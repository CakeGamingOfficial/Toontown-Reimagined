extends RefCounted

## Holiday names are HolidayNamesInCalendar. Weekly rows match the calendar's
## weekday list. Yearly rows are the start and end the calendar actually drew:
## the first day, then the last day. ~startholiday adds one to today.

const _NAMES := {
	1: "Summer Fireworks",
	2: "New Year Fireworks",
	3: "Bloodsucker Invasion",
	4: "Winter Holiday",
	5: "Skelecog Invasion",
	6: "Mr. Hollywood Invasion",
	7: "Fish Bingo",
	8: "Toon Species Election",
	9: "Black Cat Day",
	13: "Trick or Treat",
	14: "Grand Prix",
	16: "Grand Prix Weekend",
	17: "Trolley Tracks",
	19: "Silly Saturdays",
	24: "Ides of March",
	25: "Double Gag Experience",
	26: "Halloween Decor",
	28: "Winter Invasion",
	29: "April Toons' Week",
	33: "Sellbot Surprise 1",
	34: "Sellbot Surprise 2",
	35: "Sellbot Surprise 3",
	36: "Sellbot Surprise 4",
	37: "A Cashbot Conundrum 1",
	38: "A Cashbot Conundrum 2",
	39: "A Cashbot Conundrum 3",
	40: "A Cashbot Conundrum 4",
	41: "The Lawbot Gambit 1",
	42: "The Lawbot Gambit 2",
	43: "The Lawbot Gambit 3",
	44: "The Lawbot Gambit 4",
	45: "The Trouble With Bossbots 1",
	46: "The Trouble With Bossbots 2",
	47: "The Trouble With Bossbots 3",
	48: "The Trouble With Bossbots 4",
	49: "Jellybean Day",
	53: "Cold Caller Invasion",
	54: "Bean Counter Invasion",
	55: "Double Talker Invasion",
	56: "Downsizer Invasion",
	57: "Caroling",
	59: "ValenToon's Day",
	72: "Yes Men Invasion",
	73: "Tightwad Invasion",
	74: "Telemarketers Invasion",
	75: "Head Hunter Invasion",
	76: "Spin Doctor Invasion",
	77: "Moneybags Invasion",
	78: "Two-faces Invasion",
	79: "Mingler Invasion",
	80: "Loan Shark Invasion",
	81: "Corporate Raider Invasion",
	82: "Robber Baron Invasion",
	83: "Legal Eagle Invasion",
	84: "Big Wig Invasion",
	85: "Big Cheese Invasion",
	86: "Down Sizer Invasion",
	87: "Mover And Shaker Invasion",
	88: "Double Talker Invasion",
	89: "Penny Pincher Invasion",
	90: "Name Dropper Invasion",
	91: "Ambulance Chaser Invasion",
	92: "Micro Manager Invasion",
	93: "Number Cruncher Invasion",
	95: "Victory Parties",
	96: "Operation: Storm Sellbot",
	97: "Double Bean Days - Trolley Games",
	98: "Double Bean Days - Fishing",
	99: "Jellybean Week",
	101: "Top Toons New Year's Day Marathon",
	105: "Toons go GREEN!",
	200: "Double Jellybeans",
}

## NewsManager.setSystemMessage lines. A missing end falls back to the holiday name.
const _HOLIDAY_LINES := {
	2: ["Toon HQ: Happy New Year! Enjoy the fireworks show!", "Toon HQ: Hope you enjoyed the show! Happy New Year!"],
	4: ["It's Winter Holiday time in Toontown!", "Winter Holiday is over - Happy New Year!"],
	7: ["It's time for Fish Bingo!  Go to any available pier to play!", "Hope you had fun playing Fish Bingo."],
	9: ["Create a Black Cat - Today only!", "Black Cat day has ended!"],
	25: ["Good news! Double gag experience time has started.", "Double gag experience time has ended."],
	14: ["The Toontown Grand Prix at Goofy Speedway is about to begin!  To win, collect the most points in three consecutive races!", "That's all for today's Toontown Grand Prix at Goofy Speedway.  See you next week!"],
	16: ["It's Grand Prix Weekend at Goofy Speedway! Free and paid players collect the most points in three consecutive races.", "That's all for Grand Prix Weekend. See you next year."],
	17: ["Trolley Tracks is about to begin!  Board any trolley with 2 or more toons to play.", "That's all for today's Trolley Tracks.  See you next week!"],
	26: ["It's Halloween in Toontown!", "Halloween has ended. Boo!"],
	49: ["It's Jellybean Day! Get Double Jellybean rewards at Parties!", "That's all for Jellybean Day. See you next year."],
	57: ["Caroling has come to Toontown. Sing for your Snowman Head - see the Blog for details!", ""],
	59: ["Happy ValenToon's Day!", "That's all for ValenToon's Day!"],
	96: ["Operation: Storm Sellbot is happening now! Battle the VP today!", "Operation: Storm Sellbot has ended. Great work, Toons!"],
	97: ["Double Bean Days for Trolley Games have begun!", "Double Bean Days for Trolley Games have ended!"],
	98: ["Double Bean Days for Fishing have begun!", "Double Bean Days for Fishing have ended!"],
	99: ["It's Jellybean Week! Get Double Jellybean rewards!", "That's all for Jellybean Week. See you next year."],
	101: ["The Top Toons New Year's Day Marathon has begun!", "The Top Toons New Year's Day Marathon has ended."],
	105: ["Toons go GREEN!", ""],
	200: ["Double Jellybeans have begun!", "Double Jellybeans have ended!"],
}

const _DEPT_NAME := {"c": "Bossbot", "l": "Lawbot", "m": "Cashbot", "s": "Sellbot"}
const _DEPT_PLURAL := {"c": "Bossbots", "l": "Lawbots", "m": "Cashbots", "s": "Sellbots"}

## Godot weekday, Sunday = 0. Monday Grand Prix, Wednesday Fish Bingo,
## Thursday Trolley Tracks, Saturday Silly Saturdays.
const _WEEKLY := {1: 14, 3: 7, 4: 17, 6: 19}

