extends Node3D

## PartyPlanner and the activities a party actually pays out.
## Parties are PartyHood, zone 18000. PartyLoader loads phase_13/dna/party_sz.dna
## and shifts the safe zone 10 units west. Activities sit on that grid.
## The clock is the 100 jellybean base. Each activity adds its original cost.
## A party lasts PARTY_DURATION, 30 minutes. Cannon, trampoline, catch, tug,
## and cog pies pay the original jellybean amounts.

const _BEANS := preload("res://scenes/toons/jellybeans.gd")
const _HOLIDAYS := preload("res://scenes/shticker/calendar_holidays.gd")
const _GUI := preload("res://scenes/toons/toon_gui.gd")
const _LOADING := preload("res://scenes/gui/loading_screen.gd")
const _FILE := "user://toon_party.json"
const _GROUNDS := "res://scenes/playgrounds/party_grounds.tscn"
const _LENGTH := 1800.0
const _BASE := 100
const _CELL_X := 14.4
const _CELL_Y := 14.6
const _GEOM_SHIFT_X := -10.0

const _MODELS := {
	"clock": "res://assets/parties/clock.glb",
	"cannon": "res://assets/parties/cannon.glb",
	"trampoline": "res://assets/parties/trampoline.glb",
	"jukebox": "res://assets/parties/jukebox.glb",
	"dance": "res://assets/parties/dance.glb",
	"tug": "res://assets/parties/tug.glb",
	"fireworks": "res://assets/parties/fireworks.glb",
	"catch": "res://assets/parties/catch.glb",
	"cog": "res://assets/parties/cog.glb",
}

# Grid squares are the activity's center cell. Even footprints use
# PartyUtils.getCenterPosFromGridSize and shift half a cell.
const _LAYOUT := {
	"clock": {"at": Vector2i(9, 7), "size": Vector2i(1, 1), "reach": 6.0},
	"cannon": {"at": Vector2i(11, 7), "size": Vector2i(1, 1), "reach": 8.0},
	"jukebox": {"at": Vector2i(7, 7), "size": Vector2i(1, 1), "reach": 8.0},
	"trampoline": {"at": Vector2i(9, 4), "size": Vector2i(2, 2), "reach": 14.0},
	"dance": {"at": Vector2i(9, 11), "size": Vector2i(3, 3), "reach": 18.0},
	"tug": {"at": Vector2i(4, 3), "size": Vector2i(4, 4), "reach": 20.0},
	"fireworks": {"at": Vector2i(13, 3), "size": Vector2i(4, 2), "reach": 16.0},
	"catch": {"at": Vector2i(3, 7), "size": Vector2i(5, 5), "reach": 24.0},
	"cog": {"at": Vector2i(14, 7), "size": Vector2i(5, 5), "reach": 24.0},
}

const _ACTIVITIES := [
	{"id": "cannon", "name": "Cannon", "cost": 50},
	{"id": "trampoline", "name": "Trampoline", "cost": 50},
	{"id": "jukebox", "name": "Jukebox", "cost": 50},
	{"id": "dance", "name": "Dance Floor", "cost": 100},
	{"id": "tug", "name": "Tug of War", "cost": 200},
	{"id": "fireworks", "name": "Fireworks", "cost": 200},
	{"id": "catch", "name": "Catch", "cost": 300},
	{"id": "cog", "name": "Cog Pie Round", "cost": 300},
]

static var _party: Dictionary = {}
static var _loaded := false

var gate := false
var _picked: Array[String] = []
var _layer: CanvasLayer
var _text: Label
var _buttons: VBoxContainer
var _busy := false
var _gate := false


static func place_gate(host: Node) -> void:
	if host.get_node_or_null("PartyGate") != null:
		return
	var gate := _find_gate(host)
	if gate == null:
		return
	var here := load("res://scenes/parties/toon_party.gd").new() as Node3D
	here.name = "PartyGate"
	here.set("gate", true)
	host.add_child(here)
	here.global_position = gate.global_position


static func _find_gate(node: Node) -> Node3D:
	var name := String(node.name)
	if name.contains("partyGate") or name.begins_with("prop_party_gate"):
		return node as Node3D
	for child in node.get_children():
		var found := _find_gate(child)
		if found != null:
			return found
	return null


static func place_grounds(host: Node) -> void:
	if not active():
		return
	if host.get_node_or_null("PartyGrounds") != null:
		return
	var here: Node = load("res://scenes/parties/toon_party.gd").new()
	here.name = "PartyGrounds"
	host.add_child(here)


static func active() -> bool:
	_ensure()
	return float(_party.get("until", 0.0)) > Time.get_unix_time_from_system()


