class_name MiniGolf
extends Node

## The district runs the minigolf round. A client sends a tee, an aim, or a
## swing. The ball is rolled here once, and every toon plays that same path.
## GolfManagerAI allowed four toons on a kart. The kart rows are the 3, 6, and
## 9 hole courses.

const _CHANNEL := "minigolf"

var _karts: Array = []
var _matches: Array = []
var _queued: Array = []
var _seq := 1
var _since := 0.0


func _ready() -> void:
	for index in 9:
		_karts.append({
			"index": index,
			"course": int(index / 3),
			"wait": -1.0,
			"seats": [],
		})


func _physics_process(_delta: float) -> void:
	if not ToonNet.is_authority() or _queued.is_empty():
		return
	var batch: Array = _queued
	_queued = []
	for item in batch:
		var game: Dictionary = item["game"]
		if not _matches.has(game):
			continue
		_swing_player(game, float(item["hold"]), float(item["aim"]))


func _process(delta: float) -> void:
	if not ToonNet.is_authority():
		return
	_tick(delta)
	_since += delta
	if _since >= 0.1:
		_since = 0.0
		_publish()


static func act(peer: int, kind: String, a: int, b: float, c: float) -> void:
	var golf := _bus()
	if golf == null:
		return
	golf._act(peer, kind, a, b, c)


static func drop_peer(peer: int) -> void:
	var golf := _bus()
	if golf == null:
		return
	golf._drop(peer)


static func mine() -> Dictionary:
	var av := ToonRoster.avatar_id()
	if av == 0:
		return {}
	var state := ToonNet.latest(_CHANNEL)
	for item in state.get("matches", []):
		if item is Dictionary and _has_av(item, av):
			return item
	return {}


static func seated_kart() -> int:
	var av := ToonRoster.avatar_id()
	var state := ToonNet.latest(_CHANNEL)
	var karts: Array = state.get("karts", [])
	for index in karts.size():
		var kart: Dictionary = karts[index]
		if _has_av(kart, av):
			return index
	return -1


static func _has_av(row: Dictionary, av: int) -> bool:
	var ids: Array = row.get("avs", [])
	return ids.has(av)


static func _bus() -> MiniGolf:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("MiniGolfBus") as MiniGolf


func _act(peer: int, kind: String, a: int, b: float, c: float) -> void:
	var who := _who(peer)
	if int(who["av"]) == 0:
		return
	if kind == "join":
		_join(a, who)
	elif kind == "leave":
		_drop(peer)
	elif kind == "tee":
		_tee(peer, a)
	elif kind == "ready":
		_confirm(peer)
	elif kind == "aim":
		_aim(peer, b)
	elif kind == "swing":
		_swing(peer, b, c)
	_publish()
	_since = 0.0


func _tick(delta: float) -> void:
	for kart in _karts:
		var seats: Array = kart["seats"]
		if seats.is_empty():
			kart["wait"] = -1.0
			continue
		if _busy(int(kart["course"]), kart):
			continue
		if float(kart["wait"]) < 0.0:
			kart["wait"] = MiniGolfRules.COUNTDOWN
		kart["wait"] = float(kart["wait"]) - delta
		if float(kart["wait"]) <= 0.0:
			_launch(kart)
	var finished: Array = []
	for game in _matches:
		game["clock"] = float(game["clock"]) + delta
		game["timer"] = float(game["timer"]) - delta
		if float(game["timer"]) > 0.0:
			continue
		var phase := String(game["phase"])
		if phase == "tee":
			_ready_player(game)
		elif phase == "aim":
			_queue_swing(game, 0.85, _toward_cup(game))
		elif phase == "roll":
			_land(game)
		elif phase == "card":
			finished.append(game)
	for game in finished:
		_matches.erase(game)


func _join(kart_index: int, who: Dictionary) -> void:
	if kart_index < 0 or kart_index >= _karts.size():
		return
	if not _find_peer(int(who["peer"])).is_empty():
		return
	var kart: Dictionary = _karts[kart_index]
	if _kart_playing(kart_index):
		return
	var seats: Array = kart["seats"]
	if seats.size() >= MiniGolfRules.PLAYERS:
		return
	seats.append(who)
	if float(kart["wait"]) < 0.0:
		kart["wait"] = MiniGolfRules.COUNTDOWN


