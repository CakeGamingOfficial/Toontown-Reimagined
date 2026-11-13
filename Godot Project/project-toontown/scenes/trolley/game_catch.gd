extends "res://scenes/trolley/trolley_minigame.gd"

## Catching Game. Walk the treehouse in both directions. Fruit falls from above
## onto the drop grid, anvils fall faster and knock you forward, and Cogs walk
## across and knock you back. The fruit follows the playground. The jellybean
## count is half the catches, at least one, plus a quarter of the fruit on a
## perfect round. The ride still applies the playground multiplier.

const _FRUIT := {
	2000: "apple",
	1000: "orange",
	5000: "pear",
	4000: "coconut",
	3000: "watermelon",
	9000: "pineapple",
}
const _PLURAL := {
	"apple": "apples",
	"orange": "oranges",
	"pear": "pears",
	"coconut": "coconuts",
	"watermelon": "watermelons",
	"pineapple": "pineapples",
}
const _SCALE := {
	"apple": 0.7,
	"orange": 0.7,
	"pear": 0.5,
	"coconut": 0.7,
	"watermelon": 0.6,
	"pineapple": 0.45,
	"anvil": 1.0,
}
# RegionDropPlacer tables for one or two players, then three or four.
const _TABLES: Array = [
	[[1, 1, 2, 3, 3], [1, 1, 2, 3, 3], [0, 1, 2, 3, 4], [0, 1, 2, 3, 4], [0, 1, 2, 3, 4]],
	[[1, 2, 2, 3, 3, 4], [1, 1, 2, 3, 4, 4], [1, 1, 2, 3, 4, 4], [0, 1, 2, 3, 4, 5], [0, 1, 2, 3, 4, 5], [0, 1, 2, 3, 4, 5]],
]
const _SUITS: PackedStringArray = ["f", "tm", "pp", "dt"]
const _SHADOW_TEX := preload("res://assets/neighborhoods/toontown_central/props/drop_shadow.png")

var _fruit := "apple"
var _players := 1
var _difficulty := 0.0
var _toon_speed := 16.0
var _suit_speed := 8.0
var _suit_gap := 5.0
var _half_w := 10.0
var _half_h := 7.5
var _height := 24.0
var _onscreen := 2.0
var _offscreen := 2.0
var _baseline := 4.0
var _drop_period := 2.0
var _cols := 5
var _rows := 5
var _num_fruits := 0
var _px := 0.0
var _py := 0.0
var _down := 0.0
var _fall := ""
var _fell := false
var _elapsed := 0.0
var _left := 55.0
var _clock_hidden := false
var _closing := false
var _hold_end := 0.0
var _team_fruit := 0
var _counted: Dictionary = {}
var _payout := 1
var _heading := 180.0
var _rest_heading := 180.0
var _turn_from := 180.0
var _turn_to := 180.0
var _turn_left := 0.0
var _turn_dur := 0.0
var _last_ix := 0
var _last_iy := 0
var _rest_wait := 0.0
var _pending_rest := 180.0
var _drops: Array[Dictionary] = []
var _walks: Array[Dictionary] = []
var _cogs: Array[Node3D] = []
var _cog_free: Array[float] = []
var _gone: Dictionary = {}
var _perfect: Label


func _init() -> void:
	title = "Catching Game"
	duration = 55.0
	_left = 55.0


func _build() -> void:
	_players = clampi(party_size(), 1, 4)
	var hood := int(_RIDE.hood)
	if not _FRUIT.has(hood):
		hood = 2000
	_fruit = String(_FRUIT[hood])
	_difficulty = float(_RIDE._ZONES.find(hood)) / float(_RIDE._ZONES.size() - 1)
	instructions = "Catch as many %s as you can. Watch out for the Cogs, and try not to 'catch' any anvils!" % _PLURAL[_fruit]
	_constants()
	var house := "res://assets/minigames/treehouse.glb"
	if _players >= 4 and ResourceLoader.exists("res://assets/minigames/treehouse_4players.glb"):
		house = "res://assets/minigames/treehouse_4players.glb"
	elif _players == 3 and ResourceLoader.exists("res://assets/minigames/treehouse_3players.glb"):
		house = "res://assets/minigames/treehouse_3players.glb"
	_show(house)
	_schedule()
	_ready_cogs()
	_px = lineup_x(4.0)
	_py = 0.0
	var toon := _make_toon(_panda(_px, _py, 0.0))
	toon.rotation_degrees.y = 180.0
	_aim_camera()
	show_board("avatar")
	_perfect = Label.new()
	_perfect.text = "PERFECT!"
	_perfect.visible = false
	_perfect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_perfect.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_perfect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.get_parent().add_child(_perfect)


