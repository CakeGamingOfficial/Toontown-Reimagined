extends Node

## PartyPlanner pages: Welcome, the grounds editor, guests, the day,
## the time, the invitation, then the farewell. The clock is bought
## automatically and starts at grid (8, 7). As Soon As Possible is the
## next 5-minute mark, and a party lasts 30 minutes.

const _GUI := preload("res://scenes/toons/toon_gui.gd")
const _BEANS := preload("res://scenes/toons/jellybeans.gd")
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

var _layer: CanvasLayer
var _panel: ColorRect
var _title: Label
var _info: Label
var _back: Button
var _next: Button
var _pages: Dictionary = {}
var _grid: GridContainer
var _cells: Array = []
var _list: VBoxContainer
var _buy: Button
var _cost: Label
var _guest_list: VBoxContainer
var _privacy: Label
var _date_list: VBoxContainer
var _date_buttons: Array = []
var _time_label: Label
var _invite_label: Label
var _theme_buttons: Array = []


func _ready() -> void:
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
	var view := get_viewport().get_visible_rect().size
	var panel_size := Vector2(min(960.0, view.x - 24.0), min(640.0, view.y - 24.0))
	_layer = CanvasLayer.new()
	_layer.layer = 30
	add_child(_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.size = view
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(dim)
	_panel = ColorRect.new()
	_panel.color = Color(0.45, 0.2, 0.55, 0.96)
	_panel.position = (view - panel_size) * 0.5
	_panel.size = panel_size
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_panel)
	_title = _label(Vector2(16, 10), Vector2(panel_size.x - 32, 56), 26)
	_panel.add_child(_title)
	_info = _label(Vector2(16, 70), Vector2(panel_size.x - 32, 72), 18)
	_panel.add_child(_info)
	_build_editor(panel_size)
	_build_guests(panel_size)
	_build_date(panel_size)
	_build_time(panel_size)
	_build_invite(panel_size)
	_back = _nav_button("Back", Vector2(16, panel_size.y - 52), _on_back)
	_next = _nav_button("Continue", Vector2(panel_size.x * 0.5 - 110, panel_size.y - 52), _on_next)
	_nav_button("Close Planner", Vector2(panel_size.x - 236, panel_size.y - 52), _finish)


