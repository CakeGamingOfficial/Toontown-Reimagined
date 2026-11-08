class_name MagicWords
extends RefCounted

## Developer magic words, the ~ lines from the magic word manager. Typed into
## SpeedChat+, they run here instead of coming out of the toon as chat.

const _KEYS := preload("res://scenes/shticker/keybinds.gd")
const _PLACES := preload("res://scenes/places/hood_places.gd")
const _ARRIVAL := preload("res://scenes/playgrounds/playground_toon.gd")
const _BEANS := preload("res://scenes/toons/jellybeans.gd")

## HoodsForTeleportAll. Funny Farm stays off the list.
const _TELEPORT_ALL: Array[int] = [
	1000, 2000, 3000, 4000, 5000, 6000, 8000, 9000,
	10000, 11000, 12000, 13000, 17000,
]
const _RUN_SCALE := 4.0
const _FLY_SPEED := 36.0
const _FLY_FAST := 90.0
const _HELP := "~help   ~tp ttc   ~hp 15   ~maxhp 137\n~run   ~oobe   ~getpos   ~setpos x y z\n~immortal   ~ghost   ~collisions off   ~restock   ~max\n~mg maze   ~mg random   ~suit flunky   ~suit pp 5 skelecog   ~suit flunky v2   ~suit flunky laser   ~suit flunky waiter\n~spawnbuilding sellbot 1   ~spawnbuilding flunky   ~freebldg\n~togglegm   ~setgm 1\n~quest finish 164   ~quest finish 1   ~quest set 164   ~quest set 2 175\n~holiday 7   ~holiday Fish Bingo   ~startholiday 3   ~endholiday 3
~invasion start flunky 1000   ~invasion start flunky v2   ~invasion start flunky laser   ~invasion start flunky waiter   ~invasion start sellbot 1000   ~invasion start f 1000 true   ~invasion stop   ~invasionstatus\n~acc hbb1   ~hat 0   ~glasses   ~backpack   ~shoes\n~districts   ~district host   ~district join 127.0.0.1"
const _HOLIDAYS := preload("res://scenes/shticker/calendar_holidays.gd")
const _GM_NAMES: PackedStringArray = ["TOON COUNCIL", "TOON TROOPER", "RESISTANCE RANGER", "GC"]

const _WORDS: Dictionary = {
	"help": "help",
	"tp": "tp",
	"goto": "tp",
	"hp": "hp",
	"laff": "hp",
	"setlaff": "hp",
	"sethp": "hp",
	"maxhp": "maxhp",
	"maxlaff": "maxhp",
	"setmaxlaff": "maxhp",
	"run": "run",
	"oobe": "oobe",
	"getpos": "getpos",
	"pos": "getpos",
	"setpos": "setpos",
	"immortal": "immortal",
	"invincible": "immortal",
	"invulnerable": "immortal",
	"ghost": "ghost",
	"invisible": "ghost",
	"collisions": "collisions",
	"collide": "collisions",
	"noclip": "noclip",
	"gags": "restock",
	"inv": "restock",
	"restock": "restock",
	"max": "max",
	"idkfa": "max",
	"minigame": "minigame",
	"mg": "minigame",
	"trolley": "minigame",
	"suit": "suit",
	"cog": "suit",
	"spawn": "suit",
	"summon": "suit",
	"spawnbuilding": "spawnbuilding",
	"spawnbldg": "spawnbuilding",
	"building": "spawnbuilding",
	"bldg": "spawnbuilding",
	"freebldg": "freebldg",
	"togglegm": "gm",
	"setgm": "gm",
	"icon": "gm",
	"seticon": "gm",
	"gm": "gm",
	"gmicon": "gm",
	"setgmicon": "gm",
	"districts": "districts",
	"district": "district",
	"shard": "district",
	"hat": "accessory",
	"sethat": "accessory",
	"glasses": "accessory",
	"setglasses": "accessory",
	"backpack": "accessory",
	"setbackpack": "accessory",
	"shoes": "accessory",
	"setshoes": "accessory",
	"accessory": "accessory",
	"accessories": "accessory",
	"acc": "accessory",
	"quest": "quest",
	"quests": "quest",
	"task": "quest",
	"tasks": "quest",
	"toontask": "quest",
	"toontasks": "quest",
	"startholiday": "startholiday",
	"starth": "startholiday",
	"endholiday": "endholiday",
	"endh": "endholiday",
	"holiday": "holiday",
	"holidays": "holiday",
	"invasion": "invasion",
	"invasions": "invasion",
	"spawninvasion": "invasion",
	"deptinvasion": "deptinvasion",
	"invasionstatus": "invasionstatus",
}

