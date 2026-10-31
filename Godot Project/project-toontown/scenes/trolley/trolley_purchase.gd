extends Node3D

## Purchase.py. The jellybean count plays out on the street, then Goofy's Gag
## Shop opens on the toon interior: the purchase panel, the jar, and the two
## original buttons. One pouch bean buys one gag.

signal finished(reason: String)

const _SET := "res://assets/minigames/purchase_set.glb"
const _SIGN := preload("res://assets/gui/purchase/Goofys_Sign.png")
const _JAR := preload("res://assets/gui/purchase/Jar.png")
const _PANEL := preload("res://assets/gui/purchase/PurchasePanel.png")
const _UP := preload("res://assets/gui/purchase/PurchScrn_BTN_UP.png")
const _DN := preload("res://assets/gui/purchase/PurchScrn_BTN_DN.png")
const _OVER := preload("res://assets/gui/purchase/PurchScrn_BTN_RLVR.png")
const _CLOCK := preload("res://assets/gui/purchase/alarm_clock.png")
const _ROW := preload("res://assets/gui/tutorial/InventoryRow.png")
const _TRASH_CLOSED := preload("res://assets/toons/gui/TrashCan_CLSD.png")
const _TRASH_OPEN := preload("res://assets/toons/gui/TrashCan_OPEN.png")
const _TRASH_HOVER := preload("res://assets/toons/gui/TrashCan_RLVR.png")
const _BEANS := preload("res://scenes/toons/jellybeans.gd")
const _TASKS := preload("res://scenes/quests/toon_tasks.gd")
const _SECONDS := 120.0
const _WAIT := 1.0
const _COUNT := 0.5
const _HOLD := 1.0
const _CHEER := 2.6
const _ICONS: PackedStringArray = [
	"res://assets/gui/tutorial/gags/inventory_feather.png",
	"res://assets/gui/tutorial/gags/inventory_megaphone.png",
	"res://assets/gui/tutorial/gags/inventory_lipstick.png",
	"res://assets/gui/tutorial/gags/inventory_bamboo_cane.png",
	"res://assets/gui/tutorial/gags/inventory_pixiedust.png",
	"res://assets/gui/tutorial/gags/inventory_juggling_cubes.png",
	"res://assets/gui/tutorial/gags/inventory_ladder.png",
	"res://assets/gui/tutorial/gags/inventory_bannana_peel.png",
	"res://assets/gui/tutorial/gags/inventory_rake.png",
	"res://assets/gui/tutorial/gags/inventory_marbles.png",
	"res://assets/gui/tutorial/gags/inventory_quicksand_icon.png",
	"res://assets/gui/tutorial/gags/inventory_trapdoor.png",
	"res://assets/gui/tutorial/gags/inventory_tnt.png",
	"res://assets/gui/tutorial/gags/inventory_traintracks.png",
	"res://assets/gui/tutorial/gags/inventory_1dollarbill.png",
	"res://assets/gui/tutorial/gags/inventory_small_magnet.png",
	"res://assets/gui/tutorial/gags/inventory_5dollarbill.png",
	"res://assets/gui/tutorial/gags/inventory_big_magnet.png",
	"res://assets/gui/tutorial/gags/inventory_10dollarbill.png",
	"res://assets/gui/tutorial/gags/inventory_hypno_goggles.png",
	"res://assets/gui/tutorial/gags/inventory_screen.png",
	"res://assets/gui/tutorial/gags/inventory_bikehorn.png",
	"res://assets/gui/tutorial/gags/inventory_whistle.png",
	"res://assets/gui/tutorial/gags/inventory_bugle.png",
	"res://assets/gui/tutorial/gags/inventory_aoogah.png",
	"res://assets/gui/tutorial/gags/inventory_elephant.png",
	"res://assets/gui/tutorial/gags/inventory_fog_horn.png",
	"res://assets/gui/tutorial/gags/inventory_opera_singer.png",
	"res://assets/gui/tutorial/gags/inventory_tart.png",
	"res://assets/gui/tutorial/gags/inventory_fruit_pie_slice.png",
	"res://assets/gui/tutorial/gags/inventory_cream_pie_slice.png",
	"res://assets/gui/tutorial/gags/inventory_fruitpie.png",
	"res://assets/gui/tutorial/gags/inventory_creampie.png",
	"res://assets/gui/tutorial/gags/inventory_cake.png",
	"res://assets/gui/tutorial/gags/inventory_wedding.png",
	"res://assets/gui/tutorial/gags/inventory_squirt_flower.png",
	"res://assets/gui/tutorial/gags/inventory_glass_of_water.png",
	"res://assets/gui/tutorial/gags/inventory_water_gun.png",
	"res://assets/gui/tutorial/gags/inventory_seltzer_bottle.png",
	"res://assets/gui/tutorial/gags/inventory_firehose.png",
	"res://assets/gui/tutorial/gags/inventory_storm_cloud.png",
	"res://assets/gui/tutorial/gags/inventory_geyser.png",
	"res://assets/gui/tutorial/gags/inventory_flower_pot.png",
	"res://assets/gui/tutorial/gags/inventory_sandbag.png",
	"res://assets/gui/tutorial/gags/inventory_anvil.png",
	"res://assets/gui/tutorial/gags/inventory_weight.png",
	"res://assets/gui/tutorial/gags/inventory_safe_box.png",
	"res://assets/gui/tutorial/gags/inventory_piano.png",
	"res://assets/gui/tutorial/gags/inventory_ship.png",
]

