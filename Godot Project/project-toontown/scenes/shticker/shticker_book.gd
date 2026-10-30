class_name ShtickerBook
extends Control

## ShtikerBook. The corner button opens the book on a blue field, icon tabs
## sit down the right edge, and the pages are Options, the map, Gags, and
## ToonTasks. Harry's reward still opens on the map and turns to gags, then tasks.

signal book_opened
signal book_closed
signal page_ready(which: int)

const PAGE_OPTIONS := 0
const PAGE_MAP := 1
const PAGE_GAGS := 2
const PAGE_TASKS := 3
const _PAGE_NAMES: PackedStringArray = ["Options", "Map", "Gags", "ToonTasks"]
const _CARRY := 20
const _BEANS := preload("res://scenes/toons/jellybeans.gd")

const _BOOK := preload("res://assets/gui/tutorial/book/big_book.png")
const _CLOSED := preload("res://assets/gui/tutorial/book/BookIcon_CLSD.png")
const _OPEN_ICON := preload("res://assets/gui/tutorial/book/BookIcon_OPEN.png")
const _HOVER := preload("res://assets/gui/tutorial/book/BookIcon_RLVR.png")
const _ARROW := preload("res://assets/gui/tutorial/book/arrow_button.png")
const _MAP := preload("res://assets/gui/tutorial/book/toontown_map.png")
const _CLOUD := preload("res://assets/gui/tutorial/book/cloud.png")
const _JAR := preload("res://assets/gui/tutorial/book/jar.png")
const _PILL := preload("res://assets/toons/gui/QuitBtn_UP.png")
const _PILL_DOWN := preload("res://assets/toons/gui/QuitBtn_DN.png")
const _PILL_HOVER := preload("res://assets/toons/gui/QuitBtn_RLVR.png")
const _ROW := preload("res://assets/gui/tutorial/InventoryRow.png")
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

var _tasks: ToonTasks
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
var _detail: Label
var _totals: Label
var _beans: Label
var _task_row: HBoxContainer
var _here: Label
var _go_home: TextureButton
var _go_back: TextureButton
var _map_picture: TextureRect
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
	var player := AudioStreamPlayer.new()
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
	_cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cover.mouse_filter = MOUSE_FILTER_STOP
	_cover.visible = false
	add_child(_cover)
	_pages.append(_build_options())
	_pages.append(_build_map())
	_pages.append(_build_gags())
	_pages.append(_build_tasks())
	var icons: Array[Texture2D] = [_TAB_OPTIONS, _TAB_MAP, _TAB_GAGS, _TAB_TASKS]
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
	return sheet


func _build_map() -> Control:
	var sheet := Control.new()
	sheet.mouse_filter = MOUSE_FILTER_IGNORE
	sheet.visible = false
	sheet.name = "Map"
	_cover.add_child(sheet)
	_map_picture = TextureRect.new()
	_map_picture.texture = _MAP
	_map_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_map_picture.mouse_filter = MOUSE_FILTER_IGNORE
	_map_picture.name = "Picture"
	sheet.add_child(_map_picture)
	for index in _HOODS.size():
		var label := Label.new()
		label.text = _HOOD_NAMES[index]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = MOUSE_FILTER_IGNORE
		label.set_meta("hood", _HOODS[index])
		_map_picture.add_child(label)
		for spec in _clouds_for(index):
			var cloud := TextureRect.new()
			cloud.texture = _CLOUD
			cloud.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cloud.stretch_mode = TextureRect.STRETCH_SCALE
			cloud.mouse_filter = MOUSE_FILTER_IGNORE
			cloud.set_meta("hood", _HOODS[index])
			cloud.set_meta("spec", spec)
			_map_picture.add_child(cloud)
	_here = Label.new()
	_here.name = "Here"
	_here.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	sheet.add_child(_title("Gags"))
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
		for level in ToonLoadout.LEVEL_COUNT:
			var slot := Control.new()
			slot.mouse_filter = MOUSE_FILTER_STOP
			slot.mouse_entered.connect(_on_gag.bind(track, level))
			slot.mouse_exited.connect(_clear_gag)
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
	return sheet


func _build_tasks() -> Control:
	var sheet := Control.new()
	sheet.mouse_filter = MOUSE_FILTER_IGNORE
	sheet.visible = false
	sheet.name = "Tasks"
	_cover.add_child(sheet)
	sheet.add_child(_title("ToonTasks"))
	_task_row = HBoxContainer.new()
	_task_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_task_row.add_theme_constant_override("separation", 18)
	_task_row.mouse_filter = MOUSE_FILTER_IGNORE
	sheet.add_child(_task_row)
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
	if flip:
		button.scale = Vector2(-1, 1)
	button.visible = false
	return button


