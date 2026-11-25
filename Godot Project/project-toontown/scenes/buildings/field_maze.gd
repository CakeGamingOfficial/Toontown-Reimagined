extends Node

## DistCogdoMazeGame. CogdoMazeFactory joins nine quadrant rooms. The big cogs
## are Mover & Shakers. Defeating every one opens the exit. Name Droppers and
## Cold Callers drop memos, and the memo count plus the clock make the score.
## Water balloons come from the coolers. A cabinet only pops a balloon.

const _DATA := "res://assets/buildings/field_office/field_maze.json"
const _LEVEL := "res://assets/buildings/field_office/field_maze_level.glb"
const _DIVIDER := "res://assets/buildings/field_office/field_maze_divider.glb"
const _EXIT := "res://assets/buildings/field_office/field_maze_exit.glb"
const _MEMO := "res://assets/buildings/field_office/field_maze_memo.glb"
const _BALLOON := "res://assets/buildings/field_office/field_maze_balloon.glb"
const _MAP_FRAME := "res://assets/buildings/field_office/minimap_frame.png"
const _MAP_ICONS := "res://assets/buildings/field_office/minimap_icons.png"
const _MEMO_CARD := "res://assets/buildings/field_office/field_memo_card.glb"
const _BOSS_GUI := "res://assets/buildings/field_office/field_boss_gui.glb"
const _ARROW := "res://assets/buildings/field_office/field_arrow.glb"
const _SHADOW := "res://assets/cog_hq/square_drop_shadow.jpg"
const _CABINET := "res://assets/buildings/field_office/field_maze_cabinet.glb"
const _MUSIC := "res://assets/cog_hq/audio/CHQ_FACT_bg.ogg"
const _RUSH := "res://assets/buildings/cog/audio/encntr_suit_winning_indoor.ogg"
const _PICKUP := "res://assets/audio/sfx/MG_maze_pickup.ogg"
const _THROW := "res://assets/audio/sfx/AA_pie_throw_only.ogg"
const _HIT := "res://assets/audio/sfx/MG_cannon_hit_dirt.ogg"
const _FILL := "res://assets/audio/sfx/tt_s_ara_cmg_waterCoolerFill.ogg"
const _STOMP := "res://assets/audio/sfx/tt_s_ara_cmg_cogStomp.ogg"
const _QUAKE := "res://assets/audio/sfx/tt_s_ara_cmg_groundquake.ogg"
const _LAND := "res://assets/audio/sfx/tt_s_ara_cmg_itemHitsFloor.ogg"
const _DROP_HIT := "res://assets/audio/sfx/tt_s_ara_cmg_toonHit.ogg"
const _SPLAT := "res://assets/audio/sfx/SA_watercooler_spray_only.ogg"
const _WIN := "res://assets/audio/sfx/MG_win.ogg"
const _LOSE := "res://assets/audio/sfx/MG_lose.ogg"
const _SPIN := "res://assets/audio/battle/Cog_Death.ogg"
const _FALL_APART := "res://assets/audio/battle/ENC_cogfall_apart.ogg"
const _ANGRY := "res://assets/audio/sfx/tt_s_ara_cmg_bossCogAngry.ogg"
const _BARK := "res://assets/audio/dial/AV_dog_long.mp3"
const _SPLASH := "res://assets/buildings/field_office/field_splash.glb"
const _LAFF_HEADS: Dictionary = {
	"d": preload("res://assets/gui/tutorial/laff/doghead.png"),
	"c": preload("res://assets/gui/tutorial/laff/cathead.png"),
	"h": preload("res://assets/gui/tutorial/laff/horsehead.png"),
	"m": preload("res://assets/gui/tutorial/laff/mousehead.png"),
	"r": preload("res://assets/gui/tutorial/laff/bunnyhead.png"),
	"f": preload("res://assets/gui/tutorial/laff/duckhead.png"),
	"p": preload("res://assets/gui/tutorial/laff/monkeyhead.png"),
	"b": preload("res://assets/gui/tutorial/laff/bearhead.png"),
	"s": preload("res://assets/gui/tutorial/laff/pighead.png"),
}
const _STOMP_WAIT := 0.53
const _BOSS_REACH := 25.0
const _DROP_REACH := 20.0
const _VICTORY_TIME := 217.0 / 24.0

const _CELL := 3.0
const _ROOM := 16
const _GRID := 3
const _FRAME := 1
const _SPAN := 51.0
const _TIMEOUT := 240.0
const _ALERT := 60.0
const _EXIT_TIME := 60.0
const _PERFECT := 90.0
const _MAX_TIME := 210.0
const _RUN := 11.2
const _THROW_TIME := 0.5
const _THROW_REACH := 18.0
const _HURT_WAIT := 2.0
const _BALLOON_WAIT := 1.2
const _HINT_TIME := 6.0
const _DOOR_SLIDE := 3.5
const _INTRO_TIME := 24.0
const _INTRO: PackedStringArray = [
	"This is the Toon Resistance! The Movers & Shakers\nhave our Jokes, and they've locked the exit!",
	"Grab water balloons at coolers, and throw them at Cogs!\nSmall Cogs drop Jokes, BIG COGS open the exit.",
	"The more Jokes you rescue, the bigger your Toon-Up\nat the end. Good luck!",
]

const _UP := 0
const _DOWN := 1
const _LEFT := 2
const _RIGHT := 3
const _HEADING: Array[int] = [0, 180, 90, 270]

var _live := false
var _run_id := -1
var _district := 0
var _slug := ""
var _acts: Array = []
var _act_at := 0
var _asked: Dictionary = {}
var _left_maze := false
var _catching := false
var _pals: Array[TextureRect] = []
var _age := 0.0
var _hurt := 0.0
var _cool := 0.0
var _hint_left := 0.0
var _open := false
var _told_exit := false
var _intro := 0.0
var _intro_phase := -1
var _slip := 0.0
var _slip_at := Vector3.ZERO
var _release := -1.0
var _code := ""
var _revealed: Array[bool] = [false, false, false, false]
var _code_label: Label
var _open_left := 0.0
var _opened_at := 0.0
var _alerted := false
var _jump_was := false
var _has_gag := false
var _memos := 0
var _max_memos := 1
var _bosses := 0
var _floor_y := 0.0
var _last_pos := Vector3.ZERO
var _shake := 0.0
var _width := 0
var _height := 0
var _origin := 0
var _book: Dictionary = {}
var _cells := PackedByteArray()
var _roll: MazeRoll
var _root: Node3D
var _hud: Label
var _card: Panel
var _line: Label
var _hint_text := ""
var _map_root: Control
var _map_rect: TextureRect
var _map_image: Image
var _map_tex: ImageTexture
var _seen := PackedByteArray()
var _you: TextureRect
var _enter_icon: TextureRect
var _exit_icon: TextureRect
var _cog_icons: Array[TextureRect] = []
var _cooler_icons: Array[TextureRect] = []
var _portrait: Control
var _memo_card: Control
var _boss_card: Control
var _boss_closed: Node3D
var _boss_open: Node3D
var _digits: Array[Label] = []
var _flash: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _arrows: Array[Node3D] = []
var _quest: Node3D
var _quake: AudioStreamPlayer
var _stomp_left := 0.0
var _splats: Array[Dictionary] = []
var _toon: Node
var _exit_at := Vector3.ZERO
var _left_door: Node3D
var _right_door: Node3D
var _left_open := Vector3.ZERO
var _right_open := Vector3.ZERO
var _gag: Node3D
var _suits: Array[Dictionary] = []
var _drops: Array[Dictionary] = []
var _shots: Array[Dictionary] = []
var _falls: Array[Dictionary] = []
var _coolers: Array[Vector2] = []


class MazeRoll:
	var _rng := RandomNumberGenerator.new()

	func _init(seed_value: int) -> void:
		_rng.seed = seed_value

	func pick(span: int) -> int:
		if span <= 1:
			return 0
		return _rng.randi_range(0, span - 1)

	func shuffle(items: Array) -> void:
		var index := items.size() - 1
		while index > 0:
			var swap := pick(index + 1)
			var kept: Variant = items[index]
			items[index] = items[swap]
			items[swap] = kept
			index -= 1


func _ready() -> void:
	# Lower priorities run first. The street camera is 0, so this aims after it.
	process_priority = 20


func running() -> bool:
	return _live


func begin(run: Dictionary, origin: Vector3, toon: Node) -> void:
	if _live and _run_id == int(run.get("id", -1)):
		return
	clear()
	_live = true
	_run_id = int(run.get("id", -1))
	_district = int(run.get("district", 0))
	_slug = String(run.get("slug", ""))
	_age = 0.0
	_open = false
	_told_exit = false
	_open_left = 0.0
	_opened_at = 0.0
	_alerted = false
	_has_gag = false
	_memos = 0
	_toon = toon
	_roll = MazeRoll.new(maxi(int(run.get("maze_seed", 1)), 1))
	_book = _read_book()
	_root = Node3D.new()
	_root.name = "FieldMaze"
	_root.position = origin
	add_child(_root)
	if _book.is_empty():
		_finish(toon, false)
		return
	_layout_rooms()
	_assemble()
	_place_level()
	_place_rooms()
	_place_dividers()
	_place_exit()
	_build_collision()
	_spawn_suits()
	_build_hud()
	_build_arrows()
	_tune(_MUSIC, 0.8)
	_intro = _INTRO_TIME
	_intro_phase = -1
	_set_doors(0.0)
	var body := _body_of(toon)
	_plant(toon, _entrance_tile())
	if body != null:
		_floor_y = _root.global_position.y
		body.global_position.y = _floor_y
		_last_pos = body.global_position
	if toon != null:
		toon.call("hold_for_battle", false)


