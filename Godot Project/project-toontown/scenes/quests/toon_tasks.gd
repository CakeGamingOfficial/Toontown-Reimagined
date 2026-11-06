class_name ToonTasks
extends RefCounted

## The ToonTask journal. Quest 101 is Tutorial Tom's Flunky. The Toontown
## Central chain continues 110, 145, the friend and phone tasks, then Flippy's
## gag training. After that, HQ offers the Central reward track. Battle code
## reports a defeat with note_cog_defeat. Turning a finished task in assigns
## whatever it points at next.

const COG := "cog"
const TROLLEY := "trolley"
const RECOVER := "recover"
const VISIT := "visit"
const TRACK := "track"
const FRIEND := "friend"
const PHONE := "phone"

# NPCToons ids the Toontown Central chain visits, and the interior zone the
# quest map uses for that building.
const _NPC_ZONE := {2001: 2513, 2005: 2518, 2119: 2629, 2311: 2809}
const _NPC_NAME := {
	2001: "Flippy",
	2005: "Librarian Larry",
	2119: "Honey Haha",
	2311: "Franz Neckvein",
}
const _NPC_WHERE := {
	2001: "Toon Hall\nToontown Central",
	2005: "Toontown Library\nToontown Central",
	2119: "The Laughin' Place\nSilly Street",
	2311: "The Punch Line Gym\nPunchline Place",
}

const _PATH := "user://toon_tasks.json"

