class_name BattleCamera
extends RefCounted

## Every gag fight aims at the original shot. A cut does not fly the whole way
## there: the camera starts a short step off the new framing and coasts in.

const _OMEGA := 3.2
const _SLIDE := 0.7
const _LOOK_SLIDE := 0.45
const _FOV_SLIDE := 3.5
const _JUMP_POS := 1.25
const _JUMP_LOOK := 1.75
const _JUMP_FOV := 5.0
const _HOLD_POS := 0.12
const _HOLD_LOOK := 0.16
const _HOLD_FOV := 0.8

static var _live := false
static var _id := 0
static var _pos := Vector3.ZERO
static var _look := Vector3.ZERO
static var _fov := 52.0
static var _pos_vel := Vector3.ZERO
static var _look_vel := Vector3.ZERO
static var _fov_vel := 0.0
static var _goal_pos := Vector3.ZERO
static var _goal_look := Vector3.ZERO
static var _goal_fov := 52.0


static func glide(camera: Camera3D, pos: Vector3, look: Vector3, fov: float, delta: float) -> void:
	if camera == null:
		return
	var id := camera.get_instance_id()
	if not _live or id != _id:
		_id = id
		_pos = camera.global_position
		var ahead := -camera.global_basis.z
		if ahead.length_squared() < 0.0001:
			ahead = Vector3(0.0, 0.0, -1.0)
		_look = _pos + ahead.normalized() * 6.0
		_fov = camera.fov
		_pos_vel = Vector3.ZERO
		_look_vel = Vector3.ZERO
		_fov_vel = 0.0
		_goal_pos = _pos
		_goal_look = _look
		_goal_fov = _fov
		_live = true
		_begin_near(pos, look, fov)
	elif _goal_jumped(pos, look, fov):
		_begin_near(pos, look, fov)
	if _resting(pos, look, fov):
		_goal_pos = _pos
		_goal_look = _look
		_goal_fov = _fov
	else:
		_goal_pos = pos
		_goal_look = look
		_goal_fov = fov
	var dt := clampf(delta, 0.0, 0.05)
	_coast(dt)
	camera.fov = _fov
	camera.global_position = _pos
	if _pos.distance_squared_to(_look) > 0.04:
		camera.look_at(_look, Vector3.UP)


## The victory view is a cut. A glide here leaves the camera on the battle menu.
static func cut(camera: Camera3D, pos: Vector3, look: Vector3, fov: float) -> void:
	if camera == null:
		return
	_id = camera.get_instance_id()
	_pos = pos
	_look = look
	_fov = fov
	_goal_pos = pos
	_goal_look = look
	_goal_fov = fov
	_pos_vel = Vector3.ZERO
	_look_vel = Vector3.ZERO
	_fov_vel = 0.0
	_live = true
	camera.fov = fov
	camera.global_position = pos
	if _pos.distance_squared_to(_look) > 0.04:
		camera.look_at(_look, Vector3.UP)


static func release() -> void:
	_live = false
	_id = 0
	_pos_vel = Vector3.ZERO
	_look_vel = Vector3.ZERO
	_fov_vel = 0.0


static func _begin_near(pos: Vector3, look: Vector3, fov: float) -> void:
	_pos = pos + (_pos - pos).limit_length(_SLIDE)
	_look = look + (_look - look).limit_length(_LOOK_SLIDE)
	_fov = fov + clampf(_fov - fov, -_FOV_SLIDE, _FOV_SLIDE)
	_pos_vel = Vector3.ZERO
	_look_vel = Vector3.ZERO
	_fov_vel = 0.0


static func _resting(pos: Vector3, look: Vector3, fov: float) -> bool:
	if _pos.distance_squared_to(pos) > _HOLD_POS * _HOLD_POS:
		return false
	if _look.distance_squared_to(look) > _HOLD_LOOK * _HOLD_LOOK:
		return false
	return absf(_fov - fov) <= _HOLD_FOV


static func _goal_jumped(pos: Vector3, look: Vector3, fov: float) -> bool:
	if _goal_pos.distance_squared_to(pos) > _JUMP_POS * _JUMP_POS:
		return true
	if _goal_look.distance_squared_to(look) > _JUMP_LOOK * _JUMP_LOOK:
		return true
	return absf(_goal_fov - fov) > _JUMP_FOV


static func _coast(dt: float) -> void:
	var pull := _OMEGA * _OMEGA
	var drag := 2.0 * _OMEGA
	_pos_vel += (pull * (_goal_pos - _pos) - drag * _pos_vel) * dt
	_pos += _pos_vel * dt
	_look_vel += (pull * (_goal_look - _look) - drag * _look_vel) * dt
	_look += _look_vel * dt
	_fov_vel += (pull * (_goal_fov - _fov) - drag * _fov_vel) * dt
	_fov += _fov_vel * dt
