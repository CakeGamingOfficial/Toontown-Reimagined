extends Node

## One country club trip. CountryClubManagerAI picks a layout index and keeps
## it for every floor. The shipped CountryClubLayout replaces the layout list
## with testLayout, so each course has one room sequence.

const _BOOK := "res://assets/cog_hq/courses/courses.json"
const _NAMES: PackedStringArray = ["The Front Three", "The Middle Six", "The Back Nine"]
const _LAFF: PackedInt32Array = [0, 101, 106]
const _STOCK: PackedInt32Array = [8, 14, 20]
const _CREDIT: PackedFloat32Array = [2.0, 2.5, 3.0]
const _FLOORS: PackedInt32Array = [3, 6, 9]

static var trip := ""
static var course := 0
static var layout := 0
static var floor := 0
static var serial := 0
static var boss_paid := false
static var _book: Dictionary = {}


static func begin(which: int) -> void:
	course = clampi(which, 0, 2)
	layout = course * 3 + randi() % 3
	floor = 0
	boss_paid = false
	serial += 1
	trip = "in"


static func zone() -> int:
	return 10500 + course * 100


static func title() -> String:
	return _NAMES[course]


static func laff_min() -> int:
	return _LAFF[course]


static func stock_bonus() -> int:
	return _STOCK[course]


static func credit() -> float:
	return _CREDIT[course]


static func book() -> Dictionary:
	if not _book.is_empty():
		return _book
	if not FileAccess.file_exists(_BOOK):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_BOOK))
	if parsed is Dictionary:
		_book = parsed
	return _book


static func floor_key() -> String:
	return "%d:%d:%d" % [zone(), layout, floor]


static func floor_plan() -> Dictionary:
	var floors: Dictionary = book().get("floors", {})
	var found: Variant = floors.get(floor_key(), {})
	if found is Dictionary:
		return found
	return {}


static func has_next() -> bool:
	return floor + 1 < _FLOORS[course]


static func advance() -> void:
	floor += 1
	trip = "in"


static func notices_for(level: int) -> int:
	var base := _py_round(float(level) * 0.5)
	return _py_round(float(base) * credit())


static func _py_round(value: float) -> int:
	var base := floori(value)
	var frac := value - float(base)
	if absf(frac - 0.5) < 0.00001:
		if base % 2 == 0:
			return base
		return base + 1
	return int(round(value))
