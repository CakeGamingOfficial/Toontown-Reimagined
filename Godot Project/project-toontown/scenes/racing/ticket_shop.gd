extends Control

## KartShopGui. Buy a kart, or fill the 16-slot trunk once a kart is owned.
## Returning a kart is the confirm step before the new one replaces it.
## The clerk keeps the panel up for KartShopGlobals.KARTCLERK_TIMER seconds.

signal finished

const _GARAGE := preload("res://scenes/racing/kart_garage.gd")
const _MODEL := preload("res://scenes/racing/kart_model.gd")
const _GUI := preload("res://scenes/toons/toon_gui.gd")
const _SECONDS := 180.0

var _mode := "main"
var _kind := "hood"
var _index := 0
var _rows: Array = []
var _left := _SECONDS
var _title: Label
var _body: Label
var _tickets: Label
var _clock: Label
var _view: SubViewport
var _world: Node3D
var _kinds: PackedStringArray = ["hood", "trunk", "front", "back", "rim", "decal", "color"]
var _kind_names: PackedStringArray = ["Hood Accessories", "Trunk Accessories", "Front Wheel Accessories", "Back Wheel Accessories", "Rim Accessories", "Decal Accessories", "Kart Colors"]


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_preset(PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.12, 0.28, 0.45)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	add_child(dim)
	var panel := ColorRect.new()
	panel.color = Color(0.1, 0.35, 0.7, 0.94)
	panel.position = Vector2(180, 70)
	panel.size = Vector2(980, 560)
	add_child(panel)
	_title = _words(panel, Vector2(20, 12), Vector2(700, 40), 28)
	_tickets = _words(panel, Vector2(700, 12), Vector2(260, 40), 22)
	_clock = _words(panel, Vector2(20, 52), Vector2(200, 30), 18)
	_body = _words(panel, Vector2(340, 90), Vector2(610, 250), 22)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_view = SubViewport.new()
	_view.size = Vector2i(300, 220)
	_view.transparent_bg = true
	var holder := SubViewportContainer.new()
	holder.position = Vector2(20, 100)
	holder.size = Vector2(300, 220)
	holder.add_child(_view)
	panel.add_child(holder)
	_world = Node3D.new()
	_view.add_child(_world)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 2.4, 7.5)
	camera.look_at(Vector3(0, 0.6, 0), Vector3.UP)
	camera.current = true
	_world.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 20, 0)
	_world.add_child(light)
	_button(panel, "Buy Kart", Vector2(40, 360), _buy_karts)
	_button(panel, "Buy Accessories", Vector2(250, 360), _buy_accessories)
	_button(panel, "Previous", Vector2(40, 430), _previous)
	_button(panel, "Next", Vector2(250, 430), _next)
	_button(panel, "Buy", Vector2(460, 470), _confirm)
	_button(panel, "Category", Vector2(670, 470), _cycle_kind)
	_button(panel, "Cancel", Vector2(800, 360), _cancel)
	_show_main()


func _process(delta: float) -> void:
	_left -= delta
	_clock.text = "Time: %d" % int(ceil(_left))
	_tickets.text = "Tickets: %d" % _GARAGE.tickets()
	if _left <= 0.0:
		finished.emit()
		queue_free()


func _show_main() -> void:
	_mode = "main"
	_title.text = "Kart Shop"
	_body.text = "Buy a kart to race at Goofy Speedway.\nAccessories open once you own one.\nA new kart replaces the one you have."
	_show_kart(_GARAGE.dna())


func _buy_karts() -> void:
	_mode = "kart"
	_rows = _MODEL.karts()
	_index = 0
	_show_choice()


func _buy_accessories() -> void:
	if not _GARAGE.has_kart():
		_body.text = "You need a kart first! Try asking one of the clerks in the Kart Shop."
		return
	_mode = "accessory"
	_fill_accessories()
	_show_choice()


func _fill_accessories() -> void:
	_rows = []
	for card in _MODEL.of_kind(_kinds[_kind_index()]):
		if card is Dictionary and not _GARAGE.owns(int((card as Dictionary).get("id", -1))):
			_rows.append(card)
	if _index >= _rows.size():
		_index = 0