func _drop(peer: int) -> void:
	for kart in _karts:
		var seats: Array = kart["seats"]
		var kept: Array = []
		for seat in seats:
			if int(seat["peer"]) != peer:
				kept.append(seat)
		kart["seats"] = kept
	var gone: Array = []
	for game in _matches:
		var players: Array = game["players"]
		var next: Array = []
		var removed := -1
		for index in players.size():
			if int(players[index]["peer"]) == peer:
				removed = index
			else:
				next.append(players[index])
		if removed < 0:
			continue
		game["players"] = next
		if next.is_empty():
			gone.append(game)
			continue
		if int(game["turn"]) >= next.size():
			game["turn"] = 0
		elif removed < int(game["turn"]):
			game["turn"] = int(game["turn"]) - 1
		if String(game["phase"]) != "card":
			_skip_finished(game)
	for game in gone:
		_matches.erase(game)


func _tee(peer: int, tee: int) -> void:
	var game := _current(peer)
	if game.is_empty() or String(game["phase"]) != "tee":
		return
	var player: Dictionary = _player(game)
	if int(player["peer"]) != peer:
		return
	player["tee"] = clampi(tee, 0, 2)


func _confirm(peer: int) -> void:
	var game := _current(peer)
	if game.is_empty() or String(game["phase"]) != "tee":
		return
	if int(_player(game)["peer"]) != peer:
		return
	_ready_player(game)


func _aim(peer: int, aim: float) -> void:
	var game := _current(peer)
	if game.is_empty() or String(game["phase"]) != "aim":
		return
	if int(_player(game)["peer"]) != peer:
		return
	game["aim"] = aim


func _swing(peer: int, hold: float, aim: float) -> void:
	var game := _current(peer)
	if game.is_empty() or String(game["phase"]) != "aim":
		return
	if int(_player(game)["peer"]) != peer:
		return
	_queue_swing(game, hold, aim)


func _launch(kart: Dictionary) -> void:
	var seats: Array = kart["seats"]
	if seats.is_empty():
		return
	var course := int(kart["course"])
	var bag: Array = []
	for seat in seats:
		bag.append(seat.duplicate())
	kart["seats"] = []
	kart["wait"] = -1.0
	var holes: Array = MiniGolfRules.pick(course)
	var players: Array = []
	for seat in bag:
		players.append({
			"peer": int(seat["peer"]),
			"av": int(seat["av"]),
			"name": String(seat["name"]),
			"scores": [],
			"in": false,
			"tee": 1,
			"lie_x": 0.0,
			"lie_y": 0.0,
			"lie_z": 0.0,
		})
	var game := {
		"id": _seq,
		"kart": int(kart["index"]),
		"course": course,
		"holes": holes,
		"hole_i": 0,
		"phase": "tee",
		"timer": MiniGolfRules.TEE_TIME,
		"clock": 0.0,
		"turn": 0,
		"aim": 0.0,
		"shot": 0,
		"shot_time": 0.0,
		"path": [],
		"players": players,
		"winner": "",
	}
	_seq += 1
	_start_hole(game)
	_matches.append(game)


func _start_hole(game: Dictionary) -> void:
	var info := MiniGolfRules.hole(_hole_id(game))
	var tees: Array = info["tees"]
	var spot: Vector3 = tees[mini(1, tees.size() - 1)]
	for player in game["players"]:
		var scores: Array = player["scores"]
		scores.append(0)
		player["in"] = false
		player["tee"] = mini(1, tees.size() - 1)
		player["lie_x"] = spot.x
		player["lie_y"] = spot.y + MiniGolfRules.BALL_RADIUS
		player["lie_z"] = spot.z
	game["turn"] = 0
	game["phase"] = "tee"
	game["timer"] = MiniGolfRules.TEE_TIME
	game["path"] = []
	game["aim"] = _toward_cup(game)