static func plan(ids: Array) -> String:
	_ensure()
	if active():
		return "You already have a party going."
	var cost := _BASE
	var chosen: Array = []
	var has_juke := false
	var has_dance := false
	for id in ids:
		var card := _card(String(id))
		if card.is_empty():
			continue
		if String(id) == "jukebox" and has_juke:
			continue
		if String(id) == "dance" and has_dance:
			continue
		has_juke = has_juke or String(id) == "jukebox"
		has_dance = has_dance or String(id) == "dance"
		cost += int(card.get("cost", 0))
		chosen.append(String(id))
	if cost < _BASE:
		return "A party costs at least %d jellybeans." % _BASE
	if not _BEANS.take_beans(cost, true):
		return "You need %d jellybeans." % cost
	_party = {
		"until": Time.get_unix_time_from_system() + _LENGTH,
		"activities": chosen,
		"cannon": 0,
		"catch": 0,
	}
	_save()
	return "Your party has started. It lasts 30 minutes."


static func summary() -> String:
	_ensure()
	if not active():
		return "No party is planned. A party costs %d jellybeans plus activities." % _BASE
	var left := int(float(_party.get("until", 0.0)) - Time.get_unix_time_from_system())
	var names := "Clock"
	for id in _party.get("activities", []):
		names += ", " + String(_card(String(id)).get("name", id))
	return "Party time left: %d:%02d\n%s" % [left / 60, left % 60, names]


func _ready() -> void:
	_gate = gate
	if not _gate:
		_stations()
	_layer = CanvasLayer.new()
	_layer.layer = 25
	_layer.visible = false
	add_child(_layer)
	var panel := ColorRect.new()
	panel.color = Color(0.45, 0.2, 0.55, 0.94)
	panel.position = Vector2(300, 70)
	panel.size = Vector2(720, 560)
	_layer.add_child(panel)
	_text = Label.new()
	_text.position = Vector2(16, 12)
	_text.size = Vector2(688, 140)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_GUI.style_label(_text, Color.WHITE, 20, Color.BLACK, 3)
	panel.add_child(_text)
	_buttons = VBoxContainer.new()
	_buttons.position = Vector2(16, 160)
	_buttons.size = Vector2(688, 380)
	panel.add_child(_buttons)


func _process(_delta: float) -> void:
	var show := String(ToonNet.latest("dev:fireworks").get("show", ""))
	if show != "" and String(get_meta("dev_show", "")) != show:
		set_meta("dev_show", show)
		_fireworks()
	if _busy:
		return
	var body := _body()
	if body == null:
		return
	if _gate:
		if global_position.distance_to(body.global_position) > 4.0:
			return
		_busy = true
		_open_planner()
		return
	for child in get_children():
		if not (child is Node3D):
			continue
		var id := String(child.name)
		if _card(id).is_empty():
			continue
		var marker := child as Node3D
		var reach := float(marker.get_meta("reach", 8.0))
		var flat := Vector2(body.global_position.x, body.global_position.z).distance_to(
			Vector2(marker.global_position.x, marker.global_position.z)
		)
		if flat > reach:
			continue
		_busy = true
		_open_activity(id)
		return


func _open_planner() -> void:
	_hold(true)
	_picked = []
	_paint_planner()


func _paint_planner() -> void:
	_clear()
	var cost := _BASE
	for id in _picked:
		cost += int(_card(id).get("cost", 0))
	_text.text = "Plan a Party\n%s\nTotal: %d jellybeans" % [summary(), cost]
	_layer.visible = true
	if active():
		_add("Go to the Party Grounds", _go)
	else:
		for card in _ACTIVITIES:
			var id := String(card.get("id", ""))
			var mark := "On" if _picked.has(id) else "Off"
			_add("%s (%d) [%s]" % [String(card.get("name", "")), int(card.get("cost", 0)), mark], _toggle.bind(id))
		_add("Start Party", _start)
	_add("Close", _close)


func _toggle(id: String) -> void:
	if _picked.has(id):
		_picked.erase(id)
	else:
		_picked.append(id)
	_paint_planner()


func _go() -> void:
	_layer.visible = false
	_hold(false)
	_busy = true
	var arrival = load("res://scenes/playgrounds/playground_toon.gd")
	arrival.teleport_in = true
	_LOADING.change_to(_GROUNDS)


func _start() -> void:
	var message := plan(_picked)
	if active():
		_go()
		return
	_text.text = message
	_clear()
	_add("Close", _close)


func _stations() -> void:
	_spot("clock")
	for id in _party.get("activities", []):
		_spot(String(id))


