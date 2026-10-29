extends Node3D

## Chip 'n Dale's Acorn Acres motion the bind-pose export does not carry.
## The sky keeps the world's rotation and only follows the camera across the
## ground, while its cloud cards drift. Flat cards yaw to face the camera.

const MUSIC_PATH := "res://assets/neighborhoods/acorn_acres/audio/OZ_SZ.ogg"
const MUSIC_VOLUME := 0.8

var _sky: Node3D
var _sky_height := 0.0
var _cloud1: Node3D
var _cloud2: Node3D
var _cloud1_rest: Basis
var _cloud2_rest: Basis
var _cloud_heading := 0.0
var _billboards: Array[Dictionary] = []
var _waterfall: StandardMaterial3D


func _ready() -> void:
	_ready_music()
	_ready_sky()
	_ready_billboards()
	_open_backdrops(self)
	_ready_waterfall()
	if not Engine.is_editor_hint():
		preload("res://scenes/playgrounds/playground_toon.gd").attach(self)


func _open_backdrops(node: Node) -> void:
	# The mountain cards face the island. A view from outside the ring still
	# needs the painted side, which is the face the original top-down shows.
	if node is MeshInstance3D and String(node.name).begins_with("backdrop"):
		_show_both_sides(node as MeshInstance3D)
	for child in node.get_children():
		_open_backdrops(child)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	_process_sky(delta, camera)
	_process_billboards(camera)
	if _waterfall:
		# The waterfall actor loops its tide card. Scroll the same texture.
		_waterfall.uv1_offset.y += delta * 0.35


func _ready_music() -> void:
	# Playground.enter loops loader.music at 0.8. Acorn Acres uses OZ_SZ.
	if not FileAccess.file_exists(MUSIC_PATH):
		return
	var stream := AudioStreamOggVorbis.load_from_file(MUSIC_PATH)
	if stream == null:
		return
	stream.loop = true
	var player := AudioStreamPlayer.new()
	player.name = "PlaygroundMusic"
	player.stream = stream
	player.volume_db = linear_to_db(MUSIC_VOLUME)
	add_child(player)
	player.play()


func _ready_sky() -> void:
	_cloud1 = find_child("cloud1", true, false) as Node3D
	_cloud2 = find_child("cloud2", true, false) as Node3D
	if _cloud1:
		_sky = _cloud1.get_parent() as Node3D
		_cloud1_rest = _cloud1.basis
	if _cloud2:
		_cloud2_rest = _cloud2.basis
	if _sky == null:
		_sky = _find_exact(self, "OZSky") as Node3D
	if _sky:
		# The mountain ring sits farther out than the Toontown Central dome.
		# Grow it so the shell stays behind the backdrops when the camera
		# frames the whole playground.
		_sky.scale *= 3.0
		_sky_height = _sky.global_position.y
		_sky.visible = true
	if _cloud1:
		_soften_clouds(_cloud1)
	if _cloud2:
		_soften_clouds(_cloud2)


func _process_sky(delta: float, camera: Camera3D) -> void:
	# CompassEffect PRot|PZ: the dome follows the camera but keeps the world's
	# rotation and height. cloud1 gains a quarter degree per second.
	if _sky and camera:
		var place := camera.global_position
		_sky.global_position = Vector3(place.x, _sky_height, place.z)
	_cloud_heading += delta * 0.25
	if _cloud1:
		_cloud1.basis = _cloud1_rest * Basis(Vector3(0, 0, 1), deg_to_rad(_cloud_heading))
	if _cloud2:
		_cloud2.basis = _cloud2_rest * Basis(Vector3(0, 0, 1), deg_to_rad(-_cloud_heading * 0.8))


func _soften_clouds(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh:
			for surface in mesh.get_surface_count():
				var material := mesh.surface_get_material(surface)
				if material is StandardMaterial3D:
					var standard := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
					standard.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					standard.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
					standard.cull_mode = BaseMaterial3D.CULL_DISABLED
					mesh.surface_set_material(surface, standard)
	for child in node.get_children():
		_soften_clouds(child)


func _ready_billboards() -> void:
	_collect_billboards(self)


func _collect_billboards(node: Node) -> void:
	if node is Node3D and (node.is_in_group("tt_billboard") or String(node.name).contains("__billboard")):
		_billboards.append({"node": node, "rest": (node as Node3D).global_transform.basis})
		if node is MeshInstance3D:
			_show_both_sides(node as MeshInstance3D)
	for child in node.get_children():
		_collect_billboards(child)


func _ready_waterfall() -> void:
	var tide := _find_exact(self, "mesh_tide1") as MeshInstance3D
	if tide == null or tide.mesh == null or tide.mesh.get_surface_count() == 0:
		return
	var material := tide.mesh.surface_get_material(0)
	if material is StandardMaterial3D:
		_waterfall = (material as StandardMaterial3D).duplicate() as StandardMaterial3D
		tide.set_surface_override_material(0, _waterfall)


func _process_billboards(camera: Camera3D) -> void:
	if camera == null:
		return
	for item in _billboards:
		var node := item["node"] as Node3D
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


func _find_exact(node: Node, wanted: String) -> Node:
	if String(node.name) == wanted:
		return node
	for child in node.get_children():
		var found := _find_exact(child, wanted)
		if found:
			return found
	return null
