extends "res://scenes/trolley/trolley_minigame.gd"

## Treasure Dive. Roll with left and right, swim toward your head with up,
## and float unless you are carrying a chest. The side camera follows your depth.

const _LANES: Array[Dictionary] = [
	{"z": 25.0, "dir": 1.0},
	{"z": 16.0, "dir": -1.0},
	{"z": 6.0, "dir": 1.0},
	{"z": -4.0, "dir": -1.0},
	{"z": -15.0, "dir": 1.0},
	{"z": -23.0, "dir": -1.0},
]

# clown, PB&J, Bear Acuda, balloon, nurse shark, piano tuna.
# paced travel is multiplied by the hood speed. Bear and nurse are not.
const _KINDS: Array[Dictionary] = [
	{"path": "res://assets/minigames/clownfish.glb", "scale": Vector3.ONE, "radius": 1.2, "travel": 8.0, "paced": true, "cry": "Clownfish", "stay": false},
	{"path": "res://assets/minigames/pbjfish.glb", "scale": Vector3.ONE, "radius": 1.0, "travel": 12.0, "paced": true, "cry": "PBJ_Fish", "stay": false},
	{"path": "res://assets/minigames/bearacuda.glb", "scale": Vector3(0.4, 1.7, 1.7), "radius": 3.0, "travel": 20.0, "paced": false, "cry": "Bear_Acuda", "stay": true},
	{"path": "res://assets/minigames/balloonfish.glb", "scale": Vector3(2.0, 2.0, 2.0), "radius": 0.4, "travel": 10.0, "paced": true, "cry": "BalloonFish", "stay": false},
	{"path": "res://assets/minigames/nurseshark.glb", "scale": Vector3(0.5, 1.7, 1.7), "radius": 1.7, "travel": 20.0, "paced": false, "cry": "Nurse_Shark", "stay": true},
	{"path": "res://assets/minigames/pianotuna.glb", "scale": Vector3(1.4, 1.4, 1.4), "radius": 1.4, "travel": 5.0, "paced": true, "cry": "Piano_Tuna", "stay": false},
]

# Seconds between spawns, one row per hood. Toontown Central through Dreamland.
const _SPAWN_TIME: Array[float] = [3.5, 3.0, 2.5, 2.0, 2.0, 1.5]

# low, high pairs for the six fish, six lanes, six hoods. 100 means that fish never spawns.
const _ODDS: Array = [
	[
		[0.0, 0.8, 0.8, 0.9, 0.9, 1.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0],
		[0.0, 0.8, 0.8, 1.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0],
		[0.0, 0.7, 0.7, 1.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0],
		[0.0, 0.7, 0.7, 0.9, 0.9, 1.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0],
		[0.0, 0.5, 0.5, 1.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0],
		[100.0, 0.5, 0.5, 1.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0],
	],
	[
		[0.0, 0.8, 0.8, 0.9, 0.9, 1.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0],
		[0.0, 0.8, 0.8, 1.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0],
		[0.0, 0.7, 0.7, 1.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0],
		[0.0, 0.7, 0.7, 0.9, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 0.9, 1.0],
		[0.0, 0.4, 0.4, 0.8, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 0.8, 1.0],
		[100.0, 0.3, 0.3, 0.6, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 0.6, 1.0],
	],
	[
		[0.0, 0.7, 0.7, 0.9, 0.9, 1.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0],
		[0.0, 0.6, 0.6, 1.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0],
		[0.0, 0.6, 0.6, 0.8, 100.0, 100.0, 0.8, 1.0, 100.0, 100.0, 100.0, 100.0],
		[0.0, 0.5, 0.5, 0.7, 100.0, 100.0, 0.7, 0.9, 100.0, 100.0, 0.9, 1.0],
		[0.0, 0.2, 0.2, 0.4, 100.0, 100.0, 0.4, 0.75, 100.0, 100.0, 0.75, 1.0],
		[100.0, 0.2, 0.2, 0.6, 100.0, 100.0, 0.6, 0.8, 100.0, 100.0, 0.8, 1.0],
	],
	[
		[0.0, 0.7, 0.7, 0.9, 0.9, 1.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0],
		[0.0, 0.6, 0.6, 1.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0],
		[0.0, 0.6, 0.6, 0.8, 100.0, 100.0, 0.95, 1.0, 100.0, 100.0, 100.0, 100.0],
		[0.0, 0.5, 0.5, 0.7, 100.0, 100.0, 0.7, 0.85, 0.9, 0.95, 0.95, 1.0],
		[0.0, 0.2, 0.2, 0.4, 100.0, 100.0, 0.4, 0.75, 0.75, 0.85, 0.85, 1.0],
		[100.0, 0.2, 0.2, 0.6, 100.0, 100.0, 0.6, 0.8, 100.0, 100.0, 0.8, 1.0],
	],
	[
		[0.0, 0.7, 0.7, 0.9, 0.9, 1.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0],
		[0.0, 0.45, 0.45, 0.9, 100.0, 100.0, 0.9, 1.0, 100.0, 100.0, 100.0, 100.0],
		[0.0, 0.2, 0.2, 0.5, 100.0, 100.0, 0.5, 0.95, 0.95, 1.0, 100.0, 100.0],
		[0.0, 0.1, 0.1, 0.3, 100.0, 100.0, 0.3, 0.75, 0.75, 0.8, 0.8, 1.0],
		[100.0, 100.0, 0.0, 0.15, 100.0, 100.0, 0.15, 0.4, 100.0, 100.0, 0.4, 1.0],
		[100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 0.0, 0.4, 100.0, 100.0, 0.6, 1.0],
	],
	[
		[0.0, 0.7, 0.7, 0.9, 0.9, 1.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0],
		[0.0, 0.45, 0.45, 0.9, 100.0, 100.0, 0.9, 1.0, 100.0, 100.0, 100.0, 100.0],
		[0.0, 0.2, 0.2, 0.5, 100.0, 100.0, 0.5, 0.95, 0.95, 1.0, 100.0, 100.0],
		[0.0, 0.1, 0.1, 0.3, 100.0, 100.0, 0.3, 0.75, 0.75, 0.8, 0.8, 1.0],
		[100.0, 100.0, 0.0, 0.15, 100.0, 100.0, 0.15, 0.4, 100.0, 100.0, 0.4, 1.0],
		[100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 0.0, 0.4, 100.0, 100.0, 0.6, 1.0],
	],
]

