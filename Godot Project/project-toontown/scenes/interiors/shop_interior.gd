extends Node3D

## One scene for every street shop. ShopDoor.zone picks the baked room, and
## the shopkeeper stands on npc_origin the way NPCToons.createNpcsInZone
## places them.

const _DOOR := preload("res://scenes/interiors/shop_door.gd")
const _PANELS := preload("res://scenes/interiors/house_door.gd")
const _COLLISION := preload("res://scenes/playgrounds/playground_collision.gd")
const _TOON := preload("res://scenes/playgrounds/playground_toon.gd")
const _ROOM := "res://assets/interiors/shops/shop_%d.glb"
# ToonInterior.enter plays TownLoader.activityMusic. Daisy Gardens uses its
# street theme for that track. The others have a separate activity file.
const _MUSIC: Dictionary = {
	1000: "res://assets/neighborhoods/donalds_dock/audio/DD_SZ_activity.ogg",
	2000: "res://assets/neighborhoods/toontown_central/audio/TC_SZ_activity.mp3",
	3000: "res://assets/neighborhoods/the_burrrgh/audio/TB_SZ_activity.ogg",
	4000: "res://assets/neighborhoods/minnies_melodyland/audio/MM_SZ_activity.ogg",
	5000: "res://assets/neighborhoods/daisy_gardens/audio/DG_SZ.ogg",
	9000: "res://assets/neighborhoods/donalds_dreamland/audio/DL_SZ_activity.ogg",
}
const MUSIC_VOLUME := 0.7

var _billboards: Array[Dictionary] = []


func _ready() -> void:
	_light_room()
	_build_room()
	_place_keepers()
	_play_music()
	_TOON.attach(self)


## The street sun does not come indoors. The room itself is drawn unlit, the
## same way the streets are. This light is for the toon shader, which stays
## black on ambient color alone.
func _light_room() -> void:
	var world := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world != null and world.environment != null:
		world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.environment.ambient_light_color = Color(1.0, 1.0, 1.0)
		world.environment.ambient_light_energy = 1.05
	var sun := DirectionalLight3D.new()
	sun.name = "ShopLight"
	sun.rotation_degrees = Vector3(-48.0, 32.0, 0.0)
	sun.light_energy = 0.9
	sun.shadow_enabled = false
	add_child(sun)


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
	var path := _ROOM % _DOOR.zone
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Shop room missing for zone %d" % _DOOR.zone)
		return
	var geom := packed.instantiate()
	geom.name = "Geometry"
	geom.set_script(_COLLISION)
	add_child(geom)
	_PANELS.seal(_PANELS.find_door(self))
	_collect_billboards(geom)


func _place_keepers() -> void:
	var row := _DOOR.record(_DOOR.zone)
	var npcs: Array = row.get("npcs", [])
	for index in npcs.size():
		var npc: Dictionary = npcs[index]
		var origin := find_child("npc_origin_%d" % index, true, false) as Node3D
		if origin == null:
			continue
		var dna: Array = npc.get("dna", [])
		if dna.size() < 14:
			continue
		var body := StaticBody3D.new()
		body.name = "Shopkeeper%d" % index
		var npc_id := int(npc.get("id", 0))
		if npc_id != 0:
			body.set_meta("npc_id", npc_id)
		add_child(body)
		body.global_position = origin.global_position + Vector3(0.0, 0.02, 0.0)
		var actor := ToonActor.new()
		actor.name = String(npc.get("name", "Shopkeeper"))
		body.add_child(actor)
		actor.show_style(_style(npc, dna))
		_face(actor, origin)
		var shape := CapsuleShape3D.new()
		shape.radius = 0.6
		shape.height = 3.0
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = Vector3(0.0, shape.height * 0.5, 0.0)
		body.add_child(collision)


func _style(npc: Dictionary, dna: Array) -> ToonStyle:
	var style := ToonStyle.new()
	style.first_name = String(npc.get("name", "Shopkeeper"))
	style.head = String(dna[0])
	style.torso = String(dna[1])
	style.legs = String(dna[2])
	style.gender = String(dna[3])
	style.arm_color = int(dna[4])
	style.glove_color = int(dna[5])
	style.leg_color = int(dna[6])
	style.head_color = int(dna[7])
	style.top_tex = int(dna[8])
	style.top_color = int(dna[9])
	style.bot_tex = int(dna[12])
	style.bot_color = int(dna[13])
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
	var path := String(_MUSIC.get(_DOOR.hood_id(), _MUSIC[2000]))
	if not FileAccess.file_exists(path):
		return
	var stream: AudioStream = null
	if path.ends_with(".mp3"):
		stream = load(path) as AudioStreamMP3
	else:
		stream = AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		return
	var copy: AudioStream = stream.duplicate() as AudioStream
	if copy is AudioStreamMP3:
		(copy as AudioStreamMP3).loop = true
	elif copy is AudioStreamOggVorbis:
		(copy as AudioStreamOggVorbis).loop = true
	var player := ToonAudio.music_player()
	player.name = "ShopMusic"
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
