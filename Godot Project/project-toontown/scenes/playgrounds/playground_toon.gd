extends Node

## Place.enterTeleportIn plays Toon.getTeleportInTrack. A trolley task in
## Toontown Central pops up at an initial drop point. Logging in from Pick a
## Toon uses the same hole, at the last playground or Cog HQ. The hole is the
## same disc Tutorial Tom leaves through. Map teleports throw the portable
## hole instead: Toon.getTeleportOutTrack, then getTeleportInTrack on arrival.

const _PLACES := preload("res://scenes/places/hood_places.gd")
const _LINKS := preload("res://scenes/places/tunnel_links.gd")
const _TITLE := preload("res://scenes/places/zone_title.gd")
const _KEYS := preload("res://scenes/shticker/keybinds.gd")
const _DOORS := preload("res://scenes/interiors/house_door.gd")
const _SHOP := preload("res://scenes/interiors/gag_shop_door.gd")
const _BANK_GUI := preload("res://scenes/interiors/bank_gui.gd")
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
# Set with teleport_in when the map threw a portal. Arrival then plays
# getTeleportInTrack instead of the login disc.
static var portal_in := false
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
const STEP_HEIGHT := 0.55
const _CAM_PITCH_HOME := 0.0
const _CAM_PITCH_MIN := -18.0
const _CAM_PITCH_MAX := 42.0
const _CAM_DIST_MIN := 0.38
const _CAM_DIST_MAX := 2.1

var _body: CharacterBody3D
var _player: ToonActor
var _camera: Camera3D
var _heading := 0.0
var _hood := 0
var _home := Vector3(-90.7, 0.35, 60.0)
var _home_heading := 102.575
var _eye_height := 3.0
var _jumping := false
var _jump_lock := 0.0
var _locked := true
var _filming := false
var _portaling := false
var _tunnel_ready := false
var _door_ready := false
var _bank_ready := false
var _bank_open := false
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
var _tunnels: Array[Dictionary] = []
var _shot := false
var _shot_origin: Node3D
var _shot_from := Vector3.ZERO
var _shot_blend := 0.0
var _tasks: ToonTasks
var _loadout: ToonLoadout
var _book: ShtickerBook
var _meter: LaffMeter
var _line: PanelContainer
var _line_label: Label
var _line_left := 0.0
var _cam_yaw := 0.0
var _cam_pitch := 0.0
var _cam_distance := 1.0
var _cam_steering := false
var _right_yaw := 0.0
var _running := false
var _reversing := false
var _active := false


static func attach(host: Node) -> void:
	if Engine.is_editor_hint():
		return
	if host.get_node_or_null("PlaygroundToon") != null:
		return
	var arrival: Node = (load("res://scenes/playgrounds/playground_toon.gd") as GDScript).new()
	arrival.name = "PlaygroundToon"
	host.add_child(arrival)


func _ready() -> void:
	_tasks = ToonTasks.for_selected()
	var arriving := from_toontorial
	var logging_in := teleport_in
	var from_portal := portal_in
	var from_door := door_trip
	var from_shop := String(_SHOP.trip)
	from_toontorial = false
	teleport_in = false
	portal_in = false
	door_trip = ""
	_SHOP.trip = ""
	_from_door = from_door
	_shop_trip = from_shop
	var incoming := _LINKS.arriving()
	if not arriving and not logging_in and not incoming and not _tasks.in_playground:
		queue_free()
		return
	var trip: Dictionary = {}
	if incoming:
		trip = _LINKS.take()
	_active = true
	_hood = _current_hood()
	_SHOP.prepare(get_parent(), _hood)
	var window := get_tree().root
	if not window.close_requested.is_connected(_keep_quests):
		window.close_requested.connect(_keep_quests)
	_quiet_fly_camera()
	_collect_tunnels(get_parent())
	_spawn(arriving or logging_in)
	_ready_hud()
	if from_door != "" or from_shop != "":
		if _tasks.in_playground:
			_tasks.note_hood(_hood)
		_fade_in()
		_DOORS.play_close(self)
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
		_locked = false
		_place_camera()
		return
	if arriving:
		_tasks.note_playground()
	elif _tasks.in_playground:
		_tasks.note_hood(_hood)
	if arriving or logging_in:
		if from_portal:
			await _portal_in()
		else:
			_fade_in()
			await _pop_up()
	_locked = false
	_place_camera()


func _exit_tree() -> void:
	_keep_quests()


## The journal is already written on each quest change. Closing the window
## after the toontorial writes it once more, so a quit cannot drop the last task.
func _keep_quests() -> void:
	if _tasks != null and _tasks.in_playground:
		_tasks.save()


func _process(delta: float) -> void:
	if not _active or _player == null:
		return
	if _locked or _filming or _portaling or _bank_open or (_book != null and _book.is_open()):
		_release_camera_mouse(true)
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
	_place_camera()
	_place_line(delta)


