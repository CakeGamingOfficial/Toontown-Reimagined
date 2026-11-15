extends Control

## Pond bingo. Everyone at the pier shares one 5 by 5 card. The center is free.
## A catch marks one matching square. The card type sets the win and the jackpot.

signal marked
signal paid(amount: int)

const _ROLL := preload("res://scenes/fishing/fish_roll.gd")
const _HOLIDAYS := preload("res://scenes/shticker/calendar_holidays.gd")
const _NET := preload("res://scenes/net/toon_net.gd")
const _CARD_ART := preload("res://assets/gui/fishing/bingo/g.png")
const _PLATE_UP := preload("res://assets/gui/fishing/bingo/Gold_TTButtUP.png")
const _PLATE_DOWN := preload("res://assets/gui/fishing/bingo/goldTTButtDown.png")
const _PLATE_OVER := preload("res://assets/gui/fishing/bingo/RolloverBingoButton1.png")
const _WORD_ART := preload("res://assets/gui/fishing/bingo/BINGObutton.png")
const _JACKPOT_ART := preload("res://assets/gui/fishing/bingo/jackpot.png")
const _STAMP := preload("res://assets/gui/fishing/bingo/mickeyButton.png")
const _CLOCK_ART := preload("res://assets/gui/purchase/alarm_clock.png")
# FishBingo.egg stamps. The genus numbers are BingoGlobals.FishButtonDict.
const _ICONS := {
	-1: preload("res://assets/gui/fishing/bingo/mickeyButton.png"),
	0: preload("res://assets/gui/fishing/bingo/BaloonFishButton.png"),
	2: preload("res://assets/gui/fishing/bingo/CatfishButton.png"),
	4: preload("res://assets/gui/fishing/bingo/ClownfishButton.png"),
	6: preload("res://assets/gui/fishing/bingo/FrozenfishButton.png"),
	8: preload("res://assets/gui/fishing/bingo/starfishButton.png"),
	10: preload("res://assets/gui/fishing/bingo/holyMackrelButton.png"),
	12: preload("res://assets/gui/fishing/bingo/DogfishButton.png"),
	14: preload("res://assets/gui/fishing/bingo/amoreEelButton.png"),
	16: preload("res://assets/gui/fishing/bingo/nursesharkButton.png"),
	18: preload("res://assets/gui/fishing/bingo/kingcrabButton.png"),
	20: preload("res://assets/gui/fishing/bingo/moonfishButton.png"),
	22: preload("res://assets/gui/fishing/bingo/pPlane21.png"),
	24: preload("res://assets/gui/fishing/bingo/poolsharkButton.png"),
	26: preload("res://assets/gui/fishing/bingo/BearacudaButton.png"),
	28: preload("res://assets/gui/fishing/bingo/troutButton.png"),
	30: preload("res://assets/gui/fishing/bingo/pianotunaButton.png"),
	32: preload("res://assets/gui/fishing/bingo/PBJfishButton.png"),
	34: preload("res://assets/gui/fishing/bingo/DevilrayButton.png"),
}

