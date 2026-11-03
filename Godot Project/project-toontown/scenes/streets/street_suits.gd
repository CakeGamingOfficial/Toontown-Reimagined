extends Node
class_name StreetSuits

const _COG := preload("res://scenes/cogs/street_cog.gd")

## DistributedSuitPlannerAI for one street. The street wants the average of its
## min and max, then drifts inside that range. An upkeep every 10 seconds
## creates only (deficit + 3) / 4 suits, and the whole district stops at 50.
## An established cog building keeps about 1.5 suits. Those suits walk out
## a side door and later walk back into one of the same department. Clients wake a pooled actor from a
## record. They do not pick DNA themselves.

const DEPTS: PackedStringArray = ["c", "l", "m", "s"]
const TOTAL_MAX_SUITS := 50
const SUIT_BUILDING_NUM_SUITS := 1.5
## SuitHoodInfo min and max for each street zone.
const HOOD := {
	1100: Vector2i(1, 5),
	1200: Vector2i(1, 5),
	1300: Vector2i(1, 5),
	2100: Vector2i(5, 15),
	2200: Vector2i(3, 10),
	2300: Vector2i(3, 10),
	3100: Vector2i(1, 5),
	3200: Vector2i(1, 5),
	3300: Vector2i(1, 5),
	4100: Vector2i(1, 5),
	4200: Vector2i(1, 5),
	4300: Vector2i(1, 5),
	5100: Vector2i(1, 5),
	5200: Vector2i(1, 5),
	5300: Vector2i(1, 5),
	9100: Vector2i(1, 5),
	9200: Vector2i(1, 5),
}
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
var street_slug := ""

var _points: Array[Vector3] = []
var _links: Array[PackedInt32Array] = []
var _route: PackedInt32Array = PackedInt32Array()
var _starts: Array[int] = []
var _nametags: Node
var _rider: CollisionObject3D
var _count := 0
var _zone := 0
var _street_min := 1
var _street_max := 5
var _base := 1
var _desired := 1
var _adjust := 0
var _upkeep := 10.0
var _adjust_left := 300.0
var _queue: Array[Dictionary] = []
var _pool: Dictionary = {}
var _tracks: Array = []
var _levels: Array = []
var _max_type := 6
var _catalog: Array = []
var _doors: Dictionary = {}
var _timing: Dictionary = {}
var _propeller: Dictionary = {}
var _living := 0
## False when this node only fills the district AI record and draws nothing.
var visuals := true
var district_id := -1
var _net_sig := ""
var _net_actors: Dictionary = {}
var _shader_done := false
var _shader_hold: Node


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
	node.set("street_slug", base)
	host.add_child(node)


func _ready() -> void:
	if not _load_street() or not _load_catalog():
		return
	_load_doors()
	_build_route()
	if _route.size() < 2:
		return
	if district_id < 0:
		district_id = ToonNet.district_id()
	if not visuals:
		_seed()
		return
	_build_layout()
	_prepare_nametags()
	var pool := Node3D.new()
	pool.name = "CogPool"
	add_child(pool)
	tree_exiting.connect(_park)
	var saved := _claim()
	if not saved.is_empty():
		_desired = int(saved.get("desired", _desired))
		_adjust = int(saved.get("adjust", _adjust))
		_upkeep = float(saved.get("upkeep", randf_range(10.0, 12.0)))
		_adjust_left = float(saved.get("adjust_left", randf_range(300.0, 310.0)))
		var raw_rows: Variant = saved.get("cogs", [])
		if raw_rows is Array:
			for item in raw_rows as Array:
				if item is Dictionary:
					_queue.append(item)
	else:
		# initTasks waits POP_UPKEEP_DELAY plus up to two seconds. The street
		# does not dump its whole population on the first frame.
		_upkeep = randf_range(10.0, 12.0)
		_adjust_left = randf_range(300.0, 310.0)
	if not ToonNet.is_authority():
		ToonNet.request_suits(district_id, street_slug)


