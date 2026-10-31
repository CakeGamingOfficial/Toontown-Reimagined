class_name MinigameBoard
extends Control

## Original minigame score displays, placed in aspect2d the way DirectGui did.
## One aspect unit is half the viewport height. x is divided by the aspect ratio.

const _DIALOG := preload("res://assets/gui/minigames/dialog_box.png")
const _JAR := preload("res://assets/gui/purchase/Jar.png")
## dialog_box_gui geom, measured from the exported tight bounds.
const _DIALOG_W := 1.1122
const _DIALOG_H := 1.1861
const _CREAM := Color(1, 1, 0.75, 1)
const _YELLOW := Color(0.95, 0.95, 0, 1)
const _ALIGN_LEFT := 0
const _ALIGN_CENTER := 1
const _ALIGN_RIGHT := 2
const _RINGS := 16

var kind := ""
var _shown := 0
var _panel_scale := 1.0
var _origin := Vector2.ZERO
var _alpha := 1.0
var _head_h := 3.21496
var _power := 8.0
var _target := 8.0
var _flip_tint := Color(0, 1, 0, 1)
var _results: Array[int] = []
var _throb: Tween

var _card: TextureRect
var _extra_card: TextureRect
var _jar_root: Control
var _name: Label
var _number: Label
var _title: Label
var _flips: Label
var _slow: Label
var _fast: Label
var _banner: Label
var _meter: LaffMeter
var _fill: ColorRect
var _white_tick: ColorRect
var _red_tick: ColorRect
var _marks: Array[Label] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := get_viewport()
	if not view.size_changed.is_connected(relayout):
		view.size_changed.connect(relayout)


func open(which: String) -> void:
	kind = which
	if kind == "avatar" or kind == "maze":
		_build_avatar()
	elif kind == "jar":
		_build_jar()
	elif kind == "treasure":
		_build_treasure()
	elif kind == "points":
		_build_points()
	elif kind == "ring":
		_build_ring()
	elif kind == "power":
		_build_power()
	elif kind == "slingshot":
		_build_slingshot()
	relayout()


func relayout() -> void:
	if kind == "avatar" or kind == "maze":
		_layout_avatar()
	elif kind == "jar":
		_layout_jar()
	elif kind == "treasure":
		_layout_treasure()
	elif kind == "points":
		_layout_points()
	elif kind == "ring":
		_layout_ring()
	elif kind == "power":
		_layout_power()
	elif kind == "slingshot":
		_layout_slingshot()


## Sets the digits without the jar throb. begin() uses this for the opening value.
func prime(points: int) -> void:
	_shown = points
	_paint_number()


func sync(points: int) -> void:
	if kind == "power" or kind == "ring":
		return
	if points == _shown:
		return
	_shown = points
	_paint_number()
	if kind == "jar":
		_pulse_jar()


func mark_ring(index: int, success: bool) -> void:
	if index < 0 or index >= _results.size():
		return
	_results[index] = 1 if success else 2
	relayout()


## RingGamePerfect. Holds 1.5s, then fades for 0.5s.
func perfect() -> void:
	if _banner == null:
		return
	_banner.visible = true
	_banner.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.5)


func set_power(power: float, target: float) -> void:
	_power = clampf(power, 0.0, 17.0)
	_target = target
	var slow := _power < _target - 2.0
	if _slow != null:
		_slow.visible = slow
	if _fast != null:
		_fast.visible = not slow and _power > _target + 2.0
	_paint_gauge()


func note_flip(flips: int, matches: int) -> void:
	if _flips == null:
		return
	_flips.text = str(flips)
	_flip_tint = _flip_color(matches, flips)
	_flips.add_theme_color_override("font_color", _flip_tint)


func show_round(round_number: int, points: int, shown: bool) -> void:
	_shown = points
	if _title != null:
		_title.text = "Round %d - Keeping Best Score" % round_number
	_paint_number()
	visible = shown
	relayout()


func _build_avatar() -> void:
	_panel_scale = 0.9 if kind == "avatar" else 1.0
	_alpha = 0.75 if kind == "avatar" else 1.0
	_origin = Vector2(0.75, 0.85) if kind == "avatar" else Vector2(1.12, 0.5)
	_card = _make_card(_alpha)
	var style := ToonRoster.selected_style()
	_head_h = _head_height(style)
	_name = _make_label(_toon_name(style))
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_number = _make_label("0")
	_meter = LaffMeter.new()
	_meter.setup(style)
	var loadout := ToonLoadout.for_selected()
	if loadout != null:
		_meter.set_hp(loadout.hp, loadout.max_hp, true)
	add_child(_meter)


