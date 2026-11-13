extends Node

## DistributedBattleAI for a street. The district server owns the round:
## who joined, which gag each toon picked, and whether it hit. Clients only
## show that. A battle holds four toons and four cogs. The face-off plays
## before choosing. The clock is BBbattleInputTimeout, not a delay before the fight.

const _HOLIDAYS := preload("res://scenes/shticker/calendar_holidays.gd")
const _FACTORY := preload("res://scenes/cog_hq/factory_props.gd")
const _MINT := preload("res://scenes/cog_hq/mint_props.gd")
const INPUT_TIME := 20.0
const REWARD_TIME := 120.0
## BattleBase.FLOOR_REWARD_TIMEOUT. A cleared floor dances, then the elevator.
const FLOOR_REWARD_TIME := 4.0
const FACEOFF_TAUNT_T := 3.5
const SUIT_SPEED := 4.8
const MAX_TOONS := 4
const MAX_COGS := 4
const NEAR_COG := 15.0
## BattleCalculatorAI. Track experience, earlier hits, and the lure's duration.
const _EXP_BONUS: Array[int] = [0, 10, 20, 30, 40, 50, 60]
const _PREV_BONUS: Array[int] = [0, 20, 40, 60]
const _LURE_ROUNDS: Array[int] = [2, 2, 3, 3, 4, 4, 15]
const _MAX_TOON_ACC := 95
## SuitBattleGlobals.SuitAttributes def, indexed by the cog's relative level.
const _SUIT_DEF := {
	"ac": [15, 20, 25, 30, 35],
	"b": [5, 10, 15, 20, 25],
	"bc": [15, 20, 25, 30, 35],
	"bf": [2, 5, 10, 12, 15],
	"bs": [20, 25, 30, 35, 40],
	"bw": [35, 40, 45, 50, 55],
	"cc": [2, 5, 10, 12, 15],
	"cr": [30, 35, 40, 45, 50],
	"ds": [20, 25, 30, 35, 40],
	"dt": [10, 15, 20, 25, 30],
	"f": [2, 5, 10, 12, 15],
	"gh": [15, 20, 25, 30, 35],
	"hh": [25, 30, 35, 40, 45],
	"le": [30, 35, 40, 45, 50],
	"ls": [30, 35, 40, 45, 50],
	"m": [30, 35, 40, 45, 50],
	"mb": [25, 30, 35, 40, 45],
	"mh": [35, 40, 45, 50, 55],
	"mm": [15, 20, 25, 30, 35],
	"ms": [20, 25, 30, 35, 40],
	"nc": [20, 25, 30, 35, 40],
	"nd": [10, 15, 20, 25, 30],
	"p": [5, 10, 15, 20, 25],
	"pp": [5, 10, 15, 20, 25],
	"rb": [35, 40, 45, 50, 55],
	"sc": [2, 5, 10, 12, 15],
	"sd": [25, 30, 35, 40, 45],
	"tbc": [35, 40, 45, 50, 55],
	"tf": [25, 30, 35, 40, 45],
	"tm": [5, 10, 15, 20, 25],
	"tw": [10, 15, 20, 25, 30],
	"ym": [10, 15, 20, 25, 30],
}
# BattleBase.suitPoints / toonPoints. X is across the line, Y is toward the cogs.
const _SUIT_POINTS: Array = [
	[Vector2(0.0, 5.0)],
	[Vector2(2.0, 5.3), Vector2(-2.0, 5.3)],
	[Vector2(4.0, 5.2), Vector2(0.0, 6.0), Vector2(-4.0, 5.2)],
	[Vector2(6.0, 4.4), Vector2(2.0, 6.3), Vector2(-2.0, 6.3), Vector2(-6.0, 4.4)],
]
const _TOON_POINTS: Array = [
	[Vector2(0.0, -6.0)],
	[Vector2(1.5, -6.5), Vector2(-1.5, -6.5)],
	[Vector2(3.0, -6.75), Vector2(0.0, -7.0), Vector2(-3.0, -6.75)],
	[Vector2(4.5, -7.0), Vector2(1.5, -7.5), Vector2(-1.5, -7.5), Vector2(-4.5, -7.0)],
]
## BattleBase.suitPoints / toonPoints headings. Panda +H turns left, same as a toon heading.
const _SUIT_HEAD: Array = [
	[179.0],
	[170.0, 180.0],
	[170.0, 179.0, 190.0],
	[160.0, 170.0, 190.0, 200.0],
]
const _TOON_HEAD: Array = [
	[0.0],
	[5.0, -5.0],
	[5.0, 0.0, -5.0],
	[10.0, 5.0, -5.0, -10.0],
]

var _fights: Array = []
## Gag experience from the floors already cleared, paid out on the top floor.
var _floor_bank: Dictionary = {}
var _next := 1
var _dirty: Dictionary = {}
var _publish_wait := 0.0
var _taunts: Dictionary = {}
var _attack_tables: Dictionary = {}


func _ready() -> void:
	_load_taunts()
	var text := FileAccess.get_file_as_string("res://assets/cogs/attack_tables.json")
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_attack_tables = parsed


func _load_taunts() -> void:
	var text := FileAccess.get_file_as_string("res://assets/battle/faceoff_taunts.json")
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_taunts = parsed


func _process(delta: float) -> void:
	if not ToonNet.is_authority():
		return
	for fight in _fights:
		_tick(fight as Dictionary, delta)
	var gone: Array = []
	for fight in _fights:
		var row: Dictionary = fight
		if String(row.get("state", "")) == "gone":
			_dirty["%d:%s" % [int(row.get("district", 0)), String(row.get("slug", ""))]] = true
			gone.append(fight)
	for fight in gone:
		_fights.erase(fight)
	_publish_wait -= delta
	if _dirty.is_empty() or _publish_wait > 0.0:
		return
	_publish_wait = 0.4
	for key in _dirty.keys():
		_publish_key(String(key))
	_dirty.clear()


func open_fight(district: int, slug: String, cog_id: int, peer: int, toon_name: String, hp: int, max_hp: int) -> void:
	if not ToonNet.is_authority() or cog_id == 0 or peer < 0:
		return
	var existing := _fight_with(district, slug, peer, cog_id)
	if not existing.is_empty():
		var existing_state := String(existing.get("state", ""))
		if existing_state == "faceoff" or existing_state == "input":
			_add_toon(existing, peer, toon_name, hp, max_hp)
			if existing_state == "faceoff":
				_place(existing)
				_mark(existing)
		return
	var cog := _find_cog(district, slug, cog_id)
	if cog.is_empty() or int(cog.get("phase", -1)) != 1:
		return
	var fight := {
		"id": _next,
		"district": district,
		"slug": slug,
		"state": "faceoff",
		"left": FACEOFF_TAUNT_T,
		"seq": 1,
		"round": 1,
		"toons": [],
		"cogs": [],
		"choices": [],
		"beats": [],
		"origin": [0.0, 0.0, 0.0],
		"yaw": 180.0,
	}
	var cog_pos := _point(cog.get("pos", []))
	var yaw := _opening_yaw(cog_pos)
	var origin := cog_pos
	var suits := _street_suits(slug)
	var placed := false
	if suits != null:
		var spot: Dictionary = suits.battle_spot(cog_pos)
		if not spot.is_empty():
			origin = spot["at"] as Vector3
			placed = true
	if not placed:
		var forward := _battle_forward(yaw)
		origin = cog_pos - forward * 5.0
	else:
		var flat := Vector2(cog_pos.x - origin.x, cog_pos.z - origin.z)
		if flat.length() > 0.75:
			yaw = rad_to_deg(atan2(-flat.x, -flat.y))
	origin.y = cog_pos.y
	fight["origin"] = [origin.x, origin.y, origin.z]
	fight["yaw"] = yaw
	_next += 1
	_fights.append(fight)
	_add_cog(fight, cog)
	for extra in _nearby(district, slug, _point(cog.get("pos", [])), cog_id):
		if (fight["cogs"] as Array).size() >= MAX_COGS:
			break
		if randi_range(0, 1) == 0 and _flat(_point(extra.get("pos", [])), _point(cog.get("pos", []))) > 8.0:
			continue
		_add_cog(fight, extra)
	_add_toon(fight, peer, toon_name, hp, max_hp)
	_place(fight)
	_begin_faceoff(fight)


