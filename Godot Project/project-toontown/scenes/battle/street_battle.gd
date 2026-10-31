class_name StreetBattle
extends Node

## A one-toon street battle, the way DistributedBattle plays a round:
## both walk onto the zone's battle cell, the toon picks a gag, that
## attack resolves, then the cog attacks. It repeats until one of them
## runs out of health.

const APPROACH := 7.0
# TownLoader.battleMusic. BattlePlace.enterBattle plays it at 0.9 and
# stops the street track. exitBattle brings the street track back at 0.8.
const BATTLE_MUSIC := "res://assets/audio/battle/encntr_general_bg.mp3"
const BATTLE_VOLUME := 0.9
const PLACE_VOLUME := 0.8
# BattleBase points for one suit and one toon, and the face-off timing.
# The suit walks to local (0, 5) heading 179. The toon runs to (0, -6) heading 0.
const _SUIT_SPEED := 4.8
const _SUIT_REACH := 5.0
const _TOON_REACH := 6.0
const _FACEOFF_TAUNT := 3.5
const _FACEOFF_FOV := 30.0
# BattleCamDefaultPos (0, -8.6, 16.5), menu lens 65, movie lens 80.
const _MENU_FOV := 65.0
const _MOVIE_FOV := 80.0
const _MENU_BACK := 8.6
const _MENU_HEIGHT := 16.5
const _SUIT_HEIGHT := 4.88
const _RUN_STEPS := "res://assets/audio/sfx/AV_footstep_runloop.mp3"
# MovieToonVictory loops ENC_Win for the whole reward dance.
const _WIN := "res://assets/audio/sfx/ENC_Win.mp3"
const _ATTACKS: Array[Dictionary] = [
	{
		"name": "Pound Key!",
		"line": "Time to return some calls.",
		"hp": 2,
		"acc": 75,
		"freq": 30,
	},
	{
		"name": "Shred!",
		"line": "I need to get rid of some hazardous waste.",
		"hp": 3,
		"acc": 50,
		"freq": 10,
	},
	{
		"name": "Clip On Tie!",
		"line": "You should dress for success.",
		"hp": 1,
		"acc": 75,
		"freq": 60,
	},
]

var _host: Node
var _body: CharacterBody3D
var _player: ToonActor
var _flunky: Flunky
var _loadout: ToonLoadout
var _tasks: ToonTasks
var _camera: Camera3D
var _meter: LaffMeter
var _book: ShtickerBook
var _hud: CanvasLayer
var _menu: BattleMenu
var _card: Panel
var _hp_fill: ColorRect
var _marker: MeshInstance3D
var _active := false
var _cool := 0.0
var _cog_hp := 1
var _cog_max_hp := 1
var _level_label: Label
var _gained: Dictionary = {}
var _spent: Array[Vector2i] = []
var _battle_music: AudioStreamPlayer
var _place_music: AudioStreamPlayer
var _movie: BattleMovie
var _dancing := false
var _dance := 0.0
var _dance_sound: AudioStreamPlayer
var _place_fov := 52.0


func setup(host: Node, body: CharacterBody3D, player: ToonActor, flunky: Flunky, loadout: ToonLoadout, tasks: ToonTasks, camera: Camera3D, meter: LaffMeter, book: ShtickerBook, hud: CanvasLayer) -> void:
	_host = host
	_body = body
	_player = player
	_flunky = flunky
	_loadout = loadout
	_tasks = tasks
	_camera = camera
	_meter = meter
	_book = book
	_hud = hud
	_menu = BattleMenu.new()
	_menu.name = "BattleMenu"
	_menu.visible = false
	_hud.add_child(_menu)
	_menu.setup(loadout)
	_apply_cog_vitals()
	_build_card()
	_movie = BattleMovie.new()
	_movie.name = "BattleMovie"
	add_child(_movie)
	_movie.setup(player, flunky, camera)


func active() -> bool:
	return _active


func hides_flunky_tag() -> bool:
	return _active or (_flunky != null and not _flunky.visible)


func consider(where: Vector3) -> void:
	if _active or _cool > 0.0 or _flunky == null or not _flunky.on_street():
		return
	if where.x > -16.5:
		return
	if where.distance_to(_flunky.global_position) > APPROACH:
		return
	_active = true
	_run()


func _exit_tree() -> void:
	_stop_dance_sound()
	if _loadout != null:
		_loadout.clear_tutorial_accuracy()


