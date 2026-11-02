extends RefCounted

## The original street stashes every visgroup except the blocks listed for the
## floor under the avatar. Those blocks are drawn as one surface per texture.
## The other views stay as mesh data, not as objects in the scene. Swinging
## doors, closed door pictures, and signs stay on their block so they hide with it.

class Bucket extends RefCounted:
	var material: Material
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var has_uv := false
	var has_color := false


class Job extends RefCounted:
	var faces := PackedVector3Array()
	var buckets: Dictionary = {}


static var _batch_serial := 0


static func apply(root: Node) -> void:
	_walk(root, root)


static func apply_flat(root: Node3D) -> void:
	_batch(root, root)


static func prepare(host: Node, zone_nodes: Dictionary, zones: Dictionary) -> void:
	var geom := _geometry(host)
	if geom == null or geom.has_meta("street_views") or zone_nodes.is_empty():
		return
	var views := {}
	for zone_name in zone_nodes:
		var shown := _shown_nodes(zone_nodes, zones, String(zone_name))
		var meshes := _build_meshes(shown)
		if not meshes.is_empty():
			views[String(zone_name)] = meshes
	if not views.is_empty():
		geom.set_meta("street_views", views)
		_drop_sources(zone_nodes)
	if host.has_meta("street_shown"):
		host.remove_meta("street_shown")


static func apply_visible(host: Node, zone_name: String, zone_nodes: Dictionary, zones: Dictionary) -> void:
	# Street.doEnterZone only stashes the blocks that left the vis list and
	# unstashes the ones that entered. Blocks that stayed do not get touched.
	if zone_name.is_empty() or not zones.has(zone_name):
		return
	var shown := {}
	var record: Dictionary = zones[zone_name]
	var vis: Array = record.get("vis", [])
	for entry in vis:
		shown[String(entry)] = true
	shown[zone_name] = true
	if not host.has_meta("street_shown"):
		for key in zone_nodes:
			_show_zone(zone_nodes[key] as Node, shown.has(String(key)))
	else:
		var previous: Dictionary = host.get_meta("street_shown")
		for key in previous:
			var zone_key := String(key)
			if not shown.has(zone_key) and zone_nodes.has(zone_key):
				_show_zone(zone_nodes[zone_key] as Node, false)
		for key in shown:
			var zone_key := String(key)
			if not previous.has(zone_key) and zone_nodes.has(zone_key):
				_show_zone(zone_nodes[zone_key] as Node, true)
	host.set_meta("street_shown", shown)
	show_zones(host, zone_name, _shown_nodes(zone_nodes, zones, zone_name))


static func show_zones(host: Node, zone_name: String, zones: Array[Node3D]) -> void:
	var geom := _geometry(host)
	if geom == null or zone_name.is_empty():
		return
	var has_views := geom.has_meta("street_views")
	if not has_views and not _has_cached_verts(zones):
		return
	var live := geom.get_node_or_null("StreetVisible") as Node3D
	if live != null and String(live.get_meta("shown", "")) == zone_name:
		return
	if live == null:
		live = Node3D.new()
		live.name = "StreetVisible"
		geom.add_child(live)
	if has_views:
		var views: Dictionary = geom.get_meta("street_views")
		var meshes: Array = views.get(zone_name, [])
		_use_meshes(live, meshes)
		live.set_meta("shown", zone_name)
		return
	for child in live.get_children():
		child.free()
	_fill(live, zones)
	live.set_meta("shown", zone_name)


static func set_solid(zone: Node, shown: bool) -> void:
	if zone == null:
		return
	var layer := 1 if shown else 0
	var bodies: Array
	if zone.has_meta("street_bodies"):
		bodies = zone.get_meta("street_bodies")
	else:
		bodies = []
		_collect_bodies(zone, bodies)
		# Solids are added after the first visibility pass. Don't remember an
		# empty list from that pass, or the real floor never gets toggled.
		if not bodies.is_empty():
			zone.set_meta("street_bodies", bodies)
	for item in bodies:
		var object := item as CollisionObject3D
		if object != null and object.collision_layer != layer:
			object.collision_layer = layer


