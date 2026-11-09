extends Control

## GardenPage. The shovel, the watering can, the flower basket, the album,
## and which gag levels are organic.

const _GARDEN := preload("res://scenes/estate/garden.gd")
const _GUI := preload("res://scenes/toons/toon_gui.gd")
const _BROWN := Color(0.2, 0.1, 0.0)
const _GAGS: PackedStringArray = ["Toon-Up", "Trap", "Lure", "Sound", "Throw", "Squirt", "Drop"]

var _title: Label
var _body: Label
var _sell: Button


func _ready() -> void:
	name = "Gardening"
	mouse_filter = MOUSE_FILTER_IGNORE
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_GUI.style_label(_title, _BROWN, 22, Color(0, 0, 0, 0), 0)
	add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_body)
	_sell = Button.new()
	_sell.text = "Sell Basket"
	_sell.pressed.connect(_sell_basket)
	add_child(_sell)


func layout(page_size: Vector2) -> void:
	var body_px := maxi(int(page_size.y * 0.034), 12)
	_title.position = Vector2(0, page_size.y * 0.03)
	_title.size = Vector2(page_size.x, page_size.y * 0.08)
	_GUI.style_label(_title, _BROWN, maxi(int(page_size.y * 0.05), 16), Color(0, 0, 0, 0), 0)
	_body.position = Vector2(page_size.x * 0.06, page_size.y * 0.14)
	_body.size = Vector2(page_size.x * 0.88, page_size.y * 0.68)
	_GUI.style_label(_body, _BROWN, body_px, Color(0, 0, 0, 0), 0)
	_sell.position = Vector2(page_size.x * 0.3, page_size.y * 0.84)
	_sell.size = Vector2(page_size.x * 0.4, page_size.y * 0.08)


func refresh() -> void:
	_title.text = "Gardening"
	var organic := ""
	for track in _GAGS.size():
		var level := _GARDEN.organic_level(track)
		if level >= 0:
			organic += "%s organic through level %d\n" % [_GAGS[track], level + 1]
	if organic.is_empty():
		organic = "No organic gags yet. Pick a ripe gag tree.\n"
	_body.text = "%s  skill %d\n%s  skill %d\nFlower varieties: %d of %d\nBasket: %d jellybeans\n\n%s" % [
		_GARDEN.shovel_name(), _GARDEN.shovel_skill(),
		_GARDEN.can_name(), _GARDEN.can_skill(),
		_GARDEN.collected(), _GARDEN.variety_total(),
		_GARDEN.basket_value(), organic,
	]


func _sell_basket() -> void:
	var earned := _GARDEN.sell_basket()
	refresh()
	_body.text = "You sold your flowers for %d jellybeans.\n\n%s" % [earned, _body.text]
