extends RefCounted
## The district's copy of one picnic table. Two seated toons play. The first
## two occupied seats are the two colors. A countdown of 20 seconds starts the
## game, and either toon can press Start once everyone seated has done it.

const _RULES := "res://assets/neighborhoods/acorn_acres/picnic_rules.json"
const _START := 20000
const _TURN := 40000

static var _ready_rules := false
static var _checkers_adj: Array = []
static var _checkers_jump: Array = []
static var _chinese_adj: Array = []
static var _homes: Array = []


static func blank() -> Dictionary:
	return {
		"seats": [0, 0, 0, 0, 0, 0],
		"kind": "",
		"phase": "",
		"p1": 0,
		"p2": 0,
		"turn": 1,
		"seq": 0,
		"chain": -1,
		"move": {"s": -1, "d": -1, "c": -1},
		"squares": [],
		"grid": [],
		"until": 0,
		"turn_until": 0,
		"winner": 0,
		"tie": false,
		"ready": [],
	}


static func act(state: Dictionary, peer: int, action: String, payload: Dictionary, now: int) -> Dictionary:
	_ensure()
	var book := blank()
	if not state.is_empty():
		book = state.duplicate(true)
	if action == "join":
		return _join(book, peer, int(payload.get("seat", -1)), now)
	if action == "leave":
		return _leave(book, peer, now)
	if action == "pick":
		return _pick(book, peer, String(payload.get("kind", "")), now)
	if action == "start":
		return _press_start(book, peer, now)
	if action == "stop":
		return _stop_chain(book, peer, now)
	if action == "move":
		return _move(book, peer, int(payload.get("s", -1)), int(payload.get("d", -1)), int(payload.get("c", -1)), now)
	return {}


static func tick(state: Dictionary, now: int) -> Dictionary:
	if state.is_empty():
		return {}
	_ensure()
	var book: Dictionary = state.duplicate(true)
	var phase := String(book.get("phase", ""))
	if phase == "over":
		if int(book.get("turn_until", 0)) == 0:
			book["turn_until"] = now + 3000
			return book
		if now >= int(book["turn_until"]):
			return blank()
		return {}
	if phase == "ready" and int(book.get("until", 0)) > 0 and now >= int(book["until"]) and _occupied(book) >= 2:
		_begin(book, now)
		return book
	if phase == "play" and int(book.get("turn_until", 0)) > 0 and now >= int(book["turn_until"]):
		book["turn_until"] = 0
		if String(book.get("kind", "")) == "checkers":
			return book
		if int(book.get("chain", -1)) >= 0:
			_finish_turn(book, now)
			return book
		_random_move(book, now)
		return book
	return {}


static func _ensure() -> void:
	if _ready_rules:
		return
	_ready_rules = true
	if not FileAccess.file_exists(_RULES):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_RULES))
	if not parsed is Dictionary:
		return
	var rules: Dictionary = parsed
	var checkers: Dictionary = rules.get("checkers", {})
	var chinese: Dictionary = rules.get("chinese", {})
	_checkers_adj = checkers.get("adjacent", [])
	_checkers_jump = checkers.get("jumps", [])
	_chinese_adj = chinese.get("adjacent", [])
	_homes = chinese.get("homes", [])


static func _join(book: Dictionary, peer: int, seat: int, now: int) -> Dictionary:
	if seat < 0 or seat > 5 or peer == 0:
		return {}
	var seats: Array = book["seats"]
	if _holding(seats, peer) >= 0 or int(seats[seat]) != 0:
		return {}
	var phase := String(book.get("phase", ""))
	if phase == "play" or phase == "over":
		return {}
	seats[seat] = peer
	book["seats"] = seats
	_assign(book)
	if String(book.get("kind", "")) != "" and _occupied(book) >= 2 and int(book.get("until", 0)) == 0:
		book["until"] = now + _START
		book["phase"] = "ready"
	return book


