extends Control

## KartPage. Customize, Records, and Trophy, using the fishing-book tabs and
## the ShtikerBookUI frames. The kart is bought from a clerk. This page only
## equips pieces already in the trunk.

const _GARAGE := preload("res://scenes/racing/kart_garage.gd")
const _MODEL := preload("res://scenes/racing/kart_model.gd")
const _RULES := preload("res://scenes/racing/kart_rules.gd")
const _DIR := "res://assets/gui/shticker/karts/"
const _TAB := preload("res://assets/gui/shticker/fishing/page_tab.png")
const _MAPS := "res://assets/racing/maps/"
const _BROWN := Color(0.2, 0.1, 0.0)
const _CREAM := Color(1.0, 1.0, 0.8)
const _TITLES: PackedStringArray = ["Kart Customizer", "Personal Best Records", "Racing Trophies"]
const _TAB_TEXT: PackedStringArray = ["Customize", "Records", "Trophy"]
const _TAB_NUDGE: PackedFloat32Array = [-0.025, 0.0, 0.03]
const _CATEGORIES: Array[Dictionary] = [
	{"key": "eBlockButton", "kind": "hood", "word": "Hood"},
	{"key": "spoilerButton", "kind": "trunk", "word": "Trunk"},
	{"key": "frontButton", "kind": "front", "word": "Front Wheel"},
	{"key": "rearButton", "kind": "back", "word": "Back Wheel"},
	{"key": "rimButton", "kind": "rim", "word": "Rim"},
	{"key": "decalButton", "kind": "decal", "word": "Decal"},
	{"key": "paintKartButton", "kind": "color", "word": "Kart Color"},
	{"key": "paintAccessoryButton", "kind": "accent", "word": "Accessory Color"},
]

var _mode := 0
var _kind := ""
var _index := 0
var _yaw := deg_to_rad(-35.0)
var _spin := 0
var _page_size := Vector2.ZERO
var _layout: Dictionary = {}
var _title: Label
var _tabs: Array[TextureButton] = []
var _tab_names: Array[Label] = []
var _sheets: Array[Control] = []
var _view: SubViewport
var _holder: SubViewportContainer
var _world: Node3D
var _kart: Node3D
var _frame: TextureRect
var _viewer: TextureRect
var _icon: TextureRect
var _caption: Label
var _delete: TextureButton
var _left: TextureButton
var _right: TextureButton
var _rotate_left: TextureButton
var _rotate_right: TextureButton
var _cats: Array[TextureButton] = []
var _record_names: Array[Label] = []
var _record_times: Array[Label] = []
var _panels: Array[Panel] = []
var _marks: Array[Label] = []
var _trophy_line: Label
var _tickets: Label
var _ticket_art: TextureRect
var _confirm: Control
var _confirm_text: Label


func _ready() -> void:
	name = "Karts"
	mouse_filter = MOUSE_FILTER_IGNORE
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_DIR + "layout.json"))
	if parsed is Dictionary:
		_layout = parsed
	_title = Label.new()
	_title.name = "Title"
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
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(caption)
		_tab_names.append(caption)
	for _sheet in 3:
		var sheet := Control.new()
		sheet.mouse_filter = MOUSE_FILTER_IGNORE
		sheet.set_anchors_preset(PRESET_FULL_RECT)
		add_child(sheet)
		_sheets.append(sheet)
	_build_customize()
	_build_records()
	_build_trophies()
	_build_confirm()
	_set_mode(0)


func _process(delta: float) -> void:
	if _spin == 0 or _kart == null:
		return
	_yaw += float(_spin) * deg_to_rad(72.0) * delta
	_kart.rotation.y = _yaw


