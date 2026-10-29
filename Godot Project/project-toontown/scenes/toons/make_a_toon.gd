extends Control

## Make a Toon in the original room: boy or girl, body, color, clothes, name.
## The toon is the original head, torso, and legs. Done saves the slot.

const PICK_SCENE := "res://scenes/toons/pick_a_toon.tscn"
const _TITLES: PackedStringArray = [
	"CHOOSE  BOY  OR  GIRL",
	"CHOOSE  YOUR  TYPE",
	"CHOOSE  YOUR  COLOR",
	"CHOOSE  YOUR  CLOTHES",
	"CHOOSE  YOUR  NAME",
]
const _TITLE_COLORS: Array[Color] = [
	Color(1, 0.92, 0.2),
	Color(0, 0.98, 0.5),
	Color(0, 1, 1),
	Color(1, 0.92, 0.2),
	Color(0, 0.98, 0.5),
]
const _TITLE_SCALES: Array[float] = [0.18, 0.18, 0.18, 0.16, 0.15]
const _ROOMS: Array = [
	["genderAll"],
	["bodyAll"],
	["colorAll"],
	["clothWalls", "clothProps"],
	["nameAll"],
]
const _SFX_FWD := "res://assets/toons/audio/GUI_create_toon_fwd.mp3"
const _SFX_BACK := "res://assets/toons/audio/GUI_create_toon_back.mp3"
const _SFX_ENTER: Array[String] = [
	"",
	"res://assets/toons/audio/GUI_create_toon_bodyshop.mp3",
	"res://assets/toons/audio/GUI_create_toon_art.mp3",
	"res://assets/toons/audio/GUI_create_toon_store.mp3",
	"",
]
const _SFX_CRASH: Array[String] = [
	"res://assets/toons/audio/tt_s_ara_mat_crash_boing.mp3",
	"res://assets/toons/audio/tt_s_ara_mat_crash_glassBoing.mp3",
	"res://assets/toons/audio/tt_s_ara_mat_crash_wood.mp3",
	"res://assets/toons/audio/tt_s_ara_mat_crash_woodBoing.mp3",
	"res://assets/toons/audio/tt_s_ara_mat_crash_woodGlass.mp3",
]
const _OUTLINE := Color(0.02, 0.08, 0.16)

var _shop := 0
var _style: ToonStyle
var _actor: ToonActor
var _room: Node3D
var _viewport: SubViewport
var _slide: Control
var _shop_box: Control
var _transitioning := false
var _title: Label
var _next: TextureButton
var _back: Control
var _rotate_left: Control
var _rotate_right: Control
var _spin := 0.0
var _placed: Array = []
var _typing := true
var _name_edit: LineEdit
var _titles: PackedStringArray = PackedStringArray()
var _firsts: PackedStringArray = PackedStringArray()
var _prefixes: PackedStringArray = PackedStringArray()
var _suffixes: PackedStringArray = PackedStringArray()
var _title_i := 0
var _first_i := 0
var _prefix_i := 0
var _suffix_i := 0
var _title_on := false
var _first_on := true
var _last_on := true
var _name_gender := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_view()
	_build_chrome()
	_show_shop()
	resized.connect(_layout)
	_layout()
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
	_viewport = SubViewport.new()
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.size = Vector2i(1280, 720)
	box.add_child(_viewport)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.75, 0.95)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1, 1, 1)
	environment.ambient_light_energy = 1.0
	world.environment = environment
	_viewport.add_child(world)
	_room = (load("res://assets/toons/room.glb") as PackedScene).instantiate() as Node3D
	_viewport.add_child(_room)
	_unshade(_room)
	var spotlight := _find(_room, "spotlight__billboard")
	if spotlight:
		spotlight.visible = false
	# Leftover export cards: an untextured gray quad, and the camera helper
	# that was sitting in front of the clothing rack.
	for leftover_name in ["polySurface1", "camera_arrow"]:
		var leftover := _find(_room, leftover_name)
		if leftover:
			leftover.visible = false
	_actor = ToonActor.new()
	_viewport.add_child(_actor)
	var camera := Camera3D.new()
	camera.name = "MatCamera"
	camera.current = true
	_viewport.add_child(camera)
	_place_camera(camera)
	_pose_toon()