func _label(at: Vector2, size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.size = size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_GUI.style_label(label, Color.WHITE, font_size, Color.BLACK, 3)
	return label


func _nav_button(caption: String, at: Vector2, call: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = at
	button.custom_minimum_size = Vector2(210, 40)
	button.size = Vector2(210, 40)
	button.pressed.connect(call)
	_panel.add_child(button)
	return button


func _page(id: String, panel_size: Vector2) -> Control:
	var box := Control.new()
	box.position = Vector2(12, 148)
	box.size = Vector2(panel_size.x - 24, panel_size.y - 210)
	box.visible = false
	_panel.add_child(box)
	_pages[id] = box
	return box


func _build_editor(panel_size: Vector2) -> void:
	var page := _page("editor", panel_size)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 0)
	scroll.size = Vector2(270, page.size.y - 44)
	page.add_child(scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(250, 0)
	scroll.add_child(_list)
	_grid = GridContainer.new()
	_grid.columns = _COLS
	_grid.position = Vector2(284, 0)
	_grid.add_theme_constant_override("h_separation", 1)
	_grid.add_theme_constant_override("v_separation", 1)
	page.add_child(_grid)
	for y in _ROWS:
		for x in _COLS:
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(_CELL, _CELL)
			cell.focus_mode = Control.FOCUS_NONE
			cell.pressed.connect(_on_cell.bind(x, y))
			_grid.add_child(cell)
			_cells.append(cell)
	_buy = Button.new()
	_buy.position = Vector2(0, page.size.y - 40)
	_buy.custom_minimum_size = Vector2(120, 36)
	_buy.size = Vector2(120, 36)
	_buy.pressed.connect(_on_buy)
	page.add_child(_buy)
	var trash := Button.new()
	trash.text = "Trash"
	trash.position = Vector2(130, page.size.y - 40)
	trash.custom_minimum_size = Vector2(120, 36)
	trash.size = Vector2(120, 36)
	trash.pressed.connect(_on_trash)
	page.add_child(trash)
	_cost = _label(Vector2(284, page.size.y - 40), Vector2(360, 40), 18)
	page.add_child(_cost)
	for index in _catalog.size():
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_catalog.bind(index))
		_list.add_child(button)


func _build_guests(panel_size: Vector2) -> void:
	var page := _page("guests", panel_size)
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(page.size.x, page.size.y - 90)
	page.add_child(scroll)
	_guest_list = VBoxContainer.new()
	_guest_list.custom_minimum_size = Vector2(page.size.x - 20, 0)
	scroll.add_child(_guest_list)
	for index in _friends.size():
		var friend: Dictionary = _friends[index]
		var box := CheckButton.new()
		box.text = FriendsBook.shown_name(friend)
		box.toggled.connect(_on_guest.bind(index))
		_guest_list.add_child(box)
	var all := Button.new()
	all.text = "Check All"
	all.position = Vector2(0, page.size.y - 80)
	all.custom_minimum_size = Vector2(160, 34)
	all.pressed.connect(_set_guests.bind(true))
	page.add_child(all)
	var none := Button.new()
	none.text = "Uncheck All"
	none.position = Vector2(170, page.size.y - 80)
	none.custom_minimum_size = Vector2(160, 34)
	none.pressed.connect(_set_guests.bind(false))
	page.add_child(none)
	var public_button := Button.new()
	public_button.text = "Public"
	public_button.position = Vector2(360, page.size.y - 80)
	public_button.custom_minimum_size = Vector2(140, 34)
	public_button.pressed.connect(_set_public.bind(true))
	page.add_child(public_button)
	var private_button := Button.new()
	private_button.text = "Private"
	private_button.position = Vector2(510, page.size.y - 80)
	private_button.custom_minimum_size = Vector2(140, 34)
	private_button.pressed.connect(_set_public.bind(false))
	page.add_child(private_button)
	_privacy = _label(Vector2(0, page.size.y - 40), Vector2(page.size.x, 36), 18)
	page.add_child(_privacy)


func _build_date(panel_size: Vector2) -> void:
	var page := _page("date", panel_size)
	var asap := Button.new()
	asap.text = "As Soon As Possible"
	asap.custom_minimum_size = Vector2(280, 36)
	asap.pressed.connect(_on_asap)
	page.add_child(asap)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 46)
	scroll.size = Vector2(page.size.x, page.size.y - 46)
	page.add_child(scroll)
	_date_list = VBoxContainer.new()
	_date_list.custom_minimum_size = Vector2(page.size.x - 20, 0)
	scroll.add_child(_date_list)
	var noon := _clock.duplicate()
	noon["hour"] = 12
	noon["minute"] = 0
	_day_origin = _local_to_unix(noon)
	for index in 28:
		var dict := _unix_to_local(int(_day_origin + float(index) * 86400.0))
		var button := Button.new()
		button.text = _format_date(dict)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_day.bind(index))
		_date_list.add_child(button)
		_date_buttons.append(button)


func _build_time(panel_size: Vector2) -> void:
	var page := _page("time", panel_size)
	_time_label = _label(Vector2(0, 0), Vector2(page.size.x, 80), 22)
	page.add_child(_time_label)
	_time_step(page, "Hour", Vector2(0, 100), 1)
	_time_step(page, "Minute", Vector2(230, 100), 15)
	var ampm := Button.new()
	ampm.text = "AM / PM"
	ampm.position = Vector2(460, 100)
	ampm.custom_minimum_size = Vector2(160, 36)
	ampm.pressed.connect(_shift_hour.bind(12))
	page.add_child(ampm)


