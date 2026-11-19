extends "res://scenes/trolley/trolley_minigame.gd"

## Photo Fun, from DistributedPhotoGame, PhotoGameBase, and PhotoGameGlobals.
## The playground is the one the trolley was boarded in. Five assignments ask
## for one subject in one pose. The mouse aims the viewfinder, the arrows and
## the screen edges turn the tripod, Ctrl zooms, and a click spends one film.

const _FINDER_PATH := "res://assets/minigames/photo/viewfinder_card.png"
const _FRAME_PATH := "res://assets/minigames/photo/pictureframe.png"
const _CAMERA_PATH := "res://assets/minigames/photo/camera.png"
const _PALETTE_PATH := "res://assets/minigames/photo/palette.png"
const _SKY := preload("res://scenes/sky/toontown_sky.gd")
const _GUI := preload("res://scenes/toons/toon_gui.gd")
const _ASSIGNMENTS := 5
const _OUT_FOV := 55.0
const _ZOOM_FOV := 22.0
const _ZOOM_TIME := 0.5
const _FINDER_W := 1.337868 * 0.55
const _FINDER_H := 1.0034 * 0.55
const _HOLE := Rect2(0.084, 0.068, 0.822, 0.589)
const _TILTS: Array[float] = [0.0, 2.0, -2.0, -4.0, 6.0]
const _SNOW_SHADER := "shader_type particles;

float rand(inout uint seed) {
	seed = hash(seed + 1u);
	return float(seed) / 4294967295.0;
}

void start() {
	uint seed = RANDOM_SEED;
	float theta = rand(seed) * TAU;
	float radius = 50.0 * sqrt(rand(seed));
	vec3 pos = vec3(cos(theta) * radius, 0.0, sin(theta) * radius);
	TRANSFORM[3].xyz = pos;
	if (radius > 0.001) {
		VELOCITY = vec3(pos.x, 0.0, pos.z) / radius * 0.1;
	} else {
		VELOCITY = vec3(0.0);
	}
	float spin = radians((rand(seed) * 2.0 - 1.0) * 500.0);
	float ang = radians((rand(seed) * 2.0 - 1.0) * 10.0);
	CUSTOM = vec4(ang, spin, 0.0, TIME);
	COLOR = vec4(1.0, 1.0, 1.0, 0.0);
	TRANSFORM[0] = vec4(0.03125, 0.0, 0.0, 0.0);
	TRANSFORM[1] = vec4(0.0, 0.03125, 0.0, 0.0);
	TRANSFORM[2] = vec4(0.0, 0.0, 0.03125, 0.0);
}

void process() {
	uint seed = hash(INDEX + uint(TIME * 60.0) * 4099u);
	vec3 jitter = vec3(rand(seed) * 2.0 - 1.0, rand(seed) * 2.0 - 1.0, rand(seed) * 2.0 - 1.0);
	float len = length(jitter);
	if (len > 0.001) {
		jitter /= len;
	}
	VELOCITY += (vec3(0.0, -1.5, 0.0) + jitter * 10.0) * DELTA;
	if (length(VELOCITY) > 400.0) {
		VELOCITY = normalize(VELOCITY) * 400.0;
	}
	TRANSFORM[3].xyz += VELOCITY * DELTA;
	float lived = TIME - CUSTOM.w;
	float age = clamp(lived / 4.5, 0.0, 1.0);
	float size = mix(0.03125, 0.5, age);
	float turn = CUSTOM.x + CUSTOM.y * lived;
	float c = cos(turn);
	float sn = sin(turn);
	TRANSFORM[0] = vec4(c * size, sn * size, 0.0, 0.0);
	TRANSFORM[1] = vec4(-sn * size, c * size, 0.0, 0.0);
	TRANSFORM[2] = vec4(0.0, 0.0, size, 0.0);
	COLOR = vec4(1.0, 1.0, 1.0, age);
}
"
const _SCENES := {
	1000: "res://assets/neighborhoods/donalds_dock/donalds_dock.glb",
	2000: "res://assets/neighborhoods/toontown_central/toontown_central.glb",
	3000: "res://assets/neighborhoods/the_burrrgh/the_burrrgh.glb",
	4000: "res://assets/neighborhoods/minnies_melodyland/minnies_melodyland.glb",
	5000: "res://assets/neighborhoods/daisy_gardens/daisy_gardens.glb",
	9000: "res://assets/neighborhoods/donalds_dreamland/donalds_dreamland.glb",
}

var _subjects: Array[ToonActor] = []
var _styles: Array[ToonStyle] = []
var _tracks: Array = []
var _phase: PackedInt32Array = PackedInt32Array()
var _phase_time: PackedFloat32Array = PackedFloat32Array()
var _shown: PackedStringArray = PackedStringArray()
var _assignments: Array = []
var _best: PackedInt32Array = PackedInt32Array()
var _mine: PackedInt32Array = PackedInt32Array()
var _holder: PackedInt32Array = PackedInt32Array()
var _got: PackedInt32Array = PackedInt32Array()
var _tripod := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0
var _zoomed := false
var _ctrl := false
var _film := 0
var _film_pulse := 0.0
var _adjust: AudioStreamPlayer
var _finder: TextureRect
var _blackout: ColorRect
var _film_icon: TextureRect
var _film_label: Label
var _film_word: Label
var _score_frame: TextureRect
var _score_label: Label
var _cards: Array[TextureRect] = []
var _holes: Array[TextureRect] = []
var _shots: Array[TextureRect] = []
var _card_bonus: Array[Label] = []
var _card_stars: Array[TextureRect] = []
var _portraits: Array[ToonActor] = []
var _tilts: PackedFloat32Array = PackedFloat32Array()
var _finder_tex: Texture2D
var _frame_tex: Texture2D
var _camera_tex: Texture2D
var _film_tex: Texture2D
var _star_tex: Texture2D
var _hud_root: Control
var _capture_view: SubViewport
var _capture_cam: Camera3D
var _boat: Node3D
var _boat_time := 0.0
var _approach_from := Vector3.ZERO
var _approach_basis := Basis()
var _intro := 0.0
var _spin_left := 0.0
var _tilt_left := 0.0
var _spin_time := 0.0
var _grab_wait := 0
var _grab_cards: Array[int] = []
var _end_after_shot := false
var _noted_film := false
var _subject_rng := RandomNumberGenerator.new()
var _lap_points: Array = []
var _lap_anims: Array = []
var _lap_moves: Array = []
var _lap_face: PackedFloat32Array = PackedFloat32Array()
var _cannon_rig: Node3D
var _swivel: Node3D


func _init() -> void:
	title = "Photo Fun"
	instructions = "Capture photos matching the toons shown at the bottom. Aim the camera with the mouse, and left click to take a picture. Press Ctrl to zoom in/out, and look around with the arrow keys.  Pictures with higher ratings get more points!"
	duration = 120.0


func _build() -> void:
	var area := _area(_hood_id())
	duration = float(area["time"])
	_film = int(area["film"])
	_yaw = float(area["heading"])
	_pitch = float(area["pitch"])
	_load_art()
	var scene := _show(String(area["scene"]))
	_tripod = _tripod_at(scene, area)
	_camera.position = _tripod
	_camera.fov = _OUT_FOV
	_camera.far = 2000.0
	_camera.current = true
	_plant_cannon()
	_block_shots(scene)
	_aim_camera()
	_spawn_subjects(area)
	_make_assignments(area)
	_dress(_hood_id(), area)
	if _hood_id() == 1000:
		_float_boat(scene)
	if _hood_id() == 3000:
		_start_snow()
	_build_hud()
	_build_capture()
	_recount()


