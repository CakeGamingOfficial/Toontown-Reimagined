extends Node3D

## DistributedCannon and DistributedTarget. Six cannons sit on CannonGlobals.cannonDrops.
## Walking into the 1.5 sphere loads you. Arrows aim, Control fires, and twenty
## seconds without a shot puts you back beside the barrel. Flight is Trajectory
## at 80 with gravity 32. The target is the original sphere at panda (0, 0, 40),
## scale 3, radius 3.5. phase_5.5/models/estate/target was not exported, so that
## sphere is what shows. A hit scores PinballTarget, 350, and adds 1 to the
## multiplier. A floor ends the flight. A wall bounces like a house.

const _SPEED := 80.0
const _GRAVITY := 32.0
const _TIMEOUT := 20.0
const _YAW_MIN := -55.0
const _YAW_MAX := 50.0
const _PITCH_MIN := 15.0
const _PITCH_MAX := 85.0
const _TURN := 15.0
const _TARGET_RADIUS := 3.5 * 3.0
const _HOUSE := 0.4
const _TARGET_BOUNCE := 0.1
const _DROPS: Array[Vector4] = [
	Vector4(-110.0, -66.0, 0.025, -64.0),
	Vector4(65.68, -71.1, 0.025, 24.0),
	Vector4(-53.7788, -104.5, 0.72, -24.0),
	Vector4(39.58, 1.53, 8.2, 101.2),
	Vector4(61.3, 62.78, 0.031, 171.2),
	Vector4(-43.8, 75.2, 0.025, -158.15),
]

var _rigs: Array[Node3D] = []
var _barrels: Array[Node3D] = []
var _heads: Array[float] = []
var _target: MeshInstance3D
var _target_home := Vector3.ZERO
var _occupied := -1
var _aim_yaw := 0.0
var _pitch := 15.0
var _wait := 0.0
var _flying := false
var _in_target := false
var _vel := Vector3.ZERO
var _body: CharacterBody3D
var _layer := 1
var _armed := true
var _score := 0
var _mult := 1
var _best := 0
var _note: Label
var _fire_down := false
var _adjust: AudioStreamPlayer
var _bounce := 0.0
var _bounce_from := Vector3.ZERO


static func place(host: Node) -> void:
	if host.get_node_or_null("EstateCannons") != null:
		return
	var yard: Node = load("res://scenes/estate/estate_cannon.gd").new()
	yard.name = "EstateCannons"
	host.add_child(yard)


func holds_camera() -> bool:
	return _occupied >= 0


func aim(camera: Camera3D) -> void:
	if camera == null or _occupied < 0:
		return
	if _flying and _body != null:
		var back := _vel
		back.y = 0.0
		if back.length() < 0.2:
			back = Vector3(0.0, 0.0, 1.0)
		back = back.normalized()
		camera.global_position = _body.global_position - back * 30.0 + Vector3(0.0, 10.0, 0.0)
		camera.look_at(_body.global_position, Vector3.UP)
		return
	var barrel := _barrels[_occupied]
	if barrel == null:
		return
	camera.global_position = barrel.global_transform * Vector3(0.5, -2.0, 2.5)
	camera.look_at(barrel.global_transform * Vector3(0.0, 6.0, 0.0), Vector3.UP)


func _ready() -> void:
	for index in _DROPS.size():
		var drop := _DROPS[index]
		var rig := Node3D.new()
		rig.name = "Cannon%d" % index
		add_child(rig)
		rig.position = _ground(_panda(drop.x, drop.y, 30.0))
		rig.rotation.y = deg_to_rad(drop.w)
		var model := _prop("res://assets/minigames/toon_cannon.glb")
		var barrel: Node3D = rig
		if model != null:
			rig.add_child(model)
			var found := model.find_child("cannon", true, false) as Node3D
			if found != null:
				barrel = found
		_rigs.append(rig)
		_barrels.append(barrel)
		_heads.append(drop.w)
	_target = MeshInstance3D.new()
	_target.name = "Target"
	var ball := SphereMesh.new()
	ball.radius = _TARGET_RADIUS
	ball.height = _TARGET_RADIUS * 2.0
	_target.mesh = ball
	var shade := StandardMaterial3D.new()
	shade.albedo_color = Color(0.85, 0.08, 0.08, 1.0)
	shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_target.material_override = shade
	_target_home = _panda(0.0, 0.0, 40.0)
	_target.position = _target_home
	add_child(_target)
	var layer := CanvasLayer.new()
	layer.layer = 24
	add_child(layer)
	_note = Label.new()
	_note.position = Vector2(24, 24)
	_note.size = Vector2(640, 80)
	_note.visible = false
	layer.add_child(_note)


