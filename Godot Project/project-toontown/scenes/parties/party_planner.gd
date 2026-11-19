extends Node

## PartyPlanner pages: Welcome, the grounds editor, guests, the day,
## the time, the invitation, then the farewell. The frame is the original
## partyPlannerGUI model (scale 0.85 at 0.05, 0.1). The clock is bought
## automatically and starts at grid (8, 7). As Soon As Possible is the
## next 5-minute mark, and a party lasts 30 minutes.

const _GUI := preload("res://scenes/toons/toon_gui.gd")
const _BEANS := preload("res://scenes/toons/jellybeans.gd")
const _HOLIDAYS := preload("res://scenes/shticker/calendar_holidays.gd")
const _COLS := 18
const _ROWS := 15
const _CELL := 20
const _MASK: PackedStringArray = [
	"000000111110000000",
	"000001111111000000",
	"000011111111100000",
	"011111111111110000",
	"011111111111111111",
	"111111111111111111",
	"111111111111111111",
	"111111111111111111",
	"111111111111111111",
	"011111111111111111",
	"001111111111111110",
	"000111111111111100",
	"000111111111111100",
	"000011111111111000",
	"000001111111111000",
]
const _WEEK: PackedStringArray = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const _MONTH: PackedStringArray = ["", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const _THEMES: PackedStringArray = ["Birthday", "Star", "Flower", "Racing", "ValenToons", "Victory", "Winter"]

var _page := "welcome"
var _items: Array = []
var _catalog: Array = []
var _catalog_index := -1
var _selected := -1
var _moving := false
var _ground_ok := false
var _trash_at := 0
var _public := true
var _asap := true
var _day_index := -1
var _day_origin := 0.0
var _clock: Dictionary = {}
var _tz := 0
var _theme := "Star"
var _friends: Array = []
var _invited: Array = []

const _FRAME_X := 0.05
const _FRAME_Z := 0.1
const _FRAME_S := 0.85
const _LAYOUT := "res://assets/parties/planner/layout.json"

var _layer: CanvasLayer
var _dim: ColorRect
var _panel: Control
var _title: Label
var _info: Label
var _back: TextureButton
var _next: TextureButton
var _send_label: Label
var _pages: Dictionary = {}
var _grid: Control
var _cells: Array = []
var _buy: TextureButton
var _buy_label: Label
var _cost: Label
var _beans_label: Label
var _guest_list: VBoxContainer
var _guest_buttons: Array = []
var _privacy: Label
var _public_button: TextureButton
var _private_button: TextureButton
var _date_list: VBoxContainer
var _date_buttons: Array = []
var _asap_button: TextureButton
var _time_label: Label
var _hour_label: Label
var _minute_label: Label
var _ampm_label: Label
var _invite_label: Label
var _theme_label: Label
var _name_label: Label
var _desc_label: Label
var _price_label: Label
var _icon: TextureRect
var _layout: Dictionary = {}
var _view := Vector2.ZERO
var _pins: Array = []
var _info_pin: Array = []
var _list_scroll := 0
var _offered_indices: Array = []
var _squares: Dictionary = {}


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_LAYOUT))
	if parsed is Dictionary:
		_layout = parsed
	_catalog = _make_catalog()
	_friends = FriendsBook.page(2)
	for _friend in _friends:
		_invited.append(false)
	_init_clock()
	var style := ToonRoster.selected_style()
	_theme = "Flower" if style.gender == "f" else "Star"
	_add_clock()
	_build()
	_show("welcome")


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_SIZE_CHANGED or _layer == null:
		return
	_view = get_viewport().get_visible_rect().size
	if _dim != null:
		_dim.size = _view
	if _panel != null:
		_panel.size = _view
	for id in _pages.keys():
		var page := _pages[id] as Control
		page.size = _view
	for raw in _pins:
		_apply_pin(raw as Array)
	_layout_grid()


func _init_clock() -> void:
	var local := Time.get_datetime_dict_from_system()
	var minute := int(local["minute"]) - (int(local["minute"]) % 15)
	_clock = {
		"year": int(local["year"]),
		"month": int(local["month"]),
		"day": int(local["day"]),
		"hour": int(local["hour"]),
		"minute": minute,
		"second": 0,
	}
	var now_i := int(Time.get_unix_time_from_system())
	var clean := {
		"year": int(local["year"]),
		"month": int(local["month"]),
		"day": int(local["day"]),
		"hour": int(local["hour"]),
		"minute": int(local["minute"]),
		"second": int(local["second"]),
	}
	_tz = int(Time.get_unix_time_from_datetime_dict(clean)) - now_i


