extends Node3D

## The tutorial building the way DistributedTutorialInterior leaves it after
## the intro: the furnished room, the street outside the window, Tutorial Tom
## at the desk, and the toon saved from Make a Toon standing on the rug.

const TOONTOWN_SKY := preload("res://scenes/sky/toontown_sky.gd")
const _PLACES := preload("res://scenes/places/hood_places.gd")
const _ARRIVAL := preload("res://scenes/playgrounds/playground_toon.gd")
const MUSIC_PATH := "res://assets/neighborhoods/tutorial_zone/audio/TC_SZ.ogg"
const MUSIC_VOLUME := 0.8

# Quest script tutorial_mickey, after FREE_LOCALTOON. Panda (1.6, 9.8, 0) H 14.
const START_POSITION := Vector3(1.6, 0.0, -9.8)
const START_HEADING := 14.0
# npc_origin_0 from the tutorial interior. Tom's DNA is NPC 20000.
const TOM_POSITION := Vector3(1.0, 0.0, -22.5)
const TOM_HEADING := 180.0
const WELCOME := "Hey, you must be the new Toon in town! Use the MOVEMENT KEYS to come over here."
# OTPGlobals, with ToonSpeedFactor applied.
const FORWARD_SPEED := 20.0
const REVERSE_SPEED := 10.0
const TURN_SPEED := 100.0
# GravityWalker default gravity, and OTPGlobals.ToonJumpForce. Control jumps.
const GRAVITY := 64.348
const JUMP_FORCE := 24.0
const JUMP_LOCK := 0.2
# GravityWalker: impact faster than 30 plays the land animation and waits 0.3s.
const HARD_LAND := -30.0
const HARD_LOCK := 0.3
const COLLISION_PATH := "res://assets/interiors/toontorial/collision.json"

var _camera: Camera3D
var _player: ToonActor
var _body: CharacterBody3D
var _heading := START_HEADING
var _eye_height := 3.0
var _jumping := false
var _jump_lock := 0.0
var _billboards: Array[Dictionary] = []
var _tags: Array[Dictionary] = []
var _bubble: Control
var _cutscene := false
var _locked := false
var _welcome_done := false
var _fading := false
var _loadout: ToonLoadout
var _panel: GagPanel
var _meter: LaffMeter
var _briefing: TutorialBriefing
var _tasks: ToonTasks
var _book: ShtickerBook
var _speed: SpeedChat
var _line: PanelContainer
var _line_label: Label
var _line_left := 0.0
var _flunky: Flunky
var _battle: StreetBattle
var _return_spot := Vector3(-22.0, 0.2, -24.5)
var _return_heading := 180.0
var _gate: StaticBody3D
var _door_dialog: Control
var _door_stopped := false
var _gate_armed := true
var _hq
var _cam_yaw := 0.0
var _cam_pitch := 0.0
var _cam_distance := 1.0
var _camera_held := false
const _CAM_PITCH_MIN := -18.0
const _CAM_PITCH_MAX := 42.0
const _CAM_DIST_MIN := 0.38
const _CAM_DIST_MAX := 2.1
const _DOOR := Vector2(-14.2, -24.5)
const _NEED_GAGS := "You need gags! Go talk to\nTutorial Tom!"
# linktunnel_tt_0 tunnel_origin, a step into the shaft. Local -Y of that
# origin is +X here, which is the way Flippy runs.
const _TUNNEL_MOUTH := Vector2(122.4, -0.15)


func _ready() -> void:
	var tasks := ToonTasks.for_selected()
	if tasks.in_playground:
		_ARRIVAL.teleport_in = true
		get_tree().call_deferred("change_scene_to_file", _PLACES.scene_for(tasks.last_hood))
		return
	TOONTOWN_SKY.ensure(self, "tt")
	_camera = get_node_or_null("Camera") as Camera3D
	if _camera:
		_camera.keep_aspect = Camera3D.KEEP_WIDTH
		_camera.fov = 52.0
		_camera.far = 4000.0
		_camera.current = true
	_ready_music()
	_build_collision()
	_collect_billboards(self)
	_build_bubble()
	_spawn_toons()
	_ready_loadout()
	_spawn_flunky()
	_add_outside_floor()
	_build_exit_gate()
	_start_battle()
	_place_camera()
	if _tasks != null and _tasks.book_ready():
		_open_plaza()


