extends Control

## Make a Toon in the original room: boy or girl, body, color, clothes, name.
## The toon is the original head, torso, and legs. Done saves the slot.

const PICK_SCENE := "res://scenes/toons/pick_a_toon.tscn"
const _CHOOSER := preload("res://scenes/toons/pick_a_toon.gd")
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
## roomAnim_roomDrop, roomSquish, and propSquish, 24 fps. The egg channel k
## scales Panda Z only. The room root turns that into Godot's up axis, so on
## these pieces it is local Z. The drop hits the floor on frame 5.
const _DROP_Y: PackedFloat32Array = [15, 15, 14.6828, 12.8618, 8.38508, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
const _DROP_SCALE: PackedFloat32Array = [1, 1, 1, 1, 1, 0.757422, 0.805925, 0.900352, 0.998161, 1.05681, 1.03752, 0.973827, 0.931636, 0.940088, 0.970044, 1, 1, 1, 1, 1, 1]
const _SQUISH_Y: PackedFloat32Array = [0, 0, 0, 0, 0, -0.1, -0.1, -0.1, -0.1, -0.1, -0.1, -0.1, -0.1, -0.1, -0.1, -0.1, -0.1, -0.1, -0.1, -0.1, -0.1]
const _SQUISH_SCALE: PackedFloat32Array = [1, 1, 0.978795, 0.857423, 0.558954, 0.001, 0.001, 0.001, 0.001, 0.001, 0.001, 0.001, 0.001, 0.001, 0.001, 0.001, 0.001, 0.001, 0.001, 0.001, 0.001]
const _PROP_Y: PackedFloat32Array = [0, 0, 0, 0, 0, -0.637391, -0.637391, -0.637391, -0.637391, -0.637391, -0.637391, -0.637391, -0.637391, -0.637391, -0.637391, -0.637391, -0.637391, -0.637391, -0.637391, -0.637391, -0.637391]
const _PROP_SCALE: PackedFloat32Array = [1, 1, 0.980802, 0.961603, 0.816513, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
const _ROOM_PARENTS: PackedStringArray = ["genderAll", "bodyAll", "colorAll", "cothAll", "nameAll"]
const _ROOM_WALLS: PackedStringArray = ["genderWalls", "bodyWalls", "colorWalls", "clothWalls", "nameWalls"]
const _ROOM_PROPS: PackedStringArray = ["genderProps", "bodyProps", "colorProps", "clothProps", "nameProps"]
const _SPECIES_HEADS: Array[Texture2D] = [
	preload("res://assets/gui/tutorial/laff/doghead.png"),
	preload("res://assets/gui/tutorial/laff/cathead.png"),
	preload("res://assets/gui/tutorial/laff/horsehead.png"),
	preload("res://assets/gui/tutorial/laff/mousehead.png"),
	preload("res://assets/gui/tutorial/laff/bunnyhead.png"),
	preload("res://assets/gui/tutorial/laff/duckhead.png"),
	preload("res://assets/gui/tutorial/laff/monkeyhead.png"),
	preload("res://assets/gui/tutorial/laff/bearhead.png"),
	preload("res://assets/gui/tutorial/laff/pighead.png"),
]

var _shop := 0
var _style: ToonStyle
var _actor: ToonActor
var _room: Node3D
var _viewport: SubViewport
var _spotlight: MeshInstance3D
var _slide: Control
var _shop_box: Control
var _dropping := false
var _leaving := false
var _room_tween: Tween
var _title: Label
var _next: TextureButton
var _next_caption: Label
var _cancel_caption: Label
var _back_caption: Label
var _back: Control
var _rotate_left: Control
var _rotate_right: Control
var _spin := 0.0
var _placed: Array = []
var _typing := false
var _submitted_name := ""
var _name_edit: LineEdit
var _name_view: Label
var _name_caret: ColorRect
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
var _body_key := ""
var _mesh_key := ""
## 0 stays put. -1 rides the left edge and 1 rides the right edge.
var _dock := 0
var _name_panel: Control
var _scan_left := 1.0
var _toon_left_cached := NAN
var _gap_view := Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_view()
	_build_chrome()
	_show_shop()
	resized.connect(_layout)
	_layout()
	_fade_in()
	var player := ToonAudio.music_player()
	player.stream = preload("res://assets/toons/audio/create_a_toon.ogg")
	player.volume_db = -4.0
	player.autoplay = true
	add_child(player)


func _process(delta: float) -> void:
	if _actor and _style:
		# The original Make a Toon toon stands in neutral the whole time.
		_actor.set_locomotion(0.0, false, false, delta)
	if _spin != 0.0 and _actor:
		_actor.global_rotate(Vector3.UP, _spin * delta)
	_aim_spotlight()
	_blink_name_caret()


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
	_claim_spotlight()
	# Leftover export cards: an untextured gray quad, and the camera helper
	# that was sitting in front of the clothing rack.
	for leftover_name in ["polySurface1", "camera_arrow"]:
		var leftover := _find(_room, leftover_name)
		if leftover:
			leftover.visible = false
	_actor = ToonActor.new()
	_actor.load_extra_clips = false
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

	# Bottom bar is at (0.01, -0.86). Cancel is a 0.16 card. Next and Back use
	# the wider arrow card at scale 0.3, which lands on the same 0.16 size.
	var cancel := _image_button(
		preload("res://assets/toons/gui/tt_t_gui_mat_closeUp.png"),
		preload("res://assets/toons/gui/tt_t_gui_mat_closeDown.png")
	)
	cancel.name = "Cancel"
	cancel.pressed.connect(_cancel_to_chooser)
	add_child(cancel)
	_dock = -1
	_track(cancel, -1.169, -0.871, 0.16, 0.16)
	_hover_grow(cancel, 0.7 / 0.6)
	_cancel_caption = _hover_caption(cancel, "Cancel", -1.169, -0.756)

	_back = _flipped_arrow()
	add_child(_back)
	_dock = 1
	_track(_back, 0.835, -0.878, 0.16, 0.16)
	var back_hit := _back.get_child(1) as BaseButton
	back_hit.mouse_entered.connect(func() -> void: _back.scale = Vector2(0.35 / 0.3, 0.35 / 0.3))
	back_hit.mouse_exited.connect(func() -> void: _back.scale = Vector2.ONE)
	_back_caption = _hover_caption(back_hit, "Back", 0.835, -0.763)

	_next = _image_button(
		preload("res://assets/toons/gui/tt_t_gui_mat_nextUp.png"),
		preload("res://assets/toons/gui/tt_t_gui_mat_nextDown.png")
	)
	_next.pressed.connect(_on_next)
	add_child(_next)
	_track(_next, 1.175, -0.878, 0.16, 0.16)
	_hover_grow(_next, 0.35 / 0.3)
	_next_caption = _hover_caption(_next, "Next", 1.175, -0.763)

	_dock = 0
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
	if _next_caption:
		_next_caption.text = "Done" if done else "Next"
	_back.visible = _shop > 0
	if _back_caption:
		_back_caption.visible = _back.visible
		if not _back.visible:
			_back_caption.modulate.a = 0.0
	var spinning := _shop > 0 and _shop < 4
	_rotate_left.visible = spinning
	_rotate_right.visible = spinning
	if not _dropping:
		_settle_pieces()
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
	_place_spotlight()
	_layout()


func _show_room(shop: int) -> void:
	for group_name in _ROOM_PARENTS:
		var group := _find(_room, group_name)
		if group:
			group.visible = false
	for group_name in _ROOM_WALLS:
		var group := _find(_room, group_name)
		if group:
			group.visible = false
	for group_name in _ROOM_PROPS:
		var group := _find(_room, group_name)
		if group:
			group.visible = false
	_reveal_room(shop)


func _reveal_room(shop: int) -> void:
	var parent := _find(_room, _ROOM_PARENTS[shop])
	if parent:
		parent.visible = true
	var walls := _find(_room, _ROOM_WALLS[shop])
	var props := _find(_room, _ROOM_PROPS[shop])
	if walls:
		walls.visible = true
	if props:
		props.visible = true


func _pose_toon() -> void:
	if _actor == null:
		return
	if _shop == 4:
		_actor.position = Vector3(1.55, 0.0, 4.05)
	else:
		_actor.position = Vector3(-1.62, 0.0, 3.49)
	if _style == null:
		return
	var mesh := "%s|%s|%s" % [_style.head, _style.torso, _style.legs]
	var paint := "%d|%d|%d|%d|%d|%d|%d" % [
		_style.top_tex, _style.top_color, _style.bot_tex, _style.bot_color,
		_style.head_color, _style.arm_color, _style.leg_color,
	]
	var key := mesh + "|" + paint
	if mesh != _mesh_key:
		_mesh_key = mesh
		_body_key = key
		_actor.swap_style(_style)
	elif key != _body_key:
		_body_key = key
		_actor.recolor(_style)
	_stand_toon()


func _stand_toon() -> void:
	if _actor == null or _style == null:
		return
	var extra := deg_to_rad(-55.0) if _shop == 4 else 0.0
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	upright = upright.rotated(Vector3.UP, PI + extra)
	_actor.transform.basis = upright.scaled(Vector3.ONE * _style.body_scale())


func _build_gender() -> void:
	_dock = 0
	var boy := _image_button(
		preload("res://assets/toons/gui/tt_t_gui_mat_boyUp.png"),
		preload("res://assets/toons/gui/tt_t_gui_mat_boyDown.png")
	)
	boy.pressed.connect(_start_gender.bind("m"))
	_shop_box.add_child(boy)
	_track(boy, -0.4, -0.8, 0.32, 0.32)
	_hover_grow(boy, 0.7 / 0.6)
	_hover_caption(boy, "Boy", -0.4, -0.61)
	var girl := _image_button(
		preload("res://assets/toons/gui/tt_t_gui_mat_girlUp.png"),
		preload("res://assets/toons/gui/tt_t_gui_mat_girlDown.png")
	)
	girl.pressed.connect(_start_gender.bind("f"))
	_shop_box.add_child(girl)
	_track(girl, 0.4, -0.8, 0.32, 0.32)
	_hover_grow(girl, 0.7 / 0.6)
	_hover_caption(girl, "Girl", 0.4, -0.61)


func _start_gender(gender: String) -> void:
	_style = ToonStyle.random_body(gender)
	_pose_toon()
	_next.disabled = false


func _build_body() -> void:
	_dock = -1
	_species_heads()
	_dock = 1
	# BodyShop frames hang off (0.98, 0.416). Head, body, and legs stay on
	# their original cards. Species is the head grid, so that row is not repeated.
	_choice_row(0.98, 0.116, 0.9, 2.0, "Head", _cycle_head.bind(-1), _cycle_head.bind(1))
	_choice_row(0.98, -0.084, 0.9, -2.0, "Body", _cycle_torso.bind(-1), _cycle_torso.bind(1))
	_choice_row(0.98, -0.284, 0.9, 3.0, "Legs", _cycle_legs.bind(-1), _cycle_legs.bind(1))
	_shuffle_button(0.98, -0.584, _shuffle_body)


func _species_heads() -> void:
	var columns := 3
	for index in ToonStyle.SPECIES.size():
		var code := String(ToonStyle.SPECIES[index])
		var column := index % columns
		var row := index / columns
		var button := TextureButton.new()
		button.texture_normal = _SPECIES_HEADS[index]
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.focus_mode = Control.FOCUS_NONE
		var chosen := _style != null and _style.species() == code
		var fur := ToonStyle.fur_color(_style.head_color) if _style else Color.WHITE
		button.modulate = fur if chosen else fur.darkened(0.45)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.z_index = 2
		# Picking a head rebuilds this page inside the pressed handler, so the
		# click has to start on the menu itself before that button is removed.
		button.mouse_entered.connect(func() -> void:
			ToonGui.play_sfx(self, ToonGui.ROLLOVER_SFX)
		)
		button.button_down.connect(func() -> void:
			ToonGui.play_sfx(self, ToonGui.CLICK_SFX)
		)
		button.pressed.connect(_pick_species.bind(code))
		_shop_box.add_child(button)
		_track(button, -1.16 + float(column) * 0.24, 0.58 - float(row) * 0.26, 0.2, 0.2)
		if chosen:
			button.scale = Vector2(1.12, 1.12)


func _build_color() -> void:
	_dock = 1
	_choice_row(0.98, 0.343, 1.3, 0.0, "Toon Color", _cycle_all_color.bind(-1), _cycle_all_color.bind(1))
	_choice_row(0.98, 0.116, 0.9, 2.0, "Head", _cycle_part_color.bind("head", -1), _cycle_part_color.bind("head", 1))
	_choice_row(0.98, -0.084, 0.9, -2.0, "Body", _cycle_part_color.bind("arm", -1), _cycle_part_color.bind("arm", 1))
	_choice_row(0.98, -0.284, 0.9, 3.0, "Legs", _cycle_part_color.bind("leg", -1), _cycle_part_color.bind("leg", 1))
	_shuffle_button(0.98, -0.584, _shuffle_color)


func _build_clothes() -> void:
	_dock = 1
	var bottom := "Skirts" if _style != null and _style.gender == "f" else "Shorts"
	_choice_row(0.98, 0.016, 1.2, 3.0, "Shirts", _style.cycle_top.bind(-1), _style.cycle_top.bind(1))
	_choice_row(0.98, -0.234, 1.2, -2.0, bottom, _style.cycle_bottom.bind(-1), _style.cycle_bottom.bind(1))
	_shuffle_button(0.98, -0.584, _shuffle_clothes)


func _build_name() -> void:
	_dock = -1
	if _typing:
		_build_type_name()
	else:
		_build_pick_name()


func _build_type_name() -> void:
	var panel := _begin_panel(-0.42, -0.065, 1.40, 1.307)
	_name_panel = panel
	_place_art(panel, preload("res://assets/toons/gui/tt_t_gui_mat_typeNamePanel.png"))
	var ink := Color(1, 0.92, 0.15)
	# Fractions are measured on the panel card, so the words sit on the art
	# instead of floating in screen space.
	_panel_text(panel, "Please type your name:", 0.51, 0.15, 0.72, 0.07, ink, 0.055)
	_name_edit = LineEdit.new()
	_name_edit.text = ""
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.max_length = 24
	_name_edit.custom_minimum_size = Vector2.ZERO
	_name_edit.focus_mode = Control.FOCUS_ALL
	# The field keeps the keystrokes. The label draws them, so a long name can
	# break onto a second centered line the way the pick-a-name preview does.
	_name_edit.modulate = Color(1, 1, 1, 0)
	var blank := StyleBoxEmpty.new()
	_name_edit.add_theme_stylebox_override("normal", blank)
	_name_edit.add_theme_stylebox_override("focus", blank)
	_name_edit.add_theme_stylebox_override("read_only", blank)
	_name_edit.text_changed.connect(_on_typed_name)
	_name_edit.text_submitted.connect(func(_text: String) -> void:
		_on_typed_name(_name_edit.text)
	)
	_pin(panel, _name_edit, 0.51, 0.283, 0.42, 0.125)
	_name_view = Label.new()
	_name_view.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_view.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_name_view.add_theme_constant_override("line_spacing", 0)
	_name_view.gui_input.connect(_on_name_click)
	_pin(panel, _name_view, 0.51, 0.283, 0.42, 0.125)
	_name_caret = ColorRect.new()
	_name_caret.color = Color(0.08, 0.08, 0.1)
	_name_caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_caret.visible = false
	panel.add_child(_name_caret)
	_name_view.resized.connect(_refresh_typed_name)
	_panel_text(panel, "All new names must be\napproved by the Toon Council.", 0.51, 0.45, 0.72, 0.12, ink, 0.042)
	_panel_text(panel, "Be creative and remember:\nno Disney-related names, please.", 0.51, 0.58, 0.72, 0.11, Color(1, 0.95, 0.35), 0.034)
	_panel_socket(panel, "Submit", 0.508, 0.758, 0.336, 0.066, _submit_typed_name)
	_panel_socket(panel, "Pick-A-Name", 0.508, 0.859, 0.332, 0.066, func() -> void:
		_typing = false
		_load_name_lists()
		_show_shop()
	)
	_name_edit.grab_focus.call_deferred()


func _build_pick_name() -> void:
	_load_name_lists()
	var panel := _begin_panel(-0.42, -0.0301, 1.70, 1.587)
	_name_panel = panel
	_place_art(panel, preload("res://assets/toons/gui/tt_t_gui_mat_namePanel.png"))
	var result := _panel_text(panel, _picked_name(), 0.514, 0.217, 0.34, 0.10, Color(0.08, 0.08, 0.1), 0.036)
	result.name = "PickedName"
	var blue := Color(0.0, 0.25, 0.5)
	_panel_check(panel, 0.094, 0.336, _title_on, func() -> void: _set_title("toggle", not _title_on))
	_panel_text(panel, "Title", 0.20, 0.336, 0.16, 0.055, blue, 0.042, HORIZONTAL_ALIGNMENT_LEFT)
	_panel_check(panel, 0.332, 0.336, _first_on, func() -> void: _set_first("toggle", not _first_on))
	_panel_text(panel, "First", 0.44, 0.336, 0.16, 0.055, blue, 0.042, HORIZONTAL_ALIGNMENT_LEFT)
	_panel_check(panel, 0.688, 0.336, _last_on, func() -> void: _set_last("toggle", not _last_on))
	_panel_text(panel, "Last", 0.79, 0.336, 0.14, 0.055, blue, 0.042, HORIZONTAL_ALIGNMENT_LEFT)
	# Five rows at the original forceHeight, so the first and last names sit
	# near the arrows with the same gap the original list leaves.
	_panel_column(panel, 0.162, 0.513, 0.15, 0.189, Color(1.0, 0.8, 0.8), _titles, _title_i, _title_on, _set_title, HORIZONTAL_ALIGNMENT_CENTER)
	_panel_column(panel, 0.397, 0.513, 0.15, 0.189, Color(0.8, 1.0, 0.8), _firsts, _first_i, _first_on, _set_first, HORIZONTAL_ALIGNMENT_CENTER)
	_panel_column(panel, 0.633, 0.513, 0.15, 0.189, Color(0.8, 0.8, 1.0), _prefixes, _prefix_i, _last_on, _set_prefix, HORIZONTAL_ALIGNMENT_RIGHT)
	_panel_column(panel, 0.838, 0.513, 0.15, 0.189, Color(0.8, 0.8, 1.0), _suffixes, _suffix_i, _last_on, _set_suffix, HORIZONTAL_ALIGNMENT_LEFT)
	_panel_socket(panel, "Shuffle", 0.506, 0.730, 0.281, 0.059, _shuffle_name)
	_panel_socket(panel, "Type-A-Name", 0.506, 0.816, 0.281, 0.059, func() -> void:
		_typing = true
		_show_shop()
	)
	if _submitted_name.is_empty():
		_apply_picked()


func _begin_panel(x: float, z: float, width: float, height: float) -> Control:
	var panel := Control.new()
	_shop_box.add_child(panel)
	_track(panel, x, z, width, height)
	return panel


func _place_art(panel: Control, texture: Texture2D) -> void:
	var image := TextureRect.new()
	image.texture = texture
	image.set_anchors_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(image)


func _panel_label(panel: Control, text: String, left: float, top: float, right: float, bottom: float, color: Color, scale: float, outline: Color = Color(0.05, 0.15, 0.35)) -> Label:
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
		var outline_px := 0 if outline.a <= 0.0 else maxi(px / 10, 1)
		ToonGui.style_label(label, color, px, outline, outline_px)
	)
	return label


func _pin(host: Control, node: Control, cx: float, cy: float, w: float, h: float) -> void:
	host.add_child(node)
	node.anchor_left = cx - w * 0.5
	node.anchor_top = cy - h * 0.5
	node.anchor_right = cx + w * 0.5
	node.anchor_bottom = cy + h * 0.5
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0


func _panel_text(host: Control, text: String, cx: float, cy: float, w: float, h: float, color: Color, font_ratio: float, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pin(host, label, cx, cy, w, h)
	label.resized.connect(func() -> void:
		ToonGui.style_label(label, color, maxi(int(host.size.y * font_ratio), 1), Color(0, 0, 0, 0), 0)
	)
	return label


func _panel_socket(host: Control, caption: String, cx: float, cy: float, w: float, h: float, action: Callable) -> void:
	# cx/cy/w/h are the socket. The yellow art has a clear margin, so the
	# button is grown until that yellow lands on the socket.
	var button := TextureButton.new()
	button.texture_normal = preload("res://assets/toons/gui/tt_t_gui_mat_namePanelSquareUp.png")
	button.texture_pressed = preload("res://assets/toons/gui/tt_t_gui_mat_namePanelSquareDown.png")
	button.texture_hover = preload("res://assets/toons/gui/tt_t_gui_mat_namePanelSquareHover.png")
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2.ZERO
	button.z_index = 2
	button.pressed.connect(action)
	ToonGui.button_sounds(button)
	var art_w := 63.0
	var art_h := 31.0
	var yellow_w := 58.0 / art_w
	var yellow_h := 25.0 / art_h
	var box_w := w / yellow_w
	var box_h := h / yellow_h
	var box_cx := cx + (0.5 - 30.5 / art_w) * box_w
	var box_cy := cy + (0.5 - 15.0 / art_h) * box_h
	_pin(host, button, box_cx, box_cy, box_w, box_h)
	var label := Label.new()
	label.text = caption
	label.anchor_left = 2.0 / art_w
	label.anchor_top = 3.0 / art_h
	label.anchor_right = 60.0 / art_w
	label.anchor_bottom = 28.0 / art_h
	label.offset_left = 0.0
	label.offset_top = 0.0
	label.offset_right = 0.0
	label.offset_bottom = 0.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	button.resized.connect(func() -> void:
		ToonGui.style_label(label, Color(0.05, 0.16, 0.42), maxi(int(button.size.y * 0.42), 1), Color(1, 1, 1, 0), 0)
	)


func _panel_check(host: Control, cx: float, cy: float, on: bool, toggled: Callable) -> void:
	var mark := TextureButton.new()
	mark.texture_normal = preload("res://assets/toons/gui/tt_t_gui_mat_namePanelCircle.png")
	mark.ignore_texture_size = true
	mark.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	mark.focus_mode = Control.FOCUS_NONE
	mark.custom_minimum_size = Vector2.ZERO
	# The card already paints the empty dot. The green disk only covers it when the part is on.
	mark.modulate = Color(1, 1, 1, 1) if on else Color(1, 1, 1, 0)
	mark.pressed.connect(toggled)
	ToonGui.button_sounds(mark)
	_pin(host, mark, cx, cy, 0.048, 0.048)


func _panel_column(host: Control, cx: float, cy: float, w: float, h: float, tint: Color, values: PackedStringArray, index: int, enabled: bool, changed: Callable, align: HorizontalAlignment) -> void:
	# The window is 46 by 57 texels. One texel of overlap covers the filtered
	# edge without reaching the arrow grooves or closing the gap between the
	# two last-name columns.
	var back_w := 48.0 / 256.0
	var back_h := 59.0 / 256.0
	_column_back(host, cx, 132.5 / 256.0, back_w, back_h, tint)
	# The sockets are the dark grooves just outside the window, y 93–101 and 162–170.
	_column_cap(host, cx, 0.379, false, -1, enabled, changed)
	_column_cap(host, cx, 0.648, true, 1, enabled, changed)
	var row_h := h / 5.0
	var top := cy - h * 0.5
	for row in 5:
		var offset := row - 2
		var item_index := 0 if values.is_empty() else posmod(index + offset, values.size())
		var row_cy := top + row_h * (float(row) + 0.5)
		if offset == 0 and enabled:
			var mark := ColorRect.new()
			mark.color = Color(1.0, 0.0, 1.0, 0.45)
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_pin(host, mark, cx, row_cy, back_w, row_h * 1.05)
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.text = _at(values, item_index) if enabled else ""
		button.alignment = align
		button.disabled = not enabled or values.is_empty()
		var empty := StyleBoxEmpty.new()
		button.add_theme_stylebox_override("normal", empty)
		button.add_theme_stylebox_override("hover", empty)
		button.add_theme_stylebox_override("pressed", empty)
		button.add_theme_stylebox_override("disabled", empty)
		button.add_theme_stylebox_override("focus", empty)
		button.add_theme_color_override("font_hover_color", Color(1, 1, 0))
		button.add_theme_color_override("font_pressed_color", Color(0.5, 0.9, 1))
		button.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1))
		button.add_theme_color_override("font_disabled_color", Color(0.4, 0.8, 0.4, 0.0))
		button.pressed.connect(changed.bind("set", item_index))
		ToonGui.button_sounds(button)
		_pin(host, button, cx, row_cy, w, row_h)
		var row_button := button
		row_button.resized.connect(func() -> void:
			row_button.add_theme_font_override("font", ToonGui.font())
			row_button.add_theme_font_size_override("font_size", maxi(int(host.size.y * 0.034), 1))
			row_button.add_theme_constant_override("outline_size", 0)
		)
	if enabled:
		_column_wheel(host, cx, cy, 0.18, 0.24, changed)


