extends RefCounted

## FishTank plus the album FishCollection writes when a fisherman buys the
## bucket. A new toon holds 20 and the twig rod. Value is FishGlobals.getValue,
## with no holiday multiplier. Every tenth new species is a fishing trophy.
## set_rod is what Clarabelle's Cattlelog calls when a pole is delivered.

const MAX := 20
const TOTAL := 70
const PER_TROPHY := 10
const _PATH := "user://fish_tank.json"
const _GENUS: PackedStringArray = [
	"Balloon Fish", "Cat Fish", "Clown Fish", "Frozen Fish", "Star Fish", "Holey Mackerel",
	"Dog Fish", "Amore Eel", "Nurse Shark", "King Crab", "Moon Fish", "Sea Horse",
	"Pool Shark", "Bear Acuda", "Cutthroat Trout", "Piano Tuna", "Peanut Butter & Jellyfish", "Devil Ray",
]
const _SPECIES: Array = [
	["Balloon Fish", "Hot Air Balloon Fish", "Weather Balloon Fish", "Water Balloon Fish", "Red Balloon Fish"],
	["Cat Fish", "Siamese Cat Fish", "Alley Cat Fish", "Tabby Cat Fish", "Tom Cat Fish"],
	["Clown Fish", "Sad Clown Fish", "Party Clown Fish", "Circus Clown Fish"],
	["Frozen Fish"],
	["Star Fish", "Five Star Fish", "Rock Star Fish", "Shining Star Fish", "All Star Fish"],
	["Holey Mackerel"],
	["Dog Fish", "Bull Dog Fish", "Hot Dog Fish", "Dalmatian Dog Fish", "Puppy Dog Fish"],
	["Amore Eel", "Electric Amore Eel"],
	["Nurse Shark", "Clara Nurse Shark", "Florence Nurse Shark"],
	["King Crab", "Alaskan King Crab", "Old King Crab"],
	["Moon Fish", "Full Moon Fish", "Half Moon Fish", "New Moon Fish", "Crescent Moon Fish", "Harvest Moon Fish"],
	["Sea Horse", "Rocking Sea Horse", "Clydesdale Sea Horse", "Arabian Sea Horse"],
	["Pool Shark", "Kiddie Pool Shark", "Swimming Pool Shark", "Olympic Pool Shark"],
	["Brown Bear Acuda", "Black Bear Acuda", "Koala Bear Acuda", "Honey Bear Acuda", "Polar Bear Acuda", "Panda Bear Acuda", "Kodiac Bear Acuda", "Grizzly Bear Acuda"],
	["Cutthroat Trout", "Captain Cutthroat Trout", "Scurvy Cutthroat Trout"],
	["Piano Tuna", "Grand Piano Tuna", "Baby Grand Piano Tuna", "Upright Piano Tuna", "Player Piano Tuna"],
	["Peanut Butter & Jellyfish", "Grape PB&J Fish", "Crunchy PB&J Fish", "Strawberry PB&J Fish", "Concord Grape PB&J Fish"],
	["Devil Ray"],
]
const _RARITY: Array = [
	[1, 4, 5, 3, 2],
	[1, 9, 4, 3, 2],
	[1, 4, 2, 6],
	[1],
	[1, 2, 5, 7, 10],
	[9],
	[1, 6, 5, 4, 2],
	[1, 3],
	[5, 7, 8],
	[3, 7, 8],
	[1, 10, 8, 3, 6, 4],
	[2, 3, 5, 7],
	[3, 5, 6, 7],
	[2, 3, 4, 5, 6, 7, 8, 10],
	[2, 6, 7],
	[5, 10, 9, 6, 7],
	[2, 3, 4, 5, 10],
	[10],
]

static var _loaded := false
static var _tanks: Array = []
static var _albums: Array = []
static var _rods: Array = []


static func count() -> int:
	_ensure()
	var slot := _slot()
	if slot < 0:
		return 0
	return (_tanks[slot] as Array).size()


static func max_count() -> int:
	return MAX


static func value() -> int:
	var total := 0
	for fish in fish():
		total += int(fish.get("value", 0))
	return total


static func collected() -> int:
	_ensure()
	var slot := _slot()
	if slot < 0:
		return 0
	return (_albums[slot] as Dictionary).size()


static func fish() -> Array:
	_ensure()
	var slot := _slot()
	var rows: Array = []
	if slot < 0:
		return rows
	for entry in _tanks[slot] as Array:
		var row: Array = entry
		if row.size() < 3:
			continue
		var genus := int(row[0])
		var species := int(row[1])
		var weight := int(row[2])
		rows.append({
			"genus": genus,
			"species": species,
			"weight": weight,
			"name": species_name(genus, species),
			"value": bean_value(genus, species, weight),
		})
	return rows


static func add_fish(genus: int, species: int, weight: int) -> bool:
	_ensure()
	var slot := _slot()
	if slot < 0 or count() >= MAX:
		return false
	if genus < 0 or genus >= _SPECIES.size() * 2 or genus % 2 != 0:
		return false
	if species_name(genus, species) == "???":
		return false
	(_tanks[slot] as Array).append([genus, species, weight])
	_write()
	return true


