class_name BattleMenu
extends Control

## InventoryNew.battleActivateButtons. The frame is phase_3.5 BATTLE_Menu.
## Gag rows, the blue inventory buttons, and Run / SOS / Fire / Pass sit on
## it the way the original battle inventory does. Pass skips the attack.
## Fire stays grey until the toon has a pink slip.

signal picked(track: int, level: int)

const _MENU := preload("res://assets/gui/battle/BATTLE_Menu.png")
const _REWARDS := preload("res://scenes/cog_hq/boss_rewards.gd")
const _ROW := preload("res://assets/gui/tutorial/InventoryRow.png")
const _UP := preload("res://assets/gui/rules/InventoryButtonUp.png")
const _DN := preload("res://assets/gui/rules/InventoryButtonDown.png")
const _OVER := preload("res://assets/gui/rules/InventoryButtonRollover.png")
const _FLAT := preload("res://assets/gui/tutorial/InventoryButtonFlat.png")
const _DIALOG := preload("res://assets/gui/tutorial/dialog/dialog_box.png")
const _ICONS: Array[Texture2D] = [
	preload("res://assets/gui/tutorial/gags/inventory_feather.png"),
	preload("res://assets/gui/tutorial/gags/inventory_megaphone.png"),
	preload("res://assets/gui/tutorial/gags/inventory_lipstick.png"),
	preload("res://assets/gui/tutorial/gags/inventory_bamboo_cane.png"),
	preload("res://assets/gui/tutorial/gags/inventory_pixiedust.png"),
	preload("res://assets/gui/tutorial/gags/inventory_juggling_cubes.png"),
	preload("res://assets/gui/tutorial/gags/inventory_ladder.png"),
	preload("res://assets/gui/tutorial/gags/inventory_bannana_peel.png"),
	preload("res://assets/gui/tutorial/gags/inventory_rake.png"),
	preload("res://assets/gui/tutorial/gags/inventory_marbles.png"),
	preload("res://assets/gui/tutorial/gags/inventory_quicksand_icon.png"),
	preload("res://assets/gui/tutorial/gags/inventory_trapdoor.png"),
	preload("res://assets/gui/tutorial/gags/inventory_tnt.png"),
	preload("res://assets/gui/tutorial/gags/inventory_traintracks.png"),
	preload("res://assets/gui/tutorial/gags/inventory_1dollarbill.png"),
	preload("res://assets/gui/tutorial/gags/inventory_small_magnet.png"),
	preload("res://assets/gui/tutorial/gags/inventory_5dollarbill.png"),
	preload("res://assets/gui/tutorial/gags/inventory_big_magnet.png"),
	preload("res://assets/gui/tutorial/gags/inventory_10dollarbill.png"),
	preload("res://assets/gui/tutorial/gags/inventory_hypno_goggles.png"),
	preload("res://assets/gui/tutorial/gags/inventory_screen.png"),
	preload("res://assets/gui/tutorial/gags/inventory_bikehorn.png"),
	preload("res://assets/gui/tutorial/gags/inventory_whistle.png"),
	preload("res://assets/gui/tutorial/gags/inventory_bugle.png"),
	preload("res://assets/gui/tutorial/gags/inventory_aoogah.png"),
	preload("res://assets/gui/tutorial/gags/inventory_elephant.png"),
	preload("res://assets/gui/tutorial/gags/inventory_fog_horn.png"),
	preload("res://assets/gui/tutorial/gags/inventory_opera_singer.png"),
	preload("res://assets/gui/tutorial/gags/inventory_tart.png"),
	preload("res://assets/gui/tutorial/gags/inventory_fruit_pie_slice.png"),
	preload("res://assets/gui/tutorial/gags/inventory_cream_pie_slice.png"),
	preload("res://assets/gui/tutorial/gags/inventory_fruitpie.png"),
	preload("res://assets/gui/tutorial/gags/inventory_creampie.png"),
	preload("res://assets/gui/tutorial/gags/inventory_cake.png"),
	preload("res://assets/gui/tutorial/gags/inventory_wedding.png"),
	preload("res://assets/gui/tutorial/gags/inventory_squirt_flower.png"),
	preload("res://assets/gui/tutorial/gags/inventory_glass_of_water.png"),
	preload("res://assets/gui/tutorial/gags/inventory_water_gun.png"),
	preload("res://assets/gui/tutorial/gags/inventory_seltzer_bottle.png"),
	preload("res://assets/gui/tutorial/gags/inventory_firehose.png"),
	preload("res://assets/gui/tutorial/gags/inventory_storm_cloud.png"),
	preload("res://assets/gui/tutorial/gags/inventory_geyser.png"),
	preload("res://assets/gui/tutorial/gags/inventory_flower_pot.png"),
	preload("res://assets/gui/tutorial/gags/inventory_sandbag.png"),
	preload("res://assets/gui/tutorial/gags/inventory_anvil.png"),
	preload("res://assets/gui/tutorial/gags/inventory_weight.png"),
	preload("res://assets/gui/tutorial/gags/inventory_safe_box.png"),
	preload("res://assets/gui/tutorial/gags/inventory_piano.png"),
	preload("res://assets/gui/tutorial/gags/inventory_ship.png"),
]
const _PRESSABLE := Color(0, 0.6, 1, 1)
const _UNPRESSABLE := Color(0.3, 0.3, 0.3, 0.8)
const _INK := Color(0.05, 0.14, 0.4)

