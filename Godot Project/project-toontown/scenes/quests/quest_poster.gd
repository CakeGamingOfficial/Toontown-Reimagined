class_name QuestPoster
extends Control

## One scroll from the Shticker Book task page, using the original quest card.

const _CARD := preload("res://assets/gui/tutorial/book/questCard.png")
const _FRAME := preload("res://assets/gui/tutorial/book/questPictureFrame.png")
const _TROLLEY := preload("res://assets/gui/tutorial/book/trolley.png")
const _COG := preload("res://assets/gui/tutorial/book/cog_icon.png")
## RecoverItemQuest uses the stickerbook package, scaled to 0.12 inside the 0.15 frame.
const _PACKAGE := preload("res://assets/gui/tutorial/book/package.png")
const _FRIENDS := preload("res://assets/gui/friends/FriendsBox_Closed.png")
const _CLARA := preload("res://assets/gui/quests/clarabelleCow.png")
const _BUILDING := preload("res://assets/gui/quests/COG_building.png")
const _FACTORY := preload("res://assets/gui/quests/factoryIcon2.png")
const _MINT := preload("res://assets/gui/quests/CashBotMint.png")
const _ARM := preload("res://assets/gui/quests/CogArmIcon2.png")
const _SKELE := preload("res://assets/gui/quests/skelecog5.png")
const _VP := preload("res://assets/gui/quests/BossHead3Icon.png")
const _CFO := preload("res://assets/gui/quests/CashBotBossHeadIcon.png")
const _FEATHER := preload("res://assets/gui/tutorial/gags/inventory_feather.png")
const _HORN := preload("res://assets/gui/tutorial/gags/inventory_bikehorn.png")
const _CORP := preload("res://assets/gui/cogs/CorpIcon.png")
const _LEGAL := preload("res://assets/gui/cogs/LegalIcon.png")
const _MONEY := preload("res://assets/gui/cogs/MoneyIcon.png")
const _SALES := preload("res://assets/gui/cogs/SalesIcon.png")
## QuestPoster colors the picture square. Cog tasks are blue, the trolley is light blue.
const _BLUE := Color(0.45, 0.45, 0.8)
const _LIGHT_BLUE := Color(0.42, 0.671, 1.0)
const _GREEN := Color(0.45, 0.8, 0.45)
const _BROWN := Color(0.52, 0.42, 0.22)
## Suit.medallionColors. A department picture is the cog icon tinted with these.
const _CORP_TINT := Color(0.863, 0.776, 0.769)
const _SALES_TINT := Color(0.843, 0.745, 0.745)
const _LEGAL_TINT := Color(0.749, 0.776, 0.824)
const _MONEY_TINT := Color(0.749, 0.769, 0.749)
const _SHOPS := "res://assets/interiors/shops/shops.json"
## A finished task tints the scroll lightGreen and the headline (0, 0.3, 0).
const _LIGHT_GREEN := Color(0.784, 1.0, 0.863)
const _DONE := Color(0.0, 0.3, 0.0)
const _INK := Color(0.3, 0.25, 0.2)
## QuestPoster.colors rewardRed.
const _REWARD := Color(0.8, 0.3, 0.3)

var _card: TextureRect
var _headline: Label
var _caption: Label
var _where: Label
var _progress: Label
var _reward: Label
var _quest_id: Label
var _reward_text := ""
var _choosing := false
var _return: Label
var _left_name: Label
var _right_name: Label
var _aux: Label
var _badge: Panel
var _count: Label
var _badge_box: StyleBoxFlat
var _frame: TextureRect
var _icon: TextureRect
var _right_frame: TextureRect
var _right_icon: TextureRect
var _port: SubViewport
var _right_port: SubViewport
var _officer_port: SubViewport
static var _npc_dna: Dictionary = {}
static var _npcs_ready := false
var _head_code := ""
var _icon_fit := 0.8
var _right_fit := 0.8
var _complete := false
var _split := false
var _hovered := false
var _trackable := false
var _tracked := false
var _task_id := 0
var _tracking: Label
var _hover_tween: Tween
var _rest_pos := Vector2.ZERO
var _rest_size := Vector2.ZERO