func _process(delta: float) -> void:
	if _cool > 0.0:
		_cool = maxf(_cool - delta, 0.0)
	if _movie != null:
		_movie.tick_shot(delta)
	if _dancing and _player != null:
		_dance += delta
		var length := _player.action_length("victory")
		if length > 0.05:
			_player.pose_action("victory", fposmod(_dance, length))
	if _card == null:
		return
	var show := _active and _flunky != null and _flunky.visible and _camera != null
	_card.visible = show
	if not show:
		return
	var point := _flunky.global_position + Vector3(0, 3.9, 0)
	if _camera.is_position_behind(point):
		_card.visible = false
		return
	var screen := _camera.unproject_position(point)
	_card.position = screen - _card.size * 0.5


func _run() -> void:
	_gained.clear()
	_spent.clear()
	_apply_cog_vitals()
	_set_cog_bar()
	if _book != null:
		_book.close()
	var panel := _hud.get_node_or_null("GagPanel")
	if panel != null:
		panel.visible = false
	_body.velocity = Vector3.ZERO
	_player.set_locomotion(0.0, false, false, 0.0)
	_flunky.stop_for_battle()
	_start_battle_music()
	if _camera != null:
		_place_fov = _camera.fov
	# The face-off and the attack movies frame the toon. Hiding them is only
	# for a quest close-up that looks through their standing spot.
	_host.call("set_cutscene", true, false)
	await _face_off()
	_ensure_marker()
	_show_meter()
	_loadout.grant_tutorial_accuracy()
	while _cog_hp > 0 and _loadout.hp > 0:
		_aim(true)
		var pick := await _menu.choose()
		if pick.x >= 0:
			await _toon_attack(pick.x, pick.y)
		if _cog_hp <= 0 or _loadout.hp <= 0:
			break
		await _cog_attack()
	# Combat is over. Take the sure-hit bonus off before the reward or a retry.
	_loadout.clear_tutorial_accuracy()
	if _cog_hp <= 0:
		await _defeat_cog()
		_marker.visible = false
		_card.visible = false
		await _reward_movie()
	else:
		await _toon_went_sad()
		_marker.visible = false
		_card.visible = false
	_stop_battle_music()
	_loadout.clear_tutorial_accuracy()
	if _camera != null:
		_camera.fov = _place_fov
	_host.call("set_cutscene", false)
	_active = false
	_cool = 1.5


func _start_battle_music() -> void:
	_place_music = _place_track(_host)
	if _place_music != null:
		_place_music.stop()
	var stream := load(BATTLE_MUSIC) as AudioStreamMP3
	if stream == null:
		return
	stream = stream.duplicate() as AudioStreamMP3
	stream.loop = true
	_battle_music = ToonAudio.music_player()
	_battle_music.name = "BattleMusic"
	_battle_music.stream = stream
	_battle_music.volume_db = linear_to_db(BATTLE_VOLUME)
	add_child(_battle_music)
	_battle_music.play()


func _start_dance_sound() -> void:
	var stream := load(_WIN) as AudioStreamMP3
	if stream == null:
		return
	stream = stream.duplicate() as AudioStreamMP3
	stream.loop = true
	_dance_sound = ToonAudio.effect_player()
	_dance_sound.name = "WinDance"
	_dance_sound.stream = stream
	add_child(_dance_sound)
	_dance_sound.play()


func _stop_dance_sound() -> void:
	if _dance_sound == null:
		return
	_dance_sound.stop()
	_dance_sound.queue_free()
	_dance_sound = null


func _stop_battle_music() -> void:
	if _battle_music != null:
		_battle_music.stop()
		_battle_music.queue_free()
		_battle_music = null
	if _place_music != null and is_instance_valid(_place_music):
		_place_music.volume_db = linear_to_db(PLACE_VOLUME)
		_place_music.play()
	_place_music = null


func _place_track(node: Node) -> AudioStreamPlayer:
	var current := node
	while current != null:
		for child in current.get_children():
			var player := child as AudioStreamPlayer
			if player != null and str(player.name).ends_with("Music") and player.name != "BattleMusic":
				return player
		current = current.get_parent()
	return null


func _reward_movie() -> void:
	var movie = load("res://scenes/interiors/tutorial_reward.gd").new()
	movie.name = "TutorialReward"
	add_child(movie)
	await movie.play(_host, _body, _player, _camera)
	movie.queue_free()


