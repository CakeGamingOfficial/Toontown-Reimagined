extends RefCounted

## DistributedToonAI.setLocation stores lastHood and defaultZone as the hood
## id (the playground or Cog HQ), not the street. Pick a Toon sends the toon
## back there the way ToontownClientRepository.enterPlayingGame does.
## Playgrounds keep DNA coordinates. Cog HQ exteriors add the export shift
## that parked each courtyard on the origin. drop_for is HoodMgr.dropPoints
## [0], except Toontown Central, where a trolley task uses
## ToontownCentralInitialDropPoints[0]. A teleport uses random_drop, the
## same list HoodMgr.getPlaygroundCenterFromId chooses from.

const TTC := 2000
const GAG_SHOP := "res://scenes/interiors/gag_shop.tscn"
const PET_SHOP := "res://scenes/interiors/pet_shop.tscn"
const TOON_HALL := "res://scenes/interiors/toon_hall.tscn"
const TOON_HQ := "res://scenes/interiors/toon_hq.tscn"
const SHOP := "res://scenes/interiors/shop_interior.tscn"
const _SHOP := preload("res://scenes/interiors/gag_shop_door.gd")
const _PET := preload("res://scenes/interiors/pet_shop_door.gd")
const _HQ := preload("res://scenes/interiors/toon_hq_door.gd")

const _SCENES: Dictionary = {
	1000: "res://scenes/playgrounds/donalds_dock.tscn",
	2000: "res://scenes/playgrounds/toontown_central.tscn",
	3000: "res://scenes/playgrounds/the_burrrgh.tscn",
	4000: "res://scenes/playgrounds/minnies_melodyland.tscn",
	5000: "res://scenes/playgrounds/daisy_gardens.tscn",
	6000: "res://scenes/playgrounds/acorn_acres.tscn",
	8000: "res://scenes/playgrounds/goofy_speedway.tscn",
	9000: "res://scenes/playgrounds/donalds_dreamland.tscn",
	10000: "res://scenes/cog_hq/bossbot_country_club.tscn",
	11000: "res://scenes/cog_hq/sellbot_courtyard.tscn",
	12000: "res://scenes/cog_hq/cashbot_trainyard.tscn",
	13000: "res://scenes/cog_hq/lawbot_courtyard.tscn",
	17000: "res://scenes/playgrounds/chip_n_dales_minigolf.tscn",
}

const ESTATE := 16000


static func hood_of(zone_id: int) -> int:
	return zone_id - posmod(zone_id, 1000)


static func scene_for(hood: int) -> String:
	var key := hood_of(hood)
	if key == ESTATE:
		return estate_scene(ToonRoster.selected_index())
	if _SCENES.has(key):
		return String(_SCENES[key])
	return String(_SCENES[TTC])


static func estate_scene(slot: int) -> String:
	return "res://scenes/playgrounds/estates/toon_estate_%d.tscn" % clampi(slot, 0, 5)


static func house_scene(slot: int) -> String:
	return "res://scenes/interiors/estates/house_interior_%d.tscn" % clampi(slot, 0, 5)


static func is_estate(path: String) -> bool:
	return path.contains("toon_estate")


static func is_house(path: String) -> bool:
	return path.contains("house_interior")


static func gag_shop_scene() -> String:
	return GAG_SHOP


static func is_gag_shop(path: String) -> bool:
	return path.ends_with("gag_shop.tscn")


static func pet_shop_scene() -> String:
	return PET_SHOP


static func is_pet_shop(path: String) -> bool:
	return path.ends_with("pet_shop.tscn")


static func toon_hall_scene() -> String:
	return TOON_HALL


static func is_toon_hall(path: String) -> bool:
	return path.ends_with("toon_hall.tscn")


static func toon_hq_scene() -> String:
	return TOON_HQ


static func is_toon_hq(path: String) -> bool:
	return path.ends_with("toon_hq.tscn")


static func shop_scene() -> String:
	return SHOP


static func is_shop(path: String) -> bool:
	return path.ends_with("shop_interior.tscn")


