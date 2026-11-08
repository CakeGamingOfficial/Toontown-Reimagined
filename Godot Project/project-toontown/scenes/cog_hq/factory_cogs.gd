extends Node

## SellbotLegFactoryCogs. The district rolls one roster and every player in
## that factory draws it. Walking into a cog starts the street battle for
## that cog's battle cell.

const _LIST := "res://assets/cog_hq/sellbot_factory_cogs.json"
const _CATALOG := "res://assets/cogs/catalog.json"
const _WALK := 3.0
const _CHASE := 4.0
const _TURN := 1.0
const _CHASE_FOR := 3.0
const _ALERT := 15.0
const _ALERT_Y := 8.0
const _STRAY := 10.0
const _TOUCH := 3.5


class Walker:
	var actor: Node3D
	var points := PackedVector3Array()
	var stand := Vector3.ZERO
	var stand_yaw := 0.0
	var post := Vector3.ZERO
	var behavior := ""
	var mode := "stand"
	var seg := 0
	var age := 0.0
	var dur := 1.0
	var origin := Vector3.ZERO
	var goal := Vector3.ZERO
	var yaw0 := 0.0
	var yaw1 := 0.0
	var chase_left := 0.0
	var retarget := 0.0
	var aim := Vector3.ZERO


var _board: Node
var _timing: Dictionary = {}
var _paths: Dictionary = {}
var _nodes: Dictionary = {}
var _suits: GDScript
var _spawned: Dictionary = {}
var _sig := ""
var _cogs: Array[Walker] = []
var district_id := -1
var street_slug := "sellbot_factory"
var visuals := false


static func place(host: Node) -> void:
	if Engine.is_editor_hint() or host == null:
		return
	if host.scene_file_path.get_file() != "sellbot_factory.tscn":
		return
	if host.get_node_or_null("StreetSuits") != null:
		return
	var script := load("res://scenes/cog_hq/factory_cogs.gd") as GDScript
	var node := script.new() as Node
	node.name = "StreetSuits"
	host.add_child(node)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	district_id = ToonNet.district_id()
	_prepare_nametags()
	var catalog := _read_json(_CATALOG)
	_timing = catalog.get("timing", {})
	var data := _read_json(_LIST)
	_paths = data.get("paths", {})
	_collect(get_parent(), _nodes)
	_suits = load("res://scenes/cogs/street_cog.gd")
	ToonNet.request_suits(district_id, street_slug)


func _process(delta: float) -> void:
	if _board != null:
		_board.set("camera", get_viewport().get_camera_3d())
		_board.call("place")
	_apply_net()
	var toon := _toon()
	for cog in _cogs:
		_step(cog, delta, toon)


func _apply_net() -> void:
	var snap := ToonNet.latest("suits:%d:%s" % [district_id, street_slug])
	if not snap.has("rows"):
		return
	var listing: Array = snap.get("rows", [])
	var parts := PackedStringArray()
	for item in listing:
		if item is Dictionary:
			parts.append(str(int((item as Dictionary).get("do_id", 0))))
	var sig := "|".join(parts)
	if sig == _sig:
		return
	_sig = sig
	var seen := {}
	for item in listing:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		var cog_id := int(row.get("do_id", 0))
		if cog_id == 0:
			continue
		seen[cog_id] = true
		if _spawned.has(cog_id):
			continue
		var walker := _spawn(row)
		if walker != null:
			_spawned[cog_id] = walker
	var gone: Array = []
	for cog_id in _spawned.keys():
		if not seen.has(cog_id):
			gone.append(cog_id)
	for cog_id in gone:
		var walker: Walker = _spawned[cog_id]
		_spawned.erase(cog_id)
		_cogs.erase(walker)
		if walker != null and walker.actor != null and is_instance_valid(walker.actor):
			if walker.actor.has_method("fly_away") and bool(walker.actor.call("fly_away")):
				continue
			walker.actor.queue_free()


