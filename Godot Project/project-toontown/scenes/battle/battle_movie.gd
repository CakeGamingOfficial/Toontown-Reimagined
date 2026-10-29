class_name BattleMovie
extends Node

## Plays a street-battle attack the way the original movies do.
## MovieThrow, MovieSquirt, MovieDrop, and MovieSuitAttacks supply the timing.
## The toon and the Flunky are posed from the original clips, and the gag is
## the original prop parented to the same hand joint.

const _PROPS := "res://assets/battle/props/"
const _SFX := "res://assets/audio/battle/"
const _SUIT_HEIGHT := 4.88
const _PIE_LEAVES := 2.7
const _PIE_HITS := 3.0
const _PIE_DODGE := 2.45
const _MISS_RATIO := 1.5

const _GAGS: Array = [
	["feather", "megaphone", "lipstick", "cane", "cubes", "cubes", "ladder"],
	["banana", "rake", "marbles", "quicksand", "trapdoor", "tnt", "traintrack"],
	["1dollar", "magnet", "1dollar", "magnet", "1dollar", "hypno-goggles", "slideshow"],
	["bikehorn", "whistle", "bugle", "aoogah", "elephant", "fog_horn", "singing"],
	["tart", "fruitpie-slice", "creampie-slice", "fruitpie", "creampie", "birthday-cake", "wedding-cake"],
	["squirting-flower", "glass", "water-gun", "bottle", "firehose", "stormcloud", "geyser"],
	["flowerpot", "sandbag", "anvil", "weight", "safe", "piano", "ship"],
]

var _player: ToonActor
var _flunky: Flunky
var _camera: Camera3D
var _attach: Dictionary = {}
var _spawned: Array[Node] = []
var _fired: Dictionary = {}
var _gear_mat: Material
var _gear_size := Vector2(0.16, 0.16)
var _boom_mats: Array[Material] = []
var _boom_size := Vector2(1.0, 1.0)
var _boom: MeshInstance3D
var _gears: Array[Dictionary] = []
var _death_player: AudioStreamPlayer
var _shot := ""
var _shot_time := 0.0
var _shot_open := 3.0
var _shot_side := 1.0
var _saved_fov := -1.0


func setup(player: ToonActor, flunky: Flunky, camera: Camera3D) -> void:
	_player = player
	_flunky = flunky
	_camera = camera
	var path := _PROPS + "attachments.json"
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		_attach = parsed


func play_gag(track: int, level: int, hit: bool, on_contact: Callable) -> void:
	_fired.clear()
	# MovieCamera.chooseThrowShot holds the toon for 3s, then cuts to the cog.
	_begin_shot("toon", 3.0)
	var prop_name := _gag_name(track, level)
	if track == ToonLoadout.THROW:
		await _throw(prop_name, level, hit, on_contact)
	elif track == ToonLoadout.SQUIRT and level == 0:
		await _flower(hit, on_contact)
	elif track == ToonLoadout.SQUIRT:
		await _squirt_prop(prop_name, hit, on_contact)
	elif track == 6:
		await _drop(prop_name, hit, on_contact)
	elif track == 1:
		await _lob_to_feet(prop_name, hit, on_contact)
	else:
		await _hold(prop_name, on_contact)
	_clear_props()
	_end_shot()


func play_cog(attack_name: String, hit: bool, on_contact: Callable) -> void:
	_fired.clear()
	# MovieCamera.chooseSuitShot open durations for the Flunky's three attacks.
	var open_for := 2.8
	if attack_name == "Clip On Tie!":
		open_for = 3.3
	elif attack_name == "Shred!":
		open_for = 4.1
	_begin_shot("cog", open_for)
	if attack_name == "Clip On Tie!":
		await _clip_on_tie(hit, on_contact)
	elif attack_name == "Shred!":
		await _shred(hit, on_contact)
	else:
		await _pound_key(hit, on_contact)
	_clear_props()
	_end_shot()