## A cog-building floor. The cogs are not on the street; the run already picked them.
func open_roster(district: int, slug: String, cogs: Array, reserves: Array, riders: Array, origin: Vector3, yaw: float, building: int, out: Variant = null, final_floor: bool = false, floor_index: int = 0, boss_round: int = 0) -> int:
	if not ToonNet.is_authority() or cogs.is_empty() or riders.is_empty():
		return 0
	var exit_at: Array = [origin.x, origin.y, origin.z]
	if out is Array:
		exit_at = out
	var fight := {
		"id": _next,
		"district": district,
		"slug": slug,
		"building": building,
		"final_floor": final_floor,
		"state": "faceoff",
		"left": FACEOFF_TAUNT_T,
		"seq": 1,
		"round": 1,
		"toons": [],
		"cogs": [],
		"reserves": reserves,
		"joining": [],
		"choices": [],
		"beats": [],
		"origin": [origin.x, origin.y, origin.z],
		"out": exit_at,
		"yaw": yaw,
		"floor": floor_index,
	}
	if boss_round > 0:
		# ToontownBattleGlobals.getBossBattleCreditMultiplier.
		fight["boss_round"] = boss_round
	_next += 1
	_fights.append(fight)
	if building != 0 and floor_index <= 0:
		_floor_bank.erase(building)
	for cog in cogs:
		if cog is Dictionary:
			_add_cog(fight, cog)
	for rider in riders:
		if not (rider is Dictionary):
			continue
		var toon: Dictionary = rider
		_add_toon(fight, int(toon.get("id", -1)), String(toon.get("name", "Toon")), int(toon.get("hp", 1)), int(toon.get("max_hp", 1)))
	_place(fight)
	_begin_faceoff(fight)
	return int(fight.get("id", 0))


## A factory battle cell. The cogs are already chosen; they are not street suits.
func open_group(district: int, slug: String, cogs: Array, peer: int, toon_name: String, hp: int, max_hp: int, origin: Vector3, yaw: float, mint_id: int = 0) -> void:
	if not ToonNet.is_authority() or cogs.is_empty() or peer < 0:
		return
	var lead := 0
	if cogs[0] is Dictionary:
		lead = int((cogs[0] as Dictionary).get("id", 0))
	var existing := _fight_with(district, slug, peer, lead)
	if not existing.is_empty():
		var existing_state := String(existing.get("state", ""))
		if existing_state == "faceoff" or existing_state == "input":
			_add_toon(existing, peer, toon_name, hp, max_hp)
			if existing_state == "faceoff":
				_place(existing)
				_mark(existing)
		return
	var fight := {
		"id": _next,
		"district": district,
		"slug": slug,
		"state": "faceoff",
		"left": FACEOFF_TAUNT_T,
		"seq": 1,
		"round": 1,
		"toons": [],
		"cogs": [],
		"choices": [],
		"beats": [],
		"origin": [origin.x, origin.y, origin.z],
		"yaw": yaw,
	}
	if mint_id != 0:
		fight["mint"] = mint_id
	_next += 1
	_fights.append(fight)
	for cog in cogs:
		if cog is Dictionary:
			_add_cog(fight, cog)
	_add_toon(fight, peer, toon_name, hp, max_hp)
	_place(fight)
	_begin_faceoff(fight)


func state_of(fight_id: int) -> String:
	var fight := _by_id(fight_id)
	if fight.is_empty():
		return "gone"
	return String(fight.get("state", "gone"))


## SetHP. The round keeps its own laff, and that copy is what the meter shows.
func set_laff(peer: int, hp: int, max_hp: int) -> void:
	if not ToonNet.is_authority() or peer < 0:
		return
	var maximum := maxi(max_hp, 1)
	var current := clampi(hp, 0, maximum)
	for item in _fights:
		var fight: Dictionary = item
		if String(fight.get("state", "")) == "gone":
			continue
		var toon := _toon(fight, peer)
		if toon.is_empty():
			continue
		toon["hp"] = current
		toon["max_hp"] = maximum
		toon["was"] = current
		_persist_one(toon)
		_mark(fight)


func toon_hp(fight_id: int, peer: int) -> int:
	var fight := _by_id(fight_id)
	for item in fight.get("toons", []):
		if item is Dictionary and int((item as Dictionary).get("id", 0)) == peer:
			return int((item as Dictionary).get("hp", 0))
	return -1


func choose(fight_id: int, peer: int, track: int, level: int, target: int, exp: int) -> void:
	if not ToonNet.is_authority():
		return
	var fight := _by_id(fight_id)
	if fight.is_empty() or String(fight.get("state", "")) != "input":
		return
	if _choice_for(fight, peer) >= 0:
		return
	var toon := _toon(fight, peer)
	if toon.is_empty() or int(toon.get("hp", 0)) <= 0:
		return
	var known := ToonNet.stored_exp(peer, track)
	if known >= 0:
		exp = known
	var pick := {
		"id": peer,
		"track": track,
		"level": level,
		"target": target,
		"exp": clampi(exp, 0, 10500),
	}
	if track == -4 or track == -5 or track == -6:
		if track == -5:
			pick["level"] = -1
		elif level < 0 or level > 90:
			pick["track"] = -1
			pick["level"] = -1
	elif track < -2 or track > 6 or level < -1 or level > 6 or (track == -2 and int(fight.get("building", 0)) != 0):
		pick["track"] = -1
		pick["level"] = -1
	(fight["choices"] as Array).append(pick)
	_mark(fight)


func _tick(fight: Dictionary, delta: float) -> void:
	var state := String(fight.get("state", ""))
	if state == "gone" or state == "":
		return
	fight["left"] = maxf(float(fight.get("left", 0.0)) - delta, 0.0)
	if state == "faceoff" or state == "input":
		fight["pulse"] = float(fight.get("pulse", 0.0)) + delta
		if float(fight["pulse"]) >= 0.5:
			fight["pulse"] = 0.0
			_mark(fight)
	if state == "faceoff":
		_drop_missing(fight)
		if float(fight["left"]) <= 0.0:
			_begin_input(fight)
		return
	if state == "input":
		_drop_missing(fight)
		if (fight["toons"] as Array).is_empty():
			fight["state"] = "gone"
			_mark(fight)
			return
		if float(fight["left"]) <= 0.0 or _all_chosen(fight):
			_resolve(fight)
		return
	if state == "movie" and float(fight["left"]) <= 0.0:
		_finish_movie(fight)
		return
	if state == "reserves" and float(fight["left"]) <= 0.0:
		fight["joining"] = []
		_begin_input(fight)
		return
	if state == "reward":
		_drop_missing(fight)
		if float(fight["left"]) <= 0.0 or _reward_complete(fight):
			fight["state"] = "gone"
			_mark(fight)


func reward_done(fight_id: int, peer: int) -> void:
	if not ToonNet.is_authority():
		return
	var fight := _by_id(fight_id)
	if fight.is_empty() or String(fight.get("state", "")) != "reward":
		return
	var done: Array = fight.get("finished", [])
	if not done.has(peer):
		done.append(peer)
	fight["finished"] = done
	if _reward_complete(fight):
		fight["state"] = "gone"
	_mark(fight)


func _reward_complete(fight: Dictionary) -> bool:
	var done: Array = fight.get("finished", [])
	for item in fight.get("toons", []):
		if not (item is Dictionary):
			continue
		var toon: Dictionary = item
		if int(toon.get("hp", 0)) <= 0:
			continue
		if not done.has(int(toon.get("id", 0))):
			return false
	return true


func _reward_rows(fight: Dictionary, roster: Array) -> Array:
	var rows: Array = []
	var seen: Dictionary = {}
	for item in roster:
		if not (item is Dictionary):
			continue
		var toon: Dictionary = item
		var peer := int(toon.get("id", 0))
		seen[peer] = true
		rows.append(_reward_row(fight, peer, String(toon.get("name", "Toon")), toon))
	var book: Dictionary = fight.get("skill", {})
	for key in book.keys():
		var peer := int(key)
		if seen.has(peer):
			continue
		rows.append(_reward_row(fight, peer, "Toon", {}))
	return rows


func _reward_row(fight: Dictionary, peer: int, toon_name: String, toon: Dictionary) -> Dictionary:
	var earned := _earned_for(fight, peer)
	var before: Array = []
	var total: Array = []
	for track in ToonLoadout.TRACK_COUNT:
		var known := ToonNet.stored_exp(peer, track)
		var start := 0 if known < 0 else known
		var gained := int(earned[track]) if track < earned.size() else 0
		var summed := mini(start + gained, 10500)
		before.append(start)
		total.append(summed)
		earned[track] = summed - start
	var av := int(toon.get("av", 0))
	if av <= 0:
		av = ToonNet.avatar_of(peer)
	ToonNet.persist_exp(av, total)
	return {"id": peer, "name": toon_name, "before": before, "earned": earned}


