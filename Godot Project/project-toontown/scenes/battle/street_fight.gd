extends Node

## The street copy of a battle. The server decides the round. This shows the
## face-off, the gag each toon picked, and then plays the movie.

const REACH := 6.0
## BattleBase.suitSpeed. createAdjustInterval times each suit by its own distance.
const SUIT_SPEED := 4.8
const JOIN_REACH := 20.0
## Movie.play runs for anyone who can see the battle. The camera track is
## added only when the local toon is pending or active.
const WATCH_REACH := 60.0
const BATTLE_MUSIC := "res://assets/audio/battle/encntr_general_bg.mp3"
const _REWARDS := preload("res://scenes/cog_hq/boss_rewards.gd")
const BATTLE_VOLUME := 0.9
const PLACE_VOLUME := 0.8
const _LOSE := "res://assets/audio/battle/ENC_Lose.ogg"
const _WIN := "res://assets/audio/sfx/ENC_Win.mp3"
const _ARRIVAL := preload("res://scenes/playgrounds/playground_toon.gd")
const _PLACES := preload("res://scenes/places/hood_places.gd")
const _TITLES := preload("res://scenes/places/zone_title.gd")
const _HOLIDAYS := preload("res://scenes/shticker/calendar_holidays.gd")
const _FACTORY := preload("res://scenes/cog_hq/factory_props.gd")
const _MINT := preload("res://scenes/cog_hq/mint_props.gd")
const _MINT_RIDE := preload("res://scenes/cog_hq/mint_elevator.gd")
## Toon.getDiedInterval: lose, ENC_Lose at 2s, then a 1.5s shrink starting at 5.333.
const _LOSE_SHRINK := 5.333
const _LOSE_END := 6.833

var _layer: CanvasLayer
var _banner: Label
var _hud: BattleHud
var _reward: RewardPanel
var _menu: BattleMenu
var _fight: Dictionary = {}
var _asking := false
var _ask_seq := -1
var _pending := Vector2i(-1, -1)
var _need_target := false
var _sent_seq := -1
var _spent_seq := -1
var _movie_seq := -1
var _show_gen := 0
var _gags
var _shown: Dictionary = {}
var _credited_fight := -1
var _credited: Dictionary = {}
var _cool := 0.0
var _scan := 0.0
var _music: AudioStreamPlayer
var _place: AudioStreamPlayer
var _in_it := false
var _clock_key := ""
var _clock_left := 0.0
var _clock_age := 0.0
var _ask_wait := 0.0
var _saved_fov := -1.0
var _reward_seq := -1
var _reward_token := 0
var _paid_key := ""
var _factory_key := ""
var _mint_key := ""
var _dance := 0.0
var _win: AudioStreamPlayer
var _dying := false
var _sad_started: Dictionary = {}
var _face_key := ""
var _face_left := 0.0
var _face_age := 0.0
var _face_elapsed := 0.0
var _face_from: Dictionary = {}
var _face_spoke := ""
static var sad_fight := -1


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
	_banner = _caption(root)
	_menu = BattleMenu.new()
	_menu.visible = false
	_menu.z_index = 2
	root.add_child(_menu)
	_hud = BattleHud.new()
	_hud.bind_host(self)
	_hud.chose.connect(_on_target)
	_hud.backed.connect(_on_back)
	root.add_child(_hud)
	_reward = RewardPanel.new()
	_reward.z_index = 20
	root.add_child(_reward)
	_reward.mouse_filter = Control.MOUSE_FILTER_STOP
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
	if _dying:
		return
	var rows := _rows()
	var fight := _joined(rows)
	var mine := not fight.is_empty()
	_hold(mine)
	var toon := _toon()
	if toon != null:
		toon.call("unpin_remotes")
	for item in rows:
		if item is Dictionary:
			_place_bodies(item, delta)
			if String((item as Dictionary).get("state", "")) == "reward":
				_apply_my_reward(item)
	_release_idle(rows)
	if not mine:
		_stop_win()
		_watch(rows, delta)
		return
	_fight = fight
	_aim_camera(fight)
	var battle_state := String(fight.get("state", ""))
	# A cog-building floor uses the indoor battle themes. The outdoor
	# encounter song, and putting the street song back, belong on the street.
	if int(fight.get("building", 0)) == 0:
		_start_music()
	if battle_state == "reward":
		_hide_gag_gui()
		_banner.text = ""
		_start_win()
		_play(fight, delta)
		return
	_stop_win()
	if battle_state == "faceoff" or battle_state == "reserves":
		_hide_gag_gui()
		_banner.text = "More Cogs are coming!" if battle_state == "reserves" else ""
		return
	# TownBattle and the which-toon / which-cog panel exist only while a gag
	# is being chosen. The movie, the reward, and a joined round leave them down.
	if battle_state != "input":
		_hide_gag_gui()
	else:
		_show_hud(fight, delta)
	_spend(fight)
	# Close the inventory before the movie starts. The timer runs out while
	# choose() is still waiting, and cancelling that wait in the same call
	# as the new movie keeps the cog attack from playing.
	_choose(fight, true)
	_play(fight, delta)
	if String(fight.get("state", "")) == "movie":
		_aim_camera(fight)


func _rows() -> Array:
	var boss := get_parent().get_node_or_null("DeptBoss")
	if boss != null:
		var key := String(boss.call("fight_key"))
		if key != "":
			return ToonNet.latest("fights:" + key).get("rows", [])
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


## A bystander keeps the follow camera and never gets the gag menu. The
## face-off, the movies, and the victory dance still play in the world.
func _watch(rows: Array, delta: float) -> void:
	_hide_gag_gui()
	_stop_music()
	var watching := _watchable(rows)
	var watching_id := int(watching.get("id", -1))
	var current_id := int(_fight.get("id", -2))
	if watching.is_empty():
		if _movie_seq != -1 or not _fight.is_empty():
			_end_victory()
			_show_gen += 1
			_clear_movie()
			_banner.text = ""
	else:
		if watching_id != current_id:
			_show_gen += 1
			_clear_movie()
		_fight = watching
		if String(watching.get("state", "")) != "movie":
			_banner.text = ""
		_play(watching, delta)
	_scan += delta
	if _scan < 0.35:
		return
	_scan = 0.0
	var opening := _joinable(rows)
	if opening.is_empty():
		_try_start()
	else:
		_try_join(opening, false)


