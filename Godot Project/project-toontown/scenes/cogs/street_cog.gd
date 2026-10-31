extends Node3D
class_name StreetCog

## A street suit. It flies in, walks the right-hand lane of the street, then flies out.
## The lane is one loop: right sidewalk to the end, cross, then the other sidewalk back.
## Battles are not started from here.

const WALK_SPEED := 4.8
const MIN_PATH_POINTS := 40
const MAX_PATH_POINTS := 300
const FROM_SKY := 6.5
const SKY_HEIGHT := FROM_SKY * WALK_SPEED
const GROUND_FRAME := 28
const DEFAULT_FPS := 24.0
const _DEPT_NAMES := {
	"c": "Bossbot",
	"l": "Lawbot",
	"m": "Cashbot",
	"s": "Sellbot",
}
## Parsed clip files are shared. Each cog only keeps its own mesh instance.
static var _clip_files: Dictionary = {}

signal departed

var cog_code := ""
var cog_name := ""
var cog_level := 1
var dept := "c"
var body := "c"
var height := 4.0

var _points: Array[Vector3] = []
var _route: PackedInt32Array = PackedInt32Array()
var _slot := 0
var _goal := Vector3.ZERO
var _edges_left := 40
var _detail := 2
var _phase := 0
var _fly := 0.0
var _till_land := FROM_SKY
var _impact := 0.0
var _wait := 0.0
var _landing_frames := 1
var _landing_fps := DEFAULT_FPS
var _walk_fps := DEFAULT_FPS
var _neutral_fps := DEFAULT_FPS
var _walk_time := 0.0
var _idle_time := 0.0
var _prop_time := 0.0
var _prop_frames := 0
var _prop_fps := DEFAULT_FPS
var _ground := Vector3.ZERO
var _materials: Array[BaseMaterial3D] = []
var _material_modes: Array[int] = []
var _walk: Dictionary = {}
var _neutral: Dictionary = {}
var _landing: Dictionary = {}
var _attacks: Dictionary = {}
var _propeller: Node3D
var _prop_bank: Dictionary = {}
var _sound: AudioStreamPlayer3D

func setup(cog: Dictionary, points: Array[Vector3], route: PackedInt32Array, start: int, timing: Dictionary, propeller: Dictionary) -> void:
	cog_code = str(cog["code"])
	cog_name = str(cog["name"])
	dept = str(cog["dept"])
	body = str(cog["body"])
	height = float(cog["height"])
	cog_level = int(cog.get("level", 1))
	name = cog_name
	_points = points
	_route = route
	_slot = 0
	if route.size() > 0:
		_slot = posmod(start, route.size())
	_edges_left = _street_stay(route.size())
	var body_timing: Dictionary = timing.get(body, {})
	var walk_info: Dictionary = body_timing.get("walk", {})
	var neutral_info: Dictionary = body_timing.get("neutral", {})
	var landing_info: Dictionary = body_timing.get("landing", {})
	if float(walk_info.get("fps", 0.0)) > 1.0:
		_walk_fps = float(walk_info["fps"])
	if float(neutral_info.get("fps", 0.0)) > 1.0:
		_neutral_fps = float(neutral_info["fps"])
	if int(landing_info.get("frames", 0)) > 1:
		_landing_frames = int(landing_info["frames"])
		_landing_fps = float(landing_info.get("fps", DEFAULT_FPS))
	_prop_frames = int(propeller.get("frames", 0))
	_prop_fps = float(propeller.get("fps", DEFAULT_FPS))
	if _prop_fps < 1.0:
		_prop_fps = DEFAULT_FPS
	var packed := load("res://assets/cogs/suits/%s.glb" % cog_code) as PackedScene
	if packed == null:
		departed.emit()
		queue_free()
		return
	var actor := packed.instantiate()
	actor.name = "Suit"
	add_child(actor)
	_own_materials(actor)
	_hide_gray_cuffs(actor)
	_add_nametag()
	_walk = _read_bank("res://assets/cogs/anims/%s/walk.walk" % body)
	_neutral = _read_bank("res://assets/cogs/anims/%s/neutral.walk" % body)
	_landing = _read_bank("res://assets/cogs/anims/%s/landing.walk" % body)
	if int(_landing.get("frames", 0)) > 1:
		_landing_frames = int(_landing["frames"])
	_prepare_landing()
	if _route.size() < 2:
		departed.emit()
		queue_free()
		return
	_ground = _points[_route[_slot]]
	_goal = _ground
	global_position = _ground + Vector3(0.0, SKY_HEIGHT, 0.0)
	_set_alpha(0.0)
	_step_lane()
	_attach_propeller()
	_play_propeller(true)
	_pose_clip(_landing, 0, 0, 0.0)