func _skill_copy(fight: Dictionary, peer: int) -> Array:
	var earned := _earned_for(fight, peer)
	var copy: Array = []
	for amount in earned:
		copy.append(int(amount))
	return copy


## movieDone grants the sad toon's experience before the battle continues.
## The book entry is cleared so the victory card does not add it a second time.
func _cash_out(fight: Dictionary, toon: Dictionary) -> void:
	var peer := int(toon.get("id", 0))
	if int(fight.get("building", 0)) != 0:
		_pour_toon(fight, peer)
	_reward_row(fight, peer, String(toon.get("name", "Toon")), toon)
	var book: Dictionary = fight.get("skill", {})
	book.erase(str(peer))
	fight["skill"] = book


func _earned_for(fight: Dictionary, peer: int) -> Array:
	var book: Dictionary = fight.get("skill", {})
	var row: Variant = book.get(str(peer), [0, 0, 0, 0, 0, 0, 0])
	var earned: Array = []
	var source: Array = row if row is Array else []
	for track in ToonLoadout.TRACK_COUNT:
		earned.append(int(round(float(source[track]))) if track < source.size() else 0)
	return earned


func _credit_mult(fight: Dictionary) -> float:
	var boss_round := int(fight.get("boss_round", 0))
	if boss_round > 0:
		return float(1 + boss_round)
	var building := int(fight.get("building", 0)) != 0
	var mult := _HOLIDAYS.gag_credit(int(fight.get("district", 0)), building, int(fight.get("floor", 0)))
	# ToontownBattleGlobals.getFactoryCreditMultiplier. Factory gag credit is doubled.
	if String(fight.get("slug", "")) == "sellbot_factory":
		mult *= 2.0
	# ToontownBattleGlobals.getMintCreditMultiplier.
	var minted := int(fight.get("mint", 0))
	if minted == 12600:
		mult *= 2.5
	elif minted == 12700:
		mult *= 3.0
	elif minted == 12500:
		mult *= 2.0
	return mult


func _grant(fight: Dictionary, peer: int, track: int, level: int, locked := false) -> void:
	if peer == 0 or track < 0 or track >= ToonLoadout.TRACK_COUNT or level < 0:
		return
	# A trap's credit was decided when it was placed. Later rounds keep that.
	if not locked and not ToonLoadout.earns_experience(level, int(fight.get("credit_level", 0))):
		return
	var book: Dictionary = fight.get("skill", {})
	var key := str(peer)
	var row: Array = book.get(key, [0, 0, 0, 0, 0, 0, 0])
	while row.size() < ToonLoadout.TRACK_COUNT:
		row.append(0)
	var gained := float(level + 1) * _credit_mult(fight)
	row[track] = minf(float(row[track]) + gained, 10500.0)
	book[key] = row
	fight["skill"] = book


func _begin_faceoff(fight: Dictionary) -> void:
	if (fight["toons"] as Array).is_empty() or (fight["cogs"] as Array).is_empty():
		fight["state"] = "gone"
		_mark(fight)
		return
	var walk := _face_walk(fight)
	var lead: Dictionary = (fight["cogs"] as Array)[0]
	fight["state"] = "faceoff"
	fight["taunt_for"] = FACEOFF_TAUNT_T
	fight["walk"] = walk
	fight["left"] = FACEOFF_TAUNT_T + walk
	fight["taunt"] = _taunt_line(lead)
	fight["taunt_cog"] = int(lead.get("id", 0))
	fight["cam_side"] = 5.0 if randi() % 2 == 0 else -5.0
	fight["cam_high"] = randi() % 3
	fight["seq"] = int(fight.get("seq", 0)) + 1
	_mark(fight)


func _face_walk(fight: Dictionary) -> float:
	var longest := 0.1
	for item in fight.get("cogs", []):
		if not (item is Dictionary):
			continue
		var cog: Dictionary = item
		var dist := _flat(_point(cog.get("from", [])), _point(cog.get("slot", [])))
		longest = maxf(longest, dist / SUIT_SPEED)
	return longest


func _taunt_line(cog: Dictionary) -> String:
	var code := String(cog.get("code", ""))
	var lines: Array = _taunts.get(code, _taunts.get("_", ["Boo!"]))
	if lines.is_empty():
		return "Boo!"
	return String(lines[absi(int(cog.get("id", 0))) % lines.size()])


func _begin_input(fight: Dictionary) -> void:
	if (fight["toons"] as Array).is_empty() or (fight["cogs"] as Array).is_empty():
		fight["state"] = "gone"
		_mark(fight)
		return
	fight["state"] = "input"
	fight["left"] = INPUT_TIME
	fight["choices"] = []
	fight["beats"] = []
	fight["seq"] = int(fight.get("seq", 0)) + 1
	_mark(fight)


func _resolve(fight: Dictionary) -> void:
	var roster: Array = fight["toons"]
	for member_index in roster.size():
		var member: Dictionary = roster[member_index]
		if _choice_for(fight, int(member.get("id", -1))) < 0:
			(fight["choices"] as Array).append({
				"id": int(member.get("id", 0)),
				"track": -1,
				"level": -1,
				"target": -1,
				"exp": 0,
			})
		member["was"] = int(member.get("hp", 0))
	var suits: Array = fight["cogs"]
	for body_index in suits.size():
		var body: Dictionary = suits[body_index]
		body["was"] = int(body.get("hp", 0))
	# creditLevel is fixed before any gag resolves, so a cog defeated earlier
	# in this round still counts toward the cap.
	fight["credit_level"] = ToonLoadout.credit_level(suits)
	var beats: Array = []
	var runners: Array = []
	var picks: Array = fight["choices"]
	for pick_index in picks.size():
		var choice: Dictionary = picks[pick_index]
		if int(choice.get("track", -1)) != -2:
			continue
		var runner := _toon(fight, int(choice.get("id", 0)))
		if runner.is_empty():
			continue
		beats.append({"text": "%s ran away." % String(runner.get("name", "A toon")), "kind": "run", "id": int(runner.get("id", 0))})
		runners.append(runner)
	for leaving in runners:
		roster.erase(leaving)
	_place(fight)
	fight["hits"] = []
	var order: Array[int] = [0, 1, 2, 3, 4, 5, 6]
	for attack_index in picks.size():
		var special: Dictionary = picks[attack_index]
		var special_track := int(special.get("track", -1))
		if special_track == -4 or special_track == -5:
			_apply_reward(fight, special, beats)
		elif special_track == -6:
			_apply_pet(fight, special, beats)
	for track in order:
		for attack_index in picks.size():
			var attack: Dictionary = picks[attack_index]
			if int(attack.get("track", -1)) != track:
				continue
			var attacker := _toon(fight, int(attack.get("id", 0)))
			if attacker.is_empty() or int(attacker.get("hp", 0)) <= 0:
				continue
			_apply_gag(fight, attacker, attack, beats)
	for fighter_index in suits.size():
		var fighter: Dictionary = suits[fighter_index]
		if int(fighter.get("hp", 0)) <= 0:
			continue
		# A cog that is still lured skips its attack. Sound, throw, and squirt
		# already cleared the lure when they connected, so those cogs swing.
		if bool(fighter.get("lured", false)):
			continue
		_suit_attack(fight, fighter, beats)
	_age_lures(fight)
	fight.erase("hits")
	fight["beats"] = beats
	fight["state"] = "movie"
	fight["left"] = maxf(_time_beats(beats), 1.2)
	_persist_gags(fight)
	_persist_laff(fight)
	fight["seq"] = int(fight.get("seq", 0)) + 1
	_mark(fight)


func _apply_pet(fight: Dictionary, choice: Dictionary, beats: Array) -> void:
	var toon := _toon(fight, int(choice.get("id", 0)))
	if toon.is_empty() or int(toon.get("hp", 0)) <= 0:
		return
	var who := String(toon.get("name", "A toon"))
	var trick := int(choice.get("level", 0))
	var names: PackedStringArray = ["Jump", "Beg", "Play Dead", "Rollover", "Backflip", "Dance", "Speak"]
	var heal := preload("res://scenes/pets/doodle_kennel.gd").battle_trick(trick)
	if heal <= 0:
		beats.append(_beat("%s's Doodle balked." % who, -6, trick, toon, {}, false, 0))
		return
	var before := int(toon.get("hp", 0))
	toon["hp"] = mini(before + heal, int(toon.get("max_hp", before)))
	var word := names[clampi(trick, 0, names.size() - 1)]
	var line := _beat("%s's Doodle did %s and healed %d laff." % [who, word, int(toon.get("hp", 0)) - before], -6, trick, toon, {}, true, heal)
	line["toon_hp"] = int(toon.get("hp", 0))
	line["toon_id"] = int(toon.get("id", 0))
	beats.append(line)


