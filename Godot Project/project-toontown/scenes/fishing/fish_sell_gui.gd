extends Control

## FishSellGUI. The cream dialog lists the bucket, the first fish opens in the
## side panel, and Sell All is FishGuiOk. The fisherman's AI closes it after
## 30 seconds.

signal finished(reason: String)

const _TANK := preload("res://scenes/fishing/fish_tank.gd")
const _DIALOG := preload("res://assets/gui/tutorial/dialog/dialog_box.png")
const _BUCKET := preload("res://assets/gui/shticker/fishing/bucket.png")
const _OK_UP := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_UP.png")
const _OK_DOWN := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_DN.png")
const _OK_HOVER := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_Rllvr.png")
const _CLOSE_UP := preload("res://assets/toons/gui/CloseBtn_UP.png")
const _CLOSE_DOWN := preload("res://assets/toons/gui/CloseBtn_DN.png")
const _CLOSE_HOVER := preload("res://assets/toons/gui/CloseBtn_Rllvr.png")
const _SCROLL_UP := preload("res://assets/gui/friends/FndsLst_ScrollUp.png")
const _SCROLL_DOWN := preload("res://assets/gui/friends/FndsLst_ScrollDN.png")
const _SCROLL_HOVER := preload("res://assets/gui/friends/FndsLst_ScrollUp_Rllvr.png")
const _CREAM := Color(1, 1, 0.75, 1)
const _INK := Color(0, 0, 0, 1)
const _HOVER := Color(0.5, 0.9, 1, 1)
const _PICKED := Color(1, 1, 0, 1)
const _VISIBLE := 10
const _SECONDS := 30.0

var toon_name := "Toon"
var _rows: Array = []
var _first := 0
var _picked := 0
var _left := _SECONDS
var _closed := false
var _title: Label
var _names: Array[Button] = []
var _up: TextureButton
var _down: TextureButton
var _info: Label
var _panel: Control
var _panel_name: Label
var _panel_weight: Label
var _panel_value: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rows = _TANK.fish()
	_build()
	var view := get_viewport()
	if not view.size_changed.is_connected(_layout):
		view.size_changed.connect(_layout)
	_layout()
	_show_picked()


func _process(delta: float) -> void:
	if _closed:
		return
	_left -= delta
	if _left <= 0.0:
		_finish("timeout")


func _build() -> void:
	var root := Control.new()
	root.name = "Sheet"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var frame := TextureRect.new()
	frame.name = "Dialog"
	frame.texture = _DIALOG
	frame.modulate = _CREAM
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_title)
	var bucket := TextureRect.new()
	bucket.name = "Bucket"
	bucket.texture = _BUCKET
	bucket.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bucket.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bucket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bucket)
	for _index in _VISIBLE:
		var row := Button.new()
		row.focus_mode = Control.FOCUS_NONE
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var empty := StyleBoxEmpty.new()
		row.add_theme_stylebox_override("normal", empty)
		row.add_theme_stylebox_override("hover", empty)
		row.add_theme_stylebox_override("pressed", empty)
		row.add_theme_stylebox_override("focus", empty)
		row.pressed.connect(_pick.bind(_names.size()))
		row.mouse_entered.connect(_tint.bind(row, true))
		row.mouse_exited.connect(_tint.bind(row, false))
		root.add_child(row)
		_names.append(row)
	_up = _arrow(false)
	_down = _arrow(true)
	root.add_child(_up)
	root.add_child(_down)
	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_info)
	_panel = _detail(root)
	_text_button(root, "Cancel", _CLOSE_UP, _CLOSE_DOWN, _CLOSE_HOVER, "cancel")
	_text_button(root, "Sell All", _OK_UP, _OK_DOWN, _OK_HOVER, "sold")


func _detail(root: Control) -> Control:
	var panel := Control.new()
	panel.name = "FishPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var card := TextureRect.new()
	card.texture = _DIALOG
	card.modulate = _CREAM
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(card)
	_panel_name = _panel_label(panel)
	_panel_weight = _panel_label(panel)
	_panel_value = _panel_label(panel)
	var close := TextureButton.new()
	close.texture_normal = _CLOSE_UP
	close.texture_pressed = _CLOSE_DOWN
	close.texture_hover = _CLOSE_HOVER
	close.ignore_texture_size = true
	close.stretch_mode = TextureButton.STRETCH_SCALE
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: panel.visible = false)
	ToonGui.button_sounds(close)
	panel.add_child(close)
	close.set_meta("corner", true)
	return panel


func _panel_label(panel: Control) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return label


func _arrow(down: bool) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _SCROLL_DOWN if down else _SCROLL_UP
	button.texture_hover = _SCROLL_HOVER
	button.texture_pressed = _SCROLL_DOWN if down else _SCROLL_UP
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_scroll.bind(1 if down else -1))
	ToonGui.button_sounds(button)
	return button


