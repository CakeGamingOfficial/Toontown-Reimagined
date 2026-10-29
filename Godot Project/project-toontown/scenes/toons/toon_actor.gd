class_name ToonActor
extends Node3D

## Legs, torso, and head from the original 1000-LOD models, posed in neutral
## and assembled the way Toon.parentToonParts does: torso on joint_hips,
## head on def_head. The parts are still Z-up, so this node stands them up.

const _PARTS := "res://assets/toons/parts/"
const _HEADS := "res://assets/toons/heads/"
const _ANIMS := "res://assets/toons/anims/"
const _SHIRT := [
	preload("res://assets/toons/clothes/desat_shirt_1.png"),
	preload("res://assets/toons/clothes/desat_shirt_2.png"),
	preload("res://assets/toons/clothes/desat_shirt_3.png"),
]
const _SLEEVE := [
	preload("res://assets/toons/clothes/desat_sleeve_1.png"),
	preload("res://assets/toons/clothes/desat_sleeve_2.png"),
	preload("res://assets/toons/clothes/desat_sleeve_3.png"),
]
const _SHORTS := [
	preload("res://assets/toons/clothes/desat_shorts_1.png"),
	preload("res://assets/toons/clothes/desat_shorts_2.png"),
	preload("res://assets/toons/clothes/desat_shorts_4.png"),
]
const _SKIRT := preload("res://assets/toons/clothes/desat_skirt_1.png")

var _style: ToonStyle
var _walk_clips: Array = []
var _walk_joints: Array = []
var _walk_loaded := false
var _walk_missing := false
var _posing := false
var _walk_time := 0.0
var _frame_count := 0


func show_style(style: ToonStyle) -> void:
	_style = style
	_walk_clips.clear()
	_walk_joints.clear()
	_walk_loaded = false
	_walk_missing = false
	_posing = false
	_walk_time = 0.0
	_frame_count = 0
	for child in get_children():
		child.free()
	if style == null:
		return
	# Panda is Z-up. This basis makes a local (x, y, z) into Godot (x, z, -y),
	# then turns the toon around to face the Make a Toon camera.
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	upright = upright.rotated(Vector3.UP, PI)
	transform.basis = upright.scaled(Vector3.ONE * style.body_scale())
	var legs := _instance(_PARTS + "legs_%s.glb" % style.legs)
	if legs == null:
		return
	add_child(legs)
	var hips := _find(legs, "joint_hips")
	var torso := _instance(_PARTS + "torso_%s.glb" % style.torso)
	if torso and hips:
		hips.add_child(torso)
		var neck := _find(torso, "def_head")
		var head := _instance(_HEADS + "%s.glb" % style.head)
		if head and neck:
			neck.add_child(head)
	_paint(self, style)


## The original walk is 24 frames. Forward plays it at 24 fps. Backing up plays it in reverse.
## Frames live beside the standing models and are loaded the first time this toon moves,
## so Pick a Toon never has to instance a blend-shape mesh.
func set_locomotion(moving: bool, reverse: bool, delta: float) -> void:
	if _style == null:
		return
	if not moving:
		if _posing:
			_restore_posed_meshes()
			_posing = false
			_walk_time = 0.0
		return
	if not _walk_loaded:
		if _walk_missing:
			return
		_load_walk()
		if not _walk_loaded:
			_walk_missing = true
			return
	if not _posing:
		_walk_time = 0.0
		_posing = true
	var direction := -1.0 if reverse else 1.0
	_walk_time = fposmod(_walk_time + delta * 24.0 * direction, float(_frame_count))
	var frame := int(_walk_time)
	var following := (frame + 1) % _frame_count
	_pose_walk(frame, following, _walk_time - float(frame))


func _load_walk() -> void:
	var clips := [
		_read_walk(_ANIMS + "legs_%s.walk" % _style.legs),
		_read_walk(_ANIMS + "torso_%s.walk" % _style.torso),
	]
	for clip in clips:
		var surfaces_by_name: Dictionary = clip.get("surfaces", {})
		for node_name in surfaces_by_name.keys():
			var instance := _find(self, String(node_name)) as MeshInstance3D
			if instance == null or instance.mesh == null:
				continue
			var surfaces: Array = surfaces_by_name[node_name]
			if surfaces.is_empty():
				continue
			_frame_count = maxi(_frame_count, (surfaces[0]["frames"] as Array).size())
			_walk_clips.append({
				"instance": instance,
				"original": instance.mesh,
				"surfaces": surfaces,
			})
		var joints: Dictionary = clip.get("joints", {})
		for joint_name in joints.keys():
			var joint := _find(self, String(joint_name)) as Node3D
			var record: Dictionary = joints[joint_name]
			var frames: Array = record["frames"]
			if joint == null or frames.is_empty():
				continue
			_frame_count = maxi(_frame_count, frames.size())
			_walk_joints.append({
				"node": joint,
				"rest": joint.transform,
				"bind": record["bind"],
				"frames": frames,
			})
	_walk_loaded = _frame_count > 0 and not _walk_clips.is_empty()


