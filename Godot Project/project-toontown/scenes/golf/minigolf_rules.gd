class_name MiniGolfRules
extends RefCounted

## Chip 'n Dale's MiniGolf. The holes, tees, and cup come from the phase_6
## models. The power bar is the original __getGolfPower. The district rolls
## the ball against those meshes and every client plays the same path.

const PLAYERS := 4
const BALL_RADIUS := 0.25
const MAX_SWINGS := 6
const TEE_TIME := 15.0
const AIM_TIME := 60.0
const COUNTDOWN := 10.0
const POWER_SPEED := 3.0
const POWER_EXPONENT := 0.75
const COURSES: Array[int] = [3, 6, 9]
const COURSE_NAMES: PackedStringArray = ["3 Holes", "6 Holes", "9 Holes"]
const COURSE_TITLES: PackedStringArray = [
	"Walk In The Par",
	"Hole Some Fun",
	"The Hole Kit And Caboodle",
]
const HOLE_TITLES: PackedStringArray = [
	"Whole In Won", "No Putts About It", "Down The Hatch", "Seeing Green",
	"Hot Links", "Peanut Putter", "Swing-A-Long", "Afternoon Tee",
	"Hole In Fun", "Rock And Roll In", "Bogey Nights", "Tea Off Time",
	"Holey Mackerel!", "One Little Birdie", "At The Drive In", "Swing Time",
	"Hole On The Range", "Second Wind", "Whole In Won-2", "No Putts About It-2",
	"Down The Hatch-2", "Seeing Green-2", "Hot Links-2", "Peanut Putter-2",
	"Swing-A-Long-2", "Afternoon Tee-2", "Hole In Fun-2", "Rock And Roll In-2",
	"Bogey Nights-2", "Tea Off Time-2", "Holey Mackerel!-2", "One Little Birdie-2",
	"At The Drive In-2", "Swing Time-2", "Hole On The Range-2", "Second Wind-2",
]
const BALL_COLORS: Array[Color] = [
	Color(0.95, 0.95, 0.95),
	Color(0.35, 0.55, 0.95),
	Color(0.95, 0.55, 0.2),
	Color(0.72, 0.4, 0.9),
]
const BALL_MODEL := "res://assets/minigolf/golf_ball.glb"

const _CUP := 0.75
const _LIP := 5.0
const _STOP := 0.35
const _STEP := 1.0 / 60.0
const _GRAVITY := 28.0

## GolfGlobals.CourseInfo. A pair in the original list is one hole id.
const _POOLS: Array = [
	[2, 3, 4, 5, 6, 7, 8, 12, 13, 15, 16],
	[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 20, 21, 22, 23, 24, 25, 26, 28, 30, 31, 33, 34],
	[1, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35],
]

static var _book: Dictionary = {}
static var _movers: Dictionary = {}
static var _spaces: Dictionary = {}
static var _mill_fan := Transform3D.IDENTITY
static var _mill_base := Transform3D.IDENTITY
static var _mill_ready := false
## The export stands Z-up models up. A windmill placed on a locator uses the
## locator with this conversion taken back off, because the windmill file
## still has that conversion on its own root.
const _UPRIGHT := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
const _FAN_CENTER := Vector3(-2.33, 0.04, 4.74)
const _FAN_SIZE := Vector3(0.4, 9.44, 9.31)
const _BASE_CENTER := Vector3(-0.7, 0.0, 2.94)
const _BASE_SIZE := Vector3(3.01, 4.87, 5.86)


static func course_title(course: int) -> String:
	if course < 0 or course >= COURSE_TITLES.size():
		return ""
	return COURSE_TITLES[course]


static func hole_title(hole_id: int) -> String:
	if hole_id < 0 or hole_id >= HOLE_TITLES.size():
		return ""
	return HOLE_TITLES[hole_id]


static func holes_for(course: int) -> int:
	return COURSES[clampi(course, 0, COURSES.size() - 1)]


static func pick(course: int) -> Array:
	var pool: Array = (_POOLS[clampi(course, 0, _POOLS.size() - 1)] as Array).duplicate()
	pool.shuffle()
	var chosen: Array = []
	var count := holes_for(course)
	for hole_id in pool:
		if chosen.size() >= count:
			break
		chosen.append(int(hole_id))
	return chosen