func _build_chrome() -> void:
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	# Top-left sized panel so sliding it does not stretch a full-rect anchor.
	_slide = Control.new()
	_slide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_slide)
	_shop_box = Control.new()
	_shop_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide.add_child(_shop_box)

	var cancel := _image_button(
		preload("res://assets/toons/gui/tt_t_gui_mat_closeUp.png"),
		preload("res://assets/toons/gui/tt_t_gui_mat_closeDown.png")
	)
	cancel.name = "Cancel"
	cancel.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(PICK_SCENE)
	)
	add_child(cancel)
	_track(cancel, 0, 0, 0.34, 0.34)

	_back = _flipped_arrow()
	add_child(_back)
	_track(_back, 0, 0, 0.30, 0.30)

	_next = _image_button(
		preload("res://assets/toons/gui/tt_t_gui_mat_nextUp.png"),
		preload("res://assets/toons/gui/tt_t_gui_mat_nextDown.png")
	)
	_next.pressed.connect(_on_next)
	add_child(_next)
	_track(_next, 0, 0, 0.30, 0.30)

	_rotate_left = _rotate_button(true)
	_shop_box.add_child(_rotate_left)
	_rotate_right = _rotate_button(false)
	_shop_box.add_child(_rotate_right)


func _show_shop() -> void:
	for child in _shop_box.get_children():
		if child == _rotate_left or child == _rotate_right:
			continue
		_shop_box.remove_child(child)
		child.queue_free()
	var kept: Array = []
	for item in _placed:
		var control: Control = item[0]
		if not is_instance_valid(control) or control.is_queued_for_deletion():
			continue
		if control.get_parent() == _shop_box and control != _rotate_left and control != _rotate_right:
			continue
		kept.append(item)
	_placed = kept
	_title.text = _TITLES[_shop]
	var done := _shop == _TITLES.size() - 1
	_next.texture_normal = preload("res://assets/toons/gui/tt_t_gui_mat_okUp.png") if done else preload("res://assets/toons/gui/tt_t_gui_mat_nextUp.png")
	_next.texture_pressed = preload("res://assets/toons/gui/tt_t_gui_mat_okDown.png") if done else preload("res://assets/toons/gui/tt_t_gui_mat_nextDown.png")
	_next.texture_disabled = preload("res://assets/toons/gui/tt_t_gui_mat_nextDisabled.png") if not done else preload("res://assets/toons/gui/tt_t_gui_mat_okUp.png")
	_next.disabled = _style == null
	_back.visible = _shop > 0
	var spinning := _shop > 0 and _shop < 4
	_rotate_left.visible = spinning
	_rotate_right.visible = spinning
	_show_room(_shop)
	_pose_toon()
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
	_layout()


func _show_room(shop: int) -> void:
	for group_name in ["genderAll", "bodyAll", "colorAll", "clothWalls", "clothProps", "nameAll"]:
		var group := _find(_room, group_name)
		if group:
			group.visible = false
	for group_name in _ROOMS[shop]:
		var group := _find(_room, group_name)
		if group:
			group.visible = true


func _pose_toon() -> void:
	if _actor == null:
		return
	if _shop == 4:
		_actor.position = Vector3(1.55, 0.0, 4.05)
	else:
		_actor.position = Vector3(-1.62, 0.0, 3.49)
	if _style:
		_actor.show_style(_style)
		if _shop == 4:
			_actor.rotate_y(deg_to_rad(-55.0))


func _build_gender() -> void:
	var boy := _image_button(
		preload("res://assets/toons/gui/tt_t_gui_mat_boyUp.png"),
		preload("res://assets/toons/gui/tt_t_gui_mat_boyDown.png")
	)
	boy.pressed.connect(_start_gender.bind("m"))
	_shop_box.add_child(boy)
	_track(boy, -0.42, -0.78, 0.52, 0.52)
	var girl := _image_button(
		preload("res://assets/toons/gui/tt_t_gui_mat_girlUp.png"),
		preload("res://assets/toons/gui/tt_t_gui_mat_girlDown.png")
	)
	girl.pressed.connect(_start_gender.bind("f"))
	_shop_box.add_child(girl)
	_track(girl, 0.42, -0.78, 0.52, 0.52)


func _start_gender(gender: String) -> void:
	_style = ToonStyle.random_body(gender)
	_pose_toon()
	_next.disabled = false