func play(delta: float, toon: Node) -> void:
	if not _live or toon == null:
		return
	_toon = toon
	var body := _body_of(toon)
	if body == null:
		return
	if _intro > 0.0:
		_intro = maxf(_intro - delta, 0.0)
		_play_intro(body)
		_paint_map(body)
		_write_hud()
		if _intro <= 0.0:
			_set_doors(1.0)
			_say("Grab water balloons at coolers, and throw them at Cogs!")
		return
	_hurt = maxf(_hurt - delta, 0.0)
	_slip = maxf(_slip - delta, 0.0)
	_cool = maxf(_cool - delta, 0.0)
	_hint_left = maxf(_hint_left - delta, 0.0)
	var clock := _cogdo_clock()
	if ToonNet.networked():
		if clock >= 0.0:
			_catch_up(clock)
	else:
		_age += delta
		_move_suits(delta)
	if _open:
		_open_left = maxf(_EXIT_TIME - (_age - _opened_at), 0.0)
	if _left_maze:
		if body is CharacterBody3D:
			(body as CharacterBody3D).velocity = Vector3.ZERO
		body.global_position = _last_pos
		_paint_map(body)
		_write_hud()
		return
	_release_throw(body, delta)
	_tick_arrows(body, delta)
	_tick_splats(delta)
	_rumble_bosses(body, delta)
	_tick_quake()
	_clamp_toon(body, delta)
	_hold_balloon(body)
	_spin_memos(delta)
	_touch_suits(body, toon)
	if not _live:
		return
	_gather(body)
	_coolers_near(body)
	_shots_fly(delta)
	_cabinets(delta, body)
	var jumping := Keybinds.held("jump")
	if jumping and not _jump_was:
		_throw(body)
	_jump_was = jumping
	_slide_doors(delta)
	_paint_map(body)
	_write_hud()
	if not _open and _age >= _TIMEOUT - _ALERT and not _alerted:
		_alerted = true
		_tune(_RUSH, 0.9)
		_say("Hurry up! 60 seconds to go!")
	if not _open and _age >= _TIMEOUT and not ToonNet.networked():
		_finish(toon, false)
		return
	if _open:
		_open_left = maxf(_EXIT_TIME - (_age - _opened_at), 0.0)
		if _open_left <= 0.0 and not ToonNet.networked():
			_finish(toon, true)
			return
		if body.global_position.distance_to(_exit_at) < 3.0:
			if ToonNet.networked():
				if not _left_maze:
					_left_maze = true
					_tell("door", 0, 0.0, 0.0, 0.0)
					_sfx(_WIN)
					_say("Waiting for other Toons...")
			else:
				_finish(toon, true)


func _process(_delta: float) -> void:
	if not _live or _root == null:
		return
	var body := _body_of(_toon)
	var camera := get_viewport().get_camera_3d()
	if body == null or camera == null:
		return
	if _intro > 0.0:
		_aim_intro(camera)
		return
	# CogdoMazeCameraManager. Pitch 60, at least 40 back, clamped inside the rooms.
	var local := _root.to_local(body.global_position)
	var panda := Vector2(local.x, -local.z)
	var low := _corner_panda(3, 5)
	var high := _corner_panda(_width - 3, _height - 3)
	panda.x = clampf(panda.x, low.x, high.x)
	panda.y = clampf(panda.y, low.y, high.y)
	var anchor := _root.to_global(Vector3(panda.x, 3.0, -panda.y))
	_shake = maxf(_shake - 2.2 * _delta, 0.0)
	var rumble := sin(_age * 48.0) * _shake * 0.08
	camera.global_position = anchor + Vector3(rumble, 34.64, 20.0 + rumble * 0.35)
	camera.fov = 52.0
	var look := body.global_position + Vector3(0.0, 3.0, 0.0)
	if camera.global_position.distance_squared_to(look) > 0.04:
		camera.look_at(look, Vector3.UP)


func _play_intro(body: Node3D) -> void:
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO
	body.global_position = _last_pos
	var phase := 0
	if _intro <= 8.0:
		phase = 2
	elif _intro <= 16.0:
		phase = 1
	if phase != _intro_phase and phase < _INTRO.size():
		_intro_phase = phase
		_say(_INTRO[phase])
		_sfx(_BARK)
	var closing := 1.0
	if _intro > 16.0:
		closing = clampf((_INTRO_TIME - _intro) / 8.0, 0.0, 1.0)
	_set_doors(closing)
	_pose_intro_boss()


func _aim_intro(camera: Camera3D) -> void:
	var look := _exit_at + Vector3(0.0, 4.0, 0.0)
	var at := _exit_at + Vector3(0.0, 14.0, 22.0)
	if _intro <= 16.0 and _intro > 8.0 and not _coolers.is_empty():
		var cooler: Vector2 = _coolers[0]
		look = _root.to_global(Vector3(cooler.x, 2.0, cooler.y))
		at = look + Vector3(-12.0, 10.0, 12.0)
	elif _intro <= 8.0:
		for suit in _suits:
			if suit["boss"] != true:
				continue
			var actor: Node3D = suit["actor"]
			if actor == null:
				continue
			look = actor.global_position + Vector3(0.0, 6.0, 0.0)
			at = look + Vector3(0.0, 8.0, 18.0)
			break
	camera.global_position = at
	camera.fov = 52.0
	if camera.global_position.distance_squared_to(look) > 0.04:
		camera.look_at(look, Vector3.UP)


func _pose_intro_boss() -> void:
	# CogdoMazeIntroMovie. Effort plays once during the exit shot.
	# Victory loops once the camera is on the boss. Suit B's victory clip is 217 frames.
	var elapsed := _INTRO_TIME - _intro
	for suit in _suits:
		if suit.get("boss") != true:
			continue
		var actor: Node3D = suit["actor"]
		if not (actor is StreetCog):
			break
		var cog := actor as StreetCog
		if _intro <= 8.0:
			cog.play_attack("victory", fposmod(8.0 - _intro, _VICTORY_TIME))
		elif elapsed >= 2.0:
			cog.play_attack("effort", elapsed - 2.0)
		break


func _set_doors(closed: float) -> void:
	var blend := clampf(closed, 0.0, 1.0)
	if _left_door != null:
		_left_door.position = _left_open.lerp(Vector3(_DOOR_SLIDE, 0.0, 0.0), blend)
	if _right_door != null:
		_right_door.position = _right_open.lerp(Vector3(-_DOOR_SLIDE, 0.0, 0.0), blend)


func clear() -> void:
	_live = false
	_left_maze = false
	_catching = false
	_act_at = 0
	_acts = []
	_asked = {}
	_pals.clear()
	_suits.clear()
	_drops.clear()
	_shots.clear()
	_falls.clear()
	_coolers.clear()
	_cells = PackedByteArray()
	_gag = null
	_left_door = null
	_right_door = null
	_map_image = null
	_map_tex = null
	_map_root = null
	_portrait = null
	_memo_card = null
	_boss_card = null
	_boss_closed = null
	_boss_open = null
	_digits.clear()
	_arrows.clear()
	_quest = null
	_you = null
	_splats.clear()
	_stomp_left = 0.0
	if _quake != null:
		_quake.stop()
		_quake = null
	_enter_icon = null
	_exit_icon = null
	_cog_icons.clear()
	_cooler_icons.clear()
	_seen = PackedByteArray()
	if _root != null:
		_root.queue_free()
		_root = null
	for child in get_children():
		child.queue_free()


func busy() -> bool:
	return _live


func reached_exit() -> bool:
	return _left_maze


func shutdown(made_it: bool) -> void:
	_finish(_toon, made_it)


func _finish(toon: Node, made_it: bool) -> void:
	if not _live:
		return
	if made_it:
		if not _left_maze:
			_sfx(_WIN)
	else:
		_sfx(_LOSE)
	var score := _score()
	var hood := _hood_difficulty()
	var loadout: ToonLoadout = null
	if toon != null:
		loadout = toon.call("battle_loadout") as ToonLoadout
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
	var district := 0
	var slug := ""
	var host := get_parent()
	if host != null:
		district = int(host.call("_district"))
		slug = String(host.call("_slug"))
	var run_id := _run_id
	clear()
	if toon != null:
		toon.call("hold_for_battle", true)
	if runs != null and runs.has_method("maze_result"):
		runs.call("maze_result", district, slug, run_id, made_it)


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
	# MinigameGlobals.SafeZones. Toontown Central is the easy end.
	var order: Array[int] = [2000, 1000, 5000, 4000, 3000, 9000]
	var index := order.find(hood)
	if index < 0:
		index = 0
	return float(index) / 5.0


func _read_book() -> Dictionary:
	if not FileAccess.file_exists(_DATA):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_DATA))
	if parsed is Dictionary:
		return parsed
	return {}


func _assemble() -> void:
	_width = (_GRID + 1) * _FRAME + _GRID * _ROOM
	_height = _width
	_origin = int(_width / 2)
	var rows: Array = []
	var wall: Array = []
	for _x in _width:
		wall.append(1)
	rows.append(wall.duplicate())
	for band in _GRID:
		for local_y in _ROOM:
			var row: Array = [1]
			for local_x in _GRID:
				var flat := band * _GRID + local_x
				var picked: Dictionary = _layout[flat]
				var line := _quad_row(int(picked["quad"]), int(picked["angle"]), local_y)
				for cell in line:
					var value := int(cell)
					if flat == 1 and local_y < 6 and value == 0:
						value = 2
					row.append(value)
				row.append(1)
			rows.append(row)
		rows.append(wall.duplicate())
	var barriers: Array = _book.get("barriers", [])
	for group in barriers:
		if not (group is Array):
			continue
		for pair in group:
			if not (pair is Array) or (pair as Array).size() < 2:
				continue
			var spot: Array = pair
			var sx := int(spot[0])
			var sy := int(spot[1])
			if sy >= 0 and sy < rows.size():
				var row: Array = rows[sy]
				if sx >= 0 and sx < row.size():
					row[sx] = 0
	for x in _width:
		var across: Array = rows[_origin]
		if int(across[x]) == 0:
			across[x] = 2
	for y in rows.size():
		var down: Array = rows[y]
		if int(down[_origin]) == 0:
			down[_origin] = 2
	_cells.resize(_width * _height)
	for y in _height:
		var row: Array = rows[y]
		for x in _width:
			_cells[y * _width + x] = int(row[x])


var _layout: Array = []


func _layout_rooms() -> void:
	var keys: Array = [0, 1, 2, 3, 4, 5, 6, 7, 8]
	var angles: Array = [0, 90, 180, 270]
	_roll.shuffle(keys)
	_layout = []
	var cursor := 0
	for y in _GRID:
		for x in _GRID:
			_layout.append({
				"quad": int(keys[cursor]),
				"angle": int(angles[_roll.pick(4)]),
				"x": x,
				"y": y,
			})
			cursor += 1


