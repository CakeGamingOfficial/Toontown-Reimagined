extends RefCounted

## Swaps the trees and streetlights tagged holiday_prop while Winter or Halloween
## decorations are running. The glbs are the nodes named in the storage DNA.

const _HOLIDAYS := preload("res://scenes/shticker/calendar_holidays.gd")
const _CATALOG := "res://assets/holidays/props.json"

static var _book: Dictionary = {}


static func follow(host: Node3D) -> bool:
	var kind := ""
	if _HOLIDAYS.running(26) or _HOLIDAYS.running(119):
		kind = "halloween"
	elif _HOLIDAYS.running(4) or _HOLIDAYS.running(121):
		kind = "winter"
	if str(host.get_meta("holiday_kind", "")) == kind:
		return false
	host.set_meta("holiday_kind", kind)
	_apply(host, kind)
	return true


static func _apply(host: Node3D, kind: String) -> void:
	_clear(host)
	if kind == "":
		return
	var table: Dictionary = _catalog().get(kind, {})
	var scenes: Dictionary = {}
	var hidden: Array = []
	# Godot numbers a repeated glTF name, so the second tree is prop_tree_large_ur_DNARoot2.
	for node in host.find_children("*_DNARoot*", "Node3D", true, false):
		var raw := str(node.name)
		var mark := raw.find("_DNARoot")
		if mark < 0:
			continue
		var code := raw.substr(0, mark)
		var path := str(table.get(code, ""))
		if path == "":
			continue
		if not scenes.has(path):
			scenes[path] = load(path)
		var packed := scenes[path] as PackedScene
		if packed == null:
			continue
		for child in node.get_children():
			if child.visible:
				child.visible = false
				hidden.append(child)
		var prop := packed.instantiate()
		prop.name = "HolidayProp"
		node.add_child(prop)
	host.set_meta("holiday_hidden", hidden)


static func _clear(host: Node3D) -> void:
	for node in host.get_meta("holiday_hidden", []):
		if is_instance_valid(node):
			(node as Node).visible = true
	host.set_meta("holiday_hidden", [])
	var props: Array = host.find_children("HolidayProp", "Node", true, false)
	for node in props:
		node.free()


static func _catalog() -> Dictionary:
	if not _book.is_empty():
		return _book
	var file := FileAccess.open(_CATALOG, FileAccess.READ)
	if file == null:
		return _book
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_book = parsed
	return _book
