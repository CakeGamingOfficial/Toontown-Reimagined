extends Node

## DistributedToonHallInterior plus DistributedNPCScientist. Holiday 60 or 116
## replaces the flat meter and the three cards with the live meter and
## Doctor Dimm, Doctor Surlee, and Professor Prepostera. Each phase lasts the
## fallback 604800 seconds. The arrow creeps across its frame range for that
## long. The meter loops at 24 frames a second.

const _HOLIDAYS := preload("res://scenes/shticker/calendar_holidays.gd")
const _AUDIO := preload("res://scenes/audio/toon_audio.gd")
const _METER := "res://assets/interiors/toon_hall/silly_meter.glb"
const _READER := "res://assets/interiors/toon_hall/silly_reader.glb"
const _CLIPBOARD := "res://assets/interiors/toon_hall/clipboard.glb"
const _ANIMS := "res://assets/interiors/toon_hall/anims/"
const _CLOTHES := "res://assets/toons/clothes/"
const _SFX := "res://assets/interiors/toon_hall/audio/"
const _PHASE_SECONDS := 604800.0
const _FLAT := ["SillyMeterFlat", "FlatDuck", "FlatMonkey", "FlatHorse"]

const _PHASES: Array = [
	{"intro0": -1, "intro1": -1, "loop0": 1, "loop1": 30, "meter": "phase_one", "sfx": "PhaseOne", "stages": 0},
	{"intro0": 31, "intro1": 42, "loop0": 42, "loop1": 71, "meter": "phase_one", "sfx": "PhaseOne", "stages": 0},
	{"intro0": -1, "intro1": -1, "loop0": 42, "loop1": 71, "meter": "phase_one", "sfx": "PhaseOne", "stages": 1},
	{"intro0": 72, "intro1": 83, "loop0": 83, "loop1": 112, "meter": "phase_one", "sfx": "PhaseOne", "stages": 1},
	{"intro0": 113, "intro1": 124, "loop0": 124, "loop1": 153, "meter": "phase_one", "sfx": "PhaseOne", "stages": 1},
	{"intro0": 154, "intro1": 165, "loop0": 165, "loop1": 194, "meter": "phase_two", "sfx": "PhaseTwo", "stages": 1},
	{"intro0": 195, "intro1": 206, "loop0": 206, "loop1": 235, "meter": "phase_two", "sfx": "PhaseTwo", "stages": 1},
	{"intro0": 236, "intro1": 247, "loop0": 247, "loop1": 276, "meter": "phase_three", "sfx": "PhaseThree", "stages": 3},
	{"intro0": 277, "intro1": 288, "loop0": 288, "loop1": 317, "meter": "phase_three", "sfx": "PhaseThree", "stages": 3},
	{"intro0": 318, "intro1": 329, "loop0": 329, "loop1": 358, "meter": "phase_three", "sfx": "PhaseThree", "stages": 3},
	{"intro0": 359, "intro1": 370, "loop0": 370, "loop1": 399, "meter": "phase_four", "sfx": "PhaseFour", "stages": 7},
	{"intro0": 400, "intro1": 411, "loop0": 411, "loop1": 440, "meter": "phase_four", "sfx": "PhaseFour", "stages": 7},
	{"intro0": 441, "intro1": 452, "loop0": 452, "loop1": 481, "meter": "phase_four", "sfx": "PhaseFour", "stages": 7},
]

const _PRE: PackedStringArray = [
	"Gadzooks! The Silly Meter has come back to life!",
	"It's rising every day, and will reach the top soon!",
	"When it does, something silly is sure to happen!",
	"So get ready to get ridiculous!",
]
const _TOP: PackedStringArray = [
	"The Silly Meter has hit the top!",
	"Doodles are talking, Estates are bouncy!",
	"There's only one thing to say…",
	"HAPPY APRIL TOONS!",
]
const _EXT: PackedStringArray = [
	"The Silly Meter has hit the top!",
	"Doodles are talking, Estates are bouncy!",
]
const _POST: PackedStringArray = [
	"April Toons is over!",
	"It's time for us to return to our lab.",
	"But when things get REALLY crazy again…",
	"The Silly Meter will return!",
]