func _quad_row(quad: int, angle: int, row: int) -> Array:
	var tables: Array = _book.get("tables", [])
	if quad < 0 or quad >= tables.size():
		return []
	var book: Array = tables[quad]
	var index := int(angle / 90)
	if index < 0 or index >= book.size():
		return []
	var angled: Array = book[index]
	if row < 0 or row >= angled.size():
		return []
	var line: Variant = angled[row]
	if line is Array:
		return line
	return []


func _cell(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= _width or y >= _height:
		return 1
	return _cells[y * _width + x]


func _walkable(tx: int, ty: int, taken: Array) -> bool:
	if tx <= 0 or ty <= 0 or tx >= _width or ty >= _height:
		return false
	if _cell(tx, ty) != 0 or _cell(tx - 1, ty) != 0:
		return false
	if _cell(tx, ty - 1) != 0 or _cell(tx - 1, ty - 1) != 0:
		return false
	var spot := Vector2i(tx, ty)
	for item in taken:
		if item == spot:
			return false
	return true


func _open_tile(tx: int, ty: int) -> bool:
	return _cell(tx, ty) != 1


func _entrance_tile() -> Vector2i:
	var tx := int(float(_width) / 2.0)
	var ty := 2
	while ty < _height and not _open_tile(tx, ty):
		ty += 1
	return Vector2i(tx, ty)


func _place_level() -> void:
	var packed := load(_LEVEL) as PackedScene
	if packed == null:
		return
	var level := packed.instantiate()
	_root.add_child(level)
	_hide_cones(level)


func _place_rooms() -> void:
	for item in _layout:
		var picked: Dictionary = item
		var quad := int(picked["quad"])
		var angle := int(picked["angle"])
		var x := int(picked["x"])
		var y := int(picked["y"])
		var ax := float(x - 1) * _SPAN
		var ay := float(y - 1) * _SPAN
		var wrap := Node3D.new()
		wrap.position = Vector3(ax, 0.0, -ay)
		wrap.rotation_degrees = Vector3(0.0, float(angle), 0.0)
		var packed := load(_quad_path(quad)) as PackedScene
		if packed != null:
			var room := packed.instantiate()
			wrap.add_child(room)
			_hide_cones(room)
		_root.add_child(wrap)
		_keep_coolers(quad, angle, ax, ay)


func _quad_path(index: int) -> String:
	return "res://assets/buildings/field_office/field_maze_quadrant%d.glb" % (index + 1)


func _keep_coolers(quad: int, angle: float, ax: float, ay: float) -> void:
	var rooms: Array = _book.get("quadrants", [])
	if quad < 0 or quad >= rooms.size() or not (rooms[quad] is Dictionary):
		return
	var room: Dictionary = rooms[quad]
	var coolers: Array = room.get("coolers", [])
	for item in coolers:
		if not (item is Dictionary):
			continue
		var cooler: Dictionary = item
		var pos: Array = cooler.get("pos", [])
		if pos.size() < 2:
			continue
		var turned := _turn(Vector2(float(pos[0]), float(pos[1])) + _turn(Vector2(0.0, -1.5), float(cooler.get("h", 0.0))), angle)
		var world := Vector2(ax, ay) + turned
		_coolers.append(Vector2(world.x, -world.y))


func _place_dividers() -> void:
	var packed := load(_DIVIDER) as PackedScene
	if packed == null:
		return
	# The north frame, skipping the middle gap, then the west and east frames.
	for x in _GRID:
		if x == 1:
			continue
		var ax := float(x - 1) * _SPAN
		var ay := float(3 - 1) * _SPAN - _ROOM * _CELL * 0.5 - (_CELL - 0.5)
		_add_divider(packed, ax, ay, 0.0)
	var offset := _CELL - 0.5
	var edges: Array[int] = [0, 3]
	for x in edges:
		for y in _GRID:
			var ax := float(x - 1) * _SPAN - _ROOM * _CELL * 0.5 - _CELL + offset
			var ay := float(y - 1) * _SPAN
			_add_divider(packed, ax, ay, 90.0)
		offset -= 2.0


func _add_divider(packed: PackedScene, px: float, py: float, heading: float) -> void:
	var wrap := Node3D.new()
	wrap.position = Vector3(px, 0.0, -py)
	wrap.rotation_degrees = Vector3(0.0, heading, 0.0)
	_root.add_child(wrap)
	var whole := packed.instantiate()
	# CogdoMazeFactory instances the first divider node, not the whole grouping.
	var piece := _exact(whole, "divider")
	if piece != null:
		var copy := piece.duplicate()
		copy.owner = null
		wrap.add_child(copy)
		whole.queue_free()
	else:
		wrap.add_child(whole)


func _place_exit() -> void:
	var spot: Array = _book.get("exit", [])
	var px := 0.0
	var py := 74.5
	var heading := 0.0
	if spot.size() >= 2:
		px = float(spot[0])
		py = float(spot[1])
	if spot.size() >= 4:
		heading = float(spot[3])
	var wrap := Node3D.new()
	wrap.position = Vector3(px, 0.0, -py)
	wrap.rotation_degrees = Vector3(0.0, heading, 0.0)
	var packed := load(_EXIT) as PackedScene
	if packed != null:
		var door := packed.instantiate()
		wrap.add_child(door)
		_left_door = _named(door, "left_door")
		_right_door = _named(door, "right_door")
		if _left_door != null:
			_left_open = _left_door.position
			_left_door.position = Vector3(_DOOR_SLIDE, 0.0, 0.0)
		if _right_door != null:
			_right_open = _right_door.position
			_right_door.position = Vector3(-_DOOR_SLIDE, 0.0, 0.0)
	_root.add_child(wrap)
	_exit_at = wrap.global_position


func _slide_doors(_delta: float) -> void:
	if not _open:
		return
	# ElevatorUtils opens a normal door in 2 seconds.
	var blend := clampf((_EXIT_TIME - _open_left) / 2.0, 0.0, 1.0)
	if _left_door != null:
		_left_door.position = Vector3(_DOOR_SLIDE, 0.0, 0.0).lerp(_left_open, blend)
	if _right_door != null:
		_right_door.position = Vector3(-_DOOR_SLIDE, 0.0, 0.0).lerp(_right_open, blend)


func _build_collision() -> void:
	var solid := StaticBody3D.new()
	solid.name = "MazeSolids"
	_root.add_child(solid)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	var span := float(_width) * _CELL
	floor_box.size = Vector3(span, 2.0, span)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0.0, -1.0, 0.0)
	solid.add_child(floor_shape)
	for y in _height:
		var x := 0
		while x < _width:
			if _cell(x, y) != 1:
				x += 1
				continue
			var start := x
			while x < _width and _cell(x, y) == 1:
				x += 1
			var length := x - start
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(_CELL * float(length), 12.0, _CELL)
			shape.shape = box
			var cx := (float(start) + float(length) * 0.5 - float(_origin)) * _CELL
			var cz := (float(y) + 0.5 - float(_origin)) * _CELL
			shape.position = Vector3(cx, 6.0, -cz)
			solid.add_child(shape)


func _spawn_suits() -> void:
	var diff := _hood_difficulty()
	var counts: Array[int] = [
		4,
		5 + int(round(diff * 6.0)),
		5 + int(round(diff * 9.0)),
	]
	_bosses = counts[0]
	_max_memos = counts[1] * 3 + counts[2] * 2
	_code = ""
	_revealed = [false, false, false, false]
	for _digit in 4:
		_code += "0123456789ABCDEF".substr(_roll.pick(16), 1)
	var taken: Array = []
	var spots: Array = []
	for count in counts:
		spots.append(_spot_list(count, taken))
	var kinds: Array[Dictionary] = [
		{"code": "ms", "hp": 2, "memos": 0, "damage": 3, "scale": 2.5, "period": 192.0 * 2.0, "boss": true},
		{"code": "nd", "hp": 1, "memos": 3, "damage": 1, "scale": 1.3, "period": 64.0, "boss": false},
		{"code": "cc", "hp": 1, "memos": 2, "damage": 2, "scale": 1.33, "period": 160.0, "boss": false},
	]
	var serial := 0
	for kind_index in kinds.size():
		var kind: Dictionary = kinds[kind_index]
		var group: Array = spots[kind_index]
		for spot in group:
			var tile: Vector2i = spot
			tile = _nudge(tile)
			var dur := float(kind["period"]) / 256.0
			var actor := _make_suit(String(kind["code"]), float(kind["scale"]))
			var suit := {
				"id": serial,
				"hp": int(kind["hp"]),
				"memos": int(kind["memos"]),
				"damage": int(kind["damage"]),
				"scale": float(kind["scale"]),
				"dur": dur,
				"boss": kind["boss"] == true,
				"slot": serial if kind["boss"] == true else -1,
				"dying": -1.0,
				"tx": tile.x,
				"ty": tile.y,
				"nx": tile.x,
				"ny": tile.y,
				"dir": _DOWN,
				"age": dur,
				"thinks": 0,
				"actor": actor,
				"from": _corner(tile.x, tile.y),
				"to": _corner(tile.x, tile.y),
			}
			if actor != null:
				actor.position = _corner(tile.x, tile.y)
				_face_suit(actor, float(_HEADING[_DOWN]))
			_suits.append(suit)
			serial += 1


func _spot_list(length: int, taken: Array) -> Array:
	var half := int(_width / 2)
	var quads: Array = [
		Rect2i(0, 0, half, half),
		Rect2i(half, 0, _width - half, half),
		Rect2i(0, half, half, _height - half),
		Rect2i(half, half, _width - half, _height - half),
	]
	_roll.shuffle(quads)
	var found: Array = []
	var remaining := length
	for quad in quads:
		var box: Rect2i = quad
		var share := int(length / 4)
		for _n in share:
			found.append(_spot_in(box, taken))
		remaining -= share
	for _n in remaining:
		var box: Rect2i = quads[_roll.pick(quads.size())]
		found.append(_spot_in(box, taken))
	return found


func _spot_in(box: Rect2i, taken: Array) -> Vector2i:
	var wide := maxi(box.size.x, 1)
	var tall := maxi(box.size.y, 1)
	for _try in 80:
		var tx := box.position.x + _roll.pick(wide)
		var ty := box.position.y + _roll.pick(tall)
		if _walkable(tx, ty, taken):
			var spot := Vector2i(tx, ty)
			taken.append(spot)
			return spot
	return Vector2i(maxi(box.position.x, 1), maxi(box.position.y, 1))


