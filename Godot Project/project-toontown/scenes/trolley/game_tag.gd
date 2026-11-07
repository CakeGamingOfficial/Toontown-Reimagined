extends "res://scenes/trolley/trolley_minigame.gd"

## Tag Game. Treasures are worth 2. The toon who is IT cannot pick them up.
## IT runs 1.3 times faster. TagGameGlobals.DURATION is 60.

const _SPEED := 20.0
const _IT_SPEED := 1.3
const _TAG_REACH := 2.4
const _SPOTS: Array[Vector2] = [
	Vector2(0, 0), Vector2(5, 20), Vector2(0, 40), Vector2(-5, -20),
	Vector2(0, -40), Vector2(20, 0), Vector2(40, 5), Vector2(-20, -5),
	Vector2(-40, 0), Vector2(22, 20), Vector2(-20, 22), Vector2(20, -20),
	Vector2(-25, -20), Vector2(20, 40), Vector2(20, -44), Vector2(-24, 40),
	Vector2(-20, -40),
]
const _STARTS: Array[Vector2] = [
	Vector2(0, 10), Vector2(10, 0), Vector2(0, -10), Vector2(-10, 0),
]

var _px := 0.0
var _py := 10.0
var _others: Array[Dictionary] = []
var _treasures: Array[Dictionary] = []
var _it := 0
var _it_peer := -1
var _live := false
var _tag_wait := 0.0
var _banner: Label


func _init() -> void:
	title = "Tag Game"
	instructions = "Collect the treasures. You cannot collect treasure when you are IT!"
	duration = 60.0


func _build() -> void:
	_show("res://assets/minigames/tag_arena.glb")
	_live = party_size() > 1
	if _live:
		var spot: Vector2 = _STARTS[party_index()]
		_px = spot.x
		_py = spot.y
		_it_peer = party_peer(shared_int(party_size()))
		ToonNet.note_minigame("it", _it_peer)
	_make_toon(_panda(_px, _py, 0.0))
	if not _live:
		for i in range(3):
			var start: Vector2 = _STARTS[i + 1]
			var actor := ToonActor.new()
			actor.name = "Racer%d" % (i + 1)
			add_child(actor)
			var gender := "f" if i == 1 else "m"
			var style := ToonStyle.random_named(gender)
			actor.show_style(style)
			actor.position = _panda(start.x, start.y, 0.0)
			_others.append({"actor": actor, "at": start, "name": style.first_name})
		_it = shared_int(4)
	for _i in range(4):
		_drop_treasure()
	var layer := CanvasLayer.new()
	layer.layer = 21
	add_child(layer)
	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_banner.offset_top = -120
	_banner.offset_bottom = -60
	_banner.offset_left = -360
	_banner.offset_right = 360
	_banner.add_theme_font_size_override("font_size", 36)
	_banner.add_theme_color_override("font_color", Color(0.95, 0.95, 0.65))
	layer.add_child(_banner)
	_paint_it()
	show_board("points")
	_aim(0.0, -18.0, 14.0, _px, _py, 1.0)


func _play(delta: float) -> void:
	_tag_wait = maxf(_tag_wait - delta, 0.0)
	var move := _stick()
	var speed := _SPEED * (_IT_SPEED if _am_it() else 1.0)
	if move.length() > 0.1:
		move = move.normalized()
		_px += move.x * speed * delta
		_py += move.y * speed * delta
		_face(_toon, move)
	_px = clampf(_px, -46.0, 46.0)
	_py = clampf(_py, -46.0, 46.0)
	_toon.position = _panda(_px, _py, 0.0)
	_toon.clear_gesture()
	_toon.set_locomotion(speed if move.length() > 0.1 else 0.0, false, false, delta)
	if _live:
		_sync_live()
		_grab_live(delta)
		_tag_live()
	else:
		_drive_others(delta)
		_grab(delta)
		_try_tag()
	_camera.position = _panda(_px, _py - 18.0, 14.0)
	_camera.look_at(_panda(_px, _py, 1.0), Vector3.UP)


func _drive_others(delta: float) -> void:
	var it_at := _feet(_it)
	for i in range(_others.size()):
		var who: int = i + 1
		var item: Dictionary = _others[i]
		var actor := item["actor"] as ToonActor
		var at: Vector2 = item["at"]
		var speed := _SPEED * (_IT_SPEED if _it == who else 1.0)
		var want := Vector2.ZERO
		if _it == who:
			var nearest := _px
			var nearest_y := _py
			var best := at.distance_to(Vector2(_px, _py))
			for other_i in range(_others.size()):
				if other_i == i:
					continue
				var other_at: Vector2 = _others[other_i]["at"]
				var gap := at.distance_to(other_at)
				if gap < best:
					best = gap
					nearest = other_at.x
					nearest_y = other_at.y
			want = Vector2(nearest - at.x, nearest_y - at.y)
		else:
			want = at - it_at
			var bean := _nearest_treasure(at)
			if bean.length_squared() > 0.01 and at.distance_to(it_at) > 8.0:
				want = bean - at
		var moving := want.length() > 0.2
		if moving:
			want = want.normalized()
			at += want * speed * delta
			_face(actor, want)
		at.x = clampf(at.x, -46.0, 46.0)
		at.y = clampf(at.y, -46.0, 46.0)
		item["at"] = at
		actor.position = _panda(at.x, at.y, 0.0)
		actor.clear_gesture()
		actor.set_locomotion(speed if moving else 0.0, false, false, delta)


