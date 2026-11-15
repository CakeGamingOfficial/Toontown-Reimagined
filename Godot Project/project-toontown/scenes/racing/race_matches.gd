class_name KartRaces
extends Node

## The district runs Goofy Speedway the way DistributedRacePadAI did.
## A client asks to sit, throws, or finish. This process keeps the one copy
## of the pad and the race, and every toon plays that same record.

const _CHANNEL := "race"
const _LAYOUT := "res://assets/racing/speedway.json"
const _RULES := preload("res://scenes/racing/kart_rules.gd")

var _pads: Array = []
var _races: Array = []
var _seq := 1
var _loot_seq := 1
var _since := 0.0
var _throw_at: Dictionary = {}


func _ready() -> void:
	_load_pads()
	_publish()


func _process(delta: float) -> void:
	if not ToonNet.is_authority():
		return
	var changed := _tick(delta)
	var hot := false
	for pad in _pads:
		if float(pad.get("wait", -1.0)) >= 0.0:
			hot = true
	if not _races.is_empty():
		hot = true
	if not hot and not changed:
		return
	_since += delta
	if changed or _since >= 0.2:
		_since = 0.0
		_publish()


func take(peer: int, kind: String, state: Dictionary) -> void:
	if kind == "drop":
		_drop(peer)
		return
	_act(peer, kind, state)


static func drop_peer(peer: int) -> void:
	var bus := _bus()
	if bus == null:
		return
	bus._drop(peer)


static func live() -> bool:
	return not pads().is_empty()


static func pads() -> Array:
	var listed: Variant = ToonNet.latest(_CHANNEL).get("pads", [])
	if listed is Array:
		return listed
	return []


static func mine() -> Dictionary:
	var peer := ToonNet.peer_id()
	var listed: Variant = ToonNet.latest(_CHANNEL).get("races", [])
	if not (listed is Array):
		return {}
	for item in listed as Array:
		if not (item is Dictionary):
			continue
		var race: Dictionary = item
		var racers: Variant = race.get("racers", [])
		if not (racers is Array):
			continue
		for racer in racers as Array:
			if racer is Dictionary and int((racer as Dictionary).get("peer", 0)) == peer:
				return race
	return {}


static func wait_left(pad_index: int) -> float:
	var row := _pad_row(pad_index)
	return float(row.get("wait", -1.0))


static func notice(pad_index: int) -> String:
	return String(_pad_row(pad_index).get("notice", ""))


static func on_pad(pad_index: int) -> bool:
	var peers: Variant = _pad_row(pad_index).get("peers", [])
	return peers is Array and (peers as Array).has(ToonNet.peer_id())


static func pad_closed(pad_index: int) -> bool:
	var listed: Variant = ToonNet.latest(_CHANNEL).get("races", [])
	if not (listed is Array):
		return false
	for item in listed as Array:
		if item is Dictionary and int((item as Dictionary).get("pad", -1)) == pad_index:
			return true
	return false


static func my_place() -> int:
	var race := mine()
	var racers: Variant = race.get("racers", [])
	if not (racers is Array):
		return 0
	var peer := ToonNet.peer_id()
	for racer in racers as Array:
		if racer is Dictionary and int((racer as Dictionary).get("peer", 0)) == peer:
			return int((racer as Dictionary).get("place", 0))
	return 0


static func _pad_row(pad_index: int) -> Dictionary:
	var listed := pads()
	if pad_index < 0 or pad_index >= listed.size() or not (listed[pad_index] is Dictionary):
		return {}
	return listed[pad_index]


static func _bus() -> KartRaces:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("RaceBus") as KartRaces


func _act(peer: int, kind: String, state: Dictionary) -> void:
	if kind == "join":
		_join(peer, state)
	elif kind == "leave":
		_leave_pad(peer)
	elif kind == "seated":
		_mark_seated(peer)
	elif kind == "pose":
		_pose(peer, state)
	elif kind == "throw":
		_throw(peer, state)
	elif kind == "box":
		_box(peer, int(state.get("slot", -1)))
	elif kind == "finish":
		_finish(peer, float(state.get("time", 0.0)))
	elif kind == "exit":
		_exit(peer)
	if kind != "pose":
		_publish()
		_since = 0.0


