extends RefCounted

## GardenGlobals plus the plot record. Flowers spend one jellybean per bean in
## the recipe. Gag trees are planted on tree plots. A ripe tree sets that
## track's organic level, and checkGagBonus covers every gag at or below it.
## Water falls by one unit every 45 seconds. Below zero, the plant wilts.

const _BEANS := preload("res://scenes/toons/jellybeans.gd")
const _DATA := "res://scenes/estate/garden_data.json"
const _FILE := "user://garden.json"
const _DRAIN := 45.0
const _SHOVEL_SKILL: Array[int] = [80, 160, 320, 640]
const _CAN_SKILL: Array[int] = [100, 200, 400, 1000]
const _SHOVEL_NAME: PackedStringArray = ["Tin Shovel", "Steel Shovel", "Silver Shovel", "Gold Shovel"]
const _CAN_NAME: PackedStringArray = ["Small Watering Can", "Medium Watering Can", "Large Watering Can", "Huge Watering Can"]
const _GAGS: PackedStringArray = ["Toon-Up", "Trap", "Lure", "Sound", "Throw", "Squirt", "Drop"]
const _LEVELS: PackedStringArray = ["1", "2", "3", "4", "5", "6", "7"]

static var _book: Dictionary = {}
static var _rows: Array = []
static var _loaded := false


static func shovel_name() -> String:
	return _SHOVEL_NAME[shovel()]


static func can_name() -> String:
	return _CAN_NAME[can()]


static func shovel() -> int:
	return int(_record().get("shovel", 0))


static func can() -> int:
	return int(_record().get("can", 0))


static func shovel_skill() -> int:
	return int(_record().get("shovel_skill", 0))


static func can_skill() -> int:
	return int(_record().get("can_skill", 0))


static func shovel_power() -> int:
	return _tool_power(shovel(), shovel_skill(), _SHOVEL_SKILL, false)


static func can_power() -> int:
	return _tool_power(can(), can_skill(), _CAN_SKILL, true)


static func organic(track: int, level: int) -> bool:
	var row: Array = _record().get("organic", [])
	if track < 0 or track >= row.size():
		return false
	return int(row[track]) >= level


static func organic_level(track: int) -> int:
	var row: Array = _record().get("organic", [])
	if track < 0 or track >= row.size():
		return -1
	return int(row[track])


static func plots(estate: int) -> Array:
	_tick()
	var record := _record()
	var saved: Array = record.get("plots", [])
	var layout: Array = _layout(estate)
	while saved.size() < layout.size():
		saved.append({})
	record["plots"] = saved
	return saved


static func layout(estate: int) -> Array:
	return _layout(estate)


static func flower_choices() -> Array:
	var rows: Array = []
	var slots := shovel_power()
	var book := _load_book()
	var recipes: Dictionary = book.get("recipes", {})
	var species: Dictionary = book.get("species", {})
	for spec_key in species.keys():
		var spec: Dictionary = species[spec_key]
		var index := 0
		for item in spec.get("varieties", []):
			if not (item is Dictionary):
				index += 1
				continue
			var variety: Dictionary = item
			var recipe: Dictionary = recipes.get(str(int(variety.get("recipe", -1))), {})
			var beans := String(recipe.get("beans", ""))
			if beans.is_empty() or beans.length() > slots:
				index += 1
				continue
			rows.append({
				"species": int(spec_key),
				"variety": index,
				"name": "%s" % String(spec.get("name", "Flower")),
				"beans": beans,
				"value": int(variety.get("value", 1)),
				"color": String(variety.get("color", "")),
			})
			index += 1
	return rows


static func plant_recipe(estate: int, plot: int, beans: String) -> String:
	if beans.is_empty():
		return "Choose the jellybeans you want to plant."
	if beans.length() > shovel_power():
		return "Your shovel cannot plant a recipe that long yet."
	var found := _match_recipe(beans)
	if found.is_empty():
		if not _BEANS.take_beans(beans.length(), true):
			return "You do not have enough jellybeans."
		return "That didn't work.  Please try a different combination of jellybeans."
	return plant_flower(estate, plot, int(found.get("species", 0)), int(found.get("variety", 0)), beans)


