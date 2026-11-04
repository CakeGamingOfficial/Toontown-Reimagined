class_name DisplaySettings
extends RefCounted

## Window mode and VSync from the Shticker Book Graphics tab.

const _PATH := "user://display.cfg"

static var _fullscreen := false
static var _vsync := true
static var _ready := false


static func fullscreen() -> bool:
	_ensure()
	return _fullscreen


static func vsync_on() -> bool:
	_ensure()
	return _vsync


static func set_fullscreen(enabled: bool) -> void:
	_ensure()
	_fullscreen = enabled
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
	_fullscreen = bool(config.get_value("display", "fullscreen", false))
	_vsync = bool(config.get_value("display", "vsync", true))


static func _apply() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	var vsync := DisplayServer.VSYNC_ENABLED if _vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync)


static func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen", _fullscreen)
	config.set_value("display", "vsync", _vsync)
	config.save(_PATH)
