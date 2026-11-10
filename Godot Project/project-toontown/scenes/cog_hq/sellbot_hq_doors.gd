extends Node

## CSHoodDataAI. Courtyard doors 0 through 3 all open the V.P. lobby,
## and the lobby's one door comes back out through courtyard door 0.
## The courtyard side stays shut until the Sellbot suit is complete.
## Walking forward into the door origin starts the trip. The landing is four
## feet on the room side of that origin.

const _COURT := "res://scenes/cog_hq/sellbot_courtyard.tscn"
const _LOBBY := "res://scenes/cog_hq/sellbot_lobby.tscn"
const _KEYS := preload("res://scenes/shticker/keybinds.gd")
const _DISGUISE := preload("res://scenes/shticker/disguise_page.gd")
const _REACH := 2.4
const _THROUGH := 4.0
const _SELLBOT := 3
const _LOCKED := "You'll get caught going in there as a Toon! You need to complete your Sellbot Disguise first!\n\nBuild your Sellbot Disguise out of parts from the Factory."

static var trip := ""
static var _arrive_index := 0

var _origins: Array[Node3D] = []
var _dests: PackedStringArray = PackedStringArray()
var _arrive: PackedInt32Array = PackedInt32Array()
var _armed := true
var _told := false


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
	var into := _room_dir(origin, _find(host, "door_%d" % _arrive_index))
	var point := origin.global_position + into * _THROUGH
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


func _add(origin: Node3D, dest: String, arrive: int) -> void:
	if origin == null:
		return
	_origins.append(origin)
	_dests.append(dest)
	_arrive.append(arrive)


func _physics_process(_delta: float) -> void:
	if _origins.is_empty():
		return
	var toon := get_parent().get_node_or_null("PlaygroundToon")
	if toon == null or bool(toon.call("battle_busy")):
		return
	var body := toon.get_node_or_null("Player") as Node3D
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
		if not _told and toon.has_method("show_notice"):
			toon.call("show_notice", _LOCKED)
			_told = true
		return
	trip = "out" if _dests[pick] == _COURT else "in"
	_arrive_index = _arrive[pick]
	ToonLoading.change_to(_dests[pick])


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
