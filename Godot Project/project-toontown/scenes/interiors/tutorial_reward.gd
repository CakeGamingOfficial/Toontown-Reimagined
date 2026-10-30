extends Node

## Movie.playTutorialReward_3. After the gag points and the finished ToonTask,
## Tutorial Tom meets the player in front of Toon Headquarters, then leaves
## through a hole. Control comes back with the player facing the doors.

const ZONE_PATH := "res://assets/neighborhoods/tutorial_zone/tutorial_zone.glb"
# export_neighborhoods centered tutorial_street.dna. tb1's child keeps the DNA
# position, and that node's world origin fixes the shift.
const SHIFT_X := -86.09453
const SHIFT_Y := -19.84808
const PLAYER_PANDA := Vector3(40.31, 22.0, -0.47)
const PLAYER_HEADING := 150.0
const TOM_PANDA := Vector3(40.29, 17.9, -0.47)
const TOM_HEADING := 11.31
const CAMERA_PANDA := Vector3(34.0, 19.88, 3.48)
const HQ_PANDA := Vector3(100.0, 20.0, 0.0)
const FACING_HQ := 270.0
const FEET_Y := 0.05
const _BLACK := Color(0.08, 0.08, 0.1)
const _TEAL := Color(0.0, 0.55, 0.62)

var _host: Node
var _body: CharacterBody3D
var _player: ToonActor
var _camera: Camera3D
var _tom: ToonActor
var _pivot: Node3D
var _hole: MeshInstance3D
var _bubble: PanelContainer
var _label: Label
var _advance := false


func _process(delta: float) -> void:
	if is_instance_valid(_tom):
		_tom.set_locomotion(0.0, false, false, delta)
	# The street keeps the player locked for the movie, so the body never gets
	# an idle tick. The head still blinks on its own.
	if is_instance_valid(_player):
		_player.set_locomotion(0.0, false, false, delta)


func play(host: Node, body: CharacterBody3D, player: ToonActor, camera: Camera3D) -> void:
	_host = host
	_body = body
	_player = player
	_camera = camera
	var fade := _fade_rect()
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.28)
	await tween.finished
	_show_plaza()
	_stand_cast()
	_aim_wide()
	var back := create_tween()
	back.tween_property(fade, "color:a", 0.0, 0.35)
	await back.finished
	fade.queue_free()
	await _pop_in()
	await _line("Good job! You completed your first ToonTask!", _BLACK, true)
	await _line("Go to Toon Headquarters for your reward!", _TEAL, false)
	await _send_off()
	if _camera:
		_camera.keep_aspect = Camera3D.KEEP_WIDTH
	if _host.has_method("settle_camera"):
		_host.call("settle_camera")


func _show_plaza() -> void:
	var host := _host as Node3D
	if host == null:
		return
	if host.get_node_or_null("TutorialStreet") == null:
		var packed := load(ZONE_PATH) as PackedScene
		if packed != null:
			var zone := packed.instantiate()
			zone.name = "TutorialStreet"
			host.add_child(zone)
			_hide_named(zone, "sky")
			if _host.has_method("adopt_billboards"):
				_host.call("adopt_billboards", zone)
			if _host.has_method("close_landmark_doors"):
				_host.call("close_landmark_doors", zone)
	var interior := host.get_node_or_null("Geometry") as Node3D
	if interior:
		interior.visible = false
	if _host.has_method("quiet_shop_speech"):
		_host.call("quiet_shop_speech")
	var shop_tom := host.get_node_or_null("Tutorial Tom") as Node3D
	if shop_tom:
		shop_tom.visible = false
	var flunky := host.get_node_or_null("Flunky") as Node3D
	if flunky:
		flunky.visible = false
	if _host.has_method("open_plaza"):
		_host.call("open_plaza")
	if _host.has_method("lay_ground"):
		_host.call("lay_ground", "res://assets/neighborhoods/tutorial_zone/street_floor.json", 0.0, "PlazaFloor")
	if _host.has_method("add_solid"):
		_host.call("add_solid", "res://assets/neighborhoods/tutorial_zone/street_walls.json", "PlazaWalls")
	var feet := _street(PLAYER_PANDA)
	if _host.has_method("note_plaza"):
		_host.call("note_plaza", feet, FACING_HQ)
	if _host.has_method("prepare_hq"):
		_host.call("prepare_hq")


