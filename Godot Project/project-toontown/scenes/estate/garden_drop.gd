extends CanvasLayer

## GardenDropGame. Beans fall, the mouse pushes them, and three of one color
## clear. The three beans that start on the board are the ones that have to go.

signal finished(won: bool)

const _MIN_X := -0.47
const _MIN_Z := -0.1
const _CELL := 0.085
const _CELL_Z := 0.068
const _COLS := 11
const _ROWS := 11
const _COLORS: Array[Color] = [Color(1, 0, 0), Color(0, 0, 1), Color(0, 1, 0)]

var _beans: Array[Dictionary] = []
var _grid: Array = []
var _que := Vector2.ZERO
var _drop := 0.0
var _won := false
var _board: Control
var _note: Label
var _quit: Button
var _quit_call := Callable()


func _ready() -> void:
	layer = 40
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := ColorRect.new()
	panel.color = Color(0.737, 0.573, 0.345, 1.0)
	panel.position = Vector2(240, 80)
	panel.size = Vector2(800, 640)
	add_child(panel)
	_board = Control.new()
	_board.position = Vector2(40, 30)
	_board.size = Vector2(720, 500)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_board)
	_board.draw.connect(_paint)
	_note = Label.new()
	_note.position = Vector2(40, 540)
	_note.size = Vector2(500, 70)
	_note.text = "Move the white bean. Matching three clears them."
	_note.add_theme_font_size_override("font_size", 22)
	panel.add_child(_note)
	_quit = Button.new()
	_quit.text = "Exit Mini Game"
	_quit.position = Vector2(560, 548)
	_quit.custom_minimum_size = Vector2(200, 48)
	_quit_call = _exit.bind(false)
	_quit.pressed.connect(_quit_call)
	panel.add_child(_quit)
	for col in _COLS:
		var row: Array = []
		row.resize(_ROWS)
		_grid.append(row)
	for _i in 3:
		var bean := _make(randi() % 3, true)
		bean["x"] = _MIN_X + randf() * float(_COLS) * _CELL
		bean["z"] = 0.0
		_beans.append(bean)
		_stick(bean, true)
	_board.queue_redraw()


func _process(delta: float) -> void:
	if _won:
		return
	var mouse := _board.get_local_mouse_position()
	_que = Vector2(_unproject(mouse).x, _unproject(mouse).y)
	_drop += delta
	if _drop >= 1.0:
		_drop = 0.0
		var falling := _make(randi() % 3, false)
		falling["x"] = clampf(_que.x, _MIN_X, _max_x())
		falling["z"] = 0.6
		falling["active"] = true
		_beans.append(falling)
	var foundations := 0
	for bean in _beans:
		if bool(bean.get("dead", false)):
			continue
		if bool(bean.get("foundation", false)):
			foundations += 1
		if not bool(bean.get("active", false)):
			continue
		var vx := float(bean.get("vx", 0.0))
		var vz := float(bean.get("vz", 0.0))
		vz -= 0.9 * delta
		bean["x"] = float(bean["x"]) + vx * delta
		bean["z"] = float(bean["z"]) + vz * delta
		bean["vx"] = vx * (1.0 - delta * 4.0)
		bean["vz"] = vz * (1.0 - delta * 4.0)
		if float(bean["x"]) > _max_x():
			bean["x"] = _max_x()
			bean["vx"] = -float(bean["vx"])
		if float(bean["x"]) < _MIN_X:
			bean["x"] = _MIN_X
			bean["vx"] = -float(bean["vx"])
		if float(bean["z"]) > _max_z():
			bean["z"] = _max_z()
			bean["vz"] = -float(bean["vz"])
		if float(bean["z"]) < _MIN_Z:
			_stick(bean, true)
	_push()
	_collide()
	var kept: Array[Dictionary] = []
	foundations = 0
	for bean in _beans:
		if bool(bean.get("dead", false)):
			continue
		kept.append(bean)
		if bool(bean.get("foundation", false)):
			foundations += 1
	_beans = kept
	if foundations <= 0:
		_won = true
		_note.text = "Congratulations you've watered the plant!"
		_quit.text = "Exit"
		_quit.pressed.disconnect(_quit_call)
		_quit.pressed.connect(_exit.bind(true))
		_quit.show()
	_board.queue_redraw()


func _make(color: int, foundation: bool) -> Dictionary:
	return {
		"x": 0.0, "z": 0.0, "vx": 0.0, "vz": 0.0,
		"color": color, "active": true, "foundation": foundation,
		"dead": false, "col": -1, "row": -1,
	}


func _stick(bean: Dictionary, force: bool) -> void:
	if not bool(bean.get("active", false)):
		return
	var spot := _closest_cell(float(bean["x"]), float(bean["z"]), force)
	if spot.x < 0:
		return
	_set_cell(spot.x, spot.y, bean)
	bean["active"] = false
	bean["col"] = spot.x
	bean["row"] = spot.y
	var at := _cell_pos(spot.x, spot.y)
	bean["x"] = at.x
	bean["z"] = at.y
	bean["vx"] = 0.0
	bean["vz"] = 0.0
	_clear_run(spot.x, spot.y)


func _closest_cell(x: float, z: float, force: bool) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 10000000.0
	for col in _COLS:
		for row in _ROWS:
			if not _cell(col, row).is_empty():
				continue
			if not force and not _has_neighbor(col, row):
				continue
			var at := _cell_pos(col, row)
			var dist := Vector2(x, z).distance_squared_to(at)
			if dist < best_d:
				best_d = dist
				best = Vector2i(col, row)
	return best


