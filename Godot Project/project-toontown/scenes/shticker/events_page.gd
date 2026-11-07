extends Control

## EventsPage. Calendar is the page that opens. Hosting and Invitations sit
## beside it. The news tab stays hidden, matching want-news-tab 0.
## phase_4/models/parties is not in the asset set, so the fishing-book tab
## the original page already uses is the tab art, and the grid is drawn
## from CalendarGuiMonth's locator spacing.

const _TAB := preload("res://assets/gui/shticker/fishing/page_tab.png")
const _MONTH_CARD := preload("res://assets/gui/shticker/events/tt_m_gui_sbk_calendar_month.png")
const _ARROW_UP := preload("res://assets/gui/shticker/events/tt_m_gui_sbk_calendar_month_arrowR_up.png")
const _ARROW_DOWN := preload("res://assets/gui/shticker/events/tt_m_gui_sbk_calendar_month_arrowR_down.png")
const _ARROW_HOVER := preload("res://assets/gui/shticker/events/tt_m_gui_sbk_calendar_month_arrowR_hover.png")
const _FILTER_CARD := preload("res://assets/gui/shticker/events/tt_m_gui_sbk_calendar_filter.png")
const _BOX_BLANK := preload("res://assets/gui/shticker/events/tt_m_gui_sbk_calendar_box_boxBlank.png")
const _BOX_TODAY := preload("res://assets/gui/shticker/events/tt_m_gui_sbk_calendar_box_boxToday.png")
const _BOX_HOVER := preload("res://assets/gui/shticker/events/tt_m_gui_sbk_calendar_box_boxHover.png")
const _SCROLL_UP := preload("res://assets/gui/shticker/events/tt_m_gui_sbk_calendar_box_downScroll_up.png")
const _SCROLL_DOWN := preload("res://assets/gui/shticker/events/tt_m_gui_sbk_calendar_box_downScroll_down.png")
const _SCROLL_HOVER := preload("res://assets/gui/shticker/events/tt_m_gui_sbk_calendar_box_downScroll_hover.png")
const _PILL := preload("res://assets/toons/gui/QuitBtn_UP.png")
const _PILL_DOWN := preload("res://assets/toons/gui/QuitBtn_DN.png")
const _PILL_HOVER := preload("res://assets/toons/gui/QuitBtn_RLVR.png")
const _HOLIDAYS := preload("res://scenes/shticker/calendar_holidays.gd")

const _HOST := 0
const _INVITED := 1
const _CALENDAR := 2
const _NORMAL := Color(1, 1, 1, 1)
const _CLICK := Color(0.8, 0.8, 0, 1)
const _ROLLOVER := Color(0.15, 0.82, 1, 1)
const _SELECTED := Color(1.0, 0.98, 0.15, 1)
const _INK := Color(0.2, 0.1, 0, 1)
const _MONTH_INK := Color(40.0 / 255.0, 140.0 / 255.0, 246.0 / 255.0)
const _YEAR_INK := Color(140.0 / 255.0, 140.0 / 255.0, 246.0 / 255.0)
const _WEEK_INK := Color(1.0, 146.0 / 255.0, 113.0 / 255.0)
const _DAY_INK := Color(110.0 / 255.0, 126.0 / 255.0, 1.0)
const _MONTHS: PackedStringArray = [
	"", "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
	"JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER",
]
const _WEEKDAYS: PackedStringArray = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
const _FILTERS: PackedStringArray = ["Show All", "Show Only Holidays", "Show Only Parties"]
const _DAYS_IN: PackedInt32Array = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

var _mode := _CALENDAR
var _mode_tabs: Array[TextureButton] = []
var _mode_names: Array[Label] = []
var _calendar: Control
var _host: Control
var _invites: Control
var _month_label: Label
var _year_label: Label
var _day_buttons: Array[TextureButton] = []
var _month_card: TextureRect
var _filter_card: TextureRect
var _left_arrow: TextureButton
var _clock_hour: Label
var _clock_colon: Label
var _clock_minute: Label
var _clock_ampm: Label
var _filter_label: Label
var _filter := 0
var _shown_year := 0
var _shown_month := 0
var _today_year := 0
var _today_month := 0
var _today_day := 0
var _picked := 0
var _blink := 0.0
var _colon_on := true
var _page := Vector2.ZERO


