extends Node3D
## The three Acorn Acres game tables. outdoor_zone_sz.dna places them, and the
## first toon to sit picks Chinese Checkers, Checkers, or Find Four.
## With other toons connected, Checkers and Find Four use the first two seats.
## Chinese Checkers uses every seated toon, up to six. A third toon greys out
## Checkers and Find Four. Alone on one computer, one toon still plays both
## colors of the two-player game. There is no computer opponent.

const _TABLES := preload("res://assets/neighborhoods/acorn_acres/picnic_tables.glb")
const _CHECKERS := preload("res://assets/neighborhoods/acorn_acres/regular_checker_game.glb")
const _CHINESE := preload("res://assets/neighborhoods/acorn_acres/checker_game.glb")
const _FOUR := preload("res://assets/neighborhoods/acorn_acres/findfour_game.glb")
const _WHITE := preload("res://assets/neighborhoods/acorn_acres/checker_piece_white.glb")
const _BLACK := preload("res://assets/neighborhoods/acorn_acres/checker_piece_black.glb")
const _MARBLE := preload("res://assets/neighborhoods/acorn_acres/checker_marble.glb")
const _RULES := "res://assets/neighborhoods/acorn_acres/picnic_rules.json"
const _MOVE := "res://assets/audio/sfx/CC_move.ogg"
const _KNOCK := "res://assets/audio/sfx/GUI_knock_1.ogg"
const _POP := "res://assets/audio/sfx/GUI_balloon_popup.ogg"
const _REACH := 2.0
const _TURN := 40.0
const _SLEEP := 120.0
const _LAFF := 20
const _GREEN := Color(0.0, 0.9, 0.0, 1.0)
const _YELLOW := Color(0.9, 0.9, 0.0, 1.0)
const _PURPLE := Color(0.45, 0.0, 0.45, 1.0)
const _BLUE := Color(0.2, 0.4, 0.8, 1.0)
const _PINK := Color(1.0, 0.45, 1.0, 1.0)
const _RED := Color(0.8, 0.0, 0.0, 1.0)
const _CREAM := Color(1.0, 1.0, 0.75, 1.0)
const _INK := Color(1.0, 1.0, 0.65, 1.0)
const _DIALOG := preload("res://assets/gui/tutorial/dialog/dialog_box.png")
const _UP := preload("res://assets/gui/rules/InventoryButtonUp.png")
const _DN := preload("res://assets/gui/rules/InventoryButtonDown.png")
const _OVER := preload("res://assets/gui/rules/InventoryButtonRollover.png")
const _ARROW_UP := preload("res://assets/gui/friends/Horiz_Arrow_UP.png")
const _ARROW_DN := preload("res://assets/gui/friends/Horiz_Arrow_DN.png")
const _ARROW_HI := preload("res://assets/gui/friends/Horiz_Arrow_Rllvr.png")
const _OK_UP := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_UP.png")
const _OK_DN := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_DN.png")
const _OK_HI := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_Rllvr.png")
const _CLOCK_ART := preload("res://assets/gui/purchase/alarm_clock.png")
const _MINNIE := preload("res://assets/gui/picnic/MinnieFont.ttf")
const _CN_UP := preload("res://assets/gui/picnic/picnic_game_menu_Btn1_checkersBtnUp_6.png")
const _CN_DN := preload("res://assets/gui/picnic/picnic_game_menu_Btn1_checkersBtnDn_8.png")
const _CN_HI := preload("res://assets/gui/picnic/picnic_game_menu_Btn1_checkersBtnHi_7.png")
const _CK_UP := preload("res://assets/gui/picnic/picnic_game_menu_Btn2_regular_checkersBtnUp_3.png")
const _CK_DN := preload("res://assets/gui/picnic/picnic_game_menu_Btn2_regular_checkersBtnDn_5.png")
const _CK_HI := preload("res://assets/gui/picnic/picnic_game_menu_Btn2_regular_checkersBtnHi_4.png")
const _FF_UP := preload("res://assets/gui/picnic/picnic_game_menu_Btn3_findfourBtnUp_0.png")
const _FF_DN := preload("res://assets/gui/picnic/picnic_game_menu_Btn3_findfourBtnDn_2.png")
const _FF_HI := preload("res://assets/gui/picnic/picnic_game_menu_Btn3_findfourBtnHi_1.png")
const _LESSON_1 := preload("res://assets/gui/picnic/checker_tutorial_tutorialPage1_part1_2.png")
const _LESSON_2 := preload("res://assets/gui/picnic/checker_tutorial_tutorialPage2_part1_3.png")
const _LESSON_3 := preload("res://assets/gui/picnic/checker_tutorial_tutorialPage3_part1_1.png")
const _LESSON_MARK := preload("res://assets/gui/picnic/checker_tutorial_tutorialPage1_highlight_0.png")
const _RULE_1 := preload("res://assets/gui/picnic/regularchecker_tutorial_tutorialPage1_part1_3.png")
const _RULE_2 := preload("res://assets/gui/picnic/regularchecker_tutorial_tutorialPage2_part1_4.png")
const _RULE_3 := preload("res://assets/gui/picnic/regularchecker_tutorial_tutorialPage3_part1_2.png")
const _RULE_4 := preload("res://assets/gui/picnic/regularchecker_tutorial_tutorialPage4_part1_1.png")
const _RULE_KING := preload("res://assets/gui/picnic/regularchecker_tutorial_tutorialPage3_king_0.png")
const _PILL := Vector2(0.1804 * 20.0 * 0.15, 0.1137 * 11.0 * 0.15)
const _ART := 1.9685 * 0.36
const _CN_PAGE := "The goal of Chinese Checkers is to be the first  player to move all of your marbles from the bottom triangle across the board and into the triangle at the top. The first player to do so wins!"
const _CN_PLAY := "Players take turns moving any marble of their own color.  A marble can move into an adjacent hole or it can hop over other marbles. Hops must go over a marble and end in an empty hole. It is possible to chain hops together for longer moves!"
const _CK_PAGE1 := "The goal of Checkers is to leave the opponent without any possible moves. To do this you can either capture all of his peices or block them in such that he has no available moves."
const _CK_PAGE2 := "Players take turns moving any peice of their own color. A peice can move one square diagonal and forward. A peice can only move into a square that is not occupied by another peice. Kings follow the same rules but are allowed to move backwards."
const _CK_PAGE3 := "To capture an opponents peice your peice must jump over it diagonally into the vacant square beyond it. If you have any jump moves during a turn, you must do one of them. You can chain jump moves together as long as it is with the same peice.\n\nA peice becomes a king when it reaches the last row on the board. A peice that has just become a king cannot continue jumping until the next turn. Additionally, kings are allowed to move all directions and are allowed to change directions while jumping."

var _seated := false
var _table: Node3D
var _seat: Node3D
var _seat_pos := Vector3.ZERO
var _heading := 0.0
var _mode := ""
var _kind := ""
var _board: Node3D
var _spots: Array[Node3D] = []
var _starts: Array[Node3D] = []
var _pieces: Array[Node3D] = []
var _squares: Array = []
var _grid: Array = []
var _four_red: Array[Node3D] = []
var _four_yellow: Array[Node3D] = []
var _player := 1
var _selected := -1
var _chain := -1
var _clock := 0.0
var _awake := 0.0
var _over := ""
var _checkers_adj: Array = []
var _checkers_jump: Array = []
var _chinese_adj: Array = []
var _homes: Array = []
var _layer: CanvasLayer
var _screen: Control
var _status: Label
var _banner: TextureRect
var _title: Label
var _study_card: TextureRect
var _study_title: Label
var _study_body: Label
var _clock_art: TextureRect
var _clock_face: Label
var _cn_art: TextureButton
var _ck_art: TextureButton
var _ff_art: TextureButton
var _cn_name: Label
var _ck_name: Label
var _ff_name: Label
var _join_btn: TextureButton
var _howto: TextureButton
var _cancel: TextureButton
var _getup: TextureButton
var _start: TextureButton
var _quit_btn: TextureButton
var _prev: TextureButton
var _next: TextureButton
var _done: TextureButton
var _prev_words: Label
var _next_words: Label
var _done_words: Label
var _cn_pages: Array[TextureRect] = []
var _ck_pages: Array[TextureRect] = []
var _cn_mark: TextureRect
var _ck_king: TextureRect
var _study := ""
var _page := 0
var _held := false
var _cancelled := false
var _pulse := 0.0
var _seat_index := 0
var _line: Array[int] = []
var _aimed := false
var _board_basis := Basis()
var _tag_marbles: Array[Node3D] = []
var _sit_from := Vector3.ZERO
var _sit_time := -1.0
var _dance := -1.0
var _cam_from := Vector3.ZERO
var _cam_basis := Basis.IDENTITY
var _cam_armed := false
var _cam_time := 0.0
var _busy := false
var _flyer: Node3D
var _fly_a := Vector3.ZERO
var _fly_b := Vector3.ZERO
var _fly_time := 0.0
var _fly_length := 0.5
var _after_fly := Callable()
var _blink_node: Node3D
var _blink_base := Color.WHITE
var _index := -1
var _observing := false
var _leaving := false
var _leave_from := Vector3.ZERO
var _leave_to := Vector3.ZERO
var _leave_time := 0.0
var _seen := -1
var _healed := -1
var _start_until := 0
var _turn_until := 0
var _pending: Dictionary = {}
var _observe: TextureButton
var _stop_btn: TextureButton
var _move_sfx: AudioStreamPlayer
var _knock_sfx: AudioStreamPlayer
var _pop_sfx: AudioStreamPlayer