func _process(delta: float) -> void:
	if not visuals:
		return
	if _nametags != null:
		_nametags.set("camera", get_viewport().get_camera_3d())
		_nametags.call("place")
	# Clip indexes, the suit shader, and the queued suit models are ready
	# before a cog is allowed to appear. That work used to land on the spawn frame.
	if _warm_step():
		return
	if not ToonNet.is_authority():
		if _warm_net():
			return
		_apply_net()
		StreetCog.bake_one()
		return
	if not _queue.is_empty():
		var job: Dictionary = _queue.pop_front()
		_spawn_state(job)
		_publish_net()
		return
	_warm_idle()
	_upkeep -= delta
	if _upkeep <= 0.0:
		_upkeep = randf_range(10.0, 12.0)
		_authorize()
	_adjust_left -= delta
	if _adjust_left <= 0.0:
		_adjust_left = randf_range(300.0, 310.0)
		_nudge()
	_publish_net()


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
	# Off-screen names do not need a ray. The ray walks the block's triangle
	# mesh, and doing that for every suit is what dropped the street.
	if cam.is_position_behind(point) or not cam.is_position_in_frustum(point):
		return true
	var tick := Engine.get_process_frames()
	var slot := int(actor.get_instance_id()) % 12
	if tick % 12 != slot:
		return bool(actor.get_meta("occ", false))
	var height := float(actor.get("height"))
	var head := actor.global_position + Vector3(0.0, height * 0.72, 0.0)
	var blocked := _sight_blocked(actor.get_world_3d(), cam.global_position, head)
	actor.set_meta("occ", blocked)
	return blocked


## A block is one solid: the sidewalk and the walls share a body. Skipping
## that body after a floor hit let the name show through the wall.
func _sight_blocked(world: World3D, origin: Vector3, point: Vector3) -> bool:
	if world == null:
		return false
	var space := world.direct_space_state
	var target := point
	var from := origin
	var steps := 0
	while steps < 2:
		steps += 1
		var span := from.distance_to(target)
		if span < 0.45:
			return false
		var query := PhysicsRayQueryParameters3D.create(from, target)
		query.collide_with_areas = false
		query.hit_back_faces = true
		query.collision_mask = 1
		var rider := _rider_rid()
		if rider.is_valid():
			query.exclude = [rider]
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return false
		var normal: Vector3 = hit["normal"]
		var hit_at: Vector3 = hit["position"]
		if hit_at.distance_to(target) < 0.45:
			return false
		if normal.y > 0.55:
			var dir := target - from
			if dir.length() < 0.05:
				return false
			dir = dir.normalized()
			var ahead := hit_at + dir * 0.3
			if ahead.distance_to(target) >= span - 0.05:
				return false
			from = ahead
			continue
		return true
	return false


func _rider_rid() -> RID:
	if _rider != null and is_instance_valid(_rider):
		return _rider.get_rid()
	var found := get_tree().root.find_child("Player", true, false) as CollisionObject3D
	_rider = found
	if _rider == null:
		return RID()
	return _rider.get_rid()

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
	_zone = int(data.get("zone", 0))
	var span: Vector2i = HOOD.get(_zone, Vector2i(_count, _count))
	_street_min = span.x
	_street_max = maxi(span.y, span.x)
	_base = int((_street_min + _street_max) / 2)
	if _base < 1:
		_base = maxi(_count, 1)
	_desired = _base
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


## Established suit buildings on this street. The count is the server's list.
func established_suit_buildings() -> int:
	var snap := ToonNet.latest("buildings:%d:%s" % [district_id, street_slug])
	var rows: Variant = snap.get("rows", [])
	if rows is Array:
		return (rows as Array).size()
	return 0


