extends Node3D

## DistributedRace. Arrow keys drive, back brakes before it reverses, and
## Control throws the gag. Steering is scaled to these tracks: City Circuit's
## tightest real corners are about 140 units across, so a full-speed kart can
## still turn through them, and braking rotates it harder. A qualifying time
## pays the deposit back, then the place winnings and any leaderboard bonus.

const _RULES := preload("res://scenes/racing/kart_rules.gd")
const _GARAGE := preload("res://scenes/racing/kart_garage.gd")
const _MODEL := preload("res://scenes/racing/kart_model.gd")
const _COLLISION := preload("res://scenes/playgrounds/playground_collision.gd")
const _GUI := preload("res://scenes/toons/toon_gui.gd")
const _PROPS := "res://assets/racing/track_props.json"
const _CURVES := "res://assets/racing/tracks/curves.json"
const _SCENE := "res://scenes/racing/kart_race.tscn"
const _SPEEDWAY := "res://scenes/playgrounds/goofy_speedway.tscn"
const _MAX_SPEED := 600.0
const _ENGINE := 48.0
const _BRAKE := 110.0
const _REVERSE := 28.0
const _GRAVITY := 32.0
const _YAW_SLOW := 140.0
const _YAW_FAST := 100.0

static var track_id := 0
static var race_type := 0
static var lap_total := 3
static var return_point := Vector3.ZERO
static var return_heading := 0.0
static var armed := false

var _points: PackedVector3Array = PackedVector3Array()
var _kart: CharacterBody3D
var _camera: Camera3D
var _speed := 0.0
var _slide := 0.0
var _steer := 0.0
var _yaw := 0.0
var _turbo := 0.0
var _spin := 0.0
var _started := false
var _finished := false
var _clock := 0.0
var _laps := 0
var _index := 0
var _passed_mid := false
var _on_start := true
var _gag := 0
var _gag_wait := 0.0
var _hud_lap: Label
var _hud_time: Label
var _hud_gag: Label
var _hud_note: Label
var _music: AudioStreamPlayer
var _limit := 300.0


static func launch(which: int, kind: int, laps: int, point: Vector3, heading: float) -> void:
	track_id = which
	race_type = kind
	lap_total = laps
	return_point = point
	return_heading = heading
	armed = true
	ToonLoading.change_to(_SCENE)


func _ready() -> void:
	if not armed:
		_leave()
		return
	armed = false
	var fee := _RULES.entry_fee(track_id, race_type)
	if _GARAGE.tickets() < fee:
		_leave()
		return
	_GARAGE.set_tickets(_GARAGE.tickets() - fee)
	_limit = _RULES.qualifying(track_id) + 60.0
	_build_world()
	_build_kart()
	_build_hud()
	_play_music()
	await get_tree().physics_frame
	_place_kart()
	_place_props()
	await _countdown()
	if not is_inside_tree():
		return
	_started = true


func _physics_process(delta: float) -> void:
	if not _started or _finished or _kart == null:
		return
	_clock += delta
	_gag_wait = maxf(_gag_wait - delta, 0.0)
	_turbo = maxf(_turbo - delta, 0.0)
	if _clock >= _limit:
		_end(false, "You took too long to finish the race.  Your tickets have not been refunded.  Keep trying!")
		return
	_drive(delta)
	_watch_lap()
	_paint_hud()
	if Keybinds.held("jump") or Input.is_physical_key_pressed(KEY_L):
		_throw_gag()