func _process(delta: float) -> void:
	TOONTOWN_SKY.ensure(self, "tt")
	var tom := get_node_or_null("Tutorial Tom") as ToonActor
	if tom:
		# The welcome and the quest movie both keep him in the talk cycle
		# unless a gesture (the pointing hand, the raised hand) is playing.
		if _cutscene or not _welcome_done:
			tom.set_dialogue(delta)
		else:
			tom.set_locomotion(0.0, false, false, delta)
	if not _camera_held and (not _cutscene or (_hq != null and _hq.inside())):
		_place_camera()
	_face_billboards()
	_place_tags()
	if _gate != null and _briefing != null and _briefing.finished:
		_gate.queue_free()
		_gate = null
	if _door_dialog != null and Input.is_action_just_pressed("ui_accept"):
		_close_need_gags()
	if not _cutscene and not _welcome_done:
		_place_bubble()
	elif _bubble and (_cutscene or _welcome_done):
		_bubble.visible = false
	_idle_flippy(delta)
	_place_line()


func _physics_process(delta: float) -> void:
	if _locked or _door_stopped:
		return
	if _hq != null and _hq.inside():
		_walk(delta)
		if not _cutscene:
			_hq.consider_inside(_body)
		return
	_walk(delta)
	_approach_tom()
	_try_door()
	_try_battle()
	_consider_flippy()
	_try_tunnel()
	if _hq != null and not _cutscene:
		_hq.consider(_body)


func _spawn_toons() -> void:
	var style := _player_style()
	if style:
		_body = CharacterBody3D.new()
		_body.name = "Player"
		_body.floor_snap_length = 0.6
		_body.floor_max_angle = deg_to_rad(50.0)
		_body.safe_margin = 0.04
		_body.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
		_body.up_direction = Vector3.UP
		add_child(_body)
		# Sit just above the floor so the capsule is not already inside it.
		_body.position = START_POSITION + Vector3(0.0, 0.2, 0.0)
		_player = _spawn(style, Vector3.ZERO, START_HEADING, _body)
		_add_capsule()
		_add_tag(_player, style.display_name(), "player")
	var tom := _spawn(_tom_style(), TOM_POSITION, TOM_HEADING, self)
	tom.follows_ground = true
	_add_tag(tom, "Tutorial Tom", "npc")
	_cache_eye_height()


func _player_style() -> ToonStyle:
	var selected := ToonRoster.selected_style()
	if selected:
		return selected
	for index in ToonRoster.SLOT_COUNT:
		var slot := ToonRoster.get_slot(index)
		if slot:
			return slot
	return null


func _tom_style() -> ToonStyle:
	# TutorialBuildingAI colors and clothes. The head he wears is the tall
	# skull with the short muzzle.
	var style := ToonStyle.new()
	style.first_name = "Tutorial"
	style.last_name = "Tom"
	style.gender = "m"
	style.head = "dls"
	style.torso = "ms"
	style.legs = "m"
	style.arm_color = 7
	style.glove_color = 0
	style.leg_color = 7
	style.head_color = 7
	style.top_tex = 2
	style.top_color = 6
	style.bot_tex = 2
	style.bot_color = 16
	return style


func _spawn(style: ToonStyle, where: Vector3, heading: float, parent: Node) -> ToonActor:
	var actor := ToonActor.new()
	actor.name = style.display_name()
	parent.add_child(actor)
	actor.position = where
	actor.show_style(style)
	_face(actor, heading)
	return actor


func fit_hq_body() -> void:
	# The radius-1 tube stands on the landing and floats over the 45-degree stairs.
	var collision := _body.get_node_or_null("BodyCapsule") as CollisionShape3D
	if collision == null:
		return
	var shape := collision.shape as CapsuleShape3D
	if shape == null:
		return
	shape.radius = 0.35
	shape.height = maxf(shape.height, shape.radius * 2.0 + 0.2)
	collision.shape = shape


func restore_street_body() -> void:
	var collision := _body.get_node_or_null("BodyCapsule") as CollisionShape3D
	if collision == null:
		return
	var shape := collision.shape as CapsuleShape3D
	if shape == null:
		return
	shape.radius = 1.0
	shape.height = maxf(shape.height, shape.radius * 2.0 + 0.2)
	collision.shape = shape


func _add_capsule() -> void:
	# Avatar.initializeBodyCollisions uses a tube of radius 1.
	var height := 3.0
	var head := _find(_player, "def_head")
	if head:
		height = maxf(head.global_position.y - _body.global_position.y + 0.5, 2.4)
	var shape := CapsuleShape3D.new()
	shape.radius = 1.0
	shape.height = maxf(height, shape.radius * 2.0 + 0.2)
	var collision := CollisionShape3D.new()
	collision.name = "BodyCapsule"
	collision.shape = shape
	collision.position = Vector3(0.0, shape.height * 0.5, 0.0)
	_body.add_child(collision)


