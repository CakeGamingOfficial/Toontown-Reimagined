extends "res://scenes/trolley/trolley_minigame.gd"

## Treasure Dive. The boat and lake are diving_game, treasures are treasure.bam.

var _treasures: Array[Node3D] = []
var _carry: Node3D
var _fish: Node3D
var _fish_dir := 1.0
var _px := 0.0
var _pz := 1.0
var _swim: AudioStreamPlayer
var _ouch := 0.0


func _init() -> void:
	title = "Treasure Dive"
	instructions = "Treasures will appear at the bottom of the lake.  Use the arrow keys to swim.  Avoid the fish and get the treasures up to the boat!"
	duration = 60.0


func begin() -> void:
	super.begin()
	_loop_sfx("AV_ambient_water", 0.4)
	_swim = _loop_sfx("diving_swim_loop", 0.0)


func _build() -> void:
	_show("res://assets/minigames/diving_game.glb")
	for index in 8:
		var gem := _spawn("res://assets/minigames/treasure.glb", -14.0 + float(index) * 4.0, randf_range(-3.0, 3.0), -12.0, 1.4)
		if gem == null:
			gem = _ball(0.35, Color(1, 0.85, 0.15))
			add_child(gem)
			gem.position = _panda(-14.0 + float(index) * 4.0, 0.0, -12.0)
		_treasures.append(gem)
	_fish = _spawn("res://assets/minigames/clownfish.glb", 0.0, 0.0, -6.0, 2.0)
	if _fish == null:
		_fish = _box(Vector3(1.6, 0.7, 0.5), Color(0.85, 0.45, 0.1))
		add_child(_fish)
		_fish.position = _panda(0.0, 0.0, -6.0)
	_make_toon(_panda(0.0, -2.0, 1.0))
	_toon.rotation_degrees.y = -90.0
	_toon.pose_swimming(true)
	_aim(0.0, 26.0, 2.0, 0.0, 0.0, -4.0)
	show_board("treasure")


func _play(delta: float) -> void:
	var move := _stick()
	_px = clampf(_px + move.x * 8.0 * delta, -16.0, 16.0)
	_pz = clampf(_pz + move.y * 7.0 * delta, -16.0, 1.5)
	_toon.position = _panda(_px, -2.0, _pz)
	if move.x > 0.1:
		_toon.rotation_degrees.y = -90.0
	elif move.x < -0.1:
		_toon.rotation_degrees.y = 90.0
	# Carrying a chest holds swim frame 48. The original pose is 55, and this
	# cycle is 49 frames, so that index is the last one. A fish hit plays cringe.
	if _ouch > 0.0:
		_toon.play_gesture("cringe", 1.0, true)
		_toon.set_locomotion(0.0, false, false, delta)
	elif _carry != null:
		_toon.clear_gesture()
		_toon.pose_action("swim", 48.0 / 24.0)
	else:
		_toon.play_gesture("swim", 1.0, true)
		_toon.set_locomotion(0.0, false, false, delta)
	if _swim != null:
		_swim.volume_db = linear_to_db(0.55 if move.length() > 0.1 else 0.001)
	var fish_pos := _to_panda(_fish.position)
	fish_pos.x += _fish_dir * 5.0 * delta
	if absf(fish_pos.x) > 14.0:
		_fish_dir *= -1.0
	_fish.position = _panda(fish_pos.x, 0.0, -6.0)
	_ouch = maxf(_ouch - delta, 0.0)
	if _ouch == 0.0 and _toon.position.distance_to(_fish.position) < 1.8:
		_ouch = 0.8
		_pz = minf(_pz + 2.0, 1.0)
		_carry = null
		_sfx("diving_game_hit", 0.8)
	if _carry == null:
		for gem in _treasures:
			if gem.position.distance_to(_toon.position) < 1.5:
				_carry = gem
				_sfx("diving_treasure_pick_up")
				break
	else:
		_carry.position = _toon.position + Vector3(0.0, 1.2, 0.0)
		if _pz >= -0.2 and absf(_px) < 5.0:
			score += 1
			_sfx("diving_treasure_drop_off")
			_treasures.erase(_carry)
			_carry.queue_free()
			_carry = null
			if _treasures.is_empty():
				_end()
	_aim(_px, 24.0, _pz + 4.0, _px, -2.0, _pz - 2.0)


func _to_panda(point: Vector3) -> Vector3:
	return Vector3(point.x, -point.z, point.y)
