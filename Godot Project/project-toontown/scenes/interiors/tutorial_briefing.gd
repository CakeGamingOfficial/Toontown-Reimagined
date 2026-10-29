class_name TutorialBriefing
extends Node

## quest_assign_101, with the wording from the tutorial clip: posters, the
## gag handoff, the laff meter, and the first ToonTask.

const _POSTERS := {
	"suits": preload("res://assets/gui/tutorial/posters/suits.png"),
	"toon_buildings": preload("res://assets/gui/tutorial/posters/toon_buildings.png"),
	"suit_buildings": preload("res://assets/gui/tutorial/posters/suit_buildings.png"),
	"squirt1": preload("res://assets/gui/tutorial/posters/squirt1.png"),
	"squirt2": preload("res://assets/gui/tutorial/posters/squirt2.png"),
}
const _CUPCAKE := preload("res://assets/gui/tutorial/gags/inventory_tart.png")
const _FLOWER := preload("res://assets/gui/tutorial/gags/inventory_squirt_flower.png")
const _QUEST := preload("res://assets/gui/tutorial/quest_card.png")
const _BLACK := Color(0.08, 0.08, 0.1)
const _TEAL := Color(0.0, 0.58, 0.64)
const _PINK := Color(0.84, 0.27, 0.45)

var started := false
var finished := false

var _host: Node3D
var _panel: GagPanel
var _meter: LaffMeter
var _loadout: ToonLoadout
var _poster: MeshInstance3D
var _bubble: PanelContainer
var _label: Label
var _quest: Control
var _advance := false
var _bubble_on := false
var _hold_advance := false
var _pin_bubble := false


func setup(host: Node3D, panel: GagPanel, meter: LaffMeter, loadout: ToonLoadout) -> void:
	_host = host
	_panel = panel
	_meter = meter
	_loadout = loadout
	_build_poster()
	_build_bubble()
	_build_quest()


func start() -> void:
	if started:
		return
	started = true
	_run()


func _run() -> void:
	_host.call("set_cutscene", true)
	_host.call("dismiss_welcome")
	_frame_tom()
	_expression("angry")
	await _line("These are Cogs. They're the business bots trying to take over Toontown.", _BLACK, "suits")
	await _line("There are all sorts of Cogs.", _TEAL, "suits")
	await _line("They turn happy Toon buildings...", _TEAL, "toon_buildings")
	_expression("sad")
	await _line("...into ugly Cog buildings!", _TEAL, "suit_buildings")
	_expression("normal")
	await _line("The Cogs are tough, but they can't take a joke!", _TEAL, "squirt1")
	await _line("A good gag will put a stop to them.", _TEAL, "squirt2")
	_show_poster("")
	await _line("There are lots of gags, but Clara will tell you about them later. Take these two to start...", _BLACK, "")
	await _hand_over_gags()
	await _present_laff()
	_host.call("face_tom", 130.0)
	_expression("surprised")
	await _gesture("pstart", 1.5, false)
	_gesture("rpoint", 1.0, true)
	await _line("OH NO! There's a Cog outside my shop!", _TEAL, "")
	await _line("HELP ME, PLEASE! Defeat that Cog!", _TEAL, "")
	await _gesture("pstart", -1.0, false)
	_host.call("face_tom", 180.0)
	_expression("angry")
	_clear_gesture()
	var tasks := _host.call("tasks") as ToonTasks
	if tasks != null:
		tasks.assign(101)
	_quest.position = Vector2(_view().x * 0.18, _view().y * 0.16)
	_quest.scale = Vector2(1.45, 1.45)
	_quest.visible = true
	await _line("Here is your first ToonTask!", _TEAL, "")
	_quest.visible = false
	if tasks == null or not tasks.has_book:
		await _give_book()
	await _line("Hurry up! Go defeat that Flunky!", _TEAL, "")
	_bubble_on = false
	_bubble.visible = false
	_show_poster("")
	_loadout.set_hp(15, 15)
	_loadout.save()
	_host.call("place_player", Vector3(0.776, 0.2, -14.6), 58.0)
	_expression("normal")
	_clear_gesture()
	_host.call("set_cutscene", false)
	finished = true


func _process(_delta: float) -> void:
	if not _hold_advance and Input.is_action_just_pressed("ui_accept"):
		_advance = true
	if not _bubble_on or _pin_bubble or _host == null:
		return
	var camera := _host.get_node_or_null("Camera") as Camera3D
	var tom := _host.get_node_or_null("Tutorial Tom") as Node3D
	if camera == null or tom == null or not tom.visible:
		_bubble.visible = false
		return
	var point := tom.global_position + Vector3(0.2, 5.2, 0.0)
	if camera.is_position_behind(point):
		_bubble.visible = false
		return
	_bubble.visible = true
	_bubble.reset_size()
	var screen := camera.unproject_position(point)
	_bubble.position = screen + Vector2(30, -_bubble.size.y - 78)


