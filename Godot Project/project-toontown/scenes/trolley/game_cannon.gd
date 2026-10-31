extends "res://scenes/trolley/trolley_minigame.gd"

## Cannon Game. The base yaws and the barrel pitches, the way DistributedCannonGame
## updates the toon_cannon model. The aim camera sits behind the cannon, level,
## so the barrel shows where the shot will go.

const _CANNON_Y := -130.0
const _CANNON_Z := 20.0
const _TOWER_Y := 40.0
const _TOWER_HEIGHT := 43.85
const _VELOCITY := 94.0
const _GRAVITY := 32.0
const _PULL_MIN := 20.0
const _PULL_MAX := 40.0
const _LOOK_OFFSET := 80.0
const _TOWER_NEAR := 150.0

var _yaw := 0.0
var _pitch := 10.0
var _flying := false
var _vel := Vector3.ZERO
var _shot: Node3D
var _tower := Vector3.ZERO
var _cannon: Node3D
var _barrel: Node3D
var _muzzle: Node3D
var _elapsed := 0.0
var _adjust := 0.0
var _pullback := _PULL_MIN


func _init() -> void:
	title = "Cannon Game"
	instructions = "Shoot your toon into the water tower as quickly as you can. Use the mouse or the arrow keys to aim the cannon. Be quick and win a big reward for everyone!"
	duration = 90.0


func _build() -> void:
	_show("res://assets/minigames/cannon_set.glb")
	_tower = _panda(0.0, _TOWER_Y, 0.0)
	# The glb root already stands the model up. A holder yaws the whole cannon
	# so that basis stays put, and only the barrel node takes the pitch.
	var model := _prop("res://assets/minigames/toon_cannon.glb")
	_cannon = Node3D.new()
	_cannon.name = "CannonRig"
	add_child(_cannon)
	_cannon.position = _panda(0.0, _CANNON_Y, _CANNON_Z)
	if model != null:
		_cannon.add_child(model)
		_barrel = model.find_child("cannon", true, false) as Node3D
	if _barrel != null:
		_muzzle = Node3D.new()
		_muzzle.name = "Muzzle"
		_barrel.add_child(_muzzle)
		# ToonHead sits at the mouth of the barrel.
		_muzzle.position = Vector3(0.0, 6.0, 0.0)
	_make_toon(_panda(0.0, _CANNON_Y, _CANNON_Z))
	_shot = _toon
	_pose_cannon()
	_seat()
	_aim_view()
	show_board("jar")


func _play(delta: float) -> void:
	_elapsed += delta
	if not _flying:
		var move := _stick()
		# Left increases heading. Up increases the barrel angle.
		_yaw = clampf(_yaw - move.x * 15.0 * delta, -20.0, 20.0)
		_pitch = clampf(_pitch + move.y * 15.0 * delta, 10.0, 85.0)
		_pose_cannon()
		_seat()
		_aim_view()
		if absf(move.x) + absf(move.y) > 0.1:
			_adjust -= delta
			if _adjust <= 0.0:
				_adjust = 0.28
				_sfx("MG_cannon_adjust", 0.45)
		if Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_CTRL):
			_launch()
	else:
		_vel.y -= _GRAVITY * delta
		_shot.position += _vel * delta
		_flight_view()
		var flat := Vector2(_shot.position.x - _tower.x, _shot.position.z - _tower.z)
		if flat.length() < 10.5 and _shot.position.y >= 32.0 and _shot.position.y <= 50.0:
			var ratio := clampf(_elapsed / 90.0, 0.0, 1.0)
			score = int(round(23.0 - 18.0 * ratio))
			_sfx("MG_cannon_splash")
			_sfx("MG_cannon_hit_tower")
			_sfx("MG_win", 0.8)
			_end()
		elif flat.length() < 8.0 and _shot.position.y > 2.0 and _shot.position.y < 32.0:
			_bonk(true)
		elif _shot.position.y < 1.0:
			_bonk(false)


func _pose_cannon() -> void:
	if _cannon != null:
		_cannon.rotation_degrees = Vector3(0.0, _yaw, 0.0)
	if _barrel != null:
		_barrel.rotation_degrees = Vector3(_pitch, 0.0, 0.0)


func _seat() -> void:
	if _shot == null:
		return
	if _muzzle != null:
		_shot.global_position = _muzzle.global_position
	elif _cannon != null:
		_shot.position = _cannon.position


## __getCameraPositionBehindCannon / __putCameraBehindCannon. Level, looking down the field.
func _aim_view() -> void:
	_camera.position = _panda(0.0, _CANNON_Y - 25.0, _CANNON_Z + 7.0)
	_camera.rotation = Vector3.ZERO


## The flight camera pulls back from the toon and watches the tower.
func _flight_view() -> void:
	var pos := _to_panda(_shot.global_position)
	var look := Vector3(0.0, _TOWER_Y, -_TOWER_HEIGHT * 0.5)
	var vel := _to_panda(_vel)
	var toward_tower := pos - Vector3(0.0, _TOWER_Y, _TOWER_HEIGHT)
	var dist := toward_tower.length()
	if dist < _TOWER_NEAR and dist > 0.001:
		var perp := Vector3(0.0, 0.0, 1.0).cross(vel)
		if perp.length() > 0.001:
			perp = perp.normalized()
			if toward_tower.dot(perp) > 0.0:
				perp = -perp
			var nearness := 1.0 - dist / _TOWER_NEAR
			var curve := nearness * nearness
			var multiplier := -2.0 * curve * nearness + 3.0 * curve
			look += perp * (multiplier * _LOOK_OFFSET)
			_pullback = maxf(_pullback, _PULL_MIN + multiplier * (_PULL_MAX - _PULL_MIN))
	var away := pos - look
	if away.length() < 0.001:
		return
	var cam := pos + away.normalized() * _pullback
	_camera.global_position = _panda(cam.x, cam.y, cam.z)
	_camera.look_at(_shot.global_position, Vector3.UP)


func _launch() -> void:
	_flying = true
	_pullback = _PULL_MIN
	_sfx("MG_cannon_fire_alt")
	_sfx("MG_cannon_whizz", 0.7)
	var rotation := deg_to_rad(_yaw)
	var angle := deg_to_rad(_pitch)
	var horiz := _VELOCITY * cos(angle)
	var panda_vel := Vector3(horiz * -sin(rotation), horiz * cos(rotation), _VELOCITY * sin(angle))
	_vel = _panda(panda_vel.x, panda_vel.y, panda_vel.z)
	_seat()


func _bonk(tower: bool) -> void:
	_sfx("MG_cannon_hit_tower" if tower else "MG_cannon_hit_dirt")
	_flying = false
	_vel = Vector3.ZERO
	_pose_cannon()
	_seat()
	_aim_view()


func _to_panda(godot: Vector3) -> Vector3:
	return Vector3(godot.x, -godot.z, godot.y)