static func hood_for_scene(path: String) -> int:
	if is_gag_shop(path):
		return int(_SHOP.hood)
	if is_pet_shop(path):
		return int(_PET.hood)
	if is_toon_hall(path):
		return TTC
	if is_toon_hq(path):
		return _HQ.hood()
	if is_shop(path):
		return preload("res://scenes/interiors/shop_door.gd").hood_id()
	if is_house(path) or is_estate(path):
		return ESTATE
	var keys: Array = _SCENES.keys()
	for i in keys.size():
		var key := int(keys[i])
		if String(_SCENES[key]) == path:
			return key
	return 0


static func is_playground(hood: int) -> bool:
	match hood_of(hood):
		1000, 2000, 3000, 4000, 5000, 6000, 8000, 9000, 17000:
			return true
		_:
			return false


## HoodMgr.getDropPoint. Each row is panda (x, y, z, heading).
static func random_drop(hood: int) -> Dictionary:
	var rows := _playground_drops(hood_of(hood))
	if rows.is_empty():
		return {"point": drop_for(hood), "heading": heading_for(hood)}
	var row: Array = rows[randi() % rows.size()]
	return {
		"point": Vector3(float(row[0]), float(row[2]) + 0.35, -float(row[1])),
		"heading": float(row[3]),
	}


static func has_drop(hood: int) -> bool:
	match hood_of(hood):
		1000, 2000, 3000, 4000, 5000, 6000, 8000, 9000, 11000, 12000, 13000, 17000:
			return true
		_:
			return false


## Godot feet position. Panda (x, y, z) becomes (x, z + 0.35, -y).
static func drop_for(hood: int) -> Vector3:
	match hood_of(hood):
		1000:
			return Vector3(-28.0, 6.15, 2.5)
		2000:
			return Vector3(-90.7, 0.35, 60.0)
		3000:
			return Vector3(35.0, 6.55, 32.0)
		4000:
			return Vector3(86.0, -13.15, -44.0)
		5000:
			return Vector3(0.0, 0.35, 0.0)
		6000:
			return Vector3(-165.8, 0.375, -108.0)
		8000:
			return Vector3(-0.7, 0.43, -62.0)
		9000:
			return Vector3(77.0, 0.35, -91.0)
		11000:
			return Vector3(59.0, 0.61, -17.4)
		12000:
			return Vector3(-75.3, -23.089, 333.6)
		13000:
			return Vector3(257.2, -68.05, -319.23)
		17000:
			return Vector3(-49.6, 0.35, -102.0)
		_:
			return Vector3(0.0, 0.35, 0.0)


static func heading_for(hood: int) -> float:
	match hood_of(hood):
		1000:
			return 120.0
		2000:
			return 102.575
		3000:
			return 138.0
		4000:
			return 121.1
		5000:
			return -10.5
		6000:
			return 252.0
		8000:
			return 182.0
		9000:
			return 124.4
		11000:
			return 36.0
		12000:
			return 0.0
		13000:
			return -166.6
		17000:
			return 162.0
		_:
			return 0.0


