extends "res://scenes/trolley/trolley_minigame.gd"

## Race Game, from DistributedRaceGame and RaceGameGlobals.
## Click a number. You only move when nobody else picked the same one.
## The first toon to space 14 wins. A chance space between 5 and 13 deals one card.

const _WIN := 14
const _INPUT := 20.0
const _DICE := "res://assets/minigames/dice.glb"
const _MARK := "res://assets/minigames/question_mark.glb"
const _CARD := "res://assets/minigames/chance_card.glb"

# self delta, others delta, jellybeans, card text. An empty line is the Fabulous Toon card.
const _REWARDS: Array = [
	[1, 0, 0, " forward 1 space"],
	[1, 0, 0, " forward 1 space"],
	[1, 0, 0, " forward 1 space"],
	[2, 0, 0, " forward 2 spaces"],
	[2, 0, 0, " forward 2 spaces"],
	[2, 0, 0, " forward 2 spaces"],
	[3, 0, 0, " forward 3 spaces"],
	[3, 0, 0, " forward 3 spaces"],
	[3, 0, 0, " forward 3 spaces"],
	[0, -3, 0, "all others back \n3 spaces"],
	[0, -3, 0, "all others back \n3 spaces"],
	[-1, 0, 0, " back 1 space"],
	[-1, 0, 0, " back 1 space"],
	[-2, 0, 0, " back 2 spaces"],
	[-2, 0, 0, " back 2 spaces"],
	[-3, 0, 0, " back 3 spaces"],
	[-3, 0, 0, " back 3 spaces"],
	[0, 3, 0, " all others forward \n3 spaces"],
	[0, 3, 0, " all others forward \n3 spaces"],
	[0, 0, 2, "2 jellybeans"],
	[0, 0, 2, "2 jellybeans"],
	[0, 0, 2, "2 jellybeans"],
	[0, 0, 2, "2 jellybeans"],
	[0, 0, 4, "4 jellybeans"],
	[0, 0, 4, "4 jellybeans"],
	[0, 0, 4, "4 jellybeans"],
	[0, 0, 4, "4 jellybeans"],
	[0, 0, 10, "10 jellybeans!"],
	[0, 0, 0, ""],
	[14, 0, 0, "Instant Winner!"],
]

# Four lanes, fifteen squares. Panda board space: x, y, z, heading.
const _LANES: Array = [
	[Vector4(-9.03, 0.06, 0.025, -152.9), Vector4(-7.43, -2.76, 0.025, -152.68), Vector4(-6.02, -5.48, 0.025, -157.54), Vector4(-5.01, -8.32, 0.025, -160.66), Vector4(-4.05, -11.36, 0.025, -170.22), Vector4(-3.49, -14.18, 0.025, -175.76), Vector4(-3.12, -17.15, 0.025, -177.73), Vector4(-3.0, -20.32, 0.025, 178.49), Vector4(-3.09, -23.44, 0.025, 176.59), Vector4(-3.43, -26.54, 0.025, 171.44), Vector4(-4.07, -29.44, 0.025, 163.75), Vector4(-5.09, -32.27, 0.025, 158.2), Vector4(-6.11, -35.16, 0.025, 154.98), Vector4(-7.57, -37.78, 0.025, 154.98), Vector4(-9.28, -40.65, 0.025, 150.41)],
	[Vector4(-6.12, 1.62, 0.025, -152.9), Vector4(-4.38, -1.35, 0.025, -150.92), Vector4(-3.08, -4.3, 0.025, -157.9), Vector4(-1.85, -7.26, 0.025, -162.54), Vector4(-0.93, -10.49, 0.025, -167.71), Vector4(-0.21, -13.71, 0.025, -171.79), Vector4(0.21, -17.08, 0.025, -174.92), Vector4(0.31, -20.2, 0.025, 177.1), Vector4(0.17, -23.66, 0.025, 174.82), Vector4(-0.23, -26.91, 0.025, 170.51), Vector4(-0.99, -30.2, 0.025, 162.54), Vector4(-2.02, -33.28, 0.025, 160.48), Vector4(-3.28, -36.38, 0.025, 157.96), Vector4(-4.67, -39.17, 0.025, 154.13), Vector4(-6.31, -42.15, 0.025, 154.13)],
	[Vector4(-2.99, 3.09, 0.025, -154.37), Vector4(-1.38, -0.05, 0.025, -154.75), Vector4(-0.19, -3.29, 0.025, -159.22), Vector4(1.17, -6.51, 0.025, -162.74), Vector4(2.28, -9.8, 0.025, -168.73), Vector4(3.09, -13.28, 0.025, -173.49), Vector4(3.46, -16.63, 0.025, -176.81), Vector4(3.69, -20.38, 0.025, 179.14), Vector4(3.61, -24.12, 0.025, 175.78), Vector4(3.0, -27.55, 0.025, 170.87), Vector4(2.15, -30.72, 0.025, 167.41), Vector4(1.04, -34.26, 0.025, 162.11), Vector4(-0.15, -37.44, 0.025, 158.59), Vector4(-1.64, -40.52, 0.025, 153.89), Vector4(-3.42, -43.63, 0.025, 153.89)],
	[Vector4(0.0, 4.35, 0.025, -154.37), Vector4(1.52, 1.3, 0.025, -155.67), Vector4(3.17, -2.07, 0.025, -155.67), Vector4(4.47, -5.41, 0.025, -163.0), Vector4(5.56, -9.19, 0.025, -168.89), Vector4(6.22, -12.66, 0.025, -171.67), Vector4(6.67, -16.56, 0.025, -176.53), Vector4(6.93, -20.33, 0.025, 179.87), Vector4(6.81, -24.32, 0.025, 175.19), Vector4(6.22, -27.97, 0.025, 170.81), Vector4(5.59, -31.73, 0.025, 167.54), Vector4(4.48, -35.42, 0.025, 161.92), Vector4(3.06, -38.82, 0.025, 158.56), Vector4(1.4, -42.0, 0.025, 154.32), Vector4(-0.71, -45.17, 0.025, 153.27)],
]

