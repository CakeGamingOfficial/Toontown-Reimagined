extends Node

## Stompers, gears, barrels, crates, belts, sinking platforms, and goons from
## the mint room specs. Cog levels are remembered until the reward for the
## battle that defeated them.

const _FLOORS := preload("res://scenes/cog_hq/mint_floor.gd")
const _MOTION := "res://assets/cog_hq/facility_motion.json"
const _GOON := "res://assets/cog_hq/goon.glb"
const _SMALL := "res://assets/cog_hq/audio/CHQ_FACT_stomper_small.ogg"
const _MED := "res://assets/cog_hq/audio/CHQ_FACT_stomper_med.ogg"
const _LARGE := "res://assets/cog_hq/audio/CHQ_FACT_stomper_large.ogg"
const _BEANS := preload("res://scenes/toons/jellybeans.gd")
const _ARRIVAL := preload("res://scenes/playgrounds/playground_toon.gd")
const _PLACES := preload("res://scenes/places/hood_places.gd")

static var _levels: Array[int] = []

var _time := 0.0
var _leaving := false
var _hurt_until: Dictionary = {}
var _taken: Dictionary = {}
var _stompers: Array[Dictionary] = []
var _gears: Array[Dictionary] = []
var _barrels: Array[Dictionary] = []
var _crates: Array[Dictionary] = []
var _belts: Array[Dictionary] = []
var _platforms: Array[Dictionary] = []
var _mixers: Array[Dictionary] = []
var _goons: Array[Dictionary] = []
var _motion: Dictionary = {}


static func remember(level: int) -> void:
	_levels.append(level)


static func collect() -> Array:
	var copy: Array = []
	for level in _levels:
		copy.append(level)
	_levels.clear()
	return copy


static func place(host: Node) -> void:
	if Engine.is_editor_hint() or host == null:
		return
	if host.scene_file_path.get_file() != "cashbot_mint.tscn":
		return
	if host.get_node_or_null("MintProps") != null:
		return
	var script := load("res://scenes/cog_hq/mint_props.gd") as GDScript
	var node := script.new() as Node
	node.name = "MintProps"
	host.add_child(node)


func _ready() -> void:
	_levels.clear()
	var host := get_parent()
	if host == null:
		return
	var found: Dictionary = {}
	_index(host, found)
	_read(found)
	_motion = _load_motion()
	_mixers_from(host)
	_goons_from(host)


func _exit_tree() -> void:
	_levels.clear()


func _physics_process(delta: float) -> void:
	if _leaving:
		return
	_time += delta
	var body := _body()
	var busy := _busy()
	_move_stompers(body, busy)
	_spin_gears(delta, body, busy)
	_move_platforms(body, delta, busy)
	_move_mixers(body, busy)
	if body != null and not busy:
		_ride_belts(body, delta)
		_push_crates(body, delta)
		_grab_barrels(body)
		_move_goons(body, delta)
	else:
		_move_goons(null, delta)


func _index(node: Node, found: Dictionary) -> void:
	var node_name := String(node.name)
	if node_name.begins_with("stomp-") or node_name.begins_with("gear-") or node_name.begins_with("barrel-") or node_name.begins_with("crate-") or node_name.begins_with("belt-") or node_name.begins_with("platform-"):
		found[node_name] = node
	for child in node.get_children():
		_index(child, found)


func _read(found: Dictionary) -> void:
	var book := _FLOORS.data()
	var rooms: Dictionary = book.get("rooms", {})
	var floor := _FLOORS.layout()
	var seen: Dictionary = {}
	for item in floor.get("pieces", []):
		if not (item is Dictionary):
			continue
		var piece: Dictionary = item
		if String(piece.get("kind", "")) != "room":
			continue
		var room_id := str(piece.get("id", ""))
		if seen.has(room_id):
			continue
		seen[room_id] = true
		var info: Variant = rooms.get(room_id, {})
		if not (info is Dictionary):
			continue
		var hazards: Dictionary = (info as Dictionary).get("hazards", {})
		_take_stompers(found, hazards.get("stompers", []))
		_take_gears(found, hazards.get("gears", []))
		_take_named(found, hazards.get("barrels", []), _barrels, false)
		_take_named(found, hazards.get("crates", []), _crates, true)
		_take_named(found, hazards.get("belts", []), _belts, false)
		_take_platforms(found, hazards.get("platforms", []))


