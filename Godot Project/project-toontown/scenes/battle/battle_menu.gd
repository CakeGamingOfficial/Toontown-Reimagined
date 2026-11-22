class_name BattleMenu
extends Control

## InventoryNew.battleActivateButtons. Track names sit on a dark bar.
## Clicking a name opens the gag levels that track has unlocked. Those
## icons stack above the name, or run in a row when Battle Gag Menu is
## set to Horizontal. Pass skips the attack. Fire stays grey until the
## toon has a pink slip.

signal picked(track: int, level: int)
signal drafted(track: int, level: int)

const _MENU := preload("res://assets/gui/battle/BATTLE_Menu.png")
const _UI := preload("res://scenes/shticker/ui_settings.gd")
const _MATH := preload("res://scenes/battle/street_fights.gd")
const _REWARDS := preload("res://scenes/cog_hq/boss_rewards.gd")
const _ROW := preload("res://assets/gui/tutorial/InventoryRow.png")
const _UP := preload("res://assets/gui/rules/InventoryButtonUp.png")
const _DN := preload("res://assets/gui/rules/InventoryButtonDown.png")
const _OVER := preload("res://assets/gui/rules/InventoryButtonRollover.png")
const _FLAT := preload("res://assets/gui/tutorial/InventoryButtonFlat.png")
const _DIALOG := preload("res://assets/gui/tutorial/dialog/dialog_box.png")
const _OK_UP := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_UP.png")
const _OK_DOWN := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_DN.png")
const _OK_HOVER := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_Rllvr.png")
const _CANCEL_UP := preload("res://assets/toons/gui/CloseBtn_UP.png")
const _CANCEL_DOWN := preload("res://assets/toons/gui/CloseBtn_DN.png")
const _CANCEL_HOVER := preload("res://assets/toons/gui/CloseBtn_Rllvr.png")
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
## Cream faces on the blue bar. The old cyan tint disappeared into that bar.
const _COMMAND := Color(1.0, 0.96, 0.78, 1.0)
const _COMMAND_OFF := Color(0.72, 0.74, 0.78, 1.0)
const _COMMAND_INK := Color(0.04, 0.1, 0.28, 1.0)

var _loadout: ToonLoadout
var _waiting := false
var _built := false
var _tutorial := false
var _building := false
var _runnable := true
var _run_dialog: Control
## The street prop's track. InventoryNew paints those buttons orange and flashes them.
var _bonus_track := -1
const _PROP_BONUS := Color(1.0, 0.6, 0.0, 1.0)
var _menu: TextureRect
var _prompt: TextureRect
var _prompt_text: Label
var _rows: Array[TextureRect] = []
var _names: Array[Label] = []
var _bars: Array[ColorRect] = []
var _fills: Array[ColorRect] = []
var _skills: Array[Label] = []
var _xp_hits: Array[Control] = []
var _slots: Array[TextureButton] = []
var _icons: Array[TextureRect] = []
var _counts: Array[Label] = []
var _total: Label
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_amount: Label
var _detail_data: Label
var _detail_credit: Label
var _run: TextureButton
var _sos: TextureButton
var _fire: TextureButton
var _sos_list: VBoxContainer
var _pass: TextureButton
var _dock: ColorRect
var _track_picks: Array[TextureButton] = []
var _track_icons: Array[TextureRect] = []
var _track_faces: Array[ColorRect] = []
var _popped: Array[bool] = []
var _credit := 1.0
var _credit_level := -1
var _no_credit := false
## A group can hold a gag, look at the other toons, and lock it in.
var hold_choices := false
var _draft := Vector2i(-99, -1)
var _lock: TextureButton
var _lock_ready := false
var _preview_cogs: Array = []
var _preview_choices: Array = []
var _hover := Vector2i(-1, -1)


func setup(loadout: ToonLoadout, tutorial := false, building := false, credit := 1.0, credit_level := -1, bonus_track := -1, runnable := true) -> void:
	_loadout = loadout
	_credit = credit
	_credit_level = credit_level
	_bonus_track = bonus_track
	_tutorial = tutorial
	# InventoryNew.battleActivateButtons hides Run when bldg == 1.
	# Street battles are the only runable fights. Factories, mints, offices,
	# courses, and the tutorial flunky are not.
	_building = building
	_runnable = runnable and not tutorial
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


func _process(_delta: float) -> void:
	if not visible or _bonus_track < 0:
		return
	# InventoryNew flashes the prop-bonus buttons between dim and full.
	var wave := 0.15 + 0.85 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005))
	var tint := Color(_PROP_BONUS.r * wave, _PROP_BONUS.g * wave, _PROP_BONUS.b * wave, 1.0)
	for track in ToonLoadout.TRACK_COUNT:
		if track != _bonus_track:
			continue
		for level in ToonLoadout.LEVEL_COUNT:
			var index := track * ToonLoadout.LEVEL_COUNT + level
			if index >= _slots.size() or _slots[index].disabled or not _slots[index].visible:
				continue
			_slots[index].modulate = tint


