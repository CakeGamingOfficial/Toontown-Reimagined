@tool
extends Node3D

## Shared presentation for a playground or street exported from DNA.
## Streets of one playground pass the same sky_kind, so they share its sky.
## A zones_path turns on the original visgroup stash for that street.

const TOONTOWN_SKY := preload("res://scenes/sky/toontown_sky.gd")
const MUSIC_VOLUME := 0.8

@export var music_path := ""
@export var sky_kind := "tt"
@export var zones_path := ""

var _zones: Dictionary = {}
var _zone_nodes: Dictionary = {}
var _current_zone := ""
var _zone_sample := Vector2(INF, INF)
var _billboards: Array[Dictionary] = []


func _ready() -> void:
	TOONTOWN_SKY.ensure(self, sky_kind)
	_ready_zones()
	if Engine.is_editor_hint():
		return
	_ready_music()
	_ready_billboards()
	_attach_returning_toon()


func _attach_returning_toon() -> void:
	var places := preload("res://scenes/places/hood_places.gd")
	var links := preload("res://scenes/places/tunnel_links.gd")
	if places.hood_for_scene(scene_file_path) == 0 and not links.arriving():
		return
	preload("res://scenes/playgrounds/playground_toon.gd").attach(self)


func _process(_delta: float) -> void:
	TOONTOWN_SKY.ensure(self, sky_kind)
	var camera := _view_camera()
	_follow_cog_sky(camera)
	_process_zones(camera)
	if Engine.is_editor_hint():
		return
	_process_billboards(camera)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		TOONTOWN_SKY.restore_imported(self)
		_show_every_zone()
		var cog_sky := get_node_or_null("CogSky") as Node3D
		if cog_sky:
			cog_sky.position = Vector3.ZERO


func _follow_cog_sky(camera: Camera3D) -> void:
	# The cog backdrop is parented to the camera in the original game, with
	# its height and rotation locked. Here it keeps the camera's ground position.
	var cog_sky := get_node_or_null("CogSky") as Node3D
	if cog_sky == null or camera == null:
		return
	var placed := cog_sky.global_position
	placed.x = camera.global_position.x
	placed.z = camera.global_position.z
	cog_sky.global_position = placed


func _ready_music() -> void:
	if music_path.is_empty() or not FileAccess.file_exists(music_path):
		return
	var stream := AudioStreamOggVorbis.load_from_file(music_path)
	if stream == null:
		return
	stream.loop = true
	var player := AudioStreamPlayer.new()
	player.name = "NeighborhoodMusic"
	player.stream = stream
	player.volume_db = linear_to_db(MUSIC_VOLUME)
	add_child(player)
	player.play()


func _view_camera() -> Camera3D:
	if Engine.is_editor_hint():
		var editor := Engine.get_singleton("EditorInterface")
		if editor == null:
			return null
		var viewport := editor.call("get_editor_viewport_3d", 0) as Viewport
		if viewport == null:
			return null
		return viewport.get_camera_3d()
	var game_view := get_viewport()
	if game_view == null:
		return null
	return game_view.get_camera_3d()


func _ready_zones() -> void:
	if zones_path.is_empty() or not _zones.is_empty():
		return
	if not FileAccess.file_exists(zones_path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(zones_path))
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
		_zones[str(zone_name)] = {
			"vis": record.get("vis", []),
			"polygons": polygons,
			"areas": areas,
		}
	_collect_zone_nodes(self)
	_show_every_zone()
	_process_zones(_view_camera())


func _collect_zone_nodes(node: Node) -> void:
	var node_name := str(node.name)
	if _zones.has(node_name) and node is Node3D:
		_zone_nodes[node_name] = node
	for child in node.get_children():
		_collect_zone_nodes(child)


func _process_zones(camera: Camera3D) -> void:
	if camera == null or _zones.is_empty():
		return
	var sample := Vector2(camera.global_position.x, camera.global_position.z)
	if sample.distance_squared_to(_zone_sample) < 0.25:
		return
	_zone_sample = sample
	var zone := _zone_at(sample)
	if zone.is_empty():
		zone = _nearest_zone(sample)
	if zone.is_empty() or zone == _current_zone:
		return
	_current_zone = zone
	var shown := {}
	for visible_name in _zones[zone]["vis"]:
		shown[str(visible_name)] = true
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
	if node is Node3D and (node as Node3D).visible and (node.is_in_group("tt_billboard") or str(node.name).contains("__billboard")):
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
