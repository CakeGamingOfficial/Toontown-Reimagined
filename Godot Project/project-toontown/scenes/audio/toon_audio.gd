class_name ToonAudio
extends Node

## Music and sound-effect levels from the Shticker Book Options page.
## Each bus multiplies the volume a track already chose for itself.

const _PATH := "user://audio.cfg"
const _MUSIC := "Music"
const _SFX := "SFX"

static var _music_on := true
static var _sfx_on := true
static var _music_volume := 1.0
static var _sfx_volume := 1.0


func _ready() -> void:
	_ensure_bus(_MUSIC)
	_ensure_bus(_SFX)
	_load()
	_apply()


static func music_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = _MUSIC
	return player


static func effect_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = _SFX
	return player


static func effect_3d() -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.bus = _SFX
	return player


static func music_on() -> bool:
	return _music_on


static func sfx_on() -> bool:
	return _sfx_on


static func music_volume() -> float:
	return _music_volume


static func sfx_volume() -> float:
	return _sfx_volume


static func set_music_on(enabled: bool) -> void:
	_music_on = enabled
	_apply()
	_save()


static func set_sfx_on(enabled: bool) -> void:
	_sfx_on = enabled
	_apply()
	_save()


static func set_music_volume(linear: float) -> void:
	_music_volume = clampf(linear, 0.0, 1.0)
	_apply()
	_save()


static func set_sfx_volume(linear: float) -> void:
	_sfx_volume = clampf(linear, 0.0, 1.0)
	_apply()
	_save()


static func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


static func _apply() -> void:
	_apply_bus(_MUSIC, _music_on, _music_volume)
	_apply_bus(_SFX, _sfx_on, _sfx_volume)


static func _apply_bus(bus_name: String, enabled: bool, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var level := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))
	AudioServer.set_bus_mute(index, not enabled or level <= 0.001)


static func _load() -> void:
	var config := ConfigFile.new()
	if config.load(_PATH) != OK:
		return
	_music_on = bool(config.get_value("audio", "music_on", true))
	_sfx_on = bool(config.get_value("audio", "sfx_on", true))
	_music_volume = clampf(float(config.get_value("audio", "music_volume", 1.0)), 0.0, 1.0)
	_sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", 1.0)), 0.0, 1.0)


static func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music_on", _music_on)
	config.set_value("audio", "sfx_on", _sfx_on)
	config.set_value("audio", "music_volume", _music_volume)
	config.set_value("audio", "sfx_volume", _sfx_volume)
	config.save(_PATH)
