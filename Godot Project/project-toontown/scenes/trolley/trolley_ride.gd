extends Node3D

## The trolley drops you into one game, then opens Goofy's Gag Shop.
## The district deals from MinigamePlayerMatrix, so a solo ride stays on the one-player list.

const _BEANS := preload("res://scenes/toons/jellybeans.gd")
const _HOLIDAYS := preload("res://scenes/shticker/calendar_holidays.gd")
const _TASKS := preload("res://scenes/quests/toon_tasks.gd")
const _RULES_PANEL := preload("res://assets/gui/rules/minigame-rules-panel.png")
const _PLAY_UP := preload("res://assets/gui/rules/InventoryButtonUp.png")
const _PLAY_DN := preload("res://assets/gui/rules/InventoryButtonDown.png")
const _PLAY_OVER := preload("res://assets/gui/rules/InventoryButtonRollover.png")
const _ZONES: Array[int] = [2000, 1000, 5000, 4000, 3000, 9000]
const _GAMES: Array[Dictionary] = [
	{"id": 2, "script": "res://scenes/trolley/game_cannon.gd", "music": "res://assets/audio/bgm/MG_cannon_game.ogg", "loop": true, "volume": 0.8},
	{"id": 5, "script": "res://scenes/trolley/game_ring.gd", "music": "res://assets/audio/bgm/MG_toontag.ogg", "loop": false, "volume": 0.8},
	{"id": 6, "script": "res://scenes/trolley/game_maze.gd", "music": "res://assets/audio/bgm/MG_toontag.ogg", "loop": false, "volume": 0.8},
	{"id": 7, "script": "res://scenes/trolley/game_tug.gd", "music": "res://assets/audio/bgm/MG_tug_o_war.ogg", "loop": true, "volume": 1.0},
	{"id": 8, "script": "res://scenes/trolley/game_catch.gd", "music": "res://assets/audio/bgm/MG_toontag.ogg", "loop": false, "volume": 0.9},
	{"id": 9, "script": "res://scenes/trolley/game_diving.gd", "music": "res://assets/audio/bgm/MG_Target.ogg", "loop": true, "volume": 0.9},
	{"id": 10, "script": "res://scenes/trolley/game_target.gd", "music": "res://assets/audio/bgm/MG_Diving.ogg", "loop": true, "volume": 0.8},
	{"id": 11, "script": "res://scenes/trolley/game_pairing.gd", "music": "res://assets/audio/bgm/MG_Pairing.ogg", "loop": true, "volume": 0.9},
	{"id": 12, "script": "res://scenes/trolley/game_vine.gd", "music": "res://assets/audio/bgm/MG_Vine.ogg", "loop": true, "volume": 0.9},
	{"id": 14, "script": "res://scenes/trolley/game_thief.gd", "music": "res://assets/audio/bgm/MG_CogThief.ogg", "loop": true, "volume": 0.8},
	{"id": 15, "script": "res://scenes/trolley/game_escape.gd", "music": "res://assets/audio/bgm/MG_TwoDGame.ogg", "loop": true, "volume": 0.9},
	{"id": 1, "script": "res://scenes/trolley/game_race.gd", "music": "res://assets/audio/bgm/minigame_race.ogg", "loop": true, "volume": 0.85},
	{"id": 3, "script": "res://scenes/trolley/game_tag.gd", "music": "res://assets/audio/bgm/MG_toontag.ogg", "loop": true, "volume": 0.85},
	{"id": 4, "script": "res://scenes/trolley/game_pattern.gd", "music": "res://assets/audio/bgm/m_match_bg1.ogg", "loop": true, "volume": 0.85},
	{"id": 13, "script": "res://scenes/trolley/game_ice.gd", "music": "res://assets/audio/bgm/MG_IceGame.ogg", "loop": true, "volume": 0.85},
]

static var hood := 2000
static var return_scene := ""
static var previous_id := 0
static var players := 1
static var seat := 0
## Seat order from the ride that just left. Each card is peer, name, style, accessories.
static var riders: Array = []

