extends Node

## Party dance floor. Arrow keys walk the floor and build a code. A code that
## matches a pattern plays that dance. The 10-move floor uses the short list.
## The 20-move floor adds the rest. Walking off the floor leaves.

signal finished(base_beans: int, message: String)

const _SPEED := 9.778
const _TIMEOUT := 1.5
const _FLOOR := 22.0
const _REVERSE: PackedStringArray = ["left", "right", "up", "down", "good-putt"]

const _MOVES: Array = [
	{"code": "dduu", "anim": "slip-backward", "name": "The Backfall", "extra": false},
	{"code": "ldddud", "anim": "happy-dance", "name": "The Happy Dance", "extra": false},
	{"code": "lll", "anim": "left", "name": "Left", "extra": false},
	{"code": "rdu", "anim": "struggle", "name": "The Shuffle Hop", "extra": false},
	{"code": "rrr", "anim": "right", "name": "Right", "extra": false},
	{"code": "rulu", "anim": "running-jump", "name": "The Running Toon", "extra": false},
	{"code": "udlr", "anim": "good-putt", "name": "The Putt", "extra": false},
	{"code": "udllrr", "anim": "victory", "name": "The Victory Dance", "extra": false},
	{"code": "ulu", "anim": "jump", "name": "The Jump!", "extra": false},
	{"code": "uudd", "anim": "slip-forward", "name": "The Fall", "extra": false},
	{"code": "ddd", "anim": "down", "name": "Down", "extra": true},
	{"code": "drul", "anim": "sad-walk", "name": "Tired", "extra": true},
	{"code": "ldr", "anim": "push", "name": "The Mimetoon", "extra": true},
	{"code": "ldu", "anim": "sprinkle-dust", "name": "sprinkle-dust", "extra": true},
	{"code": "llrr", "anim": "firehose", "name": "The Firetoon", "extra": true},
	{"code": "lrlr", "anim": "wave", "name": "Hello Goodbye", "extra": true},
	{"code": "rlrl", "anim": "confused", "name": "Very Dizzy", "extra": true},
	{"code": "uddd", "anim": "reel-neutral", "name": "The Fishertoon", "extra": true},
	{"code": "udud", "anim": "angry", "name": "Rock n' Roll", "extra": true},
	{"code": "uuu", "anim": "up", "name": "Up", "extra": true},
]

var _body: ToonActor
var _origin := Vector3.ZERO
var _wide := false
var _patterns: Array = []
var _limit := 0
var _code := ""
var _since := 0.0
var _move := ""
var _move_left := 0.0
var _age := 0.0
var _up := false
var _down := false
var _left := false
var _right := false
var _esc := false
var _done := false
var _note: Label


func setup(player: ToonActor, origin: Vector3, _party: Dictionary) -> void:
	_body = player
	_origin = origin
	_wide = int(get_meta("act_id", 4)) == 9
	for row in _MOVES:
		var move: Dictionary = row
		if bool(move.get("extra", false)) and not _wide:
			continue
		_patterns.append(move)
		_limit = maxi(_limit, String(move.get("code", "")).length())
	var layer := CanvasLayer.new()
	layer.layer = 24
	add_child(layer)
	_note = Label.new()
	_note.position = Vector2(40, 24)
	_note.size = Vector2(900, 120)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var gui := preload("res://scenes/toons/toon_gui.gd")
	gui.style_label(_note, Color.WHITE, 22, Color.BLACK, 4)
	layer.add_child(_note)
	_paint()


func _process(delta: float) -> void:
	if _done:
		return
	if _body == null or not is_instance_valid(_body):
		_finish()
		return
	_age += delta
	if _move_left > 0.0:
		_move_left = maxf(_move_left - delta, 0.0)
		if _move_left == 0.0:
			_body.clear_gesture()
	var up := Input.is_physical_key_pressed(KEY_UP) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP)
	var down := Input.is_physical_key_pressed(KEY_DOWN) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN)
	var left := Input.is_physical_key_pressed(KEY_LEFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT)
	var right := Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT)
	_tap(up, _up, "u")
	_tap(down, _down, "d")
	_tap(left, _left, "l")
	_tap(right, _right, "r")
	_up = up
	_down = down
	_left = left
	_right = right
	var step := Vector3.ZERO
	if up:
		step.z -= 1.0
	if down:
		step.z += 1.0
	if left:
		step.x -= 1.0
	if right:
		step.x += 1.0
	if step.length() > 0.0 and _move_left <= 0.0:
		step = step.normalized() * _SPEED * delta
		_body.global_position += step
		_body.rotation.y = atan2(step.x, step.z)
	var flat := Vector2(_body.global_position.x, _body.global_position.z).distance_to(Vector2(_origin.x, _origin.z))
	var esc := Input.is_physical_key_pressed(KEY_ESCAPE) or Keybinds.pad_held("cancel")
	if _age > 0.4 and esc and not _esc:
		_finish()
		return
	_esc = esc
	if flat > _FLOOR:
		_finish()
		return
	_paint()


func _tap(down: bool, was: bool, letter: String) -> void:
	if not down or was:
		return
	if _since > 0.0 and _age - _since >= _TIMEOUT:
		_code = ""
	_since = _age
	_code += letter
	var matched := ""
	var anim := ""
	var possible := 0
	for row in _patterns:
		var move: Dictionary = row
		var code := String(move.get("code", ""))
		if code == _code:
			matched = String(move.get("name", ""))
			anim = String(move.get("anim", ""))
		elif code.begins_with(_code):
			possible += 1
	if matched != "":
		_play_move(anim, matched)
		_code = ""
	elif _code.length() >= _limit or possible == 0:
		_code = ""
		_move = ""


func _play_move(anim: String, title: String) -> void:
	_move = title
	if anim == "running-jump":
		anim = "rjump"
	if _body.action_length(anim) <= 0.0:
		return
	var reverse := _REVERSE.has(anim)
	_body.play_gesture(anim, -1.0 if reverse else 1.0, reverse)
	_move_left = 1.6


func _paint() -> void:
	var count := 20 if _wide else 10
	var arrows := _code if _code != "" else "..."
	var found := _move if _move != "" else ""
	_note.text = "Party Dance Floor\nCombine 3 or more ARROW KEY patterns to do dance moves! There are %d dance moves available. Can you find them all?\n%s\n%s" % [count, arrows, found]


func _finish() -> void:
	if _done:
		return
	_done = true
	if _body != null and is_instance_valid(_body):
		_body.clear_gesture()
	finished.emit(0, "")
	queue_free()
