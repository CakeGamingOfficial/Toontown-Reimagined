class_name GagMovie
extends Node

## MovieThrow, MovieSquirt, MovieDrop, MovieTrap, MovieLure, MovieSound, and
## MovieHeal for a street battle. Props are the exported battle models. The
## toon and the cog play the original clip for that gag.

const _PROPS := "res://assets/battle/props/"
const _SFX := "res://assets/audio/battle/"
const _HEIGHT := 4.88
const _GAGS: Array = [
	["feather", "megaphone", "lipstick", "cane", "cubes", "cubes", "ladder"],
	["banana", "rake", "marbles", "quicksand", "trapdoor", "tnt", "traintrack"],
	["1dollar", "magnet", "1dollar", "magnet", "1dollar", "hypno-goggles", "slideshow"],
	["bikehorn", "whistle", "bugle", "aoogah", "elephant", "fog_horn", "singing"],
	["tart", "fruitpie-slice", "creampie-slice", "fruitpie", "creampie", "birthday-cake", "wedding-cake"],
	["squirting-flower", "glass", "water-gun", "bottle", "firehose", "stormcloud", "geyser"],
	["flowerpot", "sandbag", "anvil", "weight", "safe", "piano", "ship"],
]
const _HEAL_SFX: PackedStringArray = [
	"AA_heal_tickle.ogg", "AA_heal_telljoke.ogg", "AA_heal_smooch.ogg", "AA_heal_happydance.ogg",
	"AA_heal_pixiedust.ogg", "AA_heal_juggle.ogg", "AA_heal_High_Dive.ogg",
]
const _TRAP_SFX: PackedStringArray = [
	"TL_banana.ogg", "TL_rake_throw_only.ogg", "TL_marbles.ogg", "TL_quicksand.ogg",
	"TL_trap_door.ogg", "TL_dynamite.ogg", "TL_train_track_appear.ogg",
]
const _SOUND_SFX: PackedStringArray = [
	"AA_sound_bikehorn.ogg", "AA_sound_whistle.ogg", "AA_sound_bugle.ogg", "AA_sound_aoogah.ogg",
	"AA_sound_elephant.ogg", "SZ_DD_foghorn.ogg", "AA_sound_Opera_Singer.ogg",
]
const _SQUIRT_HIT: PackedStringArray = [
	"AA_squirt_flowersquirt.ogg", "AA_squirt_glasswater.ogg", "AA_squirt_neonwatergun.ogg", "AA_squirt_seltzer.ogg",
	"firehose_spray.ogg", "AA_throw_stormcloud.ogg", "AA_squirt_Geyser.ogg",
]
const _SQUIRT_MISS: PackedStringArray = [
	"AA_squirt_flowersquirt_miss.ogg", "AA_squirt_glasswater_miss.ogg", "AA_squirt_neonwatergun_miss.ogg", "AA_squirt_seltzer_miss.ogg",
	"firehose_spray.ogg", "AA_throw_stormcloud_miss.ogg", "AA_squirt_Geyser.ogg",
]
const _DROP_HIT: PackedStringArray = [
	"AA_drop_flowerpot.ogg", "AA_drop_sandbag.ogg", "AA_drop_anvil.ogg", "AA_drop_bigweight.ogg",
	"AA_drop_safe.ogg", "AA_drop_piano.ogg", "AA_drop_boat.ogg",
]
const _DROP_MISS: PackedStringArray = [
	"AA_drop_flowerpot_miss.ogg", "AA_drop_sandbag_miss.ogg", "AA_drop_anvil_miss.ogg", "AA_drop_bigweight_miss.ogg",
	"AA_drop_safe_miss.ogg", "AA_drop_piano_miss.ogg", "AA_drop_boat_miss.ogg",
]

var _spawned: Array[Node] = []
var _traps: Dictionary = {}
var _fired: Dictionary = {}
var _attach: Dictionary = {}


func _ready() -> void:
	var path := _PROPS + "attachments.json"
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		_attach = parsed


func clear_traps() -> void:
	for key in _traps.keys():
		var record: Dictionary = _traps[key]
		var node: Node = record.get("node")
		if node != null and is_instance_valid(node):
			node.queue_free()
	_traps.clear()
	_clear_spawned()


