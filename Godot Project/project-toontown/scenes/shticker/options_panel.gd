class_name OptionsPanel
extends Control

## Sound, keybinds, and graphics. The Shticker Book embeds this page, and
## Pick a Toon and Make a Toon open the same panel before the game starts.

const _PILL := preload("res://assets/toons/gui/QuitBtn_UP.png")
const _PILL_DOWN := preload("res://assets/toons/gui/QuitBtn_DN.png")
const _PILL_HOVER := preload("res://assets/toons/gui/QuitBtn_RLVR.png")
const _KEYS := preload("res://scenes/shticker/keybinds.gd")

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
var _audio_sliders: Array[HSlider] = []
var _gfx_captions: Array[Label] = []
var _gfx_buttons: Array[TextureButton] = []
var _switch_button: TextureButton
var _quit_button: TextureButton
var _close_button: TextureButton
var _on_switch: Callable = Callable()
var _on_quit: Callable = Callable()
var _built := false


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
	var tab_names: PackedStringArray = ["Sound", "Keybinds", "Graphics"]
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
	_audio_row("Music", true)
	_audio_row("Sound Effects", false)
	_gfx_row("Display", _cycle_window)
	_gfx_row("VSync", _cycle_vsync)
	if _on_switch.is_valid():
		_switch_button = _pill("Switch Toon")
		_switch_button.pressed.connect(_on_switch)
		_page.add_child(_switch_button)
		_quit_button = _pill("Quit Game")
		_quit_button.pressed.connect(_on_quit)
		_page.add_child(_quit_button)
	if _popup:
		_close_button = _pill("Close")
		_close_button.pressed.connect(queue_free)
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
	var tab_w := page_size.x * 0.28
	var tab_gap := (page_size.x - tab_w * float(_tabs.size())) / float(_tabs.size() + 1)
	for index in _tabs.size():
		var tab_at := Vector2(tab_gap + float(index) * (tab_w + tab_gap), tab_y)
		_place_pill(_tabs[index], tab_at, Vector2(tab_w, tab_h), body_px)
		_tabs[index].modulate = Color(1.0, 0.86, 0.35) if index == _tab else Color.WHITE
		_tabs[index].mouse_filter = MOUSE_FILTER_IGNORE if _locked else MOUSE_FILTER_STOP
	var top := tab_y + tab_h + page_size.y * 0.04
	var room := page_size.y * 0.86 - top
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
	var audio_h := minf(room / float(maxi(_audio_sliders.size(), 1)), 52.0)
	for index in _audio_sliders.size():
		var y := top + float(index) * audio_h
		var caption := _audio_captions[index]
		caption.position = Vector2(0, y)
		caption.size = Vector2(page_size.x * 0.34, audio_h)
		ToonGui.style_label(caption, Color(0.1, 0.1, 0.1), body_px, Color(0, 0, 0, 0), 0)
		var toggle := _audio_toggles[index]
		_place_pill(toggle, Vector2(page_size.x * 0.36, y + audio_h * 0.22), Vector2(page_size.x * 0.16, audio_h * 0.56), body_px)
		var slider := _audio_sliders[index]
		slider.position = Vector2(page_size.x * 0.54, y + audio_h * 0.32)
		slider.size = Vector2(page_size.x * 0.42, audio_h * 0.36)
	var gfx_h := minf(room / float(maxi(_gfx_buttons.size(), 1)), 52.0)
	for index in _gfx_buttons.size():
		var y := top + float(index) * gfx_h
		var caption := _gfx_captions[index]
		caption.position = Vector2(0, y)
		caption.size = Vector2(page_size.x * 0.46, gfx_h)
		ToonGui.style_label(caption, Color(0.1, 0.1, 0.1), body_px, Color(0, 0, 0, 0), 0)
		_place_pill(_gfx_buttons[index], Vector2(page_size.x * 0.52, y + gfx_h * 0.22), Vector2(page_size.x * 0.36, gfx_h * 0.56), body_px)
	_refresh_binds()
	_paint_audio()
	_paint_graphics()
	_show_group()
	if _switch_button != null:
		_switch_button.visible = not _locked
		_quit_button.visible = not _locked
		_place_pill(_switch_button, Vector2(page_size.x * 0.04, page_size.y * 0.88), Vector2(page_size.x * 0.44, page_size.y * 0.09), body_px)
		_place_pill(_quit_button, Vector2(page_size.x * 0.52, page_size.y * 0.88), Vector2(page_size.x * 0.44, page_size.y * 0.09), body_px)
	if _close_button != null:
		var close_size := Vector2(page_size.x * 0.34, page_size.y * 0.09)
		_place_pill(_close_button, Vector2((page_size.x - close_size.x) * 0.5, page_size.y * 0.88), close_size, body_px)


