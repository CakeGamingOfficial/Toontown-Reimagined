extends Node

## The party jukebox. A 20-song box plays the original short list. A 40-song
## box adds the longer list. A song repeats until it has played at least
## 50 seconds, then the queue waits MUSIC_GAP and plays the next one.
## The picker closes after 30 seconds. The song keeps playing.

signal closed

const _PARTY := preload("res://scenes/parties/toon_party.gd")
const _GUI := preload("res://scenes/toons/toon_gui.gd")
const _MIN_LENGTH := 50.0
const _GAP := 2.5
const _TIMEOUT := 30.0

const _SONGS: Array = [
	{"title": "Strolling Along", "path": "res://assets/neighborhoods/tutorial_zone/audio/TC_SZ.ogg", "length": 57, "extra": false},
	{"title": "The New Toon in Town", "path": "res://assets/toons/audio/create_a_toon.ogg", "length": 175, "extra": false},
	{"title": "The Toontown Theme", "path": "res://assets/toons/audio/tt_theme.mp3", "length": 51, "extra": false},
	{"title": "Toontown Central", "path": "res://assets/neighborhoods/toontown_central/audio/TC_nbrhood.ogg", "length": 59, "extra": false},
	{"title": "Running Toon", "path": "res://assets/audio/bgm/MG_TwoDGame.ogg", "length": 60, "extra": false},
	{"title": "The Jungle Swing", "path": "res://assets/audio/bgm/MG_Vine.ogg", "length": 32, "extra": false},
	{"title": "The Funny Farm", "path": "res://assets/audio/bgm/FF_safezone.ogg", "length": 47, "extra": false},
	{"title": "Waddling Way", "path": "res://assets/neighborhoods/donalds_dock/audio/DD_SZ.ogg", "length": 33, "extra": false},
	{"title": "Goofy Speedway", "path": "res://assets/neighborhoods/goofy_speedway/audio/GS_SZ.ogg", "length": 60, "extra": false},
	{"title": "Chip n' Dale's Acres", "path": "res://assets/neighborhoods/acorn_acres/audio/OZ_SZ.ogg", "length": 31, "extra": false},
	{"title": "The Putt-Putt Polka", "path": "res://assets/neighborhoods/chip_n_dales_minigolf/audio/GZ_SZ.ogg", "length": 59, "extra": false},
	{"title": "Dancing in the Streets", "path": "res://assets/neighborhoods/minnies_melodyland/audio/MM_SZ.ogg", "length": 76, "extra": false},
	{"title": "Waltz of the Flowers", "path": "res://assets/neighborhoods/daisy_gardens/audio/DG_SZ.ogg", "length": 48, "extra": false},
	{"title": "Sleepwalking", "path": "res://assets/neighborhoods/donalds_dreamland/audio/DL_SZ.ogg", "length": 33, "extra": false},
	{"title": "Shiver and Shimmy", "path": "res://assets/neighborhoods/the_burrrgh/audio/TB_SZ.ogg", "length": 54, "extra": false},
	{"title": "Court is in Session", "path": "res://assets/cog_hq/audio/LB_juryBG.ogg", "length": 30, "extra": false},
	{"title": "Party Time", "path": "res://assets/neighborhoods/party_grounds/audio/party_original_theme.ogg", "length": 56, "extra": false},
	{"title": "Encounter With Cogs", "path": "res://assets/audio/battle/encntr_general_bg.mp3", "length": 30, "extra": true},
	{"title": "Slow and Steady", "path": "res://assets/audio/bgm/minigame_race.ogg", "length": 77, "extra": true},
	{"title": "Catch That Cog!", "path": "res://assets/audio/bgm/MG_CogThief.ogg", "length": 61, "extra": true},
	{"title": "Slippery Situation", "path": "res://assets/audio/bgm/MG_IceGame.ogg", "length": 56, "extra": true},
	{"title": "Downtown Driving", "path": "res://assets/racing/audio/GS_Race_CC.ogg", "length": 58, "extra": true},
	{"title": "Ready, Set, Go!", "path": "res://assets/racing/audio/GS_Race_SS.ogg", "length": 61, "extra": true},
	{"title": "Route 66", "path": "res://assets/racing/audio/GS_Race_RR.ogg", "length": 60, "extra": true},
	{"title": "Donald's Dock", "path": "res://assets/neighborhoods/donalds_dock/audio/DD_nbrhood.ogg", "length": 67, "extra": true},
	{"title": "Mr. Goofywrench", "path": "res://assets/neighborhoods/goofy_speedway/audio/GS_KartShop.mp3", "length": 32, "extra": true},
	{"title": "Building Excitement", "path": "res://assets/buildings/cog/audio/encntr_general_bg_indoor.ogg", "length": 31, "extra": true},
	{"title": "Cog-tastrophe!", "path": "res://assets/buildings/cog/audio/encntr_suit_winning_indoor.ogg", "length": 36, "extra": true},
	{"title": "Donald's Dreamland", "path": "res://assets/neighborhoods/donalds_dreamland/audio/DL_nbrhood.ogg", "length": 30, "extra": true},
	{"title": "Cog Factory", "path": "res://assets/cog_hq/audio/CHQ_FACT_bg.ogg", "length": 50, "extra": true},
	{"title": "Balancing Act", "path": "res://assets/cog_hq/audio/LB_courtyard.ogg", "length": 32, "extra": true},
	{"title": "Cog Waltz", "path": "res://assets/cog_hq/audio/Bossbot_Factory_v1.ogg", "length": 30, "extra": true},
	{"title": "Bossing You Around", "path": "res://assets/cog_hq/audio/BossBot_CEO_v1.ogg", "length": 31, "extra": true},
]

