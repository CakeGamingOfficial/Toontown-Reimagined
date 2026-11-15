extends Node3D

## DistributedRace. Arrow keys drive, back brakes before it reverses, and
## Control throws the gag. Steering is scaled to these tracks: City Circuit's
## tightest real corners are about 140 units across, so a full-speed kart can
## still turn through them, and braking rotates it harder. A qualifying time
## pays the deposit back, then the place winnings and any leaderboard bonus.

const _RULES := preload("res://scenes/racing/kart_rules.gd")
const _RACES := preload("res://scenes/racing/race_matches.gd")
const _GARAGE := preload("res://scenes/racing/kart_garage.gd")
const _MODEL := preload("res://scenes/racing/kart_model.gd")
const _COLLISION := preload("res://scenes/playgrounds/playground_collision.gd")
const _GUI := preload("res://scenes/toons/toon_gui.gd")
const _PROPS := "res://assets/racing/track_props.json"
const _CURVES := "res://assets/racing/tracks/curves.json"
const _SOLIDS := "res://assets/racing/tracks/collision.json"
const _QBOX := "res://assets/racing/props/qbox.glb"
const _BANANA := "res://assets/battle/props/banana.glb"
const _PIE := "res://assets/battle/props/creampie.glb"
const _ANVIL := "res://assets/battle/props/anvil.glb"
const _ARROW := "res://assets/racing/maps/boost_arrow.png"
const _GAUGE := preload("res://assets/gui/racing/speedometer_gauge.png")
const _NEEDLE := preload("res://assets/gui/racing/speedometer_spin.png")
const _FACE := preload("res://assets/gui/racing/speedometer_face.png")
const _TICS := preload("res://assets/gui/racing/speedometer_tics.png")
const _RING := preload("res://assets/gui/racing/speedometer_ring.png")
const _GAG_PANEL := preload("res://assets/gui/racing/gag_panel.png")
const _MAP_SPOT := preload("res://assets/gui/racing/racing_mapspot.png")
const _PANEL := preload("res://assets/gui/racing/racing_panel_fg.png")
const _GAG_BANANA := preload("res://assets/gui/tutorial/gags/inventory_bannana_peel.png")
const _GAG_BOOST := preload("res://assets/gui/racing/boost_arrow.png")
const _GAG_ANVIL := preload("res://assets/gui/tutorial/gags/inventory_anvil.png")
const _GAG_PIE := preload("res://assets/gui/tutorial/gags/inventory_creampie.png")
const _LEAVE_UP := preload("res://assets/toons/gui/CloseBtn_UP.png")
const _LEAVE_DOWN := preload("res://assets/toons/gui/CloseBtn_DN.png")
const _LEAVE_HOVER := preload("res://assets/toons/gui/CloseBtn_Rllvr.png")
const _YELLOW := Color(0.95, 0.95, 0, 1)
const _BLOTS: Array[Color] = [
	Color(0.95, 0.25, 0.2),
	Color(0.25, 0.45, 0.95),
	Color(0.2, 0.75, 0.35),
	Color(0.95, 0.8, 0.2),
]
const _NEEDLE_REST := -75.0
const _SCENE := "res://scenes/racing/kart_race.tscn"
const _SPEEDWAY := "res://scenes/playgrounds/goofy_speedway.tscn"
const _MAX_SPEED := 600.0
const _ENGINE := 48.0
const _BRAKE := 110.0
const _REVERSE := 28.0
const _GRAVITY := 32.0
const _YAW_SLOW := 140.0
const _YAW_FAST := 100.0
const _RACE_BUS := "RaceTempo"

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
var _gag_roll := 0
var _gag_spin := 0.0
var _gag_wait := 0.0
var _pies: Array[Node3D] = []
var _anvil: Node3D
var _flat := -1.0
var _hud_root: Control
var _hud_lap: Label
var _hud_note: Label
var _hud_wrong: Label
var _hud_place: Label
var _hud_suffix: Label
var _hud_speed: Label
var _needle: TextureRect
var _gag_icon: TextureRect
var _marker: TextureRect
var _map_line: Line2D
var _map_spot: TextureRect
var _lap_mins: Array[Label] = []
var _lap_secs: Array[Label] = []
var _lap_fracs: Array[Label] = []
var _split := 0.0
var _note_left := 0.0
var _wrong := false
var _wrong_blink := 0.0
var _music: AudioStreamPlayer
var _music_shift: AudioEffectPitchShift
var _driver: ToonActor
var _limit := 300.0
var _pose_left := 0.0
var _event_seq := 0
var _loot_seq := 0
var _remotes: Dictionary = {}


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
	_lift_iris()
	await get_tree().physics_frame
	_place_kart()
	_place_props()
	await _countdown()
	if not is_inside_tree():
		return
	_started = true


func _process(delta: float) -> void:
	if _driver != null:
		_driver.pose_synced_loop("sit")
	if _note_left > 0.0:
		_note_left -= delta
		if _note_left <= 0.0 and _hud_note != null and not _finished:
			if _hud_note.text.begins_with("Lap ") or _hud_note.text == "Final Lap!":
				_hud_note.text = ""
	if _hud_wrong == null:
		return
	if not _wrong:
		_hud_wrong.modulate.a = 0.0
		return
	_wrong_blink += delta
	_hud_wrong.modulate.a = 1.0 if fmod(_wrong_blink, 0.5) < 0.25 else 0.0