func play_attack(key: String, elapsed: float) -> void:
	# Attack clips are loaded on demand. Street roaming does not call this.
	if not _attacks.has(key):
		_attacks[key] = _read_bank("res://assets/cogs/anims/%s/%s.walk" % [body, key])
	var bank: Dictionary = _attacks[key]
	var frames := int(bank.get("frames", 0))
	if frames <= 1:
		return
	var fps := _walk_fps
	var time := clampf(elapsed * fps, 0.0, float(frames - 1))
	var frame := mini(int(time), frames - 1)
	var following := mini(frame + 1, frames - 1)
	var blend := 0.0 if following == frame else time - float(frame)
	_pose_clip(bank, frame, following, blend)


func _prepare_landing() -> void:
	var frames := float(maxi(_landing_frames, 1))
	var dur := frames / _landing_fps
	var air := float(GROUND_FRAME) / _landing_fps
	if air > dur:
		air = dur * 0.5
	_impact = maxf(dur - air, 0.0)
	_till_land = maxf(FROM_SKY - _impact, 0.2)
	_wait = maxf(_till_land - air, 0.0)


## DistributedSuitPlannerAI keeps a suit out for a path of 40 to 300 points.
## A short forward gap is rejected, and the suit takes the long way instead.
func _street_stay(count: int) -> int:
	if count < 2:
		return 1
	var ahead := randi_range(1, count - 1)
	var points := ahead + 1
	if points < MIN_PATH_POINTS:
		points = (count - ahead) + 1
	if points > MAX_PATH_POINTS:
		points = MAX_PATH_POINTS
	if points < 2:
		points = 2
	return points - 1


func _process(delta: float) -> void:
	if _points.is_empty():
		return
	_detail = _camera_detail()
	if _phase == 0:
		_fly_in(delta)
	elif _phase == 1:
		_roam(delta)
	else:
		_fly_out(delta)


func _fly_in(delta: float) -> void:
	_fly += delta
	var fade := clampf(_fly, 0.0, 1.0)
	_set_alpha(fade)
	if _fly < _till_land:
		var along := _fly / _till_land
		global_position = _ground + Vector3(0.0, SKY_HEIGHT * (1.0 - along), 0.0)
	else:
		global_position = _ground
	if _fly < _wait:
		_pose_clip(_landing, 0, 0, 0.0)
	else:
		_pose_elapsed(_landing, _fly - _wait, _landing_fps, false)
	_spin_propeller(delta, true)
	if _fly >= FROM_SKY:
		_detach_propeller()
		_phase = 1
		_pose_elapsed(_walk, 0.0, _walk_fps, true)


func _fly_out(delta: float) -> void:
	_fly += delta
	_set_alpha(1.0 - clampf(_fly, 0.0, 1.0))
	var dur := float(maxi(_landing_frames, 1)) / _landing_fps
	_pose_elapsed(_landing, dur - _fly, _landing_fps, false)
	if _fly < _impact:
		global_position = _ground
	else:
		var along := clampf((_fly - _impact) / _till_land, 0.0, 1.0)
		global_position = _ground + Vector3(0.0, SKY_HEIGHT * along, 0.0)
	_spin_propeller(delta, false)
	if _fly >= FROM_SKY:
		_detach_propeller()
		departed.emit()
		queue_free()