## Trolley games. Names match ToontownGlobals.MinigameNames.
const _TROLLEY: Dictionary = {
	"race": 1,
	"cannon": 2,
	"tag": 3,
	"pattern": 4,
	"minnie": 4,
	"match": 4,
	"matching": 4,
	"ring": 5,
	"maze": 6,
	"tug": 7,
	"tugofwar": 7,
	"catch": 8,
	"diving": 9,
	"dive": 9,
	"target": 10,
	"slingshot": 10,
	"pairing": 11,
	"memory": 11,
	"vine": 12,
	"vines": 12,
	"jungle": 12,
	"ice": 13,
	"iceslide": 13,
	"slide": 13,
	"thief": 14,
	"cogthief": 14,
	"2d": 15,
	"twod": 15,
	"escape": 15,
}

const _TROLLEY_NAMES: Dictionary = {
	1: "Race Game",
	2: "Cannon Game",
	3: "Tag Game",
	4: "Match Minnie",
	5: "Ring Game",
	6: "Maze Game",
	7: "Tug-of-War",
	8: "Catching Game",
	9: "Treasure Dive",
	10: "Toon Slingshot",
	11: "Toon Memory Game",
	12: "Jungle Vines",
	13: "Ice Slide",
	14: "Cog Thief",
	15: "Toon Escape",
}

const _ZONES: Dictionary = {
	"dd": 1000,
	"dock": 1000,
	"donaldsdock": 1000,
	"ttc": 2000,
	"central": 2000,
	"toontowncentral": 2000,
	"tb": 3000,
	"brrrgh": 3000,
	"thebrrrgh": 3000,
	"mml": 4000,
	"melody": 4000,
	"minniesmelodyland": 4000,
	"dg": 5000,
	"gardens": 5000,
	"daisygardens": 5000,
	"aa": 6000,
	"oz": 6000,
	"acorn": 6000,
	"acornacres": 6000,
	"gs": 8000,
	"speedway": 8000,
	"goofyspeedway": 8000,
	"ddl": 9000,
	"dreamland": 9000,
	"donaldsdreamland": 9000,
	"bbhq": 10000,
	"bossbot": 10000,
	"sbhq": 11000,
	"sellbot": 11000,
	"cbhq": 12000,
	"cashbot": 12000,
	"lbhq": 13000,
	"lawbot": 13000,
	"estate": 16000,
	"golf": 17000,
	"gz": 17000,
	"minigolf": 17000,
}

const _ZONE_NAMES: Dictionary = {
	1000: "Donald's Dock",
	2000: "Toontown Central",
	3000: "The Brrrgh",
	4000: "Minnie's Melodyland",
	5000: "Daisy Gardens",
	6000: "Acorn Acres",
	8000: "Goofy Speedway",
	9000: "Donald's Dreamland",
	10000: "Bossbot HQ",
	11000: "Sellbot HQ",
	12000: "Cashbot HQ",
	13000: "Lawbot HQ",
	16000: "your estate",
	17000: "Chip 'n Dale's Minigolf",
}

static var _run := false
static var _run_loaded := false
static var _oobe := false
static var _immortal := false
static var _ghost := false


static func ghosting() -> bool:
	return _ghost
static var _noclip := false
static var _hover_y := 0.0
static var _fly_yaw := 0.0
static var _fly_pitch := 0.0
static var _fly_ready := false
static var _trolley_next := 0
## SetGM icon id. 0 is off. 1..4 are TOON COUNCIL, TOON TROOPER, RESISTANCE RANGER, GC.
static var _gm := 0


static func looks_like(text: String) -> bool:
	return text.begins_with("~")


static func run_scale() -> float:
	_ensure_run()
	return _RUN_SCALE if _run else 1.0


static func _ensure_run() -> void:
	if _run_loaded:
		return
	_run_loaded = true
	var config := ConfigFile.new()
	if config.load("user://magic.cfg") != OK:
		return
	_run = bool(config.get_value("words", "run", false))


static func _save_run() -> void:
	var config := ConfigFile.new()
	config.load("user://magic.cfg")
	config.set_value("words", "run", _run)
	config.save("user://magic.cfg")


static func detached_camera() -> bool:
	return _oobe


static func ignores_damage() -> bool:
	return _immortal


static func noclip() -> bool:
	return _noclip


## The next trolley boarding uses this id once, then goes back to random.
static func take_trolley_game() -> int:
	var game_id := _trolley_next
	_trolley_next = 0
	return game_id


