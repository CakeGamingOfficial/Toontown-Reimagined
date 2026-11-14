extends Node

## LawbotHQDataAI.makeDoor. Courtyard door 0 opens the D.A. office lobby.
## Courtyard door 1 opens the Chief Justice lobby, and that side stays shut
## until the Lawbot suit is complete. Each lobby door comes back out.
## The walk-in volume is the original door_trigger polygon on the doorway.
## The landing is four feet on the room side of the door origin.
## DistributedDoor.hideDoorParts hides doorFrameHoleLeft and
## doorFrameHoleRight on a Cog HQ door. Those cards are untextured black
## and sit on the door picture. There is no doorDoubleFlat, so the leaves
## stay up. Walking in swings the right leaf. Coming out, the left leaf
## swings open and then shuts. Swing flags default to 3, so the right leaf
## goes to +100 and the left leaf to -100, around the door's up axis.

const _COURT := "res://scenes/cog_hq/lawbot_courtyard.tscn"
const _DA := "res://scenes/cog_hq/lawbot_da_lobby.tscn"
const _CJ := "res://scenes/cog_hq/lawbot_lobby.tscn"
const _KEYS := preload("res://scenes/shticker/keybinds.gd")
const _DISGUISE := preload("res://scenes/shticker/disguise_page.gd")
const _THROUGH := 4.0
const _LAWBOT := 1
const _LOCKED := "You'll get caught going in there as a Toon! You need to complete your Lawbot Disguise first!\n\nBuild your Lawbot Disguise by doing the ToonTasks after Donald's Dreamland."
const _OPEN_SFX := "res://assets/cog_hq/audio/CHQ_door_open.ogg"
const _CLOSE_SFX := "res://assets/cog_hq/audio/CHQ_door_close.ogg"

static var trip := ""
static var _arrive_index := 0
static var _close_on_arrival := false

var _origins: Array[Node3D] = []
var _dests: PackedStringArray = PackedStringArray()
var _arrive: PackedInt32Array = PackedInt32Array()
var _armed := true
var _told := false
var _traveling := false


static func place(host: Node) -> void:
	if Engine.is_editor_hint() or host == null:
		return
	var file := host.scene_file_path.get_file()
	if file != "lawbot_courtyard.tscn" and file != "lawbot_lobby.tscn" and file != "lawbot_da_lobby.tscn":
		return
	if host.get_node_or_null("LawbotDoors") != null:
		return
	var script := load("res://scenes/cog_hq/lawbot_doors.gd") as GDScript
	var node := script.new() as Node
	node.name = "LawbotDoors"
	host.add_child(node)


static func arrival(host: Node) -> Dictionary:
	if trip == "" or host == null:
		return {}
	var origin := _find(host, "door_origin_%d" % _arrive_index)
	var taken := trip
	trip = ""
	if origin == null:
		return {}
	var into := _room_dir(origin)
	var point := origin.global_position + into * _THROUGH
	point.y = origin.global_position.y
	return {
		"point": point,
		"heading": rad_to_deg(atan2(-into.x, -into.z)),
		"trip": taken,
	}


func _ready() -> void:
	_hide_holes(get_parent())
	var file := ""
	if get_parent() != null:
		file = get_parent().scene_file_path.get_file()
	if file == "lawbot_courtyard.tscn":
		_add(_find(get_parent(), "door_origin_0"), _DA, 0)
		_add(_find(get_parent(), "door_origin_1"), _CJ, 0)
	elif file == "lawbot_da_lobby.tscn":
		_add(_find(get_parent(), "door_origin_0"), _COURT, 0)
	elif file == "lawbot_lobby.tscn":
		_add(_find(get_parent(), "door_origin_0"), _COURT, 1)
	for origin in _origins:
		_show_faces(origin)
	_greet()


func _feet(toon: Node) -> Node3D:
	var body := toon.get_node_or_null("Player") as Node3D
	if body != null:
		return body
	var host := get_parent()
	if host == null:
		return null
	return host.get_node_or_null("Player") as Node3D


func _add(origin: Node3D, dest: String, arrive: int) -> void:
	if origin == null:
		return
	_origins.append(origin)
	_dests.append(dest)
	_arrive.append(arrive)


