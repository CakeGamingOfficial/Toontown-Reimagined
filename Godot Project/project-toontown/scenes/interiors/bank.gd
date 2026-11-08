extends Node3D

## Zone 2514, the toon interior DistributedToonInterior builds for the bank.
## Banker Bob stands on npc_origin_0, the only toon createNpcsInZone
## places in that zone. Paintings tagged __billboard turn toward the camera
## the way the other toon interiors do.

const _DOOR := preload("res://scenes/interiors/bank_door.gd")
const _COLLISION := preload("res://scenes/playgrounds/playground_collision.gd")
const _TOON := preload("res://scenes/playgrounds/playground_toon.gd")
const _ROOM := "res://assets/interiors/bank/bank.glb"
const _MUSIC := "res://assets/neighborhoods/toontown_central/audio/TC_SZ_activity.mp3"
const MUSIC_VOLUME := 0.7

# NPCToons 2002. head, torso, legs, gender, arm, glove, leg, head,
# top texture, top color, bottom texture, bottom color.
const _BOB: Array = ["Banker Bob", "hss", "ls", "l", "m", 4, 0, 4, 4, 0, 3, 0, 3]

var _billboards: Array[Dictionary] = []


func _ready() -> void:
	_build_room()
	_place_bob()
	_play_music()
	_TOON.attach(self)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for item in _billboards:
		var node := item["node"] as Node3D
		if not is_instance_valid(node):
			continue
		var rest: Basis = item["rest"]
		var face := Vector3(-rest.y.x, 0.0, -rest.y.z)
		var to_target := camera.global_position - node.global_position
		to_target.y = 0.0
		if face.length() < 0.0001 or to_target.length() < 0.0001:
			continue
		var turned := node.global_transform
		turned.basis = rest.rotated(Vector3.UP, face.signed_angle_to(to_target, Vector3.UP))
		node.global_transform = turned


func _build_room() -> void:
	var packed := load(_ROOM) as PackedScene
	if packed == null:
		push_error("Bank room is missing")
		return
	var geom := packed.instantiate()
	geom.name = "Geometry"
	geom.set_script(_COLLISION)
	add_child(geom)
	_DOOR.seal(_DOOR.find_interior_door(self))
	_collect_billboards(geom)


func _place_bob() -> void:
	var origin := find_child("npc_origin_0", true, false) as Node3D
	if origin == null:
		return
	var body := StaticBody3D.new()
	body.name = "BankerBob"
	body.set_meta("npc_id", 2002)
	add_child(body)
	body.global_position = origin.global_position + Vector3(0.0, 0.02, 0.0)
	var actor := ToonActor.new()
	actor.name = "Banker Bob"
	body.add_child(actor)
	actor.show_style(_style(_BOB))
	_face(actor, origin)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.6
	shape.height = 3.0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, shape.height * 0.5, 0.0)
	body.add_child(collision)


func _style(row: Array) -> ToonStyle:
	var style := ToonStyle.new()
	style.first_name = String(row[0])
	style.head = String(row[1])
	style.torso = String(row[2])
	style.legs = String(row[3])
	style.gender = String(row[4])
	style.arm_color = int(row[5])
	style.glove_color = int(row[6])
	style.leg_color = int(row[7])
	style.head_color = int(row[8])
	style.top_tex = int(row[9])
	style.top_color = int(row[10])
	style.bot_tex = int(row[11])
	style.bot_color = int(row[12])
	return style


func _face(actor: Node3D, origin: Node3D) -> void:
	var ahead := origin.to_global(Vector3(0.0, 1.0, 0.0)) - origin.global_position
	ahead.y = 0.0
	var heading := 0.0
	if ahead.length_squared() > 0.0001:
		heading = rad_to_deg(atan2(-ahead.x, -ahead.z))
	var body_scale := actor.transform.basis.get_scale().x
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	upright = upright.rotated(Vector3.UP, deg_to_rad(heading))
	actor.transform.basis = upright.scaled(Vector3.ONE * body_scale)


func _play_music() -> void:
	if not FileAccess.file_exists(_MUSIC):
		return
	var stream := load(_MUSIC) as AudioStreamMP3
	if stream == null:
		return
	var copy := stream.duplicate() as AudioStreamMP3
	copy.loop = true
	var player := ToonAudio.music_player()
	player.name = "BankMusic"
	player.stream = copy
	player.volume_db = linear_to_db(MUSIC_VOLUME)
	add_child(player)
	player.play()


func _collect_billboards(node: Node) -> void:
	if node is Node3D and String(node.name).contains("__billboard"):
		_billboards.append({"node": node, "rest": (node as Node3D).global_transform.basis})
		if node is MeshInstance3D:
			_show_both_sides(node as MeshInstance3D)
	for child in node.get_children():
		_collect_billboards(child)


func _show_both_sides(mesh_node: MeshInstance3D) -> void:
	if mesh_node.mesh == null:
		return
	for index in mesh_node.mesh.get_surface_count():
		var material := mesh_node.get_active_material(index)
		if material is StandardMaterial3D:
			var copy := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
			copy.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh_node.set_surface_override_material(index, copy)