func _tick(delta: float) -> bool:
	var changed := false
	for pad in _pads:
		if bool(pad.get("viewing", false)):
			continue
		var notice_left := float(pad.get("notice_left", 0.0))
		if notice_left > 0.0:
			pad["notice_left"] = notice_left - delta
			if float(pad["notice_left"]) <= 0.0:
				pad["notice"] = ""
				changed = true
		var seats: Array = pad["seats"]
		if not seats.is_empty() or _race_for(int(pad["slot"])) >= 0:
			continue
		pad["left"] = float(pad["left"]) - delta
		if float(pad["left"]) <= 0.0:
			pad["left"] = _RULES.SIGN_TIME
			var picked := _RULES.next_track(int(pad["track"]), String(pad["genre"]), int(pad["index"]))
			pad["track"] = int(picked.get("track", 0))
			pad["type"] = int(picked.get("type", 0))
			pad["laps"] = int(picked.get("laps", _RULES.LAPS))
			changed = true
	for pad in _pads:
		if float(pad.get("wait", -1.0)) < 0.0:
			continue
		pad["wait"] = float(pad["wait"]) - delta
		if float(pad["wait"]) <= 0.0 and _consider(pad):
			changed = true
	var done: Array = []
	for race in _races:
		if String(race["phase"]) == "enter":
			race["timer"] = float(race["timer"]) - delta
			if float(race["timer"]) <= 0.0:
				race["phase"] = "run"
				changed = true
		var boxes: Array = race["down"]
		var kept: Array = []
		for box in boxes:
			if not (box is Dictionary):
				continue
			var until := float((box as Dictionary).get("until", 0.0)) - delta
			if until > 0.0:
				(box as Dictionary)["until"] = until
				kept.append(box)
			else:
				changed = true
		race["down"] = kept
		if (race["racers"] as Array).is_empty():
			done.append(race)
	for race in done:
		_races.erase(race)
		changed = true
	return changed


func _join(peer: int, state: Dictionary) -> void:
	if not _find_peer(peer).is_empty() or not _race_with(peer).is_empty():
		return
	var pad_index := int(state.get("pad", -1))
	if pad_index < 0 or pad_index >= _pads.size():
		return
	var pad: Dictionary = _pads[pad_index]
	if bool(pad.get("viewing", false)):
		return
	if _race_for(pad_index) >= 0:
		return
	var seats: Array = pad["seats"]
	if seats.size() >= _RULES.MAX_RACERS or seats.size() >= int(pad["blocks"]):
		return
	var block := int(state.get("block", -1))
	if block < 0 or block >= int(pad["blocks"]):
		return
	for seat in seats:
		if int((seat as Dictionary).get("block", -1)) == block:
			return
	var style: Dictionary = {}
	var sent: Variant = state.get("style", {})
	if sent is Dictionary:
		style = (sent as Dictionary).duplicate(true)
	var dna: Array = []
	var row: Variant = state.get("dna", [])
	if row is Array:
		for item in row as Array:
			if dna.size() >= 16:
				break
			dna.append(int(item))
	seats.append({
		"peer": peer,
		"av": int(state.get("av", 0)),
		"name": String(state.get("name", "Toon")),
		"block": block,
		"dna": dna,
		"style": style,
		"seated": false,
	})
	pad["notice"] = ""
	pad["notice_left"] = 0.0
	if float(pad["wait"]) < 0.0:
		pad["wait"] = _RULES.COUNTDOWN


func _leave_pad(peer: int) -> void:
	for pad in _pads:
		var seats: Array = pad["seats"]
		var kept: Array = []
		for seat in seats:
			if int((seat as Dictionary).get("peer", 0)) != peer:
				kept.append(seat)
		pad["seats"] = kept
		if kept.is_empty() and _race_for(int(pad["slot"])) < 0:
			pad["wait"] = -1.0