static func tab_icon() -> Texture2D:
	# Stickerbook_PartyIcon lives in phase_4/models/parties/partyStickerbook,
	# which is not in the asset set. This stands in for that book tab.
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in 20:
		var half := int(float(20 - y) * 9.0 / 20.0)
		for x in range(16 - half, 16 + half):
			image.set_pixel(x, y + 8, Color(0.95, 0.78, 0.15, 1))
	for y in 6:
		for x in 6:
			if Vector2(x - 2.5, y - 2.5).length() < 2.8:
				image.set_pixel(13 + x, y + 2, Color(0.9, 0.18, 0.22, 1))
	for x in range(7, 25):
		image.set_pixel(x, 27, Color(0.85, 0.15, 0.22, 1))
		image.set_pixel(x, 28, Color(0.85, 0.15, 0.22, 1))
	return ImageTexture.create_from_image(image)


func _ready() -> void:
	name = "Events"
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false
	_build_tabs()
	_calendar = _sheet()
	_host = _sheet()
	_invites = _sheet()
	_build_calendar()
	_build_host()
	_build_invites()
	_read_today()
	_shown_year = _today_year
	_shown_month = _today_month
	_show_mode()


func _process(delta: float) -> void:
	if not visible or _mode != _CALENDAR:
		return
	_blink += delta
	if _blink < 0.75 and _colon_on:
		return
	if _blink < 1.0 and not _colon_on:
		return
	if _blink >= 1.0:
		_blink = 0.0
		_colon_on = true
		_paint_clock()
	elif _blink >= 0.75:
		_colon_on = false
		_clock_colon.visible = false


func layout(page_size: Vector2) -> void:
	_page = page_size
	# EventsPage tabs: Calendar, Hosting, Invitations, without the news tab.
	var tab_at := PackedFloat32Array([-0.55, -0.13, 0.28])
	var tab_order := PackedInt32Array([_CALENDAR, _HOST, _INVITED])
	var tab_box := _units(0.40, 0.085)
	for index in tab_order.size():
		var which := tab_order[index]
		var origin := _spot(tab_at[index], 0.775) - tab_box * 0.5
		_mode_tabs[which].position = origin
		_mode_tabs[which].size = tab_box
		_mode_names[which].position = origin
		_mode_names[which].size = tab_box
		ToonGui.style_label(_mode_names[which], _INK, maxi(int(tab_box.y * 0.38), 12), Color(0, 0, 0, 0), 0)
	var body := Rect2(Vector2(page_size.x * 0.08, page_size.y * 0.2), Vector2(page_size.x * 0.84, page_size.y * 0.7))
	_place_calendar(body)
	_place_host(body)
	_place_invites(body)


func refresh() -> void:
	_read_today()
	if _shown_year == 0:
		_shown_year = _today_year
		_shown_month = _today_month
	_fill_month()
	_paint_clock()
	_paint_tabs()


func _build_tabs() -> void:
	var names: PackedStringArray = ["Hosting", "Invitations", "Calendar"]
	for index in names.size():
		var tab := TextureButton.new()
		tab.texture_normal = _TAB
		tab.ignore_texture_size = true
		tab.stretch_mode = TextureButton.STRETCH_SCALE
		tab.focus_mode = FOCUS_NONE
		tab.pressed.connect(_set_mode.bind(index))
		tab.mouse_entered.connect(_tint_tab.bind(index, true))
		tab.mouse_exited.connect(_tint_tab.bind(index, false))
		tab.button_down.connect(_press_tab.bind(index))
		add_child(tab)
		_mode_tabs.append(tab)
		var caption := Label.new()
		caption.text = names[index]
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(caption)
		_mode_names.append(caption)


