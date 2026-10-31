extends "res://scenes/trolley/trolley_minigame.gd"

## Toon Slingshot. Desert, trampolines, cacti, and the umbrella are the original models.
## Pound left and right for power, pause to launch, then steer. Down opens the umbrella.

var _power := 0.0
var _last := ""
var _idle := 0.0
var _phase := "pound"
var _shots := 0
var _vel := Vector3.ZERO
var _umbrella := false
var _chute: Node3D
var _pads: Array[Dictionary] = []
var _cacti: Array[Node3D] = []
var _meter: ColorRect
var _stretch := 0.0


func _init() -> void:
	title = "Toon Slingshot"
	instructions = "Land on targets to score points"
	duration = 90.0


func _build() -> void:
	_show("res://assets/minigames/slingshot_desert.glb")
	var spots := [
		{"x": 0.0, "y": 55.0, "points": 10},
		{"x": 16.0, "y": 100.0, "points": 6},
		{"x": -18.0, "y": 150.0, "points": 3},
		{"x": 8.0, "y": 200.0, "points": 1},
	]
	for spot in spots:
		var pad := _spawn("res://assets/minigames/trampoline.glb", float(spot["x"]), float(spot["y"]), 0.05, 3.0)
		if pad == null:
			continue
		_pads.append({"node": pad, "points": int(spot["points"])})
	for index in 10:
		var cactus := _spawn("res://assets/minigames/cactus.glb", randf_range(-40.0, 40.0), 20.0 + float(index) * 18.0, 0.0, randf_range(0.7, 1.3))
		if cactus != null:
			_cacti.append(cactus)
	_chute = _spawn("res://assets/minigames/umbrella.glb", 0.0, 0.0, 2.0, 1.2)
	if _chute != null:
		_chute.visible = false
	_make_toon(_panda(0.0, 0.0, 0.0))
	_aim(0.0, -18.0, 8.0, 0.0, 20.0, 1.0)
	_loop_sfx("target_wind_fly_loop", 0.25)
	var layer := CanvasLayer.new()
	add_child(layer)
	_meter = ColorRect.new()
	_meter.color = Color(0.95, 0.3, 0.1)
	_meter.position = Vector2(40, 400)
	_meter.size = Vector2(20, 20)
	layer.add_child(_meter)
	show_board("slingshot")


func _play(delta: float) -> void:
	if _phase == "pound":
		_idle += delta
		var tap := ""
		if Input.is_physical_key_pressed(KEY_LEFT):
			tap = "l"
		elif Input.is_physical_key_pressed(KEY_RIGHT):
			tap = "r"
		_stretch = maxf(_stretch - delta, 0.0)
		if tap != "" and tap != _last:
			_last = tap
			_idle = 0.0
			_power = clampf(_power + 0.12, 0.0, 1.0)
			if _stretch <= 0.0:
				_stretch = 0.18
				_sfx("target_stretching_aim_loop", 0.4)
		_power = maxf(_power - delta * 0.15, 0.0)
		_meter.size.y = 20.0 + _power * 180.0
		if _power > 0.2 and _idle > 0.35:
			_launch()
	else:
		var move := _stick()
		_umbrella = move.y < -0.5
		if _chute != null:
			_chute.visible = _umbrella
			_chute.position = _toon.position + Vector3(0.0, 1.6, 0.0)
		var gravity := 12.0 if _umbrella else 22.0
		_vel.y -= gravity * delta
		_vel.x = move.x * 16.0
		_toon.position += _vel * delta
		_camera.position = _toon.position + Vector3(0.0, 12.0, 28.0)
		_camera.look_at(_toon.position, Vector3.UP)
		if _toon.position.y <= 0.4 and _vel.y < 0.0:
			_land()


func _launch() -> void:
	_phase = "fly"
	_umbrella = false
	if _board != null:
		_board.show_round(_shots + 1, score, false)
	_sfx("target_launch")
	var reach := 50.0 + _power * 170.0
	var time := 3.1
	_vel = Vector3(0.0, 0.5 * 22.0 * time, -reach / time)
	_toon.position = _panda(0.0, 0.0, 1.0)


func _land() -> void:
	var gained := 0
	var best := 18.0
	for pad in _pads:
		var node := pad["node"] as Node3D
		var dist := Vector2(_toon.position.x - node.position.x, _toon.position.z - node.position.z).length()
		if dist < best:
			best = dist
			gained = int(pad["points"])
	var cactus := false
	for plant in _cacti:
		if Vector2(_toon.position.x - plant.position.x, _toon.position.z - plant.position.z).length() < 3.0:
			cactus = true
	if cactus:
		gained = 0
		_sfx("target_impact_grunt1")
	elif gained > 0:
		score += gained
		_sfx("target_trampoline_2" if gained >= 6 else "target_happydance", 0.8)
	else:
		_sfx("target_Lose", 0.7)
	if _umbrella:
		_sfx("target_chute", 0.5)
	_shots += 1
	_power = 0.0
	_phase = "pound"
	_umbrella = false
	if _chute != null:
		_chute.visible = false
	_toon.position = _panda(0.0, 0.0, 0.0)
	_aim(0.0, -18.0, 8.0, 0.0, 20.0, 1.0)
	if _board != null:
		_board.show_round(_shots, score, true)
	if _shots >= 3:
		_end()
