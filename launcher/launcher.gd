extends Control

## Playtest window. Play asks GitHub for the latest release tag. A newer tag
## downloads that release's Toontown.pck and Toontown-clips.pck into game/
## beside Launcher.exe and replaces the previous packs. Toontown.exe is left
## as it is. The address field is how someone joins a friend who clicked Host.

const _RELEASES := "https://api.github.com/repos/CakeGamingOfficial/Toontown-Reimagined/releases/latest"
const _PACK_NAME := "Toontown.pck"
const _CLIPS_NAME := "Toontown-clips.pck"
const _EXE_NAME := "Toontown.exe"
const _CONFIG := "user://launcher.json"
var _release_headers := PackedStringArray([
	"User-Agent: ToontownLauncher",
	"Accept: application/vnd.github+json",
])
var _pack_headers := PackedStringArray([
	"User-Agent: ToontownLauncher",
	"Accept: application/octet-stream",
])

enum _Step { IDLE, RELEASE, PACK }

const _font := preload("res://assets/ImpressBT.ttf")
const _logo := preload("res://assets/logo.png")
const _sky := preload("res://assets/sky.png")
const _scroll := preload("res://assets/scroll.png")
const _button_up := preload("res://assets/button_up.png")
const _button_down := preload("res://assets/button_down.png")
const _button_hover := preload("res://assets/button_hover.png")

const _INK := Color(0.33, 0.2, 0.08)
const _INK_SOFT := Color(0.48, 0.32, 0.16)

var _config: Dictionary = {}
var _mode := ""
var _busy := false
var _play_local := false
var _closing := false
var _step := _Step.IDLE
var _latest_tag := ""
var _fetch_name := ""
var _queue: Array[Dictionary] = []
var _shown_percent := -1
var _http: HTTPRequest

var _menu: Control
var _host_card: Control
var _status: Label
var _address_edit: LineEdit
var _port_edit: LineEdit
var _host_body: Label
var _buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_config()
	_http = HTTPRequest.new()
	_http.name = "UpdateRequest"
	_http.use_threads = true
	_http.accept_gzip = true
	_http.body_size_limit = -1
	_http.max_redirects = 8
	_http.timeout = 30.0
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)
	_delete_partial()
	_build()
	_show_installed()


func _exit_tree() -> void:
	_closing = true
	if _http != null:
		_http.cancel_request()
	_delete_partial()


func _process(_delta: float) -> void:
	if _step != _Step.PACK or _http == null or _status == null:
		return
	var got := _http.get_downloaded_bytes()
	var total := _http.get_body_size()
	if total > 0:
		var percent := int((float(got) * 100.0) / float(total))
		if percent == _shown_percent:
			return
		_shown_percent = percent
		_status.text = "Downloading %s... %d%%." % [_fetch_name, percent]
		return
	if got <= 0:
		return
	_status.text = "Downloading %s... %s." % [_fetch_name, _size_phrase(got)]


func _play(mode: String) -> void:
	if _busy:
		return
	if not _fields_ok(mode):
		return
	_mode = mode
	_save_fields()
	if _play_local:
		_play_local = false
		_continue_after_sync()
		return
	if not FileAccess.file_exists(_game_exe()):
		_status.text = "game/Toontown.exe was not found. Play does not download or replace that file."
		return
	_busy = true
	_set_buttons_disabled(true)
	_check_release()


func _confirm_host() -> void:
	if _busy:
		return
	_start_game()


func _back_from_host() -> void:
	if _busy:
		return
	_mode = ""
	_play_local = false
	_host_card.visible = false
	_menu.visible = true
	_show_installed()


func _fields_ok(mode: String) -> bool:
	if _port() < 1 or _port() > 65535:
		_status.text = "Type a port from 1 to 65535."
		return false
	if mode == "join" and _address() == "":
		_status.text = "Type the host computer's address."
		return false
	return true


func _continue_after_sync() -> void:
	if _mode == "host":
		_show_host_card()
		_busy = false
		_set_buttons_disabled(false)
		return
	_start_game()


