@tool
extends Node3D

## Playground motion that the bind-pose export cannot carry on its own.
## The sky is the shared Toontown dome. Fish, the HQ telescope, butterflies, and ice-cream treasures
## replay the original cycles. Flat cards yaw to face the camera.

const FISH_PATH := "res://assets/neighborhoods/toontown_central/props/fish_swim.json"
const TELESCOPE_PATH := "res://assets/neighborhoods/toontown_central/props/telescope.json"
const BUTTERFLY_SCENE := "res://assets/neighborhoods/toontown_central/props/butterfly.glb"
const TREASURE_SCENE := "res://assets/neighborhoods/toontown_central/props/icecream.glb"
const SHADOW_TEXTURE := "res://assets/neighborhoods/toontown_central/props/drop_shadow.png"
const MUSIC_PATH := "res://assets/neighborhoods/toontown_central/audio/TC_nbrhood.ogg"
const MUSIC_VOLUME := 0.8
const TOONTOWN_SKY := preload("res://scenes/sky/toontown_sky.gd")
var _billboards: Array[Dictionary] = []

var _fish_fps := 24.0

var _scope_mesh: ArrayMesh
var _scope_material: Material
var _scope_instance: MeshInstance3D
var _scope_tip: Node3D
var _scope_frames: Array[PackedVector3Array] = []
var _scope_tips: Array[Transform3D] = []
var _scope_uvs := PackedVector2Array()
var _scope_colors := PackedColorArray()
var _scope_normals := PackedVector3Array()
var _scope_fps := 24.0

var _butterflies: Array[Dictionary] = []
var _treasures: Array[Node3D] = []

var _time := 0.0


func _ready() -> void:
	TOONTOWN_SKY.ensure(self)
	if Engine.is_editor_hint():
		return
	_ready_music()
	_close_hq_doors(self)
	_hide_back_pigs(self)
	_ready_billboards()
	_ready_fish()
	_ready_telescope()
	_ready_butterflies()
	_ready_treasures()
	preload("res://scenes/playgrounds/playground_toon.gd").attach(self)


func _ready_music() -> void:
	# Playground.enter loops loader.music at 0.8. Toontown Central's playground
	# track is TC_nbrhood ("Toontown Central"). The street theme is TC_SZ.
	if not FileAccess.file_exists(MUSIC_PATH):
		return
	var stream := AudioStreamOggVorbis.load_from_file(MUSIC_PATH)
	if stream == null:
		return
	stream.loop = true
	var player := AudioStreamPlayer.new()
	player.name = "PlaygroundMusic"
	player.stream = stream
	player.volume_db = linear_to_db(MUSIC_VOLUME)
	add_child(player)
	player.play()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		TOONTOWN_SKY.restore_imported(self)


func _process(delta: float) -> void:
	TOONTOWN_SKY.ensure(self)
	if Engine.is_editor_hint():
		return
	_time += delta
	var camera := _view_camera()
	_process_billboards(camera)
	_process_fish()
	_process_telescope()
	_process_butterflies(delta)
	_process_treasures(delta, camera)


func _view_camera() -> Camera3D:
	if not Engine.is_editor_hint():
		var game_view := get_viewport()
		if game_view == null:
			return null
		return game_view.get_camera_3d()
	var editor := Engine.get_singleton("EditorInterface")
	if editor == null:
		return null
	var editor_view := editor.call("get_editor_viewport_3d", 0) as Viewport
	if editor_view == null:
		return null
	return editor_view.get_camera_3d()


func _ready_billboards() -> void:
	_collect_billboards(self)


func _collect_billboards(node: Node) -> void:
	if node is Node3D and (node as Node3D).visible and (node.is_in_group("tt_billboard") or String(node.name).contains("__billboard")):
		_billboards.append({"node": node, "rest": (node as Node3D).global_transform.basis})
		if node is MeshInstance3D:
			_show_both_sides(node as MeshInstance3D)
	for child in node.get_children():
		_collect_billboards(child)


func _process_billboards(camera: Camera3D) -> void:
	if camera == null:
		return
	for item in _billboards:
		var node := item["node"] as Node3D
		var rest := item["rest"] as Basis
		_yaw_toward(node, rest, camera.global_position)


