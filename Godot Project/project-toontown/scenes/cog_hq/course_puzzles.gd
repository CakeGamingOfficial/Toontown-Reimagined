extends Node

## Country club challenges. A tee-off room is the mole field. A green is
## DistributedGolfGreenGame: the original boards, a match of three, and a stack
## that drops every ten seconds. Clearing the white balls wins a board. The
## door opens either way, matching the server. A battle blocker waits on its cell.

const _RUN := preload("res://scenes/cog_hq/course_run.gd")
const _SLIDE := "res://assets/cog_hq/audio/CHQ_FACT_door_open_sliding.ogg"
const _WILD := 8
const _BOMB := 7
const _WHITE := 3
const _WIDTH := 9
const _HEIGHT := 15

const _COLORS: Array[Color] = [
	Color(0.86, 0.16, 0.16), Color(0.16, 0.38, 0.9), Color(0.16, 0.7, 0.28),
	Color(0.95, 0.95, 0.95), Color(0.12, 0.12, 0.12), Color(0.55, 0.82, 0.95),
	Color(0.95, 0.84, 0.16), Color(0.95, 0.48, 0.08), Color(0.72, 0.28, 0.86),
	Color(0.55, 0.55, 0.55), Color(0.55, 0.08, 0.08), Color(0.08, 0.16, 0.5),
]
const _CODE := "rbgwklyoasRB"
const _BOARDS: Array[PackedStringArray] = [
	["rbygl", "r_______b", "byyywgggr", "r_______b", "bggyyyggr", "r_______b", "byylllyyr", "r_______b", "Blllllllr"],
	["rgby", "rrrgggbbb", "rwrgggbwb", "rrryyybbb", "bByyyyyRr"],
	["bygr", "b_y_b_y__", "b_y_b_yw_", "_b_y_b_y_", "_b_y_b_g_", "__b_g_r__", "__b_g_r__", "___b_g_r_", "___b_g_R_"],
	["rgb", "_b__g____", "_r__g____", "_r__r____", "_w__R____"],
	["lbryg", "___bbb___", "___bwb___", "__lgggr__", "rrgggggll", "_ybbbbby_", "__ryyyr__", "_________", "_________"],
	["lbryg", "l_rr__b__", "l__w__b__", "b__b__b__", "b__b__r__", "l__g__r__", "l__g__b__", "y__y__B__", "_________"],
	["byr", "R_______y", "ygggwgggR", "B_______B", "Rgggggggy", "y_______R", "BgggggggB", "R_______y", "BgggggggR"],
	["bygr", "____bb___", "___bwb___", "_y__y____", "_y__y____", "_yggg_bbb", "____y____", "____y____", "__b_y__b_", "__b_y__b_", "__rrRrrr_"],
	["bryg", "b_yr_by_r", "by_rb_yr_", "r_gbwrg_y", "rg_br_gy_", "b_yg_yr_b", "by_gy_Rb_", "_________", "_________"],
	["lyg", "__lyyyyl_", "__lywyl__", "___lyyl__", "___lyl___", "____ll___", "__ygyg___", "lyl___lyl", "_________"],
	["rgbyl", "l_______r", "brbrbw__r", "r_______r", "r__ylblbl", "r_______b", "lglgly__b", "________b", "___yrgrgr"],
	["rgbyl", "b_______r", "bbbw_wrrr", "___b__r__", "__b__r___", "___b__r__", "__g__y___", "___y__g__", "rrrr_bbbb", "lbyy_ggrl"],
	["yrbg", "ry_____yb", "_yrwwby__", "___yyy___", "_rl__gb__", "lr_____bg", "ylyg_gyly", "_________", "_________"],
	["bylr", "rrr_r_r_r", "_w__r_r_r", "____r_r_r", "ggggR_r_r", "______r_r", "ggggggR_r", "________r", "ggggggggR", "_________"],
	["rgbl", "__y_bb_y_", "_y__w_y__", "yyy____yy", "y_gyyyr_y", "y_______y", "byyyyyyl_", "_________", "_________", "_________", "_________"],
	["o", "b_bb_bb_b", "wb_bb_bw_", "b_bbbbb_b", "bb_bb_bb_", "b_bb_bb_b", "bb_bb_bb_", "_________", "_________"],
	["oa", "s________", "sw_______", "s________", "s________", "s________", "s________", "ssssss___", "_________"],
]