var _x := -10.0
var _z := 36.0
var _roll := 0.0
var _xv := 0.0
var _zv := 0.0
var _freeze := 0.0
var _speed := 1.5
var _mix := 0
var _spawn_every := 3.5
var _spawn_wait: Array[float] = []
var _chests: Array[Dictionary] = []
var _carry := -1
var _fish: Array[Dictionary] = []
var _swim: AudioStreamPlayer


func _init() -> void:
	title = "Treasure Dive"
	instructions = "Treasures will appear at the bottom of the lake.  Use the arrow keys to swim.  Avoid the fish and get the treasures up to the boat!"
	duration = 65.0


func begin() -> void:
	super.begin()
	_loop_sfx("AV_ambient_water", 0.2)
	_swim = _loop_sfx("diving_swim_loop", 0.0)


func _build() -> void:
	var pattern := _pattern()
	_speed = float(pattern[1])
	_mix = _hood_mix()
	_spawn_every = _SPAWN_TIME[_mix]
	duration = float(pattern[2])
	var lake := _show("res://assets/minigames/diving_game.glb")
	if lake != null:
		lake.position = _panda(0.0, 0.5, -41.0)
		lake.scale = Vector3(2.8, 2.73, 2.8)
		_place_boat(lake)
	_x = -10.0 + float(party_index()) * 5.0
	_make_toon(_panda(_x, -1.0, _z))
	_toon.pose_swimming(false)
	_toon.play_gesture("swim", 1.0, true)
	_lay_chests()
	for _lane in _LANES:
		_spawn_wait.append(0.0)
	_camera.fov = 45.0
	_camera.far = 1500.0
	_aim_camera()
	show_board("treasure")


func _play(delta: float) -> void:
	var frozen := _freeze > 0.0
	if frozen:
		_freeze = maxf(_freeze - delta, 0.0)
		_toon.play_gesture("cringe", 1.0, true)
	else:
		_steer(delta)
	_xv *= 0.99
	_zv *= 0.99
	_xv = clampf(_xv, -20.0, 20.0)
	_zv = clampf(_zv, -10.0, 10.0)
	_x += _xv * delta
	_z += _zv * delta
	if _carry >= 0:
		_z -= 0.8 * delta
	else:
		_z += 0.8 * delta
	_x = clampf(_x, -20.0, 20.0)
	_z = clampf(_z, -38.0, 36.0)
	_toon.position = _panda(_x, -2.0, _z)
	_toon.rotation_degrees = Vector3(0.0, 0.0, -_roll)
	if not frozen:
		if _carry >= 0:
			_toon.clear_gesture()
			_toon.pose_action("swim", 48.0 / 24.0)
		else:
			_toon.play_gesture("swim", 1.0, true)
	if _swim != null:
		var volume := clampf((absf(_xv) + absf(_zv)) / 15.0, 0.0, 1.0)
		_swim.volume_db = linear_to_db(maxf(volume, 0.001))
	_hold_chest()
	_sink_chests(delta)
	_swim_fish(delta)
	_spawn_fish(delta)
	_touch_chest()
	_touch_fish()
	_touch_boat()
	_aim_camera()


