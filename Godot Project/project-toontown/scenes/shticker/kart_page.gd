extends Control

## KartPage. Customize, Records, and Trophies. The kart itself is bought
## from a Speedway clerk. This page equips pieces already in the trunk.

const _GARAGE := preload("res://scenes/racing/kart_garage.gd")
const _MODEL := preload("res://scenes/racing/kart_model.gd")
const _RULES := preload("res://scenes/racing/kart_rules.gd")
const _GUI := preload("res://scenes/toons/toon_gui.gd")
const _BROWN := Color(0.2, 0.1, 0.0)

var _mode := 0
var _kind := "hood"
var _index := 0
var _title: Label
var _tabs: Array[Button] = []
var _sheets: Array[Control] = []
var _view: SubViewport
var _world: Node3D
var _detail: Label
var _tickets: Label
var _records: Label
var _trophies: Label
var _confirming := false


func _ready() -> void:
	name = "Karts"
	mouse_filter = MOUSE_FILTER_IGNORE
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_GUI.style_label(_title, _BROWN, 22, Color(0, 0, 0, 0), 0)
	add_child(_title)
	for caption in ["Customize", "Records", "Trophy"]:
		var tab := Button.new()
		tab.text = caption
		tab.focus_mode = FOCUS_NONE
		tab.pressed.connect(_set_mode.bind(_tabs.size()))
		add_child(tab)
		_tabs.append(tab)
		var sheet := Control.new()
		sheet.mouse_filter = MOUSE_FILTER_IGNORE
		sheet.set_anchors_preset(PRESET_FULL_RECT)
		add_child(sheet)
		_sheets.append(sheet)
	_build_customize()
	_records = _block(_sheets[1])
	_trophies = _block(_sheets[2])
	_set_mode(0)


func layout(page_size: Vector2) -> void:
	var body_px := maxi(int(page_size.y * 0.034), 12)
	_title.position = Vector2(0, page_size.y * 0.02)
	_title.size = Vector2(page_size.x, page_size.y * 0.08)
	_GUI.style_label(_title, _BROWN, maxi(int(page_size.y * 0.05), 16), Color(0, 0, 0, 0), 0)
	var tab_size := Vector2(page_size.x * 0.28, page_size.y * 0.07)
	for index in _tabs.size():
		_tabs[index].position = Vector2(page_size.x * (0.04 + float(index) * 0.32), page_size.y * 0.1)
		_tabs[index].size = tab_size
	var body := Rect2(Vector2(page_size.x * 0.04, page_size.y * 0.2), Vector2(page_size.x * 0.92, page_size.y * 0.74))
	for sheet in _sheets:
		sheet.position = body.position
		sheet.size = body.size
	if _detail != null:
		_detail.position = Vector2(body.size.x * 0.42, 8)
		_detail.size = Vector2(body.size.x * 0.56, body.size.y * 0.45)
		_GUI.style_label(_detail, _BROWN, body_px, Color(0, 0, 0, 0), 0)
	if _tickets != null:
		_tickets.position = Vector2(8, body.size.y * 0.86)
		_tickets.size = Vector2(body.size.x * 0.4, body.size.y * 0.1)
		_GUI.style_label(_tickets, Color(0, 0, 0.7), body_px, Color(0, 0, 0, 0), 0)
	_records.position = Vector2(8, 8)
	_records.size = body.size - Vector2(16, 16)
	_trophies.position = _records.position
	_trophies.size = _records.size
	_GUI.style_label(_records, _BROWN, body_px, Color(0, 0, 0, 0), 0)
	_GUI.style_label(_trophies, _BROWN, body_px, Color(0, 0, 0, 0), 0)


func refresh() -> void:
	_tickets.text = "Tickets : %d" % _GARAGE.tickets()
	var lines := ""
	for track_id in _RULES.TRACK_IDS:
		var best := _GARAGE.personal_best(track_id)
		var shown := "N/A" if best <= 0.0 else _RULES.clock(best)
		lines += "%s: %s\n" % [_RULES.track_name(track_id), shown]
	_records.text = lines
	var trophies := ""
	var flags := _GARAGE.trophy_flags()
	for index in range(33):
		var mark := "Won" if int(flags[index]) == 1 else "Locked"
		trophies += "%s - %s\n" % [_RULES.trophy_text(index), mark]
	_trophies.text = trophies
	_paint_detail()
	_show_kart()


