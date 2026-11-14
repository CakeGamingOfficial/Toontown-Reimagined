extends Node3D

## One Doodle from phase_4 TT_pets-mod. Parts are the original geoms, posed
## from the neutral, walk, and run clips. A remote doodle plays the pose its
## owner published. DNA shows the same pieces Pet.setDNA shows: one head,
## ears, nose, and tail, plus the body texture and color.

const _PARTS_PATH := "res://assets/pets/doodle_parts.json"
const _CLIPS_PATH := "res://assets/pets/doodle_clips.bin"
const _CATALOG_PATH := "res://assets/pets/catalog.json"
const _MAPS := "res://assets/pets/maps/"
const _GUI := preload("res://scenes/toons/toon_gui.gd")
const _LIFE := preload("res://scenes/pets/doodle_traits.gd")
const _KENNEL := preload("res://scenes/pets/doodle_kennel.gd")
const _BEANS := preload("res://scenes/toons/jellybeans.gd")
const _FPS := {"happy": 12.0, "neutral": 12.0, "walk": 24.0, "run": 24.0, "sadwalk": 24.0, "walkHappy": 24.0, "jump": 24.0, "speak": 24.0, "toBeg": 24.0, "fromBeg": 24.0, "fromPlayDead": 24.0, "swallow": 24.0}
const _PALETTE := "pets_palette_3cmla_1.png"
const _PUPIL := "pets_palette_2tmla_1.png"

static var _parts: Array = []
static var _clips: PackedByteArray = PackedByteArray()
static var _catalog: Dictionary = {}
static var _textures: Dictionary = {}

var gui := false
var remote := false
var _owner_body: Node3D
var _rows: Array = []
var _mood: Dictionary = {}
var _tricks: Array = []
var _drift_left := 0.0
var _save_left := 5.0
var _acts: Array = []
var _act_left := 0.0
var _act_heal := 0
var _called := 0.0
var _panel: CanvasLayer
var _clip := "neutral"
var _clock := 0.0
var posing := false
var _reverse := false
var _start_frame := 0
var _blink := 0.0
var _ground := 0.0
var _nodes: Dictionary = {}
var _meta: Dictionary = {}
var _dna: Array = []
var _eyes_open := ""
var _eyes_shut := ""
var _shown: Dictionary = {}


static func _load_shared() -> void:
	if not _parts.is_empty():
		return
	_parts = JSON.parse_string(FileAccess.get_file_as_string(_PARTS_PATH))["parts"]
	_clips = FileAccess.get_file_as_bytes(_CLIPS_PATH)
	_catalog = JSON.parse_string(FileAccess.get_file_as_string(_CATALOG_PATH))


static func catalog() -> Dictionary:
	_load_shared()
	return _catalog


func _ready() -> void:
	_load_shared()
	_ground = _lowest_foot()
	for part in _parts:
		var info: Dictionary = part
		var mesh_node := MeshInstance3D.new()
		mesh_node.name = String(info["name"])
		mesh_node.mesh = ArrayMesh.new()
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh_node.material_override = material
		add_child(mesh_node)
		var key := String(info["name"])
		_nodes[key] = mesh_node
		_meta[key] = info
		mesh_node.visible = false
	var tag := Label3D.new()
	tag.name = "Name"
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0.0, 2.15, 0.0)
	tag.pixel_size = 0.008
	tag.font = _GUI.font()
	tag.modulate = Color(0.45, 0.0, 0.61, 1.0)
	tag.outline_modulate = Color(1, 1, 1, 1)
	tag.outline_size = 8
	tag.visible = false
	add_child(tag)
	_pose()


func show_pet(dna: Array, pet_name: String) -> void:
	_dna = dna.duplicate()
	_apply_dna()
	var tag := get_node_or_null("Name") as Label3D
	if tag != null:
		tag.text = pet_name
		tag.visible = not gui and not pet_name.is_empty()
	_pose()


func clip_name() -> String:
	return _clip


func use_remote(clip: String) -> void:
	remote = true
	_owner_body = null
	_clip = clip if clip != "" else "neutral"


func follow(body: Node3D) -> void:
	_owner_body = body
	if body == null:
		return
	var back := body.global_transform.basis.z
	back.y = 0.0
	if back.length_squared() < 0.0001:
		back = Vector3(0.0, 0.0, 1.0)
	else:
		back = back.normalized()
	global_position = body.global_position + back * 2.2
	global_position.y = body.global_position.y
	_load_life()


