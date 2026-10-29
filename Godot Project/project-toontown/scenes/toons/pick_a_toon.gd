extends Control

## Six slots on the original Pick a Toon background. An empty slot starts
## Make a Toon. Play starts the Toontorial with the toon in that slot.

const MAKE_SCENE := "res://scenes/toons/make_a_toon.tscn"
const PLAY_SCENE := "res://scenes/interiors/toontorial.tscn"
## The six squares are painted into the background. These cover them.
# Centers of the six squares painted into the background.
const _AREAS: Array[Rect2] = [
	Rect2(0.050, 0.154, 0.260, 0.330),
	Rect2(0.373, 0.189, 0.260, 0.320),
	Rect2(0.689, 0.175, 0.266, 0.311),
	Rect2(0.045, 0.554, 0.271, 0.324),
	Rect2(0.375, 0.608, 0.258, 0.303),
	Rect2(0.701, 0.556, 0.256, 0.324),
]
const _TILT: Array[float] = [7.0, -11.0, 1.0, -5.0, 3.5, -5.0]
const _TEAL := Color(0.0, 1.0, 0.8, 1.0)
const _YELLOW := Color(1.0, 0.9, 0.1, 1.0)

var _confirm: Control
var _confirm_slot := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	resized.connect(_layout)
	_layout()


func _build() -> void:
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
	title.name = "Title"
	title.text = "PICK  A  TOON  TO  PLAY"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	for index in ToonRoster.SLOT_COUNT:
		add_child(_slot(index))

	var quit := TextureButton.new()
	quit.name = "Quit"
	quit.texture_normal = preload("res://assets/toons/gui/QuitBtn_RLVR.png")
	quit.texture_pressed = preload("res://assets/toons/gui/QuitBtn_DN.png")
	quit.texture_hover = preload("res://assets/toons/gui/QuitBtn_RLVR.png")
	quit.ignore_texture_size = true
	quit.stretch_mode = TextureButton.STRETCH_SCALE
	quit.pressed.connect(func() -> void:
		get_tree().quit()
	)
	add_child(quit)
	var quit_label := Label.new()
	quit_label.name = "QuitLabel"
	quit_label.text = "QUIT"
	quit_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	quit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quit.add_child(quit_label)


func _layout() -> void:
	if size.y < 2.0:
		return
	var title := get_node_or_null("Title") as Label
	if title:
		title.offset_top = size.y * 0.02
		title.offset_bottom = size.y * 0.14
		ToonGui.style_title(title, _YELLOW, int(size.y * 0.078))
	var quit := get_node_or_null("Quit") as TextureButton
	if quit:
		var quit_size := Vector2(size.y * 0.16, size.y * 0.075)
		quit.position = Vector2(size.x - quit_size.x - size.y * 0.03, size.y - quit_size.y - size.y * 0.025)
		quit.size = quit_size
		var quit_label := quit.get_node_or_null("QuitLabel") as Label
		if quit_label:
			ToonGui.style_label(quit_label, _YELLOW, int(size.y * 0.032), Color(0.05, 0.15, 0.35), int(size.y * 0.004))
	for index in ToonRoster.SLOT_COUNT:
		var panel := get_node_or_null("Slot%d" % index) as Control
		if panel == null:
			continue
		var area := _AREAS[index]
		panel.position = Vector2(area.position.x * size.x, area.position.y * size.y)
		panel.size = Vector2(area.size.x * size.x, area.size.y * size.y)
		_layout_slot(panel, index)


func _slot(index: int) -> Control:
	var panel := Control.new()
	panel.name = "Slot%d" % index
	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(button)

	var toon := ToonRoster.get_slot(index)
	if toon == null:
		var make := Label.new()
		make.name = "Prompt"
		make.text = "MAKE A\nTOON"
		make.set_anchors_preset(Control.PRESET_FULL_RECT)
		make.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		make.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		make.mouse_filter = Control.MOUSE_FILTER_IGNORE
		make.rotation_degrees = _TILT[index]
		make.pivot_offset = Vector2.ZERO
		button.add_child(make)
		button.mouse_entered.connect(func() -> void:
			make.modulate = Color(1, 1, 1, 1)
		)
		button.mouse_exited.connect(func() -> void:
			make.modulate = Color(1, 1, 1, 0.55)
		)
		make.modulate = Color(1, 1, 1, 0.55)
		button.pressed.connect(_make_toon.bind(index))
		return panel

	_add_head(button, toon)
	var name := Label.new()
	name.name = "ToonName"
	name.text = toon.display_name()
	name.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.rotation_degrees = _TILT[index]
	button.add_child(name)

	var play := Label.new()
	play.name = "Play"
	play.text = "PLAY\nTHIS TOON"
	play.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	play.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	play.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.modulate = Color(1, 1, 1, 0)
	button.add_child(play)
	button.mouse_entered.connect(func() -> void:
		play.modulate = Color(1, 1, 1, 1)
	)
	button.mouse_exited.connect(func() -> void:
		play.modulate = Color(1, 1, 1, 0)
	)
	button.pressed.connect(_play.bind(index))

	var trash := TextureButton.new()
	trash.name = "Trash"
	trash.texture_normal = preload("res://assets/toons/gui/TrashCan_CLSD.png")
	trash.texture_hover = preload("res://assets/toons/gui/TrashCan_RLVR.png")
	trash.texture_pressed = preload("res://assets/toons/gui/TrashCan_OPEN.png")
	trash.ignore_texture_size = true
	trash.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	trash.pressed.connect(_ask_delete.bind(index))
	panel.add_child(trash)
	return panel


