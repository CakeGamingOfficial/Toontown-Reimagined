class_name CogGallery
extends Control

## SuitPage. Four departments, eight cogs each, in suitHeadTypes order.
## A defeat fills in the head, the name, and "n of quota". The first quota
## turns the card olive, and the second turns it gold. The department icon is
## the radar button. It wakes once every cog in that department has reached
## the first quota, and the building count wakes at the second. The leaked
## CogPageManagerAI.toonKilledCogs is a stub, so the unlock follows those
## gallery tiers. A click counts the street the toon is standing on.
## A summons button sits on a cog you have already met when you hold a
## summons for that cog. The scroll icon is not in the exported book gui,
## so the button is the original OK button and its "Summon" hover.

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
const _PLATE := preload("res://assets/gui/friends/avatar_panel.png")
const _REWARDS := preload("res://scenes/cog_hq/boss_rewards.gd")
const _DIALOG := preload("res://assets/gui/tutorial/dialog/dialog_box.png")
const _SUMMON_UP := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_UP.png")
const _SUMMON_DOWN := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_DN.png")
const _SUMMON_HOVER := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_Rllvr.png")
const _QUIT_UP := preload("res://assets/toons/gui/QuitBtn_UP.png")
const _QUIT_DOWN := preload("res://assets/toons/gui/QuitBtn_DN.png")
const _QUIT_HOVER := preload("res://assets/toons/gui/QuitBtn_RLVR.png")
const _CLOSE_UP := preload("res://assets/toons/gui/CloseBtn_UP.png")
const _CLOSE_DOWN := preload("res://assets/toons/gui/CloseBtn_DN.png")
const _CLOSE_HOVER := preload("res://assets/toons/gui/CloseBtn_Rllvr.png")
const _HOLIDAYS := preload("res://scenes/shticker/calendar_holidays.gd")
const _DEPTS: PackedStringArray = ["c", "l", "m", "s"]
## SuitPage.RADAR_DELAY. Each cog in the row appears 0.2 seconds after the last.
const _RADAR_DELAY := 0.2
## SuitPage.BUILDING_RADAR_POS, the label's z on the department button.
const _BUILDING_Z: PackedFloat32Array = [0.375, 0.065, -0.225, -0.5]

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
var _dept_icons: Array[TextureButton] = []
var _radar_labels: Array[Label] = []
var _summon_buttons: Array[TextureButton] = []
var _summon_hints: Array[Label] = []
var _summon_dialog: Control
var _summon_index := -1
var _building_plates: Array[TextureRect] = []
var _building_tags: Array[Label] = []
var _radar_on: Array[bool] = [false, false, false, false]
var _scanning: Array[bool] = [false, false, false, false]
var _cog_ready: Array[bool] = [false, false, false, false]
var _bldg_ready: Array[bool] = [false, false, false, false]
var _scan_id: Array[int] = [0, 0, 0, 0]
var _building_count: Array[int] = [0, 0, 0, 0]
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
		var radar := _suit_label("")
		radar.visible = false
		card.add_child(radar)
		var summon := TextureButton.new()
		summon.texture_normal = _SUMMON_UP
		summon.texture_pressed = _SUMMON_DOWN
		summon.texture_hover = _SUMMON_HOVER
		summon.ignore_texture_size = true
		summon.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		summon.focus_mode = Control.FOCUS_NONE
		summon.mouse_filter = MOUSE_FILTER_STOP
		summon.visible = false
		summon.z_index = 3
		ToonGui.button_sounds(summon)
		summon.mouse_entered.connect(_hover_summon.bind(index, true))
		summon.mouse_exited.connect(_hover_summon.bind(index, false))
		summon.pressed.connect(_open_summon.bind(index))
		card.add_child(summon)
		var hint := _suit_label("Summon")
		hint.visible = false
		hint.mouse_filter = MOUSE_FILTER_IGNORE
		hint.z_index = 4
		card.add_child(hint)
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
		_radar_labels.append(radar)
		_summon_buttons.append(summon)
		_summon_hints.append(hint)
		_mounted.append(false)
	for icon_index in _ICONS.size():
		var icon := TextureButton.new()
		icon.texture_normal = _ICONS[icon_index]
		icon.texture_hover = _ICONS[icon_index]
		icon.texture_pressed = _ICONS[icon_index]
		icon.ignore_texture_size = true
		icon.stretch_mode = TextureButton.STRETCH_SCALE
		icon.focus_mode = Control.FOCUS_NONE
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		icon.mouse_entered.connect(_hover_icon.bind(icon_index, true))
		icon.mouse_exited.connect(_hover_icon.bind(icon_index, false))
		icon.pressed.connect(_toggle_radar.bind(icon_index))
		add_child(icon)
		_dept_icons.append(icon)
		var plate := TextureRect.new()
		plate.texture = _PLATE
		plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		plate.stretch_mode = TextureRect.STRETCH_SCALE
		plate.mouse_filter = MOUSE_FILTER_IGNORE
		plate.visible = false
		plate.pivot_offset = plate.size * 0.5
		add_child(plate)
		var tag := _suit_label("0 buildings")
		tag.visible = false
		tag.add_theme_color_override("font_color", Color(1, 0, 0, 1))
		add_child(tag)
		_building_plates.append(plate)
		_building_tags.append(tag)
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
		_layout_building(icon_index)