var _hall: Node3D
var _meter: Node3D
var _joint_names: PackedStringArray = PackedStringArray()
var _clips: Dictionary = {}
var _clip_counts: Dictionary = {}
var _skins: Array = []
var _arrow: PackedInt32Array = PackedInt32Array()
var _meter_joints: PackedInt32Array = PackedInt32Array()
var _phase := -2
var _age := 0.0
var _intro := true
var _sound: AudioStreamPlayer3D
var _sound_name := ""
var _bodies: Array[StaticBody3D] = []
var _clock := 0


static func attach(hall: Node3D) -> void:
	var node := load("res://scenes/interiors/silly_meter.gd").new() as Node
	node.name = "SillyMeter"
	hall.add_child(node)


func _ready() -> void:
	_hall = get_parent() as Node3D
	_load_meter()
	_place_scientists()
	_apply(_current_phase(), true)


func _process(delta: float) -> void:
	var phase := _current_phase()
	if phase != _phase:
		_apply(phase, true)
	if phase < 0 or _meter == null:
		_tick_scientists(delta)
		return
	_age += delta
	_pose(phase)
	_tick_scientists(delta)


func _current_phase() -> int:
	var holiday := 0
	if _HOLIDAYS.running(60):
		holiday = 60
	elif _HOLIDAYS.running(116):
		holiday = 116
	if holiday == 0:
		_clock = 0
		return -1
	if _clock != holiday:
		_clock = holiday
		var begun := _HOLIDAYS.begun(holiday)
		if begun <= 0.0:
			begun = Time.get_unix_time_from_system()
		set_meta("phase_at", begun)
	var elapsed := Time.get_unix_time_from_system() - float(get_meta("phase_at", 0.0))
	return clampi(int(elapsed / _PHASE_SECONDS), 0, 15)


func _apply(phase: int, restart: bool) -> void:
	if restart:
		_age = 0.0
		_intro = true
		_sound_name = ""
	_phase = phase
	var live := phase >= 0
	if _meter != null:
		_meter.visible = live
	for flat_name in _FLAT:
		var flat := _find(_hall, flat_name)
		if flat != null:
			flat.visible = not live
	for body in _bodies:
		body.visible = live
	if not live:
		_stop_sound()
		return
	_show_stages(phase)
	_start_loop_sound(phase)
	_pose(phase)
	_sync_scientists(true)


func _show_stages(phase: int) -> void:
	var bits := 7
	if phase < _PHASES.size():
		bits = int((_PHASES[phase] as Dictionary).get("stages", 0))
	for index in 3:
		var stage := _find(_meter, "stage%d" % (index + 2))
		if stage != null:
			stage.visible = (bits & (1 << index)) != 0


func _pose(phase: int) -> void:
	if _skins.is_empty() or _joint_names.is_empty():
		return
	var arrow_frame := 0.0
	var meter_frame := 0.0
	var meter_clip := "phase_one"
	var whole := phase >= 13
	var whole_clip := "phase_five"
	if phase == 13 and _intro:
		var intro_frames := 119.0
		if _age * 24.0 < intro_frames:
			whole_clip = "phase_four_to_five"
			arrow_frame = 1.0 + _age * 24.0
		else:
			_intro = false
			_age = 0.0
			_start_loop_sound(phase)
	if not whole:
		var row: Dictionary = _PHASES[phase]
		meter_clip = String(row.get("meter", "phase_one"))
		var intro0 := int(row.get("intro0", -1))
		var intro1 := int(row.get("intro1", -1))
		if _intro and intro0 >= 0:
			var span := float(intro1 - intro0)
			if _age * 24.0 < span:
				arrow_frame = float(intro0) + _age * 24.0
			else:
				_intro = false
				_age = 0.0
				_play_ding()
				_start_loop_sound(phase)
				arrow_frame = float(row.get("loop0", 0))
		if not _intro or intro0 < 0:
			var loop0 := float(row.get("loop0", 0))
			var loop1 := float(row.get("loop1", loop0))
			var across := _age / _PHASE_SECONDS
			arrow_frame = loop0 + clampf(across, 0.0, 1.0) * (loop1 - loop0)
		var meter_count := int(_clip_counts.get(meter_clip, 1))
		meter_frame = fposmod(_age * 24.0, float(maxi(meter_count, 1)))
	else:
		var count := int(_clip_counts.get(whole_clip, 1))
		if whole_clip == "phase_five":
			var across := _age / _PHASE_SECONDS
			arrow_frame = 1.0 + clampf(across, 0.0, 1.0) * 47.0
		else:
			arrow_frame = clampf(arrow_frame, 0.0, float(maxi(count - 1, 0)))
		meter_frame = arrow_frame
		meter_clip = whole_clip
	var arrow_clip := "arrow_tube" if not whole else meter_clip
	_pose_skins(arrow_clip, arrow_frame, meter_clip, meter_frame, whole)


