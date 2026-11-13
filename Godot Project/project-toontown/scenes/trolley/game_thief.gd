extends "res://scenes/trolley/trolley_minigame.gd"

## Cog Thief. Four gag tanks sit on cogthief_game. Cogs walk them off the stage.
## A pie sends that Cog home for 8 seconds. The jar climbs from 3 to 20 with the
## clock. Saving every barrel adds the perfect bonus. The ride still multiplies it.

const _TYPES: PackedStringArray = ["ds", "ac", "bc", "ms"]
const _ZONES: Array[int] = [2000, 1000, 5000, 4000, 3000, 9000]
const _COG_COUNTS: Array[int] = [5, 7, 9, 11]
const _COG_SPEEDS: Array[float] = [6.0, 6.4, 6.8, 7.2, 7.6, 8.0]
const _PERFECT: Array[int] = [8, 6, 4, 2]
const _STARTS: Array[Vector2] = [
	Vector2(35, 18), Vector2(35, 0), Vector2(35, -18),
	Vector2(-35, 18), Vector2(-35, 0), Vector2(-35, -18),
	Vector2(0, 27), Vector2(0, -27),
	Vector2(35, 9), Vector2(-35, 9), Vector2(35, -9), Vector2(-35, -9),
]
const _RETURNS: Array[Vector2] = [
	Vector2(-35, 28), Vector2(-14, 28), Vector2(14, 28), Vector2(35, 28),
	Vector2(35, 0), Vector2(35, -28), Vector2(-14, -28), Vector2(14, -28),
	Vector2(-35, -28), Vector2(-35, 0),
]
const _TOON_STARTS: Array[Vector2] = [
	Vector2(0, 16), Vector2(0, -16), Vector2(-16, 0), Vector2(16, 0),
]
const _NONE := 0
const _BARREL := 1
const _TOON := 2
const _RUN := 3
const _HOME_WAIT := 8.0
const _LENGTH := 60.0

var _barrels: Array[Node3D] = []
var _spots: Array[Vector2] = []
var _stolen: Array[bool] = []
var _carried: Array[int] = []
var _cogs: Array[Dictionary] = []
var _cog_speed := 6.0
var _walk_fps := 24.0
var _pie: Node3D
var _pie_vel := Vector3.ZERO
var _pie_life := 0.0
var _cool := 0.0
var _px := 0.0
var _py := 16.0
var _face := Vector2(0, -1)
var _start := Vector2(0, 16)
var _knock := 0.0
var _knock_from := Vector2.ZERO
var _knock_span := 1.0


func _init() -> void:
	title = "Cog Thief"
	instructions = "Keep the Cogs from stealing our gag barrels! Press the Ctrl key to throw a pie. Use the arrow keys to move. Tip: you can move diagonally."
	duration = _LENGTH


func _build() -> void:
	_show("res://assets/minigames/cogthief.glb")
	var spots := [Vector2(4.3, 4.0), Vector2(4.3, -4.0), Vector2(-4.3, 4.0), Vector2(-4.3, -4.0)]
	for spot in spots:
		var barrel := _spawn("res://assets/minigames/gag_tank.glb", spot.x, spot.y, 0.0, 0.25)
		if barrel == null:
			barrel = _box(Vector3(1.1, 1.4, 1.1), Color(0.45, 0.28, 0.12))
			add_child(barrel)
			barrel.position = _panda(spot.x, spot.y, 0.0)
			barrel.scale = Vector3.ONE * 0.25
		_barrels.append(barrel)
		_spots.append(spot)
		_stolen.append(false)
		_carried.append(-1)
	var zone := _ZONES.find(int(_RIDE.hood))
	if zone < 0:
		zone = 0
	_cog_speed = _COG_SPEEDS[zone]
	# CogThief plays walk at cogSpeed / 4, the clip's own walk rate.
	_walk_fps = 24.0 * (_cog_speed / 4.0)
	var timing: Dictionary = {
		"a": {"walk": {"fps": _walk_fps}},
		"b": {"walk": {"fps": _walk_fps}},
		"c": {"walk": {"fps": _walk_fps}},
	}
	var count := _COG_COUNTS[clampi(party_size() - 1, 0, 3)]
	for index in count:
		var home: Vector2 = _STARTS[index]
		var cog := StreetCog.new()
		add_child(cog)
		cog.present(_suit_row(_TYPES[shared_int(_TYPES.size())]), timing)
		cog.set_process(false)
		cog.position = _panda(home.x, home.y, 0.0)
		_cogs.append({
			"node": cog,
			"x": home.x,
			"y": home.y,
			"goal": _NONE,
			"goal_id": -1,
			"barrel": -1,
			"wait": 0.0,
		})
		_choose(index)
	_start = _TOON_STARTS[clampi(party_index(), 0, 3)]
	_px = _start.x
	_py = _start.y
	_make_toon(_panda(_px, _py, 0.0))
	_camera.position = _panda(0.0, 0.0, 55.0)
	_camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	score = 3
	show_board("jar")


