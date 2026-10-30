@tool
extends TextureRect

## The chatArrow from the original speedchat sheet. Dialogue that waits for a
## click parks it in the bottom-right corner and blinks it in and out.

const _ARROW := preload("res://assets/gui/speedchat/chatArrow.png")
const _TINT := Color(0.5, 0.5, 1.0)
const _BLINK_MSEC := 450
const _INSET := Vector2(5, 4)

var _host: Control


func _ready() -> void:
	_dress()


func follow(host: Control) -> void:
	_host = host
	_dress()


func _dress() -> void:
	texture = _ARROW
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	size = Vector2(20, 19)
	modulate = _TINT


func _process(_delta: float) -> void:
	if not is_instance_valid(_host):
		queue_free()
		return
	if not visible or not _host.is_visible_in_tree():
		modulate.a = 0.0
		return
	global_position = _host.global_position + _host.size - size - _INSET
	var shown := int(Time.get_ticks_msec() / _BLINK_MSEC) % 2 == 0
	modulate = Color(_TINT.r, _TINT.g, _TINT.b, 1.0 if shown else 0.0)
