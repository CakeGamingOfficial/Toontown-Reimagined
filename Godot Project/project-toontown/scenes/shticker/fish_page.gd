extends Control

## FishPage. Bucket, Album, and Trophies, in that order. A new toon has the
## twig rod and an empty bucket of 20, so every album name is still "???" and
## the trophy case is bare. Catching fish is what fills them in.

const _TANK := preload("res://scenes/fishing/fish_tank.gd")
const _ROLL := preload("res://scenes/fishing/fish_roll.gd")
const _BUCKET := preload("res://assets/gui/shticker/fishing/bucket.png")
const _ALBUM := preload("res://assets/gui/shticker/fishing/album.png")
const _CASE := preload("res://assets/gui/shticker/fishing/trophy_case.png")
const _TAB := preload("res://assets/gui/shticker/fishing/page_tab.png")
const _SCROLL_UP := preload("res://assets/gui/friends/FndsLst_ScrollUp.png")
const _SCROLL_DOWN := preload("res://assets/gui/friends/FndsLst_ScrollDN.png")
const _SCROLL_HOVER := preload("res://assets/gui/friends/FndsLst_ScrollUp_Rllvr.png")

# FishGlobals genus order, and how many species each one has. 70 in all.
const _SPECIES: PackedInt32Array = [5, 5, 4, 1, 5, 1, 5, 2, 3, 3, 6, 4, 4, 8, 3, 5, 5, 1]
const _TOTAL := 70
const _TITLES: PackedStringArray = ["Fish Bucket", "Fish Album", "Fishing Trophies"]
const _TAB_TEXT: PackedStringArray = ["Bucket", "Album", "Trophies"]
const _BROWN := Color(0.2, 0.1, 0.0)
const _SELECTED := Color(1.0, 0.98, 0.15)
const _ROLLOVER := Color(0.15, 0.82, 1.0)
const _PRESSED := Color(0.8, 0.8, 0.0)

var _mode := 0
var _genus := 0
var _title: Label
var _tabs: Array[TextureButton] = []
var _tab_names: Array[Label] = []
var _bucket: Control
var _album: Control
var _trophies: Control
var _album_art: TextureRect
var _species: Array[Label] = []
var _genus_name: Label
var _scroll_up: TextureButton
var _scroll_down: TextureButton


func _ready() -> void:
	name = "Fishing"
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
	_bucket = _panel()
	_album = _panel()
	_trophies = _panel()
	_build_bucket()
	_build_album()
	_build_trophies()
	_set_mode(0)


func layout(page_size: Vector2) -> void:
	var body_px := maxi(int(page_size.y * 0.038), 13)
	var tab_top := page_size.y * 0.1
	var tab_size := Vector2(page_size.x * 0.28, page_size.y * 0.075)
	for index in _tabs.size():
		var origin := Vector2(page_size.x * (0.04 + float(index) * 0.32), tab_top)
		_tabs[index].position = origin
		_tabs[index].size = tab_size
		_tab_names[index].position = origin
		_tab_names[index].size = tab_size
		ToonGui.style_label(_tab_names[index], _BROWN, body_px, Color(0, 0, 0, 0), 0)
	var body := Rect2(Vector2(0, tab_top + tab_size.y + page_size.y * 0.02), Vector2(page_size.x, page_size.y * 0.78))
	_place_bucket(body, body_px)
	_place_album(body, body_px)
	_place_case(body)


func refresh() -> void:
	var info := _bucket.get_node_or_null("Info") as Label
	if info != null:
		info.text = "Bucket: %d / %d\nValue: %d jellybeans" % [_TANK.count(), _TANK.max_count(), _TANK.value()]
	var total := _album.get_node_or_null("Total") as Label
	if total != null:
		total.text = "Fish Species Collected: %d of %d" % [_TANK.collected(), _TOTAL]
	var rod_label := _bucket.get_node_or_null("Rod") as Label
	if rod_label != null:
		var which := _TANK.rod()
		rod_label.text = "%s Rod\n%d - %d Pounds" % [_ROLL.rod_name(which), _ROLL.min_pounds(which), _ROLL.max_pounds(which)]
	_show_genus()


