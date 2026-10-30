extends Node

## The pointer from phase_3/models/gui/toonmono.cur. The hotspot is the tip
## stored in that cursor file. Buttons and the chat line keep this picture
## instead of the system hand or text beam.

const _CURSOR := preload("res://assets/gui/toon_cursor.png")
const _HOTSPOT := Vector2(1, 2)


func _ready() -> void:
	Input.set_custom_mouse_cursor(_CURSOR, Input.CURSOR_ARROW, _HOTSPOT)
	Input.set_custom_mouse_cursor(_CURSOR, Input.CURSOR_IBEAM, _HOTSPOT)
	Input.set_custom_mouse_cursor(_CURSOR, Input.CURSOR_POINTING_HAND, _HOTSPOT)
