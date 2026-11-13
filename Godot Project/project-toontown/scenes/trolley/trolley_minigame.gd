extends Node3D

## One trolley minigame. The ride shows the rules, then begin() starts the clock.
## finished reports the raw score. The ride applies the safezone multiplier.

signal finished(score: int)

const _CLOCK := preload("res://assets/gui/purchase/alarm_clock.png")

var title := "Trolley Game"
var instructions := ""
var duration := 60.0
var score := 0
var playing := false
var _over := false
var _camera: Camera3D
var _toon: ToonActor
const _RIDE := preload("res://scenes/trolley/trolley_ride.gd")

var _remotes: RemoteToons
var _tags: Nametags
var _last_feet := Vector3.ZERO
var _hud: Label
var _clock_face: TextureRect
var _clock_num: Label
var _board: MinigameBoard
var _shared := RandomNumberGenerator.new()
var _shared_ready := false


func shared_int(span: int) -> int:
	_arm_shared()
	if span <= 1:
		return 0
	return _shared.randi() % span


func shared_range(low: int, high: int) -> int:
	_arm_shared()
	return _shared.randi_range(low, high)


func shared_float(low: float, high: float) -> float:
	_arm_shared()
	return _shared.randf_range(low, high)


func shared_shuffle(items: Array) -> void:
	_arm_shared()
	for index in range(items.size() - 1, 0, -1):
		var swap := _shared.randi() % (index + 1)
		var kept: Variant = items[index]
		items[index] = items[swap]
		items[swap] = kept


func _arm_shared() -> void:
	if _shared_ready:
		return
	_shared_ready = true
	var state := ToonNet.latest("trolley:%d" % ToonNet.district_id())
	var seed := int(state.get("seed", 1))
	if seed == 0:
		seed = 1
	_shared.seed = seed


func _ready() -> void:
	_stage()
	_build()


func begin() -> void:
	playing = true
	if _clock_face != null:
		_clock_face.visible = true
		_clock_num.visible = true
		_layout_clock(true)
	# The slingshot board stays hidden until the first landing.
	if _board != null and _board.kind != "slingshot":
		_board.visible = true
		_board.prime(score)
		_board.relayout()


func _build() -> void:
	pass


func _play(_delta: float) -> void:
	pass


func _process(delta: float) -> void:
	_place_tags()
	if not playing:
		return
	duration -= delta
	_layout_clock(false)
	if duration <= 0.0:
		_end()
		return
	_play(delta)
	_note_rider(delta)
	if not is_inside_tree() or _over:
		return
	if _hud != null and _hud.visible:
		_hud.text = "Score: %d" % score
	if _board != null:
		_board.sync(score)


func _end() -> void:
	if _over:
		return
	_over = true
	playing = false
	if _board != null and is_instance_valid(_board):
		_board.sync(score)
	# The score, timer, and other play widgets sit on CanvasLayers. Hiding the
	# game node does not hide those, so they would stay up over the gag shop.
	_hide_play_ui(self)
	_silence_ids(self)
	process_mode = Node.PROCESS_MODE_DISABLED
	finished.emit(score)


func _hide_play_ui(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
		else:
			_hide_play_ui(child)


func _silence_ids(node: Node) -> void:
	if node.has_meta("av"):
		node.set_meta("av", 0)
	for child in node.get_children():
		_silence_ids(child)


## Hides the red stand-in and adds the original display for this game. Hidden until begin().
func show_board(kind: String) -> void:
	if _hud != null:
		_hud.visible = false
	if _board != null:
		return
	_board = MinigameBoard.new()
	var layer := _hud.get_parent()
	layer.add_child(_board)
	_board.visible = false
	_board.open(kind)
	if _clock_face != null:
		layer.move_child(_clock_face, -1)
		layer.move_child(_clock_num, -1)


func _stage() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.74, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.8)
	env.ambient_light_energy = 1.1
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 55.0
	_camera.far = 2500.0
	add_child(_camera)
	var floor := MeshInstance3D.new()
	floor.name = "StageFloor"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(80, 1, 80)
	floor.mesh = mesh
	floor.position = Vector3(0, -0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.72, 0.32)
	floor.material_override = mat
	add_child(floor)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(24, 16)
	_hud.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
	_hud.add_theme_font_size_override("font_size", 36)
	layer.add_child(_hud)
	# ToontownTimer.posInTopRightCorner, scale 0.45, alarm clock from clock_gui.
	_clock_face = TextureRect.new()
	_clock_face.texture = _CLOCK
	_clock_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_clock_face.stretch_mode = TextureRect.STRETCH_SCALE
	_clock_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_face.visible = false
	layer.add_child(_clock_face)
	_clock_num = Label.new()
	_clock_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_num.visible = false
	layer.add_child(_clock_num)
	var view := get_viewport()
	if not view.size_changed.is_connected(_on_view_resized):
		view.size_changed.connect(_on_view_resized)