func _column_back(host: Control, cx: float, cy: float, w: float, h: float, tint: Color) -> void:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", style)
	_pin(host, panel, cx, cy, w, h)
	panel.resized.connect(func() -> void:
		var radius := maxi(int(host.size.y * (4.0 / 256.0)), 2)
		style.set_corner_radius_all(radius)
	)


func _column_cap(host: Control, cx: float, cy: float, flip: bool, step: int, enabled: bool, changed: Callable) -> void:
	var cap := TextureButton.new()
	cap.texture_normal = preload("res://assets/toons/gui/tt_t_gui_mat_namePanelArrowUp.png")
	cap.texture_pressed = preload("res://assets/toons/gui/tt_t_gui_mat_namePanelArrowDown.png")
	cap.texture_hover = preload("res://assets/toons/gui/tt_t_gui_mat_namePanelArrowHover.png")
	cap.flip_v = flip
	cap.ignore_texture_size = true
	cap.stretch_mode = TextureButton.STRETCH_SCALE
	cap.focus_mode = Control.FOCUS_NONE
	cap.custom_minimum_size = Vector2.ZERO
	cap.disabled = not enabled
	if enabled:
		cap.pressed.connect(func() -> void: changed.call("step", step))
		ToonGui.button_sounds(cap)
	# The green dome is 77 by 18 inside a 95 by 31 card. The socket is about 36 by 9 texels.
	var box_w := 0.141 / (77.0 / 95.0)
	var box_h := 0.035 / (18.0 / 31.0)
	var box_cx := cx + (0.5 - 47.0 / 95.0) * box_w
	_pin(host, cap, box_cx, cy, box_w, box_h)


