extends Node

## Decoration.py. The globe, banners, heart, cannons, bandstands, and tube cog
## play the original clips. Banner pictures swap at 4 frames a second, heart
## wings at 12, and the cake fuse at 20. The bandstands and the tube cog loop
## their show sounds. Cog statues and ice creams wobble a few degrees.

const _DANCE := "res://assets/parties/sfx/tt_s_ara_pty_propsShow_dance.ogg"
const _WAVE := "res://assets/parties/sfx/tt_s_ara_pty_tubeCogVictory_wave.ogg"
const _AUDIO := preload("res://scenes/audio/toon_audio.gd")

const _CLIP := {
	10: "res://assets/parties/decor/anims/gag_globe.pty",
	11: "res://assets/parties/decor/anims/bean_banner.pty",
	14: "res://assets/parties/decor/anims/heart_banner.pty",
	15: "res://assets/parties/decor/anims/flying_heart.pty",
	16: "res://assets/parties/decor/anims/hydra.pty",
	17: "res://assets/parties/decor/anims/banner_victory.pty",
	18: "res://assets/parties/decor/anims/cannon_victory.pty",
	20: "res://assets/parties/decor/anims/tube_cog.pty",
	23: "res://assets/parties/decor/anims/stage_winter.pty",
}

var _id := -1
var _frames := 0
var _fps := 24.0
var _net := false
var _joint_nodes: Array[Node3D] = []
var _joint_frames: Array[PackedFloat32Array] = []
var _bind_global: Array[Transform3D] = []
var _skins: Array = []
var _age := 0.0
var _shown := -1.0
var _billboard: Node3D
var _billboard_rest := Basis.IDENTITY
var _balloons: Array[MeshInstance3D] = []
var _pages: Array[Node3D] = []
var _page_rate := 0.0
var _wobble := false
var _wobble_rest := Basis.IDENTITY
var _wobble_from := Vector3.ZERO
var _wobble_to := Vector3.ZERO
var _wobble_left := 0.0
var _wobble_wait := 0.0
var _sound: AudioStreamPlayer3D
var _sound_span := 0.0


static func dress(model: Node, id: int) -> void:
	if not _CLIP.has(id) and id != 12 and id != 19 and id != 21 and id != 22 and id != 24:
		return
	var decor := load("res://scenes/parties/party_decor.gd").new() as Node
	decor.name = "PartyDecor"
	decor.set_meta("decor_id", id)
	model.add_child(decor)


func _ready() -> void:
	_id = int(get_meta("decor_id", -1))
	var host := get_parent() as Node3D
	if host == null:
		return
	_load_clip(String(_CLIP.get(_id, "")))
	_capture_bind()
	_pages_for(host)
	_balloons_for(host)
	if _id == 10:
		_billboard = _find(host, "GagGlobe") as Node3D
		if _billboard == null:
			_billboard = host
		_billboard_rest = _billboard.global_transform.basis
	if _id == 16 or _id == 23 or _id == 20:
		_age = float(randi_range(0, 10))
		_sound_span = _frames / _fps if _fps > 0.0 else 0.0
		_start_sound(_DANCE if _id != 20 else _WAVE)
	if _id == 19 or _id == 21 or _id == 22 or _id == 24:
		_wobble = true
		_wobble_rest = host.basis
		_wobble_to = _random_tilt()
		_wobble_left = 3.0


func _process(delta: float) -> void:
	_age += delta
	if _frames > 0:
		if not _net:
			_pose_joints()
		_pose_skins()
	if _page_rate > 0.0 and not _pages.is_empty():
		var page := posmod(int(_age * _page_rate), _pages.size())
		for page_node in _pages:
			page_node.visible = false
		_pages[page].visible = true
	if _wobble:
		_tilt(delta)
	if _billboard != null:
		_face_camera()
	_sync_sound()


func _load_clip(path: String) -> void:
	if path == "" or not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var magic := file.get_buffer(8)
	if magic.get_string_from_ascii() != "PTYJNT1":
		file.close()
		return
	_frames = file.get_32()
	_fps = file.get_float()
	var joint_count := file.get_16()
	_net = file.get_8() != 0
	var host := get_parent()
	for _joint_index in joint_count:
		var name_len := file.get_16()
		var joint_name := file.get_buffer(name_len).get_string_from_utf8()
		var packed := PackedFloat32Array()
		packed.resize(_frames * 12)
		for cell in packed.size():
			packed[cell] = file.get_float()
		var joint := _find(host, joint_name) as Node3D
		_joint_nodes.append(joint)
		_joint_frames.append(packed)
	var skin_count := file.get_16()
	for _skin_index in skin_count:
		var name_len := file.get_16()
		var mesh_name := file.get_buffer(name_len).get_string_from_utf8()
		var surface_count := file.get_16()
		var mesh := _find(host, mesh_name) as MeshInstance3D
		var surfaces: Array = []
		for _surface_index in surface_count:
			var count := file.get_32()
			var lookup := {}
			for _vertex_index in count:
				var point := Vector3(file.get_float(), file.get_float(), file.get_float())
				var joints := Vector4i(file.get_8(), file.get_8(), file.get_8(), file.get_8())
				var weights := Vector4(file.get_float(), file.get_float(), file.get_float(), file.get_float())
				lookup[_position_key(point)] = [joints, weights]
			surfaces.append(lookup)
		if mesh != null and mesh.mesh != null:
			_skins.append({"mesh": mesh, "original": mesh.mesh, "surfaces": surfaces})
	file.close()


