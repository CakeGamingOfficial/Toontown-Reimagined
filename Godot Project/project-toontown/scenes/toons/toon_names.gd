class_name ToonNames
extends RefCounted

## NameMasterEnglish categories: 0 boy title, 1 girl title, 2 neutral title,
## 3 boy first, 4 girl first, 5 neutral first, 6 cap prefix, 7 last prefix,
## 8 last suffix.

static var _ready := false
static var _lists: Array[PackedStringArray] = []


static func ensure() -> void:
	if _ready:
		return
	_ready = true
	for _index in 9:
		_lists.append(PackedStringArray())
	var text := FileAccess.get_file_as_string("res://assets/toons/NameMasterEnglish.txt")
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var first := line.find("*")
		var second := line.find("*", first + 1)
		if first < 0 or second < 0:
			continue
		var category := int(line.substr(first + 1, second - first - 1))
		if category < 0 or category >= _lists.size():
			continue
		_lists[category].append(line.substr(second + 1))


static func titles(gender: String) -> PackedStringArray:
	ensure()
	var names := PackedStringArray()
	if gender == "f":
		names.append_array(_lists[1])
	else:
		names.append_array(_lists[0])
	names.append_array(_lists[2])
	return names


static func firsts(gender: String) -> PackedStringArray:
	ensure()
	var names := PackedStringArray()
	if gender == "f":
		names.append_array(_lists[4])
	else:
		names.append_array(_lists[3])
	names.append_array(_lists[5])
	return names


static func prefixes() -> PackedStringArray:
	ensure()
	var names := PackedStringArray()
	names.append_array(_lists[6])
	names.append_array(_lists[7])
	return names


static func suffixes() -> PackedStringArray:
	ensure()
	return _lists[8]


static func last_name(prefix: String, suffix: String) -> String:
	return prefix + suffix


static func join_name(title: String, first: String, last: String) -> String:
	var parts: PackedStringArray = []
	for part in [title, first, last]:
		var cleaned := String(part).strip_edges()
		if not cleaned.is_empty():
			parts.append(cleaned)
	return " ".join(parts)