func layout(page_size: Vector2) -> void:
	_page_size = page_size
	var title_box := _rect(-0.45, 0.60, 0.45, 0.70)
	_put(_title, title_box)
	ToonGui.style_label(_title, Color(0.08, 0.08, 0.08), _px(0.1), Color(0, 0, 0, 0), 0)
	var tabs: Array = _layout.get("tabs", [])
	for index in _tabs.size():
		var spot: Dictionary = tabs[index] if index < tabs.size() and tabs[index] is Dictionary else {}
		var box := _bounds(spot)
		_put(_tabs[index], box)
		var text_x := float(spot.get("text_x", 0.0)) + _TAB_NUDGE[index]
		var name_box := _rect(text_x, box_z0(spot), text_x + 0.28, box_z1(spot))
		_put(_tab_names[index], name_box)
		ToonGui.style_label(_tab_names[index], _BROWN, _px(0.07), Color(0, 0, 0, 0), 0)
	for sheet in _sheets:
		sheet.position = Vector2.ZERO
		sheet.size = page_size
	_put(_frame, _bounds(_piece("uiKartViewerFrame1")))
	_put(_holder, _rect(-0.38, 0.004, 0.38, 0.579))
	_view.size = Vector2i(maxi(int(_holder.size.x), 32), maxi(int(_holder.size.y), 32))
	_put(_rotate_left, _bounds(_piece("rotate_left_up")))
	_put(_rotate_right, _bounds(_piece("rotate_right_up")))
	_style_rotate(_rotate_left)
	_style_rotate(_rotate_right)
	_put(_viewer, _bounds(_piece("uiAccessoryViewerFrame")))
	_place_icon()
	_put(_delete, _bounds(_piece("uiAccessorydelete_up")))
	_style_delete()
	_put(_left, _arrow_box(_piece("ArrowLeftButtonUp")))
	_put(_right, _arrow_box(_piece("ArrowRightButtonUp")))
	var caption_box := _rect(-0.42, -0.56, 0.42, -0.49)
	_put(_caption, caption_box)
	ToonGui.style_label(_caption, Color(0.5, 0.0, 0.0), _px(0.0715), Color(0, 0, 0), 1)
	for button in _cats:
		_put(button, _bounds(_piece(String(button.get_meta("key")) + "_up")))
	for index in _record_names.size():
		var height := 0.5 - float(index) * 0.1
		_put(_record_names[index], _rect(-0.8, height - 0.04, 0.35, height + 0.04))
		_put(_record_times[index], _rect(0.35, height - 0.035, 0.9, height + 0.035))
		_sign(_record_names[index], Color(0.95, 0.95, 0.0), _px(0.075))
		ToonGui.style_label(_record_times[index], Color(0, 0, 0), _px(0.06), Color(0, 0, 0, 0), 0)
	for index in _panels.size():
		var center := _trophy_center(index)
		var wide := 0.1125 if index >= 30 else 0.075
		var tall := 0.15 if index >= 30 else 0.1
		var box := _rect(center.x - wide, center.y - tall, center.x + wide, center.y + tall)
		_put(_panels[index], box)
		_put(_marks[index], Rect2(Vector2.ZERO, box.size))
		var style := _panels[index].get_theme_stylebox("panel") as StyleBoxFlat
		if style != null:
			style.set_corner_radius_all(maxi(int(box.size.y * 0.18), 4))
		ToonGui.style_label(_marks[index], Color(0, 0, 0), _px(0.09 if index < 30 else 0.12), Color(0, 0, 0, 0), 0)
	_put(_trophy_line, _rect(-0.7, -0.21, 0.7, -0.14))
	ToonGui.style_label(_trophy_line, Color(1, 0, 0), _px(0.07), Color(0, 0, 0, 0), 0)
	_put(_tickets, _rect(-0.55, -0.69, 0.08, -0.61))
	_sign(_tickets, Color(0, 0, 0.95), _px(0.07))
	_put(_ticket_art, _rect(0.1, -0.735, 0.3, -0.535))
	_place_confirm()


func refresh() -> void:
	_paint()
	_paint_records()
	_paint_trophies()
	_show_kart()