## MovieUtil.createSuitDeathTrack. The lose suit plays for 6 seconds while
## gears radiate out of the chest, the kapow flash pops, and the toon ducks.
func play_defeat() -> void:
	_prepare_death()
	_flunky.begin_lose()
	# The killing gag's close shot is already on the cog. Hold that view
	# through the burst, and step back once the pieces leave his body.
	_begin_shot("death", 5.2)
	var gear_point := _flunky.global_position + Vector3(0.0, _SUIT_HEIGHT - 0.2, 0.0)
	var duck_len := _player.action_length("duck")
	var second := 0.0 if duck_len <= 1.8 else duck_len - 1.8
	var length := maxf(6.4, 1.0 + duck_len + second)
	var small_wait := 0.0
	var spun_soft := false
	var spun_loud := false
	var fell := false
	var flashed := false
	var burst_ten := false
	var burst_big := false
	var single := false
	await _play(length, func(elapsed: float) -> void:
		_flunky.pose_lose(elapsed)
		_duck(elapsed, duck_len)
		var delta := get_process_delta_time()
		if elapsed >= 2.1 and elapsed < 6.4:
			small_wait -= delta
			if small_wait <= 0.0:
				small_wait = 0.4
				_spawn_gear(gear_point, 3.2282, 9.0, 9.0, 0.112, minf(1.5, 6.4 - elapsed))
				_spawn_gear(gear_point, 3.2282, 9.0, 9.0, 0.112, minf(1.5, 6.4 - elapsed))
		if elapsed >= 0.7 and not single:
			single = true
			_spawn_gear(gear_point, 3.2282, 9.0, 9.0, 0.16, 5.7)
		if elapsed >= 5.2 and not burst_ten:
			burst_ten = true
			for _index in 10:
				_spawn_gear(gear_point, 3.2282, 9.0, 9.0, 0.16, 1.2)
		if elapsed >= 5.4 and not burst_big:
			burst_big = true
			for _index in 30:
				_spawn_gear(gear_point, 1.6282, 15.0, 18.0, 0.16, 1.0)
		if elapsed >= 5.4 and elapsed < 6.0:
			_show_boom(gear_point, elapsed - 5.4)
			flashed = true
		elif flashed:
			_hide_boom()
			flashed = false
		# MovieUtil deathSoundTrack. Cog_Death is the spin; ENC_cogfall_apart
		# is the crash, and it starts just before the kapow.
		if elapsed >= 0.8 and not spun_soft:
			spun_soft = true
			_death_sound("Cog_Death.ogg", 0.2, 1.5, 1.2)
		if elapsed >= 2.0 and not spun_loud:
			spun_loud = true
			_stop_death_sound()
			_death_sound("Cog_Death.ogg", 0.8, 0.6, 3.0)
		if elapsed >= 5.0 and not fell:
			fell = true
			_stop_death_sound()
			_death_sound("ENC_cogfall_apart.ogg", 0.32, 0.0, 0.0)
		_tick_gears(delta)
	)
	_player.end_action("duck")
	_hide_boom()
	_clear_gears()
	_end_shot()


func _throw(pie_name: String, level: int, hit: bool, on_contact: Callable) -> void:
	var pie := _make(pie_name)
	_parent_hand(pie, "def_joint_right_hold")
	var throw_len := _player.action_length("throw")
	var react := "pie-small" if hit else "sidestep-right"
	var react_at := _PIE_HITS if hit else _PIE_DODGE
	var react_len := _flunky.action_length(react)
	var fly := (_PIE_HITS - _PIE_LEAVES) * (1.0 if hit else _MISS_RATIO)
	var length := maxf(throw_len, react_at + react_len)
	if not hit:
		length = maxf(length, _PIE_LEAVES + fly + 0.7)
	var contacted := false
	await _play(length, func(elapsed: float) -> void:
		_player.pose_action("throw", elapsed)
		if elapsed >= react_at:
			_flunky.pose_action(react, elapsed - react_at)
		if elapsed < _PIE_LEAVES:
			pie.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf(elapsed, 0.0, 1.0))
		else:
			if not pie.has_meta("from"):
				pie.reparent(_player, true)
				pie.scale = Vector3.ONE
				pie.set_meta("from", pie.position)
			var start := pie.get_meta("from") as Vector3
			var target := _cog_point(_SUIT_HEIGHT if hit else _SUIT_HEIGHT * 0.45)
			if not hit:
				target += _side() * 3.2
			var flown := clampf((elapsed - _PIE_LEAVES) / fly, 0.0, 1.0)
			pie.position = start.lerp(target, flown)
			if not hit and elapsed > _PIE_LEAVES + fly:
				var shrink := clampf((elapsed - _PIE_LEAVES - fly) / 0.7, 0.0, 1.0)
				pie.scale = Vector3.ONE * lerpf(1.0, 0.01, shrink)
		if hit and elapsed >= _PIE_HITS and not pie.has_meta("splat"):
			pie.visible = false
			var splat := _make("splat")
			splat.reparent(_player, false)
			splat.position = _cog_point(_SUIT_HEIGHT)
			_tint(splat, _splat_color(pie_name))
			splat.scale = Vector3.ONE * _splat_scale(pie_name)
			pie.set_meta("splat", splat)
		if pie.has_meta("splat"):
			_billboard(pie.get_meta("splat") as Node3D)
		_once("throw", elapsed, 2.6, _SFX + "AA_pie_throw_only.mp3")
		if hit:
			_once("hit", elapsed, _PIE_LEAVES, _SFX + _throw_hit_sound(level))
		if not contacted and elapsed >= react_at:
			contacted = true
			on_contact.call()
	)
	_player.end_action("throw")
	_flunky.end_action(react)


