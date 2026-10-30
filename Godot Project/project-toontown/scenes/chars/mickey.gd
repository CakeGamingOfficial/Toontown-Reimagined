class_name Mickey
extends Node3D

## Classic Mickey from phase_3/models/char/mickey-1200. Clips are baked the
## same way as the Flunky: the mesh is the posed vertices, and the ear and
## pupil joints follow the skeleton. The ear joint stays on that pose. The
## street billboard yaws flat signs and would twist these ears off his head.

const _MODEL := "res://assets/chars/mickey.glb"
const _CLIPS: Array[String] = ["wait", "run", "left-start", "left", "right-start", "right"]

var _banks: Dictionary = {}


func _ready() -> void:
	var packed := load(_MODEL) as PackedScene
	if packed == null:
		return
	var model := packed.instantiate()
	add_child(model)
	for clip_name in _CLIPS:
		_banks[clip_name] = _read_bank("res://assets/chars/mickey." + clip_name)
	# The banks already hold the joint. Drop the billboard name before the
	# cutscene collects signs, or the ears are turned after every pose.
	_rename_ears(self)
	_show_both_sides()
	_seat_pupils()


func loaded() -> bool:
	return not _banks.is_empty()


## elapsed is seconds. A negative rate plays from the last frame backward.
## loop wraps the run and the point holds. A one-shot holds the last frame.
func pose(clip_name: String, elapsed: float, rate: float, loop: bool) -> void:
	var bank: Dictionary = _banks.get(clip_name, {})
	var frames := int(bank.get("frames", 0))
	var clips: Array = bank.get("clips", [])
	if frames <= 1 or clips.is_empty():
		return
	var cursor := elapsed * 24.0 * absf(rate)
	if rate < 0.0:
		cursor = float(frames - 1) - cursor
	if loop and rate > 0.0:
		cursor = fposmod(cursor, float(frames))
	else:
		cursor = clampf(cursor, 0.0, float(frames - 1))
	var frame := mini(int(cursor), frames - 1)
	var following := frame
	var blend := 0.0
	if loop and rate > 0.0:
		following = (frame + 1) % frames
		blend = cursor - float(frame)
	elif frame < frames - 1:
		following = frame + 1
		blend = cursor - float(frame)
	_apply_pose(clips, bank.get("joints", []), frame, following, blend)


func _rename_ears(node: Node) -> void:
	if String(node.name).begins_with("sphere3"):
		node.name = "sphere3"
	for child in node.get_children():
		_rename_ears(child)


func _show_both_sides() -> void:
	var seen: Array[Material] = []
	for child in find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var part := String(mesh_node.name)
		for index in mesh_node.mesh.get_surface_count():
			var material := mesh_node.mesh.surface_get_material(index)
			if material == null or material in seen:
				continue
			seen.append(material)
			if material is BaseMaterial3D:
				var standard := material as BaseMaterial3D
				standard.cull_mode = BaseMaterial3D.CULL_DISABLED
				# The eye and pupil cards are tiny. Mipmaps push the alpha
				# cutoff around while he holds a point, so the eyes pop.
				if part == "eyes" or part.begins_with("pupil"):
					standard.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
					# Draw the whites, then the pupils, after the head.
					standard.render_priority = 2 if part.begins_with("pupil") else 1


## The pupil cards sit on the eye whites. A couple of centimeters along the
## joint's +Y, which stays pointed out of the face, keeps them from fighting
## the whites while a dialogue line loops.
func _seat_pupils() -> void:
	for part in ["pupilL", "pupilR"]:
		var card := _find(self, part) as MeshInstance3D
		if card == null:
			continue
		card.position.y += 0.02
		card.sorting_offset = 0.02


