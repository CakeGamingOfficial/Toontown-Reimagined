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
const _HOLIDAYS := preload("res://scenes/shticker/calendar_holidays.gd")
const _TASKS := preload("res://scenes/quests/toon_tasks.gd")
const _SECONDS := 120.0
const _WAIT := 1.0
const _COUNT := 0.5
const _HOLD := 1.0
const _CHEER := 2.6
const _RIDE := preload("res://scenes/trolley/trolley_ride.gd")
## Purchase.enterReward. One toon stands in the middle. Two, three, and four use the wider spots.
const _LINE: Array = [[2], [1, 3], [0, 2, 4], [0, 1, 3, 4]]
const _BENCH: Array[float] = [5.0, 1.75, -0.25, -1.75, -5.0]
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
# A skipped game still walks the reward street so the score reads 0.
var preview_score := false

var _env: Environment
var _set: Node3D
var _toon: ToonActor
var _toon_home := Vector3.ZERO
var _camera: Camera3D
var _tags: Nametags
var _party: Array[ToonActor] = []
var _party_home: Array[Vector3] = []
var _party_ax: Array[float] = []
var _party_box: Array[Panel] = []
var _party_score: Array[Label] = []
var _party_jar: Array[TextureRect] = []
var _party_beans: Array[Label] = []
var _party_reward: Array[int] = []
var _party_pouch: Array[int] = []
var _party_limit: Array[int] = []
var _party_peer: Array[int] = []
var _local_slot := 0
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
var _heads: Array = []


func _ready() -> void:
	_stage()
	_build_gui()
	_build_party_cards()
	var view := get_viewport()
	if not view.size_changed.is_connected(_layout):
		view.size_changed.connect(_layout)
	_jar_start = _BEANS.pouch()
	_jar_shown = _jar_start
	_beans.text = str(_jar_shown)
	_play_music()
	_layout()
	if reward <= 0 and not preview_score and _party.size() < 2:
		_open_shop(false)
	else:
		_show_street(true)
		_score.text = "0"


func _process(delta: float) -> void:
	if _closed:
		return
	if _tags != null:
		_tags.place()
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
		return
	_paint_heads()


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
	_camera = camera
	# Purchase.enterReward: camera (0, 16, 2) looking at (0, 0, 0.75).
	camera.position = _panda(0.0, 16.0, 2.0)
	camera.look_at(_panda(0.0, 0.0, 0.75), Vector3.UP)
	if ResourceLoader.exists(_SET):
		_set = (load(_SET) as PackedScene).instantiate()
		add_child(_set)
	_lineup()


func _lineup() -> void:
	var cards: Array = _RIDE.riders
	if cards.is_empty():
		var mine := ToonRoster.selected_style()
		cards = [{
			"peer": ToonNet.peer_id(),
			"name": mine.display_name() if mine != null else "",
			"style": mine.to_dict() if mine != null else {},
			"accessories": {},
		}]
	var count := mini(cards.size(), 4)
	var layout: Array = _LINE[count - 1]
	var me := ToonNet.peer_id()
	_tags = Nametags.new()
	_tags.camera = _camera
	var tag_layer := CanvasLayer.new()
	tag_layer.layer = 40
	add_child(tag_layer)
	_tags.layer = tag_layer
	add_child(_tags)
	for index in count:
		var card: Dictionary = cards[index]
		var spot := int(layout[index])
		var across := _BENCH[spot]
		var actor := ToonActor.new()
		add_child(actor)
		var dressed = _style_of(card, int(card.get("peer", -1)) == me)
		if dressed is ToonStyle:
			var style := dressed as ToonStyle
			actor.show_style(style)
			actor.name = style.display_name()
		var worn: Variant = card.get("accessories", {})
		if worn is Dictionary:
			actor.wear_accessories(worn)
		var local := int(card.get("peer", -1)) == me or count == 1
		var dressed_style: Dictionary = {}
		if local:
			var mine := ToonRoster.selected_style()
			if mine != null:
				dressed_style = mine.to_dict()
		elif card.get("style") is Dictionary:
			dressed_style = card.get("style")
		if not dressed_style.is_empty():
			actor.set_meta("style", dressed_style)
		var av := ToonRoster.avatar_id() if local else int(ToonNet.latest("toon:%d" % int(card.get("peer", 0))).get("av", 0))
		actor.set_meta("av", av)
		var home := _panda(across, 1.0, -2.5)
		actor.position = home
		actor.rotation_degrees.y = 0.0
		actor.set_locomotion(0.0, false, false, 0.0)
		var label := String(card.get("name", ""))
		if label == "" and dressed is ToonStyle:
			label = (dressed as ToonStyle).display_name()
		if label != "":
			_tags.add(actor, label, "player")
		_party.append(actor)
		_party_home.append(home)
		_party_ax.append(across * -0.17)
		_party_peer.append(int(card.get("peer", 0)))
		if local and _toon == null:
			_toon = actor
			_toon_home = home
			_local_slot = index
		_party_reward.append(reward if local and _local_slot == index else 0)
		_party_pouch.append(_BEANS.pouch() if local and _local_slot == index else 0)
		_party_limit.append(_BEANS.pouch_limit() if local and _local_slot == index else 40)
	if _toon == null and not _party.is_empty():
		_toon = _party[0]
		_toon_home = _party_home[0]
		_local_slot = 0
		_party_reward[0] = reward
		_party_pouch[0] = _BEANS.pouch()
		_party_limit[0] = _BEANS.pouch_limit()


