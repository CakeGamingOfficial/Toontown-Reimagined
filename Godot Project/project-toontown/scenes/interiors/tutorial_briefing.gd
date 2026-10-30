class_name TutorialBriefing
extends Node

## quest_assign_101, with the wording from the tutorial clip: posters, the
## gag handoff, the laff meter, and the first ToonTask.

const _POSTERS := {
	"suits": preload("res://assets/gui/tutorial/posters/suits.png"),
	"toon_buildings": preload("res://assets/gui/tutorial/posters/toon_buildings.png"),
	"suit_buildings": preload("res://assets/gui/tutorial/posters/suit_buildings.png"),
	"squirt1": preload("res://assets/gui/tutorial/posters/squirt1.png"),
	"squirt2": preload("res://assets/gui/tutorial/posters/squirt2.png"),
}
const _CUPCAKE := preload("res://assets/gui/tutorial/gags/inventory_tart.png")
const _FLOWER := preload("res://assets/gui/tutorial/gags/inventory_squirt_flower.png")
const _QUEST := preload("res://assets/gui/tutorial/quest_card.png")
const _BLACK := Color(0.08, 0.08, 0.1)
const _TEAL := Color(0.0, 0.58, 0.64)
const _PINK := Color(0.84, 0.27, 0.45)

var started := false
var finished := false

var _host: Node3D
var _panel: GagPanel
var _meter: LaffMeter
var _loadout: ToonLoadout
var _poster: MeshInstance3D
var _bubble: PanelContainer
var _label: Label
var _quest: Control
var _advance := false
var _bubble_on := false
# Height above Tom's feet, taken once from the resting head. The talk cycle
# moves def_head, and following that makes the bubble bob.
var _speech_offset := Vector3(0.15, 4.7, 0.0)
var _speech_cached := false
# The raised-hand clips move def_joint_right_hold. The quest props are
# parented to that joint with the original POSHPRSCALE.
var _held: Node3D
var _hold_hands: MeshInstance3D
var _hold_ids := PackedInt32Array()
var _hold_bind := PackedVector3Array()
var _hold_joint := Transform3D.IDENTITY
var _hold_local := Transform3D.IDENTITY
static var _palm_rest := PackedVector3Array()


func setup(host: Node3D, panel: GagPanel, meter: LaffMeter, loadout: ToonLoadout) -> void:
	_host = host
	_panel = panel
	_meter = meter
	_loadout = loadout
	_build_poster()
	_build_bubble()
	_build_quest()
	_cache_speech_anchor()


func start() -> void:
	if started:
		return
	started = true
	_run()


func _run() -> void:
	_host.call("set_cutscene", true)
	_host.call("dismiss_welcome")
	_expression("angry")
	await _pan_to_tom()
	await _line("These are Cogs. They're the business bots trying to take over Toontown.", _BLACK, "suits")
	await _line("There are all sorts of Cogs.", _TEAL, "suits")
	await _line("They turn happy Toon buildings...", _TEAL, "toon_buildings")
	_expression("sad")
	await _line("...into ugly Cog buildings!", _TEAL, "suit_buildings")
	_expression("normal")
	await _line("The Cogs are tough, but they can't take a joke!", _TEAL, "squirt1")
	await _line("A good gag will put a stop to them.", _TEAL, "squirt2")
	_show_poster("")
	await _line("There are lots of gags, but Clara will tell you about them later. Take these two to start...", _BLACK, "")
	await _hand_over_gags()
	await _present_laff()
	_host.call("face_tom", 130.0)
	_expression("surprised")
	await _gesture("pstart", 1.5, false)
	_gesture("rpoint", 1.0, true)
	await _line("OH NO! There's a Cog outside my shop!", _TEAL, "")
	await _line("HELP ME, PLEASE! Defeat that Cog!", _TEAL, "")
	await _gesture("pstart", -1.0, false)
	_host.call("face_tom", 180.0)
	_expression("angry")
	_clear_gesture()
	var tasks := _host.call("tasks") as ToonTasks
	if tasks != null:
		tasks.assign(101)
	_quest.position = Vector2(_view().x * 0.18, _view().y * 0.16)
	_quest.scale = Vector2(1.45, 1.45)
	_quest.visible = true
	await _line("Here is your first ToonTask!", _TEAL, "")
	_quest.visible = false
	await _line("Hurry up! Go defeat that Flunky!", _TEAL, "")
	_bubble_on = false
	_bubble.visible = false
	_show_poster("")
	_loadout.set_hp(15, 15)
	_loadout.save()
	_host.call("place_player", Vector3(0.776, 0.2, -14.6), 58.0)
	_expression("normal")
	_clear_gesture()
	_host.call("set_cutscene", false)
	finished = true


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		_advance = true
	if not _bubble_on or _host == null or _bubble == null:
		return
	var camera := _host.get_node_or_null("Camera") as Camera3D
	var tom := _host.get_node_or_null("Tutorial Tom") as Node3D
	if camera == null or tom == null or not tom.visible:
		_bubble.visible = false
		return
	_bubble.visible = true
	_bubble.reset_size()
	var view := _view()
	var screen := Vector2(view.x * 0.58, view.y * 0.28)
	if not _speech_cached:
		_cache_speech_anchor()
	var point := tom.global_position + _speech_offset
	if not camera.is_position_behind(point):
		screen = camera.unproject_position(point) + Vector2(36, -_bubble.size.y - 8)
	var pos := screen
	pos.x = clampf(pos.x, 20.0, maxf(20.0, view.x - _bubble.size.x - 20.0))
	pos.y = clampf(pos.y, 20.0, maxf(20.0, view.y - _bubble.size.y - 20.0))
	_bubble.position = pos


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_advance = true
	elif event.is_action_pressed("ui_accept"):
		_advance = true


