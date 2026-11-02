extends Node

## DistributedBuildingMgr for one street. The district wants about 18 percent of
## the takeover blocks as suit buildings, which is the classic percentage with
## field offices left out. Toontown Central streets still stop at their bmax of
## 5. Welcome Valley never has one. A street cog walks to a shop and takes it.
## Clients only play the drop the server started.

const _CORP := preload("res://assets/buildings/cog/corp.glb")
const _LEGAL := preload("res://assets/buildings/cog/legal.glb")
const _MONEY := preload("res://assets/buildings/cog/money.glb")
const _SALES := preload("res://assets/buildings/cog/sales.glb")
const _ELEVATOR := preload("res://assets/buildings/cog/elevator.glb")
const _SIGN := preload("res://assets/buildings/cog/suit_sign.glb")
const _CORP_ICON := preload("res://assets/gui/cogs/CorpIcon.png")
const _LEGAL_ICON := preload("res://assets/gui/cogs/LegalIcon.png")
const _MONEY_ICON := preload("res://assets/gui/cogs/MoneyIcon.png")
const _SALES_ICON := preload("res://assets/gui/cogs/SalesIcon.png")
const _SUITS := preload("res://scenes/streets/street_suits.gd")

const _DEPTS: PackedStringArray = ["c", "l", "m", "s"]
const _PCT := 18
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
const _SIGN_GAP := 0.15
const _DROP_SFX := "res://assets/buildings/cog/audio/cogbldg_drop.ogg"
const _LAND_SFX := "res://assets/buildings/cog/audio/cogbldg_land.ogg"
const _SETTLE_SFX := "res://assets/buildings/cog/audio/cogbldg_settle.ogg"
## animToSuit. The building falls for 85 percent of the 8 second takeover, from 125 units up.
const _DROP_TIME := 6.8
const _TOTAL_TIME := 8.0
const _INIT_HEIGHT := 125.0

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


static func target_count(block_count: int, bmin: int, bmax: int) -> int:
	var wanted := int(float(block_count) * float(_PCT) / 100.0)
	return clampi(wanted, bmin, mini(bmax, block_count))


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
	return "|".join(parts)


func _load() -> bool:
	if not FileAccess.file_exists(json_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not (parsed is Dictionary):
		return false
	_data = parsed
	var blocks: Variant = _data.get("blocks", [])
	return blocks is Array and not (blocks as Array).is_empty()


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
		if elapsed >= _TOTAL_TIME:
			_settle(landmark as Node3D, row)
			finished.append(block)
			_hear(int(block), elapsed)
			continue
		_pose(landmark as Node3D, building as Node3D, elapsed)
		_hear(int(block), elapsed)
	for block in finished:
		_active.erase(block)


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
	if piece is Node3D and piece.has_meta("shop_scale"):
		(piece as Node3D).scale = piece.get_meta("shop_scale")
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


func _ensure_actor(landmark: Node3D, row: Dictionary) -> Node3D:
	var block := int(row.get("block", 0))
	var have: Variant = _actors.get(block)
	if have is Node3D and is_instance_valid(have):
		return have
	var model := _model(String(row.get("track", "c")))
	if model == null:
		return null
	var building := model.instantiate() as Node3D
	if building == null:
		return null
	var holder := _holder()
	building.name = "CogBuilding%d" % block
	holder.add_child(building)
	# The street landmark is already Y-up. The imported child still carries
	# the glTF Z-up spin, and leaving both on lays the tower on its side.
	building.global_transform = landmark.global_transform
	_drop_import_spin(building)
	building.set_meta("rest", building.global_transform)
	building.set_meta("rest_scale", building.scale)
	_dress(building, row)
	_use_vertex_colors(building)
	_quiet(building)
	# One surface per texture. The elevator alone was a dozen separate draws,
	# and every taken block on the street paid that cost.
	preload("res://scenes/playgrounds/street_batch.gd").flatten_prop(building)
	_actors[block] = building
	return building


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


func _zone_shown(landmark: Node) -> bool:
	var current: Node = landmark
	while current != null:
		var node_name := String(current.name)
		if node_name.length() >= 4 and node_name.is_valid_int() and current is Node3D:
			return (current as Node3D).is_visible_in_tree()
		current = current.get_parent()
	return true


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
			_floors(elevator, int(row.get("floors", 1)))
			building.set_meta("elevator", elevator)
			_show_story(elevator, int(row.get("story", -1)))
			_medallion(elevator, track)
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
	var metrics := _sign_metrics(caption)
	var text_height := metrics.x
	var z_scale := metrics.y
	# setupSuitBuilding lifts the plaque by textHeight * 0.8 / zScale. The eyes
	# face the card's local -Y, so that axis points out the door.
	var lift := text_height * 0.8 / z_scale
	_seat_sign(sign, origin, door, lift)
	sign.scale = Vector3(8.0, 8.0, 8.0 * z_scale)
	var label := Label3D.new()
	label.text = caption
	label.font = ToonGui.suit_font()
	label.font_size = 48
	label.pixel_size = 0.02
	label.modulate = Color(1, 1, 1)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Label3D width is pixels. 20px is narrower than one suit glyph, so the title stacked down the plaque.
	var cell := label.font.get_string_size("00000000000000000", HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size)
	label.width = maxf(cell.x, 17.0 * label.font_size)
	label.position = Vector3(0.0, -0.08, -0.21 + text_height * 0.1 / z_scale)
	_aim_title(sign, label, door)
	label.scale = Vector3(0.1, 0.1, 0.1 / z_scale)
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


func elevator_spot(block: int) -> Vector3:
	var have: Variant = _actors.get(block)
	if not (have is Node3D) or not is_instance_valid(have):
		return Vector3.ZERO
	var building := have as Node3D
	var door := _find(building, "elevator")
	if door == null:
		return building.global_position
	return door.global_position


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
		mat.albedo_color = color
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


func _seat_sign(sign: Node3D, origin: Node3D, door: Node3D, lift: float) -> void:
	var outward := Vector3.FORWARD
	if door != null:
		outward = door.global_basis.y
	if outward.length_squared() < 0.01:
		outward = Vector3.FORWARD
	outward = outward.normalized()
	# Local +Y points into the building so the eyes, which face local -Y, face the street.
	var y_axis := -outward
	var x_axis := Vector3.UP.cross(y_axis)
	if x_axis.length_squared() < 0.001:
		x_axis = Vector3.RIGHT
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	var basis := Basis(x_axis, y_axis, z_axis).orthonormalized()
	var place := origin.global_position + outward * _SIGN_GAP + Vector3.UP * lift
	sign.global_transform = Transform3D(basis, place)


func _aim_title(sign: Node3D, label: Label3D, door: Node3D) -> void:
	# TextNode at HPR 0 reads across the plaque and up the wall, facing the sidewalk.
	var outward := Vector3.FORWARD
	if door != null:
		outward = door.global_basis.y.normalized()
	if outward.length_squared() < 0.01:
		outward = Vector3.FORWARD
	var right := Vector3.UP.cross(outward)
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	right = right.normalized()
	var world_basis := Basis(right, Vector3.UP, outward).orthonormalized()
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
			continue
		var next := Vector3(shop_scale.x, shop_scale.y * crush, shop_scale.z)
		body.visible = true
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
