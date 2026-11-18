extends RefCounted

## Accepted cattlelog furniture and window views. Furniture that has been
## dragged into the room stands where house_layout saved it. The rest waits
## in the attic. A window fills a hole only once the attic has seated it,
## the way bringWindowFromAttic fills a slot. The first visit seats every
## window the house already owned so the holes stay filled.

const _CLOSET := preload("res://scenes/catalog/catalog_closet.gd")
const _LAYOUT := preload("res://scenes/interiors/house_layout.gd")
const _FILE := "res://assets/estate/furniture/house_catalog.json"
const _DIR := "res://assets/estate/furniture/"
const _SLOTS: PackedStringArray = [
	"windowcut_a", "windowcut_b", "windowcut_c", "windowcut_d", "windowcut_e", "windowcut_f",
]
const _RUG := 4
const _PAINTING := 8
const _ON_TABLE := 16
const _IS_TABLE := 32
const _BANK := 1
const _CLOSET_FLAG := 2
const _PHONE := 64
const _TRUNK := 256

static var _loaded := false
static var _book: Dictionary = {}
static var _packed: Dictionary = {}


static func place(host: Node) -> void:
	if host == null or host.get_node_or_null("OrderedFurniture") != null:
		return
	settle()
	_load()
	var root := Node3D.new()
	root.name = "OrderedFurniture"
	host.add_child(root)
	var tokens := owned_furniture()
	if not _LAYOUT.known():
		_LAYOUT.seed(_grid(tokens))
	for token in tokens:
		var spot: Dictionary = _LAYOUT.spot(token)
		if spot.is_empty():
			continue
		var model := make(item_id(token))
		if model == null:
			continue
		model.name = token.replace(":", "_")
		model.set_meta("token", token)
		model.position = Vector3(float(spot.get("x", 0.0)), float(spot.get("y", 0.02)), float(spot.get("z", 0.0)))
		model.rotation.y = deg_to_rad(float(spot.get("h", 0.0)))
		model.rotation.z = deg_to_rad(float(spot.get("r", 0.0)))
		root.add_child(model)
	var slots := PackedStringArray()
	if _LAYOUT.has_windows():
		slots = _LAYOUT.windows()
	else:
		for token in owned_of("window"):
			if slots.size() >= _SLOTS.size():
				break
			slots.append(token)
		_LAYOUT.set_windows(slots)
	for index in slots.size():
		if index >= _SLOTS.size() or slots[index].is_empty():
			continue
		fill_window(host, index, slots[index])


static func settle() -> void:
	for token in _LAYOUT.sweep():
		_CLOSET.drop_catalog(token)


static func owned_furniture() -> PackedStringArray:
	return owned_of("furniture")


static func owned_of(kind: String) -> PackedStringArray:
	var tokens := PackedStringArray()
	var prefix := kind + ":"
	for token in _CLOSET.catalog_tokens():
		if token.begins_with(prefix):
			tokens.append(token)
	return tokens


static func item_id(token: String) -> String:
	var bits := token.split(":")
	if bits.size() < 2:
		return ""
	return bits[1]


static func is_painting(id: String) -> bool:
	return int(_card(id).get("flags", 0)) & _PAINTING != 0


static func is_rug(id: String) -> bool:
	return int(_card(id).get("flags", 0)) & _RUG != 0


static func on_table(id: String) -> bool:
	return int(_card(id).get("flags", 0)) & _ON_TABLE != 0


static func is_table(id: String) -> bool:
	return int(_card(id).get("flags", 0)) & _IS_TABLE != 0


static func fixed_line(id: String) -> String:
	var flags := int(_card(id).get("flags", 0))
	if flags & _BANK:
		return "You can't delete your bank!"
	if flags & _CLOSET_FLAG:
		return "You can't delete your wardrobe!"
	if flags & _PHONE:
		return "You can't delete your phone!"
	if flags & _TRUNK:
		return "You can't delete your trunk!"
	return ""


static func fill_window(host: Node, index: int, token: String) -> void:
	if host == null or index < 0 or index >= _SLOTS.size():
		return
	var plug := host.find_child(_SLOTS[index], true, false) as Node3D
	if plug == null:
		return
	for child in plug.get_children():
		child.free()
	if token.is_empty():
		return
	var bits := token.split(":")
	if bits.size() < 2:
		return
	_load()
	_put_window(host, _book.get("windows", {}).get(bits[1], {}), _SLOTS[index])


static func _card(id: String) -> Dictionary:
	_load()
	var card: Variant = _book.get("furniture", {}).get(id, {})
	if card is Dictionary:
		return card
	return {}


static func make(id: String) -> Node3D:
	_load()
	var card: Dictionary = _book.get("furniture", {}).get(id, {})
	if card.is_empty():
		return null
	var model := _spawn(String(card.get("model", "")))
	if model == null:
		return null
	model.scale = Vector3.ONE * float(card.get("scale", 1.0))
	return model


## The grid the house used before a layout existed, so a furnished room
## does not jump into the attic the first time the editor is available.
static func _grid(tokens: PackedStringArray) -> Array:
	var rows: Array = []
	var floor_index := 0
	var painting_index := 0
	for token in tokens:
		var at := Vector3.ZERO
		var heading := 0.0
		if is_painting(item_id(token)):
			at = Vector3(14.6, 1.7, -6.0 + float(painting_index) * 2.8)
			heading = -90.0
			painting_index += 1
		else:
			var column := floor_index % 4
			var line := int(floor_index / 4.0)
			at = Vector3(-12.0 + float(column) * 4.5, 0.02, 1.0 + float(line) * 3.6)
			floor_index += 1
		rows.append({"token": token, "x": at.x, "y": at.y, "z": at.z, "h": heading})
	return rows


static func _put_window(host: Node, row: Variant, slot: String) -> bool:
	if not (row is Dictionary) or (row as Dictionary).is_empty():
		return false
	var plug := host.find_child(slot, true, false) as Node3D
	if plug == null:
		return false
	var model := _spawn(String((row as Dictionary).get("model", "")))
	if model == null:
		return false
	plug.add_child(model)
	# The view was exported standing up. The window hole is still in the
	# house model's own space, so the extra stand-up turn has to come off.
	model.transform = Transform3D.IDENTITY
	if plug is MeshInstance3D:
		(plug as MeshInstance3D).mesh = null
	return true


static func _spawn(file_name: String) -> Node3D:
	if file_name.is_empty():
		return null
	var path := _DIR + file_name
	if not _packed.has(path):
		_packed[path] = load(path) if ResourceLoader.exists(path) else null
	var packed := _packed[path] as PackedScene
	if packed == null:
		return null
	var node := packed.instantiate()
	if node is Node3D:
		return node
	node.free()
	return null


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(_FILE):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_FILE))
	if parsed is Dictionary:
		_book = parsed
