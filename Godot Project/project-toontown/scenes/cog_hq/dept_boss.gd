extends Node

## The four department bosses. State order, health, and rewards follow
## DistributedSellbotBoss, DistributedCashbotBoss, DistributedLawbotBoss, and
## DistributedBossbotBoss. Cog rounds use the toon's gags. The signature round
## uses that boss's damage rule.

const _GATE := preload("res://scenes/cog_hq/boss_gate.gd")
const _REWARDS := preload("res://scenes/cog_hq/boss_rewards.gd")
const _PLACES := preload("res://scenes/places/hood_places.gd")

const _ROOMS := {
	"sellbot_vp.tscn": {"title": "Senior V.P.", "dept": 3, "letter": "s", "zone": 11000, "lobby": "res://scenes/cog_hq/sellbot_lobby.tscn", "max_hp": 100, "kind": "vp"},
	"cashbot_cfo.tscn": {"title": "Chief Financial Officer", "dept": 2, "letter": "m", "zone": 12000, "lobby": "res://scenes/cog_hq/cashbot_lobby.tscn", "max_hp": 500, "kind": "cfo"},
	"lawbot_cj.tscn": {"title": "Chief Justice", "dept": 1, "letter": "l", "zone": 13000, "lobby": "res://scenes/cog_hq/lawbot_lobby.tscn", "max_hp": 2700, "kind": "cj"},
	"bossbot_ceo.tscn": {"title": "Chief Executive Officer", "dept": 0, "letter": "c", "zone": 10000, "lobby": "res://scenes/cog_hq/bossbot_lobby.tscn", "max_hp": 500, "kind": "ceo"},
}
const _SUITS := {
	"s": [["cc", "Cold Caller"], ["tm", "Telemarketer"], ["nd", "Name Dropper"], ["gh", "Glad Hander"]],
	"m": [["sc", "Short Change"], ["pp", "Penny Pincher"], ["tw", "Tightwad"], ["bc", "Bean Counter"]],
	"l": [["bf", "Bottom Feeder"], ["b", "Bloodsucker"], ["dt", "Double Talker"], ["ac", "Ambulance Chaser"]],
	"c": [["f", "Flunky"], ["p", "Pencil Pusher"], ["ym", "Yesman"], ["mm", "Micromanager"]],
}
# LawbotBossDifficultySettings: ammo, gavels, lawyers, toon-up, juror weight, juror offset.
const _CJ: Array = [
	[38, 4, 8, 1, 0, 0], [36, 5, 8, 1, 0, 0], [34, 5, 8, 1, 0, 0],
	[32, 6, 8, 2, 0, 0], [30, 6, 8, 2, 0, 0], [28, 7, 8, 3, 0, 0],
	[26, 7, 9, 3, 1, 1], [24, 8, 9, 4, 1, 1], [22, 8, 10, 4, 1, 0],
]

var _kind := ""
var _dept := 0
var _letter := ""
var _zone := 0
var _lobby := ""
var _boss_name := ""
var _max_hp := 1
var _hp := 0
var _phase := ""
var _vp_teams: Array = []
var _phase_seen := 0
var _over := false
var _cogs: Array[Dictionary] = []
var _picked := 0
var _clock := 0.0
var _cool := 0.0
var _open := 0.0
var _stun := 0.0
var _dizzy := 0.0
var _marker := 0.0
var _shots := 0
var _toon_jurors := 0
var _weight := 1
var _ammo := 0
var _ammo_max := 0
var _lawyers: Array[float] = []
var _bonus_wait := 0.0
var _bonus := 0.0
var _gavel := 0.0
var _diners: Array[float] = []
var _hungry := 0
var _serve_left := 300.0
var _holding := false
var _note := ""
var _note_left := 0.0
var _layer: CanvasLayer
var _title: Label
var _body: Label
var _bar: ProgressBar
var _row: VBoxContainer
var _fight_id := 0
var _fight_seen := false
var _battle_slug := ""
var _battle_round := 1
var _suits: Node3D
var _plates: Array[int] = []
var _stuffed: Array[bool] = []
var _diner_level := 11
var _rounds: Node
var _show: Node
var _caged: Dictionary = {}
var _vp_ending := false
var _net_doors := false
var _vp_seq := 0
var _pies_left := 0
var _stored := 0
var _recover_rate := 0.0
var _recover_at := 0.0
var _hits := 0
var _vp_dizzy := false
var _near := false
var _attack_wait := 0.0
var _strafe_wait := 0.0
var _battle_at := 0.0
var _attack_open := 0.0
var _strafe_open := 0.0
var _pending := ""
var _event: Dictionary = {}
var _helmet := false
var _gave_helmet := false
var _helmet_left := -1.0
var _helmet_at := -1000.0
var _cfo_started := 0.0
var _cfo_bye := 0
var _swing_left := 15.0
var _cfo_seq := -1
var _cfo_hit_seq := 0
var _epi_pages: PackedStringArray = PackedStringArray()
var _cfo_reward_lines: PackedStringArray = PackedStringArray()
var _cfo_exp_before: Dictionary = {}
var _cfo_earned: Dictionary = {}
var _epi_at := 0
var _epi_danced := false
var _epi_fired := false
var _round_line := ""


static func place(host: Node) -> void:
	if Engine.is_editor_hint() or host == null:
		return
	if not _ROOMS.has(host.scene_file_path.get_file()) or host.get_node_or_null("DeptBoss") != null:
		return
	var node := (load("res://scenes/cog_hq/dept_boss.gd") as GDScript).new() as Node
	node.name = "DeptBoss"
	host.add_child(node)


static func arrival(host: Node) -> Dictionary:
	var spawn := host.find_child("BossSpawn", true, false) as Node3D
	if spawn == null:
		return {"point": Vector3(0, 1, 6), "heading": 180.0}
	var forward := -spawn.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3(0, 0, 1)
	return {"point": spawn.global_position, "heading": rad_to_deg(atan2(-forward.x, -forward.z))}


func _ready() -> void:
	var host := get_parent()
	var info: Dictionary = _ROOMS.get(host.scene_file_path.get_file(), {})
	_kind = String(info.get("kind", ""))
	_dept = int(info.get("dept", 0))
	_letter = String(info.get("letter", ""))
	_zone = int(info.get("zone", 0))
	_lobby = String(info.get("lobby", ""))
	_boss_name = String(info.get("title", "Boss"))
	_max_hp = int(info.get("max_hp", 1))
	_hp = 0 if _kind != "cj" else 1350
	_mark_spawn(host)
	_suits = Node3D.new()
	_suits.name = "BossSuits"
	host.add_child(_suits)
	if host.get_node_or_null("StreetFight") == null:
		var battle: Node = load("res://scenes/battle/street_fight.gd").new()
		battle.name = "StreetFight"
		host.add_child(battle)
	_build_hud()
	_rounds = load("res://scenes/cog_hq/boss_rounds.gd").new()
	_rounds.name = "BossRounds"
	add_child(_rounds)
	if _kind == "vp":
		_show = load("res://scenes/cog_hq/vp_show.gd").new()
		_show.name = "VpShow"
		add_child(_show)
		_show.call("bind", self)
	_go("intro")


func _process(delta: float) -> void:
	_follow_phase()
	if _over:
		return
	if _fight_id == 0 and _kind == "vp" and (_phase == "cogs" or _phase == "skele"):
		_claim_vp_fight()
	if _fight_id != 0:
		_watch_fight()
		return
	_clock += delta
	_cool = maxf(_cool - delta, 0.0)
	_stun = maxf(_stun - delta, 0.0)
	if _phase == "cranes":
		if ToonNet.networked():
			_follow_cfo()
		elif _helmet_left > 0.0 and not _helmet and _dizzy <= 0.0:
			_helmet_left = maxf(_helmet_left - delta, 0.0)
			if _helmet_left <= 0.0:
				_helmet = true
				_say("He put on a safe helmet.")
		# waitForNextAttack(15), then BossCogSlowDirectedAttack. The swing ends dizzy.
		_swing_left -= delta
		if _swing_left <= 0.0:
			_cfo_swing()
	else:
		_dizzy = maxf(_dizzy - delta, 0.0)
	_bonus = maxf(_bonus - delta, 0.0)
	_note_left = maxf(_note_left - delta, 0.0)
	_marker += delta
	if _over:
		return
	if _phase == "pies" or _phase == "cranes" or _phase == "cannons" or _phase == "evidence" or _phase == "banquet" or _phase == "seltzer":
		return


func _mark_spawn(host: Node) -> void:
	var marker := host.find_child("elevator", true, false) as Node3D
	if marker == null:
		marker = host.find_child("elevator_origin", true, false) as Node3D
	var spawn := Marker3D.new()
	spawn.name = "BossSpawn"
	host.add_child(spawn)
	if marker == null:
		spawn.position = Vector3(0, 1, 8)
		return
	var forward := marker.global_transform.basis.y
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3(0, 0, 1)
	spawn.global_position = marker.global_position + forward.normalized() * 6.0 + Vector3(0, 0.5, 0)


