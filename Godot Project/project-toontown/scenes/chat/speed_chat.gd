class_name SpeedChat
extends Control

## SpeedChat++. The purple list is still TTChatInputSpeedChat.
## Once Flippy has taught it, the corner becomes the chat log from the later
## game: tabs, a history, and a line where you type. Phrases and typed lines
## both come out of the toon in a speech bubble.

signal menu_opened
signal phrase_said(text: String)

const _UP := preload("res://assets/gui/speedchat/ChtBx_ChtBtn_UP.png")
const _DOWN := preload("res://assets/gui/speedchat/ChtBx_ChtBtn_DN.png")
const _HOVER := preload("res://assets/gui/speedchat/ChtBx_ChtBtn_RLVR.png")
const _ARROW := preload("res://assets/gui/speedchat/chatArrow.png")
const _EMOTE := preload("res://assets/gui/speedchat/emotionIcon.png")
const _MENU := "res://assets/gui/speedchat/menu.json"
const _ChatSettings := preload("res://scenes/shticker/chat_settings.gd")
const _HOLIDAYS := preload("res://scenes/shticker/calendar_holidays.gd")
const _Style := preload("res://scenes/chat/speed_chat_style.gd")
const _KEYS := preload("res://scenes/shticker/keybinds.gd")
const _REWARDS := preload("res://scenes/cog_hq/boss_rewards.gd")
const _CLICK := "res://assets/gui/speedchat/GUI_quicktalker.mp3"
var _FRAME := Color(220.0 / 255.0, 195.0 / 255.0, 229.0 / 255.0, 0.95)
var _HOVER_ROW := Color(0.53, 0.9, 0.53, 0.95)
var _ARROW_TINT := Color(0.5, 0.5, 1.0)
var _EMOTE_TINT := Color(0.2, 0.72, 0.32)
const _POP_AT := Vector2(-0.3, -0.1)
const _HOME_SCALE := 1.179
const _POP_SCALE := 2.0
const _BTN := 0.15
## SpeedChat+ (white and blue) sits in the corner. SpeedChat (green) is beside it.
const _CORNER_PAD := 12.0
const _BUTTON_GAP := 8.0
## The phrase list sits under the whole chat window, not against its bottom edge.
const _MENU_GAP := 20.0
const _REOPEN_PAD := 4.0
const _BLUE := Color(0.4, 0.68, 1.0)
const _SAY_LIMIT := 120
const _HELP := "Welcome to SpeedChat++. Main shows the channels left on in the gear menu. Each other tab is one channel."
const _TAB_MAIN := 0
const _TAB_SYSTEM := 1
const _TAB_WHISPERS := 2
const _TAB_NPC := 3
const _TAB_GROUPS := 4
const _TAB_GUILD := 5
const _TAB_CONSOLE := 6
const _TAB_NAMES: PackedStringArray = ["Main", "System", "Whispers", "NPC", "Groups", "Guild", "Console"]
const _CREAM := Color(1.0, 0.97, 0.86, 0.98)
const _ORANGE := Color(0.9, 0.48, 0.1, 1.0)
const _INK := Color(0.22, 0.12, 0.06, 1.0)
const _RED := Color(0.86, 0.18, 0.14, 1.0)

var _tasks: ToonTasks
var _items: Array = []
var _speed_btn: TextureButton
var _chat_btn: TextureButton
var _reopen_btn: TextureButton
var _pin: Button
var _blocker: ColorRect
var _panel: PanelContainer
var _subs: Array[Control] = []
var _open_subs: Array[Control] = []
var phrase_is_speedchat := true
var said_trick := -1
var _click: AudioStreamPlayer
var _shown := false
var _chat_live := false
var _flying := false
var _plus_ready := false
var _pinned := false
## The panel is rebuilt in every area. The log lives in this file so a scene
## change cannot throw it away with the old panel.
const _LOG_PATH := "user://chat_log.json"

var _tab := 0
var _entries: Array[Dictionary] = []
var _channel_boxes := {}
var _restored := false
## A new play from the toon picker bumps this. Area changes keep the same number,
## so the log survives a tunnel and starts empty the next time you load in.
static var _generation := 0
static var _loaded_generation := -1
var _whisper_name := ""
var _whisper_slot := -1
var _whisper_av := 0
var _dock: PanelContainer
var _log: RichTextLabel
var _entry: LineEdit
var _phrase_slot: Control
var _tabs: Array[Button] = []
var _header: HBoxContainer
var _gear: Button
var _settings: PanelContainer
var _settings_open := false
var _alert_box: PanelContainer
var _alert_label: Label
var _alert_queue: PackedStringArray = PackedStringArray()
var _alert_left := 0.0


func setup(tasks: ToonTasks) -> void:
	_tasks = tasks
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	_load_menu()
	_click = ToonAudio.effect_player()
	_click.name = "SpeedChatClick"
	var sound := load(_CLICK) as AudioStream
	if sound != null:
		_click.stream = sound
		_click.volume_db = linear_to_db(0.6)
	add_child(_click)
	_blocker = ColorRect.new()
	_blocker.color = Color(0, 0, 0, 0)
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Visible while the phrase list is open, unless it is pinned. It must not
	# take the click: a gag button under the cursor still has to receive it.
	_blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blocker.visible = false
	add_child(_blocker)
	_speed_btn = _make_button(Color(0.75, 1.0, 0.6))
	_speed_btn.tooltip_text = "SpeedChat"
	_speed_btn.pressed.connect(_press_speed)
	add_child(_speed_btn)
	_chat_btn = _make_button(Color(1, 1, 1))
	_chat_btn.pressed.connect(_press_chat)
	add_child(_chat_btn)
	_reopen_btn = _make_button(_BLUE)
	_reopen_btn.tooltip_text = "SpeedChat++"
	_reopen_btn.pressed.connect(_press_reopen)
	_reopen_btn.visible = false
	add_child(_reopen_btn)
	_build_dock()
	_restore_log()
	_build_settings()
	_apply_unlock()
	_pull_whispers()
	var social := ToonSocial.live()
	if social != null and not social.heard.is_connected(_hear):
		social.heard.connect(_hear)
	var dev := get_node_or_null("/root/DevConsole")
	if dev != null and dev.has_signal("changed") and not dev.is_connected("changed", _on_console):
		dev.connect("changed", _on_console)