func choose() -> Vector2i:
	_waiting = true
	_draft = Vector2i(-99, -1)
	arm_lock(false)
	for track in _popped.size():
		_popped[track] = false
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
	_close_run()
	visible = false
	z_index = 2
	mouse_filter = MOUSE_FILTER_IGNORE


## The round ended while the inventory was still up. -3 is not a gag and not a pass.
func cancel() -> void:
	_close_run()
	if not _waiting:
		return
	_waiting = false
	visible = false
	z_index = 2
	mouse_filter = MOUSE_FILTER_IGNORE
	picked.emit(-3, -1)


static func icon_for(track: int, level: int) -> Texture2D:
	var index := track * ToonLoadout.LEVEL_COUNT + level
	if index < 0 or index >= _ICONS.size():
		return null
	return _ICONS[index]


func _build() -> void:
	_dock = ColorRect.new()
	# Track names and experience. Gag icons open above this strip.
	_dock.color = Color(0.12, 0.12, 0.14, 0.94)
	_dock.mouse_filter = MOUSE_FILTER_IGNORE
	_dock.z_index = -1
	add_child(_dock)
	_menu = _image(_MENU)
	_menu.visible = false
	for track in ToonLoadout.TRACK_COUNT:
		var row := _image(_ROW)
		row.modulate = ToonLoadout.TRACK_COLORS[track]
		_rows.append(row)
		var name := _label()
		name.text = ToonLoadout.TRACK_NAMES[track]
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
		skill.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(skill)
		_skills.append(skill)
		var hit := Control.new()
		hit.mouse_filter = MOUSE_FILTER_STOP
		hit.mouse_entered.connect(_show_xp.bind(track))
		hit.mouse_exited.connect(_show_total)
		add_child(hit)
		_xp_hits.append(hit)
		var pick := _gag_button()
		pick.texture_normal = null
		pick.texture_hover = null
		pick.texture_pressed = null
		pick.texture_disabled = null
		pick.pressed.connect(_select_track.bind(track))
		add_child(pick)
		_track_picks.append(pick)
		_popped.append(false)
		var face := ColorRect.new()
		face.mouse_filter = MOUSE_FILTER_IGNORE
		face.color = Color(0.16, 0.16, 0.18, 1)
		pick.add_child(face)
		_track_faces.append(face)
		var mark := TextureRect.new()
		mark.texture = _ICONS[track * ToonLoadout.LEVEL_COUNT]
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.mouse_filter = MOUSE_FILTER_IGNORE
		pick.add_child(mark)
		_track_icons.append(mark)
		for level in ToonLoadout.LEVEL_COUNT:
			var slot := _gag_button()
			slot.pressed.connect(_hold_gag.bind(track, level))
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
	# showDetail puts the gag picture in the blue plate, under the name.
	_detail_icon = _image(_ICONS[0])
	_detail_icon.visible = false
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
	_fire = _command("FIRE", _COMMAND_OFF)
	_fire.disabled = true
	_pass = _command("PASS", _COMMAND)
	_pass.pressed.connect(_pass_turn)
	_run = _command("RUN", _COMMAND)
	_run.pressed.connect(_run_away)
	_sos = _command("SOS", _COMMAND)
	_sos.pressed.connect(_open_sos)
	_fire.pressed.connect(_use_fire)
	_lock = _command("LOCK", _COMMAND)
	_lock.visible = false
	_lock.pressed.connect(_commit_draft)
	_sos_list = VBoxContainer.new()
	_sos_list.visible = false
	_sos_list.z_index = 5
	add_child(_sos_list)


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.y < 2.0:
		return
	_menu.visible = false
	for track in ToonLoadout.TRACK_COUNT:
		_rows[track].visible = false
		if track < _track_icons.size():
			_track_icons[track].visible = false
	for index in _slots.size():
		_slots[index].visible = false
		_icons[index].visible = false
		_counts[index].visible = false
	var margin := 12.0
	var well := clampf(view.y * 0.068, 46.0, 68.0)
	var gap := 6.0
	var open_tracks: Array[int] = []
	for track in ToonLoadout.TRACK_COUNT:
		if _loadout != null and _loadout.track_open(track):
			open_tracks.append(track)
	_run.visible = _runnable and not _building
	var command := clampf(well * 0.86, 44.0, 62.0)
	var commands: Array[TextureButton] = []
	commands.append(_fire)
	commands.append(_pass)
	commands.append(_sos)
	if _run.visible:
		commands.append(_run)
	var stack_h := float(commands.size()) * command + float(maxi(commands.size() - 1, 0)) * gap
	var stack_x := view.x - margin - command
	var stack_y := view.y - margin - stack_h
	for index in commands.size():
		var button := commands[index]
		_place_command(button, stack_x, stack_y + float(index) * (command + gap), command, true)
	if not _run.visible:
		_place_command(_run, 0.0, 0.0, command, false)
	var lock_on := _lock_ready and hold_choices
	_place_command(_lock, stack_x - command - gap, stack_y, command, lock_on)
	var lane_left := margin
	if not _tutorial:
		var card_h := clampf(view.y * 0.09, 72.0, 96.0)
		lane_left = 10.0 + card_h * 2.55 + 16.0
	var lane_right := stack_x - 16.0
	var lane_w := maxf(lane_right - lane_left, 1.0)
	var name_w := maxf(well, 88.0)
	var tracks_w := float(open_tracks.size()) * name_w + float(maxi(open_tracks.size() - 1, 0)) * gap
	if open_tracks.size() > 0 and tracks_w > lane_w:
		name_w = maxf((lane_w - float(open_tracks.size() - 1) * gap) / float(open_tracks.size()), 36.0)
		tracks_w = float(open_tracks.size()) * name_w + float(open_tracks.size() - 1) * gap
	well = minf(well, name_w)
	var step := 4.0
	var across := _UI.gag_rows_across()
	var rows := 0
	var deepest := 0
	for track in open_tracks:
		if track >= _popped.size() or not _popped[track]:
			continue
		var unlocked := _unlocked_levels(track)
		if unlocked.is_empty():
			continue
		rows += 1
		deepest = maxi(deepest, unlocked.size())
	if across and deepest > 0:
		var need := float(deepest) * well + float(deepest - 1) * step
		if need > lane_w:
			well = maxf((lane_w - float(deepest - 1) * step) / float(deepest), 34.0)
	var tallest := 0.0
	if across:
		tallest = float(rows) * well + float(maxi(rows - 1, 0)) * step
	elif deepest > 0:
		tallest = float(deepest) * well + float(maxi(deepest - 1, 0)) * step
	var name_h := clampf(name_w * 0.42, 26.0, 36.0)
	var xp_h := clampf(name_w * 0.28, 16.0, 22.0)
	var strip_y := view.y - margin - name_h - xp_h
	var room := strip_y - 40.0
	if tallest > room and tallest > 0.0:
		var scale := room / tallest
		well = maxf(well * scale, 32.0)
		step = maxf(step * scale, 2.0)
		if across:
			tallest = float(rows) * well + float(maxi(rows - 1, 0)) * step
		else:
			tallest = float(deepest) * well + float(maxi(deepest - 1, 0)) * step
	var popup_bottom := strip_y - 8.0
	var popup_top := popup_bottom - tallest
	var info_h := 78.0
	var info_y := popup_top - 6.0 - info_h
	_dock.position = Vector2(lane_left, strip_y)
	_dock.size = Vector2(maxf(lane_right - lane_left, 1.0), view.y - margin - strip_y)
	var row_x := lane_left + maxf((lane_w - tracks_w) * 0.5, 0.0)
	var column_x: Array[float] = []
	column_x.resize(ToonLoadout.TRACK_COUNT)
	var cursor := row_x
	for track in ToonLoadout.TRACK_COUNT:
		var listed := open_tracks.has(track)
		var pick := _track_picks[track]
		var title := _names[track]
		pick.visible = listed
		title.visible = listed
		_bars[track].visible = listed
		_fills[track].visible = listed
		_skills[track].visible = listed
		if track < _xp_hits.size():
			_xp_hits[track].visible = listed
		if not listed:
			continue
		column_x[track] = cursor
		pick.position = Vector2(cursor, strip_y)
		pick.size = Vector2(name_w, name_h)
		pick.z_index = 3
		var face := _track_faces[track]
		face.position = Vector2.ZERO
		face.size = pick.size
		var opened := track < _popped.size() and _popped[track]
		face.color = ToonLoadout.TRACK_COLORS[track] if opened else Color(0.16, 0.16, 0.18, 1.0)
		title.position = pick.position
		title.size = pick.size
		title.z_index = 5
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.clip_text = true
		var ink := Color(0.08, 0.08, 0.1, 1.0) if opened else Color.WHITE
		ToonGui.style_label(title, ink, maxi(int(name_h * 0.42), 11), Color(0, 0, 0, 0), 0)
		var back := _bars[track]
		back.position = Vector2(cursor, strip_y + name_h)
		back.size = Vector2(name_w, xp_h)
		_paint_bar(track)
		var skill := _skills[track]
		skill.position = back.position
		skill.size = back.size
		skill.z_index = 2
		skill.clip_text = true
		ToonGui.style_label(skill, Color.WHITE, maxi(int(xp_h * 0.72), 10), Color(0.05, 0.08, 0.14), 2)
		var hit := _xp_hits[track]
		hit.visible = true
		hit.position = back.position
		hit.size = back.size
		hit.z_index = 6
		cursor += name_w + gap
	var row_at := 0
	for track in open_tracks:
		var levels := _unlocked_levels(track)
		if track >= _popped.size() or not _popped[track] or levels.is_empty():
			continue
		if across:
			var row_w := float(levels.size()) * well + float(maxi(levels.size() - 1, 0)) * step
			var gag_x := lane_left + maxf((lane_w - row_w) * 0.5, 0.0)
			var gag_y := popup_bottom - float(row_at + 1) * well - float(row_at) * step
			for index in levels.size():
				var level := levels[index]
				var at := Vector2(gag_x + float(index) * (well + step), gag_y)
				_seat_gag(track, level, at, well)
			row_at += 1
		else:
			var top := popup_bottom - float(levels.size()) * well - float(maxi(levels.size() - 1, 0)) * step
			var inset := (name_w - well) * 0.5
			for index in levels.size():
				var level := levels[index]
				var at := Vector2(column_x[track] + inset, top + float(index) * (well + step))
				_seat_gag(track, level, at, well)
	_seat_bottom(Rect2(lane_left, info_y, lane_w, info_h))
	_paint_total()
	_layout_run()
	_paint_rewards(1.0)
	_prompt.visible = false
	_prompt_text.visible = _tutorial
	if _tutorial:
		_prompt_text.text = "Click a gag to attack"
		_prompt_text.position = Vector2(lane_left, info_y - 28.0)
		_prompt_text.size = Vector2(lane_w, 24.0)
		ToonGui.style_label(_prompt_text, Color(1, 0.95, 0.7), 16, Color(0.08, 0.1, 0.16), 4)