## The rules card covers the screen, so the four-second fly-in starts when the
## playground is actually visible and the clock waits until the camera lands.
func begin() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _hud_root != null:
		_hud_root.visible = true
	_approach_from = _panda(0.0, -50.0 if _hood_id() == 4000 else 50.0, 20.0)
	_camera.position = _approach_from
	if _approach_from.distance_squared_to(_tripod) > 0.25:
		_camera.look_at(_tripod, Vector3.UP)
	_approach_basis = _camera.basis
	_intro = 4.0


func _process(delta: float) -> void:
	if _intro > 0.0:
		_intro = maxf(_intro - delta, 0.0)
		var along := 1.0 - _intro / 4.0
		var eased := along * along * (3.0 - 2.0 * along)
		_camera.position = _approach_from.lerp(_tripod, eased)
		_camera.basis = _approach_basis
		_move_stage(delta)
		_layout()
		if _intro <= 0.0:
			_mount_camera()
			super.begin()
			_aim_camera()
		return
	super._process(delta)


func _play(delta: float) -> void:
	_collect_shot()
	_sync_photos()
	_finish_if_everyone_out()
	_layout()
	_turn(delta)
	_swing(delta)
	_aim_camera()
	_zoom(delta)
	_move_stage(delta)
	_veil(delta)
	_throb(delta)
	_aim_finder()


