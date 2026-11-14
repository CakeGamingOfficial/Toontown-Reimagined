extends RefCounted

## What a department boss leaves behind. The V.P. files an SOS card
## (attemptAddNPCFriend, two calls, 16 cards). The C.F.O. leaves a Resistance
## unite. The C.J. leaves a cog summon. The C.E.O. leaves pink slips. SOS and
## Fire are the battle inventory buttons. A unite is said from SpeedChat
## UNITE! and also from the disguise page. Summons stay on the disguise page.

const _PATH := "user://boss_rewards.json"
const _SOS_FILE := "res://scenes/shticker/sos_toons.json"
const _MAX_SOS := 16
const _CALLS := 2
const _POCKETS := "res://scenes/battle/toon_loadout.gd"
const _BEANS := "res://scenes/toons/jellybeans.gd"
const _HOLIDAYS := "res://scenes/shticker/calendar_holidays.gd"
const _NET := "res://scenes/net/toon_net.gd"

const _CODES: Array = [
	["f", "p", "ym", "mm", "ds", "hh", "cr", "tbc"],
	["bf", "b", "dt", "ac", "bs", "sd", "le", "bw"],
	["sc", "pp", "tw", "bc", "nc", "mb", "ls", "rb"],
	["cc", "tm", "nd", "gh", "ms", "tf", "m", "mh"],
]
const _DEPT_LETTER: PackedStringArray = ["c", "l", "m", "s"]
const _TRACKS: PackedStringArray = ["Toon-up", "Trap", "Lure", "Sound", "Throw", "Squirt", "Drop", "Gag-up", "Toons Hit", "Cogs Miss"]
const _TOONUP: PackedInt32Array = [10, 20, 40, 80, -1]
const _MONEY: PackedInt32Array = [100, 200, 350, 600]

static var _catalog: Array = []


static var _held: Dictionary = {}


static func grant_sos() -> String:
	return _store_sos(_roll_sos(), _CALLS)


static func hold_vp_sos() -> Dictionary:
	if _held.is_empty():
		_held = _roll_sos()
	return _held.duplicate(true)


static func grant_held_sos() -> String:
	var card := _held.duplicate(true)
	_held.clear()
	if card.is_empty():
		return grant_sos()
	return _store_sos(card, _CALLS)


## chooseSOSCard. One call. Stars follow the field office difficulty, and a
## difficulty above 5 does not file a card.
static func grant_field_sos(difficulty: int) -> String:
	if difficulty < 0 or difficulty > 5:
		return ""
	var low := 0
	var high := 1
	if difficulty > 3:
		low = 2
		high = 2
	elif difficulty > 1:
		low = 1
		high = 1
	var card := _roll_band(low, high)
	if card.is_empty():
		return ""
	return _store_sos(card, 1)


static func give_sos_named(query: String) -> String:
	_load_catalog()
	var needle := query.strip_edges().to_lower()
	if needle == "" or _catalog.is_empty():
		return "No SOS Toon matches %s." % query
	var exact: Dictionary = {}
	var partial: Array = []
	for item in _catalog:
		if not (item is Dictionary):
			continue
		var name := String((item as Dictionary).get("name", "")).to_lower()
		if name == needle:
			exact = item
			break
		if name.contains(needle):
			partial.append(item)
	if not exact.is_empty():
		return _store_sos(exact.duplicate(true), _CALLS)
	if partial.size() == 1:
		return _store_sos((partial[0] as Dictionary).duplicate(true), _CALLS)
	if partial.is_empty():
		return "No SOS Toon matches %s." % query
	var names := PackedStringArray()
	for item in partial:
		names.append(String((item as Dictionary).get("name", "")))
		if names.size() >= 4:
			break
	return "Which SOS Toon? %s." % ", ".join(names)


static func give_sos_pages() -> String:
	_load_catalog()
	if _catalog.is_empty():
		return "No SOS Toons are listed."
	var added := 0
	var last := ""
	for item in _catalog:
		if not (item is Dictionary):
			continue
		var line := _store_sos((item as Dictionary).duplicate(true), _CALLS)
		if line.begins_with("Your SOS"):
			last = line
			break
		if line.begins_with("You already"):
			continue
		added += 1
		last = line
	if added == 0:
		return last if last != "" else "Your SOS pages are full."
	return "Filed %d SOS cards." % added


