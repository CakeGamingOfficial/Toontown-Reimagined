class_name OptionsPanel
extends Control

## Sound, keybinds, and graphics. The Shticker Book embeds this page, and
## Pick a Toon and Make a Toon open the same panel before the game starts.

const _PILL := preload("res://assets/toons/gui/QuitBtn_UP.png")
const _PILL_DOWN := preload("res://assets/toons/gui/QuitBtn_DN.png")
const _PILL_HOVER := preload("res://assets/toons/gui/QuitBtn_RLVR.png")
const _KEYS := preload("res://scenes/shticker/keybinds.gd")
const _ChatSettings := preload("res://scenes/shticker/chat_settings.gd")
const _Style := preload("res://scenes/chat/speed_chat_style.gd")
const _UI := preload("res://scenes/shticker/ui_settings.gd")
const _ARROW_UP := preload("res://assets/gui/friends/Horiz_Arrow_UP.png")
const _ARROW_DOWN := preload("res://assets/gui/friends/Horiz_Arrow_DN.png")
const _ARROW_HOVER := preload("res://assets/gui/friends/Horiz_Arrow_Rllvr.png")

var _page: Control
var _title: Label
var _popup := false
var _locked := false
var _tab := 0
var _listen := ""
var _tabs: Array[TextureButton] = []
var _bind_buttons: Array[TextureButton] = []
var _bind_captions: Array[Label] = []
var _audio_captions: Array[Label] = []
var _audio_toggles: Array[TextureButton] = []
var _toggle_kinds: Array[String] = []
var _audio_sliders: Array[HSlider] = []
var _audio_fields: Array[LineEdit] = []
var _audio_kinds: Array[String] = []
var _device_caption: Label
var _device_button: TextureButton
var _gfx_captions: Array[Label] = []
var _gfx_buttons: Array[TextureButton] = []
var _chat_captions: Array[Label] = []
var _chat_toggles: Array[TextureButton] = []
var _chat_ids: Array[String] = []
var _color_captions: Array[Label] = []
var _color_left: Array[TextureButton] = []
var _color_right: Array[TextureButton] = []
var _color_chips: Array[PanelContainer] = []
var _color_names: Array[Label] = []
var _color_which: Array[String] = []
var _color_page: Array[String] = []
var _ui_caption: Label
var _ui_toggle: TextureButton
var _custom_menu: Control
var _custom_card: Panel
var _custom_title: Label
var _custom_picker: ColorPicker
var _custom_confirm: TextureButton
var _custom_close: TextureButton
var _custom_which := ""
var _ui_fill := false
var _switch_button: TextureButton
var _quit_button: TextureButton
var _close_button: TextureButton
var _on_switch: Callable = Callable()
var _on_quit: Callable = Callable()
var _built := false
var _closing := false
var _close_left := 0


static func open_popup(host: Node) -> OptionsPanel:
	var panel := OptionsPanel.new()
	panel._popup = true
	panel.z_index = 40
	host.add_child(panel)
	return panel


func enable_game_actions(on_switch: Callable, on_quit: Callable) -> void:
	_on_switch = on_switch
	_on_quit = on_quit


func cancel_listen() -> void:
	_listen = ""
	_refresh_binds()


func layout(page_size: Vector2, body_px: int, locked: bool) -> void:
	_locked = locked
	_ensure()
	_page.position = Vector2.ZERO
	_page.size = page_size
	_layout_page(page_size, body_px)


func _ready() -> void:
	_ensure()
	if _popup:
		mouse_filter = MOUSE_FILTER_STOP
		set_anchors_preset(PRESET_FULL_RECT)
		var dim := ColorRect.new()
		dim.color = Color(0.05, 0.12, 0.28, 0.78)
		dim.set_anchors_preset(PRESET_FULL_RECT)
		dim.mouse_filter = MOUSE_FILTER_STOP
		add_child(dim)
		move_child(dim, 0)
		resized.connect(_layout_popup)
		_layout_popup()
	else:
		mouse_filter = MOUSE_FILTER_IGNORE


func _ensure() -> void:
	if _built:
		return
	_built = true
	_page = Control.new()
	_page.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_page)
	if _popup:
		var card := Panel.new()
		card.name = "Card"
		card.mouse_filter = MOUSE_FILTER_IGNORE
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.93, 0.9, 0.78)
		box.border_color = Color(0.45, 0.32, 0.12)
		box.set_border_width_all(4)
		box.set_corner_radius_all(10)
		card.add_theme_stylebox_override("panel", box)
		_page.add_child(card)
	_title = Label.new()
	_title.name = "Title"
	_title.text = "Options"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = MOUSE_FILTER_IGNORE
	_page.add_child(_title)
	var tab_names: PackedStringArray = ["Audio", "Controls", "Video", "Chat", "Gameplay", "UI"]
	for index in tab_names.size():
		var tab := _pill(tab_names[index])
		tab.pressed.connect(_set_tab.bind(index))
		_page.add_child(tab)
		_tabs.append(tab)
	for index in _KEYS.ACTIONS.size():
		var caption := Label.new()
		caption.text = _KEYS.LABELS[index]
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.mouse_filter = MOUSE_FILTER_IGNORE
		_page.add_child(caption)
		var button := _pill(_KEYS.label(_KEYS.ACTIONS[index]))
		button.clip_contents = true
		button.pressed.connect(_on_bind.bind(_KEYS.ACTIONS[index]))
		_page.add_child(button)
		_bind_captions.append(caption)
		_bind_buttons.append(button)
	_device_row()
	_volume_row("Master Volume", "master", false)
	_volume_row("Music", "music", true)
	_volume_row("Sound Effects", "sfx", true)
	_gfx_row("Display Mode", _cycle_window)
	_gfx_row("Resolution", _cycle_resolution)
	_gfx_row("VSync", _cycle_vsync)
	_ChatSettings.bind(_ChatSettings.current_key())
	_color_row("SpeedChat Color", "speed")
	_color_row("SpeedChat++ Color", "plus")
	_ui_row()
	_color_row("In Progress Color", "progress", "ui")
	_color_row("Completed Color", "done", "ui")
	for row in _ChatSettings.rows():
		_chat_row(String(row.get("label", "")), String(row.get("id", "")))
	_ChatSettings.watch(_paint_chat)
	if _on_switch.is_valid():
		_switch_button = _pill("Switch Toon")
		_switch_button.pressed.connect(_on_switch)
		_page.add_child(_switch_button)
		_quit_button = _pill("Quit Game")
		_quit_button.pressed.connect(_on_quit)
		_page.add_child(_quit_button)
	if _popup:
		_close_button = _pill("Close")
		_close_button.button_down.connect(_guard_host)
		_close_button.pressed.connect(_request_close)
		_page.add_child(_close_button)


