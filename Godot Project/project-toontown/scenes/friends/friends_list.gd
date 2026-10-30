class_name FriendsList
extends Control

## FriendsListPanel and the toon card it opens. The closed picture sits where
## LocalToon put bFriendsList. F7 is OTPGlobals.FriendsListHotkey. Pages run
## pets, online toons, all toons, online players, all players, then ignored.

const _KEYS := preload("res://scenes/shticker/keybinds.gd")
const _CLOSED := preload("res://assets/gui/friends/FriendsBox_Closed.png")
const _ROLLOVER := preload("res://assets/gui/friends/FriendsBox_Rollover.png")
const _OPEN := preload("res://assets/gui/friends/FriendsBox_Open.png")
const _SCROLL_UP := preload("res://assets/gui/friends/FndsLst_ScrollUp.png")
const _SCROLL_DOWN := preload("res://assets/gui/friends/FndsLst_ScrollDN.png")
const _SCROLL_HOVER := preload("res://assets/gui/friends/FndsLst_ScrollUp_Rllvr.png")
const _ARROW_UP := preload("res://assets/gui/friends/Horiz_Arrow_UP.png")
const _ARROW_DOWN := preload("res://assets/gui/friends/Horiz_Arrow_DN.png")
const _ARROW_HOVER := preload("res://assets/gui/friends/Horiz_Arrow_Rllvr.png")
const _CARD := preload("res://assets/gui/friends/avatar_panel.png")
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
const _QUIT_UP := preload("res://assets/toons/gui/QuitBtn_UP.png")
const _QUIT_DOWN := preload("res://assets/toons/gui/QuitBtn_DN.png")
const _QUIT_HOVER := preload("res://assets/toons/gui/QuitBtn_RLVR.png")
const _OK_UP := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_UP.png")
const _OK_DOWN := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_DN.png")
const _OK_HOVER := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_Rllvr.png")
const _DIALOG := preload("res://assets/gui/tutorial/dialog/dialog_box.png")

const _TITLES: PackedStringArray = [
	"NEARBY\nPETS",
	"ONLINE TOON\nFRIENDS",
	"ALL TOON\nFRIENDS",
	"ONLINE PLAYER\nFRIENDS",
	"ALL PLAYER\nFRIENDS",
	"IGNORED\nTOONS",
]
const _VISIBLE := 8
const _OFFLINE := Color(0.8, 0.5, 0.1)
const _SPEED := Color(0.2, 0.6, 0.4)
const _TRUE := Color(0.3, 0.3, 0.8)
const _HOVER := Color(1, 1, 0)
const _DOWN := Color(0.5, 0.9, 1)
const _CREAM := Color(1, 1, 0.75, 1)
const _PANEL_W := 0.5208
const _PANEL_H := 0.975
const _CARD_W := 0.4542
const _CARD_H := 0.9458
const _BUTTON_W := 0.3667 * 0.8
const _BUTTON_H := 0.3708 * 0.8
const _CORNER_PAD := 0.02

var _page := 1
var _obscured := false
var _picking := false
var _cog_token := 0
var _scroll := 0
var _list_open := false
var _picked: Dictionary = {}
var _button: TextureButton
var _caption: Label
var _panel: TextureRect
var _title: Label
var _names: Control
var _up: TextureButton
var _down: TextureButton
var _left: TextureButton
var _right: TextureButton
var _close: TextureButton
var _new_friend: TextureButton
var _secrets: TextureButton
var _card: TextureRect
var _card_name: Label
var _card_buttons: Array[TextureButton] = []
var _card_labels: Array[Label] = []
var _shade: ColorRect
var _dialog: TextureRect
var _dialog_text: Label
var _dialog_edit: LineEdit
var _dialog_buttons: Array[TextureButton] = []
var _dialog_captions: Array[Label] = []
var _panel_at := Vector2(1.1, 0.54)
var _card_at := Vector2(1.1, 0.525)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_button()
	_build_list()
	_build_card()
	_build_dialog()
	var view := get_viewport()
	if not view.size_changed.is_connected(_layout):
		view.size_changed.connect(_layout)
	_layout()
	_apply_page()


