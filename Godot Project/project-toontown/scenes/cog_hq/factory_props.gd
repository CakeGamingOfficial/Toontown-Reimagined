class_name FactoryProps
extends Node

## The moving Sellbot Factory. Stompers, gears, barrels, lifts, the conveyor,
## crates, and goons come from SellbotLegFactorySpec. Defeated cog levels are
## remembered here until the foreman falls, which is when the suit part and
## merits are paid out.

const _PROPS := "res://assets/cog_hq/sellbot_factory_props.json"
const _GOON := "res://assets/cog_hq/goon.glb"
const _SMALL := "res://assets/cog_hq/audio/CHQ_FACT_stomper_small.ogg"
const _MED := "res://assets/cog_hq/audio/CHQ_FACT_stomper_med.ogg"
const _LARGE := "res://assets/cog_hq/audio/CHQ_FACT_stomper_large.ogg"
const _BEANS := preload("res://scenes/toons/jellybeans.gd")
const _ARRIVAL := preload("res://scenes/playgrounds/playground_toon.gd")
const _PLACES := preload("res://scenes/places/hood_places.gd")
const _STICK := 0.2
const _TURN := 0.95

static var _levels: Array[int] = []

var _time := 0.0
var _leaving := false
var _hurt_until: Dictionary = {}
var _taken: Dictionary = {}
var _stompers: Array[Dictionary] = []
var _gears: Array[Dictionary] = []
var _barrels: Array[Dictionary] = []
var _lifts: Array[Dictionary] = []
var _belts: Array[Dictionary] = []
var _crates: Array[Dictionary] = []
var _goons: Array[Dictionary] = []
var _goon_scene: PackedScene


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
	if host.scene_file_path.get_file() != "sellbot_factory.tscn":
		return
	if host.get_node_or_null("FactoryProps") != null:
		return
	var script := load("res://scenes/cog_hq/factory_props.gd") as GDScript
	var node := script.new() as Node
	node.name = "FactoryProps"
	host.add_child(node)


func _ready() -> void:
	_levels.clear()
	var host := get_parent()
	if host == null:
		return
	var found: Dictionary = {}
	_index(host, found)
	_read(found)


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
	_move_lifts()
	if body != null and not busy:
		_ride_belts(body, delta)
		_push_crates(body, delta)
		_grab_barrels(body)
		_move_goons(body, delta)
	else:
		_move_goons(null, delta)


func _index(node: Node, found: Dictionary) -> void:
	var node_name := String(node.name)
	if node_name.begins_with("stomper-") or node_name.begins_with("gear-") or node_name.begins_with("healBarrel-") or node_name.begins_with("gagBarrel-") or node_name.begins_with("beanBarrel-") or node_name.begins_with("lift-") or node_name.begins_with("conveyorBelt-") or node_name.begins_with("crate-") or node_name.begins_with("goon-"):
		found[node_name] = node
	for child in node.get_children():
		_index(child, found)


func _read(found: Dictionary) -> void:
	if not FileAccess.file_exists(_PROPS):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_PROPS))
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	for item in data.get("stompers", []):
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item
		var root := _node(found, "stomper-%s" % spec.get("id", 0))
		var head := _model(root)
		if head == null:
			continue
		_stompers.append({
			"id": int(spec.get("id", 0)),
			"head": head,
			"rest": head.position,
			"range": float(spec.get("range", 0.0)),
			"period": maxf(float(spec.get("period", 1.0)), 0.1),
			"phase": float(spec.get("phase", 0.0)),
			"damage": int(spec.get("damage", 0)),
			"last": 0.0,
			"voice": _stomp_voice(head, float(spec.get("range", 0.0))),
		})
	for item in data.get("gears", []):
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item
		var root := _node(found, "gear-%s" % spec.get("id", 0))
		var mesh := _model(root)
		if mesh == null:
			continue
		_gears.append({
			"id": int(spec.get("id", 0)),
			"mesh": mesh,
			"deg": float(spec.get("deg", 0.0)),
			"vertical": String(spec.get("orientation", "")) == "vertical",
		})
	for item in data.get("barrels", []):
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item
		var kind := String(spec.get("kind", ""))
		var root := _node(found, "%s-%s" % [kind, spec.get("id", 0)])
		if root == null:
			continue
		_barrels.append({
			"id": int(spec.get("id", 0)),
			"root": root,
			"kind": kind,
			"grab": int(spec.get("grab", 0)),
			"track": int(spec.get("track", 0)),
			"level": int(spec.get("level", 0)),
		})
	for item in data.get("lifts", []):
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item
		var root := _node(found, "lift-%s" % spec.get("id", 0))
		var mesh := _model(root)
		if mesh == null:
			continue
		var finish: Array = spec.get("end", [0.0, 0.0, 0.0])
		_lifts.append({
			"mesh": mesh,
			"rest": mesh.position,
			"rise": float(finish[2]) if finish.size() > 2 else 0.0,
			"duration": maxf(float(spec.get("duration", 1.0)), 0.1),
			"wait": maxf(float(spec.get("wait", 0.0)), 0.0),
		})
	for item in data.get("belts", []):
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item
		var root := _node(found, "conveyorBelt-%s" % spec.get("id", 0))
		if root == null:
			continue
		_belts.append({
			"root": root,
			"speed": float(spec.get("speed", 0.0)),
			"length": float(spec.get("length", 0.0)),
		})
	for item in data.get("crates", []):
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item
		var root := _node(found, "crate-%s" % spec.get("id", 0))
		if root == null:
			continue
		_crates.append({"root": root, "home": root.global_position})
	_goon_scene = load(_GOON) as PackedScene
	for item in data.get("goons", []):
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item
		var root := _node(found, "goon-%s" % spec.get("id", 0))
		if root == null or _goon_scene == null:
			continue
		var mesh := _goon_scene.instantiate() as Node3D
		if mesh == null:
			continue
		mesh.name = "Goon"
		root.add_child(mesh)
		mesh.scale = Vector3.ONE * float(spec.get("scale", 1.0))
		var forward := root.global_transform.basis.y
		forward.y = 0.0
		if forward.length_squared() < 0.0001:
			forward = -root.global_transform.basis.z
			forward.y = 0.0
		if forward.length_squared() < 0.0001:
			forward = Vector3.FORWARD
		forward = forward.normalized()
		_goons.append({
			"id": int(spec.get("id", 0)),
			"root": root,
			"basis": root.global_transform.basis,
			"forward": forward,
			"home": forward,
			"speed": float(spec.get("speed", 4.0)),
			"reach": float(spec.get("reach", 15.0)),
			"strength": int(spec.get("strength", 1)),
			"fov": float(spec.get("fov", 70.0)),
			"walked": 0.0,
			"alert": false,
		})


