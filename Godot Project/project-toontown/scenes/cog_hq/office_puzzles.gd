extends Node

## Lasers, doors, buttons, stompers, cameras, platforms, goons, and barrels
## from the Lawbot office room specs. A laser's switch button wins it outright.
## Mine Sweeper and Avoid have no win in the leaked source; clearing the safe
## tiles, or lasting three Avoid cycles, finishes those two so the room can
## be completed when its button is out of reach.

const _RUN := preload("res://scenes/cog_hq/office_run.gd")
const _COGS := preload("res://scenes/cog_hq/office_cogs.gd")
const _PRESS := "res://assets/cog_hq/audio/CHQ_FACT_switch_pressed.ogg"
const _SLIDE := "res://assets/cog_hq/audio/CHQ_FACT_door_open_sliding.ogg"
const _LASER_ON := "res://assets/cog_hq/audio/LB_laser_beam_on_2.ogg"
const _LASER_OFF := "res://assets/cog_hq/audio/LB_laser_beam_off_2.ogg"
const _SHUTTER := "res://assets/cog_hq/audio/LB_camera_shutter_2.ogg"
const _LABEL := preload("res://scenes/cog_hq/barrel_label.gd")

var _lasers: Array[Dictionary] = []
var _buttons: Array[Dictionary] = []
var _doors: Array[Dictionary] = []
var _stompers: Array[Dictionary] = []
var _cameras: Array[Dictionary] = []
var _platforms: Array[Dictionary] = []
var _movers: Array[Dictionary] = []
var _goons: Array[Dictionary] = []
var _barrels: Array[Dictionary] = []
var _blockers: Array[Dictionary] = []
var _told := false


static func place(host: Node) -> void:
	if Engine.is_editor_hint() or host == null:
		return
	if host.scene_file_path.get_file() != "lawbot_office.tscn":
		return
	if host.get_node_or_null("OfficePuzzles") != null:
		return
	var script := load("res://scenes/cog_hq/office_puzzles.gd") as GDScript
	var node := script.new() as Node
	node.name = "OfficePuzzles"
	host.add_child(node)


func _ready() -> void:
	var rooms: Dictionary = _RUN.book().get("rooms", {})
	var host := get_parent()
	if host == null:
		return
	for child in host.get_children():
		if not str(child.name).begins_with("Piece"):
			continue
		var piece := child as Node3D
		if piece == null:
			continue
		var room_id := int(piece.get_meta("room", 0))
		var spec: Variant = rooms.get(str(room_id), {})
		if not (spec is Dictionary):
			continue
		var piece_index := int(piece.get_meta("piece", 0))
		for item in (spec as Dictionary).get("entities", []):
			if item is Dictionary:
				_add(piece, piece_index, item)


func _physics_process(delta: float) -> void:
	var toon := _toon()
	var body := _feet()
	if toon == null or body == null:
		return
	var here := body.global_position
	_poll_buttons(here)
	_poll_lasers(toon, here, delta)
	_poll_doors(here, delta)
	_poll_stompers(toon, here, delta)
	_poll_cameras(toon, here, delta)
	_poll_platforms(delta)
	_poll_movers(delta)
	_poll_goons(toon, here, delta)
	_poll_barrels(toon, here)
	_poll_blockers()


func _add(piece: Node3D, piece_index: int, spec: Dictionary) -> void:
	var kind := str(spec.get("type", ""))
	var ent_id := int(spec.get("id", 0))
	var node := _find(piece, "ent-%d" % ent_id)
	if node == null and kind != "collisionSolid":
		return
	match kind:
		"laserField":
			_lasers.append(_make_laser(node, piece_index, spec))
		"button":
			_buttons.append({"id": ent_id, "piece": piece_index, "node": node, "on": false, "left": -1.0, "seconds": float(spec.get("secondsOn", -1.0))})
		"door":
			_doors.append(_make_door(node, piece_index, spec))
		"stomper":
			_stompers.append(_make_stomper(node, spec))
		"securityCamera":
			_cameras.append({"node": node, "radius": float(spec.get("radius", 15.0)), "damage": int(spec.get("damPow", 8)), "left": 0.0, "beam": _beam(node)})
		"platform":
			_platforms.append(_make_platform(node, spec))
		"mover":
			_movers.append(_make_mover(piece, spec))
		"goon":
			_goons.append(_make_goon(piece, node, spec))
		"gagBarrel", "healBarrel":
			var track := _LABEL.track_for(ent_id, spec.get("gagTrack", "random"))
			if node != null:
				_LABEL.dress(node, kind, track, int(spec.get("gagLevel", 0)))
			_barrels.append({"node": node, "kind": kind, "spec": spec, "used": false, "track": track})
		"battleBlocker":
			_blockers.append(_make_blocker(node, piece_index, spec))
		"collisionSolid":
			if node != null:
				_solid(node, spec)
		"elevatorMarker":
			pass