func _watchable(rows: Array) -> Dictionary:
	var here := _point()
	var best: Dictionary = {}
	var best_dist := WATCH_REACH
	for item in rows:
		if not (item is Dictionary):
			continue
		var fight: Dictionary = item
		var state := String(fight.get("state", ""))
		if state != "faceoff" and state != "input" and state != "movie" and state != "reward":
			continue
		var origin := _vec(fight.get("origin", []))
		var dist := Vector2(origin.x - here.x, origin.z - here.z).length()
		if dist <= best_dist:
			best = fight
			best_dist = dist
	return best


func _joinable(rows: Array) -> Dictionary:
	var here := _point()
	var best: Dictionary = {}
	var best_dist := JOIN_REACH
	for item in rows:
		if not (item is Dictionary):
			continue
		var fight: Dictionary = item
		var opening_state := String(fight.get("state", ""))
		if opening_state != "faceoff" and opening_state != "input":
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
	_touch_cog(cog, hp)


func _touch_cog(cog: Node, hp: Vector2i) -> void:
	var toon := _toon()
	if toon == null:
		return
	var cog_id := int(cog.get_meta("do_id", 0))
	var toon_name := str(toon.call("battle_name"))
	if _street_slug() == "sellbot_factory" and cog is Node3D:
		var body := cog as Node3D
		var here := _point()
		ToonNet.ask_factory(_street_district(), cog_id, body.global_position, _yaw(here, body.global_position), toon_name, hp.x, hp.y)
		return
	if _street_slug() == "cashbot_mint" and cog is Node3D:
		var mint_body := cog as Node3D
		var mint_here := _point()
		ToonNet.ask_mint(_street_district(), cog_id, mint_body.global_position, _yaw(mint_here, mint_body.global_position), toon_name, hp.x, hp.y)
		return
	if _street_slug() == "lawbot_office" and cog is Node3D:
		var office_body := cog as Node3D
		var office_here := _point()
		ToonNet.ask_office(_street_district(), cog_id, office_body.global_position, _yaw(office_here, office_body.global_position), toon_name, hp.x, hp.y)
		return
	if _street_slug() == "bossbot_course" and cog is Node3D:
		var course_body := cog as Node3D
		var course_here := _point()
		ToonNet.ask_course(_street_district(), cog_id, course_body.global_position, _yaw(course_here, course_body.global_position), toon_name, hp.x, hp.y)
		return
	if _street_slug() == "bossbot_course" and cog is Node3D:
		var course_body := cog as Node3D
		var course_here := _point()
		ToonNet.ask_course(_street_district(), cog_id, course_body.global_position, _yaw(course_here, course_body.global_position), toon_name, hp.x, hp.y)
		return
	ToonNet.ask_fight(_street_district(), _street_slug(), cog_id, toon_name, hp.x, hp.y)


func _try_join(fight: Dictionary, mine: bool) -> void:
	var join_state := String(fight.get("state", ""))
	if mine or _ask_wait > 0.0 or _busy() or (join_state != "faceoff" and join_state != "input"):
		return
	var origin := _vec(fight.get("origin", []))
	var here := _point()
	if absf(origin.y - here.y) > 8.0:
		return
	if _on_sidewalk(here, origin.y):
		return
	if Vector2(origin.x - here.x, origin.z - here.z).length() > JOIN_REACH:
		return
	var toon := _toon()
	if toon == null:
		return
	var hp: Vector2i = toon.call("battle_hp")
	_ask_wait = 1.2
	if _street_slug() == "sellbot_factory":
		ToonNet.ask_factory(_street_district(), _first_cog(fight), origin, 0.0, str(toon.call("battle_name")), hp.x, hp.y)
		return
	if _street_slug() == "cashbot_mint":
		ToonNet.ask_mint(_street_district(), _first_cog(fight), origin, 0.0, str(toon.call("battle_name")), hp.x, hp.y)
		return
	if _street_slug() == "lawbot_office":
		ToonNet.ask_office(_street_district(), _first_cog(fight), origin, 0.0, str(toon.call("battle_name")), hp.x, hp.y)
		return
	if _street_slug() == "bossbot_course":
		ToonNet.ask_course(_street_district(), _first_cog(fight), origin, 0.0, str(toon.call("battle_name")), hp.x, hp.y)
		return
	if _street_slug() == "bossbot_course":
		ToonNet.ask_course(_street_district(), _first_cog(fight), origin, 0.0, str(toon.call("battle_name")), hp.x, hp.y)
		return
	ToonNet.ask_fight(_street_district(), _street_slug(), _first_cog(fight), str(toon.call("battle_name")), hp.x, hp.y)


func _choose(fight: Dictionary, mine: bool) -> void:
	var state := String(fight.get("state", ""))
	var seq := int(fight.get("seq", 0))
	if not mine or state != "input" or _sent_seq == seq:
		if _asking and _ask_seq != seq:
			_menu.cancel()
		if state != "input":
			_need_target = false
			_hud.hide_choose()
			if _menu != null:
				_menu.tuck()
		return
	var toon := _toon()
	if toon == null:
		return
	var loadout: ToonLoadout = toon.call("battle_loadout")
	if loadout == null or loadout.hp <= 0:
		return
	if _need_target and _ask_seq == seq:
		_show_targets(fight)
		return
	if _asking:
		return
	_asking = true
	_ask_seq = seq
	var building := int(fight.get("building", 0)) != 0
	var credit := _HOLIDAYS.gag_credit(int(fight.get("district", 0)), building, int(fight.get("floor", 0)))
	_menu.setup(loadout, false, building, credit)
	_ask(fight, seq, loadout)


@warning_ignore("unused_parameter")
func _ask(fight: Dictionary, seq: int, loadout: ToonLoadout) -> void:
	var pick := await _menu.choose()
	_asking = false
	if not is_inside_tree():
		return
	if pick.x == -3 or int(_fight.get("seq", -1)) != seq:
		return
	if pick.x == -4 or pick.x == -5:
		var grouped := pick.x == -4 and (pick.y >= 70 or int(pick.y / 10) == 0 or int(pick.y / 10) == 3)
		if grouped:
			_send(pick.x, pick.y, -1, 0)
		else:
			_pending = pick
			_need_target = true
			_show_targets(_fight)
		return
	if pick.x < 0:
		_send(pick.x, -1, -1, 0)
		return
	if ToonLoadout.affects_group(pick.x, pick.y):
		_send(pick.x, pick.y, -1, loadout.experience_of(pick.x))
		return
	_pending = pick
	_need_target = true
	_show_targets(_fight)