static func _show_zone(zone: Node, shown: bool) -> void:
	if zone == null:
		return
	if zone is Node3D and (zone as Node3D).visible != shown:
		(zone as Node3D).visible = shown
	set_solid(zone, shown)


static func _collect_bodies(node: Node, bodies: Array) -> void:
	if node is CollisionObject3D:
		bodies.append(node)
	for child in node.get_children():
		_collect_bodies(child, bodies)


static func _use_meshes(live: Node3D, meshes: Array) -> void:
	var count := meshes.size()
	while live.get_child_count() > count:
		var extra := live.get_child(live.get_child_count() - 1)
		live.remove_child(extra)
		extra.free()
	for index in count:
		var mesh := meshes[index] as ArrayMesh
		if mesh == null:
			continue
		var instance: MeshInstance3D
		if index < live.get_child_count():
			instance = live.get_child(index) as MeshInstance3D
		else:
			instance = MeshInstance3D.new()
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			live.add_child(instance)
		if instance != null and instance.mesh != mesh:
			instance.mesh = mesh


static func _walk(node: Node, root: Node) -> void:
	if _is_zone(node):
		_batch(node as Node3D, root)
		return
	for child in node.get_children():
		_walk(child, root)


static func _is_zone(node: Node) -> bool:
	if not (node is Node3D):
		return false
	var node_name := String(node.name)
	return node_name.length() >= 4 and node_name.is_valid_int()


static func _batch(zone: Node3D, root: Node) -> void:
	var job := Job.new()
	var taken: Array[MeshInstance3D] = []
	_collect(zone, zone, zone.global_transform.affine_inverse(), job, taken)
	if not job.faces.is_empty():
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(job.faces)
		var body := StaticBody3D.new()
		body.name = "ZoneSolid"
		body.collision_layer = 0
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		zone.add_child(body)
	var shown := not _is_zone(zone)
	var placed := Transform3D.IDENTITY
	if not shown and root is Node3D:
		placed = (root as Node3D).global_transform.affine_inverse() * zone.global_transform
	for key in job.buckets:
		var bucket := job.buckets[key] as Bucket
		if shown:
			_emit(zone, bucket, true)
		else:
			_store(zone, bucket, placed)
	for mesh in taken:
		mesh.mesh = null


static func _collect(node: Node, zone: Node3D, into_zone: Transform3D, job: Job, taken: Array[MeshInstance3D]) -> void:
	# A shop stays one surface on its own node. Hiding that node is the
	# takeover. Leaving every wall as its own object is what dropped the frame rate.
	if node != zone and node is Node3D and _toon_shop(String(node.name)):
		_flatten_landmark(node as Node3D)
		return
	if node != zone and _leave_alone(String(node.name)):
		return
	if node is MeshInstance3D and node != zone:
		var mesh := node as MeshInstance3D
		if mesh.visible and _take(mesh, into_zone, job):
			taken.append(mesh)
	for child in node.get_children():
		_collect(child, zone, into_zone, job, taken)


static func _toon_shop(node_name: String) -> bool:
	return node_name.to_lower().contains("toon_landmark")


static func _landmark(node_name: String) -> bool:
	var lowered := node_name.to_lower()
	return lowered.contains("toon_landmark") or lowered.contains("animated_building")


static func flatten_prop(root: Node3D) -> void:
	if root == null:
		return
	_flatten_landmark(root)


static func sweep_empty(root: Node) -> void:
	# Batching nulls the source meshes and leaves the nodes. A street is a few
	# thousand of those, and the renderer still walks every one.
	var guard := 0
	while guard < 6:
		guard += 1
		var drop: Array[Node] = []
		_gather_empty(root, drop)
		if drop.is_empty():
			return
		for item in drop:
			if is_instance_valid(item) and item != root:
				item.free()


