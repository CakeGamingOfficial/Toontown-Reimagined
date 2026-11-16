class_name HouseEditor
extends Node

## houseDesign. Move Furniture opens the attic, the room list, and the trash.
## Drag a piece across the floor. Paintings stick to the wall. Rotate is 22.5
## degrees, the same step rotateLeft and rotateRight use. The camera walks
## camPosList, starting at the 40-unit shot, and turns in 90 degree steps.
## Grid rounds the floor the way ROUND_TO does, and it starts at 1. The door
## blocker is the original sphere on the interior door. Rugs and paintings
## ignore it, because their wall mask does not include FurnitureSideBitmask.

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

var _host: Node
var _editing := false
var _root: Node3D
var _selected: Node3D
var _held := ""
var _dragging := false
var _focus := Vector3.ZERO
var _cam_index := 2
var _cam_heading := 0.0
var _bounds := AABB()
var _names: Dictionary = {}
var _ask_ok := Callable()
var _move: Button
var _attic: PanelContainer
var _room: PanelContainer
var _trash: PanelContainer
var _attic_list: VBoxContainer
var _room_list: VBoxContainer
var _trash_list: VBoxContainer
var _tools: HBoxContainer
var _cams: HBoxContainer
var _grid_button: Button
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
	_move = Button.new()
	_move.text = "Move\nFurniture"
	_move.focus_mode = Control.FOCUS_NONE
	_move.position = Vector2(18, 0)
	_move.custom_minimum_size = Vector2(120, 64)
	_style_button(_move)
	_move.pressed.connect(_toggle)
	hud.add_child(_move)
	_attic = _pile("In the attic")
	_room = _pile("In the room")
	_trash = _pile("In the trash")
	_attic_list = _attic.get_node("Scroll/List") as VBoxContainer
	_room_list = _room.get_node("Scroll/List") as VBoxContainer
	_trash_list = _trash.get_node("Scroll/List") as VBoxContainer
	_tools = HBoxContainer.new()
	_tools.position = Vector2(18, 0)
	_tools.add_theme_constant_override("separation", 8)
	_tools.visible = false
	_tools.add_child(_tool("Rotate Left", _turn_piece.bind(-1.0)))
	_tools.add_child(_tool("Rotate Right", _turn_piece.bind(1.0)))
	_tools.add_child(_tool("Send\nto attic", _send_attic))
	_tools.add_child(_tool("Delete", _send_trash))
	hud.add_child(_tools)
	_cams = HBoxContainer.new()
	_cams.add_theme_constant_override("separation", 8)
	_cams.visible = false
	_cams.add_child(_tool("Zoom\nIn", _zoom.bind(-1)))
	_cams.add_child(_tool("Zoom\nOut", _zoom.bind(1)))
	_cams.add_child(_tool("Camera\nLeft", _orbit.bind(-1.0)))
	_cams.add_child(_tool("Camera\nRight", _orbit.bind(1.0)))
	_grid_button = _tool("Grid\nOn", _toggle_grid)
	_cams.add_child(_grid_button)
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


func _toggle() -> void:
	if _editing:
		_finish()
	else:
		_begin()


func _begin() -> void:
	if _host == null or _root == null:
		return
	_editing = true
	_move.text = "Done\nMoving"
	_attic.visible = true
	_room.visible = true
	_trash.visible = true
	_cams.visible = true
	if _host.has_method("furniture_lock"):
		_host.call("furniture_lock", true)
	_refresh()
	_dock()


func _finish() -> void:
	_dragging = false
	_select(null)
	_editing = false
	_move.text = "Move\nFurniture"
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
		if _blocked(model.global_position):
			var away := Vector3(landed.x - _DOOR.x, 0.0, landed.z - _DOOR.y)
			if away.length() < 0.1:
				away = Vector3(0.0, 0.0, -1.0)
			away = away.normalized()
			for _step in 8:
				landed += away * 2.0
				landed = _snap(landed)
				model.position = _root.to_local(landed)
				if not _blocked(model.global_position):
					break
	_save(model)
	_select(model)
	_refresh()


func _seat_window(token: String) -> void:
	var slots := _LAYOUT.windows()
	while slots.size() < 6:
		slots.append("")
	var index := -1
	for i in slots.size():
		if slots[i].is_empty():
			index = i
			break
	if index < 0:
		index = 0
	slots[index] = token
	_LAYOUT.set_windows(slots)
	_FURNITURE.fill_window(_host.get_parent(), index, token)
	_refresh()


