extends "res://scenes/trolley/trolley_minigame.gd"

## Toon Escape. The course is the original Toon Blitz sections: run and jump
## along them, squirt the Cogs, and reach the elevator before the clock ends.

const _SPEED := 12.0
const _GRAVITY := 32.174
const _JUMP := 30.0
const _BODY := 3.2
const _FILES := {
	"00": "res://assets/minigames/toonblitz_block.glb",
	"01": "res://assets/minigames/toonblitz_block12.glb",
	"02": "res://assets/minigames/toonblitz_block6.glb",
	"03": "res://assets/minigames/toonblitz_block3.glb",
}
const _ICONS: PackedStringArray = [
	"res://assets/minigames/sales_icon.glb",
	"res://assets/minigames/money_icon.glb",
	"res://assets/minigames/legal_icon.glb",
	"res://assets/minigames/corp_icon.glb",
]

var _course: Dictionary = {}
var _x := -39.0
var _z := 13.59
var _vx := 0.0
var _vz := 0.0
var _heading := -90.0
var _grounded := true
var _up_was_down := false
var _mode := "run"
var _mode_time := 0.0
var _shoot_wait := 0.0
var _knock := 0.0
var _won := false
var _exit_x := 0.0
var _respawn := Vector2(-39.0, 13.59)
var _bonus := 15
var _solids: Array[Dictionary] = []
var _enemies: Array[Dictionary] = []
var _treasures: Array[Dictionary] = []
var _stompers: Array[Dictionary] = []
var _checks: Array[Dictionary] = []
var _sprays: Array[Dictionary] = []


func _init() -> void:
	title = "Toon Escape"
	instructions = "Escape from the Cog den as soon as you can. Use arrow keys to run/jump and Ctrl to squirt a Cog. Collect Cog treasures to gain even more points."
	duration = 150.0


func _build() -> void:
	var text := FileAccess.get_file_as_string("res://assets/minigames/toon_escape.json")
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_course = parsed
	_show("res://assets/minigames/toonblitz.glb")
	var hood := _hood_key()
	duration = float(_course.get("duration", {}).get(hood, 150))
	_bonus = int(_course.get("bonus", {}).get(hood, 15))
	_lay_course(hood)
	_x = -39.0 + float(party_index())
	_z = 13.59
	_respawn = Vector2(_x, _z)
	_make_toon(_panda(_x, 0.0, _z))
	_toon.rotation_degrees = Vector3(0.0, _heading + 180.0, 0.0)
	_camera.fov = 40.0
	_camera.far = 2000.0
	_frame()
	show_board("avatar")


func _play(delta: float) -> void:
	_shoot_wait = maxf(_shoot_wait - delta, 0.0)
	_slide_pieces(delta)
	if _mode == "win":
		_finish_run(delta)
		_frame()
		return
	if _mode == "fall":
		_mode_time -= delta
		if _mode_time <= 0.0:
			_x = _respawn.x
			_z = _respawn.y
			_vx = 0.0
			_vz = 0.0
			_grounded = true
			_mode = "run"
		_put_toon()
		_frame()
		return
	if _mode == "hurt" or _mode == "squish":
		_mode_time -= delta
		_knock = maxf(_knock - delta, 0.0)
		if _mode_time <= 0.0:
			_mode = "run"
			_vx = 0.0
	else:
		_steer()
	if _mode != "squish":
		_vz -= _GRAVITY * delta
		var old_x := _x
		var old_z := _z
		if _mode != "hurt" or _knock > 0.0:
			_x += _vx * delta
		_push_walls(old_x, old_z)
		var next_z := _z + _vz * delta
		_land(old_z, next_z)
		if _grounded:
			_ride()
		if _z < -2.0 and _mode == "run":
			_drop()
	_touch_checkpoint()
	_touch_enemy()
	_touch_treasure()
	_tick_sprays(delta)
	_put_toon()
	_frame()


func _hood_key() -> String:
	var key := str(int(_RIDE.hood))
	var durations: Dictionary = _course.get("duration", {})
	if durations.has(key):
		return key
	return "2000"