func _make_laser(node: Node3D, piece_index: int, spec: Dictionary) -> Dictionary:
	var names := ["MineSweeper", "Roll", "Avoid", "Drag"]
	var game := str(spec.get("gridGame", "Roll"))
	if game == "Random":
		game = names[randi() % names.size()]
	var laser := {
		"id": int(spec.get("id", 0)),
		"piece": piece_index,
		"node": node,
		"cell": int(spec.get("cellId", 0)),
		"switch": int(spec.get("switchId", 0)),
		"game": game,
		"sx": float(spec.get("gridScaleX", 20.0)),
		"sy": float(spec.get("gridScaleY", 20.0)),
		"state": "live",
		"tx": -1,
		"ty": -1,
		"age": 0.0,
		"cycles": 0,
		"entered": false,
		"mesh": MeshInstance3D.new(),
	}
	var mesh: MeshInstance3D = laser["mesh"]
	mesh.name = "LaserGrid"
	node.add_child(mesh)
	_start_grid(laser)
	_draw_grid(laser)
	return laser


func _start_grid(laser: Dictionary) -> void:
	var game := str(laser["game"])
	var cols := 5
	var rows := 5
	if game == "MineSweeper":
		cols = 7
		rows = 7
	elif game == "Drag":
		cols = 6
		rows = 6
	elif game == "Avoid":
		cols = 8
		rows = 8
	laser["cols"] = cols
	laser["rows"] = rows
	var grid: Array = []
	var hidden: Array = []
	for _x in cols:
		var column: Array = []
		var secret: Array = []
		for _y in rows:
			column.append(0)
			secret.append(0)
		grid.append(column)
		hidden.append(secret)
	laser["grid"] = grid
	laser["hidden"] = hidden
	if game == "Roll":
		for x in cols:
			for y in rows:
				grid[x][y] = 10 if randi() % 2 == 0 else 13
			grid[x][rows - 1] = 12
	elif game == "Drag":
		for x in cols:
			grid[x][rows - 1] = 12
		for symbol in [16, 13, 17]:
			var placed := 0
			var guard := 0
			while placed < 4 and guard < 400:
				guard += 1
				var x := randi() % cols
				var y := 1 + randi() % (rows - 1)
				if int(grid[x][y]) == 0:
					grid[x][y] = symbol
					placed += 1
			_clear_drag(grid, cols, rows, symbol)
	elif game == "Avoid":
		for x in cols:
			for y in rows:
				grid[x][y] = [0, 14, 12][randi() % 3]
	elif game == "MineSweeper":
		var bombs := int(cols * rows / 8) + 1
		var placed := 0
		var guard := 0
		while placed < bombs and guard < 800:
			guard += 1
			var x := randi() % cols
			var y := 1 + randi() % (rows - 1)
			if int(hidden[x][y]) == 12:
				continue
			hidden[x][y] = 12
			placed += 1
		for x in cols:
			for y in rows:
				grid[x][y] = 11 if int(hidden[x][y]) == 12 else 10


func _poll_buttons(here: Vector3) -> void:
	for button in _buttons:
		var node: Node3D = button["node"]
		var local := node.global_transform.affine_inverse() * here
		var standing := Vector2(local.x, local.y).length() < 1.6 and absf(local.z) < 4.0
		var seconds := float(button["seconds"])
		if standing and not bool(button["on"]):
			button["on"] = true
			button["left"] = seconds
			_press(node, true)
			_once(_PRESS)
			_laser_switch(int(button["piece"]), int(button["id"]))
		elif not standing and bool(button["on"]) and seconds < 0.0:
			button["on"] = false
			_press(node, false)


func _laser_switch(piece: int, button_id: int) -> void:
	for laser in _lasers:
		if int(laser["piece"]) == piece and int(laser["switch"]) == button_id and str(laser["state"]) == "live":
			_laser_win(laser)


