extends "res://scenes/trolley/trolley_minigame.gd"

## Trolley Tracks. TravelGameId 100. The board, votes, and bonus beans follow
## TravelGameGlobals and DistributedTravelGame. The tunnel's game is queued
## for the next round. A solo ride starts that game. A party buys gags first.

const _TABLE := preload("res://assets/minigames/travel_turntable.glb")
const _CAR := preload("res://assets/minigames/travel_trolley.glb")
const _GROUND := preload("res://assets/minigames/travel_ground.glb")
const _ICONS := preload("res://assets/minigames/travel_icons.glb")
const _SKY := preload("res://scenes/sky/toontown_sky.gd")
const _DIALOG := preload("res://assets/gui/minigames/dialog_box.png")
const _SCROLL_UP := preload("res://assets/gui/friends/FndsLst_ScrollUp.png")
const _SCROLL_DOWN := preload("res://assets/gui/friends/FndsLst_ScrollDN.png")
const _SCROLL_HOVER := preload("res://assets/gui/friends/FndsLst_ScrollUp_Rllvr.png")
const _OK_UP := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_UP.png")
const _OK_DOWN := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_DN.png")
const _OK_HOVER := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_Rllvr.png")
const _X := 60.0
const _Y := 15.0
const _PIECE := 22.0
## dialog_box_gui tight bounds. The vote frames scale that card.
const _DIALOG_W := 1.1122
const _DIALOG_H := 1.1861
const _CREAM := Color(1.0, 1.0, 0.75, 1.0)
## FndsLst_ScrollUp at scale 1, and the OK card at image_scale 3.
const _SCROLL_SIZE := Vector2(0.2792, 0.0458)
const _OK_SIZE := 0.3375

var flat_score := true

var _which := 0
var _switch := 0
var _vote_round := 0
var _votes := 5
var _index := 0
var _zero := 5
var _phase := "intro"
var _phase_left := 3.0
var _sent := false
var _games: Dictionary = {}
var _goals: Dictionary = {}
var _tables: Array[Node3D] = []
var _signs: Node3D
var _car: Node3D
var _wheels: Array[Node3D] = []
var _keys: Array[Node3D] = []
var _wheel_rest: Array[float] = []
var _key_rest: Array[float] = []
var _from := 0
var _to := 0
var _from_pos := Vector3.ZERO
var _to_pos := Vector3.ZERO
var _yaw0 := 0.0
var _yaw1 := 0.0
var _move_time := 0.0
var _layer: CanvasLayer
var _remain_card: TextureRect
var _remain: Label
var _remain_num: Label
var _choice: Control
var _choice_card: TextureRect
var _use: Label
var _up_scroll: TextureButton
var _down_scroll: TextureButton
var _well: Panel
var _count: Label
var _tail: Label
var _way: Label
var _vote: TextureButton
var _vote_text: Label
var _waiting: Label
var _result: Label
var _bonus: Label
var _bonus_at := Vector3.ZERO


func _ready() -> void:
	title = "Trolley Tracks"
	instructions = "Click up or down to set your number of votes.  Click the vote button to cast it. Reach your secret goal to get bonus beans. Earn more votes by doing well in the other games."
	super._ready()


func begin() -> void:
	playing = true
	_phase = "intro"
	_phase_left = 3.0
	_sfx("SZ_trolley_away")


func _process(delta: float) -> void:
	if not playing or _over:
		return
	_play(delta)


func _build() -> void:
	var floor := get_node_or_null("StageFloor")
	if floor is Node3D:
		(floor as Node3D).visible = false
	if _hud != null:
		_hud.visible = false
	_SKY.ensure(self)
	add_child(_GROUND.instantiate())
	_which = shared_int(4)
	_deal()
	_lay_board()
	_plant_car()
	_aim_top()
	_build_ui()


