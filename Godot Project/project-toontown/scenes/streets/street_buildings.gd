extends Node

## DistributedBuildingMgr for one street. CogdoPopFactor is 1.5, so the
## classic 18 percent of takeover blocks becomes 27, and bmin and bmax grow
## the same way. Half of that quota, truncated, is Sellbot Field Offices.
## Toontown Central streets still stop at the raised bmax. Welcome Valley
## never has one. A street cog walks to a shop and takes it. Clients only
## play the drop the server started.

const _CORP := preload("res://assets/buildings/cog/corp.glb")
const _LEGAL := preload("res://assets/buildings/cog/legal.glb")
const _MONEY := preload("res://assets/buildings/cog/money.glb")
const _SALES := preload("res://assets/buildings/cog/sales.glb")
const _ELEVATOR := preload("res://assets/buildings/cog/elevator.glb")
const _SIGN := preload("res://assets/buildings/cog/suit_sign.glb")
const _WALLS := preload("res://assets/buildings/cog/suit_walls.glb")
const _SUIT_DOOR := preload("res://assets/buildings/cog/suit_door.glb")
const _CORP_ICON := preload("res://assets/gui/cogs/CorpIcon.png")
const _LEGAL_ICON := preload("res://assets/gui/cogs/LegalIcon.png")
const _MONEY_ICON := preload("res://assets/gui/cogs/MoneyIcon.png")
const _SALES_ICON := preload("res://assets/gui/cogs/SalesIcon.png")
const _SUITS := preload("res://scenes/streets/street_suits.gd")
const _HOLIDAYS := preload("res://scenes/shticker/calendar_holidays.gd")

const _DEPTS: PackedStringArray = ["c", "l", "m", "s"]
const _PCT := 27
const _POP := 1.5
## SuitBuildingInfo floor range, indexed by suit level minus one.
const _FLOORS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 3), Vector2i(2, 4),
	Vector2i(3, 4), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5),
]
const _NAMES := {"c": "Bossbot", "l": "Lawbot", "m": "Cashbot", "s": "Sellbot"}
const _MEDAL := {
	"c": Color(0.863, 0.776, 0.769),
	"s": Color(0.843, 0.745, 0.745),
	"l": Color(0.749, 0.776, 0.824),
	"m": Color(0.749, 0.769, 0.749),
}
const _LIGHT_OFF := Color(0.5, 0.5, 0.5)
const _LIGHT_ON := Color(1.0, 1.0, 1.0)
## ElevatorUtils.getLeftClosePoint for a normal elevator. Open is the origin.
const _DOOR_SLIDE := 3.5
## The eyes face the sidewalk. A paper card pushed the wrong way sits inside the wall.
const _DROP_SFX := "res://assets/buildings/cog/audio/cogbldg_drop.ogg"
const _LAND_SFX := "res://assets/buildings/cog/audio/cogbldg_land.ogg"
const _SETTLE_SFX := "res://assets/buildings/cog/audio/cogbldg_settle.ogg"
## animToSuit. The building falls for 85 percent of the 8 second takeover, from 125 units up.
const _DROP_TIME := 6.8
const _TOTAL_TIME := 8.0
const _INIT_HEIGHT := 125.0

static var _wall_source: Node3D
static var _door_source: Node3D

var json_path := ""
var street_slug := ""
var visuals := true
var district_id := -1

var _landmarks: Dictionary = {}
var _shown: Dictionary = {}
var _actors: Dictionary = {}
var _active: Dictionary = {}
var _heard: Dictionary = {}
var _data: Dictionary = {}
var _sig := ""
var _shade: StandardMaterial3D


static func attach(host: Node3D) -> void:
	if Engine.is_editor_hint() or host.get_node_or_null("StreetBuildings") != null:
		return
	var base := host.scene_file_path.get_file().get_basename()
	if not _SUITS.STREETS.has(base):
		return
	var path := str(_SUITS.STREETS[base]).replace("_suits.json", "_buildings.json")
	if not FileAccess.file_exists(path):
		return
	var script := load("res://scenes/streets/street_buildings.gd") as GDScript
	var node := script.new() as Node
	node.name = "StreetBuildings"
	node.set("json_path", path)
	node.set("street_slug", base)
	host.add_child(node)
	preload("res://scenes/streets/street_props.gd").attach(host)


static func target_count(block_count: int, bmin: int, bmax: int) -> int:
	var low := int(0.5 + _POP * float(bmin))
	var high := int(0.5 + _POP * float(bmax))
	var wanted := int(float(block_count) * float(_PCT) / 100.0)
	return clampi(wanted, low, mini(high, block_count))


## assignInitialSuitBuildings. int(wanted * CogdoRatio) of the quota are field offices.
static func cogdo_quota(total: int) -> int:
	return int(float(maxi(total, 0)) * 0.5)


## One newSuitShouldAttemptTakeover building. The level fits the floor span.
static func plan_one(blocks: Array, tracks: Array, levels: Array, used: Dictionary) -> Dictionary:
	var open: Array = []
	for item in blocks:
		if not (item is Dictionary):
			continue
		var block: Dictionary = item
		var number := int(block.get("block", 0))
		if used.has(number):
			continue
		var pos: Variant = block.get("pos", [])
		if not (pos is Array) or (pos as Array).size() < 3:
			continue
		open.append(block)
	if open.is_empty():
		return {}
	var chosen: Dictionary = open[randi() % open.size()]
	var weights := _height_table(levels)
	var track := _DEPTS[_weighted_index(tracks)]
	var height := _weighted_index(weights)
	var level := _level_for(levels, height)
	var difficulty := level - 1
	var span := _FLOORS[clampi(difficulty, 0, _FLOORS.size() - 1)]
	var floors := height + 1
	if floors < span.x or floors > span.y:
		floors = randi_range(span.x, span.y)
	return {
		"block": int(chosen.get("block", 0)),
		"track": track,
		"difficulty": difficulty,
		"floors": floors,
		"title": String(chosen.get("title", "")),
		"level": level,
		"pos": chosen.get("pos", []),
	}


static func _height_table(levels: Array) -> Array:
	var weights: Array = [0, 0, 0, 0, 0]
	for item in levels:
		var level := int(item)
		if level < 1 or level > _FLOORS.size():
			continue
		var span := _FLOORS[level - 1]
		for height in range(span.x - 1, span.y):
			if height >= 0 and height < weights.size():
				weights[height] += 1
	return weights