func _build_collision() -> void:
	if not FileAccess.file_exists(COLLISION_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COLLISION_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var faces := PackedVector3Array()
	for triangle in parsed.get("triangles", []):
		if triangle.size() < 9:
			continue
		faces.append(Vector3(float(triangle[0]), float(triangle[1]), float(triangle[2])))
		faces.append(Vector3(float(triangle[3]), float(triangle[4]), float(triangle[5])))
		faces.append(Vector3(float(triangle[6]), float(triangle[7]), float(triangle[8])))
	if faces.is_empty():
		return
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var solid := StaticBody3D.new()
	solid.name = "InteriorCollision"
	var collision := CollisionShape3D.new()
	collision.shape = shape
	solid.add_child(collision)
	add_child(solid)
	_add_floor_slab(faces)


func _add_floor_slab(faces: PackedVector3Array) -> void:
	# The exported floor is a handful of huge, paper-thin triangles. Jolt drops
	# a character straight through those when the capsule starts on top of them.
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	var found := false
	for index in range(0, faces.size(), 3):
		var a := faces[index]
		var b := faces[index + 1]
		var c := faces[index + 2]
		var normal := (b - a).cross(c - a)
		if absf(normal.y) < absf(normal.x) or absf(normal.y) < absf(normal.z) or normal.y <= 0.0:
			continue
		if absf(a.y - b.y) > 0.05 or absf(a.y - c.y) > 0.05 or a.y > 0.25:
			continue
		found = true
		for point in [a, b, c]:
			low = low.min(point)
			high = high.max(point)
	if not found:
		return
	var slab := StaticBody3D.new()
	slab.name = "Floor"
	var box := BoxShape3D.new()
	box.size = Vector3(high.x - low.x, 1.0, high.z - low.z)
	var collision := CollisionShape3D.new()
	collision.shape = box
	collision.position = Vector3((low.x + high.x) * 0.5, high.y - 0.5, (low.z + high.z) * 0.5)
	slab.add_child(collision)
	add_child(slab)


func _walk(delta: float) -> void:
	if _player == null or _body == null:
		return
	var turn := 0.0
	if Input.is_physical_key_pressed(KEY_A):
		turn += 1.0
	if Input.is_physical_key_pressed(KEY_D):
		turn -= 1.0
	_heading += turn * TURN_SPEED * delta
	var speed := 0.0
	var forward_held := Input.is_physical_key_pressed(KEY_W)
	var back_held := Input.is_physical_key_pressed(KEY_S)
	var turning := turn != 0.0
	if forward_held and not back_held:
		speed = FORWARD_SPEED
	elif back_held and not forward_held:
		speed = -REVERSE_SPEED
	var forward := _forward(_heading)
	_body.velocity.x = forward.x * speed
	_body.velocity.z = forward.z * speed
	var on_floor := _body.is_on_floor()
	var jumped := false
	var impact := _body.velocity.y
	if on_floor:
		if _jump_lock > 0.0:
			_jump_lock = maxf(_jump_lock - delta, 0.0)
		if Input.is_physical_key_pressed(KEY_CTRL) and _jump_lock <= 0.0:
			_body.velocity.y = JUMP_FORCE
			jumped = true
			_jumping = true
		else:
			_body.velocity.y = -2.0
			_jumping = false
	else:
		_body.velocity.y -= GRAVITY * delta
		impact = _body.velocity.y
	# Snap would glue a rising toon back onto the floor.
	_body.floor_snap_length = 0.0 if _body.velocity.y > 0.0 else 0.6
	_body.move_and_slide()
	# The HQ pit floor is at -5. The street reset would pull a toon back up the stairs.
	var void_y := -1.0
	if _hq != null and _hq.inside():
		void_y = -12.0
	if _body.position.y < void_y:
		_body.velocity = Vector3.ZERO
		_body.position = _return_spot
		_heading = _return_heading
		_jumping = false
	elif not on_floor and _body.is_on_floor() and not jumped:
		_jumping = false
		if impact < HARD_LAND:
			_player.hard_land()
			_jump_lock = HARD_LOCK
		elif impact < -5.0:
			_jump_lock = JUMP_LOCK
	_face(_player, _heading)
	_player.set_locomotion(speed, turning, _jumping or jumped, delta)


func _place_camera() -> void:
	if _camera == null:
		return
	var feet := START_POSITION
	var heading := START_HEADING
	if _player:
		feet = _player.global_position
		heading = _heading
	# Eye height is the resting head, taken once. Reading the live head follows
	# the idle, run, and jump, and that bob is what makes the camera sick.
	var height := _eye_height
	var orbit := heading + _cam_yaw
	var forward := _forward(orbit)
	var eye := feet + Vector3(0.0, height, 0.0)
	var distance := 9.0 * (height / 3.0) * _cam_distance
	var pitch := deg_to_rad(_cam_pitch)
	var back := forward * distance * cos(pitch)
	_camera.global_position = eye - Vector3(back.x, 0.0, back.z) + Vector3(0.0, distance * sin(pitch), 0.0)
	_camera.look_at(eye + forward * 1.5, Vector3.UP)


func _cache_eye_height() -> void:
	_eye_height = 3.0
	if _player == null:
		return
	var head := _find(_player, "def_head")
	if head:
		_eye_height = maxf(head.global_position.y - _player.global_position.y, 3.0)


func _face(actor: Node3D, heading: float) -> void:
	# show_style stands the Z-up parts up and adds a turn for Make a Toon.
	# Replace that with the Panda heading. Positive H is a left turn.
	var body_scale := actor.transform.basis.get_scale().x
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	upright = upright.rotated(Vector3.UP, deg_to_rad(heading))
	actor.transform.basis = upright.scaled(Vector3.ONE * body_scale)


func _steer_camera(event: InputEvent) -> void:
	if _cutscene or _locked or _fading:
		return
	if _book != null and _book.is_open():
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not button.pressed:
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_distance = maxf(_CAM_DIST_MIN, _cam_distance - 0.14)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_distance = minf(_CAM_DIST_MAX, _cam_distance + 0.14)
		elif button.button_index == MOUSE_BUTTON_MIDDLE:
			_cam_yaw = 0.0
			_cam_pitch = 0.0
			_cam_distance = 1.0
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var left := (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		var right := (motion.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0
		if not left and not right:
			return
		var yaw := -motion.relative.x * 0.18
		_cam_pitch = clampf(_cam_pitch - motion.relative.y * 0.12, _CAM_PITCH_MIN, _CAM_PITCH_MAX)
		if right and Input.is_physical_key_pressed(KEY_W):
			# Steering: the toon turns with the camera, so forward follows it.
			_heading += yaw
		else:
			# Looking around, or a right-drag while standing still. The facing stays.
			_cam_yaw += yaw


func _tag_hidden(actor: Node3D, point: Vector3) -> bool:
	if _camera == null or _camera.is_position_behind(point):
		return true
	# The player's own card floats above his head, so his body is not in the way.
	if actor == _player:
		return false
	# Harry stands inside the HQ trimesh. A ray from the interior camera hits
	# that shell before his card, so the card never appears.
	if _actor_in_hq(actor):
		return false
	var world := get_world_3d()
	if world == null:
		return false
	var origin := _camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, point)
	query.collide_with_areas = false
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	# Tom's card was drawing on top of the player. A body or a wall in front hides it.
	return origin.distance_to(hit.position) < origin.distance_to(point) - 0.3


func _actor_in_hq(actor: Node) -> bool:
	var node: Node = actor
	while node != null:
		if node.name == "HQInterior":
			return true
		node = node.get_parent()
	return false


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


func hud() -> CanvasLayer:
	return _hud()


func set_cutscene(active: bool) -> void:
	_cutscene = active
	_locked = active


func in_cutscene() -> bool:
	return _cutscene or _door_stopped


func hold_camera(held: bool) -> void:
	_camera_held = held


func dismiss_welcome() -> void:
	_welcome_done = true
	if _bubble:
		_bubble.visible = false


func quiet_shop_speech() -> void:
	# The plaza camera can see the shop Tom's spot. His greeting stays in the
	# building; the street cutscene speaks with its own actor.
	dismiss_welcome()
	var briefing := get_node_or_null("Briefing")
	if briefing != null and briefing.has_method("hide_speech"):
		briefing.call("hide_speech")


func face_tom(heading: float) -> void:
	var tom := get_node_or_null("Tutorial Tom") as Node3D
	if tom:
		_face(tom, heading)


func place_player(where: Vector3, heading: float) -> void:
	if _body == null or _player == null:
		return
	_body.position = where
	_heading = heading
	_face(_player, heading)


func note_plaza(where: Vector3, heading: float) -> void:
	_return_spot = where
	_return_heading = heading


func settle_camera() -> void:
	_place_camera()


func add_nametag(actor: Node3D, text: String, color: Color) -> void:
	_add_tag(actor, text, "npc", color)


func prepare_hq() -> void:
	if _hq == null:
		_hq = load("res://scenes/interiors/tutorial_hq.gd").new()
		_hq.name = "TutorialHQ"
		add_child(_hq)
	_hq.setup(self)


func face_actor(actor: Node3D, heading: float) -> void:
	_face(actor, heading)
	if actor == _player:
		_heading = heading


func _start_battle() -> void:
	_battle = StreetBattle.new()
	_battle.name = "StreetBattle"
	add_child(_battle)
	_battle.setup(self, _body, _player, _flunky, _loadout, _tasks, _camera, _meter, _book, _hud())


func _try_battle() -> void:
	if _battle == null or _briefing == null or not _briefing.finished or _body == null:
		return
	_battle.consider(_body.global_position)


func _ready_loadout() -> void:
	_loadout = ToonLoadout.for_selected()
	_panel = GagPanel.new()
	_panel.name = "GagPanel"
	_panel.setup(_loadout)
	_panel.visible = false
	_hud().add_child(_panel)
	_meter = LaffMeter.new()
	_meter.name = "LaffMeter"
	_meter.setup(_player_style())
	_meter.follow(_loadout)
	_meter.visible = false
	_hud().add_child(_meter)
	_briefing = TutorialBriefing.new()
	_briefing.name = "Briefing"
	add_child(_briefing)
	_briefing.setup(self, _panel, _meter, _loadout)
	_tasks = ToonTasks.for_selected()
	_book = ShtickerBook.new()
	_book.name = "ShtickerBook"
	_hud().add_child(_book)
	_book.setup(_tasks, _loadout)
	_speed = SpeedChat.new()
	_speed.name = "SpeedChat"
	_hud().add_child(_speed)
	_speed.setup(_tasks)
	_speed.phrase_said.connect(say_line)


func tasks() -> ToonTasks:
	return _tasks


func shticker() -> ShtickerBook:
	return _book


func speedchat() -> SpeedChat:
	return _speed


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
	_place_line()


func _spawn_flunky() -> void:
	_flunky = Flunky.new()
	_flunky.name = "Flunky"
	add_child(_flunky)
	_flunky.pace_outside()
	_add_tag(_flunky, "Flunky\nBossbot\nLevel 1", "cog")


func _build_exit_gate() -> void:
	# TutorialBuildingAI locks the inside door with TALK_TO_TOM until the
	# gag handoff. The wall fills the doorway the exit check uses.
	var gate := StaticBody3D.new()
	gate.name = "ExitGate"
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 4.2, 8.0)
	var collision := CollisionShape3D.new()
	collision.shape = box
	collision.position = Vector3(_DOOR.x - 0.6, 2.1, _DOOR.y)
	gate.add_child(collision)
	add_child(gate)
	_gate = gate


func _add_outside_floor() -> void:
	# The street mesh is already outside the window. This slab is what the
	# toon stands on after walking through the door.
	var slab := StaticBody3D.new()
	slab.name = "OutsideFloor"
	var box := BoxShape3D.new()
	box.size = Vector3(120.0, 1.0, 90.0)
	var collision := CollisionShape3D.new()
	collision.shape = box
	collision.position = Vector3(-50.0, -0.5, -18.0)
	slab.add_child(collision)
	add_child(slab)


func _approach_tom() -> void:
	if _briefing == null or _briefing.started or _body == null:
		return
	var tom := get_node_or_null("Tutorial Tom") as Node3D
	if tom == null:
		return
	var here := Vector2(_body.position.x, _body.position.z)
	var there := Vector2(tom.position.x, tom.position.z)
	var distance := here.distance_to(there)
	var pushing := Input.is_physical_key_pressed(KEY_W) and _body.get_real_velocity().length() < 0.4
	if distance < 8.0 or (distance < 12.0 and pushing):
		_briefing.start()


func _open_plaza() -> void:
	# A toon who already has the book comes back on the street outside HQ,
	# looking down toward the tunnel, instead of starting over in the shop.
	if get_node_or_null("TutorialStreet") == null:
		var packed := load("res://assets/neighborhoods/tutorial_zone/tutorial_zone.glb") as PackedScene
		if packed == null:
			return
		var zone := packed.instantiate()
		zone.name = "TutorialStreet"
		add_child(zone)
		_hide_named(zone, "sky")
	var interior := get_node_or_null("Geometry") as Node3D
	if interior:
		interior.visible = false
	dismiss_welcome()
	var tom := get_node_or_null("Tutorial Tom") as Node3D
	if tom:
		tom.visible = false
	if _flunky:
		_flunky.visible = false
	if get_node_or_null("PlazaFloor") == null:
		var slab := StaticBody3D.new()
		slab.name = "PlazaFloor"
		var box := BoxShape3D.new()
		box.size = Vector3(360.0, 1.0, 180.0)
		var collision := CollisionShape3D.new()
		collision.shape = box
		collision.position = Vector3(20.0, -0.5, 0.0)
		slab.add_child(collision)
		add_child(slab)
	prepare_hq()
	var placed := false
	if _hq != null and _hq.has_method("stand_at_tunnel"):
		placed = bool(_hq.call("stand_at_tunnel"))
	if not placed:
		if interior:
			interior.visible = true
		if tom:
			tom.visible = true
		if _flunky:
			_flunky.visible = true
		return
	if _body:
		_body.velocity = Vector3.ZERO
	settle_camera()


func _hide_named(node: Node, piece: String) -> void:
	if piece in node.name.to_lower():
		if node is Node3D:
			(node as Node3D).visible = false
		return
	for child in node.get_children():
		_hide_named(child, piece)


func _consider_flippy() -> void:
	if _tasks == null or not _tasks.book_ready() or _tasks.met_flippy or _body == null:
		return
	var street := get_node_or_null("TutorialStreet") as Node3D
	if street == null or not street.visible:
		return
	if get_node_or_null("FlippyMovie") != null:
		return
	var flippy := street.get_node_or_null("Flippy") as ToonActor
	if flippy == null:
		flippy = TutorialFlippy.spawn(street, self)
	var here := Vector2(_body.global_position.x, _body.global_position.z)
	var there := Vector2(flippy.global_position.x, flippy.global_position.z)
	var distance := here.distance_to(there)
	var pushing := Input.is_physical_key_pressed(KEY_W) and _body.get_real_velocity().length() < 0.4
	if distance < 8.0 or (distance < 12.0 and pushing):
		var movie := TutorialFlippy.new()
		movie.name = "FlippyMovie"
		add_child(movie)
		movie.play(self, flippy)


func _idle_flippy(delta: float) -> void:
	if _cutscene:
		return
	var street := get_node_or_null("TutorialStreet") as Node3D
	if street == null:
		return
	var flippy := street.get_node_or_null("Flippy") as ToonActor
	if flippy == null or not flippy.is_visible_in_tree():
		return
	flippy.set_locomotion(0.0, false, false, delta)


func _place_line() -> void:
	if _line == null or _camera == null:
		return
	_line_left = maxf(_line_left - get_process_delta_time(), 0.0)
	if _line_left <= 0.0 or _player == null or not _player.visible:
		_line.visible = false
		return
	var head := _find(_player, "def_head")
	var point := _player.global_position + Vector3(0.0, 3.6, 0.0)
	if head:
		point = head.global_position + Vector3(0.0, 0.7, 0.0)
	if _camera.is_position_behind(point):
		_line.visible = false
		return
	_line.visible = true
	_line.reset_size()
	var screen := _camera.unproject_position(point)
	_line.position = screen - Vector2(_line.size.x * 0.5, _line.size.y + 8.0)


func _try_door() -> void:
	if _fading or _briefing == null or _body == null or _door_stopped:
		return
	var here := Vector2(_body.position.x, _body.position.z)
	if not _briefing.finished:
		_try_locked_door(here)
		return
	if not Input.is_physical_key_pressed(KEY_W):
		return
	if here.distance_to(_DOOR) > 4.5 or _body.position.x < -16.5:
		return
	_fading = true
	_locked = true
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud().add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.3)
	tween.tween_callback(func() -> void:
		_body.position = Vector3(-22.0, 0.2, -24.5)
		_heading = 180.0
		_face(_player, _heading)
		# The window pace is only the cutscene. Move him while the screen is black.
		if _flunky:
			_flunky.walk_street()
	)
	tween.tween_property(fade, "color:a", 0.0, 0.4)
	tween.tween_callback(func() -> void:
		fade.queue_free()
		_locked = false
		_fading = false
	)


