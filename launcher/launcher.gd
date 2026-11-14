extends Control

## Playtest window for multiplayer-test. Single Player, Host, and Join check
## that branch on GitHub, pull when this copy can fast-forward, then start
## the game. A dirty tree is left alone. The address field is how someone
## joins a friend who clicked Host.

const _BRANCH := "multiplayer-test"
const _CONFIG := "user://launcher.json"
const _FALLBACK_GODOT := "C:/Users/fukuy/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"

var _config: Dictionary = {}
var _repo := ""
var _mode := ""
var _busy := false
var _play_local := false
var _worker: Thread
var _lock := Mutex.new()
var _phase_text := ""
var _sync_done := false
var _outcome: Dictionary = {}

var _menu: Control
var _host_card: Control
var _status: Label
var _godot_label: Label
var _address_edit: LineEdit
var _port_edit: LineEdit
var _host_body: Label
var _buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_config()
	_repo = _find_repo()
	_build()
	_show_local_rev()


func _exit_tree() -> void:
	if _worker != null:
		_worker.wait_to_finish()
		_worker = null


func _process(_delta: float) -> void:
	if _worker == null:
		return
	var done := false
	var phase := ""
	_lock.lock()
	done = _sync_done
	phase = _phase_text
	_lock.unlock()
	if phase != "":
		_status.text = phase
	if not done:
		return
	_worker.wait_to_finish()
	_worker = null
	var outcome: Dictionary = {}
	_lock.lock()
	outcome = _outcome.duplicate()
	_sync_done = false
	_lock.unlock()
	_finish_sync(outcome)


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
	_busy = true
	_set_buttons_disabled(true)
	_set_phase("Checking %s..." % _BRANCH)
	_worker = Thread.new()
	_worker.start(_sync_thread)


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
	_status.text = "Play checks the %s branch on GitHub before the game starts." % _BRANCH


func _fields_ok(mode: String) -> bool:
	if _repo == "":
		_status.text = "The launcher could not find the game repository."
		return false
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


func _finish_sync(outcome: Dictionary) -> void:
	_busy = false
	_set_buttons_disabled(false)
	if bool(outcome.get("local", false)):
		_play_local = true
		_status.text = String(outcome.get("note", ""))
		return
	if not bool(outcome.get("ok", false)):
		_status.text = String(outcome.get("error", "The update did not finish."))
		return
	var note := String(outcome.get("note", ""))
	if note != "":
		_status.text = note
	_continue_after_sync()


func _start_game() -> void:
	_busy = true
	_set_buttons_disabled(true)
	var exe := _godot_exe()
	if exe == "":
		_busy = false
		_set_buttons_disabled(false)
		_status.text = "Locate the Godot 4.7 exe. It can also be copied to launcher/Godot.exe."
		_locate_godot()
		return
	var project := _repo.path_join("Godot Project/project-toontown")
	if not FileAccess.file_exists(project.path_join("project.godot")):
		_busy = false
		_set_buttons_disabled(false)
		_status.text = "The game project is not in this repository."
		return
	var args := PackedStringArray(["--path", project, "--"])
	if _mode == "solo":
		args.append("--solo")
	elif _mode == "host":
		args.append("--host")
		args.append(str(_port()))
	else:
		args.append("--join")
		args.append(_address())
		args.append(str(_port()))
	var pid := OS.create_process(exe, args)
	if pid <= 0:
		_busy = false
		_set_buttons_disabled(false)
		_status.text = "The game did not start."
		return
	get_tree().quit()


func _show_host_card() -> void:
	var port := _port()
	var lines := _lan_lines()
	var listed := "No local address was found. On this computer, use 127.0.0.1."
	if not lines.is_empty():
		listed = "\n".join(lines)
	_host_body.text = "The game will open this computer on UDP port %d.\n\nOther players type one of these addresses, and the same port.\n\n%s\n\nOn this same computer, the address is 127.0.0.1." % [port, listed]
	_menu.visible = false
	_host_card.visible = true


func _sync_thread() -> void:
	var outcome := _sync()
	_lock.lock()
	_outcome = outcome
	_sync_done = true
	_lock.unlock()


