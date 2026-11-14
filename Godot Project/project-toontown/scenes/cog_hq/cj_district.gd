extends RefCounted

## The district owns the scale the way the Chief Justice server did.
## Evidence adds, a lawyer's book subtracts, and each hit counts once.

static var active := false
static var dirty := false

static var _hp := 1350
static var _max := 2700
static var _seen: Dictionary = {}


static func running() -> bool:
	return active


static func take_dirty() -> bool:
	var was := dirty
	dirty = false
	return was


static func begin(hp: int, maximum: int) -> void:
	if active:
		return
	active = true
	dirty = true
	_hp = clampi(hp, 0, maxi(maximum, 1))
	_max = maxi(maximum, 1)
	_seen.clear()


static func stop() -> void:
	active = false
	dirty = true
	_seen.clear()


static func hit(serial: int, kind: String, amount: int) -> void:
	if not active:
		begin(_hp, _max)
	if _seen.has(serial):
		return
	_seen[serial] = true
	if kind == "heal":
		_hp = maxi(_hp - maxi(amount, 0), 0)
	else:
		_hp = mini(_hp + maxi(amount, 0), _max)
	dirty = true


static func snapshot() -> Dictionary:
	return {"live": active, "hp": _hp, "max": _max}
