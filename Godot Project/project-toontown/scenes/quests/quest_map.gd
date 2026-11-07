class_name QuestMap
extends Control

## QuestMap. On a street, the corner button opens that branch's card from
## phase_4/models/questmap. The arrow is the toon. A numbered pin is a
## ToonTask that sends you to a building on this street, or a finished task
## you turn in at Toon HQ. The gray card is SuitHoodInfo's four department
## percentages: Bossbot, Lawbot, Cashbot, Sellbot.

const _GUI := preload("res://scenes/toons/toon_gui.gd")
const _BLDG := preload("res://scenes/interiors/shop_door.gd")
const _CORP := preload("res://assets/gui/cogs/CorpIcon.png")
const _LEGAL := preload("res://assets/gui/cogs/LegalIcon.png")
const _MONEY := preload("res://assets/gui/cogs/MoneyIcon.png")
const _SALES := preload("res://assets/gui/cogs/SalesIcon.png")

const _DIR := "res://assets/gui/questmap/"
const _INK := Color(0.2, 0.2, 0.2, 1.0)
const _NONE := Vector2(INF, INF)

# QuestMapGlobals.CornerPosTable. Top-right X, Y, then bottom-left X, Y, in Panda space.
const _CORNER := {
	1100: [596.439575, 146.409653, 28.039612, -421.990356],
	1200: [34.281967, -47.717041, -464.517944, -546.516968],
	1300: [713.403076, 361.576324, -83.596741, -435.423615],
	2100: [161.735336, -59.985107, -512.664612, -734.385193],
	2200: [1.816254, 335.417358, -641.983643, -308.382629],
	2300: [870.224243, 536.165771, -89.175751, -423.234344],
	3100: [535.648132, 267.004578, 59.248276, -209.395325],
	3200: [429.647949, 561.224304, -31.951935, 99.624283],
	3300: [461.503418, 467.348511, -27.896454, -22.051422],
	4100: [-98.880981, 349.36908, -658.680908, -210.430862],
	4200: [283.292847, 658.077393, -289.50708, 85.277466],
	4300: [801.294067, 430.992218, -5.505768, -375.807678],
	5100: [760.089722, 526.236206, -139.510132, -373.3638],
	5200: [781.219727, 476.963623, -123.380096, -427.636261],
	5300: [203.715881, 429.168274, -390.284027, -164.83165],
	9100: [279.354584, 111.658554, -423.445221, -591.141357],
	9200: [420.817871, 204.719116, -220.182007, -436.280853],
}
# QuestMapGlobals.HQPosTable and FishingSpotPosTable, Panda X and Y.
const _HQ := {
	1100: [365.0, 100.0],
	1200: [-25.0, -410.0],
	1300: [210.0, -200.0],
	2100: [-55.0, -350.0],
	2200: [-385.0, 70.0],
	2300: [490.0, 140.0],
	3100: [129.737, 51.9612],
	3200: [230.0, 200.0],
	3300: [268.052, 228.052],
	4100: [-330.0, -40.0],
	4200: [0.0, 555.0],
	4300: [326.0, 172.0],
	5100: [357.935, 28.45],
	5200: [345.0, 150.0],
	5300: [-138.597, 77.1236],
	9100: [-250.0, -160.0],
	9200: [322.91, -67.1147],
}
const _FISH := {
	1100: [368.148, -339.916],
	1200: [-394.913, -243.085],
	1300: [346.219, 88.2058],
	2100: [4.45088, -658.174],
	2200: [-223.506, 161.474],
	2300: [512.4, -69.9997],
	3100: [455.445, 15.6579],
	3200: [340.009, 462.856],
	3300: [54.17, 75.405],
	4100: [-570.662, -101.811],
	4200: [-205.722, 238.179],
	4300: [705.052, -26.4757],
	5100: [162.961, 57.4756],
	5200: [162.961, 113.59],
	5300: [120.848, -55.6079],
	9100: [106.796, -197.427],
	9200: [239.646, -330.58],
}
# QuestMapGlobals.CogInfoPosTable, the card's local X and Z.
const _COG_AT := {
	1100: [0.35, -0.2],
	1200: [0.3, -0.35],
	1300: [0.3, -0.25],
	2100: [-0.3, -0.2],
	2200: [0.2, -0.2],
	2300: [0.35, -0.2],
	3100: [0.37, -0.2],
	3200: [0.35, -0.35],
	3300: [0.3, -0.2],
	4100: [0.45, -0.2],
	4200: [0.3, -0.3],
	4300: [0.4, -0.2],
	5100: [0.3, -0.2],
	5200: [0.3, -0.2],
	5300: [-0.3, -0.3],
	9100: [0.2, -0.2],
	9200: [-0.25, -0.2],
}
# SuitPlannerBase.SuitHoodInfo track tuple: Bossbot, Lawbot, Cashbot, Sellbot.
const _SUIT := {
	1100: [90, 10, 0, 0],
	1200: [0, 0, 90, 10],
	1300: [40, 40, 10, 10],
	2100: [25, 25, 25, 25],
	2200: [10, 70, 10, 10],
	2300: [10, 10, 40, 40],
	3100: [90, 10, 0, 0],
	3200: [10, 20, 30, 40],
	3300: [5, 85, 5, 5],
	4100: [0, 0, 50, 50],
	4200: [0, 0, 90, 10],
	4300: [50, 50, 0, 0],
	5100: [0, 20, 10, 70],
	5200: [10, 70, 0, 20],
	5300: [5, 5, 5, 85],
	9100: [25, 25, 25, 25],
	9200: [5, 5, 85, 5],
}