func _check_release() -> void:
	_step = _Step.RELEASE
	_shown_percent = -1
	_http.download_file = ""
	_http.accept_gzip = true
	_http.timeout = 30.0
	_status.text = "Checking GitHub for a newer release..."
	var err := _http.request(_RELEASES, _release_headers)
	if err != OK:
		_step = _Step.IDLE
		_fail("Could not reach GitHub.")


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _closing:
		return
	var step := _step
	_step = _Step.IDLE
	if step == _Step.RELEASE:
		_apply_release(result, response_code, body)
	elif step == _Step.PACK:
		_apply_pack(result, response_code)


func _apply_release(result: int, response_code: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail(_http_problem(result, response_code))
		return
	if response_code == 404:
		_fail("GitHub has no release yet.")
		return
	if response_code != 200:
		_fail("GitHub returned an error (%d)." % response_code)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		_fail("GitHub did not return a release.")
		return
	var tag := String(parsed.get("tag_name", "")).strip_edges()
	if tag == "":
		_fail("GitHub did not return a release.")
		return
	var pack_url := _asset_url(parsed.get("assets", []), _PACK_NAME)
	var clips_url := _asset_url(parsed.get("assets", []), _CLIPS_NAME)
	if pack_url == "" or clips_url == "":
		_fail("The latest release (%s) needs Toontown.pck and Toontown-clips.pck." % tag)
		return
	var installed := String(_config.get("release", "")).strip_edges()
	var same := installed == tag
	_queue.clear()
	if not same or not FileAccess.file_exists(_pack_path()):
		_queue.append({"name": _PACK_NAME, "url": pack_url})
	if not same or not FileAccess.file_exists(_clips_path()):
		_queue.append({"name": _CLIPS_NAME, "url": clips_url})
	if _queue.is_empty():
		_status.text = "Up to date (%s)." % tag
		_continue_after_sync()
		return
	_latest_tag = tag
	_start_next_download()


func _asset_url(assets: Variant, file_name: String) -> String:
	if not (assets is Array):
		return ""
	for asset in assets:
		if not (asset is Dictionary):
			continue
		if String(asset.get("name", "")) != file_name:
			continue
		return String(asset.get("browser_download_url", "")).strip_edges()
	return ""


func _start_next_download() -> void:
	if _queue.is_empty():
		_config["release"] = _latest_tag
		_save_config()
		_status.text = "Updated to %s." % _latest_tag
		_continue_after_sync()
		return
	var job: Dictionary = _queue.pop_front()
	_fetch_name = String(job["name"])
	var url := String(job["url"])
	_delete_partial()
	_shown_percent = -1
	_http.accept_gzip = false
	_http.timeout = 0.0
	_http.download_file = _partial_path()
	_step = _Step.PACK
	_status.text = "Downloading %s..." % _fetch_name
	var err := _http.request(url, _pack_headers)
	if err != OK:
		_step = _Step.IDLE
		_http.download_file = ""
		_delete_partial()
		_fail("Could not start the %s download." % _fetch_name)


func _apply_pack(result: int, response_code: int) -> void:
	_http.download_file = ""
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_delete_partial()
		if result != HTTPRequest.RESULT_SUCCESS:
			_fail(_http_problem(result, response_code))
		else:
			_fail("GitHub returned an error (%d) for %s." % [response_code, _fetch_name])
		return
	if not _replace_pack():
		_delete_partial()
		_fail("The new %s could not replace the old one." % _fetch_name)
		return
	_start_next_download()


## Downloads land in a .partial file, then the old pack is moved aside.
## Toontown.exe is never opened here.
func _replace_pack() -> bool:
	var dir := DirAccess.open(_install_dir())
	if dir == null or _fetch_name == "":
		return false
	var partial := _fetch_name + ".partial"
	if not dir.file_exists(partial):
		return false
	if not dir.file_exists(_fetch_name):
		return dir.rename(partial, _fetch_name) == OK
	var backup := _fetch_name + ".previous"
	if dir.file_exists(backup):
		dir.remove(backup)
	if dir.rename(_fetch_name, backup) != OK:
		return false
	if dir.rename(partial, _fetch_name) != OK:
		dir.rename(backup, _fetch_name)
		return false
	dir.remove(backup)
	return true


func _fail(message: String) -> void:
	_http.download_file = ""
	if _can_play_local():
		_play_local = true
		_stop(message + " Click again to play this copy.")
		return
	_stop(message)


func _stop(message: String) -> void:
	_busy = false
	_set_buttons_disabled(false)
	_status.text = message


func _http_problem(result: int, response_code: int) -> String:
	if result == HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN or result == HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
		return "Could not write %s in the game folder." % _fetch_name
	if result == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
		return "%s is larger than this launcher can download." % _fetch_name
	if result == HTTPRequest.RESULT_CANT_RESOLVE or result == HTTPRequest.RESULT_CANT_CONNECT or result == HTTPRequest.RESULT_CONNECTION_ERROR or result == HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR or result == HTTPRequest.RESULT_NO_RESPONSE or result == HTTPRequest.RESULT_TIMEOUT:
		return "Could not reach GitHub."
	if response_code > 0 and response_code != 200:
		return "GitHub returned an error (%d)." % response_code
	return "The download did not finish."


func _start_game() -> void:
	_busy = true
	_set_buttons_disabled(true)
	_launch_game()


func _launch_game() -> void:
	var exe := _game_exe()
	if not FileAccess.file_exists(exe):
		_stop("game/Toontown.exe was not found. Play does not download or replace that file.")
		return
	if not FileAccess.file_exists(_pack_path()):
		_stop("game/Toontown.pck was not found.")
		return
	if not FileAccess.file_exists(_clips_path()):
		_stop("game/Toontown-clips.pck was not found.")
		return
	var args := PackedStringArray(["--"])
	if _mode == "solo":
		args.append("--solo")
	elif _mode == "host":
		args.append("--host")
		args.append(str(_port()))
	else:
		args.append("--join")
		args.append(_address())
		args.append(str(_port()))
	# A Godot window started by this one never receives mouse clicks.
	# The helper waits until this process is gone, then opens Toontown.exe.
	var folder := _install_dir().replace("/", "\\")
	var exe_path := exe.replace("/", "\\")
	var bat_path := _write_play_bat(folder, exe_path, args)
	if bat_path == "":
		_stop("The game did not start.")
		return
	var output: Array = []
	OS.execute("cmd.exe", PackedStringArray([
		"/C", "start", "Toontown Game", "/MIN", bat_path,
	]), output, true)
	get_tree().quit()


func _write_play_bat(folder: String, exe_path: String, args: PackedStringArray) -> String:
	var temp := OS.get_environment("TEMP").replace("/", "\\").trim_suffix("\\")
	if temp == "":
		temp = folder
	var path := temp + "\\toontown_play.bat"
	var arg_line := ""
	for arg in args:
		arg_line += " " + _cmd_quote(arg)
	var pid := OS.get_process_id()
	var lines := PackedStringArray([
		"@echo off",
		"set /a N=0",
		":wait",
		"set /a N+=1",
		"if %N% GEQ 20 goto launch",
		"tasklist /FI \"PID eq %d\" 2>nul | find \"%d\" >nul" % [pid, pid],
		"if errorlevel 1 goto launch",
		"ping 127.0.0.1 -n 2 >nul",
		"goto wait",
		":launch",
		"cd /d %s" % _cmd_quote(folder),
		"start \"\" %s%s" % [_cmd_quote(exe_path), arg_line],
	])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_buffer(("\r\n".join(lines) + "\r\n").to_utf8_buffer())
	file.close()
	return path


func _cmd_quote(text: String) -> String:
	return "\"" + text.replace("\"", "") + "\""


func _show_host_card() -> void:
	var port := _port()
	var lines := _lan_lines()
	var listed := "No local address was found. On this computer, use 127.0.0.1."
	if not lines.is_empty():
		listed = "\n".join(lines)
	_host_body.text = "The game will open this computer on UDP port %d.\n\nOther players type one of these addresses, and the same port.\n\n%s\n\nOn this same computer, the address is 127.0.0.1." % [port, listed]
	_menu.visible = false
	_host_card.visible = true


func _show_installed() -> void:
	if not FileAccess.file_exists(_game_exe()):
		_status.text = "game/Toontown.exe was not found. Play checks GitHub, then downloads the two pack files. That exe is left as it is."
		return
	var tag := String(_config.get("release", "")).strip_edges()
	if tag == "":
		_status.text = "Play checks GitHub for the latest release, then downloads Toontown.pck and Toontown-clips.pck when a newer one is available."
		return
	_status.text = "This copy is %s. Play checks GitHub before the game starts." % tag


func _size_phrase(bytes: int) -> String:
	var mb := float(bytes) / 1048576.0
	if mb < 10.0:
		return "%.1f MB" % mb
	return "%d MB" % int(round(mb))


func _install_dir() -> String:
	# Exported Launcher.exe looks beside itself. In the editor, the running
	# executable is Godot, so keep using the project folder's parent.
	var root := OS.get_executable_path().get_base_dir()
	if OS.has_feature("editor"):
		root = _launcher_dir().get_base_dir()
	return root.path_join("game")


func _game_exe() -> String:
	return _install_dir().path_join(_EXE_NAME)


func _pack_path() -> String:
	return _install_dir().path_join(_PACK_NAME)


func _clips_path() -> String:
	return _install_dir().path_join(_CLIPS_NAME)


func _partial_path() -> String:
	return _install_dir().path_join(_fetch_name + ".partial")


func _delete_partial() -> void:
	for file_name in [_PACK_NAME, _CLIPS_NAME]:
		var path := _install_dir().path_join(file_name + ".partial")
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _can_play_local() -> bool:
	return FileAccess.file_exists(_game_exe()) and FileAccess.file_exists(_pack_path()) and FileAccess.file_exists(_clips_path())


func _launcher_dir() -> String:
	return ProjectSettings.globalize_path("res://").simplify_path()


func _lan_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for raw in IP.get_local_addresses():
		var address := String(raw)
		if address.contains(":") or address == "127.0.0.1" or address.begins_with("169.254."):
			continue
		if lines.has(address):
			continue
		lines.append(address)
	return lines


func _address() -> String:
	if _address_edit == null:
		return ""
	return _address_edit.text.strip_edges()


func _port() -> int:
	if _port_edit == null or not _port_edit.text.is_valid_int():
		return 0
	return int(_port_edit.text)


func _load_config() -> void:
	_config = {"address": "", "port": 4343}
	if not FileAccess.file_exists(_CONFIG):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_CONFIG))
	if parsed is Dictionary:
		_config = parsed