func _try_locked_door(here: Vector2) -> void:
	if here.distance_to(_DOOR) > 5.2:
		_gate_armed = true
		return
	if not _gate_armed or not _pushing_the_gate():
		return
	_show_need_gags()


func _pushing_the_gate() -> bool:
	if _body == null:
		return false
	for index in _body.get_slide_collision_count():
		var hit := _body.get_slide_collision(index)
		if hit.get_collider() == _gate:
			return true
	return Input.is_physical_key_pressed(KEY_W) and Vector2(_body.position.x, _body.position.z).distance_to(_DOOR) < 2.6


func show_notice(message: String) -> void:
	_open_dialog(message)


func _show_need_gags() -> void:
	_open_dialog(_NEED_GAGS)
	_gate_armed = false


func _open_dialog(message: String) -> void:
	if _door_dialog != null:
		return
	_door_stopped = true
	if _body:
		_body.velocity = Vector3.ZERO
	var view := get_viewport().get_visible_rect().size
	var panel := TextureRect.new()
	panel.texture = load("res://assets/gui/tutorial/dialog/dialog_box.png")
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	panel.modulate = Color(1.0, 1.0, 0.75)
	panel.size = Vector2(minf(view.x * 0.46, 760.0), minf(view.y * 0.38, 440.0))
	panel.position = (view - panel.size) * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud().add_child(panel)
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector2(panel.size.x * 0.08, panel.size.y * 0.08)
	label.size = Vector2(panel.size.x * 0.84, panel.size.y * 0.42)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(label, Color(0.05, 0.05, 0.05), int(panel.size.y * 0.11), Color(0, 0, 0, 0), 0)
	panel.add_child(label)
	var button := TextureButton.new()
	button.texture_normal = load("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_UP.png")
	button.texture_hover = load("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_Rllvr.png")
	button.texture_pressed = load("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_DN.png")
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.focus_mode = Control.FOCUS_NONE
	var diameter := panel.size.y * 0.18
	button.size = Vector2(diameter, diameter)
	button.position = Vector2((panel.size.x - diameter) * 0.5, panel.size.y * 0.56)
	button.pressed.connect(_close_need_gags)
	panel.add_child(button)
	var ok := Label.new()
	ok.text = "OK"
	ok.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ok.position = Vector2(0, button.position.y + diameter)
	ok.size = Vector2(panel.size.x, panel.size.y * 0.14)
	ok.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(ok, Color(0.05, 0.05, 0.05), int(panel.size.y * 0.09), Color(0, 0, 0, 0), 0)
	panel.add_child(ok)
	_door_dialog = panel


