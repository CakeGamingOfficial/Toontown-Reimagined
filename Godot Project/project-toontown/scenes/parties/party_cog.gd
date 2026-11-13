extends Node

## Cog-O-War. Three cogs stand on the arena. Hold Control to wind the throw,
## then let go. A body hit is 1 point and a head hit is 3. After 90 seconds
## the round pays the original win, tie, or perfect-win jellybeans.

signal finished(base_beans: int, message: String)

const _WIN := 16
const _TIE := 11
const _PERFECT := 20
const _LENGTH := 90.0

var _player: ToonActor
var _origin := Vector3.ZERO
var _lane := 1
var _charge := -1.0
var _score := 0
var _time := 0.0
var _spam := 0
var _since := 1.0
var _push: Array[float] = [0.0, 0.0, 0.0]
var _cogs: Array[Node3D] = []
var _note: Label
var _done := false
var _held := false
var _left_was := false
var _right_was := false


func setup(player: ToonActor, origin: Vector3, _party: Dictionary) -> void:
	_player = player
	_origin = origin
	global_position = origin
	_player.global_position = origin + Vector3(-10.0, 0.2, 0.0)
	_player.rotation_degrees.y = 0.0
	var suits: PackedStringArray = ["f", "tm", "pp"]
	for index in 3:
		var cog := Node3D.new()
		var packed := load("res://assets/cogs/suits/%s.glb" % suits[index]) as PackedScene
		if packed != null:
			cog.add_child(packed.instantiate())
		cog.position = Vector3(6.0, 0.0, lerpf(-8.0, 8.0, float(index) / 2.0))
		cog.rotation_degrees.y = 180.0
		add_child(cog)
		_cogs.append(cog)
	_place_player()
	_banner()


func holds_camera() -> bool:
	return not _done


func aim(camera: Camera3D) -> void:
	camera.global_position = _origin + Vector3(-18.0, 12.0, 16.0)
	camera.look_at(_origin + Vector3(4.0, 2.0, 0.0), Vector3.UP)


func _process(delta: float) -> void:
	if _done or _player == null:
		return
	_time += delta
	_since += delta
	var left_down := Keybinds.held("left") or Input.is_physical_key_pressed(KEY_LEFT)
	var right_down := Keybinds.held("right") or Input.is_physical_key_pressed(KEY_RIGHT)
	if left_down and not _left_was:
		_lane = maxi(_lane - 1, 0)
	elif right_down and not _right_was:
		_lane = mini(_lane + 1, 2)
	_left_was = left_down
	_right_was = right_down
	_place_player()
	var holding := Keybinds.held("jump")
	if holding and _charge < 0.0:
		_charge = 0.0
	if holding and _charge >= 0.0:
		_charge += delta
	elif _held and _charge >= 0.0:
		_throw()
		_charge = -1.0
	_held = holding
	for index in 3:
		_cogs[index].position.x = 6.0 + _push[index] * 18.0
	var power := 0
	if _charge >= 0.0:
		power = int(round(-cos(TAU * _charge) * 50.0 + 50.0))
	_note.text = "Cog-O-War\nLeft and right pick a cog. Hold Control, then let go.\nScore %d    Power %d    %d" % [_score, power, maxi(int(_LENGTH - _time), 0)]
	if _time >= _LENGTH:
		_finish()


func _place_player() -> void:
	_player.global_position = _origin + Vector3(-10.0, 0.2, lerpf(-8.0, 8.0, float(_lane) / 2.0))
	_player.rotation_degrees.y = 0.0
	_player.set("velocity", Vector3.ZERO)


func _throw() -> void:
	var short := _charge <= 0.1
	if short:
		_spam += 1
	else:
		_spam = 0
	if _spam >= 3 or _since < 0.35:
		return
	_since = 0.0
	var power := int(round(-cos(TAU * _charge) * 50.0 + 50.0))
	var want := 30 + _lane * 25
	if absi(power - want) > 18:
		return
	var head := absi(power - want) <= 8
	var points := 3 if head else 1
	var shove := 0.1 if head else 0.05
	_score += points
	_push[_lane] = minf(_push[_lane] + shove, 1.0)
	_player.play_gesture("throw", 1.2, false)


func _finish() -> void:
	var perfect := true
	var moved := false
	for amount in _push:
		if amount < 0.99:
			perfect = false
		if amount > 0.0:
			moved = true
	var beans := _TIE
	var extra := ""
	if perfect:
		beans = _PERFECT
		extra = "\nPerfect! Your team pushed every cog across."
	elif moved:
		beans = _WIN
		extra = "\nYour team won."
	_player.global_position = _origin + Vector3(-14.0, 0.2, 0.0)
	_player.set("velocity", Vector3.ZERO)
	_done = true
	var line := "Your Score: %d\n\nJellybeans earned: " % _score
	finished.emit(beans, line + "%d" + extra)
	queue_free()


func _banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_note = Label.new()
	_note.position = Vector2(40, 40)
	_note.size = Vector2(860, 160)
	ToonGui.style_label(_note, Color.WHITE, 28, Color(0.1, 0.05, 0.2), 4)
	layer.add_child(_note)