func _flower(hit: bool, on_contact: Callable) -> void:
	var button := _make("button")
	_parent_hand(button, "def_joint_left_hold")
	button.scale = Vector3.ONE
	var flower := _make("squirting-flower")
	var joint := _joint(_player, "def_joint_attachFlower")
	if joint != null:
		flower.reparent(joint, false)
	flower.visible = false
	var spray := _make("spray")
	spray.visible = false
	_tint(spray, Color(0.75, 0.75, 1.0, 0.8))
	var push_len := _player.action_length("pushbutton")
	var react := "squirt-small" if hit else "sidestep-left"
	var react_at := 2.7 if hit else 2.5
	var length := maxf(push_len, react_at + _flunky.action_length(react))
	length = maxf(length, 3.4)
	var contacted := false
	await _play(length, func(elapsed: float) -> void:
		_player.pose_action("pushbutton", elapsed)
		if elapsed >= react_at:
			_flunky.pose_action(react, elapsed - react_at)
		if elapsed >= 1.0:
			flower.visible = true
			var grown := clampf((elapsed - 1.0) / 0.5, 0.0, 1.0)
			if elapsed < 2.5:
				flower.scale = Vector3.ONE * lerpf(0.01, 1.5, grown)
			elif elapsed > 2.8:
				var shrink := clampf((elapsed - 2.8) / 0.5, 0.0, 1.0)
				flower.scale = Vector3.ONE * lerpf(1.5, 0.01, shrink)
		if elapsed >= 2.5 and elapsed < 3.0:
			spray.visible = true
			var life := elapsed - 2.5
			var amount := 1.0
			if life < 0.2:
				amount = life / 0.2
			elif life > 0.3:
				amount = 1.0 - clampf((life - 0.3) / 0.2, 0.0, 1.0)
			_spray(spray, flower.global_position, _cog_world(_SUIT_HEIGHT * 0.66), 0.2 * amount)
		else:
			spray.visible = false
		if hit and elapsed >= 2.7 and not flower.has_meta("splash"):
			var splash := _make("splat")
			splash.reparent(_player, false)
			splash.position = _cog_point(_SUIT_HEIGHT * 0.66)
			_tint(splash, Color(0.75, 0.75, 1.0, 0.85))
			splash.scale = Vector3.ONE * 0.2
			flower.set_meta("splash", splash)
		if flower.has_meta("splash"):
			var splash := flower.get_meta("splash") as Node3D
			if elapsed > 3.3:
				splash.visible = false
			else:
				_billboard(splash)
		var sound := "AA_squirt_flowersquirt.mp3" if hit else "AA_squirt_flowersquirt_miss.mp3"
		_once("squirt", elapsed, 2.1, _SFX + sound)
		if not contacted and elapsed >= react_at:
			contacted = true
			on_contact.call()
	)
	_player.end_action("pushbutton")
	_flunky.end_action(react)


func _squirt_prop(prop_name: String, hit: bool, on_contact: Callable) -> void:
	var prop := _make(prop_name)
	_parent_hand(prop, "def_joint_right_hold")
	var spray := _make("spray")
	spray.visible = false
	_tint(spray, Color(0.75, 0.75, 1.0, 0.8))
	var push_len := maxf(_player.action_length("pushbutton"), 2.6)
	var react := "squirt-small" if hit else "sidestep-left"
	var length := maxf(push_len, 2.7 + _flunky.action_length(react))
	var contacted := false
	await _play(length, func(elapsed: float) -> void:
		_player.pose_action("pushbutton", elapsed)
		prop.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf(elapsed / 0.4, 0.0, 1.0))
		if elapsed >= 2.5:
			_flunky.pose_action(react, elapsed - 2.5)
		if elapsed >= 1.6 and elapsed < 2.8:
			spray.visible = true
			_spray(spray, prop.global_position, _cog_world(_SUIT_HEIGHT * 0.66), 0.35)
		else:
			spray.visible = false
		if not contacted and elapsed >= 2.5:
			contacted = true
			on_contact.call()
	)
	_player.end_action("pushbutton")
	_flunky.end_action(react)


