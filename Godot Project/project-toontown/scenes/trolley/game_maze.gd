extends "res://scenes/trolley/trolley_minigame.gd"

## Maze Game. maze_1player plus the MazeData walls, Mickey treasures, and Cogs.

const _DATA := "res://assets/minigames/maze_1player.json"
# DistributedMazeGame.TOON_SPEED. OrthoDrive also refuses a step longer than half a cell.
const _TOON_SPEED := 8.0
# MazeSuit. One player gets four suits. These are the 4-suit cell periods
# (ticPeriod / SUIT_TIC_FREQ is seconds per cell) for the slower and faster pairs.
const _SLOW := {
	2000: [128, 65], 1000: [110, 59], 5000: [96, 55],
	4000: [86, 58], 3000: [78, 54], 9000: [71, 50],
}
const _FAST := {
	2000: [62, 42], 1000: [57, 40], 5000: [53, 37],
	4000: [49, 35], 3000: [46, 33], 9000: [43, 32],
}
const _STARTS: Array[Vector2] = [Vector2(0.25, 0.25), Vector2(0.75, 0.75), Vector2(0.25, 0.75), Vector2(0.75, 0.25)]
const _HEADINGS: Array[float] = [0.0, 180.0, 90.0, 270.0]
const _OPPOSITE: Array[int] = [1, 0, 3, 2]
var _width := 0
var _height := 0
var _origin_x := 0
var _origin_y := 0
var _cell := 2.0
var _table: Array = []
var _mx := 0.0
var _my := 0.0
var _treasures: Array[Node3D] = []
var _left := 0
var _cogs: Array[Dictionary] = []
var _stun := 0.0
var _bar_back: Panel
var _bar_fill: ColorRect
var _status_on := false


func _init() -> void:
	title = "Maze Game"
	instructions = "Collect the treasures. Try to get them all, but look out for the Cogs!"
	duration = 60.0


func _build() -> void:
	_show("res://assets/minigames/maze_1player.glb")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_DATA))
	if parsed is Dictionary:
		var info: Dictionary = parsed
		_width = int(info["width"])
		_height = int(info["height"])
		_origin_x = int(info["originX"])
		_origin_y = int(info["originY"])
		_cell = float(info["cell"])
		_table = info["collision"]
		for spot in info["treasures"]:
			var point: Array = spot
			var gem := _spawn("res://assets/minigames/mickey.glb", float(point[0]), float(point[1]), float(point[2]))
			if gem == null:
				gem = _ball(0.35, Color(1, 0.85, 0.1))
				add_child(gem)
				gem.position = _panda(float(point[0]), float(point[1]), float(point[2]))
			_treasures.append(gem)
		_left = _treasures.size()
	_mx = 0.0
	_my = 0.0
	if _blocked(_mx, _my):
		_find_start()
	_make_toon(_panda(_mx, _my, 0.0))
	_place_cogs()
	_aim(_mx, _my - 19.0, 45.0, _mx, _my, 1.0)
	_make_status()
	show_board("maze")


func begin() -> void:
	super.begin()
	if _hud != null:
		_hud.visible = false
	_status_on = true
	_layout_status()


