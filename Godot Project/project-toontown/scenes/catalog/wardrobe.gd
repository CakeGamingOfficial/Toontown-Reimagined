extends Control

## ClosetGUI. Shirts and bottoms from every catalog issue, for this toon's gender.
## The arrows stop at the ends, the way the closet scroll buttons do.

signal closed

const _CLOSET := preload("res://scenes/catalog/catalog_closet.gd")
const _ISSUE := "res://assets/catalog/issue.json"
const _ARROW := preload("res://assets/toons/gui/tt_t_gui_mat_shuffleArrowUp.png")
const _ARROW_DOWN := preload("res://assets/toons/gui/tt_t_gui_mat_shuffleArrowDown.png")
const _ARROW_OFF := preload("res://assets/toons/gui/tt_t_gui_mat_shuffleArrowDisabled.png")
const _FRAME := preload("res://assets/toons/gui/tt_t_gui_mat_shuffleFrame.png")
const _SHUFFLE_UP := preload("res://assets/toons/gui/tt_t_gui_mat_shuffleUp.png")
const _SHUFFLE_DOWN := preload("res://assets/toons/gui/tt_t_gui_mat_shuffleDown.png")
const _DONE_UP := preload("res://assets/toons/gui/CrtAtoon_Btn1_UP.png")
const _DONE_DOWN := preload("res://assets/toons/gui/CrtAtoon_Btn1_DN.png")
const _DONE_HOVER := preload("res://assets/toons/gui/CrtAtoon_Btn1_Rllvr.png")
const _CANCEL_UP := preload("res://assets/toons/gui/CrtAtoon_Btn2_UP.png")
const _CANCEL_DOWN := preload("res://assets/toons/gui/CrtAtoon_Btn2_DN.png")
const _CANCEL_HOVER := preload("res://assets/toons/gui/CrtAtoon_Btn2_Rllvr.png")
const _TRASH_UP := preload("res://assets/toons/gui/TrashCan_CLSD.png")
const _TRASH_DOWN := preload("res://assets/toons/gui/TrashCan_OPEN.png")
const _TRASH_HOVER := preload("res://assets/toons/gui/TrashCan_RLVR.png")
const _DIALOG := preload("res://assets/gui/tutorial/dialog/dialog_box.png")
const _ROTATE_UP := preload("res://assets/toons/gui/tt_t_gui_mat_arrowRotateUp.png")
const _ROTATE_DOWN := preload("res://assets/toons/gui/tt_t_gui_mat_arrowRotateDown.png")
## MakeAToon.hprDelta is one degree a frame. The Make a Toon screen turns at 1.6 rad/s.
const _SPIN := 1.6

var _style: ToonStyle
var _actor: ToonActor
var _tops: Array[Dictionary] = []
var _bottoms: Array[Dictionary] = []
var _top := 0
var _bottom := 0
var _kept := false
var _shirt_name: Label
var _bottom_name: Label
var _top_left: BaseButton
var _top_right: BaseButton
var _bottom_left: BaseButton
var _bottom_right: BaseButton
var _shirt_trash: BaseButton
var _bottom_trash: BaseButton
var _bottom_trash_label: Label
var _spin_left: BaseButton
var _spin_right: BaseButton
var _snap := {}
var _spin := 0.0
var _heading := 0.0
var _hold_cam := false
var _frozen_cam: Camera3D
var _frozen_xform := Transform3D.IDENTITY
var _frozen_top := false


