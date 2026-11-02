extends RefCounted

## The factory road (path_floor) stops short of the courtyard tunnel floor.
## That crack is wide enough to drop a toon. A strip of the road fills it.


static func place(host: Node) -> void:
	if host == null or Engine.is_editor_hint():
		return
	if host.scene_file_path.get_file() != "sellbot_factory_exterior.tscn":
		return
	var road := _find(host, "path_floor") as MeshInstance3D
	var tunnel := _find(host, "tunnel_floor_1") as MeshInstance3D
	if road == null or tunnel == null or road.mesh == null:
		return
	var edge := _far_edge(road)
	if edge.is_empty():
		return
	var tunnel_z := _min_z(tunnel)
	var road_z := float(edge["z"])
	if tunnel_z - road_z < 0.05:
		return
	var lip := _lip(tunnel, tunnel_z)
	_lay(road, edge, tunnel_z, lip)


static func _lay(road: MeshInstance3D, edge: Dictionary, tunnel_z: float, lip: Vector2) -> void:
	var left: Vector3 = edge["left"]
	var right: Vector3 = edge["right"]
	var y := left.y + 0.015
	var z0 := float(edge["z"]) - 0.2
	var z1 := tunnel_z + 0.45
	var x0 := clampf(lip.x, left.x, right.x)
	var x1 := clampf(lip.y, left.x, right.x)
	var corners: PackedVector3Array = [
		Vector3(x0, y, z0),
		Vector3(x1, y, z0),
		Vector3(x1, y, z1),
		Vector3(x0, y, z1),
	]
	var span := z1 - z0
	var rate: Vector2 = edge["rate"]
	var uv0 := _along(edge, x0)
	var uv1 := _along(edge, x1)
	var uvs := PackedVector2Array([
		uv0,
		uv1,
		uv1 + rate * span,
		uv0 + rate * span,
	])
	var parent := road.get_parent()
	if parent == null:
		return
	var inv := (parent as Node3D).global_transform.affine_inverse()
	var local := PackedVector3Array()
	var normals := PackedVector3Array()
	for corner in corners:
		local.append(inv * corner)
		normals.append(Vector3.UP)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([local[0], local[1], local[2], local[0], local[2], local[3]])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([normals[0], normals[1], normals[2], normals[0], normals[2], normals[3]])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([uvs[0], uvs[1], uvs[2], uvs[0], uvs[2], uvs[3]])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var join := MeshInstance3D.new()
	join.name = "path_floor_join"
	join.mesh = mesh
	var material := road.get_active_material(0)
	if material != null:
		join.set_surface_override_material(0, material)
	parent.add_child(join)


static func _far_edge(road: MeshInstance3D) -> Dictionary:
	var xf := road.global_transform
	var arrays: Array = road.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	if verts.is_empty():
		return {}
	var max_z := -INF
	var min_z := INF
	for vert in verts:
		var world_z := (xf * vert).z
		max_z = maxf(max_z, world_z)
		min_z = minf(min_z, world_z)
	var left := Vector3(INF, 0.0, 0.0)
	var right := Vector3(-INF, 0.0, 0.0)
	var left_uv := Vector2.ZERO
	var right_uv := Vector2.ZERO
	var near_left_x := INF
	var near_left_uv := Vector2.ZERO
	for i in verts.size():
		var world: Vector3 = xf * verts[i]
		var uv := uvs[i] if i < uvs.size() else Vector2.ZERO
		if world.z >= max_z - 0.05:
			if world.x < left.x:
				left = world
				left_uv = uv
			if world.x > right.x:
				right = world
				right_uv = uv
		elif world.z <= min_z + 0.05 and world.x < near_left_x:
			near_left_x = world.x
			near_left_uv = uv
	var length := maxf(max_z - min_z, 0.001)
	var rate := (left_uv - near_left_uv) / length
	return {
		"left": left,
		"right": right,
		"left_uv": left_uv,
		"right_uv": right_uv,
		"rate": rate,
		"z": max_z,
	}


static func _along(edge: Dictionary, x: float) -> Vector2:
	var left: Vector3 = edge["left"]
	var right: Vector3 = edge["right"]
	var width := maxf(right.x - left.x, 0.001)
	var t := clampf((x - left.x) / width, 0.0, 1.0)
	var left_uv: Vector2 = edge["left_uv"]
	var right_uv: Vector2 = edge["right_uv"]
	return left_uv.lerp(right_uv, t)


## X extent of the tunnel floor's edge that faces the road.
static func _lip(tunnel: MeshInstance3D, tunnel_z: float) -> Vector2:
	var xf := tunnel.global_transform
	var arrays: Array = tunnel.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var x0 := INF
	var x1 := -INF
	for vert in verts:
		var world: Vector3 = xf * vert
		if world.z > tunnel_z + 0.3:
			continue
		x0 = minf(x0, world.x)
		x1 = maxf(x1, world.x)
	return Vector2(x0 - 0.4, x1 + 0.4)


static func _min_z(mesh: MeshInstance3D) -> float:
	var xf := mesh.global_transform
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var min_z := INF
	for vert in verts:
		min_z = minf(min_z, (xf * vert).z)
	return min_z


static func _find(node: Node, wanted: String) -> Node:
	if node == null:
		return null
	if String(node.name) == wanted:
		return node
	for child in node.get_children():
		var found := _find(child, wanted)
		if found != null:
			return found
	return null