func _mark_seated(peer: int) -> void:
	var seat := _find_peer(peer)
	if seat.is_empty():
		return
	seat["seated"] = true
	for pad in _pads:
		if float(pad.get("wait", -1.0)) != 0.0:
			continue
		var found := false
		for other in pad["seats"] as Array:
			if int((other as Dictionary).get("peer", 0)) == peer:
				found = true
		if found:
			_consider(pad)


func _consider(pad: Dictionary) -> bool:
	var seats: Array = pad["seats"]
	for seat in seats:
		if not bool((seat as Dictionary).get("seated", false)):
			pad["wait"] = 0.0
			return false
	var kind := int(pad["type"])
	if (kind == _RULES.BATTLE or kind == _RULES.CIRCUIT) and seats.size() < 2:
		pad["seats"] = []
		pad["wait"] = -1.0
		pad["notice"] = "racers"
		pad["notice_left"] = 5.0
		return true
	if seats.is_empty():
		pad["wait"] = -1.0
		return true
	_seq += 1
	var racers: Array = []
	for seat in seats:
		var copy: Dictionary = (seat as Dictionary).duplicate(true)
		copy["x"] = 0.0
		copy["y"] = 0.0
		copy["z"] = 0.0
		copy["yaw"] = 0.0
		copy["speed"] = 0.0
		copy["lap"] = 0
		copy["along"] = 0.0
		copy["place"] = 0
		copy["done"] = false
		racers.append(copy)
	_races.append({
		"id": _seq,
		"pad": int(pad["slot"]),
		"track": int(pad["track"]),
		"type": int(pad["type"]),
		"laps": int(pad["laps"]),
		"phase": "enter",
		"timer": _RULES.ENTER_RACE,
		"racers": racers,
		"events": [],
		"down": [],
		"loot": [],
	})
	pad["seats"] = []
	pad["wait"] = -1.0
	return true


func _pose(peer: int, state: Dictionary) -> void:
	var race := _race_with(peer)
	if race.is_empty() or String(race.get("phase", "")) != "run":
		return
	var racer := _racer(race, peer)
	if racer.is_empty() or bool(racer.get("done", false)):
		return
	racer["x"] = float(state.get("x", 0.0))
	racer["y"] = float(state.get("y", 0.0))
	racer["z"] = float(state.get("z", 0.0))
	racer["yaw"] = float(state.get("yaw", 0.0))
	racer["speed"] = float(state.get("speed", 0.0))
	racer["lap"] = int(state.get("lap", 0))
	racer["along"] = float(state.get("along", 0.0))


func _throw(peer: int, state: Dictionary) -> void:
	var race := _race_with(peer)
	if race.is_empty() or String(race.get("phase", "")) != "run":
		return
	var now := Time.get_ticks_msec()
	if now - int(_throw_at.get(peer, 0)) < 350:
		return
	_throw_at[peer] = now
	var gag := int(state.get("gag", 0))
	var at := Vector3(float(state.get("x", 0.0)), float(state.get("y", 0.0)), float(state.get("z", 0.0)))
	var nose := Vector3(float(state.get("nx", 0.0)), float(state.get("ny", 0.0)), float(state.get("nz", 0.0)))
	var target := 0
	if gag == _RULES.ANVIL:
		target = _anvil_target(race, peer)
		if target == 0:
			return
	elif gag == _RULES.PIE:
		target = _pie_target(race, peer, at, nose)
	elif gag != _RULES.BANANA:
		return
	_push_event(race, gag, peer, target, at)