## The street's suit planner picks the cell. Whichever cog started the
## fight walks onto it; a Flunky is only the tutorial's suit.
func _zone_battle_cell() -> Vector3:
	var found: Variant = _host.call("battle_cell")
	return found as Vector3


## DistributedBattle.__faceOff. The battle cell faces the cog. Both stay
## put for the taunt, then the cog walks and the toon runs onto their points.
func _face_off() -> void:
	var cell := _zone_battle_cell()
	var suit_pos := _flunky.global_position
	var toon_pos := _body.global_position
	var toward := Vector3(suit_pos.x - cell.x, 0.0, suit_pos.z - cell.z)
	if toward.length() < 0.05:
		toward = Vector3(toon_pos.x - cell.x, 0.0, toon_pos.z - cell.z)
	if toward.length() < 0.05:
		toward = Vector3(0.0, 0.0, -1.0)
	toward = toward.normalized()
	var battle_heading := _heading_toward(cell, cell + toward)
	_host.call("face_actor", _player, _heading_toward(toon_pos, suit_pos))
	_flunky.face_heading(_heading_toward(suit_pos, toon_pos))
	if _camera != null:
		_camera.fov = _FACEOFF_FOV
		_aim_taunt(suit_pos)
	await _say(_flunky.global_position + Vector3(0, 4.6, 0), "You're not going to like the way I work.", _FACEOFF_TAUNT, false, true)
	if _camera != null:
		_camera.fov = _MOVIE_FOV
	var suit_dest := Vector3(cell.x + toward.x * _SUIT_REACH, suit_pos.y, cell.z + toward.z * _SUIT_REACH)
	var toon_dest := Vector3(cell.x - toward.x * _TOON_REACH, toon_pos.y, cell.z - toward.z * _TOON_REACH)
	if toon_pos.distance_squared_to(toon_dest) > 0.04:
		_host.call("face_actor", _player, _heading_toward(toon_pos, toon_dest))
	if suit_pos.distance_squared_to(suit_dest) > 0.04:
		_flunky.face_heading(_heading_toward(suit_pos, suit_dest))
	_aim_walk(cell, toward, suit_pos)
	var facing := Vector3(cell.x - suit_pos.x, 0.0, cell.z - suit_pos.z)
	if facing.length() < 0.001:
		facing = -toward
	else:
		facing = facing.normalized()
	var timed := Vector3(cell.x - facing.x * 6.0, 0.0, cell.z - facing.z * 6.0)
	var distance := Vector2(timed.x - suit_pos.x, timed.z - suit_pos.z).length()
	var duration := maxf(distance / _SUIT_SPEED, 0.05)
	var steps := _run_steps()
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().process_frame
		var delta := get_process_delta_time()
		elapsed += delta
		var along := clampf(elapsed / duration, 0.0, 1.0)
		_body.global_position.x = lerpf(toon_pos.x, toon_dest.x, along)
		_body.global_position.z = lerpf(toon_pos.z, toon_dest.z, along)
		_flunky.global_position.x = lerpf(suit_pos.x, suit_dest.x, along)
		_flunky.global_position.z = lerpf(suit_pos.z, suit_dest.z, along)
		_player.play_run(delta)
		_flunky.play_walk(delta)
	_body.global_position.x = toon_dest.x
	_body.global_position.z = toon_dest.z
	_flunky.global_position.x = suit_dest.x
	_flunky.global_position.z = suit_dest.z
	_host.call("face_actor", _player, battle_heading)
	_flunky.face_heading(battle_heading + 179.0)
	_player.set_locomotion(0.0, false, false, 0.0)
	_flunky.stop_for_battle()
	if steps != null:
		steps.stop()
		steps.queue_free()


func _aim_taunt(suit_pos: Vector3) -> void:
	var heading := _heading_toward(suit_pos, _body.global_position)
	var axes := _heading_basis(heading)
	var forward := axes * Vector3(0.0, 1.0, 0.0)
	var right := axes * Vector3(1.0, 0.0, 0.0)
	var side: float = 5.0 if randi() % 2 == 0 else -5.0
	var chest := maxf(_SUIT_HEIGHT * 0.66, _SUIT_HEIGHT - 1.8)
	var heights: Array[float] = [chest, 1.0, 11.0]
	var height: float = heights[randi() % heights.size()]
	var cam := suit_pos + right * side + forward * 16.0 + Vector3(0.0, height, 0.0)
	_look_from(cam, suit_pos + Vector3(0.0, _SUIT_HEIGHT, 0.0))