func _deal() -> void:
	var layout := _layout(_which)
	var pool := _pool()
	var leaves: Array[int] = []
	for index in range(layout.size()):
		var info: Dictionary = layout[index]
		var links: Array = info["links"]
		if links.is_empty():
			leaves.append(index)
			if pool.is_empty():
				pool = _pool()
			var pick := shared_int(pool.size())
			_games[index] = pool[pick]
			pool.remove_at(pick)
	var open := leaves.duplicate()
	var party := _party()
	for peer in party:
		if open.is_empty():
			break
		var pick := shared_int(open.size())
		var leaf: int = int(open[pick])
		open.remove_at(pick)
		var info: Dictionary = layout[leaf]
		var beans := int(round(float(info["bonus"]) * 10.0 * float(party.size()) / 4.0))
		_goals[peer] = {"switch": leaf, "beans": beans}


func _lay_board() -> void:
	var layout := _layout(_which)
	_signs = Node3D.new()
	_signs.name = "Signs"
	add_child(_signs)
	for index in range(layout.size()):
		var info: Dictionary = layout[index]
		var pos: Vector2 = info["pos"]
		var table := _only(_TABLE.instantiate(), "turntable1")
		table.position = _panda(pos.x, pos.y, 0.0)
		add_child(table)
		_tables.append(table)
		var links: Array = info["links"]
		var lift := 0.0
		for other in links:
			var next: Vector2 = (layout[int(other)] as Dictionary)["pos"]
			_lay_track(pos.x, pos.y, next.x, next.y, lift)
			lift += 0.005
		if links.is_empty():
			var covered := _lay_track(pos.x, pos.y, pos.x + _X, pos.y, 0.0)
			var tunnel := _only(_TABLE.instantiate(), "tunnel1")
			tunnel.position = _panda(pos.x + covered, pos.y, 0.0)
			add_child(tunnel)
			_plant_sign(int(_games.get(index, 0)), pos, pos.x + covered)
	var root: Vector2 = layout[0]["pos"]
	_lay_track(root.x - _X, root.y, root.x, root.y, 0.0)


func _lay_track(x1: float, y1: float, x2: float, y2: float, lift: float) -> float:
	var host := Node3D.new()
	host.position = _panda(x1, y1, 0.03 + lift)
	host.rotation.y = atan2(y2 - y1, x2 - x1)
	add_child(host)
	var length := Vector2(x2 - x1, y2 - y1).length()
	var covered := 0.0
	var remain := length
	while remain > _PIECE * 0.5:
		var piece := _only(_TABLE.instantiate(), "track_a2")
		piece.position = Vector3(covered, 0.0, 0.0)
		host.add_child(piece)
		remain -= _PIECE
		covered += _PIECE
	return covered


func _plant_sign(game_id: int, pos: Vector2, tunnel_x: float) -> void:
	var icon_name := _icon_name(game_id)
	if icon_name == "":
		return
	# One card lies on the switch. Another lies on the track in front of the tunnel.
	_signs.add_child(_flat_icon(icon_name, pos.x, pos.y, 8.0))
	_signs.add_child(_flat_icon(icon_name, tunnel_x - 16.0, pos.y, 3.0))
	var upright := _only(_ICONS.instantiate(), icon_name)
	upright.position = _panda(tunnel_x, pos.y, 26.0)
	upright.rotation.y = deg_to_rad(-90.0)
	upright.scale = Vector3.ONE * 10.0
	add_child(upright)


func _flat_icon(icon_name: String, x: float, y: float, z: float) -> Node3D:
	var flat := _only(_ICONS.instantiate(), icon_name)
	flat.position = _panda(x, y, z)
	flat.rotation.x = PI * 0.5
	flat.scale = Vector3.ONE * 14.0
	return flat


func _plant_car() -> void:
	_car = _CAR.instantiate() as Node3D
	var root: Vector2 = _layout(_which)[0]["pos"]
	_car.position = _panda(root.x - _X, root.y, 0.0)
	_car.rotation.y = _car_yaw(0.0)
	add_child(_car)
	_collect(_car)
	var mine: Dictionary = _goals.get(ToonNet.peer_id(), {})
	var leaf := int(mine.get("switch", -1))
	if leaf >= 0:
		var pos: Vector2 = _layout(_which)[leaf]["pos"]
		_bonus_at = _panda(pos.x, pos.y, 10.0)


func _collect(node: Node) -> void:
	if node.name == "front_wheels" or node.name == "back_wheels":
		var wheel := node as Node3D
		_wheels.append(wheel)
		_wheel_rest.append(wheel.rotation.z)
	elif node.name == "key":
		var key := node as Node3D
		_keys.append(key)
		_key_rest.append(key.rotation.z)
	for child in node.get_children():
		_collect(child)