func hold_trick(clip: String, elapsed: float, reverse := false, start_frame := 0) -> void:
	posing = true
	if _clip != clip or _reverse != reverse or _start_frame != start_frame:
		_shown.clear()
	_clip = clip
	_reverse = reverse
	_start_frame = start_frame
	_clock = elapsed
	_pose()


func release_trick() -> void:
	posing = false
	_reverse = false
	_start_frame = 0
	_clip = "neutral"
	_clock = 0.0
	_shown.clear()
	_pose()


func _process(delta: float) -> void:
	if posing:
		_blink += delta
		_pose()
		return
	if gui:
		_clip = "happy"
	elif remote:
		pass
	elif _act_left > 0.0:
		_act_left -= delta
		if _act_left <= 0.0:
			_advance_act()
	else:
		_live(delta)
		_follow(delta)
	_clock += delta
	_blink += delta
	_pose()


func _follow(delta: float) -> void:
	if _owner_body == null or not is_instance_valid(_owner_body):
		_clip = "neutral"
		return
	var back := _owner_body.global_transform.basis.z
	back.y = 0.0
	if back.length_squared() < 0.0001:
		back = Vector3(0.0, 0.0, 1.0)
	else:
		back = back.normalized()
	var goal := _owner_body.global_position + back * 2.2
	goal.y = _owner_body.global_position.y
	var offset := goal - global_position
	offset.y = 0.0
	var distance := offset.length()
	var pace := 3.6 if _LIFE.unhappy(_mood, _rows) else 12.0
	var dash := pace * 1.6
	if _called > 0.0:
		goal = _owner_body.global_position
		goal.y = _owner_body.global_position.y
		offset = goal - global_position
		offset.y = 0.0
		distance = offset.length()
		pace = 20.0
		dash = 20.0
		_called -= delta
	if distance > 8.0:
		_clip = "run"
		global_position += offset.normalized() * minf(dash * delta, distance)
		look_at(global_position + offset, Vector3.UP)
	elif distance > 0.55:
		_clip = "walkHappy" if _LIFE.dominant(_mood, _rows) == "excitement" else "walk"
		if _LIFE.unhappy(_mood, _rows):
			_clip = "sadwalk"
		global_position += offset.normalized() * minf(pace * delta, distance)
		look_at(global_position + offset, Vector3.UP)
	else:
		_clip = "happy" if _LIFE.contented(_mood, _rows) and _LIFE.dominant(_mood, _rows) != "neutral" else "neutral"
		if _LIFE.unhappy(_mood, _rows):
			_clip = "sad"
	global_position.y = _owner_body.global_position.y


func _apply_dna() -> void:
	if _dna.size() < 9:
		return
	for node in _nodes.values():
		(node as MeshInstance3D).visible = false
	var body := int(_dna[4])
	var bodies: Array = _catalog["bodies"]
	var body_name := String(bodies[clampi(body, 0, bodies.size() - 1)])
	var color := _palette_color(int(_dna[5]))
	var color_scale := float((_catalog["scales"] as Array)[clampi(int(_dna[6]), 0, 8)])
	var part_color := _amplify(color, color_scale)
	_paint("body", color, String((_catalog["body_textures"] as Dictionary)[body_name]))
	var feet := "normal"
	if body_name == "turtle" or body_name == "giraffe" or body_name == "leopard":
		feet = body_name
	var foot_tex := String((_catalog["foot_textures"] as Dictionary)[feet])
	_paint("leftFoot", color, foot_tex)
	_paint("rightFoot", color, foot_tex)
	_show_piece((_catalog["heads"] as Array), int(_dna[0]), part_color, "")
	var ear_name := _show_piece((_catalog["ears"] as Array), int(_dna[1]), part_color, "")
	if ear_name != "":
		var exotic: Dictionary = _catalog["exotic_ears"] if body_name == "giraffe" or body_name == "leopard" else _catalog["ear_textures"]
		if exotic.has(ear_name):
			_paint(ear_name, part_color, String(exotic[ear_name]))
	_show_piece((_catalog["noses"] as Array), int(_dna[2]), part_color, "")
	var tail_name := _show_piece((_catalog["tails"] as Array), int(_dna[3]), part_color, "")
	if tail_name != "":
		var tail_tex := ""
		if body_name == "giraffe":
			tail_tex = String(_catalog["giraffe_tail"])
		elif body_name == "leopard":
			tail_tex = String(_catalog["leopard_tail"])
		elif (_catalog["tail_textures"] as Dictionary).has(tail_name):
			tail_tex = String((_catalog["tail_textures"] as Dictionary)[tail_name])
		if tail_tex != "":
			_paint(tail_name, part_color, tail_tex)
	_paint("extra", color, _PALETTE)
	var boy := int(_dna[8]) == 1
	var eyes: Dictionary = _catalog["eyes"]
	_eyes_open = String(eyes["boy"] if boy else eyes["girl"])
	_eyes_shut = String(eyes["boy_blink"] if boy else eyes["girl_blink"])
	_paint("eyeWhites", Color.WHITE, _eyes_open)
	var eye := _palette_eye(int(_dna[7]))
	_paint("leftPupil", eye, _PUPIL)
	_paint("rightPupil", eye, _PUPIL)
	_paint("leftHighlight", Color.WHITE, _PUPIL)
	_paint("rightHighlight", Color.WHITE, _PUPIL)
	_paint("leftBrow", Color.BLACK, _PUPIL)
	_paint("rightBrow", Color.BLACK, _PUPIL)


