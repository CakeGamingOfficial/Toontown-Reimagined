extends "res://scenes/trolley/trolley_minigame.gd"

## Ring Game. Sixteen groups swim toward you. Only your color counts.
## Tracks, spacing, and the water scroll follow RingGameGlobals and DistributedRingGame.

const _SEA := preload("res://assets/minigames/swimming_game.glb")
const _RING := preload("res://assets/minigames/swimming_ring.glb")
const _COLORS: Array[Color] = [
	Color(1.0, 0.4, 0.2), Color(0.0, 0.9, 0.2), Color(1.0, 0.5, 0.25),
	Color(1.0, 0.0, 1.0), Color(1, 1, 1), Color(0, 0, 0), Color(1, 1, 0.2),
]
const _NAMES: Array[String] = ["red", "green", "orange", "purple", "white", "black", "yellow"]
const _PAD: Array[Vector2] = [
	Vector2(0, 0), Vector2(0, 1), Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0),
	Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1),
]
const _SWIM := 22.5
const _SPACING := 67.5
const _FIRST_Y := 135.0
const _ENV_LEN := 150.0
const _ENV_START := 20.0
const _FLOOR_Z := -14.4
const _REACH := 3.075 * 3.075
const _GROUPS := 16

var _sea: Node3D
var _lane: Node3D
var _groups: Array[Dictionary] = []
var _fades: Array[Dictionary] = []
var _mine := 0
var _color := 0
var _px := 0.0
var _pz := 0.0
var _time := 0.0
var _passed := 0
var _finish := -1.0
var _sign: Label
var _toon_shadow: MeshInstance3D


func _init() -> void:
	title = "Ring Game"
	duration = float(_GROUPS) * 3.0 + 6.0 + 1.0


func _build() -> void:
	_water()
	_hide_floor()
	_lay_sea()
	_px = lineup_x(4.0)
	_make_toon(_panda(_px, 0.0, 0.0))
	_toon.pose_swimming(false)
	# The swim pitch stands the rig upright and facing the camera.
	# Another -90 lays them away from the camera, back toward us, head toward the rings.
	_toon.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_toon_shadow = _shadow(1.1)
	_camera.fov = 80.0
	_camera.far = 150.0
	_aim_camera()
	_loop_sfx("AV_ambient_water", 0.8)
	_pick_colors()
	_sign_up()
	show_board("ring")


func _play(delta: float) -> void:
	var move := _stick()
	_px = clampf(_px + move.x * 10.0 * delta, -10.0, 10.0)
	_pz = clampf(_pz + move.y * 10.0 * delta, -10.0, 10.0)
	_toon.position = _panda(_px, 0.0, _pz)
	_aim_camera()
	_time += delta
	var travel := _time * _SWIM
	_sea.position = _panda(0.0, -fmod(travel, _ENV_LEN) - _ENV_START, 0.0)
	_lane.position = _panda(0.0, -travel, 0.0)
	_place_shadow(_toon_shadow, _toon.global_position)
	for group in _groups:
		if group["done"]:
			continue
		_pose_group(group)
		if float(group["y"]) - travel < 0.0:
			_cross(group)
	_fade_rings(delta)
	if _passed < _GROUPS or _finish < 0.0:
		return
	_finish -= delta
	if _finish <= 0.0:
		_end()


func _water() -> void:
	for child in get_children():
		if not (child is WorldEnvironment):
			continue
		var env := (child as WorldEnvironment).environment
		if env == null:
			return
		env.background_color = Color(0.0, 0.0, 0.6)
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_light_color = Color(0.0, 0.0, 0.6)
		env.fog_depth_begin = 0.1
		env.fog_depth_end = 149.0
		return


func _lay_sea() -> void:
	_sea = Node3D.new()
	_sea.name = "Sea"
	add_child(_sea)
	_sea.position = _panda(0.0, -_ENV_START, 0.0)
	for row in [0.0, _ENV_LEN]:
		for column in [0.0, -_ENV_LEN, -_ENV_LEN * 2.0, _ENV_LEN, _ENV_LEN * 2.0]:
			var block := _SEA.instantiate() as Node3D
			_sea.add_child(block)
			block.position = _panda(column, row, 0.0)
	_lane = Node3D.new()
	_lane.name = "Rings"
	add_child(_lane)