func _show_group() -> void:
	var sound := _tab == 0
	var keys := _tab == 1
	var graphics := _tab == 2
	for caption in _audio_captions:
		caption.visible = sound
	for toggle in _audio_toggles:
		toggle.visible = sound
	for slider in _audio_sliders:
		slider.visible = sound
	for caption in _bind_captions:
		caption.visible = keys
	for button in _bind_buttons:
		button.visible = keys
	for caption in _gfx_captions:
		caption.visible = graphics
	for button in _gfx_buttons:
		button.visible = graphics


func _set_tab(index: int) -> void:
	if _locked:
		return
	_tab = index
	_listen = ""
	if _popup:
		_layout_popup()
	elif size.y > 1.0:
		layout(size, maxi(int(size.y * 0.038), 13), _locked)


func _audio_row(title: String, music: bool) -> void:
	var caption := Label.new()
	caption.text = title
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = MOUSE_FILTER_IGNORE
	_page.add_child(caption)
	var toggle := _pill("On")
	toggle.pressed.connect(_toggle_audio.bind(music))
	_page.add_child(toggle)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.focus_mode = Control.FOCUS_NONE
	var level := ToonAudio.music_volume() if music else ToonAudio.sfx_volume()
	slider.set_value_no_signal(level * 100.0)
	slider.value_changed.connect(_on_audio_volume.bind(music))
	_style_slider(slider)
	_page.add_child(slider)
	_audio_captions.append(caption)
	_audio_toggles.append(toggle)
	_audio_sliders.append(slider)


func _gfx_row(title: String, action: Callable) -> void:
	var caption := Label.new()
	caption.text = title
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = MOUSE_FILTER_IGNORE
	_page.add_child(caption)
	var button := _pill("Windowed")
	button.pressed.connect(action)
	_page.add_child(button)
	_gfx_captions.append(caption)
	_gfx_buttons.append(button)


func _cycle_window() -> void:
	DisplaySettings.set_fullscreen(not DisplaySettings.fullscreen())
	_paint_graphics()


func _cycle_vsync() -> void:
	DisplaySettings.set_vsync(not DisplaySettings.vsync_on())
	_paint_graphics()


func _paint_graphics() -> void:
	if _gfx_buttons.size() < 2:
		return
	var window := _gfx_buttons[0].get_child(0) as Label
	if window != null:
		window.text = "Fullscreen" if DisplaySettings.fullscreen() else "Windowed"
	var vsync := _gfx_buttons[1].get_child(0) as Label
	if vsync != null:
		vsync.text = "On" if DisplaySettings.vsync_on() else "Off"


func _toggle_audio(music: bool) -> void:
	if music:
		ToonAudio.set_music_on(not ToonAudio.music_on())
	else:
		ToonAudio.set_sfx_on(not ToonAudio.sfx_on())
	_paint_audio()


func _on_audio_volume(value: float, music: bool) -> void:
	if music:
		ToonAudio.set_music_volume(value / 100.0)
	else:
		ToonAudio.set_sfx_volume(value / 100.0)


func _paint_audio() -> void:
	for index in _audio_toggles.size():
		var enabled := ToonAudio.music_on() if index == 0 else ToonAudio.sfx_on()
		var caption := _audio_toggles[index].get_child(0) as Label
		if caption:
			caption.text = "On" if enabled else "Off"


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
		if key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE):
			if _listen != "":
				_listen = ""
				_refresh_binds()
			else:
				queue_free()
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