func _close_need_gags() -> void:
	if _door_dialog:
		_door_dialog.queue_free()
		_door_dialog = null
	_door_stopped = false
	if _hq != null and _hq.inside():
		return
	if _body != null and _body.position.x < _DOOR.x + 0.4:
		_body.position.x = _DOOR.x + 1.1


func _try_tunnel() -> void:
	if _cutscene or _locked or _fading or _body == null or _tasks == null:
		return
	if not _tasks.met_flippy or get_node_or_null("TunnelExit") != null:
		return
	if not Input.is_physical_key_pressed(KEY_W):
		return
	var here := Vector2(_body.global_position.x, _body.global_position.z)
	if here.distance_to(_TUNNEL_MOUTH) > 3.4:
		return
	var exit: Node = (load("res://scenes/interiors/tutorial_tunnel.gd") as GDScript).new()
	exit.name = "TunnelExit"
	add_child(exit)
	exit.call("play", self)


func _unhandled_input(event: InputEvent) -> void:
	_steer_camera(event)
	if in_cutscene():
		return
	if _briefing == null or not _briefing.finished or _panel == null:
		return
	if _battle != null and _battle.active():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_I:
			if _book != null and _tasks != null and _tasks.book_ready():
				_book.open_to_gags()
				return
			_panel.visible = not _panel.visible
			_panel.scale = Vector2.ONE
			if _panel.visible:
				var view := get_viewport().get_visible_rect().size
				_panel.position = (view - _panel.size) * 0.5