func open(actor: ToonActor, style: ToonStyle) -> bool:
	_actor = actor
	_style = style
	_snap = _snapshot(style)
	var clothes := _all_clothes(style.gender if style != null else "")
	_tops = clothes["tops"]
	_bottoms = clothes["bottoms"]
	_top = _place_current(_tops, _snap, "shirt")
	_bottom = _place_current(_bottoms, _snap, "bottom")
	if _bottom_name != null and style != null:
		_bottom_name.text = "Shorts" if style.gender == "m" else "Bottoms"
	_show_choice()
	_remember_camera()
	_hold_cam = true
	_seat_spinners()
	await closed
	return _kept


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Nametags sit at 36. The plates and turn arrows have to paint over them.
	# A late process puts the camera back after the follow camera runs.
	z_index = 38
	process_priority = 100
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# ClothesGUI shirt frame is parent (0.98, 0.416) plus local z -0.4, rolled 3 degrees.
	# The shorts frame is the same parent plus local z -0.65, rolled -2 degrees.
	# The words stay "Shirts" and "Shorts" or "Bottoms". They are not the item name.
	_shirt_name = _row(0.98, 0.016, 3.0, "Shirts", true)
	_bottom_name = _row(0.98, -0.234, -2.0, "Shorts", false)
	_shuffle_button()
	_trash_panel()
	_closet_button(_DONE_UP, _DONE_DOWN, _DONE_HOVER, Vector2(-0.15, -0.85), "Done", _done)
	_closet_button(_CANCEL_UP, _CANCEL_DOWN, _CANCEL_HOVER, Vector2(0.15, -0.85), "Cancel", _cancel)
	_spin_left = _rotate_button(true)
	_spin_right = _rotate_button(false)
	if not get_viewport().size_changed.is_connected(_layout):
		get_viewport().size_changed.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	if _spin != 0.0 and _actor != null and is_instance_valid(_actor):
		_heading += rad_to_deg(_spin * delta)
		_apply_heading(_heading)
	# Deferred so this runs after the follow camera's _process. Otherwise that
	# camera turns to stay behind the toon and the front never comes around.
	if _hold_cam:
		_pin_camera.call_deferred()


func _remember_camera() -> void:
	var camera := _find_camera()
	if camera == null:
		return
	_frozen_cam = camera
	_frozen_xform = camera.global_transform
	_frozen_top = camera.top_level


func _find_camera() -> Camera3D:
	if _actor == null or not is_instance_valid(_actor):
		return null
	var body := _actor.get_parent()
	var scene := body.get_parent() if body != null else null
	if scene == null:
		return null
	return scene.get_node_or_null("ToonCamera") as Camera3D


func _pin_camera() -> void:
	if not _hold_cam or _frozen_cam == null or not is_instance_valid(_frozen_cam):
		return
	# top_level keeps a parent rotation from dragging the camera after this write.
	_frozen_cam.top_level = true
	_frozen_cam.global_transform = _frozen_xform


func _release_camera() -> void:
	_hold_cam = false
	if _frozen_cam == null or not is_instance_valid(_frozen_cam):
		return
	_frozen_cam.top_level = _frozen_top
	_frozen_cam = null


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.y < 2.0:
		return
	position = Vector2.ZERO
	size = view
	for child in get_children():
		if not child.has_meta("at"):
			continue
		var at: Vector2 = child.get_meta("at")
		var box: Vector2 = child.get_meta("box")
		ToonGui.place(child, view, at.x, at.y, box.x, box.y)
		child.pivot_offset = child.size * 0.5
		if child.has_meta("rot"):
			child.rotation_degrees = float(child.get_meta("rot"))
		if child is Label:
			var ink: Color = child.get_meta("ink", Color.WHITE)
			var shadow: Color = child.get_meta("shadow", Color(0, 0, 0, 1))
			var px_scale: float = child.get_meta("px", 0.069)
			var px := maxi(int(px_scale * view.y * 0.5), 8)
			ToonGui.style_label(child, ink, px, shadow, maxi(int(px / 10.0), 1))
	_seat_spinners()