static func _level_for(levels: Array, height: int) -> int:
	var choices: Array[int] = []
	for item in levels:
		var level := int(item)
		if level < 1 or level > _FLOORS.size():
			continue
		var span := _FLOORS[level - 1]
		if height >= span.x - 1 and height <= span.y - 1:
			choices.append(level)
	if choices.is_empty():
		return 1 if levels.is_empty() else int(levels[0])
	return choices[randi() % choices.size()]


static func _weighted_index(weights: Array) -> int:
	var total := 0
	for item in weights:
		total += int(item)
	if total <= 0:
		return 0
	var roll := randi() % total
	var count := 0
	for index in weights.size():
		count += int(weights[index])
		if roll < count:
			return index
	return 0


func _ready() -> void:
	if not _load():
		return
	if visuals:
		_landmarks = _find_landmarks(get_parent())
		_shade = StandardMaterial3D.new()
		_shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shade.albedo_color = Color(0, 0, 0, 0)
	if district_id < 0:
		district_id = ToonNet.district_id()
	var net := ToonNet.live()
	if net != null and not net.state_changed.is_connected(_on_net):
		net.state_changed.connect(_on_net)
	if not ToonNet.is_authority():
		ToonNet.request_suits(district_id, street_slug)
	else:
		var traffic := get_node_or_null("/root/StreetTraffic")
		if traffic != null and traffic.has_method("prepare_buildings"):
			traffic.call("prepare_buildings", district_id, street_slug, _data)
	_pull()
	if get_parent() != null and get_parent().get_node_or_null("CogBuilding") == null:
		var rider: Node = load("res://scenes/buildings/cog_building.gd").new()
		rider.name = "CogBuilding"
		get_parent().add_child(rider)
	# Settled towers sit outside the visgroup, so culling has to keep running
	# after the drop finishes or every tower on the street stays drawn.
	set_process(not _actors.is_empty() or not _active.is_empty())


func _on_net(channel: String) -> void:
	if visuals and channel == "buildings:%d:%s" % [district_id, street_slug]:
		set_process(true)


func _process(_delta: float) -> void:
	if not visuals:
		set_process(false)
		return
	_pull()
	if not _active.is_empty():
		_animate()
	_cull_towers()
	if _active.is_empty() and _actors.is_empty():
		set_process(false)


func _pull() -> void:
	var rows := _rows()
	var sig := _signature(rows)
	if sig == _sig:
		return
	_sig = sig
	_sync(rows)


func _signature(rows: Array) -> String:
	var parts: PackedStringArray = []
	for item in rows:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		parts.append("%s:%s:%s:%s:%s" % [row.get("block", 0), row.get("state", ""), row.get("since", 0), row.get("floors", 0), row.get("track", "")])
	return "|".join(parts) + "#" + _HOLIDAYS.invasion_sig(district_id)


