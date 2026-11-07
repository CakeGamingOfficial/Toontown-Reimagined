extends RefCounted

## DistributedHQInterior.setupDoors hangs door_double_round_ur on door_origin_0
## and door_origin_1. The playground landmark already has both closed slabs
## and their swinging panels. door_index is which of those two you used.

const _MOTION := preload("res://scenes/interiors/door_motion.gd")
const OPEN_SFX := "res://assets/interiors/hq/Door_Open_1.ogg"
const CLOSE_SFX := "res://assets/interiors/hq/Door_Close_1.ogg"
const _PANELS: Array[String] = ["leftDoor", "rightDoor", "doorFrameHoleRight", "doorFrameHoleLeft"]

# "in" arrives inside. "out" returns to the sidewalk at door_index.
static var trip := ""
static var door_index := 0
# The playground or street scene that opened this room, and its interior zone.
static var return_scene := ""
static var zone_id := 2520

# Outdoor scene to the NPCToons interior zone that staffs that building.
const _ZONE_BY_SCENE: Dictionary = {
	"res://scenes/playgrounds/donalds_dock.tscn": 1507,
	"res://scenes/streets/barnacle_boulevard.tscn": 1629,
	"res://scenes/streets/seaweed_street.tscn": 1729,
	"res://scenes/streets/lighthouse_lane.tscn": 1835,
	"res://scenes/playgrounds/toontown_central.tscn": 2520,
	"res://scenes/streets/silly_street.tscn": 2671,
	"res://scenes/streets/loopy_lane.tscn": 2742,
	"res://scenes/streets/punchline_place.tscn": 2832,
	"res://scenes/playgrounds/the_burrrgh.tscn": 3508,
	"res://scenes/streets/walrus_way.tscn": 3654,
	"res://scenes/streets/sleet_street.tscn": 3739,
	"res://scenes/streets/polar_place.tscn": 3801,
	"res://scenes/playgrounds/minnies_melodyland.tscn": 4504,
	"res://scenes/streets/alto_avenue.tscn": 4659,
	"res://scenes/streets/baritone_boulevard.tscn": 4739,
	"res://scenes/streets/tenor_terrace.tscn": 4873,
	"res://scenes/playgrounds/daisy_gardens.tscn": 5502,
	"res://scenes/streets/elm_street.tscn": 5627,
	"res://scenes/streets/maple_street.tscn": 5728,
	"res://scenes/streets/oak_street.tscn": 5802,
	"res://scenes/playgrounds/donalds_dreamland.tscn": 9505,
	"res://scenes/streets/lullaby_lane.tscn": 9652,
	"res://scenes/streets/pajama_place.tscn": 9756,
}

# setupDoors seeds Random with the zone and always picks a Toontown Central door color.
const _DOOR_COLOR: Dictionary = {
	1507: Color(1.0, 1.0, 0.7),
	1629: Color(0.8, 0.5, 0.3),
	1729: Color(1.0, 1.0, 0.7),
	1835: Color(1.0, 1.0, 0.7),
	2520: Color(0.8, 0.5, 0.3),
	2671: Color(1.0, 1.0, 0.7),
	2742: Color(0.8, 0.5, 0.3),
	2832: Color(1.0, 1.0, 0.7),
	3508: Color(0.8, 0.5, 0.3),
	3654: Color(0.8, 0.5, 0.3),
	3739: Color(1.0, 1.0, 0.7),
	3801: Color(1.0, 1.0, 0.7),
	4504: Color(1.0, 1.0, 0.7),
	4659: Color(1.0, 1.0, 0.7),
	4739: Color(1.0, 1.0, 0.7),
	4873: Color(0.8, 0.5, 0.3),
	5502: Color(1.0, 1.0, 0.7),
	5627: Color(1.0, 1.0, 0.7),
	5728: Color(1.0, 1.0, 0.7),
	5802: Color(0.8, 0.5, 0.3),
	9505: Color(1.0, 1.0, 0.7),
	9652: Color(0.8, 0.5, 0.3),
	9756: Color(0.8, 0.5, 0.3),
}