func _row(x: float, z: float, rot: float, caption: String, shirt: bool) -> Label:
	# shuffleFrame is 0.875 by 0.3667, drawn at halfButtonScale 0.6, then frame scale 1.2.
	var frame_scale := 1.2
	var frame := TextureRect.new()
	frame.texture = _FRAME
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_meta("at", Vector2(x, z))
	frame.set_meta("box", Vector2(0.875 * 0.6 * frame_scale, 0.3667 * 0.6 * frame_scale))
	frame.set_meta("rot", rot)
	add_child(frame)
	var arrow_x := 0.2 * frame_scale
	var left := _arrow(x - arrow_x, z, false, _step.bind(shirt, -1))
	var right := _arrow(x + arrow_x, z, true, _step.bind(shirt, 1))
	left.set_meta("box", Vector2(0.1 * 0.6 * frame_scale, 0.1833 * 0.6 * frame_scale))
	right.set_meta("box", Vector2(0.1 * 0.6 * frame_scale, 0.1833 * 0.6 * frame_scale))
	left.set_meta("rot", rot)
	right.set_meta("rot", rot)
	if shirt:
		_top_left = left
		_top_right = right
	else:
		_bottom_left = left
		_bottom_right = right
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("at", Vector2(x, z - 0.018))
	label.set_meta("box", Vector2(0.34, 0.1))
	label.set_meta("rot", rot)
	label.set_meta("px", 0.069)
	add_child(label)
	return label


func _rotate_button(left: bool) -> BaseButton:
	var button := TextureButton.new()
	button.texture_normal = _ROTATE_UP
	button.texture_pressed = _ROTATE_DOWN
	button.texture_hover = _ROTATE_UP
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.flip_h = left
	button.focus_mode = Control.FOCUS_NONE
	var direction := _SPIN if left else -_SPIN
	button.button_down.connect(func() -> void:
		_heading = _read_heading()
		_spin = direction
		ToonGui.play_sfx(button, ToonGui.CLICK_SFX)
	)
	button.button_up.connect(func() -> void:
		if is_equal_approx(_spin, direction):
			_spin = 0.0
	)
	button.mouse_entered.connect(func() -> void:
		button.scale = Vector2(1.25, 1.25)
		ToonGui.play_sfx(button, ToonGui.ROLLOVER_SFX)
	)
	button.mouse_exited.connect(func() -> void: button.scale = Vector2.ONE)
	add_child(button)
	return button


func _seat_spinners() -> void:
	if _spin_left == null or _spin_right == null:
		return
	var view := get_viewport().get_visible_rect().size
	if view.y < 2.0:
		return
	var box := view.y * 0.09
	var left_at := Vector2(view.x * 0.22, view.y * 0.5)
	var right_at := Vector2(view.x * 0.78, view.y * 0.5)
	var camera := get_viewport().get_camera_3d()
	if camera != null and _actor != null and is_instance_valid(_actor):
		var height := _actor.clamped_height()
		var feet_world := _actor.global_position
		var head_world := feet_world + Vector3.UP * height
		if not camera.is_position_behind(feet_world) and not camera.is_position_behind(head_world):
			var feet := camera.unproject_position(feet_world)
			var head := camera.unproject_position(head_world)
			var mid := (feet + head) * 0.5
			var reach := maxf(absf(head.y - feet.y) * 0.62, box)
			left_at = mid + Vector2(-reach, 0.0)
			right_at = mid + Vector2(reach, 0.0)
	var margin := box * 0.6
	left_at.x = clampf(left_at.x, margin, view.x * 0.5 - margin)
	right_at.x = clampf(right_at.x, view.x * 0.5 + margin, view.x - margin)
	left_at.y = clampf(left_at.y, margin, view.y - margin)
	right_at.y = clampf(right_at.y, margin, view.y - margin)
	_pin(_spin_left, left_at, box)
	_pin(_spin_right, right_at, box)


func _pin(button: Control, center: Vector2, box: float) -> void:
	button.size = Vector2(box, box)
	button.pivot_offset = button.size * 0.5
	button.global_position = center - button.size * 0.5


func _arrow(x: float, z: float, flip: bool, action: Callable) -> BaseButton:
	var button := TextureButton.new()
	button.texture_normal = _ARROW
	button.texture_pressed = _ARROW_DOWN
	button.texture_hover = _ARROW
	button.texture_disabled = _ARROW_OFF
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.flip_h = flip
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	ToonGui.button_sounds(button)
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			button.scale = Vector2(0.7 / 0.6, 0.7 / 0.6)
	)
	button.mouse_exited.connect(func() -> void: button.scale = Vector2.ONE)
	button.set_meta("at", Vector2(x, z))
	button.set_meta("box", Vector2(0.08, 0.14))
	add_child(button)
	return button


