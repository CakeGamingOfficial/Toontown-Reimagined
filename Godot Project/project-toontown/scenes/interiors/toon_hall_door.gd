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
# The painted flat is nudged 0.28 toward the street. The leaves have to sit
# in front of that card or the frame hides the opening.
const _PIVOT := Vector3(23.324, -3.36, 0.55)
# DNA color on sz13:toon_landmark_TT_toonhall. The landmark stores these
# numbers as a linear baseColorFactor, and the closed cutout shows that
# import. Color() reads sRGB, so the panels use the converted color.
const _DNA := Color(0.87988, 0.4502, 0.37988, 1.0)

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
		if part == null:
			continue
		if part_name.contains("Hole"):
			_blacken(part)
		part.visible = false


## DistributedDoor.enterOpening. Going through uses the right door: the open
## sound starts, the panel waits 0.4s, then eases to heading 100 over 0.6s.
## rightSwing is set, which is the default swing of 3.
static func open(host: Node, door: Node3D) -> void:
	_swing_named(host, door, "rightDoor", "doorFrameHoleRight", 100.0, 0.4)


## exitDoorEnterOpening. Coming out of a doorway uses the left door, and that
## swing starts immediately. leftSwing makes the heading -100.
static func open_out(host: Node, door: Node3D) -> void:
	_swing_named(host, door, "leftDoor", "doorFrameHoleLeft", -100.0, 0.0)


## enterClosing / exitDoorEnterClosing. One second back to shut, then the close
## sound, and the flat slab takes the place of the panel.
static func close_out(host: Node, door: Node3D) -> void:
	_close_named(host, door, "leftDoor", "doorFrameHoleLeft", -100.0)


static func door_point(building: Node3D, door: Node3D, door_x: float, door_y: float) -> Vector3:
	# Door space matches DistributedDoor: +X is the right jamb, +Y is into the
	# building. door_y below zero stands out on the sidewalk.
	var outward := _forward(building, door)
	var side := Vector3.UP.cross(outward)
	side.y = 0.0
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	else:
		side = side.normalized()
	var origin := _doorway(door)
	var shell := 0.0
	if door_y < 0.0:
		_approach(building, door, 0.0)
		if door.has_meta("hall_shell"):
			shell = float(door.get_meta("hall_shell"))
	var out_dist := -door_y
	if out_dist > 0.0:
		out_dist += shell
	var point := origin + outward * out_dist + side * door_x
	point.y = door.global_position.y
	return point


static func face_heading(building: Node3D, door: Node3D, into: bool) -> float:
	var outward := _forward(building, door)
	if into:
		outward = -outward
	return _heading(outward)


## avatarExitTrack. The camera snaps inside the doorway at (-doorX, 5, height)
## with heading 180, so it looks back out while the toon walks to -6.
static func exit_camera(building: Node3D, door: Node3D, feet_y: float, height: float) -> Dictionary:
	var outward := _forward(building, door)
	var cam := door_point(building, door, -1.5, 5.0)
	cam.y = feet_y + height
	var look := cam + outward * 8.0
	look.y = cam.y
	return {"pos": cam, "look": look}


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
	_tint(door, _DNA.linear_to_srgb())


static func _tint(door: Node3D, color: Color) -> void:
	for part_name in ["leftDoor", "rightDoor"]:
		var part := _find_exact(door, part_name)
		if part != null:
			_tint_tree(part, color)


## doorFrameHole is the black opening behind the swinging panel. The exterior
## copy was taking the door color, and the interior copy was exported pale
## yellow. Either one sits on the wall plane and shimmers through the doorway.
static func _blacken(hole: Node3D) -> void:
	if hole.has_meta("hall_black"):
		return
	hole.set_meta("hall_black", true)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0, 0, 1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(hole, meshes)
	for mesh in meshes:
		mesh.material_override = mat
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Door skins are near -0.09 and +0.29. The flat frame is the plane
		# between them. The black card stays behind the skin the viewer sees.
		var street := _under_pivot(hole)
		mesh.position.y += -0.03 if street else 0.03
		if street:
			continue
		var parent := mesh.get_parent()
		if parent == null:
			continue
		var back := mesh.duplicate() as MeshInstance3D
		back.position.y = -0.03
		back.name = str(mesh.name) + "Back"
		parent.add_child(back)


static func _under_pivot(node: Node) -> bool:
	var cursor := node
	while cursor != null:
		if str(cursor.name) == "DoorPivot":
			return true
		cursor = cursor.get_parent()
	return false


static func _collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, meshes)


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


static func _swing_named(host: Node, door: Node3D, panel_name: String, hole_name: String, degrees: float, delay: float) -> void:
	if door == null:
		return
	var panel := _find_exact(door, panel_name)
	if panel == null:
		return
	_sound(host, OPEN_SFX)
	if not panel.has_meta("closed_basis"):
		panel.set_meta("closed_basis", panel.transform.basis)
	var hole := _find_exact(door, hole_name)
	var tween := host.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(_show_panel.bind(door, panel, hole))
	tween.tween_method(_set_swing.bind(panel), 0.0, degrees, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


static func _close_named(host: Node, door: Node3D, panel_name: String, hole_name: String, degrees: float) -> void:
	if door == null:
		return
	var panel := _find_exact(door, panel_name)
	if panel == null or not panel.has_meta("closed_basis"):
		return
	var hole := _find_exact(door, hole_name)
	var tween := host.create_tween()
	tween.tween_method(_set_swing.bind(panel), degrees, 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_hide_panel.bind(door, panel, hole))
	tween.tween_callback(_sound.bind(host, CLOSE_SFX))


static func _show_panel(door: Node3D, panel: Node3D, hole: Node3D) -> void:
	if not is_instance_valid(panel):
		return
	# Both leaves stay on screen for the whole swing. The flat frame stays too.
	var shown := 0
	for part_name in ["leftDoor", "rightDoor"]:
		var part := _find_exact(door, part_name)
		if part == null:
			continue
		_keep_door_texture(part)
		part.visible = true
		shown += 1
	if shown == 0:
		return
	# door_flat is the frame around the leaves. It stays up for the whole swing.
	if hole != null:
		hole.visible = true


static func _keep_door_texture(panel: Node3D) -> void:
	if panel.has_meta("hall_paint"):
		return
	panel.set_meta("hall_paint", true)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(panel, meshes)
	for mesh in meshes:
		var source := mesh.get_active_material(0) as StandardMaterial3D
		if source == null:
			continue
		var copy := source.duplicate() as StandardMaterial3D
		copy.cull_mode = BaseMaterial3D.CULL_DISABLED
		if _under_pivot(panel):
			# The closed cutout is an unshaded card. A lit panel in front of it
			# reads as a redder door the moment the swing starts.
			copy.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			copy.vertex_color_use_as_albedo = false
			copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			copy.alpha_scissor_threshold = 0.5
		else:
			copy.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		mesh.material_override = copy


static func _hide_panel(door: Node3D, _panel: Node3D, hole: Node3D) -> void:
	for part_name in ["leftDoor", "rightDoor"]:
		var part := _find_exact(door, part_name)
		if part != null and is_instance_valid(part):
			part.visible = false
	if hole != null and is_instance_valid(hole):
		hole.visible = false
	var flat := _flat(door)
	if flat != null and is_instance_valid(flat):
		flat.visible = true


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