var loadout: ToonLoadout
var reward := 0

var _env: Environment
var _set: Node3D
var _toon: ToonActor
var _toon_home := Vector3.ZERO
var _gui: Control
var _sign: TextureRect
var _title: Label
var _panel: TextureRect
var _score_box: Panel
var _score: Label
var _jar: TextureRect
var _beans: Label
var _pouch: Label
var _status: Label
var _clock: TextureRect
var _time: Label
var _again: TextureButton
var _exit: TextureButton
var _trash: TextureButton
var _rows: Array[TextureRect] = []
var _names: Array[Label] = []
var _buttons: Array[Button] = []
var _gags: Array[TextureRect] = []
var _counts: Array[Label] = []
var _shopping := false
var _deleting := false
var _granted := false
var _cheered := false
var _closed := false
var _age := 0.0
var _counter := 0
var _jar_start := 0
var _jar_shown := 0
var _next_tick := 0.0
var _remain := _SECONDS
var _status_left := 0.0
var _chat: SpeedChat


func _ready() -> void:
	_stage()
	_build_gui()
	var view := get_viewport()
	if not view.size_changed.is_connected(_layout):
		view.size_changed.connect(_layout)
	_jar_start = _BEANS.pouch()
	_jar_shown = _jar_start
	_beans.text = str(_jar_shown)
	_play_music()
	_layout()
	if reward <= 0:
		_open_shop(false)
	else:
		_show_street(true)
		_score.text = "0"


func _process(delta: float) -> void:
	if _closed:
		return
	if not _shopping:
		_animate(delta)
		return
	_remain = maxf(_remain - delta, 0.0)
	_paint_time()
	if _status_left > 0.0:
		_status_left = maxf(_status_left - delta, 0.0)
		if _status_left == 0.0:
			_show_beans()
	if _remain <= 0.0:
		_close("timeout")


func _input(event: InputEvent) -> void:
	if _closed or not _shopping or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE):
		# Escape leaves the typed line or the SpeedChat list before it leaves the shop.
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		if _chat != null and _chat.is_open():
			return
		get_viewport().set_input_as_handled()
		_close("home")


func _stage() -> void:
	var world := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.45, 0.74, 0.95)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.72, 0.76, 0.8)
	_env.ambient_light_energy = 1.15
	world.environment = _env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 25, 0)
	add_child(sun)
	var camera := Camera3D.new()
	# Purchase.enterReward uses DefaultCameraFov, which is a horizontal 52.
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 52.0
	camera.current = true
	camera.far = 800.0
	add_child(camera)
	# Purchase.enterReward: camera (0, 16, 2) looking at (0, 0, 0.75).
	camera.position = _panda(0.0, 16.0, 2.0)
	camera.look_at(_panda(0.0, 0.0, 0.75), Vector3.UP)
	if ResourceLoader.exists(_SET):
		_set = (load(_SET) as PackedScene).instantiate()
		add_child(_set)
	_toon = ToonActor.new()
	add_child(_toon)
	var style := ToonRoster.selected_style()
	if style != null:
		_toon.show_style(style)
	# Solo layout puts the one toon at x = -0.25, on the floor z = -2.5, facing the camera.
	_toon_home = _panda(-0.25, 1.0, -2.5)
	_toon.position = _toon_home
	_toon.rotation_degrees.y = 0.0
	_toon.set_locomotion(0.0, false, false, 0.0)


