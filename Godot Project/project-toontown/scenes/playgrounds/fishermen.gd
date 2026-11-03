extends StaticBody3D

## DistributedNPCFisherman.initToonState stands on npc_fisherman_origin_0 and
## loops neutral at 1.05. createNpcsInZone gives that origin to the fisherman
## because he is the first NPC in his pond zone. DNA and names are NPCToons
## and NPCToonNames. The estate pond has no origin and no fisherman NPC.

const _RATE := 1.05

# name, head, torso, legs, gender, arm, glove, leg, head, shirt, shirt color,
# shorts, shorts color. Sleeve indices are unused, the same as the clerks.
const _CREW := {
	"toontown_central.tscn": ["Fisherman Freddy", "rss", "ls", "l", "m", 17, 0, 17, 17, 1, 6, 1, 1],
	"silly_street.tscn": ["Fisherman Billy", "dls", "ls", "l", "m", 10, 0, 10, 10, 1, 9, 1, 10],
	"loopy_lane.tscn": ["Fisherman Droopy", "cll", "ls", "m", "m", 9, 0, 9, 9, 1, 1, 0, 13],
	"punchline_place.tscn": ["Fisherman Punchy", "fsl", "ss", "l", "m", 21, 0, 21, 21, 1, 5, 0, 12],
	"donalds_dock.tscn": ["Fisherman Furball", "cls", "ms", "m", "m", 3, 0, 3, 3, 0, 27, 0, 17],
	"barnacle_boulevard.tscn": ["Fisherman Barney", "cls", "ms", "l", "m", 4, 0, 4, 4, 1, 11, 0, 19],
	"seaweed_street.tscn": ["Fisherman Reed", "cll", "ms", "l", "m", 8, 0, 8, 8, 1, 9, 1, 0],
	"lighthouse_lane.tscn": ["Fisherman Shane", "cll", "ms", "m", "m", 5, 0, 5, 5, 0, 4, 1, 13],
	"the_burrrgh.tscn": ["Fisherman Frizzy", "rss", "ls", "l", "f", 19, 0, 19, 19, 0, 26, 4, 23],
	"walrus_way.tscn": ["Fisherman Lucille", "rll", "ms", "l", "f", 11, 0, 11, 11, 0, 3, 12, 27],
	"sleet_street.tscn": ["Fisherman Albert", "rls", "ss", "m", "m", 3, 0, 3, 3, 0, 10, 1, 9],
	"polar_place.tscn": ["Fisherman Fredrica", "rss", "ls", "m", "f", 11, 0, 11, 11, 1, 24, 1, 9],
	"minnies_melodyland.tscn": ["Fisherman Fanny", "hsl", "ld", "m", "f", 19, 0, 19, 19, 1, 6, 12, 27],
	"alto_avenue.tscn": ["Fisherman Jed", "hll", "ms", "l", "m", 4, 0, 4, 4, 1, 8, 1, 4],
	"baritone_boulevard.tscn": ["Fisherman Larry", "cls", "ls", "m", "m", 3, 0, 3, 3, 1, 3, 1, 16],
	"tenor_terrace.tscn": ["Fisherman Walden", "hsl", "ms", "l", "m", 22, 0, 22, 22, 1, 0, 0, 6],
	"daisy_gardens.tscn": ["Fisherman Flora", "cll", "md", "s", "f", 4, 0, 4, 4, 1, 22, 19, 27],
	"elm_street.tscn": ["Fisherman Sally", "dll", "md", "m", "f", 7, 0, 7, 7, 0, 23, 17, 27],
	"maple_street.tscn": ["Fisherman Lily", "hss", "ms", "s", "f", 3, 0, 3, 3, 0, 11, 16, 27],
	"oak_street.tscn": ["Fisherman Rose", "cls", "ss", "m", "f", 10, 0, 10, 10, 0, 2, 11, 27],
	"donalds_dreamland.tscn": ["Fisherman Freud", "csl", "ss", "l", "m", 7, 0, 7, 7, 0, 8, 0, 4],
	"lullaby_lane.tscn": ["Fisherman Taylor", "rll", "ss", "l", "m", 17, 0, 17, 17, 1, 0, 1, 6],
	"pajama_place.tscn": ["Fisherman Jung", "dls", "ss", "l", "m", 14, 0, 14, 14, 0, 7, 0, 10],
}

var _actor: ToonActor


static func place(host: Node) -> void:
	if host == null or Engine.is_editor_hint():
		return
	if host.find_child("Fishermen", true, false) != null:
		return
	var row: Array = _CREW.get(host.scene_file_path.get_file(), [])
	if row.is_empty():
		return
	var origin := host.find_child("npc_fisherman_origin_0", true, false) as Node3D
	if origin == null:
		return
	var body := (load("res://scenes/playgrounds/fishermen.gd") as GDScript).new() as StaticBody3D
	body.name = "Fishermen"
	origin.add_child(body)
	body.global_position = origin.global_position + Vector3(0.0, 0.02, 0.0)
	body.global_basis = Basis.IDENTITY
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
	body.call("watch", actor)


func watch(actor: ToonActor) -> void:
	_actor = actor


func _process(delta: float) -> void:
	if _actor == null:
		return
	_actor.set_locomotion(0.0, false, false, delta * _RATE)


static func _style(row: Array) -> ToonStyle:
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


static func _face(actor: Node3D, origin: Node3D) -> void:
	var ahead := origin.to_global(Vector3(0.0, 1.0, 0.0)) - origin.global_position
	ahead.y = 0.0
	var heading := 0.0
	if ahead.length_squared() > 0.0001:
		heading = rad_to_deg(atan2(-ahead.x, -ahead.z))
	var body_scale := actor.transform.basis.get_scale().x
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	upright = upright.rotated(Vector3.UP, deg_to_rad(heading))
	actor.transform.basis = upright.scaled(Vector3.ONE * body_scale)