func _process(_delta: float) -> void:
	var host := _host()
	var filming := host != null and host.has_method("in_cutscene") and bool(host.call("in_cutscene"))
	if filming:
		_hide_list()
		_hide_card()
		_hide_dialog()
	var playing := not filming and not _obscured and not _list_open and not _card.visible
	_button.visible = playing
	if not playing:
		_caption.visible = false


## SuitAvatarPanel and ToonAvatarPanel hide bFriendsList while a card is open.
func obscure_button(hidden: bool) -> void:
	_obscured = hidden
	if hidden:
		_hide_list()
		_hide_card()
		_hide_dialog()


func _unhandled_input(event: InputEvent) -> void:
	if _KEYS.typing():
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var f7 := key.keycode == KEY_F7 or key.physical_keycode == KEY_F7
	if f7 and not _list_open and not _card.visible and not _shade.visible:
		_open_list()
		get_viewport().set_input_as_handled()
		return
	if (key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE) and _shade.visible:
		_hide_dialog()
		get_viewport().set_input_as_handled()


func _build_button() -> void:
	_button = TextureButton.new()
	_button.texture_normal = _CLOSED
	_button.texture_hover = _ROLLOVER
	_button.texture_pressed = _ROLLOVER
	_button.ignore_texture_size = true
	_button.stretch_mode = TextureButton.STRETCH_SCALE
	_button.focus_mode = Control.FOCUS_NONE
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_button.pressed.connect(_open_list)
	_button.mouse_entered.connect(func() -> void: _caption.visible = true)
	_button.mouse_exited.connect(func() -> void: _caption.visible = false)
	ToonGui.button_sounds(_button)
	add_child(_button)
	_caption = Label.new()
	_caption.text = "Friends"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.visible = false
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(_caption, Color.WHITE, 16, Color.BLACK, 2)
	add_child(_caption)


func _build_list() -> void:
	_panel = TextureRect.new()
	_panel.texture = _OPEN
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	add_child(_panel)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_names = Control.new()
	_names.clip_contents = true
	_names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_names)
	_up = _arrow_button(_SCROLL_UP, _SCROLL_DOWN, _SCROLL_HOVER, _scroll_by.bind(-1))
	_down = _arrow_button(_SCROLL_UP, _SCROLL_DOWN, _SCROLL_HOVER, _scroll_by.bind(1))
	_left = _arrow_button(_ARROW_UP, _ARROW_DOWN, _ARROW_HOVER, _turn_page.bind(-1))
	_right = _arrow_button(_ARROW_UP, _ARROW_DOWN, _ARROW_HOVER, _turn_page.bind(1))
	_close = _arrow_button(_CLOSE_UP, _CLOSE_DOWN, _CLOSE_HOVER, _hide_list)
	_new_friend = _arrow_button(_FRIEND_UP, _FRIEND_DOWN, _FRIEND_HOVER, _ask_new_friend)
	_secrets = _arrow_button(_CHAT_UP, _CHAT_DOWN, _CHAT_HOVER, _open_secrets)
	for node in [_up, _down, _left, _right, _close, _new_friend, _secrets, _title, _names]:
		node.visible = false


