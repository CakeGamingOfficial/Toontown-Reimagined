class_name SpeedChat
extends Control

## TTChatInputSpeedChat. The purple list is the original phrase tree.
## The corner buttons are ChtBx_ChtBtn, tinted the way ToontownChatManager does.

signal menu_opened
signal phrase_said(text: String)

const _UP := preload("res://assets/gui/speedchat/ChtBx_ChtBtn_UP.png")
const _DOWN := preload("res://assets/gui/speedchat/ChtBx_ChtBtn_DN.png")
const _HOVER := preload("res://assets/gui/speedchat/ChtBx_ChtBtn_RLVR.png")
const _ARROW := preload("res://assets/gui/speedchat/chatArrow.png")
const _EMOTE := preload("res://assets/gui/speedchat/emotionIcon.png")
const _MENU := "res://assets/gui/speedchat/menu.json"
const _CLICK := "res://assets/gui/speedchat/GUI_quicktalker.mp3"
const _FRAME := Color(220.0 / 255.0, 195.0 / 255.0, 229.0 / 255.0, 0.95)
const _HOVER_ROW := Color(0.53, 0.9, 0.53, 0.95)
const _ARROW_TINT := Color(0.5, 0.5, 1.0)
const _EMOTE_TINT := Color(0.2, 0.72, 0.32)
const _SPEED_AT := Vector2(-1.129, 0.928)
const _CHAT_AT := Vector2(-1.2647, 0.928)
const _POP_AT := Vector2(-0.3, -0.1)
const _HOME_SCALE := 1.179
const _POP_SCALE := 2.0
const _BTN := 0.15

var _tasks: ToonTasks
var _items: Array = []
var _speed_btn: TextureButton
var _chat_btn: TextureButton
var _blocker: ColorRect
var _panel: PanelContainer
var _subs: Array[Control] = []
var _open_sub: Control
var _click: AudioStreamPlayer
var _shown := false
var _chat_live := false
var _flying := false


func setup(tasks: ToonTasks) -> void:
	_tasks = tasks
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	_load_menu()
	_click = AudioStreamPlayer.new()
	_click.name = "SpeedChatClick"
	var sound := load(_CLICK) as AudioStream
	if sound != null:
		_click.stream = sound
		_click.volume_db = linear_to_db(0.6)
	add_child(_click)
	_blocker = ColorRect.new()
	_blocker.color = Color(0, 0, 0, 0)
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.visible = false
	_blocker.gui_input.connect(_close_from_outside)
	add_child(_blocker)
	_speed_btn = _make_button(Color(0.75, 1.0, 0.6))
	_speed_btn.pressed.connect(_press_speed)
	add_child(_speed_btn)
	_chat_btn = _make_button(Color(1, 1, 1))
	_chat_btn.pressed.connect(_press_chat)
	add_child(_chat_btn)
	_apply_unlock()


func is_open() -> bool:
	return _blocker != null and _blocker.visible


func speed_center() -> Vector2:
	if _speed_btn == null:
		return Vector2.ZERO
	return _speed_btn.get_global_rect().get_center()


func set_chat_live(live: bool) -> void:
	_chat_live = live


func present_speed_button() -> void:
	_shown = true
	_flying = true
	_speed_btn.visible = true
	_speed_btn.modulate.a = 0.0
	_put(_speed_btn, _POP_AT.x, _POP_AT.y, _POP_SCALE)
	var fade := create_tween()
	fade.tween_method(_fade_speed, 0.0, 1.0, 0.5)
	await fade.finished
	await get_tree().create_timer(0.5).timeout
	var fly := create_tween()
	fly.set_trans(Tween.TRANS_SINE)
	fly.set_ease(Tween.EASE_IN_OUT)
	fly.tween_method(_fly_speed, 0.0, 1.0, 0.6)
	await fly.finished
	_flying = false
	_layout_buttons()


func present_chat_button() -> void:
	_flying = true
	_chat_btn.visible = true
	_chat_btn.modulate.a = 0.0
	_put(_chat_btn, _POP_AT.x, _POP_AT.y, _POP_SCALE)
	var fade := create_tween()
	fade.tween_method(_fade_chat, 0.0, 1.0, 0.5)
	await fade.finished
	await get_tree().create_timer(0.5).timeout
	var fly := create_tween()
	fly.set_trans(Tween.TRANS_SINE)
	fly.set_ease(Tween.EASE_IN_OUT)
	fly.tween_method(_fly_chat, 0.0, 1.0, 0.6)
	await fly.finished
	_flying = false
	_layout_buttons()


