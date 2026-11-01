class_name ToonAvatarPanel
extends Control

## ToonAvatarPanel plus ToonAvatarDetailPanel. Clicking another toon's nametag
## opens the green card. Toon Details asks that toon for the gag page.

const _ZONES := preload("res://scenes/places/zone_title.gd")
const _CARD := preload("res://assets/gui/friends/avatar_panel.png")
const _INFO := preload("res://assets/gui/friends/avatarInfoPanel.png")
const _FRIEND_UP := preload("res://assets/gui/friends/Frnds_Btn_UP.png")
const _FRIEND_DOWN := preload("res://assets/gui/friends/Frnds_Btn_DN.png")
const _FRIEND_HOVER := preload("res://assets/gui/friends/Frnds_Btn_RLVR.png")
const _GOTO_UP := preload("res://assets/gui/friends/Go2_Btn_UP.png")
const _GOTO_DOWN := preload("res://assets/gui/friends/Go2_Btn_DN.png")
const _GOTO_HOVER := preload("res://assets/gui/friends/Go2_Btn_RLVR.png")
const _TRUE_UP := preload("res://assets/gui/friends/Amuse_Btn_UP.png")
const _TRUE_DOWN := preload("res://assets/gui/friends/Amuse_Btn_DN.png")
const _TRUE_HOVER := preload("res://assets/gui/friends/Amuse_Btn_RLVR.png")
const _IGNORE_UP := preload("res://assets/gui/friends/Ignore_Btn_UP.png")
const _IGNORE_DOWN := preload("res://assets/gui/friends/Ignore_Btn_DN.png")
const _IGNORE_HOVER := preload("res://assets/gui/friends/Ignore_Btn_RLVR.png")
const _DETAIL_UP := preload("res://assets/gui/friends/ChtBx_BackBtn_UP.png")
const _DETAIL_DOWN := preload("res://assets/gui/friends/ChtBx_BackBtn_DN.png")
const _DETAIL_HOVER := preload("res://assets/gui/friends/ChtBx_BackBtn_Rllvr.png")
const _CHAT_UP := preload("res://assets/gui/speedchat/ChtBx_ChtBtn_UP.png")
const _CHAT_DOWN := preload("res://assets/gui/speedchat/ChtBx_ChtBtn_DN.png")
const _CHAT_HOVER := preload("res://assets/gui/speedchat/ChtBx_ChtBtn_RLVR.png")
const _CLOSE_UP := preload("res://assets/toons/gui/CloseBtn_UP.png")
const _CLOSE_DOWN := preload("res://assets/toons/gui/CloseBtn_DN.png")
const _CLOSE_HOVER := preload("res://assets/toons/gui/CloseBtn_Rllvr.png")
const _OK_UP := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_UP.png")
const _OK_DOWN := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_DN.png")
const _OK_HOVER := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_Rllvr.png")
const _DIALOG := preload("res://assets/gui/tutorial/dialog/dialog_box.png")
const _GAGS: Array[Texture2D] = [
	preload("res://assets/gui/tutorial/gags/inventory_feather.png"),
	preload("res://assets/gui/tutorial/gags/inventory_megaphone.png"),
	preload("res://assets/gui/tutorial/gags/inventory_lipstick.png"),
	preload("res://assets/gui/tutorial/gags/inventory_bamboo_cane.png"),
	preload("res://assets/gui/tutorial/gags/inventory_pixiedust.png"),
	preload("res://assets/gui/tutorial/gags/inventory_juggling_cubes.png"),
	preload("res://assets/gui/tutorial/gags/inventory_ladder.png"),
	preload("res://assets/gui/tutorial/gags/inventory_bannana_peel.png"),
	preload("res://assets/gui/tutorial/gags/inventory_rake.png"),
	preload("res://assets/gui/tutorial/gags/inventory_marbles.png"),
	preload("res://assets/gui/tutorial/gags/inventory_quicksand_icon.png"),
	preload("res://assets/gui/tutorial/gags/inventory_trapdoor.png"),
	preload("res://assets/gui/tutorial/gags/inventory_tnt.png"),
	preload("res://assets/gui/tutorial/gags/inventory_traintracks.png"),
	preload("res://assets/gui/tutorial/gags/inventory_1dollarbill.png"),
	preload("res://assets/gui/tutorial/gags/inventory_small_magnet.png"),
	preload("res://assets/gui/tutorial/gags/inventory_5dollarbill.png"),
	preload("res://assets/gui/tutorial/gags/inventory_big_magnet.png"),
	preload("res://assets/gui/tutorial/gags/inventory_10dollarbill.png"),
	preload("res://assets/gui/tutorial/gags/inventory_hypno_goggles.png"),
	preload("res://assets/gui/tutorial/gags/inventory_screen.png"),
	preload("res://assets/gui/tutorial/gags/inventory_bikehorn.png"),
	preload("res://assets/gui/tutorial/gags/inventory_whistle.png"),
	preload("res://assets/gui/tutorial/gags/inventory_bugle.png"),
	preload("res://assets/gui/tutorial/gags/inventory_aoogah.png"),
	preload("res://assets/gui/tutorial/gags/inventory_elephant.png"),
	preload("res://assets/gui/tutorial/gags/inventory_fog_horn.png"),
	preload("res://assets/gui/tutorial/gags/inventory_opera_singer.png"),
	preload("res://assets/gui/tutorial/gags/inventory_tart.png"),
	preload("res://assets/gui/tutorial/gags/inventory_fruit_pie_slice.png"),
	preload("res://assets/gui/tutorial/gags/inventory_cream_pie_slice.png"),
	preload("res://assets/gui/tutorial/gags/inventory_fruitpie.png"),
	preload("res://assets/gui/tutorial/gags/inventory_creampie.png"),
	preload("res://assets/gui/tutorial/gags/inventory_cake.png"),
	preload("res://assets/gui/tutorial/gags/inventory_wedding.png"),
	preload("res://assets/gui/tutorial/gags/inventory_squirt_flower.png"),
	preload("res://assets/gui/tutorial/gags/inventory_glass_of_water.png"),
	preload("res://assets/gui/tutorial/gags/inventory_water_gun.png"),
	preload("res://assets/gui/tutorial/gags/inventory_seltzer_bottle.png"),
	preload("res://assets/gui/tutorial/gags/inventory_firehose.png"),
	preload("res://assets/gui/tutorial/gags/inventory_storm_cloud.png"),
	preload("res://assets/gui/tutorial/gags/inventory_geyser.png"),
	preload("res://assets/gui/tutorial/gags/inventory_flower_pot.png"),
	preload("res://assets/gui/tutorial/gags/inventory_sandbag.png"),
	preload("res://assets/gui/tutorial/gags/inventory_anvil.png"),
	preload("res://assets/gui/tutorial/gags/inventory_weight.png"),
	preload("res://assets/gui/tutorial/gags/inventory_safe_box.png"),
	preload("res://assets/gui/tutorial/gags/inventory_piano.png"),
	preload("res://assets/gui/tutorial/gags/inventory_ship.png"),
]

