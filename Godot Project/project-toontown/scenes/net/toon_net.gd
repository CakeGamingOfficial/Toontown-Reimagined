extends Node
class_name ToonNet

## One district AI, the way ToontownAIRepository hosts a shard. Offline play is
## that AI and the client in the same process. ~district host opens an ENet
## server so other players can join. Clients apply published state. They do
## not roll cogs, battles, or the trolley game.
##
## A headless launch, or --server after --, is a dedicated district. It listens
## on UDP and does not take a player slot. Windows clients use Connect.
##
## districts.json is the list of AI processes this server stands in for.
## Welcome Valley is district 0, inside whichever shard you entered it from.
## Quiet is 399 toons or fewer, Ideal is 599, and a fuller district is closed.

signal districts_changed
signal district_rejected(reason: String)
## The seat this client asked for. Population updates do not emit this.
signal district_seated(id: int)
signal state_changed(channel: String)

const WELCOME_VALLEY := 0
const LOW_POP := 399
const MID_POP := 599
const _PORT := 4343
const _TROLLEY: Array[int] = [2, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15]
const _CONFIG := "res://scenes/net/districts.json"

var _districts: Array[Dictionary] = []
var _here := 1
var _parent := 1
var _welcome := false
var _role := "offline"
var _states: Dictionary = {}
var _peers: Dictionary = {}
var _next_id := 1
var _port := _PORT
var _dedicated := false
var _status := ""
## RequestMinigame, keyed by the peer who typed ~mg. 0 is the offline player.
var _trolley_for: Dictionary = {}


func _ready() -> void:
	_load_config()
	_apply_server_args()
	_recount()
	var link := multiplayer
	link.peer_connected.connect(_on_peer)
	link.peer_disconnected.connect(_on_peer_gone)
	link.connected_to_server.connect(_on_connected)
	link.connection_failed.connect(_on_failed)
	link.server_disconnected.connect(_on_dropped)
	if _wants_dedicated():
		_become_dedicated()


static func live() -> ToonNet:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ToonNetwork") as ToonNet


static func is_authority() -> bool:
	var net := live()
	if net == null:
		return true
	return net._role != "client"


static func networked() -> bool:
	var net := live()
	return net != null and net._role != "offline"


static func is_welcome() -> bool:
	var net := live()
	return net != null and net._welcome


static func district_id() -> int:
	var net := live()
	if net == null:
		return 1
	if net._welcome:
		return WELCOME_VALLEY
	return net._here


static func district_name() -> String:
	var net := live()
	if net == null:
		return "Sillyville"
	return net._seat_name()


static func next_id() -> int:
	var net := live()
	if net == null:
		return 1
	net._next_id += 1
	return net._next_id


static func peer_id() -> int:
	var net := live()
	if net == null or net._role == "offline":
		return 1
	return net.multiplayer.get_unique_id()


static func publish(channel: String, state: Dictionary) -> void:
	var net := live()
	if net == null or not is_authority():
		return
	net._store(channel, state)


## A client owns its own toon. The district AI relays that pose to everyone else.
static func submit(channel: String, state: Dictionary) -> void:
	var net := live()
	if net == null or net._role == "offline":
		return
	var packed := net._pack(state) as Dictionary
	if net._role == "client":
		net._submit_state.rpc_id(1, channel, packed)
		return
	net._store(channel, packed)


static func channels(prefix: String) -> PackedStringArray:
	var found := PackedStringArray()
	var net := live()
	if net == null:
		return found
	for key in net._states.keys():
		var channel := String(key)
		if channel.begins_with(prefix):
			found.append(channel)
	return found


static func latest(channel: String) -> Dictionary:
	var net := live()
	if net == null:
		return {}
	var found: Variant = net._states.get(channel, {})
	if found is Dictionary:
		return found
	return {}


static func where_text() -> String:
	var net := live()
	if net == null:
		return "You are currently in the \"Sillyville\" District."
	return net._where_text()


static func roster_text() -> String:
	var net := live()
	if net == null:
		return ""
	return net._roster_text()


static func join_named(district_name: String) -> String:
	var net := live()
	if net == null:
		return "Districts are not running."
	return net._join_named(district_name)


static func district_rows() -> Array[Dictionary]:
	var net := live()
	if net == null:
		return []
	var copy: Array[Dictionary] = []
	for row in net._sorted():
		copy.append(row.duplicate())
	return copy


static func population_word(count: int) -> String:
	var net := live()
	if net == null:
		return "Quiet"
	return net._pop_text(count)