const CATALOG := {
	101: {
		"headline": "WANTED",
		"caption": "A Flunky",
		"where": "Anywhere",
		"kind": COG,
		"cog": "f",
		"goal": 1,
		"show_count": true,
		"speech": "I need to defeat a Flunky.",
		"next": 110,
		"turn_in": "hq",
	},
	110: {
		"headline": "TROLLEY",
		"caption": "Ride on The Trolley",
		"where": "in The Playground",
		"kind": TROLLEY,
		"cog": "",
		"goal": 1,
		"show_count": false,
		"speech": "I need to ride the trolley.",
		"next": 145,
		"turn_in": "hq",
	},
	145: {
		"headline": "RECOVER",
		"caption": "A Blackboard Eraser",
		"where": "In Toontown Central",
		"kind": RECOVER,
		"cog": "any",
		"hood": 2000,
		"chance": 100,
		"goal": 1,
		"show_count": false,
		"speech": "I need to recover a blackboard eraser from the Cogs.",
		"next": 150,
		"turn_in": "hq",
	},
	150: {
		"headline": "FRIEND",
		"caption": "Make a friend",
		"where": "Anywhere",
		"kind": FRIEND,
		"cog": "",
		"goal": 1,
		"show_count": false,
		"speech": "I need to make a friend.",
		"lines": ["You have been doing great work.", "I think you are ready to make a friend.", "Go make a friend and come back to me."],
		"busy": ["Come back after you have made a friend."],
		"next": 175,
		"turn_in": "hq",
	},
	175: {
		"headline": "CLARABELLE",
		"caption": "Call Clarabelle",
		"where": "Anywhere",
		"kind": PHONE,
		"cog": "",
		"goal": 1,
		"show_count": false,
		"speech": "I need to call Clarabelle.",
		"lines": ["Nice work.", "Now you should call Clarabelle on the phone in your house.", "She will send you your first catalog."],
		"busy": ["Come back after you have called Clarabelle."],
		"next": 0,
		"turn_in": "hq",
		"laff": 1,
		"reward": 100,
	},
	# Tier 1 has one starting task. HQ sends the toon to Flippy. He and the
	# shopkeepers hand out the rest. A list of next ids is random.choice.
	164: {
		"headline": "VISIT",
		"caption": "Flippy",
		"where": "Toon Hall\nToontown Central",
		"kind": VISIT,
		"npc": 2001,
		"goal": 1,
		"show_count": false,
		"speech": "I need to visit Flippy.",
		"lines": ["You look like you could use some new gags.", "Go see Flippy. Maybe he can help you out.", "He is in Toon Hall, on the playground."],
		"next": 165,
		"turn_in": "2513",
	},
	165: {
		"headline": "WANTED",
		"caption": "4 Cogs",
		"where": "Anywhere",
		"kind": COG,
		"cog": "any",
		"npc": 2001,
		"same": true,
		"goal": 4,
		"show_count": true,
		"speech": "I need to defeat 4 Cogs.",
		"lines": ["Looks like you need to practice training your gags.", "Every time you hit a Cog with one of your gags, your experience increases.", "When you get enough experience, you will be able to use an even better gag.", "Go practice your gags by defeating 4 Cogs."],
		"busy": ["The Cogs are out in the streets, through the tunnels."],
		"next": [166, 167, 168, 169],
		"turn_in": "2513",
	},
	166: {
		"headline": "WANTED",
		"caption": "4 Bossbots",
		"where": "Anywhere",
		"kind": COG,
		"cog": "any",
		"dept": "c",
		"npc": 2001,
		"same": true,
		"goal": 4,
		"show_count": true,
		"speech": "I need to defeat 4 Bossbots.",
		"lines": ["Nice work defeating those Cogs.", "The Cogs come in four types: Lawbots, Cashbots, Sellbots, and Bossbots.", "You can tell them apart by their coloring and their name labels.", "For practice go defeat 4 Bossbots."],
		"busy": ["Come back after you defeat 4 Bossbots."],
		"next": [170, 171, 172],
		"turn_in": "2513",
	},
	167: {
		"headline": "WANTED",
		"caption": "4 Lawbots",
		"where": "Anywhere",
		"kind": COG,
		"cog": "any",
		"dept": "l",
		"npc": 2001,
		"same": true,
		"goal": 4,
		"show_count": true,
		"speech": "I need to defeat 4 Lawbots.",
		"lines": ["Nice work defeating those Cogs.", "The Cogs come in four types: Lawbots, Cashbots, Sellbots, and Bossbots.", "You can tell them apart by their coloring and their name labels.", "For practice go defeat 4 Lawbots."],
		"busy": ["Come back after you defeat 4 Lawbots."],
		"next": [170, 171, 172],
		"turn_in": "2513",
	},
	168: {
		"headline": "WANTED",
		"caption": "4 Sellbots",
		"where": "Anywhere",
		"kind": COG,
		"cog": "any",
		"dept": "s",
		"npc": 2001,
		"same": true,
		"goal": 4,
		"show_count": true,
		"speech": "I need to defeat 4 Sellbots.",
		"lines": ["Nice work defeating those Cogs.", "The Cogs come in four types: Lawbots, Cashbots, Sellbots, and Bossbots.", "You can tell them apart by their coloring and their name labels.", "For practice go defeat 4 Sellbots."],
		"busy": ["Come back after you defeat 4 Sellbots."],
		"next": [170, 171, 172],
		"turn_in": "2513",
	},
	169: {
		"headline": "WANTED",
		"caption": "4 Cashbots",
		"where": "Anywhere",
		"kind": COG,
		"cog": "any",
		"dept": "m",
		"npc": 2001,
		"same": true,
		"goal": 4,
		"show_count": true,
		"speech": "I need to defeat 4 Cashbots.",
		"lines": ["Nice work defeating those Cogs.", "The Cogs come in four types: Lawbots, Cashbots, Sellbots, and Bossbots.", "You can tell them apart by their coloring and their name labels.", "For practice go defeat 4 Cashbots."],
		"busy": ["Come back after you defeat 4 Cashbots."],
		"next": [170, 171, 172],
		"turn_in": "2513",
	},
	170: {
		"headline": "VISIT",
		"caption": "Librarian Larry",
		"where": "Toontown Library\nToontown Central",
		"kind": VISIT,
		"npc": 2005,
		"goal": 1,
		"show_count": false,
		"speech": "I need to visit Librarian Larry.",
		"lines": ["Nice work. Now you know the difference between the 4 types of Cogs.", "I think you are ready to start training for your third gag track.", "Go talk to Librarian Larry. He can give you some expert advice.", "He is in the Toontown Library, on the playground."],
		"next": 400,
		"turn_in": "2518",
	},
	171: {
		"headline": "VISIT",
		"caption": "Franz Neckvein",
		"where": "The Punch Line Gym\nPunchline Place",
		"kind": VISIT,
		"npc": 2311,
		"goal": 1,
		"show_count": false,
		"speech": "I need to visit Franz Neckvein.",
		"lines": ["Nice work. Now you know the difference between the 4 types of Cogs.", "I think you are ready to start training for your third gag track.", "Go talk to Franz Neckvein. He can give you some expert advice.", "He is at The Punch Line Gym, on Punchline Place."],
		"next": 400,
		"turn_in": "2809",
	},
	172: {
		"headline": "VISIT",
		"caption": "Honey Haha",
		"where": "The Laughin' Place\nSilly Street",
		"kind": VISIT,
		"npc": 2119,
		"goal": 1,
		"show_count": false,
		"speech": "I need to visit Honey Haha.",
		"lines": ["Nice work. Now you know the difference between the 4 types of Cogs.", "I think you are ready to start training for your third gag track.", "Go talk to Honey Haha. She can give you some expert advice.", "She is at The Laughin' Place, on Silly Street."],
		"next": 400,
		"turn_in": "2629",
	},
	400: {
		"headline": "TRAINING",
		"caption": "Sound or Toon-up",
		"where": "Anywhere",
		"kind": TRACK,
		"same": true,
		"goal": 1,
		"show_count": false,
		"speech": "I need to choose between Sound and Toon-up.",
		"lines": ["Throw and Squirt are great, but you will need more gags to fight higher level Cogs.", "When you team up with other Toons, you can combine attacks for even more damage.", "For your next track, choose between Sound and Toon-up.", "Sound damages all Cogs. Toon-up heals other Toons.", "When you are ready to decide, come back here and choose."],
		"choice": ["Back so soon? Okay, are you ready to choose?"],
		"after": ["Good decision. Now before you can use those gags, you must train for them.", "Each task gives you a single frame of your gag attack animation.", "When you collect all 15, you can use your new gags.", "You can check your progress in the Shticker Book."],
		"next": 0,
		"turn_in": "2513",
	},
}