const _TRACKS: PackedStringArray = ["TOON-UP", "TRAP", "LURE", "SOUND", "THROW", "SQUIRT", "DROP"]
const _ROW_Y: PackedFloat32Array = [56, 64, 72, 80, 88, 96, 104]
const _CARD_W := 0.4542
const _CARD_H := 0.9458
const _HOVER_INK := Color(1, 1, 0.5)
const _DOWN_INK := Color(0.5, 1, 0.5)
const _DISABLED_INK := Color(0.6, 0.6, 0.6)
const _CREAM := Color(1, 1, 0.75, 1)
const _OWNED := Color(0, 0.6, 1, 1)
const _EMPTY := Color(0.5, 0.5, 0.5, 1)

var _av := 0
var _called := ""
var _actor: Node3D
var _detail_state := "off"
var _detail_token := 0
var _social_bound := false
var _card_at := Vector2(1.1, 0.525)
var _detail_at := Vector2(0.35, 0.525)
var _detail_size := Vector2(0.92, 0.92)
var _laid := Vector2.ZERO
var _well: Texture2D
var _card: TextureRect
var _head_box: SubViewportContainer
var _viewport: SubViewport
var _camera: Camera3D
var _portrait: ToonActor
var _name_label: Label
var _hp_text: Label
var _meter: LaffMeter
var _row_buttons: Array[TextureButton] = []
var _row_labels: Array[Label] = []
var _detail_button: TextureButton
var _detail_tip: Label
var _close_button: TextureButton
var _info: TextureRect
var _info_name: Label
var _info_body: Label
var _info_close: TextureButton
var _info_close_label: Label
var _track_nodes: Array[Control] = []
var _shade: ColorRect
var _dialog: TextureRect
var _dialog_text: Label
var _notice_buttons: Array[TextureButton] = []
var _notice_labels: Array[Label] = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 38
	if ResourceLoader.exists("res://assets/gui/friends/InventoryButtonUp.png"):
		_well = load("res://assets/gui/friends/InventoryButtonUp.png")
	_build_card()
	_build_detail()
	_build_dialog()
	_bind_social()


