extends Control

## The first choice on Pick a Toon. Single player stays on the local district.
## Host opens UDP so another computer can join. Connect types that computer's
## address. The last address is remembered in user://server_door.json.

const _REMEMBER := "user://server_door.json"
const _DIALOG := preload("res://assets/gui/tutorial/dialog/dialog_box.png")
const _PILL_UP := preload("res://assets/toons/gui/QuitBtn_UP.png")
const _PILL_DOWN := preload("res://assets/toons/gui/QuitBtn_DN.png")
const _PILL_HOVER := preload("res://assets/toons/gui/QuitBtn_RLVR.png")
const _YELLOW := Color(1.0, 0.9, 0.1, 1.0)

var _panel: TextureRect
var _title: Label
var _body: Label
var _widgets: Array[Control] = []
var _address: LineEdit
var _port_edit: LineEdit
var _waiting := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 80
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.08, 0.16, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_panel = TextureRect.new()
	_panel.texture = _DIALOG
	_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_panel.stretch_mode = TextureRect.STRETCH_SCALE
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	multiplayer.connected_to_server.connect(_joined)
	multiplayer.connection_failed.connect(_failed)
	resized.connect(_layout)
	_show_menu()


func _show_menu() -> void:
	_waiting = false
	_title.text = "WELCOME"
	_body.text = "Play on this computer, host a district other computers can join, or connect to a server that is already running."
	_clear_widgets()
	_keep(_pill("Single Player", _play_alone))
	_keep(_pill("Host a Server", _ask_host))
	_keep(_pill("Connect to a Server", _ask_connect))
	_keep(_pill("Quit", func() -> void: get_tree().quit()))
	_layout()


func _ask_host() -> void:
	_title.text = "HOST A SERVER"
	_body.text = "Other players type this computer's address. The game listens on UDP, so the port has to be open on this computer."
	_clear_widgets()
	_port_edit = _field(str(ToonNet.listen_port()))
	_port_edit.text = str(ToonNet.listen_port())
	_keep(_port_edit)
	_keep(_pill("Start Hosting", _start_host))
	_keep(_pill("Back", _show_menu))
	_layout()


func _start_host() -> void:
	var port := _read_port()
	if port <= 0:
		_body.text = "Type a port from 1 to 65535."
		return
	var result := ToonNet.host_game(port)
	if not result.begins_with("Hosting") and not result.begins_with("Already hosting"):
		_body.text = result
		return
	_show_hosting(port)


func _show_hosting(port: int) -> void:
	_title.text = "SERVER OPEN"
	_body.text = "Other players choose Connect and type one of these addresses, with port %d.\n\n%s\n\nOn this same computer, the address is 127.0.0.1.\nFrom the internet, forward UDP port %d to this computer." % [port, _addresses(), port]
	_clear_widgets()
	_keep(_pill("Play", _enter))
	_keep(_pill("Stop Hosting", _stop_host))
	_layout()


func _ask_connect() -> void:
	var remembered := _remembered()
	_title.text = "CONNECT"
	_body.text = "Type the address of the computer that is hosting. On the same machine that is 127.0.0.1."
	_clear_widgets()
	_address = _field("192.168.1.20")
	_address.text = String(remembered.get("address", ""))
	_port_edit = _field(str(ToonNet.listen_port()))
	_port_edit.text = str(int(remembered.get("port", ToonNet.listen_port())))
	_address.text_submitted.connect(func(_text: String) -> void: _start_join())
	_keep(_address)
	_keep(_port_edit)
	_keep(_pill("Join", _start_join))
	_keep(_pill("Back", _back_from_join))
	_layout()


func _start_join() -> void:
	if _waiting or _address == null:
		return
	var address := _address.text.strip_edges()
	var port := _read_port()
	if address == "":
		_body.text = "Type the host computer's address."
		return
	if port <= 0:
		_body.text = "Type a port from 1 to 65535."
		return
	_save(address, port)
	var result := ToonNet.join_server(address, port)
	if not result.begins_with("Joining"):
		_body.text = result
		return
	_waiting = true
	_body.text = "Joining %s:%d..." % [address, port]


func _back_from_join() -> void:
	if _waiting:
		_waiting = false
		ToonNet.disconnect_net()
	_show_menu()


func _stop_host() -> void:
	ToonNet.disconnect_net()
	_show_menu()


func _play_alone() -> void:
	_enter()


func _enter() -> void:
	_waiting = false
	queue_free()


