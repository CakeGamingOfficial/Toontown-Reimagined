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
var _chair_slide := 0.0
var _lawyers: Array[Dictionary] = []
var _gavels: Array[Dictionary] = []
var _gavel := 7.0
var _gavel_zone := Vector3.ZERO
var _gavel_live := 0.0
var _food: Array[Dictionary] = []
var _diners: Array[Dictionary] = []
var _diner_banks: Dictionary = {}
var _balls: Array[Dictionary] = []
var _station_index := -1
var _station_table := -1
var _station_arm := false
var _crushing := false
var _crush_table := -1
var _crush_rider := false
var _attack_now := false
var _crush_to := Vector3.ZERO
var _flat_for := 3.0
var _over_one := false
var _over_two := false
var _ceo_shots: Array[Dictionary] = []
var _ceo_clip := ""
var _ceo_time := 0.0
var _hardball_left := -1.0
var _hardball_play := -1.0
var _hardball: AudioStreamPlayer
var _ceo_loop := false
var _ceo_next := ""
var _ceo_raised := false
var _ceo_banks: Dictionary = {}
var _ceo_rates: Dictionary = {}
var _ceo_frames: Dictionary = {}
var _gil: ToonActor
var _gil_job := ""
var _gil_age := 0.0
var _door_from := 0.0
var _door_to := 0.0
var _door_age := 0.0
var _door_span := 0.0
var _face_from := 0.0
var _face_to := 0.0
var _face_now := 0.0
var _face_age := 0.0
var _face_span := 0.0
var _face_return := -1.0
var _ceo_left_u := 0.0
var _ceo_right_u := 0.0
var _ceo_left_mat: StandardMaterial3D
var _ceo_right_mat: StandardMaterial3D
var _spin_from := 0.0
var _spin_add := 0.0
var _spin_age := 0.0
var _spin_span := 0.0
var _fore_phase := 0
var _fore_left := 0.0
var _fore_heading := 0.0
var _fore_safe := 0.0
var _zap_left := 0.0
var _zap_clip := ""
var _slide_from := Vector3.ZERO
var _slide_to := Vector3.ZERO
var _slide_left := 0.0
var _putter: Node3D
var _swing_age := -1.0
var _swing_power := 0.0
var _swing_sent := false
var _tee_grow := -1.0
var _water: Array[Dictionary] = []
var _board_from := Vector3.ZERO
var _board_age := 0.0
var _board_span := 0.0
var _carry := false
var _golf := false
var _spray := 0.0
var _station := ""
var _tee_h := 0.0
var _belts: Array[Vector3] = []
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
var _jury_baked := Vector3.ZERO
var _reflect: Node3D
var _reflect_start := Vector3.ZERO
var _reflect_baked := Vector3.ZERO
var _barrel_p := 10.0
var _flying := false
var _fly_from := Vector3.ZERO
var _fly_vel := Vector3.ZERO
var _fly_time := 0.0
var _cannon_pad: Node3D
var _chairs: Array[Dictionary] = []
var _suit_timing: Dictionary = {}
var _suit_timing_ready := false
var _cj: Node3D
var _witness: ToonActor
var _intro_at := 0
var _intro_wait := 0.0
var _defeat_left := 0.0
var _ctrl_down := false
var _delete_down := false
var _podium: Node3D
var _podium_base := 0.0
var _podium_low := false
var _refl_podium: Node3D
var _refl_base := 0.0
var _jury_loop: AudioStreamPlayer
var _cannon_pads: Array[Node3D] = []
var _act_t := 0.0
var _ceo_beat := 0
var _pages: PackedStringArray = PackedStringArray()
var _page := 0
var _page_next := ""
var _line_at := -1
var _scale_model: Node3D
var _court_door: Node3D
var _court_door_z := 0.0
var _cj_from := Vector3.ZERO
var _cj_to := Vector3.ZERO
var _roll_span := 5.0
var _tread_u := 0.0
var _head_talk := 0.0
var _head_back := false
var _hint := ""
var _hint_left := 30.0
var _threw := false
var _restocked := false
var _judge_wave := 0
var _area_at := -100.0
var _area_seq := 0
var _seen_area := 0
var _cj_send := 0.0
var _claims: Array = []
var _cannon_move: AudioStreamPlayer
var _toss_t := 0.0
var _tint_root: Node3D
var _tint_left := 0.0
var _tint_mat: StandardMaterial3D
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
var _belt_loop: AudioStreamPlayer
var _power_root: Control
var _power_fill: ColorRect
var _suit_at := -1.0
var _strip_at := -1.0
var _eyes_back := -1.0
var _threat_dusted := false
var _slip_left := 0.0
var _flat_return := -1
var _epilogue_on := false
var _ceo_field_send := 0.0
var _ceo_win := 0
var _walk_from := Vector3.ZERO
var _walk_floor := 0.0
var _walk_ready := false
var _belt_u := 0.0
var _attack_log: Array = []
var _attack_seq := 0
var _attack_seen := 0
var _chest: Node3D
var _chest_mat: StandardMaterial3D
var _chest_glow: StandardMaterial3D
var _chest_scale := Vector3.ONE
var _chest_condition := -1
var _chest_blink := 0.0
var _chest_red := true
var _puffs: Array[Dictionary] = []
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
	_clear_waiter()
	_restore_jury()
	_mode = ""
	_gears.clear()
	_clear_gear_bits()
	_clear_lever()
	_stop_birds()
	_stop_crane_audio()
	_belt_sound(false)
	if _power_root != null:
		_power_root.visible = false
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
	_barrel_p = 10.0
	_flying = false
	_retract_jury()
	_place_chairs()
	_place_battle_cannons()
	_place_cj(Vector3(-2.798, -60.0, 0.0), 0.0)
	if _witness != null:
		_witness.visible = false
	_mode = "cj_pass"
	_act_t = 0.0
	_line_at = -1
	_head_talk = 5.0
	_lock_toon()
	play_music("between")
	_tell("Bah, so you passed the bar exam.")


func start_evidence(boss: Node) -> void:
	_begin(boss)
	_mode = "evidence"
	# LawbotBossInjusticePosHpr and LawbotBossInjusticeScale. Pans sit on the beam.
	_scale_model = _model_or_box("res://assets/cog_hq/lawbot_scale.glb", Vector3(-3.0, 12.0, 0.0), "Scale", Color(0.75, 0.7, 0.35), Vector3(2.2, 0.4, 5.0))
	var scale := _scale_model
	scale.basis = _panda_hpr(90.0, 0.0, 0.0)
	scale.scale = Vector3(1.75, 1.75, 1.5)
	var defense := Node3D.new()
	defense.name = "Defense"
	var pan := scale.find_child("defensePan", true, false) as Node3D
	if pan != null:
		pan.add_child(defense)
	else:
		scale.add_child(defense)
		defense.position = Vector3(0.0, -4.692, 12.693)
	var geom := _geometry()
	_boss_pos = geom.to_global(Vector3(-3.0, 12.0, 0.0)) if geom != null else Vector3(-3.0, 12.0, 0.0)
	_place_lawyers(int(boss.call("lawyer_count")))
	_place_gavels(int(boss.call("gavel_count")))
	var prosecute := Node3D.new()
	prosecute.name = "Prosecution"
	var other := scale.find_child("prosecutionPan", true, false) as Node3D
	if other != null:
		other.add_child(prosecute)
	else:
		scale.add_child(prosecute)
		prosecute.position = Vector3(0.0, 4.791, 12.716)
	_show_battle_props(false)
	_show_witness(true)
	_mode = "cj_session"
	_act_t = 0.0
	_line_at = -1
	_lock_toon()
	play_music("between")
	_tell("Court is now in session")


func start_ceo_intro(boss: Node) -> void:
	_begin(boss)
	_lock_toon()
	_place_gil(Vector3(0.0, -64.0, 0.0))
	_ceo_say(PackedStringArray([
		"You toons will need different disguises.",
		"First take off your cog suits...",
		"and then fight these waiters.",
	]), "cogs")
	play_music("between")


func skip_ceo_intro() -> void:
	_mode = ""
	_gil_job = ""
	_release_camera()
	if _boss != null:
		_boss.call("finish_ceo_intro")


func start_banquet(boss: Node) -> void:
	_begin(boss)
	_place_banquet(boss)
	_place_gil(Vector3(0.0, -20.0, 0.0))
	_banquet_door(0.0)
	_ceo_say(PackedStringArray([
		"Good Job! Now put on the waiters' clothes.",
		"What's taking so long? ",
		"Get cracking and serve my banquet!",
		"Hehe, serve the food I place on these conveyor belts.",
		"If you serve a cog three times in a row it will explode.",
	]), "banquet")
	play_music("between")


func start_ceo_threat(boss: Node) -> void:
	_boss = boss
	_belt_sound(false)
	_threat_dusted = false
	_ceo_say(PackedStringArray([
		"What's happening here?!",
		"These waiters are toons!",
		"",
		"Get them!!!",
	]), "threat")


func start_seltzer(boss: Node) -> void:
	_boss = boss
	if _root == null:
		_begin(boss)
	_clock = 0.0
	_golf = false
	_carry = false
	_place_seltzer()
	_banquet_door(90.0)
	_show_gil_suit()
	_ceo_say(PackedStringArray([
		"Good Job! Now squirt the C.E.O. with the water on the tables...",
		"or use golf balls to slow him down.",
		"Hrrmmpph. When I need a job done right...",
		"I'll do it myself.",
	]), "seltzer")
	_play_music_file("res://assets/cog_hq/audio/BossBot_CEO_v2.ogg", "ceo2")


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
	if _mode == "cj_intro":
		_tick_cj_intro(delta)
		return
	if _mode == "ceo_talk":
		_tag_gil()
		_tick_ceo_talk(delta)
		return
	if _mode == "ceo_victory":
		_tick_ceo_victory(delta)
		return
	if _mode == "cj_defeat":
		_tick_cj_defeat(delta)
		return
	if _mode == "cj_pass" or _mode == "cj_roll" or _mode == "cj_rise" or _mode == "cj_pages" or _mode == "cj_appear" or _mode == "cj_session" or _mode == "cj_victory" or _mode == "cj_epilogue":
		_tick_cj_act(delta)
		_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
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
	var crane_word := "empty"
	if _crane >= 0:
		crane_word = "in use"
	_boss.call("paint_world", "Crane %s. He is %s." % [crane_word, status])


func _tick_cannon(delta: float, body: CharacterBody3D) -> void:
	if not _cj_driving() and ToonNet.networked():
		var snap := ToonNet.latest("cj-field")
		if snap.has("clock"):
			_clock = float(snap.get("clock", _clock))
		_apply_cj_field()
	_publish_cj(delta)
	var along := clampf(_clock / 70.0, 0.0, 1.0)
	var slide := Vector3(30.0, 0.0, 12.645) * along
	if _jury != null:
		_jury.position = _jury_start + slide
	if _reflect != null:
		_reflect.position = _reflect_start + slide
	_tick_chairs(delta)
	_pose_witness()
	if _clock >= 70.0:
		_flying = false
		if _cannon and _cannon_pad != null and body != null:
			body.global_position = _cannon_pad.to_global(Vector3(3.0, 0.0, 0.0))
			body.velocity = Vector3.ZERO
		if _cj_driving():
			_end_cannons()
		return
	if _flying:
		_tick_flight(delta, body)
		return
	var cannons := _named("Cannon")
	if not _cannon:
		if _KEYS.use_held() and _cool <= 0.0:
			for pad in cannons:
				if _near(body, pad.global_position, 3.0):
					_cannon = true
					_cannon_pad = pad
					_crane_h = 0.0
					_barrel_p = 10.0
					_cool = 0.3
					_lock_toon()
					_aim_cannon()
					break
		var left := maxf(70.0 - _clock, 0.0)
		_boss.call("paint_world", "Jury box %d seconds left. Toon jurors %d." % [int(left), _toon_jurors()])
		if _clock >= 70.0 and _cj_driving():
			_end_cannons()
		return
	if Input.is_physical_key_pressed(KEY_LEFT):
		_crane_h += delta * 15.0
	if Input.is_physical_key_pressed(KEY_RIGHT):
		_crane_h -= delta * 15.0
	if Input.is_physical_key_pressed(KEY_UP):
		_barrel_p += delta * 15.0
	if Input.is_physical_key_pressed(KEY_DOWN):
		_barrel_p -= delta * 15.0
	_crane_h = clampf(_crane_h, -55.0, 50.0)
	_barrel_p = clampf(_barrel_p, 10.0, 85.0)
	_aim_cannon()
	var aiming := Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_DOWN)
	_cannon_adjust(aiming)
	var firing := Input.is_key_pressed(KEY_CTRL)
	if firing and not _ctrl_down:
		_launch_flight(body)
	_ctrl_down = firing
	if _KEYS.use_held() and _cool <= 0.0:
		_cannon = false
		_cool = 0.3
		_free_toon()
	var state: Dictionary = _boss.call("world_state")
	var balls := 12 - int(state.get("shots", 0))
	_boss.call("paint_world", "Arrows aim. Control fires. E leaves. Shots %d. Jury %d seconds." % [balls, int(maxf(70.0 - _clock, 0.0))])
	if _clock >= 70.0 and _cj_driving():
		_end_cannons()


func _tick_evidence(delta: float, body: CharacterBody3D) -> void:
	_take_remote_stuns()
	_publish_cj(delta)
	_show_remote_shots()
	if not _cj_driving() and ToonNet.networked():
		_apply_cj_field()
	_tick_evidence_hints(delta)
	_tick_cj_judge(delta, body)
	var stand := _find("witnessStandSeatCenter")
	if stand == null:
		stand = _find("WitnessStand")
	if stand != null and _near(body, stand.global_position, 4.0):
		var before: Dictionary = _boss.call("world_state")
		var had := int(before.get("ammo", 0))
		_boss.call("restock_evidence")
		var after: Dictionary = _boss.call("world_state")
		if int(after.get("ammo", 0)) > had:
			_sfx("res://assets/cog_hq/audio/LB_receive_evidence.ogg")
			_restocked = true
			_hint = ""
			if not _threw:
				_hint_left = 30.0
	var deleting := Input.is_physical_key_pressed(KEY_DELETE)
	if deleting and not _delete_down and _cool <= 0.0:
		if bool(_boss.call("throw_evidence")):
			_threw = true
			_hint = ""
			_launch(body, 22.0, Color(0.45, 0.28, 0.12), "evidence")
		else:
			_hint = "You need to get more evidence!"
			_hint_left = 20.0
	_delete_down = deleting
	_pose_witness()
	_tick_tint(delta)
	_fly(_shots, delta)
	_boss.call("tick_lawyers", delta)
	var defense := _root.find_child("Defense", true, false) as Node3D
	for shot in _shots:
		if bool(shot["done"]) or defense == null:
			continue
		if _near_point(shot["at"], defense.global_position, 2.4):
			shot["done"] = true
			_boss.call("note_evidence")
			_sfx("res://assets/cog_hq/audio/LB_evidence_hit.ogg")
			var pan := defense.get_parent() as Node3D
			_tint(pan if pan != null else defense, Color(0.15, 0.25, 1.0, 0.55))
		elif _hit_evidence_toon(shot):
			shot["done"] = true
		elif _near_prosecution(shot["at"]):
			shot["done"] = true
			_tint(_cj, Color(0.2, 1.0, 0.35, 0.55))
		else:
			for index in _lawyers.size():
				var lawyer := _lawyers[index]["node"] as Node3D
				if lawyer != null and _near_point(shot["at"], lawyer.global_position, 1.6):
					shot["done"] = true
					_lawyers[index]["stun"] = 5.0
					_boss.call("stun_lawyer", index)
	var stunned := 0
	for index in _lawyers.size():
		if _cj_driving():
			_lawyers[index]["stun"] = maxf(float(_lawyers[index]["stun"]) - delta, 0.0)
		if float(_lawyers[index]["stun"]) > 0.0:
			stunned += 1
	if stunned == _lawyers.size() and not _lawyers.is_empty():
		_boss.call("note_all_stunned", delta)
	if _cj_driving():
		_tick_lawyer_throws(delta, body)
	else:
		_touch_lawyer_books(body)
	if _mode != "evidence":
		return
	_swing_gavels(0.0 if not _cj_driving() and ToonNet.networked() else delta, body)
	var state: Dictionary = _boss.call("world_state")
	_tilt_scale(float(state.get("hp", 1350)))
	var ammo_line := "Evidence %d. Throw at the defense pan." % int(state.get("ammo", 0))
	if _hint != "":
		ammo_line += "\n" + _hint
	_boss.call("paint_world", ammo_line)
	_pose_cj_head(delta)


func _place_lawyers(count: int) -> void:
	# LawbotBossLawyerPosHprs. The first eight face the scale. The last two stand at the pans.
	var seats: Array[Vector3] = [
		Vector3(-57.0, -24.0, 0.0), Vector3(-57.0, -12.0, 0.0), Vector3(-57.0, 0.0, 0.0),
		Vector3(-57.0, 12.0, 0.0), Vector3(-57.0, 24.0, 0.0), Vector3(-57.0, 36.0, 0.0),
		Vector3(-57.0, 48.0, 0.0), Vector3(-57.0, 60.0, 0.0),
		Vector3(-3.0, -37.3, 0.0), Vector3(-3.0, 53.0, 0.0),
	]
	var headings: Array[float] = [-90.0, -90.0, -90.0, -90.0, -90.0, -90.0, -90.0, -90.0, 0.0, -180.0]
	var roster: Array = [
		["b", "Bloodsucker", "b", 6.17],
		["dt", "Double Talker", "a", 5.63],
		["ac", "Ambulance Chaser", "b", 6.39],
		["bs", "Back Stabber", "a", 6.71],
		["sd", "Spin Doctor", "b", 7.9],
		["le", "Legal Eagle", "a", 8.27],
		["bw", "Big Wig", "a", 8.69],
	]
	var used := mini(count, seats.size())
	for index in used:
		var pick: Array = roster[randi() % roster.size()]
		var seat: Vector3 = seats[index]
		var node := _spawn_lawyer(pick, seat, headings[index], index)
		var book := _lawyer_book(seat, index)
		_lawyers.append({
			"stun": 0.0,
			"node": node,
			"seat": seat,
			"book": book,
			"phase": "idle",
			"kind": "",
			"t": 0.0,
			"cut": false,
			"hit": false,
			"from": seat,
			"to": seat,
		})


func _spawn_lawyer(pick: Array, seat: Vector3, heading: float, index: int) -> Node3D:
	var script := load("res://scenes/cogs/street_cog.gd") as GDScript
	var cog := script.new() as Node3D
	cog.name = "Lawyer%d" % index
	_root.add_child(cog)
	cog.call("present", {
		"code": str(pick[0]),
		"name": str(pick[1]),
		"dept": "l",
		"body": str(pick[2]),
		"height": float(pick[3]),
		"level": 1,
	}, _read_suit_timing())
	cog.position = seat
	cog.basis = _panda_hpr(heading, 0.0, 0.0)
	return cog


func _read_suit_timing() -> Dictionary:
	if _suit_timing_ready:
		return _suit_timing
	_suit_timing_ready = true
	var text := FileAccess.get_file_as_string("res://assets/cogs/catalog.json")
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_suit_timing = (parsed as Dictionary).get("timing", {})
	return _suit_timing


func _tick_lawyer_throws(delta: float, body: CharacterBody3D) -> void:
	var wave := int(_clock / 6.0)
	var previous := int((_clock - delta) / 6.0)
	var launch := wave != previous and wave > 0
	var geom := _geometry()
	for index in _lawyers.size():
		var lawyer: Dictionary = _lawyers[index]
		var node := lawyer["node"] as Node3D
		var book := lawyer["book"] as Node3D
		var stun := float(lawyer["stun"])
		var phase := String(lawyer["phase"])
		if stun > 0.0 and phase == "wind":
			lawyer["phase"] = "idle"
			lawyer["cut"] = true
			if book != null:
				book.visible = false
			if node != null:
				node.set_process(true)
			continue
		if phase == "idle":
			if launch and stun <= 0.0:
				_begin_lawyer_throw(index, body)
			continue
		lawyer["t"] = float(lawyer["t"]) + delta
		var elapsed := float(lawyer["t"])
		if node != null and node.has_method("play_attack"):
			node.set_process(false)
			node.call("play_attack", "throw-paper", elapsed)
		if phase == "wind":
			if book != null and node != null:
				book.visible = elapsed >= 1.0
				book.global_position = node.global_position + Vector3(0.0, 3.2, 0.0)
			if elapsed < 3.15:
				continue
			if bool(lawyer["cut"]) or stun > 0.0:
				lawyer["phase"] = "idle"
				if book != null:
					book.visible = false
				if node != null:
					node.set_process(true)
				continue
			lawyer["phase"] = "fly"
			lawyer["t"] = 0.0
			_aim_lawyer_book(index, body, geom)
			continue
		var span := 3.0 if String(lawyer["kind"]) == "attack" else 2.5
		var from_at: Vector3 = lawyer["from"]
		var to_at: Vector3 = lawyer["to"]
		if book != null:
			book.position = from_at.lerp(to_at, clampf(elapsed / span, 0.0, 1.0))
			book.visible = true
			if String(lawyer["kind"]) == "attack" and not bool(lawyer["hit"]) and body != null:
				if book.global_position.distance_to(body.global_position + Vector3(0.0, 1.2, 0.0)) < 1.6:
					lawyer["hit"] = true
					_boss.call("note_lawyer_hit")
					if _mode != "evidence":
						return
		if elapsed < span:
			continue
		if String(lawyer["kind"]) == "prosecute" and not bool(lawyer["cut"]):
			_boss.call("heal_scale", 2)
			if _mode != "evidence":
				return
		lawyer["phase"] = "idle"
		lawyer["cut"] = false
		if book != null:
			book.visible = false
		if node != null:
			node.set_process(true)


func _begin_lawyer_throw(index: int, body: CharacterBody3D) -> void:
	var lawyer: Dictionary = _lawyers[index]
	var attack := body != null and randi_range(1, 100) <= 50
	lawyer["kind"] = "attack" if attack else "prosecute"
	lawyer["phase"] = "wind"
	lawyer["t"] = 0.0
	lawyer["cut"] = false
	lawyer["hit"] = false
	var node := lawyer["node"] as Node3D
	if node != null:
		node.set_process(false)


func _aim_lawyer_book(index: int, body: CharacterBody3D, geom: Node3D) -> void:
	var lawyer: Dictionary = _lawyers[index]
	var seat: Vector3 = lawyer["seat"]
	var from_at := seat + Vector3(0.0, 0.0, 3.2)
	var book := lawyer["book"] as Node3D
	if book != null and geom != null:
		from_at = geom.to_local(book.global_position)
	var dest := from_at
	if String(lawyer["kind"]) == "attack" and body != null and geom != null:
		var toon := geom.to_local(body.global_position)
		var flat := Vector3(toon.x - seat.x, toon.y - seat.y, 0.0)
		if flat.length() > 0.1:
			flat = flat.normalized() * 200.0
		dest = Vector3(seat.x + flat.x, seat.y + flat.y, seat.z + 1.3)
	else:
		var pan := _root.find_child("prosecutionPan", true, false) as Node3D
		if pan != null and geom != null:
			dest = geom.to_local(pan.global_position)
		else:
			dest = Vector3(-11.4, 12.0, 19.0)
	lawyer["from"] = from_at
	lawyer["to"] = dest


