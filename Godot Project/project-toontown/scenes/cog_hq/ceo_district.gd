extends RefCounted

## The district owns the C.E.O.'s health and his slow, the way the server did.

static var active := false
static var dirty := false

static var _hp := 0
static var _max := 500
static var _speed := 0.0
static var _speed_at := 0.0
static var _seen: Dictionary = {}


static func running() -> bool:
	return active


static func begin(hp: int, maximum: int) -> void:
	if active:
		return
	active = true
	dirty = true
	_hp = clampi(hp, 0, maxi(maximum, 1))
	_max = maxi(maximum, 1)
	_speed = 0.0
	_speed_at = _now()
	_seen.clear()


static func stop() -> void:
	active = false
	dirty = true
	_seen.clear()


static func hit(serial: int, kind: String, amount: int) -> void:
	if not active:
		begin(0, 500)
	if _seen.has(serial):
		return
	_seen[serial] = true
	if kind == "golf":
		var now := _now()
		var current := maxf(_speed - 20.0 * (now - _speed_at) / 60.0, 0.0)
		_speed = minf(current + float(maxi(amount, 0)), 90.0)
		_speed_at = now
	else:
		_hp = mini(_hp + maxi(amount, 0), _max)
	dirty = true


static func snapshot() -> Dictionary:
	var now := _now()
	var current := maxf(_speed - 20.0 * (now - _speed_at) / 60.0, 0.0)
	return {"live": active, "hp": _hp, "max": _max, "speed": current}


static func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