func _ready_player(game: Dictionary) -> void:
	var player: Dictionary = _player(game)
	var info := MiniGolfRules.hole(_hole_id(game))
	var tees: Array = info["tees"]
	var tee := clampi(int(player["tee"]), 0, tees.size() - 1)
	var spot: Vector3 = tees[tee]
	player["lie_x"] = spot.x
	player["lie_y"] = spot.y + MiniGolfRules.BALL_RADIUS
	player["lie_z"] = spot.z
	game["phase"] = "aim"
	game["timer"] = MiniGolfRules.AIM_TIME
	game["aim"] = _toward_cup(game)
	game["path"] = []


func _queue_swing(game: Dictionary, hold: float, aim: float) -> void:
	if String(game["phase"]) != "aim":
		return
	game["phase"] = "roll"
	game["timer"] = 60.0
	_queued.append({"game": game, "hold": hold, "aim": aim})


func _swing_player(game: Dictionary, hold: float, aim: float) -> void:
	var player: Dictionary = _player(game)
	var scores: Array = player["scores"]
	var hole_i := int(game["hole_i"])
	game["aim"] = aim
	var shot: Dictionary = MiniGolfRules.roll(
		_hole_id(game),
		Vector3(float(player["lie_x"]), float(player["lie_y"]), float(player["lie_z"])),
		aim,
		hold
	)
	if not bool(shot.get("ready", true)) and int(game.get("sim_tries", 0)) < 8:
		game["sim_tries"] = int(game.get("sim_tries", 0)) + 1
		game["phase"] = "aim"
		_queue_swing(game, hold, aim)
		return
	game["sim_tries"] = 0
	scores[hole_i] = int(scores[hole_i]) + 1
	if bool(shot["oob"]):
		pass
	elif bool(shot["in"]):
		player["in"] = true
		var info := MiniGolfRules.hole(_hole_id(game))
		var cup: Vector3 = info["cup"]
		player["lie_x"] = cup.x
		player["lie_y"] = cup.y + MiniGolfRules.BALL_RADIUS
		player["lie_z"] = cup.z
	else:
		player["lie_x"] = float(shot["x"])
		player["lie_y"] = float(shot["y"])
		player["lie_z"] = float(shot["z"])
	if int(scores[hole_i]) >= MiniGolfRules.MAX_SWINGS:
		player["in"] = true
	game["path"] = shot["path"]
	game["shot_time"] = float(shot["time"])
	game["shot"] = int(game["shot"]) + 1
	game["phase"] = "roll"
	game["timer"] = float(shot["time"])


func _land(game: Dictionary) -> void:
	game["path"] = []
	var player: Dictionary = _player(game)
	if bool(player["in"]):
		_advance(game)
		return
	game["phase"] = "aim"
	game["timer"] = MiniGolfRules.AIM_TIME
	game["aim"] = _toward_cup(game)


func _advance(game: Dictionary) -> void:
	var players: Array = game["players"]
	if players.is_empty():
		_matches.erase(game)
		return
	var start := int(game["turn"])
	for step in players.size():
		var index := (start + 1 + step) % players.size()
		if not bool(players[index]["in"]):
			game["turn"] = index
			var scores: Array = players[index]["scores"]
			if int(scores[int(game["hole_i"])]) <= 0:
				game["phase"] = "tee"
				game["timer"] = MiniGolfRules.TEE_TIME
				var info := MiniGolfRules.hole(_hole_id(game))
				var tees: Array = info["tees"]
				var spot: Vector3 = tees[mini(1, tees.size() - 1)]
				players[index]["tee"] = mini(1, tees.size() - 1)
				players[index]["lie_x"] = spot.x
				players[index]["lie_y"] = spot.y + MiniGolfRules.BALL_RADIUS
				players[index]["lie_z"] = spot.z
			else:
				game["phase"] = "aim"
				game["timer"] = MiniGolfRules.AIM_TIME
			game["aim"] = _toward_cup(game)
			game["path"] = []
			return
	if int(game["hole_i"]) + 1 >= (game["holes"] as Array).size():
		game["phase"] = "card"
		game["timer"] = 8.0
		game["winner"] = _winner(game)
		game["path"] = []
		return
	game["hole_i"] = int(game["hole_i"]) + 1
	_start_hole(game)


func _skip_finished(game: Dictionary) -> void:
	var player: Dictionary = _player(game)
	if player.is_empty() or not bool(player.get("in", false)):
		return
	_advance(game)


