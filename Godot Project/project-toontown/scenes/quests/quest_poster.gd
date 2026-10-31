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

var _headline: Label
var _caption: Label
var _where: Label
var _progress: Label
var _badge: Panel
var _count: Label
var _badge_box: StyleBoxFlat
var _frame: TextureRect
var _icon: TextureRect
var _port: SubViewport
var _head_code := ""
var _icon_fit := 0.8


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var card := TextureRect.new()
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
	_badge.position = card * Vector2(18.0 / 230.0, 28.0 / 180.0)
	_badge.size = card * Vector2(26.0 / 230.0, 26.0 / 180.0)
	_badge_box.set_corner_radius_all(maxi(int(_badge.size.x * 0.5), 1))
	_count.position = Vector2.ZERO
	_count.size = _badge.size
	var body := maxi(int(card.y * 0.051), 11)
	ToonGui.style_label(_count, Color.WHITE, body, Color(0, 0, 0), 1)
	_place(_headline, Vector2(48, 26), Vector2(150, 28), card, body)
	_place(_caption, Vector2(24, 78), Vector2(182, 36), card, body)
	_place(_where, Vector2(24, 114), Vector2(182, 24), card, maxi(body - 2, 10))
	_place(_progress, Vector2(24, 140), Vector2(182, 22), card, maxi(body - 3, 10))
	# The picture square is image_scale 0.15, centered at z 0.13 on the 0.8 by 0.58 card.
	var frame := card * Vector2(0.15 / 0.8, 0.15 / 0.58)
	var center := Vector2(card.x * 0.5, card.y * ((0.29 - 0.13) / 0.58))
	_frame.position = center - frame * 0.5
	_frame.size = frame
	var icon := frame * _icon_fit
	_icon.position = _frame.position + (frame - icon) * 0.5
	_icon.size = icon


func show_task(task: Dictionary) -> void:
	_headline.text = String(task.get("headline", ""))
	_caption.text = String(task.get("caption", ""))
	_where.text = String(task.get("where", ""))
	var goal := int(task.get("goal", 1))
	var progress := int(task.get("progress", 0))
	var show_count := bool(task.get("show_count", false))
	_badge.visible = show_count
	_count.text = str(goal)
	if bool(task.get("ready", false)):
		_progress.text = "Ready for turn-in!"
	elif show_count:
		_progress.text = "%d of %d defeated" % [progress, goal]
	else:
		_progress.text = ""
	_show_activity(task)


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


func _label() -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	return label


func _place(label: Label, at: Vector2, box: Vector2, card: Vector2, px: int) -> void:
	label.position = Vector2(at.x / 230.0 * card.x, at.y / 180.0 * card.y)
	label.size = Vector2(box.x / 230.0 * card.x, box.y / 180.0 * card.y)
	ToonGui.style_label(label, Color(0.3, 0.25, 0.2), px, Color(0, 0, 0, 0), 0)