static func invoke(scene: Node, text: String) -> String:
	var body := text.substr(1).strip_edges()
	if body == "":
		return _HELP
	var parts := body.split(" ", false)
	var word := String(parts[0]).to_lower()
	var args: PackedStringArray = []
	for index in range(1, parts.size()):
		args.append(String(parts[index]))
	if not _WORDS.has(word):
		var prefix := _unique_prefix(word)
		if prefix == "":
			return _unknown(word)
		word = prefix
	match String(_WORDS[word]):
		"help":
			return _HELP
		"tp":
			return _teleport(scene, args)
		"hp":
			return _set_hp(scene, args, false)
		"maxhp":
			return _set_hp(scene, args, true)
		"run":
			_ensure_run()
			_run = not _run
			_save_run()
			return "Run mode is on." if _run else "Run mode is off."
		"oobe":
			return _toggle_oobe(scene)
		"getpos":
			return _get_pos(scene)
		"setpos":
			return _set_pos(scene, args)
		"immortal":
			_immortal = not _immortal
			return "Immortal mode is on." if _immortal else "Immortal mode is off."
		"ghost":
			_ghost = not _ghost
			return "Ghost mode is on. You look see-through, and other players won't see you." if _ghost else "Ghost mode is off."
		"collisions":
			return _set_collisions(scene, args)
		"noclip":
			return _set_collisions(scene, PackedStringArray(["off" if not _noclip else "on"]))
		"restock":
			return _restock(scene, false)
		"max":
			return _restock(scene, true)
		"minigame":
			return _request_trolley(args)
		"suit":
			return _summon_suit(scene, args)
		"spawnbuilding":
			return _spawn_building(scene, args)
		"freebldg":
			return _free_building(scene)
		"gm":
			return _set_gm(word, args)
		"districts":
			return _districts_word(PackedStringArray())
		"district":
			return _districts_word(args)
		"accessory":
			return _accessory(scene, word, args)
		"quest":
			return _quest_word(scene, args)
		"startholiday":
			return _holiday_word(scene, args, true)
		"endholiday":
			return _holiday_word(scene, args, false)
		"holiday":
			return _holiday_toggle(scene, args)
		"invasion":
			return _invasion_word(args)
		"deptinvasion":
			return _dept_invasion_word(args)
		"invasionstatus":
			return _HOLIDAYS.invasion_status()
	return "Uh-oh! This Magic Word doesn't exist!"


static func maintain(scene: Node) -> void:
	var body := scene.get_node_or_null("Player") as CharacterBody3D
	if body == null:
		return
	var toon := _toon(body) as ToonActor
	if toon != null and toon.ghost_mode != _ghost:
		# This body is the local player. A replicated toon passes false and is not drawn.
		toon.set_ghost_mode(_ghost, true)
	if _noclip:
		if not body.has_meta("magic_mask"):
			body.set_meta("magic_mask", body.collision_mask)
			body.set_meta("magic_layer", body.collision_layer)
			_hover_y = body.global_position.y
		body.collision_mask = 0
		body.collision_layer = 0
		body.velocity.y = 0.0
		var delta := scene.get_process_delta_time()
		if _KEYS.held("jump"):
			_hover_y += 12.0 * delta
		if not _KEYS.typing() and Input.is_physical_key_pressed(KEY_C):
			_hover_y -= 12.0 * delta
		body.global_position.y = _hover_y
	elif body.has_meta("magic_mask"):
		body.collision_mask = int(body.get_meta("magic_mask"))
		body.collision_layer = int(body.get_meta("magic_layer"))
		body.remove_meta("magic_mask")
		body.remove_meta("magic_layer")


static func fly_camera(camera: Camera3D, delta: float) -> void:
	if not _oobe or camera == null:
		return
	if not _fly_ready:
		var facing := -camera.global_basis.z
		_fly_pitch = asin(clampf(facing.y, -1.0, 1.0))
		_fly_yaw = atan2(facing.x, -facing.z)
		_fly_ready = true
	var owner := camera.get_viewport().gui_get_focus_owner()
	if owner is LineEdit:
		return
	var motion := Input.get_last_mouse_velocity()
	_fly_yaw -= motion.x * delta * 0.003
	_fly_pitch = clampf(_fly_pitch - motion.y * delta * 0.003, deg_to_rad(-85.0), deg_to_rad(85.0))
	var basis := Basis.from_euler(Vector3(_fly_pitch, _fly_yaw, 0.0))
	var wish := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		wish -= basis.z
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		wish += basis.z
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		wish -= basis.x
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		wish += basis.x
	if Input.is_physical_key_pressed(KEY_E):
		wish.y += 1.0
	if Input.is_physical_key_pressed(KEY_Q):
		wish.y -= 1.0
	var speed := _FLY_FAST if Input.is_physical_key_pressed(KEY_SHIFT) else _FLY_SPEED
	if wish.length_squared() > 0.001:
		camera.global_position += wish.normalized() * speed * delta
	camera.global_basis = basis


static func _toggle_oobe(scene: Node) -> String:
	_oobe = not _oobe
	_fly_ready = false
	if not _oobe:
		return "Oobe mode is off."
	var camera := _camera(scene)
	if camera != null:
		var facing := -camera.global_basis.z
		_fly_pitch = asin(clampf(facing.y, -1.0, 1.0))
		_fly_yaw = atan2(facing.x, -facing.z)
		_fly_ready = true
	return "Oobe mode is on. Mouse looks, WASD flies, E and Q go up and down."


