class_name TutorialHarry
extends Node

## quest_assign_110. Harry's reward for the Flunky, matching the tutorial
## recording: the book button flies to the corner, then he walks the pages
## for the map, the gags, and the new trolley ToonTask.

const _ARROW := preload("res://assets/gui/tutorial/book/arrow_button.png")
const _BLACK := Color(0.08, 0.08, 0.1)
const _TEAL := Color(0.0, 0.58, 0.64)
const _NAME := Color(0.86, 0.22, 0.12)

var _host: Node
var _harry: ToonActor
var _running := false
var _waiting := false
var _advance := false
var _ducked := false
var _music_db := 0.0
var _arrow_mode := ""
var _world: PanelContainer
var _world_label: Label
var _world_arrow: Label
var _chat: Control
var _chat_label: Label
var _chat_arrow: Label
var _arrows: Array[TextureRect] = []


func play(host: Node, harry: ToonActor) -> void:
	_host = host
	_harry = harry
	_running = true
	_host.call("set_cutscene", true)
	_host.call("hold_camera", true)
	_build_world_bubble()
	_frame()
	_face_player()
	var tasks := _tasks()
	if tasks != null and tasks.book_ready():
		_finish()
		return
	if tasks == null or not tasks.is_complete(101):
		await _world_line("Looks like you still have more work to do on that task!", _BLACK)
		_finish()
		return
	_duck_music()
	await _world_line("Good work defeating that Flunky. Let me give you your reward...", _BLACK)
	await _offer_hand()
	var book := _book()
	if book != null:
		await book.present_button()
	await _world_line("This book, a Shticker Book, is full of good stuff.", _TEAL)
	_aim_button()
	_show_world("Open it and I'll show you a couple of useful pages.", _BLACK, false)
	if book != null:
		book.arm_open()
		if not book.is_open():
			await book.book_opened
	_arrows_off()
	_hide_world()
	await _lower_hand()
	await get_tree().create_timer(0.5).timeout
	await _build_book_chat()
	await _book_line("This is a map of Toontown! It'll keep track of where you have been.", _BLACK)
	_aim_page()
	_show_book("Turn the page to see those gags that Tom gave you.", _BLACK, false)
	if book != null:
		book.arm_next()
		await _wait_page(book, 2)
	_arrows_off()
	await _book_line("Yikes! You have no gags! I'll assign you a task...", _TEAL)
	if tasks != null:
		tasks.turn_in(101)
	_aim_page()
	_show_book("Turn the page to see your ToonTasks.", _TEAL, false)
	if book != null:
		book.arm_next()
		await _wait_page(book, 3)
	_arrows_off()
	await _book_line("Here you go! Take a ride on the Trolley to buy yourself a few new gags.", _TEAL)
	await _book_line("To get to the Trolley, go out the door behind me and head for the playground.", _TEAL)
	_aim_button()
	_show_book("I'd love to show you more, but no Toon should be without gags for too long! Close the book and you can head out.", _BLACK, false)
	if book != null:
		book.arm_close()
		await book.book_closed
	_arrows_off()
	_hide_book()
	await _world_line("There is another Toon HQ in Toontown Central where you can turn in your task once complete. Good luck!", _BLACK)
	_finish()


func _process(delta: float) -> void:
	if not _running:
		return
	if _waiting and Input.is_action_just_pressed("ui_accept"):
		_advance = true
	if _harry != null:
		_harry.set_dialogue(delta)
	_place_world_bubble()
	_place_book_chat()
	if _arrow_mode == "button":
		_aim_button()
	elif _arrow_mode == "page":
		_aim_page()


func _unhandled_input(event: InputEvent) -> void:
	if not _waiting:
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_advance = true
	elif event.is_action_pressed("ui_accept"):
		_advance = true


