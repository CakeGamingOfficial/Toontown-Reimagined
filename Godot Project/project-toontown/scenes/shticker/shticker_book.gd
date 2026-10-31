class_name ShtickerBook
extends Control

## ShtikerBook. The corner button opens the book on a blue field, icon tabs
## sit down the right edge, and the pages are Options, the map, Gags,
## ToonTasks, and the Cog Gallery. Harry's reward still opens on the map and
## turns to gags, then tasks.

signal book_opened
signal book_closed
signal page_ready(which: int)

const PAGE_OPTIONS := 0
const PAGE_MAP := 1
const PAGE_GAGS := 2
const PAGE_TASKS := 3
const PAGE_COGS := 4
const _PAGE_NAMES: PackedStringArray = ["Options", "Map", "Gags", "ToonTasks", "Cog Gallery"]
const _BEANS := preload("res://scenes/toons/jellybeans.gd")

const _BOOK := preload("res://assets/gui/tutorial/book/big_book.png")
const _CLOSED := preload("res://assets/gui/tutorial/book/BookIcon_CLSD.png")
const _OPEN_ICON := preload("res://assets/gui/tutorial/book/BookIcon_OPEN.png")
const _HOVER := preload("res://assets/gui/tutorial/book/BookIcon_RLVR.png")
const _ARROW := preload("res://assets/gui/tutorial/book/arrow_button.png")
const _MAP := preload("res://assets/gui/tutorial/book/toontown_map.jpg")
const _CLOUD := preload("res://assets/gui/tutorial/book/cloud.png")
const _JAR := preload("res://assets/gui/tutorial/book/jar.png")
const _PILL := preload("res://assets/toons/gui/QuitBtn_UP.png")
const _PILL_DOWN := preload("res://assets/toons/gui/QuitBtn_DN.png")
const _PILL_HOVER := preload("res://assets/toons/gui/QuitBtn_RLVR.png")
const _DIALOG := preload("res://assets/gui/tutorial/dialog/dialog_box.png")
const _OK_UP := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_UP.png")
const _OK_DOWN := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_DN.png")
const _OK_HOVER := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_Rllvr.png")
const _CANCEL_UP := preload("res://assets/toons/gui/CloseBtn_UP.png")
const _CANCEL_DOWN := preload("res://assets/toons/gui/CloseBtn_DN.png")
const _CANCEL_HOVER := preload("res://assets/toons/gui/CloseBtn_Rllvr.png")
const _PICK_SCENE := "res://scenes/toons/pick_a_toon.tscn"
const _ROW := preload("res://assets/gui/tutorial/InventoryRow.png")
const _TRASH_CLOSED := preload("res://assets/toons/gui/TrashCan_CLSD.png")
const _TRASH_OPEN := preload("res://assets/toons/gui/TrashCan_OPEN.png")
const _TRASH_HOVER := preload("res://assets/toons/gui/TrashCan_RLVR.png")
# InventoryNew places one icon from AvPropsNew on each well of InventoryRow.
const _GAG_ICON: Array[Texture2D] = [
	preload("res://assets/gui/tutorial/gags/inventory_feather.png"),
	preload("res://assets/gui/tutorial/gags/inventory_megaphone.png"),
	preload("res://assets/gui/tutorial/gags/inventory_lipstick.png"),
	preload("res://assets/gui/tutorial/gags/inventory_bamboo_cane.png"),
	preload("res://assets/gui/tutorial/gags/inventory_pixiedust.png"),
	preload("res://assets/gui/tutorial/gags/inventory_juggling_cubes.png"),
	preload("res://assets/gui/tutorial/gags/inventory_ladder.png"),
	preload("res://assets/gui/tutorial/gags/inventory_bannana_peel.png"),
	preload("res://assets/gui/tutorial/gags/inventory_rake.png"),
	preload("res://assets/gui/tutorial/gags/inventory_marbles.png"),
	preload("res://assets/gui/tutorial/gags/inventory_quicksand_icon.png"),
	preload("res://assets/gui/tutorial/gags/inventory_trapdoor.png"),
	preload("res://assets/gui/tutorial/gags/inventory_tnt.png"),
	preload("res://assets/gui/tutorial/gags/inventory_traintracks.png"),
	preload("res://assets/gui/tutorial/gags/inventory_1dollarbill.png"),
	preload("res://assets/gui/tutorial/gags/inventory_small_magnet.png"),
	preload("res://assets/gui/tutorial/gags/inventory_5dollarbill.png"),
	preload("res://assets/gui/tutorial/gags/inventory_big_magnet.png"),
	preload("res://assets/gui/tutorial/gags/inventory_10dollarbill.png"),
	preload("res://assets/gui/tutorial/gags/inventory_hypno_goggles.png"),
	preload("res://assets/gui/tutorial/gags/inventory_screen.png"),
	preload("res://assets/gui/tutorial/gags/inventory_bikehorn.png"),
	preload("res://assets/gui/tutorial/gags/inventory_whistle.png"),
	preload("res://assets/gui/tutorial/gags/inventory_bugle.png"),
	preload("res://assets/gui/tutorial/gags/inventory_aoogah.png"),
	preload("res://assets/gui/tutorial/gags/inventory_elephant.png"),
	preload("res://assets/gui/tutorial/gags/inventory_fog_horn.png"),
	preload("res://assets/gui/tutorial/gags/inventory_opera_singer.png"),
	preload("res://assets/gui/tutorial/gags/inventory_tart.png"),
	preload("res://assets/gui/tutorial/gags/inventory_fruit_pie_slice.png"),
	preload("res://assets/gui/tutorial/gags/inventory_cream_pie_slice.png"),
	preload("res://assets/gui/tutorial/gags/inventory_fruitpie.png"),
	preload("res://assets/gui/tutorial/gags/inventory_creampie.png"),
	preload("res://assets/gui/tutorial/gags/inventory_cake.png"),
	preload("res://assets/gui/tutorial/gags/inventory_wedding.png"),
	preload("res://assets/gui/tutorial/gags/inventory_squirt_flower.png"),
	preload("res://assets/gui/tutorial/gags/inventory_glass_of_water.png"),
	preload("res://assets/gui/tutorial/gags/inventory_water_gun.png"),
	preload("res://assets/gui/tutorial/gags/inventory_seltzer_bottle.png"),
	preload("res://assets/gui/tutorial/gags/inventory_firehose.png"),
	preload("res://assets/gui/tutorial/gags/inventory_storm_cloud.png"),
	preload("res://assets/gui/tutorial/gags/inventory_geyser.png"),
	preload("res://assets/gui/tutorial/gags/inventory_flower_pot.png"),
	preload("res://assets/gui/tutorial/gags/inventory_sandbag.png"),
	preload("res://assets/gui/tutorial/gags/inventory_anvil.png"),
	preload("res://assets/gui/tutorial/gags/inventory_weight.png"),
	preload("res://assets/gui/tutorial/gags/inventory_safe_box.png"),
	preload("res://assets/gui/tutorial/gags/inventory_piano.png"),
	preload("res://assets/gui/tutorial/gags/inventory_ship.png"),
]
# Centers of the seven wells on InventoryRow, measured from the original card.
const _SLOT_CENTER: PackedFloat32Array = [0.2679, 0.3770, 0.4861, 0.5933, 0.7044, 0.8115, 0.9226]
const _TAB_OPTIONS := preload("res://assets/gui/tutorial/book/tab_options.png")
const _TAB_MAP := preload("res://assets/gui/tutorial/book/tab_map.png")
const _TAB_GAGS := preload("res://assets/gui/tutorial/book/tab_gags.png")
const _TAB_TASKS := preload("res://assets/gui/tutorial/book/tab_tasks.png")
const _TAB_GEAR := preload("res://assets/gui/shticker/gallery/tab_gear.png")
const _KEYS := preload("res://scenes/shticker/keybinds.gd")
const _LINKS := preload("res://scenes/places/tunnel_links.gd")
const _PLACES := preload("res://scenes/places/hood_places.gd")
const _TITLE_CARD := preload("res://scenes/places/zone_title.gd")
const _ARRIVAL := preload("res://scenes/playgrounds/playground_toon.gd")

