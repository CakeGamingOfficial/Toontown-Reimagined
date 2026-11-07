extends Control

## The track-choice card quest 400 puts up. Toon-up is track 0 and Sound is
## track 3. Cancel, Escape, or the 20 second timer leaves the task in place.

signal chosen(track: int)

const _DIALOG := preload("res://assets/gui/tutorial/dialog/dialog_box.png")
const _UP := preload("res://assets/toons/gui/QuitBtn_UP.png")
const _DOWN := preload("res://assets/toons/gui/QuitBtn_DN.png")
const _HOVER := preload("res://assets/toons/gui/QuitBtn_RLVR.png")
const _TIMEOUT := 20.0

var _dialog: TextureRect
var _toonup: TextureButton
var _sound: TextureButton
var _cancel: TextureButton
var _toonup_caption: Label
var _sound_caption: Label
var _cancel_caption: Label
var _timer: Label
var _left := _TIMEOUT
var _sent := false
var _side: Array[int] = [0, 3]
const _TRACK_NAME: PackedStringArray = ["Toon-up", "Trap", "Lure", "Sound", "Throw", "Squirt", "Drop"]


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	z_index = 30
	_dialog = TextureRect.new()
	_dialog.texture = _DIALOG
	_dialog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dialog.stretch_mode = TextureRect.STRETCH_SCALE
	_dialog.mouse_filter = MOUSE_FILTER_IGNORE
	_dialog.rotation_degrees = -90.0
	_dialog.modulate = Color(0.8, 0.6, 0.4, 1.0)
	add_child(_dialog)
	_toonup = _pill()
	_toonup.pressed.connect(_pick_side.bind(0))
	_toonup_caption = _ink("Toon-up")
	_sound = _pill()
	_sound.pressed.connect(_pick_side.bind(1))
	_sound_caption = _ink("Sound")
	_cancel = _pill()
	_cancel.pressed.connect(_pick.bind(-1))
	_cancel_caption = _ink("Cancel")
	_timer = Label.new()
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_timer)


func _ready() -> void:
	var view := get_viewport()
	if view != null and not view.size_changed.is_connected(_layout):
		view.size_changed.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	_left = maxf(_left - delta, 0.0)
	_timer.text = str(int(ceil(_left)))
	if _left <= 0.0:
		_pick(-1)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode != KEY_ESCAPE and key.physical_keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	_pick(-1)


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.y < 2.0:
		return
	position = Vector2.ZERO
	size = view
	ToonGui.place(_dialog, view, -0.85, 0.05, 1.15, 0.9)
	ToonGui.place(_toonup, view, -0.85, 0.28, 0.425 * 0.85, 0.1083)
	_place_ink(_toonup_caption, view, -0.85, 0.26, 0.055)
	ToonGui.place(_sound, view, -0.85, 0.08, 0.425 * 0.85, 0.1083)
	_place_ink(_sound_caption, view, -0.85, 0.06, 0.055)
	ToonGui.place(_cancel, view, -0.85, -0.28, 0.425 * 0.7, 0.1083)
	_place_ink(_cancel_caption, view, -0.85, -0.30, 0.06)
	_place_ink(_timer, view, -1.05, -0.22, 0.12)
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


func set_tracks(left: int, right: int) -> void:
	if left >= 0 and left < _TRACK_NAME.size():
		_side[0] = left
		_toonup_caption.text = _TRACK_NAME[left]
	if right >= 0 and right < _TRACK_NAME.size():
		_side[1] = right
		_sound_caption.text = _TRACK_NAME[right]


func _pick_side(index: int) -> void:
	_pick(_side[index])


func _pick(track: int) -> void:
	if _sent:
		return
	_sent = true
	set_process(false)
	chosen.emit(track)
