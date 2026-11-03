extends Node

## The district's Sellbot factory roster. One roll is shared by everyone in
## that district. A battle is the street fight, opened for the cog's battle cell.

const SLUG := "sellbot_factory"
const _LIST := "res://assets/cog_hq/sellbot_factory_cogs.json"
const _CATALOG := "res://assets/cogs/catalog.json"
const _SELLBOTS: PackedStringArray = ["cc", "tm", "nd", "gh", "ms", "tf", "m", "mh"]

var _rosters: Dictionary = {}


func ensure(district: int) -> void:
	if not ToonNet.is_authority():
		return
	if not _rosters.has(district):
		_rosters[district] = _roll_factory()
	_publish(district)


func rows(district: int) -> Array:
	var found: Variant = _rosters.get(district, [])
	if found is Array:
		return found
	return []


func dismiss(district: int, cog_id: int) -> void:
	if not ToonNet.is_authority():
		return
	var kept: Array = []
	for item in rows(district):
		if item is Dictionary and int((item as Dictionary).get("do_id", 0)) == cog_id:
			continue
		kept.append(item)
	_rosters[district] = kept
	_publish(district)


func engage(district: int, cog_id: int, origin: Vector3, yaw: float, peer: int, toon_name: String, hp: int, max_hp: int) -> void:
	ensure(district)
	var lead := _find(district, cog_id)
	if lead.is_empty():
		return
	var fights := get_node_or_null("../StreetFights")
	if fights == null or not fights.has_method("open_group"):
		return
	var spec: Dictionary = lead.get("cog", {})
	var cell := int(spec.get("cell", 0))
	var group: Array = [_battle_cog(lead, origin)]
	for item in rows(district):
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		var cog_spec: Dictionary = row.get("cog", {})
		if int(row.get("do_id", 0)) == cog_id or int(cog_spec.get("cell", -1)) != cell:
			continue
		if group.size() >= 4:
			break
		if fights.has_method("cog_paused") and bool(fights.call("cog_paused", int(row.get("do_id", 0)))):
			continue
		group.append(_battle_cog(row, origin))
	fights.call("open_group", district, SLUG, group, peer, toon_name, hp, max_hp, origin, yaw)


func _battle_cog(row: Dictionary, origin: Vector3) -> Dictionary:
	var spec: Dictionary = row.get("cog", {})
	return {
		"id": int(row.get("do_id", 0)),
		"code": String(spec.get("code", "")),
		"name": String(spec.get("name", "Cog")),
		"level": int(spec.get("level", 1)),
		"dept": String(spec.get("dept", "s")),
		"body": String(spec.get("body", "c")),
		"height": float(spec.get("height", 4.0)),
		"pos": [origin.x, origin.y, origin.z],
	}


func _find(district: int, cog_id: int) -> Dictionary:
	for item in rows(district):
		if item is Dictionary and int((item as Dictionary).get("do_id", 0)) == cog_id:
			return item
	return {}


func _publish(district: int) -> void:
	ToonNet.publish("suits:%d:%s" % [district, SLUG], {"rows": rows(district)})


func _roll_factory() -> Array:
	var catalog := _read_json(_CATALOG)
	var data := _read_json(_LIST)
	var by_code := {}
	for item in catalog.get("cogs", []):
		if item is Dictionary:
			by_code[str((item as Dictionary)["code"])] = item
	var roster: Array = []
	var next_id := 1
	for item in data.get("cogs", []):
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item
		var suit := _suit(by_code, int(spec.get("level", 1)), int(spec.get("skeleton", 0)) == 1)
		if suit.is_empty():
			continue
		suit["parent"] = int(spec.get("parent", 0))
		suit["pos"] = spec.get("pos", [0.0, 0.0, 0.0])
		suit["h"] = float(spec.get("h", 0.0))
		suit["behavior"] = str(spec.get("behavior", "walk"))
		suit["path"] = int(spec.get("path", 0))
		suit["cell"] = int(spec.get("cell", 0))
		roster.append({
			"do_id": next_id,
			"phase": 1,
			"position": [0.0, 0.0, 0.0],
			"yaw": 0.0,
			"cog": suit,
		})
		next_id += 1
	return roster


func _suit(by_code: Dictionary, level: int, skeleton: bool) -> Dictionary:
	var low := maxi(level - 4, 1)
	var high := mini(level, 8)
	if high < low:
		high = low
	var code := _SELLBOTS[randi_range(low, high) - 1]
	var row: Variant = by_code.get(code)
	if not (row is Dictionary):
		return {}
	var source: Dictionary = row
	var body := str(source.get("body", "c"))
	var suit := {
		"code": code,
		"name": str(source.get("name", "Cog")),
		"dept": "s",
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
