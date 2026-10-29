extends Node

## TutorialHQBuildingAI's interior. Door 0 opens after the Flunky fight.
## The room is phase_3.5 HQ_interior, with cream and the crashed piano hidden
## the way DistributedHQInterior.generate leaves them. HQ Harry stands on
## npc_origin_0.

const INTERIOR_PATH := "res://assets/interiors/hq/hq_interior.glb"
const COLLISION_PATH := "res://assets/interiors/hq/collision.json"
const OPEN_SFX := "res://assets/interiors/hq/Door_Open_1.ogg"
const CLOSE_SFX := "res://assets/interiors/hq/Door_Close_1.ogg"
const ROOM_SHIFT := Vector3(0.0, 0.0, 240.0)
# door_origin_0, then six units back through the doorway, facing into the room.
const STAND := Vector3(-5.0, 0.2, 7.0)
const STAND_HEADING := 0.0
# npc_origin_0. The origin sits on the pit floor.
const HARRY_SPOT := Vector3(-10.0, -5.0, -24.5)
const HARRY_HEADING := 180.0
const _WRONG_DOOR := "Wrong door! Take the other door to the playground!"

var _host: Node
var _right_door: Node3D
var _right_hole: Node3D
var _flat: Node3D
var _door_point := Vector3.ZERO
var _room: Node3D
var _harry: ToonActor
var _ext_doors: Array[Node3D] = []
var _ext_origins: Array[Node3D] = []
var _inside_doors: Array[Node3D] = []
var _inside_origins: Array[Node3D] = []
var _inside := false
var _busy := false
var _exit_armed := true


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
	var second := _find(landmark, "door_1")
	var second_origin := _find(landmark, "door_origin_1")
	_ext_doors = [door, second]
	_ext_origins = [origin, second_origin]
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


func consider_inside(body: CharacterBody3D) -> void:
	if not _inside or _busy or body == null or _inside_origins.size() < 2:
		return
	if _inside_origins[0] == null or _inside_origins[1] == null:
		return
	var here := Vector2(body.global_position.x, body.global_position.z)
	var entrance := _inside_spot(0)
	var playground := _inside_spot(1)
	var at_entrance := here.distance_to(entrance) <= 2.6
	var at_playground := here.distance_to(playground) <= 2.6
	if not at_entrance and not at_playground:
		_exit_armed = true
		return
	if not _exit_armed or not Input.is_physical_key_pressed(KEY_W):
		return
	_exit_armed = false
	# Door 0 is the tutorial side. Door 1 opens onto the tunnel street.
	if at_playground:
		leave()
	else:
		_reject_entrance()


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
	# DistributedDoor closes the panel after you are through, then plays Door_Close_1.
	_close_swung_door(_ext_doors[0], true)
	await get_tree().create_timer(1.0).timeout
	_busy = false


func leave() -> void:
	if not _inside or _busy:
		return
	_busy = true
	if _host.has_method("set_cutscene"):
		_host.call("set_cutscene", true)
	_play_sound(OPEN_SFX)
	_swing_door(_inside_doors[1])
	_swing_door(_ext_doors[1])
	await get_tree().create_timer(0.7).timeout
	await _fade(1.0, 0.45)
	_show_street()
	await get_tree().create_timer(0.25).timeout
	await _fade(0.0, 0.45)
	if _host.has_method("set_cutscene"):
		_host.call("set_cutscene", false)
	_close_swung_door(_inside_doors[1], false)
	_close_swung_door(_ext_doors[1], true)
	await get_tree().create_timer(1.0).timeout
	_busy = false


func _reject_entrance() -> void:
	if _host.has_method("show_notice"):
		_host.call("show_notice", _WRONG_DOOR)


func _inside_spot(index: int) -> Vector2:
	var origin := _inside_origins[index]
	var other := _inside_origins[1 - index]
	var toward := other.global_position - origin.global_position
	toward.y = 0.0
	var spot := origin.global_position
	if toward.length() > 0.001:
		spot += toward.normalized() * 2.2
	return Vector2(spot.x, spot.z)


func _show_street() -> void:
	var street := _host.get_node_or_null("TutorialStreet") as Node3D
	if street:
		street.visible = true
	if _room:
		_room.visible = false
	if _harry:
		_harry.visible = false
	_inside = false
	var origin := _ext_origins[1]
	var other := _ext_origins[0]
	var away := origin.global_position - other.global_position
	away.y = 0.0
	away = away.normalized()
	# Door 1 faces the tunnel. Stand on the sidewalk, looking toward it.
	var feet := origin.global_position + away * 6.0
	feet.y = 0.2
	var heading := rad_to_deg(atan2(-away.x, -away.z))
	if _host.has_method("place_player"):
		_host.call("place_player", feet, heading)
	if _host.has_method("note_plaza"):
		_host.call("note_plaza", feet, heading)
	if _host.has_method("settle_camera"):
		_host.call("settle_camera")
	if _host.has_method("restore_street_body"):
		_host.call("restore_street_body")


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
	_play_sound(OPEN_SFX)
	if _flat:
		_flat.visible = false
	if _right_hole:
		_right_hole.visible = true
	_swing_panel(_right_door)


func _swing_door(door: Node3D) -> void:
	if door == null:
		return
	var flat := _find_starting(door, "door_flat")
	var hole := _find_starting(door, "doorFrameHoleRight")
	if hole != null and flat != null and flat.is_ancestor_of(hole):
		var kept := hole.global_transform
		hole.reparent(door)
		hole.global_transform = kept
		_blacken(hole)
	if flat:
		flat.visible = false
	if hole:
		hole.visible = true
	var left := _find_starting(door, "leftDoor")
	if left:
		left.visible = true
	_swing_panel(_find_starting(door, "rightDoor"))


