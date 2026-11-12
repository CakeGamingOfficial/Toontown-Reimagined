class_name KartGarage
extends RefCounted

## Tickets, kart DNA, trunk, best times, and trophies belong to the toon who
## bought the kart. The speedway boards stay on this machine.
## RaceManagerAI pays tickets back plus winnings only when the time qualifies.

const _RULES := preload("res://scenes/racing/kart_rules.gd")
const _FILE := "user://kart_garage.json"
const _MAX_HP := 137

static var _book: Dictionary = {}
static var _loaded := false


static func tickets() -> int:
	_ensure()
	return int(_row().get("tickets", 0))


static func set_tickets(amount: int) -> void:
	_ensure()
	var garage := _row()
	if garage.is_empty():
		return
	garage["tickets"] = clampi(amount, 0, _RULES.MAX_TICKETS)
	_save()


static func has_kart() -> bool:
	return body_type() >= 0


static func body_type() -> int:
	return int(dna()[0])


static func dna() -> Array:
	_ensure()
	var garage := _row()
	var row: Array = garage.get("dna", [])
	while row.size() < 9:
		row.append(-1)
	if not garage.is_empty():
		garage["dna"] = row
	return row


static func owned() -> Array:
	_ensure()
	return _row().get("owned", [])


static func owns(accessory: int) -> bool:
	return owned().has(accessory)


static func personal_best(track_id: int) -> float:
	_ensure()
	var best: Array = _row().get("best", [])
	var index := _RULES.track_index(track_id)
	if index < 0 or index >= best.size():
		return 0.0
	return float(best[index])


static func trophy_flags() -> Array:
	_ensure()
	var flags: Array = _row().get("trophies", [])
	while flags.size() < 33:
		flags.append(0)
	return flags


static func board(track_id: int, period: int) -> Array:
	_ensure()
	var records: Dictionary = _book.get("records", {})
	var track: Dictionary = records.get(str(track_id), {})
	var rows: Array = track.get(str(period), [])
	if rows.is_empty():
		return _default_board(track_id)
	return rows


static func buy_kart(body: int, cost: int) -> String:
	var garage := _row()
	if garage.is_empty() or tickets() < cost:
		return "Not Enough Tickets!"
	set_tickets(tickets() - cost)
	var row := dna()
	row[0] = body
	garage["dna"] = row
	_save()
	return ""


static func buy_accessory(accessory: int, cost: int, field: int) -> String:
	if not has_kart():
		return "You need a kart first! Try asking one of the clerks in the Kart Shop."
	if owns(accessory):
		return "You already own that accessory."
	if owned().size() >= _RULES.MAX_ACCESSORIES:
		return "Your trunk is full."
	var garage := _row()
	if garage.is_empty() or tickets() < cost:
		return "Not Enough Tickets!"
	set_tickets(tickets() - cost)
	var trunk: Array = owned()
	trunk.append(accessory)
	garage["owned"] = trunk
	equip(field, accessory)
	return ""


static func equip(field: int, accessory: int) -> void:
	if field < 1 or field > 8:
		return
	var row := dna()
	row[field] = accessory
	var garage := _row()
	if garage.is_empty():
		return
	garage["dna"] = row
	_save()


static func delete_accessory(accessory: int) -> void:
	var garage := _row()
	if garage.is_empty():
		return
	var trunk: Array = owned()
	trunk.erase(accessory)
	garage["owned"] = trunk
	var row := dna()
	for field in range(1, 9):
		if int(row[field]) == accessory:
			row[field] = -1
	garage["dna"] = row
	_save()