func _yaw_toward(node: Node3D, rest: Basis, target: Vector3) -> void:
	# The card is flat along local Y, and the visible winding faces -Y.
	# Aim that side at the camera. Aiming +Y shows the culled back, which is
	# why the trees vanished and the bank piggy swung around to the roof's back.
	var face := Vector3(-rest.y.x, 0.0, -rest.y.z)
	var to_target := target - node.global_position
	to_target.y = 0.0
	if face.length() < 0.0001 or to_target.length() < 0.0001:
		return
	var turned := node.global_transform
	turned.basis = rest.rotated(Vector3.UP, face.signed_angle_to(to_target, Vector3.UP))
	node.global_transform = turned


func _close_hq_doors(node: Node) -> void:
	# A closed HQ door shows the painted flat. The swinging doors and the
	# black frame hole are only revealed while the door is opening.
	var node_name := String(node.name)
	if node_name.begins_with("doorFrameHole") or node_name.begins_with("leftDoor") or node_name.begins_with("rightDoor"):
		node.visible = false
	if node_name.begins_with("door_flat"):
		_show_door_flat(node)
	for child in node.get_children():
		_close_hq_doors(child)


func _show_door_flat(node: Node) -> void:
	if node is MeshInstance3D:
		_show_both_sides(node as MeshInstance3D)
	for child in node.get_children():
		if not String(child.name).begins_with("doorFrameHole"):
			_show_door_flat(child)


func _hide_back_pigs(node: Node) -> void:
	# roof_pig faces the street. The other two cards sit inside the back wall.
	var node_name := String(node.name)
	if node_name.begins_with("roof_pig_1") or node_name.begins_with("roof_pig_2"):
		node.visible = false
	for child in node.get_children():
		_hide_back_pigs(child)


func _ready_fish() -> void:
	var data = _read_json(FISH_PATH)
	if data.is_empty():
		return
	_fish_fps = float(data.get("fps", 24.0))
	var joints := {}
	for joint_name in ["joint_fish1", "joint_fish2"]:
		var joint := find_child(joint_name, true, false) as Node3D
		if joint:
			joints[joint_name] = joint
	if joints.is_empty():
		return
	set_meta("fish_joints", joints)
	set_meta("fish_frames", data["frames"])


func _process_fish() -> void:
	if not has_meta("fish_frames"):
		return
	var frames: Array = get_meta("fish_frames")
	var joints: Dictionary = get_meta("fish_joints")
	if frames.is_empty():
		return
	var count := frames.size()
	var sample := _time * _fish_fps
	var i0 := int(floorf(sample)) % count
	var i1 := (i0 + 1) % count
	var blend := sample - floorf(sample)
	var frame_a: Dictionary = frames[i0]
	var frame_b: Dictionary = frames[i1]
	for joint_name in joints:
		var joint := joints[joint_name] as Node3D
		var from_pose := _panda_transform(frame_a[joint_name])
		var to_pose := _panda_transform(frame_b[joint_name])
		joint.transform = from_pose.interpolate_with(to_pose, blend)


func _ready_telescope() -> void:
	var data = _read_json(TELESCOPE_PATH)
	var prop := find_child("animated_prop_HQTelescopeAnimatedProp_DNARoot", true, false) as Node3D
	if data.is_empty() or prop == null:
		return
	var body: MeshInstance3D
	for child in prop.get_children():
		if child is MeshInstance3D:
			body = child
			break
	if body == null or body.mesh == null:
		return
	_scope_fps = float(data.get("fps", 24.0))
	_scope_material = body.mesh.surface_get_material(0)
	if _scope_material is StandardMaterial3D:
		var standard := (_scope_material as StandardMaterial3D).duplicate() as StandardMaterial3D
		standard.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		standard.cull_mode = BaseMaterial3D.CULL_DISABLED
		_scope_material = standard
	_scope_tip = prop.find_child("joint_thirdSection", true, false) as Node3D
	var count := 0
	for flat in data["frames"]:
		var positions := PackedVector3Array()
		positions.resize(flat.size() / 3)
		for i in positions.size():
			positions[i] = Vector3(flat[i * 3], flat[i * 3 + 1], flat[i * 3 + 2])
		if count == 0:
			count = positions.size()
			_scope_normals.resize(count)
			_scope_normals.fill(Vector3.UP)
			if data["uv"].size() == count * 2:
				_scope_uvs.resize(count)
				for i in count:
					_scope_uvs[i] = Vector2(data["uv"][i * 2], data["uv"][i * 2 + 1])
			if data["color"].size() == count * 4:
				_scope_colors.resize(count)
				for i in count:
					_scope_colors[i] = Color(data["color"][i * 4], data["color"][i * 4 + 1], data["color"][i * 4 + 2], data["color"][i * 4 + 3])
		_scope_frames.append(positions)
	for flat in data["tip"]:
		_scope_tips.append(_panda_transform(flat))
	_scope_mesh = ArrayMesh.new()
	_scope_instance = MeshInstance3D.new()
	_scope_instance.name = "telescope_anim"
	body.add_sibling(_scope_instance)
	_scope_instance.transform = body.transform
	_scope_instance.mesh = _scope_mesh
	body.visible = false
	_show_telescope(0)