var _loadout: ToonLoadout
var _waiting := false
var _built := false
var _tutorial := false
var _building := false
var _menu: TextureRect
var _prompt: TextureRect
var _prompt_text: Label
var _rows: Array[TextureRect] = []
var _names: Array[Label] = []
var _bars: Array[ColorRect] = []
var _fills: Array[ColorRect] = []
var _skills: Array[Label] = []
var _slots: Array[TextureButton] = []
var _icons: Array[TextureRect] = []
var _counts: Array[Label] = []
var _total: Label
var _detail_name: Label
var _detail_amount: Label
var _detail_data: Label
var _detail_credit: Label
var _run: TextureButton
var _sos: TextureButton
var _doodle: TextureButton
var _fire: TextureButton
var _sos_list: VBoxContainer
var _pass: TextureButton
var _credit := 1.0


func setup(loadout: ToonLoadout, tutorial := false, building := false, credit := 1.0) -> void:
	_loadout = loadout
	_credit = credit
	_tutorial = tutorial
	# InventoryNew.battleActivateButtons hides Run when bldg == 1.
	_building = building
	# Each street round calls this again. Building twice stacks a new menu
	# card over the gag buttons, so the inventory looks empty.
	if not _built:
		_built = true
		mouse_filter = MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_build()
		var view := get_viewport()
		if view != null and not view.size_changed.is_connected(_layout):
			view.size_changed.connect(_layout)
	_layout()


func choose() -> Vector2i:
	_waiting = true
	_show_total()
	_layout()
	visible = true
	# Only the gag buttons take clicks. A full-screen catch would sit above
	# SpeedChat++ and the toon could not open it during the round.
	mouse_filter = MOUSE_FILTER_IGNORE
	# SpeedChat++ draws its window and phrase list at 20–50. The buttons stay
	# in front of that list. Empty space still falls through to the chat.
	z_index = 60
	var parent := get_parent()
	if parent != null:
		parent.move_child(self, parent.get_child_count() - 1)
	var result: Array = await picked
	_waiting = false
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	return Vector2i(int(result[0]), int(result[1]))


## The round left gag selection. Keep the pick waiting, but take the panel down
## so it is not sitting on the movie.
func tuck() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE


## The round ended while the inventory was still up. -3 is not a gag and not a pass.
func cancel() -> void:
	if not _waiting:
		return
	_waiting = false
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	picked.emit(-3, -1)


static func icon_for(track: int, level: int) -> Texture2D:
	var index := track * ToonLoadout.LEVEL_COUNT + level
	if index < 0 or index >= _ICONS.size():
		return null
	return _ICONS[index]


