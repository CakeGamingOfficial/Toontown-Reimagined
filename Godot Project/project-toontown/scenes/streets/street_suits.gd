extends Node
class_name StreetSuits

const _COG := preload("res://scenes/cogs/street_cog.gd")

## Spawns the original street population and keeps the suit graph in the scene.
## Cog HQ streets are not in the map. Suit nametags do not start a battle.

const DEPTS: PackedStringArray = ["c", "l", "m", "s"]
const STREETS := {
	"silly_street": "res://assets/neighborhoods/toontown_central/streets/silly_street_suits.json",
	"loopy_lane": "res://assets/neighborhoods/toontown_central/streets/loopy_lane_suits.json",
	"punchline_place": "res://assets/neighborhoods/toontown_central/streets/punchline_place_suits.json",
	"barnacle_boulevard": "res://assets/neighborhoods/donalds_dock/streets/barnacle_boulevard_suits.json",
	"seaweed_street": "res://assets/neighborhoods/donalds_dock/streets/seaweed_street_suits.json",
	"lighthouse_lane": "res://assets/neighborhoods/donalds_dock/streets/lighthouse_lane_suits.json",
	"oak_street": "res://assets/neighborhoods/daisy_gardens/streets/oak_street_suits.json",
	"elm_street": "res://assets/neighborhoods/daisy_gardens/streets/elm_street_suits.json",
	"maple_street": "res://assets/neighborhoods/daisy_gardens/streets/maple_street_suits.json",
	"baritone_boulevard": "res://assets/neighborhoods/minnies_melodyland/streets/baritone_boulevard_suits.json",
	"alto_avenue": "res://assets/neighborhoods/minnies_melodyland/streets/alto_avenue_suits.json",
	"tenor_terrace": "res://assets/neighborhoods/minnies_melodyland/streets/tenor_terrace_suits.json",
	"sleet_street": "res://assets/neighborhoods/the_burrrgh/streets/sleet_street_suits.json",
	"walrus_way": "res://assets/neighborhoods/the_burrrgh/streets/walrus_way_suits.json",
	"polar_place": "res://assets/neighborhoods/the_burrrgh/streets/polar_place_suits.json",
	"pajama_place": "res://assets/neighborhoods/donalds_dreamland/streets/pajama_place_suits.json",
	"lullaby_lane": "res://assets/neighborhoods/donalds_dreamland/streets/lullaby_lane_suits.json",
}

var json_path := ""

var _points: Array[Vector3] = []
var _links: Array[PackedInt32Array] = []
var _route: PackedInt32Array = PackedInt32Array()
var _starts: Array[int] = []
var _nametags: Node
var _count := 0
var _tracks: Array = []
var _levels: Array = []
var _max_type := 6
var _catalog: Array = []
var _timing: Dictionary = {}
var _propeller: Dictionary = {}
var _living := 0
var _filling := false


static func attach(host: Node3D) -> void:
	if Engine.is_editor_hint() or host.get_node_or_null("StreetSuits") != null:
		return
	var base := host.scene_file_path.get_file().get_basename()
	if not STREETS.has(base):
		return
	var path := str(STREETS[base])
	if not FileAccess.file_exists(path):
		return
	var script := load("res://scenes/streets/street_suits.gd") as GDScript
	var node := script.new() as Node
	node.name = "StreetSuits"
	node.set("json_path", path)
	host.add_child(node)


func _ready() -> void:
	if not _load_street() or not _load_catalog():
		return
	_build_route()
	if _route.size() < 2:
		return
	_build_layout()
	_prepare_nametags()
	_filling = true
	_fill()


func _process(_delta: float) -> void:
	if _nametags == null:
		return
	_nametags.set("camera", get_viewport().get_camera_3d())
	_nametags.call("place")


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
	board.set("occlude", _nametag_blocked)
	_nametags = board


## A wall between the camera and the suit hides the card. Floors do not.
func _nametag_blocked(actor: Node3D, point: Vector3) -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var height := float(actor.get("height"))
	var head := actor.global_position + Vector3(0.0, height * 0.72, 0.0)
	if cam.is_position_behind(point) and cam.is_position_behind(head):
		return true
	# A full ray against every building, every frame, is what dropped streets
	# to a handful of frames. Recheck each suit a few times a second.
	var tick := Engine.get_process_frames()
	if tick % 4 != int(actor.get_instance_id()) % 4 and actor.has_meta("occ"):
		return bool(actor.get_meta("occ"))
	if cam.global_position.distance_squared_to(head) > 90.0 * 90.0:
		actor.set_meta("occ", false)
		return false
	var origin := cam.global_position + cam.global_basis.z * 3.0
	var world := actor.get_world_3d()
	var blocked := _sight_blocked(world, origin, head) or _sight_blocked(world, origin, point)
	actor.set_meta("occ", blocked)
	return blocked