func _process_telescope() -> void:
	if _scope_frames.is_empty():
		return
	_show_telescope(_telescope_frame())


func _telescope_frame() -> float:
	# HQTelescopeAnimatedProp's sequence, held on the final frame of each span.
	var clips: Array = [
		[0, 0, 5.0],
		[0, 32, 0.5],
		[32, 78, 0.5],
		[79, 112, 0.5],
		[112, 79, 0.5],
		[78, 32, 0.5],
		[32, 78, 0.5],
		[79, 112, 0.5],
		[112, 148, 4.0],
	]
	var cycle := 0.0
	for clip in clips:
		var start_frame := float(clip[0])
		var end_frame := float(clip[1])
		var hold := float(clip[2])
		cycle += absf(end_frame - start_frame) / _scope_fps + hold
	var t := fmod(_time, cycle)
	for clip in clips:
		var start_frame := float(clip[0])
		var end_frame := float(clip[1])
		var hold := float(clip[2])
		var span := absf(end_frame - start_frame) / _scope_fps
		if t <= span:
			var along := 0.0 if span == 0.0 else t / span
			return lerpf(start_frame, end_frame, along)
		t -= span
		if t <= hold:
			return end_frame
		t -= hold
	return 0.0


func _show_telescope(frame: float) -> void:
	var last := _scope_frames.size() - 1
	var clamped := clampf(frame, 0.0, float(last))
	var i0 := clampi(int(floorf(clamped)), 0, last)
	var i1 := clampi(i0 + 1, 0, last)
	var along := clamped - float(i0)
	var from_frame := _scope_frames[i0]
	var to_frame := _scope_frames[i1]
	var positions := PackedVector3Array()
	positions.resize(from_frame.size())
	for i in from_frame.size():
		positions[i] = from_frame[i].lerp(to_frame[i], along)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = _scope_normals
	if not _scope_uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = _scope_uvs
	if not _scope_colors.is_empty():
		arrays[Mesh.ARRAY_COLOR] = _scope_colors
	_scope_mesh.clear_surfaces()
	_scope_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_scope_mesh.surface_set_material(0, _scope_material)
	if i0 < _scope_tips.size() and _scope_tip:
		var tip_b := i1 if i1 < _scope_tips.size() else i0
		# The head joint is scaled out along the tube. Quaternion blending
		# drops that scale and leaves the lens behind.
		_scope_tip.transform = _lerp_scaled(_scope_tips[i0], _scope_tips[tip_b], along)


func _lerp_scaled(from_pose: Transform3D, to_pose: Transform3D, along: float) -> Transform3D:
	var basis := Basis(
		from_pose.basis.x.lerp(to_pose.basis.x, along),
		from_pose.basis.y.lerp(to_pose.basis.y, along),
		from_pose.basis.z.lerp(to_pose.basis.z, along)
	)
	return Transform3D(basis, from_pose.origin.lerp(to_pose.origin, along))