func _unlocked_levels(track: int) -> Array[int]:
	var levels: Array[int] = []
	if _loadout == null or not _loadout.track_open(track):
		return levels
	for level in ToonLoadout.LEVEL_COUNT:
		if _loadout.gag_usable(track, level):
			levels.append(level)
	return levels


func _seat_gag(track: int, level: int, at: Vector2, well: float) -> void:
	var index := track * ToonLoadout.LEVEL_COUNT + level
	_slots[index].visible = true
	_slots[index].position = at
	_slots[index].size = Vector2(well, well)
	_slots[index].z_index = 3
	var icon_size := well * 0.64
	_icons[index].visible = true
	_icons[index].position = at + (Vector2(well, well) - Vector2(icon_size, icon_size)) * 0.5
	_icons[index].size = Vector2(icon_size, icon_size)
	_icons[index].z_index = 4
	_counts[index].visible = true
	_counts[index].position = at
	_counts[index].size = Vector2(well, well)
	_counts[index].z_index = 5
	ToonGui.style_label(_counts[index], Color.WHITE, maxi(int(well * 0.22), 11), Color(0.05, 0.12, 0.28), 2)
	_paint_slot(track, level)


func _place_command(button: TextureButton, x: float, y: float, side: float, shown: bool) -> void:
	button.visible = shown
	if not shown:
		return
	button.position = Vector2(x, y)
	button.size = Vector2(side, side)
	button.z_index = 4
	var caption := button.get_child(0) as Label
	ToonGui.style_label(caption, _COMMAND_INK, maxi(int(side * 0.28), 13), Color(1, 1, 1, 0.9), 2)


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