func _spawn(row: Dictionary) -> Walker:
	var suit: Dictionary = row.get("cog", {})
	if suit.is_empty() or _suits == null:
		return null
	var parent := _nodes.get("nodepath-%d" % int(suit.get("parent", 0))) as Node3D
	if parent == null:
		return null
	var actor := _suits.new() as Node3D
	actor.name = str(suit.get("name", "Cog"))
	add_child(actor)
	actor.set_meta("do_id", int(row.get("do_id", 0)))
	actor.call("present", suit, _timing)
	var spot: Array = suit.get("pos", [0.0, 0.0, 0.0])
	var cog := Walker.new()
	cog.actor = actor
	cog.stand = parent.global_transform * Vector3(float(spot[0]), float(spot[1]), float(spot[2]))
	cog.stand_yaw = _heading(parent, float(suit.get("h", 0.0)))
	cog.behavior = str(suit.get("behavior", "walk"))
	cog.points = _route(int(suit.get("path", 0)), parent, _paths, _nodes)
	_cogs.append(cog)
	if cog.points.size() >= 2:
		cog.seg = 0
		actor.global_position = cog.points[0]
		_begin_turn(cog)
	else:
		_stand(cog)
	return cog


## DistributedFactorySuit.setPath reparents the path onto the cog's marker
## and keeps the path's own transform. The points stay in that local space.
func _route(path_id: int, marker: Node3D, paths: Dictionary, nodes: Dictionary) -> PackedVector3Array:
	var points := PackedVector3Array()
	if path_id == 0 or marker == null:
		return points
	var holder := nodes.get("path-%d" % path_id) as Node3D
	var info: Variant = paths.get(str(path_id))
	if holder == null or not (info is Dictionary):
		return points
	var spec: Dictionary = info
	var scale := float(spec.get("scale", 1.0))
	var placed := marker.global_transform * holder.transform
	for item in spec.get("points", []):
		if item is Array and (item as Array).size() >= 3:
			var spot: Array = item
			points.append(placed * (Vector3(float(spot[0]), float(spot[1]), float(spot[2])) * scale))
	return points


func _step(cog: Walker, delta: float, toon: Node3D) -> void:
	if cog.actor == null or not is_instance_valid(cog.actor):
		return
	if bool(cog.actor.get_meta("in_fight", false)) or bool(cog.actor.get_meta("flying", false)):
		return
	var alert := _near(cog, toon, _ALERT)
	var touch := _near(cog, toon, _TOUCH)
	if cog.mode == "hold":
		if touch:
			_face(cog.actor, toon.global_position - cog.actor.global_position)
			cog.actor.call("set_walking", false)
		else:
			_begin_return(cog)
		return
	if cog.behavior == "chase" and alert and (cog.mode == "walk" or cog.mode == "turn" or cog.mode == "stand"):
		if touch:
			cog.mode = "hold"
			cog.actor.call("set_walking", false)
			return
		_begin_chase(cog)
	if cog.mode == "chase":
		_chase(cog, delta, toon)
	elif cog.mode == "back":
		_slide(cog, delta, false)
	elif cog.mode == "turn":
		_turn(cog, delta)
	elif cog.mode == "walk":
		_slide(cog, delta, true)


func _begin_chase(cog: Walker) -> void:
	cog.mode = "chase"
	cog.chase_left = _CHASE_FOR
	cog.retarget = 0.0
	cog.post = cog.actor.global_position
	cog.aim = cog.actor.global_position
	cog.actor.call("set_walking", true)


func _chase(cog: Walker, delta: float, toon: Node3D) -> void:
	if cog.actor.global_position.distance_to(cog.post) > _STRAY:
		_begin_return(cog)
		return
	cog.chase_left -= delta
	if cog.chase_left <= 0.0:
		_begin_return(cog)
		return
	if _near(cog, toon, _TOUCH):
		cog.mode = "hold"
		cog.actor.call("set_walking", false)
		return
	cog.retarget -= delta
	if cog.retarget <= 0.0 and toon != null:
		cog.retarget = 1.0
		cog.aim = toon.global_position
		cog.aim.x += 4.0 * (randf() - 0.5)
		cog.aim.z += 4.0 * (randf() - 0.5)
		cog.aim.y = cog.actor.global_position.y
	_move_toward(cog, cog.aim, delta)


func _begin_return(cog: Walker) -> void:
	cog.mode = "back"
	cog.origin = cog.actor.global_position
	cog.goal = cog.points[cog.seg] if cog.points.size() >= 2 else cog.stand
	cog.age = 0.0
	cog.dur = maxf(cog.origin.distance_to(cog.goal) / _WALK, 0.05)
	_face(cog.actor, cog.goal - cog.origin)
	cog.actor.call("set_walking", true)


func _begin_turn(cog: Walker) -> void:
	if cog.points.size() < 2:
		_stand(cog)
		return
	var nxt := (cog.seg + 1) % cog.points.size()
	cog.mode = "turn"
	cog.age = 0.0
	cog.yaw0 = cog.actor.rotation.y
	cog.yaw1 = _yaw(cog.points[nxt] - cog.points[cog.seg], cog.yaw0)
	cog.actor.call("set_walking", true)


