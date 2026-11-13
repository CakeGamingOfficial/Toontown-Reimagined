extends Control

## KartShopGui. The clerk pages are the phase_6 panels: the yellow main menu,
## the buy, return, confirm, and bought kart cards, and the accessory cards.
## Buying a kart you already own asks you to return it first.

signal finished

const _GARAGE := preload("res://scenes/racing/kart_garage.gd")
const _MODEL := preload("res://scenes/racing/kart_model.gd")
const _GUI := preload("res://scenes/toons/toon_gui.gd")
const _CLOCK := preload("res://assets/gui/purchase/alarm_clock.png")
const _CARDS := "res://assets/gui/kart_shop/"
const _SECONDS := 180.0
const _SHIFT := -0.01
const _MAIN := 0.75
const _BIG := 0.088
const _SMALL := 0.055
const _BLACK := Color(0, 0, 0, 1)
const _RED := Color(0.95, 0, 0, 1)
const _YELLOW := Color(0.95, 0.95, 0, 1)
const _CREAM := Color(1, 1, 0.8, 1)
const _CREAM_ACC := Color(1, 1, 0.87, 1)

var _cards: Dictionary = {}
var _pages: Dictionary = {}
var _page := "main"
var _kind := "hood"
var _index := 0
var _rows: Array = []
var _pick: Dictionary = {}
var _left := _SECONDS
var _closed := false
var _yaw := deg_to_rad(-35.0)
var _spin := 0
var _shown := ""
var _view_on := false
var _view_box := Vector4(0, 0.26, 0.76, 0.52)
var _kinds: PackedStringArray = ["hood", "trunk", "front", "back", "rim", "decal", "color"]
var _ticket_labels: Array[Label] = []
var _captions: Array[Label] = []
var _clock: TextureRect
var _clock_num: Label
var _holder: SubViewportContainer
var _cream: ColorRect
var _view: SubViewport
var _world: Node3D
var _camera: Camera3D
var _kart: Node3D
var _main_accessories: TextureButton
var _kart_name: Label
var _kart_cost: Label
var _kart_buy: Label
var _kart_buy_button: TextureButton
var _kart_left: TextureButton
var _kart_right: TextureButton
var _kart_spin_left: TextureButton
var _kart_spin_right: TextureButton
var _acc_name: Label
var _acc_cost: Label
var _acc_buy: Label
var _acc_buy_button: TextureButton
var _acc_left: TextureButton
var _acc_right: TextureButton
var _acc_spin_left: TextureButton
var _acc_spin_right: TextureButton
var _kind_buttons: Dictionary = {}
var _confirm_kart: Label
var _confirm_acc: Label


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_preset(PRESET_FULL_RECT)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(_CARDS + "cards.json"))
	_cards = parsed if parsed is Dictionary else {}
	_build_view()
	_build_main()
	_build_kart()
	_build_return()
	_build_confirm_kart()
	_build_bought_kart()
	_build_accessory()
	_build_confirm_accessory()
	_build_clock()
	_show("main")
	if not get_viewport().size_changed.is_connected(_layout):
		get_viewport().size_changed.connect(_layout)


func _process(delta: float) -> void:
	if _closed:
		return
	_left -= delta
	if _left <= 0.0:
		_close()
		return
	if _spin != 0 and _kart != null:
		_yaw += float(_spin) * deg_to_rad(72.0) * delta
		_kart.rotation.y = _yaw
	_layout()


func _close() -> void:
	if _closed:
		return
	_closed = true
	finished.emit()
	queue_free()


func _show(page: String) -> void:
	_page = page
	_spin = 0
	for key in _pages.keys():
		(_pages[key] as Control).visible = String(key) == page
	# The kart window sits on the panel, and the buttons stay in front of it.
	var host := _pages[page] as Control
	host.add_child(_cream)
	host.add_child(_holder)
	host.move_child(_cream, 1)
	host.move_child(_holder, 2)
	_refresh()
	_layout()


