extends Node3D

## One minigolf hole. The district already rolled the ball. This plays that
## path, with the camera and the power bar following the local toon.
## Tab looks down on the green. Up aims at the cup. Hold the mouse button,
## Ctrl, or the Jump button and let go to swing. The right stick aims too.
## The bar is the original three-second cycle. The score card records
## trophies, cups, and best scores.

const _HOME := "res://scenes/playgrounds/chip_n_dales_minigolf.tscn"
const _MILL := preload("res://assets/minigolf/windmill.glb")
const _KEYS := preload("res://scenes/shticker/keybinds.gd")
const _RECORDS := preload("res://scenes/golf/golf_records.gd")

var _world: Node3D
var _movers: Array[Node3D] = []
var _camera: Camera3D
var _balls: Array[MeshInstance3D] = []
var _toon: ToonActor
var _putter: Node3D
var _hit: AudioStreamPlayer
var _cup_sfx: AudioStreamPlayer
var _hole_id := -1
var _shot := -1
var _token := ""
var _roll := 0.0
var _cup_played := -1
var _aim := 0.0
var _hold := -1.0
var _pad_swing := false
var _pad_left := false
var _pad_right := false
var _pad_forward := false
var _awarded := -1
var _aim_sent := 0.0
var _top := false
var _leaving := false
var _saw := false
var _lost := 0.0
var _gui: Control
var _board: Control
var _dialog: TextureRect
var _title_bar: TextureRect
var _highlight: TextureRect
var _icon: TextureButton
var _close: TextureButton
var _exit_course: TextureButton
var _title: Label
var _help: Label
var _exit_caption: Label
var _power: ColorRect
var _power_fill: ColorRect
var _power_text: Label
var _cells: Array[Label] = []
var _board_on := false
var _board_until := 0.0
var _opened_hole := -1


func _ready() -> void:
	var env := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color(0.45, 0.72, 0.95)
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color(0.85, 0.9, 0.85)
	env.environment = sky
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 30, 0)
	add_child(sun)
	_world = Node3D.new()
	_world.name = "Green"
	add_child(_world)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 52.0
	add_child(_camera)
	var ball_mesh := _golf_ball()
	for index in MiniGolfRules.PLAYERS:
		var ball := MeshInstance3D.new()
		ball.mesh = ball_mesh
		ball.material_override = _paint(MiniGolfRules.BALL_COLORS[index])
		ball.visible = false
		add_child(ball)
		_balls.append(ball)
	_build_hud()
	_hit = _sound("res://assets/minigolf/audio/Golf_Hit_Ball.ogg")
	_cup_sfx = _sound("res://assets/minigolf/audio/Golf_Ball_Rest_In_Cup.ogg")


