class_name CogGallery
extends Control

## SuitPage. Four departments, eight cogs each, in suitHeadTypes order.
## A defeat fills in the head, the name, and "n of quota". The first quota
## turns the card olive, and the second turns it gold. Radar and summons stay
## out: this game has no district suit planner to ask.

const _SAVE := "user://cog_gallery.json"
const _GUI := "res://assets/gui/shticker/gallery/"
const _FRAME := preload("res://assets/gui/shticker/gallery/frame.png")
const _CARD := preload("res://assets/gui/shticker/gallery/card.png")
const _ICONS: Array[Texture2D] = [
	preload("res://assets/gui/shticker/gallery/corp_icon.png"),
	preload("res://assets/gui/shticker/gallery/legal_icon.png"),
	preload("res://assets/gui/shticker/gallery/money_icon.png"),
	preload("res://assets/gui/shticker/gallery/sales_icon.png"),
]

# SuitPage.makePanels. The board is wide enough for the dept icons on the left
# and the last card on the right. The frame sits inside that board.
const _X0 := -0.90
const _Z1 := 0.725
const _BOARD := Vector2(1.80, 1.35)
# card geom is 0.334 by 0.48, then the panel scale of 0.6.
const _CARD_SIZE := Vector2(0.2004, 0.288)
const _CARD_HALF := Vector2(0.1002, 0.144)

const _CODES: PackedStringArray = [
	"f", "p", "ym", "mm", "ds", "hh", "cr", "tbc",
	"bf", "b", "dt", "ac", "bs", "sd", "le", "bw",
	"sc", "pp", "tw", "bc", "nc", "mb", "ls", "rb",
	"cc", "tm", "nd", "gh", "ms", "tf", "m", "mh",
]
# \n is the original \x03 break in the suit name.
const _NAMES: PackedStringArray = [
	"Flunky", "Pencil Pusher", "Yesman", "Micro\nmanager",
	"Downsizer", "Head Hunter", "Corporate Raider", "The Big Cheese",
	"Bottom Feeder", "Blood\nsucker", "Double Talker", "Ambulance Chaser",
	"Back Stabber", "Spin Doctor", "Legal Eagle", "Big Wig",
	"Short Change", "Penny Pincher", "Tightwad", "Bean Counter",
	"Number Cruncher", "Money Bags", "Loan Shark", "Robber Baron",
	"Cold Caller", "Tele\nmarketer", "Name Dropper", "Glad Hander",
	"Mover & Shaker", "Two-Face", "The Mingler", "Mr. Hollywood",
]
const _QUOTA_0: PackedInt32Array = [30, 25, 20, 15, 10, 5, 2, 1]
const _QUOTA_1: PackedInt32Array = [45, 40, 35, 30, 25, 20, 15, 10]
const _PANEL: Array[Color] = [
	Color(0.8, 0.78, 0.77),
	Color(0.75, 0.78, 0.8),
	Color(0.75, 0.82, 0.79),
	Color(0.825, 0.76, 0.77),
]
const _PANEL_1: Array[Color] = [
	Color(0.7, 0.725, 0.545),
	Color(0.625, 0.725, 0.65),
	Color(0.6, 0.75, 0.525),
	Color(0.675, 0.675, 0.55),
]
const _PANEL_2: Array[Color] = [
	Color(0.9, 0.725, 0.32),
	Color(0.825, 0.725, 0.45),
	Color(0.8, 0.75, 0.325),
	Color(0.875, 0.675, 0.35),
]
# Tight bounds of shadow1..shadow32, then SuitPage.SHADOW_SCALE_POS (scale, x, z).
const _SHADOW_SIZE: PackedFloat32Array = [
	0.2417, 0.2333, 0.1458, 0.3250, 0.2875, 0.2708, 0.2958, 0.3042,
	0.2167, 0.3375, 0.3208, 0.3125, 0.3333, 0.3208, 0.3000, 0.3833,
	0.2458, 0.2250, 0.1542, 0.3000, 0.2583, 0.3042, 0.1542, 0.3208,
	0.1750, 0.3375, 0.2458, 0.3500, 0.3125, 0.3208, 0.3708, 0.3958,
	0.2167, 0.2583, 0.1583, 0.2833, 0.2833, 0.2583, 0.1667, 0.3250,
	0.3042, 0.3292, 0.3208, 0.2625, 0.2458, 0.3708, 0.3750, 0.3667,
	0.2167, 0.2542, 0.2125, 0.3042, 0.2333, 0.2875, 0.2917, 0.2375,
	0.1625, 0.3250, 0.2875, 0.3500, 0.2875, 0.3458, 0.3750, 0.3625,
]
const _SHADOW_PLACE: PackedFloat32Array = [
	1.225, 0.0, -0.03, 0.9, 0.0, 0.0, 1.125, 0.0, -0.015, 1.0, 0.0, -0.02,
	1.0, -0.02, -0.01, 1.05, 0.0, -0.0425, 1.0, 0.0, -0.05, 0.9, -0.0225, -0.025,
	1.25, 0.0, -0.03, 1.0, 0.0, -0.01, 1.0, 0.005, -0.01, 1.0, 0.0, -0.01,
	0.9, 0.005, -0.01, 0.95, 0.0, -0.01, 1.125, 0.005, -0.035, 0.85, -0.005, -0.035,
	1.2, 0.0, -0.01, 1.05, 0.0, 0.0, 1.1, 0.0, -0.04, 1.0, 0.0, 0.0,
	0.95, 0.0175, -0.015, 1.0, 0.0, -0.06, 0.95, 0.02, -0.0175, 0.9, 0.0, -0.03,
	1.15, 0.0, -0.01, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.1, 0.0, -0.04,
	0.93, 0.005, -0.01, 0.95, 0.005, -0.01, 1.0, 0.0, -0.02, 0.9, 0.0025, -0.03,
]
# corp, legal, money, sales vertex bounds on the unscaled frame.
const _ICON_BOX: PackedFloat32Array = [
	-19.74, 6.31, -15.94, 11.72,
	-19.74, -0.19, -15.94, 5.22,
	-19.74, -6.69, -15.94, -1.28,
	-19.74, -13.19, -15.94, -7.78,
]

