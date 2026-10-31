extends Node3D

## Builds static trimesh collision from the opaque meshes.
## Leaf cards and the sky dome stay non-solid so they don't become invisible walls.
## Street blocks are baked first, in street_batch.gd, so a block is one solid
## instead of a few hundred. The street script calls finish() after it has
## closed doors and hidden the baked shadow cards.

const _BATCH := preload("res://scenes/playgrounds/street_batch.gd")

var _built := false


static func finish(host: Node, flat: bool) -> void:
	if host.has_method("build_street"):
		host.call("build_street", flat)
	for child in host.get_children():
		finish(child, flat)


func _ready() -> void:
	if _on_street() and not Engine.is_editor_hint():
		return
	_add_collision(self)


func build_street(flat: bool) -> void:
	if _built or not _on_street():
		return
	_built = true
	if flat:
		_BATCH.apply_flat(self)
	else:
		_BATCH.apply(self)
	_add_collision(self)


func _on_street() -> bool:
	var host := get_parent()
	if host == null:
		return false
	return host.scene_file_path.contains("/streets/")


func _add_collision(node: Node) -> void:
	if "sky" in node.name.to_lower():
		return
	if node is MeshInstance3D:
		_collide_mesh(node as MeshInstance3D)
	for child in node.get_children():
		_add_collision(child)


func _collide_mesh(mesh: MeshInstance3D) -> void:
	if not mesh.visible or mesh.mesh == null or mesh.has_meta("street_batched"):
		return
	var material := mesh.get_active_material(0)
	if material is BaseMaterial3D and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return
	mesh.create_trimesh_collision()