func play(beats: Array, actor_of: Callable, cog_of: Callable, still: Callable, contact: Callable) -> void:
	_fired.clear()
	if beats.is_empty():
		return
	var lead: Dictionary = beats[0]
	var kind := String(lead.get("kind", ""))
	var track := int(lead.get("track", -1))
	var level := int(lead.get("level", 0))
	var actor: ToonActor = actor_of.call(int(lead.get("toon", 0)))
	var marks := _marks(beats, cog_of)
	if kind == "cog":
		await _suit(lead, actor, marks, still, contact)
	elif kind == "gag" and actor != null and track == 4:
		await _throw(actor, _prop_name(track, level), level, marks, still, contact)
	elif kind == "gag" and actor != null and track == 5 and level == 0:
		await _flower(actor, marks, still, contact)
	elif kind == "gag" and actor != null and track == 5 and level >= 5:
		await _sky_squirt(actor, _prop_name(track, level), level, marks, still, contact)
	elif kind == "gag" and actor != null and track == 5:
		await _squirt(actor, _prop_name(track, level), level, marks, still, contact)
	elif kind == "gag" and actor != null and track == 6:
		await _drop(actor, _prop_name(track, level), level, marks, still, contact)
	elif kind == "gag" and actor != null and track == 1:
		await _trap(actor, _prop_name(track, level), level, marks, still, contact)
	elif kind == "gag" and actor != null and track == 2:
		await _lure(actor, _prop_name(track, level), level, marks, still, contact)
	elif kind == "gag" and actor != null and track == 3:
		await _sound(actor, _prop_name(track, level), level, marks, still, contact)
	elif kind == "gag" and actor != null and track == 0:
		await _heal(actor, _prop_name(track, level), level, beats, actor_of, still, contact)
	else:
		await _wait(1.2, still)
		if still.call():
			contact.call()
	_clear_spawned()
	_rest(actor, marks)


func _marks(beats: Array, cog_of: Callable) -> Array:
	var marks: Array = []
	for item in beats:
		if not (item is Dictionary):
			continue
		var beat: Dictionary = item
		var cog_id := int(beat.get("cog", 0))
		var cog: Node = cog_of.call(cog_id)
		marks.append({
			"cog": cog,
			"id": cog_id,
			"hit": bool(beat.get("hit", false)),
			"hp": int(beat.get("cog_hp", 1)),
		})
	return marks


func _throw(actor: ToonActor, pie_name: String, level: int, marks: Array, still: Callable, contact: Callable) -> void:
	var pie := _make(pie_name)
	_hand(pie, actor, "def_joint_right_hold")
	var aim := _first_cog(marks)
	var hit := _any_hit(marks)
	var gate := {}
	await _run(4.8, still, func(elapsed: float) -> void:
		actor.pose_action("throw", elapsed)
		if elapsed < 2.7:
			pie.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf(elapsed, 0.0, 1.0))
		else:
			_fly(pie, aim, _HEIGHT if hit else _HEIGHT * 0.4, elapsed, 2.7, 0.3 if hit else 0.5, not hit)
		if hit and elapsed >= 3.0 and not pie.has_meta("splat"):
			pie.visible = false
			var splat := _make("splat")
			_tint(splat, _splat_color(pie_name))
			splat.scale = Vector3.ONE * _splat_scale(pie_name)
			if aim != null:
				splat.global_position = aim.global_position + Vector3(0.0, _HEIGHT, 0.0)
			pie.set_meta("splat", splat)
		if pie.has_meta("splat"):
			_face_camera(pie.get_meta("splat") as Node3D)
		_react_marks(marks, elapsed, 3.0 if hit else 2.45, "pie-small")
		_once("throw", elapsed, 2.6, "AA_pie_throw_only.ogg")
		if hit:
			_once("pie", elapsed, 2.7, _pie_hit(level))
		if elapsed >= 3.0 and _latch(gate, "hit"):
			contact.call()
	)
	actor.end_action("throw")