var _game: Node
var _rules: Control
var _rules_panel: TextureRect
var _rules_title: Label
var _rules_body: Label
var _rules_copy := ""
var _rules_play: TextureButton
var _rules_skip: TextureButton
var _shop: Node
var _clock: Label
var _rules_left := 16.0
var _choice: Dictionary = {}
var _asked_skip := false
var _asked_ready := false
var _did_skip := false
var _chat: SpeedChat


func _ready() -> void:
	_add_chat()
	_choice = _pick()
	if _choice.is_empty():
		var net := ToonNet.live()
		if net != null and not net.state_changed.is_connected(_on_net_game):
			net.state_changed.connect(_on_net_game)
		return
	_arm()


func _add_chat() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 70
	add_child(layer)
	_chat = SpeedChat.new()
	_chat.name = "SpeedChat"
	layer.add_child(_chat)
	_chat.setup(_TASKS.for_selected())
	if not _chat.phrase_said.is_connected(_on_phrase):
		_chat.phrase_said.connect(_on_phrase)


func _on_phrase(text: String) -> void:
	var actor := _speaker()
	if actor == null:
		return
	var kind := "speed"
	if _chat != null and not _chat.phrase_is_speedchat:
		kind = "plus"
	actor.set_meta("chat_line", text)
	actor.set_meta("chat_kind", kind)
	actor.set_meta("chat_until", Time.get_ticks_msec() + maxi(2800, text.length() * 45))
	ToonSpeech.speak(actor, text)


func _speaker() -> Node3D:
	if _shop != null and is_instance_valid(_shop) and _shop.has_method("speaker"):
		var shown: Variant = _shop.call("speaker")
		if shown is Node3D:
			return shown as Node3D
	if _game != null and is_instance_valid(_game):
		var rider: Variant = _game.get("_toon")
		if rider is Node3D:
			return rider as Node3D
	return null


func _on_net_game(channel: String) -> void:
	if _rules != null or not channel.begins_with("trolley:"):
		return
	_choice = _pick()
	if _choice.is_empty():
		return
	_arm()


func _arm() -> void:
	previous_id = int(_choice["id"])
	var posted := ToonNet.latest("trolley:%d" % ToonNet.district_id())
	if int(posted.get("by", -1)) == ToonNet.self_peer():
		MagicWords.note_played(previous_id)
	_play_song()
	_show_rules()


func _process(delta: float) -> void:
	if _rules == null:
		return
	var state := ToonNet.latest("trolley:%d" % ToonNet.district_id())
	if bool(state.get("skipped", false)):
		_apply_skip()
		return
	var until := int(state.get("rules_until", 0))
	if until > 0:
		_rules_left = maxf((float(until) - Time.get_unix_time_from_system() * 1000.0) / 1000.0, 0.0)
	else:
		_rules_left -= delta
	_paint_skip(state)
	if _clock != null:
		var whole := maxi(int(ceil(_rules_left)), 0)
		if _clock.text != str(whole):
			_clock.text = str(whole)
			# The alarm clock turns red for the last five seconds.
			var late := whole <= 5
			ToonGui.style_label(_clock, Color(1, 0, 0) if late else Color(0, 0, 0), _rules_px(0.108 if not late else 0.136), Color(0, 0, 0, 0), 0)
	if _rules_left <= 0.0:
		_start()


func _input(event: InputEvent) -> void:
	if _rules == null or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode != KEY_ENTER and key.keycode != KEY_KP_ENTER and key.physical_keycode != KEY_ENTER:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if _chat != null and _chat.is_open():
		return
	get_viewport().set_input_as_handled()
	_ask_ready()


func _pick() -> Dictionary:
	# DistributedMinigame on the district AI picks the game. This ride plays it.
	var wanted := ToonNet.begin_trolley(previous_id)
	if wanted == 0:
		return {}
	for entry in _GAMES:
		if int(entry["id"]) == wanted:
			return entry
	return {}


