extends "res://scenes/trolley/trolley_minigame.gd"

## Tug-of-War. Alternate the arrow keys to match the climbing rate on the
## meter. The cog pushes back, and the side that slides into the middle falls
## in the water. The schedule, forces, and jellybeans are the original ones.

var _codes: PackedStringArray = PackedStringArray(["pp", "dt", "gh", "cr"])
var _rate_time := PackedFloat32Array([8, 5, 6, 6, 7, 8])
var _rate_goal := PackedInt32Array([6, 7, 8, 10, 11, 12])
var _suit_time := PackedFloat32Array([6, 2, 2, 3, 5, 8, 9, 4])
var _suit_force_plan := PackedFloat32Array([4, 5, 6.5, 8, 6, 8, 8.5, 9])
const _TUG_LENGTH := 18.0 / 24.0

var _cog: StreetCog
var _rope: MeshInstance3D
var _banner: Label
var _toon_spot := Vector3(-6.0, 18.0, 0.1)
var _cog_spot := Vector3(6.0, 18.0, 0.1)
var _suit_level := 1
var _beans := 1
var _suit_mult := 0.68
var _suit_force := 0.0
var _suit_index := 0
var _suit_left := 0.0
var _suit_clock := 0.0
var _rate_index := 0
var _rate_left := 0.0
var _ideal := 6
var _all_out := false
var _award := 0.0
var _force := 0.0
var _key_rate := 0
var _expect := 0
var _ttl := PackedFloat32Array()
var _rate_tick := 0.0
var _force_tick := 0.0
var _left_offset := 0.0
var _right_offset := 0.0
var _live := false
var _vs_cog := true
var _pull_scale := 0.02
var _advantage := 1.0
var _my_side := 0
var _wobbles := PackedFloat32Array()
var _mates: Array[ToonActor] = []
var _spots: Array[Vector3] = []
var _sides := PackedInt32Array()
var _rope_from := PackedInt32Array()
var _rope_to := PackedInt32Array()
var _rope_cross := PackedByteArray()
var _ropes: Array[MeshInstance3D] = []
var _fall_nodes: Array[Node3D] = []
var _fall_froms: Array[Vector3] = []
var _fall_tos: Array[Vector3] = []
var _suit_offset := 0.0
var _right_was := false
var _left_was := false
var _arrow_hot := -1
var _keys_on := false
var _pulling := false
var _warmup := 0.0
var _whistled := false
var _intro_t := 0.0
var _intro_done := false
var _closing := false
var _close_in := 0.0
var _falling := false
var _fall_t := 0.0
var _splashed := false
var _fall_who := 0
var _fall_from := Vector3.ZERO
var _fall_to := Vector3.ZERO
var _waters: Array[Vector3] = [
	Vector3(-0.2, 16.0, 0.0),
	Vector3(0.0, 18.0, 0.0),
	Vector3(0.2, 20.0, 0.0),
	Vector3(0.4, 22.0, 0.0),
]


func _init() -> void:
	title = "Tug-of-War"
	instructions = "Alternately tap the left and right arrow keys just fast enough to line up the green bar with the red line. Don't tap them too slow or too fast, or you'll end up in the water!"
	duration = 40.0


func begin() -> void:
	super.begin()
	_hold_clock = true
	_warmup = 3.0
	_intro_done = true
	_aim_game()
	_say("Ready...")
	if _board != null:
		_board.set_arrows(false, -1)
		_board.set_power(0.0, float(_ideal), false, _bar_color())


func _process(delta: float) -> void:
	if not playing:
		_ease_intro(delta)
	if _closing:
		_tick_close(delta)
		return
	super._process(delta)


func _build() -> void:
	var stage := _show("res://assets/minigames/tug_set.glb")
	_place_stage(stage)
	_suit_level = shared_int(4) + 1
	_beans = 1 << (_suit_level - 1)
	_deal_sides()
	_seat_toons()
	if _vs_cog:
		_summon_suit()
	elif _cog != null:
		_cog.visible = false
	_frame_camera()
	_make_rope(stage)
	_make_banner()
	show_board("power")
	if _remotes != null and is_instance_valid(_remotes):
		_remotes.queue_free()
		_remotes = null