func _apply_reward(fight: Dictionary, choice: Dictionary, beats: Array) -> void:
	var toon := _toon(fight, int(choice.get("id", 0)))
	if toon.is_empty() or int(toon.get("hp", 0)) <= 0:
		return
	var who := String(toon.get("name", "A toon"))
	if int(choice.get("track", -1)) == -5:
		var target := int(choice.get("target", -1))
		var suits: Array = fight.get("cogs", [])
		for item in suits:
			if not (item is Dictionary):
				continue
			var suit: Dictionary = item
			if int(suit.get("hp", 0)) <= 0:
				continue
			if target >= 0 and int(suit.get("id", -1)) != target:
				continue
			suit["hp"] = 0
			beats.append(_beat("%s fired a pink slip. The %s is defeated." % [who, String(suit.get("name", "cog"))], -1, -1, toon, suit, true, int(suit.get("max_hp", 1))))
			return
		return
	var encoded := int(choice.get("level", 0))
	var gag_track := int(encoded / 10)
	var gag_level := encoded % 10
	if gag_track == 7:
		beats.append(_beat("%s called an SOS Toon to restock gags." % who, -1, -1, toon, {}, true, 0))
		return
	if gag_track == 8:
		fight["sos_hit"] = true
		beats.append(_beat("%s called an SOS Toon. Your gags will hit." % who, -1, -1, toon, {}, true, 0))
		return
	if gag_track == 9:
		fight["sos_miss"] = true
		beats.append(_beat("%s called an SOS Toon. The cogs will miss." % who, -1, -1, toon, {}, true, 0))
		return
	var names := ToonLoadout.new()
	var gag := names.gag_name(gag_track, gag_level)
	var amount := ToonLoadout.gag_damage(gag_track, gag_level, 10500)
	if gag_track == ToonLoadout.TOON_UP:
		for item in fight.get("toons", []):
			if not (item is Dictionary):
				continue
			var patient: Dictionary = item
			if int(patient.get("hp", 0)) <= 0:
				continue
			var before := int(patient.get("hp", 0))
			patient["hp"] = mini(before + amount, int(patient.get("max_hp", before)))
			var healed := _beat("%s's SOS used %s and healed %d laff." % [who, gag, int(patient.get("hp", 0)) - before], 0, gag_level, toon, {}, true, amount)
			healed["toon_hp"] = int(patient.get("hp", 0))
			healed["toon_id"] = int(patient.get("id", 0))
			beats.append(healed)
		return
	var group := ToonLoadout.affects_group(gag_track, gag_level)
	var target_id := int(choice.get("target", -1))
	for item in fight.get("cogs", []):
		if not (item is Dictionary):
			continue
		var suit: Dictionary = item
		if int(suit.get("hp", 0)) <= 0:
			continue
		if not group and target_id >= 0 and int(suit.get("id", -1)) != target_id:
			continue
		_hurt_cog(suit, amount)
		var cog_name := String(suit.get("name", "cog"))
		var line := "%s's SOS used %s on the %s for %d damage." % [who, gag, cog_name, amount]
		if int(suit.get("hp", 0)) <= 0:
			line += " The %s is defeated." % cog_name
		beats.append(_beat(line, gag_track, gag_level, toon, suit, true, amount))
		if not group:
			return


func _kills_instantly(toon: Dictionary) -> bool:
	var peer := int(toon.get("id", -1))
	if bool(ToonNet.latest("toon:%d" % peer).get("instant_kill", false)):
		return true
	return peer == ToonNet.peer_id() and MagicWords.instant_kill()


func _apply_gag(fight: Dictionary, toon: Dictionary, choice: Dictionary, beats: Array) -> void:
	var track := int(choice.get("track", -1))
	var level := int(choice.get("level", 0))
	var names := ToonLoadout.new()
	var gag := names.gag_name(track, level)
	var who := String(toon.get("name", "A toon"))
	if track == ToonLoadout.TOON_UP:
		_heal(fight, toon, choice, gag, who, beats)
		return
	var targets := _cog_targets(fight, choice)
	var living: Array = []
	for cog in targets:
		var body: Dictionary = cog
		if int(body.get("hp", 0)) > 0:
			living.append(body)
	if living.is_empty():
		return
	var damage := ToonLoadout.gag_damage(track, level, int(choice.get("exp", 0)))
	if _kills_instantly(toon):
		damage = 9999
	var group := ToonLoadout.affects_group(track, level)
	var target_id := int(choice.get("target", -1))
	# Trap does not roll. Every other gag rolls once for the whole attack.
	var hit := true
	var acc := 0
	if track != 1:
		var rolled: Dictionary = _toon_hit(fight, choice, living)
		hit = bool(rolled["hit"])
		acc = int(rolled["acc"])
	_note_hit(fight, track, level, target_id, group, hit)
	var landed := false
	for cog in living:
		var suit: Dictionary = cog
		var cog_name := String(suit.get("name", "cog"))
		if track == 1:
			suit["trap"] = {"damage": damage, "gag": gag, "by": who, "owner": int(toon.get("id", 0)), "level": level, "credit": ToonLoadout.earns_experience(level, int(fight.get("credit_level", 0)))}
			beats.append(_beat("%s set a %s on the %s." % [who, gag, cog_name], track, level, toon, suit, true, 0))
			landed = true
			continue
		if track == 2:
			if _lure(fight, toon, suit, gag, hit, acc, beats, track, level):
				landed = true
			continue
		if not hit:
			beats.append(_beat("%s's %s missed the %s." % [who, gag, cog_name], track, level, toon, suit, false, 0))
			continue
		# Drop on a lured cog does nothing. Sound, throw, and squirt wake it up.
		var dealt := damage
		if track == 6 and bool(suit.get("lured", false)):
			beats.append(_beat("%s's %s missed the %s." % [who, gag, cog_name], track, level, toon, suit, false, 0))
			continue
		_hurt_cog(suit, dealt)
		if track == 3 or track == ToonLoadout.THROW or track == ToonLoadout.SQUIRT:
			_clear_lure(suit)
		var revived := _revive_suit(suit)
		var line := "%s used a %s on the %s for %d damage." % [who, gag, cog_name, dealt]
		if not revived and int(suit.get("hp", 0)) <= 0:
			line += " The %s is defeated." % cog_name
		var beat := _beat(line, track, level, toon, suit, true, dealt)
		if revived:
			beat["cog_hp"] = 0
			beat["revived"] = true
		beats.append(beat)
		landed = true
	if landed and track != 1:
		_grant(fight, int(toon.get("id", 0)), track, level)


func _lure(fight: Dictionary, toon: Dictionary, suit: Dictionary, gag: String, hit: bool, acc: int, beats: Array, track: int, level: int) -> bool:
	var who := String(toon.get("name", "A toon"))
	var cog_name := String(suit.get("name", "cog"))
	if not hit:
		beats.append(_beat("%s's %s missed the %s." % [who, gag, cog_name], track, level, toon, suit, false, 0))
		return false
	var already := bool(suit.get("lured", false))
	_apply_lure_time(suit, level, acc)
	beats.append(_beat("%s's %s lured the %s." % [who, gag, cog_name], track, level, toon, suit, true, 0))
	if already:
		return true
	var trap: Variant = suit.get("trap", {})
	if not (trap is Dictionary) or (trap as Dictionary).is_empty():
		return true
	var laid: Dictionary = trap
	var damage := int(laid.get("damage", 0))
	suit["trap"] = {}
	_hurt_cog(suit, damage)
	var revived := _revive_suit(suit)
	var line := "The %s hit the %s for %d damage." % [String(laid.get("gag", "trap")), cog_name, damage]
	if not revived and int(suit.get("hp", 0)) <= 0:
		line += " The %s is defeated." % cog_name
	var beat := _beat(line, 1, 0, toon, suit, true, damage)
	if revived:
		beat["cog_hp"] = 0
		beat["revived"] = true
	beats.append(beat)
	if bool(laid.get("credit", false)):
		_grant(fight, int(laid.get("owner", 0)), 1, int(laid.get("level", 0)), true)
	return true


