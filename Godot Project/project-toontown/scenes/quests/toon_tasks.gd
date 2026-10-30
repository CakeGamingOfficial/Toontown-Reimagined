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
		"speech": "I need to defeat a Flunky.",
		"next": 110,
	},
	110: {
		"headline": "TROLLEY",
		"caption": "Ride on The Trolley",
		"where": "in The Playground",
		"kind": TROLLEY,
		"cog": "",
		"goal": 1,
		"show_count": false,
		"speech": "I need to ride the trolley.",
		"next": 0,
	},
}

var has_book := false
var met_flippy := false
var in_playground := false
## Hood id from DistributedToonAI.setLocation. 2000 is Toontown Central.
var last_hood := 0
var visited: Array[int] = []

var _slot := -1
var _active: Array[Dictionary] = []
var _done: Array[int] = []


static func for_selected() -> ToonTasks:
	var tasks := ToonTasks.new()
	tasks._slot = ToonRoster.selected_index()
	tasks._load()
	return tasks


## Make a Toon and deleting a slot both start the journal over.
static func reset_slot(index: int) -> void:
	if index < 0 or index >= ToonRoster.SLOT_COUNT:
		return
	var tasks := ToonTasks.new()
	tasks._slot = index
	tasks.save()


## Tom hands over the Laff meter before the first task. After that it stays up.
func has_laff_meter() -> bool:
	return has_book or not _active.is_empty() or not _done.is_empty()


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


## The trolley game is not in yet. When it is, finishing a ride calls this.
## Nothing else marks quest 110 complete.
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


## The corner button stays hidden until Harry has turned in the Flunky task.
## An older visit used to set has_book during Tom's briefing, before that reward.
func book_ready() -> bool:
	return has_book and _done.has(101)


func grant_speedchat() -> void:
	met_flippy = true
	save()


## TutorialStreet.handleEnterTunnel sends stopTutorial, then the toon arrives
## in Toontown Central. Reaching the playground is what finishes the toontorial.
## After that, the journal stays on disk when the game closes.
func note_playground() -> void:
	in_playground = true
	last_hood = 2000
	save()


## setLocation writes the playground or Cog HQ the toon is standing in.
func note_hood(hood: int) -> void:
	if not in_playground:
		return
	var canonical := hood - posmod(hood, 1000)
	if canonical < 1000:
		return
	if canonical == last_hood:
		_remember(canonical)
		return
	last_hood = canonical
	_remember(canonical)
	save()


func has_visited(hood: int) -> bool:
	return visited.has(hood - posmod(hood, 1000))


func _remember(hood: int) -> void:
	var canonical := hood - posmod(hood, 1000)
	if canonical < 1000 or visited.has(canonical):
		return
	visited.append(canonical)


## One task at a time in the toontorial. SpeedChat's MY TASKS reads these lines.
func task_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for entry in _active:
		var quest_id := int(entry["id"])
		if not CATALOG.has(quest_id):
			continue
		var info: Dictionary = CATALOG[quest_id]
		var speech := String(info.get("speech", ""))
		if speech != "" and not lines.has(speech):
			lines.append(speech)
	if _active.is_empty():
		lines.append("I need to get a ToonTask.")
	return lines


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
		"met_flippy": met_flippy,
		"in_playground": in_playground,
		"last_hood": last_hood,
		"visited": visited.duplicate(),
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
	visited = []
	has_book = false
	met_flippy = false
	in_playground = false
	last_hood = 0
	if _slot < 0:
		return
	var root := _read_file()
	var slots: Array = root.get("slots", [])
	if _slot >= slots.size() or typeof(slots[_slot]) != TYPE_DICTIONARY:
		return
	var stored: Dictionary = slots[_slot]
	has_book = bool(stored.get("has_book", false))
	met_flippy = bool(stored.get("met_flippy", false))
	in_playground = bool(stored.get("in_playground", false))
	last_hood = int(stored.get("last_hood", 0))
	if in_playground and last_hood == 0:
		last_hood = 2000
	for quest_id in stored.get("done", []):
		_done.append(int(quest_id))
	for item in stored.get("visited", []):
		_remember(int(item))
	if visited.is_empty() and in_playground:
		_remember(last_hood)
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
