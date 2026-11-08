extends Node

## Stage room cogs. Laser-cell suits stay hidden until the puzzle fails, and
## then they are virtual: the battle pays no jury notices.

const _CATALOG := "res://assets/cogs/catalog.json"

var _board: Node
var _timing: Dictionary = {}
var _suits: GDScript
var _spawned: Dictionary = {}
var _sig := ""
var _got := false
var district_id := -1
var street_slug := "lawbot_office"
var visuals := true


static func place(host: Node) -> void:
	if Engine.is_editor_hint() or host == null:
		return
	if host.scene_file_path.get_file() != "lawbot_office.tscn":
		return
	if host.get_node_or_null("StreetSuits") != null:
		return
	var script := load("res://scenes/cog_hq/office_cogs.gd") as GDScript
	var node := script.new() as Node
	node.name = "StreetSuits"
	host.add_child(node)


func floor_clear() -> bool:
	if not _got:
		return false
	var snap := ToonNet.latest("suits:%d:%s" % [district_id, street_slug])
	var listing: Array = snap.get("rows", [])
	return listing.is_empty()


func cell_clear(piece: int, cell: int) -> bool:
	if not _got:
		return false
	var snap := ToonNet.latest("suits:%d:%s" % [district_id, street_slug])
	for item in snap.get("rows", []):
		if not (item is Dictionary):
			continue
		var spec: Dictionary = (item as Dictionary).get("cog", {})
		if int(spec.get("piece", -1)) == piece and int(spec.get("cell", -2)) == cell:
			return false
	return true


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	district_id = ToonNet.district_id()
	_prepare_nametags()
	var catalog := _read(_CATALOG)
	_timing = catalog.get("timing", {})
	_suits = load("res://scenes/cogs/street_cog.gd")
	ToonNet.request_suits(district_id, street_slug)


func _process(_delta: float) -> void:
	if _board != null:
		_board.set("camera", get_viewport().get_camera_3d())
		_board.call("place")
	_apply_net()
	for cog_id in _spawned.keys():
		var actor: Node3D = _spawned[cog_id]
		if actor == null or not is_instance_valid(actor):
			continue
		if bool(actor.get_meta("in_fight", false)):
			continue
		var stand: Variant = actor.get_meta("stand")
		if stand is Vector3:
			actor.global_position = stand
		actor.rotation.y = float(actor.get_meta("stand_yaw"))


func _apply_net() -> void:
	var snap := ToonNet.latest("suits:%d:%s" % [district_id, street_slug])
	if not snap.has("rows"):
		return
	var listing: Array = snap.get("rows", [])
	var parts := PackedStringArray()
	for item in listing:
		if item is Dictionary:
			var row: Dictionary = item
			var spec: Dictionary = row.get("cog", {})
			parts.append("%d:%d" % [int(row.get("do_id", 0)), 1 if bool(spec.get("hidden", false)) else 0])
	var sig := "|".join(parts)
	if sig == _sig:
		return
	_sig = sig
	_got = true
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
			_show(_spawned[cog_id], row)
			continue
		var actor := _spawn(row)
		if actor != null:
			_spawned[cog_id] = actor
	var gone: Array = []
	for cog_id in _spawned.keys():
		if not seen.has(cog_id):
			gone.append(cog_id)
	for cog_id in gone:
		var actor: Node = _spawned[cog_id]
		_spawned.erase(cog_id)
		if actor != null and is_instance_valid(actor):
			if actor.has_method("fly_away") and bool(actor.call("fly_away")):
				continue
			actor.queue_free()


func _spawn(row: Dictionary) -> Node3D:
	var suit: Dictionary = row.get("cog", {})
	if suit.is_empty() or _suits == null:
		return null
	var piece := get_parent().get_node_or_null("Piece%d" % int(suit.get("piece", 0))) as Node3D
	if piece == null:
		return null
	var parent := _find(piece, "ent-%d" % int(suit.get("parent", 0)))
	if parent == null:
		parent = piece
	var actor := _suits.new() as Node3D
	actor.name = str(suit.get("name", "Cog"))
	add_child(actor)
	actor.set_meta("do_id", int(row.get("do_id", 0)))
	actor.set_meta("piece", int(suit.get("piece", 0)))
	actor.set_meta("cell", int(suit.get("cell", 0)))
	actor.call("present", suit, _timing)
	var spot: Array = suit.get("pos", [0.0, 0.0, 0.0])
	var stand: Vector3 = parent.global_transform * Vector3(float(spot[0]), float(spot[1]), float(spot[2]))
	actor.set_meta("stand", stand)
	actor.set_meta("stand_yaw", _heading(parent, float(suit.get("h", 0.0))))
	actor.global_position = stand
	actor.rotation.y = float(actor.get_meta("stand_yaw"))
	_show(actor, row)
	return actor


func _show(actor: Node3D, row: Dictionary) -> void:
	if actor == null:
		return
	var suit: Dictionary = row.get("cog", {})
	var hidden := bool(suit.get("hidden", false))
	actor.set_meta("office_hidden", hidden)
	actor.visible = not hidden
	_solids(actor, not hidden)


func _solids(node: Node, enabled: bool) -> void:
	if node is CollisionObject3D:
		var body := node as CollisionObject3D
		body.collision_layer = 1 if enabled else 0
		body.collision_mask = 1 if enabled else 0
	for child in node.get_children():
		_solids(child, enabled)


func _heading(parent: Node3D, degrees: float) -> float:
	var heading := deg_to_rad(degrees)
	var forward := parent.global_transform.basis * Vector3(-sin(heading), cos(heading), 0.0)
	return atan2(-forward.x, -forward.z)


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
	return false


func _find(node: Node, node_name: String) -> Node3D:
	if node is Node3D and str(node.name) == node_name:
		return node as Node3D
	for child in node.get_children():
		var found := _find(child, node_name)
		if found != null:
			return found
	return null


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}