func _heal(fight: Dictionary, toon: Dictionary, choice: Dictionary, gag: String, who: String, beats: Array) -> void:
	var track := int(choice.get("track", 0))
	var level := int(choice.get("level", 0))
	var amount := ToonLoadout.gag_damage(track, level, int(choice.get("exp", 0)))
	var targets: Array = []
	if ToonLoadout.affects_group(track, level):
		targets = fight["toons"]
	else:
		var picked := _toon(fight, int(choice.get("target", -1)))
		if picked.is_empty():
			picked = toon
		targets = [picked]
	var patients: Array = []
	for item in targets:
		var body: Dictionary = item
		if int(body.get("hp", 0)) > 0:
			patients.append(body)
	if patients.is_empty():
		return
	var rolled: Dictionary = _toon_hit(fight, choice, [])
	var hit: bool = bool(rolled["hit"])
	_note_hit(fight, track, level, int(choice.get("target", -1)), ToonLoadout.affects_group(track, level), hit)
	var landed := false
	for item in patients:
		var patient: Dictionary = item
		if not hit:
			var missed := _beat("%s's %s missed." % [who, gag], track, level, toon, {}, false, 0, "")
			missed["toon_id"] = int(patient.get("id", 0))
			beats.append(missed)
			continue
		var before := int(patient.get("hp", 0))
		patient["hp"] = mini(before + amount, int(patient.get("max_hp", before)))
		var gained := int(patient.get("hp", 0)) - before
		var healed := _beat("%s used a %s and healed %d laff." % [who, gag, gained], track, level, toon, {}, true, gained, "")
		healed["toon_hp"] = int(patient.get("hp", 0))
		healed["toon_id"] = int(patient.get("id", 0))
		beats.append(healed)
		landed = true
	if landed:
		_grant(fight, int(toon.get("id", 0)), track, level)


## BattleCalculatorAI.__calcToonAtkHit. One roll covers every target of the gag.
## The returned acc is the uncapped prop + experience + defense, which lure
## uses as its wake-up chance.
func _toon_hit(fight: Dictionary, choice: Dictionary, living: Array) -> Dictionary:
	if bool(fight.get("sos_hit", false)):
		return {"hit": true, "acc": 100}
	var track := int(choice.get("track", -1))
	var level := int(choice.get("level", 0))
	var target := int(choice.get("target", -1))
	var group := ToonLoadout.affects_group(track, level)
	var defense := 0
	var num_lured := 0
	for item in living:
		var suit: Dictionary = item
		defense = mini(defense, -_suit_def(suit))
		if bool(suit.get("lured", false)):
			num_lured += 1
	var prop := ToonLoadout.gag_accuracy(track, level)
	if track == 2 and preload("res://scenes/estate/garden.gd").organic(track, level):
		var organic_lure: Array[int] = [60, 60, 70, 70, 80, 80, 100]
		prop = organic_lure[clampi(level, 0, organic_lure.size() - 1)]
	var attack_acc := prop + _shared_exp(fight, choice, track) + defense
	var noted := _hit_list(fight)
	if not noted.is_empty():
		var prev: Dictionary = noted[noted.size() - 1]
		if int(prev.get("track", -2)) == track and _copies_previous(track, target, group, prev):
			return {"hit": bool(prev.get("hit", false)), "acc": attack_acc}
	var count := living.size()
	var all_lured := count > 0 and num_lured == count
	if track != 2 and track != ToonLoadout.TOON_UP:
		if track != 6 and all_lured:
			return {"hit": true, "acc": attack_acc}
		if track == 6 and all_lured:
			return {"hit": false, "acc": attack_acc}
	var acc := attack_acc + _prev_bonus(noted, track, target, group)
	if track != 2 and track != ToonLoadout.TOON_UP and track != 6 and count > 0 and not all_lured:
		acc += int(100.0 * float(num_lured) / float(count))
	if acc > _MAX_TOON_ACC:
		acc = _MAX_TOON_ACC
	return {"hit": randi_range(0, 99) < acc, "acc": attack_acc}


func _copies_previous(track: int, target: int, group: bool, prev: Dictionary) -> bool:
	if int(prev.get("target", -2)) == target:
		return true
	# A group lure copies the lure just before it. A single lure copies when
	# that cog was already lured by the previous group lure.
	if track != 2:
		return false
	if group:
		return true
	return bool(prev.get("group", false)) and bool(prev.get("hit", false))


func _shared_exp(fight: Dictionary, choice: Dictionary, track: int) -> int:
	var best := _exp_bonus(int(choice.get("exp", 0)), track)
	var target := int(choice.get("target", -1))
	var mine := int(choice.get("id", 0))
	for item in fight.get("choices", []):
		if not (item is Dictionary):
			continue
		var other: Dictionary = item
		if int(other.get("id", 0)) == mine or int(other.get("track", -1)) != track:
			continue
		if int(other.get("target", -2)) != target:
			continue
		best = maxi(best, _exp_bonus(int(other.get("exp", 0)), track))
	return best


func _exp_bonus(exp: int, track: int) -> int:
	var level := 0
	for index in 7:
		if exp >= ToonLoadout.skill_at(track, index):
			level = index
	var bonus := _EXP_BONUS[clampi(level, 0, _EXP_BONUS.size() - 1)]
	if track == ToonLoadout.TOON_UP:
		bonus = int(bonus / 2)
	return bonus


func _suit_def(suit: Dictionary) -> int:
	var row: Variant = _SUIT_DEF.get(String(suit.get("code", "")), [])
	if not (row is Array) or (row as Array).is_empty():
		return 0
	var values: Array = row
	var index := _rel_level(suit)
	return int(values[clampi(index, 0, values.size() - 1)])


func _prev_bonus(noted: Array, track: int, target: int, group: bool) -> int:
	var count := 0
	for item in noted:
		if not (item is Dictionary):
			continue
		var prev: Dictionary = item
		if not bool(prev.get("hit", false)) or int(prev.get("track", -1)) == track:
			continue
		var prev_group := bool(prev.get("group", false))
		if group or prev_group or int(prev.get("target", -2)) == target:
			count += 1
	return _PREV_BONUS[mini(count, _PREV_BONUS.size() - 1)]


func _hit_list(fight: Dictionary) -> Array:
	var raw: Variant = fight.get("hits", [])
	if raw is Array:
		return raw
	return []


func _note_hit(fight: Dictionary, track: int, level: int, target: int, group: bool, hit: bool) -> void:
	var noted := _hit_list(fight)
	noted.append({
		"track": track,
		"level": level,
		"target": target,
		"group": group,
		"hit": hit,
	})
	fight["hits"] = noted


func _apply_lure_time(suit: Dictionary, level: int, acc: int) -> void:
	var rounds := _LURE_ROUNDS[clampi(level, 0, _LURE_ROUNDS.size() - 1)]
	var wake := 100 - acc * 2
	if bool(suit.get("lured", false)):
		suit["lure_max"] = int(suit.get("lure_max", rounds)) + rounds
		suit["lure_wake"] = mini(int(suit.get("lure_wake", wake)), wake)
		return
	suit["lured"] = true
	suit["lure_round"] = -1
	suit["lure_max"] = rounds
	suit["lure_wake"] = wake


func _clear_lure(suit: Dictionary) -> void:
	suit["lured"] = false
	suit.erase("lure_round")
	suit.erase("lure_max")
	suit.erase("lure_wake")


## The round the lure lands does not wake the cog. Later rounds can, and the
## chance is 100 minus twice the lure's accuracy.
func _age_lures(fight: Dictionary) -> void:
	for item in fight.get("cogs", []):
		if not (item is Dictionary):
			continue
		var suit: Dictionary = item
		if int(suit.get("hp", 0)) <= 0 or not bool(suit.get("lured", false)):
			continue
		var round := int(suit.get("lure_round", -1)) + 1
		suit["lure_round"] = round
		if round >= int(suit.get("lure_max", 1)):
			_clear_lure(suit)
		elif round > 0 and randi_range(0, 99) < int(suit.get("lure_wake", 0)):
			_clear_lure(suit)


## SuitBattleGlobals.getSuitAttack. The printed level is getActualLevel, so the
## table index is that level minus the cog's base level, minus one.
func _attack_row(code: String) -> Dictionary:
	CogRules.note_shared(ToonNet.latest("dev:rules"))
	var edited := CogRules.attack_for(code)
	if not edited.is_empty():
		return edited
	var shipped: Variant = _attack_tables.get(code, {})
	if shipped is Dictionary:
		return shipped
	return {}


func _rel_level(suit: Dictionary) -> int:
	var table := _attack_row(String(suit.get("code", "")))
	var base := int(table.get("base", 0))
	return clampi(int(suit.get("level", 1)) - base - 1, 0, 4)


func _table_at(row: Array, index: int) -> int:
	if row.is_empty():
		return 0
	return int(row[clampi(index, 0, row.size() - 1)])