func _layout_popup() -> void:
	var view := get_viewport_rect().size
	if view.y < 2.0:
		return
	var card_h := view.y * 0.78
	var card_w := minf(card_h * 1.2, view.x * 0.86)
	_page.position = (view - Vector2(card_w, card_h)) * 0.5
	_page.size = Vector2(card_w, card_h)
	_layout_page(_page.size, maxi(int(card_h * 0.038), 13))


func _layout_page(page_size: Vector2, body_px: int) -> void:
	var title_px := maxi(int(page_size.y * 0.07), 18)
	_title.position = Vector2(0, 0)
	_title.size = Vector2(page_size.x, float(title_px) + 8.0)
	ToonGui.style_label(_title, Color(0.08, 0.08, 0.08), title_px, Color(0, 0, 0, 0), 0)
	var card := _page.get_node_or_null("Card") as Panel
	if card != null:
		card.position = Vector2.ZERO
		card.size = page_size
	var tab_y := page_size.y * 0.14
	var tab_h := minf(page_size.y * 0.08, 40.0)
	var tab_gap := page_size.x * 0.012
	var tab_w := (page_size.x - tab_gap * (float(_tabs.size()) + 1.0)) / float(maxi(_tabs.size(), 1))
	for index in _tabs.size():
		var tab_at := Vector2(tab_gap + float(index) * (tab_w + tab_gap), tab_y)
		_place_pill(_tabs[index], tab_at, Vector2(tab_w, tab_h), maxi(int(tab_h * 0.38), 11))
		_tabs[index].modulate = Color(1.0, 0.86, 0.35) if index == _tab else Color.WHITE
		_tabs[index].mouse_filter = MOUSE_FILTER_IGNORE if _locked else MOUSE_FILTER_STOP
	var action_h := page_size.y * 0.09
	var action_pad := maxf(page_size.y * 0.012, 6.0)
	var action_y := page_size.y - action_pad - action_h
	var top := tab_y + tab_h + page_size.y * 0.03
	var room := maxf(action_y - top - page_size.y * 0.015, 1.0)
	var row_h := minf(room / float(maxi(_bind_buttons.size(), 1)), 36.0)
	for index in _bind_buttons.size():
		var y := top + float(index) * row_h
		var caption := _bind_captions[index]
		caption.position = Vector2(0, y)
		caption.size = Vector2(page_size.x * 0.46, row_h)
		ToonGui.style_label(caption, Color(0.1, 0.1, 0.1), body_px, Color(0, 0, 0, 0), 0)
		var button := _bind_buttons[index]
		button.position = Vector2(page_size.x * 0.52, y + row_h * 0.12)
		button.size = Vector2(page_size.x * 0.28, row_h * 0.76)
		var key_name := button.get_child(0) as Label
		ToonGui.style_label(key_name, Color(0.1, 0.1, 0.12), body_px, Color(0, 0, 0, 0), 0)
	var audio_rows := _audio_sliders.size() + (1 if _device_button != null else 0)
	var audio_h := minf(room / float(maxi(audio_rows, 1)), 52.0)
	var audio_at := 0
	if _device_button != null:
		var device_y := top
		_device_caption.position = Vector2(0, device_y)
		_device_caption.size = Vector2(page_size.x * 0.38, audio_h)
		ToonGui.style_label(_device_caption, Color(0.1, 0.1, 0.1), body_px, Color(0, 0, 0, 0), 0)
		_place_pill(_device_button, Vector2(page_size.x * 0.42, device_y + audio_h * 0.22), Vector2(page_size.x * 0.54, audio_h * 0.56), body_px)
		audio_at = 1
	for index in _audio_sliders.size():
		var y := top + float(index + audio_at) * audio_h
		var caption := _audio_captions[index]
		caption.position = Vector2(0, y)
		caption.size = Vector2(page_size.x * 0.30, audio_h)
		ToonGui.style_label(caption, Color(0.1, 0.1, 0.1), body_px, Color(0, 0, 0, 0), 0)
		var slider_x := page_size.x * 0.32
		var toggle := _toggle_for(_audio_kinds[index])
		if toggle != null:
			_place_pill(toggle, Vector2(page_size.x * 0.32, y + audio_h * 0.22), Vector2(page_size.x * 0.13, audio_h * 0.56), body_px)
			slider_x = page_size.x * 0.47
		var field_w := page_size.x * 0.12
		var field := _audio_fields[index]
		field.position = Vector2(page_size.x * 0.84, y + audio_h * 0.2)
		field.size = Vector2(field_w, audio_h * 0.6)
		field.add_theme_font_size_override("font_size", body_px)
		var slider := _audio_sliders[index]
		slider.position = Vector2(slider_x, y + audio_h * 0.32)
		slider.size = Vector2(page_size.x * 0.82 - slider_x, audio_h * 0.36)
	var gfx_h := minf(room / float(maxi(_gfx_buttons.size(), 1)), 52.0)
	for index in _gfx_buttons.size():
		var y := top + float(index) * gfx_h
		var caption := _gfx_captions[index]
		caption.position = Vector2(0, y)
		caption.size = Vector2(page_size.x * 0.38, gfx_h)
		ToonGui.style_label(caption, Color(0.1, 0.1, 0.1), body_px, Color(0, 0, 0, 0), 0)
		_place_pill(_gfx_buttons[index], Vector2(page_size.x * 0.42, y + gfx_h * 0.22), Vector2(page_size.x * 0.54, gfx_h * 0.56), body_px)
	var chat_colors := 0
	for page in _color_page:
		if page == "chat":
			chat_colors += 1
	var chat_rows := chat_colors + _chat_toggles.size()
	var chat_h := minf(room / float(maxi(chat_rows, 1)), 36.0)
	var chat_at := 0
	for index in _color_captions.size():
		if _color_page[index] != "chat":
			continue
		var color_y := top + float(chat_at) * chat_h
		chat_at += 1
		var color_caption := _color_captions[index]
		color_caption.position = Vector2(0, color_y)
		color_caption.size = Vector2(page_size.x * 0.40, chat_h)
		ToonGui.style_label(color_caption, Color(0.1, 0.1, 0.1), body_px, Color(0, 0, 0, 0), 0)
		var arrow_w := page_size.x * 0.07
		var arrow_h := chat_h * 0.7
		var arrow_y := color_y + (chat_h - arrow_h) * 0.5
		_place_arrow(_color_left[index], Vector2(page_size.x * 0.42, arrow_y), Vector2(arrow_w, arrow_h), true)
		var chip := _color_chips[index]
		chip.position = Vector2(page_size.x * 0.51, color_y + chat_h * 0.12)
		chip.size = Vector2(page_size.x * 0.32, chat_h * 0.76)
		var chip_name := _color_names[index]
		chip_name.position = Vector2.ZERO
		chip_name.size = chip.size
		ToonGui.style_label(chip_name, Color(0.05, 0.05, 0.08), maxi(body_px - 1, 12), Color(0, 0, 0, 0), 0)
		_place_arrow(_color_right[index], Vector2(page_size.x * 0.85, arrow_y), Vector2(arrow_w, arrow_h), false)
	for index in _chat_toggles.size():
		var chat_y := top + float(chat_at) * chat_h
		chat_at += 1
		var chat_caption := _chat_captions[index]
		chat_caption.position = Vector2(0, chat_y)
		chat_caption.size = Vector2(page_size.x * 0.62, chat_h)
		ToonGui.style_label(chat_caption, Color(0.1, 0.1, 0.1), body_px, Color(0, 0, 0, 0), 0)
		_place_pill(_chat_toggles[index], Vector2(page_size.x * 0.66, chat_y + chat_h * 0.12), Vector2(page_size.x * 0.28, chat_h * 0.76), body_px)
	var ui_colors := 0
	for page in _color_page:
		if page == "ui":
			ui_colors += 1
	var ui_h := minf(room / float(maxi(1 + ui_colors, 1)), 52.0)
	var ui_at := 0
	if _ui_caption != null:
		_ui_caption.position = Vector2(0, top)
		_ui_caption.size = Vector2(page_size.x * 0.62, ui_h)
		ToonGui.style_label(_ui_caption, Color(0.1, 0.1, 0.1), body_px, Color(0, 0, 0, 0), 0)
		_place_pill(_ui_toggle, Vector2(page_size.x * 0.66, top + ui_h * 0.22), Vector2(page_size.x * 0.28, ui_h * 0.56), body_px)
		ui_at = 1
	for index in _color_captions.size():
		if _color_page[index] != "ui":
			continue
		var color_y := top + float(ui_at) * ui_h
		ui_at += 1
		var color_caption := _color_captions[index]
		color_caption.position = Vector2(0, color_y)
		color_caption.size = Vector2(page_size.x * 0.40, ui_h)
		ToonGui.style_label(color_caption, Color(0.1, 0.1, 0.1), body_px, Color(0, 0, 0, 0), 0)
		var arrow_w := page_size.x * 0.07
		var arrow_h := ui_h * 0.7
		var arrow_y := color_y + (ui_h - arrow_h) * 0.5
		_place_arrow(_color_left[index], Vector2(page_size.x * 0.42, arrow_y), Vector2(arrow_w, arrow_h), true)
		var chip := _color_chips[index]
		chip.position = Vector2(page_size.x * 0.51, color_y + ui_h * 0.12)
		chip.size = Vector2(page_size.x * 0.32, ui_h * 0.76)
		var chip_name := _color_names[index]
		chip_name.position = Vector2.ZERO
		chip_name.size = chip.size
		ToonGui.style_label(chip_name, Color(0.05, 0.05, 0.08), maxi(body_px - 1, 12), Color(0, 0, 0, 0), 0)
		_place_arrow(_color_right[index], Vector2(page_size.x * 0.85, arrow_y), Vector2(arrow_w, arrow_h), false)
	_refresh_binds()
	_paint_audio()
	_paint_graphics()
	_paint_chat()
	_paint_ui()
	_show_group()
	if _custom_menu != null and _custom_menu.visible:
		_place_custom_menu()
	if _switch_button != null:
		_switch_button.visible = not _locked
		_quit_button.visible = not _locked
		_place_pill(_switch_button, Vector2(page_size.x * 0.04, action_y), Vector2(page_size.x * 0.44, action_h), body_px)
		_place_pill(_quit_button, Vector2(page_size.x * 0.52, action_y), Vector2(page_size.x * 0.44, action_h), body_px)
	if _close_button != null:
		var close_size := Vector2(page_size.x * 0.34, action_h)
		_place_pill(_close_button, Vector2((page_size.x - close_size.x) * 0.5, action_y), close_size, body_px)


