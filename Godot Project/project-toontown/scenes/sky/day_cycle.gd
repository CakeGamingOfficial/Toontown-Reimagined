extends Node

## Optional sunlight for playgrounds and streets. The baked colors stay in
## charge: the sun only adds a little light, and soft shadows are that extra
## light being blocked. Donald's Dreamland keeps its night sky and lights the
## streetlamps. The Brrrgh adds a pale fog. Indoors and Cog HQs stay as they are.

const _DISPLAY := preload("res://scenes/shticker/display_settings.gd")

var _sun: DirectionalLight3D
var _lamps: Array[OmniLight3D] = []
var _emissions: Array[StandardMaterial3D] = []
var _overrides: Array[MeshInstance3D] = []
var _lamp_key := "unset"
var _kind := "tt"
var _cleared := true
var _fog_known := false
var _fog_was := false
var _ambient_known := false
var _ambient_energy := 1.0
var _ambient_color := Color.WHITE
var _painted_day := -1.0
static var forced_hour := -1.0


static func set_forced_hour(hour: float) -> void:
	forced_hour = hour


static func clock_hour() -> float:
	return forced_hour


func follow(host: Node3D) -> void:
	_kind = str(host.get("sky_kind"))
	var forced := forced_hour >= 0.0
	if not _outdoor(host) or (not forced and not _DISPLAY.day_cycle_on()):
		if not _cleared:
			_clear(host)
		return
	_cleared = false
	_ensure_sun(host)
	var day := _day_amount()
	# The clock only moves this value once a second. Repainting the sun,
	# fog, and lamps every frame was the same picture sixty times.
	if is_equal_approx(day, _painted_day):
		return
	_painted_day = day
	_paint_sun(day)
	_paint_sky(host, day)
	_paint_air(host, day)
	if _kind == "dl":
		_bind_lamps(host)
		_paint_lamps(lerpf(1.7, 0.45, day))
	elif not _lamps.is_empty():
		_release_lamps()


func _outdoor(host: Node3D) -> bool:
	if _kind == "cog":
		return false
	return not host.scene_file_path.contains("/interiors/")


func _day_amount() -> float:
	return clampf(sin((_hours() - 6.0) / 24.0 * TAU), 0.0, 1.0)


func _ensure_sun(host: Node3D) -> void:
	if _sun != null and is_instance_valid(_sun):
		return
	_sun = DirectionalLight3D.new()
	_sun.name = "DaySun"
	_sun.shadow_enabled = true
	_sun.shadow_blur = 1.6
	_sun.light_angular_distance = 0.5
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = 90.0
	_sun.directional_shadow_blend_splits = true
	_sun.directional_shadow_fade_start = 0.75
	_sun.shadow_bias = 0.06
	_sun.light_specular = 0.05
	host.add_child(_sun)


func _paint_sun(day: float) -> void:
	if _sun == null:
		return
	_sun.visible = true
	var hours := _hours()
	var pitch := lerpf(-0.15, -1.12, day)
	_sun.rotation = Vector3(pitch, hours / 24.0 * TAU, 0.0)
	if _kind == "dl":
		_sun.light_color = Color(0.62, 0.7, 0.95)
		_sun.light_energy = lerpf(0.05, 0.1, day)
		_sun.shadow_enabled = false
		return
	if _kind == "br":
		_sun.light_color = Color(0.82, 0.88, 1.0)
		_sun.light_energy = lerpf(0.05, 0.18, day)
	else:
		_sun.light_color = Color(1.0, 0.96, 0.86).lerp(Color(1.0, 0.72, 0.45), 1.0 - day)
		_sun.light_energy = lerpf(0.05, 0.22, day)
	_sun.shadow_enabled = day > 0.2


func _hours() -> float:
	# 6:00 is sunrise, 12:00 is noon, 18:00 is sunset. ~settime replaces the clock.
	if forced_hour >= 0.0:
		return forced_hour
	var now := Time.get_time_dict_from_system()
	return float(now.get("hour", 12)) + float(now.get("minute", 0)) / 60.0


func wake() -> void:
	_painted_day = -1.0


func _paint_sky(host: Node, day: float) -> void:
	var sky := host.get_node_or_null("ToontownSky")
	if sky == null or not sky.has_method("set_night"):
		return
	var night := lerpf(0.45, 1.0, day)
	if _kind == "dl":
		night = lerpf(0.78, 0.94, day)
	elif _kind == "br":
		night = lerpf(0.58, 0.92, day)
	sky.call("set_night", night)