func _build_customize() -> void:
	var sheet := _sheets[0]
	_frame = _picture("uiKartViewerFrame1")
	sheet.add_child(_frame)
	_view = SubViewport.new()
	_view.transparent_bg = false
	_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_holder = SubViewportContainer.new()
	_holder.mouse_filter = MOUSE_FILTER_IGNORE
	_holder.stretch = true
	_holder.add_child(_view)
	sheet.add_child(_holder)
	_world = Node3D.new()
	_view.add_child(_world)
	var camera := Camera3D.new()
	camera.look_at_from_position(Vector3(0, 2.2, 7.0), Vector3(0, 0.5, 0), Vector3.UP)
	camera.current = true
	_world.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 25, 0)
	_world.add_child(light)
	var sky := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = _CREAM
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.75)
	sky.environment = env
	_world.add_child(sky)
	_rotate_left = _spin_button("rotate_left", -1)
	_rotate_right = _spin_button("rotate_right", 1)
	_rotate_left.get_child(0).text = "Left"
	_rotate_right.get_child(0).text = "Right"
	sheet.add_child(_rotate_left)
	sheet.add_child(_rotate_right)
	_viewer = _picture("uiAccessoryViewerFrame")
	sheet.add_child(_viewer)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = MOUSE_FILTER_IGNORE
	_icon.z_index = 2
	sheet.add_child(_icon)
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.mouse_filter = MOUSE_FILTER_IGNORE
	sheet.add_child(_caption)
	_delete = _states("uiAccessorydelete")
	_delete.pressed.connect(_ask_delete)
	_delete.z_index = 3
	var delete_name := Label.new()
	delete_name.text = "Delete"
	delete_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	delete_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	delete_name.mouse_filter = MOUSE_FILTER_IGNORE
	delete_name.set_anchors_preset(PRESET_FULL_RECT)
	_delete.add_child(delete_name)
	sheet.add_child(_delete)
	_left = _camel("ArrowLeftButton")
	_right = _camel("ArrowRightButton")
	_left.pressed.connect(_step.bind(-1))
	_right.pressed.connect(_step.bind(1))
	_left.z_index = 4
	_right.z_index = 4
	sheet.add_child(_left)
	sheet.add_child(_right)
	for row in _CATEGORIES:
		var key := String(row["key"])
		var button := _states(key)
		button.set_meta("key", key)
		button.set_meta("kind", String(row["kind"]))
		button.pressed.connect(_select.bind(String(row["kind"])))
		sheet.add_child(button)
		_cats.append(button)


func _build_records() -> void:
	var sheet := _sheets[1]
	for track_id in _RULES.TRACK_IDS:
		var name_label := Label.new()
		name_label.text = _RULES.track_name(track_id)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.mouse_filter = MOUSE_FILTER_IGNORE
		sheet.add_child(name_label)
		_record_names.append(name_label)
		var time_label := Label.new()
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		time_label.mouse_filter = MOUSE_FILTER_IGNORE
		sheet.add_child(time_label)
		_record_times.append(time_label)


func _build_trophies() -> void:
	var sheet := _sheets[2]
	for index in 33:
		var panel := Panel.new()
		panel.mouse_filter = MOUSE_FILTER_STOP
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.8, 0.8, 0.8)
		panel.add_theme_stylebox_override("panel", style)
		panel.mouse_entered.connect(_grow.bind(index))
		panel.mouse_exited.connect(_shrink.bind(index))
		sheet.add_child(panel)
		_panels.append(panel)
		var mark := Label.new()
		mark.text = "?"
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.mouse_filter = MOUSE_FILTER_IGNORE
		panel.add_child(mark)
		_marks.append(mark)
	_trophy_line = Label.new()
	_trophy_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trophy_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_trophy_line.mouse_filter = MOUSE_FILTER_IGNORE
	sheet.add_child(_trophy_line)
	_tickets = Label.new()
	_tickets.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tickets.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tickets.mouse_filter = MOUSE_FILTER_IGNORE
	sheet.add_child(_tickets)
	_ticket_art = _picture("tickets")
	sheet.add_child(_ticket_art)