func _style_of(card: Dictionary, local: bool):
	if local:
		return ToonRoster.selected_style()
	var raw: Variant = card.get("style", {})
	if raw is Dictionary and (raw as Dictionary).has("head"):
		return ToonStyle.from_dict(raw)
	return null


func _build_party_cards() -> void:
	for index in _party.size():
		var box := Panel.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cream := StyleBoxFlat.new()
		cream.bg_color = Color(1, 1, 0.75)
		cream.set_corner_radius_all(8)
		box.add_theme_stylebox_override("panel", cream)
		_gui.add_child(box)
		_party_box.append(box)
		var number := Label.new()
		number.text = "0"
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gui.add_child(number)
		_party_score.append(number)
		var jar := _image(_JAR)
		_party_jar.append(jar)
		var beans := Label.new()
		beans.text = str(_party_pouch[index])
		beans.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		beans.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		beans.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gui.add_child(beans)
		_party_beans.append(beans)


func _build_gui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_gui = Control.new()
	_gui.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Empty parts of the shop let clicks through to SpeedChat.
	_gui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_gui)
	_bind_chat()
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
	_score_box.visible = false
	_score.visible = false
	if _shopping:
		_place(_panel, 0.14 - 0.21, -0.04 + 0.08, 2.4292, 1.4208)
		_jar.visible = true
		_beans.visible = true
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
		_hide_party_cards()
		_layout_heads()
	else:
		_jar.visible = false
		_beans.visible = false
		for index in _party_box.size():
			var across := _party_ax[index]
			_place(_party_box[index], across, 0.6, 0.165, 0.165)
			_party_score[index].position = _party_box[index].position
			_party_score[index].size = _party_box[index].size
			ToonGui.style_title(_party_score[index], Color(0.95, 0.95, 0.0), _px_of(0.1))
			_place(_party_jar[index], across, -0.825, 0.4333 * 0.5, 0.5292 * 0.5)
			_party_beans[index].position = _party_jar[index].position
			_party_beans[index].size = _party_jar[index].size
			_paint_one(_party_beans[index], int(_party_beans[index].text), _party_limit[index])
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
	_read_scores()
	var up_end := _WAIT + _COUNT
	var hold_end := up_end + _HOLD
	var down_end := hold_end + _COUNT
	var cheer_end := down_end + _CHEER
	if _age >= cheer_end:
		_open_shop(false)
		return
	var cheering := _age >= down_end
	var best := 0
	for beans in _party_reward:
		best = maxi(best, beans)
	var local_counter := _counter
	var local_jar := _jar_shown
	for index in _party.size():
		var counter := _counter_at(_age, _party_reward[index])
		var jar := _jar_at(_age, index, counter)
		if index == _local_slot:
			local_counter = counter
			local_jar = jar
		if index < _party_score.size():
			_party_score[index].text = str(counter)
			_party_score[index].visible = not cheering
			_party_box[index].visible = not cheering
			_party_beans[index].text = str(jar)
			_paint_one(_party_beans[index], jar, _party_limit[index])
		var actor := _party[index]
		actor.position = _party_home[index]
		if cheering and _party_reward[index] == best and not _cheered:
			actor.play_gesture("leap", 1.0, false)
		actor.set_locomotion(0.0, false, false, delta)
	var changed := local_counter != _counter or local_jar != _jar_shown
	_counter = local_counter
	_jar_shown = local_jar
	if cheering and not _cheered:
		_cheered = true
		_grant()
		_jar_shown = _BEANS.pouch()
		if _local_slot < _party_beans.size():
			_party_beans[_local_slot].text = str(_jar_shown)
			_paint_one(_party_beans[_local_slot], _jar_shown, _party_limit[_local_slot])
		_effect("MG_win")
	elif changed and _age >= _WAIT:
		var limit := _BEANS.pouch_limit()
		if _local_slot < _party_limit.size():
			limit = _party_limit[_local_slot]
		_tick(_age >= hold_end and local_jar >= limit)