func _build() -> void:
	_view = get_viewport().get_visible_rect().size
	_layer = CanvasLayer.new()
	_layer.layer = 30
	add_child(_layer)
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.28)
	_dim.size = _view
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_dim)
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.size = _view
	_layer.add_child(_panel)
	_picture(_panel, "background__background")
	_build_welcome()
	_build_editor()
	_build_guests()
	_build_date()
	_build_time()
	_build_invite()
	_build_farewell()
	_title = _caption(_panel, Color(0.35, 0.12, 0.08), HORIZONTAL_ALIGNMENT_CENTER)
	_title.set_meta("lines", 2)
	_pin_text(_title, "title_locator", 1.7, 0.18)
	_info = _caption(_panel, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_info.set_meta("edge", Color(0, 0, 0, 0.9))
	_info.set_meta("lines", 4)
	_info_pin = [_info, "box", -0.4, 0.64, -0.76, -0.46]
	_pins.append(_info_pin)
	_apply_pin(_info_pin)
	_back = _art(_panel, "background__buttons__bottomArrows_buttons__bottomPrevious_button__previousButton", _on_back)
	_next = _art(_panel, "background__buttons__bottomArrows_buttons__bottomNext_button__nextButton", _on_next)
	_art(_panel, "background__buttons__cancel_button__cancelButton", _finish)
	_paint_privacy()


func _k(tail: String) -> String:
	return "node__partyCreatorGUI_grp__" + tail


func _card(tail: String) -> Dictionary:
	return _layout["cards"][_k(tail)]


func _tex(tail: String) -> Texture2D:
	var card: Dictionary = _card(tail)
	return load(String(card["file"])) as Texture2D


func _ax(x: float) -> float:
	return _FRAME_X + x * _FRAME_S


func _az(z: float) -> float:
	return _FRAME_Z + z * _FRAME_S


func _apply_pin(pin: Array) -> void:
	var control := pin[0] as Control
	if control == null or not is_instance_valid(control):
		return
	var mode := String(pin[1])
	if mode == "card":
		var card: Dictionary = _card(String(pin[2]))
		var x0 := float(card["x0"])
		var x1 := float(card["x1"])
		var z0 := float(card["z0"])
		var z1 := float(card["z1"])
		_GUI.place(control, _view, _ax((x0 + x1) * 0.5), _az((z0 + z1) * 0.5), (x1 - x0) * _FRAME_S, (z1 - z0) * _FRAME_S)
	elif mode == "box":
		var bx0 := float(pin[2])
		var bx1 := float(pin[3])
		var bz0 := float(pin[4])
		var bz1 := float(pin[5])
		_GUI.place(control, _view, _ax((bx0 + bx1) * 0.5), _az((bz0 + bz1) * 0.5), (bx1 - bx0) * _FRAME_S, (bz1 - bz0) * _FRAME_S)
		_fit(control)
	else:
		var point: Dictionary = _layout["locators"][String(pin[2])]
		_GUI.place(control, _view, _ax(float(point["x"])), _az(float(point["z"])), float(pin[3]), float(pin[4]))
		_fit(control)
	if control == _grid:
		_layout_grid()


func _pin_card(control: Control, tail: String) -> void:
	var pin: Array = [control, "card", tail]
	_pins.append(pin)
	_apply_pin(pin)


func _pin_box(control: Control, x0: float, x1: float, z0: float, z1: float) -> void:
	var pin: Array = [control, "box", x0, x1, z0, z1]
	_pins.append(pin)
	_apply_pin(pin)


func _pin_text(control: Control, loc: String, width: float, height: float) -> void:
	var pin: Array = [control, "text", loc, width, height]
	_pins.append(pin)
	_apply_pin(pin)


func _fit(control: Control) -> void:
	var label := control as Label
	if label == null or not label.has_meta("ink"):
		return
	var ink: Color = label.get_meta("ink")
	var edge := Color(0, 0, 0, 0)
	if label.has_meta("edge"):
		edge = label.get_meta("edge")
	var lines := 1
	if label.has_meta("lines"):
		lines = maxi(int(label.get_meta("lines")), 1)
	var px := maxi(int(label.size.y / float(lines) * 0.72), 10)
	var outline := 0
	if edge.a > 0.0:
		outline = maxi(int(float(px) / 14.0), 1)
	_GUI.style_label(label, ink, px, edge, outline)


func _caption(parent: Node, ink: Color, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("ink", ink)
	parent.add_child(label)
	return label


func _picture(parent: Node, tail: String) -> TextureRect:
	var image := TextureRect.new()
	image.texture = _tex(tail)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	parent.add_child(image)
	_pin_card(image, tail)
	return image


func _art(parent: Node, stem: String, call: Callable) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _tex(stem + "_up")
	button.texture_pressed = _tex(stem + "_down")
	button.texture_hover = _tex(stem + "_rollover")
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(call)
	button.resized.connect(_fit_button.bind(button))
	_GUI.button_sounds(button)
	parent.add_child(button)
	_pin_card(button, stem + "_up")
	return button


func _fit_button(button: TextureButton) -> void:
	if button.get_child_count() == 0:
		return
	var label := button.get_child(0) as Label
	if label == null or not label.has_meta("ink"):
		return
	var ink: Color = label.get_meta("ink")
	var px := maxi(int(button.size.y * 0.32), 8)
	_GUI.style_label(label, ink, px, Color(0, 0, 0, 0.9), maxi(int(float(px) / 12.0), 1))


func _stamp(button: TextureButton, text: String, ink: Color) -> Label:
	var label := _caption(button, ink, HORIZONTAL_ALIGNMENT_CENTER)
	label.text = text
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fit_button(button)
	return label


func _flat(button: Button) -> void:
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("disabled", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", _GUI.font())
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.12, 0.08, 0.2))
	button.add_theme_color_override("font_hover_color", Color(0.05, 0.28, 0.6))
	button.add_theme_color_override("font_pressed_color", Color(0.05, 0.28, 0.6))


func _make_page(id: String) -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2.ZERO
	box.size = _view
	box.visible = false
	_panel.add_child(box)
	_pages[id] = box
	return box


func _move_info(x0: float, x1: float, z0: float, z1: float, lines: int) -> void:
	if _info_pin.is_empty():
		return
	_info.set_meta("lines", lines)
	_info_pin[1] = "box"
	_info_pin[2] = x0
	_info_pin[3] = x1
	_info_pin[4] = z0
	_info_pin[5] = z1
	_apply_pin(_info_pin)


func _build_welcome() -> void:
	var page := _make_page("welcome")
	_picture(page, "step_01__peteText_flat")


func _build_editor() -> void:
	var page := _make_page("editor")
	_picture(page, "step_05__activitiesDecorations_flat")
	_picture(page, "step_05__activitiesDecorations_flat1")
	_picture(page, "step_05__partyGrid_flat")
	_picture(page, "step_05__instructions_flat")
	_art(page, "step_05__buttons_grp__activities_buttons__activitiesButtonUp", _scroll_catalog.bind(-1))
	_art(page, "step_05__buttons_grp__activities_buttons__activitiesButtonDown", _scroll_catalog.bind(1))
	_buy = _art(page, "step_05__buttons_grp__add_button__add", _on_buy)
	_buy_label = _stamp(_buy, "BUY", Color.WHITE)
	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	page.add_child(_icon)
	_pin_text(_icon, "step_05_activitiesIcon_locator", 0.2, 0.2)
	_name_label = _caption(page, Color(0.1, 0.08, 0.2), HORIZONTAL_ALIGNMENT_CENTER)
	_pin_text(_name_label, "step_05_activitiesName_text_locator", 0.48, 0.08)
	_desc_label = _caption(page, Color(0.1, 0.08, 0.2), HORIZONTAL_ALIGNMENT_CENTER)
	_desc_label.set_meta("lines", 3)
	_pin_text(_desc_label, "step_05_activityDescription_text_locator", 0.5, 0.18)
	_price_label = _caption(page, Color(0.1, 0.08, 0.2), HORIZONTAL_ALIGNMENT_CENTER)
	_pin_text(_price_label, "step_05_activityPrice_text_locator", 0.36, 0.07)
	_cost = _caption(page, Color(0.15, 0.08, 0.05), HORIZONTAL_ALIGNMENT_CENTER)
	_pin_text(_cost, "step_05_totalPrice_locator", 0.55, 0.08)
	_beans_label = _caption(page, Color(0.95, 0.9, 0.15), HORIZONTAL_ALIGNMENT_RIGHT)
	_beans_label.set_meta("edge", Color(0, 0, 0, 0.9))
	_pin_box(_beans_label, -1.05, -0.45, 0.52, 0.66)
	var grounds := _caption(page, Color(0.85, 0.05, 0.05), HORIZONTAL_ALIGNMENT_CENTER)
	grounds.text = "PARTY GROUNDS MAP"
	grounds.set_meta("edge", Color(1, 1, 1, 0.8))
	_pin_text(grounds, "step_05_partyGrounds_text_locator", 0.7, 0.08)
	_grid = Control.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(_grid)
	_pin_box(_grid, -0.11, 0.55, -0.447, 0.289)
	for y in _ROWS:
		for x in _COLS:
			var cell := Button.new()
			_flat(cell)
			cell.pressed.connect(_on_cell.bind(x, y))
			var mark := TextureRect.new()
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			cell.add_child(mark)
			_grid.add_child(cell)
			_cells.append(cell)
	_layout_grid()
	var trash := Button.new()
	_flat(trash)
	trash.text = "Trash"
	trash.pressed.connect(_on_trash)
	page.add_child(trash)
	_pin_box(trash, -0.36, -0.12, -0.78, -0.52)


func _layout_grid() -> void:
	if _grid == null or _cells.is_empty():
		return
	var cell := Vector2(_grid.size.x / float(_COLS), _grid.size.y / float(_ROWS))
	if cell.x < 1.0 or cell.y < 1.0:
		return
	for y in _ROWS:
		for x in _COLS:
			var button := _cells[y * _COLS + x] as Button
			button.position = Vector2(cell.x * float(x), cell.y * float(y))
			button.size = cell


func _build_guests() -> void:
	var page := _make_page("guests")
	_picture(page, "step_04__guestListBackground_flat")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	_pin_box(scroll, -0.55, 0.55, -0.72, -0.02)
	_guest_list = VBoxContainer.new()
	_guest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_guest_list)
	for index in _friends.size():
		var friend: Dictionary = _friends[index]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var box := TextureButton.new()
		box.custom_minimum_size = Vector2(22, 22)
		box.ignore_texture_size = true
		box.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		box.focus_mode = Control.FOCUS_NONE
		box.pressed.connect(_toggle_guest.bind(index))
		_GUI.button_sounds(box)
		row.add_child(box)
		var who := _caption(row, Color(0.1, 0.08, 0.22), HORIZONTAL_ALIGNMENT_LEFT)
		who.text = FriendsBook.shown_name(friend)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.custom_minimum_size = Vector2(0, 24)
		_GUI.style_label(who, Color(0.1, 0.08, 0.22), 16, Color(0, 0, 0, 0), 0)
		_guest_list.add_child(row)
		_guest_buttons.append(box)
	_paint_guests()
	_art(page, "step_04__step_04_buttons__checkAll_button__checkAllButton", _set_guests.bind(true))
	_art(page, "step_04__step_04_buttons__uncheckAll_button__uncheckAllButton", _set_guests.bind(false))
	_public_button = _art(page, "step_04__step_04_buttons__public_button__publicButton", _set_public.bind(true))
	_public_button.texture_disabled = _tex("step_04__step_04_buttons__public_button__publicButton_inactive")
	_stamp(_public_button, "Public", Color.WHITE)
	_private_button = _art(page, "step_04__step_04_buttons__private_button__privateButton", _set_public.bind(false))
	_private_button.texture_disabled = _tex("step_04__step_04_buttons__private_button__privateButton_inactive")
	_stamp(_private_button, "Private", Color.WHITE)
	_privacy = _caption(page, Color(0.12, 0.08, 0.2), HORIZONTAL_ALIGNMENT_CENTER)
	_privacy.text = "This party will be:"
	_pin_text(_privacy, "step_04_partyWillBe_locator", 0.9, 0.08)