func _build_jar() -> void:
	_jar_root = Control.new()
	_jar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_jar_root)
	_card = _make_card(1.0, _jar_root)
	_card.texture = _JAR
	_card.modulate = Color.WHITE
	_title = _make_label("REWARD", _jar_root)
	_number = _make_label("", _jar_root)


func _build_treasure() -> void:
	_alpha = 0.7
	_card = _make_card(_alpha)
	_title = _make_label("Treasures Retrieved")
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_number = _make_label("0")


func _build_points() -> void:
	_card = _make_card(1.0)
	_extra_card = _make_card(1.0)
	_title = _make_label("Points:")
	_number = _make_label("0")
	_name = _make_label("Flips:")
	_flips = _make_label("0")


func _build_ring() -> void:
	for _index in _RINGS:
		_results.append(0)
		_marks.append(_make_label("-"))
	_banner = _make_label("PERFECT!")
	_banner.visible = false


func _build_power() -> void:
	_card = _make_card(1.0)
	_title = _make_label("Power Meter")
	_slow = _make_label("Too\nslow")
	_fast = _make_label("Too\nfast")
	_slow.visible = false
	_fast.visible = false
	_fill = _make_bar(Color(0, 1, 0, 0.6))
	_white_tick = _make_bar(Color(1, 1, 1, 1))
	_red_tick = _make_bar(Color(1, 0, 0, 1))


func _build_slingshot() -> void:
	_card = _make_card(1.0)
	_title = _make_label("Round 1 - Keeping Best Score")
	_name = _make_label(_toon_name(ToonRoster.selected_style()))
	_number = _make_label("0")


func _layout_avatar() -> void:
	# makeTransparent tints the name, the digits, and the Laff meter with the card.
	modulate = Color(1, 1, 1, _alpha)
	var width := _DIALOG_W * 0.4 * _panel_scale
	var height := _DIALOG_H * 0.24 * _panel_scale
	_place_card(_card, _origin.x, _origin.y, width, height, 1.0)
	var name_scale := 0.055 * _panel_scale
	_style_ui(_name, Color.BLACK, name_scale, Color(1, 1, 1, 1), 1)
	_put(_name, _origin.x, _origin.y + 0.06 * _panel_scale, name_scale, _ALIGN_CENTER, 7.5 * name_scale)
	var score_scale := 0.1 * _panel_scale
	_style_ui(_number, Color.BLACK, score_scale, Color(0, 0, 0, 0), 0)
	_put(_number, _origin.x + 0.1 * _panel_scale, _origin.y - 0.09 * _panel_scale, score_scale, _ALIGN_CENTER, 0.22 * _panel_scale)
	if _meter != null:
		var spot := _anchor(_origin.x - 0.085 * _panel_scale, _origin.y - 0.035 * _panel_scale)
		_meter.place(spot, _aspect_px(_head_h * 0.05 * _panel_scale))


func _layout_jar() -> void:
	if _jar_root == null:
		return
	var box := _rect(1.16, 0.45, 0.4333 * 0.65, 0.5292 * 0.65)
	_jar_root.position = box.position
	_jar_root.size = box.size
	_jar_root.pivot_offset = box.size * 0.5
	_card.position = Vector2.ZERO
	_card.size = box.size
	var title_px := _px(0.08 * 0.65)
	ToonGui.style_sign(_title, _YELLOW, title_px, Color(0, 0, 0, 1), maxi(int(round(float(title_px) * 0.12)), 1))
	_put_local(_title, box.size, 0.0, 0.06, 0.65, 0.08 * 0.65, _ALIGN_CENTER, box.size.x)
	ToonGui.style_sign(_number, _YELLOW, _px(0.2 * 0.65), Color(0, 0, 0, 0), 0)
	_put_local(_number, box.size, 0.0, -0.13, 0.65, 0.2 * 0.65, _ALIGN_CENTER, box.size.x)


func _layout_treasure() -> void:
	modulate = Color(1, 1, 1, _alpha)
	_place_card(_card, -1.19, 0.75, _DIALOG_W * 0.24, _DIALOG_H * 0.24, 1.0)
	_style_ui(_title, Color.BLACK, 0.05, Color(1, 1, 1, 1), 1)
	_put(_title, -1.19, 0.81, 0.05, _ALIGN_CENTER, 7.5 * 0.05)
	_style_ui(_number, Color.BLACK, 0.08, Color(0, 0, 0, 0), 0)
	_put(_number, -1.19, 0.66, 0.08, _ALIGN_CENTER, 0.2)