func _load() -> bool:
	if not FileAccess.file_exists(json_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not (parsed is Dictionary):
		return false
	_data = parsed
	var blocks: Variant = _data.get("blocks", [])
	return blocks is Array and not (blocks as Array).is_empty()


static func track_named(raw: String) -> String:
	match raw.to_lower():
		"c", "boss", "bossbot", "corporate", "corp":
			return "c"
		"l", "law", "lawbot", "legal":
			return "l"
		"m", "cash", "cashbot", "money":
			return "m"
		"s", "sell", "sellbot", "sales":
			return "s"
		_:
			return ""


static func dept_name(track: String) -> String:
	return String(_NAMES.get(track, "Bossbot"))


## The lowest SuitBuildingInfo row that can be this many stories.
static func difficulty_for_floors(floors: int) -> int:
	var want := clampi(floors, 1, 5)
	var index := want - 1
	while index < _FLOORS.size():
		var span := _FLOORS[index]
		if want >= span.x and want <= span.y:
			return index
		index += 1
	return _FLOORS.size() - 1


## doBuildingTakeover passes the suit level itself as the SuitBuildingInfo index.
static func floors_for(level: int) -> int:
	var index := takeover_index(level)
	var span := _FLOORS[index]
	return randi_range(span.x, span.y)


static func takeover_index(level: int) -> int:
	return clampi(level, 0, _FLOORS.size() - 1)


## The closest toon shop, or the closest building that is already a cog building.
func nearest_block(near: Vector3, suit: bool) -> Dictionary:
	var states := {}
	for item in _rows():
		if item is Dictionary:
			var row: Dictionary = item
			states[int(row.get("block", 0))] = String(row.get("state", "suit"))
	var best := {}
	var best_d := INF
	for key in _landmarks.keys():
		var number := int(key)
		if states.has(number) != suit:
			continue
		var landmark: Node = _landmarks[key]
		if landmark == null or not (landmark is Node3D) or not is_instance_valid(landmark):
			continue
		var dist := (landmark as Node3D).global_position.distance_squared_to(near)
		if dist >= best_d:
			continue
		best_d = dist
		best = {
			"block": number,
			"title": _title_of(number),
			"state": String(states.get(number, "")),
		}
	return best


func _title_of(block: int) -> String:
	var blocks: Variant = _data.get("blocks", [])
	if not (blocks is Array):
		return ""
	for item in blocks:
		if item is Dictionary and int((item as Dictionary).get("block", 0)) == block:
			return String((item as Dictionary).get("title", ""))
	return ""


func _rows() -> Array:
	var snap := ToonNet.latest("buildings:%d:%s" % [district_id, street_slug])
	var raw: Variant = snap.get("rows", [])
	if raw is Array:
		return raw
	return []


func _sync(rows: Array) -> void:
	var live := {}
	for item in rows:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		var block := int(row.get("block", 0))
		live[block] = true
		var landmark: Node = _landmarks.get(block)
		if landmark == null or not (landmark is Node3D):
			continue
		var state := String(row.get("state", "suit"))
		var elapsed := _elapsed(int(row.get("since", 0)))
		var dropping := state == "becoming" and elapsed < _TOTAL_TIME
		if state == "clearing":
			_show_shop(landmark)
			landmark.set_meta("suit_approaching", true)
			_drop_actor(block)
			_active.erase(block)
			continue
		if state == "liberating":
			_remember_scale(landmark)
			landmark.visible = true
			landmark.set_meta("cog_building", true)
			_shown[block] = landmark
			var tower := _ensure_actor(landmark as Node3D, row)
			if tower != null:
				_active[block] = row
				_liberate(landmark as Node3D, tower, elapsed)
			continue
		landmark.remove_meta("suit_approaching")
		if dropping:
			_remember_scale(landmark)
			landmark.visible = true
			landmark.set_meta("cog_building", true)
			_shown[block] = landmark
			var building := _ensure_actor(landmark as Node3D, row)
			if building != null:
				_active[block] = row
				_pose(landmark as Node3D, building, elapsed)
				_hear(block, elapsed)
			continue
		_active.erase(block)
		_settle(landmark as Node3D, row)
	var gone: Array = []
	for block in _shown.keys():
		if not live.has(block):
			gone.append(block)
	for block in gone:
		_release_block(int(block))
	preload("res://scenes/playgrounds/street_batch.gd").flush()


func _animate() -> void:
	var finished: Array = []
	for block in _active.keys():
		var row: Dictionary = _active[block]
		var landmark: Node = _landmarks.get(block)
		var building: Variant = _actors.get(block)
		if landmark == null or not (landmark is Node3D) or not (building is Node3D):
			finished.append(block)
			continue
		var elapsed := _elapsed(int(row.get("since", 0)))
		if String(row.get("state", "")) == "liberating":
			_liberate(landmark as Node3D, building as Node3D, elapsed)
			continue
		if elapsed >= _TOTAL_TIME:
			_settle(landmark as Node3D, row)
			finished.append(block)
			_hear(int(block), elapsed)
			continue
		_pose(landmark as Node3D, building as Node3D, elapsed)
		_hear(int(block), elapsed)
	for block in finished:
		_active.erase(block)
	preload("res://scenes/playgrounds/street_batch.gd").flush()


func _elapsed(since: int) -> float:
	if since <= 0:
		return _TOTAL_TIME
	return maxf(float(Time.get_unix_time_from_system() * 1000.0 - float(since)) / 1000.0, 0.0)


func _show_shop(landmark: Node) -> void:
	_restore_piece(landmark)
	_restore_list(landmark, "block_nodes")
	_restore_list(landmark, "door_props")
	if landmark.has_meta("cog_building"):
		landmark.remove_meta("cog_building")


func _restore_list(landmark: Node, key: String) -> void:
	if not landmark.has_meta(key):
		return
	var rows: Array = landmark.get_meta(key)
	for item in rows:
		if item is Node and item != landmark:
			_restore_piece(item)


func _restore_piece(piece: Node) -> void:
	if not is_instance_valid(piece):
		return
	piece.visible = true
	var solid := piece.get_node_or_null("LandmarkSolid") as CollisionObject3D
	if solid != null:
		solid.collision_layer = 1
	if piece is Node3D and piece.has_meta("shop_scale"):
		(piece as Node3D).scale = piece.get_meta("shop_scale")
	if piece is Node3D:
		preload("res://scenes/playgrounds/street_batch.gd").fold(piece as Node3D)
	_clear_dark(piece)


func _remember_scale(landmark: Node) -> void:
	if not landmark.has_meta("shop_scale"):
		landmark.set_meta("shop_scale", landmark.scale)


func _settle(landmark: Node3D, row: Dictionary) -> void:
	var block := int(row.get("block", 0))
	_remember_scale(landmark)
	_remember_block(landmark)
	landmark.set_meta("cog_building", true)
	_shown[block] = landmark
	var building := _ensure_actor(landmark, row)
	_remember_props(landmark, building)
	_hide_taken(landmark)
	if building != null and building.has_meta("rest"):
		building.global_transform = building.get_meta("rest")


func _face_track(row: Dictionary) -> String:
	var forced := _HOLIDAYS.building_track(district_id)
	if forced != "":
		return forced
	return String(row.get("track", "c"))


func _ensure_actor(landmark: Node3D, row: Dictionary) -> Node3D:
	var block := int(row.get("block", 0))
	var track := _face_track(row)
	var have: Variant = _actors.get(block)
	if have is Node3D and is_instance_valid(have) and String((have as Node).get_meta("dept", "")) == track:
		return have
	if have != null:
		_drop_actor(block)
	var model := _model(track)
	if model == null:
		return null
	var building := model.instantiate() as Node3D
	if building == null:
		return null
	var holder := _holder()
	building.name = "CogBuilding%d" % block
	holder.add_child(building)
	# setupSuitBuilding copies the sb slot, whose width is the lot (about
	# 0.54 to 0.83). The tb landmark is scale 1, which stretches the tower.
	# The imported child still carries the glTF Z-up spin, and leaving both
	# on lays the tower on its side.
	building.global_transform = _suit_slot(landmark).global_transform
	_drop_import_spin(building)
	if String(landmark.name).to_lower().contains("animated_building"):
		# DistributedAnimBuilding.adjustSbNodepathScale. The anim slot is scale 1.
		var squeezed := building.scale
		squeezed.x = 0.543667
		building.scale = squeezed
	building.set_meta("rest", building.global_transform)
	building.set_meta("rest_scale", building.scale)
	building.set_meta("dept", track)
	var faced := row.duplicate()
	faced["track"] = track
	_dress(building, faced)
	_use_vertex_colors(building)
	_quiet(building)
	# One surface per texture. The elevator alone was a dozen separate draws,
	# and every taken block on the street paid that cost.
	preload("res://scenes/playgrounds/street_batch.gd").flatten_prop(building)
	_suit_flats(landmark, building)
	_actors[block] = building
	return building


## DNAFlatBuilding.setup_suit_flat_building. Each toon wall becomes the suit
## wall of that story, and a wall that had a joke door gets suit_door centered
## on it. The pieces ride down with the tower. The toon flat hides when it lands.
func _suit_flats(landmark: Node3D, tower: Node3D) -> void:
	_remember_block(landmark)
	if not landmark.has_meta("block_nodes"):
		return
	_sources()
	if _wall_source == null:
		return
	var rows: Array = landmark.get_meta("block_nodes")
	for item in rows:
		if not (item is Node3D) or item == landmark or not (item as Node).has_meta("cog_walls"):
			continue
		var slots: Array = (item as Node).get_meta("cog_walls")
		for slot in slots:
			if slot is Dictionary:
				_place_slot(tower, slot)


func _place_slot(tower: Node3D, slot: Dictionary) -> void:
	var source := _find_static(_wall_source, String(slot.get("wall", "")))
	if source == null:
		return
	var piece := source.duplicate() as Node3D
	if piece == null:
		return
	tower.add_child(piece)
	var xform: Transform3D = slot["xform"]
	piece.global_transform = xform
	_use_vertex_colors(piece)
	_quiet(piece)
	_front_piece(piece, 1)
	_wall_solid(piece)
	if not slot.has("door") or _door_source == null:
		return
	var door_source := _find_static(_door_source, "g1")
	if door_source == null:
		return
	var door := door_source.duplicate() as Node3D
	if door == null:
		return
	tower.add_child(door)
	var door_xform: Transform3D = slot["door"]
	door.global_transform = door_xform
	_use_vertex_colors(door)
	_quiet(door)
	_black_door(door)
	_front_piece(door, 3)


## The suit door's center card has no texture, so it imports gray. The opening
## is a black interior.
func _black_door(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var mat := mesh.get_active_material(0) as StandardMaterial3D
		if mesh.mesh != null and str(mesh.name) == "node" and (mat == null or mat.albedo_texture == null):
			var black := StandardMaterial3D.new()
			black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			black.albedo_color = Color(0.0, 0.0, 0.0, 1.0)
			black.cull_mode = BaseMaterial3D.CULL_DISABLED
			black.vertex_color_use_as_albedo = false
			for index in mesh.mesh.get_surface_count():
				mesh.set_surface_override_material(index, black)
	for child in node.get_children():
		_black_door(child)


## The suit wall is a flat card. A toon's body walks through the card, so the
## card gets a box on its thin side.
func _wall_solid(piece: Node3D) -> void:
	var mesh := _wall_mesh(piece)
	if mesh == null:
		return
	var aabb := mesh.get_aabb()
	var size := aabb.size
	var center := aabb.position + size * 0.5
	var scale := mesh.global_basis.get_scale()
	if size.y <= size.x and size.y <= size.z:
		size.y = 1.0 / maxf(scale.y, 0.001)
	elif size.x <= size.z:
		size.x = 1.0 / maxf(scale.x, 0.001)
	else:
		size.z = 1.0 / maxf(scale.z, 0.001)
	var body := StaticBody3D.new()
	body.name = "WallSolid"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	body.add_child(shape)
	mesh.add_child(body)


func _wall_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _wall_mesh(child)
		if found != null:
			return found
	return null


## Called while the flat's wall meshes still exist, before the street batch
## folds them into the flat. The stored transforms are the suit pieces.
static func capture_flat(flat: Node3D) -> void:
	if flat == null or flat.has_meta("cog_walls"):
		return
	_sources()
	var slots: Array = []
	_scan_walls(flat, slots)
	flat.set_meta("cog_walls", slots)


static func _sources() -> void:
	if _wall_source == null:
		_wall_source = _WALLS.instantiate() as Node3D
	if _door_source == null:
		_door_source = _SUIT_DOOR.instantiate() as Node3D


static func _scan_walls(node: Node, slots: Array) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var low := str(mesh.name).to_lower()
		# Fence flats (wall_fence_wood, wall_woodflower_fence, wall_stone_fence)
		# are half-height walls. A takeover hides the flat, so they take the
		# same suit wall as any other wall of that story.
		if low.begins_with("wall_") and mesh.mesh != null:
			var slot := _wall_slot(mesh)
			if not slot.is_empty():
				slots.append(slot)
	for child in node.get_children():
		_scan_walls(child, slots)


static func _wall_slot(mesh: MeshInstance3D) -> Dictionary:
	var aabb := mesh.get_aabb()
	var width := aabb.size.x
	var height := aabb.size.z
	if aabb.size.y > height:
		height = aabb.size.y
	if width < 2.0 or height < 2.0:
		return {}
	var story := clampi(int(round(height / 10.0)), 1, 5)
	var side := "ur"
	var low := str(mesh.name).to_lower()
	if "_ul" in low or "_dl" in low:
		side = "ul"
	# The wall and the suit piece are both still Panda Z-up in mesh space.
	# The street node's transform stands them up. Both models are flat on Y=0,
	# so the door has to sit in front of the wall or the depth fight opens a
	# slot of sky. Toon joke doors are authored at about y=-0.06.
	var lip := 0.6
	var wall_at := aabb.position + Vector3(-lip, -0.04, 0.0)
	var world := mesh.global_transform * Transform3D(Basis.IDENTITY.scaled(Vector3(width + lip * 2.0, 1.0, height)), wall_at)
	var slot := {
		"wall": "wall_suit_build%d_%s" % [story, side],
		"xform": world,
	}
	if _has_door(mesh):
		var origin := Vector3(aabb.position.x + width * 0.5, aabb.position.y - 0.16, aabb.position.z)
		slot["door"] = mesh.global_transform * Transform3D(Basis.IDENTITY, origin)
	return slot


static func _has_door(node: Node) -> bool:
	for child in node.get_children():
		var low := str(child.name).to_lower()
		if low.begins_with("door_single") or low.begins_with("door_garage"):
			return true
		if _has_door(child):
			return true
	return false


static func _find_static(root: Node, needle: String) -> Node3D:
	if root == null or needle.is_empty():
		return null
	if str(root.name).contains(needle) and root is Node3D:
		return root as Node3D
	for child in root.get_children():
		var found := _find_static(child, needle)
		if found != null:
			return found
	return null


func _holder() -> Node3D:
	var holder := get_node_or_null("Placed") as Node3D
	if holder != null:
		return holder
	holder = Node3D.new()
	holder.name = "Placed"
	add_child(holder)
	return holder


func _drop_actor(block: int) -> void:
	var have: Variant = _actors.get(block)
	_actors.erase(block)
	_heard.erase(block)
	if have is Node and is_instance_valid(have):
		(have as Node).queue_free()


func block_taken(block: int) -> bool:
	var landmark: Node = _landmarks.get(block)
	return landmark != null and is_instance_valid(landmark) and landmark.has_meta("cog_building")


func _release_block(block: int) -> void:
	var landmark: Node = _shown.get(block)
	_shown.erase(block)
	_active.erase(block)
	_drop_actor(block)
	if landmark != null and is_instance_valid(landmark):
		_show_shop(landmark)
		landmark.remove_meta("suit_approaching")


func _pose(landmark: Node3D, building: Node3D, elapsed: float) -> void:
	var rest: Transform3D = building.get_meta("rest")
	var rest_scale: Vector3 = building.get_meta("rest_scale")
	_remember_block(landmark)
	_remember_props(landmark, building)
	if elapsed < _DROP_TIME:
		var along := elapsed / _DROP_TIME
		building.global_transform = rest
		building.global_position = rest.origin + Vector3(0.0, _INIT_HEIGHT * (1.0 - along), 0.0)
		building.scale = rest_scale
		# animToSuit waits until the tower is 20 feet up, then squishes every tb node.
		var squish_at := (_INIT_HEIGHT - 20.0) / _INIT_HEIGHT * _DROP_TIME
		if elapsed < squish_at:
			_squash_taken(landmark, 1.0, lerpf(0.0, 0.75, elapsed / squish_at))
		else:
			var crush := (elapsed - squish_at) / maxf(_DROP_TIME - squish_at, 0.001)
			_squash_taken(landmark, lerpf(1.0, 0.01, crush), 0.75)
		return
	_hide_taken(landmark)
	building.global_transform = rest
	var bounce := _bounce_scale(elapsed - _DROP_TIME)
	building.scale = Vector3(rest_scale.x, rest_scale.y * bounce, rest_scale.z)


func _bounce_scale(elapsed: float) -> float:
	# createBounceTrack(node, 2, 0.65, 1.2, slowInitBounce=1) on the up axis.
	var marks: Array[float] = [0.0, 0.4, 0.8, 1.2]
	var heights: Array[float] = [1.0, 0.65, 1.175, 1.0]
	if elapsed >= 1.2:
		return 1.0
	for index in 3:
		if elapsed > marks[index + 1]:
			continue
		var blend := (elapsed - marks[index]) / 0.4
		blend = blend * blend * (3.0 - 2.0 * blend)
		return lerpf(heights[index], heights[index + 1], blend)
	return 1.0


## animToToon. The suit bounces and sinks. Halfway through, the shop grows back.
func _liberate(landmark: Node3D, building: Node3D, elapsed: float) -> void:
	_remember_block(landmark)
	_remember_props(landmark, building)
	var suit := 1.0
	if elapsed < 0.4:
		suit = _axis_scale(elapsed, 3, 1.2, 0.4, 0.0, 1.0)
	elif elapsed < 1.2:
		suit = _axis_scale(elapsed - 0.4, 5, 0.8, 0.8, 0.0, 1.0)
	elif elapsed < 2.56:
		suit = _axis_scale(elapsed - 1.2, 7, 1.2, 1.36, 0.0, 1.0)
	elif elapsed < 4.0:
		suit = _axis_scale(elapsed - 2.56, 9, 1.2, 1.44, 0.0, 1.0)
	else:
		suit = lerpf(1.0, 0.01, clampf((elapsed - 4.0) / 0.8, 0.0, 1.0))
	if building.has_meta("rest"):
		building.global_transform = building.get_meta("rest")
	var rest_scale := Vector3.ONE
	if building.has_meta("rest_scale"):
		rest_scale = building.get_meta("rest_scale")
	building.visible = suit > 0.02
	building.scale = Vector3(rest_scale.x, rest_scale.y * suit, rest_scale.z)
	if elapsed < 4.0:
		_hide_taken(landmark)
		return
	var grown := _axis_scale(elapsed - 4.0, 11, 1.2, 4.0, 4.0, 0.01)
	_squash_list(landmark, "block_nodes", grown, 0.0, false)
	_squash_list(landmark, "door_props", grown, 0.0, false)


## createBounceTrack. The last step of a growing shop settles at full height.
func _axis_scale(elapsed: float, bounces: int, start_scale: float, total: float, slow: float, rest: float) -> float:
	var count := bounces + 1
	var bounce_time := total / float(count)
	if slow > 0.0:
		bounce_time = total / (float(count) + slow - 1.0)
	var span := bounce_time * slow if slow > 0.0 else bounce_time
	var diff := start_scale - rest
	var cursor := 0.0
	var from := rest
	for step in count:
		var dest := rest
		if step == count - 1 and rest < 0.5:
			dest = 1.0
		elif step != count - 1 and step % 2 == 1:
			dest = rest - diff
		elif step != count - 1:
			dest = rest + diff
		if elapsed <= cursor + span:
			var blend := clampf((elapsed - cursor) / maxf(span, 0.001), 0.0, 1.0)
			blend = blend * blend * (3.0 - 2.0 * blend)
			return lerpf(from, dest, blend)
		from = dest
		cursor += span
		diff *= 0.5
		span = bounce_time
	return 1.0 if rest < 0.5 else rest


func _darken(landmark: Node, amount: float) -> void:
	var mat: Material = null
	if landmark.has_meta("shade"):
		mat = landmark.get_meta("shade")
	if not (mat is StandardMaterial3D):
		if _shade == null:
			return
		mat = _shade.duplicate()
		landmark.set_meta("shade", mat)
	(mat as StandardMaterial3D).albedo_color = Color(0, 0, 0, clampf(amount, 0.0, 1.0))
	_paint(landmark, mat)


func _clear_dark(landmark: Node) -> void:
	_paint(landmark, null)


func _paint(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.material_overlay != mat:
			mesh.material_overlay = mat
	for child in node.get_children():
		_paint(child, mat)


## The street already has its own shadows. A suit tower that casts them
## redraws the block every frame.
## The tower is parented beside the street, not inside the visgroup, so hiding
## the block did not hide it. Follow the zone the shop lives in.
func _cull_towers() -> void:
	for block in _actors.keys():
		var building: Variant = _actors[block]
		if not (building is Node3D) or not is_instance_valid(building):
			continue
		var landmark: Node = _landmarks.get(block)
		var show := true
		if landmark != null and is_instance_valid(landmark):
			show = _zone_shown(landmark)
		var actor := building as Node3D
		if actor.visible != show:
			actor.visible = show
		_tower_collision(actor, show)


func _tower_collision(node: Node, show: bool) -> void:
	if node is CollisionObject3D:
		var body := node as CollisionObject3D
		if body.name == "LandmarkSolid" or body.name == "WallSolid":
			var layer: int = 1 if show else 0
			if body.collision_layer != layer:
				body.collision_layer = layer
	for child in node.get_children():
		_tower_collision(child, show)


func _zone_shown(landmark: Node) -> bool:
	var current: Node = landmark
	while current != null:
		var node_name := String(current.name)
		if node_name.length() >= 4 and node_name.is_valid_int() and current is Node3D:
			return (current as Node3D).is_visible_in_tree()
		current = current.get_parent()
	return true


func _front_piece(node: Node, priority: int) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null:
			for index in mesh.mesh.get_surface_count():
				var mat := mesh.get_active_material(index) as BaseMaterial3D
				if mat == null:
					continue
				var copy := mat.duplicate() as BaseMaterial3D
				copy.cull_mode = BaseMaterial3D.CULL_DISABLED
				copy.render_priority = priority
				mesh.set_surface_override_material(index, copy)
	for child in node.get_children():
		_front_piece(child, priority)


func _quiet(node: Node) -> void:
	if node is GeometryInstance3D:
		var geom := node as GeometryInstance3D
		geom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geom.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	for child in node.get_children():
		_quiet(child)


func _hear(block: int, elapsed: float) -> void:
	if not _heard.has(block):
		_heard[block] = elapsed
		if elapsed < 0.25:
			_sfx(_DROP_SFX)
		return
	var prev := float(_heard[block])
	if prev < _DROP_TIME and elapsed >= _DROP_TIME:
		_sfx(_LAND_SFX)
	if prev < _TOTAL_TIME and elapsed >= _TOTAL_TIME:
		_sfx(_SETTLE_SFX)
	_heard[block] = elapsed


func _sfx(path: String) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var speaker := ToonAudio.effect_player()
	speaker.stream = stream
	speaker.volume_db = -4.0
	add_child(speaker)
	speaker.play()
	speaker.finished.connect(speaker.queue_free)


func _model(track: String) -> PackedScene:
	match track:
		"l":
			return _LEGAL
		"m":
			return _MONEY
		"s":
			return _SALES
		_:
			return _CORP


func _dress(building: Node3D, row: Dictionary) -> void:
	var track := String(row.get("track", "c"))
	var door := _find(building, "door_origin")
	if door != null:
		var elevator := _ELEVATOR.instantiate() as Node3D
		if elevator != null:
			door.add_child(elevator)
			elevator.transform = Transform3D.IDENTITY
			_drop_import_spin(elevator)
			# normalizeElevator keeps the car at world scale 1. The lot scale
			# squeezes the tower, not the doors.
			var spun := elevator.global_basis.orthonormalized()
			elevator.global_transform = Transform3D(spun, elevator.global_position)
			_floors(elevator, int(row.get("floors", 1)))
			building.set_meta("elevator", elevator)
			_show_story(elevator, int(row.get("story", -1)))
			_medallion(elevator, track)
			frame_solid(elevator)
	var origin := _find(building, "sign_origin")
	if origin == null:
		return
	var sign := _SIGN.instantiate() as Node3D
	if sign == null:
		return
	origin.add_child(sign)
	_drop_import_spin(sign)
	_sign_material(sign)
	var caption := _caption(String(row.get("title", "")), track)
	if bool(row.get("cogdo", false)):
		caption = "Mover & Shaker\nField Office"
	var metrics := _sign_metrics(caption)
	var text_height := metrics.x
	var z_scale := metrics.y
	# setupSuitBuilding: pos (0, 0, textHeight * 0.8 / zScale), scale (8, 8, 8 * zScale).
	# Local +Y points into the tower. A step the other way keeps the plaque off
	# the front card. Panda draws it there with a decal; without one the wall wins.
	var lift := text_height * 0.8 / z_scale
	sign.transform = Transform3D.IDENTITY
	sign.position = Vector3(0.0, -0.35, lift)
	sign.scale = Vector3(8.0, 8.0, 8.0 * z_scale)
	var label := Label3D.new()
	label.text = caption
	label.font = ToonGui.suit_font()
	label.font_size = 48
	label.pixel_size = 0.02
	label.modulate = Color(1, 1, 1)
	label.outline_modulate = Color(0, 0, 0, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Label3D width is pixels. 20px is narrower than one suit glyph, so the title stacked down the plaque.
	var cell := label.font.get_string_size("00000000000000000", HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size)
	label.width = maxf(cell.x, 17.0 * label.font_size)
	label.position = Vector3(0.0, -0.04, -0.21 + text_height * 0.1 / z_scale)
	_aim_title(sign, label, origin)
	# The lot squeezes the plaque on X and the sign grows on Z, so a square
	# glyph scale comes out tall and narrow. Widen the line so it fills the frame.
	var glyph := 0.082
	label.scale = Vector3(glyph * 1.45, glyph / z_scale, glyph)
	sign.add_child(label)


func _drop_import_spin(root: Node3D) -> void:
	for child in root.get_children():
		if not (child is Node3D):
			continue
		var body := child as Node3D
		var basis := body.basis
		var z_up := basis.x.distance_to(Vector3(1, 0, 0)) < 0.02
		z_up = z_up and basis.y.distance_to(Vector3(0, 0, -1)) < 0.02
		z_up = z_up and basis.z.distance_to(Vector3(0, 1, 0)) < 0.02
		if z_up:
			body.basis = Basis.IDENTITY
		return


## TextNode.getHeight for a two-or-three line plaque, then (height + 2) / 3.
func _sign_metrics(caption: String) -> Vector2:
	var height := 0.0
	for line in caption.split("\n"):
		var remain := line
		if remain.is_empty():
			height += 1.0
			continue
		while not remain.is_empty():
			height += 1.0
			if remain.length() <= 17:
				break
			var window := remain.substr(0, 18)
			var space := window.rfind(" ")
			var cut := 17
			if space > 0:
				cut = space + 1
			remain = remain.substr(cut)
	return Vector2(height, (height + 2.0) / 3.0)


func _caption(title: String, track: String) -> String:
	var line := title.strip_edges()
	if line == "":
		line = "Cogs, Inc."
	else:
		line += ", Inc."
	return line + "\n" + String(_NAMES.get(track, "Bossbot"))


func _floors(elevator: Node, floors: int) -> void:
	elevator.set_meta("floor_count", maxi(floors, 1))


## DistributedElevatorExt.setFloor. story is the 0-based floor a group is on.
## -1 is an empty elevator: every bulb stays at LIGHT_OFF and the doors stay open.
func _show_story(elevator: Node, story: int) -> void:
	var floors := int(elevator.get_meta("floor_count", 1))
	var lights: Array[Node] = []
	_collect_lights(elevator, lights)
	for light in lights:
		var digit := str(light.name).substr(str(light.name).length() - 1, 1)
		if not digit.is_valid_int():
			continue
		var index := int(digit) - 1
		if index < 0 or index >= floors:
			light.visible = false
			continue
		light.visible = true
		var color := _LIGHT_OFF
		if story >= 0 and index == story:
			color = _LIGHT_ON
		_paint_bulb(light, color)
	_set_doors(elevator, story >= 0)


## Door the suit-building nametag hangs on. The landmark stands in until the car exists.
func marker(block: int) -> Vector3:
	var spot := elevator_spot(block)
	if spot != Vector3.ZERO:
		return spot
	var have: Variant = _landmarks.get(block)
	if have is Node3D and is_instance_valid(have):
		return (have as Node3D).global_position + Vector3.UP * 4.0
	return Vector3.ZERO


func elevator_spot(block: int) -> Vector3:
	var have: Variant = _actors.get(block)
	if not (have is Node3D) or not is_instance_valid(have):
		return Vector3.ZERO
	var building := have as Node3D
	var door := _find(building, "elevator")
	if door == null:
		return building.global_position
	return door.global_position


## The suit elevator hung on this building's door. Null until the takeover has landed.
func elevator_node(block: int) -> Node3D:
	var have: Variant = _actors.get(block)
	if not (have is Node) or not is_instance_valid(have):
		return null
	if not (have as Node).has_meta("elevator"):
		return null
	var elevator: Variant = (have as Node).get_meta("elevator")
	if elevator is Node3D and is_instance_valid(elevator):
		return elevator
	return null


func set_doors(block: int, closed: float) -> void:
	var have: Variant = _actors.get(block)
	if not (have is Node) or not is_instance_valid(have):
		return
	if not (have as Node).has_meta("elevator"):
		return
	var elevator: Node = (have as Node).get_meta("elevator")
	if not is_instance_valid(elevator):
		return
	var slide := _DOOR_SLIDE * clampf(closed, 0.0, 1.0)
	var left := _find(elevator, "left-door")
	if left == null:
		left = _find(elevator, "left_door")
	var right := _find(elevator, "right-door")
	if right == null:
		right = _find(elevator, "right_door")
	if left != null:
		left.position.x = slide
	if right != null:
		right.position.x = -slide


func set_story(block: int, story: int) -> void:
	var have: Variant = _actors.get(block)
	if not (have is Node) or not is_instance_valid(have):
		return
	if not (have as Node).has_meta("elevator"):
		return
	var elevator: Node = (have as Node).get_meta("elevator")
	if is_instance_valid(elevator):
		_show_story(elevator, story)


## DistributedSuitInterior.setElevatorLights. The street car and both floor
## cars use the same bulbs.
func paint_elevator(elevator: Node, floors: int, story: int) -> void:
	if elevator == null or not is_instance_valid(elevator):
		return
	_floors(elevator, floors)
	_show_story(elevator, story)


func _paint_bulb(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var mat := mesh.material_override as StandardMaterial3D
		if mat == null:
			var source := mesh.get_active_material(0) as StandardMaterial3D
			if source != null:
				mat = source.duplicate() as StandardMaterial3D
			else:
				mat = StandardMaterial3D.new()
			mesh.material_override = mat
		# setColor on the bulb. Unshaded keeps LIGHT_OFF gray and LIGHT_ON white
		# instead of letting the street shade both of them the same.
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		var lit := color.r > 0.75
		mat.emission_enabled = lit
		if lit:
			mat.emission = Color.WHITE
			mat.emission_texture = mat.albedo_texture
			mat.emission_energy_multiplier = 1.0
	for child in node.get_children():
		_paint_bulb(child, color)


func _set_doors(elevator: Node, closed: bool) -> void:
	var left := _find(elevator, "left-door")
	if left == null:
		left = _find(elevator, "left_door")
	var right := _find(elevator, "right-door")
	if right == null:
		right = _find(elevator, "right_door")
	var slide: float = _DOOR_SLIDE if closed else 0.0
	if left != null:
		left.position.x = slide
	if right != null:
		right.position.x = -slide


func _collect_lights(node: Node, into: Array[Node]) -> void:
	if str(node.name).begins_with("floor_light_"):
		into.append(node)
	for child in node.get_children():
		_collect_lights(child, into)


func _medallion(elevator: Node, track: String) -> void:
	var cab := _find_exact(elevator, "elevator")
	if cab == null:
		cab = elevator
	var icon := Sprite3D.new()
	icon.name = "DeptIcon"
	icon.texture = _icon(track)
	icon.modulate = _MEDAL.get(track, Color.WHITE)
	icon.pixel_size = 0.01
	icon.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	icon.position = Vector3(0.0, 6.79, 6.8)
	icon.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	icon.scale = Vector3(3.0, 3.0, 3.0)
	cab.add_child(icon)


func _icon(track: String) -> Texture2D:
	match track:
		"l":
			return _LEGAL_ICON
		"m":
			return _MONEY_ICON
		"s":
			return _SALES_ICON
		_:
			return _CORP_ICON


## The doorway stays open. The metal frame, its corners, and the light panel
## are the solid shell around that opening.
static func frame_solid(elevator: Node) -> void:
	if elevator == null:
		return
	for piece in ["frame", "corners", "light_panel_frame"]:
		var mesh := _find_named(elevator, piece) as MeshInstance3D
		if mesh == null or mesh.mesh == null or mesh.get_node_or_null(piece + "_col") != null:
			continue
		mesh.create_trimesh_collision()
		var body := mesh.get_node_or_null(piece + "_col") as StaticBody3D
		if body == null:
			continue
		body.collision_layer = 1
		body.collision_mask = 0


static func _find_named(root: Node, wanted: String) -> Node3D:
	for child in root.get_children():
		if str(child.name) == wanted and child is Node3D:
			return child as Node3D
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null


## The shell around the elevator has vertex colors and no texture. Leaving
## them off draws those faces solid white on every department.
func _use_vertex_colors(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null:
			for index in mesh.mesh.get_surface_count():
				var arrays: Array = mesh.mesh.surface_get_arrays(index)
				if arrays[Mesh.ARRAY_COLOR] == null:
					continue
				var mat := mesh.get_active_material(index) as StandardMaterial3D
				if mat == null or mat.vertex_color_use_as_albedo or mat.albedo_texture != null:
					continue
				var copy := mat.duplicate() as StandardMaterial3D
				copy.vertex_color_use_as_albedo = true
				mesh.set_surface_override_material(index, copy)
	for child in node.get_children():
		_use_vertex_colors(child)


func _sign_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null:
			for index in mesh.mesh.get_surface_count():
				var mat := mesh.get_active_material(index) as BaseMaterial3D
				if mat == null:
					continue
				var copy := mat.duplicate() as BaseMaterial3D
				copy.cull_mode = BaseMaterial3D.CULL_DISABLED
				copy.render_priority = 2
				mesh.set_surface_override_material(index, copy)
	for child in node.get_children():
		_sign_material(child)


## The sb node is the suit slot. tb is the toon shop and is left at scale 1.
func _suit_slot(landmark: Node3D) -> Node3D:
	var prefix := "sb%d_" % _block_of(str(landmark.name))
	var found := _find_prefix(get_parent(), prefix)
	if found == null:
		return landmark
	return found


func _find_prefix(node: Node, prefix: String) -> Node3D:
	if node is Node3D and String(node.name).begins_with(prefix):
		return node as Node3D
	for child in node.get_children():
		var found := _find_prefix(child, prefix)
		if found != null:
			return found
	return null


func _aim_title(sign: Node3D, label: Label3D, origin: Node3D) -> void:
	# Label3D faces its -Z. The plaque's local -Y is the sidewalk, local Z is up.
	# The slot's basis turns those axes over, so the title is rotated to match the eyes.
	var right := -origin.global_basis.x.normalized()
	var up := -origin.global_basis.z.normalized()
	var into := origin.global_basis.y.normalized()
	var world_basis := Basis(right, up, into).orthonormalized()
	var sign_basis := sign.global_transform.basis.orthonormalized()
	label.basis = sign_basis.inverse() * world_basis


func _remember_block(landmark: Node3D) -> void:
	if landmark.has_meta("block_nodes"):
		return
	var block := _block_of(str(landmark.name))
	var nodes: Array[Node3D] = []
	_collect_block(get_parent(), block, nodes)
	landmark.set_meta("block_nodes", nodes)


func _collect_block(node: Node, block: int, into: Array[Node3D]) -> void:
	if node is Node3D and _block_root(node, block):
		into.append(node as Node3D)
	for child in node.get_children():
		_collect_block(child, block, into)


func _block_root(node: Node, block: int) -> bool:
	var name := str(node.name)
	if not name.begins_with("tb") or _block_of(name) != block:
		return false
	var parent := node.get_parent()
	if parent != null and str(parent.name).begins_with("tb") and _block_of(str(parent.name)) == block:
		return false
	return true


func _remember_props(landmark: Node3D, building: Node3D) -> void:
	if landmark.has_meta("door_props") or building == null:
		return
	var door := _find(building, "door_origin")
	var props: Array[Node3D] = []
	if door != null:
		_collect_props(get_parent(), door, props)
	landmark.set_meta("door_props", props)


func _collect_props(node: Node, door: Node3D, into: Array[Node3D]) -> void:
	var low := str(node.name).to_lower()
	if node is Node3D and low.begins_with("interactive_prop_"):
		var prop := node as Node3D
		var delta := prop.global_position - door.global_position
		var outward := door.global_basis.y.normalized()
		var right := Vector3.UP.cross(outward).normalized()
		var ahead := delta.dot(outward)
		var side := absf(delta.dot(right))
		if side < 12.0 and ahead > -3.0 and ahead < 16.0 and absf(delta.y) < 8.0:
			into.append(prop)
	for child in node.get_children():
		_collect_props(child, door, into)


func _squash_taken(landmark: Node3D, crush: float, darken: float) -> void:
	_squash_list(landmark, "block_nodes", crush, darken, false)
	_squash_list(landmark, "door_props", crush, 0.0, false)


func _hide_taken(landmark: Node3D) -> void:
	_squash_list(landmark, "block_nodes", 1.0, 0.0, true)
	_squash_list(landmark, "door_props", 1.0, 0.0, true)


func _squash_list(landmark: Node3D, key: String, crush: float, darken: float, hide: bool) -> void:
	if not landmark.has_meta(key):
		return
	var rows: Array = landmark.get_meta(key)
	for item in rows:
		if not (item is Node3D) or not is_instance_valid(item):
			continue
		var body := item as Node3D
		if not body.has_meta("shop_scale"):
			body.set_meta("shop_scale", body.scale)
		var shop_scale: Vector3 = body.get_meta("shop_scale")
		if hide:
			if body.visible or body.has_meta("shade"):
				body.visible = false
				body.scale = shop_scale
				_clear_dark(body)
				preload("res://scenes/playgrounds/street_batch.gd").touch(body)
			# The suit wall stands on this flat's footprint, so the solid stays.
			var solid := body.get_node_or_null("LandmarkSolid") as CollisionObject3D
			if solid != null and not body.has_meta("cog_walls"):
				solid.collision_layer = 0
			continue
		var next := Vector3(shop_scale.x, shop_scale.y * crush, shop_scale.z)
		body.visible = true
		preload("res://scenes/playgrounds/street_batch.gd").unfold(body)
		if body.scale != next:
			body.scale = next
		if darken > 0.0:
			_darken(body, darken)
		elif body.has_meta("shade"):
			_clear_dark(body)


func _find_landmarks(root: Node) -> Dictionary:
	var found := {}
	_walk_landmarks(root, found)
	return found


func _walk_landmarks(node: Node, found: Dictionary) -> void:
	var name := str(node.name)
	if name.begins_with("tb") and (name.contains("toon_landmark") or name.contains("animated_building")):
		var block := _block_of(name)
		if block >= 0:
			found[block] = node
	for child in node.get_children():
		_walk_landmarks(child, found)


func _block_of(node_name: String) -> int:
	var digits := ""
	var index := 2
	while index < node_name.length() and node_name.substr(index, 1).is_valid_int():
		digits += node_name.substr(index, 1)
		index += 1
	if digits.is_empty():
		return -1
	return int(digits)


func _find(root: Node, needle: String) -> Node3D:
	if str(root.name).contains(needle) and root is Node3D:
		return root as Node3D
	for child in root.get_children():
		var found := _find(child, needle)
		if found != null:
			return found
	return null


func _find_exact(root: Node, wanted: String) -> Node3D:
	for child in root.get_children():
		if str(child.name) == wanted and child is Node3D:
			return child as Node3D
		var found := _find_exact(child, wanted)
		if found != null:
			return found
	return null