func _play(delta: float) -> void:
	if _warmup > 0.0:
		_tick_warmup(delta)
		_pose_tug()
		_draw_rope(false)
		return
	_read_keys()
	_tick_rates(delta)
	_tick_suit_plan(delta)
	_tick_keys(delta)
	_tick_force(delta)
	_place_line()
	_pose_tug()
	_draw_rope(true)
	_show_meter()


func _end() -> void:
	if _over or _closing:
		return
	_keys_on = false
	if not _falling:
		score = _timeout_score()
		_say("Good game!")
	_closing = true
	_close_in = 4.8 if score <= 4 + _beans / 2 else 5.0
	_hold_clock = true


func _tick_warmup(delta: float) -> void:
	_warmup -= delta
	if _warmup <= 1.5 and not _whistled:
		_whistled = true
		_sfx("AA_sound_whistle")
		_say("GO!")
	if _warmup > 0.0:
		return
	_warmup = 0.0
	_hold_clock = false
	_keys_on = true
	_say("")
	_rate_index = 0
	_ideal = _rate_goal[0]
	_rate_left = _rate_time[0]
	_all_out = false
	_suit_index = 0
	_roll_suit_force()
	_suit_left = _suit_time[0]
	if _board != null:
		_board.set_arrows(true, -1)


func _tick_close(delta: float) -> void:
	_close_in -= delta
	if _falling:
		_fall_t += delta
		var weight := clampf(_fall_t / 2.0, 0.0, 1.0)
		for index in _fall_nodes.size():
			var body := _fall_nodes[index]
			if body == null or not is_instance_valid(body):
				continue
			body.position = _fall_froms[index].lerp(_fall_tos[index], weight)
			if body is ToonActor:
				var actor := body as ToonActor
				var slip := actor.action_length("slip-forward")
				if slip > 0.0:
					actor.pose_action("slip-forward", weight * slip)
			elif body is StreetCog:
				(body as StreetCog).play_attack("slip-forward", _fall_t * 2.2)
		if _fall_t >= 1.0 and not _splashed:
			_splashed = true
			_sfx("MG_cannon_splash")
	if _won() and _toon != null and not _fall_nodes.has(_toon):
		_toon.pose_synced_loop("victory")
	_draw_rope(true)
	if _close_in <= 0.0:
		_closing = false
		super._end()


func _read_keys() -> void:
	if not _keys_on:
		return
	var right_down := Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT)
	var left_down := Input.is_physical_key_pressed(KEY_LEFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT)
	if right_down and not _right_was:
		_press(0)
	if left_down and not _left_was:
		_press(1)
	if _arrow_hot == 0 and not right_down:
		_arrow_hot = -1
	elif _arrow_hot == 1 and not left_down:
		_arrow_hot = -1
	_right_was = right_down
	_left_was = left_down
	if _board != null:
		_board.set_arrows(true, _arrow_hot)


func _press(index: int) -> void:
	if index != _expect:
		return
	_ttl.append(1.0)
	_expect = 1 - _expect
	_arrow_hot = index


func _tick_keys(delta: float) -> void:
	_rate_tick += delta
	while _rate_tick >= 0.1:
		_rate_tick -= 0.1
		var kept := PackedFloat32Array()
		for index in _ttl.size():
			var left := _ttl[index] - 0.1
			if left > 0.0:
				kept.append(left)
		_ttl = kept
		_key_rate = _ttl.size()
		if not _all_out and (_key_rate == _ideal or _key_rate == _ideal + 1):
			_award += 0.3
		else:
			_award = 0.0


func _tick_rates(delta: float) -> void:
	_rate_left -= delta
	if _rate_left > 0.0 or _rate_index >= _rate_goal.size() - 1:
		return
	_rate_index += 1
	_ideal = _rate_goal[_rate_index]
	_rate_left += _rate_time[_rate_index]
	if _rate_index == _rate_goal.size() - 1:
		_all_out = true


func _tick_suit_plan(delta: float) -> void:
	_suit_left -= delta
	if _suit_left > 0.0 or _suit_index >= _suit_time.size() - 1:
		return
	_suit_index += 1
	_roll_suit_force()
	_suit_left += _suit_time[_suit_index]


