extends CanvasLayer

## OTPClientRepository.enterNoConnection. A broken link uses CRLostConnection.
## Boot code 153 is the district reset. OK tries the server again. Cancel leaves.

signal retry_connect
signal leave_game

const _DIALOG := preload("res://assets/gui/tutorial/dialog/dialog_box.png")
const _OK_UP := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_UP.png")
const _OK_DOWN := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_DN.png")
const _OK_HOVER := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_Rllvr.png")
const _CANCEL_UP := preload("res://assets/toons/gui/CloseBtn_UP.png")
const _CANCEL_DOWN := preload("res://assets/toons/gui/CloseBtn_DN.png")
const _CANCEL_HOVER := preload("res://assets/toons/gui/CloseBtn_Rllvr.png")
const _CREAM := Color(1, 1, 0.75, 1)
const _LOST := "Your internet connection to the servers has been unexpectedly broken."
const _RESET := "The district you were playing on has been reset.  Everyone who was playing on that district has been disconnected.  However, you should be able to connect again and go right back into the game."
const _AGAIN := "\n\nTry to connect again?"
const _BOOT_RESET := 153

var _root: Control
var _message: Label


func _ready() -> void:
	layer = 130
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var frame := TextureRect.new()
	frame.texture = _DIALOG
	frame.modulate = _CREAM
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(frame)
	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_message)
	_root.add_child(_choice(_OK_UP, _OK_DOWN, _OK_HOVER, "OK", _retry))
	_root.add_child(_choice(_CANCEL_UP, _CANCEL_DOWN, _CANCEL_HOVER, "Cancel", _leave))
	var view := get_viewport()
	if view != null and not view.size_changed.is_connected(_layout):
		view.size_changed.connect(_layout)


func show_reason(code: int) -> void:
	var body := _RESET if code == _BOOT_RESET else _LOST
	_message.text = body + _AGAIN
	visible = true
	_layout()


func hide_notice() -> void:
	visible = false


func _retry() -> void:
	visible = false
	retry_connect.emit()


func _leave() -> void:
	visible = false
	leave_game.emit()


func _choice(up: Texture2D, down: Texture2D, hover: Texture2D, caption: String, action: Callable) -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var button := TextureButton.new()
	button.texture_normal = up
	button.texture_pressed = down
	button.texture_hover = hover
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	ToonGui.button_sounds(button)
	box.add_child(button)
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	return box


func _layout() -> void:
	if _root == null:
		return
	var view := get_viewport().get_visible_rect().size
	if view.y < 2.0:
		return
	_root.position = Vector2.ZERO
	_root.size = view
	var dim := _root.get_child(0) as Control
	dim.position = Vector2.ZERO
	dim.size = view
	ToonGui.place(_root.get_child(1), view, 0.0, 0.05, 1.7, 1.45)
	var px := maxi(int(round(0.055 * view.y * 0.5)), 1)
	ToonGui.style_label(_message, Color(0.08, 0.08, 0.08), px, Color(0, 0, 0, 0), 0)
	ToonGui.place(_message, view, 0.0, 0.16, 1.35, 0.72)
	_place_choice(_root.get_child(3), view, -0.28)
	_place_choice(_root.get_child(4), view, 0.28)


func _place_choice(box: Node, view: Vector2, x: float) -> void:
	var host := box as Control
	host.position = Vector2.ZERO
	host.size = view
	var button := box.get_child(0) as Control
	var caption := box.get_child(1) as Label
	ToonGui.place(button, view, x, -0.42, 0.13, 0.13)
	var px := maxi(int(round(0.05 * view.y * 0.5)), 1)
	ToonGui.style_label(caption, Color(0, 0, 0), px, Color(0, 0, 0, 0), 0)
	ToonGui.place(caption, view, x, -0.52, 0.36, 0.1)
