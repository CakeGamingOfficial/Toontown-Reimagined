extends Node3D

## The firework shows from FireworkShow.py. Each shell rises on the original
## velocity, then bursts with the card textures from the firework models.
## July 4, the party summer show, New Year, and the combo show are all here.

const _DATA := "res://scenes/effects/firework_shows.json"

const _STARS := preload("res://assets/effects/fireworks/tt_t_efx_ext_fireworkStars_01.png")
const _STARS2 := preload("res://assets/effects/fireworks/tt_t_efx_ext_fireworkStars_02.png")
const _RAYS := preload("res://assets/effects/fireworks/tt_t_efx_ext_fireworkRays.png")
const _BURST_A := preload("res://assets/effects/fireworks/tt_t_efx_ext_fireworkBurst_01.png")
const _BURST_B := preload("res://assets/effects/fireworks/tt_t_efx_ext_fireworkBurst_02.png")
const _GLOW := preload("res://assets/effects/fireworks/tt_t_efx_ext_particleWhiteGlow.png")
const _BLAST := preload("res://assets/effects/fireworks/tt_t_efx_ext_particleBlast.png")
const _SPARKLE := preload("res://assets/effects/fireworks/tt_t_efx_ext_particleSparkle.png")
const _SHARP := preload("res://assets/effects/fireworks/tt_t_efx_ext_particleSpark_sharp.png")
const _SOFT := preload("res://assets/effects/fireworks/tt_t_efx_ext_particleSpark_soft.png")
const _PARTICLE_STARS := preload("res://assets/effects/fireworks/tt_t_efx_ext_particleStars.png")
const _ICECREAM := preload("res://assets/effects/fireworks/icecream.png")

const _WHISTLE := [
	preload("res://assets/effects/fireworks/firework_whistle_01.ogg"),
	preload("res://assets/effects/fireworks/firework_whistle_02.ogg"),
]
const _BURST_SFX := [
	preload("res://assets/effects/fireworks/firework_explosion_01.ogg"),
	preload("res://assets/effects/fireworks/firework_explosion_02.ogg"),
	preload("res://assets/effects/fireworks/firework_explosion_03.ogg"),
	preload("res://assets/effects/fireworks/firework_distance_01.ogg"),
	preload("res://assets/effects/fireworks/firework_distance_02.ogg"),
	preload("res://assets/effects/fireworks/firework_distance_03.ogg"),
]
const _MUSIC := {
	"july4": preload("res://assets/effects/fireworks/tt_party2.ogg"),
	"summer": preload("res://assets/effects/fireworks/tt_summer.ogg"),
	"newyear": preload("res://assets/effects/fireworks/tt_s_ara_gen_fireworks_auldLangSyne.ogg"),
	"combo": preload("res://assets/effects/fireworks/tt_party2.ogg"),
}
const _ROCKET_DATA := "res://scenes/effects/rocket_launch.json"
const _ROCKET_SFX := preload("res://assets/effects/fireworks/rocket_launch.ogg")
const _FIREBALL := preload("res://assets/effects/fireworks/tt_m_efx_fireball.png")
const _SMOKE_TEX := preload("res://assets/effects/fireworks/tt_m_efx_smoke.png")
const _PALETTE: Array[Color] = [
	Color(1, 1, 1, 1),
	Color(1, 0.1, 0.1, 1),
	Color(0.1, 1, 0.1, 1),
	Color(0.3, 1, 0.3, 1),
	Color(0.2, 0.2, 1, 1),
	Color(1, 1, 0.1, 1),
	Color(1, 0.5, 0.1, 1),
	Color(1, 0.1, 1, 1),
	Color(0.1, 1, 1, 1),
	Color(0.1, 0.5, 1, 1),
]
const _TRAILS: Array[Vector3] = [
	Vector3(120, 120, 100),
	Vector3(120, -120, 100),
	Vector3(-120, 120, 100),
	Vector3(-120, -120, 100),
]

var _plan: Array[Dictionary] = []
var _live: Array[Dictionary] = []
var _next := 0
var _clock := 0.0
var _end := 8.0
var _restore_at := 6.0
var _show := "summer"
var _music: AudioStreamPlayer
var _hood: AudioStreamPlayer
var _started := false
var _announced := false
var _ended := false
var _replaced := false
var _night_sent := -1.0
var _quad: QuadMesh
var _delay := 0.0
var _rocket_frames := PackedFloat32Array()
var _rockets: Array[Dictionary] = []
var _rocket_hunt := 0
var _rocket_sound := false


