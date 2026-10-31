class_name GagPanel
extends Control

## InventoryNew, the way quest_assign_101 shows it. The inventory is parented
## to the camera at (-0.77, 7.42, 1.11) and scaled to (3, 0.01, 3). Detail
## text stays hidden (SET_INVENTORY_DETAIL -1). Empty wells stay on the row.
## A gag Tom has handed over shows its icon and count.

const _ROW := preload("res://assets/gui/tutorial/InventoryRow.png")
const _BUTTON := preload("res://assets/gui/tutorial/InventoryButtonUp.png")
const _CUPCAKE := preload("res://assets/gui/tutorial/gags/inventory_tart.png")
const _FLOWER := preload("res://assets/gui/tutorial/gags/inventory_squirt_flower.png")

const _CAM_X := -0.77
const _CAM_Y := 7.42
const _CAM_Z := 1.11
const _INV_SCALE := 3.0
const _ROW_W := 1.6667
const _ROW_H := 0.1252
const _ROW_Z := 1.1
const _PITCH := 0.12
# InventoryNew parents these to the row, then the row's z scale stretches them.
const _NAME_X := -0.785
const _NAME_Z := 0.01
const _NAME_SCALE := 0.05
const _BAR_X := -0.645
const _BAR_Z := -0.025
const _BAR_SCALE := 0.25
const _BAR_TEXT_Z := -0.05
const _BAR_TEXT_SCALE := 0.16
const _COUNT_X := 0.07
const _COUNT_Z := -0.04
const _COUNT_SCALE := 0.04

var _loadout: ToonLoadout
var _rows: Array[TextureRect] = []
var _names: Array[Label] = []
var _bars: Array[ColorRect] = []
var _fills: Array[ColorRect] = []
var _skills: Array[Label] = []
var _slots: Array[TextureRect] = []
var _icons: Array[TextureRect] = []
var _counts: Array[Label] = []


func setup(loadout: ToonLoadout) -> void:
	_loadout = loadout
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false
	for track in ToonLoadout.TRACK_COUNT:
		var row := TextureRect.new()
		row.texture = _ROW
		row.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.stretch_mode = TextureRect.STRETCH_SCALE
		row.mouse_filter = MOUSE_FILTER_IGNORE
		row.modulate = ToonLoadout.TRACK_COLORS[track]
		add_child(row)
		_rows.append(row)
		var name := Label.new()
		name.text = ToonLoadout.TRACK_NAMES[track].to_upper()
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.mouse_filter = MOUSE_FILTER_IGNORE
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
		var skill := Label.new()
		skill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		skill.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(skill)
		_skills.append(skill)
		for level in ToonLoadout.LEVEL_COUNT:
			var slot := TextureRect.new()
			slot.texture = _BUTTON
			slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			slot.stretch_mode = TextureRect.STRETCH_SCALE
			slot.mouse_filter = MOUSE_FILTER_IGNORE
			slot.modulate = ToonLoadout.TRACK_COLORS[track]
			add_child(slot)
			_slots.append(slot)
			var icon := TextureRect.new()
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = MOUSE_FILTER_IGNORE
			add_child(icon)
			_icons.append(icon)
			var number := Label.new()
			number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			number.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			number.mouse_filter = MOUSE_FILTER_IGNORE
			add_child(number)
			_counts.append(number)


## Grow from the inventory origin. 0.01 is the quest's starting scale; 3 is
## the scale it finishes at.
func opening_scale() -> float:
	return 0.01 / _INV_SCALE


