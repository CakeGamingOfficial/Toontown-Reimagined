extends RefCounted

## The district owns the crane round the way the CFO server did.
## One toon per crane, and a safe or a goon counts once.

static var active := false
static var dirty := false

static var _hp := 0
static var _helmet := false
static var _dizzy := 0.0
static var _helmet_left := -1.0
static var _helmet_at := -1000.0
static var _clock := 0.0
static var _started := 0.0
static var _seq := 0
static var _line := ""
static var _claims: Dictionary = {}
static var _seen: Dictionary = {}


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
	_hp = 0
	_helmet = false
	_dizzy = 0.0
	_helmet_left = -1.0
	_helmet_at = -1000.0
	_clock = 0.0
	_started = 0.0
	_seq = 0
	_line = ""
	_claims.clear()
	_seen.clear()
	_schedule_helmet()


static func stop() -> void:
	active = false
	dirty = true
	_claims.clear()
	_line = ""


static func claim(peer: int, crane: int) -> int:
	if not active:
		begin()
	if crane < 0 or crane > 3:
		if _claims.erase(peer):
			dirty = true
		return -1
	for other in _claims.keys():
		if int(other) != peer and int(_claims[other]) == crane:
			return -1
	if int(_claims.get(peer, -1)) != crane:
		dirty = true
	_claims[peer] = crane
	return crane


static func tick(delta: float) -> Dictionary:
	if not active:
		return {"live": false}
	_clock += delta
	if _helmet_left > 0.0 and not _helmet and _dizzy <= 0.0:
		_helmet_left = maxf(_helmet_left - delta, 0.0)
		if _helmet_left <= 0.0:
			_helmet = true
			_speak("He put on a safe helmet.")
	return snapshot()


static func hit(serial: int, kind: String, impact: float, scale: float) -> void:
	if not active:
		begin()
	if _seen.has(serial):
		return
	_seen[serial] = true
	if kind == "swing":
		if _dizzy > 0.0:
			_dizzy = 0.0
			_schedule_helmet()
			dirty = true
		return
	if kind == "goon":
		if _helmet:
			_speak("The goon bounced off his helmet.")
			return
		_record(maxi(2, int(impact * 25.0 * scale)))
		return
	if _dizzy > 0.0:
		_record(maxi(2, int(impact * 50.0)))
		return
	if _helmet and impact >= 0.5:
		_helmet = false
		_schedule_helmet()
		_speak("The helmet flew off.")
		return
	if not _helmet and _clock - _helmet_at > 300.0:
		_helmet = true
		_helmet_at = _clock
		_helmet_left = -1.0
		_speak("He caught the safe and wore it as a helmet.")
		return
	_speak("The safe bounced off.")


static func snapshot() -> Dictionary:
	return {
		"live": active,
		"hp": _hp,
		"helmet": _helmet,
		"dizzy": _dizzy,
		"seq": _seq,
		"line": _line,
	}


static func _record(damage: int) -> void:
	_hp = mini(_hp + damage, 500)
	if _dizzy <= 0.0 and damage >= 15:
		_dizzy = 1.0
		_helmet = false
		_helmet_left = -1.0
		_speak("The hit did %d and dizzied him." % damage)
		return
	if _dizzy <= 0.0:
		_speak("The hit did %d." % damage)
		_schedule_helmet()
		return
	_speak("The hit did %d." % damage)


static func _schedule_helmet() -> void:
	if _dizzy > 0.0 or _helmet:
		return
	var along := clampf(maxf(float(_hp) / 500.0, (_clock - _started) / 1800.0), 0.0, 1.0)
	_helmet_left = lerpf(45.0, 15.0, along)
	dirty = true


static func _speak(text: String) -> void:
	_line = text
	_seq += 1
	dirty = true