static func _store_sos(card: Dictionary, calls: int) -> String:
	if card.is_empty():
		return "The caged Toon got away before you could take their card."
	var record := _read()
	var cards: Array = record.get("sos", [])
	if cards.size() >= _MAX_SOS:
		return "Your SOS pages are full, so %s's card did not fit." % String(card.get("name", "The Toon"))
	for item in cards:
		if item is Dictionary and int((item as Dictionary).get("id", 0)) == int(card.get("id", 0)):
			return "You already carry %s's SOS card." % String(card.get("name", "that Toon"))
	card["calls"] = calls
	cards.append(card)
	record["sos"] = cards
	_write(record)
	return "%s joined your SOS cards (%d calls)." % [String(card.get("name", "An SOS Toon")), calls]


static func grant_unite() -> String:
	var menu := randi() % 3
	var count := 5 if menu == 0 else (4 if menu == 1 else 8)
	var item := randi() % count
	var record := _read()
	var unites: Array = record.get("unites", [])
	unites.append({"menu": menu, "item": item})
	record["unites"] = unites
	_write(record)
	return "The Resistance gave you a unite: %s." % _unite_label(menu, item)


static func latest_unite() -> Dictionary:
	var unites: Array = _read().get("unites", [])
	if unites.is_empty() or not (unites[unites.size() - 1] is Dictionary):
		return {}
	return (unites[unites.size() - 1] as Dictionary).duplicate()


static func unite_phrase(menu: int, item: int) -> String:
	return _phrase_label(menu, item)


static func unite_when(menu: int, item: int) -> String:
	# ResistanceToonToonupInstructions and the money and restock lines.
	if menu == 0:
		var amount := int(_TOONUP[clampi(item, 0, _TOONUP.size() - 1)])
		if amount < 0:
			return "all the Toons near you will gain full Laff points"
		return "all the Toons near you will gain %d Laff points" % amount
	if menu == 1:
		var beans := int(_MONEY[clampi(item, 0, _MONEY.size() - 1)])
		return "all the Toons near you will gain %d jellybeans" % beans
	if item >= 7:
		return "all the Toons near you will restock all their gags"
	return "all the Toons near you will restock their \"%s\" gags" % _TRACKS[clampi(item, 0, 6)]


static func rehearse_unite() -> String:
	# doEffect during the goodbye. The card stays for the one real use.
	var card := latest_unite()
	if card.is_empty():
		return ""
	return _apply_unite(int(card.get("menu", 0)), int(card.get("item", 0)))


static func give_unite(menu: int, item: int, count: int = 1) -> String:
	var copies := clampi(count, 1, 50)
	var record := _read()
	var unites: Array = record.get("unites", [])
	for _copy in copies:
		unites.append({"menu": menu, "item": item})
	record["unites"] = unites
	_write(record)
	var label := _unite_label(menu, item)
	if copies == 1:
		return "The Resistance gave you a unite: %s." % label
	return "The Resistance gave you %d unites: %s." % [copies, label]


static func give_every_unite() -> String:
	var record := _read()
	var unites: Array = record.get("unites", [])
	var added := 0
	for menu in 3:
		var count := 5 if menu == 0 else (4 if menu == 1 else 8)
		for item in count:
			unites.append({"menu": menu, "item": item})
			added += 1
	record["unites"] = unites
	_write(record)
	return "The Resistance gave you one of every unite (%d)." % added


static func grant_summon(promotions: int) -> String:
	var roll := randi() % 100
	var kind := "single"
	if roll >= 97:
		kind = "invasion"
	elif roll >= 70:
		kind = "building"
	var dept := randi() % 4
	var cog_type := clampi(int(float(promotions) / 77.0 * 8.0), 0, 7)
	var record := _read()
	var summons: Array = record.get("summons", [])
	summons.append({"dept": dept, "type": cog_type, "kind": kind})
	record["summons"] = summons
	_write(record)
	var names: PackedStringArray = ["a single cog", "a cog building", "an invasion"]
	var label := names[0]
	if kind == "building":
		label = names[1]
	elif kind == "invasion":
		label = names[2]
	return "The Chief Justice signed a summon for %s." % label


static func give_summon(dept: int, cog_type: int, kind: String, cog_name: String = "") -> String:
	var safe_dept := clampi(dept, 0, 3)
	var safe_type := clampi(cog_type, 0, 7)
	var safe_kind := kind
	if safe_kind != "building" and safe_kind != "invasion":
		safe_kind = "single"
	var record := _read()
	var summons: Array = record.get("summons", [])
	summons.append({"dept": safe_dept, "type": safe_type, "kind": safe_kind})
	record["summons"] = summons
	_write(record)
	var who := cog_name if cog_name != "" else "cog"
	if safe_kind == "building":
		return "The Chief Justice signed a summon for a %s building." % who
	if safe_kind == "invasion":
		return "The Chief Justice signed a summon for a %s invasion." % who
	return "The Chief Justice signed a summon for a single %s." % who


