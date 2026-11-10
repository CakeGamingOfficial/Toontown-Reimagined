class_name DisguisePage
extends Control

## DisguisePage. The cog suit, one department at a time. Sellbot opens first.
## A part you do not have yet is the dashed hole. The dial is the promotion
## meter for the suit you are wearing in that department.

const _DIR := "res://assets/gui/shticker/disguise/"
const _SAVE := "user://cog_disguise.json"
const _REWARDS := preload("res://scenes/cog_hq/boss_rewards.gd")
const _SCALE := 0.47
const _ORIGIN_X := 0.02
const _PART_NAMES: PackedStringArray = [
	"lUpleg", "lLowleg", "lShoe", "rUpleg", "rLowleg", "rShoe",
	"lShoulder", "rShoulder", "chest", "waist", "hip",
	"lUparm", "lLowarm", "lHand", "rUparm", "rLowarm", "rHand",
]
# suitDepts order: Bossbot, Lawbot, Cashbot, Sellbot.
const _DEPTS: PackedStringArray = ["Bossbot", "Lawbot", "Cashbot", "Sellbot"]
const _COGS: PackedStringArray = [
	"Flunky", "Pencil Pusher", "Yesman", "Micromanager", "Downsizer", "Head Hunter", "Corporate Raider", "The Big Cheese",
	"Bottom Feeder", "Bloodsucker", "Double Talker", "Ambulance Chaser", "Back Stabber", "Spin Doctor", "Legal Eagle", "Big Wig",
	"Short Change", "Penny Pincher", "Tightwad", "Bean Counter", "Number Cruncher", "Money Bags", "Loan Shark", "Robber Baron",
	"Cold Caller", "Telemarketer", "Name Dropper", "Glad Hander", "Mover & Shaker", "Two-Face", "The Mingler", "Mr. Hollywood",
]
const _COLORS: Array[Color] = [
	Color(0.647, 0.608, 0.596),
	Color(0.588, 0.635, 0.671),
	Color(0.596, 0.714, 0.659),
	Color(0.761, 0.678, 0.69),
]
const _NEED: PackedInt32Array = [17, 14, 12, 10]
const _MASKS: PackedInt32Array = [131071, 130175, 56447, 56411]
# MeritsPerLevel first tier for each department's lowest suit.
const _MERIT: PackedInt32Array = [100, 60, 40, 20]
const _METER := Color(0.87, 0.87, 0.827)
const _METER_HOT := Color(0.7, 0.3, 0.3)
const _PROGRESS: PackedStringArray = [
	"text_stock_option_progress",
	"text_jury_notice_progress",
	"text_cashbuck_progress",
	"text_merit_progress",
]

var _dept := 3
var _parts: Array[int] = [0, 0, 0, 0]
var _merits: Array[int] = [0, 0, 0, 0]
var _types: Array[int] = [0, 0, 0, 0]
var _levels: Array[int] = [0, 0, 0, 0]
var _base: ColorRect
var _pages: Array[TextureRect] = []
var _tabs: Array[TextureButton] = []
var _tab_names: Array[Label] = []
var _pieces: Dictionary = {}
var _holes: Dictionary = {}
var _face: TextureRect
var _progress: Array[TextureRect] = []
var _promotion: TextureRect
var _meter: TextureRect
var _meter_hot: TextureRect
var _meter_cover: TextureRect
var _dept_label: Label
var _cog_name: Label
var _cog_level: Label
var _part_ratio: Label
var _merit_ratio: Label
var _page_size := Vector2.ZERO


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false
	name = "CogDisguise"
	_load_save()
	_build()
	_REWARDS.attach(self)


func layout(page_size: Vector2) -> void:
	_page_size = page_size
	for child in get_children():
		if not child.has_meta("spot"):
			continue
		var spot: Variant = child.get_meta("spot")
		if spot is Dictionary:
			_place(child, spot)
	_style_words(page_size)
	_show_dept()
	_REWARDS.place(self, page_size)


func refresh() -> void:
	_load_save()
	_show_dept()


