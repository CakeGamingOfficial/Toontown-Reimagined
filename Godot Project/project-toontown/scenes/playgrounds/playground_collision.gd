extends Node3D

## Builds static trimesh collision from the opaque meshes.
## Leaf cards and the sky dome stay non-solid so they don't become invisible walls.
## Street blocks are baked first, in street_batch.gd, so a block is one solid
## instead of a few hundred. The street script calls finish() after it has
## closed doors and hidden the baked shadow cards.

const _BATCH := preload("res://scenes/playgrounds/street_batch.gd")
const _SOLIDS := "res://assets/neighborhoods/toontown_central/playground_solids.json"
const _WALL_THICK := 1.0
const _WALL_SPAN := 30.0
const _PIER_FLOOR := 0.2

var _built := false
var _lawbot := false
var _pet_record: Dictionary = {}
var _clothes_record: Dictionary = {}


static func finish(host: Node, flat: bool) -> void:
	if host.has_method("build_street"):
		host.call("build_street", flat)
	for child in host.get_children():
		finish(child, flat)


func _ready() -> void:
	if _on_street() and not Engine.is_editor_hint():
		return
	# Closed HQ doors are a painted flat. Hide the leaves before they become solid.
	var host := get_parent()
	if host != null:
		_lawbot = host.scene_file_path.get_file().begins_with("lawbot")
		preload("res://scenes/cog_hq/sellbot_doors.gd").place(host)
		preload("res://scenes/cog_hq/factory_floor.gd").place(host)
	_add_collision(self)
	_place_recorded_solids()
	_place_shells()


func build_street(flat: bool) -> void:
	if _built or not _on_street():
		return
	_built = true
	if flat:
		_BATCH.apply_flat(self)
	else:
		_BATCH.apply(self)
	_add_collision(self)
	_BATCH.sweep_empty(self)


func _factory_interior() -> bool:
	var host := get_parent()
	return host != null and host.scene_file_path.get_file() == "sellbot_factory.tscn"


func _on_street() -> bool:
	var host := get_parent()
	if host == null:
		return false
	return host.scene_file_path.contains("/streets/")


func _add_collision(node: Node) -> void:
	# The factory combines each zone into one solid. A trimesh on every pipe
	# is the frame-rate drop, so those bodies are never created.
	if _factory_interior():
		return
	if "sky" in node.name.to_lower():
		return
	if node is MeshInstance3D:
		_collide_mesh(node as MeshInstance3D)
	for child in node.get_children():
		_add_collision(child)


func _collide_mesh(mesh: MeshInstance3D) -> void:
	if not mesh.visible or mesh.mesh == null or mesh.has_meta("street_batched"):
		return
	# Shop and cog fronts get one solid from their wall triangles. A trimesh
	# on the door slab would close the opening the player has to walk up to.
	if _facade_piece(mesh):
		return
	# A flat-building wall is one quad. The concave triangle is thin enough
	# that the toon walks through it. A box along that quad is the solid.
	if not _on_street() and _flat_wall(mesh):
		_thicken_wall(mesh)
		return
	# Fishing piers over the pond are open slats. The trimesh drops the toon
	# through the deck, so the walkway gets the original floor polygon instead.
	if _pier_board(mesh):
		_solid_pier(mesh)
		return
	var material := mesh.get_active_material(0)
	var cutout := false
	if material is BaseMaterial3D:
		cutout = (material as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	# Party gates are masked cards. The tunnel, stairs, and signs still need to stop a toon.
	# Lawbot floors are translucent so the reflection shows through. They are still the floor.
	if cutout and not _party_piece(mesh) and not (_lawbot and _lawbot_floor(mesh)):
		return
	mesh.create_trimesh_collision()


func _facade_piece(mesh: MeshInstance3D) -> bool:
	var current: Node = mesh
	while current != null:
		var low := String(current.name).to_lower()
		if low.contains("toon_landmark") or low.contains("animated_building") or low.contains("suit_landmark"):
			return true
		current = current.get_parent()
	return false


func _lawbot_floor(mesh: MeshInstance3D) -> bool:
	var lower := str(mesh.name).to_lower()
	if lower.contains("shadow") or lower.contains("shad") or lower.contains("refl"):
		return false
	return lower.contains("floor") or lower.contains("ground")


## partyGate_TT and the other playground gates. Hats, clocks, and pole balls are
## flat cards. The walls, stairs, floor, and sign posts are the solid parts.
func _party_piece(mesh: MeshInstance3D) -> bool:
	var inside := false
	var current: Node = mesh
	while current != null:
		var name := str(current.name)
		var lower := name.to_lower()
		if name == "clock_flat" or lower.contains("billboard") or lower.contains("shadow"):
			return false
		if name == "partyGate_grp" or name == "partyGateSignGroup" or name.begins_with("prop_party_gate"):
			inside = true
		current = current.get_parent()
	if not inside:
		return false
	var leaf := str(mesh.name)
	return not leaf.begins_with("hatFlat") and not leaf.begins_with("hatTop")


## The landmark models ship with hidden collision the export skipped. The
## recorded solids are those polygons, in the landmark node's local space.
func _place_recorded_solids() -> void:
	if _on_street():
		return
	if not FileAccess.file_exists(_SOLIDS):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_SOLIDS))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var buildings: Dictionary = parsed
	_pet_record = _record(buildings, "sz22_toon_landmark_TT_pet_shop_DNARoot")
	_clothes_record = _record(buildings, "sz21_toon_landmark_TT_clothes_shop_DNARoot")
	for building_name in buildings.keys():
		var landmark := find_child(String(building_name), true, false) as Node3D
		if landmark == null or landmark.get_node_or_null("LandmarkSolid") != null:
			continue
		var record: Variant = buildings[building_name]
		if typeof(record) != TYPE_DICTIONARY:
			continue
		_add_recorded_solid(landmark, record)