var _wide := false
var _host := true
var _songs: Array = []
var _picked := 0
var _queue: Array = []
var _queued_pick := -1
var _current := ""
var _repeats := 0
var _gap := 0.0
var _gui_left := _TIMEOUT
var _gui := true
var _player: AudioStreamPlayer
var _hood: AudioStreamPlayer
var _layer: CanvasLayer
var _now: Label
var _song_box: VBoxContainer
var _queue_box: VBoxContainer


func setup(_player_body: ToonActor, _origin: Vector3, _party: Dictionary) -> void:
	var act_id := int(get_meta("act_id", 0))
	_wide = act_id == 8 or act_id == 18
	_host = not _PARTY.visiting()
	for row in _SONGS:
		var song: Dictionary = row
		if bool(song.get("extra", false)) and not _wide:
			continue
		_songs.append(song)
	_hood = _find_hood()
	if _hood != null:
		_hood.stream_paused = true
	_player = ToonAudio.music_player()
	_player.finished.connect(_track_done)
	add_child(_player)
	_build()


func open_gui() -> void:
	_gui = true
	_gui_left = _TIMEOUT
	if _layer != null:
		_layer.visible = true
	_paint()


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 26
	add_child(_layer)
	var panel := ColorRect.new()
	panel.color = Color(0.45, 0.2, 0.55, 0.94)
	panel.position = Vector2(180, 40)
	panel.size = Vector2(920, 620)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(panel)
	_now = Label.new()
	_now.position = Vector2(16, 12)
	_now.size = Vector2(880, 70)
	_now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_GUI.style_label(_now, Color.WHITE, 20, Color.BLACK, 3)
	panel.add_child(_now)
	var songs := ScrollContainer.new()
	songs.position = Vector2(16, 90)
	songs.size = Vector2(430, 430)
	panel.add_child(songs)
	_song_box = VBoxContainer.new()
	_song_box.custom_minimum_size = Vector2(400, 0)
	songs.add_child(_song_box)
	var queued := ScrollContainer.new()
	queued.position = Vector2(470, 90)
	queued.size = Vector2(430, 430)
	panel.add_child(queued)
	_queue_box = VBoxContainer.new()
	_queue_box.custom_minimum_size = Vector2(400, 0)
	queued.add_child(_queue_box)
	_button(panel, "Add Song", Vector2(16, 540), _add_song)
	if _host:
		_button(panel, "Move to Top", Vector2(230, 540), _move_top)
	_button(panel, "Done", Vector2(680, 540), _leave_gui)
	_paint()


