class_name ToonActor
extends Node3D

## Legs, torso, and head from the original 1000-LOD models, posed in neutral
## and assembled the way Toon.parentToonParts does: torso on joint_hips,
## head on def_head. The parts are still Z-up, so this node stands them up.

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

## World NPCs fall onto collision the way the player does. The player's own
## toon stays off, because his CharacterBody already carries him.
var follows_ground := false
## Make a Toon only plays neutral. The run, jump, and gag clips are large, and
## reading them again on every option change freezes that idle.
var load_extra_clips := true
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
var _clip := ""
var _jump_kind := ""
var _land_kind := ""
var _land_left := 0.0
var _cycle_time := {"walk": 0.0, "run": 0.0, "jump": 0.0, "rjump": 0.0, "land": 0.0, "rland": 0.0}
var _extra := {}
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
var _blink_wait := 1.0
var _look_wait := 2.0
var _look_enabled := true
var _gesture := ""
var _gesture_rate := 1.0
var _gesture_loop := true
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
	_clip = ""
	_jump_kind = ""
	_land_kind = ""
	_land_left = 0.0
	_cycle_time = {"walk": 0.0, "run": 0.0, "jump": 0.0, "rjump": 0.0, "land": 0.0, "rland": 0.0}
	_extra = {}
	_gesture = ""
	_mood = "normal"
	_mood_open = null
	_mood_closed = null
	_look_enabled = true
	_idle_time = 0.0
	_frame_count = 0
	_idle_frames = 0
	_look = null
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
	var legs := _instance(_PARTS + "legs_%s.glb" % style.legs)
	if legs == null:
		return
	add_child(legs)
	var hips := _find(legs, "joint_hips")
	var torso := _instance(_PARTS + "torso_%s.glb" % style.torso)
	if torso and hips:
		hips.add_child(torso)
		var neck := _find(torso, "def_head")
		var head := _instance(_HEADS + "%s.glb" % style.head)
		if head and neck:
			# Look-around turns this pivot. The head model keeps its own transform.
			var look := Node3D.new()
			look.name = "head_look"
			neck.add_child(look)
			look.add_child(head)
			_look = look
	_paint(self, style)
	_unify_forehead(self)
	_prepare_face()
	_add_shadow()


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


func set_locomotion(forward_speed: float, turning: bool, jumping: bool, delta: float) -> void:
	if _style == null:
		return
	# The face tick plays dog ears on its own unless locomotion just posed them.
	_locomotion_msec = Time.get_ticks_msec()
	_ensure_clips()
	_look_enabled = _gesture == ""
	if _gesture != "":
		_play_bank(_gesture, _gesture_rate, delta, _gesture_loop)
		return
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
	if _look:
		_look.rotation = Vector3.ZERO


func clear_gesture() -> void:
	_gesture = ""
	_look_enabled = true


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
	_mood = mood
	_mood_open = _expression_texture(mood, false)
	_mood_closed = _expression_texture(mood, true)
	if mood == "normal":
		_eyes_shut = false
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
	for suffix in ["run", "jump", "rjump", "land", "rland", "talk", "rhand", "rstart", "rpoint", "pstart", "throw", "pushbutton", "conked", "cringe", "sidestep-left", "sidestep-right", "duck", "victory", "teleport", "leap", "bank"]:
		if not _extra.has(suffix):
			var clips: Array = []
			var joints: Array = []
			var frames := _load_clip(suffix, clips, joints)
			_extra[suffix] = {"clips": clips, "joints": joints, "frames": frames}


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
	_ensure_clips()
	var bank: Dictionary = _extra.get(suffix, {})
	var frames := int(bank.get("frames", 0))
	if frames <= 1:
		return 0.0
	return float(frames - 1) / 24.0


func pose_action(suffix: String, elapsed: float) -> void:
	# A held pose owns the ears too. The idle flop would replace them after a tenth of a second.
	_locomotion_msec = Time.get_ticks_msec()
	_ensure_clips()
	var bank: Dictionary = _extra.get(suffix, {})
	var frames := int(bank.get("frames", 0))
	var clips: Array = bank.get("clips", [])
	if frames <= 1 or clips.is_empty():
		return
	var time := clampf(elapsed * 24.0, 0.0, float(frames - 1))
	var frame := mini(int(time), frames - 1)
	var following := mini(frame + 1, frames - 1)
	var blend := 0.0 if following == frame else time - float(frame)
	_posing = true
	_clip = suffix
	_pose_clip(clips, bank["joints"], frame, following, blend)


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
	_pose_clip(_idle_clips, _idle_joints, frame, following, _idle_time - float(frame))


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
	var blend := 0.0 if following == frame else time - float(frame)
	_pose_clip(clips, joints, frame, following, blend)


func _load_walk() -> void:
	_frame_count = _load_clip("walk", _walk_clips, _walk_joints)
	_walk_loaded = _frame_count > 0 and not _walk_clips.is_empty()


func _load_idle() -> void:
	_idle_frames = _load_clip("idle", _idle_clips, _idle_joints)
	_idle_loaded = _idle_frames > 0 and not _idle_clips.is_empty()


