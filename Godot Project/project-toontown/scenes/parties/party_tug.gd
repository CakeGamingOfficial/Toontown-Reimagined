extends Node

## Party tug-of-war. Alternate the arrow keys so your rate stays on the moving
## target. Matching it pulls the rope. Falling in pays 15 or 4. A timed finish
## pays 12, 8, or a tie of 5.

signal finished(base_beans: int, message: String)

const _PHASES: Array[Vector2] = [
	Vector2(8.0, 6.0), Vector2(5.0, 7.0), Vector2(6.0, 8.0),
	Vector2(6.0, 10.0), Vector2(7.0, 11.0), Vector2(8.0, 12.0),
]

var _player: ToonActor
var _origin := Vector3.ZERO
var _time := 0.0
var _offset := 0.0
var _ideal := 6.0
var _phase := 0
var _phase_at := 0.0
var _ttl: Array[float] = []
var _award := 0.0
var _tick := 0.0
var _want := "l"
var _last_tap := ""
var _note: Label
var _done := false


func setup(player: ToonActor, origin: Vector3, _party: Dictionary) -> void:
	_player = player
	_origin = origin
	_player.global_position = origin + Vector3(-8.0, 0.2, 0.0)
	_player.rotation_degrees.y = 90.0
	_banner()


func holds_camera() -> bool:
	return not _done


func aim(camera: Camera3D) -> void:
	camera.global_position = _origin + Vector3(0.0, 10.0, 33.0)
	camera.look_at(_origin + Vector3(_offset, 6.0, 0.0), Vector3.UP)


func _process(delta: float) -> void:
	if _done or _player == null:
		return
	_time += delta
	_phase_at += delta
	if _phase < _PHASES.size() and _phase_at >= _PHASES[_phase].x:
		_phase_at = 0.0
		_phase += 1
	if _phase < _PHASES.size():
		_ideal = _PHASES[_phase].y
	_keys(delta)
	_tick += delta
	if _tick >= 0.2:
		_tick = 0.0
		var mine := _force(_rate())
		var theirs := 4.0 + 0.4 * _ideal
		_offset += (mine - theirs) * 0.03
		_player.global_position = _origin + Vector3(-8.0 + _offset, 0.2, 0.0)
		_player.set("velocity", Vector3.ZERO)
	_note.text = "Party Tug-of-War\nAlternate the arrow keys.\nRate %d / %d    Rope %.1f" % [_rate(), int(_ideal), _offset]
	if _offset >= 6.0:
		_finish(15, "You pulled them in!")
	elif _offset <= -6.0:
		_finish(4, "You were pulled into the water.")
	elif _time >= 40.0:
		if absf(_offset) <= 0.75:
			_finish(5, "It was a tie.")
		elif _offset > 0.0:
			_finish(12, "You won the tug!")
		else:
			_finish(8, "The other side won.")


func _keys(delta: float) -> void:
	for index in _ttl.size():
		_ttl[index] -= delta
	var kept: Array[float] = []
	for life in _ttl:
		if life > 0.0:
			kept.append(life)
	_ttl = kept
	var tap := ""
	if Keybinds.held("left") or Input.is_physical_key_pressed(KEY_LEFT):
		tap = "l"
	elif Keybinds.held("right") or Input.is_physical_key_pressed(KEY_RIGHT):
		tap = "r"
	if tap == _want and tap != _last_tap:
		_ttl.insert(0, 1.0)
		_want = "r" if tap == "l" else "l"
	_last_tap = tap
	var rate := _rate()
	if rate == int(_ideal) or rate == int(_ideal) + 1:
		_award += 0.3 * delta / 0.1
	else:
		_award = 0.0


func _rate() -> int:
	return _ttl.size()


func _force(rate: int) -> float:
	var spread := 0.25 * _ideal
	if spread <= 0.01:
		return 0.0
	var match := exp(-pow(float(rate) - _ideal, 2.0) / (2.0 * spread * spread))
	return (_award + 4.0 + 0.4 * _ideal) * match


func _finish(beans: int, line: String) -> void:
	_player.global_position = _origin + Vector3(0.0, 0.2, 8.0)
	_player.set("velocity", Vector3.ZERO)
	_done = true
	finished.emit(beans, line + "\n\nJellybeans earned: %d")
	queue_free()


func _banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_note = Label.new()
	_note.position = Vector2(40, 40)
	_note.size = Vector2(760, 150)
	ToonGui.style_label(_note, Color.WHITE, 28, Color(0.1, 0.05, 0.2), 4)
	layer.add_child(_note)
