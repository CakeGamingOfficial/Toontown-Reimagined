extends "res://scenes/trolley/trolley_minigame.gd"

## Cannon Game, from DistributedCannonGame and CannonGameGlobals.
## Aiming shows the toon's head in the barrel. Flight loops swim. The open top of
## the tower is the only score. The sides and the ground send the toon back in.
## The jar counts 23 down to 5 and freezes when a shot will land in the water.

const _CANNON_Y := -130.0
const _CANNON_Z := 20.0
const _CANNON_GAP := 12.0
const _TOWER_Y_RANGE := 200
const _TOWER_HEIGHT := 43.85
const _TOWER_RADIUS := 10.5
const _BUCKET_HEIGHT := 36.0
const _VELOCITY := 94.0
const _GRAVITY := 32.0
const _GAME_TIME := 90.0
const _LAND_TIME := 2.0
const _HEAD_PITCH := -45.0
const _WHISTLE := _VELOCITY * 0.55
const _PULL_MIN := 20.0
const _PULL_MAX := 40.0
const _LOOK_OFFSET := 80.0
const _TOWER_NEAR := 150.0
const _HIT_GROUND := 0
const _HIT_TOWER := 1
const _HIT_WATER := 2
const _AIM := 0
const _FLY := 1
const _LAND := 2

var _yaw := 0.0
var _pitch := 10.0
var _mode := _AIM
var _vel := Vector3.ZERO
var _shot: Node3D
var _tower_x := 0.0
var _tower_y := 40.0
var _cannon: Node3D
var _barrel: Node3D
var _muzzle: Node3D
var _rigs: Array[Node3D] = []
var _barrels: Array = []
var _cannon_x := 0.0
var _aim_sent := -10.0
var _pullback := _PULL_MIN
var _body_scale := 1.0
var _height := 3.0
var _head_local := Vector3.ZERO
var _has_head := false
var _hidden: Array[MeshInstance3D] = []
var _start := Vector3.ZERO
var _launch_vel := Vector3.ZERO
var _launch_at := 0.0
var _impact := 0.0
var _hit := _HIT_GROUND
var _clock_stop := -1.0
var _whistled := false
var _land_left := 0.0
var _slide_from := Vector3.ZERO
var _slide_to := Vector3.ZERO
var _adjust: AudioStreamPlayer
var _whizz: AudioStreamPlayer
var _fire_down := false


func _init() -> void:
	title = "Cannon Game"
	instructions = "Shoot your toon into the water tower as quickly as you can. Use the mouse or the arrow keys to aim the cannon. Be quick and win a big reward for everyone!"
	duration = _GAME_TIME


func _build() -> void:
	var stage := _show("res://assets/minigames/cannon_set.glb")
	_place_tower(stage)
	var count := party_size()
	var mine := clampi(party_index(), 0, count - 1)
	for i in count:
		_add_cannon(i, count)
	_cannon = _rigs[mine]
	_barrel = _barrels[mine] as Node3D
	_muzzle = _cannon.find_child("Muzzle", true, false) as Node3D
	_cannon_x = _slot_x(mine, count)
	_make_toon(_panda(_cannon_x, _CANNON_Y, _CANNON_Z))
	_shot = _toon
	_remember_head()
	if _toon != null:
		_toon.ensure_clip("slip-forward")
		_toon.ensure_clip("swim")
		_toon.ensure_clip("run")
	_pose_cannon()
	_enter_aim()
	show_board("jar")


func begin() -> void:
	super.begin()
	if _board != null:
		_board.prime(_jar_points(0.0))
	_share_aim(true)


func _process(delta: float) -> void:
	_place_tags()
	if _mode == _AIM and _toon != null:
		_toon.set_locomotion(0.0, false, false, delta)
	if not playing:
		return
	duration -= delta
	_layout_clock(false)
	if duration <= 0.0:
		_end()
		return
	_play(delta)
	_note_rider(delta)
	if _over or _board == null:
		return
	_board.sync(_jar_points(_reward_time()))


func _play(delta: float) -> void:
	_pose_others()
	if _mode == _AIM:
		_steer(delta)
	elif _mode == _FLY:
		_fly(delta)
	else:
		_land(delta)


