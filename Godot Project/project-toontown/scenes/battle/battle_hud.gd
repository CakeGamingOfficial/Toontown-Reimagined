class_name BattleHud
extends Control

## TownBattle while a street fight is waiting for gag choices. The green cards
## are ToonBtl_Status_BG, the clock is the battle timer, and the arrows are
## TownBattleChooseAvatarPanel. After this toon has chosen, Waiting4Others
## stays up until the other toons choose too.

signal chose(slot: int)
signal backed

const _STATUS := preload("res://assets/gui/battle/ToonBtl_Status_BG.png")
const _PASS := preload("res://assets/gui/battle/tt_t_gui_bat_pass.png")
const _WAIT := preload("res://assets/gui/battle/Waiting4Others.png")
const _PICK := preload("res://assets/gui/battle/BtlPick_TAB.png")
const _TAB := preload("res://assets/gui/battle/PckMn_Select_Tab.png")
const _ARROW_UP := preload("res://assets/gui/battle/PckMn_Arrow_Up.png")
const _ARROW_DOWN := preload("res://assets/gui/battle/PckMn_Arrow_Dn.png")
const _ARROW_OVER := preload("res://assets/gui/battle/PckMn_Arrow_Rlvr.png")
const _BACK_UP := preload("res://assets/gui/battle/PckMn_BackBtn.png")
const _BACK_DOWN := preload("res://assets/gui/battle/PckMn_BackBtn_Dn.png")
const _BACK_OVER := preload("res://assets/gui/battle/PckMn_BackBtn_Rlvr.png")
const _CLOCK := preload("res://assets/gui/purchase/alarm_clock.png")

const _EVEN: Array[float] = [0.75, 0.25, -0.25, -0.75]
const _ODD: Array[float] = [0.5, 0.0, -0.5]
const _PANEL_Z := -0.9
const _PANEL_SCALE := 0.8
const _STATUS_SIZE := Vector2(0.4292, 0.2708)
const _INK := Color(0.05, 0.14, 0.4)

var _host: Node
var _cards: Array[Control] = []
var _health: Array[Label] = []
var _marks: Array[Label] = []
var _which: Array[Label] = []
var _gags: Array[TextureRect] = []
var _passes: Array[TextureRect] = []
var _meters: Array[LaffMeter] = []
var _meter_kind: Array[String] = []
var _clock: TextureRect
var _clock_num: Label
var _wait: TextureRect
var _wait_text: Label
var _pick: TextureRect
var _pick_status: TextureRect
var _tab: TextureRect
var _tab_text: Label
var _arrows: Array[TextureButton] = []
var _back: TextureButton
var _back_text: Label
var _toons: Array = []
var _state := ""
var _seconds := -1
var _choosing := false
var _choose_toon := false
var _choose_count := 0
var _invalid: PackedInt32Array = PackedInt32Array()
var _skip_slot := -1