func _roam(delta: float) -> void:
	if _route.size() < 2:
		_begin_fly_out()
		return
	var origin := _points[_route[_slot]]
	var flat := Vector2(global_position.x, global_position.z)
	var target := Vector2(_goal.x, _goal.z)
	var remaining := flat.distance_to(target)
	if remaining < 0.08:
		global_position = _goal
		_slot = (_slot + 1) % _route.size()
		_edges_left -= 1
		if _edges_left <= 0:
			_begin_fly_out()
			return
		_step_lane()
		return
	var step := minf(WALK_SPEED * delta, remaining)
	var toward := (target - flat) / remaining
	global_position.x += toward.x * step
	global_position.z += toward.y * step
	var span := Vector2(origin.x, origin.z).distance_to(target)
	if span > 0.001:
		global_position.y = lerpf(origin.y, _goal.y, 1.0 - remaining / span)
	_face(toward)
	_walk_time = fposmod(_walk_time + delta * _walk_fps, float(maxi(int(_walk.get("frames", 1)), 1)))
	var frames := int(_walk.get("frames", 1))
	if frames > 1:
		var frame := int(_walk_time)
		if frame >= frames:
			frame = 0
		var blend := _walk_time - float(frame)
		_pose_clip(_walk, frame, (frame + 1) % frames, blend)
	else:
		_idle(delta)


func _begin_fly_out() -> void:
	_phase = 2
	_fly = 0.0
	_ground = global_position
	_attach_propeller()
	_play_propeller(false)


## The route is already the right-hand loop. The next point is always forward.
func _step_lane() -> void:
	if _route.size() < 2:
		_begin_fly_out()
		return
	var nxt := (_slot + 1) % _route.size()
	_goal = _points[_route[nxt]]
	var toward := Vector2(_goal.x - global_position.x, _goal.z - global_position.z)
	if toward.length_squared() > 0.0001:
		_face(toward.normalized())


func _face(toward: Vector2) -> void:
	# Heading 0 faces -Z, matching the tutorial suit.
	rotation.y = atan2(-toward.x, -toward.y)


func _idle(delta: float) -> void:
	var frames := int(_neutral.get("frames", 1))
	if frames <= 1:
		return
	_idle_time = fposmod(_idle_time + delta * _neutral_fps, float(frames))
	var frame := int(_idle_time)
	if frame >= frames:
		frame = 0
	var blend := _idle_time - float(frame)
	_pose_clip(_neutral, frame, (frame + 1) % frames, blend)


func _pose_elapsed(bank: Dictionary, elapsed: float, fps: float, looping: bool) -> void:
	var frames := int(bank.get("frames", 0))
	if frames <= 1:
		_idle(0.0)
		return
	var span := float(frames) / fps
	var time := elapsed
	if looping:
		time = fposmod(elapsed, span)
	else:
		time = clampf(elapsed, 0.0, span)
	var cursor := time * fps
	var frame := mini(int(cursor), frames - 1)
	var following := frame
	if looping:
		following = (frame + 1) % frames
	else:
		following = mini(frame + 1, frames - 1)
	var blend := 0.0 if following == frame else cursor - float(frame)
	_pose_clip(bank, frame, following, blend)


func _add_nametag() -> void:
	var board := get_parent().get_node_or_null("Nametags")
	if board == null or not board.has_method("add"):
		return
	var dept_name := str(_DEPT_NAMES.get(dept, "Bossbot"))
	# SuitBaseNameWithLevel: name, department, level, on the translucent suit card.
	var tag: Variant = board.call("add", self, "%s\n%s\nLevel %d" % [cog_name, dept_name, cog_level], "cog")
	var panel := tag as Control
	if panel != null:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _attach_propeller() -> void:
	if _propeller != null:
		_propeller.visible = true
		return
	var packed := load("res://assets/cogs/props/propeller.glb") as PackedScene
	if packed == null:
		return
	var head := _find(self, "joint_head") as Node3D
	if head == null:
		return
	_propeller = packed.instantiate() as Node3D
	_propeller.name = "Propeller"
	head.add_child(_propeller)
	_own_materials(_propeller)
	_prop_bank = _read_bank("res://assets/cogs/props/propeller.walk", _propeller)


func _detach_propeller() -> void:
	if _sound != null:
		_sound.stop()
	if _propeller != null:
		_propeller.visible = false