func _process(delta: float) -> void:
	_place_tags()
	if not playing or _over:
		return
	if _left > 0.0:
		_left -= delta
		duration = maxf(_left, 0.0)
		_layout_clock(false)
	elif not _clock_hidden:
		_clock_hidden = true
		duration = 0.0
		_clock_face.visible = false
		_clock_num.visible = false
	_play(delta)
	_note_rider(delta)
	if _over or not is_inside_tree():
		return
	if _board != null:
		_board.sync(score)


func _play(delta: float) -> void:
	_elapsed += delta
	_sync_fruit()
	if _closing:
		_hold_end -= delta
		_animate_perfect()
		if _hold_end <= 0.0:
			score = _payout
			_end()
		return
	_move_toon(delta)
	_move_cogs(delta)
	_move_drops()
	if _drops_finished():
		_begin_ending()


func _constants() -> void:
	_toon_speed = lerpf(16.0, 25.0, _difficulty)
	_suit_speed = _toon_speed / 2.0
	_suit_gap = lerpf(5.0, 3.0, _difficulty)
	var area := float([1.0, 1.0, 3.0 / 2.0, 2.0][_players - 1])
	var linear := sqrt(area)
	_half_w = 20.0 * linear / 2.0
	_half_h = 15.0 * linear / 2.0
	_height = [24.0, 24.0, 26.0, 28.0][_players - 1]
	var span := sqrt(pow(_half_w * 2.0, 2.0) + pow(_half_h * 2.0, 2.0)) / linear
	var run := span / _toon_speed
	var fraction := (1.0 / 3.0) * 0.85
	_onscreen = run / (fraction * 2.0)
	_offscreen = _onscreen
	_baseline = _onscreen + _offscreen
	var scaled := (float(_players) - 1.0) * 0.75 + 1.0
	_drop_period = (_baseline / 2.0) / scaled
	var grid := int([5, 5, 6, 7][_players - 1])
	_cols = grid
	_rows = grid


func _period_at(t: float) -> float:
	if t >= float(int(2.0 / 3.0 * 55.0)):
		return _drop_period * 0.5
	return _drop_period


func _schedule() -> void:
	var count := 0
	var cursor := 0.5
	while cursor + _baseline < 55.0 + _period_at(cursor):
		count += 1
		cursor += _period_at(cursor)
	_num_fruits = int(float(count) * 0.75)
	var names: Array = []
	for _i in _num_fruits:
		names.append(_fruit)
	for _i in count - _num_fruits:
		names.append("anvil")
	shared_shuffle(names)
	var table: Array = _TABLES[0 if _players < 3 else 1]
	var cells := {}
	for row in table.size():
		var line: Array = table[row]
		for column in line.size():
			var region := int(line[column])
			if not cells.has(region):
				cells[region] = []
			(cells[region] as Array).append([row, column])
	var regions: Array[int] = []
	for key in cells.keys():
		regions.append(int(key))
	regions.sort()
	var empty := regions.duplicate()
	var falling: Array = []
	var when := 0.5
	for index in names.size():
		var still: Array = []
		for item in falling:
			if float(item[0]) > when:
				still.append(item)
			elif not empty.has(int(item[1])):
				empty.append(int(item[1]))
		falling = still
		var choices: Array = empty if not empty.is_empty() else regions
		var region := int(choices[shared_int(choices.size())])
		var spots: Array = cells[region]
		var spot: Array = spots[shared_int(spots.size())]
		# grid2world receives the table row as the column, then the table column as the row.
		var pos := _grid(int(spot[0]), int(spot[1]))
		var kind := String(names[index])
		_drops.append({
			"t": when,
			"kind": kind,
			"x": pos.x,
			"y": pos.y,
			"onscreen": _onscreen * (0.4 if kind == "anvil" else 1.0),
			"born": false,
			"done": false,
			"id": index,
			"node": null,
			"shadow": null,
			"model": null,
		})
		falling.append([when + _baseline, region])
		empty.erase(region)
		when += _period_at(when)
	_schedule_suits()