func bind_host(host: Node) -> void:
	_host = host


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index in 4:
		_build_card(index)
	_clock = _picture(_CLOCK)
	_clock_num = _label(HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_wait = _picture(_WAIT)
	_wait_text = _label(HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_pick = _picture(_PICK)
	_pick.modulate = Color(1, 0.2, 0.2)
	_pick_status = _picture(_STATUS)
	_pick_status.modulate = Color(0.5, 0.9, 0.5, 1)
	_tab = _picture(_TAB)
	_tab.modulate = Color(1, 1, 0)
	_tab_text = _label(HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_tab_text.add_theme_color_override("font_color", Color(0, 0, 0))
	for slot in 4:
		var arrow := TextureButton.new()
		arrow.texture_normal = _ARROW_UP
		arrow.texture_pressed = _ARROW_DOWN
		arrow.texture_hover = _ARROW_OVER
		arrow.ignore_texture_size = true
		arrow.stretch_mode = TextureButton.STRETCH_SCALE
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.pressed.connect(_on_arrow.bind(slot))
		add_child(arrow)
		_arrows.append(arrow)
	_back = TextureButton.new()
	_back.texture_normal = _BACK_UP
	_back.texture_pressed = _BACK_DOWN
	_back.texture_hover = _BACK_OVER
	_back.ignore_texture_size = true
	_back.stretch_mode = TextureButton.STRETCH_SCALE
	_back.focus_mode = Control.FOCUS_NONE
	_back.pressed.connect(func() -> void: backed.emit())
	add_child(_back)
	_back_text = _label(HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_back_text.text = "BACK"
	_back_text.add_theme_color_override("font_color", Color(0, 0, 0.8))
	_back_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := get_viewport()
	if view != null and not view.size_changed.is_connected(_layout):
		view.size_changed.connect(_layout)
	hide_all()


## TownBattle.__enterPanels plus the clock. Choices already made stay on the cards.
func show_battle(toons: Array, state: String, seconds: int) -> void:
	_toons = toons
	_state = state
	_seconds = seconds
	visible = true
	_layout()


func hide_all() -> void:
	_toons = []
	_state = ""
	_seconds = -1
	_choosing = false
	visible = false


## TownBattleChooseAvatarPanel. Slot 0 is the rightmost body, matching the cards.
func show_choose(toon_targets: bool, count: int, invalid: PackedInt32Array, skip_slot: int) -> void:
	_choosing = true
	_choose_toon = toon_targets
	_choose_count = clampi(count, 0, 4)
	_invalid = invalid
	_skip_slot = skip_slot
	_tab_text.text = "WHICH TOON?" if toon_targets else "WHICH COG?"
	_layout()


func hide_choose() -> void:
	_choosing = false
	_layout()


func _build_card(index: int) -> void:
	var card := TextureRect.new()
	card.texture = _STATUS
	card.modulate = Color(0.5, 0.9, 0.5, 0.7)
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	_cards.append(card)
	var meter := LaffMeter.new()
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(meter)
	_meters.append(meter)
	_meter_kind.append("")
	var health := _label(HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER)
	health.reparent(card)
	_health.append(health)
	var mark := _label(HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	mark.text = "?"
	mark.reparent(card)
	_marks.append(mark)
	var gag := TextureRect.new()
	gag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(gag)
	_gags.append(gag)
	var passed := TextureRect.new()
	passed.texture = _PASS
	passed.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	passed.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	passed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(passed)
	_passes.append(passed)
	var which := _label(HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	which.reparent(card)
	_which.append(which)


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.y < 2.0:
		return
	var showing := _state == "input"
	var count := mini(_toons.size(), 4)
	var spots := _ODD if count % 2 == 1 else _EVEN
	var start := 0 if count >= 3 else 1
	for index in 4:
		var card := _cards[index]
		var on := showing and index < count
		card.visible = on
		if not on:
			continue
		var spot := spots[start + index]
		ToonGui.place(card, view, spot, _PANEL_Z, _STATUS_SIZE.x * _PANEL_SCALE, _STATUS_SIZE.y * _PANEL_SCALE)
		_fill_card(index, _toons[index], view)
	_place_clock(view)
	_place_wait(view, count)
	_place_choose(view)


func _fill_card(index: int, toon: Dictionary, view: Vector2) -> void:
	var card := _cards[index]
	var unit := view.y * 0.5
	var hp := int(toon.get("hp", 0))
	var maximum := maxi(int(toon.get("max_hp", hp)), 1)
	_health[index].text = "%d/%d" % [hp, maximum]
	_place_on(card, _health[index], -0.048, -0.06, 0.16, 0.05, unit)
	ToonGui.style_label(_health[index], _INK, _px(unit, 0.044), Color(0, 0, 0, 0), 0)
	_dress_meter(index, int(toon.get("id", 0)), hp, maximum, unit)
	var track := int(toon.get("track", -1))
	var level := int(toon.get("level", -1))
	var undecided := track < -1 or not toon.has("track")
	_marks[index].visible = undecided or track == -2
	_marks[index].text = "Run" if track == -2 else "?"
	_place_on(card, _marks[index], 0.08, 0.012, 0.14, 0.08, unit)
	ToonGui.style_label(_marks[index], _INK, _px(unit, 0.08), Color(0, 0, 0, 0), 0)
	_passes[index].visible = track == -1
	_place_on(card, _passes[index], 0.08, 0.04, 0.085, 0.085, unit)
	_gags[index].visible = track >= 0
	if track >= 0:
		_gags[index].texture = BattleMenu.icon_for(track, level)
	_place_on(card, _gags[index], 0.08, 0.024, 0.09, 0.09, unit)
	var marks := String(toon.get("which", ""))
	_which[index].visible = marks != ""
	_which[index].text = marks
	_place_on(card, _which[index], 0.08, -0.064, 0.16, 0.05, unit)
	ToonGui.style_label(_which[index], _INK, _px(unit, 0.04), Color(0, 0, 0, 0), 0)


func _dress_meter(index: int, peer: int, hp: int, maximum: int, unit: float) -> void:
	var meter := _meters[index]
	var kind := _species(peer)
	if _meter_kind[index] != kind or meter.get_child_count() == 0:
		_meter_kind[index] = kind
		var style := _style(peer)
		for child in meter.get_children():
			child.free()
		meter.setup(style)
	var pixels := unit * 0.12
	meter.place(Vector2(_cards[index].size.x * 0.5 - 0.048 * unit, _cards[index].size.y * 0.5 - 0.04 * unit), pixels)
	meter.set_hp(hp, maximum, true)


func _place_clock(view: Vector2) -> void:
	var on := _seconds >= 0 and _state == "input"
	_clock.visible = on
	_clock_num.visible = on
	if not on:
		return
	ToonGui.place(_clock, view, 1.182, 0.842, 0.7417 * 0.4, 0.7292 * 0.4)
	_clock_num.position = _clock.position
	_clock_num.size = _clock.size
	_clock_num.text = str(_seconds)
	var urgent := _seconds <= 5
	var px := _px(view.y * 0.5, 0.34 * 0.4 if _seconds < 10 else 0.27 * 0.4)
	ToonGui.style_label(_clock_num, Color(1, 0, 0) if urgent else Color(0.05, 0.14, 0.4), px, Color(0, 0, 0, 0), 0)


func _place_wait(view: Vector2, count: int) -> void:
	var mine := _local_choice()
	var waiting := _state == "input" and not mine.is_empty() and not _everyone_chose() and not _choosing
	_wait.visible = waiting
	_wait_text.visible = waiting
	if not waiting:
		return
	ToonGui.place(_wait, view, 0.0, 0.0, 1.75 * 0.65, 0.5834 * 0.65)
	_wait_text.position = _wait.position
	_wait_text.size = _wait.size
	_wait_text.text = "Waiting for\nother players..." if count > 1 else "Please wait..."
	ToonGui.style_label(_wait_text, _INK, _px(view.y * 0.5, 0.1 * 0.65), Color(0, 0, 0, 0), 0)


func _place_choose(view: Vector2) -> void:
	var on := _choosing and _state == "input"
	_pick.visible = on
	_pick_status.visible = on
	_tab.visible = on
	_tab_text.visible = on
	_back.visible = on
	_back_text.visible = on
	if not on:
		for arrow in _arrows:
			arrow.visible = false
		return
	ToonGui.place(_pick, view, 0.0, 0.0, 1.75, 0.55)
	ToonGui.place(_pick_status, view, 0.611, 0.0, _STATUS_SIZE.x, _STATUS_SIZE.y)
	ToonGui.place(_tab, view, -0.013, 0.013, 0.8874, 0.1542)
	_tab_text.position = _tab.position
	_tab_text.size = _tab.size
	ToonGui.style_label(_tab_text, Color(0, 0, 0), _px(view.y * 0.5, 0.08), Color(0, 0, 0, 0), 0)
	ToonGui.place(_back, view, -0.647, 0.006, 0.3 * 1.05, 0.2166 * 1.05)
	_back_text.position = _back.position
	_back_text.size = _back.size
	ToonGui.style_label(_back_text, Color(0, 0, 0.8), _px(view.y * 0.5, 0.05 * 1.05), Color(0, 0, 0, 0), 0)
	var spots := _arrow_spots(_choose_count)
	var height := 0.2 if not _choose_toon else -0.2
	for slot in 4:
		var arrow := _arrows[slot]
		var show := slot < _choose_count and not _invalid.has(slot) and slot != _skip_slot
		arrow.visible = show
		if not show:
			continue
		ToonGui.place(arrow, view, spots[slot], height, 0.2416, 0.1208)
		arrow.pivot_offset = arrow.size * 0.5
		arrow.scale = Vector2(1, -1) if _choose_toon else Vector2.ONE


func _arrow_spots(count: int) -> Array[float]:
	if count <= 1:
		return [0.0, 0.0, 0.0, 0.0]
	if count == 2:
		return [0.2, -0.2, 0.0, 0.0]
	if count == 3:
		return [0.4, 0.0, -0.4, 0.0]
	return [0.6, 0.2, -0.2, -0.6]


func _local_choice() -> Dictionary:
	for item in _toons:
		if item is Dictionary and int((item as Dictionary).get("id", -1)) == ToonNet.peer_id() and (item as Dictionary).has("track"):
			return item
	return {}


func _everyone_chose() -> bool:
	if _toons.is_empty():
		return false
	for item in _toons:
		if not (item is Dictionary):
			return false
		var toon: Dictionary = item
		if int(toon.get("hp", 0)) <= 0:
			continue
		if not toon.has("track"):
			return false
	return true


func _species(peer: int) -> String:
	var style := _style(peer)
	if style == null:
		return "d"
	return style.species()


func _style(peer: int) -> ToonStyle:
	if _host != null and _host.has_method("battle_style"):
		var found: Variant = _host.call("battle_style", peer)
		if found is ToonStyle:
			return found
	return ToonRoster.selected_style()


func _on_arrow(slot: int) -> void:
	chose.emit(slot)


func _place_on(card: Control, node: Control, x: float, z: float, width: float, height: float, unit: float) -> void:
	var box := Vector2(width, height) * unit
	node.position = card.size * 0.5 + Vector2(x * unit, -z * unit) - box * 0.5
	node.size = box


func _px(unit: float, aspect: float) -> int:
	return maxi(int(round(aspect * unit)), 8)


func _picture(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	add_child(rect)
	return rect


func _label(horizontal: HorizontalAlignment, vertical: VerticalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = horizontal
	label.vertical_alignment = vertical
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", ToonGui.font())
	add_child(label)
	return label
