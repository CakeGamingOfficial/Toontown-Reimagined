extends Node

## DistributedTrolley. The car drives in along the station, waits, and leaves
## once somebody is aboard. Keys and wheels spin the way animateTrolley does.
## A solo ride then picks a one-player game from MinigamePlayerMatrix.

const ENTER_TIME := 2.0
const EXIT_TIME := 5.0
const COUNTDOWN := 10.0
const BOARD_TIME := 0.75
const SIT_TIME := 0.25
const EXIT_RUN := 1.0
const BOARD_CAM := 1.5
const LEAVE_CAM := 3.0
const RIDE_SCENE := "res://scenes/trolley/trolley_ride.tscn"
const AWAY_SFX := "res://assets/audio/sfx/SZ_trolley_away.ogg"
const BELL_SFX := "res://assets/audio/sfx/SZ_trolley_bell.ogg"

const _SEAT := Vector3(-3.9, -4.5, 3.0)
const _STEP := Vector3(-5.0, -4.5, 1.4)
const _REACH := 8.0

var _host: Node
var _car: Node3D
var _station: Node3D
var _rest := Vector3.ZERO
var _keys: Array[Node3D] = []
var _front: Array[Node3D] = []
var _back: Array[Node3D] = []
var _key_rest: Array[Transform3D] = []
var _front_rest: Array[Transform3D] = []
var _back_rest: Array[Transform3D] = []
var _clock: Label3D
var _exit: Button
var _mode := "enter"
var _age := 0.0
var _countdown := COUNTDOWN
var _aboard := false
var _departing := false
var _body: CharacterBody3D
var _actor: Node3D
var _sit := 0.0
var _from := Vector3.ZERO
var _pose := ""
var _sit_len := -1.0
var _exiting := false
var _exit_age := 0.0
var _cam_from := Vector3.ZERO
var _look_from := Vector3.ZERO
var _cam_blend := 1.0
var _leave_blend := 0.0
var _fog: ColorRect


func setup(host: Node) -> bool:
	_host = host
	var root := host.get_parent()
	if root == null:
		queue_free()
		return false
	_car = root.find_child("trolley_car", true, false) as Node3D
	if _car == null:
		queue_free()
		return false
	_station = _car.get_parent() as Node3D
	_rest = _car.position
	_collect(_car, "key", _keys, _key_rest)
	_collect(_car, "front_wheels", _front, _front_rest)
	_collect(_car, "back_wheels", _back, _back_rest)
	_car.position.x = _rest.x - 35.0
	_clock = Label3D.new()
	_clock.name = "TrolleyClock"
	_clock.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_clock.modulate = Color(0.9, 0.1, 0.1)
	_clock.font = ToonGui.sign_font()
	_clock.font_size = 64
	_clock.pixel_size = 0.05
	_clock.outline_size = 10
	_clock.outline_modulate = Color(0.2, 0.0, 0.0)
	_clock.position = Vector3(15.86, 13.82, 11.68)
	_clock.visible = false
	if _station != null:
		_station.add_child(_clock)
	_build_exit()
	_build_fog()
	_mode = "enter"
	_age = 0.0
	_play(AWAY_SFX)
	return true


func can_board() -> bool:
	return _car != null and not _departing and (_mode == "wait" or _mode == "countdown") and not _aboard


## Trolley.enterBoarding parents the camera to the car and holds it there
## until the rider gets off. The follow camera would stay inside the car.
func holds_camera() -> bool:
	return _aboard and _car != null


func near(body: Node3D) -> bool:
	if _car == null or body == null:
		return false
	var door := _car.global_transform * Vector3(-8.0, 0.0, 1.2)
	var offset := body.global_position - door
	offset.y = 0.0
	if offset.length() > _REACH:
		return false
	return body.global_position.y >= door.y - 2.5


func board(body: CharacterBody3D, actor: Node3D) -> void:
	_aboard = true
	_body = body
	_actor = actor
	_sit = 0.0
	_pose = ""
	_exiting = false
	_exit_age = 0.0
	_from = _car.global_transform.affine_inverse() * body.global_position
	_remember_camera()
	if _mode != "countdown":
		_mode = "countdown"
		_countdown = COUNTDOWN
		_clock.visible = true
		_exit.visible = true
		_paint_clock()


