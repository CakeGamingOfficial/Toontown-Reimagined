class_name ToonActor
extends Node3D

signal shticker_opened

## Legs, torso, and head posed in neutral and assembled the way
## Toon.parentToonParts does: torso on joint_hips, head on def_head.
## Toon.setLODs keeps three copies. 1000 shows inside 20 feet, 500 until 80,
## and 250 until 280. Farther than that, the body is not drawn.
## The parts are still Z-up, so this node stands them up.

const _PARTS := "res://assets/toons/parts/"
const _HEADS := "res://assets/toons/heads/"
const _ANIMS := "res://assets/toons/anims/"
const _SHIRT := [
	preload("res://assets/toons/clothes/desat_shirt_1.png"),
	preload("res://assets/toons/clothes/desat_shirt_2.png"),
	preload("res://assets/toons/clothes/desat_shirt_3.png"),
]
const _SLEEVE := [
	preload("res://assets/toons/clothes/desat_sleeve_1.png"),
	preload("res://assets/toons/clothes/desat_sleeve_2.png"),
	preload("res://assets/toons/clothes/desat_sleeve_3.png"),
]
const _SHORTS := [
	preload("res://assets/toons/clothes/desat_shorts_1.png"),
	preload("res://assets/toons/clothes/desat_shorts_2.png"),
	preload("res://assets/toons/clothes/desat_shorts_4.png"),
]
const _SKIRT := preload("res://assets/toons/clothes/desat_skirt_1.png")
const _BODY_SHADER := preload("res://scenes/toons/toon_body.gdshader")
const _FACE_SHADER := preload("res://scenes/toons/toon_face.gdshader")
const _BODY_GHOST := preload("res://scenes/toons/toon_body_ghost.gdshader")
const _FACE_GHOST := preload("res://scenes/toons/toon_face_ghost.gdshader")
## Layer 20. The player's camera still sees it. A remote camera, once
## multiplayer adds one, leaves this bit out of its cull mask.
const LOCAL_GHOST_LAYER := 1 << 19
const _GHOST_ALPHA := 0.4

## World NPCs fall onto collision the way the player does. The player's own
## toon stays off, because his CharacterBody already carries him.
var follows_ground := false
## True while ~ghost is on. Other clients hide this toon. The local one fades.
var ghost_mode := false
## LocalToon.soundWalk and soundRun. Only the toon you are playing hears them.
var footsteps := false
var _step_mode := ""
var _walk_steps: AudioStreamPlayer
var _run_steps: AudioStreamPlayer
var _ghost_local := false
var _saved_layers: Dictionary = {}
## Make a Toon only plays neutral. The run, jump, and gag clips are large, and
## reading them again on every option change freezes that idle.
var load_extra_clips := true
## A 60Hz tick moves the 24fps clip by 0.4 of a frame. Five cached poses land
## on those ticks, so the cycle does not pop and the mesh is not rebuilt to draw.
const _POSE_STEPS := 5
var _ground := Grounded.new()

var _style: ToonStyle
var _walk_clips: Array = []
var _walk_joints: Array = []
var _walk_loaded := false
var _walk_missing := false
var _idle_clips: Array = []
var _idle_joints: Array = []
var _idle_loaded := false
var _idle_missing := false
var _posing := false
var _pose_lock := false
var _sad := false
var _clip := ""
var _jump_kind := ""
var _land_kind := ""
var _land_left := 0.0
var _cycle_time := {"walk": 0.0, "run": 0.0, "jump": 0.0, "rjump": 0.0, "land": 0.0, "rland": 0.0}
var _extra := {}
var _accessory_ids := {}
var _shoe_mesh := ""
var _shoe_shown := ""
static var _accessory_book: Dictionary = {}
var _idle_time := 0.0
var _frame_count := 0
var _idle_frames := 0
var _look: Node3D
var _pupils: Array = []
var _eyes: Array = []
var _lashes: Array[MeshInstance3D] = []
var _eyes_closed: Texture2D
var _eyes_shut := false
var _blink_left := 0.0
var _blink_started_msec := 0
var _blink_wait := 1.0
var _look_wait := 2.0
var _look_enabled := true
var _gesture := ""
var _gesture_rate := 1.0
var _gesture_loop := true
## Place.enterStickerBook plays openBook, then readBook, then closeBook.
const _BOOK_MODEL := "res://assets/props/shticker_book.glb"
const _BOOK_CLIP := "res://assets/toons/anims/shticker_book.book"
var _book_phase := ""
var _book_clock := 0.0
var _book_hold := 0.0
var _book_prop: Node3D
var _book_joints: Array = []
var _parcel: MeshInstance3D
var _swimming := false
var _mood := "normal"
var _mood_open: Texture2D
var _mood_closed: Texture2D
var _looking := false
var _look_time := 0.0
var _heading := 0.0
var _pitch := 0.0
var _heading_from := 0.0
var _pitch_from := 0.0
var _heading_to := 0.0
var _pitch_to := 0.0
var _left_target := Vector3.ZERO
var _right_target := Vector3.ZERO
var _locomotion_msec := -10000
var _head_idle_clips: Array = []
var _head_idle_frames := 0
var _head_idle_time := 0.0
var _head_idle_missing := false
var _head_idle_started := false
## Toon.setLODs defaults: lod1-in 20, lod2-in 80, lod3-in 280.
const _LOD_500 := 20.0
const _LOD_250 := 80.0
const _LOD_OUT := 280.0
## Measured in this node's local space, the same space as the scaled geom
## the original LODNode sits under.
var _shown := 1000
var _lod_roots := {}
var _far_clips := {}
var _looks: Array[Node3D] = []
const _LEFT_A := Vector3(0.06, 0.0, 0.14)
const _LEFT_B := Vector3(-0.13, 0.0, 0.1)
const _LEFT_C := Vector3(-0.05, 0.0, 0.0)
const _LEFT_D := Vector3(0.06, 0.0, 0.0)
const _LEFT_AD := Vector3(0.06, 0.0, 0.0)
const _LEFT_BC := Vector3(-0.05, 0.0, 0.0)
const _RIGHT_A := Vector3(0.13, 0.0, 0.1)
const _RIGHT_B := Vector3(-0.06, 0.0, 0.14)
const _RIGHT_C := Vector3(-0.06, 0.0, 0.0)
const _RIGHT_D := Vector3(0.05, 0.0, 0.0)
const _RIGHT_AD := Vector3(0.05, 0.0, 0.0)
const _RIGHT_BC := Vector3(-0.06, 0.0, 0.0)


func show_style(style: ToonStyle) -> void:
	_style = style
	_walk_clips.clear()
	_walk_joints.clear()
	_walk_loaded = false
	_walk_missing = false
	_idle_clips.clear()
	_idle_joints.clear()
	_idle_loaded = false
	_idle_missing = false
	_posing = false
	_pose_lock = false
	_clip = ""
	_jump_kind = ""
	_land_kind = ""
	_land_left = 0.0
	_cycle_time = {"walk": 0.0, "run": 0.0, "jump": 0.0, "rjump": 0.0, "land": 0.0, "rland": 0.0}
	_extra = {}
	_gesture = ""
	_book_phase = ""
	_book_prop = null
	_book_joints.clear()
	_swimming = false
	_mood = "normal"
	_mood_open = null
	_mood_closed = null
	_look_enabled = true
	_idle_time = 0.0
	_frame_count = 0
	_idle_frames = 0
	_look = null
	_looks.clear()
	_shown = 1000
	_lod_roots.clear()
	_far_clips.clear()
	_pupils.clear()
	_eyes.clear()
	_lashes.clear()
	_eyes_shut = false
	_blink_left = 0.0
	_looking = false
	_look_time = 0.0
	_heading = 0.0
	_pitch = 0.0
	_left_target = Vector3.ZERO
	_right_target = Vector3.ZERO
	_head_idle_clips.clear()
	_head_idle_frames = 0
	_head_idle_time = 0.0
	_head_idle_missing = false
	_head_idle_started = false
	for child in get_children():
		child.free()
	if style == null:
		return
	# Panda is Z-up. This basis makes a local (x, y, z) into Godot (x, z, -y),
	# then turns the toon around to face the Make a Toon camera.
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	upright = upright.rotated(Vector3.UP, PI)
	transform.basis = upright.scaled(Vector3.ONE * style.body_scale())
	var body := _build_lod(1000)
	if body == null:
		return
	add_child(body)
	_lod_roots[1000] = body
	_paint(body, style)
	_unify_forehead(body)
	_prepare_face()
	_add_shadow(body)
	_dress_all()


## One LOD, parented the same way as the 1000 body. Missing parts mean this
## distance keeps the 1000 model.
func _build_lod(lod: int) -> Node3D:
	var leg_file := "legs_%s" % _style.legs
	var torso_file := "torso_%s" % _style.torso
	var head_file := _style.head
	if lod != 1000:
		leg_file = "%s_%d" % [leg_file, lod]
		torso_file = "%s_%d" % [torso_file, lod]
		head_file = "%s_%d" % [head_file, lod]
	var legs := _instance(_PARTS + leg_file + ".glb")
	if legs == null:
		return null
	var hips := _find(legs, "joint_hips")
	var torso := _instance(_PARTS + torso_file + ".glb")
	var neck: Node3D = _find(torso, "def_head") if torso else null
	var head := _instance(_HEADS + head_file + ".glb")
	if hips == null or torso == null or neck == null or head == null:
		legs.free()
		if torso:
			torso.free()
		if head:
			head.free()
		return null
	var root := Node3D.new()
	root.name = str(lod)
	root.add_child(legs)
		hips.add_child(torso)
	var look := Node3D.new()
	look.name = "head_look"
	neck.add_child(look)
	look.add_child(head)
	if _look == null:
		_look = look
	elif _look:
		look.basis = _look.basis
	_looks.append(look)
	return root


func _wanted_lod() -> int:
	# Make a Toon and the portrait force the 1000 model, the way useLOD(1000) does.
	if not load_extra_clips or not is_inside_tree():
		return 1000
	var viewport := get_viewport()
	if viewport == null:
		return 1000
	var camera := viewport.get_camera_3d()
	if camera == null:
		return 1000
	var dist := (global_transform.affine_inverse() * camera.global_position).length()
	if dist >= _LOD_OUT:
		return 0
	if dist >= _LOD_250:
		return 250
	if dist >= _LOD_500:
		return 500
	return 1000


func _ensure_lod(lod: int) -> bool:
	if _lod_roots.has(lod):
		return _lod_roots[lod] is Node3D
	if not is_inside_tree():
		return false
	var body := _build_lod(lod)
	if body == null:
		_lod_roots[lod] = null
		return false
	add_child(body)
	body.visible = false
	_paint(body, _style)
	_unify_forehead(body)
	_collect_face(body)
	_add_shadow(body)
	_dress_body(body)
	for suffix in ["walk", "idle", "run", "sad-neutral", "sad-walk", "jump", "rjump", "land", "rland"]:
		var clips: Array = []
		var joints: Array = []
		var frames := _load_clip(suffix, clips, joints, body, lod)
		_far_clips["%d:%s" % [lod, suffix]] = {"clips": clips, "joints": joints, "frames": frames}
	if _style.species() == "d":
		var ear_clips: Array = []
		var ear_frames := _ingest(_read_walk(_ANIMS + "%s_%d.idle" % [_style.head, lod]), ear_clips, [], body)
		_far_clips["%d:head-idle" % lod] = {"clips": ear_clips, "joints": [], "frames": ear_frames}
	if _ghost_local:
		_ghost_visuals(body, true)
	_lod_roots[lod] = body
	return true


func _show_body(lod: int) -> void:
	if lod == _shown:
		return
	_shown = lod
	for key in _lod_roots.keys():
		var node := _lod_roots[key] as Node3D
		if node:
			node.visible = int(key) == lod


