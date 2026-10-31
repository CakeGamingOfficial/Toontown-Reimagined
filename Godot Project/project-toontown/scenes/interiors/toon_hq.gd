extends Node3D

## DistributedHQInterior. Every playground and street Toon HQ uses this room.
## Cream and the crashed piano stay hidden. The four HQ Officers for the
## exterior's zone stand on npc_origin in npc-id order. Both round doors
## lead back out to the matching exterior door.

const _DOOR := preload("res://scenes/interiors/toon_hq_door.gd")
const _TOON := preload("res://scenes/playgrounds/playground_toon.gd")
const _ROOM := "res://assets/interiors/hq/hq_interior.glb"
const _FLOORS := "res://assets/interiors/hq/collision.json"
const _WALLS := "res://assets/interiors/hq/solid_collision.json"
const MUSIC_VOLUME := 0.8
const _MUSIC: Dictionary = {
	1000: "res://assets/neighborhoods/donalds_dock/audio/DD_nbrhood.ogg",
	2000: "res://assets/neighborhoods/toontown_central/audio/TC_nbrhood.ogg",
	3000: "res://assets/neighborhoods/the_burrrgh/audio/TB_nbrhood.ogg",
	4000: "res://assets/neighborhoods/minnies_melodyland/audio/MM_nbrhood.ogg",
	5000: "res://assets/neighborhoods/daisy_gardens/audio/DG_nbrhood.ogg",
	9000: "res://assets/neighborhoods/donalds_dreamland/audio/DL_nbrhood.ogg",
}

