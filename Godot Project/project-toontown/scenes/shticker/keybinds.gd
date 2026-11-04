extends RefCounted

## The Controls page of the Shticker Book. Movement reads these keys, and the
## book writes them to disk so a rebind survives closing the game.

const _PATH := "user://keybinds.cfg"

const ACTIONS: PackedStringArray = ["forward", "back", "left", "right", "jump", "book", "gags", "tasks", "position", "metrics"]
const LABELS: PackedStringArray = [
	"Move Up", "Move Down", "Move Left", "Move Right", "Jump", "Shticker Book", "Gags", "ToonTasks", "Position", "Metrics",
]
const DEFAULTS: Array[int] = [KEY_W, KEY_S, KEY_A, KEY_D, KEY_CTRL, KEY_I, KEY_HOME, KEY_END, KEY_F1, KEY_F2]

static var _keys: Dictionary = {}
static var _ready := false


static func held(action: String) -> bool:
	_ensure()
	if typing():
		return false
	return Input.is_physical_key_pressed(_code(action))


## SpeedChat and the name box keep the letters. Polling the key would walk
## the toon on every W, A, S, or D in the sentence.
static func typing() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var focused := tree.root.gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit


static func event_is(event: InputEvent, action: String) -> bool:
	if typing() or not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	if not key.pressed:
		return false
	return matches(event, action)


## Press or release. The gag and ToonTask panels stay up for as long as the key is held.
static func matches(event: InputEvent, action: String) -> bool:
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	if key.echo:
		return false
	_ensure()
	var code := key.physical_keycode
	if code == KEY_NONE:
		code = key.keycode
	return _normalize(code) == _code(action)


static func label(action: String) -> String:
	_ensure()
	return OS.get_keycode_string(_code(action))


static func assign(action: String, keycode: Key) -> void:
	_ensure()
	var chosen := _normalize(keycode)
	if chosen == KEY_NONE or chosen == KEY_ESCAPE:
		return
	var previous := _code(action)
	for other in ACTIONS:
		if other != action and _code(other) == chosen:
			_keys[other] = previous
	_keys[action] = chosen
	var config := ConfigFile.new()
	for name in ACTIONS:
		config.set_value("keys", name, _code(name))
	config.save(_PATH)


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


static func _code(action: String) -> Key:
	return _normalize(int(_keys.get(action, KEY_NONE)) as Key)


static func _normalize(keycode: Key) -> Key:
	return keycode