func _process(delta: float) -> void:
	if _leaving:
		return
	var game := MiniGolf.mine()
	if game.is_empty():
		if _saw:
			_home()
		else:
			_lost += delta
			if _lost > 2.0:
				_home()
		return
	_saw = true
	_lost = 0.0
	var hole_id := int(game.get("hole", 0))
	if hole_id != _hole_id:
		_hole_id = hole_id
		_build_hole(MiniGolfRules.hole(hole_id))
	var token := "%s:%s:%s" % [int(game.get("shot", 0)), String(game.get("phase", "")), int(game.get("turn", 0))]
	if token != _token:
		_token = token
		_aim = float(game.get("aim", _aim))
		_hold = -1.0
	var shot := int(game.get("shot", 0))
	if shot != _shot and String(game.get("phase", "")) == "roll" and _hit != null and _hit.stream != null:
		_hit.play()
	_move_balls(game, delta)
	_move_obstacles(float(game.get("clock", 0.0)))
	_move_toon(game)
	_aim_camera(game, delta)
	_fill_hud(game)
	_play(game, delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_TAB:
		_top = not _top
		return
	var game := MiniGolf.mine()
	if game.is_empty() or not _my_turn(game):
		return
	var phase := String(game.get("phase", ""))
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_UP:
			_aim = _cup_aim()
			ToonNet.minigolf_act("aim", 0, _aim, 0.0)
		elif key.keycode == KEY_LEFT or key.keycode == KEY_A:
			_nudge(phase, -1)
		elif key.keycode == KEY_RIGHT or key.keycode == KEY_D:
			_nudge(phase, 1)
		elif key.keycode == KEY_CTRL and phase == "tee":
			ToonNet.minigolf_act("ready", 0, 0.0, 0.0)
		elif key.keycode == KEY_CTRL and phase == "aim":
			_hold = 0.0
	elif event is InputEventKey and not event.pressed:
		var key := event as InputEventKey
		if key.keycode == KEY_CTRL and phase == "aim" and _hold >= 0.0:
			_release()
	elif event is InputEventMouseMotion and phase == "aim":
		_aim -= (event as InputEventMouseMotion).relative.x * 0.004
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if phase == "tee" and button.pressed:
			ToonNet.minigolf_act("ready", 0, 0.0, 0.0)
		elif phase == "aim" and button.pressed:
			_hold = 0.0
		elif phase == "aim" and _hold >= 0.0:
			_release()


func _nudge(phase: String, step: int) -> void:
	if phase == "tee":
		var game := MiniGolf.mine()
		var tee := clampi(int(game.get("tee", 1)) + step, 0, 2)
		ToonNet.minigolf_act("tee", tee, 0.0, 0.0)
	elif phase == "aim":
		_aim += float(step) * 0.08


func _release() -> void:
	var hold := maxf(_hold, 0.0)
	_hold = -1.0
	ToonNet.minigolf_act("swing", 0, hold, _aim)


func _play(game: Dictionary, delta: float) -> void:
	if String(game.get("phase", "")) == "card" and int(game.get("id", -1)) != _awarded:
		var match_id := int(game.get("id", -1))
		if _RECORDS.award(match_id, game):
			_awarded = match_id
	if not _my_turn(game):
		_hold = -1.0
		_pad_swing = false
		return
	var phase := String(game.get("phase", ""))
	_pad(phase, delta)
	if phase == "aim":
		if _hold >= 0.0:
			_hold += delta
		_aim_sent += delta
		if _aim_sent > 0.12:
			_aim_sent = 0.0
			ToonNet.minigolf_act("aim", 0, _aim, 0.0)
	else:
		_hold = -1.0
		_pad_swing = false


func _pad(phase: String, delta: float) -> void:
	var left := _KEYS.pad_held("left")
	var right := _KEYS.pad_held("right")
	var forward := _KEYS.pad_held("forward")
	var swing := _KEYS.pad_held("jump") or _KEYS.pad_held("use")
	if phase == "tee":
		if left and not _pad_left:
			_nudge(phase, -1)
		if right and not _pad_right:
			_nudge(phase, 1)
		if swing and not _pad_swing:
			ToonNet.minigolf_act("ready", 0, 0.0, 0.0)
	elif phase == "aim":
		var stick := _KEYS.look().x
		if left:
			_aim -= delta * 1.4
		if right:
			_aim += delta * 1.4
		if absf(stick) > 0.0:
			_aim += stick * delta * 1.6
		if forward and not _pad_forward:
			_aim = _cup_aim()
		if swing and not _pad_swing and _hold < 0.0:
			_hold = 0.0
		elif not swing and _pad_swing and _hold >= 0.0:
			_release()
	_pad_left = left
	_pad_right = right
	_pad_forward = forward
	_pad_swing = swing


func _move_balls(game: Dictionary, delta: float) -> void:
	var avs: Array = game.get("avs", [])
	var lies: Array = game.get("lies", [])
	var turn := int(game.get("turn", 0))
	var rolling := String(game.get("phase", "")) == "roll"
	var shot := int(game.get("shot", 0))
	if shot != _shot:
		_shot = shot
		_roll = float(game.get("timer", 0.0))
	elif rolling:
		_roll = maxf(_roll - delta, 0.0)
		var server := float(game.get("timer", 0.0))
		if absf(server - _roll) > 0.2:
			_roll = server
	for index in _balls.size():
		var ball := _balls[index]
		ball.visible = index < avs.size()
		if not ball.visible:
			continue
		if lies.size() < (index + 1) * 3:
			ball.visible = false
			continue
		var pos := Vector3(float(lies[index * 3]), float(lies[index * 3 + 1]), float(lies[index * 3 + 2]))
		if rolling and index == turn:
			pos = _along(game)
			var cup: Vector3 = MiniGolfRules.hole(_hole_id)["cup"]
			if _cup_played != shot and pos.distance_to(cup) < 1.2 and _cup_sfx != null and _cup_sfx.stream != null:
				_cup_played = shot
				_cup_sfx.play()
		ball.position = pos


func _along(game: Dictionary) -> Vector3:
	var path: Array = game.get("path", [])
	var duration := maxf(float(game.get("shot_time", 0.35)), 0.05)
	var t := clampf(1.0 - _roll / duration, 0.0, 1.0)
	if path.size() < 6:
		var lies: Array = game.get("lies", [])
		var turn := int(game.get("turn", 0))
		if lies.size() < (turn + 1) * 3:
			return Vector3.ZERO
		return Vector3(float(lies[turn * 3]), float(lies[turn * 3 + 1]), float(lies[turn * 3 + 2]))
	var samples := path.size() / 3
	var cursor := t * float(samples - 1)
	var index := clampi(int(cursor), 0, samples - 2)
	var blend := cursor - float(index)
	var x := lerpf(float(path[index * 3]), float(path[index * 3 + 3]), blend)
	var y := lerpf(float(path[index * 3 + 1]), float(path[index * 3 + 4]), blend)
	var z := lerpf(float(path[index * 3 + 2]), float(path[index * 3 + 5]), blend)
	return Vector3(x, y, z)


func _move_toon(game: Dictionary) -> void:
	var show := _my_turn(game) and String(game.get("phase", "")) != "roll" and String(game.get("phase", "")) != "card"
	if not show:
		if _toon != null:
			_toon.visible = false
		if _putter != null:
			_putter.visible = false
		return
	if _toon == null:
		var style := ToonRoster.selected_style()
		if style == null:
			return
		_toon = ToonActor.new()
		_toon.name = "Golfer"
		add_child(_toon)
		_toon.show_style(style)
	_toon.visible = true
	var ball := _balls[int(game.get("turn", 0))]
	var forward := Vector3(cos(_aim), 0.0, sin(_aim))
	_toon.global_position = ball.global_position - forward * 1.35
	_toon.global_position.y = ball.global_position.y - MiniGolfRules.BALL_RADIUS
	if forward.length_squared() > 0.0001:
		_toon.look_at(_toon.global_position + forward, Vector3.UP)
	_toon.set_locomotion(0.0, false, false, 0.016)
	_show_putter(ball.global_position, forward)


func _aim_camera(game: Dictionary, _delta: float) -> void:
	var focus := _balls[clampi(int(game.get("turn", 0)), 0, _balls.size() - 1)].global_position
	if String(game.get("phase", "")) == "card":
		focus = Vector3(0, 0, 12)
	if _top:
		var info := MiniGolfRules.hole(_hole_id)
		var cup: Vector3 = info["cup"]
		var tees: Array = info["tees"]
		var mid := cup
		var span := 24.0
		if not tees.is_empty():
			mid = ((tees[0] as Vector3) + cup) * 0.5
		for tee in tees:
			span = maxf(span, (tee as Vector3).distance_to(cup))
		_camera.global_position = mid + Vector3(0.0, span * 0.85, 0.2)
		_camera.look_at(mid, Vector3(0, 0, -1))
		return
	var back := Vector3(cos(_aim), 0.0, sin(_aim))
	if not _my_turn(game):
		back = Vector3(cos(float(game.get("aim", _aim))), 0.0, sin(float(game.get("aim", _aim))))
	var want := focus - back * 11.0 + Vector3(0, 4.2, 0)
	_camera.global_position = _camera.global_position.lerp(want, 0.18)
	_camera.look_at(focus + Vector3(0, 0.4, 0), Vector3.UP)


func _build_hole(info: Dictionary) -> void:
	for child in _world.get_children():
		child.queue_free()
	_movers.clear()
	var packed := load(String(info["model"])) as PackedScene
	if packed == null:
		return
	var hole := packed.instantiate()
	hole.name = "Hole"
	_world.add_child(hole)
	for record in MiniGolfRules.movers(_hole_id):
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var anchor := Node3D.new()
		anchor.set_meta("record", record)
		if String(record.get("kind", "")) == "fan":
			anchor.transform = MiniGolfRules.fan_root(record)
			var mill := _MILL.instantiate()
			anchor.add_child(mill)
			var fan := mill.find_child("windmillFan0", true, false)
			if fan is Node3D:
				anchor.set_meta("fan", fan)
		else:
			anchor.transform = MiniGolfRules.slide_transform(record, 0.0)
			var board := MeshInstance3D.new()
			var box := BoxMesh.new()
			var size: Array = record.get("size", [1.0, 1.0])
			box.size = Vector3(float(size[0]), float(size[1]), 1.0)
			board.mesh = box
			var paint := StandardMaterial3D.new()
			paint.albedo_color = Color(0.2, 0.75, 0.35)
			board.material_override = paint
			anchor.add_child(board)
		_world.add_child(anchor)
		_movers.append(anchor)


func _move_obstacles(when: float) -> void:
	for anchor in _movers:
		var record: Dictionary = anchor.get_meta("record", {})
		if String(record.get("kind", "")) == "fan":
			var fan: Variant = anchor.get_meta("fan", null)
			if fan is Node3D:
				(fan as Node3D).transform = MiniGolfRules.fan_spin(when)
		else:
			anchor.transform = MiniGolfRules.slide_transform(record, when)


func _fill_hud(game: Dictionary) -> void:
	var phase := String(game.get("phase", ""))
	var hole_i := int(game.get("hole_i", 0))
	if phase == "card":
		_board_on = true
	elif hole_i != _opened_hole:
		_opened_hole = hole_i
		_board_on = true
		_board_until = 3.0
	elif _board_until > 0.0:
		_board_until -= get_process_delta_time()
		if _board_until <= 0.0:
			_board_on = false
	var final := phase == "card"
	_board.visible = _board_on
	_icon.visible = not _board_on
	_close.visible = _board_on and not final
	_exit_course.visible = final
	_exit_caption.visible = final
	_write_card(game, final)
	var shown := phase == "aim" and _my_turn(game)
	_power.visible = shown
	_power_fill.visible = shown
	_power_text.visible = shown
	var reward := phase == "card" and _RECORDS.note() != ""
	_help.visible = reward or (_my_turn(game) and (phase == "tee" or phase == "aim"))
	if reward:
		_help.text = _RECORDS.note()
	elif phase == "tee":
		_help.text = "Left or Right changes the tee. Control or Jump starts the hole."
	elif phase == "aim":
		_help.text = "Left, Right, or the stick aims. Up faces the cup.\nHold Control or Jump, then let go."
	if shown:
		var amount := 0
		if _hold >= 0.0:
			amount = MiniGolfRules.power_from_hold(_hold)
		var inner := _power.size.x - _power.size.y * 0.1
		_power_fill.position = _power.position + Vector2(_power.size.y * 0.05, _power.size.y * 0.05)
		_power_fill.size = Vector2(maxf(inner, 0.0) * float(amount) / 100.0, _power.size.y * 0.9)
		_power_text.text = "%d%%" % amount


func _my_turn(game: Dictionary) -> bool:
	var avs: Array = game.get("avs", [])
	var turn := int(game.get("turn", 0))
	if turn < 0 or turn >= avs.size():
		return false
	return int(avs[turn]) == ToonRoster.avatar_id()


func _cup_aim() -> float:
	var info := MiniGolfRules.hole(_hole_id)
	var cup: Vector3 = info["cup"]
	var game := MiniGolf.mine()
	var turn := int(game.get("turn", 0))
	var lies: Array = game.get("lies", [])
	if lies.size() < (turn + 1) * 3:
		return _aim
	var aim := Vector2(cup.x - float(lies[turn * 3]), cup.z - float(lies[turn * 3 + 2]))
	if aim.length_squared() < 0.0001:
		return _aim
	return aim.angle()


func _home() -> void:
	if _leaving:
		return
	_leaving = true
	var arrival := load("res://scenes/playgrounds/playground_toon.gd")
	arrival.teleport_in = true
	ToonLoading.change_to(_HOME)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_gui = Control.new()
	_gui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gui.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_gui)
	_board = Control.new()
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.visible = false
	_gui.add_child(_board)
	_dialog = _picture(preload("res://assets/gui/tutorial/dialog/dialog_box.png"))
	_dialog.modulate = Color(1.0, 1.0, 0.75, 1.0)
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_board.add_child(_dialog)
	_title_bar = _picture(preload("res://assets/gui/golf/headPanel.png"))
	_title_bar.modulate = Color(0.7, 0.7, 0.7, 0.3)
	_board.add_child(_title_bar)
	_highlight = _picture(preload("res://assets/gui/golf/headPanel.png"))
	_board.add_child(_highlight)
	_title = _ink(_board, true)
	_help = _ink(_gui, false)
	_power = ColorRect.new()
	_power.color = Color(0.5, 0.5, 0.5, 0.5)
	_power.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power.visible = false
	_gui.add_child(_power)
	_power_fill = ColorRect.new()
	_power_fill.color = Color(1.0, 0.0, 0.0, 1.0)
	_power_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_fill.visible = false
	_gui.add_child(_power_fill)
	_power_text = _ink(_gui, false)
	_power_text.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_icon = _press(preload("res://assets/gui/golf/score_card_icon.png"), preload("res://assets/gui/golf/score_card_icon_rollover.png"), preload("res://assets/gui/golf/score_card_icon_rollover.png"))
	_gui.add_child(_icon)
	_icon.pressed.connect(_open_board)
	_close = _press(preload("res://assets/toons/gui/CloseBtn_UP.png"), preload("res://assets/toons/gui/CloseBtn_DN.png"), preload("res://assets/toons/gui/CloseBtn_Rllvr.png"))
	_board.add_child(_close)
	_close.pressed.connect(_close_board)
	_exit_course = _press(preload("res://assets/toons/gui/CloseBtn_UP.png"), preload("res://assets/toons/gui/CloseBtn_DN.png"), preload("res://assets/toons/gui/CloseBtn_Rllvr.png"))
	_board.add_child(_exit_course)
	_exit_course.pressed.connect(_quit)
	_exit_course.visible = false
	_exit_caption = _ink(_board, false)
	_exit_caption.text = "Exit Course"
	_exit_caption.visible = false
	_board.add_child(_exit_caption)
	var view := get_viewport()
	if not view.size_changed.is_connected(_layout_hud):
		view.size_changed.connect(_layout_hud)
	_layout_hud()


