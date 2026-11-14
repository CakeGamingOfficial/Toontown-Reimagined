extends Control

## Playtest window for multiplayer-test. The first Play clones that branch
## when this computer does not have the game yet. Later plays fast-forward
## a clean copy. A dirty tree is left alone. The address field is how
## someone joins a friend who clicked Host.

const _BRANCH := "multiplayer-test"
const _REMOTE := "https://github.com/CakeGamingOfficial/Toontown-Reimagined.git"
const _CONFIG := "user://launcher.json"
const _FALLBACK_GODOT := "C:/Users/fukuy/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"

const _FONT: Font = preload("res://assets/ImpressBT.ttf")
const _LOGO: Texture2D = preload("res://assets/logo.png")
const _SKY: Texture2D = preload("res://assets/sky.png")
const _SCROLL: Texture2D = preload("res://assets/scroll.png")
const _BUTTON_UP: Texture2D = preload("res://assets/button_up.png")
const _BUTTON_DOWN: Texture2D = preload("res://assets/button_down.png")
const _BUTTON_HOVER: Texture2D = preload("res://assets/button_hover.png")

const _INK := Color(0.33, 0.2, 0.08)
const _INK_SOFT := Color(0.48, 0.32, 0.16)

var _config: Dictionary = {}
var _repo := ""
var _git_path := ""
var _mode := ""
var _busy := false
var _play_local := false
var _worker: Thread
var _lock := Mutex.new()
var _phase_text := ""
var _sync_done := false
var _outcome: Dictionary = {}
var _meter_key := ""
var _meter_at := 0
var _meter_percent := 0
var _needs_import := false
var _launch_project := ""

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
	if bool(outcome.get("imported", false)):
		if not bool(outcome.get("ok", false)):
			_busy = false
			_set_buttons_disabled(false)
			_status.text = String(outcome.get("error", "The game could not be prepared."))
			return
		_needs_import = false
		_launch_game()
		return
	var installed := String(outcome.get("repo", ""))
	if installed != "":
		_repo = installed
		_config["repo"] = installed
		_save_config()
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
	_launch_project = project
	if _import_needed(project):
		_set_phase("Preparing the game. The first time takes a while.")
		_worker = Thread.new()
		_worker.start(_import_thread)
		return
	_launch_game()


func _import_needed(project: String) -> bool:
	if _needs_import:
		return true
	return not FileAccess.file_exists(project.path_join(".godot/uid_cache.bin"))


func _import_thread() -> void:
	var exe := _godot_exe()
	var result := _run_watched(exe, PackedStringArray([
		"--headless", "--path", _launch_project, "--import", "--quit",
	]), "the game", false)
	var ready := FileAccess.file_exists(_launch_project.path_join(".godot/uid_cache.bin"))
	_lock.lock()
	_outcome = {
		"imported": true,
		"ok": int(result.get("code", 1)) == 0 and ready,
		"error": _git_error(result, "The game could not be prepared."),
	}
	_sync_done = true
	_lock.unlock()


func _launch_game() -> void:
	var exe := _godot_exe()
	var project := _launch_project
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
	if _repo != "" and not outcome.has("repo"):
		outcome["repo"] = _repo
	_lock.lock()
	_outcome = outcome
	_sync_done = true
	_lock.unlock()


func _sync() -> Dictionary:
	var git_ready := _ensure_git()
	if not bool(git_ready.get("ok", false)):
		return git_ready
	var ready := _ensure_repo()
	if not bool(ready.get("ok", false)):
		return ready
	_set_phase("Checking %s..." % _BRANCH)
	var branch := _git(["rev-parse", "--abbrev-ref", "HEAD"])
	if int(branch.get("code", -1)) < 0:
		return {"ok": false, "error": "Git for Windows did not install."}
	if int(branch.get("code", 1)) != 0:
		return {"ok": false, "error": _git_error(branch, "Git could not read this repository.")}
	var name := String(branch.get("text", "")).strip_edges()
	var dirty := String(_git(["status", "--porcelain"]).get("text", "")).strip_edges() != ""
	_set_phase("Checking %s on GitHub..." % _BRANCH)
	var fetched := _git_transfer(["fetch", "--progress", "origin", _BRANCH], "the update")
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
		_needs_import = true
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
	_set_phase("Downloading the update...")
	var pulled := _git_transfer(["pull", "--progress", "--ff-only", "origin", _BRANCH], "the update")
	if int(pulled.get("code", 1)) != 0:
		return {"ok": false, "error": _git_error(pulled, "Could not update %s." % _BRANCH)}
	_needs_import = true
	var now := String(_git(["rev-parse", "HEAD"]).get("text", "")).strip_edges()
	return {"ok": true, "note": "Updated to %s (%s)." % [_BRANCH, now.substr(0, 7)]}