func _drive(delta: float) -> void:
	if _spin > 0.0:
		_spin = maxf(_spin - delta, 0.0)
		_speed = 0.0
		_slide = 0.0
		_yaw += 240.0 * delta
		_kart.rotation.y = deg_to_rad(_yaw)
		_kart.velocity = Vector3.ZERO
		_kart.move_and_slide()
		_aim_camera(delta)
		return
	var throttle := 0.0
	var steer_input := 0.0
	if Keybinds.held("forward") or Input.is_physical_key_pressed(KEY_UP):
		throttle = 1.0
	elif Keybinds.held("back") or Input.is_physical_key_pressed(KEY_DOWN):
		throttle = -1.0
	if Keybinds.held("left") or Input.is_physical_key_pressed(KEY_LEFT):
		steer_input = 1.0
	elif Keybinds.held("right") or Input.is_physical_key_pressed(KEY_RIGHT):
		steer_input = -1.0
	_steer = move_toward(_steer, steer_input, delta * 8.0)
	var braking := throttle < 0.0 and _speed > 12.0
	var pace := clampf(absf(_speed) / 200.0, 0.0, 1.0)
	var yaw_rate := lerpf(_YAW_SLOW, _YAW_FAST, pace)
	if not _kart.is_on_floor():
		yaw_rate *= 0.45
	elif braking and absf(_steer) > 0.35:
		yaw_rate *= 1.4
	if _speed < -1.0:
		yaw_rate *= -1.0
	var travel := Vector3(_kart.velocity.x, 0.0, _kart.velocity.z)
	_yaw += _steer * yaw_rate * delta
	_kart.rotation.y = deg_to_rad(_yaw)
	var forward := -_kart.global_basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
	var right := _kart.global_basis.x
	right.y = 0.0
	if right.length_squared() > 0.0001:
		right = right.normalized()
	_speed = travel.dot(forward)
	_slide = travel.dot(right)
	var engine := _ENGINE
	if _turbo > 0.0:
		engine += _ENGINE * 1.5
	if _kart.is_on_floor():
		if throttle > 0.0:
			_speed += engine * delta
		elif braking:
			_speed = move_toward(_speed, 0.0, _BRAKE * delta)
		elif throttle < 0.0:
			_speed = move_toward(_speed, -36.0, _REVERSE * delta)
		else:
			_speed = move_toward(_speed, 0.0, 18.0 * delta)
		var slope := Vector3(0.0, -_GRAVITY, 0.0).slide(_kart.get_floor_normal())
		_speed += slope.dot(forward) * delta
		_speed -= _speed * _RULES.drag(track_id) * delta
	_speed = clampf(_speed, -36.0, _MAX_SPEED)
	var grip := 12.0
	if absf(_steer) > 0.65 and absf(_speed) > 55.0:
		grip = 5.0
	if braking and absf(_steer) > 0.35:
		grip = 2.2
	_slide = lerpf(_slide, 0.0, 1.0 - exp(-grip * delta))
	var wish := forward * _speed + right * _slide
	if _kart.is_on_floor():
		wish = wish.slide(_kart.get_floor_normal())
		_kart.velocity = wish
	else:
		_kart.velocity.x = wish.x
		_kart.velocity.z = wish.z
		_kart.velocity.y -= _GRAVITY * delta
	_kart.move_and_slide()
	_scrub_walls(forward)
	var carried := Vector3(_kart.velocity.x, 0.0, _kart.velocity.z)
	_speed = carried.dot(forward)
	_slide = carried.dot(right)
	_rescue()
	_aim_camera(delta)


func _nose() -> Vector3:
	if _kart == null:
		return Vector3(0.0, 0.0, -1.0)
	var forward := -_kart.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Vector3(0.0, 0.0, -1.0)
	return forward.normalized()


func _scrub_walls(forward: Vector3) -> void:
	for index in _kart.get_slide_collision_count():
		var normal := _kart.get_slide_collision(index).get_normal()
		if absf(normal.y) > 0.45:
			continue
		var flat := Vector3(normal.x, 0.0, normal.z)
		if flat.length_squared() < 0.0001:
			continue
		flat = flat.normalized()
		var into := maxf(0.0, -forward.dot(flat))
		_kart.velocity += flat * into * absf(_speed) * 0.65
		_speed *= 1.0 - 0.35 * into


func _watch_lap() -> void:
	if _points.is_empty():
		return
	_index = _nearest(_index, _kart.global_position)
	var start := _nearest(0, _start_marker())
	var mid := _nearest(0, _mid_marker())
	if _near(_index, mid):
		_passed_mid = true
	var along := _points[(_index + 1) % _points.size()] - _points[_index]
	var moving := _kart.velocity
	moving.y = 0.0
	var wrong := along.dot(moving) < 0.0 and moving.length_squared() > 4.0
	if _hud_note != null and (_hud_note.text == "" or _hud_note.text == "Wrong\nWay!"):
		_hud_note.text = "Wrong\nWay!" if wrong else ""
	var near_start := _near(_index, start)
	if near_start and not _on_start and _passed_mid:
		_laps += 1
		_passed_mid = false
		if _music != null:
			_music.pitch_scale = 1.0 + float(_laps) * 0.5
		if _laps >= lap_total:
			_end(true, "")
	_on_start = near_start