static func _leave(book: Dictionary, peer: int, _now: int) -> Dictionary:
	var seats: Array = book["seats"]
	var seat := _holding(seats, peer)
	if seat < 0:
		return {}
	var phase := String(book.get("phase", ""))
	var playing := peer == int(book.get("p1", 0)) or peer == int(book.get("p2", 0))
	seats[seat] = 0
	book["seats"] = seats
	book["ready"] = _without(book.get("ready", []), peer)
	if phase == "play" and playing:
		var other := int(book["p2"]) if peer == int(book["p1"]) else int(book["p1"])
		if other != 0 and _holding(seats, other) >= 0:
			book["phase"] = "over"
			book["winner"] = other
			book["tie"] = false
			book["turn_until"] = 0
			book["chain"] = -1
			book["seq"] = int(book.get("seq", 0)) + 1
			_clear_move(book)
			return book
		return blank()
	if _occupied(book) == 0:
		return blank()
	_assign(book)
	if _occupied(book) < 2:
		book["until"] = 0
		book["ready"] = []
	if phase == "over" and _occupied(book) == 0:
		return blank()
	return book


static func _pick(book: Dictionary, peer: int, kind: String, now: int) -> Dictionary:
	if _holding(book["seats"], peer) < 0:
		return {}
	if String(book.get("kind", "")) != "" or String(book.get("phase", "")) == "play":
		return {}
	if kind != "chinese" and kind != "checkers" and kind != "findfour":
		return {}
	book["kind"] = kind
	book["phase"] = "ready"
	book["winner"] = 0
	book["tie"] = false
	book["chain"] = -1
	book["turn"] = 1
	_clear_move(book)
	_deal(book)
	_assign(book)
	if _occupied(book) >= 2:
		book["until"] = now + _START
	return book


static func _press_start(book: Dictionary, peer: int, now: int) -> Dictionary:
	if String(book.get("phase", "")) != "ready" or _holding(book["seats"], peer) < 0:
		return {}
	var ready: Array = book.get("ready", [])
	if not ready.has(peer):
		ready.append(peer)
	book["ready"] = ready
	if _occupied(book) >= 2 and _everyone_ready(book):
		_begin(book, now)
	return book


static func _begin(book: Dictionary, now: int) -> void:
	_assign(book)
	if int(book.get("p1", 0)) == 0 or int(book.get("p2", 0)) == 0:
		return
	book["phase"] = "play"
	book["until"] = 0
	book["ready"] = []
	book["turn"] = 1
	book["chain"] = -1
	book["winner"] = 0
	book["tie"] = false
	book["turn_until"] = now + _TURN
	book["seq"] = int(book.get("seq", 0)) + 1
	_clear_move(book)
	_deal(book)


static func _stop_chain(book: Dictionary, peer: int, now: int) -> Dictionary:
	if String(book.get("phase", "")) != "play" or _color(book, peer) != int(book.get("turn", 1)):
		return {}
	if int(book.get("chain", -1)) < 0:
		return {}
	_finish_turn(book, now)
	return book


static func _move(book: Dictionary, peer: int, source: int, dest: int, column: int, now: int) -> Dictionary:
	if String(book.get("phase", "")) != "play":
		return {}
	var player := int(book.get("turn", 1))
	if _color(book, peer) != player:
		return {}
	var kind := String(book.get("kind", ""))
	if kind == "findfour":
		if not _drop(book, player, column, now):
			return {}
		return book
	if kind == "checkers":
		if not _checkers(book, player, source, dest, now):
			return {}
		return book
	if kind == "chinese":
		if not _chinese(book, player, source, dest, now):
			return {}
		return book
	return {}


