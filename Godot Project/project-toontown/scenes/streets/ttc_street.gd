@tool
extends Node3D

## Shared motion for the three Toontown Central streets. The bind-pose export
## already has the blocks, sidewalks, and doors. The sky is the shared Toontown
## dome. Flat cards yaw, and a closed landmark door keeps its painted flat.
##
## Street.doEnterZone only draws the visgroups listed for the floor cell under
## the avatar. Everything else is stashed, which is why a roof from the next
## block never shows up in the block you are standing in.

const MUSIC_PATH := "res://assets/neighborhoods/toontown_central/audio/TC_SZ.mp3"
const MUSIC_VOLUME := 0.8
const TOONTOWN_SKY := preload("res://scenes/sky/toontown_sky.gd")

var _billboards: Array[Dictionary] = []
var _zones: Dictionary = {}
var _zone_nodes: Dictionary = {}
var _current_zone := ""
var _zone_sample := Vector2(INF, INF)
var _shadow_passes := 0


func _ready() -> void:
	_hide_baked_shadows(self)
	TOONTOWN_SKY.ensure(self)
	_ready_zones()
	if Engine.is_editor_hint():
		return
	_ready_music()
	_close_flat_doors(self)
	_ready_billboards()
	# Measure doorways while the wall meshes still exist. Batching clears them.
	preload("res://scenes/interiors/shop_door.gd").prepare(self)
	# The pond hedge mesh is cleared by the street batch, so the wall and the
	# leaf cutout have to be in place before that.
	_raise_pond_hedge()
	preload("res://scenes/playgrounds/playground_collision.gd").finish(self, false)
	preload("res://scenes/playgrounds/street_batch.gd").prepare(self, _zone_nodes, _zones)
	preload("res://scenes/playgrounds/fishing_spots.gd").place(self)
	if preload("res://scenes/places/tunnel_links.gd").arriving() or preload("res://scenes/interiors/shop_door.gd").trip == "out" or preload("res://scenes/playgrounds/playground_toon.gd").reload_resume():
		preload("res://scenes/playgrounds/playground_toon.gd").attach(self)
	preload("res://scenes/streets/street_buildings.gd").attach(self)
	preload("res://scenes/streets/street_suits.gd").attach(self)
	preload("res://scenes/battle/street_fight.gd").attach(self)
	# The fly camera picked the first block. Settle on the toon before physics.
	_current_zone = ""
	_zone_sample = Vector2(INF, INF)
	_process_zones(_view_camera())


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_show_every_zone()
		_show_baked_shadows(self)
		TOONTOWN_SKY.restore_imported(self)


func _hide_baked_shadows(node: Node) -> void:
	# The marquee's drop-shadow card shares a mesh with the sign's left,
	# bottom, and right faces. Hide that card only. The tunnel's black end
	# wall stays; the shaft in front of it is painted one color.
	if node is MeshInstance3D and _marquee_shadow(node):
		_hide_marquee_shadow_card(node as MeshInstance3D)
	if node is MeshInstance3D and _tunnel_shaft(node):
		_fix_tunnel_shaft(node as MeshInstance3D)
	for child in node.get_children():
		_hide_baked_shadows(child)


func _hide_marquee_shadow_card(mesh_instance: MeshInstance3D) -> void:
	var mesh := mesh_instance.mesh
	if mesh == null:
		return
	for surface in mesh.get_surface_count():
		var material := mesh_instance.get_active_material(surface) as StandardMaterial3D
		if material == null or material.albedo_color.a > 0.9:
			continue
		var hidden := material.duplicate() as StandardMaterial3D
		hidden.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hidden.albedo_color.a = 0.0
		hidden.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mesh_instance.set_surface_override_material(surface, hidden)


func _tunnel_shaft(node: Node) -> bool:
	var node_name := String(node.name)
	return node_name.begins_with("s_tunnel") or node_name.begins_with("tunnel_")


func _fix_tunnel_shaft(mesh_instance: MeshInstance3D) -> void:
	# Black vertices on the far rim fade the last span of wall, ceiling, and
	# floor. The entrance pieces are a flat color, so that fade reads as a
	# hard line across the shaft. Paint the rim to match, and leave the
	# untextured black quad in place. That quad is the end wall.
	_clear_tunnel_vertex_shadow(mesh_instance)
	_use_linear_tunnel_colors(mesh_instance)