func _build() -> void:
	_menu = _image(_MENU)
	for track in ToonLoadout.TRACK_COUNT:
		var row := _image(_ROW)
		row.modulate = ToonLoadout.TRACK_COLORS[track]
		_rows.append(row)
		var name := _label()
		name.text = ToonLoadout.TRACK_NAMES[track].to_upper()
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(name)
		_names.append(name)
		var bar := ColorRect.new()
		bar.mouse_filter = MOUSE_FILTER_IGNORE
		bar.color = ToonLoadout.TRACK_COLORS[track] * Color(0.6, 0.6, 0.6, 1)
		add_child(bar)
		_bars.append(bar)
		var fill := ColorRect.new()
		fill.mouse_filter = MOUSE_FILTER_IGNORE
		fill.color = ToonLoadout.TRACK_COLORS[track] * Color(0.9, 0.9, 0.9, 1)
		add_child(fill)
		_fills.append(fill)
		var skill := _label()
		skill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(skill)
		_skills.append(skill)
		for level in ToonLoadout.LEVEL_COUNT:
			var slot := _gag_button()
			slot.pressed.connect(_pick.bind(track, level))
			slot.mouse_entered.connect(_show_detail.bind(track, level))
			slot.mouse_exited.connect(_show_total)
			add_child(slot)
			_slots.append(slot)
			var icon := TextureRect.new()
			icon.texture = _ICONS[track * ToonLoadout.LEVEL_COUNT + level]
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = MOUSE_FILTER_IGNORE
			add_child(icon)
			_icons.append(icon)
			var count := _label()
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			add_child(count)
			_counts.append(count)
	_total = _label()
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_total)
	_detail_name = _label()
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_detail_name)
	_detail_amount = _label()
	_detail_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_detail_amount)
	_detail_data = _label()
	add_child(_detail_data)
	_detail_credit = _label()
	add_child(_detail_credit)
	_prompt = _image(_DIALOG)
	_prompt_text = _label()
	_prompt_text.text = "Click a\ngag to\nattack"
	_prompt_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_prompt_text)
	# loadBattleFrame places these on the four wells at the lower right.
	_fire = _command("FIRE", Color(0.4, 0.4, 0.4, 1))
	_fire.disabled = true
	_pass = _command("PASS", _PRESSABLE)
	_pass.pressed.connect(_pass_turn)
	_run = _command("RUN", _PRESSABLE)
	_run.pressed.connect(_run_away)
	_sos = _command("SOS", _PRESSABLE)
	_sos.pressed.connect(_open_sos)
	_doodle = _command("PET", _PRESSABLE)
	_doodle.pressed.connect(_open_doodle)
	_fire.pressed.connect(_use_fire)
	_sos_list = VBoxContainer.new()
	_sos_list.visible = false
	_sos_list.z_index = 5
	add_child(_sos_list)


