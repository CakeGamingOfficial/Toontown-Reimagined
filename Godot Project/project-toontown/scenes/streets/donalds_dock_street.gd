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


func _ready() -> void:
	_ready_music()
	_ready_sky()
	_ready_billboards()
	_close_hq_doors(self)
	if preload("res://scenes/places/tunnel_links.gd").arriving():
		preload("res://scenes/playgrounds/playground_toon.gd").attach(self)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
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


func _find_exact(node: Node, wanted: String) -> Node:
	if String(node.name) == wanted:
		return node
	for child in node.get_children():
		var found := _find_exact(child, wanted)
		if found:
			return found
	return null
