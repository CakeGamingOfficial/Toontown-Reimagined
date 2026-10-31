extends "res://scenes/trolley/trolley_minigame.gd"

## Catching Game. The two-player treehouse, apple, and anvil models.
## This round always drops apples, matching the rules text.

var _fruits: Array[Dictionary] = []
var _spawned := 0
var _next := 0.6
var _stun := 0.0
var _px := 0.0
const _GOAL := 18


func _init() -> void:
	title = "Catching Game"
	instructions = "Catch as many apples as you can. Watch out for the Cogs, and try not to 'catch' any anvils!"
	duration = 55.0


func _build() -> void:
	_show("res://assets/minigames/treehouse.glb")
	var toon := _make_toon(_panda(0.0, 0.0, 0.0))
	toon.rotation_degrees.y = 180.0
	_flunky(0.0, 8.0, 5.0)
	_aim(0.0, -29.36, 28.17, 0.0, 0.0, 4.0)
	show_board("avatar")


func _play(delta: float) -> void:
	var move := _stick().x
	if _stun > 0.0:
		_stun -= delta
		move = 0.0
	_px = clampf(_px + move * 14.0 * delta, -14.0, 14.0)
	_toon.position = _panda(_px, 0.0, 0.0)
	_toon.rotation_degrees.y = 180.0
	_toon.set_locomotion(move * 8.0, false, false, delta)
	_next -= delta
	if _next <= 0.0 and _spawned < _GOAL + 6:
		_drop()
		_next = 55.0 / float(_GOAL)
	var kept: Array[Dictionary] = []
	for item in _fruits:
		var node := item["node"] as Node3D
		var pos := _to_panda(node.position)
		pos.z -= float(item["speed"]) * delta
		node.position = _panda(pos.x, pos.y, pos.z)
		var caught := pos.z < 1.6 and absf(pos.x - _px) < 1.5
		if caught:
			if bool(item["good"]):
				score += 1
				_sfx("SZ_DD_treasure")
			else:
				score = maxi(score - 1, 0)
				_stun = 0.9
				_sfx("AA_drop_anvil_miss")
				_sfx("MG_cannon_hit_dirt", 0.7)
			node.queue_free()
		elif pos.z > -1.0:
			kept.append(item)
		else:
			if not bool(item["good"]):
				_sfx("AA_drop_anvil_miss", 0.45)
			node.queue_free()
	_fruits = kept


func _drop() -> void:
	_spawned += 1
	var good := _spawned % 5 != 0
	var path := "res://assets/minigames/apple.glb" if good else "res://assets/minigames/anvil.glb"
	var scale := 2.2 if good else 0.35
	var node := _spawn(path, randf_range(-12.0, 12.0), randf_range(-1.5, 1.5), 16.0, scale)
	if node == null:
		node = _ball(0.45, Color(0.9, 0.15, 0.15) if good else Color(0.35, 0.35, 0.4))
		add_child(node)
		node.position = _panda(randf_range(-12.0, 12.0), 0.0, 16.0)
	_fruits.append({"node": node, "good": good, "speed": 7.5 if good else 12.0})


func _to_panda(point: Vector3) -> Vector3:
	return Vector3(point.x, -point.z, point.y)