## The clip that should be drawn right now. An empty result means the body is
## past 280 feet and nothing is posed.
func _pose_target(suffix: String, clips: Array, joints: Array) -> Dictionary:
	var want := _wanted_lod()
	if want == 0:
		_show_body(0)
		return {}
	if want != 1000 and _ensure_lod(want):
		var bank: Dictionary = _far_clips.get("%d:%s" % [want, suffix], {})
		var far_clips: Array = bank.get("clips", [])
		if int(bank.get("frames", 0)) > 0 and not far_clips.is_empty():
			_show_body(want)
			return bank
	_show_body(1000)
	return {"clips": clips, "joints": joints}


func species() -> String:
	if _style == null:
		return ""
	return _style.species()


## DeliverItemQuest puts the package in the right hand until it is handed over.
func hold_parcel(carry: bool) -> void:
	if not carry:
		if _parcel != null and is_instance_valid(_parcel):
			_parcel.visible = false
		return
	if _parcel != null and is_instance_valid(_parcel) and _parcel.visible and _parcel.get_parent() != null:
		return
	var hand := find_child("def_joint_right_hold", true, false) as Node3D
	if hand == null:
			return
	if _parcel == null or not is_instance_valid(_parcel):
		var mesh := MeshInstance3D.new()
		mesh.name = "Parcel"
		var box := BoxMesh.new()
		box.size = Vector3(0.42, 0.32, 0.36)
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		var picture := load("res://assets/gui/tutorial/book/package.png") as Texture2D
		if picture != null:
			mat.albedo_texture = picture
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mesh.material_override = mat
		_parcel = mesh
	if _parcel.get_parent() != hand:
		hand.add_child(_parcel)
	_parcel.position = Vector3(0.0, 0.12, 0.08)
	_parcel.visible = true


func carrying_parcel() -> bool:
	return _parcel != null and is_instance_valid(_parcel) and _parcel.visible


## LocalAvatar.getClampedAvatarHeight. Toons shorter than 3 share that camera.
func clamped_height() -> float:
	if _style == null:
		return 3.0
	return maxf(_style.avatar_height(), 3.0)


## A new head, torso, or legs. The idle clock keeps going, so the toon does not
## snap back to the first frame of neutral while the new parts come in.
func swap_style(style: ToonStyle) -> void:
	var clock := _idle_time
	var playing := _clip == "idle" and _idle_frames > 0
	show_style(style)
	if playing:
		_clip = "idle"
		_idle_time = clock
	set_locomotion(0.0, false, false, 0.0)


## Standing still loops neutral. Moving forward loops run. Backing up loops the
## walk cycle backward. Turning in place keeps that walk playing forward.
## A jump from a stand loops jump-idle. A jump while running loops running-jump-idle.
## Landing faster than 30 plays jump-land, or running-jump-land after the running hop.
## Clips load the first time this toon is asked to animate, so Pick a Toon never
## has to instance a blend-shape mesh.
const _WALK_SPEED := 0.5
## Toon.setSpeed: forward at RunCutOff plays the run loop. Walking, backing
## up, and turning in place play the walk loop.
const _RUN_CUTOFF := 8.0
const _WALK_STEPS := "res://assets/audio/sfx/AV_footstep_walkloop.mp3"
const _RUN_STEPS := "res://assets/audio/sfx/AV_footstep_runloop.mp3"


## DistributedBank walks the last few steps with the walk cycle, not the run.
func play_walk(delta: float) -> void:
	if _style == null:
		return
	_locomotion_msec = Time.get_ticks_msec()
	_ensure_clips()
	_play_cycle("walk", _walk_clips, _walk_joints, _frame_count, 1.0, delta)


## DistributedBattle.__faceOff loops run while the toon moves onto the battle cell.
func play_run(delta: float) -> void:
	if _style == null:
		return
	_locomotion_msec = Time.get_ticks_msec()
	_ensure_clips()
	if _play_bank("run", 1.0, delta):
		return
	_play_cycle("walk", _walk_clips, _walk_joints, _frame_count, 1.0, delta)


func set_sad(sad: bool) -> void:
	_sad = sad
	set_expression("sad" if sad else "normal")


func is_sad() -> bool:
	return _sad


func set_locomotion(forward_speed: float, turning: bool, jumping: bool, delta: float) -> void:
	if _style == null:
		return
	# The face tick plays dog ears on its own unless locomotion just posed them.
	_locomotion_msec = Time.get_ticks_msec()
	if _pose_lock:
		return
	_ensure_clips()
	# The shticker book owns the pose until the close clip finishes.
	# The clip itself advances in _process, so a cutscene that skips
	# locomotion still lets the book open.
	if _book_phase != "":
		_look_enabled = false
		_footsteps(0.0, false)
		return
	# enterSwim loops swim and pitches the geom. Walking and jumping stay off
	# until the toon is back above the water.
	if _swimming:
		_look_enabled = false
		if _gesture != "swim":
			play_gesture("swim", 1.0, true)
		_play_bank("swim", 1.0, delta, true)
		_footsteps(0.0, false)
		return
	if _sad:
		set_expression("sad")
		_footsteps(forward_speed, turning)
		var moving := absf(forward_speed) > _WALK_SPEED or turning
		if moving and _play_bank("sad-walk", 1.2 if forward_speed >= 0.0 else -1.0, delta):
			return
		if not moving and _play_bank("sad-neutral", 1.0, delta):
			return
		jumping = false
	_look_enabled = _gesture == ""
	if _gesture != "":
		_play_bank(_gesture, _gesture_rate, delta, _gesture_loop)
		_footsteps(0.0, false)
		return
	_footsteps(forward_speed, turning)
	if jumping:
		_land_left = 0.0
		if _jump_kind == "":
			# Standing still uses the standing hop. Moving forward uses the running hop.
			var running := forward_speed > _WALK_SPEED or _clip == "run"
			_jump_kind = "rjump" if running else "jump"
		if _play_bank(_jump_kind, 1.0, delta):
			return
	elif _land_left > 0.0:
		_land_left = maxf(_land_left - delta, 0.0)
		if _land_left > 0.0 and _play_bank(_land_kind, 1.0, delta, false):
			return
		_land_left = 0.0
		_land_kind = ""
	else:
		_jump_kind = ""
	if forward_speed > _WALK_SPEED:
		if _play_bank("run", 1.0, delta):
			return
		_play_cycle("walk", _walk_clips, _walk_joints, _frame_count, 1.0, delta)
	elif forward_speed < -_WALK_SPEED:
		_play_cycle("walk", _walk_clips, _walk_joints, _frame_count, -1.0, delta)
	elif turning:
		_play_cycle("walk", _walk_clips, _walk_joints, _frame_count, 1.0, delta)
	else:
		_play_idle(delta)


## LocalToon.trackAnimToSpeed starts the walk loop or the run loop when the
## action changes, and stops both when the toon stands still.
func _footsteps(speed: float, turning: bool) -> void:
	if not footsteps:
		_play_footsteps("")
		return
	var mode := ""
	if speed >= _RUN_CUTOFF:
		mode = "run"
	elif absf(speed) > _WALK_SPEED or turning:
		mode = "walk"
	_play_footsteps(mode)


func _play_footsteps(mode: String) -> void:
	if mode == _step_mode:
		return
	_step_mode = mode
	if mode != "" and _walk_steps == null:
		_walk_steps = _loop_steps(_WALK_STEPS)
		_run_steps = _loop_steps(_RUN_STEPS)
	if _walk_steps != null:
		if mode == "walk" and not _walk_steps.playing:
			_walk_steps.play()
		elif mode != "walk":
			_walk_steps.stop()
	if _run_steps != null:
		if mode == "run" and not _run_steps.playing:
			_run_steps.play()
		elif mode != "run":
			_run_steps.stop()


func _loop_steps(path: String) -> AudioStreamPlayer:
	var loaded := load(path) as AudioStream
	if loaded == null:
		return null
	var stream := loaded.duplicate() as AudioStream
	var mp3 := stream as AudioStreamMP3
	if mp3:
		mp3.loop = true
	var player := ToonAudio.effect_player()
	player.stream = stream
	add_child(player)
	return player


## Tutorial Tom's opening line loops tutorial-neutral: the gesturing body,
## the moving head, and the ear cycle. Other toons have no talk clip and stay idle.
func set_dialogue(delta: float) -> void:
	if _style == null:
		return
	_locomotion_msec = Time.get_ticks_msec()
	_ensure_clips()
	_hold_head()
	if _gesture != "":
		_play_bank(_gesture, _gesture_rate, delta, _gesture_loop)
		return
	if _play_bank("talk", 1.0, delta):
		return
	_play_idle(delta)


## right-hand and right-point from the tutorial quest movie. A negative rate
## plays the clip backward. loop false holds the last frame it reaches.
func play_gesture(suffix: String, rate: float, loop: bool) -> void:
	if _style == null:
		return
	_ensure_clips()
	if _gesture != suffix:
		var frames := int((_extra.get(suffix, {}) as Dictionary).get("frames", 0))
		_cycle_time[suffix] = float(maxi(frames - 1, 0)) if rate < 0.0 else 0.0
		_clip = ""
	_gesture = suffix
	_gesture_rate = rate
	_gesture_loop = loop
	_hold_head()


func _hold_head() -> void:
	_look_enabled = false
	_looking = false
	for look in _looks:
		if is_instance_valid(look):
			look.rotation = Vector3.ZERO


func clear_gesture() -> void:
	_gesture = ""
	_look_enabled = true


## True from the open clip through the close clip. Walking stays off.
func holding_book() -> bool:
	return _book_phase != ""


## enterOpenBook plays book from 1.2s to 1.5s, waits a tenth, then readBook.
func open_shticker() -> void:
	if _book_phase == "open" or _book_phase == "read":
		return
	_ensure_book_prop()
	if _book_prop != null:
		_book_prop.visible = true
	_book_phase = "open"
	_book_clock = 1.2
	_book_hold = 0.0
	_look_enabled = false
	_pose_book_frame(1.2 * 24.0)


## enterCloseBook plays book from 4.96s to 6.5s and then hides it.
func close_shticker() -> void:
	if _book_phase == "" or _book_phase == "close":
		return
	if _book_phase == "open":
		shticker_opened.emit()
	_book_phase = "close"
	_book_clock = 4.96
	_book_hold = 0.0
	if _book_prop != null and is_instance_valid(_book_prop):
		_book_prop.visible = true
	_pose_book_frame(4.96 * 24.0)


func _tick_shticker(delta: float) -> void:
	if _book_phase == "open":
		_book_clock += delta
		if _book_clock < 1.5:
			_pose_book_frame(_book_clock * 24.0)
			return
		_pose_book_frame(36.0)
		_book_hold += delta
		if _book_hold < 0.1:
			return
		_book_phase = "read"
		_book_clock = 0.0
		shticker_opened.emit()
		_pose_book_frame(38.0)
	elif _book_phase == "read":
		# pingpong from frame 38 to frame 118.
		_book_clock += delta
		var span := 80.0
		var trip := fposmod(_book_clock * 24.0, span * 2.0)
		var along := trip if trip <= span else span * 2.0 - trip
		_pose_book_frame(38.0 + along)
	elif _book_phase == "close":
		_book_clock += delta
		_pose_book_frame(minf(_book_clock * 24.0, 155.0))
		if _book_clock >= 6.5:
			_book_phase = ""
			if _book_prop != null and is_instance_valid(_book_prop):
				_book_prop.visible = false


func _pose_book_frame(time: float) -> void:
	ensure_clip("book")
	var bank: Dictionary = _extra.get("book", {})
	var frames := int(bank.get("frames", 0))
	var clips: Array = bank.get("clips", [])
	if frames <= 1 or clips.is_empty():
		_pose_book_prop(time)
		return
	var posed_time := clampf(time, 0.0, float(frames - 1))
	var frame := mini(int(posed_time), frames - 1)
	var following := mini(frame + 1, frames - 1)
	var blend := 0.0 if following == frame else posed_time - float(frame)
	_posing = true
	_clip = "book"
	var drawn := _pose_target("book", clips, bank["joints"])
	if not drawn.is_empty():
		_pose_clip(drawn["clips"], drawn["joints"], frame, following, blend)
	_pose_book_prop(posed_time)