var _doors: Array[Dictionary] = []
var _blockers: Array[Dictionary] = []
var _moles: Array[Dictionary] = []
var _greens: Array[Dictionary] = []
var _mazes: Array[Dictionary] = []
var _layer: CanvasLayer
var _clock: Label
var _active: Dictionary = {}


static func place(host: Node) -> void:
	if Engine.is_editor_hint() or host == null:
		return
	if host.scene_file_path.get_file() != "bossbot_course.tscn":
		return
	if host.get_node_or_null("CoursePuzzles") != null:
		return
	var script := load("res://scenes/cog_hq/course_puzzles.gd") as GDScript
	var node := script.new() as Node
	node.name = "CoursePuzzles"
	host.add_child(node)


func piece_busy(piece: int) -> bool:
	for item in _moles:
		if int(item.get("piece", -1)) == piece and not bool(item.get("done", false)):
			return true
	for item in _greens:
		if int(item.get("piece", -1)) == piece and not bool(item.get("done", false)):
			return true
	return false


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
		var spec: Variant = rooms.get(str(int(piece.get_meta("room", -1))), {})
		if not (spec is Dictionary):
			continue
		var piece_index := int(piece.get_meta("piece", 0))
		for item in (spec as Dictionary).get("entities", []):
			if item is Dictionary:
				_add(piece, piece_index, item)
	_prepare_mazes(host)
	_layer = CanvasLayer.new()
	_layer.name = "CourseGames"
	_layer.layer = 28
	add_child(_layer)
	_clock = Label.new()
	_clock.name = "MazeClock"
	_clock.position = Vector2(0, 24)
	_clock.size = Vector2(1280, 40)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.visible = false
	_layer.add_child(_clock)


func _physics_process(delta: float) -> void:
	var toon := _toon()
	if toon == null:
		return
	var here := Vector3.ZERO
	if toon.has_method("battle_point"):
		here = toon.call("battle_point")
	_poll_doors(here, delta)
	_poll_blockers()
	_poll_mazes(toon, here, delta)
	if not _active.is_empty():
		_run_active(delta)
		return
	_poll_starts(toon, here)


func _add(piece: Node3D, piece_index: int, spec: Dictionary) -> void:
	var kind := str(spec.get("type", ""))
	var ent_id := int(spec.get("id", 0))
	var node := _find(piece, "ent-%d" % ent_id)
	match kind:
		"door":
			if node != null:
				_doors.append(_make_door(node, piece_index, spec))
		"battleBlocker":
			if node != null:
				_blockers.append(_make_blocker(node, piece_index, spec))
		"moleField":
			_moles.append({
				"id": ent_id, "piece": piece_index, "node": node, "spec": spec, "done": false,
			})
		"golfGreenGame":
			_greens.append({
				"id": ent_id, "piece": piece_index, "node": node, "spec": spec, "done": false,
			})


func _poll_starts(toon: Node, here: Vector3) -> void:
	for mole in _moles:
		if bool(mole.get("done", false)):
			continue
		var node: Node3D = mole.get("node")
		if node != null and node.global_position.distance_to(here) < 22.0:
			_begin_mole(toon, mole)
			return
	for green in _greens:
		if bool(green.get("done", false)):
			continue
		var node: Node3D = green.get("node")
		if node != null and node.global_position.distance_to(here) < 16.0:
			_begin_green(toon, green)
			return