func _start_loop_sound(phase: int) -> void:
	var clip := "PhaseFive"
	if phase == 13 and _intro:
		_play_sound("PhaseFourToFive", false)
		return
	if phase < _PHASES.size():
		clip = String((_PHASES[phase] as Dictionary).get("sfx", "PhaseOne"))
	_play_sound(clip, true)


func _play_sound(clip: String, looping: bool) -> void:
	if _sound_name == clip and _sound != null and _sound.playing:
		return
	_stop_sound()
	var stream := _AUDIO.stream(_SFX + "tt_s_prp_sillyMeter" + clip + ".ogg")
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = looping
	_sound = _AUDIO.effect_3d()
	_sound.stream = stream
	_sound.max_distance = 80.0
	_sound.unit_size = 20.0
	var host: Node = _meter if _meter != null else self
	host.add_child(_sound)
	_sound.play()
	_sound_name = clip


func _play_ding() -> void:
	var stream := _AUDIO.stream(_SFX + "tt_s_prp_sillyMeterArrow.ogg")
	if stream == null:
		return
	var ding := _AUDIO.effect_3d()
	ding.stream = stream
	ding.max_distance = 80.0
	ding.unit_size = 20.0
	var host: Node = _meter if _meter != null else self
	host.add_child(ding)
	ding.finished.connect(ding.queue_free)
	ding.play()


func _stop_sound() -> void:
	if _sound != null:
		_sound.stop()
		_sound.queue_free()
		_sound = null
	_sound_name = ""


func _load_meter() -> void:
	var packed := load(_METER) as PackedScene
	if packed == null:
		return
	_meter = packed.instantiate() as Node3D
	_meter.name = "SillyMeterLive"
	_hall.add_child(_meter)
	_meter.visible = false
	_read_clip(_ANIMS + "arrow_tube.pty", true)
	for clip_name in ["phase_one", "phase_two", "phase_three", "phase_four", "phase_four_to_five", "phase_five"]:
		_read_clip(_ANIMS + clip_name + ".pty", false)
	_sort_joints()


func _sort_joints() -> void:
	for index in _joint_names.size():
		var joint_name := _joint_names[index]
		if _under(joint_name, "uvj_progressBar") or _under(joint_name, "def_springA"):
			_arrow.append(index)
		elif _under(joint_name, "def_pivot"):
			_meter_joints.append(index)


func _under(joint_name: String, ancestor: String) -> bool:
	var node := _find(_meter, joint_name)
	if joint_name == ancestor or joint_name.begins_with(ancestor):
		return true
	while node != null and node != _meter:
		var current := String(node.name)
		if current == ancestor or current.begins_with(ancestor):
			return true
		node = node.get_parent()
	return false


func _read_clip(path: String, keep_skin: bool) -> void:
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var magic := file.get_buffer(8)
	if magic.get_string_from_ascii() != "PTYJNT1":
		file.close()
		return
	var frame_count := file.get_32()
	file.get_float()
	var joint_count := file.get_16()
	file.get_8()
	var names: PackedStringArray = PackedStringArray()
	var frames: Array = []
	for _joint_index in joint_count:
		var name_len := file.get_16()
		names.append(file.get_buffer(name_len).get_string_from_utf8())
		var packed := PackedFloat32Array()
		packed.resize(frame_count * 12)
		for cell in packed.size():
			packed[cell] = file.get_float()
		frames.append(packed)
	if _joint_names.is_empty():
		_joint_names = names
	var ordered: Array = []
	ordered.resize(_joint_names.size())
	for index in _joint_names.size():
		var found := names.find(_joint_names[index])
		if found >= 0:
			ordered[index] = frames[found]
		else:
			var empty := PackedFloat32Array()
			empty.resize(frame_count * 12)
			ordered[index] = empty
	var clip_name := path.get_file().get_basename()
	_clips[clip_name] = ordered
	_clip_counts[clip_name] = frame_count
	if keep_skin:
		_read_skins(file)
	file.close()


