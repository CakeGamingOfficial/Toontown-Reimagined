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
	_BATCH.sweep_empty(self)


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
	# Shop and cog fronts get one solid from their wall triangles. A trimesh
	# on the door slab would close the opening the player has to walk up to.
	if _facade_piece(mesh):
		return
	var material := mesh.get_active_material(0)
	var cutout := false
	if material is BaseMaterial3D:
		cutout = (material as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	# Party gates are masked cards. The tunnel, stairs, and signs still need to stop a toon.
	if cutout and not _party_piece(mesh):
		return
	mesh.create_trimesh_collision()


func _facade_piece(mesh: MeshInstance3D) -> bool:
	var current: Node = mesh
	while current != null:
		var low := String(current.name).to_lower()
		if low.contains("toon_landmark") or low.contains("animated_building") or low.contains("suit_landmark"):
			return true
		current = current.get_parent()
	return false


## partyGate_TT and the other playground gates. Hats, clocks, and pole balls are
## flat cards. The walls, stairs, floor, and sign posts are the solid parts.
func _party_piece(mesh: MeshInstance3D) -> bool:
	var inside := false
	var current: Node = mesh
	while current != null:
		var name := str(current.name)
		var lower := name.to_lower()
		if name == "clock_flat" or lower.contains("billboard") or lower.contains("shadow"):
			return false
		if name == "partyGate_grp" or name == "partyGateSignGroup" or name.begins_with("prop_party_gate"):
			inside = true
		current = current.get_parent()
	if not inside:
		return false
	var leaf := str(mesh.name)
	return not leaf.begins_with("hatFlat") and not leaf.begins_with("hatTop")