func _begin_mole(toon: Node, mole: Dictionary) -> void:
	var spec: Dictionary = mole.get("spec", {})
	var columns := maxi(int(spec.get("numSquaresX", 6)), 1)
	var rows := maxi(int(spec.get("numSquaresY", 6)), 1)
	toon.call("hold_for_battle", true)
	var root := _panel()
	var grid := GridContainer.new()
	grid.columns = columns
	root.add_child(grid)
	var hills: Array[Button] = []
	for _index in columns * rows:
		var hill := Button.new()
		hill.custom_minimum_size = Vector2(54, 54)
		hill.text = ""
		hill.disabled = true
		grid.add_child(hill)
		hill.pressed.connect(_whack.bind(hills.size()))
		hills.append(hill)
	var caption := _caption(root, "Whack %d moles" % (int(spec.get("molesBase", 4)) + int(spec.get("molesPerPlayer", 1))))
	_active = {
		"kind": "mole",
		"mole": mole,
		"hills": hills,
		"up": -1,
		"popup": 0,
		"bomb": false,
		"score": 0,
		"target": int(spec.get("molesBase", 4)) + int(spec.get("molesPerPlayer", 1)),
		"left": float(spec.get("timeToPlay", 60)),
		"wait": 1.2,
		"rounds": 0,
		"caption": caption,
		"toon": toon,
	}


func _begin_green(toon: Node, green: Dictionary) -> void:
	var spec: Dictionary = green.get("spec", {})
	var count := int(spec.get("puzzleBase", 4)) + int(spec.get("puzzlePerPlayer", 1))
	var order: Array[int] = []
	for index in _BOARDS.size():
		order.append(index)
	order.shuffle()
	var chosen: Array[int] = []
	for index in mini(count, order.size()):
		chosen.append(order[index])
	toon.call("hold_for_battle", true)
	var root := _panel()
	var grid := GridContainer.new()
	grid.columns = _WIDTH
	root.add_child(grid)
	var cells: Array[ColorRect] = []
	cells.resize(_WIDTH * _HEIGHT)
	for z in range(_HEIGHT - 1, -1, -1):
		for x in _WIDTH:
			var cell := ColorRect.new()
			cell.custom_minimum_size = Vector2(28, 22)
			cell.color = Color(0.05, 0.25, 0.08, 1)
			grid.add_child(cell)
			cells[x + z * _WIDTH] = cell
	var caption := _caption(root, "Clear the white balls")
	_active = {
		"kind": "green",
		"green": green,
		"boards": chosen,
		"board_index": 0,
		"cells": cells,
		"grid": PackedInt32Array(),
		"aim": 4,
		"next": 0,
		"pattern": PackedInt32Array(),
		"rise": 10.0,
		"left": float(spec.get("timeToPlay", 120)),
		"caption": caption,
		"toon": toon,
		"shot": false,
	}
	_load_board()


func _run_active(delta: float) -> void:
	if str(_active.get("kind", "")) == "mole":
		_run_mole(delta)
	else:
		_run_green(delta)


func _run_mole(delta: float) -> void:
	_active["left"] = float(_active["left"]) - delta
	_active["wait"] = float(_active["wait"]) - delta
	var caption: Label = _active["caption"]
	caption.text = "Moles %d/%d    %d" % [int(_active["score"]), int(_active["target"]), ceili(float(_active["left"]))]
	if float(_active["wait"]) <= 0.0:
		_pop_mole()
	if float(_active["left"]) > 0.0:
		return
	if int(_active["score"]) >= int(_active["target"]):
		_finish_mole(true)
		return
	_active["rounds"] = int(_active["rounds"]) + 1
	if int(_active["rounds"]) >= 4:
		_finish_mole(false)
		return
	_active["left"] = 60.0
	_active["score"] = 0
	_active["up"] = -1
	_hide_hills()


func _pop_mole() -> void:
	_hide_hills()
	var hills: Array = _active["hills"]
	var index := randi() % hills.size()
	var hill: Button = hills[index]
	var bomb := randi() % 4 == 0
	hill.disabled = false
	hill.text = "!" if bomb else "M"
	hill.modulate = Color(0.9, 0.3, 0.2) if bomb else Color(0.45, 0.3, 0.15)
	_active["up"] = index
	_active["popup"] = int(_active["popup"]) + 1
	_active["bomb"] = bomb
	_active["wait"] = 2.4