func _physics_process(_delta: float) -> void:
	if _traveling or _origins.is_empty():
		return
	var toon := get_parent().get_node_or_null("PlaygroundToon")
	if toon == null or bool(toon.call("battle_busy")):
		return
	# PlaygroundToon parents Player to the neighborhood, next to itself.
	var body := _feet(toon)
	if body == null:
		return
	var here := body.global_position
	var pick := -1
	for index in _origins.size():
		if _in_doorway(_origins[index], here):
			pick = index
			break
	if pick < 0:
		_armed = true
		_told = false
		return
	if not _armed or not _KEYS.held("forward"):
		return
	_armed = false
	# DistributedCogHQDoorAI.requestEnter locks only the exterior door.
	if _dests[pick] == _CJ and not _DISGUISE.suit_complete(_LAWBOT):
		if not _told and toon.has_method("show_popup"):
			toon.call("show_popup", _LOCKED)
			_told = true
		return
	_traveling = true
	toon.set("_locked", true)
	_open_and_go(pick, _origins[pick])


## DistributedDoor.enterOpening. The open sound starts immediately. The
## right leaf waits 0.4s, then swings for 0.6s. The trip starts once it is open.
func _open_and_go(pick: int, origin: Node3D) -> void:
	var door := origin.get_parent() as Node3D
	_swing_leaf(door, "rightDoor", "doorFrameHoleRight", 100.0, 0.4)
	_sound(_OPEN_SFX)
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self):
		return
	trip = "out" if _dests[pick] == _COURT else "in"
	_arrive_index = _arrive[pick]
	_close_on_arrival = true
	ToonLoading.change_to(_dests[pick])