func _near(here: int, there: int) -> bool:
	var gap := posmod(here - there, _points.size())
	return gap <= 12 or gap >= _points.size() - 12


func _nearest(around: int, pos: Vector3) -> int:
	var best := around
	var best_d := INF
	var window := 40
	for step in range(-window, window + 1):
		var index := posmod(around + step, _points.size())
		var gap := _points[index].distance_squared_to(pos)
		if gap < best_d:
			best_d = gap
			best = index
	if best_d > 900.0:
		for index in _points.size():
			var gap := _points[index].distance_squared_to(pos)
			if gap < best_d:
				best_d = gap
				best = index
	return best


func _rescue() -> void:
	if _points.is_empty():
		return
	var from := _kart.global_position + Vector3.UP * 3.0
	var space := get_world_3d().direct_space_state
	if space != null:
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 50.0)
		if not space.intersect_ray(query).is_empty():
			return
	var road := _points[_index]
	if _kart.global_position.y > road.y - 30.0:
		return
	_kart.global_position = road + Vector3.UP * 2.0
	_kart.velocity = Vector3.ZERO
	_speed = 0.0
	_slide = 0.0


func _throw_gag() -> void:
	if _gag == 0 or _gag_wait > 0.0:
		return
	var thrown := _gag
	_gag = 0
	_gag_wait = 0.4
	if thrown == _RULES.TURBO:
		_turbo = 3.0
	elif thrown == _RULES.BANANA:
		_drop_peel()
	elif thrown == _RULES.ANVIL or thrown == _RULES.PIE:
		pass


func _drop_peel() -> void:
	var peel := Area3D.new()
	peel.position = _kart.global_position - _nose() * 3.0
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 1.4
	shape.shape = ball
	peel.add_child(shape)
	var show := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.45
	mesh.height = 0.9
	show.mesh = mesh
	peel.add_child(show)
	add_child(peel)
	peel.body_entered.connect(func(body: Node) -> void:
		if body == _kart:
			_spin = 1.4
			peel.queue_free()
	)


func _end(finished: bool, reason: String) -> void:
	if _finished:
		return
	_finished = true
	_started = false
	var result := {}
	if finished:
		var qualified := _clock <= _RULES.qualifying(track_id)
		result = _GARAGE.finish_race(track_id, race_type, _clock, qualified, 1, 1)
	_show_results(result, reason)
	await get_tree().create_timer(4.0).timeout
	if is_inside_tree():
		_leave()


func _show_results(result: Dictionary, reason: String) -> void:
	if not reason.is_empty():
		_hud_note.text = reason
		return
	var qualified := bool(result.get("qualified", false))
	var line := "Qualified!" if qualified else "Did Not Qualify"
	var total := int(result.get("fee", 0)) + int(result.get("winnings", 0)) + int(result.get("bonus", 0))
	_hud_note.text = "%s\n%s\nDeposit: %d\nWinnings: %d\nBonus: %d\nRace Total: %d" % [
		line, _RULES.clock(float(result.get("time", _clock))), int(result.get("fee", 0)),
		int(result.get("winnings", 0)), int(result.get("bonus", 0)), total,
	]
	var trophies: Variant = result.get("trophies", [])
	if trophies is PackedStringArray and not (trophies as PackedStringArray).is_empty():
		_hud_note.text += "\nTrophies: " + ", ".join(trophies)


func _countdown() -> void:
	for step in range(_RULES.RACE_COUNTDOWN, 0, -1):
		_hud_note.text = _RULES.info_text(track_id) + "\n" + str(step)
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree():
			return
	_hud_note.text = "Go!"
	await get_tree().create_timer(0.6).timeout
	if is_inside_tree():
		_hud_note.text = ""


func _build_world() -> void:
	var curves: Variant = JSON.parse_string(FileAccess.get_file_as_string(_CURVES))
	var slug := _RULES.model_slug(track_id)
	var record: Dictionary = {}
	if curves is Dictionary:
		record = (curves as Dictionary).get(slug, {})
	var key := "reverse" if _RULES.reversed(track_id) else "forward"
	for item in record.get(key, []):
		if item is Array and (item as Array).size() >= 3:
			var row: Array = item
			_points.append(Vector3(float(row[0]), float(row[1]), float(row[2])))
	var packed := load(String(record.get("model", ""))) as PackedScene
	if packed != null:
		var geom := packed.instantiate()
		geom.name = "Track"
		geom.set_script(_COLLISION)
		add_child(geom)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var fill := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.7, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.7)
	fill.environment = env
	add_child(fill)