func _lay_course(hood: String) -> void:
	_place_props(-48.0)
	for piece in _course.get("startBlocks", []):
		_place_block(piece, -48.0)
	var origin := -24.0
	var picked: Array = _pick_sections(hood)
	for section_id in picked:
		var section: Dictionary = _course["sections"][str(int(section_id))]
		_place_section(section, origin, false)
		origin += float(section["length"])
	var ending: Dictionary = _course["sections"]["end"]
	_place_section(ending, origin, true)
	_exit_x = origin + 52.0
	var wall := _spawn("res://assets/minigames/toonblitz_wall.glb", origin + 100.0, 0.0, 4.0, 0.8)
	_keep_solid(wall)
	_spawn("res://assets/minigames/toonblitz_arrow.glb", origin + 6.0, 1.5, 12.76)
	_spawn("res://assets/minigames/toonblitz_elevator.glb", _exit_x, -2.0, 12.7)


func _place_props(origin: float) -> void:
	var wall := _spawn("res://assets/minigames/toonblitz_wall.glb", origin - 28.0, 0.0, 4.0, 0.8)
	_keep_solid(wall)
	_spawn("res://assets/minigames/toonblitz_start.glb", origin + 12.0, 0.0, 44.0)
	_spawn("res://assets/minigames/toonblitz_arrow.glb", origin + 23.0, 1.5, 12.76)


func _pick_sections(hood: String) -> Array:
	var weights: Array = _course.get("weights", {}).get(hood, [])
	var bag: Array[int] = []
	for index in weights.size():
		var row: Array = weights[index]
		var difficulty := int(row[0])
		for _copy in int(row[1]):
			bag.append(difficulty)
	var wanted: Array[int] = []
	var count := int(_course.get("count", {}).get(hood, 5))
	for _index in count:
		if bag.is_empty():
			break
		wanted.append(bag[_index_of(bag)])
	wanted.sort()
	var buckets: Array = [[], [], [], [], [], []]
	for section_id in _course.get("pool", []):
		var info: Dictionary = _course["sections"][str(int(section_id))]
		var bucket: Array = buckets[int(info["difficulty"])]
		bucket.append(int(section_id))
		buckets[int(info["difficulty"])] = bucket
	var chosen: Array = []
	for target in wanted:
		var difficulty := int(target)
		var guard := 0
		while (buckets[difficulty] as Array).is_empty():
			difficulty += 1
			if difficulty >= 5:
				difficulty = 0
				guard += 1
				if guard > 1:
					break
		if guard > 1:
			continue
		var open_bucket: Array = buckets[difficulty]
		var at := _index_of(open_bucket)
		chosen.append(open_bucket[at])
		open_bucket.remove_at(at)
		buckets[difficulty] = open_bucket
	return chosen


func _place_section(section: Dictionary, origin: float, victory: bool) -> void:
	for piece in section.get("blocks", []):
		_place_block(piece, origin)
	var enemy_ids := _subset(section.get("enemyRange", [0, 0]), int(_course.get("enemies", {}).get(_hood_key(), 100)), section.get("enemies", []).size())
	for enemy_id in enemy_ids:
		var enemies: Array = section["enemies"]
		_place_enemy(enemies[enemy_id], origin)
	var treasure_ids := _subset(section.get("treasureRange", [0, 0]), int(_course.get("treasures", {}).get(_hood_key(), 100)), section.get("treasures", []).size())
	for treasure_id in treasure_ids:
		var spots: Array = section["treasures"]
		var spot: Array = spots[treasure_id]
		_place_treasure(origin + float(spot[0]), float(spot[2]), _treasure_value(), false)
	var spawn_ids := _subset(section.get("spawnRange", [0, 0]), int(_course.get("spawns", {}).get(_hood_key(), 100)), section.get("spawns", []).size())
	for spawn_index in spawn_ids.size():
		var spawn_id: int = spawn_ids[spawn_index]
		var points: Array = section["spawns"]
		var point: Dictionary = points[spawn_id]
		var save: Array = point["save"]
		var load_at: Array = point.get("load", save)
		var last := victory and spawn_index == spawn_ids.size() - 1
		_checks.append({
			"x": origin + float(save[0]),
			"z": float(save[2]),
			"load_x": origin + float(load_at[0]),
			"load_z": float(load_at[2]),
			"win": last,
		})
	var stomper_ids := _subset(section.get("stomperRange", [0, 0]), int(_course.get("stomperPercent", {}).get(_hood_key(), 100)), section.get("stompers", []).size())
	for stomper_id in stomper_ids:
		var stompers: Array = section["stompers"]
		_place_stomper(stompers[stomper_id], origin)


