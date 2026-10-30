extends Node3D

## The portable hole from phase_3.5 portal-mod. Its channel is one joint,
## scale_portal, played at 24 fps. Matrices stay in Panda's Z-up space because
## the toon root already turns that space upright.

const _MODEL := "res://assets/props/portal.glb"
const _CLIP := "res://assets/props/portal_hole.json"

var _joint: Node3D
var _frames: Array[Transform3D] = []


func setup() -> void:
	var packed := load(_MODEL) as PackedScene
	if packed == null:
		return
	var model := packed.instantiate()
	add_child(model)
	_joint = find_child("scale_portal", true, false) as Node3D
	_open_hole(model)
	_read_clip()
	pose_at(0.0)


func pose_at(seconds: float) -> void:
	if _joint == null or _frames.size() <= 1:
		return
	var time := clampf(seconds * 24.0, 0.0, float(_frames.size() - 1))
	var frame := mini(int(time), _frames.size() - 1)
	var following := mini(frame + 1, _frames.size() - 1)
	var blend := 0.0 if following == frame else time - float(frame)
	var from := _frames[frame]
	if blend <= 0.001:
		_joint.transform = from
		return
	_joint.transform = _blend(from, _frames[following], blend)


func _blend(from: Transform3D, to: Transform3D, weight: float) -> Transform3D:
	# Column lerp keeps the squash and the spin. Basis.slerp would force the hole round.
	var basis := Basis()
	basis.x = from.basis.x.lerp(to.basis.x, weight)
	basis.y = from.basis.y.lerp(to.basis.y, weight)
	basis.z = from.basis.z.lerp(to.basis.z, weight)
	return Transform3D(basis, from.origin.lerp(to.origin, weight))


func _open_hole(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var mesh := mesh_instance.mesh
		if mesh != null:
			for index in mesh.get_surface_count():
				var standard := mesh.surface_get_material(index) as StandardMaterial3D
				if standard == null:
					continue
				var sided := standard.duplicate() as StandardMaterial3D
				sided.cull_mode = BaseMaterial3D.CULL_DISABLED
				sided.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mesh_instance.set_surface_override_material(index, sided)
	for child in node.get_children():
		_open_hole(child)


func _read_clip() -> void:
	if not FileAccess.file_exists(_CLIP):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_CLIP))
	if not parsed is Dictionary:
		return
	var record: Dictionary = parsed
	var rows: Array = record.get("matrices", [])
	for row in rows:
		if not row is Array:
			continue
		var cells := PackedFloat32Array()
		cells.resize(16)
		var values: Array = row
		if values.size() < 16:
			continue
		for index in 16:
			cells[index] = float(values[index])
		_frames.append(_matrix(cells))


func _matrix(cells: PackedFloat32Array) -> Transform3D:
	# Same cell order as the glTF joint, without orthonormalizing, so the
	# hole can squash flat and spin as it opens.
	var basis := Basis(
		Vector3(cells[0], cells[1], cells[2]),
		Vector3(cells[4], cells[5], cells[6]),
		Vector3(cells[8], cells[9], cells[10])
	)
	return Transform3D(basis, Vector3(cells[12], cells[13], cells[14]))
