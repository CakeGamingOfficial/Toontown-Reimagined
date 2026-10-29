class_name Flunky
extends Node3D

## The tutorial Flunky from DistributedTutorialInterior.createSuit: a bossbot
## C-body with the flunky head, pacing outside the shop window.

const _MODEL := "res://assets/cogs/flunky.glb"
const _WALK := "res://assets/cogs/flunky.walk"

var _clips: Array[Dictionary] = []
var _joints: Array[Dictionary] = []
var _frame_count := 1
var _walk_time := 0.0
var _moving := false
var _goal := Vector3.ZERO
var _heading := 0.0
var _wait := 0.0
var _leg := 0
var _pacing := false


func _ready() -> void:
	var packed := load(_MODEL) as PackedScene
	if packed == null:
		return
	var model := packed.instantiate()
	add_child(model)
	_load_walk()


func pace_outside() -> void:
	# Panda (-20, 8, 0) to (-20, 20, 0), then back to (-20, 10, 0).
	position = Vector3(-20.0, 0.0, -8.0)
	_heading = 0.0
	_leg = 0
	_wait = 0.0
	_pacing = true
	_face()
	_begin_leg()


func _process(delta: float) -> void:
	if not _pacing:
		return
	if _wait > 0.0:
		_wait -= delta
		_set_moving(false)
		return
	var flat := Vector2(position.x, position.z)
	var target := Vector2(_goal.x, _goal.z)
	var remaining := flat.distance_to(target)
	var speed := remaining / maxf(_leg_time_left(), 0.05)
	if remaining < 0.05:
		position.x = _goal.x
		position.z = _goal.z
		_finish_leg()
		return
	var step := minf(speed * delta, remaining)
	var toward := (target - flat).normalized()
	position.x += toward.x * step
	position.z += toward.y * step
	_leg_left = maxf(_leg_left - delta, 0.0)
	_set_moving(true)
	_pose(delta)


var _leg_left := 0.0


func _begin_leg() -> void:
	# 0: walk to the far side of the window. 1: pause and turn.
	# 2: walk back. 3: pause and face the window again.
	match _leg % 4:
		0:
			_goal = Vector3(-20.0, 0.0, -20.0)
			_heading = 0.0
			_leg_left = 2.0
		1:
			_heading = 180.0
			_wait = 1.0
			_leg_left = 0.0
		2:
			_goal = Vector3(-20.0, 0.0, -10.0)
			_heading = 180.0
			_leg_left = 2.0
		3:
			_heading = 0.0
			_wait = 1.0
			_leg_left = 0.0
	_face()


func _finish_leg() -> void:
	_leg += 1
	_begin_leg()


func _leg_time_left() -> float:
	return maxf(_leg_left, 0.05)


func _face() -> void:
	rotation.y = deg_to_rad(_heading)


func _set_moving(moving: bool) -> void:
	if _moving == moving:
		return
	_moving = moving
	if not moving:
		_restore()


func _pose(delta: float) -> void:
	if _frame_count <= 1:
		return
	_walk_time = fposmod(_walk_time + delta * 24.0, float(_frame_count))
	if _walk_time >= float(_frame_count):
		_walk_time = 0.0
	var frame := mini(int(_walk_time), _frame_count - 1)
	var following := (frame + 1) % _frame_count
	var blend := _walk_time - float(frame)
	for clip in _clips:
		var instance := clip["instance"] as MeshInstance3D
		if not is_instance_valid(instance):
			continue
		var original := clip["original"] as Mesh
		var surfaces: Array = clip["surfaces"]
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
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = positions
			var uvs: PackedVector2Array = surface["uv"]
			if uvs.size() == positions.size():
				arrays[Mesh.ARRAY_TEX_UV] = uvs
			posed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			if surface_index < original.get_surface_count():
				posed.surface_set_material(surface_index, original.surface_get_material(surface_index))
		instance.mesh = posed
	for joint in _joints:
		var node := joint["node"] as Node3D
		if not is_instance_valid(node):
			continue
		var frames: Array = joint["frames"]
		var posed_frame: Transform3D = frames[frame % frames.size()]
		if blend > 0.001:
			var nxt: Transform3D = frames[following % frames.size()]
			posed_frame.origin = posed_frame.origin.lerp(nxt.origin, blend)
			posed_frame.basis = posed_frame.basis.slerp(nxt.basis, blend)
		var bind: Transform3D = joint["bind"]
		var rest: Transform3D = joint["rest"]
		node.transform = rest * bind.affine_inverse() * posed_frame


func _restore() -> void:
	for clip in _clips:
		var instance := clip["instance"] as MeshInstance3D
		if is_instance_valid(instance):
			instance.mesh = clip["original"]
	for joint in _joints:
		var node := joint["node"] as Node3D
		if is_instance_valid(node):
			node.transform = joint["rest"]


func _load_walk() -> void:
	if not FileAccess.file_exists(_WALK):
		return
	var file := FileAccess.open(_WALK, FileAccess.READ)
	if file == null:
		return
	var magic := file.get_buffer(8)
	if magic.slice(0, 6).get_string_from_ascii() != "TWALK3":
		file.close()
		return
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
			_frame_count = maxi(_frame_count, frame_count)
			_clips.append({
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
			_joints.append({
				"node": joint,
				"rest": joint.transform,
				"bind": _transform_from_panda(bind_cells),
				"frames": frames,
			})
	file.close()


func _transform_from_panda(cells: PackedFloat32Array) -> Transform3D:
	var basis := Basis(
		Vector3(cells[0], cells[1], cells[2]),
		Vector3(cells[4], cells[5], cells[6]),
		Vector3(cells[8], cells[9], cells[10])
	)
	basis = basis.orthonormalized()
	return Transform3D(basis, Vector3(cells[12], cells[13], cells[14]))


func _find(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find(child, wanted)
		if found:
			return found
	return null