func _roll_suit_force() -> void:
	var wobble := 0.0
	if _live and _suit_index < _wobbles.size():
		wobble = _wobbles[_suit_index]
	else:
		wobble = shared_float(-0.5, 0.5)
	var players := float(maxi(party_size(), 1))
	_suit_force = _suit_mult * players * (_suit_force_plan[_suit_index] + wobble)


func _tick_force(delta: float) -> void:
	_force_tick += delta
	if _live and party_index() != 0:
		_apply_line()
		_watch_tow()
	if _force_tick < 0.2:
		return
	_force_tick -= 0.2
	_measure_force()
	_send_pull()
	if _live and party_index() != 0:
		return
	var sides := _side_forces()
	var delta_x := (sides.y - sides.x) * _pull_scale
	if delta_x < 0.0:
		_left_offset += delta_x * 0.5
		_right_offset += delta_x
		_suit_offset += delta_x
	else:
		_left_offset += delta_x
		_right_offset += delta_x * 0.5
		_suit_offset += delta_x * 0.5
	_place_line()
	_send_line()
	_check_fall()


func _measure_force() -> void:
	if _all_out:
		_force = 0.75 * float(_key_rate)
	else:
		var spread := 0.25 * float(_ideal)
		var miss := float(_key_rate - _ideal)
		var curve := exp(-(miss * miss) / (2.0 * spread * spread))
		_force = _advantage * (_award + 4.0 + 0.4 * float(_ideal)) * curve


func _side_forces() -> Vector2:
	var left_f := 0.0
	var right_f := 0.0
	if not _live:
		left_f = _force
	else:
		var reports: Dictionary = {}
		var raw: Variant = ToonNet.minigame_state().get("tugs", {})
		if raw is Dictionary:
			reports = raw
		for index in party_size():
			var pull := _force
			if index != party_index():
				pull = _unpack_force(int(reports.get(str(party_peer(index)), -1)))
			if index < _sides.size() and _sides[index] == 0:
				left_f += pull
			else:
				right_f += pull
	if _vs_cog:
		right_f += _suit_force
	return Vector2(left_f, right_f)


func _send_pull() -> void:
	if not _live:
		return
	var rate := clampi(_key_rate, 0, 31)
	var packed := clampi(int(round(_force * 10.0)), 0, 4095)
	ToonNet.note_minigame("tug", rate | (packed << 5))


func _send_line() -> void:
	if not _live or party_index() != 0:
		return
	var left := clampi(int(round(_left_offset * 100.0)), -30000, 30000) + 32768
	var right := clampi(int(round(_right_offset * 100.0)), -30000, 30000) + 32768
	var suit := clampi(int(round(_suit_offset * 100.0)), -30000, 30000) + 32768
	ToonNet.note_minigame("line", left | (right << 16) | (suit << 32))


func _apply_line() -> void:
	var packed := int(ToonNet.minigame_state().get("line", 0))
	if packed == 0:
		return
	_left_offset = float((packed & 65535) - 32768) / 100.0
	_right_offset = float(((packed >> 16) & 65535) - 32768) / 100.0
	_suit_offset = float(((packed >> 32) & 65535) - 32768) / 100.0
	_place_line()


func _watch_tow() -> void:
	var who := int(ToonNet.minigame_state().get("tow", 0))
	if who > 0:
		_start_fall(who)


func _unpack_force(packed: int) -> float:
	if packed < 0:
		return 0.0
	return float((packed >> 5) & 4095) / 10.0


func _over_middle(x: float) -> bool:
	return (x < 0.0 and x > -2.0) or (x > 0.0 and x < 2.0)


func _check_fall() -> void:
	if _vs_cog and _cog != null and _over_middle(_feet_x(_cog_spot.x, _suit_offset, false)):
		_start_fall(1)
		return
	for index in _spots.size():
		var offset := _left_offset if _sides[index] == 0 else _right_offset
		if _over_middle(_feet_x(_spots[index].x, offset, true)):
			_start_fall(2 if _sides[index] == 0 else 3)
			return


func _feet_x(spot: float, offset: float, handicap: bool) -> float:
	if handicap:
		return spot + offset / 2.0
	return spot + offset


