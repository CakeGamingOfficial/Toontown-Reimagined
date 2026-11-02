extends RefCounted

## DistributedDoor.hideDoorParts hides the swinging leaves and the frame holes
## when a doorDoubleFlat is the closed door. Those leaves sit on the picture,
## so the two textures flicker. In the lobby that picture is also coplanar
## with the front wall. DecalEffect used to paint it onto the wall.

const _LIFT := 0.12


static func place(host: Node) -> void:
	if host == null or Engine.is_editor_hint():
		return
	var file := host.scene_file_path.get_file()
	if file != "sellbot_courtyard.tscn" and file != "sellbot_lobby.tscn":
		return
	_walk(host, host, file == "sellbot_lobby.tscn")


static func _walk(node: Node, host: Node, lobby: bool) -> void:
	var node_name := String(node.name)
	if node is Node3D and node_name.begins_with("door_") and node_name.trim_prefix("door_").is_valid_int():
		if _find_prefix(node, "doorDoubleFlat") != null:
			if lobby:
				_seat(node as Node3D, host)
			_close(node)
			return
	for child in node.get_children():
		_walk(child, host, lobby)


static func _close(node: Node) -> void:
	for child in node.get_children():
		var child_name := String(child.name)
		if child_name.begins_with("leftDoor") or child_name.begins_with("rightDoor") or child_name.begins_with("doorFrameHole"):
			_hide(child)
		else:
			_close(child)


static func _hide(node: Node) -> void:
	node.visible = false
	for child in node.get_children():
		_hide(child)


## The lobby flat is a hair behind the front wall. Sit it on the room side.
static func _seat(door: Node3D, host: Node) -> void:
	var wall := _find_prefix(host, "frontWall") as MeshInstance3D
	var flat := _find_mesh(door, "doorDoubleFlat")
	var leaf := _find_mesh(door, "leftDoor")
	if leaf == null:
		leaf = _find_mesh(door, "rightDoor")
	if wall == null or flat == null or leaf == null:
		return
	var outward := _thin_axis(flat)
	if outward.length_squared() < 0.01:
		return
	var flat_center := flat.global_transform * flat.get_aabb().get_center()
	var leaf_center := leaf.global_transform * leaf.get_aabb().get_center()
	# The closed leaf hangs on the back of the picture. The room is the other side.
	if outward.dot(leaf_center - flat_center) > 0.0:
		outward = -outward
	var wall_center := wall.global_transform * wall.get_aabb().get_center()
	var behind := _half_along(wall, outward) - (flat_center - wall_center).dot(outward)
	if behind < -0.05 or behind > 0.2:
		return
	var holder := flat.get_parent() as Node3D
	if holder == null:
		return
	holder.global_position += outward * (behind + _LIFT)


static func _thin_axis(mesh: MeshInstance3D) -> Vector3:
	var size := mesh.get_aabb().size
	var axis := Vector3(1.0, 0.0, 0.0)
	if size.y <= size.x and size.y <= size.z:
		axis = Vector3(0.0, 1.0, 0.0)
	elif size.z <= size.x and size.z <= size.y:
		axis = Vector3(0.0, 0.0, 1.0)
	var normal := mesh.global_transform.basis * axis
	if normal.length_squared() < 0.0001:
		return Vector3.ZERO
	return normal.normalized()


static func _half_along(mesh: MeshInstance3D, axis: Vector3) -> float:
	var box := mesh.get_aabb()
	var xf := mesh.global_transform
	var center := xf * box.get_center()
	var half := 0.0
	for x in [box.position.x, box.end.x]:
		for y in [box.position.y, box.end.y]:
			for z in [box.position.z, box.end.z]:
				half = maxf(half, absf(((xf * Vector3(x, y, z)) - center).dot(axis)))
	return half


static func _find_mesh(node: Node, prefix: String) -> MeshInstance3D:
	var found := _find_prefix(node, prefix)
	if found == null:
		return null
	return _first_mesh(found)


static func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _first_mesh(child)
		if found != null:
			return found
	return null


static func _find_prefix(node: Node, prefix: String) -> Node:
	if node == null:
		return null
	if String(node.name) == prefix or String(node.name).begins_with(prefix):
		return node
	for child in node.get_children():
		var found := _find_prefix(child, prefix)
		if found != null:
			return found
	return null
