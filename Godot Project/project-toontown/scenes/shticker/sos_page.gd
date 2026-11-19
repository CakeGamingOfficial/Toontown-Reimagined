extends Control

## NPCFriendPage. The title is SOS Toons. Sixteen cards, four across.
## A card you hold shows its front. An empty slot shows the playing-card back.
## The book page does not offer Call. That button is only in battle.
## phase_3.5 name_star is not in the exported gui, so each star is drawn
## in the original brown at the original place on the card.

signal tab_ready(icon: Texture2D)

const _SLOTS := 16
const _REWARDS := preload("res://scenes/cog_hq/boss_rewards.gd")
const _CARD := "res://assets/minigames/playing_card.glb"
const _DNA := "res://scenes/shticker/sos_dna.json"
const _MINNIE := preload("res://assets/gui/picnic/MinnieFont.ttf")
const _INK := Color(0.3, 0.25, 0.2, 1)
const _STAR := Color(0.502, 0.251, 0.251, 1)
const _TRACKS: PackedStringArray = [
	"toon-up", "trap", "lure", "sound", "throw", "squirt", "drop",
	"restock", "toons hit", "cogs miss",
]

var _slots: Array[Control] = []
var _fronts: Array[TextureRect] = []
var _backs: Array[TextureRect] = []
var _kinds: Array[Label] = []
var _names: Array[Label] = []
var _counts: Array[Label] = []
var _heads: Array[TextureRect] = []
var _stars: Array = []
var _front_tex: Texture2D
var _back_tex: Texture2D
static var _shared_front: Texture2D
static var _shared_back: Texture2D
var _dna: Dictionary = {}
var _portraits: Dictionary = {}
var _baking: Dictionary = {}
var _page := Vector2.ZERO


func _ready() -> void:
	name = "SOSToons"
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	var title := Label.new()
	title.name = "Title"
	title.text = "SOS Toons"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(title)
	for index in _SLOTS:
		var card := Control.new()
		card.mouse_filter = MOUSE_FILTER_IGNORE
		card.set_meta("npc", -1)
		add_child(card)
		var back := TextureRect.new()
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		back.mouse_filter = MOUSE_FILTER_IGNORE
		card.add_child(back)
		var front := TextureRect.new()
		front.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		front.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		front.mouse_filter = MOUSE_FILTER_IGNORE
		front.visible = false
		card.add_child(front)
		var kind := _label("")
		kind.add_theme_font_override("font", _MINNIE)
		card.add_child(kind)
		var head := TextureRect.new()
		head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		head.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		head.mouse_filter = MOUSE_FILTER_IGNORE
		head.visible = false
		card.add_child(head)
		var cog_name := _label("")
		card.add_child(cog_name)
		var count := _label("")
		card.add_child(count)
		var stars: Array[Polygon2D] = []
		for _star in 5:
			var mark := Polygon2D.new()
			mark.color = _STAR
			mark.visible = false
			card.add_child(mark)
			stars.append(mark)
		_slots.append(card)
		_backs.append(back)
		_fronts.append(front)
		_kinds.append(kind)
		_heads.append(head)
		_names.append(cog_name)
		_counts.append(count)
		_stars.append(stars)
	_load_dna()
	_bake_plates()


func layout(page_size: Vector2) -> void:
	_page = page_size
	if _slots.size() < _SLOTS:
		return
	var title_h := page_size.y * 0.1
	var card_h := (page_size.y - title_h) * 0.22
	var card_w := card_h * (4.55 / 3.32)
	var gap_x := card_w * 0.08
	var gap_y := card_h * 0.06
	var grid := Vector2(card_w * 4.0 + gap_x * 3.0, card_h * 4.0 + gap_y * 3.0)
	var origin := Vector2((page_size.x - grid.x) * 0.5, title_h + (page_size.y - title_h - grid.y) * 0.35)
	for index in _SLOTS:
		var card := _slots[index]
		var col := index % 4
		var row := int(index / 4)
		card.position = origin + Vector2(float(col) * (card_w + gap_x), float(row) * (card_h + gap_y))
		card.size = Vector2(card_w, card_h)
		_backs[index].position = Vector2.ZERO
		_backs[index].size = card.size
		_fronts[index].position = Vector2.ZERO
		_fronts[index].size = card.size
		_place_label(_kinds[index], card.size, 0.02, 0.04, 0.96, 0.16, int(card_h * 0.13))
		_place_label(_names[index], card.size, 0.06, 0.58, 0.88, 0.16, int(card_h * 0.11))
		_place_label(_counts[index], card.size, 0.06, 0.74, 0.88, 0.12, int(card_h * 0.1))
		var head_side := card_h * 0.34
		_heads[index].size = Vector2(head_side, head_side)
		_heads[index].position = Vector2((card_w - head_side) * 0.5, card_h * 0.22)
		var radius := card_h * 0.045
		var stars: Array = _stars[index]
		for star_index in stars.size():
			var mark := stars[star_index] as Polygon2D
			mark.polygon = _star_points(radius)
			# name_star sits at x = 1.1 - i * 0.24, z = -1.2, on a card 4.55 by 3.32.
			var local_x := (1.1 - float(star_index) * 0.24) / 4.55
			var local_z := -1.2 / 3.32
			mark.position = Vector2(card_w * (0.5 + local_x), card_h * (0.5 - local_z))


