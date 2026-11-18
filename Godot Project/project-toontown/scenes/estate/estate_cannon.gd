extends Node3D

## DistributedCannon and DistributedTarget. The 48 hour catalog rental generates
## them. Six cannons sit on CannonGlobals.cannonDrops.
## Walking into the 1.5 sphere loads you. Arrows aim, Control fires, and twenty
## seconds without a shot puts you back beside the barrel. Flight is Trajectory
## at 80 with gravity 32. The target model sits at panda (0, 0, 40), scale 3,
## with the original sphere of radius 3.5. A hit scores PinballTarget, 350, and
## adds 1 to the multiplier. Each cannon keeps a bumper cloud at panda
## (0, -20, 40), scale 4. Delete or Insert, once above height 15, moves that
## cloud to the toon and ignores it for a quarter second. A hit scores 100 and
## bounces at 0.4. Three rings of bumper clouds sit on cloudOrigin at height 30:
## twelve at radius 40 scoring 150, twelve at 60 scoring 200, and twelve at 20
## scoring 250. startCloudPlatforms returns before the drift track, so the rings
## stay put. The sky plane, 300 above that origin, scores 150. A floor ends the
## flight. A wall bounces like a house.

const _CLOSET := preload("res://scenes/catalog/catalog_closet.gd")
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
const _BUMPER_BOUNCE := 0.4
const _BUMPER_SCORE := 100
const _LOW_SCORE := 150
const _MED_SCORE := 200
const _HIGH_SCORE := 250
## loadSkyCollision. The plane sits 300 above cloudOrigin, which is at height 30.
const _SKY := 330.0
## bumper_cloud collision box, in the exported model's local space.
const _BOX_LO := Vector3(-0.846157, -0.0071607, -0.848489)
const _BOX_HI := Vector3(0.85082, 1.68982, 0.848489)
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
var _bumpers: Array[Node3D] = []
var _rings: Array[Node3D] = []
var _ring_score: Array[int] = []
var _ring_in: Array[bool] = []
var _target: Node3D
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
var _bumper_used := false
var _bumper_wait := 0.0
var _in_bumper := false
var _in_sky := false


static func place(host: Node) -> void:
	var existing := host.get_node_or_null("EstateCannons")
	if not _CLOSET.cannon_rental_active():
		if existing != null:
			existing.queue_free()
		return
	if existing != null:
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
		_bumpers.append(_bumper(rig))
	_target = _prop("res://assets/estate/cannon/target.glb")
	if _target == null:
		var stand_in := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = _TARGET_RADIUS
		ball.height = _TARGET_RADIUS * 2.0
		stand_in.mesh = ball
		_target = stand_in
	else:
		_target.scale = Vector3.ONE * 3.0
	_target.name = "Target"
	_target_home = _panda(0.0, 0.0, 40.0)
	_target.position = _target_home
	add_child(_target)
	_place_rings()
	var layer := CanvasLayer.new()
	layer.layer = 24
	add_child(layer)
	_note = Label.new()
	_note.position = Vector2(24, 24)
	_note.size = Vector2(640, 80)
	_note.visible = false
	layer.add_child(_note)


func _process(delta: float) -> void:
	if not _CLOSET.cannon_rental_active():
		_end_rental()
		return
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
	_in_bumper = false
	_in_sky = false
	_bumper_used = false
	_bumper_wait = 0.0
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
	_bumper_wait = maxf(_bumper_wait - delta, 0.0)
	_move_bumper()
	_touch_target()
	_touch_bumper()
	_touch_rings()
	_touch_sky()
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


func _end_rental() -> void:
	if _occupied >= 0:
		_exit_cannon()
	var tree := get_tree()
	if tree != null:
		for node in tree.root.find_children("*", "SpeedChat", true, false):
			if node.has_method("alert"):
				node.call("alert", "The Cannon Game rental is over.")
				break
	queue_free()


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


func _bumper(rig: Node3D) -> Node3D:
	var cloud := _prop("res://assets/estate/cannon/bumper_cloud.glb")
	if cloud == null:
		cloud = Node3D.new()
	cloud.name = "Bumper"
	cloud.scale = Vector3.ONE * 4.0
	cloud.position = _panda(0.0, -20.0, 40.0)
	_tint(cloud, Color(0.52, 0.8, 0.98, 1.0))
	rig.add_child(cloud)
	return cloud


func _tint(root: Node, color: Color) -> void:
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		var inst := mesh as MeshInstance3D
		var source := inst.get_active_material(0) as StandardMaterial3D
		var shade := StandardMaterial3D.new()
		if source != null:
			shade.albedo_texture = source.albedo_texture
		shade.albedo_color = color
		inst.material_override = shade


func _move_bumper() -> void:
	if _bumper_used or _body == null or _occupied < 0:
		return
	if _body.global_position.y <= 15.0:
		return
	var pressed := Input.is_physical_key_pressed(KEY_DELETE) or Input.is_physical_key_pressed(KEY_INSERT)
	if not pressed:
		return
	_bumper_used = true
	_bumpers[_occupied].position = _rigs[_occupied].to_local(_body.global_position)
	_bumper_wait = 0.25
	_in_bumper = false