func _refresh() -> void:
	_view_on = false
	match _page:
		"main":
			_hide_kart()
			if _main_accessories != null:
				_main_accessories.disabled = not _GARAGE.has_kart()
		"kart":
			_use_window(0.0035, 0.53, _CREAM)
			_paint_karts()
		"return":
			_use_window(-0.04, 0.49, _CREAM)
			_show_kart(_bare(int(_GARAGE.dna()[0])))
		"confirm_kart":
			_use_window(-0.0425, 0.49, _CREAM)
			_confirm_kart.text = "Buy the %s for %d Tickets?" % [String(_pick.get("name", "Kart")), int(_pick.get("cost", 0))]
			_show_kart(_bare(int(_pick.get("id", 0))))
		"bought_kart":
			_use_window(-0.0425, 0.49, _CREAM)
			_show_kart(_bare(int(_pick.get("id", 0))))
		"accessory":
			_use_window(0.044, 0.58, _CREAM_ACC)
			_paint_accessories()
		"confirm_acc":
			_use_window(-0.0425, 0.49, _CREAM)
			_confirm_acc.text = "Buy the %s for %d Tickets?" % [String(_pick.get("name", "Accessory")), maxi(int(_pick.get("cost", 0)), 0)]
			_show_kart(_accessory_preview(_pick))
	for label in _ticket_labels:
		label.text = str(_GARAGE.tickets())


func _paint_karts() -> void:
	var can_left := false
	var can_right := false
	if _rows.is_empty():
		_hide_kart()
		_kart_name.text = ""
		_kart_cost.text = ""
		_set_line(_kart_cost, _BLACK)
		_set_buy(_kart_buy, _kart_buy_button, "Buy Kart", _BIG, false, _BLACK)
	else:
		var card: Dictionary = _rows[_index]
		var cost := int(card.get("cost", 0))
		var afford := _GARAGE.tickets() >= cost
		_kart_name.text = String(card.get("name", "Kart"))
		_kart_cost.text = "Cost: %d Tickets" % cost
		_set_line(_kart_cost, _BLACK if afford else _RED)
		if afford:
			_set_buy(_kart_buy, _kart_buy_button, "Buy Kart", _BIG, true, _BLACK)
		else:
			_set_buy(_kart_buy, _kart_buy_button, "Not Enough Tickets!", _SMALL * 0.75, false, _BLACK)
		can_left = _index > 0
		can_right = _index + 1 < _rows.size()
		_show_kart(_bare(int(card.get("id", 0))))
	_set_enabled(_kart_left, can_left)
	_set_enabled(_kart_right, can_right)
	_set_visible(_kart_spin_left, not _rows.is_empty())
	_set_visible(_kart_spin_right, not _rows.is_empty())


func _paint_accessories() -> void:
	for kind in _kinds:
		var button := _kind_buttons.get(kind) as TextureButton
		if button != null:
			button.disabled = kind == _kind
	var can_left := false
	var can_right := false
	var full := _GARAGE.owned().size() >= 16
	if _rows.is_empty():
		_hide_kart()
		_acc_name.text = "No available accessories of this type"
		_acc_cost.text = ""
		_set_line(_acc_cost, _BLACK)
		_set_buy(_acc_buy, _acc_buy_button, "Buy Accessory", _SMALL, false, _BLACK)
	else:
		var card: Dictionary = _rows[_index]
		var cost := maxi(int(card.get("cost", 0)), 0)
		var afford := _GARAGE.tickets() >= cost
		_acc_name.text = String(card.get("name", "Accessory"))
		_acc_cost.text = "Cost: %d Tickets" % cost
		_set_line(_acc_cost, _BLACK if afford else _RED)
		if afford:
			_set_buy(_acc_buy, _acc_buy_button, "Buy Accessory", _SMALL, true, _BLACK)
		else:
			_set_buy(_acc_buy, _acc_buy_button, "Not Enough Tickets!", _SMALL * 0.75, false, _BLACK)
		can_left = _index > 0
		can_right = _index + 1 < _rows.size()
		_show_kart(_accessory_preview(card))
	if full:
		_set_buy(_acc_buy, _acc_buy_button, "Your trunk is full.", _SMALL * 0.8, false, _RED)
	_set_enabled(_acc_left, can_left)
	_set_enabled(_acc_right, can_right)
	_set_visible(_acc_spin_left, not _rows.is_empty())
	_set_visible(_acc_spin_right, not _rows.is_empty())