func _build_confirm() -> void:
	_confirm = Control.new()
	_confirm.visible = false
	_confirm.mouse_filter = MOUSE_FILTER_STOP
	_confirm.z_index = 20
	add_child(_confirm)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0)
	shade.mouse_filter = MOUSE_FILTER_STOP
	shade.set_anchors_preset(PRESET_FULL_RECT)
	_confirm.add_child(shade)
	var notice := _picture("uiAccessoryNotice")
	notice.z_index = 1
	_confirm.add_child(notice)
	_confirm_text = Label.new()
	_confirm_text.text = "Delete Accessory?"
	_confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_confirm_text.mouse_filter = MOUSE_FILTER_IGNORE
	_confirm_text.z_index = 2
	_confirm.add_child(_confirm_text)
	var cancel := _camel("CancelButton")
	cancel.z_index = 3
	cancel.pressed.connect(_close_confirm)
	_confirm.add_child(cancel)
	var cancel_icon := _picture("CancelIcon")
	cancel_icon.z_index = 4
	_confirm.add_child(cancel_icon)
	var accept := _camel("CheckButton")
	accept.z_index = 3
	accept.pressed.connect(_confirm_delete)
	_confirm.add_child(accept)
	var accept_icon := _picture("CheckIcon")
	accept_icon.z_index = 4
	_confirm.add_child(accept_icon)


func _set_mode(index: int) -> void:
	_mode = index
	_close_confirm()
	_title.text = _TITLES[index]
	for sheet_index in _sheets.size():
		_sheets[sheet_index].visible = sheet_index == index
	for tab_index in _tabs.size():
		var chosen := tab_index == index
		_tabs[tab_index].modulate = Color(1.0, 0.98, 0.15) if chosen else Color.WHITE
		_tabs[tab_index].mouse_filter = MOUSE_FILTER_IGNORE if chosen else MOUSE_FILTER_STOP
	if _rotate_left != null:
		var show_spin := index == 0 and _GARAGE.has_kart()
		_rotate_left.visible = show_spin
		_rotate_right.visible = show_spin
	refresh()


func _tint_tab(index: int, over: bool) -> void:
	if index == _mode:
		return
	_tabs[index].modulate = Color(0.15, 0.82, 1.0) if over else Color.WHITE


func _press_tab(index: int) -> void:
	if index == _mode:
		return
	_tabs[index].modulate = Color(0.8, 0.8, 0.0)


func _select(kind: String) -> void:
	if not _GARAGE.has_kart():
		_kind = ""
		_paint()
		return
	_kind = kind
	_index = 0
	var equipped := int(_GARAGE.dna()[_field()])
	var owned := _owned_here()
	for row_index in owned.size():
		if int((owned[row_index] as Dictionary).get("id", -2)) == equipped:
			_index = row_index
			break
	_paint()


func _step(direction: int) -> void:
	var owned := _owned_here()
	if owned.size() < 2 or not _GARAGE.has_kart():
		return
	_index = posmod(_index + direction, owned.size())
	var card: Dictionary = owned[_index]
	_GARAGE.equip(_field(), int(card.get("id", -1)))
	_paint()
	_show_kart()


func _ask_delete() -> void:
	var card := _current()
	if card.is_empty():
		return
	var acc_id := int(card.get("id", -1))
	if acc_id < 0 or not _GARAGE.owns(acc_id):
		return
	_confirm.visible = true


func _close_confirm() -> void:
	if _confirm != null:
		_confirm.visible = false


func _confirm_delete() -> void:
	var card := _current()
	_close_confirm()
	if card.is_empty():
		return
	var acc_id := int(card.get("id", -1))
	if acc_id < 0:
		return
	_GARAGE.delete_accessory(acc_id)
	_index = 0
	_paint()
	_show_kart()