func _unhandled_input(event: InputEvent) -> void:
	if _hold_advance:
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_advance = true
	elif event.is_action_pressed("ui_accept"):
		_advance = true


func _give_book() -> void:
	# quest_assign_110's book tour, played once Tom has handed over the task.
	# The pages are the map, the gags he just gave, and this Flunky ToonTask.
	var book := _host.call("shticker") as ShtickerBook
	if book == null:
		return
	_pin_bubble = true
	_bubble.z_index = 40
	await _line("Oh! You will need a Shticker Book.", _BLACK, "")
	await _line("The book is full of good stuff.", _TEAL, "")
	_hold_advance = true
	_say("Open it, and I'll show you.")
	book.present_button()
	await book.book_opened
	_say("The map shows where you've been.")
	await _click()
	_say("Turn the page to see your gags...")
	book.arm_next()
	await _wait_page(book, 1)
	_say("Turn the page to see your tasks.")
	book.arm_next()
	await _wait_page(book, 2)
	_say("Close the book when you're ready.")
	book.arm_close()
	await book.book_closed
	_pin_bubble = false
	_hold_advance = false
	_bubble.z_index = 0


func hide_speech() -> void:
	_bubble_on = false
	if _bubble:
		_bubble.visible = false


func _say(text: String) -> void:
	_show_poster("")
	_label.text = text
	_label.add_theme_color_override("font_color", _TEAL)
	_bubble_on = true
	_bubble.visible = true
	_bubble.reset_size()
	var view := _view()
	_bubble.position = Vector2(view.x * 0.5 - 200.0, 28.0)


func _click() -> void:
	var book := _host.call("shticker") as ShtickerBook
	if book != null:
		book.let_clicks_through(true)
	_advance = false
	_hold_advance = false
	while not _advance:
		await get_tree().process_frame
	_advance = false
	_hold_advance = true
	if book != null:
		book.let_clicks_through(false)


func _wait_page(book: ShtickerBook, index: int) -> void:
	while book.page() != index:
		await book.page_ready


func _tom() -> ToonActor:
	if _host == null:
		return null
	return _host.get_node_or_null("Tutorial Tom") as ToonActor


func _expression(mood: String) -> void:
	var tom := _tom()
	if tom:
		tom.set_expression(mood)


func _clear_gesture() -> void:
	var tom := _tom()
	if tom:
		tom.clear_gesture()


func _gesture(suffix: String, rate: float, loop: bool) -> void:
	var tom := _tom()
	if tom == null:
		return
	tom.play_gesture(suffix, rate, loop)
	if loop:
		return
	while is_instance_valid(tom) and not tom.gesture_finished():
		await get_tree().process_frame


func _line(text: String, color: Color, poster: String) -> void:
	_show_poster(poster)
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	_bubble_on = true
	_advance = false
	while not _advance:
		await get_tree().process_frame
	_advance = false