func _move_stage(delta: float) -> void:
	for index in _subjects.size():
		_step_subject(index, delta)
	for index in _portraits.size():
		var pose := ""
		if index < _assignments.size():
			pose = String((_assignments[index] as Dictionary)["pose"])
		_drive(_portraits[index], pose, false, delta)
	_bob_boat(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not playing or not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	get_viewport().set_input_as_handled()
	_snap()


func _hood_id() -> int:
	var id := int(_RIDE.hood)
	if _SCENES.has(id):
		return id
	return 2000


func _tripod_at(scene: Node, area: Dictionary) -> Vector3:
	var offset: Vector3 = area["offset"]
	if bool(area["gazebo"]) and scene != null:
		var gazebo := _named(scene, "gazebo")
		if gazebo != null:
			return gazebo.global_position + _panda(offset.x, offset.y, offset.z)
	var root: Vector3 = area["root"]
	return _panda(root.x + offset.x, root.y + offset.y, root.z + offset.z)


func _named(node: Node, piece: String) -> Node3D:
	if node is Node3D and String(node.name).to_lower().contains(piece):
		return node as Node3D
	for child in node.get_children():
		var found := _named(child, piece)
		if found != null:
			return found
	return null


func _spawn_subjects(area: Dictionary) -> void:
	# The original reseeds the subjects from the clock, so each player watches
	# a different set. Assignments stay on the shared trolley seed.
	_subject_rng.randomize()
	var paths: Array = area["paths"]
	var rel: Array = area["rel"]
	var anims: Array = area["anims"]
	var moves: Array = area["moves"]
	for index in paths.size():
		var points: Array = paths[index]
		var style := _random_style()
		var actor := ToonActor.new()
		actor.name = "Subject%d" % index
		add_child(actor)
		actor.show_style(style)
		var set_index := int(rel[index]) if index < rel.size() else 0
		var home: Vector3 = points[0]
		var face := 0.0
		if points.size() > 1:
			var nxt: Vector3 = points[1]
			face = _yaw_toward(_panda(home.x, home.y, home.z), _panda(nxt.x, nxt.y, nxt.z))
		_lap_points.append(points)
		_lap_anims.append(anims[set_index])
		_lap_moves.append(moves[set_index])
		_lap_face.append(face)
		actor.position = _panda(home.x, home.y, home.z)
		actor.rotation.y = face
		_subjects.append(actor)
		_styles.append(style)
		_tracks.append(_one_lap(index))
		_phase.append(0)
		_phase_time.append(0.0)
		_shown.append("")


func _random_style() -> ToonStyle:
	var style := ToonStyle.new()
	var species := String(ToonStyle.SPECIES[_subject_rng.randi_range(0, ToonStyle.SPECIES.size() - 1)])
	var heads: Array = ToonStyle.HEADS[species]
	style.head = String(heads[_subject_rng.randi_range(0, heads.size() - 1)])
	var size := String(ToonStyle.SIZES[_subject_rng.randi_range(0, ToonStyle.SIZES.size() - 1)])
	var girl := _subject_rng.randi_range(0, 1) == 1
	style.gender = "f" if girl else "m"
	style.torso = size + ("d" if girl else "s")
	style.legs = size
	style.head_color = _subject_rng.randi_range(0, ToonStyle.FUR.size() - 1)
	style.arm_color = style.head_color
	style.leg_color = style.head_color
	style.glove_color = 0
	style.top_tex = _subject_rng.randi_range(0, ToonStyle.SHIRTS.size() - 1)
	style.top_color = _subject_rng.randi_range(0, ToonStyle.CLOTHES.size() - 1)
	style.bot_tex = _subject_rng.randi_range(0, mini(ToonStyle.SHORTS.size(), ToonStyle.SKIRTS.size()) - 1)
	style.bot_color = _subject_rng.randi_range(0, ToonStyle.CLOTHES.size() - 1)
	return style


## One lap of generateToonTrack. The first move roll is thrown away and only
## decides whether the turn is skipped. The pose plays once. A finished lap
## builds the next one.
func _one_lap(index: int) -> Array:
	var phases: Array = []
	var points: Array = _lap_points[index]
	var anims: Array = _lap_anims[index]
	var moves: Array = _lap_moves[index]
	if points.size() < 2 or moves.is_empty() or anims.is_empty():
		return phases
	var actor := _subjects[index]
	var here: Vector3 = points[0]
	var facing := _lap_face[index]
	for point in points.size():
		var nxt: Vector3 = points[(point + 1) % points.size()]
		var start := _panda(here.x, here.y, here.z)
		var dest := _panda(nxt.x, nxt.y, nxt.z)
		var toward := _yaw_toward(start, dest)
		var pose := String(anims[_subject_rng.randi_range(0, anims.size() - 1)])
		var tossed: Array = moves[_subject_rng.randi_range(0, moves.size() - 1)]
		var turn_time := 0.0 if String(tossed[0]) == "swim" else 0.2
		var chosen: Array = moves[_subject_rng.randi_range(0, moves.size() - 1)]
		var mode := String(chosen[0])
		if turn_time > 0.0:
			phases.append({
				"name": "turn",
				"dur": turn_time,
				"at": start,
				"yaw0": facing,
				"yaw1": toward,
				"interest": 1.0,
			})
		var span := maxf(start.distance_to(dest) * 0.25 * float(chosen[1]), 0.05)
		phases.append({
			"name": mode,
			"dur": span,
			"a": start,
			"b": dest,
			"yaw": toward,
			"interest": 1.0,
		})
		facing = toward
		here = nxt
		if pose == "":
			continue
		var length := actor.action_length(pose)
		if length <= 0.05:
			length = 2.0
		phases.append({
			"name": pose,
			"dur": length,
			"at": dest,
			"yaw": toward,
			"interest": 2.0,
		})
	_lap_face[index] = facing
	return phases


func _make_assignments(area: Dictionary) -> void:
	var paths: Array = area["paths"]
	var rel: Array = area["rel"]
	var anims: Array = area["anims"]
	var moves: Array = area["moves"]
	var seen: Dictionary = {}
	var guard := 0
	while _assignments.size() < _ASSIGNMENTS and guard < 400:
		guard += 1
		var subject := shared_int(paths.size())
		var set_index := int(rel[subject]) if subject < rel.size() else 0
		var pool: Array = []
		var pose_list: Array = anims[set_index]
		var move_list: Array = moves[set_index]
		for pose in pose_list:
			if String(pose) != "":
				pool.append(String(pose))
		for move in move_list:
			var row: Array = move
			pool.append(String(row[0]))
		if pool.is_empty():
			continue
		var pose := String(pool[shared_int(pool.size())])
		var key := "%d|%s" % [subject, pose]
		if seen.has(key):
			continue
		seen[key] = true
		_assignments.append({"subject": subject, "pose": pose})
	_best.resize(_assignments.size())
	_mine.resize(_assignments.size())
	_holder.resize(_assignments.size())
	_got.resize(_assignments.size())
	for index in _holder.size():
		_holder[index] = -1


func _step_subject(index: int, delta: float) -> void:
	var phases: Array = _tracks[index]
	if phases.is_empty():
		return
	var cursor := _phase[index]
	var age := _phase_time[index] + delta
	var phase: Dictionary = phases[cursor]
	var dur := float(phase["dur"])
	var guard := 0
	while age >= dur and phases.size() > 0 and guard < 12:
		guard += 1
		age -= dur
		cursor += 1
		if cursor >= phases.size():
			phases = _one_lap(index)
			_tracks[index] = phases
			cursor = 0
			if phases.is_empty():
				break
		phase = phases[cursor]
		dur = float(phase["dur"])
		if dur <= 0.0:
			break
	_phase[index] = cursor
	_phase_time[index] = age
	var actor := _subjects[index]
	var name := String(phase["name"])
	var changed := _shown[index] != name
	_shown[index] = name
	if phase.has("a"):
		var from: Vector3 = phase["a"]
		var to: Vector3 = phase["b"]
		actor.position = from.lerp(to, clampf(age / maxf(dur, 0.001), 0.0, 1.0))
		actor.rotation.y = float(phase["yaw"])
	elif phase.has("yaw0"):
		actor.position = phase["at"]
		var blend := clampf(age / maxf(dur, 0.001), 0.0, 1.0)
		actor.rotation.y = lerp_angle(float(phase["yaw0"]), float(phase["yaw1"]), blend)
	else:
		actor.position = phase["at"]
		actor.rotation.y = float(phase["yaw"])
	_drive(actor, name, changed, delta)


func _drive(actor: ToonActor, mode: String, changed: bool, delta: float) -> void:
	if changed:
		var swim := mode == "swim"
		if actor.is_swimming() != swim:
			actor.set_swimming(swim)
		actor.set_sad(mode == "sad-walk")
		if mode == "walk" or mode == "run" or mode == "sad-walk" or mode == "swim" or mode == "turn" or mode == "catch-run" or mode == "running-jump":
			actor.clear_gesture()
		else:
			# The card keeps looping. The toon on the path plays the pose once.
			actor.play_gesture(mode, 1.0, actor.has_meta("card"))
	var speed := 0.0
	if mode == "walk" or mode == "sad-walk" or mode == "swim":
		speed = 4.0
	elif mode == "run" or mode == "catch-run" or mode == "running-jump":
		speed = 12.0
	actor.set_locomotion(speed, mode == "turn", mode == "running-jump", delta)


func _turn(delta: float) -> void:
	var view := get_viewport().get_visible_rect().size
	var mouse := get_viewport().get_mouse_position()
	var left := Input.is_key_pressed(KEY_LEFT) or mouse.x < view.x * 0.05
	var right := Input.is_key_pressed(KEY_RIGHT) or mouse.x > view.x * 0.95
	var up := Input.is_key_pressed(KEY_UP) or mouse.y < view.y * 0.05
	var down := Input.is_key_pressed(KEY_DOWN) or mouse.y > view.y * 0.95
	var yaw_vel := 0.0
	var pitch_vel := 0.0
	if left:
		yaw_vel += 25.0
	if right:
		yaw_vel -= 25.0
	if up:
		pitch_vel += 25.0
	if down:
		pitch_vel -= 25.0
	_yaw += yaw_vel * delta
	_pitch = clampf(_pitch + pitch_vel * delta, -15.0, 10.0)
	var moving := yaw_vel != 0.0 or pitch_vel != 0.0
	if moving and _adjust == null:
		_adjust = _loop_sfx("MG_cannon_adjust", 0.6)
	elif not moving and _adjust != null:
		_adjust.stop()
		_adjust.queue_free()
		_adjust = null
	var ctrl := Input.is_key_pressed(KEY_CTRL)
	if ctrl and not _ctrl:
		var angles := _finder_angles()
		var zooming_in := not _zoomed
		_zoomed = not _zoomed
		var portion := (1.0 - 0.4) if zooming_in else ((1.0 - 0.4) / 0.4)
		var h_move := angles.x * portion
		var v_move := angles.y * portion
		# __doZoom, zoomFlip 1. Zooming in swings toward the viewfinder.
		if zooming_in:
			_spin_left = -h_move
			_tilt_left = v_move
		else:
			_spin_left = h_move
			_tilt_left = -v_move
		_spin_time = _ZOOM_TIME
		_sfx("Photo_zoom")
	_ctrl = ctrl


func _swing(delta: float) -> void:
	if _spin_time <= 0.0:
		return
	var take := minf(delta, _spin_time) / _spin_time
	_yaw += _spin_left * take
	_pitch += _tilt_left * take
	_spin_left *= 1.0 - take
	_tilt_left *= 1.0 - take
	_spin_time = maxf(_spin_time - delta, 0.0)
	_pitch = clampf(_pitch, -15.0, 10.0)


func _finder_angles() -> Vector2:
	var view := get_viewport().get_visible_rect().size
	if view.x < 2.0 or view.y < 2.0:
		return Vector2.ZERO
	var mouse := get_viewport().get_mouse_position()
	var ndc_x := mouse.x / view.x * 2.0 - 1.0
	var ndc_y := 1.0 - mouse.y / view.y * 2.0
	var aspect := view.x / view.y
	var v_half := deg_to_rad(_camera.fov * 0.5)
	var h_half := atan(tan(v_half) * aspect)
	var heading := rad_to_deg(atan(ndc_x * tan(h_half)))
	var pitch := rad_to_deg(atan(ndc_y * tan(v_half)))
	return Vector2(heading, pitch)


func _aim_camera() -> void:
	_aim_swivel()
	if _swivel != null:
		_camera.global_position = _swivel.global_position
	else:
		_camera.position = _tripod
	_camera.rotation = Vector3(deg_to_rad(-_pitch), deg_to_rad(_yaw), 0.0)


func _aim_swivel() -> void:
	if _swivel == null:
		return
	# The cannon node still lives in panda axes: heading about Z, then pitch about X.
	var turn := Quaternion(Vector3(0.0, 0.0, 1.0), deg_to_rad(_yaw))
	var tilt := Quaternion(Vector3(1.0, 0.0, 0.0), deg_to_rad(_pitch))
	_swivel.quaternion = turn * tilt


func _zoom(delta: float) -> void:
	var target := _ZOOM_FOV if _zoomed else _OUT_FOV
	var step := absf(_OUT_FOV - _ZOOM_FOV) / _ZOOM_TIME * delta
	_camera.fov = move_toward(_camera.fov, target, step)


func _snap() -> void:
	if _film <= 0 or _over:
		return
	_sfx("Photo_shutter")
	_film_pulse = 0.3
	_arm_capture()
	var hits := _ray_hits()
	for index in _subjects.size():
		if not hits.has(index):
			continue
		var counts: Dictionary = hits[index]
		var center := int(counts["g"])
		var bottom := int(counts["b"])
		var top := int(counts["t"])
		var right := int(counts["r"])
		var left := int(counts["l"])
		var quality := float(center - (bottom + top + right + left))
		var too_close := (bottom > 0 and top > 0) or (left > 0 and right > 0)
		var portrait := bottom > 0 and top == 0 and left == 0 and right == 0
		var subject_h := rad_to_deg(_subjects[index].rotation.y)
		var angle := absf(fposmod(_yaw + 180.0 - subject_h, 360.0) - 180.0)
		var interest := 1.0
		var phases: Array = _tracks[index]
		if not phases.is_empty():
			var phase: Dictionary = phases[_phase[index]]
			interest = float(phase["interest"])
		var stars := _judge(quality, too_close, portrait, angle, interest)
		if stars <= 0:
			continue
		_award(index, _shown[index], stars)
	_film -= 1
	if _film_label != null:
		_film_label.text = str(_film)
	_sfx("Photo_instamatic")
	_recount()
	if _film <= 0:
		_note_film()
		_end_after_shot = _grab_wait > 0
		if _grab_wait <= 0:
			_finish_if_everyone_out()


func _judge(quality: float, too_close: bool, portrait: bool, angle: float, interest: float) -> int:
	# judgePhoto. A centered, interesting pose from the side rates higher.
	# Facing the camera straight on costs a star. A miss returns nothing.
	if quality <= 0.0:
		return 0
	var stars := 0.0
	if angle >= 135.0:
		stars += 2.0
	elif angle >= 90.0:
		stars += 1.0
	elif angle <= 60.0:
		stars -= 1.0
	stars += interest
	if quality >= 5.0 and (not too_close or portrait):
		stars += 1.0
		if quality >= 10.0:
			stars += 1.0
			if quality >= 15.0:
				stars += 1.0
	stars -= 2.0
	if stars > 5.0:
		stars = 5.0
	if stars <= 0.0:
		return 1
	return int(floor(stars))


func _award(subject: int, pose: String, stars: int) -> void:
	var me := ToonNet.peer_id()
	for index in _assignments.size():
		var card: Dictionary = _assignments[index]
		if int(card["subject"]) != subject or String(card["pose"]) != pose:
			continue
		if stars < _mine[index]:
			continue
		_grab_cards.append(index)
		if stars > _mine[index]:
			_mine[index] = stars
		if stars > _best[index]:
			_best[index] = stars
			_holder[index] = me
			_got[index] = 1
			ToonNet.note_minigame("photo", index * 10 + stars)
		_paint_card(index)


func _recount() -> void:
	var team := 0
	var bonus := 0
	var me := ToonNet.peer_id()
	for index in _best.size():
		team += _best[index]
		if _holder[index] == me:
			bonus += 1
	score = team + bonus
	if _score_label != null:
		_score_label.text = "Team Score: %d\n\nBest Photos: %d\n\nTotal Score: %d" % [team, bonus, score]


func _paint_card(index: int) -> void:
	if index < _card_bonus.size():
		var holder := _holder[index] if index < _holder.size() else -1
		if holder < 0:
			_card_bonus[index].text = ""
		elif holder == ToonNet.peer_id():
			_card_bonus[index].text = "Best Bonus!"
		else:
			_card_bonus[index].text = _name_for_peer(holder)
	var stars := _best[index] if index < _best.size() else 0
	for star in 5:
		var slot := index * 5 + star
		if slot < _card_stars.size():
			_card_stars[slot].visible = star < stars


func _name_for_peer(peer: int) -> String:
	var cards: Array = _RIDE.riders
	for index in cards.size():
		var card: Dictionary = cards[index]
		if int(card.get("peer", -2)) == peer:
			return party_name(index)
	return "Toon"


func _sync_photos() -> void:
	var state := ToonNet.minigame_state()
	var raw: Variant = state.get("photos", {})
	if not (raw is Dictionary):
		return
	var photos: Dictionary = raw
	var changed := false
	for key in photos.keys():
		var slot := int(key)
		if slot < 0 or slot >= _best.size():
			continue
		var row: Variant = photos[key]
		if not (row is Dictionary):
			continue
		var record: Dictionary = row
		var stars := int(record.get("score", 0))
		var by := int(record.get("by", -1))
		if stars > _best[slot] or (stars == _best[slot] and stars > 0 and by != _holder[slot]):
			_best[slot] = stars
			_holder[slot] = by
			_paint_card(slot)
			changed = true
	if changed:
		_recount()


func _ray_hits() -> Dictionary:
	var hits: Dictionary = {}
	var view := get_viewport().get_visible_rect().size
	if view.x < 2.0 or view.y < 2.0:
		return hits
	var mouse := get_viewport().get_mouse_position()
	var aspect := view.x / view.y
	var finder_x := (mouse.x / view.x * 2.0 - 1.0) * aspect
	var finder_z := 1.0 - mouse.y / view.y * 2.0
	var v_half := tan(deg_to_rad(_camera.fov * 0.5))
	var h_half := v_half * aspect
	var origin := _camera.global_position
	var forward := -_camera.global_basis.z
	var right := _camera.global_basis.x
	var up := _camera.global_basis.y
	for row in range(-6, 7):
		for column in range(-6, 7):
			var pos_x := (finder_x + 0.08 * float(row)) / aspect
			var pos_y := finder_z + 0.06 * float(column)
			var dir := (forward + right * (pos_x * h_half) + up * (pos_y * v_half)).normalized()
			var nearest := -1
			var nearest_t := 1000000.0
			for index in _subjects.size():
				var height := _styles[index].avatar_height()
				var radius := height * 0.5
				var center := _subjects[index].global_position + Vector3.UP * radius
				var travel := _ray_sphere(origin, dir, center, radius)
				if travel >= 0.0 and travel < nearest_t:
					nearest_t = travel
					nearest = index
			if nearest < 0:
				continue
			var wall := _wall_distance(origin, dir)
			if wall >= 0.0 and nearest_t >= wall:
				continue
			var marker := _ray_marker(row, column)
			var counts: Dictionary = {"g": 0, "b": 0, "t": 0, "r": 0, "l": 0}
			if hits.has(nearest):
				counts = hits[nearest]
			counts[marker] = int(counts[marker]) + 1
			hits[nearest] = counts
	return hits


func _ray_marker(row: int, column: int) -> String:
	if row >= -4 and row <= 4 and column >= -4 and column <= 4:
		return "g"
	var marker := "l"
	if row > 4:
		marker = "r"
	if column > 4:
		marker = "t"
	if column < -4:
		marker = "b"
	return marker


func _ray_sphere(origin: Vector3, dir: Vector3, center: Vector3, radius: float) -> float:
	var offset := origin - center
	var along := offset.dot(dir)
	var gap := offset.dot(offset) - radius * radius
	var disc := along * along - gap
	if disc < 0.0:
		return -1.0
	var near := -along - sqrt(disc)
	if near >= 0.0:
		return near
	var far := -along + sqrt(disc)
	if far >= 0.0:
		return far
	return -1.0


func _build_capture() -> void:
	_capture_view = SubViewport.new()
	_capture_view.name = "PhotoCapture"
	_capture_view.own_world_3d = false
	_capture_view.transparent_bg = false
	_capture_view.size = Vector2i(256, 192)
	_capture_view.gui_disable_input = true
	_capture_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_capture_view)
	_capture_cam = Camera3D.new()
	_capture_cam.current = true
	_capture_cam.far = 2000.0
	_capture_view.add_child(_capture_cam)


