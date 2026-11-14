extends Node

## HoodDataAI.createButterflies for Daisy Gardens. One area, 36 butterflies.
## They fly 3.2 above the higher landing and take 1.8 seconds to leave and to land.

const SCENE := "res://assets/neighborhoods/toontown_central/props/butterfly.glb"
const COUNT := 36
const FLY_HEIGHT := 3.2
const TAKEOFF := 1.8
const LANDING := 1.8
const SPEED := 2.0

var _butterflies: Array[Dictionary] = []
var _grounded := false
var _tries := 0
var _time := 0.0


static func place(host: Node) -> void:
	if host == null or host.get_node_or_null("PlaygroundButterflies") != null:
		return
	var flock: Node = (load("res://scenes/playgrounds/playground_butterflies.gd") as GDScript).new()
	flock.name = "PlaygroundButterflies"
	host.add_child(flock)


func _ready() -> void:
	if not ResourceLoader.exists(SCENE):
		return
	var packed := load(SCENE) as PackedScene
	if packed == null:
		return
	var host := get_parent()
	if host == null:
		return
	var points := _garden_points()
	var colors := [
		Color(1, 1, 1),
		Color(0.2, 0, 1),
		Color(0.8, 0, 0.8),
		Color(0, 0.8, 0.8),
		Color(0.9, 0.4, 0.6),
		Color(1, 1, 1),
	]
	for copy in COUNT:
		var actor := packed.instantiate() as Node3D
		actor.name = "butterfly_%d" % copy
		host.add_child(actor)
		_style_actor(actor)
		var wing := "wings_%d" % (copy % 6 + 1)
		var model: Node = actor
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
			_select_wing(child, wing, colors[copy % colors.size()])
		frames.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name) < String(b.name))
		var start := (copy * 5) % points.size()
		var record := {
			"frames": frames,
			"landed": landed,
			"points": points,
			"index": start,
			"dest": (start + 3) % points.size(),
			"state": "takeoff" if copy % 2 == 0 else "landed",
			"wait": 0.4,
			"elapsed": 0.0,
			"phase": randf() * 4.0,
			"root": actor,
		}
		_butterflies.append(record)
		actor.global_position = points[start]
		if copy % 2 == 0:
			_face_flat(actor, points[(start + 3) % points.size()])
		_make_flutter_player(record)


func _process(delta: float) -> void:
	_time += delta
	if not _grounded:
		_tries += 1
		_grounded = _plant() or _tries >= 8
	_fly(delta)


func _plant() -> bool:
	var host := get_parent() as Node3D
	if host == null:
		return false
	var world := host.get_world_3d()
	if world == null:
		return false
	var space := world.direct_space_state
	var planted := 0
	var seen: Array = []
	for actor in _butterflies:
		var points: Array = actor["points"]
		if seen.has(points):
			continue
		seen.append(points)
		for index in points.size():
			var point: Vector3 = points[index]
			var grounded := _ground_at(space, point)
			if grounded.y != point.y:
				planted += 1
			points[index] = grounded
	for actor in _butterflies:
		var points: Array = actor["points"]
		var root := actor["root"] as Node3D
		var here := int(actor["index"])
		if String(actor["state"]) == "landed" and root != null and here < points.size():
			root.global_position = points[here]
	return planted > 0


func _ground_at(space: PhysicsDirectSpaceState3D, point: Vector3) -> Vector3:
	var from := Vector3(point.x, point.y + 25.0, point.z)
	var to := Vector3(point.x, point.y - 25.0, point.z)
	for step in 6:
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = 1
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return point
		var normal: Vector3 = hit["normal"]
		var position: Vector3 = hit["position"]
		if normal.y > 0.55:
			return Vector3(point.x, position.y + 0.02, point.z)
		from = Vector3(point.x, position.y - 0.2, point.z)
	return point


func _fly(delta: float) -> void:
	for actor in _butterflies:
		var root := actor["root"] as Node3D
		if root == null:
			continue
		var state := String(actor["state"])
		actor["elapsed"] = float(actor["elapsed"]) + delta
		var points: Array = actor["points"]
		var origin: Vector3 = points[int(actor["index"])]
		var dest: Vector3 = points[int(actor["dest"])]
		var high := maxf(origin.y, dest.y) + FLY_HEIGHT
		var origin_high := Vector3(origin.x, high, origin.z)
		var dest_high := Vector3(dest.x, high, dest.z)
		if state == "landed":
			root.global_position = origin
			if float(actor["elapsed"]) >= float(actor["wait"]):
				actor["state"] = "takeoff"
				actor["elapsed"] = 0.0
				_face_flat(root, dest)
		elif state == "takeoff":
			var u := clampf(float(actor["elapsed"]) / TAKEOFF, 0.0, 1.0)
			root.global_position = origin.lerp(origin_high, u)
			if u >= 1.0:
				actor["state"] = "fly"
				actor["elapsed"] = 0.0
		elif state == "fly":
			var step := dest_high - root.global_position
			step.y = 0.0
			var distance := step.length()
			if distance <= delta * SPEED:
				root.global_position = dest_high
				actor["state"] = "landing"
				actor["elapsed"] = 0.0
			else:
				root.global_position += step.normalized() * delta * SPEED
		elif state == "landing":
			var u := clampf(float(actor["elapsed"]) / LANDING, 0.0, 1.0)
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
			if fluttering and _wings_near(root):
				_blend_flutter(actor)
		var landed: Node = actor["landed"]
		if landed:
			landed.visible = not fluttering


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
	_select_wing_kind(node, _wing_kind(wing), tint)


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
	_capture_mesh_walk(root, Transform3D.IDENTITY, found)
	return found