func _begin_walk(cog: Walker) -> void:
	var count := cog.points.size()
	if count < 2:
		_stand(cog)
		return
	var nxt := (cog.seg + 1) % count
	cog.origin = cog.points[cog.seg]
	cog.goal = cog.points[nxt]
	if cog.origin.distance_to(cog.goal) < 0.2:
		cog.seg = nxt
		cog.actor.global_position = cog.goal
		_begin_turn(cog)
		return
	cog.mode = "walk"
	cog.age = 0.0
	cog.dur = cog.origin.distance_to(cog.goal) / _WALK
	cog.actor.global_position = cog.origin
	_face(cog.actor, cog.goal - cog.origin)
	cog.actor.call("set_walking", true)


func _turn(cog: Walker, delta: float) -> void:
	cog.age += delta
	var along := clampf(cog.age / _TURN, 0.0, 1.0)
	cog.actor.rotation.y = lerp_angle(cog.yaw0, cog.yaw1, along)
	if along >= 1.0:
		_begin_walk(cog)


func _slide(cog: Walker, delta: float, looping: bool) -> void:
	cog.age += delta
	var along := clampf(cog.age / cog.dur, 0.0, 1.0)
	cog.actor.global_position = cog.origin.lerp(cog.goal, along)
	if along < 1.0:
		return
	if looping:
		cog.seg = (cog.seg + 1) % cog.points.size()
		_begin_turn(cog)
		return
	cog.actor.global_position = cog.goal
	if cog.points.size() >= 2:
		_begin_turn(cog)
	else:
		_stand(cog)


func _stand(cog: Walker) -> void:
	cog.mode = "stand"
	cog.actor.global_position = cog.stand
	cog.actor.rotation.y = cog.stand_yaw
	cog.actor.call("set_walking", false)


func _move_toward(cog: Walker, target: Vector3, delta: float) -> void:
	var dir := target - cog.actor.global_position
	dir.y = 0.0
	var dist := dir.length()
	if dist < 0.05:
		cog.actor.call("set_walking", false)
		return
	_face(cog.actor, dir)
	cog.actor.global_position += dir.normalized() * minf(_CHASE * delta, dist)
	cog.actor.call("set_walking", true)


func _near(cog: Walker, toon: Node3D, reach: float) -> bool:
	if toon == null:
		return false
	var offset := toon.global_position - cog.actor.global_position
	if absf(offset.y) >= _ALERT_Y:
		return false
	offset.y = 0.0
	return offset.length() < reach


func _face(actor: Node3D, dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	actor.rotation.y = atan2(-dir.x, -dir.z)


func _yaw(dir: Vector3, fallback: float) -> float:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return fallback
	return atan2(-dir.x, -dir.z)


func _heading(parent: Node3D, degrees: float) -> float:
	var heading := deg_to_rad(degrees)
	var forward := parent.global_transform.basis * Vector3(-sin(heading), cos(heading), 0.0)
	return atan2(-forward.x, -forward.z)


func _toon() -> Node3D:
	var host := get_parent()
	if host == null:
		return null
	return host.get_node_or_null("PlaygroundToon") as Node3D


func _prepare_nametags() -> void:
	var script := load("res://scenes/toons/nametags.gd") as GDScript
	var board := script.new() as Node
	board.name = "Nametags"
	add_child(board)
	var layer := CanvasLayer.new()
	layer.name = "CogNametags"
	layer.layer = 6
	add_child(layer)
	board.set("layer", layer)
	board.set("occlude", _blocked)
	_board = board


func _blocked(actor: Node3D, point: Vector3) -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	if cam.is_position_behind(point) or not cam.is_position_in_frustum(point):
		return true
	var tick := Engine.get_process_frames()
	if tick % 8 != int(actor.get_instance_id()) % 8:
		return bool(actor.get_meta("occ", false))
	var world := actor.get_world_3d()
	if world == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(cam.global_position, point)
	query.collide_with_areas = false
	var blocked := not world.direct_space_state.intersect_ray(query).is_empty()
	actor.set_meta("occ", blocked)
	return blocked


func _collect(node: Node, found: Dictionary) -> void:
	if node == null:
		return
	var node_name := str(node.name)
	if not found.has(node_name):
		found[node_name] = node
	for child in node.get_children():
		_collect(child, found)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}