func _arm_capture() -> void:
	if _capture_cam == null or _capture_view == null:
		return
	var view := get_viewport().get_visible_rect().size
	var center := _finder_rect().get_center()
	var dir := _camera.project_ray_normal(center)
	if dir.length_squared() < 0.0001:
		dir = -_camera.global_basis.z
	var half := deg_to_rad(_camera.fov * 0.5)
	var edge := atan((_FINDER_H * 0.5) * tan(half))
	_capture_cam.fov = rad_to_deg(edge * 2.0)
	_capture_cam.global_position = _camera.global_position
	_capture_cam.look_at(_capture_cam.global_position + dir, Vector3.UP)
	_capture_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_grab_wait = 2
	if view.x < 2.0:
		_grab_wait = 2


func _collect_shot() -> void:
	if _grab_wait <= 0:
		return
	_grab_wait -= 1
	if _grab_wait > 0:
		return
	var shot: Texture2D = null
	if _capture_view != null and _capture_view.get_texture() != null:
		var image := _capture_view.get_texture().get_image()
		if image != null:
			image.convert(Image.FORMAT_RGBA8)
			shot = ImageTexture.create_from_image(image)
	if shot != null:
		for index in _grab_cards:
			if index < 0 or index >= _shots.size():
				continue
			_shots[index].texture = shot
			_shots[index].visible = true
			if index < _holes.size():
				_holes[index].visible = false
	_grab_cards.clear()
	if _end_after_shot:
		_end_after_shot = false
		_finish_if_everyone_out()