func _process(_delta: float) -> void:
	if _flying or _speed_btn == null:
		return
	_layout_buttons()
	if _open_sub != null and is_instance_valid(_open_sub):
		_fit(_open_sub)


func _apply_unlock() -> void:
	var unlocked := _tasks != null and _tasks.met_flippy
	_shown = unlocked
	_chat_live = unlocked
	_speed_btn.visible = unlocked
	_chat_btn.visible = unlocked
	_layout_buttons()


func _press_speed() -> void:
	if _click.stream != null:
		_click.play()
	if is_open():
		_close_menu()
		return
	_open_menu()


func _press_chat() -> void:
	if not _chat_live:
		return
	_close_menu()
	var host := get_parent().get_parent()
	if host != null and host.has_method("show_notice"):
		host.call("show_notice", "SpeedChat+ is where you type to other Toons.\nYou can try that later.")


func _open_menu() -> void:
	_close_menu()
	_blocker.visible = true
	_panel = _column(_items)
	add_child(_panel)
	_panel.z_index = 40
	var top := _aspect_point(-1.02, 0.78)
	_panel.position = top
	_fit(_panel)
	menu_opened.emit()


func _close_menu() -> void:
	_open_sub = null
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	for sub in _subs:
		if is_instance_valid(sub):
			sub.queue_free()
	_subs.clear()
	if _blocker != null:
		_blocker.visible = false


func _close_from_outside(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_close_menu()


func _column(items: Array) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := StyleBoxFlat.new()
	box.bg_color = _FRAME
	box.set_corner_radius_all(6)
	box.set_content_margin_all(4)
	box.set_border_width_all(2)
	box.border_color = Color(0.45, 0.28, 0.62, 0.85)
	panel.add_theme_stylebox_override("panel", box)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	panel.add_child(rows)
	for entry in items:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = entry
		if String(item.get("dynamic", "")) == "tasks":
			_add_task_rows(rows)
			continue
		if item.has("items"):
			_add_holder(rows, item)
		elif item.has("text"):
			_add_phrase(rows, item)
	return panel


func _add_task_rows(rows: VBoxContainer) -> void:
	var lines := PackedStringArray()
	if _tasks != null:
		lines = _tasks.task_lines()
	if lines.is_empty():
		return
	var holder := {"title": "MY TASKS", "items": []}
	var nested: Array = []
	for line in lines:
		nested.append({"text": line, "say": line})
	holder["items"] = nested
	_add_holder(rows, holder)


func _add_holder(rows: VBoxContainer, item: Dictionary) -> void:
	var nested: Array = item.get("items", [])
	var button := _row(String(item.get("title", "")), true, -1)
	var submenu := _column(nested)
	submenu.visible = false
	submenu.z_index = 50
	button.set_meta("submenu", submenu)
	button.mouse_entered.connect(_hover_holder.bind(button))
	rows.add_child(button)
	_subs.append(submenu)
	add_child(submenu)


func _add_phrase(rows: VBoxContainer, item: Dictionary) -> void:
	var emote := int(item.get("emote", -1))
	var button := _row(String(item.get("text", "")), false, emote)
	var spoken := String(item.get("say", item.get("text", "")))
	button.pressed.connect(_choose.bind(spoken))
	rows.add_child(button)


func _row(text: String, holder: bool, emote: int) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var font := ToonGui.font()
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0, 0, 0))
	button.add_theme_color_override("font_hover_color", Color(0, 0, 0))
	button.add_theme_color_override("font_pressed_color", Color(0, 0, 0))
	button.add_theme_color_override("font_focus_color", Color(0, 0, 0))
	var plain := StyleBoxFlat.new()
	plain.bg_color = Color(0, 0, 0, 0)
	plain.content_margin_left = 8
	plain.content_margin_right = 22
	plain.content_margin_top = 2
	plain.content_margin_bottom = 2
	var hot := plain.duplicate() as StyleBoxFlat
	hot.bg_color = _HOVER_ROW
	button.add_theme_stylebox_override("normal", plain)
	button.add_theme_stylebox_override("hover", hot)
	button.add_theme_stylebox_override("pressed", hot)
	button.add_theme_stylebox_override("focus", plain)
	var width := 80.0
	if font != null:
		width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 28.0
	button.custom_minimum_size = Vector2(maxf(width, 120.0), 26.0)
	if holder:
		var arrow := TextureRect.new()
		arrow.texture = _ARROW
		arrow.modulate = _ARROW_TINT
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		arrow.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		arrow.offset_left = -18
		arrow.offset_right = -4
		arrow.offset_top = -8
		arrow.offset_bottom = 8
		button.add_child(arrow)
	elif emote >= 0:
		var icon := TextureRect.new()
		icon.texture = _EMOTE
		icon.modulate = _EMOTE_TINT
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		icon.offset_left = -20
		icon.offset_right = -4
		icon.offset_top = -7
		icon.offset_bottom = 7
		button.add_child(icon)
	return button


