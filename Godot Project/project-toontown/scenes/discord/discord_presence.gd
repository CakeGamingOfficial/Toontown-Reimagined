extends Node

## Shows the toon, Laff, and current area on Discord while the game is open.
## The desktop client has to be running. A missing client is ignored.

const _APP_ID := "1565835545559572530"
const _RPC := preload("res://addons/discord_rich_presence/discord_rich_presence.gd")
const _TITLE := preload("res://scenes/places/zone_title.gd")
const _PLACES := preload("res://scenes/places/hood_places.gd")
const _SHOP := preload("res://scenes/interiors/gag_shop_door.gd")

const _HOOD := {
	1000: "Donald's Dock",
	2000: "Toontown Central",
	3000: "The Brrrgh",
	4000: "Minnie's Melodyland",
	5000: "Daisy Gardens",
	6000: "Chip 'n Dale's Acorn Acres",
	8000: "Goofy Speedway",
	9000: "Donald's Dreamland",
	10000: "Bossbot HQ",
	11000: "Sellbot HQ",
	12000: "Cashbot HQ",
	13000: "Lawbot HQ",
	17000: "Chip 'n Dale's MiniGolf",
}

var _rpc: DiscordRichPresence
var _battle: StreetBattle
var _meter: LaffMeter
var _scene_path := ""
var _saved_hp := -1
var _saved_max := -1
var _shown := ""
var _pending := ""
var _pending_details := ""
var _pending_state := ""
var _started := 0
var _next_send := 0
var _look_left := 0.0


func _ready() -> void:
	_started = int(Time.get_unix_time_from_system())
	_rpc = _RPC.new()
	_rpc.app_id = _APP_ID
	add_child(_rpc)
	_publish()


func _process(delta: float) -> void:
	_look_left -= delta
	if _look_left <= 0.0:
		_look_left = 0.5
		_find_hud()
	_publish()
	if _pending != _shown and Time.get_ticks_msec() >= _next_send:
		_flush()


func _find_hud() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		_battle = null
		_meter = null
		_scene_path = ""
		return
	var path := scene.scene_file_path
	if path != _scene_path:
		_scene_path = path
		_battle = null
		_meter = null
		_saved_hp = -1
	if _battle == null or not is_instance_valid(_battle):
		_battle = scene.find_child("StreetBattle", true, false) as StreetBattle
	if _meter == null or not is_instance_valid(_meter):
		_meter = scene.find_child("LaffMeter", true, false) as LaffMeter


func _publish() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var path := scene.scene_file_path
	if path.is_empty():
		return
	var where := _where(path, scene)
	var who := _toon_line(path)
	var details := who
	var state := where
	if details.is_empty():
		details = where
		state = ""
	var signature := details + "\n" + state
	if signature == _pending:
		return
	_pending = signature
	_pending_details = details
	_pending_state = state
	if Time.get_ticks_msec() >= _next_send:
		_flush()


## Discord asks games not to rewrite presence several times a second.
## Laff can change on every gag, so those updates wait a few seconds.
func _flush() -> void:
	if _pending == _shown:
		return
	_shown = _pending
	_next_send = Time.get_ticks_msec() + 5000
	var activity := {
		"details": _pending_details,
		"timestamps": {"start": _started},
	}
	if not _pending_state.is_empty():
		activity["state"] = _pending_state
	_rpc.set_activity(activity)


func _toon_line(path: String) -> String:
	var file := path.get_file().get_basename()
	if file == "pick_a_toon" or file == "make_a_toon":
		return ""
	var style := ToonRoster.selected_style()
	if style == null:
		return ""
	var current := 0
	var maximum := 0
	var live := _meter != null and is_instance_valid(_meter) and _meter.loadout() != null
	if live:
		var followed := _meter.loadout()
		current = followed.hp
		maximum = followed.max_hp
	else:
		if _saved_hp < 0:
			var saved := ToonLoadout.for_selected()
			_saved_hp = saved.hp
			_saved_max = saved.max_hp
		current = _saved_hp
		maximum = _saved_max
	return "%s — %d/%d Laff" % [style.display_name(), current, maximum]


func _where(path: String, scene: Node) -> String:
	var place := _place(path)
	var spot := String(place["details"])
	var extra := String(place["state"])
	var where := spot
	if extra == "Playground":
		where = spot + " Playground"
	elif not extra.is_empty() and extra != spot:
		where = "%s, %s" % [spot, extra]
	if _battle != null and is_instance_valid(_battle) and _battle.active():
		return "Battling a Cog — " + where
	if scene.has_method("in_cutscene") and bool(scene.call("in_cutscene")):
		return "In a Cutscene — " + where
	return where


func _place(path: String) -> Dictionary:
	var file := path.get_file().get_basename()
	if file == "pick_a_toon":
		return {"details": "Picking a Toon", "state": "Toontown"}
	if file == "make_a_toon":
		return {"details": "Making a Toon", "state": "Toontown"}
	if file == "toontorial" or file == "tutorial_zone":
		return {"details": "Toontorial", "state": "Toontown Central"}
	if _PLACES.is_house(path):
		return {"details": "Inside the House", "state": "Estate"}
	if _PLACES.is_estate(path):
		return {"details": "On the Estate", "state": "Estate"}
	if _PLACES.is_gag_shop(path):
		return {"details": "Gag Shop", "state": _hood_name(int(_SHOP.hood))}
	var info := _TITLE.caption(path)
	if info.is_empty():
		return {"details": "Toontown", "state": ""}
	var lines := String(info["text"]).split("\n")
	var hood := lines[0]
	if lines.size() == 1:
		return {"details": hood, "state": ""}
	var where := lines[1]
	if where == "Playground":
		return {"details": hood, "state": "Playground"}
	return {"details": where, "state": hood}


func _hood_name(hood: int) -> String:
	var key := hood - posmod(hood, 1000)
	if _HOOD.has(key):
		return String(_HOOD[key])
	return "Toontown"