func _open_karts() -> void:
	_index = 0
	_fill_karts()
	_show("kart")


func _open_accessories() -> void:
	if not _GARAGE.has_kart():
		return
	_kind = "hood"
	_index = 0
	_fill_accessories()
	_show("accessory")


func _fill_karts() -> void:
	_rows = []
	var owned_body := -1
	if _GARAGE.has_kart():
		owned_body = int(_GARAGE.dna()[0])
	for entry in _MODEL.karts():
		if not (entry is Dictionary):
			continue
		var card: Dictionary = entry
		if int(card.get("id", -1)) == owned_body:
			continue
		_rows.append(card)
	if _index >= _rows.size():
		_index = 0


func _fill_accessories() -> void:
	_rows = []
	for entry in _MODEL.of_kind(_kind):
		if not (entry is Dictionary):
			continue
		var card: Dictionary = entry
		if int(card.get("cost", 0)) < 0:
			continue
		if _GARAGE.owns(int(card.get("id", -1))):
			continue
		_rows.append(card)
	if _index >= _rows.size():
		_index = 0


func _step(direction: int) -> void:
	if _rows.is_empty():
		return
	var next := _index + direction
	if next < 0 or next >= _rows.size():
		return
	_index = next
	_refresh()


func _choose_kind(kind: String) -> void:
	if _page != "accessory" or kind == _kind:
		return
	_kind = kind
	_index = 0
	_fill_accessories()
	_refresh()


func _buy_kart_pressed() -> void:
	if _page != "kart" or _rows.is_empty():
		return
	_pick = _rows[_index]
	if _GARAGE.tickets() < int(_pick.get("cost", 0)):
		return
	if _GARAGE.has_kart():
		_show("return")
	else:
		_show("confirm_kart")


func _return_ok() -> void:
	_show("confirm_kart")


func _confirm_kart_ok() -> void:
	var reason := _GARAGE.buy_kart(int(_pick.get("id", 0)), int(_pick.get("cost", 0)))
	if reason.is_empty():
		_show("bought_kart")
	else:
		_confirm_kart.text = reason


func _buy_accessory_pressed() -> void:
	if _page != "accessory" or _rows.is_empty():
		return
	if _GARAGE.owned().size() >= 16:
		return
	_pick = _rows[_index]
	if _GARAGE.tickets() < maxi(int(_pick.get("cost", 0)), 0):
		return
	_show("confirm_acc")


func _confirm_acc_ok() -> void:
	var cost := maxi(int(_pick.get("cost", 0)), 0)
	var field := _MODEL.field_for(_kind)
	var reason := _GARAGE.buy_accessory(int(_pick.get("id", -1)), cost, field)
	if not reason.is_empty():
		_confirm_acc.text = reason
		return
	_fill_accessories()
	_show("accessory")


func _cancel() -> void:
	match _page:
		"main":
			_close()
		"return", "confirm_kart":
			_show("kart")
		"confirm_acc":
			_show("accessory")
		_:
			_show("main")


func _bare(body: int) -> Array:
	return [body, -1, -1, -1, -1, -1, -1, -1, -1]


func _accessory_preview(card: Dictionary) -> Array:
	var row := _GARAGE.dna().duplicate()
	while row.size() < 9:
		row.append(-1)
	for field in range(3, 9):
		row[field] = -1
	row[_MODEL.field_for(_kind)] = int(card.get("id", -1))
	return row


func _use_window(bottom: float, top: float, cream: Color) -> void:
	_view_on = true
	_view_box = Vector4(0.0, (bottom + top) * 0.5 + _SHIFT, 0.76, top - bottom)
	_cream.color = cream


func _hide_kart() -> void:
	_view_on = false
	_shown = ""