func _play_propeller(inbound: bool) -> void:
	var file := "ENC_propeller_in.ogg" if inbound else "ENC_propeller_out.ogg"
	var path := "res://assets/cogs/audio/" + file
	if not FileAccess.file_exists(path):
		return
	if _sound == null:
		_sound = AudioStreamPlayer3D.new()
		_sound.name = "PropellerSound"
		_sound.unit_size = 25.0
		add_child(_sound)
	_sound.stream = load(path)
	_sound.play()


func _spin_propeller(delta: float, inbound: bool) -> void:
	if _propeller == null:
		return
	var frames := int(_prop_bank.get("frames", 0))
	if frames <= 1:
		_propeller.rotate_object_local(Vector3(0, 0, 1), delta * 28.0)
		return
	_prop_time += delta
	var spin_end := 8
	if inbound:
		var loop_span := float(mini(spin_end, frames - 1) + 1)
		var spin := fposmod(_prop_time * _prop_fps, loop_span)
		if _fly > _wait:
			spin = clampf(_wait * _prop_fps + (_fly - _wait) * _prop_fps, 0.0, float(frames - 1))
		var frame := mini(int(spin), frames - 1)
		var following := (frame + 1) % frames
		if _fly <= _wait:
			following = (frame + 1) % int(loop_span)
		var blend := spin - float(frame)
		_pose_clip(_prop_bank, frame, following, blend)
	else:
		var cursor := float(frames - 1) - _prop_time * _prop_fps
		cursor = clampf(cursor, 0.0, float(frames - 1))
		var frame := mini(int(cursor), frames - 1)
		var following := mini(frame + 1, frames - 1)
		var blend := cursor - float(frame)
		_pose_clip(_prop_bank, frame, following, blend)


func _set_alpha(alpha: float) -> void:
	var shown := clampf(alpha, 0.0, 1.0)
	for index in _materials.size():
		var material := _materials[index]
		var color := material.albedo_color
		color.a = shown
		material.albedo_color = color
		# Glasses and the medallion are masked. Forcing them opaque paints the
		# texture's white margin around the lenses and the frame.
		var kept := _material_modes[index]
		if shown < 0.99 and kept == BaseMaterial3D.TRANSPARENCY_DISABLED:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		else:
			material.transparency = kept as BaseMaterial3D.Transparency


func _own_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null:
			for index in mesh_node.mesh.get_surface_count():
				var source := mesh_node.mesh.surface_get_material(index)
				if source is BaseMaterial3D:
					var copy := (source as BaseMaterial3D).duplicate() as BaseMaterial3D
					copy.cull_mode = BaseMaterial3D.CULL_DISABLED
					mesh_node.mesh.surface_set_material(index, copy)
					_materials.append(copy)
					_material_modes.append(int((source as BaseMaterial3D).transparency))
	for child in node.get_children():
		_own_materials(child)


func _hide_gray_cuffs(actor: Node) -> void:
	if body != "c":
		return
	var suit := _find(actor, "node") as MeshInstance3D
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


func _clip_drawn(bank: Dictionary) -> bool:
	var clips: Array = bank.get("clips", [])
	if clips.is_empty():
		return false
	for item in clips:
		var record: Dictionary = item
		var mesh := record.get("mesh") as ArrayMesh
		if mesh == null or mesh.get_surface_count() == 0:
			return false
	return true


func _camera_detail() -> int:
	if _block_hidden():
		return 0
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 2
	var chest := global_position + Vector3(0.0, height * 0.45, 0.0)
	if cam.is_position_behind(chest):
		return 0
	var dist2 := chest.distance_squared_to(cam.global_position)
	# Off-screen suits hold their last pose. Anything in view keeps walking,
	# including a suit at the far end of the street.
	if dist2 > 16.0 * 16.0 and not cam.is_position_in_frustum(chest):
		return 0
	# Only a suit near the camera blends every vertex. Everyone else on screen
	# steps the walk with an in-place buffer update.
	if dist2 <= 12.0 * 12.0:
		return 2
	# Far suits share the upload. A suit at the end of the street steps every
	# few frames; one near enough to read steps a little more often.
	var tick := Engine.get_process_frames()
	var slot := int(get_instance_id())
	if dist2 > 32.0 * 32.0 and tick % 4 != slot % 4:
		return 0
	if tick % 3 != slot % 3:
		return 0
	return 1