static func _checkers(book: Dictionary, player: int, source: int, dest: int, now: int) -> bool:
	var squares: Array = book.get("squares", [])
	if source < 0 or dest < 0 or source >= squares.size() or dest >= squares.size():
		return false
	var chain := int(book.get("chain", -1))
	if chain >= 0 and source != chain:
		return false
	if chain < 0 and _side(int(squares[source])) != player:
		return false
	var jumped := _legal_jump(squares, player, source, dest)
	var stepped := chain < 0 and not _any_jump(squares, player) and _legal_step(squares, player, source, dest)
	if not jumped and not stepped:
		return false
	var state := int(squares[source])
	if jumped:
		var slot := _link(_checkers_jump, source, dest)
		var captured := _link_at(_checkers_adj, source, slot)
		if captured >= 0:
			squares[captured] = 0
	squares[source] = 0
	var crowned := false
	if state <= 2 and player == 1 and dest >= 28:
		state = 3
		crowned = true
	elif state <= 2 and player == 2 and dest <= 3:
		state = 4
		crowned = true
	squares[dest] = state
	book["squares"] = squares
	book["seq"] = int(book.get("seq", 0)) + 1
	book["move"] = {"s": source, "d": dest, "c": -1}
	if jumped and not crowned and _piece_jump(squares, player, dest):
		book["chain"] = dest
		return true
	book["chain"] = -1
	_finish_turn(book, now)
	return true


static func _chinese(book: Dictionary, player: int, source: int, dest: int, now: int) -> bool:
	var squares: Array = book.get("squares", [])
	if source < 0 or dest < 0 or source >= squares.size() or dest >= squares.size():
		return false
	var color := 1 if player == 1 else 4
	var chain := int(book.get("chain", -1))
	if chain >= 0 and source != chain:
		return false
	if chain < 0 and int(squares[source]) != color:
		return false
	var hopped := _chinese_hop(squares, source, dest)
	var walked := chain < 0 and _chinese_walk(squares, source, dest)
	if not hopped and not walked:
		return false
	squares[dest] = squares[source]
	squares[source] = 0
	book["squares"] = squares
	book["seq"] = int(book.get("seq", 0)) + 1
	book["move"] = {"s": source, "d": dest, "c": -1}
	if _chinese_home(squares, player):
		book["chain"] = -1
		book["phase"] = "over"
		book["winner"] = int(book["p1"]) if player == 1 else int(book["p2"])
		book["tie"] = false
		book["turn_until"] = 0
		return true
	if hopped and _chinese_more(squares, dest):
		book["chain"] = dest
		return true
	book["chain"] = -1
	_finish_turn(book, now)
	return true


static func _drop(book: Dictionary, player: int, column: int, now: int) -> bool:
	var grid: Array = book.get("grid", [])
	if column < 0 or column > 6 or grid.size() < 42 or int(grid[column]) != 0:
		return false
	var row := 0
	for next in 6:
		if int(grid[next * 7 + column]) == 0:
			row = next
	var cell := row * 7 + column
	grid[cell] = player
	book["grid"] = grid
	book["seq"] = int(book.get("seq", 0)) + 1
	book["move"] = {"s": cell, "d": cell, "c": column}
	book["chain"] = -1
	if _four(grid, row, column):
		book["phase"] = "over"
		book["winner"] = int(book["p1"]) if player == 1 else int(book["p2"])
		book["tie"] = false
		book["turn_until"] = 0
		return true
	var open := false
	for next in 7:
		if int(grid[next]) == 0:
			open = true
	if not open:
		book["phase"] = "over"
		book["winner"] = 0
		book["tie"] = true
		book["turn_until"] = 0
		return true
	_finish_turn(book, now)
	return true


static func _finish_turn(book: Dictionary, now: int) -> void:
	if String(book.get("phase", "")) != "play":
		return
	var previous := int(book.get("turn", 1))
	var nxt := 2 if previous == 1 else 1
	book["turn"] = nxt
	book["chain"] = -1
	var kind := String(book.get("kind", ""))
	var stuck := false
	if kind == "checkers":
		stuck = not _has_play(book["squares"], nxt)
	elif kind == "chinese":
		stuck = not _chinese_has(book["squares"], nxt)
	if stuck:
		book["phase"] = "over"
		book["winner"] = int(book["p1"]) if previous == 1 else int(book["p2"])
		book["tie"] = false
		book["turn_until"] = 0
		return
	book["turn_until"] = now + _TURN


