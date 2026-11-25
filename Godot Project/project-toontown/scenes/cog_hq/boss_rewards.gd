extends RefCounted

## What a department boss leaves behind. The V.P. files an SOS card
## (attemptAddNPCFriend, two calls, 16 cards). The C.F.O. leaves a Resistance
## unite. The C.J. leaves a cog summon. The C.E.O. leaves pink slips. SOS and
## Fire are the battle inventory buttons. A unite is said from SpeedChat
## UNITE! and also from the disguise page. A summons is spent from that cog's
## button on the Cog Gallery, and the disguise page can still spend the first card.

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


static func hold_vp_sos(rentals: int = 0) -> Dictionary:
	if _held.is_empty():
		_held = _roll_sos(rentals)
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
	var stored := _store_sos(card, 1)
	if not stored.contains("joined your SOS"):
		return stored
	var friend := String(card.get("name", "a friend"))
	return "Thanks for the rescue!\nIf you need help in a fight, use this SOS card to call my friend %s." % friend


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


## ~max. Fill the SOS page, keep one of every unite and one summon for every
## cog in each kind, and set pink slips to 255. Cards already held stay put.
static func max_stock() -> String:
	_load_catalog()
	var record := _read()
	var cards: Array = record.get("sos", [])
	for item in _catalog:
		if cards.size() >= _MAX_SOS:
			break
		if not (item is Dictionary):
			continue
		var card := (item as Dictionary).duplicate(true)
		var npc := int(card.get("id", 0))
		var held_sos := false
		for existing in cards:
			if existing is Dictionary and int((existing as Dictionary).get("id", 0)) == npc:
				held_sos = true
				break
		if held_sos:
			continue
		card["calls"] = _CALLS
		cards.append(card)
	record["sos"] = cards
	var unites: Array = record.get("unites", [])
	var held_unites: Dictionary = {}
	for existing in unites:
		if existing is Dictionary:
			var unite := existing as Dictionary
			held_unites["%d:%d" % [int(unite.get("menu", 0)), int(unite.get("item", 0))]] = true
	for menu in 3:
		var count := 5 if menu == 0 else (4 if menu == 1 else 8)
		for item in count:
			var unite_key := "%d:%d" % [menu, item]
			if held_unites.has(unite_key):
				continue
			unites.append({"menu": menu, "item": item})
			held_unites[unite_key] = true
	record["unites"] = unites
	var summons: Array = record.get("summons", [])
	var held_summons: Dictionary = {}
	for existing in summons:
		if existing is Dictionary:
			var summon := existing as Dictionary
			held_summons["%d:%d:%s" % [int(summon.get("dept", 0)), int(summon.get("type", 0)), String(summon.get("kind", ""))]] = true
	var kinds: PackedStringArray = ["single", "building", "invasion"]
	for dept in 4:
		for cog_type in 8:
			for kind in kinds:
				var summon_key := "%d:%d:%s" % [dept, cog_type, kind]
				if held_summons.has(summon_key):
					continue
				summons.append({"dept": dept, "type": cog_type, "kind": kind})
				held_summons[summon_key] = true
	record["summons"] = summons
	record["pink"] = 255
	_write(record)
	return "Filled %d SOS cards, %d unites, %d summons, and 255 pink slips." % [cards.size(), unites.size(), summons.size()]


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


static func grant_summon(average: float) -> String:
	# giveCogSummonReward. The cog tier is the party's average suit, and a
	# summon the toon already carries is skipped for a different one.
	var cog_type := mini(int(average / 77.0 * 8.0), 7)
	var picked := _choose_summon(randi() % 4, cog_type, _roll_kind())
	if picked.is_empty():
		return "The Chief Justice had no new summon to sign."
	var record := _read()
	var summons: Array = record.get("summons", [])
	summons.append(picked)
	record["summons"] = summons
	_write(record)
	var kind := String(picked.get("kind", "single"))
	var label := "a single cog"
	if kind == "building":
		label = "a cog building"
	elif kind == "invasion":
		label = "an invasion"
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
	if _refused(result):
		return result
	summons.remove_at(0)
	record["summons"] = summons
	_write(record)
	return result


