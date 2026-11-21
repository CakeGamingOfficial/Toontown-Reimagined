class_name BoardingParty
extends Node

## DistributedBoardingParty for the Cog HQ elevators. The district keeps the
## groups. A leader invites toons in the same area, picks a car, and Go or a
## walk up to that car boards everybody together.

const _CANNOT_LEAVE := "You cannot leave this area because you are part of a Boarding Group."
const _ONLY_LEADER := "Only your group leader can\n decide when to board."
const _GROUP := [
	"Let's form a Boarding Group.",
	"Join my Boarding Group.",
	"Can you invite me to your Boarding Group?",
	"I'm already in a Boarding Group.",
	"Leave your Boarding Group.",
]
const _READY := [
	"We are boarding now.",
	"Where are we going?",
	"Are we ready?",
	"Let's Go!",
	"Don't leave this area or you will leave the Boarding Group.",
]

## FactoryLaffMinimums, and the boss lobbies take eight. One party per area.
const _ZONES := {
	"sellbot_factory_exterior.tscn": {
		"max": 4, "seats": 4, "kind": "factory", "promo": -1,
		"ride": "sellbot_factory.tscn",
		"names": ["Front Entrance", "Side Entrance"],
		"laff": [0, 31],
		"lets": ["Let's go to the Front Entrance.", "Let's go to the Side Entrance."],
		"going": ["We're going to the Front Entrance.", "We're going to the Side Entrance."],
	},
	"sellbot_lobby.tscn": {
		"max": 8, "seats": 8, "kind": "boss", "promo": 3,
		"ride": "sellbot_vp.tscn",
		"names": ["Senior V.P. Battle"],
		"laff": [0],
		"lets": ["Let's go to the Senior V.P Battle."],
		"going": ["We're going to the Senior V.P Battle."],
	},
	"cashbot_trainyard.tscn": {
		"max": 4, "seats": 4, "kind": "mint", "promo": -1,
		"ride": "cashbot_mint.tscn",
		"names": ["Coin Mint", "Dollar Mint", "Bullion Mint"],
		"laff": [0, 66, 71],
		"lets": ["Let's go to the Coin Mint.", "Let's go to the Dollar Mint.", "Let's go to the Bullion Mint."],
		"going": ["We're going to the Coin Mint.", "We're going to the Dollar Mint.", "We're going to the Bullion Mint."],
	},
	"cashbot_lobby.tscn": {
		"max": 8, "seats": 8, "kind": "boss", "promo": 2,
		"ride": "cashbot_cfo.tscn",
		"names": ["C.F.O. Battle"],
		"laff": [0],
		"lets": ["Let's go to the C.F.O. Battle."],
		"going": ["We're going to the C.F.O. Battle."],
	},
	"lawbot_da_lobby.tscn": {
		"max": 4, "seats": 4, "kind": "office", "promo": -1,
		"ride": "lawbot_office.tscn",
		"names": ["Lawbot A Office", "Lawbot B Office", "Lawbot C Office", "Lawbot D Office"],
		"laff": [0, 81, 86, 96],
		"lets": ["Let's go to the Lawbot A Office.", "Let's go to the Lawbot B Office.", "Let's go to the Lawbot C Office.", "Let's go to the Lawbot D Office."],
		"going": ["We're going to the Lawbot A Office.", "We're going to the Lawbot B Office.", "We're going to the Lawbot C Office.", "We're going to the Lawbot D Office."],
	},
	"lawbot_lobby.tscn": {
		"max": 8, "seats": 8, "kind": "boss", "promo": 1,
		"ride": "lawbot_cj.tscn",
		"names": ["Chief Justice Battle"],
		"laff": [0],
		"lets": ["Let's go to the Chief Justice Battle."],
		"going": ["We're going to the Chief Justice Battle."],
	},
	"bossbot_country_club.tscn": {
		"max": 4, "seats": 4, "kind": "course", "promo": -1,
		"ride": "bossbot_course.tscn",
		"names": ["Front Three", "Middle Six", "Back Nine"],
		"laff": [0, 101, 106],
		"lets": ["Let's go to the Front Three.", "Let's go to the Middle Six.", "Let's go to the Back Nine."],
		"going": ["We're going to the Front Three.", "We're going to the Middle Six.", "We're going to the Back Nine."],
	},
	"bossbot_lobby.tscn": {
		"max": 8, "seats": 8, "kind": "boss", "promo": 0,
		"ride": "bossbot_ceo.tscn",
		"names": ["C.E.O. Battle"],
		"laff": [0],
		"lets": ["Let's go to the C.E.O. Battle."],
		"going": ["We're going to the C.E.O. Battle."],
	},
}

