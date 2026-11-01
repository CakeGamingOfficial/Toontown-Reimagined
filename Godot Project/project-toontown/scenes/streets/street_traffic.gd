extends Node

## Street suits keep walking after you leave. Entering a shop or another
## street unloads the block, and this holds the population until you come back.

const WALK_SPEED := 4.8
const FROM_SKY := 6.5
const SKY_HEIGHT := FROM_SKY * WALK_SPEED
const TOTAL_MAX_SUITS := 50

var _streets: Dictionary = {}
var _actors: Dictionary = {}
## A street the local scene is showing. The data sim must not plan that one too.
var _live: Dictionary = {}


func _ready() -> void:
	var pool := Node3D.new()
	pool.name = "CogPool"
	add_child(pool)
	var sim := Node.new()
	sim.name = "SuitSim"
	add_child(sim)


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
		suit.reparent(holder)


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
	if slug.is_empty():
		return
	var key := _key(district, slug)
	record["district"] = district
	_live.erase(key)
	_streets[key] = record


func claim(district: int, slug: String) -> Dictionary:
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
	var cog := StreetSuits.match_cog(record.get("catalog", []), query)
	if cog.is_empty():
		return
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


func _process(delta: float) -> void:
	if not ToonNet.is_authority() or _streets.is_empty():
		return
	for key in _streets.keys():
		_advance(_streets[key] as Dictionary, delta)
		_publish_street(String(key))


func _advance(record: Dictionary, delta: float) -> void:
	var points: Array = record.get("points", [])
	var route: PackedInt32Array = record.get("route", PackedInt32Array())
	if points.is_empty() or route.size() < 2:
		return
	var cogs: Array = record.get("cogs", [])
	var kept: Array = []
	for index in cogs.size():
		var cog: Dictionary = cogs[index]
		if _step_cog(cog, points, route, cogs, index, delta):
			kept.append(cog)
	record["cogs"] = kept
	_tick(record, points, route, delta)


func _step_cog(cog: Dictionary, points: Array, route: PackedInt32Array, cogs: Array, index: int, delta: float) -> bool:
	var phase := int(cog.get("phase", 1))
	if phase == 0:
		var staying := _step_fly(cog, delta, false)
		if int(cog.get("phase", 0)) == 1 and not bool(cog.get("pathed", false)):
			_assign_path(cog, points, route)
		return staying
	if phase == 2:
		return _step_fly(cog, delta, true)
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
	var value: Variant = points[index]
	if value is Vector3:
		return value
	return Vector3.ZERO


func _vec_at(cog: Dictionary, key: String, fallback: Vector3) -> Vector3:
	var value: Variant = cog.get(key, fallback)
	if value is Vector3:
		return value
	return fallback


func _step_fly(cog: Dictionary, delta: float, leaving: bool) -> bool:
	var fly := float(cog.get("fly", 0.0)) + delta
	cog["fly"] = fly
	var ground: Vector3 = cog.get("ground", Vector3.ZERO)
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
	var left := float(record.get("upkeep", 10.0)) - delta
	if left > 0.0:
		record["upkeep"] = left
		return
	record["upkeep"] = randf_range(10.0, 12.0)
	var cogs: Array = record.get("cogs", [])
	var desired := int(record.get("desired", record.get("count", 0)))
	var deficit := desired - cogs.size()
	var district := int(record.get("district", 1))
	var burst := mini(int((deficit + 3) / 4), TOTAL_MAX_SUITS - suit_total(district))
	while burst > 0:
		var cog := _pick(record)
		if cog.is_empty():
			break
		cogs.append(_fresh(cog, points, route, cogs))
		burst -= 1
	record["cogs"] = cogs


func _assign_path(cog: Dictionary, points: Array, route: PackedInt32Array) -> void:
	if route.size() < 2:
		cog["phase"] = 2
		return
	var slot := int(cog.get("slot", 0))
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
	return cog


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


func _sig(rows: Array) -> String:
	var parts: PackedStringArray = []
	for item in rows:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		parts.append("%s:%s:%s:%s:%s" % [row.get("do_id", 0), row.get("phase", -1), row.get("pathed", false), row.get("slot", 0), row.get("edges", 0)])
	return "|".join(parts)