func _column_wheel(host: Control, cx: float, cy: float, w: float, h: float, changed: Callable) -> void:
	var strip := Control.new()
	strip.mouse_filter = Control.MOUSE_FILTER_PASS
	_pin(host, strip, cx, cy, w, h)
	strip.gui_input.connect(func(event: InputEvent) -> void:
		if not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
			return
		var button := event as InputEventMouseButton
		var step := 0
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			step = -1
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			step = 1
		if step == 0:
			return
		changed.call("step", step)
		strip.accept_event()
	)


func _choice_row(x: float, z: float, frame_scale: float, rot: float, caption: String, previous: Callable, next: Callable) -> void:
	# shuffleFrame is 0.875 by 0.3667, drawn at halfButtonScale 0.6, then the frame scale.
	var width := 0.875 * 0.6 * frame_scale
	var height := 0.3667 * 0.6 * frame_scale
	var frame := Control.new()
	_shop_box.add_child(frame)
	_track(frame, x, z, width, height, rot)
	var image := TextureRect.new()
	image.texture = preload("res://assets/toons/gui/tt_t_gui_mat_shuffleFrame.png")
	image.set_anchors_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(image)
	var label := Label.new()
	label.text = caption
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(label)
	frame.resized.connect(func() -> void:
		var px := int(0.0625 * frame_scale * size.y * 0.5)
		ToonGui.style_label(label, Color.WHITE, maxi(px, 1), _OUTLINE, maxi(px / 8, 1))
	)
	var arrow_w := 0.1 * 0.6 * frame_scale
	var arrow_h := 0.1833 * 0.6 * frame_scale
	var arrow_x := 0.2 * frame_scale
	_arrow_button(x - arrow_x, z, arrow_w, arrow_h, false, previous, rot)
	_arrow_button(x + arrow_x, z, arrow_w, arrow_h, true, next, rot)