func _place_gavels(count: int) -> void:
	# LawbotBossGavelPosHprs, LawbotBossGavelTimes, LawbotBossGavelHeadings.
	var seats: Array[Vector3] = [
		Vector3(35.0, 78.328, 0.0), Vector3(68.5, 78.328, 0.0), Vector3(47.0, -33.0, 0.0),
		Vector3(-50.0, -39.0, 0.0), Vector3(-9.0, -37.0, 0.0), Vector3(-9.0, 49.0, 0.0),
		Vector3(32.0, 0.0, 0.0), Vector3(33.0, 56.0, 0.0),
	]
	var headings: Array[float] = [-135.0, 135.0, 45.0, -45.0, 0.0, -180.0, 45.0, 135.0]
	var times: Array = [
		[0.2, 0.9, 0.6], [0.25, 1.0, 0.5], [1.0, 6.0, 0.5], [0.3, 3.0, 1.0],
		[0.26, 0.9, 0.45], [0.24, 1.1, 0.65], [0.27, 1.2, 0.45], [0.25, 0.95, 0.5],
	]
	var sweeps: Array = [
		[0.0, -15.0, 4.0, -115.0, 5.0, 45.0],
		[0.0, -45.0, -4.0, -35.0, -45.0, -16.0, 32.0],
		[0.0, -8.0, 19.0, -7.0, 5.0, 23.0],
		[0.0, -4.0, 8.0, -16.0, 32.0, -45.0, 7.0, 7.0, -30.0, 19.0, -13.0, 25.0],
		[0.0, -45.0, -90.0, 45.0, 90.0],
		[0.0, -45.0, -90.0, 45.0, 90.0],
		[0.0, -45.0, 45.0],
		[0.0, -45.0, 45.0],
	]
	var used := mini(count, seats.size())
	for index in used:
		var node := _model_or_box("res://assets/cog_hq/lawbot_gavel.glb", seats[index], "Gavel%d" % index, Color(0.7, 0.1, 0.1), Vector3(1.2, 4.0, 1.2))
		node.scale = Vector3(3.0, 3.0, 3.0)
		_gavels.append({
			"node": node,
			"heading": headings[index],
			"down": float(times[index][0]),
			"up": float(times[index][1]),
			"stay": float(times[index][2]),
			"sweep": sweeps[index],
			"step": 0,
			"phase": "down",
			"t": 0.0,
			"struck": false,
		})


func _tilt_scale(damage: float) -> void:
	# makeScaleReflectDamage. Winning tilt is 40 at 2700. Zero is level at 1350.
	var scale := _root.get_node_or_null("Scale") as Node3D
	if scale == null:
		return
	var beam := scale.find_child("scaleBeam", true, false) as Node3D
	if beam == null:
		return
	var tilt := (damage - 1350.0) / 1350.0 * 40.0
	beam.rotation.x = deg_to_rad(tilt)
	var defense_pan := scale.find_child("defensePan", true, false) as Node3D
	var prosecution_pan := scale.find_child("prosecutionPan", true, false) as Node3D
	if defense_pan != null:
		defense_pan.rotation.x = deg_to_rad(-tilt)
	if prosecution_pan != null:
		prosecution_pan.rotation.x = deg_to_rad(-tilt)


func _swing_gavels(delta: float, body: CharacterBody3D) -> void:
	for gavel in _gavels:
		var node := gavel["node"] as Node3D
		var sweep: Array = gavel["sweep"]
		if node == null or sweep.is_empty():
			continue
		var step := int(gavel["step"]) % sweep.size()
		var nxt := (step + 1) % sweep.size()
		var base := float(gavel["heading"])
		var here := base + float(sweep[step])
		var there := base + float(sweep[nxt])
		var phase := String(gavel["phase"])
		var span := float(gavel[phase])
		gavel["t"] = float(gavel["t"]) + delta
		var along := clampf(float(gavel["t"]) / maxf(span, 0.05), 0.0, 1.0)
		var pitch := -80.0
		var heading := here
		if phase == "down":
			pitch = lerpf(0.0, -80.0, along)
		elif phase == "up":
			pitch = lerpf(-80.0, 0.0, along)
			heading = lerpf(here, there, along)
		node.basis = _panda_hpr(heading, pitch, 0.0).scaled(Vector3(3.0, 3.0, 3.0))
		if phase == "stay" and not bool(gavel["struck"]):
			var chest := body.global_position + Vector3(0.0, 1.2, 0.0)
			var head := _exact_child(node, "top1")
			var grip := _exact_child(node, "handle")
			var stomp := head != null and head.global_position.distance_to(chest) < 4.5
			var graze := grip != null and grip.global_position.distance_to(chest) < 3.2
			if stomp or graze:
				gavel["struck"] = true
				_boss.call("note_gavel", stomp)
		if not _cj_driving() and ToonNet.networked():
			continue
		if float(gavel["t"]) < span:
			continue
		gavel["t"] = 0.0
		gavel["struck"] = false
		if phase == "down":
			gavel["phase"] = "stay"
			_sfx("res://assets/cog_hq/audio/LB_gavel.ogg")
		elif phase == "stay":
			gavel["phase"] = "up"
		else:
			gavel["phase"] = "down"
			gavel["step"] = nxt


func _tick_banquet(delta: float, body: CharacterBody3D) -> void:
	_boss.call("tick_banquet", delta)
	if String(_boss.call("current_phase")) != "banquet":
		return
	_tick_belt(delta, body, false)
	_follow_plate(body)
	_publish_ceo_field(delta)
	var state: Dictionary = _boss.call("world_state")
	var rows: Array = state.get("diners", [])
	for slot in _diners.size():
		var diner: Dictionary = _diners[slot]
		var index := int(diner.get("index", -1))
		if index < 0 or index >= rows.size() or not (rows[index] is Dictionary):
			continue
		var row: Dictionary = rows[index]
		var status := String(row.get("status", ""))
		var node := diner.get("node") as Node3D
		_pose_diner(diner, row, delta)
		_diners[slot] = diner
		var glow := status == "hungry" or status == "angry"
		if _carry and glow and node != null and _near(body, node.global_position, 2.2):
			_carry = false
			_boss.call("serve_seat", index)
	var carrying := "carrying a plate" if _carry else "empty handed"
	_boss.call("paint_world", "Banquet %s. Grab a can, then serve a hungry cog." % carrying)


func _tick_ceo_attack(delta: float, body: CharacterBody3D, slowed: float) -> void:
	var gap := 6.0 * (1.0 + slowed / 90.0)
	if _attack_left > 0.0:
		_attack_left -= delta
		if _attack_left <= 0.0 and _near(body, _attack_at, 4.0):
			_boss.call("note_golf", _attack_kind == "area")
	elif _fore_phase == 0 and not _crushing and _clock > 4.0 and (_attack_now or fposmod(_clock, gap) < delta):
		_attack_now = false
		var table := _mounted_table()
		if table >= 0 and not _table_is_flat(table) and randi() % 4 == 0:
			_start_crush(table)
		elif randi() % 5 == 0:
			_start_fore(body)
		elif table >= 0:
			_throw_gears(body.global_position, "gear")
		else:
			var pick := _upright_table()
			if pick >= 0 and randi() % 4 == 0:
				_start_crush(pick)
			else:
				_throw_balls(body.global_position)
	if _clock >= 1200.0 and not _over_one:
		_over_one = true
		_tell("It's time to reorganize.")
		_throw_gears(_belt_point(0), "overtime")
	if _clock >= 1800.0 and not _over_two:
		_over_two = true
		_tell("Now let's downsize.")
		_throw_gears(_belt_point(1), "overtime")
	_tick_ceo_shots(delta, body)


func _tick_seltzer(delta: float, body: CharacterBody3D) -> void:
	_tick_chest(delta)
	_tick_belt(delta, body, true)
	_tick_balls(delta)
	if not _KEYS.use_held():
		_station_arm = false
	if not _golf:
		_mount_station(body)
	elif _swing_age < 0.0 and _KEYS.use_held() and not _station_arm and _cool <= 0.0 and not _KEYS.held("jump"):
		_golf = false
		_spray = 0.0
		_station_arm = true
		_cool = 0.3
		_hide_putter()
		_release_board(body)
		_free_toon()
	elif _station == "bottle":
		_tick_board(delta, body)
		if _board_age >= _board_span:
			_aim_station(delta, 30.0)
		if _KEYS.held("jump"):
			_spray += delta
		elif _spray > 0.0:
			_fire_bottle(_water_power(_spray))
			_spray = 0.0
	elif _station == "tee":
		_tick_board(delta, body)
		if _board_age >= _board_span and _swing_age < 0.0:
			_aim_station(delta, 20.0)
		if _swing_age >= 0.0:
			pass
		elif _KEYS.held("jump"):
			_spray += delta
		elif _spray > 0.0 and _cool <= 0.0 and _board_age >= _board_span:
			_begin_swing(_ball_power(_spray))
			_spray = 0.0
	var state: Dictionary = _boss.call("world_state")
	var slowed := float(state.get("speed", 0.0))
	_tint_ceo_treads(slowed)
	var driving := ToonNet.ceo_driving()
	if driving:
		_tick_ceo_attack(delta, body, slowed)
		_tick_crush(delta, slowed)
		_tick_unflatten()
	else:
		_apply_flats()
		_apply_attacks()
		_tick_ceo_shots(delta, body)
	_tick_fore(delta)
	_tick_zap(delta, body)
	_advance_ceo_pose(delta)
	_tick_face(delta)
	_tick_water(delta)
	_tint_club()
	_show_power(_golf and _KEYS.held("jump"))
	_publish_ceo_field(delta)
	_publish_seat()
	var charge := "Slow %d." % int(slowed)
	if _golf and _station == "bottle":
		charge = "Bottle %d." % int(round(_water_power(_spray) * 100.0))
	elif _golf and _station == "tee":
		charge = "Golf %d. Slow %d." % [int(round(_ball_power(_spray))), int(slowed)]
	_boss.call("paint_world", charge)


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
	_gavels.clear()
	_flying = false
	_cannon_pad = null
	_crane = -1
	_held = -1
	_cannon = false
	_carry = false
	_food.clear()
	_diners.clear()
	_balls.clear()
	_station_index = -1
	_station_table = -1
	_station_arm = false
	_crushing = false
	_crush_table = -1
	_crush_rider = false
	_attack_now = false
	_face_return = -1.0
	_ceo_left_u = 0.0
	_ceo_right_u = 0.0
	_ceo_left_mat = null
	_ceo_right_mat = null
	_over_one = false
	_over_two = false
	_ceo_shots.clear()
	_ceo_clip = ""
	_ceo_time = 0.0
	_ceo_next = ""
	_ceo_raised = false
	_ceo_banks.clear()
	_ceo_rates.clear()
	_ceo_frames.clear()
	_gil_job = ""
	_door_span = 0.0
	_face_span = 0.0
	_hide_putter()
	for spray in _water:
		var mesh := spray.get("mesh") as Node
		if mesh != null:
			mesh.queue_free()
	_water.clear()
	_flat_return = -1
	_epilogue_on = false
	_strip_at = -1.0
	_eyes_back = -1.0
	_threat_dusted = false
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
	# The banquet file turns panda (x, y, z) into Godot (x, z, -y) on its inner
	# root. Parenting the round there keeps the intro camera on the floor.
	var room := geom
	if geom != null:
		var converted := geom.get_node_or_null("BossbotCeo") as Node3D
		if converted != null:
			room = converted
	if room != null:
		room.add_child(_root)
	elif host != null:
		host.add_child(_root)


func _launch(body: CharacterBody3D, speed: float, color: Color, kind: String) -> void:
	if _cool > 0.0:
		return
	var camera := _camera()
	var aim := -camera.global_basis.z if camera != null else _forward
	var book := Vector3(0.55, 0.12, 0.4) if kind == "evidence" else Vector3(0.35, 0.35, 0.35)
	var mesh := _evidence_prop(body.global_position + Vector3(0, 1.4, 0)) if kind == "evidence" else _box(body.global_position + Vector3(0, 1.4, 0), color, book, "Shot%d" % (_pies.size() + _shots.size()))
	var shot := {"at": body.global_position + Vector3(0, 1.4, 0), "vel": aim.normalized() * speed + Vector3(0, 4.0, 0), "done": false, "kind": kind, "mesh": mesh}
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


func _place_battle_cannons() -> void:
	_cannon_pads.clear()
	# One cannon per toon, spaced from LawbotBossCannonPosA to CannonPosB.
	var start := Vector3(-80.0, -51.48, 0.0)
	var finish := Vector3(-80.0, 70.73, 0.0)
	var count := _court_toons()
	for index in count:
		var at := start + (finish - start) * (float(index + 1) / float(count + 1))
		var pad := _model_or_box("res://assets/minigames/toon_cannon.glb", at, "Cannon%d" % index, Color(0.45, 0.3, 0.15), Vector3(1.6, 1.2, 2.2))
		pad.basis = _panda_hpr(-90.0, 0.0, 0.0)
		pad.scale = Vector3(0.1, 0.1, 0.1)
		pad.visible = false
		_cannon_pads.append(pad)
		_cannon_pad = pad


func _court_toons() -> int:
	var count := 1
	var host := _boss.get_parent() if _boss != null else null
	if host == null:
		return 1
	for node in host.find_children("", "ToonActor", true, false):
		if node.has_meta("peer"):
			count += 1
	return mini(count, 8)


func _aim_cannon() -> void:
	if _cannon_pad == null:
		return
	_cannon_pad.basis = _panda_hpr(-90.0 + _crane_h, 0.0, 0.0)
	var barrel := _exact_child(_cannon_pad, "cannon")
	if barrel != null:
		barrel.rotation = Vector3(deg_to_rad(_barrel_p), 0.0, 0.0)


func _exact_child(node: Node, want: String) -> Node3D:
	if node == null:
		return null
	for child in node.get_children():
		if String(child.name) == want and child is Node3D:
			return child as Node3D
		var deeper := _exact_child(child, want)
		if deeper != null:
			return deeper
	return null


func _launch_flight(body: CharacterBody3D) -> void:
	if body == null or not bool(_boss.call("note_shot")):
		return
	var geom := _geometry()
	if geom == null:
		return
	var barrel := _exact_child(_cannon_pad, "cannon")
	var muzzle := body.global_position + Vector3(0.0, 2.0, 0.0)
	if barrel != null:
		muzzle = barrel.to_global(Vector3(0.0, 6.0, 0.0))
	_fly_from = geom.to_local(muzzle)
	var heading := deg_to_rad(-90.0 + _crane_h)
	var angle := deg_to_rad(_barrel_p)
	var horiz := 80.0 * cos(angle)
	_fly_vel = Vector3(horiz * -sin(heading), horiz * cos(heading), 80.0 * sin(angle))
	_fly_time = 0.0
	_flying = true
	_sfx("res://assets/audio/sfx/MG_cannon_fire_alt.ogg")


func _tick_flight(delta: float, body: CharacterBody3D) -> void:
	if body == null:
		_flying = false
		return
	var geom := _geometry()
	if geom == null:
		return
	_fly_time += delta
	var pos := _fly_from + _fly_vel * _fly_time + Vector3(0.0, 0.0, -16.0 * _fly_time * _fly_time)
	body.global_position = geom.to_global(pos)
	body.velocity = Vector3.ZERO
	_ride_camera(body, geom.to_global(pos + _fly_vel))
	for index in _chairs.size():
		var seat := _chairs[index]["node"] as Node3D
		if seat != null and seat.global_position.distance_to(body.global_position) < 3.5:
			_land_cannon(body, index)
			return
	if _fly_time > 0.15 and pos.z <= 0.3:
		_land_cannon(body, -1)


func _land_cannon(body: CharacterBody3D, chair_index: int) -> void:
	_flying = false
	_cannon = false
	_cool = 0.4
	if chair_index >= 0:
		_seat_toon(chair_index)
	if _cannon_pad != null:
		body.global_position = _cannon_pad.to_global(Vector3(3.0, 0.0, 0.0))
	body.velocity = Vector3.ZERO
	_free_toon()
	_sfx("res://assets/audio/sfx/MG_cannon_hit_dirt.ogg")
	if _clock >= 70.0 and _cj_driving():
		_end_cannons()


func _end_cannons() -> void:
	_flying = false
	_cannon = false
	_free_toon()
	if _jury_loop != null and is_instance_valid(_jury_loop):
		_jury_loop.stop()
	_boss.call("set_jurors", _toon_jurors())
	_boss.call("finish_cannons")


func _place_chairs() -> void:
	_claims.clear()
	if _jury == null:
		return
	var front_a := Vector3(59.3, -18.2, 14.05)
	var front_b := Vector3(59.3, 48.0, 14.05)
	var back_a := Vector3(75.1, -18.2, 28.2)
	var back_b := Vector3(75.1, 48.0, 28.2)
	for index in 12:
		var row := front_a.lerp(front_b, float(index) / 5.0) if index < 6 else back_a.lerp(back_b, float(index - 6) / 5.0)
		var chair := Node3D.new()
		chair.name = "CjChair%d" % index
		_jury.add_child(chair)
		chair.position = row - _jury_baked
		chair.basis = _panda_hpr(-90.0, 0.0, 0.0)
		var cushion := _box(Vector3.ZERO, Color(0.85, 0.75, 0.35), Vector3(0.7, 0.08, 0.7), "Cushion")
		chair.add_child(cushion)
		cushion.position = Vector3(0.0, 0.0, 0.9)
		var seat_model := _model_or_box("res://assets/cog_hq/jury_chair.glb", Vector3.ZERO, "ChairModel", Color(0.45, 0.32, 0.18), Vector3(1.2, 0.8, 1.2))
		chair.add_child(seat_model)
		seat_model.position = Vector3.ZERO
		seat_model.scale = Vector3(0.5, 0.5, 0.5)
		var cog := _juror_cog()
		chair.add_child(cog)
		cog.visible = false
		var prop := _propeller()
		cog.add_child(prop)
		prop.position = Vector3(0.0, 1.6, 0.0)
		prop.visible = false
		_chairs.append({
			"node": chair,
			"cog": cog,
			"prop": prop,
			"state": "empty",
			"due": randf_range(1.0, 20.0),
			"fly": 0.0,
		})


func _juror_cog() -> Node3D:
	var packed := load("res://assets/cogs/suits/bf.glb") as PackedScene
	if packed != null:
		var cog := packed.instantiate() as Node3D
		cog.name = "JurorCog"
		return cog
	return _box(Vector3.ZERO, Color(0.45, 0.15, 0.15), Vector3(0.8, 1.6, 0.8), "JurorCog")


func _tick_chairs(delta: float) -> void:
	_take_remote_seats()
	for chair in _chairs:
		var state := String(chair["state"])
		var cog := chair["cog"] as Node3D
		if _cj_driving() and (state == "empty" or state == "toon") and _clock >= float(chair["due"]):
			chair["state"] = "fly"
			chair["fly"] = 0.0
			state = "fly"
		if state == "toon":
			var juror := chair.get("juror") as ToonActor
			if juror != null:
				juror.visible = true
				juror.pose_synced_loop("sit")
		if state == "fly":
			if cog != null:
				cog.visible = true
			if not bool(chair.get("spun", false)):
				chair["spun"] = true
				_sfx("res://assets/cog_hq/audio/ENC_propeller_in.ogg")
			var prop := chair.get("prop") as Node3D
			if prop != null:
				prop.visible = true
				prop.rotate_y(delta * 24.0)
			if _cj_driving():
				chair["fly"] = float(chair["fly"]) + delta
			var frac := clampf(float(chair["fly"]) / 10.0, 0.0, 1.0)
			var seat := chair["node"] as Node3D
			var height := 16.0
			if seat != null and _jury != null:
				height = maxf(30.0 - (_jury.position.z + seat.position.z), 2.0)
			if cog != null:
				cog.position = Vector3(0.0, -75.0, height).lerp(Vector3(0.0, -1.25, 0.95), frac)
			if frac >= 1.0 and _cj_driving():
				chair["state"] = "cog"
				state = "cog"
				if cog != null:
					cog.position = Vector3(0.0, -1.25, 0.95)
				var prop_done := chair.get("prop") as Node3D
				if prop_done != null:
					prop_done.visible = false
				var seated := chair.get("juror") as Node3D
				if seated != null:
					seated.visible = false
		if state == "cog":
			if cog != null:
				cog.visible = true
				cog.position = Vector3(0.0, -1.25, 0.95)
			var parked := chair.get("prop") as Node3D
			if parked != null:
				parked.visible = false
			if bool(chair.get("spun", false)):
				chair["spun"] = false
				_sfx("res://assets/cog_hq/audio/LB_cog_jury.ogg")
				_sfx("res://assets/cog_hq/audio/ENC_propeller_out.ogg")
		var cushion := (chair["node"] as Node3D).get_node_or_null("Cushion") as MeshInstance3D
		if cushion != null and cushion.material_override is StandardMaterial3D:
			var paint := cushion.material_override as StandardMaterial3D
			var shown := String(chair["state"])
			if shown == "toon":
				paint.albedo_color = Color(0.25, 0.35, 0.9)
			elif shown == "cog":
				paint.albedo_color = Color(0.45, 0.45, 0.45)
			else:
				paint.albedo_color = Color(0.85, 0.75, 0.35)
	_boss.call("set_jurors", _toon_jurors())


func _seat_toon(index: int, announce := true) -> void:
	if index < 0 or index >= _chairs.size():
		return
	var state := String(_chairs[index]["state"])
	if not announce and state != "empty":
		return
	if state == "cog":
		_boss.call("set_round_text", "That chair already has a cog.")
		return
	if state == "fly":
		_boss.call("set_round_text", "You reached the chair, but a cog is already flying in.")
		return
	_chairs[index]["state"] = "toon"
	_chairs[index]["due"] = _clock + randf_range(9.0, 19.0)
	if not _claims.has(index):
		_claims.append(index)
	_seat_juror(index)
	_sfx("res://assets/cog_hq/audio/LB_toon_jury.ogg")
	_boss.call("set_jurors", _toon_jurors())
	if announce:
		_boss.call("set_round_text", "You seated a Toon. A cog will come for that chair.")


func _toon_jurors() -> int:
	var count := 0
	for chair in _chairs:
		if String(chair["state"]) == "toon":
			count += 1
	return count


func _restore_jury() -> void:
	for chair in _chairs:
		var seat := chair["node"] as Node
		if seat != null and is_instance_valid(seat):
			seat.queue_free()
	_chairs.clear()
	if _jury != null and is_instance_valid(_jury):
		_jury.position = _jury_baked
	if _reflect != null and is_instance_valid(_reflect):
		_reflect.position = _reflect_baked
	_jury = null
	_reflect = null


func start_cj_intro(boss: Node) -> void:
	_begin(boss)
	_mode = "cj_intro"
	_intro_at = 0
	_intro_wait = 0.0
	_place_cj(Vector3(-2.798, -60.0, 0.0), 0.0)
	_head_talk = 3.4
	_place_witness()
	settle_cj_court()
	_boss.call("set_round_text", "Hmmm what's on the docket today?")


func skip_cj_intro() -> void:
	_mode = ""
	if _boss != null:
		_boss.call("finish_cj_intro")


func _tick_cj_intro(delta: float) -> void:
	var lines: PackedStringArray = PackedStringArray([
		"Hmmm what's on the docket today?",
		"Aha, we have a Toon on trial!",
		"The prosecution's case is strong.",
		"And here are the public defenders.",
		"Wait a minute... You're Toons!",
	])
	_intro_wait += delta
	_pose_cj_head(delta)
	if _intro_wait < 3.4:
		return
	_intro_wait = 0.0
	_intro_at += 1
	_head_talk = 3.4
	if _intro_at >= lines.size():
		_mode = ""
		_boss.call("finish_cj_intro")
		return
	_boss.call("set_round_text", lines[_intro_at])


