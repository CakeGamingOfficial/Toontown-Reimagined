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


## NametagGroup chat wordwrap. TextNode breaks a line after this many font
## heights, and a shorter line stays on one row so the balloon hugs the words.
const CHAT_WORDWRAP := 10.0


static func wrap_words(font: Font, text: String, px: int, budget: float) -> String:
	if font == null or text.is_empty():
		return text
	var size := maxi(px, 1)
	var lines: PackedStringArray = []
	for source in text.split("\n", false):
		var line := ""
		for word in source.split(" ", false):
			var trial := word if line.is_empty() else "%s %s" % [line, word]
			if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > budget and not line.is_empty():
				lines.append(line)
				line = word
			else:
				line = trial
		if not line.is_empty():
			lines.append(line)
	return "\n".join(lines)


static func wrap_speech(font: Font, text: String, px: int) -> String:
	var face := font if font != null else font()
	var size := maxi(px, 1)
	return wrap_words(face, text, size, float(size) * CHAT_WORDWRAP)


## Pre-wrap, then turn autowrap off. A Label that wraps inside a balloon
## sized to its own minimum collapses to a few pixels and stacks one word
## under the next.
static func show_speech(label: Label, text: String, px: int) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size = Vector2.ZERO
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = wrap_speech(label.get_theme_font("font"), text, px)


const CLICK_SFX := "res://assets/toons/audio/GUI_create_toon_fwd.mp3"
const ROLLOVER_SFX := "res://assets/toons/audio/GUI_rollover.mp3"

static var _streams: Dictionary = {}
static var _primed: Dictionary = {}


## Load and play the click and rollover once, so the first welcome button
## does not decode them or open the effect bus on the click itself.
static func warm_clicks() -> void:
	_stream(CLICK_SFX)
	_stream(ROLLOVER_SFX)
	_prime(CLICK_SFX)
	_prime(ROLLOVER_SFX)


static func _prime(path: String) -> void:
	if _primed.has(path) or DisplayServer.get_name() == "headless":
		return
	var stream := _stream(path)
	if stream == null:
		return
	_primed[path] = true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var player := ToonAudio.effect_player()
	player.stream = stream
	player.volume_db = -80.0
	player.finished.connect(player.queue_free)
	tree.root.add_child(player)
	player.play()


static func _stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var stream := load(path) as AudioStream
	if stream != null:
		_streams[path] = stream
	return stream


## DirectGui's default click and rollover, used by every Make a Toon and Pick a Toon button.
static func button_sounds(button: BaseButton) -> void:
	button.mouse_entered.connect(func() -> void:
		if button.disabled:
			return
		play_sfx(button, ROLLOVER_SFX)
	)
	button.pressed.connect(func() -> void:
		play_sfx(button, CLICK_SFX)
	)


static func play_sfx(host: Node, path: String) -> void:
	if path.is_empty():
		return
	var stream: AudioStream = _streams.get(path)
	if stream == null:
		if not ResourceLoader.exists(path):
			return
		stream = _stream(path)
	if stream == null:
		return
	# A click can rebuild the shop and pull the button out of the tree before
	# this runs. The scene root still can play it.
	var tree: SceneTree = null
	if host != null and is_instance_valid(host) and host.is_inside_tree():
		tree = host.get_tree()
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	if parent == null:
		return
	var player := ToonAudio.effect_player()
	player.stream = stream
	player.finished.connect(player.queue_free)
	parent.add_child(player)
	player.play()


## Click-to-continue speech. The arrow is a sibling, so a PanelContainer
## cannot stretch it across the card, and it blinks in the bottom-right corner.
static func attach_next_arrow(host: Control) -> TextureRect:
	var arrow := TextureRect.new()
	arrow.set_script(preload("res://scenes/toons/chat_next_arrow.gd"))
	arrow.call("follow", host)
	var parent := host.get_parent()
	if parent == null:
		parent = host
	parent.add_child(arrow)
	arrow.z_index = host.z_index + 1
	return arrow


static func place(control: Control, view: Vector2, x: float, z: float, width: float, height: float) -> void:
	var unit := view.y * 0.5
	var center := Vector2(view.x * 0.5 + x * unit, view.y * 0.5 - z * unit)
	var box := Vector2(width, height) * unit
	control.position = center - box * 0.5
	control.size = box
	control.pivot_offset = box * 0.5
