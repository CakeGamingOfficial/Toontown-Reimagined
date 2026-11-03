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
const _TOON := preload("res://scenes/playgrounds/playground_toon.gd")

var _districts: Array[Dictionary] = []
var _here := 1
var _parent := 1
var _welcome := false
var _role := "offline"
var _states: Dictionary = {}
var _peers: Dictionary = {}
## Peer id to the toon's permanent avId. The bank row outlives the connection.
var _avatars: Dictionary = {}
var _silence_keep := false
const _BANK := preload("res://scenes/net/toon_bank.gd")
var _next_id := 1
var _port := _PORT
var _dedicated := false
var _status := ""
## RequestMinigame, keyed by the peer who typed ~mg. 0 is the offline player.
var _trolley_for: Dictionary = {}
var _last_address := ""
var _last_port := 0
var _boot_code := 0
var _voluntary := false
var _lost := false
var _rejoining := false
var _suppress_drop := false
var _reset_told := false
var _shutdown_started := false
var _stop_file := ""
var _stop_wait := 0.0
var _notice: Node
static var _lan_lines: PackedStringArray = PackedStringArray()
static var _lan_ready := false
static var _lan_started := false


func _ready() -> void:
	# A host has to tell clients the district is closing before the window goes.
	get_tree().auto_accept_quit = false
	_load_config()
	_apply_server_args()
	_recount()
	var script := load("res://scenes/net/disconnect_notice.gd") as GDScript
	_notice = script.new() as Node
	_notice.name = "DisconnectNotice"
	add_child(_notice)
	_notice.connect("retry_connect", _retry_connect)
	_notice.connect("leave_game", _leave_after_drop)
	var window := get_tree().root
	if window != null and not window.close_requested.is_connected(_request_shutdown):
		window.close_requested.connect(_request_shutdown)
	var link := multiplayer
	link.peer_connected.connect(_on_peer)
	link.peer_disconnected.connect(_on_peer_gone)
	link.connected_to_server.connect(_on_connected)
	link.connection_failed.connect(_on_failed)
	link.server_disconnected.connect(_on_dropped)
	if _wants_dedicated():
		_become_dedicated()
	else:
		_warm_lan()


static func live() -> ToonNet:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ToonNetwork") as ToonNet


static func is_authority() -> bool:
	var net := live()
	if net == null:
		return true
	# The lost-connection dialog is up. This process must not plan the district.
	if net._lost:
		return false
	return net._role != "client"


static func networked() -> bool:
	var net := live()
	return net != null and net._role != "offline"


## Round trip to the district, in milliseconds. -1 offline, -2 when this
## process is the host and nobody else is connected yet.
static func ping_ms() -> int:
	var net := live()
	if net == null or net.multiplayer.multiplayer_peer == null or net._role == "offline":
		return -1
	var link := net.multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if link == null:
		return -1
	if net.multiplayer.is_server():
		var worst := -2
		for id in net.multiplayer.get_peers():
			var remote := link.get_peer(int(id))
			if remote == null:
				continue
			worst = maxi(worst, int(remote.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)))
		return worst
	var server := link.get_peer(1)
	if server == null:
		return -1
	return int(server.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))


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
		elif arg == "--stop-file" and index + 1 < args.size():
			_stop_file = String(args[index + 1])
		elif arg.begins_with("--stop-file="):
			_stop_file = arg.trim_prefix("--stop-file=")


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
	_status = "Dedicated server listening on UDP port %d.\nDistricts: %s\n%s\nCtrl+C tells connected toons, then stops the server." % [_port, ", ".join(names), _address_block()]
	print(_status)


func _process(delta: float) -> void:
	if _stop_file == "" or _shutdown_started:
		return
	_stop_wait -= delta
	if _stop_wait > 0.0:
		return
	_stop_wait = 0.25
	if not FileAccess.file_exists(_stop_file):
		return
	var text := FileAccess.get_file_as_string(_stop_file).strip_edges()
	if text.is_empty():
		return
	_request_shutdown()


func _address_block() -> String:
	var lines := _gather_lan()
	if lines.is_empty():
		return "No LAN address was found. Clients on this machine can use 127.0.0.1."
	return "Clients connect to:\n" + "\n".join(lines)


## GetAdaptersAddresses can stall for seconds when a VPN adapter is present.
## The game window gathers addresses on a worker so Host never waits on it.
func _warm_lan() -> void:
	if _lan_started:
		return
	_lan_started = true
	WorkerThreadPool.add_task(_read_lan)


