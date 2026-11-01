extends Node

## DistributedBattleAI for a street. The district server owns the round:
## who joined, which gag each toon picked, and whether it hit. Clients only
## show that. A battle holds four toons and four cogs. Face-off stays open,
## then everyone has BBbattleInputTimeout seconds to choose.

const JOIN_TIME := 5.0
const INPUT_TIME := 20.0
const MAX_TOONS := 4
const MAX_COGS := 4
const NEAR_COG := 15.0
const _ATTACKS: Array[String] = ["Pound Key", "Shred", "Clip On Tie", "Glower Power"]
const _ATTACK_KEYS: Array[String] = ["phone", "throw-paper", "finger-wag", "glower"]

var _fights: Array = []
var _next := 1
var _dirty: Dictionary = {}
var _publish_wait := 0.0


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
		if String(existing.get("state", "")) == "join":
			_add_toon(existing, peer, toon_name, hp, max_hp)
		return
	var cog := _find_cog(district, slug, cog_id)
	if cog.is_empty() or int(cog.get("phase", -1)) != 1:
		return
	var fight := {
		"id": _next,
		"district": district,
		"slug": slug,
		"state": "join",
		"left": JOIN_TIME,
		"seq": 1,
		"round": 1,
		"toons": [],
		"cogs": [],
		"choices": [],
		"beats": [],
		"origin": cog.get("pos", [0.0, 0.0, 0.0]),
	}
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
	_mark(fight)


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
	if track < -2 or track > 6 or level < -1 or level > 6:
		pick["track"] = -1
		pick["level"] = -1
	(fight["choices"] as Array).append(pick)
	_mark(fight)


func _tick(fight: Dictionary, delta: float) -> void:
	var state := String(fight.get("state", ""))
	if state == "gone" or state == "":
		return
	fight["left"] = maxf(float(fight.get("left", 0.0)) - delta, 0.0)
	if state == "join" or state == "input":
		fight["pulse"] = float(fight.get("pulse", 0.0)) + delta
		if float(fight["pulse"]) >= 0.5:
			fight["pulse"] = 0.0
			_mark(fight)
	if state == "join":
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
	if state == "reward" and float(fight["left"]) <= 0.0:
		fight["state"] = "gone"
		_mark(fight)


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
	var order: Array[int] = [0, 1, 2, 3, 4, 5, 6]
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
		if bool(fighter.get("lured", false)):
			beats.append({"text": "The %s is lured." % String(fighter.get("name", "cog")), "kind": "lured", "cog": int(fighter.get("id", 0))})
			fighter["lured"] = false
			continue
		_suit_attack(fight, fighter, beats)
	fight["beats"] = beats
	fight["state"] = "movie"
	fight["left"] = maxf(_time_beats(beats), 1.2)
	_persist_gags(fight)
	_persist_laff(fight)
	fight["seq"] = int(fight.get("seq", 0)) + 1
	_mark(fight)


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
	if targets.is_empty():
		return
	var damage := ToonLoadout.gag_damage(track, level, int(choice.get("exp", 0)))
	var accuracy := ToonLoadout.gag_accuracy(track, level)
	for cog in targets:
		var suit: Dictionary = cog
		if int(suit.get("hp", 0)) <= 0:
			continue
		var cog_name := String(suit.get("name", "cog"))
		if track == 1:
			suit["trap"] = {"damage": damage, "gag": gag, "by": who}
			beats.append(_beat("%s set a %s on the %s." % [who, gag, cog_name], track, level, toon, suit, true, 0))
			continue
		if track == 2:
			_lure(fight, toon, suit, gag, accuracy, beats, track, level)
			continue
		var lured := bool(suit.get("lured", false))
		if track == 3 and lured:
			beats.append(_beat("The %s is lured, so the %s missed." % [cog_name, gag], track, level, toon, suit, false, 0))
			continue
		if track == 6 and not lured:
			beats.append(_beat("%s's %s missed the %s." % [who, gag, cog_name], track, level, toon, suit, false, 0))
			continue
		if randi_range(0, 99) >= accuracy:
			beats.append(_beat("%s's %s missed the %s." % [who, gag, cog_name], track, level, toon, suit, false, 0))
			continue
		_hurt_cog(suit, damage)
		var line := "%s used a %s on the %s for %d damage." % [who, gag, cog_name, damage]
		if int(suit.get("hp", 0)) <= 0:
			line += " The %s is defeated." % cog_name
		beats.append(_beat(line, track, level, toon, suit, true, damage))