func _build_bubble() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.96)
	box.border_color = Color(0, 0, 0)
	box.set_border_width_all(3)
	box.set_corner_radius_all(16)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	label.text = WELCOME
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(280, 0)
	ToonGui.style_label(label, Color(0.05, 0.05, 0.05), 22, Color(0, 0, 0, 0), 0)
	panel.add_child(label)
	_hud().add_child(panel)
	_bubble = panel


func _add_tag(actor: Node3D, text: String, kind: String, text_tint: Color = Color(0, 0, 0, 0)) -> void:
	# phase_3/models/props/panel, stretched over the name. No dialog border.
	# NPCs are tan with orange Impress BT. Members are gray with blue Impress BT.
	# Cogs are olive with black Remington Portable.
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	var text_color := Color(0.22, 0.22, 0.78)
	var face := ToonGui.font()
	if kind == "npc":
		box.bg_color = Color(0.86, 0.78, 0.58, 0.94)
		text_color = text_tint if text_tint.a > 0.0 else Color(0.6, 0.4, 0.2)
	elif kind == "cog":
		box.bg_color = Color(0.69, 0.72, 0.55, 0.94)
		text_color = Color(0.0, 0.0, 0.0)
		face = ToonGui.suit_font()
	else:
		box.bg_color = Color(0.55, 0.55, 0.53, 0.94)
	# The panel card is a rounded rectangle, not a capsule. The corners stay
	# shallow so a long name keeps a flat top and bottom.
	box.set_corner_radius_all(7)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ToonGui.style_label(label, text_color, 16, Color(0, 0, 0, 0), 0)
	if face:
		label.add_theme_font_override("font", face)
	panel.add_child(label)
	_hud().add_child(panel)
	# Measured once, from the resting head. Reading the live head makes the
	# card bob with the idle and the talk cycle.
	var lift := 4.6
	if kind == "cog":
		lift = 6.4
	else:
		var head := _find(actor, "def_head")
		if head:
			lift = head.global_position.y - actor.global_position.y + 1.25
	_tags.append({"label": panel, "actor": actor, "lift": lift})


