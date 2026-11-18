extends RefCounted

## TTSCKartRacingMenu, TTSCGolfMenu, TTSCFactoryMenu, and TTSCPromotionalMenu.
## Each menu is added in the same place the original adds it. Singing lives
## with the boarding menu: the localizer never wrote 9000-9008, so those
## rows are the eight notes TTEmote.singNote1 through singNote8 already play.

const _HOLIDAYS := preload("res://scenes/shticker/calendar_holidays.gd")
const _ELECTION := 8

const _RACING_TOP: Array[String] = [
	"Anyone want to race?",
	"Let's race!",
	"Want to race?",
	"Let's show off our karts!",
	"I don't have enough tickets.",
	"Let's race again!",
	"Want to race again?",
]
const _RACING_PLACES: Array[String] = [
	"Where should we meet?",
	"Let's go to the Race Tracks!",
	"Meet me at the Race Tracks!",
	"Let's go to Pit Row to show off our karts!",
	"I'm going to Pit Row to show off my kart!",
	"I need to go to the Kart Shop.",
	"Meet up near the Kart Shop!",
]
const _RACING_RACES: Array[String] = [
	"Where do you want to race?",
	"Let's pick a different race.",
	"Let's do a practice race.",
	"Let's do a battle race.",
	"I like the Screwball Stadium race!",
	"I like the Rustic Raceway race!",
	"I like the City Circuit race!",
	"I like the Corkscrew Coliseum race!",
	"I like the Airborne Acres race!",
	"I like the Blizzard Boulevard race!",
	"Let's race in the Screwball Stadium!",
	"Let's race on the Rustic Raceway!",
	"Let's race on the City Circuit!",
	"Let's race in the Corkscrew Coliseum!",
	"Let's race on the Airborne Acres!",
	"Let's race on the Blizzard Boulevard!",
]
const _RACING_TRACKS: Array[String] = [
	"Which track do you want to race on?",
	"Pick a track!",
	"Can we race on a different track?",
	"Let's pick a different track!",
	"I want to race on the first track!",
	"I want to race on the second track!",
	"I want to race on the third track!",
	"I want to race on the fourth track!",
	"I don't want to race on the first track!",
	"I don't want to race on the second track!",
	"I don't want to race on the third track!",
	"I don't want to race on the fourth track!",
]
const _RACING_COMPLIMENTS: Array[String] = [
	"Wow! You are FAST!",
	"You're too fast for me!",
	"Good race!",
	"I really like your kart!",
	"Sweet ride!",
	"Your kart is cool!",
	"Your kart is awesome!",
	"Your kart is totally sweet!",
]
const _RACING_TAUNTS: Array[String] = [
	"See you at the finish line!",
	"Too scared to race me?",
	"I'm as fast as lightning!",
	"You'll never catch me!",
	"You'll never beat me!",
	"No one can beat my time!",
	"Hurry up slow pokes!",
	"Give me another shot!",
	"You got lucky!",
	"Ooooh! That was a close one!",
	"Wow, I thought you had me beat!",
]

const _GOLF_TOP: Array[String] = [
	"Let's play minigolf!",
	"Let's play again!",
	"Want to golf?",
]
const _GOLF_COURSES: Array[String] = [
	"Let's play 'Walk In The Par.'",
	"Let's play 'Hole Some Fun.'",
	"Let's play 'The Hole Kit and Caboodle.'",
	"That course is too easy.",
	"That course is too hard.",
	"That course is just right.",
]
const _GOLF_TIPS: Array[String] = [
	"Try standing more to the left.",
	"Try standing more to the right.",
	"Try standing right in the middle.",
	"Try hitting it harder.",
	"Try hitting it softer.",
	"Try aiming more to the left.",
	"Try aiming more to the right.",
	"Try aiming right down the middle.",
]
const _GOLF_COMMENTS: Array[String] = [
	"So close!",
	"What a great shot!",
	"That was a lucky shot.",
	"I'll take a mulligan...",
	"That's a gimme.",
	"Fore!",
	"Shhhh!",
	"Good game!",
]

