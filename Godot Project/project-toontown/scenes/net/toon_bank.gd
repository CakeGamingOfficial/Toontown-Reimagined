extends RefCounted

## The district's copy of a toon. Original avatars lived in the server database:
## laff, gag inventory, experience, jellybeans, and the task journal. The id is
## the toon's avId. Disconnecting does not delete the row.

const _PATH := "user://toon_bank.json"
const _BEANS := preload("res://scenes/toons/jellybeans.gd")

# A heal is written here before the Toon's next save arrives. An older save
# must not put the laff back. The Toon echoes this number once that save has
# the new total.
static var _laff_seq := 0


static func recall(av_id: int) -> Dictionary:
	if av_id <= 0:
		return {}
	var root := _read()
	var toons: Dictionary = root.get("toons", {})
	var row: Variant = toons.get(str(av_id), {})
	if row is Dictionary:
		return (row as Dictionary).duplicate(true)
	return {}


static func store(av_id: int, record: Dictionary) -> void:
	if av_id <= 0:
		return
	var root := _read()
	var toons: Dictionary = root.get("toons", {})
	toons[str(av_id)] = _clean(av_id, record)
	root["toons"] = toons
	_write(root)


static func set_laff(av_id: int, hp: int, max_hp: int) -> void:
	var row := recall(av_id)
	if row.is_empty():
		return
	var maximum := maxi(max_hp, 1)
	row["max_hp"] = maximum
	row["hp"] = clampi(hp, 0, maximum)
	store(av_id, row)


## SellbotBossGlobals.PieToonup. The district adds the laff, then tells that Toon.
static func heal(av_id: int, amount: int) -> Dictionary:
	var row := recall(av_id)
	if row.is_empty() or amount <= 0:
		return {}
	var maximum := maxi(int(row.get("max_hp", 1)), 1)
	var before := clampi(int(row.get("hp", 1)), 0, maximum)
	var hp := clampi(before + amount, 0, maximum)
	if hp == before:
		return {}
	row["hp"] = hp
	row["max_hp"] = maximum
	row["laff_seq"] = int(row.get("laff_seq", 0)) + 1
	row["laff_hold"] = int(row.get("laff_hold", 0)) + (hp - before)
	store(av_id, row)
	return {"hp": hp, "max_hp": maximum, "seq": int(row["laff_seq"]), "gained": hp - before}


## A district hit can take laff. The hold is the laff the Toon has not saved yet.
static func shift(av_id: int, delta: int) -> Dictionary:
	if delta >= 0:
		return heal(av_id, delta)
	var row := recall(av_id)
	if row.is_empty():
		return {}
	var maximum := maxi(int(row.get("max_hp", 1)), 1)
	var before := clampi(int(row.get("hp", 1)), 0, maximum)
	var hp := clampi(before + delta, 0, maximum)
	if hp == before:
		return {}
	row["hp"] = hp
	row["max_hp"] = maximum
	row["laff_seq"] = int(row.get("laff_seq", 0)) + 1
	row["laff_hold"] = int(row.get("laff_hold", 0)) + (hp - before)
	store(av_id, row)
	return {"hp": hp, "max_hp": maximum, "seq": int(row["laff_seq"]), "gained": hp - before}


static func note_laff_seq(seq: int) -> void:
	_laff_seq = maxi(_laff_seq, seq)


static func laff_seq() -> int:
	return _laff_seq


## A save that left before the district changed laff does not include it yet.
## laff_hold is that change, positive or negative. Damage in the save remains.
static func prefer_laff(incoming: Dictionary, kept: Dictionary) -> Dictionary:
	if kept.is_empty():
		return incoming
	var behind := int(kept.get("laff_seq", 0)) - int(incoming.get("laff_seq", 0))
	if behind <= 0:
		incoming["laff_hold"] = 0
		return incoming
	var cap := maxi(int(incoming.get("max_hp", 1)), int(kept.get("max_hp", 1)))
	var hold := int(kept.get("laff_hold", 0))
	incoming["max_hp"] = cap
	incoming["hp"] = clampi(int(incoming.get("hp", 1)) + hold, 0, cap)
	incoming["laff_seq"] = int(kept.get("laff_seq", 0))
	incoming["laff_hold"] = hold
	return incoming


static func zero_gags(av_id: int) -> void:
	var row := recall(av_id)
	if row.is_empty():
		return
	var counts: Array = row.get("counts", [])
	for track in counts.size():
		if not (counts[track] is Array):
			continue
		var pocket: Array = counts[track]
		for level in pocket.size():
			pocket[level] = 0
		counts[track] = pocket
	row["counts"] = counts
	store(av_id, row)


static func merge_exp(av_id: int, record: Dictionary) -> Dictionary:
	var existing := recall(av_id)
	if existing.is_empty():
		return record
	var left: Array = existing.get("exp", []) if existing.get("exp", []) is Array else []
	var right: Array = record.get("exp", []) if record.get("exp", []) is Array else []
	var merged: Array = []
	for track in ToonLoadout.TRACK_COUNT:
		var kept := int(left[track]) if track < left.size() else 0
		var incoming := int(right[track]) if track < right.size() else 0
		merged.append(maxi(kept, incoming))
	record["exp"] = merged
	record["organic"] = _higher_organic(existing.get("organic", []), record.get("organic", []))
	return record


