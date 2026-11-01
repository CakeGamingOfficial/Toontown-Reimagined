extends Node

## The street copy of a battle. The server decides the round. This shows the
## face-off, the gag each toon picked, and then plays the movie.

const REACH := 6.0
const JOIN_REACH := 20.0
const BATTLE_MUSIC := "res://assets/audio/battle/encntr_general_bg.mp3"
const BATTLE_VOLUME := 0.9
const PLACE_VOLUME := 0.8

var _layer: CanvasLayer
var _panels: Control
var _banner: Label
var _timer: Label
var _targets: VBoxContainer
var _menu: BattleMenu
var _fight: Dictionary = {}
var _asking := false
var _ask_seq := -1
var _pending := Vector2i(-1, -1)
var _need_target := false
var _sent_seq := -1
var _spent_seq := -1
var _credit_seq := -1
var _movie_seq := -1
var _show_gen := 0
var _gags
var _shown: Dictionary = {}
var _cool := 0.0
var _scan := 0.0
var _music: AudioStreamPlayer
var _place: AudioStreamPlayer
var _in_it := false
var _clock_key := ""
var _clock_left := 0.0
var _clock_age := 0.0
var _ask_wait := 0.0


static func attach(host: Node) -> void:
	if Engine.is_editor_hint() or host.get_node_or_null("StreetFight") != null:
		return
	if host.get_node_or_null("StreetSuits") == null:
		return
	var node: Node = load("res://scenes/battle/street_fight.gd").new()
	node.name = "StreetFight"
	host.add_child(node)


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 24
	add_child(_layer)
	var root := Control.new()
	root.name = "BattleHud"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	_panels = Control.new()
	_panels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_panels)
	_banner = _caption(root)
	_timer = _caption(root)
	_targets = VBoxContainer.new()
	_targets.alignment = BoxContainer.ALIGNMENT_CENTER
	_targets.visible = false
	root.add_child(_targets)
	_menu = BattleMenu.new()
	_menu.visible = false
	root.add_child(_menu)
	_gags = load("res://scenes/battle/gag_movie.gd").new()
	_gags.name = "GagMovie"
	add_child(_gags)
	var view := get_viewport()
	if view != null and not view.size_changed.is_connected(_layout):
		view.size_changed.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)
	_ask_wait = maxf(_ask_wait - delta, 0.0)
	var rows := _rows()
	var fight := _joined(rows)
	var mine := not fight.is_empty()
	_hold(mine)
	var toon := _toon()
	if toon != null:
		toon.call("unpin_remotes")
	for item in rows:
		if item is Dictionary:
			_place_bodies(item)
	_release_idle(rows)
	if not mine:
		_clear_movie()
		_show_panels([])
		_banner.text = ""
		_timer.text = ""
		_targets.visible = false
		_stop_music()
		_scan += delta
		if _scan < 0.35:
			return
		_scan = 0.0
		var opening := _joinable(rows)
		if opening.is_empty():
			_try_start()
		else:
			_fight = opening
			_try_join(opening, false)
		return
	_fight = fight
	_start_music()
	_timer.text = _clock(fight, delta)
	_show_panels(fight.get("toons", []))
	_spend(fight)
	_play(fight, delta)
	_choose(fight, true)


func _rows() -> Array:
	var suits := get_parent().get_node_or_null("StreetSuits")
	if suits == null:
		return []
	var district := int(suits.get("district_id"))
	var slug := str(suits.get("street_slug"))
	if district < 0 or slug == "":
		return []
	var state := ToonNet.latest("fights:%d:%s" % [district, slug])
	return state.get("rows", [])


func _joined(rows: Array) -> Dictionary:
	var peer := ToonNet.peer_id()
	for item in rows:
		if item is Dictionary and _has_toon(item, peer):
			return item
	return {}


func _joinable(rows: Array) -> Dictionary:
	var here := _point()
	var best: Dictionary = {}
	var best_dist := JOIN_REACH
	for item in rows:
		if not (item is Dictionary):
			continue
		var fight: Dictionary = item
		if String(fight.get("state", "")) != "join":
			continue
		var origin := _vec(fight.get("origin", []))
		var dist := Vector2(origin.x - here.x, origin.z - here.z).length()
		if dist <= best_dist:
			best = fight
			best_dist = dist
	return best


