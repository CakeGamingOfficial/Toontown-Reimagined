extends Node

## One Sellbot factory per elevator group. The district server keeps the roster,
## the car, and the shared barrels, crates, doors, and goons. The factory scene
## only draws that record. Two groups in one district do not share cogs.

const SLUG := "sellbot_factory"
const _LIST := "res://assets/cog_hq/sellbot_factory_cogs.json"
const _CATALOG := "res://assets/cogs/catalog.json"
const _SELLBOTS: PackedStringArray = ["cc", "tm", "nd", "gh", "ms", "tf", "m", "mh"]
const _BOARD := 15.0
const _CLOSE := 2.0
const _MAX := 4

var _trips: Dictionary = {}
var _cars: Dictionary = {}
var _exits: Dictionary = {}
var _peer: Dictionary = {}
var _next := 1


func _process(delta: float) -> void:
	if not ToonNet.is_authority():
		return
	var keys: Array = _cars.keys()
	for key in keys:
		_tick(_cars[key], delta, true)
	var outs: Array = _exits.keys()
	for trip in outs:
		_tick(_exits[trip], delta, false)


func ensure(district: int, slug: String = "") -> void:
	if not ToonNet.is_authority():
		return
	var trip := _number(slug)
	if trip <= 0 or not _trips.has(trip):
		return
	_publish_trip(trip)


func rows(district: int, slug: String = "") -> Array:
	var trip := _number(slug)
	if trip <= 0:
		return []
	var info: Dictionary = _trips.get(trip, {})
	if int(info.get("district", district)) != district:
		return []
	var found: Variant = info.get("rows", [])
	if found is Array:
		return found
	return []


func dismiss(district: int, slug: String, cog_id: int) -> void:
	if not ToonNet.is_authority():
		return
	var trip := _number(slug)
	if trip <= 0 or not _trips.has(trip):
		return
	var info: Dictionary = _trips[trip]
	if int(info.get("district", 0)) != district:
		return
	var kept: Array = []
	for item in info.get("rows", []):
		if item is Dictionary and int((item as Dictionary).get("do_id", 0)) == cog_id:
			continue
		kept.append(item)
	info["rows"] = kept
	_publish_suits(trip)


func engage(district: int, cog_id: int, origin: Vector3, yaw: float, peer: int, toon_name: String, hp: int, max_hp: int) -> void:
	var trip := int(_peer.get(peer, 0))
	if trip <= 0 or not _trips.has(trip):
		return
	var lead := _find(trip, cog_id)
	if lead.is_empty():
		return
	var fights := get_node_or_null("../StreetFights")
	if fights == null or not fights.has_method("open_group"):
		return
	var spec: Dictionary = lead.get("cog", {})
	var cell := int(spec.get("cell", 0))
	var group: Array = [_battle_cog(lead, origin)]
	for item in rows(district, _slug(trip)):
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		var cog_spec: Dictionary = row.get("cog", {})
		if int(row.get("do_id", 0)) == cog_id or int(cog_spec.get("cell", -1)) != cell:
			continue
		if group.size() >= 4:
			break
		if fights.has_method("cog_paused") and bool(fights.call("cog_paused", int(row.get("do_id", 0)))):
			continue
		group.append(_battle_cog(row, origin))
	fights.call("open_group", district, _slug(trip), group, peer, toon_name, hp, max_hp, origin, yaw)


func act(peer: int, action: String, payload: Dictionary) -> void:
	if not ToonNet.is_authority() or peer < 0:
		return
	if action == "board":
		_board(peer, payload, true)
	elif action == "hop":
		_hop(peer, payload, true)
	elif action == "exit_board":
		_board(peer, payload, false)
	elif action == "exit_hop":
		_hop(peer, payload, false)
	elif action == "leave":
		_leave(peer)
	elif action == "claim":
		_claim(peer, payload)
	elif action == "barrel":
		_barrel(peer, int(payload.get("id", 0)))
	elif action == "crate":
		_crate(peer, payload)
	elif action == "goons":
		_goons(peer, payload)
	elif action == "goon":
		_goon_dead(peer, int(payload.get("id", 0)))
	elif action == "switch":
		_switch(peer, int(payload.get("kind", 0)), int(payload.get("id", 0)), bool(payload.get("on", false)))