func _show_targets(fight: Dictionary) -> void:
	var track := _pending.x
	var toons := track == ToonLoadout.TOON_UP
	# TownBattle.__isCogChoiceNecessary. One cog is the target. The panel is for a choice.
	if not toons:
		var only := _only_cog(fight)
		if only >= 0:
			var loadout := _loadout()
			@warning_ignore("shadowed_global_identifier")
			var exp := 0 if loadout == null else loadout.experience_of(track)
			_send(track, _pending.y, only, exp)
			return
	var rows: Array = fight.get("toons", []) if toons else fight.get("cogs", [])
	var invalid := PackedInt32Array()
	var skip := -1
	for index in rows.size():
		if not (rows[index] is Dictionary):
			invalid.append(index)
			continue
		var body: Dictionary = rows[index]
		if int(body.get("hp", 0)) <= 0:
			invalid.append(index)
		elif not toons and _blocked_cog(body, track):
			invalid.append(index)
		elif toons and int(body.get("id", 0)) == ToonNet.peer_id():
			skip = index
	_hud.show_choose(toons, rows.size(), invalid, skip)


## The living cog, when the battle has exactly one. -1 means there is a choice.
func _only_cog(fight: Dictionary) -> int:
	var found := -1
	var count := 0
	for item in fight.get("cogs", []):
		if not (item is Dictionary):
			continue
		var cog: Dictionary = item
		if int(cog.get("hp", 0)) <= 0:
			continue
		count += 1
		found = int(cog.get("id", 0))
	if count == 1:
		return found
	return -1


## A trap cannot be laid on a cog that is lured or already trapped. Lure can be used again.
func _blocked_cog(cog: Dictionary, track: int) -> bool:
	var lured := bool(cog.get("lured", false))
	var trapped := cog.get("trap", {}) is Dictionary and not (cog.get("trap", {}) as Dictionary).is_empty()
	# A second lure extends the timer. A trap cannot be laid on a lured or trapped cog.
	if track == 1 and (lured or trapped):
		return true
	return false


func _on_target(slot: int) -> void:
	var toons := _pending.x == ToonLoadout.TOON_UP
	var rows: Array = _fight.get("toons", []) if toons else _fight.get("cogs", [])
	if slot < 0 or slot >= rows.size() or not (rows[slot] is Dictionary):
		return
	var loadout := _loadout()
	@warning_ignore("shadowed_global_identifier")
	var exp := 0 if loadout == null else loadout.experience_of(_pending.x)
	_send(_pending.x, _pending.y, int((rows[slot] as Dictionary).get("id", 0)), exp)


func _on_back() -> void:
	_need_target = false
	_pending = Vector2i(-1, -1)
	_hud.hide_choose()
	_asking = false


func _loadout() -> ToonLoadout:
	var toon := _toon()
	if toon == null:
		return null
	return toon.call("battle_loadout")


@warning_ignore("shadowed_global_identifier")
func _send(track: int, level: int, target: int, exp: int) -> void:
	_need_target = false
	_hud.hide_choose()
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
	if track == -4:
		_REWARDS.consume_encoded(level)
		if int(level / 10) == 7:
			var healed := _toon()
			if healed != null:
				var pockets: ToonLoadout = healed.call("battle_loadout")
				_REWARDS.restock_all(pockets)
		return
	if track == -5:
		_REWARDS.consume_pink()
		return
	if track < 0:
		return
	var toon := _toon()
	if toon == null:
		return
	var loadout: ToonLoadout = toon.call("battle_loadout")
	if loadout != null and loadout.spend_gag(track, level):
		loadout.save()


func _movie_playing() -> bool:
	var movie := _gags as GagMovie
	return movie != null and movie.has_aim()


func _play(fight: Dictionary, _delta: float) -> void:
	var state := String(fight.get("state", ""))
	var seq := int(fight.get("seq", 0))
	if state != "movie":
		var movie := _gags as GagMovie
		if movie != null:
			movie.end_aim()
		if _movie_seq != -1:
			_show_gen += 1
			_movie_seq = -1
		if state != "reward":
			_banner.text = ""
			_pose_local("", 0.0)
		if state == "input":
			_remember(fight, false)
	if state == "reward":
		_banner.text = ""
		if _reward_seq != seq:
			_reward_seq = seq
			_dance = 0.0
			if _mine(fight) and not bool(fight.get("floor_clear", false)):
				_reward_token += 1
				_show_reward(fight, _reward_token)
		_dance += _delta
		_pose_roster(fight, "victory", _dance)
		return
	if state != "movie" or _movie_seq == seq:
		return
	_movie_seq = seq
	_remember(fight, true)
	_show_gen += 1
	_show_movie(fight, _show_gen)


func _show_movie(fight: Dictionary, token: int) -> void:
	_banner.text = ""
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
	var victims: Array = beat.get("victims", [])
	if victims.is_empty():
		_apply_one(beat)
		return
	for item in victims:
		if not (item is Dictionary):
			continue
		var victim: Dictionary = item
		var row := {
			"kind": "cog",
			"cog": int(beat.get("cog", 0)),
			"toon": int(victim.get("id", 0)),
			"toon_id": int(victim.get("id", 0)),
			"hit": bool(victim.get("hit", false)),
			"damage": int(victim.get("damage", 0)),
			"died": bool(victim.get("died", false)),
			"skill": victim.get("skill", []),
		}
		if bool(victim.get("hit", false)):
			row["toon_hp"] = int(victim.get("hp", 0))
		_apply_one(row)


func _apply_one(beat: Dictionary) -> void:
	var cog_id := int(beat.get("cog", 0))
	if beat.has("cog_hp") and int(beat.get("cog_hp", -1)) >= 0 and cog_id != 0:
		_shown["c:%d" % cog_id] = int(beat.get("cog_hp", 0))
	var toon_id := int(beat.get("toon", 0))
	if beat.has("toon_hp"):
		_shown["t:%d" % int(beat.get("toon_id", toon_id))] = int(beat.get("toon_hp", 0))
		toon_id = int(beat.get("toon_id", toon_id))
	_push_laff(toon_id)
	_show_number(beat)
	if bool(beat.get("hit", false)) and int(beat.get("toon_hp", 1)) <= 0:
		_begin_sad(toon_id, beat)