func refresh() -> void:
	_cancel_radar()
	_apply_counts()


func _notification(what: int) -> void:
	if what != NOTIFICATION_VISIBILITY_CHANGED or is_visible_in_tree():
		return
	if _cards.size() < _CODES.size():
		return
	_close_summon()
	_cancel_radar()
	_apply_counts()


func _apply_counts() -> void:
	var counts := _counts()
	for dept in _DEPTS.size():
		var cog_ready := true
		var bldg_ready := true
		for col in 8:
			var have := int(counts.get(_CODES[dept * 8 + col], 0))
			if have < _QUOTA_0[col]:
				cog_ready = false
			if have < _QUOTA_1[col]:
				bldg_ready = false
		_cog_ready[dept] = cog_ready
		_bldg_ready[dept] = bldg_ready
		_arm_icon(dept)
	for index in _CODES.size():
		_paint(index, int(counts.get(_CODES[index], 0)))


func _layout_building(dept: int) -> void:
	# The button origin is (-0.2, 0.05). The label sits 0.225 to the right.
	var origin := _point(0.025, 0.05 + _BUILDING_Z[dept])
	var plate := _building_plates[dept]
	plate.size = _span(0.05, 0.1)
	plate.pivot_offset = plate.size * 0.5
	plate.rotation_degrees = 90.0
	plate.position = origin + Vector2(0.0, _span(0.0, 0.015).y) - plate.size * 0.5
	var tag := _building_tags[dept]
	var px := maxi(int(_span(0.05, 0.05).y), 8)
	_style_suit(tag, px)
	tag.add_theme_color_override("font_color", Color(1, 0, 0, 1))
	tag.size = _span(0.34, 0.06)
	tag.position = origin - tag.size * 0.5


func _toggle_radar(dept: int) -> void:
	if dept < 0 or dept >= _DEPTS.size() or not _cog_ready[dept] or _scanning[dept]:
		return
	if _radar_on[dept]:
		_scan_id[dept] += 1
		_radar_on[dept] = false
		_hide_dept(dept)
		_arm_icon(dept)
		return
	_radar_on[dept] = true
	_scanning[dept] = true
	_scan_id[dept] += 1
	var token := _scan_id[dept]
	_arm_icon(dept)
	var present := _present(dept)
	_building_count[dept] = _buildings(dept)
	for col in 8:
		var index := dept * 8 + col
		_quotas[index].visible = false
		_radar_labels[index].text = "%d present" % present[index]
		_radar_labels[index].visible = false
		var wait := _RADAR_DELAY * float(col)
		get_tree().create_timer(wait, true).timeout.connect(_reveal_cog.bind(dept, index, token))
	get_tree().create_timer(_RADAR_DELAY * 8.0, true).timeout.connect(_finish_scan.bind(dept, token))


