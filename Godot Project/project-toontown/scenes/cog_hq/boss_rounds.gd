extends Node

## The four boss signature rounds, played in the boss room.
## Damage follows DistributedSellbotBossAI, DistributedCashbotBossSafeAI,
## DistributedLawbotBossAI, and DistributedBossbotBossAI. The toon walks
## the room. Ctrl throws, grabs, or fires. Jump is Ctrl in the keybinds,
## so a round that has locked the toon uses that key for the round.

const _KEYS := preload("res://scenes/shticker/keybinds.gd")

var _boss: Node
var _mode := ""
var _root: Node3D
var _origin := Vector3.ZERO
var _forward := Vector3(0, 0, -1)
var _right := Vector3(1, 0, 0)
var _clock := 0.0
var _cool := 0.0
var _pies: Array[Dictionary] = []
var _shots: Array[Dictionary] = []
var _safes: Array[Dictionary] = []
var _goons: Array[Dictionary] = []
var _treasures: Array[Dictionary] = []
var _crane := -1
var _crane_h := 0.0
var _crane_y := 16.0
var _magnet := Vector3.ZERO
var _held := -1
var _crane_send := 0.0
var _crane_seq := 0
var _sent_seq := 0
var _others: Dictionary = {}
var _drops_seen: Dictionary = {}
var _drop_token := 0
var _drop_left := 0.0
var _drop_row: Dictionary = {}
var _cannon := false
var _power := 0.0
var _power_dir := 1.0
var _chairs: Array[Vector3] = []
var _chair_slide := 0.0
var _lawyers: Array[Dictionary] = []
var _gavel := 7.0
var _gavel_zone := Vector3.ZERO
var _gavel_live := 0.0
var _food: Array[Dictionary] = []
var _carry := false
var _golf := false
var _spray := 0.0
var _attack_left := 0.0
var _attack_at := Vector3.ZERO
var _attack_kind := ""
var _boss_pos := Vector3.ZERO
var _vp_forward := Vector3(0, 0, -1)
var _door_open := true
var _attack_live := false
var _attack_damage := 0
var _attack_radius := 0.0
var _attack_side := 0
var _pressed := false
var _cage := Vector3.ZERO
var _door_closed := {}
var _gears: Array[Dictionary] = []
var _jury: Node3D
var _jury_start := Vector3.ZERO
var _belt_at := Vector3.ZERO
var _goon_left := 0.0
var _magnet_prev := Vector3.ZERO
var _magnet_vel := Vector3.ZERO
var _drop_aim := Vector3(0, 0, -1)
var _intro_done := false
var _flee_t := 0.0
var _flee_line := 0
var _mata: Node3D
var _door1: Node3D
var _door2: Node3D
var _door3: Node3D
var _door_base: Dictionary = {}
var _intro_said: Dictionary = {}
var _lesson_said: Dictionary = {}
var _lesson_done := false
var _movie_cam: Camera3D
var _cam_was: Camera3D
var _suited := false
var _eyes_fixed := false
var _mata_suit: Node3D
var _hit_left := 0.0
var _throw_left := 0.0
var _poser: Node
var _anim_banks: Dictionary = {}
var _anim_rates: Dictionary = {}
var _anim_clip := ""
var _anim_time := 0.0
var _anim_loop := true
var _stars: Node3D
var _flash_left := 0.0
var _flash_paint: StandardMaterial3D
var _music: AudioStreamPlayer
var _music_key := ""
var _goon_banks: Dictionary = {}
var _goon_rates: Dictionary = {}
var _goon_clip := ""
var _goon_time := 0.0
var _cfo_doors: Dictionary = {}
var _wiggle := 0.0
var _wiggle_t := 0.0
var _head_flipped := false
var _victory_done := false
var _mount_left := 0.0
var _mount_from := Vector3.ZERO
var _lever := ""
var _cfo_raised := true
var _down_hit := false
var _birds: AudioStreamPlayer
var _magnet_on: AudioStreamPlayer
var _magnet_loop: AudioStreamPlayer
var _magnet_hum := -1.0
var _crane_move: AudioStreamPlayer
var _crane_move_path := ""
var _carry_from := Vector3.ZERO
var _carry_left := 0.0
var _clank_left := 0.0
var _clank_path := ""
var _saved_fov := -1.0
var _bolts: Array[Node3D] = []
var _gear_bits: Array[Dictionary] = []
var _stun_clip: Dictionary = {}
var _cable: Node3D
var _link_p: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _link_v: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _cable_ready := false
var _fit_crane := -1
var _fit_from := 1.0
var _fit_to := 1.0
var _fit_left := 0.0
var _fit_span := 0.5
var _fit_locked := false
var _fit_column_from := Vector3.ZERO
var _fit_column_to := Vector3.ZERO
var _fit_bottom_from := Vector3.ZERO
var _fit_bottom_to := Vector3.ZERO
var _fit_stick_from := Vector3.ZERO
var _fit_stick_to := Vector3.ZERO
var _driving := false
var _field_ready := false
var _field_send := 0.0
var _zap_peer := 0
var _zap_seq := 0
var _zap_strength := 0
var _zap_heal := 0
var _zap_at := Vector3.ZERO
var _zap_seen := 0
var _magnet_shadow: MeshInstance3D
var _crane_shadow: MeshInstance3D
var _cable_shadow: MeshInstance3D


func shutdown() -> void:
	_mode = ""
	_gears.clear()
	_clear_gear_bits()
	_clear_lever()
	_stop_birds()
	_stop_crane_audio()
	_restore_fov()
	_drop_mata_suit()
	_release_camera()
	_reset_doors()
	_clear_train()
	_anim_banks.clear()
	_goon_banks.clear()
	_goon_clip = ""
	_anim_clip = ""
	_anim_time = 0.0
	_stars = null
	_hit_left = 0.0
	_throw_left = 0.0
	_flash_left = 0.0
	_lesson_said.clear()
	_eyes_fixed = false
	if _mata != null:
		_mata.queue_free()
		_mata = null
	_free_toon()
	_cable = null
	_cable_ready = false
	_fit_crane = -1
	_fit_left = 0.0
	_magnet_shadow = null
	_crane_shadow = null
	_cable_shadow = null
	if _root != null:
		_root.queue_free()
		_root = null


func start_vp(boss: Node) -> void:
	_begin(boss)
	_mode = "vp"
	# The introduction owns the VP. Battle three starts him on SellbotBossBattleTwoPosHpr.
	var boss_node := _existing_vp()
	if boss_node == null:
		boss_node = _spawn_vp(Vector3(0.0, 60.0, 18.0))
	else:
		boss_node.position = Vector3(0.0, 60.0, 18.0)
	_boss_pos = boss_node.global_position
	var cage := _find("cage")
	if cage != null:
		_cage = cage.global_position
	else:
		var pies := _panda_box(0.0, 77.9, 18.0, Color(0.95, 0.55, 0.2), Vector3(2.0, 2.0, 2.0), "Pies")
		_cage = pies.global_position
	# The cage node's origin sits above the platform. The grab is on the floor under it.
	_cage.y = _boss_pos.y
	_vp_forward = _cage - _boss_pos
	_vp_forward.y = 0.0
	if _vp_forward.length_squared() < 0.01:
		_vp_forward = Vector3(0, 0, -1)
	_vp_forward = _vp_forward.normalized()
	boss_node.look_at(boss_node.global_position + _vp_forward, Vector3.UP)
	_tell("The pie cage is behind him. Click throws. Doors open when he attacks and stay open while he is stunned. A pie in the doors stuns him. Pies on his body do 1 only then. Front is 3, directed is 3, strafe is 2, area is 10. At 100, one more pie in the doors ends it.")


func start_cfo_intro(boss: Node) -> void:
	_begin(boss)
	_mode = "cfo_intro"
	_intro_done = false
	_intro_said.clear()
	_clock = 0.0
	# CashbotBossOffstagePosHpr. He rolls in once the vault door opens.
	_model_or_box("res://assets/cogs/bosses/cashbot_boss.glb", Vector3(120.0, -195.0, 0.0), "CFO", Color(0.15, 0.45, 0.2), Vector3(3.0, 6.0, 2.4))
	_summon_mata()
	var starts := [Vector3(111.0, -287.0, 0.0), Vector3(119.0, -315.0, 0.0), Vector3(102.0, -320.0, 0.0)]
	for index in starts.size():
		var intro := _model_or_box("res://assets/cog_hq/goon.glb", starts[index], "IntroGoon%d" % index, Color(0.35, 0.35, 0.4), Vector3(1.2, 1.8, 1.2))
		_add_goon_shadow(intro)
	_lock_toon()
	_grab_camera()


func start_cfo_lesson(boss: Node) -> void:
	_begin(boss)
	_mode = "cfo_lesson"
	_lesson_done = false
	_clock = 0.0
	_goon_left = 0.0
	_lay_cranes()
	var cfo := _root.get_node_or_null("CFO") as Node3D
	if cfo != null:
		# CashbotBossBattleOnePosHpr. He rolls into the crane vault during the lesson.
		cfo.position = Vector3(120.0, -230.0, 0.0)
	_summon_mata()
	if _mata != null:
		_mata.global_position = _panda_world(Vector3(93.935, -341.065, 0.0))
	_model_or_box("res://assets/cog_hq/goon.glb", Vector3(104.0, -316.0, 0.0), "LessonGoon", Color(0.35, 0.35, 0.4), Vector3(1.2, 1.8, 1.2))
	if cfo != null:
		_face_cfo(cfo, 90.0)
	_lock_toon()
	_grab_camera()
	_sfx("res://assets/cog_hq/audio/CHQ_GOON_hunker_down.ogg")


func enable_cranes() -> void:
	_mode = "cfo"
	_lesson_done = true
	_release_camera()
	_free_toon()
	_reset_doors()
	if _mata != null:
		_mata.visible = false
	var goon := _root.get_node_or_null("LessonGoon") as Node3D if _root != null else null
	if goon != null:
		goon.visible = false
	var body := _body()
	if body != null:
		body.velocity = Vector3.ZERO
		body.global_position = _panda_world(Vector3(105.0, -285.0, 0.0))
	var cfo := _root.get_node_or_null("CFO") as Node3D if _root != null else null
	if cfo != null:
		cfo.position = Vector3(120.0, -315.0, 0.0)
		_face_cfo(cfo, 135.0)
		_boss_pos = cfo.global_position
	_crane_help()
	_widen_crane()


func finish_cfo_lesson() -> void:
	_lesson_done = true
	_reset_doors()
	_release_camera()
	_free_toon()


func start_cranes(boss: Node) -> void:
	_begin(boss)
	_mode = "cfo"
	_goon_left = 0.0
	_lay_cranes()
	_crane_help()
	_widen_crane()


func _lay_cranes() -> void:
	_cfo_raised = true
	_down_hit = false
	_field_ready = false
	_driving = false
	_zap_seen = 0
	# CashbotBossBattleThreePosHpr. The vault room is already the scene.
	var boss_node := _model_or_box("res://assets/cogs/bosses/cashbot_boss.glb", Vector3(120.0, -315.0, 0.0), "CFO", Color(0.15, 0.45, 0.2), Vector3(3.0, 6.0, 2.4))
	_boss_pos = boss_node.global_position
	var cranes := [Vector3(97.4, -337.6, 0.0), Vector3(97.4, -292.4, 0.0), Vector3(142.6, -292.4, 0.0), Vector3(142.6, -337.6, 0.0)]
	for index in cranes.size():
		var pad: Vector3 = cranes[index]
		var controls := _model_or_box("res://assets/cog_hq/cfo_crane_controls.glb", pad, "Crane%d" % index, Color(0.2, 0.35, 0.7), Vector3(2.0, 0.5, 2.0))
		_shift_controls(controls)
		_model_or_box("res://assets/cog_hq/cfo_crane_arm.glb", pad, "Arm%d" % index, Color(0.2, 0.35, 0.7), Vector3(1.0, 0.4, 4.0))
		var stick := _model_or_box("res://assets/cog_hq/cfo_crane_stick.glb", pad, "Stick%d" % index, Color(0.4, 0.3, 0.15), Vector3(0.3, 1.2, 0.3))
		stick.position = pad + _controls_local(pad)
	_model_or_box("res://assets/cog_hq/cfo_magnet.glb", Vector3(120.0, -315.0, 6.0), "Magnet", Color(0.7, 0.2, 0.2), Vector3(1.2, 1.2, 1.2))
	# Safe 0 waits above him until he puts it on. The other eight sit on the floor.
	var safes := [Vector3(120.0, -315.0, 30.0), Vector3(77.2, -329.3, 0.0), Vector3(77.1, -302.7, 0.0), Vector3(165.7, -326.4, 0.0), Vector3(165.5, -302.4, 0.0), Vector3(107.8, -359.1, 0.0), Vector3(133.9, -359.1, 0.0), Vector3(107.0, -274.7, 0.0), Vector3(134.2, -274.7, 0.0)]
	for index in safes.size():
		var node := _model_or_box("res://assets/cog_hq/cfo_safe.glb", safes[index], "Safe%d" % index, Color(0.85, 0.75, 0.2), Vector3(1.6, 1.4, 1.6))
		node.visible = index != 0
		_safes.append({"at": node.global_position, "fall": 0.0, "node": node})


func _crane_help() -> void:
	_tell("Press E at a crane. A and D swing the arm, W and S slide the magnet, click grabs or drops. A drop counts when it is moving toward him. Knock the helmet off with a swing toward him. While he is dizzy, a safe does up to 50. His own swing does 10 and ends the dizzy.")


func start_cannons(boss: Node) -> void:
	_begin(boss)
	_mode = "cannon"
	_crane_h = 0.0
	_jury = _find("JuryBox")
	if _jury != null:
		_jury_start = _jury.position
	var cannons := [Vector3(-40.0, -12.0, 0.0), Vector3(-40.0, 0.0, 0.0), Vector3(-40.0, 12.0, 0.0), Vector3(-40.0, 24.0, 0.0)]
	for index in cannons.size():
		_model_or_box("res://assets/parties/cannon.glb", cannons[index], "Cannon%d" % index, Color(0.45, 0.3, 0.15), Vector3(1.6, 1.2, 2.2))
	_tell("Battle Two is the cannon round. Press E at a cannon. The jury box moves for 70 seconds. The bar charges, A and D aim, click fires you into it. You have 12 shots. Land in the box to seat a Toon.")


func start_evidence(boss: Node) -> void:
	_begin(boss)
	_mode = "evidence"
	var podium := _find("Podium")
	var scale := _panda_box(-3.0, 0.0, 0.0, Color(0.75, 0.7, 0.35), Vector3(2.2, 0.4, 5.0), "Scale")
	if podium != null:
		scale.global_position = podium.global_position + Vector3(0.0, 1.0, 0.0)
	var defense := _panda_box(-3.0, -2.0, 1.0, Color(0.2, 0.55, 0.85), Vector3(1.8, 0.4, 1.8), "Defense")
	defense.global_position = scale.global_position + Vector3(0.0, 0.4, -2.0)
	var stand := _panda_box(8.0, 10.0, 0.0, Color(0.9, 0.85, 0.4), Vector3(1.6, 1.2, 1.6), "Evidence")
	_boss_pos = scale.global_position
	var count := int(boss.call("lawyer_count"))
	for index in count:
		var node := _panda_box(12.0, -20.0 + float(index) * 4.0, 0.0, Color(0.55, 0.2, 0.2), Vector3(0.9, 1.8, 0.9), "Lawyer%d" % index)
		_lawyers.append({"at": node.global_position, "stun": 0.0, "node": node})
	_tell("Battle Three is the scale. Click to throw evidence onto the blue defense pan. The yellow witness stand refills you. Hit a lawyer to stun him. A gavel stomp is 20 and a graze is 2. All lawyers stunned for 60 seconds doubles your weight and heals 10. The scale needs 2700.")


func start_banquet(boss: Node) -> void:
	_begin(boss)
	_mode = "banquet"
	var locators := _find_all("TableLocator_")
	var state: Dictionary = boss.call("world_state")
	var plates: Array = state.get("plates", [])
	if locators.is_empty():
		_belt_at = _panda_box(0.0, 200.0, 0.0, Color(0.7, 0.45, 0.2), Vector3(8.0, 0.4, 1.4), "Belt").global_position
	else:
		_belt_at = locators[0].global_position
		_panda_box(0.0, 180.0, 1.0, Color(0.7, 0.45, 0.2), Vector3(10.0, 0.35, 1.2), "Belt")
	for index in plates.size():
		var seat := _panda_box(0.0, 0.0, 0.0, Color(0.3, 0.3, 0.35), Vector3(1.0, 1.2, 1.0), "Seat%d" % index)
		if locators.is_empty():
			seat.position = Vector3(float(index) * 2.0, 220.0, 0.0)
		else:
			var table := locators[index % locators.size()]
			var around := float(index / locators.size())
			seat.global_position = table.global_position + Vector3(cos(around) * 2.2, 0.6, sin(around) * 2.2)
	_tell("Battle Two is the 300 second banquet. The food belt is in the banquet hall. Walk into it for a plate and serve the glowing chair. BossbotNumFoodToExplode is 3. A wrong or late plate costs 8 laff. E ends serving.")


func start_seltzer(boss: Node) -> void:
	_begin(boss)
	_mode = "seltzer"
	# BossbotBossBattleOnePosHpr, where he stands over the banquet.
	var boss_node := _panda_box(0.0, 355.0, 0.0, Color(0.15, 0.2, 0.45), Vector3(2.6, 5.4, 2.2), "CEO")
	_boss_pos = boss_node.global_position
	var bottle := _panda_box(6.0, 340.0, 0.0, Color(0.4, 0.7, 0.9), Vector3(1.2, 0.8, 1.2), "Seltzer")
	_belt_at = bottle.global_position
	_tell("Battle Four. Press E at the seltzer bottle. Hold the jump key to charge 1, 2, or 3 and release. The server doubles it to 2, 4, or 6. His club and area swing each do 15. Step off the red marker.")


func _process(delta: float) -> void:
	if _mode == "" or _boss == null:
		return
	_clock += delta
	_cool = maxf(_cool - delta, 0.0)
	if _mode != "cfo":
		_stop_crane_audio()
	if _mode == "cfo_intro":
		_tick_cfo_intro(delta)
		_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		return
	if _mode == "cfo_lesson":
		_tick_cfo_lesson(delta)
		return
	if _mode == "cfo_flee":
		_tick_cfo_flee(delta)
		return
	if _mode == "cfo_epilogue":
		return
	if _mode == "cfo_victory":
		_tick_cfo_victory()
		return
	var body := _body()
	if body == null:
		return
	if _mode == "vp":
		_tick_vp(delta, body)
	elif _mode == "cfo":
		_tick_cfo(delta, body)
	elif _mode == "cannon":
		_tick_cannon(delta, body)
	elif _mode == "evidence":
		_tick_evidence(delta, body)
	elif _mode == "banquet":
		_tick_banquet(delta, body)
	elif _mode == "seltzer":
		_tick_seltzer(delta, body)
	_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _tick_vp(delta: float, body: CharacterBody3D) -> void:
	if _boss.has_method("vp_ending") and bool(_boss.call("vp_ending")):
		return
	var state: Dictionary = _boss.call("tick_vp", delta)
	var vp := _existing_vp()
	if vp != null:
		_boss_pos = vp.global_position
		if _boss.has_method("place_vp"):
			_boss.call("place_vp", float(state.get("hp", 0)) / float(maxi(int(state.get("max", 100)), 1)))
		_boss_pos = vp.global_position
		_vp_forward = -vp.global_transform.basis.z
		_vp_forward.y = 0.0
		if _vp_forward.length_squared() > 0.01:
			_vp_forward = _vp_forward.normalized()
	_door_open = bool(state.get("doors", false))
	_pose_doors()
	_fly_gears(delta)
	if _near(body, _cage, 3.5):
		_boss.call("restock_pies")
	if _fresh_press() and bool(_boss.call("take_pie")):
		_launch(body, 26.0, Color(0.95, 0.45, 0.55), "pie")
	_fly(_pies, delta)
	var door_at := _opening_point()
	var chest := _boss_pos + Vector3(0, 12, 0)
	for shot in _pies:
		if bool(shot["done"]):
			continue
		var at: Vector3 = shot["at"]
		if _door_open and _near_point(at, door_at, 5.0) and absf(at.y - door_at.y) < 6.0:
			shot["done"] = true
			_boss.call("note_opening")
		elif _near_point(at, chest, 7.0) and absf(at.y - chest.y) < 10.0:
			shot["done"] = true
			_boss.call("note_body")
		else:
			var peer := _hit_toon(at)
			if peer > 0:
				shot["done"] = true
				_boss.call("note_friend_pie", peer)
	var event: Dictionary = state.get("event", {})
	if not event.is_empty():
		_arm_attack(event, body)
	if _attack_left > 0.0:
		_attack_left -= delta
		if _attack_kind == "strafe" and _attack_live and _in_strafe(body):
			_attack_live = false
			_boss.call("note_vp_attack", "strafe")
		elif _attack_left <= 0.0 and _attack_live and _near(body, _attack_at, _attack_radius):
			_attack_live = false
			_boss.call("note_vp_attack", _attack_kind)
	if _boss.has_method("vp_ending") and bool(_boss.call("vp_ending")):
		return
	var doors := "OPEN" if _door_open else "shut"
	var dizzy := "stunned" if bool(state.get("dizzy", false)) else "up"
	var pies := int(state.get("pies", 0))
	var stack := "full" if pies > 100 else str(pies)
	_boss.call("paint_world", "Doors %s. He is %s. Pies %s." % [doors, dizzy, stack])