func is_open() -> bool:
	return _blocker != null and _blocker.visible


func speed_center() -> Vector2:
	if _speed_btn == null:
		return Vector2.ZERO
	return _speed_btn.get_global_rect().get_center()


func set_chat_live(live: bool) -> void:
	_chat_live = live
	if live:
		_plus_ready = true
		_show_dock()
		if _chat_btn != null:
			_chat_btn.visible = false


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


## Flippy hands over SpeedChat++. The green phrase button sits in the dock
## beside the line where you type, instead of the old pair of corner buttons.
func present_dock() -> void:
	_shown = true
	_chat_live = true
	_plus_ready = true
	_flying = true
	if _dock != null:
		_dock.modulate.a = 0.0
	_show_dock()
	_layout_dock()
	if _dock != null:
		var fade := create_tween()
		fade.tween_property(_dock, "modulate:a", 1.0, 0.45)
		await fade.finished
	_flying = false
	_layout_buttons()


func entry_center() -> Vector2:
	if _entry == null or not _entry.is_visible_in_tree():
		return speed_center()
	return _entry.get_global_rect().get_center()


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


func _process(delta: float) -> void:
	_poll_alerts(delta)
	if _flying or _speed_btn == null:
		return
	_layout_buttons()
	for sub in _open_subs:
		if is_instance_valid(sub) and sub.visible:
			_fit(sub)


func _apply_unlock() -> void:
	var unlocked := _tasks != null and _tasks.met_flippy
	_shown = unlocked
	_chat_live = unlocked
	_plus_ready = unlocked
	_speed_btn.visible = unlocked
	_chat_btn.visible = unlocked and not _plus_ready
	if _plus_ready and _pinned:
		_show_dock()
	elif _plus_ready:
		_hide_dock()
	elif _dock != null:
		_dock.visible = false
	_layout_buttons()


func _press_speed() -> void:
	if _click.stream != null:
		_click.play()
	if _plus_ready and (_dock == null or not _dock.visible):
		_show_dock()
		return
	if is_open():
		_close_menu()
		return
	_open_menu()


func _press_chat() -> void:
	if not _chat_live:
		return
	_close_menu()
	if _plus_ready:
		_focus_entry()
		return
	var host := get_parent().get_parent()
	if host != null and host.has_method("show_notice"):
		host.call("show_notice", "SpeedChat+ is where you type to other Toons.\nYou can try that later.")


func _open_menu() -> void:
	_close_menu()
	_blocker.visible = not _pinned
	var shown := _items.duplicate()
	var unite := _unite_menu()
	if shown.is_empty():
		shown.append(unite)
	else:
		shown.insert(1, unite)
	_panel = _column(shown)
	add_child(_panel)
	_panel.z_index = 40
	_place_phrase_menu()
	menu_opened.emit()


func _close_menu() -> void:
	_open_subs.clear()
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	for sub in _subs:
		if is_instance_valid(sub):
			sub.queue_free()
	_subs.clear()
	if _blocker != null:
		_blocker.visible = false


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
	submenu.set_meta("parent_menu", rows.get_parent())
	button.mouse_entered.connect(_hover_holder.bind(button))
	rows.add_child(button)
	_subs.append(submenu)
	add_child(submenu)


func _add_phrase(rows: VBoxContainer, item: Dictionary) -> void:
	var emote := int(item.get("emote", -1))
	var button := _row(String(item.get("text", "")), false, emote)
	if item.has("unite_menu"):
		button.pressed.connect(_choose_unite.bind(int(item.get("unite_menu", 0)), int(item.get("unite_item", 0))))
	else:
		var spoken := String(item.get("say", item.get("text", "")))
		button.pressed.connect(_choose.bind(spoken, int(item.get("trick", -1)), emote))
	button.mouse_entered.connect(_hover_line.bind(button))
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
	var parent_menu := button.get_parent().get_parent() as Control
	_keep_menu_chain(parent_menu)
	var submenu := button.get_meta("submenu") as Control
	if submenu == null:
		return
	submenu.visible = true
	submenu.z_index = 50 + _open_subs.size()
	submenu.global_position = button.global_position + Vector2(button.size.x - 8.0, 0.0)
	if not _open_subs.has(submenu):
		_open_subs.append(submenu)
	_fit(submenu)


func _hover_line(button: Button) -> void:
	_keep_menu_chain(button.get_parent().get_parent() as Control)


func _keep_menu_chain(menu: Control) -> void:
	var keep := {}
	var cursor := menu
	while cursor != null and is_instance_valid(cursor):
		keep[cursor.get_instance_id()] = true
		if not cursor.has_meta("parent_menu"):
			break
		cursor = cursor.get_meta("parent_menu") as Control
	var still: Array[Control] = []
	for sub in _open_subs:
		if not is_instance_valid(sub):
			continue
		if keep.has(sub.get_instance_id()):
			still.append(sub)
		else:
			sub.visible = false
	_open_subs = still


func _unite_menu() -> Dictionary:
	var toonup: Array = []
	var gags: Array = []
	var beans: Array = []
	for group in _REWARDS.unite_groups():
		if not (group is Dictionary):
			continue
		var row := {
			"text": "%s (%d)" % [String(group.get("label", "")), int(group.get("charges", 0))],
			"unite_menu": int(group.get("menu", 0)),
			"unite_item": int(group.get("item", 0)),
		}
		var menu := int(group.get("menu", 0))
		if menu == 0:
			toonup.append(row)
		elif menu == 1:
			beans.append(row)
		else:
			gags.append(row)
	return {
		"title": "UNITE!",
		"items": [
			{"title": "Toon-up", "items": toonup},
			{"title": "Gag-up", "items": gags},
			{"title": "jellybeans", "items": beans},
		],
	}


