extends Control

## Pond bingo. Everyone at the pier shares one 5 by 5 card. The center is free.
## A catch marks one matching square. The card type sets the win and the jackpot.

signal marked
signal paid(amount: int)

const _ROLL := preload("res://scenes/fishing/fish_roll.gd")
const _TANK := preload("res://scenes/fishing/fish_tank.gd")
const _HOLIDAYS := preload("res://scenes/shticker/calendar_holidays.gd")
const _NET := preload("res://scenes/net/toon_net.gd")

const _NAMES: PackedStringArray = ["Classic", "Four Corners", "Diagonals", "Three Way", "BLOCKOUT!"]
const _HELP: PackedStringArray = [
	"Mark any row down, across or diagonally to win.",
	"Mark all four corners to win.",
	"Mark both of the diagonals to win.",
	"Mark both diagonals and the middle row to win.",
	"Mark the entire card to win.",
]
const _JACKPOT: Array[int] = [10, 20, 40, 80, 1000]
const _WAIT := 15
const _CYCLE := [155, 135, 195, 195, 105]
const _FREE := 12

const _FRAME: Array[Color] = [
	Color8(249, 193, 41),
	Color8(138, 241, 106),
	Color8(128, 108, 250),
	Color8(10, 118, 251),
	Color8(243, 84, 253),
]
const _BUTTON: Array[Color] = [
	Color8(106, 241, 233),
	Color8(246, 129, 220),
	Color8(248, 129, 56),
	Color8(252, 225, 97),
	Color8(97, 163, 253),
]

static var _saved: Dictionary = {}

var _zone := 0
var _key := ""
var _type := 0
var _phase := ""
var _left := 0
var _mask := 0
var _cells: Array = []
var _pending := {}
var _called := false
var _paid := false
var _shared_mask := -1
var _shared_called := false
var _shared_key := ""
var _blink := 0.0
var _buttons: Array[Button] = []
var _panel: PanelContainer
var _title: Label
var _timer: Label
var _prize: Label
var _help: Label
var _status: Label
var _bingo: Button
var _grid: GridContainer


func open(zone: int) -> void:
	_zone = zone


func note_catch(genus: int, species: int) -> void:
	if not visible or _phase != "play" or _called:
		return
	_pending = {"genus": genus, "species": species, "boot": genus < 0}
	_paint()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	offset_left = -292.0
	offset_right = -12.0
	offset_top = -250.0
	offset_bottom = 250.0
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)
	_title = _label(22)
	_timer = _label(18)
	_prize = _label(16)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 3)
	_grid.add_theme_constant_override("v_separation", 3)
	box.add_child(_title)
	box.add_child(_timer)
	box.add_child(_prize)
	box.add_child(_grid)
	for index in 25:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.clip_text = true
		button.custom_minimum_size = Vector2(50, 36)
		button.pressed.connect(_press_cell.bind(index))
		_grid.add_child(button)
		_buttons.append(button)
	_help = _label(12)
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status = _label(18)
	_bingo = Button.new()
	_bingo.text = "BINGO!"
	_bingo.focus_mode = Control.FOCUS_NONE
	_bingo.custom_minimum_size = Vector2(0, 36)
	_bingo.pressed.connect(_press_bingo)
	box.add_child(_help)
	box.add_child(_status)
	box.add_child(_bingo)
	visible = false


func _process(delta: float) -> void:
	_blink += delta
	if not _live():
		visible = false
		_pending = {}
		return
	visible = true
	var place := _place()
	var key := "%d:%d:%d" % [_zone, int(place["hour"]), int(place["index"])]
	if key != _key or String(place["phase"]) != _phase:
		_key = key
		_phase = String(place["phase"])
		_type = int(place["type"])
		_pending = {}
		if _phase == "play":
			_deal()
		_paint()
	_left = int(place["left"])
	_adopt()
	_timer.text = _clock_line()
	_paint()


func _live() -> bool:
	if _HOLIDAYS.running(7):
		return true
	return int(Time.get_datetime_dict_from_system().get("weekday", 0)) == 3


func _place() -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	var hour := int(now / 3600)
	var second := now % 3600
	if second >= 55 * 60:
		return {"phase": "break", "left": 3600 - second, "type": 0, "index": -1, "hour": hour}
	var cursor := second
	var index := 0
	while true:
		var type := index % 5
		var span: int = _CYCLE[type]
		if cursor < span:
			var wait_left := _WAIT - cursor
			if wait_left > 0:
				return {"phase": "wait", "left": wait_left, "type": type, "index": index, "hour": hour}
			return {"phase": "play", "left": span - cursor, "type": type, "index": index, "hour": hour}
		cursor -= span
		index += 1
		if index > 40:
			return {"phase": "break", "left": 1, "type": 0, "index": -1, "hour": hour}
	return {"phase": "break", "left": 1, "type": 0, "index": -1, "hour": hour}


func _deal() -> void:
	var rng := RandomNumberGenerator.new()
	var parts := _key.split(":")
	var seed := int(parts[0]) * 17 + int(parts[1]) * 1000003 + int(parts[2]) * 97
	rng.seed = seed
	var fish: Array = _ROLL.genera(_zone)
	var empty := 24 - fish.size()
	var rod := 0
	for _fill in maxi(empty, 0):
		var caught: Array = _ROLL.seeded_fish(_zone, rod, rng)
		if caught.is_empty() and not fish.is_empty():
			caught = (fish[0] as Array).duplicate()
		if not caught.is_empty():
			fish.append(caught)
		rod = (rod + 1) % 5
	_cells = []
	for index in 25:
		if index == _FREE:
			_cells.append({"free": true, "genus": -1})
		elif fish.is_empty():
			_cells.append({"free": false, "genus": 0, "species": 0})
		else:
			var choice := rng.randi() % fish.size()
			var row: Array = fish[choice]
			fish.remove_at(choice)
			_cells.append({"free": false, "genus": int(row[0]), "species": int(row[1])})
	var kept: Dictionary = _saved.get(_key, {})
	_mask = int(kept.get("mask", 1 << _FREE)) | (1 << _FREE)
	_called = bool(kept.get("called", false))
	_paid = bool(kept.get("paid", false))