func _whack(index: int) -> void:
	if _active.is_empty() or int(_active.get("up", -2)) != index:
		return
	if bool(_active.get("bomb", false)):
		_hurt(20)
	else:
		_active["score"] = int(_active["score"]) + 1
	_active["up"] = -1
	_active["wait"] = 0.6
	_hide_hills()
	if int(_active["score"]) >= int(_active["target"]):
		_finish_mole(true)


func _finish_mole(won: bool) -> void:
	var mole: Dictionary = _active["mole"]
	mole["done"] = true
	var toon: Node = _active["toon"]
	_close_panel()
	if toon != null:
		toon.call("hold_for_battle", false)
		if won:
			toon.call("show_notice", "Mole stomp!")
	_fire(int(mole.get("piece", -1)), int(mole.get("id", 0)))


func _load_board() -> void:
	var chosen: Array = _active["boards"]
	var index := int(_active["board_index"])
	if index >= chosen.size():
		_finish_green(true)
		return
	var board := _BOARDS[int(chosen[index])]
	var grid := PackedInt32Array()
	grid.resize(_WIDTH * _HEIGHT)
	grid.fill(-1)
	for row in range(1, board.size()):
		var text := board[row]
		for column in text.length():
			var mark := text.substr(column, 1)
			var color := _CODE.find(mark)
			if color < 0:
				continue
			var x := text.length() - column - 1
			var z := _HEIGHT - 1 - (row - 1)
			if x >= 0 and x < _WIDTH and z >= 0 and z < _HEIGHT:
				grid[x + z * _WIDTH] = color
	var pattern := PackedInt32Array()
	for column in board[0].length():
		var color := _CODE.find(board[0].substr(column, 1))
		if color < 0:
			continue
		pattern.insert(randi() % (pattern.size() + 1), color)
		pattern.insert(randi() % (pattern.size() + 1), color)
	if pattern.is_empty():
		pattern.append(0)
	_active["grid"] = grid
	_active["pattern"] = pattern
	_active["next"] = 0
	_active["aim"] = 4
	_active["rise"] = 10.0
	_paint()


func _run_green(delta: float) -> void:
	_active["left"] = float(_active["left"]) - delta
	_active["rise"] = float(_active["rise"]) - delta
	var caption: Label = _active["caption"]
	var pattern: PackedInt32Array = _active["pattern"]
	var nxt := pattern[int(_active["next"]) % pattern.size()]
	caption.text = "Board %d/%d    %d    aim %d" % [int(_active["board_index"]) + 1, (_active["boards"] as Array).size(), ceili(float(_active["left"])), int(_active["aim"]) + 1]
	caption.modulate = _COLORS[nxt]
	if float(_active["left"]) <= 0.0:
		_hurt(20)
		_finish_green(false)
		return
	if float(_active["rise"]) <= 0.0:
		_active["rise"] = 10.0
		if not _drop_stack():
			_hurt(20)
			_finish_green(false)
			return
		_paint()
	if bool(_active.get("shot", false)):
		_active["shot"] = false
		_shoot(nxt)


func _unhandled_input(event: InputEvent) -> void:
	if _active.is_empty() or str(_active.get("kind", "")) != "green":
		return
	if event.is_action_pressed("ui_left"):
		_active["aim"] = maxi(int(_active["aim"]) - 1, 0)
	elif event.is_action_pressed("ui_right"):
		_active["aim"] = mini(int(_active["aim"]) + 1, _WIDTH - 1)
	elif event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		_active["shot"] = true