## id, start month, day, hour, minute, end month, day, hour, minute.
const _YEARLY: Array = [
	[59, 2, 9, 0, 0, 2, 16, 23, 59],
	[24, 3, 14, 0, 0, 3, 15, 23, 59],
	[105, 3, 14, 0, 0, 3, 20, 23, 59],
	[29, 3, 29, 0, 0, 4, 11, 23, 59],
	[16, 5, 25, 0, 0, 5, 28, 23, 59],
	[99, 6, 6, 0, 0, 6, 14, 23, 59],
	[1, 6, 29, 0, 0, 7, 16, 23, 59],
	[26, 10, 21, 0, 0, 11, 1, 23, 59],
	[13, 10, 21, 0, 0, 11, 1, 23, 59],
	[9, 10, 31, 0, 0, 10, 31, 23, 59],
	[4, 12, 14, 0, 0, 1, 4, 23, 59],
	[2, 12, 30, 0, 0, 1, 2, 23, 59],
	[101, 12, 31, 0, 0, 1, 1, 23, 59],
]

## code forces that cog. dept forces that department. skeleton makes a Skelecog.
const _INVASION := {
	3: {"code": "b"},
	5: {"skeleton": true},
	6: {"code": "mh"},
	24: {"code": "bs"},
	28: {"dept": "s"},
	33: {"code": "cc"},
	34: {"code": "nd"},
	35: {"code": "gh"},
	36: {"code": "ms"},
	37: {"code": "sc"},
	38: {"code": "pp"},
	39: {"code": "bc"},
	40: {"code": "nc"},
	41: {"code": "bf"},
	42: {"code": "dt"},
	43: {"code": "ac"},
	44: {"code": "bs"},
	45: {"code": "f"},
	46: {"code": "p"},
	47: {"code": "mm"},
	48: {"code": "ds"},
	53: {"code": "cc"},
	54: {"code": "bc"},
	55: {"code": "dt"},
	56: {"code": "ds"},
	72: {"code": "ym"},
	73: {"code": "tw"},
	74: {"code": "tm"},
	75: {"code": "hh"},
	76: {"code": "sd"},
	77: {"code": "mb"},
	78: {"code": "tf"},
	79: {"code": "m"},
	80: {"code": "ls"},
	81: {"code": "cr"},
	82: {"code": "rb"},
	83: {"code": "le"},
	84: {"code": "bw"},
	85: {"code": "tbc"},
	86: {"code": "ds"},
	87: {"code": "ms"},
	88: {"code": "dt"},
	89: {"code": "pp"},
	90: {"code": "nd"},
	91: {"code": "ac"},
	92: {"code": "mm"},
	93: {"code": "nc"},
}

static var _running: Dictionary = {}


static func start(holiday_id: int) -> String:
	if not _NAMES.has(holiday_id):
		return "Could not start holiday ID: %d" % holiday_id
	_adopt_net()
	_running[holiday_id] = true
	_publish()
	return "Started holiday %d, %s." % [holiday_id, String(_NAMES[holiday_id])]


static func stop(holiday_id: int) -> String:
	if not _NAMES.has(holiday_id):
		return "Could not end holiday ID: %d" % holiday_id
	_adopt_net()
	if not _running.has(holiday_id):
		return "Could not end holiday ID: %d" % holiday_id
	_running.erase(holiday_id)
	_publish()
	return "Ended holiday %d, %s." % [holiday_id, String(_NAMES[holiday_id])]


static func start_text(text: String) -> String:
	var holiday_id := resolve(text)
	if holiday_id == -2:
		return "That matches more than one holiday. Use the id, like ~startholiday 33."
	if holiday_id < 0:
		return "Could not start holiday ID: %s" % text
	return start(holiday_id)


static func stop_text(text: String) -> String:
	var holiday_id := resolve(text)
	if holiday_id == -2:
		return "That matches more than one holiday. Use the id, like ~endholiday 33."
	if holiday_id < 0:
		return "Could not end holiday ID: %s" % text
	return stop(holiday_id)


static func toggle(text: String) -> String:
	var holiday_id := resolve(text)
	if holiday_id == -2:
		return "That matches more than one holiday. Use the id, like ~holiday 33."
	if holiday_id < 0:
		return "Unknown holiday. Try ~holiday 7, ~holiday Fish Bingo, or ~startholiday 3."
	if _on().has(holiday_id):
		return stop(holiday_id)
	return start(holiday_id)


static func resolve(text: String) -> int:
	var key := text.strip_edges().to_lower()
	if key.is_valid_int():
		var holiday_id := int(key)
		return holiday_id if _NAMES.has(holiday_id) else -1
	var found := -1
	for holiday_id in _NAMES.keys():
		var name := String(_NAMES[holiday_id]).to_lower()
		if name != key and not name.begins_with(key):
			continue
		if found != -1:
			return -2
		found = int(holiday_id)
	return found


static func bean_scale(kind: String) -> int:
	var scale := 1
	var on := _on()
	# Double Jellybeans covers every payout and stacks with a specific one.
	if on.has(200):
		scale *= 2
	if kind == "fish" and (on.has(98) or on.has(49) or on.has(99)):
		scale *= 2
	elif kind == "trolley" and (on.has(97) or on.has(49) or on.has(99)):
		scale *= 2
	elif kind == "party" and (on.has(49) or on.has(99)):
		scale *= 2
	return scale


## ToontownBattleGlobals.getInvasionMultiplier. Welcome Valley never has one.
static func invasion_scale(district: int) -> int:
	if district <= 0 or plan_for(district).is_empty():
		return 1
	return 2


## Floor credit, then an invasion, then Double Gag Experience. Each one multiplies.
static func gag_credit(district: int, building: bool, floor: int) -> float:
	var mult := 1.0
	if building:
		mult = 1.0 + float(floor) * 0.5
	mult *= float(invasion_scale(district))
	return mult * float(exp_scale())


## ToontownBattleGlobals.getMoreXpHolidayMultiplier. This multiplies whatever
## credit the fight already has, including a building floor and an invasion.
static func exp_scale() -> int:
	if _on().has(25):
		return 2
	return 1