func drop(peer: int) -> void:
	if not ToonNet.is_authority() or peer < 0:
		return
	var car_keys: Array = _cars.keys()
	for key in car_keys:
		if _drop_rider(_cars[key], peer):
			_publish_car(_cars[key])
	var out_keys: Array = _exits.keys()
	for trip in out_keys:
		if _drop_rider(_exits[trip], peer):
			_publish_exit(int(trip))
	var owned := int(_peer.get(peer, 0))
	if owned <= 0 or not _trips.has(owned):
		_peer.erase(peer)
		return
	_peer.erase(peer)
	var info: Dictionary = _trips[owned]
	var kept: Array = []
	for id in info.get("peers", []):
		if int(id) != peer:
			kept.append(int(id))
	info["peers"] = kept
	if kept.is_empty():
		var district := int(info.get("district", 0))
		_trips.erase(owned)
		_exits.erase(owned)
		ToonNet.publish("suits:%d:%s" % [district, _slug(owned)], {"rows": []})
		ToonNet.publish("factory:%d" % owned, {})
		return
	_publish_trip(owned)


func _board(peer: int, payload: Dictionary, into: bool) -> void:
	var district := int(payload.get("district", 1))
	var entrance := int(payload.get("entrance", 0))
	var trip := int(_peer.get(peer, 0))
	if not into:
		var asked := int(payload.get("trip", 0))
		if asked > 0:
			trip = asked
		if trip <= 0 or not _trips.has(trip) or not _riding(trip, peer):
			return
	var car := _car_for(district, entrance, trip, into)
	if String(car.get("state", "")) != "boarding":
		return
	if _riding_car(car, peer) or (car["toons"] as Array).size() >= _MAX:
		return
	(car["toons"] as Array).append({
		"id": peer,
		"name": String(payload.get("name", "Toon")),
		"hp": int(payload.get("hp", 1)),
		"max_hp": int(payload.get("max", 1)),
		"seat": _open_seat(car),
	})
	car["grace"] = 1.0
	car["depart"] = false
	if into:
		_publish_car(car)
	else:
		_publish_exit(trip)


func _hop(peer: int, payload: Dictionary, into: bool) -> void:
	var car: Dictionary = {}
	var trip := 0
	if into:
		var key := _car_key(int(payload.get("district", 1)), int(payload.get("entrance", 0)))
		if not _cars.has(key):
			return
		car = _cars[key]
	else:
		trip = int(_peer.get(peer, 0))
		if trip <= 0 or not _exits.has(trip):
			return
		car = _exits[trip]
	if String(car.get("state", "")) != "boarding":
		return
	if not _drop_rider(car, peer):
		return
	var riders: Array = car.get("toons", [])
	if riders.is_empty():
		_reset_car(car)
	elif not bool(car.get("bailed", false)):
		car["bailed"] = true
		car["left"] = _BOARD
		car["grace"] = 0.0
		car["depart"] = false
	if into:
		_publish_car(car)
	else:
		_publish_exit(int(car.get("trip", trip)))


func _claim(peer: int, payload: Dictionary) -> void:
	var owned := int(_peer.get(peer, 0))
	if owned > 0 and _trips.has(owned):
		_publish_self(peer, owned)
		return
	var district := int(payload.get("district", 1))
	var entrance := int(payload.get("entrance", 0))
	var trip := _open_trip(district, entrance, [peer])
	_publish_self(peer, trip)


func _leave(peer: int) -> void:
	var trip := int(_peer.get(peer, 0))
	if trip <= 0 or not _trips.has(trip):
		return
	var info: Dictionary = _trips[trip]
	var car := _car_for(int(info.get("district", 1)), int(info.get("entrance", 0)), trip, false)
	var riders: Array = []
	var seat := 0
	for id in info.get("peers", []):
		riders.append({
			"id": int(id),
			"name": "Toon",
			"hp": 1,
			"max_hp": 1,
			"seat": seat,
		})
		seat += 1
		if seat >= _MAX:
			break
	car["toons"] = riders
	car["state"] = "depart"
	car["hold"] = 3.0
	car["trip"] = trip
	_publish_exit(trip)
	_release_riders(trip, info.get("peers", []))


func _barrel(peer: int, ent_id: int) -> void:
	var info := _owned(peer)
	if info.is_empty() or ent_id <= 0:
		return
	var taken: Array = info.get("barrels", [])
	for id in taken:
		if int(id) == ent_id:
			return
	taken.append(ent_id)
	info["barrels"] = taken
	_publish_world(int(_peer.get(peer, 0)))


func _crate(peer: int, payload: Dictionary) -> void:
	var info := _owned(peer)
	if info.is_empty():
		return
	var crates: Dictionary = info.get("crates", {})
	crates[str(int(payload.get("id", 0)))] = [
		float(payload.get("x", 0.0)),
		float(payload.get("y", 0.0)),
		float(payload.get("z", 0.0)),
	]
	info["crates"] = crates
	_publish_world(int(_peer.get(peer, 0)))


