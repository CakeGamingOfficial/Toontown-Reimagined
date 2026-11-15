@tool
extends EditorScenePostImport

const _PAINT := preload("res://assets/neighborhoods/toontown_central/ttc_paint.gd")

## Street import only. Rooms call ttc_paint.paint when they are built, because
## an exported game cannot load this editor class.


func _post_import(scene: Node) -> Object:
	_finish(scene)
	return scene


func _finish(node: Node) -> void:
	if String(node.name).contains("__billboard"):
		node.add_to_group("tt_billboard", true)
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		_PAINT.paint_mesh(mesh_node)
		var mesh := mesh_node.mesh
		if mesh:
			var cloud := _under_cloud(node)
			var node_name := String(node.name)
			for surface in mesh.get_surface_count():
				var material := mesh.surface_get_material(surface)
				if material is StandardMaterial3D:
					var standard := material as StandardMaterial3D
					# Shop signs are thin cards on the facade. Draw them from
					# either side, after the wall, so the board is not hidden by it.
					if node_name.begins_with("sign") or node_name.begins_with("baseline"):
						standard.cull_mode = BaseMaterial3D.CULL_DISABLED
						standard.render_priority = 1
					# TT_sky cloud cards are M_dual. A scissor cut turns each soft
					# puff into a rectangle, so the dome reads as a grid of holes.
					# The original draws them with alpha and no depth write.
					if cloud:
						standard.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						standard.alpha_scissor_threshold = 0.0
						standard.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
						standard.cull_mode = BaseMaterial3D.CULL_DISABLED
	for child in node.get_children():
		_finish(child)


func _under_cloud(node: Node) -> bool:
	var current := node
	while current:
		var name := String(current.name)
		if name == "cloud1" or name == "cloud2" or name.begins_with("cloud1_") or name.begins_with("cloud2_"):
			return true
		current = current.get_parent()
	return false