func refresh() -> void:
	if _slots.size() < _SLOTS:
		return
	var held: Array = _REWARDS.sos_cards()
	for index in _SLOTS:
		var card: Dictionary = {}
		if index < held.size() and held[index] is Dictionary:
			card = held[index]
		_show_slot(index, card)
	if _page != Vector2.ZERO:
		layout(_page)


func _show_slot(index: int, card: Dictionary) -> void:
	var filled := not card.is_empty()
	_fronts[index].visible = filled
	_backs[index].visible = not filled
	_kinds[index].visible = filled
	_names[index].visible = filled
	_counts[index].visible = filled
	_heads[index].visible = false
	var stars: Array = _stars[index]
	for mark in stars:
		(mark as CanvasItem).visible = false
	_slots[index].set_meta("npc", -1)
	if not filled:
		return
	var npc_id := int(card.get("id", 0))
	var track := clampi(int(card.get("track", 0)), 0, _TRACKS.size() - 1)
	var level := int(card.get("level", 0))
	var kind := _TRACKS[track]
	if track == 7:
		if level == -1:
			kind += " All"
		elif level >= 0 and level < 7:
			kind += " " + _TRACKS[level]
	_kinds[index].text = kind.to_upper()
	_names[index].text = String(card.get("name", ""))
	var calls := int(card.get("calls", 0))
	_counts[index].text = "%d Remaining" % calls
	var rarity := clampi(int(card.get("rarity", 0)), 0, stars.size())
	for star_index in stars.size():
		(stars[star_index] as CanvasItem).visible = star_index < rarity
	_slots[index].set_meta("npc", npc_id)
	_mount_head(index, npc_id)


func _mount_head(index: int, npc_id: int) -> void:
	if _portraits.has(npc_id):
		var ready: Variant = _portraits[npc_id]
		if ready is Texture2D:
			_heads[index].texture = ready
			_heads[index].visible = true
		return
	var style := _style_for(npc_id)
	if style == null:
		return
	_bake_head(npc_id, style)


func _bake_head(npc_id: int, style: ToonStyle) -> void:
	if bool(_baking.get(npc_id, false)):
		return
	_baking[npc_id] = true
	var shot := _head_shot(style)
	var port := shot["port"] as SubViewport
	var actor := shot["actor"] as ToonActor
	var camera := shot["camera"] as Camera3D
	await get_tree().process_frame
	if not is_instance_valid(port) or not is_instance_valid(actor) or not is_instance_valid(camera):
		_baking.erase(npc_id)
		return
	var focus := actor.global_position + Vector3(0.0, 3.2, 0.0)
	var neck := actor.find_child("def_head", true, false) as Node3D
	if neck != null:
		focus = neck.global_position + Vector3(0.0, 0.24, 0.0)
	camera.global_position = focus + Vector3(0.0, 0.0, 4.0)
	camera.look_at(focus, Vector3.UP)
	port.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	var image: Image = null
	if is_instance_valid(port) and port.get_texture() != null:
		image = port.get_texture().get_image()
	if is_instance_valid(port):
		port.queue_free()
	_baking.erase(npc_id)
	if image == null or image.is_empty():
		return
	var portrait := ImageTexture.create_from_image(image)
	_portraits[npc_id] = portrait
	for index in _slots.size():
		if int(_slots[index].get_meta("npc", -1)) != npc_id:
			continue
		_heads[index].texture = portrait
		_heads[index].visible = true


func _head_shot(style: ToonStyle) -> Dictionary:
	var port := SubViewport.new()
	port.transparent_bg = true
	port.own_world_3d = true
	port.size = Vector2i(180, 180)
	port.gui_disable_input = true
	port.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(port)
	var stage := Node3D.new()
	port.add_child(stage)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.15, 1.15, 1.15)
	env.ambient_light_energy = 1.15
	world.environment = env
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.05
	key.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	stage.add_child(key)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.7
	camera.near = 0.05
	camera.current = true
	stage.add_child(camera)
	var actor := ToonActor.new()
	actor.load_extra_clips = false
	actor.footsteps = false
	stage.add_child(actor)
	actor.show_style(style)
	_keep_head(actor)
	actor.set_locomotion(0.0, false, false, 0.0)
	return {"port": port, "actor": actor, "camera": camera}


