class_name CatalogCloset
extends RefCounted

## What this toon has bought from Clarabelle. Clothes are worn immediately.
## The toon slot file is left alone, because writing it clears jellybeans and tasks.

const _PATH := "user://catalog.json"
const _TANK := preload("res://scenes/fishing/fish_tank.gd")
const _EMOTE := [
	"Wave", "Happy", "Sad", "Angry", "Sleepy", "Shrug", "Dance", "Think", "Bored",
	"Applause", "Cringe", "Confused", "Belly Flop", "Bow", "Banana Peel",
	"Resistance Salute", "Laugh", "Yes", "No", "OK", "Surprise", "Cry", "Delighted",
	"Furious", "Laugh",
]
const _EMOTE_SAY := [
	"%s waves.", "%s is happy.", "%s is sad.", "%s is angry.", "%s is sleepy.",
	"%s shrugs.", "%s dances.", "%s thinks.", "%s is bored.", "%s applauds.",
	"%s cringes.", "%s is confused.", "%s does a belly flop.", "%s bows.",
	"%s slips on a banana peel.", "%s gives the resistance salute.", "%s laughs.",
	"%s says yes.", "%s says no.", "%s says OK.", "%s is surprised.", "%s cries.",
	"%s is delighted.", "%s is furious.", "%s laughs.",
]

static var _loaded := false
static var _book: Dictionary = {}


static func owns(item: Dictionary) -> bool:
	var row := _row()
	var kind := String(item.get("kind", ""))
	var item_id := int(item.get("id", -1))
	if kind == "clothing":
		return _list(row, "clothes").has(item_id)
	if kind == "accessory":
		return int(_dict(row, "accessories").get(String(item.get("slot", "")), -1)) == item_id
	if kind == "emote":
		return _list(row, "emotes").has(item_id)
	if kind == "phrase":
		return _phrase_ids(row).has(item_id)
	if kind == "nametag":
		return int(row.get("nametag", -1)) == item_id
	if kind == "pole":
		return _TANK.rod() >= item_id
	if _kept(kind):
		return _list(row, "catalog").has(_token(item))
	return false


static func buy(style: ToonStyle, item: Dictionary) -> void:
	var row := _row()
	var kind := String(item.get("kind", ""))
	var item_id := int(item.get("id", -1))
	if kind == "clothing":
		var clothes := _list(row, "clothes")
		if not clothes.has(item_id):
			clothes.append(item_id)
		row["clothes"] = clothes
		if String(item.get("piece", "")) == "shirt":
			row["shirt"] = item
			style.top_tex = int(item.get("tex", style.top_tex))
			style.top_color = int(item.get("color", style.top_color))
			style.top_map = String(item.get("map", ""))
			style.sleeve_map = String(item.get("sleeve", ""))
		else:
			row["bottom"] = item
			style.bot_tex = int(item.get("tex", style.bot_tex))
			style.bot_color = int(item.get("color", style.bot_color))
			style.bottom_map = String(item.get("map", ""))
			if style.torso.length() > 1:
				style.torso = style.torso.substr(0, 1) + ("d" if bool(item.get("skirt", false)) else "s")
	elif kind == "accessory":
		var worn := _dict(row, "accessories")
		worn[String(item.get("slot", ""))] = item_id
		row["accessories"] = worn
	elif kind == "emote":
		var emotes := _list(row, "emotes")
		if not emotes.has(item_id):
			emotes.append(item_id)
		row["emotes"] = emotes
	elif kind == "phrase":
		var lines := _phrase_rows(row)
		lines.append({"id": item_id, "text": String(item.get("name", ""))})
		row["phrases"] = lines
	elif kind == "nametag":
		row["nametag"] = item_id
		row["font"] = String(item.get("font", ""))
	elif kind == "pole":
		_TANK.set_rod(item_id)
	elif _kept(kind):
		var owned := _list(row, "catalog")
		var token := _token(item)
		if not owned.has(token):
			owned.append(token)
		row["catalog"] = owned
	_book[str(_slot())] = row
	_write()


