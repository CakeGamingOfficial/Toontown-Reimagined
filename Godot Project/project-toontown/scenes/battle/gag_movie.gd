class_name GagMovie
extends Node

## MovieThrow, MovieSquirt, MovieDrop, MovieTrap, MovieLure, MovieSound, and
## MovieHeal for a street battle. Props follow the original intervals. The
## camera cuts are MovieCamera's open shot, then the close shot.

const _PROPS := "res://assets/battle/props/"
const _SFX := "res://assets/audio/battle/"
const _HEIGHT := 4.88
# MovieUtil.SUIT_LOSE_DURATION. The lose-mod plays after the hit react.
const LOSE_SECONDS := 6.0
const _GAGS: Array = [
	["feather", "megaphone", "lipstick", "cane", "", "cubes", "ladder"],
	["banana", "rake", "marbles", "quicksand", "trapdoor", "tnt", "traintrack"],
	["fishing-pole", "magnet", "fishing-pole", "magnet", "fishing-pole", "hypno-goggles", "slideshow"],
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
const _SQUIRT_CLIP: PackedStringArray = ["pushbutton", "spit", "water-gun", "hold-bottle", "firehose", "pushbutton", "pushbutton"]
const _HEAL_CLIP: PackedStringArray = ["tickle", "sound", "smooch", "happy-dance", "sprinkle-dust", "juggle", "climb"]
const _LURE_DOLLAR: PackedStringArray = ["1dollar", "", "5dollar", "", "10dollar", "", ""]

const _DROP_FALL: Array[float] = [0.5, 0.1667, 0.0417, 0.4583, 0.4583, 0.4583, 0.0833]
const _HEAL_TIME: Array[float] = [3.2, 3.6, 3.4, 6.4, 4.6, 7.7, 9.0]
const _SHOTS: Dictionary = {
	"throw_close": {"rel": true, "x": 3.0, "y": 8.0, "z": 0.66, "chest": true},
	"three_right": {"rel": true, "x": 5.2, "y": 5.45, "z": 0.66, "chest": true},
	"three_left": {"rel": true, "x": -5.2, "y": 5.45, "z": 0.66, "chest": true},
	"three_wide": {"rel": true, "x": 7.2, "y": 8.45, "z": 0.66, "chest": true},
	"behind": {"rel": true, "x": 5.0, "y": -7.0, "z": 1.0, "chest": true},
	"behind_high_right": {"rel": true, "x": 4.0, "y": -7.0, "z": 5.0, "plus_height": true},
	"group_low": {"rel": false, "x": 15.0, "y": 0.0, "z": 3.0},
	"suit_behind": {"rel": false, "x": 12.37, "y": 11.5, "z": 8.16, "flip": true},
	"toon_group": {"rel": false, "x": 10.0, "y": 0.0, "z": 10.0},
}

var _spawned: Array[Node] = []
var _traps: Dictionary = {}
var _fired: Dictionary = {}
var _attach: Dictionary = {}
var _aiming := false
var _aim_time := 0.0
var _aim_open := 3.0
var _aim_open_name := "group_low"
var _aim_close_name := "group_low"
var _aim_open_on := "battle"
var _aim_close_on := "battle"
var _aim_flip := 1.0
var _aim_actor: ToonActor
var _aim_cog: Node3D


func _ready() -> void:
	var path := _PROPS + "attachments.json"
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		_attach = parsed


## The server holds the movie for this long. Playback uses the same numbers,
## so a client cannot finish after the round has already moved on.
static func seconds(kind: String, track: int, level: int, died: bool) -> float:
	if kind == "run" or kind == "lured":
		return 1.3
	if kind == "cog":
		return 9.4 if died else 3.8
	if kind != "gag":
		return 2.2
	if track == 4:
		return 4.8
	if track == 5:
		if level <= 0:
			return 4.6
		if level == 1:
			return 5.4
		if level == 2:
			return 4.2
		if level == 3:
			return 4.4
		if level == 4:
			return 6.2
		if level == 5:
			return 7.2
		return 5.2
	if track == 6:
		return 6.6
	if track == 1:
		return 3.6
	if track == 2:
		if level == 1 or level == 3:
			return 7.2
		if level == 5:
			return 6.0
		if level == 6:
			return 4.8
		return 5.6
	if track == 3:
		return 8.0 if level >= 6 else 5.0
	if track == 0:
		return _HEAL_TIME[clampi(level, 0, _HEAL_TIME.size() - 1)]
	return 2.2


func has_aim() -> bool:
	return _aiming


func end_aim() -> void:
	_aiming = false
	_aim_actor = null
	_aim_cog = null


func aim_camera(camera: Camera3D, basis: Dictionary) -> void:
	if not _aiming or camera == null:
		return
	var name := _aim_close_name if _aim_time >= _aim_open else _aim_open_name
	var on := _aim_close_on if _aim_time >= _aim_open else _aim_open_on
	var shot: Dictionary = _SHOTS.get(name, _SHOTS["group_low"])
	var origin: Vector3 = basis.get("origin", Vector3.ZERO)
	var forward: Vector3 = basis.get("forward", Vector3(0, 0, 1))
	var right: Vector3 = basis.get("right", Vector3.RIGHT)
	var anchor := origin
	var height := 3.5
	if on == "toon" and _live(_aim_actor):
		anchor = _aim_actor.global_position
		height = 3.5
	elif on == "cog" and _live(_aim_cog):
		anchor = _aim_cog.global_position
		height = maxf(float(_aim_cog.get("height")), _HEIGHT)
	elif on == "cog":
		anchor = origin + forward * 5.0
		height = _HEIGHT
	var rise := float(shot.get("z", 3.0))
	if bool(shot.get("chest", false)):
		rise *= height
	elif bool(shot.get("plus_height", false)):
		rise += height
	var side := float(shot.get("x", 0.0))
	if bool(shot.get("flip", false)):
		side *= _aim_flip
	var ahead := float(shot.get("y", 0.0))
	var pos := anchor + right * side + forward * ahead + Vector3.UP * rise
	var look := origin + Vector3.UP * 2.0
	if bool(shot.get("rel", false)):
		look = anchor + Vector3.UP * (height * 0.66)
	if pos.distance_squared_to(look) < 0.36:
		pos = look - forward * 6.0 + Vector3.UP * 2.0
	camera.fov = 80.0
	camera.global_position = pos
	if camera.global_position.distance_squared_to(look) > 0.25:
		camera.look_at(look, Vector3.UP)


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
	_begin_camera(lead, actor, marks)
	if kind == "cog":
		await _suit(beats, actor_of, marks, still, contact)
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
	if kind == "gag":
		await _cog_death(marks, still)
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
	await _run(seconds("gag", 4, level, false), still, func(elapsed: float) -> void:
		actor.pose_action("throw", elapsed)
		# tPieLeavesHand 2.7, tPieHitsSuit 3.0, tSuitDodges 2.45.
		if elapsed < 2.7:
			pie.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf(elapsed, 0.0, 1.0))
		else:
			_fly(pie, aim, _HEIGHT if hit else _HEIGHT * 1.3, elapsed, 2.7, 0.3 if hit else 0.45, not hit, not hit)
		if hit and elapsed >= 3.0 and not pie.has_meta("splats"):
			pie.visible = false
			var splats: Array[Node3D] = []
			for mark in marks:
				var row: Dictionary = mark
				if not bool(row.get("hit", false)):
					continue
				var cog: Node3D = row.get("cog")
				var splat := _make("splat")
				_tint(splat, _splat_color(pie_name))
				splat.scale = Vector3.ONE * _splat_scale(pie_name)
				if cog != null:
					splat.global_position = cog.global_position + Vector3(0.0, _HEIGHT, 0.0)
				splats.append(splat)
			pie.set_meta("splats", splats)
		if pie.has_meta("splats"):
			for shown in pie.get_meta("splats"):
				if _live(shown) and shown is Node3D:
					_face_camera(shown)
		_react_marks(marks, elapsed, 3.0, "pie-small", 2.45)
		_once("throw", elapsed, 2.6, "AA_pie_throw_only.ogg")
		if hit:
			_once("pie", elapsed, 3.0, _pie_hit(level))
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
	# Flower grows at 1.0s over 0.5s. Spray starts at 2.5 and lasts 0.3s.
	await _run(seconds("gag", 5, 0, false), still, func(elapsed: float) -> void:
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
		if elapsed >= 2.5 and elapsed < 2.8 and aim != null:
			spray.visible = true
			_spray(spray, flower.global_position, aim.global_position + Vector3(0.0, _HEIGHT * 0.66, 0.0))
		else:
			spray.visible = false
		_react_marks(marks, elapsed, 2.7, "squirt-small", 2.5)
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
	var when := _squirt_when(level)
	var clip := String(when.get("clip", "pushbutton"))
	var spray_at := float(when.get("spray", 2.0))
	var hold := float(when.get("hold", 0.2))
	var contact_at := spray_at + 0.1
	var dodge_at := float(when.get("dodge", contact_at))
	var hydrant: Node3D = null
	if level == 4:
		hydrant = _make("hydrant")
		hydrant.global_position = actor.global_position + (-actor.global_transform.basis.z) * 1.4
		hydrant.global_position.y = actor.global_position.y
		prop.reparent(hydrant)
	var gate := {}
	await _run(seconds("gag", 5, level, false), still, func(elapsed: float) -> void:
		actor.pose_action(clip, elapsed)
		if level != 4:
			prop.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf(elapsed / 0.5, 0.0, 1.0))
		if elapsed >= spray_at and elapsed < spray_at + hold and aim != null:
			spray.visible = true
			_spray(spray, prop.global_position, aim.global_position + Vector3(0.0, _HEIGHT * 0.66, 0.0))
		else:
			spray.visible = false
		_react_marks(marks, elapsed, contact_at, "squirt-small", dodge_at)
		_once("squirt", elapsed, float(when.get("sound", spray_at)), _SQUIRT_HIT[level] if hit else _SQUIRT_MISS[level])
		if elapsed >= contact_at and _latch(gate, "hit"):
			contact.call()
	)
	actor.end_action(clip)


func _sky_squirt(actor: ToonActor, prop_name: String, level: int, marks: Array, still: Callable, contact: Callable) -> void:
	var aim := _first_cog(marks)
	var prop := _make(prop_name)
	prop.visible = false
	if aim != null:
		prop.global_position = aim.global_position + Vector3(0.0, _HEIGHT + 6.0, 0.0)
	var hit := _any_hit(marks)
	var gate := {}
	var cloud := level == 5
	await _run(seconds("gag", 5, level, false), still, func(elapsed: float) -> void:
		actor.pose_action("pushbutton", elapsed)
		if cloud:
			# Storm cloud scales up for 1.5s, holds, then shrinks.
			if elapsed < 1.5:
				prop.visible = true
				prop.scale = Vector3.ONE * lerpf(0.05, 3.0, elapsed / 1.5)
			elif elapsed < 6.2:
				prop.visible = true
				prop.scale = Vector3.ONE * 3.0
			else:
				prop.scale = Vector3.ONE * lerpf(3.0, 0.05, clampf((elapsed - 6.2) / 0.5, 0.0, 1.0))
			if aim != null:
				prop.global_position = aim.global_position + Vector3(0.0, _HEIGHT + 3.0, 0.0)
		elif elapsed >= 1.0:
			prop.visible = true
			var column := clampf((elapsed - 1.0) / 0.5, 0.0, 1.0)
			prop.scale = Vector3(column, column * 2.2, column)
			if aim != null:
				prop.global_position = aim.global_position + Vector3(0.0, 0.2, 0.0)
		_react_marks(marks, elapsed, 2.9, "soak" if level >= 6 else "squirt-small", 1.8)
		_once("sky", elapsed, 2.3 if cloud else 1.0, _SQUIRT_HIT[level] if hit else _SQUIRT_MISS[level])
		if cloud:
			_once("sky2", elapsed, 4.6, _SQUIRT_HIT[level] if hit else _SQUIRT_MISS[level])
		if elapsed >= 2.9 and _latch(gate, "hit"):
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
	var fall := _DROP_FALL[clampi(level, 0, _DROP_FALL.size() - 1)]
	var shadows: Array[Node3D] = []
	for _mark in marks:
		shadows.append(_shadow())
	var gate := {}
	var react := "flatten" if level >= 3 else "drop-react"
	await _run(seconds("gag", 6, level, false), still, func(elapsed: float) -> void:
		actor.pose_action("pushbutton", elapsed)
		# The button lands at 2.44. The shadow grows until the object appears at 4.3.
		if elapsed >= 2.44 and _latch(gate, "box"):
			_sfx("AA_drop_trigger_box.ogg")
		for index in props.size():
			var falling := props[index]
			var shadow := shadows[index]
			var mark: Dictionary = marks[index]
			var cog: Node3D = mark.get("cog")
			if cog == null:
				continue
			var missed := not bool(mark.get("hit", false))
			var rest := cog.global_position + Vector3(0.0, 1.2 if level < 3 else 0.4, 0.0)
			if missed and level >= 3:
				rest += _aside(actor, cog) * 5.0
			elif missed:
				rest += _aside(actor, cog) * 2.4
			shadow.global_position = Vector3(rest.x, cog.global_position.y + 0.05, rest.z)
			if elapsed >= 2.44 and elapsed < 4.6:
				shadow.visible = true
				var grown := clampf((elapsed - 2.44) / (4.3 - 2.44), 0.0, 1.0)
				shadow.scale = Vector3.ONE * lerpf(0.01, 1.6, grown)
			else:
				shadow.visible = false
			if elapsed < 4.3:
				falling.visible = false
				continue
			falling.visible = true
			var fallen := clampf((elapsed - 4.3) / fall, 0.0, 1.0)
			var above := rest + Vector3(0.0, 5.0, 0.0)
			falling.global_position = above.lerp(rest, fallen)
			falling.scale = Vector3.ONE
		_react_marks(marks, elapsed, 4.3, react, 4.3)
		if elapsed >= 4.3 + fall and _latch(gate, "land"):
			_sfx(_DROP_HIT[level] if hit else _DROP_MISS[level])
		if elapsed >= 4.3 and _latch(gate, "hit"):
			contact.call()
	)
	actor.end_action("pushbutton")


func _trap(actor: ToonActor, prop_name: String, level: int, marks: Array, still: Callable, contact: Callable) -> void:
	var props: Array[Node3D] = []
	for _mark in marks:
		var prop := _make(prop_name)
		_hand(prop, actor, "def_joint_right_hold")
		props.append(prop)
	var clip := "toss" if level < 3 else "pushbutton"
	var gate := {}
	await _run(seconds("gag", 1, level, false), still, func(elapsed: float) -> void:
		actor.pose_action(clip, elapsed)
		for index in props.size():
			var prop := props[index]
			var mark: Dictionary = marks[index]
			var cog: Node3D = mark.get("cog")
			if elapsed < 2.6:
				prop.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf(elapsed, 0.0, 1.0))
			elif cog != null:
				_fly(prop, cog, 0.25, elapsed, 2.6, 0.9, false)
		_once("trap", elapsed, 0.2, _TRAP_SFX[level] if level < _TRAP_SFX.size() else "TL_banana.ogg")
		if elapsed >= 3.5 and _latch(gate, "hit"):
			contact.call()
	)
	for index in props.size():
		var mark: Dictionary = marks[index]
		var cog: Node3D = mark.get("cog")
		if cog != null:
			_plant(cog, props[index], int(mark.get("id", 0)), _TRAP_SFX[level] if level < _TRAP_SFX.size() else "TL_banana.ogg", level)
	actor.end_action(clip)


func _lure(actor: ToonActor, prop_name: String, level: int, marks: Array, still: Callable, contact: Callable) -> void:
	var clip := "battlecast"
	if level == 1 or level == 3:
		clip = "hold-magnet"
	elif level == 5:
		clip = "hypnotize"
	elif level == 6:
		clip = "pushbutton"
	var prop := _make(prop_name)
	_hand(prop, actor, "def_joint_right_hold")
	if level == 1:
		prop.scale = Vector3.ONE * 0.5
	var bill: Node3D = null
	var bill_name := _LURE_DOLLAR[level] if level < _LURE_DOLLAR.size() else ""
	if bill_name != "":
		bill = _make(bill_name)
		_hand(bill, actor, "def_joint_left_hold")
	var gate := {}
	var lure_at := 3.5
	if level == 1 or level == 3:
		lure_at = 3.7
	elif level == 5:
		lure_at = 2.6
	elif level == 6:
		lure_at = 2.4
	await _run(seconds("gag", 2, level, false), still, func(elapsed: float) -> void:
		actor.pose_action(clip, elapsed)
		if level == 1 or level == 3:
			prop.scale = Vector3.ONE * 0.5
		else:
			prop.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf(elapsed / 0.6, 0.0, 1.0))
		if bill != null:
			var aim := _first_cog(marks)
			if elapsed >= 3.0 and aim != null:
				_fly(bill, aim, _HEIGHT * 0.5, elapsed, 3.0, 0.5, not _any_hit(marks))
		_react_marks(marks, elapsed, lure_at, "hypnotized", lure_at)
		_once("lure", elapsed, 0.7, "AA_pie_throw_only.ogg")
		if elapsed >= lure_at and _latch(gate, "hit"):
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
	var horn := _make("megaphone")
	_hand(horn, actor, "def_joint_left_hold")
	var prop := _make(prop_name)
	_hand(prop, actor, "def_joint_right_hold")
	var gate := {}
	var react_at := 2.8 + (3.0 if level >= 6 else 0.0)
	await _run(seconds("gag", 3, level, false), still, func(elapsed: float) -> void:
		actor.pose_action("sound", elapsed)
		# Megaphone shows, the instrument grows after 1s, and the note hits at 2.45.
		horn.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf(elapsed / 0.2, 0.0, 1.0))
		var size := 0.01
		if elapsed >= 1.0:
			size = lerpf(0.01, 0.65, clampf((elapsed - 1.0) / 0.2, 0.0, 1.0))
		if elapsed >= 2.45 and elapsed < 2.65:
			size = lerpf(0.65, 1.1, (elapsed - 2.45) / 0.2)
		elif elapsed >= 2.65 and elapsed < 2.85:
			size = lerpf(1.1, 0.65, (elapsed - 2.65) / 0.2)
		elif elapsed >= 4.2:
			size = lerpf(0.65, 0.01, clampf((elapsed - 4.2) / 0.1, 0.0, 1.0))
		prop.scale = Vector3(size, size * (1.4 if elapsed >= 2.45 and elapsed < 2.65 else 1.0), size)
		_react_marks(marks, elapsed, react_at, "squirt-small")
		_once("sound", elapsed, 2.45, _SOUND_SFX[level] if level < _SOUND_SFX.size() else "AA_sound_bikehorn.ogg")
		if level >= 6 and _any_hit(marks):
			_once("glass", elapsed, react_at, "AA_sound_Opera_Singer_Cog_Glass.ogg")
		if elapsed >= react_at and _latch(gate, "hit"):
			contact.call()
	)
	actor.end_action("sound")