func start_cj_defeat(boss: Node) -> void:
	_boss = boss
	_mode = "cj_defeat"
	_defeat_left = 4.0
	_head_back = true
	_head_talk = 4.0
	_boss.call("set_round_text", "I find in favor of the plaintiff")


func _tick_cj_defeat(delta: float) -> void:
	_defeat_left -= delta
	_pose_cj_head(delta)
	if _defeat_left <= 0.0 and _boss != null:
		_mode = ""
		_boss.call("finish_cj_defeat")


func _tick_cj_act(delta: float) -> void:
	_act_t += delta
	_pose_cj_head(delta)
	if _mode == "cj_pass":
		if _act_t >= 5.0:
			_start_cj_roll()
		return
	if _mode == "cj_roll":
		var along := clampf(_act_t / maxf(_roll_span, 0.1), 0.0, 1.0)
		if _cj != null:
			_cj.position = _cj_from.lerp(_cj_to, along)
		_scroll_treads(delta)
		if along >= 1.0:
			_mode = "cj_rise"
			_act_t = 0.0
		return
	if _mode == "cj_rise":
		var lift := clampf(_act_t / 5.0, 0.0, 1.0)
		if _podium != null:
			_podium.position.z = lerpf(_podium_base - 19.145, _podium_base, lift)
		if _refl_podium != null:
			_refl_podium.position.z = lerpf(_refl_base, _refl_base + 19.145, lift)
		if lift >= 1.0:
			_start_cannon_pages()
		return
	if _mode == "cj_session":
		_aim_session_camera()
		if _act_t >= 3.0:
			_start_evidence_pages()
		return
	if _mode == "cj_pages":
		_aim_witness_camera()
		_tick_pages()
		return
	if _mode == "cj_appear":
		_toss_cannons(delta)
		return
	if _mode == "cj_victory":
		_tick_cj_victory(delta)
		return
	if _mode == "cj_epilogue":
		_aim_witness_camera()
		_tick_pages()


func _start_cj_roll() -> void:
	_mode = "cj_roll"
	_act_t = 0.0
	_head_talk = 4.0
	_cj_from = Vector3(-2.798, -60.0, 0.0)
	_cj_to = Vector3(-2.798, 89.0, 19.145)
	_roll_span = maxf(_cj_from.distance_to(_cj_to) / 7.5, 0.1)
	_sfx("res://assets/cog_hq/audio/CHQ_VP_ramp_slide.ogg")
	_tell("Jury selection will now commence.")


func _start_cannon_pages() -> void:
	_show_witness(true)
	_pages = PackedStringArray([
		"Oh no! They're putting only Cogs on the jury!",
		"Quick, use the cannons and shoot some Toon jurors into the jury chairs.",
		"We need 8 to get a balanced scale.",
	])
	_page = 0
	_page_next = "appear"
	_mode = "cj_pages"
	_act_t = 0.0
	play_music("battle3")
	_tell(_pages[0])


func _start_evidence_pages() -> void:
	var state: Dictionary = _boss.call("world_state")
	var jurors := int(state.get("jurors", 0))
	var first := "Cool! There are %d Toons in the jury!" % jurors
	if jurors <= 0:
		first = "Oh oh, no Toon jurors. This will be a tough trial."
	elif jurors == 1:
		first = "Cool! There is 1 Toon in the jury!"
	elif jurors >= 12:
		first = "Awesome! All the jurors are Toons!"
	_pages = PackedStringArray([
		first,
		"Hurry, touch the witness stand to get evidence.",
		"Press the Delete key to throw the evidence at the lawyers, or at the defense pan.",
	])
	var bonus := String(_boss.call("cj_bonus_line"))
	if bonus != "":
		_pages.append(bonus)
	_page = 0
	_page_next = "evidence"
	_mode = "cj_pages"
	_act_t = 0.0
	_show_witness(true)
	_tell(_pages[0])


func _tick_pages() -> void:
	if _pages.is_empty():
		_finish_pages()
		return
	if not _fresh_press() and _act_t < 4.5:
		return
	_cool = 0.35
	_page += 1
	_act_t = 0.0
	if _page >= _pages.size():
		_finish_pages()
		return
	_tell(_pages[_page])


func _finish_pages() -> void:
	var next := _page_next
	_page_next = ""
	_pages = PackedStringArray()
	if next == "appear":
		_mode = "cj_appear"
		_act_t = 0.0
		_toss_t = 0.0
		_begin_cannon_toss()
	elif next == "evidence":
		_open_evidence_round()
	elif next == "reward":
		_mode = ""
		_free_toon()
		if _boss != null:
			_boss.call("finish_cj_victory")


func _open_cannon_round() -> void:
	var mine: Node3D = _cannon_pads[0] if not _cannon_pads.is_empty() else _cannon_pad
	for pad in _cannon_pads:
		if pad != null and is_instance_valid(pad):
			if _root != null and pad.get_parent() != _root:
				pad.reparent(_root)
			if pad.has_meta("dest"):
				pad.global_position = pad.get_meta("dest")
			pad.basis = _panda_hpr(-90.0, 0.0, 0.0)
			pad.visible = true
			pad.scale = Vector3.ONE
	if mine != null:
		_cannon_pad = mine
	_mode = "cannon"
	_clock = 0.0
	_free_toon()
	var body := _body()
	if body != null and _cannon_pad != null:
		body.global_position = _cannon_pad.to_global(Vector3(0.0, 8.0, 0.0))
		body.velocity = Vector3.ZERO
	play_music("jury")
	_loop_jury()


func _open_evidence_round() -> void:
	_show_battle_props(true)
	_mode = "evidence"
	_clock = 0.0
	_hint = ""
	_hint_left = 30.0
	_threw = false
	_restocked = false
	_judge_wave = 0
	_area_at = -100.0
	_free_toon()
	play_music("battle3")
	_tell("Hurry, touch the witness stand to get evidence. Press the Delete key to throw the evidence at the lawyers, or at the defense pan.")


func start_cj_victory(boss: Node) -> void:
	_boss = boss
	_mode = "cj_victory"
	_act_t = 0.0
	_line_at = -1
	_lock_toon()
	_court_door = _find("CR3_Door")
	if _court_door != null:
		_court_door_z = _court_door.position.z
	_cj_from = Vector3(-2.798, 89.0, 19.145)
	_cj_to = Vector3(-2.798, 119.0, 19.145)
	_place_cj(_cj_from, 0.0)
	play_music("battle3")


func _tick_cj_victory(delta: float) -> void:
	var cam := _camera()
	var geom := _geometry()
	if cam != null and geom != null:
		var look := geom.to_global(Vector3(-2.8, 89.0, 22.0))
		cam.global_position = geom.to_global(Vector3(-3.0, 45.0, 25.0))
		if cam.global_position.distance_squared_to(look) > 0.04:
			cam.look_at(look, Vector3.UP)
	var spoken := -1
	if _act_t >= 9.6:
		spoken = 2
	elif _act_t >= 5.5:
		spoken = 1
	elif _act_t >= 1.0:
		spoken = 0
	if spoken != _line_at and spoken >= 0:
		_line_at = spoken
		_head_talk = 4.0
		var lines := PackedStringArray([
			"Impossible! The defense won?",
			"No. I declare a mistrial! A new one will be scheduled.",
			"Hrrmpphh. I'll be in my chambers.",
		])
		_tell(lines[spoken])
	if _cj != null and _act_t >= 9.6:
		var roll := clampf((_act_t - 9.6) / 4.0, 0.0, 1.0)
		_cj.position = _cj_from.lerp(_cj_to, roll)
		_scroll_treads(delta)
	if _court_door != null:
		var opened := _act_t - 9.6
		if opened >= 0.0 and opened <= 2.0:
			_court_door.position.z = _court_door_z + 25.0 * (opened / 2.0)
		elif opened >= 3.5 and opened <= 4.5:
			_court_door.position.z = _court_door_z + 25.0 * (1.0 - (opened - 3.5))
		elif opened > 4.5:
			_court_door.position.z = _court_door_z
	if _act_t >= 14.2:
		_begin_cj_epilogue()


func _begin_cj_epilogue() -> void:
	if _court_door != null:
		_court_door.position.z = _court_door_z
	pose_cj_epilogue()
	_pages = PackedStringArray([
		"You did it!  Thank you for a spectacular defense!",
		"Here, take these papers the Chief Justice left behind.",
		"With it you'll be able to summon Cogs from your Cog Gallery page.",
	])
	_page = 0
	_page_next = "reward"
	if _boss != null and _boss.has_method("cj_epilogue_lines"):
		var extra: PackedStringArray = _boss.call("cj_epilogue_lines")
		for line in extra:
			_pages.append(String(line))
	_mode = "cj_epilogue"
	_act_t = 0.0
	play_music("epilogue")
	_tell(_pages[0])


func settle_cj_court() -> void:
	_retract_jury()
	_lower_podium()
	_place_cj(Vector3(-2.798, -60.0, 0.0), 0.0)
	if _witness != null and is_instance_valid(_witness):
		_witness.visible = false


func _retract_jury() -> void:
	_jury = _find("JuryBox")
	_reflect = _find("JuryBox_Geo_Reflect")
	if _jury != null:
		_jury_baked = _jury.position
		_jury.position = _jury_baked - Vector3(30.0, 0.0, 12.645)
		_jury_start = _jury.position
	if _reflect != null:
		_reflect_baked = _reflect.position
		var shifted := _reflect_baked - Vector3(30.0, 0.0, 12.645)
		shifted.z += 12.645
		_reflect.position = shifted
		_reflect_start = _reflect.position


func _lower_podium() -> void:
	if _podium_low:
		return
	_podium = _find("Podium")
	if _podium == null:
		return
	_podium_base = _podium.position.z
	_podium.position.z = _podium_base - 19.145
	_refl_podium = _find("Podium_Geo1_Refl")
	if _refl_podium != null:
		_refl_base = _refl_podium.position.z
	_podium_low = true


func _show_battle_props(shown: bool) -> void:
	if _scale_model != null and is_instance_valid(_scale_model):
		_scale_model.visible = shown
	for gavel in _gavels:
		var gavel_node := gavel["node"] as Node3D
		if gavel_node != null:
			gavel_node.visible = shown
	for lawyer in _lawyers:
		var lawyer_node := lawyer["node"] as Node3D
		if lawyer_node != null:
			lawyer_node.visible = shown


func _aim_witness_camera() -> void:
	if _witness == null or not _witness.visible:
		return
	var cam := _camera()
	if cam == null:
		return
	var look := _witness.to_global(Vector3(0.0, 0.0, 2.0))
	cam.global_position = _witness.to_global(Vector3(0.0, 8.0, 2.0))
	if cam.global_position.distance_squared_to(look) > 0.04:
		cam.look_at(look, Vector3.UP)


func _aim_session_camera() -> void:
	var cam := _camera()
	var geom := _geometry()
	if cam == null or geom == null:
		return
	var look := geom.to_global(Vector3(-2.8, 89.0, 19.0))
	cam.global_position = geom.to_global(Vector3(-15.0, 15.0, 20.0))
	if cam.global_position.distance_squared_to(look) > 0.04:
		cam.look_at(look, Vector3.UP)


func _near_prosecution(at: Vector3) -> bool:
	if _root == null:
		return false
	var pan := _root.find_child("Prosecution", true, false) as Node3D
	return pan != null and _near_point(at, pan.global_position, 2.4)


func _tint(root: Node3D, color: Color) -> void:
	if root == null:
		return
	if _tint_root != null and is_instance_valid(_tint_root) and _tint_root != root:
		_apply_overlay(_tint_root, null)
	_tint_root = root
	_tint_left = 0.4
	if _tint_mat == null:
		_tint_mat = StandardMaterial3D.new()
		_tint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tint_mat.albedo_color = color
	_apply_overlay(root, _tint_mat)


func _tick_tint(delta: float) -> void:
	if _tint_left <= 0.0:
		return
	_tint_left -= delta
	if _tint_left <= 0.0 and _tint_root != null and is_instance_valid(_tint_root):
		_apply_overlay(_tint_root, null)
		_tint_root = null


func _apply_overlay(root: Node, mat: Material) -> void:
	if root is GeometryInstance3D:
		(root as GeometryInstance3D).material_overlay = mat
	for child in root.get_children():
		_apply_overlay(child, mat)


func _lawyer_book(seat: Vector3, index: int) -> Node3D:
	var path := "res://assets/cog_hq/lawbook.glb"
	var book := _model_or_box(path, seat, "EvidenceBook%d" % index, Color(0.45, 0.28, 0.12), Vector3(0.45, 0.2, 0.55))
	if ResourceLoader.exists(path):
		book.scale = Vector3(0.45, 0.45, 0.45)
	book.visible = false
	return book


func _evidence_prop(at: Vector3) -> Node3D:
	var prop := _model_or_box("res://assets/cog_hq/lawbook.glb", Vector3.ZERO, "Lawbook%d" % _shots.size(), Color(0.45, 0.28, 0.12), Vector3(0.55, 0.12, 0.4))
	prop.global_position = at
	prop.scale = Vector3(0.45, 0.45, 0.45)
	return prop


func _cannon_adjust(moving: bool) -> void:
	if not moving:
		if _cannon_move != null and is_instance_valid(_cannon_move):
			_cannon_move.stop()
		return
	if _cannon_move == null or not is_instance_valid(_cannon_move):
		var stream := load("res://assets/audio/sfx/MG_cannon_adjust.ogg") as AudioStream
		if stream == null:
			return
		var copy := stream.duplicate() as AudioStream
		if copy != null:
			stream = copy
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		_cannon_move = AudioStreamPlayer.new()
		_cannon_move.stream = stream
		_cannon_move.volume_db = -8.0
		add_child(_cannon_move)
	if not _cannon_move.playing:
		_cannon_move.play()


func _scroll_treads(delta: float) -> void:
	var treads := _exact_child(_cj, "treads")
	if treads == null:
		return
	_tread_u += delta * 3.5
	_scroll_uv(treads)


func _scroll_uv(node: Node) -> void:
	_scroll_surface(node, _tread_u)


func _scroll_surface(node: Node, amount: float) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var mat := mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat == null:
			var active := mesh.get_active_material(0)
			if active is StandardMaterial3D:
				mat = (active as StandardMaterial3D).duplicate() as StandardMaterial3D
				mesh.set_surface_override_material(0, mat)
		if mat != null:
			mat.uv1_offset.x = amount
	for child in node.get_children():
		_scroll_surface(child, amount)


func _pose_cj_head(delta: float) -> void:
	var head := _exact_child(_cj, "bossCog-head")
	if head == null:
		head = _exact_child(_cj, "head")
	if head == null:
		return
	if not head.has_meta("rest"):
		head.set_meta("rest", head.basis)
	_head_talk = maxf(_head_talk - delta, 0.0)
	var pitch := PI if _head_back else 0.0
	if _head_talk > 0.0:
		pitch += sin(_head_talk * 14.0) * 0.18
	var rest: Basis = head.get_meta("rest")
	head.basis = rest * Basis(Vector3.RIGHT, pitch)


func _local_actor() -> ToonActor:
	if _boss == null:
		return null
	var host := _boss.get_parent()
	var toon := host.get_node_or_null("PlaygroundToon") if host != null else null
	if toon != null and toon.has_method("battle_actor"):
		return toon.call("battle_actor") as ToonActor
	return null


func _begin_cannon_toss() -> void:
	var holders: Array[Node3D] = []
	var mine := _local_actor()
	if mine != null:
		holders.append(mine)
	for actor in _remote_actors():
		holders.append(actor)
	for index in _cannon_pads.size():
		var pad := _cannon_pads[index]
		if pad == null:
			continue
		pad.visible = true
		pad.scale = Vector3(0.1, 0.1, 0.1)
		pad.set_meta("dest", pad.global_position)
		var holder: Node3D = holders[index] if index < holders.size() else null
		var hand := _exact_child(holder, "def_joint_right_hold") if holder != null else null
		if hand == null:
			pad.set_meta("still", true)
			continue
		pad.reparent(hand)
		pad.position = Vector3(0.2, 0.0, 0.0)
		if holder is ToonActor:
			(holder as ToonActor).pose_action("throw", 0.0)


func _toss_cannons(delta: float) -> void:
	_toss_t += delta
	if _toss_t < 2.1:
		var mine := _local_actor()
		if mine != null:
			mine.pose_action("throw", _toss_t)
		for actor in _remote_actors():
			if actor is ToonActor:
				(actor as ToonActor).pose_action("throw", _toss_t)
		return
	if _toss_t < 3.3:
		var flight := clampf((_toss_t - 2.1) / 1.2, 0.0, 1.0)
		for pad in _cannon_pads:
			if pad == null or bool(pad.get_meta("still", false)):
				continue
			if pad.get_parent() != _root:
				pad.set_meta("from", pad.global_position)
				pad.reparent(_root)
			var origin: Vector3 = pad.get_meta("from", pad.global_position)
			var dest: Vector3 = pad.get_meta("dest", origin)
			pad.global_position = origin.lerp(dest, flight)
		return
	var squash := _toss_t - 3.3
	if squash < 0.8:
		var sized := Vector3.ONE
		if squash < 0.2:
			sized = Vector3(1.1, 1.1, 0.1)
		elif squash < 0.3:
			sized = Vector3(0.9, 0.9, 0.1)
		elif squash < 0.4:
			sized = Vector3(1.0, 1.0, 0.1)
		elif squash < 0.6:
			sized = Vector3(1.0, 1.0, 1.1)
		elif squash < 0.7:
			sized = Vector3(1.0, 1.0, 0.9)
		for pad in _cannon_pads:
			if pad != null:
				pad.scale = sized
		return
	_open_cannon_round()


func _take_remote_stuns() -> void:
	if not _cj_driving() or not ToonNet.networked():
		return
	var mine := ToonNet.peer_id()
	for channel in ToonNet.channels("cj-shots:"):
		if channel.trim_prefix("cj-shots:").to_int() == mine:
			continue
		var snap := ToonNet.latest(channel)
		var stuns: Array = snap.get("stuns", [])
		for claimed in stuns:
			var lawyer_index := int(claimed)
			if lawyer_index < 0 or lawyer_index >= _lawyers.size():
				continue
			if float(_lawyers[lawyer_index].get("stun", 0.0)) > 0.0:
				continue
			_lawyers[lawyer_index]["stun"] = 5.0
			_boss.call("stun_lawyer", lawyer_index)


func _take_remote_seats() -> void:
	if not _cj_driving() or not ToonNet.networked():
		return
	var mine := ToonNet.peer_id()
	for channel in ToonNet.channels("cj-shots:"):
		if channel.trim_prefix("cj-shots:").to_int() == mine:
			continue
		var snap := ToonNet.latest(channel)
		var seated: Array = snap.get("seated", [])
		for claimed in seated:
			var chair_index := int(claimed)
			if chair_index < 0 or chair_index >= _chairs.size():
				continue
			if String(_chairs[chair_index].get("state", "")) != "empty":
				continue
			_seat_toon(chair_index, false)


func _touch_lawyer_books(body: CharacterBody3D) -> void:
	if body == null:
		return
	for lawyer in _lawyers:
		if String(lawyer.get("kind", "")) != "attack" or bool(lawyer.get("hit", false)):
			continue
		if String(lawyer.get("phase", "")) != "fly":
			continue
		var book := lawyer.get("book") as Node3D
		if book == null or not book.visible:
			continue
		if book.global_position.distance_to(body.global_position + Vector3(0.0, 1.2, 0.0)) < 1.6:
			lawyer["hit"] = true
			_boss.call("note_lawyer_hit")
			if _mode != "evidence":
				return


func _cj_driving() -> bool:
	if not ToonNet.networked():
		return true
	var best := ToonNet.peer_id()
	var mine := ToonNet.district_id()
	for channel in ToonNet.channels("toon:"):
		var row := ToonNet.latest(channel)
		if int(row.get("district", -1)) != mine:
			continue
		if not String(row.get("place", "")).ends_with("lawbot_cj.tscn"):
			continue
		var peer := channel.trim_prefix("toon:").to_int()
		if peer > 0 and peer < best:
			best = peer
	return ToonNet.peer_id() == best


func _publish_cj(delta: float) -> void:
	if not ToonNet.networked():
		return
	_cj_send = maxf(_cj_send - delta, 0.0)
	if _cj_send > 0.0:
		return
	_cj_send = 0.2
	if _cj_driving():
		ToonNet.cj_field(_cj_snapshot())
	if _mode == "evidence" or _mode == "cannon":
		ToonNet.cj_shots(_shot_snapshot())


func _cj_snapshot() -> Dictionary:
	var chairs: Array = []
	for chair in _chairs:
		chairs.append({
			"state": String(chair.get("state", "empty")),
			"fly": float(chair.get("fly", 0.0)),
			"due": float(chair.get("due", 0.0)),
		})
	var lawyers: Array = []
	for lawyer in _lawyers:
		var book := lawyer.get("book") as Node3D
		var at := book.global_position if book != null else Vector3.ZERO
		lawyers.append({
			"phase": String(lawyer.get("phase", "idle")),
			"t": float(lawyer.get("t", 0.0)),
			"stun": float(lawyer.get("stun", 0.0)),
			"kind": String(lawyer.get("kind", "")),
			"x": at.x, "y": at.y, "z": at.z,
			"show": book != null and book.visible,
		})
	var gavels: Array = []
	for gavel in _gavels:
		gavels.append({
			"phase": String(gavel.get("phase", "down")),
			"t": float(gavel.get("t", 0.0)),
			"step": int(gavel.get("step", 0)),
			"struck": bool(gavel.get("struck", false)),
		})
	return {
		"clock": _clock,
		"area": _area_seq,
		"chairs": chairs,
		"lawyers": lawyers,
		"gavels": gavels,
	}


func _shot_snapshot() -> Dictionary:
	var rows: Array = []
	for shot in _shots:
		if bool(shot.get("done", false)):
			continue
		var at: Vector3 = shot["at"]
		rows.append({"x": at.x, "y": at.y, "z": at.z})
	var stuns: Array = []
	for lawyer_index in _lawyers.size():
		if float(_lawyers[lawyer_index].get("stun", 0.0)) > 0.0:
			stuns.append(lawyer_index)
	return {"shots": rows, "seated": _claims, "stuns": stuns}


func _apply_cj_field() -> void:
	var snap := ToonNet.latest("cj-field")
	if snap.is_empty():
		return
	var chairs: Array = snap.get("chairs", [])
	for index in mini(chairs.size(), _chairs.size()):
		var chair_row: Dictionary = chairs[index]
		var remote_state := String(chair_row.get("state", "empty"))
		if _claims.has(index) and remote_state == "empty":
			continue
		_chairs[index]["state"] = remote_state
		_chairs[index]["fly"] = float(chair_row.get("fly", 0.0))
		_chairs[index]["due"] = float(chair_row.get("due", 0.0))
	var lawyers: Array = snap.get("lawyers", [])
	for index in mini(lawyers.size(), _lawyers.size()):
		var lawyer_row: Dictionary = lawyers[index]
		var arrived := String(lawyer_row.get("phase", "idle"))
		if arrived == "wind" and String(_lawyers[index].get("phase", "")) != "wind":
			_lawyers[index]["hit"] = false
		_lawyers[index]["phase"] = arrived
		_lawyers[index]["t"] = float(lawyer_row.get("t", 0.0))
		_lawyers[index]["stun"] = float(lawyer_row.get("stun", 0.0))
		_lawyers[index]["kind"] = String(lawyer_row.get("kind", ""))
		var book := _lawyers[index].get("book") as Node3D
		if book != null:
			book.visible = bool(lawyer_row.get("show", false))
			book.global_position = Vector3(float(lawyer_row.get("x", 0.0)), float(lawyer_row.get("y", 0.0)), float(lawyer_row.get("z", 0.0)))
	var gavels: Array = snap.get("gavels", [])
	for index in mini(gavels.size(), _gavels.size()):
		var gavel_row: Dictionary = gavels[index]
		_gavels[index]["phase"] = String(gavel_row.get("phase", "down"))
		_gavels[index]["t"] = float(gavel_row.get("t", 0.0))
		var gavel_phase := String(gavel_row.get("phase", "down"))
		if gavel_phase != "stay":
			_gavels[index]["struck"] = false
		_gavels[index]["phase"] = gavel_phase
		_gavels[index]["step"] = int(gavel_row.get("step", 0))
	var area := int(snap.get("area", 0))
	if area > _seen_area:
		_seen_area = area
		_sfx("res://assets/cog_hq/audio/CHQ_GOON_tractor_beam_alarmed.ogg")
		_hint = "You're all in contempt of court!"
		_hint_left = 4.0
		_head_talk = 4.0
		var body := _body()
		if body != null and body.is_on_floor():
			_boss.call("note_area_attack")


