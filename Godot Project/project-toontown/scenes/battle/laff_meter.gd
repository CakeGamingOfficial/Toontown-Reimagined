class_name LaffMeter
extends Control

## LaffMeter.py drawn with the original laff_o_meter cards. Full laff smiles.
## Anything less opens the mouth and drops teeth from the right. Empty laff
## turns the head green and sad.

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

var _head: TextureRect
var _face: TextureRect
var _eyes: Control
var _hp_label: Label
var _max_label: Label
var _teeth: Array[TextureRect] = []
var _fur := Color.WHITE
var _hp := 15
var _max_hp := 15


func setup(style: ToonStyle) -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var species := "d"
	_fur = Color(0.996, 0.695, 0.512)
	if style:
		species = style.species()
		_fur = ToonStyle.fur_color(style.head_color)
	_head = _card(_HEADS.get(species, _HEADS["d"]))
	_face = _card(_SMILE)
	_eyes = Control.new()
	_eyes.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_eyes)
	var whites := _card(_EYES)
	whites.reparent(_eyes)
	whites.set_anchors_preset(Control.PRESET_FULL_RECT)
	whites.offset_left = 0
	whites.offset_top = 0
	whites.offset_right = 0
	whites.offset_bottom = 0
	_hp_label = _number()
	_max_label = _number()
	_eyes.add_child(_hp_label)
	_eyes.add_child(_max_label)
	for texture in _TEETH:
		var tooth := _card(texture)
		_teeth.append(tooth)
	_apply_size(108)
	set_hp(_hp, _max_hp)


func set_hp(current: int, maximum: int) -> void:
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
		_teeth[index].visible = not sad and not full and _hp > int(_max_hp * _FRACTIONS[index])
	_hp_label.text = str(_hp)
	_max_label.text = str(_max_hp)


func place(center: Vector2, pixels: float) -> void:
	_apply_size(pixels)
	position = center - size * 0.5


func _apply_size(pixels: float) -> void:
	# Size cannot drop below custom_minimum_size, so clear the floor first.
	custom_minimum_size = Vector2.ZERO
	size = Vector2(pixels, pixels)
	custom_minimum_size = size
	_head.position = Vector2.ZERO
	_head.size = size
	_face.position = Vector2.ZERO
	_face.size = size
	_eyes.position = size * Vector2(0.16, 0.2)
	_eyes.size = size * Vector2(0.68, 0.36)
	_hp_label.position = Vector2(0, _eyes.size.y * 0.02)
	_hp_label.size = Vector2(_eyes.size.x * 0.5, _eyes.size.y * 0.96)
	_max_label.position = Vector2(_eyes.size.x * 0.5, _eyes.size.y * 0.02)
	_max_label.size = Vector2(_eyes.size.x * 0.5, _eyes.size.y * 0.96)
	var point := int(clampf(_eyes.size.y * 0.72, 14, 72))
	ToonGui.style_label(_hp_label, Color(0.08, 0.08, 0.1), point, Color(1, 1, 1, 0.85), 2)
	ToonGui.style_label(_max_label, Color(0.08, 0.08, 0.1), point, Color(1, 1, 1, 0.85), 2)
	for index in _teeth.size():
		var tooth := _teeth[index]
		tooth.position = Vector2(size.x * (0.22 + index * 0.09), size.y * 0.55)
		tooth.size = size * Vector2(0.1, 0.14)


func _card(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _number() -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