func _set_mode(index: int) -> void:
	_mode = index
	var titles: PackedStringArray = ["Kart Customizer", "Personal Best Records", "Racing Trophies"]
	_title.text = titles[index]
	for sheet_index in _sheets.size():
		_sheets[sheet_index].visible = sheet_index == index
	refresh()


func _build_customize() -> void:
	var sheet := _sheets[0]
	_view = SubViewport.new()
	_view.size = Vector2i(280, 180)
	_view.transparent_bg = true
	var holder := SubViewportContainer.new()
	holder.name = "View"
	holder.position = Vector2(8, 8)
	holder.size = Vector2(280, 180)
	holder.add_child(_view)
	sheet.add_child(holder)
	_world = Node3D.new()
	_view.add_child(_world)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 2.2, 7.0)
	camera.look_at(Vector3(0, 0.5, 0), Vector3.UP)
	camera.current = true
	_world.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 25, 0)
	_world.add_child(light)
	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet.add_child(_detail)
	_tickets = Label.new()
	sheet.add_child(_tickets)
	_small(sheet, "Category", Vector2(8, 200), _cycle)
	_small(sheet, "Previous", Vector2(8, 250), _step.bind(-1))
	_small(sheet, "Next", Vector2(150, 250), _step.bind(1))
	_small(sheet, "Select", Vector2(8, 300), _equip)
	_small(sheet, "Delete", Vector2(150, 300), _delete)


func _paint_detail() -> void:
	if not _GARAGE.has_kart():
		_detail.text = "You need a kart first! Try asking one of the clerks in the Kart Shop."
		return
	var owned := _owned_here()
	var names: PackedStringArray = ["Hood", "Trunk", "Front Wheel", "Back Wheel", "Rim", "Decal", "Kart Color", "Accessory Color"]
	var kind_index := ["hood", "trunk", "front", "back", "rim", "decal", "color", "accent"].find(_kind)
	_detail.text = names[kind_index] if kind_index >= 0 else "Accessory"
	if owned.is_empty():
		_detail.text += "\nNo Accessories Owned"
		return
	_index = clampi(_index, 0, owned.size() - 1)
	var card: Dictionary = owned[_index]
	_detail.text += "\n%s" % String(card.get("name", "Accessory"))
	if _confirming:
		_detail.text += "\nDelete Accessory?"


func _owned_here() -> Array:
	var rows: Array = []
	for card in _MODEL.of_kind("color" if _kind == "accent" else _kind):
		if not (card is Dictionary):
			continue
		var acc_id := int((card as Dictionary).get("id", -1))
		if _GARAGE.owns(acc_id) or (_kind == "rim" and acc_id == 40):
			rows.append(card)
	rows.append({"id": -1, "name": "No Accessory"})
	return rows


func _field() -> int:
	if _kind == "accent":
		return 2
	if _kind == "color":
		return 1
	return _MODEL.field_for(_kind)


func _cycle() -> void:
	var order: PackedStringArray = ["hood", "trunk", "front", "back", "rim", "decal", "color", "accent"]
	var found := order.find(_kind)
	_kind = order[(found + 1) % order.size()]
	_index = 0
	_confirming = false
	refresh()


func _step(direction: int) -> void:
	var owned := _owned_here()
	if owned.is_empty():
		return
	_index = posmod(_index + direction, owned.size())
	_confirming = false
	refresh()


func _equip() -> void:
	if not _GARAGE.has_kart():
		return
	var owned := _owned_here()
	if owned.is_empty():
		return
	var card: Dictionary = owned[_index]
	_GARAGE.equip(_field(), int(card.get("id", -1)))
	_confirming = false
	refresh()


func _delete() -> void:
	var owned := _owned_here()
	if owned.is_empty():
		return
	var acc_id := int((owned[_index] as Dictionary).get("id", -1))
	if acc_id < 0:
		return
	if not _confirming:
		_confirming = true
		refresh()
		return
	_GARAGE.delete_accessory(acc_id)
	_confirming = false
	refresh()


func _show_kart() -> void:
	if _world == null:
		return
	for child in _world.get_children():
		if child is Camera3D or child is DirectionalLight3D:
			continue
		child.queue_free()
	if not _GARAGE.has_kart():
		return
	_world.add_child(_MODEL.build())


func _block(sheet: Control) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet.add_child(label)
	return label


func _small(parent: Control, text: String, at: Vector2, call: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = Vector2(130, 40)
	button.pressed.connect(call)
	parent.add_child(button)