func _take_stompers(found: Dictionary, rows: Variant) -> void:
	if not (rows is Array):
		return
	for item in rows:
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item
		var head := found.get(String(spec.get("name", ""))) as Node3D
		if head == null:
			continue
		var span := float(spec.get("range", 0.0))
		_stompers.append({
			"id": String(spec.get("name", "")),
			"head": head,
			"x": head.position.x,
			"z": head.position.z,
			"motion": int(spec.get("motion", 3)),
			"period": maxf(float(spec.get("period", 2.0)), 0.1),
			"phase": float(spec.get("phase", 0.0)),
			"range": span,
			"damage": int(spec.get("damage", 3)),
			"last": 0.0,
			"voice": _stomp_voice(head, span),
			"aim": _named(head, "head"),
		})


func _take_gears(found: Dictionary, rows: Variant) -> void:
	if not (rows is Array):
		return
	for item in rows:
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item
		var pivot := found.get(String(spec.get("name", ""))) as Node3D
		if pivot == null:
			continue
		var mesh := pivot
		for child in pivot.get_children():
			if child is Node3D:
				mesh = child
				break
		var speed := float(spec.get("speed", 0.0))
		mesh.rotate_object_local(Vector3(0, 0, 1), deg_to_rad(360.0 * float(spec.get("phase", 0.0))))
		var upright := absf(mesh.global_transform.basis.z.y) > 0.5
		_gears.append({
			"id": String(spec.get("name", "")),
			"mesh": mesh,
			"speed": speed,
			"wheel": not upright,
		})


func _take_named(found: Dictionary, rows: Variant, into: Array[Dictionary], crates: bool) -> void:
	if not (rows is Array):
		return
	for item in rows:
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item
		var root := found.get(String(spec.get("name", ""))) as Node3D
		if root == null:
			continue
		var row := spec.duplicate()
		row["root"] = root
		if crates:
			row["home"] = root.global_position
		into.append(row)


func _take_platforms(found: Dictionary, rows: Variant) -> void:
	if not (rows is Array):
		return
	for item in rows:
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item
		var root := found.get(String(spec.get("name", ""))) as Node3D
		if root == null:
			continue
		_platforms.append({
			"root": root,
			"z": root.position.z,
			"drop": float(spec.get("drop", 1.0)),
			"sink": maxf(float(spec.get("sink", 1.0)), 0.1),
			"pause": maxf(float(spec.get("pause", 1.0)), 0.0),
			"rise": maxf(float(spec.get("rise", 1.0)), 0.1),
			"along": 0.0,
			"mode": "up",
			"age": 0.0,
		})