static func dress(style: ToonStyle) -> void:
	if style == null:
		return
	var row := _row()
	var shirt: Dictionary = row.get("shirt", {})
	if not shirt.is_empty():
		style.top_tex = int(shirt.get("tex", style.top_tex))
		style.top_color = int(shirt.get("color", style.top_color))
		style.top_map = String(shirt.get("map", ""))
		style.sleeve_map = String(shirt.get("sleeve", ""))
	var bottom: Dictionary = row.get("bottom", {})
	if not bottom.is_empty():
		style.bot_tex = int(bottom.get("tex", style.bot_tex))
		style.bot_color = int(bottom.get("color", style.bot_color))
		style.bottom_map = String(bottom.get("map", ""))
		if style.torso.length() > 1:
			style.torso = style.torso.substr(0, 1) + ("d" if bool(bottom.get("skirt", false)) else "s")


static func emote_rows() -> Array:
	var rows: Array = []
	for item_id in _list(_row(), "emotes"):
		if item_id < 0 or item_id >= _EMOTE.size():
			continue
		rows.append({
			"text": _EMOTE[item_id],
			"say": _EMOTE_SAY[item_id],
			"emote": item_id,
		})
	return rows


static func phrase_rows() -> Array:
	var rows: Array = []
	for item in _phrase_rows(_row()):
		rows.append({"text": String(item.get("text", "")), "say": String(item.get("text", ""))})
	return rows


static func set_accessory(slot: String, item_id: int) -> void:
	var row := _row()
	var worn := _dict(row, "accessories")
	if item_id < 0:
		worn.erase(slot)
	else:
		worn[slot] = item_id
	row["accessories"] = worn
	_write()


static func wear_outfit(style: ToonStyle, shirt: Dictionary, bottom: Dictionary) -> void:
	var row := _row()
	_keep_piece(row, "shirt", shirt)
	_keep_piece(row, "bottom", bottom)
	_write()


static func _keep_piece(row: Dictionary, key: String, item: Dictionary) -> void:
	if item.is_empty():
		return
	row[key] = item
	var item_id := int(item.get("id", -1))
	if item_id < 0:
		return
	var clothes := _list(row, "clothes")
	if not clothes.has(item_id):
		clothes.append(item_id)
	row["clothes"] = clothes


static func accessory_ids() -> Dictionary:
	return _dict(_row(), "accessories").duplicate()


static func font_path() -> String:
	return String(_row().get("font", ""))


static func _row() -> Dictionary:
	_ensure()
	var key := str(_slot())
	var row: Dictionary = _book.get(key, {})
	_book[key] = row
	return row


static func _slot() -> int:
	return ToonRoster.selected_index()


static func _list(row: Dictionary, key: String) -> Array:
	var value: Variant = row.get(key, [])
	return value as Array if value is Array else []


static func _dict(row: Dictionary, key: String) -> Dictionary:
	var value: Variant = row.get(key, {})
	return value as Dictionary if value is Dictionary else {}


static func _token(item: Dictionary) -> String:
	return "%s:%d:%d" % [String(item.get("kind", "")), int(item.get("id", -1)), int(item.get("color_index", 0))]


static func _kept(kind: String) -> bool:
	return kind in ["furniture", "wallpaper", "flooring", "moulding", "wainscoting", "window", "trick"]


static func _phrase_rows(row: Dictionary) -> Array:
	return _list(row, "phrases")


static func _phrase_ids(row: Dictionary) -> Array:
	var ids: Array = []
	for item in _phrase_rows(row):
		if item is Dictionary:
			ids.append(int(item.get("id", -1)))
	return ids


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_PATH))
	if parsed is Dictionary:
		_book = parsed


static func _write() -> void:
	var file := FileAccess.open(_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_book))