func _flower(actor: ToonActor, marks: Array, still: Callable, contact: Callable) -> void:
	var button := _make("button")
	_hand(button, actor, "def_joint_left_hold")
	button.scale = Vector3.ONE
	var flower := _make("squirting-flower")
	var joint := _joint(actor, "def_joint_attachFlower")
	if joint != null:
		flower.reparent(joint, false)
	flower.visible = false
	var spray := _make("spray")
	spray.visible = false
	_tint(spray, Color(0.75, 0.75, 1.0, 0.8))
	var aim := _first_cog(marks)
	var hit := _any_hit(marks)
	var gate := {}
	await _run(3.6, still, func(elapsed: float) -> void:
		actor.pose_action("pushbutton", elapsed)
		if elapsed >= 1.0:
			flower.visible = true
			var grown := clampf((elapsed - 1.0) / 0.5, 0.0, 1.0)
			var size := lerpf(0.01, 1.5, grown)
			if elapsed >= 2.5 and elapsed <= 2.8:
				size = 1.5
			elif elapsed > 2.8:
				size = lerpf(1.5, 0.01, clampf((elapsed - 2.8) / 0.5, 0.0, 1.0))
			flower.scale = Vector3.ONE * size
		if elapsed >= 2.5 and elapsed < 3.1 and aim != null:
			spray.visible = true
			_spray(spray, flower.global_position, aim.global_position + Vector3(0.0, _HEIGHT * 0.66, 0.0))
		else:
			spray.visible = false
		_react_marks(marks, elapsed, 2.7, "squirt-small")
		_once("squirt", elapsed, 2.1, "AA_squirt_flowersquirt.ogg" if hit else "AA_squirt_flowersquirt_miss.ogg")
		if elapsed >= 2.7 and _latch(gate, "hit"):
			contact.call()
	)
	actor.end_action("pushbutton")


func _squirt(actor: ToonActor, prop_name: String, level: int, marks: Array, still: Callable, contact: Callable) -> void:
	var prop := _make(prop_name)
	_hand(prop, actor, "def_joint_right_hold")
	var spray := _make("spray")
	spray.visible = false
	_tint(spray, Color(0.75, 0.75, 1.0, 0.8))
	var aim := _first_cog(marks)
	var hit := _any_hit(marks)
	var gate := {}
	await _run(3.4, still, func(elapsed: float) -> void:
		actor.pose_action("pushbutton", elapsed)
		prop.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf(elapsed / 0.4, 0.0, 1.0))
		if elapsed >= 1.6 and elapsed < 2.8 and aim != null:
			spray.visible = true
			_spray(spray, prop.global_position, aim.global_position + Vector3(0.0, _HEIGHT * 0.66, 0.0))
		else:
			spray.visible = false
		_react_marks(marks, elapsed, 2.5, "squirt-small")
		_once("squirt", elapsed, 1.6, _SQUIRT_HIT[level] if hit else _SQUIRT_MISS[level])
		if elapsed >= 2.5 and _latch(gate, "hit"):
			contact.call()
	)
	actor.end_action("pushbutton")


func _sky_squirt(actor: ToonActor, prop_name: String, level: int, marks: Array, still: Callable, contact: Callable) -> void:
	var aim := _first_cog(marks)
	var prop := _make(prop_name)
	prop.visible = false
	if aim != null:
		prop.global_position = aim.global_position + Vector3(0.0, _HEIGHT + 6.0, 0.0)
	var hit := _any_hit(marks)
	var gate := {}
	await _run(4.2, still, func(elapsed: float) -> void:
		actor.pose_action("pushbutton", elapsed)
		if elapsed >= 1.2:
			prop.visible = true
			prop.scale = Vector3.ONE * lerpf(0.2, 1.4, clampf((elapsed - 1.2) / 0.6, 0.0, 1.0))
		_react_marks(marks, elapsed, 2.2, "soak" if level >= 6 else "squirt-small")
		_once("sky", elapsed, 1.4, _SQUIRT_HIT[level] if hit else _SQUIRT_MISS[level])
		if elapsed >= 2.2 and _latch(gate, "hit"):
			contact.call()
	)
	actor.end_action("pushbutton")