func _keep_head(actor: Node) -> void:
	var neck := actor.find_child("def_head", true, false)
	_keep_head_walk(actor, neck)


func _keep_head_walk(node: Node, neck: Node) -> void:
	if node is MeshInstance3D and (neck == null or not neck.is_ancestor_of(node)):
		(node as MeshInstance3D).visible = false
	for child in node.get_children():
		_keep_head_walk(child, neck)


func _style_for(npc_id: int) -> ToonStyle:
	var row: Variant = _dna.get(str(npc_id), [])
	if not (row is Array):
		return null
	var dna: Array = row
	if dna.size() < 14:
		return null
	var style := ToonStyle.new()
	style.head = String(dna[0])
	style.torso = String(dna[1])
	style.legs = String(dna[2])
	style.gender = String(dna[3])
	style.arm_color = int(dna[4])
	style.glove_color = int(dna[5])
	style.leg_color = int(dna[6])
	style.head_color = int(dna[7])
	style.top_tex = int(dna[8])
	style.top_color = int(dna[9])
	style.bot_tex = int(dna[12])
	style.bot_color = int(dna[13])
	return style


func _bake_plates() -> void:
	if _shared_front != null and _shared_back != null:
		_apply_plates(_shared_front, _shared_back)
		return
	var packed := load(_CARD) as PackedScene
	if packed == null:
		return
	var front_view := _plate_view(packed, false)
	var back_view := _plate_view(packed, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_front_tex = _copy_plate(front_view)
	_back_tex = _copy_plate(back_view)
	if is_instance_valid(front_view):
		front_view.queue_free()
	if is_instance_valid(back_view):
		back_view.queue_free()
	if _front_tex != null and _back_tex != null:
		_shared_front = _front_tex
		_shared_back = _back_tex
	_apply_plates(_front_tex, _back_tex)


func _apply_plates(front: Texture2D, back: Texture2D) -> void:
	_front_tex = front
	_back_tex = back
	for index in _fronts.size():
		_fronts[index].texture = _front_tex
		_backs[index].texture = _back_tex
	if _back_tex != null:
		tab_ready.emit(_back_tex)


func _plate_view(packed: PackedScene, back: bool) -> SubViewport:
	var port := SubViewport.new()
	port.transparent_bg = true
	port.own_world_3d = true
	port.size = Vector2i(300, 220)
	port.gui_disable_input = true
	port.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(port)
	var stage := Node3D.new()
	port.add_child(stage)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.2
	world.environment = env
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.1
	key.rotation_degrees = Vector3(-50.0, 20.0, 0.0)
	stage.add_child(key)
	var holder := Node3D.new()
	# Pitch +90 faces card_back at a camera on +Z. Pitch -90 faces card_front.
	holder.rotation_degrees.x = 90.0 if back else -90.0
	stage.add_child(holder)
	var model := packed.instantiate() as Node3D
	holder.add_child(model)
	model.scale = Vector3(0.7, 0.7, 0.7)
	model.rotate_object_local(Vector3.UP, PI)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.7
	camera.near = 0.05
	camera.current = true
	# The camera is not in the tree yet. look_at needs a parent and stalls the
	# place load when the editor breaks on that error.
	camera.look_at_from_position(Vector3(0.0, 0.0, 4.0), Vector3.ZERO, Vector3.UP)
	stage.add_child(camera)
	return port


func _copy_plate(port: SubViewport) -> Texture2D:
	if not is_instance_valid(port) or port.get_texture() == null:
		return null
	var image := port.get_texture().get_image()
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _load_dna() -> void:
	if not FileAccess.file_exists(_DNA):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_DNA))
	if parsed is Dictionary:
		_dna = parsed


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = MOUSE_FILTER_IGNORE
	ToonGui.style_label(label, _INK, 14, Color(0, 0, 0, 0), 0)
	return label


func _place_label(label: Label, card: Vector2, x: float, y: float, width: float, height: float, px: int) -> void:
	label.position = Vector2(card.x * x, card.y * y)
	label.size = Vector2(card.x * width, card.y * height)
	label.add_theme_font_size_override("font_size", maxi(px, 8))
	label.add_theme_color_override("font_color", _INK)


func _star_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in 10:
		var angle := -PI * 0.5 + float(point) * PI / 5.0
		var reach := radius if point % 2 == 0 else radius * 0.42
		points.append(Vector2(cos(angle), sin(angle)) * reach)
	return points