const _NAMES: PackedStringArray = ["Classic", "Four Corners", "Diagonals", "Three Way", "BLOCKOUT!"]
const _HELP: PackedStringArray = [
	"This is a Classic Bingo card.  Mark any row down, across or diagonally to win.",
	"An easy Corners card.  Mark all four corners to win.",
	"Mark both of the diagonals to win.",
	"Three-way.  Mark both diagonals and the middle row to win.  This one isn't easy!",
	"Blockout!.  Mark the entire card to win.  You are competing against all the other ponds for a huge jackpot!",
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
var _fish: Array = []
var _pending := {}
var _called := false
var _paid := false
var _shared_mask := -1
var _shared_called := false
var _shared_key := ""
var _blink := 0.0
var _card: TextureRect
var _cells: Array[TextureButton] = []
var _plate: TextureButton
var _word: TextureRect
var _clock: TextureRect
var _timer: Label
var _title: Label
var _prize: Label
var _help: Label
var _status: Label
var _next: Label
var _jackpot: TextureRect
var _lights: Array[TextureRect] = []
var _light_on: Array[Texture2D] = []
var _light_off: Array[Texture2D] = []
# LightOn bulbs, model (x, y) centers. The sign is scaled by 0.035 on the card.
var _bulbs: PackedFloat32Array = PackedFloat32Array([
	-1.316, 23.263, -0.350, 22.984, 0.679, 22.595, 1.624, 22.233,
	2.514, 21.830, 3.348, 21.357, 4.224, 20.732, 4.905, 19.995,
	5.197, 18.994, 4.919, 17.965, 4.266, 17.256, 3.432, 16.713,
	2.542, 16.227, 1.555, 15.865, 0.581, 15.545, -0.392, 15.254,
	-1.298, 14.920, -2.285, 15.254, -3.259, 15.545, -4.232, 15.865,
	-5.219, 16.227, -6.109, 16.713, -6.943, 17.256, -7.596, 17.965,
	-7.875, 18.994, -7.583, 19.995, -6.901, 20.732, -6.025, 21.357,
	-5.191, 21.830, -4.301, 22.233, -3.356, 22.595, -2.327, 22.984,
])


func open(zone: int) -> void:
	_zone = zone


func note_catch(genus: int, species: int) -> void:
	if not visible or _phase != "play" or _called:
		return
	_pending = {"genus": genus, "species": species, "boot": genus < 0}
	_paint()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = _picture(_CARD_ART)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	for cell_index in 25:
		var square := TextureButton.new()
		square.focus_mode = Control.FOCUS_NONE
		square.ignore_texture_size = true
		square.stretch_mode = TextureButton.STRETCH_SCALE
		square.texture_normal = _STAMP
		square.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		square.pressed.connect(_press_cell.bind(cell_index))
		add_child(square)
		_cells.append(square)
	_plate = TextureButton.new()
	_plate.focus_mode = Control.FOCUS_NONE
	_plate.ignore_texture_size = true
	_plate.stretch_mode = TextureButton.STRETCH_SCALE
	_plate.texture_normal = _PLATE_UP
	_plate.texture_pressed = _PLATE_DOWN
	_plate.texture_hover = _PLATE_OVER
	_plate.texture_disabled = _PLATE_UP
	_plate.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_plate.pressed.connect(_press_bingo)
	add_child(_plate)
	_word = _picture(_WORD_ART)
	_clock = _picture(_CLOCK_ART)
	_timer = _caption(false)
	_title = _caption(true)
	_title.mouse_filter = Control.MOUSE_FILTER_STOP
	_title.mouse_entered.connect(_show_help)
	_title.mouse_exited.connect(_hide_help)
	_prize = _caption(false)
	_help = _caption(true)
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.visible = false
	_status = _caption(true)
	_next = _caption(true)
	_jackpot = _picture(_JACKPOT_ART)
	_jackpot.visible = false
	for bulb in 32:
		var number := bulb + 1
		var on_tex: Texture2D = load("res://assets/gui/fishing/bingo/LightOn_%03d.png" % number) as Texture2D
		var off_tex: Texture2D = load("res://assets/gui/fishing/bingo/LightOff_%03d.png" % number) as Texture2D
		_light_on.append(on_tex)
		_light_off.append(off_tex)
		var light := _picture(off_tex)
		light.visible = false
		_lights.append(light)
	visible = false


func _show_help() -> void:
	_help.visible = true


func _hide_help() -> void:
	_help.visible = false


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
	_fish = []
	for index in 25:
		if index == _FREE:
			_fish.append({"free": true, "genus": -1})
		elif fish.is_empty():
			_fish.append({"free": false, "genus": 0, "species": 0})
		else:
			var choice := rng.randi() % fish.size()
			var row: Array = fish[choice]
			fish.remove_at(choice)
			_fish.append({"free": false, "genus": int(row[0]), "species": int(row[1])})
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
	var cell: Dictionary = _fish[index]
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


func _time_text() -> String:
	var minutes := int(_left / 60)
	var seconds := _left % 60
	return "%d:%02d" % [minutes, seconds]


func _paint() -> void:
	_layout()
	var frame: Color = _FRAME[_type]
	var button: Color = _BUTTON[_type]
	_card.modulate = frame
	_title.text = _NAMES[_type]
	_help.text = _HELP[_type]
	var playing := _phase == "play"
	_prize.visible = playing
	_prize.text = "Win %d jellybeans!" % _JACKPOT[_type]
	_plate.visible = playing
	_word.visible = playing
	_clock.visible = playing
	_timer.visible = playing
	_timer.text = _time_text()
	for square in _cells:
		square.visible = playing
	_next.visible = not playing
	if _phase == "break":
		_next.text = "Intermission\nEnds In:\n" + _time_text()
	elif _phase == "wait":
		_next.text = "Next Game\nStarts In:\n" + _time_text()
	var show_win := playing and _called
	_status.visible = show_win
	_status.text = "VICTORY!!" if show_win else ""
	var ready := playing and _won() and not _called
	_plate.disabled = not ready
	var plate := button
	if ready and int(_blink / 0.5) % 2 == 0:
		plate = Color(1, 1, 1, 1) if _type == 2 else Color(1, 0, 0, 1)
	_plate.modulate = plate
	var show_jackpot := ready and _type == 4
	_jackpot.visible = show_jackpot
	var bulb_on := int(_blink / 0.2) % 2 == 0
	for bulb in _lights.size():
		var light := _lights[bulb]
		light.visible = show_jackpot
		if not show_jackpot:
			continue
		var lit := (bulb % 2 == 0) == bulb_on
		var bulb_art: Texture2D = _light_off[bulb]
		if lit:
			bulb_art = _light_on[bulb]
		light.texture = bulb_art
	if not playing:
		return
	var flash := not _pending.is_empty() and int(_blink / 0.5) % 2 == 0
	for cell_index in _cells.size():
		var spot: Dictionary = {}
		if cell_index < _fish.size():
			spot = _fish[cell_index] as Dictionary
		var square := _cells[cell_index]
		var marked := _marked(cell_index) or bool(spot.get("free", false))
		var genus := int(spot.get("genus", -1))
		var art: Texture2D = _STAMP
		if not marked and _ICONS.has(genus):
			art = _ICONS[genus] as Texture2D
		square.texture_normal = art
		square.texture_pressed = art
		square.texture_hover = art
		square.texture_disabled = art
		square.disabled = marked or not _matches(spot)
		var tint := Color(1, 1, 1, 1) if _on_pattern(cell_index) else Color(0.8, 0.8, 0.8, 1)
		if flash and _matches(spot):
			tint = Color(1, 0, 0, 1)
		square.modulate = tint


func _matches(cell: Dictionary) -> bool:
	if bool(cell.get("free", false)) or _pending.is_empty():
		return false
	if bool(_pending.get("boot", false)):
		return true
	return int(cell.get("genus", -2)) == int(_pending.get("genus", -3))


func _picture(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _caption(sign: bool) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if sign:
		ToonGui.style_sign(label, Color(1, 1, 1), 16, Color(0, 0, 0), 1)
	else:
		ToonGui.style_label(label, Color(1, 1, 1), 16, Color(0, 0, 0), 1)
	add_child(label)
	return label


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.y < 2.0:
		return
	position = Vector2.ZERO
	size = view
	# BingoCardGui sits at (0.75, -0.65). The card image is g, scaled by 0.035.
	ToonGui.place(_card, view, 0.75, -0.6283, 0.6896, 0.7591)
	for cell_index in _cells.size():
		var col := cell_index % 5
		var row := int(cell_index / 5.0)
		var x := 0.75 + 0.088 * float(col - 2) - 0.052
		var z := -0.65 + 0.088 * float(row - 2) - 0.015
		ToonGui.place(_cells[cell_index], view, x, z, 0.088, 0.088)
	ToonGui.place(_plate, view, 0.698, -0.345, 0.432, 0.0922)
	ToonGui.place(_word, view, 0.698, -0.345, 0.3853, 0.0734)
	var clock_at := Vector2(0.99, -0.83)
	var clock_size := Vector2(0.7417 * 0.17, 0.7292 * 0.17)
	ToonGui.place(_clock, view, clock_at.x, clock_at.y, clock_size.x, clock_size.y)
	var face_x := clock_at.x + (28.5 / 61.0 - 0.5) * clock_size.x
	var face_z := clock_at.y - (33.5 / 61.0 - 0.5) * clock_size.y
	var px := maxi(int(round(0.18 * 0.17 * view.y * 0.5)), 8)
	ToonGui.style_label(_timer, Color(0, 0, 0), px, Color(0, 0, 0, 0), 0)
	ToonGui.place(_timer, view, face_x, face_z, clock_size.x * 0.7, clock_size.y * 0.45)
	_style_at(_title, view, 0.698, -0.94, 0.55, 0.045, true)
	_style_at(_prize, view, 0.698, -0.43, 0.7, 0.04, false)
	_style_at(_status, view, 0.698, -0.65, 0.7, 0.06, true)
	_style_at(_next, view, 0.698, -0.51, 0.7, 0.05, true)
	ToonGui.place(_next, view, 0.698, -0.51, 0.7, 0.16)
	_next.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_at(_help, view, 0.2, -0.55, 0.9, 0.045, true)
	ToonGui.place(_help, view, 0.2, -0.55, 0.9, 0.28)
	_help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ToonGui.place(_jackpot, view, 0.7015, -0.0671, 0.499, 0.499)
	for bulb in _lights.size():
		var bx := _bulbs[bulb * 2]
		var by := _bulbs[bulb * 2 + 1]
		ToonGui.place(_lights[bulb], view, 0.75 + bx * 0.035, -0.65 + by * 0.035, 0.035, 0.035)


func _style_at(label: Label, view: Vector2, x: float, z: float, width: float, text_scale: float, sign: bool) -> void:
	var px := maxi(int(round(text_scale * view.y * 0.5)), 8)
	if sign:
		ToonGui.style_sign(label, Color(1, 1, 1), px, Color(0, 0, 0), maxi(int(round(float(px) * 0.12)), 1))
	else:
		ToonGui.style_label(label, Color(1, 1, 1), px, Color(0, 0, 0), maxi(int(round(float(px) * 0.12)), 1))
	ToonGui.place(label, view, x, z, width, text_scale * 2.2)