func _lure(fight: Dictionary, toon: Dictionary, suit: Dictionary, gag: String, accuracy: int, beats: Array, track: int, level: int) -> void:
	var who := String(toon.get("name", "A toon"))
	var cog_name := String(suit.get("name", "cog"))
	if bool(suit.get("lured", false)) or randi_range(0, 99) >= accuracy:
		beats.append(_beat("%s's %s missed the %s." % [who, gag, cog_name], track, level, toon, suit, false, 0))
		return
	suit["lured"] = true
	beats.append(_beat("%s's %s lured the %s." % [who, gag, cog_name], track, level, toon, suit, true, 0))
	var trap: Variant = suit.get("trap", {})
	if not (trap is Dictionary) or (trap as Dictionary).is_empty():
		return
	var laid: Dictionary = trap
	var damage := int(laid.get("damage", 0))
	suit["trap"] = {}
	_hurt_cog(suit, damage)
	var line := "The %s hit the %s for %d damage." % [String(laid.get("gag", "trap")), cog_name, damage]
	if int(suit.get("hp", 0)) <= 0:
		line += " The %s is defeated." % cog_name
	beats.append(_beat(line, 1, 0, toon, suit, true, damage))


func _heal(fight: Dictionary, toon: Dictionary, choice: Dictionary, gag: String, who: String, beats: Array) -> void:
	var track := int(choice.get("track", 0))
	var level := int(choice.get("level", 0))
	var amount := ToonLoadout.gag_damage(track, level, int(choice.get("exp", 0)))
	var accuracy := ToonLoadout.gag_accuracy(track, level)
	var targets: Array = []
	if ToonLoadout.affects_group(track, level):
		targets = fight["toons"]
	else:
		var picked := _toon(fight, int(choice.get("target", -1)))
		if picked.is_empty():
			picked = toon
		targets = [picked]
	for item in targets:
		var patient: Dictionary = item
		if int(patient.get("hp", 0)) <= 0:
			continue
		if randi_range(0, 99) >= accuracy:
			beats.append(_beat("%s's %s missed." % [who, gag], track, level, toon, {}, false, 0, ""))
			continue
		var before := int(patient.get("hp", 0))
		patient["hp"] = mini(before + amount, int(patient.get("max_hp", before)))
		var gained := int(patient.get("hp", 0)) - before
		var healed := _beat("%s used a %s and healed %d laff." % [who, gag, gained], track, level, toon, {}, true, gained, "")
		healed["toon_hp"] = int(patient.get("hp", 0))
		healed["toon_id"] = int(patient.get("id", 0))
		beats.append(healed)


func _suit_attack(fight: Dictionary, suit: Dictionary, beats: Array) -> void:
	var living: Array = []
	for item in fight["toons"]:
		var candidate: Dictionary = item
		if int(candidate.get("hp", 0)) > 0:
			living.append(candidate)
	if living.is_empty():
		return
	var victim: Dictionary = living[randi() % living.size()]
	var level := int(suit.get("level", 1))
	var which := posmod(level, _ATTACKS.size())
	var accuracy := mini(70 + mini(level, 5) * 3, 95)
	var damage := (level + 1) * 2
	var cog_name := String(suit.get("name", "cog"))
	var attack := _ATTACKS[which]
	if randi_range(0, 99) >= accuracy:
		beats.append({
			"text": "%s dodged the %s." % [String(victim.get("name", "A toon")), cog_name],
			"kind": "cog",
			"hit": false,
			"cog": int(suit.get("id", 0)),
			"toon": int(victim.get("id", 0)),
			"anim": _ATTACK_KEYS[which],
			"react": "sidestep-left",
		})
		return
	victim["hp"] = maxi(int(victim.get("hp", 0)) - damage, 0)
	var line := "The %s used %s on %s for %d damage." % [cog_name, attack, String(victim.get("name", "a toon")), damage]
	if int(victim.get("hp", 0)) <= 0:
		line += " %s is sad." % String(victim.get("name", "A toon"))
	beats.append({
		"text": line,
		"kind": "cog",
		"hit": true,
		"damage": damage,
		"cog": int(suit.get("id", 0)),
		"toon": int(victim.get("id", 0)),
		"toon_hp": int(victim.get("hp", 0)),
		"anim": _ATTACK_KEYS[which],
		"react": "cringe",
	})


