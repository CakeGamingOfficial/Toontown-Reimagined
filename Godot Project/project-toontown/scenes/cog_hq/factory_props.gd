class_name FactoryProps
extends Node

## The moving Sellbot Factory. Stompers, gears, barrels, lifts, the conveyor,
## crates, and goons come from SellbotLegFactorySpec. The crusher-cell floor,
## the signature and lookout camera triggers, and the spinning gear discs come
## from that same spec. Defeated cog levels are remembered here until the
## foreman falls, which is when the suit part and merits are paid out.

const _PROPS := "res://assets/cog_hq/sellbot_factory_props.json"
const _MOTION := "res://assets/cog_hq/facility_motion.json"
const _GOON := "res://assets/cog_hq/goon.glb"
const _SMALL := "res://assets/cog_hq/audio/CHQ_FACT_stomper_small.ogg"
const _MED := "res://assets/cog_hq/audio/CHQ_FACT_stomper_med.ogg"
const _LARGE := "res://assets/cog_hq/audio/CHQ_FACT_stomper_large.ogg"
const _BEANS := preload("res://scenes/toons/jellybeans.gd")
const _HOLIDAYS := preload("res://scenes/shticker/calendar_holidays.gd")
const _LABEL := preload("res://scenes/cog_hq/barrel_label.gd")
const _ARRIVAL := preload("res://scenes/playgrounds/playground_toon.gd")
const _PLACES := preload("res://scenes/places/hood_places.gd")
const _WEAR := "res://assets/cog_hq/floor_wear.png"
const _STICK := 0.2
const _TURN := 0.95
const _WEAR_SPAN := 6.25
const _WEAR_TEX := 6.0
const _CELL := 3.0

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
var _mixers: Array[Dictionary] = []
var _views: Array[Dictionary] = []
var _grid: Node3D
var _goon_scene: PackedScene
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
	if host.scene_file_path.get_file() != "sellbot_factory.tscn":
		return
	if host.get_node_or_null("FactoryProps") != null:
		return
	var script := load("res://scenes/cog_hq/factory_props.gd") as GDScript
	var node := script.new() as Node
	node.name = "FactoryProps"
	host.add_child(node)


func _ready() -> void:
	process_priority = 20
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
	_move_mixers(body, delta, busy)
	_spin_gears(delta, body, busy)
	_move_lifts()
	if body != null and not busy:
		_ride_belts(body, delta)
		_push_crates(body, delta)
		_grab_barrels(body)
		_move_goons(body, delta)
	else:
		_move_goons(null, delta)


func _process(_delta: float) -> void:
	if _leaving or _busy():
		return
	_aim_view()


func _index(node: Node, found: Dictionary) -> void:
	var node_name := String(node.name)
	if node_name.begins_with("stomper-") or node_name.begins_with("gear-") or node_name.begins_with("healBarrel-") or node_name.begins_with("gagBarrel-") or node_name.begins_with("beanBarrel-") or node_name.begins_with("lift-") or node_name.begins_with("conveyorBelt-") or node_name.begins_with("crate-") or node_name.begins_with("goon-") or node_name.begins_with("paintMixer-") or node_name.begins_with("grid-") or node_name.begins_with("trigger-"):
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
	_motion = _load_motion()
	var switches: Dictionary = (_motion.get("factory", {}) as Dictionary).get("switches", {})
	for item in data.get("stompers", []):
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item
		var root := _node(found, "stomper-%s" % spec.get("id", 0))
		var head := _model(root)
		if head == null:
			continue
		var stomper_id := int(spec.get("id", 0))
		var wired: Dictionary = switches.get(str(stomper_id), {})
		var motion := int(spec.get("motion", wired.get("motion", 3)))
		_stompers.append({
			"id": stomper_id,
			"head": head,
			"rest": head.position,
			"range": float(spec.get("range", 0.0)),
			"period": maxf(float(spec.get("period", 1.0)), 0.1),
			"phase": float(spec.get("phase", 0.0)),
			"damage": int(spec.get("damage", 0)),
			"motion": motion,
			"switch": int(wired.get("switch", 0)),
			"cell": int(wired.get("cell", 0)),
			"pose": "up",
			"from": head.position.y,
			"age": 0.0,
			"last": 0.0,
			"voice": _stomp_voice(head, float(spec.get("range", 0.0))),
		})
	for item in data.get("gears", []):
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item
		var root := _node(found, "gear-%s" % spec.get("id", 0))
		var mesh := _gear_disc(root)
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
		var track := _LABEL.track_for(int(spec.get("id", 0)), spec.get("track", 0))
		var level := int(spec.get("level", 0))
		_LABEL.dress(root, kind, track, level)
		_barrels.append({
			"id": int(spec.get("id", 0)),
			"root": root,
			"kind": kind,
			"grab": int(spec.get("grab", 0)),
			"track": track,
			"level": level,
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
	var routes: Dictionary = (_motion.get("factory", {}) as Dictionary).get("goons", {})
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
		var goon_id := int(spec.get("id", 0))
		var route: Dictionary = routes.get(str(goon_id), {})
		var points := _points(route)
		if points.size() >= 2:
			root.position = points[0]
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
			"cell": int(route.get("cell", 0)),
		})
	_take_mixers(found)
	_lay_floors(found)
	_take_views(found)


