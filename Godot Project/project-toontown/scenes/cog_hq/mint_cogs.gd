extends Node

## The cogs for the mint floor this toon rode into. They stand where the room
## spec put them. Walking into one opens that battle cell.

const _RIDE := preload("res://scenes/cog_hq/mint_elevator.gd")
const _CATALOG := "res://assets/cogs/catalog.json"

var _timing: Dictionary = {}
var _suits: GDScript
var _spawned: Dictionary = {}
var _sig := ""
var _board: Node
var district_id := -1
var street_slug := "cashbot_mint"
var visuals := false


static func place(host: Node) -> void:
	if Engine.is_editor_hint() or host == null:
		return
	if host.scene_file_path.get_file() != "cashbot_mint.tscn":
		return
	if host.get_node_or_null("StreetSuits") != null:
		return
	var script := load("res://scenes/cog_hq/mint_cogs.gd") as GDScript
	var node := script.new() as Node
	node.name = "StreetSuits"
	host.add_child(node)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	district_id = ToonNet.district_id()
	_prepare_nametags()
	var catalog := _read_json(_CATALOG)
	_timing = catalog.get("timing", {})
	_suits = load("res://scenes/cogs/street_cog.gd")
	ToonNet.request_mint(district_id, _RIDE.mint_id, _RIDE.floor_num, _RIDE.ride)


func _process(_delta: float) -> void:
	if _board != null:
		_board.set("camera", get_viewport().get_camera_3d())
		_board.call("place")
	_apply_net()
	_open_blocks()
	_hide_far()


func _apply_net() -> void:
	var snap := ToonNet.latest("suits:%d:%d:cashbot_mint" % [district_id, ToonNet.peer_id()])
	if not snap.has("rows"):
		return
	var listing: Array = snap.get("rows", [])
	var parts := PackedStringArray()
	for item in listing:
		if item is Dictionary:
			parts.append(str(int((item as Dictionary).get("do_id", 0))))
	var sig := "|".join(parts)
	if sig == _sig:
		return
	_sig = sig
	var seen := {}
	for item in listing:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		var cog_id := int(row.get("do_id", 0))
		if cog_id == 0:
			continue
		seen[cog_id] = true
		if _spawned.has(cog_id):
			continue
		var actor := _spawn(row)
		if actor != null:
			_spawned[cog_id] = actor
	var gone: Array = []
	for cog_id in _spawned.keys():
		if not seen.has(cog_id):
			gone.append(cog_id)
	for cog_id in gone:
		var actor: Node3D = _spawned[cog_id]
		_spawned.erase(cog_id)
		if actor != null and is_instance_valid(actor):
			if actor.has_method("fly_away") and bool(actor.call("fly_away")):
				continue
			actor.queue_free()


func _spawn(row: Dictionary) -> Node3D:
	var suit: Dictionary = row.get("cog", {})
	if suit.is_empty() or _suits == null:
		return null
	var actor := _suits.new() as Node3D
	if actor == null:
		return null
	actor.name = str(suit.get("name", "Cog"))
	add_child(actor)
	actor.set_meta("do_id", int(row.get("do_id", 0)))
	actor.set_meta("cell", int(suit.get("cell", 0)))
	actor.call("present", suit, _timing)
	var spot: Array = suit.get("pos", [0.0, 0.0, 0.0])
	actor.global_position = Vector3(float(spot[0]), float(spot[1]), float(spot[2]))
	actor.rotation.y = deg_to_rad(float(suit.get("yaw", 0.0)))
	return actor


func _open_blocks() -> void:
	var host := get_parent()
	if host == null:
		return
	var holder := host.get_node_or_null("MintFloor/MintBlocks")
	if holder == null:
		return
	var live := {}
	for cog_id in _spawned.keys():
		var actor: Node3D = _spawned[cog_id]
		if actor == null or not is_instance_valid(actor):
			continue
		live[int(actor.get_meta("cell", -1))] = true
	for block in holder.get_children():
		if live.has(int(block.get_meta("cell", -2))):
			continue
		block.queue_free()


func _hide_far() -> void:
	var host := get_parent()
	if host == null:
		return
	var floor := host.get_node_or_null("MintFloor")
	if floor == null or not floor.has_method("shows_room"):
		return
	for cog_id in _spawned.keys():
		var actor: Node3D = _spawned[cog_id]
		if actor == null or not is_instance_valid(actor):
			continue
		var room := int(int(actor.get_meta("cell", 0)) / 100)
		var show := bool(floor.call("shows_room", room))
		actor.visible = show
		actor.set_meta("office_hidden", not show)


func _prepare_nametags() -> void:
	var script := load("res://scenes/toons/nametags.gd") as GDScript
	var board := script.new() as Node
	board.name = "Nametags"
	add_child(board)
	var layer := CanvasLayer.new()
	layer.name = "CogNametags"
	layer.layer = 6
	add_child(layer)
	board.set("layer", layer)
	board.set("occlude", _blocked)
	_board = board


func _blocked(actor: Node3D, point: Vector3) -> bool:
	if bool(actor.get_meta("office_hidden", false)):
		return true
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	if cam.is_position_behind(point) or not cam.is_position_in_frustum(point):
		return true
	var tick := Engine.get_process_frames()
	if tick % 8 != int(actor.get_instance_id()) % 8:
		return bool(actor.get_meta("occ", false))
	var world := actor.get_world_3d()
	if world == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(cam.global_position, point)
	query.collide_with_areas = false
	var blocked := not world.direct_space_state.intersect_ray(query).is_empty()
	actor.set_meta("occ", blocked)
	return blocked


func _read_json(path: String) -> Dictionary:
	if path.ends_with("cogs/catalog.json"):
		return CogCatalog.data()
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}
