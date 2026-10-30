extends Control

## Six slots on the original Pick a Toon background. An empty slot starts
## Make a Toon. Play starts the Toontorial until that toon has reached a
## playground. After that, Play teleports them to their last hood.

const MAKE_SCENE := "res://scenes/toons/make_a_toon.tscn"
const PLAY_SCENE := "res://scenes/interiors/toontorial.tscn"
const _PLACES := preload("res://scenes/places/hood_places.gd")
const _ARRIVAL := preload("res://scenes/playgrounds/playground_toon.gd")
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
# tt_m_gui_pat_mainGui draws the square background on a card that is exactly 4:3.
const _CARD_ASPECT := 4.0 / 3.0
# QuitBtn in pick_a_toon_gui: a 0.425 by 0.1083 card, scaled 1.05.
const _QUIT_SIZE := Vector2(0.425 * 1.05, 0.108333 * 1.05)
const _TEAL := Color(0.0, 1.0, 0.8, 1.0)
const _YELLOW := Color(1.0, 0.9, 0.1, 1.0)
# ToontownStart and enterChooseAvatar loop tt_theme at 0.9 on this screen.
const THEME_PATH := "res://assets/toons/audio/tt_theme.mp3"
const THEME_VOLUME := 0.9

var _confirm: Control
var _confirm_slot := -1
var _leaving := false
static var arrive_from_black := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	resized.connect(_layout)
	_layout()
	_play_theme()
	if arrive_from_black:
		arrive_from_black = false
		_fade_in()


func _play_theme() -> void:
	var stream := load(THEME_PATH) as AudioStreamMP3
	if stream == null:
		return
	stream = stream.duplicate() as AudioStreamMP3
	stream.loop = true
	var player := ToonAudio.music_player()
	player.name = "ThemeMusic"
	player.stream = stream
	player.volume_db = linear_to_db(THEME_VOLUME)
	add_child(player)
	player.play()


func _build() -> void:
	var crop := ColorRect.new()
	crop.color = Color(0, 0, 0)
	crop.set_anchors_preset(Control.PRESET_FULL_RECT)
	crop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crop)

	var background := TextureRect.new()
	background.name = "Background"
	background.texture = preload("res://assets/toons/gui/tt_t_gui_pat_background.png")
	background.set_anchors_preset(Control.PRESET_TOP_LEFT)
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
	quit.clip_contents = true
	quit.pressed.connect(func() -> void:
		get_tree().quit()
	)
	ToonGui.button_sounds(quit)
	add_child(quit)
	var quit_label := Label.new()
	quit_label.name = "QuitLabel"
	quit_label.text = "QUIT"
	quit_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	quit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quit.add_child(quit_label)


func _card_rect() -> Rect2:
	if size.x / size.y >= _CARD_ASPECT:
		var width := size.y * _CARD_ASPECT
		return Rect2((size.x - width) * 0.5, 0.0, width, size.y)
	var height := size.x / _CARD_ASPECT
	return Rect2(0.0, (size.y - height) * 0.5, size.x, height)


