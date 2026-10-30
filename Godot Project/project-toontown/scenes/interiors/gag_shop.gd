extends Node3D

## One Goofy's Gag Shop room for every playground that has one. The geometry
## is the original gagShop_interior, colored from that playground's zone.
## Clerks stand on npc_origin the way NPCToons.createNpcsInZone places them.

const _DOOR := preload("res://scenes/interiors/gag_shop_door.gd")
const _PLACES := preload("res://scenes/places/hood_places.gd")
const _COLLISION := preload("res://scenes/playgrounds/playground_collision.gd")
const _TOON := preload("res://scenes/playgrounds/playground_toon.gd")
const MUSIC_VOLUME := 0.8

# head, torso, legs, gender, then ToonDNA colors: arm, glove, leg, head,
# top texture, top color, bottom texture, bottom color. Sorted npc id is
# the origin index, the same order createNpcsInZone uses.
const _CLERKS: Dictionary = {
	1000: [
		["Clerk Will", "rss", "ms", "l", "m", 10, 0, 10, 10, 0, 11, 0, 0],
		["Clerk Bill", "mss", "ss", "l", "m", 3, 0, 3, 3, 1, 10, 0, 18],
	],
	2000: [
		["Clerk Clark", "dsl", "ls", "l", "m", 18, 0, 18, 18, 1, 4, 1, 2],
		["Clerk Clara", "rll", "ms", "l", "f", 2, 0, 2, 2, 1, 9, 23, 27],
	],
	3000: [
		["Clerk Lenny", "fsl", "ss", "m", "m", 18, 0, 18, 18, 0, 11, 0, 2],
		["Clerk Penny", "fls", "ld", "m", "f", 12, 0, 12, 12, 0, 25, 8, 5],
	],
	4000: [
		["Clerk Doe", "rss", "md", "m", "f", 21, 0, 21, 21, 1, 4, 8, 8],
		["Clerk Ray", "rls", "ms", "m", "m", 12, 0, 12, 12, 1, 3, 1, 19],
	],
	5000: [
		["Clerk Peaches", "mls", "md", "s", "f", 6, 0, 6, 6, 0, 21, 2, 3],
		["Clerk Herb", "hsl", "ms", "s", "m", 20, 0, 20, 20, 0, 9, 0, 1],
	],
	9000: [
		["Clerk Jill", "hll", "ss", "l", "f", 8, 0, 8, 8, 1, 9, 12, 27],
		["Clerk Phil", "hss", "ls", "l", "m", 22, 0, 22, 22, 0, 7, 0, 13],
	],
}

const _MUSIC: Dictionary = {
	1000: "res://assets/neighborhoods/donalds_dock/audio/DD_nbrhood.ogg",
	2000: "res://assets/neighborhoods/toontown_central/audio/TC_nbrhood.ogg",
	3000: "res://assets/neighborhoods/the_burrrgh/audio/TB_nbrhood.ogg",
	4000: "res://assets/neighborhoods/minnies_melodyland/audio/MM_nbrhood.ogg",
	5000: "res://assets/neighborhoods/daisy_gardens/audio/DG_nbrhood.ogg",
	9000: "res://assets/neighborhoods/donalds_dreamland/audio/DL_nbrhood.ogg",
}


func _ready() -> void:
	_build_room()
	_place_clerks()
	_play_music()
	_TOON.attach(self)


func _build_room() -> void:
	var path := "res://assets/interiors/gag_shop/gag_shop_%d.glb" % _DOOR.hood
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Gag shop room missing for hood %d" % _DOOR.hood)
		return
	var geom := packed.instantiate()
	geom.name = "Geometry"
	geom.set_script(_COLLISION)
	add_child(geom)
	_DOOR.seal(_DOOR.find_interior_door(self))


func _place_clerks() -> void:
	if not _CLERKS.has(_DOOR.hood):
		return
	var rows: Array = _CLERKS[_DOOR.hood]
	for index in rows.size():
		var origin := find_child("npc_origin_%d" % index, true, false) as Node3D
		if origin == null:
			continue
		var row: Array = rows[index]
		var body := StaticBody3D.new()
		body.name = "Clerk%d" % index
		add_child(body)
		body.global_position = origin.global_position + Vector3(0.0, 0.02, 0.0)
		var actor := ToonActor.new()
		actor.name = String(row[0])
		body.add_child(actor)
		actor.show_style(_style(row))
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
	var path := String(_MUSIC.get(_DOOR.hood, ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var stream := AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		return
	stream.loop = true
	var player := ToonAudio.music_player()
	player.name = "NeighborhoodMusic"
	player.stream = stream
	player.volume_db = linear_to_db(MUSIC_VOLUME)
	add_child(player)
	player.play()