func _process(_delta: float) -> void:
	_watch_tags()
	_bind_social()
	if _filming():
		if _card.visible or _info.visible or _shade.visible:
			close()
		return
	if _card.visible and (_actor == null or not is_instance_valid(_actor) or not _actor.visible):
		close()
		return
	if _card.visible:
		_sync_laff()
	var view := get_viewport().get_visible_rect().size
	if view != _laid:
		_laid = view
		_layout()


func close() -> void:
	_hide_side()
	_close_detail()
	_hide_notice()


## FriendsListPanel's Details button. The green friend card stays; this is the gag page.
func open_details(av: int, called: String) -> void:
	if av <= 0:
		return
	if _card.visible and _av != av:
		_hide_side()
	_av = av
	_called = called
	_open_detail()


func _on_toon(actor: Node3D) -> void:
	if actor == null or not is_instance_valid(actor) or Nametags.picking_friends:
		return
	var av := int(actor.get_meta("av", 0))
	if av <= 0 or av == ToonRoster.avatar_id():
		return
	if _card.visible and av == _av:
		return
	_show_side(actor, av)


func _show_side(actor: Node3D, av: int) -> void:
	_close_detail()
	_hide_notice()
	_av = av
	_actor = actor
	_called = actor.name
	_card.visible = true
	_name_label.visible = true
	_name_label.text = _called
	_hp_text.visible = true
	_head_box.visible = true
	for button in _row_buttons:
		button.visible = true
	for label in _row_labels:
		label.visible = true
	_detail_button.visible = true
	_close_button.visible = true
	_show_head()
	_sync_laff()
	_refresh_lock()
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var friends := _friends()
	if friends != null and friends.has_method("close_card"):
		friends.call("close_card")
	_laid = Vector2.ZERO


func _hide_side() -> void:
	if _card == null:
		return
	_card.visible = false
	_name_label.visible = false
	_hp_text.visible = false
	_head_box.visible = false
	_detail_tip.visible = false
	if _meter != null:
		_meter.visible = false
	for button in _row_buttons:
		button.visible = false
	for label in _row_labels:
		label.visible = false
	_detail_button.visible = false
	_close_button.visible = false
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_actor = null


func _open_detail() -> void:
	_detail_token += 1
	var token := _detail_token
	_clear_tracks()
	_info.visible = true
	_info_name.visible = true
	_info_name.text = _called
	_info_body.visible = true
	_info_close.visible = true
	_info_close_label.visible = true
	_info_close_label.text = "Cancel"
	_detail_state = "query"
	var where := ToonSocial.lookup(_av)
	var standing := _actor != null and is_instance_valid(_actor) and _actor.visible
	if where.is_empty() and not standing:
		_show_offline()
		_laid = Vector2.ZERO
		return
	_info_body.text = "Looking up details for %s." % _called
	var social := ToonSocial.live()
	if social == null or not ToonNet.networked():
		_show_failed()
		_laid = Vector2.ZERO
		return
	social.request_card(_av)
	_wait_card(token)
	_laid = Vector2.ZERO


func _wait_card(token: int) -> void:
	await get_tree().create_timer(6.0).timeout
	if not is_inside_tree() or token != _detail_token or _detail_state != "query":
		return
	_show_failed()


func _on_card(card: Dictionary) -> void:
	if _detail_state != "query" or int(card.get("from_av", -1)) != _av:
		return
	_detail_token += 1
	if String(card.get("kind", "")) != "card_give":
		_show_failed()
		return
	_show_data(card)


func _show_offline() -> void:
	_detail_state = "data"
	_info_body.text = "District: offline\nLocation: offline"
	_info_close_label.text = "Close"
	_clear_tracks()


func _show_failed() -> void:
	_detail_state = "invalid"
	_info_body.text = "Unable to get details for %s." % _called
	_info_close_label.text = "Close"
	_clear_tracks()
	_laid = Vector2.ZERO


func _show_data(card: Dictionary) -> void:
	_detail_state = "data"
	_info_body.text = _district_text()
	_info_close_label.text = "Close"
	_build_tracks(card)
	if _card.visible and _meter != null:
		_meter.set_hp(int(card.get("hp", 15)), int(card.get("max", 15)), true)
	_laid = Vector2.ZERO


func _close_detail() -> void:
	_detail_token += 1
	_detail_state = "off"
	if _info == null:
		return
	_info.visible = false
	_info_name.visible = false
	_info_body.visible = false
	_info_close.visible = false
	_info_close_label.visible = false
	_clear_tracks()