func _build_kart() -> void:
	_kart = CharacterBody3D.new()
	_kart.name = "Racer"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 1.2, 3.2)
	shape.shape = box
	shape.position.y = 0.7
	_kart.add_child(shape)
	_kart.add_child(_MODEL.build())
	_kart.floor_snap_length = 0.45
	_kart.floor_max_angle = deg_to_rad(50.0)
	add_child(_kart)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.far = 8000.0
	add_child(_camera)


func _place_kart() -> void:
	var at := _grid_start()
	if at == Vector3.INF:
		at = _start_marker()
	if _points.is_empty():
		_kart.global_position = at + Vector3.UP
		return
	_index = _nearest(0, at)
	var floor_at := _ground(at + Vector3.UP * 30.0)
	_kart.global_position = floor_at + Vector3.UP * 0.2
	var ahead := _points[(_index + 8) % _points.size()] - _points[_index]
	ahead.y = 0.0
	if ahead.length_squared() > 0.01:
		# rotation.y points the kart's nose, local -Z, along the racing line.
		_yaw = rad_to_deg(atan2(-ahead.x, -ahead.z))
	_kart.rotation.y = deg_to_rad(_yaw)
	_aim_camera(0.0, true)


func _grid_start() -> Vector3:
	var curves: Variant = JSON.parse_string(FileAccess.get_file_as_string(_CURVES))
	if not (curves is Dictionary):
		return Vector3.INF
	var record: Dictionary = (curves as Dictionary).get(_RULES.model_slug(track_id), {})
	var starts: Array = record.get("starts", [])
	if starts.is_empty() or not (starts[0] is Dictionary):
		return Vector3.INF
	var pos: Variant = (starts[0] as Dictionary).get("pos", [])
	if pos is Array and (pos as Array).size() >= 3:
		var row: Array = pos
		return Vector3(float(row[0]), float(row[1]), float(row[2]))
	return Vector3.INF


func _ground(from: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	if space == null:
		return from
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 80.0)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return from + Vector3.DOWN * 28.0
	return hit.position


func _place_props() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_PROPS))
	if not (parsed is Dictionary):
		return
	var record: Dictionary = (parsed as Dictionary).get(str(track_id), {})
	var slot := 0
	for item in record.get("gags", []):
		if item is Array and (item as Array).size() >= 3:
			var row: Array = item
			_make_gag(slot, _RULES.world(Vector3(float(row[0]), float(row[1]), float(row[2]))))
			slot += 1
	for item in record.get("boosts", []):
		if item is Array and (item as Array).size() >= 2:
			var row: Array = item
			var pos: Array = row[0]
			var hpr: Array = row[1]
			if pos.size() >= 3:
				var heading := float(hpr[0]) if not hpr.is_empty() else 0.0
				_make_boost(_RULES.world(Vector3(float(pos[0]), float(pos[1]), float(pos[2]))), heading)


func _make_gag(slot: int, at: Vector3) -> void:
	var pad := Area3D.new()
	pad.position = _ground(at + Vector3.UP * 20.0) + Vector3.UP * 1.2
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 4.0
	shape.shape = ball
	pad.add_child(shape)
	var show := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.2, 1.2, 1.2)
	show.mesh = mesh
	pad.add_child(show)
	add_child(pad)
	pad.body_entered.connect(_take_gag.bind(pad))


func _take_gag(body: Node, pad: Area3D) -> void:
	if body != _kart or _gag != 0 or pad == null or not pad.visible:
		return
	_gag = _RULES.gag_type(1, randi() % 6)
	_gag_wait = 2.0
	pad.visible = false
	pad.monitoring = false
	get_tree().create_timer(5.0).timeout.connect(func() -> void:
		if is_instance_valid(pad):
			pad.visible = true
			pad.monitoring = true
	)