const _FACTORY_GLOBALS: Array[String] = [
	"Let's split up.",
	"Let's stay together.",
	"Let's battle the Cogs.",
	"Step on the switch.",
	"Go through the door.",
]
const _FACTORY_MEET: Array[String] = [
	"Let's meet in the Front Entrance.",
	"Let's meet in the Lobby.",
	"Let's meet in the hallway outside the Lobby.",
	"Let's meet in the Gear Room.",
	"Let's meet in the Boiler Room.",
	"Let's meet in the Paint Mixer.",
	"Let's meet in the Pipe Room.",
	"Let's meet in the Duct Room.",
	"Let's meet in the Side Entrance.",
	"Let's meet in Stomper Alley.",
	"Let's meet in the Lava Room.",
	"Let's meet in the Oil Room.",
	"Let's meet on the Warehouse Lookout.",
	"Let's meet in the Warehouse.",
	"Let's meet in the Center Silo Control Room.",
	"Let's meet on top of the West Silo.",
	"Let's meet on top of the East Silo.",
]
const _FACTORY_ZONE := {
	3: ["I'm in the Front Entrance.", "Let's meet in the Front Entrance."],
	4: ["I'm in the Lobby.", "Let's meet in the Lobby."],
	5: ["I'm in the hallway outside the Lobby.", "Let's meet in the hallway outside the Lobby."],
	6: ["I'm in the hallway outside the Lobby.", "Let's meet in the hallway outside the Lobby."],
	7: ["I'm in the Gear Room.", "Let's meet in the Gear Room."],
	8: ["I'm in the Boiler Room.", "Let's meet in the Boiler Room."],
	9: ["I'm on the East Catwalk.", "Let's meet on the East Catwalk."],
	10: ["I'm in the Paint Mixer.", "Let's meet in the Paint Mixer."],
	11: ["I'm in the Paint Mixer Storage Room.", "Let's meet in the Paint Mixer Storage Room."],
	12: ["I'm on the West Silo Catwalk.", "Let's meet on the West Silo Catwalk."],
	13: ["I'm in the Pipe Room.", "Let's meet in the Pipe Room."],
	14: ["I'm on the stairs to the Pipe Room.", "Let's meet on the stairs to the Pipe Room."],
	15: ["I'm in the Duct Room.", "Let's meet in the Duct Room."],
	16: ["I'm in the Side Entrance.", "Let's meet in the Side Entrance."],
	17: ["I'm in Stomper Alley.", "Let's meet in Stomper Alley."],
	18: ["I'm outside the Lava Room.", "Let's meet outside the Lava Room."],
	19: ["I'm in the Lava Room.", "Let's meet in the Lava Room."],
	20: ["I'm in the Lava Storage Room.", "Let's meet in the Lava Storage Room."],
	21: ["I'm on the West Catwalk.", "Let's meet on the West Catwalk."],
	22: ["I'm in the Oil Room.", "Let's meet in the Oil Room."],
	23: ["I'm on the Warehouse Lookout.", "Let's meet on the Warehouse Lookout."],
	24: ["I'm in the Warehouse.", "Let's meet in the Warehouse."],
	25: ["I'm outside the Paint Mixer.", "Let's meet outside the Paint Mixer."],
	27: ["I'm outside the Oil Room.", "Let's meet outside the Oil Room."],
	30: ["I'm in the East Silo Control Room.", "Let's meet in the East Silo Control Room."],
	31: ["I'm in the West Silo Control Room.", "Let's meet in the West Silo Control Room."],
	32: ["I'm in the Center Silo Control Room.", "Let's meet in the Center Silo Control Room."],
	33: ["I'm at the East Silo.", "Let's meet at the East Silo."],
	34: ["I'm on the West Silo.", "Let's meet on the West Silo."],
	35: ["I'm on the Center Silo.", "Let's meet on the Center Silo."],
	36: ["I'm on the West Silo.", "Let's meet on the West Silo."],
	37: ["I'm at the East Silo.", "Let's meet at the East Silo."],
	38: ["I'm on the East Silo Catwalk.", "Let's meet on the East Silo Catwalk."],
	40: ["I'm on top of the West Silo.", "Let's meet on top of the West Silo."],
	41: ["I'm on top of the East Silo.", "Let's meet on top of the East Silo."],
	60: ["I'm on the West Silo Elevator.", "Let's meet on the West Silo Elevator."],
	61: ["I'm on the East Silo Elevator.", "Let's meet on the East Silo Elevator."],
}