static func grant_pink(count: int) -> String:
	var added := maxi(count, 1)
	var record := _read()
	record["pink"] = int(record.get("pink", 0)) + added
	_write(record)
	if added == 1:
		return "The C.E.O. dropped a pink slip."
	return "The C.E.O. dropped %d pink slips." % added


static func sos_count() -> int:
	return (_read().get("sos", []) as Array).size()


static func pink_slips() -> int:
	return int(_read().get("pink", 0))


static func set_pink(count: int) -> String:
	var record := _read()
	record["pink"] = maxi(count, 0)
	_write(record)
	return "Pink slips set to %d." % int(record["pink"])


static func sos_cards() -> Array:
	var cards: Array = _read().get("sos", [])
	return cards.duplicate(true)


static func sos_by_id(npc_id: int) -> Dictionary:
	_load_catalog()
	for item in _catalog:
		if item is Dictionary and int((item as Dictionary).get("id", 0)) == npc_id:
			return (item as Dictionary).duplicate(true)
	return {}


static func consume_id(npc_id: int) -> void:
	var record := _read()
	var cards: Array = record.get("sos", [])
	for index in cards.size():
		if not (cards[index] is Dictionary):
			continue
		var card: Dictionary = cards[index]
		if int(card.get("id", 0)) != npc_id:
			continue
		card["calls"] = int(card.get("calls", 1)) - 1
		if int(card["calls"]) <= 0:
			cards.remove_at(index)
		else:
			cards[index] = card
		record["sos"] = cards
		_write(record)
		return


static func consume_encoded(encoded: int) -> void:
	var track := int(encoded / 10)
	var level := 0 if track >= 7 else encoded % 10
	var record := _read()
	var cards: Array = record.get("sos", [])
	for index in cards.size():
		if not (cards[index] is Dictionary):
			continue
		var card: Dictionary = cards[index]
		if int(card.get("track", -1)) != track:
			continue
		if track < 7 and int(card.get("level", -1)) != level:
			continue
		card["calls"] = int(card.get("calls", 1)) - 1
		if int(card["calls"]) <= 0:
			cards.remove_at(index)
		else:
			cards[index] = card
		record["sos"] = cards
		_write(record)
		return


static func consume_pink() -> void:
	var record := _read()
	record["pink"] = maxi(int(record.get("pink", 0)) - 1, 0)
	_write(record)


static func restock_all(loadout) -> void:
	if loadout == null:
		return
	var pockets = load(_POCKETS)
	for track in pockets.TRACK_COUNT:
		_fill_track(loadout, track)
	loadout.save()


## InventoryBase.NPCMaxOutInv. Level -1 fills every track. A track number fills that one.
static func restock_track(loadout, track: int) -> void:
	if loadout == null:
		return
	if track < 0:
		restock_all(loadout)
		return
	_fill_track(loadout, track)
	loadout.save()


static func use_unite() -> String:
	var record := _read()
	var unites: Array = record.get("unites", [])
	if unites.is_empty() or not (unites[0] is Dictionary):
		return "You have no Resistance unites."
	var card: Dictionary = unites[0]
	var menu := int(card.get("menu", 0))
	var item := int(card.get("item", 0))
	unites.remove_at(0)
	record["unites"] = unites
	_write(record)
	var line := _apply_unite(menu, item)
	_announce(menu, item)
	return line


## TTSCResistanceTerminal. One charge of this exact phrase, then the chat line.
static func speak_unite(menu: int, item: int) -> String:
	if not take_unite(menu, item):
		return ""
	_apply_effect(menu, item)
	_announce(menu, item)
	return unite_chat(menu)


static func take_unite(menu: int, item: int) -> bool:
	var record := _read()
	var unites: Array = record.get("unites", [])
	for index in unites.size():
		if not (unites[index] is Dictionary):
			continue
		var card: Dictionary = unites[index]
		if int(card.get("menu", -1)) != menu or int(card.get("item", -1)) != item:
			continue
		unites.remove_at(index)
		record["unites"] = unites
		_write(record)
		return true
	return false


## Charges for the SpeedChat UNITE! list. Order is Toon-up, Gag-up, jellybeans.
static func unite_groups() -> Array:
	var counts := {}
	for card in _read().get("unites", []):
		if not (card is Dictionary):
			continue
		var menu := int((card as Dictionary).get("menu", -1))
		var item := int((card as Dictionary).get("item", -1))
		var key := "%d:%d" % [menu, item]
		counts[key] = int(counts.get(key, 0)) + 1
	var rows: Array = []
	var order: Array = [[0, 5], [2, 8], [1, 4]]
	for pair in order:
		var menu := int((pair as Array)[0])
		var count := int((pair as Array)[1])
		for item in count:
			var charges := int(counts.get("%d:%d" % [menu, item], 0))
			if charges <= 0:
				continue
			rows.append({
				"menu": menu,
				"item": item,
				"charges": charges,
				"label": _phrase_label(menu, item),
			})
	return rows