var _tasks: ToonTasks
var _zone := 0
var _span := PackedFloat32Array()
var _ready := false
var _open := false
var _where := Vector3.ZERO
var _heading := 0.0
var _time := 0.0

var _open_button: TextureButton
var _close_button: TextureButton
var _panel: Control
var _cog: ColorRect
var _arrow: TextureRect
var _icons: Array[TextureRect] = []
var _percents: Array[Label] = []
var _markers: Array[Control] = []


func setup(tasks: ToonTasks, zone: int) -> bool:
	_tasks = tasks
	_zone = zone
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 12
	var card := _texture("%s_%d_english.png" % [_dna(zone), zone])
	var closed := _texture("tt_t_gui_qst_mapClose.png")
	var opened := _texture("tt_t_gui_qst_mapOpen.png")
	var try_open := _texture("tt_t_gui_qst_mapTryToOpen.png")
	var try_close := _texture("tt_t_gui_qst_mapTryToClose.png")
	var arrow := _texture("tt_t_gui_qst_arrow.png")
	var pin := _texture("startPartyButton_inactive.png")
	# QuestMap.updateMap hides the map when this branch has no card. The
	# playground is one of those places: the original file has street cards only.
	if closed == null or opened == null or try_open == null or try_close == null or arrow == null or pin == null or card == null:
		visible = false
		return false
	_ready = true
	_panel = Control.new()
	_panel.name = "StreetMap"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	add_child(_panel)
	var image := TextureRect.new()
	image.set_anchors_preset(Control.PRESET_FULL_RECT)
	image.offset_right = 0.0
	image.offset_bottom = 0.0
	image.texture = card
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(image)
	_cog = ColorRect.new()
	_cog.color = Color(0.5, 0.5, 0.5, 0.5)
	_cog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_cog)
	var icons: Array[Texture2D] = [_CORP, _LEGAL, _MONEY, _SALES]
	var rates := _ints(_SUIT, zone)
	for index in 4:
		var icon := TextureRect.new()
		icon.texture = icons[index]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cog.add_child(icon)
		_icons.append(icon)
		var percent := Label.new()
		percent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var rate := 0
		if index < rates.size():
			rate = rates[index]
		percent.text = "%d%%" % rate
		_cog.add_child(percent)
		_percents.append(percent)
	_cog.visible = rates.size() == 4
	_arrow = TextureRect.new()
	_arrow.texture = arrow
	_arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_arrow)
	_open_button = _button(closed, try_open, show_map)
	_close_button = _button(opened, try_close, hide_map)
	_close_button.visible = false
	if not get_viewport().size_changed.is_connected(_layout):
		get_viewport().size_changed.connect(_layout)
	_layout()
	set_meta("pin", pin)
	return true