func _build_card() -> void:
	_card = TextureRect.new()
	_card.texture = _CARD
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.visible = false
	add_child(_card)
	_card_name = Label.new()
	_card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_name.visible = false
	add_child(_card_name)
	_add_card_row("Friends", _FRIEND_UP, _FRIEND_DOWN, _FRIEND_HOVER, Vector2(-0.103, 0.133), _ask_remove)
	_add_card_row("Go To", _GOTO_UP, _GOTO_DOWN, _GOTO_HOVER, Vector2(-0.103, 0.045), _ask_goto)
	_add_card_row("Whisper", _CHAT_UP, _CHAT_DOWN, _CHAT_HOVER, Vector2(-0.103, -0.0375), _ask_whisper)
	_add_card_row("True Friends", _TRUE_UP, _TRUE_DOWN, _TRUE_HOVER, Vector2(-0.103, -0.13), _open_secrets)
	_add_card_row("Ignore", _IGNORE_UP, _IGNORE_DOWN, _IGNORE_HOVER, Vector2(-0.1037, -0.21), _ask_ignore)
	var detail := _arrow_button(_DETAIL_UP, _DETAIL_DOWN, _DETAIL_HOVER, _ask_details)
	detail.visible = false
	_card_buttons.append(detail)
	var close := _arrow_button(_CLOSE_UP, _CLOSE_DOWN, _CLOSE_HOVER, _hide_card)
	close.visible = false
	_card_buttons.append(close)


func _build_dialog() -> void:
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0.35)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.visible = false
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_dialog = TextureRect.new()
	_dialog.texture = _DIALOG
	_dialog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dialog.stretch_mode = TextureRect.STRETCH_SCALE
	_dialog.modulate = _CREAM
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog.visible = false
	add_child(_dialog)
	_dialog_text = Label.new()
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_dialog_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog_text.visible = false
	add_child(_dialog_text)
	_dialog_edit = LineEdit.new()
	_dialog_edit.visible = false
	_dialog_edit.max_length = 16
	_dialog_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog_edit.placeholder_text = "True Friend Code"
	_dialog_edit.text_submitted.connect(func(text: String) -> void: _submit_secret(text))
	add_child(_dialog_edit)


func _arrow_button(up: Texture2D, down: Texture2D, hover: Texture2D, action: Callable) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = up
	button.texture_pressed = down
	button.texture_hover = hover
	button.texture_disabled = up
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.visible = false
	button.pressed.connect(action)
	ToonGui.button_sounds(button)
	add_child(button)
	return button


func _add_card_row(text: String, up: Texture2D, down: Texture2D, hover: Texture2D, at: Vector2, action: Callable) -> void:
	var button := _arrow_button(up, down, hover, action)
	button.set_meta("at", at)
	_card_buttons.append(button)
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	add_child(label)
	_card_labels.append(label)


func _open_list() -> void:
	_hide_card()
	_hide_dialog()
	_list_open = true
	_panel.visible = true
	_title.visible = true
	_names.visible = true
	for node in [_up, _down, _left, _right, _close, _new_friend, _secrets]:
		node.visible = true
	_button.visible = false
	_caption.visible = false
	_apply_page()
	_layout()


func _hide_list() -> void:
	_list_open = false
	_panel.visible = false
	_title.visible = false
	_names.visible = false
	for node in [_up, _down, _left, _right, _close, _new_friend, _secrets]:
		node.visible = false
	for child in _names.get_children():
		child.queue_free()


func _show_card(friend: Dictionary) -> void:
	_picked = friend
	_hide_list()
	_card.visible = true
	_card_name.visible = true
	_card_name.text = FriendsBook.shown_name(friend)
	for button in _card_buttons:
		button.visible = true
	for label in _card_labels:
		label.visible = true
	_layout()


func _hide_card() -> void:
	if _card == null:
		return
	_card.visible = false
	_card_name.visible = false
	for button in _card_buttons:
		button.visible = false
	for label in _card_labels:
		label.visible = false
	_picked = {}


