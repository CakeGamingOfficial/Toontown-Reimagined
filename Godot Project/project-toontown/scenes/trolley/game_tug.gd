extends "res://scenes/trolley/trolley_minigame.gd"

## Tug-of-War on the original dock. Alternate the arrow keys so the marker
## stays on the red line. A win pays 15. Losing still pays 4.

var _marker := 0.0
var _pull := 0.0
var _last := ""
var _since := 0.0
var _filled := 0.0
var _whistled := false


func _init() -> void:
	title = "Tug-of-War"
	instructions = "Alternately tap the left and right arrow keys just fast enough to line up the green bar with the red line. Don't tap them too slow or too fast, or you'll end up in the water!"
	duration = 40.0


func begin() -> void:
	super.begin()
	if not _whistled:
		_whistled = true
		_sfx("AA_sound_whistle")


func _build() -> void:
	_show("res://assets/minigames/tug_set.glb")
	var toon := _make_toon(_panda(-6.0, 18.0, 0.1))
	toon.rotation_degrees.y = -90.0
	var cog := _flunky(6.0, 18.0, 0.1)
	cog.rotation_degrees.y = 90.0
	_aim(0.0, 1.08, 2.75, 0.0, 18.0, 1.2)
	show_board("power")


func _play(delta: float) -> void:
	_since += delta
	var tap := ""
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		tap = "l"
	elif Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		tap = "r"
	if tap != "" and tap != _last:
		var rate := 1.0 / maxf(_since, 0.05)
		_since = 0.0
		_last = tap
		if rate > 7.0:
			_pull = 1.6
		elif rate < 2.2:
			_pull = -1.2
		else:
			_pull = -_marker * 4.0
			_sfx("MG_pos_buzzer", 0.55)
	_marker = clampf(_marker + (_pull - 0.35) * delta, -1.0, 1.0)
	_pull = move_toward(_pull, 0.0, delta * 2.0)
	if _board != null:
		_board.set_power((_marker + 1.0) * 8.0, 8.0)
	if absf(_marker) < 0.18:
		_filled += delta
	if _filled >= 8.0:
		score = 15
		_end()


func _end() -> void:
	if _over:
		return
	if score < 15:
		score = 4 if _filled < 3.0 else 8
		_sfx("MG_cannon_splash")
	super._end()