func _ensure_book_prop() -> void:
	if _book_prop != null and is_instance_valid(_book_prop):
		var held := find_child("def_joint_right_hold", true, false) as Node3D
		if held != null and _book_prop.get_parent() != held:
			held.add_child(_book_prop)
		return
	var packed := load(_BOOK_MODEL) as PackedScene
	if packed == null:
		return
	var prop := packed.instantiate() as Node3D
	if prop == null:
		return
	prop.name = "ShtickerBookProp"
	_book_prop = prop
	var hand := find_child("def_joint_right_hold", true, false) as Node3D
	if hand == null:
		add_child(prop)
	else:
		hand.add_child(prop)
	_book_joints.clear()
	_ingest(_read_walk(_BOOK_CLIP), [], _book_joints, prop)


func _pose_book_prop(time: float) -> void:
	if _book_joints.is_empty() or _book_prop == null or not is_instance_valid(_book_prop):
		return
	var count := 0
	var first: Dictionary = _book_joints[0]
	count = (first.get("frames", []) as Array).size()
	if count <= 1:
		return
	var posed_time := clampf(time, 0.0, float(count - 1))
	var frame := mini(int(posed_time), count - 1)
	var following := mini(frame + 1, count - 1)
	var blend := 0.0 if following == frame else posed_time - float(frame)
	for joint in _book_joints:
		var node := joint["node"] as Node3D
		if not is_instance_valid(node):
			continue
		node.transform = _joint_pose(joint, frame, following, blend)


## enterSwim pitches the geom -89 degrees and loops swim. enterDive sinks that
## same body two units. The drop shadow stays off, the way both games hide it.
func pose_swimming(sunk: bool) -> void:
	_tilt_swim(sunk)
	play_gesture("swim", 1.0, true)
	set_locomotion(0.0, false, false, 0.0)


## Walk.py enters swimming once the toon is under the water. The pitch is the
## same one enterSwim puts on the geom, so the swim cycle reads as swimming.
func set_swimming(on: bool) -> void:
	if on:
		if not _swimming:
			_swimming = true
			play_gesture("swim", 1.0, true)
		# SwimWalker keeps the toon on the floor. The geom bob is what keeps
		# the pitched body out of that floor.
		_tilt_swim(false, true)
		return
	if not _swimming:
		return
	_swimming = false
	_untilt_swim()
	if _gesture == "swim":
		clear_gesture()


func is_swimming() -> bool:
	return _swimming


## Feet are under a water surface in this place. Donald's Dock, the estate
## lake, and the street ponds are those planes. A waterfall or a hydrant is not.
## The returned height is that surface. INF means the toon is not under it.
func swim_surface() -> float:
	if not is_inside_tree():
		return INF
	var feet := global_position
	var found := INF
	for box in _water_planes(self):
		if feet.x < box.position.x or feet.x > box.end.x:
			continue
		if feet.z < box.position.z or feet.z > box.end.z:
			continue
		var surface := box.end.y
		if feet.y < surface - 0.35 and surface < found:
			found = surface
	return found


func under_water() -> bool:
	return swim_surface() < INF


func _tilt_swim(sunk: bool, bob := false) -> void:
	var lifted := Vector3.ZERO
	if sunk:
		lifted = Vector3(0.0, 0.0, -2.0)
	elif bob:
		# startBobSwimTask. The geom rides 3 to 4 units up, clear of the floor.
		var wave := sin(float(Time.get_ticks_msec()) * 0.001 * PI)
		lifted = Vector3(0.0, -3.0, 3.5 + 0.5 * wave)
	for key in _lod_roots.keys():
		var root := _lod_roots[key] as Node3D
		if root == null:
			continue
		var hips := _find(root, "joint_hips") as Node3D
		if hips == null:
			continue
		var body := hips
		while body.get_parent() != root and body.get_parent() is Node3D:
			body = body.get_parent() as Node3D
		body.rotation_degrees.x = -89.0
		body.position = lifted
	for shadow in find_children("drop_shadow", "MeshInstance3D", true, false):
		shadow.visible = false


func _untilt_swim() -> void:
	for key in _lod_roots.keys():
		var root := _lod_roots[key] as Node3D
		if root == null:
			continue
		var hips := _find(root, "joint_hips") as Node3D
		if hips == null:
			continue
		var body := hips
		while body.get_parent() != root and body.get_parent() is Node3D:
			body = body.get_parent() as Node3D
		body.rotation_degrees.x = 0.0
		body.position = Vector3.ZERO
	for shadow in find_children("drop_shadow", "MeshInstance3D", true, false):
		shadow.visible = true


static var _planes: Array[AABB] = []
static var _plane_place := 0


static func _water_planes(actor: Node) -> Array[AABB]:
	var place := actor
	while place.get_parent() != null and place.scene_file_path.is_empty():
		place = place.get_parent()
	var id := place.get_instance_id()
	if id == _plane_place:
		return _planes
	_plane_place = id
	_planes = []
	_collect_water(place)
	return _planes


static func _collect_water(node: Node) -> void:
	if node is MeshInstance3D and _water_surface(node.name):
		var mesh := node as MeshInstance3D
		if mesh.mesh != null:
			_planes.append(mesh.global_transform * mesh.mesh.get_aabb())
	for child in node.get_children():
		_collect_water(child)


static func _water_surface(node_name: String) -> bool:
	var low := node_name.to_lower()
	if low.contains("waterfall") or low.contains("tower") or low.begins_with("dx_") or low.contains("ice"):
		return false
	if low == "top_surface" or low == "lake" or low == "water1" or low == "water_surface":
		return true
	if low.ends_with("pd_water") or low.ends_with("sz_water"):
		return true
	return "street_water" in low and low.ends_with("water")


func gesture_finished() -> bool:
	if _gesture == "" or _gesture_loop:
		return true
	var frames := int((_extra.get(_gesture, {}) as Dictionary).get("frames", 0))
	if frames <= 1:
		return true
	var time := float(_cycle_time.get(_gesture, 0.0))
	if _gesture_rate < 0.0:
		return time <= 0.05
	return time >= float(frames - 1) - 0.05


## angry, sad, and surprised are the eye sets the quest movie swaps in.
func set_expression(mood: String) -> void:
	# Sad locomotion asks for this every frame. Rebuilding the eye card each
	# time would throw away the open sheet on the next blink.
	if mood == _mood:
		return
	_mood = mood
	_mood_open = _expression_texture(mood, false)
	_mood_closed = _expression_texture(mood, true)
	if mood == "normal":
		_eyes_shut = false
		_blink_left = 0.0
	_apply_eyes()


func _ensure_clips() -> void:
	# Load every clip while the joints are still in the standing pose. A later
	# load would record an already-posed joint as the rest pose.
	if not load_extra_clips:
		_walk_missing = true
	elif not _walk_loaded and not _walk_missing:
		_load_walk()
		if not _walk_loaded:
			_walk_missing = true
	if not _idle_loaded and not _idle_missing:
		_load_idle()
		if not _idle_loaded:
			_idle_missing = true
	if not load_extra_clips:
			return
	# Extra clips have to load with the walk, while the joints are still at rest.
	# A gag clip loaded on first use records the idle pose as the bind, and the
	# throw, squirt, or lure never matches the original.
	for suffix in ["run", "jump", "rjump", "land", "rland", "talk", "rhand", "rstart", "rpoint", "pstart", "throw", "toss", "pushbutton", "battlecast", "hold-magnet", "hypnotize", "sound", "tickle", "smooch", "happy-dance", "sprinkle-dust", "juggle", "climb", "spit", "water-gun", "hold-bottle", "firehose", "conked", "cringe", "slip-forward", "slip-backward", "struggle", "sidestep-left", "sidestep-right", "duck", "victory", "teleport", "leap", "bank", "sit-start", "sit", "swim", "lose", "sad-neutral", "sad-walk", "cast", "castlong", "pole", "pole-neutral", "fish-neutral", "reel", "reel-neutral", "fish-again", "fish-end", "book"]:
		if not _extra.has(suffix):
			var clips: Array = []
			var joints: Array = []
			var frames := _load_clip(suffix, clips, joints)
			_extra[suffix] = {"clips": clips, "joints": joints, "frames": frames}


## Jungle Vines poses swing. It is not in the everyday set: 144 frames per part.
## Call this while the toon is still in the standing pose.
func ensure_clip(suffix: String) -> void:
	if _style == null:
		return
	_ensure_clips()
	var bank: Dictionary = _extra.get(suffix, {})
	if int(bank.get("frames", 0)) > 0:
		return
	var clips: Array = []
	var joints: Array = []
	var frames := _load_clip(suffix, clips, joints)
	_extra[suffix] = {"clips": clips, "joints": joints, "frames": frames}
	if not _cycle_time.has(suffix):
		_cycle_time[suffix] = 0.0


## GravityWalker sends jumpHardLand when the impact is faster than 30.
## The land pose plays for one second, then locomotion takes over again.
func hard_land() -> void:
	if _style == null:
		return
	_ensure_clips()
	_land_kind = "rland" if _jump_kind == "rjump" else "land"
	_jump_kind = ""
	_land_left = 1.0
	_clip = ""
	_cycle_time[_land_kind] = 0.0


func _play_bank(suffix: String, direction: float, delta: float, loop: bool = true) -> bool:
	var bank: Dictionary = _extra.get(suffix, {})
	var frames := int(bank.get("frames", 0))
	var clips: Array = bank.get("clips", [])
	if frames <= 0 or clips.is_empty():
		return false
	_play_cycle(suffix, clips, bank["joints"], frames, direction, delta, loop)
	return true


## One battle clip, held on a frame. The movie advances elapsed itself so a
## pie can leave the hand while the throw is still playing.
func action_length(suffix: String) -> float:
	ensure_clip(suffix)
	var bank: Dictionary = _extra.get(suffix, {})
	var frames := int(bank.get("frames", 0))
	if frames <= 1:
		return 0.0
	return float(frames - 1) / 24.0


func pose_action(suffix: String, elapsed: float) -> void:
	# A held pose owns the ears too. The idle flop would replace them after a tenth of a second.
	_locomotion_msec = Time.get_ticks_msec()
	ensure_clip(suffix)
	var bank: Dictionary = _extra.get(suffix, {})
	var frames := int(bank.get("frames", 0))
	var clips: Array = bank.get("clips", [])
	if frames <= 1 or clips.is_empty():
		return
	_pose_lock = true
	var time := clampf(elapsed * 24.0, 0.0, float(frames - 1))
	var frame := mini(int(time), frames - 1)
	var following := mini(frame + 1, frames - 1)
	var blend: float = 0.0 if following == frame else time - float(frame)
		_posing = true
	_clip = suffix
	var drawn := _pose_target(suffix, clips, bank["joints"])
	if drawn.is_empty():
		return
	_pose_clip(drawn["clips"], drawn["joints"], frame, following, blend)


## The sit loop uses the wall clock, so every rider is on the same frame.
func pose_synced_loop(suffix: String) -> void:
	var length := action_length(suffix)
	var elapsed := 0.0
	if length > 0.0:
		elapsed = fposmod(Time.get_unix_time_from_system(), length)
	pose_action(suffix, elapsed)


func release_pose() -> void:
	_pose_lock = false


func set_look_enabled(enabled: bool) -> void:
	if enabled:
		_look_enabled = true
		return
	_hold_head()


## enterTeleportOut clips the geom on a plane through the toon's feet.
func set_hole_clip(enabled: bool, floor_y: float) -> void:
	_apply_hole_clip(self, 1.0 if enabled else 0.0, floor_y)


func _apply_hole_clip(node: Node, enabled: float, floor_y: float) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		_clip_material(mesh_instance.material_override, enabled, floor_y)
		var mesh := mesh_instance.mesh
		if mesh != null:
			for index in mesh.get_surface_count():
				_clip_material(mesh.surface_get_material(index), enabled, floor_y)
				_clip_material(mesh_instance.get_surface_override_material(index), enabled, floor_y)
	for child in node.get_children():
		_apply_hole_clip(child, enabled, floor_y)