func _capture_bind() -> void:
	_bind_global.resize(_joint_nodes.size())
	for index in _joint_nodes.size():
		var joint := _joint_nodes[index]
		if joint == null:
			_bind_global[index] = Transform3D.IDENTITY
		else:
			_bind_global[index] = joint.global_transform


func _pose_joints() -> void:
	var sample: float = _age * _fps
	var frame := posmod(int(floor(sample)), _frames)
	var following := (frame + 1) % _frames
	var blend: float = sample - floor(sample)
	for index in _joint_nodes.size():
		var joint := _joint_nodes[index]
		if joint == null:
			continue
		var frames := _joint_frames[index]
		var posed := _transform_at(frames, frame)
		var nxt := _transform_at(frames, following)
		var basis := Basis(
			posed.basis.x.lerp(nxt.basis.x, blend),
			posed.basis.y.lerp(nxt.basis.y, blend),
			posed.basis.z.lerp(nxt.basis.z, blend)
		)
		joint.transform = Transform3D(basis, posed.origin.lerp(nxt.origin, blend))


func _pose_skins() -> void:
	for entry in _skins:
		var mesh := entry["mesh"] as MeshInstance3D
		var original := entry["original"] as Mesh
		var surfaces: Array = entry["surfaces"]
		if mesh == null or original == null:
			continue
		var skin: Array[Transform3D] = []
		skin.resize(_joint_frames.size())
		var sample: float = _age * _fps
		var frame := posmod(int(floor(sample)), _frames)
		var following := (frame + 1) % _frames
		var blend: float = sample - floor(sample)
		for index in _joint_frames.size():
			var posed := _transform_at(_joint_frames[index], frame)
			var nxt := _transform_at(_joint_frames[index], following)
			var basis := Basis(
				posed.basis.x.lerp(nxt.basis.x, blend),
				posed.basis.y.lerp(nxt.basis.y, blend),
				posed.basis.z.lerp(nxt.basis.z, blend)
			)
			var current := Transform3D(basis, posed.origin.lerp(nxt.origin, blend))
			var bind := _transform_at(_joint_frames[index], 0)
			skin[index] = current * bind.affine_inverse()
		var baked := ArrayMesh.new()
		var count := mini(original.get_surface_count(), surfaces.size())
		for surface_index in count:
			var arrays := original.surface_get_arrays(surface_index)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var lookup: Dictionary = surfaces[surface_index]
			var moved := PackedVector3Array()
			var turned := PackedVector3Array()
			moved.resize(positions.size())
			if not normals.is_empty():
				turned.resize(normals.size())
			for vertex in positions.size():
				var found: Variant = lookup.get(_position_key(positions[vertex]))
				if found == null:
					moved[vertex] = positions[vertex]
					if vertex < turned.size():
						turned[vertex] = normals[vertex]
					continue
				var record: Array = found
				var joints: Vector4i = record[0]
				var weights: Vector4 = record[1]
				var point := Vector3.ZERO
				var normal := Vector3.ZERO
				var base_normal := normals[vertex] if vertex < normals.size() else Vector3.UP
				for slot in 4:
					var weight: float = weights[slot]
					if weight <= 0.0:
						continue
					var xform := skin[joints[slot]]
					point += xform * positions[vertex] * weight
					normal += xform.basis * base_normal * weight
				moved[vertex] = point
				if vertex < turned.size():
					turned[vertex] = normal.normalized() if normal.length_squared() > 0.000001 else base_normal
			arrays[Mesh.ARRAY_VERTEX] = moved
			if not turned.is_empty():
				arrays[Mesh.ARRAY_NORMAL] = turned
			baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			baked.surface_set_material(surface_index, original.surface_get_material(surface_index))
		for surface_index in range(count, original.get_surface_count()):
			var arrays := original.surface_get_arrays(surface_index)
			baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			baked.surface_set_material(surface_index, original.surface_get_material(surface_index))
		mesh.mesh = baked


