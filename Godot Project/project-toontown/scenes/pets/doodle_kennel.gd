extends RefCounted

## One doodle per toon, the way DistributedToon.hasPet is one pet. The record
## is the name chosen in the pet shop and the nine PetDNA fields.

const _PATH := "user://doodle.json"

static var _loaded := false
static var _slots: Array = []


static func has_pet() -> bool:
	return not current().is_empty()


static func current() -> Dictionary:
	_ensure()
	var slot := _slot()
	if slot < 0 or slot >= _slots.size():
		return {}
	var record = _slots[slot]
	if record is Dictionary and (record as Dictionary).has("dna"):
		return record
	return {}


static func save_pet(pet_name: String, dna: Array, zone: int, traits: Array = []) -> void:
	_ensure()
	var slot := _slot()
	if slot < 0:
		return
	_slots[slot] = {
		"name": pet_name,
		"dna": dna,
		"zone": zone,
		"traits": traits,
		"mood": {},
		"tricks": [],
		"mood_at": Time.get_unix_time_from_system(),
	}
	_write()


static func update_life(mood: Dictionary, tricks: Array) -> void:
	_ensure()
	var slot := _slot()
	if slot < 0:
		return
	var record = _slots[slot]
	if not (record is Dictionary) or not (record as Dictionary).has("dna"):
		return
	var kept: Dictionary = record
	kept["mood"] = mood
	kept["tricks"] = tricks
	kept["mood_at"] = Time.get_unix_time_from_system()
	_slots[slot] = kept
	_write()


static func clear() -> void:
	_ensure()
	var slot := _slot()
	if slot < 0:
		return
	_slots[slot] = {}
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
	_slots.resize(ToonRoster.SLOT_COUNT)
	for index in _slots.size():
		_slots[index] = {}
	if not FileAccess.file_exists(_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(_PATH))
	if not (parsed is Dictionary):
		return
	var saved: Array = (parsed as Dictionary).get("slots", [])
	for index in mini(saved.size(), _slots.size()):
		if saved[index] is Dictionary:
			_slots[index] = saved[index]


static func _write() -> void:
	var file := FileAccess.open(_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"slots": _slots}))