## Suit.showHpText and Toon.showHpText. A hit prints the signed number in red or
## green. A miss prints MISSED. The card starts at half the body height, rises
## for a second, holds, then fades.
func _show_number(beat: Dictionary) -> void:
	var kind := String(beat.get("kind", "gag"))
	var track := int(beat.get("track", -1))
	var hit := bool(beat.get("hit", false))
	var damage := int(beat.get("damage", 0))
	var heal := kind != "cog" and track == ToonLoadout.TOON_UP
	var host: Node3D = null
	if kind == "cog" or heal:
		var shown: Variant = _actor_for(int(beat.get("toon_id", beat.get("toon", 0))))
		if is_instance_valid(shown) and shown is Node3D:
			host = shown
	else:
		var cog: Variant = _cog_node(int(beat.get("cog", 0)))
		if is_instance_valid(cog) and cog is Node3D:
			host = cog
	if host == null:
		return
	var text := ""
	var color := Color(0.9, 0.0, 0.0, 1.0)
	if not hit:
		text = "MISSED"
		color = Color(1.0, 0.0, 0.0, 1.0)
	elif heal and damage > 0:
		text = "+%d" % damage
		color = Color(0.0, 0.9, 0.0, 1.0)
	elif damage > 0:
		text = "-%d" % damage
	else:
		return
	if host.has_meta("hp_text"):
		var previous: Variant = host.get_meta("hp_text")
		if is_instance_valid(previous) and previous is Node:
			(previous as Node).queue_free()
		host.remove_meta("hp_text")
	var height := _body_height(host)
	var label := Label3D.new()
	label.text = text
	label.font = ToonGui.sign_font()
	label.font_size = 64
	label.pixel_size = 0.015
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.modulate = color
	label.outline_size = 0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector3(0.0, height * 0.5, 0.0)
	host.add_child(label)
	host.set_meta("hp_text", label)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", height + 1.5, 1.0)
	tween.tween_interval(0.85)
	tween.tween_property(label, "modulate:a", 0.0, 0.1)
	tween.tween_callback(_drop_number.bind(host, label))


func _drop_number(host: Node, label: Node) -> void:
	if is_instance_valid(host) and is_instance_valid(label) and host.get_meta("hp_text", null) == label:
		host.remove_meta("hp_text")
	if is_instance_valid(label):
		label.queue_free()


func _body_height(host: Node3D) -> float:
	var low := INF
	var high := -INF
	for node in host.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var box := mesh.global_transform * mesh.get_aabb()
		low = minf(low, box.position.y)
		high = maxf(high, box.position.y + box.size.y)
	if high <= low:
		return 4.0
	return clampf(high - host.global_position.y, 2.5, 9.0)


func _credit(fight: Dictionary, beat: Dictionary) -> void:
	var fight_id := int(fight.get("id", 0))
	if _credited_fight != fight_id:
		_credited_fight = fight_id
		_credited.clear()
	if not _mine(fight) or String(beat.get("kind", "")) != "gag":
		return
	if int(beat.get("cog_hp", 1)) > 0:
		return
	var cog_id := int(beat.get("cog", 0))
	if _credited.has(cog_id):
		return
	_credited[cog_id] = true
	var code := ""
	var dept := ""
	var level := -1
	var skeleton := false
	var revives := 0
	for item in fight.get("cogs", []):
		if item is Dictionary and int((item as Dictionary).get("id", 0)) == cog_id:
			code = String((item as Dictionary).get("code", ""))
			dept = String((item as Dictionary).get("dept", ""))
			level = int((item as Dictionary).get("level", -1))
			skeleton = bool((item as Dictionary).get("skeleton", false))
			revives = int((item as Dictionary).get("revives", 0))
			break
	var tasks := ToonTasks.for_selected()
	if tasks != null:
		tasks.note_cog_defeat(code, _battle_hood(), dept, level, skeleton, revives)


## DistributedToon.died starts Toon.getDiedInterval at the hit. Every client
## plays it. Only the toon who fell over leaves for the playground.
func _begin_sad(peer: int, beat: Dictionary) -> void:
	if _sad_started.has(peer):
		return
	_sad_started[peer] = true
	var local := peer == ToonNet.peer_id()
	if local:
		_dying = true
		_grant_sad_skill(beat)
		var loadout := _loadout()
		if loadout != null:
			loadout.zero_gags()
			loadout.set_hp(0, loadout.max_hp)
			loadout.save()
		_hud.hide_all()
		_banner.text = ""
	var actor := _actor_for(peer)
	if actor == null:
		if local:
			_leave_sad()
		return
	actor.set_expression("sad")
	actor.set_look_enabled(false)
	var base_scale := actor.scale
	var elapsed := 0.0
	var sounded := false
	while elapsed < _LOSE_END:
		if not is_inside_tree():
			return
		if not is_instance_valid(actor):
			break
		actor.pose_action("lose", elapsed)
		if elapsed >= 2.0 and not sounded:
			sounded = true
			_play_lose()
		if elapsed >= _LOSE_SHRINK:
			var shrunk := clampf((elapsed - _LOSE_SHRINK) / 1.5, 0.0, 1.0)
			actor.scale = base_scale * lerpf(1.0, 0.01, shrunk)
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if not is_inside_tree():
		return
	if local:
		_leave_sad()
		return
	if is_instance_valid(actor):
		actor.set_meta("gone_sad", true)
		actor.visible = false


func _grant_sad_skill(beat: Dictionary) -> void:
	var fight_id := int(_fight.get("id", 0))
	if sad_fight == fight_id and fight_id != 0:
		return
	var loadout := _loadout()
	if loadout == null:
		return
	var gained: Variant = beat.get("skill", [])
	if not (gained is Array) or (gained as Array).is_empty():
		return
	var skill: Array = gained
	for track in mini(skill.size(), ToonLoadout.TRACK_COUNT):
		loadout.add_experience(track, int(skill[track]))
	sad_fight = fight_id


func _ride_factory() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var ride := scene.get_node_or_null("FactoryElevators")
	if ride != null and ride.has_method("win_leave"):
		ride.call("win_leave")


func _ride_mint() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var ride := scene.get_node_or_null("MintElevators")
	if ride != null and ride.has_method("win_leave"):
		ride.call("win_leave")