func _read_skins(file: FileAccess) -> void:
	var skin_count := file.get_16()
	for _skin_index in skin_count:
		var name_len := file.get_16()
		var mesh_name := file.get_buffer(name_len).get_string_from_utf8()
		var surface_count := file.get_16()
		var mesh := _find(_meter, mesh_name) as MeshInstance3D
		var surfaces: Array = []
		for _surface_index in surface_count:
			var count := file.get_32()
			var lookup := {}
			for _vertex_index in count:
				var point := Vector3(file.get_float(), file.get_float(), file.get_float())
				var joints := Vector4i(file.get_8(), file.get_8(), file.get_8(), file.get_8())
				var weights := Vector4(file.get_float(), file.get_float(), file.get_float(), file.get_float())
				lookup[_position_key(point)] = [joints, weights]
			surfaces.append(lookup)
		if mesh != null and mesh.mesh != null:
			_skins.append({"mesh": mesh, "original": mesh.mesh, "surfaces": surfaces})


func _pose_skins(arrow_clip: String, arrow_frame: float, meter_clip: String, meter_frame: float, whole: bool) -> void:
	var arrow_joints: Array = _clips.get(arrow_clip, [])
	var meter_joints: Array = _clips.get(meter_clip, [])
	if arrow_joints.is_empty():
		return
	var skin: Array[Transform3D] = []
	skin.resize(_joint_names.size())
	for index in _joint_names.size():
		var use_arrow := whole or _arrow.has(index)
		var use_meter := not whole and _meter_joints.has(index)
		var source: Array = arrow_joints
		var sample := 0.0
		var count := 1
		if use_meter and not meter_joints.is_empty():
			source = meter_joints
			sample = meter_frame
			count = int(_clip_counts.get(meter_clip, 1))
		elif use_arrow:
			sample = arrow_frame
			count = int(_clip_counts.get(arrow_clip, 1))
		var packed: PackedFloat32Array = source[index]
		var bind := _transform_at(packed, 0)
		var posed := _sample(packed, sample, count)
		skin[index] = posed * bind.affine_inverse()
	for entry in _skins:
		var mesh := entry["mesh"] as MeshInstance3D
		var original := entry["original"] as Mesh
		var surfaces: Array = entry["surfaces"]
		if mesh == null or original == null:
			continue
		var baked := ArrayMesh.new()
		var count := mini(original.get_surface_count(), surfaces.size())
		for surface_index in count:
			var arrays := original.surface_get_arrays(surface_index)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var lookup: Dictionary = surfaces[surface_index]
			var moved := PackedVector3Array()
			var turned := PackedVector3Array()
			moved.resize(positions.size())
			if not normals.is_empty():
				turned.resize(normals.size())
			for vertex in positions.size():
				var found: Variant = lookup.get(_position_key(positions[vertex]))
				if found == null:
					moved[vertex] = positions[vertex]
					if vertex < turned.size():
						turned[vertex] = normals[vertex]
					continue
				var record: Array = found
				var joints: Vector4i = record[0]
				var weights: Vector4 = record[1]
				var point := Vector3.ZERO
				var normal := Vector3.ZERO
				var base_normal := normals[vertex] if vertex < normals.size() else Vector3.UP
				for slot in 4:
					var weight: float = weights[slot]
					if weight <= 0.0:
						continue
					var joint_index: int = joints[slot]
					if joint_index < 0 or joint_index >= skin.size():
						continue
					var xform := skin[joint_index]
					point += xform * positions[vertex] * weight
					normal += xform.basis * base_normal * weight
				moved[vertex] = point
				if vertex < turned.size():
					turned[vertex] = normal.normalized() if normal.length_squared() > 0.000001 else base_normal
			arrays[Mesh.ARRAY_VERTEX] = moved
			if not turned.is_empty():
				arrays[Mesh.ARRAY_NORMAL] = turned
			baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			baked.surface_set_material(surface_index, original.surface_get_material(surface_index))
		mesh.mesh = baked


