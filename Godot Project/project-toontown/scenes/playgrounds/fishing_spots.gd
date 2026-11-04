extends Node

## DistributedFishingTarget. Each pond keeps getNumTargets spots. A spot is the
## phase_3 drop shadow plus Bubbles, and setState glides it to the next point
## in the pond with an easeInOut lerp that lasts FishingTargetGlobals.StepTime.
## The point is getDestPos: center + (radius * cos(angle), radius * sin(angle))
## with the angle in radians. Streets that were slid onto the origin use that
## same slide, so the circle stays on the water. The estate pond keeps three.

const _SHADOW := "res://assets/neighborhoods/toontown_central/props/drop_shadow.png"
const _BUBBLE := "res://assets/neighborhoods/toontown_central/props/bubble.png"
const _STEP := 5.0
const _SHADOW_SIZE := 2.64

const _PONDS := {
	"toontown_central.tscn": {"count": 2, "center": Vector3(-81, -4.8, -31), "radius": 14.0},
	"silly_street.tscn": {"count": 2, "center": Vector3(20, -1.4, 664), "radius": 14.0},
	"loopy_lane.tscn": {"count": 2, "center": Vector3(-234, -1.4, -175), "radius": 14.0},
	"punchline_place.tscn": {"count": 2, "center": Vector3(529, -1.4, 70), "radius": 13.0},
	"donalds_dock.tscn": {"count": 2, "center": Vector3(-17, 1.73, -130), "radius": 15.0},
	"barnacle_boulevard.tscn": {"count": 2, "center": Vector3(137.793, -2, 231.832), "radius": 14.0},
	"seaweed_street.tscn": {"count": 2, "center": Vector3(-186.753, -2, -56.559), "radius": 14.0},
	"lighthouse_lane.tscn": {"count": 2, "center": Vector3(34.965, -2, -136.856), "radius": 14.0},
	"daisy_gardens.tscn": {"count": 2, "center": Vector3(50, -1.48, -47), "radius": 13.0},
	"elm_street.tscn": {"count": 2, "center": Vector3(-141.439, -1.43, 59.754), "radius": 13.0},
	"maple_street.tscn": {"count": 2, "center": Vector3(-155.83, -1.43, -75.173), "radius": 13.0},
	"oak_street.tscn": {"count": 2, "center": Vector3(184.965, -1.5, 145.56), "radius": 13.0},
	"minnies_melodyland.tscn": {"count": 2, "center": Vector3(-0.2, -14.65, 20.2), "radius": 14.0},
	"alto_avenue.tscn": {"count": 2, "center": Vector3(-191.821, -0.87, 126.366), "radius": 14.0},
	"baritone_boulevard.tscn": {"count": 2, "center": Vector3(-192.712, -0.87, 95.237), "radius": 14.0},
	"tenor_terrace.tscn": {"count": 2, "center": Vector3(263.783, -0.87, 63.178), "radius": 14.0},
	"the_burrrgh.tscn": {"count": 2, "center": Vector3(-58, 1.7, 26), "radius": 10.0},
	"walrus_way.tscn": {"count": 2, "center": Vector3(190.562, -2, -0.362), "radius": 13.0},
	"sleet_street.tscn": {"count": 2, "center": Vector3(100.764, -2, -175.684), "radius": 13.0},
	"polar_place.tscn": {"count": 2, "center": Vector3(-201.762, -2, 154.954), "radius": 13.0},
	"donalds_dreamland.tscn": {"count": 2, "center": Vector3(159, -17.1, -0.2), "radius": 14.0},
	"lullaby_lane.tscn": {"count": 2, "center": Vector3(223.988, -2.1, -21.045), "radius": 14.0},
	"pajama_place.tscn": {"count": 2, "center": Vector3(90.966, -2.1, 270.577), "radius": 14.0},
	"toon_estate.tscn": {"count": 3, "center": Vector3(30, -0.3, 126), "radius": 16.0},
}

static var _shadow_mesh: QuadMesh
static var _shadow_material: StandardMaterial3D
static var _bubble_mesh: QuadMesh
static var _bubble_material: StandardMaterial3D
static var _scale_curve: Curve