func _schedule_suits() -> void:
	var margin := float([2.5, 2.5, 2.3, 2.1][_players - 1])
	var delay := 0.0
	var planned: Array[Dictionary] = []
	while delay < 55.0:
		delay += _suit_gap
		# The original lerps the gap from the minimum period to itself, so the random is spent.
		shared_float(0.0, 1.0)
		var y1 := lerpf(-_half_h, _half_h, shared_float(0.0, 1.0))
		var y2 := lerpf(-_half_h, _half_h, shared_float(0.0, 1.0))
		var start := Vector2(-_half_w * margin, y1)
		var stop := Vector2(_half_w * margin, y2)
		if shared_int(2) == 1:
			var swap := start
			start = stop
			stop = swap
		planned.append({
			"t": delay,
			"from": start,
			"to": stop,
			"dur": start.distance_to(stop) / _suit_speed,
			"cog": -1,
		})
	var free: Array[float] = []
	for _i in _SUITS.size():
		free.append(-1.0)
	for walk in planned:
		var start_t := float(walk["t"])
		var open: Array[int] = []
		for index in free.size():
			if free[index] <= start_t:
				open.append(index)
		if open.is_empty():
			continue
		var pick := open[shared_int(open.size())]
		walk["cog"] = pick
		free[pick] = start_t + float(walk["dur"])
		_walks.append(walk)
	for drop in _drops:
		drop["h"] = _fruit_heading(String(drop["kind"]))


func _ready_cogs() -> void:
	# DistributedCatchGame loops walk at SuitSpeed / SuitWalkSpeed.
	var rate := 24.0 * (_suit_speed / StreetCog.WALK_SPEED)
	var timing: Dictionary = {
		"a": {"walk": {"fps": rate}},
		"b": {"walk": {"fps": rate}},
		"c": {"walk": {"fps": rate}},
	}
	for kind in _SUITS:
		var cog := StreetCog.new()
		add_child(cog)
		cog.present(_suit_row(kind), timing)
		# Off a street, the suit turns itself back on every frame.
		cog.set_process(false)
		cog.visible = false
		_cogs.append(cog)
		_cog_free.append(-1.0)


func _suit_row(code: String) -> Dictionary:
	for item in CogCatalog.cog_rows():
		if item is Dictionary and String((item as Dictionary).get("code", "")) == code:
			return (item as Dictionary).duplicate()
	return {"code": code, "name": code, "dept": "c", "body": "c", "height": 4.0}


func _move_toon(delta: float) -> void:
	var raw := _stick()
	var wish := raw
	if wish.length() > 1.0:
		wish = wish.normalized()
	if _down > 0.0:
		_down -= delta
		# CatchGameToonSD plays slip-backward or slip-forward from frame 12
		# through the last frame, squeezed into this one second.
		var last := _toon.action_length(_fall) * 24.0
		if last >= 12.0:
			var along := 1.0 - clampf(_down, 0.0, 1.0)
			_toon.pose_action(_fall, lerpf(12.0, last, along) / 24.0)
		_fell = true
		wish = Vector2.ZERO
		raw = Vector2.ZERO
	elif _fell:
		_fell = false
		_toon.release_pose()
	if _down <= 0.0:
		_px = clampf(_px + wish.x * _toon_speed * delta, -_half_w, _half_w)
		_py = clampf(_py + wish.y * _toon_speed * delta, -_half_h, _half_h)
		_face_input(raw, delta)
		_apply_turn(delta)
	_toon.position = _panda(_px, _py, 0.0)
	if _down <= 0.0:
		_toon.set_locomotion(9.0 if wish.length_squared() > 0.01 else 0.0, false, false, delta)
	_bump_cog()


func _face_input(raw: Vector2, delta: float) -> void:
	var ix := int(signf(raw.x)) if absf(raw.x) > 0.1 else 0
	var iy := int(signf(raw.y)) if absf(raw.y) > 0.1 else 0
	if _rest_wait > 0.0:
		_rest_wait -= delta
		if _rest_wait <= 0.0:
			_rest_heading = _pending_rest
	if ix == _last_ix and iy == _last_iy:
		return
	if ix == 0 and iy == 0:
		_aim_heading(_rest_heading)
	else:
		var cur := _cardinal(ix, iy)
		var was_diag := _last_ix != 0 and _last_iy != 0
		var now_diag := ix != 0 and iy != 0
		if was_diag and not now_diag:
			_rest_wait = 0.05
			_pending_rest = cur
		else:
			_rest_heading = cur
		_aim_heading(cur)
	_last_ix = ix
	_last_iy = iy