## The record a server would replicate. A client wakes a pooled actor from
## one of these and does not choose the suit itself.
## doSummonSingleCog. The named suit flies in at the street point closest
## to the toon. A level of -1 lets the street roll one, then clamps it to
## the range that cog type can actually be.
func summon_named(query: String, level: int, near: Vector3) -> String:
	var parsed := parse_summon(query)
	if String(parsed["name"]).is_empty():
		return "Name a cog. Try ~suit flunky, ~suit pp 5, or ~suit cold caller skelecog."
	var cog := _find_named(String(parsed["name"]))
	if cog.is_empty():
		return "Unknown cog \"%s\"." % String(parsed["name"])
	if _route.size() < 2 or _points.is_empty():
		return "This street has no cog spawn points."
	var cog_type := int(cog.get("type", 1))
	var rolled := cog_type
	if level > 0:
		rolled = level
	elif not _levels.is_empty():
		rolled = int(_levels[randi() % _levels.size()])
	cog["level"] = clampi(rolled, cog_type, cog_type + 4)
	if bool(parsed["skeleton"]):
		dress_skeleton(cog)
	# A client does not create the suit. The district AI does, then everyone plays it.
	if not ToonNet.is_authority():
		ToonNet.ask_summon(district_id, street_slug, query, int(cog["level"]), near)
		return "A Level %d %s is flying in." % [int(cog["level"]), String(cog["name"])]
	if not visuals:
		return _summon_parked(cog, near)
	var net_id := ToonNet.next_id()
	cog["do_id"] = net_id
	_queue.push_front({
		"cog": cog,
		"do_id": net_id,
		"slot": _closest_slot(near),
		"phase": -1,
	})
	return "A Level %d %s is flying in." % [int(cog["level"]), String(cog["name"])]


## ~suit flunky skelecog. createNewSuit's skelecog flag, then Suit.makeSkeleton.
static func parse_summon(query: String) -> Dictionary:
	var skeleton := false
	var names := PackedStringArray()
	for part in query.split(" ", false):
		var key := part.to_lower()
		if key == "skelecog" or key == "skele" or key == "skeleton" or key == "sk":
			skeleton = true
		else:
			names.append(part)
	return {"name": " ".join(names), "skeleton": skeleton}


## Suit.makeSkeleton. The robot mesh already includes the 1.0173 scale. The
## suit's own scale is applied when it appears. The displayed name is Skelecog.
static func dress_skeleton(cog: Dictionary) -> void:
	var suit_body := String(cog.get("body", "c"))
	cog["name"] = "Skelecog"
	cog["skeleton"] = true
	cog["model"] = "res://assets/cogs/suits/robot_%s.glb" % suit_body
	cog["walk"] = "res://assets/cogs/anims/robot_%s/walk.walk" % suit_body
	cog["neutral"] = "res://assets/cogs/anims/robot_%s/neutral.walk" % suit_body
	cog["landing"] = "res://assets/cogs/anims/robot_%s/landing.walk" % suit_body
	cog["scale"] = float(cog.get("scale", 1.0))


## ~spawnbuilding sellbot 1 takes the closest toon building and makes it that
## many stories of that department. ~spawnbuilding flunky does the same as a
## real takeover by that cog: the street rolls the level and the floor count.
## A building that is already a cog building is skipped.
func spawn_building(query: String, near: Vector3) -> String:
	var buildings := get_parent().get_node_or_null("StreetBuildings")
	if buildings == null or not buildings.has_method("nearest_block"):
		return "Cog buildings can only be spawned on a street."
	var args := query.split(" ", false)
	var track := ""
	var floors := 0
	var cog: Dictionary = {}
	if not args.is_empty():
		track = String(buildings.call("track_named", String(args[0])))
	if track != "":
		if args.size() < 2 or not String(args[1]).is_valid_int():
			return "Use ~spawnbuilding sellbot 1. The floor count is 1 through 5."
		floors = int(args[1])
		if floors < 1 or floors > 5:
			return "Floor count must be from 1 to 5."
	else:
		cog = _find_named(query)
		if cog.is_empty():
			return "Invalid Cog specified."
		track = String(cog.get("dept", "c"))
	var shop: Dictionary = buildings.call("nearest_block", near, false)
	if shop.is_empty():
		if cog.is_empty():
			return "Couldn't spawn a building."
		return "Couldn't spawn building with Cog '%s'." % String(cog.get("name", query))
	var difficulty := 0
	if cog.is_empty():
		difficulty = int(buildings.call("difficulty_for_floors", floors))
	else:
		var cog_type := int(cog.get("type", 1))
		var level := cog_type
		if not _levels.is_empty():
			level = int(_levels[randi() % _levels.size()])
		level = clampi(level, cog_type, cog_type + 4)
		floors = int(buildings.call("floors_for", level))
		difficulty = int(buildings.call("takeover_index", level))
	var plan := {
		"block": int(shop.get("block", 0)),
		"track": track,
		"difficulty": difficulty,
		"floors": floors,
		"title": String(shop.get("title", "")),
	}
	if not _apply_building("spawn", plan):
		if cog.is_empty():
			return "Couldn't spawn a building."
		return "Couldn't spawn building with Cog '%s'." % String(cog.get("name", query))
	if cog.is_empty():
		return "Successfully spawned a %d-story %s building." % [floors, String(buildings.call("dept_name", track))]
	return "Successfully spawned building with Cog '%s'!" % String(cog.get("name", query))