var _board_pos := Vector2.ZERO
var _board_size := Vector2.ZERO
var _frame: TextureRect
var _plate: Label
var _cards: Array[TextureRect] = []
var _names: Array[Label] = []
var _mysteries: Array[Label] = []
var _quotas: Array[Label] = []
var _shadows: Array[TextureRect] = []
var _heads: Array[TextureRect] = []
var _dept_icons: Array[TextureRect] = []
var _mounted: Array[bool] = []


static func note(cog: String) -> void:
	var code := _resolve(cog)
	if code.is_empty():
		return
	var slot := ToonRoster.selected_index()
	if slot < 0 or slot >= ToonRoster.SLOT_COUNT:
		return
	var root := _read_file()
	var slots: Array = root.get("slots", [])
	while slots.size() < ToonRoster.SLOT_COUNT:
		slots.append({})
	var counts: Dictionary = slots[slot] if typeof(slots[slot]) == TYPE_DICTIONARY else {}
	counts[code] = int(counts.get(code, 0)) + 1
	slots[slot] = counts
	root["slots"] = slots
	var file := FileAccess.open(_SAVE, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(root))


func _init() -> void:
	name = "Cogs"
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	_frame = TextureRect.new()
	_frame.texture = _FRAME
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_frame)
	for index in _CODES.size():
		var card := TextureRect.new()
		card.texture = _CARD
		card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.stretch_mode = TextureRect.STRETCH_SCALE
		card.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(card)
		var shadow := TextureRect.new()
		shadow.texture = load(_GUI + "shadow_%d.png" % (index + 1))
		shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shadow.stretch_mode = TextureRect.STRETCH_SCALE
		shadow.mouse_filter = MOUSE_FILTER_IGNORE
		shadow.visible = false
		card.add_child(shadow)
		var head := TextureRect.new()
		head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		head.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		head.mouse_filter = MOUSE_FILTER_IGNORE
		head.visible = false
		card.add_child(head)
		var cog_name := _suit_label(_NAMES[index])
		card.add_child(cog_name)
		var quota := _suit_label("")
		quota.visible = false
		card.add_child(quota)
		# SuitPageMystery uses the panel text. Its baseline is the card's text_pos, not the name box.
		var mystery := _suit_label("???")
		mystery.autowrap_mode = TextServer.AUTOWRAP_OFF
		mystery.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		card.add_child(mystery)
		_cards.append(card)
		_shadows.append(shadow)
		_heads.append(head)
		_names.append(cog_name)
		_mysteries.append(mystery)
		_quotas.append(quota)
		_mounted.append(false)
	for icon_index in _ICONS.size():
		var icon := TextureRect.new()
		icon.texture = _ICONS[icon_index]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(icon)
		_dept_icons.append(icon)
	_plate = Label.new()
	_plate.text = "Cog Gallery"
	_plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_plate.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_plate)