func _use_linear_tunnel_colors(mesh_instance: MeshInstance3D) -> void:
	# The glTF colors are the linear tint. Decoding them as sRGB knocks the
	# shaft down to a darker yellow than the flat-colored entrance.
	var mesh := mesh_instance.mesh
	if mesh == null:
		return
	for surface in mesh.get_surface_count():
		var material := mesh_instance.get_active_material(surface) as StandardMaterial3D
		if material == null or not material.vertex_color_is_srgb:
			continue
		var matched := material.duplicate() as StandardMaterial3D
		matched.vertex_color_is_srgb = false
		mesh_instance.set_surface_override_material(surface, matched)


func _clear_tunnel_vertex_shadow(mesh_instance: MeshInstance3D) -> void:
	var mesh := mesh_instance.mesh as ArrayMesh
	if mesh == null:
		return
	var fill := Color(1, 1, 1, 1)
	var found_fill := false
	var needs := false
	for surface in mesh.get_surface_count():
		var colors := _surface_colors(mesh, surface)
		for color in colors:
			if color.r > 0.05 or color.g > 0.05 or color.b > 0.05:
				if not found_fill:
					fill = color
					found_fill = true
			elif color.a > 0.5:
				needs = true
	if not needs:
		return
	var rebuilt := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var colors := _surface_colors(mesh, surface)
		for index in colors.size():
			var color := colors[index]
			if color.a > 0.5 and color.r <= 0.05 and color.g <= 0.05 and color.b <= 0.05:
				colors[index] = fill
		if not colors.is_empty():
			arrays[Mesh.ARRAY_COLOR] = colors
		rebuilt.add_surface_from_arrays(mesh.surface_get_primitive_type(surface), arrays)
		rebuilt.surface_set_material(surface, mesh.surface_get_material(surface))
	mesh_instance.mesh = rebuilt


func _surface_colors(mesh: ArrayMesh, surface: int) -> PackedColorArray:
	# The black quad has no color array. Casting that null value throws and
	# stops the street from running.
	var colors = mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
	if colors is PackedColorArray:
		return colors
	return PackedColorArray()


func _show_baked_shadows(node: Node) -> void:
	if _marquee_shadow(node):
		node.visible = true
	for child in node.get_children():
		_show_baked_shadows(child)


func _marquee_shadow(node: Node) -> bool:
	if not String(node.name).begins_with("square_drop_shadow"):
		return false
	var current := node.get_parent()
	while current:
		if String(current.name).contains("marquee"):
			return true
		current = current.get_parent()
	return false


func _ready_music() -> void:
	# Street.enter loops TownLoader.music at 0.8. Toontown Central's street
	# track is TC_SZ ("Strolling Along").
	if not ResourceLoader.exists(MUSIC_PATH):
		return
	var stream := load(MUSIC_PATH) as AudioStreamMP3
	if stream == null:
		return
	stream = stream.duplicate() as AudioStreamMP3
	stream.loop = true
	var player := ToonAudio.music_player()
	player.name = "StreetMusic"
	player.stream = stream
	player.volume_db = linear_to_db(MUSIC_VOLUME)
	add_child(player)
	player.play()


func _process(delta: float) -> void:
	if _zones.is_empty():
		_ready_zones()
	if _shadow_passes < 8:
		_shadow_passes += 1
		# The editor clears surface overrides after _ready. Put the tunnel
		# shaft color and the marquee shadow card back.
		_hide_baked_shadows(self)
	TOONTOWN_SKY.ensure(self)
	var camera := _view_camera()
	_process_zones(camera)
	if Engine.is_editor_hint():
		return
	_process_billboards(camera)


func _focus_sample(camera: Camera3D) -> Vector2:
	# The camera sits behind the toon and can hang off the sidewalk cell.
	# The cell under the toon is the one that has to stay solid.
	var player := _toon_feet()
	if player != null:
		return Vector2(player.global_position.x, player.global_position.z)
	if camera == null:
		return Vector2(INF, INF)
	return Vector2(camera.global_position.x, camera.global_position.z)


func _toon_feet() -> Node3D:
	var host := get_node_or_null("PlaygroundToon")
	if host != null:
		var body := host.get_node_or_null("Player") as Node3D
		if body != null:
			return body
	return get_node_or_null("Player") as Node3D