## exitDoorEnterOpening, then exitDoorEnterClosing. The left leaf swings
## open as you come through, then shuts. The close sound waits half a second
## into that shut, the same as DistributedCogHQDoor.
func _greet() -> void:
	if not _close_on_arrival:
		return
	_close_on_arrival = false
	var origin := _find(get_parent(), "door_origin_%d" % _arrive_index)
	if origin == null:
		return
	var door := origin.get_parent() as Node3D
	var leaf := _named(door, "leftDoor")
	var hole := _named(door, "doorFrameHoleLeft")
	if leaf == null:
		return
	_remember(leaf)
	_drop_solid(leaf)
	if hole != null:
		_show_tree(hole)
	_sound(_OPEN_SFX)
	var tween := create_tween()
	tween.tween_method(_set_leaf.bind(leaf), 0.0, -100.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_leaf.bind(leaf), -100.0, 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if hole != null:
		tween.tween_callback(_hide.bind(hole))
	var close_sound := create_tween()
	close_sound.tween_interval(1.1)
	close_sound.tween_callback(_sound.bind(_CLOSE_SFX))


func _swing_leaf(door: Node3D, leaf_name: String, hole_name: String, degrees: float, delay: float) -> void:
	if door == null:
		return
	var leaf := _named(door, leaf_name)
	if leaf == null:
		return
	_remember(leaf)
	_drop_solid(leaf)
	var hole := _named(door, hole_name)
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	if hole != null:
		tween.tween_callback(_show_tree.bind(hole))
	tween.tween_method(_set_leaf.bind(leaf), 0.0, degrees, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _remember(leaf: Node3D) -> void:
	if not leaf.has_meta("closed_basis"):
		leaf.set_meta("closed_basis", leaf.transform.basis)


func _set_leaf(degrees: float, leaf: Node3D) -> void:
	if not is_instance_valid(leaf) or not leaf.has_meta("closed_basis"):
		return
	var closed: Basis = leaf.get_meta("closed_basis")
	# The door node is still in Panda axes, so local Z is up. That is setH.
	leaf.transform.basis = Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(degrees)) * closed


func _named(door: Node, part_name: String) -> Node3D:
	if door == null:
		return null
	return _named_under(door, part_name, true)


func _named_under(node: Node, part_name: String, skip: bool) -> Node3D:
	var node_name := String(node.name)
	if not skip and node is Node3D and _part_name(node_name, part_name):
		return node as Node3D
	for child in node.get_children():
		var found := _named_under(child, part_name, false)
		if found != null:
			return found
	return null


func _part_name(node_name: String, part_name: String) -> bool:
	if node_name == part_name or node_name.begins_with(part_name + "_"):
		return true
	if not node_name.begins_with(part_name):
		return false
	return node_name.substr(part_name.length()).is_valid_int()


func _drop_solid(node: Node) -> void:
	if node is StaticBody3D:
		(node as CollisionObject3D).collision_layer = 0
	for child in node.get_children():
		_drop_solid(child)


func _show_tree(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).visible = true
	for child in node.get_children():
		_show_tree(child)


func _sound(path: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return
	var stream := AudioStreamOggVorbis.load_from_buffer(bytes)
	if stream == null:
		return
	var speaker := ToonAudio.effect_player()
	speaker.stream = stream
	speaker.volume_db = -4.0
	add_child(speaker)
	speaker.play()
	speaker.finished.connect(speaker.queue_free)


## door_trigger_* from LawbotPlaza, LB_DA_Lobby, and LB_CH_Lobby. Those
## collision nodes were not exported. The numbers are the polygon's two
## corners in the door node's own space, which the glTF kept in Panda axes.
func _span(origin: Node3D) -> AABB:
	var file := ""
	if get_parent() != null:
		file = get_parent().scene_file_path.get_file()
	var which := String(origin.name)
	var low := Vector3.ZERO
	var high := Vector3.ZERO
	if file == "lawbot_courtyard.tscn" and which == "door_origin_0":
		low = Vector3(-7.085, -2.788, -22.807)
		high = Vector3(15.968, -2.788, -15.643)
	elif file == "lawbot_courtyard.tscn" and which == "door_origin_1":
		low = Vector3(-8.38, -2.381, -26.976)
		high = Vector3(18.887, -2.381, -18.503)
	elif file == "lawbot_da_lobby.tscn" and which == "door_origin_0":
		low = Vector3(-21.865, -0.319, -26.865)
		high = Vector3(22.840, -0.319, -18.213)
	elif file == "lawbot_lobby.tscn" and which == "door_origin_0":
		low = Vector3(-42.559, -7.736, -25.606)
		high = Vector3(2.146, -7.736, -16.953)
	else:
		return AABB()
	# The polygon is one flat line. The toon stands at the door origin, on
	# the room side, and the closed door stops them a few feet past that line.
	# A slab only around the line leaves them pushing on the door with no trip.
	var plane := low.y
	var stand := plane
	var door := origin.get_parent() as Node3D
	if door != null:
		stand = door.to_local(origin.global_position).y
	var sign := 1.0 if stand < plane else -1.0
	var approach := stand - sign * 2.0
	var face := plane + sign * 4.0
	low.x -= 1.0
	high.x += 1.0
	low.z -= 1.0
	high.z += 1.0
	low.y = minf(approach, face)
	high.y = maxf(approach, face)
	return AABB(low, high - low)


func _in_doorway(origin: Node3D, body: Vector3) -> bool:
	var door := origin.get_parent() as Node3D
	if door == null:
		return false
	var box := _span(origin)
	if box.size.length_squared() < 0.01:
		return false
	# Feet, and a point up the toon. The trigger is only about seven feet tall
	# and the floor sits on its bottom edge.
	var chest := body + Vector3(0.0, 1.6, 0.0)
	return box.has_point(door.to_local(body)) or box.has_point(door.to_local(chest))


func _hide_holes(node: Node) -> void:
	if node == null:
		return
	if String(node.name).begins_with("doorFrameHole"):
		_hide(node)
		# Collision was built while these cards were still shown, so the
		# hidden card stays a wall in the doorway. Drop that solid.
		_drop_solid(node)
		return
	for child in node.get_children():
		_hide_holes(child)


func _hide(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).visible = false
	for child in node.get_children():
		_hide(child)


## The lobby door panels are one quad, and that quad faces away from the
## stand point, so the closed door is culled. Turn the panel around.
func _show_faces(origin: Node3D) -> void:
	var door := origin.get_parent()
	if door == null:
		return
	_flip_away(door, origin, door)


func _flip_away(node: Node, origin: Node3D, door: Node) -> void:
	if node != door and node is MeshInstance3D and _under_leaf(node, door):
		_flip_mesh(node as MeshInstance3D, origin)
	for child in node.get_children():
		if String(child.name).begins_with("doorFrameHole"):
			continue
		_flip_away(child, origin, door)


func _under_leaf(node: Node, door: Node) -> bool:
	var cursor := node
	while cursor != null and cursor != door:
		var node_name := String(cursor.name)
		if node_name.begins_with("leftDoor") or node_name.begins_with("rightDoor"):
			return true
		cursor = cursor.get_parent()
	return false


func _flip_mesh(mesh: MeshInstance3D, origin: Node3D) -> void:
	if mesh.mesh == null:
		return
	var view := origin.global_position - mesh.global_position
	if view.length_squared() < 0.0001:
		return
	view = view.normalized()
	var toward := 0.0
	var away := 0.0
	for surface in mesh.mesh.get_surface_count():
		var arrays: Array = mesh.mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var count := indices.size() if indices.size() >= 3 else verts.size()
		var step := 0
		while step + 2 < count:
			var ia := indices[step] if indices.size() >= 3 else step
			var ib := indices[step + 1] if indices.size() >= 3 else step + 1
			var ic := indices[step + 2] if indices.size() >= 3 else step + 2
			step += 3
			var a := mesh.global_transform * verts[ia]
			var b := mesh.global_transform * verts[ib]
			var c := mesh.global_transform * verts[ic]
			var cross := (b - a).cross(c - a)
			var area := cross.length()
			if cross.dot(view) > 0.0:
				toward += area
			else:
				away += area
	# A door panel. Trim strips are smaller and already face along the frame.
	if toward > away * 0.05 or away < 400.0:
		return
	var fixed := ArrayMesh.new()
	for surface in mesh.mesh.get_surface_count():
		var arrays: Array = mesh.mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.size() >= 3:
			var flipped := PackedInt32Array()
			flipped.resize(indices.size())
			var step := 0
			while step + 2 < indices.size():
				flipped[step] = indices[step]
				flipped[step + 1] = indices[step + 2]
				flipped[step + 2] = indices[step + 1]
				step += 3
			arrays[Mesh.ARRAY_INDEX] = flipped
		else:
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var step := 0
			while step + 2 < verts.size():
				var swap := verts[step + 1]
				verts[step + 1] = verts[step + 2]
				verts[step + 2] = swap
				step += 3
			arrays[Mesh.ARRAY_VERTEX] = verts
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for index in normals.size():
			normals[index] = -normals[index]
		arrays[Mesh.ARRAY_NORMAL] = normals
		fixed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		fixed.surface_set_material(surface, mesh.mesh.surface_get_material(surface))
	mesh.mesh = fixed


static func _room_dir(origin: Node3D) -> Vector3:
	var forward := origin.global_basis.y
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3(0.0, 0.0, -1.0)
	else:
		forward = forward.normalized()
	var host := origin.get_parent()
	if host == null:
		return forward
	# The door slab sits on one side of the origin. Land on the other side,
	# which is the room this door opens into.
	var side := _slab_side(host, origin.global_position, forward)
	if side.y < 1.0:
		return forward
	if side.x / side.y > 0.25:
		return -forward
	return forward


static func _slab_side(node: Node, spot: Vector3, forward: Vector3) -> Vector2:
	var sum := 0.0
	var count := 0.0
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var center := mesh.global_position
		if mesh.mesh != null:
			center = mesh.global_transform * mesh.get_aabb().get_center()
		sum += (center - spot).dot(forward)
		count += 1.0
	for child in node.get_children():
		var part := _slab_side(child, spot, forward)
		sum += part.x
		count += part.y
	return Vector2(sum, count)


static func _find(node: Node, wanted: String) -> Node3D:
	if node == null:
		return null
	if node is Node3D and String(node.name) == wanted:
		return node as Node3D
	for child in node.get_children():
		var found := _find(child, wanted)
		if found != null:
			return found
	return null