func _init() -> void:
	# The book cover sits under the posters and would take the hover otherwise.
	mouse_filter = MOUSE_FILTER_STOP
	mouse_entered.connect(_hover_in)
	mouse_exited.connect(_hover_out)
	var card := TextureRect.new()
	_card = card
	card.texture = _CARD
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.mouse_filter = MOUSE_FILTER_IGNORE
	card.set_anchors_preset(PRESET_FULL_RECT)
	card.offset_left = 0
	card.offset_top = 0
	card.offset_right = 0
	card.offset_bottom = 0
	add_child(card)
	_frame = TextureRect.new()
	_frame.texture = _FRAME
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.mouse_filter = MOUSE_FILTER_IGNORE
	_frame.visible = false
	add_child(_frame)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = MOUSE_FILTER_IGNORE
	_icon.visible = false
	add_child(_icon)
	_right_frame = TextureRect.new()
	_right_frame.texture = _FRAME
	_right_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_right_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_right_frame.mouse_filter = MOUSE_FILTER_IGNORE
	_right_frame.visible = false
	add_child(_right_frame)
	_right_icon = TextureRect.new()
	_right_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_right_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_right_icon.mouse_filter = MOUSE_FILTER_IGNORE
	_right_icon.visible = false
	add_child(_right_icon)
	_return = _label()
	_left_name = _label()
	_right_name = _label()
	_aux = _label()
	_aux.visible = false
	_return.visible = false
	_left_name.visible = false
	_right_name.visible = false
	_badge = Panel.new()
	_badge.mouse_filter = MOUSE_FILTER_IGNORE
	_badge_box = StyleBoxFlat.new()
	_badge_box.bg_color = Color(0.82, 0.16, 0.16)
	_badge.add_theme_stylebox_override("panel", _badge_box)
	add_child(_badge)
	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.mouse_filter = MOUSE_FILTER_IGNORE
	_badge.add_child(_count)
	_tracking = _label()
	_tracking.text = "Tracking"
	_tracking.visible = false
	_tracking.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_headline = _label()
	_caption = _label()
	_where = _label()
	_progress = _label()
	_reward = _label()
	_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_reward.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_reward.visible = false
	_quest_id = _label()
	_quest_id.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_quest_id.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quest_id.visible = false
	layout(Vector2(230, 180))


## QuestBookPoster is image_scale (0.8, 1, 0.58) and then scaled by 1.06.
func layout(card: Vector2) -> void:
	custom_minimum_size = card
	size = card
	_card.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_badge_box.bg_color = Color(0.78, 0.58, 0.12) if _tracked else Color(0.82, 0.16, 0.16)
	_place_tracking(card)
	_badge.size = card * Vector2(26.0 / 230.0, 26.0 / 180.0)
	_place_quest_id(card)
	_badge_box.set_corner_radius_all(maxi(int(_badge.size.x * 0.5), 1))
	_count.position = Vector2.ZERO
	_count.size = _badge.size
	var body := maxi(int(card.y * 0.051), 11)
	ToonGui.style_label(_count, Color.WHITE, body, Color(0, 0, 0), 1)
	if _complete:
		_place_sign(_headline, 0.23, 0.05, card)
		_place_line(_return, 0.0, 0.12, 0.04, card, true)
		_place_line(_left_name, -0.18, 0.02, 0.0325, card, false)
		_place_line(_right_name, 0.18, 0.02, 0.0325, card, false)
		_place_line(_where, 0.0, -0.075, 0.045, card, true)
		_where.size.y = card.y * (0.16 / 0.58)
	elif _split:
		# RecoverItemQuest puts the package at x -0.18, "from:" in the middle,
		# and the holder at x 0.18. Each caption sits under its picture.
		_place_sign(_headline, 0.23, 0.05, card)
		_place_line(_caption, -0.18, 0.02, 0.0325, card, false)
		_place_line(_right_name, 0.18, 0.02, 0.0325, card, false)
		_place_line(_aux, 0.0, 0.12, 0.04, card, false)
		_place_line(_where, 0.0, -0.075, 0.045, card, true)
		_progress.visible = false
	else:
		# An open poster keeps the picture centered. The headline sits at z 0.23,
		# the caption under the frame, and the location at z -0.075.
		_place_sign(_headline, 0.23, 0.05, card)
		_place_line(_caption, 0.0, 0.02, 0.045, card, false)
		_place_line(_where, 0.0, -0.075, 0.045, card, true)
		_progress.visible = false
	# The reward stays on the scroll, at the choice-card height, so the journal
	# does not have to grow the card before the line can be read.
	_place_reward(-0.205, card)
	_reward.visible = not _reward_text.is_empty()
	# The picture square is image_scale 0.15. Open tasks center it at z 0.13.
	# A finished task, and an open recover task, shift it to x -0.18.
	var frame := card * Vector2(0.15 / 0.8, 0.15 / 0.58)
	var open_center := Vector2(card.x * 0.5, card.y * ((0.29 - 0.13) / 0.58))
	var left_center := Vector2(card.x * ((-0.18 + 0.4) / 0.8), open_center.y)
	var right_center := Vector2(card.x * ((0.18 + 0.4) / 0.8), open_center.y)
	var shown := left_center if _complete or _split else open_center
	_frame.position = shown - frame * 0.5
	_frame.size = frame
	var icon := frame * _icon_fit
	_icon.position = _frame.position + (frame - icon) * 0.5
	_icon.size = icon
	_right_frame.position = right_center - frame * 0.5
	_right_frame.size = frame
	var officer := frame * _right_fit
	_right_icon.position = _right_frame.position + (frame - officer) * 0.5
	_right_icon.size = officer