func _reveal_cog(dept: int, index: int, token: int) -> void:
	if token != _scan_id[dept] or not _radar_on[dept]:
		return
	_radar_labels[index].visible = true


func _finish_scan(dept: int, token: int) -> void:
	if token != _scan_id[dept] or not _radar_on[dept]:
		return
	_scanning[dept] = false
	if _bldg_ready[dept]:
		var count := _building_count[dept]
		if count == 1:
			_building_tags[dept].text = "%d building" % count
		else:
			_building_tags[dept].text = "%d buildings" % count
		_building_plates[dept].visible = true
		_building_tags[dept].visible = true
	_arm_icon(dept)


func _cancel_radar() -> void:
	for dept in _DEPTS.size():
		_scan_id[dept] += 1
		_radar_on[dept] = false
		_scanning[dept] = false
		_hide_dept(dept)
		if dept < _dept_icons.size():
			_arm_icon(dept)


func _hide_dept(dept: int) -> void:
	_building_plates[dept].visible = false
	_building_tags[dept].visible = false
	for col in 8:
		var index := dept * 8 + col
		_radar_labels[index].visible = false
		if _names[index].visible:
			_quotas[index].visible = true


func _arm_icon(dept: int) -> void:
	if dept >= _dept_icons.size():
		return
	var icon := _dept_icons[dept]
	var open := _cog_ready[dept] and not _scanning[dept]
	icon.mouse_filter = MOUSE_FILTER_STOP if open else MOUSE_FILTER_IGNORE
	if not open:
		icon.modulate = Color.WHITE


func _hover_icon(dept: int, over: bool) -> void:
	if dept >= _dept_icons.size() or not _cog_ready[dept] or _scanning[dept]:
		return
	_dept_icons[dept].modulate = Color(1, 1, 1, 0.75) if over else Color.WHITE


func _hover_summon(index: int, over: bool) -> void:
	if index < 0 or index >= _summon_hints.size() or not _summon_buttons[index].visible:
		return
	_summon_hints[index].visible = over


func _input(event: InputEvent) -> void:
	if _summon_dialog == null or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	var ask := _summon_dialog.get_node_or_null("Ask") as Control
	if ask != null and ask.visible:
		ask.visible = false
		return
	_close_summon()