func _sheet() -> Control:
	var panel := Control.new()
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(PRESET_FULL_RECT)
	add_child(panel)
	return panel


func _build_calendar() -> void:
	_month_card = _picture(_calendar, _MONTH_CARD)
	_month_label = _line(_calendar, _MONTH_INK)
	_year_label = _line(_calendar, _YEAR_INK)
	_left_arrow = _picture_button(_calendar, _ARROW_UP, _ARROW_DOWN, _ARROW_HOVER, _month_step.bind(-1))
	_left_arrow.name = "MonthLeft"
	var right := _picture_button(_calendar, _ARROW_UP, _ARROW_DOWN, _ARROW_HOVER, _month_step.bind(1))
	right.name = "MonthRight"
	for index in 7:
		var day_name := _line(_calendar, _WEEK_INK)
		day_name.text = _WEEKDAYS[index]
		day_name.name = "Week%d" % index
	for index in 42:
		var button := _picture_button(_calendar, _BOX_BLANK, _BOX_HOVER, _BOX_HOVER, _pick_day.bind(index))
		_day_buttons.append(button)
		var number := _line(_calendar, _DAY_INK)
		number.mouse_filter = MOUSE_FILTER_IGNORE
		button.set_meta("number", number)
		var events := Label.new()
		events.name = "Events"
		events.mouse_filter = MOUSE_FILTER_IGNORE
		events.clip_text = true
		events.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		events.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		button.add_child(events)
	_filter_card = _picture(_calendar, _FILTER_CARD)
	_filter_label = _line(_calendar, _INK)
	_filter_label.text = _FILTERS[0]
	var up := _picture_button(_calendar, _SCROLL_UP, _SCROLL_DOWN, _SCROLL_HOVER, _cycle_filter.bind(-1))
	up.name = "FilterUp"
	var down := _picture_button(_calendar, _SCROLL_UP, _SCROLL_DOWN, _SCROLL_HOVER, _cycle_filter.bind(1))
	down.name = "FilterDown"
	var time_name := _line(_calendar, _WEEK_INK)
	time_name.text = "TOONTOWN TIME IS"
	time_name.name = "TimeName"
	time_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_hour = _line(_calendar, Color(0.08, 0.08, 0.08))
	_clock_colon = _line(_calendar, Color(0.08, 0.08, 0.08))
	_clock_colon.text = ":"
	_clock_minute = _line(_calendar, Color(0.08, 0.08, 0.08))
	_clock_ampm = _line(_calendar, Color(0.08, 0.08, 0.08))


func _build_host() -> void:
	var title := _line(_host, _INK)
	title.text = "No Parties"
	title.name = "HostTitle"
	var note := _line(_host, _INK)
	note.text = "Go to a playground\nParty Gate to plan\nyour own party!"
	note.name = "HostNote"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_disabled_pill(_host, "Cancel Party", "Cancel")
	_disabled_pill(_host, "Start\nParty!", "Start")
	for list_name in ["Guests", "Activities", "Decorations"]:
		var heading := _line(_host, _INK)
		heading.text = list_name
		heading.name = list_name


func _build_invites() -> void:
	var title := _line(_invites, _INK)
	title.text = "Party Invitations"
	title.name = "InviteTitle"
	var hosts := _line(_invites, _INK)
	hosts.text = "Hosts"
	hosts.name = "Hosts"
	var activities := _line(_invites, _INK)
	activities.text = "Activities"
	activities.name = "Activities"
	_disabled_pill(_invites, "Go to\nParty!", "Go")