signal track_pressed(quest_id: int)


## The journal page can be clicked. Choice cards and the briefing cannot.
func allow_track() -> void:
	_trackable = true


func show_tracked(on: bool) -> void:
	_tracked = on
	if _tracking != null:
		_tracking.visible = on
	_badge_box.bg_color = Color(0.78, 0.58, 0.12) if on else Color(0.82, 0.16, 0.16)
	if size.y > 1.0:
		_place_tracking(size)


func _gui_input(event: InputEvent) -> void:
	if not _trackable or _task_id <= 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		track_pressed.emit(_task_id)
		accept_event()


func show_task(task: Dictionary, choosing := false) -> void:
	_choosing = choosing
	var quest_id := int(task.get("id", 0))
	_task_id = quest_id
	_quest_id.text = str(quest_id) if quest_id > 0 else ""
	_quest_id.visible = quest_id > 0
	_reward_text = String(task.get("reward_line", ""))
	_reward.text = _reward_text
	_complete = bool(task.get("ready", false))
	var goal := int(task.get("goal", 1))
	var task_number := int(task.get("task_number", 0))
	if task_number > 0:
		_badge.visible = true
		_count.text = str(task_number)
	else:
		var show_count := bool(task.get("show_count", false))
		_badge.visible = show_count
		_count.text = str(goal)
	_card.modulate = _LIGHT_GREEN if _complete else Color.WHITE
	_return.visible = _complete
	_left_name.visible = _complete
	_right_name.visible = _complete
	_right_frame.visible = _complete
	_right_icon.visible = _complete
	_caption.visible = not _complete
	if _complete:
		# QuestPoster sets the headline to COMPLETE and the card to lightGreen.
		_headline.text = "COMPLETE"
		_return.text = "Return to:"
		_left_name.text = String(task.get("caption", ""))
		_right_name.text = "HQ Officer"
		_where.text = "Toon HQ\nAny Street\nAny Neighborhood"
		_progress.text = ""
		_progress.visible = false
	else:
		_headline.text = String(task.get("headline", ""))
		_caption.text = String(task.get("caption", ""))
		_where.text = String(task.get("where", ""))
		# A single-step task hides the progress bar and drops the location down.
		_progress.visible = false
		_progress.text = ""
	_show_activity(task)
	if _complete:
		var return_name := String(task.get("return_name", ""))
		if return_name == "":
			_show_officer()
		else:
			# A visit or a Flippy task goes back to that toon, not an HQ officer.
			_right_name.text = return_name
			_where.text = String(task.get("return_where", _where.text))
			_right_frame.visible = false
			_right_icon.visible = false