func _show_choice() -> void:
	if _mode == "kart" or _mode == "return":
		_title.text = "Buy Kart"
		if _rows.is_empty():
			_body.text = "No karts are for sale."
			return
		var card: Dictionary = _rows[_index]
		var cost := int(card.get("cost", 0))
		_body.text = "%s\nCost: %d Tickets\n%s" % [
			String(card.get("name", "Kart")), cost,
			"Not Enough Tickets!" if _GARAGE.tickets() < cost else "Buy the %s for %d Tickets?" % [String(card.get("name", "Kart")), cost],
		]
		var preview := _GARAGE.dna().duplicate()
		preview[0] = int(card.get("id", 0))
		_show_kart(preview)
		return
	_title.text = _kind_names[_kind_index()]
	if _GARAGE.owned().size() >= 16:
		_body.text = "Your trunk is full."
		return
	if _rows.is_empty():
		_body.text = "No available accessories of this type"
		_show_kart(_GARAGE.dna())
		return
	var card: Dictionary = _rows[_index]
	var cost := maxi(int(card.get("cost", 0)), 0)
	_body.text = "%s\nCost: %d Tickets\n%s" % [
		String(card.get("name", "Accessory")), cost,
		"Not Enough Tickets!" if _GARAGE.tickets() < cost else "Buy the %s for %d Tickets?" % [String(card.get("name", "Accessory")), cost],
	]
	var preview := _GARAGE.dna().duplicate()
	var field := _MODEL.field_for(_kinds[_kind_index()])
	preview[field] = int(card.get("id", -1))
	_show_kart(preview)


func _confirm() -> void:
	if _mode == "main" or _rows.is_empty():
		return
	var card: Dictionary = _rows[_index]
	if _mode == "kart":
		if _GARAGE.has_kart():
			_mode = "return"
			_body.text = "Are you sure you want to return your current Kart?"
			return
		_purchase_kart(card)
		return
	if _mode == "return":
		_purchase_kart(card)
		return
	var cost := maxi(int(card.get("cost", 0)), 0)
	var field := _MODEL.field_for(_kinds[_kind_index()])
	var reason := _GARAGE.buy_accessory(int(card.get("id", -1)), cost, field)
	_body.text = "Congratulations!" if reason.is_empty() else reason
	if reason.is_empty():
		_fill_accessories()
		_show_choice()


func _purchase_kart(card: Dictionary) -> void:
	var reason := _GARAGE.buy_kart(int(card.get("id", 0)), int(card.get("cost", 0)))
	if reason.is_empty():
		_body.text = "Congratulations!"
		_show_kart(_GARAGE.dna())
		_mode = "main"
	else:
		_body.text = reason


func _previous() -> void:
	if _rows.is_empty():
		return
	_index = posmod(_index - 1, _rows.size())
	_show_choice()


func _next() -> void:
	if _rows.is_empty():
		return
	_index = posmod(_index + 1, _rows.size())
	_show_choice()


func _cycle_kind() -> void:
	if _mode != "accessory":
		return
	_index = 0
	_kind = _kinds[(_kind_index() + 1) % _kinds.size()]
	_fill_accessories()
	_show_choice()


func _kind_index() -> int:
	var found := _kinds.find(_kind)
	return found if found >= 0 else 0


func _cancel() -> void:
	if _mode == "return":
		_mode = "kart"
		_show_choice()
		return
	if _mode != "main":
		_show_main()
		return
	finished.emit()
	queue_free()


func _show_kart(row: Array) -> void:
	for child in _world.get_children():
		if child is Camera3D or child is DirectionalLight3D:
			continue
		child.queue_free()
	if row.is_empty() or int(row[0]) < 0:
		return
	var kart := _MODEL.build(row)
	_world.add_child(kart)


func _words(parent: Control, at: Vector2, size: Vector2, px: int) -> Label:
	var label := Label.new()
	label.position = at
	label.size = size
	_GUI.style_label(label, Color.WHITE, px, Color(0, 0, 0, 1), 3)
	parent.add_child(label)
	return label


func _button(parent: Control, text: String, at: Vector2, call: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = Vector2(180, 48)
	button.pressed.connect(call)
	parent.add_child(button)