func _layout() -> void:
	# The inventory sits at z 0.1. The battle frame is scaled by 0.9, and the
	# menu card itself is image_scale 0.8.
	const FRAME := 0.9
	const CARD := 0.8
	_place(_menu, 0.0, 0.1, 2.925 * CARD * FRAME, 1.3958 * CARD * FRAME)
	var origin_x := -0.26 * FRAME
	var origin_z := 0.1 + 0.35 * FRAME
	var row_w := 1.6667 * FRAME
	var row_h := 0.1137 * 1.1 * FRAME
	for track in ToonLoadout.TRACK_COUNT:
		# InventoryNew always draws the colored row and the track name.
		# hideTrack only takes the experience bar and the gag buttons away.
		var open := _loadout != null and _loadout.track_open(track)
		var row_z := origin_z + float(track) * -0.12 * FRAME
		_rows[track].visible = true
		_names[track].visible = true
		_bars[track].visible = open
		_fills[track].visible = open
		_skills[track].visible = open
		_place(_rows[track], origin_x, row_z, row_w, row_h)
		var name := _names[track]
		var name_size := _size(0.55, row_h)
		name.position = _point(origin_x + -0.785 * FRAME, row_z + 0.01 * 1.1 * FRAME) - Vector2(0.0, name_size.y * 0.5)
		name.size = name_size
		ToonGui.style_label(name, Color(0.2, 0.2, 0.2), _px_of(0.05 * FRAME), Color(0, 0, 0, 0), 0)
		if open:
			var bar_size := _size(0.3 * FRAME, 0.05 * 1.1 * FRAME)
			var bar_at := _point(origin_x + -0.645 * FRAME, row_z + -0.025 * 1.1 * FRAME)
			_bars[track].position = bar_at - bar_size * 0.5
			_bars[track].size = bar_size
			_skills[track].position = _bars[track].position
			_skills[track].size = bar_size
			ToonGui.style_label(_skills[track], Color(0, 0, 0, 0.8), _px_of(0.04 * FRAME), Color(0, 0, 0, 0), 0)
			_paint_bar(track)
		for level in ToonLoadout.LEVEL_COUNT:
			var index := track * ToonLoadout.LEVEL_COUNT + level
			var shown := open and _loadout != null and _loadout.gag_usable(track, level)
			_slots[index].visible = shown
			_icons[index].visible = shown
			_counts[index].visible = shown
			if not shown:
				continue
			var local_x := -0.375 + float(level) * 0.18
			var center := _point(origin_x + local_x * FRAME, row_z)
			var well := _size(0.1804 * FRAME, 0.1137 * 1.1 * FRAME)
			_slots[index].position = center - well * 0.5
			_slots[index].size = well
			var icon := well * 0.7
			_icons[index].position = center + Vector2(-0.01 * FRAME, 0.0) - icon * 0.5
			_icons[index].size = icon
			_counts[index].position = _slots[index].position
			_counts[index].size = well
			ToonGui.style_label(_counts[index], Color.WHITE, _px_of(0.04 * FRAME), Color(0.05, 0.12, 0.28), 2)
			_paint_slot(track, level)
	var detail_x := ( -0.26 + 1.125) * FRAME
	var detail_z := 0.1 + (0.35 - 0.08) * FRAME
	_place_text(_total, detail_x, detail_z - 0.095 * FRAME, 0.42, 0.16, _INK, 0.05 * FRAME)
	_place_text(_detail_name, detail_x, detail_z, 0.46, 0.08, _INK, 0.045 * FRAME)
	_place_text(_detail_amount, detail_x + 0.16 * FRAME, detail_z - 0.175 * FRAME, 0.28, 0.06, _INK, 0.04 * FRAME)
	_place_text(_detail_data, detail_x - 0.22 * FRAME, detail_z - 0.24 * FRAME, 0.5, 0.16, _INK, 0.04 * FRAME)
	_place_text(_detail_credit, detail_x - 0.22 * FRAME, detail_z - 0.365 * FRAME, 0.46, 0.06, _INK, 0.04 * FRAME)
	_paint_total()
	var button := _size(0.1804 * 1.05 * FRAME, 0.1137 * 1.05 * FRAME)
	_run.visible = not _building
	_place(_run, 0.73 * FRAME, 0.1 + -0.398 * FRAME, button.x / _unit(), button.y / _unit())
	_place(_sos, 0.96 * FRAME, 0.1 + -0.398 * FRAME, button.x / _unit(), button.y / _unit())
	_place(_doodle, 0.5 * FRAME, 0.1 + -0.398 * FRAME, button.x / _unit(), button.y / _unit())
	_place(_fire, 0.73 * FRAME, 0.1 + -0.242 * FRAME, button.x / _unit(), button.y / _unit())
	_place(_pass, 0.96 * FRAME, 0.1 + -0.242 * FRAME, button.x / _unit(), button.y / _unit())
	for command in [_run, _sos, _doodle, _fire, _pass]:
		var caption := command.get_child(0) as Label
		ToonGui.style_label(caption, Color.WHITE, _px_of(0.05 * FRAME), Color(0, 0, 0, 0), 0)
	_paint_rewards(FRAME)
	# The toontorial line sits over the rows. Street battles leave it off.
	_prompt.visible = _tutorial
	_prompt_text.visible = _tutorial
	if _tutorial:
		_place(_prompt, 0.045, -0.08, 0.66, 0.42)
		_prompt_text.position = _prompt.position
		_prompt_text.size = _prompt.size
		ToonGui.style_title(_prompt_text, Color(0.05, 0.05, 0.08), _px_of(0.055))