static func spend_gag(av_id: int, track: int, level: int) -> void:
	var row := recall(av_id)
	if row.is_empty() or track < 0 or level < 0:
		return
	var counts: Array = row.get("counts", [])
	if track >= counts.size() or not (counts[track] is Array):
		return
	var pocket: Array = counts[track]
	if level >= pocket.size() or int(pocket[level]) <= 0:
		return
	pocket[level] = int(pocket[level]) - 1
	counts[track] = pocket
	row["counts"] = counts
	store(av_id, row)


static func set_organic(av_id: int, amounts: Array) -> void:
	var row := recall(av_id)
	if row.is_empty():
		return
	row["organic"] = _higher_organic(row.get("organic", []), amounts)
	store(av_id, row)


static func _higher_organic(left: Variant, right: Variant) -> Array:
	var kept: Array = left if left is Array else []
	var incoming: Array = right if right is Array else []
	var levels: Array = []
	for track in ToonLoadout.TRACK_COUNT:
		var older := int(kept[track]) if track < kept.size() else -1
		var newer := int(incoming[track]) if track < incoming.size() else -1
		levels.append(maxi(older, newer))
	return levels


static func set_exp(av_id: int, amounts: Array, force: bool = false) -> void:
	var row := recall(av_id)
	if row.is_empty():
		return
	var previous: Array = row.get("exp", []) if row.get("exp", []) is Array else []
	var experience: Array = []
	for track in ToonLoadout.TRACK_COUNT:
		var amount := int(amounts[track]) if track < amounts.size() else 0
		# A fight total is counted from the bank's last number. If that number
		# is already behind the toon, writing it back would erase the point
		# that just unlocked the next gag. The tutorial reset passes force.
		if not force and track < previous.size():
			amount = maxi(amount, int(previous[track]))
		experience.append(clampi(amount, 0, 10500))
	row["exp"] = experience
	store(av_id, row)


static func capture() -> Dictionary:
	var av_id := ToonRoster.avatar_id()
	var loadout := ToonLoadout.for_selected()
	var tasks := ToonTasks.for_selected()
	var style := ToonRoster.selected_style()
	var active: Array = []
	for entry in tasks.task_entries():
		active.append(entry)
	return {
		"av_id": av_id,
		"name": "" if style == null else style.display_name(),
		"hp": loadout.hp,
		"max_hp": loadout.max_hp,
		"laff_seq": _laff_seq,
		"max_carry": loadout.max_carry,
		"counts": loadout.pocket_counts(),
		"unlocked": loadout.pocket_unlocked(),
		"exp": loadout.track_experience(),
		"organic": loadout.organic_levels(),
		"pouch": _BEANS.pouch(),
		"bank": _BEANS.bank(),
		"max_money": _BEANS.pouch_limit(),
		"vault": _BEANS.vault(),
		"vault_tier": _BEANS.vault_tier(),
		"has_book": tasks.has_book,
		"met_flippy": tasks.met_flippy,
		"in_playground": tasks.in_playground,
		"last_hood": tasks.last_hood,
		"visited": tasks.visited.duplicate(),
		"teleport": tasks.teleport.duplicate(),
		"reward_tier": tasks.reward_tier,
		"reward_history": tasks.reward_history.duplicate(),
		"active": active,
		"done": tasks.finished_ids(),
		"tracked": tasks.tracked(),
	}


static func apply(record: Dictionary) -> void:
	if record.is_empty():
		return
	note_laff_seq(int(record.get("laff_seq", 0)))
	ToonNet.silence_keep(true)
	var loadout := ToonLoadout.for_selected()
	loadout.apply_dict(record)
	loadout.save()
	var vault_amount := -1
	var vault_level := -1
	if record.has("vault"):
		vault_amount = int(record.get("vault", 0))
	if record.has("vault_tier"):
		vault_level = int(record.get("vault_tier", 0))
	_BEANS.set_saved(int(record.get("pouch", 0)), int(record.get("bank", 0)), int(record.get("max_money", -1)), vault_amount, vault_level)
	var tasks := ToonTasks.for_selected()
	tasks.apply_dict(record)
	tasks.save()
	_offer(record)
	ToonNet.silence_keep(false)


static func _offer(record: Dictionary) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	_walk(tree.current_scene, record)


static func _walk(node: Node, record: Dictionary) -> void:
	if node.has_method("adopt_record"):
		node.call("adopt_record", record)
	for child in node.get_children():
		_walk(child, record)


static func _clean(av_id: int, record: Dictionary) -> Dictionary:
	var copy := record.duplicate(true)
	copy["av_id"] = av_id
	copy["hp"] = maxi(int(copy.get("hp", 1)), 0)
	copy["max_hp"] = maxi(int(copy.get("max_hp", copy["hp"])), 1)
	if int(copy["hp"]) > int(copy["max_hp"]):
		copy["hp"] = copy["max_hp"]
	return copy


static func _read() -> Dictionary:
	if not FileAccess.file_exists(_PATH):
		return {"toons": {}}
	var file := FileAccess.open(_PATH, FileAccess.READ)
	if file == null:
		return {"toons": {}}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {"toons": {}}


static func _write(root: Dictionary) -> void:
	var file := FileAccess.open(_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(root))