func _poll_lasers(toon: Node, here: Vector3, delta: float) -> void:
	for laser in _lasers:
		if str(laser["state"]) == "failed":
			var cogs := get_parent().get_node_or_null("StreetSuits")
			if cogs != null and cogs.has_method("cell_clear") and bool(cogs.call("cell_clear", int(laser["piece"]), int(laser["cell"]))):
				laser["state"] = "won"
				_fire(int(laser["piece"]), int(laser["id"]))
			continue
		if str(laser["state"]) != "live":
			continue
		if str(laser["game"]) == "Avoid":
			laser["age"] = float(laser["age"]) + delta
			if float(laser["age"]) >= 2.5:
				laser["age"] = 0.0
				_cycle_avoid(laser)
				if bool(laser["entered"]):
					laser["cycles"] = int(laser["cycles"]) + 1
					if int(laser["cycles"]) >= 3:
						_laser_win(laser)
						continue
		var node: Node3D = laser["node"]
		var local := node.global_transform.affine_inverse() * here
		var sx := float(laser["sx"])
		var sy := float(laser["sy"])
		if local.x <= 0.0 or local.y <= 0.0 or local.x >= sx or local.y >= sy or absf(local.z) > 6.0:
			laser["tx"] = -1
			laser["ty"] = -1
			continue
		if not _told:
			_told = true
			toon.call("show_notice", _game_name(str(laser["game"])))
		var cols := int(laser["cols"])
		var rows := int(laser["rows"])
		var tile_x := clampi(int(local.x / (sx / float(cols))), 0, cols - 1)
		var tile_y := clampi(int(local.y / (sy / float(rows))), 0, rows - 1)
		if tile_x == int(laser["tx"]) and tile_y == int(laser["ty"]):
			continue
		var old_x := int(laser["tx"])
		var old_y := int(laser["ty"])
		laser["tx"] = tile_x
		laser["ty"] = tile_y
		laser["entered"] = true
		_step_laser(laser, tile_x, tile_y, old_x, old_y)


func _step_laser(laser: Dictionary, tile_x: int, tile_y: int, old_x: int, old_y: int) -> void:
	var grid: Array = laser["grid"]
	var symbol := int(grid[tile_x][tile_y])
	if symbol == 11 or symbol == 12:
		_laser_fail(laser)
		return
	var game := str(laser["game"])
	if game == "Roll":
		if symbol == 10:
			grid[tile_x][tile_y] = 13
		elif symbol == 13:
			grid[tile_x][tile_y] = 10
		if _roll_won(grid, int(laser["cols"]), int(laser["rows"])):
			_laser_win(laser)
			return
	elif game == "Drag":
		if old_x >= 0 and old_y >= 0 and symbol == 0:
			var carried := int(grid[old_x][old_y])
			if carried == 16 or carried == 13 or carried == 17:
				grid[tile_x][tile_y] = carried
				grid[old_x][old_y] = 0
		for carried in [16, 13, 17]:
			if _drag_row(grid, int(laser["cols"]), int(laser["rows"]), carried):
				_clear_symbol(grid, int(laser["cols"]), int(laser["rows"]), carried)
		if _drag_won(grid, int(laser["cols"]), int(laser["rows"])):
			_laser_win(laser)
			return
	elif game == "MineSweeper":
		var hidden: Array = laser["hidden"]
		if int(hidden[tile_x][tile_y]) == 12:
			grid[tile_x][tile_y] = 12
			_draw_grid(laser)
			_laser_fail(laser)
			return
		_reveal(grid, hidden, int(laser["cols"]), int(laser["rows"]), tile_x, tile_y)
		if _mines_won(grid, int(laser["cols"]), int(laser["rows"])):
			_laser_win(laser)
			return
	_draw_grid(laser)


func _laser_win(laser: Dictionary) -> void:
	if str(laser["state"]) != "live":
		return
	laser["state"] = "won"
	var mesh: MeshInstance3D = laser["mesh"]
	mesh.visible = false
	_once(_LASER_OFF)
	var toon := _toon_script()
	if toon != null and toon.has_method("heal"):
		toon.call("heal", _RUN.reward)
	_RUN.reward = mini(_RUN.reward + 5, 10)
	var board := get_node_or_null("/root/StreetTraffic/OfficeBoard")
	if board != null and board.has_method("remove_cell"):
		board.call("remove_cell", ToonNet.district_id(), int(laser["piece"]), int(laser["cell"]))
	_fire(int(laser["piece"]), int(laser["id"]))