func _finish_movie(fight: Dictionary) -> void:
	var cogs: Array = fight["cogs"]
	var kept: Array = []
	var traffic := get_parent()
	for item in cogs:
		var cog: Dictionary = item
		if int(cog.get("hp", 0)) <= 0:
			if traffic != null and traffic.has_method("dismiss_cog"):
				traffic.call("dismiss_cog", int(fight.get("district", 0)), String(fight.get("slug", "")), int(cog.get("id", 0)))
			continue
		cog["lured"] = false
		kept.append(cog)
		if traffic != null and traffic.has_method("park_cog"):
			traffic.call("park_cog", int(fight.get("district", 0)), String(fight.get("slug", "")), int(cog.get("id", 0)), cog.get("slot", []))
	fight["cogs"] = kept
	var toons: Array = []
	for member in fight["toons"]:
		var toon: Dictionary = member
		if int(toon.get("hp", 0)) <= 0:
			toon["hp"] = 1
		else:
			toons.append(toon)
		_persist_one(toon)
	fight["toons"] = toons
	_place(fight)
	if kept.is_empty() or toons.is_empty():
		fight["state"] = "reward"
		fight["left"] = 2.4
		fight["beats"] = []
		fight["seq"] = int(fight.get("seq", 0)) + 1
		_mark(fight)
		return
	fight["round"] = int(fight.get("round", 1)) + 1
	_begin_input(fight)


## Lengths match GagMovie. A group gag plays once, so the extra hits take no extra time.
func _time_beats(beats: Array) -> float:
	var total := 0.0
	var index := 0
	while index < beats.size():
		var lead: Dictionary = beats[index]
		var span := 1
		if _group_gag(lead):
			var follow := index + 1
			while follow < beats.size() and _same_gag(lead, beats[follow]):
				(beats[follow] as Dictionary)["dur"] = 0.0
				span += 1
				follow += 1
		var dur := _beat_dur(lead)
		lead["dur"] = dur
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


func _beat_dur(beat: Dictionary) -> float:
	var kind := String(beat.get("kind", ""))
	if kind == "run" or kind == "lured":
		return 1.3
	if kind == "cog":
		return 3.8
	var track := int(beat.get("track", -1))
	var level := int(beat.get("level", 0))
	if track == 4:
		return 4.8
	if track == 5 and level == 0:
		return 3.6
	if track == 5 and level >= 5:
		return 4.2
	if track == 5:
		return 3.4
	if track == 6:
		return 5.6
	if track == 1:
		return 3.6
	if track == 2:
		return 3.8
	if track == 3:
		return 3.4
	if track == 0:
		return 3.0
	return 2.2


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
	(fight["cogs"] as Array).append({
		"id": int(cog.get("id", 0)),
		"name": String(cog.get("name", "Cog")),
		"level": level,
		"hp": hp,
		"max_hp": hp,
		"lured": false,
		"trap": {},
		"slot": cog.get("pos", [0.0, 0.0, 0.0]),
	})


func _place(fight: Dictionary) -> void:
	var origin := _point(fight.get("origin", []))
	var cogs: Array = fight.get("cogs", [])
	var toons: Array = fight.get("toons", [])
	for index in cogs.size():
		var cog: Dictionary = cogs[index]
		cog["slot"] = _slot(origin, index, cogs.size(), 4.0)
	for index in toons.size():
		var toon: Dictionary = toons[index]
		toon["slot"] = _slot(origin, index, toons.size(), -7.0)


func _slot(origin: Vector3, index: int, count: int, side: float) -> Array:
	var span := 3.4
	var start := -span * float(count - 1) * 0.5
	return [origin.x + start + span * float(index), origin.y, origin.z + side]


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
		"name": String(body.get("name", "Cog")),
		"level": int(body.get("level", 1)),
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