func _steer(delta: float) -> void:
	var move := _stick()
	var spin := 0.0
	if move.x < -0.1:
		spin -= 80.0
	if move.x > 0.1:
		spin += 80.0
	_roll += spin * delta
	var aim := Vector2(sin(deg_to_rad(_roll)), cos(deg_to_rad(_roll)))
	if move.y > 0.1:
		_xv = aim.x * 8.0
		_zv = aim.y * 8.0
	elif move.y < -0.1:
		_xv = -aim.x * 4.0
		_zv = -aim.y * 4.0


func _pattern() -> Array:
	match int(_RIDE.hood):
		1000:
			return [1.0, 1.3, 65.0, 1.0]
		5000:
			return [2.0, 1.2, 65.0, 1.0]
		4000:
			return [2.0, 1.0, 65.0, 1.0]
		3000, 9000:
			return [3.0, 1.0, 65.0, 1.0]
		_:
			return [1.0, 1.5, 65.0, 3.0]


func _hood_mix() -> int:
	match int(_RIDE.hood):
		1000:
			return 1
		5000:
			return 2
		4000:
			return 3
		3000:
			return 4
		9000:
			return 5
		_:
			return 0


func _place_boat(lake: Node3D) -> void:
	var boat := lake.find_child("boat", true, false) as Node3D
	if boat == null:
		return
	boat.reparent(self)
	boat.position = _panda(0.0, 3.0, 33.25)
	boat.scale = Vector3(2.8, 2.8, 2.8)


func _lay_chests() -> void:
	var count := clampi(party_size(), 1, 4)
	for index in count:
		var chest := _spawn("res://assets/minigames/treasure.glb", -15.0 + 10.0 * float(index), 0.25, -36.0, 0.04)
		if chest == null:
			chest = _box(Vector3(1.2, 0.8, 0.8), Color(0.85, 0.65, 0.15))
			add_child(chest)
			chest.position = _panda(-15.0 + 10.0 * float(index), 0.25, -36.0)
		_chests.append({
			"node": chest,
			"x": -15.0 + 10.0 * float(index),
			"z": -36.0,
			"sink": 0.0,
		})


func _hold_chest() -> void:
	if _carry < 0 or _carry >= _chests.size():
		return
	var chest := _chests[_carry]["node"] as Node3D
	if chest == null or not is_instance_valid(chest):
		_carry = -1
		return
	if chest.get_parent() != _toon:
		chest.reparent(_toon)
	chest.position = Vector3(0.0, 1.8, 0.3)
	chest.rotation = Vector3.ZERO


func _sink_chests(delta: float) -> void:
	for item in _chests:
		var sink := float(item["sink"])
		if sink <= 0.0:
			continue
		var z := float(item["z"])
		z = move_toward(z, -36.0, maxf(8.0, (36.0 + z) / 4.0) * delta)
		item["z"] = z
		var chest := item["node"] as Node3D
		if chest != null and is_instance_valid(chest):
			chest.position = _panda(float(item["x"]), 0.25, z)
		if z <= -35.9:
			item["sink"] = 0.0


func _touch_chest() -> void:
	if _carry >= 0 or _freeze > 0.0:
		return
	for index in _chests.size():
		var item: Dictionary = _chests[index]
		if float(item["sink"]) > 0.0:
			continue
		var dx := float(item["x"]) - _x
		var dz := float(item["z"]) - _z
		if dx * dx + dz * dz > 4.0:
			continue
		_carry = index
		item["sink"] = 0.0
		_sfx("diving_treasure_pick_up")
		return


func _touch_boat() -> void:
	if _carry < 0:
		return
	if _z < 28.0 or absf(_x) > 10.0:
		return
	var item: Dictionary = _chests[_carry]
	var chest := item["node"] as Node3D
	_carry = -1
	score += 1
	_sfx("diving_treasure_drop_off")
	var spot := randf_range(-12.0, 12.0)
	item["x"] = spot
	item["z"] = -36.0
	item["sink"] = 0.0
	if chest != null and is_instance_valid(chest):
		chest.reparent(self)
		chest.position = _panda(spot, 0.25, -36.0)
		chest.scale = Vector3.ONE * 0.04


