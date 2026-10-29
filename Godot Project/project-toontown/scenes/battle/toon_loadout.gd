class_name ToonLoadout
extends RefCounted

## The gags and laff a toon carries. Tracks follow ToontownBattleGlobals:
## toon-up, trap, lure, sound, throw, squirt, drop. Level 0 of throw is the
## Cupcake and level 0 of squirt is the Squirting Flower.

const TRACK_COUNT := 7
const LEVEL_COUNT := 7
const THROW := 4
const SQUIRT := 5
const START_HP := 15

const TRACK_NAMES: PackedStringArray = [
	"Toon-Up", "Trap", "Lure", "Sound", "Throw", "Squirt", "Drop",
]
const TRACK_COLORS: Array[Color] = [
	Color(211.0 / 255.0, 148.0 / 255.0, 255.0 / 255.0),
	Color(249.0 / 255.0, 255.0 / 255.0, 93.0 / 255.0),
	Color(79.0 / 255.0, 190.0 / 255.0, 76.0 / 255.0),
	Color(93.0 / 255.0, 108.0 / 255.0, 239.0 / 255.0),
	Color(255.0 / 255.0, 145.0 / 255.0, 66.0 / 255.0),
	Color(255.0 / 255.0, 65.0 / 255.0, 199.0 / 255.0),
	Color(67.0 / 255.0, 243.0 / 255.0, 255.0 / 255.0),
]
const GAG_NAMES: Array = [
	["Feather", "Megaphone", "Lipstick", "Bamboo Cane", "Pixie Dust", "Juggling Balls", "High Dive"],
	["Banana Peel", "Rake", "Marbles", "Quicksand", "Trapdoor", "TNT", "Railroad"],
	["$1 Bill", "Small Magnet", "$5 Bill", "Big Magnet", "$10 Bill", "Hypno-goggles", "Presentation"],
	["Bike Horn", "Whistle", "Bugle", "Aoogah", "Elephant Trunk", "Foghorn", "Opera Singer"],
	["Cupcake", "Fruit Pie Slice", "Cream Pie Slice", "Whole Fruit Pie", "Whole Cream Pie", "Birthday Cake", "Wedding Cake"],
	["Squirting Flower", "Glass of Water", "Squirt Gun", "Seltzer Bottle", "Fire Hose", "Storm Cloud", "Geyser"],
	["Flower Pot", "Sandbag", "Anvil", "Big Weight", "Safe", "Grand Piano", "Toontanic"],
]

const _PATH := "user://toon_loadout.json"

var hp := START_HP
var max_hp := START_HP
var _counts: Array = []
var _unlocked: Array = []
var _slot := -1


static func for_selected() -> ToonLoadout:
	var loadout := ToonLoadout.new()
	loadout._slot = ToonRoster.selected_index()
	loadout._blank()
	loadout._load()
	return loadout


func gag_name(track: int, level: int) -> String:
	if track < 0 or track >= GAG_NAMES.size():
		return ""
	var names: Array = GAG_NAMES[track]
	if level < 0 or level >= names.size():
		return ""
	return String(names[level])


func count_of(track: int, level: int) -> int:
	if not _valid(track, level):
		return 0
	return int(_counts[track][level])


func unlocked(track: int, level: int) -> bool:
	if not _valid(track, level):
		return false
	return bool(_unlocked[track][level])


func set_gag(track: int, level: int, amount: int, owned: bool) -> void:
	if not _valid(track, level):
		return
	_unlocked[track][level] = owned
	_counts[track][level] = maxi(amount, 0)


func set_hp(current: int, maximum: int) -> void:
	max_hp = maxi(maximum, 1)
	hp = clampi(current, 0, max_hp)


func save() -> void:
	var root := _read_file()
	var slots: Array = root.get("slots", [])
	while slots.size() < ToonRoster.SLOT_COUNT:
		slots.append(null)
	if _slot < 0 or _slot >= ToonRoster.SLOT_COUNT:
		return
	slots[_slot] = {
		"hp": hp,
		"max_hp": max_hp,
		"counts": _counts,
		"unlocked": _unlocked,
	}
	root["slots"] = slots
	var file := FileAccess.open(_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(root))


func _blank() -> void:
	_counts = []
	_unlocked = []
	for _track in TRACK_COUNT:
		var counts: Array = []
		var owned: Array = []
		counts.resize(LEVEL_COUNT)
		owned.resize(LEVEL_COUNT)
		counts.fill(0)
		owned.fill(false)
		_counts.append(counts)
		_unlocked.append(owned)


func _load() -> void:
	if _slot < 0:
		return
	var root := _read_file()
	var slots: Array = root.get("slots", [])
	if _slot >= slots.size() or typeof(slots[_slot]) != TYPE_DICTIONARY:
		return
	var stored: Dictionary = slots[_slot]
	hp = int(stored.get("hp", START_HP))
	max_hp = int(stored.get("max_hp", START_HP))
	var counts: Array = stored.get("counts", [])
	var owned: Array = stored.get("unlocked", [])
	for track in mini(counts.size(), TRACK_COUNT):
		var row: Array = counts[track]
		var flags: Array = owned[track] if track < owned.size() else []
		for level in mini(row.size(), LEVEL_COUNT):
			_counts[track][level] = int(row[level])
			if level < flags.size():
				_unlocked[track][level] = bool(flags[level])


func _read_file() -> Dictionary:
	if not FileAccess.file_exists(_PATH):
		return {}
	var file := FileAccess.open(_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _valid(track: int, level: int) -> bool:
	return track >= 0 and track < TRACK_COUNT and level >= 0 and level < LEVEL_COUNT