func tick(delta: float) -> void:
	if _car == null:
		return
	if _aboard:
		_cam_blend = minf(_cam_blend + delta / BOARD_CAM, 1.0)
	if _mode == "enter":
		_age += delta
		var t := clampf(_age / ENTER_TIME, 0.0, 1.0)
		_roll(_ease_out(t), ENTER_TIME, 35.0)
		if t >= 1.0:
			_mode = "wait"
			_car.position = _rest
			_reset_spin()
	elif _mode == "countdown":
		_countdown = maxf(_countdown - delta, 0.0)
		_paint_clock()
		_place_rider(delta)
		if _countdown <= 0.0 and _aboard and not _exiting:
			_depart()
	elif _mode == "leave":
		_age += delta
		var t := clampf(_age / EXIT_TIME, 0.0, 1.0)
		_roll(_ease_in(t), EXIT_TIME, 35.0)
		_place_rider(delta)
		if t >= 1.0 and not _departing:
			_departing = true
			_go_play()
	elif _aboard:
		_place_rider(delta)
	if _mode == "leave":
		_leave_blend = clampf(_age / LEAVE_CAM, 0.0, 1.0)
	_paint_fog()


func _depart() -> void:
	_mode = "leave"
	_age = 0.0
	_clock.visible = false
	_exit.visible = false
	_play(BELL_SFX)
	_play(AWAY_SFX)


func _go_play() -> void:
	var ride := load("res://scenes/trolley/trolley_ride.gd") as GDScript
	ride.hood = _host._hood if _host != null else 2000
	ride.return_scene = _host._scene_path() if _host != null else ""
	get_tree().change_scene_to_file(RIDE_SCENE)


func _roll(t: float, seconds: float, distance: float) -> void:
	var start := _rest.x - 35.0 if _mode == "enter" else _rest.x
	var end := _rest.x if _mode == "enter" else _rest.x + 35.0
	_car.position.x = lerpf(start, end, t)
	var key_angle := deg_to_rad(float(int(round(seconds))) * 360.0 * t)
	var wheel_angle := deg_to_rad(distance / (2.0 * PI * 0.95) * 360.0 * t)
	_spin(_keys, _key_rest, key_angle)
	_spin(_front, _front_rest, wheel_angle)
	_spin(_back, _back_rest, wheel_angle)


## Point3(-35, 0, 8), HPR (-90, 0, 0): thirty-five units off the open side,
## looking back at the bench. The hop takes 1.5 seconds, then the shot stays.
func aim(camera: Camera3D) -> void:
	if camera == null or _car == null:
		return
	var dest := _car.global_transform * Vector3(-35.0, 0.0, 8.0)
	var look := _car.global_transform * Vector3(0.0, 0.0, 8.0)
	var t := clampf(_cam_blend, 0.0, 1.0)
	var pos := _cam_from.lerp(dest, t)
	var focus := _look_from.lerp(look, t)
	# Trolley.enterTrolleyLeaving swings beside the car over 3 seconds.
	if _leave_blend > 0.0:
		var u := _ease_in_out(clampf(_leave_blend, 0.0, 1.0))
		var beside := _car.global_transform * Vector3(0.0, 18.55, 3.75)
		var beside_look := _car.global_transform * Vector3(0.0, -4.0, 3.75)
		pos = pos.lerp(beside, u)
		focus = focus.lerp(beside_look, u)
	camera.global_position = pos
	if camera.global_position.distance_squared_to(focus) > 0.04:
		var up := _car.global_basis.z
		if up.dot(Vector3.UP) < 0.0:
			up = -up
		camera.look_at(focus, up if up.length_squared() > 0.01 else Vector3.UP)


func _remember_camera() -> void:
	_cam_blend = 0.0
	var camera := _host._camera as Camera3D if _host != null else null
	if camera == null or _car == null:
		_cam_from = _car.global_transform * Vector3(-35.0, 0.0, 8.0) if _car != null else Vector3.ZERO
		_look_from = _car.global_transform * Vector3(0.0, 0.0, 8.0) if _car != null else Vector3.FORWARD
		return
	_cam_from = camera.global_position
	_look_from = _cam_from - camera.global_basis.z * 12.0