func _show_group() -> void:
	var sound := _tab == 0
	var keys := _tab == 1
	var graphics := _tab == 2
	var chat := _tab == 3
	var ui := _tab == 5
	for caption in _audio_captions:
		caption.visible = sound
	for toggle in _audio_toggles:
		toggle.visible = sound
	for slider in _audio_sliders:
		slider.visible = sound
	for field in _audio_fields:
		field.visible = sound
	if _device_caption != null:
		_device_caption.visible = sound
		_device_button.visible = sound
	for caption in _bind_captions:
		caption.visible = keys
	for button in _bind_buttons:
		button.visible = keys
	for caption in _gfx_captions:
		caption.visible = graphics
	for button in _gfx_buttons:
		button.visible = graphics
	for caption in _chat_captions:
		caption.visible = chat
	for toggle in _chat_toggles:
		toggle.visible = chat
	if _ui_caption != null:
		_ui_caption.visible = ui
		_ui_toggle.visible = ui
	if not ui and _custom_menu != null:
		_custom_menu.visible = false
	for index in _color_captions.size():
		var show_color := (_color_page[index] == "chat" and chat) or (_color_page[index] == "ui" and ui)
		_color_captions[index].visible = show_color
		_color_left[index].visible = show_color
		_color_right[index].visible = show_color
		_color_chips[index].visible = show_color