func _play(delta: float) -> void:
	_move_toon(delta)
	_throw_pie(delta)
	_move_cogs(delta)
	_fly_pie(delta)
	score = _beans(clampf(_LENGTH - duration, 0.0, _LENGTH))
	if _saved() == 0:
		_end()


func _end() -> void:
	if _over:
		return
	var lived := clampf(_LENGTH - duration, 0.0, _LENGTH)
	score = _beans(lived)
	if _saved() == _barrels.size():
		score += _PERFECT[clampi(party_size() - 1, 0, 3)]
	super._end()


func _beans(lived: float) -> int:
	# calcScore. Three beans at the start, twenty if the barrels last the minute.
	return int(17.0 * (lived / _LENGTH) + 3.0 + 0.5)


func _saved() -> int:
	var left := 0
	for taken in _stolen:
		if not taken:
			left += 1
	return left


func _move_toon(delta: float) -> void:
	if _knock > 0.0:
		_knock = maxf(_knock - delta, 0.0)
		var along := 1.0 - clampf(_knock / maxf(_knock_span, 0.01), 0.0, 1.0)
		var pos := _knock_from.lerp(_start, along)
		_px = pos.x
		_py = pos.y
		_toon.position = _panda(_px, _py, 0.0)
		if _toon.has_method("pose_action"):
			_toon.pose_action("slip-backward", minf(along, 1.0))
		if _knock == 0.0 and _toon.has_method("release_pose"):
			_toon.release_pose()
		return
	var wish := _stick()
	if wish.length() > 1.0:
		wish = wish.normalized()
	if wish.length_squared() > 0.01:
		_face = wish
	_px = clampf(_px + wish.x * 9.0 * delta, -25.0, 25.0)
	_py = clampf(_py + wish.y * 9.0 * delta, -18.0, 18.0)
	_toon.position = _panda(_px, _py, 0.0)
	_toon.rotation_degrees.y = rad_to_deg(atan2(-_face.x, _face.y))
	_toon.set_locomotion(9.0 if wish.length_squared() > 0.01 else 0.0, false, false, delta)


func _throw_pie(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)
	if _knock > 0.0 or _pie != null or _cool > 0.0:
		return
	if not Keybinds.held("jump"):
		return
	_cool = 1.0
	_sfx("AA_pie_throw_only")
	_pie = _spawn("res://assets/minigames/tart.glb", _px, _py, 2.2, 0.9)
	if _pie == null:
		_pie = _ball(0.25, Color(0.95, 0.75, 0.7))
		add_child(_pie)
		_pie.position = _panda(_px, _py, 2.2)
	var aim := _face
	if aim.length() < 0.1:
		aim = Vector2(0, -1)
	aim = aim.normalized() * 60.0
	_pie_vel = Vector3(aim.x, 0.0, -aim.y)
	_pie_life = 6.0


func _fly_pie(delta: float) -> void:
	if _pie == null:
		return
	_pie.position += _pie_vel * delta
	_pie_life -= delta
	var hit := -1
	for index in _cogs.size():
		var cog: Dictionary = _cogs[index]
		if float(cog["wait"]) > 0.0:
			continue
		var gap := Vector2(float(cog["x"]) - _px_of(_pie), float(cog["y"]) - _py_of(_pie)).length()
		if gap < 1.75:
			hit = index
			break
	if hit >= 0:
		_sfx("AA_wholepie_only", 0.8)
		_send_home(hit, true)
		_pie.queue_free()
		_pie = null
	elif _pie_life <= 0.0 or _pie.position.length() > 120.0:
		_pie.queue_free()
		_pie = null


func _move_cogs(delta: float) -> void:
	for index in _cogs.size():
		var cog: Dictionary = _cogs[index]
		var suit := cog["node"] as StreetCog
		if float(cog["wait"]) > 0.0:
			cog["wait"] = float(cog["wait"]) - delta
			if float(cog["wait"]) <= 0.0:
				cog["wait"] = 0.0
				_choose(index)
			if suit != null:
				suit._idle(delta)
			continue
		var goal := int(cog["goal"])
		if goal == _NONE:
			_choose(index)
			goal = int(cog["goal"])
		var dest := _goal_point(cog)
		if goal == _BARREL and not _barrel_open(int(cog["goal_id"])):
			_choose(index)
			dest = _goal_point(cog)
			goal = int(cog["goal"])
		var here := Vector2(float(cog["x"]), float(cog["y"]))
		var step := dest - here
		var dist := step.length()
		if dist > 0.05:
			var walk := step / dist * minf(_cog_speed * delta, dist)
			here += walk
			cog["x"] = here.x
			cog["y"] = here.y
			if suit != null:
				suit.position = _panda(here.x, here.y, 0.0)
				suit.rotation_degrees.y = rad_to_deg(atan2(-walk.x, walk.y))
				suit._march(delta)
		elif suit != null:
			suit._idle(delta)
		_carry_barrel(cog)
		if goal == _BARREL and dist < 2.2 and _barrel_open(int(cog["goal_id"])):
			_pick_up(index)
		elif goal == _RUN and dist < 0.4:
			_steal(index)
		elif goal == _TOON and _knock <= 0.0 and here.distance_to(Vector2(_px, _py)) < 1.7:
			_bump(index)