static func place(host: Node) -> void:
	if host == null or not host.scene_file_path.ends_with("acorn_acres.tscn"):
		return
	if host.get_node_or_null("PicnicTables") != null:
		return
	var tables: Node3D = (load("res://scenes/playgrounds/picnic_tables.gd") as GDScript).new()
	tables.name = "PicnicTables"
	host.add_child(tables)


func _ready() -> void:
	var model := _TABLES.instantiate()
	add_child(model)
	_load_rules()
	_move_sfx = _sfx(_MOVE)
	_knock_sfx = _sfx(_KNOCK)
	_pop_sfx = _sfx(_POP)
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	var net := ToonNet.live()
	if net != null and not net.state_changed.is_connected(_on_state):
		net.state_changed.connect(_on_state)


func holds_camera() -> bool:
	return _seated or _observing


func aim(camera: Camera3D) -> void:
	# moveCamera parks 17 above the table and looks straight down. Seats 4-6
	# face the other way, so the board turns 180.
	if _table == null:
		return
	var up := _table.global_transform.basis.z
	if up.length_squared() < 0.0001:
		up = Vector3.UP
	up = up.normalized()
	var focus := _table.global_position + up * 2.83
	var goal := _table.global_position + up * 17.0
	var screen := _table.global_transform.basis.y
	screen.y = 0.0
	if screen.length_squared() < 0.0001:
		screen = Vector3.FORWARD
	screen = screen.normalized()
	if _seat_index >= 3:
		screen = -screen
	var goal_basis := _look_down(goal, focus, screen)
	if not _cam_armed:
		_cam_from = camera.global_position
		_cam_basis = camera.global_basis
		_cam_armed = true
	_cam_time = minf(_cam_time + get_process_delta_time(), 2.0)
	var blend := _cam_time / 2.0
	blend = blend * blend * (3.0 - 2.0 * blend)
	camera.global_position = _cam_from.lerp(goal, blend)
	camera.global_basis = _cam_basis.slerp(goal_basis, blend)


func _look_down(eye: Vector3, focus: Vector3, screen_up: Vector3) -> Basis:
	var forward := focus - eye
	if forward.length_squared() < 0.0001:
		forward = Vector3.DOWN
	forward = forward.normalized()
	var up_axis := screen_up.normalized()
	var z_axis := -forward
	var x_axis := up_axis.cross(z_axis)
	if x_axis.length_squared() < 0.0001:
		x_axis = Vector3.RIGHT
	x_axis = x_axis.normalized()
	return Basis(x_axis, z_axis.cross(x_axis).normalized(), z_axis)


func _process(delta: float) -> void:
	if _leaving:
		_leave_time += delta
		var toon := _toon()
		var weight := clampf(_leave_time / 0.9, 0.0, 1.0)
		var pos := _leave_from.lerp(_leave_to, weight)
		pos += Vector3.UP * sin(weight * PI) * 1.5
		if toon != null:
			toon.call("visit_friend", pos, _heading)
			var actor: Node = toon.call("battle_actor")
			if actor != null and actor.has_method("pose_action"):
				actor.call("pose_action", "jump", _leave_time)
		if weight >= 1.0:
			_leaving = false
			if toon != null:
				toon.call("table_lock", false)
			_set_mode("")
		return
	if _busy:
		_fly_time += delta
		var hop := clampf(_fly_time / maxf(_fly_length, 0.01), 0.0, 1.0)
		if _flyer != null:
			var spot := _fly_a.lerp(_fly_b, hop)
			if _kind != "findfour":
				spot += Vector3.UP * sin(hop * PI) * 0.45
			_flyer.global_position = spot
		if hop >= 1.0:
			_busy = false
			if _flyer != null:
				_flyer.queue_free()
				_flyer = null
			var done := _after_fly
			_after_fly = Callable()
			if done.is_valid():
				done.call()
	if _seated:
		var toon := _toon()
		var actor: Node = null
		if toon != null:
			actor = toon.call("battle_actor")
		if _sit_time >= 0.0:
			_sit_time += delta
			var pose := "jump"
			var elapsed := _sit_time
			var pos := _seat_pos
			if _sit_time < 1.0:
				var weight := _sit_time
				pos = _sit_from.lerp(_seat_pos, weight)
				pos += Vector3.UP * sin(weight * PI) * 2.5
			else:
				var start_len := 0.4
				if actor != null and actor.has_method("action_length"):
					start_len = float(actor.call("action_length", "sit-start"))
				if _sit_time < 1.0 + start_len:
					pose = "sit-start"
					elapsed = _sit_time - 1.0
				else:
					_sit_time = -1.0
					pose = "sit"
					elapsed = 0.0
					if ToonNet.online():
						_pull()
					else:
						_set_mode("menu")
			if toon != null:
				toon.call("visit_friend", pos, _heading)
			if actor != null and actor.has_method("pose_action"):
				if _sit_time < 0.0:
					actor.call("pose_action", "sit", actor.call("action_length", "sit"))
				else:
					actor.call("pose_action", pose, elapsed)
		else:
			if toon != null:
				toon.call("visit_friend", _seat_pos, _heading)
			if actor != null and actor.has_method("pose_action"):
				if _dance >= 0.0:
					_dance += delta
					var dance_len := float(actor.call("action_length", "happy-dance"))
					if _dance >= dance_len:
						_dance = -1.0
						actor.call("pose_action", "sit", actor.call("action_length", "sit"))
					else:
						actor.call("pose_action", "happy-dance", _dance)
				else:
					actor.call("pose_action", "sit", actor.call("action_length", "sit"))
					_note_pose("sit")
		if _mode == "play" and not _busy:
			if ToonNet.online():
				_clock = maxf(float(_turn_until - int(Time.get_unix_time_from_system() * 1000.0)) / 1000.0, 0.0)
				_paint_turn()
			else:
				_clock = maxf(_clock - delta, 0.0)
				_paint_turn()
				if _clock <= 0.0:
					_expire()
		elif _mode == "ready" and ToonNet.online() and _start_until > 0:
			_clock = maxf(float(_start_until - int(Time.get_unix_time_from_system() * 1000.0)) / 1000.0, 0.0)
			_paint_clock()
		_blink_selected()
		_blink_line(delta)
		if ToonNet.online() and not _busy:
			_pull()
	elif _mode != "learn" and _mode != "study" and _mode != "watch":
		_offer_seat()
		if ToonNet.online() and _mode == "near":
			_refresh_near()
	elif _mode == "over":
		_blink_line(delta)
	_watch_sleep(delta)
	if _mode == "study":
		_pulse += delta
		var shown := 0.5 + 0.5 * sin(_pulse * TAU)
		if _study == "chinese" and _page == 0 and _cn_mark != null:
			_cn_mark.modulate = Color(0.5, 0.5, 0.0, shown)
		if _study == "checkers" and _page == 2 and _ck_king != null:
			_ck_king.modulate = Color(0.9, 0.9, 0.0, shown)


func _input(event: InputEvent) -> void:
	if not _asleep_watch():
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_awake = 0.0
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		_awake = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if _mode != "play" or _busy or not event is InputEventMouseButton:
		return
	var click := event as InputEventMouseButton
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var origin := camera.project_ray_origin(click.position)
	var direction := camera.project_ray_normal(click.position)
	if _kind == "findfour":
		var column := _pick_column(origin, direction)
		if column >= 0:
			_drop(column)
		return
	var reach := 0.45 if _kind == "checkers" else 0.28
	var index := _pick_spot(origin, direction, reach)
	if index >= 0:
		if _kind == "checkers":
			_click_checkers(index)
		else:
			_click_chinese(index)


func _offer_seat() -> void:
	var toon := _toon()
	if toon == null or bool(toon.call("battle_busy")):
		_set_mode("")
		return
	var feet: Vector3 = toon.call("battle_point")
	var best: Node3D
	var best_table: Node3D
	var best_d := _REACH
	for seat in find_children("seat*", "", true, false):
		if not seat is Node3D:
			continue
		var table := _owning_table(seat)
		if table == null:
			continue
		var gap := (seat as Node3D).global_position.distance_to(feet)
		if ToonNet.online() and _seat_taken(table, seat as Node3D) and not _table_playing(table):
			continue
		if gap < best_d:
			best_d = gap
			best = seat
			best_table = table
	if best == null:
		_cancelled = false
		if _mode == "near":
			_set_mode("")
		return
	if _cancelled:
		return
	_table = best_table
	_seat = best
	if _mode != "near":
		_set_mode("near")