func _wall_distance(origin: Vector3, dir: Vector3) -> float:
	var world := get_world_3d()
	if world == null:
		return -1.0
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 800.0)
	query.collide_with_areas = false
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return -1.0
	var at: Vector3 = hit["position"]
	return origin.distance_to(at)


func _plant_cannon() -> void:
	var packed := load("res://assets/minigames/toon_cannon.glb") as PackedScene
	if packed == null:
		return
	var rig := packed.instantiate() as Node3D
	if rig == null:
		return
	rig.name = "PhotoTripod"
	add_child(rig)
	rig.position = _tripod
	_cannon_rig = rig
	_swivel = _exact(rig, "cannon")
	_aim_swivel()
	var photographer := ToonActor.new()
	photographer.name = "Photographer"
	add_child(photographer)
	var style := ToonRoster.selected_style()
	if style != null:
		photographer.show_style(style)
	photographer.position = _tripod
	photographer.rotation.y = deg_to_rad(_yaw)
	_toon = photographer


## The cannon and your toon are what the fly-in looks at. Once the camera sits
## in the lens, both go away so the barrel does not fill the picture.
func _mount_camera() -> void:
	if _cannon_rig != null:
		_cannon_rig.visible = false
	if _toon != null:
		_toon.visible = false


func _block_shots(scene: Node3D) -> void:
	var blocker: Node3D = null
	match _hood_id():
		2000:
			blocker = _named(scene, "prop_gazebo")
		1000:
			blocker = _exact(scene, "center_island")
		5000:
			blocker = _exact(scene, "o10_2")
		4000:
			var marks: Array[Node3D] = []
			_collect_named(scene, "landmark", marks)
			if marks.size() > 2:
				blocker = marks[2]
	if blocker != null:
		_solidify(blocker)


func _collect_named(node: Node, piece: String, into: Array[Node3D]) -> void:
	if node is Node3D and String(node.name).to_lower().contains(piece):
		into.append(node as Node3D)
	for child in node.get_children():
		_collect_named(child, piece, into)


func _exact(node: Node, piece: String) -> Node3D:
	if node is Node3D and String(node.name) == piece:
		return node as Node3D
	for child in node.get_children():
		var found := _exact(child, piece)
		if found != null:
			return found
	return null