func _choose(index: int) -> void:
	var cog: Dictionary = _cogs[index]
	var here := Vector2(float(cog["x"]), float(cog["y"]))
	var barrel := _closest_open(here, index)
	if barrel >= 0:
		cog["goal"] = _BARREL
		cog["goal_id"] = barrel
		return
	cog["goal"] = _TOON
	cog["goal_id"] = 0


func _goal_point(cog: Dictionary) -> Vector2:
	var goal := int(cog["goal"])
	var goal_id := int(cog["goal_id"])
	if goal == _BARREL and goal_id >= 0 and goal_id < _spots.size():
		return _spots[goal_id]
	if goal == _RUN and goal_id >= 0 and goal_id < _RETURNS.size():
		return _RETURNS[goal_id]
	return Vector2(_px, _py)


func _closest_open(here: Vector2, seeker: int) -> int:
	var best := -1
	var gap := 10000.0
	for index in _spots.size():
		if not _barrel_open(index) or _wanted(index, seeker):
			continue
		var dist := here.distance_to(_spots[index])
		if dist < gap:
			gap = dist
			best = index
	return best


func _wanted(barrel: int, except_index: int) -> bool:
	for index in _cogs.size():
		if index == except_index:
			continue
		var cog: Dictionary = _cogs[index]
		if int(cog["goal"]) == _BARREL and int(cog["goal_id"]) == barrel:
			return true
	return false


func _barrel_open(index: int) -> bool:
	if index < 0 or index >= _stolen.size():
		return false
	return not _stolen[index] and _carried[index] < 0


func _pick_up(index: int) -> void:
	var cog: Dictionary = _cogs[index]
	var barrel := int(cog["goal_id"])
	if not _barrel_open(barrel):
		_choose(index)
		return
	_carried[barrel] = index
	cog["barrel"] = barrel
	cog["goal"] = _RUN
	cog["goal_id"] = _nearest_return(Vector2(float(cog["x"]), float(cog["y"])))


func _carry_barrel(cog: Dictionary) -> void:
	var barrel := int(cog["barrel"])
	if barrel < 0 or barrel >= _barrels.size():
		return
	var suit := cog["node"] as Node3D
	if suit == null:
		return
	_barrels[barrel].position = suit.position + suit.transform.basis * Vector3(0.0, 1.5, 1.0)


func _steal(index: int) -> void:
	var cog: Dictionary = _cogs[index]
	var barrel := int(cog["barrel"])
	if barrel >= 0 and barrel < _stolen.size():
		_stolen[barrel] = true
		_carried[barrel] = -1
		_barrels[barrel].visible = false
		_sfx("SZ_DD_treasure", 0.5)
	_park(index, 0.5)


func _send_home(index: int, from_pie: bool) -> void:
	var cog: Dictionary = _cogs[index]
	var barrel := int(cog["barrel"])
	if barrel >= 0 and barrel < _barrels.size() and not _stolen[barrel]:
		_carried[barrel] = -1
		_spots[barrel] = Vector2(float(cog["x"]), float(cog["y"]))
		_barrels[barrel].position = _panda(_spots[barrel].x, _spots[barrel].y, 0.0)
	if not from_pie:
		_sfx("MG_Tag_C", 0.7)
	_park(index, _HOME_WAIT)


func _bump(index: int) -> void:
	_knock_from = Vector2(_px, _py)
	_knock_span = 1.2
	_knock = _knock_span
	_sfx("MG_cannon_hit_dirt", 0.7)
	_send_home(index, false)


func _park(index: int, wait: float) -> void:
	var cog: Dictionary = _cogs[index]
	var home: Vector2 = _STARTS[index]
	cog["x"] = home.x
	cog["y"] = home.y
	cog["goal"] = _NONE
	cog["goal_id"] = -1
	cog["barrel"] = -1
	cog["wait"] = wait
	var suit := cog["node"] as Node3D
	if suit != null:
		suit.position = _panda(home.x, home.y, 0.0)


func _nearest_return(here: Vector2) -> int:
	var best := 0
	var gap := 10000.0
	for index in _RETURNS.size():
		var dist := here.distance_to(_RETURNS[index])
		if dist < gap:
			gap = dist
			best = index
	return best


func _suit_row(code: String) -> Dictionary:
	for item in CogCatalog.cog_rows():
		if item is Dictionary and String((item as Dictionary).get("code", "")) == code:
			return (item as Dictionary).duplicate()
	return {"code": code, "name": code, "dept": "c", "body": "c", "height": 4.0}


func _px_of(node: Node3D) -> float:
	return node.position.x


func _py_of(node: Node3D) -> float:
	return -node.position.z
