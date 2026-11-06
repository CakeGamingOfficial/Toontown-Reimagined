extends Control

## Clarabelle's Cattlelog. One series week, plus whatever she sells this month.
## The week changes every seven days across the 78-week schedule.
## Wallpaper, flooring, and furniture can be ordered. The house does not
## redecorate with them yet.

signal finished

const _CLOSET := preload("res://scenes/catalog/catalog_closet.gd")
const _BEANS := preload("res://scenes/toons/jellybeans.gd")
const _ISSUE := "res://assets/catalog/issue.json"
const _PAGE := preload("res://assets/gui/catalog/background.png")
const _CLARA := preload("res://assets/gui/catalog/clarabelle.png")
const _CLARA_COLS := 11
const _CLARA_CELL: int = 128
const _CLARA_FRAMES := 242
const _HANG_UP := preload("res://assets/gui/catalog/hangup.png")
const _HANG_HOVER := preload("res://assets/gui/catalog/hangup_hover.png")
const _NEXT_UP := preload("res://assets/gui/catalog/next_up.png")
const _NEXT_DOWN := preload("res://assets/gui/catalog/next_down.png")
const _NEXT_HOVER := preload("res://assets/gui/catalog/next_hover.png")
const _PREV_UP := preload("res://assets/gui/catalog/prev_up.png")
const _PREV_DOWN := preload("res://assets/gui/catalog/prev_down.png")
const _PREV_HOVER := preload("res://assets/gui/catalog/prev_hover.png")
const _BUY_UP := preload("res://assets/gui/friends/InventoryButtonUp.png")
const _BUY_DOWN := preload("res://assets/gui/rules/InventoryButtonDown.png")
const _BUY_HOVER := preload("res://assets/gui/rules/InventoryButtonRollover.png")
const _SCALE := 0.667
const _CELLS: Array[Vector2] = [
	Vector2(-0.95, 0.91), Vector2(-0.275, 0.91),
	Vector2(-0.95, 0.275), Vector2(-0.275, 0.275),
	Vector2(-0.95, -0.4), Vector2(-0.275, -0.4),
]
const _PINK := Color(0.918, 0.69, 0.69, 0.92)
const _CREAM := Color(0.922, 0.922, 0.753, 0.92)
const _BLUE := Color(0.733, 0.78, 0.933, 0.92)
const _BODY := preload("res://scenes/toons/toon_body.gdshader")
const _ACCESSORIES := "res://assets/toons/accessories/catalog.json"
const _TANK := preload("res://scenes/fishing/fish_tank.gd")
const _SHOE_LEGS := "res://assets/toons/parts/legs_s.glb"
## CatalogItem.makeFrameModel pitches the picture 20 degrees and turns it
## once every 10 seconds, from heading 90 to -270.
const _SPIN_SECONDS := 10.0
const _GREETING := "Hello! Thanks for calling Clarabelle's Cattlelog. Can I help you?"
const _BOUGHT := "Congratulations on your new purchase!  You can start using it right away."
const _BROKE := "You don't have enough jellybeans for that."
const _OWNED := "You already have that."

var _style: ToonStyle
var _actor: ToonActor
var _items: Array[Dictionary] = []
var _page := 0
var _panels: Array[Control] = []
var _balloon: _Balloon
var _note: Label
var _spoken := ""
var _beans: Label
var _page_label: Label
var _next: TextureButton
var _prev: TextureButton
var _clara: TextureRect
var _clara_frame: AtlasTexture
var _clara_time := 0.0
var _spin_base := 0.0
static var _accessory_book: Dictionary = {}