func setup(show_name: String, at: int, delay: float) -> void:
	_show = _canonical(show_name)
	_quad = QuadMesh.new()
	_quad.size = Vector2.ONE
	_place()
	_clock = float(int(Time.get_unix_time_from_system()) - at) - delay
	_delay = delay
	if delay > 0.0:
		_arm_rockets()
		_step_rockets()
	if not _load():
		queue_free()
		return
	if _clock > _end:
		queue_free()
		return
	_hood = _music_player()
	if _hood != null:
		_hood.stream_paused = true


func takeover() -> void:
	_replaced = true
	free()


func _exit_tree() -> void:
	_drop_rocket()
	if _replaced:
		return
	_set_night(1.0)
	if _music != null:
		_music.stop()
	if _hood != null and is_instance_valid(_hood):
		_hood.stream_paused = false


func _process(delta: float) -> void:
	_clock += delta
	_step_rockets()
	_night()
	if _clock >= 0.0 and not _announced:
		_announced = true
		_say(_opening())
		_say(_instructions())
	if _clock >= 2.0 and not _started:
		_started = true
		_begin_music()
	while _next < _plan.size() and float(_plan[_next]["time"]) <= _clock:
		_launch(_plan[_next])
		_next += 1
	for shell in _live:
		if not is_instance_valid(shell["node"]):
			continue
		shell["age"] = float(shell["age"]) + delta
		var age := float(shell["age"])
		var node := shell["node"] as Node3D
		if not bool(shell["boomed"]):
			var vel: Vector3 = shell["vel"]
			var grav := float(shell["grav"])
			var start: Vector3 = shell["start"]
			node.position = start + Vector3(vel.x * age, vel.y * age - 16.0 * grav * age * age, vel.z * age)
			if age >= float(shell["burst"]):
				shell["boomed"] = true
				_boom(shell)
		elif age > float(shell["burst"]) + 4.5:
			node.queue_free()
	if _clock >= _restore_at and not _ended:
		_ended = true
		_say(_closing())
		if _music != null:
			_music.stop()
		if _hood != null and is_instance_valid(_hood):
			_hood.stream_paused = false
			_hood = null
	if _clock > _end:
		queue_free()


func _canonical(show_name: String) -> String:
	match show_name:
		"party":
			return "july4"
		"newyears":
			return "newyear"
		"july4", "summer", "newyear", "combo":
			return show_name
		_:
			return "summer"


func _load() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_DATA))
	if not (parsed is Dictionary) or not (parsed as Dictionary).has(_show):
		return false
	var book: Dictionary = (parsed as Dictionary)[_show]
	var shells: Array = book["shells"]
	var sections: Array = book["sections"]
	var cursor := 0.0
	var delay_sum := 0.0
	for section in sections:
		var bounds: Array = section
		var start := clampi(int(bounds[0]), 0, shells.size())
		var finish := clampi(int(bounds[1]), start, shells.size())
		var local := 2.0
		for index in range(start, finish):
			var row: Array = shells[index]
			_schedule(cursor + local + 2.0, row)
			var gap := float(row[7])
			local += gap
			delay_sum += gap
		cursor += local - 2.0
	_restore_at = 2.0 + delay_sum
	_end = _restore_at + 4.0
	_plan.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time"]) < float(b["time"]))
	return not _plan.is_empty()


func _schedule(time: float, row: Array) -> void:
	var kind := int(row[0])
	var vel := _vec(row[1])
	var pos := _vec(row[2])
	var scale := _number(row[3], 1.0 + randf() * 0.5)
	var primary := _color(row[4])
	var secondary := _color(row[5])
	var trail := _number(row[6], randf_range(1.2, 2.0))
	if kind == 11:
		_push(time, 0, Vector3(0, 0, 80.0 * scale), pos, scale / 1.2, primary, secondary, 1.5, 1.0)
		_push(time, 0, Vector3(-25.0 * scale, 0, 115.0 * scale), pos, scale / 1.6, primary, secondary, 1.7, 1.0)
		_push(time, 0, Vector3(25.0 * scale, 0, 115.0 * scale), pos, scale / 1.6, primary, secondary, 1.7, 1.0)
		return
	if kind == 13:
		for stripe in range(4):
			var ink := Color(1, 0, 0, 1) if stripe % 2 == 0 else Color(1, 1, 1, 1)
			var shifted := pos + Vector3(-20.0 * scale + 10.0 * float(stripe) * scale, 0, 0)
			_push(time + 0.25 * float(stripe), 9, Vector3(-30.0 * scale, 0, 150.0 * scale - 20.0 * float(stripe)), shifted, scale * 3.0, ink, ink, 2.5, 1.0)
		_push(time + 1.5, 15, Vector3(20, 0, 90), pos, scale * 1.5, Color.WHITE, Color.WHITE, 1.25, 1.0)
		return
	_push(time, kind, vel, pos, scale, primary, secondary, trail, 1.0)