func _goons(peer: int, payload: Dictionary) -> void:
	var trip := int(_peer.get(peer, 0))
	var info := _owned(peer)
	if info.is_empty() or peer != _lowest(info):
		return
	var rows: Array = []
	for item in payload.get("rows", []):
		if item is Dictionary:
			rows.append(item)
	info["goons"] = rows
	_publish_world(trip)


func _goon_dead(peer: int, ent_id: int) -> void:
	var trip := int(_peer.get(peer, 0))
	var info := _owned(peer)
	if info.is_empty() or ent_id <= 0 or peer != _lowest(info):
		return
	var dead: Array = info.get("dead", [])
	for id in dead:
		if int(id) == ent_id:
			return
	dead.append(ent_id)
	info["dead"] = dead
	_publish_world(trip)


func _switch(peer: int, kind: int, ent_id: int, on: bool) -> void:
	var trip := int(_peer.get(peer, 0))
	var info := _owned(peer)
	if info.is_empty() or ent_id <= 0:
		return
	var rows: Array = info.get("switches", [])
	var next: Array = []
	var wrote := false
	for item in rows:
		if item is Dictionary and int((item as Dictionary).get("kind", -1)) == kind and int((item as Dictionary).get("id", 0)) == ent_id:
			next.append({"kind": kind, "id": ent_id, "on": on})
			wrote = true
		else:
			next.append(item)
	if not wrote:
		next.append({"kind": kind, "id": ent_id, "on": on})
	info["switches"] = next
	_publish_world(trip)


func _tick(car: Dictionary, delta: float, into: bool) -> void:
	var state := String(car.get("state", ""))
	if state == "depart":
		car["hold"] = maxf(float(car.get("hold", 0.0)) - delta, 0.0)
		if float(car["hold"]) <= 0.0:
			_reset_car(car)
			if into:
				_publish_car(car)
			else:
				_publish_exit(int(car.get("trip", 0)))
		return
	if (car["toons"] as Array).is_empty():
		return
	if state == "boarding":
		car["grace"] = maxf(float(car.get("grace", 0.0)) - delta, 0.0)
	car["left"] = maxf(float(car.get("left", 0.0)) - delta, 0.0)
	if float(car["left"]) > 0.0:
		car["sent"] = float(car.get("sent", 0.0)) + delta
		if float(car["sent"]) < 0.15:
			return
		car["sent"] = 0.0
		if into:
			_publish_car(car)
		else:
			_publish_exit(int(car.get("trip", 0)))
		return
	if state == "boarding":
		var grace := float(car.get("grace", 0.0))
		if grace > 0.0 and not bool(car.get("depart", false)):
			car["depart"] = true
			car["left"] = grace
			car["grace"] = 0.0
			if into:
				_publish_car(car)
			else:
				_publish_exit(int(car.get("trip", 0)))
			return
		car["state"] = "closing"
		car["depart"] = false
		car["left"] = _CLOSE
	elif state == "closing":
		if into and int(car.get("trip", 0)) <= 0:
			car["trip"] = _open_trip(int(car.get("district", 1)), int(car.get("entrance", 0)), _ids(car))
		elif not into:
			_release_riders(int(car.get("trip", 0)), _ids(car))
		car["state"] = "depart"
		car["hold"] = 3.0
	if into:
		_publish_car(car)
	else:
		_publish_exit(int(car.get("trip", 0)))


func _open_trip(district: int, entrance: int, peers: Array) -> int:
	var trip := _next
	_next += 1
	var riders: Array = []
	var who := 0
	for id in peers:
		who = int(id)
		if who <= 0:
			continue
		riders.append(who)
		_peer[who] = trip
	_trips[trip] = {
		"district": district,
		"entrance": entrance,
		"peers": riders,
		"rows": _roll_factory(trip, riders.size()),
		"barrels": [],
		"crates": {},
		"goons": [],
		"dead": [],
		"switches": [],
	}
	_publish_trip(trip)
	for id in riders:
		_publish_self(int(id), trip)
	return trip


