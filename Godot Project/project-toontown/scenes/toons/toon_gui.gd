class_name ToonGui
extends RefCounted

## Shared sign-font styling and aspect2d placement. One aspect unit is half
## the window height, matching Panda's aspect2d.

static var _font: Font
static var _suit: Font
static var _sign: Font


static func font() -> Font:
	# ImpressBT.ttf is the toon font. Toon and NPC nametags use it.
	if _font == null:
		_font = load("res://assets/toons/fonts/ImpressBT.ttf")
	return _font


static func suit_font() -> Font:
	# vtRemingtonPortable.ttf is the suit font. Cog nametags use it.
	if _suit == null:
		_suit = load("res://assets/toons/fonts/vtRemingtonPortable.ttf")
	return _suit


static func sign_font() -> Font:
	# MickeyFont.bam is a glyph atlas, not a TrueType file.
	if _sign == null:
		_sign = _load_sign_font()
	return _sign


static func _load_sign_font() -> FontFile:
	var description: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/toons/fonts/mickey_font.json"))
	var image := (preload("res://assets/toons/fonts/mickey_font.png") as Texture2D).get_image()
	var px := int(description["size"])
	var sign := FontFile.new()
	sign.allow_system_fallback = false
	# The atlas is authored at one pixel size. Labels ask for other sizes,
	# and Godot only finds these glyphs when that size is the fixed size.
	sign.fixed_size = px
	sign.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
	var cache := Vector2i(px, 0)
	sign.set_texture_image(0, cache, 0, image)
	sign.set_cache_ascent(0, px, float(description["ascent"]))
	sign.set_cache_descent(0, px, float(description["descent"]))
	for item in description["glyphs"]:
		var glyph: Dictionary = item
		var code := int(glyph["cp"])
		var uv: Array = glyph["uv"]
		sign.set_glyph_advance(0, px, code, Vector2(float(glyph["advance"]), 0.0))
		sign.set_glyph_offset(0, cache, code, Vector2(float(glyph["ox"]), float(glyph["oy"])))
		sign.set_glyph_size(0, cache, code, Vector2(float(glyph["w"]), float(glyph["h"])))
		sign.set_glyph_uv_rect(0, cache, code, Rect2(float(uv[0]), float(uv[1]), float(uv[2]), float(uv[3])))
		sign.set_glyph_texture_idx(0, cache, code, 0)
	return sign


static func style_title(label: Label, color: Color, px: int) -> void:
	# Screen titles use the Mickey sign font.
	style_sign(label, color, px, Color(0, 0, 0), maxi(int(round(px * 0.16)), 2))


static func style_sign(label: Label, color: Color, px: int, outline: Color, outline_px: int) -> void:
	label.add_theme_font_override("font", sign_font())
	label.add_theme_font_size_override("font_size", maxi(px, 1))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline)
	label.add_theme_constant_override("outline_size", maxi(outline_px, 0))


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