func _choose_unite(menu: int, item: int) -> void:
	# Resistance phrases are not whisperable.
	if _whisper_name != "":
		return
	var spoken := String(_REWARDS.speak_unite(menu, item))
	if spoken == "":
		return
	if not _pinned:
		_close_menu()
	_remember(spoken)
	phrase_is_speedchat = true
	phrase_said.emit(spoken)
	_publish(spoken, true, -1)
	if _pinned:
		_open_menu()


func _choose(raw: String, trick: int = -1, emote: int = -1) -> void:
	if not _pinned:
		_close_menu()
	var spoken := _named(raw)
	said_trick = trick
	if _whisper_name != "":
		_send_whisper(spoken, true)
		return
	_remember(spoken)
	phrase_is_speedchat = true
	phrase_said.emit(spoken)
	if emote >= 0:
		_play_emote(emote)
	_publish(spoken, true, emote)


func _named(raw: String) -> String:
	if not raw.contains("%s"):
		return raw
	var who := "Toon"
	var style := ToonRoster.selected_style()
	if style != null:
		who = style.display_name()
	return raw.replace("%s", who)


func _place_phrase_menu() -> void:
	if _panel == null or not is_instance_valid(_panel):
		return
	if _dock != null and _dock.visible:
		var below := _dock.position.y + _dock.size.y + _MENU_GAP
		_panel.position = Vector2(_dock.position.x, below)
		_fit(_panel, below)
	else:
		_panel.position = _aspect_point(-1.02, 0.78)
		_fit(_panel)


func _fit(panel: Control, floor_y: float = -1.0) -> void:
	if panel == null:
		return
	panel.reset_size()
	var view := get_viewport().get_visible_rect().size
	@warning_ignore("shadowed_global_identifier")
	var floor := 8.0 if floor_y < 0.0 else floor_y
	if panel.global_position.y + panel.size.y > view.y - 12.0:
		panel.global_position.y = maxf(floor, view.y - 12.0 - panel.size.y)
	if floor_y >= 0.0 and panel.global_position.y < floor_y:
		panel.global_position.y = floor_y
	if panel.global_position.x + panel.size.x > view.x - 8.0:
		panel.global_position.x = maxf(8.0, view.x - 8.0 - panel.size.x)


func _layout_buttons() -> void:
	if _flying:
		return
	if _plus_ready:
		if _chat_btn != null:
			_chat_btn.visible = false
		var dock_open := _dock != null and _dock.visible
		if _reopen_btn != null:
			_reopen_btn.visible = not dock_open
			if not dock_open:
				_apply_rect(_reopen_btn, _reopen_rect())
		if dock_open:
			_layout_dock()
			return
		if _speed_btn != null:
			_speed_btn.visible = false
		return
	if _chat_btn != null and _chat_btn.visible:
		_apply_rect(_chat_btn, _home_rect(false))
	if _speed_btn != null and _speed_btn.visible and _speed_btn.get_parent() == self:
		_apply_rect(_speed_btn, _home_rect(true))


func _fade_speed(alpha: float) -> void:
	_speed_btn.modulate.a = alpha


func _fade_chat(alpha: float) -> void:
	_chat_btn.modulate.a = alpha


func _fly_speed(t: float) -> void:
	_glide(_speed_btn, _aspect_rect(_POP_AT.x, _POP_AT.y, _POP_SCALE), _home_rect(true), t)


func _fly_chat(t: float) -> void:
	_glide(_chat_btn, _aspect_rect(_POP_AT.x, _POP_AT.y, _POP_SCALE), _home_rect(false), t)


func _reopen_rect() -> Rect2:
	var box := _button_box()
	return Rect2(_REOPEN_PAD, _REOPEN_PAD, box, box)


func _press_reopen() -> void:
	if _click.stream != null:
		_click.play()
	_show_dock()


func _home_rect(speedchat: bool) -> Rect2:
	var box := _button_box()
	var x := _CORNER_PAD
	if speedchat:
		x += box + _BUTTON_GAP
	return Rect2(x, _CORNER_PAD, box, box)


func _button_box() -> float:
	return _BTN * get_viewport().get_visible_rect().size.y * 0.5


func _glide(button: TextureButton, start: Rect2, home: Rect2, weight: float) -> void:
	button.position = start.position.lerp(home.position, weight)
	button.size = start.size.lerp(home.size, weight)


func _apply_rect(button: TextureButton, rect: Rect2) -> void:
	button.position = rect.position
	button.size = rect.size


@warning_ignore("shadowed_variable_base_class")
func _put(button: TextureButton, x: float, z: float, scale: float) -> void:
	_apply_rect(button, _aspect_rect(x, z, scale))


@warning_ignore("shadowed_variable_base_class")
func _aspect_rect(x: float, z: float, scale: float) -> Rect2:
	var view := get_viewport().get_visible_rect().size
	var unit := view.y * 0.5
	var box := _BTN * (scale / _HOME_SCALE) * unit
	var center := Vector2(view.x * 0.5 + x * unit, view.y * 0.5 - z * unit)
	return Rect2(center - Vector2(box, box) * 0.5, Vector2(box, box))


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


func _unhandled_input(event: InputEvent) -> void:
	if _phrase_hotkey(event):
		return
	if not _plus_ready or _flying or _entry == null:
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var enter := key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.physical_keycode == KEY_ENTER
	if not enter or _entry.has_focus() or _typing_blocked():
		return
	_focus_entry()
	get_viewport().set_input_as_handled()


## Controls page. T opens and closes the phrase list. A closed SpeedChat++
## window comes up with that list, so the phrases sit under the chat.
func _phrase_hotkey(event: InputEvent) -> bool:
	if _flying or not _shown:
		return false
	if not _KEYS.event_is(event, "speedchat"):
		return false
	get_viewport().set_input_as_handled()
	if _panel != null and is_instance_valid(_panel):
		_close_menu()
	else:
		if _plus_ready:
			_show_dock()
		_open_menu()
	if _click != null and _click.stream != null:
		_click.play()
	return true


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		# The phrase list used to catch every click on a full-screen plate.
		# Close it and let the same click land on a gag button.
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT and is_open() and not _pinned and not _pointer_on_chat():
			_close_menu()
		if _entry == null or not _entry.has_focus():
			return
		if click.pressed and _click_leaves_chat(click):
			_entry.release_focus()
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode != KEY_ESCAPE and key.physical_keycode != KEY_ESCAPE:
		return
	if _entry != null and _entry.has_focus():
		_entry.release_focus()
		get_viewport().set_input_as_handled()
		return
	if _settings_open:
		_set_settings_open(false)
		get_viewport().set_input_as_handled()
		return
	if is_open():
		_close_menu()
		get_viewport().set_input_as_handled()


