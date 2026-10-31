extends Node3D

## Flat street floors (road, sidewalk, curb, grass, and the outer edge) get one
## thick box that overlaps its neighbors, so a seam or a lip cannot drop the toon.
## Ramps, stairs, and sunken roads keep their real surface, thickened into a
## volume, because a box of those bounds would fill the slope. Tunnel arches stay
## triangle shells so the mouth is not sealed. Small trim fades with distance.

var _street := false


func _ready() -> void:
	_street = _on_street()
	_collect(self)
	# Street blocks are a few dozen materials repeated across a thousand
	# meshes. Combine each block after the street script has finished painting
	# tunnels, so the draw count follows the materials instead of the props.
	if _street and not Engine.is_editor_hint():
		call_deferred("_merge_street_draws")


func _collect(node: Node) -> void:
	if "sky" in String(node.name).to_lower():
		return
	for child in node.get_children():
		_collect(child)
	if not node is MeshInstance3D:
		return
	var mesh_node := node as MeshInstance3D
	if mesh_node.mesh == null:
		return
	var node_name := String(mesh_node.name).to_lower()
	var world := mesh_node.global_transform * mesh_node.get_aabb()
	var world_size := world.size
	var span := maxf(world_size.x, world_size.z)
	var thin := minf(world_size.x, world_size.z)
	var biggest := maxf(span, world_size.y)
	var decorative := node_name.contains("shadow") or node_name.contains("billboard") or node_name.contains("sign") or node_name.contains("decal")
	if decorative or not _has_solid_surface(mesh_node):
		if not decorative:
			_distance_cull(mesh_node, biggest)
		return
	# The Loopy Lane mouth is safe_zone_entrance_front. Its bounds cover the
	# arch, so a box is a wall across the sidewalk. The triangles leave the
	# opening empty. Tunnel shells are the same shape.
	if _is_opening(node_name):
		mesh_node.create_trimesh_collision()
		return
	# Every named floor on a street: asphalt, sidewalk, curb, grass, stairs.
	# A flat piece is a thick overlapping box. A ramp keeps its triangles.
	if _is_ground(node_name) and span >= 0.35 and world.position.y < 12.0:
		if _needs_volume(node_name, world_size.y):
			_add_floor_volume(mesh_node)
		else:
			_add_ground_box(mesh_node)
		return
	# Window trim and cornices are not walls worth a physics body. A building
	# face still is, so a nametag ray and the toon both stop on it.
	var thin_wall := world_size.y >= 3.0 and thin < 6.0 and world_size.y > thin * 1.4 and span >= 4.0
	if thin_wall:
		_add_box(mesh_node, false)
	elif not _street and (node_name.contains("hill") or node_name.contains("slope") or span > 50.0):
		# Playground ring, hill, or one-piece floor. A box of that bounds
		# would be solid across the tunnel. The triangles are not.
		mesh_node.create_trimesh_collision()
	_distance_cull(mesh_node, biggest)


## Street pieces are authored Z-up, then the glTF root turns that into world
## up. Thickening local Y, or growing every axis, puts the box on top of the
## pavement and the toon stands in the air. Grow the horizontal axes only, and
## extend straight down from the walk surface.
func _add_ground_box(mesh_node: MeshInstance3D) -> void:
	var bounds := mesh_node.get_aabb()
	var origin := bounds.position
	var size := bounds.size
	var up := mesh_node.global_basis.inverse() * Vector3.UP
	var overlap := 0.5
	var depth := 2.0
	if absf(up.x) < 0.6:
		origin.x -= overlap
		size.x += overlap * 2.0
	if absf(up.y) < 0.6:
		origin.y -= overlap
		size.y += overlap * 2.0
	if absf(up.z) < 0.6:
		origin.z -= overlap
		size.z += overlap * 2.0
	if absf(up.z) >= absf(up.x) and absf(up.z) >= absf(up.y):
		if up.z >= 0.0:
			origin.z -= depth
		size.z += depth
	elif absf(up.y) >= absf(up.x):
		if up.y >= 0.0:
			origin.y -= depth
		size.y += depth
	else:
		if up.x >= 0.0:
			origin.x -= depth
		size.x += depth
	_commit_box(mesh_node, origin, size)


func _add_box(mesh_node: MeshInstance3D, _ground: bool) -> void:
	var bounds := mesh_node.get_aabb()
	var size := bounds.size
	var origin := bounds.position
	var axis := 0
	var smallest := size.x
	if size.y < smallest:
		axis = 1
		smallest = size.y
	if size.z < smallest:
		axis = 2
		smallest = size.z
	if smallest < 0.45:
		var extra := 0.45 - smallest
		if axis == 0:
			origin.x -= extra * 0.5
			size.x = 0.45
		elif axis == 1:
			origin.y -= extra * 0.5
			size.y = 0.45
		else:
			origin.z -= extra * 0.5
			size.z = 0.45
	_commit_box(mesh_node, origin, size)