func _ready_butterflies() -> void:
	if not ResourceLoader.exists(BUTTERFLY_SCENE):
		return
	var packed := load(BUTTERFLY_SCENE) as PackedScene
	var areas := _butterfly_areas()
	var colors := [
		Color(1, 1, 1),
		Color(0.2, 0, 1),
		Color(0.8, 0, 0.8),
		Color(0, 0.8, 0.8),
		Color(0.9, 0.4, 0.6),
		Color(1, 1, 1),
	]
	# HoodDataAI places NUM_BUTTERFLIES in every area: 6 x 4 in Toontown Central.
	var made := 0
	for area_index in areas.size():
		for copy in 6:
			var actor := packed.instantiate() as Node3D
			actor.name = "butterfly_%d" % made
			add_child(actor)
			_style_actor(actor)
			var wing := "wings_%d" % (made % 6 + 1)
			var model := actor
			var flutter_root := actor.find_child("flutter_00", true, false)
			if flutter_root:
				model = flutter_root.get_parent()
			var frames: Array[Node] = []
			var landed: Node
			for child in model.get_children():
				if child.name == "landed":
					landed = child
				elif String(child.name).begins_with("flutter_"):
					frames.append(child)
				_select_wing(child, wing, colors[made % colors.size()])
			frames.sort_custom(func(a, b): return String(a.name) < String(b.name))
			var points: Array = areas[area_index]
			var start: int = (copy * 5) % points.size()
			_butterflies.append({
				"frames": frames,
				"landed": landed,
				"points": points,
				"index": start,
				"dest": (start + 3) % points.size(),
				"state": "takeoff" if made % 2 == 0 else "landed",
				"wait": 0.4,
				"elapsed": 0.0,
				"from": points[start],
				"to": points[start],
				"phase": randf() * 4.0,
				"root": actor,
			})
			actor.global_position = points[start]
			if made % 2 == 0:
				_face_flat(actor, points[(start + 3) % points.size()])
			_make_flutter_player(_butterflies[_butterflies.size() - 1])
			made += 1


func _process_butterflies(delta: float) -> void:
	for actor in _butterflies:
		var root := actor["root"] as Node3D
		var state := String(actor["state"])
		actor["elapsed"] = float(actor["elapsed"]) + delta
		var points: Array = actor["points"]
		var origin: Vector3 = points[actor["index"]]
		var dest: Vector3 = points[actor["dest"]]
		var high := maxf(origin.y, dest.y) + 2.2
		var origin_high := Vector3(origin.x, high, origin.z)
		var dest_high := Vector3(dest.x, high, dest.z)
		if state == "landed":
			root.global_position = origin
			if float(actor["elapsed"]) >= float(actor["wait"]):
				actor["state"] = "takeoff"
				actor["elapsed"] = 0.0
				_face_flat(root, dest)
		elif state == "takeoff":
			var u := clampf(float(actor["elapsed"]) / 1.4, 0.0, 1.0)
			root.global_position = origin.lerp(origin_high, u)
			if u >= 1.0:
				actor["state"] = "fly"
				actor["elapsed"] = 0.0
		elif state == "fly":
			var step := dest_high - root.global_position
			step.y = 0.0
			var distance := step.length()
			if distance <= delta * 2.0:
				root.global_position = dest_high
				actor["state"] = "landing"
				actor["elapsed"] = 0.0
			else:
				root.global_position += step.normalized() * delta * 2.0
		elif state == "landing":
			var u := clampf(float(actor["elapsed"]) / 1.4, 0.0, 1.0)
			root.global_position = dest_high.lerp(dest, u)
			if u >= 1.0:
				actor["index"] = actor["dest"]
				var next := randi() % points.size()
				if next == int(actor["index"]):
					next = (next + 1) % points.size()
				actor["dest"] = next
				actor["state"] = "landed"
				actor["elapsed"] = 0.0
				actor["wait"] = randf_range(4.0, 12.0)
				root.global_position = dest
		var fluttering := String(actor["state"]) != "landed"
		var play: Node = actor.get("play")
		if play:
			play.visible = fluttering
			if fluttering:
				_blend_flutter(actor)
		var landed: Node = actor["landed"]
		if landed:
			landed.visible = not fluttering


func _ready_treasures() -> void:
	if not ResourceLoader.exists(TREASURE_SCENE):
		return
	var packed := load(TREASURE_SCENE) as PackedScene
	var points := _treasure_points()
	for point in points:
		var root := Node3D.new()
		root.name = "treasure_%d" % _treasures.size()
		root.scale = Vector3(0.9, 0.9, 0.9)
		add_child(root)
		root.global_position = point
		var model := packed.instantiate() as Node3D
		model.name = "model"
		root.add_child(model)
		_style_actor(model)
		root.add_child(_make_treasure_shadow())
		root.visible = false
		_treasures.append(model)
	# Five are placed at the start. They stay until grabbed. The original 20
	# second task only fills an empty spot; it does not move one that is still there.
	var order: Array[int] = []
	for i in _treasures.size():
		order.append(i)
	order.shuffle()
	for n in mini(order.size(), 5):
		(_treasures[order[n]].get_parent() as Node3D).visible = true