func _build_body() -> void:
	var x := _right(0.52)
	_choice_row(x, 0.34, 1.05, -1.0, "Head", _cycle_head.bind(-1), _cycle_head.bind(1))
	_choice_row(x, 0.08, 0.9, 2.0, "Body", _cycle_torso.bind(-1), _cycle_torso.bind(1))
	_choice_row(x, -0.18, 0.9, -2.0, "Legs", _cycle_legs.bind(-1), _cycle_legs.bind(1))
	_shuffle_button(x, -0.48, _shuffle_body)


func _build_color() -> void:
	var x := _right(0.55)
	_choice_row(x, 0.42, 1.15, 0.0, "Toon Color", _cycle_all_color.bind(-1), _cycle_all_color.bind(1))
	_choice_row(x, 0.16, 0.9, 2.0, "Head", _cycle_part_color.bind("head", -1), _cycle_part_color.bind("head", 1))
	_choice_row(x, -0.08, 0.9, -2.0, "Body", _cycle_part_color.bind("arm", -1), _cycle_part_color.bind("arm", 1))
	_choice_row(x, -0.32, 0.9, 3.0, "Legs", _cycle_part_color.bind("leg", -1), _cycle_part_color.bind("leg", 1))
	_shuffle_button(x, -0.58, _shuffle_color)


func _build_clothes() -> void:
	var x := _right(0.58)
	var bottom := "Skirts" if _style != null and _style.gender == "f" else "Shorts"
	_choice_row(x, 0.12, 1.15, 3.0, "Shirts", _style.cycle_top.bind(-1), _style.cycle_top.bind(1))
	_choice_row(x, -0.18, 1.15, -2.0, bottom, _style.cycle_bottom.bind(-1), _style.cycle_bottom.bind(1))
	_shuffle_button(x, -0.52, _shuffle_clothes)


func _build_name() -> void:
	if _typing:
		_build_type_name()
	else:
		_build_pick_name()


func _build_type_name() -> void:
	var panel := _name_panel(-0.28, -0.02, 1.35, 1.28)
	var title := _panel_label(panel, "Please type your name:", 0.02, 0.04, 0.96, 0.16, Color(1, 0.92, 0.15), 0.055)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var field := Panel.new()
	field.anchor_left = 0.12
	field.anchor_right = 0.88
	field.anchor_top = 0.18
	field.anchor_bottom = 0.32
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.98, 0.98, 0.98)
	plate.set_corner_radius_all(4)
	field.add_theme_stylebox_override("panel", plate)
	panel.add_child(field)
	_name_edit = LineEdit.new()
	_name_edit.set_anchors_preset(Control.PRESET_FULL_RECT)
	_name_edit.offset_left = 8
	_name_edit.offset_right = -8
	_name_edit.text = _style.display_name() if _style and _style.display_name() != "Unnamed Toon" else ""
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.max_length = 24
	_name_edit.add_theme_font_override("font", ToonGui.font())
	_name_edit.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1))
	_name_edit.add_theme_color_override("caret_color", Color(0.08, 0.08, 0.1))
	_name_edit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_name_edit.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_name_edit.text_changed.connect(_on_typed_name)
	_name_edit.text_submitted.connect(func(_text: String) -> void:
		_on_typed_name(_name_edit.text)
	)
	field.add_child(_name_edit)
	_panel_label(panel, "All new names must be\napproved by the Toon Council.", 0.08, 0.34, 0.92, 0.52, Color(1, 0.92, 0.15), 0.042)
	_panel_label(panel, "Be creative and remember:\nno Disney-related names, please.", 0.08, 0.50, 0.92, 0.68, Color(1, 0.95, 0.35), 0.038)
	_yellow_button(panel, "Submit", 0.22, 0.70, 0.78, 0.82, func() -> void:
		_on_typed_name(_name_edit.text if _name_edit else "")
	)
	_yellow_button(panel, "Pick-A-Name", 0.18, 0.84, 0.82, 0.96, func() -> void:
		_typing = false
		_load_name_lists()
		_show_shop()
	)