func _leave_sad() -> void:
	var tasks := ToonTasks.for_selected()
	var hood := 0 if tasks == null else tasks.return_hood()
	if hood == 0:
		hood = _PLACES.TTC
	_ARRIVAL.went_sad = true
	_ARRIVAL.teleport_in = true
	_ARRIVAL.portal_in = true
	ToonLoading.change_to(_PLACES.scene_for(hood))


func _start_win() -> void:
	if _win != null:
		return
	var stream := load(_WIN) as AudioStreamMP3
	if stream == null:
		return
	stream = stream.duplicate() as AudioStreamMP3
	stream.loop = true
	_win = ToonAudio.effect_player()
	_win.name = "WinDance"
	_win.stream = stream
	add_child(_win)
	_win.play()


func _stop_win() -> void:
	if _win == null:
		return
	_win.stop()
	_win.queue_free()
	_win = null


func _play_lose() -> void:
	var stream := load(_LOSE)
	if not (stream is AudioStream):
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	var tree := get_tree()
	if tree == null:
		return
	tree.root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

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
	if loadout.hp <= 0:
		return
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
	if not _has_toon(_fight, ToonNet.peer_id()):
		return
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


func _place_bodies(fight: Dictionary, delta: float) -> void:
	var state := String(fight.get("state", ""))
	var faceoff := state == "faceoff"
	if faceoff:
		_age_faceoff(fight, delta)
	var toon := _toon()
	var cog_center := _center(fight.get("cogs", []))
	var toon_center := _center(fight.get("toons", []))
	if toon == null:
		toon_center = cog_center
	elif faceoff:
		_walk_toons(fight, toon, delta)
	else:
		for member in fight.get("toons", []):
			var row: Dictionary = member
			var spot := _vec(row.get("slot", []))
			var facing := _line_heading(row, spot, cog_center)
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
		if faceoff:
			_walk_cog(fight, suit, cog, toon_center)
		elif state == "reserves" and _is_joining(fight, int(suit.get("id", 0))):
			var door := _vec(suit.get("from", suit.get("slot", [])))
			var door_face := float(suit["from_h"]) if suit.has("from_h") else _yaw(door, toon_center)
			cog.call("hold_fight", true, door, deg_to_rad(door_face))
			if cog.has_method("march"):
				cog.call("march", false)
		else:
			cog.call("hold_fight", true, stand, deg_to_rad(_line_heading(suit, stand, toon_center)))
			if state != "movie" and not _movie_playing():
				if cog.has_method("march"):
					cog.call("march", false)
				if cog.has_method("begin_react"):
					cog.call("begin_react", "", 0.0)
			_clear_taunt(cog, fight)
		_show_cog_health(suit, cog)


func _show_cog_health(suit: Dictionary, cog: Node) -> void:
	if not cog.has_method("set_battle_hp"):
		return
	var cog_id := int(suit.get("id", 0))
	var hp := int(_shown.get("c:%d" % cog_id, suit.get("hp", 1)))
	cog.call("set_battle_hp", hp, int(suit.get("max_hp", hp)))


func _age_faceoff(fight: Dictionary, delta: float) -> void:
	var total := float(fight.get("taunt_for", 3.5)) + float(fight.get("walk", 0.1))
	var posted := float(fight.get("left", total))
	var key := "%s:%s" % [int(fight.get("id", 0)), int(fight.get("seq", 0))]
	if key != _face_key:
		_face_key = key
		_face_left = posted
		_face_age = 0.0
		_face_from.clear()
	elif absf(posted - (_face_left - _face_age)) > 0.75:
		_face_left = posted
		_face_age = 0.0
	else:
		_face_age += delta
	var remain := maxf(_face_left - _face_age, 0.0)
	_face_elapsed = clampf(total - remain, 0.0, total)


func _walk_toons(fight: Dictionary, toon: Node, delta: float) -> void:
	var taunt_for := float(fight.get("taunt_for", 3.5))
	var walk := maxf(float(fight.get("walk", 0.1)), 0.1)
	var along := 0.0
	if _face_elapsed > taunt_for:
		along = clampf((_face_elapsed - taunt_for) / walk, 0.0, 1.0)
	var lead := _cog_node(int(fight.get("taunt_cog", _lead_cog(fight))))
	var focus := _center(fight.get("cogs", []))
	if lead is Node3D:
		focus = (lead as Node3D).global_position
	for member in fight.get("toons", []):
		if not (member is Dictionary):
			continue
		var row: Dictionary = member
		var peer := int(row.get("id", 0))
		var slot := _vec(row.get("slot", []))
		var key := "t:%d" % peer
		var current := _toon_here(toon, peer, slot)
		if not _face_from.has(key):
			_face_from[key] = _join_from(current, slot, along)
		var start: Vector3 = _face_from[key]
		var spot := start.lerp(slot, along)
		var facing := _yaw(spot, focus) if along <= 0.001 else _yaw(start, slot)
		var actor: ToonActor = null
		if peer == ToonNet.peer_id():
			toon.call("place_for_battle", spot, facing)
			actor = toon.call("battle_actor")
		else:
			toon.call("pin_remote", peer, spot, facing)
			actor = toon.call("remote_actor", peer)
		if actor == null:
			continue
		if along > 0.001 and along < 1.0:
			actor.set_locomotion(9.0, false, false, delta)
		else:
			actor.set_locomotion(0.0, false, false, delta)


func _toon_here(toon: Node, peer: int, fallback: Vector3) -> Vector3:
	if peer == ToonNet.peer_id():
		return _point()
	var actor: ToonActor = toon.call("remote_actor", peer)
	if actor == null:
		return fallback
	return actor.global_position


func _join_from(current: Vector3, slot: Vector3, along: float) -> Vector3:
	if along <= 0.001 or along >= 0.999:
		return current
	return (current - slot * along) / (1.0 - along)


func _is_joining(fight: Dictionary, cog_id: int) -> bool:
	var joining: Variant = fight.get("joining", [])
	if joining is Array:
		return (joining as Array).has(cog_id)
	return false