static func place(host: Node) -> void:
	preload("res://scenes/playgrounds/fishermen.gd").place(host)
	preload("res://scenes/playgrounds/fishing_shores.gd").place(host)
	if host == null or Engine.is_editor_hint():
		return
	if host.find_child("FishingSpots", true, false) != null:
		return
	var file := host.scene_file_path.get_file()
	if file.begins_with("toon_estate"):
		file = "toon_estate.tscn"
	var info: Dictionary = _PONDS.get(file, {})
	if info.is_empty():
		return
	var pond := host.find_child("fishing_pond*", true, false) as Node3D
	if pond == null:
		pond = host as Node3D
	if pond == null:
		return
	_prepare()
	var holder := Node3D.new()
	holder.name = "FishingSpots"
	pond.add_child(holder)
	var center: Vector3 = info["center"]
	var radius := float(info["radius"])
	for _index in int(info["count"]):
		var spot := FishSpot.new()
		spot.name = "FishSpot"
		holder.add_child(spot)
		spot.open(center, radius, _shadow_mesh, _shadow_material, _bubble_mesh, _bubble_material, _scale_curve)


static func _prepare() -> void:
	if _shadow_mesh != null:
		return
	_shadow_mesh = QuadMesh.new()
	# The pond keeps Panda's Z-up axes. FACE_Z lays the card on the water,
	# the same way the toon shadow lies flat on joint_shadow.
	_shadow_mesh.orientation = PlaneMesh.FACE_Z
	_shadow_mesh.size = Vector2(_SHADOW_SIZE, _SHADOW_SIZE)
	_shadow_material = StandardMaterial3D.new()
	_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_material.albedo_color = Color(1, 1, 1, 0.75)
	_shadow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shadow_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	# The pond surface is a transparent card in this same pass. Sorting by
	# distance paints the circle on top of the water, so draw the shadow first.
	_shadow_material.render_priority = -1
	_shadow_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var shadow := load(_SHADOW) as Texture2D
	if shadow != null:
		_shadow_material.albedo_texture = shadow
	_bubble_mesh = QuadMesh.new()
	_bubble_mesh.size = Vector2.ONE
	_bubble_material = StandardMaterial3D.new()
	_bubble_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bubble_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bubble_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_bubble_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bubble_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_bubble_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var bubble := load(_BUBBLE) as Texture2D
	if bubble != null:
		_bubble_material.albedo_texture = bubble
	_scale_curve = Curve.new()
	_scale_curve.add_point(Vector2(0.0, 0.35))
	_scale_curve.add_point(Vector2(1.0, 1.0))


class FishSpot extends Node3D:
	var _center := Vector3.ZERO
	var _radius := 0.0
	var _glide: Tween

	func open(center: Vector3, radius: float, shadow_mesh: QuadMesh, shadow_material: Material, bubble_mesh: QuadMesh, bubble_material: Material, scale_curve: Curve) -> void:
		_center = center
		_radius = radius
		var shadow := MeshInstance3D.new()
		shadow.name = "drop_shadow"
		shadow.mesh = shadow_mesh
		shadow.material_override = shadow_material
		shadow.position = Vector3(0.0, 0.0, -0.1)
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shadow)
		var bubbles := CPUParticles3D.new()
		bubbles.name = "bubbles"
		bubbles.mesh = bubble_mesh
		bubbles.material_override = bubble_material
		bubbles.amount = 8
		bubbles.lifetime = 2.0
		bubbles.lifetime_randomness = 0.25
		bubbles.preprocess = 2.0
		bubbles.local_coords = true
		bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		bubbles.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
		bubbles.emission_ring_height = 0.02
		bubbles.emission_ring_radius = 0.5
		bubbles.emission_ring_inner_radius = 0.0
		bubbles.direction = Vector3(0.0, 0.0, 1.0)
		bubbles.spread = 28.0
		bubbles.initial_velocity_min = 0.075
		bubbles.initial_velocity_max = 0.125
		bubbles.gravity = Vector3(0.0, 0.0, 1.0)
		bubbles.scale_amount_min = 0.2
		bubbles.scale_amount_max = 0.2
		bubbles.scale_amount_curve = scale_curve
		bubbles.visibility_aabb = AABB(Vector3(-1.5, -1.5, -0.5), Vector3(3.0, 3.0, 4.0))
		bubbles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bubbles)
		global_position = _destination()
		_sail()

	func _sail() -> void:
		_glide = create_tween()
		_glide.set_trans(Tween.TRANS_SINE)
		_glide.set_ease(Tween.EASE_IN_OUT)
		_glide.tween_property(self, "global_position", _destination(), _STEP)
		_glide.finished.connect(_sail)

	func _destination() -> Vector3:
		var angle := randf() * TAU
		var reach := randf() * _radius
		return _center + Vector3(cos(angle) * reach, 0.0, -sin(angle) * reach)
