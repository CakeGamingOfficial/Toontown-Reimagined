extends Node

## Race pads, kart stands, and the three central leaderboards on Goofy Speedway.
## A pad's sign changes track every 15 seconds until a toon is waiting.
## Toon Battle and Grand Prix still need two racers, the same as considerAllAboard.

const _RULES := preload("res://scenes/racing/kart_rules.gd")
const _GARAGE := preload("res://scenes/racing/kart_garage.gd")
const _MODEL := preload("res://scenes/racing/kart_model.gd")
const _RACE := preload("res://scenes/racing/kart_race.gd")
const _GUI := preload("res://scenes/toons/toon_gui.gd")
const _LAYOUT := "res://assets/racing/speedway.json"

const _LISTS := {
	"stadium": [0, 1, 60, 61],
	"country": [20, 21, 62, 63],
	"city": [40, 41, 64, 65],
}

static var _drop: Dictionary = {}

var _pads: Array[Dictionary] = []
var _boards: Array[Dictionary] = []
var _board_left := 0.0
var _board_step := 0
var _layer: CanvasLayer
var _prompt: Label
var _yes: Button
var _no: Button
var _busy := false
var _near := false
var _cancel := false
var _shown: Node3D
var _hidden: Node3D


static func place(host: Node) -> void:
	if host.get_node_or_null("SpeedwayRacing") != null:
		return
	var here: Node = load("res://scenes/racing/speedway_racing.gd").new()
	here.name = "SpeedwayRacing"
	host.add_child(here)


static func park_return(point: Vector3, heading: float) -> void:
	_drop = {"point": point, "heading": heading}


static func take_drop() -> Dictionary:
	var found := _drop
	_drop = {}
	return found


func _ready() -> void:
	_read_layout()
	_build_prompt()


func _process(delta: float) -> void:
	for pad in _pads:
		if int(pad.get("waiting", -1)) >= 0:
			continue
		pad["left"] = float(pad.get("left", _RULES.SIGN_TIME)) - delta
		if float(pad["left"]) <= 0.0:
			pad["left"] = _RULES.SIGN_TIME
			var picked: Dictionary = _RULES.next_track(int(pad.get("track", -1)), String(pad.get("genre", "")), int(pad.get("index", 0)))
			pad["track"] = int(picked.get("track", 0))
			pad["type"] = int(picked.get("type", 0))
		var sign := pad.get("sign") as Label3D
		if sign != null:
			sign.text = "%s\n%s" % [_RULES.track_name(int(pad.get("track", 0))), _RULES.RACE_NAMES[int(pad.get("type", 0))]]
	_board_left -= delta
	if _board_left <= 0.0:
		_board_left = 10.0
		_board_step += 1
		_paint_boards()
	if _busy:
		return
	var body := _body()
	if body == null:
		return
	var hit := _closest(body.global_position)
	if hit.is_empty():
		_near = false
		return
	if _near:
		return
	_near = true
	_offer(hit)


func _offer(hit: Dictionary) -> void:
	_busy = true
	_hold(true)
	_clear_buttons()
	var viewing := bool(hit.get("viewing", false))
	var text := "Would you like to park your car here?"
	if not viewing:
		var race_type := int(hit.get("type", 0))
		if race_type == _RULES.PRACTICE:
			text = "Would you like to enter a practice race?"
		else:
			text = "Would you like to enter a %s race for %s tickets?" % [
				_RULES.RACE_NAMES[race_type], _RULES.entry_fee(int(hit.get("track", 0)), race_type),
			]
	_prompt.text = text
	_layer.visible = true
	_yes.pressed.connect(_accept.bind(hit), CONNECT_ONE_SHOT)
	_no.pressed.connect(_decline, CONNECT_ONE_SHOT)


func _accept(hit: Dictionary) -> void:
	_layer.visible = false
	if bool(hit.get("viewing", false)):
		_park(hit)
		return
	if not _GARAGE.has_kart():
		_say("You need a kart first! Try asking one of the clerks in the Kart Shop.")
		return
	var fee := _RULES.entry_fee(int(hit.get("track", 0)), int(hit.get("type", 0)))
	if _GARAGE.tickets() < fee:
		_say("You don't have enough tickets! Try a practice race instead.")
		return
	var pad: Dictionary = hit.get("pad", {})
	pad["waiting"] = 1
	_wait_out(hit)