static func power_from_hold(hold: float) -> int:
	var t := pow(maxf(hold, 0.0) / POWER_SPEED, POWER_EXPONENT)
	var power := int(t * 100.0) % 200
	if power > 100:
		power = 200 - power
	return power


static func hole(hole_id: int) -> Dictionary:
	_ensure_book()
	var raw: Dictionary = _book.get(str(hole_id), {})
	var tees: Array[Vector3] = []
	for row in raw.get("tees", []):
		if row is Array and (row as Array).size() >= 3:
			tees.append(_vec(row))
	if tees.is_empty():
		tees.append(Vector3(1.0, 0.0, 1.0))
	var cup := Vector3.ZERO
	var cup_row = raw.get("cup", [])
	if cup_row is Array and (cup_row as Array).size() >= 3:
		cup = _vec(cup_row)
	return {
		"par": int(raw.get("par", 3)),
		"model": String(raw.get("model", "")),
		"tees": tees,
		"cup": cup,
	}


## Called from the physics frame. Movers keep the course clock, so the same
## swing at a different moment can miss a barrier or a windmill blade.
static func roll(hole_id: int, origin: Vector3, aim: float, hold: float, when := 0.0) -> Dictionary:
	var info := hole(hole_id)
	var cup: Vector3 = info["cup"]
	var power := power_from_hold(hold)
	var speed := 32.0 * pow(float(power) / 100.0, 0.85)
	var pos := _settle(info, origin + Vector3.UP * 2.0)
	var vel := Vector3(cos(aim), 0.0, sin(aim)) * speed
	var path: Array = [pos.x, pos.y, pos.z]
	var sunk := false
	var wet := false
	var steps := 0
	var elapsed := 0.0
	var world: Dictionary = _world(info)
	var bodies := _spawn_movers(world, hole_id, when)
	_refresh_space(world)
	var state: PhysicsDirectSpaceState3D = world.get("state")
	if state == null:
		_free_bodies(world, bodies)
		return {
			"ready": false,
			"path": [pos.x, pos.y, pos.z],
			"x": pos.x,
			"y": pos.y,
			"z": pos.z,
			"in": false,
			"oob": false,
			"time": 0.35,
			"power": power,
		}
	while steps < 520 and not sunk and not wet:
		steps += 1
		elapsed += _STEP
		_move_bodies(bodies, when + elapsed)
		_refresh_space(world)
		if state == null:
			break
		vel.y -= _GRAVITY * _STEP
		var step := _slide(world, pos, vel)
		pos = step["pos"]
		vel = step["vel"]
		var kind := String(step["kind"])
		if kind == "water" or pos.y < cup.y - 12.0:
			wet = true
			break
		var flat := Vector2(pos.x - cup.x, pos.z - cup.z)
		if flat.length() < _CUP and pos.y < cup.y + 1.2 and Vector2(vel.x, vel.z).length() < _LIP:
			sunk = true
			pos = cup + Vector3.UP * BALL_RADIUS
			vel = Vector3.ZERO
		if vel.length() < _STOP and absf(vel.y) < 1.0:
			break
		if steps % 2 == 0:
			path.append(pos.x)
			path.append(pos.y)
			path.append(pos.z)
	if path.size() < 6 or Vector3(path[-3], path[-2], path[-1]).distance_to(pos) > 0.02:
		path.append(pos.x)
		path.append(pos.y)
		path.append(pos.z)
	_free_bodies(world, bodies)
	return {
		"ready": true,
		"path": path,
		"x": pos.x,
		"y": pos.y,
		"z": pos.z,
		"in": sunk,
		"oob": wet,
		"time": maxf(elapsed, 0.35),
		"power": power,
	}


static func _ensure_book() -> void:
	if not _book.is_empty():
		return
	var text := FileAccess.get_file_as_string("res://assets/minigolf/holes.json")
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_book = parsed


static func _vec(row: Array) -> Vector3:
	return Vector3(float(row[0]), float(row[1]), float(row[2]))