func open(style: ToonStyle, actor: ToonActor) -> void:
	_style = style
	_actor = actor
	_items = _issue(style)
	_page = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var page := TextureRect.new()
	page.texture = _PAGE
	page.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	page.set_meta("place", Vector3(0.0, 0.025, 0.0))
	page.set_meta("box", Vector2(4.0 * _SCALE, 3.0 * _SCALE))
	_clara_frame = AtlasTexture.new()
	_clara_frame.atlas = _CLARA
	_clara_frame.region = Rect2(0, 0, _CLARA_CELL, _CLARA_CELL)
	_clara = TextureRect.new()
	_clara.texture = _clara_frame
	_clara.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_clara.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_clara.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clara)
	# clarabelle_frame sits on the right of catalog_gui. The portrait is inset
	# so the green border stays visible.
	_clara.set_meta("place", Vector3(0.536, 0.406, 0.0))
	_clara.set_meta("box", Vector2(0.58, 0.58))
	_beans = _sign()
	_beans.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_beans.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_seat_bean_bank()
	_page_label = _mark(_sign(), Vector2(-1.15, -0.9), Vector2(0.5, 0.1))
	# ChatBalloon sits on the catalog at (0.7, 0, 0.6), scale 0.08, so the
	# bubble is on the green frame instead of the item pages.
	_balloon = _Balloon.new()
	_balloon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_balloon.z_index = 4
	add_child(_balloon)
	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_balloon.add_child(_note)
	_prev = _arrow(_PREV_UP, _PREV_DOWN, _PREV_HOVER, _turn.bind(-1))
	_mark(_prev, Vector2(-0.28, -0.9), Vector2(0.12, 0.12))
	# arrowUp is the same card as arrow_up, mirrored on the model. The crop is not.
	_prev.scale.x = -1.0
	_next = _arrow(_NEXT_UP, _NEXT_DOWN, _NEXT_HOVER, _turn.bind(1))
	_mark(_next, Vector2(0.02, -0.9), Vector2(0.12, 0.12))
	var hang := _arrow(_HANG_UP, _HANG_HOVER, _HANG_HOVER, _hang_up)
	_mark(hang, Vector2(1.78, -1.3), Vector2(0.28, 0.28))
	_mark(_caption("Hang Up"), Vector2(1.78, -1.02), Vector2(0.4, 0.08))
	for index in _CELLS.size():
		var panel := _cell()
		_mark(panel, _CELLS[index], Vector2(0.40, 0.36))
		_panels.append(panel)
	if not get_viewport().size_changed.is_connected(_layout):
		get_viewport().size_changed.connect(_layout)
	_layout()
	_show_page()


func _process(delta: float) -> void:
	if _clara_frame == null:
		return
	_clara_time += delta
	var frame := int(_clara_time * 24.0) % _CLARA_FRAMES
	var col := frame % _CLARA_COLS
	var row := int(frame / _CLARA_COLS)
	_clara_frame.region = Rect2(col * _CLARA_CELL, row * _CLARA_CELL, _CLARA_CELL, _CLARA_CELL)
	var turn := fposmod(_clara_time - _spin_base, _SPIN_SECONDS) / _SPIN_SECONDS
	var heading := deg_to_rad(90.0 - turn * 360.0)
	for panel in _panels:
		var picture := panel.get_node_or_null("Picture") as CanvasItem
		if picture == null or not picture.visible:
			continue
		var spin := panel.get_node_or_null("Picture/View/Pitch/Spin") as Node3D
		if spin:
			spin.rotation.y = heading


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.y < 2.0:
		return
	position = Vector2.ZERO
	size = view
	for child in get_children():
		if child is ColorRect:
			child.position = Vector2.ZERO
			child.size = view
			continue
		if not child.has_meta("at") and not child.has_meta("place"):
			continue
		var at := Vector2(child.get_meta("at")) if child.has_meta("at") else Vector2.ZERO
		if child.has_meta("place"):
			var placed: Vector3 = child.get_meta("place")
			at = Vector2(placed.x, placed.y)
		else:
			at = Vector2(at.x * _SCALE, at.y * _SCALE + 0.025)
		var box: Vector2 = child.get_meta("box", Vector2(0.4, 0.2))
		ToonGui.place(child, view, at.x, at.y, box.x, box.y)
	_style_signs(view)
	_place_balloon(view)
	_layout_cells()


func _style_signs(view: Vector2) -> void:
	# beanBank text_scale is 0.11 under the catalog's 0.667 scale.
	var bean_px := maxi(int(round(0.11 * _SCALE * view.y * 0.5)), 12)
	ToonGui.style_sign(_beans, Color(0.95, 0.95, 0), bean_px, Color(0, 0, 0), 2)
	ToonGui.style_sign(_page_label, Color(0.95, 0.95, 0), maxi(int(view.y * 0.028), 11), Color(0, 0, 0), 2)