func _time_step(page: Control, caption: String, at: Vector2, amount: int) -> void:
	var up := Button.new()
	up.text = caption + " +"
	up.position = at
	up.custom_minimum_size = Vector2(160, 36)
	up.pressed.connect(_shift_clock.bind(caption, amount))
	page.add_child(up)
	var down := Button.new()
	down.text = caption + " -"
	down.position = at + Vector2(0, 44)
	down.custom_minimum_size = Vector2(160, 36)
	down.pressed.connect(_shift_clock.bind(caption, -amount))
	page.add_child(down)


func _build_invite(panel_size: Vector2) -> void:
	var page := _page("invite", panel_size)
	_invite_label = _label(Vector2(0, 0), Vector2(page.size.x, 180), 18)
	page.add_child(_invite_label)
	var row := 0
	for theme in _THEMES:
		var button := Button.new()
		button.text = theme
		button.position = Vector2(float(row % 4) * 180.0, 190.0 + float(row / 4) * 44.0)
		button.custom_minimum_size = Vector2(170, 36)
		button.pressed.connect(_set_theme.bind(theme))
		page.add_child(button)
		_theme_buttons.append(button)
		row += 1


func _show(page: String) -> void:
	_page = page
	for id in _pages.keys():
		(_pages[id] as Control).visible = id == page
	_title.text = "Toontown Party Planner"
	_back.visible = page != "welcome" and page != "farewell"
	_next.visible = page != "farewell"
	_next.text = "Continue"
	_next.disabled = false
	if page == "welcome":
		_info.text = "Hosting your own party is a lot of fun!\nStart planning with the arrows at the bottom!"
	elif page == "editor":
		_title.text = "Design Your Party\nPlace Activities and Decorations"
		_info.text = "Click on the Party Activity or Decoration you would like to purchase."
		_paint_editor()
	elif page == "guests":
		_title.text = "Choose Your Guests"
		_paint_privacy()
	elif page == "date":
		_title.text = "Pick A Day For Your Party"
		_info.text = "As Soon As Possible uses the next 5-minute mark."
		_next.visible = _day_index >= 0
		_paint_days()
	elif page == "time":
		_title.text = "Pick A Time For Your Party"
		_info.text = "Toontown Time"
		_paint_time()
	elif page == "invite":
		_title.text = "Double Check Your Party" if _invitees().is_empty() else "Choose Invitations To Send"
		_next.text = "Plan Party" if _invitees().is_empty() else "Send Invites"
		_info.text = "Theme"
		_paint_invite()
	elif page == "farewell":
		_title.text = "Congratulations!"
		if _invitees().is_empty():
			_info.text = "Your party has been created!\nThanks!"
		else:
			_info.text = "Your party has been created and your invitations sent out.\nThanks!"


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
	_time_label.text = "%s\n%s" % [_format_date(shown), _format_time(shown)]


func _paint_days() -> void:
	for index in _date_buttons.size():
		var button := _date_buttons[index] as Button
		button.modulate = Color(1, 1, 0.55) if index == _day_index else Color.WHITE


func _on_guest(on: bool, index: int) -> void:
	_invited[index] = on


func _set_guests(on: bool) -> void:
	for index in _invited.size():
		_invited[index] = on
		var box := _guest_list.get_child(index) as CheckButton
		if box != null:
			box.set_pressed_no_signal(on)


func _set_public(on: bool) -> void:
	_public = on
	_paint_privacy()


func _paint_privacy() -> void:
	if _public:
		_info.text = "This party will be:\nAny Toon can come!"
		_privacy.text = "Public"
	else:
		_info.text = "This party will be:\nOnly Invited Toons can come!"
		_privacy.text = "Private"


