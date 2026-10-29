class_name QuestPoster
extends Control

## One scroll from the Shticker Book task page, using the original quest card.

const _CARD := preload("res://assets/gui/tutorial/book/questCard.png")

var _headline: Label
var _caption: Label
var _where: Label
var _progress: Label
var _badge: Panel
var _count: Label


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(230, 180)
	size = custom_minimum_size
	size_flags_horizontal = SIZE_SHRINK_CENTER
	size_flags_vertical = SIZE_SHRINK_CENTER
	var card := TextureRect.new()
	card.texture = _CARD
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.mouse_filter = MOUSE_FILTER_IGNORE
	card.set_anchors_preset(PRESET_FULL_RECT)
	card.offset_left = 0
	card.offset_top = 0
	card.offset_right = 0
	card.offset_bottom = 0
	add_child(card)
	_badge = Panel.new()
	_badge.mouse_filter = MOUSE_FILTER_IGNORE
	_badge.position = Vector2(18, 28)
	_badge.size = Vector2(26, 26)
	var red := StyleBoxFlat.new()
	red.bg_color = Color(0.82, 0.16, 0.16)
	red.set_corner_radius_all(13)
	_badge.add_theme_stylebox_override("panel", red)
	add_child(_badge)
	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.mouse_filter = MOUSE_FILTER_IGNORE
	_count.size = _badge.size
	ToonGui.style_label(_count, Color.WHITE, 14, Color(0, 0, 0), 1)
	_badge.add_child(_count)
	_headline = _label(Vector2(48, 26), Vector2(150, 28), 18)
	_caption = _label(Vector2(24, 78), Vector2(182, 36), 18)
	_where = _label(Vector2(24, 114), Vector2(182, 24), 14)
	_progress = _label(Vector2(24, 140), Vector2(182, 22), 13)


func show_task(task: Dictionary) -> void:
	_headline.text = String(task.get("headline", ""))
	_caption.text = String(task.get("caption", ""))
	_where.text = String(task.get("where", ""))
	var goal := int(task.get("goal", 1))
	var progress := int(task.get("progress", 0))
	var show_count := bool(task.get("show_count", false))
	_badge.visible = show_count
	_count.text = str(goal)
	if bool(task.get("ready", false)):
		_progress.text = "Ready for turn-in!"
	elif show_count:
		_progress.text = "%d of %d defeated" % [progress, goal]
	else:
		_progress.text = ""


func _label(at: Vector2, box: Vector2, px: int) -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = at
	label.size = box
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ToonGui.style_label(label, Color(0.28, 0.18, 0.08), px, Color(0, 0, 0, 0), 0)
	add_child(label)
	return label