func _pick_colors() -> void:
	# selectColorIndices. Red, green, and orange share one draw.
	var bag: Array = [[0, 1, 2], 3, 4, 5, 6]
	var picked: Array[int] = []
	for _draw in 4:
		var draw := shared_int(bag.size())
		var slot: Variant = bag[draw]
		bag.remove_at(draw)
		var color := 0
		if slot is Array:
			var warm: Array = slot
			color = int(warm[shared_int(warm.size())])
		else:
			color = int(slot)
		picked.append(color)
	_mine = mini(party_index(), picked.size() - 1)
	_color = picked[_mine]
	var count := party_size()
	if count < 2:
		instructions = "Try to swim through as many of the %s rings as you can.  Use the arrow keys to swim." % _NAMES[_color]
	else:
		instructions = "Try to swim through the %s rings.  Other players will try for the other colored rings.  Use the arrow keys to swim." % _NAMES[_color]
	var hood := int(_RIDE.hood)
	var pattern: Array = _pattern(hood)
	var colors: Array[int] = []
	for index in count:
		colors.append(picked[index])
	for group_index in _GROUPS:
		_groups.append(_make_group(int(pattern[group_index]), colors, group_index))


func _pattern(hood: int) -> Array:
	var table: Array = _patterns(hood)
	return table[shared_int(table.size())]


func _patterns(hood: int) -> Array:
	match hood:
		1000:
			return [
				_fill(0, 10) + _fill(1, 6),
				_tile([0, 0, 0, 0, 0, 1, 1, 1]),
				_tile([0, 0, 0, 1, 0, 0, 1, 1]),
			]
		5000:
			return [
				_fill(0, 4) + _fill(1, 12),
				_tile([0, 0, 1, 1, 1, 1, 1, 1]),
				_tile([0, 1, 1, 1, 0, 1, 1, 1]),
			]
		4000:
			return [
				_fill(0, 4) + _fill(1, 8) + _fill(2, 4),
				_tile([0, 0, 1, 1, 1, 1, 2, 2]),
				_tile([0, 1, 1, 1, 1, 0, 2, 2]),
				_tile([0, 1, 1, 2, 0, 1, 1, 2]),
				_tile([0, 1, 2, 1, 0, 1, 2, 1]),
			]
		3000:
			return [
				_fill(0, 4) + _fill(1, 6) + _fill(2, 6),
				_tile([0, 0, 1, 1, 1, 2, 2, 2]),
				_tile([0, 1, 1, 1, 0, 2, 2, 2]),
				_tile([0, 1, 1, 2, 0, 1, 2, 2]),
				_tile([0, 1, 2, 1, 0, 1, 2, 2]),
			]
		9000:
			return [
				_fill(0, 2) + _fill(1, 6) + _fill(2, 8),
				_tile([0, 1, 1, 1, 2, 2, 2, 2]),
				_tile([0, 1, 1, 2, 2, 1, 2, 2]),
				_tile([0, 1, 2, 1, 2, 1, 2, 2]),
			]
		_:
			return [
				_fill(0, 14) + _fill(1, 2),
				_tile([0, 0, 0, 0, 0, 0, 0, 1]),
				[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1],
			]


func _fill(value: int, count: int) -> Array:
	var row: Array = []
	for _index in count:
		row.append(value)
	return row


func _tile(row: Array) -> Array:
	return row + row


func _make_group(difficulty: int, colors: Array[int], index: int) -> Dictionary:
	var count := colors.size()
	var motion := _motion(difficulty, count)
	var rings: Array = motion["rings"]
	_scramble(rings)
	var body := Node3D.new()
	body.name = "Group%d" % index
	_lane.add_child(body)
	body.position = _panda(0.0, _FIRST_Y + float(index) * _SPACING, 0.0)
	var made: Array[Dictionary] = []
	for ring_index in count:
		var spec: Dictionary = rings[ring_index]
		var pivot := Node3D.new()
		body.add_child(pivot)
		var model := _RING.instantiate() as Node3D
		if model != null:
			pivot.add_child(model)
			_paint(model, _COLORS[colors[ring_index]])
		var shadow := _shadow(2.2)
		made.append({
			"pivot": pivot,
			"segments": spec["segments"],
			"offset": float(spec["offset"]),
			"color": _COLORS[colors[ring_index]],
			"mine": ring_index == _mine,
			"shadow": shadow,
			"settled": false,
		})
	return {
		"body": body,
		"y": _FIRST_Y + float(index) * _SPACING,
		"period": float(motion["period"]),
		"reverse": shared_int(2) == 1,
		"offset": shared_float(0.0, 1.0),
		"rings": made,
		"done": false,
		"index": index,
	}