func _join() -> void:
	if _seat == null or _table == null:
		return
	var toward := _table.global_position - _seat.global_position
	toward.y = 0.0
	_heading = rad_to_deg(atan2(-toward.x, -toward.z)) if toward.length_squared() > 0.0001 else 0.0
	var tail := str(_seat.name).trim_prefix("seat")
	_seat_index = int(tail) - 1 if tail.is_valid_int() else 0
	_index = _table_number(_table)
	_seat_pos = _seat.global_position
	if ToonNet.online():
		ToonNet.picnic_act(_index, "join", {"seat": _seat_index})
	_seated = true
	_cam_armed = false
	_cam_time = 0.0
	_dance = -1.0
	var toon := _toon()
	if toon == null:
		_sit_time = -1.0
		_set_mode("menu")
		return
	var feet: Vector3 = toon.call("battle_point")
	_sit_from = feet
	_sit_time = 0.0
	toon.call("table_lock", true)
	_set_mode("jump")


func _stand() -> void:
	if _observing:
		_observing = false
		_hold(false)
		_close_board()
		_kind = ""
		_set_mode("")
		return
	if not _seated:
		_held = false
		_set_mode("")
		return
	if ToonNet.online() and _index >= 0:
		ToonNet.picnic_act(_index, "leave", {})
	_held = false
	_busy = false
	_after_fly = Callable()
	_flyer = null
	_sit_time = -1.0
	_dance = -1.0
	_cam_armed = false
	_restore_blink()
	_close_board()
	_seated = false
	_kind = ""
	_over = ""
	_leaving = true
	_leave_time = 0.0
	_leave_from = _seat_pos
	var away := _seat_pos - (_table.global_position if _table != null else _seat_pos)
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.FORWARD
	_leave_to = _seat_pos + away.normalized() * 2.0
	_set_mode("leave")


func _choose(kind: String) -> void:
	if ToonNet.online() and _seated and _index >= 0:
		ToonNet.picnic_act(_index, "pick", {"kind": kind})
		return
	_kind = kind
	_close_board()
	_open_board()
	_set_mode("ready")


func _begin() -> void:
	if ToonNet.online() and _seated and _index >= 0:
		ToonNet.picnic_act(_index, "start", {})
		return
	_player = 1
	_selected = -1
	_chain = -1
	_over = ""
	_clock = _TURN
	if _kind == "checkers":
		_squares.clear()
		for _index in 32:
			_squares.append(0)
		for index in range(0, 12):
			_squares[index] = 1
		for index in range(20, 32):
			_squares[index] = 2
		_show_checkers()
	elif _kind == "chinese":
		_squares.clear()
		for _index in 121:
			_squares.append(0)
		for index in _homes[0]:
			_squares[int(index)] = 1
		for index in _homes[3]:
			_squares[int(index)] = 4
		_show_chinese()
		_aim_board(1)
	else:
		_grid.clear()
		for _row_index in 6:
			var line: Array = []
			for _col in 7:
				line.append(0)
			_grid.append(line)
		_show_four()
	_set_mode("play")
	_paint_turn()


func _quit() -> void:
	_close_board()
	_kind = ""
	_over = ""
	if _seated:
		_set_mode("menu")
	else:
		_set_mode("")


func _open_board() -> void:
	var anchor := _anchor(_table)
	if anchor == null:
		return
	var packed := _CHECKERS
	if _kind == "chinese":
		packed = _CHINESE
	elif _kind == "findfour":
		packed = _FOUR
	_board = packed.instantiate()
	anchor.add_child(_board)
	_spots = _numbered(_board, "locator", 42 if _kind == "findfour" else (121 if _kind == "chinese" else 32))
	if _kind == "checkers":
		_pieces.clear()
		for spot in _spots:
			var white := _WHITE.instantiate()
			var black := _BLACK.instantiate()
			spot.add_child(white)
			spot.add_child(black)
			white.visible = false
			black.visible = false
			_pieces.append(white)
			_pieces.append(black)
			_crown(white, false)
			_crown(black, false)
	elif _kind == "chinese":
		_pieces.clear()
		for spot in _spots:
			var marble := _MARBLE.instantiate()
			spot.add_child(marble)
			marble.visible = false
			_pieces.append(marble)
	else:
		_starts = _numbered(_board, "locatorStart", 7)
		var red := _board.find_child("piece_Red3D", true, false)
		var yellow := _board.find_child("piece_Yell3D", true, false)
		_four_red.clear()
		_four_yellow.clear()
		for spot in _spots:
			var red_piece := red.duplicate() as Node3D
			var yellow_piece := yellow.duplicate() as Node3D
			spot.add_child(red_piece)
			spot.add_child(yellow_piece)
			red_piece.visible = false
			yellow_piece.visible = false
			_four_red.append(red_piece)
			_four_yellow.append(yellow_piece)
		var templates := _board.find_child("pieces", true, false)
		if templates != null:
			templates.visible = false


func _close_board() -> void:
	_busy = false
	_after_fly = Callable()
	_flyer = null
	_restore_blink()
	if _board != null:
		_board.queue_free()
	_board = null
	_spots.clear()
	_starts.clear()
	_pieces.clear()
	_four_red.clear()
	_four_yellow.clear()
	_clear_tags()
	_line.clear()
	_aimed = false
	_selected = -1
	_chain = -1


func _click_checkers(index: int) -> void:
	if _busy:
		return
	if _shared() and _peer_color(ToonNet.peer_id()) != _player:
		_knock()
		return
	var state := int(_squares[index])
	if _chain >= 0:
		if _legal_jump(_chain, index):
			_land_checkers(_chain, index, true)
		else:
			_knock()
		return
	if _side(state) == _player:
		_selected = index
		_pop()
		return
	if _selected < 0:
		_knock()
		return
	var jumping := _any_jump()
	if not jumping and _legal_step(_selected, index):
		_land_checkers(_selected, index, false)
	elif _legal_jump(_selected, index):
		_land_checkers(_selected, index, true)
	else:
		_knock()


func _land_checkers(source: int, dest: int, jumped: bool) -> void:
	if _shared():
		ToonNet.picnic_act(_index, "move", {"s": source, "d": dest, "c": -1})
		return
	var flyer := _take_flyer(source)
	var state := int(_squares[source])
	if jumped:
		var slot := _link(_checkers_jump, source, dest)
		var captured := _link_at(_checkers_adj, source, slot)
		if captured >= 0:
			_squares[captured] = 0
	_squares[source] = 0
	var crowned := false
	if state <= 2 and _player == 1 and dest >= 28:
		state = 3
		crowned = true
	elif state <= 2 and _player == 2 and dest <= 3:
		state = 4
		crowned = true
	_squares[dest] = state
	_show_checkers()
	var settled := _piece_node(dest)
	var dest_pos := _spots[dest].global_position
	if settled != null:
		dest_pos = settled.global_position
		settled.visible = false
	if flyer != null and state >= 3:
		_crown(flyer, true)
	_move()
	_fly_to(flyer, dest_pos, 0.5, func() -> void:
		if settled != null and is_instance_valid(settled):
			settled.visible = true
		if _mode != "play":
			return
		if crowned or not jumped or not _piece_jump(dest):
			_end_turn()
		else:
			_selected = dest
			_chain = dest
			_ghost_landing(settled)
	)


func _click_chinese(index: int) -> void:
	if _busy:
		return
	if _shared() and _peer_color(ToonNet.peer_id()) != _player:
		_knock()
		return
	var state := int(_squares[index])
	if _chain >= 0:
		if index == _chain:
			if _shared():
				ToonNet.picnic_act(_index, "stop", {})
			else:
				_end_turn()
			return
		if _chinese_hop(_chain, index):
			_land_chinese(_chain, index, true)
		else:
			_knock()
		return
	if state == _chinese_color():
		_selected = index
		_pop()
		return
	if _selected < 0:
		_knock()
		return
	if _chinese_walk(_selected, index):
		_land_chinese(_selected, index, false)
	elif _chinese_hop(_selected, index):
		_land_chinese(_selected, index, true)
	else:
		_knock()


func _land_chinese(source: int, dest: int, hopped: bool) -> void:
	if _shared():
		ToonNet.picnic_act(_index, "move", {"s": source, "d": dest, "c": -1})
		return
	var flyer := _take_flyer(source)
	_squares[dest] = _squares[source]
	_squares[source] = 0
	_show_chinese()
	var settled := _piece_node(dest)
	var dest_pos := _spots[dest].global_position
	if settled != null:
		dest_pos = settled.global_position
		settled.visible = false
	_move()
	_fly_to(flyer, dest_pos, 0.5, func() -> void:
		if settled != null and is_instance_valid(settled):
			settled.visible = true
		if _mode != "play":
			return
		if _chinese_won():
			_capture_line()
			_finish(_color_name(_player), "Chinese Checkers")
		elif hopped and _chinese_more(dest):
			_selected = dest
			_chain = dest
			_ghost_landing(settled)
			_paint_turn()
		else:
			_end_turn()
	)