func _paint_bar(track: int) -> void:
	if _loadout == null:
		return
	var current := _loadout.experience_of(track)
	var nxt := maxi(_loadout.next_skill(track), 1)
	var ratio := clampf(float(current) / float(nxt), 0.0, 1.0)
	_skills[track].text = "%d / %d" % [current, nxt]
	var back := _bars[track]
	_fills[track].position = back.position
	_fills[track].size = Vector2(back.size.x * ratio, back.size.y)


func _paint_slot(track: int, level: int) -> void:
	if _loadout == null:
		return
	var index := track * ToonLoadout.LEVEL_COUNT + level
	if not _counts[index].visible:
		return
	var owned := _loadout.count_of(track, level)
	_counts[index].text = str(owned)
	var blocked := owned <= 0
	var slot := _slots[index]
	slot.disabled = blocked
	slot.modulate = _UNPRESSABLE if blocked else _PRESSABLE
	_icons[index].modulate = Color(0.55, 0.55, 0.55) if blocked else Color.WHITE


func _paint_total() -> void:
	var carried := 0
	var limit := ToonLoadout.CARRY
	if _loadout != null:
		carried = _loadout.gag_count()
		limit = _loadout.max_carry
	_total.text = "Total gags\n%d / %d" % [carried, limit]


func _show_total() -> void:
	_total.visible = true
	_detail_name.visible = false
	_detail_amount.visible = false
	_detail_data.visible = false
	_detail_credit.visible = false
	_paint_total()


func _show_detail(track: int, level: int) -> void:
	if _loadout == null:
		return
	_total.visible = false
	_detail_name.visible = true
	_detail_amount.visible = true
	_detail_data.visible = true
	_detail_credit.visible = true
	var exp := _loadout.experience_of(track)
	var kind := "Toon-up" if track == ToonLoadout.TOON_UP else "Damage"
	_detail_name.text = _loadout.gag_name(track, level)
	_detail_amount.text = "%d / %d" % [_loadout.count_of(track, level), _loadout.carry_limit(track, level)]
	_detail_data.text = "Accuracy: %s\n%s: %d\nAffects: %s" % [
		ToonLoadout.accuracy_label(track, level),
		kind,
		ToonLoadout.gag_damage(track, level, exp),
		ToonLoadout.affects_label(track, level),
	]
	_detail_credit.text = ToonLoadout.experience_line(level, _credit)


func _pick(track: int, level: int) -> void:
	if not _waiting or _loadout == null or _loadout.count_of(track, level) <= 0:
		return
	_waiting = false
	picked.emit(track, level)


func _pass_turn() -> void:
	if not _waiting:
		return
	_waiting = false
	_hide_sos()
	picked.emit(-1, -1)


func _run_away() -> void:
	if not _waiting:
		return
	_waiting = false
	_hide_sos()
	picked.emit(-2, -1)


func _open_sos() -> void:
	if not _waiting or _sos_list == null:
		return
	_sos_list.visible = not _sos_list.visible
	for child in _sos_list.get_children():
		_sos_list.remove_child(child)
		child.free()
	if not _sos_list.visible:
		return
	for card in _REWARDS.sos_cards():
		if not (card is Dictionary):
			continue
		var body: Dictionary = card
		var track := int(body.get("track", 0))
		var level := int(body.get("level", 0))
		var encoded := track * 10 + level
		if track >= 7:
			encoded = track * 10
		var button := Button.new()
		button.text = "%s (%d)" % [String(body.get("name", "SOS")), int(body.get("calls", 1))]
		button.pressed.connect(_use_sos.bind(encoded))
		_sos_list.add_child(button)


