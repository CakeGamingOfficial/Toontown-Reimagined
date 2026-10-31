extends Node

## Street suits keep walking after you leave. Entering a shop or another
## street unloads the block, and this holds the population until you come back.

const WALK_SPEED := 4.8
const FROM_SKY := 6.5
const SKY_HEIGHT := FROM_SKY * WALK_SPEED

var _streets: Dictionary = {}


func hold(slug: String, record: Dictionary) -> void:
	if slug.is_empty():
		return
	_streets[slug] = record


func claim(slug: String) -> Dictionary:
	if not _streets.has(slug):
		return {}
	var record: Dictionary = _streets[slug]
	_streets.erase(slug)
	return record


func _process(delta: float) -> void:
	if _streets.is_empty():
		return
	for slug in _streets.keys():
		_advance(_streets[slug] as Dictionary, delta)


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
		else:
			var waits: Array = record.get("waits", [])
			waits.append(randf_range(10.0, 12.0))
			record["waits"] = waits
	record["cogs"] = kept
	var waits: Array = record.get("waits", [])
	var still: Array = []
	var count := int(record.get("count", 0))
	for item in waits:
		var left := float(item) - delta
		if left > 0.0:
			still.append(left)
			continue
		if kept.size() >= count:
			continue
		var cog := _pick(record)
		if cog.is_empty():
			continue
		kept.append(_fresh(cog, points, route, kept))
	record["waits"] = still
	record["cogs"] = kept


func _step_cog(cog: Dictionary, points: Array, route: PackedInt32Array, cogs: Array, index: int, delta: float) -> bool:
	var phase := int(cog.get("phase", 1))
	if phase == 0:
		return _step_fly(cog, delta, false)
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


func _fresh(cog: Dictionary, points: Array, route: PackedInt32Array, others: Array) -> Dictionary:
	var slot := _open_slot(route, others)
	var ground := _point_at(points, route[slot])
	var nxt := (slot + 1) % route.size()
	var goal := _point_at(points, route[nxt])
	var toward := Vector2(goal.x - ground.x, goal.z - ground.z)
	var yaw := 0.0
	if toward.length_squared() > 0.0001:
		var flat := toward.normalized()
		yaw = atan2(-flat.x, -flat.y)
	var ahead := randi_range(1, route.size() - 1)
	var path_points := ahead + 1
	if path_points < 40:
		path_points = (route.size() - ahead) + 1
	if path_points > 300:
		path_points = 300
	return {
		"cog": cog,
		"slot": slot,
		"edges": path_points - 1,
		"phase": 0,
		"fly": 0.0,
		"walk": 0.0,
		"idle": 0.0,
		"goal": goal,
		"ground": ground,
		"position": ground + Vector3(0.0, SKY_HEIGHT, 0.0),
		"yaw": yaw,
		"till": FROM_SKY * 0.5,
		"impact": 0.0,
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