func _show_remote_shots() -> void:
	if _root == null or not ToonNet.networked():
		return
	var mine := ToonNet.peer_id()
	for channel in ToonNet.channels("cj-shots:"):
		var peer := channel.trim_prefix("cj-shots:").to_int()
		if peer == mine:
			continue
		var snap := ToonNet.latest(channel)
		var rows: Array = snap.get("shots", [])
		for index in rows.size():
			var row: Dictionary = rows[index]
			var name := "GhostBook%d_%d" % [peer, index]
			var book := _root.get_node_or_null(name) as Node3D
			if book == null:
				book = _evidence_prop(Vector3.ZERO)
				book.name = name
			book.visible = true
			book.global_position = Vector3(float(row.get("x", 0.0)), float(row.get("y", 0.0)), float(row.get("z", 0.0)))
		var extra := rows.size()
		var leftover := _root.get_node_or_null("GhostBook%d_%d" % [peer, extra])
		while leftover != null:
			leftover.name = "FreeGhost"
			leftover.queue_free()
			extra += 1
			leftover = _root.get_node_or_null("GhostBook%d_%d" % [peer, extra])


func _tick_evidence_hints(delta: float) -> void:
	if _hint_left > 0.0:
		_hint_left = maxf(_hint_left - delta, 0.0)
		if _hint_left > 0.0:
			return
		if _hint != "Touch the witness stand to get evidence." and _hint != "Press the Delete key to throw the evidence\n at the lawyers or into the scale!" and _hint != "You need to get more evidence!":
			_hint = ""
	if _hint == "You need to get more evidence!":
		_hint = "Touch the witness stand to get evidence."
		return
	if not _restocked and not _threw and _hint == "":
		_hint = "Touch the witness stand to get evidence."
	elif _restocked and not _threw and _hint == "":
		_hint = "Press the Delete key to throw the evidence\n at the lawyers or into the scale!"


func _tick_cj_judge(delta: float, body: CharacterBody3D) -> void:
	if not _cj_driving():
		return
	var wave := int(_clock / 6.0)
	if wave <= 0 or wave == _judge_wave:
		return
	_judge_wave = wave
	if (_area_at < 0.0 or _clock - _area_at > 15.0) and randi_range(1, 100) <= 11:
		_area_at = _clock
		_area_seq += 1
		_hint = "You're all in contempt of court!"
		_hint_left = 4.0
		_head_talk = 4.0
		_sfx("res://assets/cog_hq/audio/CHQ_GOON_tractor_beam_alarmed.ogg")
		if body != null and body.is_on_floor():
			_boss.call("note_area_attack")
		return
	if randi_range(1, 100) > 25:
		return
	var which := randi_range(0, 4)
	var line := "Order in the court!"
	if which == 0:
		line = "%s, I find you in contempt of court!" % _toon_label()
	elif which == 1:
		line = "Objection sustained!"
	elif which == 2:
		line = "Strike that from the record."
	elif which == 3:
		line = "Your appeal has been rejected. I sentence you to sadness!"
	_hint = line
	_hint_left = 4.0
	_head_talk = 4.0


func _toon_label() -> String:
	var style := ToonRoster.selected_style()
	if style != null:
		return style.display_name()
	return "Toon"


func _hit_evidence_toon(shot: Dictionary) -> bool:
	var at: Vector3 = shot["at"]
	for actor in _remote_actors():
		if not _near_point(at, actor.global_position + Vector3(0.0, 1.2, 0.0), 1.6):
			continue
		_sfx("res://assets/cog_hq/audio/LB_toonup.ogg")
		_boss.call("note_evidence_toon", int(actor.get_meta("peer")))
		return true
	return false


func pose_cj_epilogue() -> void:
	_place_witness()
	if _witness == null:
		return
	var geom := _geometry()
	if geom != null and _witness.get_parent() != geom:
		geom.add_child(_witness)
	_witness.visible = true
	_witness.position = Vector3(-3.0, 0.0, 0.0)
	_witness.basis = _panda_hpr(180.0, 0.0, 0.0)
	_witness.release_pose()
	if _cj != null:
		_cj.visible = false


func _place_cj(at: Vector3, heading: float) -> void:
	var geom := _geometry()
	if geom == null:
		return
	if _cj == null or not is_instance_valid(_cj):
		_cj = _model_or_box("res://assets/cogs/bosses/lawbot_cj.glb", Vector3.ZERO, "CjBoss", Color(0.35, 0.4, 0.55), Vector3(3.0, 8.0, 3.0))
		geom.add_child(_cj)
	_cj.visible = true
	_cj.position = at
	# The export faces him backward, the same way the other bosses are baked.
	_cj.basis = _panda_hpr(heading - 180.0, 0.0, 0.0)


func _place_witness() -> void:
	var geom := _geometry()
	if geom == null:
		return
	if _witness != null and is_instance_valid(_witness):
		return
	_witness = ToonActor.new()
	_witness.name = "Witness"
	geom.add_child(_witness)
	_witness.show_style(_witness_style())
	_witness.position = Vector3(54.0, 100.0, 0.0)
	_witness.basis = _panda_hpr(-90.0, 0.0, 0.0)


func _witness_style() -> ToonStyle:
	# The witness DNA string in DistributedLawbotBoss.__makeWitnessToon.
	var style := ToonStyle.new()
	style.first_name = "Bumpy"
	style.last_name = "Bumblebehr"
	style.gender = "m"
	style.head = "bss"
	style.torso = "ss"
	style.legs = "m"
	style.top_tex = 0
	style.top_color = 3
	style.bot_tex = 1
	style.bot_color = 16
	style.arm_color = 19
	style.glove_color = 0
	style.leg_color = 19
	style.head_color = 19
	return style


func _show_witness(sitting: bool) -> void:
	_place_witness()
	if _witness == null:
		return
	var edge := _find("witnessStandSeatEdge")
	if edge != null:
		if _witness.get_parent() != edge:
			edge.add_child(_witness)
		_witness.position = Vector3(0.0, -1.15, -1.5)
		_witness.basis = _panda_hpr(180.0, 0.0, 0.0)
	_witness.visible = true
	if sitting:
		_witness.pose_action("sit", 0.0)


func _pose_witness() -> void:
	if _witness != null and is_instance_valid(_witness) and _witness.visible:
		_witness.pose_synced_loop("sit")


func _seat_juror(index: int) -> void:
	var chair := _chairs[index]["node"] as Node3D
	if chair == null:
		return
	var juror := _chairs[index].get("juror") as ToonActor
	if juror == null:
		juror = ToonActor.new()
		juror.name = "ToonJuror"
		chair.add_child(juror)
		var style := ToonStyle.new()
		style.gender = "m"
		style.head = "dss"
		style.torso = "ms"
		style.legs = "m"
		style.arm_color = 17
		style.glove_color = 0
		style.leg_color = 17
		style.head_color = 17
		style.top_tex = 3
		style.top_color = 3
		style.bot_tex = 7
		style.bot_color = 2
		juror.show_style(style)
		_chairs[index]["juror"] = juror
	juror.visible = true
	juror.position = Vector3(0.0, -1.2, 0.2)
	juror.basis = _panda_hpr(180.0, 0.0, 0.0)
	juror.pose_action("sit", 0.0)


func _propeller() -> Node3D:
	var packed := load("res://assets/cogs/props/propeller.glb") as PackedScene
	if packed != null:
		var prop := packed.instantiate() as Node3D
		prop.name = "Propeller"
		return prop
	return _box(Vector3.ZERO, Color(0.7, 0.7, 0.75), Vector3(0.8, 0.08, 0.8), "Propeller")


func _ride_camera(body: CharacterBody3D, ahead: Vector3) -> void:
	var cam := _camera()
	if cam == null:
		return
	var flat := ahead - body.global_position
	flat.y = 0.0
	if flat.length_squared() < 0.01:
		flat = Vector3(0.0, 0.0, -1.0)
	flat = flat.normalized()
	cam.global_position = body.global_position - flat * 12.0 + Vector3(0.0, 8.0, 0.0)
	if cam.global_position.distance_squared_to(body.global_position) > 0.04:
		cam.look_at(body.global_position + Vector3(0.0, 2.0, 0.0), Vector3.UP)


func _loop_jury() -> void:
	var path := "res://assets/cog_hq/audio/LB_jury_moves.ogg"
	if not FileAccess.file_exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	if _jury_loop == null or not is_instance_valid(_jury_loop):
		_jury_loop = AudioStreamPlayer.new()
		_jury_loop.name = "JuryMoves"
		add_child(_jury_loop)
	var copy := stream.duplicate() as AudioStream
	if copy != null:
		stream = copy
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_jury_loop.stream = stream
	_jury_loop.volume_db = -6.0
	_jury_loop.play()


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
	if _boss == null:
		return null
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
		paint.texture_repeat = true
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
		var path: String = paths[0]
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


func play_cj_sfx(path: String) -> void:
	_sfx(path)


func _play_hardball() -> void:
	var path := "res://assets/audio/battle/SA_hardball.ogg"
	if not FileAccess.file_exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	if _hardball != null and is_instance_valid(_hardball):
		_hardball.stop()
		_hardball.queue_free()
	_hardball = player
	_hardball_play = 0.45
	player.play()


func _ceo_ball() -> Node3D:
	var mesh := _model_or_box("res://assets/battle/props/golf-ball.glb", Vector3.ZERO, "CeoBall%d" % _ceo_shots.size(), Color(0.75, 0.75, 0.75, 0.5), Vector3(2.5, 2.5, 2.5))
	mesh.scale = Vector3.ONE * 5.0
	_fade_ball(mesh)
	return mesh


func _fade_ball(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var mat := mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat == null:
			var active := mesh.get_active_material(0)
			if active is StandardMaterial3D:
				mat = (active as StandardMaterial3D).duplicate() as StandardMaterial3D
			else:
				mat = StandardMaterial3D.new()
			mesh.set_surface_override_material(0, mat)
		if mat != null:
			mat.albedo_color = Color(0.75, 0.75, 0.75, 0.5)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for child in node.get_children():
		_fade_ball(child)


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


func _ceo_say(lines: PackedStringArray, next: String) -> void:
	_pages = lines
	_page = 0
	_act_t = 0.0
	_ceo_beat = 0
	_page_next = next
	_mode = "ceo_talk"
	if not lines.is_empty():
		_tell(lines[0])


func _tick_ceo_talk(delta: float) -> void:
	if _page_next == "seltzer" and _root != null and _root.get_node_or_null("GilSuit") == null:
		_show_gil_suit()
	_tick_door(delta)
	_tick_puffs(delta)
	if _suit_at >= 0.0 and _clock >= _suit_at:
		_suit_at = -1.0
		_wear_waiter()
	if _strip_at >= 0.0 and _clock >= _strip_at:
		_strip_at = -1.0
		_clear_waiter()
		_slip_left = 1.2
		_sad_eyes()
	if _eyes_back >= 0.0 and _clock >= _eyes_back:
		_normal_eyes()
	if _slip_left > 0.0:
		_slip_left = maxf(_slip_left - delta, 0.0)
		var body := _body()
		var actor := _toon_actor(body) if body != null else null
		if actor != null:
			actor.pose_action("slip-backward", 1.2 - _slip_left)
	if _gil_job == "walk_in":
		_tick_walk_in(delta)
		return
	_act_t += delta
	if _page_next == "cogs":
		_tick_intro_movie(delta)
	elif _page_next == "banquet":
		_tick_banquet_movie(delta)
	elif _page_next == "threat":
		_tick_threat_movie()
	elif _page_next == "seltzer":
		_tick_seltzer_movie()


func _place_banquet(boss: Node) -> void:
	var state: Dictionary = boss.call("world_state")
	var rows: Array = state.get("diners", [])
	var locators := _table_locators()
	var seats := 4
	if not rows.is_empty() and not locators.is_empty():
		seats = maxi(int(ceil(float(rows.size()) / float(mini(locators.size(), rows.size())))), 1)
	_diners.clear()
	for index in rows.size():
		if not (rows[index] is Dictionary):
			continue
		var row: Dictionary = rows[index]
		var table_index := int(row.get("table", index / seats))
		var seat_index := int(row.get("seat", index % seats))
		var node := _seat_diner(locators, table_index, seat_index, index, row)
		_diners.append({
			"index": index,
			"seat": seat_index,
			"node": node,
			"body": String(row.get("body", "c")),
			"clip": "",
			"age": 0.0,
		})
	_fill_belt(false)


func _place_seltzer() -> void:
	var origin := Vector3(0.0, 355.0, 0.0)
	if _root != null:
		origin = _root.to_global(origin)
	var boss_node: Node3D = null
	if _root != null:
		boss_node = _root.get_node_or_null("CEO") as Node3D
	if boss_node == null:
		var boss_path := "res://assets/cogs/bosses/bossbot_ceo_body.glb"
		boss_node = _model_or_box(boss_path, Vector3(0.0, 355.0, 0.0), "CEO", Color(0.15, 0.2, 0.45), Vector3(2.6, 5.4, 2.2))
		if not ResourceLoader.exists(boss_path):
			boss_node.global_position = origin
	_boss_pos = boss_node.global_position
	if _boss != null:
		var state: Dictionary = _boss.call("world_state")
		_flat_for = float(state.get("flat", 3.0))
	for diner in _diners:
		var node := diner.get("node") as Node3D
		if node != null:
			node.visible = false
	for table in _find_all("BanquetTable"):
		for chair_index in 8:
			var chair := table.find_child("chair_%d" % (chair_index + 1), true, false) as Node3D
			if chair != null:
				chair.visible = false
		var locator := table.find_child("bottle_locator", true, false) as Node3D
		var spot := locator.global_position if locator != null else table.global_position
		var table_index := int(table.get_meta("table_index", _bottle_count()))
		var bottle := _model_or_box("res://assets/cog_hq/seltzer_bottle.glb", Vector3.ZERO, "Bottle%d" % _bottle_count(), Color(0.55, 0.75, 0.9), Vector3(0.6, 1.2, 0.6))
		bottle.global_position = spot
		bottle.set_meta("table", table_index)
	if _root != null and _root.get_node_or_null("Bottle0") == null:
		var fallback := _model_or_box("res://assets/cog_hq/seltzer_bottle.glb", Vector3(6.0, 200.0, 0.0), "Bottle0", Color(0.55, 0.75, 0.9), Vector3(0.6, 1.2, 0.6))
		fallback.position = Vector3(6.0, 200.0, 0.0)
	var spots: Array[Vector3] = [Vector3(-45.0, 100.0, 0.25), Vector3(-15.0, 100.0, 0.25), Vector3(15.0, 100.0, 0.25), Vector3(45.0, 100.0, 0.25)]
	for index in spots.size():
		if _root.get_node_or_null("GolfTee%d" % index) != null:
			continue
		var tee := _model_or_box("res://assets/battle/props/golf-ball.glb", spots[index], "GolfTee%d" % index, Color(0.95, 0.95, 0.95), Vector3(0.5, 0.5, 0.5))
		tee.position = spots[index]
	_fill_belt(true)


func _bottle_count() -> int:
	var count := 0
	while _root != null and _root.get_node_or_null("Bottle%d" % count) != null:
		count += 1
	return count


func _table_locators() -> Array[Node3D]:
	var found := _find_all("TableLocator_")
	found.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return _locator_index(a.name) < _locator_index(b.name)
	)
	return found


func _locator_index(node_name: String) -> int:
	var parts := node_name.split("_")
	if parts.is_empty():
		return 0
	return int(parts[parts.size() - 1])


func _seat_diner(locators: Array[Node3D], table_index: int, seat_index: int, index: int, row: Dictionary) -> Node3D:
	var headings: Array[float] = [90.0, 90.0, 0.0, 0.0, -90.0, -90.0, 180.0, 180.0]
	var heading := headings[seat_index % headings.size()]
	if table_index < locators.size():
		var table := _banquet_table(locators[table_index], table_index)
		var chair := table.find_child("chair_%d" % (seat_index + 1), true, false) as Node3D
		if chair != null:
			var pivot := Node3D.new()
			pivot.name = "Seat%d" % index
			chair.add_child(pivot)
			pivot.basis = Basis(Vector3(0, 0, 1), deg_to_rad(heading))
			pivot.position = Vector3(0.5, 3.65, -3.75) if String(row.get("body", "c")) == "c" else Vector3(0.5, 2.5, -2.4)
			return _diner_suit(pivot, index, row)
	var box := _box(Vector3.ZERO, Color(0.35, 0.32, 0.38), Vector3(0.8, 1.5, 0.8), "Seat%d" % index)
	box.position = Vector3(float(seat_index) * 3.0 - 6.0, 80.0 + float(table_index) * 4.0, 0.0)
	return box


func _banquet_table(locator: Node3D, index: int) -> Node3D:
	var existing := locator.get_node_or_null("BanquetTable") as Node3D
	if existing != null:
		return existing
	var table := _model_or_box("res://assets/cog_hq/banquet_table.glb", Vector3.ZERO, "BanquetTable", Color(0.45, 0.32, 0.18), Vector3(4.0, 1.0, 4.0))
	table.reparent(locator)
	table.transform = Transform3D.IDENTITY
	table.name = "BanquetTable"
	table.set_meta("table_index", index)
	return table


func _diner_suit(pivot: Node3D, index: int, row: Dictionary) -> Node3D:
	var suit := StreetCog.new()
	suit.name = "Diner%d" % index
	_root.add_child(suit)
	suit.present({
		"code": String(row.get("code", "f")),
		"name": String(row.get("cog_name", "Cog")),
		"dept": "c",
		"body": String(row.get("body", "c")),
		"height": float(row.get("height", 4.0)),
		"level": int(row.get("level", 8)),
		"hp": 1,
		"max": 1,
	}, {})
	suit.set_process(false)
	if suit.has_method("_release_nametag"):
		suit.call("_release_nametag")
	pivot.force_update_transform()
	suit.force_update_transform()
	suit.global_position = pivot.global_position
	var ahead := pivot.to_global(Vector3(0, 1, 0))
	if suit.global_position.distance_squared_to(ahead) > 0.04:
		suit.look_at(ahead, Vector3.UP)
	return suit


func _show_power(charging: bool) -> void:
	if _power_root == null:
		var layer := CanvasLayer.new()
		layer.layer = 30
		add_child(layer)
		_power_root = Control.new()
		_power_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		_power_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_power_root)
		var frame := ColorRect.new()
		frame.color = Color(0.45, 0.45, 0.45, 0.55)
		frame.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		frame.offset_left = -160.0
		frame.offset_top = -96.0
		frame.offset_right = 160.0
		frame.offset_bottom = -68.0
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_power_root.add_child(frame)
		_power_fill = ColorRect.new()
		_power_fill.color = Color(0.95, 0.15, 0.15)
		_power_fill.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_power_fill.offset_left = -156.0
		_power_fill.offset_top = -92.0
		_power_fill.offset_right = -156.0
		_power_fill.offset_bottom = -72.0
		_power_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_power_root.add_child(_power_fill)
	if not charging:
		_power_root.visible = false
		return
	var amount := _water_power(_spray) * 100.0
	if _station == "tee":
		amount = _ball_power(_spray)
	amount = clampf(amount, 0.0, 100.0)
	_power_root.visible = true
	_power_fill.offset_right = lerpf(-156.0, 156.0, amount / 100.0)
	if _station == "bottle" and amount >= 97.0:
		_power_fill.color = Color(0.95, 0.1, 0.1)
	elif _station == "bottle" and amount >= 75.0:
		_power_fill.color = Color(0.95, 0.85, 0.15)
	else:
		_power_fill.color = Color(0.95, 0.15, 0.15)


func _puff_dust(on: Node3D = null, spread: float = 1.0) -> void:
	var body := on if on != null else _body()
	if body == null:
		return
	var cloud := _dust_cloud()
	if cloud == null:
		return
	var victory := body.name == "CEO"
	var parent := _geometry()
	if parent == null:
		parent = body.get_parent() as Node3D
	if parent == null:
		cloud.queue_free()
		return
	parent.add_child(cloud)
	if victory:
		cloud.global_position = body.to_global(Vector3(0.0, -10.0, 3.0))
		cloud.scale = Vector3.ONE * 4.0
		_sfx("res://assets/effects/fireworks/firework_distance_02.ogg")
	else:
		cloud.global_position = body.to_global(Vector3(0.0, 3.0, -2.0))
		cloud.scale = Vector3.ONE * 0.5
	_puffs.append({
		"mesh": cloud,
		"age": 0.0,
		"fps": 12.0 if victory else 24.0,
		"billboard": not victory,
	})


func _dust_cloud() -> Node3D:
	var path := "res://assets/effects/dust_cloud.glb"
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var cloud := packed.instantiate() as Node3D
	if cloud == null:
		return null
	cloud.name = "DustCloud"
	_dust_materials(cloud)
	var frames := cloud.find_child("frames", true, false) as Node3D
	if frames != null:
		for index in frames.get_child_count():
			var frame := frames.get_child(index) as Node3D
			if frame != null:
				frame.visible = index == 0
	return cloud


func _dust_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var active := mesh.get_active_material(0) as StandardMaterial3D
		var mat := StandardMaterial3D.new()
		if active != null:
			mat = active.duplicate() as StandardMaterial3D
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material_override = mat
	for child in node.get_children():
		_dust_materials(child)


func _tick_puffs(delta: float) -> void:
	var kept: Array[Dictionary] = []
	var camera := get_viewport().get_camera_3d()
	for puff in _puffs:
		var age := float(puff.get("age", 0.0)) + delta
		puff["age"] = age
		var cloud := puff.get("mesh") as Node3D
		if cloud == null or not is_instance_valid(cloud):
			continue
		var frames := cloud.find_child("frames", true, false) as Node3D
		var count := frames.get_child_count() if frames != null else 0
		var index := int(age * float(puff.get("fps", 24.0)))
		if count == 0 or index >= count:
			cloud.queue_free()
			continue
		for frame_index in count:
			var frame := frames.get_child(frame_index) as Node3D
			if frame != null:
				frame.visible = frame_index == index
		if bool(puff.get("billboard", false)) and camera != null:
			var flat := camera.global_position
			flat.y = cloud.global_position.y
			if cloud.global_position.distance_squared_to(flat) > 0.04:
				cloud.look_at(flat, Vector3.UP)
		kept.append(puff)
	_puffs = kept