func _nudge(tile: Vector2i) -> Vector2i:
	var tx := tile.x
	var ty := tile.y
	var step := 0
	var limit := 0
	var toggle := 0
	var direction := 0
	var guard := 0
	while not _walkable(tx, ty, []) and guard < 400:
		if direction == 0:
			tx -= 1
		elif direction == 1:
			ty -= 1
		elif direction == 2:
			tx += 1
		else:
			ty += 1
		step += 1
		if step > limit:
			step = 0
			direction = (direction + 1) % 4
			toggle += 1
			if toggle % 2 == 0:
				limit += 1
		guard += 1
	return Vector2i(tx, ty)


func _make_suit(code: String, suit_scale: float) -> StreetCog:
	var cog := StreetCog.new()
	_root.add_child(cog)
	cog.present(_cog_row(code), {})
	cog.set_process(false)
	cog.scale = Vector3.ONE * suit_scale
	return cog


func _cog_row(code: String) -> Dictionary:
	for item in CogCatalog.cog_rows():
		if item is Dictionary and String((item as Dictionary).get("code", "")) == code:
			return (item as Dictionary).duplicate()
	return {"code": code, "name": code, "dept": "s", "body": "c", "height": 4.0, "level": 1}


func _move_suits(delta: float) -> void:
	for index in _suits.size():
		var suit: Dictionary = _suits[index]
		var actor: Node3D = suit["actor"]
		if actor == null:
			continue
		suit["age"] = float(suit["age"]) + delta
		var dur := float(suit["dur"])
		var along := 1.0
		if dur > 0.0:
			along = clampf(float(suit["age"]) / dur, 0.0, 1.0)
		var origin: Vector3 = suit["from"]
		var dest: Vector3 = suit["to"]
		if float(suit.get("dying", -1.0)) >= 0.0:
			var clock := float(suit["dying"]) + delta
			suit["dying"] = clock
			if actor is StreetCog:
				(actor as StreetCog).play_lose(clock)
			if clock >= 2.5:
				actor.queue_free()
				suit["actor"] = null
			_suits[index] = suit
			continue
		actor.position = origin.lerp(dest, along)
		if actor is StreetCog:
			var cog := actor as StreetCog
			if suit["boss"] == true:
				cog.play_attack("stomp", fposmod(float(suit["age"]), 0.9))
			else:
				cog.play_step(true, delta)
		if along >= 1.0:
			_think_suit(index)
		if suit["boss"] == true:
			_pose_boss(suit, actor, delta)


func _think_suit(index: int) -> void:
	var suit: Dictionary = _suits[index]
	var blocked: Array = []
	for other_index in _suits.size():
		if other_index == index:
			continue
		var other: Dictionary = _suits[other_index]
		blocked.append(Vector2i(int(other["tx"]), int(other["ty"])))
		blocked.append(Vector2i(int(other["nx"]), int(other["ny"])))
	var tx := int(suit["nx"])
	var ty := int(suit["ny"])
	var facing := int(suit["dir"])
	var chosen := _choose_dir(facing, tx, ty, blocked, suit["boss"] == true)
	var nxt := _step_dir(chosen, tx, ty)
	suit["tx"] = tx
	suit["ty"] = ty
	suit["nx"] = nxt.x
	suit["ny"] = nxt.y
	suit["dir"] = chosen
	suit["from"] = _corner(tx, ty)
	suit["to"] = _corner(nxt.x, nxt.y)
	suit["age"] = 0.0
	suit["thinks"] = int(suit["thinks"]) + 1
	var actor: Node3D = suit["actor"]
	if actor != null:
		_face_suit(actor, float(_HEADING[chosen]))
	if suit["boss"] == true and int(suit["thinks"]) % 3 == 0:
		_drop_cabinet(tx, ty)
	_suits[index] = suit


func _choose_dir(facing: int, tx: int, ty: int, blocked: Array, _boss: bool) -> int:
	var ahead := _step_dir(facing, tx, ty)
	if _walkable(ahead.x, ahead.y, blocked):
		return facing
	if _hood_difficulty() >= 0.5 and _roll.pick(100) == 0:
		var back := _opposite(facing)
		var behind := _step_dir(back, tx, ty)
		if _walkable(behind.x, behind.y, blocked):
			return back
	var options: Array[int] = []
	for dir in [_UP, _DOWN, _LEFT, _RIGHT]:
		if dir != _opposite(facing):
			options.append(dir)
	while not options.is_empty():
		var pick := options[_roll.pick(options.size())]
		var dest := _step_dir(pick, tx, ty)
		if _walkable(dest.x, dest.y, blocked):
			return pick
		options.erase(pick)
	return _opposite(facing)


func _step_dir(dir: int, tx: int, ty: int) -> Vector2i:
	if dir == _UP:
		return Vector2i(tx, ty + 1)
	if dir == _DOWN:
		return Vector2i(tx, ty - 1)
	if dir == _LEFT:
		return Vector2i(tx - 1, ty)
	return Vector2i(tx + 1, ty)


func _opposite(dir: int) -> int:
	if dir == _UP:
		return _DOWN
	if dir == _DOWN:
		return _UP
	if dir == _LEFT:
		return _RIGHT
	return _LEFT


func _drop_cabinet(tx: int, ty: int) -> void:
	var choices: Array[Vector2i] = []
	for x in range(tx - 5, tx + 6):
		for y in range(ty - 5, ty + 6):
			if _walkable(x, y, []):
				choices.append(Vector2i(x, y))
	if choices.is_empty():
		return
	var spot := choices[_roll.pick(choices.size())]
	var packed := load(_CABINET) as PackedScene
	if packed == null:
		return
	var node := Node3D.new()
	var mesh := packed.instantiate() as Node3D
	if mesh != null:
		node.add_child(mesh)
	var base := _corner(spot.x, spot.y)
	node.position = base + Vector3(0.0, 70.0, 0.0)
	node.rotation_degrees = Vector3(0.0, 0.0, float(_roll.pick(31) - 15))
	_root.add_child(node)
	var shadow := _square_shadow()
	shadow.position = base + Vector3(0.0, 0.15, 0.0)
	shadow.scale = Vector3.ONE * 0.05
	_root.add_child(shadow)
	_falls.append({"node": node, "age": 0.0, "base": base, "popped": false, "shadow": shadow})


func _cabinets(delta: float, body: Node3D) -> void:
	var kept: Array[Dictionary] = []
	for item in _falls:
		var node: Node3D = item["node"]
		if node == null:
			continue
		var age := float(item["age"]) + delta
		item["age"] = age
		var base: Vector3 = item["base"]
		var height := 70.0
		if age > 2.0:
			var fall := clampf((age - 2.0) / 1.0, 0.0, 1.0)
			height = 70.0 * (1.0 - fall * fall)
		node.position = base + Vector3(0.0, height, 0.0)
		var shadow: Node3D = item.get("shadow")
		if shadow != null:
			var grown := clampf(age / 2.0, 0.0, 1.0)
			shadow.scale = Vector3.ONE * lerpf(0.05, 1.0, grown)
			shadow.position = base + Vector3(0.0, 0.15, 0.0)
		if age >= 3.0 and item.get("landed", false) != true:
			item["landed"] = true
			_plant_cabinet(item)
			_sfx(_LAND)
			var dist := body.global_position.distance_to(node.global_position)
			var landed := 4.0 * (1.0 - dist / _DROP_REACH)
			if landed > 0.0:
				_shake = maxf(_shake, landed)
		if age >= 3.0 and item["popped"] != true and body.global_position.distance_to(node.global_position) < 2.0:
			item["popped"] = true
			_pop_balloon()
			_sfx(_DROP_HIT)
			_say("Falling objects pop your balloon")
		if age < 4.0:
			kept.append(item)
		else:
			node.queue_free()
			var wall: Node = item.get("wall")
			if wall != null:
				wall.queue_free()
			if shadow != null:
				shadow.queue_free()
	_falls = kept


func _touch_suits(body: Node3D, toon: Node) -> void:
	if _hurt > 0.0 or _slip > 0.0:
		return
	for suit in _suits:
		if float(suit.get("dying", -1.0)) >= 0.0:
			continue
		var actor: Node3D = suit["actor"]
		if actor == null:
			continue
		var reach := 1.5 * float(suit["scale"])
		if body.global_position.distance_to(actor.global_position) > reach:
			continue
		var loadout: ToonLoadout = toon.call("battle_loadout")
		if loadout != null:
			loadout.take_damage(int(suit["damage"]))
			loadout.save()
			_sfx(_HIT)
			if loadout.hp <= 0:
				_finish(toon, false)
				return
		_hurt = _HURT_WAIT
		_slip = 2.25
		_slip_at = body.global_position
		var dancer := body.get_node_or_null("Toon")
		if dancer != null and dancer.has_method("play_emote"):
			dancer.call("play_emote", 14)
		_catching = false
		_tell("bump", int(suit.get("id", 0)), body.global_position.x, body.global_position.z, 0.0)
		return


func _coolers_near(body: Node3D) -> void:
	if _has_gag or _cool > 0.0:
		return
	var local := _root.to_local(body.global_position)
	var here := Vector2(local.x, local.z)
	for cooler in _coolers:
		if here.distance_to(cooler) > 2.5:
			continue
		_has_gag = true
		_cool = _BALLOON_WAIT
		_attach_gag(body)
		_tell("gag", 0, 0.0, 0.0, 0.0)
		_sfx(_FILL)
		_say("Press 'Ctrl' to throw your water balloon")
		return


func _attach_gag(body: Node3D) -> void:
	if _gag != null:
		_gag.queue_free()
	var packed := load(_BALLOON) as PackedScene
	if packed == null:
		return
	_gag = packed.instantiate() as Node3D
	if _gag == null:
		return
	body.add_child(_gag)
	_gag.position = Vector3(0.6, 3.2, 0.4)


func _pop_balloon() -> void:
	_has_gag = false
	if _gag != null:
		_gag.queue_free()
		_gag = null


func _throw(body: Node3D) -> void:
	if _slip > 0.0:
		return
	if not _has_gag:
		_say("Find a Water Cooler")
		return
	if _release >= 0.0:
		return
	var dancer := body.get_node_or_null("Toon")
	if dancer != null and dancer.has_method("play_gesture"):
		dancer.call("play_gesture", "throw", 1.5, false)
	# The water balloon leaves the hand near the end of the throw.
	_release = 0.35