func _sync() -> Dictionary:
	_set_phase("Checking %s..." % _BRANCH)
	var branch := _git(["rev-parse", "--abbrev-ref", "HEAD"])
	if int(branch.get("code", -1)) < 0:
		return {"ok": false, "error": "Git is not on this computer's PATH. Install Git for Windows and open the launcher again."}
	if int(branch.get("code", 1)) != 0:
		return {"ok": false, "error": _git_error(branch, "Git could not read this repository.")}
	var name := String(branch.get("text", "")).strip_edges()
	var dirty := String(_git(["status", "--porcelain"]).get("text", "")).strip_edges() != ""
	_set_phase("Checking %s on GitHub..." % _BRANCH)
	var fetched := _git(["fetch", "origin", _BRANCH])
	if int(fetched.get("code", 1)) != 0:
		return {
			"ok": false,
			"local": true,
			"note": "Could not reach GitHub. Click again to play this copy.",
		}
	if name != _BRANCH:
		if dirty:
			return {"ok": false, "error": "This copy is on %s and has local changes, so it was not switched to %s." % [name, _BRANCH]}
		var switched := _git(["checkout", _BRANCH])
		if int(switched.get("code", 1)) != 0:
			return {"ok": false, "error": _git_error(switched, "Could not switch to %s." % _BRANCH)}
		dirty = String(_git(["status", "--porcelain"]).get("text", "")).strip_edges() != ""
	var local := String(_git(["rev-parse", "HEAD"]).get("text", "")).strip_edges()
	var remote := String(_git(["rev-parse", "origin/%s" % _BRANCH]).get("text", "")).strip_edges()
	if local == "" or remote == "":
		return {"ok": false, "error": "GitHub has no %s branch." % _BRANCH}
	if local == remote:
		return {"ok": true, "note": "Up to date with %s (%s)." % [_BRANCH, local.substr(0, 7)]}
	var ahead := _git(["merge-base", "--is-ancestor", remote, "HEAD"])
	if int(ahead.get("code", 1)) == 0:
		return {"ok": true, "note": "This copy is ahead of %s on GitHub. Starting this copy." % _BRANCH}
	var behind := _git(["merge-base", "--is-ancestor", "HEAD", remote])
	if int(behind.get("code", 1)) != 0:
		return {"ok": false, "error": "This copy and %s have different commits, so it was not updated." % _BRANCH}
	if dirty:
		return {
			"ok": false,
			"local": true,
			"note": "%s has new commits, and this copy has local changes, so it was not updated. Click again to play this copy." % _BRANCH,
		}
	_set_phase("Downloading updates from %s..." % _BRANCH)
	var pulled := _git(["pull", "--ff-only", "origin", _BRANCH])
	if int(pulled.get("code", 1)) != 0:
		return {"ok": false, "error": _git_error(pulled, "Could not update %s." % _BRANCH)}
	var now := String(_git(["rev-parse", "HEAD"]).get("text", "")).strip_edges()
	return {"ok": true, "note": "Updated to %s (%s)." % [_BRANCH, now.substr(0, 7)]}


func _git(args: PackedStringArray) -> Dictionary:
	var output: Array = []
	var full := PackedStringArray(["-C", _repo])
	full.append_array(args)
	var code := OS.execute("git", full, output, true)
	var text := ""
	for line in output:
		text += String(line)
	return {"code": code, "text": text}


func _git_error(result: Dictionary, fallback: String) -> String:
	var text := String(result.get("text", "")).strip_edges()
	if text == "":
		return fallback
	return text


func _set_phase(text: String) -> void:
	_lock.lock()
	_phase_text = text
	_lock.unlock()


func _show_local_rev() -> void:
	if _repo == "":
		_status.text = "The launcher could not find the game repository."
		return
	var branch := _git(["rev-parse", "--abbrev-ref", "HEAD"])
	if int(branch.get("code", -1)) < 0:
		_status.text = "Install Git for Windows. Play checks the %s branch before the game starts." % _BRANCH
		return
	if int(branch.get("code", 1)) != 0:
		_status.text = "Play checks the %s branch on GitHub before the game starts." % _BRANCH
		return
	var name := String(branch.get("text", "")).strip_edges()
	var local := String(_git(["rev-parse", "HEAD"]).get("text", "")).strip_edges()
	var short := local.substr(0, 7) if local.length() >= 7 else local
	if name == _BRANCH:
		_status.text = "This copy is on %s (%s). Play checks GitHub before the game starts." % [_BRANCH, short]
	else:
		_status.text = "This copy is on %s. A clean copy switches to %s when you play." % [name, _BRANCH]


func _find_repo() -> String:
	var here := ProjectSettings.globalize_path("res://").simplify_path()
	for _step in 6:
		if FileAccess.file_exists(here.path_join(".git")) or DirAccess.dir_exists_absolute(here.path_join(".git")):
			return here
		var parent := here.get_base_dir()
		if parent == here:
			return ""
		here = parent
	return ""