## fillSlot runs to the step, turns to face out of the car, plays sit-start,
## and then loops sit. The seat drop waits through the first quarter of
## sit-start and lands during the second quarter.
func _place_rider(delta: float) -> void:
	if not _aboard or _body == null:
		return
	if _exiting:
		_place_exit(delta)
		return
	_sit += delta
	var length := _sit_length()
	var sat := BOARD_TIME + SIT_TIME
	var local := _SEAT
	if _sit < BOARD_TIME:
		local = _from.lerp(_STEP, clampf(_sit / BOARD_TIME, 0.0, 1.0))
		_play_run(delta)
		_face_heading(_approach_heading())
	elif _sit < sat:
		local = _STEP
		var u := clampf((_sit - BOARD_TIME) / SIT_TIME, 0.0, 1.0)
		_play_run(delta)
		var heading := rad_to_deg(lerp_angle(deg_to_rad(_approach_heading()), deg_to_rad(_sit_heading()), u))
		_face_heading(heading)
	elif length > 0.0 and _sit < sat + length:
		local = _seat_local(_sit - sat, length)
		_play_clip("sit-start", delta, false)
		_face_heading(_sit_heading())
	else:
		local = _SEAT
		if length > 0.0:
			_play_clip("sit", delta, true)
		else:
			_stand(delta)
		_face_heading(_sit_heading())
	_body.global_position = _car.global_transform * local
	_body.velocity = Vector3.ZERO


func _place_exit(delta: float) -> void:
	_exit_age += delta
	var length := _sit_length()
	if length > 0.0 and _exit_age < length:
		var u := _exit_age / length
		var local := _SEAT
		if u >= 0.5 and u < 0.75:
			local = _SEAT.lerp(_STEP, (u - 0.5) / 0.25)
		elif u >= 0.75:
			local = _STEP
		_body.global_position = _car.global_transform * local
		_body.velocity = Vector3.ZERO
		_play_reverse_sit(delta)
		_face_heading(_sit_heading())
		return
	var start := _car.global_transform * _STEP
	var dest := _off_point()
	var run_t := _exit_age - length
	if run_t < EXIT_RUN:
		if _pose != "off":
			_pose = "off"
			var rising := _toon()
			if rising != null:
				rising.clear_gesture()
		var u := clampf(run_t / EXIT_RUN, 0.0, 1.0)
		_body.global_position = start.lerp(dest, u)
		_body.velocity = Vector3.ZERO
		var move := dest - start
		move.y = 0.0
		if move.length_squared() > 0.0001 and _host != null:
			_face_heading(_host._heading_toward(move))
		_play_run(delta)
		return
	_body.global_position = dest
	_drop_off()


func _get_off() -> void:
	if not _aboard or _mode != "countdown" or _body == null or _exiting:
		return
	_clock.visible = false
	_exit.visible = false
	# emptySlot reverses sit-start once the toon is in the seat, then runs off.
	if _pose == "sit":
		_exiting = true
		_exit_age = 0.0
		_pose = ""
		return
	_drop_off()


func _drop_off() -> void:
	_aboard = false
	_exiting = false
	_pose = ""
	_mode = "wait"
	_clock.visible = false
	_exit.visible = false
	if _body != null:
		_body.global_position = _off_point()
		_body.velocity = Vector3.ZERO
	_stand(0.016)
	if _host != null:
		_host._locked = false


func _off_point() -> Vector3:
	if _station == null or _body == null:
		return _body.global_position if _body != null else Vector3.ZERO
	return _station.global_transform * Vector3(21.0, -5.0, 0.2)


func _seat_local(age: float, length: float) -> Vector3:
	var u := age / length
	if u < 0.25:
		return _STEP
	if u < 0.5:
		return _STEP.lerp(_SEAT, (u - 0.25) / 0.25)
	return _SEAT


func _sit_length() -> float:
	if _sit_len >= 0.0:
		return _sit_len
	var toon := _toon()
	_sit_len = toon.action_length("sit-start") if toon != null else 0.0
	return _sit_len


func _approach_heading() -> float:
	if _car == null or _host == null:
		return 0.0
	var travel := _car.global_transform.basis * (_STEP - _from)
	travel.y = 0.0
	if travel.length_squared() < 0.0001:
		return _sit_heading()
	return _host._heading_toward(travel)


func _sit_heading() -> float:
	if _car == null or _host == null:
		return 0.0
	var ahead := -_car.global_basis.x
	ahead.y = 0.0
	if ahead.length_squared() < 0.0001:
		return 0.0
	return _host._heading_toward(ahead)