func _build_pick_name() -> void:
	_load_name_lists()
	var panel := _name_panel(-0.32, -0.02, 1.55, 1.32)
	var result := _panel_label(panel, _picked_name(), 0.04, 0.02, 0.96, 0.16, Color(1, 0.95, 0.4), 0.05)
	result.name = "PickedName"
	_name_column(panel, "Title", 0.04, _titles, _title_i, _title_on, _set_title)
	_name_column(panel, "First", 0.36, _firsts, _first_i, _first_on, _set_first)
	_name_column(panel, "Last", 0.68, _last_choices(), _last_choice_index(), _last_on, _set_last)
	_yellow_button(panel, "Shuffle", 0.08, 0.84, 0.46, 0.96, _shuffle_name)
	_yellow_button(panel, "Type-A-Name", 0.52, 0.84, 0.92, 0.96, func() -> void:
		_typing = true
		_show_shop()
	)


func _name_panel(x: float, z: float, width: float, height: float) -> Control:
	var panel := Panel.new()
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.16, 0.62, 0.98)
	plate.border_color = Color(0.05, 0.28, 0.62)
	plate.set_border_width_all(8)
	plate.set_corner_radius_all(26)
	plate.shadow_color = Color(0, 0, 0, 0.25)
	plate.shadow_size = 8
	panel.add_theme_stylebox_override("panel", plate)
	_shop_box.add_child(panel)
	_track(panel, x, z, width, height)
	return panel


func _panel_label(panel: Control, text: String, left: float, top: float, right: float, bottom: float, color: Color, scale: float) -> Label:
	var label := Label.new()
	label.text = text
	label.anchor_left = left
	label.anchor_top = top
	label.anchor_right = right
	label.anchor_bottom = bottom
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	panel.resized.connect(func() -> void:
		var px := int(panel.size.y * scale)
		ToonGui.style_label(label, color, px, Color(0.05, 0.15, 0.35), maxi(px / 10, 1))
	)
	return label


func _yellow_button(panel: Control, caption: String, left: float, top: float, right: float, bottom: float, action: Callable) -> void:
	var button := TextureButton.new()
	button.texture_normal = preload("res://assets/toons/gui/QuitBtn_UP.png")
	button.texture_pressed = preload("res://assets/toons/gui/QuitBtn_DN.png")
	button.texture_hover = preload("res://assets/toons/gui/QuitBtn_RLVR.png")
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.anchor_left = left
	button.anchor_top = top
	button.anchor_right = right
	button.anchor_bottom = bottom
	button.offset_left = 8
	button.offset_top = 4
	button.offset_right = -8
	button.offset_bottom = -4
	button.pressed.connect(action)
	panel.add_child(button)
	var label := Label.new()
	label.text = caption
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	button.resized.connect(func() -> void:
		ToonGui.style_label(label, Color(0.12, 0.1, 0.08), int(button.size.y * 0.42), Color(1, 1, 1, 0), 0)
	)


func _name_column(panel: Control, caption: String, left: float, values: PackedStringArray, index: int, enabled: bool, changed: Callable) -> void:
	var box := VBoxContainer.new()
	box.anchor_left = left
	box.anchor_right = left + 0.28
	box.anchor_top = 0.18
	box.anchor_bottom = 0.80
	panel.add_child(box)
	var header := Button.new()
	header.toggle_mode = true
	header.button_pressed = enabled
	header.text = caption
	header.toggled.connect(func(on: bool) -> void:
		changed.call("toggle", on)
	)
	box.add_child(header)
	var up := Button.new()
	up.text = "Up"
	up.pressed.connect(func() -> void:
		changed.call("step", -1)
	)
	box.add_child(up)
	var value := Label.new()
	value.text = _at(values, index) if enabled else ""
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(value)
	var down := Button.new()
	down.text = "Down"
	down.pressed.connect(func() -> void:
		changed.call("step", 1)
	)
	box.add_child(down)
	panel.resized.connect(func() -> void:
		var px := int(panel.size.y * 0.04)
		ToonGui.style_label(value, Color.WHITE, px, _OUTLINE, maxi(px / 8, 1))
		header.add_theme_font_override("font", ToonGui.font())
		header.add_theme_font_size_override("font_size", px)
	)