func _cardinal(ix: int, iy: int) -> float:
	if ix == 0 and iy > 0:
		return 0.0
	if ix == 0 and iy < 0:
		return 180.0
	if ix > 0 and iy == 0:
		return -90.0
	if ix < 0 and iy == 0:
		return 90.0
	if ix > 0 and iy > 0:
		return -45.0
	if ix < 0 and iy > 0:
		return 45.0
	if ix > 0 and iy < 0:
		return -135.0
	return 135.0


func _aim_heading(angle: float) -> void:
	if absf(wrapf(angle - _turn_to, -180.0, 180.0)) < 0.1 and _turn_left > 0.0:
		return
	_turn_from = _heading
	_turn_to = angle
	var diff := absf(wrapf(angle - _heading, -180.0, 180.0))
	_turn_dur = 0.1 * diff / 90.0
	_turn_left = _turn_dur


func _apply_turn(delta: float) -> void:
	if _turn_left <= 0.0:
		_heading = _turn_to
	else:
		_turn_left = maxf(_turn_left - delta, 0.0)
		var along := 1.0 if _turn_dur <= 0.0 else 1.0 - _turn_left / _turn_dur
		_heading = wrapf(_turn_from + wrapf(_turn_to - _turn_from, -180.0, 180.0) * along, -180.0, 180.0)
	_toon.rotation_degrees.y = _heading


func _bump_cog() -> void:
	if _down > 0.0:
		return
	for cog in _cogs:
		if not cog.visible:
			continue
		var pos := _from_panda(cog.position)
		if Vector2(pos.x, pos.y).distance_to(Vector2(_px, _py)) < 1.7:
			_knock("slip-backward")
			_sfx("MG_cannon_hit_dirt")
			return


func _knock(anim: String) -> void:
	_down = 1.0
	_fall = anim
	_fell = false


func _move_cogs(delta: float) -> void:
	for walk in _walks:
		var cog_index := int(walk["cog"])
		if cog_index < 0 or cog_index >= _cogs.size():
			continue
		var start := float(walk["t"])
		var span := float(walk["dur"])
		var cog := _cogs[cog_index]
		if _elapsed < start or _elapsed > start + span:
			if _cog_free[cog_index] == start:
				cog.visible = false
				_cog_free[cog_index] = -1.0
			continue
		var along := clampf((_elapsed - start) / maxf(span, 0.01), 0.0, 1.0)
		var from: Vector2 = walk["from"]
		var to: Vector2 = walk["to"]
		var pos := from.lerp(to, along)
		var dir := to - from
		cog.visible = true
		cog.position = _panda(pos.x, pos.y, 0.0)
		if dir.length_squared() > 0.0001:
			cog.rotation_degrees.y = rad_to_deg(atan2(-dir.x, dir.y))
		var suit := cog as StreetCog
		if suit != null:
			suit._march(delta)
		_cog_free[cog_index] = start


func _move_drops() -> void:
	for drop in _drops:
		if bool(drop["done"]):
			continue
		var id := int(drop["id"])
		if _gone.has(id):
			_count_fruit(drop)
			_remove_drop(drop, false)
			continue
		if _elapsed < float(drop["t"]):
			continue
		if not bool(drop["born"]):
			_birth(drop)
		var age := _elapsed - float(drop["t"])
		var onscreen := float(drop["onscreen"])
		var height := _height
		if age >= _offscreen:
			var fall_t := age - _offscreen
			var u := clampf(fall_t / maxf(onscreen, 0.01), 0.0, 1.0)
			height = _height * (1.0 - u * u)
			if fall_t >= onscreen:
				if String(drop["kind"]) == "anvil":
					_sfx("AA_drop_anvil_miss", 0.45)
				_remove_drop(drop, false)
				continue
		var lift := drop["lift"] as Node3D
		if lift != null:
			lift.position.y = height
		var shadow := drop["shadow"] as MeshInstance3D
		if shadow != null:
			var mid := 0.3 * (_offscreen / maxf(_baseline, 0.01))
			var scale := mid
			var alpha := 0.4
			if age < _offscreen:
				var grow := clampf(age / maxf(_offscreen, 0.01), 0.0, 1.0)
				scale = lerpf(0.0, mid, grow)
				alpha = lerpf(0.0, 0.4, grow)
			else:
				# TrickShadows reaches 0.3 on the ground. Ease-in keeps the fruit high, so size follows height.
				var closeness := 1.0 - clampf(height / maxf(_height, 0.01), 0.0, 1.0)
				scale = lerpf(mid, 0.3, closeness)
			shadow.scale = Vector3(scale, scale, scale)
			var shade := shadow.material_override as StandardMaterial3D
			if shade != null:
				shade.albedo_color = Color(0, 0, 0, alpha)
		if _catch(drop, height):
			_take(drop)


