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
static var _spaces: Dictionary = {}


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


## Called from the physics frame. The same start, aim, and hold always lands
## on the same spot.
static func roll(hole_id: int, origin: Vector3, aim: float, hold: float) -> Dictionary:
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
	var state: PhysicsDirectSpaceState3D = world.get("state")
	if state == null:
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
			var shape := mesh.create_trimesh_shape()
			if shape != null:
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
	var ray := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 6.0, origin + Vector3.DOWN * 30.0)
	var hit := state.intersect_ray(ray)
	if hit.is_empty():
		return origin
	return hit["position"] + (hit["normal"] as Vector3) * BALL_RADIUS


static func _slide(world: Dictionary, pos: Vector3, vel: Vector3) -> Dictionary:
	var state: PhysicsDirectSpaceState3D = world.get("state")
	var motion := vel * _STEP
	var touched := ""
	for _bounce in 3:
		if motion.length_squared() < 0.0000001:
			break
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = world["sphere"]
		params.transform = Transform3D(Basis.IDENTITY, pos)
		params.motion = motion
		params.margin = 0.02
		var frac := state.cast_motion(params)
		var along := 1.0 if frac.is_empty() else float(frac[0])
		if along >= 1.0:
			pos += motion
			break
		var safe := maxf(along, 0.0)
		pos += motion * safe
		var probe := pos
		if motion.length_squared() > 0.0000001:
			probe += motion.normalized() * 0.04
		params.transform = Transform3D(Basis.IDENTITY, probe)
		params.motion = Vector3.ZERO
		var rest := state.get_rest_info(params)
		var normal := Vector3.UP
		if not rest.is_empty():
			normal = rest["normal"]
			touched = _surface(world, rest)
		if along <= 0.001:
			pos += normal * 0.05
		var into := vel.dot(normal)
		if into < 0.0:
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
		pos += normal * 0.015
		motion = vel * _STEP * (1.0 - safe)
		if touched == "water":
			break
	return {"pos": pos, "vel": vel, "kind": touched}


static func _surface(world: Dictionary, rest: Dictionary) -> String:
	var kinds: Dictionary = world["kind"]
	var collider = rest.get("collider", RID())
	if collider is RID and kinds.has(collider):
		return String(kinds[collider])
	var rid = rest.get("rid", RID())
	if rid is RID and kinds.has(rid):
		return String(kinds[rid])
	return "grass"