func follow(where: Vector3, heading: float) -> void:
	_where = where
	_heading = heading
	if _open:
		_place_arrow()


func toggle() -> void:
	if not _ready:
		return
	if _open:
		hide_map()
	else:
		show_map()


func show_map() -> void:
	if not _ready:
		return
	_open = true
	_time = 0.0
	_panel.visible = true
	_open_button.visible = false
	_close_button.visible = true
	_rebuild()
	_layout()


func hide_map() -> void:
	_open = false
	if _panel != null:
		_panel.visible = false
	if _close_button != null:
		_close_button.visible = false
	if _open_button != null and _ready:
		_open_button.visible = true


func _process(delta: float) -> void:
	if not _open:
		return
	_time += delta
	_place_arrow()
	var index := 0
	for marker in _markers:
		var rel: Vector2 = marker.get_meta("rel")
		var wave := (sin(_time * 16.0 + float(index) * PI / 3.0) + 1.0) * 0.005 + 0.04
		# image_scale 6 on a button about 0.147 units across, then the marker scale.
		_place_frac(marker, rel, wave * 0.882)
		_style_number(marker)
		_tint_marker(marker)
		index += 1


func _button(normal: Texture2D, hover: Texture2D, action: Callable) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = normal
	button.texture_pressed = normal
	button.texture_hover = hover
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.z_index = 1
	button.pressed.connect(action)
	_GUI.button_sounds(button)
	add_child(button)
	return button


func _rebuild() -> void:
	for marker in _markers:
		marker.queue_free()
	_markers.clear()
	if _tasks == null:
		return
	var pin := get_meta("pin") as Texture2D
	var cards := _tasks.entries()
	for index in cards.size():
		var card: Dictionary = cards[index]
		var rel := _marker_rel(card)
		if is_inf(rel.x):
			continue
		var marker := Control.new()
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.set_meta("rel", rel)
		marker.set_meta("building", _marker_building(card))
		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_right = 0.0
		icon.offset_bottom = 0.0
		icon.texture = pin
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color(1, 0, 0, 1)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.add_child(icon)
		var number := Label.new()
		number.set_anchors_preset(Control.PRESET_FULL_RECT)
		number.offset_right = 0.0
		number.offset_bottom = 0.0
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number.text = str(index + 1)
		marker.add_child(number)
		_panel.add_child(marker)
		_markers.append(marker)


func _marker_rel(card: Dictionary) -> Vector2:
	# QuestMap.updateQuestInfo. A cog or trolley task has no street building
	# until it is finished. Then the pin sits on this street's Toon HQ.
	var ready := bool(card.get("ready", false))
	var kind := String(card.get("kind", ""))
	var turn_in := String(card.get("turn_in", ""))
	var place := ""
	if not ready:
		if kind == "fish":
			place = "fish"
		elif kind == "visit" or kind == "deliver" or kind == "track":
			place = turn_in
		else:
			return _NONE
	else:
		place = turn_in
	if place == "hq":
		return _table_rel(_HQ)
	if place == "fish":
		return _table_rel(_FISH)
	if place.is_valid_int():
		return _building_rel(int(place))
	return _NONE


func _building_rel(interior_zone: int) -> Vector2:
	var building := _BLDG.find_for_zone(interior_zone)
	if building == null:
		building = _landmark(interior_zone)
	if building == null or not building.is_inside_tree():
		return _NONE
	var where := building.global_position
	var door := _BLDG.find_exterior_door(building)
	if door != null and door.is_inside_tree():
		where = door.global_position
	return _relative(where.x, -where.z)


func _table_rel(table: Dictionary) -> Vector2:
	var row := _floats(table, _zone)
	if row.size() < 2:
		return _NONE
	return _relative(row[0], row[1])


func _relative(panda_x: float, panda_y: float) -> Vector2:
	# QuestMap.transformAvPos. Panda X is Godot X. Panda Y is Godot -Z.
	var row := _span if _zone == 2000 and _span.size() >= 4 else _floats(_CORNER, _zone)
	if row.size() < 4:
		return Vector2.ZERO
	var span_x := row[0] - row[2]
	var span_y := row[1] - row[3]
	if absf(span_x) < 0.001 or absf(span_y) < 0.001:
		return Vector2.ZERO
	return Vector2((panda_x - row[2]) / span_x - 0.5, (panda_y - row[3]) / span_y - 0.5)


