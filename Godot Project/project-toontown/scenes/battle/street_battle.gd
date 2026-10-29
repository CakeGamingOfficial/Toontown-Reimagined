class_name StreetBattle
extends Node

## A one-toon street battle, the way DistributedBattle plays a round:
## the toon picks a gag, that attack resolves, then the cog attacks.
## It repeats until one of them runs out of health.

const APPROACH := 7.0
const FLUNKY_LEVEL := 1
const FLUNKY_HP := 6
# TownLoader.battleMusic. BattlePlace.enterBattle plays it at 0.9 and
# stops the street track. exitBattle brings the street track back at 0.8.
const BATTLE_MUSIC := "res://assets/audio/battle/encntr_general_bg.mp3"
const BATTLE_VOLUME := 0.9
const PLACE_VOLUME := 0.8
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
var _cog_hp := FLUNKY_HP
var _gained: Dictionary = {}
var _spent: Array[Vector2i] = []
var _battle_music: AudioStreamPlayer
var _place_music: AudioStreamPlayer
var _movie: BattleMovie
var _dancing := false
var _dance := 0.0


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
	_cog_hp = FLUNKY_HP
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
	_host.call("set_cutscene", true)
	_separate()
	_face_each_other()
	_ensure_marker()
	_show_meter()
	await _say(_flunky.global_position + Vector3(0, 4.6, 0), "You're not going to like the way I work.", 2.0)
	while _cog_hp > 0 and _loadout.hp > 0:
		_aim(true)
		var pick := await _menu.choose()
		if pick.x >= 0:
			await _toon_attack(pick.x, pick.y)
		if _cog_hp <= 0 or _loadout.hp <= 0:
			break
		await _cog_attack()
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
	_battle_music = AudioStreamPlayer.new()
	_battle_music.name = "BattleMusic"
	_battle_music.stream = stream
	_battle_music.volume_db = linear_to_db(BATTLE_VOLUME)
	add_child(_battle_music)
	_battle_music.play()


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


func _separate() -> void:
	var toon := _body.global_position
	var cog := _flunky.global_position
	var gap := Vector3(toon.x - cog.x, 0.0, toon.z - cog.z)
	if gap.length() < 0.2:
		gap = Vector3(1.0, 0.0, 0.0)
	var mid := Vector3((toon.x + cog.x) * 0.5, 0.0, (toon.z + cog.z) * 0.5)
	var dir := gap.normalized()
	_body.global_position = mid + dir * 3.6 + Vector3(0, 0.2, 0)
	_flunky.global_position = mid - dir * 3.6


func _face_each_other() -> void:
	_host.call("face_actor", _player, _heading_toward(_body.global_position, _flunky.global_position))
	_flunky.face_heading(_heading_toward(_flunky.global_position, _body.global_position))


func _heading_toward(from: Vector3, to: Vector3) -> float:
	return rad_to_deg(atan2(-(to.x - from.x), -(to.z - from.z)))


func _aim(menu_view: bool) -> void:
	if _camera == null:
		return
	var toon := _body.global_position
	var cog := _flunky.global_position
	var forward := Vector3(cog.x - toon.x, 0.0, cog.z - toon.z)
	if forward.length() < 0.1:
		forward = Vector3(0, 0, -1)
	forward = forward.normalized()
	if menu_view:
		_camera.global_position = toon - forward * 5.5 + Vector3(0, 7.0, 0)
		_camera.look_at(cog + Vector3(0, 2.0, 0), Vector3.UP)
	else:
		var side := forward.cross(Vector3.UP).normalized()
		var mid := (toon + cog) * 0.5
		_camera.global_position = mid + side * 8.5 + Vector3(0, 3.4, 0)
		_camera.look_at(mid + Vector3(0, 1.8, 0), Vector3.UP)