func _release_idle(rows: Array) -> void:
	var busy: Dictionary = {}
	for item in rows:
		if not (item is Dictionary):
			continue
		var fight: Dictionary = item
		if String(fight.get("state", "")) == "reward":
			continue
		for cog in fight.get("cogs", []):
			if cog is Dictionary:
				busy[int((cog as Dictionary).get("id", 0))] = true
	var suits := get_parent().get_node_or_null("StreetSuits")
	if suits == null:
		return
	for child in suits.get_children():
		var cog_id := int(child.get_meta("do_id", 0))
		if busy.has(cog_id):
			continue
		if child.has_method("hold_fight") and bool(child.get_meta("in_fight", false)):
			child.call("hold_fight", false, child.global_position, child.rotation.y)


func _try_start() -> void:
	if _cool > 0.0 or _ask_wait > 0.0 or _busy():
		return
	var cog := _nearest_cog(REACH)
	if cog == null:
		return
	var toon := _toon()
	if toon == null:
		return
	var hp: Vector2i = toon.call("battle_hp")
	_ask_wait = 1.2
	ToonNet.ask_fight(_street_district(), _street_slug(), int(cog.get_meta("do_id", 0)), str(toon.call("battle_name")), hp.x, hp.y)


func _try_join(fight: Dictionary, mine: bool) -> void:
	if mine or _ask_wait > 0.0 or _busy() or String(fight.get("state", "")) != "join":
		return
	var origin := _vec(fight.get("origin", []))
	var here := _point()
	if Vector2(origin.x - here.x, origin.z - here.z).length() > JOIN_REACH:
		return
	var toon := _toon()
	if toon == null:
		return
	var hp: Vector2i = toon.call("battle_hp")
	_ask_wait = 1.2
	ToonNet.ask_fight(_street_district(), _street_slug(), _first_cog(fight), str(toon.call("battle_name")), hp.x, hp.y)


func _choose(fight: Dictionary, mine: bool) -> void:
	var state := String(fight.get("state", ""))
	var seq := int(fight.get("seq", 0))
	if not mine or state != "input" or _sent_seq == seq:
		if _asking and _ask_seq != seq:
			_menu.cancel()
		if state != "input":
			_need_target = false
			_targets.visible = false
		return
	var toon := _toon()
	if toon == null:
		return
	var loadout: ToonLoadout = toon.call("battle_loadout")
	if loadout == null or loadout.hp <= 0:
		return
	if _need_target and _ask_seq == seq:
		if not _targets.visible:
			_show_targets(fight, loadout)
		return
	if _asking:
		return
	_asking = true
	_ask_seq = seq
	_menu.setup(loadout)
	_ask(fight, seq, loadout)


func _ask(fight: Dictionary, seq: int, loadout: ToonLoadout) -> void:
	var pick := await _menu.choose()
	_asking = false
	if not is_inside_tree():
		return
	if pick.x == -3 or int(_fight.get("seq", -1)) != seq:
		return
	if pick.x < 0:
		_send(pick.x, -1, -1, 0)
		return
	if ToonLoadout.affects_group(pick.x, pick.y):
		_send(pick.x, pick.y, -1, loadout.experience_of(pick.x))
		return
	_pending = pick
	_need_target = true
	_show_targets(_fight, loadout)


func _show_targets(fight: Dictionary, loadout: ToonLoadout) -> void:
	for child in _targets.get_children():
		child.queue_free()
	var track := _pending.x
	var prompt := Label.new()
	prompt.text = "Click a toon" if track == ToonLoadout.TOON_UP else "Click a cog"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_override("font", ToonGui.font())
	prompt.add_theme_font_size_override("font_size", 22)
	_targets.add_child(prompt)
	if track == ToonLoadout.TOON_UP:
		for item in fight.get("toons", []):
			var toon: Dictionary = item
			if int(toon.get("hp", 0)) <= 0:
				continue
			_target_button(String(toon.get("name", "Toon")), int(toon.get("id", 0)), loadout)
	else:
		for item in fight.get("cogs", []):
			var cog: Dictionary = item
			if int(cog.get("hp", 0)) <= 0:
				continue
			var title := "Level %d %s" % [int(cog.get("level", 1)), String(cog.get("name", "Cog"))]
			_target_button(title, int(cog.get("id", 0)), loadout)
	_targets.visible = true
	_layout()