var _track: Node3D
var _pos: Array[int] = []
var _chance: Array[int] = []
var _reward: Array[int] = []
var _actors: Array = []
var _names: PackedStringArray = []
var _markers: Array = []
var _count := 4
var _me := 0
var _live := false
var _seen_turn := 0
var _phase := "pick"
var _left := _INPUT
var _picked := false
var _steps: Array = []
var _step := 0
var _step_age := 0.0
var _walks: Array = []
var _busy: Dictionary = {}
var _board_dice: Array = []
var _buttons: Array = []
var _button_dice: Array = []
var _hover := 0
var _held := 0
var _waiting: Label
var _card_pivot: Node3D
var _card_text: Label
var _card_age := -1.0
var _card_said := false
var _card_who := -1
var _card_reward := -1
var _card_from := Vector3.ZERO
var _card_to := Vector3(19.62, 13.14, -13.41)
var _card_basis_to := Basis()
var _cam_from := Vector3.ZERO
var _cam_to := Vector3.ZERO
var _look_from := Vector3.ZERO
var _look_to := Vector3.ZERO
var _look := Vector3.ZERO
var _cam_age := 1.0
var _win_age := 0.0


func _init() -> void:
	title = "Race Game"
	instructions = "Click a number. Choose wisely! You only advance if no one else picked the same number."
	duration = 900.0


func begin() -> void:
	super.begin()
	_left = _INPUT
	_sync_clock()


func _build() -> void:
	_live = party_size() > 1
	_count = party_size() if _live else 4
	_me = party_index() if _live else 0
	_pos.resize(_count)
	_chance.resize(_count)
	_reward.resize(_count)
	for i in _count:
		_pos[i] = 0
		_chance[i] = shared_range(5, _WIN - 1)
		_reward[i] = shared_int(_REWARDS.size())
	_green_sky()
	_track = _show("res://assets/minigames/race.glb")
	if _track != null:
		_track.scale = Vector3(0.8, 0.8, 0.8)
	_top_camera()
	_seat_racers()
	_place_markers()
	_build_buttons()
	_build_card()
	_build_labels()
	_drop_remotes()
	show_board("points")


func _play(delta: float) -> void:
	_layout_buttons()
	_tick_camera(delta)
	if _phase == "pick":
		if not _picked:
			_left -= delta
			if _left <= 0.0:
				_choose(0)
		_idle(delta)
	elif _phase == "wait":
		_watch_deal()
		_idle(delta)
	elif _phase == "movie":
		_advance(delta)
	elif _phase == "win":
		_win_age += delta
		_celebrate(delta)
		if _win_age >= 4.0:
			_end()
	_paint_buttons()
	_sync_clock()