func _counter_at(age: float, beans: int) -> int:
	var up_end := _WAIT + _COUNT
	var hold_end := up_end + _HOLD
	var down_end := hold_end + _COUNT
	if age < _WAIT:
		return 0
	if age < up_end:
		return int(round(_ease((age - _WAIT) / _COUNT) * float(beans)))
	if age < hold_end:
		return beans
	if age < down_end:
		return int(round((1.0 - _ease((age - hold_end) / _COUNT)) * float(beans)))
	return 0


func _jar_at(age: float, index: int, counter: int) -> int:
	var hold_end := _WAIT + _COUNT + _HOLD
	var start := _party_pouch[index]
	var cap := _party_limit[index]
	if age < hold_end:
		return start
	return mini(start + (_party_reward[index] - counter), cap)


func _read_scores() -> void:
	var state := ToonNet.latest("trolley:%d" % ToonNet.district_id())
	var raw: Variant = state.get("results", {})
	if not (raw is Dictionary):
		return
	var results: Dictionary = raw
	for index in _party_peer.size():
		if index == _local_slot:
			continue
		var row: Variant = results.get(str(_party_peer[index]), {})
		if not (row is Dictionary):
			continue
		var info: Dictionary = row
		if not info.has("beans"):
			continue
		_party_reward[index] = int(info["beans"])
		_party_pouch[index] = int(info.get("pouch", _party_pouch[index]))
		_party_limit[index] = maxi(int(info.get("limit", _party_limit[index])), 1)


func _hide_party_cards() -> void:
	for box in _party_box:
		box.visible = false
	for number in _party_score:
		number.visible = false
	for jar in _party_jar:
		jar.visible = false
	for beans in _party_beans:
		beans.visible = false


func _paint_one(label: Label, shown: int, limit: int) -> void:
	var full := shown >= limit
	ToonGui.style_title(label, Color(1, 0, 0) if full else Color(0.95, 0.95, 0.0), _px_of(0.1))


func _open_shop(cheer: bool) -> void:
	_shopping = true
	_grant()
	_show_street(false)
	for actor in _party:
		actor.visible = false
	if _toon != null:
		_toon.visible = false
	_hide_party_cards()
	_build_heads()
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
	var full := _jar_shown >= _BEANS.pouch_limit()
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
	_BEANS.add_beans(reward * int(_HOLIDAYS.bean_scale("trolley")))


func _close(reason: String) -> void:
	if _closed:
		return
	_closed = true
	_grant()
	finished.emit(reason)
	queue_free()


func speaker() -> Node3D:
	return _toon


func _bind_chat() -> void:
	var host := get_parent()
	if host != null:
		_chat = host.find_child("SpeedChat", true, false) as SpeedChat
	if _chat != null:
		return
	var chat_layer := CanvasLayer.new()
	chat_layer.layer = 70
	add_child(chat_layer)
	_chat = SpeedChat.new()
	_chat.name = "SpeedChat"
	chat_layer.add_child(_chat)
	_chat.setup(_TASKS.for_selected())
	if not _chat.phrase_said.is_connected(_on_phrase):
		_chat.phrase_said.connect(_on_phrase)


func _on_phrase(text: String) -> void:
	if _toon == null:
		return
	var kind := "speed"
	if _chat != null and not _chat.phrase_is_speedchat:
		kind = "plus"
	_toon.set_meta("chat_line", text)
	_toon.set_meta("chat_kind", kind)
	_toon.set_meta("chat_until", Time.get_ticks_msec() + maxi(2800, text.length() * 45))
	ToonSpeech.speak(_toon, text)


## PurchaseHeadFrame. The local toon is the first card. The others use the original slots.
func _head_order(count: int) -> Array:
	if count <= 1:
		return [0]
	if count == 2:
		return [0, 2]
	if count == 3:
		return [0, 1, 3]
	return [0, 1, 2, 3]