func _drop(prop_name: String, hit: bool, on_contact: Callable) -> void:
	var button := _make("button")
	_parent_hand(button, "def_joint_left_hold")
	button.scale = Vector3.ONE
	var prop := _make(prop_name)
	prop.visible = false
	prop.reparent(_player, false)
	var react := "drop-react" if hit else "sidestep-right"
	if _flunky.action_length(react) <= 0.0:
		react = "pie-small" if hit else "sidestep-right"
	# MovieDrop: the button is pressed, then the object appears and falls.
	var appear := 4.3
	var land := appear + 0.6
	var length := maxf(_player.action_length("pushbutton"), land + _flunky.action_length(react))
	var contacted := false
	var start := _cog_point(_SUIT_HEIGHT + 14.0)
	var rest := _cog_point(1.2)
	await _play(length, func(elapsed: float) -> void:
		_player.pose_action("pushbutton", elapsed)
		if elapsed >= appear:
			prop.visible = true
			var fallen := clampf((elapsed - appear) / 0.6, 0.0, 1.0)
			prop.position = start.lerp(rest, fallen)
			prop.scale = Vector3.ONE
		if elapsed >= land:
			_flunky.pose_action(react, elapsed - land)
		if not contacted and elapsed >= land:
			contacted = true
			on_contact.call()
	)
	_player.end_action("pushbutton")
	_flunky.end_action(react)


func _lob_to_feet(prop_name: String, hit: bool, on_contact: Callable) -> void:
	var prop := _make(prop_name)
	_parent_hand(prop, "def_joint_right_hold")
	var throw_len := _player.action_length("throw")
	var land_at := _PIE_HITS
	var length := maxf(throw_len, land_at + 0.4)
	var contacted := false
	await _play(length, func(elapsed: float) -> void:
		_player.pose_action("throw", elapsed)
		if elapsed < _PIE_LEAVES:
			prop.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf(elapsed, 0.0, 1.0))
		else:
			if not prop.has_meta("from"):
				prop.reparent(_player, true)
				prop.set_meta("from", prop.position)
			var start := prop.get_meta("from") as Vector3
			var flown := clampf((elapsed - _PIE_LEAVES) / (_PIE_HITS - _PIE_LEAVES), 0.0, 1.0)
			prop.position = start.lerp(_cog_point(0.2), flown)
		if not contacted and elapsed >= land_at:
			contacted = true
			on_contact.call()
	)
	_player.end_action("throw")


func _hold(prop_name: String, on_contact: Callable) -> void:
	var prop := _make(prop_name)
	_parent_hand(prop, "def_joint_right_hold")
	var length := maxf(_player.action_length("throw"), 2.2)
	var contacted := false
	await _play(length, func(elapsed: float) -> void:
		_player.pose_action("throw", elapsed)
		prop.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf(elapsed / 0.5, 0.0, 1.0))
		if not contacted and elapsed >= 1.2:
			contacted = true
			on_contact.call()
	)
	_player.end_action("throw")


func _clip_on_tie(hit: bool, on_contact: Callable) -> void:
	# Flunky is a C body, so MovieSuitAttacks uses the short throw timing.
	var tie := _make("clip-on-tie")
	_parent_joint(tie, _flunky, "joint_Rhold", "tie")
	var throw_at := 1.45
	var react_at := 2.61 if hit else 2.34
	var toon_anim := "conked" if hit else "sidestep-left"
	var suit_len := _flunky.action_length("throw-paper")
	var length := maxf(suit_len, react_at + _player.action_length(toon_anim))
	length = maxf(length, throw_at + 1.2)
	var contacted := false
	var left := false
	await _play(length, func(elapsed: float) -> void:
		_flunky.pose_action("throw-paper", elapsed)
		if elapsed < 0.5:
			tie.scale = Vector3.ONE * lerpf(0.01, 1.0, elapsed / 0.5)
		if elapsed >= throw_at and not left:
			left = true
			tie.reparent(_player, true)
		if left:
			if not tie.has_meta("from"):
				tie.set_meta("from", tie.position)
			var start := tie.get_meta("from") as Vector3
			var flown := clampf((elapsed - throw_at) / (0.4 if hit else 0.8), 0.0, 1.0)
			var target := _toon_point(2.3 if hit else 0.15)
			if not hit:
				target += _side() * 2.4
			tie.position = start.lerp(target, flown)
			if not hit and flown >= 1.0:
				tie.scale = Vector3.ONE * lerpf(1.0, 0.01, clampf((elapsed - throw_at - 0.8) / 1.2, 0.0, 1.0))
		if elapsed >= react_at:
			_player.pose_action(toon_anim, elapsed - react_at)
		_once("tie", elapsed, throw_at + 1.0, _SFX + "SA_powertie_throw.mp3")
		if not hit:
			_once("step", elapsed, react_at, _SFX + "AV_side_step.mp3")
		if not contacted and elapsed >= react_at:
			contacted = true
			on_contact.call()
	)
	_flunky.end_action("throw-paper")
	_player.end_action(toon_anim)