func _drop(actor: ToonActor, prop_name: String, level: int, marks: Array, still: Callable, contact: Callable) -> void:
	var button := _make("button")
	_hand(button, actor, "def_joint_left_hold")
	button.scale = Vector3.ONE
	var props: Array[Node3D] = []
	for mark in marks:
		var falling := _make(prop_name)
		falling.visible = false
		props.append(falling)
	var hit := _any_hit(marks)
	var gate := {}
	await _run(5.6, still, func(elapsed: float) -> void:
		actor.pose_action("pushbutton", elapsed)
		if elapsed >= 2.2 and _latch(gate, "box"):
			_sfx("AA_drop_trigger_box.ogg")
		for index in props.size():
			var falling := props[index]
			var mark: Dictionary = marks[index]
			var cog: Node3D = mark.get("cog")
			if cog == null or elapsed < 4.3:
				continue
			falling.visible = true
			var fallen := clampf((elapsed - 4.3) / 0.6, 0.0, 1.0)
			var above := cog.global_position + Vector3(0.0, _HEIGHT + 14.0, 0.0)
			var rest := cog.global_position + Vector3(0.0, 1.2, 0.0)
			if not bool(mark.get("hit", false)):
				rest += _aside(actor, cog) * 2.4
			falling.global_position = above.lerp(rest, fallen)
			falling.scale = Vector3.ONE
		_react_marks(marks, elapsed, 4.9, "drop-react")
		if elapsed >= 4.9 and _latch(gate, "land"):
			_sfx(_DROP_HIT[level] if hit else _DROP_MISS[level])
			contact.call()
	)
	actor.end_action("pushbutton")


func _trap(actor: ToonActor, prop_name: String, level: int, marks: Array, still: Callable, contact: Callable) -> void:
	var props: Array[Node3D] = []
	for _mark in marks:
		var prop := _make(prop_name)
		_hand(prop, actor, "def_joint_right_hold")
		props.append(prop)
	var gate := {}
	await _run(3.6, still, func(elapsed: float) -> void:
		actor.pose_action("throw", elapsed)
		for index in props.size():
			var prop := props[index]
			var mark: Dictionary = marks[index]
			var cog: Node3D = mark.get("cog")
			if elapsed < 2.7:
				prop.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf(elapsed, 0.0, 1.0))
			elif cog != null:
				_fly(prop, cog, 0.25, elapsed, 2.7, 0.3, false)
		_once("trap", elapsed, 0.2, _TRAP_SFX[level] if level < _TRAP_SFX.size() else "TL_banana.ogg")
		if elapsed >= 3.1 and _latch(gate, "hit"):
			contact.call()
	)
	for index in props.size():
		var mark: Dictionary = marks[index]
		var cog: Node3D = mark.get("cog")
		if cog != null:
			_plant(cog, props[index], int(mark.get("id", 0)), _TRAP_SFX[level] if level < _TRAP_SFX.size() else "TL_banana.ogg")
	actor.end_action("throw")


func _lure(actor: ToonActor, prop_name: String, level: int, marks: Array, still: Callable, contact: Callable) -> void:
	var prop := _make(prop_name)
	_hand(prop, actor, "def_joint_right_hold")
	var clip := "throw" if level != 5 else "pushbutton"
	var gate := {}
	await _run(3.8, still, func(elapsed: float) -> void:
		actor.pose_action(clip, elapsed)
		prop.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf(elapsed / 0.4, 0.0, 1.0))
		if level == 0 or level == 2 or level == 4:
			var aim := _first_cog(marks)
			if elapsed >= 2.2 and aim != null:
				_fly(prop, aim, _HEIGHT * 0.5, elapsed, 2.2, 0.4, not _any_hit(marks))
		_react_marks(marks, elapsed, 2.6, "hypnotized")
		_once("lure", elapsed, 2.0, "AA_pie_throw_only.ogg")
		if elapsed >= 2.6 and _latch(gate, "hit"):
			for mark in marks:
				var row: Dictionary = mark
				if not bool(row.get("hit", false)):
					continue
				if _spring(int(row.get("id", 0))):
					_react_one(row.get("cog"), "rake-react", 0.0)
			contact.call()
	)
	actor.end_action(clip)