## The newest invasion holiday wins. Empty when the streets should stay normal.
static func invasion() -> Dictionary:
	var plan := {}
	for holiday_id in _on().keys():
		if _INVASION.has(int(holiday_id)):
			plan = _INVASION[int(holiday_id)]
	return plan


## ~invasion start. One invasion runs per district. Another start waits until it ends.
static var _rows: Array = []
static var _queue: Array = []


static func invading() -> bool:
	var district := ToonNet.district_id()
	if not _command_for(district).is_empty():
		return true
	return district > 0 and not is_county(district) and not invasion().is_empty()


## What the street should spawn. The magic-word invasion wins over a holiday.
static func spawn_plan() -> Dictionary:
	return plan_for(ToonNet.district_id())


## Empty when the district is quiet. Changes when the invading cog changes.
static func invasion_sig(district: int) -> String:
	var plan := plan_for(district)
	if plan.is_empty():
		return ""
	var skeleton := "1" if bool(plan.get("skeleton", false)) else "0"
	var revives := "1" if bool(plan.get("revives", false)) else "0"
	var laser := "1" if bool(plan.get("laser", false)) else "0"
	var waiter := "1" if bool(plan.get("waiter", false)) else "0"
	return "%s|%s|%s|%s|%s|%s" % [String(plan.get("code", "")), skeleton, String(plan.get("dept", "")), revives, laser, waiter]


## The department a Cog building shows and is taken as during this invasion.
## Empty when the invasion does not force one, such as a Skelecog invasion.
static func building_track(district: int) -> String:
	var plan := plan_for(district)
	if plan.is_empty():
		return ""
	var dept := String(plan.get("dept", ""))
	if dept != "":
		return dept
	var code := String(plan.get("code", ""))
	if code == "":
		return ""
	return _dept_of(code)


const COUNTY := "Corporate County"
## A new cog at each half hour on the host clock. Defeating them does not end it early.
const _COUNTY_COUNT := 1000
## 48 chances in a day. One in 32 starts an invasion, which is one or two a day.
const _NATURAL_ODDS := 32

static var _county: Dictionary = {}
static var _cog_rows: Array = []
## The half hour already rolled for each ordinary district. A stopped invasion stays quiet until the next :00 or :30.
static var _natural_given: Dictionary = {}
static var _spawn_pool: Array = []
static var _invasion_gen := -1
## The half-hour invasion has to survive a restart, or the street reads it as over and flies every cog away.
const _INVASION_PATH := "user://invasion_state.json"
static var _invasion_loaded := false


## What the district page draws between the name and the population.
## Empty when that district has no invasion.
static func district_invasion(district: int) -> Dictionary:
	if district <= 0:
		return {}
	var commanded := _command_for(district)
	if commanded.is_empty():
		return {}
	var dept := String(commanded.get("dept", ""))
	if dept == "":
		dept = _dept_of(String(commanded.get("code", "")))
	var left := "%d left" % int(commanded.get("remaining", 0))
	if bool(commanded.get("timed", false)):
		var until := float(commanded.get("until", 0.0))
		var seconds := maxi(int(ceil(until - ToonNet.now())), 0)
		left = "%d:%02d" % [int(seconds / 60), seconds % 60]
	return {
		"code": String(commanded.get("code", "")),
		"dept": dept,
		"name": String(commanded.get("name", "Cog")),
		"left": left,
	}


## A Cog District's name ends in County, like Corporate County. Welcome Valley does not.
static func is_county(district: int) -> bool:
	return district > 0 and _is_cog_county(ToonNet.name_of(district))


## Every district, including a Cog District, reads the invasion row for that district.
static func plan_for(district: int) -> Dictionary:
	var commanded := _command_for(district)
	if not commanded.is_empty():
		var plan := {
			"code": String(commanded.get("code", "")),
			"skeleton": bool(commanded.get("skeleton", false)),
			"revives": bool(commanded.get("revives", false)),
			"laser": bool(commanded.get("laser", false)),
			"waiter": bool(commanded.get("waiter", false)),
		}
		var dept := String(commanded.get("dept", ""))
		if dept != "":
			plan["dept"] = dept
		return plan
	return invasion()


static func republish_county() -> void:
	var row := _county_live()
	if not row.is_empty():
		ToonNet.share_county(row)


static func tick_county(_delta: float) -> void:
	if not ToonNet.is_authority():
		return
	_load_invasion()
	_tick_natural()


## The next :00 or :30 on this machine. Corporate County follows the host clock.
static func _next_half_hour() -> float:
	var now := Time.get_unix_time_from_system()
	var clock := Time.get_datetime_dict_from_system()
	var minute := int(clock.get("minute", 0))
	var second := int(clock.get("second", 0))
	var left := (30 - (minute % 30)) * 60 - second
	if left <= 0:
		left = 30 * 60
	return now + float(left)


## Welcome Valley never rolls. A Cog District always has one, and it changes at
## :00 and :30. Every other district rolls on its own then. A miss stays quiet
## until the next one. A department invasion is one eighth as likely as any one
## Cog in that same suit. Each step down the suit scale is twice as rare as
## the one above it.
static func _tick_natural() -> void:
	var slot := _half_slot()
	var until := _next_half_hour()
	var rows := _read_rows()
	var next: Array = []
	var have := {}
	var changed := false
	var noted := false
	for item in rows:
		if not item is Dictionary:
			continue
		var row: Dictionary = item
		var id := int(row.get("district", 0))
		if bool(row.get("timed", false)):
			if String(_natural_given.get(id, "")) != slot:
				changed = true
				continue
			next.append(row)
			have[id] = true
			continue
		next.append(row)
		have[id] = true
		_natural_given[id] = slot
	for district in ToonNet.district_rows():
		var id := int(district.get("id", 0))
		var district_name := String(district.get("name", ""))
		if id <= 0:
			continue
		var cog_district := _is_cog_county(district_name)
		if cog_district and have.has(id):
			_natural_given[id] = slot
			continue
		if not cog_district and (String(_natural_given.get(id, "")) == slot or have.has(id)):
			if have.has(id):
				_natural_given[id] = slot
				continue
			if not _can_promote(id):
				continue
			var held := _pull_queue(id)
			if held.is_empty():
				continue
			next.append(held)
			changed = true
			continue
		if _can_promote(id):
			var held_next := _pull_queue(id)
			if not held_next.is_empty():
				next.append(held_next)
				_natural_given[id] = slot
				changed = true
				continue
		if not cog_district and randi() % _NATURAL_ODDS != 0:
			_natural_given[id] = slot
			noted = true
			continue
		var rolled := _natural_row(id, until)
		if rolled.is_empty():
			continue
		next.append(rolled)
		_natural_given[id] = slot
		changed = true
	if changed:
		_write_rows(next)
	elif noted:
		_save_invasion()