func _use_sos(encoded: int) -> void:
	if not _waiting:
		return
	_waiting = false
	_hide_sos()
	picked.emit(-4, encoded)


func _open_doodle() -> void:
	if not _waiting or _sos_list == null:
		return
	_sos_list.visible = not _sos_list.visible
	for child in _sos_list.get_children():
		_sos_list.remove_child(child)
		child.queue_free()
	if not _sos_list.visible:
		return
	var names: PackedStringArray = ["Jump", "Beg", "Play Dead", "Rollover", "Backflip", "Dance", "Speak"]
	for trick in names.size():
		var button := Button.new()
		button.text = names[trick]
		button.pressed.connect(_use_doodle.bind(trick))
		_sos_list.add_child(button)


func _use_doodle(trick: int) -> void:
	if not _waiting:
		return
	_waiting = false
	_hide_sos()
	picked.emit(-6, trick)


func _use_fire() -> void:
	if not _waiting or _REWARDS.pink_slips() <= 0:
		return
	_waiting = false
	_hide_sos()
	picked.emit(-5, -1)


func _hide_sos() -> void:
	if _sos_list != null:
		_sos_list.visible = false


func _paint_rewards(frame: float) -> void:
	var slips := _REWARDS.pink_slips()
	_fire.disabled = slips <= 0
	_fire.modulate = _PRESSABLE if slips > 0 else Color(0.4, 0.4, 0.4, 1)
	var fire_label := _fire.get_child(0) as Label
	if fire_label != null:
		fire_label.text = "FIRE" if slips <= 0 else "FIRE %d" % slips
	var cards := _REWARDS.sos_count()
	_sos.disabled = cards <= 0
	_sos.modulate = _PRESSABLE if cards > 0 else Color(0.4, 0.4, 0.4, 1)
	var has_pet := preload("res://scenes/pets/doodle_kennel.gd").has_pet()
	if _doodle != null:
		_doodle.disabled = not has_pet
		_doodle.modulate = _PRESSABLE if has_pet else Color(0.4, 0.4, 0.4, 1)
	if _sos_list == null:
		return
	_sos_list.position = _sos.position + Vector2(-_sos.size.x * 2.2, -180.0 * frame)
	_sos_list.size = Vector2(180, 180)


func _image(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _label() -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	return label


func _gag_button() -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _UP
	button.texture_hover = _OVER
	button.texture_pressed = _DN
	button.texture_disabled = _FLAT
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	ToonGui.button_sounds(button)
	return button


func _command(text: String, tint: Color) -> TextureButton:
	var button := _gag_button()
	button.modulate = tint
	var caption := _label()
	caption.text = text
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(caption)
	add_child(button)
	return button


func _place_text(label: Label, ax: float, az: float, aw: float, ah: float, color: Color, scale: float) -> void:
	var rect := _size(aw, ah)
	var at := _point(ax, az)
	if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		label.position = at - Vector2(rect.x, rect.y * 0.5)
	elif label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		label.position = at - rect * 0.5
	else:
		label.position = at - Vector2(0.0, rect.y * 0.5)
	label.size = rect
	ToonGui.style_label(label, color, _px_of(scale), Color(0, 0, 0, 0), 0)


func _point(ax: float, az: float) -> Vector2:
	var view := get_viewport().get_visible_rect().size
	var aspect := view.x / maxf(view.y, 1.0)
	return Vector2((ax / aspect + 1.0) * 0.5 * view.x, (1.0 - az) * 0.5 * view.y)


func _size(aw: float, ah: float) -> Vector2:
	return Vector2(aw, ah) * _unit()


func _unit() -> float:
	return get_viewport().get_visible_rect().size.y * 0.5


func _place(control: Control, ax: float, az: float, aw: float, ah: float) -> void:
	var rect := _size(aw, ah)
	control.position = _point(ax, az) - rect * 0.5
	control.size = rect


func _px_of(aspect_height: float) -> int:
	return maxi(int(round(aspect_height * get_viewport().get_visible_rect().size.y * 0.5)), 8)