const _HOODS: Array[int] = [
	1000, 2000, 3000, 4000, 5000, 6000, 8000, 9000, 10000, 11000, 12000, 13000,
]
const _HOOD_NAMES: PackedStringArray = [
	"Donald's Dock", "Toontown Central", "The Brrrgh", "Minnie's Melodyland",
	"Daisy Gardens", "Chip 'n Dale's Acorn Acres", "Goofy Speedway", "Donald's Dreamland",
	"Bossbot HQ", "Sellbot HQ", "Cashbot HQ", "Lawbot HQ",
]
# Fractions of the map picture. MapPage leaves the name blank until the pointer
# is over that playground.
const _HOOD_HIT: Array[Rect2] = [
	Rect2(0.78, 0.46, 0.18, 0.15),
	Rect2(0.36, 0.46, 0.28, 0.20),
	Rect2(0.55, 0.16, 0.32, 0.28),
	Rect2(0.36, 0.28, 0.24, 0.16),
	Rect2(0.16, 0.72, 0.26, 0.20),
	Rect2(0.46, 0.72, 0.26, 0.22),
	Rect2(0.02, 0.36, 0.24, 0.22),
	Rect2(0.24, 0.04, 0.30, 0.18),
	Rect2(0.78, 0.04, 0.18, 0.20),
	Rect2(0.02, 0.68, 0.16, 0.26),
	Rect2(0.02, 0.04, 0.22, 0.22),
	Rect2(0.78, 0.68, 0.18, 0.26),
]

var _tasks: ToonTasks
var _cogs: CogGallery
var _loadout: ToonLoadout
var _button: TextureButton
var _dim: ColorRect
var _cover: TextureRect
var _pages: Array[Control] = []
var _tabs: Array[Button] = []
var _tab_name: Label
var _next: TextureButton
var _prev: TextureButton
var _bind_buttons: Array[TextureButton] = []
var _bind_captions: Array[Label] = []
var _gag_rows: Array[TextureRect] = []
var _gag_names: Array[Label] = []
var _gag_slots: Array[Control] = []
var _gag_icons: Array[TextureRect] = []
var _gag_counts: Array[Label] = []
var _gag_meters: Array[ColorRect] = []
var _gag_fills: Array[ColorRect] = []
var _gag_exps: Array[Label] = []
var _detail: Label
var _totals: Label
var _beans: Label
var _gag_title: Label
var _trash: TextureButton
var _trash_caption: Label
var _deleting := false
const _QUEST_SLOT: Array[Vector2] = [
	Vector2(-0.45, 0.25),
	Vector2(-0.45, -0.35),
	Vector2(0.45, 0.25),
	Vector2(0.45, -0.35),
]
var _here: Label
var _go_home: TextureButton
var _go_back: TextureButton
var _switch_button: TextureButton
var _quit_button: TextureButton
var _audio_captions: Array[Label] = []
var _audio_toggles: Array[TextureButton] = []
var _audio_sliders: Array[HSlider] = []
var _exit_dialog: Control
var _exit_accept: Callable
var _map_picture: TextureRect
var _hood_labels: Array[Label] = []
var _hood_clouds: Array[TextureRect] = []
var _hood_hits: Array[Control] = []
var _page := 0
var _open := false
var _guided := false
var _open_armed := false
var _next_armed := false
var _close_armed := false
var _listen := ""
var _pulse: Tween
var _open_sound: AudioStreamPlayer
var _turn_sound: AudioStreamPlayer
var _close_sound: AudioStreamPlayer


func setup(tasks: ToonTasks, loadout: ToonLoadout) -> void:
	_tasks = tasks
	_loadout = loadout
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	_build_sounds()
	_build_button()
	_build_book()
	if _tasks != null and _tasks.book_ready():
		_button.visible = true
		call_deferred("_place_button")