func _physics_process(delta: float) -> void:
	_sync_remotes(delta)
	_sync_race()
	if not _started or _finished or _kart == null:
		return
	_clock += delta
	_gag_wait = maxf(_gag_wait - delta, 0.0)
	if _gag_spin > 0.0:
		_gag_spin = maxf(_gag_spin - delta, 0.0)
		if _gag_spin == 0.0:
			_gag = _gag_roll
	_turbo = maxf(_turbo - delta, 0.0)
	_tick_pies(delta)
	if _clock >= _limit:
		_end(false, "You took too long to finish the race.  Your tickets have not been refunded.  Keep trying!")
		return
	_drive(delta)
	_watch_lap()
	_send_pose(delta)
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
	if _flat >= 0.0:
		_tick_flat(delta)
		if _flat >= 0.92:
			_speed = 0.0
			_slide = 0.0
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
	_wrong = along.dot(moving) < 0.0 and moving.length_squared() > 4.0
	var near_start := _near(_index, start)
	if near_start and not _on_start and _passed_mid:
		_laps += 1
		_split = _clock
		_passed_mid = false
		_set_music_tempo(1.0 + float(_laps) * 0.5)
		if _laps >= lap_total:
			_end(true, "")
		elif _hud_note != null:
			_hud_note.text = "Final Lap!" if _laps == lap_total - 1 else "Lap %d" % (_laps + 1)
			_note_left = 2.0
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
		return
	if _RACES.mine().is_empty():
		if thrown == _RULES.BANANA:
			_drop_peel()
		elif thrown == _RULES.ANVIL:
			_drop_anvil()
		elif thrown == _RULES.PIE:
			_shoot_pie()
		return
	var at := _kart.global_position
	var aim := _nose()
	if thrown == _RULES.BANANA:
		at -= aim * 5.0
	ToonNet.race_act("throw", {
		"gag": thrown,
		"x": at.x,
		"y": at.y,
		"z": at.z,
		"nx": aim.x,
		"ny": aim.y,
		"nz": aim.z,
	})
	_sync_race()


func _drop_peel(at: Vector3 = Vector3.ZERO, placed: bool = false, owner: int = -1) -> void:
	var peel := Area3D.new()
	peel.position = at if placed else _kart.global_position - _nose() * 5.0
	peel.set_meta("owner", owner)
	peel.set_meta("born", Time.get_ticks_msec())
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 1.4
	shape.shape = ball
	peel.add_child(shape)
	var packed := load(_BANANA) as PackedScene
	if packed != null:
		var show := packed.instantiate() as Node3D
		if show != null:
			# DistributedRace copies the banana prop at scale 2.
			show.scale = Vector3.ONE * 2.0
			peel.add_child(show)
	add_child(peel)
	peel.body_entered.connect(func(body: Node) -> void:
		if body != _kart:
			return
		var mine := int(peel.get_meta("owner", -1)) == ToonNet.peer_id()
		if mine and Time.get_ticks_msec() - int(peel.get_meta("born", 0)) < 600:
			return
		_spin = 1.4
		peel.queue_free()
	)


func _shoot_pie() -> void:
	var pie := Node3D.new()
	pie.name = "Pie"
	pie.position = _kart.global_position + Vector3.UP * 2.0
	var show := _prop(_PIE, 3.0)
	if show != null:
		# FlyingGag tips the pie and copies it at scale 3.
		show.rotation_degrees = Vector3(-45.0, 0.0, 0.0)
		pie.add_child(show)
	var aim := _nose()
	pie.set_meta("aim", aim)
	pie.set_meta("vel", aim * (_speed + 50.0) + Vector3.UP * 50.0)
	pie.set_meta("life", 3.2)
	pie.set_meta("splat", 0.0)
	pie.set_meta("spin", randf_range(-360.0, 360.0))
	add_child(pie)
	_pies.append(pie)


func _tick_pies(delta: float) -> void:
	var spent: Array[Node3D] = []
	for pie in _pies:
		if not is_instance_valid(pie):
			spent.append(pie)
			continue
		var resting := float(pie.get_meta("splat"))
		if resting > 0.0:
			resting -= delta
			pie.set_meta("splat", resting)
			if resting <= 0.0:
				pie.queue_free()
				spent.append(pie)
			continue
		var life := float(pie.get_meta("life")) - delta
		var vel := pie.get_meta("vel") as Vector3
		var aim := pie.get_meta("aim") as Vector3
		var drag := 0.2 + 0.8 * clampf(1.0 - life / 3.2, 0.0, 1.0)
		vel += aim * 100.0 * delta
		vel.y += 3.0 * delta
		vel -= vel * drag * delta
		pie.position += vel * delta
		pie.rotate_object_local(Vector3.RIGHT, deg_to_rad(float(pie.get_meta("spin")) * delta))
		pie.set_meta("vel", vel)
		pie.set_meta("life", life)
		if life <= 0.0:
			# The flying pie is already scale 3. This lands it at the splat size of 6.
			pie.scale = Vector3.ONE * 2.0
			pie.set_meta("splat", 1.0)
	for done in spent:
		_pies.erase(done)


func _drop_anvil() -> void:
	if _kart == null or _flat >= 0.0:
		return
	if _anvil != null and is_instance_valid(_anvil):
		_anvil.queue_free()
	var weight := _prop(_ANVIL, 1.0)
	if weight == null:
		return
	weight.name = "Anvil"
	# dropOnMe starts the anvil overhead at scale (7, 9, 7) and drops it in one second.
	weight.position = Vector3(0.0, 50.0, 0.0)
	weight.scale = Vector3(7.0, 9.0, 7.0)
	_kart.add_child(weight)
	_anvil = weight
	_flat = 0.0