func _target_button(title: String, target: int, loadout: ToonLoadout) -> void:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(280, 36)
	button.pressed.connect(_send.bind(_pending.x, _pending.y, target, loadout.experience_of(_pending.x)))
	_targets.add_child(button)


func _send(track: int, level: int, target: int, exp: int) -> void:
	_need_target = false
	_targets.visible = false
	_sent_seq = int(_fight.get("seq", -1))
	ToonNet.ask_gag(int(_fight.get("id", 0)), track, level, target, exp)


func _spend(fight: Dictionary) -> void:
	var seq := int(fight.get("seq", 0))
	if _spent_seq == seq or String(fight.get("state", "")) == "join":
		return
	var choice := _my_choice(fight)
	if choice.is_empty():
		return
	var track := int(choice.get("track", -1))
	var level := int(choice.get("level", -1))
	_spent_seq = seq
	if track < 0:
		return
	var toon := _toon()
	if toon == null:
		return
	var loadout: ToonLoadout = toon.call("battle_loadout")
	if loadout != null and loadout.spend_gag(track, level):
		loadout.save()


func _play(fight: Dictionary, _delta: float) -> void:
	var state := String(fight.get("state", ""))
	var seq := int(fight.get("seq", 0))
	if state != "movie":
		if _movie_seq != -1:
			_show_gen += 1
			_movie_seq = -1
		if state != "reward":
			_banner.text = ""
			_pose_local("", 0.0)
		if state == "input":
			_remember(fight, false)
	if state == "reward":
		_banner.text = "You did it!" if _mine(fight) else ""
		_pose_local("victory", 0.0)
		return
	if state != "movie" or _movie_seq == seq:
		return
	_movie_seq = seq
	_remember(fight, true)
	_show_gen += 1
	_show_movie(fight, _show_gen)


func _show_movie(fight: Dictionary, token: int) -> void:
	var beats: Array = fight.get("beats", [])
	var index := 0
	while index < beats.size():
		if token != _show_gen or not is_inside_tree():
			return
		if String(_fight.get("state", "")) != "movie":
			return
		var lead: Dictionary = beats[index]
		var group: Array = [lead]
		var cursor := index + 1
		while cursor < beats.size():
			var nxt: Dictionary = beats[cursor]
			if float(nxt.get("dur", 1.0)) > 0.001 or not _same_gag(lead, nxt):
				break
			group.append(nxt)
			cursor += 1
		_banner.text = String(lead.get("text", ""))
		var attacker := int(lead.get("toon", -1))
		_idle_others(attacker)
		if attacker != ToonNet.peer_id():
			_pose_local("", 0.0)
		var marked := {"done": false}
		await _gags.play(group, Callable(self, "_actor_for"), Callable(self, "_cog_node"), func() -> bool:
			return token == _show_gen and is_inside_tree()
		, func() -> void:
			if bool(marked["done"]):
				return
			marked["done"] = true
			for shown in group:
				_apply_beat(shown)
				_credit(fight, shown)
		)
		if not bool(marked["done"]):
			for missed in group:
				_apply_beat(missed)
				_credit(fight, missed)
		index = cursor


func _same_gag(lead: Dictionary, nxt: Dictionary) -> bool:
	if String(lead.get("kind", "")) != "gag" or String(nxt.get("kind", "")) != "gag":
		return false
	var track := int(lead.get("track", -1))
	var level := int(lead.get("level", -1))
	if not ToonLoadout.affects_group(track, level):
		return false
	return track == int(nxt.get("track", -2)) and level == int(nxt.get("level", -2)) and int(lead.get("toon", -1)) == int(nxt.get("toon", -2))