func _set_tab(index: int) -> void:
	if _locked:
		return
	_tab = index
	_listen = ""
	if _popup:
		_layout_popup()
	elif size.y > 1.0:
		layout(size, maxi(int(size.y * 0.038), 13), _locked)


func _device_row() -> void:
	_device_caption = Label.new()
	_device_caption.text = "Audio Device"
	_device_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_device_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_device_caption.mouse_filter = MOUSE_FILTER_IGNORE
	_page.add_child(_device_caption)
	_device_button = _pill("Default")
	_device_button.clip_contents = true
	var device_label := _device_button.get_child(0) as Label
	device_label.clip_text = true
	device_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_device_button.pressed.connect(_cycle_device)
	_page.add_child(_device_button)


func _volume_row(title: String, kind: String, with_toggle: bool) -> void:
	var caption := Label.new()
	caption.text = title
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = MOUSE_FILTER_IGNORE
	_page.add_child(caption)
	if with_toggle:
		var toggle := _pill("On")
		toggle.pressed.connect(_toggle_audio.bind(kind))
		_page.add_child(toggle)
		_audio_toggles.append(toggle)
		_toggle_kinds.append(kind)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.focus_mode = Control.FOCUS_NONE
	slider.set_value_no_signal(_volume_of(kind) * 100.0)
	slider.value_changed.connect(_on_audio_volume.bind(kind))
	_style_slider(slider)
	_page.add_child(slider)
	var field := _volume_field(kind)
	field.text = str(int(round(slider.value)))
	_page.add_child(field)
	_audio_captions.append(caption)
	_audio_sliders.append(slider)
	_audio_fields.append(field)
	_audio_kinds.append(kind)


func _volume_field(kind: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.max_length = 3
	edit.context_menu_enabled = false
	edit.virtual_keyboard_enabled = false
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 0.98, 0.9, 1)
	box.border_color = Color(0.45, 0.32, 0.12)
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	var focus := box.duplicate() as StyleBoxFlat
	focus.border_color = Color(0.95, 0.55, 0.16, 1)
	edit.add_theme_stylebox_override("normal", box)
	edit.add_theme_stylebox_override("focus", focus)
	edit.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	var face := ToonGui.font()
	if face != null:
		edit.add_theme_font_override("font", face)
	edit.text_submitted.connect(_commit_volume.bind(kind))
	edit.focus_exited.connect(_commit_volume_field.bind(kind))
	return edit


func _commit_volume_field(kind: String) -> void:
	var index := _audio_kinds.find(kind)
	if index < 0:
		return
	_commit_volume(_audio_fields[index].text, kind)

func _ui_row() -> void:
	_ui_caption = Label.new()
	_ui_caption.text = "Task Tracker"
	_ui_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ui_caption.mouse_filter = MOUSE_FILTER_IGNORE
	_page.add_child(_ui_caption)
	_ui_toggle = _pill("On")
	_ui_toggle.pressed.connect(_toggle_tracker)
	_page.add_child(_ui_toggle)