var _groups: Array = []
var _notes: Array = []
var _next_note := 1
var _next_pull := 1
var _wait := 0.0


static func live() -> BoardingParty:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("StreetTraffic/BoardingParty") as BoardingParty


static func request(action: String, payload: Dictionary) -> void:
	ToonNet.boarding_act(action, payload)


static func scene_file() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return ""
	return tree.current_scene.scene_file_path.get_file()


static func zone_info(file: String = "") -> Dictionary:
	var key := file if file != "" else scene_file()
	var found: Variant = _ZONES.get(key, {})
	if found is Dictionary:
		return found
	return {}


static func phrases() -> Dictionary:
	var info := zone_info()
	if info.is_empty():
		return {}
	return {
		"group": _GROUP,
		"ready": _READY,
		"lets": info.get("lets", []),
		"going": info.get("going", []),
	}


static func snapshot() -> Dictionary:
	return ToonNet.latest("boarding:%d" % ToonNet.district_id())


static func my_group() -> Dictionary:
	var me := ToonNet.peer_id()
	for item in snapshot().get("groups", []):
		if item is Dictionary and _involved(item, me):
			return item
	return {}


static func has_active_group() -> bool:
	var group := my_group()
	if group.is_empty():
		return false
	return _members(group).size() > 1 and _members(group).has(ToonNet.peer_id())


static func leading() -> bool:
	var group := my_group()
	return not group.is_empty() and int(group.get("leader", -1)) == ToonNet.peer_id()


static func waiting_on_leader() -> bool:
	var group := my_group()
	if group.is_empty():
		return false
	var leader := int(group.get("leader", -1))
	if leader == ToonNet.peer_id():
		return false
	return _members(group).has(ToonNet.peer_id()) or _ids(group, "invites").has(ToonNet.peer_id())


static func dest_name(group: Dictionary) -> String:
	var info := zone_info(String(group.get("zone", "")))
	var names: Array = info.get("names", [])
	var index := clampi(int(group.get("dest", 0)), 0, maxi(names.size() - 1, 0))
	if index < 0 or index >= names.size():
		return ""
	return String(names[index])


static func allow_scene(path: String) -> bool:
	if not has_active_group():
		return true
	var info := zone_info(String(my_group().get("zone", "")))
	return path.get_file() == String(info.get("ride", ""))


static func warn_leave() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var toon := tree.current_scene.get_node_or_null("PlaygroundToon")
	if toon != null and toon.has_method("show_popup"):
		toon.call("show_popup", _CANNOT_LEAVE)


static func leader_line() -> String:
	return _ONLY_LEADER


## 1 means the toon may board. 0 means a rejection was already shown.
## -1 means this call showed it.
static func gate(toon: Node, file: String, dest: int, told: bool) -> int:
	if toon == null:
		return 0
	if waiting_on_leader():
		if not told and toon.has_method("show_popup"):
			toon.call("show_popup", _ONLY_LEADER)
		return -1 if not told else 0
	var need := need_laff(file, dest)
	if toon.has_method("battle_hp"):
		var hp: Vector2i = toon.call("battle_hp")
		if hp.x < need:
			if not told and toon.has_method("show_notice"):
				toon.call("show_notice", laff_line(need))
			return -1 if not told else 0
	var promo := int(zone_info(file).get("promo", -1))
	if promo >= 0 and not DisguisePage.ready_for_promotion(promo):
		if not told and toon.has_method("show_popup"):
			toon.call("show_popup", "You cannot board this elevator until you have earned a promotion.")
		return -1 if not told else 0
	return 1


static func laff_line(need: int) -> String:
	return "You need %d laff points to ride this elevator." % need


static func need_laff(file: String, dest: int) -> int:
	var laff: Array = zone_info(file).get("laff", [])
	if dest < 0 or dest >= laff.size():
		return 0
	return int(laff[dest])


static func approach(toon: Node, seat: Vector3) -> Vector3:
	if toon == null or not toon.has_method("battle_point"):
		return seat
	var here: Vector3 = toon.call("battle_point")
	if here.distance_to(seat) <= 25.0:
		return here
	var flat := here - seat
	flat.y = 0.0
	if flat.length_squared() < 0.01:
		flat = Vector3(0.0, 0.0, 1.0)
	var outside := seat + flat.normalized() * 4.0
	outside.y = here.y
	if toon.has_method("visit_friend"):
		toon.call("visit_friend", outside, 0.0)
	return outside


