class_name Keybinds
extends RefCounted

## The Controls page of the Shticker Book. Movement reads these keys, and the
## book writes them to disk so a rebind survives closing the game.
## The same page has a Controller list. The left stick still walks and the
## right stick still orbits. Every other pad control is one of these binds.
## An axis bind is stored as 1000 plus the axis index so it cannot collide
## with a button index.

const _PATH := "user://keybinds.cfg"
const _AXIS := 1000

const ACTIONS: PackedStringArray = ["forward", "back", "left", "right", "jump", "book", "gags", "tasks", "speedchat", "position", "metrics"]
const LABELS: PackedStringArray = [
	"Move Up", "Move Down", "Move Left", "Move Right", "Jump", "Shticker Book", "Gags", "ToonTasks", "SpeedChat++", "Position", "Metrics",
]
const DEFAULTS: Array[int] = [KEY_W, KEY_S, KEY_A, KEY_D, KEY_CTRL, KEY_I, KEY_HOME, KEY_END, KEY_T, KEY_F1, KEY_F2]

const PAD_ACTIONS: PackedStringArray = ["forward", "back", "left", "right", "jump", "use", "book", "gags", "tasks", "speedchat", "aim", "cancel", "position", "metrics"]
const PAD_LABELS: PackedStringArray = [
	"Move Up", "Move Down", "Move Left", "Move Right", "Jump", "Use", "Shticker Book", "Gags", "ToonTasks", "SpeedChat++", "Aim", "Back", "Position", "Metrics",
]
const PAD_DEFAULTS: Array[int] = [
	int(JOY_BUTTON_DPAD_UP), int(JOY_BUTTON_DPAD_DOWN), int(JOY_BUTTON_DPAD_LEFT), int(JOY_BUTTON_DPAD_RIGHT),
	int(JOY_BUTTON_A), int(JOY_BUTTON_Y), int(JOY_BUTTON_START), int(JOY_BUTTON_LEFT_SHOULDER), int(JOY_BUTTON_RIGHT_SHOULDER),
	int(JOY_BUTTON_X), _AXIS + int(JOY_AXIS_TRIGGER_RIGHT), int(JOY_BUTTON_B), -1, -1,
]

const _DEAD := 0.22

static var _keys: Dictionary = {}
static var _pad: Dictionary = {}
static var _axis_high: Dictionary = {}
static var _ready := false


static func held(action: String) -> bool:
	_ensure()
	if typing():
		return false
	if Input.is_physical_key_pressed(_code(action)):
		return true
	if _pointer() and (action == "forward" or action == "back" or action == "left" or action == "right" or action == "jump"):
		return false
	if _pad_pressed(action):
		return true
	return _direction_down(action)


## Right stick, after the deadzone. X is right, Y is down.
static func look() -> Vector2:
	if typing():
		return Vector2.ZERO
	return Vector2(_axis(JOY_AXIS_RIGHT_X), _axis(JOY_AXIS_RIGHT_Y))


## Right mouse button, or the bound Aim control. Held, side steps run across the camera.
static func aim_held() -> bool:
	if typing():
		return false
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return true
	_ensure()
	return _pad_pressed("aim")


## The E key, or the bound Use button. Cranes and golf tees use it.
static func use_held() -> bool:
	if typing():
		return false
	if Input.is_physical_key_pressed(KEY_E):
		return true
	_ensure()
	return _pad_pressed("use")


