extends Control

## GolfPage. Records lists the best score on each course and hole. Trophies
## lists the thirty GolfGlobals trophies and the three cups. A blank score
## is N/A, and a trophy that is not earned yet is ???.

const _RECORDS := preload("res://scenes/golf/golf_records.gd")
const _RULES := preload("res://scenes/golf/minigolf_rules.gd")
const _TAB := preload("res://assets/gui/shticker/fishing/page_tab.png")
const _SCROLL_UP := preload("res://assets/gui/friends/FndsLst_ScrollUp.png")
const _SCROLL_DOWN := preload("res://assets/gui/friends/FndsLst_ScrollDN.png")
const _SCROLL_HOVER := preload("res://assets/gui/friends/FndsLst_ScrollUp_Rllvr.png")

const _TITLES: PackedStringArray = ["Golfing Records", "Golfing Trophies"]
const _TAB_TEXT: PackedStringArray = ["Records", "Trophies"]
const _BROWN := Color(0.2, 0.1, 0.0)
const _COURSE := Color(0.85, 0.64, 0.13)
const _HOLE := Color(0.95, 0.95, 0.0)
const _SELECTED := Color(1.0, 0.98, 0.15)
const _METAL: Array[Color] = [
	Color(0.72, 0.45, 0.2),
	Color(0.78, 0.78, 0.82),
	Color(0.85, 0.64, 0.13),
]
const _VISIBLE := 12

var _mode := 0
var _scroll := 0
var _title: Label
var _detail: Label
var _tabs: Array[TextureButton] = []
var _tab_names: Array[Label] = []
var _rows: Array[Label] = []
var _scores: Array[Label] = []
var _trophies: Array[Button] = []
var _cups: Array[Button] = []
var _up: TextureButton
var _down: TextureButton


func _ready() -> void:
	name = "Golf"
	mouse_filter = MOUSE_FILTER_IGNORE
	_title = Label.new()
	_title.name = "Title"
	_title.text = _TITLES[0]
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_title)
	for index in _TAB_TEXT.size():
		var tab := TextureButton.new()
		tab.texture_normal = _TAB
		tab.ignore_texture_size = true
		tab.stretch_mode = TextureButton.STRETCH_SCALE
		tab.focus_mode = FOCUS_NONE
		tab.pressed.connect(_set_mode.bind(index))
		add_child(tab)
		_tabs.append(tab)
		var caption := Label.new()
		caption.text = _TAB_TEXT[index]
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(caption)
		_tab_names.append(caption)
	for index in _VISIBLE:
		var name_label := _line(HORIZONTAL_ALIGNMENT_LEFT)
		var score_label := _line(HORIZONTAL_ALIGNMENT_RIGHT)
		_rows.append(name_label)
		_scores.append(score_label)
	_up = _arrow(true)
	_down = _arrow(false)
	for index in 30:
		var button := _chip(index)
		_trophies.append(button)
	for index in 3:
		var cup := _chip(30 + index)
		cup.text = "???"
		_cups.append(cup)
	_detail = _line(HORIZONTAL_ALIGNMENT_CENTER)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_mode(0)


func layout(page_size: Vector2) -> void:
	var body_px := maxi(int(page_size.y * 0.034), 12)
	var tab_top := page_size.y * 0.1
	var tab_size := Vector2(page_size.x * 0.28, page_size.y * 0.075)
	for index in _tabs.size():
		var origin := Vector2(page_size.x * (0.08 + float(index) * 0.36), tab_top)
		_tabs[index].position = origin
		_tabs[index].size = tab_size
		_tab_names[index].position = origin
		_tab_names[index].size = tab_size
		ToonGui.style_label(_tab_names[index], _BROWN, body_px, Color(0, 0, 0, 0), 0)
	var top := tab_top + tab_size.y + page_size.y * 0.03
	var row_h := page_size.y * 0.055
	for index in _rows.size():
		var y := top + row_h * float(index)
		_rows[index].position = Vector2(page_size.x * 0.06, y)
		_rows[index].size = Vector2(page_size.x * 0.68, row_h)
		_scores[index].position = Vector2(page_size.x * 0.7, y)
		_scores[index].size = Vector2(page_size.x * 0.18, row_h)
		ToonGui.style_label(_rows[index], _HOLE, body_px, Color(0, 0, 0, 1), 1)
		ToonGui.style_label(_scores[index], Color(0, 0, 0), body_px, Color(0, 0, 0, 0), 0)
	var arrow := Vector2(page_size.x * 0.06, page_size.y * 0.06)
	_up.position = Vector2(page_size.x * 0.9, top)
	_down.position = Vector2(page_size.x * 0.9, top + row_h * float(_VISIBLE - 1))
	_up.size = arrow
	_down.size = arrow
	var cell := Vector2(page_size.x * 0.16, page_size.y * 0.09)
	for index in _trophies.size():
		var column := index % 5
		var row := int(float(index) / 5.0)
		var button := _trophies[index]
		button.position = Vector2(page_size.x * (0.06 + float(column) * 0.18), top + float(row) * cell.y)
		button.size = cell * Vector2(0.95, 0.85)
	for index in _cups.size():
		var button := _cups[index]
		button.position = Vector2(page_size.x * (0.18 + float(index) * 0.24), top + cell.y * 6.4)
		button.size = cell * Vector2(1.2, 1.0)
	_detail.position = Vector2(page_size.x * 0.06, page_size.y * 0.9)
	_detail.size = Vector2(page_size.x * 0.88, page_size.y * 0.08)
	ToonGui.style_label(_detail, Color(0, 0, 0.7), body_px, Color(0, 0, 0, 0), 0)
	_fill()


