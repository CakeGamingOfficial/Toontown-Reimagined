extends RefCounted

## FishGlobals.getRandomFishVitals plus the catch report in generateFishingReport.
## A new toon uses the twig rod. 93 in 100 catches are fish, 1 is jellybeans,
## and the rest are an old boot.

const _SPECIES := preload("res://scenes/fishing/fish_species.gd")
const COST: Array[int] = [1, 2, 3, 4, 5]
const BEANS: Array[int] = [10, 20, 30, 75, 150]
const MIN_POUNDS: Array[int] = [0, 0, 0, 0, 0]
const MAX_POUNDS: Array[int] = [4, 8, 12, 16, 20]
const NAMES: PackedStringArray = ["Twig", "Bamboo", "Hardwood", "Steel", "Gold"]
const _EXP: Array[float] = [
	1.0 / 4.3,
	1.0 / (4.3 * 0.975),
	1.0 / (4.3 * 0.95),
	1.0 / (4.3 * 0.9),
	1.0 / (4.3 * 0.85),
]
const _HOOD := {
	2000: [2100, 2200, 2300],
	1000: [1100, 1200, 1300],
	3000: [3100, 3200, 3300],
	4000: [4100, 4200, 4300],
	5000: [5100, 5200, 5300],
	9000: [9100, 9200],
}

static var _built := false
static var _ponds: Dictionary = {}


static func cast_cost(rod: int) -> int:
	return COST[clampi(rod, 0, 4)]


static func rod_name(rod: int) -> String:
	return NAMES[clampi(rod, 0, 4)]


static func min_pounds(rod: int) -> int:
	return MIN_POUNDS[clampi(rod, 0, 4)]


static func max_pounds(rod: int) -> int:
	return MAX_POUNDS[clampi(rod, 0, 4)]


## One fish of each genus the pond can produce. The bingo card starts from this list.
static func genera(zone: int) -> Array:
	_ensure()
	var seen := {}
	var rows: Array = []
	var pond: Dictionary = _ponds.get(zone, {})
	for rod_key in pond.keys():
		var rods: Dictionary = pond[rod_key]
		for rarity_key in rods.keys():
			var fish: Array = rods[rarity_key]
			for item in fish:
				var row: Array = item
				var genus := int(row[0])
				if seen.has(genus):
					continue
				seen[genus] = true
				rows.append([genus, int(row[1])])
	return rows


## FishGlobals.getRandomFishVitals, using the card's generator instead of the global one.
static func seeded_fish(zone: int, rod: int, rng: RandomNumberGenerator) -> Array:
	_ensure()
	var which := clampi(rod, 0, 4)
	var pond: Dictionary = _ponds.get(zone, {})
	var rods: Dictionary = pond.get(which, {})
	for _try in 8:
		var rarity := maxi(int(ceili(10.0 * (1.0 - pow(rng.randf(), _EXP[which])))), 1)
		var fish: Array = rods.get(rarity, [])
		if fish.is_empty():
			continue
		var pick: Array = fish[rng.randi() % fish.size()]
		return [int(pick[0]), int(pick[1])]
	return []


static func roll(zone: int, rod: int) -> Dictionary:
	var empty := {"code": 0, "genus": 0, "species": 0, "weight": 0, "beans": 0}
	var which := clampi(rod, 0, 4)
	_ensure()
	var rolled := randf() * 100.0
	if rolled > 94.0:
		return {"code": 4, "genus": 0, "species": 0, "weight": 0, "beans": 0}
	if rolled > 93.0:
		return {"code": 3, "genus": 0, "species": 0, "weight": 0, "beans": BEANS[which]}
	var pond: Dictionary = _ponds.get(zone, {})
	var rods: Dictionary = pond.get(which, {})
	var rarity := _rarity(which)
	var fish: Array = rods.get(rarity, [])
	if fish.is_empty():
		return empty
	var pick: Array = fish[randi() % fish.size()]
	return {
		"code": 2,
		"genus": int(pick[0]),
		"species": int(pick[1]),
		"weight": _weight(int(pick[2]), int(pick[3]), which),
		"beans": 0,
	}


static func _rarity(rod: int) -> int:
	var dice := randf()
	var rarity := int(ceili(10.0 * (1.0 - pow(dice, _EXP[rod]))))
	return maxi(rarity, 1)


static func _weight(min_fish: int, max_fish: int, rod: int) -> int:
	var min_pounds := maxi(min_fish, MIN_POUNDS[rod])
	var max_pounds := mini(max_fish, MAX_POUNDS[rod])
	var unit := (randf() + randf()) * 0.5
	var pounds := float(min_pounds) + float(max_pounds - min_pounds) * unit
	return int(round(pounds * 16.0))


static func _fits(min_fish: int, max_fish: int, rod: int) -> bool:
	return MIN_POUNDS[rod] <= max_fish and MAX_POUNDS[rod] >= min_fish


static func _ensure() -> void:
	if _built:
		return
	_built = true
	var anywhere: Dictionary = {}
	for entry in _SPECIES.FISH:
		var row: Array = entry
		var genus := int(row[0])
		var species := int(row[1])
		var min_fish := int(row[2])
		var max_fish := int(row[3])
		var rarity := int(row[4])
		var zones: Array = row[5]
		for rod in 5:
			if not _fits(min_fish, max_fish, rod):
				continue
			for zone_index in zones.size():
				var zone := int(zones[zone_index])
				var effective := mini(10, rarity + zone_index)
				if zone == 1:
					_add_anywhere(anywhere, rod, effective, genus, species, min_fish, max_fish)
				else:
					_add_hood(zone, rod, effective, genus, species, min_fish, max_fish)
	var pond_zones: Array = _ponds.keys()
	for zone_index in pond_zones.size():
		var zone := int(pond_zones[zone_index])
		for rod in 5:
			var bucket: Dictionary = anywhere.get(rod, {})
			var rarities: Array = bucket.keys()
			for rarity_index in rarities.size():
				var rarity := int(rarities[rarity_index])
				var fish: Array = bucket[rarity]
				for fish_index in fish.size():
					var item: Array = fish[fish_index]
					_add(_ponds, zone, rod, rarity, int(item[0]), int(item[1]), int(item[2]), int(item[3]))


static func _add_hood(zone: int, rod: int, rarity: int, genus: int, species: int, min_fish: int, max_fish: int) -> void:
	var ponds: Array = [zone]
	var subs: Array = _HOOD.get(zone, [])
	for sub_index in subs.size():
		ponds.append(int(subs[sub_index]))
	for pond_index in ponds.size():
		_add(_ponds, int(ponds[pond_index]), rod, rarity, genus, species, min_fish, max_fish)


static func _add_anywhere(root: Dictionary, rod: int, rarity: int, genus: int, species: int, min_fish: int, max_fish: int) -> void:
	if not root.has(rod):
		root[rod] = {}
	var rods: Dictionary = root[rod]
	if not rods.has(rarity):
		rods[rarity] = []
	var fish: Array = rods[rarity]
	fish.append([genus, species, min_fish, max_fish])


## root[zone][rod][rarity] holds the fish that rod can catch there.
static func _add(root: Dictionary, a: int, b: int, rarity: int, genus: int, species: int, min_fish: int, max_fish: int) -> void:
	if not root.has(a):
		root[a] = {}
	var first: Dictionary = root[a]
	if not first.has(b):
		first[b] = {}
	var second: Dictionary = first[b]
	if not second.has(rarity):
		second[rarity] = []
	var fish: Array = second[rarity]
	fish.append([genus, species, min_fish, max_fish])