func _motion(difficulty: int, count: int) -> Dictionary:
	var table: Array = _funcs(difficulty, count)
	return _build_motion(int(table[shared_int(table.size())]), count)


func _funcs(difficulty: int, count: int) -> Array:
	# trackListGenFuncs. A single ring cannot use the patterns that need a partner.
	var all: Array = [[0], [1, 2, 3, 4, 5, 6], [7, 8, 9, 10]][clampi(difficulty, 0, 2)]
	if count > 1:
		return all
	var kept: Array = []
	for item in all:
		if int(item) != 2 and int(item) != 3 and int(item) != 6 and int(item) != 9 and int(item) != 10:
			kept.append(item)
	return kept


func _build_motion(which: int, count: int) -> Dictionary:
	var rings: Array = []
	var period := 6.0
	match which:
		0:
			rings = _keypad(count)
			period = 1.0
		1:
			rings = _circles(count, true)
		2:
			rings = _circles(count, false)
		3, 9:
			rings = _centered(count)
			period = 5.0 if which == 9 else 6.0
		4:
			rings = _slots(count, true)
		5:
			rings = _slots(count, false)
		6, 10:
			rings = _plus(count)
			period = 2.5 if which == 10 else 4.0
		7:
			rings = _infinity(count, true)
			period = 5.0
		8:
			rings = _infinity(count, false)
			period = 5.0
		_:
			rings = _keypad(count)
			period = 1.0
	return {"rings": rings, "period": period}


func _keypad(count: int) -> Array:
	var spots: Array[Vector2] = _PAD.duplicate()
	var scale := 0.7 + shared_float(0.0, 1.0) * 0.2
	var rings: Array = []
	for _index in count:
		var pick := shared_int(spots.size())
		var spot := spots[pick] * scale
		spots.remove_at(pick)
		rings.append({"segments": [{"kind": "still", "dur": 1.0, "a": spot}], "offset": 0.0})
	return rings


func _circles(count: int, even: bool) -> Array:
	var rings: Array = []
	for index in count:
		var offset := float(index) / float(count) if even else float(index) * 0.12
		rings.append({"segments": [{"kind": "circle", "dur": 1.0}], "offset": offset})
	return rings


func _centered(count: int) -> Array:
	var inner := shared_range(1, count - 1)
	var rings: Array = []
	var step := TAU / float(inner)
	for index in inner:
		var angle := float(index) * step + step * 0.5
		var spot := Vector2(sin(angle), cos(angle)) / 3.0
		if inner == 1:
			spot = Vector2.ZERO
		rings.append({"segments": [{"kind": "still", "dur": 1.0, "a": spot}], "offset": 0.0})
	var outer := count - inner
	for index in outer:
		rings.append({"segments": [{"kind": "circle", "dur": 1.0}], "offset": float(index) / float(outer)})
	return rings


func _slots(count: int, vertical: bool) -> Array:
	var spots: Array[float] = []
	for index in count:
		spots.append(float(index) * (2.0 / 3.0) - float(count - 1) * (2.0 / 3.0) * 0.5)
	var margin := 1.0 - spots[spots.size() - 1]
	var shift := shared_float(-margin, margin)
	var rings: Array = []
	for index in count:
		var at := spots[index] + shift
		var going: Array
		var back: Array
		if vertical:
			going = [{"kind": "clerp", "dur": 0.5, "a": Vector2(at, 1.0), "b": Vector2(at, -1.0)}]
			back = [{"kind": "clerp", "dur": 0.5, "a": Vector2(at, -1.0), "b": Vector2(at, 1.0)}]
		else:
			going = [{"kind": "clerp", "dur": 0.5, "a": Vector2(1.0, at), "b": Vector2(-1.0, at)}]
			back = [{"kind": "clerp", "dur": 0.5, "a": Vector2(-1.0, at), "b": Vector2(1.0, at)}]
		rings.append({"segments": going + back, "offset": float(index) / float(count) * 0.5})
	return rings


