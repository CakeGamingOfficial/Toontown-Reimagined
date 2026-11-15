class_name TrackPage
extends Control

## TrackPage. Eighteen filmstrip frames. The first is the training title and
## the last is FIN. The sixteen between them are the tasks: a question mark
## until that task is done, then this toon posed further along the track's clip.
## With no track in progress every middle frame is the grey question mark.

const _FILM := preload("res://assets/gui/shticker/filmstrip.png")
const _TASKS := preload("res://scenes/quests/toon_tasks.gd")
const _MAX := 18
const _INK := Color(0.5, 0.1, 0.1)
const _DARK := Color(0.2, 0.2, 0.2)
const _ANIMS: PackedStringArray = ["juggle", "toss", "hypnotize", "sound", "throw", "firehose", "pushbutton"]

var _title: Label
var _subtitle: Label
var _status: Label
var _frames: Array[Control] = []
var _films: Array[TextureRect] = []
var _marks: Array[Label] = []
var _numbers: Array[Label] = []
var _ports: Array[SubViewport] = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false
	name = "GagTraining"
	_title = _line("Gag Track Training")
	_subtitle = _line("Complete ToonTasks to learn how to use new gags!")
	_status = _line("")
	add_child(_title)
	add_child(_subtitle)
	add_child(_status)
	for index in _MAX:
		var frame := Control.new()
		frame.mouse_filter = MOUSE_FILTER_IGNORE
		frame.name = "Frame%d" % (index + 1)
		add_child(frame)
		var film := TextureRect.new()
		film.texture = _FILM
		film.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		film.stretch_mode = TextureRect.STRETCH_SCALE
		film.mouse_filter = MOUSE_FILTER_IGNORE
		film.set_anchors_preset(PRESET_FULL_RECT)
		frame.add_child(film)
		var mark := Label.new()
		mark.mouse_filter = MOUSE_FILTER_IGNORE
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frame.add_child(mark)
		var number := Label.new()
		number.mouse_filter = MOUSE_FILTER_IGNORE
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		number.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		frame.add_child(number)
		_frames.append(frame)
		_films.append(film)
		_marks.append(mark)
		_numbers.append(number)


func _notification(what: int) -> void:
	if what != NOTIFICATION_VISIBILITY_CHANGED:
		return
	var mode := SubViewport.UPDATE_DISABLED
	if is_visible_in_tree():
		mode = SubViewport.UPDATE_ALWAYS
	for port in _ports:
		if is_instance_valid(port):
			port.render_target_update_mode = mode


func layout(page_size: Vector2) -> void:
	_place_line(_title, 0.65, 0.1, page_size, Color(0.08, 0.08, 0.08))
	_place_line(_subtitle, 0.56, 0.05, page_size, _INK)
	_place_line(_status, -0.5, 0.05, page_size, _INK)
	_status.size.y = _status.size.y * 3.2
	# placeFrames: three rows from z 0.38, six columns from x -0.7.
	# The card is 0.708 by 0.729, then the frame scale of 0.39.
	var card := _book_point(0.276, -0.284, page_size) - _book_point(0.0, 0.0, page_size)
	var row_z := 0.38
	var rows: Array[float] = []
	for _row in 3:
		rows.append(row_z)
		row_z -= 0.32
	var col_x := -0.7
	var cols: Array[float] = []
	for _col in 6:
		cols.append(col_x)
		col_x += 0.276
	var number_px := maxi(int(absf(card.y) * 0.22), 10)
	var mark_px := maxi(int(absf(card.y) * 0.55), 16)
	var title_px := maxi(int(absf(card.y) * 0.16), 10)
	for index in _MAX:
		var col: int = index % 6
		var row: int = index / 6
		var center := _book_point(cols[col], rows[row], page_size)
		var frame := _frames[index]
		frame.position = center - card * 0.5
		frame.size = card
		var mark := _marks[index]
		mark.position = Vector2(card.x * 0.12, card.y * 0.22)
		mark.size = Vector2(card.x * 0.76, card.y * 0.62)
		var number := _numbers[index]
		number.position = Vector2(card.x * 0.48, card.y * 0.62)
		number.size = Vector2(card.x * 0.46, card.y * 0.32)
		var mark_size := title_px if index == 0 or index == _MAX - 1 else mark_px
		ToonGui.style_label(mark, Color.WHITE, mark_size, Color(0, 0, 0, 0), 0)
		ToonGui.style_label(number, Color.WHITE, number_px, Color(0, 0, 0, 0), 0)