## pickSuitAttack rolls 0-99 against the frequency column for this level.
func _pick_attack(suit: Dictionary) -> Dictionary:
	var table := _attack_row(String(suit.get("code", "")))
	var attacks: Array = table.get("attacks", [])
	if attacks.is_empty():
		return {}
	var rel := _rel_level(suit)
	var roll := randi_range(0, 99)
	var count := 0
	var chosen: Dictionary = attacks[attacks.size() - 1]
	for item in attacks:
		if not (item is Dictionary):
			continue
		var attack: Dictionary = item
		count += _table_at(attack.get("freq", []), rel)
		if roll < count:
			chosen = attack
			break
	return chosen


func _suit_attack(fight: Dictionary, suit: Dictionary, beats: Array) -> void:
	var living: Array = []
	for item in fight["toons"]:
		var candidate: Dictionary = item
		if int(candidate.get("hp", 0)) > 0:
			living.append(candidate)
	if living.is_empty():
		return
	var attack := _pick_attack(suit)
	var rel := _rel_level(suit)
	var damage := _table_at(attack.get("hp", []), rel)
	var accuracy := _table_at(attack.get("acc", []), rel)
	if attack.is_empty():
		damage = (int(suit.get("level", 1)) + 1) * 2
		accuracy = 75
	var cog_name := String(suit.get("name", "cog"))
	var title := String(attack.get("name", "Glower Power!"))
	var anim := String(attack.get("anim", "glower"))
	var targets: Array = living
	if not bool(attack.get("group", false)):
		targets = [living[randi() % living.size()]]
	var victims: Array = []
	var any_hit := false
	var any_died := false
	for item in targets:
		var victim: Dictionary = item
		var landed := randi_range(0, 99) < accuracy
		if bool(fight.get("sos_miss", false)):
			landed = false
		var row := {
			"id": int(victim.get("id", 0)),
			"name": String(victim.get("name", "a toon")),
			"hit": landed,
			"damage": 0,
			"hp": int(victim.get("hp", 0)),
			"died": false,
		}
		if landed:
			any_hit = true
			victim["hp"] = maxi(int(victim.get("hp", 0)) - damage, 0)
			row["damage"] = damage
			row["hp"] = int(victim.get("hp", 0))
			row["died"] = int(victim.get("hp", 0)) <= 0
			if bool(row["died"]):
				any_died = true
				row["skill"] = _skill_copy(fight, int(victim.get("id", 0)))
				_cash_out(fight, victim)
				ToonNet.persist_zero_gags(_avatar(victim))
		victims.append(row)
	var first: Dictionary = victims[0]
	var line := "The %s used %s" % [cog_name, title]
	if victims.size() == 1 and bool(first.get("hit", false)):
		line = "The %s used %s on %s for %d damage." % [cog_name, title, String(first.get("name", "a toon")), int(first.get("damage", 0))]
		if bool(first.get("died", false)):
			line += " %s is sad." % String(first.get("name", "A toon"))
	elif victims.size() == 1:
		line = "%s dodged the %s." % [String(first.get("name", "A toon")), cog_name]
	beats.append({
		"text": line,
		"kind": "cog",
		"hit": any_hit,
		"damage": damage,
		"cog": int(suit.get("id", 0)),
		"toon": int(first.get("id", 0)),
		"anim": anim,
		"attack": title,
		"died": any_died,
		"victims": victims,
	})


func _finish_movie(fight: Dictionary) -> void:
	var cogs: Array = fight["cogs"]
	var total_hp := 0
	var total_max := 0
	for item in cogs:
		if not (item is Dictionary):
			continue
		var cog: Dictionary = item
		total_max += int(cog.get("max_hp", cog.get("hp", 0)))
		if int(cog.get("hp", 0)) > 0:
			total_hp += int(cog.get("hp", 0))
	fight["hurt"] = 0.0 if total_max <= 0 else 100.0 - float(total_hp) / float(total_max) * 100.0
	var kept: Array = []
	var traffic := get_parent()
	var factory := String(fight.get("slug", "")) == "sellbot_factory"
	var mint := String(fight.get("slug", "")) == "cashbot_mint"
	var boss_down := bool(fight.get("boss_down", false))
	for item in cogs:
		var cog: Dictionary = item
		if int(cog.get("hp", 0)) <= 0:
			if factory:
				_FACTORY.remember(int(cog.get("level", 1)))
				if bool(cog.get("boss", false)):
					boss_down = true
			if mint:
				_MINT.remember(int(cog.get("level", 1)))
				if bool(cog.get("boss", false)):
					boss_down = true
			if int(fight.get("building", 0)) == 0:
				_HOLIDAYS.note_cog(int(fight.get("district", 0)), String(cog.get("code", "")), bool(cog.get("skeleton", false)))
			if traffic != null and traffic.has_method("dismiss_cog"):
				traffic.call("dismiss_cog", int(fight.get("district", 0)), String(fight.get("slug", "")), int(cog.get("id", 0)))
			continue
		kept.append(cog)
		if traffic != null and traffic.has_method("park_cog"):
			traffic.call("park_cog", int(fight.get("district", 0)), String(fight.get("slug", "")), int(cog.get("id", 0)), cog.get("slot", []))
	fight["cogs"] = kept
	fight["boss_down"] = boss_down
	var toons: Array = []
	for member in fight["toons"]:
		var toon: Dictionary = member
		if int(toon.get("hp", 0)) <= 0:
			toon["hp"] = 0
			ToonNet.persist_zero_gags(_avatar(toon))
		else:
			toons.append(toon)
		_persist_one(toon)
	fight["toons"] = toons
	if factory and boss_down and kept.is_empty() and not toons.is_empty():
		fight["factory_won"] = true
	if mint and boss_down and kept.is_empty() and not toons.is_empty():
		fight["mint_won"] = true
	_place(fight)
	var building := int(fight.get("building", 0))
	if toons.is_empty():
		if building != 0:
			_floor_bank.erase(building)
			_close_fight(fight)
			return
		_open_reward(fight, toons)
		return
	if _join_reserves(fight, kept):
		return
	if kept.is_empty():
		if building != 0 and not bool(fight.get("final_floor", false)):
			_stash_floor(fight)
			_open_floor_clear(fight)
			return
		if building != 0:
			_pour_bank(fight)
		_open_reward(fight, toons)
		return
	fight["round"] = int(fight.get("round", 1)) + 1
	_begin_input(fight)


func _open_reward(fight: Dictionary, toons: Array) -> void:
	fight["floor_clear"] = false
	fight["reward_rows"] = _reward_rows(fight, toons)
	fight["state"] = "reward"
	fight["left"] = REWARD_TIME
	fight["finished"] = []
	fight["beats"] = []
	fight["seq"] = int(fight.get("seq", 0)) + 1
	_mark(fight)


## DistributedBattleBldg.enterReward. The experience card waits for the top floor.
func _open_floor_clear(fight: Dictionary) -> void:
	fight["floor_clear"] = true
	fight["reward_rows"] = []
	fight["state"] = "reward"
	fight["left"] = FLOOR_REWARD_TIME
	fight["finished"] = []
	fight["beats"] = []
	fight["seq"] = int(fight.get("seq", 0)) + 1
	_mark(fight)


func _close_fight(fight: Dictionary) -> void:
	fight["state"] = "gone"
	fight["beats"] = []
	fight["seq"] = int(fight.get("seq", 0)) + 1
	_mark(fight)


func _stash_floor(fight: Dictionary) -> void:
	var block := int(fight.get("building", 0))
	if block == 0:
		return
	var bank: Dictionary = _floor_bank.get(block, {})
	var skill: Dictionary = fight.get("skill", {})
	for key in skill.keys():
		bank[str(key)] = _sum_tracks(bank.get(str(key), []), skill[key])
	_floor_bank[block] = bank


func _pour_bank(fight: Dictionary) -> void:
	var block := int(fight.get("building", 0))
	if block == 0 or not _floor_bank.has(block):
		return
	var bank: Dictionary = _floor_bank[block]
	_floor_bank.erase(block)
	var skill: Dictionary = fight.get("skill", {})
	for key in bank.keys():
		skill[str(key)] = _sum_tracks(skill.get(str(key), []), bank[key])
	fight["skill"] = skill


func _pour_toon(fight: Dictionary, peer: int) -> void:
	var block := int(fight.get("building", 0))
	if block == 0 or not _floor_bank.has(block):
		return
	var bank: Dictionary = _floor_bank[block]
	var key := str(peer)
	if not bank.has(key):
		return
	var skill: Dictionary = fight.get("skill", {})
	skill[key] = _sum_tracks(skill.get(key, []), bank[key])
	fight["skill"] = skill
	bank.erase(key)
	_floor_bank[block] = bank