func _walk_cog(fight: Dictionary, suit: Dictionary, cog: Node, toon_center: Vector3) -> void:
	var taunt_for := float(fight.get("taunt_for", 3.5))
	var start := _vec(suit.get("from", suit.get("slot", [])))
	var slot := _vec(suit.get("slot", []))
	# One shared face-off clock would make a short walk creep. Each suit
	# moves at suitSpeed, and the longest one is what ends the face-off.
	var travel := Vector2(slot.x - start.x, slot.z - start.z).length()
	var walk := travel / SUIT_SPEED
	var along := 0.0
	if _face_elapsed > taunt_for:
		along = 1.0 if walk < 0.05 else clampf((_face_elapsed - taunt_for) / walk, 0.0, 1.0)
	var spot := start.lerp(slot, along)
	var facing := _yaw(start, slot)
	if along <= 0.001:
		facing = float(suit["from_h"]) if suit.has("from_h") else _yaw(spot, toon_center)
	elif along >= 0.999:
		facing = _line_heading(suit, slot, toon_center)
	cog.call("hold_fight", true, spot, deg_to_rad(facing))
	var walking := along > 0.001 and along < 1.0
	if cog.has_method("march"):
		cog.call("march", walking)
	if int(suit.get("id", 0)) == int(fight.get("taunt_cog", 0)) and _face_elapsed < taunt_for:
		_show_taunt(fight, cog, taunt_for - _face_elapsed)
	else:
		_clear_taunt(cog, fight)


func _show_taunt(fight: Dictionary, cog: Node, remain: float) -> void:
	var text := String(fight.get("taunt", ""))
	if text == "":
		return
	var token := "%s:%s" % [int(fight.get("id", 0)), int(fight.get("seq", 0))]
	if _face_spoke != token:
		_face_spoke = token
		ToonSpeech.cog(text)
		cog.set_meta("chat_line", text)
		cog.set_meta("chat_until", Time.get_ticks_msec() + int(maxf(remain, 0.2) * 1000.0))
		cog.set_meta("faceoff_chat", int(fight.get("id", 0)))


func _clear_taunt(cog: Node, fight: Dictionary) -> void:
	if int(cog.get_meta("faceoff_chat", -1)) != int(fight.get("id", 0)):
		return
	cog.set_meta("chat_line", "")
	cog.set_meta("chat_until", 0)
	cog.set_meta("faceoff_chat", -1)


func _hide_gag_gui() -> void:
	if _hud != null:
		_hud.hide_all()
	if _menu == null:
		return
	if _asking:
		_menu.cancel()
		_asking = false
		return
	_menu.tuck()


func _show_hud(fight: Dictionary, delta: float) -> void:
	if _pending.x >= 0 and int(fight.get("seq", -1)) != _ask_seq:
		_pending = Vector2i(-1, -1)
	var cards: Array = []
	for item in fight.get("toons", []):
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		var card := row.duplicate()
		var hp := int(_shown.get("t:%d" % int(row.get("id", 0)), row.get("hp", 0)))
		card["hp"] = hp
		var choice := _choice_for(int(row.get("id", 0)))
		var pending := int(row.get("id", 0)) == ToonNet.peer_id() and _pending.x >= 0 and choice.is_empty()
		if pending:
			choice = {"track": _pending.x, "level": _pending.y, "target": -1}
		if String(fight.get("state", "")) != "join" and not choice.is_empty():
			var track := int(choice.get("track", -1))
			var level := int(choice.get("level", -1))
			card["track"] = track
			card["level"] = level
			if not pending:
				card["which"] = _which_marks(track, level, int(choice.get("target", -1)), int(row.get("id", 0)))
		cards.append(card)
	_hud.show_battle(cards, String(fight.get("state", "")), _seconds(fight, delta))


## TownBattleToonPanel.determineWhichText. The first mark is the leftmost body.
@warning_ignore("shadowed_variable_base_class")
func _which_marks(track: int, level: int, target: int, owner: int) -> String:
	if track < 0:
		return ""
	var rows: Array = fight_rows_for(track, level)
	var marks := ""
	for index in range(rows.size() - 1, -1, -1):
		if not (rows[index] is Dictionary):
			marks += "-"
			continue
		var body: Dictionary = rows[index]
		if target == -1:
			marks += "X" if int(body.get("hp", 0)) > 0 else "-"
		elif target == -2:
			marks += "-" if int(body.get("id", 0)) == owner else "X"
		else:
			marks += "X" if int(body.get("id", 0)) == target else "-"
	return marks


func fight_rows_for(track: int, level: int) -> Array:
	if track == ToonLoadout.TOON_UP and not ToonLoadout.affects_group(track, level):
		return _fight.get("toons", [])
	return _fight.get("cogs", [])


func _seconds(fight: Dictionary, delta: float) -> int:
	var state := String(fight.get("state", ""))
	if state != "input":
		return -1
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
	return int(ceil(maxf(_clock_left - _clock_age, 0.0)))


func _show_reward(fight: Dictionary, token: int) -> void:
	var rows: Array = fight.get("reward_rows", [])
	_apply_my_reward(fight)
	var recovered := ""
	var quests: Array = []
	var tasks := ToonTasks.for_selected()
	var leaving := false
	if bool(fight.get("factory_won", false)):
		var win_key := "factory:%s" % fight.get("id", 0)
		if _factory_key != win_key:
			_factory_key = win_key
			leaving = true
			var part_line := DisguisePage.grant_factory(_FACTORY.collect())
			if tasks != null:
				tasks.note_factory(11000)
				tasks.note_foreman(11000)
				if part_line.contains("recovered"):
					tasks.note_part(11000)
			recovered = part_line
	if String(fight.get("slug", "")) == "cashbot_mint":
		var mint_key := "mint:%s" % fight.get("id", 0)
		if _mint_key != mint_key:
			_mint_key = mint_key
			var supervisor := bool(fight.get("mint_won", false))
			if supervisor:
				leaving = true
			var which := int(fight.get("mint", 0))
			if which == 0:
				which = _MINT_RIDE.mint_id
			var buck_line := DisguisePage.grant_mint(_MINT.collect(), which)
			if supervisor and tasks != null:
				tasks.note_mint(which)
				tasks.note_supervisor(which)
			if buck_line != "":
				recovered = buck_line if recovered == "" else "%s\n%s" % [recovered, buck_line]
	if tasks != null:
		var notes := tasks.take_battle_notes()
		if notes != "":
			recovered = notes if recovered == "" else "%s\n%s" % [recovered, notes]
		quests = tasks.take_quest_gains()
	for item in rows:
		if token != _reward_token or not is_inside_tree():
			return
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		var before := _exp_dict(row.get("before", []))
		var earned := _exp_dict(row.get("earned", []))
		var display := _loadout()
		if int(row.get("id", 0)) != ToonNet.peer_id():
			display = _display_loadout(row.get("before", []), row.get("earned", []))
		if display == null:
			continue
		var quest_line := ""
		var mine: Array = []
		if int(row.get("id", 0)) == ToonNet.peer_id():
			quest_line = recovered
			mine = quests
		await _reward.present(String(row.get("name", "Toon")), display, before, earned, quest_line, false, mine)
	if token != _reward_token or not is_inside_tree():
		return
	if not _any_earned(rows, ToonNet.peer_id()):
		await get_tree().create_timer(1.6).timeout
	if token != _reward_token or not is_inside_tree():
		return
	ToonNet.finish_reward(int(fight.get("id", 0)))
	if leaving and bool(fight.get("mint_won", false)):
		_ride_mint()
	elif leaving:
		_ride_factory()