func _solidify(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.visible and mesh.mesh != null and not _see_through(mesh):
			mesh.create_trimesh_collision()
	for child in node.get_children():
		_solidify(child)


func _see_through(mesh: MeshInstance3D) -> bool:
	var material := mesh.get_active_material(0)
	if material is BaseMaterial3D:
		return (material as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	return false


func _note_film() -> void:
	if _noted_film:
		return
	_noted_film = true
	ToonNet.note_minigame("film", 1)


func _party_ids() -> Array[int]:
	var ids: Array[int] = []
	var cards: Array = _RIDE.riders
	for card in cards:
		if card is Dictionary:
			ids.append(int((card as Dictionary).get("peer", ToonNet.peer_id())))
	if ids.is_empty():
		ids.append(ToonNet.peer_id())
	return ids


func _finish_if_everyone_out() -> void:
	if _over or _film > 0:
		return
	var outs: Array = []
	var raw: Variant = ToonNet.minigame_state().get("film", [])
	if raw is Array:
		outs = raw
	var me := ToonNet.peer_id()
	for id in _party_ids():
		if id == me:
			continue
		var listed := false
		for item in outs:
			if int(item) == id:
				listed = true
				break
		if not listed:
			return
	_end()


func _float_boat(scene: Node3D) -> void:
	# The playground root already turns panda coordinates into Godot ones, so the
	# pivot stays under that root and is posed in panda numbers.
	var boat := _named(scene, "donalds_boat")
	if boat == null or boat.get_parent() == null:
		return
	_boat = Node3D.new()
	_boat.name = "PhotoBoat"
	boat.get_parent().add_child(_boat)
	_boat.position = Vector3(-22.0, 0.0, 1.0)
	boat.reparent(_boat)
	boat.position = Vector3(45.0, -5.0, 0.0)
	boat.rotation = Vector3(0.0, 0.0, deg_to_rad(-8.0))
	var water := _named(scene, "top_surface")
	if water is MeshInstance3D:
		var mesh := water as MeshInstance3D
		var active := mesh.get_active_material(0)
		if active is BaseMaterial3D:
			var copy := (active as BaseMaterial3D).duplicate() as BaseMaterial3D
			copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			copy.albedo_color.a = 0.8
			mesh.set_surface_override_material(0, copy)
	var world := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world != null and world.environment != null:
		var env := world.environment.duplicate() as Environment
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_light_color = Color(0.8, 0.8, 0.8)
		env.fog_depth_begin = 0.0
		env.fog_depth_end = 400.0
		world.environment = env


func _bob_boat(delta: float) -> void:
	if _boat == null:
		return
	_boat_time += delta
	_boat.rotation = Vector3(0.0, 0.0, _boat_time * TAU / 90.0)
	var cycle := fposmod(_boat_time, 10.0) / 5.0
	if cycle > 1.0:
		cycle = 2.0 - cycle
	var eased := cycle * cycle * (3.0 - 2.0 * cycle)
	_boat.position = Vector3(-22.0, 0.0, lerpf(1.0, 2.0, eased))


func _start_snow() -> void:
	# snowdisk.ptf. The disc, radiate, gravity, jitter, spin, fade, and size
	# are the particle file. It is parented to the camera, five units up.
	var flakes := GPUParticles3D.new()
	flakes.name = "PhotoSnow"
	# Birth 0.02 and a life of 4.5 keep 225 flakes in the air. 1024 is only the pool cap.
	flakes.amount = 225
	flakes.lifetime = 4.5
	flakes.preprocess = 4.5
	flakes.explosiveness = 0.0
	flakes.local_coords = true
	flakes.visibility_aabb = AABB(Vector3(-160.0, -160.0, -160.0), Vector3(320.0, 320.0, 320.0))
	flakes.position = Vector3(0.0, 5.0, 0.0)
	var shader := Shader.new()
	shader.code = _SNOW_SHADER
	var process := ShaderMaterial.new()
	process.shader = shader
	flakes.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.albedo_texture = _texture("res://assets/minigames/photo/snowflake.png")
	quad.material = mat
	flakes.draw_pass_1 = quad
	_camera.add_child(flakes)


func _yaw_toward(from: Vector3, to: Vector3) -> float:
	var flat := to - from
	flat.y = 0.0
	if flat.length_squared() < 0.0001:
		return 0.0
	return atan2(-flat.x, -flat.z)


func _load_art() -> void:
	_finder_tex = _texture(_FINDER_PATH)
	_frame_tex = _texture(_FRAME_PATH)
	_camera_tex = _texture(_CAMERA_PATH)
	var palette := _load_image(_PALETTE_PATH)
	if palette != null:
		palette.convert(Image.FORMAT_RGBA8)
		_film_tex = _crop(palette, 0.382813, 0.515625, 0.617188, 0.984375)
		_star_tex = _crop(palette, 0.632813, 0.765625, 0.742188, 0.984375)


func _texture(path: String) -> Texture2D:
	var image := _load_image(path)
	if image == null:
		return null
	image.convert(Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(image)


func _dress(hood: int, area: Dictionary) -> void:
	var kind := "tt"
	if hood == 1000 or hood == 3000:
		kind = "br"
	elif hood == 4000:
		kind = "mm"
	elif hood == 9000:
		kind = "dl"
	_SKY.ensure(self, kind)
	if hood != 5000:
		return
	var root: Vector3 = area["root"]
	_spawn("res://assets/neighborhoods/daisy_gardens/props/DG_flower.glb", root.x, root.y, root.z, 2.5)


func _load_image(path: String) -> Image:
	var image := Image.load_from_file(path)
	if image != null:
		return image
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func _crop(image: Image, u0: float, v0: float, u1: float, v1: float) -> Texture2D:
	var width := image.get_width()
	var height := image.get_height()
	var x := clampi(int(round(u0 * float(width))), 0, width - 1)
	var y := clampi(int(round((1.0 - v1) * float(height))), 0, height - 1)
	var rw := clampi(int(round((u1 - u0) * float(width))), 1, width - x)
	var rh := clampi(int(round((v1 - v0) * float(height))), 1, height - y)
	var piece := Image.create(rw, rh, false, Image.FORMAT_RGBA8)
	piece.blit_rect(image, Rect2i(x, y, rw, rh), Vector2i.ZERO)
	return ImageTexture.create_from_image(piece)


func _build_hud() -> void:
	var layer := _hud.get_parent()
	_hud.visible = false
	_hud_root = Control.new()
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.visible = false
	layer.add_child(_hud_root)
	_blackout = ColorRect.new()
	_blackout.color = Color(0, 0, 0, 0)
	_blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.add_child(_blackout)
	_finder = _picture(_finder_tex)
	_hud_root.add_child(_finder)
	_film_icon = _picture(_film_tex)
	_hud_root.add_child(_film_icon)
	_film_label = Label.new()
	_film_label.text = str(_film)
	_film_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_film_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_film_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_film_label)
	_film_word = Label.new()
	_film_word.text = "FILM"
	_film_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_film_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_film_word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_film_word)
	_score_frame = _picture(_camera_tex)
	_hud_root.add_child(_score_frame)
	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_score_label)
	for index in _assignments.size():
		var card := _assignments[index] as Dictionary
		var panel := _picture(_frame_tex)
		_tilts.append(_TILTS[shared_int(_TILTS.size())])
		_hud_root.add_child(panel)
		_cards.append(panel)
		var hole := _picture(null)
		hole.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hole.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		panel.add_child(hole)
		_holes.append(hole)
		var shot := _picture(null)
		shot.visible = false
		shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		panel.add_child(shot)
		_shots.append(shot)
		var bonus := Label.new()
		bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bonus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bonus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(bonus)
		_card_bonus.append(bonus)
		for _star in 5:
			var star := _picture(_star_tex)
			star.visible = false
			panel.add_child(star)
			_card_stars.append(star)
		_portraits.append(_portrait(int(card["subject"]), String(card["pose"]), hole))
	_layout()


func _picture(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _portrait(subject: int, pose: String, hole: TextureRect) -> ToonActor:
	var port := SubViewport.new()
	port.transparent_bg = true
	port.own_world_3d = true
	port.size = Vector2i(160, 120)
	port.gui_disable_input = true
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_hud_root.add_child(port)
	var stage := Node3D.new()
	port.add_child(stage)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.15
	world.environment = env
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.2
	key.rotation_degrees = Vector3(-35.0, 20.0, 0.0)
	stage.add_child(key)
	var actor := ToonActor.new()
	stage.add_child(actor)
	if subject >= 0 and subject < _styles.size():
		actor.show_style(_mirror_style(_styles[subject]))
	var body := 1.0
	if subject >= 0 and subject < _styles.size():
		body = maxf(_styles[subject].body_scale(), 0.6)
	actor.rotation.y = deg_to_rad(172.0)
	actor.set_meta("card", true)
	if pose == "swim":
		actor.position.y = -0.35 * body
	var camera := Camera3D.new()
	camera.fov = 32.0
	camera.current = true
	camera.position = Vector3(0.0, 2.15 * body, 3.6 * body)
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 1.85 * body, 0.0), Vector3.UP)
	_drive(actor, pose, true, 0.0)
	hole.texture = port.get_texture()
	return actor


func _mirror_style(style: ToonStyle) -> ToonStyle:
	var copy := ToonStyle.new()
	copy.gender = style.gender
	copy.head = style.head
	copy.torso = style.torso
	copy.legs = style.legs
	copy.head_color = style.head_color
	copy.arm_color = style.arm_color
	copy.leg_color = style.leg_color
	copy.glove_color = style.glove_color
	copy.top_tex = style.top_tex
	copy.top_color = style.top_color
	copy.bot_tex = style.bot_tex
	copy.bot_color = style.bot_color
	return copy


