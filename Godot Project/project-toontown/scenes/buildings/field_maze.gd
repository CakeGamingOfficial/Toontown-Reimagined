extends Node

## DistCogdoMazeGame. The only game _createGame can roll, because boardroom,
## crane, and flying are in IntGames. Four Minglers, then Name Droppers and
## Cold Callers. A gag hit costs one laff of suit health. Defeating every
## Mingler opens the door. Memos and the clock make the score.

const _CELL := 4.0
const _SIZE := 13
const _TIMEOUT := 240.0
const _PERFECT := 90.0
const _MAX_TIME := 210.0
const _HIT_WAIT := 0.45
const _HURT_WAIT := 2.0

var _live := false
var _run_id := -1
var _age := 0.0
var _cool := 0.0
var _hurt := 0.0
var _open := false
var _memos := 0
var _max_memos := 1
var _bosses := 0
var _origin := Vector3.ZERO
var _walls: Dictionary = {}
var _suits: Array[Dictionary] = []
var _drops: Array[Dictionary] = []
var _root: Node3D
var _hud: Label
var _door: Vector2i = Vector2i(_SIZE - 2, _SIZE - 2)


func running() -> bool:
	return _live


func begin(run: Dictionary, origin: Vector3, toon: Node) -> void:
	if _live and _run_id == int(run.get("id", -1)):
		return
	clear()
	_live = true
	_run_id = int(run.get("id", -1))
	_age = 0.0
	_open = false
	_memos = 0
	_origin = origin
	_root = Node3D.new()
	_root.name = "FieldMaze"
	_root.position = origin
	add_child(_root)
	_carve()
	_floor()
	_build_walls()
	_spawn()
	_door_marker()
	var layer := CanvasLayer.new()
	layer.layer = 22
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(24, 24)
	_hud.size = Vector2(520, 80)
	layer.add_child(_hud)
	_plant(toon, Vector2i(1, 1))
	if toon != null:
		toon.call("hold_for_battle", false)


func play(delta: float, toon: Node) -> void:
	if not _live or toon == null:
		return
	_age += delta
	_cool = maxf(_cool - delta, 0.0)
	_hurt = maxf(_hurt - delta, 0.0)
	var body := toon.get_node_or_null("Player") as Node3D
	if body == null:
		return
	_keep_inside(body)
	_move_suits(delta)
	_touch(body, toon)
	_gather(body)
	if Input.is_action_just_pressed("ui_accept") and _cool <= 0.0:
		_throw(body)
	var left := maxf(_TIMEOUT - _age, 0.0)
	var door := "The door is open. Walk into the gold square." if _open else "Defeat the Minglers to open the door."
	_hud.text = "Memos %d / %d\n%s\n%.0f" % [_memos, _max_memos, door, left]
	if left <= 0.0:
		_finish(toon, false)


func clear() -> void:
	_live = false
	_suits.clear()
	_drops.clear()
	_walls.clear()
	if _root != null:
		_root.queue_free()
		_root = null
	for child in get_children():
		child.queue_free()


func _finish(toon: Node, made_it: bool) -> void:
	if not _live:
		return
	var score := _score()
	var hood := _hood_difficulty()
	var loadout: ToonLoadout = toon.call("battle_loadout")
	if loadout != null:
		if made_it:
			var reward := int(round(score * (hood * 112.0 + 25.0)))
			if reward > 0:
				loadout.gain_hp(reward)
				loadout.save()
		else:
			var penalty := int(round(hood * 50.0))
			if penalty > 0 and loadout.hp > 1:
				loadout.take_damage(mini(penalty, loadout.hp - 1))
				loadout.save()
	var runs := get_node_or_null("/root/StreetTraffic/BuildingRuns")
	var district := int(get_parent().call("_district"))
	var slug := String(get_parent().call("_slug"))
	clear()
	if toon != null:
		toon.call("hold_for_battle", true)
	if runs != null and runs.has_method("maze_result"):
		runs.call("maze_result", district, slug, _run_id, made_it)


func _score() -> float:
	var adjusted := clampf(_age - _PERFECT, 0.0, _MAX_TIME)
	var time_score := 1.0 - adjusted / _MAX_TIME
	var pickup := 0.0
	if _max_memos > 0:
		pickup = float(_memos) / float(_max_memos)
	return clampf(pickup * 0.7 + time_score * 0.5, 0.0, 1.0)