func _panel() -> Control:
	var panel := Control.new()
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(PRESET_FULL_RECT)
	add_child(panel)
	return panel


func _build_bucket() -> void:
	var art := TextureRect.new()
	art.name = "Bucket"
	art.texture = _BUCKET
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = MOUSE_FILTER_IGNORE
	_bucket.add_child(art)
	var info := Label.new()
	info.name = "Info"
	info.text = "Bucket: 0 / 20\nValue: 0 jellybeans"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info.mouse_filter = MOUSE_FILTER_IGNORE
	_bucket.add_child(info)
	var rod := Label.new()
	rod.name = "Rod"
	rod.text = "Twig Rod\n0 - 4 Pounds"
	rod.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rod.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rod.mouse_filter = MOUSE_FILTER_IGNORE
	_bucket.add_child(rod)


func _build_album() -> void:
	_album_art = TextureRect.new()
	_album_art.texture = _ALBUM
	_album_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_album_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_album_art.mouse_filter = MOUSE_FILTER_IGNORE
	_album.add_child(_album_art)
	_genus_name = Label.new()
	_genus_name.text = "???"
	_genus_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_genus_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_genus_name.mouse_filter = MOUSE_FILTER_IGNORE
	_album.add_child(_genus_name)
	for _index in 8:
		var species := Label.new()
		species.text = "???"
		species.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		species.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		species.mouse_filter = MOUSE_FILTER_IGNORE
		_album.add_child(species)
		_species.append(species)
	var total := Label.new()
	total.name = "Total"
	total.text = "Fish Species Collected: 0 of %d" % _TOTAL
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	total.mouse_filter = MOUSE_FILTER_IGNORE
	_album.add_child(total)
	_scroll_up = _scroll_button(false)
	_scroll_down = _scroll_button(true)
	_album.add_child(_scroll_up)
	_album.add_child(_scroll_down)


func _build_trophies() -> void:
	var art := TextureRect.new()
	art.texture = _CASE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = MOUSE_FILTER_IGNORE
	_trophies.add_child(art)


func _scroll_button(down: bool) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _SCROLL_DOWN if down else _SCROLL_UP
	button.texture_hover = _SCROLL_HOVER
	button.texture_pressed = _SCROLL_DOWN if down else _SCROLL_UP
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.focus_mode = FOCUS_NONE
	button.pressed.connect(_turn_genus.bind(1 if down else -1))
	return button


func _place_bucket(body: Rect2, body_px: int) -> void:
	var art := _bucket.get_node("Bucket") as TextureRect
	art.position = Vector2(body.position.x + body.size.x * 0.42, body.position.y)
	art.size = Vector2(body.size.x * 0.56, body.size.y * 0.92)
	var info := _bucket.get_node("Info") as Label
	info.position = Vector2(body.position.x, body.position.y + body.size.y * 0.28)
	info.size = Vector2(body.size.x * 0.42, body.size.y * 0.28)
	ToonGui.style_label(info, _BROWN, body_px, Color(0, 0, 0, 0), 0)
	var rod := _bucket.get_node("Rod") as Label
	rod.position = Vector2(art.position.x + art.size.x * 0.18, art.position.y + art.size.y * 0.86)
	rod.size = Vector2(art.size.x * 0.64, art.size.y * 0.1)
	ToonGui.style_label(rod, _BROWN, body_px, Color(0, 0, 0, 0), 0)