func _input(event: InputEvent) -> void:
	if not playing or _phase != "pick" or _picked:
		return
	if event is InputEventMouseMotion:
		_hover = _die_at((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		var hit := _die_at(click.position)
		if click.pressed:
			_held = hit
		else:
			if _held == hit and hit > 0:
				_choose(hit)
			_held = 0
		if hit > 0:
			get_viewport().set_input_as_handled()


func _green_sky() -> void:
	for child in get_children():
		if child is WorldEnvironment:
			var env := (child as WorldEnvironment).environment
			if env != null:
				env.background_color = Color(0.1875, 0.7929, 0.0)


func _top_camera() -> void:
	var eye := Vector3(-22.78, -41.65, 31.53)
	var at := eye + Vector3(0.575734, 0.457140, -0.677903) * 30.0
	_snap_camera(_panda(eye.x, eye.y, eye.z), _panda(at.x, at.y, at.z))


func _seat_racers() -> void:
	var home := _world(0, 0) if _track != null else Vector3.ZERO
	_make_toon(home)
	_actors.resize(_count)
	_names.resize(_count)
	_actors[_me] = _toon
	_names[_me] = _local_name()
	for i in _count:
		if i == _me:
			_stand(i)
			continue
		var actor := ToonActor.new()
		add_child(actor)
		var style = _style_for(i)
		var worn: Dictionary = {}
		if _live:
			var cards: Array = _RIDE.riders
			if i < cards.size():
				var card: Dictionary = cards[i]
				var raw: Variant = card.get("accessories", {})
				if raw is Dictionary:
					worn = raw
		if style is ToonStyle:
			var dressed := style as ToonStyle
			actor.show_style(dressed)
			actor.name = dressed.display_name()
			if not _live:
				_names[i] = dressed.display_name()
		if _live:
			_names[i] = party_name(i)
		if not worn.is_empty():
			actor.wear_accessories(worn)
		if _tags != null and _names[i] != "":
			_tags.add(actor, _names[i], "player")
		_actors[i] = actor
		_stand(i)
	if _toon != null:
		_toon.set_locomotion(0.0, false, false, 0.0)


func _local_name() -> String:
	var mine := ToonRoster.selected_style()
	if mine != null:
		return mine.display_name()
	return "You"


func _style_for(index: int):
	if _live:
		var cards: Array = _RIDE.riders
		if index >= 0 and index < cards.size():
			var card: Dictionary = cards[index]
			var raw: Variant = card.get("style", {})
			if raw is Dictionary and (raw as Dictionary).has("head"):
				return ToonStyle.from_dict(raw)
	return ToonStyle.random_named("f" if index % 2 == 0 else "m")


func _drop_remotes() -> void:
	if _remotes != null and is_instance_valid(_remotes):
		_remotes.set_process(false)
		_remotes.queue_free()
		_remotes = null
	for child in get_children():
		if not is_instance_valid(child):
			continue
		if child is ToonActor and not _actors.has(child):
			(child as Node).queue_free()


func _place_markers() -> void:
	for i in _count:
		var mark := _prop(_MARK)
		_markers.append(mark)
		if mark == null or _track == null:
			continue
		_track.add_child(mark)
		mark.transform = Transform3D.IDENTITY
		var spot := _spot(i, _chance[i])
		mark.position = Vector3(spot.x, spot.y, spot.z)
		mark.scale = Vector3(0.7, 0.7, 0.7)
		mark.basis = _panda_basis(spot.w + 180.0, 0.0, 0.025)


func _build_buttons() -> void:
	for number in range(1, 5):
		var pivot := Node3D.new()
		pivot.name = "DieButton%d" % number
		_camera.add_child(pivot)
		pivot.visible = false
		pivot.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		var die := _prop(_DICE)
		if die != null:
			pivot.add_child(die)
			_show_face(die, "dice_button%d" % number)
		_buttons.append(pivot)
		_button_dice.append(die)


func _build_card() -> void:
	_card_pivot = Node3D.new()
	_card_pivot.name = "ChanceCard"
	_camera.add_child(_card_pivot)
	_card_pivot.visible = false
	var card := _prop(_CARD)
	if card != null:
		_card_pivot.add_child(card)
	_card_basis_to = Basis(Vector3(0.0, 0.996551, 0.082982), Vector3(0.0, 0.082982, -0.996551), Vector3(-1.0, 0.0, 0.0))


func _build_labels() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 22
	add_child(layer)
	_waiting = Label.new()
	_waiting.text = "Waiting for other players to choose..."
	_waiting.visible = false
	_waiting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ToonGui.style_label(_waiting, Color(1, 1, 1), _font_px(0.075), Color(0, 0, 0, 0), 0)
	_waiting.anchor_left = 0.15
	_waiting.anchor_right = 0.85
	_waiting.anchor_top = 0.78
	_waiting.anchor_bottom = 0.86
	layer.add_child(_waiting)
	_card_text = Label.new()
	_card_text.visible = false
	_card_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.anchor_left = 0.18
	_card_text.anchor_right = 0.82
	_card_text.anchor_top = 0.28
	_card_text.anchor_bottom = 0.62
	layer.add_child(_card_text)


func _choose(choice: int) -> void:
	if _phase != "pick" or _picked:
		return
	_picked = true
	_hover = 0
	_held = 0
	if _live:
		_phase = "wait"
		_waiting.visible = true
		ToonNet.note_minigame("pick", clampi(choice, 0, 4))
		return
	var picks: Array = [choice]
	for _i in range(_count - 1):
		picks.append(randi_range(1, 4))
	_resolve(picks)


func _watch_deal() -> void:
	var state := ToonNet.minigame_state()
	var turn := int(state.get("turn", 0))
	if turn == _seen_turn:
		return
	var raw: Variant = state.get("deal", [])
	if not (raw is Array) or (raw as Array).size() < _count:
		return
	_seen_turn = turn
	var picks: Array = []
	for i in _count:
		picks.append(int((raw as Array)[i]))
	_waiting.visible = false
	_resolve(picks)


func _resolve(picks: Array) -> void:
	var sim := _simulate(picks)
	_steps = _movie(sim["choices"], sim["positions"], sim["rewards"])
	_step = 0
	_step_age = 0.0
	_phase = "movie"
	_waiting.visible = false


func _simulate(picks: Array) -> Dictionary:
	var pos: Array = []
	for i in _count:
		pos.append(_pos[i])
	var chance: Array = []
	for i in _count:
		chance.append(_chance[i])
	var choices: Array = []
	var positions: Array = []
	var rewards: Array = []
	for i in _count:
		var choice := int(picks[i]) if i < picks.size() else 0
		_process_choice(pos, choices, positions, i, choice, _freq(picks, choice))
	var rewarded := false
	var done := false
	var guard := 0
	while not done and guard < _count + 2:
		guard += 1
		var row := _blank()
		for i in _count:
			var reward := -1
			if int(pos[i]) == int(chance[i]):
				reward = _reward[i]
				chance[i] = -1
			if reward != -1:
				rewarded = true
				row[i] = reward
				rewards.append_array(row)
				var entry: Array = _REWARDS[reward]
				for av in _count:
					var delta := int(entry[0]) if av == i else int(entry[1])
					_process_choice(pos, choices, positions, av, delta, 1)
				break
		if not rewarded:
			rewards.append_array(row)
		done = row.count(-1) == row.size()
	return {"choices": choices, "positions": positions, "rewards": rewards}


func _process_choice(pos: Array, choices: Array, positions: Array, i: int, choice: int, freq: int) -> void:
	if freq == 1 and choice != 0 and int(pos[i]) < _WIN:
		pos[i] = int(pos[i]) + choice
		if int(pos[i]) < 0:
			pos[i] = 0
	choices.append(choice)
	positions.append(int(pos[i]))


func _movie(choices: Array, positions: Array, rewards: Array) -> Array:
	var steps: Array = []
	var copy: Array = []
	for i in _count:
		copy.append(clampi(_pos[i], 0, _WIN))
	var turns := int(choices.size() / _count)
	for turn in turns:
		var start := turn * _count
		var choice_slice: Array = choices.slice(start, start + _count)
		var pos_slice: Array = positions.slice(start, start + _count)
		var reward_slice: Array = []
		if start < rewards.size():
			reward_slice = rewards.slice(start, mini(start + _count, rewards.size()))
		var longest := _longest(choice_slice, pos_slice, turn > 0, copy)
		if turn == 0:
			steps.append({"kind": "numbers", "choices": choice_slice, "time": 0.5})
			steps.append({"kind": "matches", "choices": choice_slice, "time": 0.75 if longest > 0.0 else 1.0})
		if longest > 0.0:
			var hold := 0.75 if turn == 0 else longest
			steps.append({"kind": "walk", "choices": choice_slice, "positions": pos_slice, "chance": turn > 0, "time": hold})
			if turn == 0:
				steps.append({"kind": "hide", "time": maxf(longest - 0.5, 0.0)})
			for index in reward_slice.size():
				if int(reward_slice[index]) != -1:
					steps.append({"kind": "card", "who": index, "reward": int(reward_slice[index]), "time": 4.25})
		elif turn == 0:
			steps.append({"kind": "hide", "time": 0.0})
		else:
			steps.append({"kind": "hide", "time": 1.0})
	return steps


func _longest(choices: Array, positions: Array, after_first: bool, copy: Array) -> float:
	var longest := 0.0
	for i in choices.size():
		var choice := int(choices[i])
		if after_first or _freq(choices, choice) == 1:
			var old_place := clampi(int(copy[i]), 0, _WIN)
			var new_place := clampi(int(positions[i]), 0, _WIN)
			copy[i] = int(positions[i])
			longest = maxf(longest, _walk_time(absi(new_place - old_place)))
	return longest


func _walk_time(squares: int) -> float:
	var pace := absf(float(squares) / 1.2)
	if squares > 4:
		pace *= 0.3
	return pace


func _advance(delta: float) -> void:
	if _step >= _steps.size():
		_finish_movie()
		return
	var step: Dictionary = _steps[_step]
	if not bool(step.get("began", false)):
		step["began"] = true
		_steps[_step] = step
		_begin_step(step)
	_tick_walks(delta)
	_tick_card(delta)
	_step_age += delta
	if _step_age < float(step.get("time", 0.0)):
		return
	_step_age = 0.0
	_step += 1
	if _step >= _steps.size():
		_finish_movie()


func _begin_step(step: Dictionary) -> void:
	var kind := String(step.get("kind", ""))
	var choices: Array = step.get("choices", [])
	var positions: Array = step.get("positions", [])
	if kind == "numbers":
		_show_numbers(choices)
	elif kind == "matches":
		_show_matches(choices)
	elif kind == "walk":
		_start_walk(choices, positions, bool(step.get("chance", false)))
	elif kind == "hide":
		_clear_dice()
	elif kind == "card":
		_start_card(int(step.get("who", -1)), int(step.get("reward", -1)))


func _show_numbers(choices: Array) -> void:
	_clear_dice()
	if _track == null:
		return
	for i in mini(choices.size(), _count):
		var choice := int(choices[i])
		if choice <= 0:
			continue
		var die := _prop(_DICE)
		if die == null:
			continue
		_track.add_child(die)
		die.transform = Transform3D.IDENTITY
		var place := mini(clampi(_pos[i], 0, _WIN) + 1, _WIN)
		var spot := _spot(i, place)
		die.position = Vector3(spot.x, spot.y, 0.05)
		die.scale = Vector3(4.0, 4.0, 4.0)
		die.basis = _panda_basis(spot.w, -90.0, 0.0)
		_show_face(die, "dice_button%d" % choice)
		die.set_meta("lane", i)
		die.set_meta("choice", choice)
		_board_dice.append(die)


func _show_matches(choices: Array) -> void:
	for die in _board_dice:
		if not is_instance_valid(die):
			continue
		var lane := int(die.get_meta("lane", -1))
		var choice := int(die.get_meta("choice", 0))
		if lane < 0 or choice == 0:
			continue
		var alone := _freq(choices, choice) == 1
		_tint_die(die, Color(0.2, 1.0, 0.2) if alone else Color(1.0, 0.2, 0.2))
		if lane == _me:
			_sfx("MG_pos_buzzer" if alone else "MG_neg_buzzer")


func _start_walk(choices: Array, positions: Array, chance: bool) -> void:
	_walks.clear()
	_busy.clear()
	for i in _count:
		var choice := int(choices[i]) if i < choices.size() else 0
		var dest := int(positions[i]) if i < positions.size() else _pos[i]
		var src := _pos[i]
		_pos[i] = dest
		var skip := choice == 0 or (not chance and _freq(choices, choice) != 1)
		var shown_src := clampi(src, 0, _WIN)
		var shown_dest := clampi(dest, 0, _WIN)
		if skip or shown_src == shown_dest:
			_stand(i)
			continue
		var squares := absi(shown_dest - shown_src)
		var run := squares > 4
		var points: Array = []
		var heads: Array = []
		if run:
			var step := int((shown_dest - shown_src) / 3)
			var stops := [shown_src, shown_src + step, shown_src + step * 2, shown_dest]
			for place in stops:
				var spot := _spot(i, place)
				points.append(_world(i, place))
				heads.append(spot.w)
		else:
			points.append(_world(i, shown_src))
			points.append(_world(i, shown_dest))
			heads.append(_spot(i, shown_src).w)
			heads.append(_spot(i, shown_dest).w)
		_walks.append({
			"lane": i,
			"points": points,
			"heads": heads,
			"dur": maxf(_walk_time(squares), 0.05),
			"age": 0.0,
			"run": run,
			"back": choice < 0,
		})
		_busy[i] = true
	_race_camera()


func _tick_walks(delta: float) -> void:
	var still: Array = []
	for item in _walks:
		var lane := int(item["lane"])
		var actor = _racer(lane)
		if actor == null:
			continue
		item["age"] = float(item["age"]) + delta
		var dur := float(item["dur"])
		var age := float(item["age"])
		if age >= dur:
			_stand(lane)
			_busy.erase(lane)
			actor.set_locomotion(0.0, false, false, delta)
			continue
		var points: Array = item["points"]
		var heads: Array = item["heads"]
		var u := clampf(age / dur, 0.0, 1.0)
		var seg := 0
		var local := u
		if bool(item["run"]) and points.size() >= 4:
			seg = mini(int(u * 3.0), 2)
			local = clampf(u * 3.0 - float(seg), 0.0, 1.0)
		var a: Vector3 = points[seg]
		var b: Vector3 = points[seg + 1]
		actor.global_position = a.lerp(b, local)
		var heading := rad_to_deg(lerp_angle(deg_to_rad(float(heads[seg])), deg_to_rad(float(heads[seg + 1])), local))
		_face(actor, heading)
		if bool(item["run"]):
			actor.play_run(delta)
		elif bool(item["back"]):
			actor.set_locomotion(-4.0, false, false, delta)
		else:
			actor.play_walk(delta)
		still.append(item)
	_walks = still
	_idle(delta)


func _start_card(who: int, reward: int) -> void:
	if who >= 0 and who < _markers.size():
		var mark = _markers[who]
		if is_instance_valid(mark):
			(mark as Node3D).visible = false
		if who < _chance.size():
			_chance[who] = -1
	_card_who = who
	_card_reward = reward
	_card_age = 0.0
	_card_said = false
	_card_text.visible = false
	if _card_pivot != null:
		_card_pivot.visible = true
		_card_from = Vector3(0.0, -6.0, -8.0)
		_card_pivot.position = _card_from
		_card_pivot.basis = Basis.IDENTITY
	_sfx("GUI_stickerbook_turn")


func _tick_card(delta: float) -> void:
	if _card_age < 0.0 or _card_pivot == null:
		return
	_card_age += delta
	var u := clampf(_card_age / 1.0, 0.0, 1.0)
	_card_pivot.position = _card_from.lerp(_card_to, u)
	_card_pivot.basis = Basis.IDENTITY.slerp(_card_basis_to, u)
	if _card_age >= 1.0 and not _card_said:
		_say_card()
	if _card_age >= 4.0:
		_hide_card()


func _say_card() -> void:
	_card_said = true
	if _card_reward < 0 or _card_reward >= _REWARDS.size():
		return
	var entry: Array = _REWARDS[_card_reward]
	var called := _names[_card_who] if _card_who >= 0 and _card_who < _names.size() else "Toon"
	var line := String(entry[3])
	if int(entry[2]) > 0:
		_card_text.text = "%s receives: %s" % [called, line]
	elif line == "":
		_card_text.text = "%s is one Fabulous Toon!" % called
	else:
		_card_text.text = "%s draws: %s" % [called, line]
	ToonGui.style_sign(_card_text, Color(1.0, 0.0, 0.0), _font_px(0.14), Color(0.0, 0.0, 0.0, 0.0), 0)
	_card_text.visible = true
	if int(entry[0]) < 0 or int(entry[1]) > 0:
		_sfx("MG_neg_buzzer")
	else:
		_sfx("MG_pos_buzzer")
	if _card_who == _me:
		score += int(entry[2])


func _hide_card() -> void:
	_card_age = -1.0
	if _card_pivot != null:
		_card_pivot.visible = false
	if _card_text != null:
		_card_text.visible = false


func _finish_movie() -> void:
	_clear_dice()
	_hide_card()
	_walks.clear()
	_busy.clear()
	var won := false
	var winners := 0
	for spot in _pos:
		if spot >= _WIN:
			won = true
			winners += 1
	if not won:
		for i in _count:
			_stand(i)
		_open_pick()
		return
	if _me >= 0 and _me < _pos.size():
		var beans := int(ceil(float(_pos[_me]) * 0.5))
		if _pos[_me] >= _WIN:
			beans = _WIN
			if winners > 1:
				beans -= 3
		score += beans
		_sfx("MG_win" if _pos[_me] >= _WIN else "MG_lose")
	_phase = "win"
	_win_age = 0.0


func _open_pick() -> void:
	_phase = "pick"
	_picked = false
	_left = _INPUT
	_hover = 0
	_held = 0
	_waiting.visible = false


func _celebrate(delta: float) -> void:
	for i in _count:
		var actor = _racer(i)
		if actor == null:
			continue
		var winner := _pos[i] >= _WIN
		if winner:
			_stand(i)
		actor.set_locomotion(0.0, false, winner, delta)


func _idle(delta: float) -> void:
	if _phase == "win":
		return
	for i in _count:
		if _busy.has(i):
			continue
		var actor = _racer(i)
		if actor == null:
			continue
		actor.set_locomotion(0.0, false, false, delta)


func _race_camera() -> void:
	if _count <= 0:
		return
	var best := _pos[0]
	var best_lane := 0
	for i in _count:
		if _pos[i] > best:
			best = _pos[i]
			best_lane = i
	best = mini(_WIN, best)
	var local_pos := mini(_WIN, _pos[_me])
	var pos1 := _spot(_me, mini(_WIN - 4, local_pos))
	var best_look := mini(_WIN, best + 1)
	var local_look := local_pos + 4
	var pos2: Vector4
	if local_look >= best_look:
		pos2 = _spot(_me, mini(_WIN, local_look))
	else:
		pos2 = _spot(best_lane, best_look)
	var cam_x := pos2.x + 0.8 * (pos2.x - pos1.x)
	var cam_y := pos2.y + 0.8 * (pos2.y - pos1.y)
	var frac := float(best) / float(_WIN)
	var cam_h := 10.0 * frac + (1.0 - frac) * 22.0
	var look := _spot(_me, mini(_WIN - 6, local_pos))
	_glide_camera(_panda(cam_x, cam_y, pos2.z + cam_h), _panda(look.x, look.y, look.z))


func _snap_camera(pos: Vector3, look: Vector3) -> void:
	_camera.position = pos
	_look = look
	_camera.look_at(look, Vector3.UP)
	_cam_from = pos
	_cam_to = pos
	_look_from = look
	_look_to = look
	_cam_age = 1.0


func _glide_camera(pos: Vector3, look: Vector3) -> void:
	_cam_from = _camera.position
	_look_from = _look
	_cam_to = pos
	_look_to = look
	_look = look
	_cam_age = 0.0


func _tick_camera(delta: float) -> void:
	if _cam_age >= 0.75:
		return
	_cam_age += delta
	var u := clampf(_cam_age / 0.75, 0.0, 1.0)
	_camera.position = _cam_from.lerp(_cam_to, u)
	_camera.look_at(_look_from.lerp(_look_to, u), Vector3.UP)


func _layout_buttons() -> void:
	if _buttons.is_empty() or _camera == null:
		return
	var depth := 1.7
	var half := depth * tan(deg_to_rad(_camera.fov * 0.5))
	var show := _phase == "pick" and not _picked
	for i in _buttons.size():
		var pivot := _buttons[i] as Node3D
		if pivot == null:
			continue
		pivot.visible = show
		var across := -0.9 + float(i) * 0.2
		pivot.position = Vector3(across * half, -0.85 * half, -depth)
		pivot.scale = Vector3.ONE * (0.25 * half)


func _paint_buttons() -> void:
	for i in _button_dice.size():
		var die = _button_dice[i]
		if not is_instance_valid(die):
			continue
		var token := "dice_button%d" % (i + 1)
		if _held == i + 1:
			token += "_down"
		elif _hover == i + 1:
			token += "_ro"
		_show_face(die, token)


func _die_at(mouse: Vector2) -> int:
	if _phase != "pick" or _picked or _camera == null:
		return 0
	var best := 0
	var best_d := 100000.0
	for i in _buttons.size():
		var pivot := _buttons[i] as Node3D
		if pivot == null or not pivot.visible:
			continue
		var center := _camera.unproject_position(pivot.global_position)
		var edge := _camera.unproject_position(pivot.global_position + pivot.global_basis.x * pivot.scale.x * 0.5)
		var radius := maxf(center.distance_to(edge), 24.0)
		var dist := center.distance_to(mouse)
		if dist <= radius and dist < best_d:
			best = i + 1
			best_d = dist
	return best


func _sync_clock() -> void:
	if _clock_face == null or _clock_num == null:
		return
	var show := playing and _phase == "pick" and not _picked
	_clock_face.visible = show
	_clock_num.visible = show
	if not show:
		return
	_layout_clock(true)
	var left := maxi(int(ceil(_left)), 0)
	var text_scale := 0.34 if str(left).length() <= 1 else 0.27
	var ink := Color(1.0, 0.0, 0.0) if left <= 5 else Color(0.0, 0.0, 0.0)
	ToonGui.style_label(_clock_num, ink, _font_px(text_scale * 0.45), Color(0.0, 0.0, 0.0, 0.0), 0)
	_clock_num.text = str(left)


func _stand(i: int) -> void:
	var actor = _racer(i)
	if actor == null:
		return
	var place := clampi(_pos[i], 0, _WIN)
	actor.global_position = _world(i, place)
	_face(actor, _spot(i, place).w)


func _face(actor: ToonActor, heading: float) -> void:
	if _track == null:
		return
	var h := deg_to_rad(heading)
	var forward := _track.global_transform.basis * Vector3(-sin(h), cos(h), 0.0)
	if forward.length_squared() < 0.0001:
		return
	actor.look_at(actor.global_position + forward, Vector3.UP)


func _world(lane: int, place: int) -> Vector3:
	if _track == null:
		return Vector3.ZERO
	var spot := _spot(lane, place)
	return _track.global_transform * Vector3(spot.x, spot.y, spot.z)


func _spot(lane: int, place: int) -> Vector4:
	var row: Array = _LANES[clampi(lane, 0, _LANES.size() - 1)]
	return row[clampi(place, 0, row.size() - 1)]


func _racer(i: int):
	if i < 0 or i >= _actors.size():
		return null
	var actor = _actors[i]
	if actor != null and is_instance_valid(actor) and actor is ToonActor:
		return actor
	return null


func _freq(picks: Array, choice: int) -> int:
	var count := 0
	for item in picks:
		if int(item) == choice:
			count += 1
	return count


func _blank() -> Array:
	var row: Array = []
	row.resize(_count)
	row.fill(-1)
	return row


func _show_face(root: Node, token: String) -> void:
	if root == null:
		return
	for number in range(1, 5):
		for suffix in ["", "_down", "_ro"]:
			var face := "dice_button%d%s" % [number, suffix]
			var piece := root.find_child(face, true, false)
			if piece != null:
				piece.visible = face == token


func _tint_die(root: Node, color: Color) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if not is_instance_valid(node) or not (node is MeshInstance3D):
			continue
		var mesh := node as MeshInstance3D
		if not mesh.visible:
			continue
		var current := mesh.get_active_material(0)
		var mat := StandardMaterial3D.new()
		if current is StandardMaterial3D:
			mat = (current as StandardMaterial3D).duplicate() as StandardMaterial3D
		mat.albedo_color = color
		mesh.material_override = mat


func _clear_dice() -> void:
	for die in _board_dice:
		if is_instance_valid(die):
			(die as Node).queue_free()
	_board_dice.clear()


func _panda_basis(heading: float, pitch: float, roll: float) -> Basis:
	var turn := Quaternion(Vector3(0.0, 0.0, 1.0), deg_to_rad(heading))
	var tilt := Quaternion(Vector3(1.0, 0.0, 0.0), deg_to_rad(pitch))
	var twist := Quaternion(Vector3(0.0, 1.0, 0.0), deg_to_rad(roll))
	return Basis(twist * tilt * turn)