func _clip_material(material: Material, enabled: float, floor_y: float) -> void:
	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("hole_clip", enabled)
	shader_material.set_shader_parameter("hole_floor", floor_y)


func end_action(suffix: String) -> void:
	var bank: Dictionary = _extra.get(suffix, {})
	var clips: Array = bank.get("clips", [])
	var joints: Array = bank.get("joints", [])
	_restore_clip(clips, joints)
	if _clip == suffix:
		_clip = ""
		_posing = false
		_pose_lock = false


func _play_idle(delta: float) -> void:
	if not _idle_loaded:
		if _posing:
			_restore_posed_meshes()
			_posing = false
			_clip = ""
		return
	if _clip != "idle":
		# enterNeutral poses a random frame, then loops from there.
		_idle_time = float(randi() % _idle_frames)
		_posing = true
		_clip = "idle"
	_idle_time = fposmod(_idle_time + delta * 24.0, float(_idle_frames))
	if _idle_time >= float(_idle_frames):
		_idle_time = 0.0
	var frame := mini(int(_idle_time), _idle_frames - 1)
	var following := (frame + 1) % _idle_frames
	var drawn := _pose_target("idle", _idle_clips, _idle_joints)
	if drawn.is_empty():
		return
	_pose_clip(drawn["clips"], drawn["joints"], frame, following, _idle_time - float(frame))


func _play_cycle(clip_name: String, clips: Array, joints: Array, frame_count: int, direction: float, delta: float, loop: bool = true) -> void:
	if frame_count <= 0 or clips.is_empty():
		return
	# Changing animation restarts it. Changing only the play rate, which is how
	# backing up uses the walk cycle, keeps the current frame.
	if _clip != clip_name:
		# A backward one-shot starts on the last frame. play_gesture already
		# parked the clock there; don't snap it back to the first frame.
		if not _cycle_time.has(clip_name) or direction >= 0.0:
			_cycle_time[clip_name] = 0.0
		_posing = true
		_clip = clip_name
	var time := float(_cycle_time.get(clip_name, 0.0))
	time += delta * 24.0 * direction
	if loop:
		time = fposmod(time, float(frame_count))
	# fposmod can return the modulus itself. That index does not exist.
		if time >= float(frame_count):
			time = 0.0
	else:
		time = clampf(time, 0.0, float(frame_count - 1))
	_cycle_time[clip_name] = time
	var frame := mini(int(time), frame_count - 1)
	var following := frame
	if loop or frame < frame_count - 1:
		following = (frame + 1) % frame_count
	var blend: float = 0.0 if following == frame else time - float(frame)
	var drawn := _pose_target(clip_name, clips, joints)
	if drawn.is_empty():
		return
	_pose_clip(drawn["clips"], drawn["joints"], frame, following, blend)


func _load_walk() -> void:
	_frame_count = _load_clip("walk", _walk_clips, _walk_joints)
	_walk_loaded = _frame_count > 0 and not _walk_clips.is_empty()


func _load_idle() -> void:
	_idle_frames = _load_clip("idle", _idle_clips, _idle_joints)
	_idle_loaded = _idle_frames > 0 and not _idle_clips.is_empty()


func _load_clip(suffix: String, clips: Array, joints: Array, host: Node = null, lod: int = 1000) -> int:
	var scope: Node = self if host == null else host
	var frame_count := 0
	var leg := "legs_%s" % _style.legs
	var torso := "torso_%s" % _style.torso
	var head := _style.head
	if lod != 1000:
		leg = "%s_%d" % [leg, lod]
		torso = "%s_%d" % [torso, lod]
		head = "%s_%d" % [head, lod]
	var files := [
		_read_walk(_ANIMS + leg + "." + suffix),
		_read_walk(_ANIMS + torso + "." + suffix),
		_read_walk(_ANIMS + head + "." + suffix),
	]
	for clip in files:
		var surfaces_by_name: Dictionary = clip.get("surfaces", {})
		for node_name in surfaces_by_name.keys():
			var surfaces: Array = surfaces_by_name[node_name]
			var bound := _bind_part(scope, String(node_name), surfaces, clips)
			if bound <= 0:
				continue
			frame_count = maxi(frame_count, bound)
			if String(node_name) == "arms":
				_anchor_wrists(scope, surfaces)
		var joint_records: Dictionary = clip.get("joints", {})
		for joint_name in joint_records.keys():
			var joint := _find(scope, String(joint_name)) as Node3D
			var record: Dictionary = joint_records[joint_name]
			var frames: Array = record["frames"]
			if joint == null or frames.is_empty():
				continue
			frame_count = maxi(frame_count, frames.size())
			joints.append({
				"node": joint,
				"rest": joint.transform,
				"bind": record["bind"],
				"frames": frames,
			})
	return frame_count


static var _clip_cache: Dictionary = {}


func _read_walk(path: String) -> Dictionary:
	if _clip_cache.has(path):
		return _clip_cache[path]
	var result := {"surfaces": {}, "joints": {}}
	if not FileAccess.file_exists(path):
		_clip_cache[path] = result
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result
	var magic := file.get_buffer(8)
	if magic.slice(0, 6).get_string_from_ascii() != "TWALK3":
		file.close()
		return result
	var frame_count := file.get_32()
	var node_count := file.get_32()
	var surfaces_by_name: Dictionary = {}
	for _node_index in node_count:
		var name_len := file.get_16()
		var node_name := file.get_buffer(name_len).get_string_from_utf8()
		var surface_count := file.get_32()
		var surfaces: Array = []
		for _surface_index in surface_count:
			var vertex_count := file.get_32()
			var has_uv := file.get_8()
			var uvs := PackedVector2Array()
			if has_uv != 0:
				uvs.resize(vertex_count)
				for index in vertex_count:
					uvs[index] = Vector2(file.get_float(), file.get_float())
			var frames: Array = []
			for _frame_index in frame_count:
				var positions := PackedVector3Array()
				positions.resize(vertex_count)
				for index in vertex_count:
					positions[index] = Vector3(file.get_float(), file.get_float(), file.get_float())
				frames.append(positions)
			surfaces.append({"uv": uvs, "frames": frames})
		surfaces_by_name[node_name] = surfaces
	var joints: Dictionary = {}
	var joint_count := file.get_32()
	for _joint_index in joint_count:
		var name_len := file.get_16()
		var joint_name := file.get_buffer(name_len).get_string_from_utf8()
		var frames: Array = []
		var bind_cells := PackedFloat32Array()
		bind_cells.resize(16)
		for cell in 16:
			bind_cells[cell] = file.get_float()
		for _frame_index in frame_count:
			var cells := PackedFloat32Array()
			cells.resize(16)
			for cell in 16:
				cells[cell] = file.get_float()
			frames.append(_transform_from_panda(cells))
		joints[joint_name] = {"bind": _transform_from_panda(bind_cells), "frames": frames}
	file.close()
	result["surfaces"] = surfaces_by_name
	result["joints"] = joints
	_clip_cache[path] = result
	return result


func _transform_from_panda(cells: PackedFloat32Array) -> Transform3D:
	# Same reading as the glTF importer: Panda's row-vector matrix becomes a Godot basis.
	var basis := Basis(
		Vector3(cells[0], cells[1], cells[2]),
		Vector3(cells[4], cells[5], cells[6]),
		Vector3(cells[8], cells[9], cells[10])
	)
	basis = basis.orthonormalized()
	return Transform3D(basis, Vector3(cells[12], cells[13], cells[14]))


## Catalog hats and glasses sit on the head. Backpacks sit on the flower
## joint. Shoes swap the leg geoms the original model already has.
func wear_accessories(worn: Dictionary) -> void:
	_accessory_ids = worn.duplicate()
	_dress_all()
	_adopt_shoe_clips()


func _dress_all() -> void:
	if _style == null:
		return
	for key in _lod_roots.keys():
		var body := _lod_roots[key] as Node
		if body:
			_dress_body(body)


func _dress_body(body: Node) -> void:
	for old in body.find_children("catalog_*", "", true, false):
		old.free()
	var book := _accessory_catalog()
	var items: Dictionary = book.get("items", {})
	var head_key := _style.head.substr(0, 2) if _style.head.length() >= 2 else ""
	var torso_key := _style.torso.substr(0, 1) if not _style.torso.is_empty() else "m"
	var hide_ears := false
	var hide_lashes := false
	_shoe_mesh = ""
	_shoe_shown = ""
	for slot in _accessory_ids.keys():
		var item: Dictionary = items.get(str(int(_accessory_ids[slot])), {})
		if item.is_empty():
			continue
		var kind := String(item.get("slot", slot))
		if kind == "hat" or kind == "glasses":
			_place_accessory(body, item, head_key, "head_look")
			hide_ears = hide_ears or bool(item.get("hide_ears", false))
			hide_lashes = hide_lashes or bool(item.get("hide_lashes", false))
		elif kind == "backpack":
			_place_accessory(body, item, torso_key, "def_joint_attachFlower")
		elif kind == "shoes":
			_shoe_mesh = String(item.get("mesh", ""))
			_paint_shoes(body, item)
	_set_named_visible(body, "ears", not hide_ears)
	var lashes := _style.gender == "f" and not hide_lashes
	for node in body.find_children("eyelashes", "", true, false):
		node.visible = lashes
	_sync_shoes([])


func _place_accessory(body: Node, item: Dictionary, key: String, anchor_name: String) -> void:
	var model := String(item.get("model", ""))
	if model == "":
		return
	var host := _find(body, anchor_name)
	if host == null:
		return
	if anchor_name == "head_look" and host.get_child_count() > 0 and host.get_child(0) is Node3D:
		host = host.get_child(0) as Node3D
	var prop := _instance(model)
	if prop == null:
		return
	prop.name = "catalog_" + String(item.get("slot", "acc"))
	host.add_child(prop)
	prop.transform = _accessory_xform(item, key)
	_retint_accessory(prop, _mapped(String(item.get("texture", ""))))


func _accessory_xform(item: Dictionary, key: String) -> Transform3D:
	var book := _accessory_catalog()
	var slot := String(item.get("slot", ""))
	var extra: Dictionary = book.get(slot + "_extra", {})
	var special: Dictionary = extra.get(str(int(item.get("index", 0))), {})
	var cells: Array = special.get(key, [])
	if cells.is_empty():
		var base: Dictionary = book.get(slot, {})
		cells = base.get(key, [])
	if cells.size() < 16:
		return Transform3D.IDENTITY
	return _cells_to_xform(cells)


func _cells_to_xform(cells: Array) -> Transform3D:
	var basis := Basis(
		Vector3(float(cells[0]), float(cells[1]), float(cells[2])),
		Vector3(float(cells[4]), float(cells[5]), float(cells[6])),
		Vector3(float(cells[8]), float(cells[9]), float(cells[10]))
	)
	return Transform3D(basis, Vector3(float(cells[12]), float(cells[13]), float(cells[14])))


func _retint_accessory(node: Node, texture: Texture2D) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var found := texture
		if found == null and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
			var material := mesh.mesh.surface_get_material(0)
			if material is BaseMaterial3D:
				found = (material as BaseMaterial3D).albedo_texture
		mesh.material_override = _body_material(found, Color.WHITE, 0.0)
	for child in node.get_children():
		_retint_accessory(child, texture)


func _paint_shoes(body: Node, item: Dictionary) -> void:
	var path := String(item.get("texture", ""))
	if _style.legs == "l" and String(item.get("long_texture", "")) != "":
		path = String(item.get("long_texture", ""))
	var texture := _mapped(path)
	if texture == null:
		return
	var mesh := _find(body, _shoe_mesh) as MeshInstance3D
	if mesh != null:
		mesh.material_override = _body_material(texture, Color.WHITE, 0.0)


