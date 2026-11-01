extends RefCounted

## Toontown Central hedges and the wooden playground fence.
## The shared playground collision skips any material that is not fully opaque,
## so these alpha cards never became solid. A box around wall_1 would fill the
## whole playground, because that one mesh runs the entire boundary.

const HEDGE_THICK := 1.6
const FENCE_THICK := 1.05


static func apply(host: Node) -> void:
	var fence_tex := _fence_texture(host)
	_walk(host, fence_tex)


static func _fence_texture(node: Node) -> Texture2D:
	if node is MeshInstance3D and String(node.name) == "wall_1":
		return _albedo(node as MeshInstance3D)
	for child in node.get_children():
		var found := _fence_texture(child)
		if found != null:
			return found
	return null


static func _walk(node: Node, fence_tex: Texture2D) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var low := String(mesh.name).to_lower()
		if "hedge" in low and "shadow" not in low:
			_dress(mesh)
			_shell(mesh, true)
		elif fence_tex != null and _wood_fence(mesh) and _same_texture(mesh, fence_tex):
			_shell(mesh, false)
	for child in node.get_children():
		_walk(child, fence_tex)


static var _hedge_material: ShaderMaterial


static func _dress(mesh: MeshInstance3D) -> void:
	if _hedge_material == null:
		var shader := load("res://scenes/playgrounds/hedge_card.gdshader") as Shader
		var source := _material(mesh)
		if shader == null or source == null or source.albedo_texture == null:
			return
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("albedo_texture", source.albedo_texture)
		material.set_shader_parameter("albedo_color", source.albedo_color)
		_hedge_material = material
	mesh.material_override = _hedge_material


static func _shell(mesh: MeshInstance3D, fill: bool) -> void:
	# A concave shell has an inside, and the toon can step into the gap
	# between the front and back cards and get stuck there. Each wall is one
	# solid box, thick enough to cover both cards.
	if mesh.mesh == null or mesh.get_node_or_null("TTCBarrier") != null:
		return
	var up := _up_axis(mesh)
	var up_vector := _up_vector(up)
	var groups: Array[Dictionary] = []
	for surface in mesh.mesh.get_surface_count():
		var arrays: Array = mesh.mesh.surface_get_arrays(surface)
		var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var index_data: Variant = arrays[Mesh.ARRAY_INDEX]
		var indices := PackedInt32Array()
		if index_data is PackedInt32Array:
			indices = index_data
		if indices.is_empty():
			var count := verts.size() - (verts.size() % 3)
			for i in range(0, count, 3):
				_collect(groups, verts[i], verts[i + 1], verts[i + 2], up_vector, fill)
		else:
			var count := indices.size() - (indices.size() % 3)
			for i in range(0, count, 3):
				_collect(groups, verts[indices[i]], verts[indices[i + 1]], verts[indices[i + 2]], up_vector, fill)
	var minimum := HEDGE_THICK if fill else FENCE_THICK
	var body := StaticBody3D.new()
	body.name = "TTCBarrier"
	body.collision_layer = 1
	body.collision_mask = 0
	for group in groups:
		var shape := _box(group, up_vector, minimum)
		if shape != null:
			body.add_child(shape)
	if body.get_child_count() == 0:
		return
	mesh.add_child(body)


static func _collect(groups: Array[Dictionary], a: Vector3, b: Vector3, c: Vector3, up_vector: Vector3, fill: bool) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 0.0001:
		return
	normal = normal.normalized()
	if absf(normal.dot(up_vector)) > 0.45:
		return
	normal = normal - up_vector * normal.dot(up_vector)
	if normal.length_squared() < 0.0001:
		return
	normal = normal.normalized()
	if _axis_of(normal) < 0.0:
		normal = -normal
	if fill:
		# One box for every card of this hedge that faces the same way, so the
		# gap between the front and the back is solid.
		for group in groups:
			var facing: Vector3 = group["normal"]
			if facing.dot(normal) < 0.92:
				continue
			var points: Array = group["points"]
			points.append(a)
			points.append(b)
			points.append(c)
			return
	groups.append({
		"normal": normal,
		"points": [a, b, c],
	})


