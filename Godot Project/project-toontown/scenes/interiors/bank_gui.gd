extends Control

## BankGui. The cream dialog is dialog_box_gui tinted GlobalDialogColor.
## The jar is jar_gui, the machine is jellybeanBank, and the arrows are the
## create-a-toon arrows. Positions are the original aspect2d coordinates.

signal finished

const _BEANS := preload("res://scenes/toons/jellybeans.gd")
const _DIALOG := preload("res://assets/gui/tutorial/dialog/dialog_box.png")
const _JAR := preload("res://assets/gui/tutorial/book/jar.png")
const _BANK := preload("res://assets/gui/bank/bank.png")
const _ARROW_UP := preload("res://assets/gui/bank/arrow_up.png")
const _ARROW_DOWN := preload("res://assets/gui/bank/arrow_down.png")
const _ARROW_HOVER := preload("res://assets/gui/bank/arrow_hover.png")
const _OK_UP := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_UP.png")
const _OK_DOWN := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_DN.png")
const _OK_HOVER := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_Rllvr.png")
const _CANCEL_UP := preload("res://assets/toons/gui/CloseBtn_UP.png")
const _CANCEL_DOWN := preload("res://assets/toons/gui/CloseBtn_DN.png")
const _CANCEL_HOVER := preload("res://assets/toons/gui/CloseBtn_Rllvr.png")

# dialog_box_gui bounds, then geom_scale (1.33, 1, 1.1).
const _DIALOG_AT := Vector2(-0.0281, -0.0426)
const _DIALOG_SIZE := Vector2(1.4792, 1.3047)
# jar_gui scaled by 0.7, centered at (-0.4, 0).
const _JAR_AT := Vector2(-0.4, 0.0)
const _JAR_SIZE := Vector2(0.3033, 0.3704)
# jellybeanBank at geom_scale 0.08 under the label's scale of 0.9.
const _BANK_AT := Vector2(0.4, 0.0705)
const _BANK_SIZE := Vector2(0.3205, 0.6077)
# CrtATn_R_Arrow cards. Deposit points at the bank. Withdraw is flipped.
const _ARROW_SIZE := Vector2(0.3125, 0.2875)
const _DEPOSIT_AT := Vector2(0.01, 0.15)
const _WITHDRAW_AT := Vector2(-0.01, -0.15)
# dialog_box_buttons_gui cards, with the caption 0.1 below the button.
const _BUTTON_SIZE := Vector2(0.1125, 0.1125)
const _CANCEL_AT := Vector2(-0.2, -0.4)
const _OK_AT := Vector2(0.2, -0.4)

var _pending := 0
var _holding := 0
var _delay := 0.4
var _wait := 0.0
var _blocker: ColorRect
var _dialog: TextureRect
var _jar: TextureRect
var _bank: TextureRect
var _jar_amount: Label
var _bank_amount: Label
var _deposit: TextureButton
var _withdraw: TextureButton
var _ok: TextureButton
var _cancel_button: TextureButton
var _ok_caption: Label
var _cancel_caption: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	var view := get_viewport()
	if not view.size_changed.is_connected(_layout):
		view.size_changed.connect(_layout)
	_layout()
	_show_amounts()


func _process(delta: float) -> void:
	if _holding == 0:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_delay = maxf(0.05, _delay * 0.75)
	_wait = _delay
	if _bump(_holding):
		_holding = 0


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode != KEY_ESCAPE and key.physical_keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	_cancel()


func _build() -> void:
	_blocker = ColorRect.new()
	_blocker.color = Color(0, 0, 0, 0)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_blocker)
	_dialog = _picture(_DIALOG)
	# ToontownGlobals.GlobalDialogColor tints the white dialog cream.
	_dialog.modulate = Color(1.0, 1.0, 0.75, 1.0)
	_jar = _picture(_JAR)
	_bank = _picture(_BANK)
	_jar_amount = _amount()
	_bank_amount = _amount()
	_deposit = _arrow(false)
	_withdraw = _arrow(true)
	_deposit.button_down.connect(_press_deposit)
	_withdraw.button_down.connect(_press_withdraw)
	_deposit.button_up.connect(_release)
	_withdraw.button_up.connect(_release)
	_cancel_button = _choice(_CANCEL_UP, _CANCEL_DOWN, _CANCEL_HOVER)
	_ok = _choice(_OK_UP, _OK_DOWN, _OK_HOVER)
	_cancel_button.pressed.connect(_cancel)
	_ok.pressed.connect(_confirm)
	_cancel_caption = _caption("Cancel")
	_ok_caption = _caption("OK")