func _build_card() -> void:
	_card = TextureRect.new()
	_card.texture = _CARD
	_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card.stretch_mode = TextureRect.STRETCH_SCALE
	_card.mouse_filter = MOUSE_FILTER_STOP
	_card.visible = false
	add_child(_card)
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.size = Vector2i(256, 320)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1, 1, 1)
	environment.ambient_light_energy = 1.15
	world.environment = environment
	_viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	sun.light_energy = 1.05
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 24.0
	_camera.near = 0.05
	_viewport.add_child(_camera)
	_head_box = SubViewportContainer.new()
	_head_box.stretch = true
	_head_box.mouse_filter = MOUSE_FILTER_IGNORE
	_head_box.visible = false
	_head_box.add_child(_viewport)
	add_child(_head_box)
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.mouse_filter = MOUSE_FILTER_IGNORE
	_name_label.visible = false
	add_child(_name_label)
	_hp_text = Label.new()
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_text.mouse_filter = MOUSE_FILTER_IGNORE
	_hp_text.visible = false
	add_child(_hp_text)
	_add_row("Friends", _FRIEND_UP, _FRIEND_DOWN, _FRIEND_HOVER, Vector2(-0.103, 0.133), _befriend)
	_add_row("Go To", _GOTO_UP, _GOTO_DOWN, _GOTO_HOVER, Vector2(-0.103, 0.045), _go)
	_add_row("Whisper", _CHAT_UP, _CHAT_DOWN, _CHAT_HOVER, Vector2(-0.103, -0.0375), _whisper)
	_add_row("True Friends", _TRUE_UP, _TRUE_DOWN, _TRUE_HOVER, Vector2(-0.103, -0.13), _secrets)
	_add_row("Ignore", _IGNORE_UP, _IGNORE_DOWN, _IGNORE_HOVER, Vector2(-0.1037, -0.21), _ask_ignore)
	_detail_button = _make_button(_DETAIL_UP, _DETAIL_DOWN, _DETAIL_HOVER, _open_from_card)
	_detail_button.visible = false
	_detail_button.mouse_entered.connect(func() -> void: _detail_tip.visible = true)
	_detail_button.mouse_exited.connect(func() -> void: _detail_tip.visible = false)
	_detail_tip = Label.new()
	_detail_tip.text = "Toon Details"
	_detail_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_detail_tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_tip.mouse_filter = MOUSE_FILTER_IGNORE
	_detail_tip.visible = false
	add_child(_detail_tip)
	_close_button = _make_button(_CLOSE_UP, _CLOSE_DOWN, _CLOSE_HOVER, close)
	_close_button.visible = false


func _build_detail() -> void:
	_info = TextureRect.new()
	_info.texture = _INFO
	_info.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_info.stretch_mode = TextureRect.STRETCH_SCALE
	_info.modulate = _CREAM
	_info.mouse_filter = MOUSE_FILTER_STOP
	_info.visible = false
	add_child(_info)
	_info_name = Label.new()
	_info_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_name.mouse_filter = MOUSE_FILTER_IGNORE
	_info_name.visible = false
	add_child(_info_name)
	_info_body = Label.new()
	_info_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_info_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_body.mouse_filter = MOUSE_FILTER_IGNORE
	_info_body.visible = false
	add_child(_info_body)
	_info_close = _make_button(_CLOSE_UP, _CLOSE_DOWN, _CLOSE_HOVER, _close_detail)
	_info_close.visible = false
	_info_close_label = Label.new()
	_info_close_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info_close_label.mouse_filter = MOUSE_FILTER_IGNORE
	_info_close_label.visible = false
	add_child(_info_close_label)


func _build_dialog() -> void:
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0.35)
	_shade.mouse_filter = MOUSE_FILTER_STOP
	_shade.visible = false
	_shade.z_index = 20
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_dialog = TextureRect.new()
	_dialog.texture = _DIALOG
	_dialog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dialog.stretch_mode = TextureRect.STRETCH_SCALE
	_dialog.modulate = _CREAM
	_dialog.mouse_filter = MOUSE_FILTER_STOP
	_dialog.visible = false
	_dialog.z_index = 21
	add_child(_dialog)
	_dialog_text = Label.new()
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_dialog_text.mouse_filter = MOUSE_FILTER_IGNORE
	_dialog_text.visible = false
	_dialog_text.z_index = 22
	add_child(_dialog_text)


