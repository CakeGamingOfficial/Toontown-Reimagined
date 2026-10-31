class_name Flunky
extends Cog

## The tutorial Flunky. He paces the shop window during the cutscene, then
## walks the street rectangle from DistributedTutorialSuit once the toon leaves.

const _MODEL := "res://assets/cogs/flunky.glb"
const _WALK := "res://assets/cogs/flunky.walk"
const _NEUTRAL := "res://assets/cogs/flunky.neutral"
const _LOSE_MODEL := "res://assets/cogs/flunky_lose.glb"
const _LOSE := "res://assets/cogs/flunky.lose"
# MovieUtil.SUIT_LOSE_DURATION. The lose clip is played across these seconds.
const LOSE_SECONDS := 6.0

var _clips: Array[Dictionary] = []
var _joints: Array[Dictionary] = []
var _actions: Dictionary = {}
var _lose_root: Node3D
var _lose_bank: Dictionary = {}
var _lose_shown := -1
var _frame_count := 1
var _walk_time := 0.0
var _moving := false
var _goal := Vector3.ZERO
var _heading := 0.0
var _wait := 0.0
var _acting := false
var _idle_bank: Dictionary = {}
var _idle_time := 0.0
var _idle_frames := 1
var _idling := false
var _leg := 0
var _pacing := false
var _street := false
var _outside := false
var _path: PackedVector3Array = PackedVector3Array()
var _path_index := 0
var _ground := Grounded.new()

# DistributedSuitBase path speed for the tutorial cog.
const _STREET_SPEED := 4.5


func _ready() -> void:
	var packed := load(_MODEL) as PackedScene
	if packed == null:
		return
	var model := packed.instantiate()
	add_child(model)
	_load_walk()
	_load_actions()
	_idle_bank = _read_bank(_NEUTRAL)
	_idle_frames = maxi(int(_idle_bank.get("frames", 1)), 1)
	_show_both_sides()
	_hide_gray_cuffs()


func pace_outside() -> void:
	# Panda (-20, 8, 0) to (-20, 20, 0), then back to (-20, 10, 0).
	# Only the cutscene, while the toon is still inside the shop.
	_street = false
	_outside = false
	position = Vector3(-20.0, 0.0, -8.0)
	_heading = 0.0
	_leg = 0
	_wait = 0.0
	_pacing = true
	_face()
	_begin_leg()


func walk_street() -> void:
	# DistributedTutorialSuit.enterWalk. The playground path is
	# (55, 15), (55, 25), (25, 25), (25, 15) at z -0.5, and the street
	# backdrop sits at (-17, 42, -0.5) heading 180. Feet stay on the
	# sidewalk the toon walks on after leaving the shop.
	_street = true
	_outside = true
	_pacing = true
	_wait = 0.0
	_path = PackedVector3Array([
		Vector3(-72.0, 0.0, -27.0),
		Vector3(-72.0, 0.0, -17.0),
		Vector3(-42.0, 0.0, -17.0),
		Vector3(-42.0, 0.0, -27.0),
	])
	_path_index = 0
	position = _path[0]
	_begin_street_leg()


func on_street() -> bool:
	return _outside and visible


func stop_for_battle() -> void:
	# Suit.loop('neutral') while the cog waits out a taunt, the gag menu,
	# or the gap between attacks.
	_pacing = false
	_wait = 0.0
	_moving = false
	_idling = true
	_idle_time = 0.0


## The face-off walks him onto the street's battle cell. The path stays stopped.
func play_walk(delta: float) -> void:
	_set_moving(true)
	_pose(delta)


func face_heading(heading: float) -> void:
	_heading = heading
	_face()


func _physics_process(delta: float) -> void:
	if _pacing:
		_walk_pace(delta)
	elif _idling and not _acting:
		_pose_idle(delta)
	_ground.step(self, delta)


