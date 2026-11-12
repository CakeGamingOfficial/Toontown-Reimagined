class_name FriendsBook
extends RefCounted

## One toon's friends, saved on that toon. True Friend codes are the
## original secret: one use, two days, and typing one makes both toons friends.
## A friend whose id starts with av: is someone in a district. A toon: id is
## another toon on this machine. Codes saved here still work while offline.

const MAX_FRIENDS := 50
const _CODES_PER_DAY := 5
const _CODE_LIFE := 2 * 24 * 60 * 60
const _PATH := "user://friends.json"
const _LETTERS := "ABCDEFGHJKLMNPQRSTUVWXYZ"

static var _loaded := false
static var _rekeyed := false
static var _slots: Dictionary = {}
static var _secrets: Array = []
static var _inbox: Dictionary = {}
static var _session_ignored: Dictionary = {}


static func count() -> int:
	return _mine().size()


## FriendQuest counts a toon on the list. A cog who said yes does not.
static func toon_friend_count() -> int:
	var total := 0
	for item in _mine():
		var record: Dictionary = item
		if String(record.get("id", "")).begins_with("av:"):
			total += 1
	return total


## A whisper addressed to another toon on this machine waits until that toon plays.
static func leave_whisper(avatar: int, from_name: String, text: String) -> void:
	if avatar <= 0:
		return
	var spoken := text.strip_edges()
	if spoken == "":
		return
	_ensure()
	var key := str(avatar)
	var pile: Array = _inbox.get(key, [])
	pile.append({"from": from_name, "text": spoken})
	_inbox[key] = pile
	_save()


static func take_incoming() -> Array:
	_ensure()
	var key := _key()
	if key == "":
		return []
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
		var online := is_online(record)
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
	var friend_id := String(friend.get("id", ""))
	if friend_id.begins_with("av:"):
		return ToonSocial.online(int(friend_id.trim_prefix("av:")))
	return bool(friend.get("online", false))


static func avatar_of(friend: Dictionary) -> int:
	var friend_id := String(friend.get("id", ""))
	if friend_id.begins_with("av:"):
		return int(friend_id.trim_prefix("av:"))
	return 0


## Another toon saved on this machine. Their list is theirs, not the slot's.
static func local_id(friend: Dictionary) -> int:
	var friend_id := String(friend.get("id", ""))
	if friend_id.begins_with("toon:"):
		return int(friend_id.trim_prefix("toon:"))
	return 0


static func true_friend_of(av: int) -> bool:
	if av <= 0:
		return false
	var wanted := "av:%d" % av
	for item in _mine():
		var record: Dictionary = item
		if String(record.get("id", "")) == wanted and bool(record.get("true_friend", false)):
			return not bool(record.get("ignored", false))
	return false


## IgnorePanelAddIgnore lasts for this session, then chat from that toon is dropped.
static func ignore_for_session(av: int, on: bool) -> void:
	if av <= 0:
		return
	if on:
		_session_ignored[av] = true
	else:
		_session_ignored.erase(av)


static func ignored_av(av: int) -> bool:
	if av <= 0:
		return false
	if _session_ignored.has(av):
		return true
	var wanted := "av:%d" % av
	for item in _mine():
		var record: Dictionary = item
		if String(record.get("id", "")) == wanted:
			return bool(record.get("ignored", false))
	return false


## A district friend. true_friend is only set by a True Friend code.
static func add_avatar(av: int, friend_name: String, true_friend: bool) -> bool:
	if av <= 0 or av == ToonRoster.avatar_id() or _key() == "":
		return false
	_ensure()
	var friend_id := "av:%d" % av
	var rows: Array = _mine()
	for item in rows:
		var record: Dictionary = item
		if String(record.get("id", "")) != friend_id:
			continue
		record["name"] = friend_name
		record["ignored"] = false
		if true_friend:
			record["true_friend"] = true
		_slots[_key()] = rows
		_save()
		ToonTasks.notify_friend()
		return true
	if rows.size() >= MAX_FRIENDS:
		return false
	rows.append({
		"id": friend_id,
		"name": friend_name,
		"slot": -1,
		"online": false,
		"true_friend": true_friend,
		"ignored": false,
	})
	_slots[_key()] = rows
	_save()
	ToonTasks.notify_friend()
	return true


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
	if _key() == "":
		return false
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
	var mine_key := _key()
	if mine_key == "":
		return
	var mine: Array = _mine()
	var other_key := ""
	if friend_id.begins_with("toon:"):
		other_key = friend_id.trim_prefix("toon:")
	for index in range(mine.size() - 1, -1, -1):
		var record: Dictionary = mine[index]
		if String(record.get("id", "")) != friend_id:
			continue
		mine.remove_at(index)
	_slots[mine_key] = mine
	if other_key != "":
		var theirs: Array = _list_for(other_key)
		var back := "toon:" + mine_key
		for index in range(theirs.size() - 1, -1, -1):
			var record: Dictionary = theirs[index]
			if String(record.get("id", "")) == back:
				theirs.remove_at(index)
		_slots[other_key] = theirs
	_save()


static func make_secret() -> String:
	_ensure()
	if _key() == "":
		return ""
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
		var owner_style := _style_for_key(owner)
		if owner_style != null:
			owner_name = owner_style.display_name()
		_link(_key(), owner, owner_name)
		var mine := ToonRoster.selected_style()
		var my_name := mine.display_name() if mine != null else "Toon"
		_link(owner, _key(), my_name)
		_save()
		return "You are now True Friends with %s!" % owner_name
	return "That's not anyone's True Friend Code.  Are you sure you spelled it correctly?\n\nIf you did type it correctly, it may have expired.  Ask your friend to get a new True Friend Code for you (or get a new one yourself and give it to your friend)."