func _layout() -> void:
	if not _ready or _panel == null:
		return
	var view := get_viewport().get_visible_rect().size
	_GUI.place(_panel, view, 0.0, 0.0, 1.5, 1.5)
	# The rolled map sits just above the shticker book, right edges lined up.
	var book := ShtickerBook.closed_rect(view)
	var side := book.size.x * 0.205 / 0.305
	var at := Vector2(book.end.x - side, book.position.y - side - 6.0)
	_open_button.position = at
	_open_button.size = Vector2(side, side)
	_close_button.position = at
	_close_button.size = Vector2(side, side)
	var cog_at := _floats(_COG_AT, _zone)
	if cog_at.size() >= 2:
		_place_box(_cog, Vector2(cog_at[0], cog_at[1]), 0.3, 0.1)
	_layout_cogs()
	_place_arrow()
	var index := 0
	for marker in _markers:
		var rel: Vector2 = marker.get_meta("rel")
		var wave := (sin(_time * 16.0 + float(index) * PI / 3.0) + 1.0) * 0.005 + 0.04
		_place_frac(marker, rel, wave * 0.882)
		_style_number(marker)
		_tint_marker(marker)
		index += 1


func _layout_cogs() -> void:
	if _percents.is_empty():
		return
	var span := _cog.size
	var icon_px := span.y * 0.4
	var font_px := maxi(int(span.y * 0.36), 8)
	# Label spots inside the 6 by 2 card: Bossbot, Lawbot, Cashbot, Sellbot.
	var spots: Array[Vector2] = [
		Vector2(0.133, 0.25),
		Vector2(0.133, 0.75),
		Vector2(0.633, 0.25),
		Vector2(0.633, 0.75),
	]
	for index in _icons.size():
		var origin := Vector2(spots[index].x * span.x, spots[index].y * span.y)
		var icon := _icons[index]
		icon.size = Vector2(icon_px, icon_px)
		icon.position = origin - Vector2(0.0, icon_px * 0.5)
		var percent := _percents[index]
		percent.position = origin + Vector2(icon_px * 1.05, -icon_px * 0.5)
		percent.size = Vector2(span.x * 0.28, icon_px)
		_GUI.style_label(percent, _INK, font_px, Color(0, 0, 0, 0), 0)


func _place_arrow() -> void:
	if _arrow == null:
		return
	_place_frac(_arrow, _relative(_where.x, -_where.z), 0.05)
	# The arrow picture points right. Heading 0 faces Panda +Y, which is up
	# on the card. Positive heading turns left, so the picture turns counterclockwise.
	_arrow.rotation = deg_to_rad(-90.0 - _heading)


func _place_frac(node: Control, rel: Vector2, frac: float) -> void:
	var span := _panel.size
	var point := Vector2((rel.x + 0.5) * span.x, (0.5 - rel.y) * span.y)
	var box := span.x * frac
	node.size = Vector2(box, box)
	node.position = point - node.size * 0.5
	node.pivot_offset = node.size * 0.5


func _place_box(node: Control, rel: Vector2, wide: float, tall: float) -> void:
	var span := _panel.size
	var point := Vector2((rel.x + 0.5) * span.x, (0.5 - rel.y) * span.y)
	node.size = Vector2(span.x * wide, span.y * tall)
	node.position = point - node.size * 0.5


func _marker_building(card: Dictionary) -> Node:
	var ready := bool(card.get("ready", false))
	var kind := String(card.get("kind", ""))
	var turn_in := String(card.get("turn_in", ""))
	var place := turn_in if ready or kind == "visit" or kind == "deliver" or kind == "track" else ""
	if not place.is_valid_int():
		return null
	var zone := int(place)
	var building := _BLDG.find_for_zone(zone)
	if building == null:
		building = _landmark(zone)
	return building