static func _half_slot() -> String:
	var clock := Time.get_datetime_dict_from_system()
	var half := int(int(clock.get("minute", 0)) / 30)
	return "%s-%s-%s-%s-%s" % [clock.get("year", 0), clock.get("month", 0), clock.get("day", 0), clock.get("hour", 0), half]


static func _is_cog_county(district_name: String) -> bool:
	return district_name.to_lower().ends_with("county")


## The screenshot pool. Six suits are legal for every department and every cog.
## v2.0 with a Skelecog, and a waiter with a Skelecog, are not in the pool.
## A named Cog's base is 8 and a department's base is 1. The suit multiplier
## is applied to that base, and each step is half the weight of the step above it:
## Common 16, Uncommon 8, Rare 4, Very Rare 2, Ultra Rare 1.
const _DEPT_BASE := 1
const _COG_BASE := 8
static func _invasion_pool() -> Array:
	CogRules.note_shared(ToonNet.latest("dev:rules"))
	var tuned := CogRules.invasion()
	if tuned.has("suits"):
		_ensure_cogs()
		if _invasion_gen != CogRules.generation() or _spawn_pool.is_empty():
			_spawn_pool.clear()
			_fill_tuned_pool(tuned)
			_invasion_gen = CogRules.generation()
		return _spawn_pool
	if not _spawn_pool.is_empty():
		return _spawn_pool
	_ensure_cogs()
	var suits: Array[Dictionary] = [
		{"skeleton": false, "laser": false, "revives": false, "waiter": false, "rarity": 16},
		{"skeleton": true, "laser": false, "revives": false, "waiter": false, "rarity": 8},
		{"skeleton": true, "laser": true, "revives": false, "waiter": false, "rarity": 1},
		{"skeleton": false, "laser": false, "revives": true, "waiter": false, "rarity": 4},
		{"skeleton": false, "laser": false, "revives": false, "waiter": true, "rarity": 2},
		{"skeleton": false, "laser": false, "revives": true, "waiter": true, "rarity": 1},
	]
	for dept in ["s", "m", "l", "c"]:
		_add_spawn_rows(dept, "", "", _DEPT_BASE, suits)
	for item in _cog_rows:
		if not item is Dictionary:
			continue
		var cog: Dictionary = item
		_add_spawn_rows(String(cog.get("dept", "")), String(cog.get("code", "")), String(cog.get("name", "Cog")), _COG_BASE, suits)
	return _spawn_pool


static func _add_spawn_rows(dept: String, code: String, cog_name: String, base: int, suits: Array[Dictionary]) -> void:
	for suit in suits:
		var entry := suit.duplicate()
		entry["dept"] = dept
		entry["code"] = code
		entry["cog_name"] = cog_name
		entry["weight"] = base * int(suit.get("rarity", 1))
		_spawn_pool.append(entry)


static func _fill_tuned_pool(tuned: Dictionary) -> void:
	var dept_base := int(tuned.get("dept_base", _DEPT_BASE))
	var cog_base := int(tuned.get("cog_base", _COG_BASE))
	var suits: Array[Dictionary] = []
	for item in tuned.get("suits", []):
		if item is Dictionary:
			var suit: Dictionary = item
			suits.append(suit)
	if suits.is_empty():
		return
	for dept in ["s", "m", "l", "c"]:
		_add_spawn_rows(dept, "", "", dept_base, suits)
	var rows := CogCatalog.cog_rows()
	if rows.is_empty():
		rows = _cog_rows
	for item in rows:
		if not item is Dictionary:
			continue
		var cog: Dictionary = item
		_add_spawn_rows(String(cog.get("dept", "")), String(cog.get("code", "")), String(cog.get("name", "Cog")), cog_base, suits)


static func _pick_spawn() -> Dictionary:
	var pool := _invasion_pool()
	var total := 0
	for item in pool:
		if item is Dictionary:
			total += int((item as Dictionary).get("weight", 1))
	if total <= 0:
		return {}
	var roll := randi() % total
	for item in pool:
		if not item is Dictionary:
			continue
		var row: Dictionary = item
		roll -= int(row.get("weight", 1))
		if roll < 0:
			return row
	return {}


static func _natural_row(district: int, until: float) -> Dictionary:
	var pick := _pick_spawn()
	if pick.is_empty():
		return {}
	var code := String(pick.get("code", ""))
	var dept := String(pick.get("dept", ""))
	var skeleton := bool(pick.get("skeleton", false))
	var revives := bool(pick.get("revives", false))
	var laser := bool(pick.get("laser", false))
	var waiter := bool(pick.get("waiter", false))
	var cog_name := String(pick.get("cog_name", ""))
	var plural := ""
	if code == "":
		cog_name = String(_DEPT_NAME.get(dept, "Cog"))
		plural = String(_DEPT_PLURAL.get(dept, "Cogs"))
	else:
		plural = _plural(cog_name)
	var titled := _titled(cog_name, plural, skeleton, revives, laser, waiter)
	var row := {
		"district": district,
		"code": code,
		"name": String(titled["name"]),
		"plural": String(titled["plural"]),
		"skeleton": skeleton,
		"revives": revives,
		"laser": laser,
		"waiter": waiter,
		"timed": true,
		"until": until,
		"remaining": 1,
		"total": 1,
	}
	if code == "":
		row["dept"] = dept
	return row