func _build() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_DIR + "layout.json"))
	if typeof(parsed) != TYPE_ARRAY:
		return
	var locator := Vector2.ZERO
	for row in parsed:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if String(row.get("name", "")) == "locator1":
			var at: Array = row.get("pos", [])
			if at.size() >= 3:
				locator = Vector2(float(at[0]), float(at[2]))
	for row in parsed:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		_add_card(row, locator)


func _add_card(row: Dictionary, locator: Vector2) -> void:
	var card_name := String(row.get("name", ""))
	var parent_name := String(row.get("parent", ""))
	if card_name in ["cog_disguises_english.egg", "", "locator1", "robot", "robot_hole", "group"]:
		return
	if parent_name.begins_with("cog_disguises"):
		return
	var low := _point(row, "low")
	var high := _point(row, "high")
	if parent_name == "locator1":
		low.x += locator.x
		low.z += locator.y
		high.x += locator.x
		high.z += locator.y
	var spot := {"low": low, "high": high}
	if card_name == "base":
		_base = ColorRect.new()
		_base.mouse_filter = MOUSE_FILTER_IGNORE
		_base.z_index = 0
		_base.set_meta("spot", spot)
		add_child(_base)
		return
	var image := _image(String(row.get("file", "")))
	image.set_meta("spot", spot)
	if card_name.begins_with("page"):
		image.z_index = 1
		var index := int(card_name.substr(4)) - 1
		if index >= 0 and index < 4:
			_pages.resize(4)
			_pages[index] = image
		add_child(image)
	elif card_name.begins_with("tab") and card_name.length() == 4:
		var index := int(card_name.substr(3)) - 1
		var button := TextureButton.new()
		button.texture_normal = image.texture
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_SCALE
		button.focus_mode = Control.FOCUS_NONE
		button.z_index = 4
		button.mouse_filter = MOUSE_FILTER_STOP
		button.set_meta("spot", spot)
		button.pressed.connect(_on_tab.bind(index))
		add_child(button)
		var caption := Label.new()
		caption.text = _DEPTS[index] if index >= 0 and index < _DEPTS.size() else ""
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.mouse_filter = MOUSE_FILTER_IGNORE
		button.add_child(caption)
		if index >= 0 and index < 4:
			_tabs.resize(4)
			_tab_names.resize(4)
			_tabs[index] = button
			_tab_names[index] = caption
		image.queue_free()
	elif card_name == "pipe_frame":
		image.z_index = 5
		add_child(image)
	elif card_name == "tube":
		image.z_index = 6
		add_child(image)
	elif card_name == "text_cog_disguises":
		image.z_index = 7
		add_child(image)
	elif card_name == "text_ready4promotion":
		image.z_index = 7
		image.visible = false
		_promotion = image
		add_child(image)
	elif card_name in _PROGRESS:
		image.z_index = 7
		image.visible = false
		_progress.resize(4)
		_progress[_PROGRESS.find(card_name)] = image
		add_child(image)
	elif card_name == "face" and parent_name == "robot":
		image.z_index = 8
		_face = image
		add_child(image)
	elif parent_name == "robot":
		image.z_index = 10
		image.visible = false
		_pieces[card_name] = image
		add_child(image)
	elif parent_name == "robot_hole":
		if card_name == "face":
			image.queue_free()
			return
		image.z_index = 9
		_holes[card_name] = image
		add_child(image)
	elif card_name == "meter_face_whole":
		image.z_index = 11
		image.modulate = _METER
		_meter = image
		add_child(image)
	elif card_name == "meter_face_half":
		image.z_index = 12
		image.visible = false
		image.modulate = _METER_HOT
		_meter_hot = image
		add_child(image)
		var cover := _image(String(row.get("file", "")))
		cover.set_meta("spot", spot)
		cover.z_index = 13
		cover.visible = false
		cover.modulate = _METER
		_meter_cover = cover
		add_child(cover)
	else:
		image.queue_free()