func _finish() -> void:
	_running = false
	_waiting = false
	_arrow_mode = ""
	_hide_world()
	_hide_book()
	_arrows_off()
	if _world != null:
		_world.queue_free()
		_world = null
	if _chat != null:
		_chat.queue_free()
		_chat = null
	for arrow in _arrows:
		arrow.queue_free()
	_arrows.clear()
	if _harry != null:
		_harry.clear_gesture()
		_harry.set_locomotion(0.0, false, false, 0.05)
	_restore_music()
	if _host != null:
		_host.call("hold_camera", false)
		_host.call("set_cutscene", false)


func _world_line(text: String, color: Color) -> void:
	_show_world(text, color, true)
	await _confirm()
	_hide_world()


func _book_line(text: String, color: Color) -> void:
	_show_book(text, color, true)
	await _confirm()


func _confirm() -> void:
	_waiting = true
	_advance = false
	var book := _book()
	if book != null and book.is_open():
		book.let_clicks_through(true)
	while not _advance:
		await get_tree().process_frame
	_advance = false
	_waiting = false
	if book != null:
		book.let_clicks_through(false)


func _wait_page(book: ShtickerBook, index: int) -> void:
	while book.page() != index:
		await book.page_ready


func _offer_hand() -> void:
	if _harry == null:
		return
	_harry.play_gesture("rstart", 1.8, false)
	while is_instance_valid(_harry) and not _harry.gesture_finished():
		await get_tree().process_frame
	if is_instance_valid(_harry):
		_harry.play_gesture("rhand", 1.0, true)


func _lower_hand() -> void:
	if _harry == null:
		return
	_harry.play_gesture("rstart", -1.5, false)
	while is_instance_valid(_harry) and not _harry.gesture_finished():
		await get_tree().process_frame
	if is_instance_valid(_harry):
		_harry.clear_gesture()
		_harry.set_locomotion(0.0, false, false, 0.05)


func _frame() -> void:
	var camera := _camera()
	if camera == null or _harry == null:
		return
	# DistributedNPCToon.setupCamera, the quest-movie side: (-5, 9, height - 0.5).
	var forward := _forward(180.0)
	var right := _right(180.0)
	var height := 4.2
	var head := _find(_harry, "def_head")
	if head:
		height = maxf(head.global_position.y - _harry.global_position.y, 3.0)
	var eyes := _harry.global_position + Vector3(0.0, height - 0.5, 0.0)
	camera.global_position = _harry.global_position + right * -5.0 + forward * 9.0 + Vector3(0.0, height - 0.5, 0.0)
	camera.look_at(eyes, Vector3.UP)


func _face_player() -> void:
	var body := _host.get_node_or_null("Player") as Node3D
	if body == null or _harry == null:
		return
	var actor: ToonActor = null
	for child in body.get_children():
		if child is ToonActor:
			actor = child as ToonActor
			break
	if actor == null:
		return
	var to := _harry.global_position - actor.global_position
	var heading := rad_to_deg(atan2(-to.x, -to.z))
	if _host.has_method("face_actor"):
		_host.call("face_actor", actor, heading)


func _tasks() -> ToonTasks:
	if _host == null or not _host.has_method("tasks"):
		return null
	return _host.call("tasks") as ToonTasks


func _book() -> ShtickerBook:
	if _host == null or not _host.has_method("shticker"):
		return null
	return _host.call("shticker") as ShtickerBook


func _camera() -> Camera3D:
	if _host == null:
		return null
	return _host.get_node_or_null("Camera") as Camera3D


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


func _build_world_bubble() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	panel.z_index = 30
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.98)
	box.border_color = Color(0, 0, 0)
	box.set_border_width_all(3)
	box.set_corner_radius_all(18)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 10
	box.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	_world_label = Label.new()
	_world_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_world_label.custom_minimum_size = Vector2(280, 0)
	_world_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(_world_label, _BLACK, 22, Color(0, 0, 0, 0), 0)
	column.add_child(_world_label)
	_world_arrow = Label.new()
	_world_arrow.text = "►"
	_world_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_world_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(_world_arrow, Color(0.15, 0.45, 0.9), 16, Color(0, 0, 0, 0), 0)
	column.add_child(_world_arrow)
	_hud().add_child(panel)
	_world = panel