func present_button() -> void:
	if _tasks != null:
		_tasks.grant_book()
	_guided = true
	_open_armed = false
	_close_armed = false
	_next_armed = false
	_lock_button(true)
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_button.visible = true
	_button.modulate = Color(1, 1, 1, 0)
	_button.scale = Vector2(1.64, 1.64)
	_button.pivot_offset = _button.size * 0.5
	var view := get_viewport_rect().size
	_button.position = view * 0.5 - _button.size * 0.5
	var home := _button_home()
	var fade := create_tween()
	fade.tween_property(_button, "modulate:a", 1.0, 0.5)
	fade.tween_interval(1.5)
	await fade.finished
	var fly := create_tween()
	fly.set_parallel(true)
	fly.tween_property(_button, "position", home, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	fly.tween_property(_button, "scale", Vector2.ONE, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await fly.finished
	_pulse = create_tween()
	_pulse.tween_property(_button, "scale", Vector2(1.12, 1.12), 0.35).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_button, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)
	_pulse.set_loops()


func arm_open() -> void:
	_open_armed = true
	_lock_button(false)


func arm_next() -> void:
	_next_armed = true
	_apply_arrows()


func arm_close() -> void:
	_close_armed = true
	_guided = true


func is_open() -> bool:
	return _open


func page() -> int:
	return _page


func button_center() -> Vector2:
	return _button.get_global_rect().get_center()


func turn_center() -> Vector2:
	return _next.get_global_rect().get_center()


func cover_rect() -> Rect2:
	return _cover.get_global_rect()


func let_clicks_through(on: bool) -> void:
	var filter := MOUSE_FILTER_IGNORE if on else MOUSE_FILTER_STOP
	if _dim != null:
		_dim.mouse_filter = filter
	if _cover != null:
		_cover.mouse_filter = filter


func toggle_hotkey() -> void:
	if _tasks == null or not _tasks.book_ready():
		return
	if _open:
		if _guided and not _close_armed:
			return
		_close()
		return
	if _guided and not _open_armed:
		return
	open_to_gags()


func open_to_gags() -> void:
	if _tasks == null or not _tasks.book_ready():
		return
	_guided = false
	_close_armed = true
	if not _open:
		_open_book()
	_set_page(PAGE_GAGS)


func _build_sounds() -> void:
	_open_sound = _sound("res://assets/gui/tutorial/book/GUI_stickerbook_open.mp3")
	_turn_sound = _sound("res://assets/gui/tutorial/book/GUI_stickerbook_turn.mp3")
	_close_sound = _sound("res://assets/gui/tutorial/book/GUI_stickerbook_delete.mp3")


func _sound(path: String) -> AudioStreamPlayer:
	var player := ToonAudio.effect_player()
	var stream := load(path) as AudioStream
	if stream != null:
		player.stream = stream
	add_child(player)
	return player


func _build_button() -> void:
	_button = TextureButton.new()
	_button.texture_normal = _CLOSED
	_button.texture_hover = _HOVER
	_button.texture_pressed = _OPEN_ICON
	_button.ignore_texture_size = true
	_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	# BookIcon_CLSD is 102 by 72. A shorter box stretches the cover.
	_button.custom_minimum_size = Vector2(102, 72)
	_button.size = Vector2(102, 72)
	_button.visible = false
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(_on_button)
	add_child(_button)


func _build_book() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.15, 0.4, 1.0)
	_dim.mouse_filter = MOUSE_FILTER_STOP
	_dim.visible = false
	_dim.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_dim)
	_cover = TextureRect.new()
	_cover.texture = _BOOK
	_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# big_book is a square card. image_scale (2, 1, 1.5) stretches it to 4:3.
	_cover.stretch_mode = TextureRect.STRETCH_SCALE
	_cover.mouse_filter = MOUSE_FILTER_STOP
	_cover.visible = false
	add_child(_cover)
	_pages.append(_build_options())
	_pages.append(_build_map())
	_pages.append(_build_gags())
	_pages.append(_build_tasks())
	_cogs = CogGallery.new()
	_cover.add_child(_cogs)
	_pages.append(_cogs)
	var icons: Array[Texture2D] = [_TAB_OPTIONS, _TAB_MAP, _TAB_GAGS, _TAB_TASKS, _TAB_GEAR]
	for index in _PAGE_NAMES.size():
		var tab := Button.new()
		tab.focus_mode = Control.FOCUS_NONE
		tab.icon = icons[index]
		tab.expand_icon = true
		tab.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab.add_theme_stylebox_override("normal", _tab_style(false))
		tab.add_theme_stylebox_override("hover", _tab_style(false))
		tab.add_theme_stylebox_override("pressed", _tab_style(true))
		tab.pressed.connect(_on_tab.bind(index))
		tab.mouse_entered.connect(_show_tab_name.bind(index))
		tab.mouse_exited.connect(_hide_tab_name)
		_cover.add_child(tab)
		_tabs.append(tab)
	_tab_name = Label.new()
	_tab_name.mouse_filter = MOUSE_FILTER_IGNORE
	_tab_name.visible = false
	ToonGui.style_label(_tab_name, Color.WHITE, 22, Color.BLACK, 4)
	add_child(_tab_name)
	_prev = _arrow(true)
	_next = _arrow(false)
	_prev.pressed.connect(_turn.bind(-1))
	_next.pressed.connect(_turn.bind(1))
	_cover.add_child(_prev)
	_cover.add_child(_next)


func _build_options() -> Control:
	var sheet := Control.new()
	sheet.mouse_filter = MOUSE_FILTER_IGNORE
	sheet.visible = false
	sheet.name = "Options"
	_cover.add_child(sheet)
	sheet.add_child(_title("Options"))
	for index in _KEYS.ACTIONS.size():
		var caption := Label.new()
		caption.text = _KEYS.LABELS[index]
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.mouse_filter = MOUSE_FILTER_IGNORE
		sheet.add_child(caption)
		var button := TextureButton.new()
		button.texture_normal = _PILL
		button.texture_hover = _PILL_HOVER
		button.texture_pressed = _PILL_DOWN
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_SCALE
		button.focus_mode = Control.FOCUS_NONE
		button.clip_contents = true
		button.pressed.connect(_on_bind.bind(_KEYS.ACTIONS[index]))
		var key_name := Label.new()
		key_name.mouse_filter = MOUSE_FILTER_IGNORE
		key_name.clip_text = true
		key_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key_name.set_anchors_preset(PRESET_FULL_RECT)
		button.add_child(key_name)
		sheet.add_child(button)
		_bind_captions.append(caption)
		_bind_buttons.append(button)
	_audio_row(sheet, "Music", true)
	_audio_row(sheet, "Sound Effects", false)
	# Switch Toon throws the portable hole and returns to Pick a Toon.
	# Quit Game writes the journal, then closes the window.
	_switch_button = _pill("Switch Toon")
	_switch_button.pressed.connect(_ask_switch)
	sheet.add_child(_switch_button)
	_quit_button = _pill("Quit Game")
	_quit_button.pressed.connect(_ask_quit)
	sheet.add_child(_quit_button)
	return sheet


func _audio_row(sheet: Control, title: String, music: bool) -> void:
	var caption := Label.new()
	caption.text = title
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = MOUSE_FILTER_IGNORE
	sheet.add_child(caption)
	var toggle := _pill("On")
	toggle.pressed.connect(_toggle_audio.bind(music))
	sheet.add_child(toggle)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.focus_mode = Control.FOCUS_NONE
	var level := ToonAudio.music_volume() if music else ToonAudio.sfx_volume()
	slider.set_value_no_signal(level * 100.0)
	slider.value_changed.connect(_on_audio_volume.bind(music))
	_style_slider(slider)
	sheet.add_child(slider)
	_audio_captions.append(caption)
	_audio_toggles.append(toggle)
	_audio_sliders.append(slider)


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


func _build_map() -> Control:
	var sheet := Control.new()
	sheet.mouse_filter = MOUSE_FILTER_IGNORE
	sheet.visible = false
	sheet.name = "Map"
	_cover.add_child(sheet)
	_map_picture = TextureRect.new()
	_map_picture.texture = _MAP
	_map_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_map_picture.mouse_filter = MOUSE_FILTER_IGNORE
	_map_picture.name = "Picture"
	sheet.add_child(_map_picture)
	var name_bg := StyleBoxFlat.new()
	name_bg.bg_color = Color(1, 1, 1, 0.4)
	name_bg.set_content_margin_all(4)
	for index in _HOODS.size():
		var cloud := TextureRect.new()
		cloud.texture = _CLOUD
		cloud.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cloud.stretch_mode = TextureRect.STRETCH_SCALE
		cloud.mouse_filter = MOUSE_FILTER_IGNORE
		cloud.visible = false
		_map_picture.add_child(cloud)
		_hood_clouds.append(cloud)
		var hit := Control.new()
		hit.mouse_filter = MOUSE_FILTER_STOP
		hit.mouse_entered.connect(_hover_hood.bind(index, true))
		hit.mouse_exited.connect(_hover_hood.bind(index, false))
		_map_picture.add_child(hit)
		_hood_hits.append(hit)
		var label := Label.new()
		label.text = _HOOD_NAMES[index]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.clip_text = true
		label.mouse_filter = MOUSE_FILTER_IGNORE
		label.visible = false
		label.add_theme_stylebox_override("normal", name_bg)
		_map_picture.add_child(label)
		_hood_labels.append(label)
	_here = Label.new()
	_here.name = "Here"
	_here.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_here.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_here.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_here.mouse_filter = MOUSE_FILTER_IGNORE
	sheet.add_child(_here)
	_go_home = _pill("Go Home")
	_go_home.pressed.connect(_travel.bind(16000))
	sheet.add_child(_go_home)
	_go_back = _pill("Back to Playground")
	_go_back.pressed.connect(_back_to_hood)
	sheet.add_child(_go_back)
	return sheet


