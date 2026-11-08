extends Node3D

## DistributedLevel.updateVisibility. The factory model has every room. The
## original stashes each zone except the one under the camera and the zones
## listed on that room. Front and side entrances use the same interior.

const _VIS := "res://assets/cog_hq/sellbot_factory_zones.json"
const _ELEVATOR := preload("res://scenes/cog_hq/factory_elevator.gd")
const _DOORS := preload("res://scenes/cog_hq/factory_doors.gd")
const _PROPS := preload("res://scenes/cog_hq/factory_props.gd")
const _BATCH := preload("res://scenes/playgrounds/street_batch.gd")
const _WALK := 1
const _SENSE := 2
const _ROOM_MIN := 1000.0
const _ROOM_MAX := 8000000.0

var _nodes: Dictionary = {}
var _boxes: Dictionary = {}
var _volumes: Dictionary = {}
var _vis: Dictionary = {}
var _bodies: Dictionary = {}
var _shown: Dictionary = {}
var _zone := -1


static func place(host: Node) -> void:
	if Engine.is_editor_hint() or host == null:
		return
	if host.scene_file_path.get_file() != "sellbot_factory.tscn":
		return
	if host.get_node_or_null("FactoryRooms") != null:
		return
	var script := load("res://scenes/cog_hq/factory_rooms.gd") as GDScript
	var node := script.new() as Node3D
	node.name = "FactoryRooms"
	host.add_child(node)


func _ready() -> void:
	process_priority = -100
	_load_vis()
	var host := get_parent()
	if host != null:
		_DOORS.place(host)
		_PROPS.place(host)
		_collect(host)
		_drop_empty(host)
	_arm_sensors()
	var start := 16 if int(_ELEVATOR.entrance) == 1 else 3
	_apply(start, start)


func _physics_process(_delta: float) -> void:
	var feet := _feet()
	var camera := get_viewport().get_camera_3d()
	var under := -1
	if feet != null:
		under = _sense(feet.global_position + Vector3(0.0, 3.0, 0.0), feet.global_position + Vector3(0.0, -20.0, 0.0))
	var looked := -1
	if camera != null:
		looked = _sense(camera.global_position, camera.global_position + Vector3(0.0, -80.0, 0.0))
	var zone := looked if looked >= 0 else under
	if zone < 0:
		zone = _zone
	if zone < 0:
		return
	var stood := under if under >= 0 else zone
	_apply(zone, stood)


## street_cog asks the neighborhood which rooms are drawn. A suit over a
## stashed zone stays on its path, but it does not draw.
func visible_at(at: Vector3) -> bool:
	var zone := _sense(at + Vector3(0.0, 4.0, 0.0), at + Vector3(0.0, -30.0, 0.0))
	if zone < 0:
		return false
	return _shown.has(zone)


func _apply(zone: int, stood: int) -> void:
	var shown := {}
	shown[zone] = true
	shown[stood] = true
	var listed: Array = _vis.get(str(zone), [])
	for item in listed:
		shown[int(item)] = true
	var feet := _feet()
	if feet != null:
		_include_rooms(feet.global_position, shown)
	if _same(shown, _shown) and zone == _zone:
		return
	for id in _nodes:
		var number := int(id)
		var want := shown.has(number)
		if _shown.has(number) == want and not _shown.is_empty():
			continue
		_show(number, want)
	_shown = shown
	_zone = zone


func _include_rooms(at: Vector3, shown: Dictionary) -> void:
	for id in _boxes:
		var number := int(id)
		if shown.has(number):
			continue
		var volume := float(_volumes[id])
		if volume < _ROOM_MIN or volume > _ROOM_MAX:
			continue
		var box: AABB = _boxes[id]
		if box.size.y < 2.0:
			continue
		if box.grow(2.0).has_point(at):
			shown[number] = true


func _show(zone: int, shown: bool) -> void:
	var node := _nodes.get(zone) as Node3D
	if node != null:
		if shown:
			_unstash_meshes(node)
		if node.visible != shown:
			node.visible = shown
		if not shown:
			_stash_meshes(node)
	# DistributedLevel.stash takes the room out of the scene. A hidden
	# MeshInstance is still walked, so the combined surfaces leave the tree.
	var layer := 0
	if shown:
		layer = _WALK | _SENSE
	for item in _bodies.get(zone, []):
		var body := item as CollisionObject3D
		if body == null:
			continue
		_use_shapes(body, shown)
		if body.collision_layer != layer:
			body.collision_layer = layer


func _stash_meshes(zone: Node3D) -> void:
	var held: Array = zone.get_meta("stashed_meshes", [])
	var take: Array[Node] = []
	_collect_props(zone, take)
	for child in take:
		var parent := child.get_parent()
		if parent == null:
			continue
		child.set_meta("stash_parent", parent)
		parent.remove_child(child)
		held.append(child)
	zone.set_meta("stashed_meshes", held)