func _show_rules() -> void:
	_rules_left = 16.0
	_asked_skip = false
	_asked_ready = false
	_did_skip = false
	var script := load(String(_choice["script"])) as GDScript
	_game = script.new()
	add_child(_game)
	_game.finished.connect(_reward)
	_rules = Control.new()
	_rules.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rules.mouse_filter = Control.MOUSE_FILTER_STOP
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	layer.add_child(_rules)
	# minigame-rules-panel already draws the blue board, the white page, and the clock.
	_rules_panel = TextureRect.new()
	_rules_panel.texture = _RULES_PANEL
	_rules_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rules_panel.stretch_mode = TextureRect.STRETCH_SCALE
	_rules_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rules.add_child(_rules_panel)
	_rules_title = Label.new()
	_rules_title.text = str(_game.get("title"))
	_rules_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rules_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rules_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rules.add_child(_rules_title)
	_rules_copy = str(_game.get("instructions"))
	_rules_body = Label.new()
	_rules_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rules_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_rules_body.autowrap_mode = TextServer.AUTOWRAP_OFF
	_rules_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rules_body.z_index = 5
	_rules.add_child(_rules_body)
	_clock = Label.new()
	_clock.text = "16"
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rules.add_child(_clock)
	_rules_play = TextureButton.new()
	_rules_play.texture_normal = _PLAY_UP
	_rules_play.texture_pressed = _PLAY_DN
	_rules_play.texture_hover = _PLAY_OVER
	_rules_play.ignore_texture_size = true
	_rules_play.stretch_mode = TextureButton.STRETCH_SCALE
	_rules_play.focus_mode = Control.FOCUS_NONE
	# self_modulate tints the pill and leaves the PLAY word white.
	_rules_play.self_modulate = Color(0.0, 0.9, 0.1)
	_rules_play.pressed.connect(_ask_ready)
	ToonGui.button_sounds(_rules_play)
	var caption := Label.new()
	caption.text = "PLAY"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rules_play.add_child(caption)
	_rules.add_child(_rules_play)
	_rules_skip = TextureButton.new()
	_rules_skip.texture_normal = _PLAY_UP
	_rules_skip.texture_pressed = _PLAY_DN
	_rules_skip.texture_hover = _PLAY_OVER
	_rules_skip.ignore_texture_size = true
	_rules_skip.stretch_mode = TextureButton.STRETCH_SCALE
	_rules_skip.focus_mode = Control.FOCUS_NONE
	_rules_skip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_rules_skip.self_modulate = Color(0.86, 0.22, 0.18)
	_rules_skip.pressed.connect(_ask_skip)
	ToonGui.button_sounds(_rules_skip)
	var skip_caption := Label.new()
	skip_caption.text = "Skip"
	skip_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	skip_caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	skip_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rules_skip.add_child(skip_caption)
	_rules.add_child(_rules_skip)
	var view := get_viewport()
	if not view.size_changed.is_connected(_layout_rules):
		view.size_changed.connect(_layout_rules)
	_layout_rules()


func _ask_ready() -> void:
	if _rules == null or _asked_ready:
		return
	if players <= 1:
		_start()
		return
	_asked_ready = true
	if _rules_play != null:
		_rules_play.disabled = true
	ToonNet.vote_trolley_ready()


func _ask_skip() -> void:
	if _rules == null or _asked_skip:
		return
	_asked_skip = true
	if _rules_skip != null:
		_rules_skip.disabled = true
	if ToonNet.vote_trolley_skip():
		_apply_skip()


func _paint_skip(state: Dictionary) -> void:
	if _rules_skip == null or _rules_skip.get_child_count() < 1:
		return
	var caption := _rules_skip.get_child(0) as Label
	if caption == null:
		return
	var group := maxi(int(state.get("players", players)), 1)
	var text := "Skip"
	if group > 1:
		var skips := 0
		var raw: Variant = state.get("skips", [])
		if raw is Array:
			skips = (raw as Array).size()
		text = "Skip %d/%d" % [skips, int(group / 2) + 1]
	if caption.text != text:
		caption.text = text


