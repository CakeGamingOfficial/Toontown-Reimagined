extends "res://scenes/trolley/trolley_minigame.gd"

## Cog Thief. The gag tanks sit on cogthief_game. Keep the Cog off the barrels.

var _barrels: Array[Node3D] = []
var _spots: Array[Vector2] = []
var _stolen: Array[bool] = []
var _cog: Node3D
var _cog_x := 28.0
var _cog_y := 8.0
var _stun := 0.0
var _pie: Node3D
var _pie_vel := Vector3.ZERO
var _cool := 0.0
var _px := 0.0
var _py := 16.0
var _bump := 0.0


func _init() -> void:
	title = "Cog Thief"
	instructions = "Keep the Cogs from stealing our gag barrels! Press the Ctrl key to throw a pie. Use the arrow keys to move. Tip: you can move diagonally."
	duration = 60.0


func _build() -> void:
	_show("res://assets/minigames/cogthief.glb")
	var spots := [Vector2(4.3, 4.0), Vector2(4.3, -4.0), Vector2(-4.3, 4.0), Vector2(-4.3, -4.0)]
	for spot in spots:
		var barrel := _spawn("res://assets/minigames/gag_tank.glb", spot.x, spot.y, 0.0)
		if barrel == null:
			barrel = _box(Vector3(1.1, 1.4, 1.1), Color(0.45, 0.28, 0.12))
			add_child(barrel)
			barrel.position = _panda(spot.x, spot.y, 0.0)
		_barrels.append(barrel)
		_spots.append(spot)
		_stolen.append(false)
	_cog = _flunky(_cog_x, _cog_y, 0.0)
	_make_toon(_panda(_px, _py, 0.0))
	_aim(0.0, -13.66, 13.59, 0.0, 0.0, 0.0)
	score = _barrels.size()
	show_board("jar")


func _play(delta: float) -> void:
	var move := _stick()
	_px = clampf(_px + move.x * 12.0 * delta, -25.0, 25.0)
	_py = clampf(_py + move.y * 12.0 * delta, -18.0, 18.0)
	_toon.position = _panda(_px, _py, 0.0)
	_toon.set_locomotion(move.length() * 8.0, false, false, delta)
	if absf(move.x) > 0.1 or absf(move.y) > 0.1:
		_toon.rotation_degrees.y = rad_to_deg(atan2(-move.x, move.y))
	_cool = maxf(_cool - delta, 0.0)
	if _cool == 0.0 and _pie == null and (Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_SPACE)):
		_cool = 0.55
		_throw()
	if _pie != null:
		_pie.position += _pie_vel * delta
		if _pie.position.distance_to(_cog.position) < 1.6:
			_stun = 2.2
			_sfx("MG_Tag_C", 0.6)
			_pie.queue_free()
			_pie = null
		elif _pie.position.length() > 80.0:
			_pie.queue_free()
			_pie = null
	if _stun > 0.0:
		_stun -= delta
	else:
		var goal := _nearest_barrel()
		if goal >= 0:
			var dest := _spots[goal]
			var step := Vector2(dest.x - _cog_x, dest.y - _cog_y)
			if step.length() < 1.2:
				_stolen[goal] = true
				_barrels[goal].visible = false
				_sfx("SZ_DD_treasure", 0.5)
			elif step.length() > 0.05:
				var walk := step.normalized() * 7.0 * delta
				_cog_x += walk.x
				_cog_y += walk.y
				_cog.rotation_degrees.y = rad_to_deg(atan2(-walk.x, walk.y))
	_cog.position = _panda(_cog_x, _cog_y, 0.0)
	_bump = maxf(_bump - delta, 0.0)
	if _bump == 0.0 and _cog.position.distance_to(_toon.position) < 1.5 and _stun <= 0.0:
		_bump = 0.7
		_px = clampf(_px - signf(_cog_x - _px) * 2.0, -25.0, 25.0)
		_py = clampf(_py - signf(_cog_y - _py) * 2.0, -18.0, 18.0)
		_sfx("MG_cannon_hit_dirt", 0.6)
	var left := 0
	for taken in _stolen:
		if not taken:
			left += 1
	score = left
	if left == 0:
		_end()


func _throw() -> void:
	_sfx("AA_pie_throw_only")
	_pie = _spawn("res://assets/minigames/tart.glb", _px, _py, 1.5, 0.45)
	if _pie == null:
		_pie = _ball(0.25, Color(0.95, 0.75, 0.7))
		add_child(_pie)
		_pie.position = _panda(_px, _py, 1.5)
	var aim := Vector2(_cog_x - _px, _cog_y - _py)
	if aim.length() < 0.1:
		aim = Vector2(0.0, -1.0)
	aim = aim.normalized() * 22.0
	_pie_vel = Vector3(aim.x, 0.0, -aim.y)


func _nearest_barrel() -> int:
	var best := -1
	var gap := 999.0
	for index in _barrels.size():
		if _stolen[index]:
			continue
		var dist := Vector2(_cog_x - _spots[index].x, _cog_y - _spots[index].y).length()
		if dist < gap:
			gap = dist
			best = index
	return best