## RequiredRewardTrackDict. Tier 0 is the phone's +1 Laff. Tier 1 is the gag
## track choice. Tier 2 is the rest of Toontown Central, in this order.
const _TIER0: Array[int] = [100]
const _TIER1: Array[int] = [400]
const _TIER2: Array[int] = [100, 801, 200, 802, 803, 101, 804, 805, 102, 806, 807, 100, 808, 809, 101, 810, 811, 500, 812, 813, 700, 814, 815, 300]
const _TIER2_BASE := 3000
const _DEPTS: PackedStringArray = ["c", "l", "s", "m"]
const _DEPT_NAMES: PackedStringArray = ["Bossbots", "Lawbots", "Sellbots", "Cashbots"]

## The playground journal. Friend and phone progress write through this, so a
## second copy loaded from disk cannot overwrite them.
static var _live: ToonTasks

var has_book := false
var met_flippy := false
# DistributedToon.trackProgressId is -1 when no gag track is in training.
# trackProgress is the bit field getTrackProgressAsArray reads, lowest bit first.
var track_id := -1
var track_progress := 0
## QuestRewardCounter. Tier 0 until the phone's +1 Laff, then 1 until the gag
## track is chosen, then 2 for the rest of Toontown Central.
var reward_tier := 0
var reward_history: Array[int] = []
## MaxQuestCarry starts at 1. Reward 500 raises it to 2.
var quest_carry := 1
var teleport: Array[int] = []
var in_playground := false
## Hood id from DistributedToonAI.setLocation. 2000 is Toontown Central.
var last_hood := 0
var visited: Array[int] = []

var _slot := -1
var _active: Array[Dictionary] = []
var _done: Array[int] = []


## The playground journal receives friend and phone progress.
static func bind(tasks: ToonTasks) -> void:
	_live = tasks


static func for_selected() -> ToonTasks:
	var tasks := ToonTasks.new()
	tasks._slot = ToonRoster.selected_index()
	tasks._load()
	return tasks


## Make a Toon and deleting a slot both start the journal over.
static func reset_slot(index: int) -> void:
	if index < 0 or index >= ToonRoster.SLOT_COUNT:
		return
	var tasks := ToonTasks.new()
	tasks._slot = index
	tasks.save()


## Tom hands over the Laff meter before the first task. After that it stays up.
func has_laff_meter() -> bool:
	return has_book or not _active.is_empty() or not _done.is_empty()


## HQ's choice list. The forced chain fills the journal by itself. An empty
## journal after the phone offers Flippy. An empty journal after the gag
## choice offers the next Central reward, three tasks when the pool has them.
func offers() -> Array[Dictionary]:
	if _active.size() >= quest_carry or not _done.has(145):
		return []
	if _chain_active():
		return []
	if not _done.has(400) and reward_tier < 2:
		if not _done.has(150):
			return [_offer_card(150)]
		if not _done.has(175):
			return [_offer_card(175)]
		if not _done.has(164):
			return [_offer_card(164)]
		return []
	if reward_tier < 2:
		return []
	return _tier2_offers()