func _button(parent: Control, caption: String, at: Vector2, call: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.position = at
	button.custom_minimum_size = Vector2(200, 40)
	button.pressed.connect(call)
	parent.add_child(button)


func _process(delta: float) -> void:
	if _gui:
		_gui_left -= delta
		if _gui_left <= 0.0:
			_leave_gui()
	if _gap > 0.0:
		_gap = maxf(_gap - delta, 0.0)
		if _gap == 0.0:
			_play_next()
	if _gui and _now != null:
		var playing := _current if _current != "" else "Add a song to the playlist!"
		_now.text = "Currently Playing\n%s\n%d" % [playing, int(ceil(_gui_left))]


func _paint() -> void:
	if _now == null:
		return
	var playing := _current if _current != "" else "Add a song to the playlist!"
	_now.text = "Currently Playing\n%s\nPick a Song:          Playing Next:     %d" % [playing, int(ceil(_gui_left)) if _gui else 0]
	for child in _song_box.get_children():
		child.queue_free()
	for index in _songs.size():
		var song: Dictionary = _songs[index]
		var button := Button.new()
		button.text = String(song.get("title", ""))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.modulate = Color(1, 1, 0.55) if index == _picked else Color.WHITE
		button.pressed.connect(_pick_song.bind(index))
		_song_box.add_child(button)
	for child in _queue_box.get_children():
		child.queue_free()
	if _queue.is_empty():
		var empty := Label.new()
		empty.text = "Playing Next:"
		_GUI.style_label(empty, Color.WHITE, 18, Color.BLACK, 3)
		_queue_box.add_child(empty)
	for index in _queue.size():
		var song: Dictionary = _queue[index]
		var button := Button.new()
		button.text = String(song.get("title", ""))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.modulate = Color(1, 1, 0.55) if index == _queued_pick else Color.WHITE
		button.pressed.connect(_pick_queue.bind(index))
		_queue_box.add_child(button)


func _pick_song(index: int) -> void:
	_picked = index
	_paint()


func _pick_queue(index: int) -> void:
	_queued_pick = index
	_paint()


func _add_song() -> void:
	if _picked < 0 or _picked >= _songs.size():
		return
	_queue.append((_songs[_picked] as Dictionary).duplicate())
	_queued_pick = _queue.size() - 1
	if _current == "" and _gap <= 0.0 and not _player.playing:
		_play_next()
	_paint()


func _move_top() -> void:
	if not _host or _queued_pick < 0 or _queued_pick >= _queue.size():
		return
	var song: Dictionary = _queue[_queued_pick]
	_queue.remove_at(_queued_pick)
	_queue.insert(0, song)
	_queued_pick = 0
	_paint()


func _play_next() -> void:
	if _queue.is_empty():
		_current = ""
		_resume_hood()
		_paint()
		return
	var song: Dictionary = _queue.pop_front()
	if _queued_pick == 0:
		_queued_pick = -1
	else:
		_queued_pick = maxi(_queued_pick - 1, -1)
	_current = String(song.get("title", ""))
	var length := float(song.get("length", 30))
	var times := int(round(_MIN_LENGTH / length))
	if times < 1:
		times = 1
	_repeats = times
	var stream := load(String(song.get("path", ""))) as AudioStream
	if stream == null:
		_gap = _GAP
		_paint()
		return
	if _hood != null:
		_hood.stream_paused = true
	_player.stream = stream
	_player.play()
	_repeats -= 1
	_paint()


func _track_done() -> void:
	if _repeats > 0:
		_repeats -= 1
		_player.play()
		return
	_gap = _GAP
	_paint()


func _leave_gui() -> void:
	if not _gui:
		return
	_gui = false
	if _layer != null:
		_layer.visible = false
	closed.emit()


func _find_hood() -> AudioStreamPlayer:
	var party := get_parent()
	if party == null:
		return null
	var hood := party.get_parent()
	if hood == null:
		return null
	return hood.get_node_or_null("NeighborhoodMusic") as AudioStreamPlayer


func _resume_hood() -> void:
	if _hood != null and is_instance_valid(_hood):
		_hood.stream_paused = false


func _exit_tree() -> void:
	_resume_hood()