func _cache_speech_anchor() -> void:
	var tom := _tom()
	if tom == null:
		return
	var head := tom.find_child("def_head", true, false) as Node3D
	if head == null:
		return
	var lift := head.global_position.y - tom.global_position.y + 0.7
	_speech_offset = Vector3(0.15, lift, 0.0)
	_speech_cached = true


func hide_speech() -> void:
	_bubble_on = false
	if _bubble:
		_bubble.visible = false


func _tom() -> ToonActor:
	if _host == null:
		return null
	return _host.get_node_or_null("Tutorial Tom") as ToonActor


func _expression(mood: String) -> void:
	var tom := _tom()
	if tom:
		tom.set_expression(mood)


func _clear_gesture() -> void:
	var tom := _tom()
	if tom:
		tom.clear_gesture()


func _gesture(suffix: String, rate: float, loop: bool) -> void:
	var tom := _tom()
	if tom == null:
		return
	tom.play_gesture(suffix, rate, loop)
	if loop:
		return
	while is_instance_valid(tom) and not tom.gesture_finished():
		await get_tree().process_frame


func _line(text: String, color: Color, poster: String) -> void:
	_show_poster(poster)
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	_bubble_on = true
	_advance = false
	while not _advance:
		await get_tree().process_frame
	_advance = false