func _winner(game: Dictionary) -> String:
	var best := 9999
	var names: PackedStringArray = []
	for player in game["players"]:
		var total := 0
		for score in player["scores"]:
			total += int(score)
		if total < best:
			best = total
			names = PackedStringArray([String(player["name"])])
		elif total == best:
			names.append(String(player["name"]))
	if names.size() == 1:
		return names[0]
	return "Tie"


func _toward_cup(game: Dictionary) -> float:
	var player: Dictionary = _player(game)
	var info := MiniGolfRules.hole(_hole_id(game))
	var cup: Vector3 = info["cup"]
	var aim := Vector2(cup.x - float(player["lie_x"]), cup.z - float(player["lie_z"]))
	if aim.length_squared() < 0.0001:
		return float(game.get("aim", 0.0))
	return aim.angle()


func _hole_id(game: Dictionary) -> int:
	var holes: Array = game["holes"]
	return int(holes[int(game["hole_i"])])


func _player(game: Dictionary) -> Dictionary:
	var players: Array = game["players"]
	if players.is_empty():
		return {}
	return players[clampi(int(game["turn"]), 0, players.size() - 1)]


func _current(peer: int) -> Dictionary:
	for game in _matches:
		if String(game["phase"]) == "card":
			continue
		var players: Array = game["players"]
		for player in players:
			if int(player["peer"]) == peer:
				return game
	return {}


func _find_peer(peer: int) -> Dictionary:
	for kart in _karts:
		for seat in kart["seats"]:
			if int(seat["peer"]) == peer:
				return seat
	if not _current(peer).is_empty():
		return {"peer": peer}
	return {}


func _kart_playing(kart_index: int) -> bool:
	for game in _matches:
		if int(game["kart"]) == kart_index and String(game["phase"]) != "card":
			return true
	return false


func _busy(_course: int, kart: Dictionary) -> bool:
	return _kart_playing(int(kart["index"]))


func _who(peer: int) -> Dictionary:
	var state := ToonNet.latest("toon:%d" % peer)
	var av := int(state.get("av", 0))
	var toon_name := String(state.get("name", "")).strip_edges()
	if av == 0 and peer == ToonNet.peer_id():
		av = ToonRoster.avatar_id()
		var style := ToonRoster.selected_style()
		if style != null:
			toon_name = style.display_name()
	if toon_name == "":
		toon_name = "Toon"
	return {"peer": peer, "av": av, "name": toon_name}


func _publish() -> void:
	ToonNet.publish(_CHANNEL, _export())


func _export() -> Dictionary:
	var karts: Array = []
	for kart in _karts:
		var avs: Array = []
		var names: Array = []
		for seat in kart["seats"]:
			avs.append(int(seat["av"]))
			names.append(String(seat["name"]))
		karts.append({
			"course": int(kart["course"]),
			"wait": float(kart["wait"]),
			"avs": avs,
			"names": names,
		})
	var matches: Array = []
	for game in _matches:
		var avs: Array = []
		var names: Array = []
		var scores: Array = []
		var ins: Array = []
		var lies: Array = []
		for player in game["players"]:
			avs.append(int(player["av"]))
			names.append(String(player["name"]))
			scores.append(player["scores"])
			ins.append(bool(player["in"]))
			lies.append(float(player["lie_x"]))
			lies.append(float(player["lie_y"]))
			lies.append(float(player["lie_z"]))
		var player: Dictionary = _player(game)
		matches.append({
			"id": int(game["id"]),
			"course": int(game["course"]),
			"hole_i": int(game["hole_i"]),
			"hole_n": (game["holes"] as Array).size(),
			"hole": _hole_id(game),
			"holes": game["holes"],
			"phase": String(game["phase"]),
			"timer": maxf(float(game["timer"]), 0.0),
			"clock": float(game["clock"]),
			"turn": int(game["turn"]),
			"aim": float(game["aim"]),
			"tee": int(player.get("tee", 1)),
			"shot": int(game["shot"]),
			"shot_time": float(game["shot_time"]),
			"path": game["path"],
			"avs": avs,
			"names": names,
			"scores": scores,
			"ins": ins,
			"lies": lies,
			"winner": String(game["winner"]),
		})
	return {"karts": karts, "matches": matches}