func _git(args: PackedStringArray) -> Dictionary:
	var exe := _git_exe()
	if exe == "":
		return {"code": -1, "text": ""}
	var output: Array = []
	var full := PackedStringArray(["-C", _repo])
	full.append_array(args)
	var code := OS.execute(exe, full, output, true)
	var text := ""
	for line in output:
		text += String(line)
	return {"code": code, "text": text}


func _git_error(result: Dictionary, fallback: String) -> String:
	var text := String(result.get("text", "")).strip_edges()
	if text == "":
		return fallback
	return text


func _git_transfer(args: PackedStringArray, what: String) -> Dictionary:
	var exe := _git_exe()
	if exe == "":
		return {"code": -1, "text": ""}
	var full := PackedStringArray(["-C", _repo])
	full.append_array(args)
	return _run_watched(exe, full, what)


## Git writes percentages to stderr with a carriage return, and only when
## --progress is set, because a pipe is not a console. The download scripts
## print a whole sentence of their own.
func _run_watched(exe: String, args: PackedStringArray, what: String, keep_plain: bool = true) -> Dictionary:
	_meter_key = ""
	_meter_at = 0
	_meter_percent = 0
	var info: Dictionary = OS.execute_with_pipe(exe, args)
	var pid := int(info.get("pid", -1))
	if pid <= 0:
		return {"code": -1, "text": ""}
	var stdio := info.get("stdio") as FileAccess
	var stderr_pipe := info.get("stderr") as FileAccess
	var pending := ""
	var errors: Array[String] = []
	while true:
		var chunk := _read_pipe(stdio) + _read_pipe(stderr_pipe)
		if chunk != "":
			pending += chunk
			pending = _consume_progress(pending, what, errors, keep_plain)
			continue
		if not OS.is_process_running(pid):
			break
		OS.delay_msec(100)
	if pending.strip_edges() != "":
		if not _apply_progress_line(pending, what) and (keep_plain or _problem_line(pending)):
			errors.append(pending.strip_edges())
	if stdio != null:
		stdio.close()
	if stderr_pipe != null:
		stderr_pipe.close()
	return {"code": OS.get_process_exit_code(pid), "text": "\n".join(PackedStringArray(errors))}


func _read_pipe(pipe: FileAccess) -> String:
	if pipe == null:
		return ""
	var available := mini(int(pipe.get_length()), 65536)
	if available <= 0:
		return ""
	return pipe.get_buffer(available).get_string_from_utf8()


func _consume_progress(buffer: String, what: String, errors: Array[String], keep_plain: bool) -> String:
	var start := 0
	var index := 0
	while index < buffer.length():
		var ch := buffer.unicode_at(index)
		if ch != 10 and ch != 13:
			index += 1
			continue
		if index > start:
			var line := buffer.substr(start, index - start)
			if not _apply_progress_line(line, what) and (keep_plain or _problem_line(line)):
				errors.append(line.strip_edges())
		start = index + 1
		index += 1
	return buffer.substr(start)


func _problem_line(line: String) -> bool:
	var lower := line.to_lower()
	return lower.contains("error") or lower.contains("fatal") or lower.contains("failed")


