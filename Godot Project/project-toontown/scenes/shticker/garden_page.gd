extends Control

## GardenPage. Basket, Album, Trophies, and Specials. A new toon has the tin
## shovel, the small watering can, an empty basket of 20, and every album
## name still "????".

const _GARDEN := preload("res://scenes/estate/garden.gd")
const _BASKET := preload("res://assets/gui/shticker/flower_basket.png")
const _ALBUM := preload("res://assets/gui/shticker/fishing/album.png")
const _CASE := preload("res://assets/gui/shticker/fishing/trophy_case.png")
const _TAB := preload("res://assets/gui/shticker/fishing/page_tab.png")
const _SCROLL_UP := preload("res://assets/gui/friends/FndsLst_ScrollUp.png")
const _SCROLL_DOWN := preload("res://assets/gui/friends/FndsLst_ScrollDN.png")
const _SCROLL_HOVER := preload("res://assets/gui/friends/FndsLst_ScrollUp_Rllvr.png")

const _TITLES: PackedStringArray = ["Flower Basket", "Flower Album", "Gardening Trophies", "Gardening Specials"]
const _TAB_TEXT: PackedStringArray = ["Basket", "Album", "Trophies", "Specials"]
const _SHOVEL: PackedStringArray = ["Tin", "Bronze", "Silver", "Gold"]
const _CAN: PackedStringArray = ["Small", "Medium", "Large", "Huge"]
const _LETTERS := "RGOVBPYCS"
const _BEAN: Array[Color] = [
	Color(1, 0, 0), Color(0, 1, 0), Color(1, 0.647, 0), Color(0.58, 0, 0.827),
	Color(0, 0, 1), Color(1, 0.753, 0.796), Color(1, 1, 0), Color(0, 1, 1), Color(0.753, 0.753, 0.753),
]
const _BROWN := Color(0.2, 0.1, 0.0)
const _SELECTED := Color(1.0, 0.98, 0.15)
const _ROLLOVER := Color(0.15, 0.82, 1.0)
const _PRESSED := Color(0.8, 0.8, 0.0)
const _BAR_TEXT := Color(0.05, 0.14, 0.2)
const _VISIBLE := 10
const _BOXES := 8

const _DAISY: PackedStringArray = ["School Daisy", "Lazy Daisy", "Midsummer Daisy", "Freshasa Daisy", "Whoopsie Daisy", "Upsy Daisy", "Crazy Daisy", "Hazy Dazy"]
const _TULIP: PackedStringArray = ["Onelip", "Twolip", "Threelip"]
const _CARNATION: PackedStringArray = ["What-in Carnation", "Instant Carnation", "Hybrid Carnation", "Side Carnation", "Model Carnation"]
const _LILY: PackedStringArray = ["Lily-of-the-Alley", "Lily Pad", "Tiger Lily", "Livered Lily", "Chili Lily", "Silly Lily", "Indubitab Lily", "Dilly Lilly"]
const _DAFFODIL: PackedStringArray = ["Laff-o-dil", "Daffy Dill", "Giraff-o-dil", "Time and a half-o-dil"]
const _PANSY: PackedStringArray = ["Dandy Pansy", "Chim Pansy", "Potsen Pansy", "Marzi Pansy", "Smarty Pansy"]
const _PETUNIA: PackedStringArray = ["Car Petunia", "Platoonia"]
const _ROSE: PackedStringArray = ["Summer's Last Rose", "Corn Rose", "Tinted Rose", "Stinking Rose", "Istilla Rose"]

var _mode := 0
var _species := 0
var _variety := 0
var _picked := 0
var _basket_from := 0
var _page := Vector2.ZERO
var _title: Label
var _tabs: Array[TextureButton] = []
var _tab_names: Array[Label] = []
var _basket: Control
var _album: Control
var _trophies: Control
var _specials: Control
var _rows: Array[Button] = []
var _basket_art: TextureRect
var _basket_info: Label
var _detail_name: Label
var _detail_value: Label
var _shovel_bar: Control
var _can_bar: Control
var _basket_up: TextureButton
var _basket_down: TextureButton
var _album_art: TextureRect
var _species_name: Label
var _varieties: Array[Button] = []
var _beans: Array[ColorRect] = []
var _collected: Label
var _album_up: TextureButton
var _album_down: TextureButton


