extends Node

## Place.enterTeleportIn plays Toon.getTeleportInTrack. A trolley task in
## Toontown Central pops up at an initial drop point. Logging in from Pick a
## Toon uses that disc, at the last playground or Cog HQ. Map teleports, and
## Tutorial Tom after the battle, throw the portable hole instead:
## Toon.getTeleportOutTrack, then getTeleportInTrack on arrival.

const _PLACES := preload("res://scenes/places/hood_places.gd")
const _LINKS := preload("res://scenes/places/tunnel_links.gd")
const _TITLE := preload("res://scenes/places/zone_title.gd")
const _KEYS := preload("res://scenes/shticker/keybinds.gd")
const _ChatSettings := preload("res://scenes/shticker/chat_settings.gd")
const _DOORS := preload("res://scenes/interiors/house_door.gd")
const _SHOP := preload("res://scenes/interiors/gag_shop_door.gd")
const _PET := preload("res://scenes/interiors/pet_shop_door.gd")
const _HALL := preload("res://scenes/interiors/toon_hall_door.gd")
const _LIB := preload("res://scenes/interiors/library_door.gd")
const _TELLER := preload("res://scenes/interiors/bank_door.gd")
const _HQ := preload("res://scenes/interiors/toon_hq_door.gd")
const _BLDG := preload("res://scenes/interiors/shop_door.gd")
const _FACTORY := preload("res://scenes/cog_hq/factory_elevator.gd")
const _BANK_GUI := preload("res://scenes/interiors/bank_gui.gd")
const _CATALOG := preload("res://scenes/catalog/catalog_book.gd")
const _CLOSET := preload("res://scenes/catalog/catalog_closet.gd")
const _SHOP_GUI := preload("res://scenes/interiors/gag_shop_gui.gd")
const _QUEST_CHOICE := preload("res://scenes/quests/quest_choice.gd")
const _TRACK_CHOICE := preload("res://scenes/quests/track_choice.gd")
const _BEANS := preload("res://scenes/toons/jellybeans.gd")
const _FISH := preload("res://scenes/fishing/fish_tank.gd")
const _SELL := preload("res://scenes/fishing/fish_sell_gui.gd")
const _CAST := preload("res://scenes/fishing/fishing_session.gd")
const _MARGINS := preload("res://scenes/toons/margin_tags.gd")
const _TROLLEY := preload("res://scenes/trolley/trolley.gd")
const _PORTAL := preload("res://scenes/playgrounds/teleport_portal.gd")
const _TELEPORT_SFX := "res://assets/audio/sfx/AV_teleport.ogg"
const _PICK_SCENE := "res://scenes/toons/pick_a_toon.tscn"
const _JAR_MODEL := "res://assets/props/jellybean_jar.glb"
# Toon.getJar: pitch 290, half a unit forward and up, in the right hand's space.
const _JAR_XFORM := Transform3D(
	Basis(
		Vector3(1.0, 0.0, 0.0),
		Vector3(0.0, 0.3420201, -0.9396926),
		Vector3(0.0, 0.9396926, 0.3420201)
	),
	Vector3(0.0, 0.5, 0.5)
)
# Toon.getTeleportOutTrack / getTeleportInTrack, in seconds.
const _OUT_TIME := 3.4
const _SOUND_AT := 0.5
const _DROP_AT := 1.708
const _IN_OPEN := 0.3
const _IN_HOLD := 0.6
const _JUMP_FROM := 0.45
# HouseGlobals.houseDrops headings, one lot per Pick a Toon slot.
const _ESTATE_HEADING: Array[float] = [-90.0, 116.565, 77.1957, 356.6, 248.962, 36.8699]

static var from_toontorial := false
static var teleport_in := false
## Welcome Valley is a copy of Toontown Central. Arriving there must not replace lastHood.
static var keep_last_hood := false
# Set with teleport_in when the map threw a portal. Arrival then plays
# getTeleportInTrack instead of the login disc.
static var portal_in := false
## Set when a street battle drops this toon to 0 laff. The next playground
## shows DeathForceAcknowledge once, then the Sad walk until a treasure heals them.
static var went_sad := false
const _DEATH_ACK := "The Cogs took all your gags!\n\nYou are sad. You may not leave the playground until you are happy."
const _DIALOG := preload("res://assets/gui/tutorial/dialog/dialog_box.png")
const _OK_UP := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_UP.png")
const _OK_DOWN := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_DN.png")
const _OK_HOVER := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_Rllvr.png")
# "in" loads this toon's house. "out" returns to the yard in front of the door.
static var door_trip := ""

const FORWARD_SPEED := 20.0
const REVERSE_SPEED := 10.0
const TURN_SPEED := 100.0
const GRAVITY := 64.348
const JUMP_FORCE := 24.0
const JUMP_LOCK := 0.2
const HARD_LAND := -30.0
const HARD_LOCK := 0.3
# Same tube the HQ stairs use. A radius-1 body stands on the landing and
# floats over the 45-degree plaza stairs.
const BODY_RADIUS := 0.35
# Street curbs rise 0.5. Plaza stairs rise 0.82, and the top one is 0.90.
# Cashbot HQ treads rise 1.82, so the step has to clear that riser.
const STEP_HEIGHT := 1.95
const _CAM_PITCH_HOME := 0.0
const _CAM_PITCH_MIN := -18.0
const _CAM_PITCH_MAX := 42.0
const _CAM_DIST_MIN := 0.38
const _CAM_DIST_MAX := 2.1

var _body: CharacterBody3D
var _player: ToonActor
var _camera: Camera3D
var _nametags: Nametags
var _margins: Node
var _remotes: RemoteToons
var _heading := 0.0
var _hood := 0
var _home := Vector3(-90.7, 0.35, 60.0)
var _home_heading := 102.575
var _void_time := 0.0
var _eye_height := 3.0
var _jumping := false
var _jump_lock := 0.0
var _locked := true
var _battle_hold := false
var _filming := false
var _portaling := false
var _tunnel_ready := false
var _door_ready := false
var _gag_sought := false
var _gag_building: Node3D
var _gag_door: Node3D
var _pet_ready := false
var _pet_sought := false
var _pet_building: Node3D
var _pet_door: Node3D
var _pet_trip := ""
var _hall_ready := false
var _hall_sought := false
var _hall_building: Node3D
var _hall_door: Node3D
var _lib_ready := false
var _lib_sought := false
var _lib_building: Node3D
var _lib_door: Node3D
var _teller_ready := false
var _teller_sought := false
var _teller_building: Node3D
var _teller_door: Node3D
var _hq_ready := false
var _officer_ready := false
var _npc_ready := false
var _hq_sought := false
var _hq_building: Node3D
# The hall must not share _door_ready. The gag shop arms that flag whenever
# the toon is simply not standing at the shop, which walked a hall exit
# straight back through the same door.
var _bank_ready := false
var _bank_open := false
var _phone_ready := false
var _catalog_open := false
var _closet_ready := false
var _closet_open := false
var _closet_cam := Transform3D.IDENTITY
var _phone_done := false
var _fish_open := false
var _casting := false
var _cast_ready := false
var _shore: Node3D
var _clerk_ready := false
var _fish_ready := false
var _clerk_mouth: Node3D
var _clerk_line: PanelContainer
var _clerk_label: Label
var _clerk_left := 0.0
var _trolley: Node
var _jar_beans: Node3D
var _bean_rest := Basis.IDENTITY
# Walk up to the jellybean bank. The sphere opens the counter, the way
# DistributedBank listens for enter on bankSphere.
const _BANK_REACH := 4.0
# __takeOutToonJar stands at (0, -3.125 * (FTScale + 0.2), 0). Every bank is scale 1.
const _BANK_STAND := 3.75
const _BANK_WALK := 0.5
const _BANK_ANIM := 3.8
const _BANK_GUI_AT := 3.0
const _BANK_JAR_IN := 1.5
const _BANK_PUT := 2.0
const _BANK_PING_LO := 48.0 / 24.0
const _BANK_PING_HI := 92.0 / 24.0
var _from_door := ""
var _shop_trip := ""
var _hall_trip := ""
var _lib_trip := ""
var _teller_trip := ""
var _hq_trip := ""
var _tunnels: Array[Dictionary] = []
var _bldg_trip := ""
var _factory_trip := ""
var _factory_entrance := 0
var _bldg_ready := false
var _shot := false
var _shot_origin: Node3D
var _shot_from := Vector3.ZERO
var _shot_blend := 0.0
var _tasks: ToonTasks
var _loadout: ToonLoadout
var _book: ShtickerBook
var _map: Control
var _meter: LaffMeter
var _line: PanelContainer
var _line_label: Label
var _line_text := ""
var _line_left := 0.0
var _line_kind := ""
var _cam_yaw := 0.0
var _cam_pitch := 0.0
var _cam_distance := 1.0
var _cam_steering := false
var _right_yaw := 0.0
var _running := false
var _reversing := false
var _active := false


## DevConsole sets _reload_armed before it rebuilds the place. A street only
## builds this toon for a tunnel or a shop door, so a reload has to notice
## that flag or the free-fly camera is what comes back.
static func reload_resume() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var console := tree.root.get_node_or_null("DevConsole")
	return console != null and bool(console.get("_reload_armed"))


## A street keeps the free-fly camera until a toon is due. Every door home
## counts, not only a shop or a tunnel. Missing one leaves no one to walk.
static func expects_avatar() -> bool:
	if reload_resume() or from_toontorial or teleport_in or portal_in:
		return true
	if door_trip != "" or _LINKS.arriving():
		return true
	if String(_SHOP.trip) != "" or String(_PET.trip) != "" or String(_HALL.trip) != "" or String(_LIB.trip) != "" or String(_TELLER.trip) != "":
		return true
	if String(_HQ.trip) != "" or String(_BLDG.trip) != "" or String(_FACTORY.trip) != "":
		return true
	return false


static func attach(host: Node) -> void:
	if Engine.is_editor_hint():
		return
	if host.get_node_or_null("PlaygroundToon") != null:
		return
	var arrival: Node = (load("res://scenes/playgrounds/playground_toon.gd") as GDScript).new()
	arrival.name = "PlaygroundToon"
	host.add_child(arrival)


func laff_missing() -> int:
	if _loadout == null:
		return 0
	return maxi(_loadout.max_hp - _loadout.hp, 0)


func _is_sad() -> bool:
	return _loadout != null and _loadout.hp < 1


func heal(amount: int) -> void:
	if _loadout == null or amount <= 0 or _loadout.hp >= _loadout.max_hp:
		return
	_loadout.set_hp(mini(_loadout.hp + amount, _loadout.max_hp), _loadout.max_hp)
	if _player != null:
		_player.set_sad(_is_sad())
	# The laff meter follows this loadout live, and other players read it from
	# the same object. The file is what the next launch loads.
	_loadout.save()


var _squish_left := 0.0


## Train.__handleCollisionSphereEnter. Ten laff and a two-second stun.
func squish(damage: int) -> void:
	if _loadout == null or _squish_left > 0.0 or damage <= 0:
		return
	_loadout.take_damage(damage)
	_loadout.save()
	_squish_left = 2.0
	if _player != null:
		_player.set_sad(_is_sad())
		ToonSpeech.speak(_player, "!")


func _ready() -> void:
	_tasks = ToonTasks.for_selected()
	var arriving := from_toontorial
	var logging_in := teleport_in
	var from_portal := portal_in
	var sad_arrival := went_sad
	went_sad = false
	var from_door := door_trip
	var from_shop := String(_SHOP.trip)
	var from_pet := String(_PET.trip)
	var from_hall := String(_HALL.trip)
	var from_lib := String(_LIB.trip)
	var from_teller := String(_TELLER.trip)
	var from_hq := String(_HQ.trip)
	var from_bldg := String(_BLDG.trip)
	var from_tunnel := _LINKS.arriving()
	var from_factory := _FACTORY.trip
	var restoring := reload_resume()
	var incoming := arriving or logging_in or from_portal or from_door != "" or from_shop != "" or from_pet != "" or from_hall != "" or from_lib != "" or from_teller != "" or from_hq != "" or from_bldg != "" or from_tunnel or from_factory != ""
	from_toontorial = false
	teleport_in = false
	portal_in = false
	door_trip = ""
	_SHOP.trip = ""
	_PET.trip = ""
	_HALL.trip = ""
	_LIB.trip = ""
	_TELLER.trip = ""
	_HQ.trip = ""
	_BLDG.trip = ""
	_from_door = from_door
	_shop_trip = from_shop
	_pet_trip = from_pet
	_hall_trip = from_hall
	_lib_trip = from_lib
	_teller_trip = from_teller
	_hq_trip = from_hq
	_bldg_trip = from_bldg
	_factory_trip = from_factory
	_factory_entrance = _FACTORY.entrance
	_FACTORY.trip = ""
	if not restoring and not arriving and not logging_in and not incoming and not _tasks.in_playground:
		queue_free()
		return
	var trip: Dictionary = {}
	if from_tunnel:
		trip = _LINKS.take()
	_active = true
	_hood = _current_hood()
	_SHOP.prepare(get_parent(), _hood)
	_PET.prepare(get_parent(), _hood)
	_HALL.prepare(get_parent())
	_LIB.prepare(get_parent())
	_TELLER.prepare(get_parent())
	_HQ.prepare(get_parent())
	var window := get_tree().root
	if _BLDG.street_zone(_scene_path()) != 0:
		_BLDG.prepare(get_parent())
	if not window.close_requested.is_connected(_keep_quests):
		window.close_requested.connect(_keep_quests)
	_quiet_fly_camera()
	_collect_tunnels(get_parent())
	_spawn(arriving or logging_in or from_factory == "in")
	if _player != null and _is_sad():
		_player.set_sad(true)
	_ready_hud()
	_trolley = _TROLLEY.new()
	_trolley.name = "Trolley"
	add_child(_trolley)
	if not _trolley.setup(self):
		_trolley = null
	# setFactoryInteriorZone. The exterior doors close, then enterTeleportIn
	# plays on the factory floor. The toon does not ride the interior car.
	if from_factory == "in":
		await _portal_in()
		if sad_arrival:
			await _death_ack()
		_locked = false
		_place_camera()
		return
	if from_door != "" or from_shop != "" or from_hall != "" or from_lib != "" or from_teller != "" or from_hq != "" or from_bldg != "":
		_tasks.note_hood(_hood)
		if from_hall == "out":
			await _settle_hall_exit()
		if from_lib == "out":
			await _settle_library_exit()
		if from_teller == "out":
			await _settle_teller_exit()
		if from_hq == "out":
			await _settle_hq_exit()
		_fade_in()
		_DOORS.play_close(self)
		if sad_arrival:
			await _death_ack()
		_locked = false
		_place_camera()
		return
	if arriving or logging_in or not trip.is_empty():
		_show_zone_title()
	if not trip.is_empty():
		var origin := _match_arrival(String(trip["from_code"]), int(trip["from_zone"]))
		if origin != null:
			_filming = true
			_locked = true
			await _tunnel_in(origin, float(trip["lateral"]))
			_filming = false
		if sad_arrival:
			await _death_ack()
		_locked = false
		_place_camera()
		return
	if arriving:
		_tasks.note_playground()
	elif _tasks.in_playground and not restoring:
		if keep_last_hood:
			keep_last_hood = false
		else:
			_tasks.note_hood(_hood)
	if arriving or logging_in:
		if from_portal:
			await _portal_in()
		else:
			_fade_in()
			await _pop_up()
	if sad_arrival:
		if _player != null:
			_player.set_sad(true)
		await _death_ack()
	_locked = false
	_place_camera()


func _exit_tree() -> void:
	_keep_quests()


## The journal is already written on each quest change. Closing the window
## after the toontorial writes it once more, so a quit cannot drop the last task.
func _keep_quests() -> void:
	if _tasks != null and _tasks.in_playground:
		_tasks.save()
	if _loadout != null:
		_loadout.save()


func _process(delta: float) -> void:
	if not _active or _player == null:
		return
	if _map != null and _body != null:
		_map.call("follow", _body.global_position, _heading)
	if _locked or _filming or _portaling or _bank_open or _battle_hold or (_book != null and _book.is_open()):
		_release_camera_mouse(true)
	if _trolley != null:
		_trolley.tick(delta)
	if _portaling:
		_place_camera()
		_place_line(delta)
		return
	if _filming:
		_player.set_locomotion(_LINKS.run_speed(), false, false, delta)
		if _shot and is_instance_valid(_shot_origin):
			_aim_tunnel_camera(_shot_origin, _shot_from, _shot_blend)
		_place_line(delta)
		return
	MagicWords.maintain(get_parent())
	var book_open := _book != null and _book.is_open()
	if _battle_hold:
		pass
	elif _fish_open or _casting:
		pass
	elif MagicWords.detached_camera() and not book_open and not _bank_open and not _locked:
		MagicWords.fly_camera(_camera, delta)
	elif _trolley != null and _trolley.holds_camera():
		_trolley.aim(_camera)
	elif _closet_open:
		_hold_closet_camera.call_deferred()
	else:
		_place_camera()
	_place_line(delta)