func _build_hud() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 30
	add_child(_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(420, 0)
	_layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_title = Label.new()
	box.add_child(_title)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(380, 18)
	_bar.show_percentage = false
	box.add_child(_bar)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(380, 72)
	box.add_child(_body)
	_row = VBoxContainer.new()
	box.add_child(_row)
	ToonGui.style_label(_title, Color(0.15, 0.1, 0.25), 22, Color(0, 0, 0, 0), 0)
	ToonGui.style_label(_body, Color(0.1, 0.1, 0.12), 16, Color(0, 0, 0, 0), 0)


func _go(phase: String) -> void:
	# The introduction leaves him standing in the vault for the cog battle.
	var keep_cfo := _kind == "cfo" and _phase == "intro" and phase == "cogs"
	if _rounds != null and keep_cfo:
		_rounds.call("finish_cfo_intro")
	elif _rounds != null:
		_rounds.call("shutdown")
	_phase = phase
	_clock = 0.0
	_holding = false
	if _layer != null:
		_layer.visible = true
	_clear_row()
	if phase == "intro":
		_intro()
	elif phase == "cogs" or phase == "cogs2" or phase == "skele":
		_start_cogs(phase == "cogs2", phase == "skele")
	elif phase == "roll" or phase == "prepare2" or phase == "prepare3":
		_start_show(phase)
	elif phase == "pies":
		_start_pies()
	elif phase == "lesson":
		_start_lesson()
	elif phase == "cranes":
		_start_cranes()
	elif phase == "cannons":
		_start_cannons()
	elif phase == "evidence":
		_start_evidence()
	elif phase == "banquet":
		_start_banquet()
	elif phase == "seltzer":
		_start_seltzer()
	elif phase == "reward":
		_start_reward()
	_paint_bar()


func _intro() -> void:
	_title.text = _boss_name
	if _kind == "vp" and _show != null:
		_body.text = ""
		_show.call("play", "intro")
		_button("Skip", _skip_show)
		return
	if _kind == "cfo":
		_rounds.call("start_cfo_intro", self)
		_button("Skip", _skip_cfo_intro)
		return
	_body.text = _intro_line()
	_button("Continue", _after_intro)


func _intro_line() -> String:
	if _kind == "vp":
		return "The Senior V.P. is in. Defeat his cogs, then his skelecogs. Get pies from the cage. A pie in the open doors stuns him. While he is stunned, each pie on his body does 1. He falls at 100, then one more pie in the doors ends it."
	if _kind == "cfo":
		return "The Chief Financial Officer is in the vault. Defeat his cogs, then use the cranes. The first safe becomes his helmet. Knock it off, drop a goon to dizzy him, then safes do up to 50. He falls at 500."
	if _kind == "cj":
		return "The Chief Justice is seated. Fire yourself into the jury chairs, then throw evidence onto the defense pan. The scale starts at 1350 and needs 2700."
	return "The Chief Executive Officer is at the banquet. Carry food from the belt to a hungry cog, fight whoever is still standing, then charge the seltzer. He falls at 500."


func _after_intro() -> void:
	_go("cogs")


func _start_show(phase: String) -> void:
	_title.text = _boss_name
	if _show == null:
		return
	if phase == "roll":
		_show.call("play", "roll")
		return
	var lines := PackedStringArray()
	if phase == "prepare2":
		lines = PackedStringArray([
			"Look out, he's trying to get away!",
			"Help me, everyone--get up here and stop him!",
		])
	else:
		lines = PackedStringArray([
			"Hooray, I'm almost free!",
			"Now you need to attack the V.P. Cog directly.",
			"I've got a whole bunch of pies you can use!",
			"Jump up and touch the bottom of my cage and I'll give you some pies.",
			"Click to throw pies once you've got them!",
		])
	_show.call("pages", phase, lines)
	_button("Continue", _next_show)


func _skip_show() -> void:
	if _show != null:
		_show.call("skip")


func _next_show() -> void:
	if _show != null:
		_show.call("next_page")


func show_pages() -> void:
	_clear_row()
	_button("Continue", _next_show)


func show_finished(which: String) -> void:
	if which == "intro":
		_go("cogs")
	elif which == "roll":
		_go("prepare2")
	elif which == "prepare2":
		_go("skele")
	elif which == "prepare3":
		_go("pies")
	elif which == "victory":
		_go("reward")


func set_line(text: String) -> void:
	if _body != null:
		_body.text = text


func hold_caged_toon() -> Dictionary:
	if _caged.is_empty():
		_caged = _REWARDS.hold_vp_sos()
	return _caged


func promotion_waiting() -> bool:
	return DisguisePage.ready_for_promotion(_dept)


func promotion_note() -> String:
	return DisguisePage.vp_thanks(_dept)


## MovieToonVictory after the fall. The cog fights already stored the points.
func play_gag_reward(loadout: ToonLoadout, before: Dictionary, earned: Dictionary, toon_name: String = "", grant := true) -> void:
	if _layer == null or loadout == null:
		return
	var panel := RewardPanel.new()
	panel.name = "VpReward"
	panel.z_index = 40
	_layer.add_child(panel)
	if toon_name == "":
		toon_name = "Toon"
		var host := get_parent()
		var body := host.get_node_or_null("Player") if host != null else null
		if body != null:
			for child in body.get_children():
				if child is ToonActor:
					toon_name = child.name
					break
	await panel.present(toon_name, loadout, before, earned, "", true, [], not grant)
	if is_instance_valid(panel):
		panel.queue_free()


func place_vp(along: float) -> void:
	if _show != null:
		_show.call("place_damage", along)


func vp_ending() -> bool:
	return _vp_ending


func _start_cogs(hard: bool, skeleton: bool = false) -> void:
	if _kind == "cfo" and _rounds != null:
		_rounds.call("play_music", "battle")
		_remember_cfo_exp()
	# BattleOne / BattleTwo are DistributedBattleFinal fights. The V.P. builds
	# two floors and splits the Toons. A side with nobody folds into reserves.
	if _kind == "vp":
		if _show != null:
			var alone := _boss_peers().size() < 2
			var cage := (3 if alone else 2) if skeleton else (1 if alone else 0)
			_show.call("seat_cage", cage)
		if ToonNet.is_authority() and _open_vp_sides(skeleton):
			return
		if ToonNet.networked() and not ToonNet.is_authority():
			_title.text = "Battle Two" if skeleton else "Battle One"
			_body.text = "The V.P.'s skelecogs." if skeleton else "The V.P.'s cogs."
			return
	var plan := _battle_plan(hard, skeleton)
	_title.text = String(plan.get("title", "Battle"))
	_body.text = String(plan.get("blurb", "The cogs are ready."))
	if _open_battle(plan.get("active", []), plan.get("reserves", []), int(plan.get("round", 1))):
		return
	_cogs.clear()
	_picked = 0
	for item in plan.get("active", []):
		if item is Dictionary:
			_cogs.append(item)
	_paint_cogs()


func _paint_cogs() -> void:
	_clear_row()
	for index in _cogs.size():
		var cog := _cogs[index]
		var alive := int(cog["hp"]) > 0
		var cog_name := String(cog["name"])
		if bool(cog["skeleton"]):
			cog_name = "Skelecog %s" % cog_name
		var text := "%s  %d/%d" % [cog_name, int(cog["hp"]), int(cog["max"])]
		if not alive:
			text = "%s defeated" % cog_name
		var pick := _button(text, _select_cog.bind(index))
		pick.disabled = not alive
	var loadout := _loadout()
	if loadout == null:
		return
	for track in ToonLoadout.TRACK_COUNT:
		if not loadout.track_open(track):
			continue
		for level in ToonLoadout.LEVEL_COUNT:
			if loadout.count_of(track, level) <= 0:
				continue
			var gag := loadout.gag_name(track, level)
			var damage := ToonLoadout.gag_damage(track, level, loadout.experience_of(track), loadout.is_organic(track, level))
			_button("%s x%d  (%d)" % [gag, loadout.count_of(track, level), damage], _use_gag.bind(track, level))


func _select_cog(index: int) -> void:
	_picked = index
	_body.text = "Aiming at %s." % String(_cogs[index]["name"])


func _use_gag(track: int, level: int) -> void:
	if _phase != "cogs" and _phase != "cogs2" and _phase != "skele":
		return
	var loadout := _loadout()
	if loadout == null or not loadout.spend_gag(track, level):
		return
	var damage := ToonLoadout.gag_damage(track, level, loadout.experience_of(track), loadout.is_organic(track, level))
	if track == ToonLoadout.TOON_UP:
		loadout.gain_hp(damage)
		_body.text = "You healed %d laff." % damage
	else:
		var group := ToonLoadout.affects_group(track, level)
		for index in _cogs.size():
			if not group and index != _picked:
				continue
			_hit_cog(index, damage, track, level, loadout)
	loadout.save()
	if _living() == 0:
		_advance_from_cogs()
		return
	_cog_swing()
	if _over:
		return
	_paint_cogs()


func _hit_cog(index: int, damage: int, track: int, level: int, loadout: ToonLoadout) -> void:
	var cog := _cogs[index]
	if int(cog["hp"]) <= 0:
		return
	cog["hp"] = int(cog["hp"]) - damage
	if int(cog["hp"]) <= 0 and not bool(cog["noted"]):
		cog["noted"] = true
		var journal := _journal()
		if journal != null:
			journal.note_cog_defeat(String(cog["code"]), _zone, _letter, int(cog["level"]), bool(cog["skeleton"]), 0, false)
		var gained := (level + 1) * 2
		if _kind == "cfo":
			_cfo_earned[track] = int(_cfo_earned.get(track, 0)) + gained
		loadout.add_experience(track, gained)
	_cogs[index] = cog


func _cog_swing() -> void:
	var total := 0
	for cog in _cogs:
		if int(cog["hp"]) <= 0:
			continue
		total += int(cog["level"]) + 1
	if total > 0:
		_hurt(total)
		_body.text = "The cogs hit back for %d." % total


func _living() -> int:
	var count := 0
	for cog in _cogs:
		if int(cog["hp"]) > 0:
			count += 1
	return count


func _advance_from_cogs() -> void:
	if _phase == "cogs2":
		_go("seltzer")
		return
	if _phase == "skele":
		_go("prepare3" if _kind == "vp" else "pies")
		return
	if _kind == "vp":
		_go("roll")
	elif _kind == "cfo":
		_go("lesson")
	elif _kind == "cj":
		_go("cannons")
	else:
		_go("banquet")


func _start_pies() -> void:
	_title.text = "Battle Three"
	_hp = 0
	_stored = 0
	_recover_rate = 0.0
	_recover_at = _clock
	_hits = 0
	_vp_dizzy = false
	_near = false
	_pies_left = 0
	_attack_wait = 5.0
	_strafe_wait = 9.0
	_battle_at = _clock
	_attack_open = 0.0
	_strafe_open = 0.0
	_pending = ""
	_event = {}
	_paint_bar()
	_vp_seq = 0
	if ToonNet.networked():
		ToonNet.vp_begin()
	if _show != null:
		_show.call("pose", "neutral")
		_show.call("music", "battle3")
		_show.call("widen")
	_rounds.call("start_vp", self)


func _start_lesson() -> void:
	_title.text = "Battle Three"
	if _rounds != null:
		_rounds.call("play_music", "battle3")
	_rounds.call("start_cfo_lesson", self)
	_button("Skip", _skip_cfo_lesson)


func finish_cfo_lesson() -> void:
	if _phase != "lesson":
		return
	_clear_row()
	_phase = "cranes"
	_arm_cranes()
	_rounds.call("enable_cranes")


func _skip_cfo_lesson() -> void:
	if _rounds != null:
		_rounds.call("finish_cfo_lesson")
	finish_cfo_lesson()


func _arm_cranes() -> void:
	_title.text = "Battle Three"
	_hp = 0
	_helmet = false
	_gave_helmet = false
	_dizzy = 0.0
	_cfo_started = _clock
	_helmet_at = -1000.0
	_swing_left = 15.0
	_cfo_seq = -1
	_schedule_helmet()
	_paint_bar()
	if ToonNet.networked():
		ToonNet.cfo_begin()


func _start_cranes() -> void:
	_arm_cranes()
	_rounds.call("start_cranes", self)


func _start_cannons() -> void:
	_title.text = "Cannon Round"
	_shots = 0
	_toon_jurors = 0
	_rounds.call("start_cannons", self)


func _start_evidence() -> void:
	var adjust := (_toon_jurors - 8) * 68
	_hp = clampi(1350 + adjust, 0, _max_hp)
	var row: Array = _difficulty()
	_ammo_max = int(row[0])
	_ammo = _ammo_max
	_weight = 1
	if int(row[4]) != 0:
		_weight = 1 + maxi(_toon_jurors - int(row[5]), 0)
	_lawyers.clear()
	for _lawyer in int(row[2]):
		_lawyers.append(0.0)
	_bonus_wait = 0.0
	_bonus = 0.0
	_gavel = 7.0
	_title.text = "Battle Three"
	_paint_bar()
	_rounds.call("start_evidence", self)


func _start_banquet() -> void:
	_title.text = "Battle Two"
	_serve_left = 300.0
	var table := _ceo_table()
	var count := int(table.get("tables", 1)) * int(table.get("diners", 4))
	_diner_level = int(table.get("level", 11))
	_diners.clear()
	_plates.clear()
	_stuffed.clear()
	_hungry = 0
	for _index in count:
		_diners.append(3.0)
		_plates.append(0)
		_stuffed.append(false)
	_rounds.call("start_banquet", self)


func _start_seltzer() -> void:
	_title.text = "Battle Four"
	_hp = 0
	_paint_bar()
	_rounds.call("start_seltzer", self)


func _difficulty() -> Array:
	var promotions := DisguisePage.promotions(_dept)
	var level := clampi(int(float(promotions) / 77.0 * float(_CJ.size())), 0, _CJ.size() - 1)
	return _CJ[level]


func _restock_evidence() -> void:
	_ammo = _ammo_max
	_say("You picked up %d evidence." % _ammo)


func _stun_lawyer(index: int) -> void:
	if index < 0 or index >= _lawyers.size():
		return
	_lawyers[index] = 5.0
	_say("Lawyer %d is stunned." % (index + 1))


func _finish_serving() -> void:
	_go("cogs2")


func _tick_banquet(delta: float) -> void:
	_serve_left = maxf(_serve_left - delta, 0.0)
	_hungry = _next_hungry(_hungry)
	if _hungry >= 0:
		_diners[_hungry] -= delta
		if _diners[_hungry] <= 0.0:
			_hurt(8)
			_diners[_hungry] = 3.0
			_say("Seat %d got angry." % (_hungry + 1))
	if _serve_left <= 0.0:
		_go("cogs2")
		return
	var line := "Banquet time left: %d." % ceili(_serve_left)
	if _hungry >= 0:
		line += " Seat %d is hungry (%d/3)." % [_hungry + 1, int(_plates[_hungry])]
	if _note_left > 0.0 and _note != "":
		line += "\n" + _note
	_body.text = line


func _serve(index: int) -> void:
	if _phase != "banquet" or index < 0 or index >= _stuffed.size() or _stuffed[index]:
		return
	if index != _hungry:
		_hurt(8)
		_say("That cog was not hungry.")
		return
	_heal(5)
	_plates[index] += 1
	_diners[index] = 3.0
	if _plates[index] >= 3:
		_stuffed[index] = true
		_say("Seat %d had three plates and is out of the battle." % (index + 1))
	else:
		_say("You served seat %d." % (index + 1))
	_hungry = _next_hungry(index + 1)


func _next_hungry(start: int) -> int:
	if _stuffed.is_empty():
		return -1
	for step in _stuffed.size():
		var index := posmod(start + step, _stuffed.size())
		if not _stuffed[index]:
			return index
	return -1


func _start_reward() -> void:
	if _rounds != null:
		_rounds.call("shutdown")
	_over = true
	_title.text = "Victory"
	var lines: PackedStringArray = []
	var journal := _journal()
	if _kind == "vp":
		if journal != null:
			journal.note_vp(_zone)
			journal.note_rescue(_zone)
		lines.append(_REWARDS.grant_held_sos())
	elif _kind == "cfo":
		if journal != null:
			journal.note_cfo(_zone)
		lines.append(_REWARDS.grant_unite())
	elif _kind == "cj":
		if journal != null:
			journal.note_cj(_zone)
		lines.append(_REWARDS.grant_summon(DisguisePage.promotions(_dept)))
	else:
		if journal != null:
			journal.note_ceo(_zone)
		lines.append(_REWARDS.grant_pink(1))
	if DisguisePage.ready_for_promotion(_dept):
		lines.append(DisguisePage.promote(_dept))
	else:
		lines.append("Your Cog suit was not ready for a promotion.")
	_body.text = "\n".join(lines)
	_bar.value = _bar.max_value
	if _kind == "cfo":
		_cfo_reward_lines = lines
		_body.text = ""
		if _rounds != null:
			_rounds.call("start_cfo_victory")
		_finish_cfo_victory()
		return
	_button("Return to the lobby", _leave)


func cfo_intro_line(text: String, cog: bool) -> void:
	_body.text = text
	if cog:
		ToonSpeech.cog(text)
	else:
		ToonSpeech.play("p", text)


func cfo_intro_done() -> void:
	if _phase == "intro":
		_after_intro()


func _skip_cfo_intro() -> void:
	if _rounds != null:
		_rounds.call("finish_cfo_intro")
	if _phase == "intro":
		_after_intro()


func cfo_flee_line(text: String) -> void:
	_body.text = text
	ToonSpeech.cog(text)


func cfo_flee_done() -> void:
	if _phase == "flee":
		_go("reward")


func cfo_victory_done() -> void:
	if _phase != "reward":
		return
	_open_cfo_pages(_cfo_reward_lines)


func _remember_cfo_exp() -> void:
	_cfo_exp_before.clear()
	_cfo_earned.clear()
	var loadout := _loadout()
	if loadout == null:
		return
	for track in ToonLoadout.TRACK_COUNT:
		_cfo_exp_before[track] = loadout.experience_of(track)


func _finish_cfo_victory() -> void:
	var any := false
	for track in ToonLoadout.TRACK_COUNT:
		if int(_cfo_earned.get(track, 0)) > 0:
			any = true
			break
	var loadout := _loadout()
	if any and loadout != null:
		await play_gag_reward(loadout, _cfo_exp_before, _cfo_earned, "", false)
	else:
		await get_tree().create_timer(4.5).timeout
	if not is_inside_tree():
		return
	if _rounds != null:
		_rounds.call("finish_cfo_victory")
	if _phase == "reward":
		_open_cfo_pages(_cfo_reward_lines)


func _cfo_swing() -> void:
	# BossCogAttackTimes slow directed, plus progressValue(10, 0). Damage is 10.
	var along := clampf(maxf(float(_hp) / 500.0, (_clock - _cfo_started) / 1800.0), 0.0, 1.0)
	_swing_left = 7.84 + lerpf(10.0, 0.0, along)
	if _over:
		return
	if ToonNet.networked():
		ToonNet.cfo_hit(_next_cfo_serial(), "swing", 0.0, 1.0)
	elif _dizzy > 0.0:
		_dizzy = 0.0
		_schedule_helmet()
	if _rounds != null:
		_rounds.call("note_cfo_throw")
	_hurt(10)
	_say("The C.F.O. swung for 10.")


func _open_cfo_pages(lines: PackedStringArray) -> void:
	# ResistanceToonCongratulations, one chat page at a time.
	var card := _REWARDS.latest_unite()
	var menu := int(card.get("menu", 0))
	var item := int(card.get("item", 0))
	var phrase := "a unite"
	var when := "the Toons near you are helped"
	if not card.is_empty():
		phrase = _REWARDS.unite_phrase(menu, item)
		when = _REWARDS.unite_when(menu, item)
	_epi_pages = PackedStringArray([
		"You did it!  Congratulations!",
		"You're an asset to the Resistance!",
		"Here's a special phrase you can use in a tight spot:\n%s" % phrase,
		"When you say it, %s." % when,
		"But you can only use it once, so choose that time well!",
	])
	for line in lines:
		if line.contains("unite:"):
			continue
		_epi_pages.append(line)
	_epi_at = 0
	_epi_danced = false
	_epi_fired = false
	_cfo_bye = 0
	if _rounds != null:
		_rounds.call("start_cfo_epilogue")
	_show_epi_page()
	_button("Continue", _cfo_epi_next)


func _show_epi_page() -> void:
	if _epi_at < 0 or _epi_at >= _epi_pages.size():
		return
	_body.text = _epi_pages[_epi_at]
	ToonSpeech.play("p", _body.text)
	if _epi_at == 1 and not _epi_danced:
		_epi_danced = true
		if _rounds != null:
			_rounds.call("epilogue_dance")
	if _epi_at == 3 and not _epi_fired:
		_epi_fired = true
		var spoken := _REWARDS.rehearse_unite()
		if spoken != "":
			ToonSpeech.play("p", spoken)


func _cfo_epi_next() -> void:
	_epi_at += 1
	if _epi_at >= _epi_pages.size():
		_cfo_bye_next()
		return
	_show_epi_page()


func _cfo_thanks(lines: PackedStringArray) -> String:
	# ResistanceToonCongratulations, then the promotion note when it is not the V.P.'s.
	var speech := "You did it!  Congratulations!\nYou're an asset to the Resistance!\nHere's a special phrase you can use in a tight spot:\n%s\nBut you can only use it once, so choose that time well!" % "\n".join(lines)
	var extra := DisguisePage.vp_thanks(_dept)
	if extra != "" and not extra.contains("V.P."):
		speech += "\n" + extra
	return speech


func _cfo_bye_next() -> void:
	if _cfo_bye == 0:
		_cfo_bye = 1
		_body.text = "See ya!"
		ToonSpeech.play("p", "See ya!")
		if _rounds != null:
			_rounds.call("epilogue_wave")
		return
	_clear_row()
	if _rounds != null:
		_rounds.call("shutdown")
	get_tree().create_timer(0.5).timeout.connect(_teleport_home)


func _teleport_home() -> void:
	var hood := _playground_home()
	var host := get_parent()
	var toon := host.get_node_or_null("PlaygroundToon") if host != null else null
	if toon != null and toon.has_method("teleport_to_hood"):
		toon.call("teleport_to_hood", hood, true)
		return
	_GATE.trip = "out"
	ToonLoading.change_to(_PLACES.scene_for(hood))


func clear_pages() -> void:
	_clear_row()


func leave_for_playground() -> void:
	# localToonToSafeZone. The goodbye sends you to your playground.
	if _kind != "vp" or _over:
		return
	if _rounds != null:
		_rounds.call("shutdown")
	_over = true
	var journal := _journal()
	if journal != null:
		journal.note_vp(_zone)
		journal.note_rescue(_zone)
	_REWARDS.grant_held_sos()
	if DisguisePage.ready_for_promotion(_dept):
		DisguisePage.promote(_dept)
	_teleport_home()


func _playground_home() -> int:
	var tasks := ToonTasks.for_selected()
	if tasks == null:
		return _PLACES.TTC
	var last := tasks.return_hood()
	if _is_playground(last):
		return last
	var found := _PLACES.TTC
	for hood in tasks.visited:
		if _is_playground(int(hood)):
			found = int(hood)
	return found


func _is_playground(hood: int) -> bool:
	return hood >= 1000 and hood < 10000


func _leave() -> void:
	_GATE.trip = "out"
	ToonLoading.change_to(_lobby)


func lawyer_count() -> int:
	return _lawyers.size()


func world_state() -> Dictionary:
	return {
		"hp": _hp,
		"max": _max_hp,
		"stun": _stun,
		"dizzy": _dizzy,
		"helmet": _helmet,
		"ammo": _ammo,
		"shots": _shots,
		"jurors": _toon_jurors,
		"weight": _weight,
		"bonus": _bonus,
		"hungry": _hungry,
		"serve": _serve_left,
		"plates": _plates.duplicate(),
		"stuffed": _stuffed.duplicate(),
	}


func set_round_text(text: String) -> void:
	_round_line = text
	if _body != null:
		_body.text = text


func paint_world(detail: String) -> void:
	var line := "%s\n%s\n%d / %d." % [_round_line, detail, _hp, _max_hp]
	if _note_left > 0.0 and _note != "":
		line += "\n" + _note
	if _body != null:
		_body.text = line
	_paint_bar()


func restock_pies() -> void:
	if _pies_left > 0:
		return
	# ToontownGlobals.FullPies. One touch of the cage fills the toon.
	_pies_left = 65535
	_say("You picked up a stack of pies.")
	if _show != null:
		_show.call("sfx", "CHQ_SOS_pies_restock.ogg")
		_show.call("touched_cage")


func take_pie() -> bool:
	if _phase != "pies" or _pies_left <= 0:
		_say("Get pies from the cage.")
		return false
	_pies_left -= 1
	if _show != null:
		_show.call("threw_pie")
		if _pies_left <= 0:
			_show.call("out_of_pies")
	return true


func phase() -> String:
	return _phase


func arena_side() -> int:
	# The side this Toon was given. That ramp is the one they roll up.
	var teams: Array = vp_teams()
	if teams.size() > 1 and (teams[1] as Array).has(ToonNet.peer_id()):
		return 1
	return 0


func nerfed() -> bool:
	# ToontownGlobals.SELLBOT_NERF_HOLIDAY. Operation: Storm Sellbot.
	var snap := ToonNet.latest("holidays")
	var ids: Variant = snap.get("ids", [])
	if ids is Array:
		for item in ids:
			if int(item) == 96:
				return true
	return false


func tick_vp(delta: float) -> Dictionary:
	if ToonNet.networked():
		return _adopt_vp()
	if _phase != "pies" or _near:
		var waiting := _vp_state()
		waiting["event"] = {}
		return waiting
	_attack_open = maxf(_attack_open - delta, 0.0)
	_strafe_open = maxf(_strafe_open - delta, 0.0)
	_hp = _boss_damage()
	_attack_wait -= delta
	if _attack_wait <= 0.0:
		_choose_attack()
	_strafe_wait -= delta
	if _strafe_wait <= 0.0:
		_choose_strafe()
	_hp = _boss_damage()
	var state := _vp_state()
	state["event"] = _event
	_event = {}
	return state


func note_opening() -> void:
	if _phase != "pies":
		return
	if _show != null:
		_show.call("flash")
	if ToonNet.networked():
		ToonNet.vp_hit("opening")
		if _near:
			_start_victory()
		else:
			_say("The doors are open. He is stunned.")
		return
	if _near:
		_start_victory()
		return
	_begin_attack("dizzy")
	_say("The doors are open. He is stunned.")


func note_friend_pie(peer: int) -> void:
	# SellbotBossGlobals.PieToonup. Storm Sellbot raises it to 2.
	var up := 2 if nerfed() else 1
	ToonNet.heal_toon(peer)
	_say("The pie tooned them up for %d." % up)


func note_body() -> void:
	if _phase != "pies" or _near or not _vp_dizzy:
		if _phase == "pies" and not _near:
			_say("That pie hit his armor.")
		return
	if ToonNet.networked():
		ToonNet.vp_hit("body")
		_say("The pie did %d." % (2 if nerfed() else 1))
		return
	var dealt := 2 if nerfed() else 1
	_set_damage(mini(_boss_damage() + dealt, _max_hp), 0.0)
	_hits += 1
	_say("The pie did %d." % dealt)
	if _boss_damage() >= _max_hp:
		_enter_near()
		return
	var need := 50 if nerfed() else 35
	if _hits >= 6 and _boss_damage() >= need:
		_begin_attack("recover")
	else:
		_pose_attack("downhit")


func note_vp_attack(kind: String) -> void:
	if _vp_dizzy or _near:
		return
	var amount := _attack_damage(kind)
	if ToonNet.networked():
		ToonNet.vp_hit("struck:" + kind)
	else:
		_hurt(amount)
	_say("The V.P. hit you for %d." % amount)


func note_safe(impact: float) -> void:
	# hitBoss. A dizzy CFO takes the fall. Otherwise the safe is a helmet.
	if ToonNet.networked():
		ToonNet.cfo_hit(_next_cfo_serial(), "safe", impact, 1.0)
		return
	if _dizzy > 0.0:
		_record_cfo(maxi(2, int(impact * 50.0)))
		return
	if _helmet and impact >= 0.5:
		_helmet = false
		_say("The helmet flew off.")
		_schedule_helmet()
		return
	if not _helmet and _clock - _helmet_at > 300.0:
		_helmet = true
		_helmet_at = _clock
		_helmet_left = -1.0
		_say("He caught the safe and wore it as a helmet.")
		return
	_say("The safe bounced off.")


func note_goon_hit(impact: float, scale: float = 1.0) -> void:
	# A goon only hurts him when he is not holding a safe.
	if ToonNet.networked():
		ToonNet.cfo_hit(_next_cfo_serial(), "goon", impact, scale)
		return
	if _helmet:
		_say("The goon bounced off his helmet.")
		return
	_record_cfo(maxi(2, int(impact * 25.0 * scale)))


func _next_cfo_serial() -> int:
	_cfo_hit_seq += 1
	return ToonNet.peer_id() * 100000 + _cfo_hit_seq


func _follow_cfo() -> void:
	var snap := ToonNet.latest("cfo-boss")
	if not bool(snap.get("live", false)):
		return
	var seq := int(snap.get("seq", 0))
	var hp := int(snap.get("hp", _hp))
	if seq != _cfo_seq:
		_cfo_seq = seq
		if hp > _hp and _rounds != null:
			_rounds.call("note_cfo_hit")
		var line := String(snap.get("line", ""))
		if line != "":
			_say(line)
	_hp = mini(hp, _max_hp)
	_helmet = bool(snap.get("helmet", _helmet))
	_dizzy = float(snap.get("dizzy", _dizzy))
	_check_boss()


func _record_cfo(damage: int) -> void:
	# recordHit. Fifteen or more dizzies him, and he stays dizzy.
	_hp = mini(_hp + damage, _max_hp)
	if _rounds != null:
		_rounds.call("note_cfo_hit")
	if _dizzy <= 0.0 and damage >= 15:
		_dizzy = 1.0
		_helmet = false
		_helmet_left = -1.0
		_say("The hit did %d and dizzied him." % damage)
	elif _dizzy <= 0.0:
		_say("The hit did %d." % damage)
		_schedule_helmet()
	else:
		_say("The hit did %d." % damage)
	_check_boss()


func _schedule_helmet() -> void:
	# waitForNextHelmet. Forty-five seconds at the start, fifteen near the end.
	if _dizzy > 0.0 or _helmet:
		return
	var along := clampf(maxf(float(_hp) / 500.0, (_clock - _cfo_started) / 1800.0), 0.0, 1.0)
	_helmet_left = lerpf(45.0, 15.0, along)


func note_goon(strength: int = 5) -> void:
	_hurt(maxi(strength, 1))
	_say("A goon zapped you for %d." % maxi(strength, 1))


func note_treasure(amount: int = 5) -> void:
	var heal := maxi(amount, 1)
	_heal(heal)
	_say("The treasure restored %d laff." % heal)


func note_chair(toon: bool) -> void:
	if _shots >= 12:
		return
	_shots += 1
	if toon:
		_toon_jurors += 1
		_say("You landed in chair %d." % _shots)
	else:
		_say("A cog took chair %d." % _shots)


func finish_cannons() -> void:
	if _phase == "cannons":
		_go("evidence")


func restock_evidence() -> void:
	if _ammo >= _ammo_max:
		return
	_ammo = _ammo_max
	_say("You picked up %d evidence." % _ammo)


func note_evidence() -> void:
	if _ammo <= 0:
		_say("You need more evidence from the stand.")
		return
	_ammo -= 1
	var dealt := _weight * (2 if _bonus > 0.0 else 1)
	_hp = mini(_hp + dealt, _max_hp)
	_say("The defense pan rose by %d." % dealt)
	_check_boss()


func stun_lawyer(index: int) -> void:
	_stun_lawyer(index)


func note_all_stunned(delta: float) -> void:
	if _bonus > 0.0 or _lawyers.is_empty():
		return
	_bonus_wait += delta
	if _bonus_wait >= 60.0:
		_bonus = 20.0
		_bonus_wait = 0.0
		_heal(10)
		_say("Bonus weight. Evidence counts double, and you recover 10 laff.")


func tick_lawyers(delta: float) -> void:
	for index in _lawyers.size():
		_lawyers[index] = maxf(float(_lawyers[index]) - delta, 0.0)
	if fposmod(_clock, 6.0) < delta:
		for left in _lawyers:
			if left <= 0.0:
				_hp = maxi(_hp - 2, 0)
				_say("A lawyer healed the scale by 2.")
				return


func note_gavel(stomp: bool) -> void:
	var amount := 20 if stomp else 2
	_hurt(amount)
	_say("The gavel hit for %d." % amount)


func serve_seat(index: int) -> void:
	_serve(index)


func tick_banquet(delta: float) -> void:
	if _phase != "banquet":
		return
	_tick_banquet(delta)


func note_seltzer(unit: int) -> void:
	var dealt := clampi(unit, 1, 3) * 2
	_hp = mini(_hp + dealt, _max_hp)
	_say("The seltzer did %d." % dealt)
	_check_boss()


func note_golf(area: bool) -> void:
	_hurt(15)
	_say("His %s did 15." % ("area swing" if area else "club"))


func _boss_damage() -> int:
	var elapsed := _clock - _recover_at
	return int(maxf(float(_stored) - _recover_rate * elapsed / 60.0, 0.0))


func _set_damage(amount: int, rate: float) -> void:
	_stored = clampi(amount, 0, _max_hp)
	_recover_rate = rate
	_recover_at = _clock
	_hp = _boss_damage()


func _progress(start: float, finish: float) -> float:
	var along := float(_boss_damage()) / float(_max_hp)
	var timed := (_clock - _battle_at) / 1800.0
	var t := clampf(maxf(along, timed), 0.0, 1.0)
	return start + (finish - start) * t


func _choose_attack() -> void:
	if _vp_dizzy:
		_begin_attack("recover")
		return
	var roll := randi() % 6
	if roll == 0:
		_begin_attack("area")
	elif roll == 1:
		_begin_attack("front")
	else:
		_begin_attack("directed")


func _choose_strafe() -> void:
	_strafe_wait = 9.0
	if _vp_dizzy or _near:
		return
	if not _event.is_empty():
		_strafe_wait = 0.5
		return
	_pending = "strafe"
	_strafe_open = 0.7 + _strafe_span()
	_event = {
		"kind": "strafe",
		"damage": 2,
		"delay": _strafe_open,
		"radius": 6.0,
		"side": randi() % 2,
		"dir": randi() % 2,
		"t": float(_boss_damage()) / 100.0,
		"target": 0,
	}


func _strafe_span() -> float:
	var t := float(_boss_damage()) / 100.0
	return 5.0 - 4.0 * t


func _begin_attack(kind: String) -> void:
	_pending = kind
	if kind == "dizzy":
		_vp_dizzy = true
		_hits = 0
		var delay := _progress(20.0, 5.0)
		_attack_open = delay
		_attack_wait = delay
		_event = {}
		_pose_attack(kind)
		return
	_vp_dizzy = false
	if kind == "area":
		var rate := 2.0 if _recover_rate <= 0.0 else minf(200.0, _recover_rate * 1.2)
		_set_damage(_boss_damage(), rate)
		_attack_open = 4.21
	elif kind == "recover":
		_attack_open = 5.1
	elif kind == "directed":
		_attack_open = 4.84
	else:
		kind = "front"
		_pending = kind
		_attack_open = 2.65
	_attack_wait = _attack_open
	var damage := _attack_damage(kind)
	var radius := 50.0 if kind == "area" else (4.0 if kind == "directed" else 12.0)
	var delay := 0.2 if kind == "area" else (1.1 if kind == "directed" else _attack_open * 0.55)
	_event = {
		"kind": kind,
		"damage": damage,
		"delay": delay,
		"radius": radius,
		"side": 0,
		"dir": 0,
		"t": float(_boss_damage()) / 100.0,
		"target": 0,
	}
	_pose_attack(kind)


func _enter_near() -> void:
	_near = true
	_vp_dizzy = true
	_attack_wait = 99999.0
	_strafe_wait = 99999.0
	_attack_open = 99999.0
	_pending = ""
	_event = {}
	_say("He is down. One more pie in the doors.")


func _attack_damage(kind: String) -> int:
	var amount := 3
	if kind == "area":
		amount = 10
	elif kind == "strafe":
		amount = 2
	elif kind == "swat":
		amount = 5
	if nerfed():
		amount = maxi(int(round(float(amount) * 0.5)), 1)
	return amount


func _start_victory() -> void:
	if _vp_ending:
		return
	_vp_ending = true
	if _show != null:
		_show.call("play", "victory")
	else:
		_go("reward")


func _pose_attack(kind: String) -> void:
	if _show == null or kind == "" or kind == "strafe":
		return
	var which := "neutral"
	if kind == "dizzy":
		which = "hit"
	elif kind == "downhit":
		which = "downhit"
	elif kind == "area":
		which = "jump"
	elif kind == "directed":
		which = "throw"
	elif kind == "front" or kind == "recover":
		which = "spin"
	_show.call("pose", which)


func _adopt_vp() -> Dictionary:
	var snap := ToonNet.latest("vp-pies")
	var event := {}
	var was_dizzy := _vp_dizzy
	if bool(snap.get("live", false)):
		_stored = int(snap.get("hp", 0))
		_recover_rate = 0.0
		_recover_at = _clock
		_hp = _stored
		_hits = int(snap.get("hits", 0))
		_vp_dizzy = bool(snap.get("dizzy", false))
		_near = bool(snap.get("near", false))
		_net_doors = bool(snap.get("doors", false))
		if bool(snap.get("ending", false)):
			_start_victory()
		var seq := int(snap.get("seq", 0))
		if seq != _vp_seq:
			_vp_seq = seq
			var raw: Variant = snap.get("event", {})
			if raw is Dictionary:
				event = raw
			var kind := str(event.get("kind", ""))
			if kind != "":
				_pose_attack(kind)
			elif _vp_dizzy and not was_dizzy:
				_pose_attack("dizzy")
		elif _vp_dizzy and not was_dizzy:
			_pose_attack("dizzy")
	var state := _vp_state()
	state["event"] = event
	return state


func _vp_state() -> Dictionary:
	var doors := _net_doors if ToonNet.networked() else (_vp_dizzy or _attack_open > 0.0 or _strafe_open > 0.0 or _near)
	return {
		"doors": doors,
		"dizzy": _vp_dizzy,
		"near": _near,
		"hp": _boss_damage(),
		"pies": _pies_left,
		"attack": _pending,
	}


func _check_boss() -> void:
	_paint_bar()
	if _kind == "vp":
		return
	if _hp >= _max_hp and not _over:
		if _kind == "cfo" and _phase == "cranes":
			_phase = "flee"
			_rounds.call("start_flee")
			return
		_go("reward")


func current_phase() -> String:
	return _phase


static var _stamp := 0


func _stamp_now() -> int:
	_stamp += 1
	return ToonNet.peer_id() * 100000 + _stamp


func magic_command(command: String) -> String:
	var parent := get_parent()
	var file := "" if parent == null else parent.scene_file_path.get_file()
	if ToonNet.networked() and not ToonNet.is_authority():
		ToonNet.share_dev("boss", {
			"file": file,
			"district": ToonNet.district_id(),
			"command": command,
			"serial": _stamp_now(),
		})
		return "Asked the district to run ~boss %s." % command
	var before := _phase
	var reply := _run_magic(command)
	if _phase != before:
		_publish_phase(file)
	return reply


func _follow_phase() -> void:
	var snap := ToonNet.latest("dev:boss")
	var serial := int(snap.get("serial", 0))
	if serial == 0 or serial == _phase_seen:
		return
	var parent := get_parent()
	var file := "" if parent == null else parent.scene_file_path.get_file()
	if String(snap.get("file", "")) != file or int(snap.get("district", -1)) != ToonNet.district_id():
		return
	if snap.has("command"):
		if not ToonNet.is_authority():
			return
		_phase_seen = serial
		magic_command(String(snap.get("command", "")))
		return
	_phase_seen = serial
	var phase := String(snap.get("phase", ""))
	if phase != "" and phase != _phase:
		_go(phase)


func _publish_phase(file: String) -> void:
	var serial := _stamp_now()
	_phase_seen = serial
	ToonNet.share_dev("boss", {
		"file": file,
		"district": ToonNet.district_id(),
		"phase": _phase,
		"serial": serial,
	})


func _run_magic(command: String) -> String:
	var order := {
		"vp": ["intro", "cogs", "roll", "prepare2", "skele", "prepare3", "pies", "reward"],
		"cfo": ["intro", "cogs", "cranes", "reward"],
		"cj": ["intro", "cogs", "cannons", "evidence", "reward"],
		"ceo": ["intro", "cogs", "banquet", "cogs2", "seltzer", "reward"],
	}
	var final_phase := {"vp": "pies", "cfo": "cranes", "cj": "evidence", "ceo": "seltzer"}
	if command == "start":
		_go("intro")
		return "Boss battle started."
	if command == "stop":
		return "This boss has no Frolic state yet."
	if command == "skip":
		var steps: Array = order.get(_kind, [])
		var index := steps.find(_phase)
		if index < 0 or index + 1 >= steps.size():
			return "Cannot skip the %s state." % _phase
		var next := String(steps[index + 1])
		_go(next)
		return "Skipped to %s." % next
	if command == "final" or command == "pie" or command == "crane":
		_go(String(final_phase.get(_kind, "reward")))
		return "Skipped to the final round."
	if command == "kill" or command == "victory" or command == "finish":
		_go("reward")
		return "Killed the boss."
	return ""


func say_for(text: String, seconds: float) -> void:
	_note = text
	_note_left = seconds


func _say(text: String) -> void:
	say_for(text, 1.8)


func _paint_bar() -> void:
	if _bar == null:
		return
	_bar.max_value = float(_max_hp)
	_bar.value = float(clampi(_hp, 0, _max_hp))


func _hurt(amount: int) -> void:
	var loadout := _loadout()
	if loadout == null or amount <= 0:
		return
	loadout.take_damage(amount)
	loadout.save()
	if loadout.hp <= 0:
		_defeat()


func _heal(amount: int) -> void:
	var loadout := _loadout()
	if loadout == null:
		return
	loadout.gain_hp(amount)
	loadout.save()


func _defeat() -> void:
	if _over:
		return
	if _rounds != null:
		_rounds.call("shutdown")
	_over = true
	load("res://scenes/playgrounds/playground_toon.gd").went_sad = true
	_GATE.trip = "out"
	ToonLoading.change_to(_lobby)


func _loadout() -> ToonLoadout:
	return ToonLoadout.for_selected()


func _journal() -> ToonTasks:
	return ToonTasks._live


func fight_key() -> String:
	if _fight_id == 0 or _battle_slug == "":
		return ""
	return "%d:%s" % [ToonNet.district_id(), _battle_slug]


func _watch_fight() -> void:
	var rows: Array = ToonNet.latest("fights:" + fight_key()).get("rows", [])
	var found: Dictionary = {}
	for item in rows:
		if item is Dictionary and int((item as Dictionary).get("id", 0)) == _fight_id:
			found = item
			break
	if found.is_empty():
		if not _fight_seen:
			return
		var alive := _loadout()
		_close_battle()
		if alive != null and alive.hp <= 0:
			return
		_advance_from_cogs()
		return
	_fight_seen = true
	_sync_suits(found)


func _close_battle() -> void:
	_fight_id = 0
	_fight_seen = false
	if _layer != null:
		_layer.visible = true
	if _suits == null:
		return
	for child in _suits.get_children():
		child.queue_free()


func _open_vp_sides(skeleton: bool) -> bool:
	var code := 10 if skeleton else 9
	if nerfed():
		code = 16 if skeleton else 15
	var left := _building_floor(code, skeleton, 0)
	var right := _building_floor(code, skeleton, 0)
	for key in ["active", "reserves"]:
		for cog in right.get(key, []):
			if cog is Dictionary:
				cog["id"] = int(cog.get("id", 0)) + 500
	var teams := vp_teams()
	var side_a: Array = teams[0]
	var side_b: Array = teams[1]
	if side_a.is_empty() and not side_b.is_empty():
		var held := side_a
		side_a = side_b
		side_b = held
		var swapped := left
		left = right
		right = swapped
	if side_a.is_empty():
		return false
	if side_b.is_empty():
		_fold_reserves(left, right)
	var mine := ToonNet.peer_id()
	var opened := _open_boss_side(left, side_a, 0, skeleton)
	if not side_b.is_empty():
		var kept_id := _fight_id
		var kept_slug := _battle_slug
		if _open_boss_side(right, side_b, 1, skeleton) and not side_b.has(mine):
			_fight_id = kept_id
			_battle_slug = kept_slug
			opened = kept_id != 0
		elif side_b.has(mine):
			opened = _fight_id != 0
	_title.text = "Battle Two" if skeleton else "Battle One"
	_body.text = "The V.P.'s skelecogs." if skeleton else "The V.P.'s cogs."
	if _show != null:
		_show.call("music", "battle2" if skeleton else "battle")
	return opened


func _fold_reserves(plan: Dictionary, extra: Dictionary) -> void:
	# An empty side's suits wait in reserve and join as soon as a spot opens.
	var reserves: Array = plan.get("reserves", [])
	for cog in extra.get("active", []):
		if cog is Dictionary:
			cog["join"] = 0
			reserves.append(cog)
	for cog in extra.get("reserves", []):
		if cog is Dictionary:
			reserves.append(cog)
	plan["reserves"] = reserves


func reset_vp_teams() -> void:
	_vp_teams.clear()


func vp_teams() -> Array:
	if _vp_teams.is_empty():
		_vp_teams = _divide_boss_toons()
	return _vp_teams


func _divide_boss_toons() -> Array:
	# Same split on every client. Storm Sellbot puts finished suits first, then alternates.
	var peers := _seeded_order(_boss_peers())
	var num := mini(peers.size(), 8)
	var team_a: Array = []
	var team_b: Array = []
	if nerfed():
		var ordered: Array = []
		var rentals: Array = []
		for id in peers.slice(0, num):
			if _rental_suit(int(id)):
				rentals.append(id)
			else:
				ordered.append(id)
		ordered.append_array(rentals)
		for index in ordered.size():
			if index % 2 == 0:
				team_a.append(ordered[index])
			else:
				team_b.append(ordered[index])
	else:
		var num_b := num / 2
		if num >= 4:
			num_b = (num + (_split_bit(peers) % 2)) / 2
		team_b = peers.slice(0, num_b)
		team_a = peers.slice(num_b, num)
	return [team_a, team_b]


func _rental_suit(peer: int) -> bool:
	if peer == ToonNet.peer_id():
		return not DisguisePage.suit_complete(3)
	return not bool(ToonNet.latest("toon:%d" % peer).get("suit_ready", false))


func _seeded_order(peers: Array) -> Array:
	var copy: Array = peers.duplicate()
	copy.sort()
	var state := 1
	for id in copy:
		state = int((int(state) * 1103515245 + int(id) + 12345) & 0x7fffffff)
	for index in range(copy.size() - 1, 0, -1):
		state = int((int(state) * 1103515245 + 12345) & 0x7fffffff)
		var swap := state % (index + 1)
		var held: Variant = copy[index]
		copy[index] = copy[swap]
		copy[swap] = held
	return copy


func _split_bit(peers: Array) -> int:
	var state := 1
	for id in peers:
		state = int((int(state) * 1103515245 + int(id)) & 0x7fffffff)
	return state


func _boss_peers() -> Array:
	var peers: Array = [ToonNet.peer_id()]
	var host := get_parent()
	if host != null:
		for node in host.find_children("", "ToonActor", true, false):
			if not node.has_meta("peer"):
				continue
			var peer := int(node.get_meta("peer"))
			if peer > 0 and not peers.has(peer):
				peers.append(peer)
	return peers


func _boss_rider(peer: int) -> Dictionary:
	if peer == ToonNet.peer_id():
		var avatar := _avatar()
		var loadout := _loadout()
		return {
			"id": peer,
			"name": String(avatar.call("battle_name")) if avatar != null else "Toon",
			"hp": loadout.hp if loadout != null else 15,
			"max_hp": loadout.max_hp if loadout != null else 15,
		}
	var state := ToonNet.latest("toon:%d" % peer)
	return {
		"id": peer,
		"name": String(state.get("name", "Toon")),
		"hp": int(state.get("hp", 15)),
		"max_hp": int(state.get("max_hp", 15)),
	}


func _open_boss_side(plan: Dictionary, peers: Array, side: int, skeleton: bool) -> bool:
	if peers.is_empty():
		return false
	var riders: Array = []
	for peer in peers:
		riders.append(_boss_rider(int(peer)))
	var round_number := 2 if skeleton else 1
	_battle_round = round_number
	_battle_slug = "boss_vp_%d_%s" % [round_number, "b" if side == 1 else "a"]
	var depth := 60.0 if skeleton else -35.0
	var height := 18.0 if skeleton else 0.0
	# BossCogBattleAPosHpr / B, composed with the boss heading of -90.
	var origin := _panda_world(Vector3(25.0 if side == 1 else -25.0, depth, height))
	var fights := get_node_or_null("/root/StreetTraffic/StreetFights")
	if fights == null or not fights.has_method("open_roster"):
		return false
	var fight_id := int(fights.call(
		"open_roster",
		ToonNet.district_id(),
		_battle_slug,
		plan.get("active", []),
		plan.get("reserves", []),
		riders,
		origin,
		180.0,
		0,
		[origin.x, origin.y, origin.z],
		false,
		0,
		round_number
	))
	if fight_id == 0:
		return false
	_fight_id = fight_id
	_fight_seen = false
	if _layer != null:
		_layer.visible = false
	return true


func _claim_vp_fight() -> void:
	var round_number := 2 if _phase == "skele" else 1
	for side in ["a", "b"]:
		var slug := "boss_vp_%d_%s" % [round_number, side]
		var key := "%d:%s" % [ToonNet.district_id(), slug]
		var rows: Array = ToonNet.latest("fights:" + key).get("rows", [])
		for item in rows:
			if not (item is Dictionary):
				continue
			var fight: Dictionary = item
			for toon in fight.get("toons", []):
				if toon is Dictionary and int((toon as Dictionary).get("id", -1)) == ToonNet.peer_id():
					_fight_id = int(fight.get("id", 0))
					_battle_slug = slug
					_battle_round = round_number
					_fight_seen = false
					if _layer != null:
						_layer.visible = false
					if _show != null:
						_show.call("music", "battle2" if round_number == 2 else "battle")
					return


func _panda_world(panda: Vector3) -> Vector3:
	var host := get_parent()
	var geom := host.get_node_or_null("Geometry") as Node3D if host != null else null
	if geom == null:
		return panda
	return geom.global_transform * panda


func _open_battle(active: Variant, reserves: Variant, round_number: int) -> bool:
	var cogs: Array = active if active is Array else []
	var waiting: Array = reserves if reserves is Array else []
	if cogs.is_empty():
		return false
	var fights := get_node_or_null("/root/StreetTraffic/StreetFights")
	var avatar := _avatar()
	var loadout := _loadout()
	if fights == null or avatar == null or loadout == null or not fights.has_method("open_roster"):
		return false
	_battle_round = round_number
	_battle_slug = "boss_%s_%d" % [_kind, round_number]
	var origin: Vector3 = avatar.call("battle_point")
	var rider := {
		"id": ToonNet.peer_id(),
		"name": String(avatar.call("battle_name")),
		"hp": loadout.hp,
		"max_hp": loadout.max_hp,
	}
	var fight_id := int(fights.call(
		"open_roster",
		ToonNet.district_id(),
		_battle_slug,
		cogs,
		waiting,
		[rider],
		origin,
		180.0,
		0,
		[origin.x, origin.y, origin.z],
		false,
		0,
		round_number
	))
	if fight_id == 0:
		return false
	_fight_id = fight_id
	_fight_seen = false
	if _layer != null:
		_layer.visible = false
	return true


func _sync_suits(fight: Dictionary) -> void:
	if _suits == null:
		return
	var wanted := {}
	for item in fight.get("cogs", []):
		if item is Dictionary:
			wanted[int((item as Dictionary).get("id", 0))] = item
	var have := {}
	for child in _suits.get_children():
		have[int(child.get_meta("do_id", 0))] = child
	for id in have.keys():
		if wanted.has(int(id)):
			continue
		var actor: Variant = have[id]
		if actor is Node and bool((actor as Node).get_meta("in_fight", false)):
			continue
		if actor is Node:
			(actor as Node).queue_free()
	for id in wanted.keys():
		if have.has(int(id)):
			continue
		var cog: Dictionary = wanted[id]
		var body := StreetCog.new()
		body.name = "BossCog%d" % int(id)
		_suits.add_child(body)
		body.present(cog, {})
		body.set_meta("do_id", int(id))
		body.hold_fight(true, _slot_point(cog.get("slot", [])), 0.0)


func _battle_plan(hard: bool, skeleton: bool) -> Dictionary:
	if _kind == "vp" and skeleton:
		var skele := _building_floor(16 if nerfed() else 10, true, 0)
		skele["title"] = "Battle Two"
		skele["blurb"] = "The V.P.'s skelecogs."
		skele["round"] = 2
		return skele
	if _kind == "vp":
		var sellbots := _building_floor(15 if nerfed() else 9, false, 0)
		sellbots["title"] = "Battle One"
		sellbots["blurb"] = "The V.P.'s cogs."
		sellbots["round"] = 1
		return sellbots
	if _kind == "cfo":
		var merged := _cfo_floor()
		merged["title"] = "Battle One"
		merged["blurb"] = "The C.F.O.'s cogs and skelecogs."
		merged["round"] = 1
		return merged
	if _kind == "cj":
		var lawyers := _building_floor(13, false, 1)
		lawyers["title"] = "Battle One"
		lawyers["blurb"] = "The Chief Justice's cogs."
		lawyers["round"] = 1
		return lawyers
	if hard:
		var diners := _diner_floor()
		diners["title"] = "Battle Three"
		diners["blurb"] = "The cogs who were not fed three times, and two level 12 v2.0s."
		diners["round"] = 3
		return diners
	var waiters := _building_floor(14, false, 1)
	_fill_active(waiters)
	waiters["title"] = "Battle One"
	waiters["blurb"] = "The C.E.O.'s cogs."
	waiters["round"] = 1
	return waiters


func _cfo_floor() -> Dictionary:
	var plain := _building_floor(11, false, 0)
	var bones := _building_floor(12, true, 0)
	var active: Array = plain.get("active", [])
	active.append_array(bones.get("active", []))
	active.shuffle()
	var reserves: Array = plain.get("reserves", [])
	reserves.append_array(bones.get("reserves", []))
	while active.size() > 4:
		var extra: Dictionary = active.pop_back()
		extra["join"] = 100
		reserves.append(extra)
	reserves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("join", 100)) < int(b.get("join", 100))
	)
	return {"active": active, "reserves": reserves}


