extends CanvasLayer

## Performance readout above the Laff meter, and the developer log the
## SpeedChat++ Console tab reads. F1 shows where the toon is standing.
## F2 shows and hides the performance readout. The Shticker Book can rebind both.

signal changed

const _KEYS := preload("res://scenes/shticker/keybinds.gd")
const _TITLES := preload("res://scenes/places/zone_title.gd")
const _LINKS := preload("res://scenes/places/tunnel_links.gd")
const _KEEP_LINES := 200
const _KEEP_SAMPLES := 180
const _METER_MARGIN := 9.8

var _panel: PanelContainer
var _label: Label
var _pos_panel: PanelContainer
var _pos_label: Label
var _body: CharacterBody3D
var _logger: Logger
var _lines: Array[Dictionary] = []
var _samples: Array[Dictionary] = []
var _dirty := false
var _sample_wait := 0.0
var _fps_wait := 0.0
var _view := Vector2.ZERO


func _ready() -> void:
	layer = 40
	_build_panel()
	_logger = _Capture.new(self)
	OS.add_logger(_logger)
	_push("Console ready.", false)


func _input(event: InputEvent) -> void:
	if _KEYS.event_is(event, "position"):
		if _pos_panel != null:
			_pos_panel.visible = not _pos_panel.visible
		_view = Vector2.ZERO
		get_viewport().set_input_as_handled()
		return
	if not _KEYS.event_is(event, "metrics"):
		return
	if _panel != null:
		_panel.visible = not _panel.visible
	_view = Vector2.ZERO
	get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if _logger != null:
		OS.remove_logger(_logger)
		_logger = null


func _process(delta: float) -> void:
	_place_panel()
	_fps_wait += delta
	if _fps_wait >= 0.25:
		_fps_wait = 0.0
		if _label != null and _panel != null and _panel.visible:
			_label.text = _metrics_text()
		if _pos_label != null and _pos_panel != null and _pos_panel.visible:
			_pos_label.text = _position_text()
	_sample_wait += delta
	if _sample_wait >= 1.0:
		_sample_wait = 0.0
		_record_sample()
	if _dirty:
		_dirty = false
		changed.emit()


func transcript() -> String:
	if _lines.is_empty():
		return "[color=#8a7058]No console output yet.[/color]"
	var body := ""
	for item in _lines:
		var row: Dictionary = item
		var text := _bb(str(row.get("text", "")))
		if body != "":
			body += "\n"
		if bool(row.get("bad", false)):
			body += "[color=#a32020]%s[/color]" % text
		else:
			body += text
	return body


func _push(message: String, bad: bool) -> void:
	var cleaned := message.replace("\r", "").strip_edges()
	if cleaned == "":
		return
	_lines.append({"text": cleaned, "bad": bad})
	while _lines.size() > _KEEP_LINES:
		_lines.pop_front()
	_dirty = true


func _record_sample() -> void:
	_samples.append({
		"fps": Engine.get_frames_per_second(),
		"frame_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"prims": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"vram": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
	})
	while _samples.size() > _KEEP_SAMPLES:
		_samples.pop_front()


func _metrics_text() -> String:
	var fps := Engine.get_frames_per_second()
	var low := fps
	for item in _samples:
		var row: Dictionary = item
		low = mini(low, int(row.get("fps", fps)))
	var frame_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objects := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var vram := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0)
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var pairs := int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))
	return "FPS %d    low %d\nframe %.1f ms   phys %.1f\ndraw %d   obj %d\nprim %s   vram %.0f\nnodes %s   pairs %d\n%s" % [int(fps), int(low), frame_ms, phys_ms, draws, objects, _grouped(prims), vram, _grouped(nodes), pairs, _ping_line()]