func _add_row(text: String, up: Texture2D, down: Texture2D, hover: Texture2D, at: Vector2, action: Callable) -> void:
	var button := _make_button(up, down, hover, action)
	button.visible = false
	button.set_meta("at", at)
	_row_buttons.append(button)
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.visible = false
	label.set_meta("button", button)
	add_child(label)
	_row_labels.append(label)
	button.mouse_entered.connect(_tint.bind(label, _HOVER_INK))
	button.mouse_exited.connect(_tint.bind(label, Color.WHITE))
	button.button_down.connect(_tint.bind(label, _DOWN_INK))
	button.button_up.connect(_tint.bind(label, _HOVER_INK))


func _make_button(up: Texture2D, down: Texture2D, hover: Texture2D, action: Callable) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = up
	button.texture_pressed = down
	button.texture_hover = hover
	button.texture_disabled = up
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	ToonGui.button_sounds(button)
	add_child(button)
	return button


func _show_head() -> void:
	if _actor == null or not is_instance_valid(_actor):
		return
	var raw: Variant = _actor.get_meta("style", {})
	if not (raw is Dictionary):
		return
	var style := ToonStyle.from_dict(raw)
	if _portrait != null:
		_portrait.queue_free()
		_portrait = null
	_portrait = ToonActor.new()
	_portrait.name = "Portrait"
	_portrait.load_extra_clips = false
	_portrait.footsteps = false
	_viewport.add_child(_portrait)
	_portrait.show_style(style)
	_portrait.set_locomotion(0.0, false, false, 0.0)
	var top := style.avatar_height()
	var muzzle := 0.75 if style.head.length() > 1 and style.head[1] == "l" else 0.5
	var look := top - muzzle * 0.42
	_camera.position = Vector3(0.08, look, 1.05)
	_camera.look_at(Vector3(0.0, look - 0.02, 0.0))
	if _meter != null:
		_meter.visible = false
		_meter.queue_free()
	_meter = LaffMeter.new()
	_meter.name = "PanelLaff"
	_meter.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_meter)
	_meter.setup(style)
	_meter.visible = true


func _sync_laff() -> void:
	if _meter == null or _actor == null or not is_instance_valid(_actor):
		return
	var current := int(_actor.get_meta("hp", 15))
	var maximum := int(_actor.get_meta("max_hp", current))
	_meter.set_hp(current, maximum, true)
	_hp_text.text = "%d / %d" % [current, maximum]


func _build_tracks(card: Dictionary) -> void:
	_clear_tracks()
	var exp: Array = card.get("exp", [])
	var counts: Array = card.get("counts", [])
	var open: Array = card.get("open", [])
	for track in _TRACKS.size():
		var label := Label.new()
		label.text = _TRACKS[track]
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(label)
		label.set_meta("row", track)
		label.set_meta("col", -1)
		_track_nodes.append(label)
		if track >= open.size() or int(open[track]) == 0:
			continue
		var points := 0
		if track < exp.size():
			points = int(exp[track])
		for level in 7:
			if points < ToonLoadout.skill_at(track, level):
				break
			var slot := track * 7 + level
			var count := 0
			if slot < counts.size():
				count = int(counts[slot])
			if _well != null:
				var back := TextureRect.new()
				back.texture = _well
				back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				back.stretch_mode = TextureRect.STRETCH_SCALE
				back.mouse_filter = MOUSE_FILTER_IGNORE
				back.modulate = _OWNED if count > 0 else _EMPTY
				add_child(back)
				back.set_meta("row", track)
				back.set_meta("col", level)
				back.set_meta("well", true)
				_track_nodes.append(back)
			var icon := TextureRect.new()
			icon.texture = _GAGS[slot]
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = MOUSE_FILTER_IGNORE
			icon.modulate = Color.WHITE if count > 0 else Color(0.25, 0.25, 0.25, 0.55)
			add_child(icon)
			icon.set_meta("row", track)
			icon.set_meta("col", level)
			_track_nodes.append(icon)


func _clear_tracks() -> void:
	for node in _track_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_track_nodes.clear()


func _befriend() -> void:
	if _actor == null or not is_instance_valid(_actor):
		_notice("%s is busy right now; try again later." % _called, ["OK"], [_hide_notice])
		return
	var friends := _friends()
	if friends != null and friends.has_method("invite_toon"):
		friends.call("invite_toon", _actor)
		return
	_notice("Cannot make friends now.", ["OK"], [_hide_notice])


