extends Node

## MintLayout.gotAllRooms. One baked floor: the entrance, the hallways, and the
## final room. Each glb already has the Z-up conversion, so the stored axes are
## the wrapper transform. Products are the mint you rode in on.

const _DATA := "res://assets/cog_hq/mint_data.json"
const _RIDE := preload("res://scenes/cog_hq/mint_elevator.gd")

static var _book: Dictionary = {}

var _pieces: Array[Node3D] = []
var _shown := -1
var _vis_min := 0
var _vis_max := 0


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


# JSON.parse_string keeps whole numbers as floats, and str(0.0) is "0.0".
static func piece_key(value: Variant) -> String:
	if value is float or value is int:
		return str(int(value))
	return str(value)


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
		var info: Variant = rooms.get(piece_key(piece.get("id", "")), {})
		if not (info is Dictionary):
			continue
		var path := String((info as Dictionary).get("file", ""))
		var room := _instance(packed, path)
		if room == null:
			push_error("Mint piece %s %s did not load from %s" % [piece.get("kind", ""), piece_key(piece.get("id", "")), path])
			continue
		room.name = "Mint%s%s" % [piece.get("kind", "room"), piece_key(piece.get("id", 0))]
		add_child(room)
		room.set_meta("piece", _pieces.size())
		_pieces.append(room)
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
	for shell in _pieces:
		shell.set_meta("box", _mesh_box(shell))
	_products(book, floor, packed)
	_blocks(floor)
	var spawn: Array = floor.get("spawn", [0.0, 0.0, 0.0])
	# The entrance sheet sits at this height. Start a step above it so the
	# first physics frame lands on the solid floor instead of inside it.
	set_meta("spawn", _vec(spawn) + Vector3(0.0, 0.2, 0.0))
	set_meta("spawn_h", float(floor.get("spawn_h", 0.0)))
	_collide(self)
	# DistributedMint.camEnterRoom starts on the entrance. Even room numbers
	# show one piece either side, so the first hallway is already up.
	_show(0)


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
		mesh.set_meta("piece", _piece_at(mesh.global_position))


func _blocks(floor: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "MintBlocks"
	add_child(holder)
	for item in floor.get("blockers", []):
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item
		# BattleBlocker.initCollisionGeom sets the sphere tangible 0. It starts
		# the battle. It is not a wall.
		var mark := Node3D.new()
		mark.name = "Block"
		holder.add_child(mark)
		mark.position = _vec(spec.get("pos", [0.0, 0.0, 0.0]))
		mark.set_meta("cell", int(spec.get("room", 0)) * 100 + int(spec.get("cell", 0)))
		mark.set_meta("radius", maxf(float(spec.get("radius", 10.0)), 1.0))


func _collide(node: Node) -> void:
	var node_name := String(node.name)
	if node_name.begins_with("stomp-") or node_name.begins_with("gear-") or node_name.begins_with("barrel-") or node_name.begins_with("crate-") or node_name.begins_with("belt-") or node_name.begins_with("platform-") or node_name.begins_with("goon-"):
		return
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.visible and mesh.mesh != null:
			# The mint floors are single sheets. A trimesh of that sheet has no
			# thickness, and the toon falls through it on the first step.
			if _slab(mesh):
				_thicken(mesh)
			elif not _cutout(mesh):
				mesh.create_trimesh_collision()
				var body := mesh.get_node_or_null(String(mesh.name) + "_col") as StaticBody3D
				if body != null:
					body.collision_layer = 1
					body.collision_mask = 0
					_backs(body)
	for child in node.get_children():
		_collide(child)


## A walk surface whose local Z (up, inside the mint model) is paper thin.
func _slab(mesh: MeshInstance3D) -> bool:
	var label := String(mesh.name).to_lower()
	if label.contains("gear"):
		return false
	var walk := label.contains("floor") or label.begins_with("moltenlava") or label == "platform" or label == "paint"
	if not walk:
		return false
	var bounds := mesh.get_aabb()
	return bounds.size.z < 0.25 and bounds.size.x > 4.0 and bounds.size.y > 4.0


## A box two units thick, with its top on the sheet, so the step cannot tunnel.
func _thicken(mesh: MeshInstance3D) -> void:
	var bounds := mesh.global_transform * mesh.get_aabb()
	var top := bounds.position.y + bounds.size.y
	var body := StaticBody3D.new()
	body.name = String(mesh.name) + "Solid"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(bounds.size.x, 0.2), 2.0, maxf(bounds.size.z, 0.2))
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_position = Vector3(bounds.get_center().x, top - 1.0, bounds.get_center().z)
	body.set_meta("piece", _owner(mesh))
	# The ouch tag sat on the floor collision of the lava room and the paint
	# mixer. Those sheets are moltenlava and paint. The hallway lava is not.
	var label := String(mesh.name).to_lower()
	if label == "moltenlava" or label == "paint":
		body.set_meta("ouch", true)


func _backs(body: StaticBody3D) -> void:
	for child in body.get_children():
		if child is CollisionShape3D:
			var shape := (child as CollisionShape3D).shape
			if shape is ConcavePolygonShape3D:
				(shape as ConcavePolygonShape3D).backface_collision = true


