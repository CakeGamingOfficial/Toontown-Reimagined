extends Node

## TutorialHQBuildingAI's interior. Door 0 opens after the Flunky fight.
## The room is phase_3.5 HQ_interior, with cream and the crashed piano hidden
## the way DistributedHQInterior.generate leaves them. HQ Harry stands on
## npc_origin_0.

const INTERIOR_PATH := "res://assets/interiors/hq/hq_interior.glb"
const COLLISION_PATH := "res://assets/interiors/hq/collision.json"
const DOOR_SFX := "res://assets/interiors/hq/Door_Open_1.ogg"
const ROOM_SHIFT := Vector3(0.0, 0.0, 240.0)
# door_origin_0, then six units back through the doorway, facing into the room.
const STAND := Vector3(-5.0, 0.2, 7.0)
const STAND_HEADING := 0.0
# npc_origin_0. The origin sits on the pit floor.
const HARRY_SPOT := Vector3(-10.0, -5.0, -24.5)
const HARRY_HEADING := 180.0

var _host: Node
var _right_door: Node3D
var _right_hole: Node3D
var _flat: Node3D
var _door_point := Vector3.ZERO
var _room: Node3D
var _harry: ToonActor
var _inside := false
var _busy := false


func inside() -> bool:
	return _inside


func setup(host: Node) -> void:
	_host = host
	if _room != null:
		_seal_front_door()
		return
	var street := host.get_node_or_null("TutorialStreet") as Node3D
	if street == null:
		return
	var landmark := _find(street, "tb1_toon_landmark_hqTT_DNARoot")
	if landmark == null:
		return
	var door := _find(landmark, "door_0")
	if door == null:
		return
	_right_door = _find(door, "rightDoor_0")
	_right_hole = _find(door, "doorFrameHoleRight_0")
	_flat = _find(door, "door_flat_0")
	_lift_holes(door)
	var origin := _find(landmark, "door_origin_0")
	_door_point = origin.global_position if origin else door.global_position
	_seal_front_door()
	_build_room()


func consider(body: CharacterBody3D) -> void:
	if _inside or _busy or body == null or _room == null:
		return
	var here := Vector2(body.global_position.x, body.global_position.z)
	# The front step is just outside the arch, on the playground side.
	var door := Vector2(_door_point.x - 4.0, _door_point.z)
	if here.distance_to(door) > 6.0:
		return
	if not Input.is_physical_key_pressed(KEY_W):
		return
	enter()


func enter() -> void:
	if _inside or _busy:
		return
	_busy = true
	if _host.has_method("set_cutscene"):
		_host.call("set_cutscene", true)
	_play_open()
	await get_tree().create_timer(0.7).timeout
	await _fade(1.0, 0.45)
	_show_room()
	await get_tree().create_timer(0.25).timeout
	await _fade(0.0, 0.45)
	if _host.has_method("set_cutscene"):
		_host.call("set_cutscene", false)
	_busy = false


func _seal_front_door() -> void:
	# Closed HQ doors keep the frame holes hidden. The flat stays up.
	var street := _host.get_node_or_null("TutorialStreet") as Node
	if street == null:
		return
	for hole_name in ["doorFrameHoleRight_0", "doorFrameHoleLeft_0"]:
		var hole := _find(street, hole_name)
		if hole:
			hole.visible = false


func _play_open() -> void:
	var stream := load(DOOR_SFX) as AudioStream
	if stream:
		var speaker := AudioStreamPlayer.new()
		speaker.stream = stream
		speaker.volume_db = -4.0
		add_child(speaker)
		speaker.play()
		speaker.finished.connect(speaker.queue_free)
	if _flat:
		_flat.visible = false
	# Only the opened side reveals its black card. The other panel stays shut.
	if _right_hole:
		_right_hole.visible = true
	if _right_door == null:
		return
	_right_door.visible = true
	# rightSwing is set, so DistributedDoor turns the right panel +100 degrees
	# on its heading. That heading is the parent's Z, and positive swings the
	# panel out toward the sidewalk.
	var closed := _right_door.transform.basis
	var tween := create_tween()
	tween.tween_method(func(degrees: float) -> void:
		if _right_door == null:
			return
		_right_door.transform.basis = Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(degrees)) * closed
	, 0.0, 100.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _lift_holes(door: Node3D) -> void:
	# The exporter nested doorFrameHole under the flat. Hiding the flat was
	# hiding the black card with it, so the arch looked straight through the
	# building. Lift the holes out, then keep them hidden until the door opens.
	for hole_name in ["doorFrameHoleRight_0", "doorFrameHoleLeft_0"]:
		var hole := _find(door, hole_name)
		if hole == null:
			continue
		if _flat and _flat.is_ancestor_of(hole):
			var kept := hole.global_transform
			hole.reparent(door)
			hole.global_transform = kept
		hole.visible = false
		_blacken(hole)