func _apply_my_reward(fight: Dictionary) -> void:
	if int(fight.get("id", 0)) == sad_fight and sad_fight != 0:
		return
	var key := "%s:%s" % [fight.get("id", 0), fight.get("seq", 0)]
	if _paid_key == key:
		return
	var loadout := _loadout()
	if loadout == null:
		return
	var rows: Array = fight.get("reward_rows", [])
	var applied := false
	for item in rows:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		if int(row.get("id", 0)) != ToonNet.peer_id():
			continue
		var earned: Array = row.get("earned", [])
		for track in mini(earned.size(), ToonLoadout.TRACK_COUNT):
			loadout.add_experience(track, int(earned[track]))
		loadout.save()
		applied = true
		break
	if applied:
		_paid_key = key


func _display_loadout(before: Variant, earned: Variant) -> ToonLoadout:
	var prior: Array = before if before is Array else []
	var gained: Array = earned if earned is Array else []
	@warning_ignore("shadowed_global_identifier")
	var exp: Array = []
	for track in ToonLoadout.TRACK_COUNT:
		exp.append(int(prior[track]) if track < prior.size() else 0)
	for track in ToonLoadout.TRACK_COUNT:
		var amount := int(gained[track]) if track < gained.size() else 0
		if amount > 0 and int(exp[track]) <= 0 and track != ToonLoadout.THROW and track != ToonLoadout.SQUIRT:
			exp[track] = 1
	var display := ToonLoadout.new()
	display.apply_dict({"hp": 15, "max_hp": 15, "exp": exp})
	return display


func _exp_dict(value: Variant) -> Dictionary:
	var packed := {}
	var row: Array = value if value is Array else []
	for track in row.size():
		packed[track] = int(row[track])
	return packed


func _any_earned(rows: Array, peer: int) -> bool:
	for item in rows:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		if int(row.get("id", 0)) != peer:
			continue
		for amount in row.get("earned", []):
			if int(amount) > 0:
				return true
	return false


func _end_victory() -> void:
	# pose_action locks locomotion on the last victory frame. The tutorial
	# battle calls end_action when the reward closes. A street battle did not.
	for item in _fight.get("toons", []):
		if not (item is Dictionary):
			continue
		var actor := _actor_for(int((item as Dictionary).get("id", 0)))
		if actor != null:
			actor.end_action("victory")


func _pose_roster(fight: Dictionary, clip: String, elapsed: float) -> void:
	for item in fight.get("toons", []):
		if not (item is Dictionary):
			continue
		var actor := _actor_for(int((item as Dictionary).get("id", 0)))
		if actor == null:
			continue
		var length := actor.action_length(clip)
		var at := elapsed if length <= 0.0 else fposmod(elapsed, length)
		actor.pose_action(clip, at)


func battle_style(peer: int) -> ToonStyle:
	if peer == ToonNet.peer_id():
		var mine := ToonRoster.selected_style()
		return mine if mine != null else ToonStyle.new()
	var actor := _actor_for(peer)
	if actor != null:
		var raw: Variant = actor.get_meta("style", {})
		if raw is Dictionary:
			return ToonStyle.from_dict(raw)
	return ToonStyle.new()

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
	if _dying:
		return
	if active == _in_it:
		if not active:
			_release_remotes()
		return
	_in_it = active
	var toon := _toon()
	if toon != null:
		toon.call("hold_for_battle", active)
	if not active:
		_end_victory()
		_cool = 2.0
		_sent_seq = -1
		_need_target = false
		_hud.hide_all()
		_reward_token += 1
		_stop_win()
		_reward.stop()
		_menu.cancel()
		_show_gen += 1
		if _gags != null:
			_gags.clear_traps()
		_release_cogs()
		_release_remotes()
		_restore_camera()


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
	var movie := _gags as GagMovie
	if movie != null:
		movie.end_aim()


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.y < 1.0:
		return
	ToonGui.place(_banner, view, 0.0, 0.42, 1.6, 0.12)

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


## BattleBlocker.__handleToonEnter. Walking into the cell sphere starts that
## cell's battle. The sphere does not stop the toon.
func touch_cell(cell: int) -> void:
	if _street_slug() != "cashbot_mint":
		return
	if _cool > 0.0 or _ask_wait > 0.0 or _busy():
		return
	var cog := _cell_cog(cell)
	if cog == null:
		return
	var toon := _toon()
	if toon == null:
		return
	var hp: Vector2i = toon.call("battle_hp")
	_ask_wait = 1.2
	_touch_cog(cog, hp)


func _cell_cog(cell: int) -> Node:
	var suits := get_parent().get_node_or_null("StreetSuits")
	if suits == null:
		return null
	for child in suits.get_children():
		if int(child.get_meta("cell", -1)) != cell:
			continue
		if not child.has_method("on_lane") or not bool(child.call("on_lane")):
			continue
		if bool(child.get_meta("office_hidden", false)):
			continue
		if bool(child.get_meta("in_fight", false)):
			continue
		return child
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
		if bool(child.get_meta("office_hidden", false)):
			continue
		if int(child.get_meta("do_id", 0)) == 0:
			continue
		if bool(child.get_meta("in_fight", false)):
			continue
		var cog := child as Node3D
		if cog == null:
			continue
		# A cog-building floor sits far above the street. The toon up there
		# must not start a fight with a suit on the sidewalk below.
		if absf(cog.global_position.y - here.y) > 8.0:
			continue
		if _on_sidewalk(here, cog.global_position.y):
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
	if suits != null:
		for child in suits.get_children():
			if int(child.get_meta("do_id", 0)) == cog_id:
				return child
	var bosses := get_parent().get_node_or_null("BossSuits")
	if bosses != null:
		for child in bosses.get_children():
			if int(child.get_meta("do_id", 0)) == cog_id:
				return child
	var floors := get_parent().get_node_or_null("CogBuilding/FloorSuits")
	if floors == null:
		return null
	for child in floors.get_children():
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