static func unite_count() -> int:
	return (_read().get("unites", []) as Array).size()


static func summon_count() -> int:
	return (_read().get("summons", []) as Array).size()


static func has_summon(dept: int, cog_type: int, kind: String) -> bool:
	return _has_summon(dept, cog_type, kind)


## reqCogSummons. The card is removed only when the summons lands.
## "busy" keeps it, the same way an invasion already in progress does.
static func spend_summon(dept: int, cog_type: int, kind: String) -> String:
	var safe_dept := clampi(dept, 0, 3)
	var safe_type := clampi(cog_type, 0, 7)
	if kind != "single" and kind != "building" and kind != "invasion":
		return "fail"
	if not _has_summon(safe_dept, safe_type, kind):
		return "fail"
	if kind == "invasion" and bool(load(_HOLIDAYS).invading()):
		return "busy"
	var record := _read()
	var summons: Array = record.get("summons", [])
	var found := -1
	for index in summons.size():
		var item: Variant = summons[index]
		if not (item is Dictionary):
			continue
		var card: Dictionary = item
		if int(card.get("dept", -1)) == safe_dept and int(card.get("type", -1)) == safe_type and String(card.get("kind", "")) == kind:
			found = index
			break
	if found < 0:
		return "fail"
	var chosen: Dictionary = summons[found]
	if _refused(_apply_summon(chosen)):
		return "badlocation"
	summons.remove_at(found)
	record["summons"] = summons
	_write(record)
	return "success"


static func _refused(result: String) -> bool:
	return result.begins_with("Stand") or result.begins_with("This street") or result.begins_with("There is") or result.begins_with("This cog") or result.begins_with("Unknown") or result.begins_with("Name a") or result.begins_with("Can't") or result.begins_with("A v2") or result.begins_with("A waiter") or result.begins_with("Only Bossbots")


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
	var applied := false
	if menu == 0:
		var amount := int(_TOONUP[clampi(item, 0, _TOONUP.size() - 1)])
		if loadout == null:
			return false
		if amount < 0:
			loadout.set_hp(loadout.max_hp, loadout.max_hp)
		else:
			loadout.gain_hp(amount)
		loadout.save()
		applied = true
	elif menu == 1:
		var beans := int(_MONEY[clampi(item, 0, _MONEY.size() - 1)])
		beans *= int(load(_HOLIDAYS).bean_scale("boss"))
		load(_BEANS).add_beans(beans)
		applied = true
	elif loadout != null:
		if item >= 7:
			restock_all(loadout)
		else:
			_fill_track(loadout, clampi(item, 0, int(pockets.TRACK_COUNT) - 1))
			loadout.save()
		applied = true
	if applied:
		_play_unite_fx(menu, item)
	return applied


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


