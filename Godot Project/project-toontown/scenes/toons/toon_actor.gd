class_name ToonActor
extends Node3D

## Legs, torso, and head from the original 1000-LOD models, posed in neutral
## and assembled the way Toon.parentToonParts does: torso on joint_hips,
## head on def_head. The parts are still Z-up, so this node stands them up.

const _PARTS := "res://assets/toons/parts/"
const _HEADS := "res://assets/toons/heads/"
const _SHIRT := [
	preload("res://assets/toons/clothes/desat_shirt_1.png"),
	preload("res://assets/toons/clothes/desat_shirt_2.png"),
]
const _SLEEVE := [
	preload("res://assets/toons/clothes/desat_sleeve_1.png"),
	preload("res://assets/toons/clothes/desat_sleeve_2.png"),
]
const _SHORTS := [
	preload("res://assets/toons/clothes/desat_shorts_1.png"),
	preload("res://assets/toons/clothes/desat_shorts_2.png"),
]
const _SKIRT := preload("res://assets/toons/clothes/desat_skirt_1.png")

var _style: ToonStyle


func show_style(style: ToonStyle) -> void:
	_style = style
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
	var part := String(mesh.name)
	if part.begins_with("eyes") or part.begins_with("muzzle") or part.contains("pupil") or part == "nose" or part == "eyelashes":
		_unshade(mesh)
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
	return _SHORTS[0]


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
			var part := String(mesh.name)
			if part == "eyelashes" or part.begins_with("eyes") or part.begins_with("muzzle") or part == "nose":
				unshaded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				unshaded.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.set_surface_override_material(surface, unshaded)


func _find(node: Node, wanted: String) -> Node3D:
	if String(node.name) == wanted and node is Node3D:
		return node as Node3D
	for child in node.get_children():
		var found := _find(child, wanted)
		if found:
			return found
	return null