func _shoot(color: int) -> void:
	var grid: PackedInt32Array = _active["grid"]
	var column := int(_active["aim"])
	var place := -1
	for z in range(_HEIGHT - 1, -1, -1):
		if grid[column + z * _WIDTH] == -1:
			place = z
			break
	if place < 0:
		_hurt(20)
		_finish_green(false)
		return
	grid[column + place * _WIDTH] = color
	_active["grid"] = grid
	_active["next"] = int(_active["next"]) + 1
	if color == _BOMB:
		_clear_bomb(column, place)
	else:
		var matched := _gather(column, place, color)
		if matched.size() >= 3:
			for spot in matched:
				grid[spot] = -1
	_drop_floaters(grid)
	_active["grid"] = grid
	_paint()
	if _whites(grid) == 0:
		_active["board_index"] = int(_active["board_index"]) + 1
		_load_board()


func _drop_stack() -> bool:
	var grid: PackedInt32Array = _active["grid"]
	for x in _WIDTH:
		if grid[x] != -1:
			return false
	var next := PackedInt32Array()
	next.resize(grid.size())
	next.fill(-1)
	for z in range(_HEIGHT - 1):
		for x in _WIDTH:
			next[x + z * _WIDTH] = grid[x + (z + 1) * _WIDTH]
	_active["grid"] = next
	return true


func _gather(x: int, z: int, color: int) -> Array[int]:
	var seen := {}
	var stack: Array[Vector2i] = [Vector2i(x, z)]
	var found: Array[int] = []
	while not stack.is_empty():
		var spot: Vector2i = stack.pop_back()
		var key := spot.x + spot.y * _WIDTH
		if seen.has(key):
			continue
		var there := _at(spot.x, spot.y)
		if there < 0:
			continue
		if there != color and there != _WILD and color != _WILD:
			continue
		seen[key] = true
		found.append(key)
		for neighbor in _neighbors(spot.x, spot.y):
			stack.append(neighbor)
	return found


func _clear_bomb(x: int, z: int) -> void:
	var grid: PackedInt32Array = _active["grid"]
	grid[x + z * _WIDTH] = -1
	for neighbor in _neighbors(x, z):
		var key := neighbor.x + neighbor.y * _WIDTH
		if key >= 0 and key < grid.size():
			grid[key] = -1
	_active["grid"] = grid


func _drop_floaters(grid: PackedInt32Array) -> void:
	var grounded := {}
	var pending: Array[Vector2i] = []
	for x in _WIDTH:
		if grid[x + (_HEIGHT - 1) * _WIDTH] != -1:
			pending.append(Vector2i(x, _HEIGHT - 1))
	while not pending.is_empty():
		var spot: Vector2i = pending.pop_back()
		var key := spot.x + spot.y * _WIDTH
		if grounded.has(key) or _at_grid(grid, spot.x, spot.y) < 0:
			continue
		grounded[key] = true
		for neighbor in _neighbors(spot.x, spot.y):
			pending.append(neighbor)
	for index in grid.size():
		if grid[index] != -1 and not grounded.has(index):
			grid[index] = -1


func _whites(grid: PackedInt32Array) -> int:
	var count := 0
	for color in grid:
		if color == _WHITE:
			count += 1
	return count


func _finish_green(won: bool) -> void:
	var green: Dictionary = _active["green"]
	green["done"] = true
	var toon: Node = _active["toon"]
	var left := maxi(int(floor(float(_active.get("left", 0.0)))), 0)
	_close_panel()
	if toon != null:
		toon.call("hold_for_battle", false)
		if won:
			_reward_gag(toon)
			if left > 0 and toon.has_method("heal"):
				toon.call("heal", left)
			toon.call("show_notice", "Fore!")
	_fire(int(green.get("piece", -1)), int(green.get("id", 0)))


func _reward_gag(toon: Node) -> void:
	if not toon.has_method("battle_loadout"):
		return
	var loadout: Object = toon.call("battle_loadout")
	if loadout == null:
		return
	var tracks: Array[int] = []
	for track in 7:
		if loadout.has_method("gag_usable") and bool(loadout.call("gag_usable", track, 0)):
			tracks.append(track)
	if tracks.is_empty():
		return
	var track := tracks[randi() % tracks.size()]
	for level in range(6, -1, -1):
		if int(loadout.call("purchase", track, level)) > 0:
			return