const _SPARKLE := "res://assets/effects/fireworks/tt_t_efx_ext_particleSparkle.png"
const _GAG_ICONS: PackedStringArray = [
	"res://assets/gui/tutorial/gags/inventory_feather.png",
	"res://assets/gui/tutorial/gags/inventory_megaphone.png",
	"res://assets/gui/tutorial/gags/inventory_lipstick.png",
	"res://assets/gui/tutorial/gags/inventory_bamboo_cane.png",
	"res://assets/gui/tutorial/gags/inventory_pixiedust.png",
	"res://assets/gui/tutorial/gags/inventory_juggling_cubes.png",
	"res://assets/gui/tutorial/gags/inventory_ladder.png",
	"res://assets/gui/tutorial/gags/inventory_bannana_peel.png",
	"res://assets/gui/tutorial/gags/inventory_rake.png",
	"res://assets/gui/tutorial/gags/inventory_marbles.png",
	"res://assets/gui/tutorial/gags/inventory_quicksand_icon.png",
	"res://assets/gui/tutorial/gags/inventory_trapdoor.png",
	"res://assets/gui/tutorial/gags/inventory_tnt.png",
	"res://assets/gui/tutorial/gags/inventory_traintracks.png",
	"res://assets/gui/tutorial/gags/inventory_1dollarbill.png",
	"res://assets/gui/tutorial/gags/inventory_small_magnet.png",
	"res://assets/gui/tutorial/gags/inventory_5dollarbill.png",
	"res://assets/gui/tutorial/gags/inventory_big_magnet.png",
	"res://assets/gui/tutorial/gags/inventory_10dollarbill.png",
	"res://assets/gui/tutorial/gags/inventory_hypno_goggles.png",
	"res://assets/gui/tutorial/gags/inventory_screen.png",
	"res://assets/gui/tutorial/gags/inventory_bikehorn.png",
	"res://assets/gui/tutorial/gags/inventory_whistle.png",
	"res://assets/gui/tutorial/gags/inventory_bugle.png",
	"res://assets/gui/tutorial/gags/inventory_aoogah.png",
	"res://assets/gui/tutorial/gags/inventory_elephant.png",
	"res://assets/gui/tutorial/gags/inventory_fog_horn.png",
	"res://assets/gui/tutorial/gags/inventory_opera_singer.png",
	"res://assets/gui/tutorial/gags/inventory_tart.png",
	"res://assets/gui/tutorial/gags/inventory_fruit_pie_slice.png",
	"res://assets/gui/tutorial/gags/inventory_cream_pie_slice.png",
	"res://assets/gui/tutorial/gags/inventory_fruitpie.png",
	"res://assets/gui/tutorial/gags/inventory_creampie.png",
	"res://assets/gui/tutorial/gags/inventory_cake.png",
	"res://assets/gui/tutorial/gags/inventory_wedding.png",
	"res://assets/gui/tutorial/gags/inventory_squirt_flower.png",
	"res://assets/gui/tutorial/gags/inventory_glass_of_water.png",
	"res://assets/gui/tutorial/gags/inventory_water_gun.png",
	"res://assets/gui/tutorial/gags/inventory_seltzer_bottle.png",
	"res://assets/gui/tutorial/gags/inventory_firehose.png",
	"res://assets/gui/tutorial/gags/inventory_storm_cloud.png",
	"res://assets/gui/tutorial/gags/inventory_geyser.png",
	"res://assets/gui/tutorial/gags/inventory_flower_pot.png",
	"res://assets/gui/tutorial/gags/inventory_sandbag.png",
	"res://assets/gui/tutorial/gags/inventory_anvil.png",
	"res://assets/gui/tutorial/gags/inventory_weight.png",
	"res://assets/gui/tutorial/gags/inventory_safe_box.png",
	"res://assets/gui/tutorial/gags/inventory_piano.png",
	"res://assets/gui/tutorial/gags/inventory_ship.png",
]


static func _play_unite_fx(menu: int, item: int) -> void:
	# ResistanceChat.doEffect. The burst lasts 3 seconds on the speaker, and
	# every toon within 30 units takes the phrase color for a moment.
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var body := _local_body(tree.root)
	if body == null:
		return
	var tint := Color(1.0, 0.5, 1.0, 1.0)
	if menu == 1:
		tint = Color(0.0, 1.0, 0.0, 1.0)
	elif menu != 0:
		tint = Color(0.0, 0.0, 1.0, 1.0)
	_flash_near(body, tint)
	var host := Node3D.new()
	host.name = "UniteFx"
	body.add_child(host)
	if menu == 0:
		host.add_child(_burst(_SPARKLE, Color(1, 1, 1, 1), 80, 0.35))
	elif menu == 1:
		var colors: Array[Color] = [Color(1, 1, 0), Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1), Color(1, 0, 1)]
		for color in colors:
			var beans := _burst("", color, 20, 0.18)
			beans.draw_pass_1 = _bean_mesh(color)
			host.add_child(beans)
	else:
		for icon in _restock_icons(item):
			host.add_child(_burst(icon, Color.WHITE, 16, 0.5))
	tree.create_timer(3.2).timeout.connect(func() -> void:
		if is_instance_valid(host):
			host.queue_free()
	)