func _plus(count: int) -> Array:
	var sets := {
		2: [[0, 1], [2, 3]],
		3: [[0, 2, 3], [2, 0, 1], [1, 2, 3], [3, 0, 1]],
		4: [[0, 1, 2, 3]],
	}
	var choices: Array = sets[count]
	var arms: Array = choices[shared_int(choices.size())]
	var rings: Array = []
	for index in count:
		rings.append({"segments": _plus_arm(int(arms[index])), "offset": 0.0})
	return rings


func _plus_arm(arm: int) -> Array:
	var tip := Vector2.ZERO
	var rest := Vector2.ZERO
	match arm:
		0:
			rest = Vector2(0.0, 0.4)
			tip = Vector2(0.0, 1.0)
		1:
			rest = Vector2(0.0, -0.4)
			tip = Vector2(0.0, -1.0)
		2:
			rest = Vector2(-0.4, 0.0)
			tip = Vector2(-1.0, 0.0)
		_:
			rest = Vector2(0.4, 0.0)
			tip = Vector2(1.0, 0.0)
	return [
		{"kind": "clerp", "dur": 0.5, "a": rest, "b": tip},
		{"kind": "clerp", "dur": 0.5, "a": tip, "b": rest},
	]


func _infinity(count: int, vertical: bool) -> Array:
	var offsets: Array[float] = [0.0]
	if count == 2:
		offsets = [0.0, 0.75]
	elif count == 3:
		offsets = [0.0, 1.0 / 3.0, 2.0 / 3.0]
	elif count >= 4:
		offsets = []
		var accum := 0.0
		for _index in count:
			offsets.append(fmod(accum, 1.0))
			accum += 14.0 / 23.0
	var kind := "vert" if vertical else "horiz"
	var rings: Array = []
	for index in count:
		rings.append({"segments": [{"kind": kind, "dur": 1.0}], "offset": offsets[index]})
	return rings


func _scramble(rings: Array) -> void:
	for index in range(rings.size() - 1, 0, -1):
		var swap := shared_int(index + 1)
		var kept: Variant = rings[index]
		rings[index] = rings[swap]
		rings[swap] = kept


func _pose_group(group: Dictionary) -> void:
	var period := float(group["period"])
	var along := fmod(_time / period + float(group["offset"]), 1.0)
	if group["reverse"]:
		along = 1.0 - along
	var rings: Array = group["rings"]
	for item in rings:
		var ring: Dictionary = item
		if ring["settled"]:
			continue
		var sample := fmod(along + float(ring["offset"]), 1.0)
		var spot := _eval(ring["segments"], sample) * 10.0
		var pivot := ring["pivot"] as Node3D
		pivot.position = _panda(spot.x, 0.0, spot.y)
		var shadow := ring["shadow"] as MeshInstance3D
		_place_shadow(shadow, pivot.global_position)


func _cross(group: Dictionary) -> void:
	group["done"] = true
	_passed += 1
	var hit := false
	var rings: Array = group["rings"]
	for item in rings:
		var ring: Dictionary = item
		if not ring["mine"]:
			continue
		var pivot := ring["pivot"] as Node3D
		var flat := Vector2(pivot.global_position.x - _toon.global_position.x, pivot.global_position.y - _toon.global_position.y)
		hit = flat.length_squared() <= _REACH
		_settle(ring, hit)
		if hit:
			score += 1
			_sfx("ring_get")
		else:
			_sfx("ring_miss", 0.7)
	if _board != null:
		_board.mark_ring(int(group["index"]), hit)
	if _passed < _GROUPS:
		return
	_finish = 2.0 if score >= _GROUPS else 1.0
	if score >= _GROUPS:
		_sfx("ring_perfect")
		if _board != null:
			_board.perfect()


func _settle(ring: Dictionary, hit: bool) -> void:
	ring["settled"] = true
	var shadow := ring["shadow"] as MeshInstance3D
	if shadow != null:
		shadow.visible = false
	var pivot := ring["pivot"] as Node3D
	var held := pivot.global_transform
	pivot.reparent(self)
	pivot.global_transform = held
	var note: Label3D = null
	if not hit:
		# __genText uses the sign font at scale 1, tinted with the ring color,
		# and sits one unit toward the camera. It has no outline.
		note = Label3D.new()
		note.text = "MISSED"
		note.font = ToonGui.sign_font()
		note.font_size = 110
		note.pixel_size = 1.0 / 110.0
		note.outline_size = 0
		note.modulate = ring["color"]
		note.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		note.visible = false
		add_child(note)
		note.global_position = pivot.global_position + Vector3(0.0, 0.0, 1.0)
	_fades.append({"pivot": pivot, "note": note, "hit": hit, "age": -0.1, "color": ring["color"]})


