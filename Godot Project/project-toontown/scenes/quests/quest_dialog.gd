extends RefCounted

## QuestDialogDict, the default greeting pools, and the three HQ movies that
## still play after the toontorial: the Shticker Book (110), the tunnel sign
## (145), and the friends list (150). Pages split on the original \x07.

const _FILE := "res://scenes/quests/ttc_dialog.json"

static var _loaded := false
static var _defaults: Dictionary = {}
static var _quests: Dictionary = {}
static var _scripts: Dictionary = {}


static func assign_pages(quest_id: int, av: String, npc: String, building: String, street: String, where: String, fallback: String) -> PackedStringArray:
	_load()
	var movie: Variant = _scripts.get(str(quest_id), [])
	if movie is Array and not (movie as Array).is_empty():
		var pages := PackedStringArray()
		for line in movie:
			pages.append_array(_pages_of(String(line), av, npc, building, street, where))
		return pages
	var quest := _custom(quest_id, "quest", av, npc, building, street, where)
	if quest.is_empty() and not fallback.is_empty():
		quest = _pages_of(fallback, av, npc, building, street, where)
	quest.append_array(_field(quest_id, "leaving", av, npc, building, street, where))
	return quest


static func busy_pages(quest_id: int, av: String, npc: String, building: String, street: String, where: String) -> PackedStringArray:
	_load()
	if _defaults.is_empty() and not _quests.has(str(quest_id)):
		return PackedStringArray()
	return _join([
		_field(quest_id, "greeting", av, npc, building, street, where),
		_field(quest_id, "incomplete_progress", av, npc, building, street, where),
		_field(quest_id, "leaving", av, npc, building, street, where),
	])


static func complete_pages(quest_id: int, av: String, npc: String, building: String, street: String, where: String, reward: String) -> PackedStringArray:
	_load()
	if _defaults.is_empty() and not _quests.has(str(quest_id)):
		return PackedStringArray()
	var pages := _join([
		_field(quest_id, "greeting", av, npc, building, street, where),
		_field(quest_id, "complete", av, npc, building, street, where),
	])
	if not reward.is_empty():
		pages.append(reward)
	pages.append_array(_field(quest_id, "leaving", av, npc, building, street, where))
	return pages


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(_FILE):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_FILE))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var root: Dictionary = parsed
	var defaults: Variant = root.get("defaults", {})
	var quests: Variant = root.get("quests", {})
	var scripts: Variant = root.get("scripts", {})
	if defaults is Dictionary:
		_defaults = defaults
	if quests is Dictionary:
		_quests = quests
	if scripts is Dictionary:
		_scripts = scripts


static func _custom(quest_id: int, key: String, av: String, npc: String, building: String, street: String, where: String) -> PackedStringArray:
	var row: Dictionary = _quests.get(str(quest_id), {})
	var value: Variant = row.get(key, [])
	if value is Array and not (value as Array).is_empty():
		return _choice(value, av, npc, building, street, where)
	return PackedStringArray()


static func _field(quest_id: int, key: String, av: String, npc: String, building: String, street: String, where: String) -> PackedStringArray:
	var row: Dictionary = _quests.get(str(quest_id), {})
	if row.has(key):
		var value: Variant = row[key]
		if value is Array:
			return _choice(value, av, npc, building, street, where)
	var pool: Variant = _defaults.get(key, [])
	if pool is Array:
		return _choice(pool, av, npc, building, street, where)
	return PackedStringArray()


static func _choice(options: Array, av: String, npc: String, building: String, street: String, where: String) -> PackedStringArray:
	if options.is_empty():
		return PackedStringArray()
	return _pages_of(String(options[randi() % options.size()]), av, npc, building, street, where)


static func _pages_of(text: String, av: String, npc: String, building: String, street: String, where: String) -> PackedStringArray:
	var filled := text.replace("_avName_", av)
	filled = filled.replace("_toNpcName_", npc)
	filled = filled.replace("_buildingName_", building)
	filled = filled.replace("_streetDesc_", street)
	filled = filled.replace("_where_", where)
	var pages := PackedStringArray()
	for part in filled.split("\u0007", false):
		var page := part.strip_edges()
		if not page.is_empty():
			pages.append(page)
	return pages


static func _join(parts: Array) -> PackedStringArray:
	var pages := PackedStringArray()
	for part in parts:
		if part is PackedStringArray:
			pages.append_array(part)
	return pages