## A building line uses BattleBase headings. A street fight still faces the other side.
func _line_heading(row: Dictionary, spot: Vector3, look_at: Vector3) -> float:
	if row.has("h"):
		return float(row["h"])
	return _yaw(spot, look_at)


func _yaw(from: Vector3, to: Vector3) -> float:
	var flat := to - from
	flat.y = 0.0
	if flat.length_squared() < 0.0001:
		return 0.0
	flat = flat.normalized()
	return rad_to_deg(atan2(-flat.x, -flat.z))


## DistributedBattleBase camera. The battle node faces the cogs. The menu
## view sits behind the toons; the face-off starts on the cog, then drops low.
func _aim_camera(fight: Dictionary) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	if _saved_fov < 0.0:
		_saved_fov = camera.fov
	var basis := _battle_basis(fight)
	var origin: Vector3 = basis["origin"]
	var forward: Vector3 = basis["forward"]
	var right: Vector3 = basis["right"]
	var state := String(fight.get("state", ""))
	if state == "reserves":
		var out := _vec(fight.get("out", []))
		camera.global_position = out + Vector3(0.0, 2.0, 8.0)
		if camera.global_position.distance_squared_to(out) > 0.04:
			camera.look_at(out + Vector3(0.0, 2.0, 0.0), Vector3.UP)
		camera.fov = 52.0
		return
	if state == "movie":
		var movie := _gags as GagMovie
		if movie != null and movie.has_aim():
			movie.aim_camera(camera, basis)
			return
	if state == "reward":
		# Movie.show_reward frames the dancing toon from the side, behind the line.
		var actor := _actor_for(ToonNet.peer_id())
		@warning_ignore("confusable_local_declaration")
		var look := origin + Vector3.UP * 3.0
		if actor != null:
			look = actor.global_position + Vector3.UP * 3.0
		var side_sign := 1.0 if int(fight.get("id", 0)) % 2 == 0 else -1.0
		var reward_pos := look - forward * 10.0 + right * side_sign * 5.0
		camera.fov = 80.0
		camera.global_position = reward_pos
		if camera.global_position.distance_squared_to(look) > 0.25:
			camera.look_at(look, Vector3.UP)
		return
	var fov := 80.0
	var pos := origin - forward * 8.6 + Vector3.UP * 16.5
	var look := origin
	if state == "faceoff":
		var taunt_for := float(fight.get("taunt_for", 3.5))
		var lead := _cog_node(int(fight.get("taunt_cog", _lead_cog(fight))))
		var cog_pos := _center(fight.get("cogs", []))
		if lead is Node3D:
			cog_pos = (lead as Node3D).global_position
		if _face_elapsed < taunt_for:
			fov = 30.0
			var height := _cog_height(int(fight.get("taunt_cog", _lead_cog(fight))))
			var chest := maxf(height * 0.66, height - 1.8)
			var cam_h := chest
			var high := int(fight.get("cam_high", 0))
			if high == 1:
				cam_h = 1.0
			elif high == 2:
				cam_h = 11.0
			var side := float(fight.get("cam_side", 5.0))
			pos = cog_pos - forward * 16.0 + right * side + Vector3.UP * cam_h
			look = cog_pos + Vector3.UP * height
		else:
			fov = 80.0
			pos = origin - forward * 10.0 + Vector3.UP * 4.0
			look = cog_pos
	elif state == "input":
		fov = 65.0
	camera.fov = fov
	camera.global_position = pos
	if camera.global_position.distance_squared_to(look) > 0.25:
		camera.look_at(look, Vector3.UP)


func _restore_camera() -> void:
	if _saved_fov < 0.0:
		return
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		camera.fov = _saved_fov
	_saved_fov = -1.0


func _battle_basis(fight: Dictionary) -> Dictionary:
	var origin := _vec(fight.get("origin", []))
	var yaw := float(fight.get("yaw", 180.0))
	var forward := _battle_forward(yaw)
	if origin == Vector3.ZERO:
		var suits := _center(fight.get("cogs", []))
		var toons := _center(fight.get("toons", []))
		forward = suits - toons
		forward.y = 0.0
		if forward.length_squared() < 0.04:
			forward = Vector3(0.0, 0.0, 1.0)
		else:
			forward = forward.normalized()
		origin = (suits + toons) * 0.5
	var right := Vector3.UP.cross(forward)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	return {"origin": origin, "forward": forward, "right": right}


func _battle_forward(heading: float) -> Vector3:
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	upright = upright.rotated(Vector3.UP, deg_to_rad(heading))
	return upright * Vector3(0, 1, 0)


func _lead_cog(fight: Dictionary) -> int:
	var rows: Array = fight.get("cogs", [])
	if rows.is_empty() or not (rows[0] is Dictionary):
		return 0
	return int((rows[0] as Dictionary).get("id", 0))


func _cog_height(cog_id: int) -> float:
	var cog := _cog_node(cog_id)
	if cog == null:
		return 4.0
	return maxf(float(cog.get("height")), 1.0)


func _vec(value: Variant) -> Vector3:
	if value is Array:
		var row: Array = value
		if row.size() >= 3:
			return Vector3(float(row[0]), float(row[1]), float(row[2]))
	return Vector3.ZERO


## Street curbs rise 0.5. Suit points sit on the road. Feet on the sidewalk
## are that step higher, and a fight does not start from there.
func _on_sidewalk(here: Vector3, street_y: float) -> bool:
	if _street_slug() == "sellbot_factory" or _street_slug() == "cashbot_mint":
		return false
	return here.y > street_y + 0.35


func _point() -> Vector3:
	var toon := _toon()
	if toon == null:
		return Vector3.ZERO
	return toon.call("battle_point")


func _battle_hood() -> int:
	var scene := get_parent()
	if scene == null:
		return 0
	if scene.scene_file_path.get_file() == "cashbot_mint.tscn":
		var which := int(_fight.get("mint", 0))
		if which == 0:
			which = _MINT_RIDE.mint_id
		return which
	return _TITLES.zone_of(scene.scene_file_path)


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
