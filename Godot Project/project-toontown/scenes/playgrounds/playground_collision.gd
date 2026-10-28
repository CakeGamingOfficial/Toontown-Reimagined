extends Node3D

## Builds static trimesh collision from the opaque playground meshes.
## Leaf cards and the sky dome are left non-solid so they don't become invisible walls.


func _ready() -> void:
	_add_collision(self)


func _add_collision(node: Node) -> void:
	if "sky" in node.name.to_lower():
		return
	var children := node.get_children()
	for child in children:
		_add_collision(child)
	if node is MeshInstance3D:
		var material := (node as MeshInstance3D).get_active_material(0)
		if material is BaseMaterial3D and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return
		(node as MeshInstance3D).create_trimesh_collision()