## DistributedStomperAI.reactToSwitch. MotionSwitched stays raised until its button.
func note_switch(ent_id: int, on: bool) -> void:
	for item in _stompers:
		if int(item.get("switch", 0)) != ent_id:
			continue
		var head: Node3D = item["head"]
		if head == null:
			continue
		var pose := str(item.get("pose", "up"))
		if on and (pose == "up" or pose == "rise"):
			item["from"] = head.position.y
			item["age"] = 0.0
			item["pose"] = "slam"
			var voice: AudioStreamPlayer3D = item["voice"]
			if voice != null:
				voice.play()
		elif not on and (pose == "down" or pose == "slam"):
			item["from"] = head.position.y
			item["age"] = 0.0
			item["pose"] = "rise"


func _move_stompers(body: Node3D, busy: bool) -> void:
	for item in _stompers:
		var head: Node3D = item["head"]
		if head == null:
			continue
		if int(item.get("motion", 3)) == 5:
			_move_switch(item, head, body, busy)
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


## MotionSwitched: waiting pose is the unshifted head, and the slam runs to -range.
func _move_switch(item: Dictionary, head: Node3D, body: Node3D, busy: bool) -> void:
	var rest: Vector3 = item["rest"]
	var up := rest.y
	var down := rest.y - float(item["range"])
	var pose := str(item.get("pose", "up"))
	var age := float(item.get("age", 0.0)) + get_physics_process_delta_time()
	item["age"] = age
	var y := up
	var arrived := false
	if pose == "slam":
		var along := clampf(age / 0.35, 0.0, 1.0)
		y = lerpf(float(item["from"]), down, along)
		arrived = along >= 1.0
		if arrived:
			item["pose"] = "down"
	elif pose == "rise":
		var along := clampf(age / 0.5, 0.0, 1.0)
		y = lerpf(float(item["from"]), up, along)
		if along >= 1.0:
			item["pose"] = "up"
	elif pose == "down":
		y = down
	head.position = Vector3(rest.x, y, rest.z)
	if not arrived:
		return
	_crush_cell(item, head)
	if not busy and body != null and body.global_position.distance_to(head.global_position) <= 3.0:
		_hurt(int(item["damage"]), "stomp-%s" % item["id"])


func _crush_under(head: Node3D) -> void:
	var flat := Vector2(head.global_position.x, head.global_position.z)
	var kept: Array[Dictionary] = []
	for item in _goons:
		var root: Node3D = item["root"]
		if root != null and is_instance_valid(root):
			var at := root.global_position
			if Vector2(at.x, at.z).distance_to(flat) <= 3.6:
				root.queue_free()
				continue
		kept.append(item)
	_goons = kept


## CrusherCellAI.doCrush. A switched stomper crushes the goon registered to its
## cell, and only while that goon is standing on the cell.
func _crush_cell(item: Dictionary, head: Node3D) -> void:
	var cell := int(item.get("cell", 0))
	var row := _cell_row(cell)
	var col := _cell_col(cell)
	if cell == 0 or row < 0 or _grid == null:
		_crush_under(head)
		return
	var kept: Array[Dictionary] = []
	for goon in _goons:
		var root: Node3D = goon["root"]
		if root == null or not is_instance_valid(root):
			continue
		if int(goon.get("cell", 0)) == cell and _stands_on(root, row, col):
			_flatten(root)
			continue
		kept.append(goon)
	_goons = kept


func _stands_on(root: Node3D, row: int, col: int) -> bool:
	var local := _grid.to_local(root.global_position)
	var at_row := int(floor(local.y / _CELL))
	var at_col := int(floor(local.x / _CELL))
	return row >= at_row and row <= at_row + 1 and col >= at_col and col <= at_col + 1