func _place_calendar(_body: Rect2) -> void:
	# Locators from tt_m_gui_sbk_calendar.bam. The month is parented at z -0.1.
	_center(_month_card, 0.0, 0.7304, 0.5904, 0.1552)
	_center(_month_label, 0.0, 0.7003, 0.5, 0.07)
	_center(_year_label, 0.0, 0.6703, 0.36, 0.04)
	ToonGui.style_label(_month_label, _MONTH_INK, maxi(int(_units(0.0, 0.07).y * 0.7), 14), Color(0, 0, 0, 0), 0)
	ToonGui.style_label(_year_label, _YEAR_INK, maxi(int(_units(0.0, 0.04).y * 0.7), 11), Color(0, 0, 0, 0), 0)
	_center(_left_arrow, -0.3363, 0.7304, 0.0953, 0.1556)
	_left_arrow.scale = Vector2(-1, 1)
	var right := _calendar.get_node("MonthRight") as TextureButton
	_center(right, 0.3657, 0.7304, 0.0953, 0.1556)
	right.scale = Vector2.ONE
	var week_x: Array[float] = [-0.7371, -0.4904, -0.2441, 0.0041, 0.2512, 0.4997, 0.7459]
	for index in 7:
		var weekday := _calendar.get_node("Week%d" % index) as Label
		_center(weekday, week_x[index], 0.6131, 0.2, 0.045)
		ToonGui.style_label(weekday, _WEEK_INK, maxi(int(weekday.size.y * 0.75), 11), Color(0, 0, 0, 0), 0)
	var number_px := maxi(int(_units(0.0, 0.045).y * 0.85), 12)
	for index in _day_buttons.size():
		var column := index % 7
		var row := int(index / 7.0)
		var x := -0.8705 + float(column) * 0.2486
		var z := 0.6036 - float(row) * 0.1861
		var button := _day_buttons[index]
		var box := _units(0.2486, 0.1860)
		button.position = _spot(x, z, 0.1)
		button.size = box
		button.pivot_offset = box * 0.5
		var number := button.get_meta("number") as Label
		var number_box := _units(0.16, 0.05)
		number.position = _spot(x + 0.1259, z - 0.0329, 0.1) - number_box * 0.5
		number.size = number_box
		ToonGui.style_label(number, _DAY_INK, number_px, Color(0, 0, 0, 0), 0)
		var events := button.get_node_or_null("Events") as Label
		if events != null:
			events.position = Vector2(_units(0.0071, 0.0).x, _units(0.0, 0.0389).y)
			events.size = Vector2(_units(0.23, 0.0).x, _units(0.0, 0.14).y)
			ToonGui.style_label(events, Color(0.08, 0.08, 0.12), maxi(int(_units(0.0, 0.03).y), 8), Color(0, 0, 0, 0), 0)
			events.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			events.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_center(_filter_card, 0.6206, 0.74325, 0.4118, 0.0733)
	_center(_filter_label, 0.6206, 0.74325, 0.32, 0.055)
	ToonGui.style_label(_filter_label, _INK, maxi(int(_filter_label.size.y * 0.55), 11), Color(0, 0, 0, 0), 0)
	var filter_up := _calendar.get_node("FilterUp") as TextureButton
	var filter_down := _calendar.get_node("FilterDown") as TextureButton
	_center(filter_up, 0.6206, 0.7924, 0.0727, 0.0318)
	filter_up.scale = Vector2(1, -1)
	_center(filter_down, 0.6206, 0.6919, 0.0727, 0.0318)
	filter_down.scale = Vector2.ONE
	# "TOONTOWN TIME IS" is text_scale 0.065. The clock is text_scale 0.075.
	var time_name := _calendar.get_node("TimeName") as Label
	var title_px := maxi(int(_units(0.0, 0.065).y), 12)
	var time_box := _units(0.9, 0.065)
	var time_right := _spot(-0.1540, -0.5524, 0.1)
	time_name.position = Vector2(time_right.x - time_box.x, time_right.y - time_box.y * 0.5)
	time_name.size = time_box
	ToonGui.style_label(time_name, _WEEK_INK, title_px, Color(0, 0, 0, 0), 0)
	var clock_px := maxi(int(_units(0.0, 0.075).y), 14)
	var hour_box := _units(0.16, 0.075)
	var hour_right := _spot(0.2696, -0.5524, 0.1)
	_clock_hour.position = hour_right - Vector2(hour_box.x, hour_box.y * 0.5)
	_clock_hour.size = hour_box
	_clock_hour.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var colon_box := _units(0.045, 0.075)
	_clock_colon.position = Vector2(hour_right.x, hour_right.y - colon_box.y * 0.5)
	_clock_colon.size = colon_box
	var minute_box := _units(0.12, 0.075)
	_clock_minute.position = Vector2(hour_right.x + colon_box.x, hour_right.y - minute_box.y * 0.5)
	_clock_minute.size = minute_box
	_clock_minute.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var am_box := _units(0.2, 0.075)
	var am_at := _spot(0.4406, -0.5524, 0.1)
	_clock_ampm.position = am_at - Vector2(0, am_box.y * 0.5)
	_clock_ampm.size = am_box
	_clock_ampm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	for label in [_clock_hour, _clock_colon, _clock_minute, _clock_ampm]:
		ToonGui.style_label(label, Color(0.08, 0.08, 0.08), clock_px, Color(0, 0, 0, 0), 0)
	for index in 7:
		(_calendar.get_node("Week%d" % index) as CanvasItem).move_to_front()
	for button in _day_buttons:
		(button.get_meta("number") as CanvasItem).move_to_front()
	for node in [_month_label, _year_label, _left_arrow, right, _filter_label, filter_up, filter_down, time_name, _clock_hour, _clock_colon, _clock_minute, _clock_ampm]:
		(node as CanvasItem).move_to_front()
	_fill_month()
	_paint_clock()