static func _roll_county() -> void:
	var cog := _random_cog()
	if cog.is_empty():
		return
	var cog_name := String(cog.get("name", "Cog"))
	var skeleton := randi() % 5 == 0
	var shown := cog_name
	var plural := _plural(cog_name)
	if skeleton:
		shown = "Skelecog %s" % cog_name
		plural = "Skelecog %s" % plural
	_county = {
		"active": true,
		"code": String(cog.get("code", "")),
		"name": shown,
		"plural": plural,
		"skeleton": skeleton,
		"remaining": _COUNTY_COUNT,
		"total": _COUNTY_COUNT,
		"until": _next_half_hour(),
	}
	ToonNet.share_county(_county)


static func _dept_of(code: String) -> String:
	_ensure_cogs()
	for item in _cog_rows:
		if item is Dictionary and String((item as Dictionary).get("code", "")) == code:
			return String((item as Dictionary).get("dept", "c"))
	return "c"


static func _random_cog() -> Dictionary:
	_ensure_cogs()
	if _cog_rows.is_empty():
		return {}
	var item: Variant = _cog_rows[randi() % _cog_rows.size()]
	if item is Dictionary:
		return (item as Dictionary).duplicate()
	return {}


static func _ensure_cogs() -> void:
	if not _cog_rows.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cogs/catalog.json"))
	if parsed is Dictionary:
		var rows: Variant = (parsed as Dictionary).get("cogs", [])
		if rows is Array:
			_cog_rows = rows


static func _county_live() -> Dictionary:
	var snap := ToonNet.latest("county")
	if snap.has("active"):
		if not bool(snap.get("active", false)):
			_county = {}
			return {}
		_county = snap.duplicate()
		return _county
	return _county


static func begin_invasion(cog: Dictionary, amount: int, skeleton: bool, revives: bool = false, laser: bool = false, waiter: bool = false) -> String:
	if amount < 10 or amount > 25000:
		return "Can't the invasion amount to %d! Specify a value between 10 and 25,000." % amount
	if laser:
		skeleton = true
	if skeleton and revives:
		return "A v2.0 Cog can't be a Skelecog."
	if waiter and skeleton:
		return "A waiter Cog can't be a Skelecog."
	if waiter and String(cog.get("dept", "")) != "c":
		return "Only Bossbots wear the waiter suit."
	var district := ToonNet.district_id()
	if district <= 0:
		return "There is no invasion on the current AI!"
	if cog.is_empty() or String(cog.get("code", "")) == "":
		return "This cog does not exist!"
	var cog_name := String(cog.get("name", "Cog"))
	var titled := _titled(cog_name, _plural(cog_name), skeleton, revives, laser, waiter)
	return _hold_or_start(district, {
		"district": district,
		"code": String(cog.get("code", "")),
		"name": String(titled["name"]),
		"plural": String(titled["plural"]),
		"skeleton": skeleton,
		"revives": revives,
		"laser": laser,
		"waiter": waiter,
		"remaining": amount,
		"total": amount,
	})


static func dept_named(query: String) -> String:
	var folded := query.to_lower()
	var key := ""
	for index in folded.length():
		var letter := folded.substr(index, 1)
		if letter >= "a" and letter <= "z":
			key += letter
	var aliases := {
		"c": "c",
		"boss": "c",
		"bossbot": "c",
		"bossbots": "c",
		"corporate": "c",
		"corp": "c",
		"l": "l",
		"law": "l",
		"lawbot": "l",
		"lawbots": "l",
		"legal": "l",
		"m": "m",
		"cash": "m",
		"cashbot": "m",
		"cashbots": "m",
		"money": "m",
		"s": "s",
		"sell": "s",
		"sellbot": "s",
		"sellbots": "s",
		"sales": "s",
	}
	return String(aliases.get(key, ""))


static func begin_dept_invasion(dept: String, amount: int, skeleton: bool, revives: bool = false, laser: bool = false, waiter: bool = false) -> String:
	if amount < 10 or amount > 25000:
		return "Can't the invasion amount to %d! Specify a value between 10 and 25,000." % amount
	if laser:
		skeleton = true
	if skeleton and revives:
		return "A v2.0 Cog can't be a Skelecog."
	if waiter and skeleton:
		return "A waiter Cog can't be a Skelecog."
	if waiter and dept != "c":
		return "Only Bossbots wear the waiter suit."
	if not _DEPT_NAME.has(dept):
		return "That department does not exist! Departments are Bossbot, Lawbot, Cashbot, and Sellbot."
	var district := ToonNet.district_id()
	if district <= 0:
		return "There is no invasion on the current AI!"
	var cog_name := String(_DEPT_NAME[dept])
	var titled := _titled(cog_name, String(_DEPT_PLURAL[dept]), skeleton, revives, laser, waiter)
	return _hold_or_start(district, {
		"district": district,
		"code": "",
		"dept": dept,
		"name": String(titled["name"]),
		"plural": String(titled["plural"]),
		"skeleton": skeleton,
		"revives": revives,
		"laser": laser,
		"waiter": waiter,
		"remaining": amount,
		"total": amount,
	})


static func end_invasion() -> String:
	var district := ToonNet.district_id()
	if is_county(district):
		return "This Cog District's invasion keeps cycling. It can't be stopped."
	var commanded := _command_for(district)
	if commanded.is_empty():
		if district > 0 and not invasion().is_empty():
			return "The current invasion is a mega invasion, you must stop the holiday to stop the invasion."
		return "There is no invasion on the current AI!"
	var shown := String(commanded.get("name", "Cog"))
	var kept: Array = []
	for item in _read_rows():
		if item is Dictionary and int((item as Dictionary).get("district", 0)) != district:
			kept.append(item)
	var started := ""
	if _can_promote(district):
		var waiting := _pull_queue(district)
		if not waiting.is_empty():
			kept.append(waiting)
			started = String(waiting.get("plural", "Cogs"))
	_write_rows(kept)
	if started != "":
		return "Toon HQ: The %s Invasion has ended!!!\nToon HQ: %s have taken over Toontown!!!" % [shown, started]
	return "Toon HQ: The %s Invasion has ended!!!\nToon HQ: The Toons have saved the day once again!!!" % shown


static func snapshot() -> Dictionary:
	return {
		"county": _county_live().duplicate(true),
		"rows": _read_rows().duplicate(true),
		"queue": _queue.duplicate(true),
		"given": _natural_given.duplicate(true),
	}


