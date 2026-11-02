extends RefCounted

## Toon Hall's windows, door, and wall shadow are painted on the front wall.
## The export leaves them a fraction of a foot off the wall. From across the
## playground one depth step is larger than that gap, so the cards are nudged
## out along their normals. The door and windows move farther than the shadow.

const _DECAL := preload("res://scenes/playgrounds/hall_decal.gdshader")
const _SHADOW := preload("res://scenes/playgrounds/hall_shadow.gdshader")
const _DECAL_UNITS := 0.28
const _SHADOW_UNITS := 0.1


static func apply(host: Node) -> void:
	var hall := _find(host, "toon_landmark_TT_toonhall")
	if hall == null:
		return
	var windows := _find_mesh(hall, "windows")
	if windows == null:
		return
	_cover(windows)
	var front := windows.get_parent()
	if front == null:
		return
	_cover_doors(front)
	var shell := front.get_parent()
	if shell is MeshInstance3D:
		_cover_shadow(shell as MeshInstance3D)


static func _cover_doors(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_name := String(node.name)
		if "door" in mesh_name and "flat" in mesh_name:
			_cover(node as MeshInstance3D)
	for child in node.get_children():
		_cover_doors(child)


static func _cover(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null:
		return
	for surface in mesh.mesh.get_surface_count():
		var source := mesh.mesh.surface_get_material(surface)
		mesh.set_surface_override_material(surface, _card(source, _DECAL, _DECAL_UNITS, true))


static func _cover_shadow(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null:
		return
	for surface in mesh.mesh.get_surface_count():
		var source := mesh.mesh.surface_get_material(surface)
		if not source is BaseMaterial3D:
			continue
		var standard := source as BaseMaterial3D
		# The glTF blend card imports as a depth pre-pass. That pre-pass is what
		# fights the wall. Alpha-scissor cutouts are the windows, handled above.
		var blends := standard.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA or standard.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		if not blends:
			continue
		if not _flat_card(mesh.mesh, surface):
			continue
		mesh.set_surface_override_material(surface, _card(source, _SHADOW, _SHADOW_UNITS, false))


static func _card(source: Material, shader: Shader, units: float, cutout: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	var texture: Texture2D = null
	var color := Color.WHITE
	var scissor := 0.5
	if source is BaseMaterial3D:
		var standard := source as BaseMaterial3D
		texture = standard.albedo_texture
		color = standard.albedo_color
		scissor = standard.alpha_scissor_threshold
	material.set_shader_parameter("albedo_color", color)
	material.set_shader_parameter("use_albedo_texture", 1.0 if texture != null else 0.0)
	material.set_shader_parameter("depth_units", units)
	if texture != null:
		material.set_shader_parameter("albedo_texture", texture)
	if cutout:
		material.set_shader_parameter("scissor_threshold", scissor)
	return material


static func _flat_card(mesh: Mesh, surface: int) -> bool:
	var arrays: Array = mesh.surface_get_arrays(surface)
	var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	if verts.is_empty():
		return false
	var low := verts[0]
	var high := verts[0]
	for point in verts:
		low = low.min(point)
		high = high.max(point)
	var span := high - low
	return minf(span.x, minf(span.y, span.z)) < 0.05


static func _find(node: Node, needle: String) -> Node:
	if needle in String(node.name):
		return node
	for child in node.get_children():
		var found := _find(child, needle)
		if found != null:
			return found
	return null


static func _find_mesh(node: Node, mesh_name: String) -> MeshInstance3D:
	if node is MeshInstance3D and String(node.name) == mesh_name:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh(child, mesh_name)
		if found != null:
			return found
	return null
