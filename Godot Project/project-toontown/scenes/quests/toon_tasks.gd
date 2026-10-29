class_name ToonTasks
extends RefCounted

## The ToonTask journal. Quest 101 is Tutorial Tom's Flunky, and finishing it
## leads to quest 110. Later playground tasks are more entries in CATALOG.
## Battle code reports a defeat with note_cog_defeat. Turning a finished task
## in assigns whatever it points at next.

const COG := "cog"
const TROLLEY := "trolley"

const _PATH := "user://toon_tasks.json"

const CATALOG := {
	101: {
		"headline": "WANTED",
		"caption": "A Flunky",
		"where": "Anywhere",
		"kind": COG,
		"cog": "f",
		"goal": 1,
		"show_count": true,
		"next": 110,
	},
	110: {
		"headline": "TROLLEY",
		"caption": "Ride the trolley",
		"where": "Playground",
		"kind": TROLLEY,
		"cog": "",
		"goal": 1,
		"show_count": false,
		"next": 0,
	},
}

var has_book := false

var _slot := -1
var _active: Array[Dictionary] = []
var _done: Array[int] = []


static func for_selected() -> ToonTasks:
	var tasks := ToonTasks.new()
	tasks._slot = ToonRoster.selected_index()
	tasks._load()
	return tasks


func assign(quest_id: int) -> void:
	if not CATALOG.has(quest_id) or _is_active(quest_id) or _done.has(quest_id):
		return
	_active.append({"id": quest_id, "progress": 0})
	save()


func note_cog_defeat(cog: String) -> void:
	var code := cog.to_lower()
	for entry in _active:
		var quest_id := int(entry["id"])
		var info: Dictionary = CATALOG[quest_id]
		if String(info["kind"]) != COG:
			continue
		var wanted := String(info["cog"])
		if wanted != code and wanted != "any":
			continue
		entry["progress"] = mini(int(entry["progress"]) + 1, int(info["goal"]))
	save()


func note_trolley() -> void:
	for entry in _active:
		var info: Dictionary = CATALOG[int(entry["id"])]
		if String(info["kind"]) != TROLLEY:
			continue
		entry["progress"] = int(info["goal"])
	save()


func turn_in(quest_id: int) -> void:
	if not is_complete(quest_id):
		return
	var next_id := 0
	if CATALOG.has(quest_id):
		next_id = int(CATALOG[quest_id]["next"])
	_remove(quest_id)
	if not _done.has(quest_id):
		_done.append(quest_id)
	save()
	if next_id != 0:
		assign(next_id)


func is_complete(quest_id: int) -> bool:
	if not CATALOG.has(quest_id):
		return false
	for entry in _active:
		if int(entry["id"]) != quest_id:
			continue
		return int(entry["progress"]) >= int(CATALOG[quest_id]["goal"])
	return false


func entries() -> Array[Dictionary]:
	var shown: Array[Dictionary] = []
	for entry in _active:
		var quest_id := int(entry["id"])
		if not CATALOG.has(quest_id):
			continue
		var info: Dictionary = CATALOG[quest_id]
		var progress := int(entry["progress"])
		var goal := int(info["goal"])
		var card: Dictionary = info.duplicate()
		card["id"] = quest_id
		card["progress"] = progress
		card["goal"] = goal
		card["ready"] = progress >= goal
		shown.append(card)
	return shown


func grant_book() -> void:
	has_book = true
	save()


func save() -> void:
	var root := _read_file()
	var slots: Array = root.get("slots", [])
	while slots.size() < ToonRoster.SLOT_COUNT:
		slots.append(null)
	if _slot < 0 or _slot >= ToonRoster.SLOT_COUNT:
		return
	var active: Array = []
	for entry in _active:
		active.append({"id": int(entry["id"]), "progress": int(entry["progress"])})
	slots[_slot] = {
		"has_book": has_book,
		"active": active,
		"done": _done.duplicate(),
	}
	root["slots"] = slots
	var file := FileAccess.open(_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(root))


func _is_active(quest_id: int) -> bool:
	for entry in _active:
		if int(entry["id"]) == quest_id:
			return true
	return false


func _remove(quest_id: int) -> void:
	var kept: Array[Dictionary] = []
	for entry in _active:
		if int(entry["id"]) != quest_id:
			kept.append(entry)
	_active = kept


func _load() -> void:
	_active = []
	_done = []
	has_book = false
	if _slot < 0:
		return
	var root := _read_file()
	var slots: Array = root.get("slots", [])
	if _slot >= slots.size() or typeof(slots[_slot]) != TYPE_DICTIONARY:
		return
	var stored: Dictionary = slots[_slot]
	has_book = bool(stored.get("has_book", false))
	for quest_id in stored.get("done", []):
		_done.append(int(quest_id))
	for entry in stored.get("active", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var quest_id := int(entry.get("id", 0))
		if not CATALOG.has(quest_id) or _done.has(quest_id):
			continue
		_active.append({
			"id": quest_id,
			"progress": int(entry.get("progress", 0)),
		})


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