func _show_dept() -> void:
	var dept := clampi(_dept, 0, 3)
	if _base != null:
		_base.color = _COLORS[dept]
	for index in _pages.size():
		var page := _pages[index]
		if page == null:
			continue
		page.visible = index == dept
		page.modulate = _COLORS[index]
	for index in _tabs.size():
		var tab := _tabs[index]
		if tab == null:
			continue
		tab.modulate = _COLORS[index]
		tab.z_index = 4 if index == dept else 3
		var caption := _tab_names[index]
		if caption != null:
			caption.add_theme_color_override("font_color", Color(1, 0, 0) if index == dept else Color(0, 0, 0))
	for index in _progress.size():
		var title := _progress[index]
		if title != null:
			title.visible = index == dept
	_fill_suit(dept)
	_fill_meter(dept)
	_fill_words(dept)


func _fill_suit(dept: int) -> void:
	var owned := _parts[dept]
	var mask := _MASKS[dept]
	var bit := 1
	var carry := false
	for part_name in _PART_NAMES:
		var in_suit := (mask & bit) != 0
		var have := (owned & bit) != 0 and in_suit
		var show_piece := have or (not in_suit and carry)
		var piece: TextureRect = _pieces.get(part_name)
		var hole: TextureRect = _holes.get(part_name)
		if piece != null:
			piece.visible = show_piece
		if hole != null:
			hole.visible = not show_piece
		if in_suit:
			carry = have
		elif not carry:
			carry = false
		bit = bit << 1


func _fill_meter(dept: int) -> void:
	var total := _need(dept, _types[dept], _levels[dept])
	var have := _merits[dept]
	var progress := 0.0 if total <= 0 else clampf(float(have) / float(total), 0.0, 1.0)
	var ready := total > 0 and have >= total
	if _promotion != null:
		_promotion.visible = ready
	for index in _progress.size():
		var title := _progress[index]
		if title != null and index == dept:
			title.visible = not ready
	if _merit_ratio != null:
		_merit_ratio.text = "Full" if ready else "%d/%d" % [have, total]
	if _meter == null:
		return
	if progress <= 0.0 or progress >= 1.0:
		if _meter_hot != null:
			_meter_hot.visible = false
		if _meter_cover != null:
			_meter_cover.visible = false
		_meter.modulate = _METER_HOT if progress >= 1.0 else _METER
		return
	_meter.modulate = _METER
	if _meter_hot != null:
		_meter_hot.visible = true
	if _meter_cover == null:
		return
	_meter_cover.visible = true
	var turn := progress
	if turn < 0.5:
		_meter_cover.modulate = _METER
	else:
		_meter_cover.modulate = _METER_HOT
		turn -= 0.5
	_meter_cover.rotation = -deg_to_rad(180.0 * (turn / 0.5))


func _fill_words(dept: int) -> void:
	if _dept_label != null:
		_dept_label.text = _DEPTS[dept]
	var cog := dept * 8 + clampi(_types[dept], 0, 7)
	if _cog_name != null and cog < _COGS.size():
		_cog_name.text = _COGS[cog]
	if _cog_level != null:
		_cog_level.text = "Level %d" % (_levels[dept] + 1)
	if _part_ratio != null:
		_part_ratio.text = "%d/%d" % [_bit_count(_parts[dept]), _NEED[dept]]


func _style_words(page_size: Vector2) -> void:
	_dept_label = _word(_dept_label, Vector2(-0.1, 0.8), 0.17, page_size)
	_cog_name = _word(_cog_name, Vector2(-0.948, -1.15), 0.093, page_size)
	_cog_level = _word(_cog_level, Vector2(-0.91, -1.02), 0.09, page_size)
	_part_ratio = _word(_part_ratio, Vector2(-0.91, -0.82), 0.08, page_size)
	_merit_ratio = _word(_merit_ratio, Vector2(0.45, -0.36), 0.08, page_size)
	for index in _tabs.size():
		var tab := _tabs[index]
		var caption := _tab_names[index]
		if tab == null or caption == null:
			continue
		caption.position = (tab.size - Vector2(tab.size.y, tab.size.x)) * 0.5
		caption.size = Vector2(tab.size.y, tab.size.x)
		caption.pivot_offset = caption.size * 0.5
		caption.rotation = -PI * 0.5
		var px := maxi(int(_book_span(0.1, page_size).y), 10)
		caption.add_theme_font_override("font", ToonGui.suit_font())
		caption.add_theme_font_size_override("font_size", px)