func _ready() -> void:
	name = "Gardening"
	mouse_filter = MOUSE_FILTER_IGNORE
	_title = Label.new()
	_title.name = "Title"
	_title.text = _TITLES[0]
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_title)
	for index in _TAB_TEXT.size():
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
		_tabs.append(tab)
		var caption := Label.new()
		caption.text = _TAB_TEXT[index]
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(caption)
		_tab_names.append(caption)
	_basket = _panel()
	_album = _panel()
	_trophies = _panel()
	_specials = _panel()
	_build_basket()
	_build_album()
	_build_trophies()
	_set_mode(0)


func layout(page_size: Vector2) -> void:
	_page = page_size
	var body_px := maxi(int(page_size.y * 0.034), 12)
	var tab_top := page_size.y * 0.1
	var tab_size := Vector2(page_size.x * 0.23, page_size.y * 0.075)
	for index in _tabs.size():
		var origin := Vector2(page_size.x * (0.02 + float(index) * 0.245), tab_top)
		_tabs[index].position = origin
		_tabs[index].size = tab_size
		_tab_names[index].position = origin
		_tab_names[index].size = tab_size
		ToonGui.style_label(_tab_names[index], _BROWN, body_px, Color(0, 0, 0, 0), 0)
	var body := Rect2(Vector2(0, tab_top + tab_size.y + page_size.y * 0.02), Vector2(page_size.x, page_size.y * 0.78))
	_place_basket(body, body_px)
	_place_album(body, body_px)
	_place_case(body)
	_paint()


func refresh() -> void:
	_paint()


func _panel() -> Control:
	var panel := Control.new()
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(PRESET_FULL_RECT)
	add_child(panel)
	return panel


func _build_basket() -> void:
	for index in _VISIBLE:
		var row := _text_button()
		row.pressed.connect(_choose_flower.bind(index))
		_basket.add_child(row)
		_rows.append(row)
	_basket_art = TextureRect.new()
	_basket_art.texture = _BASKET
	_basket_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_basket_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_basket_art.mouse_filter = MOUSE_FILTER_IGNORE
	_basket.add_child(_basket_art)
	_basket_info = _caption()
	_basket.add_child(_basket_info)
	_detail_name = _caption()
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_basket.add_child(_detail_name)
	_detail_value = _caption()
	_detail_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_basket.add_child(_detail_value)
	_shovel_bar = _meter(Color(0.6, 0.4, 0.2))
	_can_bar = _meter(Color(0.4, 0.6, 1.0))
	_basket.add_child(_shovel_bar)
	_basket.add_child(_can_bar)
	_basket_up = _scroll_button(false, _turn_basket.bind(-1))
	_basket_down = _scroll_button(true, _turn_basket.bind(1))
	_basket.add_child(_basket_up)
	_basket.add_child(_basket_down)


func _build_album() -> void:
	_album_art = TextureRect.new()
	_album_art.texture = _ALBUM
	_album_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_album_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_album_art.mouse_filter = MOUSE_FILTER_IGNORE
	_album.add_child(_album_art)
	_species_name = _caption()
	_album.add_child(_species_name)
	for index in _BOXES:
		var variety := _text_button()
		variety.pressed.connect(_choose_variety.bind(index))
		_album.add_child(variety)
		_varieties.append(variety)
		var bean := ColorRect.new()
		bean.mouse_filter = MOUSE_FILTER_IGNORE
		_album.add_child(bean)
		_beans.append(bean)
	_collected = _caption()
	_collected.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_album.add_child(_collected)
	_album_up = _scroll_button(false, _turn_species.bind(-1))
	_album_down = _scroll_button(true, _turn_species.bind(1))
	_album.add_child(_album_up)
	_album.add_child(_album_down)


func _build_trophies() -> void:
	var art := TextureRect.new()
	art.texture = _CASE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = MOUSE_FILTER_IGNORE
	_trophies.add_child(art)


func _caption() -> Label:
	var label := Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	return label


func _text_button() -> Button:
	var button := Button.new()
	button.focus_mode = FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("disabled", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.add_theme_color_override("font_hover_color", _ROLLOVER)
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 0))
	button.add_theme_color_override("font_disabled_color", Color(0.4, 0.8, 0.4))
	return button


