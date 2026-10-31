class_name RewardPanel
extends Control

## RewardPanel. The cream card is dialog_box_gui tinted GlobalDialogColor.
## Track bars sit on gagExpFrame, and the skip control is the battle_gui
## skip-section card. One aspect unit is half the viewport height.

const _DIALOG := preload("res://assets/gui/tutorial/dialog/dialog_box.png")
const _OK_UP := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_UP.png")
const _OK_DOWN := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_DN.png")
const _OK_HOVER := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_Rllvr.png")
const _SKIP_UP := preload("res://assets/gui/battle/tt_t_gui_gen_skipSectionUp.png")
const _SKIP_DOWN := preload("res://assets/gui/battle/tt_t_gui_gen_skipSectionDown.png")
const _SKIP_OVER := preload("res://assets/gui/battle/tt_t_gui_gen_skipSectionRollOver.png")
const _SKIP_OFF := preload("res://assets/gui/battle/tt_t_gui_gen_skipSectionDisabled.png")

# dialog_box_gui tight bounds, then RewardPanel geom_scale (1.75, 1, 0.825)
# and geom_pos (0, 0, -0.05) under the panel at z 0.587.
const _CARD_W := 1.1122
const _CARD_H := 1.1861
const _CARD_CX := -0.02113
const _CARD_CZ := -0.03873
const _GEOM_X := 1.75
const _GEOM_Z := 0.825
const _PANEL_Z := 0.587
const _DIALOG_AT := Vector2(_CARD_CX * _GEOM_X, _PANEL_Z - 0.05 + _CARD_CZ * _GEOM_Z)
const _DIALOG_SIZE := Vector2(_CARD_W * _GEOM_X, _CARD_H * _GEOM_Z)
# gagExpFrame is (-0.32, 0.24) on the panel. Bars are scale 0.25 of a 2 x 0.3 frame.
const _FRAME_X := -0.32
const _FRAME_Z := 0.827
const _BAR_AT := Vector2(_FRAME_X + 0.4, 0.0)
const _BAR_SIZE := Vector2(0.5, 0.075)
const _ROW := 0.09
# Skip card is ±0.1333, scaled by 0.39, at (0.815, -0.395) on the panel.
const _SKIP_AT := Vector2(0.815, _PANEL_Z - 0.395)
const _SKIP_SIZE := Vector2(0.2666 * 0.39, 0.2666 * 0.39)
const _CREAM := Color(1.0, 1.0, 0.75, 1.0)
const _INK := Color(0.0, 0.0, 0.0, 1.0)
const _DONE := Color(0.0, 0.3, 0.0, 1.0)

var _loadout: ToonLoadout
var _before: Dictionary = {}
var _earned: Dictionary = {}
var _skip := false
var _ack_done := false
var _dialog: TextureRect
var _name: Label
var _quest_title: Label
var _quest_line: Label
var _frames: Array[ColorRect] = []
var _fills: Array[ColorRect] = []
var _amounts: Array[Label] = []
var _tracks: Array[Label] = []
var _plus: Array[Label] = []
var _skip_button: TextureButton
var _skip_caption: Label
var _ack: TextureRect
var _ack_text: Label
var _ok: TextureButton
var _ok_caption: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	var view := get_viewport()
	if not view.size_changed.is_connected(_layout):
		view.size_changed.connect(_layout)
	_layout()
	visible = false


func present(toon_name: String, loadout: ToonLoadout, before: Dictionary, earned: Dictionary, quest_line: String, no_skip: bool) -> void:
	_loadout = loadout
	_before = before
	_earned = earned
	_skip = false
	_name.text = toon_name
	_skip_button.disabled = no_skip
	_show_bars()
	visible = true
	_layout()
	for track in ToonLoadout.TRACK_COUNT:
		if int(_earned.get(track, 0)) <= 0:
			continue
		await _tick(track)
		if _skip:
			break
		var amount := int(_earned[track])
		var points := "point" if amount == 1 else "points"
		var goal := loadout.goal_for(track, int(_before.get(track, 0)) + amount)
		await _acknowledge("You received %d %s %s! When you get %d, you will get a new gag!" % [
			amount, ToonLoadout.TRACK_NAMES[track], points, goal,
		])
		if _skip:
			break
	if not _skip and not quest_line.is_empty():
		_show_quest(quest_line)
		await _wait(2.0)
	visible = false


func _tick(track: int) -> void:
	var start := int(_before.get(track, 0))
	var amount := int(_earned.get(track, 0))
	_plus[track].text = "+ %d" % amount
	_plus[track].visible = true
	var elapsed := 0.0
	while elapsed < 0.5:
		if _skip:
			elapsed = 0.5
		else:
			await get_tree().process_frame
			elapsed += get_process_delta_time()
		var shown := int(round(float(start) + clampf(elapsed / 0.5, 0.0, 1.0) * float(amount)))
		_paint(track, shown, true)
	_paint(track, start + amount, false)