func _tab_style(sunken: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.72, 0.68, 0.58) if sunken else Color(0.94, 0.91, 0.82)
	box.border_color = Color(0.42, 0.36, 0.24)
	box.set_border_width_all(2)
	box.set_corner_radius_all(3)
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 4
	box.content_margin_bottom = 4
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


func _refresh_gags() -> void:
	refresh_jar()
	_clear_gag()
	var carried := 0
	if _loadout != null:
		carried = _loadout.gag_count()
	_totals.text = "Total gags\n%d / %d\n\nDamage Rate: 100%%" % [carried, _CARRY]
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
				count.text = str(_loadout.count_of(track, level))


func _on_gag(track: int, level: int) -> void:
	if _loadout == null or not _loadout.unlocked(track, level):
		_detail.text = ""
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
	if _detail != null:
		_detail.text = ""


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
	for child in _map_picture.get_children():
		var hood := int(child.get_meta("hood", 0))
		var seen := hood == 2000 or (_tasks != null and _tasks.has_visited(hood))
		if child is Label:
			child.visible = seen
		else:
			child.visible = not seen
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
	for child in _task_row.get_children():
		child.queue_free()
	var cards: Array[Dictionary] = []
	if _tasks != null:
		cards = _tasks.entries()
	if cards.is_empty():
		var blank := QuestPoster.new()
		blank.show_task({})
		_task_row.add_child(blank)
		return
	for task in cards:
		var poster := QuestPoster.new()
		poster.show_task(task)
		_task_row.add_child(poster)


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
	var side := minf(view.x * 0.78, view.y * 0.9)
	_cover.size = Vector2(side * 1.15, side)
	_cover.position = (view - _cover.size) * 0.5
	var page_origin := _cover.size * Vector2(0.12, 0.1)
	var page_size := _cover.size * Vector2(0.7, 0.76)
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
	for tab_index in _tabs.size():
		var tab := _tabs[tab_index]
		tab.position = Vector2(_cover.size.x * 0.855, _cover.size.y * (0.16 + float(tab_index) * 0.09))
		tab.size = Vector2(_cover.size.y * 0.075, _cover.size.y * 0.075)
	var arrow := _cover.size.y * 0.07
	_prev.size = Vector2(arrow, arrow)
	_next.size = Vector2(arrow, arrow)
	_prev.position = Vector2(_cover.size.x * 0.08, _cover.size.y * 0.86)
	_next.position = Vector2(_cover.size.x * 0.86, _cover.size.y * 0.86)


func _layout_options(page_size: Vector2, body_px: int) -> void:
	var top := page_size.y * 0.16
	var row_h := minf(page_size.y * 0.09, 46.0)
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


func _layout_map(page_size: Vector2, body_px: int) -> void:
	_map_picture.position = Vector2(0, 0)
	_map_picture.size = Vector2(page_size.x, page_size.y * 0.82)
	var map_size := _map_picture.size
	for child in _map_picture.get_children():
		if child is Label:
			var at := _label_at(int(child.get_meta("hood")))
			var center := _map_point(at.x, at.y, map_size)
			child.position = center - Vector2(map_size.x * 0.12, 16)
			child.size = Vector2(map_size.x * 0.24, 36)
			ToonGui.style_label(child as Label, Color(0.05, 0.05, 0.05), maxi(body_px - 2, 11), Color(1, 1, 1, 0.65), 2)
		elif child is TextureRect:
			var spec: Vector4 = child.get_meta("spec")
			var center := _map_point(spec.x, spec.y, map_size)
			var cloud_size := Vector2(absf(spec.z) / 1.8 * map_size.x, absf(spec.w) / 1.35 * map_size.y)
			child.position = center - cloud_size * 0.5
			child.size = cloud_size
			var cloud := child as Control
			cloud.pivot_offset = cloud_size * 0.5
			cloud.scale = Vector2(-1.0 if spec.z < 0.0 else 1.0, 1.0)
	_here.position = Vector2(0, page_size.y * 0.84)
	_here.size = Vector2(page_size.x * 0.42, page_size.y * 0.14)
	ToonGui.style_label(_here, Color(0.08, 0.08, 0.08), body_px, Color(0, 0, 0, 0), 0)
	_place_pill(_go_home, Vector2(page_size.x * 0.46, page_size.y * 0.86), Vector2(page_size.x * 0.2, page_size.y * 0.08), body_px)
	_place_pill(_go_back, Vector2(page_size.x * 0.68, page_size.y * 0.86), Vector2(page_size.x * 0.3, page_size.y * 0.08), body_px)