static func plant_flower(estate: int, plot: int, species: int, variety: int, beans: String) -> String:
	var spots := plots(estate)
	if plot < 0 or plot >= spots.size():
		return "That plot is not in this garden."
	if not (spots[plot] is Dictionary) or not (spots[plot] as Dictionary).is_empty():
		return "Something is already planted here."
	if beans.length() > shovel_power():
		return "Your shovel cannot plant a recipe that long yet."
	if not _BEANS.take_beans(beans.length(), true):
		return "You do not have enough jellybeans."
	spots[plot] = {
		"kind": 1,
		"species": species,
		"variety": variety,
		"name": _species_name(species),
		"water": 0,
		"growth": 0,
		"stage": 0,
		"at": Time.get_unix_time_from_system(),
		"value": _flower_value(species, variety),
	}
	_gain_shovel(2)
	_save()
	return "You planted a %s." % _species_name(species)


static func plant_tree(estate: int, plot: int, track: int, level: int) -> String:
	var spots := plots(estate)
	if plot < 0 or plot >= spots.size() or int(_layout(estate)[plot].get("kind", 1)) != 0:
		return "Gag trees are planted on tree plots."
	if not (spots[plot] as Dictionary).is_empty():
		return "Something is already planted here."
	if track < 0 or track > 6 or level < 0 or level > 6:
		return "That is not a gag."
	if level + 1 > shovel_power():
		return "Your shovel is not strong enough for that gag tree yet."
	spots[plot] = {
		"kind": 0,
		"track": track,
		"level": level,
		"name": "%s %s Tree" % [_GAGS[track], _LEVELS[level]],
		"water": 0,
		"growth": 0,
		"stage": 0,
		"at": Time.get_unix_time_from_system(),
	}
	_gain_shovel(2)
	_save()
	return "You planted a %s." % String((spots[plot] as Dictionary).get("name", "tree"))


static func place_statue(estate: int, plot: int) -> String:
	var spots := plots(estate)
	if plot < 0 or plot >= spots.size():
		return "That plot is not in this garden."
	if spots[plot] is Dictionary and not (spots[plot] as Dictionary).is_empty():
		return "Something is already planted here."
	if not _BEANS.take_beans(125, true):
		return "You do not have 125 jellybeans."
	spots[plot] = {"kind": 2, "name": "Garden Statue", "stage": 3, "water": 1, "growth": 0, "at": Time.get_unix_time_from_system()}
	_gain_shovel(2)
	_save()
	return "You placed a garden statue."


static func water(estate: int, plot: int) -> String:
	var spots := plots(estate)
	if plot < 0 or plot >= spots.size():
		return "That plot is empty."
	var plant: Dictionary = spots[plot]
	if plant.is_empty() or bool(plant.get("wilted", false)):
		return "There is nothing here to water."
	plant["water"] = int(plant.get("water", 0)) + can_power()
	plant["at"] = Time.get_unix_time_from_system()
	spots[plot] = plant
	_gain_can(1)
	_save()
	return "You watered the %s." % String(plant.get("name", "plant"))


static func harvest(estate: int, plot: int) -> String:
	var spots := plots(estate)
	if plot < 0 or plot >= spots.size():
		return "That plot is empty."
	var plant: Dictionary = spots[plot]
	if plant.is_empty():
		return "Nothing is planted here."
	if bool(plant.get("wilted", false)):
		spots[plot] = {}
		_save()
		return "The plant had wilted, so you cleared the plot."
	if int(plant.get("stage", 0)) < 3 and int(plant.get("kind", 1)) != 2:
		return "It is not ready to pick."
	if int(plant.get("kind", 1)) == 2:
		return "The statue stays in the garden."
	if int(plant.get("kind", 1)) == 0:
		var track := int(plant.get("track", 0))
		var level := int(plant.get("level", 0))
		var organic_row: Array = _record().get("organic", [])
		organic_row[track] = maxi(int(organic_row[track]), level)
		_record()["organic"] = organic_row
		var pockets := ToonLoadout.for_selected()
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.current_scene != null and tree.current_scene.has_method("battle_loadout"):
			var live: Variant = tree.current_scene.call("battle_loadout")
			if live is ToonLoadout:
				pockets = live
		pockets.raise_organic(track, level)
		plant["stage"] = 2
		plant["growth"] = 0
		plant["water"] = 1
		plant["at"] = Time.get_unix_time_from_system()
		spots[plot] = plant
		_gain_shovel(4)
		_save()
		return "Your organic %s is now level %s." % [_GAGS[track], _LEVELS[level]]
	var basket: Array = _record().get("basket", [])
	basket.append({"name": plant.get("name", "Flower"), "value": int(plant.get("value", 1)), "species": plant.get("species", 0), "variety": plant.get("variety", 0)})
	_record()["basket"] = basket
	_note_collection(int(plant.get("species", 0)), int(plant.get("variety", 0)))
	spots[plot] = {}
	_gain_shovel(4)
	_save()
	return "You picked a %s." % String(plant.get("name", "flower"))


