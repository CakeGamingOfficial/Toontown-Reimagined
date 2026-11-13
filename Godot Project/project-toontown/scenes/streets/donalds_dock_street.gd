extends Node3D

## Donald's Dock street presentation the bind-pose export does not carry.
## The sky keeps the world's rotation and only follows the camera across the
## ground. Flat cards yaw to face the camera. Every street in the neighborhood
## loops the same street theme.

const MUSIC_PATH := "res://assets/neighborhoods/donalds_dock/audio/DD_SZ.ogg"
const MUSIC_VOLUME := 0.8

var _sky: Node3D
var _sky_height := 0.0
var _billboards: Array[Dictionary] = []
var _zones: Dictionary = {}
var _zone_nodes: Dictionary = {}
var _current_zone := ""
var _zone_sample := Vector2(INF, INF)


func _ready() -> void:
	_ready_music()
	_ready_sky()
	_ready_billboards()
	_close_hq_doors(self)
	preload("res://scenes/interiors/shop_door.gd").prepare(self)
	_ready_zones()
	# The whole dock used to stay in one mesh. Stash every block that is not
	# on the vis list for the sidewalk under the toon, same as the other streets.
	preload("res://scenes/playgrounds/playground_collision.gd").finish(self, false)
	preload("res://scenes/playgrounds/street_batch.gd").prepare(self, _zone_nodes, _zones)
	preload("res://scenes/playgrounds/fishing_spots.gd").place(self)
	if preload("res://scenes/playgrounds/playground_toon.gd").expects_avatar():
		preload("res://scenes/playgrounds/playground_toon.gd").attach(self)
	preload("res://scenes/streets/street_buildings.gd").attach(self)
	preload("res://scenes/streets/street_suits.gd").attach(self)
	preload("res://scenes/battle/street_fight.gd").attach(self)
	_current_zone = ""
	_zone_sample = Vector2(INF, INF)
	_process_zones(get_viewport().get_camera_3d())


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	_process_zones(camera)
	_process_sky(camera)
	_process_billboards(camera)


func _ready_music() -> void:
	# Street.enter loops TownLoader.music at 0.8. Donald's Dock streets all
	# use DD_SZ ("Donald's Dock Street").
	if not FileAccess.file_exists(MUSIC_PATH):
		return
	var stream := AudioStreamOggVorbis.load_from_file(MUSIC_PATH)
	if stream == null:
		return
	stream.loop = true
	var player := ToonAudio.music_player()
	player.name = "StreetMusic"
	player.stream = stream
	player.volume_db = linear_to_db(MUSIC_VOLUME)
	add_child(player)
	player.play()


func _ready_sky() -> void:
	_sky = _find_exact(self, "DDSky") as Node3D
	if _sky:
		_sky_height = _sky.global_position.y
		# The dome lives in one block. Leaving it there hides the sky whenever
		# that block is stashed.
		if _sky.get_parent() != self:
			var keep := _sky.global_transform
			_sky.reparent(self)
			_sky.global_transform = keep
		_sky.visible = true


func _process_sky(camera: Camera3D) -> void:
	# CompassEffect PRot|PZ: the dome follows the camera across the street
	# but keeps the world's rotation and height.
	if _sky and camera:
		var place := camera.global_position
		_sky.global_position = Vector3(place.x, _sky_height, place.z)


func _ready_billboards() -> void:
	_collect_billboards(self)


func _collect_billboards(node: Node) -> void:
	if node is Node3D and (node.is_in_group("tt_billboard") or String(node.name).contains("__billboard")):
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
	# The card is flat along local Y, and the visible winding faces -Y.
	var face := Vector3(-rest.y.x, 0.0, -rest.y.z)
	var to_target := target - node.global_position
	to_target.y = 0.0
	if face.length() < 0.0001 or to_target.length() < 0.0001:
		return
	var angle := face.signed_angle_to(to_target, Vector3.UP)
	if absf(angle_difference(float(node.get_meta(&"billboard_yaw", 999.0)), angle)) < 0.02:
		return
	node.set_meta(&"billboard_yaw", angle)
	var turned := node.global_transform
	turned.basis = rest.rotated(Vector3.UP, angle)
	node.global_transform = turned


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


func _close_hq_doors(node: Node) -> void:
	# The slabs are stored facing into the hull. Closed, they match the door
	# origin and the black frame holes stay hidden.
	var name := String(node.name)
	if name.begins_with("doorFrameHole"):
		node.visible = false
	elif (name.begins_with("leftDoor_") or name.begins_with("rightDoor_")) and node is Node3D:
		var index := name.get_slice("_", name.get_slice_count("_") - 1)
		var origin := _find_exact(self, "door_origin_" + index) as Node3D
		if origin:
			var placed := (node as Node3D).global_transform
			placed.basis = origin.global_transform.basis
			(node as Node3D).global_transform = placed
	for child in node.get_children():
		_close_hq_doors(child)


func _toon_feet() -> Node3D:
	var host := get_node_or_null("PlaygroundToon")
	if host != null:
		var body := host.get_node_or_null("Player") as Node3D
		if body != null:
			return body
	return get_node_or_null("Player") as Node3D


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


func _ready_zones() -> void:
	if not _zones.is_empty():
		return
	var scene_path := scene_file_path
	if scene_path.is_empty() and get_tree().current_scene:
		scene_path = get_tree().current_scene.scene_file_path
	var data_path := "res://assets/neighborhoods/donalds_dock/streets/%s_zones.json" % scene_path.get_file().get_basename()
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


func _collect_zone_nodes(node: Node) -> void:
	var node_name := String(node.name)
	if _zones.has(node_name) and node is Node3D:
		_zone_nodes[node_name] = node
	for child in node.get_children():
		_collect_zone_nodes(child)


func _process_zones(camera: Camera3D) -> void:
	if _zones.is_empty():
		return
	var player := _toon_feet()
	var sample := Vector2(INF, INF)
	if player != null:
		sample = Vector2(player.global_position.x, player.global_position.z)
	elif camera != null:
		sample = Vector2(camera.global_position.x, camera.global_position.z)
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


func _find_exact(node: Node, wanted: String) -> Node:
	if String(node.name) == wanted:
		return node
	for child in node.get_children():
		var found := _find_exact(child, wanted)
		if found:
			return found
	return null