func _sum_tracks(have: Variant, extra: Variant) -> Array:
	var left: Array = have if have is Array else []
	var right: Array = extra if extra is Array else []
	var sum: Array = []
	for track in ToonLoadout.TRACK_COUNT:
		var a := float(left[track]) if track < left.size() else 0.0
		var b := float(right[track]) if track < right.size() else 0.0
		sum.append(minf(a + b, 10500.0))
	return sum


## DistributedSuitInteriorAI.__handleRoundDone. A reserve joins when the
## floor has lost at least its join chance in cog laff, and the line is under 4.
func _join_reserves(fight: Dictionary, kept: Array) -> bool:
	var reserves: Array = fight.get("reserves", [])
	if reserves.is_empty() or kept.size() >= 4:
		return false
	var hurt := float(fight.get("hurt", 0.0))
	var joining: Array = []
	var stay: Array = []
	for item in reserves:
		if not (item is Dictionary):
			continue
		var cog: Dictionary = item
		if float(cog.get("join", 100)) <= hurt and kept.size() + joining.size() < 4:
			joining.append(cog)
		else:
			stay.append(cog)
	fight["reserves"] = stay
	if joining.is_empty():
		return false
	var ids: Array = []
	for cog in joining:
		_add_cog(fight, cog)
		ids.append(int((cog as Dictionary).get("id", 0)))
	_place(fight)
	fight["joining"] = ids
	fight["state"] = "reserves"
	fight["left"] = 3.0
	fight["beats"] = []
	fight["choices"] = []
	fight["seq"] = int(fight.get("seq", 0)) + 1
	_mark(fight)
	return true


## Lengths match GagMovie. One track overlaps, so the round waits for the
## longest clip plus its start delay, not the sum of every toon.
func _time_beats(beats: Array) -> float:
	var total := 0.0
	var index := 0
	while index < beats.size():
		var lead: Dictionary = beats[index]
		var span := 1
		var killed := _gag_killed(lead)
		var follow := index + 1
		while follow < beats.size():
			var nxt: Dictionary = beats[follow]
			if not _same_gag(lead, nxt) and not GagMovie.same_chorus(lead, nxt):
				break
			if _gag_killed(nxt):
				killed = true
			span += 1
			follow += 1
		var slice: Array = []
		for step in span:
			slice.append(beats[index + step])
		var dur := 0.0
		if GagMovie.split_parties(slice).size() > 1:
			dur = GagMovie.chorus_seconds(slice)
			if killed:
				dur += GagMovie.LOSE_SECONDS
		else:
			dur = _beat_dur(lead)
			# The lead survived and another cog in the group did not. One death
			# track covers the group, so the extra time is added once.
			if killed and not _gag_killed(lead):
				dur += GagMovie.LOSE_SECONDS
		lead["dur"] = dur
		for step in range(1, span):
			(beats[index + step] as Dictionary)["dur"] = 0.0
		total += dur
		index += span
	return total


func _group_gag(beat: Dictionary) -> bool:
	if String(beat.get("kind", "")) != "gag":
		return false
	return ToonLoadout.affects_group(int(beat.get("track", -1)), int(beat.get("level", -1)))


func _same_gag(lead: Dictionary, other: Variant) -> bool:
	if not (other is Dictionary) or not _group_gag(lead):
		return false
	var nxt: Dictionary = other
	return String(nxt.get("kind", "")) == "gag" and int(nxt.get("track", -2)) == int(lead.get("track", -1)) and int(nxt.get("level", -2)) == int(lead.get("level", -1)) and int(nxt.get("toon", -2)) == int(lead.get("toon", -1))


func _gag_killed(beat: Variant) -> bool:
	if not (beat is Dictionary):
		return false
	var row: Dictionary = beat
	return String(row.get("kind", "")) == "gag" and int(row.get("cog_hp", 1)) <= 0


func _beat_dur(beat: Dictionary) -> float:
	# Toon.getDiedInterval starts at the hit. The movie stays up through the shrink.
	# A defeated cog then plays Suit.getLoseActor for SUIT_LOSE_DURATION.
	var length := GagMovie.seconds(String(beat.get("kind", "")), int(beat.get("track", -1)), int(beat.get("level", 0)), bool(beat.get("died", false)), String(beat.get("attack", "")))
	if _gag_killed(beat):
		length += GagMovie.LOSE_SECONDS
	return length


func _beat(text: String, track: int, level: int, toon: Dictionary, cog: Dictionary, hit: bool, damage: int, react: String = "auto") -> Dictionary:
	var clip := react
	if clip == "auto":
		clip = _react_for(track, hit)
	return {
		"text": text,
		"kind": "gag",
		"track": track,
		"level": level,
		"hit": hit,
		"damage": damage,
		"toon": int(toon.get("id", 0)),
		"cog": int(cog.get("id", 0)),
		"cog_hp": int(cog.get("hp", -1)),
		"react": clip,
	}


func _react_for(track: int, hit: bool) -> String:
	if not hit:
		return "sidestep-left"
	if track == 1:
		return "rake-react"
	if track == 2:
		return "hypnotized"
	if track == 3:
		return "flatten"
	if track == 5:
		return "squirt-small"
	if track == 6:
		return "drop-react"
	return "pie-small"


func _cog_targets(fight: Dictionary, choice: Dictionary) -> Array:
	var track := int(choice.get("track", -1))
	var level := int(choice.get("level", 0))
	var living: Array = []
	for item in fight["cogs"]:
		var cog: Dictionary = item
		if int(cog.get("hp", 0)) > 0:
			living.append(cog)
	if ToonLoadout.affects_group(track, level):
		return living
	var want := int(choice.get("target", -1))
	for cog in living:
		if int((cog as Dictionary).get("id", 0)) == want:
			return [cog]
	if living.is_empty():
		return []
	return [living[0]]


func _hurt_cog(suit: Dictionary, damage: int) -> void:
	suit["hp"] = maxi(int(suit.get("hp", 0)) - maxi(damage, 0), 0)


## useSkeleRevive. The killing hit plays the lose, then the suit stands back
## up as a Skelecog with full health. A cog that is already a Skelecog stays down.
func _revive_suit(suit: Dictionary) -> bool:
	if int(suit.get("hp", 1)) > 0 or bool(suit.get("skeleton", false)):
		return false
	if int(suit.get("revives", 0)) < 1:
		return false
	suit["revives"] = int(suit.get("revives", 0)) - 1
	suit["had_revives"] = true
	suit["hp"] = int(suit.get("max_hp", 1))
	suit["skeleton"] = true
	suit["name"] = "Skelecog"
	return true


func _add_toon(fight: Dictionary, peer: int, toon_name: String, hp: int, max_hp: int) -> void:
	if not _toon(fight, peer).is_empty():
		return
	if (fight["toons"] as Array).size() >= MAX_TOONS:
		return
	var saved := ToonNet.stored_laff(peer)
	if saved.x >= 0:
		hp = saved.x
		max_hp = saved.y
	var maximum := maxi(max_hp, 1)
	(fight["toons"] as Array).append({
		"id": peer,
		"av": ToonNet.avatar_of(peer),
		"name": toon_name if toon_name != "" else "Toon",
		"hp": clampi(hp, 1, maximum),
		"max_hp": maximum,
		"slot": [0.0, 0.0, 0.0],
	})
	_place(fight)
	_mark(fight)


func _persist_gags(fight: Dictionary) -> void:
	var picks: Array = fight.get("choices", [])
	for index in picks.size():
		var choice: Dictionary = picks[index]
		var track := int(choice.get("track", -1))
		if track < 0:
			continue
		var who := _toon(fight, int(choice.get("id", 0)))
		if who.is_empty():
			continue
		ToonNet.persist_gag(_avatar(who), track, int(choice.get("level", 0)))


func _persist_laff(fight: Dictionary) -> void:
	var roster: Array = fight.get("toons", [])
	for index in roster.size():
		var member: Dictionary = roster[index]
		_persist_one(member)


func _persist_one(toon: Dictionary) -> void:
	ToonNet.persist_laff(_avatar(toon), int(toon.get("hp", 1)), int(toon.get("max_hp", 1)))


func _avatar(toon: Dictionary) -> int:
	var av_id := int(toon.get("av", 0))
	if av_id <= 0:
		av_id = ToonNet.avatar_of(int(toon.get("id", 0)))
		toon["av"] = av_id
	return av_id