## The piggy bank is drawn on catalog_background. Its white screen is this
## part of that card. The number is right-aligned so it stays inside the frame.
func _seat_bean_bank() -> void:
	var page := Vector2(4.0 * _SCALE, 3.0 * _SCALE)
	var uv := Vector2(0.6461, 0.7448)
	var screen := Vector2(0.0891, 0.0583)
	var center := Vector2(
		-page.x * 0.5 + uv.x * page.x,
		0.025 + page.y * 0.5 - uv.y * page.y
	)
	var box := Vector2(screen.x * page.x, screen.y * page.y)
	var pad := Vector2(box.x * 0.1, box.y * 0.16)
	var right := center.x + box.x * 0.5 - pad.x
	box -= pad
	center.x = right - box.x * 0.5
	_beans.set_meta("place", Vector3(center.x, center.y, 0.0))
	_beans.set_meta("box", box)


## CatalogScreen.setClarabelleChat. The node origin is the tail, and the
## white bubble grows up and to the right across the green frame.
func _place_balloon(view: Vector2) -> void:
	if _balloon == null or view.y < 2.0:
		return
	var line := _note.text
	if line == "":
		_balloon.visible = false
		return
	_balloon.visible = true
	var unit := view.y * 0.5
	var px := maxi(int(round(0.08 * _SCALE * unit)), 12)
	ToonGui.style_label(_note, Color(0, 0, 0), px, Color(0, 0, 0, 0), 0)
	ToonGui.show_speech(_note, line, px)
	var measured := ToonGui.font().get_multiline_string_size(_note.text, HORIZONTAL_ALIGNMENT_CENTER, -1, px)
	var width := measured.x / float(px)
	var height := measured.y / float(px)
	if width < 2.5:
		width = 2.5
	if height < 1.0:
		height = 1.0
	width = width * 1.05 + 0.3
	var local := 0.08 * _SCALE * unit
	var origin := Vector2(view.x * 0.5 + 0.7 * _SCALE * unit, view.y * 0.5 - (0.6 * _SCALE + 0.025) * unit)
	var left := origin.x + 0.2 * local
	var right := origin.x + (0.2 + width) * local
	var bottom := origin.y - 1.4 * local
	var top := origin.y - (2.4 + height) * local
	var tip := Vector2(origin.x + (width / 10.0) * local, origin.y)
	var box := Rect2(Vector2(left, top), Vector2(right - left, bottom - top))
	_balloon.position = Vector2(minf(left, tip.x), top)
	_balloon.size = Vector2(maxf(right, tip.x) - _balloon.position.x, maxf(bottom, tip.y) - top)
	_balloon.body = box
	_balloon.tip = tip
	_balloon.queue_redraw()
	_note.position = box.position - _balloon.position
	_note.size = box.size