func _hit_toon(at: Vector3) -> int:
	if _boss == null:
		return 0
	var host := _boss.get_parent()
	if host == null:
		return 0
	var local := ToonNet.peer_id()
	for node in host.find_children("", "ToonActor", true, false):
		if not node.has_meta("peer"):
			continue
		var peer := int(node.get_meta("peer"))
		if peer <= 0 or peer == local:
			continue
		var actor := node as Node3D
		if Vector2(at.x, at.z).distance_to(Vector2(actor.global_position.x, actor.global_position.z)) < 1.5:
			return peer
	return 0


func _existing_vp() -> Node3D:
	var geom := _geometry()
	if geom == null:
		return null
	return geom.find_child("VP", true, false) as Node3D


func _attack_target(peer: int, body: CharacterBody3D) -> Vector3:
	if peer > 0 and peer != ToonNet.peer_id() and _boss != null:
		var host := _boss.get_parent()
		if host != null:
			for node in host.find_children("", "ToonActor", true, false):
				if int(node.get_meta("peer", 0)) == peer and node is Node3D:
					return (node as Node3D).global_position
	return body.global_position


func _launch_gears(event: Dictionary) -> void:
	if _attack_kind == "directed":
		_launch_directed()
	elif _attack_kind == "strafe":
		_launch_strafe(float(event.get("t", 0.0)), int(event.get("dir", 0)))


func _launch_directed() -> void:
	# doDirectedAttack throws four gears over one second, staggered by 0.15.
	var hinge := _door_hinge(0)
	var start := _boss_pos + Vector3(0, 10, 0)
	var forward := _vp_forward
	if hinge != null:
		start = hinge.global_position + Vector3(0, 4, 0)
		forward = -hinge.global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() > 0.01:
			forward = forward.normalized()
	for index in 4:
		var gear := _gear(0.2)
		var scatter := Vector3(randf_range(-5.0, 5.0), randf_range(-3.0, 3.0), randf_range(-5.0, 5.0))
		var land := _attack_at + forward * 4.0 + scatter
		land.y = maxf(land.y, 1.5)
		gear.global_position = start
		gear.visible = false
		_gears.append({"from": start, "to": land, "age": 0.0, "wait": float(index) * 0.15, "node": gear})


func _launch_strafe(along: float, direction: int) -> void:
	# doStrafe: numGears = 4+6*t, spread 60 degrees, 50 units from the open door.
	var count := int(4.0 + 6.0 * along + 0.5)
	count = clampi(count, 1, 10)
	var span := 5.0 - 4.0 * along
	var rate := span / float(count)
	var spread := deg_to_rad(60.0)
	if direction == 1:
		spread = -spread
	var hinge := _door_hinge(_attack_side)
	var forward := _vp_forward
	var start := _boss_pos + Vector3(0, 3, 0) + forward * (6.5 if _attack_side == 0 else -6.5)
	if hinge != null:
		start = hinge.global_position + Vector3(0, 3, 0)
		forward = -hinge.global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() > 0.01:
			forward = forward.normalized()
		if _attack_side == 0:
			forward = -forward
	for index in count:
		var gear := _gear(0.1)
		var frac := 0.0 if count == 1 else float(index) / float(count - 1) - 0.5
		var aim := forward.rotated(Vector3.UP, frac * spread)
		var land := start + aim * 50.0
		land.y = start.y
		gear.global_position = start
		gear.visible = false
		_gears.append({"from": start, "to": land, "age": 0.0, "wait": float(index) * rate, "node": gear})


func _door_hinge(side: int) -> Node3D:
	var actor := _existing_vp()
	if actor == null:
		return null
	return actor.find_child("DoorFront" if side == 0 else "DoorRear", true, false) as Node3D


func _gear(scale: float) -> Node3D:
	if ResourceLoader.exists("res://assets/cogs/bosses/gear.glb"):
		var packed := load("res://assets/cogs/bosses/gear.glb") as PackedScene
		if packed != null:
			var gear := packed.instantiate() as Node3D
			_root.add_child(gear)
			gear.scale = Vector3(scale, scale, scale)
			return gear
	return _box(_boss_pos, Color(0.75, 0.7, 0.2), Vector3(1.2, 0.2, 1.2), "Gear")


