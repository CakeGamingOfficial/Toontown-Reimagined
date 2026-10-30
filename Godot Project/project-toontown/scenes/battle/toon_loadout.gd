class_name ToonLoadout
extends RefCounted

## The gags and laff a toon carries. Tracks follow ToontownBattleGlobals:
## toon-up, trap, lure, sound, throw, squirt, drop. Level 0 of throw is the
## Cupcake and level 0 of squirt is the Squirting Flower.

const TRACK_COUNT := 7
const LEVEL_COUNT := 7
const TOON_UP := 0
const THROW := 4
const SQUIRT := 5
const START_HP := 15
const NEXT_GAG := 10
const POCKET := 10
const SKILL_CREDIT := 1

# ToontownBattleGlobals AvPropDamage, level by level, and AvPropAccuracy.
const _DAMAGE_MIN: Array = [
	[8, 15, 25, 40, 60, 90, 210],
	[10, 18, 30, 45, 60, 90, 195],
	[0, 0, 0, 0, 0, 0, 0],
	[3, 5, 9, 14, 19, 25, 90],
	[4, 8, 14, 24, 36, 48, 120],
	[3, 6, 10, 18, 27, 36, 105],
	[10, 18, 30, 45, 60, 85, 180],
]
const _DAMAGE_MAX: Array = [
	[10, 18, 30, 45, 70, 120, 210],
	[12, 20, 35, 50, 70, 180, 195],
	[0, 0, 0, 0, 0, 0, 0],
	[4, 7, 11, 16, 21, 50, 90],
	[6, 10, 17, 27, 40, 100, 120],
	[4, 8, 12, 21, 30, 80, 105],
	[10, 18, 30, 45, 60, 170, 180],
]
const _ACCURACY: Array = [
	[70, 70, 70, 70, 70, 70, 100],
	[0, 0, 0, 0, 0, 0, 0],
	[50, 50, 60, 60, 70, 70, 90],
	[95, 95, 95, 95, 95, 95, 95],
	[75, 75, 75, 75, 75, 75, 75],
	[95, 95, 95, 95, 95, 95, 95],
	[50, 50, 50, 50, 50, 50, 50],
]

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

signal hp_changed(current: int, maximum: int)

var hp := START_HP
var max_hp := START_HP
var _counts: Array = []
var _unlocked: Array = []
var _exp: Array[int] = []
var _slot := -1
# The tutorial Flunky fight sets this. It is not written into the save.
var _tutorial_accuracy := false


func grant_tutorial_accuracy() -> void:
	_tutorial_accuracy = true


func clear_tutorial_accuracy() -> void:
	_tutorial_accuracy = false


func rolled_accuracy(track: int, level: int) -> int:
	if _tutorial_accuracy:
		return 100
	return gag_accuracy(track, level)


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


func spend_gag(track: int, level: int) -> bool:
	if count_of(track, level) <= 0:
		return false
	_counts[track][level] = count_of(track, level) - 1
	return true


func refund_gag(track: int, level: int) -> void:
	if not _valid(track, level):
		return
	_unlocked[track][level] = true
	_counts[track][level] = count_of(track, level) + 1


func experience_of(track: int) -> int:
	if track < 0 or track >= _exp.size():
		return 0
	return _exp[track]


func add_experience(track: int, amount: int) -> void:
	if track < 0 or track >= _exp.size():
		return
	_exp[track] += maxi(amount, 0)


func gag_count() -> int:
	var total := 0
	for track in TRACK_COUNT:
		for level in LEVEL_COUNT:
			total += count_of(track, level)
	return total


static func gag_damage(track: int, level: int, exp: int) -> int:
	if track < 0 or track >= _DAMAGE_MIN.size():
		return 0
	var lows: Array = _DAMAGE_MIN[track]
	var highs: Array = _DAMAGE_MAX[track]
	if level < 0 or level >= lows.size():
		return 0
	var low := int(lows[level])
	var high := int(highs[level])
	if level > 0 or high <= low:
		return low
	# getAvPropDamage at the start of a track: 0 experience deals the minimum.
	var per := float(NEXT_GAG + 1) / float(high - low + 1)
	var dealt := int(floor(float(clampi(exp, 0, NEXT_GAG)) / per)) + low
	return clampi(dealt, low, high)


static func gag_accuracy(track: int, level: int) -> int:
	if track < 0 or track >= _ACCURACY.size():
		return 0
	var row: Array = _ACCURACY[track]
	if level < 0 or level >= row.size():
		return 0
	var percent := int(row[level])
	# Trap stores 0 because it does not roll this table.
	if percent <= 0:
		return 100
	return percent


static func accuracy_word(percent: int) -> String:
	if percent >= 95:
		return "High"
	if percent >= 70:
		return "Medium"
	if percent >= 50:
		return "Low"
	return "Very Low"


static func affects_label(track: int) -> String:
	if track == TOON_UP:
		return "One Toon"
	if track == 3 or track == 6:
		return "All Cogs"
	return "One Cog"


func set_hp(current: int, maximum: int) -> void:
	max_hp = maxi(maximum, 1)
	hp = clampi(current, 0, max_hp)
	hp_changed.emit(hp, max_hp)


## DistributedAvatar.takeDamage. The popup is the laff that was actually lost.
func take_damage(amount: int) -> int:
	var before := hp
	set_hp(before - maxi(amount, 0), max_hp)
	return before - hp


## DistributedAvatar.toonUp. The popup is the laff that was actually gained.
func gain_hp(amount: int) -> int:
	var before := hp
	set_hp(before + maxi(amount, 0), max_hp)
	return hp - before


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
		"exp": _exp,
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
	_exp.clear()
	_exp.resize(TRACK_COUNT)
	_exp.fill(0)


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
	var experience: Array = stored.get("exp", [])
	for track in mini(experience.size(), TRACK_COUNT):
		_exp[track] = int(experience[track])


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