func _laser_fail(laser: Dictionary) -> void:
	if str(laser["state"]) != "live":
		return
	laser["state"] = "failed"
	var mesh: MeshInstance3D = laser["mesh"]
	mesh.visible = false
	_once(_LASER_ON)
	_RUN.reward = 5
	var board := get_node_or_null("/root/StreetTraffic/OfficeBoard")
	if board != null and board.has_method("reveal_cell"):
		board.call("reveal_cell", ToonNet.district_id(), int(laser["piece"]), int(laser["cell"]))


func _fire(piece: int, ent_id: int) -> void:
	for door in _doors:
		if int(door["piece"]) != piece:
			continue
		var locks: Array = door["locks"]
		for index in locks.size():
			var lock: Dictionary = locks[index]
			if int(lock["event"]) == ent_id:
				lock["open"] = true


func _poll_doors(here: Vector3, delta: float) -> void:
	for door in _doors:
		if bool(door["opened"]):
			continue
		var ready := true
		for lock in door["locks"]:
			if not bool((lock as Dictionary)["open"]):
				ready = false
		if not ready:
			continue
		var node: Node3D = door["node"]
		if node.global_position.distance_to(here) > 12.0:
			continue
		door["opened"] = true
		door["age"] = 0.0
		_once(_SLIDE)
	for door in _doors:
		if not bool(door["opened"]) or bool(door["slid"]):
			continue
		door["age"] = float(door["age"]) + delta
		var blend := clampf(float(door["age"]) / 0.8, 0.0, 1.0)
		var left: Node3D = door["left"]
		var right: Node3D = door["right"]
		if left != null:
			left.position.x = float(door["left_x"]) - 7.5 * blend
		if right != null:
			right.position.x = float(door["right_x"]) + 7.5 * blend
		if blend >= 1.0:
			door["slid"] = true


func _poll_stompers(toon: Node, here: Vector3, delta: float) -> void:
	for stomper in _stompers:
		var model: Node3D = stomper["model"]
		if model == null:
			continue
		var period := maxf(float(stomper["period"]), 0.2)
		var age := float(stomper["age"]) + delta
		stomper["age"] = age
		var t := fposmod(age / period + float(stomper["phase"]), 1.0)
		var span := float(stomper["range"])
		var motion := int(stomper["motion"])
		var along := 0.0
		if motion == 1:
			along = (0.5 + cos(PI + t * TAU) * 0.5) * -span
		elif motion == 3:
			if t < 0.2:
				along = 0.0
			elif t < 0.95:
				along = -span * (t - 0.2) / 0.75
			else:
				along = -span + span * (t - 0.95) / 0.05
		elif motion == 4:
			if t < 0.2:
				along = 0.0
			elif t < 0.65:
				along = -span * (t - 0.2) / 0.45
			elif t < 0.85:
				along = -span
			else:
				along = -span * (1.0 - (t - 0.85) / 0.15)
		else:
			if t < 0.5:
				along = -span * (t / 0.5)
			elif t < 0.75:
				along = -span
			else:
				along = -span * (1.0 - (t - 0.75) / 0.25)
		model.position.y = float(stomper["rest"]) + along
		if along > -span * 0.85:
			continue
		if model.global_position.distance_to(here) > 3.5:
			continue
		if toon.has_method("squish"):
			toon.call("squish", int(stomper["damage"]))


func _poll_cameras(toon: Node, here: Vector3, delta: float) -> void:
	for camera in _cameras:
		var node: Node3D = camera["node"]
		var beam: MeshInstance3D = camera["beam"]
		camera["left"] = float(camera["left"]) - delta
		var radius := float(camera["radius"])
		var offset := here - node.global_position
		var dist := offset.length()
		var watching := dist < radius and dist > 0.5
		beam.visible = watching
		if not watching:
			continue
		beam.look_at(here, Vector3.UP)
		beam.scale = Vector3(0.15, 0.15, dist)
		if float(camera["left"]) > 0.0:
			continue
		camera["left"] = 2.0
		_once(_SHUTTER)
		if toon.has_method("squish"):
			toon.call("squish", int(camera["damage"]))


func _poll_platforms(delta: float) -> void:
	for platform in _platforms:
		var model: Node3D = platform["model"]
		if model == null:
			continue
		var period := maxf(float(platform["period"]), 0.2)
		var wait := clampf(float(platform["wait"]), 0.0, 0.9)
		var age := float(platform["age"]) + delta
		platform["age"] = age
		var t := fposmod(age / period + float(platform["phase"]), 1.0)
		var hold := wait
		var move := (1.0 - wait) * 0.5
		var along := 0.0
		if t < hold * 0.5:
			along = 0.0
		elif t < hold * 0.5 + move:
			along = (t - hold * 0.5) / maxf(move, 0.01)
		elif t < hold + move:
			along = 1.0
		else:
			along = 1.0 - (t - hold - move) / maxf(move, 0.01)
		var offset: Vector3 = platform["offset"]
		model.position = (platform["rest"] as Vector3) + offset * clampf(along, 0.0, 1.0)


