class_name CatalogCloset
extends RefCounted

## What this toon has bought from Clarabelle. An order waits in the mailbox
## until it is accepted, and accepting it wears the clothes.
## Records are keyed by the toon's avatar id. A pick-a-toon slot is only a
## seat, so a new toon made there must not inherit the last toon's closet.
## The toon slot file is left alone, because writing it clears jellybeans and tasks.

const _PATH := "user://catalog.json"
const _MAIL := "user://mailbox.json"
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
static var _mail_loaded := false
static var _mail: Dictionary = {}


static func owns(item: Dictionary) -> bool:
	if _pending(item):
		return true
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


## Catalog purchases land in the mailbox. The closet changes when the mail is accepted.
static func order(item: Dictionary) -> void:
	var owner := _slot()
	if owner <= 0:
		return
	var rows := _slot_rows()
	var posted := item.duplicate(true)
	posted["due"] = int(Time.get_unix_time_from_system()) + _delivery_seconds(String(item.get("kind", "")))
	rows.append(posted)
	_mail[str(owner)] = rows
	_write_mail()


static func mail_count() -> int:
	return mail_rows().size()


static func mail_waiting() -> int:
	return _slot_rows().size() - mail_rows().size()


static func mail_rows() -> Array:
	var ready: Array = []
	for row in _slot_rows():
		if row is Dictionary and _arrived(row):
			ready.append(row)
	return ready


static func take_mail(style: ToonStyle) -> int:
	var owner := _slot()
	if owner <= 0:
		return 0
	var kept: Array = []
	var taken: Array = []
	for row in _slot_rows():
		if row is Dictionary and _arrived(row):
			taken.append(row)
		else:
			kept.append(row)
	_mail[str(owner)] = kept
	_write_mail()
	for item in taken:
		if item is Dictionary:
			buy(style, item)
	return taken.size()


static func buy(style: ToonStyle, item: Dictionary) -> void:
	var owner := _slot()
	if owner <= 0:
		return
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
	_book[str(owner)] = row
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
	var owner := _slot()
	if owner <= 0:
		return {}
	var key := str(owner)
	var row: Dictionary = _book.get(key, {})
	_book[key] = row
	return row


## The closet follows the toon. The slot index is only where they sit on the
## Pick a Toon screen.
static func _slot() -> int:
	return ToonRoster.avatar_id()


static func _list(row: Dictionary, key: String) -> Array:
	var value: Variant = row.get(key, [])
	return value as Array if value is Array else []


static func _dict(row: Dictionary, key: String) -> Dictionary:
	var value: Variant = row.get(key, {})
	return value as Dictionary if value is Dictionary else {}


static func _slot_rows() -> Array:
	_ensure_mail()
	var owner := _slot()
	if owner <= 0:
		return []
	var value: Variant = _mail.get(str(owner), [])
	if value is Array:
		return value
	return []


## A deleted or replaced toon takes their closet with them. Slot-index records
## from older saves are dropped too, so the next toon in that seat starts bare.
static func reset_slot(index: int) -> void:
	_ensure()
	if index < 0 or index >= ToonRoster.SLOT_COUNT:
		return
	var keys: Array[String] = [str(index)]
	var style := ToonRoster.get_slot(index)
	if style != null and style.av_id > 0:
		keys.append(str(style.av_id))
	var changed := false
	var mail_changed := false
	for key in keys:
		if _book.has(key):
			_book.erase(key)
			changed = true
		if _mail.has(key):
			_mail.erase(key)
			mail_changed = true
	if changed:
		_write()
	if mail_changed:
		_write_mail()


static func _arrived(item: Dictionary) -> bool:
	return int(item.get("due", 0)) <= int(Time.get_unix_time_from_system())


## getDeliveryTime is in minutes. Clothes and wallpaper take an hour.
## Furniture and fishing poles take a day. SpeedChat phrases are ready now.
static func _delivery_seconds(kind: String) -> int:
	if kind == "furniture" or kind == "pole":
		return 24 * 60 * 60
	if kind == "emote" or kind == "phrase" or kind == "nametag":
		return 0
	return 60 * 60


static func _pending(item: Dictionary) -> bool:
	var token := _token(item)
	var piece := String(item.get("piece", ""))
	var worn := String(item.get("slot", ""))
	for row in _slot_rows():
		if not (row is Dictionary):
			continue
		var other: Dictionary = row
		if _token(other) != token:
			continue
		if String(other.get("piece", "")) != piece:
			continue
		if String(other.get("slot", "")) != worn:
			continue
		return true
	return false


static func _ensure_mail() -> void:
	if _mail_loaded:
		return
	_mail_loaded = true
	if not FileAccess.file_exists(_MAIL):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_MAIL))
	if parsed is Dictionary:
		_mail = parsed


static func _write_mail() -> void:
	var file := FileAccess.open(_MAIL, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_mail))


static func catalog_tokens() -> PackedStringArray:
	var tokens := PackedStringArray()
	for item in _list(_row(), "catalog"):
		tokens.append(String(item))
	return tokens


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
	if FileAccess.file_exists(_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_PATH))
		if parsed is Dictionary:
			_book = parsed
	_ensure_mail()
	_rekey_owners()


## Older saves stored the closet under the pick-a-toon slot. Bind that record
## to the toon sitting there now, then forget the slot key.
static func _rekey_owners() -> void:
	var changed := false
	var mail_changed := false
	for index in ToonRoster.SLOT_COUNT:
		var key := str(index)
		var style := ToonRoster.get_slot(index)
		if style == null or style.av_id <= 0:
			continue
		var dest := str(style.av_id)
		if dest == key:
			continue
		if _book.has(key):
			if not _book.has(dest):
				_book[dest] = _book[key]
			_book.erase(key)
			changed = true
		if _mail.has(key):
			if not _mail.has(dest):
				_mail[dest] = _mail[key]
			_mail.erase(key)
			mail_changed = true
	if changed:
		_write()
	if mail_changed:
		_write_mail()


static func _write() -> void:
	var file := FileAccess.open(_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_book))