func _build_gui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_gui = Control.new()
	_gui.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Empty parts of the shop let clicks through to SpeedChat.
	_gui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_gui)
	var chat_layer := CanvasLayer.new()
	chat_layer.layer = 60
	add_child(chat_layer)
	_chat = SpeedChat.new()
	chat_layer.add_child(_chat)
	_chat.setup(_TASKS.for_selected())
	_panel = _image(_PANEL)
	_panel.visible = false
	for track in ToonLoadout.TRACK_COUNT:
		var row := _image(_ROW)
		row.modulate = ToonLoadout.TRACK_COLORS[track]
		row.visible = false
		_rows.append(row)
		var name := Label.new()
		name.text = ToonLoadout.TRACK_NAMES[track].to_upper()
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name.visible = false
		_gui.add_child(name)
		_names.append(name)
		for level in ToonLoadout.LEVEL_COUNT:
			var button := Button.new()
			button.focus_mode = Control.FOCUS_NONE
			button.flat = true
			var empty := StyleBoxEmpty.new()
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				button.add_theme_stylebox_override(state, empty)
			button.pressed.connect(_press.bind(track, level))
			button.visible = false
			ToonGui.button_sounds(button)
			_gui.add_child(button)
			_buttons.append(button)
			var icon := TextureRect.new()
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.visible = false
			var picture := load(_ICONS[track * ToonLoadout.LEVEL_COUNT + level]) as Texture2D
			if picture != null:
				icon.texture = picture
			_gui.add_child(icon)
			_gags.append(icon)
			var count := Label.new()
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			count.mouse_filter = Control.MOUSE_FILTER_IGNORE
			count.visible = false
			_gui.add_child(count)
			_counts.append(count)
	_score_box = Panel.new()
	_score_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cream := StyleBoxFlat.new()
	cream.bg_color = Color(1, 1, 0.75)
	cream.set_corner_radius_all(8)
	_score_box.add_theme_stylebox_override("panel", cream)
	_gui.add_child(_score_box)
	_score = Label.new()
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score.text = "0"
	_gui.add_child(_score)
	_jar = _image(_JAR)
	_beans = Label.new()
	_beans.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_beans.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_beans.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gui.add_child(_beans)
	# InventoryNew.totalLabel sits in the blue square beside the gag rows.
	_pouch = Label.new()
	_pouch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pouch.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pouch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pouch.visible = false
	_gui.add_child(_pouch)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.visible = false
	_gui.add_child(_status)
	_again = _pill("PLAY\nAGAIN", "again")
	_exit = _pill("EXIT BACK TO\nPLAYGROUND", "home")
	_trash = TextureButton.new()
	_trash.texture_normal = _TRASH_CLOSED
	_trash.texture_hover = _TRASH_HOVER
	_trash.texture_pressed = _TRASH_OPEN
	_trash.ignore_texture_size = true
	_trash.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_trash.focus_mode = Control.FOCUS_NONE
	_trash.visible = false
	_trash.pressed.connect(_toggle_delete)
	ToonGui.button_sounds(_trash)
	_gui.add_child(_trash)
	_sign = _image(_SIGN)
	_title = Label.new()
	_title.text = "Goofy's Gag Shop"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gui.add_child(_title)
	_clock = _image(_CLOCK)
	_clock.visible = false
	_time = Label.new()
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_time.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time.visible = false
	_gui.add_child(_time)