func _place_host(body: Rect2) -> void:
	var title := _host.get_node("HostTitle") as Label
	title.position = Vector2(body.position.x, body.position.y)
	title.size = Vector2(body.size.x, body.size.y * 0.1)
	ToonGui.style_label(title, _INK, maxi(int(body.size.y * 0.05), 16), Color(0, 0, 0, 0), 0)
	var note := _host.get_node("HostNote") as Label
	note.position = Vector2(body.position.x + body.size.x * 0.15, body.position.y + body.size.y * 0.18)
	note.size = Vector2(body.size.x * 0.7, body.size.y * 0.28)
	ToonGui.style_label(note, _INK, maxi(int(body.size.y * 0.045), 14), Color(0, 0, 0, 0), 0)
	var lists: PackedStringArray = ["Guests", "Activities", "Decorations"]
	for index in lists.size():
		var heading := _host.get_node(lists[index]) as Label
		heading.position = Vector2(body.position.x + body.size.x * float(index) / 3.0, body.position.y + body.size.y * 0.5)
		heading.size = Vector2(body.size.x / 3.0, body.size.y * 0.08)
		ToonGui.style_label(heading, _INK, maxi(int(body.size.y * 0.035), 12), Color(0, 0, 0, 0), 0)
	_place_pill(_host.get_node("Cancel") as TextureButton, Vector2(body.position.x + body.size.x * 0.08, body.position.y + body.size.y * 0.78), Vector2(body.size.x * 0.34, body.size.y * 0.12))
	_place_pill(_host.get_node("Start") as TextureButton, Vector2(body.position.x + body.size.x * 0.58, body.position.y + body.size.y * 0.78), Vector2(body.size.x * 0.34, body.size.y * 0.12))


func _place_invites(body: Rect2) -> void:
	var title := _invites.get_node("InviteTitle") as Label
	title.position = Vector2(body.position.x, body.position.y)
	title.size = Vector2(body.size.x, body.size.y * 0.1)
	ToonGui.style_label(title, _INK, maxi(int(body.size.y * 0.05), 16), Color(0, 0, 0, 0), 0)
	var hosts := _invites.get_node("Hosts") as Label
	hosts.position = Vector2(body.position.x, body.position.y + body.size.y * 0.16)
	hosts.size = Vector2(body.size.x * 0.45, body.size.y * 0.08)
	var activities := _invites.get_node("Activities") as Label
	activities.position = Vector2(body.position.x + body.size.x * 0.5, body.position.y + body.size.y * 0.16)
	activities.size = Vector2(body.size.x * 0.45, body.size.y * 0.08)
	for label in [hosts, activities]:
		ToonGui.style_label(label, _INK, maxi(int(body.size.y * 0.035), 12), Color(0, 0, 0, 0), 0)
	_place_pill(_invites.get_node("Go") as TextureButton, Vector2(body.position.x + body.size.x * 0.33, body.position.y + body.size.y * 0.78), Vector2(body.size.x * 0.34, body.size.y * 0.12))


