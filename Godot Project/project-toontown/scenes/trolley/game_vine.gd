extends "res://scenes/trolley/trolley_minigame.gd"

## Jungle Vines. The rope is the swinging vine from SwingVine: thickness 1,
## hung from VineHeight, textured with vine1. Spiders, bats, and bananas use
## the scales in VineSpider, VineBat, and VineTreasure. The toon plays swing.

const _STEP := 30.0
const _ANCHOR_Z := 30.0
const _START_T := 0.25
const _CLIMB_RATE := 0.25
const _HANG := 4.0
const _JUMP_FRAME := 128.0
const _SPIDER_SCALE := 0.2
const _BAT_SCALE := 0.15
const _BANANA_SCALE := 0.25
const _VINE_TEX := preload("res://assets/minigames/vine_0.png")

# length, base angle, period, spider period. First eight vines of a TTC course.
# Spider periods 9 and 11 are the ones CourseSections actually uses.
const _COURSE: Array[Vector4] = [
	Vector4(20, 30, 4.0, 0),
	Vector4(19, 39, 3.1, 0),
	Vector4(18, 41, 4.0, 9),
	Vector4(19, 38, 3.2, 0),
	Vector4(20, 30, 6.0, 0),
	Vector4(20, 30, 3.0, 11),
	Vector4(18, 40, 4.1, 0),
	Vector4(19, 31, 5.1, 0),
]

var _vines: Array[Dictionary] = []
var _index := 0
var _t := _START_T
var _facing := 1
var _jump := -1.0
var _jump_from := Vector3.ZERO
var _bananas: Array[Node3D] = []
var _bat: Node3D
var _bat_x := 0.0
var _bat_z := 18.0
var _hurt := 0.0
var _armed := false
var _vine_shader: Shader


func _init() -> void:
	title = "Jungle Vines"
	instructions = "Get to the rightmost vine in time. Press Up or Down to climb the vine.  Press Left or Right to change facing and jump.  The lower you are on the vine, the faster you jump off.  Collect the bananas if you can, but avoid the bats and spiders."
	duration = 70.0


func _build() -> void:
	_show("res://assets/minigames/vine_background.glb")
	var start := _spawn("res://assets/minigames/vine_start.glb", -16.0, 0.0, 15.0)
	if start != null:
		start.scale = Vector3(1.0, 0.75, 1.0)
	var end := _spawn("res://assets/minigames/vine_end.glb", _STEP * float(_COURSE.size() - 1) + 20.0, 0.0, 15.0)
	if end != null:
		end.scale = Vector3(1.0, 0.75, 1.0)
	for index in _COURSE.size():
		_vines.append(_make_vine(index, _COURSE[index]))
	for index in _COURSE.size() - 1:
		var height := 12.0 + float(index % 5) * 2.5
		var bunch := _card("res://assets/minigames/bananas.glb", _STEP * float(index) + 15.0, 0.0, height, _BANANA_SCALE)
		if bunch != null:
			_bananas.append(bunch)
	_bat_x = _STEP * float(_COURSE.size())
	_bat = _card("res://assets/minigames/bat.glb", _bat_x, 0.0, _bat_z, _BAT_SCALE)
	_make_toon(_hang())
	_toon.rotation_degrees.y = -90.0
	_toon.ensure_clip("swing")
	_swing_vines(0.0)
	_pose_toon()
	_look()
	_loop_sfx("MG_sfx_vine_game_bat_flying_lp", 0.25)
	show_board("avatar")


