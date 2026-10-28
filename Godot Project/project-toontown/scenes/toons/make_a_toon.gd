extends Control

## Make a Toon in the original room: boy or girl, body, color, clothes, name.
## The toon is the original head, torso, and legs. Done saves the slot.

const PICK_SCENE := "res://scenes/toons/pick_a_toon.tscn"
const _TITLES: PackedStringArray = [
	"Choose  Boy  or  Girl",
	"Choose  Your  Type",
	"Choose  Your  Color",
	"Choose  Your  Clothes",
	"Choose  Your  Name",
]
const _TITLE_COLORS: Array[Color] = [
	Color(1, 0.92, 0.2),
	Color(0, 0.98, 0.5),
	Color(0, 1, 1),
	Color(1, 0.92, 0.2),
	Color(0, 0.98, 0.5),
]
const _ROOMS: Array = [
	["genderAll"],
	["bodyAll"],
	["colorAll"],
	["clothWalls", "clothProps"],
	["nameAll"],
]
const _FUR_COUNT := 24

var _shop := 0
var _style: ToonStyle
var _actor: ToonActor
var _room: Node3D
var _shop_box: Control
var _title: Label
var _next: TextureButton
var _next_label: Label
var _spin := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_view()
	_build_chrome()
	_show_shop()
	var player := AudioStreamPlayer.new()
	player.stream = preload("res://assets/toons/audio/create_a_toon.ogg")
	player.volume_db = -4.0
	player.autoplay = true
	add_child(player)


func _process(delta: float) -> void:
	if _spin != 0.0 and _actor:
		_actor.global_rotate(Vector3.UP, _spin * delta)


func _build_view() -> void:
	var box := SubViewportContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var viewport := SubViewport.new()
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(1280, 720)
	box.add_child(viewport)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.75, 0.95)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1, 1, 1)
	environment.ambient_light_energy = 1.0
	world.environment = environment
	viewport.add_child(world)
	_room = (load("res://assets/toons/room.glb") as PackedScene).instantiate() as Node3D
	viewport.add_child(_room)
	_unshade(_room)
	var spotlight := _find(_room, "spotlight__billboard")
	if spotlight:
		spotlight.visible = false
	_actor = ToonActor.new()
	_actor.position = Vector3(-1.62, 0.0, 3.49)
	viewport.add_child(_actor)
	var camera := Camera3D.new()
	camera.fov = 52.0
	camera.position = Vector3(-0.4, 2.6, 10.5)
	camera.current = true
	viewport.add_child(camera)
	camera.look_at(Vector3(-1.2, 1.3, 2.2))


func _build_chrome() -> void:
	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 12
	_title.offset_bottom = 78
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_shop_box = Control.new()
	_shop_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shop_box)

	var cancel := _image_button(
		preload("res://assets/toons/gui/tt_t_gui_mat_closeUp.png"),
		preload("res://assets/toons/gui/tt_t_gui_mat_closeDown.png")
	)
	cancel.anchor_left = 0.0
	cancel.anchor_top = 1.0
	cancel.anchor_right = 0.0
	cancel.anchor_bottom = 1.0
	cancel.offset_left = 28
	cancel.offset_top = -110
	cancel.offset_right = 128
	cancel.offset_bottom = -18
	cancel.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(PICK_SCENE)
	)
	add_child(cancel)

	var back := _flipped_arrow()
	back.anchor_left = 1.0
	back.anchor_top = 1.0
	back.anchor_right = 1.0
	back.anchor_bottom = 1.0
	back.offset_left = -250
	back.offset_top = -110
	back.offset_right = -160
	back.offset_bottom = -18
	add_child(back)

	_next = _image_button(
		preload("res://assets/toons/gui/tt_t_gui_mat_nextUp.png"),
		preload("res://assets/toons/gui/tt_t_gui_mat_nextDown.png")
	)
	_next.anchor_left = 1.0
	_next.anchor_top = 1.0
	_next.anchor_right = 1.0
	_next.anchor_bottom = 1.0
	_next.offset_left = -140
	_next.offset_top = -110
	_next.offset_right = -24
	_next.offset_bottom = -18
	_next.pressed.connect(_on_next)
	add_child(_next)
	_next_label = Label.new()
	_next_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_next_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next.add_child(_next_label)


