extends "res://scenes/trolley/trolley_minigame.gd"

## Match Minnie. Four rounds, length 2 then 4, 6, and 8.
## A finished round scores its number. A perfect game scores 4 more.
## A solo ride does not get the fastest-player bonus.

const _LENGTHS: Array[int] = [2, 4, 6, 8]
const _SOUNDS: PackedStringArray = ["m_match_trumpet", "m_match_guitar", "m_match_drums", "m_match_piano"]

var _round := 0
var _pattern: Array[int] = []
var _typed: Array[int] = []
var _phase := "watch"
var _wait := 1.2
var _step := 0
var _input_left := 10.0
var _perfect := true
var _banner: Label
var _arrows: Array[Label] = []
var _held := false


func _init() -> void:
	title = "Match Minnie"
	instructions = "Minnie will show you a dance sequence. Try to repeat Minnie's dance just the way you see it using the arrow keys!"
	duration = 180.0


func begin() -> void:
	super.begin()
	if _clock_face != null:
		_clock_face.visible = false
		_clock_num.visible = false


func _build() -> void:
	_show("res://assets/minigames/matching_room.glb")
	_make_toon(_panda(lineup_x(3.0), 18.0, 0.0))
	_toon.look_at(_panda(0.0, 8.0, 1.0), Vector3.UP)
	_aim(0.0, 8.0, 5.0, 0.0, 16.0, 1.2)
	var layer := CanvasLayer.new()
	layer.layer = 21
	add_child(layer)
	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 70
	_banner.offset_bottom = 140
	_banner.offset_left = -420
	_banner.offset_right = 420
	_banner.add_theme_font_size_override("font_size", 34)
	_banner.add_theme_color_override("font_color", Color(0.95, 0.95, 0.7))
	layer.add_child(_banner)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.offset_top = -160
	row.offset_bottom = -80
	row.offset_left = -280
	row.offset_right = 280
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	layer.add_child(row)
	for _i in range(8):
		var mark := Label.new()
		mark.custom_minimum_size = Vector2(48, 48)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.add_theme_font_size_override("font_size", 40)
		mark.add_theme_color_override("font_color", Color(1, 0.15, 0.15))
		mark.text = ""
		row.add_child(mark)
		_arrows.append(mark)
	_start_round()
	show_board("points")


func _play(delta: float) -> void:
	_toon.set_locomotion(0.0, false, false, delta)
	_wait -= delta
	if _phase == "watch":
		_watch(delta)
	elif _phase == "go":
		if _wait <= 0.0:
			_phase = "input"
			_input_left = 10.0
			_banner.text = "GO!"
			_held = _stick().length() > 0.2
	elif _phase == "input":
		_input_left -= delta
		_banner.text = "GO!  %d" % maxi(int(ceil(_input_left)), 0)
		_read_keys()
		if _input_left <= 0.0:
			_finish_round(false)
	elif _phase == "result":
		if _wait <= 0.0:
			if _round >= _LENGTHS.size():
				if _perfect:
					score += 4
					_sfx("MG_win")
					_banner.text = "That was perfect, Toon!"
					_phase = "bye"
					_wait = 1.6
				else:
					_end()
			else:
				_start_round()
	elif _phase == "bye" and _wait <= 0.0:
		_end()


func _start_round() -> void:
	_pattern.clear()
	_typed.clear()
	var length := _LENGTHS[_round]
	for _i in range(length):
		_pattern.append(shared_int(4))
	_step = 0
	_phase = "watch"
	_wait = 1.1
	_banner.text = "Round %d!   Watch these dance steps..." % (_round + 1)
	_paint_arrows(-1)


func _watch(_delta: float) -> void:
	if _wait > 0.0:
		return
	if _step >= _pattern.size():
		_phase = "go"
		_wait = 0.55
		_banner.text = "GO!"
		_paint_arrows(-1)
		return
	_paint_arrows(_step)
	_sfx(_SOUNDS[_pattern[_step]])
	_step += 1
	var rate := 1.4 * pow(1.06, _round)
	_wait = 0.72 / rate


func _read_keys() -> void:
	var move := _stick()
	var pressed := move.length() > 0.2
	if not pressed:
		_held = false
		return
	if _held:
		return
	_held = true
	var dir := 0
	if absf(move.x) > absf(move.y):
		dir = 3 if move.x > 0.0 else 1
	else:
		dir = 0 if move.y > 0.0 else 2
	var index := _typed.size()
	if index >= _pattern.size():
		return
	_typed.append(dir)
	_paint_typed()
	if dir != _pattern[index]:
		_sfx("MG_Tag_A")
		_finish_round(false)
		return
	_sfx(_SOUNDS[dir])
	if _typed.size() == _pattern.size():
		_sfx("MG_pos_buzzer")
		_finish_round(true)


func _finish_round(ok: bool) -> void:
	if _phase == "result":
		return
	_phase = "result"
	_wait = 1.4
	if ok:
		_round += 1
		score += _round
		_banner.text = "Good!"
	else:
		_perfect = false
		_round += 1
		_banner.text = "Oops!"


func _paint_arrows(shown: int) -> void:
	for i in range(_arrows.size()):
		var mark := _arrows[i]
		if i >= _pattern.size() or i > shown:
			mark.text = ""
			continue
		mark.text = _glyph(_pattern[i])
		mark.add_theme_color_override("font_color", Color(1, 0.15, 0.15) if i == shown else Color(1, 0.55, 0.55))


func _paint_typed() -> void:
	for i in range(_arrows.size()):
		var mark := _arrows[i]
		if i >= _typed.size():
			mark.text = ""
			continue
		var good := _typed[i] == _pattern[i]
		mark.text = _glyph(_typed[i])
		mark.add_theme_color_override("font_color", Color(0.2, 0.85, 0.25) if good else Color(1, 0.2, 0.2))


func _glyph(dir: int) -> String:
	if dir == 0:
		return "^"
	if dir == 1:
		return "<"
	if dir == 2:
		return "v"
	return ">"
