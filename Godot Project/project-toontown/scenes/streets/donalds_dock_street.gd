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
	_ready_zones()
	_ready_billboards()
	_close_hq_doors(self)
	if preload("res://scenes/places/tunnel_links.gd").arriving():
		preload("res://scenes/playgrounds/playground_toon.gd").attach(self)
	preload("res://scenes/streets/street_suits.gd").attach(self)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	_process_sky(camera)
	_process_zones(camera)
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
		if not node.visible or not node.is_visible_in_tree():
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
	var turned := node.global_transform
	turned.basis = rest.rotated(Vector3.UP, face.signed_angle_to(to_target, Vector3.UP))
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
	_show_every_zone()


func _collect_zone_nodes(node: Node) -> void:
	var node_name := String(node.name)
	if _zones.has(node_name) and node is Node3D:
		_zone_nodes[node_name] = node
	for child in node.get_children():
		_collect_zone_nodes(child)


func _process_zones(camera: Camera3D) -> void:
	if camera == null or _zones.is_empty():
		return
	var sample := Vector2(camera.global_position.x, camera.global_position.z)
	if sample.distance_squared_to(_zone_sample) < 0.25 and _current_zone != "":
		return
	_zone_sample = sample
	var zone := _zone_at(sample)
	if zone.is_empty():
		zone = _nearest_zone(sample)
	if zone.is_empty() or zone == _current_zone:
		return
	_show_zone(zone)


func _show_zone(zone: String) -> void:
	_current_zone = zone
	var shown := {}
	for visible_name in _zones[zone]["vis"]:
		shown[String(visible_name)] = true
	shown[zone] = true
	for zone_name in _zone_nodes:
		(_zone_nodes[zone_name] as Node3D).visible = shown.has(zone_name)


func _show_every_zone() -> void:
	_current_zone = ""
	_zone_sample = Vector2(INF, INF)
	for zone_name in _zone_nodes:
		(_zone_nodes[zone_name] as Node3D).visible = true


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
		var polygons: Array = _zones[zone_name]["polygons"]
		for item in polygons:
			var polygon := item as PackedVector2Array
			if polygon.size() < 3:
				continue
			var distance := _polygon_distance(point, polygon)
			if distance < best_distance:
				best_distance = distance
				best = String(zone_name)
	return best


func _polygon_distance(point: Vector2, polygon: PackedVector2Array) -> float:
	if _contains(point, polygon):
		return 0.0
	var best := INF
	var previous := polygon.size() - 1
	for index in polygon.size():
		var distance := _segment_distance(point, polygon[previous], polygon[index])
		if distance < best:
			best = distance
		previous = index
	return best


func _segment_distance(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var edge := finish - start
	var length2 := edge.length_squared()
	if length2 < 0.0001:
		return point.distance_to(start)
	var along := clampf((point - start).dot(edge) / length2, 0.0, 1.0)
	return point.distance_to(start + edge * along)


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


func zone_visible_at(point: Vector3) -> bool:
	if _zone_nodes.is_empty():
		return true
	var flat := Vector2(point.x, point.z)
	var zone := _zone_at(flat)
	if zone.is_empty():
		zone = _nearest_zone(flat)
	if zone.is_empty():
		return true
	var node := _zone_nodes.get(zone) as Node3D
	if node == null:
		return true
	return node.visible


func _find_exact(node: Node, wanted: String) -> Node:
	if String(node.name) == wanted:
		return node
	for child in node.get_children():
		var found := _find_exact(child, wanted)
		if found:
			return found
	return null