func _hood_difficulty() -> float:
	var zone := 2000
	var host := get_parent()
	if host != null and host.get_parent() != null:
		zone = int(preload("res://scenes/interiors/shop_door.gd").street_zone(host.get_parent().scene_file_path))
	var hood := zone - posmod(zone, 1000)
	var order: Array[int] = [2000, 1000, 5000, 4000, 3000, 9000]
	var index := order.find(hood)
	if index < 0:
		index = 0
	return float(index) / 5.0


func _carve() -> void:
	var visited: Dictionary = {}
	var stack: Array[Vector2i] = [Vector2i(1, 1)]
	visited[Vector2i(1, 1)] = true
	while not stack.is_empty():
		var here: Vector2i = stack[stack.size() - 1]
		var next: Array[Vector2i] = []
		for step in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			var dest: Vector2i = here + step
			if dest.x <= 0 or dest.y <= 0 or dest.x >= _SIZE - 1 or dest.y >= _SIZE - 1:
				continue
			if visited.has(dest):
				continue
			next.append(dest)
		if next.is_empty():
			stack.remove_at(stack.size() - 1)
			continue
		var pick: Vector2i = next[randi() % next.size()]
		var between := Vector2i((here.x + pick.x) / 2, (here.y + pick.y) / 2)
		_walls[here] = false
		_walls[between] = false
		_walls[pick] = false
		visited[pick] = true
		stack.append(pick)
	for x in _SIZE:
		for y in _SIZE:
			var cell := Vector2i(x, y)
			if not _walls.has(cell):
				_walls[cell] = true


func _floor() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(_CELL * _SIZE, 1.0, _CELL * _SIZE)
	shape.shape = box
	shape.position = Vector3(_CELL * _SIZE * 0.5, -0.5, _CELL * _SIZE * 0.5)
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = box.size
	mesh.mesh = slab
	mesh.position = shape.position
	body.add_child(mesh)
	body.position = Vector3.ZERO
	_root.add_child(body)


func _build_walls() -> void:
	for x in _SIZE:
		for y in _SIZE:
			if not bool(_walls.get(Vector2i(x, y), true)):
				continue
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(_CELL, 3.2, _CELL)
			shape.shape = box
			shape.position.y = 1.6
			body.add_child(shape)
			var mesh := MeshInstance3D.new()
			var block := BoxMesh.new()
			block.size = box.size
			mesh.mesh = block
			mesh.position.y = 1.6
			body.add_child(mesh)
			body.position = Vector3((float(x) + 0.5) * _CELL, 0.0, (float(y) + 0.5) * _CELL)
			_root.add_child(body)


func _spawn() -> void:
	var diff := _hood_difficulty()
	var bosses := 4
	var fast := 5 + int(round(diff * 6.0))
	var slow := 5 + int(round(diff * 9.0))
	_bosses = bosses
	_max_memos = fast * 3 + slow * 2
	var serial := 0
	for _index in bosses:
		_suits.append(_suit(serial, "Mingler", 2, 0, 3, 2.4))
		serial += 1
	for _index in fast:
		_suits.append(_suit(serial, "Name Dropper", 1, 3, 1, 1.6))
		serial += 1
	for _index in slow:
		_suits.append(_suit(serial, "Cold Caller", 1, 2, 2, 2.2))
		serial += 1


func _suit(serial: int, title: String, hp: int, memos: int, damage: int, pace: float) -> Dictionary:
	var cell := _open_cell()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 2.4, 1.2)
	mesh.mesh = box
	mesh.position.y = 1.2
	var body := Node3D.new()
	body.name = title
	body.add_child(mesh)
	_root.add_child(body)
	body.position = _cell_pos(cell)
	return {
		"id": serial,
		"name": title,
		"hp": hp,
		"memos": memos,
		"damage": damage,
		"pace": pace,
		"cell": cell,
		"wait": 0.0,
		"body": body,
		"boss": title == "Mingler",
	}