## Suits and cog towers are not children of the visgroup, so they ask the street
## whether this point is on a block that is currently drawn.
func zone_visible_at(at: Vector3) -> bool:
	var shown: Variant = get_meta("street_shown", {})
	if _zones.is_empty() or not (shown is Dictionary) or (shown as Dictionary).is_empty():
		return true
	var live: Dictionary = shown
	var point := Vector2(at.x, at.z)
	var inside := false
	for zone_name in _zones:
		var zone: Dictionary = _zones[zone_name]
		var polygons: Array = zone["polygons"]
		for polygon in polygons:
			if not _contains(point, polygon):
				continue
			inside = true
			if live.has(String(zone_name)):
				return true
	return not inside


func _view_camera() -> Camera3D:
	if Engine.is_editor_hint():
		var editor := Engine.get_singleton("EditorInterface")
		if editor == null:
			return null
		var viewport := editor.call("get_editor_viewport_3d", 0) as Viewport
		if viewport:
			return viewport.get_camera_3d()
		return null
	var viewport := get_viewport()
	if viewport == null:
		return null
	return viewport.get_camera_3d()


func _ready_zones() -> void:
	if not _zones.is_empty():
		return
	var scene_path := scene_file_path
	if scene_path.is_empty() and get_tree().current_scene:
		scene_path = get_tree().current_scene.scene_file_path
	var data_path := "res://assets/neighborhoods/toontown_central/streets/%s_zones.json" % scene_path.get_file().get_basename()
	if not FileAccess.file_exists(data_path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for zone_name in parsed:
		var record: Dictionary = parsed[zone_name]
		var polygons: Array[PackedVector2Array] = []
		var areas: Array[float] = []
		for source in record.get("polygons", []):
			var polygon := PackedVector2Array()
			for point in source:
				polygon.append(Vector2(float(point[0]), float(point[1])))
			if polygon.size() >= 3:
				polygons.append(polygon)
				areas.append(_polygon_area(polygon))
		_zones[String(zone_name)] = {
			"vis": record.get("vis", []),
			"polygons": polygons,
			"areas": areas,
		}
	_collect_zone_nodes(self)
	_show_every_zone()
	_process_zones(_view_camera())


func _collect_zone_nodes(node: Node) -> void:
	var node_name := String(node.name)
	if _zones.has(node_name) and node is Node3D:
		_zone_nodes[node_name] = node
	for child in node.get_children():
		_collect_zone_nodes(child)


func _process_zones(camera: Camera3D) -> void:
	if _zones.is_empty():
		return
	var sample := _focus_sample(camera)
	if is_inf(sample.x):
		return
	if sample.distance_squared_to(_zone_sample) < 0.25:
		return
	_zone_sample = sample
	var zone := _zone_at(sample)
	if zone.is_empty():
		zone = _nearest_zone(sample)
	if zone.is_empty() or zone == _current_zone:
		return
	_current_zone = zone
	preload("res://scenes/playgrounds/street_batch.gd").apply_visible(self, zone, _zone_nodes, _zones)


func _show_every_zone() -> void:
	_current_zone = ""
	_zone_sample = Vector2(INF, INF)
	if has_meta("street_shown"):
		remove_meta("street_shown")
	for zone_name in _zone_nodes:
		var zone_node := _zone_nodes[zone_name] as Node3D
		zone_node.visible = true
		preload("res://scenes/playgrounds/street_batch.gd").set_solid(zone_node, true)


func _zone_at(point: Vector2) -> String:
	var best := ""
	var best_area := INF
	for zone_name in _zones:
		var zone: Dictionary = _zones[zone_name]
		var polygons: Array = zone["polygons"]
		var areas: Array = zone["areas"]
		for index in polygons.size():
			var area := float(areas[index])
			if area < best_area and _contains(point, polygons[index] as PackedVector2Array):
				best = zone_name
				best_area = area
	return best


func _nearest_zone(point: Vector2) -> String:
	var best := ""
	var best_distance := INF
	for zone_name in _zones:
		for polygon in _zones[zone_name]["polygons"]:
			var center := Vector2.ZERO
			for vertex in polygon:
				center += vertex
			center /= float(polygon.size())
			var distance := center.distance_squared_to(point)
			if distance < best_distance:
				best_distance = distance
				best = zone_name
	return best


func _contains(point: Vector2, polygon: PackedVector2Array) -> bool:
	var inside := false
	var previous := polygon.size() - 1
	for index in polygon.size():
		var current := polygon[index]
		var earlier := polygon[previous]
		var crosses := (current.y > point.y) != (earlier.y > point.y)
		if crosses and point.x < (earlier.x - current.x) * (point.y - current.y) / (earlier.y - current.y) + current.x:
			inside = not inside
		previous = index
	return inside


func _polygon_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	var previous := polygon.size() - 1
	for index in polygon.size():
		var current := polygon[index]
		var earlier := polygon[previous]
		area += earlier.x * current.y - current.x * earlier.y
		previous = index
	return absf(area) * 0.5


func _ready_billboards() -> void:
	_collect_billboards(self)


func _collect_billboards(node: Node) -> void:
	if node is Node3D and (node as Node3D).visible and (node.is_in_group("tt_billboard") or String(node.name).contains("__billboard")):
		_billboards.append({"node": node, "rest": (node as Node3D).global_transform.basis})
		if node is MeshInstance3D:
			_show_both_sides(node as MeshInstance3D)
	for child in node.get_children():
		_collect_billboards(child)


func _process_billboards(camera: Camera3D) -> void:
	if camera == null:
		return
	for item in _billboards:
		var node := item["node"] as Node3D
		if node == null or not is_instance_valid(node) or not node.is_visible_in_tree():
			continue
		var rest := item["rest"] as Basis
		_yaw_toward(node, rest, camera.global_position)


func _yaw_toward(node: Node3D, rest: Basis, target: Vector3) -> void:
	var face := Vector3(-rest.y.x, 0.0, -rest.y.z)
	var to_target := target - node.global_position
	to_target.y = 0.0
	if face.length() < 0.0001 or to_target.length() < 0.0001:
		return
	var turned := node.global_transform
	turned.basis = rest.rotated(Vector3.UP, face.signed_angle_to(to_target, Vector3.UP))
	node.global_transform = turned


func _close_flat_doors(node: Node) -> void:
	# Landmark doors such as the library keep a painted flat while closed.
	# Shop doors are ordinary swinging leaves, so they stay as exported.
	var has_flat := false
	for child in node.get_children():
		if String(child.name).begins_with("door_flat"):
			has_flat = true
			break
	if has_flat:
		_hide_open_parts(node)
	for child in node.get_children():
		_close_flat_doors(child)


func _hide_open_parts(node: Node) -> void:
	for child in node.get_children():
		var child_name := String(child.name)
		if child_name.begins_with("doorFrameHole") or child_name.begins_with("leftDoor") or child_name.begins_with("rightDoor"):
			child.visible = false
		elif child_name.begins_with("door_flat"):
			_show_flat(child)
		else:
			_hide_open_parts(child)


func _show_flat(node: Node) -> void:
	if node is MeshInstance3D:
		_show_both_sides(node as MeshInstance3D)
	for child in node.get_children():
		if String(child.name).begins_with("doorFrameHole"):
			child.visible = false
		else:
			_show_flat(child)


func _show_both_sides(mesh_instance: MeshInstance3D) -> void:
	var mesh := mesh_instance.mesh
	if mesh == null:
		return
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface)
		if material is StandardMaterial3D:
			var standard := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
			standard.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.surface_set_material(surface, standard)


