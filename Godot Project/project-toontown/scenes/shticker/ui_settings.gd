extends RefCounted

## Task tracker visibility and text colors from the Options UI tab.

const _PATH := "user://ui_settings.json"
const _Style := preload("res://scenes/chat/speed_chat_style.gd")
const _TASK_GREEN := Color(0.275, 0.65, 0.31)

static var _tracker := true
static var _discord := true
static var _progress := 0
static var _done := 1
static var _progress_hex := ""
static var _done_hex := ""
static var _loaded := false


static func tracker_on() -> bool:
	_ensure()
	return _tracker


static func set_tracker_on(on: bool) -> void:
	_ensure()
	if _tracker == on:
		return
	_tracker = on
	_write()


static func discord_on() -> bool:
	_ensure()
	return _discord


static func set_discord_on(on: bool) -> void:
	_ensure()
	if _discord == on:
		return
	_discord = on
	_write()


static func color_index(which: String) -> int:
	_ensure()
	return _done if which == "done" else _progress


static func set_color_index(which: String, index: int) -> void:
	_ensure()
	var next := clampi(index, 0, count() - 1)
	var had_custom := has_custom(which)
	_store_hex(which, "")
	if which == "done":
		if next == _done and not had_custom:
			return
		_done = next
	else:
		if next == _progress and not had_custom:
			return
		_progress = next
	_write()


static func has_custom(which: String) -> bool:
	_ensure()
	return _hex_of(which) != ""


static func custom_hex(which: String) -> String:
	_ensure()
	return _hex_of(which)


static func set_custom(which: String, next: Color) -> void:
	_ensure()
	var hex := next.to_html(false)
	if _hex_of(which) == hex:
		return
	_store_hex(which, hex)
	_write()


static func active_color(which: String) -> Color:
	_ensure()
	var hex := _hex_of(which)
	if hex != "":
		return Color.html(hex)
	return color(color_index(which))


static func progress_color() -> Color:
	return active_color("progress")


static func done_color() -> Color:
	return active_color("done")


static func count() -> int:
	return 2 + _Style.count()


static func color_name(index: int) -> String:
	var names := PackedStringArray(["White", "Task Green"])
	names.append_array(_Style.NAMES)
	return names[clampi(index, 0, names.size() - 1)]


static func color(index: int) -> Color:
	var at := clampi(index, 0, count() - 1)
	if at == 0:
		return Color(1, 1, 1)
	if at == 1:
		return _TASK_GREEN
	return _Style.arrow(at - 2)


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_read()


static func _read() -> void:
	_tracker = true
	_discord = true
	_progress = 0
	_done = 1
	_progress_hex = ""
	_done_hex = ""
	if not FileAccess.file_exists(_PATH):
		return
	var file := FileAccess.open(_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var page: Dictionary = parsed
	_tracker = bool(page.get("tracker", true))
	_discord = bool(page.get("discord", true))
	_progress = clampi(int(page.get("progress", 0)), 0, count() - 1)
	_done = clampi(int(page.get("done", 1)), 0, count() - 1)
	_progress_hex = _clean_hex(String(page.get("progress_hex", "")))
	_done_hex = _clean_hex(String(page.get("done_hex", "")))


static func _hex_of(which: String) -> String:
	return _done_hex if which == "done" else _progress_hex


static func _store_hex(which: String, hex: String) -> void:
	if which == "done":
		_done_hex = hex
	else:
		_progress_hex = hex


static func _clean_hex(text: String) -> String:
	var raw := text.strip_edges().trim_prefix("#")
	if raw.length() != 6 or not raw.is_valid_hex_number():
		return ""
	return raw.to_lower()


static func _write() -> void:
	var page := {
		"tracker": _tracker,
		"discord": _discord,
		"progress": _progress,
		"done": _done,
		"progress_hex": _progress_hex,
		"done_hex": _done_hex,
	}
	var file := FileAccess.open(_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(page))