func _toggle_tracker() -> void:
	_UI.set_tracker_on(not _UI.tracker_on())
	_paint_ui()


func _paint_ui() -> void:
	if _ui_toggle == null:
		return
	var caption := _ui_toggle.get_child(0) as Label
	if caption != null:
		caption.text = "On" if _UI.tracker_on() else "Off"


func _open_custom_color(which: String) -> void:
	_ensure_custom_menu()
	_swap_copy_button(_custom_picker)
	_custom_which = which
	_custom_title.text = "In Progress Color" if which == "progress" else "Completed Color"
	_ui_fill = true
	_custom_picker.color = _UI.active_color(which)
	_ui_fill = false
	_custom_menu.visible = true
	_place_custom_menu()


func _ensure_custom_menu() -> void:
	if _custom_menu != null:
		return
	_custom_menu = Control.new()
	_custom_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_custom_menu.z_index = 40
	_custom_menu.visible = false
	_custom_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_custom_menu.gui_input.connect(_on_custom_dim)
	add_child(_custom_menu)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.12, 0.28, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_custom_menu.add_child(dim)
	_custom_card = Panel.new()
	_custom_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.93, 0.9, 0.78)
	box.border_color = Color(0.45, 0.32, 0.12)
	box.set_border_width_all(4)
	box.set_corner_radius_all(10)
	_custom_card.add_theme_stylebox_override("panel", box)
	_custom_menu.add_child(_custom_card)
	_custom_title = Label.new()
	_custom_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_custom_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_custom_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_custom_card.add_child(_custom_title)
	_custom_picker = ColorPicker.new()
	_custom_picker.edit_alpha = false
	_custom_picker.sampler_visible = false
	_custom_picker.presets_visible = false
	_custom_picker.color_mode = ColorPicker.MODE_RGB
	_custom_picker.theme = _toon_picker_theme()
	_custom_picker.color_changed.connect(_on_custom_color)
	_custom_card.add_child(_custom_picker)
	_swap_copy_button(_custom_picker)
	_custom_confirm = _pill("Confirm")
	_custom_confirm.pressed.connect(_confirm_custom)
	_custom_card.add_child(_custom_confirm)
	_custom_close = _pill("Close")
	_custom_close.pressed.connect(_close_custom)
	_custom_card.add_child(_custom_close)


func _swap_copy_button(node: Node) -> bool:
	for child in node.get_children(true):
		if child is Button:
			var button := child as Button
			var hint := (button.text + " " + button.tooltip_text).to_lower()
			if hint.contains("copy"):
				_replace_copy_button(button)
				return true
		if child is LineEdit:
			var field := child as LineEdit
			var field_hint := (field.placeholder_text + " " + field.tooltip_text).to_lower()
			if field_hint.contains("hex"):
				var copy := _button_after(field)
				if copy != null:
					_replace_copy_button(copy)
					return true
		if _swap_copy_button(child):
			return true
	return false


func _button_after(field: LineEdit) -> Button:
	var row := field.get_parent()
	if row == null:
		return null
	var found := false
	for sibling in row.get_children():
		if sibling == field:
			found = true
		elif found and sibling is Button:
			return sibling as Button
	return null


func _replace_copy_button(copy: Button) -> void:
	copy.visible = false
	copy.disabled = true
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := copy.get_parent()
	if row == null or row.has_node("PasteHex"):
		return
	var paste := Button.new()
	paste.name = "PasteHex"
	paste.text = "Paste"
	paste.tooltip_text = "Paste a color from your clipboard."
	paste.custom_minimum_size = Vector2(72, 0)
	paste.focus_mode = Control.FOCUS_NONE
	row.add_child(paste)
	paste.pressed.connect(_paste_clipboard_color)


func _paste_clipboard_color() -> void:
	var color: Variant = _color_from_clipboard()
	if color == null:
		return
	_ui_fill = true
	_custom_picker.color = color
	_ui_fill = false


func _confirm_custom() -> void:
	if _custom_which == "" or _custom_picker == null:
		return
	_UI.set_custom(_custom_which, _custom_picker.color)
	_paint_chat()


func _color_from_clipboard() -> Variant:
	var raw := DisplayServer.clipboard_get().strip_edges().trim_prefix("#")
	if raw.length() == 3 and raw.is_valid_hex_number():
		raw = "%s%s%s%s%s%s" % [raw[0], raw[0], raw[1], raw[1], raw[2], raw[2]]
	if raw.length() == 8 and raw.is_valid_hex_number():
		raw = raw.substr(0, 6)
	if raw.length() == 6 and raw.is_valid_hex_number():
		return Color.html(raw)
	var pieces := raw.replace(",", " ").split(" ", false)
	if pieces.size() < 3:
		return null
	var numbers: Array[int] = []
	for i in 3:
		if not pieces[i].is_valid_int():
			return null
		numbers.append(clampi(int(pieces[i]), 0, 255))
	return Color8(numbers[0], numbers[1], numbers[2])