static func take_pull(seen: int) -> Dictionary:
	var group := my_group()
	if group.is_empty() or String(group.get("zone", "")) != scene_file():
		return {}
	var pull: Variant = group.get("pull", {})
	if not (pull is Dictionary) or (pull as Dictionary).is_empty():
		return {}
	var order: Dictionary = pull
	var token := int(order.get("token", 0))
	if token == 0 or token == seen:
		return {}
	if ToonNet.now() < float(order.get("at", 0.0)):
		return {}
	if not _members(group).has(ToonNet.peer_id()):
		return {}
	return order


static func roll() -> Dictionary:
	var found: Variant = my_group().get("roll", {})
	if found is Dictionary:
		return found
	return {}


func _process(delta: float) -> void:
	if not ToonNet.is_authority():
		return
	_wait -= delta
	_dispatch_pulls()
	if _wait > 0.0:
		return
	_wait = 0.4
	_drop_leavers()


func act_from(sender: int, action: String, payload: Dictionary) -> void:
	if not ToonNet.is_authority() or sender < 0:
		return
	var card := _card(sender)
	var zone := _file_of(card)
	match action:
		"invite":
			_invite(sender, int(payload.get("who", -1)), zone)
		"cancel":
			_cancel(sender, int(payload.get("who", -1)))
		"accept":
			_accept(sender, int(payload.get("leader", -1)))
		"reject":
			_reject(sender, int(payload.get("leader", -1)))
		"kick":
			_kick(sender, int(payload.get("who", -1)))
		"leave":
			_leave(sender)
		"dest":
			_dest(sender, int(payload.get("index", 0)))
		"go":
			_go(sender)
		"board":
			_board(sender, int(payload.get("dest", 0)))
	_publish(int(card.get("district", ToonNet.district_id())))


func drop(peer: int) -> void:
	if not ToonNet.is_authority() or peer < 0:
		return
	var group := _group_of(peer)
	if group.is_empty():
		return
	_remove(group, peer, false)
	_publish(int(group.get("district", ToonNet.district_id())))


func _invite(sender: int, invitee: int, zone: String) -> void:
	var info := zone_info(zone)
	if info.is_empty() or invitee < 0 or invitee == sender:
		return
	var theirs := _card(invitee)
	if _file_of(theirs) != zone:
		_tell(sender, "%s is not in this area." % _name(invitee))
		return
	if bool(theirs.get("held", false)):
		_tell(sender, "%s is currently busy; try again later." % _name(invitee))
		_tell(invitee, "%s tried to invite you to their Boarding Group." % _name(sender))
		return
	var other := _group_of(invitee)
	if not other.is_empty() and int(other.get("leader", -1)) != sender:
		if _members(other).size() > 1 and _members(other).has(invitee):
			_tell(sender, "%s is already in a different Boarding Group." % _name(invitee))
		elif _ids(other, "invites").has(invitee) or (_ids(other, "invites").size() > 0 and int(other.get("leader", -1)) == invitee):
			_tell(sender, "%s has a pending invite; try again later." % _name(invitee))
		else:
			_remove(other, invitee, false)
		if not _group_of(invitee).is_empty() and int(_group_of(invitee).get("leader", -1)) != sender:
			_tell(invitee, "%s tried to invite you to their Boarding Group." % _name(sender))
			return
	var group := _group_of(sender)
	if group.is_empty():
		group = _fresh(sender, zone, int(_card(sender).get("district", ToonNet.district_id())))
		_groups.append(group)
	elif int(group.get("leader", -1)) != sender and not _members(group).has(sender):
		_tell(sender, "You need to deal with the pending invitation first.")
		return
	if _ids(group, "kicked").has(invitee) and int(group.get("leader", -1)) != sender:
		_tell(sender, "%s had been removed by your leader. Only the leader can re-invite removed members." % _name(invitee))
		return
	if _members(group).size() >= int(info.get("max", 4)):
		_tell(sender, "Your Boarding Group is already full.")
		return
	if _ids(group, "invites").has(invitee) or _members(group).has(invitee):
		return
	var names: Array = info.get("names", [])
	if names.size() == 1:
		var reason := _qualify(invitee, sender, info, 0)
		if reason != "":
			_tell(sender, reason)
			return
		reason = _qualify(sender, sender, info, 0)
		if reason != "":
			_tell(sender, reason)
			return
	if int(group.get("leader", -1)) == sender:
		var kicked := _ids(group, "kicked")
		kicked.erase(invitee)
		group["kicked"] = kicked
	var invites := _ids(group, "invites")
	invites.append(invitee)
	group["invites"] = invites
	var asked: Dictionary = group.get("asked", {})
	asked[str(invitee)] = sender
	group["asked"] = asked
	for member in _members(group):
		if int(member) != sender:
			_tell(int(member), "%s has invited %s to the Boarding Group." % [_name(sender), _name(invitee)])