func _go() -> void:
	var where := ToonSocial.lookup(_av)
	if where.is_empty():
		_notice("%s went away." % _called, ["OK"], [_hide_notice])
		return
	if not _can_travel():
		_notice("You can't go to %s from here." % _called, ["OK"], [_hide_notice])
		return
	if int(where.get("district", -1)) != ToonNet.district_id():
		_notice(
			"%s is in the %s District." % [_called, String(where.get("district_name", "another"))],
			["OK"],
			[_hide_notice]
		)
		return
	var place := String(where.get("place", ""))
	if place == "":
		_notice("%s went away." % _called, ["OK"], [_hide_notice])
		return
	var point := Vector3(float(where.get("x", 0.0)), float(where.get("y", 0.0)), float(where.get("z", 0.0)))
	point += Vector3(3.0, 0.0, 0.0)
	var heading := float(where.get("heading", 0.0))
	var here := ""
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		here = tree.current_scene.scene_file_path
	if here == place:
		var host := _scene()
		if host != null and host.has_method("visit_friend"):
			host.call("visit_friend", point, heading)
			close()
			return
		_notice("You can't reach %s from here." % _called, ["OK"], [_hide_notice])
		return
	ToonSocial.visit_on = true
	ToonSocial.visit_scene = place
	ToonSocial.visit_point = point
	ToonSocial.visit_heading = heading
	close()
	ToonLoading.change_to(place)


func _whisper() -> void:
	var chat := _speed()
	if chat == null or not chat.ready_to_type():
		_notice(
			"SpeedChat+ is where you whisper to other Toons.\nYou can try that later.",
			["OK"],
			[_hide_notice]
		)
		return
	if ToonSocial.lookup(_av).is_empty():
		_notice("This only works if %s is online" % _called, ["OK"], [_hide_notice])
		return
	var called := _called
	var av := _av
	close()
	chat.whisper_to(called, -1, av)


func _secrets() -> void:
	var friends := _friends()
	if friends != null and friends.has_method("open_true_friends"):
		close()
		friends.call("open_true_friends")
		return
	_notice("You can't get a True Friend Code right now.", ["OK"], [_hide_notice])


func _ask_ignore() -> void:
	if FriendsBook.has_id("av:%d" % _av):
		_notice(
			"%s is your friend, you cannot ignore them while you are friends." % _called,
			["Cancel"],
			[_hide_notice]
		)
		return
	if FriendsBook.ignored_av(_av):
		_notice(
			"Ignore A Player\n\nWould you like to stop ignoring %s?" % _called,
			["Yes", "No"],
			[_stop_ignore, _hide_notice]
		)
		return
	_notice(
		"Ignore A Player\n\nWould you like to ignore %s for the rest of this session?" % _called,
		["Yes", "No"],
		[_start_ignore, _hide_notice]
	)


func _start_ignore() -> void:
	FriendsBook.ignore_for_session(_av, true)
	_hide_notice()
	_notice("You are now ignoring %s." % _called, ["OK"], [_hide_notice])
	_refresh_lock()


func _stop_ignore() -> void:
	FriendsBook.ignore_for_session(_av, false)
	_hide_notice()
	_notice("You are no longer ignoring %s." % _called, ["OK"], [_hide_notice])
	_refresh_lock()


func _open_from_card() -> void:
	_detail_tip.visible = false
	_open_detail()


func _notice(text: String, captions: Array, actions: Array) -> void:
	_clear_notice()
	_shade.visible = true
	_dialog.visible = true
	_dialog_text.visible = true
	_dialog_text.text = text
	for index in captions.size():
		var caption := String(captions[index])
		var up := _OK_UP
		var down := _OK_DOWN
		var hover := _OK_HOVER
		if caption == "No" or caption == "Cancel":
			up = _CLOSE_UP
			down = _CLOSE_DOWN
			hover = _CLOSE_HOVER
		var button := _make_button(up, down, hover, actions[index])
		button.visible = true
		button.z_index = 23
		_notice_buttons.append(button)
		var label := Label.new()
		label.z_index = 24
		label.text = caption
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(label)
		_notice_labels.append(label)
	_laid = Vector2.ZERO


func _hide_notice() -> void:
	_clear_notice()
	if _shade != null:
		_shade.visible = false
	if _dialog != null:
		_dialog.visible = false
	if _dialog_text != null:
		_dialog_text.visible = false


