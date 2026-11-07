extends RefCounted

## The district's copy of a toon. Original avatars lived in the server database:
## laff, gag inventory, experience, jellybeans, and the task journal. The id is
## the toon's avId. Disconnecting does not delete the row.

const _PATH := "user://toon_bank.json"
const _BEANS := preload("res://scenes/toons/jellybeans.gd")


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
		"max_carry": loadout.max_carry,
		"counts": loadout.pocket_counts(),
		"unlocked": loadout.pocket_unlocked(),
		"exp": loadout.track_experience(),
		"pouch": _BEANS.pouch(),
		"bank": _BEANS.bank(),
		"max_money": _BEANS.pouch_limit(),
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
	ToonNet.silence_keep(true)
	var loadout := ToonLoadout.for_selected()
	loadout.apply_dict(record)
	loadout.save()
	_BEANS.set_saved(int(record.get("pouch", 0)), int(record.get("bank", 0)), int(record.get("max_money", -1)))
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
