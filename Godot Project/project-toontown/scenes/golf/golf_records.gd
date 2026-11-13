extends RefCounted

## GolfGlobals history, hole best, and course best. A finished round updates
## the same counters DistributedGolfCourseAI writes, then the cups that come
## from that history raise max laff by one and fill the meter.

const _PATH := "user://golf.json"
const _ROSTER := preload("res://scenes/toons/toon_roster.gd")
const _RULES := preload("res://scenes/golf/minigolf_rules.gd")
const _LOADOUT := preload("res://scenes/battle/toon_loadout.gd")
const _NET := preload("res://scenes/net/toon_net.gd")

const _NAMES: PackedStringArray = [
	"Courses Completed",
	"Courses Under Par",
	"Hole In One Shots",
	"Eagle Or Better Shots",
	"Birdie Or Better Shots",
	"Par Or Better Shots",
	"Multiplayer Courses Completed",
	"Walk In The Par Wins",
	"Hole Some Fun Wins",
	"The Hole Kit And Caboodle Wins",
]
## TrophyRequirements, three levels each. Par Or Better is the one counter
## the original increments with no cap.
const _NEED := [
	[4, 40, 400],
	[1, 10, 100],
	[1, 10, 100],
	[2, 20, 200],
	[3, 30, 300],
	[4, 40, 400],
	[6, 60, 600],
	[1, 10, 100],
	[1, 10, 100],
	[1, 10, 100],
]
const _CAP: PackedInt32Array = [400, 100, 100, 200, 300, 0, 600, 100, 100, 100]
const _COURSES_COMPLETED := 0
const _UNDER_PAR := 1
const _HOLE_IN_ONE := 2
const _EAGLE := 3
const _BIRDIE := 4
const _PAR := 5
const _MULTIPLAYER := 6
const _CUPS := 3

static var _loaded := false
static var _rows: Dictionary = {}
static var _seen: Dictionary = {}
static var _note := ""


static func history() -> PackedInt32Array:
	return _copy_ints(_row().get("history", []), _NAMES.size())


static func hole_best() -> PackedInt32Array:
	return _copy_ints(_row().get("holes", []), _RULES.HOLE_TITLES.size())


static func course_best() -> PackedInt32Array:
	return _copy_ints(_row().get("courses", []), _RULES.COURSE_TITLES.size())


static func trophies() -> PackedByteArray:
	var counts := history()
	var won := PackedByteArray()
	for index in _NEED.size():
		var need: Array = _NEED[index]
		for level in need.size():
			won.append(1 if counts[index] >= need[level] else 0)
	return won


static func cups() -> PackedByteArray:
	var won := trophies()
	var total := 0
	for flag in won:
		total += int(flag)
	var each := won.size() / _CUPS
	var owned := PackedByteArray()
	for cup in _CUPS:
		owned.append(1 if total >= (cup + 1) * each else 0)
	return owned


static func trophy_text(index: int) -> String:
	var flat := 0
	for group in _NEED.size():
		var need: Array = _NEED[group]
		for level in need.size():
			if flat == index:
				return "%d %s" % [need[level], _NAMES[group]]
			flat += 1
	return ""


static func note() -> String:
	return _note