func _blacken(hole: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0, 0, 1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_paint(hole, mat)


func _paint(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_paint(child, mat)


func _build_room() -> void:
	var packed := load(INTERIOR_PATH) as PackedScene
	if packed == null:
		return
	_room = packed.instantiate()
	_room.name = "HQInterior"
	_room.position = ROOM_SHIFT
	_room.visible = false
	_host.add_child(_room)
	_build_collision()
	_spawn_harry()


func _show_room() -> void:
	var street := _host.get_node_or_null("TutorialStreet") as Node3D
	if street:
		street.visible = false
	_room.visible = true
	_inside = true
	if _host.has_method("place_player"):
		_host.call("place_player", ROOM_SHIFT + STAND, STAND_HEADING)
	if _host.has_method("note_plaza"):
		_host.call("note_plaza", ROOM_SHIFT + STAND, STAND_HEADING)
	if _host.has_method("settle_camera"):
		_host.call("settle_camera")
	if _harry:
		_harry.visible = true


func _spawn_harry() -> void:
	# TutorialHQBuildingAI: ("dls", "ms", "m", "m", 6, 0, 6, 6, 0, 10, 0, 10, 2, 9)
	var style := ToonStyle.new()
	style.first_name = "HQ"
	style.last_name = "Harry"
	style.gender = "m"
	style.head = "dls"
	style.torso = "ms"
	style.legs = "m"
	style.arm_color = 6
	style.glove_color = 0
	style.leg_color = 6
	style.head_color = 6
	style.top_tex = 0
	style.top_color = 10
	style.bot_tex = 2
	style.bot_color = 9
	_harry = ToonActor.new()
	_harry.name = "HQ Harry"
	_room.add_child(_harry)
	_harry.position = HARRY_SPOT
	_harry.show_style(style)
	_harry.visible = false
	if _host.has_method("face_actor"):
		_host.call("face_actor", _harry, HARRY_HEADING)
	if _host.has_method("add_nametag"):
		_host.call("add_nametag", _harry, "HQ Harry", Color(0.86, 0.16, 0.14))


func _build_collision() -> void:
	if not FileAccess.file_exists(COLLISION_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COLLISION_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var faces := PackedVector3Array()
	for triangle in parsed.get("triangles", []):
		if triangle.size() < 9:
			continue
		faces.append(Vector3(float(triangle[0]), float(triangle[1]), float(triangle[2])))
		faces.append(Vector3(float(triangle[3]), float(triangle[4]), float(triangle[5])))
		faces.append(Vector3(float(triangle[6]), float(triangle[7]), float(triangle[8])))
	if faces.is_empty():
		return
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var solid := StaticBody3D.new()
	solid.name = "HQCollision"
	var collision := CollisionShape3D.new()
	collision.shape = shape
	solid.add_child(collision)
	_room.add_child(solid)
	_add_floor(faces)


func _add_floor(faces: PackedVector3Array) -> void:
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	var found := false
	for index in range(0, faces.size(), 3):
		var a := faces[index]
		var b := faces[index + 1]
		var c := faces[index + 2]
		var normal := (b - a).cross(c - a)
		if absf(normal.y) < absf(normal.x) or absf(normal.y) < absf(normal.z) or normal.y <= 0.0:
			continue
		if absf(a.y - b.y) > 0.15 or absf(a.y - c.y) > 0.15 or a.y < -0.4 or a.y > 0.4:
			continue
		found = true
		for point in [a, b, c]:
			low = low.min(point)
			high = high.max(point)
	if not found:
		return
	var slab := StaticBody3D.new()
	slab.name = "HQFloor"
	var box := BoxShape3D.new()
	box.size = Vector3(high.x - low.x, 1.0, high.z - low.z)
	var collision := CollisionShape3D.new()
	collision.shape = box
	collision.position = Vector3((low.x + high.x) * 0.5, high.y - 0.5, (low.z + high.z) * 0.5)
	slab.add_child(collision)
	_room.add_child(slab)


func _fade(alpha: float, seconds: float) -> void:
	var layer: Node = _host.call("hud") if _host.has_method("hud") else null
	if layer == null:
		return
	var fade := layer.get_node_or_null("HQFade") as ColorRect
	if fade == null:
		fade = ColorRect.new()
		fade.name = "HQFade"
		fade.color = Color(0, 0, 0, 0)
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", alpha, seconds)
	await tween.finished


func _find(root: Node, wanted: String) -> Node3D:
	if root.name == wanted and root is Node3D:
		return root as Node3D
	for child in root.get_children():
		var found := _find(child, wanted)
		if found:
			return found
	return null