## The leafy hedge around Loopy Lane's pond is a 4-foot card. The original
## collision wall on that same line is 15 feet tall, so a jump cannot clear it.
const _POND_HEDGE_HEIGHT := 15.0
const _POND_HEDGE_THICK := 1.6


func _raise_pond_hedge() -> void:
	if not scene_file_path.ends_with("loopy_lane.tscn"):
		return
	var fence := find_child("TTpd_fence", true, false) as Node3D
	if fence == null:
		return
	# The leaf map is blended, so the pond and the far hedge draw through it.
	# A cutout writes depth and the holes in the leaves stay open.
	_cut_pond_hedge(fence)
	if fence.get_node_or_null("PondHedge") != null:
		return
	var up := _fence_up(fence)
	var edges: Array[Dictionary] = []
	_collect_pond_edges(fence, fence.global_transform.affine_inverse(), up, edges)
	var body := StaticBody3D.new()
	body.name = "PondHedge"
	body.collision_layer = 1
	body.collision_mask = 0
	for edge in edges:
		var shape := _pond_edge_box(edge["a"], edge["b"], up)
		if shape != null:
			body.add_child(shape)
	if body.get_child_count() == 0:
		return
	fence.add_child(body)


func _cut_pond_hedge(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null:
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_active_material(surface)
				if material is StandardMaterial3D:
					var standard := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
					standard.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					standard.alpha_scissor_threshold = 0.5
					standard.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
					standard.cull_mode = BaseMaterial3D.CULL_DISABLED
					mesh.set_surface_override_material(surface, standard)
	for child in node.get_children():
		_cut_pond_hedge(child)


func _fence_up(fence: Node3D) -> Vector3:
	var basis := fence.global_transform.basis
	var best := Vector3(0.0, 0.0, 1.0)
	var score := -1.0
	var axes: Array[Vector3] = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]
	for axis in axes:
		var world: Vector3 = basis * axis
		var amount := absf(world.dot(Vector3.UP))
		if amount > score:
			score = amount
			best = axis if world.dot(Vector3.UP) >= 0.0 else -axis
	return best