func _hover_holder(button: Button) -> void:
	if _open_sub != null and is_instance_valid(_open_sub):
		_open_sub.visible = false
	var submenu := button.get_meta("submenu") as Control
	if submenu == null:
		_open_sub = null
		return
	submenu.visible = true
	submenu.global_position = button.global_position + Vector2(button.size.x - 8.0, 0.0)
	_open_sub = submenu
	_fit(submenu)


func _choose(raw: String) -> void:
	_close_menu()
	phrase_said.emit(_named(raw))


func _named(raw: String) -> String:
	if not raw.contains("%s"):
		return raw
	var who := "Toon"
	var style := ToonRoster.selected_style()
	if style != null:
		who = style.display_name()
	return raw.replace("%s", who)


func _fit(panel: Control) -> void:
	if panel == null:
		return
	panel.reset_size()
	var view := get_viewport().get_visible_rect().size
	if panel.global_position.y + panel.size.y > view.y - 12.0:
		panel.global_position.y = maxf(8.0, view.y - 12.0 - panel.size.y)
	if panel.global_position.x + panel.size.x > view.x - 8.0:
		panel.global_position.x = maxf(8.0, view.x - 8.0 - panel.size.x)


func _layout_buttons() -> void:
	if _flying:
		return
	if _speed_btn != null and _speed_btn.visible:
		_put(_speed_btn, _SPEED_AT.x, _SPEED_AT.y, _HOME_SCALE)
	if _chat_btn != null and _chat_btn.visible:
		_put(_chat_btn, _CHAT_AT.x, _CHAT_AT.y, _HOME_SCALE)


func _fade_speed(alpha: float) -> void:
	_speed_btn.modulate.a = alpha


func _fade_chat(alpha: float) -> void:
	_chat_btn.modulate.a = alpha


func _fly_speed(t: float) -> void:
	var at := _POP_AT.lerp(_SPEED_AT, t)
	var scale := lerpf(_POP_SCALE, _HOME_SCALE, t)
	_put(_speed_btn, at.x, at.y, scale)


func _fly_chat(t: float) -> void:
	var at := _POP_AT.lerp(_CHAT_AT, t)
	var scale := lerpf(_POP_SCALE, _HOME_SCALE, t)
	_put(_chat_btn, at.x, at.y, scale)


func _put(button: TextureButton, x: float, z: float, scale: float) -> void:
	var view := get_viewport().get_visible_rect().size
	var unit := view.y * 0.5
	var box := _BTN * (scale / _HOME_SCALE) * unit
	var center := Vector2(view.x * 0.5 + x * unit, view.y * 0.5 - z * unit)
	button.size = Vector2(box, box)
	button.position = center - button.size * 0.5


func _aspect_point(x: float, z: float) -> Vector2:
	var view := get_viewport().get_visible_rect().size
	var unit := view.y * 0.5
	return Vector2(view.x * 0.5 + x * unit, view.y * 0.5 - z * unit)


func _make_button(tint: Color) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _UP
	button.texture_pressed = _DOWN
	button.texture_hover = _HOVER
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.modulate = tint
	button.visible = false
	button.z_index = 30
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _load_menu() -> void:
	_items = []
	if not FileAccess.file_exists(_MENU):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_MENU))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var root: Dictionary = parsed
	var items: Variant = root.get("items", [])
	if typeof(items) == TYPE_ARRAY:
		_items = items as Array