func _play(delta: float) -> void:
	_layout_ui()
	_pin_bonus()
	if _phase == "intro":
		_slide_in(delta)
	elif _phase == "choose":
		_choose(delta)
	elif _phase == "wait":
		_wait_result()
	elif _phase == "reveal":
		_tick_phase(delta, _begin_move)
	elif _phase == "move":
		_slide_switch(delta)
	elif _phase == "win":
		_drive_out(delta)
	_show_signs()


func _slide_in(delta: float) -> void:
	_phase_left -= delta
	var done := clampf(1.0 - _phase_left / 3.0, 0.0, 1.0)
	var root: Vector2 = _layout(_which)[0]["pos"]
	var start := _panda(root.x - _X, root.y, 0.0)
	var stop := _panda(root.x, root.y, 0.0)
	_car.position = start.lerp(stop, _ease(done))
	_car.rotation.y = _car_yaw(0.0)
	if _phase_left <= 0.0:
		_car.position = stop
		_sfx("SZ_trolley_bell")
		_open_vote()


func _open_vote() -> void:
	_phase = "choose"
	_phase_left = 15.0
	_sent = false
	_zero = _votes
	_index = _zero
	_aim_top()
	_paint_choice()


func _choose(delta: float) -> void:
	_phase_left -= delta
	if _phase_left <= 0.0:
		_cast(0, 0)
		ToonNet.note_minigame("trackend", _vote_round)


func _cast(votes: int, direction: int) -> void:
	if _sent:
		return
	_sent = true
	var spent := clampi(votes, 0, _votes)
	var way := 0 if direction <= 0 else 1
	_votes -= spent
	_phase = "wait"
	ToonNet.note_minigame("track", _vote_round * 16 + spent * 2 + way)


func _wait_result() -> void:
	var book := _track_book()
	if int(book.get("vote", -1)) != _vote_round:
		return
	_phase = "reveal"
	var party := _party()
	_phase_left = 2.0 * float(party.size() + 1)
	_result.text = _result_text(book)
	_result.visible = true
	_face_car()


func _begin_move() -> void:
	var book := _track_book()
	var direction := int(book.get("dir", 0))
	var info := _info(_switch)
	var links: Array = info["links"]
	if links.is_empty():
		_begin_win()
		return
	_from = _switch
	_to = int(links[clampi(direction, 0, links.size() - 1)])
	_from_pos = _car.position
	var dest: Vector2 = _info(_to)["pos"]
	_to_pos = _panda(dest.x, dest.y, 0.0)
	_yaw0 = _car.rotation.y
	_yaw1 = _car_yaw(_angle(_from, _to))
	_move_time = 0.0
	_phase = "move"
	_result.visible = false
	_sfx("MG_sfx_travel_game_turntble_rotate_2", 0.5)
	_sfx("SZ_trolley_bell")


func _slide_switch(delta: float) -> void:
	_move_time += delta
	var t := _move_time
	if t < 1.0:
		var u := _ease(t)
		_car.rotation.y = lerp_angle(_yaw0, _yaw1, u)
		_set_table(_from, u)
		_set_table(_to, u)
	elif t < 4.0:
		var u := _ease((t - 1.0) / 3.0)
		_car.position = _from_pos.lerp(_to_pos, u)
		_car.rotation.y = _yaw1
		_spin(u)
		if t - delta < 1.0:
			_sfx("SZ_trolley_away")
	else:
		var u := _ease(clampf((t - 4.0) / 1.0, 0.0, 1.0))
		_car.rotation.y = lerp_angle(_yaw1, _car_yaw(0.0), u)
		_set_table(_from, 1.0 - u)
		_set_table(_to, 1.0 - u)
		_aim_top()
	if t < 4.0:
		_camera.look_at(_car.global_position + Vector3(0.0, 7.5, 0.0), Vector3.UP)
	if t >= 5.0:
		_car.position = _to_pos
		_car.rotation.y = _car_yaw(0.0)
		_set_table(_from, 0.0)
		_set_table(_to, 0.0)
		_switch = _to
		_vote_round += 1
		_sfx("SZ_trolley_bell")
		if (_info(_switch)["links"] as Array).is_empty():
			_begin_win()
		else:
			_open_vote()