## A click on the street, the book, or the laff meter leaves the line. Clicks
## on the log and the phrase list stay in the chat.
func _click_leaves_chat(click: InputEventMouseButton) -> bool:
	if click.button_index != MOUSE_BUTTON_LEFT and click.button_index != MOUSE_BUTTON_RIGHT and click.button_index != MOUSE_BUTTON_MIDDLE:
		return false
	return not _pointer_on_chat()


func _pointer_on_chat() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null:
		return false
	if _chat_owns(hovered, _dock) or _chat_owns(hovered, _settings) or _chat_owns(hovered, _panel):
		return true
	for sub in _subs:
		if _chat_owns(hovered, sub):
			return true
	return _chat_owns(hovered, _speed_btn) or _chat_owns(hovered, _chat_btn) or _chat_owns(hovered, _reopen_btn)


func _chat_owns(control: Control, root: Control) -> bool:
	if root == null or not is_instance_valid(root) or not root.visible:
		return false
	return control == root or root.is_ancestor_of(control)


func _build_dock() -> void:
	_dock = PanelContainer.new()
	_dock.name = "SpeedChatPlusPlus"
	_dock.visible = false
	_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	_dock.z_index = 20
	_dock.tooltip_text = "SpeedChat++"
	var frame := StyleBoxFlat.new()
	frame.bg_color = _CREAM
	frame.border_color = _ORANGE
	frame.set_border_width_all(4)
	frame.set_corner_radius_all(14)
	frame.set_content_margin_all(8)
	_dock.add_theme_stylebox_override("panel", frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dock.add_child(column)
	column.add_child(_tab_row())
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_active = true
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.fit_content = false
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size = Vector2(0, 80)
	_log.add_theme_font_override("normal_font", ToonGui.font())
	_log.add_theme_font_size_override("normal_font_size", 16)
	_log.add_theme_color_override("default_color", _INK)
	column.add_child(_log)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	_phrase_slot = Control.new()
	_phrase_slot.custom_minimum_size = Vector2(36, 32)
	_phrase_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_phrase_slot)
	_entry = LineEdit.new()
	_entry.placeholder_text = "Press Enter to chat"
	_entry.max_length = _SAY_LIMIT
	_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry.custom_minimum_size = Vector2(80, 30)
	_entry.focus_entered.connect(_release_mouse)
	_entry.focus_exited.connect(_end_whisper)
	_entry.text_submitted.connect(_send_typed)
	_style_entry(_entry)
	row.add_child(_entry)
	var send := Button.new()
	send.text = ">"
	send.focus_mode = Control.FOCUS_NONE
	send.custom_minimum_size = Vector2(36, 30)
	send.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	send.pressed.connect(_send_from_button)
	_style_send(send)
	row.add_child(send)
	add_child(_dock)
	_refresh_log()


func _tab_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header = row
	for index in _TAB_NAMES.size():
		var tab := Button.new()
		tab.text = _TAB_NAMES[index]
		tab.focus_mode = Control.FOCUS_NONE
		tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tab.pressed.connect(_select_tab.bind(index))
		_style_tab(tab, index == _TAB_MAIN)
		_tabs.append(tab)
		row.add_child(tab)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_pin = Button.new()
	_pin.text = "Pin"
	_pin.focus_mode = Control.FOCUS_NONE
	_pin.custom_minimum_size = Vector2(36, 22)
	_pin.size_flags_horizontal = Control.SIZE_SHRINK_END
	_pin.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_pin.tooltip_text = "Keep SpeedChat open while you play"
	_pin.pressed.connect(_toggle_pin)
	_style_pin()
	row.add_child(_pin)
	_gear = Button.new()
	_gear.icon = _gear_icon()
	_gear.expand_icon = true
	_gear.focus_mode = Control.FOCUS_NONE
	_gear.custom_minimum_size = Vector2(22, 22)
	_gear.size_flags_horizontal = Control.SIZE_SHRINK_END
	_gear.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_gear.tooltip_text = "SpeedChat++ settings"
	_gear.pressed.connect(_toggle_settings)
	_style_gear()
	row.add_child(_gear)
	var close := Button.new()
	close.text = "x"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(22, 22)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.pressed.connect(_hide_dock)
	_style_close(close)
	row.add_child(close)
	return row


func _show_dock() -> void:
	if _dock == null:
		return
	_dock.visible = true
	if _reopen_btn != null:
		_reopen_btn.visible = false
	_dock_phrase_button()
	if not _flying:
		_layout_buttons()


func _hide_dock() -> void:
	_close_menu()
	_set_settings_open(false)
	if _dock != null:
		_dock.visible = false
	if _entry != null:
		_entry.release_focus()
	_undock_phrase_button()
	if _plus_ready and _speed_btn != null:
		_speed_btn.visible = false
	if _reopen_btn != null and _plus_ready:
		_reopen_btn.visible = true
	if not _flying:
		_layout_buttons()


func _toggle_pin() -> void:
	_pinned = not _pinned
	_style_pin()
	_keep_log()
	if _panel == null:
		return
	if _blocker != null:
		_blocker.visible = not _pinned


func _dock_phrase_button() -> void:
	if _phrase_slot == null or _speed_btn == null:
		return
	if _speed_btn.get_parent() != _phrase_slot:
		_speed_btn.reparent(_phrase_slot)
	_speed_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	_speed_btn.offset_left = 0
	_speed_btn.offset_top = 0
	_speed_btn.offset_right = 0
	_speed_btn.offset_bottom = 0
	_speed_btn.custom_minimum_size = Vector2(32, 32)
	_speed_btn.visible = true


func _undock_phrase_button() -> void:
	if _speed_btn == null or _speed_btn.get_parent() == self:
		return
	_speed_btn.reparent(self)
	_speed_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)


