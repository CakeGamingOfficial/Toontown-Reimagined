class_name BattleMenu
extends Control

## The battle inventory. Tracks sit in their colors, and a gag the toon is
## carrying can be clicked. Pass skips the toon's attack.

signal picked(track: int, level: int)

const _ICONS: Array[Texture2D] = [
	preload("res://assets/gui/tutorial/gags/inventory_feather.png"),
	preload("res://assets/gui/tutorial/gags/inventory_bannana_peel.png"),
	preload("res://assets/gui/tutorial/gags/inventory_1dollarbill.png"),
	preload("res://assets/gui/tutorial/gags/inventory_bikehorn.png"),
	preload("res://assets/gui/tutorial/gags/inventory_tart.png"),
	preload("res://assets/gui/tutorial/gags/inventory_squirt_flower.png"),
	preload("res://assets/gui/tutorial/gags/inventory_flower_pot.png"),
]

var _loadout: ToonLoadout
var _panel: Panel
var _rows: Control
var _note: Label
var _pad_title: Label
var _pad_body: Label
var _waiting := false


func setup(loadout: ToonLoadout) -> void:
	_loadout = loadout
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = Panel.new()
	_panel.mouse_filter = MOUSE_FILTER_STOP
	_panel.size = Vector2(880, 372)
	_panel.add_theme_stylebox_override("panel", _box(Color(0.82, 0.09, 0.12), Color(0.55, 0.02, 0.05), 10, 22))
	add_child(_panel)
	_rows = Control.new()
	_rows.mouse_filter = MOUSE_FILTER_IGNORE
	_rows.position = Vector2(16, 16)
	_rows.size = Vector2(620, 340)
	_panel.add_child(_rows)
	var pad := Panel.new()
	pad.position = Vector2(648, 18)
	pad.size = Vector2(212, 250)
	pad.mouse_filter = MOUSE_FILTER_IGNORE
	pad.add_theme_stylebox_override("panel", _box(Color(1.0, 0.98, 0.86), Color(0.75, 0.62, 0.28), 3, 8))
	_panel.add_child(pad)
	_pad_title = Label.new()
	_pad_title.position = Vector2(12, 14)
	_pad_title.size = Vector2(188, 36)
	_pad_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pad_title.mouse_filter = MOUSE_FILTER_IGNORE
	pad.add_child(_pad_title)
	_pad_body = Label.new()
	_pad_body.position = Vector2(12, 52)
	_pad_body.size = Vector2(188, 184)
	_pad_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pad_body.mouse_filter = MOUSE_FILTER_IGNORE
	pad.add_child(_pad_body)
	ToonGui.style_label(_pad_title, Color(0.15, 0.1, 0.08), 20, Color(0, 0, 0, 0), 0)
	ToonGui.style_label(_pad_body, Color(0.12, 0.12, 0.14), 16, Color(0, 0, 0, 0), 0)
	var pass_button := Button.new()
	pass_button.text = "Pass"
	pass_button.focus_mode = Control.FOCUS_NONE
	pass_button.position = Vector2(648, 286)
	pass_button.size = Vector2(212, 48)
	_paint_button(pass_button, Color(0.28, 0.28, 0.32))
	pass_button.pressed.connect(_pass)
	_panel.add_child(pass_button)
	_note = Label.new()
	_note.text = "Click a gag\nto attack"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.mouse_filter = MOUSE_FILTER_IGNORE
	_note.position = Vector2(250, 70)
	_note.size = Vector2(280, 200)
	var note_panel := Panel.new()
	note_panel.mouse_filter = MOUSE_FILTER_IGNORE
	note_panel.position = _note.position
	note_panel.size = _note.size
	note_panel.add_theme_stylebox_override("panel", _box(Color(1.0, 0.97, 0.62), Color(0.55, 0.48, 0.12), 4, 10))
	_panel.add_child(note_panel)
	_note.position = Vector2.ZERO
	_note.size = note_panel.size
	note_panel.add_child(_note)
	ToonGui.style_title(_note, Color(0.08, 0.08, 0.1), 36)
	_show_total()


func choose() -> Vector2i:
	_waiting = true
	_rebuild()
	_fit()
	visible = true
	mouse_filter = MOUSE_FILTER_STOP
	var result: Array = await picked
	_waiting = false
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	return Vector2i(int(result[0]), int(result[1]))


