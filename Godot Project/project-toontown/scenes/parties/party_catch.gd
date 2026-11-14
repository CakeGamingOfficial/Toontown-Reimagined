extends Node3D

## Party catch. The stage is 36 by 36 and the round lasts 80 seconds.
## Fruit and anvils use the three-phase party schedule. Each fruit is one
## jellybean, and a party stops paying after CatchMaxTotalReward.

signal finished(base_beans: int, message: String)

const _KINDS: PackedStringArray = ["apple", "orange", "pear", "coconut", "watermelon", "pineapple"]
const _HALF := 18.0
const _SPEED := 16.0
const _LENGTH := 80.0

var _player: ToonActor
var _party: Dictionary = {}
var _origin := Vector3.ZERO
var _spot := Vector2.ZERO
var _time := 0.0
var _drops: Array[Dictionary] = []
var _next := 0
var _caught := 0
var _fruits := 0
var _winter := false
var _down := 0.0
var _note: Label
var _done := false
var _period := 3.74
var _onscreen := 5.62
var _offscreen := 5.62
var _baseline := 11.23


func setup(player: ToonActor, origin: Vector3, party: Dictionary) -> void:
	_player = player
	_party = party
	_origin = origin
	_winter = int(get_meta("act_id", 3)) == 12
	global_position = origin
	_player.global_position = origin + Vector3(0.0, 0.2, 0.0)
	_schedule()
	_banner()


func holds_camera() -> bool:
	return not _done


func aim(camera: Camera3D) -> void:
	camera.global_position = _origin + Vector3(0.0, 42.0, 28.0)
	camera.look_at(_origin + Vector3(0.0, 0.0, 0.0), Vector3.UP)


func _process(delta: float) -> void:
	if _done or _player == null:
		return
	_time += delta
	_walk(delta)
	_fall(delta)
	_spawn()
	var caught_word := "Presents" if _winter else "Fruit"
	var title := "Present Catch" if _winter else "Party Catch"
	var ask := "Catch the presents. Dodge the anvils." if _winter else "Catch the fruit. Dodge the anvils."
	_note.text = "%s\n%s\n%s: %d    %d" % [title, ask, caught_word, _caught, maxi(int(_LENGTH - _time), 0)]
	if _time < _LENGTH:
		return
	var pending := false
	for drop in _drops:
		if not bool(drop.get("done", false)):
			pending = true
			break
	if not pending:
		_finish()


func _walk(delta: float) -> void:
	if _down > 0.0:
		return
	var move := Vector2.ZERO
	if Keybinds.held("left") or Input.is_physical_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Keybinds.held("right") or Input.is_physical_key_pressed(KEY_RIGHT):
		move.x += 1.0
	if Keybinds.held("forward") or Input.is_physical_key_pressed(KEY_UP):
		move.y -= 1.0
	if Keybinds.held("back") or Input.is_physical_key_pressed(KEY_DOWN):
		move.y += 1.0
	if move.length_squared() > 0.0:
		move = move.normalized()
		_player.rotation_degrees.y = rad_to_deg(atan2(-move.x, -move.y))
		_player.set_locomotion(_SPEED, false, false, delta)
	else:
		_player.set_locomotion(0.0, false, false, delta)
	_spot += move * _SPEED * delta
	_spot.x = clampf(_spot.x, -_HALF, _HALF)
	_spot.y = clampf(_spot.y, -_HALF, _HALF)
	_player.global_position = _origin + Vector3(_spot.x, 0.2, _spot.y)
	_player.set("velocity", Vector3.ZERO)


func _fall(delta: float) -> void:
	if _down > 0.0:
		_down -= delta
		var last := _player.action_length("slip-forward") * 24.0
		if last >= 12.0:
			var along := 1.0 - clampf(_down, 0.0, 1.0)
			_player.pose_action("slip-forward", lerpf(12.0, last, along) / 24.0)
		if _down <= 0.0:
			_player.release_pose()
	for drop in _drops:
		if bool(drop.get("done", false)):
			continue
		var born := float(drop["at"])
		var age := _time - born
		if drop.get("node", null) == null:
			continue
		var node := drop["node"] as Node3D
		if age < _offscreen:
			node.position.y = 28.0
			continue
		var fall := (age - _offscreen) / _onscreen
		if fall >= 1.0:
			_remove(drop, false)
			continue
		var height := 28.0 * (1.0 - fall * fall)
		node.position = Vector3(float(drop["x"]), height, float(drop["z"]))
		_try_catch(drop, height)


func _try_catch(drop: Dictionary, height: float) -> void:
	if height > 3.2:
		return
	var flat := Vector2(float(drop["x"]), float(drop["z"])).distance_to(_spot)
	var reach := 1.8 if String(drop["kind"]) == "anvil" else 2.2
	if flat > reach:
		return
	if String(drop["kind"]) == "anvil":
		_down = 1.0
		_remove(drop, false)
		return
	_caught += 1
	_remove(drop, true)


func _spawn() -> void:
	while _next < _drops.size() and float(_drops[_next]["at"]) <= _time:
		var drop: Dictionary = _drops[_next]
		var node := _model(String(drop["kind"]))
		add_child(node)
		node.position = Vector3(float(drop["x"]), 28.0, float(drop["z"]))
		drop["node"] = node
		_drops[_next] = drop
		_next += 1


func _schedule() -> void:
	var when := 0.0
	var index := 0
	while when < _LENGTH:
		var delay := _period
		if when < 6.0:
			delay *= 1.5
		elif when >= 60.0:
			delay *= 1.0 / 3.0
		when += delay
		if when + _baseline >= _LENGTH + _baseline:
			break
		var fruit := index % 4 != 3
		var kind := "anvil"
		if fruit:
			kind = _KINDS[index % _KINDS.size()]
			_fruits += 1
		var cell := index % 36
		var col := cell % 6
		var row := int(cell / 6)
		_drops.append({
			"at": when,
			"kind": kind,
			"x": lerpf(-_HALF, _HALF, float(col) / 5.0),
			"z": lerpf(-_HALF, _HALF, float(row) / 5.0),
			"done": false,
		})
		index += 1


func _finish() -> void:
	var room := maxi(1000 - int(_party.get("catch", 0)), 0)
	var beans := mini(_caught, room)
	_party["catch"] = int(_party.get("catch", 0)) + beans
	_player.release_pose()
	_player.global_position = _origin + Vector3(0.0, 0.2, _HALF + 3.0)
	_player.set("velocity", Vector3.ZERO)
	_done = true
	var word := "PERFECT GAME!" if _fruits > 0 and _caught >= _fruits else "Good Game!"
	var caught_word := "Presents caught" if _winter else "Pieces of fruit caught"
	var line := "%s\n%s: %d\n\nJellybeans earned: " % [word, caught_word, _caught]
	finished.emit(beans, line + "%d")
	queue_free()


func _remove(drop: Dictionary, _kept: bool) -> void:
	drop["done"] = true
	var node: Variant = drop.get("node", null)
	if node is Node and is_instance_valid(node):
		(node as Node).queue_free()


func _model(kind: String) -> Node3D:
	var packed := load("res://assets/minigames/%s.glb" % kind) as PackedScene
	if packed != null:
		return packed.instantiate() as Node3D
	var stand := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.6
	mesh.height = 1.2
	stand.mesh = mesh
	return stand


func _banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_note = Label.new()
	_note.position = Vector2(40, 40)
	_note.size = Vector2(760, 140)
	ToonGui.style_label(_note, Color.WHITE, 28, Color(0.1, 0.05, 0.2), 4)
	layer.add_child(_note)