func _door_marker() -> void:
	var mesh := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(_CELL * 0.8, 0.15, _CELL * 0.8)
	mesh.mesh = slab
	mesh.position = _cell_pos(_door) + Vector3(0, 0.1, 0)
	_root.add_child(mesh)


func _throw(body: Node3D) -> void:
	_cool = _HIT_WAIT
	var best := -1
	var reach := 8.0
	for index in _suits.size():
		var suit := _suits[index]
		var actor: Node3D = suit["body"]
		if actor == null:
			continue
		var dist := body.global_position.distance_to(actor.global_position)
		if dist < reach:
			reach = dist
			best = index
	if best < 0:
		return
	var suit := _suits[best]
	suit["hp"] = int(suit["hp"]) - 1
	if int(suit["hp"]) > 0:
		_suits[best] = suit
		return
	if bool(suit["boss"]):
		_bosses -= 1
		if _bosses <= 0:
			_open = true
	for _memo in int(suit["memos"]):
		var drop := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.25
		ball.height = 0.5
		drop.mesh = ball
		drop.position = (suit["body"] as Node3D).position + Vector3(randf_range(-0.4, 0.4), 0.4, randf_range(-0.4, 0.4))
		_root.add_child(drop)
		_drops.append({"node": drop})
	var actor: Node3D = suit["body"]
	if actor != null:
		actor.queue_free()
	_suits.remove_at(best)


func _touch(body: Node3D, toon: Node) -> void:
	var here := _cell_of(body.global_position)
	if _open and here == _door:
		_finish(toon, true)
		return
	if _hurt > 0.0:
		return
	for suit in _suits:
		var actor: Node3D = suit["body"]
		if actor == null:
			continue
		if body.global_position.distance_to(actor.global_position) > 1.7:
			continue
		var loadout: ToonLoadout = toon.call("battle_loadout")
		if loadout != null:
			loadout.take_damage(int(suit["damage"]))
			loadout.save()
			if loadout.hp <= 0:
				_finish(toon, false)
				return
		_hurt = _HURT_WAIT
		return


func _gather(body: Node3D) -> void:
	var kept: Array[Dictionary] = []
	for item in _drops:
		var node: Node3D = item["node"]
		if node == null:
			continue
		if body.global_position.distance_to(node.global_position) < 1.4:
			_memos += 1
			node.queue_free()
			continue
		kept.append(item)
	_drops = kept


func _move_suits(delta: float) -> void:
	for index in _suits.size():
		var suit := _suits[index]
		suit["wait"] = float(suit["wait"]) - delta
		if float(suit["wait"]) > 0.0:
			_suits[index] = suit
			continue
		var here: Vector2i = suit["cell"]
		var options: Array[Vector2i] = [here]
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var dest: Vector2i = here + step
			if _open_at(dest):
				options.append(dest)
		suit["cell"] = options[randi() % options.size()]
		suit["wait"] = float(suit["pace"])
		var actor: Node3D = suit["body"]
		if actor != null:
			actor.position = _cell_pos(suit["cell"])
		_suits[index] = suit


func _keep_inside(body: Node3D) -> void:
	var cell := _cell_of(body.global_position)
	if _open_at(cell):
		return
	var back := _root.to_global(_cell_pos(Vector2i(1, 1)))
	body.global_position = back


func _open_cell() -> Vector2i:
	for _try in 40:
		var cell := Vector2i(randi_range(1, _SIZE - 2), randi_range(1, _SIZE - 2))
		if _open_at(cell) and cell != Vector2i(1, 1) and cell != _door:
			return cell
	return Vector2i(3, 3)


func _open_at(cell: Vector2i) -> bool:
	return not bool(_walls.get(cell, true))


func _cell_of(point: Vector3) -> Vector2i:
	var local := _root.to_local(point)
	return Vector2i(int(floor(local.x / _CELL)), int(floor(local.z / _CELL)))


func _cell_pos(cell: Vector2i) -> Vector3:
	return Vector3((float(cell.x) + 0.5) * _CELL, 0.2, (float(cell.y) + 0.5) * _CELL)


func _plant(toon: Node, cell: Vector2i) -> void:
	if toon == null or _root == null:
		return
	toon.call("visit_friend", _root.to_global(_cell_pos(cell)), 0.0)