func _play(delta: float) -> void:
	_swing_vines(delta)
	_fly_bat(delta)
	_hurt = maxf(_hurt - delta, 0.0)
	if _jump >= 0.0:
		_jump += delta
		var speed := 0.7 + _t * 1.1
		var u := clampf(_jump * speed, 0.0, 1.0)
		var dest := _hang_on(_index + _facing)
		var pos := _jump_from.lerp(dest, u)
		pos.y += sin(u * PI) * 3.0
		_toon.position = pos
		_toon.pose_action("swing", _JUMP_FRAME / 24.0)
		if u >= 1.0:
			_index += _facing
			_jump = -1.0
			_toon.position = _hang()
			_sfx("MG_sfx_vine_game_catch")
			if _index >= _COURSE.size() - 1:
				score += 8
				_sfx("MG_sfx_vine_game_finish")
				_end()
		_look()
		return
	var move := _stick()
	if move.y > 0.5 and _index < _COURSE.size() - 1:
		_t = clampf(_t - delta * _CLIMB_RATE, 0.0, 1.0)
	elif move.y < -0.5 and _index < _COURSE.size() - 1:
		_t = clampf(_t + delta * _CLIMB_RATE, 0.0, 1.0)
	if move.x == 0.0:
		_armed = true
	elif _armed and _hurt <= 0.0:
		_facing = 1 if move.x > 0.0 else -1
		_armed = false
		_toon.rotation_degrees.y = -90.0 if _facing > 0 else 90.0
		if _index + _facing >= 0 and _index + _facing < _COURSE.size():
			_jump_from = _toon.position
			_jump = 0.0
			_sfx("MG_sfx_vine_game_jump")
	if _jump < 0.0:
		_toon.position = _hang()
		_pose_toon()
		_collect()
	_look()


func _make_vine(index: int, info: Vector4) -> Dictionary:
	var anchor := Node3D.new()
	anchor.position = _panda(float(index) * _STEP, 0.0, _ANCHOR_Z)
	add_child(anchor)
	var canopy := _vine_card(8.0)
	canopy.position = Vector3(0.0, 4.0, 0.0)
	anchor.add_child(canopy)
	var pivot := Node3D.new()
	anchor.add_child(pivot)
	var rope := _vine_card(info.x)
	rope.position = Vector3(0.0, -info.x * 0.5, 0.0)
	pivot.add_child(rope)
	var spider: Node3D = null
	if info.w > 0.0:
		spider = _card("res://assets/minigames/spider.glb", 0.0, 0.0, 0.0, _SPIDER_SCALE, pivot)
	return {
		"pivot": pivot,
		"length": info.x,
		"angle": info.y,
		"period": info.z,
		"time": 0.0,
		"half_t": 0.0,
		"forward": true,
		"spider": spider,
		"spider_period": info.w,
		"spider_time": 0.0,
	}


func _swing_vines(delta: float) -> void:
	for vine in _vines:
		vine["time"] = float(vine["time"]) + delta
		var period := float(vine["period"])
		var half := period * 0.5
		var phase := fposmod(float(vine["time"]), period)
		var forward := phase < half
		var u := phase / half if forward else (phase - half) / half
		u = u * u * (3.0 - 2.0 * u)
		var base := float(vine["angle"])
		var offset := lerpf(-base, base, u) if forward else lerpf(base, -base, u)
		vine["half_t"] = u
		vine["forward"] = forward
		var pivot := vine["pivot"] as Node3D
		pivot.rotation_degrees.z = offset
		var spider := vine["spider"] as Node3D
		if spider == null:
			continue
		var spider_period := float(vine["spider_period"])
		vine["spider_time"] = float(vine["spider_time"]) + delta
		var spider_phase := fposmod(float(vine["spider_time"]), spider_period)
		var spider_half := spider_period * 0.5
		var down := spider_phase < spider_half
		var su := spider_phase / spider_half if down else (spider_phase - spider_half) / spider_half
		su = su * su * (3.0 - 2.0 * su)
		var along := su if down else 1.0 - su
		vine["spider_t"] = along
		spider.position = Vector3(0.0, -along * float(vine["length"]), 0.5)
		spider.rotation_degrees = Vector3(-90.0, 0.0, 0.0 if down else 180.0)


func _fly_bat(delta: float) -> void:
	if _bat == null:
		return
	var span := _STEP * float(_COURSE.size()) + _STEP
	_bat_x -= span / 60.0 * delta
	if _bat_x < -_STEP:
		_bat_x = _STEP * float(_COURSE.size())
		_bat_z = 10.0 + fposmod(_bat_z * 1.7, 18.0)
	_bat.position = _panda(_bat_x, 0.0, _bat_z)
	if _hurt <= 0.0 and _bat.global_position.distance_to(_chest()) < 2.2:
		_sting("MG_sfx_vine_game_bat_hit", true)