func _flatten(root: Node3D) -> void:
	root.scale = Vector3(root.scale.x * 1.2, root.scale.y * 1.2, root.scale.z * 0.2)
	var tree := get_tree()
	if tree == null:
		root.queue_free()
		return
	tree.create_timer(5.0).timeout.connect(_drop_goon.bind(root))


func _drop_goon(root: Node3D) -> void:
	if is_instance_valid(root):
		root.queue_free()


func _cell_row(cell: int) -> int:
	if cell == 20024 or cell == 20026 or cell == 20027 or cell == 20028:
		return 14
	return -1


func _cell_col(cell: int) -> int:
	if cell == 20024:
		return 1
	if cell == 20026:
		return 10
	if cell == 20027:
		return 21
	if cell == 20028:
		return 28
	return -1


## DistributedGrid.loadModel. FloorWear is one stretched card, tinted and lifted
## just off the floor. The long side follows the longer grid axis.
func _lay_floors(found: Dictionary) -> void:
	_grid = _node(found, "grid-20025")
	_lay_floor(found, "grid-20025", 30, 16)
	_lay_floor(found, "grid-20080", 2, 5)
	_lay_floor(found, "grid-20090", 2, 9)


func _lay_floor(found: Dictionary, node_name: String, cols: int, rows: int) -> void:
	var grid := _node(found, node_name)
	if grid == null or grid.get_node_or_null("FloorWear") != null:
		return
	var long := cols
	var short := rows
	var heading := 0.0
	if cols < rows:
		long = rows
		short = cols
		heading = 90.0
	var factor := _CELL / _WEAR_TEX
	var wear := MeshInstance3D.new()
	wear.name = "FloorWear"
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Z
	quad.size = Vector2(_WEAR_SPAN * factor * float(long), _WEAR_SPAN * factor * float(short))
	wear.mesh = quad
	wear.position = Vector3(_CELL * float(cols) * 0.5, _CELL * float(rows) * 0.5, 0.025)
	wear.rotation.z = deg_to_rad(heading)
	var mat := StandardMaterial3D.new()
	var texture := load(_WEAR) as Texture2D
	if texture != null:
		mat.albedo_texture = texture
	mat.albedo_color = Color(0.588, 0.588, 0.459, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	wear.material_override = mat
	grid.add_child(wear)


## FactoryCameraViews. Entering the volume switches to that camera. Leaving it
## lets the usual follow camera, which already ran this frame, stand.
func _take_views(found: Dictionary) -> void:
	_keep_view(found, "trigger-20050", Vector3(0.0, -14.8419799805, 13.212685585), Vector3(0.0, -13.9563484192, 12.749215126))
	_keep_view(found, "trigger-20057", Vector3(0.0, -17.7, 28.8), Vector3(0.0, 10.0, 0.0))


func _keep_view(found: Dictionary, node_name: String, cam: Vector3, look: Vector3) -> void:
	var trigger := _node(found, node_name)
	if trigger == null:
		return
	_views.append({"trigger": trigger, "cam": cam, "look": look})


func _aim_view() -> void:
	var body := _body()
	if body == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var actor := _actor(body)
	for item in _views:
		var trigger: Node3D = item["trigger"]
		if trigger == null or not is_instance_valid(trigger):
			continue
		var radius := trigger.global_transform.basis.x.length()
		if body.global_position.distance_to(trigger.global_position) > radius:
			continue
		var basis := actor.global_transform.basis
		var right := basis.x
		var forward := basis.y
		var up := basis.z
		if right.length_squared() < 0.0001 or forward.length_squared() < 0.0001:
			return
		right = right.normalized()
		forward = forward.normalized()
		up = up.normalized() if up.length_squared() > 0.0001 else Vector3.UP
		var cam: Vector3 = item["cam"]
		var look: Vector3 = item["look"]
		var at := actor.global_position
		camera.global_position = at + right * cam.x + forward * cam.y + up * cam.z
		var focus := at + right * look.x + forward * look.y + up * look.z
		if camera.global_position.distance_squared_to(focus) > 0.04:
			camera.look_at(focus, Vector3.UP)
		return


func _actor(body: Node3D) -> Node3D:
	for child in body.get_children():
		if child is CollisionShape3D:
			continue
		if child is Node3D:
			return child
	return body


func _spin_gears(delta: float, body: Node3D, busy: bool) -> void:
	for item in _gears:
		var mesh: Node3D = item["mesh"]
		if mesh == null:
			continue
		# GearEntity spins the disc's heading. On these nodes that axis is local Z.
		mesh.rotate_object_local(Vector3(0.0, 0.0, 1.0), deg_to_rad(float(item["deg"])) * delta)
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
			_BEANS.add_beans(grab * int(_HOLIDAYS.bean_scale("barrel")))
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
		var route: PackedVector3Array = item.get("points", PackedVector3Array())
		if route.size() >= 2:
			_walk_path(item, root, body, delta, route)
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


func _walk_path(item: Dictionary, root: Node3D, body: Node3D, delta: float, points: PackedVector3Array) -> void:
	if _stunned(item, root, body, delta):
		return
	var index := int(item.get("index", 0))
	var wait := float(item.get("wait", 0.0))
	if wait > 0.0:
		item["wait"] = wait - delta
	else:
		var nxt := (index + 1) % points.size()
		var goal := points[nxt]
		var step := goal - root.position
		var dist := step.length()
		var speed := float(item["speed"])
		if dist <= speed * delta + 0.05:
			root.position = goal
			item["index"] = nxt
			item["wait"] = 3.0
			var after := points[(nxt + 1) % points.size()]
			_face_local(root, after - goal)
		elif dist > 0.001:
			root.position += step * (speed * delta / dist)
			_face_local(root, step)
	_zap(item, root, body)


func _stunned(item: Dictionary, root: Node3D, body: Node3D, delta: float) -> bool:
	item["stun"] = maxf(float(item.get("stun", 0.0)) - delta, 0.0)
	if body != null and _head_hit(root, body, float(item.get("scale", 1.0))):
		item["stun"] = 4.0
	return float(item["stun"]) > 0.0


func _head_hit(root: Node3D, body: Node3D, scale: float) -> bool:
	var crown := root.global_position + Vector3.UP * (1.8 * maxf(scale, 0.5))
	return body.global_position.distance_to(crown) < 1.3


func _face_local(root: Node3D, step: Vector3) -> void:
	if Vector2(step.x, step.y).length_squared() < 0.001:
		return
	root.rotation = Vector3(0.0, 0.0, atan2(step.x, step.y))


func _zap(item: Dictionary, root: Node3D, body: Node3D) -> void:
	if body == null:
		return
	var toward := body.global_position - root.global_position
	toward.y = 0.0
	var dist := toward.length()
	if dist > 3.0 or dist < 0.05 or dist > float(item["reach"]):
		return
	var forward := root.global_transform.basis.y
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return
	if forward.normalized().dot(toward.normalized()) < cos(deg_to_rad(float(item["fov"]) * 0.5)):
		return
	_hurt(int(item["strength"]), "goon-%s" % item["id"])


func _take_mixers(found: Dictionary) -> void:
	var rows: Variant = (_motion.get("factory", {}) as Dictionary).get("mixers", [])
	if not (rows is Array):
		return
	for item in rows:
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item
		var holder := _node(found, "paintMixer-%s" % spec.get("id", 0))
		if holder == null:
			continue
		var model := _model(holder)
		if model == null:
			model = holder
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


func _move_mixers(body: Node3D, _delta: float, busy: bool) -> void:
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
		var rest: Vector3 = item["rest"]
		var offset: Vector3 = item["offset"]
		model.position = rest + offset * along
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


func _points(route: Dictionary) -> PackedVector3Array:
	var points := PackedVector3Array()
	var scale := float(route.get("scale", 1.0))
	var raw: Variant = route.get("points", [])
	if raw is Array:
		for item in raw:
			if item is Array and (item as Array).size() >= 3:
				var row: Array = item
				points.append(Vector3(float(row[0]), float(row[1]), float(row[2])) * scale)
	return points


func _load_motion() -> Dictionary:
	if not FileAccess.file_exists(_MOTION):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_MOTION))
	if parsed is Dictionary:
		return parsed
	return {}


func _gear_disc(root: Node) -> Node3D:
	if root == null:
		return null
	var parent := _named(root, "gearParent")
	if parent == null:
		return null
	for child in parent.get_children():
		if child is Node3D:
			return child
	return null


func _named(node: Node, node_name: String) -> Node:
	if String(node.name) == node_name:
		return node
	for child in node.get_children():
		var found := _named(child, node_name)
		if found != null:
			return found
	return null


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
