extends CanvasLayer

## Performance readout above the Laff meter, and the developer log the
## SpeedChat++ Console tab reads. F1 shows and hides the readout. The
## Shticker Book can rebind that key.

signal changed

const _KEYS := preload("res://scenes/shticker/keybinds.gd")
const _KEEP_LINES := 200
const _KEEP_SAMPLES := 180
const _METER_MARGIN := 9.8

var _panel: PanelContainer
var _label: Label
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
	if not _KEYS.event_is(event, "metrics"):
		return
	if _panel != null:
		_panel.visible = not _panel.visible
	get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if _logger != null:
		OS.remove_logger(_logger)
		_logger = null


func _process(delta: float) -> void:
	_place_panel()
	_fps_wait += delta
	if _label != null and _panel != null and _panel.visible and _fps_wait >= 0.25:
		_fps_wait = 0.0
		_label.text = _metrics_text()
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
	return "FPS %d    low %d\nframe %.1f ms   phys %.1f\ndraw %d   obj %d\nprim %s   vram %.0f\nnodes %s   pairs %d" % [int(fps), int(low), frame_ms, phys_ms, draws, objects, _grouped(prims), vram, _grouped(nodes), pairs]


func _place_panel() -> void:
	if _panel == null:
		return
	var view := get_viewport().get_visible_rect().size
	if view.distance_squared_to(_view) < 0.5 and _panel.size.y > 2.0:
		return
	_view = view
	# The Laff meter is 15% of the screen height, sitting on the bottom left.
	var meter := view.y * 0.15
	var height := 102.0
	var top := view.y - meter - _METER_MARGIN - 6.0 - height
	_panel.position = Vector2(_METER_MARGIN, maxf(top, 8.0))
	_panel.size = Vector2(220.0, height)


func _grouped(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (float(value) / 1000000.0)
	if value >= 1000:
		return "%.0fk" % (float(value) / 1000.0)
	return str(value)


func _bb(text: String) -> String:
	return text.replace("[", "[lb]")


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "PerformanceMetrics"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.04, 0.55)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	style.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.94))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	_label.add_theme_constant_override("outline_size", 3)
	_label.add_theme_constant_override("line_spacing", 1)
	_label.text = _metrics_text()
	_panel.add_child(_label)
	add_child(_panel)
	_place_panel()


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