func _walk_pace(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		_set_moving(false)
		return
	var flat := Vector2(position.x, position.z)
	var target := Vector2(_goal.x, _goal.z)
	var remaining := flat.distance_to(target)
	var speed := remaining / maxf(_leg_time_left(), 0.05)
	if remaining < 0.05:
		position.x = _goal.x
		position.z = _goal.z
		_finish_leg()
		return
	var step := minf(speed * delta, remaining)
	var toward := (target - flat).normalized()
	position.x += toward.x * step
	position.z += toward.y * step
	_leg_left = maxf(_leg_left - delta, 0.0)
	_set_moving(true)
	_pose(delta)


var _leg_left := 0.0


func _begin_leg() -> void:
	# 0: walk to the far side of the window. 1: pause and turn.
	# 2: walk back. 3: pause and face the window again.
	match _leg % 4:
		0:
			_goal = Vector3(-20.0, 0.0, -20.0)
			_heading = 0.0
			_leg_left = 2.0
		1:
			_heading = 180.0
			_wait = 1.0
			_leg_left = 0.0
		2:
			_goal = Vector3(-20.0, 0.0, -10.0)
			_heading = 180.0
			_leg_left = 2.0
		3:
			_heading = 0.0
			_wait = 1.0
			_leg_left = 0.0
	_face()


func _finish_leg() -> void:
	if _street:
		_path_index = (_path_index + 1) % _path.size()
		_begin_street_leg()
		return
	_leg += 1
	_begin_leg()


func _begin_street_leg() -> void:
	var start := _path[_path_index]
	var goal := _path[(_path_index + 1) % _path.size()]
	_goal = goal
	var flat := Vector2(goal.x - start.x, goal.z - start.z)
	# Heading 0 faces -Z. Positive heading turns left.
	_heading = rad_to_deg(atan2(-flat.x, -flat.y))
	_leg_left = flat.length() / _STREET_SPEED
	_face()


func _leg_time_left() -> float:
	return maxf(_leg_left, 0.05)


func _face() -> void:
	rotation.y = deg_to_rad(_heading)


func _set_moving(moving: bool) -> void:
	if _moving == moving:
		return
	_moving = moving
	if not moving:
		_restore()


func _pose(delta: float) -> void:
	if _frame_count <= 1:
		return
	_walk_time = fposmod(_walk_time + delta * 24.0, float(_frame_count))
	if _walk_time >= float(_frame_count):
		_walk_time = 0.0
	var frame := mini(int(_walk_time), _frame_count - 1)
	var following := (frame + 1) % _frame_count
	var blend := _walk_time - float(frame)
	_apply_pose(_clips, _joints, frame, following, blend)


func _pose_idle(delta: float) -> void:
	var clips: Array = _idle_bank.get("clips", [])
	if _idle_frames <= 1 or clips.is_empty():
		return
	_idle_time = fposmod(_idle_time + delta * 24.0, float(_idle_frames))
	var frame := mini(int(_idle_time), _idle_frames - 1)
	var following := (frame + 1) % _idle_frames
	var blend := _idle_time - float(frame)
	_apply_pose(clips, _idle_bank.get("joints", []), frame, following, blend)


func _apply_pose(clips: Array, joints: Array, frame: int, following: int, blend: float, max_edge: float = 0.0) -> void:
	for clip in clips:
		var record: Dictionary = clip
		var instance := record["instance"] as MeshInstance3D
		if not is_instance_valid(instance):
			continue
		var original := record["original"] as Mesh
		var surfaces: Array = record["surfaces"]
		var posed := ArrayMesh.new()
		for surface_index in surfaces.size():
			var surface: Dictionary = surfaces[surface_index]
			var frames: Array = surface["frames"]
			if frames.is_empty():
				continue
			var positions: PackedVector3Array = frames[frame % frames.size()]
			if blend > 0.001:
				var nxt: PackedVector3Array = frames[following % frames.size()]
				var mixed := PackedVector3Array()
				mixed.resize(positions.size())
				for index in positions.size():
					mixed[index] = positions[index].lerp(nxt[index], blend)
				positions = mixed
			var uvs: PackedVector2Array = surface["uv"]
			if max_edge > 0.0:
				var solid := PackedVector3Array()
				var solid_uv := PackedVector2Array()
				var limit := max_edge * max_edge
				var cursor := 0
				while cursor + 2 < positions.size():
					var corner_a := positions[cursor]
					var corner_b := positions[cursor + 1]
					var corner_c := positions[cursor + 2]
					# The last frames pull a few vertices across the street and
					# leave triangles the size of the block. Those sheets are
					# what flooded the renderer. The rigid chunks stay.
					if corner_a.distance_squared_to(corner_b) <= limit and corner_b.distance_squared_to(corner_c) <= limit and corner_c.distance_squared_to(corner_a) <= limit:
						solid.append(corner_a)
						solid.append(corner_b)
						solid.append(corner_c)
						if uvs.size() == positions.size():
							solid_uv.append(uvs[cursor])
							solid_uv.append(uvs[cursor + 1])
							solid_uv.append(uvs[cursor + 2])
					cursor += 3
				positions = solid
				uvs = solid_uv
			if positions.is_empty():
				continue
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = positions
			if uvs.size() == positions.size():
				arrays[Mesh.ARRAY_TEX_UV] = uvs
			arrays[Mesh.ARRAY_NORMAL] = _face_normals(positions)
			posed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			if surface_index < original.get_surface_count():
				posed.surface_set_material(posed.get_surface_count() - 1, original.surface_get_material(surface_index))
		if posed.get_surface_count() == 0:
			instance.visible = false
			continue
		instance.visible = true
		instance.mesh = posed
	for joint in joints:
		var record: Dictionary = joint
		var node := record["node"] as Node3D
		if not is_instance_valid(node):
			continue
		var frames: Array = record["frames"]
		var posed_frame: Transform3D = frames[frame % frames.size()]
		if blend > 0.001:
			var nxt: Transform3D = frames[following % frames.size()]
			posed_frame.origin = posed_frame.origin.lerp(nxt.origin, blend)
			posed_frame.basis = posed_frame.basis.slerp(nxt.basis, blend)
		var bind: Transform3D = record["bind"]
		var rest: Transform3D = record["rest"]
		node.transform = rest * bind.affine_inverse() * posed_frame


func _restore() -> void:
	for clip in _clips:
		var instance := clip["instance"] as MeshInstance3D
		if is_instance_valid(instance):
			instance.mesh = clip["original"]
	for joint in _joints:
		var node := joint["node"] as Node3D
		if is_instance_valid(node):
			node.transform = joint["rest"]


func _show_both_sides() -> void:
	# The walk replaces each part with a posed mesh. Suit pieces overlap and
	# some triangles face inward, so culling makes the cuffs vanish and the
	# gloves look like they left the sleeves.
	var seen: Array[Material] = []
	for child in find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		for index in mesh_node.mesh.get_surface_count():
			var material := mesh_node.mesh.surface_get_material(index)
			if material == null or material in seen:
				continue
			seen.append(material)
			if material is BaseMaterial3D:
				(material as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED


func _hide_gray_cuffs() -> void:
	# suitC keeps a flat blue-gray lining at each wrist. It sits outside the
	# pinstripe sleeve, so it reads as a gray cuff. Drop those surfaces from
	# the rest mesh, the walk, and every attack clip, and leave the black
	# ring up at the neck.
	var suit := _find(self, "node") as MeshInstance3D
	if suit == null or suit.mesh == null:
		return
	var drop: Array[int] = []
	for index in suit.mesh.get_surface_count():
		var material := suit.mesh.surface_get_material(index) as BaseMaterial3D
		if material == null or material.albedo_texture != null:
			continue
		var color := material.albedo_color
		var brightest := maxf(color.r, maxf(color.g, color.b))
		var dullest := minf(color.r, minf(color.g, color.b))
		# The neck ring is black. The wrist lining is a flat blue-gray, which
		# Godot may store as the glTF linear 0.06 or the sRGB value near 0.28.
		if brightest > 0.02 and brightest < 0.55 and brightest - dullest < 0.2:
			drop.append(index)
	if drop.is_empty():
		return
	var kept := ArrayMesh.new()
	for index in suit.mesh.get_surface_count():
		if drop.has(index):
			continue
		var arrays := suit.mesh.surface_get_arrays(index)
		kept.add_surface_from_arrays(suit.mesh.surface_get_primitive_type(index), arrays)
		kept.surface_set_material(kept.get_surface_count() - 1, suit.mesh.surface_get_material(index))
	suit.mesh = kept
	for clip in _clips:
		_drop_cuff_surfaces(clip, suit, drop, kept)
	for suffix in _actions.keys():
		var bank := _actions[suffix] as Dictionary
		var action_clips: Array = bank.get("clips", [])
		for action_clip in action_clips:
			_drop_cuff_surfaces(action_clip as Dictionary, suit, drop, kept)
	var idle_clips: Array = _idle_bank.get("clips", [])
	for idle_clip in idle_clips:
		_drop_cuff_surfaces(idle_clip as Dictionary, suit, drop, kept)


func _drop_cuff_surfaces(clip: Dictionary, suit: MeshInstance3D, drop: Array[int], kept: ArrayMesh) -> void:
	if clip.get("instance") != suit:
		return
	var surfaces: Array = clip["surfaces"]
	var filtered: Array = []
	for index in surfaces.size():
		if drop.has(index):
			continue
		filtered.append(surfaces[index])
	clip["surfaces"] = filtered
	clip["original"] = kept


func _face_normals(positions: PackedVector3Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(positions.size())
	var index := 0
	while index + 2 < positions.size():
		var edge_a := positions[index + 1] - positions[index]
		var edge_b := positions[index + 2] - positions[index]
		var normal := edge_a.cross(edge_b)
		if normal.length_squared() < 0.000001:
			normal = Vector3.UP
		else:
			normal = normal.normalized()
		normals[index] = normal
		normals[index + 1] = normal
		normals[index + 2] = normal
		index += 3
	return normals


func _load_walk() -> void:
	var bank := _read_bank(_WALK)
	_frame_count = maxi(int(bank.get("frames", 1)), 1)
	var clips: Array = bank.get("clips", [])
	for clip in clips:
		_clips.append(clip as Dictionary)
	var joints: Array = bank.get("joints", [])
	for joint in joints:
		_joints.append(joint as Dictionary)


func _load_actions() -> void:
	for suffix in ["phone", "throw-paper", "shredder", "pie-small", "squirt-small", "sidestep-left", "sidestep-right", "drop-react"]:
		_actions[suffix] = _read_bank("res://assets/cogs/flunky." + suffix)


func action_length(suffix: String) -> float:
	var bank: Dictionary = _actions.get(suffix, {})
	var frames := int(bank.get("frames", 0))
	if frames <= 1:
		return 0.0
	return float(frames - 1) / 24.0


func pose_action(suffix: String, elapsed: float) -> void:
	var bank: Dictionary = _actions.get(suffix, {})
	var frames := int(bank.get("frames", 0))
	var clips: Array = bank.get("clips", [])
	_acting = true
	if frames <= 1 or clips.is_empty():
		return
	var time := clampf(elapsed * 24.0, 0.0, float(frames - 1))
	var frame := mini(int(time), frames - 1)
	var following := mini(frame + 1, frames - 1)
	var blend := 0.0 if following == frame else time - float(frame)
	_apply_pose(clips, bank["joints"], frame, following, blend)


func begin_lose() -> void:
	# Suit.getLoseActor hides the live suit and shows suitC-lose-mod.
	_idling = false
	if _lose_root == null:
		var packed := load(_LOSE_MODEL) as PackedScene
		if packed == null:
			return
		_lose_root = packed.instantiate()
		_lose_root.name = "LoseActor"
		add_child(_lose_root)
		_lose_bank = _read_bank(_LOSE, _lose_root)
	_lose_shown = -1
	for child in get_children():
		if child == _lose_root:
			continue
		child.visible = false
	_lose_root.visible = true
	pose_lose(0.0)


func pose_lose(elapsed: float) -> void:
	if _lose_root == null:
		return
	var frames := int(_lose_bank.get("frames", 0))
	var clips: Array = _lose_bank.get("clips", [])
	if frames <= 1 or clips.is_empty():
		return
	# Snap to a frame. Blending the burst rubber-bands the pieces into sheets
	# that cover the whole view.
	var frame := mini(int(clampf(elapsed / LOSE_SECONDS, 0.0, 1.0) * float(frames - 1)), frames - 1)
	if frame == _lose_shown:
		return
	_lose_shown = frame
	_apply_pose(clips, _lose_bank["joints"], frame, frame, 0.0, 3.0)


func finish_lose() -> void:
	visible = false


func end_action(suffix: String) -> void:
	var bank: Dictionary = _actions.get(suffix, {})
	var clips: Array = bank.get("clips", [])
	for clip in clips:
		var record: Dictionary = clip
		var instance := record["instance"] as MeshInstance3D
		if is_instance_valid(instance):
			instance.mesh = record["original"]
	var joints: Array = bank.get("joints", [])
	for joint in joints:
		var record: Dictionary = joint
		var node := record["node"] as Node3D
		if is_instance_valid(node):
			node.transform = record["rest"]
	_acting = false
	if _idling:
		_pose_idle(0.0)


func _read_bank(path: String, root: Node = null) -> Dictionary:
	var clips: Array = []
	var joints: Array = []
	var frame_count := 0
	if not FileAccess.file_exists(path):
		return {"clips": clips, "joints": joints, "frames": 0}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"clips": clips, "joints": joints, "frames": 0}
	var magic := file.get_buffer(8)
	if magic.slice(0, 6).get_string_from_ascii() != "TWALK3":
		file.close()
		return {"clips": clips, "joints": joints, "frames": 0}
	var search: Node = self if root == null else root
	frame_count = file.get_32()
	var node_count := file.get_32()
	for _node_index in node_count:
		var name_len := file.get_16()
		var node_name := file.get_buffer(name_len).get_string_from_utf8()
		var surface_count := file.get_32()
		var surfaces: Array = []
		for _surface_index in surface_count:
			var vertex_count := file.get_32()
			var has_uv := file.get_8()
			var uvs := PackedVector2Array()
			if has_uv != 0:
				uvs.resize(vertex_count)
				for index in vertex_count:
					uvs[index] = Vector2(file.get_float(), file.get_float())
			var frames: Array = []
			for _frame_index in frame_count:
				var positions := PackedVector3Array()
				positions.resize(vertex_count)
				for index in vertex_count:
					positions[index] = Vector3(file.get_float(), file.get_float(), file.get_float())
				frames.append(positions)
			surfaces.append({"uv": uvs, "frames": frames})
		var instance := _find(search, node_name) as MeshInstance3D
		if instance != null and instance.mesh != null and not surfaces.is_empty():
			clips.append({
				"instance": instance,
				"original": instance.mesh,
				"surfaces": surfaces,
			})
	var joint_count := file.get_32()
	for _joint_index in joint_count:
		var name_len := file.get_16()
		var joint_name := file.get_buffer(name_len).get_string_from_utf8()
		var bind_cells := PackedFloat32Array()
		bind_cells.resize(16)
		for cell in 16:
			bind_cells[cell] = file.get_float()
		var frames: Array = []
		for _frame_index in frame_count:
			var cells := PackedFloat32Array()
			cells.resize(16)
			for cell in 16:
				cells[cell] = file.get_float()
			frames.append(_transform_from_panda(cells))
		var joint := _find(search, joint_name) as Node3D
		if joint != null and not frames.is_empty():
			joints.append({
				"node": joint,
				"rest": joint.transform,
				"bind": _transform_from_panda(bind_cells),
				"frames": frames,
			})
	file.close()
	return {"clips": clips, "joints": joints, "frames": frame_count}


func _transform_from_panda(cells: PackedFloat32Array) -> Transform3D:
	var x := Vector3(cells[0], cells[1], cells[2])
	var y := Vector3(cells[4], cells[5], cells[6])
	var z := Vector3(cells[8], cells[9], cells[10])
	var origin := Vector3(cells[12], cells[13], cells[14])
	# The head joint scale collapses when it pops off. Orthonormalizing a
	# zero basis invents a full-size spinning head.
	if x.length_squared() < 0.0025 or y.length_squared() < 0.0025 or z.length_squared() < 0.0025:
		return Transform3D(Basis.from_scale(Vector3.ZERO), origin)
	var basis := Basis(x, y, z)
	basis = basis.orthonormalized()
	return Transform3D(basis, origin)


func _find(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find(child, wanted)
		if found:
			return found
	return null