func _save_fields() -> void:
	_config["address"] = _address()
	_config["port"] = _port()
	_save_config()


func _save_config() -> void:
	var file := FileAccess.open(_CONFIG, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_config))


func _set_buttons_disabled(disabled: bool) -> void:
	for button in _buttons:
		if is_instance_valid(button):
			button.disabled = disabled


func _build() -> void:
	if _sky != null:
		var sky := TextureRect.new()
		sky.texture = _sky
		sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sky.stretch_mode = TextureRect.STRETCH_SCALE
		sky.set_anchors_preset(Control.PRESET_FULL_RECT)
		sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sky)
	else:
		var sky_flat := ColorRect.new()
		sky_flat.color = Color(0.08, 0.35, 0.83)
		sky_flat.set_anchors_preset(Control.PRESET_FULL_RECT)
		sky_flat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sky_flat)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(560, 0)
	column.add_theme_constant_override("separation", 0)
	center.add_child(column)
	var logo := TextureRect.new()
	logo.texture = _logo_texture()
	logo.custom_minimum_size = Vector2(520, 230)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(logo)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _scroll_box())
	column.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size = Vector2(0, 64)
	_paint(_status, 18, _INK)
	stack.add_child(_status)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 8)
	stack.add_child(_menu)
	_address_edit = _field("192.168.1.20")
	_address_edit.text = String(_config.get("address", ""))
	_menu.add_child(_labeled("Address", _address_edit))
	_port_edit = _field("4343")
	_port_edit.text = str(int(_config.get("port", 4343)))
	_menu.add_child(_labeled("Port", _port_edit))
	_menu.add_child(_button("Single Player", _play.bind("solo")))
	_menu.add_child(_button("Host", _play.bind("host")))
	_menu.add_child(_button("Join", _play.bind("join")))
	_menu.add_child(_button("Quit", func() -> void: get_tree().quit()))
	_host_card = VBoxContainer.new()
	_host_card.add_theme_constant_override("separation", 8)
	_host_card.visible = false
	stack.add_child(_host_card)
	_host_body = Label.new()
	_host_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_host_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_host_body.custom_minimum_size = Vector2(0, 180)
	_paint(_host_body, 18, _INK)
	_host_card.add_child(_host_body)
	_host_card.add_child(_button("Play", _confirm_host))
	_host_card.add_child(_button("Back", _back_from_host))


