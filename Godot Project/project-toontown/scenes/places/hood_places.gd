extends RefCounted

## DistributedToonAI.setLocation stores lastHood and defaultZone as the hood
## id (the playground or Cog HQ), not the street. Pick a Toon sends the toon
## back there the way ToontownClientRepository.enterPlayingGame does.
## Playgrounds keep DNA coordinates. Cog HQ exteriors add the export shift
## that parked each courtyard on the origin. The drop is HoodMgr.dropPoints
## [0], except Toontown Central, where a trolley task uses
## ToontownCentralInitialDropPoints[0].

const TTC := 2000
const GAG_SHOP := "res://scenes/interiors/gag_shop.tscn"
const TOON_HALL := "res://scenes/interiors/toon_hall.tscn"
const _SHOP := preload("res://scenes/interiors/gag_shop_door.gd")

const _SCENES: Dictionary = {
	1000: "res://scenes/playgrounds/donalds_dock.tscn",
	2000: "res://scenes/playgrounds/toontown_central.tscn",
	3000: "res://scenes/playgrounds/the_burrrgh.tscn",
	4000: "res://scenes/playgrounds/minnies_melodyland.tscn",
	5000: "res://scenes/playgrounds/daisy_gardens.tscn",
	6000: "res://scenes/playgrounds/acorn_acres.tscn",
	8000: "res://scenes/playgrounds/goofy_speedway.tscn",
	9000: "res://scenes/playgrounds/donalds_dreamland.tscn",
	10000: "res://scenes/cog_hq/bossbot_lobby.tscn",
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


static func toon_hall_scene() -> String:
	return TOON_HALL


static func is_toon_hall(path: String) -> bool:
	return path.ends_with("toon_hall.tscn")


static func hood_for_scene(path: String) -> int:
	if is_gag_shop(path):
		return int(_SHOP.hood)
	if is_toon_hall(path):
		return TTC
	if is_house(path) or is_estate(path):
		return ESTATE
	var keys: Array = _SCENES.keys()
	for i in keys.size():
		var key := int(keys[i])
		if String(_SCENES[key]) == path:
			return key
	return 0


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