func _physics_process(delta: float) -> void:
	if not _active or _locked:
		return
	_walk(delta)
	_try_tunnel()
	_try_house_door()
	_try_gag_door()
	_try_bank()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	_steer_camera(event)
	if _filming or _locked:
		return
	if _book != null and _tasks != null and _tasks.book_ready() and _book_hotkey(event):
		_book.toggle_hotkey()
		get_viewport().set_input_as_handled()


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


func show_notice(message: String) -> void:
	say_line(message)


func say_line(text: String) -> void:
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
		_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_line_label.custom_minimum_size = Vector2(40, 0)
		ToonGui.style_label(_line_label, Color(0.05, 0.05, 0.08), 22, Color(0, 0, 0, 0), 0)
		_line.add_child(_line_label)
		_hud().add_child(_line)
	_line_label.text = text
	_line_left = maxf(2.8, float(text.length()) * 0.045)
	_line.visible = true


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


func _arrival_spot() -> Dictionary:
	var scene_path := _scene_path()
	if _shop_trip == "out":
		return _shop_outside_drop()
	if _PLACES.is_gag_shop(scene_path):
		return _shop_inside_drop()
	if _PLACES.is_house(scene_path):
		return _house_drop()
	if _hood == _PLACES.ESTATE and _from_door == "out":
		return _estate_door_drop()
	if _hood == _PLACES.ESTATE:
		return _estate_drop()
	if _hood == _PLACES.TTC:
		return {"point": _PLACES.drop_for(_hood), "heading": _PLACES.heading_for(_hood)}
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
		origin = _DOORS.find_origin(house)
		if origin == null:
			return
		trigger = _DOORS.outside_trigger(house, origin)
	var here := Vector2(_body.global_position.x, _body.global_position.z)
	var near := here.distance_to(Vector2(trigger.x, trigger.z)) <= 2.0
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
		var building := _SHOP.find_building(get_parent())
		if building == null:
			return
		var door := _SHOP.find_exterior_door(building)
		if door == null:
			return
		trigger = _SHOP.outside_trigger(building, door)
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
	await get_tree().create_timer(0.7).timeout
	await _fade_black()
	_SHOP.hood = _hood
	_SHOP.trip = "in"
	get_tree().change_scene_to_file(_PLACES.gag_shop_scene())


func _leave_shop() -> void:
	_locked = true
	_SHOP.open(self, _SHOP.find_interior_door(get_parent()))
	await get_tree().create_timer(0.7).timeout
	await _fade_black()
	_SHOP.trip = "out"
	get_tree().change_scene_to_file(_PLACES.scene_for(_SHOP.hood))


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


func _enter_house(slot: int) -> void:
	_locked = true
	var house := _DOORS.find_house(get_parent(), slot)
	var door := _DOORS.find_door(house if house != null else get_parent())
	_DOORS.open(self, door)
	await get_tree().create_timer(0.7).timeout
	await _fade_black()
	door_trip = "in"
	get_tree().change_scene_to_file(_PLACES.house_scene(slot))


func _leave_house(slot: int) -> void:
	_locked = true
	_DOORS.open(self, _DOORS.find_door(get_parent()))
	await get_tree().create_timer(0.7).timeout
	await _fade_black()
	door_trip = "out"
	get_tree().change_scene_to_file(_PLACES.estate_scene(slot))


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
	var from := drop + Vector3(0.0, 30.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, drop + Vector3(0.0, -40.0, 0.0))
	query.collide_with_areas = false
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return drop
	var landed: Vector3 = hit["position"]
	landed.y += 0.05
	return landed


func _spawn(underground: bool) -> void:
	var style := ToonRoster.selected_style()
	_body = CharacterBody3D.new()
	_body.name = "Player"
	_body.floor_snap_length = 0.6
	# Plaza stair faces run to about 54 degrees. Steeper than that stays a wall.
	_body.floor_max_angle = deg_to_rad(58.0)
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
		_player.show_style(style)
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
func teleport_to_hood(hood: int) -> void:
	if not await _play_teleport_out():
		return
	portal_in = true
	teleport_in = true
	if _tasks != null:
		_tasks.note_hood(hood)
	get_tree().change_scene_to_file(_PLACES.scene_for(hood))


## Place.__handleBookCloseExit plays TeleportOut, fades, then leaves the shard.
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
	get_tree().change_scene_to_file(_PICK_SCENE)


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
	var player := AudioStreamPlayer.new()
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
	_meter = LaffMeter.new()
	_meter.name = "LaffMeter"
	var style := ToonRoster.selected_style()
	if style:
		_meter.setup(style)
	else:
		_meter.setup(ToonStyle.new())
	_meter.follow(_loadout)
	_hud().add_child(_meter)
	var view := get_viewport().get_visible_rect().size
	var pixels := view.y * 0.15
	_meter.place(LaffMeter.corner(view, pixels), pixels)
	_book = ShtickerBook.new()
	_book.name = "ShtickerBook"
	_hud().add_child(_book)
	_book.setup(_tasks, _loadout)
	var chat := SpeedChat.new()
	chat.name = "SpeedChat"
	_hud().add_child(chat)
	chat.setup(_tasks)
	chat.phrase_said.connect(say_line)


