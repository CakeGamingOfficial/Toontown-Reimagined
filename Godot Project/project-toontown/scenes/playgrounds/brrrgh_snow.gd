extends Node3D

## BRSafeZoneLoader snow. A disc of flakes rides with the camera, five units up.
## CPUParticles3D keeps its settings on the node. It does not take a
## ParticleProcessMaterial, and a custom particle shader floods the
## compatibility renderer with "version is null".

const _FLAKE := preload("res://assets/minigames/photo/snowflake.png")


func _ready() -> void:
	var flakes := CPUParticles3D.new()
	flakes.name = "Snow"
	flakes.amount = 225
	flakes.lifetime = 4.5
	flakes.preprocess = 4.5
	flakes.explosiveness = 0.0
	flakes.local_coords = true
	flakes.visibility_aabb = AABB(Vector3(-55.0, -40.0, -55.0), Vector3(110.0, 55.0, 110.0))
	flakes.position = Vector3(0.0, 5.0, 0.0)
	flakes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# snowdisk.ptf disc, radius 50, flat on the ground plane.
	flakes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flakes.emission_box_extents = Vector3(50.0, 0.4, 50.0)
	flakes.direction = Vector3(0.0, -1.0, 0.0)
	flakes.spread = 12.0
	flakes.initial_velocity_min = 0.15
	flakes.initial_velocity_max = 0.8
	flakes.gravity = Vector3(0.0, -1.5, 0.0)
	flakes.angular_velocity_min = -160.0
	flakes.angular_velocity_max = 160.0
	flakes.scale_amount_min = 0.2
	flakes.scale_amount_max = 0.45
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.15))
	curve.add_point(Vector2(1.0, 1.0))
	flakes.scale_amount_curve = curve
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.95),
		Color(1.0, 1.0, 1.0, 0.85),
	])
	flakes.color_ramp = gradient
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.albedo_texture = _FLAKE
	quad.material = mat
	flakes.mesh = quad
	add_child(flakes)


func follow(camera: Camera3D) -> void:
	global_transform = Transform3D(Basis.IDENTITY, camera.global_position)