func _begin_win() -> void:
	_phase = "win"
	_phase_left = 8.0
	_result.visible = true
	_score_arrival()
	var leaf: Vector2 = _info(_switch)["pos"]
	_from_pos = _car.position
	_to_pos = _panda(leaf.x + _X + 20.0, leaf.y, 0.0)
	_sfx("SZ_trolley_bell")
	var next_id := int(_games.get(_switch, 0))
	if next_id > 0:
		_RIDE.follow_id = next_id
	_result.text = "Up next, the %s trolley game." % _game_name(next_id)
	_result.text += _bonus_line()


func _score_arrival() -> void:
	var mine: Dictionary = _goals.get(ToonNet.peer_id(), {})
	var mine_switch := int(mine.get("switch", -1))
	var mine_beans := int(mine.get("beans", 0))
	var someone := false
	for key in _goals.keys():
		var card: Dictionary = _goals[key]
		if int(card.get("switch", -1)) == _switch:
			someone = true
	if not someone:
		score = 1
		_sfx("MG_sfx_travel_game_no_bonus")
	elif mine_switch == _switch:
		score = mine_beans
		_sfx("MG_sfx_travel_game_bonus")
	else:
		score = 0
		_sfx("MG_sfx_travel_game_no_bonus_2")


func _bonus_line() -> String:
	var hit := ""
	for key in _goals.keys():
		var card: Dictionary = _goals[key]
		if int(card.get("switch", -1)) == _switch:
			hit = "%s got a bonus of %s jellybeans!" % [_name_of(int(key)), str(int(card.get("beans", 0)))]
	if hit == "":
		return "\n\nNo one reached their secret goal.  Everyone gets 1 jellybean."
	return "\n\n" + hit


func _drive_out(delta: float) -> void:
	_phase_left -= delta
	var u := _ease(clampf(1.0 - _phase_left / 8.0, 0.0, 1.0) / 0.375)
	_car.position = _from_pos.lerp(_to_pos, u)
	_car.rotation.y = _car_yaw(0.0)
	if _phase_left < 5.0 and _phase_left + delta >= 5.0:
		_sfx("SZ_trolley_away")
	if _phase_left <= 0.0:
		_end()


func _tick_phase(delta: float, done: Callable) -> void:
	_phase_left -= delta
	if _phase_left <= 0.0:
		done.call()


func _result_text(book: Dictionary) -> String:
	var peers: Array = book.get("peers", [])
	var counts: Array = book.get("counts", [])
	var dirs: Array = book.get("dirs", [])
	var totals := [0, 0]
	var text := ""
	for index in range(peers.size()):
		var votes := int(counts[index]) if index < counts.size() else 0
		var way := int(dirs[index]) if index < dirs.size() else 0
		totals[way] += votes
		text += "%s used %s votes to go %s\n" % [_name_of(int(peers[index])), str(votes), _dir_word(way)]
	text += "Totals  UP:%d DOWN:%d\n" % [totals[0], totals[1]]
	var go := int(book.get("dir", 0))
	var reason := int(book.get("reason", 0))
	if reason == 2:
		text += "The trolley is randomly moving %s." % _dir_word(go)
	else:
		var other := 1 - go
		var diff: int = int(totals[go]) - int(totals[other])
		if diff > 1:
			text += "The trolley is moving %s, winning by %d votes." % [_dir_word(go), diff]
		else:
			text += "The trolley is moving %s, winning by %d vote." % [_dir_word(go), diff]
	return text


func _track_book() -> Dictionary:
	var state := ToonNet.minigame_state()
	var book: Variant = state.get("tracks", {})
	if book is Dictionary:
		return book
	return {}


func _unhandled_input(event: InputEvent) -> void:
	if _phase != "choose" or _sent:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			_nudge(-1)
		elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_nudge(1)
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_UP or key.keycode == KEY_W:
		_nudge(-1)
	elif key.keycode == KEY_DOWN or key.keycode == KEY_S:
		_nudge(1)
	elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		_cast(_choice_votes(), _choice_dir())


func _nudge(step: int) -> void:
	var last := _votes * 2
	_index = clampi(_index + step, 0, last)
	_paint_choice()