static func _teleport(scene: Node, args: PackedStringArray) -> String:
	if args.is_empty():
		return "Teleport where? Try ~tp ttc, dd, dg, mml, tb, ddl, aa, gs, estate, or a HQ."
	var key := _zone_key(args[0])
	var hood := 0
	if _ZONES.has(key):
		hood = int(_ZONES[key])
	elif args[0].is_valid_int():
		hood = _PLACES.hood_of(int(args[0]))
	else:
		return "Unknown zone! Try ttc, dd, dg, mml, tb, ddl, aa, gs, estate, sbhq, cbhq, lbhq, or bbhq."
	var place := String(_ZONE_NAMES.get(hood, "zone %d" % hood))
	var arrival := scene.get_node_or_null("PlaygroundToon")
	if arrival != null and arrival.has_method("teleport_to_hood"):
		arrival.teleport_to_hood(hood)
		return "Throwing a hole to %s." % place
	var tasks := ToonTasks.for_selected()
	if tasks != null and not tasks.in_playground:
		tasks.note_playground()
	if tasks != null:
		tasks.note_hood(hood)
	_ARRIVAL.teleport_in = true
	_ARRIVAL.portal_in = true
	ToonLoading.change_to(_PLACES.scene_for(hood))
	return "Teleporting to %s." % place


static func _set_hp(scene: Node, args: PackedStringArray, maximum: bool) -> String:
	var loadout := _loadout(scene)
	if loadout == null:
		return "No laff meter here."
	if args.is_empty():
		return "Laff is %d / %d." % [loadout.hp, loadout.max_hp]
	if not args[0].is_valid_int():
		return "That laff value isn't a number."
	var value := int(args[0])
	if maximum:
		if value < 15 or value > 137:
			return "Max laff has to be from 15 to 137."
		loadout.set_hp(value, value)
		loadout.save()
		return "Max laff is now %d." % value
	if value < 0 or value > loadout.max_hp:
		return "Laff has to be from 0 to %d." % loadout.max_hp
	loadout.set_hp(value, loadout.max_hp)
	loadout.save()
	return "Laff is now %d." % value


static func _restock(scene: Node, everything: bool) -> String:
	var loadout := _loadout(scene)
	if loadout == null:
		return "No gag pouch here."
	var filled := 0
	if everything:
		loadout.set_hp(137, 137)
		loadout.save()
		filled = loadout.unlock_all()
		_BEANS.set_pouch_limit(_BEANS.POUCH_MAX)
		_BEANS.fill_pouch()
		var tasks := ToonTasks.live()
		for hood in _TELEPORT_ALL:
			tasks.grant_teleport(hood)
			tasks._remember(hood)
		tasks.save()
	else:
		filled = loadout.restock()
	var book := _find(scene, "ShtickerBook") as ShtickerBook
	if book != null:
		book.refresh_gags()
		book.refresh_jar()
	if filled <= 0:
		return "No gags are unlocked yet. ~max unlocks them."
	if everything:
		return "Maxed laff to 137, gag pouch to %d, jellybean jar to %d, filled %d gags, and opened teleport to every playground and Cog HQ." % [loadout.max_carry, _BEANS.pouch_limit(), filled]
	return "Restocked %d gags." % filled


static func _get_pos(scene: Node) -> String:
	var body := scene.get_node_or_null("Player") as Node3D
	if body == null:
		return "No toon to measure."
	var where := body.global_position
	return "Position is %.2f %.2f %.2f.\n%s" % [where.x, where.y, where.z, ToonNet.where_text()]


static func _set_pos(scene: Node, args: PackedStringArray) -> String:
	var body := scene.get_node_or_null("Player") as Node3D
	if body == null:
		return "No toon to move."
	if args.size() < 3 or not args[0].is_valid_float() or not args[1].is_valid_float() or not args[2].is_valid_float():
		return "Use ~setpos x y z."
	body.global_position = Vector3(float(args[0]), float(args[1]), float(args[2]))
	_hover_y = body.global_position.y
	return "Moved to %.2f %.2f %.2f." % [body.global_position.x, body.global_position.y, body.global_position.z]


static func _set_collisions(scene: Node, args: PackedStringArray) -> String:
	var body := scene.get_node_or_null("Player") as CharacterBody3D
	if body == null:
		return "No toon to clip."
	var turn_off := not _noclip
	if not args.is_empty():
		var flag := args[0].to_lower()
		if flag == "on":
			turn_off = false
		elif flag == "off":
			turn_off = true
		else:
			return "Use ~collisions on or ~collisions off."
	_noclip = turn_off
	if _noclip:
		_hover_y = body.global_position.y
		return "Collisions are off. Jump rises, C sinks."
	return "Collisions are on."