func _start() -> void:
	if _rules == null:
		return
	_drop_rules()
	_game.begin()


## A skip still shows a score of 0, then Goofy's. It pays nothing and does not
## count as a trolley ride. In a group, more than half the party has to skip.
func _apply_skip() -> void:
	if _did_skip:
		return
	_did_skip = true
	if _rules == null:
		return
	_drop_rules()
	if _game != null:
		if _game.finished.is_connected(_reward):
			_game.finished.disconnect(_reward)
		_game.queue_free()
		_game = null
	_quiet(self)
	ToonNet.finish_trolley(0)
	var stage: Node = (load("res://scenes/trolley/trolley_purchase.gd") as GDScript).new()
	stage.set("loadout", ToonLoadout.for_selected())
	stage.set("reward", 0)
	stage.set("preview_score", true)
	stage.connect("finished", _after_shop)
	_shop = stage
	add_child(stage)


func _drop_rules() -> void:
	if _rules == null:
		return
	var layer := _rules.get_parent()
	_rules = null
	_rules_panel = null
	_rules_title = null
	_rules_body = null
	_rules_copy = ""
	_rules_play = null
	_rules_skip = null
	_clock = null
	if layer != null:
		layer.queue_free()


func _reward(raw: int) -> void:
	# getScoreMult, then the jellybean holiday. They stack. The cap is 255.
	var paid := clampi(int(round(float(raw) * _multiplier() * float(_HOLIDAYS.bean_scale("trolley")))), 0, 255)
	ToonNet.finish_trolley(paid)
	_TASKS.for_selected().note_trolley()
	_quiet(self)
	if _game != null:
		_game.visible = false
	var stage: Node = (load("res://scenes/trolley/trolley_purchase.gd") as GDScript).new()
	stage.set("loadout", ToonLoadout.for_selected())
	stage.set("reward", paid)
	stage.connect("finished", _after_shop)
	_shop = stage
	add_child(stage)


func _after_shop(reason: String) -> void:
	if _shop != null:
		_shop.queue_free()
		_shop = null
	if reason == "again":
		if _game != null:
			if _game.finished.is_connected(_reward):
				_game.finished.disconnect(_reward)
			_game.queue_free()
			_game = null
		_choice = _pick()
		previous_id = int(_choice["id"])
		_play_song()
		_show_rules()
		return
	_home()


func _quiet(node: Node) -> void:
	for child in node.get_children():
		_quiet(child)
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			child.queue_free()


func _home() -> void:
	var arrival := load("res://scenes/playgrounds/playground_toon.gd") as GDScript
	arrival.teleport_in = true
	if return_scene.is_empty():
		return_scene = "res://scenes/playgrounds/toontown_central.tscn"
	ToonLoading.change_to(return_scene)


func _multiplier() -> float:
	var index := _ZONES.find(hood)
	if index < 0:
		index = 0
	return lerpf(1.0, 1.5, float(index) / float(_ZONES.size() - 1))


## MinigameRulesPanel sits at this aspect2d point. The card is centered on it.
const _RULES_ORIGIN := Vector2(0.1375, -0.6667)