func _physics_process(delta: float) -> void:
	if _squish_left > 0.0:
		_squish_left = maxf(_squish_left - delta, 0.0)
		if _body != null:
			_body.velocity = Vector3.ZERO
		_leave_water()
		return
	if _battle_hold:
		if _body != null:
			_body.velocity = Vector3.ZERO
		_leave_water()
		return
	if not _active or _locked:
		_leave_water()
		return
	_walk(delta)
	if _is_sad():
		return
	_try_tunnel()
	_try_house_door()
	_try_gag_door()
	_try_pet_door()
	_try_hall_door()
	_try_library_door()
	_try_teller_door()
	_try_hq_door()
	_try_bank()
	_try_phone()
	_try_closet()
	_try_building_door()
	_try_clerk()
	_try_officer()
	_try_quest_npc()
	_try_fisherman()
	_try_fishing()
	_try_trolley()


func _unhandled_input(event: InputEvent) -> void:
	if _peek_hotkey(event):
		return
	if not _active or _casting:
		return
	_steer_camera(event)
	if _filming or _locked:
		return
	if _book != null and _tasks != null and _tasks.book_ready() and _book_hotkey(event):
		_book.toggle_hotkey()
		get_viewport().set_input_as_handled()
		return
	if _map != null and _map_hotkey(event):
		_map.call("toggle")
		get_viewport().set_input_as_handled()


func _peek_hotkey(event: InputEvent) -> bool:
	if _book == null or not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	var which := ""
	if _KEYS.matches(event, "gags"):
		which = "gags"
	elif _KEYS.matches(event, "tasks"):
		which = "tasks"
	else:
		return false
	if not key.pressed:
		_book.hide_peek(which)
		get_viewport().set_input_as_handled()
		return true
	if not _active or _casting or _filming or _locked or _battle_hold or _fish_open or _bank_open or _portaling:
		return true
	if _book.is_open() or _tasks == null or not _tasks.book_ready():
		return true
	_book.show_peek(which)
	get_viewport().set_input_as_handled()
	return true


func _book_hotkey(event: InputEvent) -> bool:
	# The Controls page can rebind the book key. Escape still opens it, the
	# way the original shticker book does, unless that press is cancelling a rebind.
	if _KEYS.event_is(event, "book"):
		return true
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return false
	return key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE


func _map_hotkey(event: InputEvent) -> bool:
	# ToontownGlobals.MapHotkey. want-toggle-quest-map opens and closes on Alt.
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return false
	return key.keycode == KEY_ALT or key.physical_keycode == KEY_ALT


func show_notice(message: String) -> void:
	_line_kind = ""
	say_line(message)


func _on_phrase(text: String) -> void:
	var chat := _hud().get_node_or_null("SpeedChat")
	_line_kind = "plus"
	if chat != null and bool(chat.get("phrase_is_speedchat")):
		_line_kind = "speed"
	say_line(text)
	_line_kind = ""


func say_line(text: String, seconds: float = -1.0) -> void:
	if _line == null:
		_line = PanelContainer.new()
		_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_line.z_index = 15
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1, 1, 1, 0.98)
		box.border_color = Color(0.05, 0.05, 0.05)
		box.set_border_width_all(3)
		box.set_corner_radius_all(16)
		box.content_margin_left = 12
		box.content_margin_right = 16
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		_line.add_theme_stylebox_override("panel", box)
		_line_label = Label.new()
		_line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ToonGui.style_label(_line_label, Color(0.05, 0.05, 0.08), 22, Color(0, 0, 0, 0), 0)
		_line.add_child(_line_label)
		_hud().add_child(_line)
	var fill := _line.get_theme_stylebox("panel") as StyleBoxFlat
	if fill != null:
		fill.bg_color = _ChatSettings.bubble(_line_kind)
	ToonGui.show_speech(_line_label, text, 22)
	_line_text = text
	if seconds < 0.0:
		_line_left = maxf(2.8, float(text.length()) * 0.045)
	else:
		_line_left = seconds
	_line.visible = _book == null or not _book.is_open()
	ToonSpeech.speak(_player, text)


## Drop a line this toon just said. A different line, such as SpeedChat, stays up.
func quiet_line(expected: String = "") -> void:
	if _line_label == null or _line == null:
		return
	if expected != "" and _line_text != expected:
		return
	_line_text = ""
	_line_left = 0.0
	_line.visible = false


func _quiet_fly_camera() -> void:
	var fly := get_parent().get_node_or_null("Camera") as Camera3D
	if fly == null:
		return
	fly.current = false
	fly.set_process(false)
	fly.set_process_unhandled_input(false)


func _current_hood() -> int:
	var scene_path := ""
	var current := get_tree().current_scene
	if current != null:
		scene_path = current.scene_file_path
	var hood: int = _PLACES.hood_for_scene(scene_path)
	if hood == 0 and _tasks != null:
		hood = _tasks.last_hood
	if hood == 0:
		hood = _PLACES.TTC
	return hood


func hold_for_battle(held: bool) -> void:
	_battle_hold = held
	if not held or _player == null:
		return
	_player.set_locomotion(0.0, false, false, 0.0)


func battle_busy() -> bool:
	if not _active or _locked or _filming or _portaling or _bank_open or _battle_hold:
		return true
	return _book != null and _book.is_open()


func battle_point() -> Vector3:
	if _body == null:
		return Vector3.ZERO
	return _body.global_position


func battle_name() -> String:
	var style := ToonRoster.selected_style()
	if style == null:
		return "Toon"
	return style.display_name()


func battle_hp() -> Vector2i:
	if _loadout == null:
		return Vector2i(ToonLoadout.START_HP, ToonLoadout.START_HP)
	return Vector2i(_loadout.hp, _loadout.max_hp)


func battle_loadout() -> ToonLoadout:
	return _loadout


func adopt_record(record: Dictionary) -> void:
	if _loadout != null:
		_loadout.apply_dict(record)
	if _tasks != null:
		_tasks.apply_dict(record)


func battle_actor() -> ToonActor:
	return _player


func place_for_battle(point: Vector3, heading: float) -> void:
	visit_friend(point, heading)


func pin_remote(peer: int, point: Vector3, heading: float) -> void:
	if _remotes != null:
		_remotes.pin(peer, point, heading)


func unpin_remote(peer: int) -> void:
	if _remotes != null:
		_remotes.unpin(peer)


func unpin_remotes() -> void:
	if _remotes != null:
		_remotes.unpin_all()


func remote_actor(peer: int) -> ToonActor:
	if _remotes == null:
		return null
	return _remotes.actor_for(peer)


func visit_friend(point: Vector3, heading: float) -> void:
	if _body == null or _player == null:
		return
	_body.global_position = point
	_heading = heading
	_face(_player, heading)


## DevConsole's Reload button frees the place and builds it again. This puts
## the toon back on the spot they were standing, facing the same way.
func plant(point: Vector3, heading: float) -> void:
	visit_friend(point, heading)
	_home = point
	_home_heading = heading


func _arrival_spot() -> Dictionary:
	if ToonSocial.visit_on and ToonSocial.visit_scene == _scene_path():
		ToonSocial.visit_on = false
		return {"point": ToonSocial.visit_point, "heading": ToonSocial.visit_heading}
	var club: Dictionary = preload("res://scenes/cog_hq/bossbot_doors.gd").arrival(get_parent())
	if not club.is_empty():
		return {"point": _snap_drop(club["point"]), "heading": float(club["heading"])}
	var scene_path := _scene_path()
	if _factory_trip != "":
		var ride: Dictionary = _FACTORY.arrival(get_parent(), _factory_entrance, _factory_trip == "in")
		_factory_trip = ""
		if not ride.is_empty():
			return {"point": _snap_drop(ride["point"]), "heading": float(ride["heading"])}
	if _shop_trip == "out":
		return _shop_outside_drop()
	if _pet_trip == "out":
		return _pet_outside_drop()
	if _hall_trip == "out":
		return _hall_outside_drop()
	if _lib_trip == "out":
		return _library_outside_drop()
	if _teller_trip == "out":
		return _teller_outside_drop()
	if _hq_trip == "out":
		return _hq_outside_drop()
	if _bldg_trip == "out":
		return _building_outside_drop()
	if _PLACES.is_gag_shop(scene_path):
		return _shop_inside_drop()
	if _PLACES.is_pet_shop(scene_path):
		return _pet_inside_drop()
	if _PLACES.is_toon_hall(scene_path):
		return _hall_inside_drop()
	if _PLACES.is_library(scene_path):
		return _library_inside_drop()
	if _PLACES.is_bank(scene_path):
		return _teller_inside_drop()
	if _PLACES.is_toon_hq(scene_path):
		return _hq_inside_drop()
	if _PLACES.is_shop(scene_path):
		return _building_inside_drop()
	if _PLACES.is_house(scene_path):
		return _house_drop()
	if _hood == _PLACES.ESTATE and _from_door == "out":
		return _estate_door_drop()
	if _hood == _PLACES.ESTATE:
		return _estate_drop()
	if _PLACES.is_playground(_hood):
		# Playground.enterTeleportIn uses HoodMgr.getPlaygroundCenterFromId,
		# which picks one of that playground's drop points at random.
		var choice: Dictionary = _PLACES.random_drop(_hood)
		var spot: Vector3 = choice["point"]
		return {"point": _snap_drop(spot), "heading": float(choice["heading"])}
	if _PLACES.has_drop(_hood):
		return {
			"point": _snap_drop(_PLACES.drop_for(_hood)),
			"heading": _PLACES.heading_for(_hood),
		}
	return _view_drop()


func _scene_path() -> String:
	var current := get_tree().current_scene
	if current != null and not current.scene_file_path.is_empty():
		return current.scene_file_path
	if get_parent() != null:
		return get_parent().scene_file_path
	return ""


func _estate_slot() -> int:
	var host := get_parent()
	if host != null and "estate_slot" in host:
		return clampi(int(host.get("estate_slot")), 0, 5)
	return clampi(ToonRoster.selected_index(), 0, 5)


func _house_drop() -> Dictionary:
	# DistributedDoor.avatarExitTrack finishes at (-doorX, -6) on the interior
	# door, facing into the room.
	var origin := _DOORS.find_origin(get_parent())
	if origin == null:
		return {"point": Vector3(0.0, 0.35, 0.0), "heading": 0.0}
	var drop: Dictionary = _DOORS.inside_drop(origin)
	var point: Vector3 = drop["point"]
	return {"point": _snap_drop(point), "heading": float(drop["heading"])}


func _estate_door_drop() -> Dictionary:
	var house := _DOORS.find_house(get_parent(), _estate_slot())
	if house == null:
		return _estate_drop()
	var origin := _DOORS.find_origin(house)
	if origin == null:
		return _estate_drop()
	var drop: Dictionary = _DOORS.outside_drop(house, origin)
	var point: Vector3 = drop["point"]
	return {"point": _snap_drop(point), "heading": float(drop["heading"])}


func _try_trolley() -> void:
	if _trolley == null or _body == null or _book != null and _book.is_open():
		return
	if not _trolley.can_board() or not _trolley.near(_body):
		return
	_locked = true
	_body.velocity = Vector3.ZERO
	if _player != null:
		_player.set_locomotion(0.0, false, false, 0.016)
	_trolley.board(_body, _player)


func _try_bank() -> void:
	if _body == null or get_parent() == null or not _PLACES.is_house(_scene_path()):
		_bank_ready = true
		return
	var bank := get_parent().find_child("bank", true, false) as Node3D
	if bank == null:
		_bank_ready = true
		return
	var offset := bank.global_position - _body.global_position
	var gap := Vector2(offset.x, offset.z).length()
	if gap > _BANK_REACH:
		_bank_ready = true
		return
	if _book != null and _book.is_open():
		_bank_ready = false
		return
	if not _bank_ready:
		return
	_bank_ready = false
	_locked = true
	_body.velocity = Vector3.ZERO
	_use_bank(bank)


## __takeOutToonJar walks to the machine, grows the jar, and plays "bank".
## The counter opens 3 seconds in. Closing it runs __putAwayToonJar backward.
func _use_bank(bank: Node3D) -> void:
	if _player == null or _body == null:
		_locked = false
		return
	var stand := bank.to_global(Vector3(0.0, -_BANK_STAND, 0.0))
	stand.y = _body.global_position.y
	var face := bank.global_transform.basis * Vector3(0.0, 1.0, 0.0)
	face.y = 0.0
	var aim := _heading
	if face.length_squared() > 0.0001:
		aim = _heading_toward(face)
	var start := _body.global_position
	var start_heading := _heading
	var elapsed := 0.0
	var delta := 0.0
	var ping := _BANK_PING_LO
	var ping_dir := 1.0
	var jar: Node3D = null
	var shown := false
	while true:
		if elapsed < _BANK_WALK:
			var weight := _ease_in_out(elapsed / _BANK_WALK)
			_body.global_position = start.lerp(stand, weight)
			_heading = rad_to_deg(lerp_angle(deg_to_rad(start_heading), deg_to_rad(aim), weight))
			_face(_player, _heading)
			_player.play_walk(delta)
		else:
			if jar == null:
				_body.global_position = stand
				_heading = aim
				_face(_player, _heading)
				jar = _attach_jar()
				_player.set_look_enabled(false)
			var anim_time := elapsed - _BANK_WALK
			if anim_time < _BANK_ANIM:
				_player.pose_action("bank", anim_time)
			else:
				_player.pose_action("bank", ping)
			_set_jar_scale(jar, _ease_out(clampf(anim_time / _BANK_JAR_IN, 0.0, 1.0)))
			_face_jar_beans(jar)
			if not shown and elapsed >= _BANK_GUI_AT:
				shown = true
				_open_bank_gui()
			if shown and not _bank_open:
				break
		_place_camera()
		await get_tree().process_frame
		if not is_inside_tree():
			return
		delta = get_process_delta_time()
		elapsed += delta
		if elapsed - _BANK_WALK >= _BANK_ANIM:
			ping += ping_dir * delta
			if ping >= _BANK_PING_HI:
				ping = _BANK_PING_HI
				ping_dir = -1.0
			elif ping <= _BANK_PING_LO:
				ping = _BANK_PING_LO
				ping_dir = 1.0
	var put := 0.0
	while put < _BANK_PUT:
		var along := clampf(put / _BANK_PUT, 0.0, 1.0)
		_player.pose_action("bank", lerpf(2.0, 0.0, along))
		if jar != null:
			_set_jar_scale(jar, 1.0 - _ease_in(along))
			_face_jar_beans(jar)
		_place_camera()
		await get_tree().process_frame
		if not is_inside_tree():
			return
		put += get_process_delta_time()
	if jar != null and is_instance_valid(jar):
		jar.queue_free()
	_jar_beans = null
	_player.end_action("bank")
	_player.set_look_enabled(true)
	_locked = false
	if _book != null:
		_book.refresh_jar()


## DistributedPhone's sphere is 0.2, just in front of the handset. The toon's
## own radius makes the phone answer from a step away.
const _PHONE_REACH := 2.2
# takePhoneInterval stands at the phone's (0, -4.5, 0) and walks for one second.
const _PHONE_WALK := 1.0
const _PHONE_STAND := 4.5
const _PHONE_PICKUP_AT := 0.625
const _PHONE_HANDLE_AT := 1.625
const _PHONE_HANG_AT := 1.0
const _PHONE_CLIPS := "res://assets/props/phone_clips.bin"
const _PHONE_PICKUP := "res://assets/audio/sfx/telephone_pickup1.ogg"
const _PHONE_HANDLE := "res://assets/audio/sfx/telephone_handle2.ogg"
const _PHONE_HANG := "res://assets/audio/sfx/telephone_hang_up.ogg"
const _PHONE_RING := "res://assets/audio/sfx/telephone_ring.ogg"
static var _phone_book: Dictionary = {}


## DistributedCloset's sphere is 2.125. The toon walks to the closet's
## (1.67, -3.29) and the wardrobe opens.
const _CLOSET_REACH := 3.2
const _CLOSET_WALK := 1.0
const _WARDROBE := preload("res://scenes/catalog/wardrobe.gd")


func _try_closet() -> void:
	if _body == null or get_parent() == null or not _PLACES.is_house(_scene_path()):
		_closet_ready = true
		return
	if _catalog_open or _bank_open or _closet_open or (_book != null and _book.is_open()):
		_closet_ready = false
		return
	var closet := get_parent().find_child("closet", true, false) as Node3D
	if closet == null:
		_closet_ready = true
		return
	var offset := closet.global_position - _body.global_position
	if Vector2(offset.x, offset.z).length() > _CLOSET_REACH:
		_closet_ready = true
		return
	if not _closet_ready:
		return
	_closet_ready = false
	_locked = true
	_body.velocity = Vector3.ZERO
	_use_closet(closet)