func _push(time: float, kind: int, vel: Vector3, pos: Vector3, scale: float, primary: Color, secondary: Color, trail: float, grav: float) -> void:
	if time < _clock - 5.0:
		return
	_plan.append({
		"time": time,
		"kind": kind,
		"vel": _godot(vel),
		"start": _godot(pos),
		"scale": scale,
		"c1": primary,
		"c2": secondary,
		"burst": trail,
		"grav": grav,
	})


func _launch(shell: Dictionary) -> void:
	var node := Node3D.new()
	node.position = shell["start"]
	add_child(node)
	var born: Dictionary = shell.duplicate()
	born["node"] = node
	var age := maxf(0.0, _clock - float(shell["time"]))
	if age > float(shell["burst"]) + 4.5:
		node.queue_free()
		return
	born["age"] = age
	born["boomed"] = false
	var effect_scale := float(shell["scale"]) / 7.0
	born["fx"] = effect_scale
	var vel: Vector3 = shell["vel"]
	var grav := float(shell["grav"])
	node.position = shell["start"] + Vector3(vel.x * age, vel.y * age - 16.0 * grav * age * age, vel.z * age)
	_head(node, int(shell["kind"]), effect_scale, shell["c1"], shell["c2"])
	if age < float(shell["burst"]):
		_whistle()
	else:
		born["boomed"] = true
		_boom(born)
	_live.append(born)


func _head(node: Node3D, kind: int, effect_scale: float, primary: Color, secondary: Color) -> void:
	var head_size := 10.0
	var trail_life := 0.3
	var trail_size := 2.0
	var trail_tex := _SPARKLE
	var trail_color := Color.WHITE
	if kind == 3 or kind == 4 or kind == 8:
		head_size = 8.0
		trail_life = 0.25
		trail_size = 0.15 * 64.0 * effect_scale
		trail_tex = _GLOW
		trail_color = primary
	elif kind == 6:
		head_size = 15.0
	elif kind == 9 or kind == 10:
		head_size = 12.0
		trail_life = 2.0
		trail_size = 0.5 * 64.0 * effect_scale
		trail_tex = _PARTICLE_STARS
		trail_color = secondary
	var head := _sprite(node, _SPARKLE if kind < 9 else _GLOW, Color.WHITE, head_size)
	head.name = "Head"
	_trail(node, trail_tex, trail_color, trail_life, trail_size)
	if kind == 9 or kind == 10:
		_trail(node, _GLOW, primary, 1.0, 0.2 * 64.0 * effect_scale)


