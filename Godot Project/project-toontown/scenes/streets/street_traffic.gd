extends Node

## Street suits keep walking after you leave. Entering a shop or another
## street unloads the block, and this holds the population until you come back.

const WALK_SPEED := 4.8
const FROM_SKY := 6.5
const SKY_HEIGHT := FROM_SKY * WALK_SPEED
const TOTAL_MAX_SUITS := 50
## clearOutToonInterior, then the drop starts. The cog is already inside.
const _CLEAR_OUT := 4.0
const _DEPTS: PackedStringArray = ["c", "l", "m", "s"]
const _BUILDINGS := preload("res://scenes/streets/street_buildings.gd")
const _HOLIDAYS := preload("res://scenes/shticker/calendar_holidays.gd")

var _streets: Dictionary = {}
var _blocks: Dictionary = {}
var _plans: Dictionary = {}
var _pending: Dictionary = {}
var _doors: Dictionary = {}
var _actors: Dictionary = {}
## A street the local scene is showing. The data sim must not plan that one too.
var _live: Dictionary = {}
const _STATE_PATH := "user://street_state.json"
var _remembered := false
var _dirty := false
var _save_wait := 2.0
## Set while the Reload button is putting the same suits back. The street
## that is closing must not park an empty roster over them.
var _keep_spawns := false


func _ready() -> void:
	var pool := Node3D.new()
	pool.name = "CogPool"
	add_child(pool)
	var sim := Node.new()
	sim.name = "SuitSim"
	add_child(sim)
	var buildings := Node.new()
	buildings.name = "BuildingSim"
	add_child(buildings)
	var fights: Node = load("res://scenes/battle/street_fights.gd").new()
	fights.name = "StreetFights"
	add_child(fights)
	var factory: Node = load("res://scenes/cog_hq/factory_board.gd").new()
	factory.name = "FactoryBoard"
	add_child(factory)
	var runs: Node = load("res://scenes/buildings/building_runs.gd").new()
	runs.name = "BuildingRuns"
	add_child(runs)


## Parked suits in one district. The live street adds the suits it is drawing.
func suit_total(district: int = -1) -> int:
	var want := district
	if want < 0:
		want = ToonNet.district_id()
	var total := 0
	for key in _streets:
		if _district_of(String(key)) != want:
			continue
		var record: Dictionary = _streets[key]
		var cogs: Array = record.get("cogs", [])
		total += cogs.size()
	return total


func keep_actor(code: String, suit: Node) -> void:
	if suit == null or not is_instance_valid(suit) or code.is_empty():
		return
	var held := 0
	for key in _actors:
		var list: Array = _actors[key]
		held += list.size()
	if held >= TOTAL_MAX_SUITS:
		suit.queue_free()
		return
	var waiting: Array = _actors.get(code, [])
	waiting.append(suit)
	_actors[code] = waiting
	var holder := get_node_or_null("CogPool")
	if holder != null and suit.get_parent() != holder:
		if suit.is_inside_tree():
			suit.reparent(holder)
		else:
			if suit.get_parent() != null:
				suit.get_parent().remove_child(suit)
			holder.add_child(suit)


func take_actor(code: String) -> Node:
	var waiting: Array = _actors.get(code, [])
	if waiting.is_empty():
		return null
	var suit: Variant = waiting.pop_back()
	_actors[code] = waiting
	if suit is Node and is_instance_valid(suit):
		var node := suit as Node
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		return node
	return null


func hold(district: int, slug: String, record: Dictionary) -> void:
	if _keep_spawns or slug.is_empty():
		return
	remember_state()
	var key := _key(district, slug)
	record["district"] = district
	record["slug"] = slug
	_live.erase(key)
	_streets[key] = record
	_touch()


func claim(district: int, slug: String) -> Dictionary:
	_keep_spawns = false
	remember_state()
	var key := _key(district, slug)
	_live[key] = true
	if not _streets.has(key):
		return {}
	var record: Dictionary = _streets[key]
	_streets.erase(key)
	return record


## doSummonSingleCog. The live street draws it. Any other street keeps the
## suit in the parked record so the players standing there can play it.
func summon(district: int, slug: String, query: String, level: int, near: Vector3) -> void:
	if not ToonNet.is_authority() or slug.is_empty():
		return
	var scene := get_tree().current_scene
	if scene != null:
		var live := scene.get_node_or_null("StreetSuits")
		if live != null and bool(live.get("visuals")) and String(live.get("street_slug")) == slug and int(live.get("district_id")) == district:
			live.call("summon_named", query, level, near)
			return
	var key := _key(district, slug)
	if not _streets.has(key):
		ensure(district, slug)
	if not _streets.has(key):
		return
	var record: Dictionary = _streets[key]
	var parsed := StreetSuits.parse_summon(query)
	if String(parsed.get("conflict", "")) != "":
		return
	var cog := StreetSuits.match_cog(record.get("catalog", []), String(parsed["name"]))
	if cog.is_empty():
		return
	if bool(parsed.get("waiter", false)) and String(cog.get("dept", "")) != "c":
		return
	StreetSuits.dress_summon(cog, parsed)
	var cog_type := int(cog.get("type", 1))
	var rolled := cog_type
	var levels: Array = record.get("levels", [])
	if level > 0:
		rolled = level
	elif not levels.is_empty():
		rolled = int(levels[randi() % levels.size()])
	cog["level"] = clampi(rolled, cog_type, cog_type + 4)
	var route: PackedInt32Array = record.get("route", PackedInt32Array())
	var points: Array = record.get("points", [])
	if route.size() < 2:
		return
	inject_suit(district, slug, cog, _nearest_slot(points, route, near))


func inject_suit(district: int, slug: String, cog: Dictionary, slot: int) -> void:
	var key := _key(district, slug)
	if not _streets.has(key):
		return
	var record: Dictionary = _streets[key]
	var points: Array = record.get("points", [])
	var route: PackedInt32Array = record.get("route", PackedInt32Array())
	if route.is_empty() or slot < 0 or slot >= route.size():
		return
	var ground := _point_at(points, route[slot])
	var cogs: Array = record.get("cogs", [])
	var net_id := int(cog.get("do_id", 0))
	if net_id == 0:
		net_id = ToonNet.next_id()
		cog["do_id"] = net_id
	cogs.append({
		"cog": cog,
		"do_id": net_id,
		"slot": slot,
		"edges": 0,
		"phase": 0,
		"fly": 0.0,
		"walk": 0.0,
		"idle": 0.0,
		"goal": ground,
		"ground": ground,
		"position": ground + Vector3(0.0, SKY_HEIGHT, 0.0),
		"yaw": 0.0,
		"till": FROM_SKY * 0.5,
		"impact": 0.0,
		"pathed": false,
		"from_building": false,
	})
	record["cogs"] = cogs
	record.erase("sig")
	_publish_street(key)