func _drop(column: int) -> void:
	if _busy:
		return
	if ToonNet.online() and _peer_color(ToonNet.peer_id()) != _player:
		_knock()
		return
	if int(_grid[0][column]) != 0:
		_knock()
		return
	if _shared():
		ToonNet.picnic_act(_index, "move", {"s": -1, "d": -1, "c": column})
		return
	var row := 0
	for next in 6:
		if int(_grid[next][column]) == 0:
			row = next
	_grid[row][column] = _player
	_show_four()
	var cell := row * 7 + column
	var settled: Node3D = _four_red[cell] if _player == 1 else _four_yellow[cell]
	if settled == null:
		_move()
		if _four_won(row, column):
			_capture_line()
			_finish("Red" if _player == 1 else "Yellow", "Find Four")
		else:
			_end_turn()
		return
	var dest_pos := settled.global_position
	var from := dest_pos + Vector3.UP * 1.6
	if column < _starts.size() and _starts[column] != null:
		from = _starts[column].global_position
	settled.visible = false
	var flyer := settled.duplicate() as Node3D
	if _board != null and flyer != null:
		var xform := settled.global_transform
		xform.origin = from
		_board.add_child(flyer)
		flyer.global_transform = xform
		flyer.visible = true
	_move()
	var won := _four_won(row, column)
	var open := false
	for next in 7:
		if int(_grid[0][next]) == 0:
			open = true
	_fly_to(flyer, dest_pos, 1.5, func() -> void:
		if is_instance_valid(settled):
			settled.visible = true
		if _mode != "play":
			return
		if won:
			_capture_line()
			_finish("Red" if _player == 1 else "Yellow", "Find Four")
		elif not open:
			_over = "This Find Four game has resulted in a Tie!"
			_capture_line()
			_set_mode("over")
			_status.text = _over
		else:
			_end_turn()
	)


func _expire() -> void:
	# Checkers lets the clock run out. Chinese Checkers and Find Four play a move.
	if _kind == "checkers":
		return
	if _kind == "findfour":
		var open: Array[int] = []
		for column in 7:
			if int(_grid[0][column]) == 0:
				open.append(column)
		if not open.is_empty():
			_drop(open[randi() % open.size()])
		return
	var walks: Array[Vector2i] = []
	var color := _chinese_color()
	for source in _squares.size():
		if int(_squares[source]) != color:
			continue
		for dest in _squares.size():
			if _chinese_walk(source, dest):
				walks.append(Vector2i(source, dest))
	if walks.is_empty():
		_end_turn()
		return
	var pick: Vector2i = walks[randi() % walks.size()]
	_land_chinese(pick.x, pick.y, false)


func _end_turn() -> void:
	if _mode != "play":
		return
	var previous := _player
	if _kind == "chinese":
		_player = _next_chinese(previous)
	else:
		_player = 2 if _player == 1 else 1
	_selected = -1
	_chain = -1
	_clock = _TURN
	if _kind == "checkers":
		_show_checkers()
	elif _kind == "chinese":
		_show_chinese()
	if _kind == "checkers" and not _has_play():
		_finish("White" if previous == 1 else "Black", "Checkers")
		return
	if _kind == "chinese" and not _chinese_has_play():
		_finish(_color_name(previous), "Chinese Checkers")
		return
	_paint_turn()


func _finish(color: String, game: String) -> void:
	_over = color + " just won a game of " + game + "!"
	if game == "Find Four":
		_over = color + " won a game of Find Four!"
	_set_mode("over")
	_status.text = _over
	_dance = 0.0
	_restore_blink()
	var toon := _toon()
	if toon != null:
		toon.call("heal", _LAFF)


func _paint_turn() -> void:
	if _status == null or _mode != "play":
		_paint_clock()
		return
	var who := _turn_sentence()
	_status.text = who
	_paint_clock()


func _turn_sentence() -> String:
	var who := "It's White's Turn"
	if _kind == "checkers" and _player == 2:
		who = "It's Black's Turn"
	elif _kind == "chinese":
		if ToonNet.online() and _peer_color(ToonNet.peer_id()) == _player:
			who = "It's Your Turn"
		else:
			who = "It's " + _color_name(_player) + "'s Turn"
	elif _kind == "findfour":
		who = "It's Red's Turn" if _player == 1 else "It's Yellow's Turn"
	if _chain >= 0 and _kind == "chinese":
		who += ". Hop again, or click the marble to stop"
	return who


func _paint_clock() -> void:
	if _clock_face == null or not _clock_art.visible:
		return
	var whole := ceili(maxf(_clock, 0.0))
	_clock_face.text = str(whole)
	var late := whole <= 5
	var view := get_viewport().get_visible_rect().size
	var px := maxi(int(round((0.34 if str(whole).length() <= 1 else 0.27) * 0.3 * view.y * 0.5)), 10)
	ToonGui.style_label(_clock_face, Color(1, 0, 0) if late else Color(0, 0, 0), px, Color(0, 0, 0, 0), 0)


func _show_checkers() -> void:
	for index in 32:
		var state := int(_squares[index])
		var white := _pieces[index * 2]
		var black := _pieces[index * 2 + 1]
		white.visible = state == 1 or state == 3
		black.visible = state == 2 or state == 4
		_crown(white, state == 3)
		_crown(black, state == 4)
		_solid(white)
		_solid(black)
	if _chain >= 0:
		_ghost_landing(_piece_node(_chain))


func _show_chinese() -> void:
	for index in _pieces.size():
		var state := int(_squares[index])
		var marble := _pieces[index]
		marble.visible = state != 0
		if state >= 1 and state <= 6:
			_tint(marble, _marble_color(state))
	if _chain >= 0:
		_ghost_landing(_piece_node(_chain))


func _show_four() -> void:
	for row in 6:
		for column in 7:
			var cell := row * 7 + column
			var state := int(_grid[row][column])
			if cell < _four_red.size():
				_four_red[cell].visible = state == 1
				_four_yellow[cell].visible = state == 2


func _legal_step(source: int, dest: int) -> bool:
	if int(_squares[dest]) != 0:
		return false
	var state := int(_squares[source])
	var dirs := [0, 1, 2, 3] if state >= 3 else ([1, 2] if _player == 1 else [0, 3])
	for slot in dirs:
		if _link_at(_checkers_adj, source, slot) == dest:
			return true
	return false


func _legal_jump(source: int, dest: int) -> bool:
	if int(_squares[dest]) != 0:
		return false
	var state := int(_squares[source])
	var dirs := [0, 1, 2, 3] if state >= 3 else ([1, 2] if _player == 1 else [0, 3])
	var foes := [2, 4] if _player == 1 else [1, 3]
	for slot in dirs:
		if _link_at(_checkers_jump, source, slot) != dest:
			continue
		var captured := _link_at(_checkers_adj, source, slot)
		if captured >= 0 and int(_squares[captured]) in foes:
			return true
	return false


func _piece_jump(source: int) -> bool:
	for dest in 32:
		if _legal_jump(source, dest):
			return true
	return false


func _any_jump() -> bool:
	for index in 32:
		if _side(int(_squares[index])) == _player and _piece_jump(index):
			return true
	return false


func _has_play() -> bool:
	for index in 32:
		if _side(int(_squares[index])) != _player:
			continue
		if _piece_jump(index):
			return true
		for dest in 32:
			if _legal_step(index, dest):
				return true
	return false


func _chinese_walk(source: int, dest: int) -> bool:
	if source < 0 or dest < 0 or source >= _squares.size() or dest >= _squares.size():
		return false
	return int(_squares[dest]) == 0 and _link(_chinese_adj, source, dest) >= 0 and _triangle_open(int(_squares[source]), dest)


func _chinese_hop(source: int, dest: int) -> bool:
	if source < 0 or dest < 0 or source >= _squares.size() or dest >= _squares.size():
		return false
	if int(_squares[dest]) != 0 or not _triangle_open(int(_squares[source]), dest):
		return false
	var row: Array = _chinese_adj[source]
	for slot in row.size():
		var middle := int(row[slot])
		if middle < 0 or int(_squares[middle]) == 0:
			continue
		if _link_at(_chinese_adj, middle, slot) == dest:
			return true
	return false


func _chinese_more(source: int) -> bool:
	for dest in _squares.size():
		if _chinese_hop(source, dest):
			return true
	return false


func _chinese_has_play() -> bool:
	var color := _chinese_color()
	for index in _squares.size():
		if int(_squares[index]) != color:
			continue
		for dest in _squares.size():
			if _chinese_walk(index, dest) or _chinese_hop(index, dest):
				return true
	return false


func _chinese_won() -> bool:
	var color := _chinese_color()
	if color < 1 or color > 6 or _homes.size() < 6:
		return false
	var goal: Array = _homes[(color - 1 + 3) % 6]
	var mine: Array = []
	for index in _squares.size():
		if int(_squares[index]) == color:
			mine.append(index)
	if mine.size() != goal.size():
		return false
	for index in goal:
		if int(_squares[int(index)]) != color:
			return false
	return true


func _four_won(row: int, column: int) -> bool:
	var state := int(_grid[row][column])
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
				if int(_grid[next_row][next_col]) != state:
					break
				count += 1
				step += 1
		if count >= 4:
			return true
	return false


func _side(state: int) -> int:
	if state == 1 or state == 3:
		return 1
	if state == 2 or state == 4:
		return 2
	return 0


func _chinese_color() -> int:
	return _player


func _link(grid: Array, source: int, dest: int) -> int:
	var row: Array = grid[source]
	for slot in row.size():
		if int(row[slot]) == dest:
			return slot
	return -1


func _link_at(grid: Array, source: int, slot: int) -> int:
	if slot < 0:
		return -1
	var row: Array = grid[source]
	if slot >= row.size():
		return -1
	return int(row[slot])