func _fill_active(plan: Dictionary) -> void:
	var active: Array = plan.get("active", [])
	var reserves: Array = plan.get("reserves", [])
	if active.size() + reserves.size() < 4:
		return
	while active.size() < 4 and not reserves.is_empty():
		var pulled: Dictionary = reserves.pop_back()
		pulled.erase("join")
		active.append(pulled)
	plan["active"] = active
	plan["reserves"] = reserves


func _diner_floor() -> Dictionary:
	var active: Array = []
	for index in 2:
		active.append(_make_cog("c", 12, 8, false, 1, 9000 + index))
	var reserves: Array = []
	for index in _stuffed.size():
		if _stuffed[index]:
			continue
		var cog_type := clampi(_diner_level - 4, 1, 8)
		var cog := _make_cog("c", _diner_level, cog_type, false, 1, 9100 + index)
		cog["join"] = 100
		reserves.append(cog)
	return {"active": active, "reserves": reserves}


func _building_floor(code: int, skeleton: bool, revives: int) -> Dictionary:
	var info: Dictionary = _floor_row(code)
	var pool := randi_range(int(info["pool"]), int(info["pool"]))
	var suit_min := int(info["min"])
	var suit_max := int(info["max"])
	var levels: Array[int] = []
	while pool >= suit_min and levels.size() < 8:
		var picked := randi_range(suit_min, mini(pool, suit_max))
		levels.append(picked)
		pool -= picked
	levels.append(randi_range(int(info["boss"]), int(info["boss"])))
	levels.sort()
	var num_active := randi_range(1, mini(4, levels.size()))
	if levels.size() > 1:
		var boss_at := levels.size() - 1
		var spot := 0 if num_active == 1 else maxi(num_active - 2, 0)
		var swapped := levels[spot]
		levels[spot] = levels[boss_at]
		levels[boss_at] = swapped
	var active: Array = []
	for index in range(num_active - 1, -1, -1):
		active.append(_make_cog(_letter, levels[index], 0, skeleton, revives, code * 100 + active.size()))
	var reserves: Array = []
	var chances: Array[int] = []
	var reserve_count := levels.size() - num_active
	for _index in reserve_count:
		chances.append(randi_range(1, 100))
	chances.sort()
	for index in reserve_count:
		var cog := _make_cog(_letter, levels[num_active + index], 0, skeleton, revives, code * 100 + 20 + index)
		cog["join"] = chances[index]
		reserves.append(cog)
	return {"active": active, "reserves": reserves}