func _layout_cells() -> void:
	for panel in _panels:
		var box := panel.size
		if box.y < 2.0:
			continue
		var buy := panel.get_node("Buy") as Control
		buy.position = Vector2(box.x * 0.62, box.y * 0.08)
		buy.size = Vector2(box.x * 0.32, box.y * 0.28)
		var caption := panel.get_node("BuyCaption") as Label
		caption.position = buy.position
		caption.size = buy.size
		var unit := get_viewport().get_visible_rect().size.y * 0.5
		# CIPbuyButton (0.06, 0.05) on a button scaled (0.7, 1, 0.8).
		ToonGui.style_label(caption, Color(0, 0, 0), maxi(int(round(0.05 * 0.8 * _SCALE * unit)), 10), Color(0, 0, 0, 0), 0)
		var owned := panel.get_node("Owned") as Label
		var stamp := Vector2(box.x * 0.52, box.y * 0.26)
		owned.size = stamp
		owned.pivot_offset = stamp * 0.5
		owned.position = Vector2(box.x * 0.17, box.y * 0.20) - stamp * 0.5
		ToonGui.style_label(owned, Color(0, 0, 0), maxi(int(round(0.05 * _SCALE * unit)), 10), Color(0, 0, 0, 0), 0)
		var accessory := bool(panel.get_meta("accessory", false))
		var picture := panel.get_node("Picture") as Control
		picture.visible = accessory
		if accessory:
			var side := minf(box.x * 0.58, box.y * 0.42)
			_pin(panel.get_node("Kind"), Rect2(4, 2, box.x * 0.58, box.y * 0.12))
			_pin(picture, Rect2((box.x * 0.58 - side) * 0.5, box.y * 0.12, side, side))
			var title := panel.get_node("Title") as Label
			var price := panel.get_node("Price") as Label
			# Name sits under the picture. The price is the next line, the way
			# CatalogItemPanel places them at z -0.22 and z -0.30.
			_pin(title, Rect2(2, box.y * 0.56, box.x - 4, box.y * 0.24))
			_pin(price, Rect2(2, box.y * 0.82, box.x - 4, box.y * 0.16))
			title.clip_contents = true
			title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			var name_px := maxi(int(round(0.06 * _SCALE * unit)), 10)
			var price_px := maxi(int(round(0.07 * _SCALE * unit)), 10)
			ToonGui.style_sign(panel.get_node("Kind"), Color(0.95, 0.95, 0), name_px, Color(0, 0, 0), 2)
			ToonGui.style_label(title, Color(0, 0, 0), name_px, Color(0, 0, 0, 0), 0)
			ToonGui.style_sign(price, Color(0.95, 0.95, 0), price_px, Color(0, 0, 0), 2)
		else:
			var title := panel.get_node("Title") as Label
			title.clip_contents = false
			title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			var price := panel.get_node("Price") as Label
			price.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			_pin(panel.get_node("Kind"), Rect2(4, 2, box.x - 8, box.y * 0.16))
			_pin(title, Rect2(4, box.y * 0.34, box.x - 8, box.y * 0.28))
			_pin(panel.get_node("Price"), Rect2(4, box.y * 0.66, box.x * 0.62, box.y * 0.16))


func _pin(node: Node, rect: Rect2) -> void:
	var control := node as Control
	if control == null:
		return
	control.position = rect.position
	control.size = rect.size


func _mark(control: Control, at: Vector2, box: Vector2) -> Control:
	control.set_meta("at", at)
	control.set_meta("box", box)
	return control


func _show_page() -> void:
	var count := maxi(int(ceil(float(_items.size()) / float(_CELLS.size()))), 1)
	_page = clampi(_page, 0, count - 1)
	_spin_base = _clara_time
	_beans.text = str(_BEANS.pouch() + _BEANS.bank())
	_page_label.text = "Page %d" % [_page + 1]
	_note.text = _spoken if _spoken != "" else (_GREETING if _page == 0 else "")
	_place_balloon(get_viewport().get_visible_rect().size)
	_prev.disabled = _page <= 0
	_next.disabled = _page >= count - 1
	_prev.modulate = Color(1, 1, 1, 0.35) if _prev.disabled else Color.WHITE
	_next.modulate = Color(1, 1, 1, 0.35) if _next.disabled else Color.WHITE
	for index in _panels.size():
		var panel := _panels[index]
		var item_index := _page * _CELLS.size() + index
		panel.visible = item_index < _items.size()
		if panel.visible:
			_fill(panel, _items[item_index])
	_layout_cells()


func _fill(panel: Control, item: Dictionary) -> void:
	var swatch := panel.get_node("Swatch") as ColorRect
	var kind_name := String(item.get("kind", ""))
	var accessory := kind_name == "accessory"
	swatch.visible = not accessory
	swatch.color = _tint(kind_name)
	panel.set_meta("accessory", accessory)
	var kind := panel.get_node("Kind") as Label
	var title := panel.get_node("Title") as Label
	var price := panel.get_node("Price") as Label
	kind.text = _kind_name(kind_name)
	title.text = String(item.get("name", ""))
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if accessory else HORIZONTAL_ALIGNMENT_LEFT
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if accessory else HORIZONTAL_ALIGNMENT_LEFT
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if accessory else HORIZONTAL_ALIGNMENT_LEFT
	price.text = "%d beans" % int(item.get("price", 0))
	if accessory:
		var record := _accessory_record(item)
		if String(record.get("name", "")) != "":
			title.text = String(record.get("name", ""))
		_show_accessory(panel, record)
	else:
		_clear_accessory(panel)
	var buy := panel.get_node("Buy") as TextureButton
	var caption := panel.get_node("BuyCaption") as Label
	var owned_label := panel.get_node("Owned") as Label
	var owned := _CLOSET.owns(item)
	buy.disabled = owned
	buy.set_meta("item", item)
	buy.modulate = Color(1, 0.4, 0.4, 0.45) if owned else Color(1, 0.4, 0.4, 1)
	caption.text = "Buy"
	owned_label.visible = owned
	owned_label.text = "Already\nPurchased"