func _host() -> Node:
	var layer := get_parent()
	if layer == null:
		return null
	return layer.get_parent()


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.y < 2.0:
		return
	var edge := view.x / view.y
	var button_x := maxf(1.192, edge - _CORNER_PAD - _BUTTON_W * 0.5)
	var panel_x := maxf(1.1, edge - _CORNER_PAD - _PANEL_W * 0.5)
	_panel_at = Vector2(panel_x, 0.54)
	_card_at = Vector2(panel_x, 0.525)
	ToonGui.place(_button, view, button_x, 0.875, _BUTTON_W, _BUTTON_H)
	var unit := view.y * 0.5
	_caption.position = _button.position + Vector2(0, _button.size.y * 0.72)
	_caption.size = Vector2(_button.size.x, unit * 0.08)
	ToonGui.style_label(_caption, Color.WHITE, int(unit * 0.07), Color.BLACK, maxi(int(unit * 0.012), 1))
	ToonGui.place(_panel, view, _panel_at.x, _panel_at.y, _PANEL_W, _PANEL_H)
	_place_on_panel(_title, view, 0.007, 0.2, 0.42, 0.12)
	ToonGui.style_label(_title, Color(0, 0.1, 0.4), int(unit * 0.04), Color(0, 0, 0, 0), 0)
	_place_on_panel(_names, view, -0.02, -0.05, 0.40, 0.34)
	_place_on_panel(_up, view, 0.0, 0.117, 0.2792, 0.0458)
	_place_on_panel(_down, view, 0.0, -0.316, 0.2792, 0.0458)
	_down.scale.y = -1
	_place_on_panel(_left, view, -0.15, -0.38, 0.0833, 0.0875)
	_left.scale.x = -1
	_place_on_panel(_right, view, 0.17, -0.38, 0.0833, 0.0875)
	_place_on_panel(_close, view, 0.01, -0.38, 0.09, 0.09)
	_place_on_panel(_new_friend, view, -0.14, 0.14, 0.10, 0.10)
	_place_on_panel(_secrets, view, 0.152, 0.14, 0.10, 0.10)
	ToonGui.place(_card, view, _card_at.x, _card_at.y, _CARD_W, _CARD_H)
	_place_card(_card_name, view, 0.0125, 0.40, 0.36, 0.08)
	ToonGui.style_label(_card_name, Color.BLACK, int(unit * 0.042), Color.WHITE, maxi(int(unit * 0.008), 1))
	var detail_index := _card_buttons.size() - 2
	var close_index := _card_buttons.size() - 1
	for index in _card_buttons.size():
		var button := _card_buttons[index]
		if index == detail_index:
			_place_card(button, view, -0.134, -0.395, 0.09, 0.08)
		elif index == close_index:
			_place_card(button, view, 0.158, -0.379, 0.09, 0.09)
		else:
			var at: Vector2 = button.get_meta("at")
			_place_card(button, view, at.x, at.y, 0.095, 0.085)
			var label := _card_labels[index]
			_place_card(label, view, at.x + 0.14, at.y, 0.2, 0.07)
			ToonGui.style_label(label, Color.WHITE, int(unit * 0.045), Color(0.1, 0.25, 0.55), maxi(int(unit * 0.006), 1))
	if _names.visible:
		_fill_names()
	if _shade.visible:
		_layout_dialog(view)


func _place_on_panel(control: Control, view: Vector2, x: float, z: float, width: float, height: float) -> void:
	ToonGui.place(control, view, _panel_at.x + x, _panel_at.y + z, width, height)


func _place_card(control: Control, view: Vector2, x: float, z: float, width: float, height: float) -> void:
	ToonGui.place(control, view, _card_at.x + x, _card_at.y + z, width, height)


func _apply_page() -> void:
	_title.text = _TITLES[_page]
	_scroll = 0
	_left.disabled = _page == 0
	_right.disabled = _page == _TITLES.size() - 1
	_left.modulate = Color(0.6, 0.6, 0.6, 0.6) if _left.disabled else Color.WHITE
	_right.modulate = Color(0.6, 0.6, 0.6, 0.6) if _right.disabled else Color.WHITE
	if _names.visible:
		_fill_names()


func _turn_page(step: int) -> void:
	var next := clampi(_page + step, 0, _TITLES.size() - 1)
	if next == _page:
		return
	_page = next
	_apply_page()