func _pound_key(hit: bool, on_contact: Callable) -> void:
	var phone := _make("phone")
	var receiver := _make("receiver")
	_parent_joint(phone, _flunky, "joint_Lhold", "phone")
	_parent_joint(receiver, _flunky, "joint_Lhold", "receiver_left")
	var marks: Array[Label3D] = []
	for _index in 6:
		var mark := Label3D.new()
		mark.text = "#"
		mark.font_size = 84
		mark.modulate = Color(0.02, 0.02, 0.02)
		mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mark.no_depth_test = true
		mark.visible = false
		add_child(mark)
		_spawned.append(mark)
		marks.append(mark)
	var toon_anim := "cringe" if hit else "sidestep-left"
	var react_at := 2.7 if hit else 1.9
	var suit_len := _flunky.action_length("phone")
	var length := maxf(suit_len, 5.8)
	length = maxf(length, react_at + _player.action_length(toon_anim))
	var contacted := false
	var moved := false
	await _play(length, func(elapsed: float) -> void:
		_flunky.pose_action("phone", elapsed)
		if elapsed < 0.8:
			var grown := clampf((elapsed - 0.3) / 0.5, 0.0, 1.0)
			phone.scale = Vector3.ONE * lerpf(0.01, 1.0, grown)
			receiver.scale = phone.scale
		if elapsed >= 1.54 and not moved:
			moved = true
			_parent_joint(receiver, _flunky, "joint_Rhold", "receiver_right")
			receiver.scale = Vector3.ONE
		if elapsed >= 4.68:
			receiver.reparent(phone, true)
		if elapsed >= 5.3:
			var shrink := clampf((elapsed - 5.3) / 0.5, 0.0, 1.0)
			phone.scale = Vector3.ONE * lerpf(1.0, 0.01, shrink)
		if elapsed >= react_at:
			_player.pose_action(toon_anim, elapsed - react_at)
		_once("hangup", elapsed, 1.3, _SFX + "SA_hangup.mp3")
		if not hit:
			_once("step", elapsed, react_at, _SFX + "AV_side_step.mp3")
		var burst := clampf((elapsed - 2.1) / 1.55, 0.0, 1.0)
		for index in marks.size():
			var mark := marks[index]
			mark.visible = elapsed >= 2.1 and elapsed <= 3.7
			if not mark.visible:
				continue
			var delay := float(index) * 0.08
			var along := clampf((burst - delay) / 0.55, 0.0, 1.0)
			var from := phone.global_position
			var to := _player.global_position + Vector3(0.0, 2.4, 0.0)
			mark.global_position = from.lerp(to, along) + Vector3(sin(float(index)), 0.2, cos(float(index))) * 0.35
		if not contacted and elapsed >= react_at:
			contacted = true
			on_contact.call()
	)
	_flunky.end_action("phone")
	_player.end_action(toon_anim)