func _apply_progress_line(line: String, what: String) -> bool:
	var cleaned := line.strip_edges()
	if cleaned == "":
		return false
	if cleaned.begins_with("["):
		var import_mark := _percent_mark(cleaned)
		if import_mark < 0:
			return false
		var import_percent := _percent_value(cleaned, import_mark)
		if import_percent < 0:
			return false
		var import_eta := _eta_phrase("Preparing the game", import_percent)
		if import_eta == "":
			_set_phase("Preparing the game... %d%%" % import_percent)
		else:
			_set_phase("Preparing the game... %d%%, %s" % [import_percent, import_eta])
		return true
	if cleaned.begins_with("Downloading ") or cleaned.begins_with("Unpacking ") or cleaned.begins_with("Installing ") or cleaned.begins_with("Preparing "):
		_set_phase(cleaned)
		return true
	var mark := _percent_mark(cleaned)
	if mark < 0:
		return false
	var percent := _percent_value(cleaned, mark)
	if percent < 0:
		return false
	var label := _friendly_phase(_percent_label(cleaned, mark), what)
	var phrase := _eta_phrase(label, percent)
	if phrase == "":
		_set_phase("%s... %d%%" % [label, percent])
	else:
		_set_phase("%s... %d%%, %s" % [label, percent, phrase])
	return true


func _percent_mark(line: String) -> int:
	var at := line.find("%")
	while at >= 0:
		if _percent_value(line, at) >= 0:
			return at
		at = line.find("%", at + 1)
	return -1


func _percent_value(line: String, mark: int) -> int:
	var index := mark - 1
	while index >= 0 and line.unicode_at(index) == 32:
		index -= 1
	var end := index
	while index >= 0 and line.unicode_at(index) >= 48 and line.unicode_at(index) <= 57:
		index -= 1
	if end < 0 or line.unicode_at(end) < 48 or line.unicode_at(end) > 57:
		return -1
	return int(line.substr(index + 1, end - index))


func _percent_label(line: String, mark: int) -> String:
	var index := mark - 1
	while index >= 0 and line.unicode_at(index) == 32:
		index -= 1
	while index >= 0 and line.unicode_at(index) >= 48 and line.unicode_at(index) <= 57:
		index -= 1
	return line.substr(0, index + 1).strip_edges().trim_suffix(":")


func _friendly_phase(raw: String, what: String) -> String:
	var lower := raw.to_lower()
	if lower.contains("receiving"):
		return "Downloading %s" % what
	if lower.contains("resolving"):
		return "Unpacking %s" % what
	if lower.contains("updating files"):
		return "Installing %s" % what
	if lower.contains("counting") or lower.contains("enumerating") or lower.contains("compressing"):
		return "Preparing %s" % what
	if raw == "":
		return "Downloading %s" % what
	return raw


func _eta_phrase(label: String, percent: int) -> String:
	if percent <= 0 or percent >= 100:
		_meter_key = label
		_meter_percent = percent
		_meter_at = Time.get_ticks_msec()
		return ""
	if label != _meter_key or percent < _meter_percent:
		_meter_key = label
		_meter_percent = percent
		_meter_at = Time.get_ticks_msec()
		return ""
	_meter_percent = percent
	var elapsed := float(Time.get_ticks_msec() - _meter_at) / 1000.0
	if elapsed < 1.0:
		return ""
	var seconds := int(round(elapsed * float(100 - percent) / float(percent)))
	return _format_left(seconds)


func _format_left(seconds: int) -> String:
	if seconds <= 1:
		return "about a second left"
	if seconds < 60:
		return "about %d seconds left" % seconds
	var minutes := int(round(float(seconds) / 60.0))
	if minutes <= 1:
		return "about a minute left"
	if minutes < 60:
		return "about %d minutes left" % minutes
	var hours := int(round(float(minutes) / 60.0))
	if hours <= 1:
		return "about an hour left"
	return "about %d hours left" % hours


func _set_phase(text: String) -> void:
	_lock.lock()
	_phase_text = text
	_lock.unlock()


func _show_local_rev() -> void:
	if _repo == "":
		_status.text = "The game is not installed yet. Play downloads Git for Windows if it is needed, then the game from %s." % _BRANCH
		return
	var branch := _git(["rev-parse", "--abbrev-ref", "HEAD"])
	if int(branch.get("code", -1)) < 0:
		_status.text = "Play downloads Git for Windows, then checks %s." % _BRANCH
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
	var here := _launcher_dir()
	for _step in 6:
		if _is_game_repo(here):
			return here
		var parent := here.get_base_dir()
		if parent == here:
			break
		here = parent
	var saved := String(_config.get("repo", ""))
	if _is_game_repo(saved):
		return saved
	if _is_game_repo(_install_dir()):
		return _install_dir()
	return ""


func _install_dir() -> String:
	return _launcher_dir().get_base_dir().path_join("game")