func _paint() -> void:
	if _caption == null:
		return
	_caption.text = _caption_text()
	var card := _current()
	var acc_id := int(card.get("id", -1)) if not card.is_empty() else -1
	var can_delete := acc_id >= 0 and _GARAGE.owns(acc_id)
	_delete.visible = can_delete and _kind != ""
	_place_icon()
	_icon.texture = _icon_for(card)
	_icon.modulate = _swatch(card) if _kind == "color" or _kind == "accent" else Color.WHITE
	var stuck := _kind == "" or _owned_here().size() < 2
	_paint_arrow(_left, "ArrowLeftButton", stuck)
	_paint_arrow(_right, "ArrowRightButton", stuck)
	for button in _cats:
		var chosen := String(button.get_meta("kind")) == _kind and _kind != ""
		var key := String(button.get_meta("key"))
		button.texture_normal = _art(key + ("_inactive" if chosen else "_up"))
		button.mouse_filter = MOUSE_FILTER_IGNORE if chosen else MOUSE_FILTER_STOP
	var show_spin := _mode == 0 and _GARAGE.has_kart()
	_rotate_left.visible = show_spin
	_rotate_right.visible = show_spin


func _paint_records() -> void:
	for index in _RULES.TRACK_IDS.size():
		var best := _GARAGE.personal_best(_RULES.TRACK_IDS[index])
		_record_times[index].text = "N/A" if best <= 0.0 else _RULES.clock(best)


func _paint_trophies() -> void:
	var flags := _GARAGE.trophy_flags()
	for index in _panels.size():
		var won := index < flags.size() and int(flags[index]) == 1
		_marks[index].visible = not won
		_marks[index].text = "?"
		var style := _panels[index].get_theme_stylebox("panel") as StyleBoxFlat
		if style != null:
			style.bg_color = Color.WHITE if won else Color(0.8, 0.8, 0.8)
	_tickets.text = "Tickets : %d" % _GARAGE.tickets()


func _caption_text() -> String:
	if not _GARAGE.has_kart():
		return "You need a kart first! Try asking one of the clerks in the Kart Shop."
	if _kind == "":
		return "Select a Category"
	var owned := _owned_here()
	if owned.is_empty():
		return "No %s Accessory" % _word()
	var card: Dictionary = owned[_index]
	var acc_id := int(card.get("id", -1))
	if acc_id < 0:
		if _kind == "color" or _kind == "accent" or _kind == "rim":
			return "Default %s" % _word()
		return "No %s Accessory" % _word()
	return "%s %s" % [String(card.get("name", "Accessory")), _word()]


func _word() -> String:
	for row in _CATEGORIES:
		if String(row["kind"]) == _kind:
			return String(row["word"])
	return "Accessory"


func _owned_here() -> Array:
	var rows: Array = []
	if _kind == "":
		return rows
	var lookup := "color" if _kind == "accent" else _kind
	for card in _MODEL.of_kind(lookup):
		if not (card is Dictionary):
			continue
		var acc_id := int((card as Dictionary).get("id", -1))
		if _GARAGE.owns(acc_id) or (_kind == "rim" and acc_id == 40):
			rows.append(card)
	rows.append({"id": -1, "name": "No Accessory"})
	return rows


func _current() -> Dictionary:
	var owned := _owned_here()
	if owned.is_empty():
		return {}
	_index = clampi(_index, 0, owned.size() - 1)
	return owned[_index]


func _field() -> int:
	if _kind == "accent":
		return 2
	if _kind == "color":
		return 1
	return _MODEL.field_for(_kind)


func _icon_for(card: Dictionary) -> Texture2D:
	if card.is_empty() or _kind == "":
		return _art("icons/NoAccessoryIcon3")
	var acc_id := int(card.get("id", -1))
	if acc_id < 0 and _kind != "color" and _kind != "accent" and _kind != "rim":
		return _art("icons/NoAccessoryIcon3")
	if _kind == "color" or _kind == "accent":
		return _art("icons/Kartmenu_paintbucket")
	if _kind == "decal" and acc_id >= 0:
		var number := int(card.get("decal", 0))
		var slug := "kart%d" % (clampi(_GARAGE.body_type(), 0, 2) + 1)
		var hood := load("%s%s_HoodDecal_%d.png" % [_MAPS, slug, number]) as Texture2D
		if hood != null:
			return hood
	var tex_name := String(card.get("tex", ""))
	if tex_name.is_empty():
		return _art("icons/NoAccessoryIcon3")
	var icon := _art("icons/" + tex_name)
	if icon != null:
		return icon
	return load(_MAPS + tex_name + ".png") as Texture2D


