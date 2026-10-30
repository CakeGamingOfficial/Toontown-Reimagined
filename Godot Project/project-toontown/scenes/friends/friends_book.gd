class_name FriendsBook
extends RefCounted

## One toon's friends, saved beside the toon slots. True Friend codes are the
## original secret: one use, two days, and typing one makes both toons friends.
## Online flags stay false until another player can actually be in the world.

const MAX_FRIENDS := 50
const _CODES_PER_DAY := 5
const _CODE_LIFE := 2 * 24 * 60 * 60
const _PATH := "user://friends.json"
const _LETTERS := "ABCDEFGHJKLMNPQRSTUVWXYZ"

static var _loaded := false
static var _slots: Dictionary = {}
static var _secrets: Array = []
static var _inbox: Dictionary = {}


static func count() -> int:
	return _mine().size()


## A whisper addressed to another toon on this machine waits until that toon plays.
static func leave_whisper(slot: int, from_name: String, text: String) -> void:
	if slot < 0:
		return
	var spoken := text.strip_edges()
	if spoken == "":
		return
	_ensure()
	var key := str(slot)
	var pile: Array = _inbox.get(key, [])
	pile.append({"from": from_name, "text": spoken})
	_inbox[key] = pile
	_save()


static func take_incoming() -> Array:
	_ensure()
	var key := _key()
	var found: Variant = _inbox.get(key, [])
	if typeof(found) != TYPE_ARRAY or (found as Array).is_empty():
		return []
	var pile: Array = found
	_inbox.erase(key)
	_save()
	return pile


static func page(which: int) -> Array:
	var rows: Array = []
	for friend in _mine():
		var record: Dictionary = friend
		var ignored := bool(record.get("ignored", false))
		var online := bool(record.get("online", false))
		if which == 0:
			continue
		if which == 1 and online and not ignored:
			rows.append(record)
		elif which == 2 and not ignored:
			rows.append(record)
		elif which == 5 and ignored:
			rows.append(record)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _shown_name(a).nocasecmp_to(_shown_name(b)) < 0
	)
	return rows


static func shown_name(friend: Dictionary) -> String:
	return _shown_name(friend)


static func is_online(friend: Dictionary) -> bool:
	return bool(friend.get("online", false))


static func is_true_friend(friend: Dictionary) -> bool:
	return bool(friend.get("true_friend", false))


static func cog_id(cog_name: String) -> String:
	return "cog:" + cog_name.strip_edges()


static func has_id(friend_id: String) -> bool:
	for item in _mine():
		var record: Dictionary = item
		if String(record.get("id", "")) == friend_id:
			return true
	return false


## A cog who says yes is only a name on the list. Nothing else treats them as a friend.
static func add_cog(cog_name: String) -> bool:
	_ensure()
	var friend_name := cog_name.strip_edges()
	if friend_name == "" or count() >= MAX_FRIENDS:
		return false
	var friend_id := cog_id(friend_name)
	if has_id(friend_id):
		return false
	var rows: Array = _list_for(_key())
	rows.append({
		"id": friend_id,
		"name": friend_name,
		"slot": -1,
		"online": false,
		"true_friend": false,
		"ignored": false,
	})
	_slots[_key()] = rows
	_save()
	return true


static func remove_friend(friend_id: String) -> void:
	_ensure()
	var mine: Array = _mine()
	var other_slot := -1
	for index in range(mine.size() - 1, -1, -1):
		var record: Dictionary = mine[index]
		if String(record.get("id", "")) != friend_id:
			continue
		other_slot = int(record.get("slot", -1))
		mine.remove_at(index)
	_slots[_key()] = mine
	if other_slot >= 0:
		var theirs: Array = _list_for(str(other_slot))
		var back := "slot:" + _key()
		for index in range(theirs.size() - 1, -1, -1):
			var record: Dictionary = theirs[index]
			if String(record.get("id", "")) == back:
				theirs.remove_at(index)
		_slots[str(other_slot)] = theirs
	_save()


static func make_secret() -> String:
	_ensure()
	var today := _today()
	var made := 0
	for item in _secrets:
		var secret: Dictionary = item
		if String(secret.get("owner", "")) == _key() and String(secret.get("day", "")) == today:
			made += 1
	if made >= _CODES_PER_DAY:
		return ""
	var code := _fresh_code()
	var style := ToonRoster.selected_style()
	var owner_name := style.display_name() if style != null else "Toon"
	_secrets.append({
		"code": code,
		"owner": _key(),
		"owner_name": owner_name,
		"day": today,
		"expires": int(Time.get_unix_time_from_system()) + _CODE_LIFE,
		"used": false,
	})
	_save()
	return code


