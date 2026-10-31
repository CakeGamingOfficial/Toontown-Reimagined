extends "res://scenes/trolley/trolley_minigame.gd"

## Toon Escape. The den, start pipe, blocks, stomper, treasures, and elevator
## are the Toon Blitz models. Arrow keys run and jump. Ctrl squirts a Cog.

var _vy := 0.0
var _grounded := true
var _floors: Array[Dictionary] = []
var _gems: Array[Node3D] = []
var _cog: Node3D
var _cog_x := 18.0
var _cog_dir := -1.0
var _cog_stun := 0.0
var _stomper: Node3D
var _stomper_phase := 0.0
var _exit: Node3D
var _squirt := 0.0
var _bump := 0.0
var _home := Vector3.ZERO


func _init() -> void:
	title = "Toon Escape"
	instructions = "Escape from the Cog den as soon as you can. Use arrow keys to run/jump and Ctrl to squirt a Cog. Collect Cog treasures to gain even more points."
	duration = 60.0


func _build() -> void:
	_show("res://assets/minigames/toonblitz.glb")
	_add_floor(_spawn("res://assets/minigames/toonblitz_wall.glb", -34.0, 0.0, 0.0))
	_add_floor(_spawn("res://assets/minigames/toonblitz_start.glb", -30.0, 0.0, 0.0))
	var icons := [
		"res://assets/minigames/sales_icon.glb",
		"res://assets/minigames/money_icon.glb",
		"res://assets/minigames/legal_icon.glb",
		"res://assets/minigames/corp_icon.glb",
	]
	var steps: Array[Vector2] = [
		Vector2(-22, 0), Vector2(-14, 0), Vector2(-6, 2), Vector2(2, 2),
		Vector2(10, 0), Vector2(18, 3), Vector2(26, 1), Vector2(34, 1),
	]
	for index in steps.size():
		var step := steps[index]
		var block := _spawn("res://assets/minigames/toonblitz_block.glb", step.x, 0.0, step.y)
		_add_floor(block)
		if index % 2 == 1 and block != null:
			var gem := _spawn(icons[index % icons.size()], step.x, 0.0, step.y + 2.2, 0.6)
			if gem != null:
				_gems.append(gem)
	_stomper = _spawn("res://assets/minigames/toonblitz_stomper.glb", 2.0, 0.0, 6.0)
	_cog = _flunky(18.0, 0.0, 4.0)
	_cog.scale = Vector3(0.7, 0.7, 0.7)
	_exit = _spawn("res://assets/minigames/toonblitz_elevator.glb", 46.0, 0.0, 0.0)
	_add_floor(_exit)
	_make_toon(Vector3(-30.0, 2.0, 0.0))
	if _floors.size() > 1:
		_toon.position.y = float(_floors[1]["top"])
	elif not _floors.is_empty():
		_toon.position.y = float(_floors[0]["top"])
	_home = _toon.position
	_frame()
	show_board("avatar")


func _play(delta: float) -> void:
	_bump = maxf(_bump - delta, 0.0)
	var move := _stick()
	_toon.position.x += move.x * 8.0 * delta
	if _grounded and (Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_SPACE)):
		_vy = 11.0
		_grounded = false
		_sfx("MG_sfx_vine_game_jump", 0.7)
	_vy -= 24.0 * delta
	_toon.position.y += _vy * delta
	_grounded = false
	if _vy <= 0.0:
		for floor in _floors:
			var top := float(floor["top"])
			if _toon.position.x < float(floor["left"]) or _toon.position.x > float(floor["right"]):
				continue
			if _toon.position.y <= top and _toon.position.y >= top - 1.4:
				_toon.position.y = top
				_vy = 0.0
				_grounded = true
				break
	if _toon.position.y < -8.0:
		_toon.position = _home
		_vy = 0.0
		_grounded = true
		_sfx("MG_sfx_vine_game_fall")
	_toon.set_locomotion(move.x * 8.0, false, not _grounded, delta)
	_stomper_phase += delta
	if _stomper != null:
		_stomper.position.y = 4.0 + sin(_stomper_phase * 2.2) * 2.4
		if _bump == 0.0 and _stomper.position.distance_to(_toon.position) < 1.6 and sin(_stomper_phase * 2.2) < -0.4:
			_bump = 0.6
			_toon.position.x -= 1.5
			_sfx("AV_collision", 0.7)
	_cog_stun = maxf(_cog_stun - delta, 0.0)
	if _cog_stun == 0.0:
		_cog_x += _cog_dir * 3.0 * delta
		if _cog_x < 14.0 or _cog_x > 24.0:
			_cog_dir *= -1.0
		_cog.position = _panda(_cog_x, 0.0, 4.0)
	if _bump == 0.0 and _toon.position.distance_to(_cog.position) < 1.3:
		_bump = 0.6
		_toon.position.x -= 2.0
		_sfx("MG_cannon_hit_dirt", 0.5)
	_squirt = maxf(_squirt - delta, 0.0)
	if _squirt == 0.0 and Input.is_physical_key_pressed(KEY_CTRL):
		_squirt = 0.45
		_sfx("AA_squirt_seltzer_miss", 0.7)
		if absf(_toon.position.x - _cog.position.x) < 9.0:
			_cog_stun = 2.0
			_sfx("Seltzer_squirt_2dgame_hit")
	for gem in _gems:
		if gem.visible and gem.position.distance_to(_toon.position) < 1.6:
			gem.visible = false
			score += 2
			_sfx("SZ_DD_treasure")
			_sfx("sparkly", 0.6)
	_frame()
	if _exit != null and _toon.position.distance_to(_exit.position) < 2.2:
		score += 6 + maxi(int(duration) / 5, 0)
		_sfx("threeSparkles")
		_end()


func _add_floor(node: Node3D) -> void:
	if node == null:
		return
	var box := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var world := mesh_node.global_transform * mesh_node.get_aabb()
		if first:
			box = world
			first = false
		else:
			box = box.merge(world)
	if first:
		return
	_floors.append({
		"top": box.position.y + box.size.y,
		"left": box.position.x,
		"right": box.position.x + box.size.x,
	})


func _frame() -> void:
	_camera.position = Vector3(_toon.position.x, _toon.position.y + 3.5, 18.0)
	_camera.look_at(_toon.position + Vector3(2.0, 1.0, 0.0), Vector3.UP)