func _logo_texture() -> Texture2D:
	if _logo == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = _logo
	atlas.region = Rect2(28, 86, 978, 782)
	return atlas


func _labeled(caption: String, field: Control) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.text = caption
	_paint(label, 16, _INK)
	row.add_child(label)
	row.add_child(field)
	return row


func _field(placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(0, 38)
	if _font != null:
		edit.add_theme_font_override("font", _font)
	edit.add_theme_font_size_override("font_size", 18)
	edit.add_theme_color_override("font_color", _INK)
	edit.add_theme_color_override("font_placeholder_color", _INK_SOFT)
	edit.add_theme_color_override("caret_color", _INK)
	var box := _field_box(Color(0.55, 0.32, 0.08))
	var focus := _field_box(Color(0.85, 0.45, 0.08))
	edit.add_theme_stylebox_override("normal", box)
	edit.add_theme_stylebox_override("focus", focus)
	edit.add_theme_stylebox_override("read_only", box)
	return edit


func _field_box(border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1.0, 0.97, 0.88)
	box.border_color = border
	box.set_border_width_all(3)
	box.set_corner_radius_all(8)
	box.content_margin_left = 10
	box.content_margin_right = 10
	return box


func _button(caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 46)
	button.focus_mode = Control.FOCUS_NONE
	if _font != null:
		button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.16, 0.1, 0.02))
	button.add_theme_color_override("font_hover_color", Color(0.05, 0.12, 0.28))
	button.add_theme_color_override("font_pressed_color", Color(0.16, 0.1, 0.02))
	button.add_theme_color_override("font_disabled_color", Color(0.28, 0.24, 0.16, 0.65))
	var normal := _pill(_button_up)
	var hover := _pill(_button_hover)
	var pressed := _pill(_button_down)
	var disabled := _pill(_button_up, Color(0.72, 0.72, 0.72))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.pressed.connect(action)
	_buttons.append(button)
	return button


