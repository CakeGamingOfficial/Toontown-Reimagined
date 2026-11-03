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

var _built := false
var _lawbot := false


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


func _on_street() -> bool:
	var host := get_parent()
	if host == null:
		return false
	return host.scene_file_path.contains("/streets/")


func _add_collision(node: Node) -> void:
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
	if faces.size() >= 3:
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