func _build_gags() -> Control:
	var sheet := Control.new()
	sheet.mouse_filter = MOUSE_FILTER_IGNORE
	sheet.visible = false
	sheet.name = "Gags"
	_cover.add_child(sheet)
	_gag_title = _title("Gags")
	sheet.add_child(_gag_title)
	for track in ToonLoadout.TRACK_COUNT:
		var row := TextureRect.new()
		row.texture = _ROW
		row.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.stretch_mode = TextureRect.STRETCH_SCALE
		row.mouse_filter = MOUSE_FILTER_IGNORE
		row.modulate = ToonLoadout.TRACK_COLORS[track]
		sheet.add_child(row)
		_gag_rows.append(row)
		var name := Label.new()
		name.text = ToonLoadout.TRACK_NAMES[track].to_upper()
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.mouse_filter = MOUSE_FILTER_IGNORE
		name.clip_text = true
		sheet.add_child(name)
		_gag_names.append(name)
		var meter := ColorRect.new()
		meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meter.color = Color(0, 0, 0, 0.45)
		meter.visible = false
		sheet.add_child(meter)
		var fill := ColorRect.new()
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.color = ToonLoadout.TRACK_COLORS[track]
		fill.visible = false
		sheet.add_child(fill)
		var exp_label := Label.new()
		exp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		exp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		exp_label.visible = false
		sheet.add_child(exp_label)
		_gag_meters.append(meter)
		_gag_fills.append(fill)
		_gag_exps.append(exp_label)
		for level in ToonLoadout.LEVEL_COUNT:
			var slot := Control.new()
			slot.mouse_filter = MOUSE_FILTER_STOP
			slot.mouse_entered.connect(_on_gag.bind(track, level))
			slot.mouse_exited.connect(_clear_gag)
			slot.gui_input.connect(_click_gag.bind(track, level))
			sheet.add_child(slot)
			var icon := TextureRect.new()
			icon.texture = _GAG_ICON[track * ToonLoadout.LEVEL_COUNT + level]
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = MOUSE_FILTER_IGNORE
			icon.visible = false
			sheet.add_child(icon)
			var count := Label.new()
			count.mouse_filter = MOUSE_FILTER_IGNORE
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			count.clip_text = true
			count.visible = false
			sheet.add_child(count)
			_gag_slots.append(slot)
			_gag_icons.append(icon)
			_gag_counts.append(count)
	_detail = _cream_label()
	_detail.name = "Detail"
	_totals = _cream_label()
	_totals.name = "Totals"
	sheet.add_child(_panel_behind(_detail))
	sheet.add_child(_detail)
	sheet.add_child(_panel_behind(_totals))
	sheet.add_child(_totals)
	var jar := TextureRect.new()
	jar.texture = _JAR
	jar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	jar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	jar.mouse_filter = MOUSE_FILTER_IGNORE
	jar.name = "Jar"
	sheet.add_child(jar)
	_beans = Label.new()
	_beans.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_beans.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_beans.mouse_filter = MOUSE_FILTER_IGNORE
	_beans.text = "%d\n/ %d" % [_BEANS.pouch(), _BEANS.POUCH_MAX]
	sheet.add_child(_beans)
	_trash = TextureButton.new()
	_trash.name = "Trash"
	_trash.texture_normal = _TRASH_CLOSED
	_trash.texture_pressed = _TRASH_OPEN
	_trash.texture_hover = _TRASH_HOVER
	_trash.ignore_texture_size = true
	_trash.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_trash.pressed.connect(_toggle_delete)
	ToonGui.button_sounds(_trash)
	sheet.add_child(_trash)
	_trash_caption = Label.new()
	_trash_caption.text = "DELETE"
	_trash_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trash_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_trash_caption.mouse_filter = MOUSE_FILTER_IGNORE
	sheet.add_child(_trash_caption)
	return sheet


func _build_tasks() -> Control:
	var sheet := Control.new()
	sheet.mouse_filter = MOUSE_FILTER_IGNORE
	sheet.visible = false
	sheet.name = "Tasks"
	_cover.add_child(sheet)
	sheet.add_child(_title("ToonTasks"))
	return sheet


func _title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.name = "Title"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	return label


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
	caption.name = "Caption"
	caption.mouse_filter = MOUSE_FILTER_IGNORE
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.set_anchors_preset(PRESET_FULL_RECT)
	button.add_child(caption)
	return button


func _cream_label() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = MOUSE_FILTER_IGNORE
	return label


func _panel_behind(label: Label) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	panel.name = label.name
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1.0, 0.98, 0.82)
	box.border_color = Color(0.45, 0.32, 0.12)
	box.set_border_width_all(3)
	box.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", box)
	return panel


func _arrow(flip: bool) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _ARROW
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = Vector2(54, 54)
	button.size = Vector2(54, 54)
	button.focus_mode = Control.FOCUS_NONE
	button.pivot_offset = button.size * 0.5
	if flip:
		button.scale = Vector2(-1, 1)
	button.visible = false
	return button


func _tab_style(sunken: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.72, 0.68, 0.58) if sunken else Color(0.94, 0.91, 0.82)
	box.border_color = Color(0.42, 0.36, 0.24)
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = 2
	box.content_margin_right = 2
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box


func _on_button() -> void:
	if _open:
		if _guided and not _close_armed:
			return
		_close()
		return
	if _guided and not _open_armed:
		return
	_open_book()


func _on_tab(index: int) -> void:
	if _guided:
		return
	_set_page(index)


func _turn(step: int) -> void:
	if _guided and step > 0 and not _next_armed:
		return
	if _guided and step < 0:
		return
	_set_page(_page + step)


func _on_bind(action: String) -> void:
	if _guided:
		return
	_listen = action
	_refresh_binds()


func _input(event: InputEvent) -> void:
	if _exit_dialog != null:
		if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
			get_viewport().set_input_as_handled()
			var key := event as InputEventKey
			if event.is_action_pressed("ui_cancel") or key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE:
				_close_exit()
		return
	if _listen == "":
		return
	if event.is_action_pressed("ui_cancel"):
		_cancel_bind()
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var code := key.physical_keycode
	if code == KEY_NONE:
		code = key.keycode
	if code == KEY_ESCAPE or key.keycode == KEY_ESCAPE or key.key_label == KEY_ESCAPE:
		_cancel_bind()
		return
	get_viewport().set_input_as_handled()
	_KEYS.assign(_listen, code)
	_listen = ""
	_refresh_binds()


func _cancel_bind() -> void:
	get_viewport().set_input_as_handled()
	_listen = ""
	_refresh_binds()


func _open_book() -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_button.scale = Vector2.ONE
	_open = true
	_listen = ""
	_page = PAGE_MAP if _guided else PAGE_OPTIONS
	_next_armed = false
	var parent := get_parent()
	if parent != null:
		parent.move_child(self, parent.get_child_count() - 1)
		# The page covers the playground, including the toon's speech bubble.
		# SpeedChat stays in front so the log can still be used.
		var chat := parent.get_node_or_null("SpeedChat")
		if chat != null:
			parent.move_child(chat, parent.get_child_count() - 1)
	move_child(_button, get_child_count() - 1)
	_layout()
	_dim.visible = true
	_cover.visible = true
	_button.texture_normal = _OPEN_ICON
	_show_page(_page)
	_play(_open_sound)
	book_opened.emit()