func _show_kart(row: Array) -> void:
	_view_on = true
	var key := str(row)
	if key == _shown:
		return
	_shown = key
	if _kart != null:
		_kart.free()
		_kart = null
	if row.is_empty() or int(row[0]) < 0:
		return
	_kart = _MODEL.build(row)
	_kart.rotation.y = _yaw
	_world.add_child(_kart)
	var body := int(row[0])
	var dist := 8.5 if body == 2 else 7.0
	_camera.look_at_from_position(Vector3(0, 2.2, dist), Vector3(0, 0.5, 0), Vector3.UP)


func _set_spin(direction: int) -> void:
	_spin = direction


func _set_buy(label: Label, button: TextureButton, text: String, text_scale: float, enabled: bool, color: Color) -> void:
	if label != null:
		label.text = text
		label.set_meta("ts", text_scale)
		_set_line(label, color)
	if button != null:
		button.disabled = not enabled


func _set_line(label: Label, color: Color) -> void:
	if label != null:
		label.set_meta("color", color)


func _set_enabled(button: TextureButton, enabled: bool) -> void:
	if button != null:
		button.disabled = not enabled


func _set_visible(button: TextureButton, shown: bool) -> void:
	if button != null:
		button.visible = shown


func _build_view() -> void:
	_cream = ColorRect.new()
	_cream.color = _CREAM
	_cream.mouse_filter = MOUSE_FILTER_IGNORE
	_cream.visible = false
	add_child(_cream)
	_view = SubViewport.new()
	_view.transparent_bg = true
	_view.size = Vector2i(512, 360)
	_holder = SubViewportContainer.new()
	_holder.stretch = true
	_holder.mouse_filter = MOUSE_FILTER_IGNORE
	_holder.visible = false
	_holder.add_child(_view)
	add_child(_holder)
	_world = Node3D.new()
	_view.add_child(_world)
	_camera = Camera3D.new()
	_camera.current = true
	_world.add_child(_camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	_world.add_child(sun)
	var fill := AmbientLight3D.new()
	fill.light_color = Color(0.55, 0.55, 0.55)
	_world.add_child(fill)


func _build_clock() -> void:
	_clock = TextureRect.new()
	_clock.texture = _CLOCK
	_clock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_clock.stretch_mode = TextureRect.STRETCH_SCALE
	_clock.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_clock)
	_clock_num = Label.new()
	_clock_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock_num.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_clock_num)


func _build_main() -> void:
	var page := _page_root("main")
	_panel(page, "Kart_MainMenuPanel", "Kart_MainMenuPanel", _MAIN)
	var buy := _button(page, "Kart_MainMenuPanel", "BuyKartButtonUp", "BuyKartButtonDown", "BuyKartButtonRollover", "BuyKartButtonDisabled", _MAIN)
	_press(buy, _open_karts)
	_icon(buy, "Kart_MainMenuPanel", "BuyKartIcon")
	_words(page, "Buy Kart", -0.2 * _MAIN, 0.34 * _MAIN + _SHIFT, _BIG * _MAIN, 0.42, 1.3, _BLACK, false, false)
	var accessories := _button(page, "Kart_MainMenuPanel", "BuyAccessoryButtonUp", "BuyAccessoryButtonDown", "BuyAccessoryButtonRollover", "BuyAccessoryButtonDisabled", _MAIN)
	_press(accessories, _open_accessories)
	_icon(accessories, "Kart_MainMenuPanel", "BuyAccessoryIcon")
	_main_accessories = accessories
	_words(page, "Buy Accessories", -0.1 * _MAIN, 0.036 * _MAIN + _SHIFT, _BIG * _MAIN, 0.55, 1.3, _BLACK, false, false)
	var cancel := _button(page, "Kart_MainMenuPanel", "CancelButtonUp", "CancelButtonDown", "CancelButtonRollover", "CancelButtonUp", _MAIN)
	_press(cancel, _cancel)
	_icon(cancel, "Kart_MainMenuPanel", "CancelIcon")