static func _playground_drops(hood: int) -> Array:
	# HoodMgr.dropPoints. These stand in the open, clear of the trolley,
	# tunnel mouths, doors, and the playground NPCs.
	match hood:
		1000:
			return [[-28.0, -2.5, 5.8, 120.0], [-22.0, 13.0, 5.8, 155.6], [67.0, 47.0, 5.7, 134.7], [62.0, 19.0, 5.7, 97.0], [66.0, -27.0, 5.7, 80.5], [-114.0, -7.0, 5.7, -97.0], [-108.0, 36.0, 5.7, -153.8], [-116.0, -46.0, 5.7, -70.1], [-63.0, -79.0, 5.7, -41.2], [-2.0, -79.0, 5.7, 57.4], [-38.0, -78.0, 5.7, 9.1]]
		2000:
			return [[-60.0, -8.0, 1.3, -90.0], [-66.0, -9.0, 1.3, -274.0], [17.0, -28.0, 4.1, -44.0], [87.7, -22.0, 4.0, 66.0], [-9.6, 61.1, 0.0, 132.0], [-109.0, -2.5, -1.656, -90.0], [-35.4, -81.3, 0.5, -4.0], [-103.0, 72.0, 0.0, -141.0], [93.5, -148.4, 2.5, 43.0], [25.0, 123.4, 2.55, 272.0], [48.0, 39.0, 4.0, 201.0], [-80.0, -61.0, 0.1, -265.0], [-46.875, 43.68, -1.05, 124.0], [34.0, -105.0, 2.55, 45.0], [16.0, -75.0, 2.55, 56.0], [-27.0, -56.0, 0.1, 45.0], [100.0, 27.0, 4.1, 150.0], [-70.0, 4.6, -1.9, 90.0], [-130.7, 50.0, 0.55, -111.0]]
		3000:
			return [[35.0, -32.0, 6.2, 138.0], [26.0, -105.0, 6.2, -339.0], [-29.0, -139.0, 6.2, -385.0], [-79.0, -123.0, 6.2, -369.0], [-114.0, -86.0, 3.0, -54.0], [-136.0, 9.0, 6.2, -125.0], [-75.0, 92.0, 6.2, -187.0], [-7.0, 75.0, 6.2, -187.0], [-106.0, -42.0, 8.6, -111.0], [-116.0, -44.0, 8.3, -20.0]]
		4000:
			return [[86.0, 44.0, -13.5, 121.1], [88.0, -8.0, -13.5, 91.0], [92.0, -76.0, -13.5, 62.5], [53.0, -112.0, 6.5, 65.8], [-69.0, -71.0, 6.5, -67.2], [-75.0, 21.0, 6.5, -100.9], [-21.0, 72.0, 6.5, -129.5], [56.0, 72.0, 6.5, 138.2], [-41.0, 47.0, 6.5, -98.9]]
		5000:
			return [[0.0, 0.0, 0.0, -10.5], [76.0, 35.0, 1.1, -30.2], [97.0, 106.0, 0.0, 51.4], [51.0, 180.0, 10.0, 22.6], [-14.0, 203.0, 10.0, 85.6], [-58.0, 158.0, 10.0, -146.9], [-86.0, 128.0, 0.0, -178.9], [-64.0, 65.0, 0.0, 17.7], [-13.0, 39.0, 0.0, -15.7], [-12.0, 193.0, 0.0, -112.4], [87.0, 128.0, 0.0, 45.4]]
		6000:
			return [[-165.8, 108.0, 0.025, 252.0], [21.0, 130.0, 0.16, 170.0], [93.0, 78.5, 0.23, 112.0], [79.0, -1.6, 0.75, 163.0], [10.0, 33.0, 5.32, 130.379], [-200.0, -42.0, 0.025, 317.543], [-21.0, -65.0, 0.335, -18.0], [23.0, 68.5, 4.51, -22.808]]
		8000:
			return [[-0.7, 62.0, 0.08, 182.0], [-1.0, -30.0, 0.06, 183.0], [-13.0, -120.0, 0.0, 307.0], [16.4, -120.0, 0.0, 65.0], [-0.5, -90.0, 0.0, 182.0], [-30.0, -25.0, -0.373, 326.0], [29.0, -17.0, -0.373, 32.0]]
		9000:
			return [[77.0, 91.0, 0.0, 124.4], [29.0, 92.0, 0.0, -154.5], [-28.0, 49.0, -16.4, -142.0], [21.0, 40.0, -16.0, -65.1], [48.0, 27.0, -15.4, -161.0], [-2.0, -22.0, -15.2, -132.1], [-92.0, -88.0, 0.0, -116.3], [-56.0, -93.0, 0.0, -21.5], [20.0, -88.0, 0.0, -123.4], [76.0, -90.0, 0.0, 11.0]]
		17000:
			return [[-49.6, 102.0, 0.0, 162.0], [-22.8, 36.6, 0.0, 157.5], [40.0, 51.0, 0.0, 185.0], [48.3, 122.2, 0.0, 192.0], [106.3, 69.2, 0.0, 133.0], [-81.5, 47.2, 0.0, 183.0], [-80.5, -84.2, 0.0, 284.0], [73.0, -111.0, 0.0, 354.0]]
		_:
			return []