func _heal(actor: ToonActor, prop_name: String, level: int, beats: Array, actor_of: Callable, still: Callable, contact: Callable) -> void:
	var clip := _HEAL_CLIP[level] if level < _HEAL_CLIP.size() else "tickle"
	var dur := seconds("gag", 0, level, false)
	var prop: Node3D = null
	if prop_name != "":
		prop = _make(prop_name)
		_hand(prop, actor, "def_joint_right_hold")
	var hat: Node3D = null
	if level == 3:
		hat = _make("hat")
		_hand(hat, actor, "def_joint_attachFlower")
	var gate := {}
	await _run(dur, still, func(elapsed: float) -> void:
		actor.pose_action(clip, elapsed)
		if prop != null:
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
				if level == 2:
					var lips := _make("lips")
					lips.global_position = patient.global_position + Vector3(0.0, 3.5, 0.35)
					lips.scale = Vector3.ONE * 0.35
		_once("heal", elapsed, 0.4, _HEAL_SFX[level] if level < _HEAL_SFX.size() else "AA_heal_tickle.ogg")
		if elapsed >= 1.4 and _latch(gate, "hit"):
			contact.call()
	)
	actor.end_action(clip)


func _suit(beats: Array, actor_of: Callable, marks: Array, still: Callable, contact: Callable) -> void:
	var lead: Dictionary = beats[0]
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
		prop_name = "shredder-paper"
		joint_name = "joint_Rhold"
		pose_name = "paper"
	elif key == "shredder":
		prop_name = "shredder"
		joint_name = "joint_Rhold"
		pose_name = "shredder"
	elif key == "clip-on-tie" or key == "throw-object":
		prop_name = "clip-on-tie" if key == "clip-on-tie" else "shredder-paper"
		joint_name = "joint_Rhold"
		pose_name = "tie" if key == "clip-on-tie" else "paper"
	var prop: Node3D = null
	if prop_name != "" and cog != null:
		prop = _make(prop_name)
		_on_joint(prop, cog, joint_name, pose_name)
	var victims: Array = lead.get("victims", [])
	var gate := {}
	var title := String(lead.get("attack", ""))
	if _live(cog) and title != "":
		cog.set_meta("chat_line", title)
		cog.set_meta("chat_until", Time.get_ticks_msec() + 3800)
		ToonSpeech.cog(title)
	# A fatal hit keeps the round open for the shrink. This clip is only the attack.
	await _run(3.8, still, func(elapsed: float) -> void:
		if _live(cog):
			_react_one(cog, key, elapsed)
		if prop != null and elapsed < 0.4:
			prop.scale = Vector3.ONE * lerpf(0.01, 1.0, elapsed / 0.4)
		if elapsed >= 2.4:
			for item in victims:
				if not (item is Dictionary):
					continue
				var victim: Dictionary = item
				if bool(victim.get("died", false)):
					continue
				var actor: ToonActor = actor_of.call(int(victim.get("id", 0)))
				if actor == null:
					continue
				var react := "cringe" if bool(victim.get("hit", false)) else "sidestep-left"
				actor.pose_action(react, elapsed - 2.4)
		if key == "phone":
			_once("phone", elapsed, 1.2, "SA_hangup.mp3")
		elif key == "throw-paper" or key == "throw-object":
			_once("tie", elapsed, 1.4, "SA_powertie_throw.mp3")
		elif key == "shredder":
			_once("shred", elapsed, 1.4, "SA_shred.mp3")
		var missed := true
		for item in victims:
			if item is Dictionary and bool((item as Dictionary).get("hit", false)):
				missed = false
		if missed:
			_once("step", elapsed, 2.4, "AV_side_step.mp3")
		if elapsed >= 2.4 and _latch(gate, "hit"):
			contact.call()
	)
	for item in victims:
		if not (item is Dictionary) or bool((item as Dictionary).get("died", false)):
			continue
		var actor: ToonActor = actor_of.call(int((item as Dictionary).get("id", 0)))
		if actor == null:
			continue
		var react := "cringe" if bool((item as Dictionary).get("hit", false)) else "sidestep-left"
		actor.end_action(react)
	if _live(cog):
		cog.set_meta("chat_line", "")
		cog.set_meta("chat_until", 0)