func _aim_walk(cell: Vector3, toward: Vector3, suit_pos: Vector3) -> void:
	var ground_y := _body.global_position.y
	var cam := Vector3(cell.x - toward.x * 10.0, ground_y + 4.0, cell.z - toward.z * 10.0)
	_look_from(cam, suit_pos + Vector3(0.0, _SUIT_HEIGHT * 0.5, 0.0))


func _look_from(pos: Vector3, at: Vector3) -> void:
	if _camera == null:
		return
	_camera.global_position = pos
	if pos.distance_squared_to(at) > 0.04:
		_camera.look_at(at, Vector3.UP)


func _heading_basis(heading: float) -> Basis:
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	return upright.rotated(Vector3.UP, deg_to_rad(heading))


func _run_steps() -> AudioStreamPlayer:
	var stream := load(_RUN_STEPS) as AudioStreamMP3
	if stream == null:
		return null
	stream = stream.duplicate() as AudioStreamMP3
	stream.loop = true
	var player := ToonAudio.effect_player()
	player.name = "RunSteps"
	player.stream = stream
	add_child(player)
	player.play()
	return player


func _face_each_other() -> void:
	_host.call("face_actor", _player, _heading_toward(_body.global_position, _flunky.global_position))
	_flunky.face_heading(_heading_toward(_flunky.global_position, _body.global_position))


func _heading_toward(from: Vector3, to: Vector3) -> float:
	return rad_to_deg(atan2(-(to.x - from.x), -(to.z - from.z)))


func _aim(menu_view: bool) -> void:
	if _camera == null:
		return
	var forward := _flunky.global_position - _body.global_position
	forward.y = 0.0
	if forward.length() < 0.1:
		forward = Vector3(0, 0, -1)
	else:
		forward = forward.normalized()
	# The toon stands 6 units on the near side of the cell, so the cell is
	# that far along the line toward the cog.
	var origin := _body.global_position + forward * _TOON_REACH
	origin.y = _body.global_position.y
	if menu_view:
		# BattleCamDefaultPos, pitched down toward the cell, menu lens 65.
		_camera.fov = _MENU_FOV
		_camera.global_position = origin - forward * _MENU_BACK + Vector3(0, _MENU_HEIGHT, 0)
		_camera.look_at(origin + Vector3(0, 2.0, 0), Vector3.UP)
	else:
		# allGroupLowShot sits 15 units off the cell at height 3.
		_camera.fov = _MOVIE_FOV
		var side := forward.cross(Vector3.UP).normalized()
		_camera.global_position = origin + side * 15.0 + Vector3(0, 3.0, 0)
		_camera.look_at(origin + Vector3(0, 1.8, 0), Vector3.UP)


func _toon_attack(track: int, level: int) -> void:
	if not _loadout.spend_gag(track, level):
		return
	_spent.append(Vector2i(track, level))
	_gained[track] = int(_gained.get(track, 0)) + ToonLoadout.SKILL_CREDIT
	_aim(false)
	var hit := true
	if track != ToonLoadout.TOON_UP:
		hit = randi() % 100 < _loadout.rolled_accuracy(track, level)
	var at := _flunky.global_position + Vector3(0, 3.4, 0)
	await _movie.play_gag(track, level, hit, func() -> void:
		if track == ToonLoadout.TOON_UP:
			var heal := ToonLoadout.gag_damage(track, level, _loadout.experience_of(track))
			var gained := _loadout.gain_hp(heal)
			if gained > 0:
				_floater(_body.global_position + Vector3(0, 3.2, 0), "+%d" % gained, Color(0.35, 0.85, 0.35))
			return
		if not hit:
			_floater(at, "MISSED", Color(1, 1, 1))
			return
		var damage := ToonLoadout.gag_damage(track, level, _loadout.experience_of(track))
		_cog_hp = maxi(_cog_hp - damage, 0)
		_set_cog_bar()
		_pulse_marker()
		# Suit.showHpText prints the gag's damage, even when that finishes the cog.
		if damage > 0:
			_floater(at + Vector3(0, 1.2, 0), "-%d" % damage, Color(0.92, 0.08, 0.08))
	)