static func prepare(host: Node) -> void:
	var building := find_building(host)
	if building == null:
		return
	for index in 2:
		seal(find_exterior_door(building, index))


static func zone_for(scene: String) -> int:
	return int(_ZONE_BY_SCENE.get(scene, 2520))


static func hood() -> int:
	return zone_id - posmod(zone_id, 1000)


static func door_color() -> Color:
	return _DOOR_COLOR.get(zone_id, Color(1.0, 1.0, 0.7)) as Color


static func find_building(host: Node) -> Node3D:
	return _find_hq(host)


static func find_exterior_door(building: Node, index: int) -> Node3D:
	return _find_exact(building, "door_%d" % index)


static func find_interior_door(host: Node, index: int) -> Node3D:
	var origin := find_interior_origin(host, index)
	if origin == null:
		return null
	return _find_exact(origin, "door_%d" % index)


static func find_interior_origin(host: Node, index: int) -> Node3D:
	return _find_exact(host, "door_origin_%d" % index)


static func outside_trigger(building: Node3D, index: int) -> Vector3:
	return _approach(building, index, 1.6)


## avatarEnterDoorTrack walks to (doorX, 2) on the door, into the building.
static func enter_frame(building: Node3D, index: int) -> Dictionary:
	var door := find_exterior_door(building, index)
	var origin := _find_exact(building, "door_origin_%d" % index)
	var mouth := _doorway(door, origin)
	return {"mouth": mouth, "outward": _outward(building, origin, mouth)}


## The interior door's +Y is not the original door depth. Walk out through it,
## opposite the six-unit step inside_drop takes into the room.
static func interior_enter_point(host: Node, index: int) -> Vector3:
	var origin := find_interior_origin(host, index)
	if origin == null:
		return Vector3.ZERO
	var other := find_interior_origin(host, 1 - index)
	var into := Vector3(0.0, 0.0, 1.0)
	if other != null:
		into = origin.global_position - other.global_position
		into.y = 0.0
	if into.length_squared() < 0.0001:
		into = Vector3(0.0, 0.0, 1.0)
	else:
		into = into.normalized()
	# into is the way the toon faces. Their right is into.cross(up), the right jamb.
	var side := into.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	else:
		side = side.normalized()
	return origin.global_position + into * 2.0 + side * 1.5


## avatarEnqueueTrack stands at (doorX, -5), in front of the right jamb.
static func interior_lineup_point(host: Node, index: int) -> Vector3:
	var origin := find_interior_origin(host, index)
	if origin == null:
		return Vector3.ZERO
	var other := find_interior_origin(host, 1 - index)
	var into := Vector3(0.0, 0.0, 1.0)
	if other != null:
		into = origin.global_position - other.global_position
		into.y = 0.0
	if into.length_squared() < 0.0001:
		into = Vector3(0.0, 0.0, 1.0)
	else:
		into = into.normalized()
	var side := into.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	else:
		side = side.normalized()
	return origin.global_position - into * 5.0 + side * 1.5


static func outside_drop(building: Node3D, index: int) -> Dictionary:
	var origin := _find_exact(building, "door_origin_%d" % index)
	var point := _approach(building, index, 8.0)
	var heading := 0.0
	if origin != null:
		heading = _heading(point - origin.global_position)
	return {"point": point, "heading": heading}


static func inside_drop(host: Node, index: int) -> Dictionary:
	var origin := find_interior_origin(host, index)
	var other := find_interior_origin(host, 1 - index)
	if origin == null:
		return {"point": Vector3(0.0, 0.2, 0.0), "heading": 0.0}
	var toward := Vector3(0.0, 0.0, -1.0)
	if other != null:
		toward = other.global_position - origin.global_position
		toward.y = 0.0
	if toward.length_squared() < 0.0001:
		toward = Vector3(0.0, 0.0, -1.0)
	else:
		toward = toward.normalized()
	# avatarExitTrack finishes six units through the doorway, facing into the room.
	var point := origin.global_position + toward * 6.0
	return {"point": point, "heading": _heading(toward)}