func _plant(cog: Node3D, prop: Node3D, cog_id: int, sound_name: String, level: int) -> void:
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
	_traps[cog_id] = {"node": prop, "sound": sound_name, "level": level}


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


func _react_marks(marks: Array, elapsed: float, at: float, hit_key: String, miss_at: float = -1.0) -> void:
	var dodge := at if miss_at < 0.0 else miss_at
	for mark in marks:
		var row: Dictionary = mark
		var when := at if bool(row.get("hit", false)) else dodge
		if elapsed < when:
			continue
		var key := hit_key
		if not bool(row.get("hit", false)):
			key = "sidestep-left"
		# A killing hit still plays the react. The lose-mod follows the gag.
		_react_one(row.get("cog"), key, elapsed - when)


func _cog_death(marks: Array, still: Callable) -> void:
	var dying := false
	for mark in marks:
		var row: Dictionary = mark
		if int(row.get("hp", 1)) <= 0 and row.get("cog") != null:
			dying = true
	if not dying:
		return
	var gate := {}
	await _run(LOSE_SECONDS, still, func(elapsed: float) -> void:
		for mark in marks:
			var row: Dictionary = mark
			if int(row.get("hp", 1)) > 0:
				continue
			var cog: Variant = row.get("cog")
			if _live(cog) and cog is Node and (cog as Node).has_method("play_lose"):
				(cog as Node).call("play_lose", elapsed)
		# MovieUtil deathSoundTrack. Cog_Death is the spin, then the crash.
		if elapsed >= 0.8 and _latch(gate, "spin"):
			_sfx("Cog_Death.ogg")
		if elapsed >= 5.0 and _latch(gate, "crash"):
			_sfx("ENC_cogfall_apart.ogg")
	)


