class_name CogRules
extends RefCounted

## Developer overlays for street spawn chances, cog attack tables, and the
## natural invasion pool. The shipped JSON is left as it was.

const _SPAWN_FILE := "user://dev_spawns.json"
const _ATTACK_FILE := "user://dev_attacks.json"
const _INVASION_FILE := "user://dev_invasions.json"
const _ATTACKS := "res://assets/cogs/attack_tables.json"
const SUITS: Array[Dictionary] = [
	{"name": "Normal", "skeleton": false, "laser": false, "revives": false, "waiter": false, "rarity": 16},
	{"name": "Skelecog", "skeleton": true, "laser": false, "revives": false, "waiter": false, "rarity": 8},
	{"name": "Laser Skelecog", "skeleton": true, "laser": true, "revives": false, "waiter": false, "rarity": 1},
	{"name": "v2.0", "skeleton": false, "laser": false, "revives": true, "waiter": false, "rarity": 4},
	{"name": "Waiter", "skeleton": false, "laser": false, "revives": false, "waiter": true, "rarity": 2},
	{"name": "v2.0 Waiter", "skeleton": false, "laser": false, "revives": true, "waiter": true, "rarity": 1},
]

static var _ready := false
static var _generation := 0
static var _shared_key := ""
static var _spawns: Dictionary = {}
static var _attacks: Dictionary = {}
static var _invasion: Dictionary = {}
static var _shipped: Dictionary = {}


static func generation() -> int:
	_ensure()
	return _generation


static func spawn_for(zone: int) -> Dictionary:
	_ensure()
	var raw: Variant = _spawns.get(str(zone), {})
	if raw is Dictionary:
		return (raw as Dictionary).duplicate(true)
	return {}


static func store_spawn(zone: int, record: Dictionary) -> void:
	_ensure()
	_spawns[str(zone)] = record.duplicate(true)
	_generation += 1
	_write(_SPAWN_FILE, _spawns)


static func attack_for(code: String) -> Dictionary:
	_ensure()
	var raw: Variant = _attacks.get(code, {})
	if raw is Dictionary and not (raw as Dictionary).is_empty():
		return (raw as Dictionary).duplicate(true)
	return {}


static func attack_table(code: String) -> Dictionary:
	var edited := attack_for(code)
	if not edited.is_empty():
		return edited
	var shipped := _shipped_attack(code)
	if shipped is Dictionary:
		return (shipped as Dictionary).duplicate(true)
	return {}


static func store_attack(code: String, table: Dictionary) -> void:
	_ensure()
	_attacks[code] = table.duplicate(true)
	_generation += 1
	_write(_ATTACK_FILE, _attacks)


static func invasion() -> Dictionary:
	_ensure()
	if _invasion.is_empty():
		return {}
	return _invasion.duplicate(true)


static func invasion_form() -> Dictionary:
	var stored := invasion()
	if stored.has("suits"):
		return stored
	return {"dept_base": 1, "cog_base": 8, "suits": SUITS.duplicate(true)}


static func store_invasion(record: Dictionary) -> void:
	_ensure()
	_invasion = record.duplicate(true)
	_generation += 1
	_write(_INVASION_FILE, _invasion)


static func bundle() -> Dictionary:
	_ensure()
	return {
		"spawns": _spawns.duplicate(true),
		"attacks": _attacks.duplicate(true),
		"invasion": _invasion.duplicate(true),
		"generation": _generation,
	}


static func note_shared(snap: Dictionary) -> void:
	_ensure()
	if snap.is_empty():
		return
	var incoming := int(snap.get("generation", 0))
	if incoming < _generation:
		return
	var key := JSON.stringify(snap)
	if key == _shared_key:
		return
	_shared_key = key
	if snap.get("spawns") is Dictionary:
		_spawns = (snap["spawns"] as Dictionary).duplicate(true)
	if snap.get("attacks") is Dictionary:
		_attacks = (snap["attacks"] as Dictionary).duplicate(true)
	if snap.get("invasion") is Dictionary:
		_invasion = (snap["invasion"] as Dictionary).duplicate(true)
	_generation = incoming


static func places(streets: Dictionary, hood: Dictionary) -> Array:
	_ensure()
	var rows: Array = []
	for slug in streets.keys():
		var path := String(streets[slug])
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = parsed
		var zone := int(data.get("zone", 0))
		var count := int(data.get("count", 1))
		var span: Vector2i = hood.get(zone, Vector2i(count, count))
		var record := {
			"zone": zone,
			"name": String(slug).replace("_", " "),
			"tracks": data.get("tracks", [25, 25, 25, 25]),
			"levels": data.get("levels", []),
			"min": span.x,
			"max": span.y,
		}
		var edited := spawn_for(zone)
		if edited.has("tracks"):
			record["tracks"] = edited["tracks"]
		if edited.has("levels"):
			record["levels"] = edited["levels"]
		if edited.has("min"):
			record["min"] = int(edited["min"])
		if edited.has("max"):
			record["max"] = int(edited["max"])
		rows.append(record)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("zone", 0)) < int(b.get("zone", 0))
	)
	return rows


static func _shipped_attack(code: String) -> Dictionary:
	if _shipped.is_empty() and FileAccess.file_exists(_ATTACKS):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_ATTACKS))
		if parsed is Dictionary:
			_shipped = parsed
	var raw: Variant = _shipped.get(code, {})
	if raw is Dictionary:
		return raw
	return {}


static func _ensure() -> void:
	if _ready:
		return
	_ready = true
	_spawns = _read(_SPAWN_FILE)
	_attacks = _read(_ATTACK_FILE)
	_invasion = _read(_INVASION_FILE)


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}


static func _write(path: String, record: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(record, "\t"))