## The closest cog building is taken back, unless toons are already inside it.
func free_building(near: Vector3) -> String:
	var buildings := get_parent().get_node_or_null("StreetBuildings")
	if buildings == null or not buildings.has_method("nearest_block"):
		return "Couldn't free building."
	var shop: Dictionary = buildings.call("nearest_block", near, true)
	if shop.is_empty():
		return "Couldn't free building."
	var block := int(shop.get("block", 0))
	var traffic := get_node_or_null("/root/StreetTraffic")
	if traffic == null:
		return "Couldn't free building."
	var runs := traffic.get_node_or_null("BuildingRuns")
	if runs != null and runs.has_method("occupied") and bool(runs.call("occupied", district_id, street_slug, block)):
		return "Toons are currently taking back the building!"
	if not _apply_building("free", {"block": block}):
		return "Couldn't free building."
	return "Successfully took back building!"


func _apply_building(mode: String, plan: Dictionary) -> bool:
	if not ToonNet.is_authority():
		ToonNet.ask_building(district_id, street_slug, mode, plan)
		return true
	var traffic := get_node_or_null("/root/StreetTraffic")
	if traffic == null:
		return false
	if mode == "free":
		if not traffic.has_method("retake_building"):
			return false
		traffic.call("retake_building", district_id, street_slug, int(plan.get("block", 0)))
		return true
	if not traffic.has_method("start_takeover"):
		return false
	traffic.call("start_takeover", district_id, street_slug, plan)
	return true


func _summon_parked(cog: Dictionary, near: Vector3) -> String:
	var traffic := get_node_or_null("/root/StreetTraffic")
	if traffic == null or not traffic.has_method("inject_suit"):
		return "This street has no cog spawn points."
	var net_id := ToonNet.next_id()
	cog["do_id"] = net_id
	traffic.call("inject_suit", district_id, street_slug, cog, _closest_slot(near))
	return "A Level %d %s is flying in." % [int(cog["level"]), String(cog["name"])]


func roster() -> Array:
	var rows: Array = []
	for child in get_children():
		if child.has_method("capture"):
			rows.append(child.call("capture"))
	for job in _queue:
		rows.append(job)
	return rows


func _spawn_state(state: Dictionary) -> Node3D:
	var cog: Variant = state.get("cog", {})
	if not (cog is Dictionary) or (cog as Dictionary).is_empty():
		return null
	var suit := _take_suit(cog as Dictionary)
	var takeover: Variant = state.get("takeover", {})
	if takeover is Dictionary:
		suit.set_meta("takeover", takeover)
	var playback := not ToonNet.is_authority()
	if playback:
		suit.set_meta("playback", true)
	elif not bool(suit.get_meta("hooked", false)):
		suit.connect("departed", _on_departed.bind(suit))
		suit.set_meta("hooked", true)
	var resume := state
	if int(state.get("phase", -1)) < 0:
		resume = {}
	_living += 1
	suit.call("setup", cog, _points, _route, int(state.get("slot", 0)), _timing, _propeller, resume)
	var net_id := int(state.get("do_id", (cog as Dictionary).get("do_id", 0)))
	suit.set_meta("do_id", net_id)
	return suit


func _claim() -> Dictionary:
	var traffic := get_node_or_null("/root/StreetTraffic")
	if traffic == null or not traffic.has_method("claim"):
		return {}
	var claimed: Variant = traffic.call("claim", district_id, street_slug)
	if claimed is Dictionary:
		return claimed
	return {}