func _steer(delta: float) -> void:
	var move := _stick()
	var before := Vector2(_yaw, _pitch)
	# Left increases heading. Up raises the barrel. Control fires.
	_yaw = clampf(_yaw - move.x * 15.0 * delta, -20.0, 20.0)
	_pitch = clampf(_pitch + move.y * 15.0 * delta, 10.0, 85.0)
	_pose_cannon()
	if not is_equal_approx(before.x, _yaw) or not is_equal_approx(before.y, _pitch):
		_share_aim(false)
		if _adjust == null:
			_adjust = _loop_sfx("MG_cannon_adjust", 0.6)
	elif _adjust != null:
		_adjust.stop()
		_adjust.queue_free()
		_adjust = null
		_share_aim(true)
	var fire := Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_SPACE)
	if fire and not _fire_down:
		_fire_down = true
		_launch()
		return
	_fire_down = fire


func _pose_cannon() -> void:
	if _cannon != null:
		_cannon.rotation_degrees = Vector3(0.0, _yaw, 0.0)
	if _barrel != null:
		_barrel.rotation_degrees = Vector3(_pitch, 0.0, 0.0)


## __loadToonInCannon. The head sits in the mouth. The body stays out of sight.
func _enter_aim() -> void:
	_mode = _AIM
	_vel = Vector3.ZERO
	_pullback = _PULL_MIN
	if _toon != null:
		_toon.end_action("slip-forward")
		_toon.clear_gesture()
		_hide_body()
		_orient_in_cannon()
	_aim_view()


func _remember_head() -> void:
	if _toon == null:
		return
	_body_scale = _toon.transform.basis.get_scale().x
	var style := ToonRoster.selected_style()
	if style != null:
		_height = style.avatar_height()
	var look := _toon.find_child("head_look", true, false) as Node3D
	if look == null:
		return
	_head_local = _toon.to_local(look.global_position)
	_has_head = true


func _orient_in_cannon() -> void:
	if _toon == null or _muzzle == null or not _has_head:
		if _toon != null and _muzzle != null:
			_toon.global_position = _muzzle.global_position
		return
	if _toon.get_parent() != _muzzle:
		_toon.reparent(_muzzle, false)
	var pitch := deg_to_rad(_HEAD_PITCH)
	var face := Vector3(0.0, cos(pitch), sin(pitch))
	var up := Vector3(0.0, -sin(pitch), cos(pitch))
	_toon.basis = Basis(face.cross(up), face, up).scaled(Vector3.ONE * _body_scale)
	_toon.position = -(_toon.basis * _head_local)


func _hide_body() -> void:
	if _toon == null or not _hidden.is_empty():
		return
	var look := _toon.find_child("head_look", true, false)
	for node in _toon.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or not mesh.visible:
			continue
		if look != null and look.is_ancestor_of(mesh):
			continue
		mesh.visible = false
		_hidden.append(mesh)


func _show_body() -> void:
	for mesh in _hidden:
		if is_instance_valid(mesh) and mesh.name != "drop_shadow":
			mesh.visible = true
	_hidden.clear()


func _launch() -> void:
	if _adjust != null:
		_adjust.stop()
		_adjust.queue_free()
		_adjust = null
	_pose_cannon()
	var head := _muzzle.global_position if _muzzle != null else _toon.global_position
	_start = _to_panda(head)
	var rotation := deg_to_rad(_yaw)
	var angle := deg_to_rad(_pitch)
	var horiz := _VELOCITY * cos(angle)
	_launch_vel = Vector3(horiz * -sin(rotation), horiz * cos(rotation), _VELOCITY * sin(angle))
	_launch_at = _elapsed()
	_hit = _predict()
	_impact = _impact_time()
	if _hit == _HIT_WATER:
		_clock_stop = _launch_at + _impact
		score = _raw_score(_clock_stop)
	_show_body()
	if _toon.get_parent() != self:
		_toon.reparent(self, true)
	_toon.play_gesture("swim", 1.0, true)
	_sfx("MG_cannon_fire_alt")
	_share_aim(true)
	_whistled = false
	_mode = _FLY
	_fly(0.0)