func _open_summon(index: int) -> void:
	if index < 0 or index >= _CODES.size() or not _summon_buttons[index].visible:
		return
	_close_summon()
	_summon_index = index
	var host := Control.new()
	host.name = "SummonDialog"
	host.mouse_filter = MOUSE_FILTER_STOP
	host.z_index = 80
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_book().add_child(host)
	_summon_dialog = host
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.mouse_filter = MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(dim)
	var frame := TextureRect.new()
	frame.name = "Frame"
	frame.texture = _DIALOG
	frame.modulate = Color(1, 1, 0.75, 1)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	host.add_child(frame)
	var title := _plain_label("Issue a Cog Summons")
	title.name = "Title"
	host.add_child(title)
	var portrait := TextureRect.new()
	portrait.name = "Head"
	portrait.texture = _heads[index].texture
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = MOUSE_FILTER_IGNORE
	portrait.visible = portrait.texture != null
	host.add_child(portrait)
	var cog_name := _suit_label(_spoken(index))
	cog_name.name = "CogName"
	host.add_child(cog_name)
	_choice(host, "Summon a Cog", "single", 0.42)
	_choice(host, "Summon a Cog Building", "building", 0.24)
	_choice(host, "Summon a Cog Invasion", "invasion", 0.06)
	var status := _plain_label("")
	status.name = "Status"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.visible = false
	host.add_child(status)
	var close := TextureButton.new()
	close.name = "Close"
	close.texture_normal = _CLOSE_UP
	close.texture_pressed = _CLOSE_DOWN
	close.texture_hover = _CLOSE_HOVER
	close.ignore_texture_size = true
	close.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close.focus_mode = Control.FOCUS_NONE
	ToonGui.button_sounds(close)
	close.pressed.connect(_close_summon)
	host.add_child(close)
	var ask := Control.new()
	ask.name = "Ask"
	ask.visible = false
	ask.mouse_filter = MOUSE_FILTER_STOP
	ask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(ask)
	var ask_dim := ColorRect.new()
	ask_dim.color = Color(0, 0, 0, 0.35)
	ask_dim.mouse_filter = MOUSE_FILTER_STOP
	ask_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ask.add_child(ask_dim)
	var ask_frame := TextureRect.new()
	ask_frame.name = "AskFrame"
	ask_frame.texture = _DIALOG
	ask_frame.modulate = Color(1, 1, 0.75, 1)
	ask_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ask_frame.stretch_mode = TextureRect.STRETCH_SCALE
	ask_frame.mouse_filter = MOUSE_FILTER_IGNORE
	ask.add_child(ask_frame)
	var question := _plain_label("")
	question.name = "Question"
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ask.add_child(question)
	_yes_no(ask, "Yes", true)
	_yes_no(ask, "No", false)
	_layout_summon()


func _choice(host: Control, text: String, kind: String, z: float) -> void:
	var button := TextureButton.new()
	button.name = kind
	button.texture_normal = _QUIT_UP
	button.texture_pressed = _QUIT_DOWN
	button.texture_hover = _QUIT_HOVER
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	ToonGui.button_sounds(button)
	button.set_meta("z", z)
	var dept := int(_summon_index / 8)
	var cog_type := _summon_index % 8
	var held := _REWARDS.has_summon(dept, cog_type, kind)
	button.disabled = not held
	button.modulate = Color(0.5, 0.5, 0.5, 1) if not held else Color.WHITE
	button.pressed.connect(_ask_summon.bind(kind))
	host.add_child(button)
	var caption := _plain_label(text)
	caption.name = kind + "Label"
	caption.mouse_filter = MOUSE_FILTER_IGNORE
	host.add_child(caption)


func _yes_no(ask: Control, text: String, yes: bool) -> void:
	var button := TextureButton.new()
	button.name = "Yes" if yes else "No"
	button.texture_normal = _SUMMON_UP if yes else _CLOSE_UP
	button.texture_pressed = _SUMMON_DOWN if yes else _CLOSE_DOWN
	button.texture_hover = _SUMMON_HOVER if yes else _CLOSE_HOVER
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.focus_mode = Control.FOCUS_NONE
	ToonGui.button_sounds(button)
	button.pressed.connect(_answer_summon.bind(yes))
	ask.add_child(button)
	var caption := _plain_label(text)
	caption.name = button.name + "Label"
	caption.mouse_filter = MOUSE_FILTER_IGNORE
	ask.add_child(caption)


func _ask_summon(kind: String) -> void:
	if _summon_dialog == null:
		return
	var ask := _summon_dialog.get_node_or_null("Ask") as Control
	var question := _summon_dialog.get_node_or_null("Ask/Question") as Label
	if ask == null or question == null:
		return
	var cog_name := _spoken(_summon_index)
	if kind == "building":
		question.text = "Would you like to summon a %s to a nearby Toon building?" % cog_name
	elif kind == "invasion":
		question.text = "Would you like to summon a %s invasion?" % cog_name
	else:
		question.text = "Would you like to issue a summons to a %s?" % cog_name
	ask.set_meta("kind", kind)
	ask.visible = true
	_layout_summon()


