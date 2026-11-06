class_name QuestChoice
extends Control

## QuestChoiceGui. A tall dialog on the left holds one, two, or three quest
## posters. Each poster has Choose. Cancel, or the 20 second timer, picks none.

signal chosen(quest_id: int)

const _DIALOG := preload("res://assets/gui/tutorial/dialog/dialog_box.png")
const _UP := preload("res://assets/toons/gui/QuitBtn_UP.png")
const _DOWN := preload("res://assets/toons/gui/QuitBtn_DN.png")
const _HOVER := preload("res://assets/toons/gui/QuitBtn_RLVR.png")
const _TIMEOUT := 20.0

var _tasks: Array[Dictionary] = []
var _dialog: TextureRect
var _posters: Array[QuestPoster] = []
var _chooses: Array[TextureButton] = []
var _captions: Array[Label] = []
var _cancel: TextureButton
var _cancel_caption: Label
var _timer: Label
var _left := _TIMEOUT
var _sent := false


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	z_index = 30
	_dialog = TextureRect.new()
	_dialog.texture = _DIALOG
	_dialog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dialog.stretch_mode = TextureRect.STRETCH_SCALE
	_dialog.mouse_filter = MOUSE_FILTER_IGNORE
	# QuestChoiceGui rolls the dialog onto its side and tints it brown.
	_dialog.rotation_degrees = -90.0
	_dialog.modulate = Color(0.8, 0.6, 0.4, 1.0)
	add_child(_dialog)
	_cancel = _pill()
	_cancel.pressed.connect(_pick.bind(0))
	_cancel_caption = _ink("Cancel")
	_timer = Label.new()
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_timer)


func show_quests(tasks: Array[Dictionary]) -> void:
	_tasks = tasks
	for poster in _posters:
		poster.queue_free()
	for button in _chooses:
		button.queue_free()
	for caption in _captions:
		caption.queue_free()
	_posters.clear()
	_chooses.clear()
	_captions.clear()
	for task in tasks:
		var poster := QuestPoster.new()
		poster.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(poster)
		poster.show_task(task)
		_posters.append(poster)
		var quest_id := int(task.get("id", 0))
		var button := _pill()
		button.pressed.connect(_pick.bind(quest_id))
		_chooses.append(button)
		_captions.append(_ink("Choose"))
	_layout()


func _ready() -> void:
	var view := get_viewport()
	if view != null and not view.size_changed.is_connected(_layout):
		view.size_changed.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	_left = maxf(_left - delta, 0.0)
	_timer.text = str(int(ceil(_left)))
	if _left <= 0.0:
		_pick(0)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode != KEY_ESCAPE and key.physical_keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	_pick(0)


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.y < 2.0:
		return
	position = Vector2.ZERO
	size = view
	var count := _posters.size()
	var tall := 1.0
	var poster_scale := 1.0
	var spots := [0.1]
	var cancel_z := -0.375
	var timer_z := -0.35
	if count == 2:
		tall = 1.5
		spots = [-0.2, 0.4]
		cancel_z = -0.625
		timer_z = -0.6
	elif count >= 3:
		tall = 1.85
		poster_scale = 0.95
		spots = [-0.4, 0.125, 0.65]
		cancel_z = -0.8
		timer_z = -0.775
	# The rotated dialog's visible size is 0.9 wide and `tall` high, at x -0.85.
	ToonGui.place(_dialog, view, -0.85, 0.0, tall, 0.9)
	var card_w := 0.8 * poster_scale
	var card_h := 0.58 * poster_scale
	for index in count:
		ToonGui.place(_posters[index], view, -0.85, spots[index], card_w, card_h)
		_posters[index].layout(_posters[index].size)
		# Choose sits on the poster's upper right. The button itself is scaled 0.65.
		var button_w := 0.425 * 0.7 * 0.65 * poster_scale
		var button_h := 0.1083 * 0.65 * poster_scale
		ToonGui.place(_chooses[index], view, -0.85 + 0.285 * poster_scale, spots[index] + 0.245 * poster_scale, button_w, button_h)
		_place_ink(_captions[index], view, -0.85 + 0.285 * poster_scale, spots[index] + 0.245 * poster_scale - 0.02, 0.06 * 0.65)
	ToonGui.place(_cancel, view, -0.7, cancel_z, 0.425 * 0.7, 0.1083)
	_place_ink(_cancel_caption, view, -0.7, cancel_z - 0.02, 0.06)
	_place_ink(_timer, view, -1.05, timer_z, 0.12)
	_timer.text = str(int(ceil(_left)))


func _pill() -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _UP
	button.texture_pressed = _DOWN
	button.texture_hover = _HOVER
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(button)
	return button


func _ink(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _place_ink(label: Label, view: Vector2, x: float, z: float, text_scale: float) -> void:
	var px := maxi(int(round(text_scale * view.y * 0.5)), 10)
	ToonGui.style_label(label, Color(0, 0, 0), px, Color(0, 0, 0, 0), 0)
	ToonGui.place(label, view, x, z, text_scale * 8.0, text_scale * 1.6)


func _pick(quest_id: int) -> void:
	if _sent:
		return
	_sent = true
	set_process(false)
	chosen.emit(quest_id)
