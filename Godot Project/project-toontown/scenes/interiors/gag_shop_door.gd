extends RefCounted

## DistributedGagshopInterior hangs door_double_round_ur on the room's
## door_origin. The playground landmark already has the closed slab from DNA.
## DistributedDoor swings the practical panels, which the neighborhood export
## did not keep, so those are instanced from doors.glb the first time the
## playground loads.

const DOORS := "res://assets/interiors/gag_shop/doors.glb"
const OPEN_SFX := "res://assets/interiors/hq/Door_Open_1.ogg"
const CLOSE_SFX := "res://assets/interiors/hq/Door_Close_1.ogg"
const _PANELS: Array[String] = ["leftDoor", "rightDoor", "doorFrameHoleRight", "doorFrameHoleLeft"]

# The playground this room belongs to. Set before the scene change.
static var hood: int = 2000
# "in" arrives inside the shop. "out" returns to the sidewalk.
static var trip := ""


static func prepare(host: Node, playground: int) -> void:
	var building := find_building(host)
	if building == null:
		return
	var door := find_exterior_door(building)
	if door == null:
		return
	_add_panels(door, playground)
	seal(door)


static func find_building(host: Node) -> Node3D:
	return _find_suffix(host, "_gag_shop_DNARoot")


static func find_exterior_door(building: Node) -> Node3D:
	return _find_door_root(building)


static func find_interior_door(host: Node) -> Node3D:
	return _find_exact(host, "door_0")


static func outside_drop(building: Node3D, door: Node3D) -> Dictionary:
	# Far enough past the front wall that the toon is not still inside the trigger.
	var point := _approach(building, door, 6.5)
	return {"point": point, "heading": _heading(point - door.global_position)}


static func outside_trigger(building: Node3D, door: Node3D) -> Vector3:
	# Just outside the door, on the street side. The old point sat past the
	# wall, so walking up to the door never entered it.
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


static func _add_panels(door: Node3D, playground: int) -> void:
	if _find_exact(door, "leftDoor") != null:
		return
	var packed := load(DOORS) as PackedScene
	if packed == null:
		return
	var root := packed.instantiate()
	# Godot numbers a repeated node, so door_double_square_ur2 is still that door.
	var source := root.find_child(_strip_digits(str(door.name)), true, false) as Node3D
	if source == null:
		root.free()
		return
	for part_name in _PANELS:
		var part := _find_base(source, part_name)
		if part == null:
			continue
		var kept := part.transform
		var old := part.get_parent()
		if old != null:
			old.remove_child(part)
		part.owner = null
		door.add_child(part)
		part.name = part_name
		part.transform = kept
	root.free()
	_tint(door, _color(playground))


static func _color(playground: int) -> Color:
	# DNA door colors on each playground's gag shop landmark.
	match playground:
		2000:
			return Color(1.0, 0.63, 0.38, 1.0)
		3000:
			return Color(0.23, 0.85, 0.6, 1.0)
		4000:
			return Color(1.0, 0.79, 0.49, 1.0)
		5000:
			return Color(0.8, 0.54, 0.61, 1.0)
		_:
			return Color(1.0, 1.0, 1.0, 1.0)


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
	if not door.has_meta("shop_shell"):
		var measured := _facade(door, forward)
		if measured >= 0.0:
			door.set_meta("shop_shell", measured)
		else:
			var tries := 0
			if door.has_meta("shop_tries"):
				tries = int(door.get_meta("shop_tries"))
			tries += 1
			if tries >= 8:
				door.set_meta("shop_shell", 0.0)
			else:
				door.set_meta("shop_tries", tries)
	var shell := 0.0
	if door.has_meta("shop_shell"):
		shell = float(door.get_meta("shop_shell"))
	var point := door.global_position + forward * (shell + gap)
	point.y = door.global_position.y
	return point


static func _forward(building: Node3D, door: Node3D) -> Vector3:
	if door.has_meta("shop_forward"):
		return door.get_meta("shop_forward")
	# The practical door's trigger polygon faces along the door's local Y.
	var axis := door.global_transform.basis.y
	axis.y = 0.0
	if axis.length_squared() < 0.0001:
		axis = Vector3(0.0, 0.0, 1.0)
	else:
		axis = axis.normalized()
	var center := _center(building)
	var outward := door.global_position + axis
	if outward.distance_squared_to(center) < door.global_position.distance_squared_to(center):
		axis = -axis
	door.set_meta("shop_forward", axis)
	return axis


static func _facade(door: Node3D, forward: Vector3) -> float:
	# -1 means the trimesh is not in the physics space yet. The caller retries.
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
	var chest := door.global_position + Vector3(0.0, 1.2, 0.0)
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
		var along := _xz_dot(point - door.global_position, forward)
		var lateral := absf(_xz_dot(point - door.global_position, side))
		# Outermost solid in the doorway. A roof hat's bounding box is ignored
		# because the ray is at chest height and only counts real triangles.
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
	var speaker := AudioStreamPlayer.new()
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