func _fly_gears(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for gear in _gears:
		var age := float(gear["age"]) + delta
		var node := gear["node"] as Node3D
		if node == null:
			continue
		var wait := float(gear.get("wait", 0.0))
		if age < wait:
			gear["age"] = age
			keep.append(gear)
			continue
		node.visible = true
		var u := clampf((age - wait) / 1.0, 0.0, 1.0)
		node.global_position = (gear["from"] as Vector3).lerp(gear["to"], u)
		node.rotate_y(delta * 8.0)
		if u >= 1.0:
			node.queue_free()
			continue
		gear["age"] = age
		keep.append(gear)
	_gears = keep


func _spawn_vp(at: Vector3) -> Node3D:
	_door_closed.clear()
	var packed := load("res://assets/cogs/bosses/sellbot_vp.glb") as PackedScene
	var actor := packed.instantiate() as Node3D
	actor.name = "VP"
	_root.add_child(actor)
	actor.position = at
	return actor


func _opening_point() -> Vector3:
	var hinge := _root.find_child("DoorFront", true, false) as Node3D
	if hinge == null:
		return _boss_pos + _vp_forward * 6.5 + Vector3(0, 8, 0)
	# BossCog's front-door pie polygon, centered on the hinge.
	return hinge.global_transform * Vector3(2.5, 0.0, 0.16)


func _pose_doors() -> void:
	var actor := _root.get_node_or_null("VP") as Node3D
	if actor == null:
		return
	for hinge_name in ["DoorFront", "DoorRear"]:
		var hinge := actor.find_child(hinge_name, true, false) as Node3D
		if hinge == null:
			continue
		if not _door_closed.has(hinge_name):
			_door_closed[hinge_name] = hinge.quaternion
		# Open is identity. Closed is the roll BossCog.DoorFSM starts on.
		hinge.quaternion = Quaternion.IDENTITY if _door_open else _door_closed[hinge_name]


func _arm_attack(event: Dictionary, body: CharacterBody3D) -> void:
	# A pie flinch is only a clip. It is not a gear attack.
	if String(event.get("kind", "")) == "downhit":
		return
	_attack_kind = String(event.get("kind", ""))
	_attack_damage = int(event.get("damage", 0))
	_attack_radius = float(event.get("radius", 4.0))
	_attack_side = int(event.get("side", 0))
	_attack_left = float(event.get("delay", 1.0))
	_attack_live = true
	var shown := minf(_attack_radius, 8.0)
	if _attack_kind == "directed":
		_attack_at = _attack_target(int(event.get("target", 0)), body)
	elif _attack_kind == "strafe":
		var side := _vp_forward.cross(Vector3.UP).normalized()
		if _attack_side == 0:
			side = -side
		_attack_at = _boss_pos + side * 8.0 + _vp_forward * 16.0
	else:
		_attack_at = _boss_pos + _vp_forward * (0.0 if _attack_kind == "area" else 12.0)
	_replace_marker("Attack", _attack_at, Color(0.8, 0.15, 0.15), Vector3(shown, 0.15, shown))
	_launch_gears(event)


func _in_strafe(body: CharacterBody3D) -> bool:
	var side := _vp_forward.cross(Vector3.UP).normalized()
	if _attack_side == 0:
		side = -side
	var from_boss := body.global_position - _boss_pos
	from_boss.y = 0.0
	var across := from_boss.dot(side)
	var along := from_boss.dot(_vp_forward)
	return across > 2.0 and across < 18.0 and along > -4.0 and along < 40.0


func _tick_cfo(delta: float, body: CharacterBody3D) -> void:
	var cfo := _root.get_node_or_null("CFO") as Node3D
	if cfo != null:
		_boss_pos = cfo.global_position
	_tick_cfo_anim(delta)
	var swinging := false
	var limited := false
	_read_cranes()
	_prepare_field()
	if _crane < 0:
		if _KEYS.use_held() and _cool <= 0.0:
			var pads := _crane_pads()
			for index in pads.size():
				if _crane_taken(index):
					continue
				if _near(body, _controls_at(pads[index]), 2.4):
					_crane = index
					_crane_h = 0.0
					_mount_from = body.global_position
					_mount_left = 0.2
					_cool = 0.3
					_lock_toon()
					_lever_pose("leverReach")
					_begin_crane_fit(index)
					break
	else:
		var turn := 0.0
		if _KEYS.held("left"):
			turn -= 1.0
		if _KEYS.held("right"):
			turn += 1.0
		var slide := 0.0
		if _KEYS.held("forward"):
			slide += 1.0
		if _KEYS.held("back"):
			slide -= 1.0
		var moved := absf(turn) + absf(slide) > 0.0
		# armMinH / armMaxH. The swing is relative to the crane's aim at him.
		var raw_h := _crane_h + turn * delta * 40.0
		var raw_y := _crane_y + slide * delta * 10.0
		_crane_h = clampf(raw_h, -45.0, 45.0)
		_crane_y = clampf(raw_y, 8.0, 25.0)
		swinging = moved
		limited = moved and (not is_equal_approx(_crane_h, raw_h) or not is_equal_approx(_crane_y, raw_y))
		_stand_on_crane(body, delta)
		if moved and _lever == "leverNeutral":
			_lever_pose("leverPull")
		elif not moved and (_lever == "leverReach" or _lever == "leverPull"):
			_finish_lever()
		if _KEYS.use_held() and _cool <= 0.0 and _held < 0 and _mount_left <= 0.0:
			_leave_crane()
	_pose_cranes(delta)
	if _crane >= 0:
		_aim_stick_at_hand()
		_aim_crane_camera()
	_apply_crane_fit(delta)
	if _crane >= 0 and _fresh_press():
		if _held >= 0:
			_drop_safe()
		else:
			_grab_safe()
	_tick_crane_audio(delta, swinging, limited)
	for index in _safes.size():
		var safe: Dictionary = _safes[index]
		var node := _root.get_node_or_null("Safe%d" % index) as Node3D
		if node == null:
			continue
		var rider := _other_holds_safe(index)
		if not rider.is_empty():
			var hung := Vector3(float(rider.get("mx", 0.0)), float(rider.get("my", 0.0)), float(rider.get("mz", 0.0))) + Vector3(0.0, -8.2, 0.0)
			node.global_position = hung
			node.visible = true
			safe["at"] = hung
			safe["fall"] = 0.0
			safe["pinned"] = true
		elif _held == index:
			var hung := _held_point()
			node.global_position = hung
			safe["at"] = hung
			safe["pinned"] = false
		elif not _driving and not (float(safe.get("fall", 0.0)) > 0.0 and not bool(safe.get("remote", false))):
			safe["pinned"] = false
			if index != 0:
				node.global_position = safe["at"]
				node.visible = true
		elif float(safe["fall"]) > 0.0:
			safe["pinned"] = false
			safe["vy"] = float(safe["vy"]) - 36.0 * delta
			var at: Vector3 = safe["at"]
			at.x += float(safe["vx"]) * delta
			at.z += float(safe["vz"]) * delta
			at.y += float(safe["vy"]) * delta
			safe["at"] = at
			_bounce_safe_walls(safe)
			at = safe["at"]
			var floor_y := float(safe.get("floor", at.y))
			if at.y <= floor_y:
				var landed := not bool(safe.get("ground", false))
				at.y = floor_y
				safe["vy"] = 0.0
				safe["ground"] = true
				safe["at"] = at
				node.global_position = at
				if landed:
					_land_safe(at, float(safe.get("impact", 0.0)), bool(safe.get("struck", false)))
				var slide := Vector2(float(safe["vx"]), float(safe["vz"])).length()
				if slide < 0.6:
					safe["fall"] = 0.0
					safe["vx"] = 0.0
					safe["vz"] = 0.0
				else:
					safe["vx"] = float(safe["vx"]) * 0.92
					safe["vz"] = float(safe["vz"]) * 0.92
			else:
				safe["ground"] = false
				node.global_position = at
				safe["at"] = at
				if _driving and not bool(safe.get("struck", false)) and _near_point(at, _boss_pos, 8.0):
					safe["struck"] = true
					var impact := float(safe.get("impact", 0.0))
					_hit_noise(impact, 0.0)
					_boss.call("note_safe", impact)
		else:
			safe["pinned"] = false
			safe["at"] = node.global_position
			safe["floor"] = node.global_position.y
		_safes[index] = safe
	if _driving:
		_separate_safes()
	_tick_gear_bits(delta)
	_share_crane(false, delta)
	if _driving:
		_spawn_goons(delta)
	var dizzy := float(_boss.call("world_state").get("dizzy", 0.0)) > 0.0
	var helmet := bool(_boss.call("world_state").get("helmet", false))
	var magnet := _root.get_node_or_null("Magnet") as Node3D
	if magnet != null:
		magnet.visible = _crane >= 0 or _held >= 0
		if magnet.visible:
			magnet.global_position = _magnet
			if _wiggle > 0.0 and _held >= 100:
				_wiggle_t += delta
				_wiggle = maxf(_wiggle - delta, 0.0)
				magnet.rotate_object_local(Vector3.UP, deg_to_rad(sin(_wiggle_t * 17.0) * 5.0))
				magnet.rotate_object_local(Vector3.RIGHT, deg_to_rad(sin(_wiggle_t * 29.0) * 10.0))
				if _wiggle <= 0.0:
					_held = -1
	var lid := _root.get_node_or_null("Safe0") as Node3D
	if lid != null:
		lid.visible = helmet
		if helmet:
			# The baked body is about 26 tall. The safe sits on his head.
			lid.global_position = _boss_pos + Vector3(0.0, 20.0, 0.0)
	for index in _goons.size():
		_tick_battle_goon(index, delta, body)
	if _driving:
		_publish_field(delta)
	var kept: Array[Dictionary] = []
	for item in _treasures:
		var spot: Dictionary = item
		var gem := spot.get("node") as Node3D
		var land: Vector3 = spot["at"]
		var fly := float(spot.get("fly", 0.0))
		if fly > 0.0 and gem != null:
			fly = maxf(fly - delta, 0.0)
			spot["fly"] = fly
			var along := 1.0 - fly
			var where := (spot["from"] as Vector3).lerp(land, along)
			where.y += sin(along * PI) * 6.0
			gem.global_position = where
			kept.append(spot)
			continue
		var near := _near(body, land, 1.4)
		var was := bool(spot.get("near", false))
		var reject := float(spot.get("reject", 0.0))
		if reject > 0.0:
			reject = maxf(reject - delta, 0.0)
			spot["reject"] = reject
			spot["near"] = near
			if gem != null:
				_paint_reject(gem, reject)
			kept.append(spot)
			continue
		if near and not was:
			var loadout := ToonLoadout.for_selected()
			if loadout != null and loadout.hp >= loadout.max_hp:
				spot["reject"] = 1.0
				spot["near"] = true
				_sfx("res://assets/audio/sfx/ring_miss.ogg")
				kept.append(spot)
				continue
			_boss.call("note_treasure", int(spot.get("heal", 3)))
			_sfx("res://assets/audio/sfx/SZ_DD_treasure.ogg")
			if gem != null:
				gem.queue_free()
		else:
			spot["near"] = near
			kept.append(spot)
	_treasures = kept
	if _mode != "cfo":
		return
	var status := "dizzy" if dizzy else ("helmet" if helmet else "open")
	_boss.call("paint_world", "Crane %s. He is %s." % ("in use" if _crane >= 0 else "empty", status))


func _tick_cannon(delta: float, body: CharacterBody3D) -> void:
	if _jury != null:
		var along := clampf(_clock / 70.0, 0.0, 1.0)
		# LawbotBossJuryBoxRelativeEndPos, in the room's panda axes.
		_jury.position = _jury_start + Vector3(30.0, 0.0, 12.645) * along
	var cannons := _named("Cannon")
	if not _cannon:
		if _KEYS.use_held() and _cool <= 0.0:
			for pad in cannons:
				if _near(body, pad.global_position, 3.0):
					_cannon = true
					_power = 0.0
					_power_dir = 1.0
					_cool = 0.3
					_lock_toon()
					break
		var left := maxf(70.0 - _clock, 0.0)
		_boss.call("paint_world", "Jury box %d seconds left." % int(left))
		if _clock >= 70.0:
			_boss.call("finish_cannons")
		return
	_power += _power_dir * delta * 0.85
	if _power >= 1.0:
		_power_dir = -1.0
	elif _power <= 0.0:
		_power_dir = 1.0
	if _KEYS.held("left"):
		_crane_h -= delta * 6.0
	if _KEYS.held("right"):
		_crane_h += delta * 6.0
	if _fresh_press():
		_fire_cannon()
	_boss.call("paint_world", "Cannon power %d%%. Aim with A and D." % int(_power * 100.0))


func _tick_evidence(delta: float, body: CharacterBody3D) -> void:
	var stand := _root.get_node_or_null("Evidence") as Node3D
	if stand != null and _near(body, stand.global_position, 2.4):
		_boss.call("restock_evidence")
	if _fresh_press():
		_launch(body, 22.0, Color(0.9, 0.85, 0.3), "evidence")
	_fly(_shots, delta)
	_boss.call("tick_lawyers", delta)
	var defense := _root.get_node_or_null("Defense") as Node3D
	for shot in _shots:
		if bool(shot["done"]) or defense == null:
			continue
		if _near_point(shot["at"], defense.global_position, 1.8):
			shot["done"] = true
			_boss.call("note_evidence")
		else:
			for index in _lawyers.size():
				if _near_point(shot["at"], _lawyers[index]["at"], 1.3):
					shot["done"] = true
					_lawyers[index]["stun"] = 5.0
					_boss.call("stun_lawyer", index)
	var stunned := 0
	for index in _lawyers.size():
		_lawyers[index]["stun"] = maxf(float(_lawyers[index]["stun"]) - delta, 0.0)
		if float(_lawyers[index]["stun"]) > 0.0:
			stunned += 1
		var node := _root.get_node_or_null("Lawyer%d" % index) as Node3D
		if node != null:
			node.global_position = _lawyers[index]["at"]
	if stunned == _lawyers.size() and not _lawyers.is_empty():
		_boss.call("note_all_stunned", delta)
	_gavel -= delta
	if _gavel <= 0.0:
		_gavel = 8.0
		_gavel_zone = body.global_position + _right * randf_range(-2.0, 2.0)
		_gavel_live = 0.7
		_replace_marker("Gavel", _gavel_zone, Color(0.7, 0.1, 0.1), Vector3(2.2, 0.2, 2.2))
	if _gavel_live > 0.0:
		_gavel_live -= delta
		if _gavel_live <= 0.0:
			var stomp := _near(body, _gavel_zone, 1.5)
			if stomp or _near(body, _gavel_zone, 2.6):
				_boss.call("note_gavel", stomp)
	_boss.call("paint_world", "Throw at the blue pan.")


func _tick_banquet(delta: float, body: CharacterBody3D) -> void:
	_boss.call("tick_banquet", delta)
	if String(_boss.call("current_phase")) != "banquet":
		return
	var state: Dictionary = _boss.call("world_state")
	var plates: Array = state.get("plates", [])
	var stuffed: Array = state.get("stuffed", [])
	var hungry := int(state.get("hungry", -1))
	if _near(body, _belt_at, 3.2):
		_carry = true
	for index in plates.size():
		var node := _root.get_node_or_null("Seat%d" % index) as Node3D
		if node == null:
			continue
		var fed := index < stuffed.size() and bool(stuffed[index])
		node.scale = Vector3(1.3, 1.3, 1.3) if index == hungry and not fed else Vector3.ONE
		if _carry and index == hungry and _near(body, node.global_position, 1.8):
			_carry = false
			_boss.call("serve_seat", index)
		elif _carry and _near(body, node.global_position, 1.8) and index != hungry and not fed:
			_carry = false
			_boss.call("serve_seat", index)
	if _KEYS.use_held() and _cool <= 0.0:
		_cool = 0.4
		_boss.call("finish_serving")
		return
	var carrying := "carrying a plate" if _carry else "empty handed"
	_boss.call("paint_world", "Banquet %s. Hungry seat %s." % [carrying, str(hungry + 1) if hungry >= 0 else "none"])


func _tick_seltzer(delta: float, body: CharacterBody3D) -> void:
	var spot := _root.get_node_or_null("Seltzer") as Node3D
	if not _golf:
		if spot != null and _KEYS.use_held() and _near(body, spot.global_position, 2.4) and _cool <= 0.0:
			_golf = true
			_spray = 0.0
			_cool = 0.3
			_lock_toon()
	else:
		if _KEYS.held("jump"):
			_spray = minf(_spray + delta * 1.4, 3.0)
		elif _spray > 0.0:
			var unit := 1
			if _spray >= 2.2:
				unit = 3
			elif _spray >= 1.1:
				unit = 2
			_boss.call("note_seltzer", unit)
			_spray = 0.0
			_golf = false
			_cool = 0.3
			_free_toon()
	if _attack_left > 0.0:
		_attack_left -= delta
		if _attack_left <= 0.0 and _near(body, _attack_at, 3.4):
			_boss.call("note_golf", _attack_kind == "area")
	elif _clock > 4.0 and fposmod(_clock, 6.5) < delta:
		_attack_kind = "area" if randi() % 2 == 0 else "club"
		_attack_at = body.global_position
		_attack_left = 1.0
		_replace_marker("Swing", _attack_at, Color(0.75, 0.2, 0.2), Vector3(3.2, 0.15, 3.2))
	_boss.call("paint_world", "Seltzer charge %d." % int(minf(_spray, 3.0)))


func _begin(boss: Node) -> void:
	shutdown()
	_boss = boss
	_clock = 0.0
	_cool = 0.4
	_pies.clear()
	_shots.clear()
	_safes.clear()
	_goons.clear()
	_treasures.clear()
	_chairs.clear()
	_lawyers.clear()
	_crane = -1
	_held = -1
	_cannon = false
	_carry = false
	_golf = false
	_attack_left = 0.0
	var body := _body()
	_origin = body.global_position if body != null else Vector3.ZERO
	if body != null:
		_forward = -body.global_transform.basis.z
		_forward.y = 0.0
		if _forward.length_squared() < 0.01:
			_forward = Vector3(0, 0, -1)
		_forward = _forward.normalized()
		_right = _forward.cross(Vector3.UP).normalized()
	var host := boss.get_parent()
	var geom := host.get_node_or_null("Geometry") as Node3D if host != null else null
	_root = Node3D.new()
	_root.name = "BossRound"
	if geom != null:
		geom.add_child(_root)
	elif host != null:
		host.add_child(_root)


func _launch(body: CharacterBody3D, speed: float, color: Color, kind: String) -> void:
	if _cool > 0.0:
		return
	var camera := _camera()
	var aim := -camera.global_basis.z if camera != null else _forward
	var shot := {"at": body.global_position + Vector3(0, 1.4, 0), "vel": aim.normalized() * speed + Vector3(0, 4.0, 0), "done": false, "kind": kind, "mesh": _box(body.global_position + Vector3(0, 1.4, 0), color, Vector3(0.35, 0.35, 0.35), "Shot%d" % (_pies.size() + _shots.size()))}
	if kind == "pie":
		_pies.append(shot)
	else:
		_shots.append(shot)
	_cool = 0.35


func _fly(rows: Array[Dictionary], delta: float) -> void:
	for shot in rows:
		if bool(shot["done"]):
			continue
		var vel: Vector3 = shot["vel"]
		vel.y -= 18.0 * delta
		shot["vel"] = vel
		shot["at"] = shot["at"] + vel * delta
		var mesh := shot.get("mesh") as Node3D
		if mesh != null:
			mesh.global_position = shot["at"]
		if shot["at"].y < 0.2:
			shot["done"] = true


func _grab_safe() -> void:
	var best := -1
	var best_d := 3.0
	for index in _safes.size():
		if index == 0 or float(_safes[index]["fall"]) > 0.0 or not _other_holds_safe(index).is_empty():
			continue
		var gap := Vector2(_magnet.x, _magnet.z).distance_to(Vector2(_safes[index]["at"].x, _safes[index]["at"].z))
		if gap < best_d:
			best_d = gap
			best = index
	_held = best
	if best >= 0:
		_safes[best]["remote"] = false
		_begin_carry(_safes[best]["at"], true)
		return
	var goon_best := -1
	var goon_d := 3.0
	for index in _goons.size():
		if not bool(_goons[index].get("live", true)) or not _other_holds_goon(index).is_empty():
			continue
		var gap := Vector2(_magnet.x, _magnet.z).distance_to(Vector2(_goons[index]["at"].x, _goons[index]["at"].z))
		if gap < goon_d:
			goon_d = gap
			goon_best = index
	if goon_best >= 0:
		_held = 100 + goon_best
		_begin_carry(_goons[goon_best]["at"], false)
		var phase := String(_goons[goon_best].get("phase", ""))
		if phase == "walk" or phase == "emerge":
			_wiggle = 2.0
			_wiggle_t = 0.0
			_sfx("res://assets/audio/battle/SA_finger_wag.ogg")
		else:
			_wiggle = 0.0


func _drop_safe() -> void:
	if _held < 0:
		return
	var at := _held_point()
	_finish_clank()
	_wiggle = 0.0
	if _held >= 100:
		var index := _held - 100
		_goons[index]["at"] = at
		_held = -1
		var impact := _throw_impact()
		var near := _near_point(at, _boss_pos, 8.0)
		var killed := near and impact >= 0.1
		if near:
			_hit_noise(impact, 0.1)
			# CashbotBossGoonImpact. A straight drop does not count.
			if killed:
				var scale := float(_goons[index].get("scale", 1.0))
				_boss.call("note_goon_hit", impact, scale)
				_goons[index]["live"] = false
				_release_goon_door(index)
				_hide_goon_cone(_goons[index])
				var gone := _root.get_node_or_null("Goon%d" % index)
				if gone != null:
					gone.visible = false
			else:
				_stun_goon(index)
		_drop_token += 1
		_drop_left = 1.0
		_drop_row = {
			"drop": _drop_token,
			"drop_goon": index,
			"sx": at.x, "sy": at.y, "sz": at.z,
			"killed": killed,
			"stun": near and not killed,
		}
		return
	var safe: Dictionary = _safes[_held]
	safe["at"] = at
	safe["fall"] = 1.0
	safe["vx"] = _magnet_vel.x
	safe["vy"] = _magnet_vel.y
	safe["vz"] = _magnet_vel.z
	safe["struck"] = false
	# __hitBoss. Impact is how much of the throw points along the crane.
	safe["impact"] = _throw_impact()
	safe["remote"] = false
	_safes[_held] = safe
	_drop_token += 1
	_drop_left = 1.0
	_drop_row = {
		"drop": _drop_token,
		"drop_safe": _held,
		"sx": at.x, "sy": at.y, "sz": at.z,
		"dx": safe["vx"], "dy": safe["vy"], "dz": safe["vz"],
	}
	_held = -1


func _spawn_goons(delta: float) -> void:
	# doNextGoon. None appear while he is dizzy, and eight is the cap.
	var state: Dictionary = _boss.call("world_state")
	if float(state.get("dizzy", 0.0)) > 0.0:
		return
	var alive := 0
	for goon in _goons:
		if bool(goon.get("live", true)):
			alive += 1
	_goon_left = maxf(_goon_left - delta, 0.0)
	if _goon_left > 0.0 or alive >= 8:
		return
	var along := clampf(maxf(float(state.get("hp", 0)) / 500.0, _clock / 1800.0), 0.0, 1.0)
	var strength := int(round(lerpf(5.0, 25.0, along)))
	var heal := 3
	if strength > 15:
		heal = 12
	elif strength > 10:
		heal = 10
	var front := _goons.size() % 2 == 0
	var door := "DoorFront" if front else "DoorRear"
	var out := _door_out(door)
	var at := _boss_pos
	var speed := lerpf(3.0, 7.0, along)
	var spread := 0.2 * (1.0 - absf(along - 0.5) * 2.0)
	var sample := clampf(along + randf_range(-spread, spread), 0.0, 1.0)
	var dest := at + out * 15.0
	dest.y = at.y
	var node := _model_or_box("res://assets/cog_hq/goon.glb", Vector3.ZERO, "Goon%d" % _goons.size(), Color(0.35, 0.35, 0.4), Vector3(1.2, 1.8, 1.2))
	_add_goon_shadow(node)
	node.global_position = at
	node.scale = Vector3.ONE * lerpf(0.5, 1.5, along)
	_hold_cfo_door(door, true)
	_goons.append({
		"at": at,
		"from": at,
		"to": dest,
		"move": 15.0 / speed,
		"span": 15.0 / speed,
		"phase": "emerge",
		"door": door,
		"door_held": true,
		"live": true,
		"strength": strength,
		"scale": lerpf(0.5, 1.5, along),
		"speed": speed,
		"heal": heal,
		"pause": lerpf(30.0, 8.0, along),
		"clip_t": 0.0,
		"face": out,
		"fov": lerpf(70.0, 80.0, sample),
		"reach": lerpf(6.0, 15.0, sample),
		"cone": _make_goon_cone(),
	})
	_goon_left = lerpf(10.0, 2.0, along)
	_field_send = 0.0


func _drop_treasure(at: Vector3, heal: int) -> void:
	var name := "Treasure%d" % (_treasures.size() + 1)
	var away := at - _boss_pos
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3(1.0, 0.0, 0.0)
	var angle := randf() * TAU
	var land := _boss_pos + away.normalized() * 27.0 + Vector3(cos(angle), 0.0, sin(angle)) * 10.0
	land.y = _boss_pos.y + 0.45
	var host := _boss.get_parent() if _boss != null else self
	var root := Node3D.new()
	root.name = name
	root.scale = Vector3(0.9, 0.9, 0.9)
	host.add_child(root)
	var packed := load(_treasure_scene(heal)) as PackedScene
	if packed != null:
		var model := packed.instantiate()
		root.add_child(model)
	root.global_position = at
	_treasures.append({
		"at": land,
		"from": at,
		"heal": heal,
		"name": name,
		"fly": 1.0,
		"node": root,
	})


func _vault_walls() -> Array[Vector2]:
	# wallsCollision on EndVault, placed at (84, -201, -6). The north doorway stays open.
	return [
		Vector2(104.55, -266.94), Vector2(88.59, -282.9),
		Vector2(88.59, -282.9), Vector2(72.63, -298.86),
		Vector2(72.63, -298.86), Vector2(72.63, -330.77),
		Vector2(72.63, -330.77), Vector2(88.59, -346.73),
		Vector2(88.59, -346.73), Vector2(104.55, -362.69),
		Vector2(104.55, -362.69), Vector2(136.46, -362.69),
		Vector2(136.46, -362.69), Vector2(152.42, -346.73),
		Vector2(152.42, -346.73), Vector2(168.38, -330.77),
		Vector2(168.38, -330.77), Vector2(168.38, -298.86),
		Vector2(168.38, -298.86), Vector2(152.42, -282.9),
		Vector2(152.42, -282.9), Vector2(136.46, -266.94),
	]


func _closest_on_segment(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var span := b - a
	var length := span.length_squared()
	if length < 0.0001:
		return a
	var along := clampf((point - a).dot(span) / length, 0.0, 1.0)
	return a + span * along


func _panda_flat(at: Vector3) -> Vector2:
	var local := _root.to_local(at) if _root != null else at
	return Vector2(local.x, local.y)


func _panda_dir(at: Vector3, face: Vector3) -> Vector2:
	var delta := _panda_flat(at + face) - _panda_flat(at)
	if delta.length_squared() < 0.0001:
		return Vector2(0.0, 1.0)
	return delta.normalized()


func _godot_dir(at: Vector3, panda_dir: Vector2) -> Vector3:
	if _root == null:
		return Vector3(panda_dir.x, 0.0, -panda_dir.y)
	var local := _root.to_local(at)
	var ahead := _root.to_global(Vector3(local.x + panda_dir.x, local.y + panda_dir.y, local.z))
	var face := ahead - _root.to_global(local)
	face.y = 0.0
	if face.length_squared() < 0.0001:
		return Vector3(0.0, 0.0, -1.0)
	return face.normalized()


func _turn_flat(dir: Vector2, heading: float) -> Vector2:
	var rad := deg_to_rad(heading)
	var left := Vector2(-dir.y, dir.x)
	var turned := dir * cos(rad) + left * sin(rad)
	if turned.length_squared() < 0.0001:
		return dir
	return turned.normalized()


func _ray_segment(origin: Vector2, end: Vector2, a: Vector2, b: Vector2) -> float:
	var span := end - origin
	var edge := b - a
	var denom := span.x * edge.y - span.y * edge.x
	if absf(denom) < 0.0001:
		return -1.0
	var offset := a - origin
	var along := (offset.x * edge.y - offset.y * edge.x) / denom
	var across := (offset.x * span.y - offset.y * span.x) / denom
	if along >= 0.0 and along <= 1.0 and across >= 0.0 and across <= 1.0:
		return along * span.length()
	return -1.0


func _wall_ray(origin: Vector2, dir: Vector2, length: float) -> float:
	var best := length
	var walls := _vault_walls()
	var end := origin + dir * length
	for index in range(0, walls.size(), 2):
		var hit := _ray_segment(origin, end, walls[index], walls[index + 1])
		if hit >= 0.0 and hit < best:
			best = hit
	return best


func _goon_wall_dist(at: Vector3, face: Vector3) -> float:
	return _wall_ray(_panda_flat(at), _panda_dir(at, face), 15.0)


func _choose_goon_heading(at: Vector3, face: Vector3) -> Dictionary:
	# directionTable. Straight ahead is preferred. A blocked feeler scores nothing.
	var headings: Array[float] = [0.0, 10.0, -10.0, 20.0, -20.0, 40.0, -40.0, 60.0, -60.0, 80.0, -80.0, 120.0, -120.0, 180.0]
	var weights: Array[float] = [15.0, 10.0, 10.0, 8.0, 8.0, 5.0, 5.0, 4.0, 4.0, 3.0, 3.0, 2.0, 2.0, 1.0]
	var dir := _panda_dir(at, face)
	var origin := _panda_flat(at)
	var net := 0.0
	var scores: Array[float] = []
	var dists: Array[float] = []
	for index in headings.size():
		var turned := _turn_flat(dir, headings[index])
		var dist := _wall_ray(origin, turned, 15.0)
		if dist < 1.2:
			dist = 0.0
		var score := dist * weights[index]
		scores.append(score)
		dists.append(dist)
		net += score
	if net <= 0.0:
		var back := _boss_pos - at
		back.y = 0.0
		if back.length_squared() < 0.01:
			back = face
		return {"face": back.normalized(), "dist": 4.0}
	var pick := randf() * net
	var chosen := 0
	for index in scores.size():
		pick -= scores[index]
		if pick <= 0.0:
			chosen = index
			break
	var heading := _turn_flat(dir, headings[chosen])
	return {"face": _godot_dir(at, heading), "dist": dists[chosen]}


func _bounce_safe_walls(safe: Dictionary) -> void:
	if _root == null:
		return
	var at: Vector3 = safe["at"]
	var local := _root.to_local(at)
	var center := Vector2(local.x, local.y)
	var ahead := _root.to_local(at + Vector3(float(safe.get("vx", 0.0)), 0.0, float(safe.get("vz", 0.0))))
	var vel := Vector2(ahead.x - local.x, ahead.y - local.y)
	var walls := _vault_walls()
	for _step in 2:
		for index in range(0, walls.size(), 2):
			var closest := _closest_on_segment(center, walls[index], walls[index + 1])
			var away := center - closest
			var dist := away.length()
			if dist >= 3.95 or dist < 0.0001:
				continue
			var normal := away / dist
			center += normal * (4.0 - dist)
			var into := vel.dot(normal)
			if into < 0.0:
				vel -= (1.0 + 0.45) * into * normal
	var moved := _root.to_global(Vector3(center.x, center.y, local.z))
	var pushed := _root.to_global(Vector3(center.x + vel.x, center.y + vel.y, local.z)) - moved
	safe["at"] = Vector3(moved.x, at.y, moved.z)
	safe["vx"] = pushed.x
	safe["vz"] = pushed.z


func _separate_safes() -> void:
	for left in _safes.size():
		if bool(_safes[left].get("pinned", false)):
			continue
		if left == 0 and float(_safes[left].get("fall", 0.0)) <= 0.0:
			continue
		for right in range(left + 1, _safes.size()):
			if bool(_safes[right].get("pinned", false)):
				continue
			if right == 0 and float(_safes[right].get("fall", 0.0)) <= 0.0:
				continue
			var a: Dictionary = _safes[left]
			var b: Dictionary = _safes[right]
			var at_a: Vector3 = a["at"]
			var at_b: Vector3 = b["at"]
			var flat := Vector2(at_a.x - at_b.x, at_a.z - at_b.z)
			var dist := flat.length()
			if dist >= 8.0 or dist < 0.001:
				continue
			var normal := flat / dist
			var push := (8.0 - dist) * 0.5
			at_a.x += normal.x * push
			at_a.z += normal.y * push
			at_b.x -= normal.x * push
			at_b.z -= normal.y * push
			var vel_a := Vector2(float(a.get("vx", 0.0)), float(a.get("vz", 0.0)))
			var vel_b := Vector2(float(b.get("vx", 0.0)), float(b.get("vz", 0.0)))
			var into := (vel_a - vel_b).dot(normal)
			if into < 0.0:
				var bounce := into * (1.0 + 0.45) * 0.5
				vel_a -= normal * bounce
				vel_b += normal * bounce
			a["at"] = at_a
			b["at"] = at_b
			a["vx"] = vel_a.x
			a["vz"] = vel_a.y
			b["vx"] = vel_b.x
			b["vz"] = vel_b.y
			for row in [a, b]:
				if float(row.get("fall", 0.0)) <= 0.0:
					row["fall"] = 1.0
					row["vy"] = 0.0
					row["ground"] = true
			var node_a := _root.get_node_or_null("Safe%d" % left) as Node3D if _root != null else null
			var node_b := _root.get_node_or_null("Safe%d" % right) as Node3D if _root != null else null
			if node_a != null:
				node_a.global_position = at_a
			if node_b != null:
				node_b.global_position = at_b
			_safes[left] = a
			_safes[right] = b


func _land_safe(at: Vector3, impact: float, already: bool) -> void:
	_sfx("res://assets/audio/battle/AA_drop_bigweight_miss.ogg")
	if not _driving:
		return
	if not already and _near_point(Vector3(at.x, 0.0, at.z), _boss_pos, 8.0):
		_hit_noise(impact, 0.0)
		_boss.call("note_safe", impact)
		return
	for index in _goons.size():
		if bool(_goons[index].get("live", true)) and _near_point(at, _goons[index]["at"], 1.8):
			_crush_goon(index)
			var gone := _root.get_node_or_null("Goon%d" % index)
			if gone != null:
				gone.visible = false
			return


func _fire_cannon() -> void:
	var body := _body()
	var aim := _crane_h
	var land := _origin
	if _jury != null:
		land = _jury.global_position + _right * aim + _forward * (_power - 0.5) * 8.0
	elif body != null:
		land = body.global_position + _forward * (18.0 + _power * 28.0) + _right * aim
	var seated := _jury != null and Vector2(land.x, land.z).distance_to(Vector2(_jury.global_position.x, _jury.global_position.z)) < 8.0
	if body != null:
		body.global_position = land + Vector3(0.0, 1.0, 0.0)
	_boss.call("note_chair", seated)
	_cannon = false
	_cool = 0.4
	_free_toon()
	var state: Dictionary = _boss.call("world_state")
	if int(state.get("shots", 0)) >= 12:
		_boss.call("finish_cannons")


func _fresh_press() -> bool:
	var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	return down and not _pressed and _cool <= 0.0


func _near(body: CharacterBody3D, at: Vector3, reach: float) -> bool:
	return Vector2(body.global_position.x, body.global_position.z).distance_to(Vector2(at.x, at.z)) <= reach


func _near_point(a: Vector3, b: Vector3, reach: float) -> bool:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) <= reach


func _body() -> CharacterBody3D:
	if _boss == null:
		return null
	var host := _boss.get_parent()
	if host == null:
		return null
	return host.get_node_or_null("Player") as CharacterBody3D


func _camera() -> Camera3D:
	var host := _boss.get_parent()
	if host == null:
		return null
	var toon := host.get_node_or_null("ToonCamera") as Camera3D
	if toon != null:
		return toon
	return host.find_child("Camera", true, false) as Camera3D


func _lock_toon() -> void:
	var host := _boss.get_parent()
	var toon := host.get_node_or_null("PlaygroundToon") if host != null else null
	if toon != null and toon.has_method("hold_for_race"):
		toon.call("hold_for_race", true)


func _free_toon() -> void:
	if _boss == null:
		return
	var host := _boss.get_parent()
	var toon := host.get_node_or_null("PlaygroundToon") if host != null else null
	if toon != null and toon.has_method("hold_for_race"):
		toon.call("hold_for_race", false)


func _tell(text: String) -> void:
	_boss.call("set_round_text", text)


func _geometry() -> Node3D:
	if _boss == null:
		return null
	var host := _boss.get_parent()
	if host == null:
		return null
	return host.get_node_or_null("Geometry") as Node3D


func _find(node_name: String) -> Node3D:
	var geom := _geometry()
	if geom == null:
		return null
	return geom.find_child(node_name, true, false) as Node3D


func _find_all(prefix: String) -> Array[Node3D]:
	var found: Array[Node3D] = []
	var geom := _geometry()
	if geom == null:
		return found
	_collect(geom, prefix, found)
	return found


func _collect(node: Node, prefix: String, found: Array[Node3D]) -> void:
	if node is Node3D and String(node.name).begins_with(prefix):
		found.append(node)
	for child in node.get_children():
		_collect(child, prefix, found)


func _panda_box(x: float, y: float, z: float, color: Color, size: Vector3, node_name: String) -> MeshInstance3D:
	var mesh := _box(Vector3.ZERO, color, size, node_name)
	# The boss glb root converts panda (x, y, z) to Godot (x, z, -y).
	mesh.position = Vector3(x, y, z)
	return mesh


func _model_or_box(path: String, at: Vector3, node_name: String, color: Color, size: Vector3) -> Node3D:
	if path != "" and ResourceLoader.exists(path):
		var packed = load(path)
		if packed is PackedScene:
			var model := (packed as PackedScene).instantiate() as Node3D
			model.name = node_name
			_root.add_child(model)
			model.position = at
			return model
	return _panda_box(at.x, at.y, at.z, color, size, node_name)


func _replace_marker(node_name: String, at: Vector3, color: Color, size: Vector3) -> void:
	var old := _root.get_node_or_null(node_name)
	if old != null:
		old.free()
	_box(at, color, size, node_name)


func _mark(at: Vector3, color: Color, size: Vector3, node_name: String) -> void:
	_box(at, color, size, node_name)


func _box(at: Vector3, color: Color, size: Vector3, node_name: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.name = node_name
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	_root.add_child(mesh)
	mesh.global_position = at + Vector3(0, size.y * 0.5, 0)
	return mesh


func _controls_local(root_pos: Vector3) -> Vector3:
	# controls.setPos(0, -4.9, 0) in the crane root, whose heading points at him.
	var to_boss := Vector3(120.0, -315.0, 0.0) - root_pos
	to_boss.z = 0.0
	if to_boss.length_squared() < 0.01:
		return Vector3.ZERO
	return -to_boss.normalized() * 4.9


func _controls_at(pad: Node3D) -> Vector3:
	if pad == null:
		return Vector3.ZERO
	return pad.to_global(_controls_local(pad.position))


func _shift_controls(crane: Node3D) -> void:
	var shift := _controls_local(crane.position)
	for child in crane.get_children():
		var part := child as Node3D
		if part != null:
			part.position += shift


func _panda_hpr(heading: float, pitch: float, roll: float) -> Basis:
	# Panda setHpr: heading about Z, pitch about X, roll about Y.
	var turn := Quaternion(Vector3(0, 0, 1), deg_to_rad(heading))
	var tilt := Quaternion(Vector3(1, 0, 0), deg_to_rad(pitch))
	var twist := Quaternion(Vector3(0, 1, 0), deg_to_rad(roll))
	return Basis(twist * tilt * turn)


func _plant_goon_shadow(goon: Node3D) -> void:
	# ShadowPlacer keeps the card on the floor under the body.
	var shadow := goon.get_node_or_null("drop_shadow") as MeshInstance3D
	if shadow == null or not shadow.visible:
		return
	var up := goon.global_transform.basis.z
	if absf(up.y) < 0.001:
		return
	var floor_y := _boss_pos.y + 0.05
	shadow.position = Vector3(0.0, 0.0, (floor_y - goon.global_position.y) / up.y)
	shadow.rotation = Vector3.ZERO


func _crane_pads() -> Array[Node3D]:
	var pads: Array[Node3D] = []
	if _root == null:
		return pads
	for index in 4:
		var pad := _root.get_node_or_null("Crane%d" % index) as Node3D
		if pad != null:
			pads.append(pad)
	return pads


func _named(node_name: String) -> Array[Node3D]:
	var found: Array[Node3D] = []
	if _root == null:
		return found
	for child in _root.get_children():
		if child is Node3D and String(child.name).begins_with(node_name):
			found.append(child)
	return found


func _swing_of(index: int) -> float:
	if index == _crane:
		return _crane_h
	return float(_other_crane(index).get("h", 0.0))


func _other_crane(index: int) -> Dictionary:
	for row in _others.values():
		if int((row as Dictionary).get("crane", -1)) == index:
			return row
	return {}


func _other_holds_safe(index: int) -> Dictionary:
	for row in _others.values():
		if int((row as Dictionary).get("held", -1)) == index:
			return row
	return {}


func _other_holds_goon(index: int) -> Dictionary:
	for row in _others.values():
		if int((row as Dictionary).get("held", -1)) == 100 + index:
			return row
	return {}


func _crane_taken(index: int) -> bool:
	return not _other_crane(index).is_empty()


func _sim_owner() -> bool:
	if not ToonNet.networked():
		return true
	var best := ToonNet.peer_id()
	var mine := ToonNet.district_id()
	for channel in ToonNet.channels("toon:"):
		var row := ToonNet.latest(channel)
		if int(row.get("district", -1)) != mine:
			continue
		if not String(row.get("place", "")).ends_with("cashbot_cfo.tscn"):
			continue
		var peer := channel.trim_prefix("toon:").to_int()
		if peer > 0 and peer < best:
			best = peer
	return ToonNet.peer_id() == best


func _prepare_field() -> void:
	_driving = false
	if not ToonNet.networked():
		_driving = true
		return
	if not _sim_owner():
		_apply_field()
		return
	if not _field_ready:
		var snap := ToonNet.latest("cfo-field")
		if not snap.is_empty():
			_apply_field()
			_field_ready = true
			return
		_field_ready = true
	_driving = true


func _publish_field(delta: float) -> void:
	if not ToonNet.networked():
		return
	_field_send = maxf(_field_send - delta, 0.0)
	if _field_send > 0.0:
		return
	_field_send = 0.2
	var safes: Array = []
	for index in _safes.size():
		var safe: Dictionary = _safes[index]
		var at: Vector3 = safe.get("at", Vector3.ZERO)
		safes.append({
			"i": index,
			"x": at.x, "y": at.y, "z": at.z,
			"fall": float(safe.get("fall", 0.0)),
			"vx": float(safe.get("vx", 0.0)),
			"vy": float(safe.get("vy", 0.0)),
			"vz": float(safe.get("vz", 0.0)),
			"struck": bool(safe.get("struck", false)),
			"ground": bool(safe.get("ground", false)),
			"impact": float(safe.get("impact", 0.0)),
			"floor": float(safe.get("floor", at.y)),
		})
	var goons: Array = []
	for goon in _goons:
		var spot: Dictionary = goon
		var spot_at: Vector3 = spot.get("at", Vector3.ZERO)
		var face: Vector3 = spot.get("face", Vector3(0.0, 0.0, -1.0))
		var frm: Vector3 = spot.get("from", spot_at)
		var dest: Vector3 = spot.get("to", spot_at)
		goons.append({
			"x": spot_at.x, "y": spot_at.y, "z": spot_at.z,
			"fx": face.x, "fy": face.y, "fz": face.z,
			"ax": frm.x, "ay": frm.y, "az": frm.z,
			"bx": dest.x, "by": dest.y, "bz": dest.z,
			"scale": float(spot.get("scale", 1.0)),
			"speed": float(spot.get("speed", 4.0)),
			"strength": int(spot.get("strength", 5)),
			"heal": int(spot.get("heal", 3)),
			"fov": float(spot.get("fov", 75.0)),
			"reach": float(spot.get("reach", 12.0)),
			"phase": String(spot.get("phase", "walk")),
			"live": bool(spot.get("live", true)),
			"clip": float(spot.get("clip_t", 0.0)),
			"move": float(spot.get("move", 0.0)),
			"span": float(spot.get("span", 1.0)),
			"pause": float(spot.get("pause", 0.0)),
			"door": String(spot.get("door", "")),
			"door_held": bool(spot.get("door_held", false)),
		})
	ToonNet.cfo_field({
		"safes": safes,
		"goons": goons,
		"goon_left": _goon_left,
		"zap_peer": _zap_peer,
		"zap_seq": _zap_seq,
		"zap_strength": _zap_strength,
		"zap_heal": _zap_heal,
		"zx": _zap_at.x, "zy": _zap_at.y, "zz": _zap_at.z,
	})


func _apply_field() -> void:
	if _root == null or _boss == null or not ToonNet.networked():
		return
	var snap := ToonNet.latest("cfo-field")
	if snap.is_empty():
		return
	var rows: Array = snap.get("safes", [])
	for row in rows:
		var data: Dictionary = row
		var index := int(data.get("i", -1))
		if index <= 0 or index >= _safes.size() or _held == index:
			continue
		var safe: Dictionary = _safes[index]
		if float(safe.get("fall", 0.0)) > 0.0 and not bool(safe.get("remote", false)):
			continue
		var at := Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0)))
		var was_ground := bool(safe.get("ground", false))
		safe["at"] = at
		safe["fall"] = float(data.get("fall", 0.0))
		safe["vx"] = float(data.get("vx", 0.0))
		safe["vy"] = float(data.get("vy", 0.0))
		safe["vz"] = float(data.get("vz", 0.0))
		safe["struck"] = bool(data.get("struck", false))
		safe["ground"] = bool(data.get("ground", false))
		safe["impact"] = float(data.get("impact", 0.0))
		safe["floor"] = float(data.get("floor", at.y))
		safe["remote"] = true
		safe["pinned"] = false
		_safes[index] = safe
		var node := _root.get_node_or_null("Safe%d" % index) as Node3D
		if node != null:
			node.global_position = at
			node.visible = true
		if bool(safe.get("ground", false)) and not was_ground:
			_sfx("res://assets/audio/battle/AA_drop_bigweight_miss.ogg")
	var goon_rows: Array = snap.get("goons", [])
	while _goons.size() < goon_rows.size():
		_add_field_goon()
	for index in goon_rows.size():
		var goon_row: Dictionary = goon_rows[index]
		var goon: Dictionary = _goons[index]
		var was_door := bool(goon.get("door_held", false))
		var goon_at := Vector3(float(goon_row.get("x", 0.0)), float(goon_row.get("y", 0.0)), float(goon_row.get("z", 0.0)))
		if _held != 100 + index:
			goon["at"] = goon_at
		goon["from"] = Vector3(float(goon_row.get("ax", goon_at.x)), float(goon_row.get("ay", goon_at.y)), float(goon_row.get("az", goon_at.z)))
		goon["to"] = Vector3(float(goon_row.get("bx", goon_at.x)), float(goon_row.get("by", goon_at.y)), float(goon_row.get("bz", goon_at.z)))
		goon["face"] = Vector3(float(goon_row.get("fx", 0.0)), float(goon_row.get("fy", 0.0)), float(goon_row.get("fz", -1.0)))
		goon["scale"] = float(goon_row.get("scale", 1.0))
		goon["speed"] = float(goon_row.get("speed", 4.0))
		goon["strength"] = int(goon_row.get("strength", 5))
		goon["heal"] = int(goon_row.get("heal", 3))
		goon["fov"] = float(goon_row.get("fov", 75.0))
		goon["reach"] = float(goon_row.get("reach", 12.0))
		var phase := String(goon_row.get("phase", "walk"))
		var same := String(goon.get("phase", "")) == phase
		goon["phase"] = phase
		var remote_live := bool(goon_row.get("live", true))
		if not bool(goon.get("live", true)):
			remote_live = false
		goon["live"] = remote_live
		if not same or phase == "collapse" or phase == "recovery" or phase == "hold":
			goon["clip_t"] = float(goon_row.get("clip", 0.0))
		goon["move"] = float(goon_row.get("move", 0.0))
		goon["span"] = float(goon_row.get("span", 1.0))
		goon["pause"] = float(goon_row.get("pause", 0.0))
		goon["door"] = String(goon_row.get("door", ""))
		var door_held := bool(goon_row.get("door_held", false))
		goon["door_held"] = door_held
		_goons[index] = goon
		if door_held and not was_door:
			_hold_cfo_door(String(goon.get("door", "")), true)
		elif was_door and not door_held:
			_hold_cfo_door(String(goon.get("door", "")), false)
		_show_field_goon(index)
	_goon_left = float(snap.get("goon_left", _goon_left))
	var seq := int(snap.get("zap_seq", 0))
	if seq != _zap_seen and int(snap.get("zap_peer", 0)) == ToonNet.peer_id():
		_zap_seen = seq
		_boss.call("note_goon", int(snap.get("zap_strength", 5)))
		var actor := _toon_actor()
		if actor != null and actor.has_method("flash_stun"):
			actor.call("flash_stun")
		_drop_treasure(Vector3(float(snap.get("zx", 0.0)), float(snap.get("zy", 0.0)), float(snap.get("zz", 0.0))), int(snap.get("zap_heal", 3)))