func _image(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gui.add_child(rect)
	return rect


func _pill(text: String, reason: String) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _UP
	button.texture_pressed = _DN
	button.texture_hover = _OVER
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.clip_contents = true
	button.visible = false
	button.pressed.connect(_close.bind(reason))
	ToonGui.button_sounds(button)
	var caption := Label.new()
	caption.text = text
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(caption)
	_gui.add_child(button)
	return button


func _layout() -> void:
	if _gui == null:
		return
	_place(_sign, 0.0, 0.83, 1.2917 * 1.2, 0.275 * 1.2)
	_title.position = _sign.position
	_title.size = _sign.size
	ToonGui.style_title(_title, Color(0.6, 0.2, 0.0), _px_of(0.09 * 1.2))
	# The score card sits above the toon. The jar sits under their feet until the shop opens.
	_place(_score_box, 0.0425, 0.6, 0.165, 0.165)
	_score.position = _score_box.position
	_score.size = _score_box.size
	ToonGui.style_title(_score, Color(0.95, 0.95, 0.0), _px_of(0.1))
	if _shopping:
		_place(_panel, 0.14 - 0.21, -0.04 + 0.08, 2.4292, 1.4208)
		_place(_jar, 0.14 - 1.15, -0.04 + 0.16, 0.4333, 0.5292)
		_place(_again, 0.14 + 0.72, -0.04 - 0.24, 0.4125 * 1.04, 0.175 * 1.04)
		_place(_exit, 0.14 + 0.72, -0.04 - 0.045, 0.4125 * 1.04, 0.175 * 1.04)
		_place(_clock, 1.16, 0.83, 0.7417 * 0.45, 0.7292 * 0.45)
		var status_size := _size(1.2, 0.1)
		_status.position = _point(-0.11, 0.585) - status_size * 0.5
		_status.size = status_size
		ToonGui.style_label(_status, Color(0.05, 0.14, 0.4), _px_of(0.08), Color(0, 0, 0, 0), 0)
		_place(_trash, -0.452, -0.263, 0.22, 0.22)
		# detailFrame (1.17, -0.02) on the purchase invFrame, totalLabel one line below its origin.
		_place(_pouch, 0.853, 0.355, 0.34, 0.14)
		ToonGui.style_label(_pouch, Color(0.05, 0.14, 0.4, 1), _px_of(0.05), Color(0, 0, 0, 0), 0)
		_paint_pouch()
		_caption(_again, _px_of(0.05))
		_caption(_exit, _px_of(0.045))
		_place_rows()
	else:
		_place(_jar, 0.0425, -0.825, 0.4333 * 0.5, 0.5292 * 0.5)
	_beans.position = _jar.position
	_beans.size = _jar.size
	_paint_jar()
	_time.position = _clock.position
	_time.size = _clock.size
	_paint_time()


func _place_rows() -> void:
	# invFrame is (-0.235, 0.52) on the purchase frame, scaled by 0.81.
	var origin_x := 0.14 - 0.235
	var origin_z := -0.04 + 0.52
	var row_w := 1.6667 * 0.81
	var row_h := 0.1137 * 1.1 * 0.81
	for track in ToonLoadout.TRACK_COUNT:
		var open := loadout != null and loadout.track_open(track)
		var row_z := origin_z + float(track) * -0.12 * 0.81
		var row := _rows[track]
		row.visible = open and _shopping
		_names[track].visible = open and _shopping
		if open:
			_place(row, origin_x, row_z, row_w, row_h)
			var name := _names[track]
			var name_size := _size(0.45, row_h)
			name.position = _point(origin_x - 0.785 * 0.81, row_z) - Vector2(0.0, name_size.y * 0.5)
			name.size = name_size
			ToonGui.style_label(name, Color(0.2, 0.2, 0.2), _px_of(0.045), Color(0, 0, 0, 0), 0)
		for level in ToonLoadout.LEVEL_COUNT:
			var index := track * ToonLoadout.LEVEL_COUNT + level
			var shown := open and _shopping and loadout != null and loadout.gag_usable(track, level)
			_buttons[index].visible = shown
			_gags[index].visible = shown
			_counts[index].visible = shown
			if not shown:
				continue
			var local_x := -0.375 + float(level) * 0.18
			var center := _point(origin_x + local_x * 0.81, row_z)
			var well := _size(0.15, 0.1)
			_buttons[index].position = center - well * 0.5
			_buttons[index].size = well
			var icon := well * 0.72
			_gags[index].position = center - icon * 0.5
			_gags[index].size = icon
			_counts[index].position = _buttons[index].position
			_counts[index].size = well
			ToonGui.style_label(_counts[index], Color.WHITE, _px_of(0.032), Color(0.05, 0.12, 0.28), 2)
			_paint_slot(track, level)


func _animate(delta: float) -> void:
	_age += delta
	var counter := 0
	var jar := _jar_start
	var pouring := false
	var up_end := _WAIT + _COUNT
	var hold_end := up_end + _HOLD
	var down_end := hold_end + _COUNT
	var cheer_end := down_end + _CHEER
	if _age < _WAIT:
		counter = 0
	elif _age < up_end:
		counter = int(round(_ease((_age - _WAIT) / _COUNT) * float(reward)))
	elif _age < hold_end:
		counter = reward
	elif _age < down_end:
		pouring = true
		counter = int(round((1.0 - _ease((_age - hold_end) / _COUNT)) * float(reward)))
		jar = mini(_jar_start + (reward - counter), _BEANS.POUCH_MAX)
	elif _age < cheer_end:
		if not _cheered:
			_cheered = true
			_grant()
			_jar_shown = _BEANS.pouch()
			_beans.text = str(_jar_shown)
			_paint_jar()
			_score_box.visible = false
			_score.visible = false
			_effect("MG_win")
			# enterJump plays the full jump once while the toon is still neutral.
			# That clip is stored as leap. The airborne hover is a different anim.
			_toon.play_gesture("leap", 1.0, false)
		_toon.position = _toon_home
		_toon.set_locomotion(0.0, false, false, delta)
		return
	else:
		_open_shop(false)
		return
	var changed := counter != _counter or jar != _jar_shown
	_counter = counter
	_jar_shown = jar
	_score.text = str(counter)
	_beans.text = str(jar)
	_paint_jar()
	if changed and _age >= _WAIT:
		_tick(pouring and jar >= _BEANS.POUCH_MAX)


func _open_shop(cheer: bool) -> void:
	_shopping = true
	_grant()
	_show_street(false)
	_toon.visible = false
	_score_box.visible = false
	_score.visible = false
	_panel.visible = true
	_status.visible = true
	_again.visible = true
	_exit.visible = true
	_trash.visible = true
	_clock.visible = true
	_time.visible = true
	_pouch.visible = true
	_env.background_color = Color(0.05, 0.14, 0.4)
	_jar_shown = _BEANS.pouch()
	_status_left = 0.0
	_layout()
	_show_beans()
	if cheer:
		_effect("MG_win")


func _show_street(street: bool) -> void:
	if _set == null:
		return
	for part in ["Foreground", "BackgroundL", "BackgroundR", "Sidewalk", "Door"]:
		var node := _set.find_child(part, true, false)
		if node != null:
			node.visible = street
	var interior := _set.find_child("Interior", true, false)
	if interior != null:
		interior.visible = not street


func _press(track: int, level: int) -> void:
	if not _shopping or _closed or loadout == null:
		return
	if _deleting:
		if loadout.toss_gag(track, level):
			_refresh()
		return
	if _BEANS.pouch() <= 0:
		_note("Sorry, you are all out of jellybeans!")
		_refresh()
		return
	var result := loadout.purchase(track, level)
	if result > 0:
		if _BEANS.take_beans(1, false):
			_note("You purchased %s" % loadout.gag_name(track, level))
		else:
			loadout.toss_gag(track, level)
			_note("Sorry, you are all out of jellybeans!")
	elif result == -2:
		_note("Sorry, you have too many props")
	elif result == -1:
		_note("Sorry, you have enough %s already" % _plural(loadout.gag_name(track, level)))
	else:
		_note("You do not have enough skill for that yet")
	_refresh()


func _toggle_delete() -> void:
	_deleting = not _deleting
	_trash.texture_normal = _TRASH_OPEN if _deleting else _TRASH_CLOSED
	_status_left = 0.0
	_refresh()


func _refresh() -> void:
	_jar_shown = _BEANS.pouch()
	_beans.text = str(_jar_shown)
	_paint_jar()
	_paint_pouch()
	for track in ToonLoadout.TRACK_COUNT:
		for level in ToonLoadout.LEVEL_COUNT:
			_paint_slot(track, level)
	if _status_left <= 0.0:
		_show_beans()


func _paint_slot(track: int, level: int) -> void:
	if loadout == null:
		return
	var index := track * ToonLoadout.LEVEL_COUNT + level
	if index >= _counts.size() or not _counts[index].visible:
		return
	var owned := loadout.count_of(track, level)
	_counts[index].text = str(owned)
	var full := owned >= loadout.carry_limit(track, level) or loadout.pouch_full()
	var blocked := (not _deleting and (_BEANS.pouch() <= 0 or full or level > ToonLoadout.LAST_REGULAR)) or (_deleting and owned <= 0)
	_buttons[index].disabled = blocked
	_gags[index].modulate = Color(0.55, 0.55, 0.55) if blocked else Color.WHITE


func _show_beans() -> void:
	if _deleting:
		_status.text = "Click on a gag to DELETE it."
		return
	var money := _BEANS.pouch()
	if money <= 0:
		_status.text = "Sorry, you are all out of jellybeans!"
	elif money == 1:
		_status.text = "You have 1 jellybean to spend"
	else:
		_status.text = "You have %d jellybeans to spend" % money


func _note(text: String) -> void:
	_status.text = text
	_status_left = 2.0


func _paint_pouch() -> void:
	if _pouch == null:
		return
	var carried := 0
	var limit := ToonLoadout.CARRY
	if loadout != null:
		carried = loadout.gag_count()
		limit = loadout.max_carry
	_pouch.text = "Total gags\n%d / %d" % [carried, limit]
	_pouch.visible = _shopping


func _paint_jar() -> void:
	var full := _jar_shown >= _BEANS.POUCH_MAX
	ToonGui.style_title(_beans, Color(1, 0, 0) if full else Color(0.95, 0.95, 0.0), _px_of(0.2 if _shopping else 0.1))


func _paint_time() -> void:
	if not _shopping:
		return
	var whole := int(ceil(_remain))
	_time.text = str(whole)
	var late := whole <= 5
	ToonGui.style_label(_time, Color(1, 0, 0) if late else Color(0, 0, 0), _px_of(0.12 if late else 0.09), Color(0, 0, 0, 0), 0)


func _caption(button: TextureButton, px: int) -> void:
	var caption := button.get_child(0) as Label
	ToonGui.style_label(caption, Color(0.0, 0.1, 0.7), px, Color(0, 0, 0, 0), 0)


func _grant() -> void:
	if _granted:
		return
	_granted = true
	_BEANS.add_beans(reward)


func _close(reason: String) -> void:
	if _closed:
		return
	_closed = true
	_grant()
	finished.emit(reason)
	queue_free()


func _point(ax: float, az: float) -> Vector2:
	var view := get_viewport().get_visible_rect().size
	var aspect := view.x / maxf(view.y, 1.0)
	return Vector2((ax / aspect + 1.0) * 0.5 * view.x, (1.0 - az) * 0.5 * view.y)


func _size(aw: float, ah: float) -> Vector2:
	var unit := get_viewport().get_visible_rect().size.y * 0.5
	return Vector2(aw * unit, ah * unit)


func _place(control: Control, ax: float, az: float, aw: float, ah: float) -> void:
	var rect := _size(aw, ah)
	control.position = _point(ax, az) - rect * 0.5
	control.size = rect


func _px_of(aspect_height: float) -> int:
	return maxi(int(round(aspect_height * get_viewport().get_visible_rect().size.y * 0.5)), 8)


func _panda(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, z, -y)


func _ease(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _tick(over_max: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _next_tick:
		return
	_next_tick = now + (0.067 if over_max else 0.034)
	_effect("AV_collision" if over_max else "tick_counter")


func _play_music() -> void:
	var path := "res://assets/audio/bgm/FF_safezone.ogg"
	if not FileAccess.file_exists(path):
		return
	var stream := AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		return
	stream.loop = true
	var player := ToonAudio.music_player()
	player.stream = stream
	player.volume_db = linear_to_db(0.8)
	add_child(player)
	player.play()


func _effect(name: String) -> void:
	var path := "res://assets/audio/sfx/%s.ogg" % name
	if not FileAccess.file_exists(path):
		return
	var stream := AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		return
	var player := ToonAudio.effect_player()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _plural(name: String) -> String:
	match name:
		"Glass of Water":
			return "Glasses of Water"
		"TNT":
			return "TNT"
		_:
			if name.ends_with("s"):
				return name
			return name + "s"