func _clear_notice() -> void:
	for button in _notice_buttons:
		if is_instance_valid(button):
			button.queue_free()
	for label in _notice_labels:
		if is_instance_valid(label):
			label.queue_free()
	_notice_buttons.clear()
	_notice_labels.clear()


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.y < 2.0:
		return
	var unit := view.y * 0.5
	var edge := view.x / view.y
	var card_x := maxf(1.1, edge - 0.02 - _CARD_W * 0.5)
	_card_at = Vector2(card_x, 0.525)
	_detail_size = Vector2(0.92, 0.92)
	var detail_x := _card_at.x - _CARD_W * 0.5 - 0.04 - _detail_size.x * 0.5
	var min_x := -edge + 0.02 + _detail_size.x * 0.5
	if detail_x < min_x:
		detail_x = min_x
	_detail_at = Vector2(detail_x, 0.525)
	ToonGui.place(_card, view, _card_at.x, _card_at.y, _CARD_W, _CARD_H)
	_place_card(_head_box, view, 0.02, 0.27, 0.22, 0.26)
	_place_card(_name_label, view, 0.0125, 0.40, 0.36, 0.08)
	ToonGui.style_label(_name_label, Color.BLACK, int(unit * 0.042), Color.WHITE, maxi(int(unit * 0.008), 1))
	_place_card(_hp_text, view, 0.06, 0.20, 0.16, 0.06)
	ToonGui.style_label(_hp_text, Color.BLACK, int(unit * 0.04), Color(0, 0, 0, 0), 0)
	if _meter != null and _meter.visible:
		var center := Vector2(view.x * 0.5 + (_card_at.x - 0.1) * unit, view.y * 0.5 - (_card_at.y + 0.24) * unit)
		_meter.place(center, unit * 0.09)
	for index in _row_buttons.size():
		var button := _row_buttons[index]
		var at: Vector2 = button.get_meta("at")
		_place_card(button, view, at.x, at.y, 0.095, 0.085)
		var label := _row_labels[index]
		_place_card(label, view, at.x + 0.145, at.y, 0.22, 0.07)
		ToonGui.style_label(label, Color.WHITE, int(unit * 0.04), Color(0.1, 0.25, 0.55), maxi(int(unit * 0.006), 1))
	_place_card(_detail_button, view, -0.134, -0.395, 0.09, 0.08)
	_place_card(_detail_tip, view, -0.02, -0.395, 0.22, 0.06)
	ToonGui.style_label(_detail_tip, Color.WHITE, int(unit * 0.035), Color(0.1, 0.25, 0.55), maxi(int(unit * 0.005), 1))
	_place_card(_close_button, view, 0.158, -0.379, 0.09, 0.09)
	ToonGui.place(_info, view, _detail_at.x, _detail_at.y, _detail_size.x, _detail_size.y)
	_place_tex(_info_name, view, 12, 8, 104, 22)
	ToonGui.style_label(_info_name, Color.BLACK, int(unit * 0.042), Color(0, 0, 0, 0), 0)
	_place_tex(_info_body, view, 14, 22, 108, 46)
	ToonGui.style_label(_info_body, Color.BLACK, int(unit * 0.034), Color(0, 0, 0, 0), 0)
	_place_tex(_info_close, view, 2, 108, 20, 123)
	_place_tex(_info_close_label, view, 22, 110, 78, 122)
	ToonGui.style_label(_info_close_label, Color.WHITE, int(unit * 0.032), Color(0.05, 0.25, 0.05), maxi(int(unit * 0.005), 1))
	for node in _track_nodes:
		if not is_instance_valid(node):
			continue
		var row := int(node.get_meta("row", 0))
		var col := int(node.get_meta("col", -1))
		var mid := _ROW_Y[row]
		if col < 0:
			_place_tex(node, view, 10, mid - 4, 40, mid + 4)
			var row_px := (8.0 / 128.0) * _detail_size.y * unit
			ToonGui.style_label(node as Label, Color.BLACK, maxi(int(row_px * 0.7), 8), Color(0, 0, 0, 0), 0)
		else:
			var x0 := 42.0 + float(col) * 9.0
			var well := bool(node.get_meta("well", false))
			if well:
				_place_tex(node, view, x0, mid - 3.5, x0 + 8.5, mid + 3.5)
			else:
				_place_tex(node, view, x0 + 0.6, mid - 3.0, x0 + 7.8, mid + 3.0)
	_refresh_lock()
	if _shade.visible:
		_layout_notice(view)


