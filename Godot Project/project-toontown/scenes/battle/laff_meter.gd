class_name LaffMeter
extends Control

## LaffMeter.py drawn with the original laff_o_meter cards. Full Laff smiles.
## Anything less opens the mouth and drops teeth from the right. Empty Laff
## turns the head green and sad.
##
## The cards keep the vertex rectangles from laff_o_meter.egg. Each number is
## centered on its eye, and the meter sits 19.6 pixels in from the corner.

const _HEADS := {
	"d": preload("res://assets/gui/tutorial/laff/doghead.png"),
	"c": preload("res://assets/gui/tutorial/laff/cathead.png"),
	"h": preload("res://assets/gui/tutorial/laff/horsehead.png"),
	"m": preload("res://assets/gui/tutorial/laff/mousehead.png"),
	"r": preload("res://assets/gui/tutorial/laff/bunnyhead.png"),
	"f": preload("res://assets/gui/tutorial/laff/duckhead.png"),
	"p": preload("res://assets/gui/tutorial/laff/monkeyhead.png"),
	"b": preload("res://assets/gui/tutorial/laff/bearhead.png"),
	"s": preload("res://assets/gui/tutorial/laff/pighead.png"),
}
const _SMILE := preload("res://assets/gui/tutorial/laff/smile.png")
const _FROWN := preload("res://assets/gui/tutorial/laff/frown.png")
const _OPEN := preload("res://assets/gui/tutorial/laff/open_smile.png")
const _EYES := preload("res://assets/gui/tutorial/laff/eyes.png")
const _TEETH: Array[Texture2D] = [
	preload("res://assets/gui/tutorial/laff/tooth_6.png"),
	preload("res://assets/gui/tutorial/laff/tooth_5.png"),
	preload("res://assets/gui/tutorial/laff/tooth_4.png"),
	preload("res://assets/gui/tutorial/laff/tooth_3.png"),
	preload("res://assets/gui/tutorial/laff/tooth_2.png"),
	preload("res://assets/gui/tutorial/laff/tooth_1.png"),
]
const _FRACTIONS: Array[float] = [0.0, 0.166666, 0.333333, 0.5, 0.666666, 0.833333]
const _SAD := Color(0.58039216, 0.80392157, 0.34117647)
## min x, min z, max x, max z. Dog, cat, horse, mouse, rabbit, and duck share
## one card. Monkey, bear, and pig share the wider card.
const _SQUARE_HEAD := Vector4(-1.71498, -1.71498, 1.5, 1.5)
const _WIDE_HEAD := Vector4(-2.02808, -1.82995, 2.04846, 1.73695)
const _MOUTH := Vector4(-1.5, -1.5, 1.5, 1.5)
const _EYE_CARD := Vector4(-1.04104, -0.293395, 1.04104, 0.693395)
const _TOOTH_BOUNDS: Array[Vector4] = [
	Vector4(-1.36317, -0.712279, -0.656499, 0.06826),
	Vector4(-1.21054, -1.04491, -0.347075, -0.184814),
	Vector4(-0.864194, -1.31928, -0.025596, -0.289792),
	Vector4(-0.034041, -1.28894, 0.616662, -0.32829),
	Vector4(0.212533, -1.14669, 1.076, -0.286587),
	Vector4(0.62354, -0.814828, 1.33021, -0.034288),
]
## Centers of the two white eyes in laff_o_meter, in the head's model space.
const _HP_EYE := Vector2(-0.4065, 0.203)
const _MAX_EYE := Vector2(0.4483, 0.203)
const _TEXT_SCALE := 0.48
## Impress BT digits are this fraction of the font size above the baseline.
const _INK_ABOVE := 0.34
## Half of the previous 19.6-pixel corner gap.
const _SCREEN_MARGIN := 9.8

var _head: TextureRect
var _face: TextureRect
var _eyes: Control
var _whites: TextureRect
var _hp_label: Label
var _max_label: Label
var _teeth: Array[TextureRect] = []
var _fur := Color.WHITE
var _head_card := _SQUARE_HEAD
var _hp := 15
var _max_hp := 15
var _followed: ToonLoadout
var _boing: Tween
var _boing_ready := false


func setup(style: ToonStyle) -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var species := "d"
	_fur = Color(0.996, 0.695, 0.512)
	if style:
		species = style.species()
		_fur = ToonStyle.fur_color(style.head_color)
	_head_card = _WIDE_HEAD if species in ["p", "b", "s"] else _SQUARE_HEAD
	_head = _card(_HEADS.get(species, _HEADS["d"]))
	_face = _card(_SMILE)
	_eyes = Control.new()
	_eyes.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_eyes)
	_whites = _card(_EYES)
	_whites.reparent(_eyes)
	_hp_label = _number()
	_max_label = _number()
	_eyes.add_child(_hp_label)
	_eyes.add_child(_max_label)
	for texture in _TEETH:
		var tooth := _card(texture)
		_teeth.append(tooth)
	_apply_size(108)
	set_hp(_hp, _max_hp)