func _add_recorded_solid(landmark: Node3D, record: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.name = "LandmarkSolid"
	body.collision_layer = 1
	body.collision_mask = 0
	var raw: Array = record.get("faces", [])
	var faces := PackedVector3Array()
	var index := 0
	while index + 2 < raw.size():
		faces.append(Vector3(float(raw[index]), float(raw[index + 1]), float(raw[index + 2])))
		index += 3
	if faces.size() >= 3 and _shop_landmark(String(landmark.name)):
		_thicken_faces(body, faces)
	elif faces.size() >= 3:
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
	var capsules: Array = record.get("capsules", [])
	for item in capsules:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var spec: Dictionary = item
		body.add_child(_capsule_shape(_point(spec.get("a")), _point(spec.get("b")), float(spec.get("r", 1.0))))
	if body.get_child_count() == 0:
		return
	landmark.add_child(body)


## Toon Hall, the library, the bank, the school, HQ, the clothes shop, and the
## pet shop. The recorded wall is one flat polygon, and a toon walks through it.
func _record(buildings: Dictionary, building_name: String) -> Dictionary:
	var record: Variant = buildings.get(building_name, {})
	if typeof(record) != TYPE_DICTIONARY:
		return {}
	return record


func _shop_landmark(node_name: String) -> bool:
	var low := node_name.to_lower()
	if not low.contains("toon_landmark"):
		return false
	return low.contains("toonhall") or low.contains("library") or low.contains("school_house") or low.contains("_bank") or low.contains("clothes_shop") or low.contains("pet_shop") or low.contains("hq")


## The same shops in the other playgrounds never had a recorded solid.
func _place_shells() -> void:
	if _on_street():
		return
	_walk_shells(self)


func _walk_shells(node: Node) -> void:
	if node is Node3D and _shop_landmark(String(node.name)) and node.get_node_or_null("LandmarkSolid") == null:
		var low := String(node.name).to_lower()
		if low.contains("pet_shop") and not _pet_record.is_empty():
			_add_recorded_solid(node as Node3D, _pet_record)
		elif low.contains("clothes_shop") and not _clothes_record.is_empty():
			_add_recorded_solid(node as Node3D, _clothes_record)
		else:
			_add_shell(node as Node3D)
		return
	for child in node.get_children():
		_walk_shells(child)


func _add_shell(landmark: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "LandmarkSolid"
	body.collision_layer = 1
	body.collision_mask = 0
	var into := landmark.global_transform.affine_inverse()
	var bag := {"faces": PackedVector3Array()}
	_collect_shell(landmark, landmark, into, body, bag)
	var faces: PackedVector3Array = bag["faces"]
	if faces.size() >= 3:
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
	if body.get_child_count() == 0:
		return
	landmark.add_child(body)


func _collect_shell(node: Node, landmark: Node3D, into: Transform3D, body: StaticBody3D, bag: Dictionary) -> void:
	if node != landmark and _skip_shell(node):
		return
	if node is MeshInstance3D and node != landmark:
		var mesh := node as MeshInstance3D
		if mesh.visible and mesh.mesh != null:
			var to_local := into * mesh.global_transform
			var floor := _floor_piece(String(mesh.name))
			for surface in mesh.mesh.get_surface_count():
				_shell_surface(mesh, surface, to_local, body, floor, bag)
	for child in node.get_children():
		_collect_shell(child, landmark, into, body, bag)


func _skip_shell(node: Node) -> bool:
	var low := String(node.name).to_lower()
	return low.contains("door") or low.contains("sign") or low.contains("billboard") or low.contains("decal") or low.contains("baseline") or low.contains("kelp") or low.contains("flag") or low.contains("pig") or low.contains("fish") or low.contains("telescope") or low.contains("periscope")


func _floor_piece(node_name: String) -> bool:
	var low := node_name.to_lower()
	return low.contains("porch") or low.contains("stair") or low.contains("stoop")


func _shell_surface(mesh: MeshInstance3D, surface: int, to_local: Transform3D, body: StaticBody3D, floor: bool, bag: Dictionary) -> void:
	var arrays: Array = mesh.mesh.surface_get_arrays(surface)
	var source: Variant = arrays[Mesh.ARRAY_VERTEX]
	if not (source is PackedVector3Array):
		return
	var verts := source as PackedVector3Array
	var ids := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		ids = arrays[Mesh.ARRAY_INDEX]
	var cursor := 0
	var limit := verts.size()
	if ids.size() >= 3:
		limit = ids.size()
	while cursor + 2 < limit:
		var i0 := cursor
		var i1 := cursor + 1
		var i2 := cursor + 2
		if ids.size() >= 3:
			i0 = ids[cursor]
			i1 = ids[cursor + 1]
			i2 = ids[cursor + 2]
		cursor += 3
		if i0 < 0 or i1 < 0 or i2 < 0 or i0 >= verts.size() or i1 >= verts.size() or i2 >= verts.size():
			continue
		var a := to_local * verts[i0]
		var b := to_local * verts[i1]
		var c := to_local * verts[i2]
		var cross := (b - a).cross(c - a)
		var span := cross.length()
		if span < 1.0:
			continue
		var normal := cross / span
		if not floor and absf(normal.y) > 0.72:
			continue
		var faces: PackedVector3Array = bag["faces"]
		faces.append(a)
		faces.append(b)
		faces.append(c)
		bag["faces"] = faces
		# A single flat quad does not stop a toon. Only the big wall faces need a box.
		if span >= 80.0:
			_add_slab(body, a, b, c, normal)


func _thicken_faces(body: StaticBody3D, faces: PackedVector3Array) -> void:
	var index := 0
	while index + 2 < faces.size():
		var a := faces[index]
		var b := faces[index + 1]
		var c := faces[index + 2]
		index += 3
		var cross := (b - a).cross(c - a)
		var span := cross.length()
		if span < 0.2:
			continue
		_add_slab(body, a, b, c, cross / span)


func _add_slab(body: StaticBody3D, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	var tangent := normal.cross(Vector3.UP)
	if tangent.length_squared() < 0.0001:
		tangent = normal.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent := tangent.cross(normal).normalized()
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var mid := 0.0
	for point in [a, b, c]:
		low = low.min(Vector2(point.dot(tangent), point.dot(bitangent)))
		high = high.max(Vector2(point.dot(tangent), point.dot(bitangent)))
		mid += point.dot(normal)
	mid /= 3.0
	var span := high - low
	if span.x < 0.15 or span.y < 0.15:
		return
	var shape := BoxShape3D.new()
	shape.size = Vector3(span.x, _WALL_THICK, span.y)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var basis := Basis()
	basis.x = tangent
	basis.y = normal
	basis.z = bitangent
	var center := tangent * ((low.x + high.x) * 0.5) + bitangent * ((low.y + high.y) * 0.5) + normal * mid
	collision.transform = Transform3D(basis, center)
	body.add_child(collision)


func _point(raw: Variant) -> Vector3:
	if typeof(raw) != TYPE_ARRAY:
		return Vector3.ZERO
	var values: Array = raw
	if values.size() < 3:
		return Vector3.ZERO
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _capsule_shape(a: Vector3, b: Vector3, radius: float) -> CollisionShape3D:
	var shape := CapsuleShape3D.new()
	var length := a.distance_to(b)
	shape.radius = radius
	shape.height = maxf(length + radius * 2.0, radius * 2.0 + 0.05)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var up := Vector3.UP
	if length > 0.001:
		up = (b - a) / length
	var side := up.cross(Vector3.FORWARD)
	if side.length_squared() < 0.0001:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	var basis := Basis()
	basis.x = side
	basis.y = up
	basis.z = side.cross(up).normalized()
	collision.transform = Transform3D(basis, (a + b) * 0.5)
	return collision


func _flat_wall(mesh: MeshInstance3D) -> bool:
	var low_name := String(mesh.name).to_lower()
	# wall_1 is the playground fence. One box around it would fill the safe zone.
	return low_name.begins_with("wall_") and low_name != "wall_1"


func _thicken_wall(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null or mesh.get_node_or_null("WallSolid") != null:
		return
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	var count := 0
	for surface in mesh.mesh.get_surface_count():
		var arrays: Array = mesh.mesh.surface_get_arrays(surface)
		var verts: Variant = arrays[Mesh.ARRAY_VERTEX]
		var points: PackedVector3Array = verts
		for point in points:
			low = low.min(point)
			high = high.max(point)
			count += 1
	if count == 0:
		return
	var span := high - low
	var axis := 0
	var thin := span.x
	if span.y < thin:
		thin = span.y
		axis = 1
	if span.z < thin:
		thin = span.z
		axis = 2
	var wide_a := span.y
	var wide_b := span.z
	if axis == 1:
		wide_a = span.x
		wide_b = span.z
	elif axis == 2:
		wide_a = span.x
		wide_b = span.y
	if thin > 0.25 or wide_a > _WALL_SPAN or wide_b > _WALL_SPAN or wide_a < 0.4 or wide_b < 0.4:
		return
	var size := span
	if axis == 0:
		size.x = _WALL_THICK
	elif axis == 1:
		size.y = _WALL_THICK
	else:
		size.z = _WALL_THICK
	var body := StaticBody3D.new()
	body.name = "WallSolid"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = (low + high) * 0.5
	body.add_child(collision)
	mesh.add_child(body)


func _pier_board(mesh: MeshInstance3D) -> bool:
	# Each dock copies the same pier. Godot names the later walkways board2,
	# board3, and board4. Only an exact "board" match left those docks as
	# open slats, so the toon fell through before the casting sphere.
	var leaf := String(mesh.name)
	if not leaf.begins_with("board"):
		return false
	var rest := leaf.substr("board".length())
	if rest != "" and not rest.is_valid_int():
		return false
	var current: Node = mesh.get_parent()
	while current != null:
		if String(current.name).begins_with("fishing_spot"):
			return true
		current = current.get_parent()
	return false


## piers_tt floor_collision is one polygon on the walkway. The model is Z-up,
## so that surface is local Z max. The bank slopes down under the planks. A
## box filled down through that slope is a wall. The thin top is the floor
## on every dock, including the copies named board2 and up.
func _solid_pier(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null or mesh.get_node_or_null("PierSolid") != null:
		return
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	var count := 0
	for surface in mesh.mesh.get_surface_count():
		var arrays: Array = mesh.mesh.surface_get_arrays(surface)
		var verts: Variant = arrays[Mesh.ARRAY_VERTEX]
		var points: PackedVector3Array = verts
		for point in points:
			low = low.min(point)
			high = high.max(point)
			count += 1
	if count == 0:
		return
	low.z = high.z - _PIER_FLOOR
	var body := StaticBody3D.new()
	body.name = "PierSolid"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = high - low
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = (low + high) * 0.5
	body.add_child(collision)
	mesh.add_child(body)