static func population_color(count: int) -> Color:
	if count <= LOW_POP:
		return Color(0.4, 0.4, 1.0)
	if count <= MID_POP:
		return Color(0.4, 1.0, 0.4)
	return Color(1.0, 0.4, 0.4)


static func open_district(district_name: String) -> String:
	var net := live()
	if net == null:
		return "Districts are not running."
	return net._open_district(district_name)


static func is_dedicated() -> bool:
	var net := live()
	return net != null and net._dedicated


static func status_text() -> String:
	var net := live()
	if net == null:
		return ""
	return net._status


static func listen_port() -> int:
	var net := live()
	if net == null:
		return _PORT
	return net._port


static func host_game(port: int) -> String:
	var net := live()
	if net == null:
		return "Districts are not running."
	return net._host_game(port)


static func join_server(address: String, port: int) -> String:
	var net := live()
	if net == null:
		return "Districts are not running."
	return net._join_server(address, port)


static func disconnect_net() -> String:
	var net := live()
	if net == null:
		return "Districts are not running."
	return net._disconnect_net()


static func self_peer() -> int:
	var net := live()
	if net == null or net._role == "offline":
		return 0
	return net.multiplayer.get_unique_id()


static func reserve_trolley(game_id: int) -> void:
	var net := live()
	if net != null:
		net._reserve_trolley(game_id)


static func ask_summon(district: int, slug: String, query: String, level: int, near: Vector3) -> void:
	var net := live()
	if net != null:
		net._ask_summon(district, slug, query, level, near)


static func begin_trolley(avoid: int) -> int:
	var net := live()
	if net == null:
		return 0
	return net._begin_trolley(avoid)


static func finish_trolley(score: int) -> void:
	var net := live()
	if net != null:
		net._finish_trolley(score)


static func request_suits(district: int, slug: String) -> void:
	var net := live()
	if net != null:
		net._request_suits(district, slug)


func _wants_dedicated() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	for arg in OS.get_cmdline_user_args():
		if arg == "--server":
			return true
	return false


func _apply_server_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		var arg := String(args[index])
		var port_text := ""
		if arg == "--port" and index + 1 < args.size():
			port_text = String(args[index + 1])
		elif arg.begins_with("--port="):
			port_text = arg.trim_prefix("--port=")
		if port_text.is_valid_int():
			var port := int(port_text)
			if port >= 1 and port <= 65535:
				_port = port


func _become_dedicated() -> void:
	_dedicated = true
	var result := _host_game(_port)
	var names: PackedStringArray = []
	for row in _districts:
		names.append(String(row["name"]))
	if not result.begins_with("Hosting"):
		_status = result
		print(result)
		get_tree().quit(1)
		return
	_status = "Dedicated server listening on UDP port %d.\nDistricts: %s\n%s\nStop this process to close the server." % [_port, ", ".join(names), _address_block()]
	print(_status)


func _address_block() -> String:
	var lines: PackedStringArray = []
	for raw in IP.get_local_addresses():
		var address := String(raw)
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254.") or address == "0.0.0.0":
			continue
		if lines.has(address):
			continue
		lines.append(address)
	if lines.is_empty():
		return "No LAN address was found. Clients on this machine can use 127.0.0.1."
	return "Clients connect to:\n" + "\n".join(lines)


func _load_config() -> void:
	_districts.clear()
	var names: Array[String] = ["Sillyville"]
	if FileAccess.file_exists(_CONFIG):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_CONFIG))
		if parsed is Dictionary:
			var data: Dictionary = parsed
			_port = int(data.get("port", _PORT))
			var listed: Variant = data.get("districts", [])
			if listed is Array and not (listed as Array).is_empty():
				names.clear()
				for item in listed as Array:
					var district_name := String(item).strip_edges()
					if district_name != "":
						names.append(district_name)
	var next := 1
	for district_name in names:
		_districts.append(_blank(next, district_name))
		next += 1
	_here = int(_districts[0]["id"])
	_parent = _here


func _blank(id: int, district_name: String) -> Dictionary:
	return {
		"id": id,
		"name": district_name,
		"available": true,
		"avatar_count": 0,
		"new_avatar_count": 0,
	}


func _store(channel: String, state: Dictionary) -> void:
	var packed := _pack(state) as Dictionary
	_states[channel] = packed
	state_changed.emit(channel)
	if _role == "host":
		_receive_state.rpc(channel, packed)


func _where_text() -> String:
	if _welcome:
		return "You are currently in the \"Welcome Valley\" District, within \"%s\"." % _name_of(_parent)
	return "You are currently in the \"%s\" District." % _seat_name()