func _release_throw(body: Node3D, delta: float) -> void:
	if _release < 0.0:
		return
	_release -= delta
	if _release > 0.0:
		return
	_release = -1.0
	if not _has_gag:
		return
	_pop_balloon()
	_sfx(_THROW)
	var packed := load(_BALLOON) as PackedScene
	if packed == null:
		return
	var balloon := packed.instantiate() as Node3D
	if balloon == null:
		return
	_root.add_child(balloon)
	var actor := body.get_node_or_null("Toon") as Node3D
	var forward := Vector3(0.0, 0.0, -1.0)
	if actor != null:
		forward = actor.global_transform.basis.y
		actor.call("clear_gesture")
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3(0.0, 0.0, -1.0)
	forward = forward.normalized()
	balloon.global_position = body.global_position + Vector3(0.0, 3.0, 0.0) + forward * 1.2
	_tell("throw", 0, forward.x, forward.z, 0.0)
	_shots.append({
		"node": balloon,
		"vel": forward * (_THROW_REACH / _THROW_TIME),
		"left": _THROW_TIME,
		"hits": true,
	})


func _shots_fly(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for item in _shots:
		var node: Node3D = item["node"]
		if node == null:
			continue
		var vel: Vector3 = item["vel"]
		node.global_position += vel * delta
		item["left"] = float(item["left"]) - delta
		var local := _root.to_local(node.global_position)
		var tile := _tile_of(local)
		if not _open_tile(tile.x, tile.y) or float(item["left"]) <= 0.0:
			node.queue_free()
			continue
		if item.get("hits", true) == true and _hit_suit(node.global_position):
			node.queue_free()
			continue
		kept.append(item)
	_shots = kept


func _hit_suit(at: Vector3) -> bool:
	var best := -1
	var nearest := 1000.0
	for index in _suits.size():
		var suit: Dictionary = _suits[index]
		if float(suit.get("dying", -1.0)) >= 0.0:
			continue
		var actor: Node3D = suit["actor"]
		if actor == null:
			continue
		var dist := at.distance_to(actor.global_position + Vector3(0.0, 2.0, 0.0))
		var limit := 1.7 * float(suit["scale"])
		if dist < limit and dist < nearest:
			nearest = dist
			best = index
	if best < 0:
		return false
	var suit: Dictionary = _suits[best]
	var was := int(suit["hp"])
	_sfx(_HIT)
	_sfx(_SPLAT)
	var struck: Node3D = suit["actor"]
	if struck != null:
		_splash(struck.global_position)
	if ToonNet.networked():
		var slot_now := int(suit.get("slot", -1))
		if suit["boss"] == true and was >= 2 and slot_now >= 0 and slot_now < _flash.size():
			_flash[slot_now] = 0.45
			_say("Big Cogs take TWO hits to defeat")
		_tell("hit", int(suit["id"]), 0.0, 0.0, 0.0)
		return true
	suit["hp"] = was - 1
	if suit["boss"] == true and was >= 2:
		_sfx(_ANGRY)
		_wound_boss(suit, struck)
	var slot := int(suit.get("slot", -1))
	if suit["boss"] == true and int(suit["hp"]) > 0 and slot >= 0 and slot < _flash.size():
		_flash[slot] = 0.45
		_say("Big Cogs take TWO hits to defeat")
	if int(suit["hp"]) > 0:
		_suits[best] = suit
		return true
	_defeat(best)
	return true


func _defeat(index: int) -> void:
	var suit: Dictionary = _suits[index]
	if suit["boss"] == true:
		_bosses -= 1
		if _bosses <= 0:
			_open_exit()
	else:
		_say("Smaller Cogs drop jokes")
	var slot := int(suit.get("slot", -1))
	if slot >= 0 and slot < _revealed.size():
		_revealed[slot] = true
	var actor: Node3D = suit["actor"]
	var origin := Vector3.ZERO
	if actor != null:
		origin = actor.position
		suit["dying"] = 0.0
		if actor is StreetCog:
			(actor as StreetCog).play_lose(0.0)
		_suits[index] = suit
	if suit["boss"] == true and actor != null:
		suit["blink"] = -1.0
		suit["spin"] = 0.0
		_tint_boss(actor, Color.WHITE)
	_sfx(_SPIN)
	_sfx(_FALL_APART)
	var count := int(suit["memos"])
	if count > 0:
		var start := float((int(suit["id"]) * 47) % 360)
		var step := 360.0 / float(count)
		for memo_index in count:
			var angle := deg_to_rad(start + step * float(memo_index))
			var drop := _memo_node()
			if drop == null:
				continue
			drop.position = origin + Vector3(cos(angle) * 2.0, 1.0, sin(angle) * 2.0)
			_root.add_child(drop)
			_drops.append({"node": drop, "id": int(suit["id"]) * 8 + memo_index})


func _open_exit() -> void:
	if _open:
		return
	_open = true
	_opened_at = _age
	_open_left = _EXIT_TIME
	_alerted = true
	_tune(_RUSH, 0.9)
	_say("THE EXIT IS OPEN FOR 60 SECONDS!\nGET THERE FAST FOR A BIGGER TOON-UP")


func _memo_node() -> Node3D:
	var packed := load(_MEMO) as PackedScene
	if packed == null:
		return null
	var wrap := Node3D.new()
	var memo := packed.instantiate() as Node3D
	if memo == null:
		return null
	wrap.add_child(memo)
	# CogdoMemo is pitched flat onto the floor.
	wrap.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	return wrap


func _gather(body: Node3D) -> void:
	var kept: Array[Dictionary] = []
	for item in _drops:
		var node: Node3D = item["node"]
		if node == null:
			continue
		if body.global_position.distance_to(node.global_position) < 1.6:
			var memo_id := int(item.get("id", -1))
			if ToonNet.networked():
				if not _asked.has(memo_id):
					_asked[memo_id] = true
					_tell("memo", memo_id, 0.0, 0.0, 0.0)
				kept.append(item)
				continue
			_memos += 1
			_sfx(_PICKUP)
			node.queue_free()
			continue
		kept.append(item)
	_drops = kept


func _clamp_toon(body: Node3D, delta: float) -> void:
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity.y = 0.0
	if _slip > 0.0:
		body.global_position = _slip_at
		if body is CharacterBody3D:
			(body as CharacterBody3D).velocity = Vector3.ZERO
		return
	body.global_position.y = _floor_y
	var flat := Vector2(body.global_position.x, body.global_position.z)
	var last := Vector2(_last_pos.x, _last_pos.z)
	var step := flat - last
	var cap := _RUN * delta
	if step.length() > cap and cap > 0.0:
		step = step.normalized() * cap
		body.global_position.x = last.x + step.x
		body.global_position.z = last.y + step.y
	if _cabinet_blocks(body.global_position):
		body.global_position.x = _last_pos.x
		body.global_position.z = _last_pos.z
	_last_pos = body.global_position


func _near_closed_door(body: Node3D) -> void:
	if _told_exit or _open or body.global_position.distance_to(_exit_at) > 3.0:
		return
	_told_exit = true
	_say("The exit will open when\nyou've busted all four BIG COGS!")


func _write_hud() -> void:
	if _hud == null:
		return
	var clock := ""
	if _open:
		clock = "   %.0f" % _open_left
	elif _age >= _TIMEOUT - _ALERT:
		clock = "   %.0f" % maxf(_TIMEOUT - _age, 0.0)
	_hud.text = "Memos: %d%s" % [_memos, clock]
	var view := get_viewport().get_visible_rect().size
	if _memo_card != null:
		_memo_card.position = Vector2(16.0, 12.0)
		_memo_card.size = Vector2(72.0, 88.0)
		_hud.position = Vector2(96.0, 36.0)
	if _boss_card != null:
		_boss_card.position = Vector2(view.x * 0.5 - 210.0, view.y - 150.0)
		_boss_card.size = Vector2(420.0, 120.0)
		var open_door := true
		for shown in _revealed:
			if not shown:
				open_door = false
		if _boss_closed != null:
			_boss_closed.visible = not open_door
		if _boss_open != null:
			_boss_open.visible = open_door
		for index in _digits.size():
			var digit := _digits[index]
			digit.position = Vector2(70.0 + float(index) * 78.0, 58.0)
			digit.size = Vector2(48.0, 36.0)
			var revealed := index < _revealed.size() and _revealed[index]
			digit.text = _code.substr(index, 1) if revealed and index < _code.length() else ""
			if index < _flash.size():
				_flash[index] = maxf(_flash[index] - get_process_delta_time(), 0.0)
				var hot := _flash[index] > 0.0
				digit.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4) if hot else Color(0.0, 0.0, 0.0))
	if _code_label != null:
		_code_label.text = "BIG COGS"
		_code_label.position = Vector2(view.x * 0.5 - 160.0, view.y - 168.0)
		_code_label.size = Vector2(320.0, 28.0)
	if _card != null:
		_card.visible = _hint_left > 0.0 and _hint_text != ""
		if _line != null:
			_line.text = _hint_text
	if _portrait != null:
		_portrait.visible = _intro > 0.0
		var box := get_viewport().get_visible_rect().size
		_portrait.position = Vector2(24.0, 150.0)
	var body := _body_of(_toon)
	if body != null:
		_near_closed_door(body)