# NPCToons HQ groups, keyed by interior zone. head, torso, legs, gender,
# arm, glove, leg, head, top texture, top color, bottom texture, bottom color.
const _OFFICERS: Dictionary = {
	1507: [
		["HQ Officer", "mls", "ss", "l", "m", 17, 0, 17, 17, 1, 11, 0, 15],
		["HQ Officer", "hsl", "md", "l", "f", 10, 0, 10, 10, 1, 24, 24, 27],
		["HQ Officer", "hss", "ms", "l", "m", 3, 0, 3, 3, 1, 11, 0, 9],
		["HQ Officer", "cll", "ss", "l", "f", 18, 0, 18, 18, 1, 25, 19, 27],
	],
	1629: [
		["HQ Officer", "hsl", "ls", "l", "m", 6, 0, 6, 6, 0, 6, 1, 1],
		["HQ Officer", "hss", "ls", "l", "f", 22, 0, 22, 22, 0, 8, 14, 27],
		["HQ Officer", "cll", "ss", "l", "m", 13, 0, 13, 13, 1, 6, 1, 16],
		["HQ Officer", "csl", "ld", "l", "f", 6, 0, 6, 6, 1, 9, 2, 2],
	],
	1729: [
		["HQ Officer", "fll", "ss", "s", "m", 4, 0, 4, 4, 1, 1, 1, 1],
		["HQ Officer", "fss", "ld", "s", "f", 19, 0, 19, 19, 1, 2, 7, 11],
		["HQ Officer", "fls", "ms", "s", "m", 12, 0, 12, 12, 1, 2, 1, 16],
		["HQ Officer", "rsl", "ls", "m", "f", 3, 0, 3, 3, 1, 3, 23, 27],
	],
	1835: [
		["HQ Officer", "css", "ms", "m", "m", 7, 0, 7, 7, 1, 7, 0, 9],
		["HQ Officer", "cls", "ms", "m", "f", 24, 0, 24, 24, 0, 12, 0, 7],
		["HQ Officer", "dsl", "ls", "m", "m", 15, 0, 15, 15, 0, 8, 0, 20],
		["HQ Officer", "dss", "sd", "m", "f", 8, 0, 8, 8, 0, 21, 4, 5],
	],
	2520: [
		["HQ Officer", "dss", "ms", "l", "m", 10, 0, 10, 10, 1, 5, 1, 20],
		["HQ Officer", "fll", "ss", "l", "m", 3, 0, 3, 3, 1, 5, 1, 17],
		["HQ Officer", "fsl", "md", "l", "f", 18, 0, 18, 18, 1, 8, 11, 27],
		["HQ Officer", "fls", "ls", "l", "f", 11, 0, 11, 11, 1, 8, 8, 4],
	],
	2671: [
		["HQ Officer", "mls", "ms", "m", "m", 15, 0, 15, 15, 1, 10, 0, 16],
		["HQ Officer", "hsl", "ss", "m", "m", 7, 0, 7, 7, 1, 10, 0, 13],
		["HQ Officer", "hss", "ld", "m", "f", 23, 0, 23, 23, 1, 23, 24, 27],
		["HQ Officer", "cll", "sd", "m", "f", 14, 0, 14, 14, 1, 24, 7, 4],
	],
	2742: [
		["HQ Officer", "fss", "ms", "s", "m", 19, 0, 19, 19, 0, 7, 0, 11],
		["HQ Officer", "fls", "ss", "s", "m", 13, 0, 13, 13, 0, 7, 0, 6],
		["HQ Officer", "rsl", "md", "s", "f", 4, 0, 4, 4, 0, 11, 16, 27],
		["HQ Officer", "rss", "sd", "s", "f", 21, 0, 21, 21, 0, 12, 0, 8],
	],
	2832: [
		["HQ Officer", "dss", "ss", "m", "m", 9, 0, 9, 9, 0, 10, 1, 12],
		["HQ Officer", "dss", "ss", "m", "m", 8, 0, 8, 8, 1, 0, 1, 9],
		["HQ Officer", "fll", "md", "m", "f", 24, 0, 24, 24, 1, 0, 16, 27],
		["HQ Officer", "fsl", "ls", "m", "f", 16, 0, 16, 16, 1, 1, 3, 1],
	],
	3508: [
		["HQ Officer", "cls", "ms", "m", "m", 4, 0, 4, 4, 1, 9, 0, 18],
		["HQ Officer", "dsl", "ss", "m", "f", 19, 0, 19, 19, 1, 22, 25, 27],
		["HQ Officer", "dss", "ls", "m", "m", 12, 0, 12, 12, 1, 10, 0, 12],
		["HQ Officer", "fll", "ms", "m", "m", 4, 0, 4, 4, 0, 11, 0, 9],
	],
	3654: [
		["HQ Officer", "mls", "ls", "m", "m", 21, 0, 21, 21, 0, 7, 0, 17],
		["HQ Officer", "hll", "ls", "m", "f", 14, 0, 14, 14, 0, 11, 0, 12],
		["HQ Officer", "hss", "ss", "m", "m", 6, 0, 6, 6, 0, 7, 0, 11],
		["HQ Officer", "cll", "ls", "m", "m", 20, 0, 20, 20, 0, 8, 0, 6],
	],
	3739: [
		["HQ Officer", "fll", "ls", "s", "m", 12, 0, 12, 12, 1, 2, 1, 14],
		["HQ Officer", "fsl", "md", "s", "f", 4, 0, 4, 4, 1, 4, 3, 1],
		["HQ Officer", "fls", "ms", "s", "m", 19, 0, 19, 19, 1, 3, 1, 6],
		["HQ Officer", "rll", "ss", "s", "m", 12, 0, 12, 12, 1, 4, 1, 1],
	],
	3801: [
		["HQ Officer", "css", "ms", "l", "m", 9, 0, 9, 9, 0, 0, 1, 2],
		["HQ Officer", "cls", "ms", "l", "f", 1, 0, 1, 1, 0, 0, 3, 25],
		["HQ Officer", "dsl", "ls", "l", "m", 17, 0, 17, 17, 0, 0, 1, 17],
		["HQ Officer", "dss", "md", "l", "f", 10, 0, 10, 10, 0, 1, 10, 27],
	],
	4504: [
		["HQ Officer", "fll", "ss", "m", "m", 5, 0, 5, 5, 0, 2, 1, 17],
		["HQ Officer", "fsl", "md", "m", "f", 21, 0, 21, 21, 0, 3, 10, 27],
		["HQ Officer", "fls", "ls", "m", "f", 13, 0, 13, 13, 1, 3, 2, 11],
		["HQ Officer", "rll", "ss", "m", "f", 4, 0, 4, 4, 1, 4, 24, 27],
	],
	4659: [
		["HQ Officer", "dll", "ms", "l", "m", 16, 0, 16, 16, 1, 8, 0, 16],
		["HQ Officer", "dss", "ls", "l", "f", 9, 0, 9, 9, 1, 21, 11, 27],
		["HQ Officer", "fll", "ss", "l", "f", 24, 0, 24, 24, 0, 22, 19, 27],
		["HQ Officer", "fsl", "md", "l", "f", 16, 0, 16, 16, 0, 22, 17, 27],
	],
	4739: [
		["HQ Officer", "hss", "ss", "l", "m", 14, 0, 14, 14, 0, 6, 0, 4],
		["HQ Officer", "cll", "ld", "l", "f", 6, 0, 6, 6, 1, 8, 10, 27],
		["HQ Officer", "css", "sd", "l", "f", 22, 0, 22, 22, 1, 8, 25, 27],
		["HQ Officer", "cls", "ls", "l", "f", 14, 0, 14, 14, 1, 9, 17, 27],
	],
	4873: [
		["HQ Officer", "rss", "ls", "m", "m", 12, 0, 12, 12, 0, 2, 0, 15],
		["HQ Officer", "mss", "sd", "m", "f", 3, 0, 3, 3, 0, 4, 26, 27],
		["HQ Officer", "hll", "ms", "m", "f", 19, 0, 19, 19, 0, 5, 4, 25],
		["HQ Officer", "hsl", "ld", "m", "f", 11, 0, 11, 11, 0, 5, 17, 27],
	],
	5502: [
		["HQ Officer", "fls", "ls", "s", "m", 14, 0, 14, 14, 1, 7, 0, 20],
		["HQ Officer", "rll", "ms", "s", "m", 6, 0, 6, 6, 0, 8, 0, 17],
		["HQ Officer", "rss", "ms", "s", "f", 22, 0, 22, 22, 0, 12, 26, 27],
		["HQ Officer", "rls", "ld", "s", "f", 13, 0, 13, 13, 0, 21, 4, 11],
	],
	5627: [
		["HQ Officer", "mls", "ss", "l", "m", 17, 0, 17, 17, 0, 7, 0, 0],
		["HQ Officer", "hsl", "ls", "l", "m", 10, 0, 10, 10, 0, 8, 0, 18],
		["HQ Officer", "hss", "ls", "l", "f", 2, 0, 2, 2, 0, 12, 7, 4],
		["HQ Officer", "cll", "ms", "l", "f", 17, 0, 17, 17, 0, 21, 14, 27],
	],
	5728: [
		["HQ Officer", "fls", "ss", "l", "m", 21, 0, 21, 21, 0, 0, 1, 9],
		["HQ Officer", "rsl", "ss", "l", "m", 14, 0, 14, 14, 1, 0, 1, 2],
		["HQ Officer", "rss", "md", "l", "f", 6, 0, 6, 6, 1, 1, 23, 27],
		["HQ Officer", "mss", "ls", "l", "f", 22, 0, 22, 22, 1, 1, 10, 27],
	],
	5802: [
		["HQ Officer", "rss", "ms", "l", "f", 13, 0, 13, 13, 0, 11, 1, 12],
		["HQ Officer", "mss", "ss", "l", "f", 4, 0, 4, 4, 0, 12, 17, 27],
		["HQ Officer", "hll", "ls", "l", "m", 19, 0, 19, 19, 1, 8, 1, 18],
		["HQ Officer", "hsl", "ls", "l", "f", 12, 0, 12, 12, 1, 12, 19, 27],
	],
	9505: [
		["HQ Officer", "rll", "ms", "l", "f", 16, 0, 16, 16, 1, 7, 3, 8],
		["HQ Officer", "rss", "ld", "l", "f", 9, 0, 9, 9, 1, 8, 19, 27],
		["HQ Officer", "rls", "ms", "l", "m", 22, 0, 22, 22, 1, 6, 0, 1],
		["HQ Officer", "mls", "ms", "l", "m", 15, 0, 15, 15, 1, 6, 0, 19],
	],
	9652: [
		["HQ Officer", "dss", "ls", "l", "f", 2, 0, 2, 2, 0, 27, 0, 0],
		["HQ Officer", "dls", "ss", "l", "m", 17, 0, 17, 17, 1, 12, 0, 17],
		["HQ Officer", "fsl", "ls", "l", "m", 10, 0, 10, 10, 1, 0, 0, 14],
		["HQ Officer", "fls", "ms", "l", "m", 3, 0, 3, 3, 1, 0, 0, 11],
	],
	9756: [
		["HQ Officer", "csl", "ls", "l", "f", 22, 0, 22, 22, 1, 7, 12, 27],
		["HQ Officer", "cls", "ss", "l", "m", 14, 0, 14, 14, 1, 5, 0, 19],
		["HQ Officer", "dll", "ls", "l", "m", 6, 0, 6, 6, 1, 6, 0, 16],
		["HQ Officer", "dss", "ms", "l", "m", 20, 0, 20, 20, 0, 6, 0, 13],
	],
}