## A client asked for a street this process is not standing on. Plan it as data
## until a scene claims the record and draws it.
func ensure(district: int, slug: String) -> void:
	if not ToonNet.is_authority():
		return
	if slug == "sellbot_factory":
		var board := get_node_or_null("FactoryBoard")
		if board != null and board.has_method("ensure"):
			board.call("ensure", district)
		return
	remember_state()
	var key := _key(district, slug)
	if _live.has(key):
		return
	if _streets.has(key):
		_publish_street(key)
		return
	if not StreetSuits.STREETS.has(slug):
		return
	var sim := get_node_or_null("SuitSim")
	var node_name := "%d_%s" % [district, slug]
	if sim == null or sim.get_node_or_null(node_name) != null:
		return
	var node := StreetSuits.new()
	node.name = node_name
	node.json_path = str(StreetSuits.STREETS[slug])
	node.street_slug = slug
	node.visuals = false
	node.district_id = district
	sim.add_child(node)


func has_buildings(district: int, slug: String) -> bool:
	return _blocks.has(_key(district, slug))


func building_rows(district: int, slug: String) -> Array:
	var found: Variant = _blocks.get(_key(district, slug), [])
	if found is Array:
		return found
	return []


func keep_buildings(district: int, slug: String, rows: Array) -> void:
	var key := _key(district, slug)
	_blocks[key] = rows
	ToonNet.publish("buildings:" + key, {"rows": rows})
	if district != 0:
		_touch()


## The street remembers its quota. Buildings are not taken until a cog arrives.
func prepare_buildings(district: int, slug: String, data: Dictionary) -> void:
	if not ToonNet.is_authority():
		return
	remember_state()
	var key := _key(district, slug)
	if not _plans.has(key):
		var blocks: Array = data.get("blocks", [])
		var target := 0
		if district != 0:
			target = _BUILDINGS.target_count(blocks.size(), int(data.get("bmin", 0)), int(data.get("bmax", 0)))
			if _HOLIDAYS.is_county(district):
				target = blocks.size()
		_plans[key] = {
			"target": target,
			"blocks": blocks,
			"tracks": data.get("tracks", []),
			"levels": data.get("levels", []),
		}
	elif _HOLIDAYS.is_county(district):
		var saved: Dictionary = _plans[key]
		var blocks: Array = saved.get("blocks", [])
		saved["target"] = blocks.size()
		_plans[key] = saved
	if not _blocks.has(key):
		_blocks[key] = []
	keep_buildings(district, slug, building_rows(district, slug))


## newSuitShouldAttemptTakeover. One walking cog is reserved per building still needed.
func claim_takeover(district: int, slug: String) -> Dictionary:
	if not ToonNet.is_authority() or district == 0:
		return {}
	var key := _key(district, slug)
	if not _plans.has(key):
		return {}
	var plan: Dictionary = _plans[key]
	if _HOLIDAYS.is_county(district):
		var blocks: Array = plan.get("blocks", [])
		plan["target"] = blocks.size()
		_plans[key] = plan
	var target := int(plan.get("target", 0))
	var used := {}
	for item in building_rows(district, slug):
		if item is Dictionary:
			used[int((item as Dictionary).get("block", 0))] = true
	var pending: Array = _pending.get(key, [])
	for block in pending:
		used[int(block)] = true
	if used.size() >= target:
		return {}
	var picked: Dictionary = _BUILDINGS.plan_one(plan.get("blocks", []), plan.get("tracks", []), plan.get("levels", []), used)
	if picked.is_empty():
		return {}
	var forced := _HOLIDAYS.building_track(district)
	if forced != "":
		picked["track"] = forced
	pending.append(int(picked.get("block", 0)))
	_pending[key] = pending
	return picked


## DistributedBuilding.enterBecomingToon. The tower is still up while it shrinks.
func begin_liberate(district: int, slug: String, block: int) -> void:
	if not ToonNet.is_authority():
		return
	var rows: Array = []
	var changed := false
	for item in building_rows(district, slug):
		if not (item is Dictionary):
			continue
		var row: Dictionary = (item as Dictionary).duplicate()
		if int(row.get("block", 0)) != block:
			rows.append(row)
			continue
		if String(row.get("state", "")) != "liberating":
			row["state"] = "liberating"
			row["since"] = int(Time.get_unix_time_from_system() * 1000.0)
			changed = true
		rows.append(row)
	if changed:
		keep_buildings(district, slug, rows)


## The toons cleared the top floor. The shop comes back and another takeover can start.
func retake_building(district: int, slug: String, block: int) -> void:
	if not ToonNet.is_authority():
		return
	var rows: Array = []
	for item in building_rows(district, slug):
		if item is Dictionary and int((item as Dictionary).get("block", 0)) == block:
			continue
		rows.append(item)
	keep_buildings(district, slug, rows)


func block_pos(district: int, slug: String, block: int) -> Array:
	var plan: Dictionary = _plans.get(_key(district, slug), {})
	for item in plan.get("blocks", []):
		if item is Dictionary and int((item as Dictionary).get("block", 0)) == block:
			var pos: Variant = (item as Dictionary).get("pos", [])
			if pos is Array:
				return pos
	return [0.0, 0.0, 0.0]


func release_takeover(district: int, slug: String, block: int) -> void:
	var key := _key(district, slug)
	var pending: Array = _pending.get(key, [])
	pending.erase(block)
	_pending[key] = pending


## The cog reached the door. The shop locks, then the drop starts 4 seconds later.
func start_takeover(district: int, slug: String, plan: Dictionary) -> void:
	if not ToonNet.is_authority():
		return
	var block := int(plan.get("block", 0))
	var rows: Array = building_rows(district, slug).duplicate()
	for item in rows:
		if item is Dictionary and int((item as Dictionary).get("block", 0)) == block:
			return
	release_takeover(district, slug, block)
	rows.append({
		"block": block,
		"track": String(plan.get("track", "c")),
		"difficulty": int(plan.get("difficulty", 0)),
		"floors": int(plan.get("floors", 1)),
		"title": String(plan.get("title", "")),
		"state": "clearing",
		"clear_left": _CLEAR_OUT,
	})
	keep_buildings(district, slug, rows)