static func restore(saved: Dictionary) -> void:
	_invasion_loaded = true
	var county: Variant = saved.get("county", {})
	if county is Dictionary and bool((county as Dictionary).get("active", false)):
		_county = (county as Dictionary).duplicate(true)
		ToonNet.share_county(_county)
	var waiting: Variant = saved.get("queue", [])
	if waiting is Array:
		_queue = (waiting as Array).duplicate(true)
	var given: Variant = saved.get("given", {})
	if given is Dictionary:
		_natural_given = (given as Dictionary).duplicate(true)
	var rows: Variant = saved.get("rows", [])
	if rows is Array:
		_write_rows(rows)


static var _alerts_ready := false
static var _seen_holidays: Dictionary = {}
static var _seen_street: Dictionary = {}
static var _seen_county: Dictionary = {}


## New system-alert lines since the last call. The first call only remembers
## what is already running, so joining does not replay it. A district seat
## changes before the teleport-out finishes, so invasion lines wait until the
## place on screen is the district you actually entered.
static func take_alerts() -> PackedStringArray:
	if _between_districts():
		return PackedStringArray()
	var lines: Array[String] = []
	var holidays := _holiday_ids()
	var street := _street_face()
	var county := _county_face()
	if not _alerts_ready:
		if not ToonNet.is_authority() and ToonNet.latest("clock").is_empty():
			return PackedStringArray()
		_seen_holidays = holidays
		_seen_street = street
		_seen_county = county
		_alerts_ready = true
		return PackedStringArray(lines)
	var street_changed := _face_key(street) != _face_key(_seen_street)
	for holiday_id in _seen_holidays.keys():
		var ended := int(holiday_id)
		if holidays.has(ended):
			continue
		if _INVASION.has(ended) and street_changed:
			continue
		lines.append(_holiday_end_line(ended))
	for holiday_id in holidays.keys():
		var started := int(holiday_id)
		if _seen_holidays.has(started):
			continue
		if _INVASION.has(started) and street_changed:
			continue
		lines.append(_holiday_start_line(started))
	_seen_holidays = holidays
	if street_changed:
		_append_invasion(lines, _seen_street, street)
		_seen_street = street
	_seen_county = county
	return PackedStringArray(lines)


## The loading screen, or a playground that was entered under a different
## district than the seat just accepted.
static func _between_districts() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var screen := tree.root.get_node_or_null("ToonLoadingScreen") as CanvasLayer
	if screen != null and screen.visible:
		return true
	var scene := tree.current_scene
	if scene == null:
		return false
	var arrival := scene.get_node_or_null("PlaygroundToon")
	if arrival == null or not arrival.has_method("district_entered"):
		return false
	return int(arrival.call("district_entered")) != ToonNet.district_id()


static func invasion_status() -> String:
	var commanded := _command_for(ToonNet.district_id())
	if commanded.is_empty():
		if ToonNet.district_id() > 0 and not invasion().is_empty():
			return "Toon HQ: There is a Cog Invasion in progress!!!"
		return "There is no invasion in progress!"
	if bool(commanded.get("timed", false)):
		var until := float(commanded.get("until", 0.0))
		var seconds := maxi(int(ceil(until - ToonNet.now())), 0)
		return "Toon HQ: The Cog Invasion is now at %d:%02d!!!\nToon HQ: We must defeat those %s!!!" % [int(seconds / 60), seconds % 60, String(commanded.get("plural", "Cogs"))]
	return "Toon HQ: The Cog Invasion is now at %s Cogs!!!\nToon HQ: We must defeat those %s!!!" % [str(int(commanded.get("remaining", 0))), String(commanded.get("plural", "Cogs"))]


## One defeated street cog of the invading type. Buildings do not count.
static func note_cog(district: int, code: String, skeleton: bool) -> void:
	if not ToonNet.is_authority():
		return
	var rows := _read_rows()
	var next: Array = []
	var changed := false
	var ended := {}
	for item in rows:
		if not item is Dictionary:
			continue
		var row: Dictionary = item
		if int(row.get("district", 0)) != district:
			next.append(row)
			continue
		if bool(row.get("timed", false)):
			next.append(row)
			continue
		if not _row_matches(row, code, skeleton):
			next.append(row)
			continue
		var left := int(row.get("remaining", 0)) - 1
		changed = true
		if left <= 0:
			ended[district] = true
			continue
		row["remaining"] = left
		next.append(row)
	for district_id in ended.keys():
		var ended_id := int(district_id)
		if _active_for(next, ended_id) or not _can_promote(ended_id):
			continue
		var waiting := _pull_queue(ended_id)
		if waiting.is_empty():
			continue
		next.append(waiting)
	if changed:
		_write_rows(next)


static func _row_matches(row: Dictionary, code: String, skeleton: bool) -> bool:
	if bool(row.get("skeleton", false)) != skeleton:
		return false
	var wanted := String(row.get("code", ""))
	if wanted != "":
		return wanted == code
	var dept := String(row.get("dept", ""))
	return dept != "" and _dept_of(code) == dept


static func _note_county(code: String, skeleton: bool) -> void:
	var county := _county_live()
	if county.is_empty():
		return
	if String(county.get("code", "")) != code:
		return
	if bool(county.get("skeleton", false)) != skeleton:
		return
	var left := int(county.get("remaining", 0)) - 1
	if left < 0:
		return
	county["remaining"] = left
	_county = county
	ToonNet.share_county(county)


static func _command_for(district: int) -> Dictionary:
	if district <= 0:
		return {}
	for item in _read_rows():
		if item is Dictionary and int((item as Dictionary).get("district", 0)) == district:
			return item
	return {}


static func _read_rows() -> Array:
	var snap := ToonNet.latest("invasion")
	if snap.has("rows") or snap.has("active") or snap.has("queue"):
		if not bool(snap.get("active", false)):
			_rows = []
			_queue = []
			return []
		var waiting: Variant = snap.get("queue", [])
		if waiting is Array:
			_queue = (waiting as Array).duplicate(true)
		else:
			_queue = []
		var raw: Variant = snap.get("rows", [])
		if raw is Array:
			_rows = (raw as Array).duplicate(true)
			return _rows
		if int(snap.get("district", 0)) > 0:
			_rows = [snap.duplicate()]
			return _rows
		_rows = []
		return []
	return _rows