func _stand_cast() -> void:
	var feet := _street(PLAYER_PANDA)
	_host.call("place_player", feet, PLAYER_HEADING)
	var host := _host as Node3D
	_pivot = Node3D.new()
	_pivot.name = "RewardTomPivot"
	_pivot.position = _street(TOM_PANDA) + Vector3(0.0, -1.15, 0.0)
	_pivot.scale = Vector3(0.12, 0.12, 0.12)
	host.add_child(_pivot)
	# A second Tom. The shop actor keeps the interior greeting.
	_tom = ToonActor.new()
	_tom.name = "Street Tom"
	_pivot.add_child(_tom)
	_tom.show_style(_tom_style())
	_host.call("face_actor", _tom, TOM_HEADING)
	_hole = MeshInstance3D.new()
	_hole.name = "RewardHole"
	var disc := CylinderMesh.new()
	disc.top_radius = 1.15
	disc.bottom_radius = 1.15
	disc.height = 0.08
	_hole.mesh = disc
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.02, 0.02, 0.02)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.disable_receive_shadows = true
	_hole.material_override = material
	_hole.position = _street(TOM_PANDA) + Vector3(0.0, 0.04, 0.0)
	_hole.scale = Vector3(0.2, 1.0, 0.2)
	host.add_child(_hole)