func _goons_from(host: Node) -> void:
	var packed := load(_GOON) as PackedScene
	if packed == null:
		return
	var floor := _FLOORS.layout()
	for item in floor.get("goons", []):
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item
		var root := Node3D.new()
		root.name = "Goon%d" % int(spec.get("id", 0))
		host.add_child(root)
		var spot: Array = spec.get("pos", [0.0, 0.0, 0.0])
		root.global_position = Vector3(float(spot[0]), float(spot[1]), float(spot[2]))
		var yaw := deg_to_rad(float(spec.get("yaw", 0.0)))
		root.rotation.y = yaw
		var mesh := packed.instantiate() as Node3D
		if mesh != null:
			mesh.name = "Goon"
			root.add_child(mesh)
			mesh.scale = Vector3.ONE * float(spec.get("scale", 1.0))
		var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var goon_id := int(spec.get("id", 0))
		var points := _route(root.global_position, yaw, goon_id)
		if not points.is_empty():
			root.global_position = points[0]
		_goons.append({
			"id": goon_id,
			"root": root,
			"basis": root.global_transform.basis,
			"forward": forward,
			"home": forward,
			"speed": float(spec.get("speed", 4.0)),
			"reach": float(spec.get("reach", 15.0)),
			"strength": int(spec.get("strength", 1)),
			"scale": float(spec.get("scale", 1.0)),
			"fov": float(spec.get("fov", 70.0)),
			"walked": 0.0,
			"alert": false,
			"points": points,
			"index": 0,
			"wait": 0.0,
			"stun": 0.0,
		})


func _move_stompers(body: Node3D, busy: bool) -> void:
	for item in _stompers:
		var head: Node3D = item["head"]
		if head == null:
			continue
		var period := float(item["period"])
		var t := fposmod(_time / period + float(item["phase"]), 1.0)
		var span := float(item["range"])
		var y := _stomp_y(int(item["motion"]), t, span)
		head.position = Vector3(float(item["x"]), y, float(item["z"]))
		var last := float(item["last"])
		item["last"] = t
		if not _slammed(int(item["motion"]), last, t):
			continue
		var voice: AudioStreamPlayer3D = item["voice"]
		if voice != null:
			voice.play()
		var aim: Node3D = item["aim"]
		var where := head.global_position if aim == null else aim.global_position
		_crush_goons(where)
		if busy or body == null:
			continue
		if body.global_position.distance_to(where) <= 3.0:
			_hurt(int(item["damage"]), String(item["id"]))


func _stomp_y(motion: int, t: float, span: float) -> float:
	if motion == 5:
		return -span
	if motion == 0:
		if t < 0.5:
			return -span * (t / 0.5)
		if t < 0.75:
			return -span
		return -span * (1.0 - (t - 0.75) / 0.25)
	if motion == 1:
		var theta := PI + t * TAU
		return (0.5 + cos(theta) * 0.5) * -span
	if motion == 3:
		if t < 0.2:
			return 0.0
		if t < 0.95:
			return (t - 0.2) * -span / 0.75
		return -span + (t - 0.95) * span / 0.05
	if motion == 4:
		if t < 0.2:
			return 0.0
		if t <= 0.35:
			return (t - 0.2) * -span / 0.15
		if t <= 0.85:
			return -span
		return -span + (t - 0.85) * span / 0.15
	return sin(t * PI) * -span


func _slammed(motion: int, last: float, t: float) -> bool:
	var mark := 0.5
	if motion == 3:
		mark = 0.95
	elif motion == 4:
		mark = 0.85
	elif motion == 5:
		return false
	if last < mark and t >= mark:
		return true
	return t < last and (last < mark or t >= mark)


func _spin_gears(delta: float, body: Node3D, busy: bool) -> void:
	for item in _gears:
		var mesh: Node3D = item["mesh"]
		if mesh == null:
			continue
		mesh.rotate_object_local(Vector3(0, 0, 1), deg_to_rad(float(item["speed"])) * delta)
		if busy or body == null or not bool(item["wheel"]):
			continue
		if body.global_position.distance_to(mesh.global_position) <= 1.8:
			_hurt(3, String(item["id"]))