func _hand_over_gags() -> void:
	_loadout.set_gag(ToonLoadout.THROW, 0, 0, true)
	_loadout.set_gag(ToonLoadout.SQUIRT, 0, 0, true)
	_panel.refresh()
	var view := _view()
	_panel.position = Vector2((view.x - _panel.size.x) * 0.5, view.y * 0.12)
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.15, 0.15)
	_panel.visible = true
	var opened := create_tween()
	opened.tween_property(_panel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await opened.finished
	await _gesture("rstart", 1.8, false)
	_gesture("rhand", 1.1, true)
	await _fly(_FLOWER, ToonLoadout.SQUIRT, 0)
	await _gesture("rstart", -1.5, false)
	_clear_gesture()
	await get_tree().create_timer(0.25).timeout
	await _gesture("rstart", 1.8, false)
	_gesture("rhand", 1.1, true)
	await _fly(_CUPCAKE, ToonLoadout.THROW, 0)
	await _gesture("rstart", -1.5, false)
	_clear_gesture()
	await get_tree().create_timer(1.1).timeout
	var closed := create_tween()
	closed.tween_property(_panel, "scale", Vector2(0.15, 0.15), 0.25)
	await closed.finished
	_panel.visible = false
	_panel.scale = Vector2.ONE


func _fly(texture: Texture2D, track: int, level: int) -> void:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = Vector2(110, 110)
	icon.position = _panel.position + Vector2(120, _panel.size.y - 30)
	_hud().add_child(icon)
	var target := _panel.slot_center(track, level) - icon.size * 0.2
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(icon, "global_position", target, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(icon, "size", Vector2(36, 36), 0.7)
	await tween.finished
	_loadout.set_gag(track, level, 1, true)
	_panel.refresh()
	icon.queue_free()


func _present_laff() -> void:
	var view := _view()
	var big := view.y * 0.46
	var small := view.y * 0.15
	var shown := Vector2(view.x * 0.3, view.y * 0.4)
	var dock := Vector2(small * 0.5 + 28.0, view.y - small * 0.5 - 28.0)
	_meter.set_hp(15, 15)
	_meter.visible = true
	_meter.place(shown, big)
	await _gesture("rstart", 1.0, false)
	_gesture("rhand", 1.0, true)
	await _line("Oh! You also need a Laff meter!", _BLACK, "")
	await _line("When you run out of Laff, you'll turn sad!", _TEAL, "")
	_expression("sad")
	for current in range(14, -1, -1):
		_meter.set_hp(current, 15)
		await get_tree().create_timer(0.07).timeout
	await _line("A happy Toon is a healthy Toon, you know.", _PINK, "")
	_expression("normal")
	_meter.set_hp(15, 15)
	await _gesture("rstart", -2.0, false)
	_clear_gesture()
	var tween := create_tween()
	tween.tween_method(_slide_meter.bind(shown, dock, big, small), 0.0, 1.0, 0.55)
	await tween.finished


func _slide_meter(weight: float, shown: Vector2, dock: Vector2, big: float, small: float) -> void:
	_meter.place(shown.lerp(dock, weight), lerpf(big, small, weight))


func _frame_tom() -> void:
	var camera := _host.get_node_or_null("Camera") as Camera3D
	if camera == null:
		return
	camera.global_position = Vector3(0.15, 3.85, -15.2)
	camera.look_at(Vector3(0.15, 2.75, -22.8), Vector3.UP)


func _show_poster(which: String) -> void:
	if which == "" or not _POSTERS.has(which):
		_poster.visible = false
		return
	var material := _poster.material_override as StandardMaterial3D
	material.albedo_texture = _POSTERS[which]
	_poster.visible = true


func _build_poster() -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(4.2, 3.25)
	_poster = MeshInstance3D.new()
	_poster.name = "TutorialPoster"
	_poster.mesh = mesh
	_poster.position = Vector3(-1.15, 3.35, -24.85)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_poster.material_override = material
	_poster.visible = false
	_host.add_child(_poster)


func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.visible = false
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.98)
	box.border_color = Color(0.1, 0.1, 0.12)
	box.set_border_width_all(3)
	box.set_corner_radius_all(18)
	box.content_margin_left = 16
	box.content_margin_right = 28
	box.content_margin_top = 10
	box.content_margin_bottom = 12
	_bubble.add_theme_stylebox_override("panel", box)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(280, 0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(_label, _BLACK, 22, Color(0, 0, 0, 0), 0)
	_bubble.add_child(_label)
	var arrow := Label.new()
	arrow.text = ">"
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	arrow.offset_left = -22
	arrow.offset_top = -22
	arrow.offset_right = -6
	arrow.offset_bottom = -4
	ToonGui.style_label(arrow, Color(0.15, 0.45, 0.85), 16, Color(0, 0, 0, 0), 0)
	_bubble.add_child(arrow)
	_hud().add_child(_bubble)


func _build_quest() -> void:
	_quest = Control.new()
	_quest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest.visible = false
	_quest.custom_minimum_size = Vector2(280, 220)
	_quest.size = _quest.custom_minimum_size
	var card := TextureRect.new()
	card.texture = _QUEST
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size = _quest.size
	_quest.add_child(card)
	var title := Label.new()
	title.text = "WANTED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(40, 28)
	title.size = Vector2(200, 28)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(title, Color(0.25, 0.16, 0.08), 20, Color(0, 0, 0, 0), 0)
	_quest.add_child(title)
	var mark := Panel.new()
	mark.position = Vector2(24, 36)
	mark.size = Vector2(22, 22)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var red := StyleBoxFlat.new()
	red.bg_color = Color(0.82, 0.16, 0.16)
	red.set_corner_radius_all(11)
	mark.add_theme_stylebox_override("panel", red)
	_quest.add_child(mark)
	var count := Label.new()
	count.text = "1"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.size = mark.size
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(count, Color.WHITE, 14, Color(0, 0, 0), 1)
	mark.add_child(count)
	var who := Label.new()
	who.text = "A Flunky"
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.position = Vector2(40, 108)
	who.size = Vector2(200, 28)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(who, Color(0.22, 0.16, 0.1), 20, Color(0, 0, 0, 0), 0)
	_quest.add_child(who)
	var where := Label.new()
	where.text = "Anywhere"
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	where.position = Vector2(40, 140)
	where.size = Vector2(200, 24)
	where.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(where, Color(0.28, 0.22, 0.14), 16, Color(0, 0, 0, 0), 0)
	_quest.add_child(where)
	_hud().add_child(_quest)


func _hud() -> CanvasLayer:
	return _host.call("hud") as CanvasLayer


func _view() -> Vector2:
	return _host.get_viewport().get_visible_rect().size