func refresh() -> void:
	_clear_toons()
	var tasks := _TASKS.for_selected()
	var track := -1 if tasks == null else tasks.training_track()
	var training := track >= 0 and track < ToonLoadout.TRACK_COUNT
	if training:
		var track_name := ToonLoadout.TRACK_NAMES[track]
		if tasks.training_done():
			_status.text = "You can now use %s gags in battle." % track_name
		else:
			_status.text = "You are training to use %s gags.\nWhen you complete all 16 tasks you\nwill be able to use %s gags in battle." % [track_name, track_name]
	else:
		_status.text = "You are not training any Gag Tracks now."
	for index in _MAX:
		var film := _films[index]
		var mark := _marks[index]
		var number := _numbers[index]
		mark.visible = false
		number.visible = false
		mark.text = ""
		number.text = ""
		if index == 0:
			film.modulate = _DARK
			mark.visible = training
			mark.text = "%s\nTraining\nFilm" % ToonLoadout.TRACK_NAMES[track] if training else ""
			_tint(mark, Color.WHITE)
			continue
		if index == _MAX - 1:
			film.modulate = _DARK
			mark.visible = true
			mark.text = "FIN"
			_tint(mark, Color.WHITE)
			continue
		# Frames 1 through 16. The last of those stays a question mark while
		# the track is still in progress, the way TrackPage.updatePage leaves it.
		var step := index - 1
		var done := false
		if training and step < 15:
			done = tasks.training_step(step)
		elif training and step == 15:
			done = tasks.training_done()
		var tint := Color(0.7, 0.7, 0.7) if not training else ToonLoadout.TRACK_COLORS[track]
		if done:
			film.modulate = tint
			_show_toon(_frames[index], track, index + 1)
		else:
			film.modulate = tint * Color(0.7, 0.7, 0.7, 1.0) if training else tint
			mark.visible = true
			mark.text = "?"
			var grey := Color(0.6, 0.6, 0.6) if not training else tint * Color(0.6, 0.6, 0.6, 1.0)
			_tint(mark, grey)
		number.visible = true
		number.text = str(index)
		var ink := Color(0.5, 0.5, 0.5) if not training else tint * Color(0.3, 0.3, 0.3, 1.0)
		_tint(number, ink)


func _show_toon(frame: Control, track: int, film_index: int) -> void:
	var style := ToonRoster.selected_style()
	if style == null:
		return
	var port := SubViewport.new()
	port.name = "ToonPort"
	port.size = Vector2i(128, 168)
	port.transparent_bg = true
	port.own_world_3d = true
	port.handle_input_locally = false
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	frame.add_child(port)
	var world := Node3D.new()
	port.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1, 1, 1)
	var sky := WorldEnvironment.new()
	sky.environment = environment
	world.add_child(sky)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.1
	camera.position = Vector3(0.55, 1.55, 3.4)
	camera.look_at(Vector3(0.0, 1.45, 0.0))
	camera.current = true
	world.add_child(camera)
	var actor := ToonActor.new()
	actor.footsteps = false
	world.add_child(actor)
	actor.show_style(style)
	# TrackFrame heading 210. rotation.y would replace the standing basis,
	# and the portrait would leave the film hole.
	var body_scale := actor.transform.basis.get_scale().x
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	upright = upright.rotated(Vector3.UP, deg_to_rad(150.0))
	actor.transform.basis = upright.scaled(Vector3.ONE * body_scale)
	var anim := _ANIMS[track] if track < _ANIMS.size() else "throw"
	var span := actor.action_length(anim)
	actor.pose_action(anim, span * float(film_index) / float(_MAX))
	var focus := Vector3(0.0, style.avatar_height() * 0.45, 0.0)
	var span_size := style.avatar_height() * 1.15
	var merged := AABB()
	var found := false
	for node in actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		if mesh.name == "drop_shadow":
			mesh.visible = false
			continue
		var piece := mesh.global_transform * mesh.get_aabb()
		merged = piece if not found else merged.merge(piece)
		found = true
	if found and merged.size.y > 0.05:
		focus = merged.get_center()
		span_size = maxf(merged.size.x, merged.size.y) * 1.35
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = span_size
	camera.position = focus + Vector3(span_size * 0.12, 0.0, span_size * 1.6)
	camera.look_at(focus)
	var view := TextureRect.new()
	view.name = "ToonView"
	view.texture = port.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.mouse_filter = MOUSE_FILTER_IGNORE
	# The white hole starts under the sprocket row. 21/125 of the card.
	view.position = frame.size * Vector2(0.04, 0.17)
	view.size = frame.size * Vector2(0.92, 0.66)
	frame.add_child(view)
	# The frame number sits on the film, in front of the portrait.
	var labels: Array[CanvasItem] = []
	for child in frame.get_children():
		if child is Label:
			labels.append(child)
	for label in labels:
		frame.move_child(label, -1)
	_ports.append(port)


func _clear_toons() -> void:
	for port in _ports:
		if is_instance_valid(port):
			port.queue_free()
	_ports.clear()
	for frame in _frames:
		var view := frame.get_node_or_null("ToonView")
		if view != null:
			view.queue_free()


func _line(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = MOUSE_FILTER_IGNORE
	return label


func _place_line(label: Label, book_z: float, scale: float, page_size: Vector2, color: Color) -> void:
	var height := absf(_book_point(0.0, book_z - scale, page_size).y - _book_point(0.0, book_z, page_size).y)
	var top := _book_point(0.0, book_z + scale * 0.35, page_size).y
	label.position = Vector2(page_size.x * 0.08, top)
	label.size = Vector2(page_size.x * 0.84, height)
	ToonGui.style_label(label, color, maxi(int(height * 0.8), 11), Color(0, 0, 0, 0), 0)


func _tint(label: Label, color: Color) -> void:
	label.add_theme_color_override("font_color", color)


func _book_point(book_x: float, book_z: float, page_size: Vector2) -> Vector2:
	var fx := (book_x + 1.0) / 2.0
	var fy := (0.75 - book_z) / 1.5
	return Vector2((fx - 0.0635) / 0.873 * page_size.x, (fy - 0.0118) / 0.873 * page_size.y)