static func _request_trolley(args: PackedStringArray) -> String:
	var token := ""
	if not args.is_empty():
		token = args[0].to_lower()
		if token == "request" or token == "next" or token == "teleport" or token == "tp":
			token = args[1].to_lower() if args.size() > 1 else ""
	var key := token.replace(" ", "").replace("-", "").replace("_", "").replace("'", "")
	if key == "":
		if _trolley_next == 0:
			return "The next trolley game is random. " + _trolley_choices()
		return "The next trolley game will be %s. ~mg random puts it back." % String(_TROLLEY_NAMES[_trolley_next])
	if key == "random" or key == "clear" or key == "off" or key == "any" or key == "none":
		_trolley_next = 0
		ToonNet.reserve_trolley(0)
		return "The next trolley game is random again."
	var game_id := 0
	if key.is_valid_int():
		game_id = int(key)
	elif _TROLLEY.has(key):
		game_id = int(_TROLLEY[key])
	else:
		return "Unknown trolley game \"%s\". %s" % [token, _trolley_choices()]
	if not _TROLLEY_NAMES.has(game_id):
		return "That game isn't on the solo trolley. " + _trolley_choices()
	_trolley_next = game_id
	# RequestMinigame[avId] lives on the district AI, not on this client.
	ToonNet.reserve_trolley(game_id)
	return "The next trolley game will be %s." % String(_TROLLEY_NAMES[game_id])


## DistributedToonAI.doSummonSingleCog asks the street planner for one named
## suit. The landing is the closest suit point to the toon.
static func _districts_word(args: PackedStringArray) -> String:
	if args.is_empty():
		return "%s\n%s" % [ToonNet.where_text(), ToonNet.roster_text()]
	var head := args[0].to_lower()
	if head == "host":
		var port := 4343
		if args.size() > 1 and args[1].is_valid_int():
			port = int(args[1])
		return ToonNet.host_game(port)
	if head == "join":
		if args.size() < 2:
			return "Use ~district join address."
		var port := 4343
		if args.size() > 2 and args[2].is_valid_int():
			port = int(args[2])
		return ToonNet.join_server(args[1], port)
	if head == "close" or head == "disconnect":
		return ToonNet.disconnect_net()
	if head == "open":
		if args.size() < 2:
			return "Use ~district open Name."
		var district_name := ""
		for index in range(1, args.size()):
			if district_name != "":
				district_name += " "
			district_name += args[index]
		return ToonNet.open_district(district_name)
	var district_name := ""
	for index in args.size():
		if district_name != "":
			district_name += " "
		district_name += args[index]
	return ToonNet.join_named(district_name)


static func gm_type() -> int:
	return _gm


static func gm_name() -> String:
	return gm_title(_gm)


static func gm_title(kind: int) -> String:
	if kind <= 0 or kind > _GM_NAMES.size():
		return ""
	return _GM_NAMES[kind - 1]


## The district AI consumed this toon's trolley request by starting that game.
static func note_played(game_id: int) -> void:
	if _trolley_next == game_id:
		_trolley_next = 0


## SetGM. ~togglegm with no number flips the Toon Council icon. The original
## aliases default to 0, which clears it. A number 0..4 sets that icon.
static func _set_gm(word: String, args: PackedStringArray) -> String:
	var request := 0
	if args.is_empty():
		request = 0 if word != "togglegm" or _gm > 0 else 1
	elif not args[0].is_valid_int():
		return "Invalid GM icon ID!"
	else:
		request = int(args[0])
	if request < 0 or request > _GM_NAMES.size():
		return "Invalid GM icon ID!"
	# b_setGM(0) then b_setGM(iconRequest). The second call is the one that sticks.
	_gm = 0
	_gm = request
	return "GM icon set to %d." % request


static func _spawn_building(scene: Node, args: PackedStringArray) -> String:
	var suits := scene.get_node_or_null("StreetSuits")
	var buildings := scene.get_node_or_null("StreetBuildings")
	var body := scene.get_node_or_null("Player") as Node3D
	if suits == null or buildings == null or body == null or not suits.has_method("spawn_building"):
		return "Cog buildings can only be spawned on a street."
	if args.is_empty():
		return "Use ~spawnbuilding sellbot 1, or ~spawnbuilding flunky."
	return String(suits.call("spawn_building", " ".join(args), body.global_position))


static func _free_building(scene: Node) -> String:
	var suits := scene.get_node_or_null("StreetSuits")
	var buildings := scene.get_node_or_null("StreetBuildings")
	var body := scene.get_node_or_null("Player") as Node3D
	if suits == null or buildings == null or body == null or not suits.has_method("free_building"):
		return "Cog buildings can only be freed on a street."
	return String(suits.call("free_building", body.global_position))


