class_name ShtickerBook
extends Control

## The Shticker Book from quest_assign_110: map, gags, and ToonTasks.
## Tutorial Tom walks the new toon through those pages once, then the book
## stays on the corner button.

signal book_opened
signal book_closed
signal page_ready(which: int)

const _BOOK := preload("res://assets/gui/tutorial/book/big_book.png")
const _CLOSED := preload("res://assets/gui/tutorial/book/BookIcon_CLSD.png")
const _OPEN_ICON := preload("res://assets/gui/tutorial/book/BookIcon_OPEN.png")
const _HOVER := preload("res://assets/gui/tutorial/book/BookIcon_RLVR.png")
const _ARROW := preload("res://assets/gui/tutorial/book/arrow_button.png")
const _MAP := preload("res://assets/gui/tutorial/book/toontown_map.png")
const _PAGE_NAMES: PackedStringArray = ["Map", "Gags", "ToonTasks"]

var _tasks: ToonTasks
var _loadout: ToonLoadout
var _button: TextureButton
var _dim: ColorRect
var _cover: TextureRect
var _pages: Array[Control] = []
var _tabs: Array[Button] = []
var _next: TextureButton
var _prev: TextureButton
var _gags: GagPanel
var _task_row: HBoxContainer
var _page := 0
var _open := false
var _guided := false
var _next_armed := false
var _close_armed := false
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
	if _tasks != null and _tasks.has_book:
		_button.visible = true
		call_deferred("_place_button")


func present_button() -> void:
	if _tasks != null:
		_tasks.grant_book()
	_guided = true
	_close_armed = false
	_next_armed = false
	_button.visible = true
	_button.scale = Vector2(0.2, 0.2)
	_button.pivot_offset = _button.size * 0.5
	var view := get_viewport_rect().size
	_button.position = view * 0.5 - _button.size * 0.5
	var home := _button_home()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_button, "position", home, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_button, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse = create_tween()
	_pulse.tween_interval(0.8)
	_pulse.tween_property(_button, "scale", Vector2(1.12, 1.12), 0.35).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_button, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)
	_pulse.set_loops()


func arm_next() -> void:
	_next_armed = true
	_apply_arrows()


func arm_close() -> void:
	_close_armed = true
	_guided = true


func page() -> int:
	return _page


func let_clicks_through(on: bool) -> void:
	# The open book covers the whole view. Dialogue beats still need a click
	# on the page, while the arrows and the corner button keep their own.
	var filter := MOUSE_FILTER_IGNORE if on else MOUSE_FILTER_STOP
	if _dim != null:
		_dim.mouse_filter = filter
	if _cover != null:
		_cover.mouse_filter = filter


func open_to_gags() -> void:
	if _tasks == null or not _tasks.has_book:
		return
	_guided = false
	_close_armed = true
	if not _open:
		_open_book()
	_set_page(1)


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
	_button.custom_minimum_size = Vector2(96, 72)
	_button.size = Vector2(96, 72)
	_button.visible = false
	_button.pressed.connect(_on_button)
	add_child(_button)


func _build_book() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.12, 0.28, 0.55)
	_dim.mouse_filter = MOUSE_FILTER_STOP
	_dim.visible = false
	_dim.set_anchors_preset(PRESET_FULL_RECT)
	_dim.offset_left = 0
	_dim.offset_top = 0
	_dim.offset_right = 0
	_dim.offset_bottom = 0
	add_child(_dim)
	_cover = TextureRect.new()
	_cover.texture = _BOOK
	_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cover.mouse_filter = MOUSE_FILTER_STOP
	_cover.visible = false
	add_child(_cover)
	_pages.append(_build_map())
	_pages.append(_build_gags())
	_pages.append(_build_tasks())
	for index in _PAGE_NAMES.size():
		var tab := Button.new()
		tab.text = _PAGE_NAMES[index]
		tab.focus_mode = FOCUS_NONE
		tab.pressed.connect(_on_tab.bind(index))
		_cover.add_child(tab)
		_tabs.append(tab)
	_prev = _arrow(true)
	_next = _arrow(false)
	_prev.pressed.connect(_turn.bind(-1))
	_next.pressed.connect(_turn.bind(1))
	_cover.add_child(_prev)
	_cover.add_child(_next)


func _build_map() -> Control:
	var sheet := Control.new()
	sheet.mouse_filter = MOUSE_FILTER_IGNORE
	sheet.visible = false
	_cover.add_child(sheet)
	var title := _title("Map")
	sheet.add_child(title)
	var picture := TextureRect.new()
	picture.texture = _MAP
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = MOUSE_FILTER_IGNORE
	picture.name = "Picture"
	sheet.add_child(picture)
	var here := Label.new()
	here.text = "You are here: Toontown Central"
	here.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	here.mouse_filter = MOUSE_FILTER_IGNORE
	here.name = "Here"
	ToonGui.style_label(here, Color(0.2, 0.28, 0.55), 18, Color(1, 1, 1, 0.8), 2)
	sheet.add_child(here)
	return sheet


func _build_gags() -> Control:
	var sheet := Control.new()
	sheet.mouse_filter = MOUSE_FILTER_IGNORE
	sheet.visible = false
	_cover.add_child(sheet)
	sheet.add_child(_title("Gags"))
	_gags = GagPanel.new()
	_gags.setup(_loadout)
	_gags.mouse_filter = MOUSE_FILTER_IGNORE
	sheet.add_child(_gags)
	return sheet