static func door_steps(from_slot: int, door_slot: int, count: int) -> int:
	if count < 2:
		return 2
	var steps := posmod(door_slot - from_slot, count)
	if steps < 2:
		steps += count
	return steps


static func nearest_route(points: Array, route: PackedInt32Array, building: Vector3) -> int:
	var best := 0
	var best_distance := INF
	var flat := Vector2(building.x, building.z)
	for index in route.size():
		var point := _route_point(points, route[index])
		var distance := flat.distance_squared_to(Vector2(point.x, point.z))
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


static func stand_outside(sidewalk: Vector3, building: Vector3) -> Vector3:
	# STAND_OUTSIDE_DOOR is 2.5. The sidewalk point is already outside, so the
	# last step toward the shop stays short of the building center.
	var flat := Vector2(building.x - sidewalk.x, building.z - sidewalk.z)
	var dist := flat.length()
	if dist < 0.001:
		return sidewalk
	var travel := minf(dist - 2.5, 8.0)
	if travel <= 0.0:
		return sidewalk
	var dir := flat / dist
	return Vector3(sidewalk.x + dir.x * travel, lerpf(sidewalk.y, building.y, travel / dist), sidewalk.z + dir.y * travel)


static func read_pos(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and (value as Array).size() >= 3:
		var nums: Array = value
		return Vector3(float(nums[0]), float(nums[1]), float(nums[2]))
	return Vector3.ZERO


static func _route_point(points: Array, index: int) -> Vector3:
	if index < 0 or index >= points.size():
		return Vector3.ZERO
	var value: Variant = points[index]
	if value is Vector3:
		return value
	return Vector3.ZERO


## A client asked for buildings on a street this process is not standing on.
func ensure_buildings(district: int, slug: String) -> void:
	if not ToonNet.is_authority():
		return
	if district == 0:
		keep_buildings(district, slug, [])
		return
	if has_buildings(district, slug):
		keep_buildings(district, slug, building_rows(district, slug))
		return
	if not StreetSuits.STREETS.has(slug):
		return
	var sim := get_node_or_null("BuildingSim")
	var node_name := "%d_%s" % [district, slug]
	if sim == null or sim.get_node_or_null(node_name) != null:
		return
	var path := str(StreetSuits.STREETS[slug]).replace("_suits.json", "_buildings.json")
	if not FileAccess.file_exists(path):
		return
	var script := load("res://scenes/streets/street_buildings.gd") as GDScript
	var node := script.new() as Node
	node.name = node_name
	node.set("json_path", path)
	node.set("street_slug", slug)
	node.set("visuals", false)
	node.set("district_id", district)
	sim.add_child(node)


func _process(delta: float) -> void:
	if not ToonNet.is_authority():
		return
	remember_state()
	_tick_buildings(delta)
	if not _streets.is_empty():
		for key in _streets.keys():
			_advance(_streets[key] as Dictionary, delta)
			_publish_street(String(key))
		_dirty = true
	elif _live_suits() != null:
		_dirty = true
	if not _dirty:
		return
	_save_wait -= delta
	if _save_wait > 0.0:
		return
	_write_state()
	_dirty = false
	_save_wait = 2.0


func _exit_tree() -> void:
	if _remembered and ToonNet.is_authority():
		_write_state()


func _tick_buildings(delta: float) -> void:
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	for key in _blocks.keys():
		var rows: Array = _blocks[key]
		var changed := false
		for item in rows:
			if not (item is Dictionary):
				continue
			var row: Dictionary = item
			if String(row.get("state", "suit")) != "clearing":
				continue
			row["clear_left"] = float(row.get("clear_left", _CLEAR_OUT)) - delta
			if float(row["clear_left"]) > 0.0:
				continue
			row["state"] = "becoming"
			row["since"] = now
			row.erase("clear_left")
			changed = true
		if not changed:
			continue
		var parts := String(key).split(":")
		var slug := parts[1] if parts.size() > 1 else ""
		keep_buildings(int(parts[0]), slug, rows)


func _advance(record: Dictionary, delta: float) -> void:
	var points: Array = record.get("points", [])
	var route: PackedInt32Array = record.get("route", PackedInt32Array())
	if points.is_empty() or route.size() < 2:
		return
	var cogs: Array = record.get("cogs", [])
	var kept: Array = []
	var district := int(record.get("district", 1))
	var slug := String(record.get("slug", ""))
	for index in cogs.size():
		var cog: Dictionary = cogs[index]
		if _step_cog(cog, points, route, cogs, index, delta, district, slug):
			kept.append(cog)
	record["cogs"] = kept
	_tick(record, points, route, delta)


func _step_cog(cog: Dictionary, points: Array, route: PackedInt32Array, cogs: Array, index: int, delta: float, district: int, slug: String) -> bool:
	var phase := int(cog.get("phase", 1))
	var fights := get_node_or_null("StreetFights")
	if phase == 1 and fights != null and fights.has_method("cog_paused") and bool(fights.call("cog_paused", int(cog.get("do_id", 0)))):
		return true
	if phase == 0:
		if bool(cog.get("from_building", false)):
			var walking := _step_exit(cog, delta)
			if int(cog.get("phase", 0)) == 1 and not bool(cog.get("pathed", false)):
				_assign_path(cog, points, route)
			return walking
		var staying := _step_fly(cog, delta, false)
		if int(cog.get("phase", 0)) == 1 and not bool(cog.get("pathed", false)):
			_assign_path(cog, points, route)
		return staying
	if phase == 2:
		return _step_fly(cog, delta, true)
	if phase == 3:
		return _step_enter(cog, delta)
	var take: Dictionary = cog.get("takeover", {})
	if not take.is_empty() and String(cog.get("take_stage", "lane")) == "door":
		return _step_door(cog, take, delta, district, slug)
	var slot := int(cog.get("slot", 0))
	if slot < 0 or slot >= route.size():
		return false
	var origin := _point_at(points, route[slot])
	var nxt := (slot + 1) % route.size()
	var goal := _point_at(points, route[nxt])
	cog["goal"] = goal
	var pos := _vec_at(cog, "position", origin)
	pos = _on_segment(origin, goal, pos)
	if _crowded(index, pos, goal, cogs):
		cog["position"] = pos
		return true
	var flat := Vector2(pos.x, pos.z)
	var target := Vector2(goal.x, goal.z)
	var remaining := flat.distance_to(target)
	if remaining < 0.08:
		cog["position"] = goal
		slot = nxt
		cog["slot"] = slot
		cog["edges"] = int(cog.get("edges", 1)) - 1
		if int(cog["edges"]) <= 0:
			if not take.is_empty():
				cog["take_stage"] = "door"
				cog["position"] = goal
				cog["door_goal"] = stand_outside(goal, read_pos(take.get("pos", [])))
				return true
			if bool(cog.get("building_suit", false)) and _vec_at(cog, "return_door", Vector3.ZERO).length_squared() > 1.0 and _block_still_suit(district, slug, int(cog.get("return_block", -1))):
				cog["phase"] = 3
				cog["fly"] = 0.0
				cog["enter_from"] = goal
				cog["position"] = goal
				return true
			cog["phase"] = 2
			cog["fly"] = 0.0
			cog["ground"] = goal
			cog["pathed"] = false
			return true
		var following := (slot + 1) % route.size()
		var next_point := _point_at(points, route[following])
		cog["goal"] = next_point
		var toward := Vector2(next_point.x - goal.x, next_point.z - goal.z)
		if toward.length_squared() > 0.0001:
			var flat_toward := toward.normalized()
			cog["yaw"] = atan2(-flat_toward.x, -flat_toward.y)
		return true
	var step := minf(WALK_SPEED * delta, remaining)
	var walk := (target - flat) / remaining
	pos.x += walk.x * step
	pos.z += walk.y * step
	var span := Vector2(origin.x, origin.z).distance_to(target)
	if span > 0.001:
		pos.y = lerpf(origin.y, goal.y, 1.0 - remaining / span)
	cog["position"] = pos
	cog["yaw"] = atan2(-walk.x, -walk.y)
	cog["walk"] = float(cog.get("walk", 0.0)) + delta * 24.0
	return true


func _step_door(cog: Dictionary, take: Dictionary, delta: float, district: int, slug: String) -> bool:
	var goal := read_pos(cog.get("door_goal", Vector3.ZERO))
	var pos := _vec_at(cog, "position", goal)
	var flat := Vector2(pos.x, pos.z)
	var target := Vector2(goal.x, goal.z)
	var remaining := flat.distance_to(target)
	if remaining < 0.08:
		cog["position"] = goal
		start_takeover(district, slug, take)
		return false
	var step := minf(WALK_SPEED * delta, remaining)
	var walk := (target - flat) / remaining
	pos.x += walk.x * step
	pos.z += walk.y * step
	pos.y = lerpf(pos.y, goal.y, step / remaining)
	cog["position"] = pos
	cog["yaw"] = atan2(-walk.x, -walk.y)
	cog["walk"] = float(cog.get("walk", 0.0)) + delta * 24.0
	return true


func _on_segment(origin: Vector3, goal: Vector3, pos: Vector3) -> Vector3:
	var start := Vector2(origin.x, origin.z)
	var end := Vector2(goal.x, goal.z)
	var here := Vector2(pos.x, pos.z)
	var edge := end - start
	var length := edge.length_squared()
	var along := 0.0
	if length > 0.0001:
		along = clampf((here - start).dot(edge) / length, 0.0, 1.0)
	var on_path := start.lerp(end, along)
	if here.distance_squared_to(on_path) > 0.12:
		pos.x = on_path.x
		pos.z = on_path.y
	pos.y = lerpf(origin.y, goal.y, along)
	return pos


func _crowded(index: int, pos: Vector3, goal: Vector3, cogs: Array) -> bool:
	var toward := Vector2(goal.x - pos.x, goal.z - pos.z)
	var reach := toward.length()
	for other_index in cogs.size():
		if other_index == index:
			continue
		var other: Dictionary = cogs[other_index]
		if int(other.get("phase", 1)) != 1:
			continue
		var place := _vec_at(other, "position", pos)
		var flat := Vector2(place.x - pos.x, place.z - pos.z)
		var dist := flat.length()
		if dist < 2.0 and other_index < index:
			return true
		if dist > 6.0 or dist < 0.001 or reach < 0.001:
			continue
		var yaw := float(other.get("yaw", 0.0))
		var same_way := Vector2(-sin(yaw), -cos(yaw))
		if same_way.dot(toward) <= 0.0:
			continue
		if flat.dot(toward) / (dist * reach) >= 0.65:
			return true
	return false


func _nearest_slot(points: Array, route: PackedInt32Array, near: Vector3) -> int:
	var best := 0
	var best_distance := INF
	var flat := Vector2(near.x, near.z)
	for index in route.size():
		var point := _point_at(points, route[index])
		var distance := flat.distance_squared_to(Vector2(point.x, point.z))
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


func _point_at(points: Array, index: int) -> Vector3:
	if index < 0 or index >= points.size():
		return Vector3.ZERO
	return _as_vec(points[index])


func _vec_at(cog: Dictionary, key: String, fallback: Vector3) -> Vector3:
	if not cog.has(key):
		return fallback
	var value := _as_vec(cog[key])
	if value == Vector3.ZERO and not (cog[key] is Vector3) and not (cog[key] is Array):
		return fallback
	return value


func _established(district: int, slug: String) -> Array:
	var kept: Array = []
	for item in building_rows(district, slug):
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		var state := String(row.get("state", "suit"))
		if state == "becoming" or state == "clearing":
			continue
		kept.append(row)
	return kept


func _return_door(district: int, slug: String, track: String, fallback: Dictionary) -> Dictionary:
	var choices: Array = []
	var book := _door_book(slug)
	for item in _established(district, slug):
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		if String(row.get("track", "")) != track:
			continue
		var doors: Array = book.get(int(row.get("block", 0)), [])
		for door in doors:
			if door is Dictionary:
				var copy: Dictionary = (door as Dictionary).duplicate()
				copy["block"] = int(row.get("block", -1))
				choices.append(copy)
	if choices.is_empty():
		return fallback
	var picked: Variant = choices[randi() % choices.size()]
	if picked is Dictionary:
		return picked
	return fallback


func _block_still_suit(district: int, slug: String, block: int) -> bool:
	if block < 0:
		return true
	for item in _established(district, slug):
		if item is Dictionary and int((item as Dictionary).get("block", -1)) == block:
			return true
	return false


func _door_for(slug: String, block: int) -> Dictionary:
	var book: Dictionary = _door_book(slug)
	var doors: Array = book.get(block, [])
	if doors.is_empty():
		return {}
	var door: Variant = doors[randi() % doors.size()]
	if door is Dictionary:
		return door
	return {}


func _door_book(slug: String) -> Dictionary:
	if _doors.has(slug):
		return _doors[slug]
	var book := {}
	if StreetSuits.STREETS.has(slug):
		var path := str(StreetSuits.STREETS[slug]).replace("_suits.json", "_buildings.json")
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				for item in (parsed as Dictionary).get("blocks", []):
					if item is Dictionary:
						var block: Dictionary = item
						var doors: Array = block.get("doors", [])
						if not doors.is_empty():
							book[int(block.get("block", 0))] = doors
	_doors[slug] = book
	return book


func _queue_building_suits(record: Dictionary, points: Array, route: PackedInt32Array, cogs: Array) -> void:
	var district := int(record.get("district", 1))
	var slug := String(record.get("slug", ""))
	var rows := _established(district, slug)
	var target := int(float(rows.size()) * StreetSuits.SUIT_BUILDING_NUM_SUITS)
	var have := 0
	for item in cogs:
		if item is Dictionary and bool((item as Dictionary).get("building_suit", false)):
			have += 1
	var burst := mini(int((target - have + 3) / 4), TOTAL_MAX_SUITS - suit_total(district))
	while burst > 0:
		if rows.is_empty():
			return
		var row: Dictionary = rows[randi() % rows.size()]
		var door := _door_for(slug, int(row.get("block", 0)))
		if door.is_empty():
			return
		var dest := _return_door(district, slug, String(row.get("track", "c")), door)
		var cog := _pick_track(record, String(row.get("track", "c")))
		if cog.is_empty():
			return
		var exit := _as_vec(door.get("exit", []))
		var span := StreetCog.exit_span(_as_vec(door.get("pos", [])), exit)
		var slot := _nearest_slot(points, route, exit)
		var job := _fresh(cog, points, route, cogs)
		job["slot"] = slot
		job["from_building"] = true
		job["building_suit"] = true
		job["door"] = door.get("pos", [])
		job["exit"] = door.get("exit", [])
		job["return_door"] = dest.get("pos", [])
		job["return_exit"] = dest.get("exit", [])
		job["return_block"] = int(dest.get("block", row.get("block", -1)))
		job["position"] = span["start"]
		job["yaw"] = span["yaw"]
		job["ground"] = span["end"]
		job["goal"] = span["end"]
		cogs.append(job)
		burst -= 1


func _pick_track(record: Dictionary, track: String) -> Dictionary:
	var cog := _pick(record)
	if cog.is_empty():
		return {}
	var level := int(cog.get("level", 1))
	var catalog: Array = record.get("catalog", [])
	var dept := StreetSuits.DEPTS.find(track)
	if dept < 0:
		dept = 0
	var cog_type := int(cog.get("type", level))
	var index := dept * 8 + cog_type - 1
	if index < 0 or index >= catalog.size():
		return cog
	var source: Dictionary = catalog[index]
	var swapped := source.duplicate() as Dictionary
	swapped["level"] = level
	return StreetSuits.invade(swapped, int(record.get("district", 1)), catalog)


func _step_exit(cog: Dictionary, delta: float) -> bool:
	var fly := float(cog.get("fly", 0.0)) + delta
	cog["fly"] = fly
	var span := StreetCog.exit_span(_vec_at(cog, "door", Vector3.ZERO), _vec_at(cog, "exit", Vector3.ZERO))
	var start: Vector3 = span["start"]
	var outside: Vector3 = span["end"]
	cog["position"] = start.lerp(outside, clampf(fly / StreetCog.FROM_BUILDING, 0.0, 1.0))
	cog["yaw"] = span["yaw"]
	cog["walk"] = float(cog.get("walk", 0.0)) + delta * 24.0
	if fly < StreetCog.FROM_BUILDING:
		return true
	cog["from_building"] = false
	cog["phase"] = 1
	cog["fly"] = 0.0
	cog["position"] = outside
	cog["ground"] = outside
	return true


func _step_enter(cog: Dictionary, delta: float) -> bool:
	var fly := float(cog.get("fly", 0.0)) + delta
	cog["fly"] = fly
	var start := _vec_at(cog, "enter_from", _vec_at(cog, "position", Vector3.ZERO))
	var door := _vec_at(cog, "return_door", Vector3.ZERO)
	var flat := Vector2(start.x, start.z)
	var target := Vector2(door.x, door.z)
	var dist := flat.distance_to(target)
	var dur := maxf(dist / StreetCog.WALK_SPEED, 0.35)
	var along := clampf(fly / dur, 0.0, 1.0)
	cog["position"] = start.lerp(door, along)
	var toward := target - flat
	if toward.length_squared() > 0.0001:
		var flat_toward := toward.normalized()
		cog["yaw"] = atan2(-flat_toward.x, -flat_toward.y)
	cog["walk"] = float(cog.get("walk", 0.0)) + delta * 24.0
	return fly < dur


func _step_fly(cog: Dictionary, delta: float, leaving: bool) -> bool:
	var fly := float(cog.get("fly", 0.0)) + delta
	cog["fly"] = fly
	var ground := _vec_at(cog, "ground", Vector3.ZERO)
	var till := float(cog.get("till", 1.0))
	if till < 0.2:
		till = 0.2
	if leaving:
		var impact := float(cog.get("impact", 0.0))
		if fly < impact:
			cog["position"] = ground
		else:
			var along := clampf((fly - impact) / till, 0.0, 1.0)
			cog["position"] = ground + Vector3(0.0, SKY_HEIGHT * along, 0.0)
		return fly < FROM_SKY
	if fly < till:
		var along := fly / till
		cog["position"] = ground + Vector3(0.0, SKY_HEIGHT * (1.0 - along), 0.0)
	else:
		cog["position"] = ground
	if fly >= FROM_SKY:
		cog["phase"] = 1
		cog["fly"] = 0.0
	return true


func _tick(record: Dictionary, points: Array, route: PackedInt32Array, delta: float) -> void:
	_retire_invasion(record)
	# adjustSuitPopulation drifts the street every five minutes. Upkeep is separate.
	_drift(record, delta)
	var left := float(record.get("upkeep", 10.0)) - delta
	if left > 0.0:
		record["upkeep"] = left
		return
	record["upkeep"] = randf_range(10.0, 12.0)
	var cogs: Array = record.get("cogs", [])
	var desired := int(record.get("desired", record.get("count", 0)))
	var deficit := desired - cogs.size()
	var district := int(record.get("district", 1))
	var slug := String(record.get("slug", ""))
	var have_buildings := 0
	for item in cogs:
		if item is Dictionary and bool((item as Dictionary).get("building_suit", false)):
			have_buildings += 1
	var building_target := int(float(_established(district, slug).size()) * StreetSuits.SUIT_BUILDING_NUM_SUITS)
	var reserved := maxi(building_target - have_buildings, 0)
	var burst := mini(int((deficit + 3) / 4), TOTAL_MAX_SUITS - suit_total(district) - reserved)
	var county_take := 1 if _HOLIDAYS.is_county(district) else 0
	while burst > 0 or county_take > 0:
		var plan := claim_takeover(district, slug)
		if plan.is_empty():
			county_take = 0
		else:
			county_take = 0
		if plan.is_empty() and burst <= 0:
			break
		var cog := _pick(record) if plan.is_empty() else _pick_planned(record, plan)
		if cog.is_empty():
			if not plan.is_empty():
				release_takeover(district, slug, int(plan.get("block", 0)))
			break
		var job := _fresh(cog, points, route, cogs)
		if not plan.is_empty():
			job["takeover"] = plan
			job["take_stage"] = "lane"
		cogs.append(job)
		if burst > 0:
			burst -= 1
	_queue_building_suits(record, points, route, cogs)
	record["cogs"] = cogs


func _retire_invasion(record: Dictionary) -> void:
	var district := int(record.get("district", 1))
	var sig := _HOLIDAYS.invasion_sig(district)
	var previous := String(record.get("invasion", ""))
	if previous == sig:
		return
	record["invasion"] = sig
	if previous == "" and not _stale_invasion(record, sig):
		return
	var fights := get_node_or_null("StreetFights")
	var kept: Array = []
	for item in record.get("cogs", []):
		if not (item is Dictionary):
			continue
		var cog: Dictionary = item
		var busy := false
		if fights != null and fights.has_method("cog_paused"):
			busy = bool(fights.call("cog_paused", int(cog.get("do_id", 0))))
		if busy:
			kept.append(cog)
	record["cogs"] = kept


func _stale_invasion(record: Dictionary, sig: String) -> bool:
	var parts := sig.split("|")
	var code := parts[0] if not parts.is_empty() else ""
	var dept := parts[2] if parts.size() > 2 else ""
	if code == "" and dept == "":
		return false
	for item in record.get("cogs", []):
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		var nested: Variant = row.get("cog", {})
		var cog: Dictionary = nested if nested is Dictionary else row
		var cog_code := String(cog.get("code", row.get("code", "")))
		if code != "" and cog_code != code:
			return true
		if code == "" and dept != "" and String(cog.get("dept", "")) != dept:
			return true
	return false


## adjustSuitPopulation adds -2..2, weighted toward zero, and clamps to the street.
func _drift(record: Dictionary, delta: float) -> void:
	if not record.has("base"):
		return
	var street_max := int(record.get("street_max", 0))
	if street_max == 0:
		return
	var left := float(record.get("adjust_left", 300.0)) - delta
	if left > 0.0:
		record["adjust_left"] = left
		return
	record["adjust_left"] = randf_range(300.0, 310.0)
	var choices: Array[int] = [-2, -1, -1, 0, 0, 0, 1, 1, 2]
	var adjust := int(record.get("adjust", 0)) + choices[randi() % choices.size()]
	var base := int(record.get("base", 1))
	var street_min := int(record.get("street_min", 1))
	var wanted := base + adjust
	if wanted < street_min:
		adjust = street_min - base
	elif wanted > street_max:
		adjust = street_max - base
	record["adjust"] = adjust
	record["desired"] = base + adjust
	record["count"] = base + adjust


func _assign_path(cog: Dictionary, points: Array, route: PackedInt32Array) -> void:
	if route.size() < 2:
		cog["phase"] = 2
		return
	var slot := int(cog.get("slot", 0))
	var take: Dictionary = cog.get("takeover", {})
	if not take.is_empty():
		var door_slot := nearest_route(points, route, read_pos(take.get("pos", [])))
		var door_next := (slot + 1) % route.size()
		var door_point := _point_at(points, route[door_next])
		var door_ground := _point_at(points, route[slot])
		var door_toward := Vector2(door_point.x - door_ground.x, door_point.z - door_ground.z)
		cog["edges"] = door_steps(slot, door_slot, route.size())
		cog["goal"] = door_point
		cog["ground"] = door_ground
		cog["pathed"] = true
		cog["take_stage"] = "lane"
		if door_toward.length_squared() > 0.0001:
			var door_flat := door_toward.normalized()
			cog["yaw"] = atan2(-door_flat.x, -door_flat.y)
		return
	if bool(cog.get("building_suit", false)):
		var dest := _vec_at(cog, "return_exit", Vector3.ZERO)
		if dest.length_squared() > 1.0:
			var back_ground := _point_at(points, route[slot])
			var back_slot := nearest_route(points, route, dest)
			var back_next := (slot + 1) % route.size()
			var back_goal := _point_at(points, route[back_next])
			cog["edges"] = door_steps(slot, back_slot, route.size())
			cog["goal"] = back_goal
			cog["ground"] = back_ground
			cog["pathed"] = true
			var back_toward := Vector2(back_goal.x - back_ground.x, back_goal.z - back_ground.z)
			if back_toward.length_squared() > 0.0001:
				var back_flat := back_toward.normalized()
				cog["yaw"] = atan2(-back_flat.x, -back_flat.y)
			return
	var ground := _point_at(points, route[slot])
	var ahead := randi_range(1, route.size() - 1)
	var path_points := ahead + 1
	if path_points < 40:
		path_points = (route.size() - ahead) + 1
	if path_points > 300:
		path_points = 300
	var nxt := (slot + 1) % route.size()
	var goal := _point_at(points, route[nxt])
	var toward := Vector2(goal.x - ground.x, goal.z - ground.z)
	cog["edges"] = path_points - 1
	cog["goal"] = goal
	cog["ground"] = ground
	cog["pathed"] = true
	if toward.length_squared() > 0.0001:
		var flat := toward.normalized()
		cog["yaw"] = atan2(-flat.x, -flat.y)


func _fresh(cog: Dictionary, points: Array, route: PackedInt32Array, others: Array) -> Dictionary:
	var slot := _open_slot(route, others)
	var ground := _point_at(points, route[slot])
	return {
		"cog": cog,
		"do_id": ToonNet.next_id(),
		"slot": slot,
		"edges": 0,
		"phase": 0,
		"fly": 0.0,
		"walk": 0.0,
		"idle": 0.0,
		"goal": ground,
		"ground": ground,
		"position": ground + Vector3(0.0, SKY_HEIGHT, 0.0),
		"yaw": 0.0,
		"till": FROM_SKY * 0.5,
		"impact": 0.0,
		"pathed": false,
		"from_building": false,
	}


func _open_slot(route: PackedInt32Array, others: Array) -> int:
	var count := route.size()
	if count < 1:
		return 0
	var taken := PackedInt32Array()
	for item in others:
		var other: Dictionary = item
		taken.append(int(other.get("slot", 0)))
	if taken.is_empty():
		return randi() % count
	var best := 0
	var best_gap := -1
	var slot := randi() % count
	for _step in count:
		var gap := count
		for other in taken:
			var along := absi(slot - int(other))
			along = mini(along, count - along)
			gap = mini(gap, along)
		if gap > best_gap:
			best_gap = gap
			best = slot
		slot = (slot + 1) % count
	return best


func _pick(record: Dictionary) -> Dictionary:
	var levels: Array = record.get("levels", [])
	var catalog: Array = record.get("catalog", [])
	if levels.is_empty() or catalog.is_empty():
		return {}
	var level := int(levels[randi() % levels.size()])
	var max_type := int(record.get("max_type", 6))
	var low := maxi(level - 4, 1)
	var high := mini(level, max_type)
	if high < low:
		high = low
	var cog_type := randi_range(low, high)
	var dept := _pick_dept(record.get("tracks", []))
	var index := dept * 8 + cog_type - 1
	if index < 0 or index >= catalog.size():
		return {}
	var source: Dictionary = catalog[index]
	var cog := source.duplicate() as Dictionary
	cog["level"] = level
	return StreetSuits.invade(cog, int(record.get("district", 1)), catalog)


func _pick_planned(record: Dictionary, plan: Dictionary) -> Dictionary:
	var catalog: Array = record.get("catalog", [])
	if catalog.is_empty():
		return {}
	var level := int(plan.get("level", 1))
	var max_type := int(record.get("max_type", 6))
	var low := maxi(level - 4, 1)
	var high := mini(level, max_type)
	if high < low:
		high = low
	var cog_type := randi_range(low, high)
	var dept := _DEPTS.find(String(plan.get("track", "c")))
	if dept < 0:
		dept = 0
	var index := dept * 8 + cog_type - 1
	if index < 0 or index >= catalog.size():
		return {}
	var source: Dictionary = catalog[index]
	var cog := source.duplicate() as Dictionary
	cog["level"] = level
	return StreetSuits.invade(cog, int(record.get("district", 1)), catalog)


func _pick_dept(tracks: Array) -> int:
	var roll := randi_range(0, 99)
	var count := 0
	for index in tracks.size():
		count += int(tracks[index])
		if roll < count:
			return index
	return 0


func _key(district: int, slug: String) -> String:
	return "%d:%s" % [district, slug]


func _district_of(key: String) -> int:
	var at := key.find(":")
	if at < 0:
		return 1
	return int(key.substr(0, at))


func _publish_street(key: String) -> void:
	if not _streets.has(key):
		return
	var record: Dictionary = _streets[key]
	var rows: Array = record.get("cogs", [])
	var sig := _sig(rows)
	if record.has("sig") and String(record["sig"]) == sig:
		return
	record["sig"] = sig
	ToonNet.publish("suits:" + key, {"rows": rows})


## The street the player is standing on keeps its suits on StreetSuits.
## Every other street in the district is the parked record.
func cog_rows(district: int, slug: String) -> Array:
	if slug == "sellbot_factory":
		var board := get_node_or_null("FactoryBoard")
		if board != null and board.has_method("rows"):
			return board.call("rows", district)
		return []
	var scene := get_tree().current_scene
	if scene != null:
		var suits := scene.get_node_or_null("StreetSuits")
		if suits != null and int(suits.get("district_id")) == district and str(suits.get("street_slug")) == slug and bool(suits.get("visuals")):
			var live: Array = []
			for child in suits.get_children():
				if child.has_method("capture"):
					live.append(child.call("capture"))
			return live
	var record: Variant = _streets.get(_key(district, slug), {})
	if record is Dictionary:
		return (record as Dictionary).get("cogs", [])
	return []


func park_cog(district: int, slug: String, cog_id: int, point: Array) -> void:
	var key := _key(district, slug)
	if not _streets.has(key) or point.size() < 3:
		return
	var record: Dictionary = _streets[key]
	for item in record.get("cogs", []):
		if not (item is Dictionary):
			continue
		var cog: Dictionary = item
		if int(cog.get("do_id", 0)) != cog_id:
			continue
		cog["position"] = Vector3(float(point[0]), float(point[1]), float(point[2]))
		record.erase("sig")
		_streets[key] = record
		_publish_street(key)
		return


func dismiss_cog(district: int, slug: String, cog_id: int) -> void:
	if slug == "sellbot_factory":
		var board := get_node_or_null("FactoryBoard")
		if board != null and board.has_method("dismiss"):
			board.call("dismiss", district, cog_id)
		return
	var scene := get_tree().current_scene
	if scene != null:
		var suits := scene.get_node_or_null("StreetSuits")
		if suits != null and int(suits.get("district_id")) == district and str(suits.get("street_slug")) == slug and bool(suits.get("visuals")):
			for child in suits.get_children():
				if int(child.get_meta("do_id", 0)) != cog_id:
					continue
				if bool(child.get_meta("playback", false)):
					return
				if child.has_method("defeat"):
					child.call("defeat")
				return
	var key := _key(district, slug)
	if not _streets.has(key):
		return
	var record: Dictionary = _streets[key]
	var kept: Array = []
	for item in record.get("cogs", []):
		if item is Dictionary and int((item as Dictionary).get("do_id", 0)) == cog_id:
			continue
		kept.append(item)
	record["cogs"] = kept
	record.erase("sig")
	_streets[key] = record
	_publish_street(key)


func has_actor(code: String) -> bool:
	var waiting: Array = _actors.get(code, [])
	return not waiting.is_empty()


func has_street(district: int, slug: String) -> bool:
	remember_state()
	return _streets.has(_key(district, slug))


## The suits already walking, plus every parked street. The Reload button
## reads this before scripts are refreshed and writes it back after.
func snapshot_spawns() -> Dictionary:
	remember_state()
	var streets := {}
	for key in _streets.keys():
		var name := String(key)
		var raw: Dictionary = _streets[key]
		var record := raw.duplicate(true)
		record["invasion"] = _HOLIDAYS.invasion_sig(int(record.get("district", _district_of(name))))
		streets[name] = record
	var suits := _live_suits()
	if suits != null and suits.has_method("capture_record"):
		var live: Variant = suits.call("capture_record")
		if live is Dictionary and not (live as Dictionary).is_empty():
			var record: Dictionary = (live as Dictionary).duplicate(true)
			var district := int(record.get("district", suits.get("district_id")))
			var slug := String(record.get("slug", suits.get("street_slug")))
			if not slug.is_empty():
				record["invasion"] = _HOLIDAYS.invasion_sig(district)
				streets[_key(district, slug)] = record
	return {
		"streets": streets,
		"blocks": _blocks.duplicate(true),
		"plans": _plans.duplicate(true),
		"pending": _pending.duplicate(true),
	}


func restore_spawns(saved: Dictionary) -> void:
	var streets: Variant = saved.get("streets", {})
	if streets is Dictionary:
		_streets = (streets as Dictionary).duplicate(true)
	var blocks: Variant = saved.get("blocks", {})
	if blocks is Dictionary:
		_blocks = (blocks as Dictionary).duplicate(true)
	var plans: Variant = saved.get("plans", {})
	if plans is Dictionary:
		_plans = (plans as Dictionary).duplicate(true)
	var pending: Variant = saved.get("pending", {})
	if pending is Dictionary:
		_pending = (pending as Dictionary).duplicate(true)
	_live.clear()
	_remembered = true
	_keep_spawns = true


func release_spawns() -> void:
	_keep_spawns = false


## The scene did not reload. Drop the copied live street so it is not simulated twice.
func abort_spawns() -> void:
	_keep_spawns = false
	var suits := _live_suits()
	if suits == null:
		return
	var district := int(suits.get("district_id"))
	var slug := String(suits.get("street_slug"))
	if slug.is_empty():
		return
	var key := _key(district, slug)
	_streets.erase(key)
	_live[key] = true


func remember_state() -> void:
	if _remembered:
		return
	_remembered = true
	if not ToonNet.is_authority():
		return
	_load_state()


func _touch() -> void:
	_dirty = true
	_save_wait = 0.0


func _live_suits() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var suits := scene.get_node_or_null("StreetSuits")
	if suits == null or not bool(suits.get("visuals")):
		return null
	return suits


func _load_state() -> void:
	if not FileAccess.file_exists(_STATE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_STATE_PATH))
	if not (parsed is Dictionary):
		return
	var root: Dictionary = parsed
	var streets: Variant = root.get("streets", {})
	if streets is Dictionary:
		for key in (streets as Dictionary).keys():
			var raw: Variant = (streets as Dictionary)[key]
			if raw is Dictionary:
				_streets[String(key)] = _unpack_street(raw)
	var buildings: Variant = root.get("buildings", {})
	if buildings is Dictionary:
		for key in (buildings as Dictionary).keys():
			var name := String(key)
			if name.begins_with("0:"):
				continue
			var rows: Variant = (buildings as Dictionary)[key]
			if rows is Array:
				_blocks[name] = rows