## A suit on a stashed block stays on its path, but it does not draw or animate.
func _block_hidden() -> bool:
	var suits := get_parent()
	if suits == null:
		return false
	var street := suits.get_parent()
	if street == null or not street.has_method("zone_visible_at"):
		visible = true
		return false
	var tick := Engine.get_process_frames()
	if tick % 8 != int(get_instance_id()) % 8 and has_meta("zone_hide"):
		var cached := bool(get_meta("zone_hide"))
		visible = not cached
		return cached
	var hidden := not bool(street.call("zone_visible_at", global_position))
	set_meta("zone_hide", hidden)
	visible = not hidden
	return hidden


func _pose_clip(bank: Dictionary, frame: int, following: int, blend: float) -> void:
	if _detail == 0:
		return
	var fraction := 0.0
	if _detail == 1:
		# A far suit steps through the walk instead of blending it. Skip the
		# rebuild only when this exact frame is already on the mesh.
		if int(bank.get("shown", -2)) == frame and _clip_drawn(bank):
			return
		bank["shown"] = frame
	else:
		fraction = clampf(blend, 0.0, 1.0)
		bank["shown"] = -1
	var clips: Array = bank.get("clips", [])
	for item in clips:
		var record: Dictionary = item
		var instance := record["instance"] as MeshInstance3D
		if not is_instance_valid(instance):
			continue
		var surfaces: Array = record["surfaces"]
		var materials: Array = record["materials"]
		var mesh := record["mesh"] as ArrayMesh
		var mix_pos: Array = record["mix_pos"]
		var mix_nrm: Array = record["mix_nrm"]
		# Positions sit in a packed block at the front of the vertex buffer.
		# Nearby suits blend that block every frame. Normals are rebuilt
		# every few source frames, and only for suits close to the camera.
		var built := int(record.get("posed", -2))
		# Rebuilding the surface allocates a new buffer. Do that once, then
		# write positions into the buffer that already exists.
		var reuse := mesh.get_surface_count() > 0
		if _detail == 2 and frame % 8 == 0 and built != frame:
			reuse = false
		if not reuse:
			mesh.clear_surfaces()
			record["posed"] = frame
		var mesh_index := 0
		for surface_index in surfaces.size():
			var surface: Dictionary = surfaces[surface_index]
			var frames: Array = surface["frames"]
			if frames.is_empty():
				continue
			var cursor := frame % frames.size()
			var positions: PackedVector3Array = frames[cursor]
			var normal_frames: Array = surface["normals"]
			var normals: PackedVector3Array = normal_frames[cursor]
			if fraction > 0.001:
				var nxt: PackedVector3Array = frames[following % frames.size()]
				var nxt_normals: PackedVector3Array = normal_frames[following % frames.size()]
				positions = _blend_vectors(mix_pos, surface_index, positions, nxt, fraction)
				if not reuse:
					normals = _blend_vectors(mix_nrm, surface_index, normals, nxt_normals, fraction)
			if positions.is_empty():
				continue
			if reuse:
				if mesh_index < mesh.get_surface_count():
					mesh.surface_update_vertex_region(mesh_index, 0, positions.to_byte_array())
				mesh_index += 1
				continue
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = positions
			var uvs: PackedVector2Array = surface["uv"]
			if uvs.size() == positions.size():
				arrays[Mesh.ARRAY_TEX_UV] = uvs
			arrays[Mesh.ARRAY_NORMAL] = normals
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
			if surface_index < materials.size() and materials[surface_index] != null:
				mesh.surface_set_material(mesh.get_surface_count() - 1, materials[surface_index])
			mesh_index += 1
		if mesh.get_surface_count() == 0:
			continue
		instance.mesh = mesh
	var joints: Array = bank.get("joints", [])
	for item in joints:
		var record: Dictionary = item
		var joint := record["node"] as Node3D
		if not is_instance_valid(joint):
			continue
		var frames: Array = record["frames"]
		if frames.is_empty():
			continue
		var posed_frame: Transform3D = frames[frame % frames.size()]
		if fraction > 0.001:
			var nxt: Transform3D = frames[following % frames.size()]
			posed_frame.origin = posed_frame.origin.lerp(nxt.origin, fraction)
			posed_frame.basis = posed_frame.basis.slerp(nxt.basis, fraction)
		var bind: Transform3D = record["bind"]
		var rest: Transform3D = record["rest"]
		joint.transform = rest * bind.affine_inverse() * posed_frame