func _pick_spot(origin: Vector3, direction: Vector3, radius: float) -> int:
	var best := -1
	var best_d := radius
	for index in _spots.size():
		var spot := _spots[index]
		if spot == null:
			continue
		var along := direction.dot(spot.global_position - origin)
		if along < 0.0:
			continue
		var gap := spot.global_position.distance_to(origin + direction * along)
		if gap < best_d:
			best_d = gap
			best = index
	return best


func _pick_column(origin: Vector3, direction: Vector3) -> int:
	var column := _pick_named(_starts, origin, direction, 0.7)
	if column >= 0:
		return column
	var cell := _pick_spot(origin, direction, 0.45)
	if cell < 0:
		return -1
	return cell % 7


func _pick_named(nodes: Array[Node3D], origin: Vector3, direction: Vector3, radius: float) -> int:
	var best := -1
	var best_d := radius
	for index in nodes.size():
		var spot := nodes[index]
		if spot == null:
			continue
		var along := direction.dot(spot.global_position - origin)
		if along < 0.0:
			continue
		var gap := spot.global_position.distance_to(origin + direction * along)
		if gap < best_d:
			best_d = gap
			best = index
	return best


func _numbered(root: Node, prefix: String, count: int) -> Array[Node3D]:
	var spots: Array[Node3D] = []
	spots.resize(count)
	for node in root.find_children(prefix + "*", "", true, false):
		if not node is Node3D:
			continue
		var label := str(node.name)
		if not label.begins_with(prefix):
			continue
		var tail := label.trim_prefix(prefix)
		if not tail.is_valid_int():
			continue
		var number := int(tail)
		if number >= 1 and number <= count and spots[number - 1] == null:
			spots[number - 1] = node
	return spots


func _crown(root: Node, crowned: bool) -> void:
	if str(root.name).begins_with("checker_k"):
		root.visible = crowned
	for child in root.get_children():
		_crown(child, crowned)


func _piece_node(index: int) -> Node3D:
	if index < 0:
		return null
	if _kind == "checkers":
		if index >= 32 or index * 2 + 1 >= _pieces.size():
			return null
		var state := int(_squares[index])
		if state == 1 or state == 3:
			return _pieces[index * 2]
		if state == 2 or state == 4:
			return _pieces[index * 2 + 1]
		return null
	if _kind == "chinese" and index < _pieces.size():
		return _pieces[index]
	return null


func _take_flyer(index: int) -> Node3D:
	var piece := _piece_node(index)
	if piece == null or _board == null:
		return null
	var flyer := piece.duplicate() as Node3D
	var xform := piece.global_transform
	_board.add_child(flyer)
	flyer.global_transform = xform
	flyer.visible = true
	if _kind == "chinese":
		_tint(flyer, _GREEN if _player == 1 else _BLUE)
	return flyer


func _fly_to(flyer: Node3D, dest: Vector3, seconds: float, done: Callable) -> void:
	_restore_blink()
	_selected = -1
	if flyer == null:
		if done.is_valid() and _mode == "play":
			done.call()
		return
	_flyer = flyer
	_fly_a = flyer.global_position
	_fly_b = dest
	_fly_time = 0.0
	_fly_length = seconds
	_after_fly = done
	_busy = true


func _blink_selected() -> void:
	if _chain >= 0 and _selected == _chain:
		return
	_pulse += get_process_delta_time()
	var node := _piece_node(_selected)
	if node != _blink_node:
		_restore_blink()
		_blink_node = node
		_blink_base = _marble_color(_player) if _kind == "chinese" else Color.WHITE
	if node == null or not node.visible:
		return
	var weight := 0.5 + 0.5 * sin(_pulse * TAU / 1.4)
	_set_albedo(node, _blink_base.lerp(Color(0.25, 0.25, 0.25), weight))


func _restore_blink() -> void:
	if _blink_node != null and is_instance_valid(_blink_node):
		_set_albedo(_blink_node, _blink_base)
	_blink_node = null


func _set_albedo(root: Node, color: Color) -> void:
	if root is GeometryInstance3D:
		var mesh := root as GeometryInstance3D
		var mat := mesh.material_override as StandardMaterial3D
		if mat == null:
			_tint(mesh, color)
		else:
			mat.albedo_color = color
	for child in root.get_children():
		_set_albedo(child, color)


func _solid(root: Node) -> void:
	if root == null:
		return
	if root is GeometryInstance3D:
		(root as GeometryInstance3D).material_override = null
	for child in root.get_children():
		_solid(child)


func _ghost_landing(node: Node) -> void:
	if node == null or _chain < 0:
		return
	var color := Color(0.5, 0.5, 0.5, 0.5)
	if _kind == "chinese" and _chain < _squares.size():
		var base := _marble_color(int(_squares[_chain]))
		color = Color(maxf(base.r - 0.25, 0.0), maxf(base.g - 0.25, 0.0), maxf(base.b - 0.25, 0.0), 0.5)
	_paint_ghost(node, color)


func _paint_ghost(root: Node, color: Color) -> void:
	if root is GeometryInstance3D:
		var mesh := root as GeometryInstance3D
		var mat := mesh.material_override as StandardMaterial3D
		if mat == null:
			_tint(mesh, color)
			mat = mesh.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = color
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for child in root.get_children():
		_paint_ghost(child, color)


func _asleep_watch() -> bool:
	return _mode == "near" or _mode == "learn" or _mode == "study" or _mode == "menu" or _mode == "ready" or _mode == "play" or _mode == "over" or _mode == "jump"


func _watch_sleep(delta: float) -> void:
	if not _asleep_watch():
		_awake = 0.0
		return
	_awake += delta
	if _awake < _SLEEP:
		return
	_awake = 0.0
	var toon := _toon()
	if toon != null and toon.has_method("say_line"):
		toon.call("say_line", ". . . ZZZ . . .")
	if _mode == "study":
		_close_study()
	elif _mode == "near" or _mode == "learn":
		_cancel_choice()
	elif _seated:
		_stand()


func _tint(root: Node, color: Color) -> void:
	if root is GeometryInstance3D:
		var mesh := root as GeometryInstance3D
		var source: Material = mesh.get_active_material(0)
		var mat := StandardMaterial3D.new()
		if source is StandardMaterial3D:
			mat = (source as StandardMaterial3D).duplicate() as StandardMaterial3D
		mat.albedo_color = color
		mesh.material_override = mat
	for child in root.get_children():
		_tint(child, color)


func _load_rules() -> void:
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


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_screen)
	_banner = _card(_DIALOG)
	_banner.modulate = _CREAM
	_title = _words()
	_study_card = _card(_DIALOG)
	_study_card.modulate = _CREAM
	_study_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_study_title = _words()
	_study_body = _words()
	_study_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status = _words()
	_clock_art = _card(_CLOCK_ART)
	_clock_face = _words()
	_clock_art.add_child(_clock_face)
	_clock_face.visible = true
	_study_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_cn_art = _picture(_CN_UP, _CN_DN, _CN_HI, _pick_art.bind("chinese"))
	_ck_art = _picture(_CK_UP, _CK_DN, _CK_HI, _pick_art.bind("checkers"))
	_ff_art = _picture(_FF_UP, _FF_DN, _FF_HI, _pick_art.bind("findfour"))
	_cn_name = _words()
	_ck_name = _words()
	_ff_name = _words()
	_cn_name.text = "Chinese Checkers"
	_ck_name.text = "Checkers"
	_ff_name.text = "Find Four"
	_join_btn = _pill("Join", 0.8, _join_seat)
	_observe = _pill("Observe", 0.55, _watch)
	_stop_btn = _pill("Stop Observing", 0.45, _stand)
	_howto = _pill("How To Play", 0.55, _open_learn)
	_cancel = _pill("Cancel", 0.8, _cancel_choice)
	_getup = _pill("Get Up", 0.8, _stand)
	_start = _pill("Start Game", 0.6, _begin)
	_quit_btn = _pill("Quit Game", 0.5, _stand)
	_prev = _picture(_ARROW_UP, _ARROW_DN, _ARROW_HI, _turn_page.bind(-1))
	_next = _picture(_ARROW_UP, _ARROW_DN, _ARROW_HI, _turn_page.bind(1))
	_done = _picture(_OK_UP, _OK_DN, _OK_HI, _close_study)
	_prev_words = _caption("Previous Page")
	_next_words = _caption("Next Page")
	_done_words = _caption("Done")
	for art in [_LESSON_1, _LESSON_3, _LESSON_2]:
		_cn_pages.append(_card(art))
	_cn_mark = _card(_LESSON_MARK)
	for art in [_RULE_1, _RULE_2, _RULE_3, _RULE_4]:
		_ck_pages.append(_card(art))
	_ck_king = _card(_RULE_KING)
	_hide_lessons()