func _show_activity(task: Dictionary) -> void:
	_clear_head()
	_split = false
	_aux.visible = false
	_right_fit = 0.8
	_icon.modulate = Color.WHITE
	_right_icon.modulate = Color.WHITE
	var kind := String(task.get("kind", ""))
	_frame.visible = kind != ""
	_icon.visible = kind != ""
	if kind == "cog":
		_frame.modulate = _BLUE
		_show_cog_icon(String(task.get("cog", "")), String(task.get("dept", "")), false)
	elif kind == "trolley":
		_frame.modulate = _LIGHT_BLUE
		_icon_fit = 0.13 / 0.15
		_icon.texture = _TROLLEY
	elif kind == "recover":
		# RecoverItemQuest puts the package on the left. The holder is the
		# cog, the department, or nothing when the holder is a fish.
		_frame.modulate = _GREEN
		_icon_fit = 0.12 / 0.15
		_icon.texture = _PACKAGE
		_icon.visible = true
		if not _complete:
			_show_recover_holder(task)
	elif kind == "visit":
		_frame.modulate = _BROWN
		_icon_fit = 0.8
		_show_visit(int(task.get("npc", 0)))
	elif kind == "friend":
		_frame.modulate = _BROWN
		_icon_fit = 0.7
		_icon.texture = _FRIENDS
	elif kind == "phone":
		_frame.modulate = _LIGHT_BLUE
		_icon_fit = 0.12 / 0.15
		_icon.texture = _CLARA
	elif kind == "track":
		# TrackChoiceQuest shows the two offered gag icons with "or" between them.
		_frame.modulate = _GREEN
		_icon_fit = 0.8
		_icon.texture = _FEATHER
		if not _complete:
			_split = true
			_aux.text = "or"
			_aux.visible = true
			_right_frame.visible = true
			_right_frame.modulate = _GREEN
			_right_icon.texture = _HORN
			_right_icon.visible = true
			_right_fit = 0.8
	elif kind == "building":
		_frame.modulate = _BLUE
		_icon_fit = 0.13 / 0.15
		_icon.texture = _BUILDING
	elif kind == "rescue":
		_frame.modulate = _BLUE
		_icon_fit = 0.13 / 0.15
		_show_portrait(_npc_style(2001))
	elif not _show_later(kind):
		_frame.visible = false
		_icon.visible = false
	if size.x > 1.0:
		layout(size)
	if _complete and _right_frame != null:
		_right_frame.visible = true
		_right_frame.modulate = _frame.modulate
		_right_icon.visible = true


func _show_cog_icon(code: String, dept: String, on_right: bool) -> void:
	var icon := _right_icon if on_right else _icon
	var frame := _right_frame if on_right else _frame
	if not on_right:
		_icon_fit = 0.85
	else:
		_right_fit = 0.85
	if code != "" and code != "any":
		if not on_right:
			_icon_fit = 0.8
		else:
			_right_fit = 0.8
		_show_head(code, on_right)
		return
	if dept != "":
		icon.texture = _dept_icon(dept)
		icon.modulate = _dept_tint(dept)
		icon.visible = true
		frame.visible = true
		if on_right:
			_right_fit = 0.13 / 0.15
		else:
			_icon_fit = 0.13 / 0.15
		return
	icon.texture = _COG
	icon.modulate = Color.WHITE
	icon.visible = true
	frame.visible = true


func _show_recover_holder(task: Dictionary) -> void:
	_split = true
	var holder := String(task.get("holder", ""))
	var holder_name := String(task.get("holder_name", "The Cogs"))
	_right_name.text = holder_name if holder_name != "" else "The Cogs"
	_right_name.visible = true
	_right_frame.visible = true
	_right_frame.modulate = _GREEN
	if holder == "fish":
		_aux.text = "for"
		_aux.visible = true
		_right_icon.visible = false
		_right_frame.visible = false
		_right_name.visible = false
		return
	_aux.text = "from:"
	_aux.visible = true
	var holder_type := String(task.get("holder_type", ""))
	if holder_type == "level" or holder == "" or holder == "any":
		_show_cog_icon("any", "", true)
	elif holder_type == "track":
		_show_cog_icon("any", holder, true)
	else:
		_show_cog_icon(holder, "", true)


func _show_visit(npc_id: int) -> void:
	if npc_id == 0 or npc_id == 1000:
		_show_portrait(_officer_style())
		return
	var style := _npc_style(npc_id)
	if style == null:
		_icon.visible = false
		return
	_show_portrait(style)