func _spawn_fish(delta: float) -> void:
	for index in _LANES.size():
		_spawn_wait[index] = float(_spawn_wait[index]) - delta
		if _spawn_wait[index] > 0.0:
			continue
		_spawn_wait[index] = _spawn_every + randf_range(-0.5, 1.0)
		var kind := _pick_kind(index)
		if kind < 0:
			continue
		var spec: Dictionary = _KINDS[kind]
		var lane: Dictionary = _LANES[index]
		var dir := float(lane["dir"])
		var start := -30.0 * dir
		var fish := _spawn(String(spec["path"]), start, 0.6, float(lane["z"]), 1.0)
		if fish == null:
			continue
		var sized: Vector3 = spec["scale"]
		fish.scale = sized
		_aim_fish(fish, kind, dir)
		var span := float(spec["travel"]) * 1.25
		if spec["paced"]:
			span *= _speed
		_fish.append({
			"node": fish,
			"kind": kind,
			"x": start,
			"z": float(lane["z"]),
			"z0": float(lane["z"]),
			"start": start,
			"goal": start + 50.0 * dir,
			"dir": dir,
			"span": span,
			"age": 0.0,
			"offset": randf_range(0.0, 9.0),
			"radius": float(spec["radius"]),
			"stay": spec["stay"],
			"cry": spec["cry"],
		})


func _pick_kind(lane: int) -> int:
	var row: Array = _ODDS[_mix][lane]
	var num := randf()
	for kind in 6:
		var low := float(row[kind * 2])
		var high := float(row[kind * 2 + 1])
		if num > low and num <= high:
			return kind
	return -1


func _aim_fish(fish: Node3D, kind: int, dir: float) -> void:
	var heading := 90.0 * dir
	if kind == 1:
		heading = 15.0 * dir
	elif kind == 3:
		heading = 0.0
	elif kind == 5:
		heading = 0.0 if dir < 0.0 else 180.0
	fish.rotation_degrees.y = -heading


func _swim_fish(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for item in _fish:
		var fish := item["node"] as Node3D
		if fish == null or not is_instance_valid(fish):
			continue
		var age := float(item["age"]) + delta
		item["age"] = age
		var span := maxf(float(item["span"]), 0.1)
		var along := clampf(age / span, 0.0, 1.0)
		var x := lerpf(float(item["start"]), float(item["goal"]), along)
		var z := float(item["z0"])
		var kind := int(item["kind"])
		var offset := float(item["offset"])
		if kind == 1:
			var wobble := 5.0 * _speed * 1.25
			z += sin(age / wobble * TAU + offset * 3.0) * 3.0
		elif kind != 2 and kind != 4:
			z = lerpf(z, z + (offset - 4.0) / 2.0, along)
		item["x"] = x
		item["z"] = z
		fish.position = _panda(x, 0.6, z)
		if kind == 3:
			var puffed := _balloon_scale(age, offset)
			fish.scale = puffed
			item["radius"] = 0.2 * puffed.x
		if along < 1.0:
			kept.append(item)
		else:
			fish.queue_free()
	_fish = kept


func _balloon_scale(age: float, offset: float) -> Vector3:
	var wait_in := offset / 10.0 * 2.0 + 1.5
	var cycle := wait_in + 1.7
	var t := fmod(age, cycle)
	var small := Vector3(2.0, 2.0, 2.0)
	var big := Vector3(5.0, 3.0, 5.0)
	if t < wait_in:
		return small
	t -= wait_in
	if t < 0.3:
		return small.lerp(big, t / 0.3)
	t -= 0.3
	if t < 1.0:
		return big
	return big.lerp(small, (t - 1.0) / 0.4)


func _touch_fish() -> void:
	if _freeze > 0.0:
		return
	for item in _fish:
		var dx := float(item["x"]) - _x
		var dz := float(item["z"]) - _z
		var radius := float(item["radius"])
		if dx * dx + dz * dz > radius * radius:
			continue
		_freeze = 3.0
		_xv = 0.0
		_zv = 0.0
		_sfx("diving_game_hit", 0.8)
		_sfx(String(item["cry"]))
		if _carry >= 0:
			var held: Dictionary = _chests[_carry]
			var chest := held["node"] as Node3D
			_carry = -1
			held["x"] = _x
			held["z"] = _z
			held["sink"] = 1.0
			if chest != null and is_instance_valid(chest):
				chest.reparent(self)
				chest.position = _panda(_x, 0.25, _z)
		if item["stay"]:
			return
		var fish := item["node"] as Node3D
		if fish != null:
			fish.queue_free()
		_fish.erase(item)
		return


func _aim_camera() -> void:
	var height := _z + 3.0
	if height < -25.0:
		height = -25.0
	_camera.position = _panda(0.0, -54.0, height)
	var ahead := _camera.position + Vector3(0.0, 0.0, -1.0)
	if _camera.global_position.distance_squared_to(ahead) > 0.04:
		_camera.look_at(ahead, Vector3.UP)