static func redeem(typed: String) -> String:
	_ensure()
	var wanted := _normalize(typed)
	if wanted == "":
		return "That's not anyone's True Friend Code.  Are you sure you spelled it correctly?\n\nIf you did type it correctly, it may have expired.  Ask your friend to get a new True Friend Code for you (or get a new one yourself and give it to your friend)."
	for item in _secrets:
		var secret: Dictionary = item
		if _normalize(String(secret.get("code", ""))) != wanted:
			continue
		if bool(secret.get("used", false)) or int(secret.get("expires", 0)) < int(Time.get_unix_time_from_system()):
			return "That's not anyone's True Friend Code.  Are you sure you spelled it correctly?\n\nIf you did type it correctly, it may have expired.  Ask your friend to get a new True Friend Code for you (or get a new one yourself and give it to your friend)."
		var owner := String(secret.get("owner", ""))
		if owner == _key():
			secret["used"] = true
			_save()
			return "You just typed in your own True Friend Code!  Now no one else can use that True Friend Code."
		if count() >= MAX_FRIENDS or _list_for(owner).size() >= MAX_FRIENDS:
			return "You can't be friends because one of you has too many friends on your friends list."
		secret["used"] = true
		var owner_name := String(secret.get("owner_name", "Toon"))
		var owner_slot := int(owner) if owner.is_valid_int() else -1
		if owner_slot >= 0:
			var owner_style := ToonRoster.get_slot(owner_slot)
			if owner_style != null:
				owner_name = owner_style.display_name()
		_link(_key(), owner, owner_name, owner_slot)
		var mine := ToonRoster.selected_style()
		var my_name := mine.display_name() if mine != null else "Toon"
		var my_slot := ToonRoster.selected_index()
		_link(owner, _key(), my_name, my_slot)
		_save()
		return "You are now True Friends with %s!" % owner_name
	return "That's not anyone's True Friend Code.  Are you sure you spelled it correctly?\n\nIf you did type it correctly, it may have expired.  Ask your friend to get a new True Friend Code for you (or get a new one yourself and give it to your friend)."


static func _link(host: String, friend_key: String, friend_name: String, friend_slot: int) -> void:
	var rows: Array = _list_for(host)
	var friend_id := "slot:" + friend_key
	for item in rows:
		var record: Dictionary = item
		if String(record.get("id", "")) == friend_id:
			record["name"] = friend_name
			record["true_friend"] = true
			record["ignored"] = false
			_slots[host] = rows
			return
	rows.append({
		"id": friend_id,
		"name": friend_name,
		"slot": friend_slot,
		"online": false,
		"true_friend": true,
		"ignored": false,
	})
	_slots[host] = rows


static func _shown_name(friend: Dictionary) -> String:
	var slot := int(friend.get("slot", -1))
	if slot >= 0:
		var style := ToonRoster.get_slot(slot)
		if style != null:
			return style.display_name()
	var stored := String(friend.get("name", "")).strip_edges()
	if stored == "":
		return "Toon"
	return stored


static func _mine() -> Array:
	_ensure()
	return _list_for(_key())


static func _list_for(key: String) -> Array:
	var found: Variant = _slots.get(key, [])
	if typeof(found) != TYPE_ARRAY:
		return []
	return found


static func _key() -> String:
	var index := ToonRoster.selected_index()
	if index < 0:
		return "guest"
	return str(index)


static func _today() -> String:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [int(now.get("year", 0)), int(now.get("month", 0)), int(now.get("day", 0))]


static func _fresh_code() -> String:
	var first := ""
	var second := ""
	for _i in 4:
		first += _LETTERS[randi() % _LETTERS.length()]
		second += _LETTERS[randi() % _LETTERS.length()]
	return "TT " + first + " " + second


static func _normalize(code: String) -> String:
	var cleaned := ""
	for piece in code.to_upper().split(" ", false):
		if cleaned != "":
			cleaned += " "
		cleaned += piece
	return cleaned


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_slots = {}
	_secrets = []
	_inbox = {}
	if not FileAccess.file_exists(_PATH):
		return
	var file := FileAccess.open(_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var body: Dictionary = parsed
	var stored: Variant = body.get("slots", {})
	if typeof(stored) == TYPE_DICTIONARY:
		_slots = stored
	var secrets: Variant = body.get("secrets", [])
	if typeof(secrets) == TYPE_ARRAY:
		_secrets = secrets
	var inbox: Variant = body.get("inbox", {})
	if typeof(inbox) == TYPE_DICTIONARY:
		_inbox = inbox


static func _save() -> void:
	var file := FileAccess.open(_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"slots": _slots, "secrets": _secrets, "inbox": _inbox}, "  "))