func close() -> void:
	if _open:
		_close()


func _close() -> void:
	_set_deleting(false)
	_close_exit()
	_open = false
	_guided = false
	_listen = ""
	_next_armed = false
	_close_armed = false
	_dim.visible = false
	_cover.visible = false
	_tab_name.visible = false
	_button.texture_normal = _CLOSED
	_play(_close_sound)
	book_closed.emit()


func _set_page(index: int) -> void:
	var next_page := clampi(index, 0, _pages.size() - 1)
	if next_page == _page and _pages[next_page].visible:
		return
	if next_page != PAGE_GAGS:
		_set_deleting(false)
	_page = next_page
	_listen = ""
	_next_armed = false
	_show_page(_page)
	_play(_turn_sound)
	page_ready.emit(_page)


func _show_page(index: int) -> void:
	if index == PAGE_OPTIONS:
		_refresh_binds()
	elif index == PAGE_MAP:
		_refresh_map()
	elif index == PAGE_GAGS:
		_refresh_gags()
	elif index == PAGE_TASKS:
		_fill_tasks()
	elif index == PAGE_COGS:
		_cogs.refresh()
	for page_index in _pages.size():
		_pages[page_index].visible = page_index == index
	for tab_index in _tabs.size():
		var sunken := tab_index == index
		_tabs[tab_index].add_theme_stylebox_override("normal", _tab_style(sunken))
		_tabs[tab_index].mouse_filter = MOUSE_FILTER_IGNORE if _guided else MOUSE_FILTER_STOP
	_apply_arrows()


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


func refresh_jar() -> void:
	if _beans == null:
		return
	_beans.text = "%d\n/ %d" % [_BEANS.pouch(), _BEANS.POUCH_MAX]


func refresh_gags() -> void:
	if _gag_icons.is_empty():
		return
	_refresh_gags()


func _refresh_gags() -> void:
	refresh_jar()
	_clear_gag()
	var carried := 0
	var limit := ToonLoadout.CARRY
	if _loadout != null:
		carried = _loadout.gag_count()
		limit = _loadout.max_carry
	_totals.text = "Total gags\n%d / %d\n\nDamage Rate: 100%%" % [carried, limit]
	if _loadout == null:
		return
	for track in ToonLoadout.TRACK_COUNT:
		for level in ToonLoadout.LEVEL_COUNT:
			var slot_index := track * ToonLoadout.LEVEL_COUNT + level
			var owned := _loadout.unlocked(track, level)
			var icon := _gag_icons[slot_index]
			var count := _gag_counts[slot_index]
			icon.visible = owned
			count.visible = owned
			if owned:
				var held := _loadout.count_of(track, level)
				count.text = str(held)
				if _deleting and held > 0:
					icon.modulate = Color(1.0, 0.35, 0.35)
				elif _deleting:
					icon.modulate = Color(1, 1, 1, 0.35)
				else:
					icon.modulate = Color.WHITE
	for track in ToonLoadout.TRACK_COUNT:
		_paint_exp_bar(track)


func _paint_exp_bar(track: int) -> void:
	if track < 0 or track >= _gag_meters.size():
		return
	var owned := false
	if _loadout != null:
		for level in ToonLoadout.LEVEL_COUNT:
			if _loadout.unlocked(track, level):
				owned = true
				break
	_gag_meters[track].visible = owned
	_gag_fills[track].visible = owned
	_gag_exps[track].visible = owned
	if not owned or _loadout == null:
		return
	var exp := _loadout.experience_of(track)
	var next := maxi(_loadout.next_skill(track), 1)
	var meter := _gag_meters[track]
	var ratio := clampf(float(exp) / float(next), 0.0, 1.0)
	var fill := _gag_fills[track]
	fill.position = meter.position
	fill.size = Vector2(meter.size.x * ratio, meter.size.y)
	var label := _gag_exps[track]
	label.position = meter.position
	label.size = meter.size
	label.text = "%d/%d" % [exp, next]


func _on_gag(track: int, level: int) -> void:
	if _loadout == null or not _loadout.unlocked(track, level):
		_clear_gag()
		return
	if _deleting:
		if _loadout.count_of(track, level) <= 0:
			_detail.text = "Click on a gag to DELETE it."
		else:
			_detail.text = "%s\n\nClick to delete." % _loadout.gag_name(track, level)
		return
	var damage := ToonLoadout.gag_damage(track, level, _loadout.experience_of(track))
	var accuracy := ToonLoadout.accuracy_word(ToonLoadout.gag_accuracy(track, level))
	_detail.text = "%s\n\nDamage: %d\nAccuracy: %s\n%s" % [
		_loadout.gag_name(track, level),
		damage,
		accuracy,
		ToonLoadout.affects_label(track),
	]


func _clear_gag() -> void:
	if _detail == null:
		return
	_detail.text = "Click on a gag to DELETE it." if _deleting else ""


func _toggle_delete() -> void:
	_set_deleting(not _deleting)


## InventoryPage.enterDeleteMode. The book turns yellow, and one click
## throws away a single gag. Nothing is refunded.
func _set_deleting(on: bool) -> void:
	if _deleting == on:
		return
	_deleting = on
	if _cover != null:
		_cover.self_modulate = Color(1, 1, 0) if on else Color.WHITE
	if _gag_title != null:
		_gag_title.text = "DELETE GAGS" if on else "Gags"
	if _trash != null:
		_trash.texture_normal = _TRASH_OPEN if on else _TRASH_CLOSED
		_trash.texture_pressed = _TRASH_CLOSED if on else _TRASH_OPEN
	if _trash_caption != null:
		_trash_caption.text = "DONE" if on else "DELETE"
	if _gag_icons.is_empty():
		return
	_refresh_gags()


func _click_gag(event: InputEvent, track: int, level: int) -> void:
	if not _deleting or not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if _loadout == null or not _loadout.toss_gag(track, level):
		return
	get_viewport().set_input_as_handled()
	_refresh_gags()
	_on_gag(track, level)


func _refresh_map() -> void:
	var scene_path := ""
	var current := get_tree().current_scene
	if current != null:
		scene_path = current.scene_file_path
	var info := _TITLE_CARD.caption(scene_path)
	if info.is_empty():
		_here.text = "You are in: Toontown Central\nPlayground"
	else:
		var lines := String(info["text"]).split("\n")
		var place := ""
		if lines.size() > 1:
			place = lines[1]
		_here.text = "You are in: %s\n%s" % [lines[0], place]
	for index in _HOODS.size():
		var seen := _HOODS[index] == 2000 or (_tasks != null and _tasks.has_visited(_HOODS[index]))
		_hood_labels[index].visible = false
		_hood_labels[index].set_meta("seen", 1 if seen else 0)
		_hood_clouds[index].visible = not seen
		_hood_clouds[index].modulate = Color.WHITE
	var zone := _LINKS.zone_for_scene(scene_path)
	if zone == 0:
		zone = _PLACES.hood_for_scene(scene_path)
	var hood_id := _LINKS.hood_of(zone) if zone > 0 else 0
	var on_street := zone > 0 and zone != hood_id
	var at_home := _PLACES.is_estate(scene_path) or _PLACES.is_house(scene_path)
	var dest := hood_id
	if at_home and _tasks != null:
		dest = _tasks.return_hood()
	# MapPage shows Back to Playground everywhere except a playground itself.
	# The estate yard and the house are not playgrounds.
	_go_back.visible = not _guided and (on_street or (at_home and dest > 0))
	var back_caption := _go_back.get_child(0) as Label
	if dest >= 10000 and dest < 16000:
		back_caption.text = "Back to Cog Headquarters"
	else:
		back_caption.text = "Back to Playground"
	_go_home.visible = not _guided and _tasks != null and _tasks.in_playground and not at_home