func _park() -> void:
	if street_slug.is_empty() or _route.size() < 2:
		return
	var traffic := get_node_or_null("/root/StreetTraffic")
	if traffic == null or not traffic.has_method("hold"):
		return
	var cogs: Array = []
	var leaving: Array[Node] = []
	for child in get_children():
		if child.has_method("capture"):
			leaving.append(child)
	for child in leaving:
		cogs.append(child.call("capture"))
		_keep(traffic, child)
	for job in _queue:
		cogs.append(job)
	_queue.clear()
	var holder := get_node_or_null("CogPool")
	if holder != null:
		var parked: Array[Node] = []
		for child in holder.get_children():
			parked.append(child)
		for child in parked:
			_keep(traffic, child)
	traffic.call("hold", district_id, street_slug, _record(cogs))


func _authorize() -> void:
	var have_buildings := _count_building_suits()
	var building_target := int(float(established_suit_buildings()) * SUIT_BUILDING_NUM_SUITS)
	var reserved := maxi(building_target - have_buildings, 0)
	var room := TOTAL_MAX_SUITS - reserved - _district_used()
	var deficit := _desired - (_living + _queue.size())
	var burst := int((deficit + 3) / 4)
	burst = mini(burst, room)
	while burst > 0:
		var traffic := get_node_or_null("/root/StreetTraffic")
		var plan := {}
		if traffic != null and traffic.has_method("claim_takeover"):
			plan = traffic.call("claim_takeover", district_id, street_slug)
		var cog := _pick_cog() if plan.is_empty() else _pick_planned(plan)
		if cog.is_empty():
			if not plan.is_empty() and traffic != null:
				traffic.call("release_takeover", district_id, street_slug, int(plan.get("block", 0)))
			break
		var net_id := ToonNet.next_id()
		cog["do_id"] = net_id
		var job := {
			"cog": cog,
			"do_id": net_id,
			"slot": _open_slot(),
			"phase": -1,
		}
		if not plan.is_empty():
			job["takeover"] = plan
			job["take_stage"] = "lane"
		_queue.append(job)
		burst -= 1
	_queue_building_suits()


func _load_doors() -> void:
	var path := json_path.replace("_suits.json", "_buildings.json")
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return
	var blocks: Array = (parsed as Dictionary).get("blocks", [])
	for item in blocks:
		if not (item is Dictionary):
			continue
		var block: Dictionary = item
		var doors: Array = block.get("doors", [])
		if not doors.is_empty():
			_doors[int(block.get("block", 0))] = doors


func _queue_building_suits() -> void:
	var rows := _established_rows()
	var target := int(float(rows.size()) * SUIT_BUILDING_NUM_SUITS)
	var have := _count_building_suits()
	var burst := int((target - have + 3) / 4)
	burst = mini(burst, TOTAL_MAX_SUITS - _district_used())
	while burst > 0:
		var row := _pick_established(rows)
		if row.is_empty():
			return
		var doors: Array = _doors.get(int(row.get("block", 0)), [])
		if doors.is_empty():
			return
		var door: Dictionary = doors[randi() % doors.size()]
		var dest := _return_door(String(row.get("track", "c")), door)
		var cog := _pick_track(String(row.get("track", "c")))
		if cog.is_empty():
			return
		var exit := _as_vec(door.get("exit", []))
		var span := StreetCog.exit_span(_as_vec(door.get("pos", [])), exit)
		var net_id := ToonNet.next_id()
		cog["do_id"] = net_id
		_queue.append({
			"cog": cog,
			"do_id": net_id,
			"slot": _closest_slot(exit),
			"phase": 0,
			"fly": 0.0,
			"from_building": true,
			"building_suit": true,
			"door": door.get("pos", []),
			"exit": door.get("exit", []),
			"return_door": dest.get("pos", []),
			"return_exit": dest.get("exit", []),
			"return_block": int(dest.get("block", row.get("block", -1))),
			"position": span["start"],
			"yaw": span["yaw"],
		})
		burst -= 1


func _return_door(track: String, fallback: Dictionary) -> Dictionary:
	var choices: Array = []
	for item in _established_rows():
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		if String(row.get("track", "")) != track:
			continue
		var doors: Array = _doors.get(int(row.get("block", 0)), [])
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


func _established_rows() -> Array:
	var snap := ToonNet.latest("buildings:%d:%s" % [district_id, street_slug])
	var rows: Variant = snap.get("rows", [])
	var kept: Array = []
	if not (rows is Array):
		return kept
	for item in rows as Array:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		var state := String(row.get("state", "suit"))
		if state == "becoming" or state == "clearing":
			continue
		kept.append(row)
	return kept