func _layout() -> void:
	if size.y < 2.0:
		return
	var card := _card_rect()
	var background := get_node_or_null("Background") as TextureRect
	if background:
		background.position = card.position
		background.size = card.size
	var title := get_node_or_null("Title") as Label
	if title:
		title.offset_top = card.position.y + card.size.y * 0.02
		title.offset_bottom = card.position.y + card.size.y * 0.14
		ToonGui.style_title(title, _YELLOW, int(card.size.y * 0.078))
	var quit := get_node_or_null("Quit") as TextureButton
	if quit:
		# The visible screen is the 4:3 card. The button sits in that corner,
		# and the caption is sized to the button so it stays inside it.
		var unit := card.size.y * 0.5
		var quit_size := _QUIT_SIZE * unit
		var margin := Vector2(0.04, 0.04) * unit
		quit.position = card.position + Vector2(card.size.x - quit_size.x - margin.x, card.size.y - quit_size.y - margin.y)
		quit.size = quit_size
		var quit_label := quit.get_node_or_null("QuitLabel") as Label
		if quit_label:
			# The sign font's letters sit high in the line. Dropping the label
			# recenters them, and the size stops short of the pill's rim.
			quit_label.set_anchors_preset(Control.PRESET_FULL_RECT)
			var drop := quit_size.y * 0.05
			quit_label.offset_left = 0.0
			quit_label.offset_top = drop
			quit_label.offset_right = 0.0
			quit_label.offset_bottom = drop
			quit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			quit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			ToonGui.style_sign(quit_label, _YELLOW, int(quit_size.y * 0.76), Color(0, 0, 0), maxi(int(quit_size.y * 0.03), 1))
	for index in ToonRoster.SLOT_COUNT:
		var panel := get_node_or_null("Slot%d" % index) as Control
		if panel == null:
			continue
		var area := _AREAS[index]
		panel.position = card.position + Vector2(area.position.x * card.size.x, area.position.y * card.size.y)
		panel.size = Vector2(area.size.x * card.size.x, area.size.y * card.size.y)
		_layout_slot(panel, index)


func _slot(index: int) -> Control:
	var panel := Control.new()
	panel.name = "Slot%d" % index
	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	ToonGui.button_sounds(button)
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
			# text2_scale 0.12 against the resting text0_scale 0.1.
			make.scale = Vector2(1.2, 1.2)
		)
		button.mouse_exited.connect(func() -> void:
			make.modulate = Color(1, 1, 1, 0.55)
			make.scale = Vector2.ONE
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

	var status := Label.new()
	status.name = "Status"
	status.text = "Name\nApproved"
	status.set_anchors_preset(Control.PRESET_FULL_RECT)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.rotation_degrees = _TILT[index]
	button.add_child(status)

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
		status.modulate = Color(1, 1, 1, 0)
	)
	button.mouse_exited.connect(func() -> void:
		play.modulate = Color(1, 1, 1, 0)
		status.modulate = Color(1, 1, 1, 1)
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
	ToonGui.button_sounds(trash)
	panel.add_child(trash)
	return panel


func _layout_slot(panel: Control, index: int) -> void:
	var prompt := panel.find_child("Prompt", true, false) as Label
	if prompt:
		ToonGui.style_sign(prompt, _TEAL, int(panel.size.y * 0.12), Color(0.0, 0.2, 0.28), int(panel.size.y * 0.012))
		prompt.pivot_offset = prompt.size * 0.5
	var name := panel.find_child("ToonName", true, false) as Label
	if name:
		name.offset_left = panel.size.x * 0.08
		name.offset_right = -panel.size.x * 0.08
		name.offset_top = panel.size.y * 0.04
		name.offset_bottom = panel.size.y * 0.28
		name.pivot_offset = name.size * 0.5
		ToonGui.style_label(name, Color.WHITE, int(panel.size.y * 0.11), Color(0, 0, 0), int(panel.size.y * 0.014))
	var status := panel.find_child("Status", true, false) as Label
	if status:
		status.offset_top = panel.size.y * 0.46
		status.offset_bottom = panel.size.y * 0.72
		status.pivot_offset = status.size * 0.5
		ToonGui.style_label(status, Color.WHITE, int(panel.size.y * 0.09), Color(0, 0, 0), int(panel.size.y * 0.012))
	var play := panel.find_child("Play", true, false) as Label
	if play:
		play.offset_top = -panel.size.y * 0.28
		play.offset_bottom = -panel.size.y * 0.04
		ToonGui.style_sign(play, _YELLOW, int(panel.size.y * 0.075), Color(0, 0, 0), int(panel.size.y * 0.008))
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
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(320, 280)
	box.add_child(viewport)
	var actor := ToonActor.new()
	actor.show_style(style)
	_hide_body(actor)
	viewport.add_child(actor)
	var camera := Camera3D.new()
	# The original square draws the head with the flat GUI camera. A close
	# perspective lens sits just in front of the muzzle and balloons the skull.
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.55
	viewport.add_child(camera)
	var neck := _find(actor, "def_head")
	var focus := _point_under(actor, neck) if neck else actor.position + Vector3(0, 1.5, 0)
	focus.y += 0.08
	camera.position = focus + Vector3(0, 0.0, 4.0)
	camera.look_at_from_position(camera.position, focus, Vector3.UP)


func _fade_in() -> void:
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	fade.z_index = 20
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 0.5)
	tween.finished.connect(fade.queue_free)