func _react_one(cog: Variant, key: String, elapsed: float) -> void:
	if _live(cog) and cog is Node and (cog as Node).has_method("begin_react"):
		(cog as Node).call("begin_react", key, elapsed)


func _rest(actor: ToonActor, marks: Array) -> void:
	for mark in marks:
		var row: Dictionary = mark
		var cog: Variant = row.get("cog")
		if _live(cog) and cog is Node and (cog as Node).has_method("begin_react") and int(row.get("hp", 1)) > 0:
			(cog as Node).call("begin_react", "", 0.0)
	if actor != null:
		actor.set_locomotion(0.0, false, false, 0.0)


func _fly(prop: Node3D, aim: Node3D, height: float, elapsed: float, leave: float, flight: float, miss: bool, shrink: bool = false) -> void:
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
		target = start + (target - start) * 1.5
	var flown := clampf((elapsed - leave) / maxf(flight, 0.05), 0.0, 1.0)
	prop.global_position = start.lerp(target, flown)
	if shrink:
		var faded := 0.0 if flown < 0.7 else (flown - 0.7) / 0.3
		prop.scale = Vector3.ONE * maxf(1.0 - faded, 0.01)


func _run(length: float, still: Callable, step: Callable) -> void:
	var elapsed := 0.0
	while elapsed < length:
		if not still.call():
			return
		_aim_time = elapsed
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