func _meter(fill: Color) -> Control:
	var bar := Control.new()
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	var frame := ColorRect.new()
	frame.name = "Frame"
	frame.color = Color(0.8, 0.8, 0.7)
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	frame.set_anchors_preset(PRESET_FULL_RECT)
	bar.add_child(frame)
	var ink := ColorRect.new()
	ink.name = "Fill"
	ink.color = fill
	ink.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_child(ink)
	var label := Label.new()
	label.name = "Text"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_child(label)
	return bar


func _scroll_button(down: bool, call: Callable) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _SCROLL_DOWN if down else _SCROLL_UP
	button.texture_hover = _SCROLL_HOVER
	button.texture_pressed = _SCROLL_DOWN if down else _SCROLL_UP
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.focus_mode = FOCUS_NONE
	button.pressed.connect(call)
	return button


func _place_basket(body: Rect2, body_px: int) -> void:
	var row_h := body.size.y * 0.045
	var list_top := body.position.y + body.size.y * 0.02
	for index in _rows.size():
		var row := _rows[index]
		row.position = Vector2(body.position.x + body.size.x * 0.02, list_top + float(index) * row_h)
		row.size = Vector2(body.size.x * 0.34, row_h)
		_style_button(row, body_px)
	var arrow := Vector2(body.size.x * 0.045, body.size.x * 0.045)
	_basket_up.position = Vector2(body.position.x + body.size.x * 0.36, list_top)
	_basket_down.position = Vector2(_basket_up.position.x, list_top + row_h * float(_VISIBLE - 1))
	_basket_up.size = arrow
	_basket_down.size = arrow
	var basket_side := body.size.y * 0.34
	_basket_art.position = Vector2(body.position.x + body.size.x * 0.42, body.position.y + body.size.y * 0.08)
	_basket_art.size = Vector2(basket_side, basket_side)
	_basket_info.position = Vector2(body.position.x + body.size.x * 0.02, list_top + row_h * float(_VISIBLE) + body.size.y * 0.02)
	_basket_info.size = Vector2(body.size.x * 0.4, body.size.y * 0.12)
	ToonGui.style_label(_basket_info, _BROWN, body_px, Color(0, 0, 0, 0), 0)
	_detail_name.position = Vector2(body.position.x + body.size.x * 0.58, body.position.y + body.size.y * 0.16)
	_detail_name.size = Vector2(body.size.x * 0.38, body.size.y * 0.08)
	_detail_value.position = Vector2(_detail_name.position.x, _detail_name.position.y + body.size.y * 0.08)
	_detail_value.size = _detail_name.size
	ToonGui.style_label(_detail_name, _BROWN, body_px, Color(0, 0, 0, 0), 0)
	ToonGui.style_label(_detail_value, _BROWN, body_px, Color(0, 0, 0, 0), 0)
	var bar := Vector2(body.size.x * 0.58, body.size.y * 0.07)
	_shovel_bar.position = Vector2(body.position.x + body.size.x * 0.38, body.position.y + body.size.y * 0.72)
	_can_bar.position = Vector2(_shovel_bar.position.x, _shovel_bar.position.y + bar.y + body.size.y * 0.03)
	_shovel_bar.size = bar
	_can_bar.size = bar
	_style_meter(_shovel_bar, body_px)
	_style_meter(_can_bar, body_px)


func _place_album(body: Rect2, body_px: int) -> void:
	var side := minf(body.size.x * 0.92, body.size.y * 0.82)
	_album_art.position = Vector2(body.position.x + (body.size.x - side) * 0.5, body.position.y)
	_album_art.size = Vector2(side, side)
	var art := _album_art
	_species_name.position = Vector2(art.position.x + art.size.x * 0.08, art.position.y + art.size.y * 0.66)
	_species_name.size = Vector2(art.size.x * 0.4, art.size.y * 0.08)
	ToonGui.style_label(_species_name, _BROWN, body_px, Color(0, 0, 0, 0), 0)
	var row_h := art.size.y * 0.055
	var list_top := art.position.y + art.size.y * 0.18
	for index in _varieties.size():
		var variety := _varieties[index]
		variety.position = Vector2(art.position.x + art.size.x * 0.5, list_top + float(index) * row_h)
		variety.size = Vector2(art.size.x * 0.42, row_h)
		_style_button(variety, maxi(body_px - 2, 11))
		var bean := _beans[index]
		bean.position = Vector2(art.position.x + art.size.x * 0.08 + float(index) * art.size.x * 0.045, art.position.y + art.size.y * 0.8)
		bean.size = Vector2(art.size.x * 0.04, art.size.y * 0.045)
	_collected.position = Vector2(body.position.x, art.position.y + art.size.y + body.size.y * 0.01)
	_collected.size = Vector2(body.size.x, body.size.y * 0.08)
	ToonGui.style_label(_collected, _BROWN, body_px, Color(0, 0, 0, 0), 0)
	var arrow := Vector2(body.size.x * 0.06, body.size.x * 0.06)
	_album_up.position = Vector2(art.position.x + art.size.x * 0.5 - arrow.x * 0.5, art.position.y + art.size.y * 0.02)
	_album_down.position = Vector2(_album_up.position.x, art.position.y + art.size.y * 0.84)
	_album_up.size = arrow
	_album_down.size = arrow