func _sound(actor: ToonActor, prop_name: String, level: int, marks: Array, still: Callable, contact: Callable) -> void:
	var prop := _make(prop_name)
	_hand(prop, actor, "def_joint_right_hold")
	var gate := {}
	await _run(3.4, still, func(elapsed: float) -> void:
		actor.pose_action("pushbutton", elapsed)
		prop.scale = Vector3.ONE * lerpf(0.01, 1.2, clampf(elapsed / 0.35, 0.0, 1.0))
		_react_marks(marks, elapsed, 1.6, "flatten")
		_once("sound", elapsed, 0.6, _SOUND_SFX[level] if level < _SOUND_SFX.size() else "AA_sound_bikehorn.ogg")
		if level >= 6 and _any_hit(marks):
			_once("glass", elapsed, 1.6, "AA_sound_Opera_Singer_Cog_Glass.ogg")
		if elapsed >= 1.6 and _latch(gate, "hit"):
			contact.call()
	)
	actor.end_action("pushbutton")


func _heal(actor: ToonActor, prop_name: String, level: int, beats: Array, actor_of: Callable, still: Callable, contact: Callable) -> void:
	var prop := _make(prop_name)
	_hand(prop, actor, "def_joint_right_hold")
	var gate := {}
	await _run(3.0, still, func(elapsed: float) -> void:
		actor.pose_action("throw" if level < 6 else "pushbutton", elapsed)
		prop.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf(elapsed / 0.4, 0.0, 1.0))
		if elapsed >= 1.4 and _latch(gate, "spark"):
			for item in beats:
				if not (item is Dictionary) or not bool((item as Dictionary).get("hit", false)):
					continue
				var patient: ToonActor = actor_of.call(int((item as Dictionary).get("toon_id", (item as Dictionary).get("toon", 0))))
				if patient == null:
					continue
				var spark := _make("splat")
				_tint(spark, Color(0.55, 1.0, 0.45, 0.9))
				spark.scale = Vector3.ONE * 0.35
				spark.global_position = patient.global_position + Vector3(0.0, 3.2, 0.0)
		_once("heal", elapsed, 0.4, _HEAL_SFX[level] if level < _HEAL_SFX.size() else "AA_heal_tickle.ogg")
		if elapsed >= 1.4 and _latch(gate, "hit"):
			contact.call()
	)
	actor.end_action("throw" if level < 6 else "pushbutton")


func _suit(lead: Dictionary, actor: ToonActor, marks: Array, still: Callable, contact: Callable) -> void:
	var cog := _first_cog(marks)
	var key := String(lead.get("anim", "glower"))
	var prop_name := ""
	var joint_name := ""
	var pose_name := ""
	if key == "phone":
		prop_name = "phone"
		joint_name = "joint_Lhold"
		pose_name = "phone"
	elif key == "throw-paper":
		prop_name = "clip-on-tie"
		joint_name = "joint_Rhold"
		pose_name = "tie"
	elif key == "finger-wag":
		prop_name = "shredder"
		joint_name = "joint_Rhold"
		pose_name = "shredder"
	var prop: Node3D = null
	if prop_name != "" and cog != null:
		prop = _make(prop_name)
		_on_joint(prop, cog, joint_name, pose_name)
	var hit := bool(lead.get("hit", false))
	var gate := {}
	await _run(3.8, still, func(elapsed: float) -> void:
		if cog != null:
			_react_one(cog, key, elapsed)
		if prop != null and elapsed < 0.4:
			prop.scale = Vector3.ONE * lerpf(0.01, 1.0, elapsed / 0.4)
		if actor != null and elapsed >= 2.4:
			actor.pose_action(String(lead.get("react", "cringe")) if hit else "sidestep-left", elapsed - 2.4)
		if key == "phone":
			_once("phone", elapsed, 1.2, "SA_hangup.mp3")
		elif key == "throw-paper":
			_once("tie", elapsed, 1.4, "SA_powertie_throw.mp3")
		if not hit:
			_once("step", elapsed, 2.4, "AV_side_step.mp3")
		if elapsed >= 2.4 and _latch(gate, "hit"):
			contact.call()
	)
	if actor != null:
		actor.end_action(String(lead.get("react", "cringe")) if hit else "sidestep-left")