## LaffMeter.start listens to the toon's hpChange. The eyes show that Laff.
func follow(loadout: ToonLoadout) -> void:
	if _followed != null and _followed.hp_changed.is_connected(_on_laff):
		_followed.hp_changed.disconnect(_on_laff)
	_followed = loadout
	if loadout == null:
		return
	loadout.hp_changed.connect(_on_laff)
	set_hp(loadout.hp, loadout.max_hp)


func _on_laff(current: int, maximum: int) -> void:
	set_hp(current, maximum)


func set_hp(current: int, maximum: int, quietly := false) -> void:
	var before := _hp
	_max_hp = maxi(maximum, 1)
	_hp = clampi(current, 0, _max_hp)
	var sad := _hp < 1
	var full := _hp >= _max_hp
	_head.modulate = _SAD if sad else _fur
	_eyes.visible = not sad
	if sad:
		_face.texture = _FROWN
	elif full:
		_face.texture = _SMILE
	else:
		_face.texture = _OPEN
	for index in _teeth.size():
		_teeth[index].visible = not sad and not full and float(_hp) > float(_max_hp) * _FRACTIONS[index]
	_hp_label.text = str(_hp)
	_max_label.text = str(_max_hp)
	if _boing_ready and not quietly and _hp != before:
		pulse(_hp > before)
	_boing_ready = true


## LaffMeter.animatedEffect. Gaining Laff pulses larger, losing it pulses smaller.
func pulse(larger: bool) -> void:
	if not is_inside_tree():
		return
	if _boing != null and _boing.is_valid():
		_boing.kill()
	pivot_offset = size * 0.5
	scale = Vector2.ONE
	var peak := 1.333 if larger else 0.667
	_boing = create_tween()
	_boing.tween_property(self, "scale", Vector2(peak, peak), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_boing.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


static func corner(view: Vector2, pixels: float) -> Vector2:
	return Vector2(pixels * 0.5 + _SCREEN_MARGIN, view.y - pixels * 0.5 - _SCREEN_MARGIN)


func place(center: Vector2, pixels: float) -> void:
	_apply_size(pixels)
	position = center - size * 0.5


func _apply_size(pixels: float) -> void:
	# Size cannot drop below custom_minimum_size, so clear the floor first.
	var head_w := _head_card.z - _head_card.x
	var head_h := _head_card.w - _head_card.y
	custom_minimum_size = Vector2.ZERO
	size = Vector2(pixels * head_w / head_h, pixels)
	custom_minimum_size = size
	pivot_offset = size * 0.5
	_place_card(_head, _head_card)
	_place_card(_face, _MOUTH)
	_eyes.position = Vector2.ZERO
	_eyes.size = size
	_place_card(_whites, _EYE_CARD)
	_place_number(_hp_label, _HP_EYE)
	_place_number(_max_label, _MAX_EYE)
	for index in _teeth.size():
		_place_card(_teeth[index], _TOOTH_BOUNDS[index])


func _place_card(card: TextureRect, bounds: Vector4) -> void:
	var rect := _map_rect(bounds)
	card.position = rect.position
	card.size = rect.size


func _place_number(label: Label, model: Vector2) -> void:
	var font := ToonGui.font()
	var line_px := _TEXT_SCALE / (_head_card.w - _head_card.y) * size.y
	var probe := 64
	var font_px := maxi(int(round(line_px / (font.get_height(probe) / float(probe)))), 1)
	# Plain black, the DirectLabel default. An outline shoves the digits off the eyes.
	ToonGui.style_label(label, Color.BLACK, font_px, Color(0, 0, 0, 0), 0)
	var width := maxf(font.get_string_size("120", HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x + 4.0, line_px)
	var height := font.get_height(font_px)
	var eye := _map_point(model.x, model.y)
	var baseline_y := eye.y + float(font_px) * _INK_ABOVE
	label.size = Vector2(width, height)
	label.position = Vector2(eye.x - width * 0.5, baseline_y - font.get_ascent(font_px))


func _map_rect(bounds: Vector4) -> Rect2:
	var left := _map_point(bounds.x, bounds.w)
	var right := _map_point(bounds.z, bounds.y)
	return Rect2(left.x, left.y, right.x - left.x, right.y - left.y)


func _map_point(x: float, z: float) -> Vector2:
	var px := (x - _head_card.x) / (_head_card.z - _head_card.x) * size.x
	var py := (_head_card.w - z) / (_head_card.w - _head_card.y) * size.y
	return Vector2(px, py)


func _card(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _number() -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return label