func _godot_exe() -> String:
	var env := OS.get_environment("TOONTOWN_GODOT")
	if env != "" and FileAccess.file_exists(env):
		return env
	var saved := String(_config.get("godot", ""))
	if saved != "" and FileAccess.file_exists(saved):
		return saved
	var beside := _launcher_dir().path_join("Godot.exe")
	if FileAccess.file_exists(beside):
		return beside
	if FileAccess.file_exists(_FALLBACK_GODOT):
		return _FALLBACK_GODOT
	return ""


func _launcher_dir() -> String:
	return ProjectSettings.globalize_path("res://").simplify_path()


func _locate_godot() -> void:
	var dialog := get_node_or_null("GodotDialog") as FileDialog
	if dialog == null:
		dialog = FileDialog.new()
		dialog.name = "GodotDialog"
		dialog.access = FileDialog.ACCESS_FILESYSTEM
		dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		dialog.filters = PackedStringArray(["*.exe ; Godot"])
		dialog.title = "Locate Godot 4.7"
		dialog.file_selected.connect(_on_godot_picked)
		add_child(dialog)
	dialog.popup_centered(Vector2i(900, 600))


func _on_godot_picked(path: String) -> void:
	_config["godot"] = path
	_save_config()
	_refresh_godot_label()
	if _mode == "":
		return
	_start_game()


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
	_config = {"address": "", "port": 4343, "godot": ""}
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


func _refresh_godot_label() -> void:
	if _godot_label == null:
		return
	var exe := _godot_exe()
	if exe == "":
		_godot_label.text = "Godot 4.7 was not found."
		return
	_godot_label.text = "Godot: %s" % exe.get_file()


func _set_buttons_disabled(disabled: bool) -> void:
	for button in _buttons:
		if is_instance_valid(button):
			button.disabled = disabled


func _build() -> void:
	var sky := ColorRect.new()
	sky.color = Color(0.45, 0.72, 0.95)
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 560)
	panel.add_theme_stylebox_override("panel", _panel_box())
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "TOONTOWN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paint(title, 36, Color(0.12, 0.22, 0.62))
	column.add_child(title)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size = Vector2(0, 72)
	_paint(_status, 16, Color(0.08, 0.12, 0.2))
	column.add_child(_status)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 10)
	column.add_child(_menu)
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
	_host_card.add_theme_constant_override("separation", 10)
	_host_card.visible = false
	column.add_child(_host_card)
	_host_body = Label.new()
	_host_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_host_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_host_body.custom_minimum_size = Vector2(0, 220)
	_paint(_host_body, 16, Color(0.08, 0.12, 0.2))
	_host_card.add_child(_host_body)
	_host_card.add_child(_button("Play", _confirm_host))
	_host_card.add_child(_button("Back", _back_from_host))
	var godot_row := HBoxContainer.new()
	godot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(godot_row)
	_godot_label = Label.new()
	_godot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paint(_godot_label, 14, Color(0.15, 0.25, 0.4))
	godot_row.add_child(_godot_label)
	var locate := _button("Locate Godot", _locate_godot)
	locate.custom_minimum_size = Vector2(180, 36)
	godot_row.add_child(locate)
	_refresh_godot_label()


func _labeled(caption: String, field: Control) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.text = caption
	_paint(label, 14, Color(0.12, 0.22, 0.62))
	row.add_child(label)
	row.add_child(field)
	return row


func _field(placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(0, 40)
	edit.add_theme_font_size_override("font_size", 18)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.96)
	box.border_color = Color(0.2, 0.35, 0.7)
	box.set_border_width_all(3)
	box.set_corner_radius_all(10)
	box.content_margin_left = 10
	box.content_margin_right = 10
	edit.add_theme_stylebox_override("normal", box)
	edit.add_theme_stylebox_override("focus", box)
	return edit


func _button(caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 48)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.45))
	button.add_theme_color_override("font_disabled_color", Color(0.85, 0.85, 0.7, 0.7))
	var normal := _button_box(Color(0.16, 0.42, 0.78))
	var hover := _button_box(Color(0.22, 0.5, 0.88))
	var pressed := _button_box(Color(0.1, 0.3, 0.62))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", normal)
	button.pressed.connect(action)
	_buttons.append(button)
	return button


func _panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.93, 0.96, 1.0)
	box.border_color = Color(0.1, 0.25, 0.55)
	box.set_border_width_all(6)
	box.set_corner_radius_all(18)
	return box


func _button_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(12)
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


func _paint(label: Label, size: int, color: Color) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
