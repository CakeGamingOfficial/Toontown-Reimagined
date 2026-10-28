extends Node3D

## Donald's Dock playground motion the bind-pose export does not carry.
## The sky is the shared Toontown dome. Palm
## tops and other flat cards yaw to face the camera. The pet
## shop bowl fish replay the original swim cycle. The boat sails the original
## east-west curves while the drawbridges swing down behind it and up ahead.

const FISH_PATH := "res://assets/neighborhoods/toontown_central/props/fish_swim.json"
const BOAT_PATH := "res://assets/neighborhoods/donalds_dock/boat_path.json"
const MUSIC_PATH := "res://assets/neighborhoods/donalds_dock/audio/DD_nbrhood.ogg"
const MUSIC_VOLUME := 0.8
const TOONTOWN_SKY := preload("res://scenes/sky/toontown_sky.gd")
const DOCK_TIME := 10.0
const PIER_TIME := 5.0

enum _Berth { WEST, EAST }
enum _Phase { DOCKED, SAILING }

var _billboards: Array[Dictionary] = []

var _fish_fps := 24.0
var _fish_joints: Dictionary = {}
var _fish_frames: Array = []
var _time := 0.0

var _boat: Node3D
var _east_pier: Node3D
var _west_pier: Node3D
var _east_to_west: Dictionary = {}
var _west_to_east: Dictionary = {}
var _east_down: Transform3D
var _east_up: Transform3D
var _west_down: Transform3D
var _west_up: Transform3D
var _berth := _Berth.WEST
var _phase := _Phase.DOCKED
var _phase_time := 0.0
var _bell: AudioStreamPlayer3D
var _horn: AudioStreamPlayer3D
var _east_creak: AudioStreamPlayer3D
var _west_creak: AudioStreamPlayer3D
var _horn_length := 0.0
var _trip_horn := false
var _trip_arrive := false


func _ready() -> void:
	_ready_music()
	TOONTOWN_SKY.ensure(self)
	_ready_billboards()
	_ready_fish()
	_ready_boat()


func _ready_music() -> void:
	# Playground.enter loops loader.music at 0.8. Donald's Dock's playground
	# track is DD_nbrhood ("Donald's Dock"). The street theme is DD_SZ.
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


func _process(delta: float) -> void:
	_time += delta
	var camera := get_viewport().get_camera_3d()
	_process_billboards(camera)
	_process_fish()
	_process_boat(delta)


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


func _ready_fish() -> void:
	var shop := _find_exact(self, "animated_prop_PetShopFishAnimatedProp_DNARoot")
	if shop == null:
		return
	var data := _read_json(FISH_PATH)
	if data.is_empty():
		return
	_fish_fps = float(data.get("fps", 24.0))
	_fish_frames = data.get("frames", [])
	for joint_name in ["joint_fish1", "joint_fish2"]:
		var joint := _find_exact(shop, joint_name) as Node3D
		if joint:
			_fish_joints[joint_name] = joint


func _process_fish() -> void:
	if _fish_frames.is_empty() or _fish_joints.is_empty():
		return
	var count := _fish_frames.size()
	var sample := _time * _fish_fps
	var i0 := int(floorf(sample)) % count
	var i1 := (i0 + 1) % count
	var blend := sample - floorf(sample)
	var frame_a: Dictionary = _fish_frames[i0]
	var frame_b: Dictionary = _fish_frames[i1]
	for joint_name in _fish_joints:
		var joint := _fish_joints[joint_name] as Node3D
		var from_pose := _panda_transform(frame_a[joint_name])
		var to_pose := _panda_transform(frame_b[joint_name])
		joint.transform = from_pose.interpolate_with(to_pose, blend)


func _panda_transform(cells: Array) -> Transform3D:
	# The exporter writes Panda's row-major matrix into glTF's column-major slot.
	var basis := Basis(
		Vector3(cells[0], cells[1], cells[2]),
		Vector3(cells[4], cells[5], cells[6]),
		Vector3(cells[8], cells[9], cells[10])
	)
	return Transform3D(basis, Vector3(cells[12], cells[13], cells[14]))


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _ready_boat() -> void:
	var data := _read_json(BOAT_PATH)
	_boat = _find_exact(self, "donalds_boat") as Node3D
	_east_pier = _find_exact(self, "east_pier") as Node3D
	_west_pier = _find_exact(self, "west_pier") as Node3D
	if data.is_empty() or _boat == null or _east_pier == null or _west_pier == null:
		_boat = null
		return
	_east_to_west = data["east_to_west"]
	_west_to_east = data["west_to_east"]
	_east_down = _panda_transform(data["east_down"])
	_east_up = _panda_transform(data["east_up"])
	_west_down = _panda_transform(data["west_down"])
	_west_up = _panda_transform(data["west_up"])
	_ride_collision(_boat)
	_ride_collision(_east_pier)
	_ride_collision(_west_pier)
	_bell = _sound(_boat, "res://assets/neighborhoods/donalds_dock/audio/ship_bell.ogg")
	_horn = _sound(_boat, "res://assets/neighborhoods/donalds_dock/audio/foghorn.ogg")
	_east_creak = _sound(_east_pier, "res://assets/neighborhoods/donalds_dock/audio/dock_creak.ogg")
	_west_creak = _sound(_west_pier, "res://assets/neighborhoods/donalds_dock/audio/dock_creak.ogg")
	if _horn and _horn.stream:
		_horn_length = _horn.stream.get_length()
	# The exported pose is the west berth: boat alongside, west bridge up.
	_berth = _Berth.WEST
	_phase = _Phase.DOCKED
	_apply_dock()


