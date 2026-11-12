extends Node

## The four department bosses. State order, health, and rewards follow
## DistributedSellbotBoss, DistributedCashbotBoss, DistributedLawbotBoss, and
## DistributedBossbotBoss. Cog rounds use the toon's gags. The signature round
## uses that boss's damage rule.

const _GATE := preload("res://scenes/cog_hq/boss_gate.gd")
const _REWARDS := preload("res://scenes/cog_hq/boss_rewards.gd")

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
var _pies_left := 0
var _helmet := false
var _gave_helmet := false
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
	_go("intro")


func _process(delta: float) -> void:
	_follow_phase()
	if _over:
		return
	if _fight_id != 0:
		_watch_fight()
		return
	_clock += delta
	_cool = maxf(_cool - delta, 0.0)
	_stun = maxf(_stun - delta, 0.0)
	if _phase != "cranes":
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
	if _rounds != null:
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
	elif phase == "pies":
		_start_pies()
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
	_body.text = _intro_line()
	_button("Continue", _after_intro)


func _intro_line() -> String:
	if _kind == "vp":
		return "The Senior V.P. is in. Defeat his cogs, then his skelecogs. A pie in the open undercarriage stuns him. Pies on his body do 1 damage only while he is stunned. He falls at 100."
	if _kind == "cfo":
		return "The Chief Financial Officer is in the vault. Defeat his cogs, then use the cranes. The first safe becomes his helmet. Knock it off, drop a goon to dizzy him, then safes do up to 50. He falls at 500."
	if _kind == "cj":
		return "The Chief Justice is seated. Fire yourself into the jury chairs, then throw evidence onto the defense pan. The scale starts at 1350 and needs 2700."
	return "The Chief Executive Officer is at the banquet. Carry food from the belt to a hungry cog, fight whoever is still standing, then charge the seltzer. He falls at 500."


func _after_intro() -> void:
	_go("cogs")


func _start_cogs(hard: bool, skeleton: bool = false) -> void:
	# BattleOne / BattleTwo are DistributedBattleFinal fights. The roster is
	# SuitPlannerInterior for that boss's building code, with reserves.
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
			var damage := ToonLoadout.gag_damage(track, level, loadout.experience_of(track))
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
	var damage := ToonLoadout.gag_damage(track, level, loadout.experience_of(track))
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
		loadout.add_experience(track, (level + 1) * 2)
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
		_go("pies")
		return
	if _kind == "vp":
		_go("skele")
	elif _kind == "cfo":
		_go("cranes")
	elif _kind == "cj":
		_go("cannons")
	else:
		_go("banquet")


func _start_pies() -> void:
	_title.text = "Battle Three"
	_hp = 0
	_pies_left = 0
	_stun = 0.0
	_paint_bar()
	_rounds.call("start_vp", self)


func _start_cranes() -> void:
	_title.text = "Battle Three"
	_hp = 0
	_helmet = false
	_gave_helmet = false
	_dizzy = 0.0
	_paint_bar()
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
		lines.append(_REWARDS.grant_sos())
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
	_button("Return to the lobby", _leave)


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
		_pies_left = 20
		return
	_pies_left = 20
	_say("You picked up a stack of pies.")


func take_pie() -> bool:
	if _pies_left <= 0:
		_say("Get pies from a pie pile.")
		return false
	_pies_left -= 1
	return true


func note_pie(insides: bool) -> void:
	if insides:
		_stun = 4.0
		_say("The undercarriage is open. He is stunned.")
		return
	if _stun <= 0.0:
		_say("That pie hit his armor.")
		return
	_hp = mini(_hp + 1, _max_hp)
	_say("The pie did 1.")
	_check_boss()


func note_vp_attack(kind: String) -> void:
	if _stun > 0.0:
		return
	var amount := 2
	if kind == "swat":
		amount = 5
	elif kind == "area":
		amount = 10
	_hurt(amount)
	_say("The V.P. hit you for %d." % amount)


func note_safe(impact: float) -> void:
	if _dizzy > 0.0:
		_record_cfo(maxi(2, int(impact * 50.0)))
		return
	if _helmet and impact >= 0.5:
		_helmet = false
		_say("The helmet flew off.")
		return
	if not _helmet and not _gave_helmet:
		_helmet = true
		_gave_helmet = true
		_say("He caught the safe and wore it as a helmet.")
		return
	_say("The safe bounced off.")


func note_goon_hit(impact: float) -> void:
	_record_cfo(maxi(2, int(impact * 25.0)))


func _record_cfo(damage: int) -> void:
	_hp = mini(_hp + damage, _max_hp)
	if _dizzy <= 0.0 and damage >= 15:
		_dizzy = 5.0
		_helmet = false
		_say("The hit did %d and dizzied him." % damage)
	elif _dizzy > 0.0 and damage < 15:
		_dizzy = 0.0
		_say("The hit did %d. He shook it off." % damage)
	else:
		_say("The hit did %d." % damage)
	_check_boss()


func note_goon() -> void:
	_hurt(5)
	_say("A goon zapped you for 5.")


func note_treasure() -> void:
	_heal(5)
	_say("The treasure restored 5 laff.")


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


func _check_boss() -> void:
	_paint_bar()
	if _hp >= _max_hp and not _over:
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
		"vp": ["intro", "cogs", "skele", "pies", "reward"],
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


func _say(text: String) -> void:
	_note = text
	_note_left = 1.8


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
		var skele := _building_floor(10, true, 0)
		skele["title"] = "Battle Two"
		skele["blurb"] = "The V.P.'s skelecogs."
		skele["round"] = 2
		return skele
	if _kind == "vp":
		var sellbots := _building_floor(9, false, 0)
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
