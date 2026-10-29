class_name ToonGui
extends RefCounted

## Shared sign-font styling and aspect2d placement. One aspect unit is half
## the window height, matching Panda's aspect2d.

static var _font: Font
static var _sign: Font


static func font() -> Font:
	if _font == null:
		var system := SystemFont.new()
		system.font_names = PackedStringArray(["Comic Sans MS", "Comic Sans"])
		system.font_weight = 700
		system.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		system.generate_mipmaps = true
		_font = system
	return _font


static func sign_font() -> Font:
	if _sign == null:
		_sign = load("res://assets/toons/fonts/LilitaOne-Regular.ttf")
	return _sign


static func style_title(label: Label, color: Color, px: int) -> void:
	# The original screen titles are the sign font: chunky yellow letters
	# with a heavy black outline.
	label.add_theme_font_override("font", sign_font())
	label.add_theme_font_size_override("font_size", maxi(px, 1))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", maxi(int(round(px * 0.16)), 2))


static func style_label(label: Label, color: Color, px: int, outline: Color, outline_px: int) -> void:
	label.add_theme_font_override("font", font())
	label.add_theme_font_size_override("font_size", maxi(px, 1))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline)
	label.add_theme_constant_override("outline_size", maxi(outline_px, 0))


static func place(control: Control, view: Vector2, x: float, z: float, width: float, height: float) -> void:
	var unit := view.y * 0.5
	var center := Vector2(view.x * 0.5 + x * unit, view.y * 0.5 - z * unit)
	var box := Vector2(width, height) * unit
	control.position = center - box * 0.5
	control.size = box
	control.pivot_offset = box * 0.5
