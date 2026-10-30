extends Control

## BankGui. The jar on the left is the pouch. The number on the right is the
## estate bank. The arrows move one jellybean at a time, and holding one
## keeps counting. OK commits the move. Cancel leaves both balances alone.

signal finished

const _BEANS := preload("res://scenes/toons/jellybeans.gd")
const _JAR := preload("res://assets/gui/tutorial/book/jar.png")
const _ARROW := preload("res://assets/gui/tutorial/book/arrow_button.png")
const _OK_UP := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_UP.png")
const _OK_DOWN := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_DN.png")
const _OK_HOVER := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_Rllvr.png")

var _pending := 0
var _holding := 0
var _delay := 0.4
var _wait := 0.0
var _jar_amount: Label
var _bank_amount: Label
var _deposit: TextureButton
var _withdraw: TextureButton


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -340.0
	panel.offset_top = -220.0
	panel.offset_right = 340.0
	panel.offset_bottom = 220.0
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 0.75)
	box.border_color = Color(0.55, 0.38, 0.14)
	box.set_border_width_all(6)
	box.set_corner_radius_all(22)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", box)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)
	var title := Label.new()
	title.text = "Jellybean Bank"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ToonGui.style_title(title, Color(0.42, 0.2, 0.05), 34)
	column.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	row.add_child(_balance("Pouch", true))
	row.add_child(_arrows())
	row.add_child(_balance("Bank", false))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 28)
	column.add_child(buttons)
	buttons.add_child(_ok_button())
	buttons.add_child(_cancel_button())
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


func _balance(caption: String, jar: bool) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(180, 0)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 4)
	var heading := Label.new()
	heading.text = caption
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ToonGui.style_label(heading, Color(0.25, 0.12, 0.04), 22, Color(0, 0, 0, 0), 0)
	card.add_child(heading)
	var art := Control.new()
	art.custom_minimum_size = Vector2(150, 150)
	card.add_child(art)
	if jar:
		var picture := TextureRect.new()
		picture.texture = _JAR
		picture.set_anchors_preset(Control.PRESET_FULL_RECT)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(picture)
	var amount := Label.new()
	amount.set_anchors_preset(Control.PRESET_FULL_RECT)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_title(amount, Color(0.95, 0.88, 0.1), 28)
	art.add_child(amount)
	if jar:
		_jar_amount = amount
	else:
		_bank_amount = amount
	return card


func _arrows() -> Control:
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 10)
	_deposit = _arrow(false)
	_withdraw = _arrow(true)
	_deposit.button_down.connect(_press_deposit)
	_withdraw.button_down.connect(_press_withdraw)
	_deposit.button_up.connect(_release)
	_withdraw.button_up.connect(_release)
	stack.add_child(_deposit)
	stack.add_child(_withdraw)
	return stack


func _arrow(flip: bool) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _ARROW
	button.ignore_texture_size = true
	button.custom_minimum_size = Vector2(72, 72)
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.flip_h = flip
	return button


func _ok_button() -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _OK_UP
	button.texture_pressed = _OK_DOWN
	button.texture_hover = _OK_HOVER
	button.ignore_texture_size = true
	button.custom_minimum_size = Vector2(110, 78)
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.pressed.connect(_confirm)
	return button


func _cancel_button() -> Button:
	var button := Button.new()
	button.text = "Cancel"
	button.custom_minimum_size = Vector2(140, 64)
	button.add_theme_font_override("font", ToonGui.font())
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.25, 0.12, 0.04))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.98, 0.9, 0.55)
	normal.border_color = Color(0.55, 0.38, 0.14)
	normal.set_border_width_all(4)
	normal.set_corner_radius_all(16)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", normal)
	button.pressed.connect(_cancel)
	return button


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
	button.modulate = Color(0.55, 0.55, 0.55, 0.45) if disabled else Color.WHITE


func _confirm() -> void:
	_BEANS.transfer(_pending)
	_close()


func _cancel() -> void:
	_close()


func _close() -> void:
	_holding = 0
	finished.emit()
	queue_free()
