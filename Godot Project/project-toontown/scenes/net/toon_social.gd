extends Node
class_name ToonSocial

## FriendManager plus DistributedToon chat, on the district that is already
## hosting the session. SpeedChat phrases are understood by everyone nearby.
## Typed lines stay clear only for True Friends. Everyone else hears "blah",
## which is ChatGarblerDefault. Offline play keeps using the local friends file.

signal heard(from_name: String, text: String, whisper: bool)
signal invited(from_av: int, from_name: String, context: int)
signal invite_note(text: String)
signal secret_code(code: String)
signal secret_note(text: String)
signal dropped_friend(av: int)
signal card_ready(card: Dictionary)

const _LETTERS := "ABCDEFGHJKLMNPQRSTUVWXYZ"
const _CODES_PER_DAY := 5
const _CODE_LIFE := 2 * 24 * 60 * 60
const _UNKNOWN := "That's not anyone's True Friend Code.  Are you sure you spelled it correctly?\n\nIf you did type it correctly, it may have expired.  Ask your friend to get a new True Friend Code for you (or get a new one yourself and give it to your friend)."
const _OWN_CODE := "You just typed in your own True Friend Code!  Now no one else can use that True Friend Code."
const _TOO_MANY_CODES := "Sorry, you can't have any more True Friend Codes today.  You've already had more than your fair share!\n\nTry again tomorrow."
const _LIST_FULL := "You can't be friends because one of you has too many friends on your friends list."

static var visit_on := false
static var visit_scene := ""
static var visit_point := Vector3.ZERO
static var visit_heading := 0.0

var _codes: Array = []
var _made: Dictionary = {}
var _invites: Dictionary = {}
var _later: Dictionary = {}
var _context := 1


static func live() -> ToonSocial:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ToonSocialBus") as ToonSocial


static func online(av: int) -> bool:
	return not lookup(av).is_empty()


static func lookup(av: int) -> Dictionary:
	if av <= 0:
		return {}
	for channel in ToonNet.channels("toon:"):
		var state := ToonNet.latest(channel)
		if int(state.get("av", 0)) == av:
			return state
	return {}


func say(text: String, speedchat: bool) -> void:
	var spoken := text.strip_edges()
	if spoken == "":
		return
	_send({
		"kind": "say",
		"text": spoken,
		"speedchat": speedchat,
		"from_av": ToonRoster.avatar_id(),
		"from_name": _my_name(),
		"place": _place(),
		"district": ToonNet.district_id(),
	})


## DistributedToon.getAvatarDetails. The owner answers with laff and gag tracks.
func request_card(av: int) -> void:
	if av <= 0:
		return
	_send({
		"kind": "card_ask",
		"to_av": av,
		"from_av": ToonRoster.avatar_id(),
	})


func whisper(av: int, text: String, speedchat: bool) -> void:
	var spoken := text.strip_edges()
	if spoken == "" or av <= 0:
		return
	_send({
		"kind": "whisper",
		"text": spoken,
		"speedchat": speedchat,
		"to_av": av,
		"from_av": ToonRoster.avatar_id(),
		"from_name": _my_name(),
		"district": ToonNet.district_id(),
	})


func invite(av: int) -> void:
	if av <= 0:
		return
	_send({
		"kind": "invite",
		"to_av": av,
		"from_av": ToonRoster.avatar_id(),
		"from_name": _my_name(),
	})


func answer(context: int, yes: bool, reason: String) -> void:
	_send({
		"kind": "answer",
		"context": context,
		"yes": yes,
		"reason": reason,
		"from_av": ToonRoster.avatar_id(),
	})


func request_secret() -> void:
	_send({
		"kind": "secret_ask",
		"from_av": ToonRoster.avatar_id(),
		"from_name": _my_name(),
	})


func submit_secret(typed: String) -> void:
	_send({
		"kind": "secret_try",
		"code": typed,
		"from_av": ToonRoster.avatar_id(),
		"from_name": _my_name(),
	})


func unfriend(av: int) -> void:
	if av <= 0:
		return
	_send({
		"kind": "unfriend",
		"to_av": av,
		"from_av": ToonRoster.avatar_id(),
		"from_name": _my_name(),
	})