func _process_boat(delta: float) -> void:
	if _boat == null:
		return
	_phase_time += delta
	if _phase == _Phase.DOCKED:
		_apply_dock()
		if _phase_time >= DOCK_TIME:
			_depart()
		return
	_apply_sailing()
	var duration := float((_west_to_east if _berth == _Berth.WEST else _east_to_west)["duration"])
	if _phase_time >= duration:
		_berth = _Berth.EAST if _berth == _Berth.WEST else _Berth.WEST
		_phase = _Phase.DOCKED
		_phase_time = 0.0
		_apply_dock()


func _apply_sailing() -> void:
	var toward_east := _berth == _Berth.WEST
	var path := _west_to_east if toward_east else _east_to_west
	var duration := float(path["duration"])
	_boat.transform = _along(path, _phase_time)
	var leaving := clampf(_phase_time / PIER_TIME, 0.0, 1.0)
	var arriving := clampf((_phase_time - (duration - PIER_TIME)) / PIER_TIME, 0.0, 1.0)
	if toward_east:
		_west_pier.transform = _west_up.interpolate_with(_west_down, leaving)
		_east_pier.transform = _east_down.interpolate_with(_east_up, arriving)
	else:
		_east_pier.transform = _east_up.interpolate_with(_east_down, leaving)
		_west_pier.transform = _west_down.interpolate_with(_west_up, arriving)
	_sail_sounds(duration, toward_east)


func _depart() -> void:
	# The bridge just left drops as the boat casts off. The far bridge rises
	# during the last five seconds so it is up when the boat arrives.
	_phase = _Phase.SAILING
	_phase_time = 0.0
	_trip_horn = false
	_trip_arrive = false
	if _bell:
		_bell.play()
	var leaving_west := _berth == _Berth.WEST
	var creak := _west_creak if leaving_west else _east_creak
	if creak:
		creak.play()


func _sail_sounds(duration: float, toward_east: bool) -> void:
	if _horn and not _trip_horn and _phase_time >= duration - _horn_length:
		_trip_horn = true
		_horn.play()
	if not _trip_arrive and _phase_time >= duration - PIER_TIME:
		_trip_arrive = true
		var creak := _east_creak if toward_east else _west_creak
		if creak:
			creak.play()


func _apply_dock() -> void:
	var at_east := _berth == _Berth.EAST
	var path := _west_to_east if at_east else _east_to_west
	_boat.transform = _along(path, float(path["duration"]))
	_east_pier.transform = _east_up if at_east else _east_down
	_west_pier.transform = _west_down if at_east else _west_up


func _along(path: Dictionary, time: float) -> Transform3D:
	var duration := float(path["duration"])
	var samples: Array = path["samples"]
	var last := samples.size() - 1
	var clamped := clampf(time, 0.0, duration)
	var t := 0.0 if duration <= 0.0 else clamped / duration * float(last)
	var i0 := mini(int(floorf(t)), last)
	var i1 := mini(i0 + 1, last)
	var from_pose := _panda_transform(samples[i0])
	var to_pose := _panda_transform(samples[i1])
	return from_pose.interpolate_with(to_pose, t - float(i0))


func _sound(parent: Node, path: String) -> AudioStreamPlayer3D:
	if not FileAccess.file_exists(path):
		return null
	var stream := AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		return null
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.unit_size = 70.0
	parent.add_child(player)
	return player


func _ride_collision(root: Node) -> void:
	# Trimesh bodies are built as static children. The boat and the swinging
	# bridges have to carry that collision with them.
	if root is StaticBody3D:
		var body := root as StaticBody3D
		var riding := AnimatableBody3D.new()
		riding.transform = body.transform
		riding.collision_layer = body.collision_layer
		riding.collision_mask = body.collision_mask
		riding.sync_to_physics = true
		var parent := body.get_parent()
		var index := body.get_index()
		for child in body.get_children():
			body.remove_child(child)
			riding.add_child(child)
		parent.remove_child(body)
		parent.add_child(riding)
		parent.move_child(riding, index)
		body.free()
		return
	for child in root.get_children():
		_ride_collision(child)


func _find_exact(node: Node, wanted: String) -> Node:
	if String(node.name) == wanted:
		return node
	for child in node.get_children():
		var found := _find_exact(child, wanted)
		if found:
			return found
	return null