func _paint() -> void:
	var grid: PackedInt32Array = _active["grid"]
	var cells: Array = _active["cells"]
	var aim := int(_active["aim"])
	for index in cells.size():
		var box: ColorRect = cells[index]
		var color := int(grid[index]) if index < grid.size() else -1
		if color >= 0 and color < _COLORS.size():
			box.color = _COLORS[color]
		elif index % _WIDTH == aim:
			box.color = Color(0.15, 0.45, 0.18, 1)
		else:
			box.color = Color(0.05, 0.22, 0.08, 1)


func _at(x: int, z: int) -> int:
	return _at_grid(_active["grid"], x, z)


func _at_grid(grid: PackedInt32Array, x: int, z: int) -> int:
	if x < 0 or z < 0 or x >= _WIDTH or z >= _HEIGHT:
		return -1
	return int(grid[x + z * _WIDTH])


func _neighbors(x: int, z: int) -> Array[Vector2i]:
	var spots: Array[Vector2i] = [Vector2i(x - 1, z), Vector2i(x + 1, z)]
	if z % 2 == 0:
		spots.append(Vector2i(x, z + 1))
		spots.append(Vector2i(x + 1, z + 1))
		spots.append(Vector2i(x, z - 1))
		spots.append(Vector2i(x + 1, z - 1))
	else:
		spots.append(Vector2i(x, z + 1))
		spots.append(Vector2i(x - 1, z + 1))
		spots.append(Vector2i(x, z - 1))
		spots.append(Vector2i(x - 1, z - 1))
	return spots


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
		if node.global_position.distance_to(here) > 18.0:
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


func _fire(piece: int, ent_id: int) -> void:
	for door in _doors:
		if int(door["piece"]) != piece:
			continue
		for lock in door["locks"]:
			if int((lock as Dictionary)["event"]) == ent_id:
				(lock as Dictionary)["open"] = true


func _prepare_mazes(host: Node) -> void:
	for child in host.get_children():
		if not str(child.name).begins_with("Piece"):
			continue
		var piece := child as Node3D
		if piece == null:
			continue
		var sections: Array[Node3D] = []
		_collect(piece, "Maze_Inside", false, sections)
		if sections.is_empty():
			continue
		sections.sort_custom(func(a: Node3D, b: Node3D) -> bool: return str(a.name) < str(b.name))
		var roll: Array = [0, 0, 90, 90, 180, 180, 270, 270]
		roll.shuffle()
		for index in sections.size():
			sections[index].rotate_object_local(Vector3(0.0, 0.0, 1.0), deg_to_rad(float(roll[index % roll.size()])))
		var names: Array = []
		if sections.size() == 2:
			names = ["HedgeBlock_0_1"]
		elif sections.size() == 4:
			var choices: Array = [
				["HedgeBlock_0_1", "HedgeBlock_1_3", "HedgeBlock_2_3"],
				["HedgeBlock_0_2", "HedgeBlock_2_3", "HedgeBlock_1_3"],
				["HedgeBlock_0_1", "HedgeBlock_0_2", "HedgeBlock_1_3", "HedgeBlock_2_3"],
			]
			names = choices[randi() % choices.size()]
		for block_name in names:
			var blocks: Array[Node3D] = []
			_collect(piece, str(block_name), true, blocks)
			for block in blocks:
				block.queue_free()
		var entrance := _find(piece, "ENTRANCE")
		var finish := _find(piece, "finish")
		if entrance == null or finish == null:
			continue
		_mazes.append({
			"entrance": entrance,
			"finish": finish,
			"duration": 35.0 + 15.0 * float(sections.size()),
			"left": 0.0,
			"started": false,
			"done": false,
		})