func _text_button(root: Control, caption: String, up: Texture2D, down: Texture2D, hover: Texture2D, reason: String) -> void:
	var button := TextureButton.new()
	button.name = caption
	button.texture_normal = up
	button.texture_pressed = down
	button.texture_hover = hover
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_finish.bind(reason))
	ToonGui.button_sounds(button)
	root.add_child(button)
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	label.set_meta("for", caption)


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.y < 1.0:
		return
	var root := get_node("Sheet") as Control
	var px := maxi(int(round(0.045 * view.y * 0.5)), 12)
	ToonGui.place(root.get_node("Dialog"), view, 0.0, 0.0, 2.0, 1.5)
	_title.text = "Hi, %s! You have %d fish in your bucket worth a total of %d jellybeans. Do you want to sell them all?" % [toon_name, _rows.size(), _TANK.value()]
	ToonGui.style_label(_title, _INK, px, Color(0, 0, 0, 0), 0)
	ToonGui.place(_title, view, 0.0, 0.58, 1.7, 0.22)
	ToonGui.place(root.get_node("Bucket"), view, -0.15, -0.02, 0.72, 0.9)
	var row_h := 0.08
	var top := 0.42
	for index in _names.size():
		ToonGui.place(_names[index], view, -0.62, top - float(index) * row_h, 0.7, row_h)
		_names[index].add_theme_font_override("font", ToonGui.font())
		_names[index].add_theme_font_size_override("font_size", px)
	ToonGui.place(_up, view, -0.22, 0.42, 0.1, 0.1)
	ToonGui.place(_down, view, -0.22, -0.38, 0.1, 0.1)
	_info.text = "Bucket: %d / %d\nValue: %d jellybeans" % [_rows.size(), _TANK.max_count(), _TANK.value()]
	ToonGui.style_label(_info, _INK, px, Color(0, 0, 0, 0), 0)
	ToonGui.place(_info, view, -0.55, -0.52, 0.7, 0.16)
	ToonGui.place(_panel, view, 0.55, 0.08, 0.65, 0.85)
	_place_panel(px)
	ToonGui.place(root.get_node("Cancel"), view, 0.3, -0.58, 0.16, 0.16)
	ToonGui.place(root.get_node("Sell All"), view, 0.6, -0.58, 0.16, 0.16)
	for child in root.get_children():
		if child is Label and child.has_meta("for"):
			var caption := String(child.get_meta("for"))
			var x := 0.3 if caption == "Cancel" else 0.6
			ToonGui.style_label(child, _INK, maxi(px - 2, 11), Color(0, 0, 0, 0), 0)
			ToonGui.place(child, view, x, -0.7, 0.28, 0.08)
	_fill()


func _place_panel(px: int) -> void:
	var box := _panel.size
	_panel_name.position = Vector2(box.x * 0.08, box.y * 0.08)
	_panel_name.size = Vector2(box.x * 0.84, box.y * 0.28)
	_panel_weight.position = Vector2(box.x * 0.08, box.y * 0.48)
	_panel_weight.size = Vector2(box.x * 0.84, box.y * 0.12)
	_panel_value.position = Vector2(box.x * 0.08, box.y * 0.6)
	_panel_value.size = Vector2(box.x * 0.84, box.y * 0.12)
	ToonGui.style_label(_panel_name, _INK, px, Color(0, 0, 0, 0), 0)
	ToonGui.style_label(_panel_weight, _INK, maxi(px - 2, 11), Color(0, 0, 0, 0), 0)
	ToonGui.style_label(_panel_value, _INK, maxi(px - 2, 11), Color(0, 0, 0, 0), 0)
	for child in _panel.get_children():
		if child is TextureButton:
			child.position = Vector2(box.x * 0.72, box.y * 0.78)
			child.size = Vector2(box.x * 0.18, box.y * 0.14)


func _fill() -> void:
	var last := maxi(_rows.size() - _VISIBLE, 0)
	_first = clampi(_first, 0, last)
	for index in _names.size():
		var row := _names[index]
		var source := _first + index
		row.visible = source < _rows.size()
		if source < _rows.size():
			row.text = String((_rows[source] as Dictionary).get("name", ""))
		_tint(row, false)
	var idle := Color(0.7, 0.7, 0.7, 0.75)
	_up.modulate = idle if _first == 0 else Color.WHITE
	_up.disabled = _first == 0
	_down.modulate = idle if _first >= last else Color.WHITE
	_down.disabled = _first >= last


func _scroll(step: int) -> void:
	_first += step
	_fill()


func _pick(shown: int) -> void:
	var source := _first + shown
	if source < 0 or source >= _rows.size():
		return
	_picked = source
	_panel.visible = true
	_show_picked()
	_fill()


func _tint(row: Button, over: bool) -> void:
	var shown := _names.find(row)
	var source := _first + shown
	var color := _INK
	if source == _picked and source < _rows.size():
		color = _PICKED
	elif over:
		color = _HOVER
	row.add_theme_color_override("font_color", color)
	row.add_theme_color_override("font_hover_color", _HOVER if source != _picked else _PICKED)
	row.add_theme_color_override("font_pressed_color", _PICKED)


func _show_picked() -> void:
	if _rows.is_empty() or _picked < 0 or _picked >= _rows.size():
		_panel.visible = false
		return
	var row: Dictionary = _rows[_picked]
	_panel.visible = true
	_panel_name.text = String(row.get("name", ""))
	_panel_weight.text = _TANK.weight_line(int(row.get("weight", 0)))
	_panel_value.text = _TANK.value_line(int(row.get("value", 0)))


func _finish(reason: String) -> void:
	if _closed:
		return
	_closed = true
	finished.emit(reason)
	queue_free()