func _scroll_by(step: int) -> void:
	var rows := FriendsBook.page(_page)
	var limit := maxi(rows.size() - _VISIBLE, 0)
	_scroll = clampi(_scroll + step, 0, limit)
	_fill_names()


func _fill_names() -> void:
	for child in _names.get_children():
		_names.remove_child(child)
		child.free()
	var rows := FriendsBook.page(_page)
	var unit := get_viewport().get_visible_rect().size.y * 0.5
	var row_h := _names.size.y / float(_VISIBLE)
	var last := mini(_scroll + _VISIBLE, rows.size())
	for index in range(_scroll, last):
		var record: Dictionary = rows[index]
		var button := Button.new()
		button.text = FriendsBook.shown_name(record)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.flat = true
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var color := _OFFLINE
		if FriendsBook.is_online(record) and FriendsBook.is_true_friend(record):
			color = _TRUE
		elif FriendsBook.is_online(record):
			color = _SPEED
		button.add_theme_font_override("font", ToonGui.font())
		button.add_theme_font_size_override("font_size", int(unit * 0.04))
		button.add_theme_color_override("font_color", color)
		button.add_theme_color_override("font_hover_color", _HOVER)
		button.add_theme_color_override("font_pressed_color", _DOWN)
		var empty := StyleBoxEmpty.new()
		button.add_theme_stylebox_override("normal", empty)
		button.add_theme_stylebox_override("hover", empty)
		button.add_theme_stylebox_override("pressed", empty)
		button.add_theme_stylebox_override("focus", empty)
		button.position = Vector2(0, (index - _scroll) * row_h)
		button.size = Vector2(_names.size.x, row_h)
		button.pressed.connect(_show_card.bind(record))
		_names.add_child(button)


func picking() -> bool:
	return _picking


## FriendInviter. A cog is asked the same way as a toon, then almost always says no.
func offer_cog(cog_name: String) -> void:
	var friend_name := cog_name.strip_edges()
	if friend_name == "":
		return
	_picking = false
	_cog_token += 1
	var token := _cog_token
	var friend_id := FriendsBook.cog_id(friend_name)
	if FriendsBook.has_id(friend_id):
		_show_notice(
			"%s is already your toon friend." % friend_name,
			["Stop being friends", "Cancel"],
			[func() -> void:
				FriendsBook.remove_friend(friend_id)
				_hide_dialog(),
			func() -> void: _hide_dialog()]
		)
		return
	if FriendsBook.count() >= FriendsBook.MAX_FRIENDS:
		_show_notice(
			"You have too many toon friends on your list to add another one now. You will have to remove some toon friends if you want to make friends with %s." % friend_name,
			["Cancel"],
			[func() -> void: _hide_dialog()]
		)
		return
	_show_notice(
		"Asking %s to be your friend." % friend_name,
		["Cancel"],
		[func() -> void: _hide_dialog()]
	)
	await get_tree().create_timer(2.0).timeout
	if token != _cog_token or not is_inside_tree():
		return
	# The original cog always refuses. One try in a hundred is the exception.
	if randi_range(1, 100) == 1 and FriendsBook.add_cog(friend_name):
		_show_notice(
			"You are now friends with %s!" % friend_name,
			["OK"],
			[func() -> void: _hide_dialog()]
		)
	else:
		_show_notice(
			"%s said no, thank you." % friend_name,
			["OK"],
			[func() -> void: _hide_dialog()]
		)


func _ask_new_friend() -> void:
	_hide_dialog()
	_picking = true
	_hide_list()
	_hide_card()
	_show_notice(
		"Click on the toon you would like to make friends with.\n\n(You have %d friends)" % FriendsBook.count(),
		["Cancel"],
		[func() -> void:
			_picking = false
			_hide_dialog()]
	)


func _ask_remove() -> void:
	var friend_name := FriendsBook.shown_name(_picked)
	var friend_id := String(_picked.get("id", ""))
	_show_notice(
		"Are you sure you want to stop being friends with %s?" % friend_name,
		["Yes", "No"],
		[func() -> void:
			FriendsBook.remove_friend(friend_id)
			_hide_dialog()
			_hide_card()
			_open_list(),
		func() -> void: _hide_dialog()]
	)