func _start_fall(who: int) -> void:
	if _falling:
		return
	_falling = true
	_keys_on = false
	_fall_who = who
	_fall_t = 0.0
	score = _payout(true)
	_say("Good game!")
	if _live and party_index() == 0:
		ToonNet.note_minigame("tow", who)
	_queue_fall(who)
	_end()


func _queue_fall(who: int) -> void:
	for index in _mates.size():
		var loser := (who == 2 and _sides[index] == 0) or (who == 3 and _sides[index] == 1)
		if not loser:
			continue
		var actor := _mates[index]
		if actor == null:
			continue
		_fall_nodes.append(actor)
		_fall_froms.append(actor.position)
		_fall_tos.append(_water_at(3.5))
	if who == 1 and _cog != null:
		_fall_nodes.append(_cog)
		_fall_froms.append(_cog.position)
		_fall_tos.append(_water_at(float(_cog.height) / 1.5))


func _water_at(sink: float) -> Vector3:
	var water := Vector3(0.4, 22.0, 0.0)
	if not _waters.is_empty():
		water = _waters[_waters.size() - 1]
		_waters.remove_at(_waters.size() - 1)
	return _panda(water.x, water.y, -sink)


func _timeout_score() -> int:
	return _payout(false)


func _payout(fell: bool) -> int:
	if _vs_cog:
		var won := _fall_who == 1 if fell else -_left_offset > _suit_offset
		if won:
			return _beans + 15 if fell else int(round(float(_beans) * 0.5 + 12.0))
		return 4 if fell else int(round(float(_beans) * 0.5 + 8.0))
	var mine := -_left_offset if _my_side == 0 else _right_offset
	var other := _right_offset if _my_side == 0 else -_left_offset
	if fell:
		var lost := (_my_side == 0 and _fall_who == 2) or (_my_side == 1 and _fall_who == 3)
		return 4 if lost else 15
	if absf(mine - other) < 0.001:
		return 5
	return 12 if mine > other else 8


func _place_line() -> void:
	if _falling:
		return
	for index in _mates.size():
		var actor := _mates[index]
		if actor == null or index >= _spots.size():
			continue
		var offset := _left_offset if _sides[index] == 0 else _right_offset
		var spot := _spots[index]
		actor.position = _panda(_feet_x(spot.x, offset, true), spot.y, spot.z)
	if _cog != null and _vs_cog:
		_cog.position = _panda(_feet_x(_cog_spot.x, _suit_offset, false), _cog_spot.y, _cog_spot.z)


func _pose_tug() -> void:
	for index in _mates.size():
		var actor := _mates[index]
		if actor == null:
			continue
		var slipping := _falling and _fall_nodes.has(actor)
		if slipping:
			continue
		var rate := _key_rate if index == party_index() else _remote_rate(index)
		if _keys_on and rate > 0:
			actor.pose_synced_loop("tug-o-war")
		else:
			actor.pose_action("tug-o-war", 3.0 / 24.0)
	_pulling = _keys_on and _key_rate > 0
	if _cog == null or not _vs_cog or (_falling and _fall_who == 1):
		return
	if _keys_on:
		_suit_clock = fposmod(_suit_clock + get_process_delta_time(), _TUG_LENGTH)
		_cog.play_attack("tug-o-war", _suit_clock)
	else:
		_cog.play_attack("tug-o-war", 0.0)


func _remote_rate(index: int) -> int:
	var raw: Variant = ToonNet.minigame_state().get("tugs", {})
	if raw is Dictionary:
		var packed := int((raw as Dictionary).get(str(party_peer(index)), 0))
		return packed & 31
	return 0


func _show_meter() -> void:
	if _board == null:
		return
	_board.set_power(float(_key_rate), float(_ideal), _all_out, _bar_color())


func _bar_color() -> Color:
	if _all_out:
		return Color(0, 1, 0, 0.5)
	var ideal_force := 4.0 + 0.4 * float(_ideal)
	var index := 0.0 if ideal_force <= 0.0 else _force / ideal_force
	var bonus := 0.0
	if index > 1.0:
		bonus = maxf(1.0, index - 1.0)
		index = 1.0
	var green := clampf(0.75 * index + 0.25 * bonus, 0.0, 1.0)
	var blue := clampf(0.75 * (1.0 - index), 0.0, 1.0)
	return Color(0.0, green, blue, 0.5)


