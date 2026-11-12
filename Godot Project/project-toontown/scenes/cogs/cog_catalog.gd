class_name CogCatalog
extends RefCounted

## The cog list from assets/cogs/catalog.json, with developer edits from
## user://dev_cogs.json laid on top. The catalog file itself is left as shipped.

const _FILE := "res://assets/cogs/catalog.json"
const _EDITS := "user://dev_cogs.json"

static var _ready := false
static var _book: Dictionary = {}
static var _edits: Dictionary = {}
static var _removed: Dictionary = {}
static var _generation := 0
static var _shared := ""


static func generation() -> int:
	_ensure()
	_take_shared()
	return _generation


static func data() -> Dictionary:
	_ensure()
	_take_shared()
	var parsed: Variant = JSON.parse_string(JSON.stringify(_merged()))
	if parsed is Dictionary:
		return parsed
	return {}


static func cog_rows() -> Array:
	var rows: Variant = data().get("cogs", [])
	if rows is Array:
		return rows
	return []


static func store_cog(cog: Dictionary) -> String:
	_ensure()
	_take_shared()
	var code := String(cog.get("code", "")).strip_edges()
	if code.is_empty():
		return "A cog needs a code."
	var dept := String(cog.get("dept", ""))
	if dept != "c" and dept != "l" and dept != "m" and dept != "s":
		return "Department has to be c, l, m, or s."
	var kept: Array = []
	for item in _edits.get("cogs", []):
		if item is Dictionary and String((item as Dictionary).get("code", "")) == code:
			continue
		kept.append(item)
	kept.append(cog.duplicate(true))
	_edits["cogs"] = kept
	_removed.erase(code)
	_generation += 1
	_write()
	return ""


static func remove_cog(code: String) -> void:
	_ensure()
	_take_shared()
	var wanted := code.strip_edges()
	if wanted.is_empty():
		return
	var kept: Array = []
	for item in _edits.get("cogs", []):
		if item is Dictionary and String((item as Dictionary).get("code", "")) == wanted:
			continue
		kept.append(item)
	_edits["cogs"] = kept
	_removed[wanted] = true
	_generation += 1
	_write()


static func _ensure() -> void:
	if _ready:
		return
	_ready = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_FILE))
	if parsed is Dictionary:
		_book = parsed
	if not FileAccess.file_exists(_EDITS):
		return
	var edits: Variant = JSON.parse_string(FileAccess.get_file_as_string(_EDITS))
	if typeof(edits) != TYPE_DICTIONARY:
		return
	_edits = edits
	for item in _edits.get("removed", []):
		_removed[String(item)] = true


static func _merged() -> Dictionary:
	var book := _book.duplicate(true)
	var rows: Array = []
	var seen: Dictionary = {}
	for item in book.get("cogs", []):
		if not (item is Dictionary):
			continue
		var code := String((item as Dictionary).get("code", ""))
		if _removed.has(code):
			continue
		rows.append(item)
		seen[code] = rows.size() - 1
	for item in _edits.get("cogs", []):
		if not (item is Dictionary):
			continue
		var cog: Dictionary = item
		var code := String(cog.get("code", ""))
		if code.is_empty() or _removed.has(code):
			continue
		if seen.has(code):
			rows[int(seen[code])] = cog
		else:
			seen[code] = rows.size()
			rows.append(cog)
	book["cogs"] = rows
	return book


static func _write() -> void:
	var removed: Array = []
	for code in _removed.keys():
		removed.append(String(code))
	_edits["removed"] = removed
	var file := FileAccess.open(_EDITS, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_edits, "\t"))
	ToonNet.share_dev("cogs", {"cogs": _edits.get("cogs", []), "removed": removed})


static func _take_shared() -> void:
	var snap := ToonNet.latest("dev:cogs")
	var key := JSON.stringify(snap)
	if key == _shared:
		return
	_shared = key
	if not snap.has("cogs") and not snap.has("removed"):
		return
	_edits = snap.duplicate(true)
	_removed.clear()
	for item in _edits.get("removed", []):
		_removed[String(item)] = true
	_generation += 1