func _commit_box(mesh_node: MeshInstance3D, origin: Vector3, size: Vector3) -> void:
	if size.x < 0.05 or size.y < 0.05 or size.z < 0.05:
		return
	var body := StaticBody3D.new()
	body.name = "Solid"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	shape_node.position = origin + size * 0.5
	body.add_child(shape_node)
	mesh_node.add_child(body)


func _distance_cull(mesh_node: MeshInstance3D, biggest: float) -> void:
	if biggest >= 18.0 or biggest < 0.05:
		return
	var reach := 55.0
	if biggest >= 8.0:
		reach = 120.0
	elif biggest >= 3.5:
		reach = 80.0
	mesh_node.visibility_range_end = reach
	mesh_node.visibility_range_end_margin = 10.0
	mesh_node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


## A slope, a stair, or a sunken block is not a flat slab. Follow its triangles
## and thicken them downward so the toon cannot fall through the ramp.
func _add_floor_volume(mesh_node: MeshInstance3D) -> void:
	var mesh := mesh_node.mesh
	var total := 0
	for index in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(index) != Mesh.PRIMITIVE_TRIANGLES:
			mesh_node.create_trimesh_collision()
			return
		total += _surface_triangles(mesh, index)
	if total <= 0:
		return
	if total > 1800:
		mesh_node.create_trimesh_collision()
		return
	var faces := PackedVector3Array()
	var world_xform := mesh_node.global_transform
	var to_local := world_xform.affine_inverse()
	var drop := Vector3(0.0, -2.0, 0.0)
	for index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(index)
		var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		if verts == null or verts.is_empty():
			continue
		var indices := PackedInt32Array()
		var raw_index: Variant = arrays[Mesh.ARRAY_INDEX]
		if raw_index is PackedInt32Array:
			indices = raw_index
		var indexed := not indices.is_empty()
		var count := indices.size() if indexed else verts.size()
		var cursor := 0
		while cursor + 2 < count:
			var i0 := cursor
			var i1 := cursor + 1
			var i2 := cursor + 2
			if indexed:
				i0 = indices[cursor]
				i1 = indices[cursor + 1]
				i2 = indices[cursor + 2]
			var w0 := world_xform * verts[i0]
			var w1 := world_xform * verts[i1]
			var w2 := world_xform * verts[i2]
			var normal := (w1 - w0).cross(w2 - w0)
			# Vertical faces are the riser, not a platform. A downward face is
			# the same walk surface wound the other way.
			if absf(normal.y) <= 0.25 or normal.length_squared() <= 0.0001:
				cursor += 3
				continue
			if normal.y < 0.0:
				var flip := w1
				w1 = w2
				w2 = flip
			var d0 := w0 + drop
			var d1 := w1 + drop
			var d2 := w2 + drop
			var l0 := to_local * w0
			var l1 := to_local * w1
			var l2 := to_local * w2
			var n0 := to_local * d0
			var n1 := to_local * d1
			var n2 := to_local * d2
			faces.append(l0)
			faces.append(l1)
			faces.append(l2)
			faces.append(n0)
			faces.append(n2)
			faces.append(n1)
			faces.append(l0)
			faces.append(n0)
			faces.append(l1)
			faces.append(l1)
			faces.append(n0)
			faces.append(n1)
			faces.append(l1)
			faces.append(n1)
			faces.append(l2)
			faces.append(l2)
			faces.append(n1)
			faces.append(n2)
			faces.append(l2)
			faces.append(n2)
			faces.append(l0)
			faces.append(l0)
			faces.append(n2)
			faces.append(n0)
			cursor += 3
	if faces.is_empty():
		mesh_node.create_trimesh_collision()
		return
	var body := StaticBody3D.new()
	body.name = "Solid"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.data = faces
	shape_node.shape = shape
	body.add_child(shape_node)
	mesh_node.add_child(body)


func _surface_triangles(mesh: Mesh, index: int) -> int:
	var arrays := mesh.surface_get_arrays(index)
	var raw_index: Variant = arrays[Mesh.ARRAY_INDEX]
	if raw_index is PackedInt32Array and not (raw_index as PackedInt32Array).is_empty():
		return int((raw_index as PackedInt32Array).size() / 3)
	var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	if verts == null:
		return 0
	return int(verts.size() / 3)


func _needs_volume(node_name: String, height: float) -> bool:
	if node_name.contains("slope") or node_name.contains("stair") or node_name.contains("sunken"):
		return true
	return height >= 1.8


func _merge_street_draws() -> void:
	var zones: Array[Node3D] = []
	_find_zones(self, zones)
	for zone in zones:
		_merge_draws(zone)
	_merge_draws(self)


func _find_zones(node: Node, zones: Array[Node3D]) -> void:
	for child in node.get_children():
		if _is_zone(child) and child is Node3D:
			zones.append(child as Node3D)
		else:
			_find_zones(child, zones)


func _is_zone(node: Node) -> bool:
	var node_name := String(node.name)
	return node_name.is_valid_int() and node_name.length() >= 4