static func _summon_suit(scene: Node, args: PackedStringArray) -> String:
	if args.is_empty():
		return "Name a cog. Try ~suit flunky, ~suit pp 5, or ~suit cold caller skelecog."
	var level := -1
	var name_args := PackedStringArray()
	for arg in args:
		if level < 0 and arg.is_valid_int():
			level = int(arg)
		else:
			name_args.append(arg)
	var query := " ".join(name_args)
	var suits := scene.get_node_or_null("StreetSuits")
	if suits == null or not suits.has_method("summon_named"):
		return "Cogs can only be summoned on a street."
	var body := scene.get_node_or_null("Player") as Node3D
	if body == null:
		return "Cogs can only be summoned on a street."
	return String(suits.call("summon_named", query, level, body.global_position))


static func _quest_word(scene: Node, args: PackedStringArray) -> String:
	var tasks := ToonTasks.live()
	if tasks == null:
		return "No ToonTask journal here."
	if args.is_empty():
		return "Try ~quest finish 164, ~quest finish 1, ~quest set 164, or ~quest set 2 175."
	var command := args[0].to_lower()
	if command == "finish" or command == "complete" or command == "done":
		if args.size() < 2 or not args[1].is_valid_int():
			var finished_all := tasks.finish_active(0)
			_refresh_tasks(scene)
			if finished_all.is_empty():
				return "You have no ToonTask."
			if finished_all.size() == 1:
				return "Finished %s. Turn it in." % finished_all[0]
			return "Finished %d ToonTasks. Turn them in." % finished_all.size()
		var picked := _journal_quest(tasks, int(args[1]))
		if picked < 0:
			return "ToonTask %d is not in your journal." % int(args[1])
		var finished := tasks.finish_active(picked)
		_refresh_tasks(scene)
		if finished.is_empty():
			return "ToonTask %d is not in your journal." % int(args[1])
		return "Finished %s. Turn it in." % finished[0]
	var quest_id := 0
	var slot := 0
	if command == "set":
		if args.size() >= 3 and args[1].is_valid_int() and args[2].is_valid_int():
			slot = int(args[1])
			quest_id = int(args[2])
		elif args.size() >= 2 and args[1].is_valid_int():
			quest_id = int(args[1])
		else:
			return "Set which ToonTask? Try ~quest set 164, or ~quest set 2 175."
	elif command.is_valid_int():
		quest_id = int(command)
	else:
		return "Try ~quest finish 164, ~quest finish 1, ~quest set 164, or ~quest set 2 175."
	var caption := tasks.set_slot(slot, quest_id) if slot > 0 else tasks.replace_with(quest_id)
	_refresh_tasks(scene)
	if caption == "":
		if slot > 0:
			return "Can't set task %d to ToonTask %d." % [slot, quest_id]
		return "No ToonTask %d." % quest_id
	if slot > 0:
		return "Task %d is now %d, %s." % [slot, quest_id, caption]
	return "Current ToonTask is %d, %s." % [quest_id, caption]


## 164 is that quest. 1 is the first poster when you are not carrying quest 1.
static func _journal_quest(tasks: ToonTasks, number: int) -> int:
	var ids := tasks.active_ids()
	if ids.has(number):
		return number
	if number >= 1 and number <= ids.size():
		return ids[number - 1]
	return -1


static func _invasion_word(args: PackedStringArray) -> String:
	if args.is_empty():
		return "You didn't enter a valid command! Commands are ~invasion start or stop."
	var command := args[0].to_lower()
	var amount := 1000
	var skeleton := false
	var revives := false
	var laser := false
	var waiter := false
	var names := PackedStringArray()
	for index in range(1, args.size()):
		var token := args[index]
		var key := token.to_lower()
		if _laser_word(key):
			laser = true
			skeleton = true
		elif _skeleton_word(key):
			skeleton = true
		elif _revive_word(key):
			revives = true
		elif _waiter_word(key):
			waiter = true
		elif key == "false" or key == "no":
			skeleton = false
			revives = false
			laser = false
			waiter = false
		elif token.is_valid_int():
			amount = int(token)
		else:
			names.append(token)
	var clash := _variant_clash(skeleton, revives, laser, waiter)
	if clash != "":
		return clash
	if amount < 10 or amount > 25000:
		return "Can't the invasion amount to %d! Specify a value between 10 and 25,000." % amount
	if command == "start":
		var query := "f" if names.is_empty() else " ".join(names)
		var dept := "" if names.is_empty() else _HOLIDAYS.dept_named(query)
		if dept != "" and not _exact_cog(query):
			return _HOLIDAYS.begin_dept_invasion(dept, amount, skeleton, revives, laser, waiter)
		var cog := _cog_named(query)
		if cog.is_empty():
			return "This cog does not exist!"
		return _HOLIDAYS.begin_invasion(cog, amount, skeleton, revives, laser, waiter)
	if command == "stop" or command == "end":
		return _HOLIDAYS.end_invasion()
	return "You didn't enter a valid command! Commands are ~invasion start or stop."