static func _link(host: String, friend_key: String, friend_name: String) -> void:
	if host == "" or friend_key == "":
		return
	var rows: Array = _list_for(host)
	var friend_id := "toon:" + friend_key
	for item in rows:
		var record: Dictionary = item
		if String(record.get("id", "")) == friend_id:
			record["name"] = friend_name
			record["true_friend"] = true
			record["ignored"] = false
			record["slot"] = -1
			_slots[host] = rows
			return
	rows.append({
		"id": friend_id,
		"name": friend_name,
		"slot": -1,
		"online": false,
		"true_friend": true,
		"ignored": false,
	})
	_slots[host] = rows


static func _shown_name(friend: Dictionary) -> String:
	var local := local_id(friend)
	if local > 0:
		var style := _style_for_id(local)
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
	var owner := ToonRoster.avatar_id()
	if owner <= 0:
		return ""
	return str(owner)


static func _style_for_id(avatar: int) -> ToonStyle:
	if avatar <= 0:
		return null
	for index in ToonRoster.SLOT_COUNT:
		var style := ToonRoster.get_slot(index)
		if style != null and style.av_id == avatar:
			return style
	return null


static func _style_for_key(key: String) -> ToonStyle:
	if not key.is_valid_int():
		return null
	return _style_for_id(int(key))


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
	if not _loaded:
		_loaded = true
		_slots = {}
		_secrets = []
		_inbox = {}
		if FileAccess.file_exists(_PATH):
			var file := FileAccess.open(_PATH, FileAccess.READ)
			if file != null:
				var parsed: Variant = JSON.parse_string(file.get_as_text())
				if typeof(parsed) == TYPE_DICTIONARY:
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
	if not _rekeyed:
		_rekeyed = _rekey_owners()


## Older saves stored the list under the pick-a-toon slot. Bind it to the toon
## sitting there now. An empty seat does not keep a list for the next toon.
static func _rekey_owners() -> bool:
	var occupied := false
	var seat_owner := {}
	for index in ToonRoster.SLOT_COUNT:
		var style := ToonRoster.get_slot(index)
		if style == null or style.av_id <= 0:
			continue
		occupied = true
		seat_owner[str(index)] = str(style.av_id)
	if not occupied:
		return false
	var changed := false
	for index in ToonRoster.SLOT_COUNT:
		var from := str(index)
		if seat_owner.has(from):
			var dest: String = seat_owner[from]
			if _slots.has(from):
				if not _slots.has(dest):
					_slots[dest] = _slots[from]
				_slots.erase(from)
				changed = true
			if _inbox.has(from):
				if not _inbox.has(dest):
					_inbox[dest] = _inbox[from]
				_inbox.erase(from)
				changed = true
		else:
			if _slots.has(from):
				_slots.erase(from)
				changed = true
			if _inbox.has(from):
				_inbox.erase(from)
				changed = true
	for host in _slots.keys():
		var rows: Array = _list_for(String(host))
		var row_changed := false
		for item in rows:
			if not (item is Dictionary):
				continue
			var record: Dictionary = item
			var friend_id := String(record.get("id", ""))
			if friend_id.begins_with("slot:"):
				var seat := friend_id.trim_prefix("slot:")
				if seat_owner.has(seat):
					record["id"] = "toon:" + String(seat_owner[seat])
				else:
					record["id"] = "gone:" + seat
				record["slot"] = -1
				row_changed = true
			elif int(record.get("slot", -1)) >= 0:
				record["slot"] = -1
				row_changed = true
		if row_changed:
			_slots[String(host)] = rows
			changed = true
	for secret_index in _secrets.size():
		var secret: Dictionary = _secrets[secret_index]
		var owner := String(secret.get("owner", ""))
		if seat_owner.has(owner):
			secret["owner"] = String(seat_owner[owner])
			changed = true
		elif owner.is_valid_int() and int(owner) >= 0 and int(owner) < ToonRoster.SLOT_COUNT:
			secret["used"] = true
			changed = true
	if changed:
		_save()
	return true


## A deleted or replaced toon takes their friends with them.
static func reset_slot(index: int) -> void:
	_ensure()
	if index < 0 or index >= ToonRoster.SLOT_COUNT:
		return
	var keys: Array[String] = [str(index)]
	var style := ToonRoster.get_slot(index)
	var avatar := 0
	if style != null and style.av_id > 0:
		avatar = style.av_id
		keys.append(str(avatar))
	var changed := false
	for key in keys:
		if _slots.has(key):
			_slots.erase(key)
			changed = true
		if _inbox.has(key):
			_inbox.erase(key)
			changed = true
	var banned := {}
	banned["slot:%d" % index] = true
	if avatar > 0:
		banned["toon:%d" % avatar] = true
		banned["av:%d" % avatar] = true
	for secret_index in range(_secrets.size() - 1, -1, -1):
		var secret: Dictionary = _secrets[secret_index]
		if keys.has(String(secret.get("owner", ""))):
			_secrets.remove_at(secret_index)
			changed = true
	for host in _slots.keys():
		var rows: Array = _list_for(String(host))
		var kept: Array = []
		var dropped := false
		for item in rows:
			if not (item is Dictionary):
				kept.append(item)
				continue
			var record: Dictionary = item
			if banned.has(String(record.get("id", ""))):
				dropped = true
				continue
			kept.append(record)
		if dropped:
			_slots[String(host)] = kept
			changed = true
	if changed:
		_save()


static func _save() -> void:
	var file := FileAccess.open(_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"slots": _slots, "secrets": _secrets, "inbox": _inbox}, "  "))
