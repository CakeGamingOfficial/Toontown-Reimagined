@tool
extends Node3D

## Shared presentation for a playground or street exported from DNA.
## Streets of one playground pass the same sky_kind, so they share its sky.
## A zones_path turns on the original visgroup stash for that street.

const TOONTOWN_SKY := preload("res://scenes/sky/toontown_sky.gd")
const _FIREWORK_SHOW := preload("res://scenes/effects/firework_show.gd")
const _BACKDROP := preload("res://scenes/sky/cog_backdrop.gdshader")
const _DOORS := preload("res://scenes/interiors/house_door.gd")
const _PLACES := preload("res://scenes/places/hood_places.gd")
const MUSIC_VOLUME := 0.8

@export var music_path := ""
@export var sky_kind := "tt"
@export var zones_path := ""
# Pick a Toon slot that owns this estate. -1 keeps every house lot.
@export var estate_slot := -1

var _zones: Dictionary = {}
var _zone_nodes: Dictionary = {}
var _current_zone := ""
var _zone_sample := Vector2(INF, INF)
var _billboards: Array[Dictionary] = []


func _ready() -> void:
	TOONTOWN_SKY.ensure(self, sky_kind)
	_ready_zones()
	_prepare_cog_sky()
	if Engine.is_editor_hint():
		return
	if scene_file_path.ends_with("cashbot_trainyard.tscn"):
		preload("res://scenes/cog_hq/cashbot_trains.gd").place(self)
	if scene_file_path.ends_with("bossbot_country_club.tscn"):
		preload("res://scenes/cog_hq/bossbot_karts.gd").place(self)
	preload("res://scenes/cog_hq/bossbot_doors.gd").place(self)
	preload("res://scenes/cog_hq/lawbot_doors.gd").place(self)
	preload("res://scenes/cog_hq/sellbot_hq_doors.gd").place(self)
	if estate_slot >= 0:
		_keep_estate_house(estate_slot)
		_DOORS.ensure_exterior(self, estate_slot)
		var house := _DOORS.find_house(self, estate_slot)
		if house != null:
			_DOORS.seal(house)
	elif _PLACES.is_house(scene_file_path):
		_DOORS.seal(self)
	_ready_music()
	_ready_billboards()
	preload("res://scenes/places/tunnel_links.gd").name_hq_exits(self)
	preload("res://scenes/cog_hq/sellbot_signs.gd").place(self)
	if preload("res://scenes/interiors/shop_door.gd").street_zone(scene_file_path) != 0:
		preload("res://scenes/interiors/shop_door.gd").prepare(self)
	preload("res://scenes/playgrounds/playground_collision.gd").finish(self, false)
	if scene_file_path.ends_with("daisy_gardens.tscn"):
		preload("res://scenes/playgrounds/playground_butterflies.gd").place(self)
	if estate_slot >= 0:
		preload("res://scenes/estate/garden_plots.gd").place(self, estate_slot)
	if scene_file_path.ends_with("party_grounds.tscn"):
		preload("res://scenes/parties/toon_party.gd").place_grounds(self)
	preload("res://scenes/playgrounds/street_batch.gd").prepare(self, _zone_nodes, _zones)
	preload("res://scenes/playgrounds/fishing_spots.gd").place(self)
	if scene_file_path.ends_with("goofy_speedway.tscn"):
		preload("res://scenes/racing/speedway_racing.gd").place(self)
	preload("res://scenes/parties/toon_party.gd").place_gate(self)
	preload("res://scenes/playgrounds/party_people.gd").place(self)
	_ready_playground_treasures()
	_attach_returning_toon()
	preload("res://scenes/cog_hq/factory_rooms.gd").place(self)
	preload("res://scenes/streets/street_buildings.gd").attach(self)
	preload("res://scenes/streets/street_suits.gd").attach(self)
	preload("res://scenes/battle/street_fight.gd").attach(self)
	_current_zone = ""
	_zone_sample = Vector2(INF, INF)
	_process_zones(_view_camera())


func _keep_estate_house(slot: int) -> void:
	# EstateLoader.loadHouses builds six lots. A toon's own estate keeps the
	# lot at HouseGlobals.houseDrops[slot] and leaves the others empty.
	var kept := "esHouse_%d" % clampi(slot, 0, 5)
	var extra: Array[Node] = []
	_collect_other_houses(self, kept, extra)
	for house in extra:
		house.free()


func _collect_other_houses(node: Node, kept: String, extra: Array[Node]) -> void:
	for child in node.get_children():
		if str(child.name).begins_with("esHouse_") and str(child.name) != kept:
			extra.append(child)
		else:
			_collect_other_houses(child, kept, extra)


func _ready_playground_treasures() -> void:
	var file := scene_file_path.get_file()
	var playground := ""
	if file == "daisy_gardens.tscn":
		playground = "dg"
	elif file == "minnies_melodyland.tscn":
		playground = "mm"
	elif file == "the_burrrgh.tscn":
		playground = "br"
	elif file == "donalds_dreamland.tscn":
		playground = "dl"
	if playground == "":
		return
	preload("res://scenes/playgrounds/playground_treasures.gd").attach(self, playground)


