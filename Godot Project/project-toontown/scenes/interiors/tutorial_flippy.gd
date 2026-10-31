class_name TutorialFlippy
extends Node

## tutorial_blocker. Flippy stops the toon in the tunnel and teaches SpeedChat.
## The lines are the ones in the tunnel recording.

const SHIFT_X := -86.09453
const SHIFT_Y := -19.84808
const FEET_Y := 0.05
const FLIPPY_PANDA := Vector3(207.4, 18.81, -0.475)
const FLIPPY_HEADING := 90.0
const PLAYER_PANDA := Vector3(203.8, 18.64, -0.475)
const PLAYER_HEADING := -90.0
const _ARROW := preload("res://assets/gui/tutorial/book/arrow_button.png")
const _BLACK := Color(0.08, 0.08, 0.1)
const _TEAL := Color(0.0, 0.58, 0.64)

var _host: Node
var _flippy: ToonActor
var _camera: Camera3D
var _bubble: PanelContainer
var _label: Label
var _arrows: Array[TextureRect] = []
var _advance := false
var _talking := false
var _running := false
var _music_db := 0.0
var _ducked := false


static func spawn(street: Node3D, host: Node) -> ToonActor:
	var actor := ToonActor.new()
	actor.name = "Flippy"
	street.add_child(actor)
	actor.global_position = _street(FLIPPY_PANDA)
	actor.show_style(_style())
	actor.follows_ground = true
	if host.has_method("face_actor"):
		host.call("face_actor", actor, FLIPPY_HEADING)
	if host.has_method("add_nametag"):
		host.call("add_nametag", actor, "Flippy", Color(0.86, 0.22, 0.12))
	return actor


func play(host: Node, flippy: ToonActor) -> void:
	_host = host
	_flippy = flippy
	_camera = host.get_node_or_null("Camera") as Camera3D
	if host.has_method("set_cutscene"):
		host.call("set_cutscene", true)
	if host.has_method("hold_camera"):
		host.call("hold_camera", true)
	_duck_music()
	if _camera:
		_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_aim_close()
	var toon := _toon()
	if toon:
		toon.visible = false
	_talking = true
	await _line("Why, hello there!", _BLACK)
	await get_tree().create_timer(0.6).timeout
	await _line("Hello?", _TEAL)
	await get_tree().create_timer(0.6).timeout
	_place_player()
	_aim_wide()
	await _line("Oh! You don't know how to use SpeedChat!", _BLACK)
	var chat := _speed()
	if chat != null:
		await chat.present_dock()
	_aim_button()
	_show("Click on the button to say something.", _BLACK)
	if chat != null:
		await chat.menu_opened
	_arrows_off()
	_talking = false
	if chat != null:
		await chat.phrase_said
	_talking = true
	await get_tree().create_timer(0.45).timeout
	await _line("Very good!", _BLACK)
	await _line("Where you're going, there will be plenty of Toons to talk to.", _TEAL)
	_aim_entry()
	await _line("If you want to chat with other Toons using the keyboard, type in the box and press Enter.", _TEAL)
	await _line("This is SpeedChat++. Phrases and typed lines both show up here.", _TEAL)
	_arrows_off()
	await _line("Hope that helps! I have a feeling I'll be seeing you later.", _TEAL)
	_hide_bubble()
	if host.has_method("tasks"):
		var tasks := host.call("tasks") as ToonTasks
		if tasks != null:
			tasks.grant_speedchat()
	if chat != null:
		chat.set_chat_live(true)
	_talking = false
	_running = true
	await _run_off()
	_finish()


func _process(delta: float) -> void:
	if not is_instance_valid(_flippy):
		return
	if _running:
		_flippy.set_locomotion(8.0, false, false, delta)
	elif _talking:
		_flippy.set_dialogue(delta)
	else:
		_flippy.set_locomotion(0.0, false, false, delta)
	_place_bubble()


func _unhandled_input(event: InputEvent) -> void:
	var chat := _speed()
	if chat != null and chat.is_open():
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_advance = true
	elif event.is_action_pressed("ui_accept"):
		_advance = true


func _line(text: String, color: Color) -> void:
	_show(text, color)
	_advance = false
	while not _advance:
		await get_tree().process_frame
	_advance = false