func _choice_row(x: float, z: float, scale: float, rot: float, caption: String, previous: Callable, next: Callable) -> void:
	var width := 0.92 * scale
	var height := 0.30 * scale
	var frame := TextureRect.new()
	frame.texture = preload("res://assets/toons/gui/tt_t_gui_mat_shuffleFrame.png")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_box.add_child(frame)
	_track(frame, x, z, width, height, rot)
	var label := Label.new()
	label.text = caption
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(label)
	frame.resized.connect(func() -> void:
		var px := int(frame.size.y * 0.42)
		ToonGui.style_label(label, Color.WHITE, px, _OUTLINE, maxi(px / 7, 2))
	)
	var arrow_w := height * 0.85
	_arrow_button(x - width * 0.36, z, arrow_w, false, previous, rot)
	_arrow_button(x + width * 0.36, z, arrow_w, true, next, rot)


func _shuffle_button(x: float, z: float, action: Callable) -> void:
	var button := TextureButton.new()
	button.texture_normal = preload("res://assets/toons/gui/tt_t_gui_mat_shuffleUp.png")
	button.texture_pressed = preload("res://assets/toons/gui/tt_t_gui_mat_shuffleDown.png")
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.pressed.connect(action)
	_shop_box.add_child(button)
	_track(button, x, z, 0.72, 0.22)
	var label := Label.new()
	label.text = "Shuffle"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	button.resized.connect(func() -> void:
		ToonGui.style_label(label, Color.WHITE, int(button.size.y * 0.46), _OUTLINE, maxi(int(button.size.y * 0.08), 2))
	)


func _arrow_button(x: float, z: float, size: float, flip: bool, action: Callable, rot: float) -> void:
	var box := Control.new()
	_shop_box.add_child(box)
	_track(box, x, z, size, size, rot)
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
		if _style == null:
			return
		action.call()
		_pose_toon()
		if _shop == 3:
			_show_shop()
	)
	box.add_child(button)


func _rotate_button(left: bool) -> Control:
	var box := Control.new()
	var image := TextureRect.new()
	image.texture = preload("res://assets/toons/gui/tt_t_gui_mat_arrowRotateUp.png")
	image.flip_h = left
	image.set_anchors_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(image)
	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	var direction := 1.6 if left else -1.6
	button.button_down.connect(func() -> void: _spin = direction)
	button.button_up.connect(func() -> void: _spin = 0.0)
	box.add_child(button)
	_track(box, -0.34 if left else 0.34, -0.62, 0.28, 0.28)
	return box


func _layout() -> void:
	if size.y < 2.0:
		return
	var edge := _aspect()
	_move(_back, edge - 0.52, -0.90)
	_move(_next, edge - 0.22, -0.90)
	for item in _placed:
		var control: Control = item[0]
		if control == _back or control == _next:
			continue
		if control.name == "Cancel":
			_move(control, -edge + 0.24, -0.90)
	for item in _placed:
		var control: Control = item[0]
		if not is_instance_valid(control):
			continue
		ToonGui.place(control, size, item[1], item[2], item[3], item[4])
		control.rotation_degrees = item[5]
	if _slide and not _transitioning:
		_slide.position = Vector2.ZERO
		_slide.size = size
	elif _slide:
		_slide.size = size
	if _title:
		_title.position = Vector2(0, size.y * 0.012)
		_title.size = Vector2(size.x, size.y * 0.12)
		var px := int(_TITLE_SCALES[_shop] * size.y * 0.5)
		ToonGui.style_title(_title, _TITLE_COLORS[_shop], px)
	if _name_edit:
		_name_edit.add_theme_font_size_override("font_size", int(size.y * 0.035))


func _move(control: Control, x: float, z: float) -> void:
	for item in _placed:
		if item[0] == control:
			item[1] = x
			item[2] = z
			return


func _track(control: Control, x: float, z: float, width: float, height: float, rot: float = 0.0) -> void:
	_placed.append([control, x, z, width, height, rot])


func _right(margin: float) -> float:
	return _aspect() - margin


func _aspect() -> float:
	return size.x / maxf(size.y, 1.0)


func _cycle_head(step: int) -> void:
	var heads := _all_heads()
	var index := heads.find(_style.head)
	if index < 0:
		index = 0
	_style.head = String(heads[posmod(index + step, heads.size())])
	_refresh()


func _all_heads() -> PackedStringArray:
	var heads := PackedStringArray()
	for species_code in ToonStyle.SPECIES:
		for head in ToonStyle.heads_for(species_code):
			heads.append(String(head))
	return heads


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
	var index := clampi(current, 1, 24) - 1
	return posmod(index + step, 24) + 1