func _show_shop() -> void:
	_title.text = _TITLES[_shop]
	_letter(_title, _TITLE_COLORS[_shop], 42, Color(0.05, 0.18, 0.35))
	var done := _shop == _TITLES.size() - 1
	_next.texture_normal = preload("res://assets/toons/gui/tt_t_gui_mat_okUp.png") if done else preload("res://assets/toons/gui/tt_t_gui_mat_nextUp.png")
	_next.texture_pressed = preload("res://assets/toons/gui/tt_t_gui_mat_okDown.png") if done else preload("res://assets/toons/gui/tt_t_gui_mat_nextDown.png")
	if _style == null and not done:
		_next.texture_normal = preload("res://assets/toons/gui/tt_t_gui_mat_nextDisabled.png")
		_next.texture_pressed = _next.texture_normal
	_next.disabled = _style == null
	_next_label.text = "Done" if done else "Next"
	_letter(_next_label, Color(1, 1, 1), 18, Color(0, 0, 0))
	for child in _shop_box.get_children():
		_shop_box.remove_child(child)
		child.queue_free()
	_show_room(_shop)
	match _shop:
		0:
			_build_gender()
		1:
			_build_body()
		2:
			_build_color()
		3:
			_build_clothes()
		4:
			_build_name()


func _show_room(shop: int) -> void:
	for group_name in ["genderAll", "bodyAll", "colorAll", "clothWalls", "clothProps", "nameAll"]:
		var group := _find(_room, group_name)
		if group:
			group.visible = false
	for group_name in _ROOMS[shop]:
		var group := _find(_room, group_name)
		if group:
			group.visible = true


func _build_gender() -> void:
	var boy := _image_button(
		preload("res://assets/toons/gui/tt_t_gui_mat_boyUp.png"),
		preload("res://assets/toons/gui/tt_t_gui_mat_boyDown.png")
	)
	_place_center(boy, -150, 150)
	boy.pressed.connect(_start_gender.bind("m"))
	_shop_box.add_child(boy)
	var girl := _image_button(
		preload("res://assets/toons/gui/tt_t_gui_mat_girlUp.png"),
		preload("res://assets/toons/gui/tt_t_gui_mat_girlDown.png")
	)
	_place_center(girl, 150, 150)
	girl.pressed.connect(_start_gender.bind("f"))
	_shop_box.add_child(girl)


func _start_gender(gender: String) -> void:
	_style = ToonStyle.random_body(gender)
	_actor.show_style(_style)
	_next.disabled = false
	_next.texture_normal = preload("res://assets/toons/gui/tt_t_gui_mat_nextUp.png")
	_next.texture_pressed = preload("res://assets/toons/gui/tt_t_gui_mat_nextDown.png")


func _build_body() -> void:
	_choice_row(0, "Species", _cycle_species.bind(-1), _cycle_species.bind(1))
	_choice_row(1, "Head", _cycle_head.bind(-1), _cycle_head.bind(1))
	_choice_row(2, "Body", _cycle_torso.bind(-1), _cycle_torso.bind(1))
	_choice_row(3, "Legs", _cycle_legs.bind(-1), _cycle_legs.bind(1))
	_add_rotate()


func _build_color() -> void:
	_choice_row(0, "Toon Color", _cycle_all_color.bind(-1), _cycle_all_color.bind(1))
	_choice_row(1, "Head", _cycle_part_color.bind("head", -1), _cycle_part_color.bind("head", 1))
	_choice_row(2, "Body", _cycle_part_color.bind("arm", -1), _cycle_part_color.bind("arm", 1))
	_choice_row(3, "Legs", _cycle_part_color.bind("leg", -1), _cycle_part_color.bind("leg", 1))
	_add_rotate()


func _build_clothes() -> void:
	var bottom := "Bottoms" if _style.gender == "f" else "Shorts"
	_choice_row(1, "Shirts", _style.cycle_top.bind(-1), _style.cycle_top.bind(1))
	_choice_row(2, bottom, _style.cycle_bottom.bind(-1), _style.cycle_bottom.bind(1))
	_add_rotate()