func _adopt() -> void:
	if _phase != "play" or _key == "":
		return
	var state: Dictionary = _NET.latest("bingo:" + _key)
	if not state.is_empty():
		_mask = _mask | int(state.get("mask", 0))
		if bool(state.get("called", false)):
			_called = true
	if _called:
		_pay()
	if not _NET.is_authority():
		return
	if _mask == _shared_mask and _called == _shared_called and _key == _shared_key:
		return
	_shared_mask = _mask
	_shared_called = _called
	_shared_key = _key
	_NET.publish("bingo:" + _key, {"mask": _mask, "called": _called})


func _press_cell(index: int) -> void:
	if _phase != "play" or _called or _pending.is_empty() or index == _FREE:
		return
	if (_mask & (1 << index)) != 0:
		return
	var cell: Dictionary = _cells[index]
	var boot := bool(_pending.get("boot", false))
	if not boot and int(cell.get("genus", -2)) != int(_pending.get("genus", -3)):
		return
	_mask |= 1 << index
	_pending = {}
	_save()
	marked.emit()
	_paint()


func _press_bingo() -> void:
	if _phase != "play" or _called or not _won():
		return
	_called = true
	_save()
	_pay()
	_paint()


func _pay() -> void:
	if _paid:
		return
	_paid = true
	_save()
	paid.emit(_JACKPOT[_type])


func _save() -> void:
	if _key == "":
		return
	_saved[_key] = {"mask": _mask, "called": _called, "paid": _paid}


func _won() -> bool:
	if _type == 1:
		return _marked(0) and _marked(4) and _marked(20) and _marked(24)
	if _type == 2:
		return _fdiag() and _bdiag()
	if _type == 3:
		return _row(2) and _fdiag() and _bdiag()
	if _type == 4:
		for row in 5:
			if not _row(row):
				return false
		return true
	for line in 5:
		if _row(line) or _col(line):
			return true
	return _fdiag() or _bdiag()


func _row(row: int) -> bool:
	for col in 5:
		if not _marked(row * 5 + col):
			return false
	return true


func _col(col: int) -> bool:
	for row in 5:
		if not _marked(row * 5 + col):
			return false
	return true


func _fdiag() -> bool:
	for step in 5:
		if not _marked(step * 6):
			return false
	return true


func _bdiag() -> bool:
	for step in 5:
		if not _marked(step * 4 + 4):
			return false
	return true


func _marked(index: int) -> bool:
	return (_mask & (1 << index)) != 0


func _on_pattern(index: int) -> bool:
	if _type == 1:
		return index == 0 or index == 4 or index == 20 or index == 24
	if _type == 2:
		return index % 6 == 0 or index % 4 == 0
	if _type == 3:
		return int(index / 5) == 2 or index % 6 == 0 or index % 4 == 0
	return true


func _clock_line() -> String:
	var minutes := int(_left / 60)
	var seconds := _left % 60
	var shown := "%d:%02d" % [minutes, seconds]
	if _phase == "break":
		return "Intermission\nEnds In: " + shown
	if _phase == "wait":
		return "Next Game\nStarts In: " + shown
	return shown


func _paint() -> void:
	var frame := _FRAME[_type]
	var button := _BUTTON[_type]
	var style := StyleBoxFlat.new()
	style.bg_color = frame
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	_title.text = _NAMES[_type]
	_prize.text = "Win %d jellybeans!" % _JACKPOT[_type]
	_help.text = _HELP[_type]
	var playing := _phase == "play"
	_grid.visible = playing
	_help.visible = playing
	_bingo.visible = playing
	if _called:
		_status.text = "VICTORY!!"
	elif playing and _won() and _type == 4:
		_status.text = "JACKPOT!"
	elif playing:
		_status.text = ""
	else:
		_status.text = ""
	_bingo.disabled = not playing or _called or not _won()
	_bingo.modulate = Color(1, 0.2, 0.2) if playing and _won() and not _called and int(_blink / 0.5) % 2 == 0 else button
	if not playing:
		return
	var flash := playing and not _pending.is_empty() and int(_blink / 0.5) % 2 == 0
	for index in _buttons.size():
		var cell: Dictionary = _cells[index] if index < _cells.size() else {}
		var square := _buttons[index]
		if bool(cell.get("free", false)):
			square.text = "FREE"
		else:
			square.text = _TANK.genus_name(int(int(cell.get("genus", 0)) / 2))
		var marked := _marked(index)
		square.disabled = marked or index == _FREE
		var tint := Color(1, 1, 1, 1) if _on_pattern(index) else Color(0.8, 0.8, 0.8, 1)
		if marked:
			tint = Color(0.55, 0.85, 0.55, 1)
		elif flash and _matches(cell):
			tint = Color(1, 0.25, 0.25, 1)
		square.modulate = tint


func _matches(cell: Dictionary) -> bool:
	if bool(cell.get("free", false)) or _pending.is_empty():
		return false
	if bool(_pending.get("boot", false)):
		return true
	return int(cell.get("genus", -2)) == int(_pending.get("genus", -3))


func _label(size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label