func _purchase(item: Dictionary) -> void:
	if _CLOSET.owns(item):
		_say(_OWNED)
		return
	var price := int(item.get("price", 0))
	if not _BEANS.take_beans(price):
		_say(_BROKE)
		return
	_CLOSET.buy(_style, item)
	if _actor != null and is_instance_valid(_actor):
		_actor.recolor(_style)
		_actor.wear_accessories(_CLOSET.accessory_ids())
	_refresh_chat()
	_refresh_nametag()
	_say(_BOUGHT)
	_show_page()


func _refresh_chat() -> void:
	var host := get_tree().root
	for node in host.find_children("*", "SpeedChat", true, false):
		if node.has_method("apply_catalog"):
			node.call("apply_catalog")


func _refresh_nametag() -> void:
	var path := _CLOSET.font_path()
	if path == "":
		return
	var host := get_tree().root
	for node in host.find_children("*", "Nametags", true, false):
		if node.has_method("apply_font"):
			node.call("apply_font", path)


func _say(line: String) -> void:
	_spoken = line
	_note.text = line
	_place_balloon(get_viewport().get_visible_rect().size)


func _turn(step: int) -> void:
	_spoken = ""
	_page += step
	_show_page()


func _hang_up() -> void:
	finished.emit()
	queue_free()


func _issue(style: ToonStyle) -> Array[Dictionary]:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_ISSUE))
	if parsed is not Dictionary:
		return []
	var data: Dictionary = parsed
	var weeks: Array = data.get("weeks", [])
	var index := int(Time.get_unix_time_from_system() / (7.0 * 24.0 * 60.0 * 60.0)) % maxi(weeks.size(), 1)
	var rows: Array[Dictionary] = []
	var seen := {}
	_take(rows, seen, _month(data.get("months", [])), style)
	if index >= 0 and index < weeks.size() and weeks[index] is Array:
		_take(rows, seen, weeks[index], style)
	return rows


func _month(months: Array) -> Array:
	var now := Time.get_datetime_dict_from_system()
	var month := int(now.get("month", 1))
	var day := int(now.get("day", 1))
	var found: Array = []
	for entry in months:
		if entry is not Dictionary:
			continue
		var start: Array = entry.get("start", [])
		var ending: Array = entry.get("end", [])
		if start.size() < 2 or ending.size() < 2:
			continue
		if _in_season(month, day, int(start[0]), int(start[1]), int(ending[0]), int(ending[1])):
			var items: Array = entry.get("items", [])
			found.append_array(items)
	return found


func _in_season(month: int, day: int, start_m: int, start_d: int, end_m: int, end_d: int) -> bool:
	var here := month * 100 + day
	var start := start_m * 100 + start_d
	var ending := end_m * 100 + end_d
	if start <= ending:
		return here >= start and here <= ending
	return here >= start or here <= ending


func _offer(item: Dictionary) -> Dictionary:
	if String(item.get("kind", "")) != "pole" or int(item.get("id", -1)) >= 0:
		return item
	var rod := _TANK.rod() + 1
	if rod > 4:
		return {}
	var names: PackedStringArray = ["Twig Rod", "Bamboo Rod", "Hardwood Rod", "Steel Rod", "Gold Rod"]
	var prices := [0, 400, 800, 1200, 2000]
	return {"kind": "pole", "id": rod, "name": names[rod], "price": prices[rod], "gender": ""}


func _take(rows: Array[Dictionary], seen: Dictionary, source: Array, style: ToonStyle) -> void:
	for item in source:
		if item is not Dictionary:
			continue
		var offered := _offer(item)
		if offered.is_empty():
			continue
		var gender := String(offered.get("gender", ""))
		if gender != "" and style != null and gender != style.gender:
			continue
		var key := String(offered.get("kind", "")) + ":" + str(int(offered.get("id", -1)))
		if seen.has(key):
			continue
		seen[key] = true
		rows.append(offered)