static func _dept_invasion_word(args: PackedStringArray) -> String:
	if args.is_empty():
		return "Use ~deptinvasion sellbot. Departments are Bossbot, Lawbot, Cashbot, and Sellbot."
	var amount := 1000
	var skeleton := false
	var revives := false
	var laser := false
	var waiter := false
	var names := PackedStringArray()
	for token in args:
		var key := token.to_lower()
		if _laser_word(key):
			laser = true
			skeleton = true
		elif _skeleton_word(key):
			skeleton = true
		elif _revive_word(key):
			revives = true
		elif _waiter_word(key):
			waiter = true
		elif key == "false" or key == "no":
			skeleton = false
			revives = false
			laser = false
			waiter = false
		elif token.is_valid_int():
			amount = int(token)
		else:
			names.append(token)
	var clash := _variant_clash(skeleton, revives, laser, waiter)
	if clash != "":
		return clash
	if amount < 10 or amount > 25000:
		return "Can't the invasion amount to %d! Specify a value between 10 and 25,000." % amount
	var dept := _HOLIDAYS.dept_named(" ".join(names))
	if dept == "":
		return "That department does not exist! Departments are Bossbot, Lawbot, Cashbot, and Sellbot."
	return _HOLIDAYS.begin_dept_invasion(dept, amount, skeleton, revives, laser, waiter)


static func _skeleton_word(key: String) -> bool:
	return key == "true" or key == "yes" or key == "skelecog" or key == "skele" or key == "skeleton"


static func _revive_word(key: String) -> bool:
	return key == "v2" or key == "v2.0" or key == "version2" or key == "revive"


static func _laser_word(key: String) -> bool:
	return key == "laser" or key == "lasers" or key == "virtual"


static func _waiter_word(key: String) -> bool:
	return key == "waiter" or key == "waiters"


static func _variant_clash(skeleton: bool, revives: bool, laser: bool, waiter: bool) -> String:
	if (skeleton or laser) and revives:
		return "A v2.0 Cog can't be a Skelecog."
	if waiter and (skeleton or laser):
		return "A waiter Cog can't be a Skelecog."
	return ""


static func _exact_cog(query: String) -> bool:
	var wanted := StreetSuits.cog_key(query)
	if wanted.is_empty():
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cogs/catalog.json"))
	if not (parsed is Dictionary):
		return false
	var cogs: Variant = (parsed as Dictionary).get("cogs", [])
	if not (cogs is Array):
		return false
	for item in cogs:
		if not (item is Dictionary):
			continue
		var cog: Dictionary = item
		if wanted == StreetSuits.cog_key(String(cog.get("code", ""))):
			return true
		if wanted == StreetSuits.cog_key(String(cog.get("name", ""))):
			return true
	return false