func _poll_movers(delta: float) -> void:
	for mover in _movers:
		var node: Node3D = mover["node"]
		var target: Vector3 = mover["target"]
		var rest: Vector3 = mover["rest"]
		if node == null:
			continue
		var go := float(mover["go"])
		var back := float(mover["back"])
		var wait_a := float(mover["wait_a"])
		var wait_b := float(mover["wait_b"])
		var total := maxf(go + back + wait_a + wait_b, 0.2)
		var age := float(mover["age"]) + delta
		mover["age"] = age
		var t := fposmod(age, total)
		if t < go:
			node.position = rest.lerp(target, t / maxf(go, 0.01))
		elif t < go + wait_b:
			node.position = target
		elif t < go + wait_b + back:
			node.position = target.lerp(rest, (t - go - wait_b) / maxf(back, 0.01))
		else:
			node.position = rest


func _poll_goons(toon: Node, here: Vector3, delta: float) -> void:
	for goon in _goons:
		var node: Node3D = goon["node"]
		var points: PackedVector3Array = goon["points"]
		if node == null or points.size() < 2:
			continue
		goon["stun"] = maxf(float(goon.get("stun", 0.0)) - delta, 0.0)
		var crown := node.global_position + Vector3.UP * (1.8 * maxf(float(goon.get("scale", 1.0)), 0.5))
		if here.distance_to(crown) < 1.3:
			goon["stun"] = 4.0
		if float(goon["stun"]) > 0.0:
			continue
		var index := int(goon["index"])
		var nxt := (index + 1) % points.size()
		var goal := points[nxt]
		var current := node.position
		var step := goal - current
		var dist := step.length()
		var speed := float(goon["speed"])
		if dist < speed * delta + 0.05:
			goon["index"] = nxt
			node.position = goal
		elif dist > 0.001:
			node.position = current + step * (speed * delta / dist)
			var flat := Vector3(step.x, step.y, 0.0)
			if flat.length_squared() > 0.001:
				# Path points live in the path node's panda axes: Z is up.
				node.rotation = Vector3(0.0, 0.0, atan2(step.x, step.y))
		if node.global_position.distance_to(here) > float(goon["radius"]):
			continue
		var forward := node.global_transform.basis.y
		forward.y = 0.0
		var toward := here - node.global_position
		toward.y = 0.0
		if forward.length_squared() < 0.001 or toward.length_squared() < 0.001:
			continue
		if forward.normalized().dot(toward.normalized()) < cos(deg_to_rad(float(goon["fov"]) * 0.5)):
			continue
		if toon.has_method("squish"):
			toon.call("squish", int(goon["strength"]))


func _poll_barrels(toon: Node, here: Vector3) -> void:
	for barrel in _barrels:
		if bool(barrel["used"]):
			continue
		var node: Node3D = barrel["node"]
		if node.global_position.distance_to(here) > 2.4:
			continue
		barrel["used"] = true
		node.visible = false
		var spec: Dictionary = barrel["spec"]
		var reward := int(spec.get("rewardPerGrab", 1))
		if str(barrel["kind"]) == "healBarrel":
			if toon.has_method("heal"):
				toon.call("heal", reward)
			continue
		var loadout: Variant = toon.call("battle_loadout") if toon.has_method("battle_loadout") else null
		if loadout == null or not loadout.has_method("purchase"):
			continue
		var level := int(spec.get("gagLevel", 0))
		var track := int(barrel.get("track", 0))
		for _grab in maxi(reward, 1):
			if track < 0 or int(loadout.call("purchase", track, level)) <= 0:
				break


func _poll_blockers() -> void:
	var cogs := get_parent().get_node_or_null("StreetSuits")
	if cogs == null or not cogs.has_method("cell_clear"):
		return
	for blocker in _blockers:
		if bool(blocker["open"]):
			continue
		if not bool(cogs.call("cell_clear", int(blocker["piece"]), int(blocker["cell"]))):
			continue
		blocker["open"] = true
		var body: Node = blocker["body"]
		if body != null:
			body.queue_free()