func _move_platforms(body: Node3D, delta: float, busy: bool) -> void:
	for item in _platforms:
		var root: Node3D = item["root"]
		if root == null:
			continue
		var stood := false
		if body != null and not busy:
			var local := root.to_local(body.global_position)
			stood = absf(local.x) < 4.0 and absf(local.y) < 4.0 and local.z > -1.0 and local.z < 5.0
		var mode := String(item["mode"])
		var age := float(item["age"]) + delta
		item["age"] = age
		var along := float(item["along"])
		if mode == "up" and stood:
			item["mode"] = "sink"
			item["age"] = 0.0
		elif mode == "sink":
			along = clampf(age / float(item["sink"]), 0.0, 1.0)
			if along >= 1.0:
				item["mode"] = "pause"
				item["age"] = 0.0
		elif mode == "pause":
			along = 1.0
			if age >= float(item["pause"]):
				item["mode"] = "rise"
				item["age"] = 0.0
		elif mode == "rise":
			along = 1.0 - clampf(age / float(item["rise"]), 0.0, 1.0)
			if along <= 0.0:
				item["mode"] = "up"
				item["age"] = 0.0
		var before := root.global_position
		item["along"] = along
		root.position.z = float(item["z"]) - float(item["drop"]) * along
		if stood:
			body.global_position += root.global_position - before


func _ride_belts(body: CharacterBody3D, delta: float) -> void:
	for item in _belts:
		var root: Node3D = item["root"]
		if root == null:
			continue
		var local := root.to_local(body.global_position)
		var half := float(item.get("length", 10.0)) * 0.5
		var dir := Vector3.ZERO
		if absf(local.y) < half and absf(local.x) < 4.0 and absf(local.z) < 5.0:
			dir = root.global_transform.basis.y
		elif absf(local.x) < half and absf(local.y) < 4.0 and absf(local.z) < 5.0:
			dir = root.global_transform.basis.x
		if dir == Vector3.ZERO:
			continue
		dir.y = 0.0
		if dir.length_squared() < 0.0001:
			continue
		body.global_position += dir.normalized() * float(item.get("speed", 1.0)) * delta


func _push_crates(body: CharacterBody3D, delta: float) -> void:
	for item in _crates:
		var root: Node3D = item["root"]
		if root == null:
			continue
		var home: Vector3 = item["home"]
		var away := body.global_position - root.global_position
		away.y = 0.0
		if away.length() > 1.6 or away.length() < 0.05:
			continue
		var step := -away.normalized() * 2.5 * delta
		var next := root.global_position + step
		next.y = root.global_position.y
		var moved := next - home
		moved.y = 0.0
		if moved.length() > 8.0:
			continue
		root.global_position = next


func _grab_barrels(body: CharacterBody3D) -> void:
	for item in _barrels:
		var root: Node3D = item["root"]
		if root == null or not root.visible:
			continue
		var key := int(item.get("id", 0))
		if bool(_taken.get(key, false)):
			continue
		if body.global_position.distance_to(root.global_position) > 2.2:
			continue
		var kind := String(item.get("kind", ""))
		var grab := int(item.get("grab", 0))
		if kind == "healBarrel":
			var toon := _toon()
			if toon == null or not toon.has_method("battle_loadout"):
				continue
			var loadout := toon.call("battle_loadout") as ToonLoadout
			if loadout == null:
				continue
			loadout.set_hp(mini(loadout.hp + grab, loadout.max_hp), loadout.max_hp)
			loadout.save()
		elif kind == "beanBarrel":
			_BEANS.add_beans(grab)
		elif kind == "gagBarrel":
			var pockets := ToonLoadout.for_selected()
			if pockets == null:
				continue
			var track := _gag_track(pockets, item.get("track", "random"))
			var level := _gag_level(pockets, track, int(item.get("level", 0)))
			if track < 0 or level < 0:
				continue
			var got := 0
			for _n in grab:
				if pockets.purchase(track, level) <= 0:
					break
				got += 1
			if got <= 0:
				continue
		else:
			continue
		_taken[key] = true
		root.visible = false


func _gag_track(loadout: ToonLoadout, raw: Variant) -> int:
	if raw is String and (String(raw) == "random" or String(raw) == ""):
		var choices: Array[int] = []
		for track in ToonLoadout.TRACK_COUNT:
			if loadout.unlocked(track, 0):
				choices.append(track)
		if choices.is_empty():
			return -1
		return choices[randi() % choices.size()]
	var track := int(raw)
	if track < 0 or track >= ToonLoadout.TRACK_COUNT:
		return -1
	return track