func _release_riders(trip: int, leaving: Array) -> void:
	var info: Dictionary = _trips.get(trip, {})
	if info.is_empty():
		return
	var gone := {}
	for id in leaving:
		var who := int(id)
		gone[who] = true
		if int(_peer.get(who, 0)) == trip:
			_peer.erase(who)
	var kept: Array = []
	for id in info.get("peers", []):
		if not gone.has(int(id)):
			kept.append(int(id))
	info["peers"] = kept
	if not kept.is_empty():
		_publish_world(trip)
		return
	var district := int(info.get("district", 0))
	_trips.erase(trip)
	ToonNet.publish("suits:%d:%s" % [district, _slug(trip)], {"rows": []})
	ToonNet.publish("factory:%d" % trip, {})


func _car_for(district: int, entrance: int, trip: int, into: bool) -> Dictionary:
	var made := {}
	if into:
		var key := _car_key(district, entrance)
		if not _cars.has(key):
			made = _fresh(district, entrance, 0)
			made["into"] = true
			_cars[key] = made
		return _cars[key]
	if not _exits.has(trip):
		var info: Dictionary = _trips.get(trip, {})
		made = _fresh(int(info.get("district", district)), int(info.get("entrance", entrance)), trip)
		made["into"] = false
		_exits[trip] = made
	return _exits[trip]


func _fresh(district: int, entrance: int, trip: int) -> Dictionary:
	return {
		"district": district,
		"entrance": entrance,
		"trip": trip,
		"state": "boarding",
		"left": _BOARD,
		"grace": 1.0,
		"depart": false,
		"bailed": false,
		"hold": 0.0,
		"toons": [],
	}


func _reset_car(car: Dictionary) -> void:
	car["state"] = "boarding"
	car["left"] = _BOARD
	car["grace"] = 1.0
	car["depart"] = false
	car["bailed"] = false
	car["hold"] = 0.0
	car["toons"] = []
	if bool(car.get("into", false)):
		car["trip"] = 0


func _drop_rider(car: Dictionary, peer: int) -> bool:
	var kept: Array = []
	var found := false
	for item in car.get("toons", []):
		if item is Dictionary and int((item as Dictionary).get("id", 0)) == peer:
			found = true
			continue
		kept.append(item)
	if found:
		car["toons"] = kept
	return found


func _riding_car(car: Dictionary, peer: int) -> bool:
	for item in car.get("toons", []):
		if item is Dictionary and int((item as Dictionary).get("id", 0)) == peer:
			return true
	return false


func _riding(trip: int, peer: int) -> bool:
	var info: Dictionary = _trips.get(trip, {})
	for id in info.get("peers", []):
		if int(id) == peer:
			return true
	return false


func _owned(peer: int) -> Dictionary:
	var trip := int(_peer.get(peer, 0))
	if trip <= 0:
		return {}
	var info: Variant = _trips.get(trip, {})
	if info is Dictionary:
		return info
	return {}


func _ids(car: Dictionary) -> Array:
	var peers: Array = []
	for item in car.get("toons", []):
		if item is Dictionary:
			peers.append(int((item as Dictionary).get("id", 0)))
	return peers


func _open_seat(car: Dictionary) -> int:
	var used := {}
	for item in car.get("toons", []):
		if item is Dictionary:
			used[int((item as Dictionary).get("seat", 0))] = true
	for index in _MAX:
		if not used.has(index):
			return index
	return 0


func _lowest(info: Dictionary) -> int:
	var low := 0
	for id in info.get("peers", []):
		var who := int(id)
		if who <= 0:
			continue
		if low == 0 or who < low:
			low = who
	return low


func _publish_car(car: Dictionary) -> void:
	ToonNet.publish(_car_key(int(car.get("district", 1)), int(car.get("entrance", 0))), _packed(car))


func _publish_exit(trip: int) -> void:
	if trip <= 0 or not _exits.has(trip):
		return
	ToonNet.publish("factory-out:%d" % trip, _packed(_exits[trip]))


func _packed(car: Dictionary) -> Dictionary:
	var shown := String(car.get("state", "boarding"))
	if shown == "boarding":
		shown = "open"
	return {
		"state": shown,
		"left": float(car.get("left", 0.0)),
		"toons": car.get("toons", []),
		"trip": int(car.get("trip", 0)),
		"entrance": int(car.get("entrance", 0)),
	}


func _publish_trip(trip: int) -> void:
	_publish_suits(trip)
	_publish_world(trip)


func _publish_suits(trip: int) -> void:
	var info: Dictionary = _trips.get(trip, {})
	if info.is_empty():
		return
	ToonNet.publish("suits:%d:%s" % [int(info.get("district", 1)), _slug(trip)], {"rows": info.get("rows", [])})


