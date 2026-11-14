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
static var _visit: Dictionary = {}
static var _loaded := false

const _CANNON := preload("res://scenes/parties/party_cannon.gd")
const _TRAMP := preload("res://scenes/parties/party_trampoline.gd")
const _CATCH := preload("res://scenes/parties/party_catch.gd")
const _TUG := preload("res://scenes/parties/party_tug.gd")
const _COG := preload("res://scenes/parties/party_cog.gd")
const _JUKEBOX := preload("res://scenes/parties/party_jukebox.gd")
const _DANCE := preload("res://scenes/parties/party_dance.gd")

const _STATION_OF := {
	0: "jukebox",
	1: "cannon",
	2: "trampoline",
	3: "catch",
	4: "dance",
	5: "tug",
	6: "fireworks",
	7: "clock",
	8: "jukebox",
	9: "dance",
	10: "cog",
	11: "trampoline",
	12: "catch",
	13: "trampoline",
	14: "cog",
	15: "dance",
	16: "dance",
	17: "jukebox",
	18: "jukebox",
	19: "trampoline",
}
const _ACT_MODEL := {
	11: "res://assets/parties/trampoline_victory.glb",
	12: "res://assets/parties/catch_winter.glb",
	13: "res://assets/parties/trampoline_winter.glb",
	14: "res://assets/parties/cog_winter.glb",
	15: "res://assets/parties/dance_valentine.glb",
	16: "res://assets/parties/dance_valentine_20.glb",
	17: "res://assets/parties/jukebox_valentine.glb",
	18: "res://assets/parties/jukebox_valentine_40.glb",
	19: "res://assets/parties/trampoline_valentine.glb",
}
const _DECOR_MODEL := {
	0: "res://assets/parties/decor/balloon_anvil.glb",
	1: "res://assets/parties/decor/balloon_stage.glb",
	2: "res://assets/parties/decor/bow.glb",
	3: "res://assets/parties/decor/cake.glb",
	4: "res://assets/parties/decor/castle.glb",
	5: "res://assets/parties/decor/gift_pile.glb",
	6: "res://assets/parties/decor/horn.glb",
	7: "res://assets/parties/decor/mardi_gras.glb",
	8: "res://assets/parties/decor/noise_makers.glb",
	9: "res://assets/parties/decor/pinwheel.glb",
	10: "res://assets/parties/decor/gag_globe.glb",
	11: "res://assets/parties/decor/bean_banner.glb",
	12: "res://assets/parties/decor/gag_cake.glb",
	13: "res://assets/parties/decor/heart_target.glb",
	14: "res://assets/parties/decor/heart_banner.glb",
	15: "res://assets/parties/decor/flying_heart.glb",
	16: "res://assets/parties/decor/hydra.glb",
	17: "res://assets/parties/decor/banner_victory.glb",
	18: "res://assets/parties/decor/cannon_victory.glb",
	19: "res://assets/parties/decor/cog_statue_victory.glb",
	20: "res://assets/parties/decor/tube_cog.glb",
	21: "res://assets/parties/decor/cog_ice_cream_victory.glb",
	22: "res://assets/parties/decor/cog_ice_cream_winter.glb",
	23: "res://assets/parties/decor/stage_winter.glb",
	24: "res://assets/parties/decor/cog_statue_winter.glb",
	25: "res://assets/parties/decor/snowman.glb",
	26: "res://assets/parties/decor/snow_doodle.glb",
	27: "res://assets/parties/decor/balloon_anvil_valentine.glb",
}
const _DECOR: PackedStringArray = [
	"Balloon Anvil", "Party Stage", "Party Bow", "Cake", "Party Castle",
	"Gift Pile", "Streamer Horn", "Party Gate", "Noise Makers", "Pinwheel",
	"Gag Globe", "Bean Banner", "Gag Cake", "Cupid's Heart", "Candy Hearts Banner",
	"Flying Heart", "Victory Bandstand", "Victory Banner", "Confetti Cannons",
	"Cog & Doodle", "Cog Flappy Man", "Cog Ice Cream", "CogCicle", "Holiday Bandstand",
	"Chilly Cog", "Snowman", "SnowDoodle", "ValenToons Anvil",
]