func _actor_for(peer: int) -> ToonActor:
	var toon := _toon()
	if toon == null:
		return null
	if peer == ToonNet.peer_id():
		return toon.call("battle_actor")
	return toon.call("remote_actor", peer)


func _apply_beat(beat: Dictionary) -> void:
	var cog_id := int(beat.get("cog", 0))
	if beat.has("cog_hp") and int(beat.get("cog_hp", -1)) >= 0 and cog_id != 0:
		_shown["c:%d" % cog_id] = int(beat.get("cog_hp", 0))
	var toon_id := int(beat.get("toon", 0))
	if beat.has("toon_hp"):
		_shown["t:%d" % int(beat.get("toon_id", toon_id))] = int(beat.get("toon_hp", 0))
		toon_id = int(beat.get("toon_id", toon_id))
	_push_laff(toon_id)


func _credit(fight: Dictionary, beat: Dictionary) -> void:
	if int(beat.get("toon", 0)) != ToonNet.peer_id():
		return
	var track := int(beat.get("track", -1))
	if track < 0 or _credit_seq == int(fight.get("seq", 0)):
		return
	_credit_seq = int(fight.get("seq", 0))
	var toon := _toon()
	if toon == null:
		return
	var loadout: ToonLoadout = toon.call("battle_loadout")
	if loadout == null:
		return
	loadout.add_experience(track, ToonLoadout.SKILL_CREDIT)
	loadout.save()


func _remember(fight: Dictionary, opening: bool) -> void:
	for item in fight.get("toons", []):
		var toon: Dictionary = item
		var key := "t:%d" % int(toon.get("id", 0))
		if opening:
			_shown[key] = int(toon.get("was", toon.get("hp", 0)))
		else:
			_shown[key] = int(toon.get("hp", 0))
		_push_laff(int(toon.get("id", 0)))
	for item in fight.get("cogs", []):
		var suit: Dictionary = item
		var cog_key := "c:%d" % int(suit.get("id", 0))
		if opening:
			_shown[cog_key] = int(suit.get("was", suit.get("hp", 0)))
		else:
			_shown[cog_key] = int(suit.get("hp", 0))


func _push_laff(toon_id: int) -> void:
	if toon_id != ToonNet.peer_id():
		return
	var toon := _toon()
	if toon == null or not _shown.has("t:%d" % toon_id):
		return
	var loadout: ToonLoadout = toon.call("battle_loadout")
	if loadout == null:
		return
	loadout.set_hp(int(_shown["t:%d" % toon_id]), loadout.max_hp)
	loadout.save()


func _idle_others(active_peer: int) -> void:
	var toon := _toon()
	if toon == null:
		return
	for item in _fight.get("toons", []):
		if not (item is Dictionary):
			continue
		var peer := int((item as Dictionary).get("id", 0))
		if peer == ToonNet.peer_id() or peer == active_peer:
			continue
		var actor: ToonActor = toon.call("remote_actor", peer)
		if actor != null:
			actor.set_locomotion(0.0, false, false, 0.0)


func _pose_local(clip: String, elapsed: float) -> void:
	var toon := _toon()
	if toon == null:
		return
	var actor: ToonActor = toon.call("battle_actor")
	if actor == null:
		return
	if clip == "":
		actor.set_locomotion(0.0, false, false, 0.0)
		return
	actor.pose_action(clip, elapsed)


func _place_bodies(fight: Dictionary) -> void:
	var toon := _toon()
	var cog_center := _center(fight.get("cogs", []))
	var toon_center := _center(fight.get("toons", []))
	if toon == null:
		toon_center = cog_center
	else:
		for member in fight.get("toons", []):
			var row: Dictionary = member
			var spot := _vec(row.get("slot", []))
			var facing := _yaw(spot, cog_center)
			if int(row.get("id", 0)) == ToonNet.peer_id():
				toon.call("place_for_battle", spot, facing)
			else:
				toon.call("pin_remote", int(row.get("id", 0)), spot, facing)
	for suit_row in fight.get("cogs", []):
		var suit: Dictionary = suit_row
		var stand := _vec(suit.get("slot", []))
		var cog := _cog_node(int(suit.get("id", 0)))
		if cog == null or not cog.has_method("hold_fight"):
			continue
		cog.call("hold_fight", true, stand, deg_to_rad(_yaw(stand, toon_center)))
		if String(fight.get("state", "")) != "movie" and cog.has_method("begin_react"):
			cog.call("begin_react", "", 0.0)