static func _gather_empty(node: Node, drop: Array[Node]) -> void:
	for child in node.get_children():
		_gather_empty(child, drop)
	if node is MeshInstance3D and (node as MeshInstance3D).mesh == null and node.get_child_count() == 0 and not node.has_meta("street_batched") and not "door" in String(node.name).to_lower():
		drop.append(node)


static func _flatten_landmark(landmark: Node3D) -> void:
	if landmark.has_meta("landmark_flat"):
		return
	var job := Job.new()
	var taken: Array[MeshInstance3D] = []
	var into := landmark.global_transform.affine_inverse()
	for child in landmark.get_children():
		_collect(child, landmark, into, job, taken)
	for key in job.buckets:
		var mesh := _mesh_from(job.buckets[key] as Bucket)
		if mesh == null:
			continue
		_instance(landmark, mesh)
	for mesh in taken:
		# Keep the node visible. Door cards are children of the wall, and
		# hiding the wall hides the door even though its own mesh is still there.
		mesh.mesh = null
	landmark.set_meta("landmark_flat", true)


static func _leave_alone(node_name: String) -> bool:
	var lowered := node_name.to_lower()
	if _landmark(lowered):
		return true
	if lowered.contains("__billboard") or lowered.contains("drop_shadow") or lowered.contains("sky"):
		return true
	# The painted door and its frame sit on the wall mesh. Folding them into
	# that mesh and then hiding the wall node removes the door and leaves a hole.
	if "door" in lowered:
		return true
	while lowered.ends_with("_") or (lowered.length() > 0 and lowered.substr(lowered.length() - 1, 1).is_valid_int()):
		lowered = lowered.substr(0, lowered.length() - 1)
	return lowered == "leftdoor" or lowered == "rightdoor" or lowered.begins_with("doorframehole") or lowered == "door_flat" or lowered.ends_with("_flat") or lowered == "def_left_door" or lowered == "def_right_door"


static func _take(mesh: MeshInstance3D, into_zone: Transform3D, job: Job) -> bool:
	if mesh.mesh == null or mesh.mesh.get_surface_count() == 0:
		return false
	for surface in mesh.mesh.get_surface_count():
		if mesh.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			return false
		var arrays: Array = mesh.mesh.surface_get_arrays(surface)
		var verts: Variant = arrays[Mesh.ARRAY_VERTEX]
		if not (verts is PackedVector3Array) or (verts as PackedVector3Array).is_empty():
			return false
		var bones: Variant = arrays[Mesh.ARRAY_BONES]
		if bones is PackedInt32Array and (bones as PackedInt32Array).size() > 0:
			return false
		if bones is PackedFloat32Array and (bones as PackedFloat32Array).size() > 0:
			return false
	var to_local := into_zone * mesh.global_transform
	if absf(to_local.basis.determinant()) < 0.0000001:
		return false
	var copied := 0
	for surface in mesh.mesh.get_surface_count():
		copied += _take_surface(mesh, surface, to_local, job)
	return copied > 0