func _toon_picker_theme() -> Theme:
	var theme := Theme.new()
	var face := ToonGui.font()
	theme.default_font = face
	theme.default_font_size = 16
	var ink := Color(0.1, 0.1, 0.1)
	theme.set_color("font_color", "Label", ink)
	theme.set_font("font", "Label", face)
	theme.set_font_size("font_size", "Label", 16)
	var field := StyleBoxFlat.new()
	field.bg_color = Color(1, 0.98, 0.9)
	field.border_color = Color(0, 0, 0)
	field.set_border_width_all(2)
	field.set_corner_radius_all(6)
	field.set_content_margin_all(4)
	var focus := field.duplicate() as StyleBoxFlat
	focus.border_color = Color(0.95, 0.55, 0.16)
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_color("font_color", "LineEdit", ink)
	theme.set_font("font", "LineEdit", face)
	theme.set_font_size("font_size", "LineEdit", 16)
	var button := StyleBoxFlat.new()
	button.bg_color = Color(0.98, 0.9, 0.55)
	button.border_color = Color(0.45, 0.32, 0.12)
	button.set_border_width_all(2)
	button.set_corner_radius_all(8)
	button.set_content_margin_all(4)
	var hover := button.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1, 0.96, 0.7)
	var pressed := button.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.9, 0.72, 0.28)
	theme.set_stylebox("normal", "Button", button)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_color("font_color", "Button", Color(0.12, 0.12, 0.14))
	theme.set_font("font", "Button", face)
	theme.set_font_size("font_size", "Button", 16)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.72, 0.58, 0.38)
	track.set_corner_radius_all(5)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Color(0.95, 0.55, 0.16)
	var knob := _knob_texture()
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	theme.set_icon("grabber", "HSlider", knob)
	theme.set_icon("grabber_highlight", "HSlider", knob)
	var popup := StyleBoxFlat.new()
	popup.bg_color = Color(0.98, 0.96, 0.88)
	popup.border_color = Color(0.45, 0.32, 0.12)
	popup.set_border_width_all(2)
	popup.set_corner_radius_all(6)
	theme.set_stylebox("panel", "PopupMenu", popup)
	theme.set_font("font", "PopupMenu", face)
	theme.set_font_size("font_size", "PopupMenu", 16)
	theme.set_color("font_color", "PopupMenu", ink)
	var marked := StyleBoxFlat.new()
	marked.bg_color = Color(1, 0.86, 0.35, 0.85)
	theme.set_stylebox("hover", "PopupMenu", marked)
	return theme


func _place_custom_menu() -> void:
	if _custom_menu == null:
		return
	var area := size
	if area.y < 2.0 and _page != null:
		area = _page.size
	_custom_menu.position = Vector2.ZERO
	_custom_menu.size = area
	var card_w := minf(maxf(area.x * 0.72, 320.0), 440.0)
	var inner_w := card_w - 24.0
	_custom_picker.custom_minimum_size = Vector2(inner_w, 0)
	var picker_h := _custom_picker.get_combined_minimum_size().y
	if picker_h < 1.0:
		picker_h = 460.0
	var title_h := 40.0
	var close_h := 36.0
	var gap := 8.0
	var card_h := title_h + picker_h + gap + close_h + 14.0
	_custom_card.position = Vector2((area.x - card_w) * 0.5, maxf((area.y - card_h) * 0.5, 8.0))
	_custom_card.size = Vector2(card_w, card_h)
	_custom_title.position = Vector2(12, 6)
	_custom_title.size = Vector2(inner_w, title_h - 8.0)
	ToonGui.style_label(_custom_title, Color(0.08, 0.08, 0.08), 20, Color(0, 0, 0, 0), 0)
	_custom_picker.position = Vector2(12, title_h)
	_custom_picker.size = Vector2(inner_w, picker_h)
	var button_w := minf(card_w * 0.36, 140.0)
	var row_y := title_h + picker_h + gap
	var pair_x := (card_w - button_w * 2.0 - gap) * 0.5
	_place_pill(_custom_confirm, Vector2(pair_x, row_y), Vector2(button_w, close_h), 16)
	_place_pill(_custom_close, Vector2(pair_x + button_w + gap, row_y), Vector2(button_w, close_h), 16)


func _close_custom() -> void:
	if _custom_menu != null:
		_custom_menu.visible = false