func _show_panels(toons: Array) -> void:
	var signature := _panel_sig(toons)
	if signature != str(_panels.get_meta("sig", "")):
		for child in _panels.get_children():
			child.queue_free()
		_panels.set_meta("sig", signature)
		for item in toons:
			var built: Dictionary = item
			var panel := Panel.new()
			panel.name = "Toon%d" % int(built.get("id", 0))
			panel.modulate = Color(0.55, 0.9, 0.45, 0.92)
			var name := Label.new()
			name.name = "Name"
			name.add_theme_font_override("font", ToonGui.font())
			name.add_theme_font_size_override("font_size", 16)
			name.add_theme_color_override("font_color", Color(0.05, 0.14, 0.4))
			panel.add_child(name)
			var laff := Label.new()
			laff.name = "Laff"
			laff.add_theme_font_override("font", ToonGui.font())
			laff.add_theme_font_size_override("font_size", 14)
			laff.add_theme_color_override("font_color", Color(0.05, 0.14, 0.4))
			panel.add_child(laff)
			var icon := TextureRect.new()
			icon.name = "Icon"
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			panel.add_child(icon)
			var which := Label.new()
			which.name = "Which"
			which.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			which.add_theme_font_override("font", ToonGui.font())
			which.add_theme_font_size_override("font_size", 18)
			which.add_theme_color_override("font_color", Color(0.05, 0.14, 0.4))
			panel.add_child(which)
			_panels.add_child(panel)
		_layout()
	for member in toons:
		var row: Dictionary = member
		var card := _panels.get_node_or_null("Toon%d" % int(row.get("id", 0))) as Panel
		if card == null:
			continue
		var name_label := card.get_node("Name") as Label
		var laff_label := card.get_node("Laff") as Label
		var icon_rect := card.get_node("Icon") as TextureRect
		var which_label := card.get_node("Which") as Label
		name_label.text = String(row.get("name", "Toon"))
		var hp := int(_shown.get("t:%d" % int(row.get("id", 0)), row.get("hp", 0)))
		laff_label.text = "%d / %d" % [hp, int(row.get("max_hp", hp))]
		_fill_choice(icon_rect, which_label, row)


func _fill_choice(icon: TextureRect, which: Label, toon: Dictionary) -> void:
	var choice := _choice_for(int(toon.get("id", 0)))
	if choice.is_empty() or String(_fight.get("state", "")) == "join":
		icon.texture = null
		which.text = "?"
		return
	var track := int(choice.get("track", -1))
	var level := int(choice.get("level", -1))
	if track < 0:
		icon.texture = null
		which.text = "Pass" if track == -1 else "Run"
		return
	icon.texture = BattleMenu.icon_for(track, level)
	which.text = _which_text(track, level, int(choice.get("target", -1)))


func _which_text(track: int, level: int, target: int) -> String:
	var marks := ""
	if track == ToonLoadout.TOON_UP and not ToonLoadout.affects_group(track, level):
		for item in _fight.get("toons", []):
			var toon: Dictionary = item
			marks += "X" if int(toon.get("id", 0)) == target else "-"
		return marks
	if ToonLoadout.affects_group(track, level):
		for item in _fight.get("cogs", []):
			var group: Dictionary = item
			marks += "X" if int(group.get("hp", 0)) > 0 else "-"
		return marks
	for item in _fight.get("cogs", []):
		var single: Dictionary = item
		marks += "X" if int(single.get("id", 0)) == target else "-"
	return marks


func _panel_sig(toons: Array) -> String:
	var parts: PackedStringArray = []
	for item in toons:
		if item is Dictionary:
			parts.append(str((item as Dictionary).get("id", 0)))
	parts.append(str(_fight.get("seq", 0)))
	return "|".join(parts)