func _closet_button(up: Texture2D, down: Texture2D, hover: Texture2D, at: Vector2, caption: String, action: Callable) -> void:
	var button := TextureButton.new()
	button.texture_normal = up
	button.texture_pressed = down
	button.texture_hover = hover
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	ToonGui.button_sounds(button)
	# CrtAtoon_Btn1 and Btn2 are 0.2667 by 0.2458. The word shows on rollover.
	button.set_meta("at", at)
	button.set_meta("box", Vector2(0.2667, 0.2458))
	add_child(button)
	var label := Label.new()
	label.text = caption
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate = Color(1, 1, 1, 0)
	button.add_child(label)
	button.mouse_entered.connect(func() -> void: label.modulate = Color(1, 1, 1, 1))
	button.mouse_exited.connect(func() -> void: label.modulate = Color(1, 1, 1, 0))
	button.resized.connect(func() -> void:
		ToonGui.style_label(label, Color.WHITE, maxi(int(0.08 * get_viewport().get_visible_rect().size.y * 0.5), 10), Color(0, 0, 0), 2)
	)


func _shuffle_button() -> void:
	# ShuffleButton sits on the clothes frame at local z -1, so aspect z is -0.584.
	var button := TextureButton.new()
	button.texture_normal = _SHUFFLE_UP
	button.texture_pressed = _SHUFFLE_DOWN
	button.texture_hover = _SHUFFLE_UP
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_shuffle)
	ToonGui.button_sounds(button)
	button.mouse_entered.connect(func() -> void: button.scale = Vector2(1.05, 1.05))
	button.mouse_exited.connect(func() -> void: button.scale = Vector2.ONE)
	button.set_meta("at", Vector2(0.98, -0.584))
	button.set_meta("box", Vector2(0.30, 0.1275))
	add_child(button)
	var label := Label.new()
	label.text = "Shuffle"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	button.resized.connect(func() -> void:
		ToonGui.style_label(label, Color.WHITE, maxi(int(0.08 * get_viewport().get_visible_rect().size.y * 0.5), 10), Color(0, 0, 0), 2)
	)


func _trash_panel() -> void:
	# dialog_box_gui tight card, then ClosetGUI image_scale (0.36, 0.75) and tint.
	var panel := TextureRect.new()
	panel.texture = _DIALOG
	panel.modulate = Color(1, 1, 0.75, 0.8)
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_meta("at", Vector2(-0.86, -0.05))
	panel.set_meta("box", Vector2(1.1122 * 0.36, 1.1861 * 0.75))
	add_child(panel)
	_shirt_trash = _trash_can(-0.95, 0.15, "Delete\nshirt", true)
	_bottom_trash = _trash_can(-0.95, -0.25, "Delete\nshorts", false)


func _trash_can(x: float, z: float, caption: String, shirt: bool) -> BaseButton:
	var button := TextureButton.new()
	button.texture_normal = _TRASH_UP
	button.texture_pressed = _TRASH_DOWN
	button.texture_hover = _TRASH_HOVER
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_remove.bind(shirt))
	ToonGui.button_sounds(button)
	button.set_meta("at", Vector2(x, z))
	button.set_meta("box", Vector2(0.1688, 0.2146))
	add_child(button)
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("at", Vector2(x + 0.15, z))
	label.set_meta("box", Vector2(0.28, 0.16))
	label.set_meta("ink", Color(0.8, 0.2, 0.2))
	label.set_meta("px", 0.06)
	add_child(label)
	button.set_meta("caption", label)
	if not shirt:
		_bottom_trash_label = label
	return button


func _shuffle() -> void:
	if _tops.size() > 0:
		_top = randi() % _tops.size()
	if _bottoms.size() > 0:
		_bottom = randi() % _bottoms.size()
	_show_choice()