func _summon_suit() -> void:
	var code := _codes[_suit_level - 1]
	_cog = StreetCog.new()
	add_child(_cog)
	var timing: Dictionary = {
		"a": {"tug-o-war": {"fps": 24.0}, "slip-forward": {"fps": 24.0}},
		"b": {"tug-o-war": {"fps": 24.0}, "slip-forward": {"fps": 24.0}},
		"c": {"tug-o-war": {"fps": 24.0}, "slip-forward": {"fps": 24.0}},
	}
	_cog.present(_suit_row(code), timing)
	_cog.set_process(false)
	_cog.set_physics_process(false)
	_cog.position = _panda(_cog_spot.x, _cog_spot.y, _cog_spot.z)
	_cog.rotation_degrees.y = 120.0
	_cog.play_attack("tug-o-war", 0.0)


func _suit_row(code: String) -> Dictionary:
	for item in CogCatalog.cog_rows():
		if item is Dictionary and String((item as Dictionary).get("code", "")) == code:
			var copy: Dictionary = (item as Dictionary).duplicate()
			return copy
	return {"code": code, "name": code, "dept": "c", "body": "c", "height": 4.0}


func _place_stage(stage: Node3D) -> void:
	if stage == null:
		return
	var dock: Node3D = stage.find_child("tug_of_war_dock.egg", true, false) as Node3D
	if dock != null:
		dock.position = Vector3(0.0, 18.39, -0.025)
		dock.scale = Vector3(0.4, 0.4, 0.4)
	var card: Node3D = stage.find_child("tug_of_war_rope.egg", true, false) as Node3D
	if card != null:
		card.visible = false
	var sky: Node3D = stage.find_child("TT_sky.egg", true, false) as Node3D
	if sky != null:
		sky.position = Vector3(0.0, 0.0, -5.0)


func _deal_sides() -> void:
	var count := party_size()
	_live = count > 1
	_vs_cog = true
	_pull_scale = 0.02
	_suit_mult = 0.58 + float(_suit_level) / 10.0
	if _live:
		_vs_cog = shared_int(10) < 8
		_suit_mult = 0.65 + float(_suit_level) / 16.0
		if not _vs_cog:
			_pull_scale = 0.04
		for _step in 8:
			_wobbles.append(shared_float(-0.5, 0.5))
	var order: Array[int] = []
	for index in count:
		order.append(index)
	if _live and not _vs_cog:
		var mixed: Array = []
		for index in order:
			mixed.append(index)
		shared_shuffle(mixed)
		order.clear()
		for item in mixed:
			order.append(int(item))
	var slots := _slot_list(count)
	_spots.clear()
	_sides.clear()
	_spots.resize(count)
	_sides.resize(count)
	for index in count:
		var who := order[index]
		var x := _dock_x(slots[index])
		_spots[who] = Vector3(x, 18.0, 0.1)
		_sides[who] = 0 if x < 0.0 else 1
	_my_side = _sides[clampi(party_index(), 0, count - 1)]
	_toon_spot = _spots[clampi(party_index(), 0, count - 1)]
	var lefts := 0
	for side in _sides:
		if side == 0:
			lefts += 1
	var rights := count - lefts
	_advantage = 1.0
	if not _vs_cog and count == 3 and ((_my_side == 0 and lefts == 1) or (_my_side == 1 and rights == 1)):
		_advantage = 2.0
	var suit_slot := 6 if _vs_cog and count >= 4 else 7
	_cog_spot = Vector3(_dock_x(suit_slot), 18.0, 0.1)


func _slot_list(count: int) -> PackedInt32Array:
	if _vs_cog:
		if count <= 1:
			return PackedInt32Array([2])
		if count == 2:
			return PackedInt32Array([1, 2])
		if count == 3:
			return PackedInt32Array([0, 1, 2])
		return PackedInt32Array([0, 1, 2, 3])
	if count <= 2:
		return PackedInt32Array([2, 7])
	if count == 3:
		return PackedInt32Array([1, 2, 7])
	return PackedInt32Array([1, 2, 7, 8])