func _toon_attack(track: int, level: int) -> void:
	if not _loadout.spend_gag(track, level):
		return
	_spent.append(Vector2i(track, level))
	_gained[track] = int(_gained.get(track, 0)) + ToonLoadout.SKILL_CREDIT
	_aim(false)
	var hit := true
	if track != ToonLoadout.TOON_UP:
		hit = randi() % 100 < ToonLoadout.gag_accuracy(track, level)
	var at := _flunky.global_position + Vector3(0, 3.4, 0)
	await _movie.play_gag(track, level, hit, func() -> void:
		if track == ToonLoadout.TOON_UP:
			var heal := ToonLoadout.gag_damage(track, level, _loadout.experience_of(track))
			_loadout.set_hp(_loadout.hp + heal, _loadout.max_hp)
			_meter.set_hp(_loadout.hp, _loadout.max_hp)
			_floater(_body.global_position + Vector3(0, 3.2, 0), "+%d" % heal, Color(0.35, 0.85, 0.35))
			return
		if not hit:
			_floater(at, "MISSED", Color(1, 1, 1))
			return
		var damage := ToonLoadout.gag_damage(track, level, _loadout.experience_of(track))
		_cog_hp = maxi(_cog_hp - damage, 0)
		_set_cog_bar()
		_pulse_marker()
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
			var damage := int(attack["hp"])
			_loadout.set_hp(_loadout.hp - damage, _loadout.max_hp)
			_meter.set_hp(_loadout.hp, _loadout.max_hp)
			_floater(at, "-%d" % damage, Color(0.92, 0.08, 0.08))
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
	_movie.show_reward()
	var was_done := false
	if _tasks != null:
		was_done = _tasks.is_complete(101)
		_tasks.note_cog_defeat("f")
	_loadout.save()
	for track in _gained.keys():
		_loadout.add_experience(int(track), int(_gained[track]))
		await _reward(int(track), int(_gained[track]))
	_loadout.save()
	if _tasks != null and not was_done and _tasks.is_complete(101):
		await _notice("ToonTasks", "Defeat a Flunky : Complete")
	_dancing = false
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


func _reward(track: int, amount: int) -> void:
	var name := ToonLoadout.TRACK_NAMES[track]
	var points := "point" if amount == 1 else "points"
	var exp := mini(_loadout.experience_of(track), ToonLoadout.NEXT_GAG)
	var body := "You received %d %s %s!\nWhen you get %d, you will get a new gag!\n\n%s  %d/%d" % [
		amount, name, points, ToonLoadout.NEXT_GAG, name.to_upper(), exp, ToonLoadout.NEXT_GAG,
	]
	await _notice(_player.name, body)


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


func _say(at: Vector3, text: String, seconds: float) -> void:
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
	panel.add_child(label)
	_hud.add_child(panel)
	panel.reset_size()
	if _camera != null and not _camera.is_position_behind(at):
		var screen := _camera.unproject_position(at)
		panel.position = screen - Vector2(panel.size.x * 0.5, panel.size.y + 8.0)
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
	_meter.place(Vector2(pixels * 0.5 + 28.0, view.y - pixels * 0.5 - 28.0), pixels)
	_meter.set_hp(_loadout.hp, _loadout.max_hp)


func _build_card() -> void:
	_card = Panel.new()
	_card.visible = false
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.size = Vector2(168, 72)
	_card.add_theme_stylebox_override("panel", _flat(Color(0.78, 0.8, 0.84), Color(0.25, 0.25, 0.28), 3, 8))
	var level := Label.new()
	level.text = "Level %d" % FLUNKY_LEVEL
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level.position = Vector2(8, 6)
	level.size = Vector2(152, 28)
	level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(level, Color(0.1, 0.1, 0.12), 18, Color(1, 1, 1, 0.4), 1)
	_card.add_child(level)
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


func _set_cog_bar() -> void:
	if _hp_fill == null:
		return
	var ratio := clampf(float(_cog_hp) / float(FLUNKY_HP), 0.0, 1.0)
	_hp_fill.size.x = 140.0 * ratio
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