func _add_field_goon() -> void:
	var index := _goons.size()
	var node := _model_or_box("res://assets/cog_hq/goon.glb", Vector3.ZERO, "Goon%d" % index, Color(0.35, 0.35, 0.4), Vector3(1.2, 1.8, 1.2))
	_add_goon_shadow(node)
	_goons.append({
		"at": Vector3.ZERO,
		"from": Vector3.ZERO,
		"to": Vector3.ZERO,
		"phase": "walk",
		"live": true,
		"door_held": false,
		"door": "",
		"face": Vector3(0.0, 0.0, -1.0),
		"clip_t": 0.0,
		"scale": 1.0,
		"cone": _make_goon_cone(),
	})


func _show_field_goon(index: int) -> void:
	if index < 0 or index >= _goons.size() or _root == null:
		return
	var goon: Dictionary = _goons[index]
	var node := _root.get_node_or_null("Goon%d" % index) as Node3D
	if node == null:
		return
	var live := bool(goon.get("live", true))
	node.visible = live
	if not live:
		_hide_goon_cone(goon)
		var hidden := node.get_node_or_null("drop_shadow") as MeshInstance3D
		if hidden != null:
			hidden.visible = false
		return
	var at: Vector3 = goon["at"]
	var rider := _other_holds_goon(index)
	if _held == 100 + index:
		at = _held_point()
	elif not rider.is_empty():
		at = _remote_goon_hang(rider, goon)
	goon["at"] = at
	var scale := float(goon.get("scale", 1.0))
	node.global_position = at
	node.scale = Vector3.ONE * scale
	var phase := String(goon.get("phase", "walk"))
	var carrying := _held == 100 + index or not rider.is_empty()
	if not carrying and (phase == "emerge" or phase == "walk"):
		_yaw_goon(node, goon.get("face", Vector3(0.0, 0.0, -1.0)))
	_pose_battle_goon(node, goon)
	var shadow := node.get_node_or_null("drop_shadow") as MeshInstance3D
	if shadow != null:
		shadow.visible = not carrying
	_plant_goon_shadow(node)
	_aim_goon_cone(goon, at, (phase == "emerge" or phase == "walk") and not carrying)
	_goons[index] = goon


func _remote_goon_hang(row: Dictionary, goon: Dictionary) -> Vector3:
	var scale := float(goon.get("scale", 1.0))
	var phase := String(goon.get("phase", ""))
	var drop := -3.6 if phase == "walk" or phase == "emerge" else -2.2
	return Vector3(float(row.get("mx", 0.0)), float(row.get("my", 0.0)), float(row.get("mz", 0.0))) + Vector3(0.0, drop * scale, 0.0)


func _remote_actors() -> Array[Node3D]:
	var found: Array[Node3D] = []
	if _boss == null:
		return found
	var host := _boss.get_parent()
	if host == null:
		return found
	var local := ToonNet.peer_id()
	for node in host.find_children("", "ToonActor", true, false):
		if not node.has_meta("peer"):
			continue
		var peer := int(node.get_meta("peer"))
		if peer <= 0 or peer == local:
			continue
		var actor := node as Node3D
		if actor != null:
			found.append(actor)
	return found


func _read_cranes() -> void:
	_others.clear()
	if not ToonNet.networked():
		return
	var me := ToonNet.peer_id()
	for channel in ToonNet.channels("cfo-crane:"):
		var row := ToonNet.latest(channel)
		var peer := int(row.get("peer", channel.trim_prefix("cfo-crane:").to_int()))
		if peer == me:
			if _crane >= 0 and int(row.get("crane", -1)) < 0 and int(row.get("seq", 0)) == _sent_seq and _sent_seq > 0:
				_leave_crane()
			continue
		if int(row.get("crane", -1)) < 0:
			var parked := _root.get_node_or_null("RemoteGoon%d" % peer) as Node3D if _root != null else null
			if parked != null:
				parked.visible = false
			continue
		_others[peer] = row
		_apply_remote_drop(peer, row)


func _apply_remote_drop(peer: int, row: Dictionary) -> void:
	var token := int(row.get("drop", 0))
	if token <= 0 or int(_drops_seen.get(peer, 0)) == token:
		return
	_drops_seen[peer] = token
	if not _sim_owner():
		return
	var goon_index := int(row.get("drop_goon", -1))
	if goon_index >= 0 and goon_index < _goons.size():
		var goon: Dictionary = _goons[goon_index]
		goon["at"] = Vector3(float(row.get("sx", 0.0)), float(row.get("sy", 0.0)), float(row.get("sz", 0.0)))
		_goons[goon_index] = goon
		if bool(row.get("killed", false)):
			goon["live"] = false
			_goons[goon_index] = goon
			_release_goon_door(goon_index)
			_hide_goon_cone(goon)
			var gone := _root.get_node_or_null("Goon%d" % goon_index) as Node3D if _root != null else null
			if gone != null:
				gone.visible = false
		elif bool(row.get("stun", false)):
			_stun_goon(goon_index)
		return
	var index := int(row.get("drop_safe", -1))
	if index <= 0 or index >= _safes.size():
		return
	var safe: Dictionary = _safes[index]
	safe["at"] = Vector3(float(row.get("sx", 0.0)), float(row.get("sy", 0.0)), float(row.get("sz", 0.0)))
	safe["vx"] = float(row.get("dx", 0.0))
	safe["vy"] = float(row.get("dy", 0.0))
	safe["vz"] = float(row.get("dz", 0.0))
	safe["fall"] = 1.0
	safe["struck"] = false
	safe["remote"] = true
	safe["ground"] = false
	safe["impact"] = 0.0
	safe["pinned"] = false
	_safes[index] = safe
	var node := _root.get_node_or_null("Safe%d" % index) as Node3D if _root != null else null
	if node != null:
		node.visible = true
		node.global_position = safe["at"]


func _share_crane(force: bool, delta: float = 0.0) -> void:
	if not ToonNet.networked():
		return
	_drop_left = maxf(_drop_left - delta, 0.0)
	_crane_send = maxf(_crane_send - delta, 0.0)
	if not force and _crane_send > 0.0:
		return
	_crane_send = 0.2
	_crane_seq += 1
	_sent_seq = _crane_seq
	var state := {
		"want": _crane,
		"seq": _crane_seq,
		"h": _crane_h,
		"y": _crane_y,
		"mx": _magnet.x,
		"my": _magnet.y,
		"mz": _magnet.z,
		"held": _held,
	}
	if _drop_left > 0.0:
		for key in _drop_row.keys():
			state[key] = _drop_row[key]
	ToonNet.cfo_crane(state)


func _leave_crane() -> void:
	_end_crane_fit()
	_crane = -1
	_mount_left = 0.0
	_cool = 0.3
	_clear_lever()
	_release_camera()
	_free_toon()
	_share_crane(true)


func _pose_other_cranes(pads: Array[Node3D]) -> void:
	var used: Dictionary = {}
	var riding: Dictionary = {}
	for row in _others.values():
		var crane := int((row as Dictionary).get("crane", -1))
		var peer := int((row as Dictionary).get("peer", 0))
		if crane < 0 or crane >= pads.size() or crane == _crane:
			continue
		used[crane] = true
		riding[peer] = true
		var magnet := _remote_magnet(crane)
		var at := Vector3(float(row.get("mx", 0.0)), float(row.get("my", 0.0)), float(row.get("mz", 0.0)))
		magnet.visible = true
		magnet.global_position = at
		_point_arm_node(magnet, _aim_of(pads[crane], float(row.get("h", 0.0))))
		_pose_carried_goon(peer, row, at)
	if _root == null:
		return
	for index in 4:
		if used.has(index):
			continue
		var extra := _root.get_node_or_null("RemoteMagnet%d" % index) as Node3D
		if extra != null:
			extra.visible = false
	for child in _root.get_children():
		var name := String(child.name)
		if not name.begins_with("RemoteGoon"):
			continue
		var peer := name.trim_prefix("RemoteGoon").to_int()
		if not riding.has(peer) and child is Node3D:
			(child as Node3D).visible = false


func _pose_carried_goon(peer: int, row: Dictionary, at: Vector3) -> void:
	var node := _root.get_node_or_null("RemoteGoon%d" % peer) as Node3D if _root != null else null
	if int(row.get("held", -1)) < 100:
		if node != null:
			node.visible = false
		return
	if node == null:
		node = _model_or_box("res://assets/cog_hq/goon.glb", Vector3.ZERO, "RemoteGoon%d" % peer, Color(0.35, 0.35, 0.4), Vector3(1.2, 1.8, 1.2))
		_add_goon_shadow(node)
	node.visible = true
	node.global_position = at + Vector3(0.0, -3.6, 0.0)
	var carried_shadow := node.get_node_or_null("drop_shadow") as MeshInstance3D
	if carried_shadow != null:
		carried_shadow.visible = false


func _remote_magnet(index: int) -> Node3D:
	var node := _root.get_node_or_null("RemoteMagnet%d" % index) as Node3D
	if node != null:
		return node
	return _model_or_box("res://assets/cog_hq/cfo_magnet.glb", Vector3.ZERO, "RemoteMagnet%d" % index, Color(0.7, 0.2, 0.2), Vector3(1.2, 1.2, 1.2))


func _aim_of(pad: Node3D, swing: float) -> Vector3:
	var to_boss := _boss_pos - pad.global_position
	to_boss.y = 0.0
	if to_boss.length_squared() < 0.01:
		to_boss = Vector3(0.0, 0.0, -1.0)
	return to_boss.normalized().rotated(Vector3.UP, deg_to_rad(swing))


func _pose_cranes(delta: float) -> void:
	var pads := _crane_pads()
	var aim := _drop_aim
	for index in pads.size():
		var swing := _swing_of(index)
		var pointed := _point_arm(pads[index], "Arm%d" % index, swing)
		_point_arm(pads[index], "Stick%d" % index, swing)
		if index == _crane:
			aim = pointed
			# The magnet rides the arm. Reach is the crane's slide.
			_magnet = pads[index].global_position + pointed * _crane_y + Vector3(0.0, 12.0, 0.0)
	if _crane >= 0:
		_drop_aim = aim
		if delta > 0.0:
			_magnet_vel = (_magnet - _magnet_prev) / delta
		_magnet_prev = _magnet
	var magnet := _root.get_node_or_null("Magnet") as Node3D
	_pose_cable(delta)
	if magnet != null and (_crane >= 0 or _held >= 0):
		_aim_magnet(magnet)
	if _crane >= 0 and _crane < pads.size():
		_follow_crane_shadow(pads[_crane].global_position + aim * _crane_y, aim)
	else:
		_hide_crane_shadow()
	_pose_other_cranes(pads)