func _shuffle_button(x: float, z: float, action: Callable) -> void:
	var button := TextureButton.new()
	button.texture_normal = preload("res://assets/toons/gui/tt_t_gui_mat_shuffleUp.png")
	button.texture_pressed = preload("res://assets/toons/gui/tt_t_gui_mat_shuffleDown.png")
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	ToonGui.button_sounds(button)
	_shop_box.add_child(button)
	_track(button, x, z, 0.30, 0.1275)
	_hover_grow(button, 1.05)
	var label := Label.new()
	label.text = "Shuffle"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	button.resized.connect(func() -> void:
		var px := int(0.08 * size.y * 0.5)
		ToonGui.style_label(label, Color.WHITE, maxi(px, 1), _OUTLINE, maxi(px / 8, 1))
	)


func _arrow_button(x: float, z: float, width: float, height: float, flip: bool, action: Callable, rot: float) -> void:
	var box := Control.new()
	_shop_box.add_child(box)
	_track(box, x, z, width, height, rot)
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
	ToonGui.button_sounds(button)
	# halfButtonScale is 0.6 and the hover scale is 0.7.
	button.mouse_entered.connect(func() -> void: box.scale = Vector2(0.7 / 0.6, 0.7 / 0.6))
	button.mouse_exited.connect(func() -> void: box.scale = Vector2.ONE)
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
	button.button_down.connect(func() -> void:
		_spin = direction
		ToonGui.play_sfx(button, ToonGui.CLICK_SFX)
	)
	button.button_up.connect(func() -> void: _spin = 0.0)
	button.mouse_entered.connect(func() -> void:
		box.scale = Vector2(1.25, 1.25)
		ToonGui.play_sfx(button, ToonGui.ROLLOVER_SFX)
	)
	button.mouse_exited.connect(func() -> void: box.scale = Vector2.ONE)
	box.add_child(button)
	_track(box, -0.319 if left else 0.320, -0.657 if left else -0.654, 0.107, 0.107)
	return box