func _box(peer: int, slot: int) -> void:
	var race := _race_with(peer)
	if race.is_empty() or slot < 0 or String(race.get("phase", "")) != "run":
		return
	var down: Array = race["down"]
	for box in down:
		if int((box as Dictionary).get("slot", -1)) == slot:
			return
	down.append({"slot": slot, "until": 5.0})
	_loot_seq += 1
	var loot: Array = race["loot"]
	loot.append({
		"seq": _loot_seq,
		"peer": peer,
		"slot": slot,
		"gag": _RULES.gag_type(_place_of(race, peer), randi() % 6),
	})
	while loot.size() > 8:
		loot.pop_front()


func _finish(peer: int, total_time: float) -> void:
	var race := _race_with(peer)
	if race.is_empty():
		return
	var racer := _racer(race, peer)
	if racer.is_empty() or bool(racer.get("done", false)):
		return
	var place := 1
	for other in race["racers"] as Array:
		if bool((other as Dictionary).get("done", false)):
			place += 1
	racer["done"] = true
	racer["place"] = place
	racer["clock"] = total_time


func _exit(peer: int) -> void:
	_leave_pad(peer)
	var gone: Array = []
	for race in _races:
		var racers: Array = race["racers"]
		var kept: Array = []
		for racer in racers:
			if int((racer as Dictionary).get("peer", 0)) != peer:
				kept.append(racer)
		race["racers"] = kept
		if kept.is_empty():
			gone.append(race)
	for race in gone:
		_races.erase(race)


func _drop(peer: int) -> void:
	_throw_at.erase(peer)
	_exit(peer)
	_publish()


func _anvil_target(race: Dictionary, owner: int) -> int:
	var best_peer := 0
	var best_along := -1.0
	var second_peer := 0
	var second_along := -1.0
	for racer in race["racers"] as Array:
		if not (racer is Dictionary) or bool((racer as Dictionary).get("done", false)):
			continue
		var along := float((racer as Dictionary).get("along", 0.0))
		var who := int((racer as Dictionary).get("peer", 0))
		if along >= best_along:
			second_peer = best_peer
			second_along = best_along
			best_peer = who
			best_along = along
		elif along >= second_along:
			second_peer = who
			second_along = along
	if best_peer != owner:
		return best_peer
	return second_peer


func _pie_target(race: Dictionary, owner: int, at: Vector3, nose: Vector3) -> int:
	var flat_nose := Vector3(nose.x, 0.0, nose.z)
	if flat_nose.length_squared() < 0.01:
		return 0
	flat_nose = flat_nose.normalized()
	var best := 0
	var best_d := 120.0
	for racer in race["racers"] as Array:
		if not (racer is Dictionary):
			continue
		var who := int((racer as Dictionary).get("peer", 0))
		if who == owner:
			continue
		var spot := Vector3(float((racer as Dictionary).get("x", 0.0)), 0.0, float((racer as Dictionary).get("z", 0.0)))
		var offset := Vector3(spot.x - at.x, 0.0, spot.z - at.z)
		var dist := offset.length()
		if dist < 0.5 or dist >= best_d:
			continue
		if offset.normalized().dot(flat_nose) < 0.45:
			continue
		best = who
		best_d = dist
	return best


func _push_event(race: Dictionary, gag: int, owner: int, target: int, at: Vector3) -> void:
	_seq += 1
	var events: Array = race["events"]
	events.append({
		"seq": _seq,
		"gag": gag,
		"owner": owner,
		"target": target,
		"x": at.x,
		"y": at.y,
		"z": at.z,
	})
	while events.size() > 12:
		events.pop_front()


func _place_of(race: Dictionary, peer: int) -> int:
	var mine := 0.0
	var found := false
	for racer in race["racers"] as Array:
		if racer is Dictionary and int((racer as Dictionary).get("peer", 0)) == peer:
			mine = float((racer as Dictionary).get("along", 0.0))
			if bool((racer as Dictionary).get("done", false)):
				mine = 1.0e12
			found = true
	if not found:
		return 1
	var place := 1
	for racer in race["racers"] as Array:
		if not (racer is Dictionary) or int((racer as Dictionary).get("peer", 0)) == peer:
			continue
		var along := float((racer as Dictionary).get("along", 0.0))
		if bool((racer as Dictionary).get("done", false)):
			along = 1.0e12
		if along > mine:
			place += 1
	return place