static func _random_move(book: Dictionary, now: int) -> void:
	var player := int(book.get("turn", 1))
	var kind := String(book.get("kind", ""))
	if kind == "findfour":
		var open: Array[int] = []
		var grid: Array = book.get("grid", [])
		for column in 7:
			if column < grid.size() and int(grid[column]) == 0:
				open.append(column)
		if open.is_empty():
			return
		_drop(book, player, open[randi() % open.size()], now)
		return
	if kind != "chinese":
		return
	var squares: Array = book.get("squares", [])
	var color := 1 if player == 1 else 4
	var walks: Array[Vector2i] = []
	for source in squares.size():
		if int(squares[source]) != color:
			continue
		for dest in squares.size():
			if _chinese_walk(squares, source, dest):
				walks.append(Vector2i(source, dest))
	if walks.is_empty():
		_finish_turn(book, now)
		return
	var pick: Vector2i = walks[randi() % walks.size()]
	_chinese(book, player, pick.x, pick.y, now)


static func _deal(book: Dictionary) -> void:
	var kind := String(book.get("kind", ""))
	if kind == "checkers":
		var squares: Array = []
		squares.resize(32)
		for index in 32:
			squares[index] = 0
		for index in 12:
			squares[index] = 1
		for index in range(20, 32):
			squares[index] = 2
		book["squares"] = squares
		book["grid"] = []
	elif kind == "chinese":
		var squares: Array = []
		squares.resize(121)
		for index in 121:
			squares[index] = 0
		if _homes.size() >= 4:
			for index in _homes[0]:
				squares[int(index)] = 1
			for index in _homes[3]:
				squares[int(index)] = 4
		book["squares"] = squares
		book["grid"] = []
	elif kind == "findfour":
		var grid: Array = []
		grid.resize(42)
		for index in 42:
			grid[index] = 0
		book["grid"] = grid
		book["squares"] = []


static func _assign(book: Dictionary) -> void:
	var found: Array[int] = []
	for seat in book["seats"]:
		var who := int(seat)
		if who != 0:
			found.append(who)
	book["p1"] = found[0] if found.size() >= 1 else 0
	book["p2"] = found[1] if found.size() >= 2 else 0


static func _occupied(book: Dictionary) -> int:
	var count := 0
	for seat in book["seats"]:
		if int(seat) != 0:
			count += 1
	return count


static func _holding(seats: Array, peer: int) -> int:
	for index in seats.size():
		if int(seats[index]) == peer:
			return index
	return -1


static func _everyone_ready(book: Dictionary) -> bool:
	var ready: Array = book.get("ready", [])
	var seen := 0
	for seat in book["seats"]:
		var who := int(seat)
		if who == 0:
			continue
		if not ready.has(who):
			return false
		seen += 1
	return seen >= 2


static func _without(raw: Variant, peer: int) -> Array:
	var next: Array = []
	if raw is Array:
		for item in raw:
			if int(item) != peer:
				next.append(int(item))
	return next


static func _clear_move(book: Dictionary) -> void:
	book["move"] = {"s": -1, "d": -1, "c": -1}


static func _color(book: Dictionary, peer: int) -> int:
	if peer == int(book.get("p1", 0)):
		return 1
	if peer == int(book.get("p2", 0)):
		return 2
	return 0


static func _side(state: int) -> int:
	if state == 1 or state == 3:
		return 1
	if state == 2 or state == 4:
		return 2
	return 0


static func _link(grid: Array, source: int, dest: int) -> int:
	if source < 0 or source >= grid.size():
		return -1
	var row: Array = grid[source]
	for slot in row.size():
		if int(row[slot]) == dest:
			return slot
	return -1


static func _link_at(grid: Array, source: int, slot: int) -> int:
	if source < 0 or slot < 0 or source >= grid.size():
		return -1
	var row: Array = grid[source]
	if slot >= row.size():
		return -1
	return int(row[slot])