## creditFishTank. The bucket's beans are paid, the fish join the album, and
## crossing another ten species earns one trophy.
static func sell() -> Dictionary:
	var beans := value()
	var before := collected()
	_ensure()
	var slot := _slot()
	if slot >= 0:
		var album: Dictionary = _albums[slot]
		for entry in _tanks[slot] as Array:
			var row: Array = entry
			if row.size() < 3:
				continue
			var key := "%d:%d" % [int(row[0]), int(row[1])]
			var weight := int(row[2])
			if not album.has(key) or weight > int(album[key]):
				album[key] = weight
		(_tanks[slot] as Array).clear()
		_write()
	var after := collected()
	var trophies := mini(int(after / PER_TROPHY), 7) - mini(int(before / PER_TROPHY), 7)
	if beans > 0:
		preload("res://scenes/toons/jellybeans.gd").add_beans(beans)
	return {"beans": beans, "trophies": maxi(trophies, 0), "collected": after, "total": TOTAL}


static func has_genus(index: int) -> bool:
	if index < 0 or index >= _GENUS.size():
		return false
	var prefix := "%d:" % (index * 2)
	_ensure()
	var slot := _slot()
	if slot < 0:
		return false
	for key in (_albums[slot] as Dictionary).keys():
		if String(key).begins_with(prefix):
			return true
	return false


static func has_species(genus: int, species: int) -> bool:
	_ensure()
	var slot := _slot()
	if slot < 0:
		return false
	return (_albums[slot] as Dictionary).has("%d:%d" % [genus * 2, species])


static func genus_name(index: int) -> String:
	if index < 0 or index >= _GENUS.size():
		return "???"
	return _GENUS[index]


static func species_name(genus: int, species: int) -> String:
	var index := int(genus / 2)
	if genus < 0 or genus % 2 != 0 or index >= _SPECIES.size():
		return "???"
	var names: Array = _SPECIES[index]
	if species < 0 or species >= names.size():
		return "???"
	return String(names[species])


static func bean_value(genus: int, species: int, weight: int) -> int:
	var index := int(genus / 2)
	if genus < 0 or genus % 2 != 0 or index >= _RARITY.size():
		return 0
	var row: Array = _RARITY[index]
	if species < 0 or species >= row.size():
		return 0
	var rarity := float(row[species])
	var rarity_value := pow(0.2 * rarity, 1.5)
	var weight_value := pow((0.05 / 16.0) * float(weight), 1.1)
	return ceili(15.0 * (rarity_value + weight_value))


static func weight_line(weight: int) -> String:
	var pounds := int(weight / 16.0)
	var ounces := weight % 16
	var large := "%d lb. " % pounds if pounds == 1 else "%d lbs. " % pounds
	var small := "%d oz." % ounces
	return "Weight: " + large + small


static func value_line(beans: int) -> String:
	if beans == 1:
		return "Value: 1 jellybean"
	return "Value: %d jellybeans" % beans


## FishItem, FishItemNewEntry, or FishItemNewRecord. The album is what makes a
## species new. A second one still in the bucket is just another fish.
static func catch_code(genus: int, species: int, weight: int) -> int:
	var best := best_weight(genus, species)
	if best >= 0 and weight > best:
		return 10
	if best >= 0 or _holding(genus, species):
		return 2
	return 9


static func best_weight(genus: int, species: int) -> int:
	_ensure()
	var slot := _slot()
	if slot < 0:
		return -1
	var album: Dictionary = _albums[slot]
	var key := "%d:%d" % [genus, species]
	if not album.has(key):
		return -1
	return int(album[key])


static func _holding(genus: int, species: int) -> bool:
	_ensure()
	var slot := _slot()
	if slot < 0:
		return false
	for entry in _tanks[slot] as Array:
		var row: Array = entry
		if row.size() >= 2 and int(row[0]) == genus and int(row[1]) == species:
			return true
	return false


static func rod() -> int:
	_ensure()
	var slot := _slot()
	if slot < 0:
		return 0
	return int(_rods[slot])


static func set_rod(rod_id: int) -> void:
	_ensure()
	var slot := _slot()
	if slot < 0:
		return
	_rods[slot] = clampi(rod_id, 0, 4)
	_write()


static func reset_slot(index: int) -> void:
	_ensure()
	if index < 0 or index >= ToonRoster.SLOT_COUNT:
		return
	_tanks[index] = []
	_albums[index] = {}
	_rods[index] = 0
	_write()


static func _slot() -> int:
	var index := ToonRoster.selected_index()
	if index < 0 or index >= ToonRoster.SLOT_COUNT:
		return -1
	return index


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_tanks.resize(ToonRoster.SLOT_COUNT)
	_albums.resize(ToonRoster.SLOT_COUNT)
	_rods.resize(ToonRoster.SLOT_COUNT)
	for index in ToonRoster.SLOT_COUNT:
		_tanks[index] = []
		_albums[index] = {}
		_rods[index] = 0
	if not FileAccess.file_exists(_PATH):
		return
	var file := FileAccess.open(_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var stored: Array = (parsed as Dictionary).get("slots", [])
	for index in mini(stored.size(), ToonRoster.SLOT_COUNT):
		var entry: Variant = stored[index]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = entry
		var tank: Array = row.get("tank", [])
		var kept: Array = []
		for fish in tank:
			if fish is Array and (fish as Array).size() >= 3:
				kept.append([int(fish[0]), int(fish[1]), int(fish[2])])
		_tanks[index] = kept
		var album: Dictionary = {}
		var saved: Dictionary = row.get("album", {})
		for key in saved.keys():
			album[String(key)] = int(saved[key])
		_albums[index] = album
		_rods[index] = clampi(int(row.get("rod", 0)), 0, 4)


static func _write() -> void:
	var slots: Array = []
	for index in ToonRoster.SLOT_COUNT:
		slots.append({"tank": _tanks[index], "album": _albums[index], "rod": int(_rods[index])})
	var file := FileAccess.open(_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"slots": slots}))
	file.close()
