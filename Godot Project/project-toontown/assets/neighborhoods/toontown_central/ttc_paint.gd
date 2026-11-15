extends RefCounted

## Toontown is texture and vertex color, drawn unshaded. Flat factors are already
## Godot colors. Vertex colors are the source sRGB numbers, so only surfaces that
## actually carry them should be decoded. Forcing that decode on every mesh turns
## uncolored hedges, doors, and signs black.
##
## This stays off the street importer. That script extends EditorScenePostImport,
## and an exported game cannot load an editor class.


static func paint(node: Node) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		paint_mesh(node as MeshInstance3D)
	for child in node.get_children():
		paint(child)


static func paint_mesh(mesh_node: MeshInstance3D) -> void:
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
		# surface_get_format is ArrayMesh only. A BoxMesh, such as the
		# toontorial HQ sidewalk patch, has no vertex colors to decode.
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR:
			standard.vertex_color_is_srgb = true