func _name_gap_x(panel_width: float) -> float:
	# Halfway between the left edge and the toon's left side. The toon keeps
	# idling, so the edge is measured once per window size. Measuring again on
	# every scroll walks the posed mesh and slides the whole panel.
	var edge := size.x / maxf(size.y, 1.0)
	var half := panel_width * 0.5
	if _gap_view != size or is_nan(_toon_left_cached):
		_gap_view = size
		_toon_left_cached = _toon_left_aspect()
	var toon_left := _toon_left_cached
	var x := (toon_left - edge) * 0.5
	var low := -edge + half + 0.03
	var high := toon_left - half - 0.03
	if high >= low:
		x = clampf(x, low, high)
	return x


func _toon_left_aspect() -> float:
	var edge := size.x / maxf(size.y, 1.0)
	var camera := _viewport.get_node_or_null("MatCamera") as Camera3D if _viewport else null
	if camera == null or _actor == null or _viewport.size.x < 2:
		return edge * 0.35
	_scan_left = 1.0
	_scan_toon(_actor, camera)
	if _scan_left >= 0.98:
		return edge * 0.35
	var unit := size.y * 0.5
	return (_scan_left * size.x - size.x * 0.5) / unit


func _scan_toon(node: Node, camera: Camera3D) -> void:
	if String(node.name) == "drop_shadow":
		return
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh:
			var bounds := mesh_node.global_transform * mesh_node.mesh.get_aabb()
			var vp := Vector2(_viewport.size)
			for corner in 8:
				var point := bounds.get_endpoint(corner)
				if camera.is_position_behind(point):
					continue
				_scan_left = minf(_scan_left, camera.unproject_position(point).x / vp.x)
	for child in node.get_children():
		_scan_toon(child, camera)


