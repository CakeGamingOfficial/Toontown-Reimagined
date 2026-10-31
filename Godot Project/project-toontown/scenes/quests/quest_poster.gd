class_name QuestPoster
extends Control

## One scroll from the Shticker Book task page, using the original quest card.

const _CARD := preload("res://assets/gui/tutorial/book/questCard.png")
const _FRAME := preload("res://assets/gui/tutorial/book/questPictureFrame.png")
const _TROLLEY := preload("res://assets/gui/tutorial/book/trolley.png")
const _COG := preload("res://assets/gui/tutorial/book/cog_icon.png")
## QuestPoster colors the picture square. Cog tasks are blue, the trolley is light blue.
const _BLUE := Color(0.45, 0.45, 0.8)
const _LIGHT_BLUE := Color(0.42, 0.671, 1.0)
## A finished task tints the scroll lightGreen and the headline (0, 0.3, 0).
const _LIGHT_GREEN := Color(0.784, 1.0, 0.863)
const _DONE := Color(0.0, 0.3, 0.0)
const _INK := Color(0.3, 0.25, 0.2)

var _card: TextureRect
var _headline: Label
var _caption: Label
var _where: Label
var _progress: Label
var _return: Label
var _left_name: Label
var _right_name: Label
var _badge: Panel
var _count: Label
var _badge_box: StyleBoxFlat
var _frame: TextureRect
var _icon: TextureRect
var _right_frame: TextureRect
var _right_icon: TextureRect
var _port: SubViewport
var _officer_port: SubViewport
var _head_code := ""
var _icon_fit := 0.8
var _complete := false
var _hovered := false
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
	_headline = _label()
	_caption = _label()
	_where = _label()
	_progress = _label()
	layout(Vector2(230, 180))


## QuestBookPoster is image_scale (0.8, 1, 0.58) and then scaled by 1.06.
func layout(card: Vector2) -> void:
	custom_minimum_size = card
	size = card
	_card.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_badge.position = card * Vector2(18.0 / 230.0, 28.0 / 180.0)
	_badge.size = card * Vector2(26.0 / 230.0, 26.0 / 180.0)
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
	else:
		# An open poster keeps the picture centered. The headline sits at z 0.23,
		# the caption under the frame, and the location at z -0.075.
		_place_sign(_headline, 0.23, 0.05, card)
		_place_line(_caption, 0.0, 0.02, 0.045, card, false)
		_place_line(_where, 0.0, -0.075, 0.045, card, true)
		_progress.visible = false
	# The picture square is image_scale 0.15. Open tasks center it at z 0.13.
	# A finished task shifts it to x -0.18 and adds the return picture at x 0.18.
	var frame := card * Vector2(0.15 / 0.8, 0.15 / 0.58)
	var open_center := Vector2(card.x * 0.5, card.y * ((0.29 - 0.13) / 0.58))
	var left_center := Vector2(card.x * ((-0.18 + 0.4) / 0.8), open_center.y)
	var right_center := Vector2(card.x * ((0.18 + 0.4) / 0.8), open_center.y)
	var shown := left_center if _complete else open_center
	_frame.position = shown - frame * 0.5
	_frame.size = frame
	var icon := frame * _icon_fit
	_icon.position = _frame.position + (frame - icon) * 0.5
	_icon.size = icon
	_right_frame.position = right_center - frame * 0.5
	_right_frame.size = frame
	var officer := frame * 0.8
	_right_icon.position = _right_frame.position + (frame - officer) * 0.5
	_right_icon.size = officer


func show_task(task: Dictionary) -> void:
	_complete = bool(task.get("ready", false))
	var goal := int(task.get("goal", 1))
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
		_show_officer()


func _show_activity(task: Dictionary) -> void:
	_clear_head()
	var kind := String(task.get("kind", ""))
	_frame.visible = kind != ""
	_icon.visible = kind != ""
	if kind == "cog":
		_frame.modulate = _BLUE
		var code := String(task.get("cog", ""))
		if code == "" or code == "any":
			_icon_fit = 0.85
			_icon.texture = _COG
		else:
			# createSuitHead fits the head into 0.8, then the poster scales it by 0.15.
			_icon_fit = 0.8
			_show_head(code)
	elif kind == "trolley":
		_frame.modulate = _LIGHT_BLUE
		_icon_fit = 0.13 / 0.15
		_icon.texture = _TROLLEY
	else:
		_frame.visible = false
		_icon.visible = false
	if size.x > 1.0:
		layout(size)
	if _complete and _right_frame != null:
		_right_frame.visible = true
		_right_frame.modulate = _frame.modulate
		_right_icon.visible = true


func _show_head(code: String) -> void:
	var packed := load("res://assets/cogs/heads/%s.glb" % code) as PackedScene
	if packed == null:
		_icon.visible = false
		return
	_port = SubViewport.new()
	_port.transparent_bg = true
	_port.own_world_3d = true
	_port.size = Vector2i(160, 160)
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
	_icon.texture = _port.get_texture()
	_head_code = code


func _clear_head() -> void:
	_head_code = ""
	if _port != null and is_instance_valid(_port):
		_port.queue_free()
	_port = null


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


func _place_sign(label: Label, z: float, text_scale: float, card: Vector2) -> void:
	_place_line(label, 0.0, z, text_scale, card, true)