func assign(quest_id: int, from_npc: int = 0) -> void:
	if not _known(quest_id) or _is_active(quest_id) or _done.has(quest_id):
		return
	if bool(_info(quest_id).get("hold", false)):
		return
	var info: Dictionary = _info(quest_id)
	var to_npc := int(info.get("npc", 0))
	if bool(info.get("same", false)):
		to_npc = from_npc
	var progress := 0
	if String(info.get("kind", "")) == FRIEND and FriendsBook.toon_friend_count() > 0:
		progress = int(info["goal"])
	_active.append({"id": quest_id, "progress": progress, "to_npc": to_npc})
	save()


## FriendQuest is done once a toon is on the friends list.
static func notify_friend() -> void:
	if _live != null and is_instance_valid(_live):
		_live.note_friend()


func note_friend() -> void:
	if FriendsBook.toon_friend_count() <= 0:
		return
	_fill_kind(FRIEND)


## PhoneQuest finishes when Clarabelle's catalog closes.
func note_phone() -> void:
	_fill_kind(PHONE)


func note_cog_defeat(cog: String, hood: int = 0, dept: String = "") -> void:
	var code := cog.to_lower()
	CogGallery.note(code)
	var playground := hood - posmod(hood, 1000)
	var changed := false
	for entry in _active:
		var quest_id := int(entry["id"])
		if not _known(quest_id):
			continue
		var info: Dictionary = _info(quest_id)
		var kind := String(info["kind"])
		if kind == COG:
			var wanted := String(info["cog"])
			var want_dept := String(info.get("dept", ""))
			if want_dept != "" and want_dept != dept:
				continue
			if wanted != code and wanted != "any":
				continue
			var need_hood := int(info.get("hood", 0))
			if need_hood != 0 and playground != need_hood:
				continue
			entry["progress"] = mini(int(entry["progress"]) + 1, int(info["goal"]))
			changed = true
		elif kind == RECOVER:
			var need_hood := int(info.get("hood", 0))
			if need_hood != 0 and playground != need_hood:
				continue
			if int(entry["progress"]) >= int(info["goal"]):
				continue
			var chance := int(info.get("chance", 100))
			if randi_range(1, 100) > chance:
				continue
			entry["progress"] = mini(int(entry["progress"]) + 1, int(info["goal"]))
			changed = true
	if changed:
		save()


## The first finished task an HQ officer can take.
func ready_hq() -> Dictionary:
	for entry in _active:
		var quest_id := int(entry["id"])
		if not _known(quest_id) or not is_complete(quest_id):
			continue
		var info: Dictionary = _info(quest_id)
		if String(info.get("turn_in", "")) != "hq":
			continue
		var card: Dictionary = info.duplicate()
		card["id"] = quest_id
		return card
	return {}


## Finishing a trolley ride calls this. Nothing else marks quest 110 complete.
func note_trolley() -> void:
	for entry in _active:
		var info: Dictionary = _info(int(entry["id"]))
		if info.is_empty() or String(info["kind"]) != TROLLEY:
			continue
		entry["progress"] = int(info["goal"])
	save()


## npc_id is who is standing in front of the toon. HQ passes 0.
## A visit is finished by arriving. A track choice is finished by choose_track.
## The returned id is the task this NPC just handed out.
func turn_in(quest_id: int, npc_id: int = 0) -> int:
	var entry := _entry(quest_id)
	if entry.is_empty() or not _known(quest_id):
		return 0
	var info: Dictionary = _info(quest_id)
	if String(info["kind"]) == TRACK:
		return 0
	var dest := _dest(entry)
	if dest != 0 and npc_id != dest:
		return 0
	var kind := String(info["kind"])
	var finished := kind == VISIT or _kind_done(entry, info)
	if not finished:
		return 0
	var next_id := _follow(info)
	# A list pick, or a task already turned in at HQ, is skipped so the chain
	# still reaches the toon who gives the next part.
	var guard := 0
	while next_id != 0 and _done.has(next_id) and guard < 8:
		guard += 1
		if not _known(next_id):
			next_id = 0
			break
		next_id = _follow(_info(next_id))
	_remove(quest_id)
	if not _done.has(quest_id):
		_done.append(quest_id)
	# A reward is paid when the task does not point at another one.
	if next_id == 0:
		_collect(info)
	save()
	if next_id != 0:
		assign(next_id, npc_id)
	return next_id


## Quest 400. The NPC presents Sound and Toon-up, then the training film starts.
func choose_track(quest_id: int, track: int) -> void:
	var entry := _entry(quest_id)
	if entry.is_empty() or not _known(quest_id):
		return
	var info: Dictionary = _info(quest_id)
	if String(info["kind"]) != TRACK:
		return
	if track < 0 or track >= ToonLoadout.TRACK_COUNT:
		return
	track_id = track
	track_progress = 0
	_remove(quest_id)
	if not _done.has(quest_id):
		_done.append(quest_id)
	_collect({"reward": 400})
	save()