func _tick_flat(delta: float) -> void:
	_flat += delta
	var body: Node3D = _kart.get_node_or_null("Kart") as Node3D
	if _anvil != null and is_instance_valid(_anvil):
		var fall := clampf(_flat / 1.0, 0.0, 1.0)
		_anvil.position.y = lerpf(50.0, 0.6, fall)
		if _flat >= 1.0:
			_anvil.scale.y = lerpf(9.0, 4.0, clampf((_flat - 1.0) / 0.2, 0.0, 1.0))
		if _flat >= 1.2:
			_anvil.queue_free()
			_anvil = null
	if body != null and _flat >= 0.92 and _flat < 1.7:
		body.scale = Vector3(1.0, 0.1, 1.0)
	elif body != null and _flat >= 1.7 and _flat < 2.0:
		body.scale = Vector3(1.0, 2.0, 1.0)
	elif body != null and _flat >= 2.0:
		body.scale = Vector3.ONE
		_flat = -1.0


func _prop(path: String, prop_scale: float) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var show: Node3D = packed.instantiate() as Node3D
	if show == null:
		return null
	show.scale = Vector3.ONE * prop_scale
	return show


func _gag_texture(which: int) -> Texture2D:
	match which:
		_RULES.TURBO:
			return _GAG_BOOST
		_RULES.ANVIL:
			return _GAG_ANVIL
		_RULES.PIE:
			return _GAG_PIE
		_:
			return _GAG_BANANA


## The reel slows onto the rolled gag. A fixed cycle always eased out on the pie.
func _spinning_gag() -> int:
	var order: Array[int] = [_RULES.BANANA, _RULES.TURBO, _RULES.ANVIL, _RULES.PIE]
	var stop := order.find(_gag_roll)
	if stop < 0:
		stop = 0
	var steps := 8 * order.size()
	var cycle := clampf(1.0 - _gag_spin / 2.0, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - cycle, 3.0)
	var shown := mini(int(eased * float(steps + 1)), steps)
	return order[(shown + stop) % order.size()]


func _end(finished: bool, reason: String) -> void:
	if _finished:
		return
	_finished = true
	_started = false
	var result := {}
	if finished:
		ToonNet.race_act("finish", {"time": _clock})
		var place := _RACES.my_place()
		var waits := 0
		while place <= 0 and waits < 20 and is_inside_tree():
			await get_tree().create_timer(0.05).timeout
			place = _RACES.my_place()
			waits += 1
		if place <= 0:
			place = _standing()
		var racers := 1
		var listed: Variant = _RACES.mine().get("racers", [])
		if listed is Array and not (listed as Array).is_empty():
			racers = (listed as Array).size()
		var qualified := _clock <= _RULES.qualifying(track_id)
		result = _GARAGE.finish_race(track_id, race_type, _clock, qualified, place, racers)
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


func _lift_iris() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 1)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var fade := create_tween()
	fade.tween_property(shade, "color:a", 0.0, 0.6)
	fade.tween_callback(layer.queue_free)


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
	# The visible pieces with cutout textures never became solid. The original
	# track and wall polygons are the floor and the barriers.
	_add_track_solids(slug)
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


func _add_track_solids(slug: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_SOLIDS))
	if not (parsed is Dictionary):
		return
	var raw: Array = (parsed as Dictionary).get(slug, [])
	if raw.size() < 9:
		return
	var faces := PackedVector3Array()
	var cursor := 0
	while cursor + 2 < raw.size():
		faces.append(Vector3(float(raw[cursor]), float(raw[cursor + 1]), float(raw[cursor + 2])))
		cursor += 3
	var body := StaticBody3D.new()
	body.name = "TrackSolids"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _build_kart() -> void:
	_kart = CharacterBody3D.new()
	_kart.name = "Racer"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 1.2, 3.2)
	shape.shape = box
	shape.position.y = 0.7
	_kart.add_child(shape)
	# Kart.__createLODKart turns the body 180. The bam nose points the other
	# way, so without this the kart drives hood-first the wrong direction.
	var model := _MODEL.build()
	model.rotate_y(PI)
	_kart.add_child(model)
	# Kart.baseScale. The exported body is the unscaled bam.
	_kart.scale = Vector3(2.0, 2.0, 2.0)
	_kart.floor_snap_length = 0.45
	_kart.floor_max_angle = deg_to_rad(50.0)
	add_child(_kart)
	_seat_driver()
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 52.0
	_camera.far = 8000.0
	add_child(_camera)


func _seat_driver() -> void:
	var style := ToonRoster.selected_style()
	if style == null:
		return
	var seat := Node3D.new()
	seat.name = "ToonSeat"
	# The seat is (0, -1.3, -7) on the suspension, after the body turn.
	# That is this spot in the kart, before baseScale. The half scale cancels
	# baseScale so the toon keeps its own size.
	seat.position = Vector3(0.0, 0.1555, -0.1238)
	seat.scale = Vector3(0.5, 0.5, 0.5)
	_kart.add_child(seat)
	_driver = ToonActor.new()
	_driver.name = "Driver"
	_driver.footsteps = false
	seat.add_child(_driver)
	_driver.show_style(style)
	var body_scale := _driver.transform.basis.get_scale().x
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	_driver.transform.basis = upright.scaled(Vector3.ONE * body_scale)
	_tuck_driver(_driver)
	_driver.pose_synced_loop("sit")


func _tuck_driver(actor: ToonActor) -> void:
	# DistributedVehicle.enterControlled hides the legs and feet, drops the
	# shadow, and sets the head to 1.75 while the toon loops sit.
	for shadow in actor.find_children("drop_shadow", "MeshInstance3D", true, false):
		shadow.visible = false
	var torso := _torso_of(actor)
	if torso != null:
		for mesh in actor.find_children("*", "MeshInstance3D", true, false):
			if _under(mesh, torso):
				continue
			mesh.visible = false
	for look in actor.find_children("head_look", "Node3D", true, false):
		for child in look.get_children():
			if child is Node3D:
				(child as Node3D).scale = Vector3(1.75, 1.75, 1.75)


func _torso_of(actor: Node) -> Node:
	var hips := actor.find_child("joint_hips", true, false)
	if hips == null:
		return null
	for child in hips.get_children():
		if child.find_child("def_head", true, false) != null:
			return child
	return null