func _show_xp(track: int) -> void:
	if _loadout == null:
		return
	_hover = Vector2i(-1, -1)
	_total.visible = false
	_detail_icon.visible = false
	_detail_name.visible = true
	_detail_amount.visible = false
	_detail_data.visible = true
	_detail_credit.visible = false
	_detail_name.text = ToonLoadout.TRACK_NAMES[track]
	_detail_data.text = _xp_line(track)


func _xp_line(track: int) -> String:
	var exp := _loadout.experience_of(track)
	var next_level := -1
	for level in ToonLoadout.LEVEL_COUNT:
		if exp < ToonLoadout.skill_at(track, level):
			next_level = level
			break
	if next_level < 0:
		return "This track is maxed."
	var left := ToonLoadout.skill_at(track, next_level) - exp
	var gag := _loadout.gag_name(track, next_level)
	if left == 1:
		return "1 point to %s." % gag
	return "%d points to %s." % [left, gag]


func _paint_slot(track: int, level: int) -> void:
	if _loadout == null:
		return
	var index := track * ToonLoadout.LEVEL_COUNT + level
	if not _counts[index].visible:
		return
	var owned := _loadout.count_of(track, level)
	_counts[index].text = str(owned)
	# InventoryNew.ShadowBuffedColor. An organic gag or the prop's track has a white shadow.
	var buffed := _loadout.is_organic(track, level) or track == _bonus_track
	var outline := Color.WHITE if buffed else Color(0.05, 0.12, 0.28)
	_counts[index].add_theme_color_override("font_outline_color", outline)
	var blocked := owned <= 0
	var slot := _slots[index]
	slot.disabled = blocked
	if blocked:
		slot.modulate = _UNPRESSABLE
	elif track == _bonus_track:
		slot.modulate = _PROP_BONUS
	else:
		slot.modulate = _PRESSABLE
	_icons[index].modulate = Color(0.55, 0.55, 0.55) if blocked else Color.WHITE