const _ELECTION_LINES: Array[String] = [
	"The choice is yours!",
	"Who are you voting for?",
	"Think big! Vote Pig!",
	"Vote Goat - and that's all she wrote!",
]


static func menus(chat: Node) -> Array:
	var file := _file(chat)
	var built: Array = []
	if file == "goofy_speedway.tscn":
		built.append(_racing())
	if file == "chip_n_dales_minigolf.tscn" or file == "minigolf_round.tscn":
		built.append(_golf())
	var factory := _factory(chat, file)
	if not factory.is_empty():
		built.append(factory)
	if _HOLIDAYS.running(_ELECTION):
		built.append({"title": "ELECTION", "items": _rows(_ELECTION_LINES)})
	return built


static func place_key(chat: Node) -> String:
	var file := _file(chat)
	var zone := -1
	if file == "sellbot_factory.tscn":
		zone = _stood(chat)
	var election := 1 if _HOLIDAYS.running(_ELECTION) else 0
	return "%s|%d|%d" % [file, zone, election]


static func _file(chat: Node) -> String:
	var tree := chat.get_tree()
	if tree == null or tree.current_scene == null:
		return ""
	return tree.current_scene.scene_file_path.get_file()


static func _stood(chat: Node) -> int:
	var tree := chat.get_tree()
	if tree == null or tree.current_scene == null:
		return -1
	var rooms := tree.current_scene.get_node_or_null("FactoryRooms")
	if rooms != null and rooms.has_method("stood_zone"):
		return int(rooms.call("stood_zone"))
	return -1


static func _racing() -> Dictionary:
	return {
		"title": "RACING",
		"items": [
			_holder("PLACES", _RACING_PLACES),
			_holder("RACES", _RACING_RACES),
			_holder("TRACKS", _RACING_TRACKS),
			_holder("COMPLIMENTS", _RACING_COMPLIMENTS),
			_holder("TAUNTS", _RACING_TAUNTS),
		] + _rows(_RACING_TOP),
	}


static func _golf() -> Dictionary:
	return {
		"title": "GOLF",
		"items": [
			_holder("COURSES", _GOLF_COURSES),
			_holder("TIPS", _GOLF_TIPS),
			_holder("COMMENTS", _GOLF_COMMENTS),
		] + _rows(_GOLF_TOP),
	}


static func _factory(chat: Node, file: String) -> Dictionary:
	var meet := false
	var zone := -1
	if file == "sellbot_factory.tscn":
		meet = true
		zone = _stood(chat)
	elif file != "lawbot_office.tscn" and file != "bossbot_course.tscn":
		return {}
	var items: Array = []
	if meet:
		items.append(_holder("MEET", _FACTORY_MEET))
	items.append_array(_factory_lines(zone))
	return {"title": "FACTORY", "items": items}


static func _factory_lines(zone: int) -> Array:
	var pending: Array = []
	pending.append_array(_FACTORY_GLOBALS)
	if _FACTORY_ZONE.has(zone):
		pending.append_array(_FACTORY_ZONE[zone])
	var texts: Array[String] = []
	var seen := {}
	for text in pending:
		var line := String(text)
		if seen.has(line):
			continue
		seen[line] = true
		texts.append(line)
	return _rows(texts)


static func _holder(title: String, texts: Array) -> Dictionary:
	return {"title": title, "items": _rows(texts)}


static func _rows(texts: Array) -> Array:
	var rows: Array = []
	for text in texts:
		var line := String(text)
		rows.append({"text": line, "say": line})
	return rows
