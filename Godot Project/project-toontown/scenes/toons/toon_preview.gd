class_name ToonPreview
extends Node3D

## A stand-in body until the real toon actor is assembled from the
## original head, torso, and leg models. Proportions and colors follow
## the Make a Toon choices.

var _style: ToonStyle


func show_style(style: ToonStyle) -> void:
	_style = style
	for child in get_children():
		child.free()
	if style == null:
		return
	var leg_h: float = [0.55, 0.85, 1.15][style.leg_size()]
	var torso_h: float = [0.5, 0.7, 0.9][style.torso_size()]
	var torso_w: float = [0.38, 0.46, 0.54][style.torso_size()]
	var fur := ToonStyle.fur_color(style.leg_color)
	var arms := ToonStyle.fur_color(style.arm_color)
	var head := ToonStyle.fur_color(style.head_color)
	var shirt := ToonStyle.clothes_color(style.top_color)
	var bottom := ToonStyle.clothes_color(style.bot_color)
	var gloves := ToonStyle.fur_color(style.glove_color)
	_capsule(Vector3(-0.16, leg_h * 0.5, 0), Vector3(0.16, leg_h, 0.16), bottom)
	_capsule(Vector3(0.16, leg_h * 0.5, 0), Vector3(0.16, leg_h, 0.16), bottom)
	var torso_y := leg_h + torso_h * 0.5
	_capsule(Vector3(0, torso_y, 0), Vector3(torso_w, torso_h, torso_w * 0.75), shirt)
	if style.wears_skirt():
		_sphere(Vector3(0, leg_h + 0.08, 0), Vector3(torso_w * 1.35, 0.22, torso_w), bottom)
	_capsule(Vector3(-torso_w * 0.72, torso_y + 0.05, 0), Vector3(0.12, torso_h * 0.85, 0.12), arms)
	_capsule(Vector3(torso_w * 0.72, torso_y + 0.05, 0), Vector3(0.12, torso_h * 0.85, 0.12), arms)
	var hand_y := torso_y - torso_h * 0.32
	_sphere(Vector3(-torso_w * 0.72, hand_y, 0.02), Vector3(0.12, 0.1, 0.1), gloves)
	_sphere(Vector3(torso_w * 0.72, hand_y, 0.02), Vector3(0.12, 0.1, 0.1), gloves)
	var head_y := leg_h + torso_h + 0.32
	_sphere(Vector3(0, head_y, 0), Vector3(0.46, 0.42, 0.42), head)
	_add_features(style, head_y, head)


func _process(delta: float) -> void:
	rotate_y(delta * 0.6)


func _add_features(style: ToonStyle, head_y: float, fur: Color) -> void:
	var long_muzzle := style.head.length() > 1 and style.head[1] == "l"
	var long_ears := style.head.length() > 2 and style.head[2] == "l"
	var muzzle_z := 0.28 if long_muzzle else 0.2
	match style.species():
		"d":
			_sphere(Vector3(-0.22, head_y + (0.05 if long_ears else -0.08), 0), Vector3(0.16, 0.22, 0.1), fur)
			_sphere(Vector3(0.22, head_y + (0.05 if long_ears else -0.08), 0), Vector3(0.16, 0.22, 0.1), fur)
			_sphere(Vector3(0, head_y - 0.06, muzzle_z), Vector3(0.2, 0.14, 0.16), fur)
		"c":
			_ear(Vector3(-0.16, head_y + 0.28, 0), long_ears, fur)
			_ear(Vector3(0.16, head_y + 0.28, 0), long_ears, fur)
			_sphere(Vector3(0, head_y - 0.08, muzzle_z), Vector3(0.14, 0.1, 0.12), fur)
		"h":
			_ear(Vector3(-0.14, head_y + 0.32, 0), true, fur)
			_ear(Vector3(0.14, head_y + 0.32, 0), true, fur)
			_sphere(Vector3(0, head_y - 0.02, 0.34 if long_muzzle else 0.24), Vector3(0.14, 0.12, 0.22), fur)
		"m":
			_sphere(Vector3(-0.24, head_y + 0.12, 0), Vector3(0.2, 0.2, 0.08), fur)
			_sphere(Vector3(0.24, head_y + 0.12, 0), Vector3(0.2, 0.2, 0.08), fur)
			_sphere(Vector3(0, head_y - 0.08, 0.22), Vector3(0.12, 0.1, 0.1), fur)
		"r":
			_capsule(Vector3(-0.12, head_y + 0.48, 0), Vector3(0.1, 0.55 if long_ears else 0.36, 0.08), fur)
			_capsule(Vector3(0.12, head_y + 0.48, 0), Vector3(0.1, 0.55 if long_ears else 0.36, 0.08), fur)
			_sphere(Vector3(0, head_y - 0.08, muzzle_z), Vector3(0.12, 0.1, 0.12), fur)
		"f":
			_sphere(Vector3(0, head_y - 0.04, 0.32 if long_muzzle else 0.24), Vector3(0.22, 0.1, 0.16), Color(1.0, 0.62, 0.15))
		"p":
			_sphere(Vector3(-0.22, head_y + 0.16, 0), Vector3(0.14, 0.14, 0.08), fur)
			_sphere(Vector3(0.22, head_y + 0.16, 0), Vector3(0.14, 0.14, 0.08), fur)
			_sphere(Vector3(0, head_y - 0.08, muzzle_z), Vector3(0.18, 0.12, 0.14), fur)
		"b":
			_sphere(Vector3(-0.16, head_y + 0.28, 0), Vector3(0.14, 0.14, 0.08), fur)
			_sphere(Vector3(0.16, head_y + 0.28, 0), Vector3(0.14, 0.14, 0.08), fur)
			_sphere(Vector3(0, head_y - 0.08, 0.22), Vector3(0.16, 0.12, 0.12), fur)
		"s":
			_ear(Vector3(-0.16, head_y + 0.26, 0), long_ears, fur)
			_ear(Vector3(0.16, head_y + 0.26, 0), long_ears, fur)
			_sphere(Vector3(0, head_y - 0.06, 0.28), Vector3(0.16, 0.12, 0.12), fur.darkened(0.15))


func _ear(at: Vector3, long_ear: bool, color: Color) -> void:
	_capsule(at, Vector3(0.08, 0.28 if long_ear else 0.16, 0.06), color)


func _sphere(at: Vector3, scale: Vector3, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	_add(mesh, at, scale, color)


func _capsule(at: Vector3, scale: Vector3, color: Color) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	_add(mesh, at, scale, color)


func _add(mesh: Mesh, at: Vector3, scale: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.scale = scale
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	instance.material_override = material
	add_child(instance)