func _write_state() -> void:
	if not _remembered or not ToonNet.is_authority():
		return
	var streets := {}
	for key in _streets.keys():
		streets[String(key)] = _pack(_streets[key])
	var suits := _live_suits()
	if suits != null and suits.has_method("capture_record"):
		var live: Variant = suits.call("capture_record")
		if live is Dictionary and not (live as Dictionary).is_empty():
			var record: Dictionary = live
			var district := int(record.get("district", suits.get("district_id")))
			var slug := String(record.get("slug", suits.get("street_slug")))
			var live_key := _key(district, slug)
			# Leaving the street already parked this record. Don't replace it
			# with the empty roster left behind after the suits were moved out.
			if not slug.is_empty() and not streets.has(live_key):
				streets[live_key] = _pack(record)
	var buildings := {}
	for key in _blocks.keys():
		var name := String(key)
		if name.begins_with("0:"):
			continue
		buildings[name] = _pack(_blocks[key])
	if streets.is_empty() and buildings.is_empty():
		return
	var file := FileAccess.open(_STATE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"streets": streets, "buildings": buildings}))
	file.close()


func _unpack_street(raw: Dictionary) -> Dictionary:
	var record := raw.duplicate(true)
	var points: Array = []
	var raw_points: Variant = record.get("points", [])
	if raw_points is Array:
		for item in raw_points as Array:
			points.append(_as_vec(item))
	record["points"] = points
	var route := PackedInt32Array()
	var raw_route: Variant = record.get("route", [])
	if raw_route is Array:
		for item in raw_route as Array:
			route.append(int(item))
	record["route"] = route
	var cogs: Variant = record.get("cogs", [])
	if cogs is Array:
		for item in cogs as Array:
			if item is Dictionary:
				_unpack_cog(item)
	return record


func _unpack_cog(cog: Dictionary) -> void:
	for key in ["position", "goal", "ground", "door_goal"]:
		if cog.has(key):
			cog[key] = _as_vec(cog[key])


func _as_vec(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and (value as Array).size() >= 3:
		var nums: Array = value
		return Vector3(float(nums[0]), float(nums[1]), float(nums[2]))
	return Vector3.ZERO


func _pack(value: Variant) -> Variant:
	if value is Vector3:
		var point := value as Vector3
		return [point.x, point.y, point.z]
	if value is PackedInt32Array:
		var nums: Array = []
		for number in value as PackedInt32Array:
			nums.append(int(number))
		return nums
	if value is Dictionary:
		var out := {}
		for key in (value as Dictionary).keys():
			out[str(key)] = _pack((value as Dictionary)[key])
		return out
	if value is Array:
		var rows: Array = []
		for item in value as Array:
			rows.append(_pack(item))
		return rows
	return value


func _sig(rows: Array) -> String:
	var parts: PackedStringArray = []
	for item in rows:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		parts.append("%s:%s:%s:%s:%s" % [row.get("do_id", 0), row.get("phase", -1), row.get("pathed", false), row.get("slot", 0), row.get("edges", 0)])
	return "|".join(parts)