func _paint_total() -> void:
	var carried := 0
	var limit := ToonLoadout.CARRY
	if _loadout != null:
		carried = _loadout.gag_count()
		limit = _loadout.max_carry
	_total.text = "Total gags\n%d / %d" % [carried, limit]


func set_preview(cogs: Array, choices: Array) -> void:
	_preview_cogs = cogs
	_preview_choices = choices
	if _hover.x >= 0 and _detail_data != null and _detail_data.visible:
		_show_detail(_hover.x, _hover.y)


func _show_total() -> void:
	_hover = Vector2i(-1, -1)
	_total.visible = true
	_detail_icon.visible = false
	_detail_name.visible = false
	_detail_amount.visible = false
	_detail_data.visible = false
	_detail_credit.visible = false
	_no_credit = false
	_paint_total()


func _show_detail(track: int, level: int) -> void:
	if _loadout == null:
		return
	_hover = Vector2i(track, level)
	_total.visible = false
	_detail_icon.visible = true
	_detail_icon.texture = _ICONS[track * ToonLoadout.LEVEL_COUNT + level]
	_detail_name.visible = true
	_detail_amount.visible = true
	_detail_data.visible = true
	_detail_credit.visible = true
	var exp := _loadout.experience_of(track)
	var grown := _loadout.is_organic(track, level)
	var buffed := grown or track == _bonus_track
	var base := ToonLoadout.gag_damage(track, level, exp, buffed)
	_detail_name.text = _loadout.gag_name(track, level)
	_detail_amount.text = "%d / %d" % [_loadout.count_of(track, level), _loadout.carry_limit(track, level)]
	_detail_data.text = _hover_math(track, level, exp, buffed, base)
	_no_credit = _credit_level >= 0 and not ToonLoadout.earns_experience(level, _credit_level)
	# InventoryNew.setDetailCredit shows "Skill credit: None" in red.
	_detail_credit.text = "Experience: None" if _no_credit else ToonLoadout.experience_line(level, _credit)


## Damage and hit chance for the gag under the cursor. Knockback is half of a
## throw or squirt when that cog is lured before this track. A same-track combo
## adds 20 percent of those gag hits on the last one.
func _hover_math(track: int, level: int, exp: int, buffed: bool, base: int) -> String:
	if track == ToonLoadout.TOON_UP:
		var chance := _MATH.hit_chance(track, level, buffed, exp, 0, 0, 1)
		return "Heals %d laff    %d%% to hit" % [base, chance]
	if track == 1:
		return "100%% to hit    sets %d trap damage" % base
	var living := _living_cogs()
	if living.is_empty():
		var bare := _MATH.hit_chance(track, level, buffed, exp, 0, 0, 1)
		return "%d%% to hit    %d damage" % [bare, base]
	var group := ToonLoadout.affects_group(track, level)
	var lines: PackedStringArray = PackedStringArray()
	if group:
		lines.append(_group_chance(track, level, exp, buffed, living))
	for item in living:
		if item is Dictionary:
			lines.append(_cog_math(item, track, level, exp, buffed, base, group))
	return "\n".join(lines)


func _living_cogs() -> Array:
	var rows: Array = []
	for item in _preview_cogs:
		if item is Dictionary and int((item as Dictionary).get("hp", 0)) > 0:
			rows.append(item)
	return rows


func _group_chance(track: int, level: int, exp: int, buffed: bool, living: Array) -> String:
	var defense := 0
	var lured_n := 0
	for item in living:
		var body: Dictionary = item
		defense = maxi(defense, _MATH.suit_defense(String(body.get("code", "")), int(body.get("level", 1))))
		if _lured_for(body, track):
			lured_n += 1
	var use_exp := _shared_exp(track, exp, -1)
	var chance := _MATH.hit_chance(track, level, buffed, use_exp, defense, lured_n, living.size())
	var note := "" if chance >= 100 else ". Damage is if that hit lands"
	return "%d%% to hit the group%s" % [chance, note]