func _floor_row(code: int) -> Dictionary:
	var rows := {
		9: {"min": 1, "max": 12, "boss": 12, "pool": 67},
		10: {"min": 8, "max": 12, "boss": 12, "pool": 100},
		11: {"min": 1, "max": 12, "boss": 12, "pool": 100},
		12: {"min": 8, "max": 12, "boss": 12, "pool": 150},
		13: {"min": 8, "max": 12, "boss": 12, "pool": 275},
		14: {"min": 9, "max": 12, "boss": 12, "pool": 206},
		15: {"min": 1, "max": 5, "boss": 5, "pool": 33},
		16: {"min": 4, "max": 5, "boss": 5, "pool": 50},
	}
	return rows.get(code, rows[9])


func _ceo_table() -> Dictionary:
	var promotions := DisguisePage.promotions(0)
	var rank := clampi(int(float(promotions) / 77.0 * 5.0), 0, 4)
	# BossbotBossDifficultySettings: tables, diners per table, diner level.
	var rows: Array = [
		{"tables": 8, "diners": 4, "level": 11},
		{"tables": 9, "diners": 5, "level": 12},
		{"tables": 10, "diners": 6, "level": 11},
		{"tables": 8, "diners": 8, "level": 12},
		{"tables": 13, "diners": 5, "level": 12},
	]
	return rows[rank]