func _layout() -> void:
	if size.y < 2.0:
		return
	# The stored coordinates sit on a 4:3 screen. Wider windows push the side
	# columns out so they keep that same gap from the screen edge.
	var extra := maxf(size.x / size.y - 4.0 / 3.0, 0.0)
	for item in _placed:
		var control: Control = item[0]
		if not is_instance_valid(control):
			continue
		var dock := int(item[6]) if item.size() > 6 else 0
		var x := float(item[1]) + float(dock) * extra
		if control == _name_panel:
			x = _name_gap_x(float(item[3]))
		ToonGui.place(control, size, x, item[2], item[3], item[4])
		control.rotation_degrees = item[5]
	if _slide:
		_slide.position = Vector2.ZERO
		_slide.size = size
	if _title:
		_title.position = Vector2(0, size.y * 0.012)
		_title.size = Vector2(size.x, size.y * 0.12)
		var px := int(_TITLE_SCALES[_shop] * size.y * 0.5)
		ToonGui.style_title(_title, _TITLE_COLORS[_shop], px)
	_refresh_typed_name()


func _track(control: Control, x: float, z: float, width: float, height: float, rot: float = 0.0) -> void:
	_placed.append([control, x, z, width, height, rot, _dock])


func _cycle_head(step: int) -> void:
	var heads := ToonStyle.heads_for(_style.species())
	var index := 0
	for item in heads.size():
		if String(heads[item]) == _style.head:
			index = item
	_style.head = String(heads[posmod(index + step, heads.size())])
	_refresh()


func _pick_species(code: String) -> void:
	if _style == null:
		return
	var suffix := _style.head.substr(1)
	var heads := ToonStyle.heads_for(code)
	var chosen := String(heads[0])
	for head in heads:
		if String(head).substr(1) == suffix:
			chosen = String(head)
			break
	_style.head = chosen
	_refresh()
	_show_shop()


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
	var code := String(ToonStyle.SPECIES[randi() % ToonStyle.SPECIES.size()])
	var heads := ToonStyle.heads_for(code)
	_style.head = String(heads[randi() % heads.size()])
	var bottom := "d" if _style.wears_skirt() else "s"
	_style.torso = ToonStyle.SIZES[randi() % 3] + bottom
	_style.legs = ToonStyle.SIZES[randi() % 3]
	_show_shop()


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


func _claim_spotlight() -> void:
	var card := _find(_room, "spotlight__billboard") as MeshInstance3D
	if card == null:
		return
	var parent := card.get_parent()
	if parent:
		parent.remove_child(card)
	_viewport.add_child(card)
	card.visible = true
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://scenes/toons/mat_spotlight.gdshader")
	card.material_override = material
	_spotlight = card
	_place_spotlight()


func _place_spotlight() -> void:
	if _spotlight == null or not is_instance_valid(_spotlight):
		return
	# The beam is centered on the mark the toon uses, including the boy-or-girl
	# screen before a body exists. Name shop stands the toon further right.
	# It sits just past that mark so the body covers the middle and the light
	# shows on the wall around them.
	var stand := Vector3(1.55, 1.55, 4.05) if _shop == 4 else Vector3(-1.62, 1.55, 3.49)
	var camera := Vector3(-5.7, 2.15, 12.3501)
	var away := stand - camera
	if away.length() < 0.001:
		return
	_spotlight.global_position = stand + away.normalized() * 1.4
	_aim_spotlight()


func _aim_spotlight() -> void:
	if _spotlight == null or not is_instance_valid(_spotlight) or _viewport == null:
		return
	var camera := _viewport.get_camera_3d()
	if camera == null:
		return
	var to_camera := camera.global_position - _spotlight.global_position
	if to_camera.length() < 0.001:
		return
	# The card is flat along local Y and its visible side faces -Y.
	var y_axis := -to_camera.normalized()
	var side := Vector3.UP.cross(y_axis)
	if side.length() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := y_axis.cross(side).normalized()
	# The card is about 4 units across. This scale keeps the beam on the toon
	# instead of flooding the room. The column is a little taller than it is wide.
	var amount := 0.85 if _shop == 4 else 0.95
	_spotlight.global_transform = Transform3D(Basis(side, y_axis, up).scaled(Vector3(amount, 1.0, amount * 1.35)), _spotlight.global_position)


func _place_camera(camera: Camera3D) -> void:
	# Original camera sits at Panda (-5.7, -12.3501, 2.15) with a 52 degree
	# horizontal lens. The aim is a little above the chest so the head stays
	# under the title and the feet fall off the bottom, the way the original
	# screen crops them.
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 52.0
	camera.position = Vector3(-5.7, 2.15, 12.3501)
	camera.look_at(Vector3(-1.62, 2.55, 3.49))


func _on_back() -> void:
	if _shop == 0:
		return
	_transition_to(_shop - 1)


func _transition_to(target: int) -> void:
	if target == _shop or target < 0 or target >= _TITLES.size():
		return
	_dropping = true
	var forward := target > _shop
	if not forward:
		_play_sfx(_SFX_BACK)
	_play_sfx(_SFX_ENTER[target])
	# The original drop starts the crash as the walls leave, not when they land.
	_play_crash()
	var leaving_walls := _piece(_ROOM_WALLS[_shop])
	var leaving_props := _piece(_ROOM_PROPS[_shop])
	var arriving_walls := _piece(_ROOM_WALLS[target])
	var arriving_props := _piece(_ROOM_PROPS[target])
	_release_other_rooms(_ROOM_WALLS[_shop], _ROOM_WALLS[target])
	_reveal_room(target)
	_pose_piece(arriving_walls, 15.0, 1.0)
	_pose_piece(arriving_props, 15.0, 1.0)
	_shop = target
	_show_shop()
	if _room_tween != null and _room_tween.is_valid():
		_room_tween.kill()
	_room_tween = create_tween()
	_room_tween.tween_method(func(frame: float) -> void:
		_pose_piece(leaving_walls, _curve(_SQUISH_Y, frame), _curve(_SQUISH_SCALE, frame))
		_pose_piece(leaving_props, _curve(_PROP_Y, frame), _curve(_PROP_SCALE, frame))
		var drop_y := _curve(_DROP_Y, frame)
		var drop_scale := _curve(_DROP_SCALE, frame)
		_pose_piece(arriving_walls, drop_y, drop_scale)
		_pose_piece(arriving_props, drop_y, drop_scale)
	, 0.0, 20.0, 20.0 / 24.0)
	_room_tween.tween_callback(func() -> void:
		_dropping = false
		_settle_pieces()
		_show_room(_shop)
	)


