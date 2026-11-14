extends Node

## CSHoodDataAI. Courtyard doors 0 through 3 all open the V.P. lobby,
## and the lobby's one door comes back out through courtyard door 0.
## The courtyard side stays shut until the Sellbot suit is complete.
## Walking forward lines up, the right leaf opens, and the toon walks through
## while the iris closes. The next room opens the left leaf and steps them in.

const _COURT := "res://scenes/cog_hq/sellbot_courtyard.tscn"
const _LOBBY := "res://scenes/cog_hq/sellbot_lobby.tscn"
const _KEYS := preload("res://scenes/shticker/keybinds.gd")
const _DISGUISE := preload("res://scenes/shticker/disguise_page.gd")
const _OPEN_SFX := "res://assets/cog_hq/audio/CHQ_door_open.ogg"
const _CLOSE_SFX := "res://assets/cog_hq/audio/CHQ_door_close.ogg"
const _REACH := 2.4
const _SELLBOT := 3
const _LOCKED := "You'll get caught going in there as a Toon! You need to complete your Sellbot Disguise first!\n\nBuild your Sellbot Disguise out of parts from the Factory."

static var trip := ""
static var _arrive_index := 0

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
	if file != "sellbot_courtyard.tscn" and file != "sellbot_lobby.tscn":
		return
	if host.get_node_or_null("SellbotHqDoors") != null:
		return
	var script := load("res://scenes/cog_hq/sellbot_hq_doors.gd") as GDScript
	var node := script.new() as Node
	node.name = "SellbotHqDoors"
	host.add_child(node)


static func arrival(host: Node) -> Dictionary:
	if trip == "" or host == null:
		return {}
	var origin := _find(host, "door_origin_%d" % _arrive_index)
	var taken := trip
	trip = ""
	if origin == null:
		return {}
	var door := _find(host, "door_%d" % _arrive_index)
	var into := _room_dir(origin, door)
	var right := _right_of(into)
	# avatarExitTrack starts on the left jamb, then steps six feet into the room.
	var point := origin.global_position - right * 1.5
	point.y = origin.global_position.y
	return {
		"point": point,
		"heading": rad_to_deg(atan2(-into.x, -into.z)),
		"trip": taken,
	}


func _ready() -> void:
	var file := ""
	var host := get_parent()
	if host != null:
		file = host.scene_file_path.get_file()
	if file == "sellbot_courtyard.tscn":
		for index in 4:
			_add(_find(host, "door_origin_%d" % index), _LOBBY, 0)
	elif file == "sellbot_lobby.tscn":
		_add(_find(host, "door_origin_0"), _COURT, 0)


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
	# PlaygroundToon parents Player to the courtyard, next to itself.
	var body := _feet(toon)
	if body == null:
		return
	var here := body.global_position
	var pick := -1
	var best := _REACH
	for index in _origins.size():
		var there := _origins[index].global_position
		var flat := Vector2(here.x, here.z).distance_to(Vector2(there.x, there.z))
		if flat > _REACH or absf(here.y - there.y) >= 3.0:
			continue
		if pick == -1 or flat <= best:
			best = flat
			pick = index
	if pick < 0:
		_armed = true
		_told = false
		return
	if not _armed or not _KEYS.held("forward"):
		return
	_armed = false
	# DistributedSellbotHQDoorAI.requestEnter locks only the exterior door.
	if _dests[pick] == _LOBBY and not _DISGUISE.suit_complete(_SELLBOT):
		if not _told and toon.has_method("show_popup"):
			toon.call("show_popup", _LOCKED)
			_told = true
		return
	_traveling = true
	toon.set("_locked", true)
	_open_and_go(toon, pick, _origins[pick])


## DistributedDoor.enterOpening, then avatarEnqueueTrack, then avatarEnterDoorTrack.
## The right leaf waits 0.4s and swings for 0.6s. The lineup takes that same second.
func _open_and_go(toon: Node, pick: int, origin: Node3D) -> void:
	var door := origin.get_parent() as Node3D
	_drop_solid(door)
	_swing_leaf(door, "rightDoor", "doorFrameHoleRight", 100.0, 0.4)
	_sound(_OPEN_SFX)
	# avatarEnqueueTrack faces the door node's heading 0 and stands on its
	# -Y side. That +Y is through the doorway, not the side the flat sits on.
	var into := _door_forward(origin)
	var right := _right_of(into)
	var feet := _feet(toon)
	var outside := origin.global_position - into * 5.0 + right * 1.5
	var through := origin.global_position + into * 2.0 + right * 1.5
	if feet != null:
		outside.y = feet.global_position.y
		through.y = outside.y
	var facing := rad_to_deg(atan2(-into.x, -into.z))
	await toon._hall_stride(outside, 0.5, facing)
	if not is_instance_valid(self):
		return
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self):
		return
	await toon._walk_into_door(through, true)
	if not is_instance_valid(self):
		return
	trip = "out" if _dests[pick] == _COURT else "in"
	_arrive_index = _arrive[pick]
	ToonLoading.change_to(_dests[pick])