func _load_clip(suffix: String, clips: Array, joints: Array) -> int:
	var frame_count := 0
	var files := [
		_read_walk(_ANIMS + "legs_%s.%s" % [_style.legs, suffix]),
		_read_walk(_ANIMS + "torso_%s.%s" % [_style.torso, suffix]),
		_read_walk(_ANIMS + "%s.%s" % [_style.head, suffix]),
	]
	for clip in files:
		var surfaces_by_name: Dictionary = clip.get("surfaces", {})
		for node_name in surfaces_by_name.keys():
			var instance := _find(self, String(node_name)) as MeshInstance3D
			if instance == null or instance.mesh == null:
				continue
			var surfaces: Array = surfaces_by_name[node_name]
			if surfaces.is_empty():
				continue
			frame_count = maxi(frame_count, (surfaces[0]["frames"] as Array).size())
			clips.append({
				"instance": instance,
				"original": instance.mesh,
				"surfaces": surfaces,
			})
		var joint_records: Dictionary = clip.get("joints", {})
		for joint_name in joint_records.keys():
			var joint := _find(self, String(joint_name)) as Node3D
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


func _pose_clip(clips: Array, joints: Array, frame: int, following: int, blend: float) -> void:
	var posed_head := false
	for clip in clips:
		var instance := clip["instance"] as MeshInstance3D
		if not is_instance_valid(instance):
			continue
		var original := clip["original"] as Mesh
		var surfaces: Array = clip["surfaces"]
		var posed := ArrayMesh.new()
		for surface_index in surfaces.size():
			var surface: Dictionary = surfaces[surface_index]
			var frames: Array = surface["frames"]
			if frames.is_empty():
				continue
			var count := frames.size()
			var used := frame % count
			var next_frame := following % count
			var positions: PackedVector3Array = frames[used]
			if blend > 0.001:
				var nxt: PackedVector3Array = frames[next_frame]
				var mixed := PackedVector3Array()
				mixed.resize(positions.size())
				for index in positions.size():
					mixed[index] = positions[index].lerp(nxt[index], blend)
				positions = mixed
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = positions
			var part := String(instance.name)
			if part.begins_with("ears"):
				arrays[Mesh.ARRAY_NORMAL] = _smooth_normals(positions, true)
			elif part.begins_with("head"):
				arrays[Mesh.ARRAY_NORMAL] = _smooth_normals(positions)
				posed_head = true
			else:
				arrays[Mesh.ARRAY_NORMAL] = _smooth_normals(positions)
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
		instance.mesh = posed
	if posed_head:
		_unify_forehead(self)
	for joint in joints:
		var node := joint["node"] as Node3D
		if not is_instance_valid(node):
			continue
		var frames: Array = joint["frames"]
		if frames.is_empty():
			continue
		var count := frames.size()
		node.transform = _joint_pose(joint, frame % count, following % count, blend)


func _joint_pose(joint: Dictionary, frame: int, following: int, blend: float) -> Transform3D:
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


func _restore_posed_meshes() -> void:
	_restore_clip(_walk_clips, _walk_joints)
	_restore_clip(_idle_clips, _idle_joints)
	for bank in _extra.values():
		_restore_clip(bank["clips"], bank["joints"])


func _restore_clip(clips: Array, joints: Array) -> void:
	for clip in clips:
		var instance := clip["instance"] as MeshInstance3D
		if is_instance_valid(instance):
			instance.mesh = clip["original"]
	for joint in joints:
		var node := joint["node"] as Node3D
		if is_instance_valid(node):
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
func _add_shadow() -> void:
	var joint := _find(self, "joint_shadow")
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
				color = ToonStyle.fur_color(_style.arm_color)
				paint = true
			elif part == "legs" or part == "feet":
				color = ToonStyle.fur_color(_style.leg_color)
				paint = true
			elif part.begins_with("ears"):
				color = Color.BLACK if _style.species() == "d" else ToonStyle.fur_color(_style.head_color)
				paint = true
			elif part.begins_with("head"):
				color = ToonStyle.fur_color(_style.head_color)
				paint = true
			elif part == "torso-top":
				color = ToonStyle.clothes_color(_style.top_color)
				texture = _SHIRT[clampi(_style.top_tex, 0, _SHIRT.size() - 1)]
				paint = true
			elif part == "sleeves":
				color = ToonStyle.clothes_color(_style.top_color)
				texture = _SLEEVE[clampi(_style.top_tex, 0, _SLEEVE.size() - 1)]
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
	if part == "hands":
		color = ToonStyle.fur_color(style.glove_color)
	elif part == "arms" or part == "neck":
		color = ToonStyle.fur_color(style.arm_color)
	elif part == "legs" or part == "feet":
		color = ToonStyle.fur_color(style.leg_color)
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
		color = Color.BLACK if style.species() == "d" else ToonStyle.fur_color(style.head_color)
	elif part.begins_with("head"):
		color = ToonStyle.fur_color(style.head_color)
	elif part == "torso-top":
		color = ToonStyle.clothes_color(style.top_color)
		texture = _SHIRT[clampi(style.top_tex, 0, _SHIRT.size() - 1)]
	elif part == "sleeves":
		color = ToonStyle.clothes_color(style.top_color)
		texture = _SLEEVE[clampi(style.top_tex, 0, _SLEEVE.size() - 1)]
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
	mesh.material_override = _body_material(texture, color, shell)