func _layout_points() -> void:
	var width := _DIALOG_W * 0.4
	var height := _DIALOG_H * 0.1
	_place_card(_card, -0.33, 0.9, width, height, 1.0)
	_place_card(_extra_card, 0.33, 0.9, width, height, 1.0)
	_style_ui(_title, Color.BLACK, 0.07, Color(0, 0, 0, 0), 0)
	_put(_title, -0.524, 0.89, 0.07, _ALIGN_LEFT, 0.28)
	_style_ui(_number, Color(0, 0.5, 0, 1), 0.07, Color(0, 0, 0, 0), 0)
	_put(_number, -0.148, 0.885, 0.07, _ALIGN_RIGHT, 0.16)
	_style_ui(_name, Color.BLACK, 0.07, Color(0, 0, 0, 0), 0)
	_put(_name, 0.136, 0.89, 0.07, _ALIGN_LEFT, 0.22)
	_style_ui(_flips, _flip_tint, 0.07, Color(0, 0, 0, 0), 0)
	_put(_flips, 0.512, 0.885, 0.07, _ALIGN_RIGHT, 0.16)


func _layout_ring() -> void:
	for index in _marks.size():
		var result := _results[index]
		var mark := _marks[index]
		mark.text = _mark_char(result)
		var lifted := -0.915 if result == 0 else -0.93
		ToonGui.style_sign(mark, _mark_color(result), _px(0.1), Color(0, 0, 0, 0), 0)
		_put(mark, -1.0 + 0.085 * float(index), lifted, 0.1, _ALIGN_CENTER, 0.08)
	if _banner != null:
		ToonGui.style_sign(_banner, Color(1, 1, 0.5, 1), _px(0.25), Color(0, 0, 0, 0), 0)
		_put(_banner, 0.0, 0.0, 0.25, _ALIGN_CENTER, 1.4)


func _layout_power() -> void:
	_place_card(_card, 0.0, 0.4, _DIALOG_W * 0.48, _DIALOG_H * 0.7, 1.0)
	_style_ui(_title, Color.BLACK, 0.07, Color(0, 0, 0, 0), 0)
	_put(_title, 0.01, 0.69, 0.07, _ALIGN_CENTER, 0.5)
	var blue := Color(0.1, 0.3, 0.6, 1)
	_style_ui(_slow, blue, 0.07, Color(0, 0, 0, 0), 0)
	_put(_slow, -0.15, 0.45, 0.07, _ALIGN_CENTER, 0.16)
	_style_ui(_fast, blue, 0.07, Color(0, 0, 0, 0), 0)
	_put(_fast, 0.15, 0.45, 0.07, _ALIGN_CENTER, 0.16)
	_paint_gauge()


func _layout_slingshot() -> void:
	_place_card(_card, 0.0, 0.587, _DIALOG_W * 1.75, _DIALOG_H * 0.75, 1.0)
	_style_ui(_title, Color.BLACK, 0.08, Color(0, 0, 0, 0), 0)
	_put(_title, 0.0, 0.867, 0.08, _ALIGN_CENTER, 1.6)
	_style_ui(_name, Color.BLACK, 0.08, Color(0, 0, 0, 0), 0)
	_put(_name, -0.8, 0.727, 0.08, _ALIGN_LEFT, 1.2)
	_style_ui(_number, Color.BLACK, 0.08, Color(0, 0, 0, 0), 0)
	_put(_number, 0.8, 0.727, 0.08, _ALIGN_RIGHT, 0.7)


func _paint_number() -> void:
	if _number == null:
		return
	if kind == "jar" and _shown <= 0:
		_number.text = ""
	else:
		_number.text = str(_shown)