func _publish_world(trip: int) -> void:
	var info: Dictionary = _trips.get(trip, {})
	if info.is_empty():
		return
	ToonNet.publish("factory:%d" % trip, {
		"peers": info.get("peers", []),
		"barrels": info.get("barrels", []),
		"crates": info.get("crates", {}),
		"goons": info.get("goons", []),
		"dead": info.get("dead", []),
		"switches": info.get("switches", []),
		"entrance": int(info.get("entrance", 0)),
	})


func _publish_self(peer: int, trip: int) -> void:
	var info: Dictionary = _trips.get(trip, {})
	ToonNet.publish("factory-self:%d" % peer, {
		"trip": trip,
		"entrance": int(info.get("entrance", 0)),
	})


func _car_key(district: int, entrance: int) -> String:
	return "factory-car:%d:%d" % [district, entrance]


func _slug(trip: int) -> String:
	return "%s:%d" % [SLUG, trip]


func _number(slug: String) -> int:
	var at := slug.rfind(":")
	if at < 0:
		return 0
	return int(slug.substr(at + 1))


func _find(trip: int, cog_id: int) -> Dictionary:
	var info: Dictionary = _trips.get(trip, {})
	for item in info.get("rows", []):
		if item is Dictionary and int((item as Dictionary).get("do_id", 0)) == cog_id:
			return item
	return {}


func _battle_cog(row: Dictionary, origin: Vector3) -> Dictionary:
	var spec: Dictionary = row.get("cog", {})
	return {
		"id": int(row.get("do_id", 0)),
		"code": String(spec.get("code", "")),
		"name": String(spec.get("name", "Cog")),
		"level": int(spec.get("level", 1)),
		"dept": String(spec.get("dept", "s")),
		"body": String(spec.get("body", "c")),
		"height": float(spec.get("height", 4.0)),
		"skeleton": bool(spec.get("skeleton", false)),
		"boss": bool(spec.get("boss", false)),
		"pos": [origin.x, origin.y, origin.z],
	}


func _roll_factory(trip: int, toons: int) -> Array:
	var catalog := _read_json(_CATALOG)
	var data := _read_json(_LIST)
	var by_code := {}
	for item in catalog.get("cogs", []):
		if item is Dictionary:
			by_code[str((item as Dictionary)["code"])] = item
	var roster: Array = []
	var next_id := trip * 200 + 1
	for item in data.get("cogs", []):
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item
		var suit := _suit(by_code, int(spec.get("level", 1)), int(spec.get("skeleton", 0)) == 1)
		if suit.is_empty():
			continue
		suit["level"] = preload("res://scenes/cog_hq/party_scale.gd").level(int(suit.get("level", 1)), toons)
		suit["parent"] = int(spec.get("parent", 0))
		suit["pos"] = spec.get("pos", [0.0, 0.0, 0.0])
		suit["h"] = float(spec.get("h", 0.0))
		suit["behavior"] = str(spec.get("behavior", "walk"))
		suit["path"] = int(spec.get("path", 0))
		suit["cell"] = int(spec.get("cell", 0))
		suit["boss"] = int(spec.get("boss", 0)) == 1
		roster.append({
			"do_id": next_id,
			"phase": 1,
			"position": [0.0, 0.0, 0.0],
			"yaw": 0.0,
			"cog": suit,
		})
		next_id += 1
	return roster


func _suit(by_code: Dictionary, level: int, skeleton: bool) -> Dictionary:
	var low := maxi(level - 4, 1)
	var high := mini(level, 8)
	if high < low:
		high = low
	var code := _SELLBOTS[randi_range(low, high) - 1]
	var row: Variant = by_code.get(code)
	if not (row is Dictionary):
		return {}
	var source: Dictionary = row
	var body := str(source.get("body", "c"))
	var suit := {
		"code": code,
		"name": str(source.get("name", "Cog")),
		"dept": "s",
		"body": body,
		"height": float(source.get("height", 4.0)),
		"level": level,
	}
	if not skeleton:
		return suit
	suit["name"] = "Skelecog"
	suit["skeleton"] = true
	var model := "res://assets/cogs/suits/robot_%s.glb" % body
	var walk := "res://assets/cogs/anims/robot_%s/walk.walk" % body
	var neutral := "res://assets/cogs/anims/robot_%s/neutral.walk" % body
	if FileAccess.file_exists(model) and FileAccess.file_exists(walk) and FileAccess.file_exists(neutral):
		suit["model"] = model
		suit["walk"] = walk
		suit["neutral"] = neutral
		suit["scale"] = float(source.get("scale", 1.0))
	return suit


func _read_json(path: String) -> Dictionary:
	if path.ends_with("cogs/catalog.json"):
		return CogCatalog.data()
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}