func _place_ceo_at(panda_y: float) -> void:
	if _root == null:
		return
	var ceo := _root.get_node_or_null("CEO") as Node3D
	if ceo == null:
		var boss_path := "res://assets/cogs/bosses/bossbot_ceo_body.glb"
		ceo = _model_or_box(boss_path, Vector3(0.0, panda_y, 0.0), "CEO", Color(0.15, 0.2, 0.45), Vector3(2.6, 5.4, 2.2))
		if not ResourceLoader.exists(boss_path):
			ceo.global_position = _root.to_global(Vector3(0.0, panda_y, 0.0))
		return
	ceo.position = Vector3(0.0, panda_y, 0.0)


func _belt_sound(playing: bool) -> void:
	if not playing:
		if _belt_loop != null and is_instance_valid(_belt_loop):
			_belt_loop.stop()
		return
	if _belt_loop == null or not is_instance_valid(_belt_loop):
		var path := "res://assets/cog_hq/audio/CHQ_FACT_conveyor_belt.ogg"
		if not FileAccess.file_exists(path):
			return
		var stream := load(path) as AudioStream
		if stream == null:
			return
		stream = stream.duplicate()
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		_belt_loop = AudioStreamPlayer.new()
		_belt_loop.stream = stream
		_belt_loop.volume_db = -10.0
		add_child(_belt_loop)
	if not _belt_loop.playing:
		_belt_loop.play()


func _pose_diner(diner: Dictionary, row: Dictionary, delta: float) -> void:
	var status := String(row.get("status", ""))
	var cog := diner.get("node") as Node
	if cog == null or not cog.has_method("_pose_elapsed"):
		var box := diner.get("node") as Node3D
		if box != null:
			var glow := status == "hungry" or status == "angry"
			box.scale = Vector3(1.25, 1.25, 1.25) if glow else Vector3.ONE
			box.visible = status != "dead"
			_diner_icon(diner, box, row)
		return
	var want := "sit_hungry_right"
	var meal := 0.0
	if status == "angry":
		want = "sit_angry"
	elif status == "eating":
		var duration := float(row.get("eat", 25.0))
		var left := float(row.get("left", 0.0))
		meal = maxf(duration - left, 0.0)
		var eat_in := 32.0 / 24.0
		var eat_out := 21.0 / 24.0
		if meal < 5.0:
			want = "sit"
		elif meal < 5.0 + eat_in:
			want = "sit_eat_in"
		elif meal < duration - eat_out:
			want = "sit_eat_loop"
		else:
			want = "sit_eat_out"
	elif status == "dead":
		want = "sit_lose"
	elif int(row.get("lean", 0)) == 1:
		want = "sit_hungry_left"
	if String(diner.get("clip", "")) != want:
		diner["clip"] = want
		diner["age"] = 0.0
	if status == "eating" and (want == "sit_eat_in" or want == "sit_eat_out"):
		var duration_now := float(row.get("eat", 25.0))
		if want == "sit_eat_in":
			diner["age"] = maxf(meal - 5.0, 0.0)
		else:
			diner["age"] = maxf(meal - (duration_now - 21.0 / 24.0), 0.0)
	else:
		diner["age"] = float(diner.get("age", 0.0)) + delta
	_hold_meal(diner, cog as Node3D, status == "eating" and meal >= 5.0 + 6.0 / 24.0 and meal < float(row.get("eat", 25.0)) - 21.0 / 24.0 + 12.0 / 24.0)
	var body_name := String(diner.get("body", "c"))
	var path := "res://assets/cogs/anims/%s/%s.walk" % [body_name, want]
	if not FileAccess.file_exists(path):
		if status == "dead":
			(cog as Node3D).visible = false
		return
	if not _diner_banks.has(path):
		var loaded: Variant = cog.call("_read_bank", path)
		if loaded is Dictionary:
			_diner_banks[path] = loaded
	var bank: Dictionary = _diner_banks.get(path, {})
	var looping := want != "sit_eat_in" and want != "sit_eat_out" and want != "sit_lose"
	cog.call("_pose_elapsed", bank, float(diner.get("age", 0.0)), 24.0, looping)
	var show_lose := status == "dead" and want == "sit_lose" and float(diner.get("age", 0.0)) <= 2.4
	(cog as Node3D).visible = status != "dead" or show_lose
	_diner_icon(diner, cog as Node3D, row)


func _fill_belt(snacks: bool) -> void:
	for item in _food:
		var old := item.get("mesh") as Node
		if old != null:
			old.queue_free()
	_food.clear()
	_belts.clear()
	for belt_index in 2:
		var start := _find("conveyer_belt_start_%d" % (belt_index + 1))
		var finish := _find("conveyer_belt_end_%d" % (belt_index + 1))
		if start == null or finish == null:
			continue
		var span := start.global_position.distance_to(finish.global_position)
		if span < 1.0:
			continue
		_belts.append(start.global_position)
		for slot in 4:
			var mesh := _belt_mesh(snacks, slot, belt_index)
			_food.append({
				"mesh": mesh,
				"start": start.global_position,
				"end": finish.global_position,
				"length": span,
				"slot": slot,
				"belt": belt_index,
				"heal": [1, 2, 3, 4][slot],
				"picked": -1,
			})
	if _food.is_empty():
		var pad := _panda_box(0.0, 200.0, 0.0, Color(0.7, 0.45, 0.2), Vector3(8.0, 0.4, 1.4), "Belt")
		_belts.append(pad.global_position)


func _belt_mesh(snacks: bool, slot: int, belt_index: int) -> Node3D:
	var names: PackedStringArray = PackedStringArray([
		"res://assets/cog_hq/picnic_apple.glb",
		"res://assets/cog_hq/picnic_cupcake.glb",
		"res://assets/cog_hq/picnic_sandwich.glb",
		"res://assets/cog_hq/picnic_cake.glb",
	])
	var path := "res://assets/cog_hq/can_of_food.glb"
	var scale := 0.75
	if snacks:
		path = names[slot]
		scale = 4.0 if slot == 3 else 5.0
	var mesh := _model_or_box(path, Vector3.ZERO, "BeltFood%d_%d" % [belt_index, slot], Color(0.72, 0.48, 0.2), Vector3(0.7, 0.5, 0.7))
	mesh.scale = Vector3.ONE * scale
	return mesh


func _diner_icon(diner: Dictionary, cog: Node3D, row: Dictionary) -> void:
	if cog == null:
		return
	var status := String(row.get("status", ""))
	var icons := diner.get("icons") as Node3D
	if icons == null or not is_instance_valid(icons):
		var packed := load("res://assets/cog_hq/banquet_icons.glb") as PackedScene
		if packed == null:
			return
		icons = packed.instantiate() as Node3D
		if icons == null:
			return
		cog.add_child(icons)
		icons.position = Vector3(0.0, float(diner.get("height", 4.0)) + 1.4, 0.0)
		diner["icons"] = icons
	var show_name := "Hunger"
	if status == "angry":
		show_name = "Anger"
	elif status == "eating":
		show_name = "Food"
	for icon_name in ["Hunger", "Anger", "Food"]:
		var icon := icons.find_child(icon_name, true, false) as Node3D
		if icon != null:
			icon.visible = icon_name == show_name and status != "dead"
	icons.visible = status != "dead"
	var camera := get_viewport().get_camera_3d() if get_viewport() != null else null
	if camera != null and icons.global_position.distance_squared_to(camera.global_position) > 0.04:
		icons.look_at(camera.global_position, Vector3.UP)
	if status == "angry" or status == "dead":
		return
	var duration := float(row.get("eat", 25.0)) if status == "eating" else float(row.get("hungry", 30.0))
	var left := float(row.get("left", duration))
	var cover := 1.0 - clampf(left / maxf(duration, 0.1), 0.0, 1.0)
	var meter := icons.get_node_or_null("Meter") as MeshInstance3D
	if meter == null:
		meter = MeshInstance3D.new()
		meter.name = "Meter"
		var quad := QuadMesh.new()
		quad.size = Vector2(1.1, 1.1)
		meter.mesh = quad
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.15, 0.15, 0.15, 0.55)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		meter.material_override = mat
		icons.add_child(meter)
	meter.position = Vector3(0.0, -0.55 + cover * 0.55, 0.05)
	meter.scale = Vector3(1.0, maxf(cover, 0.02), 1.0)
	var shown := icons.find_child(show_name, true, false) as Node3D
	if shown != null:
		if left < 10.0:
			var flash := 0.5 + 0.5 * sin(_clock * 10.0)
			shown.scale = Vector3.ONE * lerpf(1.0, 1.25, flash)
		else:
			shown.scale = Vector3.ONE


func _hold_meal(diner: Dictionary, cog: Node3D, holding: bool) -> void:
	var can := diner.get("food") as Node3D
	if not holding:
		if can != null:
			can.visible = false
		return
	if can == null or not is_instance_valid(can):
		can = _model_or_box("res://assets/cog_hq/can_of_food.glb", Vector3.ZERO, "Meal", Color(0.72, 0.48, 0.2), Vector3(0.4, 0.3, 0.4))
		var scale := 0.6 if String(diner.get("body", "c")) == "c" else 0.8
		can.scale = Vector3.ONE * 0.75 * scale
		diner["food"] = can
	var hand := cog.find_child("joint_Rhold", true, false) as Node3D
	if hand == null:
		hand = cog.find_child("def_joint_right_hold", true, false) as Node3D
	if hand == null:
		hand = cog
	if can.get_parent() != hand:
		hand.add_child(can)
	can.visible = true
	if hand == cog:
		can.position = Vector3(0.35, 1.2, 0.25)
	else:
		can.position = Vector3(-0.15, -0.7, -0.4)
		if String(diner.get("body", "c")) == "c":
			can.position = Vector3(0.1, -0.25, -0.31)


func _ensure_food_belts() -> void:
	if _root == null or _root.get_node_or_null("FoodBelt1") != null:
		return
	# DistributedFoodBelt.setPos(conveyer_belt_start). Panda positions from BanquetInterior_1.
	var spots := [
		Vector3(-111.369, 61.7974, 3.86091),
		Vector3(112.622, 61.7974, 3.86091),
	]
	for index in 2:
		_model_or_box(
			"res://assets/cog_hq/food_belt%d.glb" % (index + 1),
			spots[index],
			"FoodBelt%d" % (index + 1),
			Color(0.45, 0.42, 0.38),
			Vector3(6.0, 1.0, 60.0)
		)


func _scroll_tide(node: Node, amount: float) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null:
			for surface in mesh.mesh.get_surface_count():
				var mat := mesh.get_surface_override_material(surface) as StandardMaterial3D
				if mat == null:
					var active := mesh.get_active_material(surface)
					if active is StandardMaterial3D:
						mat = (active as StandardMaterial3D).duplicate() as StandardMaterial3D
						mat.texture_repeat = true
						mesh.set_surface_override_material(surface, mat)
				if mat != null:
					# uvj_WakeWhiteTide1's animated channel is Y, and that becomes the texture V.
					mat.uv1_offset.y = amount
	for child in node.get_children():
		_scroll_tide(child, amount)


func _tick_belt(delta: float, body: CharacterBody3D, snacks: bool) -> void:
	_belt_sound(true)
	_ensure_food_belts()
	# BeltActorPlayRate 5.35 (snacks: 5.35 * ToonupBeltSpeed / BeltSpeed). The tide joint
	# travels Y 0→1 across 200 frames at 24 fps, so one UV cycle is 200 / (24 * play rate).
	var play := 5.35 * (1.0 / 5.0 if snacks else 1.0)
	_belt_u += delta * play * 24.0 / 200.0
	if _root != null:
		for index in 2:
			var belt := _root.get_node_or_null("FoodBelt%d" % (index + 1))
			if belt == null:
				continue
			var tide := belt.find_child("mesh_tide1", true, false)
			if tide != null:
				_scroll_tide(tide, _belt_u)
	var speed := 1.0 if snacks else 5.0
	for slot in _food.size():
		var item: Dictionary = _food[slot]
		var mesh := item.get("mesh") as Node3D
		if mesh == null:
			continue
		var length := float(item.get("length", 1.0))
		var along := _clock * speed + float(item.get("slot", 0)) * length / 4.0
		var lap := int(along / length)
		var frac := fposmod(along, length) / length
		var start: Vector3 = item["start"]
		var finish: Vector3 = item["end"]
		mesh.global_position = start.lerp(finish, frac)
		var dropping := frac > 0.92
		if dropping:
			mesh.global_position.y = lerpf(mesh.global_position.y, 0.2, (frac - 0.92) / 0.08)
		var picked := int(item.get("picked", -1))
		mesh.visible = picked != lap and not dropping
		if not mesh.visible or dropping:
			continue
		if not _near(body, mesh.global_position, 2.2):
			continue
		if snacks:
			item["picked"] = lap
			mesh.visible = false
			_boss.call("note_snack", int(item.get("heal", 1)))
			_sfx("res://assets/cog_hq/audio/LB_toonup.ogg")
		elif not _carry:
			item["picked"] = lap
			mesh.visible = false
			_carry = true
			_sfx("res://assets/audio/sfx/SZ_MM_gliss.ogg")
		_food[slot] = item


func _follow_plate(body: CharacterBody3D) -> void:
	var plate: Node3D = null
	if _root != null:
		plate = _root.get_node_or_null("Plate") as Node3D
	var toon := _playground_toon()
	if not _carry:
		if plate != null:
			plate.visible = false
			if _root != null and plate.get_parent() != _root:
				_root.add_child(plate)
		if toon != null and toon.has_method("set_waiter_tray"):
			toon.call("set_waiter_tray", false)
		return
	if plate == null:
		plate = _model_or_box("res://assets/cog_hq/can_of_food.glb", Vector3.ZERO, "Plate", Color(0.72, 0.48, 0.2), Vector3(0.5, 0.35, 0.5))
	var hand: Node3D = null
	var suit := body.get_node_or_null("CogSuit") as Node3D
	if suit != null:
		hand = suit.find_child("joint_Rhold", true, false) as Node3D
	if hand != null:
		if plate.get_parent() != hand:
			hand.add_child(plate)
		plate.position = Vector3.ZERO
		plate.basis = _panda_hpr(52.1961, 180.4983, -4.2882)
		plate.scale = Vector3.ONE * 0.75
	else:
		if _root != null and plate.get_parent() != _root:
			_root.add_child(plate)
		plate.global_position = body.global_position + Vector3(0.6, 1.3, 0.0)
		plate.scale = Vector3.ONE * 0.75
	plate.visible = true
	if toon != null and toon.has_method("set_waiter_tray"):
		toon.call("set_waiter_tray", true)


func _swing_door(heading: float, seconds: float) -> void:
	var door := _find("door3")
	if door == null:
		_banquet_door(heading)
		return
	_door_from = float(door.get_meta("heading", 0.0))
	_door_to = heading
	_door_age = 0.0
	_door_span = maxf(seconds, 0.05)


func _tick_door(delta: float) -> void:
	if _door_span <= 0.0:
		return
	_door_age += delta
	var along := clampf(_door_age / _door_span, 0.0, 1.0)
	_banquet_door(lerpf(_door_from, _door_to, along))
	if along >= 1.0:
		_door_span = 0.0


func _aim_world(from: Vector3, at: Vector3) -> void:
	_grab_camera()
	if _movie_cam == null:
		return
	_movie_cam.global_position = from
	if from.distance_squared_to(at) > 0.04:
		_movie_cam.look_at(at, Vector3.UP)


func _aim_toon_front() -> void:
	var body := _body()
	if body == null:
		return
	var forward := Vector3(0.0, 0.0, -1.0)
	var actor := _toon_actor(body)
	if actor != null:
		forward = actor.global_transform.basis.y
		forward.y = 0.0
		if forward.length_squared() > 0.01:
			forward = forward.normalized()
		else:
			forward = Vector3(0.0, 0.0, -1.0)
	var from := body.global_position + forward * 19.0 + Vector3.UP * 6.0
	_aim_world(from, body.global_position - forward * 1.5 + Vector3.UP * (6.0 - tan(deg_to_rad(5.0)) * 19.0))


func _tick_chest(delta: float) -> void:
	_ensure_chest()
	if _chest == null or _boss == null:
		return
	var state: Dictionary = _boss.call("world_state")
	var cap := maxf(float(state.get("max", 500.0)), 1.0)
	var health := 1.0 - clampf(float(state.get("hp", 0.0)) / cap, 0.0, 1.0)
	_paint_chest(health)
	if _chest_condition < 4:
		return
	_chest_blink += delta
	var hold := 0.25 if _chest_condition == 5 else 0.75
	var span := hold if _chest_red else 0.1
	if _chest_blink < span:
		return
	_chest_blink = 0.0
	_chest_red = not _chest_red
	_apply_chest_blink()


func _ensure_chest() -> void:
	if _chest != null and is_instance_valid(_chest):
		_chest.visible = true
		return
	if _root == null:
		return
	var ceo := _root.get_node_or_null("CEO") as Node3D
	if ceo == null:
		return
	var joint := ceo.find_child("joint_lifeMeter", true, false) as Node3D
	if joint == null:
		return
	var light := Node3D.new()
	light.name = "HealthLight"
	joint.add_child(light)
	light.rotate_object_local(Vector3.RIGHT, deg_to_rad(-20.0))
	var disc := _chest_card("res://assets/cogs/bosses/minnie_circle.glb", "Disc")
	if disc == null:
		disc = MeshInstance3D.new()
		disc.name = "Disc"
		disc.mesh = StreetCog._disc_mesh()
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		light.scale = Vector3(2.0, 2.0, 2.0)
	else:
		light.scale = Vector3(6.0, 6.0, 6.0)
	_chest_scale = light.scale
	_chest_mat = _chest_material(Color(0, 1, 0), false)
	_take_card_texture(disc, _chest_mat)
	disc.material_override = _chest_mat
	light.add_child(disc)
	var glow := _chest_card("res://assets/cogs/bosses/boss_glow.glb", "Glow")
	if glow == null:
		glow = MeshInstance3D.new()
		glow.name = "Glow"
		glow.mesh = StreetCog._disc_mesh()
		glow.scale = Vector3(1.55, 1.55, 1.55)
		glow.position = Vector3(0.0, 0.04, 0.0)
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		glow.scale = Vector3(0.28, 0.28, 0.28)
		glow.position = Vector3(-0.005, 0.01, 0.015)
	_chest_glow = _chest_material(Color(0.25, 1, 0.25, 0.5), true)
	_take_card_texture(glow, _chest_glow)
	glow.material_override = _chest_glow
	light.add_child(glow)
	_chest = light
	_chest_condition = -1


func _chest_card(path: String, node_name: String) -> MeshInstance3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var root := packed.instantiate()
	var card: MeshInstance3D = null
	if root is MeshInstance3D:
		card = root as MeshInstance3D
	else:
		card = root.find_child("*", true, false) as MeshInstance3D
		if card == null:
			for child in root.find_children("*", "MeshInstance3D", true, false):
				card = child as MeshInstance3D
				break
		if card != null and card.get_parent() != null:
			card.get_parent().remove_child(card)
		root.queue_free()
	if card == null:
		return null
	card.name = node_name
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return card