func _place_tags() -> void:
	if _camera == null:
		return
	var kept: Array[Dictionary] = []
	for item in _tags:
		var label := item["label"] as Control
		# Casting a freed actor errors. Flippy is freed when he runs into the tunnel.
		var raw: Variant = item.get("actor")
		if not is_instance_valid(raw):
			if is_instance_valid(label):
				label.queue_free()
			continue
		var actor := raw as Node3D
		if actor == null or not actor.visible or not actor.is_visible_in_tree():
			if is_instance_valid(label):
				label.visible = false
			kept.append(item)
			continue
		kept.append(item)
		var lift := float(item.get("lift", 4.6))
		var point := actor.global_position + Vector3(0.0, lift, 0.0)
		if _tag_hidden(actor, point):
			label.visible = false
			continue
		_place_control(label, point, Vector2(0, -8))
		if actor == _flunky and (_body != null and _body.position.x > -16.5 or (_battle != null and _battle.hides_flunky_tag())):
			label.visible = false
	_tags = kept


func _place_bubble() -> void:
	if _bubble == null or _camera == null:
		return
	var tom := get_node_or_null("Tutorial Tom") as Node3D
	if tom == null or not tom.visible:
		_bubble.visible = false
		return
	var point := tom.global_position + Vector3(0.0, 5.1, 0.0)
	_place_control(_bubble, point, Vector2(150, -70))