func _subset(span: Variant, percent: int, total: int) -> Array[int]:
	var picked: Array[int] = []
	if total <= 0:
		return picked
	var limits: Array = span
	var minimum := int(limits[0]) if limits.size() > 1 else 0
	var maximum := int(limits[1]) if limits.size() > 1 else 0
	var want := int(float(maximum) * float(percent) / 100.0)
	if want < minimum:
		want = minimum
	if want > total:
		want = total
	var bag: Array[int] = []
	for index in total:
		bag.append(index)
	for _step in want:
		if bag.is_empty():
			break
		var at := _index_of(bag)
		picked.append(bag[at])
		bag.remove_at(at)
	picked.sort()
	return picked


func _index_of(bag: Array) -> int:
	if bag.size() <= 1:
		return 0
	return shared_int(bag.size())


func _treasure_value() -> int:
	var roll := shared_int(10)
	if roll < 4:
		return 1
	if roll < 7:
		return 2
	if roll < 9:
		return 3
	return 4


func _place_block(piece: Dictionary, origin: float) -> void:
	var kinds: Dictionary = _course.get("blocks", {})
	var kind: Dictionary = kinds.get(piece.get("type", ""), {})
	var file := String(kind.get("file", "00"))
	var hpr: Array = kind.get("hpr", [0, 0, 0])
	var scale: Array = kind.get("scale", [1, 1, 1])
	var pos: Array = piece["pos"]
	var node := _shaped(_FILES.get(file, _FILES["00"]), origin + float(pos[0]), float(pos[1]), float(pos[2]), float(hpr[0]), float(hpr[1]), float(hpr[2]), float(scale[0]), float(scale[1]), float(scale[2]))
	if node == null:
		return
	var solid := _keep_solid(node)
	if piece.has("end"):
		var ending: Array = piece["end"]
		solid["end"] = Vector3(origin + float(ending[0]), float(ending[2]), -float(ending[1]))
		solid["start"] = node.position
		solid["time"] = float(piece.get("time", 2.0))
		solid["age"] = 0.0
		_solids[_solids.size() - 1] = solid


func _place_enemy(info: Dictionary, origin: float) -> void:
	var pos: Array = info["pos"]
	var code := String(info.get("code", "tm"))
	var path := "res://assets/cogs/suits/%s.glb" % code
	if not ResourceLoader.exists(path):
		path = "res://assets/cogs/flunky.glb"
	var suit := _spawn(path, origin + float(pos[0]), float(pos[1]), float(pos[2]))
	if suit == null:
		return
	var enemy := {
		"node": suit,
		"x": origin + float(pos[0]),
		"z": float(pos[2]),
		"alive": true,
		"vertical": false,
	}
	if info.has("end"):
		var ending: Array = info["end"]
		enemy["x0"] = enemy["x"]
		enemy["z0"] = enemy["z"]
		enemy["x1"] = origin + float(ending[0])
		enemy["z1"] = float(ending[2])
		enemy["time"] = float(info.get("time", 3.5))
		enemy["age"] = 0.0
		enemy["vertical"] = absf(float(ending[2]) - float(pos[2])) > 0.5
	_face_suit(suit, 90.0 if enemy["vertical"] else -90.0)
	if enemy["vertical"]:
		enemy["propeller"] = _add_propeller(suit)
	_enemies.append(enemy)