func _begin_camera(lead: Dictionary, actor: ToonActor, marks: Array) -> void:
	var kind := String(lead.get("kind", ""))
	var track := int(lead.get("track", -1))
	var level := int(lead.get("level", 0))
	var many := marks.size() > 1
	var seed := absi(int(lead.get("toon", 1)) * 13 + int(lead.get("cog", 1)) * 17 + track * 19 + level * 23 + int(lead.get("hp", 0)))
	_aiming = true
	_aim_time = 0.0
	_aim_actor = actor
	_aim_cog = _first_cog(marks)
	_aim_flip = 1.0 if seed % 2 == 0 else -1.0
	_aim_open = 3.0
	_aim_open_name = "group_low"
	_aim_close_name = "group_low"
	_aim_open_on = "battle"
	_aim_close_on = "battle"
	if kind == "cog":
		_aim_open = 2.8
		_aim_open_name = "throw_close"
		_aim_open_on = "cog"
		_aim_close_name = "three_left"
		_aim_close_on = "toon"
		return
	if track == 0:
		if level >= 6:
			_aim_open = 9.0
			return
		_aim_open = 2.8
		_aim_open_name = "toon_group"
		_aim_close_name = "toon_group"
		return
	if track == 1 or track == 2:
		if track == 2 and _train_trap():
			_aim_close_name = "behind_high_right"
			_aim_close_on = "toon"
		return
	if track == 3:
		_aim_open = 5.0 if level >= 6 else 3.1
		if many:
			_aim_open_name = "group_low" if seed % 2 == 0 else "suit_behind"
			_aim_close_name = "suit_behind" if seed % 2 == 0 else "group_low"
			return
		var sound_open: Array[String] = ["three_wide", "group_low", "suit_behind"] if level >= 6 else ["three_right", "group_low", "suit_behind"]
		_assign_shot(true, sound_open[seed % sound_open.size()], "toon")
		var sound_close: Array[String] = ["throw_close", "three_left", "group_low", "suit_behind"]
		_assign_shot(false, sound_close[(seed / 5) % sound_close.size()], "cog")
		return
	if many:
		_aim_open_name = "group_low" if seed % 2 == 0 else "suit_behind"
		_aim_close_name = "suit_behind" if seed % 2 == 0 else "group_low"
		return
	var opens: Array[String] = ["throw_close", "three_right", "behind", "group_low", "suit_behind"]
	_assign_shot(true, opens[seed % opens.size()], "toon")
	var closes: Array[String] = ["throw_close", "three_left", "group_low", "suit_behind"]
	_assign_shot(false, closes[(seed / 5) % closes.size()], "cog")


