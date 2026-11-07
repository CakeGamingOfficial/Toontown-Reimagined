extends Control

## Held ToonTasks as text on the right side of the screen.

const _UI := preload("res://scenes/shticker/ui_settings.gd")

var _tasks: ToonTasks
var _panel: PanelContainer
var _label: RichTextLabel
var _shown := ""
var _wait := 0.0
var _view := Vector2.ZERO


func setup(tasks: ToonTasks) -> void:
	_tasks = tasks
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.mouse_filter = MOUSE_FILTER_IGNORE
	_panel.visible = false
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1.0, 1.0, 1.0, 0.55)
	box.set_corner_radius_all(4)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	_panel.add_theme_stylebox_override("panel", box)
	_label = RichTextLabel.new()
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("normal_font", ToonGui.font())
	_label.add_theme_font_size_override("normal_font_size", 22)
	_label.add_theme_color_override("default_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 4)
	_panel.add_child(_label)
	add_child(_panel)


func _process(delta: float) -> void:
	var view := get_viewport_rect().size
	if view != _view:
		_place()
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = 0.25
	var book := get_parent().get_node_or_null("ShtickerBook") if get_parent() != null else null
	var open := book != null and book.has_method("is_open") and bool(book.call("is_open"))
	if open or _tasks == null or not _UI.tracker_on():
		_panel.visible = false
		return
	var text := _lines()
	_panel.visible = not text.is_empty()
	if text == _shown and _view == view:
		return
	_shown = text
	_label.text = text
	_place()


func _place() -> void:
	_view = get_viewport_rect().size
	var card := _panel.get_combined_minimum_size()
	_panel.size = card
	# Mid-right, above the Shticker Book button. The card hugs the words.
	_panel.position = Vector2(_view.x - card.x - 22.0, _view.y * 0.32)


func _lines() -> String:
	var blocks: PackedStringArray = []
	for card in _tasks.entries():
		var caption := String(card.get("caption", ""))
		if caption.is_empty():
			continue
		var block := caption
		var building := String(card.get("building", ""))
		var location := String(card.get("location", ""))
		if bool(card.get("ready", false)):
			var who := String(card.get("return_name", ""))
			if who.is_empty():
				who = "an HQ Officer"
			block += "\nReturn to " + who
		else:
			var goal := int(card.get("goal", 1))
			if goal > 1 or bool(card.get("show_count", false)):
				block += "\n%d of %d" % [int(card.get("progress", 0)), goal]
			var kind := String(card.get("kind", ""))
			var where := String(card.get("where", ""))
			if kind != "visit" and kind != "track" and not where.is_empty() and where != building:
				block += "\n" + where
		var street := _street_name(location)
		if not street.is_empty():
			block += "\n" + street
		var playground := _playground_name(location)
		if not building.is_empty() and not playground.is_empty():
			block += "\n" + building + "/" + playground
		elif not building.is_empty():
			block += "\n" + building
		var ink := _UI.done_color() if bool(card.get("ready", false)) else _UI.progress_color()
		block = "[color=#%s]%s[/color]" % [ink.to_html(false), block]
		blocks.append(block)
	return "\n\n".join(blocks)


## Loopy Lane counts. "Playground" and "Any Street" do not.
func _street_name(location: String) -> String:
	var bits := location.split("\n", false)
	if bits.is_empty():
		return ""
	var street := String(bits[0])
	if street == "Playground" or street == "Any Street" or street == _playground_name(location):
		return ""
	return street


## The neighborhood, not the extra "Playground" street line.
func _playground_name(location: String) -> String:
	var bits := location.split("\n", false)
	for i in range(bits.size() - 1, -1, -1):
		var line := String(bits[i])
		if line != "Playground" and line != "Any Street":
			return line
	return ""
