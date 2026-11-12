extends SubViewportContainer

## FishPhoto. The caught fish plays its intro, then loops swim, inside the
## cream card FishPanel puts over the dialog. The glb is already framed the
## way makeFishFrame places it, two units in front of the camera.

const _CREAM := Color(1.0, 1.0, 0.749, 1.0)

var _view: SubViewport
var _root: Node3D
var _meshes: Array[MeshInstance3D] = []
var _materials: Array = []
var _uvs: Array = []
var _colors: Array = []
var _counts: Array = []
var _frames: Array = []
var _intro := 0
var _swim := 0
var _fps := 24.0
var _time := 0.0
var _playing := false


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_view = SubViewport.new()
	_view.name = "Swim"
	_view.own_world_3d = true
	_view.transparent_bg = false
	_view.handle_input_locally = false
	_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_view.size = Vector2i(512, 512)
	var world := World3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = _CREAM
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.0
	world.environment = env
	_view.world_3d = world
	add_child(_view)
	var camera := Camera3D.new()
	camera.fov = 40.0
	camera.near = 0.1
	camera.far = 100.0
	camera.current = true
	_view.add_child(camera)
	_root = Node3D.new()
	_root.name = "FishRoot"
	_view.add_child(_root)


func show_genus(genus: int) -> void:
	clear()
	var glb := load("res://assets/props/fish/genus_%d.glb" % genus) as PackedScene
	var clip := "res://assets/props/fish/genus_%d.bin" % genus
	if glb == null or not FileAccess.file_exists(clip):
		return
	var fish := glb.instantiate() as Node3D
	if fish == null:
		return
	_root.add_child(fish)
	_collect(fish)
	if not _read_clip(clip):
		clear()
		return
	_unshade()
	_time = 0.0
	_playing = true
	visible = true
	_apply(0)
	set_process(true)


func clear() -> void:
	_playing = false
	set_process(false)
	visible = false
	_frames.clear()
	_meshes.clear()
	_materials.clear()
	_uvs.clear()
	_colors.clear()
	_counts.clear()
	_intro = 0
	_swim = 0
	if _root == null:
		return
	for child in _root.get_children():
		child.free()


func _process(delta: float) -> void:
	if not _playing or _frames.is_empty():
		return
	_time += delta
	var frame := int(_time * _fps)
	if _swim > 0 and _intro > 0 and _frames.size() == _intro + _swim:
		if frame < _intro:
			_apply(frame)
		else:
			_apply(_intro + (frame - _intro) % _swim)
	else:
		var count := maxi(_frames.size(), 1)
		_apply(frame % count)


func _collect(fish: Node3D) -> void:
	var found: Array[MeshInstance3D] = []
	for node in fish.find_children("fish_*", "MeshInstance3D", true, false):
		found.append(node as MeshInstance3D)
	found.sort_custom(func(a: MeshInstance3D, b: MeshInstance3D) -> bool:
		return String(a.name) < String(b.name)
	)
	for mesh_node in found:
		_meshes.append(mesh_node)
		var materials: Array = []
		var mesh := mesh_node.mesh
		var count := 0 if mesh == null else mesh.get_surface_count()
		for surface in count:
			var material := mesh_node.get_active_material(surface)
			if material == null and mesh != null:
				material = mesh.surface_get_material(surface)
			materials.append(material)
		_materials.append(materials)


func _read_clip(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var magic := file.get_buffer(8)
	if magic.slice(0, 7).get_string_from_ascii() != "FISH200":
		return false
	_intro = file.get_32()
	_swim = file.get_32()
	_fps = file.get_float()
	if _fps <= 0.0:
		_fps = 24.0
	var geom_count := file.get_32()
	_uvs.clear()
	_colors.clear()
	_counts.clear()
	for _geom in geom_count:
		var surface_count := file.get_32()
		var geom_uvs: Array = []
		var geom_colors: Array = []
		var geom_counts: Array = []
		for _surface in surface_count:
			var verts := file.get_32()
			var flags := file.get_8()
			var uv := PackedVector2Array()
			if flags & 1:
				uv.resize(verts)
				for index in verts:
					uv[index] = Vector2(file.get_float(), file.get_float())
			var color := PackedColorArray()
			if flags & 2:
				color.resize(verts)
				for index in verts:
					color[index] = Color(file.get_float(), file.get_float(), file.get_float(), file.get_float())
			geom_uvs.append(uv)
			geom_colors.append(color)
			geom_counts.append(verts)
		_uvs.append(geom_uvs)
		_colors.append(geom_colors)
		_counts.append(geom_counts)
	var frame_count := file.get_32()
	for _frame in frame_count:
		var frame: Array = []
		for geom in geom_count:
			var surfaces: Array = []
			var geom_counts: Array = _counts[geom]
			for surface in geom_counts.size():
				var verts := int(geom_counts[surface])
				var positions := PackedVector3Array()
				positions.resize(verts)
				for index in verts:
					positions[index] = Vector3(file.get_float(), file.get_float(), file.get_float())
				surfaces.append(positions)
			frame.append(surfaces)
		_frames.append(frame)
	return not _frames.is_empty() and _meshes.size() == geom_count


func _unshade() -> void:
	for geom in _materials.size():
		var materials: Array = _materials[geom]
		for surface in materials.size():
			var source = materials[surface]
			if not (source is StandardMaterial3D):
				continue
			var copy := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
			copy.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			copy.cull_mode = BaseMaterial3D.CULL_DISABLED
			materials[surface] = copy


func _apply(frame_index: int) -> void:
	if frame_index < 0 or frame_index >= _frames.size():
		return
	var frame: Array = _frames[frame_index]
	for geom in mini(_meshes.size(), frame.size()):
		var mesh_node := _meshes[geom]
		var built := ArrayMesh.new()
		var surfaces: Array = frame[geom]
		var geom_uvs: Array = _uvs[geom]
		var geom_colors: Array = _colors[geom]
		var materials: Array = _materials[geom]
		for surface in surfaces.size():
			var positions: PackedVector3Array = surfaces[surface]
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = positions
			var uv: PackedVector2Array = geom_uvs[surface]
			if uv.size() == positions.size():
				arrays[Mesh.ARRAY_TEX_UV] = uv
			var color: PackedColorArray = geom_colors[surface]
			if color.size() == positions.size():
				arrays[Mesh.ARRAY_COLOR] = color
			built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			if surface < materials.size() and materials[surface] is Material:
				built.surface_set_material(surface, materials[surface])
		mesh_node.mesh = built