func _paint_air(host: Node, day: float) -> void:
	var env := _environment(host)
	if env == null:
		return
	if not _fog_known:
		_fog_was = env.fog_enabled
		_fog_known = true
	if not _ambient_known:
		_ambient_energy = env.ambient_light_energy
		_ambient_color = env.ambient_light_color
		_ambient_known = true
	if _kind == "dl":
		env.ambient_light_color = Color(0.72, 0.76, 0.95)
		env.ambient_light_energy = lerpf(0.74, 0.88, day) * _ambient_energy
	elif _kind == "br":
		env.ambient_light_color = Color(0.8, 0.86, 0.96)
		env.ambient_light_energy = lerpf(0.7, 0.94, day) * _ambient_energy
	else:
		env.ambient_light_color = Color(0.7, 0.76, 0.98).lerp(_ambient_color, day)
		env.ambient_light_energy = lerpf(0.68, 1.0, day) * _ambient_energy
	if _kind != "br":
		env.fog_enabled = _fog_was
		return
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.82, 0.87, 0.93)
	# A light haze. Night is only a little thicker than day.
	env.fog_density = lerpf(0.0035, 0.0016, day)
	env.fog_aerial_perspective = 0.1
	env.fog_sky_affect = 0.06


func _environment(host: Node) -> Environment:
	var world := host.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world == null:
		return null
	return world.environment


func _bind_lamps(host: Node3D) -> void:
	var key := str(host.get_meta("holiday_kind", ""))
	if key == _lamp_key:
		return
	_release_lamps()
	_lamp_key = key
	for node in host.find_children("prop_post_*light_streetlamp*", "Node3D", true, false):
		if not (node is Node3D):
			continue
		var lamp_node := node as Node3D
		var light := OmniLight3D.new()
		light.name = "LampGlow"
		light.light_color = Color(1.0, 0.8, 0.42)
		light.omni_range = 9.0
		light.shadow_enabled = false
		light.light_specular = 0.0
		light.position = _bulb_local(lamp_node)
		lamp_node.add_child(light)
		_lamps.append(light)
		_emit_bulb(lamp_node)


func _bulb_local(node: Node3D) -> Vector3:
	var mesh := _first_mesh(node)
	if mesh == null or mesh.mesh == null:
		return Vector3.ZERO
	var center := mesh.global_transform * mesh.mesh.get_aabb().get_center()
	return node.to_local(center)


func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	var found := node.find_child("*", true, false) as MeshInstance3D
	if found != null:
		return found
	for child in node.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			return child as MeshInstance3D
	return null


func _emit_bulb(node: Node3D) -> void:
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for child in node.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			meshes.append(child as MeshInstance3D)
	for mesh in meshes:
		if mesh.mesh == null:
			continue
		var box := mesh.mesh.get_aabb()
		if box.size.length() > 4.0:
			continue
		for surface in mesh.mesh.get_surface_count():
			var active := mesh.get_active_material(surface)
			if not (active is StandardMaterial3D):
				continue
			var copy := (active as StandardMaterial3D).duplicate() as StandardMaterial3D
			copy.emission_enabled = true
			copy.emission = Color(1.0, 0.76, 0.32)
			copy.emission_energy_multiplier = 0.0
			mesh.set_surface_override_material(surface, copy)
			_emissions.append(copy)
			if not _overrides.has(mesh):
				_overrides.append(mesh)


func _paint_lamps(glow: float) -> void:
	for mat in _emissions:
		mat.emission_energy_multiplier = glow
	for lamp in _lamps:
		if is_instance_valid(lamp):
			lamp.light_energy = glow
			lamp.visible = true


func _clear(host: Node) -> void:
	_cleared = true
	_painted_day = -1.0
	if _sun != null and is_instance_valid(_sun):
		_sun.visible = false
		_sun.shadow_enabled = false
	var sky := host.get_node_or_null("ToontownSky")
	if sky != null and sky.has_method("set_night"):
		sky.call("set_night", 1.0)
	var env := _environment(host)
	if env != null and _fog_known:
		env.fog_enabled = _fog_was
	if env != null and _ambient_known:
		env.ambient_light_energy = _ambient_energy
		env.ambient_light_color = _ambient_color
	_release_lamps()
	_lamp_key = "unset"


func _release_lamps() -> void:
	for mesh in _overrides:
		if is_instance_valid(mesh) and mesh.mesh != null:
			for surface in mesh.mesh.get_surface_count():
				mesh.set_surface_override_material(surface, null)
	_overrides.clear()
	_emissions.clear()
	for lamp in _lamps:
		if is_instance_valid(lamp):
			lamp.queue_free()
	_lamps.clear()