static func _box(group: Dictionary, up_vector: Vector3, minimum: float) -> CollisionShape3D:
	var normal: Vector3 = group["normal"]
	normal = normal - up_vector * normal.dot(up_vector)
	if normal.length_squared() < 0.0001:
		return null
	normal = normal.normalized()
	var tangent := up_vector.cross(normal)
	if tangent.length_squared() < 0.0001:
		return null
	tangent = tangent.normalized()
	var points: Array = group["points"]
	var min_t := INF
	var max_t := -INF
	var min_u := INF
	var max_u := -INF
	var min_n := INF
	var max_n := -INF
	for item in points:
		var point: Vector3 = item
		var along := point.dot(tangent)
		var height := point.dot(up_vector)
		var depth := point.dot(normal)
		min_t = minf(min_t, along)
		max_t = maxf(max_t, along)
		min_u = minf(min_u, height)
		max_u = maxf(max_u, height)
		min_n = minf(min_n, depth)
		max_n = maxf(max_n, depth)
	if max_n - min_n < minimum:
		var mid := (min_n + max_n) * 0.5
		min_n = mid - minimum * 0.5
		max_n = mid + minimum * 0.5
	# Overlap the ends so the corner of an L is solid instead of a crack.
	min_t -= 0.3
	max_t += 0.3
	var center := tangent * ((min_t + max_t) * 0.5) + up_vector * ((min_u + max_u) * 0.5) + normal * ((min_n + max_n) * 0.5)
	var box := BoxShape3D.new()
	box.size = Vector3(max_t - min_t, max_u - min_u, max_n - min_n)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.transform = Transform3D(Basis(tangent, up_vector, normal), center)
	return shape


static func _up_vector(axis: int) -> Vector3:
	if axis == 0:
		return Vector3(1.0, 0.0, 0.0)
	if axis == 2:
		return Vector3(0.0, 0.0, 1.0)
	return Vector3(0.0, 1.0, 0.0)


static func _axis_of(normal: Vector3) -> float:
	if absf(normal.x) >= absf(normal.y) and absf(normal.x) >= absf(normal.z):
		return normal.x
	if absf(normal.z) >= absf(normal.y):
		return normal.z
	return normal.y


static func _up_axis(mesh: MeshInstance3D) -> int:
	# Walk local transforms. global_transform is identity until the node is in
	# the tree, and the hedge cards are still Z-up under the playground root.
	var basis := mesh.transform.basis
	var parent := mesh.get_parent()
	while parent is Node3D:
		basis = (parent as Node3D).transform.basis * basis
		parent = parent.get_parent()
	var best := 1
	var score := -1.0
	for axis in 3:
		var column := basis.x
		if axis == 1:
			column = basis.y
		elif axis == 2:
			column = basis.z
		var amount := absf(column.dot(Vector3.UP))
		if amount > score:
			score = amount
			best = axis
	return best


static func _material(mesh: MeshInstance3D) -> StandardMaterial3D:
	var active := mesh.get_active_material(0)
	if active is StandardMaterial3D:
		return active as StandardMaterial3D
	if mesh.mesh != null:
		var surface := mesh.mesh.surface_get_material(0)
		if surface is StandardMaterial3D:
			return surface as StandardMaterial3D
	return null


static func _albedo(mesh: MeshInstance3D) -> Texture2D:
	var source := _material(mesh)
	if source == null:
		return null
	return source.albedo_texture


static func _wood_fence(mesh: MeshInstance3D) -> bool:
	var mesh_name := String(mesh.name)
	if mesh_name == "wall_1":
		return true
	# Godot renames the second "fence" node. Skip the little picket pieces.
	if mesh_name.begins_with("fenceFlat"):
		return false
	return mesh_name == "fence" or mesh_name.begins_with("fence_") or mesh_name.begins_with("fence2")


static func _same_texture(mesh: MeshInstance3D, fence_tex: Texture2D) -> bool:
	var texture := _albedo(mesh)
	if texture == null or fence_tex == null:
		return false
	if texture == fence_tex:
		return true
	if texture.resource_path != "" and texture.resource_path == fence_tex.resource_path:
		return true
	if texture.get_width() != fence_tex.get_width() or texture.get_height() != fence_tex.get_height():
		return false
	var left := texture.get_image()
	var right := fence_tex.get_image()
	if left == null or right == null or left.is_empty() or right.is_empty():
		return false
	var mid_x := left.get_width() / 2
	var mid_y := left.get_height() / 2
	return left.get_pixel(0, 0) == right.get_pixel(0, 0) and left.get_pixel(mid_x, mid_y) == right.get_pixel(mid_x, mid_y)
