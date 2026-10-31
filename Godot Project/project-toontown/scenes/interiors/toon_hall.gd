extends Node3D

## DistributedToonHallInterior for zone 2513. The room is the flat silly-meter
## state: ropes, the still meter, and the three scientist cards. Flippy stands
## on npc_origin_0, the first toon createNpcsInZone places in that zone.

const _DOOR := preload("res://scenes/interiors/toon_hall_door.gd")
const _COLLISION := preload("res://scenes/playgrounds/playground_collision.gd")
const _TOON := preload("res://scenes/playgrounds/playground_toon.gd")
const _ROOM := "res://assets/interiors/toon_hall/toon_hall.glb"
const _MUSIC := "res://assets/neighborhoods/toontown_central/audio/TC_nbrhood.ogg"
const MUSIC_VOLUME := 0.8

# NPCToons 2001. head, torso, legs, gender, arm, glove, leg, head,
# top texture, top color, bottom texture, bottom color.
const _FLIPPY: Array = ["Flippy", "dss", "ms", "m", "m", 17, 0, 17, 17, 3, 3, 7, 2]


func _ready() -> void:
	_build_room()
	_place_flippy()
	_play_music()
	_TOON.attach(self)


func _build_room() -> void:
	var packed := load(_ROOM) as PackedScene
	if packed == null:
		push_error("Toon Hall room is missing")
		return
	var geom := packed.instantiate()
	geom.name = "Geometry"
	geom.set_script(_COLLISION)
	add_child(geom)
	_DOOR.seal(_DOOR.find_interior_door(self))


func _place_flippy() -> void:
	var origin := find_child("npc_origin_0", true, false) as Node3D
	if origin == null:
		return
	var body := StaticBody3D.new()
	body.name = "Flippy"
	add_child(body)
	body.global_position = origin.global_position + Vector3(0.0, 0.02, 0.0)
	var actor := ToonActor.new()
	actor.name = "Flippy"
	body.add_child(actor)
	actor.show_style(_style(_FLIPPY))
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
	var stream := AudioStreamOggVorbis.load_from_file(_MUSIC)
	if stream == null:
		return
	stream.loop = true
	var player := ToonAudio.music_player()
	player.name = "NeighborhoodMusic"
	player.stream = stream
	player.volume_db = linear_to_db(MUSIC_VOLUME)
	add_child(player)
	player.play()
