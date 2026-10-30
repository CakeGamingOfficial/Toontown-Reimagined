extends RefCounted

## The Controls page of the Shticker Book. Movement reads these keys, and the
## book writes them to disk so a rebind survives closing the game.

const _PATH := "user://keybinds.cfg"

const ACTIONS: PackedStringArray = ["forward", "back", "left", "right", "jump", "book"]
const LABELS: PackedStringArray = [
	"Move Up", "Move Down", "Move Left", "Move Right", "Jump", "Shticker Book",
]
const DEFAULTS: Array[int] = [KEY_W, KEY_S, KEY_A, KEY_D, KEY_CTRL, KEY_I]

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
	if not key.pressed or key.echo:
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
	for index in ACTIONS.size():
		var name := ACTIONS[index]
		_keys[name] = int(config.get_value("keys", name, DEFAULTS[index]))


static func _code(action: String) -> Key:
	return _normalize(int(_keys.get(action, KEY_NONE)) as Key)


static func _normalize(keycode: Key) -> Key:
	return keycode