func _add_cog(fight: Dictionary, cog: Dictionary) -> void:
	var level := int(cog.get("level", 1))
	var hp := Cog.hp_for_level(level)
	var row := {
		"id": int(cog.get("id", 0)),
		"code": String(cog.get("code", "")),
		"name": String(cog.get("name", "Cog")),
		"level": level,
		"hp": hp,
		"max_hp": hp,
		"lured": false,
		"trap": {},
		"dept": String(cog.get("dept", "c")),
		"skeleton": bool(cog.get("skeleton", false)),
		"boss": bool(cog.get("boss", false)),
		"revives": int(cog.get("revives", 0)),
		"body": String(cog.get("body", "c")),
		"height": float(cog.get("height", 4.0)),
		"from": cog.get("pos", [0.0, 0.0, 0.0]),
		"slot": cog.get("pos", [0.0, 0.0, 0.0]),
	}
	if cog.has("from_h"):
		row["from_h"] = float(cog["from_h"])
	(fight["cogs"] as Array).append(row)


func _place(fight: Dictionary) -> void:
	var origin := _point(fight.get("origin", []))
	var yaw := float(fight.get("yaw", 180.0))
	var forward := _battle_forward(yaw)
	var right := Vector3.UP.cross(forward)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var cogs: Array = fight.get("cogs", [])
	var toons: Array = fight.get("toons", [])
	var suit_row: Array = _SUIT_POINTS[clampi(cogs.size(), 1, 4) - 1]
	var toon_row: Array = _TOON_POINTS[clampi(toons.size(), 1, 4) - 1]
	var suit_head: Array = _SUIT_HEAD[clampi(cogs.size(), 1, 4) - 1]
	var toon_head: Array = _TOON_HEAD[clampi(toons.size(), 1, 4) - 1]
	var indoors := int(fight.get("building", 0)) != 0
	for index in cogs.size():
		var cog: Dictionary = cogs[index]
		var spot: Vector2 = suit_row[mini(index, suit_row.size() - 1)] as Vector2
		cog["slot"] = _battle_slot(origin, right, forward, spot)
		if indoors:
			cog["h"] = float(suit_head[mini(index, suit_head.size() - 1)])
	for index in toons.size():
		var toon: Dictionary = toons[index]
		var spot: Vector2 = toon_row[mini(index, toon_row.size() - 1)] as Vector2
		toon["slot"] = _battle_slot(origin, right, forward, spot)
		if indoors:
			toon["h"] = float(toon_head[mini(index, toon_head.size() - 1)])


func _battle_slot(origin: Vector3, right: Vector3, forward: Vector3, spot: Vector2) -> Array:
	var placed := origin + right * spot.x + forward * spot.y
	placed.y = origin.y
	return [placed.x, placed.y, placed.z]


func _opening_yaw(cog_pos: Vector3) -> float:
	var scene := get_tree().current_scene
	if scene == null:
		return 180.0
	var body := scene.find_child("Player", true, false) as Node3D
	if body == null:
		return 180.0
	var flat := Vector2(cog_pos.x - body.global_position.x, cog_pos.z - body.global_position.z)
	if flat.length_squared() < 0.04:
		return 180.0
	return rad_to_deg(atan2(-flat.x, -flat.y))


func _street_suits(slug: String) -> StreetSuits:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var node := scene.find_child("StreetSuits", true, false)
	if node is StreetSuits and (node as StreetSuits).street_slug == slug:
		return node as StreetSuits
	return null


func _battle_forward(heading: float) -> Vector3:
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	upright = upright.rotated(Vector3.UP, deg_to_rad(heading))
	return upright * Vector3(0, 1, 0)


func _all_chosen(fight: Dictionary) -> bool:
	for item in fight.get("toons", []):
		var toon: Dictionary = item
		if int(toon.get("hp", 0)) <= 0:
			continue
		if _choice_for(fight, int(toon.get("id", -1))) < 0:
			return false
	return true


func _choice_for(fight: Dictionary, peer: int) -> int:
	var choices: Array = fight.get("choices", [])
	for index in choices.size():
		var choice: Dictionary = choices[index]
		if int(choice.get("id", -1)) == peer:
			return index
	return -1


func _drop_missing(fight: Dictionary) -> void:
	if not ToonNet.networked():
		return
	var here: Array = [1]
	if multiplayer.multiplayer_peer != null:
		for peer in multiplayer.get_peers():
			here.append(int(peer))
		here.append(multiplayer.get_unique_id())
	var kept: Array = []
	var changed := false
	for item in fight.get("toons", []):
		var toon: Dictionary = item
		if here.has(int(toon.get("id", 0))):
			kept.append(toon)
		else:
			changed = true
	if changed:
		fight["toons"] = kept
		_place(fight)
		_mark(fight)


func _fight_with(district: int, slug: String, peer: int, cog_id: int) -> Dictionary:
	for item in _fights:
		var fight: Dictionary = item
		if int(fight.get("district", -1)) != district or String(fight.get("slug", "")) != slug:
			continue
		if String(fight.get("state", "")) == "gone":
			continue
		if not _toon(fight, peer).is_empty():
			return fight
		for cog in fight.get("cogs", []):
			if int((cog as Dictionary).get("id", 0)) == cog_id:
				return fight
	return {}


func _by_id(fight_id: int) -> Dictionary:
	for item in _fights:
		var fight: Dictionary = item
		if int(fight.get("id", 0)) == fight_id:
			return fight
	return {}


func _toon(fight: Dictionary, peer: int) -> Dictionary:
	for item in fight.get("toons", []):
		var toon: Dictionary = item
		if int(toon.get("id", -1)) == peer:
			return toon
	return {}


func _find_cog(district: int, slug: String, cog_id: int) -> Dictionary:
	for row in _rows(district, slug):
		var info := _cog_info(row)
		if int(info.get("id", 0)) == cog_id:
			return info
	return {}


func _nearby(district: int, slug: String, origin: Vector3, skip: int) -> Array:
	var found: Array = []
	for row in _rows(district, slug):
		var info := _cog_info(row)
		if int(info.get("id", 0)) == 0 or int(info.get("id", 0)) == skip:
			continue
		if int(info.get("phase", -1)) != 1:
			continue
		if _cog_busy(int(info.get("id", 0))):
			continue
		if _flat(_point(info.get("pos", [])), origin) > NEAR_COG:
			continue
		found.append(info)
	return found


func cog_paused(cog_id: int) -> bool:
	return _cog_busy(cog_id)


func _cog_busy(cog_id: int) -> bool:
	for item in _fights:
		var fight: Dictionary = item
		if String(fight.get("state", "")) == "gone":
			continue
		for cog in fight.get("cogs", []):
			if int((cog as Dictionary).get("id", 0)) == cog_id:
				return true
	return false


func _rows(district: int, slug: String) -> Array:
	var traffic := get_parent()
	if traffic != null and traffic.has_method("cog_rows"):
		return traffic.call("cog_rows", district, slug)
	return []


func _cog_info(row: Variant) -> Dictionary:
	if not (row is Dictionary):
		return {}
	var source: Dictionary = row
	var cog: Variant = source.get("cog", {})
	if not (cog is Dictionary):
		return {}
	var body: Dictionary = cog
	return {
		"id": int(source.get("do_id", 0)),
		"code": String(body.get("code", "")),
		"name": String(body.get("name", "Cog")),
		"level": int(body.get("level", 1)),
		"dept": String(body.get("dept", "c")),
		"skeleton": bool(body.get("skeleton", false)),
		"revives": int(body.get("revives", 0)),
		"body": String(body.get("body", "c")),
		"height": float(body.get("height", 4.0)),
		"phase": int(source.get("phase", -1)),
		"pos": _array_point(source.get("position", [])),
	}


func _array_point(value: Variant) -> Array:
	var point := _point(value)
	return [point.x, point.y, point.z]


func _point(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array:
		var row: Array = value
		if row.size() >= 3:
			return Vector3(float(row[0]), float(row[1]), float(row[2]))
	return Vector3.ZERO


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _mark(fight: Dictionary) -> void:
	_dirty["%d:%s" % [int(fight.get("district", 0)), String(fight.get("slug", ""))]] = true
	_publish_wait = 0.0


func _publish_key(key: String) -> void:
	var rows: Array = []
	var parts := key.split(":", false, 1)
	if parts.size() < 2:
		return
	var district := int(parts[0])
	var slug := parts[1]
	for item in _fights:
		var fight: Dictionary = item
		if int(fight.get("district", -1)) == district and String(fight.get("slug", "")) == slug and String(fight.get("state", "")) != "gone":
			rows.append(fight)
	ToonNet.publish("fights:" + key, {"rows": rows})