func _ask_goto() -> void:
	_offline_notice("This only works if %s is online")


func _ask_whisper() -> void:
	var chat := _speed_chat()
	if chat == null or not chat.ready_to_type():
		_show_notice(
			"SpeedChat+ is where you whisper to other Toons.\nYou can try that later.",
			["OK"],
			[func() -> void: _hide_dialog()]
		)
		return
	var friend_name := FriendsBook.shown_name(_picked)
	var slot := int(_picked.get("slot", -1))
	_hide_card()
	chat.whisper_to(friend_name, slot)


func _speed_chat() -> SpeedChat:
	var hud := get_parent()
	if hud == null:
		return null
	return hud.get_node_or_null("SpeedChat") as SpeedChat


func _ask_ignore() -> void:
	_show_notice(
		"%s is your friend, you cannot ignore them while you are friends." % FriendsBook.shown_name(_picked),
		["Cancel"],
		[func() -> void: _hide_dialog()]
	)


func _ask_details() -> void:
	_show_notice(
		"%s\n\nDistrict: offline\nLocation: offline" % FriendsBook.shown_name(_picked),
		["OK"],
		[func() -> void: _hide_dialog()]
	)


func _offline_notice(pattern: String) -> void:
	if FriendsBook.is_online(_picked):
		_show_notice("Cannot make friends now.", ["OK"], [func() -> void: _hide_dialog()])
		return
	_show_notice(pattern % FriendsBook.shown_name(_picked), ["OK"], [func() -> void: _hide_dialog()])


func _open_secrets() -> void:
	_show_notice("", [], [])
	_dialog_text.text = "If you are playing Toontown with someone you know in the real world, you can become True Friends.  You can chat using the keyboard with your True Friends.  Other Toons won't understand what you're saying.\n\nYou do this by getting a True Friend Code.  Tell the True Friend Code to your friend, but not to anyone else.  When your friend types in your True Friend Code on his or her screen, you'll be True Friends in Toontown!"
	_dialog_edit.text = ""
	_dialog_edit.visible = true
	_dialog_edit.grab_focus()
	_add_dialog_button("Get a True Friend Code", _give_secret, 0)
	_add_dialog_button("Enter True Friend Code", func() -> void: _submit_secret(_dialog_edit.text), 1)
	_add_dialog_button("Cancel", _hide_dialog, 2)
	_layout()


func _give_secret() -> void:
	var code := FriendsBook.make_secret()
	_clear_dialog_buttons()
	_dialog_edit.visible = false
	_dialog_edit.release_focus()
	if code == "":
		_dialog_text.text = "Sorry, you can't have any more True Friend Codes today.  You've already had more than your fair share!\n\nTry again tomorrow."
	else:
		_dialog_text.text = "Here is your new True Friend Code.  Be sure to write it down!\n\nYou may give this True Friend Code to one person only.  Once someone types in your True Friend Code, it will not work for anyone else.\n\nThe True Friend Code will only work for the next two days.\n\nYour True Friend Code is:\n\n%s" % code
	_add_dialog_button("OK", _hide_dialog, 0)
	_layout()


func _submit_secret(typed: String) -> void:
	var reply := FriendsBook.redeem(typed)
	_clear_dialog_buttons()
	_dialog_edit.visible = false
	_dialog_edit.release_focus()
	_dialog_text.text = reply
	_add_dialog_button("OK", _hide_dialog, 0)
	_layout()


func _show_notice(text: String, captions: Array, actions: Array) -> void:
	_clear_dialog_buttons()
	z_index = 40
	_shade.visible = true
	# While choosing someone, the prompt stays up and nametags can still be clicked.
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE if _picking else Control.MOUSE_FILTER_STOP
	_dialog.visible = true
	_dialog_text.visible = true
	_dialog_text.text = text
	_dialog_edit.visible = false
	for index in captions.size():
		_add_dialog_button(String(captions[index]), actions[index] as Callable, index)
	_layout()