func _acknowledge(text: String) -> void:
	_ack_done = false
	_ack_text.text = text
	_show_ack(true)
	_layout()
	while not _ack_done and not _skip:
		await get_tree().process_frame
	_show_ack(false)


func _show_ack(shown: bool) -> void:
	_ack.visible = shown
	_ack_text.visible = shown
	_ok.visible = shown
	_ok_caption.visible = shown


func _wait(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds and not _skip:
		await get_tree().process_frame
		elapsed += get_process_delta_time()


func _show_bars() -> void:
	_quest_title.visible = false
	_quest_line.visible = false
	for track in ToonLoadout.TRACK_COUNT:
		var open := _loadout != null and _loadout.track_open(track)
		_frames[track].visible = open
		_fills[track].visible = open
		_amounts[track].visible = open
		_tracks[track].visible = open
		_plus[track].visible = false
		if open:
			_paint(track, int(_before.get(track, _loadout.experience_of(track))), false)


func _show_quest(line: String) -> void:
	for track in ToonLoadout.TRACK_COUNT:
		_frames[track].visible = false
		_fills[track].visible = false
		_amounts[track].visible = false
		_tracks[track].visible = false
		_plus[track].visible = false
	_quest_title.visible = true
	_quest_line.text = line
	_quest_line.visible = true
	_layout()


func _paint(track: int, shown: int, hot: bool) -> void:
	var goal := 1
	if _loadout != null:
		goal = maxi(_loadout.goal_for(track, shown), 1)
	var color: Color = ToonLoadout.TRACK_COLORS[track]
	_frames[track].color = Color(color.r * 0.7, color.g * 0.7, color.b * 0.7)
	var ink := color if hot else Color(color.r * 0.8, color.g * 0.8, color.b * 0.8)
	_fills[track].color = ink
	var ratio := clampf(float(shown) / float(goal), 0.0, 1.0)
	var frame := _frames[track]
	var pad := Vector2(frame.size.x * 0.02, frame.size.y * 0.133)
	_fills[track].position = pad
	_fills[track].size = Vector2(maxf(frame.size.x - pad.x * 2.0, 0.0) * ratio, maxf(frame.size.y - pad.y * 2.0, 0.0))
	_amounts[track].text = "%d/%d" % [shown, goal]


func _build() -> void:
	_dialog = _picture(_DIALOG)
	_dialog.modulate = _CREAM
	_name = _ink_label(HORIZONTAL_ALIGNMENT_CENTER)
	_quest_title = _ink_label(HORIZONTAL_ALIGNMENT_CENTER)
	_quest_title.text = "ToonTasks"
	_quest_title.visible = false
	_quest_line = _ink_label(HORIZONTAL_ALIGNMENT_LEFT)
	_quest_line.add_theme_color_override("font_color", _DONE)
	_quest_line.visible = false
	for track in ToonLoadout.TRACK_COUNT:
		var frame := ColorRect.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.visible = false
		add_child(frame)
		var fill := ColorRect.new()
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(fill)
		var amount := _ink_label(HORIZONTAL_ALIGNMENT_CENTER)
		var title := _ink_label(HORIZONTAL_ALIGNMENT_RIGHT)
		title.text = ToonLoadout.TRACK_NAMES[track].to_upper()
		var plus := _ink_label(HORIZONTAL_ALIGNMENT_LEFT)
		plus.visible = false
		_frames.append(frame)
		_fills.append(fill)
		_amounts.append(amount)
		_tracks.append(title)
		_plus.append(plus)
	_skip_button = TextureButton.new()
	_skip_button.texture_normal = _SKIP_UP
	_skip_button.texture_pressed = _SKIP_DOWN
	_skip_button.texture_hover = _SKIP_OVER
	_skip_button.texture_disabled = _SKIP_OFF
	_skip_button.ignore_texture_size = true
	_skip_button.stretch_mode = TextureButton.STRETCH_SCALE
	_skip_button.focus_mode = Control.FOCUS_NONE
	_skip_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_skip_button.pressed.connect(_press_skip)
	ToonGui.button_sounds(_skip_button)
	add_child(_skip_button)
	_skip_caption = _ink_label(HORIZONTAL_ALIGNMENT_CENTER)
	_skip_caption.text = "Skip"
	_skip_caption.visible = false
	ToonGui.style_label(_skip_caption, Color(1, 1, 1), 16, _INK, 2)
	_skip_button.mouse_entered.connect(func() -> void:
		_skip_caption.visible = not _skip_button.disabled
	)
	_skip_button.mouse_exited.connect(func() -> void:
		_skip_caption.visible = false
	)
	_ack = _picture(_DIALOG)
	_ack.modulate = _CREAM
	_ack.mouse_filter = Control.MOUSE_FILTER_STOP
	_ack.visible = false
	_ack.z_index = 2
	_ack_text = _ink_label(HORIZONTAL_ALIGNMENT_CENTER)
	_ack_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ack_text.z_index = 3
	_ack_text.visible = false
	_ok = TextureButton.new()
	_ok.texture_normal = _OK_UP
	_ok.texture_pressed = _OK_DOWN
	_ok.texture_hover = _OK_HOVER
	_ok.ignore_texture_size = true
	_ok.stretch_mode = TextureButton.STRETCH_SCALE
	_ok.focus_mode = Control.FOCUS_NONE
	_ok.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_ok.z_index = 3
	_ok.visible = false
	_ok.pressed.connect(_press_ok)
	ToonGui.button_sounds(_ok)
	add_child(_ok)
	_ok_caption = _ink_label(HORIZONTAL_ALIGNMENT_CENTER)
	_ok_caption.text = "OK"
	_ok_caption.z_index = 3
	_ok_caption.visible = false


func _picture(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _ink_label(align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(label, _INK, 16, Color(0, 0, 0, 0), 0)
	add_child(label)
	return label


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.y < 2.0:
		return
	position = Vector2.ZERO
	size = view
	_put(_dialog, _DIALOG_AT, _DIALOG_SIZE)
	_style(_name, 0.0, _PANEL_Z + 0.3, 1.5, 0.08, HORIZONTAL_ALIGNMENT_CENTER)
	_style(_quest_title, 0.0, _PANEL_Z + 0.2, 1.2, 0.06, HORIZONTAL_ALIGNMENT_CENTER)
	_style(_quest_line, -0.1, _PANEL_Z - 0.1, 1.5, 0.05, HORIZONTAL_ALIGNMENT_LEFT)
	for track in ToonLoadout.TRACK_COUNT:
		var row_z := _FRAME_Z - _ROW * float(track)
		_put(_frames[track], Vector2(_BAR_AT.x, row_z), _BAR_SIZE)
		_style(_tracks[track], _FRAME_X - 0.08, row_z - 0.02, 0.42, 0.05, HORIZONTAL_ALIGNMENT_RIGHT)
		_style(_plus[track], _FRAME_X + 0.86, row_z - 0.02, 0.35, 0.05, HORIZONTAL_ALIGNMENT_LEFT)
		_style(_amounts[track], _BAR_AT.x, row_z, _BAR_SIZE.x, 0.045, HORIZONTAL_ALIGNMENT_CENTER)
		if _loadout != null and _frames[track].visible:
			_paint(track, _shown(track), false)
	_put(_skip_button, _SKIP_AT, _SKIP_SIZE)
	_style(_skip_caption, _SKIP_AT.x, _SKIP_AT.y - 0.109, 0.4, 0.078, HORIZONTAL_ALIGNMENT_CENTER)
	# Movie.playTutorialReward places the acknowledge dialog at (0.65, 0.5), scale 0.8.
	var ack_at := Vector2(0.65, 0.42)
	var ack_size := Vector2(_CARD_W * 0.8, _CARD_H * 0.62)
	_put(_ack, ack_at, ack_size)
	_style(_ack_text, ack_at.x, ack_at.y + 0.08, ack_size.x * 0.72, 0.056, HORIZONTAL_ALIGNMENT_CENTER)
	# Three wrapped lines. _style sizes a single line, so open the box back up.
	var text_box := Vector2(ack_size.x * 0.72, 0.22)
	ToonGui.place(_ack_text, size, ack_at.x, ack_at.y + 0.06, text_box.x, text_box.y)
	_ack_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ack_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_put(_ok, ack_at + Vector2(0.0, -0.16), Vector2(0.1, 0.1))
	_style(_ok_caption, ack_at.x, ack_at.y - 0.24, 0.3, 0.05, HORIZONTAL_ALIGNMENT_CENTER)


func _shown(track: int) -> int:
	if _plus[track].visible:
		return int(_before.get(track, 0)) + int(_earned.get(track, 0))
	return int(_before.get(track, _loadout.experience_of(track)))


func _style(label: Label, x: float, baseline: float, width: float, text_scale: float, align: HorizontalAlignment) -> void:
	var px := maxi(int(round(text_scale * size.y * 0.5)), 1)
	var color := _DONE if label == _quest_line else _INK
	if label == _skip_caption:
		ToonGui.style_label(label, Color(1, 1, 1), px, _INK, maxi(int(round(float(px) * 0.16)), 1))
	else:
		ToonGui.style_label(label, color, px, Color(0, 0, 0, 0), 0)
	label.horizontal_alignment = align
	ToonGui.place(label, size, x, baseline + text_scale * 0.35, width, text_scale * 1.45)


func _put(control: Control, center: Vector2, box: Vector2) -> void:
	ToonGui.place(control, size, center.x, center.y, box.x, box.y)


func _press_skip() -> void:
	_skip = true
	_ack_done = true


func _press_ok() -> void:
	_ack_done = true