func _pages_for(host: Node) -> void:
	if _id == 11:
		_page_rate = 4.0
		_add_page(host, "banner1")
		_add_page(host, "banner2")
	elif _id == 15:
		_page_rate = 12.0
		for wing_name in ["wing1", "wing2", "wing3", "wing4", "wing3", "wing2"]:
			_add_page(host, wing_name)
	elif _id == 12:
		_page_rate = 20.0
		_add_page(host, "tnt1__billboard")
		if _pages.is_empty():
			_add_page(host, "tnt1")
		_add_page(host, "tnt2__billboard")
		if _pages.size() == 1:
			_add_page(host, "tnt2")
	if _pages.size() > 1:
		for index in _pages.size():
			_pages[index].visible = index == 0


func _add_page(host: Node, node_name: String) -> void:
	var page := _find(host, node_name) as Node3D
	if page != null:
		_pages.append(page)


func _balloons_for(host: Node) -> void:
	if _id != 11 and _id != 14 and _id != 17:
		return
	for node_name in ["balloonsLMesh", "balloonsRMesh", "balloonsL", "balloonsR"]:
		var mesh := _find(host, node_name) as MeshInstance3D
		if mesh != null:
			_balloons.append(mesh)
			_billboard_mesh(mesh)


func _tilt(delta: float) -> void:
	var host := get_parent() as Node3D
	if host == null:
		return
	if _wobble_wait > 0.0:
		_wobble_wait -= delta
		if _wobble_wait <= 0.0:
			_wobble_from = _wobble_to
			_wobble_to = _random_tilt()
			_wobble_left = 3.0
		return
	_wobble_left -= delta
	var weight := 1.0
	if _wobble_left > 0.0:
		weight = 1.0 - _wobble_left / 3.0
	else:
		_wobble_wait = 0.05
		weight = 1.0
	var tilt := _wobble_from.lerp(_wobble_to, weight)
	var spin := Basis.from_euler(Vector3(deg_to_rad(tilt.x), deg_to_rad(tilt.y), deg_to_rad(tilt.z)))
	host.basis = _wobble_rest * spin


func _random_tilt() -> Vector3:
	return Vector3(randi_range(0, 5), randi_range(0, 5), randi_range(0, 5))


func _face_camera() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var face := Vector3(-_billboard_rest.y.x, 0.0, -_billboard_rest.y.z)
	var to_camera := camera.global_position - _billboard.global_position
	to_camera.y = 0.0
	if face.length() < 0.0001 or to_camera.length() < 0.0001:
		return
	var angle := face.signed_angle_to(to_camera, Vector3.UP)
	var turned := _billboard.global_transform
	turned.basis = _billboard_rest.rotated(Vector3.UP, angle)
	_billboard.global_transform = turned


func _start_sound(path: String) -> void:
	var stream := _AUDIO.stream(path)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	_sound = _AUDIO.effect_3d()
	_sound.stream = stream
	_sound.max_distance = 45.0
	_sound.unit_size = 15.0
	add_child(_sound)
	var into := 0.0
	if _sound_span > 0.0:
		into = fposmod(_age, _sound_span)
	_sound.play(into)
	_shown = into


func _sync_sound() -> void:
	if _sound == null or _sound_span <= 0.0:
		return
	var into := fposmod(_age, _sound_span)
	if _shown >= 0.0 and into < _shown:
		_sound.play(0.0)
	_shown = into


func _billboard_mesh(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null:
		return
	for surface in mesh.mesh.get_surface_count():
		var material := mesh.mesh.surface_get_material(surface)
		if material is BaseMaterial3D:
			var paint := (material as BaseMaterial3D).duplicate() as BaseMaterial3D
			paint.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
			paint.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.mesh.surface_set_material(surface, paint)


func _transform_at(frames: PackedFloat32Array, frame: int) -> Transform3D:
	var start := frame * 12
	var x := Vector3(frames[start], frames[start + 1], frames[start + 2])
	var y := Vector3(frames[start + 3], frames[start + 4], frames[start + 5])
	var z := Vector3(frames[start + 6], frames[start + 7], frames[start + 8])
	var origin := Vector3(frames[start + 9], frames[start + 10], frames[start + 11])
	return Transform3D(Basis(x, y, z), origin)


func _position_key(point: Vector3) -> int:
	var x := int(round(point.x * 64.0))
	var y := int(round(point.y * 64.0))
	var z := int(round(point.z * 64.0))
	return (x & 0x1FFFFF) | ((y & 0x1FFFFF) << 21) | ((z & 0x1FFFFF) << 42)


func _find(node: Node, wanted: String) -> Node:
	if node == null:
		return null
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find(child, wanted)
		if found != null:
			return found
	return null