func _cell() -> Control:
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var swatch := ColorRect.new()
	swatch.name = "Swatch"
	swatch.set_anchors_preset(Control.PRESET_FULL_RECT)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(swatch)
	var picture := SubViewportContainer.new()
	picture.name = "Picture"
	picture.stretch = true
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.visible = false
	panel.add_child(picture)
	var view := SubViewport.new()
	view.name = "View"
	view.own_world_3d = true
	view.transparent_bg = true
	view.handle_input_locally = false
	view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	view.size = Vector2i(256, 256)
	picture.add_child(view)
	var pitch := Node3D.new()
	pitch.name = "Pitch"
	pitch.rotation.x = deg_to_rad(20.0)
	view.add_child(pitch)
	var spin := Node3D.new()
	spin.name = "Spin"
	pitch.add_child(spin)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.position = Vector3(0, 0, 4)
	camera.current = true
	view.add_child(camera)
	var kind := _plain("Kind")
	kind.position = Vector2(4, 2)
	panel.add_child(kind)
	var title := _plain("Title")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(title)
	var price := _plain("Price")
	price.add_theme_color_override("font_color", Color(0.95, 0.95, 0))
	price.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	panel.add_child(price)
	var buy := TextureButton.new()
	buy.name = "Buy"
	buy.texture_normal = _BUY_UP
	buy.texture_pressed = _BUY_DOWN
	buy.texture_hover = _BUY_HOVER
	buy.ignore_texture_size = true
	buy.stretch_mode = TextureButton.STRETCH_SCALE
	panel.add_child(buy)
	var caption := _plain("BuyCaption")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(caption)
	var owned := _plain("Owned")
	owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owned.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	owned.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owned.rotation = deg_to_rad(-30.0)
	owned.visible = false
	panel.add_child(owned)
	buy.pressed.connect(_pressed_buy.bind(buy))
	add_child(panel)
	var backdrop := Environment.new()
	backdrop.background_mode = Environment.BG_COLOR
	backdrop.background_color = Color(0, 0, 0, 0)
	if view.world_3d:
		view.world_3d.environment = backdrop
	return panel


func _accessory_record(item: Dictionary) -> Dictionary:
	var items: Dictionary = _accessory_catalog().get("items", {})
	var record: Variant = items.get(str(int(item.get("id", -1))), {})
	return record if record is Dictionary else {}


func _accessory_catalog() -> Dictionary:
	if not _accessory_book.is_empty():
		return _accessory_book
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_ACCESSORIES))
	if parsed is Dictionary:
		_accessory_book = parsed
	return _accessory_book


func _clear_accessory(panel: Control) -> void:
	var spin := panel.get_node_or_null("Picture/View/Pitch/Spin") as Node3D
	if spin == null:
		return
	for child in spin.get_children():
		spin.remove_child(child)
		child.free()


func _show_accessory(panel: Control, record: Dictionary) -> void:
	_clear_accessory(panel)
	var model := _accessory_model(record)
	if model == null:
		return
	var spin := panel.get_node("Picture/View/Pitch/Spin") as Node3D
	var stand := Node3D.new()
	stand.name = "Stand"
	# Accessory glbs are still Panda Z-up, the same as the toon parts.
	stand.basis = Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	spin.add_child(stand)
	stand.add_child(model)
	_paint_prop(model, _mapped(String(record.get("texture", ""))))
	_fit_stand(stand, spin.get_parent() as Node3D)