static func _take_surface(mesh: MeshInstance3D, surface: int, to_local: Transform3D, job: Job) -> int:
	var material := mesh.get_active_material(surface)
	if _hidden_card(material):
		return 0
	var arrays: Array = mesh.mesh.surface_get_arrays(surface)
	var source_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var source_norms := PackedVector3Array()
	if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
		source_norms = arrays[Mesh.ARRAY_NORMAL]
	var source_uvs := PackedVector2Array()
	if arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array:
		source_uvs = arrays[Mesh.ARRAY_TEX_UV]
	var source_colors := PackedColorArray()
	if arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
		source_colors = arrays[Mesh.ARRAY_COLOR]
	var has_uv := source_uvs.size() == source_verts.size()
	var has_color := source_colors.size() == source_verts.size()
	var bucket := _bucket(job, material, has_uv, has_color)
	var ids := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		ids = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := to_local.basis.inverse().transposed()
	var tint := Color.WHITE
	var keep_vertex := false
	if material is StandardMaterial3D:
		var std := material as StandardMaterial3D
		tint = std.albedo_color
		keep_vertex = has_color and std.vertex_color_use_as_albedo
	var cursor := 0
	var limit := ids.size() if ids.size() >= 3 else source_verts.size()
	var copied := 0
	var opaque := not (material is BaseMaterial3D) or (material as BaseMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
	# Fence pictures are masked, but the wall behind the picture is solid.
	var wall := boundary_wall(mesh)
	while cursor + 2 < limit:
		var i0 := cursor
		var i1 := cursor + 1
		var i2 := cursor + 2
		if ids.size() >= 3:
			i0 = ids[cursor]
			i1 = ids[cursor + 1]
			i2 = ids[cursor + 2]
		if i0 < 0 or i1 < 0 or i2 < 0 or i0 >= source_verts.size() or i1 >= source_verts.size() or i2 >= source_verts.size():
			cursor += 3
			continue
		var p0 := to_local * source_verts[i0]
		var p1 := to_local * source_verts[i1]
		var p2 := to_local * source_verts[i2]
		bucket.verts.append(p0)
		bucket.verts.append(p1)
		bucket.verts.append(p2)
		if (opaque or wall) and _keep_solid(p0, p1, p2):
			job.faces.append(p0)
			job.faces.append(p1)
			job.faces.append(p2)
		bucket.norms.append(_normal(source_norms, normal_basis, i0, p0, p1, p2))
		bucket.norms.append(_normal(source_norms, normal_basis, i1, p1, p2, p0))
		bucket.norms.append(_normal(source_norms, normal_basis, i2, p2, p0, p1))
		if bucket.has_uv:
			bucket.uvs.append(source_uvs[i0] if has_uv else Vector2.ZERO)
			bucket.uvs.append(source_uvs[i1] if has_uv else Vector2.ZERO)
			bucket.uvs.append(source_uvs[i2] if has_uv else Vector2.ZERO)
		if bucket.has_color:
			bucket.colors.append(_paint(source_colors, i0, tint, keep_vertex))
			bucket.colors.append(_paint(source_colors, i1, tint, keep_vertex))
			bucket.colors.append(_paint(source_colors, i2, tint, keep_vertex))
		copied += 1
		cursor += 3
	return copied


## Flat-building walls, and the playground fence copied along a street edge.
## The texture is a cutout, so the opaque pass used to leave the rectangle out.
static func boundary_wall(mesh: MeshInstance3D) -> bool:
	var low := String(mesh.name).to_lower()
	return low.begins_with("wall_") or "fence" in low


static func _keep_solid(a: Vector3, b: Vector3, c: Vector3) -> bool:
	var cross := (b - a).cross(c - a)
	var span := cross.length()
	if span < 0.08:
		return false
	if absf(cross.y) / span > 0.55:
		return true
	return span > 0.35


static func _hidden_card(material: Material) -> bool:
	if material is StandardMaterial3D:
		return (material as StandardMaterial3D).albedo_color.a < 0.05
	return false


static func _paint(source: PackedColorArray, index: int, tint: Color, keep_vertex: bool) -> Color:
	if keep_vertex and index < source.size():
		return source[index] * tint
	return tint


static func _normal(source: PackedVector3Array, basis: Basis, index: int, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	if index < source.size():
		var turned := basis * source[index]
		if turned.length_squared() > 0.000001:
			return turned.normalized()
	var face := (b - a).cross(c - a)
	if face.length_squared() < 0.000001:
		return Vector3.UP
	return face.normalized()


static func _bucket_shared(job: Job, material: Material, has_uv: bool, has_color: bool) -> Bucket:
	var key := "%s|%s|%s" % [_key(material), 1 if has_uv else 0, 1 if has_color else 0]
	if job.buckets.has(key):
		return job.buckets[key] as Bucket
	var bucket := Bucket.new()
	bucket.has_uv = has_uv
	bucket.has_color = has_color
	bucket.material = material
	_relax_filter(bucket.material)
	job.buckets[key] = bucket
	return bucket


static func _bucket(job: Job, material: Material, has_uv: bool, has_color: bool) -> Bucket:
	var standard: StandardMaterial3D = null
	if material is StandardMaterial3D:
		standard = material as StandardMaterial3D
	var colored := standard != null or has_color
	var key := "%s|%s|%s" % [_key(material), 1 if has_uv else 0, 1 if colored else 0]
	if job.buckets.has(key):
		return job.buckets[key] as Bucket
	var bucket := Bucket.new()
	bucket.has_uv = has_uv
	bucket.has_color = colored
	if standard != null:
		var copy := standard.duplicate() as StandardMaterial3D
		copy.albedo_color = Color.WHITE
		copy.vertex_color_use_as_albedo = true
		bucket.material = copy
	else:
		bucket.material = material
	_relax_filter(bucket.material)
	job.buckets[key] = bucket
	return bucket


## Anisotropic 16 on a sidewalk seen down its length samples the texture many
## times per pixel. The street is that view. Mipmaps without it stay sharp
## enough and the block stops filling the frame rate.
static func _relax_filter(material: Material) -> void:
	if material is BaseMaterial3D:
		(material as BaseMaterial3D).texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


static func _key(material: Material) -> String:
	if material == null:
		return "none"
	if material is StandardMaterial3D:
		var std := material as StandardMaterial3D
		var tex := "0"
		if std.albedo_texture != null:
			tex = str(std.albedo_texture.get_instance_id())
		return "%s|%s|%s|%s|%s|%.3f" % [
			tex,
			int(std.transparency),
			int(std.cull_mode),
			_vec(std.uv1_scale),
			_vec(std.uv1_offset),
			std.alpha_scissor_threshold,
		]
	return "id%d" % material.get_instance_id()


static func _vec(value: Vector3) -> String:
	return "%.3f,%.3f,%.3f" % [value.x, value.y, value.z]


static func _geometry(host: Node) -> Node3D:
	var named := host.get_node_or_null("Geometry")
	if named is Node3D:
		return named as Node3D
	if host is Node3D and host.has_method("build_street"):
		return host as Node3D
	return null


static func _store(zone: Node3D, bucket: Bucket, placed: Transform3D) -> void:
	var count := bucket.verts.size()
	if count == 0:
		return
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	verts.resize(count)
	norms.resize(count)
	var normal_basis := placed.basis.inverse().transposed()
	for index in count:
		verts[index] = placed * bucket.verts[index]
		var turned := normal_basis * bucket.norms[index]
		if turned.length_squared() > 0.000001:
			norms[index] = turned.normalized()
		else:
			norms[index] = Vector3.UP
	var node := Node3D.new()
	_batch_serial += 1
	node.name = "ZoneBatch%d" % _batch_serial
	node.set_meta("street_batched", true)
	node.set_meta("verts", verts)
	node.set_meta("norms", norms)
	node.set_meta("material", bucket.material)
	node.set_meta("has_uv", bucket.has_uv)
	node.set_meta("has_color", bucket.has_color)
	if bucket.has_uv:
		node.set_meta("uvs", bucket.uvs)
	if bucket.has_color:
		node.set_meta("colors", bucket.colors)
	zone.add_child(node)


static func _shown_nodes(zone_nodes: Dictionary, zones: Dictionary, zone_name: String) -> Array[Node3D]:
	var shown: Array[Node3D] = []
	if not zones.has(zone_name):
		return shown
	var record: Dictionary = zones[zone_name]
	var vis: Array = record.get("vis", [])
	var seen := {}
	for entry in vis:
		var key := String(entry)
		if seen.has(key) or not zone_nodes.has(key) or not (zone_nodes[key] is Node3D):
			continue
		seen[key] = true
		shown.append(zone_nodes[key] as Node3D)
	if zone_nodes.has(zone_name) and zone_nodes[zone_name] is Node3D:
		var own := zone_nodes[zone_name] as Node3D
		if not shown.has(own):
			shown.append(own)
	return shown


static func _has_cached_verts(zones: Array[Node3D]) -> bool:
	for zone in zones:
		if zone == null:
			continue
		for child in zone.get_children():
			if child.has_meta("verts"):
				return true
	return false


static func _build_meshes(zones: Array[Node3D]) -> Array[ArrayMesh]:
	var built: Array[ArrayMesh] = []
	var job := Job.new()
	for zone in zones:
		if zone == null:
			continue
		for child in zone.get_children():
			if child.has_meta("verts"):
				_absorb_cached(job, child)
	for key in job.buckets:
		var mesh := _mesh_from(job.buckets[key] as Bucket)
		if mesh != null:
			built.append(mesh)
	return built


static func _drop_sources(zone_nodes: Dictionary) -> void:
	for zone_name in zone_nodes:
		var zone := zone_nodes[zone_name] as Node
		if zone == null:
			continue
		var drop: Array[Node] = []
		for child in zone.get_children():
			if child.has_meta("verts"):
				drop.append(child)
		for child in drop:
			child.free()


static func _fill(holder: Node3D, zones: Array[Node3D]) -> bool:
	var meshes := _build_meshes(zones)
	if meshes.is_empty():
		return false
	for mesh in meshes:
		_instance(holder, mesh)
	return true


static func _instance(holder: Node3D, mesh: ArrayMesh) -> void:
	var instance := MeshInstance3D.new()
	_batch_serial += 1
	instance.name = "ZoneBatch%d" % _batch_serial
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.set_meta("street_batched", true)
	holder.add_child(instance)


static func _absorb_cached(job: Job, node: Node) -> void:
	var source: Variant = node.get_meta("verts")
	if not (source is PackedVector3Array) or (source as PackedVector3Array).is_empty():
		return
	var material := node.get_meta("material") as Material
	var has_uv := bool(node.get_meta("has_uv"))
	var has_color := bool(node.get_meta("has_color"))
	var bucket := _bucket_shared(job, material, has_uv, has_color)
	bucket.verts.append_array(source as PackedVector3Array)
	var norms: Variant = node.get_meta("norms")
	if norms is PackedVector3Array:
		bucket.norms.append_array(norms as PackedVector3Array)
	if bucket.has_uv:
		var uvs: Variant = node.get_meta("uvs")
		if uvs is PackedVector2Array:
			bucket.uvs.append_array(uvs as PackedVector2Array)
	if bucket.has_color:
		var colors: Variant = node.get_meta("colors")
		if colors is PackedColorArray:
			bucket.colors.append_array(colors as PackedColorArray)


static func _mesh_from(bucket: Bucket) -> ArrayMesh:
	if bucket.verts.is_empty():
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = bucket.verts
	arrays[Mesh.ARRAY_NORMAL] = bucket.norms
	if bucket.has_uv and bucket.uvs.size() == bucket.verts.size():
		arrays[Mesh.ARRAY_TEX_UV] = bucket.uvs
	if bucket.has_color and bucket.colors.size() == bucket.verts.size():
		arrays[Mesh.ARRAY_COLOR] = bucket.colors
	var combined := ArrayMesh.new()
	combined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if bucket.material != null:
		combined.surface_set_material(0, bucket.material)
	return combined


static func _emit(zone: Node3D, bucket: Bucket, shown: bool) -> void:
	var mesh := _mesh_from(bucket)
	if mesh == null:
		return
	_instance(zone, mesh)
	zone.get_child(zone.get_child_count() - 1).visible = shown