func _roster_text() -> String:
	var lines: PackedStringArray = []
	for row in _sorted():
		var marker := ""
		if int(row["id"]) == _seat_id():
			marker = "  (you are here)"
		lines.append("%s   %s%s" % [String(row["name"]), _pop_text(int(row["avatar_count"])), marker])
	return "\n".join(lines)


func _sorted() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var welcome_count := -1
	for row in _districts:
		if int(row.get("id", -1)) == WELCOME_VALLEY:
			welcome_count = int(row.get("avatar_count", 0))
			continue
		if bool(row.get("available", false)):
			rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["name"]) < String(b["name"])
	)
	# The host counts Welcome Valley itself. Clients use the number it sent.
	if _role != "client" or welcome_count < 0:
		welcome_count = _welcome_pop()
	rows.append({
		"id": WELCOME_VALLEY,
		"name": "Welcome Valley",
		"available": true,
		"avatar_count": welcome_count,
		"new_avatar_count": 0,
	})
	return rows


func _welcome_pop() -> int:
	var total := 0
	if _welcome:
		total += 1
	for peer in _peers:
		if int(_peers[peer]) == WELCOME_VALLEY:
			total += 1
	return total


func _pop_text(count: int) -> String:
	if count <= LOW_POP:
		return "Quiet"
	if count <= MID_POP:
		return "Ideal"
	return "Full"


func _full(id: int) -> bool:
	if id == WELCOME_VALLEY:
		return false
	return _count_of(id) > MID_POP


func _count_of(id: int) -> int:
	for row in _districts:
		if int(row["id"]) == id:
			return int(row["avatar_count"])
	return 0


func _seat_id() -> int:
	if _welcome:
		return WELCOME_VALLEY
	return _here


func _seat_name() -> String:
	if _welcome:
		return "Welcome Valley"
	return _name_of(_here)


func _name_of(id: int) -> String:
	if id == WELCOME_VALLEY:
		return "Welcome Valley"
	for row in _districts:
		if int(row["id"]) == id:
			return String(row["name"])
	return "Sillyville"


func _join_named(district_name: String) -> String:
	var wanted := district_name.strip_edges()
	if wanted == "":
		return _where_text()
	if wanted.to_lower() == "welcome valley":
		return _join_id(WELCOME_VALLEY)
	for row in _districts:
		if String(row["name"]).to_lower() == wanted.to_lower():
			return _join_id(int(row["id"]))
	return "Unknown district \"%s\"." % wanted


func _join_id(id: int) -> String:
	if not _known(id):
		return "Unknown district."
	if _full(id) and id != _seat_id():
		return "Sorry, that district is full. Please try another one."
	if _role == "client":
		_request_join.rpc_id(1, id)
		return "Asking to enter the %s District." % _name_of(id)
	return _take_seat(0, id)


func _known(id: int) -> bool:
	if id == WELCOME_VALLEY:
		return true
	for row in _districts:
		if int(row["id"]) == id:
			return true
	return false


func _take_seat(peer: int, id: int) -> String:
	if _full(id) and not (peer == 0 and id == _seat_id()):
		return "Sorry, that district is full. Please try another one."
	if peer == 0:
		if id == WELCOME_VALLEY:
			if not _welcome:
				_parent = _here
			_welcome = true
		else:
			_welcome = false
			_here = id
			_parent = id
	else:
		_peers[peer] = id
	_recount()
	_broadcast()
	districts_changed.emit()
	if peer == 0:
		return "You are in the %s District." % _seat_name()
	return ""


func _open_district(district_name: String) -> String:
	if not is_authority():
		return "Only the district AI can open a district."
	var clean := district_name.strip_edges()
	if clean == "":
		return "Name the district."
	for row in _districts:
		if String(row["name"]).to_lower() == clean.to_lower():
			return "%s is already open." % String(row["name"])
	var id := 1
	for row in _districts:
		id = maxi(id, int(row["id"]) + 1)
	_districts.append(_blank(id, clean))
	_recount()
	_broadcast()
	districts_changed.emit()
	return "Opened the %s District." % clean


func _host_game(port: int) -> String:
	if _role == "host":
		return "Already hosting on port %d." % _port
	if _role == "client":
		return "Leave the server with ~district close before hosting."
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 128)
	if err != OK:
		return "Could not host on port %d." % port
	_port = port
	multiplayer.multiplayer_peer = peer
	_role = "host"
	_recount()
	if _dedicated:
		return "Hosting %d districts on UDP port %d." % [_districts.size(), port]
	return "Hosting %d districts on port %d. You are in %s." % [_districts.size(), port, _seat_name()]