func _read_lan() -> void:
	var lines := _gather_lan()
	_store_lan.call_deferred(lines)


func _store_lan(lines: PackedStringArray) -> void:
	_lan_lines = lines
	_lan_ready = true


static func lan_ready() -> bool:
	return _lan_ready


static func lan_lines() -> PackedStringArray:
	return _lan_lines


static func _gather_lan() -> PackedStringArray:
	var lines: PackedStringArray = []
	for raw in IP.get_local_addresses():
		var address := String(raw)
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254.") or address == "0.0.0.0":
			continue
		if lines.has(address):
			continue
		lines.append(address)
	return lines


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
	var previous := -1
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
		previous = int(_peers.get(peer, -1))
		_peers[peer] = id
	_recount()
	_broadcast()
	districts_changed.emit()
	if _dedicated and peer != 0 and previous != id:
		_print_move(peer, previous, id)
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
	_last_address = address
	_last_port = port
	multiplayer.multiplayer_peer = peer
	_role = "client"
	return "Joining %s:%d." % [address, port]


func _disconnect_net() -> String:
	if _role == "offline":
		return "You are already on the local district."
	if _role == "host":
		_close_district()
		return "Closing the district."
	_voluntary = true
	_finish_offline()
	return "Back on the local district, %s." % _seat_name()


func _close_district() -> void:
	_voluntary = true
	if not _reset_told and multiplayer.multiplayer_peer != null:
		_reset_told = true
		_boot.rpc(153)
		_drop_host_soon()
		return
	_finish_offline()


func _drop_host_soon() -> void:
	# The boot packet has to leave before this process drops the link.
	await get_tree().create_timer(0.5).timeout
	_finish_offline()


func _finish_offline() -> void:
	_role = "offline"
	_peers.clear()
	multiplayer.multiplayer_peer = null
	_recount()
	districts_changed.emit()


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


func _ask_board(district: int, slug: String, block: int, toon_name: String, hp: int, max_hp: int) -> void:
	if is_authority():
		_open_board(district, slug, block, peer_id(), toon_name, hp, max_hp)
		return
	if _role == "client":
		_request_board.rpc_id(1, district, slug, block, toon_name, hp, max_hp)


func _ask_hop(district: int, slug: String, block: int) -> void:
	if is_authority():
		_open_hop(district, slug, block, peer_id())
		return
	if _role == "client":
		_request_hop.rpc_id(1, district, slug, block)


func _open_board(district: int, slug: String, block: int, peer: int, toon_name: String, hp: int, max_hp: int) -> void:
	var runs := get_node_or_null("/root/StreetTraffic/BuildingRuns")
	if runs != null and runs.has_method("board"):
		runs.call("board", district, slug, block, peer, toon_name, hp, max_hp)


func _open_hop(district: int, slug: String, block: int, peer: int) -> void:
	var runs := get_node_or_null("/root/StreetTraffic/BuildingRuns")
	if runs != null and runs.has_method("hop"):
		runs.call("hop", district, slug, block, peer)


func _ask_fight(district: int, slug: String, cog_id: int, toon_name: String, hp: int, max_hp: int) -> void:
	if is_authority():
		_open_fight(district, slug, cog_id, peer_id(), toon_name, hp, max_hp)
		return
	if _role == "client":
		_request_fight.rpc_id(1, district, slug, cog_id, toon_name, hp, max_hp)


func _ask_factory(district: int, cog_id: int, where: Vector3, yaw: float, toon_name: String, hp: int, max_hp: int) -> void:
	if is_authority():
		_open_factory(district, cog_id, where, yaw, peer_id(), toon_name, hp, max_hp)
		return
	if _role == "client":
		_request_factory.rpc_id(1, district, cog_id, where.x, where.y, where.z, yaw, toon_name, hp, max_hp)


func _open_factory(district: int, cog_id: int, where: Vector3, yaw: float, peer: int, toon_name: String, hp: int, max_hp: int) -> void:
	var board := get_node_or_null("/root/StreetTraffic/FactoryBoard")
	if board != null and board.has_method("engage"):
		board.call("engage", district, cog_id, where, yaw, peer, toon_name, hp, max_hp)


func _ask_gag(fight_id: int, track: int, level: int, target: int, exp: int) -> void:
	if is_authority():
		_choose_fight(fight_id, peer_id(), track, level, target, exp)
		return
	if _role == "client":
		_choose_gag.rpc_id(1, fight_id, track, level, target, exp)