func _read_walk(path: String) -> Dictionary:
	var result := {"surfaces": {}, "joints": {}}
	if not FileAccess.file_exists(path):
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result
	var magic := file.get_buffer(8)
	if magic.slice(0, 6).get_string_from_ascii() != "TWALK3":
		file.close()
		return result
	var frame_count := file.get_32()
	var node_count := file.get_32()
	var surfaces_by_name: Dictionary = {}
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
		surfaces_by_name[node_name] = surfaces
	var joints: Dictionary = {}
	var joint_count := file.get_32()
	for _joint_index in joint_count:
		var name_len := file.get_16()
		var joint_name := file.get_buffer(name_len).get_string_from_utf8()
		var frames: Array = []
		var bind_cells := PackedFloat32Array()
		bind_cells.resize(16)
		for cell in 16:
			bind_cells[cell] = file.get_float()
		for _frame_index in frame_count:
			var cells := PackedFloat32Array()
			cells.resize(16)
			for cell in 16:
				cells[cell] = file.get_float()
			frames.append(_transform_from_panda(cells))
		joints[joint_name] = {"bind": _transform_from_panda(bind_cells), "frames": frames}
	file.close()
	result["surfaces"] = surfaces_by_name
	result["joints"] = joints
	return result


func _transform_from_panda(cells: PackedFloat32Array) -> Transform3D:
	# Same reading as the glTF importer: Panda's row-vector matrix becomes a Godot basis.
	var basis := Basis(
		Vector3(cells[0], cells[1], cells[2]),
		Vector3(cells[4], cells[5], cells[6]),
		Vector3(cells[8], cells[9], cells[10])
	)
	basis = basis.orthonormalized()
	return Transform3D(basis, Vector3(cells[12], cells[13], cells[14]))


func _pose_walk(frame: int, following: int, blend: float) -> void:
	for clip in _walk_clips:
		var instance := clip["instance"] as MeshInstance3D
		if not is_instance_valid(instance):
			continue
		var original := clip["original"] as Mesh
		var surfaces: Array = clip["surfaces"]
		var posed := ArrayMesh.new()
		for surface_index in surfaces.size():
			var surface: Dictionary = surfaces[surface_index]
			var frames: Array = surface["frames"]
			var positions: PackedVector3Array = frames[frame]
			if blend > 0.001:
				var nxt: PackedVector3Array = frames[following]
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
	for joint in _walk_joints:
		var node := joint["node"] as Node3D
		if not is_instance_valid(node):
			continue
		var frames: Array = joint["frames"]
		if frames.is_empty():
			continue
		node.transform = _joint_pose(joint, frame, following, blend)


func _joint_pose(joint: Dictionary, frame: int, following: int, blend: float) -> Transform3D:
	var frames: Array = joint["frames"]
	var posed: Transform3D = frames[frame]
	if blend > 0.001:
		var nxt: Transform3D = frames[following]
		posed.origin = posed.origin.lerp(nxt.origin, blend)
		posed.basis = posed.basis.slerp(nxt.basis, blend)
	# The standing joint came from the glTF importer. Apply only the change from
	# that pose to the walk frame, so the hips and head are not twisted into the clothes.
	var bind: Transform3D = joint["bind"]
	var rest: Transform3D = joint["rest"]
	return rest * bind.affine_inverse() * posed


func _restore_posed_meshes() -> void:
	for clip in _walk_clips:
		var instance := clip["instance"] as MeshInstance3D
		if is_instance_valid(instance):
			instance.mesh = clip["original"]
	for joint in _walk_joints:
		var node := joint["node"] as Node3D
		if is_instance_valid(node):
			node.transform = joint["rest"]