func _show_piece(choices: Array, index: int, color: Color, texture_name: String) -> String:
	if index < 0 or index >= choices.size():
		return ""
	var piece := String(choices[index])
	_paint(piece, color, texture_name if texture_name != "" else _PALETTE)
	return piece


func _paint(part: String, color: Color, texture_name: String) -> void:
	if not _nodes.has(part):
		return
	var mesh_node := _nodes[part] as MeshInstance3D
	mesh_node.visible = true
	var material := mesh_node.material_override as StandardMaterial3D
	material.albedo_color = color
	if texture_name != "":
		material.albedo_texture = _texture(texture_name)


func _pose() -> void:
	var rate := float(_FPS.get(_clip, 12.0))
	for part in _nodes.keys():
		var mesh_node := _nodes[part] as MeshInstance3D
		if not mesh_node.visible:
			continue
		var info: Dictionary = _meta[part]
		var clip := _clip
		var frames: Dictionary = info["frames"]
		if not frames.has(clip):
			clip = "neutral"
		var count := int(frames.get(clip, 1))
		if count < 1:
			continue
		var frame := int(_clock * rate)
		if posing:
			if _reverse:
				frame = maxi(count - 1 - mini(frame, count - 1), 0)
			else:
				frame = mini(maxi(frame + _start_frame, 0), count - 1)
		else:
			frame = frame % count
		var stamp := "%s:%d" % [clip, frame]
		if String(_shown.get(part, "")) == stamp:
			continue
		_shown[part] = stamp
		var uv: Array = info["uv"]
		var verts := uv.size() >> 1
		var start := int((info["offset"] as Dictionary)[clip]) + frame * verts * 3
		var positions := PackedVector3Array()
		var normals := PackedVector3Array()
		var texcoords := PackedVector2Array()
		positions.resize(verts)
		normals.resize(verts)
		texcoords.resize(verts)
		for index in verts:
			var cursor := (start + index * 3) * 4
			positions[index] = Vector3(
				_clips.decode_float(cursor),
				_clips.decode_float(cursor + 4) - _ground,
				_clips.decode_float(cursor + 8)
			)
			texcoords[index] = Vector2(float(uv[index * 2]), float(uv[index * 2 + 1]))
		for index in range(0, verts - 2, 3):
			var edge := (positions[index + 1] - positions[index]).cross(positions[index + 2] - positions[index])
			var normal := Vector3.UP if edge.length_squared() < 0.0000001 else edge.normalized()
			normals[index] = normal
			normals[index + 1] = normal
			normals[index + 2] = normal
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = positions
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = texcoords
		var mesh := mesh_node.mesh as ArrayMesh
		mesh.clear_surfaces()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if _blink > 3.4 and _eyes_shut != "":
		_paint("eyeWhites", Color.WHITE, _eyes_shut if _blink < 3.55 else _eyes_open)
		if _blink >= 3.55:
			_blink = 0.0