func _play(delta: float) -> void:
	if _stun > 0.0:
		_stun -= delta
		_toon.set_locomotion(0.0, false, false, delta)
	else:
		var move := _stick()
		if move.length() > 0.1:
			move = move.normalized()
		var step := minf(_TOON_SPEED * delta, _cell * 0.5)
		var next_x := _mx + move.x * step
		var next_y := _my + move.y * step
		if not _blocked(next_x, _my):
			_mx = next_x
		if not _blocked(_mx, next_y):
			_my = next_y
		if absf(move.x) > absf(move.y) and absf(move.x) > 0.1:
			_toon.rotation_degrees.y = -90.0 if move.x > 0.0 else 90.0
		elif move.y > 0.1:
			_toon.rotation_degrees.y = 0.0
		elif move.y < -0.1:
			_toon.rotation_degrees.y = 180.0
		# Speed 8 is a walk. set_locomotion plays the run above a tiny threshold,
		# so the walk cycle is requested with the turning flag instead.
		_toon.set_locomotion(0.0, move.length() > 0.1, false, delta)
	_toon.position = _panda(_mx, _my, 0.0)
	_collect()
	_walk_cogs(delta)
	for cog in _cogs:
		var node := cog["node"] as Node3D
		if node.position.distance_to(_toon.position) < 2.0 and _stun <= 0.0:
			_stun = 0.8
			_sfx("MG_Tag_C")
			_sfx("MG_cannon_whizz", 0.4)
	_aim(_mx, _my - 19.0, 45.0, _mx, _my, 1.0)
	if _left <= 0 and _treasures.size() > 0:
		_end()


func _collect() -> void:
	for gem in _treasures:
		if not gem.visible:
			continue
		if gem.position.distance_to(_toon.position) > 1.6:
			continue
		gem.visible = false
		_left -= 1
		score += 1
		_sfx("MG_maze_pickup")
		_paint_bar()


func _make_status() -> void:
	if _hud == null:
		return
	_hud.visible = false
	var layer := _hud.get_parent()
	_bar_back = Panel.new()
	_bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_back.visible = false
	layer.add_child(_bar_back)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.0, 0.7, 0.0)
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill.visible = false
	layer.add_child(_bar_fill)
	var view := get_viewport()
	if not view.size_changed.is_connected(_layout_status):
		view.size_changed.connect(_layout_status)
	_layout_status()


func _layout_status() -> void:
	if _bar_back == null:
		return
	_bar_back.visible = _status_on
	_bar_fill.visible = _status_on
	if not _status_on:
		return
	# goalBar is parented to render2d. One player: (0.84, 0, 0.27), scale 0.42.
	var frame := _render_rect(0.84, 0.27, 0.7 * 0.42, 0.3 * 0.42)
	_bar_back.position = frame.position
	_bar_back.size = frame.size
	var border := maxi(int(round(_render_size(0.02 * 0.42, 0.0).x)), 2)
	var trough := StyleBoxFlat.new()
	trough.bg_color = Color(0.75, 0.75, 0.75)
	trough.border_color = Color(0.35, 0.35, 0.4)
	trough.set_border_width_all(border)
	_bar_back.add_theme_stylebox_override("panel", trough)
	_paint_bar()


func _paint_bar() -> void:
	if _bar_back == null or not _status_on:
		return
	var total := maxi(_treasures.size(), 1)
	var ratio := clampf(float(score) / float(total), 0.0, 1.0)
	var border := _render_size(0.02 * 0.42, 0.02 * 0.42)
	_bar_fill.position = _bar_back.position + border
	var inner := _bar_back.size - border * 2.0
	_bar_fill.size = Vector2(maxf(inner.x * ratio, 0.0), maxf(inner.y, 0.0))


func _render_rect(rx: float, rz: float, rw: float, rh: float) -> Rect2:
	var rect := _render_size(rw, rh)
	var view := get_viewport().get_visible_rect().size
	var center := Vector2((rx + 1.0) * 0.5 * view.x, (1.0 - rz) * 0.5 * view.y)
	return Rect2(center - rect * 0.5, rect)


func _render_size(rw: float, rh: float) -> Vector2:
	var view := get_viewport().get_visible_rect().size
	return Vector2(rw * view.x * 0.5, rh * view.y * 0.5)