func _walk(delta: float) -> void:
	if _player == null or _body == null:
		return
	var forward_held := _KEYS.held("forward")
	var back_held := _KEYS.held("back")
	var left_held := _KEYS.held("left")
	var right_held := _KEYS.held("right")
	var aim_held := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	# Right-click turns the side keys into a full run across the camera.
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
	var forward := _forward(move_heading)
	_body.velocity.x = forward.x * speed
	_body.velocity.z = forward.z * speed
	var on_floor := _body.is_on_floor()
	var jumped := false
	var impact := _body.velocity.y
	if on_floor:
		if _jump_lock > 0.0:
			_jump_lock = maxf(_jump_lock - delta, 0.0)
		if _KEYS.held("jump") and _jump_lock <= 0.0:
			_body.velocity.y = JUMP_FORCE
			jumped = true
			_jumping = true
		else:
			_body.velocity.y = -2.0
			_jumping = false
	else:
		_body.velocity.y -= GRAVITY * delta
		impact = _body.velocity.y
	if on_floor and not jumped:
		_raise_onto_step()
	_body.floor_snap_length = 0.0 if _body.velocity.y > 0.0 else 0.6
	_body.move_and_slide()
	if _body.position.y < _home.y - 8.0:
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
	_player.set_locomotion(speed, turning, _jumping or jumped, delta)


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
	if _locked or _filming or _portaling or _bank_open or (_book != null and _book.is_open()):
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


func _place_line(delta: float) -> void:
	if _line == null or _camera == null or _player == null:
		return
	_line_left = maxf(_line_left - delta, 0.0)
	if _line_left <= 0.0 or not _player.visible:
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


## A vertical riser is not a floor. Lift onto the tread in front of it, the
## way GravityWalker's lifter clears a step before the body hits the wall.
func _raise_onto_step() -> void:
	var ahead := Vector3(_body.velocity.x, 0.0, _body.velocity.z)
	if ahead.length() < 0.2:
		return
	var space := _body.get_world_3d().direct_space_state
	if space == null:
		return
	var dir := ahead.normalized()
	var feet := _body.global_position
	var ankle_from := feet + Vector3(0.0, 0.12, 0.0)
	var ankle := PhysicsRayQueryParameters3D.create(ankle_from, ankle_from + dir * (BODY_RADIUS + 0.35))
	ankle.exclude = [_body.get_rid()]
	ankle.collide_with_areas = false
	var riser := space.intersect_ray(ankle)
	if riser.is_empty():
		return
	var riser_normal: Vector3 = riser["normal"]
	if riser_normal.y > 0.45:
		return
	var high := feet + Vector3(0.0, STEP_HEIGHT + 0.2, 0.0) + dir * (BODY_RADIUS + 0.2)
	var down := PhysicsRayQueryParameters3D.create(high, high + Vector3(0.0, -(STEP_HEIGHT + 0.45), 0.0))
	down.exclude = [_body.get_rid()]
	down.collide_with_areas = false
	var tread := space.intersect_ray(down)
	if tread.is_empty():
		return
	var point: Vector3 = tread["position"]
	var rise := point.y - feet.y
	if rise < 0.08 or rise > STEP_HEIGHT:
		return
	var chest_from := feet + Vector3(0.0, rise + 0.6, 0.0)
	var chest := PhysicsRayQueryParameters3D.create(chest_from, chest_from + dir * 0.4)
	chest.exclude = [_body.get_rid()]
	chest.collide_with_areas = false
	if not space.intersect_ray(chest).is_empty():
		return
	_body.global_position.y += rise
	_body.velocity.y = 0.0


func _cache_eye_height() -> void:
	_eye_height = 3.0
	if _player == null:
		return
	_eye_height = _player.clamped_height()


func _face(actor: Node3D, heading: float) -> void:
	var body_scale := actor.transform.basis.get_scale().x
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	upright = upright.rotated(Vector3.UP, deg_to_rad(heading))
	actor.transform.basis = upright.scaled(Vector3.ONE * body_scale)


func _forward(heading: float) -> Vector3:
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	upright = upright.rotated(Vector3.UP, deg_to_rad(heading))
	return upright * Vector3(0, 1, 0)


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
	var packed := await _wait_scene(scene_path)
	if packed != null:
		get_tree().change_scene_to_packed(packed)
	else:
		get_tree().change_scene_to_file(scene_path)


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