static func event_is_cancel(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return false
		return key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE
	_ensure()
	if event is InputEventJoypadMotion:
		if not matches(event, "cancel"):
			return false
		return _axis_edge(event as InputEventJoypadMotion)
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if not button.pressed:
			return false
		var code := _pad_code("cancel")
		return code >= 0 and code < _AXIS and code == int(button.button_index)
	return false


## SpeedChat and the name box keep the letters. Polling the key would walk
## the toon on every W, A, S, or D in the sentence.
static func typing() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var focused := tree.root.gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit


static func event_is(event: InputEvent, action: String) -> bool:
	if typing():
		return false
	if event is InputEventKey and not (event as InputEventKey).pressed:
		return false
	if event is InputEventJoypadButton and not (event as InputEventJoypadButton).pressed:
		return false
	if event is InputEventJoypadMotion:
		if not matches(event, action):
			return false
		return _axis_edge(event as InputEventJoypadMotion)
	if not (event is InputEventKey) and not (event is InputEventJoypadButton):
		return false
	return matches(event, action)


## Press or release. The gag and ToonTask panels stay up for as long as the key is held.
static func matches(event: InputEvent, action: String) -> bool:
	_ensure()
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		var code := _pad_code(action)
		return code >= 0 and code < _AXIS and code == int(button.button_index)
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var code := _pad_code(action)
		return code >= _AXIS and code - _AXIS == int(motion.axis)
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	if key.echo:
		return false
	var keycode := key.physical_keycode
	if keycode == KEY_NONE:
		keycode = key.keycode
	return _normalize(keycode) == _code(action)


static func label(action: String) -> String:
	_ensure()
	return OS.get_keycode_string(_code(action))


static func pad_label(action: String) -> String:
	_ensure()
	var code := _pad_code(action)
	if code < 0:
		return "None"
	if code >= _AXIS:
		return _axis_name(code - _AXIS)
	return _button_name(code)


static func assign(action: String, keycode: Key) -> void:
	_ensure()
	if not ACTIONS.has(action):
		return
	var chosen := _normalize(keycode)
	if chosen == KEY_NONE or chosen == KEY_ESCAPE:
		return
	var previous := _code(action)
	for other in ACTIONS:
		if other != action and _code(other) == chosen:
			_keys[other] = previous
	_keys[action] = chosen
	_save()


static func pad_axis(axis: JoyAxis) -> int:
	return _AXIS + int(axis)


static func clear_pad(action: String) -> void:
	_ensure()
	if not PAD_ACTIONS.has(action):
		return
	_pad[action] = -1
	_save()


static func restore_pad() -> void:
	_ensure()
	for index in PAD_ACTIONS.size():
		_pad[PAD_ACTIONS[index]] = PAD_DEFAULTS[index]
	_save()


static func assign_pad(action: String, code: int) -> void:
	_ensure()
	if not PAD_ACTIONS.has(action) or code < 0:
		return
	var previous := _pad_code(action)
	for other in PAD_ACTIONS:
		if other != action and _pad_code(other) == code:
			_pad[other] = previous
	_pad[action] = code
	_save()


## D-pad (or whatever those four actions were rebound to) while a menu cursor is up.
static func pointer_nudge() -> Vector2:
	_ensure()
	var pad := Vector2.ZERO
	if _pad_pressed("left"):
		pad.x -= 1.0
	if _pad_pressed("right"):
		pad.x += 1.0
	if _pad_pressed("forward"):
		pad.y -= 1.0
	if _pad_pressed("back"):
		pad.y += 1.0
	return pad


## The bound Jump control clicks a menu. South does that until Jump is moved.
static func pointer_click(event: InputEvent) -> bool:
	return event_is(event, "jump")


static func _ensure() -> void:
	if _ready:
		return
	_ready = true
	var config := ConfigFile.new()
	config.load(_PATH)
	# Position took F1. A saved Metrics bind that is still F1 moves to F2.
	var had_position := config.has_section_key("keys", "position")
	var metrics_saved := int(config.get_value("keys", "metrics", KEY_F1))
	for index in ACTIONS.size():
		var name := ACTIONS[index]
		if name == "metrics" and not had_position and metrics_saved == KEY_F1:
			_keys[name] = KEY_F2
		else:
			_keys[name] = int(config.get_value("keys", name, DEFAULTS[index]))
	for index in PAD_ACTIONS.size():
		var pad_name := PAD_ACTIONS[index]
		_pad[pad_name] = int(config.get_value("pad", pad_name, PAD_DEFAULTS[index]))


static func _save() -> void:
	var config := ConfigFile.new()
	config.load(_PATH)
	for name in ACTIONS:
		config.set_value("keys", name, _code(name))
	for name in PAD_ACTIONS:
		config.set_value("pad", name, _pad_code(name))
	config.save(_PATH)


static func _code(action: String) -> Key:
	return _normalize(int(_keys.get(action, KEY_NONE)) as Key)


static func _pad_code(action: String) -> int:
	return int(_pad.get(action, -1))


static func _normalize(keycode: Key) -> Key:
	return keycode


static func _pointer() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var cursor := tree.root.get_node_or_null("ToonCursor")
	if cursor == null or not cursor.has_method("pointer_active"):
		return false
	return bool(cursor.call("pointer_active"))


static func _direction_down(action: String) -> bool:
	var stick := Vector2(_axis(JOY_AXIS_LEFT_X), _axis(JOY_AXIS_LEFT_Y))
	if action == "forward":
		return stick.y < -_DEAD
	if action == "back":
		return stick.y > _DEAD
	if action == "left":
		return stick.x < -_DEAD
	if action == "right":
		return stick.x > _DEAD
	return false


static func _pad_pressed(action: String) -> bool:
	var code := _pad_code(action)
	if code < 0:
		return false
	if code >= _AXIS:
		return _axis((code - _AXIS) as JoyAxis) > 0.45
	return _pad_down(code)


static func _axis_edge(motion: InputEventJoypadMotion) -> bool:
	var axis := int(motion.axis)
	var high := motion.axis_value > 0.55
	var was := bool(_axis_high.get(axis, false))
	if motion.axis_value < 0.35:
		_axis_high[axis] = false
		return false
	if high and not was:
		_axis_high[axis] = true
		return true
	return false


static func _pad_down(button: int) -> bool:
	for id in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(id, button as JoyButton):
			return true
	return false


static func _axis(axis: JoyAxis) -> float:
	var best := 0.0
	for id in Input.get_connected_joypads():
		var value := Input.get_joy_axis(id, axis)
		if absf(value) > absf(best):
			best = value
	if absf(best) < _DEAD:
		return 0.0
	return best


static func _button_name(button: int) -> String:
	match button:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_BACK:
			return "Back"
		JOY_BUTTON_GUIDE:
			return "Guide"
		JOY_BUTTON_START:
			return "Start"
		JOY_BUTTON_LEFT_STICK:
			return "Left Stick"
		JOY_BUTTON_RIGHT_STICK:
			return "Right Stick"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		JOY_BUTTON_DPAD_UP:
			return "D-pad Up"
		JOY_BUTTON_DPAD_DOWN:
			return "D-pad Down"
		JOY_BUTTON_DPAD_LEFT:
			return "D-pad Left"
		JOY_BUTTON_DPAD_RIGHT:
			return "D-pad Right"
		JOY_BUTTON_TOUCHPAD:
			return "Touchpad"
		_:
			if button >= JOY_BUTTON_PADDLE1 and button <= JOY_BUTTON_PADDLE4:
				return "Paddle %d" % (button - int(JOY_BUTTON_PADDLE1) + 1)
			return "Button %d" % button


static func _axis_name(axis: int) -> String:
	match axis:
		JOY_AXIS_TRIGGER_LEFT:
			return "Left Trigger"
		JOY_AXIS_TRIGGER_RIGHT:
			return "Right Trigger"
		_:
			return "Axis %d" % axis
