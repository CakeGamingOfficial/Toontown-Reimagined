class_name CogPanel
extends Control

## SuitAvatarPanel. Clicking a cog nametag opens phase_3.5 suit_detail_panel
## at (1.1, 0, 0.525). The head is the cog's own head parts, turned to face
## the card. Close is the black suit-font word at the bottom.

const _CARD := preload("res://assets/gui/cogs/suit_panel.png")
const _CORP := preload("res://assets/gui/cogs/CorpIcon.png")
const _SALES := preload("res://assets/gui/cogs/SalesIcon.png")
const _LEGAL := preload("res://assets/gui/cogs/LegalIcon.png")
const _MONEY := preload("res://assets/gui/cogs/MoneyIcon.png")
const _FRIEND_UP := preload("res://assets/gui/friends/Frnds_Btn_UP.png")
const _FRIEND_DOWN := preload("res://assets/gui/friends/Frnds_Btn_DN.png")
const _FRIEND_HOVER := preload("res://assets/gui/friends/Frnds_Btn_RLVR.png")

# suit_detail_panel avatar_panel bounds, then geom_scale 0.21 and geom_pos z 0.02.
const _FRAME := Vector2(1.1, 0.525)
const _CARD_SIZE := Vector2(2.4, 4.4) * 0.21
const _CARD_SHIFT := Vector2(-0.1, -0.1) * 0.21 + Vector2(0.0, 0.02)
const _BODY := ["legs", "hands", "torso", "arms", "node", "CorpIcon"]

var _open := false
var _actor: Cog
var _dept := "c"
var _card: TextureRect
var _head_port: SubViewport
var _head_view: TextureRect
var _stage: Node3D
var _head: Node3D
var _camera: Camera3D
var _name_label: Label
var _level_label: Label
var _dept_label: Label
var _icon: TextureRect
var _close: Button
var _friend: TextureButton
var _friend_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	z_index = 30
	_build()
	var view := get_viewport()
	if not view.size_changed.is_connected(_layout):
		view.size_changed.connect(_layout)
	_layout()


func _process(_delta: float) -> void:
	if not _open:
		return
	if _filming() or not is_instance_valid(_actor):
		hide_panel()


func show_cog(actor: Cog, cog_name: String, dept: String) -> void:
	_actor = actor
	_dept = dept
	_open = true
	visible = true
	_name_label.text = cog_name
	_level_label.text = "Level: %d" % actor.cog_level
	_dept_label.text = Cog.dept_name(dept)
	_icon.texture = _icon_for(dept)
	_icon.modulate = Cog.medallion_color(dept)
	_mount_head(actor)
	_obscure_friends(true)
	_layout()


func hide_panel() -> void:
	if not _open and not visible:
		return
	_open = false
	visible = false
	_clear_head()
	_obscure_friends(false)


func _unhandled_input(event: InputEvent) -> void:
	if not _open or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE:
		hide_panel()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_card = TextureRect.new()
	_card.texture = _CARD
	_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card.stretch_mode = TextureRect.STRETCH_SCALE
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)
	_head_port = SubViewport.new()
	_head_port.transparent_bg = true
	_head_port.own_world_3d = true
	_head_port.size = Vector2i(384, 384)
	_head_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_head_port)
	_stage = Node3D.new()
	_head_port.add_child(_stage)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.9
	world.environment = env
	_stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.3
	_stage.add_child(key)
	_head = Node3D.new()
	_stage.add_child(_head)
	_camera = Camera3D.new()
	_camera.fov = 32.0
	_camera.current = true
	_stage.add_child(_camera)
	_head_view = TextureRect.new()
	_head_view.texture = _head_port.get_texture()
	_head_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_head_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_head_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_head_view)
	_name_label = _suit_label()
	_level_label = _suit_label()
	_dept_label = _suit_label()
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_close = Button.new()
	_close.text = "Close"
	_close.flat = true
	_close.focus_mode = Control.FOCUS_NONE
	_close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close.pressed.connect(hide_panel)
	ToonGui.button_sounds(_close)
	var empty := StyleBoxEmpty.new()
	_close.add_theme_stylebox_override("normal", empty)
	_close.add_theme_stylebox_override("hover", empty)
	_close.add_theme_stylebox_override("pressed", empty)
	_close.add_theme_stylebox_override("focus", empty)
	add_child(_close)
	# ToonAvatarPanel's Friends button. Same art as the friends list's add-a-toon button.
	_friend = TextureButton.new()
	_friend.texture_normal = _FRIEND_UP
	_friend.texture_pressed = _FRIEND_DOWN
	_friend.texture_hover = _FRIEND_HOVER
	_friend.ignore_texture_size = true
	_friend.stretch_mode = TextureButton.STRETCH_SCALE
	_friend.focus_mode = Control.FOCUS_NONE
	_friend.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_friend.pressed.connect(_ask_friend)
	_friend.mouse_entered.connect(func() -> void: _paint_friend(Color(1, 1, 0.5)))
	_friend.mouse_exited.connect(func() -> void: _paint_friend(Color.WHITE))
	_friend.button_down.connect(func() -> void: _paint_friend(Color(0.5, 1, 0.5)))
	_friend.button_up.connect(func() -> void: _paint_friend(Color(1, 1, 0.5)))
	ToonGui.button_sounds(_friend)
	add_child(_friend)
	_friend_label = Label.new()
	_friend_label.text = "Friends"
	_friend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_friend_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_friend_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_friend_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_friend_label.gui_input.connect(_on_friend_label)
	_friend_label.mouse_entered.connect(func() -> void: _paint_friend(Color(1, 1, 0.5)))
	_friend_label.mouse_exited.connect(func() -> void: _paint_friend(Color.WHITE))
	add_child(_friend_label)