func _cutout(mesh: MeshInstance3D) -> bool:
	var material := mesh.get_active_material(0)
	if material is BaseMaterial3D:
		return (material as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	return false


func _physics_process(_delta: float) -> void:
	_watch()
	_trip()


## DistributedMint.camEnterRoom. Odd pieces (halls) show two rooms either
## side. Even pieces show the hall on each side.
func shows_room(room_index: int) -> bool:
	var piece := room_index * 2
	return piece >= _vis_min and piece <= _vis_max


func shows_at(point: Vector3) -> bool:
	if _pieces.is_empty():
		return true
	for shell in _pieces:
		var index := int(shell.get_meta("piece", 0))
		if index < _vis_min or index > _vis_max:
			continue
		var box: AABB = shell.get_meta("box", AABB())
		if box.grow(2.0).has_point(point):
			return true
	return false


func _watch() -> void:
	if _pieces.is_empty():
		return
	var toon := _player()
	if toon == null:
		return
	var here := toon.global_position
	var best := _shown
	var best_dist := INF
	var inside := false
	for shell in _pieces:
		var plan := int(shell.get_meta("piece", 0))
		var box: AABB = shell.get_meta("box", AABB())
		if not box.grow(1.5).has_point(here):
			continue
		inside = true
		var dist := box.get_center().distance_squared_to(here)
		if dist < best_dist:
			best_dist = dist
			best = plan
	if not inside:
		best = 0
		best_dist = INF
		for shell in _pieces:
			var plan := int(shell.get_meta("piece", 0))
			var box: AABB = shell.get_meta("box", AABB())
			var dist := box.get_center().distance_squared_to(here)
			if dist < best_dist:
				best_dist = dist
				best = plan
	if best != _shown:
		_show(best)


func _show(room_num: int) -> void:
	_shown = room_num
	var min_vis := room_num - 1
	var max_vis := room_num + 1
	if room_num % 2 == 1:
		min_vis = room_num - 2
		max_vis = room_num + 2
	_vis_min = min_vis
	_vis_max = max_vis
	for child in get_children():
		if not child.has_meta("piece") or String(child.name) == "MintBlocks":
			continue
		var index := int(child.get_meta("piece", -1))
		var show := index >= min_vis and index <= max_vis
		if child is Node3D:
			(child as Node3D).visible = show
		_arm(child, show)


func _trip() -> void:
	var holder := get_node_or_null("MintBlocks")
	var body := _player()
	if holder == null or body == null:
		return
	var fight := get_parent().get_node_or_null("StreetFight")
	if fight == null or not fight.has_method("touch_cell"):
		return
	var feet := body.global_position
	var chest := feet + Vector3(0.0, 2.0, 0.0)
	for block in holder.get_children():
		if not (block is Node3D):
			continue
		var mark := block as Node3D
		var radius := float(mark.get_meta("radius", 0.0))
		var center := mark.global_position
		if chest.distance_to(center) > radius and feet.distance_to(center) > radius:
			continue
		fight.call("touch_cell", int(mark.get_meta("cell", -1)))
		return


func _arm(node: Node, enabled: bool) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 1 if enabled else 0
	for child in node.get_children():
		_arm(child, enabled)


func _piece_at(point: Vector3) -> int:
	var best := 0
	var best_dist := INF
	var inside := false
	for shell in _pieces:
		var plan := int(shell.get_meta("piece", 0))
		var box: AABB = shell.get_meta("box", AABB())
		if not box.grow(1.5).has_point(point):
			continue
		inside = true
		var dist := box.get_center().distance_squared_to(point)
		if dist < best_dist:
			best_dist = dist
			best = plan
	if inside:
		return best
	best_dist = INF
	for shell in _pieces:
		var plan := int(shell.get_meta("piece", 0))
		var box: AABB = shell.get_meta("box", AABB())
		var dist := box.get_center().distance_squared_to(point)
		if dist < best_dist:
			best_dist = dist
			best = plan
	return best


func _owner(node: Node) -> int:
	var current := node
	while current != null and current != self:
		if current.has_meta("piece"):
			return int(current.get_meta("piece"))
		current = current.get_parent()
	return 0


func _player() -> Node3D:
	var host := get_parent()
	if host == null:
		return null
	var body := host.get_node_or_null("Player")
	if body is Node3D:
		return body as Node3D
	return null


func _mesh_box(root: Node) -> AABB:
	var found: Array = [AABB(), false]
	_merge_box(root, found)
	if not bool(found[1]):
		var origin := Vector3.ZERO
		if root is Node3D:
			origin = (root as Node3D).global_position
		return AABB(origin, Vector3.ONE)
	return found[0]


func _merge_box(node: Node, found: Array) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null and mesh.visible:
			var global_box := mesh.global_transform * mesh.mesh.get_aabb()
			if not bool(found[1]):
				found[0] = global_box
				found[1] = true
			else:
				found[0] = (found[0] as AABB).merge(global_box)
	for child in node.get_children():
		_merge_box(child, found)


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