func _choice_for(peer: int) -> Dictionary:
	for item in _fight.get("choices", []):
		if item is Dictionary and int((item as Dictionary).get("id", -1)) == peer:
			return item
	return {}


func _my_choice(fight: Dictionary) -> Dictionary:
	var peer := ToonNet.peer_id()
	for item in fight.get("choices", []):
		if item is Dictionary and int((item as Dictionary).get("id", -1)) == peer:
			return item
	return {}


func _hold(active: bool) -> void:
	if active == _in_it:
		if not active:
			_release_remotes()
		return
	_in_it = active
	var toon := _toon()
	if toon != null:
		toon.call("hold_for_battle", active)
	if not active:
		_cool = 2.0
		_sent_seq = -1
		_need_target = false
		_targets.visible = false
		if _asking:
			_menu.cancel()
		_show_gen += 1
		if _gags != null:
			_gags.clear_traps()
		_release_cogs()
		_release_remotes()
		_recover()


func _recover() -> void:
	var toon := _toon()
	if toon == null:
		return
	var loadout: ToonLoadout = toon.call("battle_loadout")
	if loadout != null and loadout.hp <= 0:
		loadout.set_hp(1, loadout.max_hp)
		loadout.save()


func _release_cogs() -> void:
	var suits := get_parent().get_node_or_null("StreetSuits")
	if suits == null:
		return
	for child in suits.get_children():
		if child.has_method("hold_fight") and bool(child.get_meta("in_fight", false)):
			child.call("hold_fight", false, child.global_position, child.rotation.y)


func _release_remotes() -> void:
	var toon := _toon()
	if toon != null:
		toon.call("unpin_remotes")


func _clear_movie() -> void:
	_movie_seq = -1
	_fight = {}


func _clock(fight: Dictionary, delta: float) -> String:
	var state := String(fight.get("state", ""))
	if state != "join" and state != "input":
		return ""
	var key := "%s:%s" % [fight.get("id", 0), fight.get("seq", 0)]
	var posted := float(fight.get("left", 0.0))
	if key != _clock_key:
		_clock_key = key
		_clock_left = posted
		_clock_age = 0.0
	elif absf(posted - (_clock_left - _clock_age)) > 0.75:
		_clock_left = posted
		_clock_age = 0.0
	else:
		_clock_age += delta
	var left := maxf(_clock_left - _clock_age, 0.0)
	if state == "join":
		return "Join  %d" % int(ceil(left))
	return "Pick a gag  %d" % int(ceil(left))


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.y < 1.0:
		return
	var count := _panels.get_child_count()
	for index in count:
		var panel := _panels.get_child(index) as Control
		var span := 0.55
		var x := (float(index) - float(count - 1) * 0.5) * span
		ToonGui.place(panel, view, x, 0.78, 0.5, 0.34)
		var name := panel.get_node_or_null("Name") as Control
		var laff := panel.get_node_or_null("Laff") as Control
		var icon := panel.get_node_or_null("Icon") as Control
		var which := panel.get_node_or_null("Which") as Control
		if name != null:
			name.position = Vector2(8, 4)
			name.size = Vector2(panel.size.x - 16, 22)
		if laff != null:
			laff.position = Vector2(8, 26)
			laff.size = Vector2(panel.size.x - 16, 20)
		if icon != null:
			icon.position = Vector2(panel.size.x * 0.5 - 28, 50)
			icon.size = Vector2(56, 56)
		if which != null:
			which.position = Vector2(8, panel.size.y - 28)
			which.size = Vector2(panel.size.x - 16, 24)
	ToonGui.place(_banner, view, 0.0, 0.42, 1.6, 0.12)
	ToonGui.place(_timer, view, 0.0, 0.95, 0.8, 0.1)
	ToonGui.place(_targets, view, 0.0, -0.15, 0.9, 0.7)


func _caption(parent: Node) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", ToonGui.font())
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.2, 0.5))
	label.add_theme_constant_override("outline_size", 6)
	parent.add_child(label)
	return label