func _apply_pose(clips: Array, joints: Array, frame: int, following: int, blend: float) -> void:
	for clip in clips:
		var record: Dictionary = clip
		var instance := record["instance"] as MeshInstance3D
		if not is_instance_valid(instance):
			continue
		var original := record["original"] as Mesh
		var surfaces: Array = record["surfaces"]
		var posed := ArrayMesh.new()
		for surface_index in surfaces.size():
			var surface: Dictionary = surfaces[surface_index]
			var frames: Array = surface["frames"]
			if frames.is_empty():
				continue
			var positions: PackedVector3Array = frames[frame % frames.size()]
			if blend > 0.001:
				var nxt: PackedVector3Array = frames[following % frames.size()]
				var mixed := PackedVector3Array()
				mixed.resize(positions.size())
				for index in positions.size():
					mixed[index] = positions[index].lerp(nxt[index], blend)
				positions = mixed
			var uvs: PackedVector2Array = surface["uv"]
			if positions.is_empty():
				continue
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = positions
			if uvs.size() == positions.size():
				arrays[Mesh.ARRAY_TEX_UV] = uvs
			arrays[Mesh.ARRAY_NORMAL] = _face_normals(positions)
			posed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			if surface_index < original.get_surface_count():
				posed.surface_set_material(posed.get_surface_count() - 1, original.surface_get_material(surface_index))
		if posed.get_surface_count() == 0:
			instance.visible = false
			continue
		instance.visible = true
		instance.mesh = posed
	for joint in joints:
		var record: Dictionary = joint
		var node := record["node"] as Node3D
		if not is_instance_valid(node):
			continue
		var frames: Array = record["frames"]
		var posed_frame: Transform3D = frames[frame % frames.size()]
		if blend > 0.001:
			var nxt: Transform3D = frames[following % frames.size()]
			posed_frame.origin = posed_frame.origin.lerp(nxt.origin, blend)
			posed_frame.basis = Basis(
				posed_frame.basis.x.lerp(nxt.basis.x, blend),
				posed_frame.basis.y.lerp(nxt.basis.y, blend),
				posed_frame.basis.z.lerp(nxt.basis.z, blend)
			)
		# The clip stores each joint in the same space as the baked body.
		# The glTF rest is only the wait pose, so a delta from that rest
		# leaves the ears and pupils behind when he runs or points.
		node.transform = posed_frame


func _face_normals(positions: PackedVector3Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(positions.size())
	var index := 0
	while index + 2 < positions.size():
		var edge_a := positions[index + 1] - positions[index]
		var edge_b := positions[index + 2] - positions[index]
		var normal := edge_a.cross(edge_b)
		if normal.length_squared() < 0.000001:
			normal = Vector3.UP
		else:
			normal = normal.normalized()
		normals[index] = normal
		normals[index + 1] = normal
		normals[index + 2] = normal
		index += 3
	return normals


func _read_bank(path: String) -> Dictionary:
	var clips: Array = []
	var joints: Array = []
	if not FileAccess.file_exists(path):
		return {"clips": clips, "joints": joints, "frames": 0}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"clips": clips, "joints": joints, "frames": 0}
	var magic := file.get_buffer(8)
	if magic.slice(0, 6).get_string_from_ascii() != "TWALK3":
		file.close()
		return {"clips": clips, "joints": joints, "frames": 0}
	var frame_count := file.get_32()
	var node_count := file.get_32()
	for _node_index in node_count:
		var name_len := file.get_16()
		var node_name := file.get_buffer(name_len).get_string_from_utf8()
		var surface_count := file.get_32()
		var surfaces: Array = []
		for _surface_index in surface_count:
			var vertex_count := file.get_32()
			var has_uv := file.get_8()
			var uvs := PackedVector2Array()
			if has_uv != 0:
				uvs.resize(vertex_count)
				for index in vertex_count:
					uvs[index] = Vector2(file.get_float(), file.get_float())
			var frames: Array = []
			for _frame_index in frame_count:
				var positions := PackedVector3Array()
				positions.resize(vertex_count)
				for index in vertex_count:
					positions[index] = Vector3(file.get_float(), file.get_float(), file.get_float())
				frames.append(positions)
			surfaces.append({"uv": uvs, "frames": frames})
		var instance := _find(self, node_name) as MeshInstance3D
		if instance != null and instance.mesh != null and not surfaces.is_empty():
			clips.append({
				"instance": instance,
				"original": instance.mesh,
				"surfaces": surfaces,
			})
	var joint_count := file.get_32()
	for _joint_index in joint_count:
		var name_len := file.get_16()
		var joint_name := file.get_buffer(name_len).get_string_from_utf8()
		var bind_cells := PackedFloat32Array()
		bind_cells.resize(16)
		for cell in 16:
			bind_cells[cell] = file.get_float()
		var frames: Array = []
		for _frame_index in frame_count:
			var cells := PackedFloat32Array()
			cells.resize(16)
			for cell in 16:
				cells[cell] = file.get_float()
			frames.append(_transform_from_panda(cells))
		var joint := _find(self, joint_name) as Node3D
		if joint != null and not frames.is_empty():
			joints.append({
				"node": joint,
				"rest": joint.transform,
				"bind": _transform_from_panda(bind_cells),
				"frames": frames,
			})
	file.close()
	return {"clips": clips, "joints": joints, "frames": frame_count}


func _transform_from_panda(cells: PackedFloat32Array) -> Transform3D:
	var x := Vector3(cells[0], cells[1], cells[2])
	var y := Vector3(cells[4], cells[5], cells[6])
	var z := Vector3(cells[8], cells[9], cells[10])
	var origin := Vector3(cells[12], cells[13], cells[14])
	return Transform3D(Basis(x, y, z), origin)


func _find(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find(child, wanted)
		if found:
			return found
	return null