func _under(node: Node, ancestor: Node) -> bool:
	var cursor := node
	while cursor != null:
		if cursor == ancestor:
			return true
		cursor = cursor.get_parent()
	return false


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


func _grid_start(slot: int = -1) -> Vector3:
	if slot < 0:
		slot = _seat_index()
	var curves: Variant = JSON.parse_string(FileAccess.get_file_as_string(_CURVES))
	if not (curves is Dictionary):
		return Vector3.INF
	var record: Dictionary = (curves as Dictionary).get(_RULES.model_slug(track_id), {})
	var starts: Array = record.get("starts", [])
	if starts.is_empty():
		return Vector3.INF
	var pick := clampi(slot, 0, starts.size() - 1)
	if not (starts[pick] is Dictionary):
		return Vector3.INF
	var pos: Variant = (starts[pick] as Dictionary).get("pos", [])
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
	pad.position = _ground(at + Vector3.UP * 20.0) + Vector3.UP * 2.0
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 4.0
	shape.shape = ball
	pad.add_child(shape)
	var packed := load(_QBOX) as PackedScene
	if packed != null:
		var box := packed.instantiate() as Node3D
		if box != null:
			# RaceGag.genGag grows the question box to scale 4.
			box.scale = Vector3.ONE * 4.0
			pad.add_child(box)
	pad.set_meta("slot", slot)
	add_child(pad)
	pad.body_entered.connect(_take_gag.bind(pad))


func _take_gag(body: Node, pad: Area3D) -> void:
	if body != _kart or _gag != 0 or _gag_spin > 0.0 or pad == null or not pad.visible:
		return
	# GagFreq follows the racer's place. The district rolls the box once,
	# so the same question mark cannot pay two karts.
	if not _RACES.mine().is_empty() and pad.has_meta("slot"):
		pad.visible = false
		pad.monitoring = false
		pad.set_meta("pending", Time.get_ticks_msec())
		ToonNet.race_act("box", {"slot": int(pad.get_meta("slot"))})
		_sync_race()
		return
	_gag_roll = _RULES.gag_type(_standing(), randi() % 6)
	_gag = 0
	_gag_spin = 2.0
	pad.visible = false
	pad.monitoring = false
	get_tree().create_timer(5.0).timeout.connect(func() -> void:
		if is_instance_valid(pad):
			pad.visible = true
			pad.monitoring = true
	)


func _make_boost(at: Vector3, panda_heading: float) -> void:
	var pad := Area3D.new()
	pad.position = _ground(at + Vector3.UP * 20.0) + Vector3.UP * 0.15
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# genArrow's tube runs about 60 units along the boost, under three scale-24 cards.
	box.size = Vector3(10.0, 2.0, 72.0)
	shape.shape = box
	shape.position = Vector3(0.0, 0.0, -24.0)
	pad.add_child(shape)
	# Panda heading 0 faces +Y. Positive heading turns toward -X.
	var rad := deg_to_rad(panda_heading)
	var aim := Vector3(-sin(rad), 0.0, -cos(rad))
	if aim.length_squared() > 0.01:
		pad.basis = Basis.looking_at(aim, Vector3.UP)
	var art := load(_ARROW) as Texture2D
	if art != null:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_texture = art
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		for step in 3:
			var card := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(24.0, 24.0)
			card.mesh = quad
			card.material_override = material
			# The card faces +Z, with the arrow tip toward +Y. Pitch -90 lays it on
			# the road and sends that tip along local -Z, the boost direction.
			card.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
			card.position = Vector3(0.0, 0.08, -24.0 * float(step))
			pad.add_child(card)
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
	# DistributedVehicle puts the camera at (0, -33, 16) with pitch -10.
	# Turbo pulls that arm in to (0, -25, 16) and leaves the height alone.
	var back := 25.0 if _turbo > 0.0 else 33.0
	var want := _kart.global_position - forward * back + Vector3.UP * 16.0
	var look := want + forward * 40.0 - Vector3.UP * (40.0 * tan(deg_to_rad(10.0)))
	if snap:
		_camera.global_position = want
	else:
		var weight := 1.0 - exp(-7.0 * delta)
		_camera.global_position = _camera.global_position.lerp(want, weight)
	_camera.look_at(look, Vector3.UP)