func _play_sound(path: String) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var speaker := AudioStreamPlayer.new()
	speaker.stream = stream
	speaker.volume_db = -4.0
	add_child(speaker)
	speaker.play()
	speaker.finished.connect(speaker.queue_free)


func _swing_panel(panel: Node3D) -> void:
	if panel == null:
		return
	panel.visible = true
	if not panel.has_meta("closed_basis"):
		panel.set_meta("closed_basis", panel.transform.basis)
	panel.set_meta("door_open", true)
	# rightSwing turns the right panel +100 degrees on its parent's Z.
	var tween := create_tween()
	tween.tween_method(_set_panel_swing.bind(panel), 0.0, 100.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _close_swung_door(door: Node3D, play_sound: bool) -> void:
	if door == null:
		return
	var panel := _find_starting(door, "rightDoor")
	if panel != null and bool(panel.get_meta("door_open", false)):
		var tween := create_tween()
		# enterClosing lerps the open heading back to 0 over one second.
		tween.tween_method(_set_panel_swing.bind(panel), 100.0, 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.finished.connect(_finish_door_close.bind(door, panel, play_sound))
		return
	_show_closed_door(door)
	if play_sound:
		_play_sound(CLOSE_SFX)


func _set_panel_swing(degrees: float, panel: Node3D) -> void:
	if not is_instance_valid(panel) or not panel.has_meta("closed_basis"):
		return
	var closed: Basis = panel.get_meta("closed_basis")
	panel.transform.basis = Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(degrees)) * closed


func _finish_door_close(door: Node3D, panel: Node3D, play_sound: bool) -> void:
	if is_instance_valid(panel):
		panel.set_meta("door_open", false)
	if is_instance_valid(door):
		_show_closed_door(door)
	if play_sound:
		_play_sound(CLOSE_SFX)


func _show_closed_door(door: Node3D) -> void:
	var flat := _find_starting(door, "door_flat")
	if flat:
		flat.visible = true
	for prefix in ["leftDoor", "rightDoor", "doorFrameHoleRight", "doorFrameHoleLeft"]:
		var part := _find_starting(door, prefix)
		if part:
			part.visible = false


func _place_interior_doors() -> void:
	_inside_doors.clear()
	_inside_origins.clear()
	for index in 2:
		var origin := _find(_room, "door_origin_%d" % index)
		_inside_origins.append(origin)
		# door_double_round_ur, placed by export_hq the way setupDoors does.
		var door := _find(origin, "door_%d" % index) if origin != null else null
		if door == null:
			_inside_doors.append(null)
			continue
		# The flat sits just in front of the wall paint. Step it into the room
		# so the wall does not draw over the round door.
		var other := _find(_room, "door_origin_%d" % (1 - index))
		if other != null:
			var into := other.global_position - origin.global_position
			into.y = 0.0
			if into.length() > 0.001:
				door.global_position += into.normalized() * 0.2
		_close_copy(door)
		_inside_doors.append(door)


func _close_copy(door: Node3D) -> void:
	var flat := _find_starting(door, "door_flat")
	for prefix in ["doorFrameHoleRight", "doorFrameHoleLeft"]:
		var hole := _find_starting(door, prefix)
		if hole == null:
			continue
		if flat != null and flat.is_ancestor_of(hole):
			var kept := hole.global_transform
			hole.reparent(door)
			hole.global_transform = kept
		hole.visible = false
		_blacken(hole)
	_show_closed_door(door)


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
	_place_interior_doors()
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
	if _host.has_method("fit_hq_body"):
		_host.call("fit_hq_body")
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
	var floors := PackedVector3Array()
	var walls := PackedVector3Array()
	for index in range(0, faces.size(), 3):
		var a := faces[index]
		var b := faces[index + 1]
		var c := faces[index + 2]
		var normal := (b - a).cross(c - a)
		var length := normal.length()
		if length < 0.0001:
			continue
		# Stair ramps are 45 degrees. Walls stay in the trimesh.
		if normal.y > length * 0.5:
			floors.append(a)
			floors.append(b)
			floors.append(c)
		else:
			walls.append(a)
			walls.append(b)
			walls.append(c)
	if not walls.is_empty():
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(walls)
		var solid := StaticBody3D.new()
		solid.name = "HQCollision"
		var collision := CollisionShape3D.new()
		collision.shape = shape
		solid.add_child(collision)
		_room.add_child(solid)
	_add_floor(floors)


# Stepped boxes turn each riser into a wall, so the toon can walk down and
# not back up. Each floor polygon is a smooth prism. The ramps stop a unit
# above the pit, so a short slope closes that step.
func _add_floor(faces: PackedVector3Array) -> void:
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
	# The pit polygons leave the center open. The floor mesh there is at -5.
	var hole := BoxShape3D.new()
	hole.size = Vector3(19.0, THICK, 18.0)
	var hole_shape := CollisionShape3D.new()
	hole_shape.shape = hole
	hole_shape.position = Vector3(-5.5, PIT - THICK * 0.5, -30.0)
	slab.add_child(hole_shape)
	_room.add_child(slab)


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


func _find_starting(root: Node, prefix: String) -> Node3D:
	if root.name.begins_with(prefix) and root is Node3D:
		return root as Node3D
	for child in root.get_children():
		var found := _find_starting(child, prefix)
		if found:
			return found
	return null


func _find(root: Node, wanted: String) -> Node3D:
	if root.name == wanted and root is Node3D:
		return root as Node3D
	for child in root.get_children():
		var found := _find(child, wanted)
		if found:
			return found
	return null