func _seat_toons() -> void:
	var me := clampi(party_index(), 0, _spots.size() - 1)
	_toon_spot = _spots[me]
	var rider := _make_toon(_panda(_toon_spot.x, _toon_spot.y, _toon_spot.z))
	_prep_toon(rider, _my_side)
	_mates.resize(_spots.size())
	_mates[me] = rider
	for index in _spots.size():
		if index == me:
			continue
		var actor := ToonActor.new()
		add_child(actor)
		var dressed := _style_for(index)
		actor.show_style(dressed)
		actor.name = dressed.display_name()
		var cards: Array = _RIDE.riders
		if index < cards.size():
			var card: Dictionary = cards[index]
			var worn: Variant = card.get("accessories", {})
			if worn is Dictionary and not (worn as Dictionary).is_empty():
				actor.wear_accessories(worn)
		if _tags != null:
			_tags.add(actor, party_name(index), "player")
		_prep_toon(actor, _sides[index])
		var spot := _spots[index]
		actor.position = _panda(spot.x, spot.y, spot.z)
		_mates[index] = actor


func _prep_toon(actor: ToonActor, side: int) -> void:
	actor.rotation_degrees.y = 240.0 if side == 0 else 120.0
	actor.ensure_clip("slip-forward")
	actor.ensure_clip("victory")
	actor.ensure_clip("tug-o-war")
	actor.pose_action("tug-o-war", 3.0 / 24.0)


func _style_for(index: int) -> ToonStyle:
	var cards: Array = _RIDE.riders
	if index >= 0 and index < cards.size():
		var card: Dictionary = cards[index]
		var raw: Variant = card.get("style", {})
		if raw is Dictionary and (raw as Dictionary).has("head"):
			return ToonStyle.from_dict(raw)
	return ToonStyle.random_named("f" if index % 2 == 0 else "m")


func _won() -> bool:
	if _fall_who == 1:
		return true
	if _fall_who == 2:
		return _my_side == 1
	if _fall_who == 3:
		return _my_side == 0
	if _vs_cog:
		return -_left_offset > _suit_offset
	var mine := -_left_offset if _my_side == 0 else _right_offset
	var other := _right_offset if _my_side == 0 else -_left_offset
	return mine > other


func _dock_x(slot: int) -> float:
	if slot < 5:
		return -9.0 + 1.5 * float(slot)
	return 3.0 + 1.5 * float(slot - 5)


func _frame_camera() -> void:
	var players := maxi(party_size(), 1)
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = 60.0 + 2.0 * float(players)
	_aim_game()


func _ease_intro(delta: float) -> void:
	if _intro_done or _camera == null:
		return
	_intro_t += delta
	var weight := clampf(_intro_t / 8.0, 0.0, 1.0)
	weight = weight * weight * (3.0 - 2.0 * weight)
	var from_pos := _panda(-11.4427, 9.03559, 2.80094)
	var to_pos := _panda(0.0, 1.0838, 2.745)
	var from_look := _look_point(-11.4427, 9.03559, 2.80094, -49.104, -0.732374)
	var to_look := _look_point(0.0, 1.0838, 2.745, -1.13, 1.042)
	_camera.position = from_pos.lerp(to_pos, weight)
	_camera.look_at(from_look.lerp(to_look, weight), Vector3.UP)
	if _intro_t >= 8.0:
		_intro_done = true


func _aim_game() -> void:
	if _camera == null:
		return
	_camera.position = _panda(0.0, 1.0838, 2.745)
	_camera.look_at(_look_point(0.0, 1.0838, 2.745, -1.13, 1.042), Vector3.UP)


func _look_point(x: float, y: float, z: float, heading_deg: float, pitch_deg: float) -> Vector3:
	var heading := deg_to_rad(heading_deg)
	var pitch := deg_to_rad(pitch_deg)
	var level := cos(pitch)
	return _panda(x + -sin(heading) * level * 40.0, y + cos(heading) * level * 40.0, z + sin(pitch) * 40.0)


func _make_banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_banner)
	ToonGui.style_sign(_banner, Color(0.95, 0.95, 0.2), 72, Color(0, 0, 0, 1), 6)
	_banner.text = ""


func _say(text: String) -> void:
	if _banner != null:
		_banner.text = text