static func _write_rows(rows: Array) -> void:
	_rows = rows.duplicate(true)
	if _rows.is_empty() and _queue.is_empty():
		_publish_command({"active": false, "rows": [], "queue": []})
	else:
		_publish_command({"active": true, "rows": _rows, "queue": _queue.duplicate(true)})
	_save_invasion()


static func _load_invasion() -> void:
	if _invasion_loaded:
		return
	_invasion_loaded = true
	if not FileAccess.file_exists(_INVASION_PATH):
		_remember_half_hour()
		_save_invasion()
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_INVASION_PATH))
	if not (parsed is Dictionary):
		_remember_half_hour()
		_save_invasion()
		return
	var root: Dictionary = parsed
	var waiting: Variant = root.get("queue", [])
	if waiting is Array:
		_queue = (waiting as Array).duplicate(true)
	var raw: Variant = root.get("rows", [])
	if raw is Array:
		_rows = (raw as Array).duplicate(true)
	var given: Variant = root.get("given", {})
	if given is Dictionary:
		_natural_given = {}
		for key in (given as Dictionary).keys():
			_natural_given[int(String(key))] = String((given as Dictionary)[key])
	if _rows.is_empty() and _natural_given.is_empty():
		_remember_half_hour()
		_save_invasion()
	if _rows.is_empty() and _queue.is_empty():
		_publish_command({"active": false, "rows": [], "queue": []})
		return
	_publish_command({"active": true, "rows": _rows, "queue": _queue.duplicate(true)})


## Opening the game in the middle of a half hour is not a new invasion.
static func _remember_half_hour() -> void:
	var slot := _half_slot()
	for district in ToonNet.district_rows():
		var id := int(district.get("id", 0))
		if id > 0 and not _natural_given.has(id):
			_natural_given[id] = slot


static func _save_invasion() -> void:
	if not ToonNet.is_authority():
		return
	var given := {}
	for key in _natural_given.keys():
		given[str(int(key))] = String(_natural_given[key])
	var file := FileAccess.open(_INVASION_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"rows": _rows,
		"queue": _queue,
		"given": given,
	}))
	file.close()


## A start while one is already running waits. The next one begins when that one ends.
static func _hold_or_start(district: int, row: Dictionary) -> String:
	var shown := String(row.get("plural", "Cogs"))
	var rows := _read_rows()
	if invading():
		_queue.append(row)
		_write_rows(rows)
		return "Toon HQ: %s will invade after the current Cog Invasion ends!!!" % shown
	rows.append(row)
	_write_rows(rows)
	return "Toon HQ: A Cog Invasion has begun!!!\nToon HQ: %s have taken over Toontown!!!" % shown


static func _pull_queue(district: int) -> Dictionary:
	var kept: Array = []
	var found := {}
	for item in _queue:
		if found.is_empty() and item is Dictionary and int((item as Dictionary).get("district", 0)) == district:
			found = (item as Dictionary).duplicate(true)
			continue
		kept.append(item)
	if not found.is_empty():
		_queue = kept
	return found


static func _active_for(rows: Array, district: int) -> bool:
	for item in rows:
		if item is Dictionary and int((item as Dictionary).get("district", 0)) == district:
			return true
	return false


## A holiday invasion is still the current one, so a queued start waits for it too.
## A Cog District's own invasion is the one that has to finish.
static func _can_promote(district: int) -> bool:
	if is_county(district):
		return true
	return invasion().is_empty()


static func _publish_command(state: Dictionary) -> void:
	ToonNet.share_invasion(state)


static func _holiday_ids() -> Dictionary:
	var found := {}
	for holiday_id in _on().keys():
		found[int(holiday_id)] = true
	return found


static func _holiday_start_line(holiday_id: int) -> String:
	var written := _holiday_written(holiday_id, 0)
	if written != "":
		return written
	return "Toon HQ: %s has started!" % String(_NAMES.get(holiday_id, "A holiday"))


static func _holiday_end_line(holiday_id: int) -> String:
	var written := _holiday_written(holiday_id, 1)
	if written != "":
		return written
	return "Toon HQ: %s has ended!" % String(_NAMES.get(holiday_id, "A holiday"))


static func _holiday_written(holiday_id: int, slot: int) -> String:
	if not _HOLIDAY_LINES.has(holiday_id):
		return ""
	var pair: Array = _HOLIDAY_LINES[holiday_id]
	if slot < 0 or slot >= pair.size():
		return ""
	return String(pair[slot])


static func _street_face() -> Dictionary:
	var district := ToonNet.district_id()
	if district <= 0:
		return {}
	var commanded := _command_for(district)
	if not commanded.is_empty():
		return {
			"code": String(commanded.get("code", "")),
			"name": String(commanded.get("name", "Cog")),
			"plural": String(commanded.get("plural", "Cogs")),
			"skeleton": bool(commanded.get("skeleton", false)),
			"until": float(commanded.get("until", 0.0)),
		}
	return _face_from_plan(invasion())


static func _county_face() -> Dictionary:
	var row := _county_live()
	if row.is_empty():
		return {}
	return {
		"code": String(row.get("code", "")),
		"name": String(row.get("name", "Cog")),
		"plural": String(row.get("plural", "Cogs")),
		"skeleton": bool(row.get("skeleton", false)),
		"until": float(row.get("until", 0.0)),
	}