func _fill_tasks() -> void:
	var sheet := _pages[PAGE_TASKS]
	for child in sheet.get_children():
		if child is QuestPoster:
			sheet.remove_child(child)
			child.queue_free()
	var cards: Array[Dictionary] = []
	if _tasks != null:
		cards = _tasks.entries()
	if cards.is_empty():
		var blank := QuestPoster.new()
		sheet.add_child(blank)
		blank.show_task({})
	else:
		for task in cards:
			var poster := QuestPoster.new()
			sheet.add_child(poster)
			poster.show_task(task)
	_layout_tasks(sheet.size)


func _back_to_hood() -> void:
	var scene_path := ""
	var current := get_tree().current_scene
	if current != null:
		scene_path = current.scene_file_path
	if _PLACES.is_estate(scene_path) or _PLACES.is_house(scene_path):
		if _tasks == null:
			return
		var dest := _tasks.return_hood()
		if dest == 0:
			return
		_travel(dest)
		return
	var zone := _LINKS.zone_for_scene(scene_path)
	if zone == 0:
		return
	_travel(_LINKS.hood_of(zone))


func _ask_switch() -> void:
	_ask_confirm("Switch toons?", _leave_for_chooser)


func _ask_quit() -> void:
	_ask_confirm("Quit the game?", _leave_game)


func _ask_confirm(message_text: String, action: Callable) -> void:
	if _guided or _exit_dialog != null:
		return
	_exit_accept = action
	var dialog := Control.new()
	dialog.name = "ExitConfirm"
	dialog.mouse_filter = MOUSE_FILTER_STOP
	dialog.set_anchors_preset(PRESET_FULL_RECT)
	_exit_dialog = dialog
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.mouse_filter = MOUSE_FILTER_STOP
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dialog.add_child(dim)
	var frame := TextureRect.new()
	frame.texture = _DIALOG
	frame.modulate = Color(1, 1, 0.75)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	dialog.add_child(frame)
	var message := Label.new()
	message.text = message_text
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.mouse_filter = MOUSE_FILTER_IGNORE
	dialog.add_child(message)
	dialog.add_child(_exit_choice(_OK_UP, _OK_DOWN, _OK_HOVER, "OK", _accept_exit))
	dialog.add_child(_exit_choice(_CANCEL_UP, _CANCEL_DOWN, _CANCEL_HOVER, "Cancel", _close_exit))
	add_child(dialog)
	move_child(dialog, get_child_count() - 1)
	_layout_exit()


func _exit_choice(up: Texture2D, down: Texture2D, hover: Texture2D, caption: String, action: Callable) -> Control:
	var box := Control.new()
	box.mouse_filter = MOUSE_FILTER_IGNORE
	var button := TextureButton.new()
	button.texture_normal = up
	button.texture_pressed = down
	button.texture_hover = hover
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	box.add_child(button)
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(label)
	return box


func _layout_exit() -> void:
	if _exit_dialog == null or not is_instance_valid(_exit_dialog):
		return
	var view := get_viewport_rect().size
	if view.y < 2.0:
		return
	_exit_dialog.position = Vector2.ZERO
	_exit_dialog.size = view
	var dim := _exit_dialog.get_child(0) as Control
	dim.position = Vector2.ZERO
	dim.size = view
	ToonGui.place(_exit_dialog.get_child(1), view, -0.0281, -0.0426, 1.4792, 1.3047)
	var message := _exit_dialog.get_child(2) as Label
	var px := maxi(int(round(0.07 * view.y * 0.5)), 1)
	ToonGui.style_label(message, Color(0.08, 0.08, 0.08), px, Color(0, 0, 0, 0), 0)
	ToonGui.place(message, view, 0.0, 0.08, 1.2, 0.22)
	_place_exit_choice(_exit_dialog.get_child(3), view, -0.2)
	_place_exit_choice(_exit_dialog.get_child(4), view, 0.2)


func _place_exit_choice(box: Node, view: Vector2, x: float) -> void:
	var host := box as Control
	host.position = Vector2.ZERO
	host.size = view
	var button := box.get_child(0) as Control
	var caption := box.get_child(1) as Label
	ToonGui.place(button, view, x, -0.4, 0.1125, 0.1125)
	var px := maxi(int(round(0.06 * view.y * 0.5)), 1)
	ToonGui.style_label(caption, Color(0, 0, 0), px, Color(0, 0, 0, 0), 0)
	ToonGui.place(caption, view, x, -0.5, 0.4, 0.1)


func _close_exit() -> void:
	_exit_accept = Callable()
	if _exit_dialog != null and is_instance_valid(_exit_dialog):
		_exit_dialog.queue_free()
	_exit_dialog = null


func _accept_exit() -> void:
	var action := _exit_accept
	_close_exit()
	if action.is_valid():
		action.call()


func _leave_for_chooser() -> void:
	var scene := get_tree().current_scene
	var arrival: Node = scene.get_node_or_null("PlaygroundToon") if scene != null else null
	if arrival != null and arrival.has_method("quit_to_chooser"):
		close()
		arrival.call("quit_to_chooser")
		return
	get_tree().change_scene_to_file(_PICK_SCENE)


func _leave_game() -> void:
	if _tasks != null and _tasks.in_playground:
		_tasks.save()
	if _loadout != null:
		_loadout.save()
	get_tree().quit()


func _travel(hood: int) -> void:
	if _guided:
		return
	var scene := get_tree().current_scene
	var arrival: Node = scene.get_node_or_null("PlaygroundToon") if scene != null else null
	if arrival != null and arrival.has_method("teleport_to_hood"):
		close()
		arrival.call("teleport_to_hood", hood)
		return
	_ARRIVAL.teleport_in = true
	if _tasks != null:
		_tasks.note_hood(hood)
	get_tree().change_scene_to_file(_PLACES.scene_for(hood))


func _show_tab_name(index: int) -> void:
	if _guided or not _open:
		return
	_tab_name.text = _PAGE_NAMES[index]
	_tab_name.visible = true
	var tab := _tabs[index]
	_tab_name.position = _cover.position + tab.position + Vector2(tab.size.x + 8.0, tab.size.y * 0.2)
	_tab_name.size = Vector2(180, tab.size.y)


func _hide_tab_name() -> void:
	_tab_name.visible = false


func _lock_button(locked: bool) -> void:
	if _button == null:
		return
	_button.mouse_filter = MOUSE_FILTER_IGNORE if locked else MOUSE_FILTER_STOP


func _apply_arrows() -> void:
	_prev.visible = _open and not _guided and _page > 0
	_next.visible = _open and _page < _pages.size() - 1 and (not _guided or _next_armed)


