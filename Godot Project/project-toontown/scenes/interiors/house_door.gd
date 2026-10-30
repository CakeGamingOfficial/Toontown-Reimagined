extends RefCounted

## DistributedHouse and DistributedHouseInterior hang door_double_round_ur on
## door_origin. House A has no door in the exported model, so that door is
## instanced here. Catalog houses already include theirs.
## Walking into the door uses DistributedDoor: the right panel swings +100
## and the left panel swings -100, then the other side of the door loads.

const DOOR_GLB := "res://assets/interiors/estate/house_door.glb"
const OPEN_SFX := "res://assets/interiors/hq/Door_Open_1.ogg"
const CLOSE_SFX := "res://assets/interiors/hq/Door_Close_1.ogg"
const _PANELS: Array[String] = ["leftDoor", "rightDoor", "doorFrameHoleRight", "doorFrameHoleLeft"]
## Wide enough to cover the round door. The slab is about five units across.
const OUTSIDE_REACH := 3.2


static func ensure_exterior(host: Node, slot: int) -> void:
	var house := find_house(host, slot)
	if house == null or _find_exact(house, "rightDoor") != null:
		return
	var origin := find_origin(house)
	if origin == null:
		# The second houseA lot lost its empty door_origin in the export.
		# houseA.bam places that marker at this local position.
		if find_anchor(house) != null:
			return
		origin = Node3D.new()
		origin.name = "door_origin"
		origin.position = Vector3(7.05265, -0.170105, 0.0)
		house.add_child(origin)
	var packed := load(DOOR_GLB) as PackedScene
	if packed == null:
		return
	var root := packed.instantiate()
	var door := _find_exact(root, "HouseDoor")
	if door == null:
		root.free()
		return
	var kept := door.transform
	door.reparent(origin)
	door.transform = kept
	door.name = "door_0"
	root.free()
	_collide(door)


static func find_house(host: Node, slot: int) -> Node3D:
	return _find_exact(host, "esHouse_%d" % clampi(slot, 0, 5))


static func find_origin(root: Node) -> Node3D:
	return _find_exact(root, "door_origin")


static func find_door(root: Node) -> Node3D:
	return _find_exact(root, "door_0")


## House A keeps a door_origin marker. Catalog houses only have the door mesh,
## named door_0, door_02, door_03, or door_04.
static func find_anchor(house: Node3D) -> Node3D:
	var origin := find_origin(house)
	if origin != null:
		return origin
	var best := {"node": null, "dist": 0.0}
	_farthest_door(house, house, best)
	return best["node"] as Node3D


static func _farthest_door(house: Node3D, node: Node, best: Dictionary) -> void:
	var node_name := str(node.name)
	if node != house and node is Node3D and node_name.begins_with("door_0"):
		var place := node as Node3D
		var dist := place.global_position.distance_squared_to(house.global_position)
		if best["node"] == null or dist > float(best["dist"]):
			best["node"] = place
			best["dist"] = dist
	for child in node.get_children():
		_farthest_door(house, child, best)


static func inside_drop(origin: Node3D) -> Dictionary:
	# avatarExitTrack's final point, doorX = 1.5, six units into the room.
	var point := origin.to_global(Vector3(-1.5, -6.0, 0.025))
	return {"point": point, "heading": _heading(point - origin.global_position)}


static func inside_trigger(origin: Node3D) -> Vector3:
	return origin.to_global(Vector3(-1.5, -2.2, 0.025))


static func outside_drop(house: Node3D, origin: Node3D) -> Dictionary:
	var point := _yard(house, origin, 6.0)
	return {"point": point, "heading": _heading(point - origin.global_position)}


static func outside_trigger(house: Node3D, origin: Node3D) -> Vector3:
	# The door is set back under the porch. A point 3.2 units out from the
	# marker sits in the yard, short of the doorway, so walking into the
	# door never enters it.
	return _in_front(house, origin, 1.0)


static func seal(root: Node) -> void:
	if root == null:
		return
	_seal_tree(root)


