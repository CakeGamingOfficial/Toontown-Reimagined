extends RefCounted

## DistributedDoor.enterOpening for every toon door except Toon Hall.
## The right panel swings. The flat stays: its border is the door frame.
## A black card on each side of that flat covers the painted doors, so the
## opening is black and the frame around it remains.

const OPEN_SFX := "res://assets/interiors/hq/Door_Open_1.ogg"
const CLOSE_SFX := "res://assets/interiors/hq/Door_Close_1.ogg"


static func shown_color(dna: Color) -> Color:
	return dna.linear_to_srgb()


static func open_in(host: Node, door: Node3D) -> bool:
	return _swing_named(host, door, "rightDoor", "doorFrameHoleRight", 100.0, 0.4)


static func close_in(host: Node, door: Node3D, play_sound: bool = true) -> bool:
	return _close_named(host, door, "rightDoor", "doorFrameHoleRight", 100.0, play_sound)


static func _swing_named(host: Node, door: Node3D, panel_name: String, hole_name: String, degrees: float, delay: float) -> bool:
	if door == null:
		return false
	var panel := find_part(door, panel_name)
	if panel == null:
		return false
	_sound(host, OPEN_SFX)
	if not panel.has_meta("closed_basis"):
		panel.set_meta("closed_basis", panel.transform.basis)
	var hole := find_part(door, hole_name)
	var tween := host.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(_show_panel.bind(door, panel, hole))
	tween.tween_method(_set_swing.bind(panel), 0.0, degrees, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return true


static func _close_named(host: Node, door: Node3D, panel_name: String, hole_name: String, degrees: float, play_sound: bool) -> bool:
	if door == null:
		return false
	var panel := find_part(door, panel_name)
	if panel == null or not panel.has_meta("closed_basis"):
		return false
	var hole := find_part(door, hole_name)
	var tween := host.create_tween()
	tween.tween_method(_set_swing.bind(panel), degrees, 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_hide_panel.bind(door, hole))
	if play_sound:
		tween.tween_callback(_sound.bind(host, CLOSE_SFX))
	return true


static func _show_panel(door: Node3D, panel: Node3D, hole: Node3D) -> void:
	if not is_instance_valid(door) or not is_instance_valid(panel):
		return
	var flat := _flat(door)
	# Only the leaf that swings comes out. The other leaf stays hidden behind
	# the flat, which is where its picture already is.
	_lift(door, flat, panel)
	_dress_panel(panel, flat)
	panel.visible = true
	for part_name in ["leftDoor", "rightDoor"]:
		var other := find_part(door, part_name)
		if other != null and other != panel:
			other.visible = false
	if hole != null and is_instance_valid(hole):
		_lift(door, flat, hole)
		_blacken(hole)
		hole.visible = true
	if flat != null and is_instance_valid(flat):
		_flat_tests_depth(flat)
		flat.visible = true


static func _hide_panel(door: Node3D, hole: Node3D) -> void:
	for part_name in ["leftDoor", "rightDoor"]:
		var part := find_part(door, part_name)
		if part != null and is_instance_valid(part):
			part.visible = false
	if hole != null and is_instance_valid(hole):
		hole.visible = false
	var flat := _flat(door)
	if flat != null and is_instance_valid(flat):
		flat.visible = true


static func _dress_panel(panel: Node3D, flat: Node3D) -> void:
	if panel.has_meta("door_paint"):
		return
	panel.set_meta("door_paint", true)
	var flat_mesh := _first_mesh(flat)
	var flat_mat: StandardMaterial3D = null
	if flat_mesh != null:
		flat_mat = flat_mesh.get_active_material(0) as StandardMaterial3D
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(panel, meshes)
	for mesh in meshes:
		var source := mesh.get_active_material(0) as StandardMaterial3D
		if source == null:
			continue
		var copy := source.duplicate() as StandardMaterial3D
		copy.cull_mode = BaseMaterial3D.CULL_DISABLED
		# Landmark HQ leaves are a gray shell with the windows cut out, so the
		# faces have no picture. A solid door of the same outline keeps the
		# thickness and uses the closed door's picture on both faces.
		if copy.albedo_texture == null and flat_mat != null and flat_mat.albedo_texture != null:
			mesh.visible = false
			_add_door_model(panel, mesh, flat_mesh, flat_mat)
			continue
		mesh.material_override = copy


static func _flat_tests_depth(flat: Node3D) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(flat, meshes)
	for mesh in meshes:
		var source := mesh.get_active_material(0) as StandardMaterial3D
		if source == null or mesh.material_override != null:
			continue
		var copy := source.duplicate() as StandardMaterial3D
		copy.no_depth_test = false
		mesh.material_override = copy


static func _add_door_model(panel: Node3D, shell: MeshInstance3D, flat_mesh: MeshInstance3D, flat_mat: StandardMaterial3D) -> void:
	if panel.has_meta("door_card") or shell.mesh == null:
		return
	panel.set_meta("door_card", true)
	var box := shell.get_aabb()
	var low := box.position
	var high := box.position + box.size
	var size := box.size
	var depth := 1
	if size.x <= size.y and size.x <= size.z:
		depth = 0
	elif size.z <= size.x and size.z <= size.y:
		depth = 2
	# A flat rectangle as tall as the whole shell sticks through the arch at
	# the hinge. The shell's own top edge is lower there, and that is what
	# sits in the frame.
	var up := _up_axis(shell, depth)
	var width := 3 - depth - up
	var facing := _up_sign(shell, up)
	var tops := _end_tops(shell, width, up, facing, low, high)
	var corners := _door_corners(low, high, width, up, facing, tops)
	# Quads. The two ends along the door's thickness get the door picture.
	# The rim is the door color, so the edge reads as a solid panel.
	var picture: Array[PackedInt32Array] = []
	var rim: Array[PackedInt32Array] = []
	if depth == 1:
		picture = [PackedInt32Array([3, 2, 6, 7]), PackedInt32Array([0, 4, 5, 1])]
		rim = [PackedInt32Array([0, 1, 2, 3]), PackedInt32Array([4, 7, 6, 5]), PackedInt32Array([0, 3, 7, 4]), PackedInt32Array([1, 5, 6, 2])]
	elif depth == 0:
		picture = [PackedInt32Array([1, 2, 6, 5]), PackedInt32Array([0, 4, 7, 3])]
		rim = [PackedInt32Array([0, 1, 5, 4]), PackedInt32Array([3, 7, 6, 2]), PackedInt32Array([0, 3, 2, 1]), PackedInt32Array([4, 5, 6, 7])]
	else:
		picture = [PackedInt32Array([4, 5, 6, 7]), PackedInt32Array([0, 3, 2, 1])]
		rim = [PackedInt32Array([0, 4, 7, 3]), PackedInt32Array([1, 2, 6, 5]), PackedInt32Array([0, 1, 5, 4]), PackedInt32Array([3, 7, 6, 2])]
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var edge := Vector2.ZERO
	for quad_index in picture.size():
		var quad: PackedInt32Array = picture[quad_index]
		var face_uv: Array[Vector2] = []
		for index in quad:
			face_uv.append(_uv_on_flat(shell, flat_mesh, corners[index]))
		if quad_index == 0:
			for uv in face_uv:
				edge += uv
			edge /= float(face_uv.size())
		_add_quad(verts, uvs, indices, corners, quad, face_uv)
	var edge_uvs: Array[Vector2] = [edge, edge, edge, edge]
	for quad in rim:
		_add_quad(verts, uvs, indices, corners, quad, edge_uvs)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var door := MeshInstance3D.new()
	door.name = "DoorModel"
	door.mesh = ArrayMesh.new()
	(door.mesh as ArrayMesh).add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	door.transform = shell.transform
	var mat := flat_mat.duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.vertex_color_use_as_albedo = false
	door.material_override = mat
	door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.add_child(door)


static func _up_axis(shell: MeshInstance3D, depth: int) -> int:
	var basis := Basis.IDENTITY
	if shell.is_inside_tree():
		basis = shell.global_transform.basis
	var columns: Array[Vector3] = [basis.x, basis.y, basis.z]
	var axis := 0
	var best := -1.0
	for index in 3:
		if index == depth:
			continue
		var score := absf(columns[index].y)
		if score > best:
			best = score
			axis = index
	return axis


static func _up_sign(shell: MeshInstance3D, up: int) -> float:
	if not shell.is_inside_tree():
		return 1.0
	var column := shell.global_transform.basis.x
	if up == 1:
		column = shell.global_transform.basis.y
	elif up == 2:
		column = shell.global_transform.basis.z
	return -1.0 if column.y < 0.0 else 1.0


static func _end_tops(shell: MeshInstance3D, width: int, up: int, facing: float, low: Vector3, high: Vector3) -> Vector2:
	var fallback := high[up] if facing > 0.0 else low[up]
	var low_top := fallback
	var high_top := fallback
	var have_low := false
	var have_high := false
	var span: float = high[width] - low[width]
	var band := absf(span) * 0.3
	var arrays: Array = shell.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for vert in verts:
		var along: float = vert[width]
		var height: float = vert[up]
		if along <= low[width] + band:
			if not have_low or height * facing > low_top * facing:
				low_top = height
				have_low = true
		if along >= high[width] - band:
			if not have_high or height * facing > high_top * facing:
				high_top = height
				have_high = true
	return Vector2(low_top, high_top)


static func _door_corners(low: Vector3, high: Vector3, width: int, up: int, facing: float, tops: Vector2) -> Array[Vector3]:
	var xs := [low.x, high.x]
	var ys := [low.y, high.y]
	var zs := [low.z, high.z]
	var order: Array = [
		[0, 0, 0], [1, 0, 0], [1, 1, 0], [0, 1, 0],
		[0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1],
	]
	var top_bit := 1 if facing > 0.0 else 0
	var corners: Array[Vector3] = []
	for bits in order:
		var point := Vector3(xs[bits[0]], ys[bits[1]], zs[bits[2]])
		if int(bits[up]) == top_bit:
			var top: float = tops.x if int(bits[width]) == 0 else tops.y
			if up == 0:
				point.x = top
			elif up == 1:
				point.y = top
			else:
				point.z = top
		corners.append(point)
	return corners


static func _add_quad(verts: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, corners: Array[Vector3], quad: PackedInt32Array, corner_uvs: Array[Vector2]) -> void:
	var start := verts.size()
	for index in 4:
		verts.append(corners[quad[index]])
		uvs.append(corner_uvs[index])
	indices.append_array(PackedInt32Array([start, start + 1, start + 2, start, start + 2, start + 3]))


static func _uv_on_flat(shell: MeshInstance3D, flat_mesh: MeshInstance3D, corner: Vector3) -> Vector2:
	var flat_arrays: Array = flat_mesh.mesh.surface_get_arrays(0)
	var flat_uv = flat_arrays[Mesh.ARRAY_TEX_UV]
	var flat_verts: PackedVector3Array = flat_arrays[Mesh.ARRAY_VERTEX]
	if flat_uv == null or flat_verts.is_empty():
		return Vector2.ZERO
	var flat_uvs: PackedVector2Array = flat_uv
	var u_at_min_x := _edge_uv(flat_verts, flat_uvs, true, true)
	var u_at_max_x := _edge_uv(flat_verts, flat_uvs, true, false)
	var v_at_min_z := _edge_uv(flat_verts, flat_uvs, false, true)
	var v_at_max_z := _edge_uv(flat_verts, flat_uvs, false, false)
	var bounds := flat_mesh.get_aabb()
	var on_flat: Vector3 = flat_mesh.global_transform.affine_inverse() * shell.to_global(corner)
	var across := _span(on_flat.x, bounds.position.x, bounds.position.x + bounds.size.x)
	var along := _span(on_flat.z, bounds.position.z, bounds.position.z + bounds.size.z)
	return Vector2(lerpf(u_at_min_x, u_at_max_x, across), lerpf(v_at_min_z, v_at_max_z, along))


static func _edge_uv(verts: PackedVector3Array, uvs: PackedVector2Array, use_x: bool, take_min: bool) -> float:
	var limit := verts[0].x if use_x else verts[0].z
	for vert in verts:
		var value := vert.x if use_x else vert.z
		limit = minf(limit, value) if take_min else maxf(limit, value)
	var total := 0.0
	var count := 0
	for index in verts.size():
		var value := verts[index].x if use_x else verts[index].z
		if absf(value - limit) > 0.05:
			continue
		total += uvs[index].x if use_x else uvs[index].y
		count += 1
	if count == 0:
		return 0.0
	return total / float(count)


static func _span(value: float, low: float, high: float) -> float:
	if absf(high - low) < 0.0001:
		return 0.0
	return clampf((value - low) / (high - low), 0.0, 1.0)


static func _blacken(hole: Node3D) -> void:
	if hole.has_meta("door_black"):
		return
	hole.set_meta("door_black", true)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0, 0, 1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(hole, meshes)
	for mesh in meshes:
		mesh.material_override = mat
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Door skins sit near local -0.09 and +0.29. The flat is the plane
		# between them. One black card on each side covers the painted doors
		# from either face, and the frame outside the hole still shows.
		mesh.position.y += 0.15
		var back := mesh.duplicate() as MeshInstance3D
		back.position = Vector3(0.0, -0.3, 0.0)
		back.name = "Back"
		mesh.add_child(back)


static func _lift(door: Node3D, flat: Node3D, part: Node3D) -> void:
	if flat == null or part == null or not flat.is_ancestor_of(part):
		return
	var kept := part.global_transform
	part.reparent(door)
	part.global_transform = kept


static func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	if node == null:
		return null
	for child in node.get_children():
		var found := _first_mesh(child)
		if found != null:
			return found
	return null


static func _collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, meshes)


static func _flat(door: Node3D) -> Node3D:
	var named := find_part(door, "door_flat")
	if named != null:
		return named
	return _find_ending(door, "_flat")


static func _find_ending(node: Node, suffix: String) -> Node3D:
	if node is Node3D and _strip_digits(str(node.name)).ends_with(suffix):
		return node as Node3D
	for child in node.get_children():
		var found := _find_ending(child, suffix)
		if found != null:
			return found
	return null


static func find_part(node: Node, base: String) -> Node3D:
	if node is Node3D:
		var name := _strip_digits(str(node.name))
		if name == base or name.ends_with("_" + base):
			return node as Node3D
	for child in node.get_children():
		var found := find_part(child, base)
		if found != null:
			return found
	return null


static func _strip_digits(name: String) -> String:
	var end := name.length()
	while end > 0 and name.substr(end - 1, 1).is_valid_int():
		end -= 1
	# Landmark doors are rightDoor_0. Stripping the digits leaves the underscore.
	if end < name.length() and end > 0 and name.substr(end - 1, 1) == "_":
		end -= 1
	return name.substr(0, end)


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