func _take_card_texture(card: MeshInstance3D, mat: StandardMaterial3D) -> void:
	var active := card.get_active_material(0) as StandardMaterial3D
	if active == null or active.albedo_texture == null:
		return
	mat.albedo_texture = active.albedo_texture
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _chest_material(color: Color, glow: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return mat


func _chest_tone(index: int, glow: bool) -> Color:
	var solid: Array[Color] = [
		Color(0, 1, 0, 1),
		Color(1, 1, 0, 1),
		Color(1, 0.5, 0, 1),
		Color(1, 0, 0, 1),
		Color(0.3, 0.3, 0.3, 1),
	]
	var soft: Array[Color] = [
		Color(0.25, 1, 0.25, 0.5),
		Color(1, 1, 0.25, 0.5),
		Color(1, 0.5, 0.25, 0.5),
		Color(1, 0.25, 0.25, 0.5),
		Color(0.3, 0.3, 0.3, 0.0),
	]
	var row := soft if glow else solid
	return row[clampi(index, 0, row.size() - 1)]


func _paint_chest(health: float) -> void:
	if _chest_mat == null or _chest_glow == null:
		return
	var condition := 5
	if health > 0.95:
		condition = 0
	elif health > 0.7:
		condition = 1
	elif health > 0.3:
		condition = 2
	elif health > 0.05:
		condition = 3
	elif health > 0.0:
		condition = 4
	if condition == _chest_condition:
		return
	_chest_condition = condition
	_chest_blink = 0.0
	_chest_red = true
	_chest.scale = _chest_scale
	if condition >= 4:
		_apply_chest_blink()
		return
	_chest_mat.albedo_color = _chest_tone(condition, false)
	_chest_glow.albedo_color = _chest_tone(condition, true)


func _apply_chest_blink() -> void:
	if _chest_mat == null or _chest_glow == null or _chest == null or not is_instance_valid(_chest):
		return
	var index := 3 if _chest_red else 4
	_chest_mat.albedo_color = _chest_tone(index, false)
	_chest_glow.albedo_color = _chest_tone(index, true)
	var pulse := 1.17 if _chest_condition == 5 and _chest_red else 1.0
	_chest.scale = _chest_scale * pulse


func _scale_club(amount: float) -> void:
	if _root == null:
		return
	var ceo := _root.get_node_or_null("CEO") as Node3D
	if ceo == null:
		return
	var club := ceo.find_child("golfclub", true, false) as Node3D
	if club == null:
		return
	club.scale = Vector3.ONE * amount


func _py2_suit(do_id: int) -> int:
	# Python 2 random.seed(doId); random.randint(0, 7). SuitDNA.getRandomSuitByDept('c').
	var mt: Array[int] = []
	mt.resize(624)
	var number := absi(do_id)
	var key: Array[int] = []
	if number == 0:
		key.append(0)
	else:
		while number > 0:
			key.append(number & 0xffffffff)
			number >>= 32
	mt[0] = 19650218
	for step in range(1, 624):
		var prev := mt[step - 1]
		mt[step] = (1812433253 * (prev ^ (prev >> 30)) + step) & 0xffffffff
	var index := 1
	var key_at := 0
	var left := key.size()
	if left < 624:
		left = 624
	while left > 0:
		var seed_prev := mt[index - 1]
		mt[index] = ((mt[index] ^ ((seed_prev ^ (seed_prev >> 30)) * 1664525)) + key[key_at] + key_at) & 0xffffffff
		index += 1
		key_at += 1
		if index >= 624:
			mt[0] = mt[623]
			index = 1
		if key_at >= key.size():
			key_at = 0
		left -= 1
	left = 623
	while left > 0:
		var mix_prev := mt[index - 1]
		mt[index] = ((mt[index] ^ ((mix_prev ^ (mix_prev >> 30)) * 1566083941)) - index) & 0xffffffff
		index += 1
		if index >= 624:
			mt[0] = mt[623]
			index = 1
		left -= 1
	mt[0] = 0x80000000
	var upper := 0x80000000
	var lower := 0x7fffffff
	var matrix := 0x9908b0df
	for step in 227:
		var mixed := (mt[step] & upper) | (mt[step + 1] & lower)
		var twist := mt[step + 397] ^ (mixed >> 1)
		if (mixed & 1) != 0:
			twist ^= matrix
		mt[step] = twist & 0xffffffff
	for step in range(227, 623):
		var mixed_b := (mt[step] & upper) | (mt[step + 1] & lower)
		var twist_b := mt[step - 227] ^ (mixed_b >> 1)
		if (mixed_b & 1) != 0:
			twist_b ^= matrix
		mt[step] = twist_b & 0xffffffff
	var mixed_last := (mt[623] & upper) | (mt[0] & lower)
	var last := mt[396] ^ (mixed_last >> 1)
	if (mixed_last & 1) != 0:
		last ^= matrix
	mt[623] = last & 0xffffffff
	var word := mt[0]
	word ^= word >> 11
	word ^= (word << 7) & 0x9d2c5680
	word ^= (word << 15) & 0xefc60000
	word ^= word >> 18
	return (word & 0xffffffff) >> 29


func _show_gil_suit() -> void:
	if _root == null:
		return
	_place_gil(Vector3(0.0, -5.0, 0.0))
	if _gil != null and is_instance_valid(_gil):
		_gil.basis = _panda_hpr(0.0, 0.0, 0.0)
		_gil.visible = false
	if _root.get_node_or_null("GilSuit") != null:
		return
	var do_id := 0
	if _boss != null and _boss.has_method("ceo_do_id"):
		do_id = int(_boss.call("ceo_do_id"))
	if do_id <= 0:
		return
	var bosses: Array = [
		{"code": "f", "name": "Flunky", "body": "c", "height": 4.88},
		{"code": "p", "name": "Pencil Pusher", "body": "b", "height": 5.0},
		{"code": "ym", "name": "Yesman", "body": "a", "height": 5.28},
		{"code": "mm", "name": "Micromanager", "body": "c", "height": 3.25},
		{"code": "ds", "name": "Downsizer", "body": "b", "height": 6.08},
		{"code": "hh", "name": "Head Hunter", "body": "a", "height": 7.45},
		{"code": "cr", "name": "Corporate Raider", "body": "c", "height": 8.23},
		{"code": "tbc", "name": "The Big Cheese", "body": "a", "height": 9.34},
	]
	var picked: Dictionary = bosses[_py2_suit(do_id)]
	var suit := StreetCog.new()
	suit.name = "GilSuit"
	_root.add_child(suit)
	suit.present({
		"code": String(picked.get("code", "f")),
		"name": String(picked.get("name", "Flunky")),
		"dept": "c",
		"body": String(picked.get("body", "c")),
		"height": float(picked.get("height", 4.88)),
		"level": 1,
		"hp": 1,
		"max": 1,
	}, {})
	suit.set_process(false)
	if suit.has_method("_release_nametag"):
		suit.call("_release_nametag")
	suit.global_position = _root.to_global(Vector3(0.0, -5.0, 0.0))
	var ahead := _root.to_global(Vector3(0.0, 10.0, 0.0))
	ahead.y = suit.global_position.y
	if suit.global_position.distance_squared_to(ahead) > 0.04:
		suit.look_at(ahead, Vector3.UP)
	suit.force_update_transform()
	_tag_npc(suit, "Good ol' Gil Giggles")


func _hide_gil_suit() -> void:
	if _root != null:
		var suit := _root.get_node_or_null("GilSuit") as Node3D
		if suit != null:
			_release_npc(suit)
			suit.queue_free()
		var tag := _root.get_node_or_null("GilSuitTag")
		if tag != null:
			tag.queue_free()
	_hide_gil()


func _ceo_line(index: int) -> void:
	if index < 0 or index >= _pages.size() or _pages[index].is_empty():
		return
	_tell(_pages[index])


func _tick_intro_movie(delta: float) -> void:
	_aim_intro_movie()
	# placeToonInElevator. BigElevatorPoints[0], facing out of the car.
	if _ceo_beat < 2:
		_stand_in_elevator()
	if _ceo_beat < 1 and _act_t >= 3.0:
		_ceo_beat = 1
		_ceo_line(1)
	if _ceo_beat < 2 and _act_t >= 6.0:
		_ceo_beat = 2
		_tell("")
		_puff_dust()
		_strip_at = _clock + 0.3
	if _ceo_beat < 3 and _act_t >= 9.0:
		_ceo_beat = 3
		_ceo_line(2)
	if _ceo_beat < 4 and _act_t >= 12.0:
		_ceo_beat = 4
		_gil_job = "intro_leave"
		_gil_age = 0.0
	if _gil_job == "intro_leave":
		_tick_gil_walk(delta)
	if _ceo_beat < 5 and _act_t >= 18.5:
		_ceo_beat = 5
		_tell("")
		_finish_gil_walk()


func _tick_banquet_movie(delta: float) -> void:
	_aim_banquet_movie()
	if _ceo_beat < 1 and _act_t >= 3.0:
		_ceo_beat = 1
		_tell("")
		_puff_dust()
		_suit_at = _clock + 0.3
	if _ceo_beat < 2 and _act_t >= 4.0:
		_ceo_beat = 2
		_place_ceo_at(20.0)
		_swing_door(90.0, 2.0)
	if _ceo_beat < 3 and _act_t >= 6.0:
		_ceo_beat = 3
		_ceo_line(1)
	if _ceo_beat < 4 and _act_t >= 9.0:
		_ceo_beat = 4
		_ceo_line(2)
	if _ceo_beat < 5 and _act_t >= 12.0:
		_ceo_beat = 5
		_swing_door(0.0, 2.0)
	if _ceo_beat < 6 and _act_t >= 14.0:
		_ceo_beat = 6
		_place_ceo_at(355.0)
		_ceo_line(3)
	if _ceo_beat < 7 and _act_t >= 17.0:
		_ceo_beat = 7
		_ceo_line(4)
	if _ceo_beat < 8 and _act_t >= 18.0:
		_ceo_beat = 8
		_swing_door(120.0, 2.0)
	if _ceo_beat < 9 and _act_t >= 20.0:
		_ceo_beat = 9
		_gil_job = "banquet_leave"
		_gil_age = 0.0
	if _gil_job == "banquet_leave":
		_tick_gil_walk(delta)
	if _ceo_beat < 10 and _act_t >= 23.5:
		_ceo_beat = 10
		_finish_gil_walk()


func _tick_threat_movie() -> void:
	_aim_threat_movie()
	if _ceo_beat < 1 and _act_t >= 3.0:
		_ceo_beat = 1
		_ceo_line(1)
	if _ceo_beat < 2 and _act_t >= 7.0:
		_ceo_beat = 2
		if not _threat_dusted:
			_threat_dusted = true
			_puff_dust()
			_strip_at = _clock + 0.3
	if _ceo_beat < 3 and _act_t >= 10.0:
		_ceo_beat = 3
		_ceo_line(3)
	if _ceo_beat < 4 and _act_t >= 13.0:
		_ceo_beat = 4
		_tell("")
		_normal_eyes()
		_mode = ""
		_page_next = ""
		_release_camera()
		_clear_waiter()
		if _boss != null:
			_boss.call("finish_ceo_threat")


func _tick_seltzer_movie() -> void:
	_aim_seltzer_movie()
	if _act_t >= 11.0:
		_scale_club(lerpf(0.01, 1.0, clampf((_act_t - 11.0) / 3.0, 0.0, 1.0)))
	if _ceo_beat < 1 and _act_t >= 4.0:
		_ceo_beat = 1
		_ceo_line(1)
	if _ceo_beat < 2 and _act_t >= 8.0:
		_ceo_beat = 2
		_hide_gil_suit()
		_banquet_door(0.0)
		_ceo_line(2)
	if _ceo_beat < 3 and _act_t >= 11.0:
		_ceo_beat = 3
		_ceo_line(3)
	if _ceo_beat < 4 and _act_t >= 14.0:
		_ceo_beat = 4
		_release_camera()
		_hide_gil_suit()
		_scale_club(1.0)
		_page_next = ""
		_mode = "seltzer"
		_golf = false
		_station = ""
		_play_music_file("res://assets/cog_hq/audio/BossBot_CEO_v2.ogg", "ceo2")
		_tell("Press E at a table bottle or a golf ball. Left and right aim. Hold the jump key, then release. E steps off. Snacks ride the belts.")


func _aim_intro_movie() -> void:
	var elev := Vector3(0.0, -100.544, 7.18258)
	var close := Vector3(0.0, -80.544, 5.18258)
	if _act_t < 3.0:
		var along := clampf(_act_t / 3.0, 0.0, 1.0)
		_aim_movie(elev.lerp(close, along), 0.0, lerpf(0.0, 5.0, along))
	elif _act_t < 6.0:
		_aim_movie(close, 0.0, 5.0)
	elif _act_t < 9.0:
		_aim_movie(Vector3(0.0, -69.0, 4.0), 180.0, 0.0)
	elif _act_t < 10.0:
		_aim_movie(close, 0.0, 5.0)
	elif _act_t < 12.0:
		var swing := clampf((_act_t - 10.0) / 2.0, 0.0, 1.0)
		_aim_movie(close, lerpf(0.0, -15.0, swing), 5.0)
	else:
		_aim_movie(close, -15.0, 5.0)


func _aim_banquet_movie() -> void:
	var gil_cam := Vector3(0.0, -42.0, 6.0)
	var boss_cam := Vector3(0.0, -20.0, 18.0)
	var side_cam := Vector3(5.0, -45.0, 12.0)
	if _act_t < 4.0:
		_aim_movie(gil_cam, 0.0, 0.0)
	elif _act_t < 6.0:
		var open := clampf((_act_t - 4.0) / 2.0, 0.0, 1.0)
		_aim_movie(gil_cam.lerp(boss_cam, open), 0.0, 0.0)
	elif _act_t < 12.0:
		_aim_movie(boss_cam, 0.0, 0.0)
	elif _act_t < 14.0:
		var aside := clampf((_act_t - 12.0) / 2.0, 0.0, 1.0)
		_aim_movie(boss_cam.lerp(side_cam, aside), lerpf(0.0, 10.0, aside), lerpf(0.0, -8.0, aside))
	else:
		_aim_movie(side_cam, 10.0, -8.0)


func _aim_threat_movie() -> void:
	if _act_t >= 6.0 and _act_t < 10.0:
		_aim_toon_front()
		return
	_aim_movie(Vector3(0.0, _ceo_panda_y() - 45.0, 5.0), 0.0, 14.0)


func _aim_seltzer_movie() -> void:
	if _act_t < 8.0:
		_aim_movie(Vector3(0.0, 8.0, 5.44), -180.0, 0.0)
		return
	_aim_movie(Vector3(0.0, _ceo_panda_y() - 45.0, 5.0), 0.0, 14.0)


func _aim_walk_in(body: CharacterBody3D) -> void:
	var actor := _toon_actor(body)
	var height := 3.0
	if actor != null and actor.has_method("clamped_height"):
		height = maxf(float(actor.call("clamped_height")), 3.0)
	var forward := Vector3(0.0, 0.0, -1.0)
	if actor != null:
		forward = actor.global_transform.basis.y
		forward.y = 0.0
		if forward.length_squared() > 0.01:
			forward = forward.normalized()
		else:
			forward = Vector3(0.0, 0.0, -1.0)
	var from := body.global_position - forward * (9.0 * height * 0.333333) + Vector3.UP * height
	_aim_world(from, body.global_position + forward * 1.5 + Vector3.UP * height)


func _sad_eyes() -> void:
	var actor := _toon_actor()
	if actor != null:
		actor.set_expression("sad")
	_eyes_back = _clock + 0.7


func _normal_eyes() -> void:
	if _eyes_back < 0.0:
		return
	_eyes_back = -1.0
	var actor := _toon_actor()
	if actor != null:
		actor.set_expression("normal")


func _fight_ids() -> Array[int]:
	var ids: Array[int] = [ToonNet.peer_id()]
	var host: Node = _boss.get_parent() if _boss != null else null
	if host != null:
		for node in host.find_children("*", "ToonActor", true, false):
			var peer := int(node.get_meta("peer", 0))
			if peer > 0 and not ids.has(peer):
				ids.append(peer)
	ids.sort()
	return ids


func _tick_walk_in(delta: float) -> void:
	var body := _body()
	if body == null or _root == null:
		_finish_walk_in()
		return
	_aim_walk_in(body)
	if not _walk_ready:
		_walk_from = _root.to_local(body.global_position)
		_walk_floor = body.global_position.y
		_walk_ready = true
	_gil_age += delta
	var ids := _fight_ids()
	var slot := ids.find(ToonNet.peer_id())
	if slot < 0:
		slot = 0
	var span := float(maxi(ids.size() - 1, 0)) + 7.0
	if _gil_age >= span:
		_finish_walk_in()
		return
	var age := _gil_age - float(slot)
	if age < 0.0:
		return
	var mid := Vector3(0.0, 0.0, 0.0)
	var dest := Vector3(-14.0 + float(slot) * 4.0, 25.0, 0.0)
	var panda := dest
	var face := dest
	var moving := true
	if age < 3.0:
		panda = _walk_from.lerp(mid, clampf(age / 3.0, 0.0, 1.0))
		face = mid
	elif age < 6.0:
		panda = mid.lerp(dest, clampf((age - 3.0) / 3.0, 0.0, 1.0))
		face = dest
	elif age < 7.0:
		moving = false
	else:
		moving = false
	var world := _root.to_global(Vector3(panda.x, panda.y, 0.0))
	world.y = _walk_floor
	body.velocity = Vector3.ZERO
	body.global_position = world
	var host := _boss.get_parent() if _boss != null else null
	var toon := host.get_node_or_null("PlaygroundToon") if host != null else null
	if toon != null and toon.has_method("aim_fishing"):
		if moving:
			var look := _root.to_global(Vector3(face.x, face.y, 0.0))
			var flat := look - body.global_position
			flat.y = 0.0
			if flat.length_squared() > 0.0001:
				toon.call("aim_fishing", rad_to_deg(atan2(flat.x, -flat.z)))
		else:
			toon.call("aim_fishing", 0.0)
	var actor := _toon_actor(body)
	if actor != null:
		actor.set_locomotion(4.8 if moving else 0.0, false, false, delta)


func _tick_gil_walk(delta: float) -> void:
	if _gil == null or not is_instance_valid(_gil):
		_finish_gil_walk()
		return
	_gil_age += delta
	_gil.visible = true
	if _gil_job == "intro_leave":
		var turn := clampf(_gil_age / 1.0, 0.0, 1.0)
		_gil.basis = _panda_hpr(lerpf(180.0, 270.0, turn), 0.0, 0.0)
		if _gil_age >= 3.5:
			_gil.position = Vector3(40.0, -64.0, 0.0)
			_gil.set_locomotion(0.0, false, false, delta)
		elif _gil_age > 1.0:
			var walk := clampf((_gil_age - 1.0) / 2.5, 0.0, 1.0)
			_gil.position = Vector3(lerpf(0.0, 40.0, walk), -64.0, 0.0)
			_gil.play_walk(delta)
		return
	var turn_out := clampf(_gil_age / 1.0, 0.0, 1.0)
	_gil.basis = _panda_hpr(lerpf(180.0, 90.0, turn_out), 0.0, 0.0)
	if _gil_age >= 3.5:
		_gil.position = Vector3(-40.0, -20.0, 0.0)
		_gil.set_locomotion(0.0, false, false, delta)
	elif _gil_age > 1.0:
		var walk_out := clampf((_gil_age - 1.0) / 2.5, 0.0, 1.0)
		_gil.position = Vector3(lerpf(0.0, -40.0, walk_out), -20.0, 0.0)
		_gil.play_walk(delta)


func _finish_gil_walk() -> void:
	var job := _gil_job
	_gil_job = ""
	_hide_gil()
	if job == "intro_leave":
		_mode = ""
		_release_camera()
		if _boss != null:
			_boss.call("finish_ceo_intro")
		return
	if job != "banquet_leave":
		return
	_gil_job = "walk_in"
	_gil_age = 0.0
	_walk_ready = false
	_release_camera()
	_lock_toon()
	return


func _finish_walk_in() -> void:
	_gil_job = ""
	_banquet_door(0.0)
	var body := _body()
	var actor := _toon_actor(body) if body != null else null
	if actor != null:
		actor.set_locomotion(0.0, false, false, 0.0)
	_free_toon()
	_mode = "banquet"
	_carry = false
	if _suit_at >= 0.0:
		_wear_waiter()
		_suit_at = -1.0
	play_music("ceo")
	_tell("Walk into a can on the conveyor. Serve it to a hungry cog. Three plates in a row make it explode.")


func _upright_table() -> int:
	var choices: Array[int] = []
	if _root == null:
		return -1
	var count := _bottle_count()
	for index in count:
		var bottle := _root.get_node_or_null("Bottle%d" % index) as Node3D
		if bottle == null:
			continue
		var table_index := int(bottle.get_meta("table", -1))
		if table_index >= 0 and not _table_is_flat(table_index):
			choices.append(table_index)
	if choices.is_empty():
		return -1
	return choices[randi() % choices.size()]


func _face_ceo(target: Vector3, span: float) -> void:
	if _root == null:
		return
	var ceo := _root.get_node_or_null("CEO") as Node3D
	if ceo == null:
		return
	var flat := ceo.to_local(target)
	if Vector2(flat.x, flat.y).length() < 0.2:
		return
	_face_return = -1.0
	_face_from = _face_now
	_face_to = rad_to_deg(atan2(-flat.x, flat.y))
	_face_age = 0.0
	_face_span = maxf(span, 0.05)


func _arm_face_return(delay: float) -> void:
	_face_return = _clock + delay


func _tick_face(delta: float) -> void:
	if _spin_span > 0.0:
		_tick_spin(delta)
		return
	if _face_span <= 0.0:
		if _face_return >= 0.0 and _clock >= _face_return and not _crushing and _fore_phase == 0:
			_face_from = _face_now
			_face_to = 0.0
			_face_age = 0.0
			_face_span = 0.2
			_face_return = -1.0
		else:
			return
	if _root == null or _crushing:
		return
	var ceo := _root.get_node_or_null("CEO") as Node3D
	if ceo == null:
		return
	_face_age += delta
	var along := clampf(_face_age / _face_span, 0.0, 1.0)
	_face_now = rad_to_deg(lerp_angle(deg_to_rad(_face_from), deg_to_rad(_face_to), along))
	_apply_heading()
	if along >= 1.0:
		_face_span = 0.0


func _tick_spin(delta: float) -> void:
	_spin_age += delta
	var along := clampf(_spin_age / maxf(_spin_span, 0.05), 0.0, 1.0)
	_face_now = _spin_from + _spin_add * along
	_apply_heading()
	if along >= 1.0:
		_spin_span = 0.0


func _ceo_torso(ceo: Node3D) -> Node3D:
	var torso := ceo.find_child("bossbotBoss-torso-zero.egg", true, false) as Node3D
	if torso != null:
		return torso
	return ceo.find_child("bossCog-torso", true, false) as Node3D


func _apply_heading() -> void:
	if _root == null:
		return
	var ceo := _root.get_node_or_null("CEO") as Node3D
	if ceo == null:
		return
	# BossCog attaches the torso to joint_pelvis and turns that part. The treads stay.
	var torso := _ceo_torso(ceo)
	var part: Node3D = ceo
	if torso != null:
		part = torso
	if not part.has_meta("rest_basis"):
		part.set_meta("rest_basis", part.basis)
	var rest := part.get_meta("rest_basis") as Basis
	part.basis = Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(_face_now)) * rest


func _spin_ceo(extra: float, span: float) -> void:
	_spin_from = _face_now
	_spin_add = extra
	_spin_age = 0.0
	_spin_span = maxf(span, 0.05)
	_face_span = 0.0


func _tint_club() -> void:
	if not _over_one or _root == null:
		return
	var ceo := _root.get_node_or_null("CEO") as Node3D
	if ceo == null:
		return
	# colorScaleInterval(0.1, green or red) then colorScaleInterval(0.3, white), looped.
	var cycle := fposmod(_clock, 0.4)
	var hot := Color(1.0, 0.0, 0.0, 1.0) if _over_two else Color(0.0, 1.0, 0.0, 1.0)
	var tint := Color.WHITE
	if cycle < 0.1:
		tint = Color.WHITE.lerp(hot, cycle / 0.1)
	else:
		tint = hot.lerp(Color.WHITE, (cycle - 0.1) / 0.3)
	for part_name in ["golfclub", "club_handle", "club_head"]:
		var part := ceo.find_child(part_name, true, false)
		if part != null:
			_tint_meshes(part, tint)