func _make_toon(index: int) -> void:
	if _leaving:
		return
	_leaving = true
	ToonRoster.pending_slot = index
	# The original chooser fades out, then Make a Toon fades in.
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.5)
	tween.finished.connect(func() -> void:
		get_tree().change_scene_to_file(MAKE_SCENE)
	)


func _play(index: int) -> void:
	ToonRoster.select_slot(index)
	var tasks := ToonTasks.for_selected()
	if not tasks.in_playground:
		get_tree().change_scene_to_file(PLAY_SCENE)
		return
	# PlayGame.enter uses how = teleportIn at defaultZone, which is lastHood.
	_ARRIVAL.teleport_in = true
	get_tree().change_scene_to_file(_PLACES.scene_for(tasks.last_hood))


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
	var card := TextureRect.new()
	card.texture = preload("res://assets/toons/gui/g1.png")
	card.modulate = Color(1, 1, 0.75)
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -250
	card.offset_top = -130
	card.offset_right = 250
	card.offset_bottom = 130
	dim.add_child(card)
	var message := Label.new()
	message.text = "This will delete %s forever." % toon.display_name()
	message.anchor_left = 0.08
	message.anchor_right = 0.92
	message.anchor_top = 0.16
	message.anchor_bottom = 0.48
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(message, Color(0.08, 0.08, 0.1), 28, Color(0, 0, 0, 0), 0)
	card.add_child(message)
	card.add_child(_dialog_choice(preload("res://assets/toons/gui/ChtBx_OKBtn_UP.png"), preload("res://assets/toons/gui/ChtBx_OKBtn_DN.png"), "OK", 0.28, _confirm_delete))
	card.add_child(_dialog_choice(preload("res://assets/toons/gui/CloseBtn_UP.png"), preload("res://assets/toons/gui/CloseBtn_DN.png"), "Cancel", 0.58, _close_confirm))


func _dialog_choice(up: Texture2D, down: Texture2D, caption: String, left: float, action: Callable) -> Control:
	var box := Control.new()
	box.anchor_left = left
	box.anchor_right = left + 0.16
	box.anchor_top = 0.52
	box.anchor_bottom = 0.92
	var button := TextureButton.new()
	button.texture_normal = up
	button.texture_pressed = down
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.anchor_left = 0.0
	button.anchor_right = 1.0
	button.anchor_top = 0.0
	button.anchor_bottom = 0.62
	button.pressed.connect(action)
	ToonGui.button_sounds(button)
	box.add_child(button)
	var label := Label.new()
	label.text = caption
	label.anchor_left = -0.4
	label.anchor_right = 1.4
	label.anchor_top = 0.62
	label.anchor_bottom = 1.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(label, Color(0.08, 0.08, 0.1), 18, Color(0, 0, 0, 0), 0)
	box.add_child(label)
	return box


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
	# The slot only shows the head. A shirt or shorts under this camera reads as a second head.
	if node is MeshInstance3D and not _is_head_part(part):
		node.visible = false
	for child in node.get_children():
		_hide_body(child)


func _is_head_part(part: String) -> bool:
	return part.begins_with("head") or part.begins_with("ears") or part.begins_with("eyes") or part.begins_with("muzzle") or part.begins_with("eyelash") or part == "nose" or part == "node" or part == "node2" or part.contains("pupil")


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