func _layout_rules() -> void:
	if _rules == null or _rules_panel == null:
		return
	var origin := _RULES_ORIGIN
	_place(_rules_panel, origin.x, origin.y, 2.3208, 0.6417)
	ToonGui.style_sign(_rules_title, Color(1.0, 0.33, 0.33), _rules_px(0.11), Color(0, 0, 0, 0), 0)
	# The title stops short of Skip, which sits in the white page's top-right corner.
	_place(_rules_title, origin.x - 0.20, origin.y + 0.092, 1.28, 0.16)
	# The first line starts at the frame center, the same place as the original
	# instructions label. The white page on the 256x128 card is x 10..218, y 26..112.
	var panel := _rules_rect(origin.x, origin.y, 2.3208, 0.6417)
	var white := Rect2(
		panel.position.x + panel.size.x * (10.0 / 256.0),
		panel.position.y + panel.size.y * (26.0 / 128.0),
		panel.size.x * (208.0 / 256.0),
		panel.size.y * (86.0 / 128.0)
	)
	var top := panel.position.y + panel.size.y * 0.5
	var bottom := white.position.y + white.size.y - 4.0
	var left := white.position.x + panel.size.x * (8.0 / 256.0)
	var width := white.size.x - panel.size.x * (16.0 / 256.0)
	var face := ToonGui.font()
	var px := _rules_px(0.07)
	var wrapped := _rules_copy
	# The line budget is the white page. That is the original 26.5-font-height
	# word wrap at the full instruction size. A longer game shrinks until the
	# lines stay above the bottom of the page.
	while px > 10:
		wrapped = ToonGui.wrap_words(face, _rules_copy, px, width)
		var lines := maxi(wrapped.split("\n").size(), 1)
		if float(face.get_height(px)) * float(lines) <= bottom - top:
			break
		px -= 1
	_rules_body.text = wrapped
	_rules_body.position = Vector2(left, top)
	_rules_body.size = Vector2(width, maxf(bottom - top, 1.0))
	_rules_body.clip_text = true
	ToonGui.style_label(_rules_body, Color(0, 0, 0, 1), px, Color(0, 0, 0, 0), 0)
	_rules_body.add_theme_constant_override("line_spacing", 0)
	ToonGui.style_label(_clock, Color(0, 0, 0), _rules_px(0.108), Color(0, 0, 0, 0), 0)
	# The digits sit in the clock face that is already painted on the panel.
	_place(_clock, origin.x + 0.997, origin.y + 0.05, 0.26, 0.2)
	_place(_rules_play, origin.x + 1.0025, origin.y - 0.203, 0.1804 * 1.05, 0.1137 * 1.05)
	var caption := _rules_play.get_child(0) as Label
	if caption != null:
		ToonGui.style_label(caption, Color(1, 1, 1), _rules_px(0.055), Color(0, 0, 0, 0), 0)
	# White page on the 256x128 card runs to x 217 and starts at y 26.
	# Skip is inset from that corner so it stays on the page.
	if _rules_skip != null:
		_place(_rules_skip, origin.x + 0.66, origin.y + 0.115, 0.22, 0.09)
		var skip_caption := _rules_skip.get_child(0) as Label
		if skip_caption != null:
			ToonGui.style_label(skip_caption, Color(1, 1, 1), _rules_px(0.05), Color(0, 0, 0, 0), 0)


func _place(control: Control, ax: float, az: float, aw: float, ah: float) -> void:
	var rect := _rules_rect(ax, az, aw, ah)
	control.position = rect.position
	control.size = rect.size


func _rules_rect(ax: float, az: float, aw: float, ah: float) -> Rect2:
	var view := get_viewport().get_visible_rect().size
	var aspect := view.x / maxf(view.y, 1.0)
	var unit := view.y * 0.5
	var rect := Vector2(aw * unit, ah * unit)
	var center := Vector2((ax / aspect + 1.0) * 0.5 * view.x, (1.0 - az) * 0.5 * view.y)
	return Rect2(center - rect * 0.5, rect)


func _rules_px(aspect_height: float) -> int:
	return maxi(int(round(aspect_height * get_viewport().get_visible_rect().size.y * 0.5)), 8)


func _play_song() -> void:
	var path := String(_choice.get("music", ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var stream := AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		return
	stream.loop = bool(_choice.get("loop", true))
	var player := ToonAudio.music_player()
	player.stream = stream
	player.volume_db = linear_to_db(float(_choice.get("volume", 0.8)))
	add_child(player)
	player.play()