func _layout() -> void:
	var view := get_viewport_rect().size
	_place_button()
	# The open book is 2 by 1.5 aspect units, 75% of the screen tall, shifted up 0.1.
	var book_h := view.y * 0.75
	var book_w := book_h * (2.0 / 1.5)
	if book_w > view.x:
		book_w = view.x
		book_h = book_w * (1.5 / 2.0)
	var top := (view.y - book_h) * 0.5 - view.y * 0.05
	_cover.size = Vector2(book_w, book_h)
	_cover.position = Vector2((view.x - book_w) * 0.5, maxf(top, 0.0))
	# MapPage's map is the page footprint: 1.746 by 1.3095, just under the top of the book.
	var page_origin := _cover.size * Vector2(0.0635, 0.0118)
	var page_size := _cover.size * Vector2(0.873, 0.873)
	var title_px := maxi(int(page_size.y * 0.07), 18)
	var body_px := maxi(int(page_size.y * 0.038), 13)
	for sheet in _pages:
		sheet.position = page_origin
		sheet.size = page_size
		var title := sheet.get_node_or_null("Title") as Label
		if title:
			title.position = Vector2(0, 0)
			title.size = Vector2(page_size.x, float(title_px) + 8.0)
			ToonGui.style_label(title, Color(0.08, 0.08, 0.08), title_px, Color(0, 0, 0, 0), 0)
	_layout_options(page_size, body_px)
	_layout_map(page_size, body_px)
	_layout_gags(page_size, body_px)
	_layout_tasks(page_size)
	if _cogs != null:
		_cogs.layout(page_size)
	# pageTabFrame scale 1.25, each tab scale 0.06, frame ±0.575, step 0.07.
	var tab_size := Vector2(_cover.size.x * 0.043125, _cover.size.y * 0.0575)
	for tab_index in _tabs.size():
		var tab := _tabs[tab_index]
		var center := Vector2(_cover.size.x * 0.965, _cover.size.y * (0.1167 + float(tab_index) * 0.05833))
		tab.position = center - tab_size * 0.5
		tab.size = tab_size
	var arrow := _cover.size.x * 0.05
	_prev.size = Vector2(arrow, arrow)
	_next.size = Vector2(arrow, arrow)
	# The previous arrow is mirrored. Flip it around its center so it stays on the same spot.
	_prev.pivot_offset = _prev.size * 0.5
	var arrow_y := _cover.size.y * 0.9407 - arrow * 0.5
	_prev.position = Vector2(_cover.size.x * 0.081 - arrow * 0.5, arrow_y)
	_next.position = Vector2(_cover.size.x * 0.919 - arrow * 0.5, arrow_y)


func _layout_options(page_size: Vector2, body_px: int) -> void:
	var top := page_size.y * 0.13
	var row_h := minf(page_size.y * 0.062, 34.0)
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
	var audio_top := top + float(_bind_buttons.size()) * row_h + page_size.y * 0.03
	var audio_h := minf(page_size.y * 0.08, 40.0)
	for index in _audio_sliders.size():
		var y := audio_top + float(index) * audio_h
		var caption := _audio_captions[index]
		caption.position = Vector2(0, y)
		caption.size = Vector2(page_size.x * 0.34, audio_h)
		ToonGui.style_label(caption, Color(0.1, 0.1, 0.1), body_px, Color(0, 0, 0, 0), 0)
		var toggle := _audio_toggles[index]
		_place_pill(toggle, Vector2(page_size.x * 0.36, y + audio_h * 0.12), Vector2(page_size.x * 0.16, audio_h * 0.76), body_px)
		var slider := _audio_sliders[index]
		slider.position = Vector2(page_size.x * 0.54, y + audio_h * 0.22)
		slider.size = Vector2(page_size.x * 0.42, audio_h * 0.56)
	_paint_audio()
	_switch_button.visible = not _guided
	_quit_button.visible = not _guided
	_place_pill(_switch_button, Vector2(page_size.x * 0.04, page_size.y * 0.88), Vector2(page_size.x * 0.44, page_size.y * 0.09), body_px)
	_place_pill(_quit_button, Vector2(page_size.x * 0.52, page_size.y * 0.88), Vector2(page_size.x * 0.44, page_size.y * 0.09), body_px)
	_layout_exit()


func _layout_map(page_size: Vector2, body_px: int) -> void:
	var side := minf(page_size.x, page_size.y)
	_map_picture.position = Vector2((page_size.x - side) * 0.5, (page_size.y - side) * 0.5)
	_map_picture.size = Vector2(side, side)
	var map_size := _map_picture.size
	var name_px := maxi(int(map_size.y * 0.04), 12)
	for index in _HOOD_HIT.size():
		var spot := _HOOD_HIT[index]
		var rect := Rect2(spot.position * map_size, spot.size * map_size)
		var cloud := _hood_clouds[index]
		cloud.position = rect.position
		cloud.size = rect.size
		var hit := _hood_hits[index]
		hit.position = rect.position
		hit.size = rect.size
		var label := _hood_labels[index]
		label.position = rect.position
		label.size = rect.size
		ToonGui.style_label(label, Color(0, 0, 0, 1), name_px, Color(0, 0, 0, 0), 0)
	# MapPage parents these to the map, below the picture: the label at
	# (-0.43, 0, -0.726), Go Home at (0.15, 0, -0.74), Back at (0.55, 0, -0.74).
	var here_px := maxi(int(page_size.y * 0.046), 13)
	var here_size := _map_span(0.84, 0.15, page_size)
	_here.position = _map_footer(-0.43, -0.726, page_size) - here_size * 0.5
	_here.size = here_size
	ToonGui.style_label(_here, Color(0, 0, 0, 1), here_px, Color(0, 0, 0, 0), 0)
	var home_size := _map_span(0.425 * 0.66, 0.108333 * 1.1, page_size)
	_place_pill(_go_home, _map_footer(0.15, -0.74, page_size) - home_size * 0.5, home_size, maxi(int(page_size.y * 0.042), 12))
	var back_size := _map_span(0.425 * 1.3, 0.108333 * 1.1, page_size)
	_place_pill(_go_back, _map_footer(0.55, -0.74, page_size) - back_size * 0.5, back_size, maxi(int(page_size.y * 0.042), 12))