func _say(line: String) -> void:
	_hint_left = _HINT_TIME
	_hint_text = line


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 22
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(24.0, 24.0)
	_hud.size = Vector2(420.0, 48.0)
	# CogdoMemoGui. The count is the toon font, yellow, with a gray shadow.
	ToonGui.style_label(_hud, Color(0.95, 0.95, 0.0), 32, Color(0.2, 0.2, 0.2), 2)
	layer.add_child(_hud)
	_card = Panel.new()
	_card.visible = false
	_card.position = Vector2(180.0, 150.0)
	_card.size = Vector2(620.0, 110.0)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(1.0, 1.0, 1.0)
	paper.content_margin_left = 12.0
	paper.content_margin_right = 12.0
	paper.content_margin_top = 8.0
	paper.content_margin_bottom = 8.0
	_card.add_theme_stylebox_override("panel", paper)
	layer.add_child(_card)
	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.size = Vector2(596.0, 94.0)
	_line.position = Vector2(12.0, 8.0)
	# CogdoGameMovie. The spoken lines are the toon font, black on a white card.
	ToonGui.style_label(_line, Color(0.0, 0.0, 0.0), 26, Color(0.0, 0.0, 0.0, 0.0), 0)
	_card.add_child(_line)
	_code_label = Label.new()
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# CogdoMazeBossGui. The title and the code are the suit font.
	_code_label.add_theme_font_override("font", ToonGui.suit_font())
	_code_label.add_theme_font_size_override("font_size", 28)
	_code_label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	_code_label.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0))
	_code_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(_code_label)
	_build_map(layer)
	_memo_card = _card_view(layer, _MEMO_CARD, "")
	_boss_card = _card_view(layer, _BOSS_GUI, "")
	if _boss_card != null:
		_boss_closed = _named(_boss_card, "doorClosed")
		_boss_open = _named(_boss_card, "doorOpen")
		if _boss_open != null:
			_boss_open.visible = false
		for _index in 4:
			var digit := Label.new()
			digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			digit.add_theme_font_override("font", ToonGui.suit_font())
			digit.add_theme_font_size_override("font_size", 26)
			digit.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0))
			digit.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_boss_card.add_child(digit)
			_digits.append(digit)
	_build_portrait(layer)


func _build_map(layer: CanvasLayer) -> void:
	_seen.resize(_width * _height)
	_seen.fill(0)
	_reveal(_entrance_tile())
	_map_root = Control.new()
	_map_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_map_root)
	var frame := TextureRect.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.texture = load(_MAP_FRAME) as Texture2D
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_root.add_child(frame)
	_map_rect = TextureRect.new()
	_map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_map_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_root.add_child(_map_rect)
	_map_image = Image.create(_width, _height, false, Image.FORMAT_RGBA8)
	_map_tex = ImageTexture.create_from_image(_map_image)
	_map_rect.texture = _map_tex
	_enter_icon = _map_icon(0.883, 0.383, 0.992, 0.492)
	_exit_icon = _map_icon(0.883, 0.258, 0.992, 0.367)
	for _index in _coolers.size():
		_cooler_icons.append(_map_icon(0.211, 0.18, 0.273, 0.242))
	for _index in _suits.size():
		_cog_icons.append(_map_icon(0.133, 0.18, 0.195, 0.242))
	for _index in 3:
		var pal := TextureRect.new()
		pal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pal.visible = false
		_map_root.add_child(pal)
		_pals.append(pal)
	_you = TextureRect.new()
	_you.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_you.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_you.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_map_root.add_child(_you)


func _map_icon(u0: float, v0: float, u1: float, v1: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture = _icon_region(u0, v0, u1, v1)
	_map_root.add_child(rect)
	return rect


func _icon_region(u0: float, v0: float, u1: float, v1: float) -> Texture2D:
	var tex := load(_MAP_ICONS) as Texture2D
	if tex == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	var size := tex.get_size()
	atlas.region = Rect2(u0 * size.x, (1.0 - v1) * size.y, (u1 - u0) * size.x, (v1 - v0) * size.y)
	return atlas


func _paint_map(body: Node3D) -> void:
	if _map_image == null or _map_rect == null or _map_root == null:
		return
	var view := get_viewport().get_visible_rect().size
	_map_root.position = Vector2(view.x - 214.0, view.y - 214.0)
	_map_root.size = Vector2(196.0, 196.0)
	_map_rect.position = Vector2(22.0, 22.0)
	_map_rect.size = Vector2(152.0, 152.0)
	var here := _tile_of(_root.to_local(body.global_position))
	if not _open:
		_reveal(here)
	var floor := Color(0.9, 0.9, 0.9)
	var wall := Color(0.5, 0.5, 0.5)
	var fog := Color(0.1, 0.1, 0.1)
	for y in _height:
		for x in _width:
			var seen := _open or _seen[y * _width + x] == 1
			var ink := fog
			if seen:
				ink = wall if _cell(x, y) == 1 else floor
			_map_image.set_pixel(x, _height - 1 - y, ink)
	if _map_tex != null:
		_map_tex.update(_map_image)
	_place_icon(_enter_icon, _entrance_tile(), true)
	var door := _tile_of(_root.to_local(_exit_at))
	if _open and _exit_icon != null:
		_exit_icon.texture = _icon_region(0.008, 0.133, 0.117, 0.242)
	_place_icon(_exit_icon, door, true)
	for index in _cooler_icons.size():
		if index >= _coolers.size():
			break
		var spot := _tile_of(Vector3(_coolers[index].x, 0.0, _coolers[index].y))
		var shown := _open or (_seen_at(spot))
		_place_icon(_cooler_icons[index], spot, shown)
	for index in _cog_icons.size():
		if index >= _suits.size():
			break
		var suit: Dictionary = _suits[index]
		var alive := suit.get("actor") != null
		_place_icon(_cog_icons[index], Vector2i(int(suit["tx"]), int(suit["ty"])), alive)
	_mark_pals()
	_mark_you(body, here)


func _mark_you(body: Node3D, tile: Vector2i) -> void:
	if _you == null:
		return
	if _you.texture == null:
		var dancer := body.get_node_or_null("Toon")
		var species := "d"
		if dancer != null and dancer.has_method("species"):
			var found := String(dancer.call("species"))
			if _LAFF_HEADS.has(found):
				species = found
		_you.texture = _LAFF_HEADS[species] as Texture2D
		if dancer != null and dancer.has_method("head_color"):
			var ink: Variant = dancer.call("head_color")
			if ink is Color:
				_you.modulate = ink
	_place_icon(_you, tile, true)
	_you.size = Vector2(22.0, 22.0)
	_you.position -= Vector2(2.0, 2.0)


func _seen_at(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.y < 0 or tile.x >= _width or tile.y >= _height:
		return false
	return _seen[tile.y * _width + tile.x] == 1


func _reveal(center: Vector2i) -> void:
	# MazeMapGui punches a small smooth circle. Three cells is that hole on this grid.
	var radius := 3
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if x < 0 or y < 0 or x >= _width or y >= _height:
				continue
			if Vector2(x - center.x, y - center.y).length() > float(radius):
				continue
			_seen[y * _width + x] = 1


func _place_icon(icon: TextureRect, tile: Vector2i, shown: bool) -> void:
	if icon == null or _map_rect == null:
		return
	icon.visible = shown
	if not shown:
		return
	var span := _map_rect.size
	var px := _map_rect.position.x + (float(tile.x) + 0.5) / float(_width) * span.x
	var py := _map_rect.position.y + (1.0 - (float(tile.y) + 0.5) / float(_height)) * span.y
	icon.size = Vector2(18.0, 18.0)
	icon.position = Vector2(px - 9.0, py - 9.0)


func _build_portrait(layer: CanvasLayer) -> void:
	# CogdoMazeGameIntro. The resistance dog wears a Short Change suit, head showing.
	var box := SubViewportContainer.new()
	box.name = "Resistance"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.stretch = true
	box.size = Vector2(150.0, 170.0)
	box.visible = false
	layer.add_child(box)
	var view := SubViewport.new()
	view.size = Vector2i(150, 170)
	view.transparent_bg = true
	view.own_world_3d = true
	box.add_child(view)
	var stage := Node3D.new()
	view.add_child(stage)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28.0, 18.0, 0.0)
	light.light_energy = 1.3
	stage.add_child(light)
	var cam := Camera3D.new()
	cam.fov = 26.0
	cam.current = true
	stage.add_child(cam)
	var suit := StreetCog.new()
	stage.add_child(suit)
	suit.present(_cog_row("sc"), {})
	suit.set_process(false)
	suit.play_step(false, 0.0)
	var actor := ToonActor.new()
	stage.add_child(actor)
	var style := ToonStyle.new()
	style.first_name = "Resistance"
	style.head = "dss"
	style.torso = "ss"
	style.legs = "m"
	style.gender = "m"
	style.arm_color = 2
	style.glove_color = 0
	style.leg_color = 2
	style.head_color = 2
	style.top_tex = 1
	style.top_color = 8
	style.bot_tex = 1
	style.bot_color = 14
	actor.show_style(style)
	var neck := suit.find_child("joint_head", true, false) as Node3D
	var head := actor.find_child("head_look", true, false) as Node3D
	if neck != null and head != null:
		for piece in neck.get_children():
			if piece is Node3D:
				(piece as Node3D).visible = false
		var seat := Node3D.new()
		neck.add_child(seat)
		head.reparent(seat)
		head.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.2))
		for child in actor.get_children():
			if child.name == "1000" or child.name == "500" or child.name == "250" or child.name == "0":
				child.visible = false
	var bounds := _merged_bounds(stage)
	if bounds.size.length() > 0.2:
		var focus := bounds.position + Vector3(bounds.size.x * 0.5, bounds.size.y * 0.78, bounds.size.z * 0.5)
		var reach := maxf(bounds.size.y, 1.0) * 0.95
		cam.global_position = focus + Vector3(0.0, bounds.size.y * 0.06, -reach)
		cam.look_at(focus, Vector3.UP)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-8.0, 180.0, 0.0)
	fill.light_energy = 1.2
	stage.add_child(fill)
	_portrait = box


func _build_arrows() -> void:
	var packed := load(_ARROW) as PackedScene
	if packed == null or _root == null:
		return
	for cooler in _coolers:
		var mark := Node3D.new()
		mark.position = Vector3(cooler.x, 10.0, cooler.y)
		var arrow := packed.instantiate() as Node3D
		if arrow != null:
			arrow.scale = Vector3.ONE * 8.0
			_paint_arrow(arrow)
			mark.add_child(arrow)
		_root.add_child(mark)
		_arrows.append(mark)
	_quest = Node3D.new()
	_quest.visible = false
	var pointer := packed.instantiate() as Node3D
	if pointer != null:
		pointer.scale = Vector3.ONE * 5.0
		_paint_arrow(pointer)
		_quest.add_child(pointer)
	_root.add_child(_quest)


func _paint_arrow(node: Node) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 1.0, 0.0)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_paint_arrow(child)