func _boom(shell: Dictionary) -> void:
	var node := shell["node"] as Node3D
	var head := node.get_node_or_null("Head")
	if head != null:
		head.visible = false
	var trail := node.get_node_or_null("Trail")
	if trail is GPUParticles3D:
		(trail as GPUParticles3D).emitting = false
	var extra := node.get_node_or_null("Trail2")
	if extra is GPUParticles3D:
		(extra as GPUParticles3D).emitting = false
	var kind := int(shell["kind"])
	if kind == 9:
		return
	var effect_scale := float(shell["fx"])
	var primary: Color = shell["c1"]
	var secondary: Color = shell["c2"]
	_burst_sound()
	_bloom(node, _GLOW, primary, 1200.0 * effect_scale, 6000.0 * effect_scale, 0.0, 0.5, 0.0)
	_bloom(node, _BLAST, Color.WHITE, 100.0 * effect_scale, 400.0 * effect_scale, 0.0, 0.15, 0.0)
	_bloom(node, _BLAST, primary, 250.0 * effect_scale, 1000.0 * effect_scale, 0.0, 0.3, 0.0)
	match kind:
		0:
			_bloom(node, _STARS, primary, 700.0 * effect_scale, 750.0 * effect_scale, 0.2, 1.25, 0.0)
			_bloom(node, _RAYS, primary, 100.0 * effect_scale, 700.0 * effect_scale, 0.0, 0.25, 0.0)
			_bloom(node, _STARS, primary, 560.0 * effect_scale, 600.0 * effect_scale, 0.2, 1.25, 0.15)
		1:
			_puff(node, _PARTICLE_STARS, primary, 64, 1.25, 50.0 * effect_scale, 150.0 * effect_scale, 0.5 * 64.0 * effect_scale, 220.0 * effect_scale, -25.0, false)
			_bloom(node, _RAYS, primary, 75.0 * effect_scale, 525.0 * effect_scale, 0.0, 0.25, 0.0)
		2:
			_puff(node, _PARTICLE_STARS, primary, 64, 1.25, 50.0 * effect_scale, 150.0 * effect_scale, 0.5 * 64.0 * effect_scale, 220.0 * effect_scale, -25.0, false)
			_bloom(node, _RAYS, primary, 100.0 * effect_scale, 700.0 * effect_scale, 0.0, 0.25, 0.0)
			_puff(node, _SHARP, secondary, 32, 1.5, 20.0 * effect_scale, 40.0 * effect_scale, 0.8 * 64.0 * effect_scale, 100.0 * effect_scale, -10.0, false)
		15:
			_puff(node, _SHARP, primary, 32, 1.5, 15.0 * effect_scale, 35.0 * effect_scale, 1.2 * 16.0 * effect_scale, 100.0 * effect_scale, -15.0, false)
		3, 4:
			_bloom(node, _BURST_A, primary, 200.0 * effect_scale, 700.0 * effect_scale, 0.0, 1.25, 0.0)
			_bloom(node, _BURST_B, primary, 250.0 * effect_scale, 720.0 * effect_scale, 0.0, 1.0, 0.0)
			_bloom(node, _STARS2, primary, 660.0 * effect_scale, 720.0 * effect_scale, 0.25, 1.0, 0.4)
			if kind == 4:
				_puff(node, _PARTICLE_STARS, secondary, 32, 1.5, 20.0 * effect_scale, 40.0 * effect_scale, 0.8 * 64.0 * effect_scale, 100.0 * effect_scale, -10.0, false)
		5, 6:
			var ring := _puff(node, _SOFT, primary, 16, 1.0, 70.0 * effect_scale, 80.0 * effect_scale, 1.3 * 16.0 * effect_scale, 200.0 * effect_scale, -15.0, true)
			ring.rotation_degrees.x = randf_range(50.0, 100.0)
			_bloom(node, _PARTICLE_STARS, primary, 50.0 * effect_scale, 75.0 * effect_scale, 0.0, 1.0, 0.0)
			if kind == 6:
				_puff(node, _PARTICLE_STARS, secondary, 24, 1.2, 20.0 * effect_scale, 40.0 * effect_scale, 0.8 * 64.0 * effect_scale, 75.0 * effect_scale, -10.0, false)
		7:
			_puff(node, _SOFT, primary, 24, 1.2, 15.0 * effect_scale, 35.0 * effect_scale, 16.0 * effect_scale, 250.0 * effect_scale, 10.0, false)
			_bloom(node, _RAYS, primary, 100.0 * effect_scale, 700.0 * effect_scale, 0.0, 0.25, 0.0)
		8, 10:
			_explode_trails(node, primary, effect_scale)
		14:
			_puff(node, _ICECREAM, Color.WHITE, 48, 3.25, 18.0 * effect_scale, 22.0 * effect_scale, 0.5 * 18.0 * effect_scale, 150.0 * effect_scale, -0.25, false)


func _explode_trails(node: Node3D, color: Color, effect_scale: float) -> void:
	for vel in _TRAILS:
		var jitter := Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(0, 50))
		var shot := (vel + jitter) * effect_scale
		var spark := Node3D.new()
		node.add_child(spark)
		_trail(spark, _PARTICLE_STARS, color, 2.0, 0.3 * 64.0 * effect_scale)
		var record := {
			"node": spark,
			"start": Vector3.ZERO,
			"vel": _godot(shot),
			"grav": 0.6,
			"age": 0.0,
			"burst": 2.1,
			"boomed": false,
			"kind": 9,
			"fx": effect_scale,
			"c1": color,
			"c2": color,
		}
		_live.append(record)


