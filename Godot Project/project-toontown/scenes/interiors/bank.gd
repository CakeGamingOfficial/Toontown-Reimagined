extends Node3D

## Zone 2514, the toon interior DistributedToonInterior builds for the bank.
## Banker Bob stands on npc_origin_0, the only toon createNpcsInZone
## places in that zone. Paintings tagged __billboard turn toward the camera
## the way the other toon interiors do.
##
## The original bank is that plain shop room. The floor and walls stretch back
## from the door so a vault fits behind the counter. That stretch, and the
## dressing, are not in the original game. The props are the estate jellybean
## machine, the drop-gag safe, the jellybean jar, the dollar bills, and the
## cashbot money bag, stack, and register.

const _DOOR := preload("res://scenes/interiors/bank_door.gd")
const _COLLISION := preload("res://scenes/playgrounds/playground_collision.gd")
const _TOON := preload("res://scenes/playgrounds/playground_toon.gd")
const _ROOM := "res://assets/interiors/bank/bank.glb"
const _MUSIC := "res://assets/neighborhoods/toontown_central/audio/TC_SZ_activity.mp3"
const MUSIC_VOLUME := 0.7
const _COUNTER_TOP := 2.03
const _FLOOR_Y := -0.025
# The shell stretches back from the door line so the vault fits behind Bob.
# Furniture, the door, and npc_origin_0 stay at the original size.
const _STRETCH := 1.32
const _DOOR_LINE := 4.0
const _SHELL: PackedStringArray = [
	"random_tc1_TI_floor",
	"ceiling",
	"doors_and_windows",
	"random_tc1_TI_wallpaper_border",
	"random_tc1_TI_wallpaper",
	"random_tc1_TI_wainscotting",
]

# The baked room is a living-room shop. These nodes are the couches, lamps,
# and other pieces that come out so the counter can read as a teller line.
const _LOBBY: PackedStringArray = [
	"random_mo1_TI_bookcase",
	"random_mo1_TI_chair",
	"random_mo1_TI_coatrack",
	"random_mo1_TI_lamp_tall",
	"random_mo2_TI_lamp_tall",
	"random_mo1_TI_umbrella_stand",
	"random_mo1_TI_couch_1person",
	"random_mo1_TI_couch_2person",
	"random_mo2_TI_couch_2person",
	"random_mo1_TI_ending_table",
]

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
	_lengthen(geom)
	_clear_lobby(geom)
	_seat_rug(geom)
	_dress(geom)
	geom.set_script(_COLLISION)
	add_child(geom)
	_DOOR.seal(_DOOR.find_interior_door(self))
	_collect_billboards(geom)


func _lengthen(room: Node) -> void:
	# The shell's parent is still Z-up. Local Y runs the depth of the room
	# (world -Z) and local Z is up. Scaling Z dropped the floor and left the
	# rug and the money bags floating. The door is local Y = -4, and it stays.
	var shift := -_DOOR_LINE * (1.0 - _STRETCH)
	for shell_name in _SHELL:
		var shell := room.find_child(shell_name, true, false) as Node3D
		if shell == null:
			continue
		shell.position.y = shift
		shell.scale.y = _STRETCH


func _seat_rug(room: Node) -> void:
	# The floor is a flat sheet at -0.025. The rug's mesh is 0.025 above its
	# node, and this interior maps the node's Z onto world Y.
	var rug := room.find_child("random_mo1_TI_rug", true, false) as Node3D
	if rug == null:
		return
	rug.position.z = _FLOOR_Y - 0.025 + 0.004


func _clear_lobby(room: Node) -> void:
	for prop_name in _LOBBY:
		for node in room.find_children(prop_name, "", true, false):
			_hide_meshes(node)


func _hide_meshes(node: Node) -> void:
	if node is GeometryInstance3D:
		node.visible = false
	for child in node.get_children():
		_hide_meshes(child)


