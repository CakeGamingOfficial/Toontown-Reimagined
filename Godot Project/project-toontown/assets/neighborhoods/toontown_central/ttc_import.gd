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
		var mesh := (node as MeshInstance3D).mesh
		if mesh:
			for surface in mesh.get_surface_count():
				var material := mesh.surface_get_material(surface)
				if material is StandardMaterial3D:
					var standard := material as StandardMaterial3D
					standard.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					standard.vertex_color_use_as_albedo = true
					# Panda repeats a texture per axis. Godot turns repeat off for the
					# whole sampler when either axis clamps, which stretches fences
					# and the trolley awning into a single texel.
					standard.texture_repeat = true
					if mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR:
						standard.vertex_color_is_srgb = true
	for child in node.get_children():
		_finish(child)