## The task aimed at this NPC, finished or not. Empty when they have nothing.
func for_npc(npc_id: int) -> Dictionary:
	if npc_id == 0:
		return {}
	var waiting: Dictionary = {}
	for entry in _active:
		if _dest(entry) != npc_id:
			continue
		var quest_id := int(entry["id"])
		var info: Dictionary = _info(quest_id)
		if info.is_empty():
			continue
		var kind := String(info["kind"])
		var card := _card(entry)
		card["ready"] = kind == VISIT or kind == TRACK or _kind_done(entry, info)
		if bool(card["ready"]):
			return card
		waiting = card
	return waiting


func quest_pages(quest_id: int) -> PackedStringArray:
	return _pages(quest_id, "lines")


func busy_pages(quest_id: int) -> PackedStringArray:
	return _pages(quest_id, "busy")


func choice_pages(quest_id: int) -> PackedStringArray:
	return _pages(quest_id, "choice")


func after_pages(quest_id: int) -> PackedStringArray:
	return _pages(quest_id, "after")


func is_complete(quest_id: int) -> bool:
	if not _known(quest_id):
		return false
	for entry in _active:
		if int(entry["id"]) != quest_id:
			continue
		return _kind_done(entry, _info(quest_id))
	return false


func entries() -> Array[Dictionary]:
	var shown: Array[Dictionary] = []
	for entry in _active:
		if not _known(int(entry["id"])):
			continue
		shown.append(_card(entry))
	return shown


func _card(entry: Dictionary) -> Dictionary:
	var quest_id := int(entry["id"])
	var info: Dictionary = _info(quest_id)
	var progress := int(entry["progress"])
	var goal := int(info["goal"])
	var card: Dictionary = info.duplicate()
	card["id"] = quest_id
	card["progress"] = progress
	card["goal"] = goal
	card["ready"] = _kind_done(entry, info)
	if bool(card["ready"]):
		card["progress"] = goal
	var dest := _dest(entry)
	if dest != 0 and _NPC_ZONE.has(dest):
		card["turn_in"] = str(_NPC_ZONE[dest])
		card["return_name"] = String(_NPC_NAME[dest])
		card["return_where"] = String(_NPC_WHERE[dest])
		card["where"] = String(_NPC_WHERE[dest]) if String(info["kind"]) == VISIT or String(info["kind"]) == TRACK else String(info.get("where", ""))
	return card


func _entry(quest_id: int) -> Dictionary:
	for entry in _active:
		if int(entry["id"]) == quest_id:
			return entry
	return {}


func _dest(entry: Dictionary) -> int:
	var stored := int(entry.get("to_npc", 0))
	if stored != 0:
		return stored
	if not _known(int(entry.get("id", 0))):
		return 0
	return int(_info(int(entry["id"])).get("npc", 0))


func _follow(info: Dictionary) -> int:
	var nxt: Variant = info.get("next", 0)
	if typeof(nxt) == TYPE_ARRAY:
		var options: Array = nxt
		if options.is_empty():
			return 0
		return int(options[randi() % options.size()])
	return int(nxt)


func _kept(quest_id: int, progress: int, to_npc: int) -> Dictionary:
	if to_npc == 0 and _known(quest_id):
		to_npc = int(_info(quest_id).get("npc", 0))
	return {"id": quest_id, "progress": progress, "to_npc": to_npc}


func _pages(quest_id: int, key: String) -> PackedStringArray:
	var lines := PackedStringArray()
	if not _known(quest_id):
		return lines
	var raw: Variant = _info(quest_id).get(key, [])
	if typeof(raw) != TYPE_ARRAY:
		return lines
	for line in raw:
		lines.append(String(line))
	return lines


func grant_book() -> void:
	has_book = true
	save()


## The corner button stays hidden until Harry has turned in the Flunky task.
## An older visit used to set has_book during Tom's briefing, before that reward.
func book_ready() -> bool:
	return has_book and _done.has(101)


func grant_speedchat() -> void:
	met_flippy = true
	save()


## TutorialStreet.handleEnterTunnel sends stopTutorial, then the toon arrives
## in Toontown Central. Reaching the playground is what finishes the toontorial.
## After that, the journal stays on disk when the game closes.
func note_playground() -> void:
	in_playground = true
	last_hood = 2000
	save()