func layout(page_size: Vector2) -> void:
	var board_w := page_size.x
	var board_h := board_w * _BOARD.y / _BOARD.x
	if board_h > page_size.y:
		board_h = page_size.y
		board_w = board_h * _BOARD.x / _BOARD.y
	_board_size = Vector2(board_w, board_h)
	_board_pos = Vector2((page_size.x - board_w) * 0.5, (page_size.y - board_h) * 0.5)
	_frame.position = _point(-0.675, 0.725)
	_frame.size = _span(1.35, 1.35)
	# The name plate is the clipboard tab on suitpage_frame, pixels 71..194 by 2..20.
	_plate.position = _frame.position + Vector2(71.0, 2.0) / 256.0 * _frame.size
	_plate.size = Vector2(123.0, 18.0) / 256.0 * _frame.size
	ToonGui.style_label(_plate, Color(0.1, 0.1, 0.1), maxi(int(_plate.size.y * 0.62), 10), Color(0, 0, 0, 0), 0)
	for index in _cards.size():
		_layout_card(index)
	for icon_index in _dept_icons.size():
		var box := _icon_rect(icon_index)
		_dept_icons[icon_index].position = box.position
		_dept_icons[icon_index].size = box.size


func refresh() -> void:
	var counts := _counts()
	for index in _CODES.size():
		_paint(index, int(counts.get(_CODES[index], 0)))


func _layout_card(index: int) -> void:
	var row := int(index / 8)
	var col := index % 8
	var ax := -0.66 + float(col) * 0.199
	var az := 0.445 - float(row) * 0.284
	var card := _cards[index]
	card.position = _point(ax - _CARD_HALF.x, az + _CARD_HALF.y)
	card.size = _span(_CARD_SIZE.x, _CARD_SIZE.y)
	var px := maxi(int(card.size.x * 0.13), 8)
	_style_suit(_names[index], px)
	_style_suit(_quotas[index], px)
	_style_suit(_mysteries[index], px)
	_names[index].position = Vector2(0.0, card.size.y * 0.02)
	_names[index].size = Vector2(card.size.x, card.size.y * 0.26)
	# Card geom is z -0.2396..0.2396. text_pos (0, 0.185, 0) puts the baseline at z 0.185.
	var font := ToonGui.suit_font()
	var baseline := card.size.y * ((0.239583 - 0.185) / 0.479166)
	_mysteries[index].position = Vector2(0.0, maxf(baseline - font.get_ascent(px), 0.0))
	_mysteries[index].size = Vector2(card.size.x, font.get_height(px) + 2.0)
	_quotas[index].position = Vector2(0.0, card.size.y * 0.80)
	_quotas[index].size = Vector2(card.size.x, card.size.y * 0.17)
	_heads[index].position = Vector2(card.size.x * 0.14, card.size.y * 0.28)
	_heads[index].size = Vector2(card.size.x * 0.72, card.size.y * 0.50)
	var fitted := _SHADOW_PLACE[index * 3] * 0.6
	var ox := _SHADOW_PLACE[index * 3 + 1] * 0.6
	var oz := _SHADOW_PLACE[index * 3 + 2] * 0.6
	var shadow_size := _span(_SHADOW_SIZE[index * 2] * fitted, _SHADOW_SIZE[index * 2 + 1] * fitted)
	_shadows[index].size = shadow_size
	_shadows[index].position = _point(ax + ox, az + oz) - card.position - shadow_size * 0.5


func _paint(index: int, count: int) -> void:
	var row := int(index / 8)
	var col := index % 8
	var color := _PANEL[row]
	var quota := _QUOTA_0[col]
	if count >= _QUOTA_1[col]:
		color = _PANEL_2[row]
		quota = _QUOTA_1[col]
	elif count >= _QUOTA_0[col]:
		color = _PANEL_1[row]
		quota = _QUOTA_1[col]
	_cards[index].self_modulate = color
	var seen := count > 0
	_names[index].text = _NAMES[index]
	_names[index].visible = seen
	_mysteries[index].visible = not seen
	_quotas[index].text = "%d of %d" % [count, quota]
	_quotas[index].visible = seen
	_shadows[index].visible = seen
	_heads[index].visible = seen
	if seen:
		_mount_head(index)