func _remove(shirt: bool) -> void:
	var rows: Array[Dictionary] = _tops if shirt else _bottoms
	if rows.size() < 2:
		return
	var index := _top if shirt else _bottom
	if index < 0 or index >= rows.size():
		return
	rows.remove_at(index)
	if shirt:
		_tops = rows
		if _top >= _tops.size():
			_top = 0
	else:
		_bottoms = rows
		if _bottom >= _bottoms.size():
			_bottom = 0
	_show_choice()


func _step(shirt: bool, direction: int) -> void:
	if shirt:
		_top = clampi(_top + direction, 0, _tops.size() - 1)
	else:
		_bottom = clampi(_bottom + direction, 0, _bottoms.size() - 1)
	_show_choice()


func _show_choice() -> void:
	if _style == null:
		return
	if _top >= 0 and _top < _tops.size():
		_wear(_tops[_top])
	if _bottom >= 0 and _bottom < _bottoms.size():
		_wear(_bottoms[_bottom])
		if _bottom_trash_label != null:
			var bottom: Dictionary = _bottoms[_bottom]
			_bottom_trash_label.text = "Delete\nskirt" if bool(bottom.get("skirt", false)) else "Delete\nshorts"
	_set_enabled(_top_left, _top > 0)
	_set_enabled(_top_right, _top < _tops.size() - 1)
	_set_enabled(_bottom_left, _bottom > 0)
	_set_enabled(_bottom_right, _bottom < _bottoms.size() - 1)
	_set_enabled(_shirt_trash, _tops.size() >= 2)
	_set_enabled(_bottom_trash, _bottoms.size() >= 2)


func _set_enabled(button: BaseButton, enabled: bool) -> void:
	if button == null:
		return
	button.disabled = not enabled
	var tint := Color.WHITE if enabled else Color(0.55, 0.55, 0.55, 0.45)
	button.modulate = tint
	if button.has_meta("caption") and button.get_meta("caption") is CanvasItem:
		(button.get_meta("caption") as CanvasItem).modulate = tint


func _wear(item: Dictionary) -> void:
	var skirt_before := _style.wears_skirt()
	if String(item.get("piece", "")) == "shirt":
		_style.top_tex = int(item.get("tex", _style.top_tex))
		_style.top_color = int(item.get("color", _style.top_color))
		_style.top_map = String(item.get("map", ""))
		_style.sleeve_map = String(item.get("sleeve", ""))
	else:
		_style.bot_tex = int(item.get("tex", _style.bot_tex))
		_style.bot_color = int(item.get("color", _style.bot_color))
		_style.bottom_map = String(item.get("map", ""))
		if _style.torso.length() > 1:
			_style.torso = _style.torso.substr(0, 1) + ("d" if bool(item.get("skirt", false)) else "s")
	if _actor == null or not is_instance_valid(_actor):
		return
	var heading := _read_heading()
	if _style.wears_skirt() != skirt_before:
		_actor.show_style(_style)
		_actor.wear_accessories(_CLOSET.accessory_ids())
		_apply_heading(heading)
	else:
		_actor.recolor(_style)


func _done() -> void:
	var shirt: Dictionary = _tops[_top] if _top >= 0 and _top < _tops.size() else {}
	var bottom: Dictionary = _bottoms[_bottom] if _bottom >= 0 and _bottom < _bottoms.size() else {}
	_CLOSET.wear_outfit(_style, shirt, bottom)
	_kept = true
	_close()


func _cancel() -> void:
	_restore()
	_kept = false
	_close()


func _close() -> void:
	_spin = 0.0
	_release_camera()
	closed.emit()
	queue_free()


func _restore() -> void:
	if _style == null:
		return
	var skirt_before := _style.wears_skirt()
	_style.top_tex = int(_snap.get("top_tex", _style.top_tex))
	_style.top_color = int(_snap.get("top_color", _style.top_color))
	_style.top_map = String(_snap.get("top_map", ""))
	_style.sleeve_map = String(_snap.get("sleeve_map", ""))
	_style.bot_tex = int(_snap.get("bot_tex", _style.bot_tex))
	_style.bot_color = int(_snap.get("bot_color", _style.bot_color))
	_style.bottom_map = String(_snap.get("bottom_map", ""))
	_style.torso = String(_snap.get("torso", _style.torso))
	if _actor == null or not is_instance_valid(_actor):
		return
	var heading := _read_heading()
	if _style.wears_skirt() != skirt_before:
		_actor.show_style(_style)
		_actor.wear_accessories(_CLOSET.accessory_ids())
		_apply_heading(heading)
	else:
		_actor.recolor(_style)