func _poll_mazes(toon: Node, here: Vector3, delta: float) -> void:
	var showing := false
	var left := 0.0
	for maze in _mazes:
		if bool(maze.get("done", false)):
			continue
		var entrance: Node3D = maze.get("entrance")
		var finish: Node3D = maze.get("finish")
		if entrance == null or finish == null:
			continue
		if not bool(maze.get("started", false)):
			if entrance.global_position.distance_to(here) > 8.0:
				continue
			maze["started"] = true
			maze["left"] = float(maze["duration"])
			if toon.has_method("show_notice"):
				toon.call("show_notice", "Race through the Hedge Maze for a laff bonus!")
		maze["left"] = float(maze["left"]) - delta
		showing = true
		left = float(maze["left"])
		if finish.global_position.distance_to(here) <= 15.0:
			maze["done"] = true
			showing = false
			if toon.has_method("heal"):
				toon.call("heal", 200)
			if toon.has_method("show_notice"):
				toon.call("show_notice", "You finished the Hedge Maze in 1st place!")
			continue
		if float(maze["left"]) <= 0.0:
			maze["done"] = true
			showing = false
			if toon.has_method("squish"):
				toon.call("squish", 20)
			if toon.has_method("plant"):
				toon.call("plant", finish.global_position, 0.0)
			if toon.has_method("show_notice"):
				toon.call("show_notice", "Time is up in the Hedge Maze!")
	if _clock == null:
		return
	_clock.visible = showing
	if showing:
		_clock.text = "Maze Race! %d" % int(ceil(maxf(left, 0.0)))


func _collect(node: Node, piece: String, exact: bool, found: Array[Node3D]) -> void:
	var node_name := str(node.name)
	var hit := node_name == piece if exact else node_name.begins_with(piece)
	if hit and node is Node3D:
		found.append(node as Node3D)
	for child in node.get_children():
		_collect(child, piece, exact, found)


func _make_door(node: Node3D, piece_index: int, spec: Dictionary) -> Dictionary:
	var locks: Array[Dictionary] = []
	for index in 4:
		var event_id := int(spec.get("unlock%dEvent" % index, 0))
		var opened := int(spec.get("isLock%dUnlocked" % index, 0)) == 1 or event_id == 0
		locks.append({"event": event_id, "open": opened})
	var left := _find_loose(node, "doorLeft")
	var right := _find_loose(node, "doorRight")
	return {
		"piece": piece_index,
		"node": node,
		"locks": locks,
		"opened": false,
		"slid": false,
		"age": 0.0,
		"left": left,
		"right": right,
		"left_x": left.position.x if left != null else 0.0,
		"right_x": right.position.x if right != null else 0.0,
	}


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


func _panel() -> Control:
	_close_panel()
	var root := PanelContainer.new()
	root.name = "Game"
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.position = Vector2(-260, -280)
	root.custom_minimum_size = Vector2(520, 560)
	_layer.add_child(root)
	var box := VBoxContainer.new()
	root.add_child(box)
	return box


func _caption(root: Control, text: String) -> Label:
	var caption := Label.new()
	caption.text = text
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(caption)
	return caption


func _close_panel() -> void:
	if _layer == null:
		_active = {}
		return
	var old := _layer.get_node_or_null("Game")
	if old != null:
		old.queue_free()
	_active = {}


func _hide_hills() -> void:
	var hills: Array = _active.get("hills", [])
	for hill in hills:
		var button := hill as Button
		if button == null:
			continue
		button.disabled = true
		button.text = ""
		button.modulate = Color(0.25, 0.45, 0.2)


func _hurt(amount: int) -> void:
	var toon: Node = _active.get("toon")
	if toon == null or not toon.has_method("battle_loadout"):
		return
	var loadout: Object = toon.call("battle_loadout")
	if loadout != null and loadout.has_method("take_damage"):
		loadout.call("take_damage", amount)
		if loadout.has_method("save"):
			loadout.call("save")


func _once(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = AudioStreamOggVorbis.load_from_file(path)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _toon() -> Node:
	var host := get_parent()
	if host == null:
		return null
	return host.get_node_or_null("PlaygroundToon")


func _find_loose(node: Node, piece: String) -> Node3D:
	if node == null:
		return null
	if str(node.name) == piece or str(node.name).begins_with(piece):
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