static func sell_basket() -> int:
	var record := _record()
	var basket: Array = record.get("basket", [])
	var total := 0
	for item in basket:
		if item is Dictionary:
			total += int((item as Dictionary).get("value", 0))
	if total > 0:
		total *= int(preload("res://scenes/shticker/calendar_holidays.gd").bean_scale("garden"))
		_BEANS.add_beans(total)
	record["basket"] = []
	_save()
	return total


static func basket_value() -> int:
	var total := 0
	for item in _record().get("basket", []):
		if item is Dictionary:
			total += int((item as Dictionary).get("value", 0))
	return total


static func collected() -> int:
	return int(_record().get("collected", []).size())


static func variety_total() -> int:
	var count := 0
	for spec in _load_book().get("species", {}).values():
		if spec is Dictionary:
			count += (spec as Dictionary).get("varieties", []).size()
	return count


static func describe(plot: Dictionary) -> String:
	if plot.is_empty():
		return "Empty"
	if bool(plot.get("wilted", false)):
		return "%s wilted" % String(plot.get("name", "Plant"))
	var stage := int(plot.get("stage", 0))
	var word := "seedling"
	if stage == 1:
		word = "growing"
	elif stage == 2:
		word = "established"
	elif stage >= 3:
		word = "ready"
	return "%s (%s, water %d)" % [String(plot.get("name", "Plant")), word, int(plot.get("water", 0))]


static func _tick() -> void:
	var record := _record()
	var spots: Array = record.get("plots", [])
	var now := Time.get_unix_time_from_system()
	var changed := false
	for index in spots.size():
		if not (spots[index] is Dictionary):
			continue
		var plant: Dictionary = spots[index]
		if plant.is_empty() or bool(plant.get("wilted", false)):
			continue
		var steps := int((now - float(plant.get("at", now))) / _DRAIN)
		if steps <= 0:
			continue
		plant["at"] = float(plant.get("at", now)) + float(steps) * _DRAIN
		for _step in steps:
			var water := int(plant.get("water", 0))
			if water > 0:
				plant["water"] = water - 1
				plant["growth"] = int(plant.get("growth", 0)) + 1
				_advance(plant)
			else:
				plant["water"] = water - 1
				var floor := -2 if int(plant.get("kind", 1)) == 1 else -1
				if int(plant["water"]) < floor:
					plant["wilted"] = true
		spots[index] = plant
		changed = true
	if changed:
		record["plots"] = spots
		_save()


static func _advance(plant: Dictionary) -> void:
	var need := _thresholds(plant)
	var growth := int(plant.get("growth", 0))
	var stage := 0
	var covered := 0
	for point in need:
		covered += point
		if growth >= covered:
			stage += 1
	plant["stage"] = mini(stage, 3)


static func _thresholds(plant: Dictionary) -> Array:
	if int(plant.get("kind", 1)) == 0:
		var level := int(plant.get("level", 0))
		return [level + 1, (level + 1) * 2, (level + 1) * 3]
	return [1, 1, 1]


static func _tool_power(tool: int, skill: int, bands: Array[int], doubled: bool) -> int:
	var boxes := 0
	for index in tool + 1:
		var band := bands[index]
		var pair := 2
		if index == tool:
			var per := maxi(int(band / pair), 1)
			var progress := mini(skill, band - 1)
			boxes += 1 + int(progress / per)
		else:
			boxes += pair
	return boxes * (2 if doubled else 1)