## setLocation writes the playground or Cog HQ the toon is standing in.
## The estate uses a dynamic zone, so going home does not replace lastHood.
func note_hood(hood: int) -> void:
	if not in_playground:
		return
	var canonical := hood - posmod(hood, 1000)
	if canonical < 1000 or canonical == 16000:
		return
	if canonical == last_hood:
		_remember(canonical)
		return
	last_hood = canonical
	_remember(canonical)
	save()


## MapPage.backToSafeZone teleports to lastHood. A visit home leaves that hood
## in place. An older save may have stored the estate itself; skip that.
func return_hood() -> int:
	if _returnable(last_hood):
		return last_hood
	var found := 0
	for hood in visited:
		if _returnable(hood):
			found = hood
	if found != 0:
		return found
	if in_playground:
		return 2000
	return 0


func _returnable(hood: int) -> bool:
	return hood >= 1000 and hood != 16000


func has_visited(hood: int) -> bool:
	return visited.has(hood - posmod(hood, 1000))


func _remember(hood: int) -> void:
	var canonical := hood - posmod(hood, 1000)
	if canonical < 1000 or visited.has(canonical):
		return
	visited.append(canonical)


## One task at a time in the toontorial. SpeedChat's MY TASKS reads these lines.
func task_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for entry in _active:
		var quest_id := int(entry["id"])
		if not _known(quest_id):
			continue
		var info: Dictionary = _info(quest_id)
		var speech := String(info.get("speech", ""))
		if speech != "" and not lines.has(speech):
			lines.append(speech)
	if _active.is_empty():
		lines.append("I need to get a ToonTask.")
	return lines


func task_entries() -> Array:
	var rows: Array = []
	for entry in _active:
		rows.append({"id": int(entry["id"]), "progress": int(entry["progress"])})
	return rows


func training_track() -> int:
	return track_id


## Frame index 0 is the first training task. Fifteen bits, matching
## getTrackProgressAsArray's default length.
func training_step(index: int) -> bool:
	if index < 0 or index > 14:
		return false
	return (track_progress & (1 << index)) != 0


func finished_ids() -> Array:
	var rows: Array = []
	for quest_id in _done:
		rows.append(int(quest_id))
	return rows