func _process(delta: float) -> void:
	_spring_target(delta)
	if _occupied < 0:
		_watch_entry()
		return
	if _flying:
		_fly(delta)
		return
	_aim_barrel(delta)
	_wait += delta
	if _wait >= _TIMEOUT:
		_exit_cannon()


func _watch_entry() -> void:
	var body := _player()
	if body == null:
		return
	var held := false
	var host := body.get_parent()
	if host != null and host.has_method("is_held"):
		held = bool(host.call("is_held"))
	if held:
		_armed = body.global_position.distance_to(_nearest(body.global_position)) > 3.0
		return
	var nearest := -1
	var reach := 1.5
	for index in _rigs.size():
		var gap := body.global_position.distance_to(_rigs[index].global_position)
		if gap < reach:
			reach = gap
			nearest = index
	if nearest < 0:
		_armed = true
		return
	if not _armed:
		return
	_enter(nearest, body)


func _enter(index: int, body: CharacterBody3D) -> void:
	var host := body.get_parent()
	if host != null and host.has_method("hold_for_race"):
		host.call("hold_for_race", true)
	_occupied = index
	_body = body
	_layer = body.collision_layer
	body.collision_layer = 0
	body.velocity = Vector3.ZERO
	_aim_yaw = 0.0
	_pitch = _PITCH_MIN
	_wait = 0.0
	_flying = false
	_in_target = false
	_fire_down = false
	_score = 0
	_mult = 1
	_pose()
	_show_score()


func _aim_barrel(delta: float) -> void:
	var yaw_dir := 0.0
	if Input.is_physical_key_pressed(KEY_LEFT):
		yaw_dir -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT):
		yaw_dir += 1.0
	var pitch_dir := 0.0
	if Input.is_physical_key_pressed(KEY_UP):
		pitch_dir += 1.0
	if Input.is_physical_key_pressed(KEY_DOWN):
		pitch_dir -= 1.0
	var before := Vector2(_aim_yaw, _pitch)
	_aim_yaw = clampf(_aim_yaw + yaw_dir * _TURN * delta, _YAW_MIN, _YAW_MAX)
	_pitch = clampf(_pitch + pitch_dir * _TURN * delta, _PITCH_MIN, _PITCH_MAX)
	_pose()
	var moving := not is_equal_approx(before.x, _aim_yaw) or not is_equal_approx(before.y, _pitch)
	_loop_adjust(moving)
	var fire := Keybinds.held("jump") or Input.is_physical_key_pressed(KEY_SPACE)
	if fire and not _fire_down:
		_fire_down = true
		_launch()
		return
	_fire_down = fire


func _pose() -> void:
	if _occupied < 0:
		return
	_rigs[_occupied].rotation.y = deg_to_rad(_heads[_occupied] + _aim_yaw)
	var barrel := _barrels[_occupied]
	if barrel != null and barrel != _rigs[_occupied]:
		barrel.rotation_degrees = Vector3(_pitch, 0.0, 0.0)
	if _body != null and barrel != null:
		_body.global_position = barrel.global_transform * Vector3(0.0, 6.0, 0.0)
		_body.velocity = Vector3.ZERO


func _launch() -> void:
	_loop_adjust(false)
	_flying = true
	_in_target = false
	var heading := deg_to_rad(_heads[_occupied] + _aim_yaw)
	var angle := deg_to_rad(_pitch)
	var horiz := _SPEED * cos(angle)
	var panda := Vector3(horiz * -sin(heading), horiz * cos(heading), _SPEED * sin(angle))
	_vel = _panda(panda.x, panda.y, panda.z)
	_sfx("res://assets/audio/sfx/MG_cannon_fire_alt.ogg")
	var actor := _actor()
	if actor != null and actor.has_method("play_gesture"):
		actor.call("play_gesture", "swim", 1.0, true)


func _fly(delta: float) -> void:
	if _body == null:
		_exit_cannon()
		return
	var start := _body.global_position
	_vel.y -= _GRAVITY * delta
	var step := _vel * delta
	var landed := _hit_along(start, step)
	if landed:
		return
	_body.global_position = start + step
	_body.velocity = Vector3.ZERO
	_touch_target()
	if _body.global_position.y < -20.0 or _body.global_position.y > 1000.0:
		_exit_cannon()