func _dress(room: Node3D) -> void:
	# Estate jellybean machines, full size, behind the counter and facing the door.
	for side in [-4.9, 4.9]:
		_prop(room, "res://assets/interiors/bank/props/teller.glb", Vector3(side, 0.0, -24.9), PI, 1.0)
		_box(room, Vector3(side, 4.23, -25.1), Vector3(4.45, 8.44, 4.87))
	# Drop-gag safes across the vault, with bags against the new back wall.
	for side in [-6.0, 0.0, 6.0]:
		_prop(room, "res://assets/interiors/bank/props/vault_safe.glb", Vector3(side, 0.693, -29.96), PI, 1.15)
		_box(room, Vector3(side, 2.16, -30.18), Vector3(4.04, 4.31, 3.16))
	for side in [-7.2, -2.4, 2.4, 7.2]:
		var bag := Vector3(side, _FLOOR_Y, -36.3)
		_prop(room, "res://assets/interiors/bank/props/money_bag.glb", bag, 0.0, 0.5)
		_box(room, bag + Vector3(0.0, 1.31, 0.05), Vector3(2.89, 2.63, 2.17))
	for side in [-3.4, 3.4]:
		_prop(room, "res://assets/interiors/bank/props/money_stack.glb", Vector3(side, 0.006, -33.6), PI, 0.7)
	for side in [-4.6, 4.6]:
		_prop(room, "res://assets/interiors/bank/props/cash_register.glb", Vector3(side, _COUNTER_TOP + 0.003, -19.31), PI, 0.13)
	for side in [-2.15, 2.15]:
		_prop(room, "res://assets/interiors/bank/props/money_stack.glb", Vector3(side, _COUNTER_TOP + 0.004, -19.31), PI + side * 0.08, 0.42)
	for side in [-6.15, 6.15]:
		_tipped(room, "res://assets/props/jellybean_jar.glb", Vector3(side, _COUNTER_TOP + 0.189, -19.31), 0.32)
	_bill(room, "res://assets/battle/props/1dollar.glb", Vector3(-0.75, _COUNTER_TOP + 0.02, -19.15), 0.4)
	_bill(room, "res://assets/battle/props/5dollar.glb", Vector3(0.15, _COUNTER_TOP + 0.02, -19.45), -0.5)
	_bill(room, "res://assets/battle/props/10dollar.glb", Vector3(0.9, _COUNTER_TOP + 0.02, -19.2), 0.15)
	for spot in [Vector3(-8.4, _FLOOR_Y, -12.0), Vector3(-8.2, _FLOOR_Y, -6.6), Vector3(8.4, _FLOOR_Y, -12.0), Vector3(8.2, _FLOOR_Y, -6.6)]:
		_prop(room, "res://assets/interiors/bank/props/money_bag.glb", spot, spot.x * 0.03, 0.42)
		_box(room, spot + Vector3(0.0, 1.1, 0.0), Vector3(2.43, 2.21, 1.82))


func _prop(room: Node3D, path: String, pos: Vector3, yaw: float, amount: float) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Bank prop is missing: " + path)
		return
	var prop := packed.instantiate() as Node3D
	prop.name = path.get_file().get_basename()
	room.add_child(prop)
	prop.position = pos
	prop.rotation = Vector3(0.0, yaw, 0.0)
	prop.scale = Vector3.ONE * amount


## The jar file is still Z-up. Tip local Z onto Y so it sits on the counter.
func _tipped(room: Node3D, path: String, pos: Vector3, amount: float) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Bank prop is missing: " + path)
		return
	var prop := packed.instantiate() as Node3D
	prop.name = path.get_file().get_basename()
	room.add_child(prop)
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	prop.transform = Transform3D(upright.scaled(Vector3.ONE * amount), pos)


func _bill(room: Node3D, path: String, pos: Vector3, yaw: float) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Bank prop is missing: " + path)
		return
	var prop := packed.instantiate() as Node3D
	prop.name = path.get_file().get_basename()
	room.add_child(prop)
	var flat := Basis().rotated(Vector3.RIGHT, PI * 0.5).rotated(Vector3.UP, yaw)
	prop.transform = Transform3D(flat.scaled(Vector3(1.3, 1.3, 1.3)), pos)


func _box(room: Node3D, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "PropSolid"
	room.add_child(body)
	body.position = center
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)


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