func _tint_meshes(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var mat := mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat == null:
			var active := mesh.get_active_material(0)
			if active is StandardMaterial3D:
				mat = (active as StandardMaterial3D).duplicate()
			else:
				mat = StandardMaterial3D.new()
			mesh.set_surface_override_material(0, mat)
		mat.albedo_color = color
	for child in node.get_children():
		_tint_meshes(child, color)


func holds_camera() -> bool:
	return _epilogue_on or (_golf and _mode == "seltzer")


func aim(camera: Camera3D) -> void:
	if _epilogue_on and _gil != null and is_instance_valid(_gil) and _gil.get_parent() != null:
		var want := _gil.to_global(Vector3(-9.0, 12.0, 6.0))
		camera.global_position = camera.global_position.lerp(want, 0.12)
		var face := _gil.to_global(Vector3(0.0, 0.0, 3.0))
		if camera.global_position.distance_squared_to(face) > 0.04:
			camera.look_at(face, Vector3.UP)
		return
	var node := _station_node()
	if node == null or _root == null or camera == null:
		return
	var back := Vector3(0.0, -50.0, 40.0)
	if _station == "tee":
		back = Vector3(0.0, -10.0, 3.0)
	var want := _root.to_global(node.position + back)
	camera.global_position = camera.global_position.lerp(want, 0.12)
	var look := node.global_position + Vector3.UP * 2.0
	if camera.global_position.distance_squared_to(look) > 0.04:
		camera.look_at(look, Vector3.UP)


func _tick_board(delta: float, body: CharacterBody3D) -> void:
	var node := _station_node()
	if node == null:
		return
	var spot := node.global_position + Vector3.UP * 1.6
	if _station == "tee":
		spot = node.to_global(Vector3(-2.0, 0.0, 0.2))
	var actor := _toon_actor(body)
	body.velocity = Vector3.ZERO
	if _board_age < _board_span:
		_board_age += delta
		var along := clampf(_board_age / _board_span, 0.0, 1.0)
		var hop := 0.0
		if _station == "bottle":
			var rise := clampf((_board_age - 0.43) / 0.9, 0.0, 1.0)
			along = rise
			hop = sin(rise * PI) * 3.0
			if actor != null:
				actor.pose_action("jump", _board_age)
		else:
			hop = sin(along * PI) * 0.4
			if actor != null:
				actor.play_walk(delta)
		body.global_position = _board_from.lerp(spot, along) + Vector3.UP * hop
		return
	body.global_position = spot
	if _station == "tee":
		_show_putter(body)
		if _swing_age >= 0.0:
			_tick_swing(delta, node, actor)
		else:
			_aim_putter(node)
			if actor != null:
				actor.pose_synced_loop("loop-putt")
				if actor.action_length("loop-putt") <= 0.0:
					actor.set_locomotion(0.0, false, false, delta)
	else:
		_hide_putter()
		if actor != null:
			actor.pose_action("leverNeutral", 0.0)


func _release_board(body: Node) -> void:
	_board_span = 0.0
	_board_age = 0.0
	if body == null:
		return
	var actor := _toon_actor(body)
	if actor != null:
		actor.release_pose()


func _toon_actor(body: Node = null) -> ToonActor:
	if body == null:
		body = _body()
	if body == null:
		return null
	for child in body.get_children():
		if child is ToonActor:
			return child
	return null


func _show_putter(body: Node3D) -> void:
	if _putter != null and is_instance_valid(_putter):
		return
	var packed := load("res://assets/minigolf/putter.glb") as PackedScene
	if packed == null:
		return
	_putter = packed.instantiate() as Node3D
	if _putter == null:
		return
	var actor := _toon_actor(body)
	var hand: Node3D = null
	if actor != null:
		hand = actor.find_child("def_joint_left_hold", true, false) as Node3D
	var host: Node3D = body
	if hand != null:
		host = hand
	host.add_child(_putter)
	if hand != null:
		# attachClub sets the putter on the left hand, offset -0.25 on the hand's X.
		_putter.position = Vector3(-0.25, 0.0, 0.0)
	else:
		_putter.position = Vector3(0.35, 1.05, 0.2)
		_putter.rotation_degrees = Vector3(70.0, 0.0, 90.0)


func _aim_putter(tee: Node3D) -> void:
	if _putter == null or not is_instance_valid(_putter) or tee == null:
		return
	var spot := tee.global_position
	if _putter.global_position.distance_squared_to(spot) > 0.04:
		_putter.look_at(spot, Vector3.UP)
	# adjustClub stretches the shaft so the head reaches the ball. 2.058 is the putter length.
	var reach := _putter.global_position.distance_to(spot)
	_putter.scale = Vector3(1.0, 1.0, maxf(reach, 0.2) / 2.058)


func _begin_swing(power: float) -> void:
	var actor := _toon_actor()
	if actor == null or actor.action_length("swing-putt") <= 0.0:
		_fire_ball(power)
		return
	_swing_age = 0.0
	_swing_power = power
	_swing_sent = false
	_tee_grow = -1.0
	if _putter != null and is_instance_valid(_putter):
		_putter.scale = Vector3.ONE


func _tick_swing(delta: float, tee: Node3D, actor: ToonActor) -> void:
	_swing_age += delta
	if actor != null:
		actor.pose_action("swing-putt", _swing_age)
	# BALL_CONTACT_FRAME is 9. The resting ball hides when the club meets it.
	if not _swing_sent and _swing_age >= 9.0 / 24.0:
		_swing_sent = true
		_fire_ball(_swing_power)
		if tee != null:
			tee.visible = false
	if _swing_age < 1.0:
		return
	if _tee_grow < 0.0:
		_tee_grow = 0.0
		if tee != null:
			tee.visible = true
			tee.scale = Vector3.ONE * 0.1
	_tee_grow += delta
	if tee != null:
		tee.scale = Vector3.ONE * lerpf(0.1, 1.0, clampf(_tee_grow, 0.0, 1.0))
	if _tee_grow < 1.0:
		return
	if tee != null:
		tee.scale = Vector3.ONE
		tee.visible = true
	_swing_age = -1.0
	_tee_grow = -1.0


func _hide_putter() -> void:
	if _swing_age >= 0.0 or _tee_grow >= 0.0:
		var tee := _station_node()
		if tee != null:
			tee.visible = true
			tee.scale = Vector3.ONE
	_swing_age = -1.0
	_tee_grow = -1.0
	_swing_sent = false
	if _putter != null and is_instance_valid(_putter):
		_putter.queue_free()
	_putter = null


func _show_spray(origin: Vector3, target: Vector3) -> void:
	if _root == null:
		return
	var packed := load("res://assets/battle/props/spray.glb") as PackedScene
	if packed == null:
		return
	var mesh := packed.instantiate() as Node3D
	if mesh == null:
		return
	_root.add_child(mesh)
	var length := clampf(origin.distance_to(target), 1.0, 36.0)
	mesh.global_position = origin
	if origin.distance_squared_to(target) > 0.04:
		mesh.look_at(target, Vector3.UP)
		mesh.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	mesh.scale = Vector3(0.05, 0.05, 0.05)
	_water.append({"mesh": mesh, "age": 0.0, "length": length / 1.5})


func _tick_water(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for spray in _water:
		var age := float(spray.get("age", 0.0)) + delta
		spray["age"] = age
		var mesh := spray.get("mesh") as Node3D
		var length := float(spray.get("length", 1.0))
		if mesh != null and age < 0.55:
			var grow := clampf(age / 0.2, 0.0, 1.0)
			if age > 0.4:
				grow = clampf(1.0 - (age - 0.4) / 0.15, 0.05, 1.0)
			mesh.scale = Vector3(length * grow, length * grow, length * grow)
			kept.append(spray)
		elif mesh != null:
			mesh.queue_free()
	_water = kept


func _stand_in_elevator() -> void:
	var body := _body()
	var elev := _find("elevator_origin")
	if body == null or elev == null:
		return
	var spot := elev.to_global(Vector3(-2.5, 9.0, 0.1))
	body.velocity = Vector3.ZERO
	body.global_position = spot
	var ahead := elev.to_global(Vector3(-2.5, 8.0, 0.1))
	var flat := ahead - spot
	flat.y = 0.0
	var host := _boss.get_parent() if _boss != null else null
	var toon := host.get_node_or_null("PlaygroundToon") if host != null else null
	if flat.length_squared() > 0.01 and toon != null and toon.has_method("aim_fishing"):
		toon.call("aim_fishing", rad_to_deg(atan2(flat.x, -flat.z)))
	var actor := _toon_actor(body)
	if actor != null:
		if actor.get_parent() != body:
			actor.reparent(body)
			actor.position = Vector3.ZERO
		actor.visible = true
	_lock_toon()
	if toon != null and toon.has_method("wear_bossbot_suit"):
		toon.call("wear_bossbot_suit")


func _place_gil(at: Vector3) -> void:
	var parent: Node3D = _root if _root != null else _geometry()
	if parent == null:
		return
	if _gil == null or not is_instance_valid(_gil):
		_gil = ToonActor.new()
		_gil.name = "Gil"
		parent.add_child(_gil)
		var style := ToonStyle.new()
		style.first_name = "Good ol' Gil"
		style.last_name = "Giggles"
		style.gender = "m"
		style.head = "sls"
		style.torso = "ms"
		style.legs = "l"
		style.top_tex = 0
		style.top_color = 3
		style.bot_tex = 1
		style.bot_color = 11
		style.arm_color = 15
		style.glove_color = 0
		style.leg_color = 15
		style.head_color = 15
		_gil.show_style(style)
	_gil.visible = true
	_gil.position = at
	_gil.basis = _panda_hpr(180.0, 0.0, 0.0)
	_tag_gil()


func _tag_gil() -> void:
	if _gil == null or not is_instance_valid(_gil) or _gil.has_meta("named"):
		return
	_gil.force_update_transform()
	if _tag_npc(_gil, "Good ol' Gil Giggles"):
		_gil.set_meta("named", true)


func _tag_npc(actor: Node3D, text: String) -> bool:
	if actor == null or _boss == null:
		return false
	var host := _boss.get_parent()
	var tags := host.find_child("Nametags", true, false) if host != null else null
	if tags == null or not tags.has_method("add"):
		return false
	tags.call("add", actor, text, "npc")
	return true


func _release_npc(actor: Node3D) -> void:
	if actor == null or _boss == null:
		return
	var host := _boss.get_parent()
	var tags := host.find_child("Nametags", true, false) if host != null else null
	if tags != null and tags.has_method("release"):
		tags.call("release", actor)


func _hide_gil() -> void:
	if _gil != null and is_instance_valid(_gil):
		_gil.visible = false


func _banquet_door(heading: float) -> void:
	var door := _find("door3")
	if door == null:
		return
	if not door.has_meta("closed_basis"):
		door.set_meta("closed_basis", door.basis)
	var closed := door.get_meta("closed_basis") as Basis
	door.basis = Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(heading)) * closed
	door.set_meta("heading", heading)


func _belt_point(index: int) -> Vector3:
	var finish := _find("conveyer_belt_end_%d" % (index + 1))
	if finish != null:
		return finish.global_position
	if index < _belts.size():
		return _belts[index]
	return _boss_pos


func _start_fore(body: CharacterBody3D) -> void:
	_attack_kind = "area"
	_begin_fore_show()
	var first := _ceo_shots.size()
	for target in _fore_targets(body):
		_queue_fore_balls(target)
	_remember_volley("fore", first)


func _begin_fore_show() -> void:
	_tell("Fore!")
	_sfx("res://assets/audio/sfx/Skel_COG_VO_grunt.ogg")
	_face_return = -1.0
	_face_span = 0.0
	_fore_heading = _face_now
	_fore_phase = 1
	_fore_left = 2.0
	_spin_ceo(360.0, 2.0)
	if _ceo_raised:
		_ceo_clip = ""
		_play_ceo("Ff_neutral", true)
	else:
		_ceo_raised = true
		_play_ceo("Fb_down2Up", false, "Ff_neutral")


func _tick_fore(delta: float) -> void:
	if _fore_phase == 0:
		return
	_fore_left -= delta
	if _fore_left > 0.0:
		return
	if _fore_phase == 1:
		_fore_phase = 2
		_fore_left = 2.0
		_spin_ceo(1440.0, 2.0)
		_play_ceo("golf_swing", false, "Ff_neutral")
		return
	_fore_phase = 0
	_spin_span = 0.0
	_face_now = 0.0
	_apply_heading()


func _fore_targets(body: CharacterBody3D) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	if body != null:
		spots.append(body.global_position + Vector3.UP * 3.0)
	var host: Node = _boss.get_parent() if _boss != null else null
	if host != null:
		for node in host.find_children("*", "ToonActor", true, false):
			if int(node.get_meta("peer", 0)) <= 0:
				continue
			var actor := node as Node3D
			if actor != null and actor.visible:
				spots.append(actor.global_position + Vector3.UP * 3.0)
	if spots.is_empty():
		spots.append(_boss_pos + Vector3.UP * 3.0)
	return spots


func _shot_axes(target: Vector3) -> Dictionary:
	var origin := _boss_pos + Vector3.UP * 10.0
	var flat := target - origin
	flat.y = 0.0
	var forward := Vector3(0.0, 0.0, -1.0)
	if flat.length_squared() > 0.01:
		forward = flat.normalized()
	var right := Vector3.UP.cross(forward)
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	return {"origin": origin, "forward": forward, "right": right}


func _queue_fore_balls(target: Vector3) -> void:
	var axes := _shot_axes(target)
	var origin: Vector3 = axes["origin"]
	var forward: Vector3 = axes["forward"]
	var right: Vector3 = axes["right"]
	var launch := origin + right * 10.5 + forward * 8.5 - Vector3.UP * 5.0
	var distance := launch.distance_to(target)
	for index in 5:
		var lateral := randf_range(-5.0, 5.0)
		var lift := randf_range(-3.0, 3.0)
		var extra := randf_range(5.0, 15.0)
		if index == 2:
			lateral = 0.0
			lift = 0.0
			extra = 10.0
		var dest := origin + right * lateral + forward * (distance + extra) + Vector3.UP * lift
		var mesh := _ceo_ball()
		mesh.visible = false
		_ceo_shots.append({
			"from": launch,
			"to": dest,
			"age": 0.0,
			"wait": 2.0 + 26.0 / 24.0 + float(index) * 0.15,
			"mesh": mesh,
			"kind": "fore",
			"hurt": false,
			"spin": randf_range(-720.0, -90.0),
			"pitch": true,
		})


func _tick_zap(delta: float, body: CharacterBody3D) -> void:
	if _zap_left > 0.0 and body != null:
		_zap_left = maxf(_zap_left - delta, 0.0)
		var actor := _toon_actor(body)
		if actor != null:
			actor.pose_action(_zap_clip, 1.0 - _zap_left)
	if _slide_left <= 0.0 or body == null:
		return
	_slide_left = maxf(_slide_left - delta, 0.0)
	var along := clampf(1.0 - _slide_left / 0.5, 0.0, 1.0)
	var spot := _slide_from.lerp(_slide_to, along)
	spot.y = body.global_position.y
	body.global_position = spot
	body.velocity = Vector3.ZERO


func _zap_fore() -> void:
	if _clock < _fore_safe:
		return
	_fore_safe = _clock + 1.0
	_boss.call("note_golf", true)
	var body := _body()
	var roaming := not _golf
	_zap_clip = "slip-backward" if roaming else "slip-forward"
	_zap_left = 1.0
	if not roaming or body == null:
		return
	var to_ceo := _boss_pos - body.global_position
	to_ceo.y = 0.0
	if to_ceo.length_squared() > 0.04:
		var heading := rad_to_deg(atan2(to_ceo.x, -to_ceo.z))
		var toon := _playground_toon()
		if toon != null and toon.has_method("aim_fishing"):
			toon.call("aim_fishing", heading)
	var back := -body.global_transform.basis.y
	back.y = 0.0
	if back.length_squared() < 0.01:
		back = Vector3(0.0, 0.0, 1.0)
	else:
		back = back.normalized()
	_slide_from = body.global_position
	_slide_to = body.global_position + back * 5.0
	_slide_left = 0.5


func _swing_club(target: Vector3) -> void:
	_wind_up("golf_swing", target)


func _wind_up(attack: String, target: Vector3) -> float:
	_face_ceo(target, 1.0)
	if _ceo_raised:
		_play_ceo(attack, false, "Ff_neutral")
		return 0.0
	_ceo_raised = true
	_play_ceo("Fb_down2Up", false, attack)
	return _ceo_span("Fb_down2Up")


func _play_ceo(clip: String, looping: bool, then_clip: String = "") -> void:
	if clip == _ceo_clip and looping == _ceo_loop and then_clip == _ceo_next:
		return
	_ceo_clip = clip
	_ceo_time = 0.0
	_ceo_loop = looping
	_ceo_next = then_clip if not looping else ""
	if clip == "golf_swing":
		_hardball_left = 0.85


func _ceo_span(clip: String) -> float:
	_load_ceo_rates()
	var frames := float(_ceo_frames.get(clip, 24))
	var rate := float(_ceo_rates.get(clip, 24.0))
	var bank: Dictionary = _ceo_banks.get(clip, {})
	if int(bank.get("frames", 0)) > 1:
		frames = float(bank["frames"])
	if rate <= 0.0:
		rate = 24.0
	return frames / rate


func _load_ceo_rates() -> void:
	if not _ceo_rates.is_empty():
		return
	var path := "res://assets/cogs/bosses/ceo_anims/clips.json"
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		for key in parsed:
			var row: Dictionary = parsed[key]
			_ceo_rates[String(key)] = float(row.get("fps", 24.0))
			_ceo_frames[String(key)] = int(row.get("frames", 24))


func _advance_ceo_pose(delta: float) -> void:
	if _hardball_left >= 0.0:
		_hardball_left -= delta
		if _hardball_left <= 0.0:
			_hardball_left = -1.0
			_play_hardball()
	if _hardball_play >= 0.0:
		_hardball_play -= delta
		if _hardball_play <= 0.0:
			_hardball_play = -1.0
			if _hardball != null and is_instance_valid(_hardball):
				_hardball.stop()
				_hardball.queue_free()
				_hardball = null
	if _root == null or _ceo_clip == "":
		return
	var ceo := _root.get_node_or_null("CEO") as Node3D
	if ceo == null:
		return
	var path := "res://assets/cogs/bosses/ceo_anims/%s.walk" % _ceo_clip
	if not FileAccess.file_exists(path):
		return
	if not _ceo_banks.has(_ceo_clip):
		if _poser == null:
			_poser = StreetCog.new()
		_load_ceo_rates()
		var loaded: Variant = _poser.call("_read_bank", path, ceo)
		if loaded is Dictionary:
			_ceo_banks[_ceo_clip] = loaded
	var bank: Dictionary = _ceo_banks.get(_ceo_clip, {})
	var frames := int(bank.get("frames", 0))
	if frames <= 1 or _poser == null:
		return
	var fps := float(_ceo_rates.get(_ceo_clip, 24.0))
	_ceo_time += delta
	_poser.call("_pose_elapsed", bank, _ceo_time, fps, _ceo_loop)
	if _ceo_loop:
		return
	if _ceo_time < float(frames) / fps:
		return
	var follow := _ceo_next
	_ceo_next = ""
	if follow == "":
		_play_ceo("Ff_neutral", true)
	elif follow == "Ff_neutral":
		_play_ceo("Ff_neutral", true)
	else:
		_play_ceo(follow, false, "Ff_neutral")


func _throw_gears(target: Vector3, kind: String) -> void:
	var first := _ceo_shots.size()
	var axes := _shot_axes(target)
	var origin: Vector3 = axes["origin"]
	var forward: Vector3 = axes["forward"]
	var right: Vector3 = axes["right"]
	var distance := _boss_pos.distance_to(target)
	var windup := _wind_up("Fb_UpThrow", target)
	_sfx("res://assets/cogs/bosses/audio/CHQ_VP_frisbee_gears.ogg")
	for index in 4:
		var lateral := randf_range(-5.0, 5.0)
		var lift := randf_range(-3.0, 3.0)
		if index == 2:
			lateral = 0.0
			lift = 0.0
		var mesh := _gear(0.2)
		mesh.visible = false
		_ceo_shots.append({
			"from": origin + forward * 5.85 + Vector3.UP * 4.0,
			"to": origin + right * lateral + forward * distance + Vector3.UP * lift,
			"age": 0.0,
			"wait": windup + 0.19 + float(index) * 0.15,
			"mesh": mesh,
			"kind": kind,
			"hurt": index != 2,
			"spin": randf_range(-720.0, 720.0),
			"pitch": false,
		})
	_arm_face_return(windup + 0.19 + 0.45 + 1.0)
	_remember_volley(kind, first)


func _throw_balls(target: Vector3) -> void:
	var first := _ceo_shots.size()
	var axes := _shot_axes(target)
	var origin: Vector3 = axes["origin"]
	var forward: Vector3 = axes["forward"]
	var right: Vector3 = axes["right"]
	var launch := origin + right * 10.5 + forward * 8.5 - Vector3.UP * 5.0
	var distance := launch.distance_to(target)
	var windup := _wind_up("golf_swing", target)
	for index in 5:
		var lateral := randf_range(-5.0, 5.0)
		var lift := randf_range(-3.0, 3.0)
		var extra := randf_range(5.0, 15.0)
		if index == 2:
			lateral = 0.0
			lift = 0.0
			extra = 10.0
		var mesh := _ceo_ball()
		mesh.visible = false
		_ceo_shots.append({
			"from": launch,
			"to": origin + right * lateral + forward * (distance + extra) + Vector3.UP * lift,
			"age": 0.0,
			"wait": windup + 1.08 + float(index) * 0.15,
			"mesh": mesh,
			"kind": "ball",
			"hurt": index != 2,
			"spin": randf_range(-720.0, -90.0),
			"pitch": true,
		})
	_arm_face_return(windup + 1.08 + 0.60 + 1.0)
	_remember_volley("ball", first)


func _remember_fore(at: Vector3) -> void:
	if not ToonNet.networked() or not ToonNet.ceo_driving():
		return
	_attack_seq += 1
	_attack_log.append({
		"seq": _attack_seq,
		"kind": "fore",
		"x": at.x, "y": at.y, "z": at.z,
		"rows": [],
	})
	_trim_attacks()


func _remember_volley(kind: String, first: int) -> void:
	if not ToonNet.networked() or not ToonNet.ceo_driving():
		return
	var rows: Array = []
	for index in range(first, _ceo_shots.size()):
		var shot: Dictionary = _ceo_shots[index]
		var origin: Vector3 = shot["from"]
		var dest: Vector3 = shot["to"]
		rows.append({
			"fx": origin.x, "fy": origin.y, "fz": origin.z,
			"tx": dest.x, "ty": dest.y, "tz": dest.z,
			"wait": float(shot.get("wait", 0.0)),
			"kind": String(shot.get("kind", kind)),
			"hurt": bool(shot.get("hurt", false)),
			"spin": float(shot.get("spin", 0.0)),
			"pitch": bool(shot.get("pitch", false)),
		})
	_attack_seq += 1
	_attack_log.append({"seq": _attack_seq, "kind": kind, "rows": rows})
	_trim_attacks()


func _trim_attacks() -> void:
	while _attack_log.size() > 8:
		_attack_log.pop_front()


func _spawn_shared_shot(row: Dictionary, kind: String) -> void:
	var shot_kind := String(row.get("kind", kind))
	var mesh: Node3D
	if shot_kind == "ball" or shot_kind == "fore":
		mesh = _ceo_ball()
	else:
		mesh = _gear(0.2)
	mesh.visible = false
	_ceo_shots.append({
		"from": Vector3(float(row.get("fx", 0.0)), float(row.get("fy", 0.0)), float(row.get("fz", 0.0))),
		"to": Vector3(float(row.get("tx", 0.0)), float(row.get("ty", 0.0)), float(row.get("tz", 0.0))),
		"age": 0.0,
		"wait": float(row.get("wait", 0.0)),
		"mesh": mesh,
		"kind": shot_kind,
		"hurt": bool(row.get("hurt", false)),
		"spin": float(row.get("spin", 0.0)),
		"pitch": bool(row.get("pitch", false)),
	})


func _apply_attacks() -> void:
	var attacks: Array = ToonNet.latest("ceo-field").get("attacks", [])
	for item in attacks:
		if not (item is Dictionary):
			continue
		var seq := int(item.get("seq", 0))
		if seq <= _attack_seen:
			continue
		_attack_seen = seq
		var kind := String(item.get("kind", ""))
		if kind == "fore":
			_attack_kind = "area"
			_begin_fore_show()
			for row in item.get("rows", []):
				if row is Dictionary:
					_spawn_shared_shot(row, "fore")
			continue
		var rows: Array = item.get("rows", [])
		var aim := Vector3.ZERO
		if not rows.is_empty() and rows[0] is Dictionary:
			var sample: Dictionary = rows[0]
			aim = Vector3(float(sample.get("tx", 0.0)), float(sample.get("ty", 0.0)), float(sample.get("tz", 0.0)))
		if kind == "ball":
			_wind_up("golf_swing", aim)
		else:
			_wind_up("Fb_UpThrow", aim)
			_sfx("res://assets/cogs/bosses/audio/CHQ_VP_frisbee_gears.ogg")
		var latest := 0.0
		for row in rows:
			if row is Dictionary:
				_spawn_shared_shot(row, kind)
				latest = maxf(latest, float(row.get("wait", 0.0)))
		_arm_face_return(latest + 1.0)


func _tick_ceo_shots(delta: float, body: CharacterBody3D) -> void:
	var kept: Array[Dictionary] = []
	for shot in _ceo_shots:
		var age := float(shot.get("age", 0.0)) + delta
		shot["age"] = age
		var wait := float(shot.get("wait", 0.0))
		var mesh := shot.get("mesh") as Node3D
		if age < wait:
			kept.append(shot)
			continue
		var along := clampf((age - wait) / 1.0, 0.0, 1.0)
		var at: Vector3 = (shot["from"] as Vector3).lerp(shot["to"] as Vector3, along)
		if mesh != null:
			mesh.visible = true
			mesh.global_position = at
			_spin_shot(shot, mesh, along)
		var kind := String(shot.get("kind", ""))
		var reach := 2.2
		var flying := true
		if kind == "ball" or kind == "fore":
			reach = 4.0
			flying = along > 0.15
		if not bool(shot.get("hurt", false)) and flying and _near(body, at, reach):
			shot["hurt"] = true
			if kind == "overtime":
				_boss.call("note_overtime")
			elif kind == "gear":
				_boss.call("note_gear")
			elif kind == "fore":
				_zap_fore()
			else:
				_boss.call("note_golf", false)
		if along < 1.0:
			kept.append(shot)
		elif mesh != null:
			mesh.queue_free()
	_ceo_shots = kept


func _wear_waiter() -> void:
	var toon := _playground_toon()
	if toon != null and toon.has_method("wear_waiter"):
		toon.call("wear_waiter")


func _clear_waiter() -> void:
	var toon := _playground_toon()
	if toon != null and toon.has_method("clear_disguise"):
		toon.call("clear_disguise")


func _playground_toon() -> Node:
	if _boss == null:
		return null
	var host := _boss.get_parent()
	if host == null:
		return null
	return host.get_node_or_null("PlaygroundToon")


func _mounted_table() -> int:
	if not _golf or _station != "bottle":
		return -1
	return _station_table


func _banquet_by_index(index: int) -> Node3D:
	for table in _find_all("BanquetTable"):
		if int(table.get_meta("table_index", -1)) == index:
			return table
	return null


func _table_is_flat(index: int) -> bool:
	var table := _banquet_by_index(index)
	if table == null or not table.has_meta("flat_until"):
		return false
	return _clock < float(table.get_meta("flat_until"))


func _start_crush(index: int) -> void:
	var table := _banquet_by_index(index)
	if table == null or _table_is_flat(index):
		return
	_crushing = true
	_crush_table = index
	_crush_rider = _mounted_table() == index
	_crush_to = table.global_position
	_face_now = 0.0
	_face_span = 0.0
	_face_return = -1.0
	_spin_span = 0.0
	_apply_heading()
	if _ceo_clip == "" or _ceo_clip == "Ff_neutral":
		_play_ceo("Ff_neutral", true)
	_tell("The C.E.O. is heading for a table.")


func _tick_crush(delta: float, slowed: float) -> void:
	if not _crushing or _root == null:
		return
	if _crush_rider and _mounted_table() != _crush_table:
		_crush_rider = false
		if randf() < 0.5:
			_crushing = false
			_crush_table = -1
			_attack_now = true
			return
	var ceo := _root.get_node_or_null("CEO") as Node3D
	if ceo == null:
		_crushing = false
		return
	var speed := 22.0 - 14.5 * clampf(slowed / 90.0, 0.0, 1.0)
	var gap := ceo.global_position.distance_to(_crush_to)
	var step := speed * delta
	if gap <= maxf(step, 1.5):
		ceo.global_position = _crush_to
		_flatten_table(_crush_table)
		_crushing = false
		return
	var direction := _crush_to - ceo.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.04:
		ceo.global_position = _crush_to
		_flatten_table(_crush_table)
		_crushing = false
		return
	direction = direction.normalized()
	var turn := deg_to_rad(60.0 - 40.0 * clampf(slowed / 90.0, 0.0, 1.0))
	var facing := -ceo.global_transform.basis.z
	facing.y = 0.0
	var yaw := 0.0
	if facing.length_squared() > 0.01:
		yaw = facing.signed_angle_to(direction, Vector3.UP)
	var angle := absf(yaw)
	if angle > 0.12:
		var aimed := ceo.global_transform.looking_at(ceo.global_position + direction, Vector3.UP)
		var blend := clampf((turn * delta) / angle, 0.0, 1.0)
		ceo.global_basis = ceo.global_basis.slerp(aimed.basis, blend)
		_scroll_turn_treads(delta, yaw)
		return
	ceo.global_position += direction * step
	_scroll_roll_treads(delta, slowed)


func _spin_shot(shot: Dictionary, mesh: Node3D, along: float) -> void:
	var spin := float(shot.get("spin", 0.0))
	if absf(spin) < 0.01:
		return
	if not shot.has("rest"):
		shot["rest"] = mesh.basis
	var rest: Basis = shot["rest"]
	var axis := Vector3.UP
	if bool(shot.get("pitch", false)):
		var flight: Vector3 = shot["to"] - shot["from"]
		flight.y = 0.0
		if flight.length_squared() > 0.01:
			axis = Vector3.UP.cross(flight.normalized())
	if axis.length_squared() < 0.01:
		axis = Vector3.RIGHT
	mesh.basis = Basis(axis.normalized(), deg_to_rad(spin * along)) * rest


func _ceo_tread(node_name: String, left: bool) -> StandardMaterial3D:
	if _root == null:
		return null
	var ceo := _root.get_node_or_null("CEO") as Node3D
	if ceo == null:
		return null
	var mesh := ceo.find_child(node_name, true, false) as MeshInstance3D
	if mesh == null:
		return null
	var kept := _ceo_left_mat if left else _ceo_right_mat
	if kept == null or not is_instance_valid(kept):
		var source := mesh.get_surface_override_material(0) as StandardMaterial3D
		if source == null:
			var active := mesh.get_active_material(0)
			if active is StandardMaterial3D:
				source = active as StandardMaterial3D
		if source == null:
			return null
		kept = source.duplicate() as StandardMaterial3D
		if left:
			_ceo_left_mat = kept
		else:
			_ceo_right_mat = kept
	mesh.set_surface_override_material(0, kept)
	return kept


func _bump_tread(node_name: String, left: bool, amount: float) -> void:
	if left:
		_ceo_left_u += amount
	else:
		_ceo_right_u += amount
	var mat := _ceo_tread(node_name, left)
	if mat == null:
		return
	mat.uv1_offset.x = _ceo_left_u if left else _ceo_right_u


func _scroll_turn_treads(delta: float, yaw: float) -> void:
	# treadsLeft is the right_tread node. A turn runs the two belts opposite ways.
	var left_rate := -3.5
	if yaw < 0.0:
		left_rate = 3.5
	_bump_tread("right_tread", false, left_rate * delta)
	_bump_tread("left_tread", true, -left_rate * delta)


func _scroll_roll_treads(delta: float, slowed: float) -> void:
	var rate := 10.5 - 7.0 * clampf(slowed / 90.0, 0.0, 1.0)
	_bump_tread("right_tread", false, rate * delta)
	_bump_tread("left_tread", true, rate * delta)


func _tint_ceo_treads(slowed: float) -> void:
	var fraction := 1.0 - clampf(slowed / 90.0, 0.0, 1.0)
	var tint := Color(1.0, fraction, fraction, 1.0)
	var left := _ceo_tread("left_tread", true)
	var right := _ceo_tread("right_tread", false)
	if left != null:
		left.albedo_color = tint
	if right != null:
		right.albedo_color = tint


func _flatten_table(index: int) -> void:
	var table := _banquet_by_index(index)
	if table == null or _table_is_flat(index):
		return
	if not table.has_meta("saved_scale"):
		table.set_meta("saved_scale", table.scale)
	var saved := table.get_meta("saved_scale") as Vector3
	table.scale = Vector3(saved.x, saved.y, saved.z * 0.01)
	table.set_meta("flat_until", _clock + _flat_for)
	if _mounted_table() == index:
		_flat_return = index
		_golf = false
		_spray = 0.0
		_station = ""
		_hide_putter()
		_release_board(_body())
		_free_toon()
		if _boss != null:
			_boss.call("note_crush")


func start_ceo_victory(boss: Node) -> void:
	_boss = boss
	_mode = "ceo_victory"
	_clock = 0.0
	_ceo_win = 0
	_victory_done = false
	_golf = false
	_belt_sound(false)
	if _power_root != null:
		_power_root.visible = false
	_lock_toon()
	_play_music_file("res://assets/cog_hq/audio/BossBot_CEO_v2.ogg", "ceo2")
	_tell("No! The Chairman won't like this.")
	_aim_ceo_victory()


func _tick_ceo_victory(delta: float) -> void:
	if _victory_done:
		return
	_tick_chest(delta)
	_tick_puffs(delta)
	_aim_ceo_victory()
	if _ceo_win < 1 and _clock >= 3.0:
		_ceo_win = 1
		_tell("Arrrggghhh!!!!")
	elif _ceo_win < 2 and _clock >= 5.0:
		_ceo_win = 2
		_tell("")
		var ceo: Node3D = null
		if _root != null:
			ceo = _root.get_node_or_null("CEO") as Node3D
		_puff_dust(ceo, 4.0)
	elif _ceo_win < 3 and _clock >= 5.5:
		_ceo_win = 3
		_show_demoted()
	elif _ceo_win < 4 and _clock >= 5.0 + 19.0 / 12.0 + 2.0:
		_ceo_win = 4
		_victory_done = true
		_seat_gil_for_reward()
		_release_camera()
		if _boss != null:
			_boss.call("ceo_victory_done")


func _ceo_panda_y() -> float:
	if _root != null:
		var ceo := _root.get_node_or_null("CEO") as Node3D
		if ceo != null:
			return ceo.position.y
	return 355.0


func _aim_ceo_victory() -> void:
	_aim_movie(Vector3(0.0, _ceo_panda_y() - 35.0, 25.0), 0.0, -20.0)


func _show_demoted() -> void:
	if _root == null:
		return
	var ceo := _root.get_node_or_null("CEO") as Node3D
	if ceo == null:
		return
	ceo.visible = false
	if _root.get_node_or_null("Demoted") != null:
		return
	var suit := StreetCog.new()
	suit.name = "Demoted"
	_root.add_child(suit)
	suit.present({
		"code": "f",
		"name": "Flunky",
		"dept": "c",
		"body": "c",
		"height": 4.88,
		"level": 1,
		"hp": 1,
		"max": 1,
	}, {})
	suit.set_process(false)
	if suit.has_method("_release_nametag"):
		suit.call("_release_nametag")
	suit.global_position = ceo.global_position
	var back := -ceo.global_transform.basis.y
	back.y = 0.0
	if back.length_squared() > 0.01:
		suit.look_at(suit.global_position + back.normalized(), Vector3.UP)


func _seat_gil_for_reward() -> void:
	_place_gil(Vector3(0.0, 90.0, 0.0))
	var geom := _geometry()
	if _gil != null and is_instance_valid(_gil) and geom != null and _gil.get_parent() != geom:
		_gil.reparent(geom)
	if _gil != null and is_instance_valid(_gil):
		_gil.visible = true
		_gil.pose_action("sit", 0.0)


func pose_ceo_epilogue() -> void:
	var geom := _geometry()
	_place_gil(Vector3(0.0, 90.0, 0.0))
	if _gil == null or not is_instance_valid(_gil):
		return
	if geom != null and _gil.get_parent() != geom:
		geom.add_child(_gil)
	_gil.position = Vector3(0.0, 90.0, 0.0)
	_gil.basis = _panda_hpr(180.0, 0.0, 0.0)
	_gil.visible = true
	_gil.pose_action("sit", 0.0)
	var ceo := _root.get_node_or_null("CEO") if _root != null else null
	if ceo != null:
		ceo.visible = false
	var body := _body()
	if body != null and _gil.get_parent() != null:
		var parent := _gil.get_parent() as Node3D
		body.velocity = Vector3.ZERO
		body.global_position = parent.to_global(_gil.position + Vector3(0.0, -7.0, 0.0))
		if body.global_position.distance_squared_to(_gil.global_position) > 0.04:
			body.look_at(_gil.global_position, Vector3.UP)
	_arrange_epilogue()
	_lock_toon()
	_epilogue_on = true


func hold_epilogue() -> void:
	_epilogue_on = true
	_lock_toon()
	_arrange_epilogue()


func stand_gil_epilogue() -> void:
	if _gil != null and is_instance_valid(_gil):
		_gil.release_pose()


func _arrange_epilogue() -> void:
	if _gil == null or not is_instance_valid(_gil):
		return
	var people: Array[Node3D] = []
	var body := _body()
	if body != null:
		people.append(body)
	var host: Node = _boss.get_parent() if _boss != null else null
	var local_actor := _toon_actor(body)
	if host != null:
		for node in host.find_children("*", "ToonActor", true, false):
			var actor := node as ToonActor
			if actor == null or actor == _gil or actor == local_actor or not actor.visible:
				continue
			if int(actor.get_meta("peer", 0)) <= 0:
				continue
			people.append(actor)
	people.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return _epilogue_id(a) < _epilogue_id(b)
	)
	var count := people.size()
	if count == 0:
		return
	var center := float(count - 1) * 0.5
	var book: Node = host.find_child("RemoteToons", true, false) if host != null else null
	for index in count:
		var person := people[index]
		var angle := 90.0 - 15.0 * (float(index) - center)
		var spot := _gil.to_global(Vector3(cos(deg_to_rad(angle)) * 7.0, sin(deg_to_rad(angle)) * 7.0, 0.0))
		if person is CharacterBody3D:
			var mover := person as CharacterBody3D
			mover.velocity = Vector3.ZERO
			mover.global_position = spot
			var look := _gil.global_position
			look.y = spot.y
			if mover.global_position.distance_squared_to(look) > 0.04:
				mover.look_at(look, Vector3.UP)
			var actor := _toon_actor(mover)
			if actor != null:
				actor.release_pose()
			continue
		var toward := _gil.global_position - spot
		toward.y = 0.0
		var heading := 0.0
		if toward.length_squared() > 0.0001:
			heading = rad_to_deg(atan2(-toward.x, -toward.z))
		var peer := int(person.get_meta("peer", 0))
		if book != null and book.has_method("pin"):
			book.call("pin", peer, spot, heading)
		else:
			person.global_position = spot
		if person is ToonActor:
			(person as ToonActor).release_pose()