func _sample(packed: PackedFloat32Array, sample: float, count: int) -> Transform3D:
	if packed.is_empty() or count <= 0:
		return Transform3D.IDENTITY
	var time := clampf(sample, 0.0, float(count - 1))
	var frame := mini(int(time), count - 1)
	var following := mini(frame + 1, count - 1)
	var blend: float = 0.0 if following == frame else time - float(frame)
	var posed := _transform_at(packed, frame)
	var nxt := _transform_at(packed, following)
	var basis := Basis(
		posed.basis.x.lerp(nxt.basis.x, blend),
		posed.basis.y.lerp(nxt.basis.y, blend),
		posed.basis.z.lerp(nxt.basis.z, blend)
	)
	return Transform3D(basis, posed.origin.lerp(nxt.origin, blend))


func _transform_at(frames: PackedFloat32Array, frame: int) -> Transform3D:
	var start := frame * 12
	if start + 11 >= frames.size():
		return Transform3D.IDENTITY
	var x := Vector3(frames[start], frames[start + 1], frames[start + 2])
	var y := Vector3(frames[start + 3], frames[start + 4], frames[start + 5])
	var z := Vector3(frames[start + 6], frames[start + 7], frames[start + 8])
	var origin := Vector3(frames[start + 9], frames[start + 10], frames[start + 11])
	return Transform3D(Basis(x, y, z), origin)


func _position_key(point: Vector3) -> int:
	var x := int(round(point.x * 64.0))
	var y := int(round(point.y * 64.0))
	var z := int(round(point.z * 64.0))
	return (x & 0x1FFFFF) | ((y & 0x1FFFFF) << 21) | ((z & 0x1FFFFF) << 42)


func _place_scientists() -> void:
	_place_scientist(2018, "Doctor Dimm", 1, ["fll", "ss", "s", "m", 15, 0, 15, 15], "tt_t_chr_shirt_scientistB.png", "tt_t_chr_shorts_scientistC.png", _READER, true)
	_place_scientist(2019, "Doctor Surlee", 2, ["pls", "ls", "l", "m", 9, 0, 9, 9], "tt_t_chr_shirt_scientistA.png", "tt_t_chr_shorts_scientistB.png", _CLIPBOARD, true)
	_place_scientist(2020, "Professor Prepostera", 3, ["hss", "ms", "m", "m", 20, 0, 20, 20], "tt_t_chr_shirt_scientistC.png", "tt_t_chr_shorts_scientistA.png", _CLIPBOARD, false)


func _place_scientist(npc_id: int, npc_name: String, origin_index: int, dna: Array, shirt: String, shorts: String, prop_path: String, hides_prop: bool) -> void:
	var origin := _find(_hall, "npc_origin_%d" % origin_index) as Node3D
	if origin == null:
		return
	var body := StaticBody3D.new()
	body.name = npc_name
	body.set_meta("npc_id", npc_id)
	body.set_meta("hides_prop", hides_prop)
	body.visible = false
	_hall.add_child(body)
	body.global_position = origin.global_position + Vector3(0.0, 0.02, 0.0)
	var actor := ToonActor.new()
	actor.name = npc_name
	body.add_child(actor)
	var style := ToonStyle.new()
	style.first_name = npc_name
	style.head = String(dna[0])
	style.torso = String(dna[1])
	style.legs = String(dna[2])
	style.gender = String(dna[3])
	style.arm_color = int(dna[4])
	style.glove_color = int(dna[5])
	style.leg_color = int(dna[6])
	style.head_color = int(dna[7])
	style.top_color = 27
	style.bot_color = 27
	style.top_map = _CLOTHES + shirt
	style.sleeve_map = _CLOTHES + "tt_t_chr_shirtSleeve_scientist.png"
	style.bottom_map = _CLOTHES + shorts
	actor.show_style(style)
	_face(actor, origin)
	actor.ensure_clip("scientistJealous")
	actor.ensure_clip("scientistWork")
	actor.ensure_clip("scientistGame")
	actor.ensure_clip("scientistEmcee")
	_attach_prop(actor, prop_path)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.6
	shape.height = 3.0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, shape.height * 0.5, 0.0)
	body.add_child(collision)
	var label := Label3D.new()
	label.name = "Speech"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, 3.3, 0.0)
	label.pixel_size = 0.008
	label.font_size = 48
	label.modulate = Color(0, 0, 0, 1)
	label.outline_modulate = Color(1, 1, 1, 1)
	label.outline_size = 10
	label.width = 460.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.visible = false
	body.add_child(label)
	_bodies.append(body)