var gate := false
var _public_pick := ""
var _layer: CanvasLayer
var _text: Label
var _buttons: VBoxContainer
var _busy := false
var _gate := false
var _play: Node
var _wait_out := false


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
	if not active() and not visiting():
		return
	if host.get_node_or_null("PartyGrounds") != null:
		return
	var here: Node = load("res://scenes/parties/toon_party.gd").new()
	here.name = "PartyGrounds"
	host.add_child(here)


static func active() -> bool:
	_ensure()
	var now := Time.get_unix_time_from_system()
	return float(_party.get("until", 0.0)) > now and float(_party.get("start", 0.0)) <= now


static func hosting() -> bool:
	_ensure()
	return float(_party.get("until", 0.0)) > Time.get_unix_time_from_system()


static func visiting() -> bool:
	var now := Time.get_unix_time_from_system()
	return float(_visit.get("until", 0.0)) > now and float(_visit.get("start", 0.0)) <= now


static func begin_visit(state: Dictionary) -> void:
	_visit = {
		"until": float(state.get("until", 0.0)),
		"start": float(state.get("start", 0.0)),
		"layout": String(state.get("layout", "")),
		"cannon": 0,
		"catch": 0,
	}


static func clear_visit() -> void:
	_visit = {}


static func plan(ids: Array) -> String:
	_ensure()
	if hosting():
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
	var started := Time.get_unix_time_from_system()
	_party = {
		"until": started + _LENGTH,
		"start": started,
		"activities": chosen,
		"cannon": 0,
		"catch": 0,
	}
	_save()
	return "Your party has started. It lasts 30 minutes."


static func summary() -> String:
	_ensure()
	if not hosting():
		return "No party is planned. A party costs %d jellybeans plus activities." % _BASE
	var now := Time.get_unix_time_from_system()
	var start := float(_party.get("start", 0.0))
	var names := String(_party.get("summary", ""))
	if names == "":
		names = "Clock"
		for id in _party.get("activities", []):
			names += ", " + String(_card(String(id)).get("name", id))
	if start > now:
		var wait := int(start - now)
		return "Your party starts in %d:%02d.\n%s" % [wait / 60, wait % 60, names]
	var left := int(float(_party.get("until", 0.0)) - now)
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
	if _busy:
		return
	var body := _body()
	if body == null:
		return
	if _gate:
		if _beside_party_person(body):
			return
		var near := global_position.distance_to(body.global_position) <= 4.0
		if not near:
			_wait_out = false
			return
		if _wait_out:
			return
		_busy = true
		_open_planner()
		return
	var inside := false
	for child in get_children():
		if not (child is Node3D):
			continue
		var id := String(child.get_meta("act", ""))
		if id == "" or _card(id).is_empty():
			continue
		var marker := child as Node3D
		var reach := float(marker.get_meta("reach", 8.0))
		var flat := Vector2(body.global_position.x, body.global_position.z).distance_to(
			Vector2(marker.global_position.x, marker.global_position.z)
		)
		if flat > reach:
			continue
		inside = true
		if _wait_out:
			continue
		_busy = true
		_open_activity(id, marker)
		return
	if not inside:
		_wait_out = false


func _open_planner() -> void:
	_hold(true)
	_announce()
	_paint_gate()


func _paint_gate() -> void:
	_public_pick = ""
	_clear()
	_layer.visible = true
	if active():
		_text.text = summary()
		_add("Go to the Party Grounds", _go)
	elif hosting():
		_text.text = "You can only host one party at a time, sorry.\n" + summary()
	else:
		_text.text = "Toontown Party Planner\nHosting your own party is a lot of fun!"
		_add("Plan a Party", _open_editor)
	_add("Public Parties", _paint_public)
	_add("Close", _close)


func _open_editor() -> void:
	if hosting():
		_text.text = "You can only host one party at a time, sorry."
		return
	open_planner()