func _assign_shot(opening: bool, name: String, actor_on: String) -> void:
	var shot: Dictionary = _SHOTS.get(name, {})
	var on := actor_on if bool(shot.get("rel", false)) else "battle"
	if opening:
		_aim_open_name = name
		_aim_open_on = on
	else:
		_aim_close_name = name
		_aim_close_on = on


func _train_trap() -> bool:
	for key in _traps.keys():
		var record: Dictionary = _traps[key]
		if int(record.get("level", -1)) >= 6:
			return true
	return false


func _squirt_when(level: int) -> Dictionary:
	# MovieSquirt starts the spray on a frame of the toon clip. Clips are 24fps.
	if level == 1:
		return {"clip": "spit", "spray": 82.0 / 24.0, "hold": 0.2, "dodge": 82.0 / 24.0 - 0.5, "sound": 1.7}
	if level == 2:
		return {"clip": "water-gun", "spray": 48.0 / 24.0, "hold": 0.4, "dodge": 1.1, "sound": 1.8}
	if level == 3:
		var spray := 53.0 / 24.0 + 0.05
		return {"clip": "hold-bottle", "spray": spray, "hold": 0.2, "dodge": maxf(spray + 0.1 - 0.7, 0.0), "sound": spray - 0.1}
	return {"clip": "firehose", "spray": 2.8, "hold": 2.0, "dodge": 2.1, "sound": 2.8}


func _shadow() -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 1.0)
	mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.0, 0.0, 0.0, 0.45)
	mesh.material_override = mat
	mesh.visible = false
	add_child(mesh)
	_spawned.append(mesh)
	return mesh


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
	var path := _PROPS + prop_name + ".glb"
	if not ResourceLoader.exists(path):
		return wrap
	var packed := load(path) as PackedScene
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


func _live(node: Variant) -> bool:
	return node != null and is_instance_valid(node)


func _first_cog(marks: Array) -> Node3D:
	for mark in marks:
		var cog: Variant = (mark as Dictionary).get("cog")
		if _live(cog) and cog is Node3D:
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
