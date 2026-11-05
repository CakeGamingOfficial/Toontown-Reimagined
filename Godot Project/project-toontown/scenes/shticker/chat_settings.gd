class_name ChatSettings
extends RefCounted

## Channel toggles for the Shticker Book Chat tab. SpeedChat++'s gear menu
## is a shortcut to this same list, stored with that toon's chat log.

const _PATH := "user://chat_log.json"
const _Style := preload("res://scenes/chat/speed_chat_style.gd")
const ROWS: Array[Dictionary] = [
	{"id": "player", "label": "Players", "on": true},
	{"id": "cog", "label": "Cogs", "on": true},
	{"id": "whisper", "label": "Whispers", "on": true},
	{"id": "system", "label": "System Alerts/Notifications", "on": true},
	{"id": "npc", "label": "NPCs", "on": true},
	{"id": "group", "label": "Group", "on": true},
	{"id": "guild", "label": "Guild", "on": true},
	{"id": "console", "label": "Console (for developers)", "on": false},
	{"id": "magic", "label": "Magic Words (for staff)", "on": true},
]

static var _key := ""
static var _on := {}
static var _speed_color := 0
static var _plus_color := 0
static var _loaded := false
static var _watchers: Array[Callable] = []


static func rows() -> Array[Dictionary]:
	return ROWS


static func current_key() -> String:
	var index := ToonRoster.selected_index()
	if index < 0:
		return "guest"
	return str(index)


static func bind(key: String) -> void:
	if _loaded and _key == key:
		return
	_key = key
	_loaded = true
	_read()


static func enabled(id: String) -> bool:
	_ensure()
	if _on.has(id):
		return bool(_on[id])
	for row in ROWS:
		if String(row.get("id", "")) == id:
			return bool(row.get("on", true))
	return true


static func set_enabled(id: String, on: bool) -> void:
	_ensure()
	if _on.has(id) and bool(_on[id]) == on:
		return
	_on[id] = on
	_write()
	_notify()


static func channels() -> Dictionary:
	_ensure()
	return _on.duplicate()


static func speed_color() -> int:
	_ensure()
	return _speed_color


static func plus_color() -> int:
	_ensure()
	return _plus_color


static func set_speed_color(index: int) -> void:
	_ensure()
	var next := _Style.clamp_index(index)
	if next == _speed_color:
		return
	_speed_color = next
	_write()
	_notify()


static func set_plus_color(index: int) -> void:
	_ensure()
	var next := _Style.clamp_index(index)
	if next == _plus_color:
		return
	_plus_color = next
	_write()
	_notify()


static func bubble(kind: String) -> Color:
	_ensure()
	if kind == "speed":
		return _Style.frame(_speed_color)
	if kind == "plus":
		return _Style.frame(_plus_color)
	return Color(1, 1, 1, 0.98)


static func watch(callback: Callable) -> void:
	if not callback.is_valid():
		return
	if _watchers.has(callback):
		return
	_watchers.append(callback)


static func _ensure() -> void:
	if _loaded:
		return
	bind(current_key())


static func _read() -> void:
	_on = {}
	_speed_color = 0
	_plus_color = 0
	var saved := {}
	var record: Variant = _logs().get(_key, {})
	if typeof(record) == TYPE_DICTIONARY:
		var page: Dictionary = record
		var channels: Variant = page.get("channels", {})
		if typeof(channels) == TYPE_DICTIONARY:
			saved = channels
		_speed_color = _Style.clamp_index(int(page.get("speed_color", 0)))
		_plus_color = _Style.clamp_index(int(page.get("plus_color", 0)))
	for row in ROWS:
		var id := String(row.get("id", ""))
		_on[id] = bool(saved.get(id, row.get("on", true)))


static func _write() -> void:
	var saved := _logs()
	var record: Dictionary = {}
	var found: Variant = saved.get(_key, {})
	if typeof(found) == TYPE_DICTIONARY:
		record = (found as Dictionary).duplicate(true)
	record["channels"] = _on.duplicate()
	record["speed_color"] = _speed_color
	record["plus_color"] = _plus_color
	saved[_key] = record
	var file := FileAccess.open(_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(saved))


static func _logs() -> Dictionary:
	if not FileAccess.file_exists(_PATH):
		return {}
	var file := FileAccess.open(_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func _notify() -> void:
	var live: Array[Callable] = []
	for callback in _watchers:
		if not callback.is_valid():
			continue
		live.append(callback)
		callback.call()
	_watchers = live