func _card(art: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = art
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	_screen.add_child(rect)
	return rect


func _words() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	_screen.add_child(label)
	return label


func _picture(up: Texture2D, down: Texture2D, hover: Texture2D, action: Callable) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = up
	button.texture_pressed = down
	button.texture_hover = hover
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.visible = false
	button.pressed.connect(action)
	ToonGui.button_sounds(button)
	_screen.add_child(button)
	return button


func _pill(text: String, scale: float, action: Callable) -> TextureButton:
	var button := _picture(_UP, _DN, _OVER, action)
	button.self_modulate = Color(1, 0, 0, 1)
	button.set_meta("ink_scale", scale)
	var caption := Label.new()
	caption.text = text
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(caption)
	return button


func _caption(text: String) -> Label:
	var caption := _words()
	caption.text = text
	return caption


func _anchor(table: Node) -> Node3D:
	for child in table.get_children():
		if child is Node3D and str(child.name).begins_with("board_anchor"):
			return child as Node3D
	return null


func _owning_table(seat: Node) -> Node3D:
	var node := seat.get_parent()
	while node != null:
		if str(node.name).begins_with("game_table"):
			return node as Node3D
		node = node.get_parent()
	return null


func _set_mode(mode: String) -> void:
	if _mode == mode:
		if mode == "near":
			_hide_chrome()
			if _watching_only():
				_show_nodes([_observe, _howto, _cancel])
			else:
				_show_nodes([_join_btn, _howto, _cancel])
		elif mode == "menu":
			_tint_games()
		return
	var fresh := not _asleep_watch()
	_mode = mode
	_hide_chrome()
	if mode == "near":
		if _watching_only():
			_show_nodes([_observe, _howto, _cancel])
		else:
			_show_nodes([_join_btn, _howto, _cancel])
	elif mode == "learn" or mode == "menu":
		_show_nodes([_banner, _title, _cn_art, _ck_art, _ff_art, _cn_name, _ck_name, _ff_name])
		_title.text = "What game do you want to learn?" if mode == "learn" else "What game do you want to play?"
		if mode == "learn":
			_cancel.visible = true
		if mode == "menu":
			_getup.visible = true
		_tint_games()
	elif mode == "study":
		_show_study()
	elif mode == "ready":
		_show_nodes([_start, _getup])
		if _start_until > 0:
			_clock_art.visible = true
			_paint_clock()
	elif mode == "watch":
		_show_nodes([_stop_btn, _status])
	elif mode == "play":
		_show_nodes([_quit_btn, _status, _clock_art])
		_paint_turn()
	elif mode == "over":
		_show_nodes([_quit_btn, _status])
		_status.text = _over
	if fresh and _asleep_watch():
		_awake = 0.0
	_layout()


func _hide_chrome() -> void:
	for child in _screen.get_children():
		child.visible = false
	_hide_lessons()


func _hide_lessons() -> void:
	for page in _cn_pages:
		page.visible = false
	for page in _ck_pages:
		page.visible = false
	if _cn_mark != null:
		_cn_mark.visible = false
	if _ck_king != null:
		_ck_king.visible = false


func _show_nodes(nodes: Array) -> void:
	for node in nodes:
		if node is CanvasItem:
			(node as CanvasItem).visible = true


func _show_study() -> void:
	_show_nodes([_study_card, _study_title, _study_body, _prev, _next, _done, _prev_words, _next_words, _done_words])
	var last := 1 if _study == "chinese" else 2
	_prev.visible = _page > 0
	_prev_words.visible = _page > 0
	_next.visible = _page < last
	_next_words.visible = _page < last
	_done.visible = _page == last
	_done_words.visible = _page == last
	_study_title.text = "Objective" if _page == 0 else "How to Play"
	if _study == "chinese":
		_study_body.text = _CN_PAGE if _page == 0 else _CN_PLAY
		_cn_pages[0].visible = _page == 0
		_cn_mark.visible = _page == 0
		_cn_pages[1].visible = _page == 1
		_cn_pages[2].visible = _page == 1
	else:
		_study_body.text = _CK_PAGE1 if _page == 0 else (_CK_PAGE2 if _page == 1 else _CK_PAGE3)
		_ck_pages[0].visible = _page == 0
		_ck_pages[1].visible = _page == 1
		_ck_pages[2].visible = _page == 2
		_ck_pages[3].visible = _page == 2
		_ck_king.visible = _page == 2
	_layout()


func _pick_art(kind: String) -> void:
	if _mode == "learn":
		if kind == "findfour":
			return
		_study = kind
		_page = 0
		_pulse = 0.0
		_set_mode("study")
		return
	if kind != "chinese" and _crowd() > 2:
		return
	_choose(kind)


func _open_learn() -> void:
	_hold(true)
	_set_mode("learn")


func _close_study() -> void:
	_hold(false)
	_set_mode("")


func _cancel_choice() -> void:
	var leaving_seat := _mode == "near"
	_hold(false)
	if leaving_seat:
		_cancelled = true
	_set_mode("")


func _join_seat() -> void:
	_join()


func _turn_page(step: int) -> void:
	var last := 1 if _study == "chinese" else 2
	_page = clampi(_page + step, 0, last)
	_show_study()


func _hold(holding: bool) -> void:
	if _held == holding:
		return
	_held = holding
	var toon := _toon()
	if toon != null and not _seated:
		toon.call("table_lock", holding)


func _layout() -> void:
	if _screen == null:
		return
	var view := _screen.get_viewport_rect().size
	if view.y < 1.0:
		return
	ToonGui.place(_banner, view, 0.0, 0.85, 1.1122 * 1.8, 1.1861 * 0.13)
	_fit(_title, view, 0.0, 0.81, 1.6, 0.12, 0.09, Color(1, 0, 0), true)
	ToonGui.place(_cn_art, view, 0.0, 0.15, _ART, _ART)
	ToonGui.place(_ck_art, view, 0.8, 0.15, _ART, _ART)
	ToonGui.place(_ff_art, view, -0.8, 0.15, _ART, _ART)
	_fit(_cn_name, view, 0.0, -0.8, 1.05, 0.45, 0.15, Color(1, 1, 1), false)
	_fit(_ck_name, view, 0.81, -0.8, 1.05, 0.45, 0.15, Color(1, 1, 1), false)
	_fit(_ff_name, view, -0.81, -0.8, 1.2, 0.45, 0.15, Color(1, 1, 1), false)
	_cn_name.rotation_degrees = 8.0
	_ff_name.rotation_degrees = 8.0
	_ck_name.rotation_degrees = -8.0
	_place_pill(_join_btn, view, 0.0, 0.8)
	_place_pill(_observe, view, 0.0, 0.6)
	_place_pill(_stop_btn, view, 0.92, 0.4)
	_place_pill(_howto, view, -1.0, 0.6)
	_place_pill(_cancel, view, 1.0, 0.6)
	_place_pill(_getup, view, 0.92, 0.4)
	_place_pill(_start, view, 0.92, 0.1)
	_place_pill(_quit_btn, view, 0.92, 0.4)
	ToonGui.place(_study_card, view, -0.7, 0.0, 1.1122, 1.1861 * 1.5)
	_fit(_study_title, view, -0.7, 0.4, 0.9, 0.16, 0.13, Color(1, 0, 0), true)
	var body_scale := 0.05 if _study == "checkers" and _page == 2 else 0.06
	var body_wrap := 19.0 if _study == "checkers" and _page == 2 else (12.5 if _page > 0 else 13.5)
	var body_z := 0.32 if _study == "checkers" and _page == 2 else (0.28 if _page > 0 else 0.23)
	_fit(_study_body, view, -0.7, body_z - 0.25, body_wrap * body_scale, 0.7, body_scale, Color(0, 0, 0), false)
	ToonGui.place(_cn_pages[0], view, 0.43, 0.0, 0.915, 0.915)
	ToonGui.place(_cn_mark, view, 0.43, 0.261, 0.243, 0.243)
	ToonGui.place(_cn_pages[1], view, 0.43, 0.5, 0.915, 0.915)
	ToonGui.place(_cn_pages[2], view, 0.43, -0.5, 0.915, 0.915)
	ToonGui.place(_ck_pages[0], view, 0.43, 0.0, 0.7985, 0.7985)
	ToonGui.place(_ck_pages[1], view, 0.43, 0.0, 0.7985, 0.7985)
	ToonGui.place(_ck_pages[2], view, 0.6, 0.5, 0.7985, 0.7985)
	ToonGui.place(_ck_pages[3], view, 0.6, -0.5, 0.7985, 0.7985)
	ToonGui.place(_ck_king, view, 0.732, 0.828, 0.097, 0.132)
	ToonGui.place(_prev, view, -1.05, -0.33, 0.0833, 0.0875)
	_prev.scale.x = -1.0
	ToonGui.place(_next, view, -0.35, -0.33, 0.0833, 0.0875)
	ToonGui.place(_done, view, -0.7, -0.33, 0.28, 0.28)
	_fit(_prev_words, view, -1.05, -0.43, 0.45, 0.08, 0.05, Color(0, 0, 0), false)
	_fit(_next_words, view, -0.35, -0.43, 0.45, 0.08, 0.05, Color(0, 0, 0), false)
	_fit(_done_words, view, -0.7, -0.48, 0.3, 0.08, 0.05, Color(0, 0, 0), false)
	ToonGui.place(_status, view, -0.8, -0.5, 1.2, 0.16)
	var turn_color := Color(0, 0, 0) if _mode == "over" else (Color(1, 1, 1) if _player == 1 else Color(0, 0, 0))
	_fit(_status, view, -0.8, -0.5, 1.2, 0.2, 0.092, turn_color, false)
	var clock_at := Vector2(-0.74, -0.2)
	if _mode == "ready":
		clock_at = Vector2(1.16, -0.83)
	elif _kind == "findfour":
		clock_at = Vector2(0.64, -0.27)
	ToonGui.place(_clock_art, view, clock_at.x, clock_at.y, 0.7417 * 0.3, 0.7292 * 0.3)
	_clock_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clock_face.offset_top = _clock_art.size.y * 0.08


func _place_pill(button: TextureButton, view: Vector2, x: float, z: float) -> void:
	ToonGui.place(button, view, x, z, _PILL.x, _PILL.y)
	var caption := button.get_child(0) as Label
	var scale := float(button.get_meta("ink_scale", 0.8))
	var px := maxi(int(round(scale * 0.15 * view.y * 0.5)), 8)
	ToonGui.style_label(caption, _INK, px, Color(0, 0, 0, 0), 0)


func _fit(label: Label, view: Vector2, x: float, z: float, width: float, height: float, scale: float, color: Color, sign: bool) -> void:
	ToonGui.place(label, view, x, z, width, height)
	var px := maxi(int(round(scale * view.y * 0.5)), 8)
	if sign:
		ToonGui.style_sign(label, color, px, Color(1, 1, 1), maxi(int(px * 0.08), 1))
	elif label == _cn_name or label == _ck_name or label == _ff_name:
		label.add_theme_font_override("font", _MINNIE)
		label.add_theme_font_size_override("font_size", px)
		label.add_theme_color_override("font_color", color)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("outline_size", maxi(int(px * 0.12), 1))
	else:
		ToonGui.style_label(label, color, px, Color(0, 0, 0, 0), 0)


func _toon() -> Node:
	var host := get_parent()
	if host == null:
		return null
	for child in host.get_children():
		if child.has_method("battle_point") and child.has_method("table_lock"):
			return child
	return null


func _on_state(channel: String) -> void:
	if channel.begins_with("picnic:"):
		_pull()


func _pull() -> void:
	if not ToonNet.online() or _sit_time >= 0.0 or _leaving:
		return
	if _mode == "learn" or _mode == "study":
		return
	var index := _index if (_seated or _observing) else _table_number(_table)
	if index < 0:
		return
	var state := ToonNet.latest(_channel(index))
	if not _seated and not _observing:
		return
	if state.is_empty():
		if _seated and _mode == "jump":
			_set_mode("menu")
		return
	_ingest(state)


func _ingest(state: Dictionary) -> void:
	if _busy:
		_pending = state.duplicate(true)
		return
	if _seated and not _listed(state) and not _observing:
		if String(state.get("kind", "")) == "" and _mode != "menu" and _mode != "jump" and _mode != "learn" and _mode != "study":
			_stand()
			return
		if _mode == "jump":
			_set_mode("menu")
		return
	var seq := int(state.get("seq", 0))
	var changed := seq != _seen
	var move: Dictionary = state.get("move", {})
	var kind := String(state.get("kind", ""))
	var glide := changed and int(move.get("s", -1)) >= 0 and _board != null and kind == _kind and kind != ""
	_seen = seq
	if glide:
		_glide(move, state)
		return
	_present(state)
	if changed or (_kind == "chinese" and _tag_marbles.is_empty()):
		_place_tags(state)
	_apply_phase(state, changed)


func _present(state: Dictionary) -> void:
	var kind := String(state.get("kind", ""))
	if kind == "":
		if _board != null:
			_close_board()
		_kind = ""
		return
	if _board == null or _kind != kind:
		_kind = kind
		if _table == null:
			_table = _table_by_number(_index)
		_close_board()
		_open_board()
	_copy_board(state)
	_show_current()


func _copy_board(state: Dictionary) -> void:
	var kind := String(state.get("kind", ""))
	if kind == "findfour":
		var flat: Array = state.get("grid", [])
		_grid.clear()
		for row in 6:
			var line: Array = []
			for column in 7:
				var cell := row * 7 + column
				line.append(int(flat[cell]) if cell < flat.size() else 0)
			_grid.append(line)
		return
	var squares: Array = state.get("squares", [])
	_squares = squares.duplicate()


func _show_current() -> void:
	if _pieces.is_empty() and _four_red.is_empty():
		return
	if _kind == "checkers":
		_show_checkers()
	elif _kind == "chinese":
		_show_chinese()
	elif _kind == "findfour":
		_show_four()


func _glide(move: Dictionary, state: Dictionary) -> void:
	var source := int(move.get("s", -1))
	var dest := int(move.get("d", -1))
	var column := int(move.get("c", -1))
	if column >= 0:
		_present(state)
		if source < 0 or source >= _four_red.size():
			_apply_phase(state, true)
			return
		var settled: Node3D = _four_red[source] if int(_grid[source / 7][source % 7]) == 1 else _four_yellow[source]
		if settled == null:
			_apply_phase(state, true)
			return
		var dest_pos := settled.global_position
		var from := dest_pos + Vector3.UP * 1.6
		if column < _starts.size() and _starts[column] != null:
			from = _starts[column].global_position
		settled.visible = false
		var flyer := settled.duplicate() as Node3D
		if _board != null and flyer != null:
			var xform := settled.global_transform
			xform.origin = from
			_board.add_child(flyer)
			flyer.global_transform = xform
			flyer.visible = true
		_fly_to(flyer, dest_pos, 1.5, func() -> void:
			if is_instance_valid(settled):
				settled.visible = true
			_apply_phase(state, true)
			_flush_pending()
		)
		return
	var flyer := _take_flyer(source)
	_present(state)
	var settled := _piece_node(dest)
	var dest_pos := dest_pos_of(dest, settled)
	if settled != null:
		settled.visible = false
	if flyer != null and dest < _squares.size() and int(_squares[dest]) >= 3:
		_crown(flyer, true)
	_fly_to(flyer, dest_pos, 0.5, func() -> void:
		if settled != null and is_instance_valid(settled):
			settled.visible = true
		_apply_phase(state, true)
		_flush_pending()
		if _chain == dest:
			_ghost_landing(settled)
	)


func dest_pos_of(dest: int, settled: Node3D) -> Vector3:
	if settled != null:
		return settled.global_position
	if dest >= 0 and dest < _spots.size() and _spots[dest] != null:
		return _spots[dest].global_position
	return Vector3.ZERO


func _apply_phase(state: Dictionary, changed: bool) -> void:
	var phase := String(state.get("phase", ""))
	var kind := String(state.get("kind", ""))
	_player = int(state.get("turn", 1))
	_start_until = int(state.get("until", 0))
	_turn_until = int(state.get("turn_until", 0))
	var server_chain := int(state.get("chain", -1))
	if changed or server_chain != _chain:
		_chain = server_chain
		_selected = _chain if _chain >= 0 and _peer_color(ToonNet.peer_id()) == _player else -1
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	if _observing and not _seated and phase != "over":
		_clock = maxf(float(_turn_until - now) / 1000.0, 0.0) if phase == "play" else 0.0
		if _mode != "watch":
			_set_mode("watch")
		if _status != null and phase == "play":
			_status.text = _turn_sentence()
		return
	if phase == "play":
		if _kind == "chinese" and not _aimed:
			var mine := _peer_color(ToonNet.peer_id()) if ToonNet.online() else _player
			_aim_board(mine if mine > 0 else 1)
		_clock = maxf(float(_turn_until - now) / 1000.0, 0.0)
		if _mode != "play":
			_set_mode("play")
		else:
			_paint_turn()
	elif phase == "ready" and kind != "":
		_clock = maxf(float(_start_until - now) / 1000.0, 0.0)
		if _observing and not _seated:
			if _mode != "watch":
				_set_mode("watch")
			return
		if _mode != "ready":
			_set_mode("ready")
		elif _start_until > 0 and _clock_art != null and not _clock_art.visible:
			_clock_art.visible = true
			_layout()
		_paint_clock()
	elif phase == "over":
		_over = _win_line(state)
		_capture_line()
		if _mode != "over":
			_set_mode("over")
		elif _status != null:
			_status.text = _over
		var seq := int(state.get("seq", 0))
		if int(state.get("winner", 0)) != 0 and _healed != seq:
			_healed = seq
			if _listed(state):
				var toon := _toon()
				if toon != null:
					toon.call("heal", _LAFF)
			if int(state.get("winner", 0)) == ToonNet.peer_id():
				_dance = 0.0
	elif _seated and kind == "":
		if _mode != "menu" and _mode != "learn" and _mode != "study":
			_set_mode("menu")
		elif _mode == "menu":
			_tint_games()


func _flush_pending() -> void:
	if _pending.is_empty():
		return
	var state := _pending
	_pending = {}
	_ingest(state)


func _win_line(state: Dictionary) -> String:
	var kind := String(state.get("kind", ""))
	if bool(state.get("tie", false)):
		return "This Find Four game has resulted in a Tie!"
	var winner := int(state.get("winner", 0))
	if winner == 0:
		return ""
	if winner == ToonNet.peer_id():
		if kind == "findfour":
			return "You won a game of Find Four!"
		if kind == "chinese":
			return "You just won a game of Chinese Checkers!"
		return "You just won a game of Checkers!"
	var called := String(ToonNet.latest("toon:%d" % winner).get("name", "")).strip_edges()
	if called == "":
		called = "A Toon"
	if kind == "findfour":
		return called + " has won a game of Find Four!"
	if kind == "chinese":
		return called + " has just won a game of Chinese Checkers."
	return called + " has just won a game of Checkers."


func _watch() -> void:
	if _table == null:
		return
	_index = _table_number(_table)
	_observing = true
	_seat_index = 0
	if _seat != null:
		var tail := str(_seat.name).trim_prefix("seat")
		if tail.is_valid_int():
			_seat_index = int(tail) - 1
	_cam_armed = false
	_cam_time = 0.0
	_hold(true)
	_seen = -1
	_set_mode("watch")
	_pull()


func _refresh_near() -> void:
	if _mode == "near":
		_set_mode("near")


func _watching_only() -> bool:
	if not ToonNet.online() or _table == null:
		return false
	var state := ToonNet.latest(_channel(_table_number(_table)))
	return String(state.get("phase", "")) == "play" and not _listed(state)


func _listed(state: Dictionary) -> bool:
	var seats: Array = state.get("seats", [])
	return seats.has(ToonNet.peer_id())


func _shared() -> bool:
	return ToonNet.online() and _seated and _index >= 0


func _marble_color(color: int) -> Color:
	match color:
		1:
			return _GREEN
		2:
			return _YELLOW
		3:
			return _PURPLE
		4:
			return _BLUE
		5:
			return _PINK
		6:
			return _RED
		_:
			return _GREEN


func _color_name(color: int) -> String:
	match color:
		1:
			return "Green"
		2:
			return "Yellow"
		3:
			return "Purple"
		4:
			return "Blue"
		5:
			return "Pink"
		6:
			return "Red"
		_:
			return "Green"


func _next_chinese(current: int) -> int:
	var active: Array[int] = [1, 4]
	if ToonNet.online() and _index >= 0:
		active.clear()
		var colors: Array = ToonNet.latest(_channel(_index)).get("colors", [])
		for index in colors.size():
			if int(colors[index]) != 0:
				active.append(index + 1)
		if active.is_empty():
			active.append(1)
			active.append(4)
	var at: int = active.find(current)
	if at < 0:
		return active[0]
	return active[(at + 1) % active.size()]


func _triangle_open(color: int, square: int) -> bool:
	if color < 1 or color > 6:
		return true
	var own := color - 1
	var goal := (color - 1 + 3) % 6
	for home in _homes.size():
		if home == own or home == goal:
			continue
		for index in _homes[home]:
			if int(index) == square:
				return false
	return true


func _crowd() -> int:
	if not ToonNet.online() or _index < 0:
		return 1
	var count := 0
	for seat in ToonNet.latest(_channel(_index)).get("seats", []):
		if int(seat) != 0:
			count += 1
	return count


func _tint_games() -> void:
	if _ck_art == null or _ff_art == null:
		return
	var crowded := _mode == "menu" and _crowd() > 2
	var dim := Color(0.7, 0.7, 0.7, 0.7) if crowded else Color(1, 1, 1, 1)
	_ck_art.self_modulate = dim
	_ff_art.self_modulate = dim
	_ck_art.disabled = crowded
	_ff_art.disabled = crowded
	if _ck_name != null:
		_ck_name.modulate = dim
	if _ff_name != null:
		_ff_name.modulate = dim


func _heading_for(color: int, seat_index: int) -> float:
	var far := seat_index > 2
	if far:
		match color:
			1:
				return 180.0
			2:
				return -120.0
			3:
				return -60.0
			4:
				return 0.0
			5:
				return 60.0
			6:
				return 120.0
	match color:
		2:
			return 60.0
		3:
			return 120.0
		4:
			return 180.0
		5:
			return -120.0
		6:
			return -60.0
	return 0.0


func _aim_board(color: int) -> void:
	if _board == null or _kind != "chinese" or color < 1:
		return
	if not _aimed:
		_board_basis = _board.transform.basis
	_board.transform.basis = _board_basis * Basis(Vector3.BACK, deg_to_rad(_heading_for(color, _seat_index)))
	_aimed = true


func _clear_tags() -> void:
	for marble in _tag_marbles:
		if is_instance_valid(marble):
			marble.queue_free()
	_tag_marbles.clear()


func _place_tags(state: Dictionary) -> void:
	_clear_tags()
	if _kind != "chinese" or _table == null:
		return
	var colors: Array = state.get("colors", [])
	var seats: Array = state.get("seats", [])
	if colors.is_empty():
		return
	for seat in _table.find_children("seat*", "", true, false):
		if not seat is Node3D:
			continue
		var tail := str(seat.name).trim_prefix("seat")
		if not tail.is_valid_int():
			continue
		var seat_index := int(tail) - 1
		if seat_index < 0 or seat_index >= seats.size() or int(seats[seat_index]) == 0:
			continue
		var color := 0
		for index in colors.size():
			if int(colors[index]) == int(seats[seat_index]):
				color = index + 1
		if color == 0:
			continue
		var marble := _MARBLE.instantiate()
		(seat as Node3D).add_child(marble)
		marble.position = Vector3(0.0, 3.3, 0.0)
		var scale := 1.5
		if seat_index == 1:
			scale = 1.3
		elif seat_index == 4:
			scale = 1.45
		marble.scale = Vector3.ONE * scale
		_tint(marble, _marble_color(color))
		_tag_marbles.append(marble)


func _capture_line() -> void:
	_line.clear()
	if _kind != "findfour" or _grid.size() < 6:
		return
	var filled := true
	for row in 6:
		for column in 7:
			if int(_grid[row][column]) == 0:
				filled = false
				continue
			var found := _line_from(row, column)
			if found.size() >= 4:
				_line = found
				return
	if filled:
		for cell in 42:
			_line.append(cell)


func _line_from(row: int, column: int) -> Array[int]:
	var state := int(_grid[row][column])
	var ways: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]
	for way in ways:
		var step_way := way as Vector2i
		var cells: Array[int] = [row * 7 + column]
		for sign_value in [-1, 1]:
			var sign := int(sign_value)
			var step := 1
			while step < 4:
				var next_row := row + step_way.y * sign * step
				var next_col := column + step_way.x * sign * step
				if next_row < 0 or next_row > 5 or next_col < 0 or next_col > 6:
					break
				if int(_grid[next_row][next_col]) != state:
					break
				cells.append(next_row * 7 + next_col)
				step += 1
		if cells.size() >= 4:
			return cells
	return []