func _pop_in() -> void:
	var risen := create_tween()
	risen.set_parallel(true)
	risen.tween_property(_pivot, "position:y", FEET_Y, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	risen.tween_property(_pivot, "scale", Vector3.ONE, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	risen.tween_property(_hole, "scale", Vector3(1.0, 1.0, 1.0), 0.35)
	await risen.finished
	var shut := create_tween()
	shut.tween_property(_hole, "scale", Vector3(0.05, 1.0, 0.05), 0.25)
	await shut.finished


func _line(text: String, color: Color, warm: bool) -> void:
	_show_bubble(text, color)
	_advance = false
	var catcher := ColorRect.new()
	catcher.color = Color(0, 0, 0, 0)
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.gui_input.connect(_on_catcher)
	_hud().add_child(catcher)
	var waited := 0.0
	while not _advance:
		_place_bubble()
		if warm and waited >= 0.45 and _label:
			_label.add_theme_color_override("font_color", _TEAL)
		if Input.is_action_just_pressed("ui_accept"):
			_advance = true
		waited += get_process_delta_time()
		await get_tree().process_frame
	catcher.queue_free()
	_advance = false


func _on_catcher(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_advance = true


func _send_off() -> void:
	_show_bubble("Have fun!", _BLACK)
	var shown := 0.0
	while shown < 0.9:
		_place_bubble()
		shown += get_process_delta_time()
		await get_tree().process_frame
	_host.call("face_actor", _player, FACING_HQ)
	_host.call("face_actor", _tom, FACING_HQ)
	var from_at := _camera.global_position
	var from_look := _street(HQ_PANDA) + Vector3(0.0, 6.2, 0.0)
	var behind := _behind_pair()
	var to_at: Vector3 = behind["at"]
	var to_look: Vector3 = behind["look"]
	var hop := 0.0
	while hop < 0.45:
		var weight := hop / 0.45
		_camera.global_position = from_at.lerp(to_at, weight)
		_camera.look_at(from_look.lerp(to_look, weight), Vector3.UP)
		_pivot.position.y = lerpf(FEET_Y, 2.55, 1.0 - pow(1.0 - weight, 2.0))
		var disc := lerpf(0.15, 1.2, minf(weight * 1.6, 1.0))
		_hole.scale = Vector3(disc, 1.0, disc)
		_place_bubble()
		hop += get_process_delta_time()
		await get_tree().process_frame
	var drop := 0.0
	while drop < 0.5:
		var weight := drop / 0.5
		_pivot.position.y = lerpf(2.55, -1.25, weight * weight)
		var shrunk := lerpf(1.0, 0.08, weight)
		_pivot.scale = Vector3(shrunk, shrunk, shrunk)
		_camera.look_at(to_look, Vector3.UP)
		_place_bubble()
		drop += get_process_delta_time()
		await get_tree().process_frame
	if _bubble:
		_bubble.queue_free()
		_bubble = null
	var close := 0.0
	while close < 0.3:
		var disc := lerpf(1.2, 0.02, close / 0.3)
		_hole.scale = Vector3(disc, 1.0, disc)
		close += get_process_delta_time()
		await get_tree().process_frame
	_hole.queue_free()
	_pivot.queue_free()
	_tom = null
	var follow := _follow_camera()
	var settle_from := _camera.global_position
	var settle_look := to_look
	var settle := 0.0
	while settle < 0.45:
		var weight := settle / 0.45
		_camera.global_position = settle_from.lerp(follow["at"], weight)
		_camera.look_at(settle_look.lerp(follow["look"], weight), Vector3.UP)
		settle += get_process_delta_time()
		await get_tree().process_frame


func _behind_pair() -> Dictionary:
	var mid := (_body.global_position + _pivot.global_position) * 0.5
	mid.y = FEET_Y
	return {
		"at": mid + Vector3(-6.4, 2.7, 0.2),
		"look": _street(HQ_PANDA) + Vector3(0.0, 4.8, 0.0),
	}


func _follow_camera() -> Dictionary:
	var feet := _body.global_position
	var height := 3.0
	var head := _find(_player, "def_head")
	if head:
		height = maxf(head.global_position.y - feet.y, 3.0)
	var forward := Vector3(1.0, 0.0, 0.0)
	var eye := feet + Vector3(0.0, height, 0.0)
	return {
		"at": eye - forward * 9.0 * (height / 3.0),
		"look": eye + forward * 1.5,
	}


func _aim_wide() -> void:
	if _camera == null:
		return
	var panda := CAMERA_PANDA
	# The play window is wide. Keep the vertical field at 52 degrees, the way
	# the original lens does, or the toons are cropped down to their heads.
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.global_position = Vector3(panda.x + SHIFT_X, FEET_Y + 3.95, -(panda.y + SHIFT_Y))
	_camera.look_at(_street(HQ_PANDA) + Vector3(0.0, 3.4, 0.0), Vector3.UP)


func _show_bubble(text: String, color: Color) -> void:
	if _bubble == null:
		_bubble = PanelContainer.new()
		_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1, 1, 1, 0.98)
		box.border_color = Color(0.05, 0.05, 0.05)
		box.set_border_width_all(3)
		box.set_corner_radius_all(14)
		box.content_margin_left = 14
		box.content_margin_right = 18
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		_bubble.add_theme_stylebox_override("panel", box)
		_label = Label.new()
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.custom_minimum_size = Vector2(230, 0)
		ToonGui.style_label(_label, color, 22, Color(0, 0, 0, 0), 0)
		_bubble.add_child(_label)
		_hud().add_child(_bubble)
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	_place_bubble()


func _place_bubble() -> void:
	if _bubble == null or _camera == null or _tom == null:
		return
	var head := _find(_tom, "def_head")
	var point := _tom.global_position + Vector3(0.0, 3.4, 0.0)
	if head:
		point = head.global_position + Vector3(0.0, 0.55, 0.0)
	if _camera.is_position_behind(point):
		_bubble.visible = false
		return
	_bubble.visible = true
	_bubble.reset_size()
	var screen := _camera.unproject_position(point)
	_bubble.position = screen + Vector2(18.0, -_bubble.size.y - 8.0)


func _street(panda: Vector3) -> Vector3:
	return Vector3(panda.x + SHIFT_X, FEET_Y, -(panda.y + SHIFT_Y))


func _fade_rect() -> ColorRect:
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud().add_child(fade)
	return fade


func _hud() -> CanvasLayer:
	return _host.call("hud") as CanvasLayer


func _tom_style() -> ToonStyle:
	var style := ToonStyle.new()
	style.first_name = "Tutorial"
	style.last_name = "Tom"
	style.gender = "m"
	style.head = "dls"
	style.torso = "ms"
	style.legs = "m"
	style.arm_color = 7
	style.glove_color = 0
	style.leg_color = 7
	style.head_color = 7
	style.top_tex = 2
	style.top_color = 6
	style.bot_tex = 2
	style.bot_color = 16
	return style


func _hide_named(node: Node, piece: String) -> void:
	if piece in node.name.to_lower():
		if node is Node3D:
			(node as Node3D).visible = false
		return
	for child in node.get_children():
		_hide_named(child, piece)


func _find(node: Node, wanted: String) -> Node3D:
	if node != null and String(node.name) == wanted and node is Node3D:
		return node as Node3D
	if node == null:
		return null
	for child in node.get_children():
		var found := _find(child, wanted)
		if found:
			return found
	return null