func _place_cogs() -> void:
	# One player faces four suits. MazeSuit defaults every one of them to a Flunky.
	var periods: Array[int] = []
	var hood := 2000
	var host := get_parent()
	if host != null and host.get("hood") != null:
		hood = int(host.get("hood"))
	var slow: Array = _SLOW.get(hood, _SLOW[2000])
	var fast: Array = _FAST.get(hood, _FAST[2000])
	for period in slow:
		periods.append(int(period))
	for period in fast:
		periods.append(int(period))
	periods.shuffle()
	var taken: Array[Vector2i] = []
	for index in periods.size():
		var frac := _STARTS[index % _STARTS.size()]
		var tile := _walkable_start(int(frac.x * float(_width)), int(frac.y * float(_height)), taken)
		var cog := Flunky.new()
		cog.set_physics_process(false)
		add_child(cog)
		var world := _tile_world(tile.x, tile.y)
		cog.position = _panda(world.x, world.y, 0.1)
		var suit := {
			"node": cog,
			"tx": tile.x,
			"ty": tile.y,
			"dir": 1,
			"duration": float(periods[index]) / 256.0,
			"elapsed": 0.0,
			"from": world,
			"to": world,
			"heading": 180.0,
			"turn_from": 180.0,
			"turn_to": 180.0,
			"turn_left": 0.0,
		}
		_cogs.append(suit)
		taken.append(tile)
		_begin_leg(suit)
		cog.face_heading(float(suit["heading"]))


func _walk_cogs(delta: float) -> void:
	for cog in _cogs:
		var duration := maxf(float(cog["duration"]), 0.05)
		var elapsed := float(cog["elapsed"]) + delta
		var hops := 0
		while elapsed >= duration and hops < 3:
			elapsed -= duration
			_begin_leg(cog)
			hops += 1
		cog["elapsed"] = elapsed
		var along := clampf(elapsed / duration, 0.0, 1.0)
		var from: Vector2 = cog["from"]
		var to: Vector2 = cog["to"]
		var world := from.lerp(to, along)
		var node := cog["node"] as Flunky
		node.position = _panda(world.x, world.y, 0.1)
		var turn_left := float(cog["turn_left"])
		if turn_left > 0.0:
			turn_left = maxf(turn_left - delta, 0.0)
			cog["turn_left"] = turn_left
			var turn_dur := maxf(0.6 * duration, 0.01)
			var turn := 1.0 - clampf(turn_left / turn_dur, 0.0, 1.0)
			var blended := lerp_angle(deg_to_rad(float(cog["turn_from"])), deg_to_rad(float(cog["turn_to"])), turn)
			cog["heading"] = rad_to_deg(blended)
			node.face_heading(float(cog["heading"]))
		# Walk clip is authored for MazeSuit.DEFAULT_SPEED of 4 units a second.
		node.play_walk(delta * (_cell / duration) / 4.0)


func _begin_leg(cog: Dictionary) -> void:
	var tx := int(cog["tx"])
	var ty := int(cog["ty"])
	var blocked := _other_tiles(cog)
	var direction := _choose_dir(int(cog["dir"]), tx, ty, blocked)
	var nxt := _step_tile(direction, tx, ty)
	if not _suit_walkable(nxt.x, nxt.y, blocked):
		direction = int(cog["dir"])
		nxt = Vector2i(tx, ty)
	var previous := int(cog["dir"])
	cog["dir"] = direction
	cog["tx"] = nxt.x
	cog["ty"] = nxt.y
	cog["from"] = _tile_world(tx, ty)
	cog["to"] = _tile_world(nxt.x, nxt.y)
	var heading := _HEADINGS[direction]
	if direction != previous:
		var from_h := _HEADINGS[previous]
		if is_equal_approx(from_h, 270.0) and is_equal_approx(heading, 0.0):
			from_h = -90.0
		elif is_equal_approx(from_h, 0.0) and is_equal_approx(heading, 270.0):
			from_h = 360.0
		cog["turn_from"] = from_h
		cog["turn_to"] = heading
		cog["turn_left"] = 0.6 * float(cog["duration"])
	else:
		cog["heading"] = heading
		cog["turn_left"] = 0.0
		(cog["node"] as Flunky).face_heading(heading)