func _layout_gags(page_size: Vector2, body_px: int) -> void:
	var sheet := _pages[PAGE_GAGS]
	_gag_title.visible = false
	# InventoryNew book mode. Rows are 1.6667 by 0.1252, pitched 0.12, from z 0.52.
	# The page rect is the map, 1.746 by 1.3095, whose top is book z 0.73225.
	var row_w := page_size.x * (1.6667 / 1.746)
	var row_h := row_w * (0.1252 / 1.6667)
	var pitch := page_size.y * (0.12 / 1.3095)
	var row_x := (page_size.x - row_w) * 0.5
	var first_center := page_size.y * ((0.73225 - 0.52) / 1.3095)
	var name_px := mini(body_px, maxi(int(row_h * 0.38), 8))
	var count_px := maxi(int(row_h * 0.28), 8)
	for track in ToonLoadout.TRACK_COUNT:
		var row_y := first_center + float(track) * pitch - row_h * 0.5
		var row := _gag_rows[track]
		row.position = Vector2(row_x, row_y)
		row.size = Vector2(row_w, row_h)
		var name := _gag_names[track]
		name.position = Vector2(row_x + row_w * 0.02, row_y)
		name.size = Vector2(row_w * 0.17, row_h * 0.52)
		ToonGui.style_label(name, Color.WHITE, name_px, Color(0.08, 0.08, 0.12), 2)
		var meter := _gag_meters[track]
		meter.position = Vector2(row_x + row_w * 0.02, row_y + row_h * 0.58)
		meter.size = Vector2(row_w * 0.16, row_h * 0.32)
		_paint_exp_bar(track)
		ToonGui.style_label(_gag_exps[track], Color.WHITE, maxi(int(row_h * 0.22), 8), Color(0, 0, 0), 1)
		for level in ToonLoadout.LEVEL_COUNT:
			var index := track * ToonLoadout.LEVEL_COUNT + level
			var center := Vector2(row_x + _SLOT_CENTER[level] * row_w, row_y + row_h * 0.5)
			var well := row_w * 0.10
			var slot := _gag_slots[index]
			slot.position = center - Vector2(well, row_h * 0.84) * 0.5
			slot.size = Vector2(well, row_h * 0.84)
			var icon_size := well * 0.78
			var icon := _gag_icons[index]
			icon.position = center - Vector2(icon_size, icon_size) * 0.5
			icon.size = Vector2(icon_size, icon_size)
			var count := _gag_counts[index]
			count.position = center - Vector2(well, row_h * 0.84) * 0.5
			count.size = Vector2(well, row_h * 0.84) - Vector2(well * 0.06, row_h * 0.04)
			ToonGui.style_label(count, Color.WHITE, count_px, Color(0.05, 0.12, 0.28), 2)
	var footer_y := first_center + float(ToonLoadout.TRACK_COUNT - 1) * pitch + row_h * 0.5 + 4.0
	var box := Vector2(page_size.x * 0.24, maxf(page_size.y - footer_y - 4.0, row_h))
	_place_cream(sheet, _detail, Vector2(page_size.x * 0.02, footer_y), box, body_px)
	_place_cream(sheet, _totals, Vector2(page_size.x * 0.27, footer_y), box, body_px)
	var can := minf(box.y * 0.92, page_size.x * 0.14)
	_trash.position = Vector2(page_size.x * 0.53, footer_y + (box.y - can) * 0.5)
	_trash.size = Vector2(can, can)
	_trash_caption.position = _trash.position + Vector2(0.0, can * 0.62)
	_trash_caption.size = Vector2(can, can * 0.38)
	ToonGui.style_label(_trash_caption, Color.WHITE, maxi(int(can * 0.16), 10), Color(0, 0, 0), 2)
	var jar := sheet.get_node("Jar") as TextureRect
	jar.position = Vector2(page_size.x * 0.70, footer_y)
	jar.size = Vector2(box.y, box.y)
	_beans.position = jar.position
	_beans.size = jar.size
	ToonGui.style_title(_beans, Color(0.95, 0.88, 0.1), maxi(int(box.y * 0.22), 14))


func _layout_tasks(page_size: Vector2) -> void:
	var sheet := _pages[PAGE_TASKS]
	var title := sheet.get_node_or_null("Title") as Label
	if title != null:
		var title_px := maxi(int(_map_span(0.12, 0.12, page_size).y), 16)
		var title_h := float(title_px) * 1.3
		var title_at := _book_point(0.0, 0.6, page_size)
		title.position = Vector2(0.0, title_at.y - title_h * 0.5)
		title.size = Vector2(page_size.x, title_h)
		ToonGui.style_label(title, Color(0.08, 0.08, 0.08), title_px, Color(0, 0, 0, 0), 0)
	# QuestPage places each poster at scale 1.06. The card itself is 0.8 by 0.58.
	var card := _map_span(0.8 * 1.06, 0.58 * 1.06, page_size)
	var index := 0
	for child in sheet.get_children():
		var poster := child as QuestPoster
		if poster == null or index >= _QUEST_SLOT.size():
			continue
		var spot := _QUEST_SLOT[index]
		var center := _book_point(spot.x, spot.y, page_size)
		poster.position = center - card * 0.5
		poster.layout(card)
		index += 1


func _place_cream(sheet: Control, label: Label, at: Vector2, box: Vector2, body_px: int) -> void:
	label.position = at
	label.size = box
	ToonGui.style_label(label, Color(0.08, 0.12, 0.28), maxi(body_px - 1, 12), Color(0, 0, 0, 0), 0)
	for child in sheet.get_children():
		if child is Panel and child.name == label.name:
			child.position = at
			child.size = box


## A point in the book's own coordinates, in this page's pixels.
func _book_point(book_x: float, book_z: float, page_size: Vector2) -> Vector2:
	var fx := (book_x + 1.0) / 2.0
	var fy := (0.75 - book_z) / 1.5
	return Vector2((fx - 0.0635) / 0.873 * page_size.x, (fy - 0.0118) / 0.873 * page_size.y)


## A point on the map node, in the page's pixels. The map sits at z 0.0775, scale 0.97.
func _map_footer(local_x: float, local_z: float, page_size: Vector2) -> Vector2:
	var book_x := local_x * 0.97
	var book_z := 0.0775 + local_z * 0.97
	var fx := (book_x + 1.0) / 2.0
	var fy := (0.75 - book_z) / 1.5
	return Vector2((fx - 0.0635) / 0.873 * page_size.x, (fy - 0.0118) / 0.873 * page_size.y)


## Width and height in aspect units, turned into page pixels. The map picture is 1.746 by 1.3095.
func _map_span(aspect_w: float, aspect_h: float, page_size: Vector2) -> Vector2:
	return Vector2(aspect_w / 1.746 * page_size.x, aspect_h / 1.3095 * page_size.y)


func _place_pill(button: TextureButton, at: Vector2, box: Vector2, body_px: int) -> void:
	button.position = at
	button.size = box
	var caption := button.get_child(0) as Label
	ToonGui.style_label(caption, Color(0.12, 0.12, 0.14), maxi(body_px - 1, 12), Color(0, 0, 0, 0), 0)


func _notification(what: int) -> void:
	if what != NOTIFICATION_RESIZED or _button == null:
		return
	if _open:
		_layout()
	else:
		_place_button()


func _place_button() -> void:
	if not is_inside_tree():
		return
	var view := get_viewport_rect().size
	if view.x < 1.0:
		return
	_button.position = _button_home()


func _button_home() -> Vector2:
	var view := get_viewport_rect().size
	return Vector2(view.x - _button.size.x - 28.0, view.y - _button.size.y - 22.0)


func _play(player: AudioStreamPlayer) -> void:
	if player != null and player.stream != null:
		player.play()


func _hover_hood(index: int, inside: bool) -> void:
	var label := _hood_labels[index]
	label.visible = inside
	if inside:
		var seen := int(label.get_meta("seen", 0)) == 1
		label.add_theme_color_override("font_color", Color(0, 0, 0, 1 if seen else 0.65))
	var cloud := _hood_clouds[index]
	if cloud.visible:
		cloud.modulate = Color(1, 1, 1, 0.25 if inside else 1.0)
