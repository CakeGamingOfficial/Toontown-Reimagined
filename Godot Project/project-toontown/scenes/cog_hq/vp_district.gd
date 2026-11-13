extends RefCounted

## DistributedSellbotBossAI for the pie round. The district rolls his attacks
## and his damage. Clients only report pies and hits.

static var active := false
static var dirty := false

static var _stored := 0
static var _rate := 0.0
static var _recover_at := 0.0
static var _clock := 0.0
static var _battle_at := 0.0
static var _hits := 0
static var _dizzy := false
static var _near := false
static var _ending := false
static var _attack_wait := 5.0
static var _strafe_wait := 9.0
static var _attack_open := 0.0
static var _strafe_open := 0.0
static var _seq := 0
static var _event := {}
static var _struck: Dictionary = {}


static func running() -> bool:
	return active


static func take_dirty() -> bool:
	var was := dirty
	dirty = false
	return was


static func begin() -> void:
	if active:
		return
	active = true
	dirty = true
	_stored = 0
	_rate = 0.0
	_clock = 0.0
	_recover_at = 0.0
	_battle_at = 0.0
	_hits = 0
	_dizzy = false
	_near = false
	_ending = false
	_attack_wait = 5.0
	_strafe_wait = 9.0
	_attack_open = 0.0
	_strafe_open = 0.0
	_seq = 0
	_event = {}
	_struck.clear()


static func stop() -> void:
	active = false
	dirty = true
	_event = {}


static func pie_toonup() -> int:
	return 2 if _nerfed() else 1


static func tick(delta: float, peers: Array) -> Dictionary:
	if not active:
		return {"live": false}
	_clock += delta
	_attack_open = maxf(_attack_open - delta, 0.0)
	_strafe_open = maxf(_strafe_open - delta, 0.0)
	if not _near and not _ending:
		_attack_wait -= delta
		if _attack_wait <= 0.0:
			_choose_attack(peers)
		_strafe_wait -= delta
		if _strafe_wait <= 0.0:
			_choose_strafe()
	var state := _snapshot()
	state["event"] = _event
	_event = {}
	return state


static func hit(kind: String, peer: int, peers: Array) -> int:
	if not active or _ending:
		return 0
	if kind == "opening":
		if _near:
			_ending = true
			dirty = true
			return 0
		_begin("dizzy", peers)
		return 0
	if kind == "body":
		if not _dizzy or _near:
			return 0
		var dealt := 2 if _nerfed() else 1
		_set_damage(mini(_damage() + dealt, 100), 0.0)
		_hits += 1
		dirty = true
		if _damage() >= 100:
			_enter_near()
			return 0
		var need := 50 if _nerfed() else 35
		if _hits >= 6 and _damage() >= need:
			_begin("recover", peers)
			return 0
		_seq += 1
		_event = {"kind": "downhit", "damage": dealt, "delay": 0.0, "radius": 0.0, "side": 0, "dir": 0, "target": 0, "seq": _seq, "t": float(_damage()) / 100.0}
		return 0
	if kind.begins_with("struck:"):
		if _dizzy or _near:
			return 0
		var seq := _seq
		var seen: Array = _struck.get(peer, [])
		if seen.has(seq):
			return 0
		seen.append(seq)
		_struck[peer] = seen
		dirty = true
		return _amount(kind.trim_prefix("struck:"))
	return 0


static func struck_damage(kind: String) -> int:
	return _amount(kind)


static func _choose_attack(peers: Array) -> void:
	if _dizzy:
		_begin("recover", peers)
		return
	var roll := randi() % 6
	if roll == 0:
		_begin("area", peers)
	elif roll == 1:
		_begin("front", peers)
	else:
		_begin("directed", peers)


static func _choose_strafe() -> void:
	_strafe_wait = 9.0
	if _dizzy or _near:
		return
	if not _event.is_empty():
		_strafe_wait = 0.5
		return
	var t := float(_damage()) / 100.0
	_strafe_open = 0.7 + (5.0 - 4.0 * t)
	_seq += 1
	_event = {
		"kind": "strafe",
		"damage": _amount("strafe"),
		"delay": _strafe_open,
		"radius": 6.0,
		"side": randi() % 2,
		"dir": randi() % 2,
		"target": 0,
		"seq": _seq,
		"t": t,
	}
	dirty = true


static func _begin(kind: String, peers: Array) -> void:
	if kind == "dizzy":
		_dizzy = true
		_hits = 0
		var delay := _progress(20.0, 5.0)
		_attack_open = delay
		_attack_wait = delay
		_event = {}
		dirty = true
		return
	_dizzy = false
	if kind == "area":
		var rate := 2.0 if _rate <= 0.0 else minf(200.0, _rate * 1.2)
		_set_damage(_damage(), rate)
		_attack_open = 4.21
	elif kind == "recover":
		_attack_open = 5.1
	elif kind == "directed":
		_attack_open = 4.84
	else:
		kind = "front"
		_attack_open = 2.65
	_attack_wait = _attack_open
	var target := 0
	if kind == "directed" and not peers.is_empty():
		target = int(peers[randi() % peers.size()])
	_seq += 1
	var delay := 0.2 if kind == "area" else (1.1 if kind == "directed" else _attack_open * 0.55)
	var radius := 50.0 if kind == "area" else (4.0 if kind == "directed" else 12.0)
	_event = {
		"kind": kind,
		"damage": _amount(kind),
		"delay": delay,
		"radius": radius,
		"side": 0,
		"dir": 0,
		"target": target,
		"seq": _seq,
		"t": float(_damage()) / 100.0,
	}
	dirty = true


static func _enter_near() -> void:
	_near = true
	_dizzy = true
	_attack_wait = 99999.0
	_strafe_wait = 99999.0
	_attack_open = 99999.0
	_event = {}
	dirty = true


static func _damage() -> int:
	var elapsed := _clock - _recover_at
	return int(maxf(float(_stored) - _rate * elapsed / 60.0, 0.0))


static func _set_damage(amount: int, rate: float) -> void:
	_stored = clampi(amount, 0, 100)
	_rate = rate
	_recover_at = _clock


static func _progress(start: float, finish: float) -> float:
	var along := float(_damage()) / 100.0
	var timed := (_clock - _battle_at) / 1800.0
	var t := clampf(maxf(along, timed), 0.0, 1.0)
	return start + (finish - start) * t


static func _amount(kind: String) -> int:
	var amount := 3
	if kind == "area":
		amount = 10
	elif kind == "strafe":
		amount = 2
	elif kind == "swat":
		amount = 5
	if _nerfed():
		amount = maxi(int(round(float(amount) * 0.5)), 1)
	return amount


static func _nerfed() -> bool:
	var snap := ToonNet.latest("holidays")
	var ids: Variant = snap.get("ids", [])
	if ids is Array:
		for item in ids:
			if int(item) == 96:
				return true
	return false


static func _snapshot() -> Dictionary:
	return {
		"live": true,
		"hp": _damage(),
		"hits": _hits,
		"dizzy": _dizzy,
		"near": _near,
		"ending": _ending,
		"doors": _dizzy or _attack_open > 0.0 or _strafe_open > 0.0 or _near,
		"seq": _seq,
	}