static func unite_chat(menu: int) -> String:
	if menu == 0:
		return "Toons of the World, Toon-up!"
	if menu == 1:
		return "Toons of the World, Spend Wisely!"
	return "Toons of the World, Gag-up!"


## A nearby toon receiving the phrase. Their own card is not spent.
static func receive_unite(menu: int, item: int) -> void:
	_apply_effect(menu, item)


static func use_summon() -> String:
	var record := _read()
	var summons: Array = record.get("summons", [])
	if summons.is_empty() or not (summons[0] is Dictionary):
		return "You have no cog summons."
	var card: Dictionary = summons[0]
	var result := _apply_summon(card)
	if result.begins_with("Stand") or result.begins_with("This street") or result.begins_with("There is"):
		return result
	summons.remove_at(0)
	record["summons"] = summons
	_write(record)
	return result


static func unite_count() -> int:
	return (_read().get("unites", []) as Array).size()


static func summon_count() -> int:
	return (_read().get("summons", []) as Array).size()


static func attach(page: Control) -> void:
	if page == null or page.get_node_or_null("BossRewardRow") != null:
		return
	var row := HBoxContainer.new()
	row.name = "BossRewardRow"
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var unite := Button.new()
	unite.name = "UseUnite"
	unite.pressed.connect(func() -> void:
		_toast(page, use_unite())
		_refresh_row(page)
	)
	row.add_child(unite)
	var summon := Button.new()
	summon.name = "UseSummon"
	summon.pressed.connect(func() -> void:
		_toast(page, use_summon())
		_refresh_row(page)
	)
	row.add_child(summon)
	page.add_child(row)
	_refresh_row(page)


static func place(page: Control, page_size: Vector2) -> void:
	var row := page.get_node_or_null("BossRewardRow") as Control
	if row == null:
		return
	row.position = Vector2(8.0, page_size.y - 36.0)
	_refresh_row(page)


static func _refresh_row(page: Control) -> void:
	var unite := page.get_node_or_null("BossRewardRow/UseUnite") as Button
	var summon := page.get_node_or_null("BossRewardRow/UseSummon") as Button
	if unite != null:
		unite.text = "Unite (%d)" % unite_count()
		unite.disabled = unite_count() <= 0
	if summon != null:
		summon.text = "Summon (%d)" % summon_count()
		summon.disabled = summon_count() <= 0


static func _toast(page: Control, text: String) -> void:
	var note := page.get_node_or_null("BossRewardNote") as Label
	if note == null:
		note = Label.new()
		note.name = "BossRewardNote"
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.size = Vector2(280, 64)
		page.add_child(note)
	note.position = Vector2(8, page.size.y - 100)
	note.text = text


static func _apply_unite(menu: int, item: int) -> String:
	if not _apply_effect(menu, item):
		return "The unite fizzled."
	if menu == 0:
		return "Toons of the world, Toon-up!"
	if menu == 1:
		return "Toons of the world, spend some jellybeans!"
	if item >= 7:
		return "Toons of the world, restock all gags!"
	return "Toons of the world, restock %s!" % _TRACKS[clampi(item, 0, 6)]


static func _apply_effect(menu: int, item: int) -> bool:
	var pockets = load(_POCKETS)
	var loadout = pockets.for_selected()
	if menu == 0:
		var amount := int(_TOONUP[clampi(item, 0, _TOONUP.size() - 1)])
		if loadout == null:
			return false
		if amount < 0:
			loadout.set_hp(loadout.max_hp, loadout.max_hp)
		else:
			loadout.gain_hp(amount)
		loadout.save()
		return true
	if menu == 1:
		var beans := int(_MONEY[clampi(item, 0, _MONEY.size() - 1)])
		beans *= int(load(_HOLIDAYS).bean_scale("boss"))
		load(_BEANS).add_beans(beans)
		return true
	if loadout == null:
		return false
	if item >= 7:
		restock_all(loadout)
		return true
	_fill_track(loadout, clampi(item, 0, int(load(_POCKETS).TRACK_COUNT) - 1))
	loadout.save()
	return true


static func _announce(menu: int, item: int) -> void:
	var social := ToonSocial.live()
	if social == null:
		return
	var origin := Vector3.ZERO
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var body := _local_body(tree.root)
		if body != null:
			origin = body.global_position
	social.share_unite(menu, item, origin)