func _show_later(kind: String) -> bool:
	var picture: Texture2D = null
	var tint := _BLUE
	var fit := 0.13 / 0.15
	if kind == "factory":
		picture = _FACTORY
	elif kind == "mint":
		picture = _MINT
	elif kind == "cogpart":
		picture = _ARM
		tint = _GREEN
	elif kind == "skelecog" or kind == "foreman" or kind == "supervisor":
		picture = _SKELE
	elif kind == "vp":
		picture = _VP
	elif kind == "cfo":
		picture = _CFO
	elif kind == "mailbox" or kind == "deliver":
		picture = _PACKAGE
		tint = _LIGHT_BLUE
		fit = 0.12 / 0.15
	else:
		return false
	_frame.modulate = tint
	_icon_fit = fit
	_icon.texture = picture
	_icon.visible = true
	return true


func _dept_icon(dept: String) -> Texture2D:
	if dept == "c":
		return _CORP
	if dept == "s":
		return _SALES
	if dept == "l":
		return _LEGAL
	if dept == "m":
		return _MONEY
	return _COG


func _dept_tint(dept: String) -> Color:
	if dept == "c":
		return _CORP_TINT
	if dept == "s":
		return _SALES_TINT
	if dept == "l":
		return _LEGAL_TINT
	if dept == "m":
		return _MONEY_TINT
	return Color.WHITE


func _show_head(code: String, on_right := false) -> void:
	var icon := _right_icon if on_right else _icon
	var packed := load("res://assets/cogs/heads/%s.glb" % code) as PackedScene
	if packed == null:
		icon.visible = false
		return
	var port := SubViewport.new()
	if on_right:
		_right_port = port
	else:
		_port = port
		_head_code = code
	port.transparent_bg = true
	port.own_world_3d = true
	port.size = Vector2i(160, 160)
	port.gui_disable_input = true
	port.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(port)
	var stage := Node3D.new()
	port.add_child(stage)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.1
	world.environment = env
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.2
	key.rotation_degrees = Vector3(-25.0, 180.0, 0.0)
	stage.add_child(key)
	var actor := packed.instantiate() as Node3D
	stage.add_child(actor)
	var holder := Node3D.new()
	stage.add_child(holder)
	_copy_head(actor, holder)
	stage.remove_child(actor)
	actor.free()
	var camera := Camera3D.new()
	camera.fov = 28.0
	camera.current = true
	camera.position = Vector3(0.0, 0.02, 2.05)
	stage.add_child(camera)
	icon.texture = port.get_texture()
	icon.visible = true


func _clear_head() -> void:
	_head_code = ""
	if _port != null and is_instance_valid(_port):
		_port.queue_free()
	_port = null
	if _right_port != null and is_instance_valid(_right_port):
		_right_port.queue_free()
	_right_port = null


func _copy_head(actor: Node3D, holder: Node3D) -> void:
	var merged := AABB()
	var found := false
	for node in actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		var copy := mesh.duplicate() as MeshInstance3D
		copy.transform = _pose(mesh, actor)
		holder.add_child(copy)
		var box := copy.transform * copy.get_aabb()
		merged = box if not found else merged.merge(box)
		found = true
	if not found:
		return
	var center := merged.get_center()
	for child in holder.get_children():
		var placed := child as Node3D
		placed.position -= center
	var biggest := maxf(merged.size.x, maxf(merged.size.y, merged.size.z))
	if biggest < 0.001:
		biggest = 1.0
	holder.scale = Vector3.ONE / biggest


func _pose(mesh: Node3D, actor: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var node: Node = mesh
	while node is Node3D:
		xform = (node as Node3D).transform * xform
		if node == actor:
			break
		node = node.get_parent()
	return xform


func _show_portrait(style: ToonStyle) -> void:
	if style == null:
		_icon.visible = false
		return
	_port = SubViewport.new()
	_port.transparent_bg = true
	_port.own_world_3d = true
	_port.size = Vector2i(180, 180)
	_port.gui_disable_input = true
	_port.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_port)
	var stage := Node3D.new()
	_port.add_child(stage)
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
	key.light_energy = 1.2
	key.rotation_degrees = Vector3(-28.0, 35.0, 0.0)
	stage.add_child(key)
	var actor := ToonActor.new()
	stage.add_child(actor)
	actor.show_style(style)
	var camera := Camera3D.new()
	camera.fov = 26.0
	camera.current = true
	stage.add_child(camera)
	var focus := actor.position + Vector3(0.0, 3.45, 0.0)
	var head := _find(actor, "def_head")
	if head != null:
		focus = head.global_position if is_inside_tree() else actor.to_global(head.position)
	camera.position = focus + Vector3(0.0, 0.08, 1.55)
	camera.look_at(focus, Vector3.UP)
	_icon.texture = _port.get_texture()
	_icon.visible = true