func _build_name() -> void:
	var card := PanelContainer.new()
	card.anchor_left = 0.5
	card.anchor_top = 1.0
	card.anchor_right = 0.5
	card.anchor_bottom = 1.0
	card.offset_left = -220
	card.offset_top = -250
	card.offset_right = 220
	card.offset_bottom = -130
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.96, 0.98, 1.0, 0.94)
	plate.border_color = Color(0.15, 0.35, 0.7)
	plate.set_border_width_all(4)
	plate.set_corner_radius_all(12)
	plate.content_margin_left = 16
	plate.content_margin_right = 16
	plate.content_margin_top = 12
	plate.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", plate)
	_shop_box.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	column.add_child(_name_edit("First name", _style.first_name, func(value: String) -> void:
		_style.first_name = value
	))
	column.add_child(_name_edit("Last name", _style.last_name, func(value: String) -> void:
		_style.last_name = value
	))
	var shuffle := Button.new()
	shuffle.text = "Shuffle"
	shuffle.pressed.connect(func() -> void:
		var named := ToonStyle.random_named(_style.gender)
		_style.first_name = named.first_name
		_style.last_name = named.last_name
		_show_shop()
	)
	column.add_child(shuffle)
	_add_rotate()


func _name_edit(placeholder: String, value: String, changed: Callable) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.text = value
	edit.max_length = 12
	edit.add_theme_color_override("font_color", Color(0.08, 0.1, 0.22))
	edit.add_theme_color_override("font_placeholder_color", Color(0.35, 0.4, 0.5))
	edit.add_theme_color_override("caret_color", Color(0.08, 0.1, 0.22))
	edit.add_theme_font_size_override("font_size", 22)
	edit.text_changed.connect(func(text: String) -> void:
		var cleaned := _clean_name(text)
		if cleaned != text:
			edit.text = cleaned
			edit.caret_column = cleaned.length()
		changed.call(cleaned)
	)
	return edit


func _choice_row(row: int, caption: String, previous: Callable, next: Callable) -> void:
	var frame := TextureRect.new()
	frame.texture = preload("res://assets/toons/gui/tt_t_gui_mat_shuffleFrame.png")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.anchor_left = 1.0
	frame.anchor_right = 1.0
	frame.anchor_top = 0.0
	frame.anchor_bottom = 0.0
	frame.offset_left = -430
	frame.offset_right = -36
	frame.offset_top = 110 + row * 78
	frame.offset_bottom = frame.offset_top + 64
	frame.rotation_degrees = [-2.0, 2.0, -1.0, 3.0][row]
	_shop_box.add_child(frame)
	var label := Label.new()
	label.text = caption
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letter(label, Color(1, 1, 1), 22, Color(0.02, 0.15, 0.35))
	frame.add_child(label)
	var left := _arrow(false, previous)
	left.anchor_left = 1.0
	left.anchor_right = 1.0
	left.anchor_top = 0.0
	left.anchor_bottom = 0.0
	left.offset_left = -430
	left.offset_right = -376
	left.offset_top = frame.offset_top + 8
	left.offset_bottom = frame.offset_bottom - 8
	_shop_box.add_child(left)
	var right := _arrow(true, next)
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_top = 0.0
	right.anchor_bottom = 0.0
	right.offset_left = -90
	right.offset_right = -36
	right.offset_top = frame.offset_top + 8
	right.offset_bottom = frame.offset_bottom - 8
	_shop_box.add_child(right)


func _add_rotate() -> void:
	var left := _image_button(
		preload("res://assets/toons/gui/tt_t_gui_mat_arrowRotateUp.png"),
		preload("res://assets/toons/gui/tt_t_gui_mat_arrowRotateDown.png")
	)
	left.anchor_left = 0.5
	left.anchor_right = 0.5
	left.anchor_top = 1.0
	left.anchor_bottom = 1.0
	left.offset_left = -150
	left.offset_right = -80
	left.offset_top = -120
	left.offset_bottom = -40
	left.button_down.connect(func() -> void: _spin = 1.6)
	left.button_up.connect(func() -> void: _spin = 0.0)
	_shop_box.add_child(left)
	var right := _flipped_rotate()
	right.anchor_left = 0.5
	right.anchor_right = 0.5
	right.anchor_top = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = 80
	right.offset_right = 150
	right.offset_top = -120
	right.offset_bottom = -40
	_shop_box.add_child(right)


func _cycle_species(step: int) -> void:
	var index := posmod(ToonStyle.SPECIES.find(_style.species()) + step, ToonStyle.SPECIES.size())
	var heads := ToonStyle.heads_for(ToonStyle.SPECIES[index])
	var head_index := mini(_head_index(), heads.size() - 1)
	_style.head = String(heads[head_index])
	_refresh()


func _head_index() -> int:
	var heads := ToonStyle.heads_for(_style.species())
	var index := heads.find(_style.head)
	return 0 if index < 0 else index


