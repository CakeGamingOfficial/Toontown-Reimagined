extends Node3D

## One pet shop room for every playground that has one. The geometry is the
## original PetShopInterior, colored from that playground's clerk zone.
## Clerks stand on npc_origin the way NPCToons.createNpcsInZone places them.
## The tank fish loops interiorfish-swim at the original 0.7 play rate.

const _DOOR := preload("res://scenes/interiors/pet_shop_door.gd")
const _COLLISION := preload("res://scenes/playgrounds/playground_collision.gd")
const _TOON := preload("res://scenes/playgrounds/playground_toon.gd")
const _FISH := "res://assets/interiors/pet_shop/fish_swim.json"
const MUSIC_VOLUME := 0.7

# head, torso, legs, gender, then ToonDNA colors: arm, glove, leg, head,
# top texture, top color, bottom texture, bottom color. Sorted npc id is
# the origin index, the same order createNpcsInZone uses.
const _CLERKS: Dictionary = {
	1000: [
		["Clerk Barky", "dsl", "ss", "m", "m", 17, 0, 17, 17, 0, 0, 0, 14],
		["Clerk Purr", "dss", "ld", "m", "f", 10, 0, 10, 10, 0, 0, 26, 27],
		["Clerk Bloop", "fll", "sd", "m", "f", 1, 0, 1, 1, 0, 1, 4, 25],
	],
	2000: [
		["Clerk Poppy", "rls", "ms", "l", "m", 9, 0, 9, 9, 0, 7, 1, 19],
		["Clerk Peppy", "mls", "ms", "m", "f", 2, 0, 2, 2, 0, 12, 1, 0],
		["Clerk Pappy", "hsl", "ls", "m", "m", 17, 0, 17, 17, 0, 8, 1, 13],
	],
	3000: [
		["Clerk Skip", "rls", "ss", "l", "m", 10, 0, 10, 10, 0, 12, 0, 11],
		["Clerk Dip", "mls", "md", "l", "f", 3, 0, 3, 3, 1, 26, 26, 27],
		["Clerk Kipp", "hsl", "ms", "l", "m", 18, 0, 18, 18, 1, 12, 0, 1],
	],
	4000: [
		["Clerk Chris", "hss", "ms", "m", "m", 12, 0, 12, 12, 0, 5, 1, 10],
		["Clerk Neil", "cll", "ss", "m", "m", 4, 0, 4, 4, 0, 5, 1, 4],
		["Clerk Westin Girl", "csl", "ss", "m", "f", 19, 0, 19, 19, 0, 8, 10, 27],
	],
	5000: [
		["Clerk Bo Tanny", "csl", "ls", "m", "f", 21, 0, 21, 21, 1, 23, 8, 23],
		["Clerk Tom A. Dough", "cls", "ss", "m", "m", 13, 0, 13, 13, 1, 10, 0, 10],
		["Clerk Doug Wood", "dll", "ls", "m", "m", 5, 0, 5, 5, 1, 10, 0, 4],
	],
	9000: [
		["Clerk Sarah Snuze", "cls", "ld", "l", "f", 23, 0, 23, 23, 0, 21, 10, 27],
		["Clerk Kat Knap", "dll", "sd", "l", "f", 15, 0, 15, 15, 0, 21, 10, 27],
		["Clerk R. V. Winkle", "dss", "ss", "l", "m", 7, 0, 7, 7, 0, 9, 1, 15],
	],
}

const _MUSIC: Dictionary = {
	1000: "res://assets/neighborhoods/donalds_dock/audio/DD_SZ_activity.ogg",
	2000: "res://assets/neighborhoods/toontown_central/audio/TC_SZ_activity.mp3",
	3000: "res://assets/neighborhoods/the_burrrgh/audio/TB_SZ_activity.ogg",
	4000: "res://assets/neighborhoods/minnies_melodyland/audio/MM_SZ_activity.ogg",
	5000: "res://assets/neighborhoods/daisy_gardens/audio/DG_SZ.ogg",
	9000: "res://assets/neighborhoods/donalds_dreamland/audio/DL_SZ_activity.ogg",
}

var _fish_fps := 24.0
var _fish_frames: Array = []
var _fish_joints: Dictionary = {}
var _fish_time := 0.0


func _ready() -> void:
	_build_room()
	_place_clerks()
	_ready_fish()
	_play_music()
	_TOON.attach(self)


func _process(delta: float) -> void:
	if _fish_frames.is_empty() or _fish_joints.is_empty():
		return
	_fish_time += delta
	var count := _fish_frames.size()
	var sample := _fish_time * _fish_fps
	var i0 := int(floorf(sample)) % count
	var i1 := (i0 + 1) % count
	var blend := sample - floorf(sample)
	var frame_a: Dictionary = _fish_frames[i0]
	var frame_b: Dictionary = _fish_frames[i1]
	for joint_name in _fish_joints:
		var joint := _fish_joints[joint_name] as Node3D
		if not frame_a.has(joint_name) or not frame_b.has(joint_name):
			continue
		var from_pose := _panda_transform(frame_a[joint_name])
		var to_pose := _panda_transform(frame_b[joint_name])
		joint.transform = from_pose.interpolate_with(to_pose, blend)


func _build_room() -> void:
	var path := "res://assets/interiors/pet_shop/pet_shop_%d.glb" % _DOOR.hood
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Pet shop room missing for hood %d" % _DOOR.hood)
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


func _ready_fish() -> void:
	var shop := find_child("interior_fish", true, false) as Node3D
	if shop == null:
		return
	if not FileAccess.file_exists(_FISH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(_FISH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_fish_fps = float(parsed.get("fps", 16.8))
	_fish_frames = parsed.get("frames", [])
	for joint_name in ["joint_fish1", "joint_fish2"]:
		var joint := shop.find_child(joint_name, true, false) as Node3D
		if joint != null:
			_fish_joints[joint_name] = joint


func _panda_transform(cells: Array) -> Transform3D:
	# The exporter writes Panda's row-major matrix into glTF's column-major slot.
	var basis := Basis(
		Vector3(cells[0], cells[1], cells[2]),
		Vector3(cells[4], cells[5], cells[6]),
		Vector3(cells[8], cells[9], cells[10])
	)
	return Transform3D(basis, Vector3(cells[12], cells[13], cells[14]))


func _play_music() -> void:
	var path := String(_MUSIC.get(_DOOR.hood, _MUSIC[2000]))
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
	player.name = "PetShopMusic"
	player.stream = copy
	player.volume_db = linear_to_db(MUSIC_VOLUME)
	add_child(player)
	player.play()