func _npc_style(npc_id: int) -> ToonStyle:
	_load_npcs()
	var dna: Variant = _npc_dna.get(npc_id, [])
	if typeof(dna) != TYPE_ARRAY or (dna as Array).size() < 14:
		return null
	return _style_from_dna(dna)


func _load_npcs() -> void:
	if _npcs_ready:
		return
	_npcs_ready = true
	# Flippy and Librarian Larry are interior toons, not shopkeepers.
	_npc_dna[2001] = ["dss", "ms", "m", "m", 17, 0, 17, 17, 3, 3, 0, 0, 7, 2]
	_npc_dna[2005] = ["cls", "ls", "l", "m", 4, 0, 4, 4, 0, 4, 0, 0, 0, 4]
	if not FileAccess.file_exists(_SHOPS):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_SHOPS))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var shops: Dictionary = parsed
	for zone in shops.keys():
		var row: Variant = shops[zone]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var people: Variant = (row as Dictionary).get("npcs", [])
		if typeof(people) != TYPE_ARRAY:
			continue
		for npc in people:
			if typeof(npc) != TYPE_DICTIONARY:
				continue
			var who: Dictionary = npc
			var dna: Array = who.get("dna", [])
			var npc_id := int(who.get("id", 0))
			if npc_id != 0 and dna.size() >= 14:
				_npc_dna[npc_id] = dna


func _style_from_dna(dna: Array) -> ToonStyle:
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


func _show_officer() -> void:
	if _officer_port != null and is_instance_valid(_officer_port):
		_right_icon.texture = _officer_port.get_texture()
		return
	_officer_port = SubViewport.new()
	_officer_port.transparent_bg = true
	_officer_port.own_world_3d = true
	_officer_port.size = Vector2i(180, 180)
	_officer_port.gui_disable_input = true
	_officer_port.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_officer_port)
	var stage := Node3D.new()
	_officer_port.add_child(stage)
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
	key.light_energy = 1.2
	key.rotation_degrees = Vector3(-28.0, 35.0, 0.0)
	stage.add_child(key)
	var actor := ToonActor.new()
	stage.add_child(actor)
	actor.show_style(_officer_style())
	var camera := Camera3D.new()
	camera.fov = 26.0
	camera.current = true
	stage.add_child(camera)
	var focus := actor.position + Vector3(0.0, 3.45, 0.0)
	var head := _find(actor, "def_head")
	if head != null:
		focus = head.global_position if is_inside_tree() else actor.to_global(head.position)
	camera.position = focus + Vector3(0.0, 0.08, 1.55)
	camera.look_at(focus, Vector3.UP)
	_right_icon.texture = _officer_port.get_texture()


static func _officer_style() -> ToonStyle:
	# The finished poster returns the task to a Toon HQ officer. The attached
	# card shows the pink pig with lashes that HQ uses for that picture.
	var style := ToonStyle.new()
	style.gender = "f"
	style.head = "sls"
	style.torso = "md"
	style.legs = "m"
	style.arm_color = 1
	style.glove_color = 0
	style.leg_color = 1
	style.head_color = 1
	style.top_tex = 0
	style.top_color = 3
	style.bot_tex = 0
	style.bot_color = 3
	return style


func _find(node: Node, wanted: String) -> Node3D:
	if node != null and node.name == wanted and node is Node3D:
		return node as Node3D
	for child in node.get_children():
		var found := _find(child, wanted)
		if found != null:
			return found
	return null


## mouseEnterPoster grows the card's height by 0.07 and lifts the pictures
## by 0.03. The resting card is 0.58 tall, so both are fractions of it.
func _hover_in() -> void:
	if _hovered or size.y < 2.0:
		return
	_hovered = true
	_rest_pos = position
	_rest_size = size
	z_index = 6
	move_to_front()
	var extra := size.y * (0.07 / 0.58)
	var lift := size.y * (0.03 / 0.58)
	var settle := extra * 0.5 - lift
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_parallel(true)
	_hover_tween.tween_property(self, "position", position + Vector2(0.0, -extra * 0.5), 0.08)
	_hover_tween.tween_property(self, "size", size + Vector2(0.0, extra), 0.08)
	_reward.visible = not _reward_text.is_empty()
	for child in get_children():
		if child == _card or child is SubViewport:
			continue
		var control := child as Control
		if control == null:
			continue
		_hover_tween.tween_property(control, "position:y", control.position.y + settle, 0.08)