func _ready() -> void:
	_build_room()
	_place_officers()
	_place_board()
	_play_music()
	_TOON.attach(self)


func _build_room() -> void:
	var packed := load(_ROOM) as PackedScene
	if packed == null:
		push_error("Toon HQ room is missing")
		return
	var geom := packed.instantiate()
	geom.name = "Geometry"
	add_child(geom)
	_build_collision(geom)
	for index in 2:
		_DOOR.seal(_DOOR.find_interior_door(self, index))
	_DOOR.tint_interior(self)


func _place_officers() -> void:
	var roster: Array = _OFFICERS.get(_DOOR.zone_id, _OFFICERS[2520])
	for index in roster.size():
		var origin := find_child("npc_origin_%d" % index, true, false) as Node3D
		if origin == null:
			continue
		var row: Array = roster[index]
		var body := StaticBody3D.new()
		body.name = "Officer%d" % index
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


func _place_board() -> void:
	# buildLeaderBoard hangs "Toon Platoon" and ten empty rows on empty_board.
	var board := find_child("empty_board", true, false) as Node3D
	if board == null:
		return
	var mount: Node3D = board
	if board.get_child_count() > 0 and board.get_child(0) is Node3D:
		mount = board.get_child(0) as Node3D
	var holder := Node3D.new()
	holder.name = "LeaderBoard"
	holder.position = Vector3(0.1, 0.0, 4.5)
	holder.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	holder.scale = Vector3(0.9, 0.9, 0.9)
	mount.add_child(holder)
	_board_line(holder, "Toon Platoon", Vector3(0.0, 0.0, 0.0), Color(0.5, 0.75, 0.7), true)
	for index in 10:
		var row := Node3D.new()
		row.position = Vector3(0.0, 0.0, -1.0 - float(index))
		holder.add_child(row)
		_board_line(row, "-", Vector3(-4.0, 0.0, 0.0), Color(1.0, 1.0, 1.0, 0.7), false)
		_board_line(row, "-", Vector3(1.6, 0.0, 0.0), Color(1.0, 1.0, 0.1, 0.7), false)