func apply_dict(record: Dictionary) -> void:
	has_book = bool(record.get("has_book", has_book))
	met_flippy = bool(record.get("met_flippy", met_flippy))
	track_id = int(record.get("track_id", track_id))
	track_progress = int(record.get("track_progress", track_progress))
	reward_tier = int(record.get("reward_tier", reward_tier))
	quest_carry = maxi(int(record.get("quest_carry", quest_carry)), 1)
	reward_history.clear()
	for reward_id in record.get("reward_history", []):
		reward_history.append(int(reward_id))
	teleport.clear()
	for zone_id in record.get("teleport", []):
		teleport.append(int(zone_id))
	in_playground = bool(record.get("in_playground", in_playground))
	last_hood = int(record.get("last_hood", last_hood))
	visited.clear()
	for hood in record.get("visited", []):
		_remember(int(hood))
	_done.clear()
	for finished in record.get("done", []):
		_done.append(int(finished))
	_active.clear()
	for entry in record.get("active", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var quest_num := int(entry.get("id", 0))
		if _known(quest_num):
			_active.append(_kept(quest_num, int(entry.get("progress", 0)), int(entry.get("to_npc", 0))))


func save() -> void:
	var root := _read_file()
	var slots: Array = root.get("slots", [])
	while slots.size() < ToonRoster.SLOT_COUNT:
		slots.append(null)
	if _slot < 0 or _slot >= ToonRoster.SLOT_COUNT:
		return
	var active: Array = []
	for entry in _active:
		active.append({
			"id": int(entry["id"]),
			"progress": int(entry["progress"]),
			"to_npc": int(entry.get("to_npc", 0)),
		})
	slots[_slot] = {
		"has_book": has_book,
		"met_flippy": met_flippy,
		"track_id": track_id,
		"track_progress": track_progress,
		"reward_tier": reward_tier,
		"reward_history": reward_history.duplicate(),
		"quest_carry": quest_carry,
		"teleport": teleport.duplicate(),
		"in_playground": in_playground,
		"last_hood": last_hood,
		"visited": visited.duplicate(),
		"active": active,
		"done": _done.duplicate(),
	}
	root["slots"] = slots
	var file := FileAccess.open(_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(root))
	# keep_toon reads this file back. Closing first flushes it; a read while
	# the write is still open comes back empty and would store a blank journal.
	file.close()
	ToonNet.keep_toon()


func _known(quest_id: int) -> bool:
	return CATALOG.has(quest_id) or _tier2_step(quest_id) >= 0


func _info(quest_id: int) -> Dictionary:
	if CATALOG.has(quest_id):
		return CATALOG[quest_id]
	return _tier2_info(quest_id)


func _kind_done(entry: Dictionary, info: Dictionary) -> bool:
	if String(info.get("kind", "")) == FRIEND and FriendsBook.toon_friend_count() > 0:
		return true
	return int(entry.get("progress", 0)) >= int(info.get("goal", 1))


func _fill_kind(kind: String) -> void:
	var changed := false
	for entry in _active:
		var info := _info(int(entry["id"]))
		if info.is_empty() or String(info.get("kind", "")) != kind:
			continue
		var goal := int(info["goal"])
		if int(entry["progress"]) >= goal:
			continue
		entry["progress"] = goal
		changed = true
	if changed:
		save()


func _chain_active() -> bool:
	for entry in _active:
		if int(entry["id"]) < _TIER2_BASE:
			return true
	return false


func _offer_card(quest_id: int) -> Dictionary:
	var info: Dictionary = _info(quest_id)
	var card: Dictionary = info.duplicate()
	card["id"] = quest_id
	card["progress"] = 0
	card["goal"] = int(info.get("goal", 1))
	card["ready"] = false
	return card


func _required(tier: int) -> Array[int]:
	if tier == 0:
		return _TIER0.duplicate()
	if tier == 1:
		return _TIER1.duplicate()
	if tier == 2:
		return _TIER2.duplicate()
	return []


## The next Central reward that is neither recorded nor already in the journal.
func _tier2_offers() -> Array[Dictionary]:
	var taken: Dictionary = {}
	for entry in _active:
		var step := _tier2_step(int(entry["id"]))
		if step >= 0:
			taken[step] = true
	var pending: Array[int] = []
	for reward_id in reward_history:
		pending.append(reward_id)
	for step in _TIER2.size():
		var reward_id := _TIER2[step]
		if bool(taken.get(step, false)):
			continue
		var found := pending.find(reward_id)
		if found >= 0:
			pending.remove_at(found)
			continue
		var shown: Array[Dictionary] = []
		for variant in 3:
			shown.append(_offer_card(_TIER2_BASE + step * 3 + variant))
		return shown
	return []


func _tier2_step(quest_id: int) -> int:
	if quest_id < _TIER2_BASE:
		return -1
	var step := int((quest_id - _TIER2_BASE) / 3)
	if step < 0 or step >= _TIER2.size():
		return -1
	return step


func _tier2_info(quest_id: int) -> Dictionary:
	var step := _tier2_step(quest_id)
	if step < 0:
		return {}
	var variant := (quest_id - _TIER2_BASE) % 3
	var reward_id := _TIER2[step]
	var goal := 2 + (step % 4)
	var dept := _DEPTS[step % _DEPTS.size()]
	var info := {
		"headline": "WANTED",
		"kind": COG,
		"goal": goal,
		"show_count": true,
		"next": 0,
		"turn_in": "hq",
		"reward": reward_id,
	}
	if variant == 0:
		info["caption"] = "%d Cogs" % goal
		info["where"] = "In Toontown Central"
		info["cog"] = "any"
		info["hood"] = 2000
		info["speech"] = "I need to defeat %d Cogs in Toontown Central." % goal
	elif variant == 1:
		var more := goal + 1
		info["goal"] = more
		info["caption"] = "%d Cogs" % more
		info["where"] = "Anywhere"
		info["cog"] = "any"
		info["speech"] = "I need to defeat %d Cogs." % more
	else:
		info["caption"] = "%d %s" % [goal, _DEPT_NAMES[step % _DEPT_NAMES.size()]]
		info["where"] = "Anywhere"
		info["cog"] = "any"
		info["dept"] = dept
		info["speech"] = "I need to defeat %d %s." % [goal, _DEPT_NAMES[step % _DEPT_NAMES.size()]]
	_stamp_reward(info, reward_id)
	return info


func _stamp_reward(info: Dictionary, reward_id: int) -> void:
	if reward_id == 100:
		info["laff"] = 1
	elif reward_id == 101:
		info["laff"] = 2
	elif reward_id == 102:
		info["laff"] = 3
	elif reward_id == 200:
		info["carry"] = 25
	elif reward_id == 700:
		info["beans"] = 50
	elif reward_id >= 801 and reward_id <= 815:
		info["frame"] = reward_id - 800


func _collect(info: Dictionary) -> void:
	var reward_id := int(info.get("reward", 0))
	if reward_id == 0:
		return
	reward_history.append(reward_id)
	if reward_id >= 801 and reward_id <= 815 and track_id >= 0:
		track_progress = track_progress | (1 << (reward_id - 801))
	if reward_id == 500:
		quest_carry = maxi(quest_carry, 2)
	if reward_id == 300 and not teleport.has(2000):
		teleport.append(2000)
	var guard := 0
	while guard < 4:
		guard += 1
		var need := _required(reward_tier)
		if need.is_empty():
			return
		var pending: Array[int] = []
		for owned in reward_history:
			pending.append(owned)
		var finished := true
		for needed in need:
			var found := pending.find(needed)
			if found < 0:
				finished = false
				break
			pending.remove_at(found)
		if not finished:
			return
		reward_tier += 1


func _is_active(quest_id: int) -> bool:
	for entry in _active:
		if int(entry["id"]) == quest_id:
			return true
	return false


func _remove(quest_id: int) -> void:
	var kept: Array[Dictionary] = []
	for entry in _active:
		if int(entry["id"]) != quest_id:
			kept.append(entry)
	_active = kept


func _load() -> void:
	_active = []
	_done = []
	visited = []
	has_book = false
	met_flippy = false
	track_id = -1
	track_progress = 0
	reward_tier = 0
	reward_history = []
	quest_carry = 1
	teleport = []
	in_playground = false
	last_hood = 0
	if _slot < 0:
		return
	var root := _read_file()
	var slots: Array = root.get("slots", [])
	if _slot >= slots.size() or typeof(slots[_slot]) != TYPE_DICTIONARY:
		return
	var stored: Dictionary = slots[_slot]
	has_book = bool(stored.get("has_book", false))
	met_flippy = bool(stored.get("met_flippy", false))
	track_id = int(stored.get("track_id", -1))
	track_progress = int(stored.get("track_progress", 0))
	reward_tier = maxi(int(stored.get("reward_tier", 0)), 0)
	quest_carry = maxi(int(stored.get("quest_carry", 1)), 1)
	reward_history.clear()
	for reward_id in stored.get("reward_history", []):
		reward_history.append(int(reward_id))
	teleport.clear()
	for zone_id in stored.get("teleport", []):
		teleport.append(int(zone_id))
	in_playground = bool(stored.get("in_playground", false))
	last_hood = int(stored.get("last_hood", 0))
	if in_playground and last_hood == 0:
		last_hood = 2000
	for quest_id in stored.get("done", []):
		_done.append(int(quest_id))
	for item in stored.get("visited", []):
		_remember(int(item))
	if visited.is_empty() and in_playground:
		_remember(last_hood)
	for entry in stored.get("active", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var quest_id := int(entry.get("id", 0))
		if not _known(quest_id) or _done.has(quest_id):
			continue
		_active.append(_kept(quest_id, int(entry.get("progress", 0)), int(entry.get("to_npc", 0))))
	var repaired := false
	# Finishing the Flunky task is what ends the toontorial. A save that kept
	# that and lost the playground flag must not start Tom's lesson over.
	if _done.has(101) and not in_playground:
		in_playground = true
		if last_hood == 0:
			last_hood = 2000
		repaired = true
	if _done.has(101) and not _done.has(110) and not _is_active(110):
		_active.append({"id": 110, "progress": 0})
		repaired = true
	if _done.has(110) and not _done.has(145) and not _is_active(145):
		_active.append({"id": 145, "progress": 0})
		repaired = true
	# Saves from before the friend and phone tasks were handed out.
	if _done.has(145) and not _done.has(164) and not _done.has(400) and not _chain_active():
		if not _done.has(150) and not _is_active(150):
			var progress := 1 if FriendsBook.toon_friend_count() > 0 else 0
			_active.append({"id": 150, "progress": progress, "to_npc": 0})
			repaired = true
		elif _done.has(150) and not _done.has(175) and not _is_active(175):
			_active.append({"id": 175, "progress": 0, "to_npc": 0})
			repaired = true
	if reward_history.is_empty() and _done.has(400) and reward_tier < 2:
		reward_tier = 2
		reward_history.append(100)
		reward_history.append(400)
		repaired = true
	elif reward_history.is_empty() and _done.has(175) and reward_tier < 1:
		reward_tier = 1
		reward_history.append(100)
		repaired = true
	if repaired:
		save()


func _read_file() -> Dictionary:
	if not FileAccess.file_exists(_PATH):
		return {}
	var file := FileAccess.open(_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