func _layout_dock() -> void:
	if _dock == null:
		return
	var view := get_viewport().get_visible_rect().size
	var header_w := 520.0
	if _header != null:
		header_w = maxf(_header.get_combined_minimum_size().x, header_w)
	var chrome := 16.0
	var frame := _dock.get_theme_stylebox("panel")
	if frame != null:
		chrome = frame.get_minimum_size().x
	# Wide enough for every tab, Pin, the gear, and Close, with no scroller.
	var width := header_w + chrome + 4.0
	var height := clampf(view.y * 0.32, 200.0, 300.0)
	_dock.position = Vector2(12, 12)
	_dock.size = Vector2(width, height)
	_dock.custom_minimum_size = _dock.size
	_place_phrase_menu()
	_place_settings()


func _select_tab(index: int) -> void:
	_tab = index
	for tab_index in _tabs.size():
		_style_tab(_tabs[tab_index], tab_index == _tab)
	_refresh_log()


func _focus_entry() -> void:
	if _entry == null:
		return
	_show_dock()
	_release_mouse()
	_entry.grab_focus()
	_entry.caret_column = _entry.text.length()


func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _send_from_button() -> void:
	if _entry == null:
		return
	_send_typed(_entry.text)


func _send_typed(text: String) -> void:
	var spoken := text.replace("\n", " ").replace("\r", " ").strip_edges()
	if spoken == "":
		if _entry != null:
			_entry.text = ""
		return
	if spoken.length() > _SAY_LIMIT:
		spoken = spoken.substr(0, _SAY_LIMIT)
	if _entry != null:
		_entry.text = ""
	if MagicWords.looks_like(spoken):
		var scene := get_tree().current_scene
		_log_magic(MagicWords.invoke(scene, spoken))
		if _click.stream != null:
			_click.play()
		return
	if _whisper_name != "":
		_send_whisper(spoken, false)
		return
	_remember(spoken)
	phrase_is_speedchat = false
	phrase_said.emit(spoken)
	_publish(spoken, false, -1)
	if _click.stream != null:
		_click.play()


func _remember(spoken: String) -> void:
	var color := _speaker_color().to_html(false)
	var line := "[color=#7a5a3a]%s[/color] [color=#%s]%s[/color]: %s" % [_clock(), color, _bb(_speaker_name()), _bb(spoken)]
	_append("player", line, _TAB_MAIN)


func _log_magic(reply: String) -> void:
	var line := "[color=#7a5a3a]%s[/color] [color=#6a3d8a]Magic:[/color] %s" % [_clock(), _bb(reply)]
	_append("magic", line, _TAB_MAIN)


func ready_to_type() -> bool:
	return _plus_ready and _entry != null


## ChatManager.whisperTo. The line reads "To Flippy" until the box loses focus.
func whisper_to(friend_name: String, slot: int, av: int = 0) -> void:
	_whisper_name = friend_name
	_whisper_slot = slot
	_whisper_av = av
	if not ready_to_type():
		return
	_show_dock()
	_entry.placeholder_text = "To %s" % friend_name
	_entry.grab_focus()
	_entry.caret_column = _entry.text.length()


func _end_whisper() -> void:
	if _whisper_name == "":
		return
	_whisper_name = ""
	_whisper_slot = -1
	_whisper_av = 0
	if _entry != null:
		_entry.placeholder_text = "Press Enter to chat"


func _send_whisper(spoken: String, speedchat: bool) -> void:
	if _whisper_av > 0 and ToonNet.networked():
		var social := ToonSocial.live()
		if social != null:
			social.whisper(_whisper_av, spoken, speedchat)
	else:
		FriendsBook.leave_whisper(_whisper_slot, _speaker_name(), spoken)
	_log_whisper("To %s:" % _whisper_name, spoken)
	if _click.stream != null:
		_click.play()


func _publish(spoken: String, speedchat: bool, emote: int = -1) -> void:
	var social := ToonSocial.live()
	if social != null:
		social.say(spoken, speedchat, emote)