func _joined() -> void:
	if not _waiting:
		return
	_enter()


func _failed() -> void:
	if not _waiting:
		return
	_waiting = false
	_body.text = "Could not reach that server. Check the address, the UDP port, and that the host is still running."


func _read_port() -> int:
	if _port_edit == null:
		return ToonNet.listen_port()
	if not _port_edit.text.is_valid_int():
		return 0
	var port := int(_port_edit.text)
	if port < 1 or port > 65535:
		return 0
	return port


func _addresses() -> String:
	var lines: PackedStringArray = []
	for raw in IP.get_local_addresses():
		var address := String(raw)
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254.") or address == "0.0.0.0":
			continue
		if lines.has(address):
			continue
		lines.append(address)
	if lines.is_empty():
		return "No local address was found. Try 127.0.0.1 on this computer."
	return "\n".join(lines)


func _pill(caption: String, action: Callable) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _PILL_UP
	button.texture_pressed = _PILL_DOWN
	button.texture_hover = _PILL_HOVER
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.pressed.connect(action)
	ToonGui.button_sounds(button)
	var label := Label.new()
	label.text = caption
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	add_child(button)
	return button


func _field(placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.caret_blink = true
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.96)
	box.border_color = Color(0.2, 0.35, 0.7)
	box.set_border_width_all(3)
	box.set_corner_radius_all(10)
	box.content_margin_left = 10
	box.content_margin_right = 10
	edit.add_theme_stylebox_override("normal", box)
	edit.add_theme_stylebox_override("focus", box)
	var face := ToonGui.font()
	if face != null:
		edit.add_theme_font_override("font", face)
	add_child(edit)
	return edit


func _keep(control: Control) -> void:
	_widgets.append(control)


func _clear_widgets() -> void:
	for widget in _widgets:
		if is_instance_valid(widget):
			widget.queue_free()
	_widgets.clear()
	_address = null
	_port_edit = null


func _layout() -> void:
	var view := get_viewport_rect().size
	if view.y < 2.0 or _panel == null:
		return
	ToonGui.place(_panel, view, 0.0, 0.02, 1.85, 1.62)
	var inset := _panel.size.x * 0.08
	_title.position = _panel.position + Vector2(inset, _panel.size.y * 0.08)
	_title.size = Vector2(_panel.size.x - inset * 2.0, _panel.size.y * 0.1)
	ToonGui.style_sign(_title, Color(0.12, 0.22, 0.62), int(_panel.size.y * 0.065), Color(0, 0, 0, 0), 0)
	var shown: Array[Control] = []
	for widget in _widgets:
		if is_instance_valid(widget):
			shown.append(widget)
	var button_h := _panel.size.y * 0.09
	var gap := _panel.size.y * 0.018
	var stack := 0.0
	if not shown.is_empty():
		stack = shown.size() * button_h + (shown.size() - 1) * gap
	var y := _panel.position.y + _panel.size.y - _panel.size.y * 0.08 - stack
	_body.position = _title.position + Vector2(0.0, _title.size.y)
	_body.size = Vector2(_title.size.x, maxf(24.0, y - _body.position.y - gap))
	ToonGui.style_label(_body, Color(0.08, 0.1, 0.16), int(_panel.size.y * 0.038), Color(0, 0, 0, 0), 0)
	var button_w := _panel.size.x * 0.72
	for widget in shown:
		var height := button_h
		if widget is LineEdit:
			height = button_h * 0.82
		widget.position = Vector2(_panel.position.x + (_panel.size.x - button_w) * 0.5, y)
		widget.size = Vector2(button_w, height)
		y += button_h + gap
		if widget is TextureButton and widget.get_child_count() > 0:
			var caption := widget.get_child(0) as Label
			if caption != null:
				caption.set_anchors_preset(Control.PRESET_FULL_RECT)
				caption.offset_top = height * 0.08
				ToonGui.style_sign(caption, _YELLOW, int(height * 0.42), Color(0, 0, 0), maxi(int(height * 0.04), 1))
		elif widget is LineEdit:
			widget.add_theme_font_size_override("font_size", int(height * 0.42))


func _remembered() -> Dictionary:
	if not FileAccess.file_exists(_REMEMBER):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_REMEMBER))
	if parsed is Dictionary:
		return parsed
	return {}


func _save(address: String, port: int) -> void:
	var file := FileAccess.open(_REMEMBER, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"address": address, "port": port}))