func _layout_slot(panel: Control, index: int) -> void:
	var prompt := panel.find_child("Prompt", true, false) as Label
	if prompt:
		ToonGui.style_label(prompt, _TEAL, int(panel.size.y * 0.16), Color(0.0, 0.25, 0.35), int(panel.size.y * 0.02))
		prompt.pivot_offset = prompt.size * 0.5
	var name := panel.find_child("ToonName", true, false) as Label
	if name:
		name.offset_left = panel.size.x * 0.08
		name.offset_right = -panel.size.x * 0.08
		name.offset_top = panel.size.y * 0.04
		name.offset_bottom = panel.size.y * 0.28
		name.pivot_offset = name.size * 0.5
		ToonGui.style_label(name, Color.WHITE, int(panel.size.y * 0.11), Color(0, 0, 0), int(panel.size.y * 0.014))
	var play := panel.find_child("Play", true, false) as Label
	if play:
		play.offset_top = -panel.size.y * 0.28
		play.offset_bottom = -panel.size.y * 0.04
		ToonGui.style_label(play, _YELLOW, int(panel.size.y * 0.08), Color(0, 0, 0), int(panel.size.y * 0.01))
	var trash := panel.find_child("Trash", true, false) as TextureButton
	if trash:
		var trash_size := panel.size.y * 0.24
		trash.position = Vector2(panel.size.x * 0.68, panel.size.y * 0.70)
		trash.size = Vector2(trash_size, trash_size)


func _add_head(parent: Control, style: ToonStyle) -> void:
	var box := SubViewportContainer.new()
	box.anchor_left = 0.14
	box.anchor_top = 0.20
	box.anchor_right = 0.86
	box.anchor_bottom = 0.80
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(320, 280)
	box.add_child(viewport)
	var actor := ToonActor.new()
	actor.show_style(style)
	_hide_body(actor)
	viewport.add_child(actor)
	var camera := Camera3D.new()
	camera.fov = 32
	viewport.add_child(camera)
	var neck := _find(actor, "def_head")
	var focus := _point_under(actor, neck) if neck else actor.position + Vector3(0, 1.5, 0)
	focus.y += 0.05
	camera.position = focus + Vector3(0, 0.0, 2.35)
	camera.look_at_from_position(camera.position, focus, Vector3.UP)


func _make_toon(index: int) -> void:
	ToonRoster.pending_slot = index
	get_tree().change_scene_to_file(MAKE_SCENE)


func _play(index: int) -> void:
	ToonRoster.select_slot(index)
	get_tree().change_scene_to_file(PLAY_SCENE)


func _ask_delete(index: int) -> void:
	_close_confirm()
	var toon := ToonRoster.get_slot(index)
	if toon == null:
		return
	_confirm_slot = index
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_confirm = dim
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -280
	card.offset_top = -120
	card.offset_right = 280
	card.offset_bottom = 120
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.18, 0.55, 0.95)
	plate.border_color = Color(0.05, 0.2, 0.45)
	plate.set_border_width_all(6)
	plate.set_corner_radius_all(18)
	plate.content_margin_left = 24
	plate.content_margin_right = 24
	plate.content_margin_top = 18
	plate.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", plate)
	dim.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	card.add_child(column)
	var message := Label.new()
	message.text = "This will delete %s forever." % toon.display_name()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ToonGui.style_label(message, Color.WHITE, 28, Color(0, 0, 0), 4)
	column.add_child(message)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	column.add_child(row)
	row.add_child(_dialog_button("Delete", _confirm_delete))
	row.add_child(_dialog_button("Cancel", _close_confirm))


func _dialog_button(caption: String, action: Callable) -> Control:
	var button := TextureButton.new()
	button.texture_normal = preload("res://assets/toons/gui/QuitBtn_UP.png")
	button.texture_pressed = preload("res://assets/toons/gui/QuitBtn_DN.png")
	button.texture_hover = preload("res://assets/toons/gui/QuitBtn_RLVR.png")
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.custom_minimum_size = Vector2(180, 64)
	button.pressed.connect(action)
	var label := Label.new()
	label.text = caption
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(label, Color(0.1, 0.1, 0.15), 22, Color(1, 1, 1, 0), 0)
	button.add_child(label)
	return button


func _confirm_delete() -> void:
	if _confirm_slot >= 0:
		ToonRoster.clear_slot(_confirm_slot)
	_confirm_slot = -1
	_rebuild()


func _close_confirm() -> void:
	_confirm_slot = -1
	if _confirm:
		_confirm.queue_free()
		_confirm = null


func _rebuild() -> void:
	_confirm = null
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_build()
	_layout()


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