func _on_custom_dim(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT:
		return
	if Rect2(_custom_card.position, _custom_card.size).has_point(click.position):
		return
	_close_custom()


func _on_chip_click(event: InputEvent, which: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_custom_color(which)


func _on_custom_color(color: Color) -> void:
	if _ui_fill or _custom_which == "":
		return
	_UI.set_custom(_custom_which, color)
	_paint_chat()


func _color_row(title: String, which: String, page: String = "chat") -> void:
	var caption := Label.new()
	caption.text = title
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = MOUSE_FILTER_IGNORE
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_page.add_child(caption)
	var left := _arrow_button()
	left.pressed.connect(_nudge_color.bind(which, -1))
	_page.add_child(left)
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_STOP if page == "ui" else Control.MOUSE_FILTER_IGNORE
	if page == "ui":
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		chip.gui_input.connect(_on_chip_click.bind(which))
		chip.mouse_entered.connect(func() -> void:
			chip.modulate = Color(0.15, 0.82, 1.0)
		)
		chip.mouse_exited.connect(func() -> void:
			chip.modulate = Color.WHITE
		)
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(6)
	box.set_content_margin_all(2)
	box.border_color = Color(0, 0, 0)
	box.set_border_width_all(2)
	chip.add_theme_stylebox_override("panel", box)
	var name := Label.new()
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(name)
	_page.add_child(chip)
	var right := _arrow_button()
	right.pressed.connect(_nudge_color.bind(which, 1))
	_page.add_child(right)
	_color_captions.append(caption)
	_color_left.append(left)
	_color_right.append(right)
	_color_chips.append(chip)
	_color_names.append(name)
	_color_which.append(which)
	_color_page.append(page)


func _arrow_button() -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _ARROW_UP
	button.texture_pressed = _ARROW_DOWN
	button.texture_hover = _ARROW_HOVER
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _place_arrow(button: TextureButton, at: Vector2, box: Vector2, flip: bool) -> void:
	button.position = at
	button.size = box
	button.pivot_offset = box * 0.5
	button.scale = Vector2(-1, 1) if flip else Vector2.ONE


func _nudge_color(which: String, step: int) -> void:
	if which == "progress" or which == "done":
		_UI.set_color_index(which, _UI.color_index(which) + step)
		_paint_chat()
		return
	var current := _ChatSettings.speed_color() if which == "speed" else _ChatSettings.plus_color()
	if which == "speed":
		_ChatSettings.set_speed_color(current + step)
	else:
		_ChatSettings.set_plus_color(current + step)


func _paint_color(index: int) -> void:
	var which := _color_which[index]
	var chosen := 0
	var swatch := Color.WHITE
	var label := ""
	var last := 0
	if which == "progress" or which == "done":
		chosen = _UI.color_index(which)
		swatch = _UI.active_color(which)
		label = "#" + _UI.custom_hex(which).to_upper() if _UI.has_custom(which) else _UI.color_name(chosen)
		last = _UI.count() - 1
	else:
		chosen = _ChatSettings.speed_color() if which == "speed" else _ChatSettings.plus_color()
		swatch = _Style.frame(chosen)
		label = _Style.style_name(chosen)
		last = _Style.count() - 1
	var chip := _color_chips[index]
	var box := chip.get_theme_stylebox("panel")
	if box is StyleBoxFlat:
		var next := (box as StyleBoxFlat).duplicate() as StyleBoxFlat
		next.bg_color = swatch
		chip.add_theme_stylebox_override("panel", next)
	_color_names[index].text = label
	var bright := swatch.r * 0.3 + swatch.g * 0.59 + swatch.b * 0.11
	_color_names[index].add_theme_color_override("font_color", Color(1, 1, 1) if bright < 0.55 else Color(0.05, 0.05, 0.08))
	var named := which != "progress" and which != "done" or not _UI.has_custom(which)
	var at_start := named and chosen <= 0
	var at_end := named and chosen >= last
	_color_left[index].modulate = Color(1, 1, 1, 0.35) if at_start else Color.WHITE
	_color_left[index].mouse_filter = Control.MOUSE_FILTER_IGNORE if at_start else Control.MOUSE_FILTER_STOP
	_color_right[index].modulate = Color(1, 1, 1, 0.35) if at_end else Color.WHITE
	_color_right[index].mouse_filter = Control.MOUSE_FILTER_IGNORE if at_end else Control.MOUSE_FILTER_STOP

func _chat_row(title: String, id: String) -> void:
	var caption := Label.new()
	caption.text = title
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = MOUSE_FILTER_IGNORE
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_page.add_child(caption)
	var toggle := _pill("On")
	toggle.pressed.connect(_toggle_chat.bind(id))
	_page.add_child(toggle)
	_chat_captions.append(caption)
	_chat_toggles.append(toggle)
	_chat_ids.append(id)


func _toggle_chat(id: String) -> void:
	_ChatSettings.set_enabled(id, not _ChatSettings.enabled(id))


func _paint_chat() -> void:
	for index in _chat_toggles.size():
		var caption := _chat_toggles[index].get_child(0) as Label
		if caption == null:
			continue
		caption.text = "On" if _ChatSettings.enabled(_chat_ids[index]) else "Off"
	for index in _color_chips.size():
		_paint_color(index)


func _gfx_row(title: String, action: Callable) -> void:
	var caption := Label.new()
	caption.text = title
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = MOUSE_FILTER_IGNORE
	_page.add_child(caption)
	var button := _pill("Windowed")
	button.clip_contents = true
	var button_label := button.get_child(0) as Label
	button_label.clip_text = true
	button_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.pressed.connect(action)
	_page.add_child(button)
	_gfx_captions.append(caption)
	_gfx_buttons.append(button)


func _cycle_window() -> void:
	DisplaySettings.cycle_mode()
	_paint_graphics()


func _cycle_resolution() -> void:
	DisplaySettings.cycle_resolution()
	_paint_graphics()


func _cycle_device() -> void:
	var names := ToonAudio.devices()
	var index := names.find(ToonAudio.device_name())
	if index < 0:
		index = 0
	ToonAudio.set_device(names[(index + 1) % names.size()])
	_paint_audio()


func _cycle_vsync() -> void:
	DisplaySettings.set_vsync(not DisplaySettings.vsync_on())
	_paint_graphics()


func _paint_graphics() -> void:
	if _gfx_buttons.size() < 3:
		return
	var window := _gfx_buttons[0].get_child(0) as Label
	if window != null:
		window.text = DisplaySettings.mode_label()
	var size := _gfx_buttons[1].get_child(0) as Label
	if size != null:
		size.text = DisplaySettings.resolution_label()
	var vsync := _gfx_buttons[2].get_child(0) as Label
	if vsync != null:
		vsync.text = "On" if DisplaySettings.vsync_on() else "Off"


func _toggle_audio(kind: String) -> void:
	if kind == "music":
		ToonAudio.set_music_on(not ToonAudio.music_on())
	elif kind == "sfx":
		ToonAudio.set_sfx_on(not ToonAudio.sfx_on())
	_paint_audio()


func _on_audio_volume(value: float, kind: String) -> void:
	var linear := value / 100.0
	if kind == "master":
		ToonAudio.set_master_volume(linear)
	elif kind == "music":
		ToonAudio.set_music_volume(linear)
	elif kind == "sfx":
		ToonAudio.set_sfx_volume(linear)
	var index := _audio_kinds.find(kind)
	if index >= 0:
		_show_volume(_audio_fields[index], int(round(value)))


func _commit_volume(text: String, kind: String) -> void:
	var index := _audio_kinds.find(kind)
	if index < 0:
		return
	var field := _audio_fields[index]
	var slider := _audio_sliders[index]
	if not text.is_valid_int():
		field.text = str(int(round(slider.value)))
		return
	var number := clampi(int(text), 0, 100)
	field.text = str(number)
	if int(round(slider.value)) != number:
		slider.set_value(float(number))


func _show_volume(field: LineEdit, number: int) -> void:
	if field.has_focus():
		return
	field.text = str(number)


func _volume_of(kind: String) -> float:
	if kind == "master":
		return ToonAudio.master_volume()
	if kind == "music":
		return ToonAudio.music_volume()
	return ToonAudio.sfx_volume()


func _toggle_for(kind: String) -> TextureButton:
	var index := _toggle_kinds.find(kind)
	if index < 0:
		return null
	return _audio_toggles[index]


func _paint_audio() -> void:
	if _device_button != null:
		var device := _device_button.get_child(0) as Label
		if device != null:
			device.text = ToonAudio.device_name()
	for index in _audio_toggles.size():
		var kind := _toggle_kinds[index]
		var enabled := ToonAudio.music_on() if kind == "music" else ToonAudio.sfx_on()
		var caption := _audio_toggles[index].get_child(0) as Label
		if caption:
			caption.text = "On" if enabled else "Off"
	for index in _audio_fields.size():
		_show_volume(_audio_fields[index], int(round(_audio_sliders[index].value)))


func _guard_host() -> void:
	var host := get_parent()
	if host != null and host.has_method("_swallow_click"):
		host.call("_swallow_click")


func _request_close() -> void:
	if not _popup or _closing:
		return
	_closing = true
	_close_left = 2
	var host := get_parent()
	if host != null and host.has_method("_swallow_click"):
		host.call("_swallow_click")
	set_process(true)


func _process(_delta: float) -> void:
	if not _closing:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_close_left = 2
		return
	_close_left -= 1
	if _close_left > 0:
		return
	queue_free()


func _on_bind(action: String) -> void:
	if _locked:
		return
	_listen = action
	_refresh_binds()


func _refresh_binds() -> void:
	var listening := Color(0.45, 0.9, 1.0)
	for index in _bind_buttons.size():
		var action := _KEYS.ACTIONS[index]
		var caption := _bind_buttons[index].get_child(0) as Label
		if action == _listen:
			caption.text = "?"
			_bind_buttons[index].modulate = listening
		else:
			caption.text = _KEYS.label(action)
			_bind_buttons[index].modulate = Color.WHITE


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _popup and event is InputEventKey:
		var key := event as InputEventKey
		if _typing():
			if key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE):
				get_viewport().gui_get_focus_owner().release_focus()
				get_viewport().set_input_as_handled()
			return
		if key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE):
			if _listen != "":
				_listen = ""
				_refresh_binds()
			else:
				_request_close()
			get_viewport().set_input_as_handled()
			return
		if _listen == "":
			get_viewport().set_input_as_handled()
			return
	if _listen == "" or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if event.is_action_pressed("ui_cancel") or key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE:
		_listen = ""
		_refresh_binds()
		get_viewport().set_input_as_handled()
		return
	var code := key.physical_keycode
	if code == KEY_NONE:
		code = key.keycode
	get_viewport().set_input_as_handled()
	_KEYS.assign(_listen, code)
	_listen = ""
	_refresh_binds()


func _typing() -> bool:
	var owner := get_viewport().gui_get_focus_owner()
	return owner is LineEdit or owner is TextEdit


func _pill(text: String) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _PILL
	button.texture_hover = _PILL_HOVER
	button.texture_pressed = _PILL_DOWN
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	var caption := Label.new()
	caption.text = text
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.set_anchors_preset(PRESET_FULL_RECT)
	button.add_child(caption)
	return button


func _place_pill(button: TextureButton, at: Vector2, box: Vector2, body_px: int) -> void:
	button.position = at
	button.size = box
	var caption := button.get_child(0) as Label
	ToonGui.style_label(caption, Color(0.12, 0.12, 0.14), maxi(body_px - 1, 12), Color(0, 0, 0, 0), 0)


func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.72, 0.58, 0.38, 1)
	track.set_corner_radius_all(5)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Color(0.95, 0.55, 0.16, 1)
	var knob := _knob_texture()
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", knob)


func _knob_texture() -> Texture2D:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in 16:
		for x in 16:
			var edge := x < 2 or y < 2 or x > 13 or y > 13
			image.set_pixel(x, y, Color(0.42, 0.24, 0.05, 1) if edge else Color(0.98, 0.84, 0.32, 1))
	return ImageTexture.create_from_image(image)