func _build_heads() -> void:
	if not _heads.is_empty():
		for item in _heads:
			var root: Control = item.get("root")
			if root != null:
				root.visible = true
		return
	var spots: Array[Vector2] = [
		Vector2(0.105, -0.384),
		Vector2(0.105, -0.776),
		Vector2(0.85, -0.555),
		Vector2(-0.654, -0.555),
	]
	var order := _head_order(_party.size())
	var next := 1
	var art := load("res://assets/gui/purchase/Char_Pnl.png") as Texture2D
	for index in _party.size():
		var slot := 0
		if index != _local_slot:
			if next < order.size():
				slot = int(order[next])
			next += 1
		var at: Vector2 = spots[clampi(slot, 0, spots.size() - 1)]
		var root := Control.new()
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.z_index = 2
		_gui.add_child(root)
		var card := TextureRect.new()
		card.texture = art
		card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.stretch_mode = TextureRect.STRETCH_SCALE
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(card)
		var viewport := SubViewport.new()
		viewport.transparent_bg = true
		viewport.own_world_3d = true
		viewport.size = Vector2i(192, 224)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var world := WorldEnvironment.new()
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color(0, 0, 0, 0)
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(1, 1, 1)
		environment.ambient_light_energy = 1.15
		world.environment = environment
		viewport.add_child(world)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-35, 25, 0)
		sun.light_energy = 1.05
		viewport.add_child(sun)
		var camera := Camera3D.new()
		camera.current = true
		camera.fov = 24.0
		camera.near = 0.05
		viewport.add_child(camera)
		var box := SubViewportContainer.new()
		box.stretch = true
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(viewport)
		root.add_child(box)
		var portrait := ToonActor.new()
		portrait.load_extra_clips = false
		portrait.footsteps = false
		viewport.add_child(portrait)
		var raw: Variant = _party[index].get_meta("style", {})
		if raw is Dictionary:
			var style := ToonStyle.from_dict(raw)
			portrait.show_style(style)
			portrait.set_locomotion(0.0, false, false, 0.0)
			var top := style.avatar_height()
			var muzzle := 0.75 if style.head.length() > 1 and style.head[1] == "l" else 0.5
			var look := top - muzzle * 0.42
			camera.position = Vector3(0.08, look, 1.05)
			camera.look_at(Vector3(0.0, look - 0.02, 0.0))
		var name := Label.new()
		name.text = _party[index].name
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(name)
		var bubble := PanelContainer.new()
		bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bubble.visible = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(1, 1, 1, 0.98)
		fill.border_color = Color(0.05, 0.05, 0.05)
		fill.set_border_width_all(3)
		fill.set_corner_radius_all(12)
		fill.content_margin_left = 8
		fill.content_margin_right = 8
		fill.content_margin_top = 4
		fill.content_margin_bottom = 4
		bubble.add_theme_stylebox_override("panel", fill)
		var words := Label.new()
		words.name = "Words"
		words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bubble.add_child(words)
		root.add_child(bubble)
		_heads.append({
			"root": root,
			"box": box,
			"name": name,
			"bubble": bubble,
			"words": words,
			"actor": _party[index],
			"at": at,
		})


func _layout_heads() -> void:
	for item in _heads:
		var root: Control = item.get("root")
		if root == null:
			continue
		var at: Vector2 = item.get("at", Vector2.ZERO)
		var rect := _size(0.766, 0.4)
		root.position = _point(0.14 + at.x, -0.04 + at.y) - rect * 0.5
		root.size = rect
		var box: Control = item.get("box")
		if box != null:
			var head := _size(0.28, 0.32)
			box.position = rect * 0.5 + Vector2(_size(-0.16, 0.0).x, _size(0.0, 0.02).y) - head * 0.5
			box.size = head
		var name: Label = item.get("name")
		if name != null:
			var band := _size(0.7, 0.1)
			name.position = Vector2((rect.x - band.x) * 0.5, rect.y - band.y - 2.0)
			name.size = band
			ToonGui.style_label(name, Color(0.05, 0.14, 0.4), _px_of(0.045), Color(0, 0, 0, 0), 0)


func _paint_heads() -> void:
	for item in _heads:
		var actor: Node = item.get("actor")
		var bubble: PanelContainer = item.get("bubble")
		var words: Label = item.get("words")
		var root: Control = item.get("root")
		if actor == null or bubble == null or words == null or root == null:
			continue
		var line := String(actor.get_meta("chat_line", ""))
		var until := int(actor.get_meta("chat_until", 0))
		if line == "" or Time.get_ticks_msec() >= until:
			bubble.visible = false
			continue
		ToonGui.show_speech(words, line, _px_of(0.04))
		bubble.visible = true
		bubble.reset_size()
		bubble.position = Vector2((root.size.x - bubble.size.x) * 0.5, -bubble.size.y - 6.0)


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