func _fly(delta: float) -> void:
	var now := _elapsed() - _launch_at
	var t := minf(now, _impact)
	var panda := _pos_at(t)
	var vel := _vel_at(t)
	_vel = _panda(vel.x, vel.y, vel.z)
	var run := Vector2(vel.x, vel.y).length()
	var theta: float = 0.0 if run < 0.001 else rad_to_deg(atan(vel.z / run))
	_place(panda, _yaw, -90.0 + theta, _height * 0.5)
	_toon.set_locomotion(0.0, false, false, delta)
	_flight_view()
	if not _whistled and -vel.z > _WHISTLE and t < _impact - 0.5:
		_whistled = true
		_whizz = _loop_sfx("MG_cannon_whizz", 0.7)
	if now < _impact:
		return
	_arrive()


func _arrive() -> void:
	if _whizz != null:
		_whizz.stop()
		_whizz.queue_free()
		_whizz = null
	_land_left = _LAND_TIME
	_mode = _LAND
	if _hit == _HIT_WATER:
		_toon.clear_gesture()
		_place(_pos_at(_impact), _yaw, 0.0, _height * 0.5)
		_sfx("MG_cannon_splash")
		_sfx("MG_win", 0.8)
		return
	if _hit == _HIT_TOWER:
		_bonk_tower()
		return
	_place(_pos_at(_impact), _yaw, -150.0, _height * 0.5)
	_toon.play_gesture("run", 2.0, true)
	_sfx("MG_cannon_hit_dirt")


func _bonk_tower() -> void:
	var pos := _pos_at(_impact)
	var away := Vector3(pos.x - _tower_x, pos.y - _tower_y, 0.0)
	if away.length() < 0.001:
		away = Vector3(0.0, 1.0, 0.0)
	away = away.normalized()
	var heading := rad_to_deg(asin(clampf(away.x, -1.0, 1.0)))
	var span := _TOWER_HEIGHT - _BUCKET_HEIGHT
	var along := clampf(pos.z - _BUCKET_HEIGHT, 0.0, span) / span
	var hit := pos + away * (0.75 * along)
	_face(heading, 94.0)
	_toon.global_position = _panda(hit.x, hit.y, hit.z)
	hit.z -= 1.0
	_slide_from = _toon.global_position
	_slide_to = _panda(hit.x, hit.y, hit.z)
	_toon.pose_action("slip-forward", 25.0 / 24.0)
	_sfx("MG_cannon_hit_tower")


func _land(delta: float) -> void:
	_land_left -= delta
	if _hit == _HIT_TOWER:
		var started := _LAND_TIME - 0.5
		if _land_left < started:
			var blend := clampf((started - _land_left) / (_LAND_TIME - 0.5), 0.0, 1.0)
			blend = blend * blend
			_toon.global_position = _slide_from.lerp(_slide_to, blend)
	elif _hit == _HIT_GROUND:
		_toon.set_locomotion(0.0, false, false, delta)
	elif _hit == _HIT_WATER:
		_toon.set_locomotion(0.0, false, false, delta)
	if _land_left > 0.0:
		return
	if _hit == _HIT_WATER:
		_end()
		return
	_enter_aim()


## __calcToonImpact. The water disc sits on the lip. The cylinder is the bucket wall.
func _predict() -> int:
	var lip := _BUCKET_HEIGHT + (_TOWER_HEIGHT - _BUCKET_HEIGHT)
	var water := _disc(Vector3(_tower_x, _tower_y, lip), _TOWER_RADIUS)
	if water >= 0.0:
		_impact = water
		return _HIT_WATER
	var tower := _cylinder(Vector3(_tower_x, _tower_y, _BUCKET_HEIGHT), _TOWER_RADIUS, _TOWER_HEIGHT - _BUCKET_HEIGHT)
	if tower >= 0.0:
		_impact = tower
		return _HIT_TOWER
	var ground := _plane(0.0)
	_impact = ground if ground >= 0.0 else 0.0
	return _HIT_GROUND


func _impact_time() -> float:
	return _impact


func _reaches(height: float) -> bool:
	var peak := -_launch_vel.z / -_GRAVITY
	if peak < 0.0:
		peak = 0.0
	return _z_at(peak) >= height


func _plane(height: float) -> float:
	var a := -_GRAVITY * 0.5
	var b := _launch_vel.z
	var c := _start.z - height
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return -1.0
	var t: float = -b / (2.0 * a) if disc == 0.0 else (-b - sqrt(disc)) / (2.0 * a)
	if t < 0.0:
		return -1.0
	return t