func open_planner() -> void:
	_hold(true)
	_layer.visible = false
	if get_node_or_null("PartyPlanner") != null:
		return
	var planner := load("res://scenes/parties/party_planner.gd").new() as Node
	planner.name = "PartyPlanner"
	add_child(planner)


func _beside_party_person(body: Node3D) -> bool:
	var host := get_parent()
	if host == null:
		return false
	for node in host.find_children("PartyPerson*", "StaticBody3D", true, false):
		var person := node as Node3D
		if person.global_position.distance_to(body.global_position) <= 2.4:
			return true
	return false


func _paint_public() -> void:
	_clear()
	_layer.visible = true
	_text.text = "Public Parties\nClick on a host, then click on \"Go to Party\""
	var now := Time.get_unix_time_from_system()
	var any := false
	for channel in ToonNet.channels("party:"):
		var row := ToonNet.latest(channel)
		var start := float(row.get("start", 0.0))
		var until := float(row.get("until", 0.0))
		if until <= now or start > now:
			continue
		any = true
		var mins := int((until - now) / 60.0)
		var mark := ">" if channel == _public_pick else " "
		var host := String(row.get("name", "A Toon"))
		var activities := String(row.get("activities", ""))
		_add("%s %s | %s | %d min" % [mark, host, activities, mins], _choose_public.bind(channel))
	if not any:
		_text.text = "Public Parties\nNobody is hosting a public party right now."
	if _public_pick != "":
		_add("Go to Party", _join_public)
	_add("Back", _paint_gate)


func _choose_public(channel: String) -> void:
	_public_pick = channel
	_paint_public()


func _join_public() -> void:
	var row := ToonNet.latest(_public_pick)
	var now := Time.get_unix_time_from_system()
	if float(row.get("until", 0.0)) <= now or float(row.get("start", 0.0)) > now:
		_text.text = "Sorry. That party is no longer available."
		_clear()
		_add("Back", _paint_public)
		return
	var host_id := int(_public_pick.trim_prefix("party:"))
	if host_id == ToonNet.peer_id():
		_go()
		return
	begin_visit(row)
	_travel()


func _go() -> void:
	clear_visit()
	_travel()


func _travel() -> void:
	_layer.visible = false
	_hold(false)
	_busy = true
	var arrival = load("res://scenes/playgrounds/playground_toon.gd")
	arrival.teleport_in = true
	_LOADING.change_to(_GROUNDS)


func _stations() -> void:
	if visiting():
		_place_layout(String(_visit.get("layout", "")))
		return
	_ensure()
	var layout := String(_party.get("layout", ""))
	if layout != "":
		_place_layout(layout)
		return
	_spot("clock")
	for id in _party.get("activities", []):
		_spot(String(id))


func _place_layout(layout: String) -> void:
	for piece in layout.split(",", false):
		var bits := piece.split(":")
		if bits.size() < 6:
			continue
		var at := Vector2i(int(bits[2]), 14 - int(bits[3]))
		var size := Vector2i(int(bits[4]), int(bits[5]))
		_spot_at(String(bits[0]), int(bits[1]), at, size)


func _spot(id: String) -> void:
	var layout: Dictionary = _LAYOUT.get(id, {})
	if layout.is_empty():
		return
	var marker := Node3D.new()
	marker.name = id
	marker.position = _grid(layout["at"] as Vector2i, layout["size"] as Vector2i)
	marker.set_meta("reach", float(layout["reach"]))
	marker.set_meta("act", id)
	if id == "jukebox":
		marker.set_meta("act_id", 0)
	elif id == "dance":
		marker.set_meta("act_id", 4)
	elif id == "fireworks":
		marker.set_meta("act_id", 6)
	add_child(marker)
	var packed = load(String(_MODELS.get(id, "")))
	if packed is PackedScene:
		marker.add_child((packed as PackedScene).instantiate())