func _picture(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _amount() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = false
	add_child(label)
	return label


func _arrow(flip: bool) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _ARROW_UP
	button.texture_pressed = _ARROW_DOWN
	button.texture_hover = _ARROW_HOVER
	button.texture_disabled = _ARROW_UP
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.flip_h = flip
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(button)
	return button


func _choice(up: Texture2D, down: Texture2D, hover: Texture2D) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = up
	button.texture_pressed = down
	button.texture_hover = hover
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(button)
	return button


func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.y < 2.0:
		return
	position = Vector2.ZERO
	size = view
	_blocker.position = Vector2.ZERO
	_blocker.size = view
	_put(_dialog, _DIALOG_AT, _DIALOG_SIZE)
	_put(_jar, _JAR_AT, _JAR_SIZE)
	_put(_bank, _BANK_AT, _BANK_SIZE)
	_put(_deposit, _DEPOSIT_AT, _ARROW_SIZE)
	_put(_withdraw, _WITHDRAW_AT, _ARROW_SIZE)
	_put(_cancel_button, _CANCEL_AT, _BUTTON_SIZE)
	_put(_ok, _OK_AT, _BUTTON_SIZE)
	# text_scale 0.2 is local to the jar (scale 0.7) and the bank label (scale 0.9).
	_put_sign(_jar_amount, _JAR_AT.x, -0.07, 0.14)
	_put_sign(_bank_amount, _BANK_AT.x, -0.09, 0.18)
	_put_caption(_cancel_caption, _CANCEL_AT.x, _CANCEL_AT.y - 0.1, 0.06)
	_put_caption(_ok_caption, _OK_AT.x, _OK_AT.y - 0.1, 0.06)


func _put(control: Control, center: Vector2, box: Vector2) -> void:
	ToonGui.place(control, size, center.x, center.y, box.x, box.y)


func _put_sign(label: Label, x: float, baseline: float, text_scale: float) -> void:
	var px := maxi(int(round(text_scale * size.y * 0.5)), 1)
	ToonGui.style_sign(label, Color(0.95, 0.95, 0.0), px, Color(0, 0, 0), maxi(int(round(float(px) * 0.14)), 1))
	ToonGui.place(label, size, x, baseline + text_scale * 0.35, 1.05, text_scale * 1.45)


func _put_caption(label: Label, x: float, baseline: float, text_scale: float) -> void:
	var px := maxi(int(round(text_scale * size.y * 0.5)), 1)
	ToonGui.style_label(label, Color(0, 0, 0), px, Color(0, 0, 0, 0), 0)
	ToonGui.place(label, size, x, baseline + text_scale * 0.35, 0.55, text_scale * 1.45)


func _press_deposit() -> void:
	_press(1)


func _press_withdraw() -> void:
	_press(-1)


func _press(step: int) -> void:
	_holding = step
	_delay = 0.4
	_wait = 0.4
	if _bump(step):
		_holding = 0


func _release() -> void:
	_holding = 0


func _bump(step: int) -> bool:
	var next := _BEANS.clamp_transfer(_pending + step)
	var stopped := next == _pending
	_pending = next
	_show_amounts()
	return stopped


func _show_amounts() -> void:
	var carried := _BEANS.pouch() - _pending
	var saved := _BEANS.bank() + _pending
	_jar_amount.text = str(carried)
	_bank_amount.text = str(saved)
	var deposit_full := carried <= 0 or saved >= _BEANS.BANK_MAX
	var withdraw_full := saved <= 0 or carried >= _BEANS.POUCH_MAX
	_paint(_deposit, deposit_full)
	_paint(_withdraw, withdraw_full)


func _paint(button: TextureButton, disabled: bool) -> void:
	button.disabled = disabled
	# image3_color on a disabled create-a-toon arrow.
	button.modulate = Color(0.6, 0.6, 0.6, 0.25) if disabled else Color.WHITE


func _confirm() -> void:
	_BEANS.transfer(_pending)
	_close()


func _cancel() -> void:
	_close()


func _close() -> void:
	_holding = 0
	finished.emit()
	queue_free()