func _cog_math(cog: Dictionary, track: int, level: int, exp: int, buffed: bool, base: int, group: bool) -> String:
	var cog_id := int(cog.get("id", -1))
	var lured := _lured_for(cog, track)
	var already := bool(cog.get("lured", false))
	var lvl := int(cog.get("level", 1))
	var hp := int(cog.get("hp", 0))
	var title := "Lv.%d %s %d hp" % [lvl, String(cog.get("name", "Cog")), hp]
	if track == 6 and lured:
		return "%s    misses, the cog is lured" % title
	var mine := base
	var kb := _MATH.knockback_bonus(track, mine, lured)
	var extra := _partner_damage(track, cog_id, lured)
	var hits := 1 + int(extra.get("count", 0))
	var bases := mine + int(extra.get("base", 0))
	var bonus := _MATH.combo_extra(hits, bases)
	var total := bases + kb + int(extra.get("kb", 0)) + bonus
	var parts := str(mine)
	if kb > 0:
		parts += "+%d lure" % kb
	if int(extra.get("base", 0)) > 0:
		parts += "+%d" % int(extra.get("base", 0))
		if int(extra.get("kb", 0)) > 0:
			parts += "+%d lure" % int(extra.get("kb", 0))
	if bonus > 0:
		parts += "+%d combo" % bonus
	if (kb > 0 or int(extra.get("kb", 0)) > 0) and not already:
		parts += " if lured"
	var shown := str(total) if parts == str(mine) else "%d (%s)" % [total, parts]
	var left := "KO" if total >= hp else "%d left" % (hp - total)
	if group:
		return "%s    %s    %s" % [title, shown, left]
	var defense := _MATH.suit_defense(String(cog.get("code", "")), lvl)
	var lured_n := 1 if lured else 0
	var use_exp := _shared_exp(track, exp, cog_id)
	var chance := _MATH.hit_chance(track, level, buffed, use_exp, defense, lured_n, 1)
	if chance < 100 and total >= hp:
		left = "KO if it hits"
	return "%s    %d%%    %s    %s" % [title, chance, shown, left]


func _lured_for(cog: Dictionary, track: int) -> bool:
	var lured := bool(cog.get("lured", false))
	var cog_id := int(cog.get("id", -1))
	for earlier in range(track):
		if earlier != 2 and earlier != 3 and earlier != 4 and earlier != 5:
			continue
		if not _round_hits(earlier, cog_id):
			continue
		lured = earlier == 2
	return lured


func _round_hits(track: int, cog_id: int) -> bool:
	for item in _preview_choices:
		if not (item is Dictionary):
			continue
		var choice: Dictionary = item
		if int(choice.get("id", -1)) == ToonNet.peer_id():
			continue
		if int(choice.get("track", -1)) != track:
			continue
		if _hits_cog(choice, cog_id):
			return true
	return false


func _hits_cog(choice: Dictionary, cog_id: int) -> bool:
	var track := int(choice.get("track", -1))
	var level := int(choice.get("level", 0))
	if track < 0 or track > 6:
		return false
	if ToonLoadout.affects_group(track, level):
		return true
	return int(choice.get("target", -2)) == cog_id


func _partner_damage(track: int, cog_id: int, lured: bool) -> Dictionary:
	var base := 0
	var kb := 0
	var count := 0
	for item in _preview_choices:
		if not (item is Dictionary):
			continue
		var choice: Dictionary = item
		if int(choice.get("id", -1)) == ToonNet.peer_id():
			continue
		if int(choice.get("track", -1)) != track or not _hits_cog(choice, cog_id):
			continue
		var grown := bool(choice.get("organic", false)) or track == _bonus_track
		var dealt := ToonLoadout.gag_damage(track, int(choice.get("level", 0)), int(choice.get("exp", 0)), grown)
		if dealt <= 0:
			continue
		base += dealt
		kb += _MATH.knockback_bonus(track, dealt, lured)
		count += 1
	return {"base": base, "kb": kb, "count": count}


func _shared_exp(track: int, exp: int, target: int) -> int:
	var best := exp
	var best_bonus := _MATH.exp_accuracy(exp, track)
	for item in _preview_choices:
		if not (item is Dictionary):
			continue
		var choice: Dictionary = item
		if int(choice.get("id", -1)) == ToonNet.peer_id():
			continue
		if int(choice.get("track", -1)) != track:
			continue
		if int(choice.get("target", -2)) != target:
			continue
		var theirs := int(choice.get("exp", 0))
		var bonus := _MATH.exp_accuracy(theirs, track)
		if bonus > best_bonus:
			best_bonus = bonus
			best = theirs
	return best