func _catch(drop: Dictionary, height: float) -> bool:
	if height > 3.2 or height < 0.0:
		return false
	var reach := 1.0 + 0.7
	if String(drop["kind"]) != "anvil":
		reach = lerpf(1.0, 1.3, _difficulty) + 0.7
	return Vector2(float(drop["x"]) - _px, float(drop["y"]) - _py).length() < reach


func _take(drop: Dictionary) -> void:
	var id := int(drop["id"])
	_gone[id] = true
	if party_size() > 1:
		ToonNet.note_minigame("take", id)
	if String(drop["kind"]) == "anvil":
		_knock("slip-forward")
		_sfx("MG_cannon_hit_dirt")
		_sfx("AA_drop_anvil_miss")
	else:
		_count_fruit(drop)
		score += 1
		_sfx("SZ_DD_treasure")
	_remove_drop(drop, false)


func _count_fruit(drop: Dictionary) -> void:
	var id := int(drop["id"])
	if _counted.has(id) or String(drop["kind"]) == "anvil":
		return
	_counted[id] = true
	_team_fruit += 1


func _birth(drop: Dictionary) -> void:
	drop["born"] = true
	var anchor := Node3D.new()
	add_child(anchor)
	anchor.position = _panda(float(drop["x"]), float(drop["y"]), 0.0)
	var shadow := MeshInstance3D.new()
	var card := QuadMesh.new()
	# phase_3 drop_shadow is an 8-unit card. Catch scales it up to 0.3.
	card.orientation = PlaneMesh.FACE_Y
	card.size = Vector2(8.0, 8.0)
	shadow.mesh = card
	var shade := StandardMaterial3D.new()
	shade.albedo_color = Color(0, 0, 0, 1)
	shade.albedo_texture = _SHADOW_TEX
	shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shade.cull_mode = BaseMaterial3D.CULL_DISABLED
	shade.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	shadow.material_override = shade
	shadow.position = Vector3(0.0, 0.2, 0.0)
	anchor.add_child(shadow)
	var kind := String(drop["kind"])
	var lift := Node3D.new()
	anchor.add_child(lift)
	var spin := Node3D.new()
	spin.rotation_degrees.y = float(drop.get("h", 0.0))
	lift.add_child(spin)
	var offset := Node3D.new()
	offset.scale = Vector3.ONE * float(_SCALE.get(kind, 0.7))
	if kind == "pear":
		offset.position.y = -0.6
	elif kind == "coconut":
		offset.rotation_degrees.x = 180.0
	elif kind == "watermelon":
		offset.position.y = -0.5
	elif kind == "pineapple":
		offset.position.y = -1.7
	elif kind == "anvil":
		offset.position.y = -1.0
	spin.add_child(offset)
	offset.add_child(_fruit_model(kind))
	drop["node"] = anchor
	drop["shadow"] = shadow
	drop["lift"] = lift


func _fruit_heading(kind: String) -> float:
	if kind == "watermelon":
		return 135.0 + (shared_float(0.0, 1.0) * 2.0 - 1.0) * 12.0
	if kind == "anvil":
		return (shared_float(0.0, 1.0) * 2.0 - 1.0) * 15.0
	return shared_float(0.0, 1.0) * 360.0


func _fruit_model(kind: String) -> Node3D:
	var path := "res://assets/minigames/%s.glb" % kind
	var node := _prop(path)
	if node != null:
		return node
	if kind != "apple" and kind != "anvil":
		node = _prop("res://assets/minigames/apple.glb")
		if node != null:
			_tint(node, _fruit_tint(kind))
			return node
	return _ball(0.45, _fruit_tint(kind))