func _cancel(sender: int, invitee: int) -> void:
	var group := _group_of(sender)
	if group.is_empty() or invitee < 0:
		return
	_remove(group, invitee, false)
	_tell(invitee, "")


func _accept(sender: int, leader: int) -> void:
	var group := _find_leader(leader)
	if group.is_empty() or not _ids(group, "invites").has(sender):
		_tell(sender, "Something went wrong; try again later.")
		return
	if _members(group).has(sender):
		return
	var info := zone_info(String(group.get("zone", "")))
	if _members(group).size() >= int(info.get("max", 4)):
		_remove(group, sender, false)
		_tell(sender, "You cannot accept this invitation because the group is already full.")
		_tell(int(group.get("leader", leader)), "%s tried to accept your invitation but your group was full." % _name(sender))
		return
	var invites := _ids(group, "invites")
	invites.erase(sender)
	group["invites"] = invites
	var asked: Dictionary = group.get("asked", {})
	asked.erase(str(sender))
	group["asked"] = asked
	var members := _members(group)
	members.append(sender)
	group["members"] = members


func _reject(sender: int, leader: int) -> void:
	var group := _find_leader(leader)
	if group.is_empty():
		return
	_remove(group, sender, false)
	_tell(leader, "%s has rejected to join your Boarding Group." % _name(sender))


func _kick(sender: int, who: int) -> void:
	var group := _group_of(sender)
	if group.is_empty() or int(group.get("leader", -1)) != sender or who == sender:
		return
	if not _members(group).has(who) and not _ids(group, "invites").has(who):
		return
	var kicked := _ids(group, "kicked")
	if not kicked.has(who):
		kicked.append(who)
	group["kicked"] = kicked
	_remove(group, who, true)
	_tell(who, "You have been removed from the Boarding Group.")


func _leave(sender: int) -> void:
	var group := _group_of(sender)
	if group.is_empty():
		return
	_remove(group, sender, false)


func _dest(sender: int, index: int) -> void:
	var group := _group_of(sender)
	if group.is_empty() or int(group.get("leader", -1)) != sender:
		return
	if not (group.get("pull", {}) as Dictionary).is_empty():
		return
	var names: Array = zone_info(String(group.get("zone", ""))).get("names", [])
	if names.is_empty():
		return
	group["dest"] = posmod(index, names.size())


func _go(sender: int) -> void:
	var group := _group_of(sender)
	if group.is_empty() or int(group.get("leader", -1)) != sender:
		return
	if not (group.get("pull", {}) as Dictionary).is_empty():
		return
	var dest := int(group.get("dest", 0))
	var reason := _can_board(group, dest, false)
	if reason != "":
		_tell(sender, reason)
		return
	_start_pull(group, dest, 4.0)


func _board(sender: int, dest: int) -> void:
	var group := _group_of(sender)
	if group.is_empty() or int(group.get("leader", -1)) != sender:
		return
	if not (group.get("pull", {}) as Dictionary).is_empty():
		return
	var names: Array = zone_info(String(group.get("zone", ""))).get("names", [])
	if dest < 0 or dest >= names.size():
		return
	group["dest"] = dest
	var reason := _can_board(group, dest, true)
	if reason != "":
		_tell(sender, reason)
		return
	_start_pull(group, dest, 0.0)


func _start_pull(group: Dictionary, dest: int, delay: float) -> void:
	preload("res://scenes/cog_hq/party_scale.gd").note_group(_members(group))
	var info := zone_info(String(group.get("zone", "")))
	var roll := {}
	var kind := String(info.get("kind", ""))
	if kind == "mint":
		roll = {"floor": randi() % 20, "ride": _next_pull}
	elif kind == "office" or kind == "course":
		roll = {"layout": dest * 3 + randi() % 3}
	group["roll"] = roll
	group["pull"] = {
		"token": _next_pull,
		"dest": dest,
		"at": ToonNet.now() + delay,
		"done": false,
	}
	_next_pull += 1