func _select_track(track: int) -> void:
	if _loadout == null or not _loadout.track_open(track):
		return
	if track < 0 or track >= _popped.size():
		return
	_popped[track] = not _popped[track]
	_show_total()
	_layout()


func _hold_gag(track: int, level: int) -> void:
	if not _waiting:
		return
	if track >= 0 and (_loadout == null or _loadout.count_of(track, level) <= 0):
		return
	_draft = Vector2i(track, level)
	_hide_sos()
	if not hold_choices:
		_waiting = false
		picked.emit(track, level)
		return
	arm_lock(false)
	drafted.emit(track, level)


func arm_lock(on: bool) -> void:
	_lock_ready = on and hold_choices
	if _lock != null:
		_lock.disabled = not _lock_ready
	if is_inside_tree():
		_layout()


func _commit_draft() -> void:
	if not _waiting or not _lock_ready or _draft.x < -6:
		return
	_waiting = false
	_lock_ready = false
	picked.emit(_draft.x, _draft.y)


func _pass_turn() -> void:
	_hold_gag(-1, -1)


func _run_away() -> void:
	if not _waiting or not _runnable or _building:
		return
	if _run_dialog != null:
		return
	_open_run()


## TownBattle.enterRun. TwoChoice asks before the toon leaves the street.
func _open_run() -> void:
	var dialog := Control.new()
	dialog.name = "RunConfirm"
	dialog.mouse_filter = MOUSE_FILTER_STOP
	dialog.z_index = 80
	dialog.set_anchors_preset(PRESET_FULL_RECT)
	_run_dialog = dialog
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.mouse_filter = MOUSE_FILTER_STOP
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dialog.add_child(dim)
	var frame := TextureRect.new()
	frame.texture = _DIALOG
	frame.modulate = Color(1, 1, 0.75)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	dialog.add_child(frame)
	var message := Label.new()
	message.text = "Run all the way back to the playground?"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.mouse_filter = MOUSE_FILTER_IGNORE
	dialog.add_child(message)
	dialog.add_child(_run_choice(_OK_UP, _OK_DOWN, _OK_HOVER, "OK", _accept_run))
	dialog.add_child(_run_choice(_CANCEL_UP, _CANCEL_DOWN, _CANCEL_HOVER, "Cancel", _close_run))
	add_child(dialog)
	move_child(dialog, get_child_count() - 1)
	_layout_run()


func _run_choice(up: Texture2D, down: Texture2D, hover: Texture2D, caption: String, action: Callable) -> Control:
	var box := Control.new()
	box.mouse_filter = MOUSE_FILTER_IGNORE
	var button := TextureButton.new()
	button.texture_normal = up
	button.texture_pressed = down
	button.texture_hover = hover
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	box.add_child(button)
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(label)
	return box


func _layout_run() -> void:
	if _run_dialog == null or not is_instance_valid(_run_dialog):
		return
	var view := get_viewport_rect().size
	if view.y < 2.0:
		return
	_run_dialog.position = Vector2.ZERO
	_run_dialog.size = view
	var dim := _run_dialog.get_child(0) as Control
	dim.position = Vector2.ZERO
	dim.size = view
	ToonGui.place(_run_dialog.get_child(1), view, -0.0281, -0.0426, 1.4792, 1.3047)
	var message := _run_dialog.get_child(2) as Label
	var px := maxi(int(round(0.055 * view.y * 0.5)), 1)
	ToonGui.style_label(message, Color(0.08, 0.08, 0.08), px, Color(0, 0, 0, 0), 0)
	ToonGui.place(message, view, 0.0, 0.08, 1.2, 0.22)
	_place_run_choice(_run_dialog.get_child(3), view, -0.2)
	_place_run_choice(_run_dialog.get_child(4), view, 0.2)


func _place_run_choice(box: Node, view: Vector2, x: float) -> void:
	var host := box as Control
	host.position = Vector2.ZERO
	host.size = view
	var button := box.get_child(0) as Control
	var caption := box.get_child(1) as Label
	ToonGui.place(button, view, x, -0.4, 0.1125, 0.1125)
	var px := maxi(int(round(0.06 * view.y * 0.5)), 1)
	ToonGui.style_label(caption, Color(0, 0, 0), px, Color(0, 0, 0, 0), 0)
	ToonGui.place(caption, view, x, -0.5, 0.4, 0.1)


func _close_run() -> void:
	var dialog := _run_dialog
	_run_dialog = null
	ToonGui.dismiss_after_click(dialog)