func _make_cog(dept: String, level: int, forced_type: int, skeleton: bool, revives: int, cog_id: int) -> Dictionary:
	var cog_type := forced_type
	if cog_type <= 0:
		cog_type = randi_range(maxi(level - 4, 1), mini(level, 8))
	var found := _catalog_cog(dept, cog_type)
	var hp := Cog.hp_for_level(level)
	return {
		"id": 800000 + cog_id,
		"code": String(found.get("code", "f")),
		"name": String(found.get("name", "Cog")),
		"dept": dept,
		"body": String(found.get("body", "c")),
		"height": float(found.get("height", 4.0)),
		"level": level,
		"hp": hp,
		"max": hp,
		"skeleton": skeleton,
		"revives": revives,
		"noted": false,
	}


func _catalog_cog(dept: String, cog_type: int) -> Dictionary:
	_load_catalog()
	for item in _boss_catalog:
		if not (item is Dictionary):
			continue
		var cog: Dictionary = item
		if String(cog.get("dept", "")) == dept and int(cog.get("type", 0)) == cog_type:
			return cog
	return {}


static var _boss_catalog: Array = []
static var _boss_gen := -1


func _load_catalog() -> void:
	if _boss_gen == CogCatalog.generation() and not _boss_catalog.is_empty():
		return
	var rows: Variant = CogCatalog.data().get("cogs", [])
	if rows is Array:
		_boss_catalog = rows
		_boss_gen = CogCatalog.generation()


func _slot_point(raw: Variant) -> Vector3:
	if raw is Array and (raw as Array).size() >= 3:
		var row: Array = raw
		return Vector3(float(row[0]), float(row[1]), float(row[2]))
	return Vector3.ZERO


func _avatar() -> Node:
	var host := get_parent()
	if host == null:
		return null
	for child in host.get_children():
		if child.has_method("battle_name"):
			return child
	return null


func _button(text: String, call: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(call)
	_row.add_child(button)
	return button


func _clear_row() -> void:
	if _row == null:
		return
	for child in _row.get_children():
		if child is BaseButton:
			child.disabled = true
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		child.queue_free()