func _hover_out() -> void:
	if not _hovered:
		return
	# Growing the card moves its rectangle, which can fire a leave while the
	# pointer is still on it. Recheck once the move has settled.
	call_deferred("_finish_hover")


func _finish_hover() -> void:
	if not _hovered or not is_inside_tree():
		return
	if get_global_rect().has_point(get_global_mouse_position()):
		return
	_hovered = false
	z_index = 0
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	position = _rest_pos
	if _rest_size.x > 1.0:
		layout(_rest_size)


func _label() -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	return label


## A quest-card z, on the 0.8 by 0.58 poster, measured from the card center.
func _place_line(label: Label, x: float, z: float, text_scale: float, card: Vector2, wide: bool) -> void:
	var px := maxi(int(card.y * text_scale / 0.58), 10)
	var width := card.x * (0.72 if wide else 0.34)
	var height := float(px) * 1.35
	var center := Vector2(card.x * ((x + 0.4) / 0.8), card.y * ((0.29 - z) / 0.58))
	label.position = center - Vector2(width, height) * 0.5
	label.size = Vector2(width, height)
	if label == _headline:
		var ink := _DONE if _complete else _INK
		ToonGui.style_sign(label, ink, px, Color(0, 0, 0, 0), 0)
	else:
		ToonGui.style_label(label, _INK, px, Color(0, 0, 0, 0), 0)


## The quest number sits in the top-left of the scroll. A counted task's red
## circle moves to the right of it.
func _place_quest_id(card: Vector2) -> void:
	var id_px := maxi(int(card.y * 0.04 / 0.58), 9)
	ToonGui.style_label(_quest_id, _INK, id_px, Color(0, 0, 0, 0), 0)
	var text_w := 0.0
	if _quest_id.visible:
		text_w = ToonGui.font().get_string_size(_quest_id.text, HORIZONTAL_ALIGNMENT_LEFT, -1, id_px).x
	var origin := card * Vector2(14.0 / 230.0, 24.0 / 180.0)
	_quest_id.position = origin
	_quest_id.size = Vector2(maxf(text_w, 1.0), card.y * (26.0 / 180.0))
	var badge_x := 18.0 / 230.0
	if _quest_id.visible:
		badge_x = (origin.x + text_w + card.x * (6.0 / 230.0)) / card.x
	_badge.position = Vector2(card.x * badge_x, card.y * (28.0 / 180.0))


func _place_tracking(card: Vector2) -> void:
	if _tracking == null:
		return
	_tracking.visible = _tracked
	if not _tracked:
		return
	var px := maxi(int(card.y * 0.045 / 0.58), 10)
	ToonGui.style_label(_tracking, Color(0.05, 0.38, 0.12), px, Color(0, 0, 0, 0), 0)
	var width := card.x * 0.42
	var height := float(px) * 1.3
	_tracking.position = Vector2(card.x - width - card.x * (14.0 / 230.0), card.y * (20.0 / 180.0))
	_tracking.size = Vector2(width, height)


## rewardText is left aligned at x -0.36. z is the first line's baseline, so the
## words sit above it and a wrapped second line continues down the scroll.
func _place_reward(z: float, card: Vector2) -> void:
	var px := maxi(int(card.y * 0.0425 / 0.58), 8)
	var width := card.x * 0.9
	var line_h := float(px)
	var left := card.x * ((-0.36 + 0.4) / 0.8)
	var baseline := card.y * ((0.29 - z) / 0.58)
	_reward.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_reward.position = Vector2(left, baseline - line_h)
	_reward.size = Vector2(width, line_h * 2.4)
	ToonGui.style_label(_reward, _REWARD, px, Color(0, 0, 0, 0), 0)


func _place_sign(label: Label, z: float, text_scale: float, card: Vector2) -> void:
	_place_line(label, 0.0, z, text_scale, card, true)