func _swatch(card: Dictionary) -> Color:
	var acc_id := int(card.get("id", -1))
	if acc_id < 0:
		return Color.WHITE
	var parts: Variant = card.get("color", [])
	if parts is Array and (parts as Array).size() >= 3:
		var row: Array = parts
		return Color(float(row[0]), float(row[1]), float(row[2]))
	return Color.WHITE


func _show_kart() -> void:
	if _world == null:
		return
	if _kart != null:
		_kart.free()
		_kart = null
	if not _GARAGE.has_kart():
		return
	_kart = _MODEL.build()
	_kart.rotation.y = _yaw
	_world.add_child(_kart)


func _grow(index: int) -> void:
	var flags := _GARAGE.trophy_flags()
	if index >= flags.size() or int(flags[index]) != 1:
		return
	var style := _panels[index].get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.bg_color = _CREAM
	_trophy_line.text = "Trophy %d : %s" % [index + 1, _RULES.trophy_text(index)]


func _shrink(index: int) -> void:
	var flags := _GARAGE.trophy_flags()
	var won := index < flags.size() and int(flags[index]) == 1
	var style := _panels[index].get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.bg_color = Color.WHITE if won else Color(0.8, 0.8, 0.8)
	_trophy_line.text = ""


func _trophy_center(index: int) -> Vector2:
	if index >= 30:
		return Vector2(-0.25 + float(index - 30) * 0.25, -0.38)
	var column := index % 10
	var row := int(float(index) / 10.0)
	return Vector2(-0.76 + float(column) * 0.17, 0.475 - float(row) * 0.23)


func _spin_button(stem: String, direction: int) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _art(stem + "_up")
	button.texture_hover = _art(stem + "_roll")
	button.texture_pressed = _art(stem + "_down")
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = FOCUS_NONE
	button.z_index = 3
	button.button_down.connect(_set_spin.bind(direction))
	button.button_up.connect(_set_spin.bind(0))
	button.mouse_exited.connect(_set_spin.bind(0))
	var caption := Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = MOUSE_FILTER_IGNORE
	caption.set_anchors_preset(PRESET_FULL_RECT)
	button.add_child(caption)
	return button


func _set_spin(direction: int) -> void:
	_spin = direction


func _style_rotate(button: TextureButton) -> void:
	var caption := button.get_child(0) as Label
	if caption == null:
		return
	caption.position = Vector2.ZERO
	caption.size = button.size
	_sign(caption, Color.WHITE, _px(0.035))


func _style_delete() -> void:
	var caption := _delete.get_child(0) as Label
	if caption == null:
		return
	caption.position = Vector2.ZERO
	caption.size = _delete.size
	_sign(caption, Color.WHITE, _px(0.06))


func _camel(stem: String) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _art(stem + "Up")
	button.texture_hover = _art(stem + "Rollover")
	button.texture_pressed = _art(stem + "Down")
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = FOCUS_NONE
	return button


func _states(stem: String) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _art(stem + "_up")
	button.texture_hover = _art(stem + "_rollover")
	button.texture_pressed = _art(stem + "_down")
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = FOCUS_NONE
	return button


func _paint_arrow(button: TextureButton, stem: String, stuck: bool) -> void:
	var state := "Inactive" if stuck else "Up"
	button.texture_normal = _art(stem + state)
	button.mouse_filter = MOUSE_FILTER_IGNORE if stuck else MOUSE_FILTER_STOP


