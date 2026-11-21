class_name BattleHud
extends Control

## TownBattle while a street fight is waiting for gag choices. The green cards
## are ToonBtl_Status_BG, the clock is the battle timer, and the arrows are
## TownBattleChooseAvatarPanel. After this toon has chosen, Waiting4Others
## stays up until the other toons choose too.

signal chose(slot: int)
signal backed

const _STATUS := preload("res://assets/gui/battle/ToonBtl_Status_BG.png")
const _BUTTON := preload("res://assets/gui/rules/InventoryButtonUp.png")
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
## Above the bottom gag bar, so the toon cards do not cover the picker or the fight.
const _PANEL_Z := 0.72
const _PANEL_SCALE := 0.8
const _STATUS_SIZE := Vector2(0.4292, 0.2708)
const _INK := Color(0.05, 0.14, 0.4)

var _host: Node
var _cards: Array[Control] = []
var _health: Array[Label] = []
var _marks: Array[Label] = []
var _which: Array[Label] = []
var _toon_names: Array[Label] = []
var _positions: Array[Label] = []
var _gags: Array[TextureRect] = []
var _plates: Array[TextureRect] = []
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
	if state != "input":
		hide_all()
		return
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
	for card in _cards:
		card.visible = false
	if _clock != null:
		_clock.visible = false
	if _clock_num != null:
		_clock_num.visible = false
	if _wait != null:
		_wait.visible = false
	if _wait_text != null:
		_wait_text.visible = false
	_set_choose_visible(false)


## TownBattleChooseAvatarPanel. Toon-up still uses the arrows. A cog attack
## is chosen by clicking that cog. Slot 0 is the rightmost body.
func show_choose(toon_targets: bool, count: int, invalid: PackedInt32Array, skip_slot: int) -> void:
	_choosing = true
	_choose_toon = toon_targets
	_choose_count = clampi(count, 0, 4)
	_invalid = invalid
	_skip_slot = skip_slot
	_tab_text.text = "WHICH TOON?" if toon_targets else "WHICH COG?"
	_layout()


func choosing_cogs() -> bool:
	return _choosing and _state == "input" and not _choose_toon


func hide_choose() -> void:
	_choosing = false
	if _state != "input":
		_set_choose_visible(false)
		return
	_layout()


func _build_card(index: int) -> void:
	var card := TextureRect.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	_cards.append(card)
	var shell := Panel.new()
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.95, 0.96, 0.98, 0.94)
	frame_style.border_color = Color(0.12, 0.22, 0.4, 1.0)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(4)
	shell.add_theme_stylebox_override("panel", frame_style)
	card.add_child(shell)
	var toon_name := _label(HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER)
	toon_name.reparent(card)
	_toon_names.append(toon_name)
	var position := _label(HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_CENTER)
	position.reparent(card)
	_positions.append(position)
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
	var plate := TextureRect.new()
	plate.texture = _BUTTON
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.z_index = 2
	card.add_child(plate)
	_plates.append(plate)
	var gag := TextureRect.new()
	gag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gag.z_index = 3
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
	# Your card is the lowest. Other toons stack above it, clear of the fight.
	var showing := _state == "input"
	var count := mini(_toons.size(), 4)
	var order: Array[int] = []
	var mine := -1
	for index in count:
		if int((_toons[index] as Dictionary).get("id", -1)) == ToonNet.peer_id():
			mine = index
		else:
			order.append(index)
	if mine >= 0:
		order.append(mine)
	var gap := 6.0
	var card_h := clampf(view.y * 0.09, 72.0, 96.0)
	var card_w := card_h * 2.55
	var shown := order.size()
	var stack_h := float(shown) * card_h + float(maxi(shown - 1, 0)) * gap
	# The gag bar is only the track names, so the cards sit in the bottom-left corner.
	var bottom := view.y - 10.0
	if shown > 0 and bottom - stack_h < 8.0:
		card_h = maxf((bottom - 8.0 - float(maxi(shown - 1, 0)) * gap) / float(shown), 60.0)
		card_w = card_h * 2.55
		stack_h = float(shown) * card_h + float(maxi(shown - 1, 0)) * gap
	for index in 4:
		var card := _cards[index]
		var slot := order.find(index)
		var on := showing and slot >= 0
		card.visible = on
		if not on:
			continue
		var from_bottom := float(shown - 1 - slot)
		card.position = Vector2(10.0, bottom - card_h - from_bottom * (card_h + gap))
		card.size = Vector2(card_w, card_h)
		_fill_card(index, _toons[index], _battle_position(index, count))
	_place_clock(view)
	_place_wait(view, count)
	_place_choose(view)


## The first battle point is the rightmost toon. That spot is position 1.
func _battle_position(index: int, count: int) -> int:
	var place := 0
	for cursor in mini(count, _toons.size()):
		var body: Dictionary = _toons[cursor]
		if bool(body.get("running", false)):
			continue
		place += 1
		if cursor == index:
			return place
	return 0