func _paint_choice() -> void:
	var votes := _choice_votes()
	var signed := _index - _zero
	_count.text = str(signed)
	_remain.text = "Remaining Votes:"
	_remain_num.text = str(_votes - votes)
	var phrase := "vote to go" if votes == 1 else "votes to go"
	if signed < 0:
		_count.add_theme_color_override("font_color", Color(0, 0, 1))
		_way.text = "UP."
		_way.add_theme_color_override("font_color", Color(0, 0, 1))
		_tail.text = phrase
	elif signed == 0:
		_count.add_theme_color_override("font_color", Color(0, 0, 0))
		_way.text = ""
		_tail.text = "votes."
	else:
		_count.add_theme_color_override("font_color", Color(1, 0, 0))
		_way.text = "DOWN."
		_way.add_theme_color_override("font_color", Color(1, 0, 0))
		_tail.text = phrase
	_dim_scroll(_up_scroll, _index <= 0)
	_dim_scroll(_down_scroll, _index >= _votes * 2)


func _choice_votes() -> int:
	return absi(_index - _zero)


func _choice_dir() -> int:
	return 1 if _index > _zero else 0


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 30
	add_child(_layer)
	_remain_card = _dialog_card()
	_layer.add_child(_remain_card)
	_remain = _line("Remaining Votes:", Color(0, 0, 0), HORIZONTAL_ALIGNMENT_LEFT)
	_layer.add_child(_remain)
	_remain_num = _line("5", Color(0, 0.5, 0), HORIZONTAL_ALIGNMENT_RIGHT)
	_layer.add_child(_remain_num)
	_choice = Control.new()
	_choice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_choice)
	_choice_card = _dialog_card()
	_choice.add_child(_choice_card)
	_use = _line("Use", Color(0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER)
	_choice.add_child(_use)
	_well = _ridge()
	_choice.add_child(_well)
	_count = _line("0", Color(0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER)
	_choice.add_child(_count)
	_up_scroll = _scroll_button(false)
	_up_scroll.pressed.connect(_nudge.bind(-1))
	_choice.add_child(_up_scroll)
	_down_scroll = _scroll_button(true)
	_down_scroll.pressed.connect(_nudge.bind(1))
	_choice.add_child(_down_scroll)
	_tail = _line("votes.", Color(0, 0, 0), HORIZONTAL_ALIGNMENT_LEFT)
	_choice.add_child(_tail)
	_way = _line("", Color(0, 0, 1), HORIZONTAL_ALIGNMENT_LEFT)
	_choice.add_child(_way)
	_vote = _ok_button()
	_vote.pressed.connect(func() -> void: _cast(_choice_votes(), _choice_dir()))
	_choice.add_child(_vote)
	_vote_text = _line("Vote!", Color(0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER)
	_choice.add_child(_vote_text)
	_waiting = _line("Waiting for other players to vote...", Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
	_layer.add_child(_waiting)
	_result = Label.new()
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.visible = false
	_style(_result, Color(1, 1, 1), 28)
	_layer.add_child(_result)
	_bonus = Label.new()
	_style(_bonus, Color(1, 1, 1), 24)
	_layer.add_child(_bonus)
	_paint_choice()
	_layout_ui()


func _layout_ui() -> void:
	if _choice == null or _remain_card == null:
		return
	var view := get_viewport().get_visible_rect().size
	if view.y < 2.0:
		return
	var choosing := _phase == "choose"
	_remain_card.visible = choosing
	_remain.visible = choosing
	_remain_num.visible = choosing
	_choice.visible = choosing
	_waiting.visible = _phase == "wait"
	_choice.position = Vector2.ZERO
	_choice.size = view
	# remainingVotesFrame: dialog geom_scale (7, 1, 1), node scale 0.1, at (-0.9, 0.8).
	ToonGui.place(_remain_card, view, -0.9, 0.8, 0.7 * _DIALOG_W, 0.1 * _DIALOG_H)
	_place_line(_remain, -1.24, 0.79, 0.07, 0.62, HORIZONTAL_ALIGNMENT_LEFT)
	_place_line(_remain_num, -0.58, 0.785, 0.07, 0.28, HORIZONTAL_ALIGNMENT_RIGHT)
	# choiceFrame image_scale (1.4, 1, 0.225) at (-0.55, -0.85).
	ToonGui.place(_choice_card, view, -0.55, -0.85, 1.4 * _DIALOG_W, 0.225 * _DIALOG_H)
	_place_line(_use, -1.14, -0.86, 0.1, 0.4, HORIZONTAL_ALIGNMENT_CENTER)
	ToonGui.place(_up_scroll, view, -0.91, -0.775, _SCROLL_SIZE.x, _SCROLL_SIZE.y)
	ToonGui.place(_well, view, -0.91, -0.87, 0.24, 0.1025)
	ToonGui.style_label(_count, _count.get_theme_color("font_color"), _font_px(0.1), Color(0, 0, 0, 0), 0)
	ToonGui.place(_count, view, -0.91, -0.87, 0.22, 0.09)
	ToonGui.place(_down_scroll, view, -0.91, -0.91, _SCROLL_SIZE.x, _SCROLL_SIZE.y)
	_place_line(_tail, -0.76, -0.86, 0.1, 0.52, HORIZONTAL_ALIGNMENT_LEFT)
	_place_line(_way, -0.24, -0.86, 0.125, 0.45, HORIZONTAL_ALIGNMENT_LEFT)
	ToonGui.place(_vote, view, 0.3, -0.85, _OK_SIZE, _OK_SIZE)
	ToonGui.style_label(_vote_text, Color(0, 0, 0), _font_px(0.07), Color(0, 0, 0, 0), 0)
	ToonGui.place(_vote_text, view, 0.3, -0.85, 0.3, 0.08)
	_place_line(_waiting, -0.2, -0.85, 0.075, 2.4, HORIZONTAL_ALIGNMENT_CENTER)
	_result.position = Vector2(view.x * 0.12, view.y * 0.18)
	_result.size = Vector2(view.x * 0.76, view.y * 0.4)


func _aim_top() -> void:
	# cameraTopView is (100, -20, 280) with HPR (0, -89, 0). Positive pitch looks up.
	_camera.position = _panda(100.0, -20.0, 280.0)
	_camera.rotation = Vector3(deg_to_rad(-89.0), 0.0, 0.0)
	_camera.fov = 52.0


func _dialog_card() -> TextureRect:
	var card := TextureRect.new()
	card.texture = _DIALOG
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.modulate = _CREAM
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _line(text: String, color: Color, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(label, color, 16, Color(0, 0, 0, 0), 0)
	return label


func _ridge() -> Panel:
	var panel := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.82, 0.82, 0.82, 1)
	box.border_color = Color(0.55, 0.55, 0.55, 1)
	box.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _scroll_button(flip: bool) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _SCROLL_UP
	button.texture_pressed = _SCROLL_DOWN
	button.texture_hover = _SCROLL_HOVER
	button.texture_disabled = _SCROLL_UP
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.flip_v = flip
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _ok_button() -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _OK_UP
	button.texture_pressed = _OK_DOWN
	button.texture_hover = _OK_HOVER
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _dim_scroll(button: TextureButton, stuck: bool) -> void:
	button.disabled = stuck
	button.modulate = Color(0.6, 0.6, 0.6, 0.6) if stuck else Color(1, 1, 1, 1)


func _place_line(label: Label, x: float, z: float, scale: float, width: float, align: HorizontalAlignment) -> void:
	var view := get_viewport().get_visible_rect().size
	var color := label.get_theme_color("font_color")
	ToonGui.style_label(label, color, _font_px(scale), Color(0, 0, 0, 0), 0)
	var center_x := x
	if align == HORIZONTAL_ALIGNMENT_LEFT:
		center_x = x + width * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		center_x = x - width * 0.5
	ToonGui.place(label, view, center_x, z + scale * 0.35, width, scale * 1.35)


func _pin_bonus() -> void:
	if _bonus == null:
		return
	var show := _signs != null and _signs.visible
	var mine: Dictionary = _goals.get(ToonNet.peer_id(), {})
	if not show or mine.is_empty() or _camera == null or _camera.is_position_behind(_bonus_at):
		_bonus.visible = false
		return
	var point := _camera.unproject_position(_bonus_at)
	_bonus.visible = true
	_bonus.text = "%d Beans" % int(mine.get("beans", 0))
	_bonus.position = point + Vector2(16, -12)


func _show_signs() -> void:
	if _signs == null:
		return
	_signs.visible = _phase == "choose" or _phase == "wait" or _phase == "win"


func _face_car() -> void:
	_camera.global_position = _car.global_position + Vector3(0.0, 7.5, 25.0)
	_camera.look_at(_car.global_position + Vector3(0.0, 4.0, 0.0), Vector3.UP)


func _set_table(index: int, amount: float) -> void:
	if index < 0 or index >= _tables.size():
		return
	_tables[index].rotation.y = _angle(_from, _to) * amount


func _spin(u: float) -> void:
	var dist := _from_pos.distance_to(_to_pos)
	var wheel := u * dist / 0.95
	var key_turn := u * deg_to_rad(1080.0)
	for index in range(_wheels.size()):
		_wheels[index].rotation.z = _wheel_rest[index] + wheel
	for index in range(_keys.size()):
		_keys[index].rotation.z = _key_rest[index] + key_turn


func _angle(a: int, b: int) -> float:
	var start: Vector2 = _info(a)["pos"]
	var stop: Vector2 = _info(b)["pos"]
	return atan2(stop.y - start.y, stop.x - start.x)


func _car_yaw(angle: float) -> float:
	return -angle - PI * 0.5


func _info(index: int) -> Dictionary:
	return _layout(_which)[index]


func _ease(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


func _party() -> Array[int]:
	var ids: Array[int] = []
	for card in _RIDE.riders:
		if card is Dictionary:
			var peer := int((card as Dictionary).get("peer", 0))
			if peer > 0 and not ids.has(peer):
				ids.append(peer)
	if ids.is_empty():
		ids.append(ToonNet.peer_id())
	ids.sort()
	return ids


func _name_of(peer: int) -> String:
	for card in _RIDE.riders:
		if card is Dictionary and int((card as Dictionary).get("peer", -1)) == peer:
			var called := String((card as Dictionary).get("name", ""))
			if called != "":
				return called
	return "A Toon"


func _pool() -> Array[int]:
	var count := maxi(_party().size(), 1)
	var source: Array[int] = [2, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15, 16]
	if count == 2:
		source = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
	elif count >= 3:
		source = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
	var pool: Array[int] = []
	for game_id in source:
		pool.append(game_id)
	return pool


func _only(node: Node, keep: String) -> Node3D:
	var keeper := _named(node, keep)
	_hide_meshes(node, keeper)
	return node as Node3D


func _named(node: Node, wanted: String) -> Node:
	if String(node.name) == wanted:
		return node
	for child in node.get_children():
		var found := _named(child, wanted)
		if found != null:
			return found
	return null


func _hide_meshes(node: Node, keeper: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		mesh.visible = keeper != null and (node == keeper or keeper.is_ancestor_of(node))
	for child in node.get_children():
		_hide_meshes(child, keeper)


func _style(label: Label, color: Color, px: int) -> void:
	ToonGui.style_label(label, color, px, Color(0, 0, 0), 4)


func _icon_name(game_id: int) -> String:
	match game_id:
		1:
			return "mg_trolley_sign_race"
		2:
			return "mg_trolley_sign_cannon"
		3:
			return "mg_trolley_sign_tag"
		4:
			return "mg_trolley_sign_minnie"
		5:
			return "mg_trolley_sign_ring"
		6:
			return "mg_trolley_sign_maze"
		7:
			return "mg_trolley_sign_tugawar"
		8:
			return "mg_trolley_sign_catch"
		9:
			return "mg_trolley_sign_dive"
		10:
			return "mg_trolley_sign_umbrella"
		11:
			return "mg_trolley_sign_card"
		12:
			return "mg_trolley_sign_vine"
		13:
			return "mg_trolley_sign_ice"
		14:
			return "mg_trolley_sign_theif"
		15:
			return "mg_trolley_sign_2d"
		16:
			return "mg_trolley_sign_photo"
		_:
			return ""


func _game_name(game_id: int) -> String:
	match game_id:
		1:
			return "Race Game"
		2:
			return "Cannon Game"
		3:
			return "Tag Game"
		4:
			return "Match Minnie"
		5:
			return "Ring Game"
		6:
			return "Maze Game"
		7:
			return "Tug of War"
		8:
			return "Catching Game"
		9:
			return "Treasure Dive"
		10:
			return "Toon Slingshot"
		11:
			return "Memory Game"
		12:
			return "Jungle Vines"
		13:
			return "Ice Slide"
		14:
			return "Cog Thief"
		15:
			return "Toon Escape"
		16:
			return "Photo Fun"
		_:
			return "Trolley Game"


func _dir_word(direction: int) -> String:
	return "UP" if direction == 0 else "DOWN"


func _spot(links: Array, x: float, y: float, bonus: int = 0) -> Dictionary:
	return {"links": links, "pos": Vector2(x, y), "bonus": bonus}


func _layout(index: int) -> Dictionary:
	if index == 1:
		return {
			0: _spot([1, 2], 0, 0),
			1: _spot([3, 4], _X, 3 * _Y),
			2: _spot([5, 6], _X, -3 * _Y),
			3: _spot([7, 8], 2 * _X, 4 * _Y),
			4: _spot([8, 9], 2 * _X, 2 * _Y),
			5: _spot([10, 11], 2 * _X, -2 * _Y),
			6: _spot([11, 12], 2 * _X, -4 * _Y),
			7: _spot([], 3 * _X, 5 * _Y, 2),
			8: _spot([], 3 * _X, 3 * _Y, 1),
			9: _spot([], 3 * _X, _Y, 2),
			10: _spot([], 3 * _X, -_Y, 2),
			11: _spot([], 3 * _X, -3 * _Y, 1),
			12: _spot([], 3 * _X, -5 * _Y, 2),
		}
	if index == 2:
		return {
			0: _spot([1, 2], 0, 0),
			1: _spot([3, 4], _X, 3 * _Y),
			2: _spot([5, 6], _X, -3 * _Y),
			3: _spot([7, 8], 2 * _X, 4 * _Y),
			4: _spot([8, 9], 2 * _X, 2 * _Y),
			5: _spot([9, 10], 2 * _X, 0),
			6: _spot([11, 12], 2 * _X, -4 * _Y),
			7: _spot([], 3 * _X, 5 * _Y, 2),
			8: _spot([], 3 * _X, 3 * _Y, 1),
			9: _spot([], 3 * _X, _Y, 1),
			10: _spot([], 3 * _X, -_Y, 2),
			11: _spot([], 3 * _X, -3 * _Y, 2),
			12: _spot([], 3 * _X, -5 * _Y, 2),
		}
	if index == 3:
		return {
			0: _spot([1, 2], 0, 0),
			1: _spot([3, 4], _X, 2 * _Y),
			2: _spot([5, 6], _X, -3 * _Y),
			3: _spot([7, 8], 2 * _X, 4 * _Y),
			4: _spot([9, 10], 2 * _X, 0),
			5: _spot([10, 11], 2 * _X, -2 * _Y),
			6: _spot([11, 12], 2 * _X, -4 * _Y),
			7: _spot([], 3 * _X, 5 * _Y, 2),
			8: _spot([], 3 * _X, 3 * _Y, 2),
			9: _spot([], 3 * _X, _Y, 2),
			10: _spot([], 3 * _X, -_Y, 1),
			11: _spot([], 3 * _X, -3 * _Y, 1),
			12: _spot([], 3 * _X, -5 * _Y, 2),
		}
	return {
		0: _spot([1, 2], 0, 0),
		1: _spot([3, 4], _X, 2 * _Y),
		2: _spot([4, 5], _X, -2 * _Y),
		3: _spot([6, 7], 2 * _X, 4 * _Y),
		4: _spot([8, 9], 2 * _X, 0),
		5: _spot([10, 11], 2 * _X, -4 * _Y),
		6: _spot([], 3 * _X, 5 * _Y, 2),
		7: _spot([], 3 * _X, 3 * _Y, 2),
		8: _spot([], 3 * _X, _Y, 1),
		9: _spot([], 3 * _X, -_Y, 1),
		10: _spot([], 3 * _X, -3 * _Y, 2),
		11: _spot([], 3 * _X, -5 * _Y, 2),
	}