func _picture(stem: String) -> TextureRect:
	var image := TextureRect.new()
	image.texture = _art(stem)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = MOUSE_FILTER_IGNORE
	return image


func _art(stem: String) -> Texture2D:
	return load(_DIR + stem + ".png") as Texture2D


func _sign(label: Label, color: Color, px: int) -> void:
	ToonGui.style_label(label, color, px, Color(0, 0, 0), 1)
	label.add_theme_font_override("font", ToonGui.sign_font())


func _place_icon() -> void:
	if _icon == null or _page_size == Vector2.ZERO:
		return
	var lift := 0.035 if _delete != null and _delete.visible else 0.0
	_put(_icon, _rect(-0.126, -0.425 + lift, 0.126, -0.172 + lift))


func _place_confirm() -> void:
	if _confirm == null:
		return
	_confirm.position = Vector2.ZERO
	_confirm.size = _page_size
	var origin := Vector2(0.0, -0.15)
	_put(_confirm.get_child(1), _shifted(origin, -0.384, -0.232, 0.384, 0.211))
	_put(_confirm_text, _shifted(origin, -0.3, 0.0, 0.3, 0.08))
	ToonGui.style_label(_confirm_text, Color(0, 0, 0), _px(0.07), Color(0, 0, 0, 0), 0)
	_put(_confirm.get_child(3), _local_box("CancelButtonUp", origin))
	_put(_confirm.get_child(4), _local_box("CancelIcon", origin))
	_put(_confirm.get_child(5), _local_box("CheckButtonUp", origin))
	_put(_confirm.get_child(6), _local_box("CheckIcon", origin))


func _local_box(piece_name: String, origin: Vector2) -> Rect2:
	var row := _piece(piece_name)
	return _shifted(origin, float(row.get("lx0", 0.0)), float(row.get("lz0", 0.0)), float(row.get("lx1", 0.0)), float(row.get("lz1", 0.0)))


func _shifted(origin: Vector2, x0: float, z0: float, x1: float, z1: float) -> Rect2:
	return _rect(origin.x + x0, origin.y + z0, origin.x + x1, origin.y + z1)


func _arrow_box(row: Dictionary) -> Rect2:
	return _rect(float(row.get("lx0", 0.0)), 0.209 + float(row.get("lz0", 0.0)), float(row.get("lx1", 0.0)), 0.209 + float(row.get("lz1", 0.0)))


func _piece(piece_name: String) -> Dictionary:
	var pieces: Variant = _layout.get("pieces", {})
	if not (pieces is Dictionary):
		return {}
	var row: Variant = (pieces as Dictionary).get(piece_name, {})
	return row if row is Dictionary else {}


func _bounds(row: Dictionary) -> Rect2:
	return _rect(float(row.get("x0", 0.0)), float(row.get("z0", 0.0)), float(row.get("x1", 0.0)), float(row.get("z1", 0.0)))


func box_z0(row: Dictionary) -> float:
	return float(row.get("z0", 0.0))


func box_z1(row: Dictionary) -> float:
	return float(row.get("z1", 0.0))


func _rect(x0: float, z0: float, x1: float, z1: float) -> Rect2:
	var top := _book_point(minf(x0, x1), maxf(z0, z1), _page_size)
	var bottom := _book_point(maxf(x0, x1), minf(z0, z1), _page_size)
	return Rect2(top, bottom - top)


func _book_point(book_x: float, book_z: float, page_size: Vector2) -> Vector2:
	var fx := (book_x + 1.0) / 2.0
	var fy := (0.75 - book_z) / 1.5
	return Vector2((fx - 0.0635) / 0.873 * page_size.x, (fy - 0.0118) / 0.873 * page_size.y)


func _px(aspect_h: float) -> int:
	return maxi(int(abs(_book_point(0.0, 0.0, _page_size).y - _book_point(0.0, aspect_h, _page_size).y)), 8)


func _put(node: Control, box: Rect2) -> void:
	if node == null:
		return
	node.position = box.position
	node.size = box.size