func _use_closet(closet: Node3D) -> void:
	if _player == null or _body == null:
		_locked = false
		return
	var stand := closet.to_global(Vector3(1.67, -3.29, 0.0))
	stand.y = _body.global_position.y
	var face := closet.global_position - stand
	face.y = 0.0
	var aim := _heading_toward(face) if face.length_squared() > 0.0001 else _heading
	var start := _body.global_position
	var start_heading := _heading
	var elapsed := 0.0
	while elapsed < _CLOSET_WALK:
		var weight := _ease_in_out(elapsed / _CLOSET_WALK)
		_body.global_position = start.lerp(stand, weight)
		_heading = rad_to_deg(lerp_angle(deg_to_rad(start_heading), deg_to_rad(aim), weight))
		_face(_player, _heading)
		_player.play_walk(get_process_delta_time())
		_place_camera()
		await get_tree().process_frame
		if not is_inside_tree():
			return
		elapsed += get_process_delta_time()
	_body.global_position = stand
	_heading = aim
	_face(_player, _heading)
	_player.set_locomotion(0.0, false, false, 0.0)
	if _camera != null:
		_closet_cam = _camera.global_transform
	var book := _WARDROBE.new() as Control
	book.name = "Wardrobe"
	_hud().add_child(book)
	_closet_open = true
	var style := ToonRoster.selected_style()
	var camera_yaw := _cam_yaw
	var kept: bool = await book.open(_player, style)
	_cam_yaw = camera_yaw
	_adopt_facing()
	if _camera != null:
		_camera.top_level = false
	_closet_open = false
	if kept and style != null:
		_CLOSET.dress(style)
	_locked = false


func _try_phone() -> void:
	if _body == null or get_parent() == null or not _PLACES.is_house(_scene_path()):
		_phone_ready = true
		return
	if _catalog_open or _bank_open or _closet_open or (_book != null and _book.is_open()):
		_phone_ready = false
		return
	var phone := get_parent().find_child("phone", true, false) as Node3D
	if phone == null:
		_phone_ready = true
		return
	var offset := phone.global_position - _body.global_position
	if Vector2(offset.x, offset.z).length() > _PHONE_REACH:
		_phone_ready = true
		return
	if not _phone_ready:
		return
	_phone_ready = false
	_locked = true
	_catalog_open = true
	_body.velocity = Vector3.ZERO
	if _player != null:
		_player.set_locomotion(0.0, false, false, 0.016)
	_use_phone(phone)


## takePhoneInterval, then the catalog, then replacePhoneInterval.
func _use_phone(phone: Node3D) -> void:
	if _player == null or _body == null:
		_finish_phone()
		return
	_phone_done = false
	_player.ensure_clip("takePhone")
	_player.ensure_clip("phoneNeutral")
	_player.ensure_clip("phoneBack")
	_player.set_look_enabled(false)
	var size := _phone_size()
	var home_scale := phone.scale
	var toon_scale := _player.scale
	_bind_phone(phone, size)
	var stand := phone.to_global(Vector3(0.0, -_PHONE_STAND, 0.0))
	stand.y = _body.global_position.y
	var face := phone.global_transform.basis * Vector3(0.0, 1.0, 0.0)
	face.y = 0.0
	var aim := _heading
	if face.length_squared() > 0.0001:
		aim = _heading_toward(face)
	var start := _body.global_position
	var start_heading := _heading
	var out_len := _phone_length(size, "phoneOut")
	var lead := maxf(_PHONE_WALK, out_len)
	var elapsed := 0.0
	var delta := 0.0
	while elapsed < lead:
		if elapsed < _PHONE_WALK:
			var weight := _ease_in_out(elapsed / _PHONE_WALK)
			_body.global_position = start.lerp(stand, weight)
			_heading = rad_to_deg(lerp_angle(deg_to_rad(start_heading), deg_to_rad(aim), weight))
			_face(_player, _heading)
			_player.play_walk(delta)
		else:
			_body.global_position = stand
			_heading = aim
			_face(_player, _heading)
		_pose_phone(size, "phoneOut", elapsed, false)
		phone.scale = home_scale.lerp(toon_scale, _ease_in_out(clampf(elapsed / _PHONE_WALK, 0.0, 1.0)))
		_place_camera()
		if not await _phone_frame():
			return
		delta = get_process_delta_time()
		elapsed += delta
	_body.global_position = stand
	_heading = aim
	_face(_player, _heading)
	var take_len := _player.action_length("takePhone")
	var grabbed := false
	var handled := false
	elapsed = 0.0
	while elapsed < take_len:
		_player.pose_action("takePhone", elapsed)
		_pose_phone(size, "takePhone", elapsed, false)
		if not grabbed and elapsed >= _PHONE_PICKUP_AT:
			grabbed = true
			_play_phone_sfx(_PHONE_PICKUP)
			_grab_receiver(phone)
		if not handled and elapsed >= _PHONE_HANDLE_AT:
			handled = true
			_play_phone_sfx(_PHONE_HANDLE)
		_place_camera()
		if not await _phone_frame():
			return
		elapsed += get_process_delta_time()
	if not grabbed:
		_grab_receiver(phone)
	_play_phone_sfx(_PHONE_RING)
	_open_catalog()
	var neutral := 0.0
	while not _phone_done:
		var toon_span := _player.action_length("phoneNeutral")
		var shown := neutral if toon_span <= 0.0 else fposmod(neutral, toon_span)
		_player.pose_action("phoneNeutral", shown)
		_pose_phone(size, "phoneNeutral", neutral, true)
		_place_camera()
		if not await _phone_frame():
			return
		neutral += get_process_delta_time()
	var back_len := _player.action_length("phoneBack")
	var returned := false
	elapsed = 0.0
	while elapsed < back_len:
		_player.pose_action("phoneBack", elapsed)
		_pose_phone(size, "phoneBack", elapsed, false)
		if not returned and elapsed >= _PHONE_HANG_AT:
			returned = true
			_return_receiver()
			_play_phone_sfx(_PHONE_HANG)
		_place_camera()
		if not await _phone_frame():
			return
		elapsed += get_process_delta_time()
	if not returned:
		_return_receiver()
		_play_phone_sfx(_PHONE_HANG)
	if not home_scale.is_equal_approx(phone.scale):
		var from_scale := phone.scale
		var put := 0.0
		while put < 1.0:
			phone.scale = from_scale.lerp(home_scale, _ease_in_out(clampf(put, 0.0, 1.0)))
			_place_camera()
			if not await _phone_frame():
				return
			put += get_process_delta_time()
	phone.scale = home_scale
	if back_len > 0.0:
		_player.end_action("phoneBack")
	elif take_len > 0.0:
		_player.end_action("phoneNeutral")
	_player.set_look_enabled(true)
	_reset_phone()
	_finish_phone()


func _phone_frame() -> bool:
	await get_tree().process_frame
	return is_inside_tree()


func _finish_phone() -> void:
	_return_receiver()
	_catalog_open = false
	_locked = false
	_phone_ready = false
	_phone_done = false


func _open_catalog() -> void:
	var book := _CATALOG.new() as Control
	book.name = "Catalog"
	var style := ToonRoster.selected_style()
	_CLOSET.dress(style)
	book.call("open", style, _player)
	book.connect("finished", _catalog_closed)
	_hud().add_child(book)


func _catalog_closed() -> void:
	_phone_done = true


func _phone_size() -> String:
	var style := ToonRoster.selected_style()
	if style == null or style.torso.is_empty() or style.legs.is_empty():
		return "ms"
	return (style.torso.substr(0, 1) + style.legs.substr(0, 1)).to_lower()


func _play_phone_sfx(path: String) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var player := ToonAudio.effect_player()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


var _phone_rig: Array = []
var _receiver: MeshInstance3D
var _receiver_joint: Node3D
var _receiver_home := Transform3D.IDENTITY
var _receiver_held := false


func _bind_phone(phone: Node3D, size: String) -> void:
	_read_phone_book()
	_phone_rig.clear()
	var record: Dictionary = _phone_book.get(size, {})
	var joints: Array = record.get("joints", [])
	for joint in joints:
		var data: Dictionary = joint
		var node := phone.find_child(String(data.get("name", "")), true, false) as Node3D
		if node == null:
			_phone_rig.append({})
		else:
			_phone_rig.append({
				"node": node,
				"rest": node.transform,
				"bind": data["bind"],
			})


func _pose_phone(size: String, anim: String, elapsed: float, loop: bool) -> void:
	var record: Dictionary = _phone_book.get(size, {})
	var anims: Dictionary = record.get("anims", {})
	var clip: Dictionary = anims.get(anim, {})
	var frames := int(clip.get("frames", 0))
	var tracks: Array = clip.get("tracks", [])
	if frames <= 1 or tracks.size() != _phone_rig.size():
		return
	var span := float(frames - 1)
	var time := elapsed * 24.0
	if loop:
		time = fposmod(time, span)
	else:
		time = clampf(time, 0.0, span)
	var frame := mini(int(time), frames - 1)
	var following := mini(frame + 1, frames - 1)
	var blend: float = 0.0 if following == frame else time - float(frame)
	for index in _phone_rig.size():
		var rig: Dictionary = _phone_rig[index]
		if rig.is_empty():
			continue
		var track: Array = tracks[index]
		var posed: Transform3D = track[frame]
		if blend > 0.0:
			var after: Transform3D = track[following]
			posed = posed.interpolate_with(after, blend)
		var node := rig["node"] as Node3D
		var rest: Transform3D = rig["rest"]
		var bind: Transform3D = rig["bind"]
		node.transform = rest * bind.affine_inverse() * posed


func _phone_length(size: String, anim: String) -> float:
	_read_phone_book()
	var record: Dictionary = _phone_book.get(size, {})
	var anims: Dictionary = record.get("anims", {})
	var clip: Dictionary = anims.get(anim, {})
	var frames := int(clip.get("frames", 0))
	if frames <= 1:
		return 0.0
	return float(frames - 1) / 24.0


func _reset_phone() -> void:
	for rig in _phone_rig:
		if rig.is_empty():
			continue
		var node := rig["node"] as Node3D
		if node != null and is_instance_valid(node):
			node.transform = rig["rest"]
	_phone_rig.clear()


func _grab_receiver(phone: Node3D) -> void:
	if _receiver_held or _player == null:
		return
	var joint := phone.find_child("joint_receiver", true, false) as Node3D
	var mesh := _first_mesh(joint)
	var hand := _find(_player, "def_joint_left_hold")
	if joint == null or mesh == null or hand == null:
		return
	_receiver = mesh
	_receiver_joint = joint
	_receiver_home = mesh.transform
	mesh.reparent(hand)
	mesh.transform = _receiver_in_hand()
	_receiver_held = true


func _return_receiver() -> void:
	if not _receiver_held or _receiver == null or not is_instance_valid(_receiver):
		_receiver_held = false
		return
	if _receiver_joint != null and is_instance_valid(_receiver_joint):
		_receiver.reparent(_receiver_joint)
		_receiver.transform = _receiver_home
	_receiver_held = false


## __receiverToHand. Panda pos/hpr (0.0906813, 0.380375, 0.1, 32.41, 70.68, 137.04).
func _receiver_in_hand() -> Transform3D:
	var basis := Basis(
		Vector3(-0.962526, 0.150694, -0.225466),
		Vector3(-0.177324, 0.27931, 0.943685),
		Vector3(0.205183, 0.948302, -0.242121)
	)
	return Transform3D(basis, Vector3(0.090681, 0.380375, 0.1))


func _first_mesh(node: Node) -> MeshInstance3D:
	if node == null:
		return null
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _first_mesh(child)
		if found != null:
			return found
	return null


func _read_phone_book() -> void:
	if not _phone_book.is_empty():
		return
	var file := FileAccess.open(_PHONE_CLIPS, FileAccess.READ)
	if file == null:
		return
	var magic := file.get_buffer(7).get_string_from_utf8()
	if magic != "PHONE1":
		file.close()
		return
	var sizes := file.get_32()
	for _size_index in sizes:
		var size_name := _phone_string(file)
		var joint_count := file.get_32()
		var joints: Array = []
		for _joint_index in joint_count:
			joints.append({
				"name": _phone_string(file),
				"bind": _phone_xform(file),
			})
		var anim_count := file.get_32()
		var anims := {}
		for _anim_index in anim_count:
			var anim_name := _phone_string(file)
			var frames := file.get_32()
			var tracks: Array = []
			for _track_index in joint_count:
				var track: Array[Transform3D] = []
				for _frame_index in frames:
					track.append(_phone_xform(file))
				tracks.append(track)
			anims[anim_name] = {"frames": frames, "tracks": tracks}
		_phone_book[size_name] = {"joints": joints, "anims": anims}
	file.close()


func _phone_string(file: FileAccess) -> String:
	var length := file.get_16()
	return file.get_buffer(length).get_string_from_utf8()


func _phone_xform(file: FileAccess) -> Transform3D:
	var cells := PackedFloat32Array()
	cells.resize(16)
	for index in 16:
		cells[index] = file.get_float()
	var basis := Basis(
		Vector3(cells[0], cells[1], cells[2]),
		Vector3(cells[4], cells[5], cells[6]),
		Vector3(cells[8], cells[9], cells[10])
	)
	return Transform3D(basis, Vector3(cells[12], cells[13], cells[14]))


func _open_bank_gui() -> void:
	_bank_open = true
	var panel := _BANK_GUI.new() as Node
	panel.name = "BankGui"
	panel.connect("finished", _bank_gui_closed)
	_hud().add_child(panel)


func _bank_gui_closed() -> void:
	_bank_open = false
	if _book != null:
		_book.refresh_jar()


## DistributedNPCToonBase puts a CollisionTube one unit in front of the clerk,
## radius 3.25, from the floor to above their head. The toon's own sphere is
## 1.4, so the counter in front of them is inside the trigger. A fisherman's
## tube uses getCollSphereRadius, which is 1.
const _CLERK_FORWARD := 1.0
const _CLERK_REACH := 3.25 + 1.4
const _FISHER_REACH := 1.0 + 1.4
const _NO_FISH := "Come back here to sell fish to the Pet Shop for jellybeans."
const _THANKS_FISH := "Thanks! The Pet Shop will love these. Bye!"
const _TROPHY_FISH := "Wow! You collected %d of %d fish. That deserves a trophy and a Laff boost!"
const _FISH_SLOW := "Need more time to think?"


## DistributedFishingSpot sphere is 1.5 at the outer end of the pier. A toon
## standing on the planks is still on that dock, so the plate counts too.
## Spots with no plate keep the old point test.
const _DOCK_MARGIN := 1.5
const _SHORE_REACH := 6.5


func aim_fishing(heading: float) -> void:
	_heading = heading
	if _player != null:
		_face(_player, heading)


func stand_fishing(at: Vector3) -> void:
	if _body == null:
		return
	_body.velocity = Vector3.ZERO
	_body.global_position = at


func refresh_fishing_jar() -> void:
	if _book != null:
		_book.refresh_jar()


func _try_fishing() -> void:
	if _casting or _body == null or _player == null:
		return
	var spot := _nearest_shore()
	# Each dock is its own sphere. Walking off one and onto the next starts
	# a cast, the same as a new enterFishingSpotSphere.
	if spot != _shore:
		_shore = spot
		_cast_ready = true
	if spot == null:
		return
	if not _cast_ready or _is_sad():
		return
	if _book != null and _book.is_open():
		_cast_ready = false
		return
	_cast_ready = false
	_casting = true
	_locked = true
	_body.velocity = Vector3.ZERO
	var session := _CAST.new()
	session.open(_player, _camera, spot, _body.global_position, _heading)
	add_child(session)
	await session.finished
	if not is_inside_tree():
		return
	_casting = false
	_locked = false
	if _book != null:
		_book.refresh_jar()


func _nearest_shore() -> Node3D:
	var host := get_parent()
	if host == null or _body == null:
		return null
	var best: Node3D = null
	var best_gap := INF
	for node in host.find_children("FishingShore", "Node3D", true, false):
		var spot := node as Node3D
		if spot == null or not spot.is_visible_in_tree():
			continue
		var margin := _DOCK_MARGIN if spot.has_meta("deck_min") else _SHORE_REACH
		var gap := _shore_gap(spot)
		if gap <= margin and gap < best_gap:
			best_gap = gap
			best = spot
	return best


func _shore_gap(spot: Node3D) -> float:
	if not spot.has_meta("deck_min"):
		var offset := spot.global_position - _body.global_position
		return Vector2(offset.x, offset.z).length()
	var local: Vector3 = spot.global_transform.affine_inverse() * _body.global_position
	var deck_min: Vector2 = spot.get_meta("deck_min")
	var deck_max: Vector2 = spot.get_meta("deck_max")
	var clamped := Vector2(
		clampf(local.x, deck_min.x, deck_max.x),
		clampf(local.y, deck_min.y, deck_max.y)
	)
	return Vector2(local.x, local.y).distance_to(clamped)