func _piece(node_name: String) -> Node3D:
	return _find(_room, node_name) as Node3D


func _pose_piece(node: Node3D, height: float, amount: float) -> void:
	if node == null:
		return
	# Local Z is up. Scaling every axis pulls the room into its middle.
	node.position = Vector3(0.0, 0.0, height)
	node.scale = Vector3(1.0, 1.0, amount)


func _curve(values: PackedFloat32Array, frame: float) -> float:
	if values.is_empty():
		return 0.0
	var index := clampi(int(frame), 0, values.size() - 1)
	var following := mini(index + 1, values.size() - 1)
	return lerpf(values[index], values[following], frame - float(index))


func _release_other_rooms(leaving: String, arriving: String) -> void:
	for index in _ROOM_WALLS.size():
		var walls_name := _ROOM_WALLS[index]
		if walls_name == leaving or walls_name == arriving:
			continue
		var walls := _piece(walls_name)
		var props := _piece(_ROOM_PROPS[index])
		_pose_piece(walls, 0.0, 1.0)
		_pose_piece(props, 0.0, 1.0)
		if walls:
			walls.visible = false
		if props:
			props.visible = false
		var parent := _find(_room, _ROOM_PARENTS[index])
		if parent:
			parent.visible = false


func _settle_pieces() -> void:
	for node_name in _ROOM_WALLS:
		_pose_piece(_piece(node_name), 0.0, 1.0)
	for node_name in _ROOM_PROPS:
		_pose_piece(_piece(node_name), 0.0, 1.0)


func _play_crash() -> void:
	_play_sfx(_SFX_CRASH[randi() % _SFX_CRASH.size()])


func _play_sfx(path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var player := ToonAudio.effect_player()
	player.stream = load(path)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _on_next() -> void:
	if _style == null:
		return
	if _shop < _TITLES.size() - 1:
		_transition_to(_shop + 1)
		return
	# A second click in the same drop would skip naming. Done waits until this
	# room has landed; Next and Back do not.
	if _dropping:
		return
	_style.first_name = _style.first_name.strip_edges()
	_style.last_name = _style.last_name.strip_edges()
	if _style.first_name.is_empty() and _style.last_name.is_empty():
		_title.text = "TYPE  A  NAME"
		return
	ToonRoster.set_slot(ToonRoster.pending_slot, _style)
	ToonRoster.select_slot(ToonRoster.pending_slot)
	get_tree().change_scene_to_file("res://scenes/interiors/toontorial.tscn")


func _cancel_to_chooser() -> void:
	if _leaving:
		return
	_leaving = true
	_CHOOSER.arrive_from_black = true
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	fade.z_index = 20
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.5)
	tween.finished.connect(func() -> void:
		get_tree().change_scene_to_file(PICK_SCENE)
	)


func _fade_in() -> void:
	# Pick a Toon fades out, then this screen fades in. Both use the original
	# half-second transition.
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 0.5)
	tween.finished.connect(fade.queue_free)


func _name_font_px() -> int:
	# The pick-a-name preview is 0.036 of the taller card. Match that size on
	# this shorter card.
	if _name_view == null or not is_instance_valid(_name_view):
		return 16
	var panel := _name_view.get_parent() as Control
	var panel_h := panel.size.y if panel != null else _name_view.size.y
	return maxi(int(panel_h * 0.036 * 1.587 / 1.307), 1)