func _word(label: Label, at: Vector2, scale: float, page_size: Vector2) -> Label:
	if label == null:
		label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = MOUSE_FILTER_IGNORE
		label.z_index = 14
		add_child(label)
	var height := _book_span(scale, page_size).y
	var center := _book_point(_ORIGIN_X + at.x * _SCALE, at.y * _SCALE, page_size)
	label.position = center - Vector2(page_size.x * 0.22, height * 0.5)
	label.size = Vector2(page_size.x * 0.44, height)
	var px := maxi(int(height * 0.8), 10)
	ToonGui.style_label(label, Color(0.05, 0.05, 0.05), px, Color(0, 0, 0, 0), 0)
	label.add_theme_font_override("font", ToonGui.suit_font())
	return label


func _on_tab(index: int) -> void:
	_dept = index
	_show_dept()


func _place(node: Control, spot: Dictionary) -> void:
	var low: Vector3 = spot["low"]
	var high: Vector3 = spot["high"]
	var x0 := _ORIGIN_X + low.x * _SCALE
	var x1 := _ORIGIN_X + high.x * _SCALE
	var z0 := low.z * _SCALE
	var z1 := high.z * _SCALE
	var top := _book_point(minf(x0, x1), maxf(z0, z1), _page_size)
	var bottom := _book_point(maxf(x0, x1), minf(z0, z1), _page_size)
	node.position = top
	node.size = bottom - top
	if node == _meter_cover or node == _meter_hot:
		node.pivot_offset = node.size * 0.5


func _image(file_name: String) -> TextureRect:
	var image := TextureRect.new()
	image.texture = load(_DIR + file_name)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = MOUSE_FILTER_IGNORE
	return image


func _point(row: Dictionary, key: String) -> Vector3:
	var values: Array = row.get(key, [])
	if values.size() < 3:
		return Vector3.ZERO
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _bit_count(value: int) -> int:
	var sum := 0
	var bits := value
	while bits != 0:
		sum += bits & 1
		bits = bits >> 1
	return sum


static func grant_notices(amount: int) -> int:
	# PromotionManagerAI pays jury notices only for a finished Lawbot suit.
	# This book stores the first promotion tier, so the meter stops at 60.
	if amount <= 0:
		return 0
	var record := {}
	if FileAccess.file_exists(_SAVE):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_SAVE))
		if parsed is Dictionary:
			record = parsed
	var parts: Array = record.get("parts", [0, 0, 0, 0])
	var merits: Array = record.get("merits", [0, 0, 0, 0])
	while parts.size() < 4:
		parts.append(0)
	while merits.size() < 4:
		merits.append(0)
	if (int(parts[1]) & _MASKS[1]) != _MASKS[1]:
		return 0
	var have := int(merits[1])
	var filled := mini(have + amount, promotion_cap(1))
	var gained := filled - have
	if gained <= 0:
		return 0
	merits[1] = filled
	record["parts"] = parts
	record["merits"] = merits
	if not record.has("types"):
		record["types"] = [0, 0, 0, 0]
	if not record.has("levels"):
		record["levels"] = [0, 0, 0, 0]
	var file := FileAccess.open(_SAVE, FileAccess.WRITE)
	if file == null:
		return 0
	file.store_string(JSON.stringify(record))
	file.close()
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var page := tree.root.find_child("CogDisguise", true, false)
		if page != null and page.has_method("reload_notices"):
			page.call("reload_notices")
	return gained


func reload_notices() -> void:
	_load_save()
	_show_dept()


func _load_save() -> void:
	_parts = [0, 0, 0, 0]
	_merits = [0, 0, 0, 0]
	_types = [0, 0, 0, 0]
	_levels = [0, 0, 0, 0]
	if not FileAccess.file_exists(_SAVE):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_SAVE))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var record: Dictionary = parsed
	_read_row(_parts, record.get("parts", []))
	_read_row(_merits, record.get("merits", []))
	_read_row(_types, record.get("types", []))
	_read_row(_levels, record.get("levels", []))