func _build_date() -> void:
	var page := _make_page("date")
	_picture(page, "step_02")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	_pin_box(scroll, -0.72, 0.68, -0.7, 0.28)
	_date_list = VBoxContainer.new()
	_date_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_date_list)
	var noon := _clock.duplicate()
	noon["hour"] = 12
	noon["minute"] = 0
	_day_origin = _local_to_unix(noon)
	for index in 28:
		var dict := _unix_to_local(int(_day_origin + float(index) * 86400.0))
		var button := Button.new()
		_flat(button)
		button.text = _format_date(dict)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_day.bind(index))
		_date_list.add_child(button)
		_date_buttons.append(button)
	_asap_button = _art(page, "step_06__send_button__send", _on_asap)
	_stamp(_asap_button, "As Soon As Possible", Color.WHITE)


func _build_time() -> void:
	var page := _make_page("time")
	_picture(page, "step_03__toontownTime_background")
	var town := _caption(page, Color(0.85, 0.05, 0.05), HORIZONTAL_ALIGNMENT_CENTER)
	town.text = "Toontown"
	town.set_meta("edge", Color(1, 1, 1, 0.75))
	_pin_text(town, "step_03_toontown_locator", 0.55, 0.1)
	var time_word := _caption(page, Color(0.85, 0.05, 0.05), HORIZONTAL_ALIGNMENT_CENTER)
	time_word.text = "Time"
	time_word.set_meta("edge", Color(1, 1, 1, 0.75))
	_pin_text(time_word, "step_03_time_locator", 0.4, 0.1)
	var colon := _caption(page, Color(0.1, 0.08, 0.2), HORIZONTAL_ALIGNMENT_CENTER)
	colon.text = ":"
	_pin_text(colon, "step_03_colon_locator", 0.08, 0.1)
	_hour_label = _caption(page, Color(0.1, 0.08, 0.2), HORIZONTAL_ALIGNMENT_CENTER)
	_pin_text(_hour_label, "step_03_hour_locator", 0.16, 0.12)
	_minute_label = _caption(page, Color(0.1, 0.08, 0.2), HORIZONTAL_ALIGNMENT_CENTER)
	_pin_text(_minute_label, "step_03_minute_locator", 0.16, 0.12)
	_ampm_label = _caption(page, Color(0.1, 0.08, 0.2), HORIZONTAL_ALIGNMENT_CENTER)
	_pin_text(_ampm_label, "step_03_ampm_locator", 0.18, 0.1)
	_art(page, "step_03__step_03_buttons__hour_buttons__hourButtonUp", _shift_clock.bind("Hour", 1))
	_art(page, "step_03__step_03_buttons__hour_buttons__hourButtonDown", _shift_clock.bind("Hour", -1))
	_art(page, "step_03__step_03_buttons__minute_buttons__minuteButtonUp", _shift_clock.bind("Minute", 15))
	_art(page, "step_03__step_03_buttons__minute_buttons__minuteButtonDown", _shift_clock.bind("Minute", -15))
	_art(page, "step_03__step_03_buttons__ampm_buttons__ampmButtonUp", _shift_hour.bind(12))
	_art(page, "step_03__step_03_buttons__ampm_buttons__ampmButtonDown", _shift_hour.bind(-12))
	_time_label = _caption(page, Color(0.1, 0.08, 0.2), HORIZONTAL_ALIGNMENT_CENTER)
	_time_label.set_meta("lines", 2)
	_pin_text(_time_label, "step_03_toontownTime_locator", 1.15, 0.16)