func _point_arm(pad: Node3D, node_name: String, swing: float) -> Vector3:
	var to_boss := _boss_pos - pad.global_position
	to_boss.y = 0.0
	if to_boss.length_squared() < 0.01:
		to_boss = Vector3(0.0, 0.0, -1.0)
	var aim := to_boss.normalized().rotated(Vector3.UP, deg_to_rad(swing))
	var node := _root.get_node_or_null(node_name) as Node3D
	if node != null:
		var fitting := _fit_crane >= 0 and node_name == "Stick%d" % _fit_crane
		if not fitting:
			node.global_position = _controls_at(pad) if node_name.begins_with("Stick") else pad.global_position
		_point_arm_node(node, aim)
	return aim


func _point_arm_node(node: Node3D, aim: Vector3) -> void:
	# The arm runs about 44 units along local -Y, and local +Z is up.
	var flat := Vector3(aim.x, 0.0, aim.z)
	if flat.length_squared() < 0.0001:
		return
	flat = flat.normalized()
	var side := flat.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		return
	node.global_basis = Basis(-side.normalized(), -flat, Vector3.UP)


func _aim_magnet(magnet: Node3D) -> void:
	# The magnet looks at the middle link. Its up vector is panda (1, 1, 1).
	var toward := _link_p[1] - _magnet
	if toward.length_squared() < 0.0001:
		return
	var z_axis := toward.normalized()
	var up_hint := Vector3(1.0, 1.0, -1.0)
	var x_axis := up_hint.cross(z_axis)
	if x_axis.length_squared() < 0.0001:
		x_axis = Vector3.RIGHT.cross(z_axis)
	if x_axis.length_squared() < 0.0001:
		return
	x_axis = x_axis.normalized()
	# lookAt the middle link, then the magnet model gets setHpr(90, 45, 90).
	var look := Basis(x_axis, z_axis.cross(x_axis), z_axis)
	magnet.global_basis = look * _panda_hpr(90.0, 45.0, 90.0)


func _pose_cable(delta: float) -> void:
	# Three links under the carriage. Gravity is -32, and each link stays
	# within cableLength / 3 of the one above it, the way the crane shells do.
	if _root == null:
		return
	var showing := _crane >= 0 or _held >= 0
	if not showing:
		if _cable != null and is_instance_valid(_cable):
			_cable.visible = false
		var parked := _root.get_node_or_null("CableRope") as MeshInstance3D
		if parked != null:
			parked.visible = false
		_cable_ready = false
		return
	if _cable == null or not is_instance_valid(_cable):
		_cable = Node3D.new()
		_cable.name = "Cable"
		_root.add_child(_cable)
	var rest := _magnet
	var top := Vector3(rest.x, rest.y + 20.0, rest.z)
	var reach := 20.0 / 3.0
	if not _cable_ready:
		for index in 3:
			_link_p[index] = top.lerp(rest, float(index + 1) / 3.0)
			_link_v[index] = Vector3.ZERO
		_cable_ready = true
	var step := clampf(delta, 0.0, 0.05)
	var before := _link_p[2]
	if step > 0.0:
		for index in 3:
			_link_v[index] += Vector3(0.0, -32.0, 0.0) * step
			_link_p[index] += _link_v[index] * step
		for _pass in 6:
			var anchor := top
			for index in 3:
				var span := _link_p[index] - anchor
				var length := span.length()
				if length > reach and length > 0.0001:
					var along := span / length
					_link_p[index] = anchor + along * reach
					var outward := _link_v[index].dot(along)
					if outward > 0.0:
						_link_v[index] -= along * outward
				anchor = _link_p[index]
		for index in 3:
			_link_v[index] *= 0.98
	_magnet = _link_p[2]
	_magnet_vel = (_link_p[2] - before) / step if step > 0.0 else _link_v[2]
	_draw_rope([top, _link_p[0], _link_p[1], _link_p[2]])
	_cable.visible = true


func _begin_crane_fit(index: int) -> void:
	# accomodateToon. Scale, then slide the column to the hand and the platform to the feet.
	if _fit_crane >= 0 and _fit_crane != index:
		_set_crane_scale(_fit_crane, 1.0)
		_reset_crane_slide(_fit_crane)
	_fit_from = _crane_scale_now(index)
	_fit_crane = index
	_fit_to = _toon_body_scale()
	_fit_left = 0.5
	_fit_span = 0.5
	_fit_locked = false
	var crane := _root.get_node_or_null("Crane%d" % index) as Node3D if _root != null else null
	var column := _crane_part(crane, "column")
	var bottom := _crane_part(crane, "bottom")
	_fit_column_from = _part_rest(column)
	_fit_column_to = _fit_column_from
	_fit_bottom_from = _part_rest(bottom)
	_fit_bottom_to = _fit_bottom_from
	_fit_stick_from = _controls_at(crane) if crane != null else Vector3.ZERO
	_fit_stick_to = _fit_stick_from


func _end_crane_fit() -> void:
	if _fit_crane < 0:
		return
	var index := _fit_crane
	_fit_from = _crane_scale_now(index)
	_fit_to = 1.0
	_fit_left = 1.0
	_fit_span = 1.0
	_fit_locked = true
	var crane := _root.get_node_or_null("Crane%d" % index) as Node3D if _root != null else null
	var column := _crane_part(crane, "column")
	var bottom := _crane_part(crane, "bottom")
	if column != null:
		_fit_column_from = column.position
	_fit_column_to = _part_rest(column)
	if bottom != null:
		_fit_bottom_from = bottom.position
	_fit_bottom_to = _part_rest(bottom)
	var stick := _root.get_node_or_null("Stick%d" % index) as Node3D if _root != null else null
	_fit_stick_from = stick.global_position if stick != null else _fit_stick_to
	_fit_stick_to = _controls_at(crane) if crane != null else _fit_stick_from


func _toon_body_scale() -> float:
	var actor := _toon_actor() as Node3D
	if actor == null:
		return 1.0
	var scale := actor.transform.basis.get_scale().y
	if scale < 0.2:
		return 1.0
	return scale


func _crane_scale_now(index: int) -> float:
	if _root == null:
		return 1.0
	var crane := _root.get_node_or_null("Crane%d" % index) as Node3D
	if crane == null:
		return 1.0
	return crane.scale.y


func _apply_crane_fit(delta: float) -> void:
	if _fit_crane < 0 or _root == null:
		return
	if _fit_left > 0.0:
		_fit_left = maxf(_fit_left - delta, 0.0)
	var span := maxf(_fit_span, 0.01)
	var along := 1.0 - clampf(_fit_left / span, 0.0, 1.0)
	var eased := along * along * (3.0 - 2.0 * along)
	var crane := _root.get_node_or_null("Crane%d" % _fit_crane) as Node3D
	var restoring := is_equal_approx(_fit_to, 1.0)
	if crane != null and not restoring and not _fit_locked:
		_measure_fit_targets(crane)
		if _lever == "leverNeutral" or (_fit_left <= 0.0 and _lever != "leverReach"):
			_fit_locked = true
	var amount := lerpf(_fit_from, _fit_to, eased)
	_set_crane_scale(_fit_crane, amount)
	if crane != null:
		var column := _crane_part(crane, "column")
		var bottom := _crane_part(crane, "bottom")
		if column != null:
			column.position = _fit_column_from.lerp(_fit_column_to, eased)
		if bottom != null:
			bottom.position = _fit_bottom_from.lerp(_fit_bottom_to, eased)
	var stick := _root.get_node_or_null("Stick%d" % _fit_crane) as Node3D
	if stick != null:
		stick.global_position = _fit_stick_from.lerp(_fit_stick_to, eased)
	if _crane == _fit_crane:
		_aim_stick_at_hand()
		if stick != null:
			var aimed := stick.global_basis.orthonormalized()
			stick.global_basis = aimed.scaled(Vector3.ONE * amount)
	if _fit_left <= 0.0 and _crane < 0 and restoring:
		_reset_crane_slide(_fit_crane)
		_fit_crane = -1


func _set_crane_scale(index: int, amount: float) -> void:
	var crane := _root.get_node_or_null("Crane%d" % index) as Node3D
	if crane != null:
		crane.scale = Vector3.ONE * amount
	var stick := _root.get_node_or_null("Stick%d" % index) as Node3D
	if stick == null:
		return
	var aimed := stick.global_basis.orthonormalized()
	stick.global_basis = aimed.scaled(Vector3.ONE * amount)


func _crane_part(crane: Node3D, part_name: String) -> Node3D:
	if crane == null:
		return null
	return crane.find_child(part_name, true, false) as Node3D


func _part_rest(part: Node3D) -> Vector3:
	if part == null:
		return Vector3.ZERO
	if not part.has_meta("fit_rest"):
		part.set_meta("fit_rest", part.position)
	return part.get_meta("fit_rest")


func _reset_crane_slide(index: int) -> void:
	if _root == null:
		return
	var crane := _root.get_node_or_null("Crane%d" % index) as Node3D
	var column := _crane_part(crane, "column")
	var bottom := _crane_part(crane, "bottom")
	if column != null:
		column.position = _part_rest(column)
	if bottom != null:
		bottom.position = _part_rest(bottom)
	var stick := _root.get_node_or_null("Stick%d" % index) as Node3D
	if stick != null and crane != null:
		stick.global_position = _controls_at(crane)


func _measure_fit_targets(crane: Node3D) -> void:
	var actor := _toon_actor() as Node3D
	if actor == null:
		return
	var hand := actor.find_child("def_joint_right_hold", true, false) as Node3D
	if hand == null:
		return
	var column := _crane_part(crane, "column")
	var bottom := _crane_part(crane, "bottom")
	var saved := crane.scale
	crane.scale = Vector3.ONE * _fit_to
	var column_space := column.get_parent() as Node3D if column != null else crane
	var bottom_space := bottom.get_parent() as Node3D if bottom != null else crane
	var hand_local := column_space.to_local(hand.global_position)
	hand_local.z -= 1.0
	var feet := bottom_space.to_local(actor.global_position)
	crane.scale = saved
	_fit_column_to = hand_local
	var bottom_rest := _part_rest(bottom)
	_fit_bottom_to = Vector3(bottom_rest.x, bottom_rest.y, feet.z)
	_fit_stick_to = hand.global_position - Vector3.UP


func _draw_rope(points: Array) -> void:
	# RopeNode tube, thickness 0.5, three slices, MagnetControl at (0.83, 0.01) scale (0.15, 0.13).
	if _root == null or points.size() < 2:
		return
	if _cable != null:
		for child in _cable.get_children():
			if String(child.name).begins_with("Link"):
				child.visible = false
	var rope := _root.get_node_or_null("CableRope") as MeshInstance3D
	if rope == null:
		rope = MeshInstance3D.new()
		rope.name = "CableRope"
		var paint := StandardMaterial3D.new()
		var tex := load("res://assets/cog_hq/magnet_control.jpg") as Texture2D
		if tex != null:
			paint.albedo_texture = tex
		else:
			paint.albedo_color = Color(0.55, 0.57, 0.62)
		paint.uv1_scale = Vector3(0.15, 0.13, 1.0)
		paint.uv1_offset = Vector3(0.83, 0.01, 0.0)
		paint.texture_repeat = BaseMaterial3D.TEXTURE_REPEAT_ENABLED
		paint.roughness = 0.45
		paint.metallic = 0.35
		rope.material_override = paint
		rope.mesh = ImmediateMesh.new()
		_root.add_child(rope)
	var mesh := rope.mesh as ImmediateMesh
	if mesh == null:
		return
	mesh.clear_surfaces()
	var local: Array[Vector3] = []
	for point in points:
		local.append(_root.to_local(point as Vector3))
	var length := 0.01
	for index in local.size() - 1:
		length += local[index].distance_to(local[index + 1])
	var sides := 3
	var radius := 0.25
	var rings: Array[Dictionary] = []
	var walked := 0.0
	for index in local.size():
		var forward := Vector3.UP
		if index < local.size() - 1:
			forward = local[index + 1] - local[index]
		elif index > 0:
			forward = local[index] - local[index - 1]
		if forward.length_squared() < 0.0001:
			forward = Vector3.UP
		forward = forward.normalized()
		var hint := Vector3(0.0, -1.0, 0.0)
		if absf(forward.dot(hint)) > 0.95:
			hint = Vector3.UP
		var side := hint.cross(forward)
		if side.length_squared() < 0.0001:
			side = Vector3.RIGHT.cross(forward)
		side = side.normalized()
		var up := forward.cross(side).normalized()
		rings.append({"at": local[index], "side": side, "up": up, "v": walked / length})
		if index < local.size() - 1:
			walked += local[index].distance_to(local[index + 1])
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in rings.size() - 1:
		var a: Dictionary = rings[index]
		var b: Dictionary = rings[index + 1]
		for slice in sides:
			var u0 := float(slice) / float(sides)
			var u1 := float(slice + 1) / float(sides)
			var a0 := _rope_point(a, slice, sides, radius)
			var a1 := _rope_point(a, slice + 1, sides, radius)
			var b0 := _rope_point(b, slice, sides, radius)
			var b1 := _rope_point(b, slice + 1, sides, radius)
			_rope_vertex(mesh, a0, u0, float(a["v"]))
			_rope_vertex(mesh, b0, u0, float(b["v"]))
			_rope_vertex(mesh, b1, u1, float(b["v"]))
			_rope_vertex(mesh, a0, u0, float(a["v"]))
			_rope_vertex(mesh, b1, u1, float(b["v"]))
			_rope_vertex(mesh, a1, u1, float(a["v"]))
	mesh.surface_end()
	rope.visible = true


func _rope_point(ring: Dictionary, slice: int, sides: int, radius: float) -> Vector3:
	var angle := TAU * float(slice) / float(sides)
	var at: Vector3 = ring["at"]
	var side: Vector3 = ring["side"]
	var up: Vector3 = ring["up"]
	return at + (side * cos(angle) + up * sin(angle)) * radius


func _rope_vertex(mesh: ImmediateMesh, point: Vector3, u: float, v: float) -> void:
	mesh.surface_set_uv(Vector2(u, v))
	mesh.surface_add_vertex(point)


func _throw_impact() -> float:
	# __hitBoss normalizes the velocity and keeps the crane-forward part.
	var flat := Vector3(_magnet_vel.x, 0.0, _magnet_vel.z)
	var face := Vector3(_drop_aim.x, 0.0, _drop_aim.z)
	if flat.length_squared() < 0.04 or face.length_squared() < 0.0001:
		return 0.0
	return clampf(flat.normalized().dot(face.normalized()), 0.0, 1.0)


func _tick_cfo_intro(delta: float) -> void:
	if _intro_done or _root == null:
		return
	var t := _clock
	if _door_base.is_empty() and t > 0.05:
		_bind_doors()
	var cfo := _root.get_node_or_null("CFO") as Node3D
	if cfo != null:
		if t < 8.0:
			cfo.position = Vector3(120.0, -195.0, 0.0)
		elif t < 11.0:
			cfo.position = Vector3(120.0, lerpf(-195.0, -230.0, (t - 8.0) / 3.0), 0.0)
		else:
			cfo.position = Vector3(120.0, -230.0, 0.0)
	if t < 17.5:
		_rise(_door2, _span(t, 3.0, 6.0, 0.0, 30.0))
	else:
		_rise(_door2, _span(t, 17.5, 20.5, 30.0, 0.0))
	if t < 8.0:
		_rise(_door1, _span(t, 6.0, 8.0, 0.0, 30.0))
	else:
		_rise(_door1, _span(t, 8.0, 11.0, 30.0, 0.0))
	var paths: Array = [
		[Vector3(111.0, -287.0, 0.0), Vector3(101.0, -323.0, 0.0), Vector3(111.0, -287.0, 0.0), Vector3(104.0, -316.0, 0.0)],
		[Vector3(119.0, -315.0, 0.0), Vector3(121.0, -280.0, 0.0)],
		[Vector3(102.0, -320.0, 0.0), Vector3(127.0, -337.0, 0.0)],
	]
	for index in paths.size():
		var goon := _root.get_node_or_null("IntroGoon%d" % index) as Node3D
		if goon != null:
			goon.position = _patrol(paths[index], t)
			_plant_goon_shadow(goon)
	var spot := Vector3(94.0, -220.0, 0.0)
	var moving := false
	if t < 3.0:
		spot = Vector3(94.0, -220.0, 0.0)
	elif t < 6.0:
		spot = Vector3(94.0, -220.0, 0.0).lerp(Vector3(120.0, -255.0, 0.0), (t - 3.0) / 3.0)
		moving = true
	elif t < 17.5:
		spot = Vector3(120.0, -255.0, 0.0)
	elif t < 19.0:
		spot = Vector3(120.0, -255.0, 0.0).lerp(Vector3(109.0, -294.0, 0.0), (t - 17.5) / 1.5)
		moving = true
	elif t < 20.5:
		spot = Vector3(109.0, -294.0, 0.0).lerp(Vector3(93.935, -341.065, 2.0), (t - 19.0) / 1.5)
		moving = true
	else:
		spot = Vector3(93.935, -341.065, 2.0)
	_wear_mata()
	if t >= 15.2 and _suited:
		_drop_mata_suit()
	if t >= 19.0 and not _eyes_fixed and _mata != null and _mata.has_method("set_expression"):
		_eyes_fixed = true
		_mata.call("set_expression", "normal")
	_aim_track([
		[0.0, Vector3(82.0, -219.0, 5.0), 267.0, 0.0],
		[3.0, Vector3(82.0, -219.0, 5.0), 267.0, 0.0],
		[7.0, Vector3(108.0, -244.0, 4.0), 211.5, 0.0, true],
		[7.05, Vector3(61.1, -228.8, 10.2), -90.0, 0.0],
		[11.0, Vector3(61.1, -228.8, 10.2), -90.0, 0.0],
		[12.5, Vector3(93.3, -230.0, 0.7), -92.9, 39.7, true],
		[22.0, Vector3(93.3, -230.0, 0.7), -92.9, 39.7],
	], t)
	_lock_toon()
	if t >= 8.0:
		_tick_cfo_anim(delta)
	if _mata != null:
		var world := _panda_world(spot)
		if _mata.global_position.distance_squared_to(world) > 0.04:
			_mata.look_at(world, Vector3.UP)
		_mata.global_position = world
		if _mata.has_method("set_locomotion"):
			_mata.call("set_locomotion", 8.0 if moving else 0.0, false, false, delta)
		if _mata_suit != null and is_instance_valid(_mata_suit):
			_mata_suit.global_position = _mata.global_position
			_mata_suit.global_rotation = _mata.global_rotation
			_mata_suit.set_meta("walking", moving)
	_cue(0.4, "Hey, you made it!  Follow me to the main vault before the C.F.O. finds us!", false)
	_cue(6.0, "Blast it!  We're too late!", false)
	_cue(11.0, "Ah-HAH!", true)
	_cue(12.6, "I thought I smelled something a little toony in here!  Imposters!", true)
	_cue(16.6, "Keep him busy!  I'm going to set a trap!", false)
	_cue(20.6, "Get them!!!", true)
	if t >= 22.5:
		_intro_done = true
		_mode = ""
		_boss.call("cfo_intro_done")


func finish_cfo_intro() -> void:
	_intro_done = true
	if _mode == "cfo_intro":
		_mode = ""
	_drop_mata_suit()
	_release_camera()
	_free_toon()
	_reset_doors()
	if _mata != null:
		_mata.visible = false
	if _root == null:
		return
	for index in 3:
		var goon := _root.get_node_or_null("IntroGoon%d" % index) as Node3D
		if goon != null:
			goon.visible = false


func start_flee() -> void:
	if _root == null or _boss == null:
		return
	_mode = "cfo_flee"
	_flee_t = 0.0
	_flee_line = 1
	_crane = -1
	_held = -1
	_share_crane(true)
	_free_toon()
	for child in _root.get_children():
		if String(child.name) == "CFO" or not child is Node3D:
			continue
		(child as Node3D).visible = false
	_bind_doors()
	_spawn_train()
	_lock_toon()
	play_music("battle3")
	var cfo := _root.get_node_or_null("CFO") as Node3D
	if cfo != null:
		_face_cfo(cfo, 180.0)
	_boss.call("cfo_flee_line", "That's it.  I've had enough of these pesky Toons!")