func _blend_vectors(cache: Array, surface_index: int, current: PackedVector3Array, nxt: PackedVector3Array, amount: float) -> PackedVector3Array:
	if nxt.size() != current.size():
		return current
	while cache.size() <= surface_index:
		cache.append(PackedVector3Array())
	var into := cache[surface_index] as PackedVector3Array
	if into.size() != current.size():
		into = PackedVector3Array()
		into.resize(current.size())
		cache[surface_index] = into
	for index in current.size():
		into[index] = current[index].lerp(nxt[index], amount)
	return into


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


func _read_bank(path: String, root: Node = null) -> Dictionary:
	if not _clip_files.has(path):
		_clip_files[path] = _parse_clip(path)
	var search: Node = self if root == null else root
	return _bind_clip(_clip_files[path], search)


func _parse_clip(path: String) -> Dictionary:
	var nodes: Array = []
	var joints: Array = []
	if not FileAccess.file_exists(path):
		return {"nodes": nodes, "joints": joints, "frames": 0}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"nodes": nodes, "joints": joints, "frames": 0}
	var magic := file.get_buffer(8)
	if magic.slice(0, 6).get_string_from_ascii() != "TWALK3":
		file.close()
		return {"nodes": nodes, "joints": joints, "frames": 0}
	var frame_count := file.get_32()
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
			var normals: Array = []
			for _frame_index in frame_count:
				var positions := PackedVector3Array()
				positions.resize(vertex_count)
				for index in vertex_count:
					positions[index] = Vector3(file.get_float(), file.get_float(), file.get_float())
				frames.append(positions)
				normals.append(_face_normals(positions))
			surfaces.append({"uv": uvs, "frames": frames, "normals": normals})
		if not surfaces.is_empty():
			nodes.append({"name": node_name, "surfaces": surfaces})
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
		joints.append({
			"name": joint_name,
			"bind": _transform_from_panda(bind_cells),
			"frames": frames,
		})
	file.close()
	return {"nodes": nodes, "joints": joints, "frames": frame_count}


func _bind_clip(parsed: Dictionary, root: Node) -> Dictionary:
	var clips: Array = []
	var joints: Array = []
	var nodes: Array = parsed.get("nodes", [])
	for item in nodes:
		var node: Dictionary = item
		var instance := _find(root, str(node["name"])) as MeshInstance3D
		if instance == null or instance.mesh == null:
			continue
		var surfaces: Array = node["surfaces"]
		if surfaces.is_empty():
			continue
		var materials: Array = []
		for surface_index in surfaces.size():
			var material: Material = null
			if surface_index < instance.mesh.get_surface_count():
				material = instance.mesh.surface_get_material(surface_index)
			materials.append(material)
		var mesh := ArrayMesh.new()
		clips.append({
			"instance": instance,
			"surfaces": surfaces,
			"materials": materials,
			"mesh": mesh,
			"mix_pos": [],
			"mix_nrm": [],
		})
		instance.mesh = mesh
	var shared_joints: Array = parsed.get("joints", [])
	for item in shared_joints:
		var node: Dictionary = item
		var joint := _find(root, str(node["name"])) as Node3D
		if joint == null:
			continue
		joints.append({
			"node": joint,
			"rest": joint.transform,
			"bind": node["bind"],
			"frames": node["frames"],
		})
	return {"clips": clips, "joints": joints, "frames": int(parsed.get("frames", 0)), "shown": -1}


func _transform_from_panda(cells: PackedFloat32Array) -> Transform3D:
	var x := Vector3(cells[0], cells[1], cells[2])
	var y := Vector3(cells[4], cells[5], cells[6])
	var z := Vector3(cells[8], cells[9], cells[10])
	var origin := Vector3(cells[12], cells[13], cells[14])
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
		if found != null:
			return found
	return null
