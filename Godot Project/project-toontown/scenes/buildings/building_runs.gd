class_name BuildingRuns
extends Node

## DistributedSuitInterior for a street cog building. The district owns who
## boarded, which floor they are on, and when the shop is taken back.
## Clients only play the elevator and the floor.

const BOARD_TIME := 15.0
const CLOSE_TIME := 2.0
## getRideElevatorInterval is 4 seconds, then the doors take openTime.
const RIDE_TIME := 6.0
const MAX_TOONS := 4
## SuitBuildingGlobals.SuitBuildingInfo, street buildings only (index is difficulty).
const _BLDG: Array = [
	{"suit_min": 1, "suit_max": 3, "boss_min": 4, "boss_max": 4, "pool_min": 8, "pool_max": 10, "mult": [1.0]},
	{"suit_min": 2, "suit_max": 4, "boss_min": 5, "boss_max": 5, "pool_min": 8, "pool_max": 10, "mult": [1.0, 1.2]},
	{"suit_min": 3, "suit_max": 5, "boss_min": 6, "boss_max": 6, "pool_min": 8, "pool_max": 10, "mult": [1.0, 1.3, 1.6]},
	{"suit_min": 4, "suit_max": 6, "boss_min": 7, "boss_max": 7, "pool_min": 8, "pool_max": 10, "mult": [1.0, 1.4, 1.8]},
	{"suit_min": 5, "suit_max": 7, "boss_min": 8, "boss_max": 8, "pool_min": 8, "pool_max": 10, "mult": [1.0, 1.6, 1.8, 2.0]},
	{"suit_min": 6, "suit_max": 8, "boss_min": 9, "boss_max": 9, "pool_min": 10, "pool_max": 12, "mult": [1.0, 1.6, 2.0, 2.4]},
	{"suit_min": 7, "suit_max": 9, "boss_min": 10, "boss_max": 10, "pool_min": 10, "pool_max": 14, "mult": [1.0, 1.6, 1.8, 2.2, 2.4]},
	{"suit_min": 8, "suit_max": 10, "boss_min": 11, "boss_max": 11, "pool_min": 12, "pool_max": 16, "mult": [1.0, 1.8, 2.4, 3.0, 3.2]},
	{"suit_min": 9, "suit_max": 11, "boss_min": 12, "boss_max": 12, "pool_min": 14, "pool_max": 20, "mult": [1.4, 1.8, 2.6, 3.4, 4.0]},
]

var _runs: Array = []
var _next := 1
var _catalog: Array = []
var _dirty: Dictionary = {}
var _wait := 0.0


static func room_origin(block: int) -> Vector3:
	return Vector3(120.0 + float(block) * 36.0, 320.0, 40.0)


## Floor 0 is suit_interior, the top floor is the boss office, and the
## floors between are the cubicle hall. Those models are the original rooms.
static func room_kind(floor: int, floors: int) -> String:
	if floor <= 0:
		return "lobby"
	if floor + 1 >= maxi(floors, 1):
		return "office"
	return "hall"


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cogs/catalog.json"))
	if parsed is Dictionary:
		var rows: Variant = (parsed as Dictionary).get("cogs", [])
		if rows is Array:
			_catalog = rows


func _process(delta: float) -> void:
	if not ToonNet.is_authority():
		return
	for item in _runs:
		_tick(item, delta)
	var kept: Array = []
	for item in _runs:
		var run: Dictionary = item
		if String(run.get("state", "")) == "gone":
			_dirty[_key(run)] = true
			continue
		kept.append(run)
	_runs = kept
	_wait -= delta
	if _dirty.is_empty() or _wait > 0.0:
		return
	_wait = 0.4
	for key in _dirty.keys():
		_publish(String(key))
	_dirty.clear()


func board(district: int, slug: String, block: int, peer: int, toon_name: String, hp: int, max_hp: int) -> void:
	if not ToonNet.is_authority() or peer < 0 or block == 0:
		return
	var building := _building(district, slug, block)
	if building.is_empty() or String(building.get("state", "")) == "clearing":
		return
	var run := _run_for(district, slug, block)
	if run.is_empty():
		run = {
			"id": _next,
			"district": district,
			"slug": slug,
			"block": block,
			"track": String(building.get("track", "c")),
			"difficulty": int(building.get("difficulty", 0)),
			"floors": maxi(int(building.get("floors", 1)), 1),
			"title": String(building.get("title", "")),
			"floor": 0,
			"room": "lobby",
			"state": "boarding",
			"left": BOARD_TIME,
			## acceptExiter resets the clock once. depart holds the doors for the walk-in.
			"grace": 1.0,
			"depart": false,
			"bailed": false,
			"toons": [],
			"cogs": [],
			"fight": 0,
			"exit": [0.0, 0.0, 0.0],
		}
		var traffic := _traffic()
		if traffic != null and traffic.has_method("block_pos"):
			var pos: Variant = traffic.call("block_pos", district, slug, block)
			if pos is Array:
				run["exit"] = pos
		_next += 1
		_runs.append(run)
	elif String(run.get("state", "")) != "boarding" or bool(run.get("depart", false)):
		return
	if _has(run, peer) or (run["toons"] as Array).size() >= MAX_TOONS:
		return
	(run["toons"] as Array).append({
		"id": peer,
		"name": toon_name,
		"hp": hp,
		"max_hp": max_hp,
		"seat": _open_seat(run),
	})
	## The last boarder gets TOON_BOARD_ELEVATOR_TIME before the doors close.
	run["grace"] = 1.0
	run["depart"] = false
	_mark(run)