func _set_named_visible(body: Node, prefix: String, shown: bool) -> void:
	for node in body.find_children("*", "MeshInstance3D", true, false):
		if String(node.name).begins_with(prefix):
			node.visible = shown


func _sync_shoes(clips: Array) -> void:
	var want := "feet"
	if _shoe_mesh != "":
		for clip in clips:
			var inst := clip.get("instance") as Node
			if inst != null and String(inst.name) == _shoe_mesh:
				want = _shoe_mesh
				break
	if want == _shoe_shown:
		return
	_shoe_shown = want
	for name in ["feet", "shoes", "boots_short", "boots_long"]:
		_set_named_visible(self, name, name == want)


func _adopt_shoe_clips() -> void:
	if _shoe_mesh == "" or _style == null:
		return
	_adopt_shoe(_walk_clips, "walk")
	_adopt_shoe(_idle_clips, "idle")
	for suffix in _extra.keys():
		_adopt_shoe((_extra[suffix] as Dictionary).get("clips", []), String(suffix))
	for key in _far_clips.keys():
		var label := String(key)
		var suffix := label.split(":")[1] if label.contains(":") else label
		var bank: Dictionary = _far_clips[key]
		_adopt_shoe(bank.get("clips", []), suffix)


func _adopt_shoe(clips: Array, suffix: String) -> void:
	if clips.is_empty():
		return
	var sample := clips[0].get("instance") as Node
	if sample == null:
		return
	var body := sample
	while body != null and not _lod_roots.values().has(body):
		body = body.get_parent()
	if body == null:
		body = self
	var shoe := _find(body, _shoe_mesh) as MeshInstance3D
	if shoe == null:
		return
	for clip in clips:
		if clip.get("instance") == shoe:
			return
	var lod := ""
	var owner := shoe
	while owner != null:
		if _lod_roots.values().has(owner) and String(owner.name).is_valid_int() and int(owner.name) != 1000:
			lod = "_" + String(owner.name)
			break
		owner = owner.get_parent()
	var data := _read_walk(_ANIMS + "legs_%s%s.%s" % [_style.legs, lod, suffix])
	var surfaces: Array = (data.get("surfaces", {}) as Dictionary).get(_shoe_mesh, [])
	if surfaces.is_empty():
		return
	clips.append({
		"instance": shoe,
		"original": shoe.mesh,
		"surfaces": surfaces,
	})


func _accessory_catalog() -> Dictionary:
	if not _accessory_book.is_empty():
		return _accessory_book
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/toons/accessories/catalog.json"))
	if parsed is Dictionary:
		_accessory_book = parsed
	return _accessory_book


func _kept_mesh(value: Variant) -> MeshInstance3D:
	if value != null and is_instance_valid(value) and value is MeshInstance3D:
		return value
	return null


func _kept_node(value: Variant) -> Node3D:
	if value != null and is_instance_valid(value) and value is Node3D:
		return value
	return null


func _pose_clip(clips: Array, joints: Array, frame: int, _following: int, blend: float) -> void:
	# The next baked frame is only a small step away, so the pose can meet it
	# without folding a leg. The pose is one of five cached fractions. Holding
	# the whole frame made the cycle pop, and rebuilding a mesh every draw
	# was the hitch.
	var step := 0
	if blend > 0.001:
		step = mini(int(round(blend * float(_POSE_STEPS))), _POSE_STEPS - 1)
	var amount := float(step) / float(_POSE_STEPS)
	var cache_key := frame * _POSE_STEPS + step
	var posed_head: MeshInstance3D = null
	var built := false
	for clip in clips:
		var instance := _kept_mesh(clip.get("instance"))
		if instance == null:
			continue
		var cache: Dictionary = clip.get("posed_meshes", {})
		var posed: ArrayMesh = cache.get(cache_key) as ArrayMesh
		if posed == null:
			posed = _mesh_for_frame(clip, frame, amount)
			if posed == null:
				continue
			cache[cache_key] = posed
			clip["posed_meshes"] = cache
			built = true
		if posed == null:
			continue
		if instance.mesh != posed:
			instance.mesh = posed
		if String(instance.name).begins_with("head"):
			posed_head = instance
	_sync_shoes(clips)
	if built and posed_head != null:
		var host: Node = posed_head
		while host.get_parent() != null and host.get_parent() != self:
			host = host.get_parent()
		_unify_forehead(host)
		for clip in clips:
			var instance := _kept_mesh(clip.get("instance"))
			if instance == null or not is_instance_valid(instance.mesh) or not (instance.mesh is ArrayMesh):
				continue
			var cache: Dictionary = clip.get("posed_meshes", {})
			cache[cache_key] = instance.mesh
			clip["posed_meshes"] = cache
	for joint in joints:
		var node := _kept_node(joint.get("node"))
		if node == null:
			continue
		var frames: Array = joint["frames"]
		if frames.is_empty():
			continue
		var count := frames.size()
		var shown := frame % count
		var nxt := (shown + 1) % count
		node.transform = _joint_pose(joint, shown, nxt, amount)
	_seat_hands(joints)


func _mesh_for_frame(clip: Dictionary, frame: int, amount: float) -> ArrayMesh:
	var instance := _kept_mesh(clip.get("instance"))
	var source: Variant = clip.get("original")
	if instance == null or not is_instance_valid(source) or not (source is Mesh):
		return null
	var original := source as Mesh
		var surfaces: Array = clip["surfaces"]
		var posed := ArrayMesh.new()
	var part := String(instance.name)
		for surface_index in surfaces.size():
			var surface: Dictionary = surfaces[surface_index]
			var frames: Array = surface["frames"]
			if frames.is_empty():
				continue
		var frame_index := frame % frames.size()
		var next_index := (frame_index + 1) % frames.size()
		var positions := _blend_positions(surface, frame_index, next_index, amount)
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = positions
		arrays[Mesh.ARRAY_NORMAL] = _blend_normals(surface, frame_index, next_index, amount, part)
			var uvs: PackedVector2Array = surface["uv"]
			if uvs.size() == positions.size():
				arrays[Mesh.ARRAY_TEX_UV] = uvs
		if surface_index < original.get_surface_count():
			var colors := _corner_colors(original, surface_index, positions.size())
			if colors.size() == positions.size():
				arrays[Mesh.ARRAY_COLOR] = colors
			posed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			if surface_index < original.get_surface_count():
				posed.surface_set_material(surface_index, original.surface_get_material(surface_index))
	if posed.get_surface_count() == 0:
		return null
	return posed


func _joint_pose(joint: Dictionary, frame: int, following: int, blend: float) -> Transform3D:
	# Same fraction as the body meshes, so the hip does not lag the legs.
	var frames: Array = joint["frames"]
	var posed: Transform3D = frames[frame]
	if blend > 0.001:
		var nxt: Transform3D = frames[following]
		posed.origin = posed.origin.lerp(nxt.origin, blend)
		posed.basis = posed.basis.slerp(nxt.basis, blend)
	# The standing joint came from the glTF importer. Apply only the change from
	# that pose to the walk frame, so the hips and head are not twisted into the clothes.
	var bind: Transform3D = joint["bind"]
	var rest: Transform3D = joint["rest"]
	return rest * bind.affine_inverse() * posed


func _frame_normals(surface: Dictionary, frame: int, part: String) -> PackedVector3Array:
	var frames: Array = surface["frames"]
	var cached: Array = surface.get("normals", [])
	if cached.size() != frames.size():
		cached = []
		cached.resize(frames.size())
		surface["normals"] = cached
	var found: Variant = cached[frame]
	if found is PackedVector3Array:
		return found
	var positions: PackedVector3Array = frames[frame]
	var normals := _smooth_normals(positions, part.begins_with("ears"))
	cached[frame] = normals
	return normals


func _blend_positions(surface: Dictionary, frame: int, following: int, amount: float) -> PackedVector3Array:
	var frames: Array = surface["frames"]
	var current: PackedVector3Array = frames[frame]
	if amount <= 0.001 or following == frame:
		return current
	var stored: Dictionary = surface.get("blend_pos", {})
	var key := frame * _POSE_STEPS + int(round(amount * float(_POSE_STEPS)))
	var found: Variant = stored.get(key)
	if found is PackedVector3Array:
		return found
	var nxt: PackedVector3Array = frames[following]
	var mixed := PackedVector3Array()
	mixed.resize(current.size())
	for index in current.size():
		mixed[index] = current[index].lerp(nxt[index], amount)
	stored[key] = mixed
	surface["blend_pos"] = stored
	return mixed


func _blend_normals(surface: Dictionary, frame: int, following: int, amount: float, part: String) -> PackedVector3Array:
	var current := _frame_normals(surface, frame, part)
	if amount <= 0.001 or following == frame:
		return current
	var nxt := _frame_normals(surface, following, part)
	if nxt.size() != current.size():
		return current
	var mixed := PackedVector3Array()
	mixed.resize(current.size())
	for index in current.size():
		var normal := current[index].lerp(nxt[index], amount)
		mixed[index] = normal.normalized() if normal.length_squared() > 0.000001 else current[index]
	return mixed


func _restore_posed_meshes() -> void:
	_restore_clip(_walk_clips, _walk_joints)
	_restore_clip(_idle_clips, _idle_joints)
	for bank in _extra.values():
		_restore_clip(bank["clips"], bank["joints"])


func _restore_clip(clips: Array, joints: Array) -> void:
	for clip in clips:
		var instance := _kept_mesh(clip.get("instance"))
		var source: Variant = clip.get("original")
		if instance != null and is_instance_valid(source) and source is Mesh:
			instance.mesh = source
	for joint in joints:
		var node := _kept_node(joint.get("node"))
		if node != null:
			node.transform = joint["rest"]


func _instance(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as Node3D


## phase_3 drop_shadow on joint_shadow. The card is 8 units, scaled to 0.4,
## black at half strength, and it lies flat in the Z-up leg space.
func _add_shadow(root: Node = null) -> void:
	var host: Node = self if root == null else root
	var joint := _find(host, "joint_shadow")
	if joint == null:
		return
	var mesh := QuadMesh.new()
	mesh.orientation = PlaneMesh.FACE_Z
	mesh.size = Vector2(3.2, 3.2)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.0, 0.0, 0.0, 0.5)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var texture := load("res://assets/neighborhoods/toontown_central/props/drop_shadow.png") as Texture2D
	if texture:
		material.albedo_texture = texture
	var shadow := MeshInstance3D.new()
	shadow.name = "drop_shadow"
	shadow.mesh = mesh
	shadow.material_override = material
	shadow.position = Vector3(0.0, 0.0, 0.05)
	joint.add_child(shadow)


## ~ghost. The local player keeps a see-through toon. Anyone else does not
## draw it: pass local_player false for a replicated avatar, or omit
## LOCAL_GHOST_LAYER from that camera's cull mask.
func set_ghost_mode(enabled: bool, local_player: bool) -> void:
	ghost_mode = enabled
	if enabled and not local_player:
		_ghost_local = false
		_show_ghost_body(false)
		visible = false
		return
	visible = true
	_ghost_local = enabled
	_show_ghost_body(enabled)


func _show_ghost_body(enabled: bool) -> void:
	_ghost_visuals(self, enabled)
	if not enabled:
		_saved_layers.clear()


func _ghost_visuals(node: Node, enabled: bool) -> void:
	if node is GeometryInstance3D:
		var visual := node as GeometryInstance3D
		if enabled:
			if not _saved_layers.has(visual):
				_saved_layers[visual] = visual.layers
			visual.layers = LOCAL_GHOST_LAYER
		elif _saved_layers.has(visual):
			visual.layers = int(_saved_layers[visual])
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		_ghost_shadow(mesh, enabled)
		if mesh.material_override != null:
			_ghost_shader(mesh.material_override, enabled)
		if mesh.mesh != null:
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_surface_override_material(surface)
				if material != null:
					_ghost_shader(material, enabled)
	for child in node.get_children():
		_ghost_visuals(child, enabled)