## exitDoorEnterOpening, avatarExitTrack, then exitDoorEnterClosing.
## The left leaf is open as the iris lifts and the toon steps in. It shuts
## over one second, and the close sound starts halfway through that shut.
func play_exit(toon: Node) -> void:
	var origin := _find(get_parent(), "door_origin_%d" % _arrive_index)
	if origin == null:
		if toon != null and toon.has_method("_fade_in"):
			toon.call("_fade_in")
		return
	var door := origin.get_parent() as Node3D
	_drop_solid(door)
	_swing_leaf(door, "leftDoor", "doorFrameHoleLeft", -100.0, 0.0)
	_sound(_OPEN_SFX)
	await get_tree().create_timer(0.6).timeout
	if not is_instance_valid(self) or toon == null:
		return
	var into := _room_dir(origin, door)
	var right := _right_of(into)
	var feet := _feet(toon)
	var start := origin.global_position - right * 1.5
	var goal := start + into * 6.0
	if feet != null:
		start.y = feet.global_position.y
		goal.y = start.y
		feet.global_position = start
	var facing := rad_to_deg(atan2(-into.x, -into.z))
	var cover: ColorRect = toon.call("_blackout")
	if cover != null:
		cover.color.a = 1.0
		var fade := create_tween()
		fade.tween_property(cover, "color:a", 0.0, 0.2)
	await toon._hall_stride(goal, 0.2, facing)
	if cover != null and is_instance_valid(cover):
		cover.queue_free()
	_close_leaf(door, "leftDoor", "doorFrameHoleLeft", -100.0)


static func _door_forward(origin: Node3D) -> Vector3:
	var forward := origin.global_basis.y
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Vector3(0.0, 0.0, -1.0)
	return forward.normalized()


static func _right_of(into: Vector3) -> Vector3:
	var right := into.cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		return Vector3.RIGHT
	return right.normalized()


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
	tween.tween_callback(_show_tree.bind(leaf))
	if hole != null:
		tween.tween_callback(_show_tree.bind(hole))
	tween.tween_method(_set_leaf.bind(leaf), 0.0, degrees, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _close_leaf(door: Node3D, leaf_name: String, hole_name: String, degrees: float) -> void:
	var leaf := _named(door, leaf_name)
	if leaf == null:
		return
	var hole := _named(door, hole_name)
	var tween := create_tween()
	tween.tween_method(_set_leaf.bind(leaf), degrees, 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_hide.bind(leaf))
	if hole != null:
		tween.tween_callback(_hide.bind(hole))
	var close_sound := create_tween()
	close_sound.tween_interval(0.5)
	close_sound.tween_callback(_sound.bind(_CLOSE_SFX))


func _remember(leaf: Node3D) -> void:
	if not leaf.has_meta("closed_basis"):
		leaf.set_meta("closed_basis", leaf.transform.basis)


func _set_leaf(degrees: float, leaf: Node3D) -> void:
	if not is_instance_valid(leaf) or not leaf.has_meta("closed_basis"):
		return
	var closed: Basis = leaf.get_meta("closed_basis")
	# The courtyard export is Y-up, so the hinge is local up.
	leaf.transform.basis = Basis(Vector3.UP, deg_to_rad(degrees)) * closed


func _named(door: Node, part_name: String) -> Node3D:
	if door == null:
		return null
	return _named_under(door, part_name, true)


func _named_under(node: Node, part_name: String, skip: bool) -> Node3D:
	var node_name := String(node.name)
	if not skip and node is Node3D and (node_name == part_name or node_name.begins_with(part_name)):
		return node as Node3D
	for child in node.get_children():
		var found := _named_under(child, part_name, false)
		if found != null:
			return found
	return null


func _drop_solid(node: Node) -> void:
	if node == null:
		return
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	for child in node.get_children():
		_drop_solid(child)


func _show_tree(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).visible = true
	for child in node.get_children():
		_show_tree(child)


func _hide(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).visible = false
	for child in node.get_children():
		_hide(child)


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


static func _room_dir(origin: Node3D, door: Node) -> Vector3:
	var forward := origin.global_basis.y
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3(0.0, 0.0, -1.0)
	else:
		forward = forward.normalized()
	var host := door if door != null else origin.get_parent()
	if host == null:
		return forward
	# The closed picture sits a fraction of a foot in front of the origin.
	# Land on the other side, which is the room this door opens into.
	var side := _slab_side(host, origin.global_position, forward)
	if side.y < 1.0:
		return forward
	if side.x / side.y > 0.05:
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
