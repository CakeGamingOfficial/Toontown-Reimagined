extends SceneTree

func _initialize() -> void:
	var world := (load("res://scenes/interiors/toontorial.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var door0 := _find(world, "door_0")
	var door1 := _find(world, "door_1")
	var origin0 := _find(world, "door_origin_0")
	var origin1 := _find(world, "door_origin_1")
	print("rel door0 to origin0 ", origin0.global_transform.affine_inverse() * door0.global_transform)
	print("rel door1 to origin1 ", origin1.global_transform.affine_inverse() * door1.global_transform)
	_bounds(door0)
	_bounds(door1)
	print("--- door0 children ---")
	_kids(door0, 0)
	print("--- door1 children ---")
	_kids(door1, 0)
	quit()


func _bounds(node: Node3D) -> void:
	var meshes := _meshes(node)
	if meshes.is_empty():
		print(node.name, " no mesh")
		return
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for mesh in meshes:
		var aabb: AABB = mesh.get_aabb()
		for corner in [Vector3.ZERO, Vector3(aabb.size.x, 0, 0), Vector3(0, aabb.size.y, 0), Vector3(0, 0, aabb.size.z), aabb.size]:
			var point := mesh.to_global(aabb.position + corner)
			low = low.min(point)
			high = high.max(point)
	print(node.name, " bounds ", low, high, " center ", (low + high) * 0.5)


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_meshes(child))
	return found


func _kids(node: Node, depth: int) -> void:
	if depth > 2:
		return
	for child in node.get_children():
		var line := "  ".repeat(depth) + String(child.name)
		if child is Node3D:
			line += " " + str((child as Node3D).position)
		print(line)
		_kids(child, depth + 1)


func _find(node: Node, wanted: String) -> Node3D:
	if node.name == wanted and node is Node3D:
		return node
	for child in node.get_children():
		var found := _find(child, wanted)
		if found:
			return found
	return null