func _spot_at(kind: String, id: int, at: Vector2i, size: Vector2i) -> void:
	var station := ""
	if kind == "a":
		station = String(_STATION_OF.get(id, ""))
	var marker := Node3D.new()
	marker.name = "spot_%d_%d_%d" % [id, at.x, at.y]
	marker.position = _grid(at, size)
	marker.set_meta("reach", float(maxi(size.x, size.y)) * 4.0 + 6.0)
	if station != "" and station != "clock":
		marker.set_meta("act", station)
	marker.set_meta("act_id", id)
	add_child(marker)
	var model_path := ""
	if kind == "a":
		model_path = String(_ACT_MODEL.get(id, ""))
		if model_path == "" and station != "" and _MODELS.has(station):
			model_path = String(_MODELS[station])
	elif kind == "d":
		model_path = String(_DECOR_MODEL.get(id, ""))
	if model_path != "":
		var packed = load(model_path)
		if packed is PackedScene:
			marker.add_child((packed as PackedScene).instantiate())
			return
	if kind != "d" or id < 0 or id >= _DECOR.size():
		return
	var label := Label3D.new()
	label.text = String(_DECOR[id])
	label.font_size = 64
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 12
	label.modulate = Color(1, 0.9, 0.95)
	label.position = Vector3(0, 2.2, 0)
	marker.add_child(label)


func _grid(at: Vector2i, size: Vector2i) -> Vector3:
	# PartyUtils.convertDistanceFromPartyGrid, then PartyLoader's -10 shift.
	var px := float(at.x) * _CELL_X - _CELL_X * 18.0 / 2.0 + _CELL_X / 2.0
	var py := float(at.y) * _CELL_Y - _CELL_Y * 15.0 / 2.0 + _CELL_Y / 2.0
	if size.x % 2 == 0:
		px += _CELL_X / 2.0
	if size.y % 2 == 0:
		py += _CELL_Y / 2.0
	return Vector3(px + _GEOM_SHIFT_X, 0.0, -py)


func holds_camera() -> bool:
	return _play != null and is_instance_valid(_play) and _play.has_method("holds_camera") and bool(_play.call("holds_camera"))


func aim(camera: Camera3D) -> void:
	if holds_camera():
		_play.call("aim", camera)


func _open_activity(id: String, marker: Node3D) -> void:
	_hold(true)
	if id == "cannon" or id == "trampoline" or id == "catch" or id == "tug" or id == "cog" or id == "jukebox" or id == "dance" or id == "fireworks":
		_begin(id, marker)
		return
	_clear()
	var card := _card(id)
	_text.text = String(card.get("name", "Activity"))
	_layer.visible = true
	_add("Close", _close)


func _begin(id: String, marker: Node3D) -> void:
	var body := _body() as ToonActor
	if body == null:
		_close()
		return
	var book := _bean_book()
	if id == "cannon" and int(book.get("cannon", 0)) >= 200:
		_show_note("The cannon is out of jellybeans for this party.")
		return
	if id == "catch" and int(book.get("catch", 0)) >= 1000:
		_show_note("You cannot catch any more jellybeans at this party.")
		return
	var origin := body.global_position
	if marker != null:
		origin = marker.global_position
	if id == "fireworks":
		_launch_fireworks(origin, book)
		return
	if id == "jukebox":
		var playing := get_node_or_null("PartyJukebox")
		if playing != null:
			playing.call("open_gui")
			_play = playing
			return
	var script: Script = _CANNON
	if id == "trampoline":
		script = _TRAMP
	elif id == "catch":
		script = _CATCH
	elif id == "tug":
		script = _TUG
	elif id == "cog":
		script = _COG
	elif id == "jukebox":
		script = _JUKEBOX
	elif id == "dance":
		script = _DANCE
	var play := script.new() as Node
	play.name = "PartyJukebox" if id == "jukebox" else "PartyPlay"
	if marker != null:
		play.set_meta("act_id", int(marker.get_meta("act_id", 0)))
	add_child(play)
	_play = play
	if play.has_signal("finished"):
		play.finished.connect(_played)
	if play.has_signal("closed"):
		play.closed.connect(_release)
	play.call("setup", body, origin, book)


func _played(base_beans: int, message: String) -> void:
	_play = null
	if not visiting():
		_save()
	var paid := _pay(base_beans)
	if message == "":
		_close()
		return
	if message.contains("%d"):
		message = message % paid
	_show_note(message)