func _answer_summon(yes: bool) -> void:
	if _summon_dialog == null:
		return
	var ask := _summon_dialog.get_node_or_null("Ask") as Control
	if ask == null:
		return
	var kind := String(ask.get_meta("kind", "single"))
	ask.visible = false
	if not yes:
		return
	var dept := int(_summon_index / 8)
	var cog_type := _summon_index % 8
	var code := _REWARDS.spend_summon(dept, cog_type, kind)
	var cog_name := _spoken(_summon_index)
	var status := _summon_dialog.get_node_or_null("Status") as Label
	if status != null:
		status.visible = true
		if code == "success" and kind == "building":
			status.text = "You have successfully summoned the Cogs. A Shopkeeper has agreed to let them temporarily take over their building!"
		elif code == "success" and kind == "invasion":
			status.text = "You have successfully summoned the Cogs. It's an invasion!"
		elif code == "success":
			status.text = "You have successfully summoned the Cog."
		elif code == "busy":
			status.text = "A %s cannot be found now.  Try again when the Cog invasion is over." % cog_name
		elif code == "badlocation" and kind == "building":
			status.text = "Sorry, there are no Toon buildings nearby for the Cogs to take over."
		elif code == "badlocation":
			status.text = "Sorry, Cogs aren't allowed here.  Try somewhere else."
		else:
			status.text = "Sorry, the Cog invasion has failed."
	var choices: PackedStringArray = ["single", "building", "invasion"]
	for choice in choices:
		var button := _summon_dialog.get_node_or_null(choice) as CanvasItem
		var caption := _summon_dialog.get_node_or_null(choice + "Label") as CanvasItem
		if button != null:
			button.visible = false
		if caption != null:
			caption.visible = false
	_apply_counts()


func _layout_summon() -> void:
	if _summon_dialog == null:
		return
	var view := _summon_dialog.get_viewport().get_visible_rect().size
	var frame := _summon_dialog.get_node_or_null("Frame") as Control
	var title := _summon_dialog.get_node_or_null("Title") as Label
	var portrait := _summon_dialog.get_node_or_null("Head") as Control
	var cog_name := _summon_dialog.get_node_or_null("CogName") as Label
	var status := _summon_dialog.get_node_or_null("Status") as Label
	var close := _summon_dialog.get_node_or_null("Close") as Control
	if frame == null or title == null or portrait == null or cog_name == null or status == null or close == null:
		return
	ToonGui.place(frame, view, 0.0, 0.42, 1.7, 0.95)
	var title_px := maxi(int(round(0.06 * view.y * 0.5)), 10)
	ToonGui.style_label(title, Color(0.08, 0.08, 0.08), title_px, Color(0, 0, 0, 0), 0)
	ToonGui.place(title, view, 0.0, 0.78, 1.4, 0.1)
	ToonGui.place(portrait, view, -0.48, 0.48, 0.28, 0.28)
	var name_px := maxi(int(round(0.045 * view.y * 0.5)), 8)
	_style_suit(cog_name, name_px)
	ToonGui.place(cog_name, view, -0.48, 0.22, 0.5, 0.12)
	var body_px := maxi(int(round(0.035 * view.y * 0.5)), 8)
	var choices: PackedStringArray = ["single", "building", "invasion"]
	for choice in choices:
		var button := _summon_dialog.get_node_or_null(choice) as Control
		var caption := _summon_dialog.get_node_or_null(choice + "Label") as Label
		if button == null or caption == null:
			continue
		var z := float(button.get_meta("z", 0.0))
		ToonGui.place(button, view, 0.32, z, 0.72, 0.14)
		ToonGui.style_label(caption, Color(0.08, 0.08, 0.08), body_px, Color(0, 0, 0, 0), 0)
		ToonGui.place(caption, view, 0.32, z, 0.66, 0.1)
	ToonGui.style_label(status, Color(0.08, 0.08, 0.08), body_px, Color(0, 0, 0, 0), 0)
	ToonGui.place(status, view, 0.28, 0.24, 0.7, 0.4)
	ToonGui.place(close, view, 0.68, 0.02, 0.12, 0.12)
	var ask := _summon_dialog.get_node_or_null("Ask") as Control
	if ask == null:
		return
	var ask_frame := ask.get_node_or_null("AskFrame") as Control
	var question := ask.get_node_or_null("Question") as Label
	var yes := ask.get_node_or_null("Yes") as Control
	var no := ask.get_node_or_null("No") as Control
	var yes_label := ask.get_node_or_null("YesLabel") as Label
	var no_label := ask.get_node_or_null("NoLabel") as Label
	if ask_frame == null or question == null or yes == null or no == null or yes_label == null or no_label == null:
		return
	ToonGui.place(ask_frame, view, 0.0, 0.15, 1.35, 0.55)
	ToonGui.style_label(question, Color(0.08, 0.08, 0.08), body_px, Color(0, 0, 0, 0), 0)
	ToonGui.place(question, view, 0.0, 0.28, 1.15, 0.22)
	ToonGui.place(yes, view, 0.22, 0.02, 0.12, 0.12)
	ToonGui.place(no, view, -0.22, 0.02, 0.12, 0.12)
	ToonGui.style_label(yes_label, Color(0.08, 0.08, 0.08), body_px, Color(0, 0, 0, 0), 0)
	ToonGui.style_label(no_label, Color(0.08, 0.08, 0.08), body_px, Color(0, 0, 0, 0), 0)
	ToonGui.place(yes_label, view, 0.22, -0.08, 0.2, 0.06)
	ToonGui.place(no_label, view, -0.22, -0.08, 0.2, 0.06)