func _finish_reward(fight_id: int) -> void:
	if is_authority():
		_close_reward(fight_id, peer_id())
		return
	if _role == "client":
		_reward_done.rpc_id(1, fight_id)


func _open_fight(district: int, slug: String, cog_id: int, peer: int, toon_name: String, hp: int, max_hp: int) -> void:
	var fights := get_node_or_null("/root/StreetTraffic/StreetFights")
	if fights != null and fights.has_method("open_fight"):
		fights.call("open_fight", district, slug, cog_id, peer, toon_name, hp, max_hp)


func _choose_fight(fight_id: int, peer: int, track: int, level: int, target: int, exp: int) -> void:
	var fights := get_node_or_null("/root/StreetTraffic/StreetFights")
	if fights != null and fights.has_method("choose"):
		fights.call("choose", fight_id, peer, track, level, target, exp)


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


static func silence_keep(silent: bool) -> void:
	var net := live()
	if net != null:
		net._silence_keep = silent


static func keep_toon() -> void:
	var net := live()
	if net == null or net._silence_keep:
		return
	var av_id := ToonRoster.avatar_id()
	if av_id <= 0:
		return
	var record: Dictionary = _BANK.merge_exp(av_id, _BANK.capture())
	if net.is_authority():
		_BANK.store(av_id, record)
		net._avatars[net.peer_id()] = av_id
		return
	if net._role == "client":
		net._keep_toon.rpc_id(1, record)


static func claim_toon() -> void:
	var net := live()
	if net == null:
		return
	var av_id := ToonRoster.avatar_id()
	if av_id <= 0:
		return
	var record: Dictionary = _BANK.capture()
	if net.is_authority():
		net._accept_claim(net.peer_id(), av_id, record)
		return
	if net._role == "client":
		net._claim_toon.rpc_id(1, av_id, record)


static func avatar_of(peer: int) -> int:
	var net := live()
	if net == null:
		return 0
	return int(net._avatars.get(peer, 0))


static func stored_laff(peer: int) -> Vector2i:
	var row: Dictionary = _BANK.recall(avatar_of(peer))
	if row.is_empty():
		return Vector2i(-1, -1)
	return Vector2i(int(row.get("hp", 1)), int(row.get("max_hp", 1)))


static func stored_exp(peer: int, track: int) -> int:
	var row: Dictionary = _BANK.recall(avatar_of(peer))
	if row.is_empty():
		return -1
	var experience: Array = row.get("exp", [])
	if track < 0 or track >= experience.size():
		return 0
	return int(experience[track])


static func persist_zero_gags(av_id: int) -> void:
	var net := live()
	if net == null or not net.is_authority():
		return
	_BANK.zero_gags(av_id)


static func persist_laff(av_id: int, hp: int, max_hp: int) -> void:
	var net := live()
	if net == null or not net.is_authority():
		return
	_BANK.set_laff(av_id, hp, max_hp)


static func persist_gag(av_id: int, track: int, level: int) -> void:
	var net := live()
	if net == null or not net.is_authority():
		return
	_BANK.spend_gag(av_id, track, level)


static func persist_exp(av_id: int, amounts: Array) -> void:
	var net := live()
	if net == null or not net.is_authority():
		return
	_BANK.set_exp(av_id, amounts)


static func finish_reward(fight_id: int) -> void:
	var net := live()
	if net == null:
		return
	net._finish_reward(fight_id)


static func ask_fight(district: int, slug: String, cog_id: int, toon_name: String, hp: int, max_hp: int) -> void:
	var net := live()
	if net == null:
		return
	net._ask_fight(district, slug, cog_id, toon_name, hp, max_hp)


static func ask_factory(district: int, cog_id: int, where: Vector3, yaw: float, toon_name: String, hp: int, max_hp: int) -> void:
	var net := live()
	if net == null:
		return
	net._ask_factory(district, cog_id, where, yaw, toon_name, hp, max_hp)


static func ask_board(district: int, slug: String, block: int, toon_name: String, hp: int, max_hp: int) -> void:
	var net := live()
	if net == null:
		return
	net._ask_board(district, slug, block, toon_name, hp, max_hp)


static func ask_hop(district: int, slug: String, block: int) -> void:
	var net := live()
	if net == null:
		return
	net._ask_hop(district, slug, block)


static func ask_gag(fight_id: int, track: int, level: int, target: int, exp: int) -> void:
	var net := live()
	if net == null:
		return
	net._ask_gag(fight_id, track, level, target, exp)