func _gag_level(loadout: ToonLoadout, track: int, level: int) -> int:
	if track < 0:
		return -1
	if level > 0 and loadout.unlocked(track, level):
		return level
	var top := -1
	for step in ToonLoadout.LEVEL_COUNT:
		if loadout.unlocked(track, step):
			top = step
	if top < 0:
		return -1
	return randi() % (top + 1)


func _move_goons(body: Node3D, delta: float) -> void:
	for item in _goons:
		var root: Node3D = item["root"]
		if root == null or not is_instance_valid(root):
			continue
		var route: PackedVector3Array = item.get("points", PackedVector3Array())
		if route.size() >= 2:
			_walk_route(item, root, body, delta, route)
			continue
		if _stunned(item, root, body, delta):
			continue
		var home: Vector3 = item["home"]
		var face := home
		var speed := float(item["speed"])
		if body != null:
			var toward := body.global_position - root.global_position
			toward.y = 0.0
			var dist := toward.length()
			var reach := float(item["reach"])
			if dist > 0.05:
				var look := toward.normalized()
				var cone := cos(deg_to_rad(float(item["fov"]) * 0.5))
				var seen := dist <= reach and home.dot(look) >= cone
				if bool(item["alert"]):
					seen = dist <= reach * 1.35
				item["alert"] = seen
				if seen:
					face = look
					if dist <= 3.0:
						_hurt(int(item["strength"]), "goon-%s" % item["id"])
						speed = 0.0
		if speed > 0.0:
			if not bool(item["alert"]):
				var walked := float(item["walked"]) + speed * delta
				if walked > 8.0:
					walked = 0.0
					home = -home
					item["home"] = home
					face = home
				item["walked"] = walked
			root.global_position += face * speed * delta
		var origin: Basis = item["basis"]
		var base: Vector3 = item["forward"]
		var angle := base.signed_angle_to(face, Vector3.UP)
		root.global_transform = Transform3D(Basis(Vector3.UP, angle) * origin, root.global_position)


func _walk_route(item: Dictionary, root: Node3D, body: Node3D, delta: float, points: PackedVector3Array) -> void:
	if _stunned(item, root, body, delta):
		return
	var index := int(item.get("index", 0))
	var wait := float(item.get("wait", 0.0))
	if wait > 0.0:
		item["wait"] = wait - delta
	else:
		var nxt := (index + 1) % points.size()
		var goal := points[nxt]
		var step := goal - root.global_position
		var dist := step.length()
		var speed := float(item["speed"])
		if dist <= speed * delta + 0.05:
			root.global_position = goal
			item["index"] = nxt
			item["wait"] = 3.0
			var after := points[(nxt + 1) % points.size()]
			_face_world(root, after - goal)
		elif dist > 0.001:
			root.global_position += step * (speed * delta / dist)
			_face_world(root, step)
	if body == null:
		return
	var toward := body.global_position - root.global_position
	toward.y = 0.0
	var gap := toward.length()
	if gap > 3.0 or gap < 0.05:
		return
	var forward := Vector3(-sin(root.rotation.y), 0.0, -cos(root.rotation.y))
	if forward.dot(toward.normalized()) < cos(deg_to_rad(float(item["fov"]) * 0.5)):
		return
	_hurt(int(item["strength"]), "goon-%s" % item["id"])


func _stunned(item: Dictionary, root: Node3D, body: Node3D, delta: float) -> bool:
	item["stun"] = maxf(float(item.get("stun", 0.0)) - delta, 0.0)
	if body != null:
		var crown := root.global_position + Vector3.UP * (1.8 * maxf(float(item.get("scale", 1.0)), 0.5))
		if body.global_position.distance_to(crown) < 1.3:
			item["stun"] = 4.0
	return float(item["stun"]) > 0.0