func _dispatch_pulls() -> void:
	var now := ToonNet.now()
	for item in _groups:
		if not (item is Dictionary):
			continue
		var group: Dictionary = item
		var pull: Variant = group.get("pull", {})
		if not (pull is Dictionary):
			continue
		var order: Dictionary = pull
		if order.is_empty() or bool(order.get("done", false)):
			continue
		if now < float(order.get("at", 0.0)):
			continue
		var info := zone_info(String(group.get("zone", "")))
		if String(info.get("kind", "")) == "factory":
			_seat_factory(group, int(order.get("dest", 0)))
		order["done"] = true
		group["pull"] = order
		_publish(int(group.get("district", ToonNet.district_id())))


func _seat_factory(group: Dictionary, dest: int) -> void:
	var board := get_node_or_null("../FactoryBoard")
	if board == null or not board.has_method("act"):
		return
	var district := int(group.get("district", 1))
	for id in _members(group):
		var card := _card(int(id))
		board.call("act", int(id), "board", {
			"district": district,
			"entrance": dest,
			"name": _name(int(id)),
			"hp": int(card.get("hp", 1)),
			"max": int(card.get("max_hp", 1)),
		})


func _can_board(group: Dictionary, dest: int, need_space: bool) -> String:
	var info := zone_info(String(group.get("zone", "")))
	if info.is_empty():
		return "Something went wrong; try again later."
	var failed: Array[int] = []
	var kind := ""
	var need := need_laff(String(group.get("zone", "")), dest)
	for id in _members(group):
		var card := _card(int(id))
		if bool(card.get("held", false)):
			if kind == "" or kind == "battle":
				kind = "battle"
				failed.append(int(id))
		elif int(card.get("hp", 0)) < need:
			if kind == "" or kind == "laff":
				kind = "laff"
				failed.append(int(id))
		elif int(info.get("promo", -1)) >= 0 and not _promoted(card, int(info.get("promo", -1))):
			if kind == "" or kind == "promo":
				kind = "promo"
				failed.append(int(id))
	if kind == "laff":
		return _who_failed(group, failed, "you have less than %d laff points." % need, "%s has less than %d laff points." % ["%s", need], "%s have less than %d laff points." % ["%s", need])
	if kind == "promo":
		return _who_failed(group, failed, "you do not have enough promotion merits.", "%s does not have enough promotion merits.", "%s do not have enough promotion merits.")
	if kind == "battle":
		return _who_failed(group, failed, "you are in battle.", "%s is in battle.", "%s are in battle.")
	if need_space and _members(group).size() > int(info.get("seats", 4)):
		return "Your group cannot board because there is not enough space."
	if need_space and String(info.get("kind", "")) == "factory":
		var snap := ToonNet.latest("factory-car:%d:%d" % [int(group.get("district", 1)), dest])
		var riding: Array = snap.get("toons", [])
		var state := String(snap.get("state", "open"))
		if state != "open" and state != "boarding" and state != "":
			return "Something went wrong; try again later."
		if riding.size() + _members(group).size() > int(info.get("seats", 4)):
			return "Your group cannot board because there is not enough space."
	return ""


func _who_failed(group: Dictionary, failed: Array[int], leader_bit: String, one: String, many: String) -> String:
	var leader := int(group.get("leader", 0))
	if failed.has(leader):
		return "Your group cannot board because %s" % leader_bit
	var names: PackedStringArray = []
	for id in failed:
		if int(id) != leader:
			names.append(_name(int(id)))
	if names.is_empty():
		return "Your group cannot board because %s" % leader_bit
	var listed := _join_names(names)
	if names.size() == 1:
		return "Your group cannot board because %s" % one.replace("%s", listed)
	return "Your group cannot board because %s" % many.replace("%s", listed)


func _qualify(peer: int, inviter: int, info: Dictionary, dest: int) -> String:
	var card := _card(peer)
	var need := 0
	var laff: Array = info.get("laff", [])
	if dest >= 0 and dest < laff.size():
		need = int(laff[dest])
	var called := _name(peer)
	if int(card.get("hp", 0)) < need:
		if peer == inviter:
			return "You need %d Laff Points before being a member of this Boarding Group." % need
		return "%s needs %d Laff Points before being a member of this Boarding Group." % [called, need]
	if int(info.get("promo", -1)) >= 0 and not _promoted(card, int(info.get("promo", -1))):
		if peer == inviter:
			return "You need to earn a promotion before being a member of this Boarding Group."
		return "%s needs to earn a promotion before being a member of this Boarding Group." % called
	return ""