func _place_case(body: Rect2) -> void:
	var art := _trophies.get_child(0) as TextureRect
	var side := minf(body.size.x * 0.8, body.size.y * 0.92)
	art.position = Vector2(body.position.x + (body.size.x - side) * 0.5, body.position.y)
	art.size = Vector2(side, side)


func _style_button(button: Button, px: int) -> void:
	button.add_theme_font_override("font", ToonGui.font())
	button.add_theme_font_size_override("font_size", maxi(px, 1))


func _style_meter(bar: Control, px: int) -> void:
	var label := bar.get_node("Text") as Label
	label.position = Vector2(bar.size.x * 0.03, 0)
	label.size = Vector2(bar.size.x * 0.94, bar.size.y)
	ToonGui.style_label(label, _BAR_TEXT, px, Color(0, 0, 0, 0), 0)


func _set_mode(mode: int) -> void:
	_mode = mode
	if _title != null:
		_title.text = _TITLES[mode]
	_basket.visible = mode == 0
	_album.visible = mode == 1
	_trophies.visible = mode == 2
	_specials.visible = mode == 3
	for index in _tabs.size():
		var chosen := index == mode
		_tabs[index].modulate = _SELECTED if chosen else Color.WHITE
		_tabs[index].mouse_filter = MOUSE_FILTER_IGNORE if chosen else MOUSE_FILTER_STOP
		_tabs[index].button_pressed = false
	_paint()


func _tint_tab(index: int, over: bool) -> void:
	if index == _mode:
		return
	_tabs[index].modulate = _ROLLOVER if over else Color.WHITE


func _press_tab(index: int) -> void:
	if index == _mode:
		return
	_tabs[index].modulate = _PRESSED


func _turn_basket(step: int) -> void:
	_basket_from = maxi(_basket_from + step, 0)
	_paint_basket()


func _turn_species(step: int) -> void:
	var rows: Array = _GARDEN.species_catalog()
	if rows.is_empty():
		return
	_species = clampi(_species + step, 0, rows.size() - 1)
	_variety = _first_variety()
	_paint_album()


func _choose_flower(row: int) -> void:
	_picked = _basket_from + row
	_paint_basket()


func _choose_variety(index: int) -> void:
	_variety = index
	_paint_album()


func _paint() -> void:
	if _rows.is_empty():
		return
	_paint_basket()
	_paint_album()


func _paint_basket() -> void:
	var items: Array = _GARDEN.basket_items()
	var count := items.size()
	var last := maxi(count - _VISIBLE, 0)
	_basket_from = clampi(_basket_from, 0, last)
	if _picked >= count:
		_picked = 0
	for index in _rows.size():
		var slot := _basket_from + index
		var row := _rows[index]
		row.visible = slot < count
		if slot >= count or not (items[slot] is Dictionary):
			continue
		var flower: Dictionary = items[slot]
		row.text = _funny(int(flower.get("species", 49)), int(flower.get("variety", 0)))
		row.add_theme_color_override("font_color", Color(1, 1, 0) if slot == _picked else _BROWN)
	_end_scroll(_basket_up, _basket_from == 0)
	_end_scroll(_basket_down, _basket_from >= last)
	_basket_info.text = "Basket: %d / %d\nValue: %d jellybeans" % [count, _GARDEN.basket_max(), _GARDEN.basket_value()]
	var showing := count > 0 and _picked < count and items[_picked] is Dictionary
	_detail_name.visible = showing
	_detail_value.visible = showing
	if showing:
		var flower: Dictionary = items[_picked]
		var worth := int(flower.get("value", 0))
		_detail_name.text = _funny(int(flower.get("species", 49)), int(flower.get("variety", 0)))
		_detail_value.text = "Value: %d jellybean" % worth if worth == 1 else "Value: %d jellybeans" % worth
	_fill_meter(_shovel_bar, "%s Shovel: %d / %d" % [_SHOVEL[_GARDEN.shovel()], _GARDEN.shovel_skill(), _GARDEN.shovel_goal()], _GARDEN.shovel_skill(), _GARDEN.shovel_goal())
	_fill_meter(_can_bar, "%s Watering Can: %d / %d" % [_CAN[_GARDEN.can()], _GARDEN.can_skill(), _GARDEN.can_goal()], _GARDEN.can_skill(), _GARDEN.can_goal())


