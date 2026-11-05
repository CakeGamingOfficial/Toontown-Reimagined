extends RefCounted

## Street shop doors. Each toon building opens the interior zone
## DistributedBuildingAI assigns it: the street's hundred plus 500 plus the
## block number. The room itself is baked from that zone's seed.

## doors_practical door_*_trigger is a plane 4 wide on the door. The toon
## tube radius is 1, so the opening reaches 3 to either side and 1 out.
const _TRIGGER_ACROSS := 3.0
const _TRIGGER_OUT := 1.0
const _TRIGGER_IN := 0.35
const DOORS := "res://assets/interiors/shops/doors.glb"
const CATALOG := "res://assets/interiors/shops/shops.json"
const OPEN_SFX := "res://assets/interiors/hq/Door_Open_1.ogg"
const _PANELS: Array[String] = ["leftDoor", "rightDoor", "doorFrameHoleRight", "doorFrameHoleLeft"]
const _ZONE_FOLDERS: Array[String] = [
	"res://assets/neighborhoods/toontown_central/streets/",
	"res://assets/neighborhoods/the_burrrgh/streets/",
	"res://assets/neighborhoods/minnies_melodyland/streets/",
	"res://assets/neighborhoods/daisy_gardens/streets/",
	"res://assets/neighborhoods/donalds_dreamland/streets/",
]
const _STREETS: Dictionary = {
	"barnacle_boulevard.tscn": 1100,
	"seaweed_street.tscn": 1200,
	"lighthouse_lane.tscn": 1300,
	"silly_street.tscn": 2100,
	"loopy_lane.tscn": 2200,
	"punchline_place.tscn": 2300,
	"walrus_way.tscn": 3100,
	"sleet_street.tscn": 3200,
	"polar_place.tscn": 3300,
	"alto_avenue.tscn": 4100,
	"baritone_boulevard.tscn": 4200,
	"tenor_terrace.tscn": 4300,
	"elm_street.tscn": 5100,
	"maple_street.tscn": 5200,
	"oak_street.tscn": 5300,
	"lullaby_lane.tscn": 9100,
	"pajama_place.tscn": 9200,
}

static var zone := 0
static var street := ""
static var title := ""
static var trip := ""
static var _catalog: Dictionary = {}
static var _buildings: Array[Node3D] = []
# Door node and sidewalk point, measured once when the street loads.
# Searching every building every physics frame walks the whole street mesh.
static var _entries: Array[Dictionary] = []
static var _kit: Node
static var _zone_cache: Dictionary = {}


class _Span extends RefCounted:
	var sum := Vector3.ZERO
	var count := 0


static func street_zone(scene_path: String) -> int:
	return int(_STREETS.get(scene_path.get_file(), 0))


static func hood_id() -> int:
	var street_id := street_zone(street)
	if street_id == 0:
		street_id = int(record(zone).get("street", 0))
	if street_id == 0:
		return 2000
	return street_id - street_id % 1000


static func record(zone_id: int) -> Dictionary:
	if _catalog.is_empty() and FileAccess.file_exists(CATALOG):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
		if typeof(parsed) == TYPE_DICTIONARY:
			_catalog = parsed
	var row = _catalog.get(str(zone_id), {})
	if row is Dictionary:
		return row
	return {}


static func remember(zone_id: int, street_path: String) -> void:
	zone = zone_id
	street = street_path
	title = String(record(zone_id).get("title", ""))


static func named_doors() -> Array:
	var live: Array[Dictionary] = []
	for entry in _entries:
		var raw: Variant = entry.get("building")
		if typeof(raw) != TYPE_OBJECT or not is_instance_valid(raw):
			continue
		live.append(entry)
	_entries = live
	return _entries


static func prepare(host: Node) -> void:
	_buildings.clear()
	_entries.clear()
	_gather(host)
	for building in _buildings:
		var door := find_exterior_door(building)
		if door == null:
			continue
		_entries.append({
			"building": building,
			"door": door,
			"point": outside_trigger(building, door),
		})
	# Every street that measures shop doors also gets the knock-knock doors.
	preload("res://scenes/streets/joke_doors.gd").attach(host)


static func find_for_zone(zone_id: int) -> Node3D:
	for building in _buildings:
		if is_instance_valid(building) and interior_zone(building) == zone_id:
			return building
	return null