func _drop_leavers() -> void:
	var dirty: Dictionary = {}
	for item in _groups.duplicate():
		if not (item is Dictionary):
			continue
		var group: Dictionary = item
		var zone := String(group.get("zone", ""))
		var gone: Array[int] = []
		for id in _members(group) + _ids(group, "invites"):
			var card := _card(int(id))
			var where := _file_of(card)
			if where != "" and where != zone:
				gone.append(int(id))
		for id in gone:
			_remove(group, id, false)
			dirty[int(group.get("district", 1))] = true
	for district in dirty.keys():
		_publish(int(district))


func _remove(group: Dictionary, peer: int, _kicked: bool) -> void:
	var members := _members(group)
	var invites := _ids(group, "invites")
	var was_leader := int(group.get("leader", -1)) == peer
	var was_member := members.has(peer)
	members.erase(peer)
	invites.erase(peer)
	var asked: Dictionary = group.get("asked", {})
	asked.erase(str(peer))
	group["asked"] = asked
	group["invites"] = invites
	var dissolve := was_leader or members.size() < 2
	if dissolve:
		if was_leader:
			for member in members:
				_tell(int(member), "Your Boarding Group was disbanded by the group leader.")
		elif was_member:
			for member in members:
				_tell(int(member), "%s has left the Boarding Group." % _name(peer))
		_forget(group)
		return
	group["members"] = members
	group["invites"] = invites
	if was_member:
		for member in members:
			_tell(int(member), "%s has left the Boarding Group." % _name(peer))


func _fresh(leader: int, zone: String, district: int) -> Dictionary:
	return {
		"district": district,
		"zone": zone,
		"leader": leader,
		"members": [leader],
		"invites": [],
		"kicked": [],
		"asked": {},
		"dest": 0,
		"pull": {},
		"roll": {},
	}


func _forget(group: Dictionary) -> void:
	var kept: Array = []
	for item in _groups:
		if item != group:
			kept.append(item)
	_groups = kept


func _tell(peer: int, text: String) -> void:
	if peer < 0 or text == "":
		return
	_notes.append({"id": _next_note, "to": peer, "text": text})
	_next_note += 1
	if _notes.size() > 24:
		_notes = _notes.slice(_notes.size() - 24)


func _publish(district: int) -> void:
	var groups: Array = []
	for item in _groups:
		if item is Dictionary and int((item as Dictionary).get("district", 0)) == district:
			groups.append(item)
	ToonNet.publish("boarding:%d" % district, {"groups": groups, "notes": _notes.duplicate()})


func _group_of(peer: int) -> Dictionary:
	for item in _groups:
		if item is Dictionary and _involved(item, peer):
			return item
	return {}


func _find_leader(leader: int) -> Dictionary:
	for item in _groups:
		if item is Dictionary and int((item as Dictionary).get("leader", -1)) == leader:
			return item
	return {}


func _card(peer: int) -> Dictionary:
	return ToonNet.latest("toon:%d" % peer)


func _name(peer: int) -> String:
	var called := String(_card(peer).get("name", "")).strip_edges()
	if called == "":
		return "A Toon"
	return called


func _file_of(card: Dictionary) -> String:
	return String(card.get("place", "")).get_file()


func _promoted(card: Dictionary, dept: int) -> bool:
	var promo: Variant = card.get("promo", [])
	if promo is Array and dept >= 0 and dept < (promo as Array).size():
		return bool((promo as Array)[dept])
	return false


static func _involved(group: Dictionary, peer: int) -> bool:
	if int(group.get("leader", -1)) == peer:
		return true
	return _members(group).has(peer) or _ids(group, "invites").has(peer)


static func _members(group: Dictionary) -> Array:
	return _ids(group, "members")


static func _ids(group: Dictionary, key: String) -> Array:
	var found: Variant = group.get(key, [])
	if found is Array:
		return (found as Array).duplicate()
	return []


static func _join_names(names: PackedStringArray) -> String:
	if names.size() == 1:
		return names[0]
	if names.size() == 2:
		return "%s and %s" % [names[0], names[1]]
	var head := ""
	for index in names.size() - 1:
		if index > 0:
			head += ", "
		head += names[index]
	return "%s and %s" % [head, names[names.size() - 1]]