func _read_heading() -> float:
	if _actor == null or not is_instance_valid(_actor):
		return _heading
	var forward := _actor.transform.basis.orthonormalized().y
	return rad_to_deg(atan2(forward.x, -forward.z))


func _apply_heading(heading: float) -> void:
	_heading = heading
	var host := _turn_host()
	if host != null:
		host.turn_toon(heading)


func _turn_host() -> Node:
	if _actor == null or not is_instance_valid(_actor):
		return null
	var body := _actor.get_parent()
	var scene := body.get_parent() if body != null else null
	if scene == null:
		return null
	for child in scene.get_children():
		if child.has_method("turn_toon"):
			return child
	return null


func _snapshot(style: ToonStyle) -> Dictionary:
	if style == null:
		return {}
	return {
		"top_tex": style.top_tex,
		"top_color": style.top_color,
		"top_map": style.top_map,
		"sleeve_map": style.sleeve_map,
		"bot_tex": style.bot_tex,
		"bot_color": style.bot_color,
		"bottom_map": style.bottom_map,
		"torso": style.torso,
		"piece_shirt": "shirt",
		"piece_bottom": "bottom",
	}


func _place_current(rows: Array[Dictionary], snap: Dictionary, piece: String) -> int:
	var found := _index_of(rows, snap, piece)
	if found >= 0:
		return found
	var shirt := piece == "shirt"
	rows.insert(0, {
		"id": -1,
		"name": "Current",
		"piece": piece,
		"tex": int(snap.get("top_tex" if shirt else "bot_tex", 0)),
		"color": int(snap.get("top_color" if shirt else "bot_color", 0)),
		"map": String(snap.get("top_map" if shirt else "bottom_map", "")),
		"sleeve": String(snap.get("sleeve_map", "")) if shirt else "",
		"skirt": String(snap.get("torso", "")).ends_with("d"),
	})
	return 0


func _index_of(rows: Array[Dictionary], snap: Dictionary, piece: String) -> int:
	var tex := int(snap.get("top_tex" if piece == "shirt" else "bot_tex", -1))
	var color := int(snap.get("top_color" if piece == "shirt" else "bot_color", -1))
	var path := String(snap.get("top_map" if piece == "shirt" else "bottom_map", ""))
	for index in rows.size():
		var item := rows[index]
		if int(item.get("tex", -2)) == tex and int(item.get("color", -2)) == color and String(item.get("map", "")) == path:
			return index
	return -1


static func _all_clothes(gender: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_ISSUE))
	var tops: Array[Dictionary] = []
	var bottoms: Array[Dictionary] = []
	var seen := {}
	var piles: Array = []
	if parsed is Dictionary:
		var data: Dictionary = parsed
		if data.has("clothes"):
			piles.append(data.get("clothes", []))
		else:
			piles.append_array(data.get("weeks", []))
			for month in data.get("months", []):
				if month is Dictionary:
					piles.append((month as Dictionary).get("items", []))
	for pile in piles:
		if pile is not Array:
			continue
		for item in pile:
			if item is not Dictionary:
				continue
			if String(item.get("kind", "")) != "clothing":
				continue
			var item_gender := String(item.get("gender", ""))
			if item_gender != "" and gender != "" and item_gender != gender:
				continue
			var key := str(int(item.get("id", -1))) + ":" + str(int(item.get("color", 0)))
			if seen.has(key):
				continue
			seen[key] = true
			var copy: Dictionary = item.duplicate()
			if String(copy.get("piece", "")) == "shirt":
				tops.append(copy)
			else:
				bottoms.append(copy)
	tops.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("name", "")) < String(b.get("name", "")))
	bottoms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("name", "")) < String(b.get("name", "")))
	return {"tops": tops, "bottoms": bottoms}