static func interior_zone(building: Node) -> int:
	var block := block_of(str(building.name))
	if block < 0:
		return 0
	var street_id := street_zone(street_of(building))
	if street_id == 0:
		return 0
	return street_id - street_id % 100 + 500 + block


static func closest(where: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_out := _TRIGGER_OUT + 1.0
	for entry in _entries:
		var building: Node3D = entry["building"]
		if not is_instance_valid(building) or building.has_meta("cog_building") or building.has_meta("suit_approaching"):
			continue
		var door: Node3D = entry["door"]
		if not is_instance_valid(door):
			continue
		var mouth := _doorway(door)
		var axis := _forward(building, door)
		var offset := where - mouth
		offset.y = 0.0
		var outward := offset.dot(axis)
		var aside := offset.length_squared() - outward * outward
		if outward < -_TRIGGER_IN or outward > _TRIGGER_OUT:
			continue
		if aside > _TRIGGER_ACROSS * _TRIGGER_ACROSS:
			continue
		if outward < best_out:
			best_out = outward
			best = entry
	return best


static func find_exterior_door(building: Node) -> Node3D:
	var practical := _find_door_root(building)
	if practical != null:
		return practical
	return _find_anim_door(building)


static func outside_drop(building: Node3D, door: Node3D) -> Dictionary:
	var point := _approach(building, door, 6.5)
	return {"point": point, "heading": _heading(point - _doorway(door))}


static func outside_trigger(building: Node3D, door: Node3D) -> Vector3:
	return _approach(building, door, 1.2)


## avatarEnterDoorTrack walks to (doorX, 2) on the door, into the building.
static func enter_frame(building: Node3D, door: Node3D) -> Dictionary:
	return {"mouth": _doorway(door), "outward": _forward(building, door)}


static func seal(door: Node3D) -> void:
	if door == null:
		return
	var flat := _flat(door)
	if flat != null:
		flat.visible = true
	for part_name in _PANELS:
		var part := _find_exact(door, part_name)
		if part != null:
			part.visible = false


static func open(host: Node, door: Node3D) -> void:
	if door == null:
		return
	# Swinging leaves stay off the street until this door opens. A copy on
	# every building is a few hundred extra meshes in the blocks you walk past.
	_add_panels(door)
	_sound(host, OPEN_SFX)
	var flat := _flat(door)
	if flat != null:
		flat.visible = false
	var swung := false
	for part_name in ["rightDoor", "leftDoor"]:
		var part := _find_exact(door, part_name)
		if part == null:
			continue
		part.visible = true
		_swing(host, part, 100.0 if part_name == "rightDoor" else -100.0)
		swung = true
	for part_name in ["doorFrameHoleRight", "doorFrameHoleLeft"]:
		var part := _find_exact(door, part_name)
		if part != null:
			part.visible = true
	if swung:
		return
	var host_node: Node = door
	var guard := 0
	while host_node != null and guard < 6:
		var right := _find_exact(host_node, "def_right_door")
		var left := _find_exact(host_node, "def_left_door")
		if right != null or left != null:
			_swing(host, right, 100.0)
			_swing(host, left, -100.0)
			return
		host_node = host_node.get_parent()
		guard += 1


static func _gather(node: Node) -> void:
	if node is Node3D and _is_shop(str(node.name)):
		_buildings.append(node as Node3D)
	for child in node.get_children():
		_gather(child)


static func _is_shop(node_name: String) -> bool:
	if not node_name.begins_with("tb") or node_name.contains("hq"):
		return false
	return node_name.contains("toon_landmark") or node_name.contains("animated_building")


static func block_of(node_name: String) -> int:
	if not node_name.begins_with("tb"):
		return -1
	var digits := ""
	var index := 2
	while index < node_name.length() and node_name.substr(index, 1).is_valid_int():
		digits += node_name.substr(index, 1)
		index += 1
	if digits.is_empty():
		return -1
	return int(digits)


static func street_of(node: Node) -> String:
	# The street mesh is an instanced glb, so the first scene path is that
	# file. Keep walking until the Silly Street / Loopy Lane / Punchline scene.
	var current := node
	while current != null:
		if street_zone(current.scene_file_path) != 0:
			return current.scene_file_path
		current = current.get_parent()
	return ""


static func _add_panels(door: Node3D) -> void:
	if door == null or _find_exact(door, "leftDoor") != null:
		return
	if _find_exact(door, "def_right_door") != null:
		return
	var source := _door_model(_strip_digits(str(door.name)))
	if source == null:
		return
	var tint := _flat_color(door)
	for part_name in _PANELS:
		var part := _find_base(source, part_name)
		if part == null:
			continue
		var copy: Node3D = part.duplicate() as Node3D
		if copy == null:
			continue
		copy.name = part_name
		door.add_child(copy)
		copy.transform = part.transform
		if tint.a > 0.0:
			_tint_tree(copy, tint)


static func _door_model(code: String) -> Node3D:
	if _kit == null or not is_instance_valid(_kit):
		var packed := load(DOORS) as PackedScene
		if packed == null:
			return null
		_kit = packed.instantiate()
	return _kit.find_child(code, true, false) as Node3D


static func _flat_color(door: Node3D) -> Color:
	var flat := _flat(door) as MeshInstance3D
	if flat == null:
		return Color(0, 0, 0, 0)
	var material := flat.get_active_material(0) as StandardMaterial3D
	if material == null:
		return Color(0, 0, 0, 0)
	return material.albedo_color


static func _tint_tree(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var source := mesh.get_active_material(0)
		if source is StandardMaterial3D:
			var copy := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
			copy.albedo_color = color
			mesh.material_override = copy
	for child in node.get_children():
		_tint_tree(child, color)


static func _approach(building: Node3D, door: Node3D, gap: float) -> Vector3:
	var forward := _forward(building, door)
	var origin := _doorway(door)
	var reach := gap
	if door.has_meta("shop_reach"):
		var known := float(door.get_meta("shop_reach"))
		if known > 0.0:
			reach = minf(gap, known)
	var point := origin + forward * reach
	point.y = door.global_position.y
	return point


static func _doorway(door: Node3D) -> Vector3:
	var center := door.global_position
	var flat := _flat(door)
	if flat is MeshInstance3D and (flat as MeshInstance3D).mesh != null:
		var mesh := flat as MeshInstance3D
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		center = box.get_center()
	center.y = door.global_position.y
	return center


static func _forward(building: Node3D, door: Node3D) -> Vector3:
	if door.has_meta("shop_forward"):
		return door.get_meta("shop_forward")
	var axis := door.global_transform.basis.y
	axis.y = 0.0
	if axis.length_squared() < 0.0001:
		axis = Vector3(0.0, 0.0, 1.0)
	else:
		axis = axis.normalized()
	var spot := _doorway(door)
	var polygons := _polygons(building)
	var ahead := _side_reach(polygons, spot, axis)
	var behind := _side_reach(polygons, spot, -axis)
	if behind > ahead:
		axis = -axis
	elif ahead == behind:
		var center := _visual_center(building)
		if (spot + axis).distance_squared_to(center) < spot.distance_squared_to(center):
			axis = -axis
	var reach := maxf(ahead, behind)
	door.set_meta("shop_forward", axis)
	door.set_meta("shop_reach", reach)
	return axis


static func _side_reach(polygons: Array, origin: Vector3, axis: Vector3) -> float:
	var reach := 0.0
	var steps: Array[float] = [1.5, 3.0, 4.5, 6.5]
	for distance in steps:
		if _in_polygons(polygons, origin + axis * distance):
			reach = distance
	return reach


static func _polygons(building: Node) -> Array:
	var base := _street_base(building)
	if base.is_empty():
		return []
	if _zone_cache.has(base):
		return _zone_cache[base]
	var found: Array = []
	for folder in _ZONE_FOLDERS:
		var data_path := folder + base + "_zones.json"
		if not FileAccess.file_exists(data_path):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(data_path))
		if typeof(parsed) != TYPE_DICTIONARY:
			break
		for zone_name in parsed:
			var record: Dictionary = parsed[zone_name]
			for source in record.get("polygons", []):
				var polygon := PackedVector2Array()
				for corner in source:
					polygon.append(Vector2(float(corner[0]), float(corner[1])))
				if polygon.size() >= 3:
					found.append(polygon)
		break
	_zone_cache[base] = found
	return found


static func _street_base(building: Node) -> String:
	var current := building
	while current != null:
		var file := current.scene_file_path.get_file().get_basename()
		if file.ends_with("_zones"):
			return file.trim_suffix("_zones")
		if not file.is_empty() and file != "shop_door":
			var named := file
			if named.ends_with(".glb"):
				named = named.trim_suffix(".glb")
			return named
		current = current.get_parent()
	return ""


static func _in_polygons(polygons: Array, point: Vector3) -> bool:
	var flat := Vector2(point.x, point.z)
	for polygon in polygons:
		if polygon is PackedVector2Array and _contains(flat, polygon):
			return true
	return false


static func _contains(point: Vector2, polygon: PackedVector2Array) -> bool:
	var inside := false
	var previous := polygon.size() - 1
	for index in polygon.size():
		var current := polygon[index]
		var earlier := polygon[previous]
		var crosses := (current.y > point.y) != (earlier.y > point.y)
		if crosses and point.x < (earlier.x - current.x) * (point.y - current.y) / (earlier.y - current.y) + current.x:
			inside = not inside
		previous = index
	return inside


static func _visual_center(building: Node3D) -> Vector3:
	if building.has_meta("shop_center"):
		return building.get_meta("shop_center")
	var span := _Span.new()
	_accumulate(building, span)
	var center := building.global_position
	if span.count > 0:
		center = span.sum / float(span.count)
	building.set_meta("shop_center", center)
	return center


static func _accumulate(node: Node, span: _Span) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null and mesh.visible:
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			span.sum += bounds.get_center()
			span.count += 1
	for child in node.get_children():
		_accumulate(child, span)


static func _heading(dir: Vector3) -> float:
	var flat := dir
	flat.y = 0.0
	if flat.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(atan2(-flat.x, -flat.z))


static func _flat(door: Node3D) -> Node3D:
	for child in door.get_children():
		if child is Node3D:
			var name := _strip_digits(str(child.name))
			if name == "door_flat" or name.ends_with("_flat"):
				return child as Node3D
	return null


static func _swing(host: Node, panel: Node3D, degrees: float) -> void:
	if panel == null:
		return
	panel.visible = true
	if not panel.has_meta("closed_basis"):
		panel.set_meta("closed_basis", panel.transform.basis)
	var tween := host.create_tween()
	tween.tween_method(_set_swing.bind(panel), 0.0, degrees, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


static func _set_swing(degrees: float, panel: Node3D) -> void:
	if not is_instance_valid(panel) or not panel.has_meta("closed_basis"):
		return
	var closed: Basis = panel.get_meta("closed_basis")
	panel.transform.basis = Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(degrees)) * closed


static func _sound(host: Node, path: String) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var speaker := ToonAudio.effect_player()
	speaker.stream = stream
	speaker.volume_db = -4.0
	host.add_child(speaker)
	speaker.play()
	speaker.finished.connect(speaker.queue_free)


static func _find_door_root(node: Node) -> Node3D:
	if node is Node3D and _is_door_root(str(node.name)):
		return node as Node3D
	for child in node.get_children():
		var found := _find_door_root(child)
		if found != null:
			return found
	return null


static func _is_door_root(node_name: String) -> bool:
	return node_name.begins_with("door_double_") and not node_name.contains("flat") and not node_name.contains("hole") and not node_name.ends_with("_left") and not node_name.ends_with("_right")


static func _find_anim_door(node: Node) -> Node3D:
	var node_name := str(node.name)
	if node is Node3D and (node_name.ends_with("_Door") or node_name == "door_origin"):
		return node as Node3D
	for child in node.get_children():
		var found := _find_anim_door(child)
		if found != null:
			return found
	return null


static func _strip_digits(node_name: String) -> String:
	var end := node_name.length()
	while end > 0 and node_name.substr(end - 1, 1).is_valid_int():
		end -= 1
	return node_name.substr(0, end)


static func _find_base(node: Node, base: String) -> Node3D:
	if node is Node3D and _strip_digits(str(node.name)) == base:
		return node as Node3D
	for child in node.get_children():
		var found := _find_base(child, base)
		if found != null:
			return found
	return null


static func _find_exact(node: Node, wanted: String) -> Node3D:
	if node == null:
		return null
	if node is Node3D and str(node.name) == wanted:
		return node as Node3D
	for child in node.get_children():
		var found := _find_exact(child, wanted)
		if found != null:
			return found
	return null