func _pick_established(rows: Array) -> Dictionary:
	var open: Array = []
	for item in rows:
		if item is Dictionary and not _doors.get(int((item as Dictionary).get("block", 0)), []).is_empty():
			open.append(item)
	if open.is_empty():
		return {}
	return open[randi() % open.size()]


func _count_building_suits() -> int:
	var count := 0
	for child in get_children():
		if child.has_method("capture") and bool(child.get_meta("building_suit", false)):
			count += 1
	for job in _queue:
		if bool(job.get("building_suit", false)):
			count += 1
	return count


func _pick_track(track: String) -> Dictionary:
	if _levels.is_empty() or _catalog.is_empty():
		return {}
	var level := int(_levels[randi() % _levels.size()])
	var low := maxi(level - 4, 1)
	var high := mini(level, _max_type)
	if high < low:
		high = low
	var cog_type := randi_range(low, high)
	var dept := DEPTS.find(track)
	if dept < 0:
		dept = 0
	var index := dept * 8 + cog_type - 1
	if index < 0 or index >= _catalog.size():
		return {}
	var source: Dictionary = _catalog[index]
	var cog := source.duplicate() as Dictionary
	cog["level"] = level
	return cog


func _as_vec(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and (value as Array).size() >= 3:
		var row: Array = value
		return Vector3(float(row[0]), float(row[1]), float(row[2]))
	return Vector3.ZERO


func finish_takeover(plan: Dictionary) -> void:
	var traffic := get_node_or_null("/root/StreetTraffic")
	if traffic != null and traffic.has_method("start_takeover"):
		traffic.call("start_takeover", district_id, street_slug, plan)


func _nudge() -> void:
	if _street_max == 0:
		return
	var choices: Array[int] = [-2, -1, -1, 0, 0, 0, 1, 1, 2]
	_adjust += choices[randi() % choices.size()]
	var wanted := _base + _adjust
	if wanted < _street_min:
		_adjust = _street_min - _base
	elif wanted > _street_max:
		_adjust = _street_max - _base
	_desired = _base + _adjust


func _district_used() -> int:
	var other := 0
	var traffic := get_node_or_null("/root/StreetTraffic")
	if traffic != null and traffic.has_method("suit_total"):
		other = int(traffic.call("suit_total"))
	return other + _living + _queue.size()


func _take_suit(cog: Dictionary) -> Node3D:
	var code := str(cog.get("code", ""))
	var traffic := get_node_or_null("/root/StreetTraffic")
	if traffic != null and traffic.has_method("take_actor"):
		var reused: Variant = traffic.call("take_actor", code)
		if reused is Node3D and is_instance_valid(reused):
			_adopt(reused)
			return reused
	var waiting: Array = _pool.get(code, [])
	if not waiting.is_empty():
		var local: Variant = waiting.pop_back()
		_pool[code] = waiting
		if local is Node3D and is_instance_valid(local):
			_adopt(local)
			return local
	var suit := _COG.new() as Node3D
	add_child(suit)
	return suit


## A warmed suit still belongs to CogPool. add_child refuses a node that
## already has a parent, so the cog never reached the street and could not
## be walked into.
func _adopt(actor: Node) -> void:
	if actor.get_parent() == self:
		return
	if actor.get_parent() != null:
		actor.get_parent().remove_child(actor)
	add_child(actor)


func _keep(traffic: Node, suit: Node) -> void:
	if not is_instance_valid(suit):
		return
	if suit.has_method("retire"):
		suit.call("retire")
	suit.set_meta("pooled", true)
	if traffic.has_method("keep_actor"):
		traffic.call("keep_actor", str(suit.get("cog_code")), suit)


## Spread arrivals around the loop. Two suits should not land on the same corner.
func _open_slot() -> int:
	var count := _route.size()
	if count < 1:
		return 0
	var taken := PackedInt32Array()
	for child in get_children():
		if child.has_method("lane_slot"):
			taken.append(int(child.call("lane_slot")))
	for job in _queue:
		taken.append(int(job.get("slot", 0)))
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


func _on_departed(suit: Node) -> void:
	_living = maxi(_living - 1, 0)
	if not is_instance_valid(suit) or bool(suit.get_meta("discard", false)):
		return
	if suit.has_method("retire"):
		suit.call("retire")
	suit.set_meta("pooled", true)
	var code := str(suit.get("cog_code"))
	var traffic := get_node_or_null("/root/StreetTraffic")
	if traffic != null and traffic.has_method("keep_actor") and int(traffic.call("suit_total", district_id)) + _pool_size() < TOTAL_MAX_SUITS:
		traffic.call("keep_actor", code, suit)
		return
	var waiting: Array = _pool.get(code, [])
	waiting.append(suit)
	_pool[code] = waiting
	var holder := get_node_or_null("CogPool")
	if holder != null:
		suit.reparent(holder)


func _pool_size() -> int:
	var count := 0
	for code in _pool:
		var waiting: Array = _pool[code]
		count += waiting.size()
	return count


func _closest_slot(near: Vector3) -> int:
	var best := 0
	var best_distance := INF
	var flat := Vector2(near.x, near.z)
	for index in _route.size():
		var point := _points[_route[index]]
		var distance := flat.distance_squared_to(Vector2(point.x, point.z))
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


func _find_named(query: String) -> Dictionary:
	return match_cog(_catalog, query)


static func match_cog(catalog: Array, query: String) -> Dictionary:
	var wanted := cog_key(query)
	if wanted.is_empty():
		return {}
	var prefix: Dictionary = {}
	for item in catalog:
		if not (item is Dictionary):
			continue
		var cog := (item as Dictionary).duplicate() as Dictionary
		var code := cog_key(String(cog.get("code", "")))
		var label := cog_key(String(cog.get("name", "")))
		if wanted == code or wanted == label:
			return cog
		if code.begins_with(wanted) or label.begins_with(wanted):
			prefix[String(cog.get("name", ""))] = cog
	if prefix.size() == 1:
		var only: Variant = prefix.values()[0]
		if only is Dictionary:
			return only
	return {}


static func cog_key(raw: String) -> String:
	var folded := raw.to_lower()
	var kept := ""
	for index in folded.length():
		var letter := folded.substr(index, 1)
		var alpha := letter >= "a" and letter <= "z"
		var digit := letter >= "0" and letter <= "9"
		if alpha or digit:
			kept += letter
	return kept


func _record(cogs: Array) -> Dictionary:
	return {
		"points": _points,
		"route": _route,
		"count": _desired,
		"desired": _desired,
		"base": _base,
		"street_min": _street_min,
		"street_max": _street_max,
		"adjust": _adjust,
		"upkeep": _upkeep,
		"adjust_left": _adjust_left,
		"catalog": _catalog,
		"levels": _levels,
		"tracks": _tracks,
		"max_type": _max_type,
		"cogs": cogs,
		"waits": [],
		"district": district_id,
	}


func capture_record() -> Dictionary:
	var record := _record(roster())
	record["district"] = district_id
	record["slug"] = street_slug
	return record


func _seed() -> void:
	var traffic := get_node_or_null("/root/StreetTraffic")
	if traffic == null or not traffic.has_method("hold"):
		return
	if traffic.has_method("remember_state"):
		traffic.call("remember_state")
	if traffic.has_method("has_street") and bool(traffic.call("has_street", district_id, street_slug)):
		return
	traffic.call("hold", district_id, street_slug, _record([]))


func _publish_net() -> void:
	var rows := roster()
	var parts: PackedStringArray = []
	for item in rows:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		parts.append("%s:%s:%s:%s:%s" % [row.get("do_id", 0), row.get("phase", -1), row.get("pathed", false), row.get("slot", 0), row.get("edges", 0)])
	var sig := "|".join(parts)
	if sig == _net_sig:
		return
	_net_sig = sig
	ToonNet.publish("suits:%d:%s" % [district_id, street_slug], {"rows": rows})


func _warm_step() -> bool:
	if StreetCog.index_next():
		return true
	if not _shader_done:
		_warm_shader()
		_shader_done = true
		return true
	if is_instance_valid(_shader_hold):
		_shader_hold.queue_free()
		_shader_hold = null
	var queued := _pending_code(true)
	if not queued.is_empty():
		_warm_code(queued)
		return true
	return false


func _warm_idle() -> void:
	var extra := _pending_code(false)
	if not extra.is_empty():
		_warm_code(extra)
		return
	StreetCog.bake_one()


func _warm_net() -> bool:
	var snap := ToonNet.latest("suits:%d:%s" % [district_id, street_slug])
	var raw: Variant = snap.get("rows", [])
	if not (raw is Array):
		return false
	for item in raw as Array:
		if not (item is Dictionary):
			continue
		var cog: Variant = (item as Dictionary).get("cog", {})
		if cog is Dictionary and not _code_ready(str((cog as Dictionary).get("code", ""))):
			_warm_code(cog)
			return true
	return false


func _pending_code(queue_only: bool) -> Dictionary:
	if queue_only:
		for job in _queue:
			var cog: Variant = job.get("cog", {})
			if cog is Dictionary and not _code_ready(str((cog as Dictionary).get("code", ""))):
				return cog
		return {}
	for item in _catalog:
		if item is Dictionary and not _code_ready(str((item as Dictionary).get("code", ""))):
			return item
	return {}


func _code_ready(code: String) -> bool:
	if code.is_empty():
		return true
	var waiting: Array = _pool.get(code, [])
	if not waiting.is_empty():
		return true
	var traffic := get_node_or_null("/root/StreetTraffic")
	if traffic != null and traffic.has_method("has_actor"):
		return bool(traffic.call("has_actor", code))
	return false


func _warm_code(cog: Dictionary) -> void:
	var code := str(cog.get("code", ""))
	if code.is_empty() or _code_ready(code):
		return
	var holder := get_node_or_null("CogPool")
	if holder == null:
		return
	var suit := _COG.new() as Node3D
	holder.add_child(suit)
	suit.call("preload_suit", cog, _timing, _propeller)
	var waiting: Array = _pool.get(code, [])
	waiting.append(suit)
	_pool[code] = waiting


## The first on-screen suit used to compile cog_shade.gdshader. Draw it once up front.
func _warm_shader() -> void:
	var view := SubViewport.new()
	view.name = "CogShaderWarm"
	view.size = Vector2i(8, 8)
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var camera := Camera3D.new()
	camera.current = true
	view.add_child(camera)
	var card := MeshInstance3D.new()
	card.mesh = QuadMesh.new()
	card.position = Vector3(0.0, 0.0, -2.0)
	var material := ShaderMaterial.new()
	material.shader = load("res://scenes/cogs/cog_shade.gdshader")
	material.set_shader_parameter("use_albedo_texture", 0.0)
	material.set_shader_parameter("albedo_color", Color.WHITE)
	card.material_override = material
	view.add_child(card)
	add_child(view)
	_shader_hold = view


func _apply_net() -> void:
	var snap := ToonNet.latest("suits:%d:%s" % [district_id, street_slug])
	var raw: Variant = snap.get("rows", [])
	if not (raw is Array):
		return
	var seen: Dictionary = {}
	var spawned := false
	for item in raw as Array:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		if int(row.get("phase", -1)) < 0:
			continue
		var net_id := int(row.get("do_id", 0))
		if net_id == 0:
			continue
		seen[net_id] = true
		var have: Variant = _net_actors.get(net_id)
		if have is Node3D and is_instance_valid(have):
			if (have as Node).has_method("follow_net"):
				(have as Node).call("follow_net", row)
			continue
		if spawned:
			continue
		var suit := _spawn_state(row)
		if suit != null:
			_net_actors[net_id] = suit
			spawned = true
	var gone: Array = []
	for net_id in _net_actors.keys():
		if not seen.has(net_id):
			gone.append(net_id)
	for net_id in gone:
		var actor: Variant = _net_actors[net_id]
		_net_actors.erase(net_id)
		if actor is Node and is_instance_valid(actor):
			if (actor as Node).has_method("retire"):
				(actor as Node).call("retire")
			(actor as Node).queue_free()


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


func _pick_planned(plan: Dictionary) -> Dictionary:
	if _catalog.is_empty():
		return {}
	var level := int(plan.get("level", 1))
	var low := maxi(level - 4, 1)
	var high := mini(level, _max_type)
	if high < low:
		high = low
	var cog_type := randi_range(low, high)
	var dept := DEPTS.find(String(plan.get("track", "c")))
	if dept < 0:
		dept = 0
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
