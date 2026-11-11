@tool
extends EditorScenePostImport

## Toontown is texture and vertex color, drawn unshaded. Flat factors are already
## Godot colors. Vertex colors are the source sRGB numbers, so only surfaces that
## actually carry them should be decoded. Forcing that decode on every mesh turns
## uncolored hedges, doors, and signs black.


func _post_import(scene: Node) -> Object:
	_finish(scene)
	return scene


func _finish(node: Node) -> void:
	if String(node.name).contains("__billboard"):
		node.add_to_group("tt_billboard", true)
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		_paint_mesh(mesh_node)
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


## Streets import through _finish. Building interiors are the same Panda
## colors, so they call paint when the room is built. A lit StandardMaterial
## on top of those colors blows the room out.
static func paint(node: Node) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		_paint_mesh(node as MeshInstance3D)
	for child in node.get_children():
		paint(child)


static func _paint_mesh(mesh_node: MeshInstance3D) -> void:
	var mesh := mesh_node.mesh
	if mesh == null:
		return
	for surface in mesh.get_surface_count():
		var material := mesh_node.get_active_material(surface)
		if not material is StandardMaterial3D:
			continue
		var standard := material as StandardMaterial3D
		standard.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		standard.vertex_color_use_as_albedo = true
		# Panda repeats a texture per axis. Godot turns repeat off for the
		# whole sampler when either axis clamps, which stretches fences
		# and the trolley awning into a single texel.
		standard.texture_repeat = true
		if mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR:
			standard.vertex_color_is_srgb = true


func _under_cloud(node: Node) -> bool:
	var current := node
	while current:
		var name := String(current.name)
		if name == "cloud1" or name == "cloud2" or name.begins_with("cloud1_") or name.begins_with("cloud2_"):
			return true
		current = current.get_parent()
	return false