func _grab(delta: float) -> void:
	var feet: Array[Vector2] = [Vector2(_px, _py)]
	for item in _others:
		feet.append(item["at"])
	for treasure in _treasures:
		if float(treasure["wait"]) > 0.0:
			treasure["wait"] = float(treasure["wait"]) - delta
			if float(treasure["wait"]) <= 0.0:
				var spot := _free_spot()
				treasure["at"] = spot
				var node := treasure["node"] as Node3D
				node.position = _panda(spot.x, spot.y, 0.1)
				node.visible = true
			continue
		var at: Vector2 = treasure["at"]
		for who in range(feet.size()):
			if who == _it:
				continue
			if feet[who].distance_to(at) > 1.8:
				continue
			if who == 0:
				score += 2
				_sfx("SZ_DD_treasure")
			treasure["wait"] = 4.0
			(treasure["node"] as Node3D).visible = false
			break


func _try_tag() -> void:
	if _tag_wait > 0.0:
		return
	var it_at := _feet(_it)
	var caught := -1
	var best := _TAG_REACH
	if _it != 0 and it_at.distance_to(Vector2(_px, _py)) < best:
		caught = 0
		best = it_at.distance_to(Vector2(_px, _py))
	for i in range(_others.size()):
		if _it == i + 1:
			continue
		var gap := it_at.distance_to(_others[i]["at"])
		if gap < best:
			best = gap
			caught = i + 1
	if caught < 0:
		return
	_it = caught
	_tag_wait = 0.8
	_sfx("MG_Tag_C")
	_paint_it()


func _drop_treasure() -> void:
	var spot := _free_spot()
	var node := _spawn("res://assets/minigames/treasure.glb", spot.x, spot.y, 0.1, 1.0)
	if node == null:
		node = _box(Vector3(0.8, 0.8, 0.8), Color(1.0, 0.85, 0.15))
		add_child(node)
		node.position = _panda(spot.x, spot.y, 0.4)
	_treasures.append({"node": node, "at": spot, "wait": 0.0})


func _free_spot() -> Vector2:
	var open: Array[Vector2] = []
	for spot in _SPOTS:
		var taken := false
		for treasure in _treasures:
			if float(treasure["wait"]) <= 0.0 and (treasure["at"] as Vector2).distance_to(spot) < 1.0:
				taken = true
				break
		if not taken:
			open.append(spot)
	if open.is_empty():
		return _SPOTS[shared_int(_SPOTS.size())]
	return open[shared_int(open.size())]


func _nearest_treasure(at: Vector2) -> Vector2:
	var best := 999.0
	var found := Vector2.ZERO
	for treasure in _treasures:
		if float(treasure["wait"]) > 0.0:
			continue
		var spot: Vector2 = treasure["at"]
		var gap := at.distance_to(spot)
		if gap < best:
			best = gap
			found = spot
	return found


func _feet(who: int) -> Vector2:
	if who == 0:
		return Vector2(_px, _py)
	return _others[who - 1]["at"]


func _face(actor: Node3D, move: Vector2) -> void:
	var ahead := actor.position + Vector3(move.x, 0.0, -move.y)
	if ahead.distance_squared_to(actor.position) < 0.0001:
		return
	actor.look_at(ahead, Vector3.UP)


func _am_it() -> bool:
	if _live:
		return _it_peer == ToonNet.peer_id()
	return _it == 0


func _sync_live() -> void:
	var state := ToonNet.minigame_state()
	var it := int(state.get("it", -1))
	if it >= 0 and it != _it_peer:
		_it_peer = it
		_paint_it()
	var raw: Variant = state.get("taken", [])
	if not (raw is Array):
		return
	for item in raw:
		var index := int(item)
		if index < 0 or index >= _treasures.size():
			continue
		var treasure: Dictionary = _treasures[index]
		if float(treasure["wait"]) > 0.0:
			continue
		treasure["wait"] = 4.0
		(treasure["node"] as Node3D).visible = false
		_treasures[index] = treasure


func _grab_live(delta: float) -> void:
	for index in _treasures.size():
		var treasure: Dictionary = _treasures[index]
		if float(treasure["wait"]) > 0.0:
			treasure["wait"] = float(treasure["wait"]) - delta
			if float(treasure["wait"]) <= 0.0:
				var spot: Vector2 = _SPOTS[index % _SPOTS.size()]
				treasure["at"] = spot
				var node := treasure["node"] as Node3D
				node.position = _panda(spot.x, spot.y, 0.1)
				node.visible = true
			_treasures[index] = treasure
			continue
		if _am_it():
			continue
		var at: Vector2 = treasure["at"]
		if Vector2(_px, _py).distance_to(at) > 1.8:
			continue
		score += 2
		_sfx("SZ_DD_treasure")
		treasure["wait"] = 4.0
		(treasure["node"] as Node3D).visible = false
		_treasures[index] = treasure
		ToonNet.note_minigame("take", index)
		break


func _tag_live() -> void:
	if _tag_wait > 0.0 or not _am_it():
		return
	var best := -1
	var reach := _TAG_REACH
	for actor in other_toons():
		var gap := panda_of(actor).distance_to(Vector2(_px, _py))
		if gap < reach:
			reach = gap
			best = int(actor.get_meta("peer", -1))
	if best < 0:
		return
	ToonNet.note_minigame("it", best)
	_tag_wait = 0.8
	_sfx("MG_Tag_C")
	_paint_it()


func _paint_it() -> void:
	if _live:
		if _am_it():
			_banner.text = "You Are IT!"
		else:
			var label := "Someone"
			for i in party_size():
				if party_peer(i) == _it_peer:
					label = party_name(i)
			_banner.text = "%s is IT!" % label
		return
	if _it == 0:
		_banner.text = "You Are IT!"
	else:
		_banner.text = "%s is IT!" % str(_others[_it - 1]["name"])