func _disc(center: Vector3, radius: float) -> float:
	if not _reaches(center.z):
		return -1.0
	var t := _plane(center.z)
	if t < 0.0:
		return -1.0
	var pos := _pos_at(t)
	var offset := Vector2(pos.x - center.x, pos.y - center.y)
	if offset.length_squared() < radius * radius:
		return t
	return -1.0


func _cylinder(bottom: Vector3, radius: float, height: float) -> float:
	if not _reaches(bottom.z):
		return -1.0
	var span := _enter_leave(Vector2(bottom.x, bottom.y), radius)
	if span.x < 0.0 and span.y < 0.0:
		return -1.0
	var enter := _pos_at(span.x)
	var leave := _pos_at(span.y)
	var top := bottom.z + height
	if enter.z > top and leave.z > top:
		return -1.0
	if enter.z < top and enter.z > bottom.z and span.x > 0.0:
		return span.x
	return -1.0


func _enter_leave(center: Vector2, radius: float) -> Vector2:
	var origin := Vector2(_start.x, _start.y)
	var step := Vector2(_launch_vel.x, _launch_vel.y)
	var speed := step.length()
	if speed < 0.001:
		return Vector2(-1.0, -1.0)
	var direction := step / speed
	var toward := origin - center
	var b := direction.dot(toward)
	var c := toward.dot(toward) - radius * radius
	var under := b * b - c
	if under <= 0.0:
		return Vector2(-1.0, -1.0)
	var root := sqrt(under)
	return Vector2((-b - root) / speed, (-b + root) / speed)


func _pos_at(t: float) -> Vector3:
	return Vector3(_start.x + _launch_vel.x * t, _start.y + _launch_vel.y * t, _z_at(t))


func _vel_at(t: float) -> Vector3:
	return Vector3(_launch_vel.x, _launch_vel.y, _launch_vel.z - _GRAVITY * t)


func _z_at(t: float) -> float:
	return _start.z + _launch_vel.z * t - 0.5 * _GRAVITY * t * t


func _place(panda_pos: Vector3, heading: float, pitch: float, drop: float) -> void:
	_face(heading, pitch)
	var up := _toon.global_basis.z.normalized()
	_toon.global_position = _panda(panda_pos.x, panda_pos.y, panda_pos.z) - up * drop


## setHpr(heading, pitch, 0). The head, which is the toon's up axis, follows the arc.
func _face(heading: float, pitch: float) -> void:
	if _toon == null:
		return
	var h := deg_to_rad(heading)
	var p := deg_to_rad(pitch)
	var forward := Vector3(-sin(h), cos(h), 0.0)
	var up := Vector3(0.0, 0.0, 1.0)
	var face := forward * cos(p) + up * sin(p)
	var raised := up * cos(p) - forward * sin(p)
	var face_godot := _panda(face.x, face.y, face.z).normalized()
	var up_godot := _panda(raised.x, raised.y, raised.z).normalized()
	_toon.global_basis = Basis(face_godot.cross(up_godot), face_godot, up_godot).scaled(Vector3.ONE * _body_scale)


func _elapsed() -> float:
	return clampf(_GAME_TIME - duration, 0.0, _GAME_TIME)


func _reward_time() -> float:
	var now := _elapsed()
	if _clock_stop >= 0.0 and _clock_stop < now:
		return _clock_stop
	return now


func _raw_score(t: float) -> int:
	return int(23.0 - 18.0 * (clampf(t, 0.0, _GAME_TIME) / _GAME_TIME) + 0.5)


func _jar_points(t: float) -> int:
	return int(float(_raw_score(t)) * _score_mult() + 0.5)


func _score_mult() -> float:
	var ride := get_parent()
	if ride != null and ride.has_method("_multiplier"):
		return float(ride.call("_multiplier"))
	return 1.0