func _read_row(into: Array[int], raw: Variant) -> void:
	if typeof(raw) != TYPE_ARRAY:
		return
	var values: Array = raw
	for index in mini(into.size(), values.size()):
		into[index] = int(values[index])


func _book_point(book_x: float, book_z: float, page_size: Vector2) -> Vector2:
	var fx := (book_x + 1.0) / 2.0
	var fy := (0.75 - book_z) / 1.5
	return Vector2((fx - 0.0635) / 0.873 * page_size.x, (fy - 0.0118) / 0.873 * page_size.y)


func _book_span(scale: float, page_size: Vector2) -> Vector2:
	return _book_point(0.0, 0.0, page_size) - _book_point(0.0, scale * _SCALE, page_size)


## CogSuitManagerAI.recoverPart for a full Sellbot suit, then merits.
## Merits count only once every required part is in. The page's first
## Sellbot promotion is 20 merits, so the dial stops there.
const _SELLBOT := 3
const _PART_GROUPS: PackedInt32Array = [7, 56, 1984, 14336, 114688]


static func grant_factory(levels: Array) -> String:
	var record := _read_disk()
	var parts := _four(record.get("parts", []))
	var merits := _four(record.get("merits", []))
	var lines: PackedStringArray = []
	var bit := _next_part(parts[_SELLBOT])
	if bit != 0:
		parts[_SELLBOT] = parts[_SELLBOT] | bit
		lines.append("You recovered a Sellbot %s." % _part_label(bit))
	if _suit_complete(parts[_SELLBOT]):
		var gained := 0
		for level in levels:
			gained += _py_round(float(level) * 0.5) * 4
		if gained > 0:
			var before := int(merits[_SELLBOT])
			merits[_SELLBOT] = mini(before + gained, promotion_cap(_SELLBOT))
			var added := int(merits[_SELLBOT]) - before
			if added > 0:
				lines.append("You got %d Sellbot merits." % added)
	record["parts"] = parts
	record["merits"] = merits
	if not record.has("types"):
		record["types"] = [0, 0, 0, 0]
	if not record.has("levels"):
		record["levels"] = [0, 0, 0, 0]
	_write_disk(record)
	return "\n".join(lines)


## PromotionManagerAI.recoverMerits for a Cashbot mint. No suit part. Cogbucks
## are paid only when the Cashbot suit is already complete. DistributedMintBattleAI
## adds MintCogBuckRewards on every battle the toons win.
const _CASHBOT := 2


static func grant_mint(levels: Array, mint_id: int) -> String:
	var mask := int(_MASKS[_CASHBOT])
	var record := _read_disk()
	var parts := _four(record.get("parts", []))
	if (int(parts[_CASHBOT]) & mask) != mask:
		return ""
	var merits := _four(record.get("merits", []))
	var mult := 2.0
	var bonus := 8
	if mint_id == 12600:
		mult = 2.5
		bonus = 14
	elif mint_id == 12700:
		mult = 3.0
		bonus = 20
	var gained := 0
	for level in levels:
		var base := _py_round(float(level) * 0.5)
		gained += _py_round(float(base) * mult)
	gained += bonus
	if gained <= 0:
		return ""
	var before := int(merits[_CASHBOT])
	merits[_CASHBOT] = mini(before + gained, promotion_cap(_CASHBOT))
	var added := int(merits[_CASHBOT]) - before
	if added <= 0:
		return ""
	record["merits"] = merits
	if not record.has("parts"):
		record["parts"] = parts
	if not record.has("types"):
		record["types"] = [0, 0, 0, 0]
	if not record.has("levels"):
		record["levels"] = [0, 0, 0, 0]
	_write_disk(record)
	return "You got %d Cogbucks." % added


## PromotionManagerAI.recoverMerits for a Bossbot country club. Stock options
## are paid only when the Bossbot suit is already complete. The first promotion
## on this page stops at 100. The course bonus is the Club President.
const _BOSSBOT := 0