func _sight_blocked(world: World3D, origin: Vector3, point: Vector3) -> bool:
	if world == null:
		return false
	var space := world.direct_space_state
	var skip: Array[RID] = []
	var total := origin.distance_to(point)
	if total < 0.05:
		return false
	for _step in 6:
		var query := PhysicsRayQueryParameters3D.create(origin, point)
		query.collide_with_areas = false
		query.hit_back_faces = true
		query.exclude = skip
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return false
		var normal: Vector3 = hit["normal"]
		var hit_at: Vector3 = hit["position"]
		if origin.distance_to(hit_at) < 0.35:
			var near_rid: RID = hit["rid"]
			skip.append(near_rid)
			continue
		if origin.distance_to(hit_at) + 0.2 >= total:
			return false
		if normal.y > 0.55 or _not_a_wall(hit):
			var rid: RID = hit["rid"]
			skip.append(rid)
			continue
		return true
	return false


## Curbs and the toon are not walls. A short solid does not hide the card.
func _not_a_wall(hit: Dictionary) -> bool:
	var collider := hit.get("collider") as Object
	if collider is CharacterBody3D:
		return true
	if not collider is Node3D:
		return false
	var host := (collider as Node3D).get_parent() as MeshInstance3D
	if host == null or host.mesh == null:
		return false
	var box := host.global_transform * host.get_aabb()
	return box.size.y < 1.6


