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

## Tight bounds of Coggolf_cart3, still in Panda. The cart root converts them.
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


func _park(geom: Node3D, row: Dictionary) -> void:
	var kart := _MODEL.instantiate() as Node3D
	kart.name = str(row["kart_name"])
	geom.add_child(kart)
	_drop_spin(kart)
	var panda: Vector3 = row["pos"]
	kart.position = _to_godot(panda)
	kart.basis = _world_basis(float(row["heading"]))
	var body := StaticBody3D.new()
	body.name = "KartBody"
	body.collision_layer = 1
	body.collision_mask = 0
	kart.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = _BOX_SIZE
	shape.shape = box
	shape.position = _BOX_CENTER
	body.add_child(shape)


func _drop_spin(root: Node3D) -> void:
	for child in root.get_children():
		if not (child is Node3D):
			continue
		var body := child as Node3D
		var basis := body.basis
		var z_up := basis.x.distance_to(Vector3(1, 0, 0)) < 0.02
		z_up = z_up and basis.y.distance_to(Vector3(0, 0, -1)) < 0.02
		z_up = z_up and basis.z.distance_to(Vector3(0, 1, 0)) < 0.02
		if z_up:
			body.basis = Basis.IDENTITY
		return


static func _panda_basis(heading: float) -> Basis:
	var yaw := deg_to_rad(heading)
	return Basis(
		Vector3(cos(yaw), -sin(yaw), 0.0),
		Vector3(-sin(yaw), cos(yaw), 0.0),
		Vector3(0.0, 0.0, 1.0)
	)


static func _world_basis(heading: float) -> Basis:
	var panda := _panda_basis(heading)
	return Basis(_to_godot(panda.x), _to_godot(panda.y), _to_godot(panda.z))


static func _to_godot(panda: Vector3) -> Vector3:
	return Vector3(panda.x, panda.z, -panda.y)
