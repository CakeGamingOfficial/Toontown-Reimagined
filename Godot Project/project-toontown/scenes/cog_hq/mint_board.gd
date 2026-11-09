extends Node

## LevelSuitPlannerAI for one mint ride. Cashbot suits are rolled from the
## battle level, the way SuitDNA.getRandomSuitType does. A battle is the cogs
## that share a room and a battle cell.

const SLUG := "cashbot_mint"
const _FLOORS := preload("res://scenes/cog_hq/mint_floor.gd")
const _CATALOG := "res://assets/cogs/catalog.json"
const _CASHBOTS: PackedStringArray = ["sc", "pp", "tw", "bc", "nc", "mb", "ls", "rb"]

var _rosters: Dictionary = {}
var _next_id := 1


func ensure(district: int, owner: int, mint: int, floor_num: int, ride: int) -> void:
	if not ToonNet.is_authority():
		return
	var key := "%d:%d:%d" % [district, owner, ride]
	var stale: Array = []
	for item in _rosters.keys():
		var existing := String(item)
		if existing.begins_with("%d:%d:" % [district, owner]) and existing != key:
			stale.append(existing)
	for existing in stale:
		_rosters.erase(existing)
	if not _rosters.has(key):
		_rosters[key] = _roll(mint, floor_num)
	_publish(district, owner, key)


func rows_for(district: int, owner: int) -> Array:
	var prefix := "%d:%d:" % [district, owner]
	for item in _rosters.keys():
		if not String(item).begins_with(prefix):
			continue
		var found: Variant = _rosters[item]
		if found is Array:
			return found
	return []


func dismiss(district: int, cog_id: int) -> void:
	if not ToonNet.is_authority():
		return
	for item in _rosters.keys():
		var key := String(item)
		if not key.begins_with("%d:" % district):
			continue
		var kept: Array = []
		var hit := false
		for row in _rosters[key]:
			if row is Dictionary and int((row as Dictionary).get("do_id", 0)) == cog_id:
				hit = true
				continue
			kept.append(row)
		if not hit:
			continue
		_rosters[key] = kept
		var parts := key.split(":")
		if parts.size() >= 2:
			_publish(district, int(parts[1]), key)
		return


func engage(district: int, owner: int, cog_id: int, origin: Vector3, yaw: float, peer: int, toon_name: String, hp: int, max_hp: int) -> void:
	var key := ""
	var lead: Dictionary = {}
	var prefix := "%d:%d:" % [district, owner]
	for item in _rosters.keys():
		if not String(item).begins_with(prefix):
			continue
		lead = _find(String(item), cog_id)
		if lead.is_empty():
			continue
		key = String(item)
		break
	if lead.is_empty():
		return
	var fights := get_node_or_null("../StreetFights")
	if fights == null or not fights.has_method("open_group"):
		return
	var spec: Dictionary = lead.get("cog", {})
	var cell := int(spec.get("cell", 0))
	var group: Array = [_battle_cog(lead, origin)]
	for row_item in _rosters.get(key, []):
		if not (row_item is Dictionary):
			continue
		var row: Dictionary = row_item
		var cog_spec: Dictionary = row.get("cog", {})
		if int(row.get("do_id", 0)) == cog_id or int(cog_spec.get("cell", -1)) != cell:
			continue
		if group.size() >= 4:
			break
		if fights.has_method("cog_paused") and bool(fights.call("cog_paused", int(row.get("do_id", 0)))):
			continue
		group.append(_battle_cog(row, origin))
	var mint := _mint_of(key)
	fights.call("open_group", district, SLUG, group, peer, toon_name, hp, max_hp, origin, yaw, mint)