func _board_line(parent: Node3D, text: String, at: Vector3, color: Color, title: bool) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.font = ToonGui.sign_font() if title else ToonGui.font()
	label.font_size = 48
	label.pixel_size = 0.02
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if title else HORIZONTAL_ALIGNMENT_LEFT
	label.no_depth_test = false
	parent.add_child(label)


func _style(row: Array) -> ToonStyle:
	var style := ToonStyle.new()
	var parts := String(row[0]).split(" ")
	style.first_name = parts[0]
	if parts.size() > 1:
		style.last_name = parts[1]
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


func _build_collision(room: Node3D) -> void:
	_add_model_collision(room)
	var faces := _read_faces(_FLOORS)
	var floors := PackedVector3Array()
	for index in range(0, faces.size(), 3):
		var a := faces[index]
		var b := faces[index + 1]
		var c := faces[index + 2]
		var normal := (b - a).cross(c - a)
		var length := normal.length()
		if length < 0.0001:
			continue
		if normal.y > length * 0.5:
			floors.append(a)
			floors.append(b)
			floors.append(c)
	_add_floor(room, floors)


func _read_faces(path: String) -> PackedVector3Array:
	var faces := PackedVector3Array()
	if not FileAccess.file_exists(path):
		return faces
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return faces
	for triangle in parsed.get("triangles", []):
		if triangle.size() < 9:
			continue
		faces.append(Vector3(float(triangle[0]), float(triangle[1]), float(triangle[2])))
		faces.append(Vector3(float(triangle[3]), float(triangle[4]), float(triangle[5])))
		faces.append(Vector3(float(triangle[6]), float(triangle[7]), float(triangle[8])))
	return faces


