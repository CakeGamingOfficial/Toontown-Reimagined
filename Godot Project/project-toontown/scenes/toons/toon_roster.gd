class_name ToonRoster
extends RefCounted

## Six toon slots, saved on this machine. There is no account server yet,
## so Pick a Toon reads and writes user://toons.json.

const SLOT_COUNT := 6
const _PATH := "user://toons.json"

static var pending_slot := 0
static var _slots: Array = []
static var _selected := -1
static var _loaded := false


static func slots() -> Array:
	_ensure()
	return _slots


static func get_slot(index: int) -> ToonStyle:
	_ensure()
	if index < 0 or index >= SLOT_COUNT:
		return null
	return _slots[index]


static func set_slot(index: int, style: ToonStyle) -> void:
	_ensure()
	if index < 0 or index >= SLOT_COUNT:
		return
	_slots[index] = style
	_save()


static func clear_slot(index: int) -> void:
	_ensure()
	if index < 0 or index >= SLOT_COUNT:
		return
	_slots[index] = null
	if _selected == index:
		_selected = -1
	_save()


static func selected_style() -> ToonStyle:
	_ensure()
	return get_slot(_selected)


static func selected_index() -> int:
	_ensure()
	return _selected


static func select_slot(index: int) -> void:
	_ensure()
	_selected = index
	_save()


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_slots = []
	_slots.resize(SLOT_COUNT)
	if not FileAccess.file_exists(_PATH):
		return
	var file := FileAccess.open(_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_selected = int(parsed.get("selected", -1))
	var stored: Array = parsed.get("slots", [])
	for index in mini(stored.size(), SLOT_COUNT):
		var entry: Variant = stored[index]
		if typeof(entry) == TYPE_DICTIONARY:
			_slots[index] = ToonStyle.from_dict(entry)


static func _save() -> void:
	var stored: Array = []
	for slot in _slots:
		if slot is ToonStyle:
			stored.append((slot as ToonStyle).to_dict())
		else:
			stored.append(null)
	var file := FileAccess.open(_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"selected": _selected, "slots": stored}, "  "))