func _tick_arrows(body: Node3D, _delta: float) -> void:
	var bob := sin(Time.get_ticks_msec() / 1000.0 * 2.0) * 2.0
	var show_cooler := not _has_gag and _intro <= 0.0
	for index in _arrows.size():
		if index >= _coolers.size():
			break
		var mark := _arrows[index]
		mark.visible = show_cooler
		var cooler: Vector2 = _coolers[index]
		mark.position = Vector3(cooler.x, 10.0 + bob, cooler.y)
		var cam := get_viewport().get_camera_3d()
		if cam != null and mark.visible:
			mark.look_at(cam.global_position, Vector3.UP)
	if _quest == null:
		return
	_quest.visible = _open
	if not _open:
		return
	_quest.global_position = body.global_position + Vector3(0.0, 5.0, 0.0)
	var door := _exit_at + Vector3(0.0, 3.0, 0.0)
	if _quest.global_position.distance_squared_to(door) > 0.04:
		_quest.look_at(door, Vector3.UP)


func _square_shadow() -> MeshInstance3D:
	var card := QuadMesh.new()
	card.orientation = PlaneMesh.FACE_Y
	card.size = Vector2(3.2, 3.2)
	var shadow := MeshInstance3D.new()
	shadow.mesh = card
	var shade := StandardMaterial3D.new()
	shade.albedo_color = Color(1.0, 1.0, 1.0, 0.45)
	shade.albedo_texture = load(_SHADOW) as Texture2D
	shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shade.cull_mode = BaseMaterial3D.CULL_DISABLED
	shade.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	shadow.material_override = shade
	return shadow


func _card_view(layer: CanvasLayer, path: String, only: String) -> SubViewportContainer:
	var box := SubViewportContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.stretch = true
	layer.add_child(box)
	var view := SubViewport.new()
	view.transparent_bg = true
	view.own_world_3d = true
	view.size = Vector2i(512, 256)
	box.add_child(view)
	var stage := Node3D.new()
	view.add_child(stage)
	var packed := load(path) as PackedScene
	if packed == null:
		return box
	var model := packed.instantiate() as Node3D
	if model == null:
		return box
	stage.add_child(model)
	if only != "":
		_show_only(model, only)
	var bounds := _merged_bounds(model)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.current = true
	stage.add_child(cam)
	_frame_card(cam, bounds)
	var light := DirectionalLight3D.new()
	light.light_energy = 1.5
	stage.add_child(light)
	if bounds.size.length() > 0.01:
		light.global_position = cam.global_position
		light.look_at(bounds.get_center(), Vector3.UP)
	return box


func _show_only(root: Node, needle: String) -> void:
	var keep := _exact(root, needle)
	if keep == null:
		return
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var under := false
		var walk: Node = mesh
		while walk != null:
			if walk == keep:
				under = true
				break
			walk = walk.get_parent()
		mesh.visible = under


func _frame_card(cam: Camera3D, bounds: AABB) -> void:
	if bounds.size.length() < 0.01:
		cam.position = Vector3(0.0, 0.0, 2.0)
		cam.look_at(Vector3.ZERO, Vector3.UP)
		return
	var center := bounds.get_center()
	var size := bounds.size
	var axis := 0
	var thin := size.x
	if size.y < thin:
		axis = 1
		thin = size.y
	if size.z < thin:
		axis = 2
	var span := maxf(size.x, maxf(size.y, size.z))
	var offset := Vector3.ZERO
	offset[axis] = span
	cam.global_position = center + offset
	var up := Vector3.UP if axis != 1 else Vector3.BACK
	if cam.global_position.distance_squared_to(center) > 0.0001:
		cam.look_at(center, up)
	cam.size = span * 1.15


func _merged_bounds(root: Node) -> AABB:
	var box := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.visible:
			continue
		var world := mesh.global_transform * mesh.get_aabb()
		if first:
			box = world
			first = false
		else:
			box = box.merge(world)
	return box


func _tune(path: String, volume: float) -> void:
	var host := get_parent()
	if host != null and host.has_method("_play_music"):
		host.call("_play_music", path, volume)


func _splash(at: Vector3) -> void:
	var packed := load(_SPLASH) as PackedScene
	if packed == null or _root == null:
		return
	var pivot := Node3D.new()
	_root.add_child(pivot)
	pivot.global_position = at + Vector3(0.0, 3.0, 0.0)
	var card := packed.instantiate() as Node3D
	if card == null:
		pivot.queue_free()
		return
	pivot.add_child(card)
	_splash_mat(card)
	_splats.append({"node": pivot, "age": 0.0})


