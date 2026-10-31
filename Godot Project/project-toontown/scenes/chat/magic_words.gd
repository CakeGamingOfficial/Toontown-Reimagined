class_name MagicWords
extends RefCounted

## Developer magic words, the ~ lines from the magic word manager. Typed into
## SpeedChat+, they run here instead of coming out of the toon as chat.

const _KEYS := preload("res://scenes/shticker/keybinds.gd")
const _PLACES := preload("res://scenes/places/hood_places.gd")
const _ARRIVAL := preload("res://scenes/playgrounds/playground_toon.gd")

const _RUN_SCALE := 4.0
const _FLY_SPEED := 36.0
const _FLY_FAST := 90.0
const _HELP := "~help   ~tp ttc   ~hp 15   ~maxhp 137\n~run   ~oobe   ~getpos   ~setpos x y z\n~immortal   ~ghost   ~collisions off   ~restock   ~max\n~mg maze   ~mg random"

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
}

## Solo games from MinigamePlayerMatrix. Names match ToontownGlobals.MinigameNames.
const _TROLLEY: Dictionary = {
	"cannon": 2,
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
	"thief": 14,
	"cogthief": 14,
	"2d": 15,
	"twod": 15,
	"escape": 15,
}

const _TROLLEY_NAMES: Dictionary = {
	2: "Cannon Game",
	5: "Ring Game",
	6: "Maze Game",
	7: "Tug-of-War",
	8: "Catching Game",
	9: "Treasure Dive",
	10: "Toon Slingshot",
	11: "Toon Memory Game",
	12: "Jungle Vines",
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
static var _oobe := false
static var _immortal := false
static var _ghost := false
static var _noclip := false
static var _hover_y := 0.0
static var _fly_yaw := 0.0
static var _fly_pitch := 0.0
static var _fly_ready := false
static var _trolley_next := 0


static func looks_like(text: String) -> bool:
	return text.begins_with("~")


static func run_scale() -> float:
	return _RUN_SCALE if _run else 1.0


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
		return _unknown(word)
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
			_run = not _run
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
	scene.get_tree().change_scene_to_file(_PLACES.scene_for(hood))
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
	else:
		filled = loadout.restock()
	var book := _find(scene, "ShtickerBook") as ShtickerBook
	if book != null:
		book.refresh_gags()
	if filled <= 0:
		return "No gags are unlocked yet. ~max unlocks them."
	if everything:
		return "Maxed laff to 137, gag pouch to %d, and filled %d gags." % [loadout.max_carry, filled]
	return "Restocked %d gags." % filled


static func _get_pos(scene: Node) -> String:
	var body := scene.get_node_or_null("Player") as Node3D
	if body == null:
		return "No toon to measure."
	var where := body.global_position
	return "Position is %.2f %.2f %.2f." % [where.x, where.y, where.z]


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
	return "The next trolley game will be %s." % String(_TROLLEY_NAMES[game_id])


static func _trolley_choices() -> String:
	return "Try ~mg cannon, ring, maze, tug, catch, diving, slingshot, memory, vine, thief, or escape."


static func _unknown(word: String) -> String:
	var guess := ""
	for alias in _WORDS.keys():
		var name := String(alias)
		if word.length() >= 2 and (name.begins_with(word) or name.contains(word)):
			guess = name
			break
	if guess != "":
		return "This Magic Word doesn't exist! Did you mean ~%s?" % guess
	return "Uh-oh! This Magic Word doesn't exist! ~help lists them."


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