static func grant_part(dept: int, bit: int) -> void:
	if dept < 0 or dept > 3 or bit == 0:
		return
	var record := _read_disk()
	var parts := _four(record.get("parts", []))
	parts[dept] = int(parts[dept]) | bit
	record["parts"] = parts
	if not record.has("merits"):
		record["merits"] = _four(record.get("merits", []))
	if not record.has("types"):
		record["types"] = [0, 0, 0, 0]
	if not record.has("levels"):
		record["levels"] = [0, 0, 0, 0]
	_write_disk(record)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var page := tree.root.find_child("CogDisguise", true, false)
		if page != null and page.has_method("reload_notices"):
			page.call("reload_notices")


static func grant_course(levels: Array, course_id: int, president: bool) -> String:
	var mask := int(_MASKS[_BOSSBOT])
	var record := _read_disk()
	var parts := _four(record.get("parts", []))
	if (int(parts[_BOSSBOT]) & mask) != mask:
		return ""
	var merits := _four(record.get("merits", []))
	var mult := 2.0
	var bonus := 8
	if course_id == 10600:
		mult = 2.5
		bonus = 14
	elif course_id == 10700:
		mult = 3.0
		bonus = 20
	var gained := 0
	for level in levels:
		var base := _py_round(float(level) * 0.5)
		gained += _py_round(float(base) * mult)
	if president:
		gained += bonus
	if gained <= 0:
		return ""
	var before := int(merits[_BOSSBOT])
	merits[_BOSSBOT] = mini(before + gained, promotion_cap(_BOSSBOT))
	var added := int(merits[_BOSSBOT]) - before
	if added <= 0:
		return ""
	record["merits"] = merits
	if not record.has("parts"):
		record["parts"] = parts
	if not record.has("types"):
		record["types"] = [0, 0, 0, 0]
	if not record.has("levels"):
		record["levels"] = [0, 0, 0, 0]
	_write_disk(record)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var page := tree.root.find_child("CogDisguise", true, false)
		if page != null and page.has_method("reload_notices"):
			page.call("reload_notices")
	return "You got %d Stock Options." % added


static func _next_part(have: int) -> int:
	var mask := int(_MASKS[_SELLBOT])
	for group in _PART_GROUPS:
		var missing := (mask & int(group)) & ~have
		if missing == 0:
			continue
		return missing & -missing
	return 0


## CogDisguiseGlobals.isSuitComplete. Every part bit in that department's
## mask has to be set. The Chief Justice lobby door checks the Lawbot suit.
static func suit_complete(dept: int) -> bool:
	if dept < 0 or dept >= _MASKS.size():
		return false
	var parts := _four(_read_disk().get("parts", []))
	var have := int(parts[dept])
	var mask := int(_MASKS[dept])
	return (have & mask) == mask


static func _suit_complete(have: int) -> bool:
	var mask := int(_MASKS[_SELLBOT])
	return (have & mask) == mask


static func _part_label(bit: int) -> String:
	var names: PackedStringArray = [
		"upper left leg", "lower left leg", "left foot",
		"upper right leg", "lower right leg", "right foot",
		"left shoulder", "right shoulder", "chest", "health meter", "pelvis",
		"upper left arm", "lower left arm", "left hand",
		"upper right arm", "lower right arm", "right hand",
	]
	var flag := 1
	for label in names:
		if bit == flag:
			return label
		flag = flag << 1
	return "suit part"


static func _py_round(value: float) -> int:
	var base := int(value)
	var frac := value - float(base)
	if frac < 0.0:
		frac = -frac
	if frac > 0.5:
		return base + (1 if value > 0.0 else -1)
	if frac < 0.5:
		return base
	if base % 2 == 0:
		return base
	return base + (1 if value > 0.0 else -1)


static func _four(raw: Variant) -> Array:
	var out: Array = [0, 0, 0, 0]
	if raw is Array:
		var values: Array = raw
		for index in mini(4, values.size()):
			out[index] = int(values[index])
	return out


static func _read_disk() -> Dictionary:
	if not FileAccess.file_exists(_SAVE):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_SAVE))
	if parsed is Dictionary:
		return parsed
	return {}