func _collect_props(node: Node, take: Array[Node]) -> void:
	for child in node.get_children():
		var node_name := String(child.name)
		if _zone_number(node_name) >= 0:
			continue
		# A hidden MeshInstance is still walked. Doors and buttons leave with
		# the combined surfaces, and come back with the room.
		if node_name.begins_with("ZoneBatch") or node_name.begins_with("door-") or node_name.begins_with("button-"):
			take.append(child)
			continue
		_collect_props(child, take)


func _unstash_meshes(zone: Node3D) -> void:
	var held: Array = zone.get_meta("stashed_meshes", [])
	for item in held:
		var child := item as Node
		if child == null or not is_instance_valid(child) or child.get_parent() != null:
			continue
		var parent := child.get_meta("stash_parent") as Node
		if parent == null or not is_instance_valid(parent):
			parent = zone
		parent.add_child(child)
	zone.set_meta("stashed_meshes", [])


func _use_shapes(body: CollisionObject3D, shown: bool) -> void:
	var off := not shown
	for child in body.get_children():
		var shape := child as CollisionShape3D
		if shape != null and shape.disabled != off:
			shape.disabled = off


func _arm_sensors() -> void:
	for id in _nodes:
		_show(int(id), false)


func _sense(from: Vector3, to: Vector3) -> int:
	var world := get_world_3d()
	if world == null:
		return -1
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = _SENSE
	query.collide_with_areas = false
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return -1
	return _zone_of(hit.get("collider") as Node)


func _load_vis() -> void:
	if not FileAccess.file_exists(_VIS):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_VIS))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var records: Dictionary = parsed
	for key in records:
		var listed: Array = records[key]
		var ids: Array[int] = []
		for item in listed:
			ids.append(int(item))
		_vis[str(int(key))] = ids


func _collect(node: Node) -> void:
	var number := _zone_number(str(node.name))
	if number >= 0 and node is Node3D and not _nodes.has(number):
		var room := node as Node3D
		_nodes[number] = room
		_BATCH.flatten_room(room)
		_measure(room, number)
		var bodies: Array[CollisionObject3D] = []
		_collect_bodies(room, bodies)
		_bodies[number] = bodies
	for child in node.get_children():
		_collect(child)


func _measure(room: Node3D, zone: int) -> void:
	_merge(room, zone)
	if not _boxes.has(zone):
		return
	var box: AABB = _boxes[zone]
	_volumes[zone] = box.size.x * box.size.y * box.size.z


func _merge(node: Node3D, zone: int) -> void:
	for child in node.get_children():
		if not (child is Node3D):
			continue
		if _zone_number(str(child.name)) >= 0:
			continue
		var body := child as Node3D
		if body is MeshInstance3D and (body as MeshInstance3D).mesh != null:
			var piece := body.global_transform * (body as MeshInstance3D).get_aabb()
			if _boxes.has(zone):
				_boxes[zone] = (_boxes[zone] as AABB).merge(piece)
			else:
				_boxes[zone] = piece
		_merge(body, zone)


func _collect_bodies(node: Node, bodies: Array[CollisionObject3D]) -> void:
	if _zone_number(str(node.name)) >= 0 and bodies.size() > 0:
		return
	if node is CollisionObject3D:
		bodies.append(node as CollisionObject3D)
	for child in node.get_children():
		if _zone_number(str(child.name)) >= 0:
			continue
		_collect_bodies(child, bodies)


func _drop_empty(node: Node) -> void:
	var node_name := String(node.name)
	if node_name.begins_with("Factory") or node_name.begins_with("door-") or node_name.begins_with("button-"):
		return
	for child in node.get_children():
		_drop_empty(child)
	if node is MeshInstance3D and (node as MeshInstance3D).mesh == null and node.get_child_count() == 0 and node.get_parent() != null:
		node.free()


func _feet() -> Node3D:
	var host := get_parent()
	if host == null:
		return null
	return host.get_node_or_null("Player") as Node3D


func _zone_of(node: Node) -> int:
	var current := node
	while current != null:
		var number := _zone_number(str(current.name))
		if number >= 0:
			return number
		current = current.get_parent()
	return -1


func _same(next: Dictionary, previous: Dictionary) -> bool:
	if next.size() != previous.size():
		return false
	for key in next:
		if not previous.has(key):
			return false
	return true


static func _zone_number(node_name: String) -> int:
	if not node_name.begins_with("ZONE"):
		return -1
	var digits := ""
	for index in range(4, node_name.length()):
		var ch := node_name.substr(index, 1)
		if ch < "0" or ch > "9":
			break
		digits += ch
	if digits.is_empty():
		return -1
	return digits.to_int()
