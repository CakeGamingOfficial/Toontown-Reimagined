extends RefCounted

## KartShopBuildingAI hangs two practical doors on the Goofy Speedway landmark
## and the matching pair inside KartShop_Interior. door_index is 1 or 2, the
## same index DistributedDoor uses. The closed panels are already in the model.
## There is no flat slab to swap in.

const OPEN_SFX := "res://assets/interiors/hq/Door_Open_1.ogg"
const CLOSE_SFX := "res://assets/interiors/hq/Door_Close_1.ogg"

# Goofy Speedway is the only playground with this shop.
static var hood: int = 8000
# "in" arrives inside the shop. "out" returns to the sidewalk at door_index.
static var trip := ""
static var door_index := 1


static func prepare(host: Node) -> void:
	var building := find_building(host)
	if building == null:
		return
	for index in [1, 2]:
		_hide_holes(find_exterior_door(building, index))


static func find_building(host: Node) -> Node3D:
	return _find_suffix(host, "kart_shop_DNARoot")


static func find_exterior_door(building: Node, index: int) -> Node3D:
	return _find_exact(building, "door_%d" % index)


static func find_interior_door(host: Node, index: int) -> Node3D:
	return _find_exact(host, "door_%d" % index)


static func find_interior_origin(host: Node, index: int) -> Node3D:
	return _find_exact(host, "door_origin_%d" % index)


static func outside_trigger(building: Node3D, index: int) -> Vector3:
	return _approach(building, index, 2.0)


## avatarEnterDoorTrack walks to (doorX, 2) on the door, into the building.
static func enter_frame(building: Node3D, index: int) -> Dictionary:
	var door := find_exterior_door(building, index)
	var origin := _find_exact(building, "door_origin_%d" % index)
	var mouth := _doorway(door, origin)
	return {"mouth": mouth, "outward": _outward(building, index)}


## Walk out through this interior door, two units past the doorway.
static func interior_enter_point(host: Node, index: int) -> Vector3:
	var origin := find_interior_origin(host, index)
	if origin == null:
		return Vector3.ZERO
	var outward := _outward(host, index)
	var side := Vector3.UP.cross(outward)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	else:
		side = side.normalized()
	return origin.global_position + outward * 2.0 + side * 1.5


static func outside_drop(building: Node3D, index: int) -> Dictionary:
	var origin := _find_exact(building, "door_origin_%d" % index)
	var point := _approach(building, index, 8.0)
	var heading := 0.0
	if origin != null:
		heading = _heading(point - origin.global_position)
	return {"point": point, "heading": heading}


static func inside_drop(host: Node, index: int) -> Dictionary:
	var origin := find_interior_origin(host, index)
	if origin == null:
		return {"point": Vector3(0.0, 0.2, 0.0), "heading": 0.0}
	# avatarExitTrack finishes six units through the doorway, facing into the room.
	var inward := -_outward(host, index)
	var point := origin.global_position + inward * 6.0
	return {"point": point, "heading": _heading(inward)}


static func open(host: Node, door: Node3D) -> void:
	if door == null:
		return
	_sound(host, OPEN_SFX)
	for part_name in ["doorFrameHoleRight", "doorFrameHoleLeft"]:
		var hole := _find_starting(door, part_name)
		if hole != null:
			hole.visible = true
	_swing(host, _find_starting(door, "rightDoor"), 100.0)
	_swing(host, _find_starting(door, "leftDoor"), -100.0)


static func hide_interior_holes(host: Node) -> void:
	for index in [1, 2]:
		_hide_holes(find_interior_door(host, index))


static func _approach(building: Node3D, index: int, gap: float) -> Vector3:
	var door := find_exterior_door(building, index)
	var origin := _find_exact(building, "door_origin_%d" % index)
	var spot := _doorway(door, origin)
	var point := spot + _outward(building, index) * gap
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


## The two doors sit on opposite faces. Outward is away from the other door.
static func _outward(building: Node, index: int) -> Vector3:
	var origin := _find_exact(building, "door_origin_%d" % index)
	var mate := _find_exact(building, "door_origin_%d" % (1 if index == 2 else 2))
	var axis := Vector3(0.0, 0.0, 1.0)
	if origin != null and mate != null:
		axis = origin.global_position - mate.global_position
		axis.y = 0.0
	if axis.length_squared() < 0.0001:
		axis = Vector3(0.0, 0.0, 1.0)
	else:
		axis = axis.normalized()
	return axis


static func _heading(dir: Vector3) -> float:
	var flat := dir
	flat.y = 0.0
	if flat.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(atan2(-flat.x, -flat.z))


static func _hide_holes(door: Node3D) -> void:
	if door == null:
		return
	for part_name in ["doorFrameHoleRight", "doorFrameHoleLeft"]:
		var hole := _find_starting(door, part_name)
		if hole != null:
			hole.visible = false


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
	if node is Node3D and _is_part(str(node.name), prefix):
		return node as Node3D
	for child in node.get_children():
		var found := _find_starting(child, prefix)
		if found != null:
			return found
	return null


## leftDoor2 is a repeated panel. leftDoorGeom is the mesh under it.
static func _is_part(name: String, prefix: String) -> bool:
	if name == prefix:
		return true
	if not name.begins_with(prefix):
		return false
	return name.substr(prefix.length()).is_valid_int()


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


static func _find_suffix(node: Node, suffix: String) -> Node3D:
	if node is Node3D and str(node.name).ends_with(suffix):
		return node as Node3D
	for child in node.get_children():
		var found := _find_suffix(child, suffix)
		if found != null:
			return found
	return null