func _splash_mat(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		if mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
			var existing := mesh.get_active_material(0) as StandardMaterial3D
			if existing != null:
				mat.albedo_texture = existing.albedo_texture
		mesh.material_override = mat
	for child in node.get_children():
		_splash_mat(child)


func _tick_splats(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var kept: Array[Dictionary] = []
	for item in _splats:
		var node: Node3D = item["node"]
		if node == null:
			continue
		var age := float(item["age"]) + delta
		item["age"] = age
		if age >= 0.5:
			node.queue_free()
			continue
		if camera != null and node.global_position.distance_squared_to(camera.global_position) > 0.04:
			node.look_at(camera.global_position, Vector3.UP)
		node.scale = Vector3.ONE * lerpf(1.0, 6.0, age / 0.5)
		kept.append(item)
	_splats = kept


func _rumble_bosses(body: Node3D, delta: float) -> void:
	_stomp_left -= delta
	if _stomp_left > 0.0:
		return
	_stomp_left = _STOMP_WAIT
	var nearest := 9999.0
	var where := Vector3.ZERO
	var found := false
	for suit in _suits:
		if suit.get("boss") != true:
			continue
		if float(suit.get("dying", -1.0)) >= 0.0:
			continue
		var actor: Node3D = suit["actor"]
		if actor == null:
			continue
		var dist := body.global_position.distance_to(actor.global_position)
		if dist < nearest:
			nearest = dist
			where = actor.global_position
			found = true
	if not found:
		return
	_stomp_at(where)
	var strength := 1.2 * (1.0 - nearest / _BOSS_REACH)
	if strength > 0.0:
		_shake = maxf(_shake, strength)


func _stomp_at(at: Vector3) -> void:
	var stream := ToonAudio.stream(_STOMP)
	if stream == null or _root == null:
		return
	var player := ToonAudio.effect_3d()
	player.stream = stream
	player.max_distance = 70.0
	player.unit_size = 8.0
	_root.add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()


func _tick_quake() -> void:
	if _quake == null:
		var stream := ToonAudio.stream(_QUAKE) as AudioStreamOggVorbis
		if stream == null:
			return
		stream.loop = true
		_quake = ToonAudio.effect_player()
		add_child(_quake)
		_quake.stream = stream
	var loud := clampf(3.0 * _shake / 5.0, 0.0, 1.0)
	if loud <= 0.02:
		if _quake.playing:
			_quake.stop()
		return
	_quake.volume_db = linear_to_db(loud)
	if not _quake.playing:
		_quake.play()


func _hold_balloon(body: Node3D) -> void:
	var dancer := body.get_node_or_null("Toon")
	if dancer == null or not dancer.has_method("play_gesture"):
		return
	# Catching is gameneutral while you stand and gamerun while you move.
	if _has_gag and _slip <= 0.0 and _release < 0.0:
		var moving := false
		var rate := 1.0
		if body is CharacterBody3D:
			var flat := Vector2((body as CharacterBody3D).velocity.x, (body as CharacterBody3D).velocity.z)
			moving = flat.length() > 0.8
			var actor := dancer as Node3D
			if moving and actor != null:
				var forward := actor.global_transform.basis.y
				if Vector2(forward.x, forward.z).dot(flat) < 0.0:
					rate = -1.0
		dancer.call("play_gesture", "catch-run" if moving else "catch-neutral", rate, true)
		_catching = true
		return
	if _catching and _release < 0.0 and dancer.has_method("clear_gesture"):
		_catching = false
		dancer.call("clear_gesture")


func _spin_memos(delta: float) -> void:
	for item in _drops:
		var node: Node3D = item["node"]
		if node == null:
			continue
		var yaw := float(item.get("yaw", 0.0)) + 60.0 * delta
		item["yaw"] = yaw
		node.rotation_degrees = Vector3(-90.0, yaw, 0.0)


func _wound_boss(suit: Dictionary, actor: Node) -> void:
	suit["spin"] = 1.0
	suit["blink"] = 0.0
	if actor != null:
		_tint_boss(actor, Color(1.0, 0.4, 0.4))


func _pose_boss(suit: Dictionary, actor: Node3D, delta: float) -> void:
	var spin := float(suit.get("spin", 0.0))
	if spin > 0.0:
		spin = maxf(spin - delta, 0.0)
		suit["spin"] = spin
		var along := 1.0 - spin
		var ease := 1.0 - (1.0 - along) * (1.0 - along)
		_face_suit(actor, float(_HEADING[int(suit["dir"])]) + ease * 720.0)
	if float(suit.get("blink", -1.0)) < 0.0:
		return
	var clock := float(suit["blink"]) + delta
	suit["blink"] = clock
	var red := Color(1.0, 0.4, 0.4)
	var ink := red
	if clock >= 1.0:
		var loop := fposmod(clock - 1.0, 1.0)
		if loop < 0.5:
			ink = red.lerp(Color.WHITE, loop / 0.5)
		else:
			ink = Color.WHITE.lerp(red, (loop - 0.5) / 0.5)
	_tint_boss(actor, ink)


func _tint_boss(actor: Node, ink: Color) -> void:
	if actor is MeshInstance3D:
		var mesh := actor as MeshInstance3D
		for index in mesh.get_surface_override_material_count():
			var mat := mesh.get_surface_override_material(index) as ShaderMaterial
			if mat == null:
				continue
			if not mat.has_meta("maze_base"):
				var found: Variant = mat.get_shader_parameter("albedo_color")
				mat.set_meta("maze_base", found if found is Color else Color.WHITE)
			var base: Color = mat.get_meta("maze_base")
			mat.set_shader_parameter("albedo_color", Color(base.r * ink.r, base.g * ink.g, base.b * ink.b, base.a))
	for child in actor.get_children():
		_tint_boss(child, ink)


func _show_remote_slip(peer: int) -> void:
	if peer == ToonNet.peer_id() or _toon == null or not _toon.has_method("remote_actor"):
		return
	var actor: ToonActor = _toon.call("remote_actor", peer)
	if actor != null and actor.has_method("play_emote"):
		actor.play_emote(14)


func _plant_cabinet(item: Dictionary) -> void:
	if item.get("wall") != null or _root == null:
		return
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 4.0, 1.6)
	shape.shape = box
	shape.position = Vector3(0.0, 2.0, 0.0)
	body.add_child(shape)
	var base: Vector3 = item["base"]
	body.position = base
	_root.add_child(body)
	item["wall"] = body


func _cabinet_blocks(at: Vector3) -> bool:
	if _root == null:
		return false
	for item in _falls:
		if item.get("landed", false) != true:
			continue
		var base: Vector3 = item["base"]
		var world := _root.to_global(base)
		if Vector2(at.x - world.x, at.z - world.z).length() < 1.15:
			return true
	return false


func _cogdo_channel() -> String:
	return "cogdo:%d:%s:%d" % [_district, _slug, _run_id]


func _cogdo_clock() -> float:
	if not ToonNet.networked():
		return -1.0
	var snap := ToonNet.latest(_cogdo_channel())
	if not snap.has("age"):
		return -1.0
	return maxf(float(snap.get("age", 0.0)) - _INTRO_TIME, 0.0)


func _catch_up(target: float) -> void:
	# Every client steps the same 0.05 second grid, so suit turns stay in step.
	_sync_act_list()
	var goal := float(floor(target / 0.05)) * 0.05
	var guard := 0
	while _age + 0.0001 < goal and guard < 80:
		guard += 1
		var next := _age + 0.05
		while _act_at < _acts.size() and _act_stamp(_act_at) <= next + 0.0001:
			_apply_one_act()
		_age = next
		_move_suits(0.05)


func _sync_act_list() -> void:
	var snap := ToonNet.latest(_cogdo_channel())
	var raw: Variant = snap.get("acts", [])
	if raw is Array:
		_acts = raw


func _act_stamp(index: int) -> float:
	var row: Variant = _acts[index]
	if row is Array and (row as Array).size() > 3:
		return float((row as Array)[3])
	return _age


func _apply_one_act() -> void:
	if _act_at >= _acts.size():
		return
	var row: Variant = _acts[_act_at]
	_act_at += 1
	if not (row is Array):
		return
	var act: Array = row
	if act.size() < 4:
		return
	var op := String(act[0])
	var peer := int(act[1])
	var suit := int(act[2])
	var aim_x := 0.0
	var aim_z := 0.0
	if act.size() > 5:
		aim_x = float(act[4])
		aim_z = float(act[5])
	if op == "hit":
		_apply_hit(peer, suit)
	elif op == "memo":
		_apply_memo(peer, suit)
	elif op == "throw":
		_ghost_throw(peer, aim_x, aim_z)
	elif op == "gag":
		_show_remote_gag(peer, true)
	elif op == "bump":
		_show_remote_slip(peer)


func _apply_hit(peer: int, suit_id: int) -> void:
	var index := _suit_index(suit_id)
	if index < 0:
		return
	var suit: Dictionary = _suits[index]
	if float(suit.get("dying", -1.0)) >= 0.0 or int(suit["hp"]) <= 0:
		return
	var was := int(suit["hp"])
	if peer != ToonNet.peer_id():
		_sfx(_HIT)
		_sfx(_SPLAT)
		var struck: Node3D = suit["actor"]
		if struck != null:
			_splash(struck.global_position)
	if suit["boss"] == true and was >= 2:
		_sfx(_ANGRY)
		var boss_body: Node = suit["actor"]
		_wound_boss(suit, boss_body)
		var slot := int(suit.get("slot", -1))
		if slot >= 0 and slot < _flash.size():
			_flash[slot] = 0.45
		if peer != ToonNet.peer_id():
			_say("Big Cogs take TWO hits to defeat")
	suit["hp"] = was - 1
	if int(suit["hp"]) > 0:
		_suits[index] = suit
		return
	_defeat(index)


func _apply_memo(peer: int, memo_id: int) -> void:
	var kept: Array[Dictionary] = []
	var found := false
	for item in _drops:
		if int(item.get("id", -2)) == memo_id and not found:
			found = true
			var node: Node3D = item["node"]
			if node != null:
				node.queue_free()
			continue
		kept.append(item)
	_drops = kept
	if not found:
		return
	_memos += 1
	if peer == ToonNet.peer_id():
		_sfx(_PICKUP)


func _suit_index(suit_id: int) -> int:
	for index in _suits.size():
		var suit: Dictionary = _suits[index]
		if int(suit.get("id", -1)) == suit_id:
			return index
	return -1


func _ghost_throw(peer: int, aim_x: float, aim_z: float) -> void:
	_show_remote_gag(peer, false)
	if peer == ToonNet.peer_id() or _toon == null or _root == null:
		return
	if not _toon.has_method("remote_actor"):
		return
	var actor: ToonActor = _toon.call("remote_actor", peer)
	if actor == null:
		return
	var packed := load(_BALLOON) as PackedScene
	if packed == null:
		return
	var balloon := packed.instantiate() as Node3D
	if balloon == null:
		return
	var forward := Vector3(aim_x, 0.0, aim_z)
	if forward.length_squared() < 0.001:
		forward = Vector3(0.0, 0.0, -1.0)
	forward = forward.normalized()
	_root.add_child(balloon)
	balloon.global_position = actor.global_position + Vector3(0.0, 3.0, 0.0) + forward * 1.2
	_shots.append({
		"node": balloon,
		"vel": forward * (_THROW_REACH / _THROW_TIME),
		"left": _THROW_TIME,
		"hits": false,
	})


func _show_remote_gag(peer: int, hold: bool) -> void:
	if peer == ToonNet.peer_id() or _toon == null or not _toon.has_method("remote_actor"):
		return
	var actor: ToonActor = _toon.call("remote_actor", peer)
	if actor == null:
		return
	var old := actor.get_node_or_null("CogdoBalloon")
	if not hold:
		if old != null:
			old.queue_free()
		return
	if old != null:
		return
	var packed := load(_BALLOON) as PackedScene
	if packed == null:
		return
	var balloon := packed.instantiate() as Node3D
	if balloon == null:
		return
	balloon.name = "CogdoBalloon"
	actor.add_child(balloon)
	balloon.position = Vector3(0.6, 3.2, 0.4)


func _mark_pals() -> void:
	var used := 0
	if _toon != null and _toon.has_method("remote_actor") and _root != null:
		var mine := ToonNet.peer_id()
		for rider in _party():
			if used >= _pals.size() or not (rider is Dictionary):
				continue
			var peer := int((rider as Dictionary).get("id", 0))
			if peer == mine:
				continue
			var actor: ToonActor = _toon.call("remote_actor", peer)
			if actor == null or not actor.visible:
				continue
			if actor.global_position.distance_to(_root.global_position) > 120.0:
				continue
			var tile := _tile_of(_root.to_local(actor.global_position))
			var icon := _pals[used]
			var species := actor.species()
			if not _LAFF_HEADS.has(species):
				species = "d"
			icon.texture = _LAFF_HEADS[species] as Texture2D
			icon.modulate = actor.head_color()
			_place_icon(icon, tile, true)
			used += 1
	for index in range(used, _pals.size()):
		_pals[index].visible = false


func _party() -> Array:
	var snap := ToonNet.latest("runs:%d:%s" % [_district, _slug])
	var rows: Variant = snap.get("rows", [])
	if not (rows is Array):
		return []
	for item in rows as Array:
		if not (item is Dictionary):
			continue
		var run: Dictionary = item
		if int(run.get("id", -1)) != _run_id:
			continue
		var toons: Variant = run.get("toons", [])
		if toons is Array:
			return toons as Array
	return []


func _tell(op: String, suit: int, x: float, y: float, h: float) -> void:
	if not ToonNet.networked():
		return
	ToonNet.cogdo_act(_district, _slug, _run_id, op, suit, x, y, h)


func _sfx(path: String) -> void:
	var stream := ToonAudio.stream(path)
	if stream == null:
		return
	var player := ToonAudio.effect_player()
	add_child(player)
	player.stream = stream
	player.finished.connect(player.queue_free)
	player.play()


func _hide_cones(node: Node) -> void:
	if node is MeshInstance3D and String(node.name).to_lower().contains("lightcone"):
		var mesh := node as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color(1.0, 0.92, 0.55, 0.45)
		mesh.material_overlay = mat
	for child in node.get_children():
		_hide_cones(child)


func _exact(node: Node, needle: String) -> Node3D:
	if String(node.name) == needle and node is Node3D:
		return node as Node3D
	for child in node.get_children():
		var found := _exact(child, needle)
		if found != null:
			return found
	return null


func _named(node: Node, needle: String) -> Node3D:
	if String(node.name).to_lower().contains(needle) and node is Node3D:
		return node as Node3D
	for child in node.get_children():
		var found := _named(child, needle)
		if found != null:
			return found
	return null


func _turn(point: Vector2, degrees: float) -> Vector2:
	var rad := deg_to_rad(degrees)
	var c := cos(rad)
	var s := sin(rad)
	return Vector2(point.x * c - point.y * s, point.x * s + point.y * c)


func _face_suit(actor: Node3D, heading: float) -> void:
	var kept := actor.scale
	actor.rotation_degrees = Vector3(0.0, heading, 0.0)
	actor.scale = kept


func _corner(tx: int, ty: int) -> Vector3:
	return Vector3((float(tx) - float(_origin)) * _CELL, 0.1, -((float(ty) - float(_origin)) * _CELL))


func _corner_panda(tx: int, ty: int) -> Vector2:
	return Vector2((float(tx) - float(_origin)) * _CELL, (float(ty) - float(_origin)) * _CELL)


func _tile_of(local: Vector3) -> Vector2i:
	var tx := int(floor(local.x / _CELL + float(_origin)))
	var ty := int(floor(-local.z / _CELL + float(_origin)))
	return Vector2i(tx, ty)


func _plant(toon: Node, cell: Vector2i) -> void:
	if toon == null or _root == null:
		return
	var local := _corner(cell.x, cell.y)
	local.x += _CELL * 0.5
	local.z -= _CELL * 0.5
	toon.call("visit_friend", _root.to_global(local), 0.0)


func _body_of(toon: Node) -> Node3D:
	if toon == null:
		return null
	return toon.get_node_or_null("Player") as Node3D