func _scroll_box() -> StyleBox:
	if _scroll == null:
		var plain := StyleBoxFlat.new()
		plain.bg_color = Color(0.93, 0.9, 0.8)
		plain.set_corner_radius_all(16)
		plain.set_content_margin_all(24)
		return plain
	var box := StyleBoxTexture.new()
	box.texture = _scroll
	box.texture_margin_left = 32
	box.texture_margin_right = 32
	box.texture_margin_top = 46
	box.texture_margin_bottom = 52
	# Content margins replace the texture margins, so they have to include
	# the rolled edges or the words sit on the curl.
	box.content_margin_left = 48
	box.content_margin_right = 48
	box.content_margin_top = 58
	box.content_margin_bottom = 64
	return box


func _pill(texture: Texture2D, tint: Color = Color.WHITE) -> StyleBox:
	if texture == null:
		var plain := StyleBoxFlat.new()
		plain.bg_color = Color(0.95, 0.9, 0.15) * Color(tint.r, tint.g, tint.b, 1.0)
		plain.set_corner_radius_all(12)
		plain.content_margin_top = 6
		plain.content_margin_bottom = 6
		return plain
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.texture_margin_left = 18
	box.texture_margin_right = 18
	box.texture_margin_top = 10
	box.texture_margin_bottom = 10
	box.modulate_color = tint
	return box


func _paint(label: Label, size: int, color: Color) -> void:
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