func _decline() -> void:
	_release_pad()
	_layer.visible = false
	_hold(false)
	_busy = false


func _release_pad() -> void:
	for pad in _pads:
		pad["waiting"] = -1


func _clear_buttons() -> void:
	for link in _yes.pressed.get_connections():
		_yes.pressed.disconnect(link["callable"])
	for link in _no.pressed.get_connections():
		_no.pressed.disconnect(link["callable"])


func _say(text: String) -> void:
	_clear_buttons()
	_prompt.text = text
	_yes.visible = false
	_layer.visible = true
	_no.text = "OK"
	_no.pressed.connect(func() -> void:
		_no.text = "No"
		_yes.visible = true
		_decline()
	, CONNECT_ONE_SHOT)


func _wait_out(hit: Dictionary) -> void:
	var left := _RULES.COUNTDOWN
	_cancel = false
	_clear_buttons()
	_no.pressed.connect(func() -> void:
		_cancel = true
	, CONNECT_ONE_SHOT)
	while left > 0.0 and is_inside_tree() and not _cancel:
		_prompt.text = "%s\nRace begins in %d" % [_RULES.track_name(int(hit.get("track", 0))), int(ceil(left))]
		_yes.visible = false
		_no.text = "Exit"
		_layer.visible = true
		await get_tree().create_timer(0.25).timeout
		left -= 0.25
	if not is_inside_tree():
		return
	_yes.visible = true
	_no.text = "No"
	if _cancel:
		_decline()
		return
	if int(hit.get("type", 0)) != _RULES.PRACTICE:
		_say("Toon Battle and Grand Prix races require two or more racers.")
		return
	_prompt.text = "Going to the Race!"
	await get_tree().create_timer(_RULES.ENTER_RACE).timeout
	if not is_inside_tree():
		return
	var spot: Vector3 = hit.get("pos", Vector3.ZERO)
	var back := Vector3(sin(deg_to_rad(float(hit.get("heading", 0.0)))), 0.0, cos(deg_to_rad(float(hit.get("heading", 0.0))))) * 4.0
	_RACE.launch(int(hit.get("track", 0)), int(hit.get("type", 0)), _RULES.LAPS, spot + back, float(hit.get("heading", 0.0)))


func _park(hit: Dictionary) -> void:
	if not _GARAGE.has_kart():
		_say("You need a kart first! Try asking one of the clerks in the Kart Shop.")
		return
	_clear_buttons()
	_clear_show()
	_shown = _MODEL.build()
	add_child(_shown)
	var at: Vector3 = hit.get("pos", Vector3.ZERO)
	_shown.global_position = at + Vector3.UP * 0.2
	_shown.rotation.y = deg_to_rad(-float(hit.get("heading", 0.0)))
	var body := _body()
	if body != null:
		for child in body.get_children():
			if child is ToonActor:
				_hidden = child
				_hidden.visible = false
	_prompt.text = "Parked."
	_yes.visible = false
	_no.text = "Exit"
	_layer.visible = true
	_no.pressed.connect(func() -> void:
		_clear_show()
		_no.text = "No"
		_yes.visible = true
		_decline()
	, CONNECT_ONE_SHOT)


func _clear_show() -> void:
	if _shown != null and is_instance_valid(_shown):
		_shown.queue_free()
	_shown = null
	if _hidden != null and is_instance_valid(_hidden):
		_hidden.visible = true
	_hidden = null