func _attach_prop(actor: ToonActor, prop_path: String) -> void:
	var packed := load(prop_path) as PackedScene
	var hand := actor.find_child("def_joint_right_hold", true, false) as Node3D
	if packed == null or hand == null:
		return
	var prop := packed.instantiate() as Node3D
	prop.name = "HandProp"
	hand.add_child(prop)
	prop.position = Vector3(0.0, 0.1, 0.0)
	prop.basis = Basis(Vector3.UP, PI)
	var parent_scale := hand.global_basis.get_scale()
	if parent_scale.x > 0.001 and parent_scale.y > 0.001 and parent_scale.z > 0.001:
		prop.scale = Vector3(1.0 / parent_scale.x, 1.0 / parent_scale.y, 1.0 / parent_scale.z)


func _tick_scientists(delta: float) -> void:
	if _phase < 0:
		return
	for body in _bodies:
		if not body.visible:
			continue
		var actor := body.get_node_or_null(String(body.name)) as ToonActor
		if actor == null:
			continue
		var npc_id := int(body.get_meta("npc_id", 0))
		var clip := _scientist_clip(npc_id, _phase)
		if clip == "scientistWork:less":
			var span := (619.0 - 319.0) / 24.0
			var into := fposmod(_age, span)
			actor.pose_action("scientistWork", 319.0 / 24.0 + into)
		elif String(body.get_meta("clip", "")) != clip:
			actor.release_pose()
			actor.play_gesture(clip, 1.0, true)
			body.set_meta("clip", clip)
		var prop := actor.find_child("HandProp", true, false) as Node3D
		if prop != null:
			var hide := bool(body.get_meta("hides_prop", false)) and _phase >= 13
			prop.visible = not hide
		if npc_id == 2020:
			_say(body, delta)


func _sync_scientists(restart: bool) -> void:
	if not restart:
		return
	for body in _bodies:
		body.set_meta("clip", "")
		body.set_meta("line", -1)
		body.set_meta("line_left", 0.0)
		body.set_meta("pausing", false)


func _scientist_clip(npc_id: int, phase: int) -> String:
	if npc_id == 2020:
		return "scientistEmcee"
	if phase <= 6:
		return "scientistJealous"
	if phase <= 11:
		return "scientistWork"
	if phase <= 12:
		return "scientistWork:less"
	return "scientistGame"


func _say(body: StaticBody3D, delta: float) -> void:
	var label := body.get_node_or_null("Speech") as Label3D
	if label == null:
		return
	var lines := _professor_lines()
	if lines.is_empty():
		label.visible = false
		return
	var index := int(body.get_meta("line", -1))
	var left := float(body.get_meta("line_left", 0.0)) - delta
	var pausing := bool(body.get_meta("pausing", false))
	if index < 0:
		index = 0
		left = 4.5
		pausing = false
		label.text = lines[0]
		label.visible = true
	elif left > 0.0:
		pass
	elif pausing:
		index = 0
		left = 4.5
		pausing = false
		label.text = lines[0]
		label.visible = true
	else:
		index += 1
		if index >= lines.size():
			pausing = true
			left = 30.0
			label.visible = false
		else:
			left = 4.5
			label.text = lines[index]
			label.visible = true
	body.set_meta("line", index)
	body.set_meta("line_left", left)
	body.set_meta("pausing", pausing)


func _professor_lines() -> PackedStringArray:
	if _phase <= 11:
		return _PRE
	if _HOLIDAYS.running(116):
		return _EXT
	if _phase == 12:
		return _TOP
	return _POST


func _face(actor: Node3D, origin: Node3D) -> void:
	var ahead := origin.to_global(Vector3(0.0, -1.0, 0.0)) - origin.global_position
	ahead.y = 0.0
	var heading := 0.0
	if ahead.length_squared() > 0.0001:
		heading = rad_to_deg(atan2(-ahead.x, -ahead.z))
	var body_scale := actor.transform.basis.get_scale().x
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	upright = upright.rotated(Vector3.UP, deg_to_rad(heading))
	actor.transform.basis = upright.scaled(Vector3.ONE * body_scale)


func _find(node: Node, wanted: String) -> Node:
	if node == null:
		return null
	if String(node.name) == wanted:
		return node
	for child in node.get_children():
		var found := _find(child, wanted)
		if found != null:
			return found
	return null