func _make_door(node: Node3D, piece_index: int, spec: Dictionary) -> Dictionary:
	var locks: Array[Dictionary] = []
	for index in 4:
		var event_id := int(spec.get("unlock%dEvent" % index, 0))
		var opened := int(spec.get("isLock%dUnlocked" % index, 0)) == 1 or event_id == 0
		locks.append({"event": event_id, "open": opened})
	return {
		"piece": piece_index,
		"node": node,
		"locks": locks,
		"opened": false,
		"slid": false,
		"age": 0.0,
		"left": _find_loose(node, "doorLeft"),
		"right": _find_loose(node, "doorRight"),
		"left_x": _local_x(_find_loose(node, "doorLeft")),
		"right_x": _local_x(_find_loose(node, "doorRight")),
	}


func _make_stomper(node: Node3D, spec: Dictionary) -> Dictionary:
	var model := _find_loose(node, "stomp-model")
	return {
		"model": model,
		"rest": model.position.y if model != null else 0.0,
		"period": float(spec.get("period", 4.0)),
		"phase": float(spec.get("phaseShift", 0.0)),
		"range": float(spec.get("range", 8.0)),
		"motion": int(spec.get("motion", 3)),
		"damage": int(spec.get("damage", 10)),
		"age": 0.0,
	}


func _make_platform(node: Node3D, spec: Dictionary) -> Dictionary:
	var model := _find_loose(node, "platform-move")
	var offset: Array = spec.get("offset", [0, 0, 0])
	return {
		"model": model,
		"rest": model.position if model != null else Vector3.ZERO,
		"offset": Vector3(float(offset[0]), float(offset[1]), float(offset[2])) if offset.size() >= 3 else Vector3.ZERO,
		"period": float(spec.get("period", 4.0)),
		"wait": float(spec.get("waitPercent", 0.1)),
		"phase": float(spec.get("phaseShift", 0.0)),
		"age": 0.0,
	}


func _make_mover(piece: Node3D, spec: Dictionary) -> Dictionary:
	var moved := _find(piece, "ent-%d" % int(spec.get("entity2Move", 0)))
	var target := _find(piece, "ent-%d" % int(spec.get("moveTarget", 0)))
	var rest := moved.position if moved != null else Vector3.ZERO
	var goal := rest
	if moved != null and target != null:
		goal = moved.global_transform.affine_inverse() * target.global_position
		goal = moved.position + (target.global_position - moved.global_position)
		if moved.get_parent() == target.get_parent():
			goal = target.position
		else:
			var parent := moved.get_parent() as Node3D
			goal = parent.to_local(target.global_position) if parent != null else target.position
	return {
		"node": moved,
		"rest": rest,
		"target": goal,
		"go": float(spec.get("pos0Move", 2.0)),
		"back": float(spec.get("pos1Move", 2.0)),
		"wait_a": float(spec.get("pos0Wait", 0.0)),
		"wait_b": float(spec.get("pos1Wait", 3.0)),
		"age": 0.0,
	}


func _make_goon(piece: Node3D, node: Node3D, spec: Dictionary) -> Dictionary:
	_hide_hat(node, str(spec.get("goonType", "sg")))
	var points := _goon_points(piece, node)
	var scale := 1.0
	var raw: Variant = spec.get("scale", 1.0)
	if raw is float or raw is int:
		scale = float(raw)
	return {
		"node": node,
		"points": points,
		"index": 0,
		"speed": float(spec.get("velocity", 4.0)),
		"radius": float(spec.get("attackRadius", 15.0)),
		"fov": float(spec.get("hFov", 70.0)),
		"strength": int(spec.get("strength", 15)),
		"scale": scale,
		"stun": 0.0,
	}