func _suit_label() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.y < 2.0:
		return
	var edge := view.x / view.y
	var frame_x := maxf(_FRAME.x, edge - 0.02 - _CARD_SIZE.x * 0.5 - _CARD_SHIFT.x)
	var frame := Vector2(frame_x, _FRAME.y)
	ToonGui.place(_card, view, frame.x + _CARD_SHIFT.x, frame.y + _CARD_SHIFT.y, _CARD_SIZE.x, _CARD_SIZE.y)
	# The head sits on the frame origin. SuitAvatarPanel scales it so its
	# longest side is 0.3.
	_place(view, frame, _head_view, 0.0, 0.02, 0.3, 0.3)
	_place(view, frame, _name_label, 0.0125, 0.36, 0.36, 0.1)
	_place(view, frame, _level_label, 0.0, -0.1, 0.4, 0.07)
	_place(view, frame, _icon, 0.0, -0.175, 0.139, 0.139)
	_place(view, frame, _dept_label, 0.0, -0.28, 0.4, 0.07)
	_place(view, frame, _close, 0.0, -0.36, 0.28, 0.07)
	# Sits in the gap under the name. text_pos (0.06, -0.02), left aligned, like the toon card.
	_place(view, frame, _friend, -0.103, 0.24, 0.09, 0.09)
	_place(view, frame, _friend_label, 0.057, 0.22, 0.2, 0.06)
	var unit := view.y * 0.5
	var face := ToonGui.suit_font()
	ToonGui.style_label(_name_label, Color.BLACK, int(unit * 0.047), Color.WHITE, maxi(int(unit * 0.004), 1))
	ToonGui.style_label(_level_label, Color.BLACK, int(unit * 0.05), Color(0, 0, 0, 0), 0)
	ToonGui.style_label(_dept_label, Color.BLACK, int(unit * 0.05), Color(0, 0, 0, 0), 0)
	if face:
		_name_label.add_theme_font_override("font", face)
		_level_label.add_theme_font_override("font", face)
		_dept_label.add_theme_font_override("font", face)
		_close.add_theme_font_override("font", face)
	_close.add_theme_font_size_override("font_size", int(unit * 0.05))
	_close.add_theme_color_override("font_color", Color.BLACK)
	_close.add_theme_color_override("font_hover_color", Color(1, 0, 0))
	_close.add_theme_color_override("font_pressed_color", Color(0.5, 0, 0))
	var impress := ToonGui.font()
	if impress:
		_friend_label.add_theme_font_override("font", impress)
	ToonGui.style_label(_friend_label, Color.WHITE, int(unit * 0.05), Color(0.1, 0.25, 0.55), maxi(int(unit * 0.006), 1))


func _ask_friend() -> void:
	var hud := get_parent()
	if hud == null:
		return
	var friends := hud.get_node_or_null("FriendsList") as FriendsList
	if friends != null:
		friends.offer_cog(_name_label.text)


func _on_friend_label(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	_friend_label.accept_event()
	_ask_friend()


func _paint_friend(color: Color) -> void:
	_friend_label.add_theme_color_override("font_color", color)


func _place(view: Vector2, frame: Vector2, control: Control, x: float, z: float, width: float, height: float) -> void:
	ToonGui.place(control, view, frame.x + x, frame.y + z, width, height)


func _mount_head(actor: Node3D) -> void:
	_clear_head()
	for node in actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null or _BODY.has(String(mesh.name)):
			continue
		var copy := mesh.duplicate() as MeshInstance3D
		copy.transform = actor.global_transform.affine_inverse() * mesh.global_transform
		_head.add_child(copy)
	_frame_head()


func _frame_head() -> void:
	var merged := AABB()
	var found := false
	for node in _head.get_children():
		var mesh := node as MeshInstance3D
		if mesh == null:
			continue
		var box := mesh.transform * mesh.get_aabb()
		merged = box if not found else merged.merge(box)
		found = true
	if not found:
		return
	var center := merged.get_center()
	for node in _head.get_children():
		var mesh := node as MeshInstance3D
		mesh.position -= center
	var biggest := maxf(merged.size.x, maxf(merged.size.y, merged.size.z))
	if biggest < 0.001:
		biggest = 1.0
	_head.scale = Vector3.ONE / biggest
	_head.rotation = Vector3.ZERO
	_camera.position = Vector3(0.0, 0.05, 2.15)
	_camera.rotation = Vector3.ZERO


func _clear_head() -> void:
	for node in _head.get_children():
		_head.remove_child(node)
		node.free()


func _icon_for(dept: String) -> Texture2D:
	if dept == "s":
		return _SALES
	if dept == "l":
		return _LEGAL
	if dept == "m":
		return _MONEY
	return _CORP


func _obscure_friends(hidden: bool) -> void:
	var hud := get_parent()
	if hud == null:
		return
	var friends := hud.get_node_or_null("FriendsList") as FriendsList
	if friends != null:
		friends.obscure_button(hidden)


func _filming() -> bool:
	var node := get_parent()
	while node != null:
		if node.has_method("in_cutscene") and bool(node.call("in_cutscene")):
			return true
		node = node.get_parent()
	return false