func _place_treasure(x: float, z: float, value: int, hidden: bool) -> void:
	var which := clampi(value, 1, 4) - 1
	var icon := _spawn(_ICONS[which], x, 0.0, z, 2.5)
	if icon == null:
		return
	icon.visible = not hidden
	_treasures.append({"node": icon, "x": x, "z": z, "value": value, "taken": hidden})


func _place_stomper(info: Dictionary, origin: float) -> void:
	var pos: Array = info["pos"]
	var kind := str(int(info.get("type", 1)))
	var spec: Dictionary = _course.get("stomperTypes", {}).get(kind, {})
	var sized := float(spec.get("scale", 2.0))
	var node := _spawn("res://assets/minigames/toonblitz_stomper.glb", origin + float(pos[0]), float(pos[1]), float(pos[2]))
	if node == null:
		return
	node.scale = Vector3.ONE * sized
	var base_block := node.find_child("block", true, false) as Node3D
	if base_block != null and sized != 0.0:
		base_block.scale = Vector3.ONE / sized
	var head_span: Array = spec.get("head", [0.0, -4.0])
	var shaft_span: Array = spec.get("shaft", [1.0, 6.75])
	_stompers.append({
		"node": node,
		"head": node.find_child("head", true, false),
		"shaft": node.find_child("shaft", true, false),
		"x": origin + float(pos[0]),
		"z": float(pos[2]),
		"scale": sized,
		"period": float(info.get("period", 2.0)),
		"age": 0.0,
		"head0": float(head_span[0]),
		"head1": float(head_span[1]),
		"shaft0": float(shaft_span[0]),
		"shaft1": float(shaft_span[1]),
		"down": false,
	})


func _shaped(path: String, x: float, y: float, z: float, heading: float, pitch: float, roll: float, sx: float, sy: float, sz: float) -> Node3D:
	var node := _spawn(path, x, y, z)
	if node == null:
		return null
	var model := node.get_child(0) as Node3D
	if model == null:
		return node
	model.scale = Vector3(sx, sy, sz)
	var turn := Quaternion(Vector3(0, 0, 1), deg_to_rad(heading))
	var tilt := Quaternion(Vector3(1, 0, 0), deg_to_rad(pitch))
	var twist := Quaternion(Vector3(0, 1, 0), deg_to_rad(roll))
	model.basis = Basis(twist * tilt * turn)
	return node


func _keep_solid(node: Node3D) -> Dictionary:
	var empty := {}
	if node == null:
		return empty
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
		return empty
	var solid := {
		"node": node,
		"base": node.position,
		"minx": box.position.x,
		"maxx": box.position.x + box.size.x,
		"minz": box.position.y,
		"maxz": box.position.y + box.size.y,
	}
	_solids.append(solid)
	return solid


func _box_of(solid: Dictionary) -> Dictionary:
	var node := solid["node"] as Node3D
	var shift := Vector3.ZERO
	if node != null and is_instance_valid(node):
		var base_at: Vector3 = solid["base"]
		shift = node.position - base_at
	return {
		"minx": float(solid["minx"]) + shift.x,
		"maxx": float(solid["maxx"]) + shift.x,
		"minz": float(solid["minz"]) + shift.y,
		"maxz": float(solid["maxz"]) + shift.y,
	}


func _steer() -> void:
	var move := _stick()
	_vx = move.x * _SPEED
	if absf(move.x) > 0.1:
		_heading = -90.0 if move.x > 0.0 else 90.0
	var jumping := move.y > 0.1
	if jumping and not _up_was_down and _grounded and not _head_blocked():
		_vz = _JUMP
		_grounded = false
		_sfx("MG_sfx_vine_game_jump", 0.7)
	_up_was_down = jumping
	if _shoot_wait <= 0.0 and Keybinds.held("jump"):
		_fire()


func _head_blocked() -> bool:
	var crown := _z + _BODY + 0.4
	for solid in _solids:
		var box := _box_of(solid)
		if _x < float(box["minx"]) or _x > float(box["maxx"]):
			continue
		if crown > float(box["minz"]) and _z + 1.0 < float(box["maxz"]):
			return true
	return false


