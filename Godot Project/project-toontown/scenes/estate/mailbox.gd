extends Node3D

## DistributedMailbox. The house keeps one mailbox at the original house-local
## spot. Clarabelle's orders wait here. The flag lies down when it is empty
## and stands out when a delivery is inside.

signal done

const _GUI := preload("res://scenes/toons/toon_gui.gd")
const _CLOSET := preload("res://scenes/catalog/catalog_closet.gd")
const _PAPER := Color(0.98, 0.93, 0.72, 1.0)
const _INK := Color(0.15, 0.12, 0.2, 1.0)
const _BLUE := Color(0.18, 0.38, 0.82, 1.0)
const _RED := Color(0.86, 0.16, 0.14, 1.0)

var _flag: MeshInstance3D
var _screen: Control


func build() -> void:
	var post := _box(Vector3(0.22, 1.05, 0.22), Vector3(0.0, 0.52, 0.0), Color(0.45, 0.32, 0.18, 1.0))
	add_child(post)
	var body := _box(Vector3(0.85, 0.62, 0.55), Vector3(0.0, 1.15, 0.0), _BLUE)
	add_child(body)
	var door := _box(Vector3(0.7, 0.42, 0.06), Vector3(0.0, 1.12, 0.28), Color(0.12, 0.28, 0.7, 1.0))
	add_child(door)
	_flag = _box(Vector3(0.08, 0.42, 0.28), Vector3(0.0, 0.2, 0.0), _RED)
	var hinge := Node3D.new()
	hinge.name = "FlagHinge"
	hinge.position = Vector3(0.48, 1.35, 0.0)
	add_child(hinge)
	hinge.add_child(_flag)


func _process(_delta: float) -> void:
	if _flag == null:
		return
	var raised := _CLOSET.mail_count() > 0
	_flag.rotation_degrees.x = 0.0 if raised else -70.0


func open_screen(parent: Node) -> void:
	if _screen != null and is_instance_valid(_screen):
		return
	var panel := Control.new()
	panel.name = "MailboxScreen"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(panel)
	_screen = panel
	var card := ColorRect.new()
	card.color = _PAPER
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(card)
	var view := panel.get_viewport().get_visible_rect().size
	_GUI.place(card, view, -0.35, 0.15, 0.7, 0.7)
	var title := Label.new()
	title.text = "Mailbox"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_GUI.style_label(title, _INK, 28, Color(0, 0, 0, 0), 0)
	card.add_child(title)
	title.position = Vector2(16.0, 12.0)
	title.size = Vector2(card.size.x - 32.0, 40.0)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_GUI.style_label(body, _INK, 20, Color(0, 0, 0, 0), 0)
	card.add_child(body)
	body.position = Vector2(20.0, 64.0)
	body.size = Vector2(card.size.x - 40.0, card.size.y - 140.0)
	var rows := _CLOSET.mail_rows()
	if rows.is_empty():
		if _CLOSET.mail_waiting() > 0:
			body.text = "Your order is on the way."
		else:
			body.text = "You have no mail."
	else:
		var lines := PackedStringArray()
		for item in rows:
			if item is Dictionary:
				lines.append(String((item as Dictionary).get("name", "Delivery")))
		body.text = "\n".join(lines)
	var button := Button.new()
	button.text = "OK" if rows.is_empty() else "Accept"
	button.position = Vector2(card.size.x * 0.5 - 70.0, card.size.y - 64.0)
	button.size = Vector2(140.0, 40.0)
	card.add_child(button)
	if rows.is_empty():
		button.pressed.connect(_close)
	else:
		button.pressed.connect(_accept)


func _accept() -> void:
	var style := ToonRoster.selected_style()
	if style != null:
		_CLOSET.take_mail(style)
	_close()


func _close() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null
	done.emit()


func _box(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mesh.material_override = mat
	return mesh
