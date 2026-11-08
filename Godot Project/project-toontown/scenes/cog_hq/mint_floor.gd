extends Node

## MintLayout.gotAllRooms. One baked floor: the entrance, the hallways, and the
## final room. Each glb already has the Z-up conversion, so the stored axes are
## the wrapper transform. Products are the mint you rode in on.

const _DATA := "res://assets/cog_hq/mint_data.json"
const _RIDE := preload("res://scenes/cog_hq/mint_elevator.gd")

static var _book: Dictionary = {}


static func data() -> Dictionary:
	if not _book.is_empty():
		return _book
	if not FileAccess.file_exists(_DATA):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_DATA))
	if parsed is Dictionary:
		_book = parsed
	return _book


static func layout() -> Dictionary:
	var book := data()
	var floors: Variant = book.get("layouts", {})
	if not (floors is Dictionary):
		return {}
	var mint: Variant = (floors as Dictionary).get(str(_RIDE.mint_id), {})
	if not (mint is Dictionary):
		return {}
	var floor: Variant = (mint as Dictionary).get(str(_RIDE.floor_num), {})
	if floor is Dictionary:
		return floor
	return {}


static func place(host: Node) -> void:
	if Engine.is_editor_hint() or host == null:
		return
	if host.scene_file_path.get_file() != "cashbot_mint.tscn":
		return
	if host.get_node_or_null("MintFloor") != null:
		return
	var script := load("res://scenes/cog_hq/mint_floor.gd") as GDScript
	var node := script.new() as Node
	node.name = "MintFloor"
	host.add_child(node)


func _ready() -> void:
	var host := get_parent()
	if host == null:
		return
	var book := data()
	var floor := layout()
	if floor.is_empty():
		return
	var rooms: Dictionary = book.get("rooms", {})
	var packed: Dictionary = {}
	for item in floor.get("pieces", []):
		if not (item is Dictionary):
			continue
		var piece: Dictionary = item
		var info: Variant = rooms.get(str(piece.get("id", "")), {})
		if not (info is Dictionary):
			continue
		var path := String((info as Dictionary).get("file", ""))
		var room := _instance(packed, path)
		if room == null:
			continue
		room.name = "Mint%s%s" % [piece.get("kind", "room"), piece.get("id", 0)]
		add_child(room)
		_apply(room, piece)
		# The stored frame is the door's transform inside this piece. The glb
		# wrapper already carries the piece, so the frame stays parented to it.
		var frame: Variant = piece.get("frame", {})
		if frame is Dictionary and not (frame as Dictionary).is_empty():
			var door := _instance(packed, String(book.get("frame", "")))
			if door != null:
				door.name = "DoorFrame"
				room.add_child(door)
				_apply(door, frame)
	_products(book, floor, packed)
	_blocks(floor)
	var spawn: Array = floor.get("spawn", [0.0, 0.0, 0.0])
	set_meta("spawn", _vec(spawn))
	set_meta("spawn_h", float(floor.get("spawn_h", 0.0)))
	_collide(self)


func _products(book: Dictionary, floor: Dictionary, packed: Dictionary) -> void:
	var catalog: Dictionary = book.get("products", {})
	var mint_key := str(_RIDE.mint_id)
	for item in floor.get("props", []):
		if not (item is Dictionary):
			continue
		var prop: Dictionary = item
		var kinds: Variant = catalog.get(String(prop.get("kind", "")), {})
		if not (kinds is Dictionary):
			continue
		var mesh := _instance(packed, String((kinds as Dictionary).get(mint_key, "")))
		if mesh == null:
			continue
		mesh.name = String(prop.get("kind", "product"))
		add_child(mesh)
		_apply(mesh, prop)


func _blocks(floor: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "MintBlocks"
	add_child(holder)
	for item in floor.get("blockers", []):
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item
		var body := StaticBody3D.new()
		body.name = "Block"
		var shape := SphereShape3D.new()
		shape.radius = maxf(float(spec.get("radius", 10.0)), 1.0)
		var owner := CollisionShape3D.new()
		owner.shape = shape
		body.add_child(owner)
		holder.add_child(body)
		body.position = _vec(spec.get("pos", [0.0, 0.0, 0.0]))
		body.set_meta("cell", int(spec.get("room", 0)) * 100 + int(spec.get("cell", 0)))


func _collide(node: Node) -> void:
	var node_name := String(node.name)
	if node_name.begins_with("stomp-") or node_name.begins_with("gear-") or node_name.begins_with("barrel-") or node_name.begins_with("crate-") or node_name.begins_with("belt-") or node_name.begins_with("platform-") or node_name.begins_with("goon-"):
		return
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.visible and mesh.mesh != null and not _cutout(mesh):
			mesh.create_trimesh_collision()
	for child in node.get_children():
		_collide(child)


func _cutout(mesh: MeshInstance3D) -> bool:
	var material := mesh.get_active_material(0)
	if material is BaseMaterial3D:
		return (material as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	return false


func _instance(packed: Dictionary, path: String) -> Node3D:
	if path == "":
		return null
	var scene: PackedScene = packed.get(path) as PackedScene
	if scene == null:
		scene = load(path) as PackedScene
		if scene == null:
			return null
		packed[path] = scene
	return scene.instantiate() as Node3D


func _apply(node: Node3D, row: Dictionary) -> void:
	var x := _vec(row.get("x", [1.0, 0.0, 0.0]))
	var y := _vec(row.get("y", [0.0, 1.0, 0.0]))
	var z := _vec(row.get("z", [0.0, 0.0, 1.0]))
	node.transform = Transform3D(Basis(x, y, z), _vec(row.get("o", [0.0, 0.0, 0.0])))


func _vec(value: Variant) -> Vector3:
	if value is Array:
		var row: Array = value
		if row.size() >= 3:
			return Vector3(float(row[0]), float(row[1]), float(row[2]))
	return Vector3.ZERO