func _shuffle_body() -> void:
	if _style == null:
		return
	var heads := _all_heads()
	_style.head = String(heads[randi() % heads.size()])
	var bottom := "d" if _style.wears_skirt() else "s"
	_style.torso = ToonStyle.SIZES[randi() % 3] + bottom
	_style.legs = ToonStyle.SIZES[randi() % 3]
	_refresh()


func _shuffle_color() -> void:
	if _style == null:
		return
	_style.head_color = 1 + randi() % 24
	_style.arm_color = 1 + randi() % 24
	_style.leg_color = 1 + randi() % 24
	_refresh()


func _shuffle_clothes() -> void:
	if _style == null:
		return
	var tops := ToonStyle.tops_for(_style.gender)
	var top: Array = tops[randi() % tops.size()]
	_style.top_tex = int(top[0])
	_style.top_color = int(top[1])
	var bottoms := ToonStyle.bottoms_for(_style.gender)
	var bottom: Array = bottoms[randi() % bottoms.size()]
	_style.bot_tex = int(bottom[0])
	_style.bot_color = int(bottom[1])
	_style.torso = ToonStyle.SIZES[_style.torso_size()] + ("d" if bool(bottom[2]) else "s")
	_show_shop()


func _refresh() -> void:
	_pose_toon()


func _place_camera(camera: Camera3D) -> void:
	# Original camera sits at Panda (-5.7, -12.3501, 2.15). On a 4:3 screen
	# its 52 degree horizontal view is about 40 degrees tall, which is what
	# frames the toon. Widescreen keeps that vertical view and the aim is the
	# toon's chest, so the body sits in the middle instead of off to one side.
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.fov = 40.0
	camera.position = Vector3(-5.7, 2.15, 12.3501)
	camera.look_at(Vector3(-1.62, 1.45, 3.49))


func _on_back() -> void:
	if _transitioning or _shop == 0:
		return
	_transition_to(_shop - 1)