func _process_treasures(_delta: float, camera: Camera3D) -> void:
	if camera == null:
		return
	for model in _treasures:
		var root := model.get_parent() as Node3D
		if root == null or not root.visible:
			continue
		var flat := camera.global_position - root.global_position
		flat.y = 0.0
		if flat.length() < 0.001:
			continue
		# The cone's visible side is +Z. look_at aims -Z at the point, so aim
		# it away from the camera and the picture faces the player. The shadow
		# stays flat on the ground.
		model.look_at(model.global_position - flat, Vector3.UP)


func _make_treasure_shadow() -> MeshInstance3D:
	# phase_3/models/props/drop_shadow, tinted black at half strength, sitting
	# just above the ground. The card is 8 units across and then scaled by 0.4.
	var mesh := QuadMesh.new()
	mesh.orientation = PlaneMesh.FACE_Y
	mesh.size = Vector2(8.0, 8.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.0, 0.0, 0.0, 0.5)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var texture := load(SHADOW_TEXTURE) as Texture2D
	if texture:
		material.albedo_texture = texture
	var shadow := MeshInstance3D.new()
	shadow.name = "shadow"
	shadow.mesh = mesh
	shadow.material_override = material
	shadow.position = Vector3(0.0, 0.025, 0.0)
	shadow.scale = Vector3(0.4, 0.4, 0.4)
	return shadow


func _style_actor(root: Node) -> void:
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D
		var source := mesh_instance.get_active_material(0)
		if source is StandardMaterial3D:
			var material := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.vertex_color_use_as_albedo = true
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			if material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh_instance.material_override = material
			mesh_instance.lod_bias = 128.0
	for child in root.get_children():
		_style_actor(child)


func _select_wing(node: Node, wing: String, tint: Color) -> void:
	# The importer keeps the first wings_1 and renames the copies wings_12, wings_151,
	# and so on. An exact name check hid every copy, so the butterfly was only a body.
	var wanted := _wing_kind(wing)
	_select_wing_kind(node, wanted, tint)


func _select_wing_kind(node: Node, wanted: int, tint: Color) -> void:
	var kind := _wing_kind(String(node.name))
	if kind > 0 and kind != wanted:
		node.visible = false
	elif kind == wanted and node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var source := mesh_instance.material_override
		if source == null:
			source = mesh_instance.get_active_material(0)
		if source is StandardMaterial3D:
			var material := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
			material.albedo_color = tint
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh_instance.material_override = material
		mesh_instance.lod_bias = 128.0
	for child in node.get_children():
		_select_wing_kind(child, wanted, tint)


func _wing_kind(node_name: String) -> int:
	if not node_name.begins_with("wings_"):
		return 0
	var rest := node_name.substr(6)
	if rest.is_empty():
		return 0
	var digit := rest.unicode_at(0)
	if digit < 49 or digit > 54:
		return 0
	var suffix := rest.substr(1)
	if not suffix.is_empty() and not suffix.is_valid_int():
		return 0
	return digit - 48


func _part_key(node_name: String) -> String:
	var kind := _wing_kind(node_name)
	if kind > 0:
		return "wings_%d" % kind
	var end := node_name.length()
	while end > 0 and node_name.unicode_at(end - 1) >= 48 and node_name.unicode_at(end - 1) <= 57:
		end -= 1
	if end == 0 or end == node_name.length():
		return node_name
	return node_name.substr(0, end)


func _show_both_sides(mesh_instance: MeshInstance3D) -> void:
	var mesh := mesh_instance.mesh
	if mesh == null:
		return
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface)
		if material is StandardMaterial3D:
			var standard := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
			standard.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.surface_set_material(surface, standard)