func _race_with(peer: int) -> Dictionary:
	for race in _races:
		if not _racer(race, peer).is_empty():
			return race
	return {}


func _racer(race: Dictionary, peer: int) -> Dictionary:
	for racer in race["racers"] as Array:
		if racer is Dictionary and int((racer as Dictionary).get("peer", 0)) == peer:
			return racer
	return {}


func _find_peer(peer: int) -> Dictionary:
	for pad in _pads:
		for seat in pad["seats"] as Array:
			if int((seat as Dictionary).get("peer", 0)) == peer:
				return seat
	return {}


func _race_for(pad_index: int) -> int:
	for index in _races.size():
		if int((_races[index] as Dictionary).get("pad", -1)) == pad_index:
			return index
	return -1


func _load_pads() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_LAYOUT))
	if not (parsed is Array):
		return
	var current: Dictionary = {}
	for item in parsed as Array:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		var pad_name := String(row.get("name", ""))
		if pad_name.begins_with("racing_pad") or pad_name.begins_with("viewing_pad"):
			var parts := pad_name.split("_")
			var index := 0
			if parts.size() > 2 and pad_name.begins_with("racing"):
				index = int(parts[2])
			var genre_name := ""
			if parts.size() > 3:
				genre_name = parts[3]
			var picked := _RULES.next_track(-1, genre_name, index)
			current = {
				"slot": _pads.size(),
				"index": index,
				"genre": genre_name,
				"viewing": pad_name.begins_with("viewing"),
				"track": int(picked.get("track", 0)),
				"type": int(picked.get("type", 0)),
				"laps": int(picked.get("laps", _RULES.LAPS)),
				"left": _RULES.SIGN_TIME,
				"wait": -1.0,
				"notice": "",
				"notice_left": 0.0,
				"blocks": 0,
				"seats": [],
			}
			_pads.append(current)
		elif pad_name.begins_with("starting_block") and not current.is_empty():
			current["blocks"] = int(current["blocks"]) + 1


func _publish() -> void:
	ToonNet.publish(_CHANNEL, _export())


func _export() -> Dictionary:
	var pads: Array = []
	for pad in _pads:
		var peers: Array = []
		var blocks: Array = []
		var names: Array = []
		var seated: Array = []
		var dna: Array = []
		var styles: Array = []
		for seat in pad["seats"] as Array:
			peers.append(int((seat as Dictionary).get("peer", 0)))
			blocks.append(int((seat as Dictionary).get("block", 0)))
			names.append(String((seat as Dictionary).get("name", "")))
			seated.append(bool((seat as Dictionary).get("seated", false)))
			dna.append((seat as Dictionary).get("dna", []))
			styles.append((seat as Dictionary).get("style", {}))
		pads.append({
			"track": int(pad["track"]),
			"type": int(pad["type"]),
			"laps": int(pad["laps"]),
			"left": float(pad["left"]),
			"wait": float(pad["wait"]),
			"notice": String(pad["notice"]),
			"viewing": bool(pad["viewing"]),
			"peers": peers,
			"blocks": blocks,
			"names": names,
			"seated": seated,
			"dna": dna,
			"styles": styles,
		})
	var races: Array = []
	for race in _races:
		var down: Array = []
		for box in race["down"] as Array:
			down.append(int((box as Dictionary).get("slot", -1)))
		races.append({
			"id": int(race["id"]),
			"pad": int(race["pad"]),
			"track": int(race["track"]),
			"type": int(race["type"]),
			"laps": int(race["laps"]),
			"phase": String(race["phase"]),
			"timer": float(race["timer"]),
			"racers": race["racers"],
			"events": race["events"],
			"down": down,
			"loot": race["loot"],
		})
	return {"pads": pads, "races": races}