func _join_server(address: String, port: int) -> String:
	if _role != "offline":
		return "Leave the current server with ~district close first."
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return "Could not join %s:%d." % [address, port]
	multiplayer.multiplayer_peer = peer
	_role = "client"
	return "Joining %s:%d." % [address, port]


func _disconnect_net() -> String:
	if _role == "offline":
		return "You are already on the local district."
	multiplayer.multiplayer_peer = null
	_role = "offline"
	_peers.clear()
	_recount()
	districts_changed.emit()
	return "Back on the local district, %s." % _seat_name()


func _recount() -> void:
	if _role == "client":
		return
	for row in _districts:
		row["avatar_count"] = 0
		row["new_avatar_count"] = 0
	if not _dedicated:
		_add_pop(_seat_id())
	for peer in _peers:
		_add_pop(int(_peers[peer]))


func _add_pop(id: int) -> void:
	if id == WELCOME_VALLEY:
		return
	for row in _districts:
		if int(row["id"]) == id:
			row["avatar_count"] = int(row["avatar_count"]) + 1
			return


func _broadcast() -> void:
	if _role != "host":
		return
	_receive_districts.rpc(_pack_rows())


func _pack_rows() -> Array:
	var rows: Array = []
	for row in _districts:
		rows.append(_pack(row))
	rows.append(_pack({
		"id": WELCOME_VALLEY,
		"name": "Welcome Valley",
		"available": true,
		"avatar_count": _welcome_pop(),
		"new_avatar_count": 0,
	}))
	return rows


func _self_peer() -> int:
	if _role == "offline":
		return 0
	return multiplayer.get_unique_id()


func _reserve_trolley(game_id: int) -> void:
	if _role == "client":
		_set_trolley.rpc_id(1, game_id)
		return
	_keep_trolley(_self_peer(), game_id)


func _keep_trolley(peer: int, game_id: int) -> void:
	if game_id == 0 or not _TROLLEY.has(game_id):
		_trolley_for.erase(peer)
		return
	_trolley_for[peer] = game_id


func _ask_summon(district: int, slug: String, query: String, level: int, near: Vector3) -> void:
	if is_authority():
		var traffic := get_node_or_null("/root/StreetTraffic")
		if traffic != null and traffic.has_method("summon"):
			traffic.call("summon", district, slug, query, level, near)
		return
	if _role == "client":
		_request_summon.rpc_id(1, district, slug, query, level, near.x, near.y, near.z)


func _begin_trolley(avoid: int, peer: int = -1, district: int = -1) -> int:
	if district < 0:
		district = district_id()
	var channel := "trolley:%d" % district
	var have := latest(channel)
	if bool(have.get("open", false)) and int(have.get("id", 0)) != 0:
		return int(have["id"])
	if not is_authority():
		if _role == "client":
			_request_trolley.rpc_id(1, avoid, district_id())
		return 0
	if peer < 0:
		peer = _self_peer()
	# The toon who boarded asked for this game with ~mg. Anyone else's request waits.
	var picked := int(_trolley_for.get(peer, 0))
	_trolley_for.erase(peer)
	if not _TROLLEY.has(picked):
		picked = 0
	if picked == 0:
		var pool: Array[int] = []
		for game_id in _TROLLEY:
			if game_id != avoid:
				pool.append(game_id)
		if pool.is_empty():
			pool = _TROLLEY.duplicate()
		picked = pool[randi() % pool.size()]
	publish(channel, {"id": picked, "open": true, "score": 0, "by": peer})
	return picked


func _finish_trolley(score: int, district: int = -1) -> void:
	if not is_authority():
		if _role == "client":
			_submit_trolley.rpc_id(1, score, district_id())
		return
	if district < 0:
		district = district_id()
	var channel := "trolley:%d" % district
	var have := latest(channel)
	have["open"] = false
	have["score"] = score
	publish(channel, have)


func _request_suits(district: int, slug: String) -> void:
	if is_authority():
		var traffic := get_node_or_null("/root/StreetTraffic")
		if traffic != null and traffic.has_method("ensure"):
			traffic.call("ensure", district, slug)
		return
	if _role == "client":
		_request_street.rpc_id(1, district, slug)


func _on_peer(id: int) -> void:
	# peer_connected also fires on a client, and the new peer is the server.
	# Those welcome calls are authority-only, so a client must not send them.
	if not multiplayer.is_server():
		return
	_peers[id] = _here
	_recount()
	if _dedicated:
		print("Peer %d joined. %d connected." % [id, _peers.size()])
	_broadcast()
	districts_changed.emit()
	_receive_districts.rpc_id(id, _pack_rows())
	for channel in _states.keys():
		var state: Dictionary = _states[channel]
		_receive_state.rpc_id(id, String(channel), state)
	_join_result.rpc_id(id, _here, "")