func _attach_returning_toon() -> void:
	var places := preload("res://scenes/places/hood_places.gd")
	var toon := preload("res://scenes/playgrounds/playground_toon.gd")
	var factory := preload("res://scenes/cog_hq/factory_elevator.gd")
	factory.place(self)
	preload("res://scenes/cog_hq/mint_elevator.gd").place(self)
	preload("res://scenes/cog_hq/mint_floor.gd").place(self)
	preload("res://scenes/cog_hq/factory_cogs.gd").place(self)
	preload("res://scenes/cog_hq/mint_cogs.gd").place(self)
	preload("res://scenes/cog_hq/mint_props.gd").place(self)
	preload("res://scenes/cog_hq/office_floor.gd").place(self)
	preload("res://scenes/cog_hq/office_elevator.gd").place(self)
	preload("res://scenes/cog_hq/office_cogs.gd").place(self)
	preload("res://scenes/cog_hq/office_puzzles.gd").place(self)
	preload("res://scenes/cog_hq/course_floor.gd").place(self)
	preload("res://scenes/cog_hq/course_kart.gd").place(self)
	preload("res://scenes/cog_hq/course_cogs.gd").place(self)
	preload("res://scenes/cog_hq/course_puzzles.gd").place(self)
	preload("res://scenes/cog_hq/boss_gate.gd").place(self)
	preload("res://scenes/cog_hq/dept_boss.gd").place(self)
	# A playground always has someone to walk. A street does too when a door,
	# a tunnel, or a factory car is bringing them back.
	if places.hood_for_scene(scene_file_path) == 0 and not toon.expects_avatar():
		return
	toon.attach(self)


func _process(_delta: float) -> void:
	TOONTOWN_SKY.ensure(self, sky_kind)
	var camera := _view_camera()
	_follow_cog_sky(camera)
	_process_zones(camera)
	if Engine.is_editor_hint():
		return
	_process_billboards(camera)
	_watch_fireworks()


func show_fireworks(show_name: String, at: int = -1, delay: float = 0.0) -> void:
	_FIREWORK_SHOW.present(self, show_name, at, delay)


func _watch_fireworks() -> void:
	_FIREWORK_SHOW.follow(self)
	_watch_holiday_show()


func _watch_holiday_show() -> void:
	var file := scene_file_path.get_file()
	if file != "toontown_central.tscn" and file != "donalds_dock.tscn" and file != "daisy_gardens.tscn" and file != "minnies_melodyland.tscn" and file != "the_burrrgh.tscn" and file != "donalds_dreamland.tscn" and file != "goofy_speedway.tscn" and file != "acorn_acres.tscn":
		return
	var holidays := preload("res://scenes/shticker/calendar_holidays.gd")
	var show := ""
	if bool(holidays.call("running", 2)):
		show = "newyear"
	elif bool(holidays.call("running", 1)):
		show = "summer"
	if show == "":
		return
	if String(get_meta("holiday_show", "")) == show or get_node_or_null("FireworkShow") != null:
		return
	set_meta("holiday_show", show)
	_FIREWORK_SHOW.present(self, show)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		TOONTOWN_SKY.restore_imported(self)
		_show_every_zone()
		var cog_sky := get_node_or_null("CogSky") as Node3D
		if cog_sky:
			cog_sky.position = Vector3.ZERO


func _prepare_cog_sky() -> void:
	var cog_sky := get_node_or_null("CogSky") as Node3D
	if cog_sky == null:
		return
	# LawbotHQ.load hides the shared backdrop. The plaza model has its own sky,
	# and the shared one hangs above the sunken floor, so the courtyard looks
	# up into the underside of it.
	if scene_file_path.get_file().begins_with("lawbot"):
		cog_sky.visible = false
		return
	# SellbotHQ.load scales the backdrop by 2. At 1, the hill ring sits inside
	# the courtyard and travels with the camera.
	if scene_file_path.get_file().begins_with("sellbot"):
		cog_sky.scale = Vector3.ONE * 2.0
	_push_backdrop(cog_sky)


func _push_backdrop(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		if mesh.mesh != null:
			for surface in mesh.mesh.get_surface_count():
				var source := mesh.get_active_material(surface)
				mesh.set_surface_override_material(surface, _backdrop_material(source))
	for child in node.get_children():
		_push_backdrop(child)


func _backdrop_material(source: Material) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _BACKDROP
	var tint := Color.WHITE
	var cutoff := 0.0
	var tex: Texture2D = null
	if source is BaseMaterial3D:
		var base := source as BaseMaterial3D
		tex = base.albedo_texture
		tint = base.albedo_color
		if base.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
			cutoff = base.alpha_scissor_threshold
	mat.set_shader_parameter("albedo_tex", tex)
	mat.set_shader_parameter("albedo_color", tint)
	mat.set_shader_parameter("alpha_scissor", cutoff)
	return mat


func _follow_cog_sky(camera: Camera3D) -> void:
	# Hood.startSky parents the backdrop to the camera, then CompassEffect
	# keeps its height and rotation in the world. It slides on the ground
	# plane only, and the shader keeps it behind the courtyard.
	var cog_sky := get_node_or_null("CogSky") as Node3D
	if cog_sky == null or camera == null or not cog_sky.visible:
		return
	var placed := cog_sky.global_position
	placed.x = camera.global_position.x
	placed.y = 0.0
	placed.z = camera.global_position.z
	cog_sky.global_position = placed


func _ready_music() -> void:
	if music_path.is_empty() or not FileAccess.file_exists(music_path):
		return
	var stream := AudioStreamOggVorbis.load_from_file(music_path)
	if stream == null:
		return
	stream.loop = true
	var player := ToonAudio.music_player()
	player.name = "NeighborhoodMusic"
	player.stream = stream
	player.volume_db = linear_to_db(MUSIC_VOLUME)
	add_child(player)
	player.play()


func _focus_sample(camera: Camera3D) -> Vector2:
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


func zone_visible_at(at: Vector3) -> bool:
	var rooms := get_node_or_null("FactoryRooms")
	if rooms != null:
		return bool(rooms.call("visible_at", at))
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