func _cog_attack() -> void:
	_aim(false)
	_face_each_other()
	var attack := _pick_attack()
	var banner := _banner(String(attack["name"]).to_upper())
	await _say(_flunky.global_position + Vector3(0, 4.4, 0), String(attack["line"]), 1.3)
	var hit := randi() % 100 < int(attack["acc"])
	var at := _body.global_position + Vector3(0, 2.6, 0)
	await _movie.play_cog(String(attack["name"]), hit, func() -> void:
		if hit:
			var lost := _loadout.take_damage(int(attack["hp"]))
			if lost > 0:
				_floater(at, "-%d" % lost, Color(0.92, 0.08, 0.08))
		else:
			_floater(at, "MISSED", Color(1, 1, 1))
	)
	banner.queue_free()


func _pick_attack() -> Dictionary:
	var roll := randi() % 100
	var cursor := 0
	for attack in _ATTACKS:
		cursor += int(attack["freq"])
		if roll < cursor:
			return attack
	return _ATTACKS[0]


func _defeat_cog() -> void:
	_aim(false)
	await _explode()
	_flunky.finish_lose()
	_dance = 0.0
	_dancing = true
	_start_dance_sound()
	_movie.show_reward()
	var was_done := false
	if _tasks != null:
		was_done = _tasks.is_complete(101)
		_tasks.note_cog_defeat("f")
	var before := {}
	for track in _gained.keys():
		before[int(track)] = _loadout.experience_of(int(track))
		_loadout.add_experience(int(track), int(_gained[track]))
	_loadout.save()
	var quest_line := ""
	if _tasks != null and not was_done and _tasks.is_complete(101):
		quest_line = "Defeat a Flunky : Complete"
	var panel := RewardPanel.new()
	panel.name = "RewardPanel"
	_hud.add_child(panel)
	await panel.present(_player.name, _loadout, before, _gained, quest_line, true)
	panel.queue_free()
	_dancing = false
	_stop_dance_sound()
	_movie.hide_reward()
	_player.end_action("victory")


func _toon_went_sad() -> void:
	_meter.set_hp(0, _loadout.max_hp)
	await _notice("Oh no!", "You ran out of Laff and went sad!\nLet's try that Flunky again.")
	for spent in _spent:
		_loadout.refund_gag(spent.x, spent.y)
	_loadout.set_hp(_loadout.max_hp, _loadout.max_hp)
	_loadout.save()
	_meter.set_hp(_loadout.hp, _loadout.max_hp)
	var away := _body.global_position - _flunky.global_position
	away.y = 0.0
	if away.length() < 0.2:
		away = Vector3(1, 0, 0)
	_body.global_position = _flunky.global_position + away.normalized() * 14.0 + Vector3(0, 0.2, 0)
	_host.call("face_actor", _player, _heading_toward(_body.global_position, _flunky.global_position))
	_flunky.face_heading(_heading_toward(_flunky.global_position, _body.global_position))


func _explode() -> void:
	await _movie.play_defeat()


func _notice(title: String, body: String) -> void:
	var view := _hud.get_viewport().get_visible_rect().size
	var panel := Panel.new()
	panel.size = Vector2(520, 280)
	panel.position = Vector2((view.x - panel.size.x) * 0.5, 48)
	panel.add_theme_stylebox_override("panel", _flat(Color(1.0, 0.98, 0.82), Color(0.25, 0.62, 0.28), 6, 16))
	_hud.add_child(panel)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.position = Vector2(20, 16)
	heading.size = Vector2(480, 40)
	ToonGui.style_title(heading, Color(0.1, 0.1, 0.12), 28)
	panel.add_child(heading)
	var label := Label.new()
	label.text = body
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(28, 64)
	label.size = Vector2(464, 140)
	ToonGui.style_label(label, Color(0.1, 0.12, 0.1), 20, Color(0, 0, 0, 0), 0)
	panel.add_child(label)
	var button := Button.new()
	button.text = "OK"
	button.focus_mode = Control.FOCUS_NONE
	button.position = Vector2(190, 214)
	button.size = Vector2(140, 44)
	button.add_theme_font_override("font", ToonGui.font())
	button.add_theme_font_size_override("font_size", 22)
	panel.add_child(button)
	await button.pressed
	panel.queue_free()