func _lowest_foot() -> float:
	var lowest := 1000.0
	for part_name in ["leftFoot", "rightFoot"]:
		for part in _parts:
			var info: Dictionary = part
			if String(info["name"]) != part_name:
				continue
			var uv: Array = info["uv"]
			var verts := uv.size() >> 1
			var start := int((info["offset"] as Dictionary)["neutral"])
			for index in verts:
				lowest = minf(lowest, _clips.decode_float((start + index * 3 + 1) * 4))
	return lowest if lowest < 100.0 else 0.0


func _palette_color(index: int) -> Color:
	var colors: Array = _catalog["colors"]
	var row: Array = colors[clampi(index, 0, colors.size() - 1)]
	return Color(float(row[0]), float(row[1]), float(row[2]), 1.0)


func _palette_eye(index: int) -> Color:
	var colors: Array = _catalog["eye_colors"]
	var row: Array = colors[clampi(index, 0, colors.size() - 1)]
	return Color(float(row[0]), float(row[1]), float(row[2]), 1.0)


func _amplify(color: Color, amount: float) -> Color:
	return Color(
		minf(color.r * amount, 1.0),
		minf(color.g * amount, 1.0),
		minf(color.b * amount, 1.0),
		1.0
	)


static func _texture(file_name: String) -> Texture2D:
	if _textures.has(file_name):
		return _textures[file_name]
	var texture := load(_MAPS + file_name) as Texture2D
	_textures[file_name] = texture
	return texture


func _load_life() -> void:
	var record := _KENNEL.current()
	_rows = record.get("traits", [])
	if _rows.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(String(record.get("name", "Doodle")))
		var rolled: Dictionary = _LIFE.roll(rng, int(record.get("zone", 2000)))
		_rows = rolled["rows"]
		record["traits"] = _rows
	var mood = record.get("mood", {})
	_mood = mood if mood is Dictionary and not (mood as Dictionary).is_empty() else _LIFE.blank_mood()
	var tricks = record.get("tricks", [])
	_tricks = []
	for index in 7:
		var known := 0.0
		if tricks is Array and index < (tricks as Array).size():
			known = float((tricks as Array)[index])
		_tricks.append(known)
	var stamp := float(record.get("mood_at", 0.0))
	if stamp > 0.0:
		var elapsed := clampf(Time.get_unix_time_from_system() - stamp, 0.0, 48.0 * 3600.0)
		_mood = _LIFE.drift(_mood, _rows, elapsed)
	_remember()


func _live(delta: float) -> void:
	_drift_left -= delta
	_save_left -= delta
	if _drift_left > 0.0:
		return
	_drift_left = 1.0
	_mood = _LIFE.drift(_mood, _rows, 1.0)
	if _save_left <= 0.0:
		_save_left = 5.0
		_remember()


func _remember() -> void:
	if remote or gui:
		return
	_KENNEL.update_life(_mood, _tricks)


func ask_trick(trick_id: int) -> void:
	if remote or gui or _act_left > 0.0 or trick_id < 0 or trick_id > 6:
		return
	var accuracy := float([1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4][trick_id])
	var happy := _LIFE.contented(_mood, _rows)
	var low := 0.5 if happy else 0.1
	var high := 0.97 if happy else 0.6
	var cutoff := lerpf(low, high, float(_tricks[trick_id])) * accuracy
	if _LIFE.active(_mood, _rows, "fatigue"):
		cutoff *= 0.5
	if randf() >= cutoff:
		_begin([{"clip": "neutral", "seconds": 1.0}], 0)
		return
	var aptitude := float(_tricks[trick_id])
	_tricks[trick_id] = minf(aptitude + 0.0005, 1.0)
	_mood = _LIFE.nudge(_mood, {"fatigue": lerpf(0.65, 0.1, aptitude)})
	var heals: Array = [[5, 10], [6, 12], [7, 14], [8, 16], [9, 18], [10, 20], [11, 22]]
	var pair: Array = heals[trick_id]
	var amount := int(round(lerpf(float(pair[0]), float(pair[1]), aptitude)))
	_begin(_steps(trick_id), amount)
	_remember()