func _build_kart() -> void:
	var page := _page_root("kart")
	_panel(page, "BuyKartPanel", "BuyKartPanel", 1.0)
	_kart_left = _button(page, "BuyKartPanel", "ArrowLeftButtonUp", "ArrowLeftButtonDown", "ArrowLeftButtonRollover", "ArrowLeftButtonInactive", 1.0)
	_press(_kart_left, _step.bind(-1))
	_kart_right = _button(page, "BuyKartPanel", "ArrowRightButtonUp", "ArrowRightButtonDown", "ArrowRightButtonRollover", "ArrowRightButtonInactive", 1.0)
	_press(_kart_right, _step.bind(1))
	_kart_spin_left = _spin_button(page, "BuyKartPanel", "rotate_left", -1)
	_kart_spin_right = _spin_button(page, "BuyKartPanel", "rotate_right", 1)
	_kart_buy_button = _button(page, "BuyKartPanel", "BuyKartButtonUp", "BuyKartButtonDown", "BuyKartButtonRollover", "BuyKartButtonDisabled", 1.0)
	_press(_kart_buy_button, _buy_kart_pressed)
	var cancel := _button(page, "BuyKartPanel", "CancelButtonUp", "CancelButtonDown", "CancelButtonRollover", "CancelButtonUp", 1.0)
	_press(cancel, _cancel)
	_icon(cancel, "BuyKartPanel", "CancelIcon")
	_kart_name = _words(page, "", 0.0, -0.29 + _SHIFT, _SMALL, 1.43, 1.4, _BLACK, false, false)
	_kart_cost = _words(page, "", 0.0, -0.365 + _SHIFT, _SMALL, 1.2, 1.3, _BLACK, false, false)
	_kart_buy = _words(page, "Buy Kart", 0.0, -0.534 + _SHIFT, _BIG, 0.62, 1.3, _BLACK, false, false)
	_tickets(page, 0.44, -0.55 + _SHIFT)


func _build_return() -> void:
	var page := _page_root("return")
	_panel(page, "ReturnKartPanel", "ReturnKartPanel", 1.0)
	var cancel := _button(page, "ReturnKartPanel", "CancelButtonUp", "CancelButtonDown", "CancelButtonRollover", "CancelButtonUp", 1.0)
	_press(cancel, _cancel)
	_icon(cancel, "ReturnKartPanel", "CancelIcon")
	var ok := _button(page, "ReturnKartPanel", "CheckButtonUp", "CheckButtonDown", "CheckButtonRollover", "CheckButtonUp", 1.0)
	_press(ok, _return_ok)
	_icon(ok, "ReturnKartPanel", "CheckIcon")
	_words(page, "Are you sure you want to return your current Kart?", 0.0, -0.26 + _SHIFT, _SMALL * 0.9, 11.0 * _SMALL * 0.9, 5.0, _BLACK, false, false)


func _build_confirm_kart() -> void:
	var page := _page_root("confirm_kart")
	_panel(page, "ConfirmBuyKartPanel", "ConfirmBuyKartPanel", 1.0)
	var cancel := _button(page, "ConfirmBuyKartPanel", "CancelButtonUp", "CancelButtonDown", "CancelButtonRollover", "CancelButtonUp", 1.0)
	_press(cancel, _cancel)
	_icon(cancel, "ConfirmBuyKartPanel", "CancelIcon")
	var ok := _button(page, "ConfirmBuyKartPanel", "CheckButtonUp", "CheckButtonDown", "CheckButtonRollover", "CheckButtonUp", 1.0)
	_press(ok, _confirm_kart_ok)
	_icon(ok, "ConfirmBuyKartPanel", "CheckIcon")
	_confirm_kart = _words(page, "", 0.0, -0.26 + _SHIFT, _SMALL, 11.0 * _SMALL, 4.0, _BLACK, false, false)
	_tickets(page, 0.43, -0.5 + _SHIFT)