## One award per match. The client applies it when the score card appears.
static func award(match_id: int, game: Dictionary) -> bool:
	var av := _ROSTER.avatar_id()
	var key := "%s:%d" % [_who(), match_id]
	if _seen.has(key):
		return true
	var avs: Array = game.get("avs", [])
	var slot := avs.find(av)
	if slot < 0:
		return false
	var scores: Array = game.get("scores", [])
	if slot >= scores.size():
		return false
	var row: Array = scores[slot]
	var holes: Array = game.get("holes", [])
	var record := _row()
	var counts := _copy_ints(record.get("history", []), _NAMES.size())
	var holes_best := _copy_ints(record.get("holes", []), _RULES.HOLE_TITLES.size())
	var courses_best := _copy_ints(record.get("courses", []), _RULES.COURSE_TITLES.size())
	var before_trophies := _flags_from(counts)
	var before_cups := _cups_from(before_trophies)
	var lines: PackedStringArray = []
	var total := 0
	var par_sum := 0
	var played := 0
	for index in holes.size():
		if index >= row.size():
			break
		var strokes := int(row[index])
		if strokes <= 0:
			continue
		played += 1
		total += strokes
		var hole_id := int(holes[index])
		var par := int(_RULES.hole(hole_id).get("par", 3))
		par_sum += par
		var diff := strokes - par
		if strokes == 1:
			_bump(counts, _HOLE_IN_ONE)
		if diff <= -2:
			_bump(counts, _EAGLE)
		if diff <= -1:
			_bump(counts, _BIRDIE)
		if diff <= 0:
			counts[_PAR] += 1
		if hole_id >= 0 and hole_id < holes_best.size():
			if holes_best[hole_id] == 0 or strokes < holes_best[hole_id]:
				holes_best[hole_id] = strokes
				if lines.size() < 2:
					lines.append("New best: %s %d" % [_RULES.hole_title(hole_id), strokes])
	if played <= 0 or played < holes.size():
		_seen[key] = true
		return true
	_seen[key] = true
	_bump(counts, _COURSES_COMPLETED)
	if total < par_sum:
		_bump(counts, _UNDER_PAR)
	var course := int(game.get("course", 0))
	var names: Array = game.get("names", [])
	if names.size() > 1:
		_bump(counts, _MULTIPLAYER)
		if _won_course(slot, scores, game.get("aims", [])) and course >= 0 and course < 3:
			_bump(counts, 7 + course)
	if course >= 0 and course < courses_best.size():
		if courses_best[course] == 0 or total < courses_best[course]:
			courses_best[course] = total
			lines.append("New best: %s %d" % [_RULES.course_title(course), total])
	var after := _flags_from(counts)
	var new_trophies := 0
	for index in after.size():
		if after[index] == 1 and before_trophies[index] == 0:
			new_trophies += 1
			if lines.size() < 3:
				lines.append("New trophy: %s" % trophy_text(index))
	var after_cups := _cups_from(after)
	var new_cups := 0
	for index in after_cups.size():
		if after_cups[index] == 1 and before_cups[index] == 0:
			new_cups += 1
	if new_cups > 0:
		var loadout := _LOADOUT.for_selected()
		loadout.set_hp(loadout.max_hp + new_cups, loadout.max_hp + new_cups)
		loadout.save()
		_NET.persist_laff(_ROSTER.avatar_id(), loadout.hp, loadout.max_hp)
		lines.append("Laff +%d" % new_cups)
	record["history"] = counts
	record["holes"] = holes_best
	record["courses"] = courses_best
	_write()
	_note = "\n".join(lines)
	return true


static func _won_course(slot: int, scores: Array, aims: Array) -> bool:
	var mine := _total(scores[slot] if slot < scores.size() else [])
	var mine_aim := float(aims[slot]) if slot < aims.size() else 0.0
	for index in scores.size():
		if index == slot:
			continue
		var other := _total(scores[index])
		if other < mine:
			return false
		if other == mine:
			var other_aim := float(aims[index]) if index < aims.size() else 0.0
			if other_aim <= mine_aim:
				return false
	return true


static func _total(row: Array) -> int:
	var sum := 0
	for score in row:
		sum += int(score)
	return sum


static func _bump(counts: PackedInt32Array, index: int) -> void:
	if index < 0 or index >= counts.size():
		return
	var cap := _CAP[index] if index < _CAP.size() else 0
	if cap > 0 and counts[index] >= cap:
		return
	counts[index] += 1


static func _flags_from(counts: PackedInt32Array) -> PackedByteArray:
	var won := PackedByteArray()
	for index in _NEED.size():
		var need: Array = _NEED[index]
		for level in need.size():
			won.append(1 if counts[index] >= need[level] else 0)
	return won


static func _cups_from(won: PackedByteArray) -> PackedByteArray:
	var total := 0
	for flag in won:
		total += int(flag)
	var each := won.size() / _CUPS
	var owned := PackedByteArray()
	for cup in _CUPS:
		owned.append(1 if total >= (cup + 1) * each else 0)
	return owned


static func _row() -> Dictionary:
	_ensure()
	var key := _who()
	if not _rows.has(key):
		_rows[key] = {"history": PackedInt32Array(), "holes": PackedInt32Array(), "courses": PackedInt32Array()}
	return _rows[key]


static func _who() -> String:
	var av := _ROSTER.avatar_id()
	if av != 0:
		return str(av)
	return "slot:%d" % _ROSTER.selected_index()


static func _copy_ints(source: Variant, size: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(size)
	if source is PackedInt32Array:
		var packed: PackedInt32Array = source
		for index in mini(packed.size(), size):
			out[index] = packed[index]
		return out
	if source is Array:
		var row: Array = source
		for index in mini(row.size(), size):
			out[index] = int(row[index])
	return out


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(_PATH):
		return
	var file := FileAccess.open(_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_rows = parsed


static func _write() -> void:
	var file := FileAccess.open(_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_rows))