func _epilogue_id(person: Node) -> int:
	if person == _body():
		return ToonNet.peer_id()
	return int(person.get_meta("peer", 0))


func _return_to_bottle(index: int) -> void:
	if _root == null or index < 0:
		_flat_return = -1
		return
	var bottle: Node3D = null
	var bottle_index := -1
	for slot in _bottle_count():
		var node := _root.get_node_or_null("Bottle%d" % slot) as Node3D
		if node != null and int(node.get_meta("table", -1)) == index:
			bottle = node
			bottle_index = slot
			break
	_flat_return = -1
	if bottle == null:
		return
	var body := _body()
	_golf = true
	_station = "bottle"
	_station_index = bottle_index
	_station_table = index
	_tee_h = 0.0
	_spray = 0.0
	_station_arm = true
	_board_span = 0.0
	_board_age = 1.0
	_lock_toon()
	if body != null:
		body.velocity = Vector3.ZERO
		body.global_position = bottle.global_position + Vector3.UP * 1.6
		var actor := _toon_actor(body)
		if actor != null:
			actor.pose_action("leverNeutral", 0.0)


func _seat_taken(kind: String, index: int) -> bool:
	if not ToonNet.networked():
		return false
	var mine := ToonNet.peer_id()
	for channel in ToonNet.channels("ceo-seat:"):
		var row := ToonNet.latest(channel)
		if int(row.get("peer", 0)) == mine:
			continue
		if String(row.get("station", "")) != kind:
			continue
		var claimed := int(row.get("table", -1)) if kind == "bottle" else int(row.get("index", -1))
		if claimed == index:
			return true
	return false


func _publish_seat() -> void:
	if not ToonNet.networked() or _mode != "seltzer":
		return
	ToonNet.ceo_seat({
		"station": _station if _golf else "",
		"index": _station_index,
		"table": _station_table,
	})


func _publish_ceo_field(delta: float) -> void:
	if _boss == null or not ToonNet.ceo_driving():
		return
	_ceo_field_send -= delta
	if _ceo_field_send > 0.0:
		return
	_ceo_field_send = 0.2
	var state: Dictionary = _boss.call("world_state")
	var flats: Array = []
	for table in _find_all("BanquetTable"):
		if not table.has_meta("flat_until"):
			continue
		flats.append({
			"index": int(table.get_meta("table_index", -1)),
			"left": float(table.get_meta("flat_until")) - _clock,
		})
	state["flats"] = flats
	state["attacks"] = _attack_log
	ToonNet.ceo_field(state)


func _apply_flats() -> void:
	var field := ToonNet.latest("ceo-field")
	var flats: Array = field.get("flats", [])
	var open := {}
	for item in flats:
		if item is Dictionary:
			open[int(item.get("index", -1))] = float(item.get("left", 0.0))
	for table in _find_all("BanquetTable"):
		var index := int(table.get_meta("table_index", -1))
		if open.has(index) and float(open[index]) > 0.0:
			if not table.has_meta("saved_scale"):
				table.set_meta("saved_scale", table.scale)
			var saved := table.get_meta("saved_scale") as Vector3
			table.scale = Vector3(saved.x, saved.y, saved.z * 0.01)
			table.set_meta("flat_until", _clock + float(open[index]))
			if _mounted_table() == index:
				_flat_return = index
				_golf = false
				_spray = 0.0
				_station = ""
				_hide_putter()
				_release_board(_body())
				_free_toon()
				if _boss != null:
					_boss.call("note_crush")
		elif table.has_meta("flat_until"):
			var saved_scale: Variant = table.get_meta("saved_scale")
			if saved_scale is Vector3:
				table.scale = saved_scale
			table.remove_meta("flat_until")
			if _flat_return == index:
				_return_to_bottle(index)


func _tick_unflatten() -> void:
	for table in _find_all("BanquetTable"):
		if not table.has_meta("flat_until"):
			continue
		if _clock < float(table.get_meta("flat_until")):
			continue
		var saved: Variant = table.get_meta("saved_scale")
		if saved is Vector3:
			table.scale = saved
		table.remove_meta("flat_until")
		if _flat_return == int(table.get_meta("table_index", -1)):
			_return_to_bottle(_flat_return)


func _mount_station(body: CharacterBody3D) -> void:
	if not _KEYS.use_held() or _cool > 0.0 or _root == null:
		return
	var count := _bottle_count()
	for index in count:
		var bottle := _root.get_node_or_null("Bottle%d" % index) as Node3D
		var table_index := int(bottle.get_meta("table", -1)) if bottle != null else -1
		if bottle != null and not _table_is_flat(table_index) and not _seat_taken("bottle", table_index) and _near(body, bottle.global_position, 2.4):
			_golf = true
			_station = "bottle"
			_station_index = index
			_station_table = table_index
			_tee_h = 0.0
			_spray = 0.0
			_station_arm = true
			_cool = 0.3
			_board_from = body.global_position
			_board_age = 0.0
			_board_span = 1.33
			_lock_toon()
			return
	for index in 4:
		var tee := _root.get_node_or_null("GolfTee%d" % index) as Node3D
		if tee != null and not _seat_taken("tee", index) and _near(body, tee.global_position, 2.4):
			_golf = true
			_station = "tee"
			_station_index = index
			_tee_h = 0.0
			_spray = 0.0
			_station_arm = true
			_cool = 0.3
			_board_from = body.global_position
			_board_age = 0.0
			_board_span = 0.2
			_lock_toon()
			return


func _aim_station(delta: float, speed: float) -> void:
	var turn := 0.0
	if Input.is_physical_key_pressed(KEY_LEFT):
		turn -= 1.0
	elif Input.is_physical_key_pressed(KEY_RIGHT):
		turn += 1.0
	if turn == 0.0:
		return
	_tee_h = fposmod(_tee_h - turn * speed * delta, 360.0)
	var node := _station_node()
	if node == null or _root == null:
		return
	var ahead := _root.to_global(node.position + _aim_vector(_tee_h))
	if node.global_position.distance_squared_to(ahead) > 0.04:
		node.look_at(ahead, Vector3.UP)


func _station_node() -> Node3D:
	if _root == null:
		return null
	if _station == "bottle":
		return _root.get_node_or_null("Bottle%d" % _station_index) as Node3D
	return _root.get_node_or_null("GolfTee%d" % _station_index) as Node3D


func _aim_vector(heading: float) -> Vector3:
	var rad := deg_to_rad(heading)
	return Vector3(-sin(rad), cos(rad), 0.0)


func _water_power(elapsed: float) -> float:
	var t := fposmod(elapsed / 15.0, 1.0)
	return clampf(1.0 - pow(1.0 - t, 0.75), 0.001, 1.0)


func _ball_power(elapsed: float) -> float:
	var saw := fposmod(pow(maxf(elapsed, 0.0) / 3.0, 0.75) * 100.0, 200.0)
	if saw > 100.0:
		saw = 200.0 - saw
	return saw


func _fire_bottle(power: float) -> void:
	var bottle := _station_node()
	if bottle == null or _root == null:
		return
	var origin: Vector3 = bottle.position
	var target := origin + _aim_vector(_tee_h) * (250.0 * power)
	var boss_at := Vector3(0.0, 355.0, 4.0)
	var unit := 1
	if power >= 0.97:
		unit = 3
	elif power >= 0.75:
		unit = 2
	_show_spray(bottle.global_position + Vector3.UP * 1.4, _root.to_global(target))
	if _segment_hits(origin, target, boss_at, 8.0):
		_boss.call("note_seltzer", unit)
		_sfx("res://assets/audio/battle/SA_watercooler_spray_only.ogg")
	else:
		_tell("The seltzer missed.")
		_sfx("res://assets/audio/battle/AA_squirt_seltzer_miss.ogg")
	_spray = 0.0
	_cool = 0.35


func _fire_ball(power: float) -> void:
	var tee := _station_node()
	if tee == null or _root == null:
		_spray = 0.0
		return
	var remain := 1.0 - power / 100.0
	var dist := 300.0 - 200.0 * remain
	var span := 1.5 + 0.5 * remain
	var gravity := 32.174
	var velocity := _aim_vector(_tee_h) * (dist / span) + Vector3(0.0, 0.0, 0.5 * gravity * span)
	var mesh := _model_or_box("res://assets/battle/props/golf-ball.glb", tee.position, "FlyBall%d" % _balls.size(), Color(0.95, 0.95, 0.95), Vector3(0.4, 0.4, 0.4))
	mesh.position = tee.position
	_balls.append({"at": tee.position, "vel": velocity, "age": 0.0, "mesh": mesh, "hit": false})
	_sfx("res://assets/minigolf/audio/Golf_Hit_Ball.ogg")
	_spray = 0.0
	_cool = 0.45


func _tick_balls(delta: float) -> void:
	for slot in _balls.size():
		var ball: Dictionary = _balls[slot]
		if bool(ball.get("hit", false)):
			continue
		var vel: Vector3 = ball["vel"]
		vel.z -= 32.174 * delta
		ball["vel"] = vel
		var at: Vector3 = ball["at"] + vel * delta
		ball["at"] = at
		ball["age"] = float(ball.get("age", 0.0)) + delta
		var mesh := ball.get("mesh") as Node3D
		if mesh != null:
			mesh.position = at
		var flat := Vector2(at.x, at.y).distance_to(Vector2(0.0, 355.0))
		if not bool(ball.get("hit", false)) and flat < 8.0 and at.z > -1.0 and at.z < 16.0:
			ball["hit"] = true
			_boss.call("note_golf_ball", 2)
			if mesh != null:
				mesh.visible = false
		elif float(ball.get("age", 0.0)) >= 3.0 or at.z < -4.0:
			ball["hit"] = true
			if mesh != null:
				mesh.visible = false
		_balls[slot] = ball


func _segment_hits(origin: Vector3, target: Vector3, point: Vector3, reach: float) -> bool:
	var span := target - origin
	var length := span.length()
	if length < 0.001:
		return origin.distance_to(point) <= reach
	var along := clampf((point - origin).dot(span) / (length * length), 0.0, 1.0)
	return origin.lerp(target, along).distance_to(point) <= reach


func play_music(which: String) -> void:
	if which == "ceo":
		_play_music_file("res://assets/cog_hq/audio/BossBot_CEO_v1.ogg", which)
		return
	var file := ""
	match which:
		"battle", "battle1":
			file = "encntr_general_bg.ogg"
		"battle3":
			file = "encntr_suit_winning_indoor.ogg"
		"jury":
			file = "LB_juryBG.ogg"
		"between":
			file = "encntr_toon_winning.ogg"
		"epilogue":
			file = "encntr_hall_of_fame.ogg"
	if file == "":
		return
	_play_music_file("res://assets/cogs/bosses/audio/" + file, which)


func _play_music_file(path: String, which: String) -> void:
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
		var cone := CylinderMesh.new()
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
	if mesh is MeshInstance3D and (mesh as MeshInstance3D).mesh is CylinderMesh:
		var radius := tan(deg_to_rad(half)) * reach
		var shape := (mesh as MeshInstance3D).mesh as CylinderMesh
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