func _layout_gags(page_size: Vector2, body_px: int) -> void:
	var sheet := _pages[PAGE_GAGS]
	var top := page_size.y * 0.105
	var footer_h := page_size.y * 0.24
	var band := page_size.y - top - footer_h
	var gap := maxf(band * 0.015, 2.0)
	var row_h := (band - gap * float(ToonLoadout.TRACK_COUNT - 1)) / float(ToonLoadout.TRACK_COUNT)
	var row_w := row_h * (252.0 / 28.0)
	if row_w > page_size.x:
		row_w = page_size.x
		row_h = row_w * (28.0 / 252.0)
	var row_x := (page_size.x - row_w) * 0.5
	var name_px := mini(body_px, maxi(int(row_h * 0.42), 10))
	var count_px := maxi(int(row_h * 0.30), 9)
	for track in ToonLoadout.TRACK_COUNT:
		var row_y := top + float(track) * (row_h + gap)
		var row := _gag_rows[track]
		row.position = Vector2(row_x, row_y)
		row.size = Vector2(row_w, row_h)
		var name := _gag_names[track]
		name.position = Vector2(row_x + row_w * 0.025, row_y)
		name.size = Vector2(row_w * 0.185, row_h)
		ToonGui.style_label(name, Color.WHITE, name_px, Color(0.08, 0.08, 0.12), 2)
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
	var footer_y := top + band
	var box := Vector2(page_size.x * 0.28, page_size.y - footer_y - 6.0)
	_place_cream(sheet, _detail, Vector2(page_size.x * 0.08, footer_y), box, body_px)
	_place_cream(sheet, _totals, Vector2(page_size.x * 0.4, footer_y), box, body_px)
	var jar := sheet.get_node("Jar") as TextureRect
	jar.position = Vector2(page_size.x * 0.72, footer_y)
	jar.size = Vector2(box.y, box.y)
	_beans.position = jar.position
	_beans.size = jar.size
	ToonGui.style_title(_beans, Color(0.95, 0.88, 0.1), maxi(int(box.y * 0.22), 14))


func _layout_tasks(page_size: Vector2) -> void:
	_task_row.position = Vector2(0, page_size.y * 0.16)
	_task_row.size = Vector2(page_size.x * 0.48, page_size.y * 0.7)


func _place_cream(sheet: Control, label: Label, at: Vector2, box: Vector2, body_px: int) -> void:
	label.position = at
	label.size = box
	ToonGui.style_label(label, Color(0.08, 0.12, 0.28), maxi(body_px - 1, 12), Color(0, 0, 0, 0), 0)
	for child in sheet.get_children():
		if child is Panel and child.name == label.name:
			child.position = at
			child.size = box


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


func _map_point(local_x: float, local_z: float, map_size: Vector2) -> Vector2:
	return Vector2((local_x + 0.9) / 1.8 * map_size.x, (0.675 - local_z) / 1.35 * map_size.y)


func _label_at(hood: int) -> Vector2:
	match hood:
		1000:
			return Vector2(0.594, -0.075)
		2000:
			return Vector2(0.0, -0.1)
		3000:
			return Vector2(0.475, 0.25)
		4000:
			return Vector2(0.1, 0.15)
		5000:
			return Vector2(-0.3, -0.375)
		6000:
			return Vector2(0.2, -0.45)
		8000:
			return Vector2(-0.55, 0.0)
		9000:
			return Vector2(-0.088, 0.47)
		10000:
			return Vector2(0.7, -0.5)
		11000:
			return Vector2(-0.7, -0.5)
		12000:
			return Vector2(-0.7, 0.5)
		_:
			return Vector2(0.7, 0.5)


func _clouds_for(index: int) -> Array[Vector4]:
	match index:
		0:
			return [Vector4(0.575, -0.04, 0.55, 0.4), Vector4(0.45, -0.25, 0.35, 0.25)]
		2:
			return [Vector4(0.375, 0.4, 0.45, 0.45), Vector4(0.5625, 0.2, 0.5, 0.4)]
		3:
			return [Vector4(-0.02, 0.23, 0.7, 0.45)]
		4:
			return [Vector4(-0.3, -0.4, 0.55, 0.4)]
		5:
			return [Vector4(0.25, -0.425, 0.6, 0.4), Vector4(0.125, -0.36, 0.5332, 0.32)]
		6:
			return [Vector4(-0.5625, -0.07, 0.7, 0.45), Vector4(-0.45, 0.2125, 0.7, 0.45)]
		7:
			return [Vector4(-0.125, 0.5, 0.7998, 0.39)]
		8:
			return [Vector4(0.66, -0.4, 0.5, 0.4)]
		9:
			return [Vector4(-0.68, -0.444, -0.45, 0.4)]
		10:
			return [Vector4(-0.6, 0.45, -0.45, 0.35)]
		11:
			return [Vector4(0.66, 0.5, 0.5, 0.35)]
		_:
			var none: Array[Vector4] = []
			return none