func _process(_delta: float) -> void:
	if not ToonNet.is_authority() or _later.is_empty():
		return
	var pending: Array = _later.keys()
	for av in pending:
		var peer := _peer_of(int(av))
		if peer <= 0:
			continue
		var pile: Array = _later[av]
		_later.erase(av)
		for item in pile:
			if item is Dictionary:
				_tell(peer, item)


func _send(msg: Dictionary) -> void:
	if not ToonNet.networked():
		return
	if ToonNet.is_authority():
		_handle(msg, ToonNet.peer_id())
		return
	_social_up.rpc_id(1, msg)


@rpc("any_peer", "reliable")
func _social_up(msg: Dictionary) -> void:
	if not ToonNet.is_authority():
		return
	var peer := multiplayer.get_remote_sender_id()
	var state := ToonNet.latest("toon:%d" % peer)
	var known := int(state.get("av", 0))
	if known > 0:
		msg["from_av"] = known
		var called := String(state.get("name", "")).strip_edges()
		if called != "":
			msg["from_name"] = called
	_handle(msg, peer)


@rpc("authority", "reliable")
func _social_down(msg: Dictionary) -> void:
	_show(msg)


func _handle(msg: Dictionary, from_peer: int) -> void:
	var kind := String(msg.get("kind", ""))
	if kind == "card_ask" or kind == "card_give" or kind == "card_fail":
		_route_card(msg, from_peer)
		return
	if kind == "say" or kind == "whisper":
		_relay_chat(msg, from_peer)
	elif kind == "invite":
		_relay_invite(msg, from_peer)
	elif kind == "answer":
		_relay_answer(msg, from_peer)
	elif kind == "secret_ask":
		_mint_secret(msg, from_peer)
	elif kind == "secret_try":
		_try_secret(msg, from_peer)
	elif kind == "unfriend":
		_relay_unfriend(msg)


func _route_card(msg: Dictionary, from_peer: int) -> void:
	var kind := String(msg.get("kind", ""))
	if kind == "card_ask":
		var target := int(msg.get("to_av", 0))
		var asker := int(msg.get("from_av", 0))
		var dest := _peer_of(target)
		if dest <= 0 or asker <= 0:
			_tell(from_peer, {"kind": "card_fail", "to_av": asker, "from_av": target})
			return
		_tell(dest, {"kind": "card_pull", "to_av": asker, "from_av": target})
		return
	_tell(_peer_of(int(msg.get("to_av", 0))), msg)


func _answer_card(asker: int) -> void:
	if asker <= 0:
		return
	var card := ToonLoadout.for_selected().detail_card()
	card["kind"] = "card_give"
	card["to_av"] = asker
	card["from_av"] = ToonRoster.avatar_id()
	_send(card)


func _relay_chat(msg: Dictionary, from_peer: int) -> void:
	var whisper := String(msg.get("kind", "")) == "whisper"
	for peer in _each_peer():
		if peer == from_peer:
			continue
		var state := ToonNet.latest("toon:%d" % peer)
		if state.is_empty():
			continue
		var their_av := int(state.get("av", 0))
		if whisper:
			if their_av != int(msg.get("to_av", 0)):
				continue
		else:
			if int(state.get("district", -99)) != int(msg.get("district", -1)):
				continue
			if String(state.get("place", "")) != String(msg.get("place", "")):
				continue
		_tell(peer, msg.duplicate())


func _relay_invite(msg: Dictionary, from_peer: int) -> void:
	var to_av := int(msg.get("to_av", 0))
	var dest := _peer_of(to_av)
	var called := _name_of(to_av)
	if dest <= 0:
		_tell(from_peer, {"kind": "note", "text": "%s went away." % called})
		return
	var context := _take_context()
	_invites[context] = {
		"from_peer": from_peer,
		"from_av": int(msg.get("from_av", 0)),
		"from_name": String(msg.get("from_name", "Toon")),
		"to_av": to_av,
		"to_peer": dest,
		"to_name": called,
	}
	_tell(from_peer, {"kind": "note", "text": "Asking %s to be your friend." % called})
	_tell(dest, {
		"kind": "invited",
		"from_av": int(msg.get("from_av", 0)),
		"from_name": String(msg.get("from_name", "Toon")),
		"context": context,
	})