func _place_album(body: Rect2, body_px: int) -> void:
	var side := minf(body.size.x * 0.92, body.size.y * 0.82)
	_album_art.position = Vector2(body.position.x + (body.size.x - side) * 0.5, body.position.y)
	_album_art.size = Vector2(side, side)
	var art := _album_art
	_genus_name.position = Vector2(art.position.x + art.size.x * 0.08, art.position.y + art.size.y * 0.72)
	_genus_name.size = Vector2(art.size.x * 0.38, art.size.y * 0.08)
	ToonGui.style_label(_genus_name, _BROWN, body_px, Color(0, 0, 0, 0), 0)
	var row_h := art.size.y * 0.055
	var list_top := art.position.y + art.size.y * 0.22
	for index in _species.size():
		var species := _species[index]
		species.position = Vector2(art.position.x + art.size.x * 0.52, list_top + float(index) * row_h)
		species.size = Vector2(art.size.x * 0.4, row_h)
		ToonGui.style_label(species, _BROWN, maxi(body_px - 2, 11), Color(0, 0, 0, 0), 0)
	var total := _album.get_node("Total") as Label
	total.position = Vector2(body.position.x, art.position.y + art.size.y + body.size.y * 0.01)
	total.size = Vector2(body.size.x, body.size.y * 0.08)
	ToonGui.style_label(total, _BROWN, body_px, Color(0, 0, 0, 0), 0)
	var arrow := Vector2(body.size.x * 0.06, body.size.x * 0.06)
	_scroll_up.position = Vector2(art.position.x + art.size.x * 0.5 - arrow.x * 0.5, art.position.y + art.size.y * 0.02)
	_scroll_down.position = Vector2(_scroll_up.position.x, art.position.y + art.size.y * 0.84)
	_scroll_up.size = arrow
	_scroll_down.size = arrow
	_show_genus()


func _place_case(body: Rect2) -> void:
	var art := _trophies.get_child(0) as TextureRect
	var side := minf(body.size.x * 0.8, body.size.y * 0.92)
	art.position = Vector2(body.position.x + (body.size.x - side) * 0.5, body.position.y)
	art.size = Vector2(side, side)


func _set_mode(mode: int) -> void:
	_mode = mode
	if _title != null:
		_title.text = _TITLES[mode]
	_bucket.visible = mode == 0
	_album.visible = mode == 1
	_trophies.visible = mode == 2
	for index in _tabs.size():
		var chosen := index == mode
		_tabs[index].modulate = _SELECTED if chosen else Color.WHITE
		_tabs[index].mouse_filter = MOUSE_FILTER_IGNORE if chosen else MOUSE_FILTER_STOP
		_tabs[index].button_pressed = false


func _tint_tab(index: int, over: bool) -> void:
	if index == _mode:
		return
	_tabs[index].modulate = _ROLLOVER if over else Color.WHITE


func _press_tab(index: int) -> void:
	if index == _mode:
		return
	_tabs[index].modulate = _PRESSED


func _turn_genus(step: int) -> void:
	_genus = clampi(_genus + step, 0, _SPECIES.size() - 1)
	_show_genus()


func _show_genus() -> void:
	if _species.is_empty():
		return
	var count := _SPECIES[_genus]
	_genus_name.text = _TANK.genus_name(_genus) if _TANK.has_genus(_genus) else "???"
	for index in _species.size():
		_species[index].visible = index < count
		if index < count:
			_species[index].text = _TANK.species_name(_genus * 2, index) if _TANK.has_species(_genus, index) else "???"
	_scroll_up.modulate = Color(0.7, 0.7, 0.7, 0.5) if _genus == 0 else Color.WHITE
	_scroll_up.mouse_filter = MOUSE_FILTER_IGNORE if _genus == 0 else MOUSE_FILTER_STOP
	var last := _genus == _SPECIES.size() - 1
	_scroll_down.modulate = Color(0.7, 0.7, 0.7, 0.5) if last else Color.WHITE
	_scroll_down.mouse_filter = MOUSE_FILTER_IGNORE if last else MOUSE_FILTER_STOP
