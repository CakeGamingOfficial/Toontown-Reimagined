extends Node

## One D.A. Office trip. The layout is chosen when the lobby elevator leaves,
## and the same layout is kept for every floor, matching LawOfficeManagerAI.

const _BOOK := "res://assets/cog_hq/offices/offices.json"
const _NAMES: PackedStringArray = ["Lawbot A Office", "Lawbot B Office", "Lawbot C Office", "Lawbot D Office"]
const _LAFF: PackedInt32Array = [0, 81, 86, 96]
const _NOTICES: PackedInt32Array = [75, 150, 225, 300]

static var trip := ""
static var office := 0
static var layout := 0
static var floor := 0
static var reward := 5
static var serial := 0
static var boss_paid := false
static var _book: Dictionary = {}


static func begin(which: int) -> void:
	office = clampi(which, 0, 3)
	layout = office * 3 + randi() % 3
	floor = 0
	reward = 5
	boss_paid = false
	serial += 1
	trip = "in"


static func zone() -> int:
	return 13300 + office * 100


static func title() -> String:
	return _NAMES[office]


static func laff_min() -> int:
	return _LAFF[office]


static func notice_bonus() -> int:
	return _NOTICES[office]


static func credit() -> float:
	return 1.0 + float(floor) * 0.5


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
	var floors: Dictionary = book().get("floors", {})
	return floors.has("%d:%d:%d" % [zone(), layout, floor + 1])


static func advance() -> void:
	floor += 1
	trip = "in"


static func notices_for(level: int) -> int:
	# PromotionManagerAI.recoverMerits. MeritMultiplier is 0.5, then the floor
	# credit. Python's round-half-even is what the original server used.
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