static func _world(info: Dictionary) -> Dictionary:
	var model := String(info["model"])
	if _spaces.has(model):
		var cached: Dictionary = _spaces[model]
		cached["state"] = PhysicsServer3D.space_get_direct_state(cached["space"])
		return cached
	var built := {
		"space": RID(),
		"state": null,
		"sphere": SphereShape3D.new(),
		"shapes": [],
		"kind": {},
	}
	(built["sphere"] as SphereShape3D).radius = BALL_RADIUS
	if model == "":
		_spaces[model] = built
		return built
	var packed := load(model) as PackedScene
	if packed == null:
		return built
	var space := PhysicsServer3D.space_create()
	PhysicsServer3D.space_set_active(space, true)
	built["space"] = space
	var root := packed.instantiate()
	_collect(root, Transform3D.IDENTITY, built)
	root.free()
	if (built["shapes"] as Array).is_empty():
		PhysicsServer3D.free_rid(space)
		built["space"] = RID()
		return built
	built["state"] = PhysicsServer3D.space_get_direct_state(space)
	_spaces[model] = built
	return built


static func _collect(node: Node, parent: Transform3D, built: Dictionary) -> void:
	var here := parent
	if node is Node3D:
		here = parent * (node as Node3D).transform
	if node is MeshInstance3D:
		var kind := _kind(node)
		var mesh := (node as MeshInstance3D).mesh
		if kind != "" and mesh != null:
			var shape := mesh.create_trimesh_shape() as ConcavePolygonShape3D
			if shape != null:
				# The green is a thin card. A one-sided face lets the ball drop through it.
				shape.backface_collision = true
				(built["shapes"] as Array).append(shape)
				var body := PhysicsServer3D.body_create()
				PhysicsServer3D.body_set_space(body, built["space"])
				PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
				PhysicsServer3D.body_add_shape(body, shape.get_rid())
				PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, here)
				(built["kind"] as Dictionary)[body] = kind
	for child in node.get_children():
		_collect(child, here, built)


static func _kind(node: Node) -> String:
	var current := node
	while current != null:
		var name := String(current.name).to_lower()
		if name.contains("tree") or name.contains("flower") or name.contains("background") or name.contains("drop_shadow") or name.contains("locator") or name.begins_with("tee"):
			return ""
		current = current.get_parent()
	var own := String(node.name).to_lower()
	if own.begins_with("pplane"):
		return "water"
	if own.contains("slick"):
		return "slick"
	if own.contains("hole"):
		return "cup"
	var hard := false
	var grass := false
	current = node
	while current != null:
		var name := String(current.name).to_lower()
		if name.contains("hard") or name.begins_with("collision") or name.contains("blocker") or name == "sides" or name.contains("flyover"):
			hard = true
		if name.contains("soft") or name == "grass":
			grass = true
		current = current.get_parent()
	if grass and not hard:
		return "grass"
	if hard:
		return "hard"
	return ""


static func _settle(info: Dictionary, origin: Vector3) -> Vector3:
	var world := _world(info)
	var state: PhysicsDirectSpaceState3D = world.get("state")
	if state == null:
		return origin
	var hit := _ray(state, origin + Vector3.UP * 6.0, origin + Vector3.DOWN * 30.0)
	if hit.is_empty():
		return origin
	return hit["position"] + (hit["normal"] as Vector3) * BALL_RADIUS