func layout_quest(view: Vector2) -> void:
	position = Vector2.ZERO
	size = view
	var span := _span(view)
	pivot_offset = _pixel(view, _CAM_X * span, _CAM_Z * span)
	var row_w := _ROW_W * _INV_SCALE * span
	var row_h := _ROW_H * _INV_SCALE * span
	for track in ToonLoadout.TRACK_COUNT:
		var ax := _CAM_X * span
		var az := (_CAM_Z - float(track) * _PITCH * _INV_SCALE) * span
		ToonGui.place(_rows[track], view, ax, az, row_w, row_h)
		var name := _names[track]
		var name_px := _px(view, _NAME_SCALE)
		ToonGui.style_label(name, Color(0.2, 0.2, 0.2), name_px, Color(0, 0, 0, 0), 0)
		# ALeft. The anchor is the left end of the baseline, just above the bar.
		_place_line(name, _row_point(view, span, az, _NAME_X, _NAME_Z * _ROW_Z), _pixel_span(view, 0.45 * _INV_SCALE * span), name_px, HORIZONTAL_ALIGNMENT_LEFT)
		# frameSize (-0.6, 0.6, -0.1, 0.1) at scale 0.25, then the row stretches z.
		var bar_size := Vector2(_pixel_span(view, 1.2 * _BAR_SCALE * _INV_SCALE * span), _pixel_span(view, 0.2 * _BAR_SCALE * _ROW_Z * _INV_SCALE * span))
		var bar_at := _row_point(view, span, az, _BAR_X, _BAR_Z * _ROW_Z)
		_bars[track].position = bar_at - bar_size * 0.5
		_bars[track].size = bar_size
		var skill_px := _px(view, _BAR_TEXT_SCALE * _BAR_SCALE)
		ToonGui.style_label(_skills[track], Color(0, 0, 0, 0.8), skill_px, Color(0, 0, 0, 0), 0)
		# ACenter. text_pos (0, -0.05) is inside the bar, before the bar's own scale.
		var skill_at := _row_point(view, span, az, _BAR_X, (_BAR_Z + _BAR_TEXT_Z * _BAR_SCALE) * _ROW_Z)
		_place_line(_skills[track], skill_at, bar_size.x, skill_px, HORIZONTAL_ALIGNMENT_CENTER)
		for level in ToonLoadout.LEVEL_COUNT:
			var index := track * ToonLoadout.LEVEL_COUNT + level
			var local_x := -0.375 + float(level) * 0.18
			var center := _row_point(view, span, az, local_x, 0.0)
			var well := Vector2(_pixel_span(view, 0.1804 * _INV_SCALE * span), _pixel_span(view, 0.1137 * _ROW_Z * _INV_SCALE * span))
			_slots[index].position = center - well * 0.5
			_slots[index].size = well
			var icon := well * 0.7
			_icons[index].position = center + Vector2(_pixel_span(view, -0.01 * _INV_SCALE * span), 0.0) - icon * 0.5
			_icons[index].size = icon
			var count_px := _px(view, _COUNT_SCALE)
			ToonGui.style_label(_counts[index], Color.WHITE, count_px, Color(0.05, 0.12, 0.28), 2)
			# ARight. text_pos (0.07, -0.04) is the right end of the baseline.
			var count_at := _row_point(view, span, az, local_x + _COUNT_X, _COUNT_Z * _ROW_Z)
			_place_line(_counts[index], count_at, _pixel_span(view, 0.14 * _INV_SCALE * span), count_px, HORIZONTAL_ALIGNMENT_RIGHT)
	refresh()


func refresh() -> void:
	if _loadout == null:
		return
	for track in ToonLoadout.TRACK_COUNT:
		var current := _loadout.experience_of(track)
		var nxt := maxi(_loadout.next_skill(track), 1)
		var ratio := clampf(float(current) / float(nxt), 0.0, 1.0)
		_skills[track].text = "%d / %d" % [current, nxt]
		var back := _bars[track]
		_fills[track].position = back.position
		_fills[track].size = Vector2(back.size.x * ratio, back.size.y)
		for level in ToonLoadout.LEVEL_COUNT:
			var index := track * ToonLoadout.LEVEL_COUNT + level
			var owned := _loadout.unlocked(track, level)
			_slots[index].visible = owned
			_icons[index].visible = owned
			_counts[index].visible = owned
			if owned:
				_icons[index].texture = _icon_for(track, level)
				_counts[index].text = str(_loadout.count_of(track, level))


func slot_center(track: int, level: int) -> Vector2:
	var slot := _slots[track * ToonLoadout.LEVEL_COUNT + level]
	return slot.get_global_rect().get_center()


## A point on the row, in camera aspect units. local_z already includes the
## row's z scale of 1.1. local_x does not, because that scale is 1.
func _row_point(view: Vector2, span: float, row_z: float, local_x: float, local_z: float) -> Vector2:
	return _pixel(view, (_CAM_X + local_x * _INV_SCALE) * span, row_z + local_z * _INV_SCALE * span)


## Panda's TextNode anchor is the baseline. Top alignment plus the font ascent
## puts that baseline on `anchor`. The row then stretches the glyphs in z.
func _place_line(label: Label, anchor: Vector2, width: float, px: int, align: HorizontalAlignment) -> void:
	var font := ToonGui.font()
	var ascent := font.get_ascent(px)
	var descent := absf(font.get_descent(px))
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.clip_text = false
	var pivot_x := 0.0
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		pivot_x = width * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		pivot_x = width
	label.pivot_offset = Vector2(pivot_x, ascent)
	label.scale = Vector2(1.0, _ROW_Z)
	label.position = anchor - label.pivot_offset
	label.size = Vector2(width, ascent + descent + 1.0)


func _span(view: Vector2) -> float:
	# Horizontal fov is 52. One aspect unit is half the screen height.
	var aspect := view.x / maxf(view.y, 1.0)
	return aspect / (_CAM_Y * tan(deg_to_rad(26.0)))


func _pixel(view: Vector2, ax: float, az: float) -> Vector2:
	var unit := view.y * 0.5
	return Vector2(view.x * 0.5 + ax * unit, view.y * 0.5 - az * unit)


func _pixel_span(view: Vector2, amount: float) -> float:
	return amount * view.y * 0.5


func _px(view: Vector2, local_scale: float) -> int:
	return maxi(int(round(local_scale * _INV_SCALE * _span(view) * view.y * 0.5)), 8)


func _icon_for(track: int, level: int) -> Texture2D:
	if track == ToonLoadout.THROW and level == 0:
		return _CUPCAKE
	if track == ToonLoadout.SQUIRT and level == 0:
		return _FLOWER
	return null