func _blink_line(delta: float) -> void:
	if _mode != "over" or _kind != "findfour" or _line.is_empty():
		return
	_pulse += delta
	var weight := 0.5 + 0.5 * sin(_pulse * TAU / 0.6)
	var tint := Color(1, 1, 1, 1).lerp(Color(0.5, 0.5, 0.5, 1), weight)
	for cell in _line:
		if cell < 0 or cell >= _four_red.size():
			continue
		var piece := _four_red[cell] if _four_red[cell].visible else _four_yellow[cell]
		if piece != null and piece.visible:
			_set_albedo(piece, tint)


func _peer_color(peer: int) -> int:
	var state := ToonNet.latest(_channel(_index))
	if String(state.get("kind", "")) == "chinese":
		var colors: Array = state.get("colors", [])
		for index in colors.size():
			if int(colors[index]) == peer:
				return index + 1
		return 0
	if peer == int(state.get("p1", 0)):
		return 1
	if peer == int(state.get("p2", 0)):
		return 2
	return 0


func _channel(index: int) -> String:
	return "picnic:%d:%d" % [ToonNet.district_id(), index]


func _table_number(table: Node) -> int:
	if table == null:
		return -1
	var tail := str(table.name).trim_prefix("game_table_")
	if tail.is_valid_int():
		return int(tail) - 1
	return -1