func _goon_points(piece: Node3D, node: Node3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	var master := node.get_parent() as Node3D
	if master == null or not str(master.name).begins_with("ent-"):
		return points
	var record := _entity(piece, int(str(master.name).trim_prefix("ent-")))
	var scale := float(record.get("pathScale", 1.0))
	var used_targets := false
	for index in 8:
		var target_id := int(record.get("pathTarget%d" % index, 0))
		if target_id == 0:
			continue
		var target := _find(piece, "ent-%d" % target_id)
		if target == null:
			continue
		points.append(master.to_local(target.global_position) * scale)
		used_targets = true
	if used_targets:
		return points
	# PathEntity walks GoonPathData.Paths['lawOfficeStage'][pathIndex].
	var table: Dictionary = _RUN.book().get("paths", {})
	var raw: Variant = table.get(str(int(record.get("pathIndex", -1))), [])
	if raw is Array:
		for item in raw:
			if item is Array and (item as Array).size() >= 3:
				var row: Array = item
				points.append(Vector3(float(row[0]), float(row[1]), float(row[2])) * scale)
	return points


func _entity(piece: Node3D, ent_id: int) -> Dictionary:
	var rooms: Dictionary = _RUN.book().get("rooms", {})
	var room_spec: Variant = rooms.get(str(int(piece.get_meta("room", 0))), {})
	if not (room_spec is Dictionary):
		return {}
	for ent in (room_spec as Dictionary).get("entities", []):
		if ent is Dictionary and int((ent as Dictionary).get("id", 0)) == ent_id:
			return ent
	return {}


func _hide_hat(node: Node, goon_type: String) -> void:
	var hidden := "hard_hat" if goon_type == "sg" else "security_hat"
	_hide_named(node, hidden)


func _hide_named(node: Node, piece: String) -> void:
	var node_name := str(node.name).to_lower()
	if node_name == piece or node_name.begins_with(piece):
		if node is Node3D:
			(node as Node3D).visible = false
	for child in node.get_children():
		_hide_named(child, piece)


func _make_blocker(node: Node3D, piece_index: int, spec: Dictionary) -> Dictionary:
	var body := StaticBody3D.new()
	body.name = "BattleBlocker"
	node.add_child(body)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = float(spec.get("radius", 10.0))
	shape.shape = sphere
	body.add_child(shape)
	return {"body": body, "piece": piece_index, "cell": int(spec.get("cellId", 0)), "open": false}


func _solid(node: Node3D, spec: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.name = "OfficeSolid"
	node.add_child(body)
	var shape := CollisionShape3D.new()
	if str(spec.get("solidType", "sphere")) == "tube":
		var cylinder := CylinderShape3D.new()
		cylinder.radius = float(spec.get("radius", 1.0))
		cylinder.height = float(spec.get("length", 1.0))
		shape.shape = cylinder
		shape.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	else:
		var sphere := SphereShape3D.new()
		sphere.radius = float(spec.get("radius", 1.0))
		shape.shape = sphere
	body.add_child(shape)


func _beam(node: Node3D) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = "CameraBeam"
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.2, 0.2, 0.45)
	mesh.material_override = material
	mesh.position = Vector3(0.0, 0.0, 0.5)
	mesh.visible = false
	node.add_child(mesh)
	return mesh


func _draw_grid(laser: Dictionary) -> void:
	var mesh: MeshInstance3D = laser["mesh"]
	var cols := int(laser["cols"])
	var rows := int(laser["rows"])
	var sx := float(laser["sx"])
	var sy := float(laser["sy"])
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = laser["grid"]
	for x in cols:
		for y in rows:
			var x0 := sx * float(x) / float(cols)
			var x1 := sx * float(x + 1) / float(cols)
			var y0 := sy * float(y) / float(rows)
			var y1 := sy * float(y + 1) / float(rows)
			_quad(tool, x0, x1, y0, y1, _color(int(grid[x][y])))
	mesh.mesh = tool.commit()


func _quad(tool: SurfaceTool, x0: float, x1: float, y0: float, y1: float, color: Color) -> void:
	var z := 0.08
	tool.set_color(color)
	tool.add_vertex(Vector3(x0, y0, z))
	tool.set_color(color)
	tool.add_vertex(Vector3(x1, y0, z))
	tool.set_color(color)
	tool.add_vertex(Vector3(x1, y1, z))
	tool.set_color(color)
	tool.add_vertex(Vector3(x0, y0, z))
	tool.set_color(color)
	tool.add_vertex(Vector3(x1, y1, z))
	tool.set_color(color)
	tool.add_vertex(Vector3(x0, y1, z))


func _color(symbol: int) -> Color:
	match symbol:
		10, 11:
			return Color(0.85, 0.15, 0.15, 0.85)
		12:
			return Color(0.05, 0.05, 0.05, 0.9)
		13:
			return Color(0.15, 0.8, 0.25, 0.85)
		14:
			return Color(0.95, 0.85, 0.2, 0.85)
		15:
			return Color(0.25, 0.35, 0.95, 0.85)
		16:
			return Color(0.95, 0.35, 0.1, 0.85)
		17:
			return Color(0.3, 0.75, 0.95, 0.85)
		0:
			return Color(0.15, 0.15, 0.2, 0.28)
		_:
			return Color(0.9, 0.9, 0.85, 0.8)


func _roll_won(grid: Array, cols: int, rows: int) -> bool:
	var red := 0
	var green := 0
	for x in cols:
		for y in rows:
			var symbol := int(grid[x][y])
			if symbol == 10:
				red += 1
			elif symbol == 13:
				green += 1
	return red == 0 or green == 0


func _drag_row(grid: Array, cols: int, rows: int, symbol: int) -> bool:
	for x in cols:
		var run := 0
		for y in rows:
			run = run + 1 if int(grid[x][y]) == symbol else 0
			if run >= 3:
				return true
	for y in rows:
		var run := 0
		for x in cols:
			run = run + 1 if int(grid[x][y]) == symbol else 0
			if run >= 3:
				return true
	return false


func _clear_symbol(grid: Array, cols: int, rows: int, symbol: int) -> void:
	for x in cols:
		for y in rows:
			if int(grid[x][y]) == symbol:
				grid[x][y] = 0


func _clear_drag(grid: Array, cols: int, rows: int, symbol: int) -> void:
	if _drag_row(grid, cols, rows, symbol):
		_clear_symbol(grid, cols, rows, symbol)


func _drag_won(grid: Array, cols: int, rows: int) -> bool:
	for x in cols:
		for y in rows:
			var symbol := int(grid[x][y])
			if symbol == 16 or symbol == 13 or symbol == 17:
				return false
	return true


func _mines_won(grid: Array, cols: int, rows: int) -> bool:
	for x in cols:
		for y in rows:
			if int(grid[x][y]) == 10:
				return false
	return true


func _reveal(grid: Array, hidden: Array, cols: int, rows: int, x: int, y: int) -> void:
	if int(grid[x][y]) != 10:
		return
	var count := _neighbors(hidden, cols, rows, x, y)
	grid[x][y] = count
	if count != 0:
		return
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx := x + int(dx)
			var ny := y + int(dy)
			if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
				continue
			_reveal(grid, hidden, cols, rows, nx, ny)


func _neighbors(hidden: Array, cols: int, rows: int, x: int, y: int) -> int:
	var count := 0
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx := x + int(dx)
			var ny := y + int(dy)
			if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
				continue
			if int(hidden[nx][ny]) == 12:
				count += 1
	return count


func _cycle_avoid(laser: Dictionary) -> void:
	var grid: Array = laser["grid"]
	for x in int(laser["cols"]):
		for y in int(laser["rows"]):
			var symbol := int(grid[x][y])
			if symbol == 0:
				grid[x][y] = 0 if randi() % 2 == 0 else 14
			elif symbol == 14:
				grid[x][y] = 12
			elif symbol == 12:
				grid[x][y] = 0
	_draw_grid(laser)


func _game_name(game: String) -> String:
	match game:
		"MineSweeper":
			return "Skull Finder!"
		"Roll":
			return "Matching"
		"Avoid":
			return "Avoid the Skulls"
		"Drag":
			return "Drag three of a color in a row"
		_:
			return "Unknown Game"


func _press(node: Node3D, down: bool) -> void:
	var button := _find_loose(node, "button")
	if button == null:
		return
	if not button.has_meta("up_y"):
		button.set_meta("up_y", button.position.y)
	button.position.y = float(button.get_meta("up_y")) - (0.15 if down else 0.0)


func _local_x(node: Node3D) -> float:
	if node == null:
		return 0.0
	return node.position.x


func _find_loose(node: Node, piece: String) -> Node3D:
	if node == null:
		return null
	var node_name := str(node.name)
	if node_name == piece or node_name.begins_with(piece):
		if node is Node3D:
			return node as Node3D
	for child in node.get_children():
		var found := _find_loose(child, piece)
		if found != null:
			return found
	return null


func _find(node: Node, node_name: String) -> Node3D:
	if node is Node3D and str(node.name) == node_name:
		return node as Node3D
	for child in node.get_children():
		var found := _find(child, node_name)
		if found != null:
			return found
	return null


func _toon() -> Node:
	var host := get_parent()
	if host == null:
		return null
	return host.get_node_or_null("PlaygroundToon")


func _feet() -> Node3D:
	var host := get_parent()
	if host == null:
		return null
	var body := host.get_node_or_null("Player")
	if body is Node3D:
		return body as Node3D
	return null


func _toon_script() -> Node:
	return _toon()


func _once(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = AudioStreamOggVorbis.load_from_file(path)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