func _start_music() -> void:
	if _music != null:
		return
	_place = _place_track(get_parent())
	if _place != null:
		_place.stop()
	var stream := load(BATTLE_MUSIC) as AudioStreamMP3
	if stream == null:
		return
	stream = stream.duplicate() as AudioStreamMP3
	stream.loop = true
	_music = ToonAudio.music_player()
	_music.name = "BattleMusic"
	_music.stream = stream
	_music.volume_db = linear_to_db(BATTLE_VOLUME)
	add_child(_music)
	_music.play()


func _stop_music() -> void:
	if _music != null:
		_music.stop()
		_music.queue_free()
		_music = null
	if _place != null and is_instance_valid(_place):
		_place.volume_db = linear_to_db(PLACE_VOLUME)
		_place.play()
	_place = null


func _place_track(node: Node) -> AudioStreamPlayer:
	var current := node
	while current != null:
		for child in current.get_children():
			var player := child as AudioStreamPlayer
			if player != null and str(player.name).ends_with("Music") and player.name != "BattleMusic":
				return player
		current = current.get_parent()
	return null


func _nearest_cog(reach: float) -> Node:
	var suits := get_parent().get_node_or_null("StreetSuits")
	if suits == null:
		return null
	var here := _point()
	var best: Node = null
	var best_dist := reach
	for child in suits.get_children():
		if not child.has_method("on_lane") or not bool(child.call("on_lane")):
			continue
		if int(child.get_meta("do_id", 0)) == 0:
			continue
		if bool(child.get_meta("in_fight", false)):
			continue
		var cog := child as Node3D
		if cog == null:
			continue
		var dist := Vector2(cog.global_position.x - here.x, cog.global_position.z - here.z).length()
		if dist <= best_dist:
			best = child
			best_dist = dist
	return best


func _cog_node(cog_id: int) -> Node:
	if cog_id == 0:
		return null
	var suits := get_parent().get_node_or_null("StreetSuits")
	if suits == null:
		return null
	for child in suits.get_children():
		if int(child.get_meta("do_id", 0)) == cog_id:
			return child
	return null


func _busy() -> bool:
	var toon := _toon()
	if toon == null:
		return true
	return bool(toon.call("battle_busy"))


func _mine(fight: Dictionary) -> bool:
	return _has_toon(fight, ToonNet.peer_id())


func _has_toon(fight: Dictionary, peer: int) -> bool:
	for item in fight.get("toons", []):
		if item is Dictionary and int((item as Dictionary).get("id", -1)) == peer:
			return true
	return false


func _first_cog(fight: Dictionary) -> int:
	for item in fight.get("cogs", []):
		if item is Dictionary:
			return int((item as Dictionary).get("id", 0))
	return 0


func _center(rows: Array) -> Vector3:
	if rows.is_empty():
		return _vec(_fight.get("origin", []))
	var total := Vector3.ZERO
	var count := 0
	for item in rows:
		if not (item is Dictionary):
			continue
		total += _vec((item as Dictionary).get("slot", []))
		count += 1
	if count == 0:
		return _vec(_fight.get("origin", []))
	return total / float(count)


func _yaw(from: Vector3, to: Vector3) -> float:
	var flat := Vector2(to.x - from.x, to.z - from.z)
	if flat.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(atan2(-flat.x, -flat.y))


func _vec(value: Variant) -> Vector3:
	if value is Array:
		var row: Array = value
		if row.size() >= 3:
			return Vector3(float(row[0]), float(row[1]), float(row[2]))
	return Vector3.ZERO


func _point() -> Vector3:
	var toon := _toon()
	if toon == null:
		return Vector3.ZERO
	return toon.call("battle_point")


func _street_district() -> int:
	var suits := get_parent().get_node_or_null("StreetSuits")
	if suits == null:
		return ToonNet.district_id()
	return int(suits.get("district_id"))


func _street_slug() -> String:
	var suits := get_parent().get_node_or_null("StreetSuits")
	if suits == null:
		return ""
	return str(suits.get("street_slug"))


func _toon() -> Node:
	var host := get_parent()
	if host == null:
		return null
	return host.get_node_or_null("PlaygroundToon")