func _build_invite() -> void:
	var page := _make_page("invite")
	_picture(page, "step_06__invitationBackground")
	_art(page, "step_06__topArrows_buttons__topPrevious_button__previousButton", _cycle_theme.bind(-1))
	_art(page, "step_06__topArrows_buttons__topNext_button__nextButton", _cycle_theme.bind(1))
	_theme_label = _caption(page, Color(0.12, 0.08, 0.2), HORIZONTAL_ALIGNMENT_CENTER)
	_pin_text(_theme_label, "step_06_theme_locator", 0.8, 0.08)
	_invite_label = _caption(page, Color(0.1, 0.08, 0.22), HORIZONTAL_ALIGNMENT_CENTER)
	_invite_label.set_meta("lines", 6)
	_pin_box(_invite_label, -0.62, 0.62, -0.55, 0.12)
	var send := _art(page, "step_06__send_button__send", _on_next)
	_send_label = _stamp(send, "Send Invites", Color.WHITE)


func _build_farewell() -> void:
	var page := _make_page("farewell")
	_picture(page, "step_07__peteText_flat")
	var close := _art(page, "step_07__close_button__close", _finish)
	_stamp(close, "Close Planner", Color.WHITE)


func _icon_tail(item: Dictionary) -> String:
	var station := String(item.get("station", ""))
	if station == "cog":
		return "step_05__activity_squares__PartyCog_activity_5x5"
	if station == "jukebox":
		return "step_05__activity_squares__PartyJukebox_activity_1x1"
	if station == "cannon":
		return "step_05__activity_squares__PartyCannon_activity_1x1"
	if station == "trampoline":
		return "step_05__activity_squares__PartyTrampoline_activity_2x2"
	if station == "catch":
		return "step_05__activity_squares__PartyCatch_activity_5x5"
	if station == "dance":
		return "step_05__activity_squares__PartyDance_activity_3x3"
	if station == "tug":
		return "step_05__activity_squares__PartyTufOfWar_activity_4x4"
	if station == "fireworks":
		return "step_05__activity_squares__PartyFireworks_activity_2x4"
	if station == "clock":
		return "step_05__activity_squares__PartyClock_activity_1x1"
	if String(item.get("kind", "")) == "d" and int(item.get("w", 1)) >= 2:
		return "step_05__activity_squares__decoration_propStage_2x2"
	return "step_05__activity_squares__decoration_1x1"


func _square_for(item: Dictionary) -> Texture2D:
	var tail := _icon_tail(item)
	if not _squares.has(tail):
		_squares[tail] = _tex(tail)
	return _squares[tail] as Texture2D


func _scroll_catalog(step: int) -> void:
	_refresh_offered()
	if _offered_indices.is_empty():
		return
	var slot := _list_scroll
	if step != 0:
		slot = clampi(_list_scroll + step, 0, _offered_indices.size() - 1)
	_list_scroll = slot
	_select_catalog(int(_offered_indices[_list_scroll]))


func _refresh_offered() -> void:
	_offered_indices.clear()
	for index in _catalog.size():
		if _offered(_catalog[index]):
			_offered_indices.append(index)


func _cycle_theme(step: int) -> void:
	var index := _THEMES.find(_theme)
	if index < 0:
		index = 0
	_set_theme(_THEMES[posmod(index + step, _THEMES.size())])


func _show(page: String) -> void:
	_page = page
	for id in _pages.keys():
		(_pages[id] as Control).visible = id == page
	_title.text = "Toontown Party Planner"
	_back.visible = page != "welcome" and page != "farewell"
	_next.visible = page != "farewell" and page != "invite"
	_next.disabled = false
	_info.visible = true
	if page == "welcome":
		_move_info(-0.4, 0.64, -0.76, -0.46, 4)
		_info.text = "Hosting your own party is a lot of fun!\nStart planning with the arrows at the bottom!"
	elif page == "editor":
		_title.text = "Design Your Party\nPlace Activities and Decorations"
		_move_info(-1.02, 1.1, -1.25, -1.08, 2)
		_info.text = _theme_note()
		if _catalog_index < 0:
			_scroll_catalog(0)
		else:
			_paint_editor()
	elif page == "guests":
		_title.text = "Choose Your Guests"
		_move_info(-0.85, 0.85, 0.38, 0.5, 2)
		_paint_privacy()
	elif page == "date":
		_title.text = "Pick A Day For Your Party"
		_move_info(-0.7, 0.7, 0.4, 0.5, 2)
		_info.text = "As Soon As Possible uses the next 5-minute mark."
		_next.visible = _day_index >= 0
		_asap_button.visible = _day_index < 0
		_paint_days()
	elif page == "time":
		_title.text = "Pick A Time For Your Party"
		_info.visible = false
		_paint_time()
	elif page == "invite":
		_title.text = "Double Check Your Party" if _invitees().is_empty() else "Choose Invitations To Send"
		_info.visible = false
		_send_label.text = "Plan Party" if _invitees().is_empty() else "Send Invites"
		_paint_invite()
	elif page == "farewell":
		_title.text = "Congratulations!"
		_move_info(-0.4, 0.64, -0.76, -0.46, 4)
		if _invitees().is_empty():
			_info.text = "Your party has been created!\nThanks!"
		else:
			_info.text = "Your party has been created and your invitations sent out.\nThanks!"
	_fit(_title)