func _pulse_jar() -> void:
	if _jar_root == null:
		return
	if _throb != null and _throb.is_valid():
		_throb.kill()
	_jar_root.pivot_offset = _jar_root.size * 0.5
	_jar_root.scale = Vector2.ONE
	_throb = create_tween()
	_throb.tween_property(_jar_root, "scale", Vector2(0.75, 0.75), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_throb.tween_property(_jar_root, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_reward_tick()


func _reward_tick() -> void:
	var host: Node = self
	while host != null:
		if host.has_method("_sfx"):
			host.call("_sfx", "tick_counter")
			return
		host = host.get_parent()


func _paint_gauge() -> void:
	if _fill == null:
		return
	# WaitBar frameSize (-0.6, 0.6, -0.2, 0.2) at scale 0.35, rolled -90 so it grows upward.
	var slot := _rect(0.0, 0.4, 0.14, 0.42)
	var ratio := clampf(_power / 17.0, 0.0, 1.0)
	var fill_h := slot.size.y * ratio
	_fill.position = Vector2(slot.position.x, slot.position.y + slot.size.y - fill_h)
	_fill.size = Vector2(slot.size.x, maxf(fill_h, 1.0))
	_tick(_white_tick, _target)
	_tick(_red_tick, _target + 1.0)


func _tick(node: ColorRect, value: float) -> void:
	var slot := _rect(0.0, 0.4, 0.14, 0.42)
	var frac := clampf(value / 17.0, 0.0, 1.0)
	var tick := maxf(slot.size.y / 17.0, 2.0)
	var y := slot.position.y + slot.size.y * (1.0 - frac) - tick * 0.5
	node.position = Vector2(slot.position.x - 6.0, y)
	node.size = Vector2(slot.size.x + 12.0, tick)


func _flip_color(matches: int, flips: int) -> Color:
	var ideal := maxi(int(round(float(matches) * 2.0 * 1.6)), 2)
	var cap := ideal * 2
	var modifier := 0.0
	if flips < ideal:
		modifier = 1.0
	elif flips > cap:
		modifier = 0.0
	else:
		modifier = float(cap - flips) / float(maxi(cap - ideal, 1))
	return Color(1.0 - modifier, modifier, 0.0, 1.0)


func _place_card(card: TextureRect, ax: float, az: float, aw: float, ah: float, alpha: float) -> void:
	var box := _rect(ax, az, aw, ah)
	card.position = box.position
	card.size = box.size
	card.modulate = Color(_CREAM.r, _CREAM.g, _CREAM.b, alpha)


func _put(label: Label, ax: float, az: float, font_aspect: float, align: int, width_aspect: float) -> void:
	_apply_anchor(label, _anchor(ax, az), font_aspect, align, _aspect_px(width_aspect))


func _put_local(label: Label, parent_size: Vector2, lx: float, lz: float, node_scale: float, font_aspect: float, align: int, width: float) -> void:
	var anchor := parent_size * 0.5 + _delta_px(lx * node_scale, lz * node_scale)
	_apply_anchor(label, anchor, font_aspect, align, width)


func _apply_anchor(label: Label, anchor: Vector2, font_aspect: float, align: int, width: float) -> void:
	var font_px := _px(font_aspect)
	var lines := maxi(label.text.split("\n").size(), 1)
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		lines = maxi(lines, 2)
	var height := float(font_px) * 1.35 * float(lines)
	var origin := anchor
	if align == _ALIGN_CENTER:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		origin = anchor - Vector2(width * 0.5, height * 0.5)
	elif align == _ALIGN_RIGHT:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		origin = anchor - Vector2(width, height * 0.5)
	else:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		origin = anchor - Vector2(0.0, height * 0.5)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = origin
	label.size = Vector2(maxf(width, 1.0), height)


func _make_card(alpha: float, parent: Node = null) -> TextureRect:
	var card := TextureRect.new()
	card.texture = _DIALOG
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.modulate = Color(_CREAM.r, _CREAM.g, _CREAM.b, alpha)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(card)
	return card


func _make_label(text: String, parent: Node = null) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(label)
	return label


func _make_bar(color: Color) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	return bar


func _style_ui(label: Label, color: Color, font_aspect: float, outline: Color, outline_px: int) -> void:
	ToonGui.style_label(label, color, _px(font_aspect), outline, outline_px)


func _rect(ax: float, az: float, aw: float, ah: float) -> Rect2:
	var size := Vector2(_aspect_px(aw), _aspect_px(ah))
	return Rect2(_anchor(ax, az) - size * 0.5, size)


func _anchor(ax: float, az: float) -> Vector2:
	var view := get_viewport().get_visible_rect().size
	var aspect := view.x / maxf(view.y, 1.0)
	return Vector2((ax / aspect + 1.0) * 0.5 * view.x, (1.0 - az) * 0.5 * view.y)


func _delta_px(dx: float, dz: float) -> Vector2:
	var view := get_viewport().get_visible_rect().size
	var aspect := view.x / maxf(view.y, 1.0)
	var unit := view.y * 0.5
	return Vector2(dx / aspect * unit, -dz * unit)


func _aspect_px(amount: float) -> float:
	return amount * get_viewport().get_visible_rect().size.y * 0.5


func _px(aspect_height: float) -> int:
	return maxi(int(round(aspect_height * get_viewport().get_visible_rect().size.y * 0.5)), 8)


func _toon_name(style: ToonStyle) -> String:
	if style == null:
		return "Toon"
	var called := style.display_name()
	if called == "":
		return "Toon"
	return called


func _head_height(style: ToonStyle) -> float:
	if style != null and style.species() in ["p", "b", "s"]:
		return 3.5669
	return 3.21496


func _mark_char(result: int) -> String:
	if result == 1:
		return "O"
	if result == 2:
		return "X"
	return "-"


func _mark_color(result: int) -> Color:
	if result == 1:
		return Color(0, 1, 0, 1)
	if result == 2:
		return Color(1, 0, 0, 1)
	return Color(0.8, 0.8, 0.8, 1)