func _split_typed(text: String, width: float, px: int) -> PackedStringArray:
	var font := ToonGui.font()
	if text.is_empty() or width < 4.0 or font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= width:
		return PackedStringArray([text])
	var split_at := -1
	for index in text.length():
		if text[index] != " ":
			continue
		if font.get_string_size(text.substr(0, index), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= width:
			split_at = index
	if split_at > 0:
		return PackedStringArray([text.substr(0, split_at), text.substr(split_at + 1)])
	var cut := text.length()
	while cut > 1 and font.get_string_size(text.substr(0, cut), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
		cut -= 1
	return PackedStringArray([text.substr(0, cut), text.substr(cut)])


func _refresh_typed_name() -> void:
	if _name_view == null or _name_edit == null:
		return
	if not is_instance_valid(_name_view) or not is_instance_valid(_name_edit):
		return
	var px := _name_font_px()
	ToonGui.style_label(_name_view, Color(0.08, 0.08, 0.1), px, Color(0, 0, 0, 0), 0)
	var lines := _split_typed(_name_edit.text, _name_view.size.x * 0.94, px)
	_name_view.text = "\n".join(lines)
	_place_name_caret()


func _place_name_caret() -> void:
	if _name_caret == null or _name_view == null or _name_edit == null:
		return
	if not is_instance_valid(_name_caret) or not is_instance_valid(_name_view) or not is_instance_valid(_name_edit):
		return
	var px := _name_font_px()
	var font := ToonGui.font()
	var text := _name_edit.text
	var lines := _split_typed(text, _name_view.size.x * 0.94, px)
	var caret := clampi(_name_edit.caret_column, 0, text.length())
	var line := 0
	var column := caret
	if lines.size() > 1:
		var first := lines[0]
		var broke_on_space := text.length() > first.length() and text[first.length()] == " "
		var boundary := first.length()
		if caret <= boundary:
			column = caret
		else:
			line = 1
			column = caret - boundary - (1 if broke_on_space else 0)
	var shown := lines[line] if line < lines.size() else ""
	column = clampi(column, 0, shown.length())
	var line_w := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var before_w := font.get_string_size(shown.substr(0, column), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var line_h := font.get_height(px)
	var block_h := line_h * lines.size()
	var top := _name_view.position.y + (_name_view.size.y - block_h) * 0.5
	var left := _name_view.position.x + (_name_view.size.x - line_w) * 0.5
	_name_caret.position = Vector2(left + before_w, top + line_h * line)
	_name_caret.size = Vector2(maxi(2, int(px * 0.06)), line_h * 0.82)


func _blink_name_caret() -> void:
	if _name_caret == null or _name_edit == null:
		return
	if not is_instance_valid(_name_caret) or not is_instance_valid(_name_edit):
		return
	var focused := _name_edit.has_focus()
	if focused:
		_place_name_caret()
	_name_caret.visible = focused and int(Time.get_ticks_msec() / 530.0) % 2 == 0


func _on_name_click(event: InputEvent) -> void:
	if _name_edit == null or not is_instance_valid(_name_edit):
		return
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	_name_edit.grab_focus()
	var px := _name_font_px()
	var font := ToonGui.font()
	var text := _name_edit.text
	var lines := _split_typed(text, _name_view.size.x * 0.94, px)
	var line_h := font.get_height(px)
	var block_h := line_h * lines.size()
	var top := (_name_view.size.y - block_h) * 0.5
	var line := 0 if lines.size() < 2 or click.position.y < top + line_h else 1
	var shown := lines[line]
	var line_w := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var left := (_name_view.size.x - line_w) * 0.5
	var column := shown.length()
	for index in shown.length():
		var width := font.get_string_size(shown.substr(0, index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		if click.position.x < left + width - font.get_string_size(shown.substr(index, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x * 0.5:
			column = index
			break
	var first := lines[0]
	var broke_on_space := lines.size() > 1 and text.length() > first.length() and text[first.length()] == " "
	_name_edit.caret_column = column if line == 0 else first.length() + column + (1 if broke_on_space else 0)
	_place_name_caret()


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
	_refresh_typed_name()


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


func _submit_typed_name() -> void:
	if _name_edit == null or not is_instance_valid(_name_edit):
		return
	_on_typed_name(_name_edit.text)
	var typed := _name_edit.text.strip_edges()
	if typed.is_empty():
		return
	# Submit leaves Type a Name and keeps this name. The lists take over again
	# only after the player shuffles or scrolls one.
	_submitted_name = typed
	_typing = false
	_show_shop()


func _picked_name() -> String:
	if not _submitted_name.is_empty():
		return _submitted_name
	var title := _at(_titles, _title_i) if _title_on else ""
	var first := _at(_firsts, _first_i) if _first_on else ""
	var last := ToonNames.last_name(_at(_prefixes, _prefix_i), _at(_suffixes, _suffix_i)) if _last_on else ""
	var given := ToonNames.join_name(title, first, "")
	if given.is_empty():
		return last
	if last.is_empty():
		return given
	return given + "\n" + last
func _apply_picked() -> void:
	_submitted_name = ""
	if _style == null:
		return
	var title := _at(_titles, _title_i) if _title_on else ""
	var first := _at(_firsts, _first_i) if _first_on else ""
	_style.first_name = ToonNames.join_name(title, first, "")
	_style.last_name = ToonNames.last_name(_at(_prefixes, _prefix_i), _at(_suffixes, _suffix_i)) if _last_on else ""


func _set_title(kind: String, value: Variant) -> void:
	if kind == "toggle":
		_title_on = bool(value)
	elif kind == "set":
		_title_i = posmod(int(value), maxi(_titles.size(), 1))
	else:
		_title_i = posmod(_title_i + int(value), maxi(_titles.size(), 1))
	_apply_picked()
	_show_shop()


func _set_first(kind: String, value: Variant) -> void:
	if kind == "toggle":
		_first_on = bool(value)
		if not _first_on and not _last_on:
			_last_on = true
	elif kind == "set":
		_first_i = posmod(int(value), maxi(_firsts.size(), 1))
	else:
		_first_i = posmod(_first_i + int(value), maxi(_firsts.size(), 1))
	_apply_picked()
	_show_shop()


func _set_prefix(kind: String, value: Variant) -> void:
	if kind == "set":
		_prefix_i = posmod(int(value), maxi(_prefixes.size(), 1))
	else:
		_prefix_i = posmod(_prefix_i + int(value), maxi(_prefixes.size(), 1))
	_apply_picked()
	_show_shop()


func _set_suffix(kind: String, value: Variant) -> void:
	if kind == "set":
		_suffix_i = posmod(int(value), maxi(_suffixes.size(), 1))
	else:
		_suffix_i = posmod(_suffix_i + int(value), maxi(_suffixes.size(), 1))
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
	ToonGui.button_sounds(button)
	box.add_child(button)
	return box


func _hover_caption(button: BaseButton, text: String, x: float, z: float) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate = Color(1, 1, 1, 0)
	label.z_index = 8
	# Place against the full screen. A caption parented to the Back card is
	# positioned with screen coordinates and lands outside that small card.
	var host: Node = button
	while host != null and host != self and host != _shop_box:
		host = host.get_parent()
	if host == null:
		host = self
	host.add_child(label)
	_track(label, x, z, 0.5, 0.1)
	button.mouse_entered.connect(func() -> void:
		if button.disabled:
			return
		label.modulate.a = 1.0
	)
	button.mouse_exited.connect(func() -> void:
		label.modulate.a = 0.0
	)
	label.resized.connect(func() -> void:
		var px := int(0.08 * size.y * 0.5)
		ToonGui.style_label(label, Color.WHITE, maxi(px, 1), Color(0, 0, 0), maxi(px / 8, 1))
	)
	return label


func _hover_grow(button: Control, amount: float) -> void:
	button.mouse_entered.connect(func() -> void:
		if button is BaseButton and (button as BaseButton).disabled:
			return
		button.scale = Vector2(amount, amount)
	)
	button.mouse_exited.connect(func() -> void:
		button.scale = Vector2.ONE
	)


func _image_button(up: Texture2D, down: Texture2D) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = up
	button.texture_pressed = down
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	ToonGui.button_sounds(button)
	return button


func _unshade(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var mesh := mesh_instance.mesh
		if mesh:
			for surface in mesh.get_surface_count():
				var source := mesh.surface_get_material(surface)
				if source is StandardMaterial3D:
					# Wall paint is stored in the vertex colors. The imported
					# material ignores them, which leaves the rooms white.
					var material := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
					material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					material.vertex_color_use_as_albedo = true
					material.vertex_color_is_srgb = true
					# The spotlight adds the bright column back. The rest of the
					# room sits a little under that so the beam reads.
					# Prop shadows are black cards at the alpha they were
					# exported with (0.5, or 0.28 on the floor ovals). A tint
					# with alpha 1 paints those cards solid and turns the
					# soft floor shadows into hard black shapes.
					if String(mesh_instance.name) != "spotlight__billboard":
						var shadow_alpha := material.albedo_color.a
						if shadow_alpha >= 0.99:
							material.albedo_color = Color(0.84, 0.84, 0.84, shadow_alpha)
					mesh_instance.set_surface_override_material(surface, material)
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
