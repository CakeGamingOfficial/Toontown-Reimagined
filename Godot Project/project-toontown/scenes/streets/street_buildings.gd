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
	if not ToonNet.is_authority():
		ToonNet.request_suits(district_id, street_slug)
		return
	var traffic := get_node_or_null("/root/StreetTraffic")
	if traffic != null and traffic.has_method("prepare_buildings"):
		traffic.call("prepare_buildings", district_id, street_slug, _data)


func _process(_delta: float) -> void:
	if not visuals:
		return
	var rows := _rows()
	var sig := JSON.stringify(rows)
	if sig != _sig:
		_sig = sig
		_sync(rows)
	_animate()


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
	landmark.visible = true
	landmark.remove_meta("cog_building")
	if landmark.has_meta("shop_scale"):
		landmark.scale = landmark.get_meta("shop_scale")
	_clear_dark(landmark)


func _remember_scale(landmark: Node) -> void:
	if not landmark.has_meta("shop_scale"):
		landmark.set_meta("shop_scale", landmark.scale)


func _settle(landmark: Node3D, row: Dictionary) -> void:
	var block := int(row.get("block", 0))
	_remember_scale(landmark)
	landmark.visible = false
	landmark.scale = landmark.get_meta("shop_scale")
	landmark.set_meta("cog_building", true)
	_clear_dark(landmark)
	_shown[block] = landmark
	var building := _ensure_actor(landmark, row)
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
	building.global_transform = landmark.global_transform
	building.set_meta("rest", building.global_transform)
	building.set_meta("rest_scale", building.scale)
	_dress(building, row)
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
	var shop_scale: Vector3 = landmark.get_meta("shop_scale")
	if elapsed < _DROP_TIME:
		var along := elapsed / _DROP_TIME
		building.global_transform = rest
		building.global_position = rest.origin + Vector3(0.0, _INIT_HEIGHT * (1.0 - along), 0.0)
		building.scale = rest_scale
		var squish_at := (_INIT_HEIGHT - 20.0) / _INIT_HEIGHT * _DROP_TIME
		if elapsed < squish_at:
			landmark.scale = shop_scale
			landmark.visible = true
			_darken(landmark, lerpf(0.0, 0.75, elapsed / squish_at))
		else:
			var crush := (elapsed - squish_at) / maxf(_DROP_TIME - squish_at, 0.001)
			landmark.scale = Vector3(shop_scale.x, shop_scale.y * lerpf(1.0, 0.01, crush), shop_scale.z)
			landmark.visible = true
			_darken(landmark, 0.75)
		return
	landmark.visible = false
	landmark.scale = shop_scale
	_clear_dark(landmark)
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
	var mat: Material = landmark.get_meta("shade", null)
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
		(node as MeshInstance3D).material_overlay = mat
	for child in node.get_children():
		_paint(child, mat)


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
			elevator.position = Vector3.ZERO
			elevator.rotation = Vector3.ZERO
			var basis := door.global_transform.basis.orthonormalized()
			elevator.global_transform = Transform3D(basis, door.global_position)
			_floors(elevator, int(row.get("floors", 1)))
			_medallion(elevator, track)
	var origin := _find(building, "sign_origin")
	if origin == null:
		return
	var sign := _SIGN.instantiate() as Node3D
	if sign == null:
		return
	origin.add_child(sign)
	sign.position = Vector3(0.0, 0.0, 1.2)
	sign.scale = Vector3(8.0, 8.0, 8.0)
	var label := Label3D.new()
	label.text = _caption(String(row.get("title", "")), track)
	label.font = ToonGui.suit_font()
	label.font_size = 48
	label.pixel_size = 0.045
	label.modulate = Color(1, 1, 1)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.width = 14.0
	label.position = Vector3(0.0, -0.35, 0.85)
	origin.add_child(label)


func _caption(title: String, track: String) -> String:
	var line := title.strip_edges()
	if line == "":
		line = "Cogs, Inc."
	else:
		line += ", Inc."
	return line + "\n" + String(_NAMES.get(track, "Bossbot"))


func _floors(elevator: Node, floors: int) -> void:
	var lights: Array[Node] = []
	_collect_lights(elevator, lights)
	for light in lights:
		var digit := str(light.name).substr(str(light.name).length() - 1, 1)
		if not digit.is_valid_int():
			continue
		var floor := int(digit)
		if floor > floors:
			light.visible = false
			continue
		if light is MeshInstance3D:
			var mesh := light as MeshInstance3D
			var mat := StandardMaterial3D.new()
			var source := mesh.get_active_material(0) as StandardMaterial3D
			if source != null:
				mat = source.duplicate() as StandardMaterial3D
			mat.albedo_color = _LIGHT_OFF
			mesh.material_override = mat


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
	icon.pixel_size = 0.02
	icon.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	icon.position = Vector3(0.0, 6.79, 6.8)
	icon.rotation_degrees = Vector3(90.0, 0.0, 0.0)
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