func _fill_card(index: int, toon: Dictionary, position: int) -> void:
	var card := _cards[index]
	var width := card.size.x
	var height := card.size.y
	var hp := int(toon.get("hp", 0))
	var maximum := maxi(int(toon.get("max_hp", hp)), 1)
	var meter_px := height * 0.62
	_dress_meter(index, int(toon.get("id", 0)), hp, maximum, Vector2(8.0 + meter_px * 0.5, height * 0.4), meter_px)
	_health[index].text = "%d/%d" % [hp, maximum]
	_health[index].position = Vector2(meter_px + 12.0, height * 0.12)
	_health[index].size = Vector2(width * 0.34, height * 0.28)
	ToonGui.style_label(_health[index], _INK, maxi(int(height * 0.2), 11), Color(0, 0, 0, 0), 0)
	_toon_names[index].text = String(toon.get("name", "Toon"))
	_toon_names[index].position = Vector2(8.0, height * 0.62)
	_toon_names[index].size = Vector2(width * 0.52, height * 0.32)
	ToonGui.style_label(_toon_names[index], _INK, maxi(int(height * 0.18), 11), Color(0, 0, 0, 0), 0)
	_positions[index].text = "Pos. #%d" % position if position > 0 else ""
	_positions[index].position = Vector2(width * 0.5, height * 0.62)
	_positions[index].size = Vector2(width * 0.46, height * 0.32)
	_positions[index].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ToonGui.style_label(_positions[index], _INK, maxi(int(height * 0.16), 10), Color(0, 0, 0, 0), 0)
	var track := int(toon.get("track", -1))
	var level := int(toon.get("level", -1))
	# A missing choice is not a pass. Pass is track -1 only after this toon picked it.
	var chosen_pass := toon.has("track") and track == -1
	var undecided := not toon.has("track") or track < -1
	var icon := height * 0.46
	var icon_at := Vector2(width - icon - 10.0, (height - icon) * 0.28)
	_marks[index].visible = not chosen_pass and (undecided or track == -2)
	_marks[index].text = "Run" if track == -2 else "?"
	_marks[index].position = icon_at
	_marks[index].size = Vector2(icon, icon)
	ToonGui.style_label(_marks[index], _INK, maxi(int(icon * 0.55), 14), Color(0, 0, 0, 0), 0)
	_passes[index].visible = chosen_pass
	_passes[index].z_index = 3
	_passes[index].position = icon_at
	_passes[index].size = Vector2(icon, icon)
	var chosen := track >= 0
	_plates[index].visible = chosen
	_gags[index].visible = chosen
	if chosen:
		_gags[index].texture = BattleMenu.icon_for(track, level)
		var held := not bool(toon.get("locked", true))
		_gags[index].modulate = Color(1, 1, 1, 0.55) if held else Color.WHITE
		_plates[index].modulate = Color(1, 1, 1, 0.55) if held else Color.WHITE
	_plates[index].position = icon_at
	_plates[index].size = Vector2(icon, icon)
	_gags[index].position = icon_at + Vector2(icon, icon) * 0.12
	_gags[index].size = Vector2(icon, icon) * 0.76
	var marks := String(toon.get("which", ""))
	_which[index].visible = marks != ""
	_which[index].text = marks
	_which[index].position = Vector2(width * 0.52, height * 0.08)
	_which[index].size = Vector2(width * 0.44, height * 0.24)
	ToonGui.style_label(_which[index], _INK, maxi(int(height * 0.16), 10), Color(0, 0, 0, 0), 0)


func _dress_meter(index: int, peer: int, hp: int, maximum: int, center: Vector2, pixels: float) -> void:
	var meter := _meters[index]
	var kind := _species(peer)
	if _meter_kind[index] != kind or meter.get_child_count() == 0:
		_meter_kind[index] = kind
		meter.setup(_style(peer))
	meter.place(center, pixels)
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


func _set_choose_visible(on: bool) -> void:
	if _pick != null:
		_pick.visible = on
	if _pick_status != null:
		_pick_status.visible = on
	if _tab != null:
		_tab.visible = on
	if _tab_text != null:
		_tab_text.visible = on
	if _back != null:
		_back.visible = on
	if _back_text != null:
		_back_text.visible = on
	if not on:
		for arrow in _arrows:
			arrow.visible = false


func _place_choose(view: Vector2) -> void:
	var on := _choosing and _state == "input"
	_set_choose_visible(on)
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
	if not _choose_toon:
		_pick.visible = false
		_pick_status.visible = false
		for arrow in _arrows:
			arrow.visible = false
		return
	var spots := _arrow_spots(_choose_count)
	var height := -0.2
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
		if item is Dictionary and int((item as Dictionary).get("id", -1)) == ToonNet.peer_id() and (item as Dictionary).has("track") and bool((item as Dictionary).get("locked", false)):
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
		if not toon.has("track") or not bool(toon.get("locked", false)):
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