func _rebuild() -> void:
	for child in _rows.get_children():
		child.free()
	if _loadout == null:
		return
	for track in ToonLoadout.TRACK_COUNT:
		var row := Control.new()
		row.mouse_filter = MOUSE_FILTER_IGNORE
		row.position = Vector2(0, track * 48)
		row.size = Vector2(620, 46)
		_rows.add_child(row)
		var title := Label.new()
		title.text = ToonLoadout.TRACK_NAMES[track].to_upper()
		title.position = Vector2(4, 4)
		title.size = Vector2(118, 22)
		title.mouse_filter = MOUSE_FILTER_IGNORE
		ToonGui.style_label(title, Color(0.1, 0.1, 0.12), 15, Color(1, 1, 1, 0.35), 1)
		row.add_child(title)
		var owned_track := false
		for level in ToonLoadout.LEVEL_COUNT:
			if _loadout.unlocked(track, level):
				owned_track = true
				break
		if owned_track:
			var exp := _loadout.experience_of(track)
			var next := maxi(_loadout.next_skill(track), 1)
			var bar := ColorRect.new()
			bar.color = Color(0.15, 0.15, 0.18, 0.35)
			bar.position = Vector2(4, 26)
			bar.size = Vector2(108, 12)
			bar.mouse_filter = MOUSE_FILTER_IGNORE
			row.add_child(bar)
			var fill := ColorRect.new()
			fill.color = ToonLoadout.TRACK_COLORS[track]
			fill.position = Vector2(4, 26)
			fill.size = Vector2(108.0 * clampf(float(exp) / float(next), 0.0, 1.0), 12)
			fill.mouse_filter = MOUSE_FILTER_IGNORE
			row.add_child(fill)
			var exp_label := Label.new()
			exp_label.text = "%d/%d" % [exp, next]
			exp_label.position = Vector2(4, 22)
			exp_label.size = Vector2(108, 16)
			exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			exp_label.mouse_filter = MOUSE_FILTER_IGNORE
			ToonGui.style_label(exp_label, Color.WHITE, 11, Color(0, 0, 0), 1)
			row.add_child(exp_label)
		for level in ToonLoadout.LEVEL_COUNT:
			var color := ToonLoadout.TRACK_COLORS[track]
			var slot_pos := Vector2(132 + level * 68, 4)
			if not _loadout.unlocked(track, level):
				var empty := Panel.new()
				empty.position = slot_pos
				empty.size = Vector2(62, 38)
				empty.mouse_filter = MOUSE_FILTER_IGNORE
				empty.add_theme_stylebox_override("panel", _box(color.darkened(0.18), color.darkened(0.4), 2, 8))
				row.add_child(empty)
				continue
			var button := Button.new()
			button.focus_mode = Control.FOCUS_NONE
			button.text = ""
			button.position = slot_pos
			button.size = Vector2(62, 38)
			button.disabled = _loadout.count_of(track, level) <= 0
			_paint_button(button, color)
			button.mouse_entered.connect(_show_detail.bind(track, level))
			button.mouse_exited.connect(_show_total)
			button.pressed.connect(_pick.bind(track, level))
			row.add_child(button)
			var icon := TextureRect.new()
			icon.texture = _ICONS[track]
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = MOUSE_FILTER_IGNORE
			icon.position = Vector2(6, 2)
			icon.size = Vector2(34, 28)
			button.add_child(icon)
			var badge := Label.new()
			badge.text = str(_loadout.count_of(track, level))
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			badge.mouse_filter = MOUSE_FILTER_IGNORE
			badge.position = Vector2(36, 18)
			badge.size = Vector2(22, 16)
			ToonGui.style_label(badge, Color.WHITE, 12, Color(0.05, 0.2, 0.45), 2)
			button.add_child(badge)
	_show_total()


func _fit() -> void:
	var view := get_viewport_rect().size
	var fit := minf((view.x - 40.0) / _panel.size.x, (view.y * 0.56) / _panel.size.y)
	fit = minf(fit, 1.0)
	_panel.scale = Vector2(fit, fit)
	_panel.position = Vector2((view.x - _panel.size.x * fit) * 0.5, view.y - _panel.size.y * fit - 12.0)


func _pick(track: int, level: int) -> void:
	if not _waiting or _loadout == null or _loadout.count_of(track, level) <= 0:
		return
	_waiting = false
	picked.emit(track, level)


func _pass() -> void:
	if not _waiting:
		return
	_waiting = false
	picked.emit(-1, -1)


func _show_detail(track: int, level: int) -> void:
	if _loadout == null:
		return
	var exp := _loadout.experience_of(track)
	var damage := ToonLoadout.gag_damage(track, level, exp)
	var accuracy := _loadout.rolled_accuracy(track, level)
	_pad_title.text = _loadout.gag_name(track, level)
	_pad_body.text = "%d / %d\nAccuracy: %s\nDamage: %d\nAffects: %s\nSkill Credit: %d" % [
		_loadout.count_of(track, level),
		ToonLoadout.POCKET,
		ToonLoadout.accuracy_word(accuracy),
		damage,
		ToonLoadout.affects_label(track),
		ToonLoadout.SKILL_CREDIT,
	]


func _show_total() -> void:
	var carried := 0
	if _loadout != null:
		carried = _loadout.gag_count()
	_pad_title.text = "Total gags"
	_pad_body.text = "%d / %d" % [carried, 20]


func _paint_button(button: Button, color: Color) -> void:
	button.add_theme_stylebox_override("normal", _box(color, color.darkened(0.35), 2, 8))
	button.add_theme_stylebox_override("hover", _box(color.lightened(0.12), color.darkened(0.2), 2, 8))
	button.add_theme_stylebox_override("pressed", _box(color.darkened(0.12), color.darkened(0.4), 2, 8))
	button.add_theme_stylebox_override("disabled", _box(color.darkened(0.35), color.darkened(0.5), 2, 8))
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_font_override("font", ToonGui.font())
	button.add_theme_font_size_override("font_size", 18)


func _box(fill: Color, edge: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	return box