func _battle_cog(row: Dictionary, origin: Vector3) -> Dictionary:
	var spec: Dictionary = row.get("cog", {})
	# DistributedLevelBattle face-off walks each suit from its own getPos.
	# The battle line is still built around the cog that was touched.
	var spot: Array = [origin.x, origin.y, origin.z]
	var stood: Variant = spec.get("pos", [])
	if stood is Array and (stood as Array).size() >= 3:
		spot = stood
	return {
		"id": int(row.get("do_id", 0)),
		"code": String(spec.get("code", "")),
		"name": String(spec.get("name", "Cog")),
		"level": int(spec.get("level", 1)),
		"dept": String(spec.get("dept", "m")),
		"body": String(spec.get("body", "c")),
		"height": float(spec.get("height", 4.0)),
		"skeleton": bool(spec.get("skeleton", false)),
		"boss": bool(spec.get("boss", false)),
		"pos": spot,
	}


func _find(key: String, cog_id: int) -> Dictionary:
	for item in _rosters.get(key, []):
		if item is Dictionary and int((item as Dictionary).get("do_id", 0)) == cog_id:
			return item
	return {}


func _mint_of(key: String) -> int:
	var listing: Variant = _rosters.get(key, [])
	if listing is Array and not (listing as Array).is_empty():
		var row: Variant = (listing as Array)[0]
		if row is Dictionary:
			return int((row as Dictionary).get("mint", 0))
	return 0


func _publish(district: int, owner: int, key: String) -> void:
	ToonNet.publish("suits:%d:%d:%s" % [district, owner, SLUG], {"rows": _rosters.get(key, [])})


func _roll(mint: int, floor_num: int) -> Array:
	var catalog := _read_json(_CATALOG)
	var by_code := {}
	for item in catalog.get("cogs", []):
		if item is Dictionary:
			by_code[str((item as Dictionary)["code"])] = item
	var floor := _floor(mint, floor_num)
	var roster: Array = []
	for item in floor.get("cogs", []):
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item
		var level := int(spec.get("level", 10))
		var suit := _suit(by_code, level, int(spec.get("skeleton", 0)) == 1)
		if suit.is_empty():
			continue
		suit["pos"] = spec.get("pos", [0.0, 0.0, 0.0])
		suit["yaw"] = float(spec.get("yaw", 0.0))
		suit["cell"] = int(spec.get("room", 0)) * 100 + int(spec.get("cell", 0))
		suit["boss"] = int(spec.get("boss", 0)) == 1
		roster.append({
			"do_id": _next_id,
			"mint": mint,
			"phase": 1,
			"position": [0.0, 0.0, 0.0],
			"yaw": 0.0,
			"cog": suit,
		})
		_next_id += 1
	return roster


func _floor(mint: int, floor_num: int) -> Dictionary:
	var book := _FLOORS.data()
	var layouts: Variant = book.get("layouts", {})
	if not (layouts is Dictionary):
		return {}
	var mint_floors: Variant = (layouts as Dictionary).get(str(mint), {})
	if not (mint_floors is Dictionary):
		return {}
	var floor: Variant = (mint_floors as Dictionary).get(str(floor_num), {})
	if floor is Dictionary:
		return floor
	return {}


func _suit(by_code: Dictionary, level: int, skeleton: bool) -> Dictionary:
	var low := maxi(level - 4, 1)
	var high := mini(level, 8)
	if high < low:
		high = low
	var code := _CASHBOTS[randi_range(low, high) - 1]
	var row: Variant = by_code.get(code)
	if not (row is Dictionary):
		return {}
	var source: Dictionary = row
	var body := str(source.get("body", "c"))
	var suit := {
		"code": code,
		"name": str(source.get("name", "Cog")),
		"dept": "m",
		"body": body,
		"height": float(source.get("height", 4.0)),
		"level": level,
	}
	if not skeleton:
		return suit
	suit["name"] = "Skelecog"
	suit["skeleton"] = true
	var model := "res://assets/cogs/suits/robot_%s.glb" % body
	var walk := "res://assets/cogs/anims/robot_%s/walk.walk" % body
	var neutral := "res://assets/cogs/anims/robot_%s/neutral.walk" % body
	if FileAccess.file_exists(model) and FileAccess.file_exists(walk) and FileAccess.file_exists(neutral):
		suit["model"] = model
		suit["walk"] = walk
		suit["neutral"] = neutral
		suit["scale"] = float(source.get("scale", 1.0))
	return suit


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}