func _make_flutter_player(actor: Dictionary) -> void:
	var frames: Array = actor["frames"]
	if frames.is_empty():
		return
	var model := (frames[0] as Node).get_parent()
	var play := Node3D.new()
	play.name = "flutter_play"
	model.add_child(play)
	var caches: Array = []
	for frame in frames:
		caches.append(_capture_visible_meshes(frame as Node))
		(frame as Node).visible = false
	var first: Array = caches[0]
	var parts: Array = []
	for i in first.size():
		var source: Dictionary = first[i]
		var mesh := ArrayMesh.new()
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.transform = source["xform"]
		instance.lod_bias = 128.0
		play.add_child(instance)
		parts.append({
			"name": source["name"],
			"mesh": mesh,
			"uv": source["uv"],
			"color": source["color"],
			"material": source["material"],
		})
	actor["play"] = play
	actor["parts"] = parts
	actor["caches"] = caches
	actor["rate"] = randf_range(0.6, 1.4)
	play.visible = false


func _capture_visible_meshes(root: Node) -> Array:
	var found: Array = []
	_capture_mesh_walk(root, Transform3D.IDENTITY, found, "")
	return found


func _capture_mesh_walk(node: Node, parent: Transform3D, found: Array, path: String) -> void:
	var here := parent
	var next := path + "/" + String(node.name)
	if node is Node3D:
		here = parent * (node as Node3D).transform
	if node is MeshInstance3D and node.visible:
		var mesh := (node as MeshInstance3D).mesh
		if mesh and mesh.get_surface_count() > 0:
			var arrays := mesh.surface_get_arrays(0)
			var uvs := PackedVector2Array()
			var colors := PackedColorArray()
			var verts := PackedVector3Array()
			if arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
				verts = arrays[Mesh.ARRAY_VERTEX]
			if arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array:
				uvs = arrays[Mesh.ARRAY_TEX_UV]
			if arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
				colors = arrays[Mesh.ARRAY_COLOR]
			if not verts.is_empty():
				var active := (node as MeshInstance3D).get_active_material(0)
				found.append({
					"name": _part_key(String(node.name)),
					"xform": here,
					"verts": verts,
					"uv": uvs,
					"color": colors,
					"material": active,
				})
	for child in node.get_children():
		if child.visible:
			_capture_mesh_walk(child, here, found, next)


func _blend_flutter(actor: Dictionary) -> void:
	var caches: Array = actor["caches"]
	var parts: Array = actor["parts"]
	if caches.is_empty() or parts.is_empty():
		return
	var sample := (_time + float(actor["phase"])) * 12.0 * float(actor["rate"])
	var count := caches.size()
	var i0 := int(floorf(sample)) % count
	var i1 := (i0 + 1) % count
	var along := sample - floorf(sample)
	var pose_a := _poses_by_name(caches[i0])
	var pose_b := _poses_by_name(caches[i1])
	for i in parts.size():
		var part_name := String(parts[i]["name"])
		if not pose_a.has(part_name) or not pose_b.has(part_name):
			continue
		var from_part: Dictionary = pose_a[part_name]
		var to_part: Dictionary = pose_b[part_name]
		var from_verts: PackedVector3Array = from_part["verts"]
		var to_verts: PackedVector3Array = to_part["verts"]
		if from_verts.size() != to_verts.size() or from_verts.is_empty():
			continue
		var blended := PackedVector3Array()
		blended.resize(from_verts.size())
		for v in from_verts.size():
			blended[v] = from_verts[v].lerp(to_verts[v], along)
		var mesh: ArrayMesh = parts[i]["mesh"]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = blended
		var uvs: PackedVector2Array = parts[i]["uv"]
		if uvs.size() == blended.size():
			arrays[Mesh.ARRAY_TEX_UV] = uvs
		var colors: PackedColorArray = parts[i]["color"]
		if colors.size() == blended.size():
			arrays[Mesh.ARRAY_COLOR] = colors
		mesh.clear_surfaces()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, parts[i]["material"])


func _poses_by_name(pose: Array) -> Dictionary:
	var named := {}
	for part in pose:
		named[String(part["name"])] = part
	return named


func _face_flat(node: Node3D, target: Vector3) -> void:
	var flat := target - node.global_position
	flat.y = 0.0
	if flat.length() < 0.001:
		return
	node.look_at(node.global_position + flat, Vector3.UP)