static func _write_disk(record: Dictionary) -> void:
	var file := FileAccess.open(_SAVE, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(record))


const _MERIT_FILE := "res://scenes/shticker/cog_merits.json"
const _HP_LEVELS: PackedInt32Array = [14, 19, 29, 39, 49]
static var _merit_rows: Array = []


## CogDisguiseGlobals.getTotalMerits. The row is the suit you are wearing.
## The column is how far that suit has climbed above its lowest level.
static func promotion_cap(dept: int) -> int:
	if dept < 0 or dept > 3:
		return 0
	var record := _read_disk()
	var types := _four(record.get("types", []))
	var levels := _four(record.get("levels", []))
	return _need(dept, int(types[dept]), int(levels[dept]))


static func ready_for_promotion(dept: int) -> bool:
	if dept < 0 or dept > 3:
		return false
	var record := _read_disk()
	var merits := _four(record.get("merits", []))
	return int(merits[dept]) >= promotion_cap(dept) and promotion_cap(dept) > 0


static func promotions(dept: int) -> int:
	if dept < 0 or dept > 3:
		return 0
	var record := _read_disk()
	var types := _four(record.get("types", []))
	var levels := _four(record.get("levels", []))
	var cog_type := clampi(int(types[dept]), 0, 7)
	return 5 * cog_type + int(levels[dept]) - cog_type


## DistributedToonAI.b_promote. Merits clear, then the suit climbs. The last
## cog in the department grants a laff point at levels 14, 19, 29, 39, and 49.
static func promote(dept: int) -> String:
	if dept < 0 or dept > 3:
		return ""
	var record := _read_disk()
	var types := _four(record.get("types", []))
	var levels := _four(record.get("levels", []))
	var merits := _four(record.get("merits", []))
	var started_type := int(types[dept])
	var started_level := int(levels[dept])
	if started_level < 49:
		merits[dept] = 0
	var last := started_type >= 7
	var base := started_type
	var new_level := started_level + 1
	var max_level := 49 if last else base + 4
	var laff := false
	if new_level > max_level:
		if not last:
			types[dept] = started_type + 1
			levels[dept] = int(types[dept])
	else:
		levels[dept] = new_level
		if last:
			for mark in _HP_LEVELS:
				if new_level == mark:
					laff = true
	record["types"] = types
	record["levels"] = levels
	record["merits"] = merits
	_write_disk(record)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var page := tree.root.find_child("CogDisguise", true, false)
		if page != null and page.has_method("reload_notices"):
			page.call("reload_notices")
	if int(types[dept]) == started_type and int(levels[dept]) == started_level:
		return "You can't upgrade your Cog suit anymore, but you can keep fighting this boss."
	if laff:
		var loadout := ToonLoadout.for_selected()
		if loadout != null and loadout.max_hp < 137:
			var maximum := mini(loadout.max_hp + 1, 137)
			loadout.set_hp(maximum, maximum)
			loadout.save()
	var cog := dept * 8 + clampi(int(types[dept]), 0, 7)
	return "You have been promoted to a Level %d %s." % [int(levels[dept]) + 1, _COGS[cog]]


static func _need(dept: int, cog_type: int, cog_level: int) -> int:
	_load_merits()
	var index := dept * 8 + clampi(cog_type, 0, 7)
	if index < 0 or index >= _merit_rows.size() or not (_merit_rows[index] is Array):
		return int(_MERIT[clampi(dept, 0, 3)])
	var row: Array = _merit_rows[index]
	if row.is_empty():
		return int(_MERIT[clampi(dept, 0, 3)])
	var slot := clampi(cog_level - (index % 8), 0, row.size() - 1)
	return int(row[slot])


static func _load_merits() -> void:
	if not _merit_rows.is_empty():
		return
	if not FileAccess.file_exists(_MERIT_FILE):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_MERIT_FILE))
	if parsed is Dictionary:
		var rows: Variant = (parsed as Dictionary).get("merits", [])
		if rows is Array:
			_merit_rows = rows
