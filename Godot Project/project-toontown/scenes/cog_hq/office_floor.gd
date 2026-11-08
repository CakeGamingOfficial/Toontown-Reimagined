extends Node

## DistributedStage.gotAllRooms. Rooms and hallways are instanced on the pivots
## baked by tools/export_law_office.py. camEnterRoom stashes everything outside
## the current room's neighbors.

const _RUN := preload("res://scenes/cog_hq/office_run.gd")

var _pieces: Array[Node3D] = []
var _shown := -1


static func place(host: Node) -> void:
	if Engine.is_editor_hint() or host == null:
		return
	if host.scene_file_path.get_file() != "lawbot_office.tscn":
		return
	if host.get_node_or_null("OfficeFloor") != null:
		return
	var script := load("res://scenes/cog_hq/office_floor.gd") as GDScript
	var node := script.new() as Node
	node.name = "OfficeFloor"
	host.add_child(node)


func _ready() -> void:
	var plan: Dictionary = _RUN.floor_plan()
	var rooms: Dictionary = _RUN.book().get("rooms", {})
	var halls: Array = _RUN.book().get("halls", [])
	var host := get_parent() as Node3D
	if host == null:
		return
	var index := 0
	var spawn_id := 0
	for item in plan.get("pieces", []):
		if not (item is Dictionary):
			continue
		var piece: Dictionary = item
		var path := ""
		var room_id := 0
		if str(piece.get("kind", "")) == "hall":
			room_id = -1
			var hall_index := int(piece.get("hall", 0))
			if hall_index >= 0 and hall_index < halls.size():
				path = str(halls[hall_index])
		else:
			room_id = int(piece.get("room", 0))
			var spec: Variant = rooms.get(str(room_id), {})
			if spec is Dictionary:
				path = str((spec as Dictionary).get("file", ""))
				if spawn_id == 0:
					spawn_id = int((spec as Dictionary).get("spawn", 0))
		if path.is_empty() or not FileAccess.file_exists(path):
			index += 1
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			index += 1
			continue
		var pivot := Node3D.new()
		pivot.name = "Piece%d" % index
		pivot.transform = _xform(piece.get("mat", []))
		pivot.set_meta("room", room_id)
		pivot.set_meta("piece", index)
		host.add_child(pivot)
		var model := packed.instantiate()
		pivot.add_child(model)
		pivot.set_meta("box", _mesh_box(pivot))
		_pieces.append(pivot)
		if spawn_id != 0 and host.get_node_or_null("OfficeSpawn") == null:
			var entrance := _find(pivot, "ent-%d" % spawn_id)
			if entrance != null:
				var mark := Marker3D.new()
				mark.name = "OfficeSpawn"
				host.add_child(mark)
				mark.global_transform = entrance.global_transform
		index += 1
	_show(0)
	_collide(_pieces[0] if not _pieces.is_empty() else null)


func _process(_delta: float) -> void:
	var toon := _toon()
	if toon == null or _pieces.is_empty():
		return
	var here := toon.global_position
	var best := _shown
	var best_dist := INF
	var inside := false
	for piece in _pieces:
		var plan := int(piece.get_meta("piece", 0))
		var box: AABB = piece.get_meta("box", AABB())
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
		for piece in _pieces:
			var plan := int(piece.get_meta("piece", 0))
			var box: AABB = piece.get_meta("box", AABB())
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
	for piece in _pieces:
		var index := int(piece.get_meta("piece", 0))
		var show := index >= min_vis and index <= max_vis
		piece.visible = show
		if show:
			_collide(piece)


func _collide(piece: Node3D) -> void:
	if piece == null or bool(piece.get_meta("solid", false)):
		return
	piece.set_meta("solid", true)
	_add_mesh(piece)


func _add_mesh(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var lower := str(mesh.name).to_lower()
		if mesh.mesh != null and mesh.visible and not lower.contains("shadow") and not lower.contains("shad"):
			if mesh.get_node_or_null(String(mesh.name) + "_col") == null:
				mesh.create_trimesh_collision()
	for child in node.get_children():
		_add_mesh(child)


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


static func _xform(raw: Variant) -> Transform3D:
	var values: Array = raw if raw is Array else []
	if values.size() < 12:
		return Transform3D.IDENTITY
	var formed := Transform3D()
	formed.basis.x = Vector3(float(values[0]), float(values[1]), float(values[2]))
	formed.basis.y = Vector3(float(values[3]), float(values[4]), float(values[5]))
	formed.basis.z = Vector3(float(values[6]), float(values[7]), float(values[8]))
	formed.origin = Vector3(float(values[9]), float(values[10]), float(values[11]))
	return formed


func _toon() -> Node3D:
	var host := get_parent()
	if host == null:
		return null
	var body := host.get_node_or_null("Player")
	if body is Node3D:
		return body as Node3D
	return null


static func _find(node: Node, node_name: String) -> Node3D:
	if node == null:
		return null
	if node is Node3D and str(node.name) == node_name:
		return node as Node3D
	for child in node.get_children():
		var found := _find(child, node_name)
		if found != null:
			return found
	return null