## A shape sweep misses the thin green. A ray hits the card from either side.
static func _ray(state: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	if from.distance_squared_to(to) < 0.000001:
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.hit_back_faces = true
	var hit := state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var normal: Vector3 = hit["normal"]
	if normal.dot(to - from) > 0.0:
		hit["normal"] = -normal
	return hit


static func _bounce(vel: Vector3, normal: Vector3, touched: String) -> Vector3:
	var into := vel.dot(normal)
	if into >= 0.0:
		return vel
	var bounce := 0.0
	var drag := 9.0
	if touched == "hard":
		bounce = 0.4
		drag = 4.5
	elif touched == "slick":
		bounce = 0.05
		drag = 1.1
	elif touched == "cup":
		drag = 16.0
	vel -= normal * into * (1.0 + bounce)
	if normal.y > 0.45:
		var flat := Vector3(vel.x, 0.0, vel.z)
		flat = flat.move_toward(Vector3.ZERO, drag * _STEP)
		vel.x = flat.x
		vel.z = flat.z
		if normal.y > 0.65 and absf(vel.y) < 2.2:
			vel.y = 0.0
	return vel


static func _slide(world: Dictionary, pos: Vector3, vel: Vector3) -> Dictionary:
	var state: PhysicsDirectSpaceState3D = world.get("state")
	var touched := ""
	var flat_step := Vector3(vel.x, 0.0, vel.z) * _STEP
	if flat_step.length() > 0.001:
		var dir := flat_step.normalized()
		var hit := _ray(state, pos, pos + dir * (flat_step.length() + BALL_RADIUS))
		var blocked := false
		if not hit.is_empty():
			var normal: Vector3 = hit["normal"]
			var dist := pos.distance_to(hit["position"])
			if normal.y < 0.45 and dist <= flat_step.length() + BALL_RADIUS:
				if dist < BALL_RADIUS:
					pos += normal * (BALL_RADIUS - dist + 0.01)
				else:
					pos += dir * minf(dist - BALL_RADIUS, flat_step.length())
				touched = _surface(world, hit)
				vel = _bounce(vel, normal, touched)
				blocked = true
		if not blocked:
			pos += flat_step
	if vel.y > 0.0:
		var rise := vel.y * _STEP
		var ceiling := _ray(state, pos, pos + Vector3.UP * (rise + BALL_RADIUS))
		if not ceiling.is_empty():
			var normal: Vector3 = ceiling["normal"]
			var dist := pos.distance_to(ceiling["position"])
			if normal.y < 0.2 and dist <= rise + BALL_RADIUS:
				pos += Vector3.UP * clampf(dist - BALL_RADIUS, 0.0, rise)
				vel.y = 0.0
				touched = _surface(world, ceiling)
			else:
				pos.y += rise
		else:
			pos.y += rise
	else:
		var drop := -vel.y * _STEP
		var ground := _ray(state, pos, pos + Vector3.DOWN * (BALL_RADIUS + drop + 0.4))
		if not ground.is_empty():
			var normal: Vector3 = ground["normal"]
			var dist := pos.distance_to(ground["position"])
			if normal.y > 0.2 and dist <= BALL_RADIUS + drop + 0.05:
				pos = (ground["position"] as Vector3) + normal * BALL_RADIUS
				touched = _surface(world, ground)
				vel = _bounce(vel, normal, touched)
			else:
				pos.y -= drop
		else:
			pos.y -= drop
	return {"pos": pos, "vel": vel, "kind": touched}


static func movers(hole_id: int) -> Array:
	_ensure_movers()
	var raw = _movers.get(str(hole_id), [])
	if raw is Array:
		return raw
	return []


static func slide_transform(record: Dictionary, when: float) -> Transform3D:
	var basis := _basis(record)
	var origin := _origin(record)
	origin += basis.y * _slide_distance(float(record.get("travel", 0.0)), when)
	return Transform3D(basis, origin)


static func fan_root(record: Dictionary) -> Transform3D:
	return Transform3D(_basis(record) * _UPRIGHT.inverse(), _origin(record))


static func fan_spin(when: float) -> Transform3D:
	var spin := Basis(Vector3.RIGHT, when)
	return Transform3D(spin, _FAN_CENTER - spin * _FAN_CENTER)


static func _slide_distance(travel: float, when: float) -> float:
	var cycle := fposmod(when, 10.0)
	if cycle < 1.0:
		return 0.0
	if cycle < 5.0:
		return (cycle - 1.0) * travel / 4.0
	if cycle < 6.0:
		return travel
	return travel - (cycle - 6.0) * travel / 4.0


static func _basis(record: Dictionary) -> Basis:
	var row: Array = record.get("basis", [])
	if row.size() < 9:
		return Basis.IDENTITY
	return Basis(
		Vector3(float(row[0]), float(row[1]), float(row[2])),
		Vector3(float(row[3]), float(row[4]), float(row[5])),
		Vector3(float(row[6]), float(row[7]), float(row[8]))
	)


static func _origin(record: Dictionary) -> Vector3:
	var row: Array = record.get("origin", [])
	if row.size() < 3:
		return Vector3.ZERO
	return _vec(row)


static func _ensure_movers() -> void:
	if _movers.has("_loaded"):
		return
	_movers["_loaded"] = true
	var text := FileAccess.get_file_as_string("res://assets/minigolf/movers.json")
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		for key in (parsed as Dictionary).keys():
			_movers[key] = (parsed as Dictionary)[key]


static func _spawn_movers(world: Dictionary, hole_id: int, when: float) -> Array:
	var space: RID = world.get("space", RID())
	if not space.is_valid():
		return []
	var made: Array = []
	for record in movers(hole_id):
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var kind := String(record.get("kind", ""))
		if kind == "slide":
			var size: Array = record.get("size", [1.0, 1.0])
			var shape := BoxShape3D.new()
			shape.size = Vector3(float(size[0]), float(size[1]), 1.0)
			made.append({
				"body": _box_body(world, shape, slide_transform(record, when)),
				"shape": shape,
				"kind": "slide",
				"record": record,
			})
		elif kind == "fan":
			_ensure_mill()
			var root := fan_root(record)
			var base_shape := BoxShape3D.new()
			base_shape.size = _BASE_SIZE
			made.append({
				"body": _box_body(world, base_shape, root * _mill_base * Transform3D(Basis.IDENTITY, _BASE_CENTER)),
				"shape": base_shape,
				"kind": "base",
			})
			var fan_shape := BoxShape3D.new()
			fan_shape.size = _FAN_SIZE
			made.append({
				"body": _box_body(world, fan_shape, root * _mill_fan * Transform3D(Basis(Vector3.RIGHT, when), _FAN_CENTER)),
				"shape": fan_shape,
				"kind": "fan",
				"root": root,
			})
	return made


static func _move_bodies(bodies: Array, when: float) -> void:
	for item in bodies:
		var kind := String(item.get("kind", ""))
		var body: RID = item.get("body", RID())
		if not body.is_valid():
			continue
		var xform := Transform3D.IDENTITY
		if kind == "slide":
			xform = slide_transform(item.get("record", {}), when)
		elif kind == "fan":
			var root: Transform3D = item.get("root", Transform3D.IDENTITY)
			xform = root * _mill_fan * Transform3D(Basis(Vector3.RIGHT, when), _FAN_CENTER)
		else:
			continue
		PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, xform)