func _touch_bumper() -> void:
	if _body == null or _occupied < 0 or _bumper_wait > 0.0:
		return
	var cloud := _bumpers[_occupied]
	var local := cloud.global_transform.affine_inverse() * _body.global_position
	if local.x < _BOX_LO.x or local.x > _BOX_HI.x or local.y < _BOX_LO.y or local.y > _BOX_HI.y or local.z < _BOX_LO.z or local.z > _BOX_HI.z:
		_in_bumper = false
		return
	if _in_bumper:
		return
	var faces: Array[Vector3] = [
		Vector3(local.x - _BOX_LO.x, -1.0, 0.0),
		Vector3(_BOX_HI.x - local.x, 1.0, 0.0),
		Vector3(local.y - _BOX_LO.y, 0.0, -1.0),
		Vector3(_BOX_HI.y - local.y, 0.0, 1.0),
		Vector3(local.z - _BOX_LO.z, 0.0, 0.0),
		Vector3(_BOX_HI.z - local.z, 0.0, 0.0),
	]
	var best := 0
	for i in faces.size():
		if faces[i].x < faces[best].x:
			best = i
	var normal := Vector3.ZERO
	if best < 2:
		normal = Vector3(faces[best].y, 0.0, 0.0)
	elif best < 4:
		normal = Vector3(0.0, faces[best].z, 0.0)
	elif best == 4:
		normal = Vector3(0.0, 0.0, -1.0)
	else:
		normal = Vector3(0.0, 0.0, 1.0)
	normal = (cloud.global_transform.basis * normal).normalized()
	if _vel.dot(normal) > 0.0:
		return
	_in_bumper = true
	_bounce_off(normal, _BUMPER_BOUNCE, _BUMPER_SCORE)
	_sfx("res://assets/audio/battle/AA_drop_sandbag.ogg")


func _place_rings() -> void:
	var origin := Node3D.new()
	origin.name = "CloudOrigin"
	origin.position = _panda(0.0, 0.0, 30.0)
	add_child(origin)
	_ring(origin, 40.0, 0.0, _LOW_SCORE)
	_ring(origin, 60.0, 40.0, _MED_SCORE)
	_ring(origin, 20.0, 80.0, _HIGH_SCORE)


func _ring(origin: Node3D, radius: float, z_offset: float, score: int) -> void:
	for i in 12:
		var cloud := _prop("res://assets/estate/cannon/bumper_cloud.glb")
		if cloud == null:
			continue
		cloud.name = "cloud-%d-1" % score
		cloud.scale = Vector3.ONE * 4.0
		var theta := TAU * float(i) / 12.0
		cloud.position = _panda(radius * cos(theta), radius * sin(theta), randf() * 4.0 + z_offset)
		origin.add_child(cloud)
		_rings.append(cloud)
		_ring_score.append(score)
		_ring_in.append(false)


func _touch_rings() -> void:
	if _body == null:
		return
	for i in _rings.size():
		var normal := _box_face(_rings[i])
		if normal == Vector3.ZERO:
			_ring_in[i] = false
			continue
		if _ring_in[i] or _vel.dot(normal) > 0.0:
			continue
		_ring_in[i] = true
		_bounce_off(normal, _BUMPER_BOUNCE, _ring_score[i])
		_sfx("res://assets/audio/battle/AA_drop_sandbag.ogg")
		return


func _touch_sky() -> void:
	if _body == null:
		return
	if _body.global_position.y < _SKY:
		_in_sky = false
		return
	if _in_sky or _vel.y <= 0.0:
		return
	_in_sky = true
	_bounce_off(Vector3.DOWN, _BUMPER_BOUNCE, _LOW_SCORE)
	_sfx("res://assets/audio/battle/AA_drop_sandbag.ogg")


func _box_face(cloud: Node3D) -> Vector3:
	var local := cloud.global_transform.affine_inverse() * _body.global_position
	if local.x < _BOX_LO.x or local.x > _BOX_HI.x or local.y < _BOX_LO.y or local.y > _BOX_HI.y or local.z < _BOX_LO.z or local.z > _BOX_HI.z:
		return Vector3.ZERO
	var depth: Array[float] = [
		local.x - _BOX_LO.x, _BOX_HI.x - local.x,
		local.y - _BOX_LO.y, _BOX_HI.y - local.y,
		local.z - _BOX_LO.z, _BOX_HI.z - local.z,
	]
	var best := 0
	for i in depth.size():
		if depth[i] < depth[best]:
			best = i
	var normal := Vector3.ZERO
	if best == 0:
		normal = Vector3.LEFT
	elif best == 1:
		normal = Vector3.RIGHT
	elif best == 2:
		normal = Vector3.DOWN
	elif best == 3:
		normal = Vector3.UP
	elif best == 4:
		normal = Vector3(0.0, 0.0, -1.0)
	else:
		normal = Vector3(0.0, 0.0, 1.0)
	return (cloud.global_transform.basis * normal).normalized()


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