func _bottom_texture(style: ToonStyle) -> Texture2D:
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
	# gap. A depth bias keeps whites, then pupils, then lashes in front without
	# moving the mesh. They stay in the opaque pass (alpha scissor). Alpha
	# blending sorted those cards behind the head and left holes in the face.
	var scissor := 0.0
	var push := 0.0
	var bias := 0.0
	match kind:
		"muzzle":
			push = 0.001
		"nose":
			push = 0.0015
		"eyes":
			scissor = 0.5
			bias = 0.000008
		"pupil":
			scissor = 0.5
			bias = 0.000016
		"lashes":
			scissor = 0.5
			bias = 0.000024
	mesh.material_override = null
	for surface in source.get_surface_count():
		var texture: Texture2D = null
		var color := Color.WHITE
		if kind == "front":
			color = ToonStyle.fur_color(style.head_color)
		else:
			var material := source.surface_get_material(surface)
			if material is BaseMaterial3D:
				var standard := material as BaseMaterial3D
				texture = standard.albedo_texture
				color = standard.albedo_color
		mesh.set_surface_override_material(surface, _face_material(texture, color, scissor, push, bias))


func _face_material(texture: Texture2D, color: Color, scissor: float, push: float, bias: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://scenes/toons/toon_face.gdshader")
	material.set_shader_parameter("albedo_color", color)
	material.set_shader_parameter("scissor_threshold", scissor)
	material.set_shader_parameter("surface_push", push)
	material.set_shader_parameter("depth_bias", bias)
	material.set_shader_parameter("use_albedo_texture", 1.0 if texture else 0.0)
	if texture:
		material.set_shader_parameter("albedo_texture", texture)
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


func _body_material(texture: Texture2D, color: Color, shell: float, gloss: float = 0.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://scenes/toons/toon_body.gdshader")
	material.set_shader_parameter("albedo_color", color)
	material.set_shader_parameter("shell", shell)
	material.set_shader_parameter("gloss", gloss)
	material.set_shader_parameter("use_albedo_texture", 1.0 if texture else 0.0)
	if texture:
		material.set_shader_parameter("albedo_texture", texture)
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
	_tick_blink(delta)
	_tick_look(delta)
	# Pick a Toon only shows the head, so it never asks for locomotion.
	# Dogs still loop neutral there so the ears keep flopping.
	if Time.get_ticks_msec() - _locomotion_msec > 100 and _style.species() == "d":
		_tick_dog_ears(delta)


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
			var material := mesh.get_surface_override_material(0) as ShaderMaterial
			var open_texture: Texture2D = null
			if material:
				open_texture = material.get_shader_parameter("albedo_texture")
			_eyes.append({"material": material, "open": open_texture})
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
		if _blink_left > 0.0:
			return
		_eyes_shut = false
		_apply_eyes()
		_blink_wait = 0.2 if randf() < 0.1 else randf() * 4.0 + 1.0
		return
	_blink_wait -= delta
	if _blink_wait <= 0.0:
		_shut_eyes()


func _shut_eyes() -> void:
	_eyes_shut = true
	_blink_left = 0.125
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
	var closed := _mood_closed if _mood_closed else _load_closed_eyes()
	for eye in _eyes:
		var material := eye["material"] as ShaderMaterial
		if material == null:
			continue
		var open: Texture2D = _mood_open if _mood_open else eye["open"]
		var texture: Texture2D = closed if _eyes_shut and closed else open
		if texture:
			material.set_shader_parameter("albedo_texture", texture)
			material.set_shader_parameter("use_albedo_texture", 1.0)
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
	_look.basis = Basis(Vector3(0, 0, 1), _heading) * Basis(Vector3(1, 0, 0), _pitch)
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
	_shut_eyes()


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


func _tick_dog_ears(delta: float) -> void:
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


func _ingest(clip: Dictionary, clips: Array, joints: Array) -> int:
	var frame_count := 0
	var surfaces_by_name: Dictionary = clip.get("surfaces", {})
	for node_name in surfaces_by_name.keys():
		var instance := _find(self, String(node_name)) as MeshInstance3D
		if instance == null or instance.mesh == null:
			continue
		var surfaces: Array = surfaces_by_name[node_name]
		if surfaces.is_empty():
			continue
		frame_count = maxi(frame_count, (surfaces[0]["frames"] as Array).size())
		clips.append({
			"instance": instance,
			"original": instance.mesh,
			"surfaces": surfaces,
		})
	var joint_records: Dictionary = clip.get("joints", {})
	for joint_name in joint_records.keys():
		var joint := _find(self, String(joint_name)) as Node3D
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


func _find(node: Node, wanted: String) -> Node3D:
	if String(node.name) == wanted and node is Node3D:
		return node as Node3D
	for child in node.get_children():
		var found := _find(child, wanted)
		if found:
			return found
	return null