func _place_control(control: Control, world: Vector3, nudge: Vector2) -> void:
	if _camera.is_position_behind(world):
		control.visible = false
		return
	control.visible = true
	control.reset_size()
	var screen := _camera.unproject_position(world)
	control.position = screen - control.size * Vector2(0.5, 1.0) + nudge


func _ready_music() -> void:
	if not FileAccess.file_exists(MUSIC_PATH):
		return
	var stream := AudioStreamOggVorbis.load_from_file(MUSIC_PATH)
	if stream == null:
		return
	stream.loop = true
	var player := AudioStreamPlayer.new()
	player.name = "ToontorialMusic"
	player.stream = stream
	player.volume_db = linear_to_db(MUSIC_VOLUME)
	add_child(player)
	player.play()


func _collect_billboards(node: Node) -> void:
	if node is Node3D and str(node.name).contains("__billboard"):
		_billboards.append({"node": node, "rest": (node as Node3D).global_transform.basis})
	for child in node.get_children():
		_collect_billboards(child)


func _face_billboards() -> void:
	if _camera == null:
		return
	for item in _billboards:
		var node := item["node"] as Node3D
		var rest := item["rest"] as Basis
		var face := Vector3(-rest.y.x, 0.0, -rest.y.z)
		var to_target := _camera.global_position - node.global_position
		to_target.y = 0.0
		if face.length() < 0.0001 or to_target.length() < 0.0001:
			continue
		var turned := node.global_transform
		turned.basis = rest.rotated(Vector3.UP, face.signed_angle_to(to_target, Vector3.UP))
		node.global_transform = turned


func _find(node: Node, wanted: String) -> Node3D:
	if node == null:
		return null
	if String(node.name) == wanted and node is Node3D:
		return node as Node3D
	for child in node.get_children():
		var found := _find(child, wanted)
		if found:
			return found
	return null