func _close_summon() -> void:
	_summon_index = -1
	if _summon_dialog != null and is_instance_valid(_summon_dialog):
		_summon_dialog.queue_free()
	_summon_dialog = null


func _book() -> Control:
	var node: Node = self
	while node != null:
		if node is ShtickerBook:
			return node as Control
		node = node.get_parent()
	return self


func _spoken(index: int) -> String:
	if index < 0 or index >= _NAMES.size():
		return "Cog"
	return _NAMES[index].replace("\n", "")


func _plain_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	return label


## suitListQuery for this street. An empty list is what the page shows with no planner.
func _present(dept: int) -> PackedInt32Array:
	var counts := PackedInt32Array()
	counts.resize(32)
	var scene := get_tree().current_scene
	var suits := scene.get_node_or_null("StreetSuits") if scene != null else null
	if suits == null or not suits.has_method("roster"):
		return counts
	var listed: Variant = suits.call("roster")
	if not (listed is Array):
		return counts
	var rows: Array = listed
	for item in rows:
		if not (item is Dictionary):
			continue
		var cog: Variant = (item as Dictionary).get("cog", {})
		if not (cog is Dictionary):
			continue
		var index := _CODES.find(String((cog as Dictionary).get("code", "")))
		if index < dept * 8 or index >= dept * 8 + 8:
			continue
		counts[index] += 1
	return counts