func _set_mode(mode: int) -> void:
	if _mode == mode:
		return
	_mode = mode
	_show_mode()


func _show_mode() -> void:
	_calendar.visible = _mode == _CALENDAR
	_host.visible = _mode == _HOST
	_invites.visible = _mode == _INVITED
	_paint_tabs()
	if _mode == _CALENDAR:
		_fill_month()
		_paint_clock()


func _paint_tabs() -> void:
	for index in _mode_tabs.size():
		var chosen := index == _mode
		_mode_tabs[index].modulate = _SELECTED if chosen else _NORMAL
		_mode_tabs[index].mouse_filter = MOUSE_FILTER_IGNORE if chosen else MOUSE_FILTER_STOP
		_mode_tabs[index].button_pressed = false


func _tint_tab(index: int, over: bool) -> void:
	if index == _mode:
		return
	_mode_tabs[index].modulate = _ROLLOVER if over else _NORMAL


func _press_tab(index: int) -> void:
	if index == _mode:
		return
	_mode_tabs[index].modulate = _CLICK


func _month_step(step: int) -> void:
	if step < 0 and _shown_year == _today_year and _shown_month == _today_month:
		return
	_shown_month += step
	if _shown_month > 12:
		_shown_month = 1
		_shown_year += 1
	elif _shown_month < 1:
		_shown_month = 12
		_shown_year -= 1
	if _shown_year < _today_year or (_shown_year == _today_year and _shown_month < _today_month):
		_shown_year = _today_year
		_shown_month = _today_month
	_picked = 0
	_fill_month()


func _cycle_filter(step: int) -> void:
	_filter = posmod(_filter + step, _FILTERS.size())
	_filter_label.text = _FILTERS[_filter]
	_fill_month()


func _pick_day(index: int) -> void:
	var number := int(_day_buttons[index].get_meta("day", 0))
	if number <= 0:
		return
	_picked = number
	_fill_month()


func _fill_month() -> void:
	if _month_label == null:
		return
	_month_label.text = _MONTHS[_shown_month]
	_year_label.text = str(_shown_year)
	var on_now := _shown_year == _today_year and _shown_month == _today_month
	_left_arrow.visible = not on_now
	_left_arrow.mouse_filter = MOUSE_FILTER_IGNORE if on_now else MOUSE_FILTER_STOP
	var first := _weekday_of(_shown_year, _shown_month, 1)
	var count := _days_in(_shown_month, _shown_year)
	var previous_month := _shown_month - 1
	var previous_year := _shown_year
	if previous_month < 1:
		previous_month = 12
		previous_year -= 1
	var previous_count := _days_in(previous_month, previous_year)
	for index in _day_buttons.size():
		var button := _day_buttons[index]
		var number := button.get_meta("number") as Label
		var day_number := index - first + 1
		var in_month := day_number >= 1 and day_number <= count
		var shown := day_number
		if day_number < 1:
			shown = previous_count + day_number
		elif day_number > count:
			shown = day_number - count
		number.text = str(shown)
		button.set_meta("day", day_number if in_month else 0)
		var today := in_month and on_now and day_number == _today_day
		var picked := in_month and day_number == _picked
		var face: Texture2D = _BOX_BLANK
		if picked:
			face = _BOX_HOVER
		elif today:
			face = _BOX_TODAY
		var hover: Texture2D = face
		if in_month:
			hover = _BOX_HOVER
		button.texture_normal = face
		button.texture_hover = hover
		button.texture_pressed = hover
		button.modulate = Color.WHITE if in_month else Color(0.75, 0.75, 0.75, 1)
		button.mouse_filter = MOUSE_FILTER_STOP if in_month else MOUSE_FILTER_IGNORE
		var when := _cell_date(day_number, count, previous_year, previous_month, previous_count)
		var events := button.get_node_or_null("Events") as Label
		if events != null:
			var holiday_lines: PackedStringArray = _HOLIDAYS.lines(when.x, when.y, when.z, _filter != 2)
			events.text = "\n".join(holiday_lines)