func _show(text: String, color: Color) -> void:
	if _bubble == null:
		_bubble = PanelContainer.new()
		_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bubble.z_index = 20
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1, 1, 1, 0.98)
		box.border_color = Color(0.05, 0.05, 0.05)
		box.set_border_width_all(3)
		box.set_corner_radius_all(16)
		box.content_margin_left = 14
		box.content_margin_right = 28
		box.content_margin_top = 8
		box.content_margin_bottom = 16
		_bubble.add_theme_stylebox_override("panel", box)
		_label = Label.new()
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.custom_minimum_size = Vector2(240, 0)
		ToonGui.style_label(_label, color, 22, Color(0, 0, 0, 0), 0)
		_bubble.add_child(_label)
		_hud().add_child(_bubble)
		ToonGui.attach_next_arrow(_bubble)
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	_bubble.visible = true
	ToonSpeech.speak(_flippy, text)
	_place_bubble()


func _place_bubble() -> void:
	if _bubble == null or _camera == null or not is_instance_valid(_flippy):
		return
	var head := _find(_flippy, "def_head")
	var point := _flippy.global_position + Vector3(0.0, 3.5, 0.0)
	if head:
		point = head.global_position + Vector3(0.15, 0.55, 0.0)
	if _camera.is_position_behind(point):
		_bubble.visible = false
		return
	_bubble.visible = true
	_bubble.reset_size()
	var screen := _camera.unproject_position(point)
	_bubble.position = screen + Vector2(16.0, -_bubble.size.y - 10.0)


func _hide_bubble() -> void:
	if _bubble:
		_bubble.visible = false


func _place_player() -> void:
	var toon := _toon()
	if toon:
		toon.visible = true
	if _host.has_method("place_player"):
		_host.call("place_player", _street(PLAYER_PANDA), PLAYER_HEADING)
	if _host.has_method("face_actor") and is_instance_valid(_flippy):
		_host.call("face_actor", _flippy, FLIPPY_HEADING)


func _aim_close() -> void:
	if _camera == null or not is_instance_valid(_flippy):
		return
	var eyes := _flippy.global_position + Vector3(0.0, 3.15, 0.0)
	var head := _find(_flippy, "def_head")
	if head:
		eyes = head.global_position + Vector3(0.0, 0.12, 0.0)
	var forward := _basis(FLIPPY_HEADING) * Vector3(0, 1, 0)
	_camera.global_position = eyes + forward * 2.45
	_camera.look_at(eyes, Vector3.UP)


func _aim_wide() -> void:
	if _camera == null or not is_instance_valid(_flippy) or _host == null:
		return
	var body := _host.get_node_or_null("Player") as Node3D
	var feet := _flippy.global_position
	if body:
		feet = (body.global_position + _flippy.global_position) * 0.5
	var side := _basis(FLIPPY_HEADING) * Vector3(1, 0, 0)
	_camera.global_position = feet + side * 8.0 + Vector3(0.0, 3.4, 0.0)
	_camera.look_at(feet + Vector3(0.0, 2.1, 0.0), Vector3.UP)


func _run_off() -> void:
	if not is_instance_valid(_flippy):
		return
	_face(270.0)
	await get_tree().create_timer(0.5).timeout
	await _slide(_street(Vector3(217.4, 18.81, -0.475)), 240.0, 0.75)
	await _slide(_street(Vector3(222.4, 15.0, -0.475)), 180.0, 0.35)
	await _slide(_street(Vector3(222.4, 5.0, -0.475)), 180.0, 0.75)
	_flippy.visible = false


func _slide(target: Vector3, heading: float, seconds: float) -> void:
	if not is_instance_valid(_flippy):
		return
	_face(heading)
	var start := _flippy.global_position
	var tween := create_tween()
	tween.tween_method(_along.bind(start, target), 0.0, 1.0, seconds)
	await tween.finished


func _along(t: float, start: Vector3, target: Vector3) -> void:
	if not is_instance_valid(_flippy):
		return
	var next := start.lerp(target, t)
	next.y = _flippy.global_position.y
	_flippy.global_position = next


func _face(heading: float) -> void:
	if _host.has_method("face_actor") and is_instance_valid(_flippy):
		_host.call("face_actor", _flippy, heading)


func _aim_button() -> void:
	var chat := _speed()
	if chat == null:
		return
	_point_at(chat.speed_center())