func _plant(cog: Node3D, prop: Node3D, cog_id: int, sound_name: String) -> void:
	if _traps.has(cog_id):
		var previous: Dictionary = _traps[cog_id]
		var old: Node = previous.get("node")
		if old != null and is_instance_valid(old):
			old.queue_free()
	var forward := -cog.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3(0, 0, -1)
	prop.reparent(cog)
	prop.global_position = cog.global_position + forward.normalized() * 1.7 + Vector3(0.0, 0.15, 0.0)
	prop.scale = Vector3.ONE
	_spawned.erase(prop)
	_traps[cog_id] = {"node": prop, "sound": sound_name}


func _spring(cog_id: int) -> bool:
	if not _traps.has(cog_id):
		return false
	var record: Dictionary = _traps[cog_id]
	_traps.erase(cog_id)
	_sfx(String(record.get("sound", "TL_step_on_rake.ogg")))
	var node: Node = record.get("node")
	if node != null and is_instance_valid(node):
		node.queue_free()
	return true


func _react_marks(marks: Array, elapsed: float, at: float, hit_key: String) -> void:
	if elapsed < at:
		return
	for mark in marks:
		var row: Dictionary = mark
		var key := hit_key
		if not bool(row.get("hit", false)):
			key = "sidestep-left"
		elif int(row.get("hp", 1)) <= 0:
			key = "lose"
		_react_one(row.get("cog"), key, elapsed - at)


func _react_one(cog: Variant, key: String, elapsed: float) -> void:
	if cog is Node and (cog as Node).has_method("begin_react"):
		(cog as Node).call("begin_react", key, elapsed)


func _rest(actor: ToonActor, marks: Array) -> void:
	for mark in marks:
		var row: Dictionary = mark
		var cog: Variant = row.get("cog")
		if cog is Node and (cog as Node).has_method("begin_react") and int(row.get("hp", 1)) > 0:
			(cog as Node).call("begin_react", "", 0.0)
	if actor != null:
		actor.set_locomotion(0.0, false, false, 0.0)


func _fly(prop: Node3D, aim: Node3D, height: float, elapsed: float, leave: float, flight: float, miss: bool) -> void:
	if not prop.has_meta("from"):
		var at := prop.global_position
		prop.reparent(self)
		prop.global_position = at
		prop.scale = Vector3.ONE
		prop.set_meta("from", at)
	if aim == null:
		return
	var start: Vector3 = prop.get_meta("from")
	var target := aim.global_position + Vector3(0.0, height, 0.0)
	if miss:
		target += _aside_from(start, aim) * 3.0
	var flown := clampf((elapsed - leave) / flight, 0.0, 1.0)
	prop.global_position = start.lerp(target, flown)


func _run(length: float, still: Callable, step: Callable) -> void:
	var elapsed := 0.0
	while elapsed < length:
		if not still.call():
			return
		step.call(elapsed)
		await get_tree().process_frame
		if not is_inside_tree():
			return
		elapsed += get_process_delta_time()
	if still.call():
		step.call(length)


func _wait(length: float, still: Callable) -> void:
	await _run(length, still, func(_elapsed: float) -> void:
		pass)


func _prop_name(track: int, level: int) -> String:
	if track < 0 or track >= _GAGS.size():
		return "tart"
	var row: Array = _GAGS[track]
	if level < 0 or level >= row.size():
		return "tart"
	return String(row[level])


func _make(prop_name: String) -> Node3D:
	var wrap := Node3D.new()
	wrap.name = prop_name
	add_child(wrap)
	_spawned.append(wrap)
	var packed := load(_PROPS + prop_name + ".glb") as PackedScene
	if packed == null:
		return wrap
	var model := packed.instantiate()
	wrap.add_child(model)
	return wrap


func _hand(prop: Node3D, actor: Node3D, joint_name: String) -> void:
	var joint := _joint(actor, joint_name)
	if joint == null:
		prop.reparent(actor)
		prop.position = Vector3(0.2, 1.4, 0.4)
	else:
		prop.reparent(joint, false)
		prop.transform = Transform3D.IDENTITY
	prop.scale = Vector3(0.01, 0.01, 0.01)


