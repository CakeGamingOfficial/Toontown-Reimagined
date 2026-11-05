class_name DisplaySettings
extends RefCounted

## Window mode, resolution, and VSync from the Shticker Book Video tab.

const _PATH := "user://display.cfg"
const _MODES: PackedStringArray = ["fullscreen", "windowed", "borderless"]
const _SIZES: Array[Vector2i] = [
	Vector2i(640, 480),
	Vector2i(800, 600),
	Vector2i(1024, 768),
	Vector2i(1280, 720),
	Vector2i(1280, 800),
	Vector2i(1366, 768),
	Vector2i(1440, 900),
	Vector2i(1600, 900),
	Vector2i(1680, 1050),
	Vector2i(1920, 1080),
	Vector2i(1920, 1200),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
	Vector2i(3440, 1440),
	Vector2i(3840, 2160),
]

static var _mode := "windowed"
static var _vsync := true
static var _width := 0
static var _height := 0
static var _ready := false


static func mode() -> String:
	_ensure()
	return _mode


static func mode_label() -> String:
	match mode():
		"fullscreen":
			return "Fullscreen"
		"borderless":
			return "Borderless Windowed"
		_:
			return "Windowed"


static func cycle_mode() -> void:
	_ensure()
	var index := _MODES.find(_mode)
	if index < 0:
		index = 0
	_mode = _MODES[(index + 1) % _MODES.size()]
	_apply()
	_save()


static func resolution() -> Vector2i:
	_ensure()
	if _width >= 640 and _height >= 480:
		return Vector2i(_width, _height)
	if _mode == "windowed":
		var window := DisplayServer.window_get_size()
		if window.x >= 640 and window.y >= 480:
			return window
	return _screen_size()


static func resolution_label() -> String:
	var size := resolution()
	return "%d x %d" % [size.x, size.y]


static func resolutions() -> Array[Vector2i]:
	var screen := _screen_size()
	var list: Array[Vector2i] = []
	for size in _SIZES:
		if size.x <= screen.x and size.y <= screen.y and not list.has(size):
			list.append(size)
	if screen.x >= 640 and screen.y >= 480 and not list.has(screen):
		list.append(screen)
	var current := resolution()
	if current.x >= 640 and current.y >= 480 and not list.has(current):
		list.append(current)
	if list.is_empty():
		list.append(Vector2i(1280, 720))
	return list


static func cycle_resolution() -> void:
	var list := resolutions()
	var current := resolution()
	var index := list.find(current)
	if index < 0:
		index = 0
	var next: Vector2i = list[(index + 1) % list.size()]
	_width = next.x
	_height = next.y
	_apply()
	_save()


static func fullscreen() -> bool:
	return mode() != "windowed"


static func vsync_on() -> bool:
	_ensure()
	return _vsync


static func set_fullscreen(enabled: bool) -> void:
	_ensure()
	_mode = "borderless" if enabled else "windowed"
	_apply()
	_save()


static func set_vsync(enabled: bool) -> void:
	_ensure()
	_vsync = enabled
	_apply()
	_save()


static func apply() -> void:
	_ensure()
	_apply()


static func _ensure() -> void:
	if _ready:
		return
	_ready = true
	var config := ConfigFile.new()
	config.load(_PATH)
	if config.has_section_key("display", "mode"):
		_mode = String(config.get_value("display", "mode", "windowed"))
	elif bool(config.get_value("display", "fullscreen", false)):
		# The old switch was Godot's borderless fullscreen.
		_mode = "borderless"
	else:
		_mode = "windowed"
	if not _MODES.has(_mode):
		_mode = "windowed"
	_vsync = bool(config.get_value("display", "vsync", true))
	_width = int(config.get_value("display", "width", 0))
	_height = int(config.get_value("display", "height", 0))


static func _apply() -> void:
	var borderless := _mode == "borderless"
	var size := resolution()
	match _mode:
		"fullscreen":
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, borderless)
	# Leave an untouched windowed frame where the player put it.
	if _mode == "borderless" or (_mode == "windowed" and _width >= 640 and _height >= 480):
		DisplayServer.window_set_size(size)
		_center(size)
	var vsync := DisplayServer.VSYNC_ENABLED if _vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync)


static func _center(size: Vector2i) -> void:
	var screen_index := DisplayServer.window_get_current_screen()
	var screen := DisplayServer.screen_get_size(screen_index)
	var origin := DisplayServer.screen_get_position(screen_index)
	var pos := origin + (screen - size) / 2
	DisplayServer.window_set_position(pos)


static func _screen_size() -> Vector2i:
	var screen := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	if screen.x < 2 or screen.y < 2:
		return Vector2i(1920, 1080)
	return screen


static func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "mode", _mode)
	config.set_value("display", "fullscreen", _mode != "windowed")
	config.set_value("display", "vsync", _vsync)
	config.set_value("display", "width", _width)
	config.set_value("display", "height", _height)
	config.save(_PATH)