func _paint_album() -> void:
	var rows: Array = _GARDEN.species_catalog()
	if rows.is_empty():
		return
	_species = clampi(_species, 0, rows.size() - 1)
	var row: Dictionary = rows[_species]
	var species := int(row.get("id", 49))
	var varieties: Array = row.get("varieties", [])
	var owned := _owned(species)
	if _variety >= varieties.size():
		_variety = _first_variety()
	_species_name.text = String(row.get("name", "????")) if owned else "????"
	var has_this := false
	for index in _varieties.size():
		var button := _varieties[index]
		var bean := _beans[index]
		button.visible = index < varieties.size()
		bean.visible = false
		if index >= varieties.size():
			continue
		var known := _has(species, index)
		button.disabled = not known
		button.text = _funny(species, index) if known else "????"
		button.add_theme_color_override("font_color", _BROWN)
		if index == _variety and known:
			has_this = true
			_species_name.text = _funny(species, index)
	if has_this and _variety < varieties.size() and varieties[_variety] is Dictionary:
		var recipe := String((varieties[_variety] as Dictionary).get("beans", ""))
		for index in _beans.size():
			var bean := _beans[index]
			bean.visible = index < _BOXES
			if index < recipe.length():
				var letter := recipe.unicode_at(index)
				var color_index := _LETTERS.find(char(letter))
				bean.color = _BEAN[color_index] if color_index >= 0 else Color(0.5, 0.5, 0.5)
			else:
				bean.color = Color(0.5, 0.5, 0.5, 0.45)
	_collected.text = "Flower Varieties Collected: %d of %d" % [_GARDEN.collected(), _GARDEN.variety_total()]
	_end_scroll(_album_up, _species == 0)
	_end_scroll(_album_down, _species >= rows.size() - 1)


func _fill_meter(bar: Control, text: String, skill: int, goal: int) -> void:
	var label := bar.get_node("Text") as Label
	label.text = text
	var ink := bar.get_node("Fill") as ColorRect
	var inset := 3.0
	var span := maxf(bar.size.x - inset * 2.0, 0.0)
	var ratio := 0.0 if goal <= 0 else clampf(float(skill) / float(goal), 0.0, 1.0)
	ink.position = Vector2(inset, inset)
	ink.size = Vector2(span * ratio, maxf(bar.size.y - inset * 2.0, 0.0))


func _end_scroll(button: TextureButton, stuck: bool) -> void:
	button.modulate = Color(0.7, 0.7, 0.7, 0.5) if stuck else Color.WHITE
	button.mouse_filter = MOUSE_FILTER_IGNORE if stuck else MOUSE_FILTER_STOP


func _owned(species: int) -> bool:
	for key in _GARDEN.collected_keys():
		if key.begins_with("%d:" % species):
			return true
	return false


func _has(species: int, variety: int) -> bool:
	return _GARDEN.collected_keys().has("%d:%d" % [species, variety])


func _first_variety() -> int:
	var rows: Array = _GARDEN.species_catalog()
	if _species < 0 or _species >= rows.size():
		return 0
	var species := int((rows[_species] as Dictionary).get("id", 49))
	var varieties: Array = (rows[_species] as Dictionary).get("varieties", [])
	for index in varieties.size():
		if _has(species, index):
			return index
	return 0


func _funny(species: int, variety: int) -> String:
	var table := _DAISY
	match species:
		50:
			table = _TULIP
		51:
			table = _CARNATION
		52:
			table = _LILY
		53:
			table = _DAFFODIL
		54:
			table = _PANSY
		55:
			table = _PETUNIA
		56:
			table = _ROSE
	if variety < 0 or variety >= table.size():
		return "????"
	return table[variety]