static func _burst(texture_path: String, tint: Color, amount: int, size: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 3.0
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.local_coords = true
	particles.visibility_aabb = AABB(Vector3(-16, -8, -16), Vector3(32, 24, 32))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 2.0
	process.direction = Vector3(0, 1, 0)
	process.spread = 180.0
	process.initial_velocity_min = 12.0
	process.initial_velocity_max = 20.0
	process.gravity = Vector3(0, -6.0, 0)
	process.scale_min = size * 0.7
	process.scale_max = size
	process.color = tint
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.albedo_color = tint
	if texture_path != "" and ResourceLoader.exists(texture_path):
		mat.albedo_texture = load(texture_path)
	quad.material = mat
	particles.draw_pass_1 = quad
	particles.emitting = true
	return particles


static func _bean_mesh(color: Color) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 0.7
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh.material = mat
	return mesh


static func _restock_icons(item: int) -> PackedStringArray:
	var icons := PackedStringArray()
	if item < 7:
		for level in 6:
			var index := item * 7 + level
			if index >= 0 and index < _GAG_ICONS.size():
				icons.append(_GAG_ICONS[index])
		return icons
	var tracks: Array[int] = [0, 1, 2, 3, 4, 5, 6]
	tracks.shuffle()
	for index in 6:
		var level := randi() % 6
		var slot := tracks[index] * 7 + level
		if slot >= 0 and slot < _GAG_ICONS.size():
			icons.append(_GAG_ICONS[slot])
	return icons


static func _flash_near(origin: Node3D, tint: Color) -> void:
	var tree := origin.get_tree()
	if tree == null:
		return
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.45)
	var painted: Array[MeshInstance3D] = []
	for node in tree.root.find_children("", "ToonActor", true, false):
		if not (node is Node3D):
			continue
		var actor := node as Node3D
		if actor.global_position.distance_to(origin.global_position) > 30.0:
			continue
		_overlay(actor, mat, painted)
	tree.create_timer(0.6).timeout.connect(func() -> void:
		for mesh in painted:
			if is_instance_valid(mesh):
				mesh.material_overlay = null
	)


static func _overlay(node: Node, mat: Material, painted: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		mesh.material_overlay = mat
		painted.append(mesh)
	for child in node.get_children():
		_overlay(child, mat, painted)


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


static func _roll_sos(rentals: int = 0) -> Dictionary:
	# A full party of rental suits draws only 3-star cards. One to three
	# rentals stop at 4 stars. No rentals draw 3 through 5.
	var high := 5
	if rentals >= 4:
		high = 3
	elif rentals >= 1:
		high = 4
	return _roll_band(3, high)


static func _roll_kind() -> String:
	var roll := randi() % 100
	if roll >= 97:
		return "invasion"
	if roll >= 70:
		return "building"
	return "single"


static func _has_summon(dept: int, cog_type: int, kind: String) -> bool:
	for item in _read().get("summons", []):
		if not (item is Dictionary):
			continue
		var card: Dictionary = item
		if int(card.get("dept", -1)) == dept and int(card.get("type", -1)) == cog_type and String(card.get("kind", "")) == kind:
			return true
	return false


static func _choose_summon(pref_dept: int, cog_type: int, pref_kind: String) -> Dictionary:
	var kinds: PackedStringArray = ["single", "building", "invasion"]
	if not _has_summon(pref_dept, cog_type, pref_kind):
		return {"dept": pref_dept, "type": cog_type, "kind": pref_kind}
	for kind in kinds:
		if not _has_summon(pref_dept, cog_type, kind):
			return {"dept": pref_dept, "type": cog_type, "kind": kind}
	for dept in 4:
		if not _has_summon(dept, cog_type, pref_kind):
			return {"dept": dept, "type": cog_type, "kind": pref_kind}
		for kind in kinds:
			if not _has_summon(dept, cog_type, kind):
				return {"dept": dept, "type": cog_type, "kind": kind}
	for _try in 5:
		var dept := randi() % 4
		var level := randi() % 8
		var kind := _roll_kind()
		if not _has_summon(dept, level, kind):
			return {"dept": dept, "type": level, "kind": kind}
	for kind in kinds:
		for level in 8:
			for dept in 4:
				if not _has_summon(dept, level, kind):
					return {"dept": dept, "type": level, "kind": kind}
	return {}


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