func _cycle_head(step: int) -> void:
	var heads := ToonStyle.heads_for(_style.species())
	_style.head = String(heads[posmod(_head_index() + step, heads.size())])
	_refresh()


func _cycle_torso(step: int) -> void:
	var bottom := "d" if _style.wears_skirt() else "s"
	_style.torso = ToonStyle.SIZES[posmod(_style.torso_size() + step, 3)] + bottom
	_refresh()


func _cycle_legs(step: int) -> void:
	_style.legs = ToonStyle.SIZES[posmod(_style.leg_size() + step, 3)]
	_refresh()


func _cycle_all_color(step: int) -> void:
	var color := _step_color(_style.head_color, step)
	_style.head_color = color
	_style.arm_color = color
	_style.leg_color = color
	_refresh()


func _cycle_part_color(part: String, step: int) -> void:
	match part:
		"head":
			_style.head_color = _step_color(_style.head_color, step)
		"arm":
			_style.arm_color = _step_color(_style.arm_color, step)
		"leg":
			_style.leg_color = _step_color(_style.leg_color, step)
	_refresh()


func _step_color(current: int, step: int) -> int:
	var index := clampi(current, 1, _FUR_COUNT) - 1
	index = posmod(index + step, _FUR_COUNT)
	return index + 1


func _refresh() -> void:
	_actor.show_style(_style)
	if _shop == 3:
		_show_shop()


func _on_back() -> void:
	if _shop == 0:
		return
	_shop -= 1
	_show_shop()


func _on_next() -> void:
	if _style == null:
		return
	if _shop < _TITLES.size() - 1:
		_shop += 1
		_show_shop()
		return
	if _style.first_name.strip_edges().is_empty() and _style.last_name.strip_edges().is_empty():
		_title.text = "Give your toon a name"
		return
	_style.first_name = _style.first_name.strip_edges()
	_style.last_name = _style.last_name.strip_edges()
	ToonRoster.set_slot(ToonRoster.pending_slot, _style)
	get_tree().change_scene_to_file(PICK_SCENE)


func _clean_name(value: String) -> String:
	var cleaned := ""
	for index in value.length():
		var letter := value[index]
		if (letter >= "A" and letter <= "Z") or (letter >= "a" and letter <= "z") or letter == " " or letter == "'" or letter == "-":
			cleaned += letter
	return cleaned.substr(0, 12)


func _flipped_rotate() -> Control:
	var box := Control.new()
	var image := TextureRect.new()
	image.texture = preload("res://assets/toons/gui/tt_t_gui_mat_arrowRotateUp.png")
	image.flip_h = true
	image.set_anchors_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(image)
	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.button_down.connect(func() -> void: _spin = -1.6)
	button.button_up.connect(func() -> void: _spin = 0.0)
	box.add_child(button)
	return box


func _flipped_arrow() -> Control:
	var box := Control.new()
	var image := TextureRect.new()
	image.texture = preload("res://assets/toons/gui/tt_t_gui_mat_nextUp.png")
	image.flip_h = true
	image.set_anchors_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(image)
	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(_on_back)
	box.add_child(button)
	return box


func _image_button(up: Texture2D, down: Texture2D) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = up
	button.texture_pressed = down
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	return button


func _arrow(flip: bool, action: Callable) -> Control:
	var box := Control.new()
	var image := TextureRect.new()
	image.texture = preload("res://assets/toons/gui/tt_t_gui_mat_shuffleArrowUp.png")
	image.flip_h = flip
	image.set_anchors_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(image)
	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(func() -> void:
		action.call()
		_actor.show_style(_style)
	)
	box.add_child(button)
	return box


func _place_center(button: TextureButton, x: float, y_from_bottom: float) -> void:
	button.anchor_left = 0.5
	button.anchor_right = 0.5
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = x - 70
	button.offset_right = x + 70
	button.offset_top = -y_from_bottom - 70
	button.offset_bottom = -y_from_bottom + 70


func _letter(label: Label, color: Color, size: int, outline: Color) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline)
	label.add_theme_constant_override("outline_size", maxi(4, size / 7))


func _unshade(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh:
			for surface in mesh.get_surface_count():
				var material := mesh.surface_get_material(surface)
				if material is StandardMaterial3D:
					(material as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for child in node.get_children():
		_unshade(child)


func _find(node: Node, wanted: String) -> Node:
	if node != null and String(node.name) == wanted:
		return node
	if node == null:
		return null
	for child in node.get_children():
		var found := _find(child, wanted)
		if found:
			return found
	return null