func _show_world(text: String, color: Color, confirm: bool) -> void:
	_hide_book()
	_world_label.text = text
	_world_label.add_theme_color_override("font_color", color)
	_world_arrow.visible = confirm
	_world.visible = true


func _hide_world() -> void:
	if _world != null:
		_world.visible = false


func _place_world_bubble() -> void:
	if _world == null or not _world.visible or _harry == null:
		return
	var camera := _camera()
	if camera == null:
		_world.visible = false
		return
	var point := _harry.global_position + Vector3(0.35, 4.8, 0.0)
	if camera.is_position_behind(point):
		_world.visible = false
		return
	_world.visible = true
	_world.reset_size()
	var screen := camera.unproject_position(point)
	_world.position = screen + Vector2(28.0, -_world.size.y - 16.0)


func _build_book_chat() -> void:
	var book := _book()
	if book == null:
		return
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	panel.z_index = 40
	var plate := Panel.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	var plate_box := StyleBoxFlat.new()
	plate_box.bg_color = Color(0.99, 0.97, 0.75)
	plate_box.border_color = Color(0.2, 0.62, 0.28)
	plate_box.set_border_width_all(6)
	plate_box.set_corner_radius_all(12)
	plate.add_theme_stylebox_override("panel", plate_box)
	panel.add_child(plate)
	var portrait := await _portrait()
	portrait.position = Vector2(10, 16)
	portrait.size = Vector2(96, 96)
	panel.add_child(portrait)
	var name := Label.new()
	name.text = "HQ Harry"
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.position = Vector2(116, 8)
	name.size = Vector2(220, 24)
	ToonGui.style_label(name, _NAME, 16, Color(0, 0, 0, 0), 0)
	panel.add_child(name)
	var bubble := PanelContainer.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.position = Vector2(116, 34)
	var bubble_box := StyleBoxFlat.new()
	bubble_box.bg_color = Color(1, 1, 1, 0.98)
	bubble_box.border_color = Color(0, 0, 0)
	bubble_box.set_border_width_all(3)
	bubble_box.set_corner_radius_all(14)
	bubble_box.content_margin_left = 12
	bubble_box.content_margin_right = 12
	bubble_box.content_margin_top = 8
	bubble_box.content_margin_bottom = 6
	bubble.add_theme_stylebox_override("panel", bubble_box)
	panel.add_child(bubble)
	bubble.name = "Speech"
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(column)
	_chat_label = Label.new()
	_chat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(_chat_label, _BLACK, 18, Color(0, 0, 0, 0), 0)
	column.add_child(_chat_label)
	_chat_arrow = Label.new()
	_chat_arrow.text = "►"
	_chat_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_chat_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(_chat_arrow, Color(0.15, 0.45, 0.9), 14, Color(0, 0, 0, 0), 0)
	column.add_child(_chat_arrow)
	book.add_child(panel)
	_chat = panel


func _portrait() -> TextureRect:
	var port := SubViewport.new()
	port.name = "HarryHead"
	port.own_world_3d = true
	port.transparent_bg = true
	port.size = Vector2i(180, 180)
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(port)
	var world := Node3D.new()
	port.add_child(world)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1, 1, 1)
	environment.ambient_light_energy = 1.2
	env.environment = environment
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28.0, 35.0, 0.0)
	world.add_child(sun)
	var actor := ToonActor.new()
	world.add_child(actor)
	actor.show_style(_harry_style())
	var cam := Camera3D.new()
	cam.fov = 26.0
	world.add_child(cam)
	await get_tree().process_frame
	var focus := actor.global_position + Vector3(0.0, 3.3, 0.0)
	var head := _find(actor, "def_head")
	if head:
		focus = head.global_position
	# show_style turns the toon to face +Z, the Make a Toon camera.
	cam.global_position = focus + Vector3(0.0, 0.12, 2.15)
	cam.look_at(focus, Vector3.UP)
	cam.current = true
	var picture := TextureRect.new()
	picture.texture = port.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture


func _harry_style() -> ToonStyle:
	var style := ToonStyle.new()
	style.first_name = "HQ"
	style.last_name = "Harry"
	style.gender = "m"
	style.head = "dls"
	style.torso = "ms"
	style.legs = "m"
	style.arm_color = 6
	style.glove_color = 0
	style.leg_color = 6
	style.head_color = 6
	style.top_tex = 0
	style.top_color = 10
	style.bot_tex = 2
	style.bot_color = 9
	return style


func _show_book(text: String, color: Color, confirm: bool) -> void:
	_hide_world()
	if _chat == null:
		return
	_chat_label.text = text
	_chat_label.add_theme_color_override("font_color", color)
	_chat_arrow.visible = confirm
	_chat.visible = true
	_place_book_chat()


func _hide_book() -> void:
	if _chat != null:
		_chat.visible = false


func _place_book_chat() -> void:
	if _chat == null or not _chat.visible:
		return
	var book := _book()
	if book == null:
		return
	var rect := book.cover_rect()
	_chat.global_position = rect.position + Vector2(rect.size.x * 0.04, rect.size.y * 0.62)
	_chat.size = Vector2(rect.size.x * 0.58, rect.size.y * 0.32)
	var bubble := _chat.get_node_or_null("Speech") as Control
	if bubble == null:
		return
	bubble.position = Vector2(116, 34)
	bubble.size = Vector2(maxf(_chat.size.x - 128.0, 80.0), maxf(_chat.size.y - 46.0, 40.0))


func _aim_button() -> void:
	var book := _book()
	if book == null:
		return
	book.arm_open()
	_ensure_arrows(book)
	if _arrows.size() < 2:
		return
	_arrow_mode = "button"
	var at := book.button_center()
	_point(_arrows[0], at, at + Vector2(-130.0, 18.0))
	_point(_arrows[1], at, at + Vector2(-48.0, -96.0))


func _aim_page() -> void:
	var book := _book()
	if book == null:
		return
	_ensure_arrows(book)
	if _arrows.is_empty():
		return
	_arrow_mode = "page"
	var at := book.turn_center()
	_point(_arrows[0], at, at + Vector2(6.0, 84.0))
	_arrows[1].visible = false


func _arrows_off() -> void:
	_arrow_mode = ""
	for arrow in _arrows:
		arrow.visible = false


func _ensure_arrows(book: ShtickerBook) -> void:
	if not _arrows.is_empty():
		return
	_arrows.append(_make_arrow(book))
	_arrows.append(_make_arrow(book))


func _make_arrow(book: ShtickerBook) -> TextureRect:
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
	book.add_child(arrow)
	return arrow


func _point(arrow: TextureRect, at: Vector2, park: Vector2) -> void:
	arrow.visible = true
	arrow.global_position = park - arrow.pivot_offset
	# The picture's tip sits up and to the right, which is -45 degrees.
	arrow.rotation = (at - park).angle() + PI * 0.25


func _hud() -> Node:
	if _host != null and _host.has_method("hud"):
		var layer := _host.call("hud") as Node
		if layer != null:
			return layer
	return self


func _forward(heading: float) -> Vector3:
	return _basis(heading) * Vector3(0, 1, 0)


func _right(heading: float) -> Vector3:
	return _basis(heading) * Vector3(1, 0, 0)


func _basis(heading: float) -> Basis:
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	return upright.rotated(Vector3.UP, deg_to_rad(heading))


func _find(node: Node, wanted: String) -> Node3D:
	if node.name == wanted and node is Node3D:
		return node as Node3D
	for child in node.get_children():
		var found := _find(child, wanted)
		if found:
			return found
	return null
