extends Control

## Six slots on the original Pick a Toon background. An empty slot starts
## Make a Toon. Play enters Toontown Central with that toon remembered.

const MAKE_SCENE := "res://scenes/toons/make_a_toon.tscn"
const PLAY_SCENE := "res://scenes/playgrounds/toontown_central.tscn"
## The six squares are painted into the background. These cover them.
const _AREAS: Array[Rect2] = [
	Rect2(0.06, 0.13, 0.28, 0.36),
	Rect2(0.37, 0.15, 0.26, 0.34),
	Rect2(0.67, 0.12, 0.28, 0.36),
	Rect2(0.06, 0.54, 0.28, 0.36),
	Rect2(0.36, 0.56, 0.28, 0.36),
	Rect2(0.67, 0.50, 0.28, 0.38),
]
var _confirm_delete := -1


func _ready() -> void:
	_build()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var sky := ColorRect.new()
	sky.color = Color(0.09, 0.35, 0.78)
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)

	var background := TextureRect.new()
	background.texture = preload("res://assets/toons/gui/tt_t_gui_pat_background.png")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var title := Label.new()
	title.text = "Pick  A  Toon  To  Play"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 18
	title.offset_bottom = 90
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_letter(title, Color(1, 0.9, 0.1), 46, Color(0.35, 0.18, 0.02))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	for index in ToonRoster.SLOT_COUNT:
		add_child(_slot(index))

	var quit := TextureButton.new()
	quit.texture_normal = preload("res://assets/toons/gui/QuitBtn_RLVR.png")
	quit.texture_pressed = preload("res://assets/toons/gui/QuitBtn_DN.png")
	quit.ignore_texture_size = true
	quit.stretch_mode = TextureButton.STRETCH_SCALE
	quit.anchor_left = 1.0
	quit.anchor_top = 1.0
	quit.anchor_right = 1.0
	quit.anchor_bottom = 1.0
	quit.offset_left = -230
	quit.offset_top = -92
	quit.offset_right = -28
	quit.offset_bottom = -22
	quit.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(PLAY_SCENE)
	)
	add_child(quit)
	var quit_label := Label.new()
	quit_label.text = "Quit"
	quit_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	quit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letter(quit_label, Color(0.977, 0.816, 0.133), 26, Color(0.15, 0.2, 0.45))
	quit.add_child(quit_label)


func _slot(index: int) -> Control:
	var area := _AREAS[index]
	var panel := Control.new()
	panel.anchor_left = area.position.x
	panel.anchor_top = area.position.y
	panel.anchor_right = area.position.x + area.size.x
	panel.anchor_bottom = area.position.y + area.size.y

	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(button)

	var toon := ToonRoster.get_slot(index)
	if toon == null:
		var make := Label.new()
		make.text = "Make A\nToon"
		make.set_anchors_preset(Control.PRESET_FULL_RECT)
		make.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		make.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		make.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_letter(make, Color(0.55, 1.0, 0.95), 34, Color(0.0, 0.22, 0.32))
		button.add_child(make)
		button.pressed.connect(_make_toon.bind(index))
		return panel

	_add_head(button, toon)
	var name := Label.new()
	name.text = toon.display_name()
	name.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name.offset_top = 8
	name.offset_bottom = 70
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letter(name, Color(1, 1, 1), 22, Color(0, 0, 0))
	button.add_child(name)

	var play := Label.new()
	play.text = "Play This Toon"
	play.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	play.offset_top = -58
	play.offset_bottom = -8
	play.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letter(play, Color(1, 0.9, 0.1), 18, Color(0.2, 0.1, 0))
	button.add_child(play)
	button.pressed.connect(_play.bind(index))

	var trash := TextureButton.new()
	trash.texture_normal = preload("res://assets/toons/gui/TrashCan_CLSD.png")
	trash.texture_hover = preload("res://assets/toons/gui/TrashCan_RLVR.png")
	trash.texture_pressed = preload("res://assets/toons/gui/TrashCan_OPEN.png")
	trash.ignore_texture_size = true
	trash.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	trash.custom_minimum_size = Vector2(54, 54)
	trash.anchor_left = 1.0
	trash.anchor_top = 1.0
	trash.anchor_right = 1.0
	trash.anchor_bottom = 1.0
	trash.offset_left = -62
	trash.offset_top = -62
	trash.offset_right = -6
	trash.offset_bottom = -6
	trash.pressed.connect(_delete.bind(index))
	panel.add_child(trash)
	if _confirm_delete == index:
		var sure := Label.new()
		sure.text = "Delete?"
		sure.position = Vector2(-8, 168)
		sure.size = Vector2(150, 28)
		sure.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sure.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_letter(sure, Color(1, 1, 1), 18, Color(0.4, 0, 0))
		panel.add_child(sure)
	return panel


func _add_head(parent: Control, style: ToonStyle) -> void:
	var box := SubViewportContainer.new()
	box.anchor_left = 0.18
	box.anchor_top = 0.22
	box.anchor_right = 0.82
	box.anchor_bottom = 0.78
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(220, 180)
	box.add_child(viewport)
	var actor := ToonActor.new()
	actor.show_style(style)
	_hide_body(actor)
	viewport.add_child(actor)
	var camera := Camera3D.new()
	camera.fov = 28
	viewport.add_child(camera)
	var neck := _find(actor, "def_head")
	var focus := _point_under(actor, neck) if neck else actor.position + Vector3(0, 1.5, 0)
	focus.y += 0.28
	camera.position = focus + Vector3(0, 0.05, 1.7)
	camera.look_at_from_position(camera.position, focus, Vector3.UP)


func _letter(label: Label, color: Color, size: int, outline: Color) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline)
	label.add_theme_constant_override("outline_size", maxi(4, size / 7))


func _make_toon(index: int) -> void:
	ToonRoster.pending_slot = index
	get_tree().change_scene_to_file(MAKE_SCENE)


func _play(index: int) -> void:
	ToonRoster.select_slot(index)
	get_tree().change_scene_to_file(PLAY_SCENE)


func _delete(index: int) -> void:
	if _confirm_delete != index:
		_confirm_delete = index
		_rebuild()
		return
	ToonRoster.clear_slot(index)
	_confirm_delete = -1
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_build()


func _hide_body(node: Node) -> void:
	var part := String(node.name)
	if part in ["legs", "feet", "arms", "hands", "neck", "torso-top", "torso-bot", "sleeves"]:
		node.visible = false
	for child in node.get_children():
		_hide_body(child)


func _point_under(root: Node3D, node: Node3D) -> Vector3:
	var chain: Array[Node3D] = []
	var current: Node = node
	while current and current != root:
		if current is Node3D:
			chain.append(current as Node3D)
		current = current.get_parent()
	chain.reverse()
	var xform := Transform3D.IDENTITY
	for item in chain:
		xform = xform * item.transform
	return (root.transform * xform).origin


func _find(node: Node, wanted: String) -> Node3D:
	if String(node.name) == wanted and node is Node3D:
		return node as Node3D
	for child in node.get_children():
		var found := _find(child, wanted)
		if found:
			return found
	return null