func _place_panel() -> void:
	if _panel == null or _pos_panel == null:
		return
	var view := get_viewport().get_visible_rect().size
	if view.distance_squared_to(_view) < 0.5 and _panel.size.y > 2.0:
		return
	_view = view
	# The Laff meter is 15% of the screen height, sitting on the bottom left.
	var meter := view.y * 0.15
	var floor_y := view.y - meter - _METER_MARGIN - 6.0
	var width := 260.0
	if _pos_panel.visible:
		var pos_h := 132.0
		var pos_top := floor_y - pos_h
		_pos_panel.position = Vector2(_METER_MARGIN, maxf(pos_top, 8.0))
		_pos_panel.size = Vector2(width, pos_h)
		floor_y = _pos_panel.position.y - 6.0
	if _panel.visible:
		var height := 120.0
		var top := floor_y - height
		_panel.position = Vector2(_METER_MARGIN, maxf(top, 8.0))
		_panel.size = Vector2(width, height)


func _ping_line() -> String:
	var ms := ToonNet.ping_ms()
	if ms < -1:
		return "ping host"
	if ms < 0:
		return "ping —"
	return "ping %d ms" % ms


func _grouped(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (float(value) / 1000000.0)
	if value >= 1000:
		return "%.0fk" % (float(value) / 1000.0)
	return str(value)


func _bb(text: String) -> String:
	return text.replace("[", "[lb]")


func _position_text() -> String:
	var scene := get_tree().current_scene
	var path := ""
	if scene != null:
		path = scene.scene_file_path
	var zone := int(_TITLES.zone_of(path))
	var hood := _LINKS.hood_of(zone) if zone != 0 else 0
	var titled: Dictionary = _TITLES.caption(path)
	var lines := str(titled.get("text", "")).split("\n", false)
	var hood_name := "—"
	var place := "—"
	if lines.size() > 0:
		hood_name = lines[0]
	if lines.size() > 1:
		place = lines[1]
	elif hood != 0 and zone == hood:
		place = "Playground"
	var where := "—"
	var heading := "—"
	var speed := "—"
	var body := _player_body()
	if body != null:
		var at := body.global_position
		where = "X %.2f   Y %.2f   Z %.2f" % [at.x, at.y, at.z]
		heading = "%.1f°" % _heading_of(body)
		speed = "%.1f" % body.velocity.length()
	else:
		where = "X —   Y —   Z —"
	var zone_line := "zone —" if zone == 0 else "zone %d" % zone
	return "%s\nH %s   speed %s\nDistrict %s\nHood %s\nPlace %s\n%s" % [where, heading, speed, ToonNet.district_name(), hood_name, place, zone_line]


func _player_body() -> CharacterBody3D:
	if _body != null and is_instance_valid(_body):
		return _body
	_body = _find_body(get_tree().root)
	return _body


func _find_body(node: Node) -> CharacterBody3D:
	if node is CharacterBody3D and node.name == "Player":
		return node as CharacterBody3D
	for child in node.get_children():
		var found := _find_body(child)
		if found != null:
			return found
	return null


func _heading_of(body: Node3D) -> float:
	var actor := _find_toon(body)
	if actor == null:
		return 0.0
	var forward := actor.global_basis.y
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(atan2(-forward.x, -forward.z))


func _find_toon(node: Node) -> Node3D:
	if node is ToonActor:
		return node as Node3D
	for child in node.get_children():
		var found := _find_toon(child)
		if found != null:
			return found
	return null


func _build_panel() -> void:
	_panel = _readout("PerformanceMetrics")
	_label = _panel.get_child(0) as Label
	_label.text = _metrics_text()
	add_child(_panel)
	_pos_panel = _readout("PlayerPosition")
	_pos_label = _pos_panel.get_child(0) as Label
	_pos_label.text = _position_text()
	add_child(_pos_panel)
	_place_panel()


func _readout(node_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.04, 0.55)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", ToonGui.font())
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.94))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_constant_override("line_spacing", 1)
	panel.add_child(label)
	return panel


class _Capture extends Logger:
	var host: Node

	func _init(owner: Node) -> void:
		host = owner

	func _log_message(message: String, error: bool) -> void:
		if is_instance_valid(host):
			host.call_deferred("_push", message, error)

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var where := file.get_file()
		var text := "%s:%d %s" % [where, line, rationale]
		if function != "":
			text = "%s in %s" % [text, function]
		if code != "":
			text = "%s (%s)" % [text, code]
		if is_instance_valid(host):
			host.call_deferred("_push", text, true)
