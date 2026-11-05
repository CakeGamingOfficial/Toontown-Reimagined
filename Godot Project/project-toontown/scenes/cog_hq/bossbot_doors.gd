extends Node

## DistributedCogHQDoor. door_0 on the country club opens the Bossbot lobby,
## and the lobby door comes back out. Walking forward into door_origin_0
## starts the trip. The landing is four feet through that origin.

const _CLUB := "res://scenes/cog_hq/bossbot_country_club.tscn"
const _LOBBY := "res://scenes/cog_hq/bossbot_lobby.tscn"
const _KEYS := preload("res://scenes/shticker/keybinds.gd")
const _REACH := 2.4
const _THROUGH := 4.0

static var _trip := ""

var _origin: Node3D
var _ready_walk := true


static func place(host: Node) -> void:
	if Engine.is_editor_hint() or host == null:
		return
	var file := host.scene_file_path.get_file()
	if file != "bossbot_country_club.tscn" and file != "bossbot_lobby.tscn":
		return
	if host.get_node_or_null("BossbotDoors") != null:
		return
	var script := load("res://scenes/cog_hq/bossbot_doors.gd") as GDScript
	var node := script.new() as Node
	node.name = "BossbotDoors"
	host.add_child(node)


static func arrival(host: Node) -> Dictionary:
	if _trip == "" or host == null:
		return {}
	var origin := _origin_of(host)
	var trip := _trip
	_trip = ""
	if origin == null:
		return {}
	var through := origin.global_basis.y
	through.y = 0.0
	if through.length_squared() < 0.0001:
		through = Vector3(0.0, 0.0, -1.0)
	through = through.normalized()
	var point := origin.global_position + through * _THROUGH
	point.y = origin.global_position.y
	return {
		"point": point,
		"heading": rad_to_deg(atan2(-through.x, -through.z)),
		"trip": trip,
	}


func _ready() -> void:
	_origin = _origin_of(get_parent())


func _physics_process(_delta: float) -> void:
	if _origin == null:
		return
	var toon := get_parent().get_node_or_null("PlaygroundToon")
	if toon == null or bool(toon.call("battle_busy")):
		return
	var body := toon.get_node_or_null("Player") as Node3D
	if body == null:
		return
	var here := body.global_position
	var there := _origin.global_position
	var close := Vector2(here.x, here.z).distance_to(Vector2(there.x, there.z)) <= _REACH
	close = close and absf(here.y - there.y) < 3.0
	if not close:
		_ready_walk = true
		return
	if not _ready_walk or not _KEYS.held("forward"):
		return
	_ready_walk = false
	var club := get_parent().scene_file_path.get_file() == "bossbot_country_club.tscn"
	_trip = "lobby" if club else "club"
	ToonLoading.change_to(_LOBBY if club else _CLUB)


static func _origin_of(host: Node) -> Node3D:
	return _find(host, "door_origin_0")


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