static func _local_body(node: Node) -> Node3D:
	if node is Node3D and int(node.get_meta("av", 0)) == ToonRoster.avatar_id():
		return node as Node3D
	for child in node.get_children():
		var found := _local_body(child)
		if found != null:
			return found
	return null


static func _apply_summon(card: Dictionary) -> String:
	var dept := clampi(int(card.get("dept", 0)), 0, 3)
	var cog_type := clampi(int(card.get("type", 0)), 0, 7)
	var code := String((_CODES[dept] as Array)[cog_type])
	var kind := String(card.get("kind", "single"))
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return "Stand on a street to use this summon."
	var suits := tree.root.find_child("StreetSuits", true, false)
	if suits == null:
		return "Stand on a street to use this summon."
	if kind == "invasion":
		var cog: Dictionary = suits.call("_find_named", code)
		if cog.is_empty():
			return "This cog does not exist!"
		return String(load(_HOLIDAYS).begin_invasion(cog, 1000, false))
	if kind == "building":
		var district := int(suits.get("district_id"))
		var slug := String(suits.get("street_slug"))
		var traffic := tree.root.get_node_or_null("/root/StreetTraffic")
		if traffic == null or not traffic.has_method("claim_takeover"):
			return "This street has no open shop for a Cog building."
		var plan: Dictionary = traffic.call("claim_takeover", district, slug)
		if plan.is_empty():
			return "This street has no open shop for a Cog building."
		plan["track"] = _DEPT_LETTER[dept]
		plan["difficulty"] = cog_type
		plan["floors"] = clampi(cog_type + 1, 1, 5)
		load(_NET).ask_building(district, slug, "take", plan)
		return "A Cog building is taking over a shop on this street."
	var near := Vector3.ZERO
	var body := tree.root.find_child("Player", true, false) as Node3D
	if body != null:
		near = body.global_position
	return String(suits.call("summon_named", code, -1, near))


static func _fill_track(loadout, track: int) -> void:
	var pockets = load(_POCKETS)
	for level in range(int(pockets.LEVEL_COUNT) - 1, -1, -1):
		var added := 1
		while added > 0:
			added = loadout.purchase(track, level)


static func _phrase_label(menu: int, item: int) -> String:
	if menu == 0:
		var amount := int(_TOONUP[clampi(item, 0, _TOONUP.size() - 1)])
		var word := "Max" if amount < 0 else str(amount)
		return "%s Toon-up" % word
	if menu == 1:
		return "%s jellybeans" % int(_MONEY[clampi(item, 0, _MONEY.size() - 1)])
	var tracks: PackedStringArray = ["Heal", "Trap", "Lure", "Sound", "Throw", "Squirt", "Drop", "All"]
	return "Gag-up %s" % tracks[clampi(item, 0, tracks.size() - 1)]


static func _unite_label(menu: int, item: int) -> String:
	if menu == 0:
		var amount := int(_TOONUP[clampi(item, 0, _TOONUP.size() - 1)])
		if amount < 0:
			return "Max Toon-up"
		return "%d Toon-up" % amount
	if menu == 1:
		return "%d jellybeans" % int(_MONEY[clampi(item, 0, _MONEY.size() - 1)])
	if item >= 7:
		return "Gag-up All"
	return "Gag-up %s" % _TRACKS[clampi(item, 0, 6)]


static func _roll_sos() -> Dictionary:
	return _roll_band(3, 5)


static func _roll_band(low: int, high: int) -> Dictionary:
	_load_catalog()
	if _catalog.is_empty():
		return {}
	var stars: Array = []
	for item in _catalog:
		if not (item is Dictionary):
			continue
		var rarity := int((item as Dictionary).get("rarity", 0))
		if rarity >= low and rarity <= high:
			stars.append(item)
	if stars.is_empty():
		return {}
	var picked: Dictionary = stars[randi() % stars.size()]
	return picked.duplicate(true)


static func _load_catalog() -> void:
	if not _catalog.is_empty():
		return
	if not FileAccess.file_exists(_SOS_FILE):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_SOS_FILE))
	if parsed is Array:
		_catalog = parsed


static func _read() -> Dictionary:
	if not FileAccess.file_exists(_PATH):
		return {"sos": [], "unites": [], "summons": [], "pink": 0}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_PATH))
	if parsed is Dictionary:
		return parsed
	return {"sos": [], "unites": [], "summons": [], "pink": 0}


static func _write(record: Dictionary) -> void:
	var file := FileAccess.open(_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(record))