static func seal(door: Node3D) -> void:
	if door == null:
		return
	var flat := _flat(door)
	if flat != null:
		flat.visible = true
	for part_name in _PANELS:
		var part := _find_starting(door, part_name)
		if part != null:
			part.visible = false


static func open(host: Node, door: Node3D) -> void:
	if door == null:
		return
	var flat := _flat(door)
	for part_name in ["doorFrameHoleRight", "doorFrameHoleLeft"]:
		var hole := _find_starting(door, part_name)
		if hole != null and flat != null and flat.is_ancestor_of(hole):
			var kept := hole.global_transform
			hole.reparent(door)
			hole.global_transform = kept
	# The right leaf swings. The flat frame stays, and the opening is black.
	_MOTION.open_in(host, door)


static func _approach(building: Node3D, index: int, gap: float) -> Vector3:
	var door := find_exterior_door(building, index)
	var origin := _find_exact(building, "door_origin_%d" % index)
	var spot := _doorway(door, origin)
	var forward := _outward(building, origin, spot)
	var point := spot + forward * gap
	if origin != null:
		point.y = origin.global_position.y
	return point


static func _doorway(door: Node3D, origin: Node3D) -> Vector3:
	var spot := origin.global_position if origin != null else Vector3.ZERO
	if door == null:
		return spot
	var left := _find_starting(door, "leftDoor")
	var right := _find_starting(door, "rightDoor")
	if left != null and right != null:
		spot = (left.global_position + right.global_position) * 0.5
	elif origin != null:
		spot = origin.global_position
	if origin != null:
		spot.y = origin.global_position.y
	return spot


static func _outward(building: Node3D, origin: Node3D, spot: Vector3) -> Vector3:
	var axis := Vector3(0.0, 0.0, 1.0)
	if origin != null:
		axis = origin.global_transform.basis.y
		axis.y = 0.0
		if axis.length_squared() < 0.0001:
			axis = Vector3(0.0, 0.0, 1.0)
		else:
			axis = axis.normalized()
	var other := _find_exact(building, "door_origin_0")
	var mate := _find_exact(building, "door_origin_1")
	var inside := building.global_position
	if other != null and mate != null:
		inside = (other.global_position + mate.global_position) * 0.5
	if (spot + axis).distance_squared_to(inside) < spot.distance_squared_to(inside):
		axis = -axis
	return axis


static func _heading(dir: Vector3) -> float:
	var flat := dir
	flat.y = 0.0
	if flat.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(atan2(-flat.x, -flat.z))


static func _flat(door: Node3D) -> Node3D:
	return _find_starting(door, "door_flat")


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


static func _find_starting(node: Node, prefix: String) -> Node3D:
	if node is Node3D and str(node.name).begins_with(prefix):
		return node as Node3D
	for child in node.get_children():
		var found := _find_starting(child, prefix)
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


static func tint_interior(host: Node) -> void:
	var color := _MOTION.shown_color(door_color())
	for index in 2:
		var door := find_interior_door(host, index)
		if door == null:
			continue
		for part_name in ["leftDoor", "rightDoor"]:
			_tint_tree(_find_starting(door, part_name), color)


static func _tint_tree(node: Node, color: Color) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var source := mesh.get_active_material(0)
		if source is StandardMaterial3D:
			var copy := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
			copy.albedo_color = color
			mesh.material_override = copy
	for child in node.get_children():
		_tint_tree(child, color)


static func _find_hq(node: Node) -> Node3D:
	if node is Node3D:
		var node_name := str(node.name)
		if node_name.contains("toon_landmark_hq") and node_name.ends_with("_DNARoot"):
			return node as Node3D
	for child in node.get_children():
		var found := _find_hq(child)
		if found != null:
			return found
	return null