static func _legal_step(squares: Array, player: int, source: int, dest: int) -> bool:
	if int(squares[dest]) != 0:
		return false
	var state := int(squares[source])
	var dirs: Array = [0, 1, 2, 3] if state >= 3 else ([1, 2] if player == 1 else [0, 3])
	for slot in dirs:
		if _link_at(_checkers_adj, source, int(slot)) == dest:
			return true
	return false


static func _legal_jump(squares: Array, player: int, source: int, dest: int) -> bool:
	if int(squares[dest]) != 0:
		return false
	var state := int(squares[source])
	var dirs: Array = [0, 1, 2, 3] if state >= 3 else ([1, 2] if player == 1 else [0, 3])
	var foes: Array = [2, 4] if player == 1 else [1, 3]
	for slot in dirs:
		if _link_at(_checkers_jump, source, int(slot)) != dest:
			continue
		var captured := _link_at(_checkers_adj, source, int(slot))
		if captured >= 0 and int(squares[captured]) in foes:
			return true
	return false


static func _piece_jump(squares: Array, player: int, source: int) -> bool:
	for dest in squares.size():
		if _legal_jump(squares, player, source, dest):
			return true
	return false


static func _any_jump(squares: Array, player: int) -> bool:
	for index in squares.size():
		if _side(int(squares[index])) == player and _piece_jump(squares, player, index):
			return true
	return false


static func _has_play(squares: Array, player: int) -> bool:
	for index in squares.size():
		if _side(int(squares[index])) != player:
			continue
		if _piece_jump(squares, player, index):
			return true
		for dest in squares.size():
			if _legal_step(squares, player, index, dest):
				return true
	return false


static func _chinese_walk(squares: Array, source: int, dest: int) -> bool:
	return int(squares[dest]) == 0 and _link(_chinese_adj, source, dest) >= 0


static func _chinese_hop(squares: Array, source: int, dest: int) -> bool:
	if int(squares[dest]) != 0 or source < 0 or source >= _chinese_adj.size():
		return false
	var row: Array = _chinese_adj[source]
	for slot in row.size():
		var middle := int(row[slot])
		if middle < 0 or middle >= squares.size() or int(squares[middle]) == 0:
			continue
		if _link_at(_chinese_adj, middle, slot) == dest:
			return true
	return false


static func _chinese_more(squares: Array, source: int) -> bool:
	for dest in squares.size():
		if _chinese_hop(squares, source, dest):
			return true
	return false


static func _chinese_has(squares: Array, player: int) -> bool:
	var color := 1 if player == 1 else 4
	for index in squares.size():
		if int(squares[index]) != color:
			continue
		for dest in squares.size():
			if _chinese_walk(squares, index, dest) or _chinese_hop(squares, index, dest):
				return true
	return false


static func _chinese_home(squares: Array, player: int) -> bool:
	if _homes.size() < 4:
		return false
	var color := 1 if player == 1 else 4
	var goal: Array = _homes[3] if player == 1 else _homes[0]
	for index in goal:
		if int(index) < 0 or int(index) >= squares.size() or int(squares[int(index)]) != color:
			return false
	var mine := 0
	for state in squares:
		if int(state) == color:
			mine += 1
	return mine == goal.size()


static func _four(grid: Array, row: int, column: int) -> bool:
	var state := int(grid[row * 7 + column])
	var ways: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]
	for way in ways:
		var step_way := way as Vector2i
		var count := 1
		for sign_value in [-1, 1]:
			var sign := int(sign_value)
			var step := 1
			while step < 4:
				var next_row := row + step_way.y * sign * step
				var next_col := column + step_way.x * sign * step
				if next_row < 0 or next_row > 5 or next_col < 0 or next_col > 6:
					break
				if int(grid[next_row * 7 + next_col]) != state:
					break
				count += 1
				step += 1
		if count >= 4:
			return true
	return false