func _build_hud() -> void:
	# RaceGUI and the kart speedometer. Cards are the phase_6 and phase_4
	# karting models, and the words are the sign font in the original spots.
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_hud_root = Control.new()
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_hud_root)
	_map_line = Line2D.new()
	_map_line.width = 2.0
	_map_line.default_color = Color.WHITE
	_map_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_map_line.z_index = -1
	layer.add_child(_map_line)
	_map_spot = _card(_MAP_SPOT, "MapSpot")
	var body := _dna_color(1)
	var accessory := _dna_color(2)
	_card(_GAUGE, "Gauge")
	_needle = _card(_NEEDLE, "Needle")
	var face := _card(_FACE, "Face")
	face.modulate = Color(1, 1, 1).lerp(accessory, 0.5)
	var tics := _card(_TICS, "Tics")
	tics.modulate = body.lerp(Color.WHITE, 0.5)
	var ring := _card(_RING, "Ring")
	ring.modulate = body.lerp(Color.WHITE, 0.5)
	_map_spot.modulate = body
	_card(_GAG_PANEL, "Panel")
	_gag_icon = _card(_GAG_BANANA, "Gag")
	_gag_icon.visible = false
	_marker = _card(_PANEL, "Marker")
	_marker.modulate = body
	_hud_place = _sign(_YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	_hud_place.text = "1"
	_hud_suffix = _sign(_YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	_hud_suffix.text = "st"
	_hud_lap = _sign(_YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	_hud_speed = _sign(body, HORIZONTAL_ALIGNMENT_CENTER)
	_hud_speed.text = "0"
	_hud_wrong = _sign(Color(0.95, 0, 0, 1), HORIZONTAL_ALIGNMENT_CENTER)
	_hud_wrong.text = "Wrong\nWay!"
	_hud_wrong.modulate.a = 0.0
	_hud_note = _sign(_YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	for lap in lap_total:
		_lap_mins.append(_sign(_YELLOW, HORIZONTAL_ALIGNMENT_RIGHT))
		_lap_secs.append(_sign(_YELLOW, HORIZONTAL_ALIGNMENT_RIGHT))
		_lap_fracs.append(_sign(_YELLOW, HORIZONTAL_ALIGNMENT_RIGHT))
		_lap_mins[lap].text = "0'"
		_lap_secs[lap].text = "00''"
		_lap_fracs[lap].text = "00"
		if lap > 0:
			_lap_mins[lap].visible = false
			_lap_secs[lap].visible = false
			_lap_fracs[lap].visible = false
	var leave := TextureButton.new()
	leave.texture_normal = _LEAVE_UP
	leave.texture_pressed = _LEAVE_DOWN
	leave.texture_hover = _LEAVE_HOVER
	leave.ignore_texture_size = true
	leave.stretch_mode = TextureButton.STRETCH_SCALE
	leave.focus_mode = Control.FOCUS_NONE
	leave.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_GUI.button_sounds(leave)
	leave.pressed.connect(_leave_early)
	_hud_root.add_child(leave)
	var leave_caption := _sign(Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	leave_caption.text = "Leave Race"
	_hud_root.set_meta("leave", leave)
	_hud_root.set_meta("leave_caption", leave_caption)
	_build_map()
	var view := get_viewport()
	if view != null and not view.size_changed.is_connected(_layout_hud):
		view.size_changed.connect(_layout_hud)
	_layout_hud()
	_paint_hud()


func _card(art: Texture2D, node_name: String) -> TextureRect:
	var card := TextureRect.new()
	card.name = node_name
	card.texture = art
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(card)
	return card


func _sign(color: Color, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("ink", color)
	_GUI.style_sign(label, color, 16, Color(0, 0, 0, 0), 0)
	_hud_root.add_child(label)
	return label


func _build_map() -> void:
	_map_line.clear_points()
	if _points.is_empty():
		return
	var scale := 0.00025 * _map_factor() * 0.25
	for point in _points:
		_map_line.add_point(Vector2(point.x * scale, point.z * scale))


func _map_factor() -> float:
	# TrackDict's map scale. The country tracks use 0.75. The others use 1.
	if track_id == 20 or track_id == 21 or track_id == 62 or track_id == 63:
		return 0.75
	return 1.0


func _dna_color(field: int) -> Color:
	var dna := _GARAGE.dna()
	if field < 0 or field >= dna.size():
		return Color.WHITE
	var card := _MODEL.item(int(dna[field]))
	var parts: Variant = card.get("color", [])
	if not (parts is Array) or (parts as Array).size() < 3:
		return Color.WHITE
	var row: Array = parts
	return Color(float(row[0]), float(row[1]), float(row[2]), 1.0)


func _layout_hud() -> void:
	if _hud_root == null:
		return
	var view := get_viewport().get_visible_rect().size
	if view.y < 2.0:
		return
	_hud_root.position = Vector2.ZERO
	_hud_root.size = view
	var unit := view.y * 0.5
	# The line is already in aspect units. Scale it up to pixels and sit it
	# on the map at (1.1, 0.75).
	_map_line.position = Vector2(view.x * 0.5 + 1.1 * unit, view.y * 0.5 - 0.75 * unit)
	_map_line.scale = Vector2(unit, unit)
	# LineSegs.setThickness(2) is a screen width. The map scale must not fatten it.
	_map_line.width = 2.0 / unit
	_GUI.place(_map_spot, view, 1.1, 0.75, 0.0469, 0.0469)
	_GUI.place(_hud_root.get_node("Gauge") as Control, view, 1.24, -0.98, 0.75, 0.75)
	_GUI.place(_needle, view, 1.24, -0.98, 0.75, 0.75)
	_GUI.place(_hud_root.get_node("Face") as Control, view, 1.24, -0.98, 0.75, 0.75)
	_GUI.place(_hud_root.get_node("Tics") as Control, view, 1.24, -0.98, 0.75, 0.75)
	_GUI.place(_hud_root.get_node("Ring") as Control, view, 1.24, -0.98, 0.75, 0.75)
	_GUI.place(_hud_root.get_node("Panel") as Control, view, -1.13, -0.5, 0.25, 0.25)
	_GUI.place(_gag_icon, view, -1.13, -0.5, 0.14, 0.14)
	_GUI.place(_marker, view, -0.8, 0.93, 0.1875, 0.0938)
	_style_at(_hud_place, view, -1.2, -0.97, 0.35, 0.4, 0.5)
	_style_at(_hud_suffix, view, -1.05, -0.8, 0.1, 0.3, 0.16)
	_style_at(_hud_lap, view, 1.1, 0.45, 0.1, 0.4, 0.16)
	_style_at(_hud_speed, view, 1.2, -0.96, 0.18, 0.4, 0.24)
	_style_at(_hud_wrong, view, 1.1, 0.85, 0.1, 0.5, 0.28)
	_style_at(_hud_note, view, 0.0, 0.15, 0.055, 1.6, 0.7)
	var bar := _bar()
	_GUI.place(bar, view, 0.0, 0.93, 1.6, 0.01)
	for lap in lap_total:
		var along := (2.0 * float(lap) + 1.0) / float(lap_total * 2)
		var at := lerpf(-0.8, 0.8, along)
		_edge_at(_lap_mins[lap], view, at - 0.06, 0.84, 0.06)
		_edge_at(_lap_secs[lap], view, at + 0.06, 0.84, 0.06)
		_edge_at(_lap_fracs[lap], view, at + 0.14, 0.84, 0.06)
	for lap in range(lap_total + 1):
		var hash := _hash(lap)
		var hash_x := lerpf(-0.8, 0.8, float(lap) / float(lap_total))
		_GUI.place(hash, view, hash_x, 0.93, 0.01, 0.05)
	var leave := _hud_root.get_meta("leave") as Control
	var caption := _hud_root.get_meta("leave_caption") as Label
	_GUI.place(leave, view, -0.99, 0.925, 0.118, 0.118)
	var px := maxi(int(round(0.04 * view.y * 0.5)), 1)
	_GUI.style_label(caption, Color.WHITE, px, Color(0, 0, 0, 0), 0)
	_GUI.place(caption, view, -0.99, 0.855, 0.45, 0.08)


func _bar() -> ColorRect:
	var found := _hud_root.get_node_or_null("Progress") as ColorRect
	if found != null:
		return found
	var bar := ColorRect.new()
	bar.name = "Progress"
	bar.color = Color.WHITE
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.z_index = -1
	_hud_root.add_child(bar)
	for lap in range(lap_total + 1):
		var hash := ColorRect.new()
		hash.name = "Hash%d" % lap
		hash.color = Color.WHITE
		hash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hash.z_index = -1
		_hud_root.add_child(hash)
	return bar


func _hash(lap: int) -> ColorRect:
	return _hud_root.get_node("Hash%d" % lap) as ColorRect


func _style_at(label: Label, view: Vector2, x: float, z: float, text_scale: float, width: float, height: float) -> void:
	var px := maxi(int(round(text_scale * view.y * 0.5)), 1)
	var ink := _YELLOW
	if label.has_meta("ink"):
		ink = label.get_meta("ink") as Color
	_GUI.style_sign(label, ink, px, Color(0, 0, 0, 0), 0)
	_GUI.place(label, view, x, z, width, height)


func _edge_at(label: Label, view: Vector2, right: float, z: float, text_scale: float) -> void:
	# The original time is right-aligned, so the given x is the right edge.
	_style_at(label, view, right - 0.07, z, text_scale, 0.14, 0.1)


func _paint_hud() -> void:
	if _hud_lap == null:
		return
	var showing := mini(_laps + 1, lap_total)
	_hud_lap.text = "%d/%d" % [showing, lap_total]
	var place := _standing()
	_hud_place.text = str(place)
	_hud_suffix.text = _place_suffix(place)
	var shown := clampf(_speed, 0.0, _MAX_SPEED) * 200.0 / _MAX_SPEED
	_hud_speed.text = str(int(shown / 3.0))
	var sweep := clampf(shown / 3.0 / 120.0 * 110.0, 0.0, 110.0)
	if _needle != null:
		_needle.rotation_degrees = _NEEDLE_REST + sweep
	if _gag_icon != null:
		# waitingOnGag flips the panel, then updateGag shows the gag that was rolled.
		var spinning := _gag_spin > 0.0
		_gag_icon.visible = spinning or _gag != 0
		if spinning:
			_gag_icon.texture = _gag_texture(_spinning_gag())
		else:
			_gag_icon.texture = _gag_texture(_gag)
	var lap_index := mini(_laps, lap_total - 1)
	if lap_index >= 0 and lap_index < _lap_mins.size():
		var elapsed := maxf(_clock - _split, 0.0)
		var minutes := int(elapsed / 60.0)
		var seconds := int(elapsed) % 60
		var fraction := int((elapsed - floor(elapsed)) * 100.0)
		_lap_mins[lap_index].text = "%d'" % minutes
		_lap_secs[lap_index].text = "%02d''" % seconds
		_lap_fracs[lap_index].text = "%02d" % fraction
		_lap_mins[lap_index].visible = true
		_lap_secs[lap_index].visible = true
		_lap_fracs[lap_index].visible = true
	if _marker != null and lap_total > 0:
		var along := 0.0
		if not _points.is_empty():
			along = float(_index) / float(_points.size())
		var lap_t := clampf((float(_laps) + along) / float(lap_total), 0.0, 1.0)
		var view := get_viewport().get_visible_rect().size
		if view.y > 2.0:
			_GUI.place(_marker, view, lerpf(-0.8, 0.8, lap_t), 0.93, 0.1875, 0.0938)
			if not _points.is_empty():
				var world := 0.00025 * _map_factor() * 0.25
				var spot := _points[_index]
				_GUI.place(_map_spot, view, 1.1 + spot.x * world, 0.75 - spot.z * world, 0.0469, 0.0469)
				_place_blips(view, world)


func _send_pose(delta: float) -> void:
	if _RACES.mine().is_empty() or _kart == null:
		return
	_pose_left -= delta
	if _pose_left > 0.0:
		return
	_pose_left = 0.1
	var along := float(_laps) * float(maxi(_points.size(), 1)) + float(_index)
	var spot := _kart.global_position
	ToonNet.race_act("pose", {
		"x": spot.x,
		"y": spot.y,
		"z": spot.z,
		"yaw": _yaw,
		"speed": _speed,
		"lap": _laps,
		"along": along,
	})


func _sync_race() -> void:
	var race := _RACES.mine()
	if race.is_empty():
		return
	_apply_events(race)
	_apply_loot(race)
	_apply_boxes(race)


func _apply_events(race: Dictionary) -> void:
	var listed: Variant = race.get("events", [])
	if not (listed is Array):
		return
	for item in listed as Array:
		if not (item is Dictionary):
			continue
		var event: Dictionary = item
		var seq := int(event.get("seq", 0))
		if seq <= _event_seq:
			continue
		_event_seq = seq
		var gag := int(event.get("gag", 0))
		var owner := int(event.get("owner", 0))
		var target := int(event.get("target", 0))
		var at := Vector3(float(event.get("x", 0.0)), float(event.get("y", 0.0)), float(event.get("z", 0.0)))
		if gag == _RULES.BANANA:
			_drop_peel(at, true, owner)
		elif gag == _RULES.PIE:
			if owner == ToonNet.peer_id():
				_shoot_pie()
			elif target == ToonNet.peer_id():
				_spin = 1.4
		elif gag == _RULES.ANVIL and target == ToonNet.peer_id():
			_drop_anvil()
		elif gag == _RULES.ANVIL:
			_anvil_remote(target)


func _apply_loot(race: Dictionary) -> void:
	var listed: Variant = race.get("loot", [])
	if not (listed is Array):
		return
	var mine := ToonNet.peer_id()
	for item in listed as Array:
		if not (item is Dictionary):
			continue
		var card: Dictionary = item
		if int(card.get("peer", 0)) != mine:
			continue
		var seq := int(card.get("seq", 0))
		if seq <= _loot_seq:
			continue
		_loot_seq = seq
		_gag_roll = int(card.get("gag", _RULES.BANANA))
		_gag = 0
		_gag_spin = 2.0


func _apply_boxes(race: Dictionary) -> void:
	var listed: Variant = race.get("down", [])
	if not (listed is Array):
		return
	var down: Array = listed
	var now := Time.get_ticks_msec()
	for child in get_children():
		if not (child is Area3D) or not child.has_meta("slot"):
			continue
		var pad := child as Area3D
		var slot := int(pad.get_meta("slot"))
		var pending := int(pad.get_meta("pending", 0))
		var taken := false
		for held in down:
			if int(held) == slot:
				taken = true
		var hidden := taken or (pending > 0 and now - pending < 1000)
		if not hidden:
			pad.set_meta("pending", 0)
		pad.visible = not hidden
		pad.monitoring = not hidden


func _sync_remotes(delta: float) -> void:
	var race := _RACES.mine()
	var listed: Variant = race.get("racers", [])
	var want: Dictionary = {}
	if listed is Array:
		var racers: Array = listed
		for index in racers.size():
			if not (racers[index] is Dictionary):
				continue
			var racer: Dictionary = racers[index]
			var peer := int(racer.get("peer", 0))
			if peer == 0 or peer == ToonNet.peer_id():
				continue
			want[peer] = true
			var show := _remotes.get(peer) as Node3D
			if show == null:
				show = _make_remote(racer, index)
				_remotes[peer] = show
			_follow_remote(show, racer, index, delta)
	var gone: Array = []
	for key in _remotes.keys():
		if not want.has(key):
			gone.append(key)
	for key in gone:
		var old := _remotes[key] as Node3D
		if old != null and is_instance_valid(old):
			var blip := old.get_meta("blip") as TextureRect
			if blip != null:
				blip.queue_free()
			old.queue_free()
		_remotes.erase(key)


func _make_remote(racer: Dictionary, slot: int) -> Node3D:
	var root := Node3D.new()
	root.name = "RemoteKart"
	add_child(root)
	var dna: Array = []
	var row: Variant = racer.get("dna", [])
	if row is Array:
		dna = row
	var model := _MODEL.build(dna)
	model.rotate_y(PI)
	root.add_child(model)
	root.scale = Vector3(2.0, 2.0, 2.0)
	var dressed: Variant = racer.get("style", {})
	if dressed is Dictionary and not (dressed as Dictionary).is_empty():
		var seat := Node3D.new()
		seat.name = "ToonSeat"
		seat.position = Vector3(0.0, 0.1555, -0.1238)
		seat.scale = Vector3(0.5, 0.5, 0.5)
		root.add_child(seat)
		var actor := ToonActor.new()
		actor.name = "Driver"
		actor.footsteps = false
		seat.add_child(actor)
		actor.show_style(ToonStyle.from_dict(dressed))
		var body_scale := actor.transform.basis.get_scale().x
		var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
		actor.transform.basis = upright.scaled(Vector3.ONE * body_scale)
		_tuck_driver(actor)
		actor.pose_synced_loop("sit")
	var label := Label3D.new()
	label.text = String(racer.get("name", "Toon"))
	label.font = _GUI.sign_font()
	label.font_size = 42
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = _BLOTS[slot % _BLOTS.size()]
	label.outline_modulate = Color.WHITE
	label.position = Vector3(0.0, 2.4, 0.0)
	root.add_child(label)
	if _hud_root != null:
		var blip := TextureRect.new()
		blip.texture = _MAP_SPOT
		blip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		blip.stretch_mode = TextureRect.STRETCH_SCALE
		blip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blip.modulate = _BLOTS[slot % _BLOTS.size()]
		_hud_root.add_child(blip)
		root.set_meta("blip", blip)
	root.set_meta("flat", -1.0)
	var park := _grid_start(slot)
	if park != Vector3.INF:
		root.global_position = park
	return root


func _follow_remote(show: Node3D, racer: Dictionary, slot: int, delta: float) -> void:
	var driver := show.get_node_or_null("ToonSeat/Driver") as ToonActor
	if driver != null:
		driver.pose_synced_loop("sit")
	_tick_remote_flat(show, delta)
	var spot := Vector3(float(racer.get("x", 0.0)), float(racer.get("y", 0.0)), float(racer.get("z", 0.0)))
	var parked := spot.length_squared() < 4.0 and float(racer.get("along", 0.0)) <= 0.0
	if parked:
		if not bool(show.get_meta("parked", false)):
			var grid := _grid_start(slot)
			if grid != Vector3.INF:
				show.global_position = grid
			show.set_meta("parked", true)
		return
	if not bool(show.get_meta("got", false)):
		show.global_position = spot
		show.rotation.y = deg_to_rad(float(racer.get("yaw", 0.0)))
		if not parked:
			show.set_meta("got", true)
		return
	var weight := 1.0 - exp(-12.0 * delta)
	show.global_position = show.global_position.lerp(spot, weight)
	show.rotation.y = lerp_angle(show.rotation.y, deg_to_rad(float(racer.get("yaw", 0.0))), weight)


func _anvil_remote(peer: int) -> void:
	var show := _remotes.get(peer) as Node3D
	if show == null or float(show.get_meta("flat", -1.0)) >= 0.0:
		return
	var weight := _prop(_ANVIL, 1.0)
	if weight == null:
		return
	weight.position = Vector3(0.0, 50.0, 0.0)
	weight.scale = Vector3(7.0, 9.0, 7.0)
	show.add_child(weight)
	show.set_meta("anvil", weight)
	show.set_meta("flat", 0.0)


func _tick_remote_flat(show: Node3D, delta: float) -> void:
	var flat := float(show.get_meta("flat", -1.0))
	if flat < 0.0:
		return
	flat += delta
	show.set_meta("flat", flat)
	var weight := show.get_meta("anvil") as Node3D
	var body := show.get_node_or_null("Kart") as Node3D
	if weight != null and is_instance_valid(weight):
		weight.position.y = lerpf(50.0, 0.6, clampf(flat / 1.0, 0.0, 1.0))
		if flat >= 1.0:
			weight.scale.y = lerpf(9.0, 4.0, clampf((flat - 1.0) / 0.2, 0.0, 1.0))
		if flat >= 1.2:
			weight.queue_free()
			show.set_meta("anvil", null)
	if body != null and flat >= 0.92 and flat < 1.7:
		body.scale = Vector3(1.0, 0.1, 1.0)
	elif body != null and flat >= 1.7 and flat < 2.0:
		body.scale = Vector3(1.0, 2.0, 1.0)
	elif body != null and flat >= 2.0:
		body.scale = Vector3.ONE
		show.set_meta("flat", -1.0)


func _place_blips(view: Vector2, world: float) -> void:
	for key in _remotes.keys():
		var show := _remotes[key] as Node3D
		if show == null:
			continue
		var blip := show.get_meta("blip") as TextureRect
		if blip == null:
			continue
		var spot := show.global_position
		_GUI.place(blip, view, 1.1 + spot.x * world, 0.75 - spot.z * world, 0.0469, 0.0469)


func _seat_index() -> int:
	var listed: Variant = _RACES.mine().get("racers", [])
	if not (listed is Array):
		return 0
	var peer := ToonNet.peer_id()
	var racers: Array = listed
	for index in racers.size():
		if racers[index] is Dictionary and int((racers[index] as Dictionary).get("peer", 0)) == peer:
			return index
	return 0


func _standing() -> int:
	var listed: Variant = _RACES.mine().get("racers", [])
	if not (listed is Array):
		return 1
	var mine := float(_laps) * float(maxi(_points.size(), 1)) + float(_index)
	if _finished:
		var official := _RACES.my_place()
		if official > 0:
			return official
		mine = 1.0e12
	var place := 1
	var peer := ToonNet.peer_id()
	for item in listed as Array:
		if not (item is Dictionary):
			continue
		var racer: Dictionary = item
		if int(racer.get("peer", 0)) == peer:
			continue
		var along := float(racer.get("along", 0.0))
		if bool(racer.get("done", false)):
			along = 1.0e12
		if along > mine:
			place += 1
	return place


func _place_suffix(place: int) -> String:
	var teen := place % 100
	if teen >= 11 and teen <= 13:
		return "th"
	match place % 10:
		1:
			return "st"
		2:
			return "nd"
		3:
			return "rd"
		_:
			return "th"


func _play_music() -> void:
	var path := "res://assets/racing/audio/" + _RULES.music_file(track_id)
	var stream := ToonAudio.stream(path) as AudioStreamOggVorbis
	if stream == null:
		return
	stream.loop = true
	_ensure_race_bus()
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.bus = _RACE_BUS
	_music.volume_db = linear_to_db(0.7)
	add_child(_music)
	_music.play()
	_set_music_tempo(1.0)


func _ensure_race_bus() -> void:
	var index := AudioServer.get_bus_index(_RACE_BUS)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, _RACE_BUS)
		AudioServer.set_bus_send(index, "Master")
	if AudioServer.get_bus_effect_count(index) == 0:
		var shift := AudioEffectPitchShift.new()
		shift.pitch_scale = 1.0
		AudioServer.add_bus_effect(index, shift)
	_music_shift = AudioServer.get_bus_effect(index, 0) as AudioEffectPitchShift


## The lap tempo is the original 1 + laps * 0.5. Playing the stream faster
## also raises its pitch, so the bus shifts that pitch back down.
func _set_music_tempo(tempo: float) -> void:
	if _music == null:
		return
	var rate := maxf(tempo, 0.01)
	_music.pitch_scale = rate
	if _music_shift == null:
		return
	var index := AudioServer.get_bus_index(_RACE_BUS)
	if index < 0:
		return
	var faster := rate > 1.01
	AudioServer.set_bus_effect_enabled(index, 0, faster)
	_music_shift.pitch_scale = 1.0 / rate


func _leave_early() -> void:
	if _finished:
		return
	_finished = true
	_started = false
	_hud_note.text = "Leaving the race."
	_leave()


func _leave() -> void:
	ToonNet.race_act("exit", {})
	var pads = load("res://scenes/racing/speedway_racing.gd")
	pads.park_return(return_point, return_heading)
	ToonLoading.change_to(_SPEEDWAY)
