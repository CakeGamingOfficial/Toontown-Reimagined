class_name Nametags
extends Node

## The white see-through name card from phase_3/models/props/panel.
## One board can follow every toon and cog in an area.

const _TAG_BODY := ["legs", "hands", "torso", "arms", "node", "drop_shadow", "CorpIcon"]

var camera: Camera3D
var layer: CanvasLayer
## Return true to hide this card for one frame. The toontorial uses it for
## Tom's shop and for a wall between the camera and an NPC.
var occlude: Callable = Callable()

signal cog_clicked(actor: Node3D, tag: Control)

var _tags: Array[Dictionary] = []


func add(actor: Node3D, text: String, kind: String = "player", text_tint: Color = Color(0, 0, 0, 0)) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1.0, 1.0, 1.0, 0.55)
	var text_color := Color(0.25, 0.28, 0.75)
	var face := ToonGui.font()
	if kind == "npc":
		text_color = text_tint if text_tint.a > 0.0 else Color(0.93, 0.45, 0.14)
	elif kind == "cog":
		text_color = Color.BLACK
		face = ToonGui.suit_font()
	box.set_corner_radius_all(4)
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ToonGui.style_label(label, text_color, 16, Color(0, 0, 0, 0), 0)
	if face:
		label.add_theme_font_override("font", face)
	panel.add_child(label)
	panel.visible = false
	if kind == "cog":
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.z_index = 35
		panel.set_meta("cog_name", text.get_slice("\n", 0))
		panel.gui_input.connect(_on_cog_tag.bind(panel, actor))
	if layer != null:
		layer.add_child(panel)
	# Measured once, from the resting head. A live head would bob the card.
	# The scale is remembered so a teleport hole shrinks the card with the toon.
	var born := actor.global_transform.basis.get_scale().y
	_tags.append({"label": panel, "actor": actor, "lift": _lift(actor), "scale": born})
	return panel


func place() -> void:
	if camera == null:
		return
	var kept: Array[Dictionary] = []
	for item in _tags:
		var label := item["label"] as Control
		var raw: Variant = item.get("actor")
		if not is_instance_valid(raw):
			if is_instance_valid(label):
				label.queue_free()
			continue
		var actor := raw as Node3D
		if actor == null or not actor.visible or not actor.is_visible_in_tree():
			if is_instance_valid(label):
				label.visible = false
			kept.append(item)
			continue
		kept.append(item)
		var lift := float(item.get("lift", 3.6))
		var born := float(item.get("scale", 1.0))
		var now := actor.global_transform.basis.get_scale().y
		if born > 0.05 and now > 0.001:
			lift *= now / born
		var point := actor.global_position + Vector3(0.0, lift, 0.0)
		if occlude.is_valid() and bool(occlude.call(actor, point)):
			label.visible = false
			continue
		if camera.is_position_behind(point):
			label.visible = false
			continue
		_fit(label, point)
		_place(label, point)
	_tags = kept


func _on_cog_tag(event: InputEvent, tag: Control, actor: Node3D) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	var host := get_parent()
	if host != null and host.has_method("in_cutscene") and bool(host.call("in_cutscene")):
		return
	tag.accept_event()
	cog_clicked.emit(actor, tag)


func _lift(actor: Node3D) -> float:
	var head := _find(actor, "def_head")
	if head:
		var scale := actor.global_transform.basis.get_scale().y
		if scale < 0.05:
			scale = 1.0
		return head.global_position.y - actor.global_position.y + 0.96 * scale
	var top := -1.0
	for node in actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null or _TAG_BODY.has(String(mesh.name)):
			continue
		var box := mesh.global_transform * mesh.get_aabb()
		top = maxf(top, box.position.y + box.size.y)
	if top >= 0.0:
		return top - actor.global_position.y + 0.04
	return 3.6


func _fit(panel: Control, point: Vector3) -> void:
	var here := camera.unproject_position(point)
	var above := camera.unproject_position(point + Vector3(0.0, 0.2, 0.0))
	var px := clampi(int(absf(here.y - above.y)), 12, 36)
	var label := panel.get_child(0) as Label
	if label:
		label.add_theme_font_size_override("font_size", px)
		label.add_theme_constant_override("line_spacing", -maxi(int(px * 0.12), 1))
	var box := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if box == null:
		return
	box.set_corner_radius_all(maxi(int(px * 0.22), 3))
	var side := maxi(int(px * 0.24), 3)
	var vert := maxi(int(px * 0.048), 1)
	box.content_margin_left = side
	box.content_margin_right = side
	box.content_margin_top = vert
	box.content_margin_bottom = vert


func _place(control: Control, world: Vector3) -> void:
	var view := camera.get_viewport().get_visible_rect().size
	if view.x < 2.0 or view.y < 2.0:
		control.visible = false
		return
	control.reset_size()
	var screen := camera.unproject_position(world)
	control.position = screen - control.size * Vector2(0.5, 1.0)
	control.visible = true


func _find(root: Node, node_name: String) -> Node3D:
	if root.name == node_name and root is Node3D:
		return root as Node3D
	var found := root.find_child(node_name, true, false)
	return found as Node3D