func _on_back() -> void:
	_ground_ok = false
	if _page == "editor":
		_show("welcome")
	elif _page == "guests":
		_show("editor")
	elif _page == "date":
		_show("editor" if _friends.is_empty() else "guests")
	elif _page == "time":
		_show("date")
	elif _page == "invite":
		_show("date" if _asap else "time")


func _on_next() -> void:
	if _page == "welcome":
		_show("editor")
	elif _page == "editor":
		if not _ground_ok:
			_ground_ok = true
			_info.text = "Are you done moving your Party Activities and Decorations around the Party Grounds Map?"
			return
		_ground_ok = false
		_show("date" if _friends.is_empty() else "guests")
	elif _page == "guests":
		_show("date")
	elif _page == "date":
		_asap = false
		_show("time")
	elif _page == "time":
		if _start_unix() <= Time.get_unix_time_from_system():
			_info.visible = true
			_move_info(-0.7, 0.7, -0.98, -0.82, 2)
			_info.text = "Please choose a time in the future."
			return
		_show("invite")
	elif _page == "invite":
		_send()


func _on_asap() -> void:
	_asap = true
	_day_index = -1
	_show("invite")


func _on_day(index: int) -> void:
	var dict := _unix_to_local(int(_day_origin + float(index) * 86400.0))
	_clock["year"] = int(dict["year"])
	_clock["month"] = int(dict["month"])
	_clock["day"] = int(dict["day"])
	_day_index = index
	_asap = false
	_paint_days()
	_next.visible = true
	_asap_button.visible = false


func _shift_clock(caption: String, amount: int) -> void:
	if caption == "Hour":
		_shift_hour(amount)
		return
	var minute := int(_clock["minute"]) + amount
	if minute > 59:
		minute = 0
	elif minute < 0:
		minute = 45
	_clock["minute"] = minute
	_paint_time()


func _shift_hour(amount: int) -> void:
	var hour := int(_clock["hour"]) + amount
	hour = hour % 24
	if hour < 0:
		hour += 24
	_clock["hour"] = hour
	_paint_time()


func _paint_time() -> void:
	var shown := _unix_to_local(int(_local_to_unix(_clock)))
	var hour := int(shown["hour"])
	var h12 := hour % 12
	if h12 == 0:
		h12 = 12
	_hour_label.text = str(h12)
	_minute_label.text = "%02d" % int(shown["minute"])
	_ampm_label.text = "am" if hour < 12 else "pm"
	_time_label.text = "%s\n%s" % [_format_date(shown), _format_time(shown)]
	if _page == "time":
		_info.visible = false


func _paint_days() -> void:
	for index in _date_buttons.size():
		var button := _date_buttons[index] as Button
		button.modulate = Color(1, 1, 0.55) if index == _day_index else Color.WHITE


func _toggle_guest(index: int) -> void:
	_invited[index] = not bool(_invited[index])
	_paint_guests()


func _paint_guests() -> void:
	var on_tex := _tex("step_04__step_04_buttons__inviteButtonChecked")
	var off_tex := _tex("step_04__step_04_buttons__inviteButtonUnchecked")
	for index in _guest_buttons.size():
		var button := _guest_buttons[index] as TextureButton
		var marked: bool = bool(_invited[index])
		button.texture_normal = on_tex if marked else off_tex


func _set_guests(on: bool) -> void:
	for index in _invited.size():
		_invited[index] = on
	_paint_guests()


func _set_public(on: bool) -> void:
	_public = on
	_paint_privacy()


func _paint_privacy() -> void:
	if _public_button != null:
		_public_button.disabled = _public
	if _private_button != null:
		_private_button.disabled = not _public
	if _info == null:
		return
	_info.text = "Any Toon can come!" if _public else "Only Invited Toons can come!"


func _set_theme(theme: String) -> void:
	_theme = theme
	_drop_unoffered()
	if _catalog_index >= 0 and _catalog_index < _catalog.size() and not _offered(_catalog[_catalog_index]):
		_catalog_index = -1
	_paint_invite()
	if _page == "editor":
		_info.text = _theme_note()
		if _catalog_index < 0:
			_scroll_catalog(0)
		else:
			_paint_editor()


func _paint_invite() -> void:
	var when := _unix_to_local(int(_start_unix()))
	var host := ToonRoster.selected_style().display_name()
	var privacy := "public" if _public else "private"
	var activities := _activity_sentence()
	var line := "I am hosting a %s party! %s!" if _invitees().is_empty() else "You are invited to my %s party! %s!"
	var when_line := "It will be on %s,\nat %s Toontown Time.\nToontastic!" if _invitees().is_empty() else "It will be on %s,\nat %s Toontown Time.\nHope you can make it!"
	var decor := _decor_sentence()
	_invite_label.text = "%s Party\n%s\n%s\n%s\nTotal Cost: %d beans" % [
		_possessive(host),
		line % [privacy, activities],
		when_line % [_format_date(when), _format_time(when)],
		decor,
		_total(),
	]
	var slot := _THEMES.find(_theme)
	if slot < 0:
		slot = 0
	_theme_label.text = "%s (%d/%d)" % [_theme, slot + 1, _THEMES.size()]


func _send() -> void:
	var guests: Array = _invitees()
	var result: Variant = get_parent().call("commit_party", _items, guests, _public, _start_unix(), _theme)
	var message := String(result)
	if message != "":
		_title.text = "Oops."
		_info.visible = true
		_move_info(-0.62, 0.62, -0.15, 0.12, 3)
		_info.text = message
		return
	_show("farewell")


func _finish() -> void:
	var host := get_parent()
	queue_free()
	if host != null and host.has_method("_close"):
		host.call("_close")


func _paint_editor() -> void:
	_paint_grid()
	_paint_list()
	_paint_buy()
	_cost.text = "Total Cost: %d beans" % _total()
	_beans_label.text = str(maxi(_beans() - _total(), 0))


func _paint_grid() -> void:
	for y in _ROWS:
		for x in _COLS:
			var button := _cells[y * _COLS + x] as Button
			var mark := button.get_child(0) as TextureRect
			var owner := _owner_at(x, y, -1)
			if not _open_cell(x, y):
				button.disabled = true
				button.modulate = Color(1, 1, 1, 0)
				mark.visible = false
				continue
			button.disabled = false
			if owner < 0:
				button.modulate = Color(1, 1, 1, 0)
				mark.visible = false
				continue
			mark.visible = true
			mark.texture = _square_for(_items[owner])
			button.modulate = Color(1, 1, 0.55) if owner == _selected else Color.WHITE