func _table_by_number(index: int) -> Node3D:
	for node in find_children("game_table_*", "", true, false):
		if node is Node3D and _table_number(node) == index:
			return node as Node3D
	return null


func _table_playing(table: Node3D) -> bool:
	return String(ToonNet.latest(_channel(_table_number(table))).get("phase", "")) == "play"


func _seat_taken(table: Node3D, seat: Node3D) -> bool:
	var tail := str(seat.name).trim_prefix("seat")
	if not tail.is_valid_int():
		return false
	var seat_index := int(tail) - 1
	var seats: Array = ToonNet.latest(_channel(_table_number(table))).get("seats", [])
	return seat_index >= 0 and seat_index < seats.size() and int(seats[seat_index]) != 0


func _note_pose(anim: String) -> void:
	var toon := _toon()
	if toon == null:
		return
	var remotes := toon.get_node_or_null("RemoteToons")
	if remotes != null and remotes.has_method("note_anim"):
		remotes.call("note_anim", _heading, anim)


func _sfx(path: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	add_child(player)
	if ResourceLoader.exists(path):
		player.stream = load(path)
	return player


func _move() -> void:
	if _move_sfx != null and _move_sfx.stream != null:
		_move_sfx.play()


func _knock() -> void:
	if _knock_sfx != null and _knock_sfx.stream != null:
		_knock_sfx.play()


func _pop() -> void:
	if _pop_sfx != null and _pop_sfx.stream != null:
		_pop_sfx.play()