func _ghost_shadow(mesh: MeshInstance3D, enabled: bool) -> void:
	if mesh.name != "drop_shadow" or not (mesh.material_override is StandardMaterial3D):
		return
	var material := mesh.material_override as StandardMaterial3D
	if enabled:
		if not mesh.has_meta("solid_shadow"):
			mesh.set_meta("solid_shadow", material.albedo_color.a)
		var faded := material.albedo_color
		faded.a = float(mesh.get_meta("solid_shadow")) * _GHOST_ALPHA
		material.albedo_color = faded
	elif mesh.has_meta("solid_shadow"):
		var solid := material.albedo_color
		solid.a = float(mesh.get_meta("solid_shadow"))
		material.albedo_color = solid
		mesh.remove_meta("solid_shadow")


func _ghost_shader(material: Material, enabled: bool) -> void:
	var shader_mat := material as ShaderMaterial
	if shader_mat == null or shader_mat.shader == null:
		return
	var path := shader_mat.shader.resource_path
	var face := path.contains("toon_face")
	var body := path.contains("toon_body")
	if not face and not body:
		return
	if enabled:
		shader_mat.shader = _FACE_GHOST if face else _BODY_GHOST
		shader_mat.set_shader_parameter("ghost_alpha", _GHOST_ALPHA)
	elif path.contains("_ghost"):
		shader_mat.shader = _FACE_SHADER if face else _BODY_SHADER


## Color and clothes only. The meshes and the idle clip stay where they are,
## so Make a Toon can change an option without dropping into the bind pose.
func recolor(style: ToonStyle) -> void:
	_style = style
	_recolor(self)


func _recolor(node: Node) -> void:
	if node is MeshInstance3D and _style != null:
		var mesh := node as MeshInstance3D
		var material := mesh.material_override as ShaderMaterial
		if material != null:
			var part := _part_name(mesh)
			var color := Color.WHITE
			var texture: Texture2D = null
			var paint := false
			if part == "hands":
				color = ToonStyle.fur_color(_style.glove_color)
				paint = true
			elif part == "arms" or part == "neck":
				color = _style.painted_color("arm")
				paint = true
			elif part == "legs" or part == "feet":
				color = _style.painted_color("leg")
				paint = true
			elif part.begins_with("ears"):
				color = Color.BLACK if _style.species() == "d" else _style.painted_color("head")
				paint = true
			elif part.begins_with("head"):
				color = _style.painted_color("head")
				paint = true
			elif part == "torso-top":
				color = ToonStyle.clothes_color(_style.top_color)
				texture = _shirt_texture(_style)
				paint = true
			elif part == "sleeves":
				color = ToonStyle.clothes_color(_style.top_color)
				texture = _sleeve_texture(_style)
				paint = true
			elif part.begins_with("torso-bot"):
				color = ToonStyle.clothes_color(_style.bot_color)
				if part.ends_with("cap"):
					color = color.darkened(0.35)
				texture = _bottom_texture(_style)
				paint = true
			if paint:
				material.set_shader_parameter("albedo_color", color)
				material.set_shader_parameter("use_albedo_texture", 1.0 if texture else 0.0)
				if texture:
					material.set_shader_parameter("albedo_texture", texture)
	for child in node.get_children():
		_recolor(child)


func _paint(node: Node, style: ToonStyle) -> void:
	if String(node.name) == "eyelashes":
		node.visible = style.gender == "f"
	if node is MeshInstance3D:
		_paint_mesh(node as MeshInstance3D, style)
	for child in node.get_children():
		_paint(child, style)


func _paint_mesh(mesh: MeshInstance3D, style: ToonStyle) -> void:
	var part := _part_name(mesh)
	var face := _face_kind(part)
	if face != "":
		_apply_face(mesh, style, face)
		return
	var color := Color.WHITE
	var texture: Texture2D = null
	var glove := 0.0
	var face_sign := 1.0
	if part == "hands":
		color = ToonStyle.fur_color(style.glove_color)
		glove = 1.0
	elif part == "arms" or part == "neck":
		color = style.painted_color("arm")
	elif part == "legs" or part == "feet":
		color = style.painted_color("leg")
	elif part.begins_with("muzzle"):
		# The snout keeps the normals it was exported with. Rebuilding them from
		# the snout's own center points the two halves apart and draws a seam.
		_lit_surface(mesh, 0.0, 0.0)
		return
	elif part == "nose":
		_lit_surface(mesh, 0.004, 0.85)
		return
	elif part.begins_with("ears"):
		# Dogs keep the black ears from the model. Other species take the head color.
		# Ears are a thin shell. The two sides share corners, so a single averaged
		# normal cancels and every triangle shades on its own.
		_smooth_sides(mesh)
		color = Color.BLACK if style.species() == "d" else style.painted_color("head")
	elif part.begins_with("head"):
		color = style.painted_color("head")
		# Smoothed skull normals point backward. The body does not.
		face_sign = -1.0
	elif part == "torso-top":
		color = ToonStyle.clothes_color(style.top_color)
		texture = _shirt_texture(style)
	elif part == "sleeves":
		color = ToonStyle.clothes_color(style.top_color)
		texture = _sleeve_texture(style)
	elif part.begins_with("torso-bot"):
		color = ToonStyle.clothes_color(style.bot_color)
		if part.ends_with("cap"):
			color = color.darkened(0.35)
		texture = _bottom_texture(style)
	else:
		_shade_existing(mesh)
		return
	# Clothes are a shell over the body so the body underneath cannot show through.
	var shell := 0.0
	if part == "torso-top" or part == "sleeves" or part.begins_with("torso-bot"):
		shell = 0.06
	mesh.material_override = _body_material(texture, color, shell, 0.0, glove, face_sign)


func _mapped(path: String) -> Texture2D:
	if path == "":
		return null
	return load(path) as Texture2D


func _shirt_texture(style: ToonStyle) -> Texture2D:
	var mapped := _mapped(style.top_map)
	if mapped != null:
		return mapped
	return _SHIRT[clampi(style.top_tex, 0, _SHIRT.size() - 1)]


func _sleeve_texture(style: ToonStyle) -> Texture2D:
	var mapped := _mapped(style.sleeve_map)
	if mapped != null:
		return mapped
	return _SLEEVE[clampi(style.top_tex, 0, _SLEEVE.size() - 1)]


func _bottom_texture(style: ToonStyle) -> Texture2D:
	var mapped := _mapped(style.bottom_map)
	if mapped != null:
		return mapped
	if style.wears_skirt():
		return _SKIRT
	if style.bot_tex == 1:
		return _SHORTS[1]
	# BoyShorts index 2 is desat_shorts_4. Make a Toon stays on 0 and 1.
	if style.bot_tex == 2:
		return _SHORTS[2]
	return _SHORTS[0]


func _part_name(mesh: MeshInstance3D) -> String:
	var part := String(mesh.name)
		var parent := mesh.get_parent()
	# Pupil cards are unnamed meshes. A second card is renamed node2 on import.
	if parent and _is_pupil_joint(String(parent.name)):
		return String(parent.name)
	if part == "node" or part.is_empty():
		# Mouse noses are an unnamed mesh under the head. Pupils already returned above.
		if parent and String(parent.name).to_lower().contains("head"):
			return "nose"
		if parent:
			part = String(parent.name)
	return part


func _face_kind(part: String) -> String:
	# Muzzle and nose are lit with the head. Only the eye cards stay flat.
	if part.begins_with("eyes"):
		return "eyes"
	if part == "eyelashes" or part.begins_with("eyelash"):
		return "lashes"
	if part.contains("pupil"):
		return "pupil"
	return ""


func _apply_face(mesh: MeshInstance3D, style: ToonStyle, kind: String) -> void:
	var source := mesh.mesh
	if source == null:
		return
	# The cards already sit on the face. Pushing them along the normal opened a
	# gap. They stay in the opaque pass (alpha scissor). Writing DEPTH to fake
	# that gap drops the cards in the compatibility renderer, so the eyes vanish.
	# Alpha blending sorted those cards behind the head and left holes in the face.
	var scissor := 0.0
	var push := 0.0
	match kind:
		"muzzle":
			push = 0.001
		"nose":
			push = 0.0015
		"eyes":
			scissor = 0.5
		"pupil":
			scissor = 0.5
		"lashes":
			scissor = 0.5
	mesh.material_override = null
	for surface in source.get_surface_count():
		var texture: Texture2D = null
		var color := Color.WHITE
		if kind == "front":
			color = style.painted_color("head")
		else:
			var material := source.surface_get_material(surface)
			if material is BaseMaterial3D:
				var standard := material as BaseMaterial3D
				texture = standard.albedo_texture
				color = standard.albedo_color
		# The blink swaps in a plain image. The open sheet has to be one too, or the
		# sclera's alpha does not survive and the fur shows through the eye.
		if kind == "eyes" or kind == "pupil" or kind == "lashes":
			texture = _raw_face_texture(texture)
		if kind == "eyes" and texture:
			# The open sheet stays on the mesh. Putting it back onto a material
			# that already showed the closed lids does not stick in this renderer.
			mesh.set_meta(&"open_eye", texture)
			mesh.set_meta(&"eye_color", color)
		mesh.set_surface_override_material(surface, _face_material(texture, color, scissor, push))


static var _raw_face_textures: Dictionary = {}