func _has_neighbor(col: int, row: int) -> bool:
	var shifts: Array[Vector2i] = []
	if row % 2 == 0:
		shifts = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, -1), Vector2i(1, -1)]
	else:
		shifts = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(0, -1), Vector2i(-1, -1)]
	for shift in shifts:
		if _occupied(col + shift.x, row + shift.y):
			return true
	return false


func _occupied(col: int, row: int) -> bool:
	if col < 0 or row < 0 or col >= _COLS or row >= _ROWS:
		return false
	return not _cell(col, row).is_empty()


func _clear_run(col: int, row: int) -> void:
	var bean: Dictionary = _cell(col, row)
	if bean.is_empty():
		return
	var color := int(bean.get("color", 0))
	var matched: Array[Vector2i] = []
	var pending: Array[Vector2i] = [Vector2i(col, row)]
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		if cell in matched:
			continue
		var here: Dictionary = _cell(cell.x, cell.y)
		if here.is_empty() or int(here.get("color", -1)) != color:
			continue
		matched.append(cell)
		for shift in _neighbors(cell.y):
			var next := Vector2i(cell.x + shift.x, cell.y + shift.y)
			if next.x < 0 or next.y < 0 or next.x >= _COLS or next.y >= _ROWS:
				continue
			var other: Dictionary = _cell(next.x, next.y)
			if other.is_empty() or int(other.get("color", -1)) != color:
				continue
			pending.append(next)
	if matched.size() < 3:
		return
	for cell in matched:
		var gone: Dictionary = _cell(cell.x, cell.y)
		gone["dead"] = true
		_set_cell(cell.x, cell.y, null)


func _neighbors(row: int) -> Array[Vector2i]:
	if row % 2 == 0:
		return [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, -1), Vector2i(1, -1)]
	return [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(0, -1), Vector2i(-1, -1)]


func _collide() -> void:
	for index in _beans.size():
		var bean: Dictionary = _beans[index]
		if bool(bean.get("dead", false)) or not bool(bean.get("active", false)):
			continue
		for other_index in range(index + 1, _beans.size()):
			var other: Dictionary = _beans[other_index]
			if bool(other.get("dead", false)):
				continue
			var dist := Vector2(float(bean["x"]), float(bean["z"])).distance_to(Vector2(float(other["x"]), float(other["z"])))
			if dist >= 0.08:
				continue
			if bool(bean.get("active", false)) == bool(other.get("active", false)):
				continue
			_stick(bean, false)
			_stick(other, false)


func _push() -> void:
	for bean in _beans:
		if bool(bean.get("dead", false)) or not bool(bean.get("active", false)):
			continue
		var at := Vector2(float(bean["x"]), float(bean["z"]))
		var dist := at.distance_to(_que)
		if dist <= 0.0 or dist >= 0.24:
			continue
		var force := (0.12 - absf(dist - 0.12)) / 0.12
		var angle := atan2(_que.x - at.x, at.y - _que.y)
		var push := PI if angle > PI * 0.5 and angle < PI * 1.5 else 0.0
		bean["vx"] = float(bean["vx"]) + cos(push) * force * 0.1
		bean["vz"] = float(bean["vz"]) + sin(push) * force * 0.1


func _paint() -> void:
	var board := _board.size
	_board.draw_rect(Rect2(Vector2.ZERO, board), Color(0.922, 0.922, 0.753))
	for bean in _beans:
		if bool(bean.get("dead", false)):
			continue
		var at := _project(float(bean["x"]), float(bean["z"]))
		var color: Color = _COLORS[int(bean.get("color", 0)) % 3]
		if not bool(bean.get("foundation", false)):
			color.a = 0.55
		_board.draw_circle(at, 16.0, color)
	_board.draw_circle(_project(_que.x, _que.y), 18.0, Color.WHITE)


func _project(x: float, z: float) -> Vector2:
	var span_x := _max_x() - _MIN_X
	var span_z := _max_z() - _MIN_Z
	var px := (x - _MIN_X) / span_x * _board.size.x
	var py := (1.0 - (z - _MIN_Z) / span_z) * _board.size.y
	return Vector2(px, py)


func _unproject(at: Vector2) -> Vector2:
	var span_x := _max_x() - _MIN_X
	var span_z := _max_z() - _MIN_Z
	var x := _MIN_X + clampf(at.x / _board.size.x, 0.0, 1.0) * span_x
	var z := _MIN_Z + (1.0 - clampf(at.y / _board.size.y, 0.0, 1.0)) * span_z
	return Vector2(x, z)


func _cell_pos(col: int, row: int) -> Vector2:
	var offset := _CELL * 0.5 if row % 2 == 0 else 0.0
	return Vector2(col * _CELL + _MIN_X + offset, row * _CELL_Z + _MIN_Z)


func _cell(col: int, row: int) -> Dictionary:
	var line: Array = _grid[col]
	var value: Variant = line[row]
	if value is Dictionary:
		return value
	return {}


func _set_cell(col: int, row: int, value: Variant) -> void:
	var line: Array = _grid[col]
	line[row] = value
	_grid[col] = line


func _max_x() -> float:
	return _MIN_X + float(_COLS) * _CELL


func _max_z() -> float:
	return _MIN_Z + float(_ROWS) * _CELL_Z


func _exit(won: bool) -> void:
	finished.emit(won)
	queue_free()