func _read_layout() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_LAYOUT))
	if not (parsed is Array):
		return
	var current: Dictionary = {}
	for item in parsed as Array:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		var name := String(row.get("name", ""))
		var pos_row: Array = row.get("pos", [0, 0, 0])
		var pos := Vector3(float(pos_row[0]), float(pos_row[1]), float(pos_row[2]))
		var heading := float(row.get("heading", 0.0))
		if name.begins_with("racing_pad") or name.begins_with("viewing_pad"):
			var parts := name.split("_")
			var index := int(parts[2]) if parts.size() > 2 and name.begins_with("racing") else 0
			var genre_name := parts[3] if parts.size() > 3 else ""
			var picked: Dictionary = _RULES.next_track(-1, genre_name, index)
			current = {
				"name": name,
				"index": index,
				"genre": genre_name,
				"viewing": name.begins_with("viewing"),
				"track": int(picked.get("track", 0)),
				"type": int(picked.get("type", 0)),
				"left": _RULES.SIGN_TIME,
				"blocks": [],
			}
			_pads.append(current)
			if not bool(current["viewing"]):
				var sign := Label3D.new()
				sign.font = _GUI.sign_font()
				sign.font_size = 48
				sign.pixel_size = 0.025
				sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				sign.modulate = Color(0.05, 0.2, 0.55)
				sign.outline_modulate = Color.WHITE
				sign.text = _RULES.track_name(int(current["track"]))
				add_child(sign)
				current["sign"] = sign
		elif name.begins_with("starting_block") and not current.is_empty():
			var blocks: Array = current.get("blocks", [])
			blocks.append({"pos": pos, "heading": heading, "viewing": bool(current.get("viewing", false)), "track": current.get("track", 0), "type": current.get("type", 0), "pad": current})
			current["blocks"] = blocks
			var sign := current.get("sign") as Label3D
			if sign != null and blocks.size() == 1:
				sign.global_position = pos + Vector3.UP * 7.0
		elif name == "leaderBoard_stadium" or name == "leaderBoard_city" or name == "leaderBoard_country":
			var kind := "stadium"
			if name.ends_with("city"):
				kind = "city"
			elif name.ends_with("country"):
				kind = "country"
			var label := Label3D.new()
			label.font = _GUI.sign_font()
			label.font_size = 32
			label.pixel_size = 0.012
			label.modulate = Color(0.15, 0.45, 0.4)
			label.outline_size = 8
			label.outline_modulate = Color.WHITE
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			label.global_position = pos + Vector3.UP * 4.5
			label.rotation.y = deg_to_rad(-heading)
			add_child(label)
			_boards.append({"label": label, "kind": kind})
	_paint_boards()


func _paint_boards() -> void:
	for board in _boards:
		var label := board.get("label") as Label3D
		var tracks: Array = _LISTS.get(String(board.get("kind", "stadium")), [])
		if label == null or tracks.is_empty():
			continue
		var slot := posmod(_board_step, tracks.size() * 3)
		var track_id := int(tracks[slot / 3])
		var period := slot % 3
		var lines := "%s\n%s" % [_RULES.track_name(track_id), _RULES.PERIOD_NAMES[period]]
		var place := 1
		for row in _GARAGE.board(track_id, period):
			if row is Array and (row as Array).size() >= 4:
				var record: Array = row
				lines += "\n%d. %s  %s" % [place, String(record[3]), _RULES.clock(float(record[0]))]
				place += 1
		label.text = lines


func _closest(at: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_d := 2.4
	for pad in _pads:
		var blocks: Array = pad.get("blocks", [])
		for block in blocks:
			if not (block is Dictionary):
				continue
			var row: Dictionary = block
			var pos: Vector3 = row.get("pos", Vector3.ZERO)
			var flat := Vector2(at.x, at.z).distance_to(Vector2(pos.x, pos.z))
			if flat < best_d and absf(at.y - pos.y) < 4.0:
				best_d = flat
				best = row.duplicate()
				best["track"] = pad.get("track", 0)
				best["type"] = pad.get("type", 0)
				best["viewing"] = pad.get("viewing", false)
	return best


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


func _build_prompt() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 30
	_layer.visible = false
	add_child(_layer)
	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.2, 0.45, 0.92)
	panel.position = Vector2(360, 220)
	panel.size = Vector2(640, 220)
	_layer.add_child(panel)
	_prompt = Label.new()
	_prompt.position = Vector2(16, 16)
	_prompt.size = Vector2(608, 120)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_GUI.style_label(_prompt, Color.WHITE, 22, Color.BLACK, 3)
	panel.add_child(_prompt)
	_yes = Button.new()
	_yes.text = "Yes"
	_yes.position = Vector2(150, 150)
	_yes.size = Vector2(140, 44)
	panel.add_child(_yes)
	_no = Button.new()
	_no.text = "No"
	_no.position = Vector2(350, 150)
	_no.size = Vector2(140, 44)
	panel.add_child(_no)