func _layout() -> void:
	if _hud_root == null:
		return
	var view := get_viewport().get_visible_rect().size
	if view.x < 2.0 or view.y < 2.0:
		return
	var screen := Vector2(view.x / maxf(view.y, 1.0), 1.0)
	var scale := screen.x / float(_ASSIGNMENTS)
	var card_w := 1.6 * scale
	var card_h := 1.75 * scale
	var spacing := scale * 1.61
	var x_off := screen.x - 0.735
	var yellow := Color(0.95, 0.95, 0, 1)
	_GUI.style_label(_film_label, yellow, _font_px(0.2 * 0.65), Color(0, 0, 0), _font_px(0.02))
	_GUI.style_label(_film_word, yellow, _font_px(0.08 * 0.65), Color(0, 0, 0), _font_px(0.012))
	_GUI.style_label(_score_label, Color(0, 0, 0), _font_px(0.05), Color(0, 0, 0, 0), 0)
	var film := _aspect_rect(1.16, 0.45, 0.5 * 0.65, 0.666 * 0.85 * 0.65)
	_film_icon.position = film.position
	_film_icon.size = film.size
	_film_icon.pivot_offset = film.size * 0.5
	var count_at := _aspect_rect(1.16 + 0.08 * 0.65, 0.45 - 0.15 * 0.65, 0.28, 0.16)
	_film_label.position = count_at.position
	_film_label.size = count_at.size
	var word_at := _aspect_rect(1.16 + 0.08 * 0.65, 0.45 + 0.04 * 0.65, 0.28, 0.08)
	_film_word.position = word_at.position
	_film_word.size = word_at.size
	var score_at := _aspect_rect(1.05, -0.725, 0.64, 0.64)
	_score_frame.position = score_at.position
	_score_frame.size = score_at.size
	var well := _aspect_rect(1.05, -0.78, 0.36, 0.28)
	_score_label.position = well.position
	_score_label.size = well.size
	for index in _cards.size():
		var center_x := x_off - spacing * float(index)
		var panel_at := _aspect_rect(center_x, -0.75, card_w, card_h)
		var panel := _cards[index]
		panel.position = panel_at.position
		panel.size = panel_at.size
		panel.pivot_offset = panel_at.size * 0.5
		panel.rotation_degrees = _tilts[index] if index < _tilts.size() else 0.0
		var hole_at := Rect2(panel.size * _HOLE.position, panel.size * _HOLE.size)
		_holes[index].position = hole_at.position
		_holes[index].size = hole_at.size
		_shots[index].position = hole_at.position
		_shots[index].size = hole_at.size
		var shown := _best[index] if index < _best.size() else 0
		var shift := float(5 - shown) * 0.03
		for star in 5:
			var mark := _card_stars[index * 5 + star]
			var star_x := -0.15 + float(star + 0.5) * 0.06 + shift
			var local := Vector2((star_x / card_w + 0.5) * panel.size.x, (0.5 - (-0.11) / card_h) * panel.size.y)
			var star_px := Vector2(0.06 / card_w * panel.size.x, 0.06 / card_h * panel.size.y)
			mark.position = local - star_px * 0.5
			mark.size = star_px
		_GUI.style_label(_card_bonus[index], Color(0.1, 0.1, 0.1), _font_px(0.045), Color(0, 0, 0, 0), 0)
		_card_bonus[index].position = Vector2(panel.size.x * 0.08, panel.size.y * 0.78)
		_card_bonus[index].size = Vector2(panel.size.x * 0.84, panel.size.y * 0.22)
	_aim_finder()


func _veil(delta: float) -> void:
	if _blackout == null:
		return
	var target := 0.5 if _zoomed else 0.0
	var alpha := move_toward(_blackout.color.a, target, delta / _ZOOM_TIME)
	_blackout.color = Color(0, 0, 0, alpha)


func _throb(delta: float) -> void:
	if _film_icon == null:
		return
	var amount := 1.0
	if _film_pulse > 0.0:
		_film_pulse = maxf(_film_pulse - delta, 0.0)
		var t := 1.0 - _film_pulse / 0.3
		if t < 0.5:
			amount = lerpf(1.0, 0.75, t / 0.5)
		else:
			amount = lerpf(0.75, 1.0, (t - 0.5) / 0.5)
	_film_icon.scale = Vector2(amount, amount)


func _aim_finder() -> void:
	if _finder == null:
		return
	var rect := _finder_rect()
	_finder.position = rect.position
	_finder.size = rect.size


func _finder_rect() -> Rect2:
	var view := get_viewport().get_visible_rect().size
	var unit := view.y * 0.5
	var size := Vector2(_FINDER_W * unit, _FINDER_H * unit)
	var mouse := get_viewport().get_mouse_position()
	return Rect2(mouse - size * 0.5, size)


func _area(hood: int) -> Dictionary:
	match hood:
		1000:
			return _pack(28, 110.0, 218.211, -6.7879, Vector3(-22, 0, 0), Vector3(0, -4, 9), false, 1000, _dock_paths(), [0, 0, 1, 2, 3], _dock_anims(), _dock_moves())
		3000:
			return _pack(21, 90.0, -49.401, -11.6266, Vector3(-110, -48, 8.567), Vector3(0, 0, 6), false, 3000, _brrrgh_paths(), [0, 0, 1, 2], _brrrgh_anims(), _brrrgh_moves())
		4000:
			return _pack(23, 95.0, 71.3028, -3.12932, Vector3(103.6, -61, -4.497), Vector3(0, 0, 6), false, 4000, _melody_paths(), [0, 0, 1, 2], _melody_anims(), _melody_moves())
		5000:
			return _pack(26, 100.0, 0.0, 0.0, Vector3(1.39, 92.91, 2.0), Vector3(0, 0, 6), false, 5000, _garden_paths(), [0, 0, 1, 2], _garden_anims(), _garden_moves())
		9000:
			return _pack(18, 85.0, -137.183, -9.06236, Vector3(-70.228, 87.588, 4.397), Vector3(0, 0, 6), false, 9000, _dream_paths(), [0, 0, 1, 2], _dream_anims(), _dream_moves())
		_:
			return _pack(32, 120.0, -87.8752, -0.378549, Vector3.ZERO, Vector3(0, 0, 7), true, 2000, _central_paths(), [0, 0, 1, 2], _central_anims(), _central_moves())


func _pack(film: int, time: float, heading: float, pitch: float, root: Vector3, offset: Vector3, gazebo: bool, hood: int, paths: Array, rel: Array, anims: Array, moves: Array) -> Dictionary:
	return {
		"film": film,
		"time": time,
		"heading": heading,
		"pitch": pitch,
		"root": root,
		"offset": offset,
		"gazebo": gazebo,
		"scene": String(_SCENES[hood]),
		"paths": paths,
		"rel": rel,
		"anims": anims,
		"moves": moves,
	}


func _points(raw: Array) -> Array:
	var out: Array = []
	for item in raw:
		var row: Array = item
		out.append(Vector3(float(row[0]), float(row[1]), float(row[2])))
	return out


func _central_paths() -> Array:
	return [
		_points([[10, 20, 4.025], [10, -3, 4.025], [32, -5, 4.025], [32, 12, 4.025]]),
		_points([[-58.396, -51.972, -1.386], [-59.967, -66.906, 0.025], [-56.416, -77.651, 0.025], [-26.619, -74.156, 0.025], [-10.664, -73.82, 0.025], [5.421, -81.282, 2.525], [5.421, -57.383, 0.025], [-27.497, -34.525, 0.025], [-41.784, -48.023, 0.025]]),
		_points([[-29.015, 36.498, 0.028], [-45.701, 42.963, -0.904], [-54.659, 65.987, 0.025], [-45.458, 81.478, 0.025], [-17.325, 83.591, 0.525], [4.169, 69.942, 1.133], [-10.625, 38.357, 0.036]]),
		_points([[-84.761, -74.52, 0.034], [-101.685, -75.619, 0.525], [-113.606, -71.806, 0.525], [-111.463, -63.672, 0.525], [-102.072, -60.867, 0.525], [-94.049, -60.519, 0.035], [-66.868, -64.715, 0.025]]),
	]


func _central_anims() -> Array:
	return [["wave", "", ""], ["slip-forward", "", ""], ["shrug", ""]]