func _face_world(root: Node3D, step: Vector3) -> void:
	var flat := Vector3(step.x, 0.0, step.z)
	if flat.length_squared() < 0.001:
		return
	root.rotation.y = atan2(-flat.x, -flat.z)


func _mixers_from(host: Node) -> void:
	var rooms: Dictionary = _motion.get("mints", {})
	var floor := host.get_node_or_null("MintFloor")
	if floor == null:
		return
	for child in floor.get_children():
		var node_name := str(child.name)
		if not node_name.begins_with("Mintroom"):
			continue
		var room_id := node_name.trim_prefix("Mintroom")
		var book: Dictionary = rooms.get(room_id, {})
		var rows: Variant = book.get("mixers", [])
		if not (rows is Array):
			continue
		for item in rows:
			if not (item is Dictionary):
				continue
			var spec: Dictionary = item
			var model := _find_named(child, "mixer-%s" % spec.get("id", 0))
			if model == null:
				continue
			var offset: Array = spec.get("offset", [])
			var shift := Vector3.ZERO
			if offset.size() >= 3:
				shift = Vector3(float(offset[0]), float(offset[1]), float(offset[2]))
			_mixers.append({
				"model": model,
				"rest": model.position,
				"offset": shift,
				"period": maxf(float(spec.get("period", 8.0)), 0.1),
				"phase": float(spec.get("phase", 0.0)),
				"wait": clampf(float(spec.get("wait", 0.1)), 0.0, 0.9),
			})


func _move_mixers(body: Node3D, busy: bool) -> void:
	for item in _mixers:
		var model: Node3D = item["model"]
		if model == null:
			continue
		var before := model.global_position
		var stood := false
		if body != null and not busy:
			var local := model.to_local(body.global_position)
			stood = absf(local.x) < 8.0 and absf(local.y) < 8.0 and local.z > -1.0 and local.z < 8.0
		var along := _platform_along(float(item["period"]), float(item["phase"]), float(item["wait"]))
		model.position = (item["rest"] as Vector3) + (item["offset"] as Vector3) * along
		if stood:
			body.global_position += model.global_position - before


func _platform_along(period: float, phase: float, wait: float) -> float:
	var t := fposmod(_time / period + phase, 1.0)
	var move := maxf((1.0 - wait) * 0.5, 0.01)
	if t < wait * 0.5:
		return 0.0
	if t < wait * 0.5 + move:
		return _ease((t - wait * 0.5) / move)
	if t < wait + move:
		return 1.0
	return 1.0 - _ease((t - wait - move) / move)