func _build_bought_kart() -> void:
	var page := _page_root("bought_kart")
	_panel(page, "BoughtKartPanel", "BoughtKartPanel", 1.0)
	var ok := _button(page, "BoughtKartPanel", "CheckButtonUp", "CheckButtonDown", "CheckButtonRollover", "CheckButtonUp", 1.0)
	_press(ok, _show.bind("main"))
	_icon(ok, "BoughtKartPanel", "CheckIcon")
	_words(page, "Congratulations!", 0.0, -0.26 + _SHIFT, _SMALL, 1.2, 1.6, _BLACK, false, false)
	_tickets(page, 0.43, -0.5 + _SHIFT)


func _build_accessory() -> void:
	var page := _page_root("accessory")
	_panel(page, "BuyAccessoryPanel", "BuyAccessoryPanel", 1.0)
	_acc_left = _button(page, "BuyAccessoryPanel", "ArrowLeftButtonUp", "ArrowLeftButtonDown", "ArrowLeftButtonRollover", "ArrowLeftButtonInactive", 1.0)
	_press(_acc_left, _step.bind(-1))
	_acc_right = _button(page, "BuyAccessoryPanel", "ArrowRightButtonUp", "ArrowRightButtonDown", "ArrowRightButtonRollover", "ArrowRightButtonInactive", 1.0)
	_press(_acc_right, _step.bind(1))
	_acc_spin_left = _spin_button(page, "BuyAccessoryPanel", "rotate_left", -1)
	_acc_spin_right = _spin_button(page, "BuyAccessoryPanel", "rotate_right", 1)
	_kind_buttons["hood"] = _kind_button(page, "EBlock", "hood")
	_kind_buttons["trunk"] = _kind_button(page, "Spoiler", "trunk")
	_kind_buttons["front"] = _kind_button(page, "Front", "front")
	_kind_buttons["back"] = _kind_button(page, "Rear", "back")
	_kind_buttons["rim"] = _kind_button(page, "Rim", "rim")
	_kind_buttons["decal"] = _kind_button(page, "Decal", "decal")
	_kind_buttons["color"] = _kind_button(page, "Paint", "color")
	_acc_buy_button = _button(page, "BuyAccessoryPanel", "BuyAccessoryButtonUp", "BuyAccessoryButtonDown", "BuyAccessoryButtonRollover", "BuyAccessoryButtonDisabled", 1.0)
	_press(_acc_buy_button, _buy_accessory_pressed)
	var cancel := _button(page, "BuyAccessoryPanel", "CancelButtonUp", "CancelButtonDown", "CancelButtonRollover", "CancelButtonUp", 1.0)
	_press(cancel, _cancel)
	_icon(cancel, "BuyAccessoryPanel", "CancelIcon")
	_acc_name = _words(page, "", 0.0, -0.33 + _SHIFT, _SMALL, 11.0 * _SMALL, 2.2, _BLACK, false, false)
	_acc_cost = _words(page, "", 0.0, -0.4 + _SHIFT, _SMALL, 1.2, 1.3, _BLACK, false, false)
	_acc_buy = _words(page, "Buy Accessory", 0.0, -0.57 + _SHIFT, _SMALL, 0.62, 1.4, _BLACK, false, false)
	_tickets(page, 0.42, -0.6 + _SHIFT)


func _build_confirm_accessory() -> void:
	var page := _page_root("confirm_acc")
	_panel(page, "ConfirmBuyAccessory", "ConfirmBuyAccessoryPanel", 1.0)
	var cancel := _button(page, "ConfirmBuyAccessory", "CancelButtonUp", "CancelButtonDown", "CancelButtonRollover", "CancelButtonUp", 1.0)
	_press(cancel, _cancel)
	_icon(cancel, "ConfirmBuyAccessory", "CancelIcon")
	var ok := _button(page, "ConfirmBuyAccessory", "CheckButtonUp", "CheckButtonDown", "CheckButtonRollover", "CheckButtonUp", 1.0)
	_press(ok, _confirm_acc_ok)
	_icon(ok, "ConfirmBuyAccessory", "CheckIcon")
	_confirm_acc = _words(page, "", 0.0, -0.25 + _SHIFT, _SMALL, 14.0 * _SMALL, 4.0, _BLACK, false, false)
	_tickets(page, 0.43, -0.5 + _SHIFT)