static func _box_body(world: Dictionary, shape: BoxShape3D, xform: Transform3D) -> RID:
	var body := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_space(body, world["space"])
	PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_add_shape(body, shape.get_rid())
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, xform)
	(world["kind"] as Dictionary)[body] = "hard"
	return body


static func _refresh_space(world: Dictionary) -> void:
	var space: RID = world.get("space", RID())
	if space.is_valid():
		world["state"] = PhysicsServer3D.space_get_direct_state(space)


static func _free_bodies(world: Dictionary, bodies: Array) -> void:
	var kinds: Dictionary = world.get("kind", {})
	for item in bodies:
		var body: RID = item.get("body", RID())
		if not body.is_valid():
			continue
		kinds.erase(body)
		PhysicsServer3D.body_set_space(body, RID())
		PhysicsServer3D.free_rid(body)


static func _ensure_mill() -> void:
	if _mill_ready:
		return
	_mill_ready = true
	var packed := load("res://assets/minigolf/windmill.glb") as PackedScene
	if packed == null:
		return
	var root := packed.instantiate()
	var fan := root.find_child("windmillFan0", true, false) as Node3D
	var base := root.find_child("windmillBase0", true, false) as Node3D
	if fan != null:
		_mill_fan = _chain(fan)
	if base != null:
		_mill_base = _chain(base)
	root.free()


static func _chain(node: Node3D) -> Transform3D:
	var order: Array[Node3D] = []
	var current: Node = node
	while current is Node3D:
		order.append(current as Node3D)
		current = current.get_parent()
	order.reverse()
	var xform := Transform3D.IDENTITY
	for item in order:
		xform = xform * item.transform
	return xform


static func _surface(world: Dictionary, rest: Dictionary) -> String:
	var kinds: Dictionary = world["kind"]
	var collider = rest.get("collider", RID())
	if collider is RID and kinds.has(collider):
		return String(kinds[collider])
	var rid = rest.get("rid", RID())
	if rid is RID and kinds.has(rid):
		return String(kinds[rid])
	return "grass"
