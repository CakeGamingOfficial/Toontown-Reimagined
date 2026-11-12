class_name ToonRoster
extends RefCounted

## Six toon slots, saved on this machine. There is no account server yet,
## so Pick a Toon reads and writes user://toons.json.

const SLOT_COUNT := 6
const _PATH := "user://toons.json"
const _BEANS := preload("res://scenes/toons/jellybeans.gd")
const _FISH := preload("res://scenes/fishing/fish_tank.gd")

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
	# Drop the previous toon's closet, cog suit, kart, and friends before the new one takes the slot.
	CatalogCloset.reset_slot(index)
	DisguisePage.reset_slot(index)
	KartGarage.reset_slot(index)
	FriendsBook.reset_slot(index)
	if style.av_id <= 0:
		style.av_id = _fresh_id()
	_slots[index] = style
	_save()
	# A new toon must not inherit the journal, gags, or jellybeans of whoever used this slot.
	ToonTasks.reset_slot(index)
	ToonLoadout.reset_slot(index)
	_BEANS.reset_slot(index)
	_FISH.reset_slot(index)


static func clear_slot(index: int) -> void:
	_ensure()
	if index < 0 or index >= SLOT_COUNT:
		return
	CatalogCloset.reset_slot(index)
	DisguisePage.reset_slot(index)
	KartGarage.reset_slot(index)
	FriendsBook.reset_slot(index)
	_slots[index] = null
	if _selected == index:
		_selected = -1
	_save()
	ToonTasks.reset_slot(index)
	ToonLoadout.reset_slot(index)
	_BEANS.reset_slot(index)
	_FISH.reset_slot(index)


static func selected_style() -> ToonStyle:
	_ensure()
	return get_slot(_selected)


static func selected_index() -> int:
	_ensure()
	return _selected


static func avatar_id() -> int:
	_ensure()
	var style := selected_style()
	if style == null:
		return 0
	if style.av_id <= 0:
		style.av_id = _fresh_id()
		_save()
	return style.av_id


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
	var minted := false
	for slot in _slots:
		if slot is ToonStyle and (slot as ToonStyle).av_id <= 0:
			(slot as ToonStyle).av_id = _fresh_id()
			minted = true
	if minted:
		_save()


static func _fresh_id() -> int:
	var used := {}
	for slot in _slots:
		if slot is ToonStyle and (slot as ToonStyle).av_id > 0:
			used[(slot as ToonStyle).av_id] = true
	var av := 0
	while av <= 0 or used.has(av):
		av = randi() % 900000000 + 100000000
	return av


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