func _move_stompers(body: Node3D, busy: bool) -> void:
	for item in _stompers:
		var head: Node3D = item["head"]
		if head == null:
			continue
		var period := float(item["period"])
		var t := fposmod(_time / period + float(item["phase"]), 1.0)
		var span := float(item["range"])
		var along := 0.0
		if t < _STICK:
			along = 0.0
		elif t < _TURN:
			along = (t - _STICK) / (_TURN - _STICK)
		else:
			along = 1.0 - (t - _TURN) / (1.0 - _TURN)
		var rest: Vector3 = item["rest"]
		head.position = Vector3(rest.x, rest.y + span * (1.0 - along), rest.z)
		var last := float(item["last"])
		item["last"] = t
		var slammed := last < _TURN and t >= _TURN
		if not slammed:
			continue
		var voice: AudioStreamPlayer3D = item["voice"]
		if voice != null:
			voice.play()
		_crush_goons(head.global_position)
		if busy or body == null:
			continue
		if body.global_position.distance_to(head.global_position) <= 3.0:
			_hurt(int(item["damage"]), "stomp-%s" % item["id"])


func _spin_gears(delta: float, body: Node3D, busy: bool) -> void:
	for item in _gears:
		var mesh: Node3D = item["mesh"]
		if mesh == null:
			continue
		var axis := Vector3(1.0, 0.0, 0.0) if bool(item["vertical"]) else Vector3(0.0, 0.0, 1.0)
		mesh.rotate_object_local(axis, deg_to_rad(float(item["deg"])) * delta)
		if busy or body == null or not bool(item["vertical"]):
			continue
		if body.global_position.distance_to(mesh.global_position) <= 1.8:
			_hurt(3, "gear-%s" % item["id"])


func _move_lifts() -> void:
	for item in _lifts:
		var mesh: Node3D = item["mesh"]
		if mesh == null:
			continue
		var duration := float(item["duration"])
		var wait := float(item["wait"])
		var span := duration + wait
		var t := fposmod(_time, span * 2.0)
		var along := 0.0
		if t < wait:
			along = 0.0
		elif t < span:
			along = (t - wait) / duration
		elif t < span + wait:
			along = 1.0
		else:
			along = 1.0 - (t - span - wait) / duration
		var rest: Vector3 = item["rest"]
		mesh.position = rest + Vector3(0.0, 0.0, float(item["rise"]) * along)


func _ride_belts(body: CharacterBody3D, delta: float) -> void:
	for item in _belts:
		var root: Node3D = item["root"]
		if root == null:
			continue
		var local := root.to_local(body.global_position)
		var half := float(item["length"]) * 0.5
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
		body.global_position += dir.normalized() * float(item["speed"]) * delta


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
		var key := int(item["id"])
		if bool(_taken.get(key, false)):
			continue
		if body.global_position.distance_to(root.global_position) > 2.2:
			continue
		var kind := String(item["kind"])
		var grab := int(item["grab"])
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
			var loadout := ToonLoadout.for_selected()
			if loadout == null:
				continue
			var got := 0
			for _n in grab:
				if loadout.purchase(int(item["track"]), int(item["level"])) <= 0:
					break
				got += 1
			if got <= 0:
				continue
		else:
			continue
		_taken[key] = true
		root.visible = false


func _move_goons(body: Node3D, delta: float) -> void:
	for item in _goons:
		var root: Node3D = item["root"]
		if root == null or not is_instance_valid(root):
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
			var step := face * speed * delta
			root.global_position += step
		var origin: Basis = item["basis"]
		var base: Vector3 = item["forward"]
		var angle := base.signed_angle_to(face, Vector3.UP)
		root.global_transform = Transform3D(Basis(Vector3.UP, angle) * origin, root.global_position)


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


func _model(root: Node) -> Node3D:
	if root == null:
		return null
	var pivot := _pivot(root)
	var host: Node = pivot if pivot != null else root
	for child in host.get_children():
		if child is Node3D:
			return child
	return null


func _pivot(node: Node) -> Node:
	if String(node.name).findn("pivot") >= 0:
		return node
	for child in node.get_children():
		var found := _pivot(child)
		if found != null:
			return found
	return null


func _node(found: Dictionary, node_name: String) -> Node3D:
	var node: Variant = found.get(node_name)
	return node as Node3D


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