## DistributedElevatorExtAI.acceptExiter. The first hop restarts the countdown.
func hop(district: int, slug: String, block: int, peer: int) -> void:
	if not ToonNet.is_authority() or peer < 0 or block == 0:
		return
	var run := _run_for(district, slug, block)
	if run.is_empty():
		return
	if String(run.get("state", "")) != "boarding" or bool(run.get("depart", false)):
		return
	var kept: Array = []
	var found := false
	for item in run.get("toons", []):
		if item is Dictionary and int((item as Dictionary).get("id", 0)) == peer:
			found = true
			continue
		kept.append(item)
	if not found:
		return
	run["toons"] = kept
	if kept.is_empty():
		run["state"] = "gone"
	elif not bool(run.get("bailed", false)):
		run["bailed"] = true
		run["left"] = BOARD_TIME
		run["grace"] = 0.0
		run["depart"] = false
	_mark(run)


func _tick(run: Dictionary, delta: float) -> void:
	var state := String(run.get("state", ""))
	if state == "gone" or state == "":
		return
	_drop_missing(run)
	if (run["toons"] as Array).is_empty():
		run["state"] = "gone"
		_mark(run)
		return
	if state == "battle":
		var fights := get_node_or_null("../StreetFights")
		var status := "gone"
		if fights != null and fights.has_method("state_of"):
			status = String(fights.call("state_of", int(run.get("fight", 0))))
		if status != "gone":
			_copy_hp(run)
		else:
			_after_floor(run)
		return
	if state == "boarding":
		run["grace"] = maxf(float(run.get("grace", 0.0)) - delta, 0.0)
	run["left"] = maxf(float(run.get("left", 0.0)) - delta, 0.0)
	if float(run["left"]) > 0.0:
		## The clock and the door slide read left every frame.
		_mark(run)
		return
	if state == "boarding":
		var grace := float(run.get("grace", 0.0))
		if grace > 0.0 and not bool(run.get("depart", false)):
			run["depart"] = true
			run["left"] = grace
			run["grace"] = 0.0
			_mark(run)
			return
		run["state"] = "closing"
		run["depart"] = false
		run["left"] = CLOSE_TIME
	elif state == "closing":
		run["state"] = "riding"
		run["left"] = RIDE_TIME
	elif state == "riding":
		_begin_floor(run)
	elif state == "victory" or state == "failed":
		run["state"] = "gone"
	_mark(run)


func _begin_floor(run: Dictionary) -> void:
	var plan := _floor_cogs(run)
	var cogs: Array = plan.get("active", [])
	if cogs.is_empty():
		run["state"] = "failed"
		run["left"] = 2.0
		_mark(run)
		return
	run["cogs"] = cogs
	run["room"] = String(plan.get("room", "lobby"))
	var fights := get_node_or_null("../StreetFights")
	var origin := room_origin(int(run.get("block", 0)))
	var fight_id := 0
	if fights != null and fights.has_method("open_roster"):
		fight_id = int(fights.call(
			"open_roster",
			int(run.get("district", 0)),
			String(run.get("slug", "")),
			cogs,
			plan.get("reserves", []),
			run.get("toons", []),
			origin,
			0.0,
			int(run.get("block", 0)),
			plan.get("out", [origin.x, origin.y, origin.z])
		))
	if fight_id == 0:
		run["state"] = "failed"
		run["left"] = 2.0
		_mark(run)
		return
	run["fight"] = fight_id
	run["state"] = "battle"
	run["left"] = 0.0
	_mark(run)


