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
var _treasures: Array[Vector3] = []
var _crane := -1
var _crane_h := 0.0
var _crane_y := 16.0
var _magnet := Vector3.ZERO
var _held := -1
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
var _door_open := true
var _pressed := false
var _cage := Vector3.ZERO
var _jury: Node3D
var _jury_start := Vector3.ZERO
var _belt_at := Vector3.ZERO


func shutdown() -> void:
	_mode = ""
	_free_toon()
	if _root != null:
		_root.queue_free()
		_root = null


func start_vp(boss: Node) -> void:
	_begin(boss)
	_mode = "vp"
	# SellbotBossBattleTwoPosHpr. Battle three is fought from this end of the room.
	var boss_node := _panda_box(0.0, 60.0, 18.0, Color(0.45, 0.15, 0.55), Vector3(4.0, 8.0, 3.0), "VP")
	_boss_pos = boss_node.global_position
	var cage := _find("cage")
	_cage = cage.global_position if cage != null else _panda_box(0.0, 77.9, 18.0, Color(0.95, 0.55, 0.2), Vector3(2.0, 2.0, 2.0), "Pies").global_position
	_tell("The pie cage is at the back of the room. Click to throw. His doors open when he attacks and stay open while he is stunned. A pie in the opening stuns him. Pies on his body do 1 only then. Step out of the red attack. Strafe is 2, swat is 5, area is 10.")


func start_cranes(boss: Node) -> void:
	_begin(boss)
	_mode = "cfo"
	# CashbotBossBattleThreePosHpr.
	var boss_node := _panda_box(120.0, -315.0, 10.0, Color(0.15, 0.45, 0.2), Vector3(3.0, 6.0, 2.4), "CFO")
	_boss_pos = boss_node.global_position
	var cranes := [Vector3(97.4, -337.6, 0.0), Vector3(97.4, -292.4, 0.0), Vector3(142.6, -292.4, 0.0), Vector3(142.6, -337.6, 0.0)]
	for index in cranes.size():
		_panda_box(cranes[index].x, cranes[index].y, cranes[index].z, Color(0.2, 0.35, 0.7), Vector3(2.0, 0.5, 2.0), "Crane%d" % index)
	var safes := [Vector3(77.2, -329.3, 0.0), Vector3(77.1, -302.7, 0.0), Vector3(165.7, -326.4, 0.0), Vector3(165.5, -302.4, 0.0), Vector3(107.8, -359.1, 0.0), Vector3(133.9, -359.1, 0.0), Vector3(107.0, -274.7, 0.0), Vector3(134.2, -274.7, 0.0)]
	for index in safes.size():
		var node := _model_or_box("", safes[index], "Safe%d" % index, Color(0.85, 0.75, 0.2), Vector3(1.6, 1.4, 1.6))
		_safes.append({"at": node.global_position, "fall": 0.0, "node": node})
	for index in 4:
		var spot := Vector3(110.0 + float(index) * 8.0, -320.0, 0.0)
		var goon := _model_or_box("res://assets/cog_hq/goon.glb", spot, "Goon%d" % index, Color(0.35, 0.35, 0.4), Vector3(1.2, 1.8, 1.2))
		_goons.append({"at": goon.global_position, "cool": 0.0, "node": goon})
	_tell("The cranes are CashbotBossCranePosHprs, around the vault. Press E to take one. A and D turn it from -45 to 45 degrees, W and S slide it. Click grabs or drops. Impact is how far the safe falls. A helmet needs 0.5 or more to knock off. A goon dropped on him can dizzy him.")


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
	var state: Dictionary = _boss.call("world_state")
	_door_open = _attack_left > 0.0 or float(state.get("stun", 0.0)) > 0.0
	var boss_mesh := _root.get_node_or_null("VP") as Node3D
	if boss_mesh != null:
		boss_mesh.scale = Vector3(1, 1, 1) if _door_open else Vector3(1, 0.55, 1)
	if _near(body, _cage, 3.5):
		_boss.call("restock_pies")
	if _fresh_press() and bool(_boss.call("take_pie")):
		_launch(body, 26.0, Color(0.95, 0.45, 0.55), "pie")
	_fly(_pies, delta)
	for shot in _pies:
		if bool(shot["done"]):
			continue
		if _near_point(shot["at"], _boss_pos, 2.4):
			shot["done"] = true
			_boss.call("note_pie", _door_open)
	if _attack_left > 0.0:
		_attack_left -= delta
		if _attack_left <= 0.0 and _near(body, _attack_at, 3.2):
			_boss.call("note_vp_attack", _attack_kind)
	elif _clock > 6.0 and fposmod(_clock, 7.5) < delta:
		_attack_kind = "area" if randi() % 3 == 0 else ("swat" if randi() % 2 == 0 else "strafe")
		_attack_at = body.global_position
		_attack_left = 1.2
		_replace_marker("Attack", _attack_at, Color(0.8, 0.15, 0.15), Vector3(3.0, 0.15, 3.0))
	_boss.call("paint_world", "Undercarriage %s." % ("OPEN" if _door_open else "shut"))