func _central_moves() -> Array:
	return [[["walk", 1.0], ["run", 0.4]], [["run", 0.4]], [["walk", 1.0], ["sad-walk", 2.5]]]


func _dock_paths() -> Array:
	return [
		_points([[-115.6, 39.4, 5.692], [-109.9, -14, 5.692], [-112.652, -46.7, 5.692], [-68.9, -74.7, 5.692], [-0.2, -82.0, 5.692], [-73.5, -72.2, 5.692], [-112.0, -45, 5.692], [-110.3, 17.5, 5.692]]),
		_points([[-67.143, 131.117, 3.28], [-56.4, 101.4, 3.279], [-51.425, 80.1, 3.279], [-87.632, 56.718, 2.392], [-114.1, 54.7, 3.28], [-108.5, 80.5, 3.281], [-82.672, 68.971, 3.28], [-83.122, 101.9, 3.28]]),
		_points([[11.456, -82.521, 3.28], [49.735, -70.46, 3.28], [60.666, -42.735, 3.28], [40.81, -76.633, 3.28]]),
		_points([[68.924, -33.681, 5.692], [60.51, -31.574, 5.692], [58.672, 12.253, 5.692], [69.809, 48.261, 5.692], [57.857, 46.134, 5.692], [66.057, -22.476, 5.692]]),
		_points([[-24.439, 37.429, 0.2], [-3.549, 19.343, 0.2], [3.218, -1.475, 0.2], [-12.292, -25.318, 0.2], [-42.954, -25.706, 0.2], [-55.102, 4.041, 0.2], [-54.247, 16.051, 0.2]]),
	]


func _dock_anims() -> Array:
	return [["wave", ""], ["slip-forward", "", ""], ["shrug", ""], [""]]


func _dock_moves() -> Array:
	return [[["walk", 1.0]], [["run", 0.4]], [["walk", 1.0], ["sad-walk", 2.5]], [["swim", 1.0]]]


func _garden_paths() -> Array:
	return [
		_points([[-37.252, 25.513, 0.025], [-30.032, 37.9, 0.025], [-38.694, 50.631, 0.025], [-52.1, 52.926, 0.025], [-62.807, 43.957, 0.025]]),
		_points([[36.214, 117.447, 5.0], [3.534, 137.083, 5.0], [-9.384, 136.973, 5.0], [-26.377, 120.564, 5.0], [-43.268, 122.335, 5.0], [-26.377, 120.564, 5.0], [-9.384, 136.973, 5.0], [3.534, 137.083, 5.0]]),
		_points([[15.675, 111.21, 0.025], [21.261, 119.429, 0.025], [6.201, 129.047, 0.025], [-10.984, 124.684, 0.025], [4.039, 130.275, 0.025], [22.645, 118.204, 0.025]]),
		_points([[27.348, 16.836, 0.025], [47.152, 18.038, 0.025], [65.325, 22.322, 0.025], [73.063, 43.545, 0.025], [75.228, 66.869, 0.025], [69.468, 23.798, 0.025], [46.43, 20.473, 0.025]]),
	]


func _garden_anims() -> Array:
	return [["wave", ""], ["jump", "", ""], ["bow", "happy-dance", ""]]


func _garden_moves() -> Array:
	return [[["walk", 1.0], ["run", 0.4]], [["run", 0.4]], [["walk", 1.0], ["run", 0.4]]]


func _melody_paths() -> Array:
	return [
		_points([[-42.35, -16.0, -12.476], [-23.7, -49.0, -12.476], [12.4, -62.1, -12.476], [37.8, -31.163, -12.476], [29.5, 8.9, -12.476], [-11.1, 19.6, -12.476], [-34.4, -3.4, -12.476]]),
		_points([[133.976, -67.686, -6.618], [126.749, -47.351, 0.404], [130.493, -33.429, 4.534], [126.239, -15.853, 5.25], [129.774, -0.535, 3.114], [130.83, 25.08, -5.688], [128.077, -5.33, 4.291], [128.399, -23.142, 5.457], [129.239, -39.886, 2.914], [133.063, -78.315, -10.756]]),
		_points([[50.757, -102.705, 6.725], [-23.276, -108.546, 6.725], [-57.283, -72.081, 6.725], [-21.699, -109.808, 6.725], [19.614, -108.591, 6.725]]),
		_points([[51.761, -36.129, -14.627], [26.374, -73.664, -14.645], [14.322, -89.378, -14.562], [61.594, -91.931, -14.524]]),
	]


func _melody_anims() -> Array:
	return [["wave", ""], ["jump", "slip-forward", "", ""], ["shrug", "confused", ""]]


func _melody_moves() -> Array:
	return [[["walk", 1.0], ["run", 0.4]], [["run", 0.4]], [["walk", 1.0], ["sad-walk", 2.5]]]


func _brrrgh_paths() -> Array:
	return [
		_points([[-82.52, -28.727, 3.009], [-77.642, -4.616, 3.009], [-51.006, 1.05, 3.009], [-28.618, -28.449, 4.026], [-37.948, -64.705, 4.714]]),
		_points([[-74.672, 62.15, 6.192], [-92.602, 38.734, 6.192], [-126.887, 34.757, 6.192], [-138.12, 56.002, 6.192], [-113.968, 32.661, 6.192], [-84.717, 46.837, 6.192]]),
		_points([[-55.239, -126.921, 6.192], [-20.35, -108.696, 6.192], [5.028, -61.737, 6.192], [27.967, -19.683, 6.192], [11.487, 2.913, 6.192], [-23.727, -47.344, 6.192]]),
		_points([[-143.22, -104.727, 6.192], [-152.989, -64.372, 6.192], [-139.328, -6.628, 4.018], [-135.815, -39.935, 3.009]]),
	]


func _brrrgh_anims() -> Array:
	return [["wave", ""], ["applause", "slip-forward", "", ""], ["shrug", "confused", "angry", ""]]


func _brrrgh_moves() -> Array:
	return [[["walk", 1.0], ["running-jump", 0.4]], [["run", 0.4]], [["walk", 1.0], ["sad-walk", 2.5]]]


func _dream_paths() -> Array:
	return [
		_points([[-51.222, 90.874, 0.025], [0.715, 94.789, 0.025], [30.715, 94.0, 0.025], [69.181, 93.45, 0.025], [30.715, 94.0, 0.025], [-8.696, 91.799, 0.025]]),
		_points([[-70.403, 29.575, 2.125], [-68.829, -21.076, 2.125], [-104.669, -24.758, 2.125], [-114.801, 21.777, 2.125]]),
		_points([[15.923, -41.824, -16.089], [18.217, 34.322, -14.732], [7.087, 61.964, -16.058], [50.447, 8.17, -13.975], [-15.793, -19.916, -14.041], [-26.41, 26.786, -14.371], [20.853, 1.639, -13.975]]),
		_points([[-35.391, -24.112, -14.241], [-54.364, -12.996, -13.975], [-51.578, 21.964, -14.139], [-10.49, 15.537, -13.974], [-25.728, -14.665, -13.975], [-43.923, -32.324, -14.634]]),
	]


func _dream_anims() -> Array:
	return [["wave", ""], ["applause", "jump", "slip-forward", "", ""], ["shrug", "angry", ""]]


func _dream_moves() -> Array:
	return [[["walk", 1.0], ["catch-run", 0.4]], [["run", 0.4], ["running-jump", 0.4]], [["walk", 1.0], ["sad-walk", 2.5]]]