func _load_street() -> bool:
	if not FileAccess.file_exists(json_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	var raw_points: Array = data.get("points", [])
	for item in raw_points:
		var row: Array = item
		# DNA stand height is -0.5, a half unit into the sidewalk at y = 0.
		# Lifting that to 0 leaves the suit hovering above the street.
		_points.append(Vector3(float(row[0]), float(row[1]), float(row[2])))
	_links.resize(_points.size())
	for index in _points.size():
		_links[index] = PackedInt32Array()
	var raw_edges: Array = data.get("edges", [])
	for item in raw_edges:
		var edge: Array = item
		var a := int(edge[0])
		var b := int(edge[1])
		if a < 0 or b < 0 or a >= _points.size() or b >= _points.size() or a == b:
			continue
		if not _links[a].has(b):
			_links[a].append(b)
		if not _links[b].has(a):
			_links[b].append(a)
	for index in _links.size():
		if not _links[index].is_empty():
			_starts.append(index)
	_count = int(data.get("count", 0))
	_tracks = data.get("tracks", [])
	_levels = data.get("levels", [])
	_max_type = int(data.get("max_type", 6))
	return not _points.is_empty() and not _starts.is_empty() and _count > 0


## One directed loop. The street center stays on the cog's left, so the
## walk stays on the right sidewalk until the end, then comes back the other side.
func _build_route() -> void:
	var start := -1
	for index in _links.size():
		if _links[index].size() == 2:
			start = index
			break
	if start < 0 and not _starts.is_empty():
		start = _starts[0]
	if start < 0:
		return
	var route := PackedInt32Array()
	var prev := -1
	var cur := start
	var guard := _points.size() + 2
	while guard > 0:
		guard -= 1
		route.append(cur)
		var nxt := _next_lane(prev, cur)
		if nxt < 0 or nxt == start:
			break
		prev = cur
		cur = nxt
	if route.size() < 2:
		return
	if _right_hand_score(route) < 0.0:
		var flipped := PackedInt32Array()
		var index := route.size() - 1
		while index >= 0:
			flipped.append(route[index])
			index -= 1
		route = flipped
	_route = route


func _next_lane(prev: int, cur: int) -> int:
	var options := _links[cur]
	if options.is_empty():
		return -1
	if prev < 0:
		return int(options[0])
	var incoming := Vector2(_points[cur].x - _points[prev].x, _points[cur].z - _points[prev].z)
	var best := -1
	var best_dot := -2.0
	var best_len := 0.0
	for index in options.size():
		var nxt := int(options[index])
		if nxt == prev:
			continue
		var step := Vector2(_points[nxt].x - _points[cur].x, _points[nxt].z - _points[cur].z)
		var length := step.length()
		var denom := incoming.length() * length
		var dot := 0.0 if denom < 0.0001 else incoming.dot(step) / denom
		if best < 0 or dot > best_dot + 0.02 or (absf(dot - best_dot) <= 0.02 and length < best_len):
			best = nxt
			best_dot = dot
			best_len = length
	return best


func _right_hand_score(route: PackedInt32Array) -> float:
	var center := Vector2.ZERO
	for point in _points:
		center += Vector2(point.x, point.z)
	center /= float(_points.size())
	var score := 0.0
	for index in route.size():
		var a := _points[route[index]]
		var b := _points[route[(index + 1) % route.size()]]
		var dir := Vector2(b.x - a.x, b.z - a.z)
		var left := Vector2(dir.y, -dir.x)
		score += left.dot(center - Vector2(a.x, a.z))
	return score


func _load_catalog() -> bool:
	var path := "res://assets/cogs/catalog.json"
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	_catalog = data.get("cogs", [])
	_timing = data.get("timing", {})
	_propeller = data.get("propeller", {})
	return not _catalog.is_empty()


func _build_layout() -> void:
	var paths := Node3D.new()
	paths.name = "SuitPaths"
	add_child(paths)
	for index in _points.size():
		var marker := Marker3D.new()
		marker.name = "SuitPoint_%d" % index
		marker.position = _points[index]
		paths.add_child(marker)
	var cells := Node3D.new()
	cells.name = "BattleCells"
	add_child(cells)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	var data: Dictionary = parsed
	var raw_cells: Array = data.get("cells", [])
	for index in raw_cells.size():
		var cell: Dictionary = raw_cells[index]
		var pos: Array = cell.get("pos", [])
		if pos.size() < 3:
			continue
		var zone := str(cell.get("zone", index))
		var area := Area3D.new()
		area.name = "BattleCell_%s" % zone
		area.collision_layer = 0
		area.collision_mask = 0
		area.monitoring = false
		area.monitorable = false
		area.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(float(cell.get("width", 20.0)), 4.0, float(cell.get("height", 20.0)))
		shape.shape = box
		area.add_child(shape)
		cells.add_child(area)


func _fill() -> void:
	var spawned := 0
	while spawned < _count:
		if spawned > 0:
			await get_tree().create_timer(randf_range(1.6, 3.4)).timeout
		if not is_inside_tree():
			return
		_spawn()
		spawned += 1
	_filling = false


func _spawn() -> void:
	if _living >= _count or _starts.is_empty():
		return
	var cog := _pick_cog()
	if cog.is_empty():
		return
	var suit := _COG.new() as Node3D
	add_child(suit)
	suit.connect("departed", _on_departed)
	suit.call("setup", cog, _points, _route, randi() % _route.size(), _timing, _propeller)
	_living += 1


func _on_departed() -> void:
	_living -= 1
	if _filling or not is_inside_tree():
		return
	_replace()


func _replace() -> void:
	# POP_UPKEEP_DELAY is 10 seconds, plus up to 2 seconds of jitter.
	await get_tree().create_timer(randf_range(10.0, 12.0)).timeout
	if _filling or not is_inside_tree():
		return
	if _living < _count:
		_spawn()


func _pick_cog() -> Dictionary:
	if _levels.is_empty() or _catalog.is_empty():
		return {}
	var level := int(_levels[randi() % _levels.size()])
	var low := maxi(level - 4, 1)
	var high := mini(level, _max_type)
	if high < low:
		high = low
	var cog_type := randi_range(low, high)
	var dept := _pick_dept()
	var index := dept * 8 + cog_type - 1
	if index < 0 or index >= _catalog.size():
		return {}
	var source: Dictionary = _catalog[index]
	var cog := source.duplicate() as Dictionary
	cog["level"] = level
	return cog


func _pick_dept() -> int:
	# SuitBattleGlobals.pickFromFreqList rolls 0..99 against weights that sum to 100.
	var roll := randi_range(0, 99)
	var count := 0
	for index in _tracks.size():
		count += int(_tracks[index])
		if roll < count:
			return index
	return 0