func _is_game_repo(folder: String) -> bool:
	if folder == "":
		return false
	var git_dir := folder.path_join(".git")
	if not FileAccess.file_exists(git_dir) and not DirAccess.dir_exists_absolute(git_dir):
		return false
	return FileAccess.file_exists(folder.path_join("Godot Project/project-toontown/project.godot"))


func _ensure_git() -> Dictionary:
	if _git_exe() != "":
		return {"ok": true}
	_set_phase("Downloading Git for Windows...")
	var script := _launcher_dir().path_join("download_git.ps1")
	var downloaded := _run_watched("powershell.exe", PackedStringArray([
		"-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script,
	]), "Git for Windows")
	if _git_exe() == "":
		return {"ok": false, "error": _git_error(downloaded, "Git for Windows did not install.")}
	return {"ok": true}


func _git_exe() -> String:
	if _git_path == "git" or (_git_path != "" and FileAccess.file_exists(_git_path)):
		return _git_path
	var output: Array = []
	if OS.execute("git", PackedStringArray(["--version"]), output, true) == 0:
		_git_path = "git"
		return _git_path
	var bundled := _launcher_dir().path_join("git/cmd/git.exe")
	if FileAccess.file_exists(bundled):
		_git_path = bundled
		return _git_path
	_git_path = ""
	return ""


func _ensure_repo() -> Dictionary:
	if _repo != "":
		return {"ok": true, "repo": _repo}
	var exe := _git_exe()
	if exe == "":
		return {"ok": false, "error": "Git for Windows did not install."}
	var dest := _install_dir()
	if DirAccess.dir_exists_absolute(dest):
		if _is_game_repo(dest):
			_repo = dest
			return {"ok": true, "repo": dest}
		return {"ok": false, "error": "A folder named game is already next to the launcher, and it is not the game. Move that folder aside and try again."}
	_set_phase("Downloading the game... This is a few gigabytes.")
	var cloned := _run_watched(exe, PackedStringArray([
		"clone", "--progress", "--branch", _BRANCH, "--single-branch", _REMOTE, dest,
	]), "the game")
	if int(cloned.get("code", 1)) != 0:
		return {"ok": false, "error": _git_error(cloned, "The game download did not finish.")}
	if not _is_game_repo(dest):
		return {"ok": false, "error": "The download finished, but the game project was not in it."}
	_repo = dest
	_needs_import = true
	return {"ok": true, "repo": dest}


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
	var sky := TextureRect.new()
	sky.texture = _SKY
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
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
	var godot_row := HBoxContainer.new()
	godot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	godot_row.add_theme_constant_override("separation", 12)
	stack.add_child(godot_row)
	_godot_label = Label.new()
	_godot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paint(_godot_label, 15, _INK_SOFT)
	godot_row.add_child(_godot_label)
	var locate := _button("Locate Godot", _locate_godot)
	locate.custom_minimum_size = Vector2(210, 40)
	locate.add_theme_font_size_override("font_size", 16)
	godot_row.add_child(locate)
	_refresh_godot_label()


func _logo_texture() -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = _LOGO
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
	edit.add_theme_font_override("font", _FONT)
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
	button.add_theme_font_override("font", _FONT)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.16, 0.1, 0.02))
	button.add_theme_color_override("font_hover_color", Color(0.05, 0.12, 0.28))
	button.add_theme_color_override("font_pressed_color", Color(0.16, 0.1, 0.02))
	button.add_theme_color_override("font_disabled_color", Color(0.28, 0.24, 0.16, 0.65))
	var normal := _pill(_BUTTON_UP)
	var hover := _pill(_BUTTON_HOVER)
	var pressed := _pill(_BUTTON_DOWN)
	var disabled := _pill(_BUTTON_UP, Color(0.72, 0.72, 0.72))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.pressed.connect(action)
	_buttons.append(button)
	return button


func _scroll_box() -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = _SCROLL
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


func _pill(texture: Texture2D, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.texture_margin_left = 18
	box.texture_margin_right = 18
	box.texture_margin_top = 10
	box.texture_margin_bottom = 10
	box.modulate_color = tint
	return box


func _paint(label: Label, size: int, color: Color) -> void:
	label.add_theme_font_override("font", _FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