static func finish_race(track_id: int, race_type: int, total_time: float, qualified: bool, place: int, racers: int) -> Dictionary:
	# exitedRace. The deposit comes back only after a qualifying finish.
	_ensure()
	var fee := _RULES.entry_fee(track_id, race_type)
	var won := 0
	var bonus := 0
	var names: PackedStringArray = []
	if qualified:
		_note_best(track_id, total_time)
		if race_type == _RULES.PRACTICE:
			won = _RULES.PRACTICE_TICKETS
		else:
			won = _RULES.winnings_for(place, racers, fee, race_type, true)
			_note_history(track_id, place)
			bonus = _note_record(track_id, total_time, race_type)
		names = _note_trophies()
		set_tickets(tickets() + won + fee + bonus)
	return {
		"fee": fee,
		"winnings": won,
		"bonus": bonus,
		"qualified": qualified,
		"trophies": names,
		"time": total_time,
	}


static func _note_best(track_id: int, total_time: float) -> void:
	var best: Array = _row().get("best", _blank_best())
	var index := _RULES.track_index(track_id)
	if index < 0:
		return
	if float(best[index]) == 0.0 or total_time < float(best[index]):
		best[index] = total_time
	_row()["best"] = best


static func _note_history(track_id: int, place: int) -> void:
	# getNewSingleRaceHistory. Wins and qualifies stop climbing at 100.
	var history: Array = _row().get("history", _blank_history())
	var which := _RULES.genre(track_id)
	if place == 1 and int(history[3 + which]) < 100:
		history[3 + which] = int(history[3 + which]) + 1
	if int(history[which]) < 100:
		history[which] = int(history[which]) + 1
	_row()["history"] = history


static func _note_record(track_id: int, total_time: float, race_type: int) -> int:
	var bonus := 0
	var records: Dictionary = _book.get("records", {})
	var track: Dictionary = records.get(str(track_id), {})
	var racer := _racer_name()
	for period in range(3):
		var rows: Array = track.get(str(period), _default_board(track_id))
		for index in rows.size():
			if total_time < float((rows[index] as Array)[0]):
				rows.insert(index, [total_time, race_type, 1, racer])
				while rows.size() > 10:
					rows.pop_back()
				track[str(period)] = rows
				bonus = _RULES.bonus_for(period)
				break
	records[str(track_id)] = track
	_book["records"] = records
	return bonus


static func _note_trophies() -> PackedStringArray:
	var flags: Array = _row().get("trophies", _blank_trophies())
	var history: Array = _row().get("history", _blank_history())
	var earned: PackedStringArray = []
	for which in range(3):
		_award_steps(flags, earned, int(history[which]), which * 3, _RULES.QUAL_NEED)
		_award_steps(flags, earned, int(history[3 + which]), 10 + which * 3, _RULES.WIN_NEED)
	var qual_total := int(history[0]) + int(history[1]) + int(history[2])
	var win_total := int(history[3]) + int(history[4]) + int(history[5])
	if qual_total >= 100:
		_award(flags, earned, 9)
	if win_total >= 100:
		_award(flags, earned, 19)
	var best: Array = _row().get("best", _blank_best())
	var driven := 0
	for time in best:
		if float(time) > 0.0:
			driven += 1
	if driven >= _RULES.TRACK_IDS.size():
		_award(flags, earned, 29)
	var collected := 0
	for index in range(30):
		if int(flags[index]) == 1:
			collected += 1
	for cup in range(3):
		if collected >= (cup + 1) * 10:
			if _award(flags, earned, 30 + cup):
				_grant_laff()
	_row()["trophies"] = flags
	return earned


static func _award_steps(flags: Array, earned: PackedStringArray, count: int, first: int, needs: Array) -> void:
	for step in needs.size():
		if count >= int(needs[step]):
			_award(flags, earned, first + step)


static func _award(flags: Array, earned: PackedStringArray, index: int) -> bool:
	if index < 0 or index >= flags.size() or int(flags[index]) == 1:
		return false
	flags[index] = 1
	earned.append(_RULES.trophy_text(index))
	return true


static func _grant_laff() -> void:
	var loadout := ToonLoadout.for_selected()
	if loadout == null or loadout.max_hp >= _MAX_HP:
		return
	var maximum := mini(loadout.max_hp + 1, _MAX_HP)
	loadout.set_hp(maximum, maximum)
	loadout.save()