func _shred(hit: bool, on_contact: Callable) -> void:
	var paper := _make("shredder-paper")
	var shredder := _make("shredder")
	_parent_joint(paper, _flunky, "joint_Rhold", "paper")
	_parent_joint(shredder, _flunky, "joint_Lhold", "shredder")
	paper.visible = false
	shredder.scale = Vector3(0.01, 0.01, 0.01)
	var suit_len := maxf(_flunky.action_length("shredder"), 4.0)
	var react_at := suit_len - (1.1 if hit else 3.1)
	var toon_anim := "conked" if hit else "sidestep-left"
	var length := maxf(suit_len, react_at + _player.action_length(toon_anim))
	var contacted := false
	await _play(length, func(elapsed: float) -> void:
		_flunky.pose_action("shredder", elapsed)
		if elapsed >= 1.0:
			var grown := clampf((elapsed - 1.0) / 0.5, 0.0, 1.0)
			shredder.scale = Vector3.ONE * lerpf(0.01, 4.81, grown)
		if elapsed >= 2.4:
			paper.visible = true
			paper.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf((elapsed - 2.4) / 0.2, 0.0, 1.0))
		if elapsed >= react_at:
			_player.pose_action(toon_anim, elapsed - react_at)
		_once("shred", elapsed, 3.4, _SFX + "SA_shred.mp3")
		if not hit:
			_once("step", elapsed, react_at, _SFX + "AV_side_step.mp3")
		if not contacted and elapsed >= react_at:
			contacted = true
			on_contact.call()
	)
	_flunky.end_action("shredder")
	_player.end_action(toon_anim)


func _duck(elapsed: float, duck_len: float) -> void:
	if duck_len <= 0.0 or elapsed < 1.0:
		return
	var local := elapsed - 1.0
	if local <= duck_len:
		_player.pose_action("duck", local)
		return
	if 1.8 >= duck_len:
		return
	var into := local - duck_len
	if into <= duck_len - 1.8:
		_player.pose_action("duck", 1.8 + into)


func _prepare_death() -> void:
	if _gear_mat != null:
		return
	_gear_mat = _card_material(_PROPS + "gear.glb", true)
	var packed := load(_PROPS + "explosion.glb") as PackedScene
	if packed == null:
		return
	var root := packed.instantiate()
	for index in 10:
		var found := root.find_child("boom%d" % index, true, false) as MeshInstance3D
		if found == null or found.mesh == null:
			continue
		if _boom_mats.is_empty():
			_boom_size = _card_size(found.mesh)
		var material := _sprite_material(found.get_active_material(0))
		if material != null:
			_boom_mats.append(material)
	root.free()


func _card_material(path: String, remember_size: bool) -> Material:
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var root := packed.instantiate()
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	var material: Material = null
	if not meshes.is_empty():
		var mesh_node := meshes[0] as MeshInstance3D
		if mesh_node.mesh != null and remember_size:
			_gear_size = _card_size(mesh_node.mesh)
		material = _sprite_material(mesh_node.get_active_material(0))
	root.free()
	return material


func _sprite_material(source: Material) -> Material:
	if source == null:
		return null
	var material := source.duplicate() as BaseMaterial3D
	if material == null:
		return source
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _card_size(mesh: Mesh) -> Vector2:
	var size := mesh.get_aabb().size
	var wide := maxf(size.x, maxf(size.y, size.z))
	var thin := minf(size.x, minf(size.y, size.z))
	var mid := size.x + size.y + size.z - wide - thin
	return Vector2(maxf(wide, 0.05), maxf(mid, 0.05))


func _spawn_gear(origin: Vector3, radius: float, amplitude: float, lift: float, scale: float, life: float) -> void:
	if _gear_mat == null:
		return
	var gear := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = _gear_size
	gear.mesh = quad
	gear.material_override = _gear_mat
	var span := maxf(_gear_size.x, _gear_size.y)
	var fitted := scale
	if span > 0.01:
		fitted = minf(scale, 0.55 / span)
	gear.scale = Vector3.ONE * fitted
	add_child(gear)
	var offset := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if offset.length_squared() > 1.0:
		offset = offset.normalized()
	elif offset.length_squared() < 0.0001:
		offset = Vector3.UP
	gear.global_position = origin + Vector3(0.0, -2.0, 0.0) + offset * radius
	_gears.append({
		"node": gear,
		"velocity": offset.normalized() * amplitude,
		"accel": Vector3(0.0, lift, 0.0),
		"life": life,
	})