func _paint_list() -> void:
	_refresh_offered()
	var found := _offered_indices.find(_catalog_index)
	if found >= 0:
		_list_scroll = found
	if _catalog_index < 0 or _catalog_index >= _catalog.size():
		_name_label.text = ""
		_desc_label.text = ""
		_price_label.text = ""
		_icon.texture = null
		return
	var entry: Dictionary = _catalog[_catalog_index]
	var caption := String(entry["editor"])
	if _count(entry) >= int(entry["limit"]):
		caption += "\nSOLD OUT"
	_name_label.text = caption
	_desc_label.text = String(entry["desc"])
	_price_label.text = "%d beans" % int(entry["cost"])
	_icon.texture = _square_for(entry)


func _paint_buy() -> void:
	_buy.disabled = true
	_buy.modulate = Color(0.55, 0.55, 0.55)
	_buy_label.text = "BUY"
	if _catalog_index < 0:
		return
	var entry: Dictionary = _catalog[_catalog_index]
	if _count(entry) >= int(entry["limit"]):
		_buy_label.text = "SOLD OUT"
		return
	if _total() + int(entry["cost"]) > _beans():
		return
	_buy.disabled = false
	_buy.modulate = Color.WHITE


func _select_catalog(index: int) -> void:
	_catalog_index = index
	_moving = false
	_ground_ok = false
	var entry: Dictionary = _catalog[index]
	_info.text = "Click Buy or click the Party Grounds Map."
	_paint_editor()


func _on_buy() -> void:
	if _catalog_index < 0:
		return
	var entry: Dictionary = _catalog[_catalog_index]
	if not _can_buy(entry):
		_paint_buy()
		return
	var spot := _first_open(int(entry["w"]), int(entry["h"]))
	if spot.x < 0:
		_info.text = "There is no room to place that activity."
		return
	_put(entry, spot)


func _on_cell(x: int, y: int) -> void:
	if not _open_cell(x, y):
		return
	_ground_ok = false
	var owner := _owner_at(x, y, -1)
	if owner >= 0:
		_selected = owner
		_moving = true
		_info.text = "Click and Drag items to move them around the Party Grounds Map"
		_paint_editor()
		return
	if _moving and _selected >= 0:
		_move_to(x, y)
		return
	if _catalog_index < 0:
		_info.text = "Click on the Party Activity or Decoration you would like to purchase."
		return
	var entry: Dictionary = _catalog[_catalog_index]
	if not _can_buy(entry):
		_paint_buy()
		return
	if not _fits(x, y, int(entry["w"]), int(entry["h"]), -1):
		_info.text = "There is no room to place that activity."
		return
	_put(entry, Vector2i(x, y))


func _move_to(x: int, y: int) -> void:
	var item: Dictionary = _items[_selected]
	if not _fits(x, y, int(item["w"]), int(item["h"]), _selected):
		_info.text = "There is no room to place that activity."
		return
	item["x"] = x
	item["y"] = y
	_moving = false
	_info.text = "Click and Drag items to move them around the Party Grounds Map"
	_paint_editor()


func _on_trash() -> void:
	var now := Time.get_ticks_msec()
	if now - _trash_at < 500:
		_items.clear()
		_add_clock()
		_selected = 0
		_moving = false
		_trash_at = 0
		_ground_ok = false
		_info.text = "Click on the Party Activity or Decoration you would like to purchase."
		_paint_editor()
		return
	_trash_at = now
	_info.text = "Drag an Activity or Decoration here to remove it."
	if _selected < 0 or _selected >= _items.size():
		return
	var item: Dictionary = _items[_selected]
	if String(item.get("kind", "")) == "a" and int(item.get("id", -1)) == 7:
		return
	_items.remove_at(_selected)
	_selected = -1
	_moving = false
	_ground_ok = false
	_paint_editor()


func _put(entry: Dictionary, at: Vector2i) -> void:
	var item := entry.duplicate()
	item["x"] = at.x
	item["y"] = at.y
	_items.append(item)
	var note := _drop_conflicts(item)
	_selected = _items.size() - 1
	_moving = false
	_ground_ok = false
	if note != "":
		_info.text = note
	else:
		_info.text = "Click and Drag items to move them around the Party Grounds Map"
	_paint_editor()


func _drop_conflicts(added: Dictionary) -> String:
	if String(added.get("kind", "")) != "a":
		return ""
	var pairs := [[0, 8], [4, 9], [15, 16], [17, 18]]
	var id := int(added.get("id", -1))
	var note := ""
	for pair in pairs:
		var ids: Array = pair
		if not ids.has(id):
			continue
		var other: int = int(ids[0]) if int(ids[1]) == id else int(ids[1])
		var index := _items.size() - 2
		while index >= 0:
			var item: Dictionary = _items[index]
			if String(item.get("kind", "")) == "a" and int(item.get("id", -1)) == other:
				note = "%s removed since %s was added." % [String(item["editor"]), String(added["editor"])]
				_items.remove_at(index)
				if _selected > index:
					_selected -= 1
			index -= 1
	return note


func _can_buy(entry: Dictionary) -> bool:
	if _count(entry) >= int(entry["limit"]):
		_info.text = "SOLD OUT"
		return false
	if _total() + int(entry["cost"]) > _beans():
		_info.text = "You do not have enough jellybeans for that."
		return false
	return true


func _add_clock() -> void:
	for entry in _catalog:
		var card: Dictionary = entry
		if String(card.get("kind", "")) == "a" and int(card.get("id", -1)) == 7:
			var clock := card.duplicate()
			clock["x"] = 8
			clock["y"] = 7
			_items.append(clock)
			_selected = 0
			return


func _count(entry: Dictionary) -> int:
	var total := 0
	for item in _items:
		var row: Dictionary = item
		if String(row.get("kind", "")) == String(entry.get("kind", "")) and int(row.get("id", -1)) == int(entry.get("id", -2)):
			total += 1
	return total


func _total() -> int:
	var cost := 0
	for item in _items:
		cost += int((item as Dictionary).get("cost", 0))
	return cost


func _beans() -> int:
	return _BEANS.pouch() + _BEANS.bank()