static func _face_from_plan(plan: Dictionary) -> Dictionary:
	if plan.is_empty():
		return {}
	var code := String(plan.get("code", ""))
	var skeleton := bool(plan.get("skeleton", false))
	var revives := bool(plan.get("revives", false))
	var laser := bool(plan.get("laser", false))
	var waiter := bool(plan.get("waiter", false))
	var dept := String(plan.get("dept", ""))
	if code != "":
		var cog := _cog_by_code(code)
		var cog_name := String(cog.get("name", "Cog"))
		var titled := _titled(cog_name, _plural(cog_name), skeleton, revives, laser, waiter)
		return {"code": code, "name": String(titled["name"]), "plural": String(titled["plural"]), "skeleton": skeleton}
	if laser:
		return {"code": "", "name": "Laser Skelecog", "plural": "Laser Skelecogs", "skeleton": true}
	if skeleton:
		return {"code": "", "name": "Skelecog", "plural": "Skelecogs", "skeleton": true}
	if _DEPT_NAME.has(dept):
		var titled := _titled(String(_DEPT_NAME[dept]), String(_DEPT_PLURAL[dept]), false, revives, false, waiter)
		return {
			"code": "",
			"name": String(titled["name"]),
			"plural": String(titled["plural"]),
			"skeleton": false,
		}
	return {}


static func _cog_by_code(code: String) -> Dictionary:
	_ensure_cogs()
	for item in _cog_rows:
		if item is Dictionary and String((item as Dictionary).get("code", "")) == code:
			return item
	return {}


static func _face_key(face: Dictionary) -> String:
	if face.is_empty():
		return ""
	var skeleton := "1" if bool(face.get("skeleton", false)) else "0"
	return "%s|%s|%s|%s" % [str(face.get("code", "")), skeleton, str(face.get("name", "")), str(face.get("until", ""))]


static func _append_invasion(lines: Array[String], before: Dictionary, after: Dictionary) -> void:
	if not before.is_empty():
		lines.append("Toon HQ: The %s Invasion has ended!!!" % String(before.get("name", "Cog")))
		lines.append("Toon HQ: The Toons have saved the day once again!!!")
	if not after.is_empty():
		lines.append("Toon HQ: A Cog Invasion has begun!!!")
		lines.append("Toon HQ: %s have taken over Toontown!!!" % String(after.get("plural", "Cogs")))


static func _plural(cog_name: String) -> String:
	if cog_name.ends_with("man"):
		return cog_name.substr(0, cog_name.length() - 3) + "men"
	if cog_name.ends_with("y") and cog_name.length() > 1:
		var previous := cog_name.substr(cog_name.length() - 2, 1)
		if previous != "a" and previous != "e" and previous != "i" and previous != "o" and previous != "u":
			return cog_name.substr(0, cog_name.length() - 1) + "ies"
	if cog_name.ends_with("s") or cog_name.ends_with("x") or cog_name.ends_with("z") or cog_name.ends_with("ch") or cog_name.ends_with("sh"):
		return cog_name + "es"
	return cog_name + "s"


static func _titled(cog_name: String, plural: String, skeleton: bool, revives: bool, laser: bool, waiter: bool) -> Dictionary:
	var shown := cog_name
	var many := plural
	if laser:
		shown = "Laser Skelecog %s" % cog_name
		many = "Laser Skelecog %s" % plural
	elif waiter and revives:
		shown = "Waiter v2.0 %s" % cog_name
		many = "Waiter v2.0 %s" % plural
	elif waiter:
		shown = "Waiter %s" % cog_name
		many = "Waiter %s" % plural
	elif revives:
		shown = "v2.0 %s" % cog_name
		many = "v2.0 %s" % plural
	elif skeleton:
		shown = "Skelecog %s" % cog_name
		many = "Skelecog %s" % plural
	return {"name": shown, "plural": many}


static func _publish() -> void:
	var ids: Array = []
	for holiday_id in _running.keys():
		ids.append(int(holiday_id))
	ToonNet.share_holidays(ids)


static func _adopt_net() -> void:
	var snap := ToonNet.latest("holidays")
	var raw: Variant = snap.get("ids", null)
	if not (raw is Array):
		return
	_running.clear()
	for item in raw as Array:
		var holiday_id := int(item)
		if _NAMES.has(holiday_id):
			_running[holiday_id] = true


static func running(holiday_id: int) -> bool:
	return _on().has(holiday_id)


static func _on() -> Dictionary:
	_adopt_net()
	return _running


static func lines(year: int, month: int, day: int, include: bool) -> PackedStringArray:
	var rows: Array[String] = []
	if not include:
		return PackedStringArray(rows)
	var seen := {}
	var weekday := _weekday(year, month, day)
	if _WEEKLY.has(weekday):
		var weekly_id := int(_WEEKLY[weekday])
		_push(rows, seen, weekly_id, String(_NAMES[weekly_id]))
	var timed: Array = []
	for item in _YEARLY:
		var holiday_id := int(item[0])
		var starts := int(item[1]) == month and int(item[2]) == day
		var ends := int(item[5]) == month and int(item[6]) == day
		if starts:
			timed.append([int(item[3]) * 60 + int(item[4]), holiday_id, "%s %s" % [_clock(int(item[3]), int(item[4])), _NAMES[holiday_id]]])
		elif ends:
			timed.append([int(item[7]) * 60 + int(item[8]), holiday_id, "%s End-%s" % [_clock(int(item[7]), int(item[8])), _NAMES[holiday_id]]])
	timed.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	for entry in timed:
		_push(rows, seen, int(entry[1]), String(entry[2]))
	if _is_today(year, month, day):
		for holiday_id in _on():
			var running_id := int(holiday_id)
			if seen.has(running_id) or not _NAMES.has(running_id):
				continue
			_push(rows, seen, running_id, String(_NAMES[running_id]))
	return PackedStringArray(rows)


static func _push(rows: Array[String], seen: Dictionary, holiday_id: int, text: String) -> void:
	if rows.size() >= 4 or seen.has(holiday_id):
		return
	seen[holiday_id] = true
	rows.append(text)


static func _clock(hour: int, minute: int) -> String:
	var suffix := "AM"
	var shown := hour
	if hour >= 12:
		suffix = "PM"
		shown = hour - 12
	if shown == 0:
		shown = 12
	return "%d:%02d %s" % [shown, minute, suffix]


static func _weekday(year: int, month: int, day: int) -> int:
	var stamp := Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": 12})
	return int(Time.get_datetime_dict_from_unix_time(stamp).get("weekday", 0))


static func _is_today(year: int, month: int, day: int) -> bool:
	var now := ToonNet.clock()
	return int(now.get("year", 0)) == year and int(now.get("month", 0)) == month and int(now.get("day", 0)) == day