func _play_emote(index: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var actor := _local_actor(tree.root)
	if actor != null and actor.has_method("play_emote"):
		actor.call("play_emote", index)


func _local_actor(node: Node) -> Node:
	if node is ToonActor and int(node.get_meta("av", 0)) == ToonRoster.avatar_id():
		return node
	for child in node.get_children():
		var found := _local_actor(child)
		if found != null:
			return found
	return null


func _hear(from_name: String, text: String, whisper: bool) -> void:
	if whisper:
		_log_whisper("%s whispers:" % from_name, text)
		return
	var line := "[color=#7a5a3a]%s[/color] [color=#3a5f9a]%s[/color]: %s" % [_clock(), _bb(from_name), _bb(text)]
	_append("player", line, _TAB_MAIN)


func _pull_whispers() -> void:
	for item in FriendsBook.take_incoming():
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var note: Dictionary = item
		var body := String(note.get("text", "")).strip_edges()
		if body == "":
			continue
		_log_whisper("%s whispers:" % String(note.get("from", "Toon")), body)


func _log_whisper(who: String, text: String) -> void:
	var line := "[color=#7a5a3a]%s[/color] [color=#3a5f9a]%s[/color] %s" % [_clock(), _bb(who), _bb(text)]
	_append("whisper", line, _TAB_WHISPERS)


func _log_key() -> String:
	var index := ToonRoster.selected_index()
	if index < 0:
		return "guest"
	return str(index)


## Pick a Toon calls this before Play. The next area starts with an empty log.
static func begin_session() -> void:
	_generation += 1


func _restore_log() -> void:
	var record := _stored_record()
	_pinned = bool(record.get("pinned", false))
	_ChatSettings.bind(_log_key())
	var fresh := _generation != _loaded_generation
	_loaded_generation = _generation
	_entries.clear()
	_tab = _TAB_MAIN
	if not fresh:
		_entries = _entries_from(record.get("entries", []))
		_tab = clampi(int(record.get("tab", _TAB_MAIN)), 0, _TAB_NAMES.size() - 1)
	_restored = true
	for tab_index in _tabs.size():
		_style_tab(_tabs[tab_index], tab_index == _tab)
	_style_pin()
	_refresh_log()


func _keep_log() -> void:
	# The dock paints once while this panel is still empty. Saving then would
	# replace the log the previous area just stored.
	if not _restored:
		return
	var saved := _read_logs()
	saved[_log_key()] = {
		"entries": _entries_of(),
		"tab": _tab,
		"pinned": _pinned,
		"channels": _ChatSettings.channels(),
	}
	_write_logs(saved)


func _stored_record() -> Dictionary:
	var found: Variant = _read_logs().get(_log_key(), {})
	if typeof(found) != TYPE_DICTIONARY:
		return {}
	return found


func _read_logs() -> Dictionary:
	if not FileAccess.file_exists(_LOG_PATH):
		return {}
	var file := FileAccess.open(_LOG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _write_logs(saved: Dictionary) -> void:
	var file := FileAccess.open(_LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(saved))


func _on_console() -> void:
	if _log == null:
		return
	if _tab == _TAB_CONSOLE or (_tab == _TAB_MAIN and _wants("console")):
		_refresh_log()


func _show_console() -> void:
	if _log == null:
		return
	var dev := get_node_or_null("/root/DevConsole")
	if dev == null or not dev.has_method("transcript"):
		_log.text = "[color=#8a7058]Console is not running.[/color]"
		return
	_log.text = str(dev.call("transcript"))


func _refresh_log() -> void:
	_keep_log()
	if _tab == _TAB_CONSOLE:
		_show_console()
		return
	if _log == null:
		return
	var channel := _tab_channel(_tab)
	var body := ""
	if _tab == _TAB_MAIN:
		body = "[color=#8a7058]%s[/color]" % _bb(_HELP)
	var count := 0
	for item in _entries:
		var row: Dictionary = item
		var kind := String(row.get("channel", ""))
		if _tab == _TAB_MAIN:
			if not _wants(kind):
				continue
		elif kind != channel:
			continue
		if body != "":
			body += "\n"
		body += String(row.get("text", ""))
		count += 1
	if _tab == _TAB_MAIN and _wants("console"):
		var dev := get_node_or_null("/root/DevConsole")
		if dev != null and dev.has_method("transcript"):
			var extra := str(dev.call("transcript"))
			if extra != "":
				if body != "":
					body += "\n"
				body += extra
				count += 1
	if count == 0:
		_log.text = "[color=#8a7058]%s[/color]" % _empty_line(_tab)
		return
	_log.text = body


func _clock() -> String:
	var now: Dictionary = ToonNet.clock()
	var hour := int(now.get("hour", 0))
	var minute := int(now.get("minute", 0))
	var shown := hour % 12
	if shown == 0:
		shown = 12
	return "%d:%02d" % [shown, minute]


func _speaker_name() -> String:
	var style := ToonRoster.selected_style()
	if style == null:
		return "Toon"
	return style.display_name()


func _speaker_color() -> Color:
	var style := ToonRoster.selected_style()
	var color := Color(0.12, 0.35, 0.75)
	if style != null:
		color = style.painted_color("head")
	if color.get_luminance() > 0.72:
		color = color.darkened(0.4)
	return color


func _bb(text: String) -> String:
	return text.replace("[", "[lb]")


func _typing_blocked() -> bool:
	if is_open():
		return true
	@warning_ignore("shadowed_variable_base_class")
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null and owner != _entry:
		return true
	var layer := get_parent()
	if layer == null:
		return false
	if layer.get_node_or_null("BankGui") != null:
		return true
	return false


func _style_entry(entry: LineEdit) -> void:
	var box := _cream_box(8)
	entry.add_theme_stylebox_override("normal", box)
	entry.add_theme_stylebox_override("focus", box)
	entry.add_theme_stylebox_override("read_only", box)
	entry.add_theme_font_override("font", ToonGui.font())
	entry.add_theme_font_size_override("font_size", 16)
	entry.add_theme_color_override("font_color", _INK)
	entry.add_theme_color_override("font_placeholder_color", Color(0.55, 0.45, 0.32))
	entry.add_theme_color_override("caret_color", _INK)


func _style_send(button: Button) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = _RED
	box.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_stylebox_override("focus", box)
	button.add_theme_font_override("font", ToonGui.font())
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _style_pin() -> void:
	if _pin == null:
		return
	var box := _header_button(_pinned)
	_pin.add_theme_stylebox_override("normal", box)
	_pin.add_theme_stylebox_override("hover", box)
	_pin.add_theme_stylebox_override("pressed", box)
	_pin.add_theme_stylebox_override("focus", box)
	_pin.add_theme_font_override("font", ToonGui.font())
	_pin.add_theme_font_size_override("font_size", 13)
	var ink := Color.WHITE if _pinned else _INK
	_pin.add_theme_color_override("font_color", ink)
	_pin.add_theme_color_override("font_hover_color", ink)
	_pin.add_theme_color_override("font_pressed_color", ink)


func _style_close(button: Button) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = _RED
	box.set_corner_radius_all(11)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_stylebox_override("focus", box)
	button.add_theme_font_override("font", ToonGui.font())
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _style_tab(button: Button, selected: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = _ORANGE if selected else _CREAM
	box.border_color = _ORANGE
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_stylebox_override("focus", box)
	button.add_theme_font_override("font", ToonGui.font())
	button.add_theme_font_size_override("font_size", 14)
	var ink := Color.WHITE if selected else _INK
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)


func _cream_box(radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 0.94, 1)
	box.border_color = _ORANGE
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 8
	box.content_margin_right = 8
	return box


func _append(channel: String, text: String, tab: int) -> void:
	_entries.append({"channel": channel, "text": text})
	while _entries.size() > 200:
		_entries.pop_front()
	if tab >= 0 and _tab != tab:
		_select_tab(tab)
		return
	_refresh_log()


func alert(text: String) -> void:
	_queue_alert(text)


## Holiday and invasion changes. The line stays in the System tab, and a
## Toon HQ box shows it without pulling the chat onto that tab.
func _poll_alerts(delta: float) -> void:
	if not _restored:
		return
	for line in _HOLIDAYS.take_alerts():
		_queue_alert(String(line))
	if _alert_box == null or not _alert_box.visible:
		return
	_alert_left -= delta
	_place_alert()
	if _alert_left > 0.0:
		return
	_present_alert()


func _queue_alert(text: String) -> void:
	var clean := text.replace("\n", " ").strip_edges()
	if clean == "":
		return
	var line := "[color=#7a5a3a]%s[/color] %s" % [_clock(), _bb(clean)]
	_append("system", line, -1)
	_alert_queue.append(clean)
	if _alert_box == null or not _alert_box.visible:
		_present_alert()


func _present_alert() -> void:
	if _alert_queue.is_empty():
		if _alert_box != null:
			_alert_box.visible = false
		return
	var text := _alert_queue[0]
	_alert_queue.remove_at(0)
	_ensure_alert()
	_alert_label.text = text
	_alert_box.visible = true
	_alert_left = 5.0
	_place_alert()


func _ensure_alert() -> void:
	if _alert_box != null:
		return
	_alert_box = PanelContainer.new()
	_alert_box.name = "SystemAlert"
	_alert_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alert_box.z_index = 40
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.98)
	box.border_color = Color(0.05, 0.05, 0.05)
	box.set_border_width_all(3)
	box.set_corner_radius_all(16)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	_alert_box.add_theme_stylebox_override("panel", box)
	_alert_label = Label.new()
	_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_alert_label.custom_minimum_size = Vector2(560, 0)
	_alert_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(_alert_label, Color(0.05, 0.05, 0.08), 22, Color(0, 0, 0, 0), 0)
	_alert_box.add_child(_alert_label)
	add_child(_alert_box)


func _place_alert() -> void:
	if _alert_box == null or not _alert_box.visible:
		return
	_alert_box.reset_size()
	var view := size
	if view.x < 32.0:
		view = get_viewport_rect().size
	_alert_box.position = Vector2(maxf((view.x - _alert_box.size.x) * 0.5, 8.0), 28.0)


## Boarding groups, guilds, and system notices can drop a line in later.
func post(channel: String, text: String) -> void:
	var clean := text.replace("\n", " ").strip_edges()
	if clean == "":
		return
	var line := "[color=#7a5a3a]%s[/color] %s" % [_clock(), _bb(clean)]
	_append(channel, line, _tab_index(channel))


## A line the local toon spoke, in the same shape as a typed chat line.
## The log stays on whatever tab is open. The Player channel still receives it.
func log_player_line(text: String) -> void:
	var clean := text.replace("\n", " ").strip_edges()
	if clean == "":
		return
	var color := _speaker_color().to_html(false)
	var line := "[color=#7a5a3a]%s[/color] [color=#%s]%s[/color]: %s" % [_clock(), color, _bb(_speaker_name()), _bb(clean)]
	_append("player", line, -1)


## NPC speech, including joke doors. Channel "npc" is the NPCs filter and the NPC tab.
func log_npc_line(speaker: String, text: String, ink: Color = Color(0.25, 0.28, 0.75)) -> void:
	var clean := text.replace("\n", " ").strip_edges()
	if clean == "" or speaker == "":
		return
	var line := "[color=#7a5a3a]%s[/color] [color=#%s]%s[/color]: %s" % [_clock(), ink.to_html(false), _bb(speaker), _bb(clean)]
	_append("npc", line, -1)


func _tab_index(channel: String) -> int:
	match channel:
		"system":
			return _TAB_SYSTEM
		"whisper":
			return _TAB_WHISPERS
		"npc":
			return _TAB_NPC
		"group":
			return _TAB_GROUPS
		"guild":
			return _TAB_GUILD
		"player", "cog", "magic":
			return _TAB_MAIN
		_:
			return -1


func _tab_channel(tab: int) -> String:
	match tab:
		_TAB_SYSTEM:
			return "system"
		_TAB_WHISPERS:
			return "whisper"
		_TAB_NPC:
			return "npc"
		_TAB_GROUPS:
			return "group"
		_TAB_GUILD:
			return "guild"
		_:
			return ""


func _empty_line(tab: int) -> String:
	match tab:
		_TAB_SYSTEM:
			return "No system alerts yet."
		_TAB_WHISPERS:
			return "No whispers yet."
		_TAB_NPC:
			return "No NPC chat yet."
		_TAB_GROUPS:
			return "No group chat yet."
		_TAB_GUILD:
			return "No guild chat yet."
		_:
			return "No chat yet."


func _wants(channel: String) -> bool:
	return _ChatSettings.enabled(channel)


func _entries_of() -> Array:
	var copy: Array = []
	for item in _entries:
		copy.append(item)
	return copy


func _entries_from(value: Variant) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	if value is Array:
		for item in value:
			if item is Dictionary:
				lines.append(item)
	return lines


func _toggle_settings() -> void:
	_set_settings_open(not _settings_open)


func _set_settings_open(open: bool) -> void:
	_settings_open = open
	if _settings != null:
		_settings.visible = open
	_style_gear()
	if open:
		_place_settings()


func _build_settings() -> void:
	_settings = PanelContainer.new()
	_settings.name = "SpeedChatSettings"
	_settings.visible = false
	_settings.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings.z_index = 21
	var frame := StyleBoxFlat.new()
	frame.bg_color = _CREAM
	frame.border_color = _ORANGE
	frame.set_border_width_all(4)
	frame.set_corner_radius_all(14)
	frame.set_content_margin_all(10)
	_settings.add_theme_stylebox_override("panel", frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_settings.add_child(column)
	var title := Label.new()
	title.text = "Main"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(title, _INK, 18, Color(0, 0, 0, 0), 0)
	column.add_child(title)
	var hint := Label.new()
	hint.text = "Channels shown in the Main tab."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(240, 0)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(hint, Color(0.35, 0.24, 0.14), 13, Color(0, 0, 0, 0), 0)
	column.add_child(hint)
	for row in _ChatSettings.rows():
		var id := String(row.get("id", ""))
		var box := CheckBox.new()
		box.text = String(row.get("label", id))
		box.focus_mode = Control.FOCUS_NONE
		box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		box.add_theme_font_override("font", ToonGui.font())
		box.add_theme_font_size_override("font_size", 14)
		box.add_theme_color_override("font_color", _INK)
		box.add_theme_color_override("font_hover_color", _INK)
		box.add_theme_color_override("font_pressed_color", _INK)
		box.set_pressed_no_signal(_ChatSettings.enabled(id))
		box.toggled.connect(_set_channel.bind(id))
		column.add_child(box)
		_channel_boxes[id] = box
	add_child(_settings)
	_ChatSettings.watch(_on_chat_settings)
	_apply_menu_colors()



func _apply_menu_colors() -> void:
	var fill := _Style.frame(_ChatSettings.speed_color())
	fill.a = 0.95
	_FRAME = fill
	_HOVER_ROW = _Style.rollover(_ChatSettings.speed_color())
	_ARROW_TINT = _Style.arrow(_ChatSettings.speed_color())
	_EMOTE_TINT = _Style.emote(_ChatSettings.speed_color())
	_tint_menu(_panel)
	for sub in _subs:
		_tint_menu(sub)


func _tint_menu(panel: Control) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var box := panel.get_theme_stylebox("panel")
	if box is StyleBoxFlat:
		var next := (box as StyleBoxFlat).duplicate() as StyleBoxFlat
		next.bg_color = _FRAME
		next.border_color = Color(_ARROW_TINT.r, _ARROW_TINT.g, _ARROW_TINT.b, 0.85)
		panel.add_theme_stylebox_override("panel", next)
	if panel.get_child_count() == 0:
		return
	var rows := panel.get_child(0)
	for node in rows.get_children():
		if not (node is Button):
			continue
		var button := node as Button
		var hot := button.get_theme_stylebox("hover")
		if hot is StyleBoxFlat:
			var copy := (hot as StyleBoxFlat).duplicate() as StyleBoxFlat
			copy.bg_color = _HOVER_ROW
			button.add_theme_stylebox_override("hover", copy)
			button.add_theme_stylebox_override("pressed", copy)
		for child in button.get_children():
			if not (child is TextureRect):
				continue
			var icon := child as TextureRect
			if icon.texture == _ARROW:
				icon.modulate = _ARROW_TINT
			elif icon.texture == _EMOTE:
				icon.modulate = _EMOTE_TINT

func _set_channel(on: bool, id: String) -> void:
	_ChatSettings.set_enabled(id, on)


func _on_chat_settings() -> void:
	for id in _channel_boxes.keys():
		var box := _channel_boxes[id] as CheckBox
		if box == null:
			continue
		box.set_pressed_no_signal(_ChatSettings.enabled(String(id)))
	if _restored and _tab == _TAB_MAIN:
		_refresh_log()
	_apply_menu_colors()


func _place_settings() -> void:
	if _settings == null or _dock == null or not _settings_open:
		return
	_settings.reset_size()
	var view := get_viewport().get_visible_rect().size
	var at := _dock.position + Vector2(_dock.size.x + 8.0, 0.0)
	if at.x + _settings.size.x > view.x - 8.0:
		at.x = maxf(8.0, view.x - 8.0 - _settings.size.x)
	_settings.position = at


func _gear_icon() -> Texture2D:
	@warning_ignore("shadowed_variable_base_class")
	var size := 22
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(10.5, 10.5)
	var ink := Color(0.22, 0.12, 0.06, 1)
	for y in size:
		for x in size:
			var point := Vector2(float(x) + 0.5, float(y) + 0.5) - center
			var distance := point.length()
			var tooth := 0.62 + 0.38 * absf(sin(point.angle() * 4.0))
			if distance <= 9.0 * tooth and distance >= 3.1:
				image.set_pixel(x, y, ink)
	return ImageTexture.create_from_image(image)


func _style_gear() -> void:
	if _gear == null:
		return
	var box := _header_button(_settings_open)
	_gear.add_theme_stylebox_override("normal", box)
	_gear.add_theme_stylebox_override("hover", box)
	_gear.add_theme_stylebox_override("pressed", box)
	_gear.add_theme_stylebox_override("focus", box)
	_gear.add_theme_color_override("icon_normal_color", Color.WHITE if _settings_open else _INK)
	_gear.add_theme_color_override("icon_hover_color", Color.WHITE if _settings_open else _INK)
	_gear.add_theme_color_override("icon_pressed_color", Color.WHITE if _settings_open else _INK)


func _header_button(pressed: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.border_color = _ORANGE
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 2
	box.content_margin_right = 2
	if pressed:
		box.bg_color = _ORANGE.darkened(0.12)
		box.content_margin_top = 3
		box.content_margin_bottom = 0
	else:
		box.bg_color = _CREAM
		box.shadow_color = Color(0, 0, 0, 0.28)
		box.shadow_size = 2
		box.shadow_offset = Vector2(0, 1)
		box.content_margin_top = 1
		box.content_margin_bottom = 2
	return box


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
	apply_catalog()


## Bought emotions and SpeedChat lines from Clarabelle.
func apply_catalog() -> void:
	var closet := load("res://scenes/catalog/catalog_closet.gd") as GDScript
	if closet == null:
		return
	var emotes: Array = closet.call("emote_rows")
	var phrases: Array = closet.call("phrase_rows")
	if not emotes.is_empty():
		var emotions: Dictionary = _items[0] if not _items.is_empty() and _items[0] is Dictionary else {}
		var lines: Array = emotions.get("items", [])
		for row in emotes:
			if row is not Dictionary or _has_emote(lines, int(row.get("emote", -1))):
				continue
			lines.append(row)
		if emotions.is_empty():
			_items.insert(0, {"title": "EMOTIONS", "items": lines})
		else:
			emotions["items"] = lines
			_items[0] = emotions
	if phrases.is_empty():
		return
	for group in _items:
		if group is Dictionary and String(group.get("title", "")) == "MY PHRASES":
			group["items"] = phrases
			return
	_items.append({"title": "MY PHRASES", "items": phrases})


func _has_emote(lines: Array, emote: int) -> bool:
	for row in lines:
		if row is Dictionary and int(row.get("emote", -2)) == emote:
			return true
	return false