func _page_root(page_name: String) -> Control:
	var root := Control.new()
	root.name = page_name
	root.set_anchors_preset(PRESET_FULL_RECT)
	root.mouse_filter = MOUSE_FILTER_IGNORE
	root.visible = false
	add_child(root)
	_pages[page_name] = root
	return root


func _panel(page: Control, model: String, card_name: String, model_scale: float) -> void:
	var found := _card(model, card_name)
	if found.is_empty():
		return
	var panel := TextureRect.new()
	panel.texture = _texture_of(found)
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	panel.set_meta("card", found)
	panel.set_meta("scale", model_scale)
	page.add_child(panel)


func _button(page: Control, model: String, normal_name: String, down_name: String, over_name: String, off_name: String, model_scale: float) -> TextureButton:
	var found := _card(model, normal_name)
	if found.is_empty():
		return null
	var button := TextureButton.new()
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.texture_normal = _texture_of(found)
	var down := _texture(model, down_name)
	button.texture_pressed = down if down != null else button.texture_normal
	var over := _texture(model, over_name)
	button.texture_hover = over if over != null else button.texture_normal
	var off := _texture(model, off_name)
	button.texture_disabled = off if off != null else button.texture_normal
	button.set_meta("card", found)
	button.set_meta("scale", model_scale)
	page.add_child(button)
	return button


func _kind_button(page: Control, prefix: String, kind: String) -> TextureButton:
	var button := _button(
		page,
		"BuyAccessoryPanel",
		prefix + "ButtonUp",
		prefix + "ButtonDown",
		prefix + "ButtonRollover",
		prefix + "ButtonDown",
		1.0
	)
	_press(button, _choose_kind.bind(kind))
	return button


func _spin_button(page: Control, model: String, side: String, direction: int) -> TextureButton:
	var button := _button(
		page,
		model,
		side + "_up",
		side + "_down",
		side + "_roll",
		side + "_inactive",
		1.0
	)
	if button == null:
		return null
	button.button_down.connect(_set_spin.bind(direction))
	button.button_up.connect(_set_spin.bind(0))
	button.mouse_exited.connect(_set_spin.bind(0))
	var caption := Label.new()
	caption.text = "Left" if direction < 0 else "Right"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = MOUSE_FILTER_IGNORE
	caption.set_anchors_preset(PRESET_FULL_RECT)
	caption.set_meta("ts", 0.035)
	caption.set_meta("sign", true)
	caption.set_meta("color", Color.WHITE)
	caption.set_meta("outline", _BLACK)
	button.add_child(caption)
	_captions.append(caption)
	return button


func _press(button: TextureButton, call: Callable) -> void:
	if button != null:
		button.pressed.connect(call)


func _icon(button: TextureButton, model: String, card_name: String) -> void:
	if button == null:
		return
	var found := _card(model, card_name)
	var host: Dictionary = button.get_meta("card")
	if found.is_empty() or host.is_empty():
		return
	var icon := TextureRect.new()
	icon.texture = _texture_of(found)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	var bw := float(host["w"])
	var bh := float(host["h"])
	if bw < 0.001 or bh < 0.001:
		return
	var left := (float(found["x"]) - float(found["w"]) * 0.5 - (float(host["x"]) - bw * 0.5)) / bw
	var top := ((float(host["z"]) + bh * 0.5) - (float(found["z"]) + float(found["h"]) * 0.5)) / bh
	icon.anchor_left = left
	icon.anchor_right = left + float(found["w"]) / bw
	icon.anchor_top = top
	icon.anchor_bottom = top + float(found["h"]) / bh
	icon.offset_left = 0.0
	icon.offset_top = 0.0
	icon.offset_right = 0.0
	icon.offset_bottom = 0.0
	button.add_child(icon)