func _set_theme(theme: String) -> void:
	_theme = theme
	_paint_invite()


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
	for index in _theme_buttons.size():
		var button := _theme_buttons[index] as Button
		button.modulate = Color(1, 1, 0.55) if button.text == _theme else Color.WHITE


func _send() -> void:
	var guests: Array = _invitees()
	var result: Variant = get_parent().call("commit_party", _items, guests, _public, _start_unix(), _theme)
	var message := String(result)
	if message != "":
		_title.text = "Oops."
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


func _paint_grid() -> void:
	for y in _ROWS:
		for x in _COLS:
			var button := _cells[y * _COLS + x] as Button
			var owner := _owner_at(x, y, -1)
			if not _open_cell(x, y):
				button.disabled = true
				button.modulate = Color(0.32, 0.2, 0.4)
				continue
			button.disabled = false
			if owner < 0:
				button.modulate = Color(0.62, 0.8, 0.95)
			elif owner == _selected:
				button.modulate = Color(1, 1, 0.45)
			elif String(_items[owner].get("kind", "")) == "d":
				button.modulate = Color(0.9, 0.45, 0.75)
			elif int(_items[owner].get("id", -1)) == 7:
				button.modulate = Color(0.95, 0.84, 0.25)
			else:
				button.modulate = Color(0.28, 0.74, 0.4)


func _paint_list() -> void:
	for index in _catalog.size():
		var entry: Dictionary = _catalog[index]
		var button := _list.get_child(index) as Button
		if button == null:
			continue
		var caption := "%d  %s" % [int(entry["cost"]), String(entry["editor"])]
		if _count(entry) >= int(entry["limit"]):
			caption += "  SOLD OUT"
		button.text = caption
		button.modulate = Color(1, 1, 0.55) if index == _catalog_index else Color.WHITE


func _paint_buy() -> void:
	_buy.disabled = true
	_buy.text = "BUY"
	if _catalog_index < 0:
		return
	var entry: Dictionary = _catalog[_catalog_index]
	if _count(entry) >= int(entry["limit"]):
		_buy.text = "SOLD OUT"
		return
	if _total() + int(entry["cost"]) > _beans():
		return
	_buy.disabled = false


func _select_catalog(index: int) -> void:
	_catalog_index = index
	_moving = false
	_ground_ok = false
	var entry: Dictionary = _catalog[index]
	_info.text = "%s\n%d beans\nClick Buy or click the Party Grounds Map." % [String(entry["desc"]), int(entry["cost"])]
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
	var pairs := [[0, 8], [4, 9]]
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
		_act(0, "Jukebox - 20", "a 20 song Jukebox", "Listen to music with your own 20 song jukebox!", 50, 1, 1, 1, "jukebox"),
		_act(8, "Jukebox - 40", "a 40 song jukebox", "Listen to music with your own 40 song jukebox!", 100, 1, 1, 1, "jukebox"),
		_act(1, "Cannons", "Party Cannons", "Fire yourself out of the cannons and into fun!", 50, 1, 1, 10, "cannon"),
		_act(2, "Trampoline", "Trampoline", "Collect jellybeans and bounce the highest!", 50, 2, 2, 8, "trampoline"),
		_act(3, "Party Catch", "Party Catch", "Catch fruit to win beans! Dodge those anvils!", 300, 5, 5, 1, "catch"),
		_act(4, "Dance Floor - 10", "a 10 move Dance Floor", "Show off all 10 of your moves, toon style!", 100, 3, 3, 1, "dance"),
		_act(9, "Dance Floor - 20", "a 20 move Dance Floor", "Show off all 20 of your moves, toon style!", 200, 3, 3, 1, "dance"),
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


func _decor(id: int, editor: String, desc: String, cost: int) -> Dictionary:
	return {
		"kind": "d",
		"id": id,
		"editor": editor,
		"invite": "",
		"desc": desc,
		"cost": cost,
		"w": 1,
		"h": 1,
		"limit": 5,
		"station": "",
	}