func _relay_answer(msg: Dictionary, from_peer: int) -> void:
	var context := int(msg.get("context", 0))
	var pending: Variant = _invites.get(context, {})
	if not (pending is Dictionary) or (pending as Dictionary).is_empty():
		return
	var invite: Dictionary = pending
	_invites.erase(context)
	if int(invite.get("to_peer", 0)) != from_peer and int(invite.get("to_av", 0)) != int(msg.get("from_av", 0)):
		return
	var from_av := int(invite.get("from_av", 0))
	var to_av := int(invite.get("to_av", 0))
	var from_name := String(invite.get("from_name", "Toon"))
	var to_name := String(invite.get("to_name", "Toon"))
	if not bool(msg.get("yes", false)):
		var reason := String(msg.get("reason", "no"))
		var line := "%s said no, thank you." % to_name
		if reason == "full":
			line = "%s has too many friends already!" % to_name
		elif reason == "busy":
			line = "%s is busy right now; try again later." % to_name
		_tell(int(invite.get("from_peer", 0)), {"kind": "note", "text": line})
		return
	_give_friend(int(invite.get("from_peer", 0)), from_av, to_av, to_name, false, "You are now friends with %s!" % to_name)
	_give_friend(from_peer, to_av, from_av, from_name, false, "You are now friends with %s!" % from_name)


func _mint_secret(msg: Dictionary, from_peer: int) -> void:
	var av := int(msg.get("from_av", 0))
	var today := _today()
	var made: Dictionary = _made.get(av, {})
	var count := int(made.get("count", 0)) if String(made.get("day", "")) == today else 0
	if count >= _CODES_PER_DAY:
		_tell(from_peer, {"kind": "secret_note", "text": _TOO_MANY_CODES})
		return
	count += 1
	_made[av] = {"day": today, "count": count}
	var code := _fresh_code()
	_codes.append({
		"code": code,
		"av": av,
		"name": String(msg.get("from_name", "Toon")),
		"expires": int(Time.get_unix_time_from_system()) + _CODE_LIFE,
		"used": false,
	})
	_tell(from_peer, {"kind": "secret_code", "code": code})


func _try_secret(msg: Dictionary, from_peer: int) -> void:
	var wanted := _normalize(String(msg.get("code", "")))
	var redeemer := int(msg.get("from_av", 0))
	var redeemer_name := String(msg.get("from_name", "Toon"))
	if wanted == "":
		_tell(from_peer, {"kind": "secret_note", "text": _UNKNOWN})
		return
	for item in _codes:
		var secret: Dictionary = item
		if _normalize(String(secret.get("code", ""))) != wanted:
			continue
		if bool(secret.get("used", false)) or int(secret.get("expires", 0)) < int(Time.get_unix_time_from_system()):
			_tell(from_peer, {"kind": "secret_note", "text": _UNKNOWN})
			return
		var owner := int(secret.get("av", 0))
		var owner_name := String(secret.get("name", "Toon"))
		secret["used"] = true
		if owner == redeemer:
			_tell(from_peer, {"kind": "secret_note", "text": _OWN_CODE})
			return
		_give_friend(from_peer, redeemer, owner, owner_name, true, "You are now True Friends with %s!" % owner_name)
		_give_friend(_peer_of(owner), owner, redeemer, redeemer_name, true, "You are now True Friends with %s!" % redeemer_name)
		return
	_tell(from_peer, {"kind": "secret_note", "text": _UNKNOWN})


func _relay_unfriend(msg: Dictionary) -> void:
	var to_av := int(msg.get("to_av", 0))
	var note := {
		"kind": "drop",
		"av": int(msg.get("from_av", 0)),
		"name": String(msg.get("from_name", "Toon")),
	}
	var peer := _peer_of(to_av)
	if peer <= 0:
		_queue(to_av, note)
		return
	_tell(peer, note)


func _give_friend(peer: int, _host_av: int, other_av: int, other_name: String, true_friend: bool, text: String) -> void:
	var note := {
		"kind": "befriend",
		"av": other_av,
		"name": other_name,
		"true_friend": true_friend,
		"text": text,
	}
	if peer <= 0:
		_queue(_host_av, note)
		return
	_tell(peer, note)


func _queue(av: int, msg: Dictionary) -> void:
	if av <= 0:
		return
	var pile: Array = _later.get(av, [])
	pile.append(msg)
	_later[av] = pile


