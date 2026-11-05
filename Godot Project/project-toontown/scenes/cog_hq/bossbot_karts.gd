extends Node

## DistributedCogKart. BossbotHQDataAI parks three Coggolf_cart3 karts on the
## country club. The Front Three, the Middle Six, and the Back Nine.

const _MODEL := preload("res://assets/cog_hq/cog_golf_cart.glb")

## createCogKarts positions and headings, in Panda.
const _KARTS: Array[Dictionary] = [
	{"kart_name": "FrontThree", "pos": Vector3(154.762, 37.169, 0.0), "heading": 110.815},
	{"kart_name": "MiddleSix", "pos": Vector3(141.403, -81.887, 0.0), "heading": 61.231},
	{"kart_name": "BackNine", "pos": Vector3(-48.44, 15.308, 0.0), "heading": -105.481},
]

## Tight bounds of Coggolf_cart3 sit 0.142 below the origin. Parked at z = 0
## that buries the wheels, so the whole cart is lifted onto the ground.
const _GROUND := 0.142
const _BOX_CENTER := Vector3(0.0, 0.0, 2.842)
const _BOX_SIZE := Vector3(10.168, 11.686, 5.969)


static func place(host: Node) -> void:
	if Engine.is_editor_hint() or host == null:
		return
	if host.scene_file_path.get_file() != "bossbot_country_club.tscn":
		return
	if host.get_node_or_null("CogKarts") != null:
		return
	var script := load("res://scenes/cog_hq/bossbot_karts.gd") as GDScript
	var node := script.new() as Node
	node.name = "CogKarts"
	host.add_child(node)


func _ready() -> void:
	var geom := get_parent().get_node_or_null("Geometry") as Node3D
	if geom == null:
		return
	for row in _KARTS:
		_park(geom, row)
	_letter(geom, "Gate_4", "The Front Three")
	_letter(geom, "Gate_3", "The Middle Six")
	_letter(geom, "Gate_2", "The Back Nine")
	_letter(geom, "GateHouse", "The Clubhouse")
	_letter(geom, "TunnelEntrance", "Playground")


func _park(geom: Node3D, row: Dictionary) -> void:
	var kart := _MODEL.instantiate() as Node3D
	kart.name = str(row["kart_name"])
	geom.add_child(kart)
	var panda: Vector3 = row["pos"]
	kart.position = _to_godot(panda) + Vector3(0.0, _GROUND, 0.0)
	# The cart mesh is already Y-up. Panda's heading is a yaw around that up axis.
	kart.basis = Basis(Vector3.UP, deg_to_rad(float(row["heading"])))
	var body := StaticBody3D.new()
	body.name = "KartBody"
	body.collision_layer = 1
	body.collision_mask = 0
	kart.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# The cart mesh keeps the export's Y-up conversion. The box is in that space.
	box.size = Vector3(_BOX_SIZE.x, _BOX_SIZE.z, _BOX_SIZE.y)
	shape.shape = box
	shape.position = Vector3(_BOX_CENTER.x, _BOX_CENTER.z, -_BOX_CENTER.y)
	body.add_child(shape)


## BossbotCogHQLoader.makeSigns. The line sits on sign_origin, just off the board.
func _letter(geom: Node, gate_name: String, words: String) -> void:
	var gate := _find(geom, gate_name)
	var origin := _find_prefix(gate, "sign_origin") as Node3D
	if origin == null:
		return
	var label := Label3D.new()
	label.name = "CourseSign"
	label.text = words.to_upper()
	label.font = ToonGui.suit_font()
	label.font_size = 100
	label.pixel_size = 0.0112
	label.modulate = Color(0, 0, 0, 1)
	label.outline_size = 0
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.no_depth_test = true
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# sign_origin is still Panda: local Y faces out of the board, local Z is up.
	# Label3D faces its local +Z.
	label.basis = Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))
	label.position = Vector3(0.0, 0.12, -0.25)
	origin.add_child(label)


static func _to_godot(panda: Vector3) -> Vector3:
	return Vector3(panda.x, panda.z, -panda.y)


func _find(node: Node, wanted: String) -> Node:
	if node == null:
		return null
	if String(node.name) == wanted:
		return node
	for child in node.get_children():
		var found := _find(child, wanted)
		if found != null:
			return found
	return null


func _find_prefix(node: Node, prefix: String) -> Node:
	if node == null:
		return null
	var node_name := String(node.name)
	if node_name == prefix or node_name.begins_with(prefix):
		return node
	for child in node.get_children():
		var found := _find_prefix(child, prefix)
		if found != null:
			return found
	return null