func _show_note(message: String) -> void:
	_clear()
	_text.text = message
	_layer.visible = true
	_add("Close", _close)


func _pay(gain: int) -> int:
	var paid := gain * int(_HOLIDAYS.bean_scale("party"))
	if paid > 0:
		_BEANS.add_beans(paid)
	return paid


func _launch_fireworks(_origin: Vector3, book: Dictionary) -> void:
	if visiting():
		_show_note("Only the host can start this activity. Sorry.")
		return
	if bool(book.get("fireworks_done", false)):
		_show_note("The fireworks show is over.")
		return
	var host := get_parent()
	if host != null and host.get_node_or_null("FireworkShow") != null:
		_show_note("The fireworks show has already started.")
		return
	book["fireworks_done"] = true
	if not visiting():
		_save()
	var at := int(Time.get_unix_time_from_system())
	ToonNet.share_dev("fireworks", {"show": "summer", "at": at, "delay": 5})
	if host != null and host.has_method("show_fireworks"):
		host.call("show_fireworks", "summer", at, 5.0)
	_release()


func _release() -> void:
	_play = null
	_layer.visible = false
	_hold(false)
	_busy = false
	_wait_out = true


func _close() -> void:
	_layer.visible = false
	_hold(false)
	_busy = false
	_wait_out = true


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


func commit_party(items: Array, guests: Array, is_public: bool, when_unix: float, theme: String) -> String:
	_ensure()
	if hosting():
		return "Sorry, you are already hosting a party.\nIf you want to plan another party, please\ncancel your current party."
	var cost := 0
	var layout := ""
	var activities: Array = []
	var seen := {}
	var summary_text := ""
	var seen_name := {}
	var guest_ids: Array = []
	var guest_names: Array = []
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		var kind := String(row.get("kind", "a"))
		var id := int(row.get("id", 0))
		var piece := "%s:%d:%d:%d:%d:%d" % [kind, id, int(row.get("x", 0)), int(row.get("y", 0)), int(row.get("w", 1)), int(row.get("h", 1))]
		if layout != "":
			layout += ","
		layout += piece
		cost += int(row.get("cost", 0))
		var station := String(row.get("station", ""))
		if station != "" and station != "clock" and not bool(seen.get(station, false)):
			seen[station] = true
			activities.append(station)
		var invite := String(row.get("invite", ""))
		if kind == "a" and invite != "" and not bool(seen_name.get(invite, false)):
			seen_name[invite] = true
			if summary_text != "":
				summary_text += ", "
			summary_text += invite
	for guest in guests:
		if typeof(guest) != TYPE_DICTIONARY:
			continue
		var who: Dictionary = guest
		guest_ids.append(String(who.get("id", "")))
		guest_names.append(String(who.get("name", "")))
	if cost < _BASE:
		return "It costs a minimum of %d jellybeans to plan a party." % _BASE
	if not _BEANS.take_beans(cost, true):
		return "You need %d jellybeans." % cost
	_party = {
		"until": when_unix + _LENGTH,
		"start": when_unix,
		"activities": activities,
		"layout": layout,
		"summary": summary_text,
		"cannon": 0,
		"catch": 0,
		"public": is_public,
		"theme": theme,
		"host": ToonRoster.selected_style().display_name(),
		"guests": guest_ids,
		"guest_names": guest_names,
	}
	_save()
	_announce()
	return ""


func _announce() -> void:
	_ensure()
	if String(_party.get("host", "")) == "" and float(_party.get("until", 0.0)) <= 0.0:
		return
	var until := float(_party.get("until", 0.0))
	if not bool(_party.get("public", false)):
		until = 0.0
	ToonNet.share_party({
		"name": String(_party.get("host", "")),
		"start": float(_party.get("start", 0.0)),
		"until": until,
		"activities": String(_party.get("summary", "")),
		"layout": String(_party.get("layout", "")),
	})


static func _bean_book() -> Dictionary:
	if visiting():
		return _visit
	return _party


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