func _words(page: Control, text: String, x: float, z: float, text_scale: float, width: float, lines: float, color: Color, sign: bool, shadow: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.set_meta("x", x)
	label.set_meta("z", z)
	label.set_meta("ts", text_scale)
	label.set_meta("w", width)
	label.set_meta("h", text_scale * lines)
	label.set_meta("sign", sign)
	label.set_meta("color", color)
	label.set_meta("outline", _BLACK if shadow else Color(0, 0, 0, 0))
	page.add_child(label)
	return label


func _tickets(page: Control, x: float, z: float) -> void:
	var label := _words(page, "0", x, z, _SMALL, 0.35, 1.3, _YELLOW, true, true)
	_ticket_labels.append(label)


func _card(model: String, card_name: String) -> Dictionary:
	for entry in _cards.get(model, []):
		if entry is Dictionary and String((entry as Dictionary).get("name", "")) == card_name:
			return entry
	return {}


func _texture(model: String, card_name: String) -> Texture2D:
	var found := _card(model, card_name)
	if found.is_empty():
		return null
	return _texture_of(found)


func _texture_of(found: Dictionary) -> Texture2D:
	return load(_CARDS + String(found.get("file", ""))) as Texture2D


func _layout() -> void:
	var view := get_viewport_rect().size
	if view.y < 1.0:
		return
	for page in _pages.values():
		if not (page is Control):
			continue
		for child in (page as Control).get_children():
			if child.has_meta("card"):
				var card: Dictionary = child.get_meta("card")
				var model_scale := float(child.get_meta("scale"))
				_GUI.place(
					child,
					view,
					float(card["x"]) * model_scale,
					float(card["z"]) * model_scale + _SHIFT,
					maxf(float(card["w"]) * model_scale, 0.02),
					maxf(float(card["h"]) * model_scale, 0.02)
				)
			elif child.has_meta("ts"):
				_fit_label(child as Label, view)
	for caption in _captions:
		if caption == null:
			continue
		_GUI.style_sign(caption, Color.WHITE, _px(0.035, view), _BLACK, maxi(int(_px(0.035, view) / 12), 1))
	_cream.visible = _view_on
	_holder.visible = _view_on
	if _view_on:
		_GUI.place(_cream, view, _view_box.x, _view_box.y, _view_box.z, _view_box.w)
		_GUI.place(_holder, view, _view_box.x, _view_box.y, _view_box.z, _view_box.w)
		var pixels := Vector2i(maxi(int(_holder.size.x), 8), maxi(int(_holder.size.y), 8))
		if _view.size != pixels:
			_view.size = pixels
	_layout_clock(view)


func _fit_label(label: Label, view: Vector2) -> void:
	var text_scale := float(label.get_meta("ts"))
	var color: Color = label.get_meta("color")
	var outline: Color = label.get_meta("outline")
	var px := _px(text_scale, view)
	var outline_px := 0
	if outline.a > 0.0:
		outline_px = maxi(int(float(px) * 0.08), 1)
	if bool(label.get_meta("sign")):
		_GUI.style_sign(label, color, px, outline, outline_px)
	else:
		_GUI.style_label(label, color, px, outline, outline_px)
	_GUI.place(label, view, float(label.get_meta("x")), float(label.get_meta("z")), float(label.get_meta("w")), float(label.get_meta("h")))


func _layout_clock(view: Vector2) -> void:
	var clock_w := 0.7417 * 0.45
	var clock_h := 0.7292 * 0.45
	_GUI.place(_clock, view, 1.16, 0.83, clock_w, clock_h)
	var whole := maxi(int(ceil(_left)), 0)
	_clock_num.text = str(whole)
	var text_scale := 0.27
	if _clock_num.text.length() <= 1:
		text_scale = 0.34
	elif _clock_num.text.length() >= 3:
		text_scale = 0.2
	var late := whole <= 5
	_GUI.style_label(_clock_num, Color(1, 0, 0, 1) if late else _BLACK, _px(text_scale * 0.45, view), Color(0, 0, 0, 0), 0)
	var face_x := 1.16 + (28.5 / 61.0 - 0.5) * clock_w
	var face_z := 0.83 - (33.5 / 61.0 - 0.5) * clock_h
	_GUI.place(_clock_num, view, face_x, face_z, 0.26, 0.16)


func _px(scale: float, view: Vector2) -> int:
	return maxi(int(round(scale * view.y * 0.5)), 1)