func _after_floor(run: Dictionary) -> void:
	var alive := false
	for item in run.get("toons", []):
		if item is Dictionary and int((item as Dictionary).get("hp", 0)) > 0:
			alive = true
	if not alive:
		run["state"] = "failed"
		run["left"] = 2.0
		_mark(run)
		return
	var floor := int(run.get("floor", 0)) + 1
	if floor >= int(run.get("floors", 1)):
		var traffic := _traffic()
		if traffic != null and traffic.has_method("retake_building"):
			traffic.call("retake_building", int(run.get("district", 0)), String(run.get("slug", "")), int(run.get("block", 0)))
		run["state"] = "victory"
		run["left"] = 4.0
		run["cogs"] = []
		_mark(run)
		return
	run["floor"] = floor
	run["room"] = room_kind(floor, int(run.get("floors", 1)))
	run["cogs"] = []
	run["fight"] = 0
	run["state"] = "riding"
	run["left"] = RIDE_TIME
	_mark(run)


func _floor_cogs(run: Dictionary) -> Dictionary:
	var info: Dictionary = _BLDG[clampi(int(run.get("difficulty", 0)), 0, _BLDG.size() - 1)]
	var mults: Array = info.get("mult", [1.0])
	var floor := int(run.get("floor", 0))
	var mult := float(mults[mini(floor, mults.size() - 1)])
	var pool := randi_range(int(float(info["pool_min"]) * mult), int(float(info["pool_max"]) * mult))
	var suit_min := int(info["suit_min"])
	var suit_max := int(info["suit_max"])
	var levels: Array = []
	while pool >= suit_min and levels.size() < 8:
		var picked := randi_range(suit_min, mini(pool, suit_max))
		levels.append(picked)
		pool -= picked
	var top := floor + 1 >= int(run.get("floors", 1))
	if top:
		levels.append(randi_range(int(info["boss_min"]), int(info["boss_max"])))
	levels.sort()
	var num_active := randi_range(1, mini(4, levels.size()))
	if top and levels.size() > 1:
		var boss_at := levels.size() - 1
		var spot := 0 if num_active == 1 else maxi(num_active - 2, 0)
		var swapped: Variant = levels[spot]
		levels[spot] = levels[boss_at]
		levels[boss_at] = swapped
	var active_levels: Array = []
	for index in range(num_active - 1, -1, -1):
		active_levels.append(levels[index])
	var reserve_levels: Array = []
	for index in range(num_active, levels.size()):
		reserve_levels.append(levels[index])
	var chances: Array = []
	for _index in reserve_levels.size():
		chances.append(randi_range(1, 100))
	chances.sort()
	var kind := room_kind(floor, int(run.get("floors", 1)))
	var origin := room_origin(int(run.get("block", 0)))
	var active: Array = []
	for index in active_levels.size():
		var made := _suit(run, int(active_levels[index]), index, _stand(origin, kind, index), floor)
		if not made.is_empty():
			active.append(made)
	var reserves: Array = []
	for index in reserve_levels.size():
		var made := _suit(run, int(reserve_levels[index]), active.size() + index, _out_seat(origin, kind, index), floor)
		if made.is_empty():
			continue
		made["join"] = int(chances[index])
		reserves.append(made)
	var out := origin + Vector3(0.0, 0.0, -_room_depth(kind))
	return {"active": active, "reserves": reserves, "room": kind, "out": [out.x, out.y, out.z]}


func _suit(run: Dictionary, level: int, index: int, spot: Vector3, floor: int) -> Dictionary:
	var cog := _pick_cog(String(run.get("track", "c")), level)
	if cog.is_empty():
		return {}
	return {
		"id": 700000 + int(run.get("block", 0)) * 16 + floor * 8 + index,
		"code": String(cog.get("code", "f")),
		"name": String(cog.get("name", "Cog")),
		"dept": String(cog.get("dept", "c")),
		"body": String(cog.get("body", "c")),
		"height": float(cog.get("height", 4.0)),
		"level": level,
		"pos": [spot.x, spot.y, spot.z],
	}


func _stand(origin: Vector3, kind: String, index: int) -> Vector3:
	var spots: Array[Vector3] = [
		Vector3(0.0, 0.0, -15.0), Vector3(10.0, 0.0, -20.0),
		Vector3(-7.0, 0.0, -24.0), Vector3(-10.0, 0.0, 0.0),
	]
	if kind == "hall":
		spots = [
			Vector3(0.0, 0.0, -18.0), Vector3(10.0, 0.0, -12.0),
			Vector3(-9.0, 0.0, -11.0), Vector3(-3.0, 0.0, -13.0),
		]
	elif kind == "office":
		spots = [
			Vector3(0.0, 0.0, -15.0), Vector3(10.0, 0.0, -20.0),
			Vector3(-10.0, 0.0, -6.0), Vector3(-17.0, 11.0, -34.0),
		]
	return origin + spots[mini(index, spots.size() - 1)]


