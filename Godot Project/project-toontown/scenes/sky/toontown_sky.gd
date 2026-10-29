@tool
extends Node3D

## Background sky for every neighborhood. Call ensure(self) from _ready.
## "tt" is the Toontown Central cloud sky. Daisy Gardens, Goofy Speedway,
## MiniGolf, and the Toontorial use that same sky, because the original game does.
## The other kinds use that hood's own sky painting.
## Saving the scene puts the imported sky and the original environment back.

const GRADIENT := preload("res://assets/neighborhoods/toontown_central/toontown_central_117.png")
const CLOUDS := preload("res://assets/neighborhoods/toontown_central/toontown_central_115.png")
const SKY_SHADER_PATH := "res://assets/neighborhoods/toontown_central/toontown_sky.gdshader"
const HOOD_SHADER_PATH := "res://scenes/sky/hood_sky.gdshader"

const PROFILES := {
	"mm": {
		"sky": "res://assets/neighborhoods/minnies_melodyland/sky/lateday_sky3.png",
		"zenith": "res://assets/neighborhoods/minnies_melodyland/sky/lateday_sky3.png",
		"repeats": 8.0,
		"crop": Vector4(0, 0, 1, 1),
		"zenith_mode": 0,
	},
	"br": {
		"sky": "res://assets/neighborhoods/the_burrrgh/sky/phase_3.5_palette_3cmla_1.png",
		"zenith": "res://assets/neighborhoods/the_burrrgh/sky/sky_oc_blue2.png",
		"repeats": 6.0,
		"crop": Vector4(0.008, 0.008, 0.484, 0.484),
		"zenith_mode": 0,
	},
	"dl": {
		"sky": "res://assets/neighborhoods/donalds_dreamland/sky/nightsky.png",
		"zenith": "res://assets/neighborhoods/donalds_dreamland/sky/nightskytop.png",
		"repeats": 10.0,
		"crop": Vector4(0, 0, 1, 1),
		"zenith_mode": 1,
	},
}

var kind := "tt"
var _material: ShaderMaterial
var _hidden: Array[Node3D] = []
var _scroll := 0.0
var _original_environment: Environment


static func ensure(host: Node, sky_kind: String = "tt") -> Node3D:
	var existing := host.get_node_or_null("ToontownSky") as Node3D
	if existing:
		if existing.get("kind") != sky_kind:
			existing.set("kind", sky_kind)
			existing.set("_material", null)
		return existing
	var sky := (load("res://scenes/sky/toontown_sky.gd") as GDScript).new() as Node3D
	sky.name = "ToontownSky"
	sky.set("kind", sky_kind)
	host.add_child(sky)
	return sky


static func restore_imported(host: Node) -> void:
	var sky := host.get_node_or_null("ToontownSky")
	if sky and sky.has_method("_show_imported"):
		sky.call("_show_imported")


func _ready() -> void:
	_apply_sky()
	_collect_imported(get_parent())
	_hide_imported()


func _process(delta: float) -> void:
	# cloud1 gains a quarter degree per second. The second layer uses 0.8 of that.
	if kind == "tt":
		_scroll += delta * 0.25
		if _material:
			_material.set_shader_parameter("cloud_scroll", _scroll)
	_apply_sky()
	if _hidden.is_empty() or not is_instance_valid(_hidden[0]):
		_hidden.clear()
		_collect_imported(get_parent())
	_hide_imported()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_show_imported()


func _apply_sky() -> void:
	var world := _world()
	if world == null:
		return
	if _material == null:
		_material = _make_material()
	var current := world.environment
	if current and current.sky and current.sky.sky_material == _material:
		return
	if _original_environment == null:
		_original_environment = current
	var environment := current.duplicate() if current else Environment.new()
	var sky := Sky.new()
	sky.sky_material = _material
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	world.environment = environment


func _make_material() -> ShaderMaterial:
	var shader := Shader.new()
	var material := ShaderMaterial.new()
	if kind == "cog":
		shader.code = "shader_type sky;\nvoid sky() {\n\tfloat height = clamp(normalize(EYEDIR).y, 0.0, 1.0);\n\tCOLOR = mix(vec3(0.55, 0.58, 0.62), vec3(0.28, 0.32, 0.38), height);\n}\n"
		material.shader = shader
		return material
	if kind == "tt" or not PROFILES.has(kind):
		shader.code = FileAccess.get_file_as_string(SKY_SHADER_PATH)
		material.shader = shader
		material.set_shader_parameter("gradient_tex", GRADIENT)
		material.set_shader_parameter("cloud_tex", CLOUDS)
		material.set_shader_parameter("cloud_scroll", _scroll)
		return material
	var profile: Dictionary = PROFILES[kind]
	shader.code = FileAccess.get_file_as_string(HOOD_SHADER_PATH)
	material.shader = shader
	material.set_shader_parameter("sky_tex", load(str(profile["sky"])))
	material.set_shader_parameter("zenith_tex", load(str(profile["zenith"])))
	material.set_shader_parameter("crop", profile["crop"])
	material.set_shader_parameter("repeats", float(profile["repeats"]))
	material.set_shader_parameter("zenith_mode", int(profile["zenith_mode"]))
	return material


func _world() -> WorldEnvironment:
	var host := get_parent()
	if host == null:
		return null
	var found := host.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if found:
		return found
	var created := WorldEnvironment.new()
	created.name = "WorldEnvironment"
	host.add_child(created)
	return created


func _collect_imported(node: Node) -> void:
	if node == null or node == self:
		return
	var node_name := str(node.name)
	if node_name == "cloud1" or node_name == "cloud2":
		if node is Node3D:
			_hidden.append(node as Node3D)
		var parent := node.get_parent()
		if parent is Node3D and parent != get_parent() and not _hidden.has(parent):
			_hidden.append(parent as Node3D)
	elif node_name == "DDSky" and node is Node3D:
		_hidden.append(node as Node3D)
	elif node is MeshInstance3D and (node_name == "Sky" or node_name.begins_with("Sky2")):
		_hidden.append(node as Node3D)
	for child in node.get_children():
		if child == self:
			continue
		_collect_imported(child)


func _hide_imported() -> void:
	for node in _hidden:
		if is_instance_valid(node):
			node.visible = false


func _show_imported() -> void:
	for node in _hidden:
		if is_instance_valid(node):
			node.visible = true
	var world := _world()
	if world and _original_environment:
		world.environment = _original_environment