func _ease(along: float) -> float:
	var x := clampf(along, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _route(origin: Vector3, yaw: float, goon_id: int) -> PackedVector3Array:
	var room := _room_at(origin)
	var book: Dictionary = (_motion.get("mints", {}) as Dictionary).get(str(room), {})
	var row: Dictionary = (book.get("goons", {}) as Dictionary).get(str(goon_id), {})
	var raw: Variant = row.get("points", [])
	var points := PackedVector3Array()
	if not (raw is Array):
		return points
	var scale := float(row.get("scale", 1.0))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var ahead := Vector3(-sin(yaw), 0.0, -cos(yaw))
	for item in raw:
		if item is Array and (item as Array).size() >= 3:
			var spot: Array = item
			var local := Vector3(float(spot[0]), float(spot[1]), float(spot[2])) * scale
			points.append(origin + right * local.x + ahead * local.y + Vector3.UP * local.z)
	return points


func _room_at(point: Vector3) -> int:
	var host := get_parent()
	if host == null:
		return -1
	var floor := host.get_node_or_null("MintFloor")
	if floor == null:
		return -1
	var best := -1
	var best_dist := INF
	for child in floor.get_children():
		var node_name := str(child.name)
		if not node_name.begins_with("Mintroom") or not (child is Node3D):
			continue
		var box := _bounds(child).grow(4.0)
		if not box.has_point(point):
			continue
		var dist := box.get_center().distance_squared_to(point)
		if dist < best_dist:
			best_dist = dist
			best = int(node_name.trim_prefix("Mintroom"))
	return best


func _bounds(node: Node) -> AABB:
	var box := AABB()
	var seeded := false
	if node is Node3D:
		box = AABB((node as Node3D).global_position, Vector3.ZERO)
		seeded = true
	return _grow_bounds(node, box, seeded)


func _grow_bounds(node: Node, box: AABB, seeded: bool) -> AABB:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh_box: AABB = (node as MeshInstance3D).global_transform * (node as MeshInstance3D).get_aabb()
		box = mesh_box if not seeded else box.merge(mesh_box)
		seeded = true
	for child in node.get_children():
		box = _grow_bounds(child, box, seeded)
		seeded = true
	return box


func _find_named(node: Node, node_name: String) -> Node3D:
	if str(node.name) == node_name and node is Node3D:
		return node as Node3D
	for child in node.get_children():
		var found := _find_named(child, node_name)
		if found != null:
			return found
	return null


func _load_motion() -> Dictionary:
	if not FileAccess.file_exists(_MOTION):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_MOTION))
	if parsed is Dictionary:
		return parsed
	return {}


func _crush_goons(where: Vector3) -> void:
	var kept: Array[Dictionary] = []
	for item in _goons:
		var root: Node3D = item["root"]
		if root != null and root.global_position.distance_to(where) <= 3.5:
			root.queue_free()
			continue
		kept.append(item)
	_goons = kept


func _hurt(amount: int, key: String) -> void:
	if amount <= 0 or _leaving:
		return
	if _hurt_until.has(key) and float(_hurt_until[key]) > _time:
		return
	_hurt_until[key] = _time + 1.0
	var toon := _toon()
	if toon == null or not toon.has_method("battle_loadout"):
		return
	var loadout := toon.call("battle_loadout") as ToonLoadout
	if loadout == null or loadout.hp <= 0:
		return
	var left := maxi(loadout.hp - amount, 0)
	loadout.set_hp(left, loadout.max_hp)
	loadout.save()
	if left > 0:
		return
	_leaving = true
	var tasks := ToonTasks.for_selected()
	var hood := 0 if tasks == null else tasks.return_hood()
	if hood == 0:
		hood = _PLACES.TTC
	_ARRIVAL.went_sad = true
	_ARRIVAL.teleport_in = true
	_ARRIVAL.portal_in = true
	ToonLoading.change_to(_PLACES.scene_for(hood))


func _stomp_voice(head: Node3D, span: float) -> AudioStreamPlayer3D:
	var path := _SMALL
	if span >= 20.0:
		path = _LARGE
	elif span >= 12.0:
		path = _MED
	var stream := load(path) as AudioStream
	if stream == null:
		return null
	var voice := AudioStreamPlayer3D.new()
	voice.stream = stream
	voice.max_distance = 45.0
	voice.unit_size = 8.0
	head.add_child(voice)
	return voice


func _named(node: Node, wanted: String) -> Node3D:
	if node == null:
		return null
	if String(node.name) == wanted and node is Node3D:
		return node as Node3D
	for child in node.get_children():
		var found := _named(child, wanted)
		if found != null:
			return found
	return null


func _body() -> CharacterBody3D:
	var host := get_parent()
	if host == null:
		return null
	return host.get_node_or_null("Player") as CharacterBody3D


func _toon() -> Node:
	var host := get_parent()
	if host == null:
		return null
	return host.get_node_or_null("PlaygroundToon")


func _busy() -> bool:
	var toon := _toon()
	if toon == null or not toon.has_method("battle_busy"):
		return false
	return bool(toon.call("battle_busy"))