func _collect() -> void:
	var chest := _chest()
	for vine_index in _vines.size():
		var vine: Dictionary = _vines[vine_index]
		var spider := vine["spider"] as Node3D
		if spider == null or vine_index != _index:
			continue
		if absf(float(vine.get("spider_t", 0.0)) - _t) < 0.12 and _hurt <= 0.0:
			_sting("MG_sfx_vine_game_spider_hit", false)
	for bunch in _bananas:
		if bunch.visible and bunch.global_position.distance_to(chest) < 2.0:
			bunch.visible = false
			score += 1
			_sfx("MG_sfx_vine_game_bananas")


func _sting(sound: String, drop_score: bool) -> void:
	_hurt = 0.9
	_t = 0.92
	if drop_score:
		score = maxi(score - 1, 0)
	_sfx(sound)


func _pose_toon() -> void:
	var frame := _swing_frame(_vines[_index])
	_toon.pose_action("swing", frame / 24.0)


func _swing_frame(vine: Dictionary) -> float:
	var lean := _t * float(vine["angle"])
	var half_t := float(vine["half_t"])
	var with_vine := bool(vine["forward"]) == (_facing > 0)
	if lean > 10.0:
		if with_vine:
			if half_t < 0.5:
				return lerpf(108.0, 143.0, half_t * 2.0)
			return lerpf(0.0, 35.0, (half_t - 0.5) * 2.0)
		return lerpf(35.0, 107.0, half_t)
	if lean > 2.0:
		return lerpf(5.0, 15.0, half_t) if with_vine else lerpf(15.0, 5.0, half_t)
	return lerpf(88.0, 84.0, half_t) if with_vine else lerpf(84.0, 88.0, half_t)


func _hang() -> Vector3:
	return _hang_on(_index)


func _hang_on(index: int) -> Vector3:
	return _point(_vines[index], _t) + Vector3(0.0, -_HANG, 0.0)


func _point(vine: Dictionary, down: float) -> Vector3:
	var pivot := vine["pivot"] as Node3D
	return pivot.global_position + pivot.global_transform.basis * Vector3(0.0, -down * float(vine["length"]), 0.0)


func _chest() -> Vector3:
	return _toon.global_position + Vector3(0.0, 2.2, 0.0)


func _look() -> void:
	var x := _toon.position.x
	_aim(x, -53.0, 17.3, x, 0.0, 17.3)


func _card(path: String, x: float, y: float, z: float, card_scale: float, parent: Node3D = null) -> Node3D:
	var model := _prop(path)
	if model == null:
		return null
	var holder := Node3D.new()
	(parent if parent != null else self).add_child(holder)
	holder.position = _panda(x, y, z) if parent == null else Vector3(x, y, z)
	holder.add_child(model)
	holder.rotation_degrees.x = -90.0
	model.scale = Vector3(card_scale, card_scale, card_scale)
	return holder


func _vine_card(length: float) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.orientation = PlaneMesh.FACE_Z
	mesh.size = Vector2(1.0, length)
	var card := MeshInstance3D.new()
	card.mesh = mesh
	card.material_override = _vine_material(length)
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return card


func _vine_material(length: float) -> ShaderMaterial:
	if _vine_shader == null:
		_vine_shader = Shader.new()
		_vine_shader.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled, blend_mix, depth_prepass_alpha;\nuniform sampler2D albedo : source_color, repeat_enable;\nuniform float tiles = 3.0;\nvoid fragment() {\n\tvec4 tex = texture(albedo, vec2(UV.x, UV.y * tiles));\n\tALBEDO = tex.rgb;\n\tALPHA = tex.a;\n}\n"
	var material := ShaderMaterial.new()
	material.shader = _vine_shader
	material.set_shader_parameter("albedo", _VINE_TEX)
	material.set_shader_parameter("tiles", maxf(length * 0.15, 0.15))
	return material