func _fruit_tint(kind: String) -> Color:
	match kind:
		"orange":
			return Color(1.0, 0.55, 0.1)
		"pear":
			return Color(0.72, 0.88, 0.22)
		"coconut":
			return Color(0.55, 0.36, 0.2)
		"watermelon":
			return Color(0.25, 0.7, 0.28)
		"pineapple":
			return Color(0.95, 0.82, 0.2)
		"anvil":
			return Color(0.35, 0.35, 0.4)
		_:
			return Color(0.85, 0.2, 0.15)


func _remove_drop(drop: Dictionary, _caught: bool) -> void:
	drop["done"] = true
	var node := drop["node"] as Node3D
	if node != null and is_instance_valid(node):
		node.queue_free()
	drop["node"] = null
	drop["lift"] = null
	drop["shadow"] = null


func _drops_finished() -> bool:
	if _drops.is_empty():
		return _elapsed > 1.0
	for drop in _drops:
		if not bool(drop["done"]):
			return false
	return true


func _begin_ending() -> void:
	_closing = true
	_clock_hidden = true
	if _clock_face != null:
		_clock_face.visible = false
		_clock_num.visible = false
	var perfect := _team_fruit >= _num_fruits and _num_fruits > 0
	_payout = maxi(1, int(float(score) / 2.0))
	if perfect:
		_payout += _bankers(float(_num_fruits) / 4.0)
		_perfect.visible = true
		_layout_perfect()
		_sfx("ring_perfect")
		_hold_end = 3.5
	else:
		_hold_end = 1.0


func _bankers(value: float) -> int:
	var down := int(value)
	var frac := value - float(down)
	if frac > 0.5:
		return down + 1
	if frac < 0.5:
		return down
	if down % 2 == 0:
		return down
	return down + 1


func _animate_perfect() -> void:
	if _perfect == null or not _perfect.visible:
		return
	var shown := 3.5 - _hold_end
	var amount := 1.0
	var alpha := 1.0
	if shown < 0.5:
		var u := clampf(shown / 0.5, 0.0, 1.0)
		amount = u
		alpha = u
	elif shown < 2.5:
		amount = 1.0
	elif shown < 3.0:
		var u := clampf((shown - 2.5) / 0.5, 0.0, 1.0)
		amount = lerpf(1.0, 1.35, u)
		alpha = 1.0 - u
	else:
		alpha = 0.0
	_perfect.pivot_offset = _perfect.size * 0.5
	_perfect.scale = Vector2.ONE * amount
	_perfect.modulate = Color(1, 1, 1, alpha)


func _layout_perfect() -> void:
	if _perfect == null:
		return
	var view := get_viewport().get_visible_rect().size
	_perfect.position = Vector2(view.x * 0.5 - 180.0, view.y * 0.38)
	_perfect.size = Vector2(360.0, 80.0)
	ToonGui.style_sign(_perfect, Color(1.0, 0.1, 0.1), maxi(int(view.y * 0.08), 28), Color(0, 0, 0, 0), 0)


func _sync_fruit() -> void:
	if party_size() <= 1:
		return
	var raw: Variant = ToonNet.minigame_state().get("taken", [])
	if not (raw is Array):
		return
	for item in raw:
		var id := int(item)
		_gone[id] = true
		if id >= 0 and id < _drops.size():
			_count_fruit(_drops[id])


func _grid(column: int, row: int) -> Vector2:
	var x := (float(column) / float(_cols - 1)) * 2.0 - 1.0
	var y := (float(row) / float(_rows - 1)) * 2.0 - 1.0
	return Vector2(x * _half_w, y * _half_h)


func _aim_camera() -> void:
	var spots: Array[Vector2] = [
		Vector2(-29.36, 28.17),
		Vector2(-29.36, 28.17),
		Vector2(-32.87, 30.43),
		Vector2(-35.59, 32.1),
	]
	var spot := spots[_players - 1]
	_camera.position = _panda(0.0, spot.x, spot.y)
	var pitch := deg_to_rad(35.0)
	_camera.look_at(_camera.position + Vector3(0.0, -sin(pitch), -cos(pitch)), Vector3.UP)


func _from_panda(point: Vector3) -> Vector3:
	return Vector3(point.x, -point.z, point.y)