func _make_rope(stage: Node3D) -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.89, 0.89, 0.6)
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	if stage != null:
		var card: MeshInstance3D = stage.find_child("GS_rope", true, false) as MeshInstance3D
		if card != null:
			var source := card.get_active_material(0) as StandardMaterial3D
			if source != null:
				paint.albedo_texture = source.albedo_texture
	var order: Array[int] = []
	for index in _spots.size():
		order.append(index)
	for left in order.size():
		for right in range(left + 1, order.size()):
			if _spots[order[right]].x < _spots[order[left]].x:
				var swap := order[left]
				order[left] = order[right]
				order[right] = swap
	var last_left := -1
	var first_right := -1
	var prev_right := -1
	for who in order:
		if _sides[who] == 0:
			if last_left >= 0:
				_link(last_left, who, false, paint)
			last_left = who
		else:
			if first_right < 0:
				first_right = who
			else:
				_link(prev_right, who, false, paint)
			prev_right = who
	if _vs_cog and last_left >= 0:
		_link(last_left, -1, true, paint)
	elif last_left >= 0 and first_right >= 0:
		_link(last_left, first_right, true, paint)
	_draw_rope(false)


func _link(a: int, b: int, cross: bool, paint: Material) -> void:
	var rope := MeshInstance3D.new()
	rope.name = "TugRope"
	rope.material_override = paint
	rope.mesh = ImmediateMesh.new()
	add_child(rope)
	_ropes.append(rope)
	_rope_from.append(a)
	_rope_to.append(b)
	_rope_cross.append(1 if cross else 0)


func _draw_rope(taut: bool) -> void:
	var sag := _panda(0.0, 18.0, -1.0)
	for index in _ropes.size():
		var rope := _ropes[index]
		var mesh := rope.mesh as ImmediateMesh
		if mesh == null:
			continue
		var start_at := _hand(_rope_from[index])
		var finish_at := _hand(_rope_to[index])
		var mid_at := start_at
		if _rope_cross[index] == 1 and not taut:
			mid_at = to_global(sag)
		var start := rope.to_local(start_at)
		var finish := rope.to_local(finish_at)
		var mid := rope.to_local(mid_at)
		mesh.clear_surfaces()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		var steps := 8
		for step in steps:
			var t0 := float(step) / float(steps)
			var t1 := float(step + 1) / float(steps)
			_band(mesh, _bend(start, mid, finish, t0), _bend(start, mid, finish, t1), 0.1, t0, t1)
		mesh.surface_end()


func _hand(index: int) -> Vector3:
	if index < 0:
		return _grip(_cog, "joint_Rhold") if _cog != null else Vector3.ZERO
	if index < _mates.size() and _mates[index] != null:
		return _grip(_mates[index], "def_joint_right_hold")
	return Vector3.ZERO


func _grip(body: Node3D, joint_name: String) -> Vector3:
	var joint: Node3D = body.find_child(joint_name, true, false) as Node3D
	if joint != null:
		return joint.global_position
	return body.global_position + Vector3(0.0, 1.2, 0.0)


func _bend(start: Vector3, sag: Vector3, finish: Vector3, t: float) -> Vector3:
	var stay := 1.0 - t
	return start * stay * stay + sag * 2.0 * stay * t + finish * t * t


func _band(mesh: ImmediateMesh, a: Vector3, b: Vector3, radius: float, u0: float, u1: float) -> void:
	var forward := b - a
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var side := forward.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized() * radius
	var up := forward.cross(side.normalized()) * radius
	_quad(mesh, a - side, a + side, b + side, b - side, u0, u1)
	_quad(mesh, a - up, a + up, b + up, b - up, u0, u1)


func _quad(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, d: Vector3, u0: float, u1: float) -> void:
	mesh.surface_set_uv(Vector2(u0, 0.0))
	mesh.surface_add_vertex(a)
	mesh.surface_set_uv(Vector2(u0, 1.0))
	mesh.surface_add_vertex(b)
	mesh.surface_set_uv(Vector2(u1, 1.0))
	mesh.surface_add_vertex(c)
	mesh.surface_set_uv(Vector2(u0, 0.0))
	mesh.surface_add_vertex(a)
	mesh.surface_set_uv(Vector2(u1, 1.0))
	mesh.surface_add_vertex(c)
	mesh.surface_set_uv(Vector2(u1, 0.0))
	mesh.surface_add_vertex(d)