func _tick_cfo_flee(delta: float) -> void:
	if _root == null or _boss == null:
		return
	_flee_t += delta
	var t := _flee_t
	var cfo := _root.get_node_or_null("CFO") as Node3D
	if cfo != null and t < 9.5:
		if t < 5.5:
			cfo.position = Vector3(120.0, -315.0, 0.0)
		else:
			cfo.position = Vector3(120.0, lerpf(-315.0, -250.0, clampf((t - 5.5) / 2.6, 0.0, 1.0)), 0.0)
	_aim_track([
		[0.0, Vector3(105.0, -280.0, 20.0), -158.0, -3.0],
		[5.5, Vector3(100.0, -315.0, 16.0), -20.0, 0.0],
		[16.0, Vector3(100.0, -315.0, 16.0), -20.0, 0.0],
	], t)
	_lock_toon()
	if t < 3.0:
		_pose_cfo("hit", false)
	elif t < 5.5:
		_pose_cfo("getup", false)
	else:
		_pose_cfo("idle", true)
	_advance_cfo_pose(delta)
	if t >= 5.5:
		_rise(_door3, _span(t, 5.5, 8.0, 0.0, 25.0))
	if t >= 5.5 and _flee_line < 2:
		_flee_line = 2
		_boss.call("cfo_flee_line", "I've got a train to catch!")
		_sfx("res://assets/cog_hq/audio/CBHQ_TRAIN_pass.ogg")
	if t >= 9.4:
		_move_train(t - 9.4)
	if t >= 9.5 and _flee_line < 3:
		_flee_line = 3
		if cfo != null:
			cfo.position = Vector3(0.0, -250.0, 0.0)
			cfo.visible = false
		_sfx("res://assets/cogs/bosses/audio/ENC_cogfall_apart.ogg")
	if t >= 15.7 and _flee_line < 4:
		_flee_line = 4
		_boss.call("cfo_flee_done")


func _summon_mata() -> void:
	if _boss == null:
		return
	var host := _boss.get_parent()
	if host == null:
		return
	var style := ToonStyle.new()
	style.gender = "f"
	style.head = "pls"
	style.torso = "md"
	style.legs = "m"
	style.first_name = "Mata"
	style.last_name = "Hairy"
	_mata = ToonActor.new()
	_mata.name = "MataHairy"
	host.add_child(_mata)
	_mata.set("follows_ground", false)
	if _mata.has_method("show_style"):
		_mata.call("show_style", style)
	var tags := host.find_child("Nametags", true, false)
	if tags != null and tags.has_method("add"):
		tags.call("add", _mata, "Mata Hairy", "npc")


func _bind_doors() -> void:
	var geom := _geometry()
	if geom == null or _root == null:
		return
	var sliding: Array[Node3D] = []
	var ones: Array[Node3D] = []
	_collect_exact(geom, "SlidingDoor", sliding)
	_collect_exact(geom, "SlidingDoor1", ones)
	if not ones.is_empty():
		_door1 = ones[0]
	var battle := _root.to_global(Vector3(120.0, -315.0, 0.0))
	sliding.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(battle) < b.global_position.distance_squared_to(battle)
	)
	if not sliding.is_empty():
		_door3 = sliding[0]
		_door2 = sliding[sliding.size() - 1]
	for door in [_door1, _door2, _door3]:
		if door != null and is_instance_valid(door) and not _door_base.has(door):
			_door_base[door] = door.position.z


func _collect_exact(node: Node, wanted: String, found: Array[Node3D]) -> void:
	if node is Node3D and String(node.name) == wanted:
		found.append(node)
	for child in node.get_children():
		_collect_exact(child, wanted, found)


func _reset_doors() -> void:
	for door in _door_base.keys():
		var node := door as Node3D
		if node != null and is_instance_valid(node):
			node.position.z = float(_door_base[door])
	_door_base.clear()
	_door1 = null
	_door2 = null
	_door3 = null


func _rise(door: Node3D, amount: float) -> void:
	if door == null or not is_instance_valid(door) or not _door_base.has(door):
		return
	door.position.z = float(_door_base[door]) + amount


func _span(t: float, a: float, b: float, start: float, end_value: float) -> float:
	if t <= a:
		return start
	if t >= b:
		return end_value
	return lerpf(start, end_value, (t - a) / (b - a))


func _patrol(stops: Array, t: float) -> Vector3:
	if stops.is_empty():
		return Vector3.ZERO
	var span := 9.0
	var along := fmod(t, span * float(stops.size()))
	var step := int(along / span) % stops.size()
	var frac := fmod(along, span) / span
	var nxt := (step + 1) % stops.size()
	return (stops[step] as Vector3).lerp(stops[nxt] as Vector3, frac)


func _panda_world(panda: Vector3) -> Vector3:
	var space: Node3D = _root
	if space == null and _boss != null:
		var host := _boss.get_parent()
		space = host.get_node_or_null("Geometry") as Node3D if host != null else null
	if space == null:
		return panda
	return space.to_global(panda)


func _cue(at: float, text: String, cog: bool) -> void:
	if _clock < at or _intro_said.has(at):
		return
	_intro_said[at] = true
	if _boss != null:
		_boss.call("cfo_intro_line", text, cog)


func _spawn_train() -> void:
	if _boss == null:
		return
	var host := _boss.get_parent()
	if host == null:
		return
	var paths := [
		"res://assets/cog_hq/trains/locomotive.glb",
		"res://assets/cog_hq/trains/tank_car.glb",
		"res://assets/cog_hq/trains/box_car.glb",
	]
	for index in 15:
		var path := paths[0]
		if index > 0:
			path = paths[1] if index % 2 == 1 else paths[2]
		_train_car(host, path, "FleeCar%d" % index)


func _train_car(host: Node, path: String, node_name: String) -> void:
	if host.get_node_or_null(node_name) != null or not ResourceLoader.exists(path):
		return
	var packed = load(path)
	if not packed is PackedScene:
		return
	var model := (packed as PackedScene).instantiate() as Node3D
	if model == null:
		return
	model.name = node_name
	host.add_child(model)
	model.visible = false


func _move_train(age: float) -> void:
	if _boss == null or _root == null:
		return
	var host := _boss.get_parent()
	if host == null:
		return
	for index in 15:
		var car := host.get_node_or_null("FleeCar%d" % index) as Node3D
		if car == null:
			continue
		var x := 150.0 - age * 300.0 + float(index) * 80.0
		car.visible = x < 180.0
		if car.visible:
			car.global_position = _root.to_global(Vector3(x, -242.0, 0.0))


func _clear_train() -> void:
	if _boss == null:
		return
	var host := _boss.get_parent()
	if host == null:
		return
	for child in host.get_children():
		if String(child.name).begins_with("FleeCar") or String(child.name).begins_with("FleeLoco") or String(child.name).begins_with("FleeTank") or String(child.name).begins_with("FleeBox"):
			child.queue_free()


func _tick_crane_audio(delta: float, swinging: bool, limited: bool) -> void:
	if _carry_left > 0.0:
		_carry_left = maxf(_carry_left - delta, 0.0)
	if _clank_left > 0.0:
		_clank_left = maxf(_clank_left - delta, 0.0)
		if _clank_left <= 0.0 and _clank_path != "":
			_sfx(_clank_path)
			_clank_path = ""
	if _crane < 0:
		_stop_magnet_hum()
		_move_sound("")
		_clear_bolts()
		return
	if swinging and limited:
		_move_sound("res://assets/audio/sfx/MG_cannon_adjust.ogg")
	elif swinging:
		_move_sound("res://assets/cog_hq/audio/CHQ_FACT_elevator_up_down.ogg")
	else:
		_move_sound("")
	# The hum plays while the magnet is live and empty. A grab turns it off.
	if _held < 0:
		if _magnet_loop == null and _magnet_hum < 0.0:
			_magnet_on = _play_held("res://assets/cog_hq/audio/CBHQ_CFO_magnet_on.ogg", false, 1.0)
			_magnet_hum = 0.5
		elif _magnet_hum > 0.0:
			_magnet_hum = maxf(_magnet_hum - delta, 0.0)
			if _magnet_hum <= 0.0:
				_magnet_hum = -1.0
				_free_player(_magnet_on)
				_magnet_on = null
				_magnet_loop = _play_held("res://assets/cog_hq/audio/CBHQ_CFO_magnet_loop.ogg", true, 1.0)
	else:
		_stop_magnet_hum()
	_tick_bolts()


func _begin_carry(from: Vector3, is_safe: bool) -> void:
	# CashbotBossToMagnetTime. The whoosh plays on the way up, then the clank.
	_carry_from = from
	_carry_left = 0.2
	_clank_left = 0.18 if is_safe else 0.2
	_clank_path = "res://assets/audio/battle/AA_drop_safe.ogg" if is_safe else "res://assets/audio/sfx/AA_drop_anvil_miss.ogg"
	_sfx("res://assets/audio/battle/TL_rake_throw_only.ogg")
	_stop_magnet_hum()


func _finish_clank() -> void:
	if _clank_path != "":
		_sfx(_clank_path)
	_clank_left = 0.0
	_clank_path = ""
	_carry_left = 0.0


func _held_point() -> Vector3:
	var hang := Vector3(0.0, -8.2, 0.0)
	if _held >= 100 and _held - 100 < _goons.size():
		var goon: Dictionary = _goons[_held - 100]
		var scale := float(goon.get("scale", 1.0))
		var phase := String(goon.get("phase", ""))
		var drop := -3.6 if phase == "walk" or phase == "emerge" else -2.2
		hang = Vector3(0.0, drop * scale, 0.0)
	var dest := _magnet + hang
	if _carry_left <= 0.0:
		return dest
	var along := clampf(1.0 - _carry_left / 0.2, 0.0, 1.0)
	return _carry_from.lerp(dest, along)


func _stop_crane_audio() -> void:
	_stop_magnet_hum()
	_move_sound("")
	_clear_bolts()


func _widen_crane() -> void:
	# BossBattleCameraFov. Battle three opens wider than the playground view.
	var camera := _camera()
	if camera == null:
		return
	if _saved_fov < 0.0:
		_saved_fov = camera.fov
	camera.fov = 72.0


func _restore_fov() -> void:
	var camera := _camera()
	if camera != null and is_instance_valid(camera) and _saved_fov >= 0.0:
		camera.fov = _saved_fov
	_saved_fov = -1.0


func _tick_bolts() -> void:
	if _crane < 0 or _held >= 0:
		_clear_bolts()
		return
	var magnet := _root.get_node_or_null("Magnet") as Node3D if _root != null else null
	if magnet == null:
		return
	if _bolts.is_empty():
		for index in 4:
			var t := float(index) / 3.0 - 0.5
			var bolt := _lightning_bolt()
			magnet.add_child(bolt)
			var side := t - 0.7 if t < 0.0 else t + 0.7
			bolt.position = Vector3(side, 0.0, randf_range(-5.5, -5.0))
			bolt.rotation = Vector3(deg_to_rad(randf_range(-20.0, 20.0)), 0.0, deg_to_rad(-20.0 * t))
			bolt.scale = Vector3.ONE * randf_range(0.5, 1.0)
			_bolts.append(bolt)
	for bolt in _bolts:
		if is_instance_valid(bolt):
			bolt.visible = randf() >= 0.5


func _lightning_bolt() -> Node3D:
	var path := "res://assets/cog_hq/cfo_lightning.glb"
	if ResourceLoader.exists(path):
		var packed = load(path)
		if packed is PackedScene:
			var model := (packed as PackedScene).instantiate() as Node3D
			if model != null:
				_billboard_bolt(model)
				return model
	var mesh := MeshInstance3D.new()
	var card := BoxMesh.new()
	card.size = Vector3(0.4, 0.15, 4.0)
	mesh.mesh = card
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.75, 0.9, 1.0)
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mesh.material_override = paint
	return mesh