func _try_fisherman() -> void:
	if _body == null:
		_fish_ready = true
		return
	var fisher := _nearest_fisherman()
	if fisher == null:
		_fish_ready = true
		return
	if _book != null and _book.is_open():
		_fish_ready = false
		return
	if not _fish_ready:
		return
	_fish_ready = false
	_locked = true
	_body.velocity = Vector3.ZERO
	if _player != null:
		_player.set_locomotion(0.0, false, false, 0.016)
	_talk_fisherman(fisher)


func _nearest_fisherman() -> Node3D:
	var host := get_parent()
	if host == null:
		return null
	var best: Node3D = null
	var best_gap := _FISHER_REACH
	for node in host.find_children("Fishermen", "StaticBody3D", true, false):
		var body := node as Node3D
		if body == null or not body.is_visible_in_tree():
			continue
		var actor := _clerk_actor(body)
		var center := body.global_position + _clerk_forward(actor) * _CLERK_FORWARD
		var offset := center - _body.global_position
		var gap := Vector2(offset.x, offset.z).length()
		if gap <= best_gap:
			best_gap = gap
			best = body
	return best


func _talk_fisherman(fisher: Node3D) -> void:
	var actor := _clerk_actor(fisher)
	var toward := actor.global_position - _body.global_position
	toward.y = 0.0
	if toward.length_squared() > 0.0001:
		_heading = _heading_toward(toward)
		_face(_player, _heading)
	if _FISH.value() <= 0:
		_say_clerk(actor, _NO_FISH, 4.5)
		await get_tree().create_timer(4.5).timeout
		if not is_inside_tree():
			return
		_say_clerk(null, "", 0.0)
		_locked = false
		return
	_fish_open = true
	await _frame_fisherman(actor)
	if not is_inside_tree():
		return
	var panel := _SELL.new()
	panel.name = "FishSell"
	panel.set("toon_name", _player.name if _player != null else "Toon")
	_hud().add_child(panel)
	var reason := "cancel"
	if panel.has_signal("finished"):
		reason = await panel.finished
	if not is_inside_tree():
		return
	var line := _NO_FISH
	var hold := 4.5
	if reason == "sold":
		var result: Dictionary = _FISH.sell()
		if _book != null:
			_book.refresh_jar()
		var trophies := int(result.get("trophies", 0))
		if trophies > 0 and _loadout != null:
			_loadout.set_hp(_loadout.hp + trophies, _loadout.max_hp + trophies)
			_loadout.save()
			line = _TROPHY_FISH % [int(result.get("collected", 0)), int(result.get("total", 70))]
			hold = 5.5
		else:
			line = _THANKS_FISH
			hold = 3.5
	elif reason == "timeout":
		line = _FISH_SLOW
		hold = 2.4
	_fish_open = false
	_say_clerk(actor, line, hold)
	await get_tree().create_timer(hold).timeout
	if not is_inside_tree():
		return
	_say_clerk(null, "", 0.0)
	_locked = false


func _frame_fisherman(actor: Node3D) -> void:
	if _camera == null or actor == null:
		await get_tree().create_timer(1.0).timeout
		return
	var forward := _clerk_forward(actor)
	var right := Vector3.UP.cross(forward)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	var height := 3.0
	if actor is ToonActor:
		height = (actor as ToonActor).clamped_height()
	var at := actor.global_position - right * 5.0 + forward * 9.0 + Vector3(0.0, height - 0.5, 0.0)
	var look := actor.global_position + Vector3(0.0, height * 0.85, 0.0)
	var from := _camera.global_position
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_glide_fish_camera.bind(from, at, look), 0.0, 1.0, 1.0)
	await tween.finished


func _glide_fish_camera(weight: float, from: Vector3, at: Vector3, look: Vector3) -> void:
	if _camera == null:
		return
	_camera.global_position = from.lerp(at, weight)
	_camera.look_at(look, Vector3.UP)


func _try_clerk() -> void:
	if _body == null or not _PLACES.is_gag_shop(_scene_path()):
		_clerk_ready = true
		return
	var clerk := _nearest_clerk()
	if clerk == null:
		_clerk_ready = true
		return
	if _book != null and _book.is_open():
		_clerk_ready = false
		return
	if not _clerk_ready or _loadout == null:
		return
	_clerk_ready = false
	_locked = true
	_body.velocity = Vector3.ZERO
	if _player != null:
		_player.set_locomotion(0.0, false, false, 0.016)
	_shop_with(clerk)


func _try_officer() -> void:
	if _body == null or not _PLACES.is_toon_hq(_scene_path()) or _tasks == null:
		_officer_ready = true
		return
	var officer := _nearest_officer()
	if officer == null:
		_officer_ready = true
		return
	if _book != null and _book.is_open():
		_officer_ready = false
		return
	if _locked or not _officer_ready:
		return
	var card := _tasks.ready_hq()
	var offers := _tasks.offers()
	if card.is_empty() and offers.is_empty():
		return
	_officer_ready = false
	_locked = true
	_body.velocity = Vector3.ZERO
	if _player != null:
		_player.set_locomotion(0.0, false, false, 0.016)
	var actor := _clerk_actor(officer)
	if not card.is_empty():
		var laff := int(card.get("laff", 0))
		_tasks.turn_in(int(card.get("id", 0)))
		if laff > 0 and _loadout != null:
			_loadout.set_hp(_loadout.hp + laff, _loadout.max_hp + laff)
			_loadout.save()
		if _book != null:
			_book.refresh_tasks()
		_say_clerk(actor, "Nice work! Here is your reward...", 3.2)
		await get_tree().create_timer(3.2).timeout
		if not is_inside_tree():
			return
		_say_clerk(null, "", 0.0)
		offers = _tasks.offers()
	if offers.is_empty():
		_locked = false
		return
	# QuestMovieQuestChoice. The posters stay up until Choose, Cancel, or 20 seconds.
	_say_clerk(actor, "Choose a ToonTask.", 30.0)
	var panel := _QUEST_CHOICE.new() as QuestChoice
	panel.name = "QuestChoice"
	_hud().add_child(panel)
	panel.show_quests(offers)
	var picked: int = await panel.chosen
	if is_instance_valid(panel):
		panel.queue_free()
	_say_clerk(null, "", 0.0)
	if not is_inside_tree():
		return
	if picked != 0:
		_tasks.assign(picked)
		if _book != null:
			_book.refresh_tasks()
	else:
		_say_clerk(actor, "Come back later if you need a ToonTask! Bye!", 3.2)
		await get_tree().create_timer(3.2).timeout
		if not is_inside_tree():
			return
		_say_clerk(null, "", 0.0)
	_locked = false


func _try_quest_npc() -> void:
	if _body == null or _tasks == null:
		_npc_ready = true
		return
	var path := _scene_path()
	if not (_PLACES.is_toon_hall(path) or _PLACES.is_library(path) or _PLACES.is_shop(path)):
		_npc_ready = true
		return
	var npc := _nearest_quest_npc()
	if npc == null:
		_npc_ready = true
		return
	if _book != null and _book.is_open():
		_npc_ready = false
		return
	if _locked or not _npc_ready:
		return
	var npc_id := int(npc.get_meta("npc_id", 0))
	var card := _tasks.for_npc(npc_id)
	if card.is_empty():
		return
	_npc_ready = false
	_locked = true
	_body.velocity = Vector3.ZERO
	if _player != null:
		_player.set_locomotion(0.0, false, false, 0.016)
	var actor := _clerk_actor(npc)
	var toward := actor.global_position - _body.global_position
	toward.y = 0.0
	if toward.length_squared() > 0.0001:
		_heading = _heading_toward(toward)
		_face(_player, _heading)
	var quest_id := int(card.get("id", 0))
	if not bool(card.get("ready", false)):
		await _speak_pages(actor, _tasks.busy_pages(quest_id))
		_locked = false
		return
	if String(card.get("kind", "")) == "track":
		await _speak_pages(actor, _tasks.choice_pages(quest_id))
		if not is_inside_tree():
			return
		var panel := _TRACK_CHOICE.new()
		panel.name = "TrackChoice"
		_hud().add_child(panel)
		var track: int = await panel.chosen
		if is_instance_valid(panel):
			panel.queue_free()
		if not is_inside_tree():
			return
		if track < 0:
			_say_clerk(actor, "Come back when you have decided.", 3.0)
			await get_tree().create_timer(3.0).timeout
			if not is_inside_tree():
				return
			_say_clerk(null, "", 0.0)
			_locked = false
			return
		_tasks.choose_track(quest_id, track)
		if _book != null:
			_book.refresh_tasks()
		await _speak_pages(actor, _tasks.after_pages(quest_id))
		_locked = false
		return
	var given := _tasks.turn_in(quest_id, npc_id)
	if _book != null:
		_book.refresh_tasks()
	if given != 0:
		await _speak_pages(actor, _tasks.quest_pages(given))
	_locked = false


func _nearest_quest_npc() -> Node3D:
	var host := get_parent()
	if host == null or _body == null:
		return null
	var best: Node3D = null
	var best_gap := _CLERK_REACH
	for node in host.find_children("*", "StaticBody3D", true, false):
		if not node.has_meta("npc_id"):
			continue
		var body := node as Node3D
		var actor := _clerk_actor(body)
		var center := body.global_position + _clerk_forward(actor) * _CLERK_FORWARD
		var gap := Vector2(_body.global_position.x, _body.global_position.z).distance_to(Vector2(center.x, center.z))
		if gap < best_gap:
			best_gap = gap
			best = body
	return best


func _speak_pages(actor: Node3D, lines: PackedStringArray) -> void:
	for line in lines:
		if not is_inside_tree():
			return
		if line.is_empty():
			continue
		var hold := clampf(float(line.length()) * 0.05, 2.2, 6.5)
		_say_clerk(actor, line, hold)
		await get_tree().create_timer(hold).timeout
	if is_inside_tree():
		_say_clerk(null, "", 0.0)


func _nearest_officer() -> Node3D:
	var host := get_parent()
	if host == null or _body == null:
		return null
	var best: Node3D = null
	var best_gap := _CLERK_REACH
	for node in host.find_children("*", "StaticBody3D", true, false):
		if not String(node.name).begins_with("Officer"):
			continue
		var body := node as Node3D
		var actor := _clerk_actor(body)
		var center := body.global_position + _clerk_forward(actor) * _CLERK_FORWARD
		var gap := Vector2(_body.global_position.x, _body.global_position.z).distance_to(Vector2(center.x, center.z))
		if gap < best_gap:
			best_gap = gap
			best = body
	return best


func _nearest_clerk() -> Node3D:
	var host := get_parent()
	if host == null:
		return null
	var best: Node3D = null
	var best_gap := _CLERK_REACH
	for node in host.find_children("*", "StaticBody3D", true, false):
		if not String(node.name).begins_with("Clerk"):
			continue
		var body := node as Node3D
		var center := body.global_position + _clerk_forward(body) * _CLERK_FORWARD
		var offset := center - _body.global_position
		var gap := Vector2(offset.x, offset.z).length()
		if gap <= best_gap:
			best_gap = gap
			best = body
	return best


func _clerk_forward(clerk: Node3D) -> Vector3:
	var ahead := _clerk_actor(clerk).global_basis * Vector3(0, 1, 0)
	ahead.y = 0.0
	if ahead.length_squared() < 0.0001:
		return Vector3(0, 0, -1)
	return ahead.normalized()


func _clerk_actor(clerk: Node3D) -> Node3D:
	for child in clerk.get_children():
		if child is ToonActor:
			return child as Node3D
	return clerk


func _shop_with(clerk: Node3D) -> void:
	var actor := _clerk_actor(clerk)
	var toward := actor.global_position - _body.global_position
	toward.y = 0.0
	if toward.length_squared() > 0.0001:
		_heading = _heading_toward(toward)
		_face(_player, _heading)
	if _BEANS.pouch() <= 0:
		_say_clerk(actor, "You need to ride the Trolley to get some jellybeans.", 3.2)
		await get_tree().create_timer(3.2).timeout
		if not is_inside_tree():
			return
		_say_clerk(null, "", 0.0)
		_locked = false
		return
	_say_clerk(actor, "Choose what you want to buy.", 1.0)
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	_say_clerk(null, "", 0.0)
	var panel := _SHOP_GUI.new()
	panel.name = "GagShop"
	panel.loadout = _loadout
	_hud().add_child(panel)
	var reason: String = await panel.finished
	if not is_inside_tree():
		return
	if _book != null:
		_book.refresh_gags()
		_book.refresh_jar()
	if not is_instance_valid(actor):
		_locked = false
		return
	var goodbye := "See you later!"
	var hold := 2.0
	if reason == "timeout":
		goodbye = "Need more time to think?"
		hold = 2.4
	_say_clerk(actor, goodbye, hold)
	await get_tree().create_timer(hold).timeout
	if not is_inside_tree():
		return
	_say_clerk(null, "", 0.0)
	_locked = false


func _say_clerk(actor: Node3D, text: String, seconds: float) -> void:
	_clerk_mouth = actor
	_clerk_left = seconds
	if text.is_empty():
		if _clerk_line != null:
			_clerk_line.visible = false
		return
	if _clerk_line == null:
		_clerk_line = PanelContainer.new()
		_clerk_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_clerk_line.z_index = 16
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1, 1, 1, 0.98)
		box.border_color = Color(0.05, 0.05, 0.05)
		box.set_border_width_all(3)
		box.set_corner_radius_all(16)
		box.content_margin_left = 12
		box.content_margin_right = 16
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		_clerk_line.add_theme_stylebox_override("panel", box)
		_clerk_label = Label.new()
		_clerk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ToonGui.style_label(_clerk_label, Color(0.05, 0.05, 0.08), 22, Color(0, 0, 0, 0), 0)
		_clerk_line.add_child(_clerk_label)
		_hud().add_child(_clerk_line)
	ToonGui.show_speech(_clerk_label, text, 22)
	_clerk_line.visible = true
	ToonSpeech.speak(actor, text)


func _place_clerk_line(delta: float) -> void:
	if _clerk_line == null or _camera == null:
		return
	_clerk_left = maxf(_clerk_left - delta, 0.0)
	if _clerk_left <= 0.0 or _clerk_mouth == null or not is_instance_valid(_clerk_mouth):
		_clerk_line.visible = false
		return
	var point := _clerk_mouth.global_position + Vector3(0.0, 3.6, 0.0)
	var head := _find(_clerk_mouth, "def_head")
	if head:
		point = head.global_position + Vector3(0.0, 0.7, 0.0)
	if _camera.is_position_behind(point):
		_clerk_line.visible = false
		return
	_clerk_line.visible = true
	_clerk_line.reset_size()
	var screen := _camera.unproject_position(point)
	_clerk_line.position = screen - Vector2(_clerk_line.size.x * 0.5, _clerk_line.size.y + 8.0)


func _attach_jar() -> Node3D:
	var jar := Node3D.new()
	jar.name = "JellybeanJar"
	var packed := load(_JAR_MODEL) as PackedScene
	if packed != null:
		jar.add_child(packed.instantiate())
	var hand := _find(_player, "def_joint_right_hold")
	if hand == null:
		_player.add_child(jar)
	else:
		hand.add_child(jar)
	_jar_beans = _find_billboard(jar)
	_bean_rest = Basis.IDENTITY
	if _jar_beans != null:
		_bean_rest = _jar_beans.transform.basis
		if _jar_beans is MeshInstance3D:
			_show_both_sides(_jar_beans as MeshInstance3D)
	_set_jar_scale(jar, 0.0)
	return jar


func _set_jar_scale(jar: Node3D, amount: float) -> void:
	jar.transform = Transform3D(_JAR_XFORM.basis.scaled(Vector3.ONE * amount), _JAR_XFORM.origin)


## The beans are an axial billboard. Yaw that card toward the camera after the jar scale.
func _face_jar_beans(jar: Node3D) -> void:
	if _jar_beans == null or _camera == null or not is_instance_valid(_jar_beans):
		return
	if jar.scale.x < 0.02:
		return
	var parent := _jar_beans.get_parent() as Node3D
	if parent == null:
		return
	var rest := parent.global_transform.basis * _bean_rest
	var face := Vector3(-rest.y.x, 0.0, -rest.y.z)
	var to_target := _camera.global_position - _jar_beans.global_position
	to_target.y = 0.0
	if face.length() < 0.0001 or to_target.length() < 0.0001:
		return
	var turned := _jar_beans.global_transform
	turned.basis = rest.rotated(Vector3.UP, face.signed_angle_to(to_target, Vector3.UP))
	_jar_beans.global_transform = turned


func _find_billboard(root: Node) -> Node3D:
	if root is Node3D and String(root.name).contains("billboard"):
		return root as Node3D
	for child in root.get_children():
		var found := _find_billboard(child)
		if found != null:
			return found
	return null