func _on_view_resized() -> void:
	if _clock_face != null and _clock_face.visible:
		_layout_clock(true)
	if _board != null:
		_board.relayout()


func _layout_clock(force: bool) -> void:
	if _clock_face == null or not _clock_face.visible:
		return
	var clock_w := 0.7417 * 0.45
	var clock_h := 0.7292 * 0.45
	var clock := _aspect_rect(1.16, 0.83, clock_w, clock_h)
	_clock_face.position = clock.position
	_clock_face.size = clock.size
	var whole := maxi(int(ceil(duration)), 0)
	if not force and _clock_num.text == str(whole):
		return
	_clock_num.text = str(whole)
	var late := whole <= 5
	var text_scale := 0.27
	if str(whole).length() <= 1:
		text_scale = 0.34
	elif str(whole).length() >= 3:
		text_scale = 0.2
	ToonGui.style_label(_clock_num, Color(1, 0, 0, 1) if late else Color(0, 0, 0, 1), _font_px(text_scale * 0.45), Color(0, 0, 0, 0), 0)
	# The white face sits a little left of and below the middle of alarm_clock.
	var face_x := 1.16 + (28.5 / 61.0 - 0.5) * clock_w
	var face_z := 0.83 - (33.5 / 61.0 - 0.5) * clock_h
	var box := _aspect_rect(face_x, face_z, 0.26, 0.16)
	_clock_num.position = box.position
	_clock_num.size = box.size


func _aspect_rect(ax: float, az: float, aw: float, ah: float) -> Rect2:
	var view := get_viewport().get_visible_rect().size
	var aspect := view.x / maxf(view.y, 1.0)
	var unit := view.y * 0.5
	var rect := Vector2(aw * unit, ah * unit)
	var center := Vector2((ax / aspect + 1.0) * 0.5 * view.x, (1.0 - az) * 0.5 * view.y)
	return Rect2(center - rect * 0.5, rect)


func _font_px(aspect_height: float) -> int:
	return maxi(int(round(aspect_height * get_viewport().get_visible_rect().size.y * 0.5)), 8)


func _make_toon(at: Vector3) -> ToonActor:
	_toon = ToonActor.new()
	_toon.name = "Rider"
	add_child(_toon)
	var style := ToonRoster.selected_style()
	if style != null:
		_toon.show_style(style)
	_toon.position = at
	_toon.set_meta("av", ToonRoster.avatar_id())
	_last_feet = _toon.global_position
	_remotes = RemoteToons.new()
	_remotes.name = "RemoteToons"
	add_child(_remotes)
	_remotes.bind(self, _toon, _toon, null)
	var avatar_layer := CanvasLayer.new()
	avatar_layer.name = "AvatarHud"
	avatar_layer.layer = 12
	add_child(avatar_layer)
	var avatar_panel := (load("res://scenes/toons/toon_avatar_panel.gd") as GDScript).new() as Control
	avatar_panel.name = "ToonAvatarPanel"
	avatar_layer.add_child(avatar_panel)
	_tags = Nametags.new()
	_tags.name = "RiderTags"
	_tags.camera = _camera
	var tag_layer := CanvasLayer.new()
	tag_layer.layer = 30
	add_child(tag_layer)
	_tags.layer = tag_layer
	add_child(_tags)
	var called := ""
	if style != null:
		called = style.display_name()
	if called != "":
		_tags.add(_toon, called, "player")
	return _toon


func _place_tags() -> void:
	if _tags == null:
		return
	if _camera != null:
		_tags.camera = _camera
	_tags.place()


func party_size() -> int:
	return clampi(maxi(int(_RIDE.players), _RIDE.riders.size()), 1, 4)


func party_index() -> int:
	var me := ToonNet.peer_id()
	var cards: Array = _RIDE.riders
	for i in cards.size():
		var card: Dictionary = cards[i]
		if int(card.get("peer", -2)) == me:
			return i
	return 0


func party_peer(index: int) -> int:
	var cards: Array = _RIDE.riders
	if index >= 0 and index < cards.size():
		var card: Dictionary = cards[index]
		return int(card.get("peer", ToonNet.peer_id()))
	return ToonNet.peer_id()


func party_name(index: int) -> String:
	var cards: Array = _RIDE.riders
	if index >= 0 and index < cards.size():
		var card: Dictionary = cards[index]
		var label := String(card.get("name", ""))
		if label != "":
			return label
	return "Toon"