func _accessory_model(record: Dictionary) -> Node3D:
	if String(record.get("slot", "")) == "shoes":
		if not ResourceLoader.exists(_SHOE_LEGS):
			return null
		var legs := load(_SHOE_LEGS) as PackedScene
		if legs == null:
			return null
		var body := legs.instantiate() as Node3D
		if body == null:
			return null
		var shoe := _find_node(body, String(record.get("mesh", "")))
		if shoe == null:
			body.free()
			return null
		for node in body.find_children("*", "MeshInstance3D", true, false):
			node.visible = node == shoe
		return body
	var path := String(record.get("model", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as Node3D


func _fit_stand(stand: Node3D, pitch: Node3D) -> void:
	var model := stand.get_child(0) as Node3D
	if model == null:
		return
	var box := _local_bounds(stand)
	if box.size.length_squared() < 0.000001:
		return
	model.position -= box.get_center()
	var pitched := _local_bounds(pitch)
	var half := pitched.size * 0.5
	var extent := maxf(half.x, maxf(half.y, half.z))
	if extent > 0.0001:
		stand.scale = Vector3.ONE * (1.0 / extent)


func _local_bounds(root: Node3D) -> AABB:
	var box := AABB()
	var found := false
	var meshes: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		meshes.append(root)
	for node in root.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node)
	for mesh in meshes:
		if not mesh.visible or mesh.mesh == null:
			continue
		var xform := root.global_transform.affine_inverse() * mesh.global_transform
		var local := xform * mesh.mesh.get_aabb()
		box = local if not found else box.merge(local)
		found = true
	return box


func _paint_prop(node: Node, texture: Texture2D) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var found := texture
		if found == null and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
			var material := mesh.mesh.surface_get_material(0)
			if material is BaseMaterial3D:
				found = (material as BaseMaterial3D).albedo_texture
		mesh.material_override = _toon_material(found)
	for child in node.get_children():
		_paint_prop(child, texture)


func _toon_material(texture: Texture2D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _BODY
	material.set_shader_parameter("albedo_color", Color.WHITE)
	material.set_shader_parameter("use_albedo_texture", 1.0 if texture else 0.0)
	if texture:
		material.set_shader_parameter("albedo_texture", texture)
	return material


func _mapped(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _find_node(node: Node, wanted: String) -> Node3D:
	if wanted != "" and String(node.name) == wanted and node is Node3D:
		return node as Node3D
	for child in node.get_children():
		var found := _find_node(child, wanted)
		if found:
			return found
	return null


func _pressed_buy(buy: TextureButton) -> void:
	var item: Variant = buy.get_meta("item", {})
	if item is Dictionary:
		_purchase(item)


func _plain(node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _sign() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _caption(text: String) -> Label:
	var label := _sign()
	label.text = text
	return label


func _arrow(up: Texture2D, down: Texture2D, hover: Texture2D, pressed: Callable) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = up
	button.texture_pressed = down
	button.texture_hover = hover
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.pressed.connect(pressed)
	add_child(button)
	return button


func _tint(kind: String) -> Color:
	if kind == "clothing":
		return _PINK
	if kind == "accessory":
		return _BLUE
	return _CREAM


func _kind_name(kind: String) -> String:
	if kind == "clothing":
		return "Clothing"
	if kind == "accessory":
		return "Accessory"
	if kind == "emote":
		return "Emotion"
	if kind == "phrase":
		return "SpeedChat"
	if kind == "nametag":
		return "Name Tag"
	if kind == "furniture":
		return "Furniture"
	if kind == "wallpaper":
		return "Wallpaper"
	if kind == "flooring":
		return "Flooring"
	if kind == "moulding":
		return "Moulding"
	if kind == "wainscoting":
		return "Wainscoting"
	if kind == "window":
		return "Window"
	if kind == "pole":
		return "Fishing Rod"
	if kind == "trick":
		return "Doodle Training"
	return ""


## White chatbox with the tail at the node origin. The body rect and the tip
## are in the catalog's screen space; this control is shifted so both fit.
class _Balloon extends Control:
	var body := Rect2()
	var tip := Vector2.ZERO

	func _draw() -> void:
		if body.size.x < 1.0:
			return
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1, 1, 1, 1)
		box.border_color = Color(0.05, 0.05, 0.05)
		box.set_border_width_all(3)
		box.set_corner_radius_all(maxi(int(body.size.y * 0.18), 8))
		box.corner_detail = 8
		var local_body := Rect2(body.position - position, body.size)
		var local_tip := tip - position
		var foot := local_body.position + Vector2(local_body.size.x * 0.08, local_body.size.y)
		draw_colored_polygon(PackedVector2Array([
			foot,
			foot + Vector2(mini(28.0, local_body.size.x * 0.22), 0.0),
			local_tip,
		]), Color(1, 1, 1, 1))
		draw_style_box(box, local_body)
