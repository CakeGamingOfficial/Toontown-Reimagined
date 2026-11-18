class_name HouseEditor
extends Node

## houseDesign. Move Furniture opens the attic, the room list, and the trash.
## Drag a piece across the floor. Paintings stick to the wall and roll by 22.5
## degrees. Floor pieces turn by the same step. A table item sits on a table.
## DELETE sends an attic or room item to the trash instead of placing it.
## A window fills slot 2 or slot 4, the side of the room the toon is on.
## The camera walks camPosList, starting at the 40-unit shot, and turns in
## 90 degree steps. Dragging the view turns that same heading, and the wheel
## steps the four heights. Grid rounds the floor the way ROUND_TO does, and it
## starts at 1. The door blocker is the original sphere on the interior door.
## Rugs and paintings ignore it, and they ignore other furniture, because
## their wall mask does not include FurnitureSideBitmask. A floor piece
## tests the six footprint segments against walls, the door sphere, and
## the four side faces collisionTest builds. A hit pushes the piece out.
## If it still overlaps, the move returns to the last clear pose.

const _FURNITURE := preload("res://scenes/interiors/house_furniture.gd")
const _LAYOUT := preload("res://scenes/interiors/house_layout.gd")
const _SURFACES := preload("res://scenes/interiors/house_surfaces.gd")
const _CLOSET := preload("res://scenes/catalog/catalog_closet.gd")
const _ISSUE := "res://assets/catalog/issue.json"
const _CREAM := Color(0.945, 0.875, 0.706, 1)
const _INK := Color(0.16, 0.1, 0.05, 1)
const _TURN := 22.5
## makeDoorBlocker. Panda (-12, -33, 0) lands on the interior door after the
## Z-up export. The radius is the original CollisionSphere.
const _DOOR := Vector2(-12.0, 33.0)
const _DOOR_RADIUS := 7.5
const _GRID := 1.0
const _BACK: Array[float] = [20.0, 20.0, 15.0, 10.0]
const _UP: Array[float] = [20.0, 30.0, 40.0, 50.0]
const _PAPER: Array[String] = ["wallpaper", "flooring", "moulding", "wainscoting"]
## LocalToon.loadFurnitureGui. The attic card sits at (-1.19, 0.33) with scale 0.04.
const _ATTIC := preload("res://assets/gui/house/attic.png")
const _ROOF := preload("res://assets/gui/house/rooftile.png")
const _ATTIC_UP := preload("res://assets/gui/house/attic_up.png")
const _ATTIC_DOWN := preload("res://assets/gui/house/attic_down.png")
const _ATTIC_HOVER := preload("res://assets/gui/house/attic_rollover.png")
const _STOP_UP := preload("res://assets/gui/house/attic_x_up.png")
const _STOP_DOWN := preload("res://assets/gui/house/attic_x_down.png")
const _STOP_HOVER := preload("res://assets/gui/house/attic_x_rollover.png")

var _host: Node
var _editing := false
var _root: Node3D
var _selected: Node3D
var _held := ""
var _dragging := false
var _looking := false
var _focus := Vector3.ZERO
var _cam_index := 2
var _cam_heading := 0.0
var _bounds := AABB()
var _names: Dictionary = {}
var _ask_ok := Callable()
var _move: TextureButton
var _attic_art: TextureRect
var _roof_art: TextureRect
var _move_label: Label
var _attic: PanelContainer
var _room: PanelContainer
var _trash: PanelContainer
var _attic_list: VBoxContainer
var _room_list: VBoxContainer
var _trash_list: VBoxContainer
var _tools: HBoxContainer
var _cams: HBoxContainer
var _grid_button: Button
var _delete_button: Button
var _deleting := false
var _grid := _GRID
var _ask: PanelContainer
var _ask_text: Label
var _ask_cancel: Button


func open_house(host: Node) -> void:
	_host = host
	var scene := host.get_parent() as Node3D
	if scene == null:
		return
	_root = scene.get_node_or_null("OrderedFurniture") as Node3D
	_bounds = _measure(scene)
	_focus = _bounds.get_center()
	_focus.y = _bounds.position.y + 0.4
	_load_names()
	_build()


func holds_camera() -> bool:
	return _editing


func aim(camera: Camera3D) -> void:
	if camera == null or not _editing:
		return
	var yaw := deg_to_rad(_cam_heading)
	var offset := Vector3(sin(yaw), 0.0, cos(yaw)) * _BACK[_cam_index]
	camera.global_position = _focus + Vector3(0.0, _UP[_cam_index], 0.0) + offset
	camera.look_at(_focus, Vector3.UP)


func _build() -> void:
	var hud := _hud()
	_build_attic_button()
	_attic = _pile("In the attic")
	_room = _pile("In the room")
	_trash = _pile("In the trash")
	_attic_list = _attic.find_child("List", true, false) as VBoxContainer
	_room_list = _room.find_child("List", true, false) as VBoxContainer
	_trash_list = _trash.find_child("List", true, false) as VBoxContainer
	_tools = HBoxContainer.new()
	_tools.position = Vector2(18, 0)
	_tools.add_theme_constant_override("separation", 8)
	_tools.visible = false
	_tools.mouse_filter = Control.MOUSE_FILTER_STOP
	_tools.z_index = 12
	_tools.custom_minimum_size = Vector2(456, 40)
	_tools.add_child(_tool("Rotate Left", _turn_piece.bind(-1.0)))
	_tools.add_child(_tool("Rotate Right", _turn_piece.bind(1.0)))
	_tools.add_child(_tool("Send\nto attic", _send_attic))
	_tools.add_child(_tool("Delete", _send_trash))
	hud.add_child(_tools)
	_cams = HBoxContainer.new()
	_cams.add_theme_constant_override("separation", 8)
	_cams.visible = false
	_cams.mouse_filter = Control.MOUSE_FILTER_STOP
	_cams.z_index = 12
	# Six 108-wide buttons plus the gaps. The combined minimum is 0 until a
	# layout pass, which left this bar with no clickable rect.
	_cams.custom_minimum_size = Vector2(688, 40)
	_cams.add_child(_tool("Zoom\nIn", _zoom.bind(-1)))
	_cams.add_child(_tool("Zoom\nOut", _zoom.bind(1)))
	_cams.add_child(_tool("Camera\nLeft", _orbit.bind(-1.0)))
	_cams.add_child(_tool("Camera\nRight", _orbit.bind(1.0)))
	_grid_button = _tool("Grid\nOn", _toggle_grid)
	_cams.add_child(_grid_button)
	_delete_button = _tool("DELETE", _toggle_delete)
	_cams.add_child(_delete_button)
	hud.add_child(_cams)
	_ask = PanelContainer.new()
	_ask.visible = false
	_ask.mouse_filter = Control.MOUSE_FILTER_STOP
	_ask.custom_minimum_size = Vector2(360, 120)
	var ask_box := StyleBoxFlat.new()
	ask_box.bg_color = _CREAM
	ask_box.set_corner_radius_all(10)
	ask_box.set_content_margin_all(12)
	_ask.add_theme_stylebox_override("panel", ask_box)
	var ask_column := VBoxContainer.new()
	ask_column.add_theme_constant_override("separation", 8)
	_ask.add_child(ask_column)
	_ask_text = Label.new()
	_ask_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ask_text.custom_minimum_size = Vector2(336, 48)
	ToonGui.style_label(_ask_text, _INK, 16, Color(0, 0, 0, 0), 0)
	ask_column.add_child(_ask_text)
	var ask_row := HBoxContainer.new()
	ask_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ask_row.add_theme_constant_override("separation", 8)
	var yes := _tool("OK", _ask_yes)
	_ask_cancel = _tool("Cancel", _ask_no)
	ask_row.add_child(yes)
	ask_row.add_child(_ask_cancel)
	ask_column.add_child(ask_row)
	hud.add_child(_ask)
	_dock()


func _pile(title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.visible = false
	panel.custom_minimum_size = Vector2(210, 280)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := StyleBoxFlat.new()
	box.bg_color = Color(_CREAM.r, _CREAM.g, _CREAM.b, 0.94)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var label := Label.new()
	label.name = "Title"
	label.text = title
	ToonGui.style_label(label, _INK, 16, Color(0, 0, 0, 0), 0)
	column.add_child(label)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(190, 230)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_hud().add_child(panel)
	return panel


func _build_attic_button() -> void:
	var hud := _hud()
	_attic_art = TextureRect.new()
	_attic_art.texture = _ATTIC
	_attic_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attic_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_attic_art.stretch_mode = TextureRect.STRETCH_SCALE
	hud.add_child(_attic_art)
	_roof_art = TextureRect.new()
	_roof_art.texture = _ROOF
	_roof_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roof_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_roof_art.stretch_mode = TextureRect.STRETCH_SCALE
	hud.add_child(_roof_art)
	_move = TextureButton.new()
	_move.focus_mode = Control.FOCUS_NONE
	_move.ignore_texture_size = true
	_move.stretch_mode = TextureButton.STRETCH_SCALE
	_move.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_move.pressed.connect(_toggle)
	_move.mouse_entered.connect(_show_move_text.bind(true))
	_move.mouse_exited.connect(_show_move_text.bind(false))
	ToonGui.button_sounds(_move)
	hud.add_child(_move)
	_move_label = Label.new()
	_move_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_move_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_move_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_move_label.visible = false
	hud.add_child(_move_label)
	_pose_attic_button()


func _pose_attic_button() -> void:
	if _move == null:
		return
	_move.texture_normal = _STOP_UP if _editing else _ATTIC_UP
	_move.texture_pressed = _STOP_DOWN if _editing else _ATTIC_DOWN
	_move.texture_hover = _STOP_HOVER if _editing else _ATTIC_HOVER
	if _move_label != null:
		_move_label.text = "Done\nMoving" if _editing else "Move\nFurniture"


func _show_move_text(show: bool) -> void:
	if _move_label != null:
		_move_label.visible = show


func _toggle() -> void:
	if _editing:
		_finish()
	else:
		_begin()


func _begin() -> void:
	if _host == null or _root == null:
		return
	_editing = true
	_pose_attic_button()
	_attic.visible = true
	_room.visible = true
	_trash.visible = true
	_cams.visible = true
	if _host.has_method("furniture_lock"):
		_host.call("furniture_lock", true)
	_refresh()
	_dock()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_camera()


func _finish() -> void:
	_dragging = false
	_looking = false
	_select(null)
	_editing = false
	_set_delete(false)
	_pose_attic_button()
	_attic.visible = false
	_room.visible = false
	_trash.visible = false
	_tools.visible = false
	_cams.visible = false
	_ask.visible = false
	if _host.has_method("furniture_lock"):
		_host.call("furniture_lock", false)


func _refresh() -> void:
	_FURNITURE.settle()
	var owned := _CLOSET.catalog_tokens()
	_fill(_attic_list, _attic_tokens(owned), _use)
	_fill(_room_list, _room_tokens(), _pick_token)
	_fill(_trash_list, _LAYOUT.in_trash(owned), _restore)
	_tools.visible = _editing and (_selected != null or _held != "")


func _fill(list: VBoxContainer, tokens: PackedStringArray, pressed: Callable) -> void:
	if list == null:
		return
	for child in list.get_children():
		child.queue_free()
	if tokens.is_empty():
		var empty := Label.new()
		empty.text = "Nothing here."
		ToonGui.style_label(empty, _INK, 14, Color(0, 0, 0, 0), 0)
		list.add_child(empty)
		return
	for token in tokens:
		var button := Button.new()
		button.text = _label(token)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		_style_button(button)
		button.pressed.connect(pressed.bind(token))
		list.add_child(button)


func _use(token: String) -> void:
	if _deleting:
		_ask_trash(token)
		return
	var kind := token.split(":")[0]
	if kind == "furniture":
		_bring(token)
	elif kind == "window":
		_seat_window(token)
	elif kind in _PAPER:
		_LAYOUT.choose_surface(kind, token)
		_SURFACES.apply(_host.get_parent())
		_refresh()


func _bring(token: String) -> void:
	if _root == null or _root.get_node_or_null(token.replace(":", "_")) != null:
		return
	var model := _FURNITURE.make(_FURNITURE.item_id(token))
	if model == null:
		return
	model.name = token.replace(":", "_")
	model.set_meta("token", token)
	_root.add_child(model)
	if _FURNITURE.is_painting(_FURNITURE.item_id(token)):
		model.position = Vector3(_bounds.position.x + _bounds.size.x - 0.35, _bounds.position.y + 1.7, _focus.z)
		model.rotation.y = -PI * 0.5
	else:
		var landed := _snap(Vector3(_focus.x, _bounds.position.y + 0.02, _focus.z))
		model.position = landed
		_select(model)
		var fitted := _fit(model.global_position)
		if bool(fitted.get("ok", false)):
			model.position = _root.to_local(fitted["pos"] as Vector3)
		else:
			var away := model.global_position - _door_center()
			away.y = 0.0
			if away.length() < 0.1:
				away = Vector3(0.0, 0.0, -1.0)
			away = away.normalized()
			for _step in 8:
				landed += away * 2.0
				landed = _snap(landed)
				model.position = _root.to_local(landed)
				fitted = _fit(model.global_position)
				if bool(fitted.get("ok", false)):
					model.position = _root.to_local(fitted["pos"] as Vector3)
					break
	_save(model)
	_select(model)
	_refresh()


func _seat_window(token: String) -> void:
	var slots := _LAYOUT.windows()
	while slots.size() < 6:
		slots.append("")
	var index := _window_slot()
	var vacated: Array[int] = []
	for i in slots.size():
		if slots[i] == token and i != index:
			slots[i] = ""
			vacated.append(i)
	slots[index] = token
	_LAYOUT.set_windows(slots)
	_FURNITURE.fill_window(_host.get_parent(), index, token)
	for hole in vacated:
		_FURNITURE.fill_window(_host.get_parent(), hole, "")
	_refresh()


## bringWindowFromAttic. Slot 2 is the south wall, slot 4 the far wall.
## The exported interior stores Panda Y as negative Godot Z.
func _window_slot() -> int:
	var body := _host as Node3D
	var scene := _host.get_parent() as Node3D
	if body == null or scene == null:
		return 2
	if -scene.to_local(body.global_position).z < 2.3:
		return 2
	return 4


func _pick_token(token: String) -> void:
	if _deleting:
		_ask_trash(token)
		return
	if token.begins_with("window:"):
		_select(null)
		_held = token
		_tools.visible = true
		return
	_select(_piece(token))


func _restore(token: String) -> void:
	_confirm("Return this item to the attic from the trash?", _commit_restore.bind(token))


func _send_attic() -> void:
	if _current().is_empty():
		return
	_confirm("Return this item to the attic?", _commit_drop.bind(false))


func _send_trash() -> void:
	var token := _current()
	if token.is_empty():
		return
	_ask_trash(token)


func _ask_trash(token: String) -> void:
	if token.is_empty():
		return
	if token.begins_with("furniture:"):
		var line := _FURNITURE.fixed_line(_FURNITURE.item_id(token))
		if line != "":
			_confirm(line, Callable())
			return
	_confirm("Click OK to send this item to the trash, or Cancel to keep it.", _commit_token.bind(token))


func _toggle_delete() -> void:
	_set_delete(not _deleting)


func _set_delete(on: bool) -> void:
	_deleting = on
	var attic_title := _attic.find_child("Title", true, false) as Label
	var room_title := _room.find_child("Title", true, false) as Label
	if attic_title != null:
		attic_title.text = "Delete?" if on else "In the attic"
	if room_title != null:
		room_title.text = "Delete?" if on else "In the room"
	if _delete_button != null:
		_delete_button.text = "DONE" if on else "DELETE"


func _commit_restore(token: String) -> void:
	_LAYOUT.restore(token)
	_refresh()


func _commit_drop(to_trash: bool) -> void:
	if to_trash:
		_commit_token(_current())
	else:
		_return_token(_current())


func _commit_token(token: String) -> void:
	if token.is_empty():
		return
	var piece := _piece(token)
	var hole := _window_index(token)
	if _selected == piece:
		_select(null)
	_LAYOUT.trash(token)
	_FURNITURE.settle()
	if piece != null and is_instance_valid(piece):
		piece.free()
	if hole >= 0:
		_FURNITURE.fill_window(_host.get_parent(), hole, "")
	if token.split(":")[0] in _PAPER:
		_SURFACES.apply(_host.get_parent())
	_refresh()


func _return_token(token: String) -> void:
	if token.is_empty():
		return
	var piece := _piece(token)
	var hole := _window_index(token)
	if _selected == piece:
		_select(null)
	_LAYOUT.forget(token)
	if piece != null and is_instance_valid(piece):
		piece.free()
	if hole >= 0:
		_FURNITURE.fill_window(_host.get_parent(), hole, "")
	if token.split(":")[0] in _PAPER:
		_SURFACES.apply(_host.get_parent())
	_refresh()


func _current() -> String:
	if _selected != null and is_instance_valid(_selected):
		return String(_selected.get_meta("token", ""))
	return _held


func _window_index(token: String) -> int:
	var slots := _LAYOUT.windows()
	for i in slots.size():
		if slots[i] == token:
			return i
	return -1


func _attic_tokens(owned: PackedStringArray) -> PackedStringArray:
	var out := _LAYOUT.in_attic(_FURNITURE.owned_furniture())
	var seated := _LAYOUT.windows()
	var trashed := _LAYOUT.in_trash(owned)
	for token in owned:
		var kind := token.split(":")[0]
		if kind == "furniture" or kind == "trick" or trashed.has(token):
			continue
		if kind == "window" and seated.has(token):
			continue
		if kind != "window" and not (kind in _PAPER):
			continue
		if not out.has(token):
			out.append(token)
	return out


func _zoom(step: int) -> void:
	_cam_index = clampi(_cam_index + step, 0, _BACK.size() - 1)
	_show_camera()


func _orbit(sign: float) -> void:
	_cam_heading = fposmod(_cam_heading + 90.0 * sign, 360.0)
	_show_camera()


func _show_camera() -> void:
	var camera := _view()
	if camera == null:
		return
	camera.current = true
	aim(camera)


func _confirm(text: String, ok: Callable) -> void:
	_ask_text.text = text
	_ask_ok = ok
	_ask_cancel.visible = ok.is_valid()
	_ask.visible = true
	_dock()


func _ask_yes() -> void:
	var ok := _ask_ok
	_ask_ok = Callable()
	_ask.visible = false
	if ok.is_valid():
		ok.call()


func _ask_no() -> void:
	_ask_ok = Callable()
	_ask.visible = false


func _turn_piece(sign: float) -> void:
	if _selected == null:
		return
	var id := _FURNITURE.item_id(String(_selected.get_meta("token", "")))
	if _FURNITURE.is_painting(id):
		var rolled := rad_to_deg(_selected.rotation.z) + _TURN * -sign
		_selected.rotation.z = deg_to_rad(_round_to(rolled, _TURN))
		_save(_selected)
		return
	var before := _selected.rotation.y
	_selected.rotation.y = before + deg_to_rad(_TURN * sign)
	var fitted := _fit(_selected.global_position)
	if not bool(fitted.get("ok", false)):
		_selected.rotation.y = before
		return
	_selected.position = _root.to_local(fitted["pos"] as Vector3)
	_save(_selected)


func _unhandled_input(event: InputEvent) -> void:
	if not _editing:
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_WHEEL_UP or click.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if click.pressed and not _over_gui():
				_zoom(-1 if click.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			get_viewport().set_input_as_handled()
			return
		# The house scene still has the free-fly camera. A right click there
		# captures the pointer, and the next furniture drag uses the screen center.
		if click.button_index == MOUSE_BUTTON_RIGHT:
			get_viewport().set_input_as_handled()
			return
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			_press(click.position)
		else:
			_dragging = false
			_looking = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		_drag((event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var turning := _looking or (motion.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0
		if not turning or _over_gui():
			return
		_cam_heading = fposmod(_cam_heading - motion.relative.x * 0.4, 360.0)
		_show_camera()
		get_viewport().set_input_as_handled()


func _press(screen: Vector2) -> void:
	if _ask.visible or _over_gui():
		return
	var piece := _pick_piece(screen)
	if piece == null:
		_looking = true
		_select(null)
		_refresh()
		return
	_looking = false
	_select(piece)
	_dragging = true
	_refresh()


func _drag(screen: Vector2) -> void:
	if _selected == null or _host == null:
		return
	var camera := _view()
	if camera == null:
		return
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var token := String(_selected.get_meta("token", ""))
	var id := _FURNITURE.item_id(token)
	var next := _selected.global_position
	var turned := _selected.rotation.y
	var floor_y := _bounds.position.y + 0.02
	if _FURNITURE.is_painting(id):
		var hit := _wall_ray(origin, dir)
		if hit.is_empty():
			return
		var point: Vector3 = hit.position
		var normal: Vector3 = hit.normal
		next = point + normal * 0.08
		next.y = maxf(next.y, _bounds.position.y + 0.8)
		turned = _wall_yaw(normal)
	else:
		var dropped: Variant = _floor_point(origin, dir)
		if dropped == null:
			return
		var at := dropped as Vector3
		at.y = floor_y
		if _FURNITURE.on_table(id):
			var table := _table_at(at)
			if table != null:
				at.y = _top(table)
		next = _snap(at)
		var fitted := _fit(next)
		if not bool(fitted.get("ok", false)):
			return
		next = fitted["pos"] as Vector3
	_selected.position = _root.to_local(next)
	_selected.rotation.y = turned
	_save(_selected)


func _toggle_grid() -> void:
	_grid = 0.0 if _grid > 0.0 else _GRID
	if _grid_button != null:
		_grid_button.text = "Grid\nOn" if _grid > 0.0 else "Grid\nOff"


func _snap(at: Vector3) -> Vector3:
	if _grid <= 0.0:
		return at
	return Vector3(_round_to(at.x, _grid), at.y, _round_to(at.z, _grid))


func _round_to(value: float, spacing: float) -> float:
	return roundf(value / spacing) * spacing


## collisionTest. The footprint is the tight box, grown 0.1 on the floor,
## with the four corners at height 0.2. Six segments (the edges and both
## diagonals) are tested. Other pieces contribute the four side faces.
func _fit(proposed: Vector3) -> Dictionary:
	if _selected == null:
		return {"ok": false, "pos": proposed}
	var id := _FURNITURE.item_id(String(_selected.get_meta("token", "")))
	var sides := not (_FURNITURE.is_painting(id) or _FURNITURE.is_rug(id))
	var start_pos := _selected.global_position
	var start_xf := _selected.global_transform
	var corners := _foot_corners(_selected)
	var drag := _drag_point(_selected)
	var xf := _pose(_selected, proposed)
	var hits := _collect(_selected, _world_pts(xf, corners), sides, false)
	if hits.is_empty():
		return {"ok": true, "pos": proposed}
	var pushed := proposed
	var offsets := _edge_offsets(xf, start_xf, hits, drag)
	if not offsets.is_empty():
		pushed = proposed + xf.basis * _combine(offsets)
		xf = _pose(_selected, pushed)
		if _collect(_selected, _world_pts(xf, corners), sides, false).is_empty():
			return {"ok": true, "pos": pushed}
	if pushed.distance_to(start_pos) < 0.001:
		var started := _collect(_selected, _world_pts(start_xf, corners), sides, false).size()
		if hits.size() <= started:
			return {"ok": true, "pos": proposed}
		return {"ok": false, "pos": start_pos}
	var path_hits := _collect(_selected, _path_pts(start_xf, xf, corners), sides, true)
	if not path_hits.is_empty():
		var longest := Vector3.ZERO
		for item in path_hits:
			var row: Dictionary = item
			var shift := _path_shift(xf, row["a"] as Vector3, row["p"] as Vector3)
			if shift.length() > longest.length():
				longest = shift
		if longest.length() > 0.0:
			pushed += xf.basis * longest
			xf = _pose(_selected, pushed)
	var stayed := _collect(_selected, _world_pts(xf, corners), sides, false)
	if stayed.is_empty():
		return {"ok": true, "pos": pushed}
	# The wall solids can already overlap a piece that was placed before they
	# existed. Sliding is allowed while the move does not pick up more contacts.
	var before := _collect(_selected, _world_pts(start_xf, corners), sides, false).size()
	if stayed.size() <= before:
		return {"ok": true, "pos": pushed}
	return {"ok": false, "pos": start_pos}


func _edge_offsets(xf: Transform3D, start_xf: Transform3D, hits: Array, drag: Vector3) -> Array[Vector3]:
	var offsets: Array[Vector3] = []
	for item in hits:
		var row: Dictionary = item
		var shift := _segment_offset(xf, start_xf, row["a"] as Vector3, row["b"] as Vector3, row["p"] as Vector3, row["n"] as Vector3, drag)
		if shift.length() > 0.0001:
			offsets.append(shift)
	return offsets


func _segment_offset(xf: Transform3D, start_xf: Transform3D, a: Vector3, b: Vector3, hit: Vector3, normal: Vector3, drag: Vector3) -> Vector3:
	var inv := xf.affine_inverse()
	var local_normal := inv.basis * normal
	var nlen2 := local_normal.length_squared()
	if nlen2 < 0.0001:
		return Vector3.ZERO
	var start_inv := start_xf.affine_inverse()
	var seen := start_inv * hit
	var seen_normal := start_inv.basis * normal
	if (seen - drag).dot(seen_normal) > 0.0:
		return Vector3.ZERO
	var local_hit := inv * hit
	var along_a := local_normal * (local_hit - inv * a).dot(local_normal) / nlen2
	if along_a.dot(local_normal) > 0.0:
		return along_a * 1.01
	return local_normal * (local_hit - inv * b).dot(local_normal) / nlen2 * 1.01


func _path_shift(xf: Transform3D, a: Vector3, hit: Vector3) -> Vector3:
	var inv := xf.affine_inverse()
	return inv * hit - inv * a


func _combine(offsets: Array[Vector3]) -> Vector3:
	var ortho1 := offsets[0]
	var ortho2 := Vector3.ZERO
	var v1 := ortho1.normalized()
	for i in range(1, offsets.size()):
		var offset := offsets[i]
		if offset.length() < 0.0001:
			continue
		var dp := v1.dot(offset.normalized())
		if absf(dp) > 0.95:
			if offset.length() > ortho1.length():
				ortho1 = offset
		elif absf(dp) < 0.05:
			if offset.length() > ortho2.length():
				ortho2 = offset
		else:
			var span := ortho1.length_squared()
			if span < 0.0001:
				continue
			var parallel := ortho1 * offset.dot(ortho1) / span
			var perp := offset - parallel
			if parallel.length() > ortho1.length():
				ortho1 = parallel
			if perp.length() > ortho2.length():
				ortho2 = perp
	return ortho1 + ortho2


func _collect(piece: Node3D, ends: PackedVector3Array, sides: bool, paths: bool) -> Array:
	var hits: Array = []
	var count := 4 if paths else 6
	for i in count:
		var a := ends[i * 2]
		var b := ends[i * 2 + 1]
		if a.distance_to(b) < 0.001:
			continue
		if sides:
			_hit_sphere(a, b, _door_center(), _DOOR_RADIUS, hits)
			_hit_sides(piece, a, b, hits)
		_hit_walls(a, b, hits)
	return hits


func _hit_sphere(a: Vector3, b: Vector3, center: Vector3, radius: float, hits: Array) -> void:
	var delta := b - a
	var qa := delta.length_squared()
	if qa < 0.0001:
		return
	var from_center := a - center
	var qb := 2.0 * from_center.dot(delta)
	var qc := from_center.length_squared() - radius * radius
	var disc := qb * qb - 4.0 * qa * qc
	if disc < 0.0:
		return
	var root := sqrt(disc)
	var t1 := (-qb - root) / (2.0 * qa)
	var t2 := (-qb + root) / (2.0 * qa)
	var t := -1.0
	if t1 >= 0.0 and t1 <= 1.0:
		t = t1
	elif t2 >= 0.0 and t2 <= 1.0:
		t = t2
	if t < 0.0:
		return
	var point := a.lerp(b, t)
	var normal := point - center
	if normal.length() < 0.0001:
		return
	hits.append({"a": a, "b": b, "p": point, "n": normal.normalized()})


func _hit_sides(piece: Node3D, a: Vector3, b: Vector3, hits: Array) -> void:
	if _root == null:
		return
	for child in _root.get_children():
		var other := child as Node3D
		if other == null or other == piece:
			continue
		var other_id := _FURNITURE.item_id(String(other.get_meta("token", "")))
		if _FURNITURE.is_painting(other_id) or _FURNITURE.is_rug(other_id):
			continue
		for face in _quads(other):
			var row: Dictionary = face
			var point: Variant = _hit_quad(a, b, row["o"] as Vector3, row["u"] as Vector3, row["v"] as Vector3, row["n"] as Vector3)
			if point == null:
				continue
			hits.append({"a": a, "b": b, "p": point as Vector3, "n": row["n"] as Vector3})


func _hit_quad(a: Vector3, b: Vector3, origin: Vector3, edge_u: Vector3, edge_v: Vector3, normal: Vector3) -> Variant:
	var denom := normal.dot(b - a)
	if absf(denom) < 0.0001:
		return null
	var t := normal.dot(origin - a) / denom
	if t < 0.0 or t > 1.0:
		return null
	var point := a.lerp(b, t)
	var rel := point - origin
	var uu := edge_u.length_squared()
	var vv := edge_v.length_squared()
	if uu < 0.0001 or vv < 0.0001:
		return null
	var u := rel.dot(edge_u) / uu
	var v := rel.dot(edge_v) / vv
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return null
	return point


func _hit_walls(a: Vector3, b: Vector3, hits: Array) -> void:
	if _selected == null:
		return
	var space := _selected.get_world_3d().direct_space_state
	var from := a
	var dir := b - a
	if dir.length() < 0.001:
		return
	dir = dir.normalized()
	for _step in 4:
		if from.distance_to(b) < 0.02:
			return
		var query := PhysicsRayQueryParameters3D.create(from, b)
		query.collision_mask = 1
		query.collide_with_areas = false
		var found := space.intersect_ray(query)
		if found.is_empty():
			return
		var normal: Vector3 = found.normal
		var point: Vector3 = found.position
		if absf(normal.y) < 0.1:
			hits.append({"a": a, "b": b, "p": point, "n": normal})
		from = point + dir * 0.05


func _quads(piece: Node3D) -> Array:
	var box := _local_box(piece)
	var lo := box.position
	var hi := box.end
	lo.x -= 0.09
	lo.z -= 0.09
	hi.x += 0.09
	hi.z += 0.09
	var xf := piece.global_transform
	var faces: Array[Vector3] = [
		lo, Vector3(0.0, 0.0, hi.z - lo.z), Vector3(0.0, hi.y - lo.y, 0.0),
		Vector3(hi.x, lo.y, lo.z), Vector3(0.0, 0.0, hi.z - lo.z), Vector3(0.0, hi.y - lo.y, 0.0),
		lo, Vector3(hi.x - lo.x, 0.0, 0.0), Vector3(0.0, hi.y - lo.y, 0.0),
		Vector3(lo.x, lo.y, hi.z), Vector3(hi.x - lo.x, 0.0, 0.0), Vector3(0.0, hi.y - lo.y, 0.0),
	]
	var center := xf * box.get_center()
	var out: Array = []
	for i in 4:
		var origin := xf * faces[i * 3]
		var edge_u := xf.basis * faces[i * 3 + 1]
		var edge_v := xf.basis * faces[i * 3 + 2]
		var normal := edge_u.cross(edge_v)
		if normal.length() < 0.0001:
			continue
		normal = normal.normalized()
		if normal.dot(origin - center) < 0.0:
			normal = -normal
		out.append({"o": origin, "u": edge_u, "v": edge_v, "n": normal})
	return out


func _foot_corners(piece: Node3D) -> PackedVector3Array:
	var box := _local_box(piece)
	var lo := box.position
	var hi := box.end
	lo.x -= 0.1
	lo.z -= 0.1
	hi.x += 0.1
	hi.z += 0.1
	return PackedVector3Array([
		Vector3(lo.x, 0.2, lo.z),
		Vector3(hi.x, 0.2, lo.z),
		Vector3(hi.x, 0.2, hi.z),
		Vector3(lo.x, 0.2, hi.z),
	])


func _drag_point(piece: Node3D) -> Vector3:
	var box := _local_box(piece)
	var lo := box.position
	var hi := box.end
	lo.x -= 0.1
	lo.z -= 0.1
	hi.x += 0.1
	hi.z += 0.1
	var mid := (lo + hi) * 0.5
	var id := _FURNITURE.item_id(String(piece.get_meta("token", "")))
	if _FURNITURE.is_painting(id):
		return Vector3(mid.x, mid.y, lo.z)
	return Vector3(mid.x, lo.y, mid.z)


func _world_pts(xf: Transform3D, corners: PackedVector3Array) -> PackedVector3Array:
	var world: Array[Vector3] = [
		xf * corners[0], xf * corners[1],
		xf * corners[1], xf * corners[2],
		xf * corners[2], xf * corners[3],
		xf * corners[3], xf * corners[0],
		xf * corners[0], xf * corners[2],
		xf * corners[1], xf * corners[3],
	]
	return PackedVector3Array(world)


func _path_pts(start_xf: Transform3D, xf: Transform3D, corners: PackedVector3Array) -> PackedVector3Array:
	var world: Array[Vector3] = []
	for i in 4:
		world.append(xf * corners[i])
		world.append(start_xf * corners[i])
	return PackedVector3Array(world)


func _pose(piece: Node3D, global_pos: Vector3) -> Transform3D:
	var parent := piece.get_parent() as Node3D
	var local_pos := global_pos
	if parent != null:
		local_pos = parent.global_transform.affine_inverse() * global_pos
	var local := Transform3D(Basis(Vector3.UP, piece.rotation.y).scaled(piece.scale), local_pos)
	if parent == null:
		return local
	return parent.global_transform * local


func _local_box(piece: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var inv := piece.global_transform.affine_inverse()
	for mesh in piece.find_children("*", "MeshInstance3D", true, false):
		var inst := mesh as MeshInstance3D
		var mesh_box := inst.get_aabb()
		var to_piece := inv * inst.global_transform
		for i in 8:
			var corner: Vector3 = to_piece * mesh_box.get_endpoint(i)
			if first:
				box = AABB(corner, Vector3.ZERO)
				first = false
			else:
				box = box.expand(corner)
	if first:
		box = AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.0, 1.0))
	return box


func _door_center() -> Vector3:
	var scene := _host.get_parent() as Node3D
	var local := Vector3(_DOOR.x, 0.0, _DOOR.y)
	if scene == null:
		return local
	return scene.to_global(local)


func _reach(node: Node3D) -> float:
	var wide := 0.8
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var box := (mesh as MeshInstance3D).get_aabb().size
		var scale := (mesh as MeshInstance3D).global_basis.get_scale()
		wide = maxf(wide, maxf(absf(box.x * scale.x), absf(box.z * scale.z)))
	return wide * 0.45


func _table_at(point: Vector3) -> Node3D:
	var best: Node3D = null
	var best_top := -1.0e9
	for child in _root.get_children():
		var piece := child as Node3D
		if piece == null or piece == _selected:
			continue
		if not _FURNITURE.is_table(_FURNITURE.item_id(String(piece.get_meta("token", "")))):
			continue
		var box := _world_box(piece)
		if point.x < box.position.x or point.x > box.end.x:
			continue
		if point.z < box.position.z or point.z > box.end.z:
			continue
		var top := box.position.y + box.size.y
		if top > best_top:
			best = piece
			best_top = top
	return best


func _top(table: Node3D) -> float:
	return _world_box(table).end.y


func _world_box(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(mesh as MeshInstance3D)
	for inst in meshes:
		var world := inst.global_transform * inst.get_aabb()
		if first:
			box = world
			first = false
		else:
			box = box.merge(world)
	if first:
		box = AABB(node.global_position, Vector3.ONE)
	return box


func _piece_at(hit: Dictionary) -> Node3D:
	if hit.is_empty() or _root == null:
		return null
	var point: Vector3 = hit.position
	var best: Node3D = null
	var best_gap := 4.0
	for child in _root.get_children():
		var piece := child as Node3D
		if piece == null:
			continue
		var gap := Vector2(piece.global_position.x - point.x, piece.global_position.z - point.z).length()
		if gap < best_gap and gap <= _reach(piece) + 0.4:
			best = piece
			best_gap = gap
	return best


## pickGeom. The piece under the pointer, not the first wall the ray meets.
func _pick_piece(screen: Vector2) -> Node3D:
	if _root == null:
		return null
	var camera := _view()
	if camera == null:
		return null
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var best: Node3D = null
	var best_t := 200.0
	for child in _root.get_children():
		var piece := child as Node3D
		if piece == null:
			continue
		var along: Variant = _ray_aabb(origin, dir, _world_box(piece).grow(0.3))
		if along == null:
			continue
		var t := float(along)
		if t < best_t:
			best_t = t
			best = piece
	if best != null:
		return best
	var dropped: Variant = _floor_point(origin, dir)
	if dropped == null:
		return null
	return _piece_at({"position": dropped})


func _ray_aabb(origin: Vector3, dir: Vector3, box: AABB) -> Variant:
	var tmin := 0.0
	var tmax := 200.0
	var bmin := box.position
	var bmax := box.end
	var origin_axis: Array[float] = [origin.x, origin.y, origin.z]
	var dir_axis: Array[float] = [dir.x, dir.y, dir.z]
	var min_axis: Array[float] = [bmin.x, bmin.y, bmin.z]
	var max_axis: Array[float] = [bmax.x, bmax.y, bmax.z]
	for axis in 3:
		var o := origin_axis[axis]
		var d := dir_axis[axis]
		var mn := min_axis[axis]
		var mx := max_axis[axis]
		if absf(d) < 0.0000001:
			if o < mn or o > mx:
				return null
			continue
		var t1 := (mn - o) / d
		var t2 := (mx - o) / d
		if t1 > t2:
			var swap := t1
			t1 = t2
			t2 = swap
		tmin = maxf(tmin, t1)
		tmax = minf(tmax, t2)
		if tmin > tmax:
			return null
	if tmax < 0.0:
		return null
	return tmin


## FurnitureDragBitmask lands on the floor. The wall trimesh is closer to an
## overhead ray than the floor is, so the drag uses the floor plane itself.
func _floor_point(origin: Vector3, dir: Vector3) -> Variant:
	if absf(dir.y) < 0.00001:
		return null
	var floor_y := _bounds.position.y + 0.02
	var t := (floor_y - origin.y) / dir.y
	if t < 0.0 or t > 250.0:
		return null
	return origin + dir * t


func _wall_ray(origin: Vector3, dir: Vector3) -> Dictionary:
	if _root == null:
		return {}
	var space := _root.get_world_3d().direct_space_state
	if space == null:
		return {}
	var skip: Array[RID] = []
	var end := origin + dir * 200.0
	for _step in 8:
		var query := PhysicsRayQueryParameters3D.create(origin, end)
		query.collision_mask = 1
		query.collide_with_areas = false
		query.exclude = skip
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return {}
		var normal: Vector3 = hit.normal
		if absf(normal.y) <= 0.45:
			return hit
		skip.append(hit.rid as RID)
	return {}


func _select(piece: Node3D) -> void:
	if _selected != null and is_instance_valid(_selected):
		_mark(_selected, false)
	_selected = piece
	_held = ""
	if _selected != null:
		_mark(_selected, true)
	_tools.visible = _editing and _selected != null
	if _roof_art != null:
		_roof_art.visible = _selected == null


func _mark(piece: Node3D, on: bool) -> void:
	var overlay: Material = _glow() if on else null
	if piece is MeshInstance3D:
		(piece as MeshInstance3D).material_overlay = overlay
	for mesh in piece.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = overlay


func _glow() -> StandardMaterial3D:
	var flat := StandardMaterial3D.new()
	flat.albedo_color = Color(1.0, 0.85, 0.3, 0.45)
	flat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return flat


func _save(piece: Node3D) -> void:
	var token := String(piece.get_meta("token", ""))
	if token == "":
		return
	_LAYOUT.remember(token, piece.position, rad_to_deg(piece.rotation.y), rad_to_deg(piece.rotation.z))


func _room_tokens() -> PackedStringArray:
	var tokens := PackedStringArray()
	if _root == null:
		return tokens
	for child in _root.get_children():
		if child.has_meta("token"):
			tokens.append(String(child.get_meta("token")))
	for token in _LAYOUT.windows():
		if not token.is_empty() and not tokens.has(token):
			tokens.append(token)
	return tokens


func _piece(token: String) -> Node3D:
	if _root == null:
		return null
	return _root.get_node_or_null(token.replace(":", "_")) as Node3D


func _wall_yaw(normal: Vector3) -> float:
	if normal.x > 0.5:
		return -PI * 0.5
	if normal.x < -0.5:
		return PI * 0.5
	if normal.z > 0.5:
		return PI
	return 0.0


func _over_gui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and (_attic.is_ancestor_of(hovered) or _room.is_ancestor_of(hovered) or _trash.is_ancestor_of(hovered) or _tools.is_ancestor_of(hovered) or _cams.is_ancestor_of(hovered) or _ask.is_ancestor_of(hovered) or hovered == _move)


func _label(token: String) -> String:
	var bits := token.split(":")
	var key := bits[0] + ":" + _FURNITURE.item_id(token) if bits.size() >= 2 else token
	var named := String(_names.get(key, ""))
	if named == "":
		named = bits[0].capitalize() if bits.size() >= 2 else "Furniture"
	if bits.size() >= 2 and bits[0] in _PAPER and _LAYOUT.surface(bits[0]) == token:
		named += " (in use)"
	return named


func _load_names() -> void:
	if not FileAccess.file_exists(_ISSUE):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_ISSUE))
	if not (parsed is Dictionary):
		return
	for week in (parsed as Dictionary).get("weeks", []):
		if not (week is Array):
			continue
		for item in week:
			if item is Dictionary:
				var kind := String(item.get("kind", ""))
				if kind == "furniture" or kind == "window" or kind in _PAPER:
					_names["%s:%d" % [kind, int(item.get("id", -1))]] = String(item.get("name", ""))


func _measure(scene: Node3D) -> AABB:
	var box := AABB()
	var started := false
	var geom := scene.get_node_or_null("Geometry")
	if geom == null:
		return AABB(Vector3(-8, 0, -8), Vector3(16, 4, 16))
	for mesh in geom.find_children("*", "MeshInstance3D", true, false):
		var shape := mesh as MeshInstance3D
		var local := shape.get_aabb()
		var world := shape.global_transform * local
		if not started:
			box = world
			started = true
		else:
			box = box.merge(world)
	if not started:
		return AABB(Vector3(-8, 0, -8), Vector3(16, 4, 16))
	return box


func _view() -> Camera3D:
	if _host == null:
		return null
	var scene := _host.get_parent()
	if scene == null:
		return null
	return scene.get_node_or_null("ToonCamera") as Camera3D


func _dock() -> void:
	if _move == null:
		return
	var view := get_viewport().get_visible_rect().size
	if view.y < 2.0:
		return
	# The frame is at x=-1.19, which is 0.143 in from the left of a 4:3 window.
	# A wider window keeps that same margin from its own left edge.
	var shift := -view.x / view.y + 4.0 / 3.0
	if _attic_art != null:
		ToonGui.place(_attic_art, view, -1.17743 + shift, 0.7213, 0.26514, 0.25502)
	if _roof_art != null:
		ToonGui.place(_roof_art, view, -1.17572 + shift, 0.79036, 0.26173, 0.16465)
	ToonGui.place(_move, view, -1.202 + shift, 0.706, 0.14295, 0.13666)
	if _move_label != null:
		var unit := view.y * 0.5
		ToonGui.style_label(_move_label, Color.WHITE, maxi(int(round(0.04 * unit)), 8), Color.BLACK, maxi(int(round(0.008 * unit)), 1))
		ToonGui.place(_move_label, view, -1.202 + shift, 0.706, 0.4, 0.1)
	if _attic == null:
		return
	_attic.position = Vector2(18, 18)
	_attic.size = _attic.get_combined_minimum_size()
	_room.position = Vector2(view.x - 228, 18)
	_room.size = _room.get_combined_minimum_size()
	_trash.position = Vector2(view.x - 228, 310)
	_trash.size = _trash.get_combined_minimum_size()
	_tools.position = Vector2(18, view.y - 132)
	_tools.size = _bar_size(_tools)
	_cams.position = Vector2(maxf(150.0, view.x * 0.5 - 230.0), view.y - 56)
	_cams.size = _bar_size(_cams)
	_ask.position = Vector2(maxf(18.0, view.x * 0.5 - 180.0), maxf(18.0, view.y * 0.5 - 70.0))
	_ask.size = _ask.get_combined_minimum_size()


func _bar_size(bar: HBoxContainer) -> Vector2:
	return bar.get_combined_minimum_size().max(bar.custom_minimum_size)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_dock()


func _hud() -> Node:
	if _host != null and _host.has_method("_hud"):
		return _host.call("_hud")
	return self


func _tool(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(108, 36)
	_style_button(button)
	button.pressed.connect(pressed)
	return button


func _style_button(button: Button) -> void:
	var flat := StyleBoxFlat.new()
	flat.bg_color = _CREAM
	flat.border_color = Color(0.45, 0.28, 0.12)
	flat.set_border_width_all(2)
	flat.set_corner_radius_all(8)
	flat.content_margin_left = 8
	flat.content_margin_right = 8
	button.add_theme_stylebox_override("normal", flat)
	button.add_theme_stylebox_override("hover", flat)
	button.add_theme_stylebox_override("pressed", flat)
	button.add_theme_color_override("font_color", _INK)
	button.add_theme_font_override("font", ToonGui.font())