func _hand_over_gags() -> void:
	_panel.refresh()
	var view := _view()
	_panel.position = Vector2((view.x - _panel.size.x) * 0.5, view.y * 0.12)
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.15, 0.15)
	_panel.visible = true
	var opened := create_tween()
	opened.tween_property(_panel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await opened.finished
	# quest_assign_101 seats each prop on def_joint_right_hold, plays the
	# hand out, holds it, then flies the model into the inventory icon.
	await _offer("squirting-flower", Vector3(0.10, -0.14, 0.20), Vector3(180.0, 287.10, 168.69), 0.70, Vector3(-1.75, 4.77, 0.0), Vector3(30.0, 180.0, 16.39), 0.75, Vector3(-1.76, 7.42, -0.63), Vector3(179.96, -89.9, -153.43), 0.12, _FLOWER, ToonLoadout.SQUIRT, 0)
	await get_tree().create_timer(0.25).timeout
	# The raised glove is about 0.77 across. The cupcake base is 1.15 at
	# scale 1, so 0.67 makes the bottom fill the palm. The quest's 0.34
	# leaves it about half that wide.
	await _offer("tart", Vector3(0.19, 0.02, 0.0), Vector3(0.0, 0.0, 349.38), 0.67, Vector3(-1.37, 4.56, 0.0), Vector3(329.53, 39.81, 346.76), 0.6, Vector3(-1.66, 7.42, -0.36), Vector3(0.0, 30.0, 30.0), 0.12, _CUPCAKE, ToonLoadout.THROW, 0)
	await get_tree().create_timer(1.1).timeout
	var closed := create_tween()
	closed.tween_property(_panel, "scale", Vector2(0.15, 0.15), 0.25)
	await closed.finished
	_panel.visible = false
	_panel.scale = Vector2.ONE


func _offer(prop_name: String, pos: Vector3, hpr: Vector3, amount: float, show_pos: Vector3, show_hpr: Vector3, show_scale: float, slot_pos: Vector3, slot_hpr: Vector3, slot_scale: float, texture: Texture2D, track: int, level: int) -> void:
	var prop := _make_prop(prop_name)
	_begin_hold(prop, pos, hpr, amount)
	await _gesture("rstart", 1.8, false)
	_gesture("rhand", 1.1, true)
	await get_tree().create_timer(0.8).timeout
	await _fly(prop, texture, track, level, show_pos, show_hpr, show_scale, slot_pos, slot_hpr, slot_scale)
	await _gesture("rstart", -1.5, false)
	_clear_gesture()


func _fly(prop: Node3D, texture: Texture2D, track: int, level: int, show_pos: Vector3, show_hpr: Vector3, show_scale: float, slot_pos: Vector3, slot_hpr: Vector3, slot_scale: float) -> void:
	_held = null
	var camera := _host.get_node_or_null("Camera") as Camera3D
	var held := prop.global_transform
	prop.reparent(_host)
	prop.global_transform = held
	var shown := _camera_prop(camera, show_pos, show_hpr, show_scale)
	var slotted := _camera_prop(camera, slot_pos, slot_hpr, slot_scale)
	var carry := create_tween()
	carry.tween_method(_blend_prop.bind(prop, held, shown), 0.0, 1.0, 0.589)
	await carry.finished
	await get_tree().create_timer(1.094).timeout
	var drop := create_tween()
	drop.tween_method(_blend_prop.bind(prop, shown, slotted), 0.0, 1.0, 1.0)
	await drop.finished
	var slot := _panel.slot_center(track, level)
	var from := slot
	if camera and is_instance_valid(prop) and not camera.is_position_behind(prop.global_position):
		from = camera.unproject_position(prop.global_position)
	if is_instance_valid(prop):
		prop.visible = false
	var icon := _flat_icon(texture, from)
	var settle := create_tween()
	settle.tween_method(_settle_icon.bind(icon, from, slot), 0.0, 1.0, 0.32)
	await settle.finished
	if is_instance_valid(prop):
		prop.queue_free()
	if is_instance_valid(icon):
		icon.queue_free()
	_loadout.set_gag(track, level, 1, true)
	_panel.refresh()


func _blend_prop(weight: float, prop: Node3D, start: Transform3D, finish: Transform3D) -> void:
	if not is_instance_valid(prop):
		return
	var basis := start.basis.orthonormalized().slerp(finish.basis.orthonormalized(), weight)
	var amount := lerpf(start.basis.get_scale().x, finish.basis.get_scale().x, weight)
	prop.global_transform = Transform3D(basis.scaled(Vector3.ONE * amount), start.origin.lerp(finish.origin, weight))


## Quest POSHPRSCALE is in the Panda camera: +X right, +Y forward, +Z up.
## The mesh is still Z-up, so only the finished camera point is turned upright.
func _camera_prop(camera: Camera3D, pos: Vector3, hpr: Vector3, amount: float) -> Transform3D:
	var panda := Transform3D(_panda_hpr(hpr.x, hpr.y, hpr.z).scaled(Vector3.ONE * amount), pos)
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	if camera == null:
		return Transform3D(upright, Vector3.ZERO) * panda
	return camera.global_transform * Transform3D(upright, Vector3.ZERO) * panda


func _settle_icon(weight: float, icon: TextureRect, from: Vector2, slot: Vector2) -> void:
	if not is_instance_valid(icon):
		return
	var side := lerpf(70.0, 34.0, weight)
	icon.size = Vector2(side, side)
	icon.global_position = from.lerp(slot, weight) - icon.size * 0.5


func _make_prop(prop_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = prop_name
	var packed := load("res://assets/battle/props/%s.glb" % prop_name) as PackedScene
	if packed:
		var model := packed.instantiate()
		root.add_child(model)
		# setScale in the quest replaces the egg root. The tart bakes that
		# 0.5 into the node, which would leave the cupcake half as big.
		if model is Node3D:
			(model as Node3D).scale = Vector3.ONE
		_two_sided(model)
	_host.add_child(root)
	return root


func _two_sided(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null:
			_unlock_surfaces(mesh)
	for child in node.get_children():
		_two_sided(child)


func _unlock_surfaces(mesh: MeshInstance3D) -> void:
	for surface in mesh.mesh.get_surface_count():
		var material := mesh.get_active_material(surface)
		if material is StandardMaterial3D:
			var copy := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
			copy.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.set_surface_override_material(surface, copy)


func _begin_hold(prop: Node3D, pos: Vector3, hpr: Vector3, amount: float) -> void:
	# quest_assign_101 parents the prop to def_joint_right_hold, then plays
	# right-hand-start. The joint track in that clip carries it into the palm.
	_held = prop
	_hold_ids = PackedInt32Array()
	_seat_in_hand(prop, pos, hpr, amount)


func _follow_hold() -> void:
	if _held == null or not is_instance_valid(_held) or _hold_hands == null or _hold_ids.is_empty():
		return
	if _hold_hands.mesh == null:
		return
	var verts := _mesh_vertices(_hold_hands)
	if verts.size() <= _hold_ids[_hold_ids.size() - 1]:
		return
	var posed := PackedVector3Array()
	posed.resize(_hold_ids.size())
	for index in _hold_ids.size():
		var vertex := _hold_ids[index]
		if vertex >= verts.size():
			return
		posed[index] = verts[vertex]
	var carried := _rigid_map(_hold_bind, posed) * _hold_joint * _hold_local
	_held.global_transform = _hold_hands.global_transform * carried


func _palm_rest_vertices() -> PackedVector3Array:
	if not _palm_rest.is_empty():
		return _palm_rest
	# Tutorial Tom's medium shorts torso. Frame 0 of its hand clips matches
	# these vertices, so the palm indices stay valid after the mesh is posed.
	var packed := load("res://assets/toons/parts/torso_ms.glb") as PackedScene
	if packed == null:
		return _palm_rest
	var torso := packed.instantiate()
	var hands := torso.find_child("hands", true, false) as MeshInstance3D
	if hands:
		_palm_rest = _mesh_vertices(hands)
	torso.free()
	return _palm_rest


func _mesh_vertices(mesh_node: MeshInstance3D) -> PackedVector3Array:
	if mesh_node == null or mesh_node.mesh == null or mesh_node.mesh.get_surface_count() == 0:
		return PackedVector3Array()
	var arrays := mesh_node.mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_VERTEX]


## Rigid map of the bind-pose palm onto the posed palm. The hold joint, and the
## gag seated on it, ride along with that motion.
func _rigid_map(src: PackedVector3Array, dst: PackedVector3Array) -> Transform3D:
	var count := mini(src.size(), dst.size())
	if count < 3:
		return Transform3D.IDENTITY
	var src_center := Vector3.ZERO
	var dst_center := Vector3.ZERO
	for index in count:
		src_center += src[index]
		dst_center += dst[index]
	src_center /= float(count)
	dst_center /= float(count)
	var covariance := PackedFloat32Array()
	covariance.resize(9)
	for index in count:
		var from := src[index] - src_center
		var to := dst[index] - dst_center
		# Rows are the posed point, columns the bind point, so the fit turns the
		# resting palm into the raised one instead of the other way around.
		covariance[0] += to.x * from.x
		covariance[1] += to.x * from.y
		covariance[2] += to.x * from.z
		covariance[3] += to.y * from.x
		covariance[4] += to.y * from.y
		covariance[5] += to.y * from.z
		covariance[6] += to.z * from.x
		covariance[7] += to.z * from.y
		covariance[8] += to.z * from.z
	var rotation := _kabsch_basis(covariance)
	return Transform3D(rotation, dst_center - rotation * src_center)


func _kabsch_basis(covariance: PackedFloat32Array) -> Basis:
	var gram := PackedFloat32Array()
	gram.resize(9)
	for row in 3:
		for col in 3:
			var sum := 0.0
			for k in 3:
				sum += covariance[k * 3 + row] * covariance[k * 3 + col]
			gram[row * 3 + col] = sum
	var values := PackedFloat32Array()
	values.resize(3)
	var vectors := _jacobi(gram, values)
	var order := [0, 1, 2]
	order.sort_custom(func(a: int, b: int) -> bool: return absf(values[a]) > absf(values[b]))
	var v_cols: Array[Vector3] = []
	var singular: Array[float] = []
	for slot in 3:
		var axis := int(order[slot])
		v_cols.append(Vector3(vectors[0][axis], vectors[1][axis], vectors[2][axis]))
		singular.append(sqrt(maxf(values[axis], 0.0)))
	var u_cols: Array[Vector3] = []
	for slot in 3:
		var mixed := Vector3(
			covariance[0] * v_cols[slot].x + covariance[1] * v_cols[slot].y + covariance[2] * v_cols[slot].z,
			covariance[3] * v_cols[slot].x + covariance[4] * v_cols[slot].y + covariance[5] * v_cols[slot].z,
			covariance[6] * v_cols[slot].x + covariance[7] * v_cols[slot].y + covariance[8] * v_cols[slot].z
		)
		if singular[slot] > 0.0000001:
			u_cols.append(mixed / singular[slot])
		else:
			u_cols.append(Vector3.ZERO)
	if singular[2] <= 0.0000001:
		var filled := u_cols[0].cross(u_cols[1])
		u_cols[2] = filled.normalized() if filled.length_squared() > 0.0000001 else Vector3.UP
	var right := Basis(v_cols[0], v_cols[1], v_cols[2])
	var rotation := Basis(u_cols[0], u_cols[1], u_cols[2]) * right.transposed()
	if rotation.determinant() < 0.0:
		u_cols[2] = -u_cols[2]
		rotation = Basis(u_cols[0], u_cols[1], u_cols[2]) * right.transposed()
	return rotation.orthonormalized()


func _jacobi(matrix: PackedFloat32Array, values: PackedFloat32Array) -> Array:
	var entries := matrix.duplicate()
	var vectors := [
		[1.0, 0.0, 0.0],
		[0.0, 1.0, 0.0],
		[0.0, 0.0, 1.0],
	]
	for _step in 24:
		var row := 0
		var col := 1
		if absf(entries[2]) > absf(entries[row * 3 + col]):
			row = 0
			col = 2
		if absf(entries[5]) > absf(entries[row * 3 + col]):
			row = 1
			col = 2
		var off: float = entries[row * 3 + col]
		if absf(off) < 0.000000000001:
			break
		var diag_row: float = entries[row * 3 + row]
		var diag_col: float = entries[col * 3 + col]
		var tau := (diag_col - diag_row) / (2.0 * off)
		var tangent := signf(tau) / (absf(tau) + sqrt(1.0 + tau * tau))
		var cosine := 1.0 / sqrt(1.0 + tangent * tangent)
		var sine := tangent * cosine
		for index in 3:
			if index == row or index == col:
				continue
			var left: float = entries[index * 3 + row]
			var right: float = entries[index * 3 + col]
			var turned_left := cosine * left - sine * right
			var turned_right := sine * left + cosine * right
			entries[index * 3 + row] = turned_left
			entries[row * 3 + index] = turned_left
			entries[index * 3 + col] = turned_right
			entries[col * 3 + index] = turned_right
		entries[row * 3 + row] = cosine * cosine * diag_row - 2.0 * sine * cosine * off + sine * sine * diag_col
		entries[col * 3 + col] = sine * sine * diag_row + 2.0 * sine * cosine * off + cosine * cosine * diag_col
		entries[row * 3 + col] = 0.0
		entries[col * 3 + row] = 0.0
		for index in 3:
			var left_vec: float = vectors[index][row]
			var right_vec: float = vectors[index][col]
			vectors[index][row] = cosine * left_vec - sine * right_vec
			vectors[index][col] = sine * left_vec + cosine * right_vec
	values[0] = entries[0]
	values[1] = entries[4]
	values[2] = entries[8]
	return vectors


func _seat_in_hand(prop: Node3D, pos: Vector3, hpr: Vector3, amount: float) -> void:
	var tom := _tom()
	var hand := tom.find_child("def_joint_right_hold", true, false) as Node3D if tom else null
	if hand == null:
		prop.global_position = _hand_point(tom)
		prop.scale = Vector3.ONE * amount
		return
	# The hold joint is still in the Z-up part, so the quest script's Panda
	# position and HPR drop in as local coordinates.
	prop.reparent(hand)
	prop.position = pos
	prop.basis = _panda_hpr(hpr.x, hpr.y, hpr.z)
	prop.scale = Vector3.ONE * amount


## Panda setHpr in Z-up: heading about Z, pitch about X, roll about Y.
func _panda_hpr(heading: float, pitch: float, roll: float) -> Basis:
	var turn := Quaternion(Vector3(0, 0, 1), deg_to_rad(heading))
	var tilt := Quaternion(Vector3(1, 0, 0), deg_to_rad(pitch))
	var twist := Quaternion(Vector3(0, 1, 0), deg_to_rad(roll))
	return Basis(twist * tilt * turn)


func _hand_point(tom: ToonActor) -> Vector3:
	if tom == null:
		return Vector3(1.0, 2.8, -21.6)
	var hand := tom.find_child("def_joint_right_hold", true, false) as Node3D
	if hand:
		return hand.global_position
	return tom.global_position + Vector3(0.45, 2.7, 0.35)


func _flat_icon(texture: Texture2D, at: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = Vector2(70, 70)
	icon.global_position = at - icon.size * 0.5
	icon.z_index = 40
	_hud().add_child(icon)
	return icon


func _present_laff() -> void:
	var view := _view()
	var big := view.y * 0.46
	var small := view.y * 0.15
	var shown := Vector2(view.x * 0.3, view.y * 0.4)
	var dock := LaffMeter.corner(view, small)
	_meter.set_hp(15, 15, true)
	_meter.visible = true
	_meter.place(shown, big)
	_meter.pulse(true)
	await _gesture("rstart", 1.0, false)
	_gesture("rhand", 1.0, true)
	await _line("Oh! You also need a Laff meter!", _BLACK, "")
	await _line("When you run out of Laff, you'll turn sad!", _TEAL, "")
	_expression("sad")
	_meter.pulse(false)
	for current in range(14, -1, -1):
		_meter.set_hp(current, 15, true)
		await get_tree().create_timer(0.07).timeout
	await _line("A happy Toon is a healthy Toon, you know.", _PINK, "")
	_expression("normal")
	_meter.set_hp(15, 15)
	await _gesture("rstart", -2.0, false)
	_clear_gesture()
	var tween := create_tween()
	tween.tween_method(_slide_meter.bind(shown, dock, big, small), 0.0, 1.0, 0.55)
	await tween.finished


func _slide_meter(weight: float, shown: Vector2, dock: Vector2, big: float, small: float) -> void:
	_meter.place(shown.lerp(dock, weight), lerpf(big, small, weight))


func _pan_to_tom() -> void:
	var camera := _host.get_node_or_null("Camera") as Camera3D
	var finish := _cutscene_pose()
	if camera == null or finish == Transform3D.IDENTITY:
		return
	# The follow camera is already behind the player. Ease into the shot
	# instead of cutting. The horizon stays level, and the sine ease has no
	# snap at either end, which is what makes a fast pan feel sick.
	var start := camera.global_transform
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_blend_level.bind(camera, start, finish), 0.0, 1.0, 1.35)
	await tween.finished
	camera.global_transform = finish


func _blend_level(weight: float, camera: Camera3D, start: Transform3D, finish: Transform3D) -> void:
	if camera == null:
		return
	var pos := start.origin.lerp(finish.origin, weight)
	var from := (-start.basis.z).normalized()
	var to := (-finish.basis.z).normalized()
	var fwd := from.slerp(to, weight)
	if fwd.length_squared() < 0.001:
		fwd = to
	var back := -fwd.normalized()
	var side := Vector3.UP.cross(back)
	if side.length_squared() < 0.001:
		return
	side = side.normalized()
	var up := back.cross(side).normalized()
	camera.global_transform = Transform3D(Basis(side, up, back), pos)


func _cutscene_pose() -> Transform3D:
	var camera := _host.get_node_or_null("Camera") as Camera3D
	var tom := _tom()
	if camera == null or tom == null:
		return Transform3D.IDENTITY
	# quest_assign_101 parents the camera to the NPC root, then
	# POS -2.2 5.2 3.3, HPR 215 5 0. Avatar scale lives on the geom, so
	# this offset is not shrunk by Tom's body scale. Panda looks along +Y.
	var panda := _quest_camera_hpr(215.0, 5.0, 0.0)
	var axes := Basis(panda.x, panda.z, -panda.y)
	var local := Vector3(-2.2, 5.2, 3.3)
	var facing := tom.global_basis.orthonormalized()
	var world_basis := (facing * axes).orthonormalized()
	var pos := tom.global_position + facing * local
	# The left edge already cuts the door where it should. Step back along
	# the view so Tom and the rest of the shop sit a little further out.
	var look := (-world_basis.z).normalized()
	pos -= look * 2.0
	var forward := _door_in_frame(camera, pos, look)
	var back := -forward
	var side := Vector3.UP.cross(back)
	if side.length_squared() < 0.001:
		return Transform3D(world_basis, pos)
	side = side.normalized()
	var up := back.cross(side).normalized()
	return Transform3D(Basis(side, up, back), pos)


## Yaw the quest camera left until a little more than half the shop door
## sits inside the left edge of the frame. Position and pitch stay put.
func _door_in_frame(camera: Camera3D, pos: Vector3, forward: Vector3) -> Vector3:
	var door := _interior_door()
	if door == null:
		return forward.normalized()
	var box := _merged_aabb(door)
	if box.size.length_squared() < 0.01:
		return forward.normalized()
	var flat := Vector3(forward.x, 0.0, forward.z)
	var flat_len := flat.length()
	if flat_len < 0.0001:
		return forward.normalized()
	flat /= flat_len
	var right := Vector3(-flat.z, 0.0, flat.x)
	var height := pos.y
	var corners: Array[Vector3] = [
		Vector3(box.position.x, height, box.position.z),
		Vector3(box.position.x, height, box.end.z),
		Vector3(box.end.x, height, box.position.z),
		Vector3(box.end.x, height, box.end.z),
	]
	var left: Vector3 = corners[0]
	var right_edge: Vector3 = corners[0]
	var left_angle := 0.0
	var right_angle := 0.0
	var seen := false
	for corner in corners:
		var offset := corner - pos
		offset.y = 0.0
		if offset.length_squared() < 0.0001:
			continue
		offset = offset.normalized()
		var angle := atan2(offset.dot(right), offset.dot(flat))
		if not seen or angle < left_angle:
			left_angle = angle
			left = corner
		if not seen or angle > right_angle:
			right_angle = angle
			right_edge = corner
		seen = true
	if not seen:
		return forward.normalized()
	# 0.56 of the width, measured from the in-frame edge toward the left edge.
	var clip := right_edge.lerp(left, 0.56)
	var to_clip := clip - pos
	to_clip.y = 0.0
	if to_clip.length_squared() < 0.0001:
		return forward.normalized()
	to_clip = to_clip.normalized()
	var half := deg_to_rad(camera.fov * 0.5)
	if camera.keep_aspect != Camera3D.KEEP_WIDTH:
		var view := camera.get_viewport().get_visible_rect().size
		half = atan(tan(half) * view.x / maxf(view.y, 1.0))
	var clip_right := Vector3(-to_clip.z, 0.0, to_clip.x)
	var aimed := (to_clip * cos(half) + clip_right * sin(half)).normalized()
	var pitch := atan2(forward.y, flat_len)
	return aimed * cos(pitch) + Vector3.UP * sin(pitch)


func _interior_door() -> Node3D:
	var geometry := _host.get_node_or_null("Geometry")
	if geometry == null:
		return null
	return geometry.find_child("door_double_round_ur", true, false) as Node3D


func _merged_aabb(root: Node3D) -> AABB:
	var box := AABB()
	var started := false
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is MeshInstance3D:
			var mesh := node as MeshInstance3D
			if mesh.mesh != null:
				var local := mesh.get_aabb()
				for corner in 8:
					var point: Vector3 = mesh.global_transform * local.get_endpoint(corner)
					if not started:
						box = AABB(point, Vector3.ZERO)
						started = true
					else:
						box = box.expand(point)
		for child in node.get_children():
			pending.append(child as Node)
	return box


## Panda setHpr for this shot: pitch, then heading. The prop helper applies
## heading first, which swings this camera off the poster.
func _quest_camera_hpr(heading: float, pitch: float, roll: float) -> Basis:
	var turn := Quaternion(Vector3(0, 0, 1), deg_to_rad(heading))
	var tilt := Quaternion(Vector3(1, 0, 0), deg_to_rad(pitch))
	var twist := Quaternion(Vector3(0, 1, 0), deg_to_rad(roll))
	return Basis(turn * tilt * twist)


func _show_poster(which: String) -> void:
	if which == "" or not _POSTERS.has(which):
		_poster.visible = false
		return
	var camera := _host.get_node_or_null("Camera") as Camera3D
	if camera:
		# Cards sit on the camera at POS -1.05 7 0. The suits card grows to
		# 1.875 before the first line, which is the size of this quad.
		_poster.reparent(camera)
		_poster.position = Vector3(-1.05, 0.0, -7.0)
		_poster.basis = Basis.IDENTITY
		_poster.scale = Vector3.ONE
	var material := _poster.material_override as StandardMaterial3D
	material.albedo_texture = _POSTERS[which]
	_poster.visible = true


func _build_poster() -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(4.2, 3.25)
	_poster = MeshInstance3D.new()
	_poster.name = "TutorialPoster"
	_poster.mesh = mesh
	_poster.position = Vector3(-1.15, 3.35, -24.85)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_poster.material_override = material
	_poster.visible = false
	_host.add_child(_poster)


func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	_bubble.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_bubble.z_index = 60
	_bubble.visible = false
	_bubble.gui_input.connect(_click_bubble)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.98)
	box.border_color = Color(0.1, 0.1, 0.12)
	box.set_border_width_all(3)
	box.set_corner_radius_all(18)
	box.content_margin_left = 16
	box.content_margin_right = 28
	box.content_margin_top = 10
	box.content_margin_bottom = 12
	_bubble.add_theme_stylebox_override("panel", box)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(420, 0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(_label, _BLACK, 26, Color(0, 0, 0, 0), 0)
	_bubble.add_child(_label)
	_hud().add_child(_bubble)
	ToonGui.attach_next_arrow(_bubble)


func _click_bubble(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_advance = true
		_bubble.accept_event()


func _build_quest() -> void:
	_quest = Control.new()
	_quest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest.visible = false
	_quest.custom_minimum_size = Vector2(280, 220)
	_quest.size = _quest.custom_minimum_size
	var card := TextureRect.new()
	card.texture = _QUEST
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size = _quest.size
	_quest.add_child(card)
	var title := Label.new()
	title.text = "WANTED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(40, 28)
	title.size = Vector2(200, 28)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(title, Color(0.25, 0.16, 0.08), 20, Color(0, 0, 0, 0), 0)
	_quest.add_child(title)
	var mark := Panel.new()
	mark.position = Vector2(24, 36)
	mark.size = Vector2(22, 22)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var red := StyleBoxFlat.new()
	red.bg_color = Color(0.82, 0.16, 0.16)
	red.set_corner_radius_all(11)
	mark.add_theme_stylebox_override("panel", red)
	_quest.add_child(mark)
	var count := Label.new()
	count.text = "1"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.size = mark.size
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(count, Color.WHITE, 14, Color(0, 0, 0), 1)
	mark.add_child(count)
	var who := Label.new()
	who.text = "A Flunky"
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.position = Vector2(40, 108)
	who.size = Vector2(200, 28)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(who, Color(0.22, 0.16, 0.1), 20, Color(0, 0, 0, 0), 0)
	_quest.add_child(who)
	var where := Label.new()
	where.text = "Anywhere"
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	where.position = Vector2(40, 140)
	where.size = Vector2(200, 24)
	where.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(where, Color(0.28, 0.22, 0.14), 16, Color(0, 0, 0, 0), 0)
	_quest.add_child(where)
	_hud().add_child(_quest)


func _hud() -> CanvasLayer:
	return _host.call("hud") as CanvasLayer


func _view() -> Vector2:
	return _host.get_viewport().get_visible_rect().size