func _choose_dir(direction: int, tx: int, ty: int, blocked: Array[Vector2i]) -> int:
	# randrange(WALK_SAME_DIRECTION_PROB) is zero one time in four, and that keeps the heading.
	if randi() % 4 == 0:
		var ahead := _step_tile(direction, tx, ty)
		if _suit_walkable(ahead.x, ahead.y, blocked):
			return direction
	var opposite := _OPPOSITE[direction]
	var options: Array[int] = []
	for candidate in [0, 1, 2, 3]:
		if candidate != opposite:
			options.append(candidate)
	while not options.is_empty():
		var pick := options[randi() % options.size()]
		var nxt := _step_tile(pick, tx, ty)
		if _suit_walkable(nxt.x, nxt.y, blocked):
			return pick
		options.erase(pick)
	return opposite


func _step_tile(direction: int, tx: int, ty: int) -> Vector2i:
	match direction:
		0:
			return Vector2i(tx, ty + 1)
		1:
			return Vector2i(tx, ty - 1)
		2:
			return Vector2i(tx - 1, ty)
		_:
			return Vector2i(tx + 1, ty)


func _other_tiles(cog: Dictionary) -> Array[Vector2i]:
	var taken: Array[Vector2i] = []
	for other in _cogs:
		if other == cog:
			continue
		taken.append(Vector2i(int(other["tx"]), int(other["ty"])))
	return taken


func _walkable_start(tx: int, ty: int, taken: Array[Vector2i]) -> Vector2i:
	var count := 0
	var limit := 0
	var toggle := 0
	var direction := 0
	var guard := 0
	while not _suit_walkable(tx, ty, taken) and guard < 400:
		guard += 1
		match direction:
			0:
				tx -= 1
			1:
				ty -= 1
			2:
				tx += 1
			_:
				ty += 1
		count += 1
		if count > limit:
			count = 0
			direction = (direction + 1) % 4
			toggle += 1
			if (toggle & 1) == 0:
				limit += 1
	return Vector2i(tx, ty)


func _suit_walkable(tx: int, ty: int, blocked: Array[Vector2i]) -> bool:
	# MazeBase.isWalkable: the suit stands on a corner, so four cells must be open.
	if tx <= 0 or ty <= 0 or tx >= _width or ty >= _height:
		return false
	if _solid_cell(tx, ty) or _solid_cell(tx - 1, ty) or _solid_cell(tx, ty - 1) or _solid_cell(tx - 1, ty - 1):
		return false
	return not blocked.has(Vector2i(tx, ty))


func _find_start() -> void:
	for radius in 12:
		for ty in range(_origin_y - radius, _origin_y + radius + 1):
			for tx in range(_origin_x - radius, _origin_x + radius + 1):
				var world := _tile_world(tx, ty)
				if not _blocked(world.x, world.y):
					_mx = world.x
					_my = world.y
					return


func _tile_world(tx: int, ty: int) -> Vector2:
	return Vector2((float(tx) - float(_origin_x)) * _cell, (float(ty) - float(_origin_y)) * _cell)


func _blocked(x: float, y: float) -> bool:
	return _solid(x, y) or _solid(x + 0.6, y) or _solid(x - 0.6, y) or _solid(x, y + 0.6) or _solid(x, y - 0.6)


func _solid_cell(tx: int, ty: int) -> bool:
	if _table.is_empty() or tx < 0 or ty < 0 or tx >= _width or ty >= _height:
		return true
	var row: Array = _table[ty]
	return int(row[tx]) == 1


func _solid(x: float, y: float) -> bool:
	if _table.is_empty():
		return false
	var tx := int(floor(x / _cell + float(_origin_x)))
	var ty := int(floor(y / _cell + float(_origin_y)))
	if tx < 0 or ty < 0 or tx >= _width or ty >= _height:
		return true
	var row: Array = _table[ty]
	return int(row[tx]) == 1