func _accept_run() -> void:
	if not _waiting:
		_close_run()
		return
	_close_run()
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
	# TownBattleSOSPanel puts the doodle first in the friends list.
	var kennel := preload("res://scenes/pets/doodle_kennel.gd")
	if kennel.has_pet():
		var pet_name := String(kennel.current().get("name", ""))
		if pet_name.is_empty():
			pet_name = "Doodle"
		var pet := Button.new()
		pet.text = pet_name
		pet.pressed.connect(_show_tricks)
		_sos_list.add_child(pet)
	for card in _REWARDS.sos_cards():
		if not (card is Dictionary):
			continue
		var body: Dictionary = card
		var button := Button.new()
		button.text = "%s (%d)" % [String(body.get("name", "SOS")), int(body.get("calls", 1))]
		button.pressed.connect(_use_sos.bind(int(body.get("id", 0))))
		_sos_list.add_child(button)


func _use_sos(npc_id: int) -> void:
	_hold_gag(-4, npc_id)


func _show_tricks() -> void:
	if not _waiting or _sos_list == null:
		return
	_sos_list.visible = true
	for child in _sos_list.get_children():
		_sos_list.remove_child(child)
		child.queue_free()
	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(_reopen_sos)
	_sos_list.add_child(back)
	var names: PackedStringArray = ["Jump", "Beg", "Play Dead", "Rollover", "Backflip", "Dance", "Speak"]
	for trick in names.size():
		var button := Button.new()
		button.text = names[trick]
		button.pressed.connect(_use_doodle.bind(trick))
		_sos_list.add_child(button)


func _reopen_sos() -> void:
	if _sos_list != null:
		_sos_list.visible = false
	_open_sos()


func _use_doodle(trick: int) -> void:
	_hold_gag(-6, trick)


func _use_fire() -> void:
	if _REWARDS.pink_slips() <= 0:
		return
	_hold_gag(-5, -1)


func _hide_sos() -> void:
	if _sos_list != null:
		_sos_list.visible = false


func _paint_rewards(frame: float) -> void:
	var slips := _REWARDS.pink_slips()
	_fire.disabled = slips <= 0
	_fire.modulate = _COMMAND if slips > 0 else _COMMAND_OFF
	var fire_label := _fire.get_child(0) as Label
	if fire_label != null:
		fire_label.text = "FIRE" if slips <= 0 else "FIRE %d" % slips
	var cards := _REWARDS.sos_count()
	var has_pet := preload("res://scenes/pets/doodle_kennel.gd").has_pet()
	var can_call := cards > 0 or has_pet
	_sos.disabled = not can_call
	_sos.modulate = _COMMAND if can_call else _COMMAND_OFF
	if _sos_list == null:
		return
	_sos_list.position = Vector2(_sos.position.x - 196.0, _sos.position.y - 24.0 * frame)
	_sos_list.size = Vector2(188, 180)


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


## Hovering a gag fills this strip with the hit chance and the damage each cog would take.
func _seat_bottom(rect: Rect2) -> void:
	var icon := minf(rect.size.y * 0.46, 28.0)
	_detail_icon.position = rect.position
	_detail_icon.size = Vector2(icon, icon)
	var text := Rect2(rect.position + Vector2(icon + 8.0, 0.0), Vector2(maxf(rect.size.x - icon - 8.0, 1.0), rect.size.y))
	var top_h := 18.0
	var name_w := text.size.x * 0.34
	_fit_line(_detail_name, Rect2(text.position, Vector2(name_w, top_h)), HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, 0.026)
	_fit_line(_detail_amount, Rect2(text.position + Vector2(name_w, 0.0), Vector2(text.size.x * 0.28, top_h)), HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, 0.024)
	_fit_line(_detail_credit, Rect2(text.position + Vector2(text.size.x * 0.64, 0.0), Vector2(text.size.x * 0.36, top_h)), HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_CENTER, 0.022)
	_fit_line(_detail_data, Rect2(text.position + Vector2(0.0, top_h), Vector2(text.size.x, text.size.y - top_h)), HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, 0.022)
	_detail_data.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fit_line(_total, rect, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, 0.03)


func _card_rect(card: Control, x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(card.position + Vector2(card.size.x * x, card.size.y * y), Vector2(card.size.x * w, card.size.y * h))


func _fit_line(label: Label, rect: Rect2, horizontal: HorizontalAlignment, vertical: VerticalAlignment, scale: float) -> void:
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = horizontal
	label.vertical_alignment = vertical
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.add_theme_constant_override("line_spacing", 0)
	var ink := Color(1.0, 0.45, 0.4, 1.0) if label == _detail_credit and _no_credit else Color.WHITE
	ToonGui.style_label(label, ink, _px_of(scale), Color(0.05, 0.08, 0.16), 4)


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