func _tick_gears(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for item in _gears:
		var record: Dictionary = item
		var node := record["node"] as MeshInstance3D
		if not is_instance_valid(node):
			continue
		var velocity: Vector3 = record["velocity"]
		var accel: Vector3 = record["accel"]
		velocity += accel * delta
		node.global_position += velocity * delta
		record["velocity"] = velocity
		var life := float(record["life"]) - delta
		record["life"] = life
		if life > 0.0:
			kept.append(record)
		else:
			node.queue_free()
	_gears = kept


func _clear_gears() -> void:
	for item in _gears:
		var record: Dictionary = item
		var node := record["node"] as MeshInstance3D
		if is_instance_valid(node):
			node.queue_free()
	_gears.clear()


func _show_boom(at: Vector3, into: float) -> void:
	if _boom_mats.is_empty():
		return
	if _boom == null:
		_boom = MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = _boom_size
		_boom.mesh = quad
		add_child(_boom)
	_boom.visible = true
	_boom.global_position = at
	var span := maxf(_boom_size.x, _boom_size.y)
	var world := 0.4 * span
	world = clampf(world, 5.0, 8.0)
	_boom.scale = Vector3.ONE * (world / maxf(span, 0.01))
	var frame := mini(int(into * 24.0), _boom_mats.size() - 1)
	_boom.material_override = _boom_mats[frame]


func _hide_boom() -> void:
	if _boom != null:
		_boom.visible = false


func _death_sound(file_name: String, volume: float, from_time: float, duration: float) -> void:
	var stream := load(_SFX + file_name) as AudioStream
	if stream == null:
		return
	_death_player = AudioStreamPlayer.new()
	_death_player.stream = stream
	_death_player.volume_db = linear_to_db(volume)
	add_child(_death_player)
	_death_player.finished.connect(_death_player.queue_free)
	_death_player.play(from_time)
	if duration > 0.0:
		get_tree().create_timer(duration).timeout.connect(_cut_death_sound.bind(_death_player), CONNECT_ONE_SHOT)


func _cut_death_sound(player: AudioStreamPlayer) -> void:
	if is_instance_valid(player) and player == _death_player:
		_stop_death_sound()


func _stop_death_sound() -> void:
	if _death_player == null or not is_instance_valid(_death_player):
		_death_player = null
		return
	_death_player.stop()
	_death_player.queue_free()
	_death_player = null


func show_reward() -> void:
	_begin_shot("reward", 0.0)


func hide_reward() -> void:
	_end_shot()


func tick_shot(delta: float) -> void:
	if _shot == "" or _camera == null or _player == null or _flunky == null:
		return
	_shot_time += delta
	var toon_height := 3.5
	if _shot == "toon":
		if _shot_time < _shot_open:
			_frame(_player, _flunky, _shot_side * 3.0, 4.6, toon_height * 0.66)
		else:
			_frame(_flunky, _player, -_shot_side * 4.0, 4.4, _SUIT_HEIGHT * 0.66)
	elif _shot == "cog":
		if _shot_time < _shot_open:
			_frame(_flunky, _player, _shot_side * 3.4, 4.8, _SUIT_HEIGHT * 0.55)
		else:
			_frame(_player, _flunky, -_shot_side * 3.0, 4.2, toon_height * 0.66)
	elif _shot == "death":
		# BattleCamDefaultFov is 80, and the suit close-up sits about 8 units
		# out. Step further back once the pieces leave his body.
		var side := _shot_side * (6.0 if _shot_time < _shot_open else 9.0)
		var ahead := 8.0 if _shot_time < _shot_open else 12.0
		_frame(_flunky, _player, side, ahead, _SUIT_HEIGHT * 0.66)
	else:
		_frame(_player, _flunky, _shot_side * 2.0, -6.5, toon_height * 0.85)


func _begin_shot(mode: String, open_for: float) -> void:
	_shot = mode
	_shot_time = 0.0
	_shot_open = open_for
	_shot_side = 1.0 if randi() % 2 == 0 else -1.0
	if mode == "death" and _camera != null and _saved_fov < 0.0:
		_saved_fov = _camera.fov
		_camera.fov = 80.0
	tick_shot(0.0)


func _end_shot() -> void:
	_shot = ""
	if _saved_fov >= 0.0 and _camera != null:
		_camera.fov = _saved_fov
		_saved_fov = -1.0


func _frame(actor: Node3D, other: Node3D, side: float, ahead: float, height: float) -> void:
	var forward := other.global_position - actor.global_position
	forward.y = 0.0
	if forward.length_squared() < 0.04:
		forward = Vector3(0.0, 0.0, -1.0)
	else:
		forward = forward.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var look := actor.global_position + Vector3(0.0, height, 0.0)
	var pos := actor.global_position + right * side + forward * ahead + Vector3(0.0, height, 0.0)
	if pos.distance_squared_to(look) < 0.36:
		pos = look - forward * 4.0
	_camera.global_position = pos
	_camera.look_at(look, Vector3.UP)


func _play(length: float, step: Callable) -> void:
	var elapsed := 0.0
	while elapsed < length:
		step.call(elapsed)
		await get_tree().process_frame
		if not is_inside_tree():
			return
		elapsed += get_process_delta_time()
	step.call(length)


func _gag_name(track: int, level: int) -> String:
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
	_two_sided(model)
	return wrap


func _parent_hand(prop: Node3D, joint_name: String) -> void:
	var joint := _joint(_player, joint_name)
	if joint == null:
		prop.reparent(_player, false)
		return
	prop.reparent(joint, false)
	prop.transform = Transform3D.IDENTITY
	prop.scale = Vector3(0.01, 0.01, 0.01)


func _parent_joint(prop: Node3D, host: Node, joint_name: String, pose_name: String) -> void:
	var joint := _joint(host, joint_name)
	if joint == null:
		return
	prop.reparent(joint, false)
	prop.transform = _pose(pose_name)
	prop.scale = Vector3(0.01, 0.01, 0.01)


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
	var basis := Basis(
		Vector3(float(x[0]), float(x[1]), float(x[2])),
		Vector3(float(y[0]), float(y[1]), float(y[2])),
		Vector3(float(z[0]), float(z[1]), float(z[2]))
	)
	return Transform3D(basis, Vector3(float(origin[0]), float(origin[1]), float(origin[2])))


func _joint(host: Node, joint_name: String) -> Node3D:
	if host == null:
		return null
	return host.find_child(joint_name, true, false) as Node3D


func _hand_point(joint_name: String) -> Vector3:
	var joint := _joint(_player, joint_name)
	if joint == null:
		return _player.global_position + Vector3(0, 1.5, 0)
	return joint.global_position


func _cog_point(height: float) -> Vector3:
	return _player.to_local(_cog_world(height))


func _cog_world(height: float) -> Vector3:
	if _flunky == null:
		return Vector3.ZERO
	return _flunky.global_position + Vector3(0.0, height, 0.0)


func _toon_point(height: float) -> Vector3:
	return _player.to_local(_player.global_position + Vector3(0.0, height, 0.0))


func _side() -> Vector3:
	var away := _flunky.global_position - _player.global_position
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(0, 0, -1)
	return _player.to_local(_player.global_position + away.cross(Vector3.UP).normalized()) - _player.to_local(_player.global_position)


func _spray(spray: Node3D, from_world: Vector3, to_world: Vector3, width: float) -> void:
	var origin := _player.to_local(from_world)
	var target := _player.to_local(to_world)
	var dir := target - origin
	var distance := dir.length()
	if distance < 0.05:
		spray.visible = false
		return
	var y := dir / distance
	var up := Vector3(0, 0, 1)
	if absf(y.dot(up)) > 0.95:
		up = Vector3(1, 0, 0)
	var x := up.cross(y).normalized()
	var z := y.cross(x).normalized()
	var reach := distance / 1.5
	spray.reparent(_player, false)
	spray.transform = Transform3D(Basis(x, y, z).scaled(Vector3(reach * width, reach, reach * width)), origin)


func _billboard(node: Node3D) -> void:
	if _camera == null or _player == null:
		return
	var origin := node.position
	var cam := _player.to_local(_camera.global_position)
	var z := cam - origin
	if z.length() < 0.05:
		return
	z = z.normalized()
	var up := Vector3(0, 1, 0)
	if absf(z.dot(up)) > 0.95:
		up = Vector3(1, 0, 0)
	var x := up.cross(z).normalized()
	var y := z.cross(x).normalized()
	var size := node.scale
	node.transform = Transform3D(Basis(x, y, z), origin)
	node.scale = size


func _tint(node: Node, color: Color) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var material := mesh_node.get_active_material(0)
		var tint := StandardMaterial3D.new()
		if material is StandardMaterial3D:
			tint = (material as StandardMaterial3D).duplicate() as StandardMaterial3D
		tint.albedo_color = color
		tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tint.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh_node.material_override = tint


func _two_sided(node: Node) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		for index in mesh_node.mesh.get_surface_count():
			var material := mesh_node.mesh.surface_get_material(index)
			if material is BaseMaterial3D:
				(material as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED


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


func _throw_hit_sound(level: int) -> String:
	if level <= 0:
		return "AA_tart_only.mp3"
	if level >= 5:
		return "AA_wholepie_only.mp3"
	return "AA_slice_only.mp3"


func _once(id: String, elapsed: float, at: float, path: String) -> void:
	if elapsed < at or bool(_fired.get(id, false)):
		return
	_fired[id] = true
	_sfx(path)


func _sfx(path: String) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _clear_props() -> void:
	for node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()