func _show_both_sides(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return
	for index in mesh_instance.mesh.get_surface_count():
		var material := mesh_instance.mesh.surface_get_material(index)
		if material is BaseMaterial3D:
			var sided := (material as BaseMaterial3D).duplicate() as BaseMaterial3D
			sided.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh_instance.set_surface_override_material(index, sided)


func _ease_in_out(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	if c < 0.5:
		return 2.0 * c * c
	return -2.0 * c * c + 4.0 * c - 1.0


func _ease_out(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	return c * (2.0 - c)


func _ease_in(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	return c * c


func _try_house_door() -> void:
	if _player == null or _body == null:
		return
	var scene_path := _scene_path()
	var inside := _PLACES.is_house(scene_path)
	if not inside and not _PLACES.is_estate(scene_path):
		return
	var slot := _estate_slot()
	var origin: Node3D
	var trigger := Vector3.ZERO
	if inside:
		origin = _DOORS.find_origin(get_parent())
		if origin == null:
			return
		trigger = _DOORS.inside_trigger(origin)
	else:
		var house := _DOORS.find_house(get_parent(), slot)
		if house == null:
			return
		origin = _DOORS.find_anchor(house)
		if origin == null:
			return
		trigger = _DOORS.outside_trigger(house, origin)
	var here := Vector2(_body.global_position.x, _body.global_position.z)
	var reach := _DOORS.OUTSIDE_REACH if not inside else 2.0
	var near := here.distance_to(Vector2(trigger.x, trigger.z)) <= reach
	if not near:
		_door_ready = true
		return
	if not _door_ready or not _KEYS.held("forward"):
		return
	_door_ready = false
	if inside:
		_leave_house(slot)
	else:
		_enter_house(slot)


func _try_gag_door() -> void:
	if _player == null or _body == null:
		return
	var scene_path := _scene_path()
	var inside := _PLACES.is_gag_shop(scene_path)
	var trigger := Vector3.ZERO
	var reach := 2.8
	if inside:
		var origin := _DOORS.find_origin(get_parent())
		if origin == null:
			return
		# The round door is the doorway. Standing against it is close enough.
		trigger = origin.global_position
	else:
		if not _gag_sought:
			_gag_sought = true
			_gag_building = _SHOP.find_building(get_parent())
			if _gag_building != null:
				_gag_door = _SHOP.find_exterior_door(_gag_building)
		elif _gag_building != null and not is_instance_valid(_gag_building):
			_gag_sought = false
			return
		if _gag_building == null or _gag_door == null or not is_instance_valid(_gag_door):
			return
		trigger = _SHOP.outside_trigger(_gag_building, _gag_door)
		reach = 2.4
	var here := Vector2(_body.global_position.x, _body.global_position.z)
	if here.distance_to(Vector2(trigger.x, trigger.z)) > reach:
		_door_ready = true
		return
	if not _door_ready or not _KEYS.held("forward"):
		return
	_door_ready = false
	if inside:
		_leave_shop()
	else:
		_enter_shop()


func _enter_shop() -> void:
	_locked = true
	var building := _SHOP.find_building(get_parent())
	var door: Node3D = null
	if building != null:
		door = _SHOP.find_exterior_door(building)
	_SHOP.open(self, door)
	var goal := _body.global_position
	if building != null and door != null:
		goal = _into_door(_SHOP.enter_frame(building, door))
	await _walk_into_door(goal)
	_SHOP.hood = _hood
	_SHOP.trip = "in"
	ToonLoading.change_to(_PLACES.gag_shop_scene())


func _leave_shop() -> void:
	_locked = true
	_SHOP.open(self, _SHOP.find_interior_door(get_parent()))
	await _walk_into_door(_interior_door_goal(_DOORS.find_origin(get_parent())))
	_SHOP.trip = "out"
	ToonLoading.change_to(_PLACES.scene_for(_SHOP.hood))


func _try_pet_door() -> void:
	if _player == null or _body == null:
		return
	var scene_path := _scene_path()
	var inside := _PLACES.is_pet_shop(scene_path)
	var trigger := Vector3.ZERO
	var reach := 2.8
	if inside:
		var origin := _DOORS.find_origin(get_parent())
		if origin == null:
			return
		trigger = origin.global_position
	else:
		if not _pet_sought:
			_pet_sought = true
			_pet_building = _PET.find_building(get_parent())
			if _pet_building != null:
				_pet_door = _PET.find_exterior_door(_pet_building)
		elif _pet_building != null and not is_instance_valid(_pet_building):
			_pet_sought = false
			return
		if _pet_building == null or _pet_door == null or not is_instance_valid(_pet_door):
			return
		trigger = _PET.outside_trigger(_pet_building, _pet_door)
		reach = 2.4
	var here := Vector2(_body.global_position.x, _body.global_position.z)
	if here.distance_to(Vector2(trigger.x, trigger.z)) > reach:
		_pet_ready = true
		return
	if not _pet_ready or not _KEYS.held("forward"):
		return
	_pet_ready = false
	if inside:
		_leave_pet()
	else:
		_enter_pet()


func _enter_pet() -> void:
	_locked = true
	var building := _PET.find_building(get_parent())
	var door: Node3D = null
	if building != null:
		door = _PET.find_exterior_door(building)
	_PET.open(self, door)
	var goal := _body.global_position
	if building != null and door != null:
		goal = _into_door(_PET.enter_frame(building, door))
	await _walk_into_door(goal)
	_PET.hood = _hood
	_PET.trip = "in"
	ToonLoading.change_to(_PLACES.pet_shop_scene())


func _leave_pet() -> void:
	_locked = true
	_PET.open(self, _PET.find_interior_door(get_parent()))
	await _walk_into_door(_interior_door_goal(_DOORS.find_origin(get_parent())))
	_PET.trip = "out"
	ToonLoading.change_to(_PLACES.scene_for(_PET.hood))


func _pet_inside_drop() -> Dictionary:
	var origin := _DOORS.find_origin(get_parent())
	if origin == null:
		return {"point": Vector3(0.0, 0.05, 0.0), "heading": 0.0}
	var drop: Dictionary = _DOORS.inside_drop(origin)
	var point: Vector3 = drop["point"]
	return {"point": _shop_floor(point), "heading": float(drop["heading"])}


func _pet_outside_drop() -> Dictionary:
	var building := _PET.find_building(get_parent())
	if building == null:
		return {"point": _snap_drop(_PLACES.drop_for(_hood)), "heading": _PLACES.heading_for(_hood)}
	var door := _PET.find_exterior_door(building)
	if door == null:
		return {"point": _snap_drop(_PLACES.drop_for(_hood)), "heading": _PLACES.heading_for(_hood)}
	var drop: Dictionary = _PET.outside_drop(building, door)
	var point: Vector3 = drop["point"]
	return {"point": _shop_floor(point), "heading": float(drop["heading"])}


func _try_hall_door() -> void:
	if _player == null or _body == null:
		return
	var scene_path := _scene_path()
	var inside := _PLACES.is_toon_hall(scene_path)
	var trigger := Vector3.ZERO
	var reach := 2.8
	if inside:
		var origin := _DOORS.find_origin(get_parent())
		if origin == null:
			return
		trigger = origin.global_position
	else:
		if not _hall_sought:
			_hall_sought = true
			_hall_building = _HALL.find_building(get_parent())
			if _hall_building != null:
				_hall_door = _HALL.find_exterior_door(_hall_building)
		elif _hall_building != null and not is_instance_valid(_hall_building):
			_hall_sought = false
			return
		if _hall_building == null or _hall_door == null or not is_instance_valid(_hall_door):
			return
		trigger = _HALL.outside_trigger(_hall_building, _hall_door)
		reach = 2.4
	var here := Vector2(_body.global_position.x, _body.global_position.z)
	if here.distance_to(Vector2(trigger.x, trigger.z)) > reach:
		_hall_ready = true
		return
	if not _hall_ready or not _KEYS.held("forward"):
		return
	_hall_ready = false
	if inside:
		_leave_hall()
	else:
		_enter_hall()


func _enter_hall() -> void:
	_locked = true
	var building := _HALL.find_building(get_parent())
	var door: Node3D = null
	if building != null:
		door = _HALL.find_exterior_door(building)
	_HALL.open(self, door)
	var goal := _body.global_position
	if building != null and door != null:
		goal = _into_door(_HALL.enter_frame(building, door))
	await _walk_into_door(goal)
	_HALL.trip = "in"
	ToonLoading.change_to(_PLACES.toon_hall_scene())


func _leave_hall() -> void:
	_locked = true
	_HALL.open(self, _HALL.find_interior_door(get_parent()))
	await _walk_into_door(_interior_door_goal(_DOORS.find_origin(get_parent())))
	_HALL.trip = "out"
	ToonLoading.change_to(_PLACES.scene_for(_PLACES.TTC))


func _hall_inside_drop() -> Dictionary:
	var origin := _DOORS.find_origin(get_parent())
	if origin == null:
		return {"point": Vector3(0.0, 0.05, 0.0), "heading": 0.0}
	var drop: Dictionary = _DOORS.inside_drop(origin)
	var point: Vector3 = drop["point"]
	return {"point": _shop_floor(point), "heading": float(drop["heading"])}


func _settle_hall_exit() -> void:
	# The doorway depth is a physics ray. It is not ready on the first placement,
	# so that drop lands in the entrance. Wait until the front wall is known,
	# then stand on the sidewalk beyond it.
	for _i in 8:
		await get_tree().physics_frame
		var building := _HALL.find_building(get_parent())
		if building == null:
			return
		var door := _HALL.find_exterior_door(building)
		if door == null:
			return
		if not door.has_meta("hall_shell"):
			_HALL.outside_trigger(building, door)
			continue
		var drop := _hall_outside_drop()
		var point: Vector3 = drop["point"]
		_body.global_position = point
		_heading = float(drop["heading"])
		_home = point
		_home_heading = _heading
		if _player != null:
			_face(_player, _heading)
		_place_camera()
		return


func _hall_outside_drop() -> Dictionary:
	var building := _HALL.find_building(get_parent())
	if building == null:
		return {"point": _snap_drop(_PLACES.drop_for(_hood)), "heading": _PLACES.heading_for(_hood)}
	var door := _HALL.find_exterior_door(building)
	if door == null:
		return {"point": _snap_drop(_PLACES.drop_for(_hood)), "heading": _PLACES.heading_for(_hood)}
	var drop: Dictionary = _HALL.outside_drop(building, door)
	var point: Vector3 = drop["point"]
	return {"point": _shop_floor(point), "heading": float(drop["heading"])}


func _try_library_door() -> void:
	if _player == null or _body == null:
		return
	var scene_path := _scene_path()
	var inside := _PLACES.is_library(scene_path)
	var trigger := Vector3.ZERO
	var reach := 2.8
	if inside:
		var origin := _DOORS.find_origin(get_parent())
		if origin == null:
			return
		trigger = origin.global_position
	else:
		if not _lib_sought:
			_lib_sought = true
			_lib_building = _LIB.find_building(get_parent())
			if _lib_building != null:
				_lib_door = _LIB.find_exterior_door(_lib_building)
		elif _lib_building != null and not is_instance_valid(_lib_building):
			_lib_sought = false
			return
		if _lib_building == null or _lib_door == null or not is_instance_valid(_lib_door):
			return
		trigger = _LIB.outside_trigger(_lib_building, _lib_door)
		reach = 3.5
	var here := Vector2(_body.global_position.x, _body.global_position.z)
	if here.distance_to(Vector2(trigger.x, trigger.z)) > reach:
		_lib_ready = true
		return
	if not _lib_ready or not _KEYS.held("forward"):
		return
	_lib_ready = false
	if inside:
		_leave_library()
	else:
		_enter_library()


func _enter_library() -> void:
	_locked = true
	var building := _LIB.find_building(get_parent())
	var door: Node3D = null
	if building != null:
		door = _LIB.find_exterior_door(building)
	_LIB.open(self, door)
	var goal := _body.global_position
	if building != null and door != null:
		goal = _into_door(_LIB.enter_frame(building, door))
	await _walk_into_door(goal)
	_LIB.trip = "in"
	ToonLoading.change_to(_PLACES.library_scene())


func _leave_library() -> void:
	_locked = true
	_LIB.open(self, _LIB.find_interior_door(get_parent()))
	await _walk_into_door(_interior_door_goal(_DOORS.find_origin(get_parent())))
	_LIB.trip = "out"
	ToonLoading.change_to(_PLACES.scene_for(_PLACES.TTC))


func _library_inside_drop() -> Dictionary:
	var origin := _DOORS.find_origin(get_parent())
	if origin == null:
		return {"point": Vector3(0.0, 0.05, 0.0), "heading": 0.0}
	var drop: Dictionary = _DOORS.inside_drop(origin)
	var point: Vector3 = drop["point"]
	return {"point": _shop_floor(point), "heading": float(drop["heading"])}


func _settle_library_exit() -> void:
	for _i in 8:
		await get_tree().physics_frame
		var building := _LIB.find_building(get_parent())
		if building == null:
			return
		var door := _LIB.find_exterior_door(building)
		if door == null:
			return
		if not door.has_meta("hall_shell"):
			_LIB.outside_trigger(building, door)
			continue
		var drop := _library_outside_drop()
		var point: Vector3 = drop["point"]
		_body.global_position = point
		_heading = float(drop["heading"])
		_home = point
		_home_heading = _heading
		if _player != null:
			_face(_player, _heading)
		_place_camera()
		return


func _library_outside_drop() -> Dictionary:
	var building := _LIB.find_building(get_parent())
	if building == null:
		return {"point": _snap_drop(_PLACES.drop_for(_hood)), "heading": _PLACES.heading_for(_hood)}
	var door := _LIB.find_exterior_door(building)
	if door == null:
		return {"point": _snap_drop(_PLACES.drop_for(_hood)), "heading": _PLACES.heading_for(_hood)}
	var drop: Dictionary = _LIB.outside_drop(building, door)
	var point: Vector3 = drop["point"]
	return {"point": _shop_floor(point), "heading": float(drop["heading"])}


func _try_teller_door() -> void:
	if _player == null or _body == null:
		return
	var scene_path := _scene_path()
	var inside := _PLACES.is_bank(scene_path)
	var trigger := Vector3.ZERO
	var reach := 2.8
	if inside:
		var origin := _DOORS.find_origin(get_parent())
		if origin == null:
			return
		trigger = origin.global_position
	else:
		if not _teller_sought:
			_teller_sought = true
			_teller_building = _TELLER.find_building(get_parent())
			if _teller_building != null:
				_teller_door = _TELLER.find_exterior_door(_teller_building)
		elif _teller_building != null and not is_instance_valid(_teller_building):
			_teller_sought = false
			return
		if _teller_building == null or _teller_door == null or not is_instance_valid(_teller_door):
			return
		trigger = _TELLER.outside_trigger(_teller_building, _teller_door)
		reach = 3.5
	var here := Vector2(_body.global_position.x, _body.global_position.z)
	if here.distance_to(Vector2(trigger.x, trigger.z)) > reach:
		_teller_ready = true
		return
	if not _teller_ready or not _KEYS.held("forward"):
		return
	_teller_ready = false
	if inside:
		_leave_bank()
	else:
		_enter_bank()


func _enter_bank() -> void:
	_locked = true
	var building := _TELLER.find_building(get_parent())
	var door: Node3D = null
	if building != null:
		door = _TELLER.find_exterior_door(building)
	_TELLER.open(self, door)
	var goal := _body.global_position
	if building != null and door != null:
		goal = _into_door(_TELLER.enter_frame(building, door))
	await _walk_into_door(goal)
	_TELLER.trip = "in"
	ToonLoading.change_to(_PLACES.bank_scene())


func _leave_bank() -> void:
	_locked = true
	_TELLER.open(self, _TELLER.find_interior_door(get_parent()))
	await _walk_into_door(_interior_door_goal(_DOORS.find_origin(get_parent())))
	_TELLER.trip = "out"
	ToonLoading.change_to(_PLACES.scene_for(_PLACES.TTC))


func _teller_inside_drop() -> Dictionary:
	var origin := _DOORS.find_origin(get_parent())
	if origin == null:
		return {"point": Vector3(0.0, 0.05, 0.0), "heading": 0.0}
	var drop: Dictionary = _DOORS.inside_drop(origin)
	var point: Vector3 = drop["point"]
	return {"point": _shop_floor(point), "heading": float(drop["heading"])}


func _settle_teller_exit() -> void:
	# The drop is measured from the slab, so it does not wait on a facade ray.
	await get_tree().physics_frame
	if _body == null:
		return
	var drop := _teller_outside_drop()
	var point: Vector3 = drop["point"]
	_body.global_position = point
	_heading = float(drop["heading"])
	_home = point
	_home_heading = _heading
	if _player != null:
		_face(_player, _heading)
	_place_camera()


func _teller_outside_drop() -> Dictionary:
	var building := _TELLER.find_building(get_parent())
	if building == null:
		return {"point": _snap_drop(_PLACES.drop_for(_hood)), "heading": _PLACES.heading_for(_hood)}
	var door := _TELLER.find_exterior_door(building)
	if door == null:
		return {"point": _snap_drop(_PLACES.drop_for(_hood)), "heading": _PLACES.heading_for(_hood)}
	var drop: Dictionary = _TELLER.outside_drop(building, door)
	var point: Vector3 = drop["point"]
	return {"point": _shop_floor(point), "heading": float(drop["heading"])}


func _try_hq_door() -> void:
	if _player == null or _body == null:
		return
	var scene_path := _scene_path()
	var inside := _PLACES.is_toon_hq(scene_path)
	var trigger := Vector3.ZERO
	var reach := 2.8
	var index := 0
	if inside:
		var nearest := 1000.0
		var found := false
		for door_index in 2:
			var origin := _HQ.find_interior_origin(get_parent(), door_index)
			if origin == null:
				continue
			var there := origin.global_position
			var distance := Vector2(_body.global_position.x, _body.global_position.z).distance_to(Vector2(there.x, there.z))
			if distance < nearest:
				nearest = distance
				trigger = there
				index = door_index
				found = true
		if not found:
			return
	else:
		if not _hq_sought:
			_hq_sought = true
			_hq_building = _HQ.find_building(get_parent())
		elif _hq_building != null and not is_instance_valid(_hq_building):
			_hq_sought = false
			return
		if _hq_building == null:
			return
		var nearest := 1000.0
		var found := false
		for door_index in 2:
			if _HQ.find_exterior_door(_hq_building, door_index) == null:
				continue
			var there := _HQ.outside_trigger(_hq_building, door_index)
			var distance := Vector2(_body.global_position.x, _body.global_position.z).distance_to(Vector2(there.x, there.z))
			if distance < nearest:
				nearest = distance
				trigger = there
				index = door_index
				found = true
		if not found:
			return
		reach = 2.4
	var here := Vector2(_body.global_position.x, _body.global_position.z)
	if here.distance_to(Vector2(trigger.x, trigger.z)) > reach:
		_hq_ready = true
		return
	if not _hq_ready or not _KEYS.held("forward"):
		return
	_hq_ready = false
	if inside:
		_leave_hq(index)
	else:
		_enter_hq(index)


func _enter_hq(index: int) -> void:
	_locked = true
	var building := _HQ.find_building(get_parent())
	var door: Node3D = null
	if building != null:
		door = _HQ.find_exterior_door(building, index)
	_HQ.open(self, door)
	var goal := _body.global_position
	if building != null and door != null:
		goal = _into_door(_HQ.enter_frame(building, index))
	await _walk_into_door(goal)
	_HQ.return_scene = _scene_path()
	_HQ.zone_id = _HQ.zone_for(_HQ.return_scene)
	_HQ.door_index = index
	_HQ.trip = "in"
	ToonLoading.change_to(_PLACES.toon_hq_scene())


func _leave_hq(index: int) -> void:
	_locked = true
	_HQ.open(self, _HQ.find_interior_door(get_parent(), index))
	var goal := _body.global_position
	if _HQ.find_interior_origin(get_parent(), index) != null:
		goal = _HQ.interior_enter_point(get_parent(), index)
		goal.y = _body.global_position.y
	await _walk_into_door(goal)
	_HQ.door_index = index
	_HQ.trip = "out"
	var back := _HQ.return_scene
	if back.is_empty():
		back = _PLACES.scene_for(_PLACES.TTC)
	ToonLoading.change_to(back)


func _hq_inside_drop() -> Dictionary:
	var drop: Dictionary = _HQ.inside_drop(get_parent(), _HQ.door_index)
	var point: Vector3 = drop["point"]
	return {"point": _shop_floor(point), "heading": float(drop["heading"])}


func _hq_outside_drop() -> Dictionary:
	var building := _HQ.find_building(get_parent())
	if building == null:
		return {"point": _snap_drop(_PLACES.drop_for(_hood)), "heading": _PLACES.heading_for(_hood)}
	var drop: Dictionary = _HQ.outside_drop(building, _HQ.door_index)
	var point: Vector3 = drop["point"]
	return {"point": _shop_floor(point), "heading": float(drop["heading"])}


func _settle_hq_exit() -> void:
	await get_tree().physics_frame
	var drop := _hq_outside_drop()
	var point: Vector3 = drop["point"]
	_body.global_position = point
	_heading = float(drop["heading"])
	_home = point
	_home_heading = _heading
	if _player != null:
		_face(_player, _heading)
	_place_camera()


func _shop_inside_drop() -> Dictionary:
	var origin := _DOORS.find_origin(get_parent())
	if origin == null:
		return {"point": Vector3(0.0, 0.05, 0.0), "heading": 0.0}
	var drop: Dictionary = _DOORS.inside_drop(origin)
	var point: Vector3 = drop["point"]
	return {"point": _shop_floor(point), "heading": float(drop["heading"])}


func _shop_outside_drop() -> Dictionary:
	var building := _SHOP.find_building(get_parent())
	if building == null:
		return {"point": _snap_drop(_PLACES.drop_for(_hood)), "heading": _PLACES.heading_for(_hood)}
	var door := _SHOP.find_exterior_door(building)
	if door == null:
		return {"point": _snap_drop(_PLACES.drop_for(_hood)), "heading": _PLACES.heading_for(_hood)}
	var drop: Dictionary = _SHOP.outside_drop(building, door)
	var point: Vector3 = drop["point"]
	return {"point": _shop_floor(point), "heading": float(drop["heading"])}


func _shop_floor(point: Vector3) -> Vector3:
	# A tall ray lands on the awning or the shop ceiling. Start just overhead.
	var parent := get_parent() as Node3D
	if parent == null:
		return point
	var world := parent.get_world_3d()
	if world == null:
		return point
	var query := PhysicsRayQueryParameters3D.create(point + Vector3(0.0, 2.0, 0.0), point + Vector3(0.0, -6.0, 0.0))
	query.collide_with_areas = false
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return point
	var landed: Vector3 = hit["position"]
	if landed.y > point.y + 1.2:
		return point
	landed.y += 0.05
	return landed


func _try_building_door() -> void:
	if _player == null or _body == null:
		return
	var scene_path := _scene_path()
	var inside := _PLACES.is_shop(scene_path)
	var trigger := Vector3.ZERO
	var reach := 2.2
	# closest() is the door panel. A second circle around the sidewalk point
	# would open the door from the street again.
	var at_door := false
	if inside:
		var origin := _DOORS.find_origin(get_parent())
		if origin == null:
			return
		trigger = _DOORS.inside_trigger(origin)
	else:
		if _BLDG.street_zone(scene_path) == 0:
			return
		var near: Dictionary = _BLDG.closest(_body.global_position)
		if near.is_empty():
			_bldg_ready = true
			return
		at_door = true
	if not at_door:
		var here := Vector2(_body.global_position.x, _body.global_position.z)
		if here.distance_to(Vector2(trigger.x, trigger.z)) > reach:
			_bldg_ready = true
			return
	if not _bldg_ready or not _KEYS.held("forward"):
		return
	_bldg_ready = false
	if inside:
		_leave_building()
	else:
		_enter_building()


func _enter_building() -> void:
	_locked = true
	var near: Dictionary = _BLDG.closest(_body.global_position)
	if near.is_empty():
		_locked = false
		return
	var building: Node3D = near["building"]
	var door: Node3D = near["door"]
	var zone_id := _BLDG.interior_zone(building)
	var street_path := _scene_path()
	_BLDG.open(self, door)
	await _walk_into_door(_into_door(_BLDG.enter_frame(building, door)))
	if zone_id == 0:
		_locked = false
		_lift_blackout()
		return
	_BLDG.remember(zone_id, street_path)
	_BLDG.trip = "in"
	ToonLoading.change_to(_PLACES.shop_scene())


func _leave_building() -> void:
	_locked = true
	_DOORS.open(self, _DOORS.find_door(get_parent()))
	await _walk_into_door(_interior_door_goal(_DOORS.find_origin(get_parent())))
	_BLDG.trip = "out"
	var back := _BLDG.street
	if back.is_empty():
		back = _PLACES.scene_for(_PLACES.TTC)
	ToonLoading.change_to(back)


func _building_inside_drop() -> Dictionary:
	var origin := _DOORS.find_origin(get_parent())
	if origin == null:
		return {"point": Vector3(0.0, 0.05, 0.0), "heading": 0.0}
	var drop: Dictionary = _DOORS.inside_drop(origin)
	var point: Vector3 = drop["point"]
	return {"point": _shop_floor(point), "heading": float(drop["heading"])}


func _building_outside_drop() -> Dictionary:
	var building := _BLDG.find_for_zone(_BLDG.zone)
	if building == null:
		return {"point": Vector3.ZERO, "heading": 0.0}
	var door := _BLDG.find_exterior_door(building)
	if door == null:
		return {"point": Vector3.ZERO, "heading": 0.0}
	var drop: Dictionary = _BLDG.outside_drop(building, door)
	var point: Vector3 = drop["point"]
	return {"point": _shop_floor(point), "heading": float(drop["heading"])}


func _enter_house(slot: int) -> void:
	_locked = true
	var house := _DOORS.find_house(get_parent(), slot)
	var door := _DOORS.find_door(house if house != null else get_parent())
	if door == null and house != null:
		door = _DOORS.find_anchor(house)
	_DOORS.open(self, door)
	var goal := _body.global_position
	if house != null and door != null:
		var anchor := _DOORS.find_anchor(house)
		if anchor != null:
			goal = _into_door(_DOORS.enter_frame(house, anchor))
	await _walk_into_door(goal)
	door_trip = "in"
	ToonLoading.change_to(_PLACES.house_scene(slot))


func _leave_house(slot: int) -> void:
	_locked = true
	_DOORS.open(self, _DOORS.find_door(get_parent()))
	await _walk_into_door(_interior_door_goal(_DOORS.find_origin(get_parent())))
	door_trip = "out"
	ToonLoading.change_to(_PLACES.estate_scene(slot))


## DistributedDoor.avatarEnterDoorTrack. Walk loops for one second while the
## toon eases through the doorway. The iris starts halfway through that step.
func _walk_into_door(goal: Vector3) -> void:
	if _player == null or _body == null:
		await _fade_black()
		return
	var duration := 1.0
	var start := _body.global_position
	var flat := goal - start
	flat.y = 0.0
	if flat.length_squared() > 0.04:
		_heading = rad_to_deg(atan2(-flat.x, -flat.z))
		_face(_player, _heading)
	_body.velocity = Vector3.ZERO
	var clock := 0.0
	var cover: ColorRect
	while clock < duration:
		var delta := minf(get_process_delta_time(), 0.05)
		if delta <= 0.0:
			delta = 0.016
		clock += delta
		var next := start.lerp(goal, _ease_in(clampf(clock / duration, 0.0, 1.0)))
		next.y = start.y
		_body.global_position = next
		# setAnimState('walk') is the walk cycle, below the run cutoff.
		_player.set_locomotion(4.0, false, false, delta)
		if _remotes != null:
			_remotes.note(_heading, 4.0, false, false, false)
		# The iris follows this clock. A separate tween runs on real time, so a
		# hitch finishes it early and the scene change waits on a signal that
		# already fired. The screen stays black and the building never loads.
		if clock >= duration * 0.5:
			if cover == null:
				cover = _blackout()
			cover.color.a = clampf((clock - duration * 0.5) / (duration * 0.5), 0.0, 1.0)
		await get_tree().process_frame
	_player.set_locomotion(0.0, false, false, 0.0)
	if _remotes != null:
		_remotes.note(_heading, 0.0, false, false, false)
	if cover == null:
		cover = _blackout()
	cover.color.a = 1.0


## doorX is 1.5 and the enter point sits two units through the doorway.
func _into_door(frame: Dictionary) -> Vector3:
	var mouth: Vector3 = frame.get("mouth", _body.global_position)
	var outward: Vector3 = frame.get("outward", Vector3.ZERO)
	outward.y = 0.0
	if outward.length_squared() < 0.0001:
		outward = Vector3(0.0, 0.0, 1.0)
	else:
		outward = outward.normalized()
	var side := Vector3.UP.cross(outward)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	else:
		side = side.normalized()
	var point := mouth - outward * 2.0 + side * 1.5
	point.y = _body.global_position.y
	return point


func _interior_door_goal(origin: Node3D) -> Vector3:
	if origin == null or _body == null:
		return _body.global_position if _body != null else Vector3.ZERO
	var point := _DOORS.interior_enter_point(origin)
	point.y = _body.global_position.y
	return point


func _lift_blackout() -> void:
	var fade := _hud().get_node_or_null("TunnelFade") as ColorRect
	if fade == null:
		return
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 0.25)


func _fade_black() -> void:
	var fade := _blackout()
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.45)
	await tween.finished


func _estate_drop() -> Dictionary:
	# Estate._teleportToHouse stands the toon at setPosHpr(house, 17, 3, 0, 125, 0, 0).
	var slot := 0
	var host := get_parent()
	if host != null and "estate_slot" in host:
		slot = clampi(int(host.get("estate_slot")), 0, 5)
	var house := _find_house(host, "esHouse_%d" % slot)
	var heading := _ESTATE_HEADING[slot] + 125.0
	if house == null:
		return {"point": _snap_drop(Vector3(23.875, 10.44, 13.052)), "heading": 7.52}
	var point := house.to_global(Vector3(17.0, 3.0, 0.0))
	return {"point": _snap_drop(point), "heading": heading}


func _find_house(node: Node, wanted: String) -> Node3D:
	if node == null:
		return null
	if str(node.name) == wanted and node is Node3D:
		return node as Node3D
	for child in node.get_children():
		var found := _find_house(child, wanted)
		if found != null:
			return found
	return null


func _view_drop() -> Dictionary:
	var fly := get_parent().get_node_or_null("Camera") as Camera3D
	var point := Vector3(0.0, 0.35, 0.0)
	var heading := 0.0
	if fly == null:
		return {"point": point, "heading": heading}
	var look := -fly.global_basis.z
	look.y = 0.0
	if look.length_squared() > 0.0001:
		look = look.normalized()
		heading = rad_to_deg(atan2(-look.x, -look.z))
		point = fly.global_position + look * 8.0
	else:
		point = fly.global_position
	point.y = fly.global_position.y
	return {"point": _snap_drop(point), "heading": heading}


func _snap_drop(drop: Vector3) -> Vector3:
	var parent := get_parent() as Node3D
	if parent == null:
		return drop
	var world := parent.get_world_3d()
	if world == null:
		return drop
	# A roof above the authored height is not the floor. The central gazebo
	# drop points stand on its platform, and a ray from overhead hits the roof first.
	var ceiling := drop.y + 2.0
	var from := drop + Vector3(0.0, 30.0, 0.0)
	var to := drop + Vector3(0.0, -40.0, 0.0)
	var steps := 0
	while steps < 6:
		steps += 1
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collide_with_areas = false
		var hit := world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return drop
		var landed: Vector3 = hit["position"]
		if landed.y <= ceiling:
			landed.y += 0.05
			return landed
		from = landed + Vector3(0.0, -0.15, 0.0)
		if from.y <= to.y:
			return drop
	return drop


func _spawn(underground: bool) -> void:
	var style := ToonRoster.selected_style()
	_body = CharacterBody3D.new()
	_body.name = "Player"
	_body.floor_snap_length = 0.6
	# Plaza stair faces run to about 54 degrees. Steeper than that stays a wall.
	_body.floor_max_angle = deg_to_rad(58.0)
	# A steep walkable face should not eat forward speed. GravityWalker keeps
	# the same pace and lets the floor ray take the height.
	_body.floor_constant_speed = true
	_body.floor_block_on_wall = false
	_body.safe_margin = 0.04
	_body.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	_body.up_direction = Vector3.UP
	var spot: Dictionary = _arrival_spot()
	var point: Vector3 = spot["point"]
	_heading = float(spot["heading"])
	_home = point
	_home_heading = _heading
	_body.position = point
	get_parent().add_child(_body)
	_player = ToonActor.new()
	_player.name = "Toon" if style == null else style.display_name()
	_body.add_child(_player)
	if style:
		_CLOSET.dress(style)
		_player.show_style(style)
		_player.wear_accessories(_CLOSET.accessory_ids())
	# The standing pose is only intact until the first step. Loading the clips
	# then is the hitch a moment after the hole closes, so load them now.
	_player.set_locomotion(0.0, false, false, 0.0)
	_player.set_meta("av", ToonRoster.avatar_id())
	_player.footsteps = true
	_face(_player, _heading)
	_add_capsule()
	_camera = Camera3D.new()
	_camera.name = "ToonCamera"
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = 52.0
	_camera.far = 4000.0
	_camera.current = true
	get_parent().add_child(_camera)
	_cache_eye_height()
	_add_world_tags(style)
	_remotes = RemoteToons.new()
	_remotes.name = "RemoteToons"
	add_child(_remotes)
	_remotes.bind(get_parent(), _body, _player, _nametags)
	if underground:
		_player.visible = false


func _pop_up() -> void:
	var pivot := Node3D.new()
	pivot.name = "HolePivot"
	_body.add_child(pivot)
	pivot.position = Vector3(0.0, -1.15, 0.0)
	pivot.scale = Vector3(0.12, 0.12, 0.12)
	# Keep the toon's own scale. Matching the world size against a 0.12 pivot
	# would multiply them by about eight as the hole opens.
	_player.reparent(pivot, false)
	_player.position = Vector3.ZERO
	_player.visible = true
	var hole := _hole()
	_body.add_child(hole)
	_place_camera()
	var risen := create_tween()
	risen.set_parallel(true)
	risen.tween_property(pivot, "position:y", 0.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	risen.tween_property(pivot, "scale", Vector3.ONE, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	risen.tween_property(hole, "scale", Vector3(1.0, 1.0, 1.0), 0.35)
	await risen.finished
	var shut := create_tween()
	shut.tween_property(hole, "scale", Vector3(0.05, 1.0, 0.05), 0.25)
	await shut.finished
	_player.reparent(_body, false)
	_player.position = Vector3.ZERO
	_face(_player, _heading)
	pivot.queue_free()
	hole.queue_free()
	_cache_eye_height()


## MapPage teleports throw the hole, then jump in. The scene changes when the
## track finishes, and the next place plays the jump back out.
func teleport_to_hood(hood: int, remember := true) -> void:
	if _is_sad():
		return
	if not await _play_teleport_out():
		return
	portal_in = true
	teleport_in = true
	keep_last_hood = not remember
	if remember and _tasks != null:
		_tasks.note_hood(hood)
	ToonLoading.change_to(_PLACES.scene_for(hood))


## DeathForceAcknowledge. The laff meter sits on the left of the card at 0.
func _death_ack() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	_hud().add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var frame := TextureRect.new()
	frame.texture = _DIALOG
	frame.modulate = Color(1, 1, 0.75, 1)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	var message := Label.new()
	message.text = _DEATH_ACK
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(message)
	var button := TextureButton.new()
	button.texture_normal = _OK_UP
	button.texture_pressed = _OK_DOWN
	button.texture_hover = _OK_HOVER
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	ToonGui.button_sounds(button)
	root.add_child(button)
	var meter := LaffMeter.new()
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := ToonRoster.selected_style()
	if style == null:
		style = ToonStyle.new()
	meter.setup(style)
	var maximum := 1 if _loadout == null else _loadout.max_hp
	meter.set_hp(0, maximum)
	root.add_child(meter)
	var view := get_viewport().get_visible_rect().size
	ToonGui.place(frame, view, 0.0, 0.05, 2.2, 1.25)
	var px := maxi(int(round(0.055 * view.y * 0.5)), 1)
	ToonGui.style_label(message, Color(0.08, 0.08, 0.08), px, Color(0, 0, 0, 0), 0)
	ToonGui.place(message, view, 0.12, 0.12, 1.45, 0.7)
	ToonGui.place(button, view, 0.0, -0.38, 0.13, 0.13)
	var monkey := style.species() == "p"
	var meter_x := -0.46 if monkey else -0.48
	var meter_px := view.y * (0.085 if monkey else 0.1)
	meter.place(Vector2(view.x * 0.5 + meter_x * view.y * 0.5, view.y * 0.5 - (-0.035) * view.y * 0.5), meter_px)
	await button.pressed
	if is_instance_valid(layer):
		layer.queue_free()
## Here the next screen is Pick a Toon.
func quit_to_chooser() -> void:
	if not await _play_teleport_out():
		return
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud().add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 1.0)
	await tween.finished
	if not is_inside_tree():
		return
	ToonLoading.change_to(_PICK_SCENE)


func _play_teleport_out() -> bool:
	if _portaling or not _active or _player == null or _body == null:
		return false
	if _book != null:
		_book.close()
	_locked = true
	_filming = true
	_portaling = true
	_body.velocity = Vector3.ZERO
	_player.set_look_enabled(false)
	_show_shadow(false)
	var portal := _make_portal()
	var hand := _find(_player, "def_joint_right_hold")
	if hand == null:
		_player.add_child(portal)
	else:
		hand.add_child(portal)
	portal.transform = Transform3D.IDENTITY
	portal.call("pose_at", 0.0)
	var sounded := false
	var dropped := false
	var elapsed := 0.0
	while elapsed < _OUT_TIME:
		_player.set_hole_clip(true, _player.global_position.y)
		_player.pose_action("teleport", elapsed)
		portal.call("pose_at", elapsed)
		if elapsed >= _SOUND_AT and not sounded:
			sounded = true
			_play_teleport_sound()
		if elapsed >= _DROP_AT and not dropped:
			dropped = true
			# reparentTo keeps the local transform, so the hole leaves the hand
			# and sits on the toon. The portal clip then opens where the jump lands.
			portal.reparent(_player, false)
			portal.transform = Transform3D.IDENTITY
		_place_camera()
		await get_tree().process_frame
		if not is_inside_tree():
			return false
		elapsed += get_process_delta_time()
	if is_instance_valid(portal):
		portal.queue_free()
	_player.set_hole_clip(false, 0.0)
	return true


func _portal_in() -> void:
	if _player == null or _body == null:
		return
	_portaling = true
	_filming = true
	_locked = true
	_player.set_look_enabled(false)
	_show_shadow(false)
	_player.pose_action("teleport", _player.action_length("teleport"))
	var portal := _make_portal()
	_body.add_child(portal)
	portal.global_transform = _player.global_transform
	portal.global_position = _player.to_global(Vector3(0.0, -2.4, 0.0))
	portal.call("pose_at", _OUT_TIME)
	var leap := _player.action_length("leap")
	var total := _IN_OPEN + _IN_HOLD + _IN_OPEN
	if leap > _JUMP_FROM:
		total = maxf(total, _IN_OPEN + (leap - _JUMP_FROM))
	var elapsed := 0.0
	var shown := false
	while elapsed < total:
		portal.call("pose_at", _arrival_hole_time(elapsed))
		if elapsed >= _IN_OPEN and not shown:
			shown = true
			_player.visible = true
		if shown:
			_player.pose_action("leap", _JUMP_FROM + (elapsed - _IN_OPEN))
		_place_camera()
		await get_tree().process_frame
		if not is_inside_tree():
			return
		elapsed += get_process_delta_time()
	if is_instance_valid(portal):
		portal.queue_free()
	_player.end_action("leap")
	_player.end_action("teleport")
	_player.visible = true
	_player.set_look_enabled(true)
	_show_shadow(true)
	_face(_player, _heading)
	_portaling = false
	_filming = false
	_cache_eye_height()


func _arrival_hole_time(elapsed: float) -> float:
	if elapsed < _IN_OPEN:
		return lerpf(_OUT_TIME, 3.1, elapsed / _IN_OPEN)
	if elapsed < _IN_OPEN + _IN_HOLD:
		return 3.1
	var shut := clampf((elapsed - _IN_OPEN - _IN_HOLD) / _IN_OPEN, 0.0, 1.0)
	return lerpf(3.1, _OUT_TIME, shut)


func _make_portal() -> Node3D:
	var portal: Node3D = _PORTAL.new() as Node3D
	portal.name = "TeleportPortal"
	portal.call("setup")
	return portal


func _play_teleport_sound() -> void:
	var stream := load(_TELEPORT_SFX) as AudioStream
	if stream == null:
		return
	var player := ToonAudio.effect_player()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _show_shadow(shown: bool) -> void:
	if _player == null:
		return
	var shadow := _find(_player, "drop_shadow")
	if shadow != null:
		shadow.visible = shown


func _hole() -> MeshInstance3D:
	var hole := MeshInstance3D.new()
	hole.name = "ArrivalHole"
	var disc := CylinderMesh.new()
	disc.top_radius = 1.15
	disc.bottom_radius = 1.15
	disc.height = 0.08
	hole.mesh = disc
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.02, 0.02, 0.02)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.disable_receive_shadows = true
	hole.material_override = material
	hole.position = Vector3(0.0, 0.04, 0.0)
	hole.scale = Vector3(0.2, 1.0, 0.2)
	return hole


func _fade_in() -> void:
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud().add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 0.4)
	tween.finished.connect(fade.queue_free)


func _ready_hud() -> void:
	_loadout = ToonLoadout.for_selected()
	# Apply the district copy before either corner control is built. Doing it
	# between them left the book showing a journal the claim had already erased.
	ToonNet.claim_toon()
	_meter = LaffMeter.new()
	_meter.name = "LaffMeter"
	var style := ToonRoster.selected_style()
	if style:
		_meter.setup(style)
	else:
		_meter.setup(ToonStyle.new())
	_meter.follow(_loadout)
	_hud().add_child(_meter)
	_dock_laff()
	var view_port := get_viewport()
	if view_port != null and not view_port.size_changed.is_connected(_dock_laff):
		view_port.size_changed.connect(_dock_laff)
	_book = ShtickerBook.new()
	_book.name = "ShtickerBook"
	_hud().add_child(_book)
	_book.setup(_tasks, _loadout)
	# The open book covers the street map. The map stays above the laff meter.
	_book.z_index = 20
	var street_zone := _BLDG.street_zone(_scene_path())
	if street_zone != 0:
		# Loaded by path so the street script and the map script do not preload each other.
		var map_script := load("res://scenes/quests/quest_map.gd") as GDScript
		if map_script != null:
			_map = map_script.new() as Control
			_map.name = "QuestMap"
			_hud().add_child(_map)
			if not bool(_map.call("setup", _tasks, street_zone)):
				_map.queue_free()
				_map = null
	var chat := SpeedChat.new()
	chat.name = "SpeedChat"
	_hud().add_child(chat)
	chat.setup(_tasks)
	chat.phrase_said.connect(_on_phrase)
	var friends := FriendsList.new()
	friends.name = "FriendsList"
	_hud().add_child(friends)
	var avatar_panel := (load("res://scenes/toons/toon_avatar_panel.gd") as GDScript).new() as Control
	avatar_panel.name = "ToonAvatarPanel"
	_hud().add_child(avatar_panel)


func local_toon() -> ToonActor:
	return _player


func _leave_water() -> void:
	if _player != null:
		_player.set_swimming(false)


func _walk(delta: float) -> void:
	if _player == null or _body == null:
		return
	var forward_held := _KEYS.held("forward")
	var back_held := _KEYS.held("back")
	var left_held := _KEYS.held("left")
	var right_held := _KEYS.held("right")
	var aim_held := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	# The book clips replace walking until the toon closes it.
	if _player != null and _player.holding_book():
		forward_held = false
		back_held = false
		left_held = false
		right_held = false
	# Right-click turns the side keys into a full run across the camera.
	if MagicWords.detached_camera():
		forward_held = false
		back_held = false
		left_held = false
		right_held = false
	var strafe := 0.0
	if aim_held and not forward_held and not back_held:
		if left_held:
			strafe += 1.0
		if right_held:
			strafe -= 1.0
	var turn := 0.0
	if strafe == 0.0:
		if left_held:
			turn += 1.0
		if right_held:
			turn -= 1.0
	_heading += turn * TURN_SPEED * delta
	var speed := 0.0
	var turning := turn != 0.0
	var running := forward_held and not back_held
	var reversing := back_held and not forward_held
	# A right-click orbit made while standing is the new forward or back.
	# Adopt it on the first step, without waiting for another drag.
	if (running and not _running) or (reversing and not _reversing):
		_adopt_right_aim()
	_running = running
	_reversing = reversing
	var move_heading := _heading
	var face_heading := _heading
	if strafe != 0.0:
		move_heading = _heading + _cam_yaw + 90.0 * strafe
		face_heading = move_heading
		speed = FORWARD_SPEED
	elif running:
		speed = FORWARD_SPEED
	elif reversing:
		speed = -REVERSE_SPEED
	speed *= MagicWords.run_scale()
	var forward := _forward(move_heading)
	_body.velocity.x = forward.x * speed
	_body.velocity.z = forward.z * speed
	var on_floor := _body.is_on_floor()
	var jumped := false
	var impact := _body.velocity.y
	if on_floor:
		if _jump_lock > 0.0:
			_jump_lock = maxf(_jump_lock - delta, 0.0)
		if not _is_sad() and not _player.holding_book() and _KEYS.held("jump") and _jump_lock <= 0.0:
			_body.velocity.y = JUMP_FORCE
			jumped = true
			_jumping = true
		else:
			_body.velocity.y = -2.0
			_jumping = false
	else:
		_body.velocity.y -= GRAVITY * delta
		impact = _body.velocity.y
	if not jumped and (on_floor or (_body.is_on_wall() and _body.velocity.y <= 1.0)):
		_raise_onto_step()
	_body.floor_snap_length = 0.0 if _body.velocity.y > 0.0 else 0.6
	_body.move_and_slide()
	# The pond bed sits lower than a high spawn. Standing there, or jumping
	# in the water, is not a fall out of the world. Only a real drop with no
	# floor sends the toon home.
	var fallen := _body.position.y < _home.y - 8.0 and not _body.is_on_floor() and not MagicWords.noclip()
	if fallen:
		_void_time += delta
	else:
		_void_time = 0.0
	if _void_time > 0.85:
		_void_time = 0.0
		_body.velocity = Vector3.ZERO
		_body.position = _home
		_heading = _home_heading
		_jumping = false
	elif not on_floor and _body.is_on_floor() and not jumped:
		_jumping = false
		if impact < HARD_LAND:
			_player.hard_land()
			_jump_lock = HARD_LOCK
		elif impact < -5.0:
			_jump_lock = JUMP_LOCK
	_face(_player, face_heading)
	_player.set_sad(_is_sad())
	_player.set_swimming(_player.under_water())
	_player.set_locomotion(speed, turning, _jumping or jumped, delta)
	if _remotes != null:
		_remotes.note(face_heading, speed, turning, _jumping or jumped, not _player.visible)


func _place_camera() -> void:
	if _camera == null or _player == null:
		return
	# LocalAvatar camera 0 sits at the clamped toon height and 3 heights
	# behind, looking level. A drag rides that same sphere, so the default
	# view grows with a tall toon and stays put for a short one.
	var feet := _player.global_position
	var orbit := _heading + _cam_yaw
	var forward := _forward(orbit)
	var target := feet + Vector3(0.0, _eye_height, 0.0)
	var distance := 9.0 * (_eye_height / 3.0) * _cam_distance
	var pitch := deg_to_rad(_cam_pitch)
	var horizontal := distance * cos(pitch)
	_camera.global_position = target - forward * horizontal + Vector3(0.0, distance * sin(pitch), 0.0)
	if _camera.global_position.distance_squared_to(target) > 0.04:
		_camera.look_at(target, Vector3.UP)


func _steer_camera(event: InputEvent) -> void:
	if _locked or _filming or _portaling or _bank_open or _battle_hold or (_book != null and _book.is_open()):
		_release_camera_mouse(true)
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		var drag := button.button_index == MOUSE_BUTTON_LEFT or button.button_index == MOUSE_BUTTON_RIGHT
		if drag and button.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif drag:
			_release_camera_mouse()
		if not button.pressed:
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_distance = maxf(_CAM_DIST_MIN, _cam_distance - 0.14)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_distance = minf(_CAM_DIST_MAX, _cam_distance + 0.14)
		elif button.button_index == MOUSE_BUTTON_MIDDLE:
			_cam_yaw = 0.0
			_right_yaw = 0.0
			_cam_pitch = _CAM_PITCH_HOME
			_cam_distance = 1.0
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var left := (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		var right := (motion.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0
		if not left and not right:
			return
		var yaw := -motion.relative.x * 0.18
		# Down looks down. The camera climbs the sphere and stays aimed at the toon.
		_cam_pitch = clampf(_cam_pitch + motion.relative.y * 0.1, _CAM_PITCH_MIN, _CAM_PITCH_MAX)
		var steering := _KEYS.held("forward") or _KEYS.held("back")
		if right and steering:
			# Forward and back keep the camera behind the toon and follow the drag.
			if not _cam_steering:
				_heading += _cam_yaw
				_cam_yaw = 0.0
				_cam_steering = true
			_heading += yaw
			_right_yaw = 0.0
		else:
			_cam_steering = false
			_cam_yaw += yaw
			if right:
				_right_yaw += yaw


func _adopt_right_aim() -> void:
	if absf(_right_yaw) < 0.01:
		return
	_heading += _right_yaw
	_cam_yaw -= _right_yaw
	_right_yaw = 0.0


func _release_camera_mouse(force := false) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if not force and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _place_nametag() -> void:
	if _nametags == null or _camera == null:
		return
	_nametags.camera = _camera
	_nametags.place()
	if _margins != null:
		var people: Array = _nametags.cards()
		var host := get_parent()
		if host != null:
			var suits := host.get_node_or_null("StreetSuits")
			if suits != null:
				var board := suits.get_node_or_null("Nametags")
				if board != null and board.has_method("cards"):
					var extra: Variant = board.call("cards")
					if extra is Array:
						people.append_array(extra)
		_margins.call("place", _camera, host, people)


## The local toon, plus any clerk already standing in this area.
func _add_world_tags(style: ToonStyle) -> void:
	_nametags = Nametags.new()
	_nametags.name = "Nametags"
	add_child(_nametags)
	_nametags.camera = _camera
	_nametags.layer = _hud()
	_margins = _MARGINS.new()
	_margins.name = "MarginTags"
	add_child(_margins)
	_margins.call("setup", _hud())
	var spoken := "Toon" if style == null else style.display_name()
	_nametags.add(_player, spoken, "player")
	var host := get_parent()
	if host == null:
		return
	for node in host.find_children("*", "ToonActor", true, false):
		var actor := node as ToonActor
		if actor == null or actor == _player or is_ancestor_of(actor):
			continue
		_nametags.add(actor, String(actor.name), "npc")


func _place_line(delta: float) -> void:
	_place_nametag()
	_place_clerk_line(delta)
	if _line == null or _camera == null or _player == null:
		return
	_line_left = maxf(_line_left - delta, 0.0)
	if _line_left <= 0.0 or not _player.visible or (_book != null and _book.is_open()):
		_line.visible = false
		return
	var point := _player.global_position + Vector3(0.0, 3.6, 0.0)
	var head := _find(_player, "def_head")
	if head:
		point = head.global_position + Vector3(0.0, 0.7, 0.0)
	if _camera.is_position_behind(point):
		_line.visible = false
		return
	_line.visible = true
	_line.reset_size()
	var screen := _camera.unproject_position(point)
	_line.position = screen - Vector2(_line.size.x * 0.5, _line.size.y + 8.0)
	var view := _camera.get_viewport().get_visible_rect()
	var margin := 8.0
	_line.position.x = clampf(_line.position.x, view.position.x + margin, maxf(view.position.x + margin, view.end.x - _line.size.x - margin))
	_line.position.y = clampf(_line.position.y, view.position.y + margin, maxf(view.position.y + margin, view.end.y - _line.size.y - margin))


func _add_capsule() -> void:
	var height := 3.0
	var head := _find(_player, "def_head")
	if head:
		height = maxf(head.global_position.y - _body.global_position.y + 0.5, 2.4)
	var shape := CapsuleShape3D.new()
	shape.radius = BODY_RADIUS
	shape.height = maxf(height, shape.radius * 2.0 + 0.2)
	var collision := CollisionShape3D.new()
	collision.name = "BodyCapsule"
	collision.shape = shape
	collision.position = Vector3(0.0, shape.height * 0.5, 0.0)
	_body.add_child(collision)


## A curb or stair lip is not a floor. Lift onto the flat surface past it.
## The old ankle test missed a beveled curb, whose face is not vertical.
func _raise_onto_step() -> void:
	var ahead := Vector3(_body.velocity.x, 0.0, _body.velocity.z)
	if ahead.length() < 0.2:
		return
	var world := _body.get_world_3d()
	if world == null:
		return
	var space := world.direct_space_state
	var dir := ahead.normalized()
	var feet := _body.global_position
	var exclude: Array[RID] = [_body.get_rid()]
	if not _ledge_ahead(space, feet, dir, exclude):
		return
	var rise := _tread_ahead(space, feet, dir, exclude)
	if rise < 0.05 or rise > STEP_HEIGHT:
		return
	var up := PhysicsTestMotionParameters3D.new()
	up.from = _body.global_transform
	up.motion = Vector3(0.0, rise + 0.04, 0.0)
	up.margin = _body.safe_margin
	up.recovery_as_collision = false
	var lifted := PhysicsTestMotionResult3D.new()
	# A riser graze is not a ceiling. Only a blocked rise cancels the step.
	if PhysicsServer3D.body_test_motion(_body.get_rid(), up, lifted) and lifted.get_travel().y < rise * 0.5:
		return
	var raised := _body.global_transform
	raised.origin.y += rise + 0.04
	var forward := PhysicsTestMotionParameters3D.new()
	forward.from = raised
	forward.motion = dir * 0.25
	forward.margin = _body.safe_margin
	if PhysicsServer3D.body_test_motion(_body.get_rid(), forward):
		return
	_body.global_position.y += rise
	_body.velocity.y = 0.0


func _ledge_ahead(space: PhysicsDirectSpaceState3D, feet: Vector3, dir: Vector3, exclude: Array[RID]) -> bool:
	# Steeper than floor_max_angle is a wall. A walkable stair slope is not.
	var limit := cos(_body.floor_max_angle)
	for height in PackedFloat32Array([0.12, 0.28, 0.46]):
		var from := feet + Vector3(0.0, height, 0.0)
		var query := PhysicsRayQueryParameters3D.create(from, from + dir * (BODY_RADIUS + 0.55))
		query.exclude = exclude
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit["normal"]
		if normal.y < limit:
			return true
	return false


func _tread_ahead(space: PhysicsDirectSpaceState3D, feet: Vector3, dir: Vector3, exclude: Array[RID]) -> float:
	# The nearest tread only. A farther sample can see the step after this one,
	# and taking the higher of the two made every stair after the first too tall.
	for reach in PackedFloat32Array([BODY_RADIUS + 0.08, BODY_RADIUS + 0.35, BODY_RADIUS + 0.7]):
		var origin := feet + Vector3(0.0, STEP_HEIGHT + 0.05, 0.0) + dir * reach
		var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3(0.0, -(STEP_HEIGHT + 0.25), 0.0))
		query.exclude = exclude
		query.collide_with_areas = false
		var tread := space.intersect_ray(query)
		if tread.is_empty():
			continue
		var normal: Vector3 = tread["normal"]
		if normal.y < 0.7:
			continue
		var point: Vector3 = tread["position"]
		var rise := point.y - feet.y
		if rise >= 0.05 and rise <= STEP_HEIGHT:
			return rise
	return -1.0


func _cache_eye_height() -> void:
	_eye_height = 3.0
	if _player == null:
		return
	_eye_height = _player.clamped_height()


func turn_toon(heading: float) -> void:
	# The follow camera orbits _heading. Turning in the wardrobe only changes
	# the pose, so the view stays where it was when the closet opened.
	if _player != null:
		_face(_player, heading)


func _hold_closet_camera() -> void:
	if _camera == null or not _closet_open:
		return
	_camera.top_level = true
	_camera.global_transform = _closet_cam


func _adopt_facing() -> void:
	if _player == null:
		return
	var forward := _player.transform.basis.orthonormalized().y
	_heading = rad_to_deg(atan2(forward.x, -forward.z))


func _face(actor: Node3D, heading: float) -> void:
	var body_scale := actor.transform.basis.get_scale().x
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	upright = upright.rotated(Vector3.UP, deg_to_rad(heading))
	actor.transform.basis = upright.scaled(Vector3.ONE * body_scale)


func _forward(heading: float) -> Vector3:
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	upright = upright.rotated(Vector3.UP, deg_to_rad(heading))
	return upright * Vector3(0, 1, 0)


func _dock_laff() -> void:
	if _meter == null:
		return
	_meter.dock(get_viewport().get_visible_rect().size)


func _hud() -> CanvasLayer:
	var layer := get_node_or_null("Hud") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "Hud"
		add_child(layer)
	return layer


## LocalToon.tunnelOut plays getTunnelOutToonTrack, then Place loads the
## other zone with how = tunnelIn. +Y of tunnel_origin points out of the shaft.
func _try_tunnel() -> void:
	if _filming or _body == null:
		return
	var best := -1
	var best_gap := 20.0
	for i in _tunnels.size():
		var entry: Dictionary = _tunnels[i]
		var origin: Node3D = entry["origin"]
		if not is_instance_valid(origin):
			continue
		var local := _LINKS.local_on(origin, _body.global_position)
		if not _LINKS.in_mouth(local):
			continue
		var gap := Vector2(local.x, local.y).length()
		if gap < best_gap:
			best_gap = gap
			best = i
	# HoodMgr listens for enter on the sphere, not overlap. Coming out of the
	# shaft leaves the toon on the sidewalk, and the trip cannot start again
	# until they have stepped clear and walked back in.
	if best < 0:
		_tunnel_ready = true
		return
	if not _tunnel_ready or not _KEYS.held("forward"):
		return
	_tunnel_ready = false
	var chosen: Dictionary = _tunnels[best]
	_filming = true
	_locked = true
	_body.velocity = Vector3.ZERO
	_leave_tunnel(chosen)


func _leave_tunnel(entry: Dictionary) -> void:
	var origin: Node3D = entry["origin"]
	var scene_path := String(entry["scene"])
	_LINKS.request_scene(scene_path)
	var lateral := _LINKS.local_on(origin, _body.global_position).x
	await _tunnel_out(origin, lateral)
	if not is_inside_tree():
		return
	var from_zone := int(entry["from_zone"])
	_LINKS.depart(from_zone, _LINKS.code_for_zone(from_zone), lateral)
	if _tasks != null:
		_tasks.note_hood(_LINKS.hood_of(int(entry["dest_zone"])))
	ToonLoading.change_to(scene_path)


## LocalToon.tunnelOut is a short straight run plus a 2 second pivot. The
## clock is wall time, so a slow frame skips ahead instead of stretching the
## movie. The follow camera stays off; the shot is the tunnel mouth.
func _tunnel_out(origin: Node3D, lateral: float) -> void:
	var start := _LINKS.local_on(origin, _body.global_position)
	var start_x := clampf(lateral * 0.95, -10.0, 10.0)
	var straight := maxf(absf(start.y - (-6.0)) / _LINKS.run_speed(), 0.15)
	var total := straight + 2.0
	var fade := _blackout()
	fade.color.a = 0.0
	_begin_shot(origin, _camera.global_position if _camera != null else Vector3.ZERO)
	var started := Time.get_ticks_msec()
	while true:
		await get_tree().process_frame
		if not is_instance_valid(origin) or _body == null:
			_shot = false
			return
		var elapsed := float(Time.get_ticks_msec() - started) / 1000.0
		var done := elapsed >= total
		if done:
			elapsed = total
		_body.global_position = _out_point(origin, start, start_x, straight, elapsed)
		_heading = _heading_toward(_out_facing(origin, start, start_x, straight, elapsed))
		_face(_player, _heading)
		_shot_blend = clampf(elapsed / 1.0, 0.0, 1.0)
		if elapsed >= total - 0.5:
			fade.color.a = clampf((elapsed - (total - 0.5)) / 0.4, 0.0, 1.0)
		if done:
			break
	_shot = false


## getTunnelInToonTrack is 0.8 seconds already swung, a 2 second unwind, then
## 0.55 seconds straight out to local Y 5.
func _tunnel_in(origin: Node3D, lateral: float) -> void:
	var end_x := clampf(lateral * 0.8, -10.0, 10.0)
	var fade := _blackout()
	fade.color.a = 1.0
	_body.global_position = _in_point(origin, end_x, 0.0)
	_heading = _heading_toward(origin.global_basis.y)
	_face(_player, _heading)
	_begin_shot(origin, _camera.global_position if _camera != null else Vector3.ZERO)
	_shot_blend = 1.0
	var total := _LINKS.in_length()
	var started := Time.get_ticks_msec()
	while true:
		await get_tree().process_frame
		if not is_instance_valid(origin) or _body == null:
			_shot = false
			return
		var elapsed := float(Time.get_ticks_msec() - started) / 1000.0
		var done := elapsed >= total
		if done:
			elapsed = total
		_body.global_position = _in_point(origin, end_x, elapsed)
		_heading = _heading_toward(_in_facing(origin, end_x, elapsed))
		_face(_player, _heading)
		fade.color.a = 1.0 - clampf(elapsed / 0.4, 0.0, 1.0)
		if done:
			break
	_shot = false
	fade.queue_free()
	_home = _body.global_position
	_home_heading = _heading
	_snap_feet()


func _begin_shot(origin: Node3D, cam_from: Vector3) -> void:
	_shot = true
	_shot_origin = origin
	_shot_from = cam_from
	_shot_blend = 0.0
	_aim_tunnel_camera(origin, cam_from, 0.0)


func _wait_scene(path: String) -> PackedScene:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 20000:
		var packed := _LINKS.take_scene(path)
		if packed != null:
			return packed
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return null
		await get_tree().process_frame
	return null


## Hood.doSpawnTitleText. A tunnel or a teleport into a street, playground, or
## Cog HQ shows the two-line sign. A door that stays in the same playground
## does not load this scene again, so it does not show the title.
func _show_zone_title() -> void:
	var scene_path := ""
	var current := get_tree().current_scene
	if current != null:
		scene_path = current.scene_file_path
	if scene_path.is_empty() and get_parent() != null:
		scene_path = get_parent().scene_file_path
	var info := _TITLE.caption(scene_path)
	# EstateHood.spawnTitleText does nothing. Go Home still uses the map line.
	if info.is_empty() or _PLACES.is_estate(scene_path) or _PLACES.is_house(scene_path) or _hud().get_node_or_null("ZoneTitle") != null:
		return
	var title := _TITLE.new() as Control
	title.name = "ZoneTitle"
	_hud().add_child(title)
	var tint: Color = info["color"]
	title.call("open", String(info["text"]), tint)


func _out_point(origin: Node3D, start: Vector3, start_x: float, straight: float, elapsed: float) -> Vector3:
	return _LINKS.world_on(origin, _LINKS.out_local(start, start_x, straight, elapsed))


func _out_facing(origin: Node3D, start: Vector3, start_x: float, straight: float, elapsed: float) -> Vector3:
	var ahead := _out_point(origin, start, start_x, straight, elapsed + 0.05)
	var here := _out_point(origin, start, start_x, straight, elapsed)
	var step := ahead - here
	step.y = 0.0
	if step.length_squared() < 0.0001:
		return -origin.global_basis.y
	return step.normalized()


func _in_point(origin: Node3D, end_x: float, elapsed: float) -> Vector3:
	return _LINKS.world_on(origin, _LINKS.in_local(end_x, elapsed))


func _in_facing(origin: Node3D, end_x: float, elapsed: float) -> Vector3:
	var ahead := _in_point(origin, end_x, elapsed + 0.05)
	var here := _in_point(origin, end_x, elapsed)
	var step := ahead - here
	step.y = 0.0
	if step.length_squared() < 0.0001:
		return origin.global_basis.y
	return step.normalized()


func _aim_tunnel_camera(origin: Node3D, cam_from: Vector3, blend: float) -> void:
	if _camera == null:
		return
	var settle := _LINKS.world_on(origin, Vector3(0.0, 20.0, 12.0))
	var focus := _LINKS.world_on(origin, Vector3(0.0, 0.0, 3.0))
	var eased := blend * blend * (3.0 - 2.0 * blend)
	_camera.global_position = cam_from.lerp(settle, eased)
	if _camera.global_position.distance_squared_to(focus) > 0.01:
		_camera.look_at(focus, Vector3.UP)


func _snap_feet() -> void:
	var space := _body.get_world_3d().direct_space_state
	var from := _body.global_position + Vector3(0.0, 2.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, -8.0, 0.0))
	query.exclude = [_body.get_rid()]
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	var point: Vector3 = hit["position"]
	_body.global_position.y = point.y + 0.05
	_home = _body.global_position


func _blackout() -> ColorRect:
	var existing := _hud().get_node_or_null("TunnelFade") as ColorRect
	if existing != null:
		return existing
	var fade := ColorRect.new()
	fade.name = "TunnelFade"
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	# SpeedChat++ draws at 20–50. The iris has to cover that window.
	fade.z_index = 80
	_hud().add_child(fade)
	return fade


func _collect_tunnels(root: Node) -> void:
	_walk_tunnels(root)


func _walk_tunnels(node: Node) -> void:
	var parsed := _parse_link(String(node.name))
	if not parsed.is_empty():
		var origin := _LINKS.origin_under(node)
		var scene := _LINKS.scene_for_zone(int(parsed["zone"]))
		var from_zone := _zone_above(node)
		if from_zone < 1000 and node.has_meta("link_from_zone"):
			from_zone = int(node.get_meta("link_from_zone"))
		if origin != null and scene != "" and from_zone >= 1000:
			_LINKS.request_scene(scene)
			_tunnels.append({
				"origin": origin,
				"dest_zone": int(parsed["zone"]),
				"from_zone": from_zone,
				"scene": scene,
			})
	for child in node.get_children():
		_walk_tunnels(child)


func _match_arrival(code: String, zone: int) -> Node3D:
	var link := _LINKS.find_link(get_parent(), code, zone)
	if link == null:
		return null
	return _LINKS.origin_under(link)


func _parse_link(node_name: String) -> Dictionary:
	if not node_name.begins_with("linktunnel_"):
		return {}
	var parts := node_name.split("_")
	if parts.size() < 3:
		return {}
	var zone_text := parts[2].split("@")[0]
	if not zone_text.is_valid_int():
		return {}
	return {"code": parts[1], "zone": int(zone_text)}


func _zone_above(node: Node) -> int:
	var cursor := node.get_parent()
	while cursor != null:
		var part := String(cursor.name).split("_")[0]
		if part.is_valid_int():
			return int(part)
		cursor = cursor.get_parent()
	return 0


func _heading_toward(dir: Vector3) -> float:
	return _LINKS.heading_of(dir)


func _find(root: Node, node_name: String) -> Node3D:
	if root.name == node_name and root is Node3D:
		return root as Node3D
	for child in root.get_children():
		var found := _find(child, node_name)
		if found:
			return found
	return null