func _panda_transform(cells: Array) -> Transform3D:
	# The exporter writes Panda's row-major matrix into glTF's column-major slot.
	var basis := Basis(
		Vector3(cells[0], cells[1], cells[2]),
		Vector3(cells[4], cells[5], cells[6]),
		Vector3(cells[8], cells[9], cells[10])
	)
	return Transform3D(basis, Vector3(cells[12], cells[13], cells[14]))


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _butterfly_areas() -> Array:
	return [
		_points([[84.0, -116.0, 3.5], [95.0, -144.0, 2.6], [94.0, -145.0, 2.6], [95.0, -149.0, 2.6], [50.0, -155.0, 2.6], [51.0, -147.0, 2.6], [51.0, -145.0, 2.6], [14.0, -99.0, 3.1], [17.0, -94.0, 3.1], [50.0, -79.0, 3.1], [47.0, -86.0, 3.1], [54.0, -127.0, 2.6], [84.0, -113.0, 3.8]]),
		_points([[-57.0, -70.0, 0.1], [-55.0, -68.0, 0.1], [-90.0, -77.0, 0.6], [-90.0, -72.0, 0.1], [-133.0, -50.0, 0.6], [-129.0, -48.0, 0.6], [-127.0, -25.0, 0.1], [-125.0, -22.0, 0.1], [-123.0, -22.0, 0.1], [-103.0, -10.0, -3.0], [-104.0, -13.0, -2.5], [-100.0, -28.0, -2.7], [-89.0, -41.0, -4.4], [-58.0, -34.0, -4.1], [-69.0, -18.0, -1.9], [-65.0, -19.0, -1.9], [-65.0, -16.0, -1.9], [6.0, -49.0, -0.1], [2.6, -47.0, 0.1], [-33.6, -43.0, 0.0]]),
		_points([[-53.0, 3.0, -1.8], [-58.0, 2.0, -1.8], [-76.0, 2.0, -1.8], [-69.0, 11.0, -1.8], [-100.0, 14.0, -4.1], [-104.0, 17.0, -2.6], [-125.0, 34.0, 0.1], [-124.0, 30.0, 0.1], [-113.0, 73.0, 0.6], [-33.0, 78.0, 0.1], [-65.0, 48.0, -3.0], [-51.0, 33.0, -3.0], [-30.0, 71.0, 0.1], [-26.0, 71.0, 0.1], [-23.0, 69.0, 0.1], [-23.0, 64.0, 0.1], [-5.0, 42.0, 0.1], [-22.0, 22.0, 0.1], [-27.0, 22.0, 0.1]]),
		_points([[14.0, 93.0, 3.1], [17.0, 93.0, 3.1], [20.0, 122.0, 2.6], [21.0, 127.0, 2.6], [23.0, 123.0, 2.6], [32.0, 130.0, 2.6], [48.0, 148.0, 2.6], [64.0, 111.0, 2.6], [32.0, 82.0, 2.6], [63.0, 90.0, 3.1], [68.0, 85.0, 3.1], [65.0, 85.0, 3.1], [70.0, 95.0, 3.1]]),
	]


func _treasure_points() -> Array[Vector3]:
	var raw := [
		[-59.9, -6.9, 0.84], [-90.6, -3.0, -0.75], [27.1, -93.5, 2.5], [94.2, 33.5, 4.0], [35.4, 43.1, 4.0],
		[67.1, 105.5, 2.5], [-99.15, -87.3407, 0.52499], [1.60586, -119.492, 3.025], [43.2026, -76.287, 3.025],
		[129.137, -61.9039, 2.525], [92.99, -158.399, 3.025], [111.749, -8.59927, 4.57466], [41.999, -30.2923, 4.025],
		[31.0649, -43.9149, 4.025], [10.0156, 105.218, 2.525], [46.9667, 169.143, 3.025], [100.68, 93.9896, 2.525],
		[129.285, 58.6107, 2.525], [-28.6272, 85.9833, 0.525], [-114.613, 86.1727, 0.525], [-132.528, 31.255, 0.025],
	]
	var points: Array[Vector3] = []
	for item in raw:
		points.append(Vector3(item[0], item[2], -item[1]))
	return points


func _points(raw: Array) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for item in raw:
		points.append(Vector3(item[0], item[2], -item[1]))
	return points