func _push_walls(old_x: float, old_z: float) -> void:
	for solid in _solids:
		var box := _box_of(solid)
		var minx := float(box["minx"])
		var maxx := float(box["maxx"])
		var minz := float(box["minz"])
		var maxz := float(box["maxz"])
		if old_z >= maxz - 0.3:
			continue
		if maxz - minz < 2.0:
			continue
		if old_z + _BODY < minz or old_z > maxz:
			continue
		var was_in := old_x > minx and old_x < maxx
		var now_in := _x > minx and _x < maxx
		if was_in or not now_in:
			continue
		if old_x <= minx:
			_x = minx - 0.05
		else:
			_x = maxx + 0.05


func _land(old_z: float, next_z: float) -> void:
	_grounded = false
	if _vz > 0.0:
		var crown := next_z + _BODY
		for solid in _solids:
			var box := _box_of(solid)
			if _x < float(box["minx"]) + 0.2 or _x > float(box["maxx"]) - 0.2:
				continue
			if old_z + _BODY <= float(box["minz"]) and crown >= float(box["minz"]):
				next_z = float(box["minz"]) - _BODY
				_vz = 0.0
				_sfx("AV_collision", 0.5)
				break
		_z = next_z
		return
	var floor_z := -999.0
	var support := -1
	for index in _solids.size():
		var box := _box_of(_solids[index])
		if _x < float(box["minx"]) or _x > float(box["maxx"]):
			continue
		var top := float(box["maxz"])
		if old_z >= top - 0.2 and next_z <= top and top > floor_z:
			floor_z = top
			support = index
	if support >= 0:
		_z = floor_z
		_vz = 0.0
		_grounded = true
		_support = support
		return
	_support = -1
	_z = next_z


var _support := -1


func _ride() -> void:
	if _support < 0 or _support >= _solids.size():
		return
	var solid: Dictionary = _solids[_support]
	if not solid.has("start"):
		return
	var node := solid["node"] as Node3D
	if node == null:
		return
	var previous: Vector3 = solid.get("prev", node.position)
	var step := node.position - previous
	_x += step.x
	_z += step.y


func _slide_pieces(delta: float) -> void:
	for index in _solids.size():
		var solid: Dictionary = _solids[index]
		if not solid.has("start"):
			continue
		var node := solid["node"] as Node3D
		if node == null:
			continue
		solid["prev"] = node.position
		var age := float(solid["age"]) + delta
		solid["age"] = age
		var span := maxf(float(solid["time"]), 0.1)
		var loop := fmod(age, span * 2.0)
		var along := loop / span
		if along > 1.0:
			along = 2.0 - along
		var start_at: Vector3 = solid["start"]
		var end_at: Vector3 = solid["end"]
		node.position = start_at.lerp(end_at, along)
		_solids[index] = solid
	for index in _enemies.size():
		var enemy: Dictionary = _enemies[index]
		if not enemy["alive"] or not enemy.has("x1"):
			continue
		var age := float(enemy["age"]) + delta
		enemy["age"] = age
		var span := maxf(float(enemy["time"]), 0.1)
		var loop := fmod(age, span * 2.0)
		var along := loop / span
		var forward := along <= 1.0
		if not forward:
			along = 2.0 - along
		enemy["x"] = lerpf(float(enemy["x0"]), float(enemy["x1"]), along)
		enemy["z"] = lerpf(float(enemy["z0"]), float(enemy["z1"]), along)
		var suit := enemy["node"] as Node3D
		if suit != null:
			suit.position = _panda(float(enemy["x"]), 0.0, float(enemy["z"]))
			if enemy["vertical"]:
				var propeller := enemy.get("propeller") as Node3D
				if propeller != null:
					propeller.rotate_object_local(Vector3.UP, delta * 28.0)
			else:
				var facing := -90.0 if float(enemy["x1"]) > float(enemy["x0"]) else 90.0
				if not forward:
					facing = -facing
				_face_suit(suit, facing)
		_enemies[index] = enemy
	for index in _stompers.size():
		var stomper: Dictionary = _stompers[index]
		var age := float(stomper["age"]) + delta
		stomper["age"] = age
		var period := maxf(float(stomper["period"]), 0.2)
		var t := fmod(age, period) / period
		var head0 := float(stomper["head0"])
		var head1 := float(stomper["head1"])
		var span := head1 - head0
		var head_z := head1
		var going_down := false
		if t < 0.2:
			head_z = head1
		elif t < 0.95:
			head_z = head1 + (t - 0.2) * -span / 0.75
		else:
			head_z = -span + (t - 0.95) * span / 0.05 + head1
			going_down = true
		var head := stomper["head"] as Node3D
		if head != null:
			head.position.z = head_z
		var shaft := stomper["shaft"] as Node3D
		if shaft != null and absf(span) > 0.001:
			var stretched := float(stomper["shaft0"]) + (head_z - head0) * (float(stomper["shaft1"]) - float(stomper["shaft0"])) / span
			shaft.scale = Vector3(1.0, 1.0, stretched)
		var was_down: bool = stomper["down"]
		var started: bool = going_down and not was_down
		stomper["down"] = going_down
		stomper["head_z"] = head_z
		if started:
			_try_squish(stomper)
		_stompers[index] = stomper