func _face_heading(heading: float) -> void:
	if _actor != null and _host != null:
		_host._face(_actor, heading)


func _toon() -> ToonActor:
	return _actor as ToonActor


func _play_run(delta: float) -> void:
	var toon := _toon()
	if toon == null:
		return
	if _pose != "run" and _pose != "off":
		_pose = "run"
		toon.clear_gesture()
	toon.play_run(delta)


func _play_clip(suffix: String, delta: float, loop: bool) -> void:
	var toon := _toon()
	if toon == null:
		return
	if _pose != suffix:
		_pose = suffix
		toon.play_gesture(suffix, 1.0, loop)
	toon.set_locomotion(0.0, false, false, delta)


func _play_reverse_sit(delta: float) -> void:
	var toon := _toon()
	if toon == null:
		return
	if _pose != "stand":
		_pose = "stand"
		toon.play_gesture("sit-start", -1.0, false)
	toon.set_locomotion(0.0, false, false, delta)


func _stand(delta: float) -> void:
	var toon := _toon()
	if toon == null:
		return
	toon.clear_gesture()
	toon.set_locomotion(0.0, false, false, delta)


func _paint_clock() -> void:
	_clock.text = str(int(ceil(_countdown)))


func _build_exit() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TrolleyExit"
	layer.layer = 30
	add_child(layer)
	_exit = Button.new()
	_exit.text = "Hop off"
	_exit.visible = false
	_exit.focus_mode = Control.FOCUS_NONE
	_exit.pressed.connect(_get_off)
	_exit.add_theme_font_override("font", ToonGui.sign_font())
	_exit.add_theme_font_size_override("font_size", 36)
	_exit.add_theme_color_override("font_color", Color(1.0, 1.0, 0.65))
	_exit.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.85))
	_exit.add_theme_color_override("font_pressed_color", Color(1.0, 0.9, 0.45))
	var normal := _hop_box(Color(0.92, 0.08, 0.08))
	var hover := _hop_box(Color(1.0, 0.22, 0.16))
	var pressed := _hop_box(Color(0.7, 0.04, 0.04))
	_exit.add_theme_stylebox_override("normal", normal)
	_exit.add_theme_stylebox_override("hover", hover)
	_exit.add_theme_stylebox_override("pressed", pressed)
	_exit.add_theme_stylebox_override("focus", normal)
	ToonGui.button_sounds(_exit)
	layer.add_child(_exit)
	_exit.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_exit.offset_left = -130.0
	_exit.offset_right = 130.0
	_exit.offset_top = 18.0
	_exit.offset_bottom = 86.0


func _collect(root: Node, node_name: String, into: Array[Node3D], rests: Array[Transform3D]) -> void:
	var found := root.find_child(node_name, true, false) as Node3D
	if found == null:
		return
	into.append(found)
	rests.append(found.transform)


func _spin(nodes: Array[Node3D], rests: Array[Transform3D], angle: float) -> void:
	for index in nodes.size():
		var rest := rests[index]
		var axis := rest.basis.z
		if axis.length_squared() < 0.0001:
			continue
		nodes[index].transform = Transform3D(rest.basis.rotated(axis.normalized(), angle), rest.origin)


func _reset_spin() -> void:
	_spin(_keys, _key_rest, 0.0)
	_spin(_front, _front_rest, 0.0)
	_spin(_back, _back_rest, 0.0)


func _build_fog() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TrolleyFog"
	layer.layer = 20
	add_child(layer)
	_fog = ColorRect.new()
	_fog.color = Color(0.0, 0.0, 0.0, 1.0)
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fog)


## The station fog swallows the car on the way in and on the way out.
## Enter is opaque behind x = rest - 22 and clear by rest - 15.
## Leave is clear until 15 units down the track and black by 22.
func _paint_fog() -> void:
	if _fog == null:
		return
	var traveled := _car.position.x - _rest.x
	var amount := 0.0
	if _mode == "enter":
		amount = clampf((-15.0 - traveled) / 7.0, 0.0, 1.0)
	elif _mode == "leave":
		amount = clampf((traveled - 15.0) / 7.0, 0.0, 1.0)
	_fog.color.a = amount


func _hop_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(22)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


func _ease_in(t: float) -> float:
	return t * t * t


func _play(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var stream := AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		return
	var player := ToonAudio.effect_player()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