func _add_dialog_button(caption: String, action: Callable, index: int) -> void:
	var up := _QUIT_UP
	var down := _QUIT_DOWN
	var hover := _QUIT_HOVER
	if caption == "OK" or caption == "Yes":
		up = _OK_UP
		down = _OK_DOWN
		hover = _OK_HOVER
	elif caption == "No" or caption == "Cancel":
		up = _CLOSE_UP
		down = _CLOSE_DOWN
		hover = _CLOSE_HOVER
	var button := _arrow_button(up, down, hover, action)
	button.visible = true
	button.set_meta("slot", index)
	button.set_meta("count", 0)
	_dialog_buttons.append(button)
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	_dialog_captions.append(label)


func _clear_dialog_buttons() -> void:
	for button in _dialog_buttons:
		button.queue_free()
	for label in _dialog_captions:
		label.queue_free()
	_dialog_buttons.clear()
	_dialog_captions.clear()


func _hide_dialog() -> void:
	if _dialog != null and _dialog.visible:
		_cog_token += 1
	_picking = false
	z_index = 0
	_shade.visible = false
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog.visible = false
	_dialog_text.visible = false
	_dialog_edit.visible = false
	if _dialog_edit.has_focus():
		_dialog_edit.release_focus()
	_clear_dialog_buttons()


func _layout_dialog(view: Vector2) -> void:
	var wide := _dialog_edit.visible or _dialog_text.text.length() > 180
	var box := Vector2(1.6, 1.4) if wide else Vector2(1.25, 0.9)
	var center_z := 0.22 if wide else 0.3
	ToonGui.place(_dialog, view, 0.0, center_z, box.x, box.y)
	var unit := view.y * 0.5
	var count := _dialog_buttons.size()
	var inner_w := box.x * 0.76
	var button_w := 0.7
	if count > 1:
		button_w = minf(0.5, inner_w / float(count) - 0.05)
	var button_h := 0.13
	var span := button_w + 0.06
	var buttons_z := center_z - box.y * 0.34
	for index in count:
		var button := _dialog_buttons[index]
		var x := (float(index) - float(count - 1) * 0.5) * span
		ToonGui.place(button, view, x, buttons_z, button_w, button_h)
		var caption := _dialog_captions[index]
		caption.position = button.position
		caption.size = button.size
		ToonGui.style_label(caption, Color.WHITE, int(unit * 0.03), Color(0.15, 0.35, 0.7), maxi(int(unit * 0.006), 1))
	var content_bottom := _dialog.position.y + _dialog.size.y * 0.86
	if count > 0:
		content_bottom = _dialog_buttons[0].position.y - unit * 0.03
	if _dialog_edit.visible:
		var edit_z := buttons_z + button_h * 0.5 + 0.1
		ToonGui.place(_dialog_edit, view, 0.0, edit_z, inner_w, 0.08)
		_dialog_edit.add_theme_font_override("font", ToonGui.font())
		_dialog_edit.add_theme_font_size_override("font_size", int(unit * 0.04))
		content_bottom = _dialog_edit.position.y - unit * 0.02
	# dialog_box.png keeps a green frame around the cream. Text starts inside that frame.
	var inset_x := _dialog.size.x * 0.12
	var inset_top := _dialog.size.y * 0.13
	_dialog_text.position = _dialog.position + Vector2(inset_x, inset_top)
	_dialog_text.size = Vector2(_dialog.size.x - inset_x * 2.0, maxf(unit * 0.16, content_bottom - _dialog_text.position.y))
	_dialog_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP if wide else VERTICAL_ALIGNMENT_CENTER
	ToonGui.style_label(_dialog_text, Color.BLACK, int(unit * 0.042), Color(0, 0, 0, 0), 0)