func _try_squish(stomper: Dictionary) -> void:
	if _mode != "run":
		return
	var sized := float(stomper["scale"])
	var head_z := float(stomper.get("head_z", 0.0))
	var low := float(stomper["z"]) + float(stomper["head1"]) * sized
	var high := float(stomper["z"]) + head_z * sized
	if absf(_x - float(stomper["x"])) > sized:
		return
	if _z <= low or _z >= high:
		return
	_mode = "squish"
	_mode_time = 2.5
	_vx = 0.0
	_vz = 0.0
	score -= 1
	_toon.play_gesture("cringe", 1.0, false)
	_sfx("AV_collision", 0.8)


func _fire() -> void:
	_shoot_wait = 0.55
	_toon.play_gesture("water-gun", 1.0, false)
	_sfx("AA_squirt_seltzer_miss", 0.7)
	var direction := -1.0 if _heading > 0.0 else 1.0
	var mouth := _toon.global_position + Vector3(0.0, 1.6, 0.4)
	_show_spray(mouth, mouth + Vector3(direction * 10.0, 0.2, 0.0))
	var closest := -1
	var nearest := 10.0
	for index in _enemies.size():
		var enemy: Dictionary = _enemies[index]
		if not enemy["alive"]:
			continue
		var ahead := (float(enemy["x"]) - _x) * direction
		if ahead < 0.4 or ahead > nearest:
			continue
		if absf((float(enemy["z"]) + 2.0) - (_z + 3.0)) > 2.6:
			continue
		nearest = ahead
		closest = index
	if closest < 0:
		return
	var enemy: Dictionary = _enemies[closest]
	enemy["alive"] = false
	var suit := enemy["node"] as Node3D
	if suit != null:
		suit.visible = false
	_enemies[closest] = enemy
	_place_treasure(float(enemy["x"]), float(enemy["z"]) + 2.0, maxi(party_size(), 1), false)
	_sfx("Seltzer_squirt_2dgame_hit")


func _touch_enemy() -> void:
	if _mode != "run":
		return
	for enemy in _enemies:
		if not enemy["alive"]:
			continue
		if absf(float(enemy["x"]) - _x) > 1.8:
			continue
		if absf((float(enemy["z"]) + 2.0) - (_z + 1.4)) > 2.2:
			continue
		_hurt()
		return


func _hurt() -> void:
	_mode = "hurt"
	_mode_time = 2.0
	_knock = 0.75
	_vz = 12.0
	_vx = 12.0 if _heading > 0.0 else -12.0
	score -= 1
	_toon.play_gesture("slip-backward", 1.0, false)
	_sfx("MG_cannon_hit_dirt", 0.7)