static func open(host: Node, door: Node3D) -> void:
	if door == null:
		return
	_sound(host, OPEN_SFX)
	var flat := _find_exact(door, "door_flat")
	if flat != null:
		flat.visible = false
	for part_name in _PANELS:
		var part := _find_exact(door, part_name)
		if part != null:
			part.visible = true
	_swing(host, _find_exact(door, "rightDoor"), 100.0)
	_swing(host, _find_exact(door, "leftDoor"), -100.0)


static func play_close(host: Node) -> void:
	_sound(host, CLOSE_SFX)


static func _yard(house: Node3D, origin: Node3D, distance: float) -> Vector3:
	var point := origin.global_position + _outward(house, origin) * distance
	point.y = origin.global_position.y
	return point


static func _in_front(house: Node3D, origin: Node3D, gap: float) -> Vector3:
	var point := _doorway(house, origin) + _outward(house, origin) * gap
	point.y = origin.global_position.y
	return point


static func _outward(house: Node3D, origin: Node3D) -> Vector3:
	var outward := origin.global_position - house.global_position
	outward.y = 0.0
	if outward.length_squared() < 0.0001:
		return Vector3(0.0, 0.0, 1.0)
	return outward.normalized()


## Center of the round door's slab, so the zone lines up with the opening.
static func _doorway(house: Node3D, origin: Node3D) -> Vector3:
	var door := find_door(house)
	if door == null:
		door = origin
	var flat := _find_exact(door, "door_flat")
	if flat is MeshInstance3D and (flat as MeshInstance3D).mesh != null:
		var mesh := flat as MeshInstance3D
		var box: AABB = mesh.global_transform * mesh.mesh.get_aabb()
		return box.get_center()
	return _mesh_center(door)


static func _mesh_center(node: Node3D) -> Vector3:
	var state := {"found": false, "box": AABB()}
	_merge_bounds(node, state)
	if not bool(state["found"]):
		return node.global_position
	var box: AABB = state["box"]
	return box.get_center()


static func _merge_bounds(node: Node, state: Dictionary) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh := node as MeshInstance3D
		var part: AABB = mesh.global_transform * mesh.mesh.get_aabb()
		if not bool(state["found"]):
			state["box"] = part
			state["found"] = true
		else:
			var box: AABB = state["box"]
			state["box"] = box.merge(part)
	for child in node.get_children():
		_merge_bounds(child, state)


static func _heading(dir: Vector3) -> float:
	var flat := dir
	flat.y = 0.0
	if flat.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(atan2(-flat.x, -flat.z))


static func _seal_tree(node: Node) -> void:
	if str(node.name) == "door_0":
		var flat := _find_exact(node, "door_flat")
		if flat != null:
			flat.visible = true
			for part_name in _PANELS:
				var part := _find_exact(node, part_name)
				if part != null:
					part.visible = false
		return
	for child in node.get_children():
		_seal_tree(child)


static func _swing(host: Node, panel: Node3D, degrees: float) -> void:
	if panel == null:
		return
	panel.visible = true
	if not panel.has_meta("closed_basis"):
		panel.set_meta("closed_basis", panel.transform.basis)
	var tween := host.create_tween()
	tween.tween_method(_set_swing.bind(panel), 0.0, degrees, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


static func _set_swing(degrees: float, panel: Node3D) -> void:
	if not is_instance_valid(panel) or not panel.has_meta("closed_basis"):
		return
	var closed: Basis = panel.get_meta("closed_basis")
	panel.transform.basis = Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(degrees)) * closed


static func _sound(host: Node, path: String) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var speaker := ToonAudio.effect_player()
	speaker.stream = stream
	speaker.volume_db = -4.0
	host.add_child(speaker)
	speaker.play()
	speaker.finished.connect(speaker.queue_free)


static func _collide(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var material := mesh.get_active_material(0)
		var solid := true
		if material is BaseMaterial3D:
			solid = (material as BaseMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
		if solid:
			mesh.create_trimesh_collision()
	for child in node.get_children():
		_collide(child)


static func _find_exact(node: Node, wanted: String) -> Node3D:
	if node == null:
		return null
	if node is Node3D and str(node.name) == wanted:
		return node as Node3D
	for child in node.get_children():
		var found := _find_exact(child, wanted)
		if found != null:
			return found
	return null