func _first_open(w: int, h: int) -> Vector2i:
	for y in _ROWS:
		for x in _COLS:
			if _fits(x, y, w, h, -1):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _fits(cx: int, cy: int, w: int, h: int, ignore: int) -> bool:
	for cell in _covers(cx, cy, w, h):
		var spot := cell as Vector2i
		if not _open_cell(spot.x, spot.y):
			return false
		if _owner_at(spot.x, spot.y, ignore) >= 0:
			return false
	return true


func _covers(cx: int, cy: int, w: int, h: int) -> Array:
	var x_low := 1 if w % 2 == 0 else 0
	var y_extra := 0 if h % 2 == 0 else 1
	var cells: Array = []
	var y := cy - h / 2
	var y_end := cy + h / 2 + y_extra
	var x_start := cx - w / 2 + x_low
	var x_end := cx + w / 2 + 1
	while y < y_end:
		var x := x_start
		while x < x_end:
			cells.append(Vector2i(x, y))
			x += 1
		y += 1
	return cells


func _open_cell(x: int, y: int) -> bool:
	if y < 0 or y >= _MASK.size():
		return false
	var row := String(_MASK[y])
	if x < 0 or x >= row.length():
		return false
	return row.substr(x, 1) == "1"


func _owner_at(x: int, y: int, ignore: int) -> int:
	for index in _items.size():
		if index == ignore:
			continue
		var item: Dictionary = _items[index]
		for cell in _covers(int(item["x"]), int(item["y"]), int(item["w"]), int(item["h"])):
			var spot := cell as Vector2i
			if spot.x == x and spot.y == y:
				return index
	return -1


func _invitees() -> Array:
	var rows: Array = []
	for index in _friends.size():
		if index >= _invited.size() or not bool(_invited[index]):
			continue
		var friend: Dictionary = _friends[index]
		rows.append({
			"id": String(friend.get("id", "")),
			"name": FriendsBook.shown_name(friend),
		})
	return rows


func _activity_sentence() -> String:
	var bits: PackedStringArray = []
	for item in _items:
		var row: Dictionary = item
		if String(row.get("kind", "")) != "a":
			continue
		var text := String(row.get("invite", ""))
		if text != "" and not bits.has(text):
			bits.append(text)
	if bits.is_empty():
		return "It will have a Party Clock"
	if bits.size() == 1:
		return "It will have " + bits[0]
	var sentence := ""
	for index in bits.size():
		if index == 0:
			sentence = bits[index]
		elif index == bits.size() - 1:
			sentence += ", and " + bits[index]
		else:
			sentence += ", " + bits[index]
	return "It will have " + sentence


func _decor_sentence() -> String:
	var bits: PackedStringArray = []
	for item in _items:
		var row: Dictionary = item
		if String(row.get("kind", "")) != "d":
			continue
		var text := String(row.get("editor", ""))
		if text != "" and not bits.has(text):
			bits.append(text)
	if bits.is_empty():
		return ""
	var sentence := ""
	for text in bits:
		if sentence != "":
			sentence += ", "
		sentence += text
	return "Decorations: " + sentence


func _start_unix() -> float:
	if _asap:
		return _asap_unix()
	return _local_to_unix(_clock)


func _asap_unix() -> float:
	var now := Time.get_unix_time_from_system()
	var local := Time.get_datetime_dict_from_system()
	var remainder: int = int(local["minute"]) % 5
	var add_min := 5 if remainder == 0 else 5 - remainder
	return now - float(int(local["second"])) + float(add_min) * 60.0


func _local_to_unix(dict: Dictionary) -> float:
	return float(int(Time.get_unix_time_from_datetime_dict(dict)) - _tz)


func _unix_to_local(stamp: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(stamp + _tz)


func _format_date(dict: Dictionary) -> String:
	var weekday := int(dict.get("weekday", 0))
	var month := int(dict.get("month", 1))
	if weekday < 0 or weekday >= _WEEK.size():
		weekday = 0
	if month < 1 or month >= _MONTH.size():
		month = 1
	return "%s, %s %d, %d" % [_WEEK[weekday], _MONTH[month], int(dict.get("day", 1)), int(dict.get("year", 2000))]


func _format_time(dict: Dictionary) -> String:
	var hour := int(dict.get("hour", 0))
	var suffix := "am" if hour < 12 else "pm"
	var h12 := hour % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, int(dict.get("minute", 0)), suffix]


func _possessive(who: String) -> String:
	if who.ends_with("s") or who.ends_with("S"):
		return who + "'"
	return who + "'s"