func _fade_rings(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for item in _fades:
		item["age"] = float(item["age"]) + delta
		var age := float(item["age"])
		var note := item["note"] as Label3D
		if note != null:
			note.visible = age >= 0.0
		if age < 0.0:
			kept.append(item)
			continue
		var along := clampf(age / 0.5, 0.0, 1.0)
		var pivot := item["pivot"] as Node3D
		if item["hit"]:
			pivot.scale = Vector3.ONE * lerpf(1.0, 2.0, along)
			var tint: Color = item["color"]
			var flipped := Color(1.0 - tint.r, 1.0 - tint.g, 1.0 - tint.b, 1.0)
			var shown := tint.lerp(flipped, clampf(along / 0.5, 0.0, 1.0))
			if along > 0.5:
				shown.a = 1.0 - (along - 0.5) / 0.5
			_paint(pivot, shown)
		else:
			var shrink := along * along
			pivot.scale = Vector3.ONE * lerpf(1.0, 0.01, shrink)
		if along >= 1.0:
			pivot.queue_free()
			if note != null:
				note.queue_free()
		else:
			kept.append(item)
	_fades = kept


func _eval(segments: Array, along: float) -> Vector2:
	var cursor := 0.0
	for index in segments.size():
		var seg: Dictionary = segments[index]
		var span := float(seg["dur"])
		var end := cursor + span
		if along < end or index == segments.size() - 1:
			var u := 0.0 if span <= 0.001 else clampf((along - cursor) / span, 0.0, 1.0)
			return _sample(seg, u)
		cursor = end
	return Vector2.ZERO


func _sample(seg: Dictionary, along: float) -> Vector2:
	var kind := String(seg["kind"])
	if kind == "still":
		return seg["a"]
	if kind == "clerp":
		var smooth := along * along * (3.0 - 2.0 * along)
		return (seg["a"] as Vector2).lerp(seg["b"], smooth)
	var turns := along * TAU
	if kind == "circle":
		return Vector2(sin(turns), cos(turns))
	if kind == "vert":
		return Vector2(0.5 * sin(turns * 2.0), cos(turns))
	return Vector2(sin(turns), 0.5 * sin(turns * 2.0))


func _aim_camera() -> void:
	_camera.position = _panda(_px, -15.0, _pz)
	var ahead := _panda(_px, 20.0, _pz)
	if _camera.global_position.distance_squared_to(ahead) > 0.04:
		_camera.look_at(ahead, Vector3.UP)


func _sign_up() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_sign = Label.new()
	_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sign.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_sign.offset_top = 70
	_sign.offset_bottom = 130
	_sign.offset_left = -280
	_sign.offset_right = 280
	_sign.add_theme_font_size_override("font_size", 40)
	_sign.add_theme_constant_override("outline_size", 10)
	_sign.text = "Swim through the %s rings" % _NAMES[_color]
	var ink := _COLORS[_color]
	if ink.get_luminance() < 0.2:
		ink = Color(0.85, 0.85, 0.85)
	_sign.add_theme_color_override("font_color", ink)
	_sign.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.16))
	layer.add_child(_sign)


func _shadow(size: float) -> MeshInstance3D:
	var body := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(size, size * 0.72)
	body.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0, 0, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body.material_override = mat
	add_child(body)
	return body


func _place_shadow(body: MeshInstance3D, at: Vector3) -> void:
	if body == null:
		return
	body.global_position = Vector3(at.x, _FLOOR_Z, at.z)


func _paint(root: Node, color: Color) -> void:
	if root is MeshInstance3D:
		var mesh_node := root as MeshInstance3D
		var mat := mesh_node.material_override as StandardMaterial3D
		if mat == null:
			mat = StandardMaterial3D.new()
			var current := mesh_node.get_active_material(0)
			if current is StandardMaterial3D:
				mat.albedo_texture = (current as StandardMaterial3D).albedo_texture
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh_node.material_override = mat
		mat.albedo_color = color
	for child in root.get_children():
		_paint(child, color)