func _transition_to(target: int) -> void:
	if _transitioning or target == _shop:
		return
	_transitioning = true
	var forward := target > _shop
	# Forward and back are the menu whooshes. Body, color, and clothes also
	# play the sting for that shop. The room squishes away and the next one
	# drops in, which is when a crash plays.
	_play_sfx(_SFX_FWD if forward else _SFX_BACK)
	_play_sfx(_SFX_ENTER[target])
	var leaving := _room_nodes(_shop)
	var arriving := _room_nodes(target)
	for node in arriving:
		node.scale = Vector3.ONE
		node.position = Vector3(0, 6.5, 0)
		node.visible = true
	var room := create_tween()
	room.set_parallel(true)
	for node in leaving:
		room.tween_property(node, "scale", Vector3(1, 0.02, 1), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for node in arriving:
		room.tween_property(node, "position:y", 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	room.chain().tween_callback(_play_crash)
	var exit_x := -size.x if forward else size.x
	var enter_x := -exit_x
	var gui := create_tween()
	gui.tween_property(_slide, "position:x", exit_x, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	gui.tween_callback(func() -> void:
		for node in leaving:
			node.visible = false
			node.scale = Vector3.ONE
			node.position = Vector3.ZERO
		_shop = target
		_show_shop()
		_slide.position.x = enter_x
	)
	gui.tween_property(_slide, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	gui.tween_callback(func() -> void:
		_transitioning = false
	)


func _room_nodes(shop: int) -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	for group_name in _ROOMS[shop]:
		var group := _find(_room, group_name)
		if group:
			nodes.append(group)
	return nodes


func _play_crash() -> void:
	_play_sfx(_SFX_CRASH[randi() % _SFX_CRASH.size()])


func _play_sfx(path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _on_next() -> void:
	if _style == null or _transitioning:
		return
	if _shop < _TITLES.size() - 1:
		_transition_to(_shop + 1)
		return
	_style.first_name = _style.first_name.strip_edges()
	_style.last_name = _style.last_name.strip_edges()
	if _style.first_name.is_empty() and _style.last_name.is_empty():
		_title.text = "TYPE  A  NAME"
		return
	ToonRoster.set_slot(ToonRoster.pending_slot, _style)
	get_tree().change_scene_to_file(PICK_SCENE)


func _on_typed_name(value: String) -> void:
	if _style == null:
		return
	var cleaned := _clean_name(value)
	if _name_edit and cleaned != _name_edit.text:
		_name_edit.text = cleaned
		_name_edit.caret_column = cleaned.length()
	var parts := cleaned.split(" ", false)
	if parts.is_empty():
		_style.first_name = ""
		_style.last_name = ""
	elif parts.size() == 1:
		_style.first_name = parts[0]
		_style.last_name = ""
	else:
		_style.first_name = parts[0]
		_style.last_name = " ".join(parts.slice(1))


func _clean_name(value: String) -> String:
	var cleaned := ""
	for index in value.length():
		var letter := value[index]
		if (letter >= "A" and letter <= "Z") or (letter >= "a" and letter <= "z") or letter == " " or letter == "'" or letter == "-" or letter == ".":
			cleaned += letter
	return cleaned.substr(0, 24)


func _load_name_lists() -> void:
	var gender := "m" if _style == null else _style.gender
	if gender == _name_gender and not _titles.is_empty():
		return
	_name_gender = gender
	_titles = ToonNames.titles(gender)
	_firsts = ToonNames.firsts(gender)
	_prefixes = ToonNames.prefixes()
	_suffixes = ToonNames.suffixes()
	_title_i = randi() % maxi(_titles.size(), 1)
	_first_i = randi() % maxi(_firsts.size(), 1)
	_prefix_i = randi() % maxi(_prefixes.size(), 1)
	_suffix_i = randi() % maxi(_suffixes.size(), 1)


func _picked_name() -> String:
	var title := _at(_titles, _title_i) if _title_on else ""
	var first := _at(_firsts, _first_i) if _first_on else ""
	var last := ToonNames.last_name(_at(_prefixes, _prefix_i), _at(_suffixes, _suffix_i)) if _last_on else ""
	var full := ToonNames.join_name(title, first, last)
	return full if not full.is_empty() else " "
func _apply_picked() -> void:
	if _style == null:
		return
	var title := _at(_titles, _title_i) if _title_on else ""
	var first := _at(_firsts, _first_i) if _first_on else ""
	_style.first_name = ToonNames.join_name(title, first, "")
	_style.last_name = ToonNames.last_name(_at(_prefixes, _prefix_i), _at(_suffixes, _suffix_i)) if _last_on else ""


func _set_title(kind: String, value: Variant) -> void:
	if kind == "toggle":
		_title_on = bool(value)
	else:
		_title_i = posmod(_title_i + int(value), maxi(_titles.size(), 1))
	_apply_picked()
	_show_shop()


func _set_first(kind: String, value: Variant) -> void:
	if kind == "toggle":
		_first_on = bool(value)
		if not _first_on and not _last_on:
			_last_on = true
	else:
		_first_i = posmod(_first_i + int(value), maxi(_firsts.size(), 1))
	_apply_picked()
	_show_shop()


func _set_last(kind: String, value: Variant) -> void:
	if kind == "toggle":
		_last_on = bool(value)
		if not _first_on and not _last_on:
			_first_on = true
	else:
		var count := maxi(_prefixes.size() * maxi(_suffixes.size(), 1), 1)
		var index := posmod(_last_choice_index() + int(value), count)
		_prefix_i = index / maxi(_suffixes.size(), 1)
		_suffix_i = index % maxi(_suffixes.size(), 1)
	_apply_picked()
	_show_shop()


func _shuffle_name() -> void:
	_title_on = randf() < 0.35
	_first_on = true
	_last_on = true
	_title_i = randi() % maxi(_titles.size(), 1)
	_first_i = randi() % maxi(_firsts.size(), 1)
	_prefix_i = randi() % maxi(_prefixes.size(), 1)
	_suffix_i = randi() % maxi(_suffixes.size(), 1)
	_apply_picked()
	_show_shop()


func _last_choices() -> PackedStringArray:
	return PackedStringArray([ToonNames.last_name(_at(_prefixes, _prefix_i), _at(_suffixes, _suffix_i))])


func _last_choice_index() -> int:
	return _prefix_i * maxi(_suffixes.size(), 1) + _suffix_i


func _at(values: PackedStringArray, index: int) -> String:
	if values.is_empty():
		return ""
	return values[posmod(index, values.size())]


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