func _pick_token(token: String) -> void:
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
	var line := ""
	if token.begins_with("furniture:"):
		line = _FURNITURE.fixed_line(_FURNITURE.item_id(token))
	if line != "":
		_confirm(line, Callable())
		return
	_confirm("Click OK to send this item to the trash, or Cancel to keep it.", _commit_drop.bind(true))


func _commit_restore(token: String) -> void:
	_LAYOUT.restore(token)
	_refresh()


func _commit_drop(to_trash: bool) -> void:
	var token := _current()
	var piece := _selected
	var hole := _window_index(token)
	_select(null)
	if to_trash:
		_LAYOUT.trash(token)
		_FURNITURE.settle()
	else:
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


func _orbit(sign: float) -> void:
	_cam_heading = fposmod(_cam_heading + 90.0 * sign, 360.0)


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
	if _FURNITURE.is_painting(_FURNITURE.item_id(String(_selected.get_meta("token", "")))):
		return
	_selected.rotation.y += deg_to_rad(_TURN * sign)
	_save(_selected)


func _unhandled_input(event: InputEvent) -> void:
	if not _editing:
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			_press(click.position)
		else:
			_dragging = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		_drag((event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()


func _press(screen: Vector2) -> void:
	if _ask.visible or _over_gui():
		return
	var hit := _ray(screen)
	var piece := _piece_at(hit)
	if piece == null:
		_select(null)
		_refresh()
		return
	_select(piece)
	_dragging = true
	_refresh()


func _drag(screen: Vector2) -> void:
	if _selected == null or _host == null:
		return
	var camera := _view()
	if camera == null:
		return
	var space := _selected.get_world_3d().direct_space_state
	var origin := camera.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen) * 200.0)
	query.collide_with_areas = false
	query.collision_mask = 1
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	var point: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	var token := String(_selected.get_meta("token", ""))
	var next := _selected.global_position
	var turned := _selected.rotation.y
	if _FURNITURE.is_painting(_FURNITURE.item_id(token)):
		if absf(normal.y) > 0.45:
			return
		next = point + normal * 0.08
		next.y = maxf(next.y, _bounds.position.y + 0.8)
		turned = _wall_yaw(normal)
	else:
		if normal.y < 0.65:
			return
		next = _snap(Vector3(point.x, _bounds.position.y + 0.02, point.z))
	if _blocked(next):
		return
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


func _blocked(at: Vector3) -> bool:
	if _in_door(at):
		return true
	var mine := _reach(_selected)
	for child in _root.get_children():
		var other := child as Node3D
		if other == null or other == _selected:
			continue
		var gap := Vector2(other.global_position.x - at.x, other.global_position.z - at.z).length()
		if gap < (mine + _reach(other)) * 0.55:
			return true
	return false


func _in_door(at: Vector3) -> bool:
	if _selected == null:
		return false
	var id := _FURNITURE.item_id(String(_selected.get_meta("token", "")))
	if _FURNITURE.is_painting(id) or _FURNITURE.is_rug(id):
		return false
	var gap := Vector2(at.x - _DOOR.x, at.z - _DOOR.y).length()
	return gap < _DOOR_RADIUS + _reach(_selected)


func _reach(node: Node3D) -> float:
	var wide := 0.8
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var box := (mesh as MeshInstance3D).get_aabb().size
		var scale := (mesh as MeshInstance3D).global_basis.get_scale()
		wide = maxf(wide, maxf(absf(box.x * scale.x), absf(box.z * scale.z)))
	return wide * 0.45


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


func _ray(screen: Vector2) -> Dictionary:
	if _host == null or _root == null:
		return {}
	var camera := _view()
	if camera == null:
		return {}
	var origin := camera.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen) * 200.0)
	query.collision_mask = 1
	return _root.get_world_3d().direct_space_state.intersect_ray(query)


func _select(piece: Node3D) -> void:
	if _selected != null and is_instance_valid(_selected):
		_mark(_selected, false)
	_selected = piece
	_held = ""
	if _selected != null:
		_mark(_selected, true)
	_tools.visible = _editing and _selected != null


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
	_LAYOUT.remember(token, piece.position, rad_to_deg(piece.rotation.y))


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
	_move.position = Vector2(18, view.y - 84)
	_attic.position = Vector2(18, 18)
	_room.position = Vector2(view.x - 228, 18)
	_trash.position = Vector2(view.x - 228, 310)
	_tools.position = Vector2(18, view.y - 132)
	_cams.position = Vector2(maxf(150.0, view.x * 0.5 - 230.0), view.y - 56)
	_ask.position = Vector2(maxf(18.0, view.x * 0.5 - 180.0), maxf(18.0, view.y * 0.5 - 70.0))


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