func _spot(id: String) -> void:
	var layout: Dictionary = _LAYOUT.get(id, {})
	if layout.is_empty():
		return
	var marker := Node3D.new()
	marker.name = id
	marker.position = _grid(layout["at"] as Vector2i, layout["size"] as Vector2i)
	marker.set_meta("reach", float(layout["reach"]))
	add_child(marker)
	var packed = load(String(_MODELS.get(id, "")))
	if packed is PackedScene:
		marker.add_child((packed as PackedScene).instantiate())


func _grid(at: Vector2i, size: Vector2i) -> Vector3:
	# PartyUtils.convertDistanceFromPartyGrid, then PartyLoader's -10 shift.
	var px := float(at.x) * _CELL_X - _CELL_X * 18.0 / 2.0 + _CELL_X / 2.0
	var py := float(at.y) * _CELL_Y - _CELL_Y * 15.0 / 2.0 + _CELL_Y / 2.0
	if size.x % 2 == 0:
		px += _CELL_X / 2.0
	if size.y % 2 == 0:
		py += _CELL_Y / 2.0
	return Vector3(px + _GEOM_SHIFT_X, 0.0, -py)


func _open_activity(id: String) -> void:
	_hold(true)
	_clear()
	var card := _card(id)
	_text.text = String(card.get("name", "Activity"))
	_layer.visible = true
	if id == "cannon":
		_add("Fire the cannon", _cannon)
	elif id == "trampoline":
		_add("Bounce", _trampoline)
	elif id == "catch":
		_add("Catch jellybeans", _catch)
	elif id == "tug":
		_add("Heave", _tug)
	elif id == "cog":
		_add("Throw a pie", _cog)
	elif id == "fireworks":
		_add("Light the show", _fireworks)
	elif id == "jukebox":
		_add("Play a song", _jukebox)
	elif id == "dance":
		_add("Dance", _dance)
	_add("Close", _close)


func _pay(gain: int) -> int:
	var paid := gain * int(_HOLIDAYS.bean_scale("party"))
	if paid > 0:
		_BEANS.add_beans(paid)
	return paid


func _cannon() -> void:
	var earned := int(_party.get("cannon", 0))
	if earned >= 200:
		_text.text = "The cannon is out of jellybeans for this party."
		return
	var base := mini(2, 200 - earned)
	var gain := _pay(base)
	_party["cannon"] = earned + base
	_save()
	_text.text = "You landed in the beans and got %d jellybeans." % gain


func _trampoline() -> void:
	var bonus := 10 if randf() > 0.5 else 0
	var gain := _pay(12 + bonus)
	_text.text = "Nice bounce! %d jellybeans." % gain


func _catch() -> void:
	var earned := int(_party.get("catch", 0))
	if earned >= 1000:
		_text.text = "You cannot catch any more jellybeans at this party."
		return
	var base := mini(randi_range(4, 12), 1000 - earned)
	var gain := _pay(base)
	_party["catch"] = earned + base
	_save()
	_text.text = "You caught %d jellybeans." % gain


func _tug() -> void:
	var win := randf() > 0.45
	var gain := _pay(12 if win else 8)
	_text.text = "You won the tug! %d jellybeans." % gain if win else "You were pulled across. %d jellybeans." % gain


func _cog() -> void:
	# CogActivityBeansToAward is 27. A clean hit pays the perfect-win share.
	var gain := _pay(20 if randf() > 0.35 else 16)
	_text.text = "The cog is dizzy. %d jellybeans." % gain


func _fireworks() -> void:
	_text.text = "The sky fills with fireworks."


func show_fireworks(_show_name: String) -> void:
	_fireworks()


func _jukebox() -> void:
	_text.text = "The jukebox plays a party song."


func _dance() -> void:
	_text.text = "Everybody dance!"


func _close() -> void:
	_layer.visible = false
	_hold(false)
	_busy = false


func _add(caption: String, call: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(660, 36)
	button.pressed.connect(call)
	_buttons.add_child(button)


func _clear() -> void:
	for child in _buttons.get_children():
		child.queue_free()


func _body() -> Node3D:
	var host := get_parent()
	if host == null:
		return null
	return host.get_node_or_null("Player") as Node3D


func _hold(holding: bool) -> void:
	var host := get_parent()
	if host == null:
		return
	var toon := host.get_node_or_null("PlaygroundToon")
	if toon != null and toon.has_method("hold_for_race"):
		toon.call("hold_for_race", holding)


static func _card(id: String) -> Dictionary:
	for card in _ACTIVITIES:
		if String(card.get("id", "")) == id:
			return card
	return {}


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(_FILE):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_FILE))
	if parsed is Dictionary:
		_party = parsed


static func _save() -> void:
	var file := FileAccess.open(_FILE, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_party))