func feed() -> void:
	if remote or gui or _act_left > 0.0:
		return
	if _owner_body != null and global_position.distance_to(_owner_body.global_position) > 4.0:
		return
	if not _BEANS.take_beans(1, true):
		return
	_mood = _LIFE.nudge(_mood, {
		"affection": 0.35, "anger": -0.07, "boredom": -0.5, "excitement": 0.5,
		"fatigue": -0.2, "hunger": -0.5, "loneliness": -0.08, "playfulness": 0.1,
		"restlessness": -0.05, "sadness": -0.2,
	})
	_begin([
		{"clip": "toBeg", "seconds": 1.2},
		{"clip": "beg", "seconds": 1.6},
		{"clip": "eat", "seconds": 1.6},
		{"clip": "swallow", "seconds": 1.0},
	], 0)
	_remember()
	_hide_panel()


func scratch() -> void:
	if remote or gui or _act_left > 0.0:
		return
	if _owner_body != null and global_position.distance_to(_owner_body.global_position) > 2.0:
		return
	_mood = _LIFE.nudge(_mood, {
		"affection": 0.45, "anger": -0.1, "boredom": -0.8, "excitement": 0.5,
		"fatigue": -0.25, "loneliness": -0.2, "playfulness": 0.1,
		"restlessness": -0.2, "sadness": -0.2,
	})
	_begin([{"clip": "happy", "seconds": 2.0}], 0)
	_remember()
	_hide_panel()


func call_over() -> void:
	if remote or gui:
		return
	_called = 3.0
	_acts.clear()
	_act_left = 0.0
	_hide_panel()


func _begin(steps: Array, heal: int) -> void:
	_acts = steps
	_act_heal = heal
	_act_left = 0.0
	_advance_act()


func _advance_act() -> void:
	if _acts.is_empty():
		if _act_heal > 0:
			_heal_near(_act_heal)
		_act_heal = 0
		_clip = "neutral"
		return
	var step: Dictionary = _acts.pop_front()
	_clip = String(step.get("clip", "neutral"))
	_act_left = float(step.get("seconds", 1.0))
	_shown.clear()


func _steps(trick_id: int) -> Array:
	if trick_id == 0:
		return [{"clip": "jump", "seconds": 2.0}]
	if trick_id == 1:
		return [{"clip": "toBeg", "seconds": 1.2}, {"clip": "beg", "seconds": 2.4}, {"clip": "fromBeg", "seconds": 1.5}]
	if trick_id == 2:
		return [{"clip": "playDead", "seconds": 12.0}, {"clip": "fromPlayDead", "seconds": 3.2}]
	if trick_id == 3:
		return [{"clip": "rollover", "seconds": 8.0}]
	if trick_id == 4:
		return [{"clip": "backflip", "seconds": 4.88}]
	if trick_id == 5:
		return [{"clip": "dance", "seconds": 7.42}]
	return [{"clip": "speak", "seconds": 0.75}]


func _heal_near(amount: int) -> void:
	var host := get_parent()
	if host == null or amount <= 0:
		return
	for child in host.get_children():
		if not child.has_method("heal"):
			continue
		var body := _toon_body(child)
		if body != null and global_position.distance_to(body.global_position) <= 15.0:
			child.heal(amount)


func _toon_body(node: Node) -> Node3D:
	if node is CharacterBody3D:
		return node
	for child in node.get_children():
		var found := _toon_body(child)
		if found != null:
			return found
	return null


func _unhandled_input(event: InputEvent) -> void:
	if remote or gui or not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _clicked(click.position):
		_hide_panel()
		return
	_toggle_panel()
	get_viewport().set_input_as_handled()


func _clicked(screen: Vector2) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var offset := global_position + Vector3(0.0, 0.8, 0.0) - origin
	var along := offset.dot(direction)
	if along < 0.0:
		return false
	var closest := origin + direction * along
	return closest.distance_to(global_position + Vector3(0.0, 0.8, 0.0)) < 1.35


func _toggle_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		_hide_panel()
		return
	_panel = CanvasLayer.new()
	_panel.layer = 30
	add_child(_panel)
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.55, 0.85, 0.45, 0.92)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	box.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	box.add_child(column)
	_panel.add_child(box)
	var view := get_viewport().get_visible_rect().size
	box.position = Vector2(view.x - 180.0, view.y * 0.35)
	_life_button(column, "Feed", feed)
	_life_button(column, "Scratch", scratch)
	_life_button(column, "Call", call_over)


func _life_button(column: VBoxContainer, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140.0, 32.0)
	button.add_theme_font_override("font", _GUI.font())
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	column.add_child(button)


func _hide_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null


func _exit_tree() -> void:
	_remember()