func refresh() -> void:
	_fill()


func _set_mode(mode: int) -> void:
	_mode = mode
	_title.text = _TITLES[mode]
	_scroll = 0
	_detail.text = ""
	for index in _tabs.size():
		_tabs[index].modulate = _SELECTED if index == mode else Color.WHITE
	var records := mode == 0
	for label in _rows:
		label.visible = records
	for label in _scores:
		label.visible = records
	_up.visible = records
	_down.visible = records
	for button in _trophies:
		button.visible = not records
	for button in _cups:
		button.visible = not records
	_fill()


func _fill() -> void:
	if _mode == 0:
		_fill_records()
	else:
		_fill_trophies()


func _fill_records() -> void:
	var courses := _RECORDS.course_best()
	var holes := _RECORDS.hole_best()
	var total := _RULES.COURSE_TITLES.size() + _RULES.HOLE_TITLES.size()
	_scroll = clampi(_scroll, 0, maxi(total - _VISIBLE, 0))
	for index in _VISIBLE:
		var which := _scroll + index
		if which >= total:
			_rows[index].text = ""
			_scores[index].text = ""
			continue
		if which < _RULES.COURSE_TITLES.size():
			_rows[index].text = _RULES.COURSE_TITLES[which]
			_rows[index].add_theme_color_override("font_color", _COURSE)
			_scores[index].text = str(courses[which]) if courses[which] != 0 else "N/A"
		else:
			var hole := which - _RULES.COURSE_TITLES.size()
			_rows[index].text = _RULES.HOLE_TITLES[hole]
			_rows[index].add_theme_color_override("font_color", _HOLE)
			_scores[index].text = str(holes[hole]) if holes[hole] != 0 else "N/A"


func _fill_trophies() -> void:
	var won := _RECORDS.trophies()
	for index in _trophies.size():
		var button := _trophies[index]
		var earned := index < won.size() and won[index] == 1
		button.text = "" if earned else "???"
		var metal := _METAL[index % 3]
		button.modulate = metal if earned else Color(0.8, 0.8, 0.8)
	var owned := _RECORDS.cups()
	for index in _cups.size():
		var earned := index < owned.size() and owned[index] == 1
		_cups[index].text = "Cup" if earned else "???"
		_cups[index].modulate = _METAL[index] if earned else Color(0.8, 0.8, 0.8)


func _show_trophy(index: int) -> void:
	var won := _RECORDS.trophies()
	if index < won.size() and won[index] == 1:
		_detail.text = _RECORDS.trophy_text(index)
	else:
		_detail.text = "???"


func _show_cup(index: int) -> void:
	var owned := _RECORDS.cups()
	var names: PackedStringArray = ["Bronze Cup", "Silver Cup", "Gold Cup"]
	if index < owned.size() and owned[index] == 1:
		_detail.text = names[index]
	else:
		_detail.text = "???"


func _scroll_by(step: int) -> void:
	_scroll += step
	_fill_records()


func _line(align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _chip(index: int) -> Button:
	var button := Button.new()
	button.focus_mode = FOCUS_NONE
	button.text = "???"
	button.pressed.connect(_pick_chip.bind(index))
	add_child(button)
	return button


func _pick_chip(index: int) -> void:
	if index < 30:
		_show_trophy(index)
	else:
		_show_cup(index - 30)


func _arrow(up: bool) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _SCROLL_UP if up else _SCROLL_DOWN
	button.texture_hover = _SCROLL_HOVER
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = FOCUS_NONE
	button.pressed.connect(_scroll_by.bind(-1 if up else 1))
	add_child(button)
	return button