func _merge_draws(root: Node3D) -> void:
	var sources: Array[MeshInstance3D] = []
	_gather_merge(root, sources, root)
	if sources.size() < 2:
		return
	var counts: Dictionary = {}
	for mesh_node in sources:
		var mesh := mesh_node.mesh
		for index in mesh.get_surface_count():
			var material := mesh_node.get_active_material(index)
			if _skip_surface(material):
				continue
			var key := _material_key(material)
			counts[key] = int(counts.get(key, 0)) + 1
	var groups: Dictionary = {}
	var hidden: Array[MeshInstance3D] = []
	for mesh_node in sources:
		if _bucket_mesh(root, mesh_node, groups, counts):
			hidden.append(mesh_node)
	for key in groups:
		var group: Dictionary = groups[key]
		var tool := group["tool"] as SurfaceTool
		var material := group["material"] as Material
		var batch := tool.commit()
		for index in batch.get_surface_count():
			if material != null:
				batch.surface_set_material(index, material)
		var instance := MeshInstance3D.new()
		instance.name = "StreetBatch"
		instance.mesh = batch
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(instance)
	for mesh_node in hidden:
		# Hide this draw only. A child sign or door still renders, and the
		# floor body hung on this node keeps colliding.
		mesh_node.layers = 0


func _material_key(material: Material) -> String:
	if material == null:
		return "none"
	return str(material.get_instance_id())


func _skip_surface(material: Material) -> bool:
	return material is BaseMaterial3D and (material as BaseMaterial3D).albedo_color.a < 0.05


func _bucket_mesh(root: Node3D, mesh_node: MeshInstance3D, groups: Dictionary, counts: Dictionary) -> bool:
	var mesh := mesh_node.mesh
	var pending: Array[int] = []
	for index in mesh.get_surface_count():
		var material := mesh_node.get_active_material(index)
		if _skip_surface(material):
			continue
		if int(counts.get(_material_key(material), 0)) < 2:
			return false
		pending.append(index)
	if pending.is_empty():
		return false
	var xform := root.global_transform.affine_inverse() * mesh_node.global_transform
	for index in pending:
		var material := mesh_node.get_active_material(index)
		var key := _material_key(material)
		if not groups.has(key):
			var created := SurfaceTool.new()
			created.begin(Mesh.PRIMITIVE_TRIANGLES)
			if material != null:
				created.set_material(material)
			groups[key] = {"tool": created, "material": material}
		var group: Dictionary = groups[key]
		var tool := group["tool"] as SurfaceTool
		if material != null:
			tool.set_material(material)
		tool.append_from(mesh, index, xform)
	return true


func _gather_merge(node: Node, sources: Array[MeshInstance3D], root: Node) -> void:
	for child in node.get_children():
		if child != root and _is_zone(child):
			continue
		if child is MeshInstance3D and _can_merge(child as MeshInstance3D):
			sources.append(child as MeshInstance3D)
		_gather_merge(child, sources, root)


func _can_merge(mesh_node: MeshInstance3D) -> bool:
	if not mesh_node.visible or mesh_node.mesh == null or mesh_node.skin != null:
		return false
	if mesh_node.layers == 0:
		return false
	var node_name := String(mesh_node.name).to_lower()
	if node_name == "streetbatch" or node_name.contains("billboard") or node_name.contains("sky"):
		return false
	if mesh_node.is_in_group("tt_billboard"):
		return false
	var mesh := mesh_node.mesh
	for index in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(index) != Mesh.PRIMITIVE_TRIANGLES:
			return false
	return mesh.get_surface_count() > 0


func _is_opening(node_name: String) -> bool:
	if _is_ground(node_name):
		return false
	return node_name.contains("tunnel") or node_name.contains("entrance")


func _on_street() -> bool:
	var owner := get_owner()
	var path := ""
	if owner != null:
		path = owner.scene_file_path
	if path.is_empty() and get_tree() != null and get_tree().current_scene != null:
		path = get_tree().current_scene.scene_file_path
	return path.contains("/streets/")


func _is_ground(node_name: String) -> bool:
	if node_name.contains("background"):
		return false
	if node_name.contains("sidewalk") or node_name.contains("curb") or node_name.ends_with("street"):
		return true
	if node_name.contains("grass") or node_name.contains("floor") or node_name.contains("slope"):
		return true
	if node_name.contains("stair") or node_name.contains("sunken"):
		return true
	return node_name == "ground" or node_name.ends_with("_ground") or node_name.contains("outsideground") or node_name.contains("outside_ground")


func _is_wall(node_name: String) -> bool:
	if node_name.contains("background"):
		return false
	return node_name.contains("wall") or node_name.contains("building") or node_name.contains("bldg") or node_name.contains("door") or node_name.contains("fence")


func _has_solid_surface(mesh_node: MeshInstance3D) -> bool:
	var mesh := mesh_node.mesh
	if mesh == null:
		return false
	for index in mesh.get_surface_count():
		if _surface_solid(mesh_node.get_active_material(index)):
			return true
	return false


## Cutout walls still stop a nametag. Soft cards (leaves, glass, shadows) do not.
func _surface_solid(material: Material) -> bool:
	if not material is BaseMaterial3D:
		return true
	var mode := (material as BaseMaterial3D).transparency
	return mode == BaseMaterial3D.TRANSPARENCY_DISABLED or mode == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR or mode == BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