func _aim_entry() -> void:
	var chat := _speed()
	if chat == null:
		return
	_point_at(chat.entry_center())


func _point_at(at: Vector2) -> void:
	_ensure_arrows()
	if _arrows.size() < 2:
		return
	_point(_arrows[0], at, at + Vector2(78.0, 8.0))
	_point(_arrows[1], at, at + Vector2(6.0, 72.0))


func _arrows_off() -> void:
	for arrow in _arrows:
		arrow.visible = false


func _ensure_arrows() -> void:
	if not _arrows.is_empty():
		return
	_arrows.append(_make_arrow())
	_arrows.append(_make_arrow())


func _make_arrow() -> TextureRect:
	var arrow := TextureRect.new()
	arrow.texture = _ARROW
	arrow.modulate = Color(0.86, 0.08, 0.1)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arrow.size = Vector2(84, 84)
	arrow.pivot_offset = arrow.size * 0.5
	arrow.visible = false
	arrow.z_index = 70
	_hud().add_child(arrow)
	return arrow


func _point(arrow: TextureRect, at: Vector2, park: Vector2) -> void:
	arrow.visible = true
	arrow.global_position = park - arrow.pivot_offset
	arrow.rotation = (at - park).angle() + PI * 0.25


func _finish() -> void:
	_running = false
	_talking = false
	var toon := _toon()
	if toon:
		toon.visible = true
	_arrows_off()
	_hide_bubble()
	for arrow in _arrows:
		arrow.queue_free()
	_arrows.clear()
	if _bubble:
		_bubble.queue_free()
		_bubble = null
	if is_instance_valid(_flippy):
		_flippy.follows_ground = false
		_flippy.queue_free()
	_restore_music()
	if _camera:
		_camera.keep_aspect = Camera3D.KEEP_WIDTH
	if _host != null and _host.has_method("hold_camera"):
		_host.call("hold_camera", false)
	if _host != null and _host.has_method("set_cutscene"):
		_host.call("set_cutscene", false)
	if _host != null and _host.has_method("settle_camera"):
		_host.call("settle_camera")
	queue_free()


func _duck_music() -> void:
	var music := _host.get_node_or_null("ToontorialMusic") as AudioStreamPlayer
	if music == null:
		return
	_music_db = music.volume_db
	_ducked = true
	music.volume_db = linear_to_db(0.4)


func _restore_music() -> void:
	if not _ducked or _host == null:
		return
	var music := _host.get_node_or_null("ToontorialMusic") as AudioStreamPlayer
	if music != null:
		music.volume_db = _music_db
	_ducked = false


func _toon() -> ToonActor:
	if _host == null:
		return null
	var body := _host.get_node_or_null("Player")
	if body == null:
		return null
	for child in body.get_children():
		if child is ToonActor:
			return child as ToonActor
	return null


func _speed() -> SpeedChat:
	if _host != null and _host.has_method("speedchat"):
		return _host.call("speedchat") as SpeedChat
	return null


func _hud() -> Node:
	if _host != null and _host.has_method("hud"):
		var layer := _host.call("hud") as Node
		if layer != null:
			return layer
	return self


static func _street(panda: Vector3) -> Vector3:
	return Vector3(panda.x + SHIFT_X, FEET_Y, -(panda.y + SHIFT_Y))


static func _style() -> ToonStyle:
	# NPCToons 2001: ("dss", "ms", "m", "m", 17, 0, 17, 17, 3, 3, 3, 3, 7, 2)
	var style := ToonStyle.new()
	style.first_name = "Flippy"
	style.gender = "m"
	style.head = "dss"
	style.torso = "ms"
	style.legs = "m"
	style.arm_color = 17
	style.glove_color = 0
	style.leg_color = 17
	style.head_color = 17
	style.top_tex = 3
	style.top_color = 3
	style.bot_tex = 7
	style.bot_color = 2
	return style


func _basis(heading: float) -> Basis:
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	return upright.rotated(Vector3.UP, deg_to_rad(heading))


func _find(node: Node, wanted: String) -> Node3D:
	if node != null and node.name == wanted and node is Node3D:
		return node as Node3D
	if node == null:
		return null
	for child in node.get_children():
		var found := _find(child, wanted)
		if found:
			return found
	return null