func _request_suits(district: int, slug: String) -> void:
	if is_authority():
		var traffic := get_node_or_null("/root/StreetTraffic")
		if traffic != null and traffic.has_method("ensure"):
			traffic.call("ensure", district, slug)
		if traffic != null and traffic.has_method("ensure_buildings"):
			traffic.call("ensure_buildings", district, slug)
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
		print("Peer %d joined %s. %d connected." % [id, _district_phrase(_here), _peers.size()])
	_broadcast()
	districts_changed.emit()
	_receive_districts.rpc_id(id, _pack_rows())
	for channel in _states.keys():
		var state: Dictionary = _states[channel]
		_receive_state.rpc_id(id, String(channel), state)
	_join_result.rpc_id(id, _here, "")


func _on_peer_gone(id: int) -> void:
	var who := _peer_label(id)
	_peers.erase(id)
	_avatars.erase(id)
	_recount()
	if _dedicated:
		print("%s disconnected. %d still connected." % [who, _peers.size()])
	_broadcast()
	districts_changed.emit()
	_drop_toon(id)


func _peer_label(id: int) -> String:
	var state: Dictionary = _states.get("toon:%d" % id, {})
	var toon_name := String(state.get("name", "")).strip_edges()
	if toon_name == "":
		return "Peer %d" % id
	return "%s (peer %d)" % [toon_name, id]


func _district_phrase(id: int) -> String:
	if id == WELCOME_VALLEY:
		return "Welcome Valley"
	return "the %s District" % _name_of(id)


func _print_move(peer: int, previous: int, id: int) -> void:
	var who := _peer_label(peer)
	if previous < 0:
		print("%s entered %s." % [who, _district_phrase(id)])
		return
	print("%s left %s and entered %s." % [who, _district_phrase(previous), _district_phrase(id)])


func _on_connected() -> void:
	_lost = false
	_role = "client"
	if not _rejoining:
		return
	_rejoining = false
	if _notice != null:
		_notice.call("hide_notice")
	claim_toon()
	_return_to_place()


func _on_failed() -> void:
	_role = "offline"
	multiplayer.multiplayer_peer = null
	if not _rejoining:
		return
	_rejoining = false
	_lost = true
	_show_disconnect(0)


func _on_dropped() -> void:
	# Reconnect closes the old link. That close is not another outage.
	if _suppress_drop:
		return
	var was_client := _role == "client"
	var code := _boot_code
	var voluntary := _voluntary
	_boot_code = 0
	_voluntary = false
	# An unexpected drop must not turn this process into the district AI
	# while the lost-connection dialog is waiting for an answer.
	_role = "offline"
	if was_client and not voluntary:
		_lost = true
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
	if was_client and not voluntary:
		_show_disconnect(code)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_shutdown()


func _request_shutdown() -> void:
	if _shutdown_started:
		return
	_shutdown_started = true
	if _role == "host" and not _reset_told and multiplayer.multiplayer_peer != null and not _peers.is_empty():
		_reset_told = true
		_voluntary = true
		if _dedicated:
			print("District closing. Telling connected toons.")
		_boot.rpc(153)
		_quit_after_boot()
		return
	get_tree().quit()


func _quit_after_boot() -> void:
	await get_tree().create_timer(0.5).timeout
	if is_inside_tree():
		get_tree().quit()


func _show_disconnect(code: int) -> void:
	if _notice != null:
		_notice.call("show_reason", code)


func _retry_connect() -> void:
	_lost = false
	# Drop the old link before opening another, without showing this dialog again.
	_suppress_drop = true
	_voluntary = true
	_role = "offline"
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	_voluntary = false
	if _last_address == "":
		get_tree().quit()
		return
	_rejoining = true
	var result := _join_server(_last_address, _last_port)
	if not result.begins_with("Joining"):
		_rejoining = false
		_suppress_drop = false
		_show_disconnect(0)
		return
	_release_suppress()


func _release_suppress() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _rejoining:
		_suppress_drop = false


func _leave_after_drop() -> void:
	get_tree().quit()


func _return_to_place() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var path := scene.scene_file_path
	if path.is_empty() or path.ends_with("pick_a_toon.tscn"):
		return
	_TOON.teleport_in = true
	_TOON.portal_in = true
	ToonLoading.change_to(path)


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
func _boot(code: int) -> void:
	if is_authority():
		return
	_boot_code = code
	if _role != "client" or _voluntary:
		return
	# The district is closing now. The socket may still look open for a moment.
	_lost = true
	_show_disconnect(code)


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
	claim_toon()


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


