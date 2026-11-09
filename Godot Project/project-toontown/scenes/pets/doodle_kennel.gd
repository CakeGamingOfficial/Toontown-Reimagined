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


static func battle_trick(trick_id: int) -> int:
	# attemptBattleTrick, then TrickHeals lerped by aptitude.
	var record := current()
	if record.is_empty() or trick_id < 0 or trick_id > 6:
		return 0
	var tricks: Array = record.get("tricks", [])
	var aptitude := 0.0
	if trick_id < tricks.size():
		aptitude = float(tricks[trick_id])
	var mood: Dictionary = record.get("mood", {})
	var rows: Array = record.get("traits", [])
	var happy: bool = preload("res://scenes/pets/doodle_traits.gd").contented(mood, rows)
	var low := 0.5 if happy else 0.1
	var high := 0.97 if happy else 0.6
	var accuracy := float([1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4][trick_id])
	var cutoff := lerpf(low, high, aptitude) * accuracy
	if randf() >= cutoff:
		return 0
	var heals := [[5, 10], [6, 12], [7, 14], [8, 16], [9, 18], [10, 20], [11, 22]]
	var pair: Array = heals[trick_id]
	var amount := int(round(lerpf(float(pair[0]), float(pair[1]), aptitude)))
	while tricks.size() <= trick_id:
		tricks.append(0.0)
	tricks[trick_id] = minf(aptitude + 0.0005, 1.0)
	update_life(mood, tricks)
	return amount


static func update_life(mood: Dictionary, tricks: Array) -> void:
	_ensure()
	var slot := _slot()
	if slot < 0:
		return
	var kept = _slots[slot]
	if not (kept is Dictionary) or not (kept as Dictionary).has("dna"):
		return
	var record: Dictionary = kept
	record["mood"] = mood
	record["tricks"] = tricks
	record["mood_at"] = Time.get_unix_time_from_system()
	_slots[slot] = record
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