static func _racer_name() -> String:
	var style := ToonRoster.selected_style()
	if style == null:
		return "Toon"
	return style.display_name()


static func _default_board(track_id: int) -> Array:
	var rows: Array = []
	var time := _RULES.record_time(track_id)
	for _index in range(10):
		rows.append([time, 0, 1, "Goofy"])
	return rows


static func _blank_best() -> Array:
	var row: Array = []
	for _index in _RULES.TRACK_IDS.size():
		row.append(0.0)
	return row


static func _blank_history() -> Array:
	var row: Array = []
	for _index in range(12):
		row.append(0)
	return row


static func _blank_trophies() -> Array:
	var row: Array = []
	for _index in range(33):
		row.append(0)
	return row


static func _ensure() -> void:
	if not _loaded:
		_loaded = true
		_book = {
			"records": {},
			"day": _day(),
			"week": _week(),
		}
		if FileAccess.file_exists(_FILE):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_FILE))
			if parsed is Dictionary:
				_book = parsed
	_roll_periods()


## The kart follows the toon who bought it. A missing row is a new toon:
## 200 tickets and no kart, the same as a fresh DistributedToon.
static func _row() -> Dictionary:
	_ensure()
	_claim_legacy()
	var owner := ToonRoster.avatar_id()
	if owner <= 0:
		return {}
	var key := str(owner)
	var found: Variant = _book.get(key, null)
	if found is Dictionary:
		return found
	var garage := {
		"tickets": 200,
		"dna": [-1, -1, -1, -1, -1, -1, -1, -1, -1],
		"owned": [],
		"best": _blank_best(),
		"history": _blank_history(),
		"trophies": _blank_trophies(),
	}
	_book[key] = garage
	return garage


## Older saves kept one kart for the whole account. It stays with the toon
## who is playing when the file is next read.
static func _claim_legacy() -> void:
	if not (_book.get("dna", null) is Array):
		return
	var owner := ToonRoster.avatar_id()
	if owner <= 0:
		return
	var key := str(owner)
	if not _book.has(key):
		_book[key] = {
			"tickets": int(_book.get("tickets", 200)),
			"dna": _book.get("dna", []),
			"owned": _book.get("owned", []),
			"best": _book.get("best", _blank_best()),
			"history": _book.get("history", _blank_history()),
			"trophies": _book.get("trophies", _blank_trophies()),
		}
	_book.erase("tickets")
	_book.erase("dna")
	_book.erase("owned")
	_book.erase("best")
	_book.erase("history")
	_book.erase("trophies")
	_save()


## A deleted or replaced toon takes their kart with them.
static func reset_slot(index: int) -> void:
	_ensure()
	if index < 0 or index >= ToonRoster.SLOT_COUNT:
		return
	var style := ToonRoster.get_slot(index)
	if style == null or style.av_id <= 0:
		return
	var key := str(style.av_id)
	if not _book.has(key):
		return
	_book.erase(key)
	_save()


static func _roll_periods() -> void:
	# KartRecordDailyResetter and KartRecordWeeklyResetter clear those columns.
	var day := _day()
	var week := _week()
	var changed := false
	if int(_book.get("day", day)) != day:
		_clear_period(0)
		_book["day"] = day
		changed = true
	if int(_book.get("week", week)) != week:
		_clear_period(1)
		_book["week"] = week
		changed = true
	if changed:
		_save()


static func _clear_period(period: int) -> void:
	var records: Dictionary = _book.get("records", {})
	for track_id in _RULES.TRACK_IDS:
		var track: Dictionary = records.get(str(track_id), {})
		track[str(period)] = _default_board(track_id)
		records[str(track_id)] = track
	_book["records"] = records


static func _day() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


static func _week() -> int:
	return int(Time.get_unix_time_from_system() / 604800.0)


static func _save() -> void:
	var file := FileAccess.open(_FILE, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_book))