func _layout_notice(view: Vector2) -> void:
	var unit := view.y * 0.5
	var wide := _dialog_text.text.length() > 140
	var box := Vector2(1.45, 1.05) if wide else Vector2(1.2, 0.85)
	var center_z := 0.2
	ToonGui.place(_dialog, view, 0.0, center_z, box.x, box.y)
	var count := _notice_buttons.size()
	var button_w := 0.42 if count > 1 else 0.55
	var button_h := 0.12
	var buttons_z := center_z - box.y * 0.32
	for index in count:
		var button := _notice_buttons[index]
		var x := (float(index) - float(count - 1) * 0.5) * (button_w + 0.08)
		ToonGui.place(button, view, x, buttons_z, button_w, button_h)
		var caption := _notice_labels[index]
		caption.position = button.position
		caption.size = button.size
		ToonGui.style_label(caption, Color.WHITE, int(unit * 0.03), Color(0.15, 0.35, 0.7), maxi(int(unit * 0.006), 1))
	var content_bottom := _dialog.position.y + _dialog.size.y * 0.8
	if count > 0:
		content_bottom = _notice_buttons[0].position.y - unit * 0.03
	var inset_x := _dialog.size.x * 0.12
	var inset_top := _dialog.size.y * 0.14
	_dialog_text.position = _dialog.position + Vector2(inset_x, inset_top)
	_dialog_text.size = Vector2(_dialog.size.x - inset_x * 2.0, maxf(unit * 0.16, content_bottom - _dialog_text.position.y))
	ToonGui.style_label(_dialog_text, Color.BLACK, int(unit * 0.034), Color(0, 0, 0, 0), 0)


func _place_card(control: Control, view: Vector2, x: float, z: float, width: float, height: float) -> void:
	ToonGui.place(control, view, _card_at.x + x, _card_at.y + z, width, height)


func _place_tex(control: Control, view: Vector2, x0: float, y0: float, x1: float, y1: float) -> void:
	var cx := (x0 + x1) * 0.5 / 128.0
	var cy := (y0 + y1) * 0.5 / 128.0
	var ax := _detail_at.x + (cx - 0.5) * _detail_size.x
	var az := _detail_at.y + (0.5 - cy) * _detail_size.y
	ToonGui.place(control, view, ax, az, (x1 - x0) / 128.0 * _detail_size.x, (y1 - y0) / 128.0 * _detail_size.y)


func _refresh_lock() -> void:
	if _row_buttons.is_empty():
		return
	var blocked := _av > 0 and FriendsBook.ignored_av(_av)
	var travel := _can_travel()
	for index in _row_buttons.size():
		var button := _row_buttons[index]
		var label := _row_labels[index]
		var lock := blocked and index != 4
		if index == 1 and not travel:
			lock = true
		button.disabled = lock
		button.modulate.a = 0.4 if lock else 1.0
		if lock:
			label.add_theme_color_override("font_color", _DISABLED_INK)
	if _row_labels.size() > 4:
		_row_labels[4].text = "Stop Ignoring" if blocked else "Ignore"


func _tint(label: Label, color: Color) -> void:
	var button: Variant = label.get_meta("button", null)
	if button is BaseButton and (button as BaseButton).disabled:
		return
	label.add_theme_color_override("font_color", color)


func _district_text() -> String:
	var where := ToonSocial.lookup(_av)
	if where.is_empty():
		return "District: offline\nLocation: offline"
	var district := String(where.get("district_name", "offline"))
	if district == "":
		district = "offline"
	var loc := _hood_name(String(where.get("place", "")))
	if loc == "":
		loc = _pretty(String(where.get("spot", "")))
	if loc == "":
		loc = "offline"
	return "District: %s\nLocation: %s" % [district, loc]


func _hood_name(place: String) -> String:
	if place == "":
		return ""
	var found: Dictionary = _ZONES.caption(place)
	var text := String(found.get("text", ""))
	if text == "":
		return ""
	return text.get_slice("\n", 0)


func _pretty(raw: String) -> String:
	var titled := ""
	for word in raw.replace("_", " ").split(" ", false):
		if word.is_empty():
			continue
		if not titled.is_empty():
			titled += " "
		titled += word.substr(0, 1).to_upper() + word.substr(1)
	return titled


func _can_travel() -> bool:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return false
	return not tree.current_scene.scene_file_path.contains("/trolley/")


func _watch_tags() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("nametag_boards"):
		var tags := node as Nametags
		if tags != null and not tags.toon_clicked.is_connected(_on_toon):
			tags.toon_clicked.connect(_on_toon)


func _bind_social() -> void:
	if _social_bound:
		return
	var social := ToonSocial.live()
	if social == null:
		return
	if not social.card_ready.is_connected(_on_card):
		social.card_ready.connect(_on_card)
	_social_bound = true


func _friends() -> Node:
	var hud := get_parent()
	if hud != null:
		var found := hud.get_node_or_null("FriendsList")
		if found != null:
			return found
	return null


func _speed() -> SpeedChat:
	var hud := get_parent()
	if hud == null:
		return null
	return hud.get_node_or_null("SpeedChat") as SpeedChat


func _scene() -> Node:
	var layer := get_parent()
	if layer == null:
		return null
	return layer.get_parent()


func _filming() -> bool:
	var host := _scene()
	return host != null and host.has_method("in_cutscene") and bool(host.call("in_cutscene"))