func _quit() -> void:
	ToonNet.minigolf_act("leave", 0, 0.0, 0.0)
	_home()


func _layout_hud() -> void:
	if _gui == null:
		return
	var view := get_viewport().get_visible_rect().size
	_gui.position = Vector2.ZERO
	_gui.size = view
	# dialog_box_gui, geom_scale (1.9, 1, 1.05), at (0, 0.375).
	ToonGui.place(_dialog, view, -0.02113 * 1.9, 0.375 - 0.03873 * 1.05, 1.1122 * 1.9, 1.1861 * 1.05)
	# headPanel is centered half its height above the given point.
	ToonGui.place(_title_bar, view, -0.003, 0.375 + 0.166 + 0.0975, 1.82, 0.195)
	ToonGui.place(_icon, view, 1.2, -0.85, 0.2, 0.2)
	ToonGui.place(_close, view, 0.0, 0.375 - 0.42, 0.1125, 0.1125)
	ToonGui.place(_exit_course, view, 0.0, 0.375 - 0.42, 0.1125, 0.1125)
	_put_text(_title, view, 0.0, 0.375 + 0.4, 1.6, 0.07, true, Color(0.0, 0.5, 0.125, 1.0))
	_put_text(_exit_caption, view, 0.15, 0.375 - 0.42, 0.5, 0.04, false, Color(0, 0, 0, 1))
	_put_text(_help, view, 0.0, -0.78, 1.4, 0.1, false, Color(1, 1, 1, 1))
	ToonGui.place(_help, view, 0.0, -0.78, 1.4, 0.24)
	_help.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_help.add_theme_constant_override("shadow_offset_x", 1)
	_help.add_theme_constant_override("shadow_offset_y", 1)
	ToonGui.place(_power, view, 0.0, -0.65, 1.0, 0.1)
	ToonGui.place(_power_text, view, 0.0, -0.65, 1.0, 0.065)
	_power_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _write_card(game: Dictionary, final: bool) -> void:
	var names: Array = game.get("names", [])
	var scores: Array = game.get("scores", [])
	var holes: Array = game.get("holes", [])
	var hole_i := int(game.get("hole_i", 0))
	var turn := int(game.get("turn", 0))
	var course := int(game.get("course", 0))
	var hole_name := MiniGolfRules.hole_title(int(game.get("hole", 0)))
	_title.text = "%s - %s" % [MiniGolfRules.course_title(course), hole_name]
	if final:
		var winner := String(game.get("winner", ""))
		if winner == "Tie":
			_title.text = "It's a tie!"
		elif winner != "":
			_title.text = "%s wins!" % winner
	var colors: Array[Color] = [
		Color(0.925, 0.168, 0.168, 0.4),
		Color(0.13, 0.59, 0.973, 0.4),
		Color(0.973, 0.809, 0.129, 0.4),
		Color(0.598, 0.402, 0.875, 0.4),
	]
	var view := get_viewport().get_visible_rect().size
	if turn >= 0 and turn < colors.size() and not final:
		_highlight.modulate = colors[turn]
		_highlight.visible = true
		ToonGui.place(_highlight, view, -0.003, 0.375 + 0.038 - float(turn) * 0.13 + 0.0675, 1.82, 0.135)
	else:
		_highlight.visible = false
	var need := 4 + holes.size() * 2 + names.size() * (holes.size() + 2)
	while _cells.size() < need:
		_cells.append(_ink(_board, false))
	for cell in _cells:
		cell.visible = false
	var column := -0.41
	_show_cell(0, view, -0.695, 0.675, "Hole", false, 0.22)
	_show_cell(1, view, -0.695, 0.575, "Par", false, 0.22)
	var slot := 2
	for index in holes.size():
		var hole_id := int(holes[index])
		var current := index == hole_i and not final
		_show_cell(slot, view, column + 0.12 * float(index), 0.675, str(index + 1), current)
		slot += 1
		_show_cell(slot, view, column + 0.12 * float(index), 0.575, str(int(MiniGolfRules.hole(hole_id)["par"])), current)
		slot += 1
	var total_x := -0.365 + 0.12 * 9.5
	_show_cell(slot, view, total_x, 0.675, "Total", final, 0.18)
	slot += 1
	var par_sum := 0
	for hole_id in holes:
		par_sum += int(MiniGolfRules.hole(int(hole_id))["par"])
	_show_cell(slot, view, total_x, 0.575, str(par_sum), final)
	slot += 1
	for player in names.size():
		var row: Array = scores[player] if player < scores.size() else []
		var y := 0.47 - 0.13 * float(player)
		_show_cell(slot, view, -0.695, y, String(names[player]), false, 0.28)
		slot += 1
		var total := 0
		for index in holes.size():
			var text := "-"
			var hot := index == hole_i and not final
			if index < row.size():
				text = str(int(row[index]))
				total += int(row[index])
			_show_cell(slot, view, column + 0.12 * float(index), y, text, hot)
			slot += 1
		_show_cell(slot, view, total_x, y, str(total), final)
		slot += 1


