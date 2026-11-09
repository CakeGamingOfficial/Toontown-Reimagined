extends Node

## The cogs for the country club floor the player is on. Stock options follow
## PromotionManagerAI: a finished Bossbot suit, then the course multiplier.
## The course bonus is paid once, when the Club President is dismissed.

const SLUG := "bossbot_course"
const _RUN := preload("res://scenes/cog_hq/course_run.gd")
const _CATALOG := "res://assets/cogs/catalog.json"
const _BOSSBOTS: PackedStringArray = ["f", "p", "ym", "mm", "ds", "hh", "cr", "tbc"]

var _rows: Array = []
var _sig := ""
var _boss_paid := false


func ensure(district: int) -> void:
	if not ToonNet.is_authority():
		return
	var plan: Dictionary = _RUN.floor_plan()
	var signature := "%d:%s" % [_RUN.serial, _RUN.floor_key()]
	if signature == _sig and not plan.is_empty():
		_publish(district)
		return
	_sig = signature
	_boss_paid = _RUN.boss_paid
	_rows = _roll(plan)
	_publish(district)


func rows(_district: int) -> Array:
	return _rows


func dismiss(district: int, cog_id: int) -> void:
	if not ToonNet.is_authority():
		return
	var kept: Array = []
	for item in _rows:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		if int(row.get("do_id", 0)) != cog_id:
			kept.append(row)
			continue
		_pay(row)
	_rows = kept
	_publish(district)


func remove_cell(district: int, piece: int, cell: int) -> void:
	if not ToonNet.is_authority():
		return
	var kept: Array = []
	for item in _rows:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		var spec: Dictionary = row.get("cog", {})
		if int(spec.get("piece", -1)) == piece and int(spec.get("cell", -2)) == cell:
			continue
		kept.append(row)
	_rows = kept
	_publish(district)


func reveal_cell(district: int, piece: int, cell: int) -> void:
	if not ToonNet.is_authority():
		return
	for item in _rows:
		if not (item is Dictionary):
			continue
		var spec: Dictionary = (item as Dictionary).get("cog", {})
		if int(spec.get("piece", -1)) == piece and int(spec.get("cell", -2)) == cell:
			spec["hidden"] = false
			spec["virtual"] = true
	_publish(district)


func engage(district: int, cog_id: int, origin: Vector3, yaw: float, peer: int, toon_name: String, hp: int, max_hp: int) -> void:
	ensure(district)
	var lead := _find(cog_id)
	if lead.is_empty():
		return
	var fights := get_node_or_null("../StreetFights")
	if fights == null or not fights.has_method("open_group"):
		return
	var spec: Dictionary = lead.get("cog", {})
	if bool(spec.get("hidden", false)):
		return
	var piece := int(spec.get("piece", -1))
	var cell := int(spec.get("cell", -1))
	var group: Array = [_battle_cog(lead, origin)]
	for item in _rows:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		var cog_spec: Dictionary = row.get("cog", {})
		if int(row.get("do_id", 0)) == cog_id:
			continue
		if int(cog_spec.get("piece", -2)) != piece or int(cog_spec.get("cell", -2)) != cell:
			continue
		if bool(cog_spec.get("hidden", false)):
			continue
		if group.size() >= 4:
			break
		if fights.has_method("cog_paused") and bool(fights.call("cog_paused", int(row.get("do_id", 0)))):
			continue
		group.append(_battle_cog(row, origin))
	fights.call("open_group", district, SLUG, group, peer, toon_name, hp, max_hp, origin, yaw)


func _pay(row: Dictionary) -> void:
	var spec: Dictionary = row.get("cog", {})
	if bool(spec.get("virtual", false)) or bool(spec.get("hidden", false)):
		return
	var levels: Array = [int(spec.get("level", 1))]
	var president := int(spec.get("boss", 0)) == 1 and not _boss_paid
	if president:
		_boss_paid = true
		_RUN.boss_paid = true
	var text := DisguisePage.grant_course(levels, _RUN.zone(), president)
	if text.is_empty():
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var toon := scene.get_node_or_null("PlaygroundToon")
	if toon != null and toon.has_method("show_notice"):
		toon.call("show_notice", text)