func _collect_pond_edges(node: Node, into_fence: Transform3D, up: Vector3, edges: Array[Dictionary]) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null:
			var to_fence := into_fence * mesh.global_transform
			var seen := {}
			for surface in mesh.mesh.get_surface_count():
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
				var ids := PackedInt32Array()
				if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
					ids = arrays[Mesh.ARRAY_INDEX]
				var limit := ids.size() if ids.size() >= 3 else verts.size()
				var cursor := 0
				while cursor + 2 < limit:
					var i0 := cursor
					var i1 := cursor + 1
					var i2 := cursor + 2
					if ids.size() >= 3:
						i0 = ids[cursor]
						i1 = ids[cursor + 1]
						i2 = ids[cursor + 2]
					if i0 >= 0 and i1 >= 0 and i2 >= 0 and i0 < verts.size() and i1 < verts.size() and i2 < verts.size():
						var a := to_fence * verts[i0]
						var b := to_fence * verts[i1]
						var c := to_fence * verts[i2]
						_keep_pond_base(edges, seen, a, b, c, up)
						_keep_pond_base(edges, seen, b, c, a, up)
						_keep_pond_base(edges, seen, c, a, b, up)
					cursor += 3
	for child in node.get_children():
		_collect_pond_edges(child, into_fence, up, edges)


func _keep_pond_base(edges: Array[Dictionary], seen: Dictionary, a: Vector3, b: Vector3, other: Vector3, up: Vector3) -> void:
	var ua := a.dot(up)
	var ub := b.dot(up)
	# The foot of the card. The top edge is the same line, raised.
	if absf(ua - ub) > 0.35:
		return
	if other.dot(up) < minf(ua, ub) + 0.2:
		return
	var flat := b - a
	flat = flat - up * flat.dot(up)
	if flat.length() < 0.5:
		return
	var key := _pond_edge_key(a, b)
	if seen.has(key):
		return
	seen[key] = true
	edges.append({"a": a, "b": b})


func _pond_edge_key(a: Vector3, b: Vector3) -> String:
	var ak := Vector3i(roundi(a.x * 20.0), roundi(a.y * 20.0), roundi(a.z * 20.0))
	var bk := Vector3i(roundi(b.x * 20.0), roundi(b.y * 20.0), roundi(b.z * 20.0))
	if ak.x > bk.x or (ak.x == bk.x and (ak.y > bk.y or (ak.y == bk.y and ak.z > bk.z))):
		var swap := ak
		ak = bk
		bk = swap
	return "%s|%s" % [ak, bk]


func _pond_edge_box(a: Vector3, b: Vector3, up: Vector3) -> CollisionShape3D:
	var along := b - a
	along = along - up * along.dot(up)
	var length := along.length()
	if length < 0.5:
		return null
	var tangent := along / length
	var normal := up.cross(tangent)
	if normal.length_squared() < 0.0001:
		return null
	normal = normal.normalized()
	var base := minf(a.dot(up), b.dot(up))
	var mid := (a + b) * 0.5
	mid = mid + up * ((base + _POND_HEDGE_HEIGHT * 0.5) - mid.dot(up))
	var box := BoxShape3D.new()
	# A short overlap at each end closes the crack where two cards meet.
	box.size = Vector3(length + 0.4, _POND_HEDGE_HEIGHT, _POND_HEDGE_THICK)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.transform = Transform3D(Basis(tangent, up, normal), mid)
	return shape