func _billboard_bolt(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
			var mat := mesh.get_active_material(0)
			if mat is StandardMaterial3D:
				var paint := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				paint.cull_mode = BaseMaterial3D.CULL_DISABLED
				paint.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
				mesh.set_surface_override_material(0, paint)
	for child in node.get_children():
		_billboard_bolt(child)


func _clear_bolts() -> void:
	for bolt in _bolts:
		if is_instance_valid(bolt):
			bolt.queue_free()
	_bolts.clear()


func _bumped_goon(at: Vector3, scale: float, reach: float, body: Node3D) -> bool:
	if body == null:
		return false
	var gap := body.global_position - at
	if gap.length() > reach:
		return false
	gap.y = 0.0
	# The stun sphere sits on the head. Walking into the body is what hits it.
	return gap.length() <= 1.2 + scale


func _stop_magnet_hum() -> void:
	_magnet_hum = -1.0
	_free_player(_magnet_on)
	_magnet_on = null
	_free_player(_magnet_loop)
	_magnet_loop = null


func _move_sound(path: String) -> void:
	if path == _crane_move_path:
		return
	_free_player(_crane_move)
	_crane_move = null
	_crane_move_path = path
	if path == "":
		return
	_crane_move = _play_held(path, true, 0.5)


func _play_held(path: String, looped: bool, volume: float) -> AudioStreamPlayer:
	if not FileAccess.file_exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		return null
	stream = stream.duplicate() as AudioStream
	if looped and stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(volume)
	add_child(player)
	player.play()
	return player


func _free_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	player.stop()
	player.queue_free()


func _paint_reject(gem: Node, reject: float) -> void:
	var shade := 1.0
	if reject > 0.2:
		var along := (1.0 - reject) / 0.8
		shade = 1.0 - along * along
	elif reject > 0.0:
		var along := (0.2 - reject) / 0.2
		shade = 1.0 - (1.0 - along) * (1.0 - along)
	_overlay_shade(gem, shade)


func _overlay_shade(node: Node, shade: float) -> void:
	if node is GeometryInstance3D:
		var geo := node as GeometryInstance3D
		if shade >= 0.98:
			geo.material_overlay = null
		else:
			var mat := geo.material_overlay as StandardMaterial3D
			if mat == null:
				mat = StandardMaterial3D.new()
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color = Color(0.0, 0.0, 0.0, 1.0)
				geo.material_overlay = mat
			mat.albedo_color.a = 1.0 - shade
	for child in node.get_children():
		_overlay_shade(child, shade)


func _sfx(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _tick_cfo_lesson(delta: float) -> void:
	if _lesson_done or _root == null or _boss == null:
		return
	var t := _clock
	# BossCogTurnSpeed is 20 and BossCogRollSpeed is 7.5. He turns to 180,
	# rolls the 85 units into the crane vault, then turns to 135.
	var turn_a := 90.0 / 20.0
	var roll := 85.0 / 7.5
	var arrive := turn_a + roll
	var settled := arrive + 45.0 / 20.0
	var watch := settled
	var away := settled + 2.0
	var instruct := settled + 5.5
	var recover := instruct + 16.0
	var eek := recover + 2.0
	var run_at := eek + 1.8
	var done := run_at + 3.0
	if _door_base.is_empty() and t > 0.05:
		_bind_doors()
	var cfo := _root.get_node_or_null("CFO") as Node3D
	if cfo != null:
		var heading := 135.0
		if t < turn_a:
			heading = lerpf(90.0, 180.0, t / turn_a)
			cfo.position = Vector3(120.0, -230.0, 0.0)
		elif t < arrive:
			heading = 180.0
			cfo.position = Vector3(120.0, lerpf(-230.0, -315.0, (t - turn_a) / roll), 0.0)
		else:
			heading = lerpf(180.0, 135.0, clampf((t - arrive) / (settled - arrive), 0.0, 1.0))
			cfo.position = Vector3(120.0, -315.0, 0.0)
		_face_cfo(cfo, heading)
		_boss_pos = cfo.global_position
		if t < settled:
			_roll_camera(cfo)
	if t < run_at:
		_rise(_door2, _span(t, 0.0, turn_a, 0.0, 30.0))
		_rise(_door3, _span(t, 0.0, turn_a, 0.0, 30.0))
	else:
		_rise(_door3, _span(t, run_at, done, 30.0, 0.0))
	var on_crane := t < eek
	var jumping := t >= eek and t < run_at
	var moving := t >= run_at
	if _mata != null:
		if on_crane:
			var pad := _root.get_node_or_null("Crane0") as Node3D
			if pad != null:
				_mata.global_position = _controls_at(pad)
			var focus := _panda_world(Vector3(120.0, -315.0, 0.0))
			if _mata.global_position.distance_squared_to(focus) > 0.04:
				_mata.look_at(focus, Vector3.UP)
			if _mata.has_method("play_gesture"):
				_mata.call("play_gesture", "leverNeutral", 1.0, true)
		else:
			if _mata.has_method("clear_gesture"):
				_mata.call("clear_gesture")
			var spot := Vector3(110.8, -292.7, 0.0)
			if moving:
				spot = spot.lerp(Vector3(136.0, -212.9, 0.0), clampf((t - run_at) / 3.0, 0.0, 1.0))
			var world := _panda_world(spot)
			if _mata.global_position.distance_squared_to(world) > 0.04:
				_mata.look_at(world, Vector3.UP)
			_mata.global_position = world
		if _mata.has_method("set_locomotion"):
			_mata.call("set_locomotion", 12.0 if moving else 0.0, false, jumping, delta)
	var goon := _root.get_node_or_null("LessonGoon") as Node3D
	if goon != null:
		if t < run_at:
			goon.position = Vector3(104.0, -316.0, 0.0)
			_pose_lesson_goon(goon, "collapse" if t < recover else "recovery", delta)
		else:
			goon.position = Vector3(104.8, -309.5, 0.0).lerp(Vector3(125.2, -243.5, 0.0), clampf((t - run_at) / 3.0, 0.0, 1.0))
			_pose_lesson_goon(goon, "walk", delta)
	if t >= settled:
		_aim_track([
			[watch, Vector3(105.0, -326.0, 5.0), 136.3, 0.0],
			[away, Vector3(105.0, -326.0, 20.0), -45.3, 11.0],
			[away + 2.0, Vector3(105.0, -326.0, 20.0), -45.3, 11.0],
			[instruct, Vector3(105.0, -326.0, 5.0), 136.3, 0.0, true],
			[recover, Vector3(102.0, -323.6, 0.9), -10.6, 14.0],
			[eek, Vector3(95.4, -332.6, 4.2), 167.1, -13.2],
			[run_at, Vector3(109.1, -300.7, 13.9), -15.6, -13.6],
			[done, Vector3(109.1, -300.7, 13.9), -15.6, -13.6],
		], t)
	_lock_toon()
	_pose_cfo("idle", true)
	_advance_cfo_pose(delta)
	_lesson_line(watch, "Watch this!", false)
	_lesson_line(away, "Hey!  Get away from that!", true)
	_lesson_line(instruct, "Control a magnet by stepping up to a podium.", false)
	_lesson_line(instruct + 4.0, "Use the arrow keys to move the crane, and press the Ctrl key to grab an object.", false)
	_lesson_line(instruct + 8.0, "Grab a safe with a magnet and knock the C.F.O.'s safe-ty helmet off.", false)
	_lesson_line(instruct + 12.0, "Once his helmet is gone, grab a disabled goon and hit him in the head!", false)
	_lesson_line(eek, "Eek!  Gotta run!", false)
	if t >= recover and not _lesson_said.has(-1.0):
		_lesson_said[-1.0] = true
		_sfx("res://assets/cog_hq/audio/CHQ_GOON_rattle_shake.ogg")
	if t >= done:
		_lesson_done = true
		_boss.call("finish_cfo_lesson")


func start_cfo_epilogue() -> void:
	_mode = "cfo_epilogue"
	play_music("epilogue")
	_drop_mata_suit()
	if _mata == null or not is_instance_valid(_mata):
		_summon_mata()
	if _mata != null:
		_mata.visible = true
		var spot := _panda_world(Vector3(120.0, -315.0, 0.0))
		var ahead := _panda_world(Vector3(120.0, -319.0, 0.0))
		_mata.global_position = spot
		if spot.distance_squared_to(ahead) > 0.04:
			_mata.look_at(ahead, Vector3.UP)
	_lock_toon()
	_aim_at(Vector3(129.0, -327.0, 6.0), Vector3(120.0, -315.0, 3.0))


func epilogue_dance() -> void:
	if _mata != null and is_instance_valid(_mata) and _mata.has_method("play_emote"):
		_mata.call("play_emote", 15)
	_sfx("res://assets/audio/sfx/ENC_Win.mp3")


func epilogue_wave() -> void:
	if _mata != null and is_instance_valid(_mata) and _mata.has_method("play_emote"):
		_mata.call("play_emote", 0)


func note_cfo_hit() -> void:
	# A hit while he is still up plays Fb_firstHit and knocks him down.
	_down_hit = not _cfo_raised
	_cfo_raised = false
	_hit_left = 1.4
	_flash_left = 0.4
	_anim_clip = ""


func note_cfo_throw() -> void:
	_cfo_raised = true
	_down_hit = false
	_throw_left = 2.2
	_anim_clip = ""


func _tick_cfo_anim(delta: float) -> void:
	var dizzy := false
	if _boss != null and _boss.has_method("world_state"):
		dizzy = float(_boss.call("world_state").get("dizzy", 0.0)) > 0.0
	var which := "idle"
	var loop := true
	if _hit_left > 0.0:
		_hit_left = maxf(_hit_left - delta, 0.0)
		which = "hit"
		loop = false
	elif _throw_left > 0.0:
		_throw_left = maxf(_throw_left - delta, 0.0)
		which = "throw"
		loop = false
	elif dizzy:
		which = "dizzy"
	_pose_cfo(which, loop)
	_advance_cfo_pose(delta)
	_show_stars(dizzy)
	_tick_birds(dizzy)
	_tick_flash(delta)


func _pose_cfo(which: String, loop: bool) -> void:
	var clip := "Ff_neutral"
	if which == "hit":
		clip = "Fb_downHit" if _down_hit else "Fb_firstHit"
	elif which == "dizzy":
		clip = "Fb_downNeutral"
	elif which == "throw":
		clip = "Fb_UpThrow"
	elif which == "getup":
		clip = "Fb_down2Up"
	if clip == _anim_clip:
		_anim_loop = loop
		return
	_anim_clip = clip
	_anim_time = 0.0
	_anim_loop = loop
	if clip == "Fb_firstHit" or clip == "Fb_downHit":
		# getAnim('hit') plays the reel alone. The collapse is the down transition.
		_sfx("res://assets/cogs/bosses/audio/CHQ_VP_reeling_backwards.ogg")
	elif clip == "Fb_down2Up":
		_sfx("res://assets/cogs/bosses/audio/CHQ_VP_raise_up.ogg")
	elif clip == "Fb_UpThrow":
		_sfx("res://assets/cogs/bosses/audio/CHQ_VP_frisbee_gears.ogg")


func _advance_cfo_pose(delta: float) -> void:
	if _root == null or _anim_clip == "":
		return
	var cfo := _root.get_node_or_null("CFO") as Node3D
	if cfo == null:
		return
	_set_cfo_head(_head_is_flipped())
	var path := "res://assets/cogs/bosses/cfo_anims/%s.walk" % _anim_clip
	if not FileAccess.file_exists(path):
		return
	if not _anim_banks.has(_anim_clip):
		if _poser == null:
			_poser = StreetCog.new()
		if _anim_rates.is_empty():
			_load_cfo_rates()
		var loaded: Variant = _poser.call("_read_bank", path, cfo)
		if loaded is Dictionary:
			_anim_banks[_anim_clip] = loaded
	var bank := _anim_banks.get(_anim_clip, {}) as Dictionary
	var frames := int(bank.get("frames", 0))
	if frames <= 1 or _poser == null:
		return
	var fps := float(_anim_rates.get(_anim_clip, 24.0))
	_anim_time += delta
	_poser.call("_pose_elapsed", bank, _anim_time, fps, _anim_loop)
	_set_cfo_head(_head_is_flipped())


func _load_cfo_rates() -> void:
	var path := "res://assets/cogs/bosses/cfo_anims/clips.json"
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		for key in parsed:
			var row: Variant = parsed[key]
			if row is Dictionary:
				_anim_rates[str(key)] = float(row.get("fps", 24.0))


func _show_stars(dizzy: bool) -> void:
	var cfo := _root.get_node_or_null("CFO") as Node3D if _root != null else null
	if cfo == null:
		return
	if _stars == null or not is_instance_valid(_stars):
		_stars = Node3D.new()
		_stars.name = "DizzyStars"
		var head := _cfo_head(cfo)
		if head == null:
			cfo.add_child(_stars)
			_stars.position = Vector3(0.0, 0.0, 20.0)
		else:
			head.add_child(_stars)
			# BossCog stars sit at (7, 0, 0) on the head, so they flip with it.
			_stars.position = Vector3(7.0, 0.0, 0.0)
		# BossCog stars: (7, 0, 0), roll -90, scale 3, looping the stun clip.
		_stars.transform.basis = Basis(Vector3(0.0, 1.0, 0.0), deg_to_rad(-90.0)).scaled(Vector3.ONE * 3.0)
		var packed := load("res://assets/cogs/bosses/stun.glb") as PackedScene
		if packed != null:
			_stars.add_child(packed.instantiate())
	_stars.visible = dizzy
	if dizzy:
		_pose_stun(_stars)


func _tick_flash(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left = maxf(_flash_left - delta, 0.0)
	var cfo := _root.get_node_or_null("CFO") as Node3D if _root != null else null
	if cfo == null:
		return
	if _flash_paint == null:
		_flash_paint = StandardMaterial3D.new()
		_flash_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_paint.albedo_color = Color(1, 0, 0, 0.55 if _flash_left > 0.2 else 0.0)
	for node in cfo.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = _flash_paint if _flash_left > 0.0 else null


func _wear_mata() -> void:
	if _suited or _mata == null or not is_instance_valid(_mata):
		return
	var head := _mata.find_child("head_look", true, false) as Node3D
	var neck := head.get_parent() as Node3D if head != null else null
	if head == null or neck == null:
		return
	var host := _mata.get_parent()
	if host == null:
		return
	var suit := StreetCog.new()
	suit.name = "MataSuit"
	host.add_child(suit)
	suit.present({
		"code": "sc",
		"name": "Short Change",
		"dept": "m",
		"body": "c",
		"height": 4.0,
		"level": 1,
		"hp": 1,
		"max": 1,
	}, {})
	var joint := suit.find_child("joint_head", true, false) as Node3D
	if joint == null:
		suit.queue_free()
		return
	for piece in joint.get_children():
		if piece is Node3D:
			(piece as Node3D).visible = false
	head.reparent(joint)
	var scale := _mata.transform.basis.get_scale().x
	if scale < 0.01:
		scale = 1.0
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	head.transform = Transform3D(upright.scaled(Vector3.ONE * scale), Vector3(0, 0.2, 0))
	for child in _mata.get_children():
		if child.name == "1000" or child.name == "500" or child.name == "250" or child.name == "0":
			child.visible = false
	suit.set_meta("toon_head", head)
	suit.set_meta("toon_neck", neck)
	if suit.has_method("_release_nametag"):
		suit.call("_release_nametag")
	_mata_suit = suit
	_suited = true
	var tags := host.find_child("Nametags", true, false)
	if tags != null and tags.has_method("dress_suit"):
		tags.call("dress_suit", _mata, "Mata Hairy\nShort Change\nLevel 1", 5.3)


func _drop_mata_suit() -> void:
	if _mata_suit == null or not is_instance_valid(_mata_suit):
		_mata_suit = null
		_suited = false
		return
	var head := _mata_suit.get_meta("toon_head") as Node3D
	var neck := _mata_suit.get_meta("toon_neck") as Node3D
	if head != null and neck != null and is_instance_valid(head) and is_instance_valid(neck):
		head.reparent(neck)
		head.transform = Transform3D.IDENTITY
	if _mata != null and is_instance_valid(_mata):
		for child in _mata.get_children():
			if child.name == "1000" or child.name == "500" or child.name == "250" or child.name == "0":
				child.visible = true
		if _mata.has_method("set_expression"):
			_mata.call("set_expression", "sad")
		if _mata.has_method("play_emote"):
			_mata.call("play_emote", 14)
		_puff(_mata.global_position)
		var host := _mata.get_parent()
		var tags := host.find_child("Nametags", true, false) if host != null else null
		if tags != null and tags.has_method("undress_suit"):
			tags.call("undress_suit", _mata)
	if _mata_suit.has_method("_release_nametag"):
		_mata_suit.call("_release_nametag")
	_mata_suit.queue_free()
	_mata_suit = null
	_suited = false


func _puff(at: Vector3) -> void:
	var host := _boss.get_parent() if _boss != null else self
	var bits := CPUParticles3D.new()
	bits.amount = 24
	bits.lifetime = 0.7
	bits.one_shot = true
	bits.explosiveness = 0.9
	bits.direction = Vector3(0, 1, 0)
	bits.spread = 50.0
	bits.initial_velocity_min = 1.0
	bits.initial_velocity_max = 2.5
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	bits.mesh = mesh
	bits.emitting = false
	host.add_child(bits)
	bits.global_position = at
	bits.emitting = true
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(bits.queue_free)


func _grab_camera() -> void:
	if _movie_cam != null and is_instance_valid(_movie_cam):
		_movie_cam.current = true
		return
	if _boss == null:
		return
	var host := _boss.get_parent()
	if host == null:
		return
	_cam_was = _camera()
	_movie_cam = Camera3D.new()
	_movie_cam.name = "CfoMovieCam"
	host.add_child(_movie_cam)
	_movie_cam.current = true


func _release_camera() -> void:
	if _movie_cam != null and is_instance_valid(_movie_cam):
		_movie_cam.current = false
		_movie_cam.queue_free()
	_movie_cam = null
	if _cam_was != null and is_instance_valid(_cam_was):
		_cam_was.current = true
	_cam_was = null


func _aim_movie(at: Vector3, heading: float, pitch: float) -> void:
	_grab_camera()
	if _movie_cam == null:
		return
	var h := deg_to_rad(heading)
	var p := deg_to_rad(pitch)
	var look := at + Vector3(-sin(h) * cos(p), cos(h) * cos(p), sin(p))
	_movie_cam.global_position = _panda_world(at)
	var focus := _panda_world(look)
	if _movie_cam.global_position.distance_squared_to(focus) > 0.04:
		_movie_cam.look_at(focus, Vector3.UP)


func _aim_at(at: Vector3, focus_at: Vector3) -> void:
	_grab_camera()
	if _movie_cam == null:
		return
	_movie_cam.global_position = _panda_world(at)
	var focus := _panda_world(focus_at)
	if _movie_cam.global_position.distance_squared_to(focus) > 0.04:
		_movie_cam.look_at(focus, Vector3.UP)


func _aim_track(shots: Array, t: float) -> void:
	if shots.is_empty():
		return
	var index := 0
	while index < shots.size() - 1 and t >= float((shots[index + 1] as Array)[0]):
		index += 1
	var a: Array = shots[index]
	var from := a[1] as Vector3
	var heading := float(a[2])
	var pitch := float(a[3])
	if index >= shots.size() - 1:
		_aim_movie(from, heading, pitch)
		return
	var b: Array = shots[index + 1]
	var span := float(b[0]) - float(a[0])
	if b.size() <= 4 or not bool(b[4]) or span <= 0.05:
		_aim_movie(from, heading, pitch)
		return
	var along := clampf((t - float(a[0])) / span, 0.0, 1.0)
	var to := b[1] as Vector3
	_aim_movie(from.lerp(to, along), lerpf(heading, float(b[2]), along), lerpf(pitch, float(b[3]), along))


func play_music(which: String) -> void:
	var file := ""
	match which:
		"battle", "battle1":
			file = "encntr_general_bg.ogg"
		"battle3":
			file = "encntr_suit_winning_indoor.ogg"
		"epilogue":
			file = "encntr_hall_of_fame.ogg"
	if file == "":
		return
	var path := "res://assets/cogs/bosses/audio/" + file
	if not FileAccess.file_exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	if _music == null or not is_instance_valid(_music):
		_music = AudioStreamPlayer.new()
		_music.name = "CfoMusic"
		add_child(_music)
	if _music_key == which and _music.playing:
		return
	var copy := stream.duplicate() as AudioStream
	if copy != null:
		stream = copy
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	_music_key = which
	_music.stream = stream
	_music.volume_db = -4.0
	_music.play()


func start_cfo_victory() -> void:
	_mode = "cfo_victory"
	_victory_done = false
	_clock = 0.0
	_lock_toon()
	_grab_camera()
	var actor := _toon_actor()
	if actor != null and actor.has_method("play_gesture"):
		actor.call("play_gesture", "victory", 1.0, true)
	_sfx("res://assets/audio/sfx/ENC_Win.mp3")


func _tick_cfo_victory() -> void:
	if _victory_done:
		return
	var actor := _toon_actor() as Node3D
	if actor != null and _movie_cam != null:
		var forward := -actor.global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() < 0.01:
			forward = Vector3(0, 0, -1)
		forward = forward.normalized()
		_movie_cam.global_position = actor.global_position + forward * 8.0 + Vector3.UP * 2.1
		var focus := actor.global_position + Vector3.UP * 1.6
		if _movie_cam.global_position.distance_squared_to(focus) > 0.04:
			_movie_cam.look_at(focus, Vector3.UP)
func finish_cfo_victory() -> void:
	_victory_done = true
	_mode = ""
	var actor := _toon_actor()
	if actor != null and actor.has_method("clear_gesture"):
		actor.call("clear_gesture")
	_release_camera()
	_free_toon()


func _toon_actor() -> Node:
	var body := _body()
	if body == null:
		return null
	for child in body.get_children():
		if child.has_method("play_emote"):
			return child
	return null


func _stand_on_crane(body: CharacterBody3D, delta: float) -> void:
	var pads := _crane_pads()
	if _crane < 0 or _crane >= pads.size():
		return
	var pad := pads[_crane]
	body.velocity = Vector3.ZERO
	var spot := _controls_at(pad)
	if _mount_left > 0.0:
		_mount_left = maxf(_mount_left - delta, 0.0)
		var along := 1.0 - clampf(_mount_left / 0.2, 0.0, 1.0)
		body.global_position = _mount_from.lerp(spot, along)
	else:
		body.global_position = spot
	var focus := _boss_pos
	focus.y = body.global_position.y
	if body.global_position.distance_squared_to(focus) > 0.04:
		body.look_at(focus, Vector3.UP)


func _lever_pose(suffix: String) -> void:
	_lever = suffix
	var actor := _toon_actor()
	if actor != null and actor.has_method("play_gesture"):
		actor.call("play_gesture", suffix, 1.0, suffix == "leverNeutral")


func _finish_lever() -> void:
	var actor := _toon_actor()
	if actor != null and actor.has_method("gesture_finished") and bool(actor.call("gesture_finished")):
		_lever_pose("leverNeutral")


func _clear_lever() -> void:
	_lever = ""
	_mount_left = 0.0
	var actor := _toon_actor()
	if actor != null and actor.has_method("clear_gesture"):
		actor.call("clear_gesture")


func _aim_stick_at_hand() -> void:
	if _root == null or _crane < 0:
		return
	var stick := _root.get_node_or_null("Stick%d" % _crane) as Node3D
	var actor := _toon_actor() as Node3D
	if stick == null or actor == null:
		return
	var hand := actor.find_child("def_joint_right_hold", true, false) as Node3D
	if hand == null:
		return
	var to_hand := hand.global_position - stick.global_position
	if to_hand.length_squared() < 0.01:
		return
	var up := to_hand.normalized()
	var side := Vector3.UP.cross(up)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT.cross(up)
	side = side.normalized()
	stick.global_basis = Basis(side, up.cross(side), up)


func _aim_crane_camera() -> void:
	var pads := _crane_pads()
	if _crane < 0 or _crane >= pads.size():
		return
	_grab_camera()
	if _movie_cam == null:
		return
	var pad := pads[_crane]
	# The hinge stays on the crane. The arm swings under it, and the camera does not.
	var forward := _boss_pos - pad.global_position
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3(0.0, 0.0, -1.0)
	forward = forward.normalized()
	var hinge := pad.global_position + forward * -17.6 + Vector3.UP * 38.5
	_movie_cam.fov = 72.0
	_movie_cam.global_position = hinge + forward * -20.0 + Vector3.UP * -5.0
	var focus := _movie_cam.global_position + forward * cos(deg_to_rad(20.0)) + Vector3.DOWN * sin(deg_to_rad(20.0))
	if _movie_cam.global_position.distance_squared_to(focus) > 0.04:
		_movie_cam.look_at(focus, Vector3.UP)


func _tick_birds(dizzy: bool) -> void:
	if not dizzy:
		_stop_birds()
		return
	if _birds != null and is_instance_valid(_birds) and _birds.playing:
		return
	var path := "res://assets/cogs/bosses/audio/SZ_TC_bird1.ogg"
	if not FileAccess.file_exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var copy := stream.duplicate() as AudioStream
	if copy != null:
		stream = copy
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	if _birds == null or not is_instance_valid(_birds):
		_birds = AudioStreamPlayer.new()
		_birds.name = "CfoBirds"
		add_child(_birds)
	_birds.stream = stream
	_birds.play()


func _stop_birds() -> void:
	if _birds != null and is_instance_valid(_birds):
		_birds.stop()


func _face_cfo(cfo: Node3D, heading: float) -> void:
	# The exported body already faces heading 180.
	cfo.rotation.z = deg_to_rad(heading - 180.0)


func _roll_camera(cfo: Node3D) -> void:
	_grab_camera()
	if _movie_cam == null:
		return
	_movie_cam.global_position = cfo.to_global(Vector3(0.0, -27.0, 25.0))
	var focus := cfo.to_global(Vector3(0.0, -8.0, 19.0))
	if _movie_cam.global_position.distance_squared_to(focus) > 0.04:
		_movie_cam.look_at(focus, Vector3.UP)


func _tick_battle_goon(index: int, delta: float, body: CharacterBody3D) -> void:
	var goon: Dictionary = _goons[index]
	if not bool(goon.get("live", true)):
		return
	if not _driving and _held != 100 + index:
		return
	var phase := String(goon.get("phase", "walk"))
	var at: Vector3 = goon["at"]
	var speed := float(goon.get("speed", 4.0))
	var scale := float(goon.get("scale", 1.0))
	var rider := _other_holds_goon(index)
	var carrying := _held == 100 + index or not rider.is_empty()
	if _held == 100 + index:
		at = _held_point()
	elif not rider.is_empty():
		at = _remote_goon_hang(rider, goon)
	elif phase == "emerge":
		var left := maxf(float(goon.get("move", 0.0)) - delta, 0.0)
		goon["move"] = left
		var span := maxf(float(goon.get("span", 1.0)), 0.01)
		at = (goon["from"] as Vector3).lerp(goon["to"], 1.0 - left / span)
		if left <= 0.0:
			_release_goon_door(index)
			goon["door_held"] = false
			phase = "walk"
			goon["move"] = randf_range(2.0, 5.0)
	elif phase == "walk":
		var face: Vector3 = goon.get("face", Vector3(0.0, 0.0, -1.0))
		var turning := float(goon.get("turn", 0.0))
		if turning > 0.0:
			var span := maxf(float(goon.get("turn_span", turning)), 0.01)
			goon["turn"] = maxf(turning - delta, 0.0)
			var along := 1.0 - float(goon["turn"]) / span
			var start: Vector3 = goon.get("turn_from", face)
			var goal: Vector3 = goon.get("turn_to", face)
			face = start.slerp(goal, clampf(along, 0.0, 1.0))
			if face.length_squared() > 0.0001:
				face = face.normalized()
			goon["face"] = face
		else:
			var room := _goon_wall_dist(at, face)
			if float(goon.get("move", 0.0)) <= 0.0 or room < 1.2:
				var picked := _choose_goon_heading(at, face)
				var goal: Vector3 = picked["face"]
				var dist := minf(float(picked["dist"]), 10.0)
				var degrees := absf(rad_to_deg(face.signed_angle_to(goal, Vector3.UP)))
				var turn_time := degrees / (maxf(speed, 0.2) * 5.0)
				goon["move"] = dist / maxf(speed, 0.2)
				if turn_time > 0.05:
					goon["turn_from"] = face
					goon["turn_to"] = goal
					goon["turn"] = turn_time
					goon["turn_span"] = turn_time
				else:
					face = goal
					goon["face"] = face
			else:
				var step := minf(speed * delta, maxf(room - 1.0, 0.0))
				at += face * step
				goon["move"] = float(goon["move"]) - delta
				if step < speed * delta * 0.5:
					goon["move"] = 0.0
			goon["face"] = face
	elif phase == "collapse":
		goon["clip_t"] = float(goon.get("clip_t", 0.0)) + delta
		if float(goon["clip_t"]) >= 1.0:
			phase = "hold"
			goon["clip_t"] = float(goon.get("pause", 8.0))
	elif phase == "hold":
		goon["clip_t"] = maxf(float(goon.get("clip_t", 0.0)) - delta, 0.0)
		if float(goon["clip_t"]) <= 0.0:
			phase = "recovery"
			goon["clip_t"] = 0.0
			_sfx("res://assets/cog_hq/audio/CHQ_GOON_rattle_shake.ogg")
	elif phase == "recovery":
		goon["clip_t"] = float(goon.get("clip_t", 0.0)) + delta
		if float(goon["clip_t"]) >= 2.0:
			phase = "walk"
	goon["phase"] = phase
	goon["at"] = at
	var node := _root.get_node_or_null("Goon%d" % index) as Node3D
	if node != null:
		node.global_position = at
		node.visible = true
		node.scale = Vector3.ONE * scale
		if not carrying and (phase == "emerge" or phase == "walk"):
			_yaw_goon(node, goon.get("face", Vector3(0.0, 0.0, -1.0)))
		_pose_battle_goon(node, goon)
		var shadow := node.get_node_or_null("drop_shadow") as MeshInstance3D
		if shadow != null:
			shadow.visible = not carrying
		_plant_goon_shadow(node)
	_aim_goon_cone(goon, at, (phase == "emerge" or phase == "walk") and not carrying)
	if not carrying and (phase == "emerge" or phase == "walk") and _in_goon_cone(goon, at, body):
		_stun_goon(index)
		_boss.call("note_goon", int(goon.get("strength", 5)))
		_drop_treasure(at, int(goon.get("heal", 3)))
		var actor := _toon_actor()
		if actor != null and actor.has_method("flash_stun"):
			actor.call("flash_stun")
	elif not carrying and (phase == "emerge" or phase == "walk") and _bumped_goon(at, scale, float(goon.get("reach", 12.0)), body):
		# entertoonSphere. Touching the body collapses the goon and leaves you standing.
		_stun_goon(index)
	elif _driving and not carrying and (phase == "emerge" or phase == "walk"):
		for person in _remote_actors():
			if _in_goon_cone(goon, at, person):
				_stun_goon(index)
				_zap_peer = int(person.get_meta("peer"))
				_zap_seq += 1
				_zap_strength = int(goon.get("strength", 5))
				_zap_heal = int(goon.get("heal", 3))
				_zap_at = at
				break
			if _bumped_goon(at, scale, float(goon.get("reach", 12.0)), person):
				_stun_goon(index)
				break
	_goons[index] = goon


func _make_goon_cone() -> Node3D:
	var root := Node3D.new()
	root.name = "GoonCone"
	add_child(root)
	var path := "res://assets/cog_hq/alpha_cone.glb"
	var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if packed != null:
		var model := packed.instantiate() as Node3D
		if model != null:
			root.add_child(model)
			_fade_cone(model)
	if root.get_child_count() == 0:
		var mesh := MeshInstance3D.new()
		var cone := ConeMesh.new()
		cone.top_radius = 1.0
		cone.bottom_radius = 0.02
		cone.height = 1.0
		mesh.mesh = cone
		mesh.rotation.x = -PI * 0.5
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color(1.0, 1.0, 1.0, 0.2)
		paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		paint.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material_override = paint
		root.add_child(mesh)
	root.visible = false
	return root


func _aim_goon_cone(goon: Dictionary, at: Vector3, showing: bool) -> void:
	var cone := goon.get("cone") as Node3D
	if cone == null or not is_instance_valid(cone):
		return
	cone.visible = showing
	if not cone.visible:
		return
	var face: Vector3 = goon.get("face", Vector3(0.0, 0.0, -1.0))
	face.y = 0.0
	if face.length_squared() < 0.01:
		face = Vector3(0.0, 0.0, -1.0)
	face = face.normalized()
	var reach := float(goon.get("reach", 12.0))
	var half := float(goon.get("fov", 75.0)) * 0.5
	var mesh := cone.get_child(0) as Node3D
	if mesh is MeshInstance3D and (mesh as MeshInstance3D).mesh is ConeMesh:
		var radius := tan(deg_to_rad(half)) * reach
		var shape := (mesh as MeshInstance3D).mesh as ConeMesh
		shape.height = reach
		shape.top_radius = radius
		mesh.position = Vector3(0.0, 0.0, -reach * 0.5)
	elif mesh != null:
		# scaleRadar. The beam is long on Y, then pitched by half the fov.
		var kw := tan(deg_to_rad(half)) * reach / 10.5
		var kl := sqrt(reach * reach + 9.0) / 25.0
		var pitch := deg_to_rad(half)
		var y := -6.0 * kl
		var z := -1.8 * kw
		var z2 := y * sin(pitch) + z * cos(pitch)
		var sz := -3.5 / z2 if absf(z2) > 0.01 else 1.0
		mesh.scale = Vector3(kw, kl, kw * sz)
		mesh.rotation = Vector3(pitch + PI * 0.5, 0.0, 0.0)
	cone.global_position = at + Vector3.UP * 1.2
	var focus := cone.global_position + face
	if cone.global_position.distance_squared_to(focus) > 0.04:
		cone.look_at(focus, Vector3.UP)


func _in_goon_cone(goon: Dictionary, at: Vector3, body: Node3D) -> bool:
	if body == null:
		return false
	var delta := body.global_position - at
	var reach := float(goon.get("reach", 12.0))
	if delta.length() > reach:
		return false
	var flat := Vector3(delta.x, 0.0, delta.z)
	if flat.length_squared() < 0.01:
		return true
	var face: Vector3 = goon.get("face", Vector3(0.0, 0.0, -1.0))
	face.y = 0.0
	if face.length_squared() < 0.01:
		return false
	return face.normalized().dot(flat.normalized()) >= cos(deg_to_rad(float(goon.get("fov", 75.0)) * 0.5))


func _hide_goon_cone(goon: Dictionary) -> void:
	var cone := goon.get("cone") as Node3D
	if cone != null and is_instance_valid(cone):
		cone.visible = false


func _crush_goon(index: int) -> void:
	if index < 0 or index >= _goons.size():
		return
	var goon: Dictionary = _goons[index]
	goon["live"] = false
	_goons[index] = goon
	_release_goon_door(index)
	_hide_goon_cone(goon)
	var at: Vector3 = goon["at"]
	var host := _boss.get_parent() if _boss != null else self
	var packed := load("res://assets/battle/props/explosion.glb") as PackedScene
	if packed != null and host != null:
		var boom := packed.instantiate() as Node3D
		if boom != null:
			host.add_child(boom)
			boom.global_position = at + Vector3.UP * 2.0
			boom.scale = Vector3(randf_range(0.3, 0.8), 1.0, randf_range(0.3, 0.8))
			get_tree().create_timer(0.6).timeout.connect(func() -> void:
				if is_instance_valid(boom):
					boom.queue_free()
			)
	_sfx("res://assets/audio/battle/ENC_cogfall_apart.ogg")
	_spray_gears(at + Vector3.UP * 2.0)


func _pose_stun(stars: Node3D) -> void:
	if _stun_clip.is_empty():
		var path := "res://assets/cogs/bosses/stun_clip.json"
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				_stun_clip = parsed
	var joints: Dictionary = _stun_clip.get("joints", {})
	if joints.is_empty():
		stars.rotate_z(0.08)
		return
	var posed := false
	for joint_name in ["joint_blur1", "joint_blur2"]:
		var joint := stars.find_child(joint_name, true, false) as Node3D
		var samples: Array = joints.get(joint_name, [])
		if joint == null or samples.is_empty():
			continue
		var frame := posmod(int(_clock * float(_stun_clip.get("fps", 24.0))), samples.size())
		var sample: Array = samples[frame]
		var heading := deg_to_rad(float(sample[0]))
		var pitch := deg_to_rad(float(sample[1]))
		var roll := deg_to_rad(float(sample[2]))
		joint.basis = Basis(Vector3.UP, heading) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3(0.0, 1.0, 0.0), roll)
		posed = true
	if not posed:
		stars.rotate_z(0.08)


func _fade_cone(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var source := mesh.get_active_material(0) if mesh.mesh != null and mesh.mesh.get_surface_count() > 0 else null
		var paint := source.duplicate() as StandardMaterial3D if source is StandardMaterial3D else StandardMaterial3D.new()
		paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var color := paint.albedo_color
		color.a = 0.2
		paint.albedo_color = color
		paint.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		paint.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material_override = paint
	for child in node.get_children():
		_fade_cone(child)


func _spray_gears(at: Vector3) -> void:
	# GearExplosion lasts 4.3 seconds. WideGearExplosion lasts 1 second.
	_burst_gears(at, 10, 9.0, 9.0, 3.23, Vector3.DOWN * 2.0, 4.3)
	_burst_gears(at, 30, 15.0, 10.0, 1.75, Vector3.DOWN * 0.5, 1.0)


func _burst_gears(at: Vector3, count: int, speed: float, lift: float, radius: float, origin: Vector3, life: float) -> void:
	var texture := load("res://assets/battle/props/gear_0.png") as Texture2D
	for _index in count:
		var mesh := MeshInstance3D.new()
		var card := QuadMesh.new()
		card.size = Vector2(0.7, 0.7)
		mesh.mesh = card
		var paint := StandardMaterial3D.new()
		paint.albedo_texture = texture
		paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		paint.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		paint.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material_override = paint
		var host := _boss.get_parent() if _boss != null else self
		if host == null:
			mesh.queue_free()
			return
		host.add_child(mesh)
		var spread := Vector3(randf_range(-1.0, 1.0), randf_range(-0.2, 0.6), randf_range(-1.0, 1.0))
		if spread.length_squared() < 0.01:
			spread = Vector3.UP
		spread = spread.normalized()
		mesh.global_position = at + origin + spread * randf() * radius
		_gear_bits.append({
			"node": mesh,
			"vel": spread * speed + Vector3.UP * lift,
			"left": life,
		})


func _tick_gear_bits(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for bit in _gear_bits:
		var left := float(bit.get("left", 0.0)) - delta
		var node := bit.get("node") as Node3D
		if left <= 0.0 or node == null or not is_instance_valid(node):
			if node != null and is_instance_valid(node):
				node.queue_free()
			continue
		var vel: Vector3 = bit["vel"]
		vel.y -= 28.0 * delta
		bit["vel"] = vel
		bit["left"] = left
		node.global_position += vel * delta
		kept.append(bit)
	_gear_bits = kept


func _clear_gear_bits() -> void:
	for bit in _gear_bits:
		var node := bit.get("node") as Node3D
		if node != null and is_instance_valid(node):
			node.queue_free()
	_gear_bits.clear()


func _head_is_flipped() -> bool:
	# getAngryActorInterval reverses the head for the clip, then forwardHead.
	# The throw clip is under a second long, so the head comes forward while the swing continues.
	if _anim_clip == "Fb_UpThrow":
		return _anim_time < _clip_span("Fb_UpThrow")
	return _anim_clip == "Fb_firstHit" or _anim_clip == "Fb_downHit" or _anim_clip == "Fb_down2Up"


func _clip_span(clip: String) -> float:
	var bank := _anim_banks.get(clip, {}) as Dictionary
	var frames := int(bank.get("frames", 0))
	var fps := float(_anim_rates.get(clip, 24.0))
	if frames <= 1 or fps <= 0.0:
		return 100.0
	return float(frames) / fps


func _cfo_head(cfo: Node3D) -> Node3D:
	var neck := cfo.find_child("joint34", true, false) as Node3D
	if neck == null or neck.get_child_count() == 0:
		return null
	return neck.get_child(0) as Node3D


func _set_cfo_head(flipped: bool) -> void:
	# reverseHead sets the head part to pitch -180. The mesh is the child of joint34.
	var cfo := _root.get_node_or_null("CFO") as Node3D if _root != null else null
	var head := _cfo_head(cfo) if cfo != null else null
	if head == null:
		return
	_head_flipped = flipped
	if flipped:
		head.quaternion = Quaternion(Vector3.RIGHT, deg_to_rad(-180.0))
	else:
		head.quaternion = Quaternion.IDENTITY


func _follow_crane_shadow(carriage: Vector3, aim: Vector3) -> void:
	# startShadow. The round card sits under the magnet. The square card sits
	# under the arm, baked 12 back from the carriage at scale (0.5, 4, 1).
	if _root == null:
		return
	_ensure_crane_shadow()
	var magnet_local := _root.to_local(_magnet)
	_magnet_shadow.position = Vector3(magnet_local.x, magnet_local.y, 1.0)
	_magnet_shadow.visible = true
	var center := _root.to_local(carriage - aim * 12.0)
	_crane_shadow.position = Vector3(center.x, center.y, 1.0)
	var flat := _root.global_transform.basis.inverse() * aim
	flat.z = 0.0
	if flat.length_squared() > 0.0001:
		_crane_shadow.rotation = Vector3(0.0, 0.0, atan2(flat.x, flat.y))
	_crane_shadow.visible = true
	_pose_cable_shadow(carriage)


func _hide_crane_shadow() -> void:
	if _magnet_shadow != null and is_instance_valid(_magnet_shadow):
		_magnet_shadow.visible = false
	if _crane_shadow != null and is_instance_valid(_crane_shadow):
		_crane_shadow.visible = false
	if _cable_shadow != null and is_instance_valid(_cable_shadow):
		_cable_shadow.visible = false


func _ensure_crane_shadow() -> void:
	if _magnet_shadow != null and is_instance_valid(_magnet_shadow):
		return
	_magnet_shadow = _shadow_card("MagnetShadow", Vector2(8.0, 8.0), "res://assets/neighborhoods/toontown_central/props/drop_shadow.png")
	_crane_shadow = _shadow_card("CraneShadow", Vector2(4.0, 32.0), "res://assets/cog_hq/square_drop_shadow.jpg")
	_cable_shadow = _shadow_card("CableShadow", Vector2.ZERO, "res://assets/cog_hq/square_drop_shadow.jpg", Color(1.0, 1.0, 1.0, 0.2))
	_cable_shadow.mesh = ImmediateMesh.new()


func _pose_cable_shadow(carriage: Vector3) -> void:
	# The shadow rope is a flat tape under the links, lifted to shadowOffset.
	if _cable_shadow == null or not is_instance_valid(_cable_shadow):
		return
	var points: Array[Vector3] = [_root.to_local(carriage)]
	for index in 3:
		points.append(_root.to_local(_link_p[index]))
	for index in points.size():
		points[index] = Vector3(points[index].x, points[index].y, 1.0)
	var ribbon := _cable_shadow.mesh as ImmediateMesh
	if ribbon == null:
		ribbon = ImmediateMesh.new()
		_cable_shadow.mesh = ribbon
	ribbon.clear_surfaces()
	var total := 0.01
	for index in points.size() - 1:
		total += Vector2(points[index].x, points[index].y).distance_to(Vector2(points[index + 1].x, points[index + 1].y))
	ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var along := 0.0
	var half := 0.4
	for index in points.size() - 1:
		var a := points[index]
		var b := points[index + 1]
		var dir := Vector3(b.x - a.x, b.y - a.y, 0.0)
		var span := dir.length()
		if span < 0.001:
			continue
		dir /= span
		var side := Vector3(-dir.y, dir.x, 0.0) * half
		var u0 := along / total
		along += span
		var u1 := along / total
		_ribbon_vertex(ribbon, a - side, u0, 0.0)
		_ribbon_vertex(ribbon, a + side, u0, 1.0)
		_ribbon_vertex(ribbon, b + side, u1, 1.0)
		_ribbon_vertex(ribbon, a - side, u0, 0.0)
		_ribbon_vertex(ribbon, b + side, u1, 1.0)
		_ribbon_vertex(ribbon, b - side, u1, 0.0)
	ribbon.surface_end()
	_cable_shadow.position = Vector3.ZERO
	_cable_shadow.rotation = Vector3.ZERO
	_cable_shadow.visible = true


func _ribbon_vertex(ribbon: ImmediateMesh, point: Vector3, u: float, v: float) -> void:
	ribbon.surface_set_uv(Vector2(u, v))
	ribbon.surface_add_vertex(point)


func _add_goon_shadow(goon: Node3D) -> void:
	# initializeDropShadow. Scale 0.4 on the 8-unit card, black at half strength.
	# ShadowPlacer drops it to the floor. hideShadows while the magnet is holding it.
	_shadow_card("drop_shadow", Vector2(3.2, 3.2), "res://assets/neighborhoods/toontown_central/props/drop_shadow.png", Color(0.0, 0.0, 0.0, 0.5), goon)


func _shadow_card(card_name: String, size: Vector2, texture_path: String, tint: Color = Color(1.0, 1.0, 1.0, 0.3), parent: Node = null) -> MeshInstance3D:
	var card := MeshInstance3D.new()
	card.name = card_name
	if size != Vector2.ZERO:
		var quad := QuadMesh.new()
		quad.orientation = PlaneMesh.FACE_Z
		quad.size = size
		card.mesh = quad
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	paint.albedo_color = tint
	var tex := load(texture_path) as Texture2D
	if tex != null:
		paint.albedo_texture = tex
	card.material_override = paint
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var host: Node = parent if parent != null else _root
	if size == Vector2.ZERO:
		card.mesh = ImmediateMesh.new()
	host.add_child(card)
	return card


func _stun_goon(index: int) -> void:
	if index < 0 or index >= _goons.size():
		return
	_release_goon_door(index)
	_goons[index]["door_held"] = false
	_goons[index]["phase"] = "collapse"
	_goons[index]["clip_t"] = 0.0
	_sfx("res://assets/cog_hq/audio/CHQ_GOON_hunker_down.ogg")


func _release_goon_door(index: int) -> void:
	if index < 0 or index >= _goons.size():
		return
	if not bool(_goons[index].get("door_held", false)):
		return
	_goons[index]["door_held"] = false
	_hold_cfo_door(String(_goons[index].get("door", "")), false)


func _door_out(door_name: String) -> Vector3:
	var cfo := _root.get_node_or_null("CFO") as Node3D if _root != null else null
	var hinge := cfo.find_child(door_name, true, false) as Node3D if cfo != null else null
	var out := Vector3.ZERO
	if hinge != null:
		out = hinge.global_transform.basis.x
		if door_name == "DoorRear":
			out = -out
	if out.length_squared() < 0.01:
		out = _right if door_name == "DoorFront" else -_right
	out.y = 0.0
	if out.length_squared() < 0.01:
		out = Vector3(0.0, 0.0, -1.0)
	return out.normalized()


func _hold_cfo_door(door_name: String, opening: bool) -> void:
	if door_name == "" or _root == null:
		return
	var cfo := _root.get_node_or_null("CFO") as Node3D
	if cfo == null:
		return
	var hinge := cfo.find_child(door_name, true, false) as Node3D
	if hinge == null:
		return
	if not _cfo_doors.has(door_name):
		_cfo_doors[door_name] = {"closed": hinge.quaternion, "count": 0}
	var row: Dictionary = _cfo_doors[door_name]
	var count := maxi(int(row.get("count", 0)) + (1 if opening else -1), 0)
	row["count"] = count
	_cfo_doors[door_name] = row
	hinge.quaternion = Quaternion.IDENTITY if count > 0 else (row["closed"] as Quaternion)


func _yaw_goon(node: Node3D, face: Vector3) -> void:
	# initGoon turns actorGeom 180 so the face leads panda +Y. Yaw around local Z,
	# which the vault turns into world up. look_at would drop that conversion.
	var flat := _panda_dir(node.global_position, face)
	var heading := atan2(-flat.x, flat.y) + PI
	var size := node.scale
	node.rotation = Vector3(0.0, 0.0, heading)
	node.scale = size


func _pose_battle_goon(node: Node3D, goon: Dictionary) -> void:
	var phase := String(goon.get("phase", "walk"))
	var clip := "walk"
	var time := 0.0
	var looping := true
	var rate := 1.0
	var scale := maxf(float(goon.get("scale", 1.0)), 0.2)
	var speed := float(goon.get("speed", 4.0))
	if phase == "collapse" or phase == "hold":
		clip = "collapse"
		time = 1.0 if phase == "hold" else float(goon.get("clip_t", 0.0))
		looping = false
	elif phase == "recovery":
		clip = "recovery"
		time = float(goon.get("clip_t", 0.0))
		looping = false
	else:
		time = float(goon.get("clip_t", 0.0))
		rate = 4.0 if _held >= 100 else speed / (2.8 * scale)
	if phase == "walk" or phase == "emerge":
		goon["clip_t"] = time + get_process_delta_time() * rate
	var bank := _battle_goon_bank(node, clip)
	var frames := int(bank.get("frames", 0))
	if frames <= 1 or _poser == null:
		return
	if _goon_rates.is_empty():
		_load_goon_rates()
	var fps := float(_goon_rates.get(clip, 24.0))
	_poser.call("_pose_elapsed", bank, time, fps, looping)


func _battle_goon_bank(node: Node3D, clip: String) -> Dictionary:
	var key := "%d:%s" % [node.get_instance_id(), clip]
	if _goon_banks.has(key):
		return _goon_banks[key]
	var path := "res://assets/cog_hq/goon_anims/%s.walk" % clip
	if not FileAccess.file_exists(path):
		return {}
	if _poser == null:
		_poser = StreetCog.new()
	var loaded: Variant = _poser.call("_read_bank", path, node)
	if loaded is Dictionary:
		_goon_banks[key] = loaded
		return loaded
	return {}


func _load_goon_rates() -> void:
	var rates_path := "res://assets/cog_hq/goon_anims/clips.json"
	if not FileAccess.file_exists(rates_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(rates_path))
	if parsed is Dictionary:
		for key in parsed:
			var row: Variant = parsed[key]
			if row is Dictionary:
				_goon_rates[str(key)] = float(row.get("fps", 24.0))


func _treasure_scene(heal: int) -> String:
	if heal >= 12:
		var cold: Array[String] = [
			"res://assets/neighborhoods/the_burrrgh/props/snowflake_treasure.glb",
			"res://assets/neighborhoods/donalds_dreamland/props/zzz_treasure.glb",
		]
		return cold[randi() % cold.size()]
	if heal >= 10:
		var mid: Array[String] = [
			"res://assets/neighborhoods/donalds_dock/props/starfish_treasure.glb",
			"res://assets/neighborhoods/daisy_gardens/props/flower_treasure.glb",
			"res://assets/neighborhoods/minnies_melodyland/props/music_treasure.glb",
		]
		return mid[randi() % mid.size()]
	return "res://assets/neighborhoods/toontown_central/props/icecream.glb"


func _hit_noise(impact: float, minimum: float) -> void:
	if impact >= minimum:
		_sfx("res://assets/cog_hq/audio/AA_drop_safe_miss.ogg")
	else:
		_sfx("res://assets/cog_hq/audio/AA_drop_sandbag.ogg")


func _pose_lesson_goon(goon: Node3D, clip: String, delta: float) -> void:
	var path := "res://assets/cog_hq/goon_anims/%s.walk" % clip
	if not FileAccess.file_exists(path):
		return
	if _goon_rates.is_empty():
		var rates_path := "res://assets/cog_hq/goon_anims/clips.json"
		if FileAccess.file_exists(rates_path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(rates_path))
			if parsed is Dictionary:
				for key in parsed:
					var row: Variant = parsed[key]
					if row is Dictionary:
						_goon_rates[str(key)] = float(row.get("fps", 24.0))
	if clip != _goon_clip:
		_goon_clip = clip
		_goon_time = 1.0 if clip == "collapse" else 0.0
	if not _goon_banks.has(clip):
		if _poser == null:
			_poser = StreetCog.new()
		var loaded: Variant = _poser.call("_read_bank", path, goon)
		if loaded is Dictionary:
			_goon_banks[clip] = loaded
	var bank := _goon_banks.get(clip, {}) as Dictionary
	var frames := int(bank.get("frames", 0))
	if frames <= 1 or _poser == null:
		return
	var fps := float(_goon_rates.get(clip, 12.0))
	if clip != "collapse":
		_goon_time += delta
	_poser.call("_pose_elapsed", bank, _goon_time, fps, clip == "walk")


func _lesson_line(at: float, text: String, cog: bool) -> void:
	if _clock < at or _lesson_said.has(at):
		return
	_lesson_said[at] = true
	if _boss != null:
		_boss.call("cfo_intro_line", text, cog)