func _find(cog_id: int) -> Dictionary:
	for item in _rows:
		if item is Dictionary and int((item as Dictionary).get("do_id", 0)) == cog_id:
			return item
	return {}


func _battle_cog(row: Dictionary, origin: Vector3) -> Dictionary:
	var spec: Dictionary = row.get("cog", {})
	return {
		"id": int(row.get("do_id", 0)),
		"code": String(spec.get("code", "")),
		"name": String(spec.get("name", "Cog")),
		"level": int(spec.get("level", 1)),
		"dept": "c",
		"body": String(spec.get("body", "c")),
		"height": float(spec.get("height", 4.0)),
		"pos": [origin.x, origin.y, origin.z],
		"skeleton": bool(spec.get("skeleton", false)),
	}


func _publish(district: int) -> void:
	ToonNet.publish("suits:%d:%s" % [district, SLUG], {"rows": _rows})


func _roll(plan: Dictionary) -> Array:
	var catalog := _read(_CATALOG)
	var by_code := {}
	for item in catalog.get("cogs", []):
		if item is Dictionary:
			by_code[str((item as Dictionary)["code"])] = item
	var rooms: Dictionary = _RUN.book().get("rooms", {})
	var roster: Array = []
	var next_id := 1
	var piece_index := 0
	for item in plan.get("pieces", []):
		if not (item is Dictionary):
			continue
		var piece: Dictionary = item
		if str(piece.get("kind", "")) != "room":
			piece_index += 1
			continue
		var spec: Variant = rooms.get(str(int(piece.get("room", 0))), {})
		var cogs: Array = []
		if spec is Dictionary:
			cogs = (spec as Dictionary).get("cogs", [])
		for cog_item in cogs:
			if not (cog_item is Dictionary):
				continue
			var cog: Dictionary = cog_item
			var suit := _suit(by_code, int(cog.get("level", 1)), int(cog.get("skeleton", 0)) == 1)
			if suit.is_empty():
				continue
			suit["parent"] = int(cog.get("parent", 0))
			suit["pos"] = cog.get("pos", [0.0, 0.0, 0.0])
			suit["h"] = float(cog.get("h", 0.0))
			suit["cell"] = int(cog.get("cell", 0))
			suit["piece"] = piece_index
			suit["boss"] = int(cog.get("boss", 0))
			suit["revives"] = int(cog.get("revives", 0))
			suit["hidden"] = false
			suit["virtual"] = false
			roster.append({
				"do_id": next_id,
				"phase": 1,
				"position": [0.0, 0.0, 0.0],
				"yaw": 0.0,
				"cog": suit,
			})
			next_id += 1
		piece_index += 1
	return roster


func _suit(by_code: Dictionary, level: int, skeleton: bool) -> Dictionary:
	var low := maxi(level - 4, 1)
	var high := mini(level, 8)
	if high < low:
		high = low
	var code := _BOSSBOTS[randi_range(low, high) - 1]
	var row: Variant = by_code.get(code)
	if not (row is Dictionary):
		return {}
	var source: Dictionary = row
	var suit := {
		"code": code,
		"name": str(source.get("name", "Cog")),
		"dept": "c",
		"body": str(source.get("body", "c")),
		"height": float(source.get("height", 4.0)),
		"level": level,
	}
	if not skeleton:
		return suit
	suit["name"] = "Skelecog"
	suit["skeleton"] = true
	var body := str(suit["body"])
	var model := "res://assets/cogs/suits/robot_%s.glb" % body
	var walk := "res://assets/cogs/anims/robot_%s/walk.walk" % body
	var neutral := "res://assets/cogs/anims/robot_%s/neutral.walk" % body
	if FileAccess.file_exists(model) and FileAccess.file_exists(walk) and FileAccess.file_exists(neutral):
		suit["model"] = model
		suit["walk"] = walk
		suit["neutral"] = neutral
		suit["scale"] = float(source.get("scale", 1.0))
	return suit


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}
