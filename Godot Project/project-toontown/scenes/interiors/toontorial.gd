extends Node3D

## The tutorial building the way DistributedTutorialInterior leaves it after
## the intro: the furnished room, the street outside the window, Tutorial Tom
## at the desk, and the toon saved from Make a Toon standing on the rug.

const TOONTOWN_SKY := preload("res://scenes/sky/toontown_sky.gd")
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
const COLLISION_PATH := "res://assets/interiors/toontorial/collision.json"

var _camera: Camera3D
var _player: ToonActor
var _body: CharacterBody3D
var _heading := START_HEADING
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
var _flunky: Flunky
var _battle: StreetBattle


func _ready() -> void:
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
	_start_battle()
	_place_camera()


func _process(delta: float) -> void:
	TOONTOWN_SKY.ensure(self, "tt")
	if not _cutscene:
		_place_camera()
	_face_billboards()
	_place_tags()
	if not _cutscene and not _welcome_done:
		_place_bubble()
	elif _bubble and (_cutscene or _welcome_done):
		_bubble.visible = false


func _physics_process(delta: float) -> void:
	if _locked:
		return
	_walk(delta)
	_approach_tom()
	_try_door()
	_try_battle()


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
		_add_tag(_player, style.display_name(), Color(0.45, 0.62, 0.95))
	var tom := _spawn(_tom_style(), TOM_POSITION, TOM_HEADING, self)
	_add_tag(tom, "Tutorial Tom", Color(0.92, 0.32, 0.18))


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
	# TutorialBuildingAI: ("dll", "ms", "m", "m", 7, 0, 7, 7, 2, 6, 2, 6, 2, 16)
	var style := ToonStyle.new()
	style.first_name = "Tutorial"
	style.last_name = "Tom"
	style.gender = "m"
	style.head = "dll"
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
	if _body.is_on_floor():
		_body.velocity.y = -2.0
	else:
		_body.velocity.y -= 80.0 * delta
	_body.move_and_slide()
	if _body.position.y < -1.0:
		_body.velocity = Vector3.ZERO
		_body.position = Vector3(-22.0, 0.2, -24.5)
		_heading = 180.0
	_face(_player, _heading)
	# S plays the cycle backward. A and D turn, and still play the cycle forward.
	_player.set_locomotion(speed != 0.0 or turning, speed < 0.0, delta)


func _place_camera() -> void:
	if _camera == null:
		return
	var feet := START_POSITION
	var heading := START_HEADING
	if _player:
		feet = _player.global_position
		heading = _heading
	var height := 3.0
	if _player:
		var head := _find(_player, "def_head")
		if head:
			height = maxf(head.global_position.y - feet.y, 3.0)
	var forward := _forward(heading)
	var eye := feet + Vector3(0.0, height, 0.0)
	_camera.global_position = eye - forward * 9.0 * (height / 3.0)
	_camera.look_at(eye + forward * 1.5, Vector3.UP)


func _face(actor: Node3D, heading: float) -> void:
	# show_style stands the Z-up parts up and adds a turn for Make a Toon.
	# Replace that with the Panda heading. Positive H is a left turn.
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


func hud() -> CanvasLayer:
	return _hud()


func set_cutscene(active: bool) -> void:
	_cutscene = active
	_locked = active


func dismiss_welcome() -> void:
	_welcome_done = true
	if _bubble:
		_bubble.visible = false


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
	_meter.set_hp(_loadout.hp, _loadout.max_hp)
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


func tasks() -> ToonTasks:
	return _tasks


func shticker() -> ShtickerBook:
	return _book


func _spawn_flunky() -> void:
	_flunky = Flunky.new()
	_flunky.name = "Flunky"
	add_child(_flunky)
	_flunky.pace_outside()
	_add_tag(_flunky, "Flunky\nBossbot\nLevel 1", Color(0.95, 0.95, 0.95))


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


func _try_door() -> void:
	if _fading or _briefing == null or not _briefing.finished or _body == null:
		return
	if not Input.is_physical_key_pressed(KEY_W):
		return
	var door := Vector2(-14.2, -24.5)
	var here := Vector2(_body.position.x, _body.position.z)
	if here.distance_to(door) > 4.5 or _body.position.x < -16.5:
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


func _unhandled_input(event: InputEvent) -> void:
	if _briefing == null or not _briefing.finished or _panel == null:
		return
	if _battle != null and _battle.active():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_I:
			if _book != null and _tasks != null and _tasks.has_book:
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


func _add_tag(actor: Node3D, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ToonGui.style_label(label, color, 20, Color(0, 0, 0), 3)
	_hud().add_child(label)
	_tags.append({"label": label, "actor": actor})


func _place_tags() -> void:
	if _camera == null:
		return
	for item in _tags:
		var label := item["label"] as Label
		var actor := item["actor"] as Node3D
		var head := _find(actor, "def_head")
		var point := actor.global_position + Vector3(0, 3.2, 0)
		if actor == _flunky:
			point = actor.global_position + Vector3(0, 5.4, 0)
		elif head:
			point = head.global_position + Vector3(0, 0.45, 0)
		_place_control(label, point, Vector2(0, -8))
		if actor == _flunky and (_body != null and _body.position.x > -16.5 or (_battle != null and _battle.hides_flunky_tag())):
			label.visible = false


func _place_bubble() -> void:
	if _bubble == null or _camera == null:
		return
	var tom := get_node_or_null("Tutorial Tom") as Node3D
	if tom == null:
		_bubble.visible = false
		return
	var head := _find(tom, "def_head")
	var point := tom.global_position + Vector3(0, 4.0, 0)
	if head:
		point = head.global_position + Vector3(0, 0.8, 0)
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