## The toontorial writes the book and SpeedChat into the journal after the
## first claim. A stored row from that first claim must not win over them.
func _journal_ahead(incoming: Dictionary, kept: Dictionary) -> bool:
	if bool(incoming.get("has_book", false)) and not bool(kept.get("has_book", false)):
		return true
	if bool(incoming.get("met_flippy", false)) and not bool(kept.get("met_flippy", false)):
		return true
	var incoming_done: Array = incoming.get("done", [])
	var kept_done: Array = kept.get("done", [])
	return incoming_done.size() > kept_done.size()


func _accept_claim(peer: int, av_id: int, record: Dictionary) -> void:
	if av_id <= 0:
		return
	_avatars[peer] = av_id
	var kept := _BANK.recall(av_id)
	# The first claim, at the start of the toontorial, stores a journal from
	# before Harry and Flippy. A later claim has to keep the copy that actually
	# has the book and SpeedChat, not replay that empty row over the file.
	if kept.is_empty() or _journal_ahead(record, kept):
		_BANK.store(av_id, record)
		kept = _BANK.recall(av_id)
	var local := false
	if multiplayer.multiplayer_peer == null:
		local = true
	elif peer == multiplayer.get_unique_id():
		local = true
	if local:
		_BANK.apply(kept)
		return
	_claim_result.rpc_id(peer, kept)


@rpc("any_peer", "reliable")
func _claim_toon(av_id: int, record: Dictionary) -> void:
	if not is_authority():
		return
	_accept_claim(multiplayer.get_remote_sender_id(), av_id, record)


@rpc("any_peer", "reliable")
func _keep_toon(record: Dictionary) -> void:
	if not is_authority() or not (record is Dictionary):
		return
	var sender := multiplayer.get_remote_sender_id()
	var av_id := int(_avatars.get(sender, record.get("av_id", 0)))
	if av_id <= 0:
		return
	_avatars[sender] = av_id
	_BANK.store(av_id, _BANK.merge_exp(av_id, record))


@rpc("authority", "reliable")
func _claim_result(record: Dictionary) -> void:
	if is_authority():
		return
	_BANK.apply(record)


@rpc("any_peer", "reliable")
func _request_board(district: int, slug: String, block: int, toon_name: String, hp: int, max_hp: int) -> void:
	if not is_authority():
		return
	var sender := multiplayer.get_remote_sender_id()
	if _peers.has(sender):
		district = int(_peers[sender])
	_open_board(district, slug, block, sender, toon_name, hp, max_hp)


@rpc("any_peer", "reliable")
func _request_hop(district: int, slug: String, block: int) -> void:
	if not is_authority():
		return
	var sender := multiplayer.get_remote_sender_id()
	if _peers.has(sender):
		district = int(_peers[sender])
	_open_hop(district, slug, block, sender)


@rpc("any_peer", "reliable")
func _request_fight(district: int, slug: String, cog_id: int, toon_name: String, hp: int, max_hp: int) -> void:
	if not is_authority():
		return
	var sender := multiplayer.get_remote_sender_id()
	if _peers.has(sender):
		district = int(_peers[sender])
	_open_fight(district, slug, cog_id, sender, toon_name, hp, max_hp)


@rpc("any_peer", "reliable")
func _request_factory(district: int, cog_id: int, x: float, y: float, z: float, yaw: float, toon_name: String, hp: int, max_hp: int) -> void:
	if not is_authority():
		return
	var sender := multiplayer.get_remote_sender_id()
	if _peers.has(sender):
		district = int(_peers[sender])
	_open_factory(district, cog_id, Vector3(x, y, z), yaw, sender, toon_name, hp, max_hp)


@rpc("any_peer", "reliable")
func _choose_gag(fight_id: int, track: int, level: int, target: int, exp: int) -> void:
	if not is_authority():
		return
	_choose_fight(fight_id, multiplayer.get_remote_sender_id(), track, level, target, exp)


@rpc("any_peer", "reliable")
func _reward_done(fight_id: int) -> void:
	if not is_authority():
		return
	_close_reward(fight_id, multiplayer.get_remote_sender_id())


func _close_reward(fight_id: int, peer: int) -> void:
	var fights := get_node_or_null("/root/StreetTraffic/StreetFights")
	if fights != null and fights.has_method("reward_done"):
		fights.call("reward_done", fight_id, peer)


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