func _raw_face_texture(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var path := texture.resource_path
	if path.is_empty():
		return texture
	if _raw_face_textures.has(path):
		return _raw_face_textures[path] as Texture2D
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return texture
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return texture
	var raw := ImageTexture.create_from_image(image)
	_raw_face_textures[path] = raw
	return raw


func _face_material(texture: Texture2D, color: Color, scissor: float, push: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _FACE_GHOST if _ghost_local else _FACE_SHADER
	material.set_shader_parameter("albedo_color", color)
	material.set_shader_parameter("scissor_threshold", scissor)
	material.set_shader_parameter("surface_push", push)
	material.set_shader_parameter("use_albedo_texture", 1.0 if texture else 0.0)
	if texture:
		material.set_shader_parameter("albedo_texture", texture)
	if _ghost_local:
		material.set_shader_parameter("ghost_alpha", _GHOST_ALPHA)
	return material


func _shade_existing(mesh: MeshInstance3D) -> void:
	var source := mesh.mesh
	if source == null:
		return
	for surface in source.get_surface_count():
		var texture: Texture2D = null
		var color := Color.WHITE
		var material := source.surface_get_material(surface)
		if material is BaseMaterial3D:
			var standard := material as BaseMaterial3D
			texture = standard.albedo_texture
			color = standard.albedo_color
		mesh.set_surface_override_material(surface, _body_material(texture, color, 0.0))


func _lit_surface(mesh: MeshInstance3D, shell: float, gloss: float) -> void:
	var source := mesh.mesh
	if source == null or source.get_surface_count() == 0:
		return
	var texture: Texture2D = null
	var color := Color.WHITE
	var material := source.surface_get_material(0)
	if material is BaseMaterial3D:
		var standard := material as BaseMaterial3D
		texture = standard.albedo_texture
		color = standard.albedo_color
	mesh.material_override = _body_material(texture, color, shell, gloss)


func _body_material(texture: Texture2D, color: Color, shell: float, gloss: float = 0.0, glove: float = 0.0, face_sign: float = 1.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _BODY_GHOST if _ghost_local else _BODY_SHADER
	material.set_shader_parameter("albedo_color", color)
	material.set_shader_parameter("shell", shell)
	material.set_shader_parameter("gloss", gloss)
	material.set_shader_parameter("glove", glove)
	material.set_shader_parameter("face_sign", face_sign)
	material.set_shader_parameter("use_albedo_texture", 1.0 if texture else 0.0)
	if texture:
		material.set_shader_parameter("albedo_texture", texture)
	if _ghost_local:
		material.set_shader_parameter("ghost_alpha", _GHOST_ALPHA)
	return material


func _smooth_normals(positions: PackedVector3Array, split_back: bool = false) -> PackedVector3Array:
	if not split_back:
		return _smooth_closed(positions)
	var normals := PackedVector3Array()
	normals.resize(positions.size())
	var faces: Array[Vector3] = []
	var groups := {}
	var tri_count := positions.size() / 3
	faces.resize(tri_count)
	for tri in tri_count:
		var face := (positions[tri * 3 + 1] - positions[tri * 3]).cross(positions[tri * 3 + 2] - positions[tri * 3])
		face = face.normalized() if face.length_squared() > 0.0000001 else Vector3.FORWARD
		faces[tri] = face
		for corner in 3:
			normals[tri * 3 + corner] = face
			var point := positions[tri * 3 + corner]
			var key := Vector3i(roundi(point.x * 100.0), roundi(point.y * 100.0), roundi(point.z * 100.0))
			if not groups.has(key):
				groups[key] = []
			(groups[key] as Array).append(tri)
	for tri in tri_count:
		var face: Vector3 = faces[tri]
		for corner in 3:
			var point := positions[tri * 3 + corner]
			var key := Vector3i(roundi(point.x * 100.0), roundi(point.y * 100.0), roundi(point.z * 100.0))
			var sum := Vector3.ZERO
			for other in groups[key]:
				var other_face: Vector3 = faces[int(other)]
				# The back of an ear shares these corners and points the other way.
				if face.dot(other_face) > 0.0:
					sum += other_face
			normals[tri * 3 + corner] = sum.normalized() if sum.length_squared() > 0.0000001 else face
	return normals


## Clothes are a thin shell. Front and back share corners, so their face normals
## cancel. One shared direction keeps the clothing push from opening a cut.
func _smooth_closed(positions: PackedVector3Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(positions.size())
	var groups := {}
	for index in range(0, positions.size() - 2, 3):
		var a := positions[index]
		var b := positions[index + 1]
		var c := positions[index + 2]
		var face := (b - a).cross(c - a)
		for corner in 3:
			var point: Vector3 = positions[index + corner]
			var key := Vector3i(roundi(point.x * 100.0), roundi(point.y * 100.0), roundi(point.z * 100.0))
			if not groups.has(key):
				groups[key] = []
			(groups[key] as Array).append(index + corner)
			normals[index + corner] = face
	for key in groups:
		var sum := Vector3.ZERO
		var corners: Array = groups[key]
		for corner in corners:
			sum += normals[int(corner)]
		if sum.length_squared() < 0.0000001:
			sum = Vector3.UP
		else:
			sum = sum.normalized()
		for corner in corners:
			normals[int(corner)] = sum
	return normals


## Standing ears keep the exported normals, which cancelled across the shell.
func _smooth_sides(instance: MeshInstance3D) -> void:
	var source := instance.mesh
	if source == null:
		return
	var rebuilt := ArrayMesh.new()
	for surface_index in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if vertices.is_empty():
			continue
		var corners := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			corners = arrays[Mesh.ARRAY_INDEX]
		if corners.is_empty():
			corners.resize(vertices.size())
			for index in vertices.size():
				corners[index] = index
		if corners.size() < 3:
			continue
		var expanded := PackedVector3Array()
		expanded.resize(corners.size())
		for index in corners.size():
			expanded[index] = vertices[corners[index]]
		var normals := _smooth_normals(expanded, true)
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var built: Array = []
		built.resize(Mesh.ARRAY_MAX)
		built[Mesh.ARRAY_VERTEX] = expanded
		built[Mesh.ARRAY_NORMAL] = normals
		if uvs.size() == vertices.size():
			var out_uv := PackedVector2Array()
			out_uv.resize(corners.size())
			for index in corners.size():
				out_uv[index] = uvs[corners[index]]
			built[Mesh.ARRAY_TEX_UV] = out_uv
		if colors.size() == vertices.size():
			var out_color := PackedColorArray()
			out_color.resize(corners.size())
			for index in corners.size():
				out_color[index] = colors[corners[index]]
			built[Mesh.ARRAY_COLOR] = out_color
		rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, built)
		rebuilt.surface_set_material(surface_index, source.surface_get_material(surface_index))
	instance.mesh = rebuilt


## The forehead patch is a second copy of the front of the skull. Its exported
## normals point at the camera while the skull at the same points points
## sideways, so the overlap draws a line. Smooth both meshes as one surface.
func _unify_forehead(root: Node) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	for patch in meshes:
		var patch_name := String(patch.name)
		if not patch_name.begins_with("head-front"):
			continue
		var suffix := patch_name.trim_prefix("head-front")
		for skull in meshes:
			var skull_name := String(skull.name)
			if skull_name.begins_with("head-front") or not skull_name.begins_with("head"):
				continue
			if skull_name.trim_prefix("head") != suffix:
				continue
			_smooth_joined(skull, patch)
			break


func _collect_meshes(node: Node, into: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		into.append(node)
	for child in node.get_children():
		_collect_meshes(child, into)


func _smooth_joined(skull: MeshInstance3D, patch: MeshInstance3D) -> void:
	if skull.mesh == null or patch.mesh == null:
		return
	var skull_corners := _triangle_positions(skull.mesh)
	var patch_corners := _triangle_positions(patch.mesh)
	if skull_corners.is_empty() or patch_corners.is_empty():
		return
	var joined := PackedVector3Array()
	joined.append_array(skull_corners)
	joined.append_array(patch_corners)
	var normals := _smooth_closed(joined)
	_apply_corner_normals(skull, normals, 0)
	_apply_corner_normals(patch, normals, skull_corners.size())


func _triangle_positions(mesh: Mesh) -> PackedVector3Array:
	var out := PackedVector3Array()
	for surface_index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if vertices.is_empty():
			continue
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for vertex in vertices:
				out.append(vertex)
		else:
			for index in indices:
				out.append(vertices[index])
	return out


func _apply_corner_normals(instance: MeshInstance3D, corner_normals: PackedVector3Array, offset: int) -> void:
	var source := instance.mesh
	if source == null:
		return
	var rebuilt := ArrayMesh.new()
	var cursor := offset
	for surface_index in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if vertices.is_empty():
			continue
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]
		var normals := PackedVector3Array()
		normals.resize(vertices.size())
		normals.fill(Vector3.UP)
		var corner_count := indices.size() if not indices.is_empty() else vertices.size()
		for corner in corner_count:
			if cursor >= corner_normals.size():
				break
			var vertex_index := indices[corner] if not indices.is_empty() else corner
			normals[vertex_index] = corner_normals[cursor]
			cursor += 1
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var built: Array = []
		built.resize(Mesh.ARRAY_MAX)
		built[Mesh.ARRAY_VERTEX] = vertices
		built[Mesh.ARRAY_NORMAL] = normals
		if not indices.is_empty():
			built[Mesh.ARRAY_INDEX] = indices
		if uvs.size() == vertices.size():
			built[Mesh.ARRAY_TEX_UV] = uvs
		if colors.size() == vertices.size():
			built[Mesh.ARRAY_COLOR] = colors
		rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, built)
		rebuilt.surface_set_material(surface_index, source.surface_get_material(surface_index))
	instance.mesh = rebuilt


func _corner_colors(mesh: Mesh, surface_index: int, corner_count: int) -> PackedColorArray:
	var arrays := mesh.surface_get_arrays(surface_index)
	if arrays[Mesh.ARRAY_COLOR] == null:
		return PackedColorArray()
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	if colors.is_empty():
		return PackedColorArray()
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		return colors if colors.size() == corner_count else PackedColorArray()
	if indices.size() != corner_count:
		return PackedColorArray()
	var expanded := PackedColorArray()
	expanded.resize(corner_count)
	for index in corner_count:
		var source := indices[index]
		if source < 0 or source >= colors.size():
			return PackedColorArray()
		expanded[index] = colors[source]
	return expanded


func _physics_process(delta: float) -> void:
	if not follows_ground or get_parent() is CharacterBody3D:
		return
	_ground.step(self, delta)


func _process(delta: float) -> void:
	if _style == null:
		return
	if _book_phase != "":
		_tick_shticker(delta)
	_tick_blink(delta)
	_tick_look(delta)
	# Pick a Toon only shows the head, so it never asks for locomotion.
	# Dogs still loop neutral there so the ears keep flopping.
	if Time.get_ticks_msec() - _locomotion_msec > 100 and _style.species() == "d":
		_tick_dog_ears(delta)
	if footsteps and _step_mode != "" and Time.get_ticks_msec() - _locomotion_msec > 100:
		_footsteps(0.0, false)


func _prepare_face() -> void:
	_pupils.clear()
	_eyes.clear()
	_lashes.clear()
	_collect_face(self)
	_blink_wait = randf() * 4.0 + 1.0
	_look_wait = randf() * 5.0 + 2.0
	_apply_eyes()


func _collect_face(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var kind := _face_kind(_part_name(mesh))
		if kind == "eyes":
			var open_texture: Texture2D = null
			var eye_color := Color.WHITE
			if mesh.has_meta(&"open_eye"):
				open_texture = mesh.get_meta(&"open_eye") as Texture2D
			if mesh.has_meta(&"eye_color"):
				eye_color = mesh.get_meta(&"eye_color")
			# Stamp matches the painted card, so the first blink is what builds a new one.
			_eyes.append({"mesh": mesh, "open": open_texture, "color": eye_color, "stamp": "0" + _mood})
		elif kind == "pupil":
			var mover := mesh as Node3D
			var parent := mesh.get_parent()
			var label := String(mesh.name)
			if parent and _is_pupil_joint(String(parent.name)):
				mover = parent
				label = String(parent.name)
			var side := "right" if label.contains("right") or label.contains("pupilR") or label.contains("Right") else "left"
			_pupils.append({"mesh": mesh, "mover": mover, "rest": mover.position, "side": side})
		elif kind == "lashes":
			_lashes.append(mesh)
	for child in node.get_children():
		_collect_face(child)


func _is_pupil_joint(name: String) -> bool:
	return name.begins_with("def_left_pupil") or name.begins_with("def_right_pupil") or name.begins_with("joint_pupil")


func _tick_blink(delta: float) -> void:
	if _mood == "surprised":
		return
	if _eyes_shut:
		_blink_left -= delta
		var elapsed := Time.get_ticks_msec() - _blink_started_msec
		if _blink_left > 0.0 and elapsed < 125:
			return
		_finish_blink()
		return
	_blink_wait -= delta
	if _blink_wait <= 0.0:
		_shut_eyes()


func _shut_eyes() -> void:
	if _eyes_shut:
		return
	_eyes_shut = true
	_blink_left = 0.125
	_blink_started_msec = Time.get_ticks_msec()
	_apply_eyes()
	var tree := get_tree()
	if tree == null:
		return
	# The frame clock and a one-shot both open the lids, so a hitch cannot leave them down.
	var timer := tree.create_timer(0.125)
	timer.timeout.connect(_finish_blink, CONNECT_ONE_SHOT)


func _finish_blink() -> void:
	if not _eyes_shut or _mood == "surprised":
		return
	_eyes_shut = false
	_blink_left = 0.0
	_blink_wait = 0.2 if randf() < 0.1 else randf() * 4.0 + 1.0
	_apply_eyes()


func _expression_texture(mood: String, closed: bool) -> Texture2D:
	var file := ""
	match mood:
		"angry":
			file = "eyesAngryClosed.png" if closed else "eyesAngry.png"
		"sad":
			file = "eyesSadClosed.png" if closed else "eyesSad.png"
		"surprised":
			file = "eyesSurprised.png"
		_:
			return _load_closed_eyes() if closed else null
	return load("res://assets/toons/face/" + file) as Texture2D


func _apply_eyes() -> void:
	# A material that has already drawn the closed lids keeps them if we only
	# write the open sheet back onto it. Each change gets a new material.
	var stamp: String = ("1" if _eyes_shut else "0") + _mood
	for eye in _eyes:
		var mesh := eye["mesh"] as MeshInstance3D
		if not is_instance_valid(mesh):
			continue
		if String(eye.get("stamp", "")) == stamp:
			continue
		eye["stamp"] = stamp
		var open: Texture2D = _mood_open if _mood_open else eye["open"]
		if open == null and mesh.has_meta(&"open_eye"):
			open = mesh.get_meta(&"open_eye") as Texture2D
			eye["open"] = open
		var closed: Texture2D = _mood_closed if _mood_closed else _load_closed_eyes()
		var texture: Texture2D = closed if _eyes_shut and closed else open
		if texture == null:
			continue
		var color: Color = eye["color"] if eye.has("color") else Color.WHITE
		var material := _face_material(texture, color, 0.5, 0.0)
		mesh.material_override = material
		var surfaces := 1
		if mesh.mesh:
			surfaces = maxi(mesh.mesh.get_surface_count(), 1)
		for surface in surfaces:
			mesh.set_surface_override_material(surface, material)
	for pupil in _pupils:
		var mesh := pupil["mesh"] as MeshInstance3D
		if is_instance_valid(mesh):
			mesh.visible = not _eyes_shut
	for lash in _lashes:
		if is_instance_valid(lash):
			lash.visible = not _eyes_shut and _style.gender == "f"


func _load_closed_eyes() -> Texture2D:
	if _eyes_closed:
		return _eyes_closed
	var bytes := FileAccess.get_file_as_bytes("res://assets/toons/face/eyes_closed.png")
	if bytes.is_empty():
		return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	_eyes_closed = ImageTexture.create_from_image(image)
	return _eyes_closed


func _tick_look(delta: float) -> void:
	if _look == null or not _look_enabled:
		return
	if not _looking:
		_look_wait -= delta
		if _look_wait > 0.0:
			return
		_begin_look()
	_look_time += delta
	var t := clampf(_look_time / 1.0, 0.0, 1.0)
	var head_blend := t * t * (3.0 - 2.0 * t)
	_heading = lerpf(_heading_from, _heading_to, head_blend)
	_pitch = lerpf(_pitch_from, _pitch_to, head_blend)
	var look_basis := Basis(Vector3(0, 0, 1), _heading) * Basis(Vector3(1, 0, 0), _pitch)
	for look in _looks:
		if is_instance_valid(look):
			look.basis = look_basis
	var weight := 0.0
	if t < 0.2:
		weight = _ease_out(t / 0.2)
	elif t < 0.7:
		weight = 1.0
	else:
		weight = 1.0 - _ease_out((t - 0.7) / 0.3)
	_place_pupils(_left_target * weight, _right_target * weight)
	if t >= 1.0:
		_looking = false
		_look_wait = randf() * 4.0 + 3.0


func _begin_look() -> void:
	_looking = true
	_look_time = 0.0
	_heading_from = _heading
	_pitch_from = _pitch
	var x := 0.0
	var z := 0.0
	# One look in three picks a point in front of the face. The rest return forward.
	if randf() < 0.33:
		var xs: Array[float] = [-0.8, -0.5, 0.0, 0.5, 0.8]
		var zs: Array[float] = [-0.5, 0.0, 0.5, 0.8]
		x = xs[randi() % xs.size()]
		z = zs[randi() % zs.size()]
	_heading_to = clampf(-atan2(x, 1.5), deg_to_rad(-60.0), deg_to_rad(60.0))
	_pitch_to = clampf(atan2(z, 1.5), deg_to_rad(-20.0), deg_to_rad(30.0))
	var pupil_x := clampf(x / 1.5, -1.0, 1.0)
	var pupil_y := clampf(z / 1.5, -1.0, 1.0)
	_left_target = _pupil_point(true, pupil_x, pupil_y) * 0.5
	_right_target = _pupil_point(false, pupil_x, pupil_y) * 0.5


func _ease_out(t: float) -> float:
	var clamped := clampf(t, 0.0, 1.0)
	return 1.0 - (1.0 - clamped) * (1.0 - clamped)


func _pupil_point(left: bool, x: float, y: float) -> Vector3:
	if left:
		return _pupil_side(_LEFT_A, _LEFT_B, _LEFT_AD, _LEFT_BC, _LEFT_D, _LEFT_C, x, y)
	return _pupil_side(_RIGHT_A, _RIGHT_B, _RIGHT_AD, _RIGHT_BC, _RIGHT_D, _RIGHT_C, x, y)


func _pupil_side(up_a: Vector3, up_b: Vector3, flat_ad: Vector3, flat_bc: Vector3, down_d: Vector3, down_c: Vector3, x: float, y: float) -> Vector3:
	var y2 := absf(y)
	var first: Vector3
	var second: Vector3
	if y < 0.0:
		first = flat_ad + (down_d - flat_ad) * y2
		second = flat_bc + (down_c - flat_bc) * y2
	else:
		first = flat_ad + (up_a - flat_ad) * y2
		second = flat_bc + (up_b - flat_bc) * y2
	var span := second.x - first.x
	var origin_z := 0.0
	if absf(span) > 0.0001:
		origin_z = first.z - first.x * (second.z - first.z) / span
	var origin := Vector3(0.0, 0.0, origin_z)
	if x < 0.0:
		return origin + (second - origin) * -x
	return origin + (first - origin) * x


func _place_pupils(left_offset: Vector3, right_offset: Vector3) -> void:
	for pupil in _pupils:
		var mover := pupil["mover"] as Node3D
		if not is_instance_valid(mover):
			continue
		var rest: Vector3 = pupil["rest"]
		var offset := left_offset if String(pupil["side"]) == "left" else right_offset
		mover.position = rest + Vector3(offset.x, 0.0, offset.z)


func _tick_far_ears(delta: float) -> void:
	if _shown == 0:
		return
	var bank: Dictionary = _far_clips.get("%d:head-idle" % _shown, {})
	var frames := int(bank.get("frames", 0))
	var clips: Array = bank.get("clips", [])
	if frames <= 0 or clips.is_empty():
		return
	if not _head_idle_started:
		_head_idle_time = float(randi() % frames)
		_head_idle_started = true
	_head_idle_time = fposmod(_head_idle_time + delta * 24.0, float(frames))
	if _head_idle_time >= float(frames):
		_head_idle_time = 0.0
	var frame := mini(int(_head_idle_time), frames - 1)
	var following := (frame + 1) % frames
	_pose_clip(clips, [], frame, following, _head_idle_time - float(frame))


func _tick_dog_ears(delta: float) -> void:
	if _shown != 1000:
		_tick_far_ears(delta)
		return
	if _head_idle_missing:
		return
	if _head_idle_frames <= 0:
		_head_idle_frames = _ingest(_read_walk(_ANIMS + "%s.idle" % _style.head), _head_idle_clips, [])
		if _head_idle_frames <= 0:
			_head_idle_missing = true
			return
		_head_idle_time = float(randi() % _head_idle_frames)
		_head_idle_started = true
	if not _head_idle_started:
		_head_idle_time = float(randi() % _head_idle_frames)
		_head_idle_started = true
	_head_idle_time = fposmod(_head_idle_time + delta * 24.0, float(_head_idle_frames))
	if _head_idle_time >= float(_head_idle_frames):
		_head_idle_time = 0.0
	var frame := mini(int(_head_idle_time), _head_idle_frames - 1)
	var following := (frame + 1) % _head_idle_frames
	_pose_clip(_head_idle_clips, [], frame, following, _head_idle_time - float(frame))


## One clip entry per mesh. Far torsos name both gloves "hands", and each glove
## is its own surface. Giving both surfaces to the first glove draws the other
## hand in the wrong place on every toon that drops to that model.
func _bind_part(scope: Node, node_name: String, surfaces: Array, clips: Array) -> int:
	var meshes: Array = []
	_collect_named_meshes(scope, node_name, meshes)
	if meshes.is_empty() or surfaces.is_empty():
		return 0
	var frames: Array = surfaces[0]["frames"]
	if frames.is_empty():
		return 0
	if meshes.size() > 1 and meshes.size() == surfaces.size():
		for index in meshes.size():
			var mesh := meshes[index] as MeshInstance3D
			if mesh == null or mesh.mesh == null:
				continue
			var one: Array = [surfaces[index]]
			clips.append({
				"instance": mesh,
				"original": mesh.mesh,
				"surfaces": one,
			})
		return frames.size()
	var mesh := meshes[0] as MeshInstance3D
	if mesh == null or mesh.mesh == null:
		return 0
	clips.append({
		"instance": mesh,
		"original": mesh.mesh,
		"surfaces": surfaces,
	})
	return frames.size()


func _collect_named_meshes(node: Node, wanted: String, into: Array) -> void:
	# The importer renames the second glove hands2. It is still the hands part.
	if node is MeshInstance3D and _same_part(String(node.name), wanted):
		into.append(node)
	for child in node.get_children():
		_collect_named_meshes(child, wanted, into)


func _same_part(name: String, wanted: String) -> bool:
	if name == wanted:
		return true
	if not name.begins_with(wanted):
		return false
	return name.substr(wanted.length()).is_valid_int()


func _ingest(clip: Dictionary, clips: Array, joints: Array, host: Node = null) -> int:
	var scope: Node = self if host == null else host
	var frame_count := 0
	var surfaces_by_name: Dictionary = clip.get("surfaces", {})
	for node_name in surfaces_by_name.keys():
		var surfaces: Array = surfaces_by_name[node_name]
		frame_count = maxi(frame_count, _bind_part(scope, String(node_name), surfaces, clips))
	var joint_records: Dictionary = clip.get("joints", {})
	for joint_name in joint_records.keys():
		var joint := _find(scope, String(joint_name)) as Node3D
		var record: Dictionary = joint_records[joint_name]
		var frames: Array = record["frames"]
		if joint == null or frames.is_empty():
			continue
		frame_count = maxi(frame_count, frames.size())
		joints.append({
			"node": joint,
			"rest": joint.transform,
			"bind": record["bind"],
			"frames": frames,
		})
	return frame_count


## 250 hands are parented to the wrist joints, and the clips never pose those
## joints. Remember the arm corner that sits on the wrist while it is at rest.
func _anchor_wrists(scope: Node, surfaces: Array) -> void:
	var frames: Array = surfaces[0]["frames"]
	if frames.is_empty():
		return
	for wrist_name in ["def_left_wrist", "def_right_wrist"]:
		var wrist := _find(scope, wrist_name)
		if wrist == null or wrist.has_meta("arm_corner"):
			continue
		var best := 0
		var best_dist := 1000000.0
		var origin := wrist.transform.origin
		for frame in frames:
			var posed: PackedVector3Array = frame
			for index in posed.size():
				var dist := posed[index].distance_squared_to(origin)
				if dist < best_dist:
					best_dist = dist
					best = index
		wrist.set_meta("arm_corner", best)
		wrist.set_meta("bind_rest", wrist.transform)


func _seat_hands(joints: Array) -> void:
	var head: Node3D = null
	for joint in joints:
		var node := _kept_node(joint.get("node"))
		if node != null and String(node.name) == "def_head":
			head = node
	if head == null:
		return
	var body: Node = head
	while body.get_parent() != null and body.get_parent() != self:
		var parent_name := String(body.get_parent().name)
		if parent_name == "1000" or parent_name == "500" or parent_name == "250":
			body = body.get_parent()
			break
		body = body.get_parent()
	var left := _find(body, "def_left_wrist")
	var right := _find(body, "def_right_wrist")
	if left == null and right == null:
		return
	var arms := _find(body, "arms") as MeshInstance3D
	if arms == null or arms.mesh == null or arms.mesh.get_surface_count() == 0:
		return
	var arrays := arms.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return
	for wrist in [left, right]:
		if wrist == null or not wrist.has_meta("arm_corner") or not wrist.has_meta("bind_rest"):
			continue
		var index := int(wrist.get_meta("arm_corner"))
		if index < 0 or index >= vertices.size():
			continue
		var rest: Transform3D = wrist.get_meta("bind_rest")
		rest.origin = vertices[index]
		wrist.transform = rest


func _find(node: Node, wanted: String) -> Node3D:
	if String(node.name) == wanted and node is Node3D:
		return node as Node3D
	for child in node.get_children():
		var found := _find(child, wanted)
		if found:
			return found
	return null