func _make_boost(at: Vector3, panda_heading: float) -> void:
	var pad := Area3D.new()
	pad.position = _ground(at + Vector3.UP * 20.0) + Vector3.UP * 0.6
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 2.0, 18.0)
	shape.shape = box
	pad.add_child(shape)
	# Panda heading 0 faces +Y. Positive heading turns toward -X.
	var rad := deg_to_rad(panda_heading)
	var arrow := Vector3(-sin(rad), 0.0, -cos(rad))
	if arrow.length_squared() > 0.01:
		pad.basis = Basis.looking_at(arrow, Vector3.UP)
	add_child(pad)
	pad.body_entered.connect(_take_boost.bind(pad))


func _take_boost(body: Node, pad: Area3D) -> void:
	if body != _kart or pad == null or bool(pad.get_meta("cooling", false)):
		return
	if _nose().dot(-pad.global_basis.z) < 0.7:
		return
	pad.set_meta("cooling", true)
	_turbo = 3.0
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if is_instance_valid(pad):
			pad.set_meta("cooling", false)
	)


func _start_marker() -> Vector3:
	var curves: Variant = JSON.parse_string(FileAccess.get_file_as_string(_CURVES))
	if curves is Dictionary:
		var record: Dictionary = (curves as Dictionary).get(_RULES.model_slug(track_id), {})
		var key := "lap_start_rev" if _RULES.reversed(track_id) else "lap_start"
		var marker: Dictionary = record.get(key, {})
		var pos: Variant = marker.get("pos", [])
		if pos is Array and (pos as Array).size() >= 3:
			var row: Array = pos
			return Vector3(float(row[0]), float(row[1]), float(row[2]))
	if not _points.is_empty():
		return _points[0]
	return Vector3.ZERO


func _mid_marker() -> Vector3:
	if _points.is_empty():
		return Vector3.ZERO
	return _points[_points.size() / 2]


func _aim_camera(delta: float, snap: bool = false) -> void:
	if _camera == null or _kart == null:
		return
	var forward := -_kart.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return
	forward = forward.normalized()
	var back := 15.0 if _turbo > 0.0 else 11.5
	var want := _kart.global_position - forward * back + Vector3.UP * 4.6
	var look := _kart.global_position + forward * 8.0 + Vector3.UP * 1.3
	if snap:
		_camera.global_position = want
	else:
		var weight := 1.0 - exp(-7.0 * delta)
		_camera.global_position = _camera.global_position.lerp(want, weight)
	_camera.look_at(look, Vector3.UP)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_hud_lap = _label(layer, Vector2(24, 16))
	_hud_time = _label(layer, Vector2(24, 56))
	_hud_gag = _label(layer, Vector2(24, 96))
	_hud_note = _label(layer, Vector2(280, 80))
	_hud_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_note.size = Vector2(720, 280)
	var leave := Button.new()
	leave.text = "Leave Race"
	leave.position = Vector2(24, 150)
	leave.size = Vector2(180, 42)
	leave.pressed.connect(_leave_early)
	layer.add_child(leave)
	_paint_hud()


func _label(layer: CanvasLayer, at: Vector2) -> Label:
	var label := Label.new()
	label.position = at
	label.size = Vector2(420, 40)
	_GUI.style_label(label, Color.WHITE, 22, Color.BLACK, 4)
	layer.add_child(label)
	return label


func _paint_hud() -> void:
	if _hud_lap == null:
		return
	var showing := mini(_laps + 1, lap_total)
	_hud_lap.text = "Final Lap!" if _laps == lap_total - 1 and _started else "Lap %d" % showing
	_hud_time.text = _RULES.clock(_clock)
	var gag_name := ""
	match _gag:
		_RULES.BANANA:
			gag_name = "Banana Peel"
		_RULES.TURBO:
			gag_name = "Turbo"
		_RULES.ANVIL:
			gag_name = "Anvil"
		_RULES.PIE:
			gag_name = "Cream Pie"
	_hud_gag.text = gag_name


func _play_music() -> void:
	var path := "res://assets/racing/audio/" + _RULES.music_file(track_id)
	if not FileAccess.file_exists(path):
		return
	var stream := AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		return
	stream.loop = true
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.volume_db = linear_to_db(0.7)
	add_child(_music)
	_music.play()


func _leave_early() -> void:
	if _finished:
		return
	_finished = true
	_started = false
	_hud_note.text = "Leaving the race."
	_leave()


func _leave() -> void:
	var pads = load("res://scenes/racing/speedway_racing.gd")
	pads.park_return(return_point, return_heading)
	ToonLoading.change_to(_SPEEDWAY)