## A taken building keeps its pin, in grey, until the Toons take it back.
func _tint_marker(marker: Control) -> void:
	var icon := marker.get_child(0) as CanvasItem
	if icon == null:
		return
	var building: Variant = marker.get_meta("building", null)
	var taken := is_instance_valid(building) and building is Node and (building as Node).has_meta("cog_building")
	icon.modulate = Color(0.55, 0.55, 0.55, 1) if taken else Color(1, 0, 0, 1)


func _style_number(marker: Control) -> void:
	var number := marker.get_child(1) as Label
	if number == null:
		return
	var px := maxi(int(marker.size.y * 0.42), 8)
	_GUI.style_label(number, Color(1, 1, 1, 1), px, Color(0, 0, 0, 0), 0)


func _texture(file_name: String) -> Texture2D:
	var path := _DIR + file_name
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _landmark(interior_zone: int) -> Node3D:
	var suffix := ""
	if interior_zone == 2513:
		suffix = "toon_landmark_TT_toonhall"
	elif interior_zone == 2518:
		suffix = "library_DNARoot"
	elif interior_zone == 2516:
		suffix = "school_house_DNARoot"
	elif interior_zone == 1508 or interior_zone == 2521 or interior_zone == 3509 or interior_zone == 4506 or interior_zone == 5503 or interior_zone == 9506:
		suffix = "clothes_shop_DNARoot"
	else:
		return null
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return _find_suffix(scene, suffix)


func _find_suffix(node: Node, suffix: String) -> Node3D:
	if node is Node3D and str(node.name).ends_with(suffix):
		return node as Node3D
	for child in node.get_children():
		var found := _find_suffix(child, suffix)
		if found != null:
			return found
	return null


func _playground_span() -> PackedFloat32Array:
	var scene := get_tree().current_scene
	if scene == null:
		return PackedFloat32Array()
	var found := {"ok": false, "minx": 0.0, "maxx": 0.0, "miny": 0.0, "maxy": 0.0}
	_span_walk(scene, found)
	if not bool(found["ok"]):
		return PackedFloat32Array()
	var pad := 30.0
	return PackedFloat32Array([
		float(found["maxx"]) + pad,
		float(found["maxy"]) + pad,
		float(found["minx"]) - pad,
		float(found["miny"]) - pad,
	])


func _span_walk(node: Node, found: Dictionary) -> void:
	var label := str(node.name).to_lower()
	if "sky" in label or "cloud" in label:
		return
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null and mesh.is_inside_tree():
			var box := mesh.global_transform * mesh.get_aabb()
			if box.size.x < 2000.0 and box.size.y < 400.0 and box.size.z < 2000.0:
				var min_x := box.position.x
				var max_x := min_x + box.size.x
				var panda_min := -box.position.z - box.size.z
				var panda_max := -box.position.z
				if not bool(found["ok"]):
					found["ok"] = true
					found["minx"] = min_x
					found["maxx"] = max_x
					found["miny"] = panda_min
					found["maxy"] = panda_max
				else:
					found["minx"] = minf(float(found["minx"]), min_x)
					found["maxx"] = maxf(float(found["maxx"]), max_x)
					found["miny"] = minf(float(found["miny"]), panda_min)
					found["maxy"] = maxf(float(found["maxy"]), panda_max)
	for child in node.get_children():
		_span_walk(child, found)


func _dna(zone: int) -> String:
	var hood := zone - zone % 1000
	match hood:
		1000:
			return "donalds_dock"
		2000:
			return "toontown_central"
		3000:
			return "the_burrrgh"
		4000:
			return "minnies_melody_land"
		5000:
			return "daisys_garden"
		9000:
			return "donalds_dreamland"
		_:
			return ""


func _floats(table: Dictionary, zone: int) -> PackedFloat32Array:
	var found: Variant = table.get(zone, null)
	var packed := PackedFloat32Array()
	if found is Array:
		for item in found:
			packed.append(float(item))
	return packed


func _ints(table: Dictionary, zone: int) -> Array[int]:
	var found: Variant = table.get(zone, null)
	var rates: Array[int] = []
	if found is Array:
		for item in found:
			rates.append(int(item))
	return rates