func _out_seat(origin: Vector3, kind: String, index: int) -> Vector3:
	var seats: Array[Vector3] = [
		Vector3(-1.5, 0.1, -5.0), Vector3(1.5, 0.1, -5.0),
		Vector3(-2.5, 0.1, -3.0), Vector3(2.5, 0.1, -3.0),
	]
	return origin + Vector3(0.0, 0.0, -_room_depth(kind)) + seats[index % seats.size()]


func _room_depth(kind: String) -> float:
	if kind == "hall":
		return 40.0
	if kind == "office":
		return 37.5
	return 30.0


func _pick_cog(dept: String, level: int) -> Dictionary:
	var fits: Array = []
	var same: Array = []
	for item in _catalog:
		if not (item is Dictionary):
			continue
		var cog: Dictionary = item
		if String(cog.get("dept", "")) != dept:
			continue
		same.append(cog)
		var type := int(cog.get("type", 1))
		if level >= type and level <= type + 4:
			fits.append(cog)
	var pool: Array = fits if not fits.is_empty() else same
	if pool.is_empty():
		return {}
	return pool[randi() % pool.size()]


func _copy_hp(run: Dictionary) -> void:
	var fights := get_node_or_null("../StreetFights")
	if fights == null or not fights.has_method("toon_hp"):
		return
	for item in run.get("toons", []):
		if not (item is Dictionary):
			continue
		var toon: Dictionary = item
		var hp := int(fights.call("toon_hp", int(run.get("fight", 0)), int(toon.get("id", 0))))
		if hp >= 0:
			toon["hp"] = hp


func _drop_missing(run: Dictionary) -> void:
	if not ToonNet.networked():
		return
	var here: Array = [1]
	if multiplayer.multiplayer_peer != null:
		for peer in multiplayer.get_peers():
			here.append(int(peer))
		here.append(multiplayer.get_unique_id())
	var kept: Array = []
	var changed := false
	for item in run.get("toons", []):
		var toon: Dictionary = item
		if here.has(int(toon.get("id", 0))):
			kept.append(toon)
		else:
			changed = true
	if changed:
		run["toons"] = kept
		_mark(run)


func _building(district: int, slug: String, block: int) -> Dictionary:
	var traffic := _traffic()
	if traffic == null or not traffic.has_method("building_rows"):
		return {}
	for item in traffic.call("building_rows", district, slug):
		if item is Dictionary and int((item as Dictionary).get("block", 0)) == block:
			return item
	return {}


func occupied(district: int, slug: String, block: int) -> bool:
	if _busy(_run_for(district, slug, block)):
		return true
	var snap := ToonNet.latest("runs:%d:%s" % [district, slug])
	var raw: Variant = snap.get("rows", [])
	if not (raw is Array):
		return false
	for item in raw:
		if not (item is Dictionary):
			continue
		var run: Dictionary = item
		if int(run.get("block", 0)) == block and _busy(run):
			return true
	return false


func _busy(run: Dictionary) -> bool:
	if run.is_empty():
		return false
	var state := String(run.get("state", ""))
	return state != "" and state != "victory" and state != "failed" and state != "gone"


func _run_for(district: int, slug: String, block: int) -> Dictionary:
	for item in _runs:
		var run: Dictionary = item
		if int(run.get("district", -1)) == district and String(run.get("slug", "")) == slug and int(run.get("block", 0)) == block and String(run.get("state", "")) != "gone":
			return run
	return {}


func _open_seat(run: Dictionary) -> int:
	var used := {}
	var index := 0
	for item in run.get("toons", []):
		if item is Dictionary and (item as Dictionary).has("seat"):
			used[int((item as Dictionary).get("seat", index))] = true
		else:
			used[index] = true
		index += 1
	for seat in MAX_TOONS:
		if not used.has(seat):
			return seat
	return index


func _has(run: Dictionary, peer: int) -> bool:
	for item in run.get("toons", []):
		if item is Dictionary and int((item as Dictionary).get("id", 0)) == peer:
			return true
	return false


func _traffic() -> Node:
	return get_parent()


func _key(run: Dictionary) -> String:
	return "%d:%s" % [int(run.get("district", 0)), String(run.get("slug", ""))]


func _mark(run: Dictionary) -> void:
	_dirty[_key(run)] = true
	_wait = 0.0


func _publish(key: String) -> void:
	var rows: Array = []
	var parts := key.split(":", false, 1)
	if parts.size() < 2:
		return
	var district := int(parts[0])
	var slug := parts[1]
	for item in _runs:
		var run: Dictionary = item
		if int(run.get("district", -1)) == district and String(run.get("slug", "")) == slug and String(run.get("state", "")) != "gone":
			rows.append(run)
	ToonNet.publish("runs:" + key, {"rows": rows})
