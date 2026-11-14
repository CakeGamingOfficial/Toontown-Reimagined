extends RefCounted

## Accepted cattlelog furniture and window views. Furniture stands on the floor
## in the front room. Paintings hang on the east wall. Each window fills the
## next window hole, the way DistributedHouseInterior.__setupWindows does.

const _CLOSET := preload("res://scenes/catalog/catalog_closet.gd")
const _FILE := "res://assets/estate/furniture/house_catalog.json"
const _DIR := "res://assets/estate/furniture/"
const _SLOTS: PackedStringArray = [
	"windowcut_a", "windowcut_b", "windowcut_c", "windowcut_d", "windowcut_e", "windowcut_f",
]
const _PAINTING := 8

static var _loaded := false
static var _book: Dictionary = {}
static var _packed: Dictionary = {}


static func place(host: Node) -> void:
	if host == null or host.get_node_or_null("OrderedFurniture") != null:
		return
	_load()
	var root := Node3D.new()
	root.name = "OrderedFurniture"
	host.add_child(root)
	var floor_index := 0
	var painting_index := 0
	var window_index := 0
	var furniture: Dictionary = _book.get("furniture", {})
	var windows: Dictionary = _book.get("windows", {})
	for token in _CLOSET.catalog_tokens():
		var bits := token.split(":")
		if bits.size() < 2:
			continue
		var item_id := bits[1]
		if bits[0] == "furniture":
			var placed := _put_furniture(root, furniture.get(item_id, {}), floor_index, painting_index)
			floor_index = int(placed.get("floor", floor_index))
			painting_index = int(placed.get("painting", painting_index))
		elif bits[0] == "window" and window_index < _SLOTS.size():
			if _put_window(host, windows.get(item_id, {}), _SLOTS[window_index]):
				window_index += 1


static func _put_furniture(root: Node3D, row: Variant, floor_index: int, painting_index: int) -> Dictionary:
	if not (row is Dictionary) or (row as Dictionary).is_empty():
		return {"floor": floor_index, "painting": painting_index}
	var card: Dictionary = row
	var model := _spawn(String(card.get("model", "")))
	if model == null:
		return {"floor": floor_index, "painting": painting_index}
	model.scale = Vector3.ONE * float(card.get("scale", 1.0))
	root.add_child(model)
	var flags := int(card.get("flags", 0))
	if flags & _PAINTING:
		model.position = Vector3(14.6, 1.7, -6.0 + float(painting_index) * 2.8)
		model.rotation.y = -PI * 0.5
		painting_index += 1
	else:
		var column := floor_index % 4
		var line := int(floor_index / 4.0)
		model.position = Vector3(-12.0 + float(column) * 4.5, 0.02, 1.0 + float(line) * 3.6)
		floor_index += 1
	return {"floor": floor_index, "painting": painting_index}


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