func _hit_along(start: Vector3, step: Vector3) -> bool:
	var space := get_world_3d()
	if space == null or step.length() < 0.001:
		return false
	var query := PhysicsRayQueryParameters3D.create(start, start + step)
	if _body != null:
		query.exclude = [_body.get_rid()]
	var hit := space.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var normal: Vector3 = hit.normal
	if normal.y > 0.55 and _vel.y <= 0.0:
		_body.global_position = hit.position + Vector3(0.0, 0.2, 0.0)
		_sfx("res://assets/audio/sfx/MG_cannon_hit_dirt.ogg")
		_finish_flight()
		return true
	_body.global_position = hit.position + normal * 0.3
	_bounce_off(normal, _HOUSE, 50)
	_sfx("res://assets/audio/battle/AA_drop_sandbag.ogg")
	return true


func _touch_target() -> void:
	if _body == null or _target == null:
		return
	var gap := _body.global_position - _target.global_position
	if gap.length() > _TARGET_RADIUS or gap.length() < 0.001:
		_in_target = false
		return
	if _in_target or _vel.dot(gap) > 0.0:
		return
	_in_target = true
	var incoming := _vel.normalized() if _vel.length() > 0.001 else gap.normalized()
	_bounce_off(gap.normalized(), _TARGET_BOUNCE, 350)
	_kick_target(incoming)
	_sfx("res://assets/audio/battle/AA_drop_sandbag.ogg")


func _bounce_off(normal: Vector3, kr: float, points: int) -> void:
	var speed := _vel.length()
	if speed < 0.001:
		return
	var vel := _vel / speed
	_vel = (normal * 2.0 + vel) * (kr * speed)
	_score += points
	_mult += 1
	var total := _score * _mult
	if total > _best:
		_best = total
	_show_score()


func _kick_target(dir: Vector3) -> void:
	_bounce = 0.55
	_bounce_from = _target_home - dir * 1.5
	_target.position = _bounce_from


func _spring_target(delta: float) -> void:
	if _target == null or _bounce <= 0.0:
		return
	_bounce = maxf(_bounce - delta, 0.0)
	var toward := 1.0 - _bounce / 0.55
	_target.position = _bounce_from.lerp(_target_home, clampf(toward, 0.0, 1.0))


func _finish_flight() -> void:
	_flying = false
	var actor := _actor()
	if actor != null and actor.has_method("clear_gesture"):
		actor.call("clear_gesture")
	_release()


func _exit_cannon() -> void:
	_loop_adjust(false)
	if _occupied >= 0 and _body != null:
		_body.global_position = _rigs[_occupied].to_global(Vector3(2.0, 0.0, 4.0))
	_release()


func _release() -> void:
	_flying = false
	_occupied = -1
	_armed = false
	_note.visible = false
	if _body != null and is_instance_valid(_body):
		_body.collision_layer = _layer
		_body.velocity = Vector3.ZERO
		var host := _body.get_parent()
		if host != null and host.has_method("hold_for_race"):
			host.call("hold_for_race", false)
	_body = null


func _show_score() -> void:
	_note.visible = true
	_note.text = "Score:            %d x %d = %d\nHigh Score:     %d" % [_score, _mult, _score * _mult, _best]


func _player() -> CharacterBody3D:
	var host := get_parent()
	if host == null:
		return null
	var toon := host.get_node_or_null("PlaygroundToon")
	if toon == null:
		return null
	return toon.get_node_or_null("Player") as CharacterBody3D


func _actor() -> Node:
	if _body == null:
		return null
	for child in _body.get_children():
		if child is ToonActor:
			return child
	return null


func _nearest(at: Vector3) -> Vector3:
	var best := _rigs[0].global_position
	var gap := at.distance_to(best)
	for rig in _rigs:
		var next := at.distance_to(rig.global_position)
		if next < gap:
			gap = next
			best = rig.global_position
	return best


func _ground(at: Vector3) -> Vector3:
	var space := get_world_3d()
	if space == null:
		return Vector3(at.x, 0.2, at.z)
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 40.0, at + Vector3.DOWN * 80.0)
	var hit := space.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3(at.x, 0.2, at.z)
	return hit.position


func _panda(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, z, -y)


func _prop(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as Node3D


func _sfx(path: String) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _loop_adjust(on: bool) -> void:
	if not on:
		if _adjust != null:
			_adjust.stop()
			_adjust.queue_free()
			_adjust = null
		return
	if _adjust != null:
		return
	var stream := load("res://assets/audio/sfx/MG_cannon_adjust.ogg") as AudioStream
	if stream == null:
		return
	_adjust = AudioStreamPlayer.new()
	_adjust.stream = stream
	add_child(_adjust)
	_adjust.play()