static func _cog_named(query: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cogs/catalog.json"))
	if not (parsed is Dictionary):
		return {}
	var cogs: Variant = (parsed as Dictionary).get("cogs", [])
	if not (cogs is Array):
		return {}
	return StreetSuits.match_cog(cogs, query)


static func _holiday_word(scene: Node, args: PackedStringArray, starting: bool) -> String:
	if args.is_empty():
		return "Use ~holiday 7 to toggle one. ~startholiday 3 starts it, ~endholiday 3 ends it."
	var reply := _HOLIDAYS.start_text(" ".join(args)) if starting else _HOLIDAYS.stop_text(" ".join(args))
	_refresh_holidays(scene)
	return reply


static func _holiday_toggle(scene: Node, args: PackedStringArray) -> String:
	if args.is_empty():
		return "Use ~holiday 7, ~holiday Fish Bingo, or ~holiday Bloodsucker."
	var reply := String(_HOLIDAYS.toggle(" ".join(args)))
	_refresh_holidays(scene)
	return reply


static func _refresh_holidays(scene: Node) -> void:
	var page := scene.find_child("EventsPage", true, false) if scene != null else null
	if page != null and page.has_method("refresh"):
		page.call("refresh")


static func _refresh_tasks(scene: Node) -> void:
	if scene == null:
		return
	var book := scene.find_child("ShtickerBook", true, false)
	if book != null and book.has_method("refresh_tasks"):
		book.call("refresh_tasks")


static func _trolley_choices() -> String:
	return "Try ~mg race, cannon, tag, minnie, ring, maze, tug, catch, diving, slingshot, memory, vine, ice, thief, or escape."


static func _unique_prefix(word: String) -> String:
	if word.length() < 2:
		return ""
	var found := ""
	for alias in _WORDS.keys():
		var name := String(alias)
		if not name.begins_with(word):
			continue
		if found != "" and found != name:
			return ""
		found = name
	return found


static func _unknown(word: String) -> String:
	var guess := ""
	for alias in _WORDS.keys():
		var name := String(alias)
		if word.length() >= 2 and (name.begins_with(word) or name.contains(word)):
			guess = name
			break
	if guess != "":
		return "This Magic Word doesn't exist! I read ~%s. Did you mean ~%s?" % [word, guess]
	return "Uh-oh! This Magic Word doesn't exist! I read ~%s. ~help lists them." % word


static func _zone_key(raw: String) -> String:
	var key := raw.to_lower()
	key = key.replace("'", "")
	key = key.replace(" ", "")
	return key


static func _loadout(scene: Node) -> ToonLoadout:
	var meter := _find(scene, "LaffMeter") as LaffMeter
	if meter == null:
		return null
	return meter.loadout()


static func _camera(scene: Node) -> Camera3D:
	var named := scene.get_node_or_null("ToonCamera") as Camera3D
	if named != null:
		return named
	return scene.get_node_or_null("Camera") as Camera3D


static var _acc_items: Dictionary = {}
static var _acc_loaded := false


## setHat, setGlasses, setBackpack, and setShoes. A style code such as hbb1
## wears that catalog item. Three numbers are the model, texture, and color.
## No argument, or 0, takes that accessory off.
static func _accessory(scene: Node, word: String, args: PackedStringArray) -> String:
	var slot := ""
	match word:
		"hat", "sethat":
			slot = "hat"
		"glasses", "setglasses":
			slot = "glasses"
		"backpack", "setbackpack":
			slot = "backpack"
		"shoes", "setshoes":
			slot = "shoes"
	var rest := args
	if slot == "" and not rest.is_empty() and ["hat", "glasses", "backpack", "shoes"].has(rest[0].to_lower()):
		slot = rest[0].to_lower()
		rest = rest.slice(1)
	if rest.is_empty() or rest[0].to_lower() == "off" or rest[0] == "0":
		if slot == "":
			return "Usage: ~acc hbb1   ~hat 1 0 0   ~glasses off"
		_apply_accessory(scene, slot, -1)
		return "%s removed." % slot.capitalize()
	var found := _find_accessory(slot, rest)
	if found.is_empty():
		return "That accessory isn't in the catalog."
	slot = String(found.get("slot", slot))
	_apply_accessory(scene, slot, int(found.get("id", -1)))
	var label := String(found.get("name", ""))
	if label == "":
		label = String(found.get("code", ""))
	return "Set %s to %s." % [slot, label]


static func _apply_accessory(scene: Node, slot: String, item_id: int) -> void:
	CatalogCloset.set_accessory(slot, item_id)
	var body := scene.get_node_or_null("Player")
	if body == null:
		body = _find(scene, "Player")
	if body == null:
		return
	var toon := _toon(body) as ToonActor
	if toon:
		toon.wear_accessories(CatalogCloset.accessory_ids())


static func _find_accessory(slot: String, args: PackedStringArray) -> Dictionary:
	var items := _accessory_items()
	if not args[0].is_valid_int():
		var code := args[0].to_lower()
		for item_id in items.keys():
			var item: Dictionary = items[item_id]
			if String(item.get("code", "")).to_lower() != code:
				continue
			if slot != "" and String(item.get("slot", "")) != slot:
				continue
			var copy := item.duplicate()
			copy["id"] = int(String(item_id))
			return copy
		return {}
	var index := int(args[0])
	var tex := int(args[1]) if args.size() > 1 and args[1].is_valid_int() else 0
	var color := int(args[2]) if args.size() > 2 and args[2].is_valid_int() else 0
	if index <= 0:
		return {}
	for item_id in items.keys():
		var item: Dictionary = items[item_id]
		if slot != "" and String(item.get("slot", "")) != slot:
			continue
		if int(item.get("index", -1)) != index:
			continue
		if int(item.get("tex", 0)) != tex:
			continue
		if int(item.get("color", 0)) != color:
			continue
		var copy := item.duplicate()
		copy["id"] = int(String(item_id))
		return copy
	return {}


static func _accessory_items() -> Dictionary:
	if _acc_loaded:
		return _acc_items
	_acc_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/toons/accessories/catalog.json"))
	if parsed is Dictionary:
		var items: Variant = (parsed as Dictionary).get("items", {})
		if items is Dictionary:
			_acc_items = items
	return _acc_items


static func _toon(body: Node) -> Node3D:
	for child in body.get_children():
		if child is ToonActor:
			return child as Node3D
	return null


static func _find(node: Node, wanted: String) -> Node:
	if node == null:
		return null
	if String(node.name) == wanted:
		return node
	for child in node.get_children():
		var found := _find(child, wanted)
		if found != null:
			return found
	return null