func _say(at: Vector3, text: String, seconds: float, aim: bool = true, tick_idle: bool = false) -> void:
	ToonSpeech.cog(text)
	if aim:
		_aim(false)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := _flat(Color(1, 1, 1, 0.96), Color(0, 0, 0), 3, 14)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(220, 0)
	ToonGui.style_label(label, Color(0.05, 0.05, 0.05), 20, Color(0, 0, 0, 0), 0)
	label.add_theme_font_override("font", ToonGui.suit_font())
	panel.add_child(label)
	_hud.add_child(panel)
	panel.reset_size()
	if _camera != null and not _camera.is_position_behind(at):
		var screen := _camera.unproject_position(at)
		panel.position = screen - Vector2(panel.size.x * 0.5, panel.size.y + 8.0)
	if tick_idle:
		var elapsed := 0.0
		while elapsed < seconds:
			await get_tree().process_frame
			var delta := get_process_delta_time()
			elapsed += delta
			if _player != null:
				_player.set_locomotion(0.0, false, false, delta)
	else:
		await get_tree().create_timer(seconds).timeout
	panel.queue_free()


func _banner(text: String) -> Label:
	var view := _hud.get_viewport().get_visible_rect().size
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2((view.x - 720.0) * 0.5, 28)
	label.size = Vector2(720, 80)
	ToonGui.style_title(label, Color(0.9, 0.05, 0.06), 58)
	_hud.add_child(label)
	return label


func _floater(at: Vector3, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(220, 64)
	ToonGui.style_title(label, color, 52)
	_hud.add_child(label)
	if _camera != null and not _camera.is_position_behind(at):
		var screen := _camera.unproject_position(at)
		label.position = screen - Vector2(110, 64)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 64.0, 0.85)
	tween.tween_callback(label.queue_free)


func _pulse_marker() -> void:
	if _marker == null:
		return
	_marker.scale = Vector3.ONE
	var tween := create_tween()
	tween.tween_property(_marker, "scale", Vector3(1.8, 1.8, 1.8), 0.12)
	tween.tween_property(_marker, "scale", Vector3.ONE, 0.2)


func _ensure_marker() -> void:
	if _marker != null:
		_marker.visible = true
		return
	_marker = _prop(Color(0.25, 1.0, 0.4), Vector3(0.28, 0.28, 0.28))
	var sphere := _marker.mesh as SphereMesh
	if sphere:
		sphere.radius = 0.22
		sphere.height = 0.44
	_marker.reparent(_flunky)
	_marker.position = Vector3(0, 3.15, -0.55)
	var chest := _flunky.find_child("joint_attachMeter", true, false) as Node3D
	if chest != null:
		_marker.reparent(chest, true)


func _show_meter() -> void:
	if _meter == null:
		return
	var view := _hud.get_viewport().get_visible_rect().size
	var pixels := view.y * 0.15
	_meter.visible = true
	_meter.place(LaffMeter.corner(view, pixels), pixels)
	_meter.set_hp(_loadout.hp, _loadout.max_hp)


func _build_card() -> void:
	_card = Panel.new()
	_card.visible = false
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.size = Vector2(168, 72)
	_card.add_theme_stylebox_override("panel", _flat(Color(0.78, 0.8, 0.84), Color(0.25, 0.25, 0.28), 3, 8))
	_level_label = Label.new()
	_level_label.text = "Level %d" % _flunky.cog_level
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.position = Vector2(8, 6)
	_level_label.size = Vector2(152, 28)
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(_level_label, Color(0.1, 0.1, 0.12), 18, Color(1, 1, 1, 0.4), 1)
	_card.add_child(_level_label)
	var track := ColorRect.new()
	track.color = Color(0.15, 0.15, 0.16)
	track.position = Vector2(14, 42)
	track.size = Vector2(140, 16)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(track)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.2, 0.78, 0.22)
	_hp_fill.position = Vector2(14, 42)
	_hp_fill.size = Vector2(140, 16)
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_hp_fill)
	_hud.add_child(_card)


func _apply_cog_vitals() -> void:
	_cog_max_hp = maxi(_flunky.max_hp(), 1)
	_cog_hp = _cog_max_hp
	if _level_label != null:
		_level_label.text = "Level %d" % _flunky.cog_level


func _set_cog_bar() -> void:
	if _hp_fill == null:
		return
	var ratio := clampf(float(_cog_hp) / float(_cog_max_hp), 0.0, 1.0)
	_hp_fill.size = Vector2(140.0 * ratio, 16.0)
	if ratio > 0.5:
		_hp_fill.color = Color(0.2, 0.78, 0.22)
	elif ratio > 0.25:
		_hp_fill.color = Color(0.9, 0.78, 0.15)
	else:
		_hp_fill.color = Color(0.85, 0.16, 0.12)


func _prop(color: Color, box_size: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = box_size.x
	mesh.height = box_size.y * 2.0
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	node.material_override = mat
	add_child(node)
	return node


func _flat(fill: Color, edge: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	return box