func _tick_cfo(delta: float, body: CharacterBody3D) -> void:
	if _crane < 0:
		if _KEYS.use_held() and _cool <= 0.0:
			var pads := _named("Crane")
			for index in pads.size():
				if _near(body, pads[index].global_position, 2.4):
					_crane = index
					_magnet = pads[index].global_position + Vector3(0, 6.0, 0)
					_cool = 0.3
					_lock_toon()
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
		_crane_h = clampf(_crane_h + turn * delta * 40.0, -45.0, 45.0)
		_crane_y = clampf(_crane_y + slide * delta * 10.0, 8.0, 25.0)
		var aim := Vector3(sin(deg_to_rad(_crane_h)), 0, -cos(deg_to_rad(_crane_h)))
		var pad := _named("Crane")[_crane]
		_magnet = pad.global_position + aim * (_crane_y - 8.0) + Vector3(0, 7.0, 0)
		if _fresh_press():
			if _held >= 0:
				_drop_safe()
			else:
				_grab_safe()
		if _KEYS.use_held() and _cool <= 0.0 and _held < 0:
			_crane = -1
			_cool = 0.3
			_free_toon()
	for index in _safes.size():
		var safe: Dictionary = _safes[index]
		var node := _root.get_node_or_null("Safe%d" % index) as Node3D
		if node == null:
			continue
		if _held == index:
			node.global_position = _magnet
			safe["at"] = _magnet
		elif float(safe["fall"]) > 0.0:
			safe["fall"] = float(safe["fall"]) - delta
			var at: Vector3 = safe["at"]
			at.y = lerpf(0.6, 7.0, float(safe["fall"]) / 0.55)
			node.global_position = at
			if float(safe["fall"]) <= 0.0:
				_land_safe(at, float(safe.get("impact", 0.5)))
		else:
			node.global_position = safe["at"]
		_safes[index] = safe
	for index in _goons.size():
		var goon: Dictionary = _goons[index]
		var at: Vector3 = goon["at"]
		if _held == 100 + index:
			at = _magnet
		else:
			at += _right * sin(_clock + float(index)) * delta * 2.0
		goon["at"] = at
		goon["cool"] = maxf(float(goon["cool"]) - delta, 0.0)
		var node := _root.get_node_or_null("Goon%d" % index) as Node3D
		if node != null:
			node.global_position = at
		if float(goon["cool"]) <= 0.0 and _near(body, at, 1.6):
			goon["cool"] = 2.0
			_boss.call("note_goon")
		_goons[index] = goon
	var kept: Array[Vector3] = []
	for treasure in _treasures:
		if _near(body, treasure, 1.4):
			_boss.call("note_treasure")
		else:
			kept.append(treasure)
	_treasures = kept
	_boss.call("paint_world", "Crane %s." % ("in use" if _crane >= 0 else "empty"))


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
		if float(_safes[index]["fall"]) > 0.0:
			continue
		var gap := Vector2(_magnet.x, _magnet.z).distance_to(Vector2(_safes[index]["at"].x, _safes[index]["at"].z))
		if gap < best_d:
			best_d = gap
			best = index
	_held = best
	if best >= 0:
		return
	var goon_best := -1
	var goon_d := 3.0
	for index in _goons.size():
		var gap := Vector2(_magnet.x, _magnet.z).distance_to(Vector2(_goons[index]["at"].x, _goons[index]["at"].z))
		if gap < goon_d:
			goon_d = gap
			goon_best = index
	if goon_best >= 0:
		_held = 100 + goon_best


func _drop_safe() -> void:
	if _held < 0:
		return
	if _held >= 100:
		var index := _held - 100
		var at := _magnet
		_goons[index]["at"] = at
		_held = -1
		if _near_point(at, _boss_pos, 3.2):
			_boss.call("note_goon_hit", clampf((_magnet.y - 1.0) / 12.0, 0.15, 1.0))
			_goons[index]["at"] = _origin + Vector3(0, -40, 0)
		return
	var safe: Dictionary = _safes[_held]
	safe["at"] = _magnet
	safe["fall"] = 0.55
	safe["impact"] = clampf((_magnet.y - 1.0) / 12.0, 0.15, 1.0)
	_safes[_held] = safe
	_held = -1


func _land_safe(at: Vector3, impact: float) -> void:
	if _near_point(Vector3(at.x, 0.0, at.z), _boss_pos, 4.0):
		_boss.call("note_safe", impact)
		return
	for index in _goons.size():
		if _near_point(at, _goons[index]["at"], 1.8):
			_goons[index]["at"] = _origin + Vector3(0, -40, 0)
			_treasures.append(Vector3(at.x, 0.4, at.z))
			_box(_treasures.back(), Color(0.4, 0.85, 0.45), Vector3(0.45, 0.45, 0.45), "Treasure%d" % _treasures.size())
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


func _named(node_name: String) -> Array[Node3D]:
	var found: Array[Node3D] = []
	if _root == null:
		return found
	for child in _root.get_children():
		if child is Node3D and String(child.name).begins_with(node_name):
			found.append(child)
	return found