func _mount_head(index: int) -> void:
	if _mounted[index]:
		return
	_mounted[index] = true
	var packed := load("res://assets/cogs/heads/%s.glb" % _CODES[index]) as PackedScene
	if packed == null:
		return
	var port := SubViewport.new()
	port.transparent_bg = true
	port.own_world_3d = true
	port.size = Vector2i(160, 160)
	port.gui_disable_input = true
	port.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(port)
	var stage := Node3D.new()
	port.add_child(stage)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.1
	world.environment = env
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.2
	key.rotation_degrees = Vector3(-25.0, 180.0, 0.0)
	stage.add_child(key)
	var actor := packed.instantiate() as Node3D
	stage.add_child(actor)
	var holder := Node3D.new()
	stage.add_child(holder)
	_copy_head(actor, holder)
	stage.remove_child(actor)
	actor.free()
	var camera := Camera3D.new()
	camera.fov = 28.0
	camera.current = true
	camera.position = Vector3(0.0, 0.02, 2.05)
	stage.add_child(camera)
	_heads[index].texture = port.get_texture()


func _copy_head(actor: Node3D, holder: Node3D) -> void:
	var merged := AABB()
	var found := false
	for node in actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		var copy := mesh.duplicate() as MeshInstance3D
		copy.transform = _pose(mesh, actor)
		holder.add_child(copy)
		var box := copy.transform * copy.get_aabb()
		merged = box if not found else merged.merge(box)
		found = true
	if not found:
		return
	var center := merged.get_center()
	for child in holder.get_children():
		var placed := child as Node3D
		placed.position -= center
	var biggest := maxf(merged.size.x, maxf(merged.size.y, merged.size.z))
	if biggest < 0.001:
		biggest = 1.0
	holder.scale = Vector3.ONE / biggest


func _pose(mesh: Node3D, actor: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var node: Node = mesh
	while node is Node3D:
		xform = (node as Node3D).transform * xform
		if node == actor:
			break
		node = node.get_parent()
	return xform


func _icon_rect(index: int) -> Rect2:
	var x0 := _ICON_BOX[index * 4]
	var z0 := _ICON_BOX[index * 4 + 1]
	var x1 := _ICON_BOX[index * 4 + 2]
	var z1 := _ICON_BOX[index * 4 + 3]
	# DirectButton image_scale matches the frame scale. The button sits on the frame.
	var ax0 := -0.2 + x0 * 0.03375
	var ax1 := -0.2 + x1 * 0.03375
	var az0 := 0.05 + z0 * 0.045
	var az1 := 0.05 + z1 * 0.045
	return Rect2(_point(ax0, az1), _span(ax1 - ax0, az1 - az0))


func _point(ax: float, az: float) -> Vector2:
	var fx := (ax - _X0) / _BOARD.x
	var fy := (_Z1 - az) / _BOARD.y
	return _board_pos + Vector2(fx * _board_size.x, fy * _board_size.y)


func _span(aw: float, ah: float) -> Vector2:
	return Vector2(aw / _BOARD.x * _board_size.x, ah / _BOARD.y * _board_size.y)


func _suit_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = MOUSE_FILTER_IGNORE
	return label


func _style_suit(label: Label, px: int) -> void:
	label.add_theme_font_override("font", ToonGui.suit_font())
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", Color.BLACK)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	label.add_theme_constant_override("outline_size", 0)


static func _counts() -> Dictionary:
	var slot := ToonRoster.selected_index()
	if slot < 0:
		return {}
	var slots: Array = _read_file().get("slots", [])
	if slot >= slots.size() or typeof(slots[slot]) != TYPE_DICTIONARY:
		return {}
	return slots[slot]


static func _read_file() -> Dictionary:
	if not FileAccess.file_exists(_SAVE):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_SAVE))
	if parsed is Dictionary:
		return parsed
	return {}


static func _resolve(cog: String) -> String:
	var key := cog.strip_edges().to_lower()
	if _CODES.has(key):
		return key
	var compact := key.replace(" ", "").replace(".", "").replace("-", "").replace("&", "").replace("\n", "")
	for index in _CODES.size():
		var name := _NAMES[index].to_lower().replace(" ", "").replace(".", "").replace("-", "").replace("&", "").replace("\n", "")
		if name == compact:
			return _CODES[index]
	return ""