## getTowerPosition. A new spot each round. Near towers stay toward the middle.
func _place_tower(stage: Node3D) -> void:
	var y_min := int(float(_TOWER_Y_RANGE) * 0.3)
	var y_roll := shared_range(y_min, _TOWER_Y_RANGE)
	var x_range := int(float(_TOWER_Y_RANGE) / 2.0)
	var x_roll := shared_range(0, x_range)
	var x := float(x_roll - int(float(x_range) / 2.0))
	x *= float(y_roll) / float(_TOWER_Y_RANGE)
	_tower_x = x
	_tower_y = float(y_roll - int(float(_TOWER_Y_RANGE) / 2.0))
	if stage == null:
		return
	var tower := stage.find_child("toon_cannon_water_tower_egg", true, false) as Node3D
	if tower == null:
		return
	# The set root stands the model up, so this local point is the Panda position.
	tower.position = Vector3(_tower_x, _tower_y, 0.0)


func _aim_view() -> void:
	_camera.position = _panda(_cannon_x, _CANNON_Y - 25.0, _CANNON_Z + 7.0)
	_camera.rotation = Vector3.ZERO


## One cannon per rider. DistributedCannonGame spaces them by CANNON_X_SPACING.
func _slot_x(index: int, count: int) -> float:
	return float(index) * _CANNON_GAP - float(count - 1) * _CANNON_GAP * 0.5


func _add_cannon(index: int, count: int) -> void:
	var rig := Node3D.new()
	rig.name = "CannonRig%d" % index
	add_child(rig)
	rig.position = _panda(_slot_x(index, count), _CANNON_Y, _CANNON_Z)
	var barrel: Node3D = null
	var model := _prop("res://assets/minigames/toon_cannon.glb")
	if model != null:
		rig.add_child(model)
		barrel = model.find_child("cannon", true, false) as Node3D
	if barrel != null:
		var muzzle := Node3D.new()
		muzzle.name = "Muzzle"
		barrel.add_child(muzzle)
		# ToonHead.setPosHpr(0, 6, 0, 0, -45, 0) on the barrel node.
		muzzle.position = Vector3(0.0, 6.0, 0.0)
		barrel.rotation_degrees = Vector3(_pitch, 0.0, 0.0)
	_rigs.append(rig)
	_barrels.append(barrel)


func _share_aim(force: bool) -> void:
	if party_size() <= 1:
		return
	var now := _elapsed()
	if not force and now - _aim_sent < 0.5:
		return
	_aim_sent = now
	ToonNet.note_cannon(_yaw, _pitch)


func _pose_others() -> void:
	if party_size() <= 1:
		return
	var raw: Variant = ToonNet.minigame_state().get("aims", {})
	if not (raw is Dictionary):
		return
	var aims: Dictionary = raw
	for i in _rigs.size():
		if _rigs[i] == _cannon:
			continue
		var aim: Variant = aims.get(str(party_peer(i)), [])
		if not (aim is Array) or (aim as Array).size() < 2:
			continue
		_rigs[i].rotation_degrees = Vector3(0.0, float((aim as Array)[0]), 0.0)
		var barrel := _barrels[i] as Node3D
		if barrel != null:
			barrel.rotation_degrees = Vector3(float((aim as Array)[1]), 0.0, 0.0)


func _flight_view() -> void:
	var pos := _to_panda(_shot.global_position)
	var look := Vector3(_tower_x, _tower_y, -_TOWER_HEIGHT * 0.5)
	var vel := _to_panda(_vel)
	var toward_tower := pos - Vector3(_tower_x, _tower_y, _TOWER_HEIGHT)
	var dist := toward_tower.length()
	var multiplier := 0.0
	if dist < _TOWER_NEAR and dist > 0.001 and vel.length() > 0.001:
		var perp := Vector3(0.0, 0.0, 1.0).cross(vel)
		if perp.length() > 0.001:
			perp = perp.normalized()
			if toward_tower.dot(perp) > 0.0:
				perp = -perp
			var nearness := 1.0 - dist / _TOWER_NEAR
			var curve := nearness * nearness
			multiplier = -2.0 * curve * nearness + 3.0 * curve
			look += perp * (multiplier * _LOOK_OFFSET)
			_pullback = maxf(_pullback, _PULL_MIN + multiplier * (_PULL_MAX - _PULL_MIN))
	var away := pos - look
	if away.length() < 0.001:
		return
	var cam := pos + away.normalized() * _pullback
	_camera.global_position = _panda(cam.x, cam.y, cam.z)
	_camera.look_at(_shot.global_position, Vector3.UP)


func _to_panda(godot: Vector3) -> Vector3:
	return Vector3(godot.x, -godot.z, godot.y)