static func _gain_shovel(amount: int) -> void:
	var record := _record()
	var skill := int(record.get("shovel_skill", 0)) + amount
	var tool := int(record.get("shovel", 0))
	while tool < 3 and skill >= _SHOVEL_SKILL[tool]:
		skill -= _SHOVEL_SKILL[tool]
		tool += 1
	record["shovel"] = tool
	record["shovel_skill"] = skill


static func _gain_can(amount: int) -> void:
	var record := _record()
	var skill := int(record.get("can_skill", 0)) + amount
	var tool := int(record.get("can", 0))
	while tool < 3 and skill >= _CAN_SKILL[tool]:
		skill -= _CAN_SKILL[tool]
		tool += 1
	record["can"] = tool
	record["can_skill"] = skill


static func _note_collection(species: int, variety: int) -> void:
	var key := "%d:%d" % [species, variety]
	var owned: Array = _record().get("collected", [])
	if not owned.has(key):
		owned.append(key)
		_record()["collected"] = owned
		if owned.size() % 10 == 0:
			var loadout := ToonLoadout.for_selected()
			if loadout != null and loadout.max_hp < 137:
				var maximum := loadout.max_hp + 1
				loadout.set_hp(maximum, maximum)
				loadout.save()


static func _match_recipe(beans: String) -> Dictionary:
	var book := _load_book()
	var recipes: Dictionary = book.get("recipes", {})
	var species: Dictionary = book.get("species", {})
	for spec_key in species.keys():
		var spec: Dictionary = species[spec_key]
		var index := 0
		for item in spec.get("varieties", []):
			if item is Dictionary:
				var recipe: Dictionary = recipes.get(str(int((item as Dictionary).get("recipe", -1))), {})
				if String(recipe.get("beans", "")) == beans:
					return {"species": int(spec_key), "variety": index}
			index += 1
	return {}


static func flower_color(species: int, variety: int) -> String:
	var spec: Dictionary = _load_book().get("species", {}).get(str(species), {})
	var rows: Array = spec.get("varieties", [])
	if variety >= 0 and variety < rows.size() and rows[variety] is Dictionary:
		return String((rows[variety] as Dictionary).get("color", "red"))
	return "red"


static func _species_name(species: int) -> String:
	var spec: Dictionary = _load_book().get("species", {}).get(str(species), {})
	return String(spec.get("name", "Flower"))


static func _flower_value(species: int, variety: int) -> int:
	var spec: Dictionary = _load_book().get("species", {}).get(str(species), {})
	var rows: Array = spec.get("varieties", [])
	if variety >= 0 and variety < rows.size() and rows[variety] is Dictionary:
		return int((rows[variety] as Dictionary).get("value", 1))
	return 1


static func _layout(estate: int) -> Array:
	var plots: Array = _load_book().get("plots", [])
	var index := clampi(estate, 0, maxi(plots.size() - 1, 0))
	if index < plots.size() and plots[index] is Array:
		return plots[index]
	return []


static func _record() -> Dictionary:
	_ensure()
	var slot := ToonRoster.selected_index()
	if slot < 0:
		slot = 0
	while _rows.size() <= slot:
		_rows.append({})
	if not (_rows[slot] is Dictionary) or (_rows[slot] as Dictionary).is_empty():
		_rows[slot] = {
			"shovel": 0, "shovel_skill": 0, "can": 0, "can_skill": 0,
			"organic": [-1, -1, -1, -1, -1, -1, -1],
			"plots": [], "basket": [], "collected": [],
		}
	return _rows[slot]


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_rows = []
	if not FileAccess.file_exists(_FILE):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_FILE))
	if parsed is Dictionary:
		var saved: Array = (parsed as Dictionary).get("slots", [])
		_rows = saved


static func _save() -> void:
	var file := FileAccess.open(_FILE, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"slots": _rows}))


static func _load_book() -> Dictionary:
	if not _book.is_empty():
		return _book
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_DATA))
	if parsed is Dictionary:
		_book = parsed
	return _book
