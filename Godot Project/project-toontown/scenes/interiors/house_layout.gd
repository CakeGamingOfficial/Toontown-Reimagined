extends RefCounted

## Where this toon's catalog furniture sits. Anything owned and not placed,
## and not in the trash, is in the attic. houseDesign keeps the same three piles.

const _PATH := "user://house_layout.json"
const _LIFE := 7 * 24 * 60 * 60
const _EXTRA := 5
const _SURFACES: Array[String] = ["wallpaper", "flooring", "moulding", "wainscoting"]

static var _loaded := false
static var _book: Dictionary = {}


static func known() -> bool:
	_ensure()
	return _book.has(_key())


static func seed(rows: Array) -> void:
	_ensure()
	_book[_key()] = {"placed": rows, "trash": []}
	_write()


static func spot(token: String) -> Dictionary:
	for row in _placed():
		if String(row.get("token", "")) == token:
			return row
	return {}


static func remember(token: String, at: Vector3, heading: float, roll: float = 0.0) -> void:
	_ensure()
	var record := _record()
	var placed: Array = record.get("placed", [])
	var kept: Array = []
	var wrote := false
	var row_data := {"token": token, "x": at.x, "y": at.y, "z": at.z, "h": heading, "r": roll}
	for row in placed:
		if String(row.get("token", "")) == token:
			kept.append(row_data)
			wrote = true
		else:
			kept.append(row)
	if not wrote:
		kept.append(row_data)
	record["placed"] = kept
	record["trash"] = _drop_row(_trash_rows(record), token)
	_book[_key()] = record
	_write()


static func forget(token: String) -> void:
	_ensure()
	var record := _record()
	var kept: Array = []
	for row in record.get("placed", []):
		if String(row.get("token", "")) != token:
			kept.append(row)
	record["placed"] = kept
	_release(record, token)
	_book[_key()] = record
	_write()


static func trash(token: String) -> void:
	forget(token)
	var record := _record()
	var rows := _trash_rows(record)
	if not _trash_of(record).has(token):
		rows.append({"token": token, "at": int(Time.get_unix_time_from_system())})
	record["trash"] = rows
	_book[_key()] = record
	_write()


static func restore(token: String) -> void:
	_ensure()
	var record := _record()
	record["trash"] = _drop_row(_trash_rows(record), token)
	_book[_key()] = record
	_write()


## Oldest trash goes first: after a week, or once more than five are waiting.
static func sweep() -> PackedStringArray:
	if not known():
		return PackedStringArray()
	var record := _record()
	var now := int(Time.get_unix_time_from_system())
	var kept: Array = []
	var gone := PackedStringArray()
	for row in _trash_rows(record):
		var token := String(row.get("token", ""))
		if now - int(row.get("at", now)) >= _LIFE:
			gone.append(token)
			_release(record, token)
		else:
			kept.append(row)
	kept.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("at", 0)) < int(b.get("at", 0)))
	while kept.size() > _EXTRA:
		var oldest := String((kept[0] as Dictionary).get("token", ""))
		gone.append(oldest)
		_release(record, oldest)
		kept.pop_front()
	record["trash"] = kept
	_book[_key()] = record
	_write()
	return gone


static func surface(kind: String) -> String:
	return String(_record().get(kind, ""))


static func choose_surface(kind: String, token: String) -> void:
	var record := _record()
	record[kind] = token
	_book[_key()] = record
	_write()


static func has_windows() -> bool:
	return _record().has("windows")


static func windows() -> PackedStringArray:
	var out := PackedStringArray()
	for item in _record().get("windows", []):
		out.append(String(item))
	return out


static func set_windows(tokens: PackedStringArray) -> void:
	var record := _record()
	var rows: Array = []
	for token in tokens:
		rows.append(token)
	record["windows"] = rows
	_book[_key()] = record
	_write()


static func in_trash(owned: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for token in _trash_of(_record()):
		var name := String(token)
		if owned.has(name):
			out.append(name)
	return out


static func in_attic(owned: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	var gone := _trash_of(_record())
	for token in owned:
		if spot(token).is_empty() and not gone.has(token):
			out.append(token)
	return out


static func _placed() -> Array:
	return _record().get("placed", [])


static func _record() -> Dictionary:
	_ensure()
	var row: Variant = _book.get(_key(), {})
	if row is Dictionary:
		return (row as Dictionary).duplicate(true)
	return {"placed": [], "trash": []}


static func _trash_of(record: Dictionary) -> Array:
	var pile: Array = []
	for row in _trash_rows(record):
		pile.append(String(row.get("token", "")))
	return pile


static func _trash_rows(record: Dictionary) -> Array:
	var now := int(Time.get_unix_time_from_system())
	var rows: Array = []
	for item in record.get("trash", []):
		if item is String and not String(item).is_empty():
			rows.append({"token": String(item), "at": now})
		elif item is Dictionary and not String(item.get("token", "")).is_empty():
			rows.append({
				"token": String(item.get("token", "")),
				"at": int(item.get("at", now)),
			})
	return rows


static func _drop_row(rows: Array, token: String) -> Array:
	var kept: Array = []
	for row in rows:
		if row is Dictionary and String(row.get("token", "")) != token:
			kept.append(row)
	return kept


static func _release(record: Dictionary, token: String) -> void:
	if record.has("windows"):
		var slots: Array = []
		for item in record.get("windows", []):
			slots.append("" if String(item) == token else String(item))
		record["windows"] = slots
	var kind := token.split(":")[0]
	if kind in _SURFACES and String(record.get(kind, "")) == token:
		record.erase(kind)


static func _key() -> String:
	return str(ToonRoster.avatar_id())


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_PATH))
	if parsed is Dictionary:
		_book = parsed


static func _write() -> void:
	var file := FileAccess.open(_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_book))