func _show_cell(index: int, view: Vector2, x: float, z: float, text: String, hot: bool, width: float = 0.11) -> void:
	if index < 0 or index >= _cells.size():
		return
	var cell := _cells[index]
	cell.visible = true
	cell.text = text
	_put_text(cell, view, x, z, width, 0.05, false, Color(1, 0, 0, 1) if hot else Color(0, 0, 0, 1))


func _open_board() -> void:
	_board_on = true
	_board_until = 0.0


func _close_board() -> void:
	_board_on = false
	_board_until = 0.0


func _picture(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _press(up: Texture2D, down: Texture2D, hover: Texture2D) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = up
	button.texture_pressed = down
	button.texture_hover = hover
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ToonGui.button_sounds(button)
	return button


func _ink(parent: Node, sign: bool) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if sign:
		ToonGui.style_sign(label, Color(0, 0.5, 0.125), 16, Color(0, 0, 0, 0), 0)
	else:
		ToonGui.style_label(label, Color(0, 0, 0), 16, Color(0, 0, 0, 0), 0)
	parent.add_child(label)
	return label


func _put_text(label: Label, view: Vector2, x: float, z: float, width: float, text_scale: float, sign: bool, color: Color) -> void:
	var px := maxi(int(round(text_scale * view.y * 0.5)), 8)
	if sign:
		ToonGui.style_sign(label, color, px, Color(0, 0, 0, 0), 0)
	else:
		ToonGui.style_label(label, color, px, Color(0, 0, 0, 0), 0)
	ToonGui.place(label, view, x, z, width, text_scale * 1.3)


func _golf_ball() -> Mesh:
	var packed := load(MiniGolfRules.BALL_MODEL) as PackedScene
	var found := _first_mesh(packed.instantiate() if packed != null else null)
	if found != null:
		return found
	var sphere := SphereMesh.new()
	sphere.radius = MiniGolfRules.BALL_RADIUS
	sphere.height = MiniGolfRules.BALL_RADIUS * 2.0
	return sphere


func _first_mesh(node: Node) -> Mesh:
	if node == null:
		return null
	var found := _seek_mesh(node)
	node.free()
	return found


func _seek_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return (node as MeshInstance3D).mesh
	for child in node.get_children():
		var found := _seek_mesh(child)
		if found != null:
			return found
	return null


func _show_putter(ball: Vector3, forward: Vector3) -> void:
	if _putter == null:
		var packed := load("res://assets/minigolf/putter.glb") as PackedScene
		if packed == null:
			return
		_putter = packed.instantiate()
		add_child(_putter)
	_putter.visible = true
	_putter.global_position = ball - forward * 0.55
	if forward.length_squared() > 0.0001:
		_putter.look_at(ball, Vector3.UP)


func _sound(path: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream := load(path) as AudioStream
	if stream != null:
		player.stream = stream
	add_child(player)
	return player


func _paint(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat
