class_name DistrictPage
extends Control

## ShardPage. The district tab lists every shard, colors its population the
## original way, and shows how many toons are there. Clicking a name teleports
## into that district's copy of the playground. The current district cannot be
## clicked. A full one answers with the original rejection.

const _PLACES := preload("res://scenes/places/hood_places.gd")

const _CIRCLE := preload("res://assets/gui/shticker/pop_circle.png")
const _SCROLL_UP := preload("res://assets/gui/friends/FndsLst_ScrollUp.png")
const _SCROLL_DOWN := preload("res://assets/gui/friends/FndsLst_ScrollDN.png")
const _SCROLL_HOVER := preload("res://assets/gui/friends/FndsLst_ScrollUp_Rllvr.png")
const _DIALOG := preload("res://assets/gui/tutorial/dialog/dialog_box.png")
const _OK_UP := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_UP.png")
const _OK_DOWN := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_DN.png")
const _OK_HOVER := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_Rllvr.png")
const _HERE := Color(0.4, 0.8, 0.4)
const _INTRO := "Each District is a copy of the Toontown world.   "
const _MOVE := "  To move to a new District, click on its name."
const _REJECT := "Sorry, that district is full. Please try another one."

var _page := Vector2.ZERO
var _wait := 5.0
var _pending := -1
var _first := 0
var _queued := false
var _drawn := -1
var _drawn_here := -2
var _rows: Array[Dictionary] = []
var _help: Label
var _name_head: Label
var _pop_head: Label
var _list: Panel
var _clip: Control
var _stack: Control
var _up: TextureButton
var _down: TextureButton
var _total: Label
var _notice: Control
var _notice_frame: TextureRect
var _notice_text: Label
var _notice_ok: TextureButton


func _ready() -> void:
	name = "Districts"
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false
	_build()
	var net := ToonNet.live()
	if net != null:
		net.districts_changed.connect(refresh)
		net.district_rejected.connect(_on_rejected)
		net.district_seated.connect(_on_seated)


func _process(delta: float) -> void:
	if not visible:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = 5.0
	refresh()


func layout(page_size: Vector2) -> void:
	_page = page_size
	var title_h := page_size.y * 0.09
	var body := maxi(int(page_size.y * 0.034), 12)
	_help.position = Vector2(page_size.x * 0.06, title_h)
	_help.size = Vector2(page_size.x * 0.88, page_size.y * 0.2)
	ToonGui.style_label(_help, Color(0.08, 0.08, 0.08), body, Color(0, 0, 0, 0), 0)
	var head_y := page_size.y * 0.31
	_name_head.position = Vector2(page_size.x * 0.08, head_y)
	_name_head.size = Vector2(page_size.x * 0.4, page_size.y * 0.05)
	_pop_head.position = Vector2(page_size.x * 0.5, head_y)
	_pop_head.size = Vector2(page_size.x * 0.34, page_size.y * 0.05)
	ToonGui.style_label(_name_head, Color(0.08, 0.08, 0.08), body, Color(0, 0, 0, 0), 0)
	ToonGui.style_label(_pop_head, Color(0.08, 0.08, 0.08), body, Color(0, 0, 0, 0), 0)
	_pop_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var arrow := page_size.y * 0.055
	_list.position = Vector2(page_size.x * 0.06, page_size.y * 0.37)
	_list.size = Vector2(page_size.x * 0.78, page_size.y * 0.46)
	_clip.position = Vector2(6, 4)
	_clip.size = _list.size - Vector2(12, 8)
	_up.position = Vector2(_list.position.x + _list.size.x + page_size.x * 0.012, _list.position.y)
	_up.size = Vector2(arrow, arrow)
	_down.size = Vector2(arrow, arrow)
	_down.pivot_offset = _down.size * 0.5
	_down.scale = Vector2(1, -1)
	_down.position = Vector2(_up.position.x, _list.position.y + _list.size.y - arrow)
	_total.position = Vector2(page_size.x * 0.08, page_size.y * 0.85)
	_total.size = Vector2(page_size.x * 0.84, page_size.y * 0.12)
	ToonGui.style_label(_total, Color(0.08, 0.08, 0.08), body, Color(0, 0, 0, 0), 0)
	_place_notice()
	refresh()


func refresh() -> void:
	if _queued:
		return
	_queued = true
	_apply_refresh.call_deferred()


func _apply_refresh() -> void:
	_queued = false
	if _page == Vector2.ZERO or _help == null or not is_inside_tree():
		return
	var here := ToonNet.district_id()
	var wanted := _INTRO + ToonNet.where_text() + _MOVE
	var next := ToonNet.district_rows()
	var room := _row_height()
	var shown := 1
	if room > 1.0 and _clip.size.y > 1.0:
		shown = maxi(int(_clip.size.y / room), 1)
	var last := maxi(next.size() - shown, 0)
	_first = clampi(_first, 0, last)
	var changed := here != _drawn_here or _first != _drawn or _help.text != wanted or not _same(next)
	_help.text = wanted
	_rows = next
	var total := 0
	for row in _rows:
		total += int(row.get("avatar_count", 0))
	_total.text = "Total Toontown Population:\n%d" % total
	_drawn_here = here
	_drawn = _first
	if changed:
		_fill(shown, room)
	_arm(_up, _first > 0)
	_arm(_down, _first < last)


func _same(next: Array[Dictionary]) -> bool:
	if next.size() != _rows.size():
		return false
	for index in next.size():
		var have: Dictionary = _rows[index]
		var row: Dictionary = next[index]
		if int(have.get("id", -1)) != int(row.get("id", -1)):
			return false
		if int(have.get("avatar_count", -1)) != int(row.get("avatar_count", -1)):
			return false
		if String(have.get("name", "")) != String(row.get("name", "")):
			return false
	return true


func _build() -> void:
	var title := Label.new()
	title.name = "Title"
	title.text = "Districts"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(title)
	_help = Label.new()
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_help.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_help)
	_name_head = Label.new()
	_name_head.text = "Name"
	_name_head.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_name_head)
	_pop_head = Label.new()
	_pop_head.text = "Population"
	_pop_head.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_pop_head)
	_list = Panel.new()
	_list.mouse_filter = MOUSE_FILTER_IGNORE
	var sunken := StyleBoxFlat.new()
	sunken.bg_color = Color(0.85, 0.95, 1.0)
	sunken.border_color = Color(0.45, 0.58, 0.72)
	sunken.set_border_width_all(2)
	sunken.set_corner_radius_all(3)
	_list.add_theme_stylebox_override("panel", sunken)
	add_child(_list)
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = MOUSE_FILTER_IGNORE
	_list.add_child(_clip)
	_stack = Control.new()
	_stack.mouse_filter = MOUSE_FILTER_IGNORE
	_clip.add_child(_stack)
	_up = _scroll_button()
	_down = _scroll_button()
	_up.pressed.connect(_nudge.bind(-1))
	_down.pressed.connect(_nudge.bind(1))
	add_child(_up)
	add_child(_down)
	_total = Label.new()
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_total)


func _scroll_button() -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _SCROLL_UP
	button.texture_pressed = _SCROLL_DOWN
	button.texture_hover = _SCROLL_HOVER
	button.ignore_texture_size = true
	button.focus_mode = Control.FOCUS_NONE
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	return button


func _row_height() -> float:
	return maxf(_page.y * 0.055, 22.0)


func _fill(shown: int, room: float) -> void:
	for child in _stack.get_children():
		child.free()
	var width := _clip.size.x
	_stack.position = Vector2(0, -float(_first) * room)
	_stack.size = Vector2(width, room * float(_rows.size()))
	var body := maxi(int(room * 0.42), 11)
	var stop := mini(_first + shown, _rows.size())
	for index in range(_first, stop):
		_stack.add_child(_make_row(_rows[index], width, room, body, float(index) * room))


func _make_row(row: Dictionary, width: float, room: float, body: int, top: float) -> Control:
	var id := int(row.get("id", 0))
	var district_name := String(row.get("name", ""))
	var count := int(row.get("avatar_count", 0))
	var here := id == ToonNet.district_id()
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	button.position = Vector2(0, top)
	button.size = Vector2(width, room)
	button.add_theme_stylebox_override("normal", _row_box(Color(0, 0, 0, 0)))
	button.add_theme_stylebox_override("hover", _row_box(Color(1, 1, 0, 0.9)))
	button.add_theme_stylebox_override("pressed", _row_box(Color(0.5, 0.9, 1, 0.95)))
	button.add_theme_stylebox_override("disabled", _row_box(Color(0, 0, 0, 0)))
	if here:
		button.disabled = true
		button.mouse_filter = MOUSE_FILTER_IGNORE
	else:
		button.pressed.connect(_pick.bind(id, district_name, count))
	var name_label := Label.new()
	name_label.text = district_name
	name_label.position = Vector2(8, 0)
	name_label.size = Vector2(width * 0.48, room)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.mouse_filter = MOUSE_FILTER_IGNORE
	var ink := _HERE if here else Color(0.05, 0.05, 0.05)
	ToonGui.style_label(name_label, ink, body, Color(0, 0, 0, 0), 0)
	button.add_child(name_label)
	var count_label := Label.new()
	count_label.text = str(count)
	count_label.position = Vector2(width * 0.5, 0)
	count_label.size = Vector2(width * 0.14, room)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.mouse_filter = MOUSE_FILTER_IGNORE
	ToonGui.style_label(count_label, ink, body, Color(0, 0, 0, 0), 0)
	button.add_child(count_label)
	var word := Label.new()
	word.text = ToonNet.population_word(count)
	word.position = Vector2(width * 0.66, 0)
	word.size = Vector2(width * 0.2, room)
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word.mouse_filter = MOUSE_FILTER_IGNORE
	ToonGui.style_label(word, ToonNet.population_color(count), body, Color(0, 0, 0, 0), 0)
	button.add_child(word)
	var circle := TextureRect.new()
	circle.texture = _CIRCLE
	circle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	circle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	circle.modulate = ToonNet.population_color(count)
	circle.mouse_filter = MOUSE_FILTER_IGNORE
	var side := room * 0.72
	circle.size = Vector2(side, side)
	circle.position = Vector2(width - side - 6.0, (room - side) * 0.5)
	button.add_child(circle)
	return button


func _row_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	return box


func _pick(id: int, district_name: String, count: int) -> void:
	if _pending >= 0 or id == ToonNet.district_id():
		return
	if not _can_leave():
		return
	if id != ToonNet.WELCOME_VALLEY and count > ToonNet.MID_POP:
		_show_reject(_REJECT)
		return
	_pending = id
	var result := ToonNet.join_named(district_name)
	if result.begins_with("Asking"):
		return
	if not result.begins_with("You are in"):
		_pending = -1
		if result != "":
			_show_reject(result)
		return
	_depart(id)


func _on_seated(id: int) -> void:
	if id != _pending:
		return
	_depart(id)


func _on_rejected(reason: String) -> void:
	_pending = -1
	if reason == "":
		return
	_show_reject(reason)
	refresh()


## choseShard sends Welcome Valley to its playground and every other district
## to lastHood. The hole plays after the district AI accepts the seat.
func _depart(id: int) -> void:
	_pending = -1
	var book := _book()
	if book == null:
		return
	var welcome := id == ToonNet.WELCOME_VALLEY
	book.call("teleport_district", _hood_for(id), not welcome)


func _hood_for(id: int) -> int:
	if id == ToonNet.WELCOME_VALLEY:
		return _PLACES.TTC
	var tasks := ToonTasks.for_selected()
	var hood := 0
	if tasks != null:
		hood = tasks.return_hood()
	if hood < 1000:
		var scene := get_tree().current_scene
		if scene != null:
			hood = _PLACES.hood_for_scene(scene.scene_file_path)
	hood = _PLACES.hood_of(hood)
	if hood < 1000 or hood == _PLACES.ESTATE:
		return _PLACES.TTC
	return hood


func _can_leave() -> bool:
	var book := _book()
	return book != null and book.has_method("can_leave") and bool(book.call("can_leave"))


func _book() -> Node:
	var node: Node = self
	while node != null:
		if node.has_method("teleport_district"):
			return node
		node = node.get_parent()
	return null


func _nudge(step: int) -> void:
	_first += step
	refresh()


func _arm(button: TextureButton, enabled: bool) -> void:
	button.disabled = not enabled
	button.mouse_filter = MOUSE_FILTER_STOP if enabled else MOUSE_FILTER_IGNORE
	button.modulate = Color(1, 1, 1, 1) if enabled else Color(1, 1, 1, 0.35)


func _show_reject(message_text: String) -> void:
	if _notice != null:
		_notice_text.text = message_text
		_notice.visible = true
		_place_notice()
		return
	_notice = Control.new()
	_notice.mouse_filter = MOUSE_FILTER_STOP
	_notice.set_anchors_preset(PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.mouse_filter = MOUSE_FILTER_STOP
	dim.set_anchors_preset(PRESET_FULL_RECT)
	_notice.add_child(dim)
	_notice_frame = TextureRect.new()
	_notice_frame.texture = _DIALOG
	_notice_frame.modulate = Color(1, 1, 0.75)
	_notice_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_notice_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_notice_frame.mouse_filter = MOUSE_FILTER_IGNORE
	_notice.add_child(_notice_frame)
	_notice_text = Label.new()
	_notice_text.text = message_text
	_notice_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_text.mouse_filter = MOUSE_FILTER_IGNORE
	_notice.add_child(_notice_text)
	_notice_ok = TextureButton.new()
	_notice_ok.texture_normal = _OK_UP
	_notice_ok.texture_pressed = _OK_DOWN
	_notice_ok.texture_hover = _OK_HOVER
	_notice_ok.ignore_texture_size = true
	_notice_ok.focus_mode = Control.FOCUS_NONE
	_notice_ok.pressed.connect(_hide_reject)
	_notice.add_child(_notice_ok)
	add_child(_notice)
	_place_notice()


func _hide_reject() -> void:
	if _notice != null:
		_notice.visible = false


func _place_notice() -> void:
	if _notice == null or _page == Vector2.ZERO:
		return
	_notice.position = Vector2.ZERO
	_notice.size = _page
	var frame := _page * Vector2(0.72, 0.42)
	_notice_frame.position = (_page - frame) * 0.5
	_notice_frame.size = frame
	_notice_text.position = _notice_frame.position + Vector2(frame.x * 0.08, frame.y * 0.12)
	_notice_text.size = Vector2(frame.x * 0.84, frame.y * 0.46)
	ToonGui.style_label(_notice_text, Color(0.08, 0.08, 0.08), maxi(int(_page.y * 0.032), 12), Color(0, 0, 0, 0), 0)
	var ok := frame.y * 0.22
	_notice_ok.size = Vector2(ok * 2.2, ok)
	_notice_ok.position = Vector2(_notice_frame.position.x + (frame.x - _notice_ok.size.x) * 0.5, _notice_frame.position.y + frame.y * 0.68)