func _add_model_collision(room: Node3D) -> void:
	var faces := _read_faces(_WALLS)
	if faces.is_empty():
		return
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var solid := StaticBody3D.new()
	solid.name = "HQWalls"
	var collision := CollisionShape3D.new()
	collision.shape = shape
	solid.add_child(collision)
	room.add_child(solid)


func _add_floor(room: Node3D, faces: PackedVector3Array) -> void:
	if faces.is_empty():
		return
	const THICK := 0.35
	const PIT := -5.0
	const LIP := 1.6
	var slab := StaticBody3D.new()
	slab.name = "HQFloor"
	for index in range(0, faces.size(), 3):
		var a := faces[index]
		var b := faces[index + 1]
		var c := faces[index + 2]
		_add_prism(slab, [a, b, c], THICK)
		_add_ramp_lip(slab, a, b, c, PIT, LIP, THICK)
	var hole := BoxShape3D.new()
	hole.size = Vector3(19.0, THICK, 18.0)
	var hole_shape := CollisionShape3D.new()
	hole_shape.shape = hole
	hole_shape.position = Vector3(-5.5, PIT - THICK * 0.5, -30.0)
	slab.add_child(hole_shape)
	room.add_child(slab)


func _add_prism(slab: StaticBody3D, points: Array, thick: float) -> void:
	var drop := Vector3(0.0, -thick, 0.0)
	var cloud := PackedVector3Array()
	for point in points:
		var corner := point as Vector3
		cloud.append(corner)
		cloud.append(corner + drop)
	var shape := ConvexPolygonShape3D.new()
	shape.points = cloud
	var collision := CollisionShape3D.new()
	collision.shape = shape
	slab.add_child(collision)


func _add_ramp_lip(slab: StaticBody3D, a: Vector3, b: Vector3, c: Vector3, pit: float, reach: float, thick: float) -> void:
	var points: Array[Vector3] = [a, b, c]
	points.sort_custom(func(left: Vector3, right: Vector3) -> bool: return left.y < right.y)
	var low: Vector3 = points[0]
	var mid: Vector3 = points[1]
	var high: Vector3 = points[2]
	if high.y - low.y < 0.5 or mid.y - low.y > 0.2:
		return
	var edge := Vector3(mid.x - low.x, 0.0, mid.z - low.z)
	if edge.length() < 0.001:
		return
	var outward := Vector3(-edge.z, 0.0, edge.x).normalized()
	var toward_high := Vector3(high.x - low.x, 0.0, high.z - low.z)
	if outward.dot(toward_high) > 0.0:
		outward = -outward
	var pit_low := Vector3(low.x, pit, low.z) + outward * reach
	var pit_mid := Vector3(mid.x, pit, mid.z) + outward * reach
	_add_prism(slab, [low, mid, pit_mid, pit_low], thick)


func _play_music() -> void:
	var path := String(_MUSIC.get(_DOOR.hood(), _MUSIC[2000]))
	if not FileAccess.file_exists(path):
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