func _cell_date(day_number: int, count: int, previous_year: int, previous_month: int, previous_count: int) -> Vector3i:
	if day_number >= 1 and day_number <= count:
		return Vector3i(_shown_year, _shown_month, day_number)
	if day_number < 1:
		return Vector3i(previous_year, previous_month, previous_count + day_number)
	var next_month := _shown_month + 1
	var next_year := _shown_year
	if next_month > 12:
		next_month = 1
		next_year += 1
	return Vector3i(next_year, next_month, day_number - count)


func _paint_clock() -> void:
	var now := ToonNet.clock()
	var hour := int(now.get("hour", 0))
	var minute := int(now.get("minute", 0))
	var suffix := "AM"
	if hour >= 12:
		suffix = "PM"
	var shown := hour % 12
	if shown == 0:
		shown = 12
	_clock_hour.text = str(shown)
	_clock_minute.text = "%02d" % minute
	_clock_ampm.text = suffix
	_clock_colon.visible = _colon_on


func _read_today() -> void:
	var now := ToonNet.clock()
	_today_year = int(now.get("year", 2026))
	_today_month = int(now.get("month", 1))
	_today_day = int(now.get("day", 1))


func _weekday_of(year: int, month: int, day: int) -> int:
	var stamp := Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day})
	var info := Time.get_datetime_dict_from_unix_time(stamp)
	return int(info.get("weekday", 0))


func _days_in(month: int, year: int) -> int:
	if month == 2 and (year % 400 == 0 or (year % 4 == 0 and year % 100 != 0)):
		return 29
	return _DAYS_IN[month]


func _line(parent: Control, _color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _spot(x: float, z: float, drop: float = 0.0) -> Vector2:
	return Vector2((x + 1.0) * 0.5 * _page.x, (0.75 - (z - drop)) / 1.5 * _page.y)


func _units(w: float, h: float) -> Vector2:
	return Vector2(w * 0.5 * _page.x, h / 1.5 * _page.y)


func _center(node: Control, x: float, z: float, w: float, h: float) -> void:
	var box := _units(w, h)
	node.position = _spot(x, z, 0.1) - box * 0.5
	node.size = box
	node.pivot_offset = box * 0.5


func _picture(parent: Control, texture: Texture2D) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.mouse_filter = MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	parent.add_child(image)
	return image


func _picture_button(parent: Control, up: Texture2D, down: Texture2D, hover: Texture2D, action: Callable) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = up
	button.texture_pressed = down
	button.texture_hover = hover
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	ToonGui.button_sounds(button)
	return button


func _disabled_pill(parent: Control, text: String, node_name: String) -> void:
	var button := TextureButton.new()
	button.name = node_name
	button.texture_normal = _PILL
	button.texture_pressed = _PILL_DOWN
	button.texture_hover = _PILL_HOVER
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = FOCUS_NONE
	button.disabled = true
	button.modulate = Color(1, 1, 1, 0.45)
	button.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(button)
	var caption := Label.new()
	caption.text = text
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = MOUSE_FILTER_IGNORE
	caption.set_anchors_preset(PRESET_FULL_RECT)
	button.add_child(caption)


func _place_pill(button: TextureButton, at: Vector2, box: Vector2) -> void:
	button.position = at
	button.size = box
	var caption := button.get_child(0) as Label
	ToonGui.style_label(caption, Color(0.12, 0.12, 0.14), maxi(int(box.y * 0.28), 12), Color(0, 0, 0, 0), 0)
