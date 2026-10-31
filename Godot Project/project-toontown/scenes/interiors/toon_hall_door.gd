extends RefCounted

## DistributedToonHallInterior hangs door_double_round_ur on the room's
## door_origin. The playground landmark already has the closed slab from DNA.
## The swinging panels live in doors.glb, placed on toonhall_door_origin.

const DOORS := "res://assets/interiors/toon_hall/doors.glb"
const OPEN_SFX := "res://assets/interiors/hq/Door_Open_1.ogg"
const CLOSE_SFX := "res://assets/interiors/hq/Door_Close_1.ogg"
const _PANELS: Array[String] = ["leftDoor", "rightDoor", "doorFrameHoleRight", "doorFrameHoleLeft"]
# phase_4 toonhall.bam node toonhall_door_origin, in the landmark's own space.
# The neighborhood export baked the slab's vertices and left this node at the
# building origin, so the panels take the marker's placement.
const _PIVOT := Vector3(23.324, -3.0, 0.55)
# DNA color on sz13:toon_landmark_TT_toonhall.
const _COLOR := Color(0.88, 0.45, 0.38, 1.0)

# "in" arrives inside the hall. "out" returns to the sidewalk.
static var trip := ""


static func prepare(host: Node) -> void:
	var building := find_building(host)
	if building == null:
		return
	var door := find_exterior_door(building)
	if door == null:
		return
	_add_panels(door)
	seal(door)


static func find_building(host: Node) -> Node3D:
	return _find_suffix(host, "toonhall_DNARoot")


static func find_exterior_door(building: Node) -> Node3D:
	return _find_door_root(building)


static func find_interior_door(host: Node) -> Node3D:
	return _find_exact(host, "door_0")


static func outside_drop(building: Node3D, door: Node3D) -> Dictionary:
	# Past the front wall, and past the 2.4 step that opens the door.
	var point := _approach(building, door, 8.0)
	return {"point": point, "heading": _heading(point - _doorway(door))}


static func outside_trigger(building: Node3D, door: Node3D) -> Vector3:
	return _approach(building, door, 1.2)


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
	_sound(host, OPEN_SFX)
	var flat := _flat(door)
	if flat != null:
		flat.visible = false
	for part_name in _PANELS:
		var part := _find_exact(door, part_name)
		if part != null:
			part.visible = true
	_swing(host, _find_exact(door, "rightDoor"), 100.0)
	_swing(host, _find_exact(door, "leftDoor"), -100.0)


static func _add_panels(door: Node3D) -> void:
	if _find_exact(door, "leftDoor") != null:
		return
	var packed := load(DOORS) as PackedScene
	if packed == null:
		return
	var root := packed.instantiate()
	var source := root.find_child(_strip_digits(str(door.name)), true, false) as Node3D
	if source == null:
		root.free()
		return
	var pivot := Node3D.new()
	pivot.name = "DoorPivot"
	pivot.position = _PIVOT
	door.add_child(pivot)
	for part_name in _PANELS:
		var part := _find_base(source, part_name)
		if part == null:
			continue
		var kept := part.transform
		var old := part.get_parent()
		if old != null:
			old.remove_child(part)
		part.owner = null
		pivot.add_child(part)
		part.name = part_name
		part.transform = kept
	root.free()
	_tint(door, _COLOR)


static func _tint(door: Node3D, color: Color) -> void:
	for part_name in _PANELS:
		var part := _find_exact(door, part_name)
		if part != null:
			_tint_tree(part, color)


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
	if not door.has_meta("hall_shell"):
		var measured := _facade(door, forward, origin)
		if measured >= 0.0:
			door.set_meta("hall_shell", measured)
		else:
			var tries := 0
			if door.has_meta("hall_tries"):
				tries = int(door.get_meta("hall_tries"))
			tries += 1
			if tries >= 8:
				door.set_meta("hall_shell", 0.0)
			else:
				door.set_meta("hall_tries", tries)
	var shell := 0.0
	if door.has_meta("hall_shell"):
		shell = float(door.get_meta("hall_shell"))
	var point := origin + forward * (shell + gap)
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
	if door.has_meta("hall_forward"):
		return door.get_meta("hall_forward")
	var axis := door.global_transform.basis.y
	axis.y = 0.0
	if axis.length_squared() < 0.0001:
		axis = Vector3(0.0, 0.0, 1.0)
	else:
		axis = axis.normalized()
	var center := _center(building)
	var spot := _doorway(door)
	var outward := spot + axis
	if outward.distance_squared_to(center) < spot.distance_squared_to(center):
		axis = -axis
	door.set_meta("hall_forward", axis)
	return axis


static func _facade(door: Node3D, forward: Vector3, origin: Vector3) -> float:
	var world := door.get_world_3d()
	if world == null:
		return -1.0
	var space := world.direct_space_state
	if space == null:
		return -1.0
	var side := door.global_transform.basis.x
	side.y = 0.0
	if side.length_squared() < 0.0001:
		side = Vector3(-forward.z, 0.0, forward.x)
	else:
		side = side.normalized()
	var chest := origin + Vector3(0.0, 1.2, 0.0)
	var start := chest + forward * 24.0
	var exclude: Array[RID] = []
	var best := -1.0
	var guard := 0
	while guard < 16:
		guard += 1
		var query := PhysicsRayQueryParameters3D.create(start, chest)
		query.exclude = exclude
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		var point: Vector3 = hit.position
		var along := _xz_dot(point - origin, forward)
		var lateral := absf(_xz_dot(point - origin, side))
		if lateral <= 2.2 and along > best and along < 14.0:
			best = along
		var rid: RID = hit.rid
		exclude.append(rid)
		start = point - forward * 0.25
		if _xz_dot(start - chest, forward) < 0.3:
			break
	return best


static func _xz_dot(point: Vector3, forward: Vector3) -> float:
	return point.x * forward.x + point.z * forward.z


static func _center(root: Node) -> Vector3:
	var acc := {"min": Vector3(INF, INF, INF), "max": Vector3(-INF, -INF, -INF), "n": 0}
	_bounds(root, acc)
	if int(acc["n"]) == 0 and root is Node3D:
		return (root as Node3D).global_position
	var lo: Vector3 = acc["min"]
	var hi: Vector3 = acc["max"]
	return (lo + hi) * 0.5


static func _bounds(node: Node, acc: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null and mesh.visible:
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			var lo: Vector3 = acc["min"]
			var hi: Vector3 = acc["max"]
			acc["min"] = lo.min(box.position)
			acc["max"] = hi.max(box.end)
			acc["n"] = int(acc["n"]) + 1
	for child in node.get_children():
		_bounds(child, acc)


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


static func _strip_digits(name: String) -> String:
	var end := name.length()
	while end > 0 and name.substr(end - 1, 1).is_valid_int():
		end -= 1
	return name.substr(0, end)


static func _find_base(node: Node, base: String) -> Node3D:
	if node is Node3D and _strip_digits(str(node.name)) == base:
		return node as Node3D
	for child in node.get_children():
		var found := _find_base(child, base)
		if found != null:
			return found
	return null


static func _is_door_root(name: String) -> bool:
	return name.begins_with("door_double_") and not name.contains("flat") and not name.contains("hole") and not name.ends_with("_left") and not name.ends_with("_right")


static func _find_suffix(node: Node, suffix: String) -> Node3D:
	if node is Node3D and str(node.name).ends_with(suffix):
		return node as Node3D
	for child in node.get_children():
		var found := _find_suffix(child, suffix)
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