func lineup_x(span: float) -> float:
	var count := party_size()
	if count <= 1:
		return 0.0
	return (float(party_index()) - float(count - 1) * 0.5) * span


func other_toons() -> Array[ToonActor]:
	var found: Array[ToonActor] = []
	for child in get_children():
		if child == _toon or not (child is ToonActor):
			continue
		var actor := child as ToonActor
		if actor.visible:
			found.append(actor)
	return found


func panda_of(node: Node3D) -> Vector2:
	return Vector2(node.position.x, -node.position.z)


func _note_rider(delta: float) -> void:
	if _remotes == null or _toon == null or not is_instance_valid(_toon):
		return
	var step := 0.0
	if delta > 0.0:
		step = _toon.global_position.distance_to(_last_feet) / delta
	_last_feet = _toon.global_position
	var speed := 0.0
	if step >= 8.0:
		speed = 9.0
	elif step > 0.5:
		speed = 4.0
	_remotes.note(RemoteToons.facing(_toon), speed, false, false, not _toon.visible)


func _stick() -> Vector2:
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return Vector2.ZERO
	var x := 0.0
	var y := 0.0
	if Keybinds.held("left") or Input.is_physical_key_pressed(KEY_LEFT):
		x -= 1.0
	if Keybinds.held("right") or Input.is_physical_key_pressed(KEY_RIGHT):
		x += 1.0
	if Keybinds.held("forward") or Input.is_physical_key_pressed(KEY_UP):
		y += 1.0
	if Keybinds.held("back") or Input.is_physical_key_pressed(KEY_DOWN):
		y -= 1.0
	return Vector2(x, y)


func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_node.material_override = mat
	return mesh_node


func _hide_floor() -> void:
	var floor := get_node_or_null("StageFloor")
	if floor != null:
		floor.visible = false


## Panda is Z-up. The exported glb root applies the same conversion as the playground.
func _panda(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, z, -y)


func _prop(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as Node3D


func _show(path: String) -> Node3D:
	_hide_floor()
	var node := _prop(path)
	if node != null:
		add_child(node)
	return node


func _spawn(path: String, x: float, y: float, z: float, scale: float = 1.0) -> Node3D:
	var node := _prop(path)
	if node == null:
		return null
	add_child(node)
	node.position = _panda(x, y, z)
	if scale != 1.0:
		node.scale = Vector3(scale, scale, scale)
	return node


func _flunky(x: float, y: float, z: float) -> Node3D:
	var cog := _prop("res://assets/cogs/flunky.glb")
	if cog == null:
		cog = _box(Vector3(1.2, 2.4, 0.8), Color(0.12, 0.12, 0.16))
	add_child(cog)
	cog.position = _panda(x, y, z)
	return cog


func _aim(x: float, y: float, z: float, at_x: float, at_y: float, at_z: float) -> void:
	_camera.position = _panda(x, y, z)
	_camera.look_at(_panda(at_x, at_y, at_z), Vector3.UP)


func _tint(root: Node, color: Color) -> void:
	if root is MeshInstance3D:
		var mesh_node := root as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		var current := mesh_node.get_active_material(0)
		if current is StandardMaterial3D:
			mat.albedo_texture = (current as StandardMaterial3D).albedo_texture
			mat.transparency = (current as StandardMaterial3D).transparency
		mesh_node.material_override = mat
	for child in root.get_children():
		_tint(child, color)


func _load_sfx(file_name: String) -> AudioStream:
	var ogg := "res://assets/audio/sfx/%s.ogg" % file_name
	if FileAccess.file_exists(ogg):
		return AudioStreamOggVorbis.load_from_file(ogg)
	var mp3 := "res://assets/audio/sfx/%s.mp3" % file_name
	if FileAccess.file_exists(mp3):
		return AudioStreamMP3.load_from_file(mp3)
	return null


func _sfx(file_name: String, volume: float = 1.0) -> void:
	var stream := _load_sfx(file_name)
	if stream == null:
		return
	var player := ToonAudio.effect_player()
	player.stream = stream
	player.volume_db = linear_to_db(maxf(volume, 0.001))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _loop_sfx(file_name: String, volume: float) -> AudioStreamPlayer:
	var stream := _load_sfx(file_name)
	if stream == null:
		return null
	stream.set("loop", true)
	var player := ToonAudio.effect_player()
	player.stream = stream
	player.volume_db = linear_to_db(maxf(volume, 0.001))
	add_child(player)
	player.play()
	return player


func _ball(radius: float, color: Color) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh_node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_node.material_override = mat
	return mesh_node