func _capture_mesh_walk(node: Node, parent: Transform3D, found: Array) -> void:
	var here := parent
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
				found.append({
					"name": _part_key(String(node.name)),
					"xform": here,
					"verts": verts,
					"uv": uvs,
					"color": colors,
					"material": (node as MeshInstance3D).get_active_material(0),
				})
	for child in node.get_children():
		if child.visible:
			_capture_mesh_walk(child, here, found)


func _wings_near(root: Node3D) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return true
	return camera.global_position.distance_squared_to(root.global_position) < 80.0 * 80.0


func _blend_flutter(actor: Dictionary) -> void:
	var caches: Array = actor["caches"]
	var parts: Array = actor["parts"]
	if caches.is_empty() or parts.is_empty():
		return
	var sample := (_time + float(actor["phase"])) * 12.0 * float(actor["rate"])
	var count := caches.size()
	var i0 := int(floorf(sample)) % count
	var along := sample - floorf(sample)
	var step := int(along * 4.0)
	if int(actor.get("pose_frame", -1)) == i0 and int(actor.get("pose_step", -1)) == step:
		return
	actor["pose_frame"] = i0
	actor["pose_step"] = step
	along = float(step) / 4.0
	var i1 := (i0 + 1) % count
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


func _garden_points() -> Array[Vector3]:
	var raw: Array = [
		[-7.9, 22.9, 0.05], [-8.0, 17.0, 2.1], [-7.5, 18.0, 2.1], [-27.5, 70.7, 0.05],
		[-30.0, 70.0, 1.0], [-31.0, 69.0, 1.0], [-1.0, 53.0, 2.2], [-0.5, 53.0, 2.2],
		[35.0, 71.5, 1.0], [33.0, 69.0, 0.05], [45.0, 61.0, 0.05], [55.0, 62.0, 0.05],
		[80.0, 74.0, 0.05], [80.0, 73.0, 0.05], [76.0, 46.0, 0.05], [76.0, 45.0, 0.05],
		[77.0, 41.0, 0.05], [62.0, 28.0, 0.05], [48.0, 24.0, 0.05], [83.0, 122.0, 0.05],
		[82.0, 123.0, 0.05], [81.0, 81.0, 0.05], [38.0, 77.0, 0.05], [-26.0, 69.0, 0.05],
		[-26.0, 70.0, 0.05], [-61.0, 71.0, 0.05], [-61.0, 70.0, 0.05], [-78.0, 79.0, 0.05],
		[-99.0, 106.0, 0.05], [-99.0, 108.0, 0.05], [-80.0, 123.0, 0.05], [-77.0, 125.0, 0.05],
		[-32.0, 162.0, 0.05], [-3.0, 186.5, 2.2], [-3.2, 186.8, 2.2], [-1.0, 185.0, 2.2],
		[39.0, 165.0, 0.05], [42.0, 162.0, 0.05], [62.0, 145.0, 0.05], [64.0, 145.0, 0.05],
		[59.0, 102.0, 0.05], [32.7, 93.7, 0.05], [31.2, 90.8, 0.05], [29.8, 140.1, 0.05],
		[16.5, 146.3, 0.05], [15.3, 146.9, 0.05], [-24.3, 128.6, 0.05], [-67.9, 117.9, 0.05],
		[-41.6, 88.4, 0.05], [-13.6, 120.3, 0.05], [26.0, 117.8, 0.05], [22.6, 112.3, 0.05],
		[-8.2, 107.9, 0.05], [-18.1, 97.0, 0.05], [-21.4, 92.9, 0.05], [-2.1, 74.0, 0.05],
		[19.8, 93.5, 0.05], [21.4, 95.4, 0.05], [19.2, 97.5, 0.05], [-10.7, 143.3, 0.05],
		[38.2, 120.7, 0.05], [34.1, 101.5, 0.05], [32.4, 96.5, 0.05], [72.9, 121.8, 0.05],
	]
	var points: Array[Vector3] = []
	for item in raw:
		var row: Array = item
		points.append(Vector3(float(row[0]), float(row[2]), -float(row[1])))
	return points