func _tell(peer: int, msg: Dictionary) -> void:
	if peer <= 0:
		return
	if peer == ToonNet.peer_id():
		_show(msg)
		return
	_social_down.rpc_id(peer, msg)


func _show(msg: Dictionary) -> void:
	var kind := String(msg.get("kind", ""))
	if kind == "say" or kind == "whisper":
		_show_chat(msg)
	elif kind == "note":
		invite_note.emit(String(msg.get("text", "")))
	elif kind == "invited":
		invited.emit(int(msg.get("from_av", 0)), String(msg.get("from_name", "Toon")), int(msg.get("context", 0)))
	elif kind == "befriend":
		var added := FriendsBook.add_avatar(int(msg.get("av", 0)), String(msg.get("name", "Toon")), bool(msg.get("true_friend", false)))
		var line := String(msg.get("text", ""))
		if not added:
			line = _LIST_FULL
		invite_note.emit(line)
	elif kind == "secret_code":
		secret_code.emit(String(msg.get("code", "")))
	elif kind == "secret_note":
		secret_note.emit(String(msg.get("text", "")))
	elif kind == "drop":
		dropped_friend.emit(int(msg.get("av", 0)))
	elif kind == "card_pull":
		_answer_card(int(msg.get("to_av", 0)))
	elif kind == "card_give" or kind == "card_fail":
		card_ready.emit(msg)


func _show_chat(msg: Dictionary) -> void:
	var from_av := int(msg.get("from_av", 0))
	if from_av == ToonRoster.avatar_id() or FriendsBook.ignored_av(from_av):
		return
	var whisper := String(msg.get("kind", "")) == "whisper"
	if whisper and not FriendsBook.has_id("av:%d" % from_av):
		return
	var text := String(msg.get("text", ""))
	if not bool(msg.get("speedchat", false)) and not FriendsBook.true_friend_of(from_av):
		text = _garble()
	var called := String(msg.get("from_name", "Toon"))
	if not whisper:
		_bubble(from_av, text)
	heard.emit(called, text, whisper)


func _bubble(av: int, text: String) -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var actor := _find_actor(tree.root, av)
	if actor == null:
		return
	actor.set_meta("chat_line", text)
	actor.set_meta("chat_until", Time.get_ticks_msec() + maxi(2800, text.length() * 45))
	ToonSpeech.speak(actor, text)


func _find_actor(node: Node, av: int) -> Node3D:
	if node is Node3D and int(node.get_meta("av", 0)) == av:
		return node as Node3D
	for child in node.get_children():
		var found := _find_actor(child, av)
		if found != null:
			return found
	return null


func _each_peer() -> Array[int]:
	var ids: Array[int] = []
	if multiplayer.multiplayer_peer == null:
		return ids
	ids.append(1)
	for peer in multiplayer.get_peers():
		ids.append(int(peer))
	return ids


func _peer_of(av: int) -> int:
	if av <= 0:
		return 0
	for channel in ToonNet.channels("toon:"):
		var state := ToonNet.latest(channel)
		if int(state.get("av", 0)) == av:
			return channel.trim_prefix("toon:").to_int()
	return 0


func _name_of(av: int) -> String:
	var state := lookup(av)
	var called := String(state.get("name", "")).strip_edges()
	if called == "":
		return "Toon"
	return called


func _my_name() -> String:
	var style := ToonRoster.selected_style()
	if style == null:
		return "Toon"
	return style.display_name()


func _place() -> String:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return ""
	return tree.current_scene.scene_file_path


func _take_context() -> int:
	_context += 1
	return _context


func _today() -> String:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [int(now.get("year", 0)), int(now.get("month", 0)), int(now.get("day", 0))]


func _fresh_code() -> String:
	var first := ""
	var second := ""
	for _i in 4:
		first += _LETTERS[randi() % _LETTERS.length()]
		second += _LETTERS[randi() % _LETTERS.length()]
	return "TT " + first + " " + second


func _normalize(code: String) -> String:
	var cleaned := ""
	for piece in code.to_upper().split(" ", false):
		if cleaned != "":
			cleaned += " "
		cleaned += piece
	return cleaned


func _garble() -> String:
	var words := randi_range(1, 7)
	var text := ""
	for index in words:
		if index > 0:
			text += " "
		text += "blah"
	return text