func _sprite(parent: Node3D, tex: Texture2D, color: Color, size: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = _quad
	mesh.material_override = _mat(tex, color)
	mesh.scale = Vector3.ONE * maxf(size, 0.01)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh


func _bloom(parent: Node3D, tex: Texture2D, color: Color, start_size: float, end_size: float, fade_in: float, fade_out: float, delay: float) -> void:
	var mesh := _sprite(parent, tex, Color(color.r, color.g, color.b, 0.0), start_size)
	var mat := mesh.material_override as StandardMaterial3D
	if fade_in <= 0.0:
		mat.albedo_color = color
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	if fade_in > 0.0:
		tw.tween_property(mat, "albedo_color", color, fade_in)
	tw.parallel().tween_property(mesh, "scale", Vector3.ONE * end_size, maxf(fade_out, 0.05))
	tw.parallel().tween_property(mat, "albedo_color", Color(color.r, color.g, color.b, 0.0), maxf(fade_out, 0.05))
	tw.chain().tween_callback(mesh.queue_free)


func _puff(parent: Node3D, tex: Texture2D, color: Color, amount: int, life: float, speed_min: float, speed_max: float, size: float, radius: float, gravity: float, ring: bool) -> CPUParticles3D:
	var bits := CPUParticles3D.new()
	bits.mesh = _quad
	bits.material_override = _mat(tex, Color.WHITE)
	bits.one_shot = true
	bits.explosiveness = 1.0
	bits.amount = amount
	bits.lifetime = life
	bits.direction = Vector3.UP
	bits.spread = 180.0
	bits.initial_velocity_min = speed_min
	bits.initial_velocity_max = maxf(speed_max, speed_min + 0.1)
	bits.scale_amount_min = maxf(size, 0.05)
	bits.scale_amount_max = maxf(size, 0.05)
	bits.gravity = Vector3(0, gravity, 0)
	bits.color = color
	bits.emitting = true
	if ring:
		bits.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		bits.emission_ring_radius = radius
		bits.emission_ring_inner_radius = radius * 0.85
	else:
		bits.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		bits.emission_sphere_radius = radius
	parent.add_child(bits)
	return bits


func _trail(parent: Node3D, tex: Texture2D, color: Color, life: float, size: float) -> void:
	var bits := GPUParticles3D.new()
	bits.name = "Trail2" if parent.get_node_or_null("Trail") != null else "Trail"
	bits.local_coords = false
	bits.amount = 24
	bits.lifetime = maxf(life, 0.1)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process.direction = Vector3(0, 1, 0)
	process.spread = 12.0
	process.initial_velocity_min = 0.2
	process.initial_velocity_max = 0.8
	process.gravity = Vector3.ZERO
	process.scale_min = maxf(size, 0.05)
	process.scale_max = maxf(size, 0.05)
	process.color = color
	bits.process_material = process
	bits.draw_pass_1 = _quad
	bits.material_override = _mat(tex, Color.WHITE)
	parent.add_child(bits)


func _mat(tex: Texture2D, color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.albedo_texture = tex
	mat.albedo_color = color
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return mat


func _whistle() -> void:
	var player := ToonAudio.effect_player()
	player.stream = _WHISTLE[randi() % _WHISTLE.size()]
	player.volume_db = linear_to_db(0.075)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func _burst_sound() -> void:
	var player := ToonAudio.effect_player()
	player.stream = _BURST_SFX[randi() % _BURST_SFX.size()]
	player.volume_db = linear_to_db(0.8)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func _begin_music() -> void:
	var stream: AudioStream = _MUSIC.get(_show)
	if stream == null:
		return
	_music = ToonAudio.music_player()
	_music.stream = stream
	_music.volume_db = linear_to_db(0.8)
	add_child(_music)
	_music.play(maxf(0.0, _clock - 2.0))


func _night() -> void:
	var amount := 1.0
	if _clock >= 0.0 and _clock < 2.5:
		amount = 1.0 - _clock / 2.5
	elif _clock >= 2.5 and _clock < _restore_at:
		amount = 0.0
	elif _clock >= _restore_at:
		amount = clampf((_clock - _restore_at) / 2.5, 0.0, 1.0)
	_set_night(amount)


func _set_night(amount: float) -> void:
	if absf(amount - _night_sent) < 0.05 and amount > 0.02 and amount < 0.98:
		return
	_night_sent = amount
	var host := get_parent()
	if host == null:
		return
	var sky := host.get_node_or_null("ToontownSky")
	if sky != null and sky.has_method("set_night"):
		sky.call("set_night", amount)


func _place() -> void:
	var host := get_parent()
	var file := ""
	if host != null:
		file = host.scene_file_path.get_file()
	var panda := Vector3(150, 0, 80)
	var party := false
	if file == "party_grounds.tscn":
		panda = Vector3(0, -400, 120)
		party = true
	elif file in ["the_burrrgh.tscn", "walrus_way.tscn", "sleet_street.tscn", "polar_place.tscn"]:
		panda = Vector3(-200, -60, 50)
	elif file in ["minnies_melodyland.tscn", "tenor_terrace.tscn", "alto_avenue.tscn", "baritone_boulevard.tscn"]:
		panda = Vector3(150, -25, 40)
	elif file in ["donalds_dreamland.tscn", "pajama_place.tscn", "lullaby_lane.tscn"]:
		panda = Vector3(-160, 0, 80)
	elif file in ["daisy_gardens.tscn", "elm_street.tscn", "maple_street.tscn", "oak_street.tscn"]:
		panda = Vector3(-80, -50, 60)
	elif file in ["donalds_dock.tscn", "lighthouse_lane.tscn", "seaweed_street.tscn", "barnacle_boulevard.tscn"]:
		panda = Vector3(150, 0, 50)
	elif file == "goofy_speedway.tscn":
		panda = Vector3(60, -350, 80)
	elif file.begins_with("acorn"):
		panda = Vector3(-450, -80, 140)
	var placed := _godot(panda)
	position = placed
	if party:
		scale = Vector3.ONE * 1.8
	var away := placed.normalized()
	if away.length_squared() < 0.001:
		away = Vector3(0, 0, 1)
	var side := Vector3.UP.cross(away)
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()
	basis = Basis(side, away.cross(side).normalized(), away)


func _opening() -> String:
	match _show:
		"july4":
			return "Toon HQ: Welcome to summer fireworks! Enjoy the show!"
		"newyear":
			return "Toon HQ: Happy New Year! Enjoy the fireworks show!"
		"combo":
			return "Toon HQ: Enjoy lots of Laffs with Toon fireworks!"
		_:
			return "Party fireworks are about to start! Enjoy the show!"


func _closing() -> String:
	match _show:
		"july4":
			return "Toon HQ: Hope you enjoyed the show! Have a great summer!"
		"newyear":
			return "Toon HQ: Hope you enjoyed the show! Happy New Year!"
		"combo":
			return "Toon HQ: Thank you, Toons! Hope you enjoyed the show!"
		_:
			return "Hope you enjoyed the show!"


func _instructions() -> String:
	if _show == "summer":
		return "Hit the \"Page Up\" key to see better."
	return "Toon HQ: Hit the \"Page Up\" key to see the show!"


func _say(text: String) -> void:
	var chat := get_tree().root.find_child("SpeedChat", true, false)
	if chat != null and chat.has_method("alert"):
		chat.call("alert", text)


func _music_player() -> AudioStreamPlayer:
	var host := get_parent()
	if host == null:
		return null
	var music := host.get_node_or_null("NeighborhoodMusic") as AudioStreamPlayer
	if music == null:
		music = host.get_node_or_null("PlaygroundMusic") as AudioStreamPlayer
	return music


## One show node per playground. The token keeps a relayed copy from starting twice.
static func present(host: Node, show_name: String, at: int = -1, delay: float = 0.0) -> void:
	if host == null:
		return
	if at < 0:
		at = int(Time.get_unix_time_from_system())
	var token := "%s:%d:%.1f" % [show_name, at, delay]
	if String(host.get_meta("dev_show", "")) == token and host.get_node_or_null("FireworkShow") != null:
		return
	host.set_meta("dev_show", token)
	var existing := host.get_node_or_null("FireworkShow")
	if existing != null and existing.has_method("takeover"):
		existing.call("takeover")
	var show := (load("res://scenes/effects/firework_show.gd") as GDScript).new() as Node
	show.name = "FireworkShow"
	host.add_child(show)
	show.call("setup", show_name, at, delay)


## dev:fireworks is the shared record. A party launch stays on the party grounds.
## ~fireworks plays in the playground it was started in, or in every playground
## when the word was "all".
static func follow(host: Node) -> void:
	if host == null:
		return
	var state: Dictionary = ToonNet.latest("dev:fireworks")
	var show := String(state.get("show", ""))
	if show == "":
		return
	var here := host.scene_file_path.get_file()
	var delay := float(state.get("delay", 0.0))
	if delay > 0.0:
		if here != "party_grounds.tscn":
			return
	else:
		var hood := String(state.get("hood", ""))
		var there := String(state.get("scene", ""))
		if hood == "all":
			if not _playground_file(here):
				return
		elif there != "" and there != here:
			return
	present(host, show, int(state.get("at", 0)), delay)


static func _playground_file(file: String) -> bool:
	return file in [
		"toontown_central.tscn",
		"donalds_dock.tscn",
		"daisy_gardens.tscn",
		"minnies_melodyland.tscn",
		"the_burrrgh.tscn",
		"donalds_dreamland.tscn",
		"goofy_speedway.tscn",
		"acorn_acres.tscn",
	]


func _vec(value: Variant) -> Vector3:
	if value is String:
		if String(value) == "rv":
			return Vector3(randi_range(-60, 60), randi_range(10, 30), randi_range(125, 150))
		return Vector3.ZERO
	if value is Array and (value as Array).size() >= 4:
		var row: Array = value
		return Vector3(float(row[1]), float(row[2]), float(row[3]))
	return Vector3.ZERO


func _color(value: Variant) -> Color:
	if value is String or ((value is int or value is float) and int(value) == -1):
		return _PALETTE[randi() % _PALETTE.size()]
	if value is Array and (value as Array).size() >= 5:
		var row: Array = value
		return Color(float(row[1]), float(row[2]), float(row[3]), float(row[4]))
	return Color.WHITE


func _number(value: Variant, rolled: float) -> float:
	if value is String:
		return rolled
	return float(value)


func _godot(panda: Vector3) -> Vector3:
	return Vector3(panda.x, panda.z, -panda.y)


## Party lever only. The launch plays on the pad while the show clock is still
## waiting out the original 5 second post-launch delay.
func _arm_rockets() -> void:
	if _rockets.size() > 0:
		return
	if _rocket_frames.is_empty():
		var file := FileAccess.open(_ROCKET_DATA, FileAccess.READ)
		if file == null:
			return
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary:
			var rows: Variant = (parsed as Dictionary).get("frames", [])
			if rows is Array:
				_rocket_frames = PackedFloat32Array(rows)
	if _rocket_frames.size() < 16:
		return
	var host := get_parent()
	if host == null:
		return
	for node in host.find_children("joint1", "Node3D", true, false):
		var joint := node as Node3D
		if joint == null or not _is_rocket_joint(joint):
			continue
		var rocket := joint.get_parent() as Node3D
		if rocket == null:
			continue
		_rockets.append({
			"joint": joint,
			"rocket": rocket,
			"locator": _rocket_locator(joint),
			"lit": false,
			"fire": null,
			"smoke": null,
		})


func _is_rocket_joint(joint: Node3D) -> bool:
	var here: Node = joint
	while here != null:
		if String(here.name).contains("rocket_locator"):
			return true
		here = here.get_parent()
	return false


func _rocket_locator(joint: Node3D) -> Node3D:
	var here := joint.get_parent()
	while here != null:
		if String(here.name).contains("rocket_locator"):
			return here
		here = here.get_parent()
	return joint.get_parent()


func _step_rockets() -> void:
	if _delay <= 0.0:
		return
	if _rockets.is_empty():
		if _rocket_hunt < 120:
			_rocket_hunt += 1
			_arm_rockets()
		if _rockets.is_empty():
			return
	var t := _clock + _delay
	var flying := t < 8.0
	for item in _rockets:
		var joint := item["joint"] as Node3D
		var rocket := item["rocket"] as Node3D
		if not is_instance_valid(joint) or not is_instance_valid(rocket):
			continue
		if flying:
			_rocket_pose(joint, t)
			# Panda roll is around local Y, which this model still uses.
			rocket.basis = Basis(Vector3(0, 1, 0), deg_to_rad(_rocket_roll(t)))
			rocket.visible = true
			if t >= 2.0 and not bool(item["lit"]):
				item["lit"] = true
				_light_rocket(item)
		else:
			rocket.visible = false
			_quench_rocket(item)
	if flying and t >= 2.0 and not _rocket_sound:
		_rocket_sound = true
		_play_rocket_sound(t - 2.0)
	elif not flying:
		_rocket_sound = true


func _rocket_roll(t: float) -> float:
	if t <= 4.0:
		return 0.0
	if t >= 8.0:
		return -60.0
	return -60.0 * (t - 4.0) / 4.0


func _rocket_pose(joint: Node3D, t: float) -> void:
	var count := int(_rocket_frames.size() / 16)
	if count <= 0:
		return
	var frame := clampf(t * 24.0, 0.0, float(count - 1))
	var i0 := int(frame)
	var i1 := mini(i0 + 1, count - 1)
	joint.transform = _rocket_xf(i0).interpolate_with(_rocket_xf(i1), frame - float(i0))


func _rocket_xf(index: int) -> Transform3D:
	var o := index * 16
	var m := _rocket_frames
	return Transform3D(
		Vector3(m[o], m[o + 1], m[o + 2]),
		Vector3(m[o + 4], m[o + 5], m[o + 6]),
		Vector3(m[o + 8], m[o + 9], m[o + 10]),
		Vector3(m[o + 12], m[o + 13], m[o + 14])
	)


func _light_rocket(item: Dictionary) -> void:
	var joint := item["joint"] as Node3D
	var burned := maxf(_clock + _delay - 2.0, 0.0)
	var fire := CPUParticles3D.new()
	fire.name = "RocketFire"
	fire.local_coords = true
	fire.amount = 50
	fire.lifetime = 0.5
	fire.preprocess = minf(burned, 0.5)
	fire.explosiveness = 0.0
	fire.mesh = _quad
	fire.material_override = _rocket_mat(_FIREBALL, true)
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fire.emission_box_extents = Vector3(0.5, 0.05, 0.05)
	fire.position = Vector3(0.5, 0.0, 0.0)
	fire.direction = Vector3(0, 0, -1)
	fire.spread = 25.0
	fire.initial_velocity_min = 0.2
	fire.initial_velocity_max = 1.0
	fire.gravity = Vector3(0, 0, -22.5)
	fire.scale_amount_min = 1.0
	fire.scale_amount_max = 4.0
	var fire_ramp := Gradient.new()
	fire_ramp.set_color(0, Color(1, 1, 1, 0.69))
	fire_ramp.set_color(1, Color(0.73, 0.40, 0.11, 0.0))
	fire.color_ramp = fire_ramp
	fire.visibility_aabb = AABB(Vector3(-8, -8, -16), Vector3(16, 16, 20))
	joint.add_child(fire)
	item["fire"] = fire
	var locator := item["locator"] as Node3D
	if locator == null:
		return
	var smoke := CPUParticles3D.new()
	smoke.name = "RocketSmoke"
	smoke.local_coords = true
	smoke.position = Vector3(0, 0, 16)
	smoke.scale = Vector3(2, 2, 3)
	smoke.amount = 40
	smoke.lifetime = 4.0
	smoke.preprocess = minf(burned, 4.0)
	smoke.explosiveness = 0.0
	smoke.mesh = _quad
	smoke.material_override = _rocket_mat(_SMOKE_TEX, false)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	smoke.emission_box_extents = Vector3(1, 1, 0.15)
	smoke.direction = Vector3(0, 0, 1)
	smoke.spread = 180.0
	smoke.initial_velocity_min = 0.4
	smoke.initial_velocity_max = 2.4
	smoke.gravity = Vector3(0, 0, -2.5)
	smoke.scale_amount_min = 2.0
	smoke.scale_amount_max = 4.0
	var smoke_ramp := Gradient.new()
	smoke_ramp.set_color(0, Color(1, 1, 1, 0.0))
	smoke_ramp.add_point(0.15, Color(1, 1, 1, 0.47))
	smoke_ramp.set_color(1, Color(0.588, 0.588, 0.588, 0.0))
	smoke.color_ramp = smoke_ramp
	smoke.visibility_aabb = AABB(Vector3(-12, -12, -8), Vector3(24, 24, 24))
	locator.add_child(smoke)
	item["smoke"] = smoke


func _rocket_mat(tex: Texture2D, additive: bool) -> StandardMaterial3D:
	var mat := _mat(tex, Color.WHITE)
	if not additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	return mat


func _quench_rocket(item: Dictionary) -> void:
	var fire := item["fire"] as CPUParticles3D
	if fire != null and is_instance_valid(fire):
		fire.emitting = false
		fire.queue_free()
		item["fire"] = null
	var smoke := item["smoke"] as CPUParticles3D
	if smoke == null or not is_instance_valid(smoke) or not smoke.emitting:
		return
	smoke.emitting = false
	var mat := smoke.material_override as StandardMaterial3D
	if mat == null:
		smoke.queue_free()
		return
	var fade := smoke.create_tween()
	fade.tween_property(mat, "albedo_color", Color(1, 1, 1, 0), 2.0)
	fade.tween_callback(smoke.queue_free)


func _play_rocket_sound(offset: float) -> void:
	var player := ToonAudio.effect_player()
	player.stream = _ROCKET_SFX
	player.volume_db = 0.0
	add_child(player)
	player.finished.connect(player.queue_free)
	var length := _ROCKET_SFX.get_length()
	if length <= 0.0 or offset < length:
		player.play(maxf(offset, 0.0))
	else:
		player.queue_free()


func _drop_rocket() -> void:
	var t := _clock + _delay
	for item in _rockets:
		var fire := item["fire"] as CPUParticles3D
		if fire != null and is_instance_valid(fire):
			fire.queue_free()
		var smoke := item["smoke"] as CPUParticles3D
		if smoke != null and is_instance_valid(smoke):
			smoke.queue_free()
		var rocket := item["rocket"] as Node3D
		if rocket != null and is_instance_valid(rocket) and (t >= 8.0 or bool(item.get("lit", false))):
			rocket.visible = false
	_rockets.clear()