func _on_joint(prop: Node3D, host: Node, joint_name: String, pose_name: String) -> void:
	var joint := _joint(host, joint_name)
	if joint == null:
		prop.reparent(host)
		return
	prop.reparent(joint, false)
	prop.transform = _pose(pose_name)
	prop.scale = Vector3.ONE


func _pose(pose_name: String) -> Transform3D:
	var data: Variant = _attach.get(pose_name, {})
	if not data is Dictionary:
		return Transform3D.IDENTITY
	var record: Dictionary = data
	var origin: Array = record.get("origin", [0, 0, 0])
	var x: Array = record.get("x", [1, 0, 0])
	var y: Array = record.get("y", [0, 1, 0])
	var z: Array = record.get("z", [0, 0, 1])
	if origin.size() < 3 or x.size() < 3 or y.size() < 3 or z.size() < 3:
		return Transform3D.IDENTITY
	return Transform3D(Basis(
		Vector3(float(x[0]), float(x[1]), float(x[2])),
		Vector3(float(y[0]), float(y[1]), float(y[2])),
		Vector3(float(z[0]), float(z[1]), float(z[2]))
	), Vector3(float(origin[0]), float(origin[1]), float(origin[2])))


func _joint(host: Node, joint_name: String) -> Node3D:
	if host == null:
		return null
	return host.find_child(joint_name, true, false) as Node3D


func _spray(spray: Node3D, from_world: Vector3, to_world: Vector3) -> void:
	var dir := to_world - from_world
	var distance := dir.length()
	if distance < 0.05:
		spray.visible = false
		return
	spray.reparent(self)
	spray.look_at(to_world, Vector3.UP)
	spray.global_position = from_world
	spray.scale = Vector3(0.35, distance, 0.35)


func _face_camera(node: Node3D) -> void:
	if node == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	node.look_at(camera.global_position, Vector3.UP)


func _tint(node: Node, color: Color) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var tint := StandardMaterial3D.new()
		tint.albedo_color = color
		tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tint.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh_node.material_override = tint


func _first_cog(marks: Array) -> Node3D:
	for mark in marks:
		var cog: Variant = (mark as Dictionary).get("cog")
		if cog is Node3D:
			return cog
	return null


func _any_hit(marks: Array) -> bool:
	for mark in marks:
		if bool((mark as Dictionary).get("hit", false)):
			return true
	return false


func _aside(actor: Node3D, cog: Node3D) -> Vector3:
	return _aside_from(actor.global_position, cog)


func _aside_from(origin: Vector3, cog: Node3D) -> Vector3:
	var away := cog.global_position - origin
	away.y = 0.0
	if away.length_squared() < 0.01:
		return Vector3.RIGHT
	return away.normalized().cross(Vector3.UP)


func _splat_color(pie_name: String) -> Color:
	if pie_name.begins_with("cream"):
		return Color(250.0 / 255.0, 241.0 / 255.0, 24.0 / 255.0)
	if pie_name == "birthday-cake" or pie_name == "wedding-cake":
		return Color(253.0 / 255.0, 119.0 / 255.0, 220.0 / 255.0)
	return Color(55.0 / 255.0, 40.0 / 255.0, 148.0 / 255.0)


func _splat_scale(pie_name: String) -> float:
	if pie_name == "tart":
		return 0.3
	if pie_name.ends_with("slice"):
		return 0.5
	if pie_name == "birthday-cake" or pie_name == "wedding-cake":
		return 0.9
	return 0.7


func _pie_hit(level: int) -> String:
	if level <= 0:
		return "AA_tart_only.ogg"
	if level >= 5:
		return "AA_wholepie_only.ogg"
	return "AA_slice_only.ogg"


func _once(id: String, elapsed: float, at: float, file_name: String) -> void:
	if elapsed < at or bool(_fired.get(id, false)):
		return
	_fired[id] = true
	_sfx(file_name)


func _latch(gate: Dictionary, id: String) -> bool:
	if bool(gate.get(id, false)):
		return false
	gate[id] = true
	return true


func _sfx(file_name: String) -> void:
	var stream := load(_SFX + file_name) as AudioStream
	if stream == null:
		return
	var player := ToonAudio.effect_player()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _clear_spawned() -> void:
	for node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()