func _instance(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as Node3D


func _paint(node: Node, style: ToonStyle) -> void:
	if String(node.name) == "eyelashes":
		node.visible = style.gender == "f"
	if node is MeshInstance3D:
		_paint_mesh(node as MeshInstance3D, style)
	for child in node.get_children():
		_paint(child, style)


func _paint_mesh(mesh: MeshInstance3D, style: ToonStyle) -> void:
	var part := _part_name(mesh)
	var face := _face_kind(part)
	if face != "":
		_apply_face(mesh, style, face)
		return
	var color := Color.WHITE
	var texture: Texture2D = null
	if part == "hands":
		color = ToonStyle.fur_color(style.glove_color)
	elif part == "arms" or part == "neck":
		color = ToonStyle.fur_color(style.arm_color)
	elif part == "legs" or part == "feet":
		color = ToonStyle.fur_color(style.leg_color)
	elif part.begins_with("head") or part.begins_with("ears"):
		color = ToonStyle.fur_color(style.head_color)
	elif part == "torso-top":
		color = ToonStyle.clothes_color(style.top_color)
		texture = _SHIRT[clampi(style.top_tex, 0, _SHIRT.size() - 1)]
	elif part == "sleeves":
		color = ToonStyle.clothes_color(style.top_color)
		texture = _SLEEVE[clampi(style.top_tex, 0, _SLEEVE.size() - 1)]
	elif part.begins_with("torso-bot"):
		color = ToonStyle.clothes_color(style.bot_color)
		if part.ends_with("cap"):
			color = color.darkened(0.35)
		texture = _bottom_texture(style)
	else:
		_unshade(mesh)
		return
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mesh.material_override = material


func _bottom_texture(style: ToonStyle) -> Texture2D:
	if style.wears_skirt():
		return _SKIRT
	if style.bot_tex == 1:
		return _SHORTS[1]
	# BoyShorts index 2 is desat_shorts_4. Make a Toon stays on 0 and 1.
	if style.bot_tex == 2:
		return _SHORTS[2]
	return _SHORTS[0]


func _part_name(mesh: MeshInstance3D) -> String:
	var part := String(mesh.name)
	# Pupil cards are unnamed meshes parented under def_left_pupil.
	if part == "node" or part == "":
		var parent := mesh.get_parent()
		if parent:
			part = String(parent.name)
	return part


func _face_kind(part: String) -> String:
	if part.begins_with("eyes"):
		return "eyes"
	if part.begins_with("muzzle"):
		return "muzzle"
	if part == "nose":
		return "nose"
	if part == "eyelashes" or part.begins_with("eyelash"):
		return "lashes"
	if part.contains("pupil"):
		return "pupil"
	if part.begins_with("head-front"):
		return "front"
	return ""


func _apply_face(mesh: MeshInstance3D, style: ToonStyle, kind: String) -> void:
	var source := mesh.mesh
	if source == null:
		return
	# Draw farther out than the head shell so a card cannot sink into it.
	# Eyes stay in the opaque pass (alpha scissor). Alpha blending sorted
	# those cards behind the head and left holes in the face.
	var scissor := 0.0
	var push := 0.002
	match kind:
		"front":
			push = 0.0015
		"muzzle":
			push = 0.003
		"nose":
			push = 0.004
		"eyes":
			scissor = 0.5
			push = 0.006
		"pupil":
			scissor = 0.5
			push = 0.008
		"lashes":
			scissor = 0.5
			push = 0.01
	mesh.material_override = null
	for surface in source.get_surface_count():
		var texture: Texture2D = null
		var color := Color.WHITE
		if kind == "front":
			color = ToonStyle.fur_color(style.head_color)
		else:
			var material := source.surface_get_material(surface)
			if material is BaseMaterial3D:
				var standard := material as BaseMaterial3D
				texture = standard.albedo_texture
				color = standard.albedo_color
		mesh.set_surface_override_material(surface, _face_material(texture, color, scissor, push))


func _face_material(texture: Texture2D, color: Color, scissor: float, push: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://scenes/toons/toon_face.gdshader")
	material.set_shader_parameter("albedo_color", color)
	material.set_shader_parameter("scissor_threshold", scissor)
	material.set_shader_parameter("surface_push", push)
	material.set_shader_parameter("use_albedo_texture", 1.0 if texture else 0.0)
	if texture:
		material.set_shader_parameter("albedo_texture", texture)
	return material


func _unshade(mesh: MeshInstance3D) -> void:
	var source := mesh.mesh
	if source == null:
		return
	for surface in source.get_surface_count():
		var material := source.surface_get_material(surface)
		if material is StandardMaterial3D:
			var unshaded := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
			unshaded.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			unshaded.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			mesh.set_surface_override_material(surface, unshaded)


func _find(node: Node, wanted: String) -> Node3D:
	if String(node.name) == wanted and node is Node3D:
		return node as Node3D
	for child in node.get_children():
		var found := _find(child, wanted)
		if found:
			return found
	return null