func _on_peer_gone(id: int) -> void:
	_peers.erase(id)
	_recount()
	if _dedicated:
		print("Peer %d left. %d connected." % [id, _peers.size()])
	_broadcast()
	districts_changed.emit()
	_drop_toon(id)


func _on_connected() -> void:
	_role = "client"


func _on_failed() -> void:
	_role = "offline"
	multiplayer.multiplayer_peer = null


func _on_dropped() -> void:
	_role = "offline"
	_peers.clear()
	multiplayer.multiplayer_peer = null
	_recount()
	districts_changed.emit()
	var gone: PackedStringArray = []
	for key in _states.keys():
		var channel := String(key)
		if channel.begins_with("toon:"):
			gone.append(channel)
	for channel in gone:
		_states.erase(channel)
		state_changed.emit(channel)


func _drop_toon(id: int) -> void:
	var channel := "toon:%d" % id
	if not _states.has(channel):
		return
	_states.erase(channel)
	state_changed.emit(channel)
	if _role == "host":
		_clear_state.rpc(channel)


@rpc("any_peer", "reliable")
func _request_join(id: int) -> void:
	if not is_authority():
		return
	var peer := multiplayer.get_remote_sender_id()
	var reason := _take_seat(peer, id)
	if reason != "":
		_join_result.rpc_id(peer, id, reason)
		return
	_join_result.rpc_id(peer, id, "")


@rpc("authority", "reliable")
func _join_result(id: int, reason: String) -> void:
	if is_authority():
		return
	if reason != "":
		district_rejected.emit(reason)
		return
	if id == WELCOME_VALLEY:
		if not _welcome:
			_parent = _here
		_welcome = true
	else:
		_welcome = false
		_here = id
		_parent = id
	districts_changed.emit()
	district_seated.emit(id)


@rpc("authority", "reliable")
func _receive_districts(rows: Array) -> void:
	if is_authority():
		return
	var next: Array[Dictionary] = []
	for item in rows:
		if item is Dictionary:
			next.append(item)
	if next.is_empty():
		return
	_districts = next
	districts_changed.emit()


@rpc("authority", "reliable")
func _receive_state(channel: String, state: Dictionary) -> void:
	if is_authority():
		return
	_states[channel] = state
	state_changed.emit(channel)


@rpc("any_peer", "reliable")
func _set_trolley(game_id: int) -> void:
	if is_authority():
		_keep_trolley(multiplayer.get_remote_sender_id(), game_id)


@rpc("any_peer", "reliable")
func _request_trolley(avoid: int, district: int) -> void:
	if not is_authority():
		return
	var sender := multiplayer.get_remote_sender_id()
	if _peers.has(sender):
		district = int(_peers[sender])
	_begin_trolley(avoid, sender, district)


@rpc("any_peer", "reliable")
func _submit_trolley(score: int, district: int) -> void:
	if not is_authority():
		return
	var sender := multiplayer.get_remote_sender_id()
	if _peers.has(sender):
		district = int(_peers[sender])
	_finish_trolley(score, district)


@rpc("any_peer", "reliable")
func _request_summon(district: int, slug: String, query: String, level: int, x: float, y: float, z: float) -> void:
	if not is_authority():
		return
	var sender := multiplayer.get_remote_sender_id()
	if _peers.has(sender):
		district = int(_peers[sender])
	_ask_summon(district, slug, query, level, Vector3(x, y, z))


@rpc("any_peer", "unreliable_ordered")
func _submit_state(channel: String, state: Dictionary) -> void:
	if not is_authority() or not channel.begins_with("toon:"):
		return
	var peer := multiplayer.get_remote_sender_id()
	_store("toon:%d" % peer, state)


@rpc("authority", "reliable")
func _clear_state(channel: String) -> void:
	if is_authority():
		return
	_states.erase(channel)
	state_changed.emit(channel)


@rpc("any_peer", "reliable")
func _request_street(district: int, slug: String) -> void:
	if is_authority():
		_request_suits(district, slug)


func _pack(value: Variant) -> Variant:
	if value is Vector3:
		var point := value as Vector3
		return [point.x, point.y, point.z]
	if value is Dictionary:
		var copy := {}
		var source: Dictionary = value
		for key in source.keys():
			copy[key] = _pack(source[key])
		return copy
	if value is Array:
		var copy: Array = []
		for item in value as Array:
			copy.append(_pack(item))
		return copy
	return value