## buildingListQuery. Suit, takeover, and clear-out count. A field office does not.
func _buildings(dept: int) -> int:
	var scene := get_tree().current_scene
	var suits := scene.get_node_or_null("StreetSuits") if scene != null else null
	if suits == null:
		return 0
	var district := int(suits.get("district_id"))
	var slug := String(suits.get("street_slug"))
	var snap := ToonNet.latest("buildings:%d:%s" % [district, slug])
	var raw: Variant = snap.get("rows", [])
	if not (raw is Array):
		return 0
	var forced := String(_HOLIDAYS.building_track(district))
	var total := 0
	for item in raw as Array:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		if bool(row.get("cogdo", false)):
			continue
		var state := String(row.get("state", ""))
		if state != "suit" and state != "becoming" and state != "clearing":
			continue
		var track := forced if forced != "" else String(row.get("track", "c"))
		if _DEPTS.find(track) == dept:
			total += 1
	return total


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
	# The seen name replaces "???" on the same panel text. text_pos (0, 0.185)
	# is that baseline on the card geom z -0.2396..0.2396. A second line hangs
	# below it, and the head stays under that.
	var font := ToonGui.suit_font()
	var baseline := card.size.y * ((0.239583 - 0.185) / 0.479166)
	var text_top := maxf(baseline - font.get_ascent(px), 0.0)
	var line_h := font.get_height(px)
	_names[index].vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_names[index].clip_contents = true
	_names[index].position = Vector2(0.0, text_top)
	_names[index].size = Vector2(card.size.x, line_h * 2.0 + 2.0)
	_mysteries[index].position = Vector2(0.0, text_top)
	_mysteries[index].size = Vector2(card.size.x, line_h + 2.0)
	# addQuotaLabel sits at z -0.215 in the same card space.
	var quota_base := card.size.y * ((0.239583 - (-0.215)) / 0.479166)
	_quotas[index].vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_quotas[index].position = Vector2(0.0, maxf(quota_base - font.get_ascent(px), 0.0))
	_quotas[index].size = Vector2(card.size.x, line_h + 2.0)
	# addCogRadarLabel uses the same z and a text scale of 0.05, against 0.045.
	var radar_px := maxi(int(round(float(px) * 0.05 / 0.045)), 8)
	_style_suit(_radar_labels[index], radar_px)
	var radar_h := font.get_height(radar_px)
	_radar_labels[index].vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_radar_labels[index].position = Vector2(0.0, maxf(quota_base - font.get_ascent(radar_px), 0.0))
	_radar_labels[index].size = Vector2(card.size.x, radar_h + 2.0)
	# addSummonButton sits at (0.1, -0.13) on the unscaled panel, then the panel scale of 0.6.
	var summon_size := _span(0.045, 0.045)
	var summon_center := _point(ax + 0.06, az - 0.078)
	_summon_buttons[index].size = summon_size
	_summon_buttons[index].position = summon_center - card.position - summon_size * 0.5
	var hint_px := maxi(int(_span(0.04, 0.04).y), 8)
	_style_suit(_summon_hints[index], hint_px)
	_summon_hints[index].size = _span(0.18, 0.045)
	var hint_center := _point(ax + 0.06 - 0.09, az - 0.078)
	_summon_hints[index].position = hint_center - card.position - _summon_hints[index].size * 0.5
	var fitted := _SHADOW_PLACE[index * 3] * 0.6
	var ox := _SHADOW_PLACE[index * 3 + 1] * 0.6
	var oz := _SHADOW_PLACE[index * 3 + 2] * 0.6
	var shadow_size := _span(_SHADOW_SIZE[index * 2] * fitted, _SHADOW_SIZE[index * 2 + 1] * fitted)
	_shadows[index].size = shadow_size
	_shadows[index].position = _point(ax + ox, az + oz) - card.position - shadow_size * 0.5
	# The portrait is the centered head, so its middle sits on this cog's shadow.
	# attachSuitHead still sets the size: (0.2 + column/100), then the panel scale of 0.6.
	var head_world := (0.2 + float(col) / 100.0) * 0.6
	var head_px := _span(head_world, head_world)
	var shadow_center := _shadows[index].position + shadow_size * 0.5
	_heads[index].size = head_px
	_heads[index].position = shadow_center - head_px * 0.5


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
	_quotas[index].visible = seen and not _radar_on[row]
	var held := seen and (_REWARDS.has_summon(row, col, "single") or _REWARDS.has_summon(row, col, "building") or _REWARDS.has_summon(row, col, "invasion"))
	_summon_buttons[index].visible = held
	if not held:
		_summon_hints[index].visible = false
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