func _make_catalog() -> Array:
	return [
		_act(10, "Cog-O-War", "Cog-O-War", "The team vs. team game of Cog splatting!", 300, 5, 5, 1, "cog"),
		_act(14, "Holiday Cog-O-War", "Holiday Cog-O-War", "The team vs. team game of Cog splattering!", 300, 5, 5, 1, "cog"),
		_act(0, "Jukebox - 20", "a 20 song Jukebox", "Listen to music with your own 20 song jukebox!", 50, 1, 1, 1, "jukebox"),
		_act(8, "Jukebox - 40", "a 40 song jukebox", "Listen to music with your own 40 song jukebox!", 100, 1, 1, 1, "jukebox"),
		_act(17, "Jukebox - 20", "a 20 song Valentoons Jukebox", "Nothing sets the mood like music!", 50, 1, 1, 1, "jukebox"),
		_act(18, "Jukebox - 40", "a 40 song Valentoons jukebox", "Nothing sets the mood like music!", 100, 1, 1, 1, "jukebox"),
		_act(1, "Cannons", "Party Cannons", "Fire yourself out of the cannons and into fun!", 50, 1, 1, 10, "cannon"),
		_act(2, "Trampoline", "Trampoline", "Collect jellybeans and bounce the highest!", 50, 2, 2, 8, "trampoline"),
		_act(19, "Trampoline", "ValenToons Trampoline", "Jump to your heart's content!", 50, 2, 2, 8, "trampoline"),
		_act(11, "Cog Trampoline", "Cog Trampoline", "Jump on a Cog's face!", 50, 2, 2, 8, "trampoline"),
		_act(13, "Holiday Trampoline", "Holiday Trampoline", "Jump if you love Winter Holidays!", 50, 2, 2, 8, "trampoline"),
		_act(3, "Party Catch", "Party Catch", "Catch fruit to win beans! Dodge those anvils!", 300, 5, 5, 1, "catch"),
		_act(12, "Present Catch", "Present Catch", "Catch presents to win beans! Dodge those anvils!", 300, 5, 5, 1, "catch"),
		_act(4, "Dance Floor - 10", "a 10 move Dance Floor", "Show off all 10 of your moves, toon style!", 100, 3, 3, 1, "dance"),
		_act(9, "Dance Floor - 20", "a 20 move Dance Floor", "Show off all 20 of your moves, toon style!", 200, 3, 3, 1, "dance"),
		_act(15, "Dance Floor - 10", "a 10 move ValenToons Dance Floor", "Get your ValenToon Groove On!", 100, 3, 3, 1, "dance"),
		_act(16, "Dance Floor - 20", "a 20 move ValenToons Dance Floor", "Get your ValenToon Groove On!", 200, 3, 3, 1, "dance"),
		_act(5, "Tug-of-War", "Party Tug-of-War", "Up to 4 on 4 toon tugging craziness!", 200, 4, 4, 1, "tug"),
		_act(6, "Fireworks", "Party Fireworks", "Launch your very own fireworks show!", 200, 4, 2, 1, "fireworks"),
		_act(7, "Party Clock", "a Party Clock", "Counts down the time left in your party.", 100, 1, 1, 1, "clock"),
		_decor(0, "Balloon Anvil", "Try to keep the fun from floating away!", 10),
		_decor(1, "Party Stage", "Balloons, stars, what else could you want?", 25),
		_decor(2, "Party Bow", "Wrap up the fun!", 10),
		_decor(3, "Cake", "Delicious.", 10),
		_decor(4, "Party Castle", "A Toon's home is his castle.", 25),
		_decor(5, "Gift Pile", "Gifts for every Toon!", 10),
		_decor(6, "Streamer Horn", "This horn is a hoot! Streamers!", 10),
		_decor(7, "Party Gate", "Multi-colored and crazy!", 25),
		_decor(8, "Noise Makers", "Tweeeeet!", 10),
		_decor(9, "Pinwheel", "Colorful twirling for everyone!", 10),
		_decor(10, "Gag Globe", "Gag and star globe designed by Olivea", 25),
		_decor(11, "Bean Banner", "A Jellybean banner designed by Cassidy", 25),
		_decor(12, "Gag Cake", "A Topsy Turvy gag cake designed by Felicia", 25),
		_decor(13, "Cupid's Heart", "Ready...Aim...\nValenToons!", 25),
		_decor(14, "Candy Hearts Banner", "Who doesn't love candy hearts?", 25),
		_decor(15, "Flying Heart", "This heart is getting carried away!", 25),
		_decor(16, "Victory Bandstand", "All our new friends are ready to dance!", 25, 2, 2),
		_decor(17, "Victory Banner", "Not just a normal banner!", 25),
		_decor(18, "Confetti Cannons", "BOOM! Confetti! Fun!", 25),
		_decor(19, "Cog & Doodle", "Ouch! That's gotta hurt.", 25),
		_decor(20, "Cog Flappy Man", "A Cog full of hot air, what a shock!", 25),
		_decor(21, "Cog Ice Cream", "A Cog looking his best.", 25),
		_decor(22, "CogCicle", "A Cog looking his holiday best.", 25),
		_decor(23, "Holiday Bandstand", "Everyone loves a Holiday Party!", 25, 2, 2),
		_decor(24, "Chilly Cog", "Ouch! That's gotta hurt.", 25),
		_decor(25, "Snowman", "So cool, he's hot!", 25),
		_decor(26, "SnowDoodle", "His only trick is being cold!", 25),
		_decor(27, "ValenToons Anvil", "We've got your heart on a string!", 10),
	]


func _act(id: int, editor: String, invite: String, desc: String, cost: int, w: int, h: int, limit: int, station: String) -> Dictionary:
	return {
		"kind": "a",
		"id": id,
		"editor": editor,
		"invite": invite,
		"desc": desc,
		"cost": cost,
		"w": w,
		"h": h,
		"limit": limit,
		"station": station,
	}


func _decor(id: int, editor: String, desc: String, cost: int, w: int = 1, h: int = 1) -> Dictionary:
	return {
		"kind": "d",
		"id": id,
		"editor": editor,
		"invite": "",
		"desc": desc,
		"cost": cost,
		"w": w,
		"h": h,
		"limit": 5,
		"station": "",
	}


func _season_flags() -> Dictionary:
	return {
		"winter": _theme == "Winter" or _HOLIDAYS.running(4) or _HOLIDAYS.running(121),
		"valentine": _theme == "ValenToons" or _HOLIDAYS.running(59),
		"victory": _theme == "Victory" or _HOLIDAYS.running(95),
	}


func _offered(entry: Dictionary) -> bool:
	var flags := _season_flags()
	var id := int(entry.get("id", -1))
	var winter: bool = bool(flags["winter"])
	var valentine: bool = bool(flags["valentine"])
	var victory: bool = bool(flags["victory"])
	if String(entry.get("kind", "")) == "a":
		if (not victory and id == 11) or (not winter and (id == 12 or id == 13 or id == 14)) or (not valentine and (id >= 15 and id <= 19)):
			return false
		if (victory and id == 2) or (winter and (id == 2 or id == 3 or id == 10)) or (valentine and (id == 0 or id == 2 or id == 4 or id == 8 or id == 9)):
			return false
		return true
	if (not victory and id >= 16 and id <= 21) or (not winter and id >= 22 and id <= 26) or (not valentine and (id == 13 or id == 14 or id == 15 or id == 27)):
		return false
	if (victory and id == 11) or (valentine and (id == 0 or id == 11)):
		return false
	return true


func _theme_note() -> String:
	var flags := _season_flags()
	var bits: PackedStringArray = []
	if bool(flags["winter"]):
		bits.append("Winter")
	if bool(flags["valentine"]):
		bits.append("ValenToons")
	if bool(flags["victory"]):
		bits.append("Victory")
	if bits.is_empty():
		return "Click on the Party Activity or Decoration you would like to purchase."
	return "Offering " + ", ".join(bits) + " party activities and decorations."


func _drop_unoffered() -> void:
	var index := _items.size() - 1
	while index >= 0:
		var item: Dictionary = _items[index]
		if not _offered(item):
			_items.remove_at(index)
		index -= 1
	_selected = 0 if not _items.is_empty() else -1
	_moving = false