func _touch_treasure() -> void:
	for index in _treasures.size():
		var item: Dictionary = _treasures[index]
		if item["taken"]:
			continue
		var dx := float(item["x"]) - _x
		var dz := float(item["z"]) - _z
		if dx * dx + dz * dz > 1.3 * 1.3:
			continue
		item["taken"] = true
		var icon := item["node"] as Node3D
		if icon != null:
			icon.visible = false
		score += int(item["value"])
		_sfx("SZ_DD_treasure")
		_sfx("sparkly", 0.6)
		_treasures[index] = item


func _touch_checkpoint() -> void:
	if _mode != "run":
		return
	for point in _checks:
		var dx := float(point["x"]) - _x
		var dz := float(point["z"]) - _z
		if dx * dx + dz * dz > 9.0:
			continue
		_respawn = Vector2(float(point["load_x"]), float(point["load_z"]))
		if point["win"] and not _won:
			_escape()
		return


func _drop() -> void:
	_mode = "fall"
	_mode_time = 1.0
	_vx = 0.0
	_vz = 0.0
	_sfx("MG_sfx_vine_game_fall")


func _escape() -> void:
	_won = true
	_mode = "win"
	_mode_time = 1.5
	var left := maxf(duration, 0.0)
	var extra := int(float(_bonus) + 0.8 * left)
	if extra < 0:
		extra = 0
	score += extra
	_sfx("threeSparkles")
	_toon.play_gesture("victory", 1.0, true)


func _finish_run(delta: float) -> void:
	_mode_time -= delta
	_x = move_toward(_x, _exit_x, _SPEED * delta)
	_z = move_toward(_z, 13.6, 8.0 * delta)
	_heading = -90.0
	_put_toon()
	if _mode_time <= 0.0:
		_end()


func _put_toon() -> void:
	_toon.position = _panda(_x, 0.0, _z)
	_toon.rotation_degrees = Vector3(0.0, _heading + 180.0, 0.0)
	if _mode == "run" and _shoot_wait <= 0.2:
		_toon.set_locomotion(_vx, false, not _grounded, get_process_delta_time())


func _add_propeller(suit: Node3D) -> Node3D:
	var head := suit.find_child("joint_head", true, false) as Node3D
	if head == null:
		return null
	var packed := load("res://assets/cogs/props/propeller.glb") as PackedScene
	if packed == null:
		return null
	var propeller := packed.instantiate() as Node3D
	if propeller == null:
		return null
	propeller.name = "Propeller"
	head.add_child(propeller)
	propeller.scale = Vector3.ONE * 1.1
	return propeller


func _show_spray(origin: Vector3, target: Vector3) -> void:
	var packed := load("res://assets/battle/props/spray.glb") as PackedScene
	if packed == null:
		return
	var mesh := packed.instantiate() as Node3D
	if mesh == null:
		return
	add_child(mesh)
	mesh.global_position = origin
	if origin.distance_squared_to(target) > 0.04:
		mesh.look_at(target, Vector3.UP)
		mesh.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		mesh.rotate_object_local(Vector3.UP, PI)
	var length := clampf(origin.distance_to(target), 1.0, 12.0)
	mesh.scale = Vector3(0.05, 0.05, 0.05)
	_sprays.append({"mesh": mesh, "age": 0.0, "length": length / 1.5})


func _tick_sprays(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for spray in _sprays:
		var age := float(spray["age"]) + delta
		spray["age"] = age
		var mesh := spray["mesh"] as Node3D
		if mesh != null and age < 0.45:
			var grow := clampf(age / 0.12, 0.0, 1.0)
			if age > 0.28:
				grow = clampf(1.0 - (age - 0.28) / 0.17, 0.05, 1.0)
			var length := float(spray["length"])
			mesh.scale = Vector3(length * grow, length * grow, length * grow)
			kept.append(spray)
		elif mesh != null:
			mesh.queue_free()
	_sprays = kept


func _face_suit(suit: Node3D, heading: float) -> void:
	# Street suits face +X at yaw -90. That is also this game's heading for running right.
	suit.rotation_degrees.y = heading


func _frame() -> void:
	var lead := sin(deg_to_rad(_heading)) * 2.0
	_camera.position = _panda(_x - lead, -53.0, 17.3)
	_camera.rotation = Vector3.ZERO