func _build_tasks() -> Control:
	var sheet := Control.new()
	sheet.mouse_filter = MOUSE_FILTER_IGNORE
	sheet.visible = false
	_cover.add_child(sheet)
	sheet.add_child(_title("ToonTasks"))
	_task_row = HBoxContainer.new()
	_task_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_task_row.add_theme_constant_override("separation", 18)
	_task_row.mouse_filter = MOUSE_FILTER_IGNORE
	sheet.add_child(_task_row)
	var empty := Label.new()
	empty.name = "Empty"
	empty.text = "You have no ToonTasks right now."
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.mouse_filter = MOUSE_FILTER_IGNORE
	ToonGui.style_label(empty, Color(0.25, 0.18, 0.1), 20, Color(0, 0, 0, 0), 0)
	sheet.add_child(empty)
	return sheet


func _title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.name = "Title"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	ToonGui.style_label(label, Color(0.55, 0.16, 0.12), 28, Color(1, 1, 1, 0.7), 2)
	return label


func _arrow(flip: bool) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _ARROW
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = Vector2(54, 54)
	button.size = Vector2(54, 54)
	if flip:
		button.scale = Vector2(-1, 1)
	button.visible = false
	return button


func _on_button() -> void:
	if _open:
		if _guided and not _close_armed:
			return
		_close()
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


func _open_book() -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_button.scale = Vector2.ONE
	_open = true
	_page = 0
	_next_armed = false
	move_child(_button, get_child_count() - 1)
	_layout()
	_dim.visible = true
	_cover.visible = true
	_button.texture_normal = _OPEN_ICON
	_show_page(0)
	_play(_open_sound)
	book_opened.emit()


func close() -> void:
	if _open:
		_close()


func _close() -> void:
	_open = false
	_guided = false
	_next_armed = false
	_close_armed = false
	_dim.visible = false
	_cover.visible = false
	_button.texture_normal = _CLOSED
	_play(_close_sound)
	book_closed.emit()


func _set_page(index: int) -> void:
	var next_page := clampi(index, 0, _pages.size() - 1)
	if next_page == _page and _pages[next_page].visible:
		return
	_page = next_page
	_next_armed = false
	_show_page(_page)
	_play(_turn_sound)
	page_ready.emit(_page)


func _show_page(index: int) -> void:
	if index == 1 and _gags != null:
		_gags.refresh()
	if index == 2:
		_fill_tasks()
	for page_index in _pages.size():
		_pages[page_index].visible = page_index == index
	for tab_index in _tabs.size():
		_tabs[tab_index].disabled = _guided or tab_index == index
		_tabs[tab_index].mouse_filter = MOUSE_FILTER_IGNORE if _guided else MOUSE_FILTER_STOP
	_apply_arrows()


func _apply_arrows() -> void:
	_prev.visible = _open and not _guided and _page > 0
	_next.visible = _open and _page < _pages.size() - 1 and (not _guided or _next_armed)


func _fill_tasks() -> void:
	for child in _task_row.get_children():
		child.queue_free()
	var cards: Array[Dictionary] = []
	if _tasks != null:
		cards = _tasks.entries()
	var empty := _pages[2].get_node("Empty") as Label
	empty.visible = cards.is_empty()
	_task_row.visible = not cards.is_empty()
	for task in cards:
		var poster := QuestPoster.new()
		poster.show_task(task)
		_task_row.add_child(poster)


func _layout() -> void:
	var view := get_viewport_rect().size
	_place_button()
	var side := minf(view.x * 0.72, view.y * 0.82)
	_cover.size = Vector2(side, side)
	_cover.position = (view - _cover.size) * 0.5
	var page_origin := _cover.size * Vector2(0.16, 0.14)
	var page_size := _cover.size * Vector2(0.68, 0.62)
	for sheet in _pages:
		sheet.position = page_origin
		sheet.size = page_size
		var title := sheet.get_node_or_null("Title") as Label
		if title:
			title.position = Vector2(0, 0)
			title.size = Vector2(page_size.x, 36)
		var picture := sheet.get_node_or_null("Picture") as TextureRect
		if picture:
			picture.position = Vector2(0, 40)
			picture.size = Vector2(page_size.x, page_size.y - 78)
		var here := sheet.get_node_or_null("Here") as Label
		if here:
			here.position = Vector2(0, page_size.y - 32)
			here.size = Vector2(page_size.x, 28)
	if _gags != null:
		var fit := minf((page_size.x - 8.0) / _gags.size.x, (page_size.y - 48.0) / _gags.size.y)
		_gags.scale = Vector2(fit, fit)
		var scaled := _gags.size * fit
		_gags.position = Vector2((page_size.x - scaled.x) * 0.5, 42)
	_task_row.position = Vector2(0, 48)
	_task_row.size = Vector2(page_size.x, page_size.y - 56)
	var empty_label := _pages[2].get_node_or_null("Empty") as Label
	if empty_label:
		empty_label.position = Vector2(0, page_size.y * 0.4)
		empty_label.size = Vector2(page_size.x, 32)
	for tab_index in _tabs.size():
		var tab := _tabs[tab_index]
		tab.position = Vector2(_cover.size.x * 0.8, _cover.size.y * (0.2 + tab_index * 0.12))
		tab.size = Vector2(_cover.size.x * 0.16, 32)
	_prev.position = Vector2(_cover.size.x * 0.12, _cover.size.y * 0.78)
	_next.position = Vector2(_cover.size.x * 0.82, _cover.size.y * 0.78)


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
