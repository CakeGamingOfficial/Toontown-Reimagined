extends Node

## DistributedBossElevator. The lobby elevator boards only when the department
## promotion meter is full. The countdown is ElevatorData for the V.P., C.F.O.,
## C.J., and C.E.O. cars: 30 seconds.

const _REACH := 7.5
const _COUNTDOWN := 30.0
const _HOP_UP := preload("res://assets/gui/rules/InventoryButtonUp.png")
const _HOP_DN := preload("res://assets/gui/rules/InventoryButtonDown.png")
const _HOP_OVER := preload("res://assets/gui/rules/InventoryButtonRollover.png")

const _ROOMS := {
	"sellbot_lobby.tscn": {"boss": "res://scenes/cog_hq/sellbot_vp.tscn", "dept": 3, "marker": "elevator_locator"},
	"cashbot_lobby.tscn": {"boss": "res://scenes/cog_hq/cashbot_cfo.tscn", "dept": 2, "marker": "door_origin_0"},
	"lawbot_lobby.tscn": {"boss": "res://scenes/cog_hq/lawbot_cj.tscn", "dept": 1, "marker": "LBElevator1"},
	"bossbot_lobby.tscn": {"boss": "res://scenes/cog_hq/bossbot_ceo.tscn", "dept": 0, "marker": "elevator_locator"},
}

static var trip := ""

var _dept := 0
var _boss := ""
var _door: Node3D
var _left := 0.0
var _boarding := false
var _hop: TextureButton
var _note: Label


static func place(host: Node) -> void:
	if Engine.is_editor_hint() or host == null:
		return
	var file := host.scene_file_path.get_file()
	if not _ROOMS.has(file) or host.get_node_or_null("BossGate") != null:
		return
	var node := (load("res://scenes/cog_hq/boss_gate.gd") as GDScript).new() as Node
	node.name = "BossGate"
	host.add_child(node)


static func arrival(host: Node) -> Dictionary:
	var gate := host.get_node_or_null("BossGate")
	if gate == null or not gate.has_method("drop"):
		return {}
	return gate.call("drop")


func drop() -> Dictionary:
	if _door == null:
		return {}
	var forward := -_door.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = _door.global_transform.basis.y
		forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3(0, 0, 1)
	forward = forward.normalized()
	return {"point": _door.global_position + forward * 6.0 + Vector3(0, 0.4, 0), "heading": _heading(forward)}


func _ready() -> void:
	var host := get_parent()
	if host == null:
		return
	var room: Dictionary = _ROOMS.get(host.scene_file_path.get_file(), {})
	_dept = int(room.get("dept", 0))
	_boss = String(room.get("boss", ""))
	_door = _find(host, String(room.get("marker", "")))
	if _door == null:
		_door = _find_any(host, ["elevator_locator", "LBElevator1", "elevator", "door_origin_0"])
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_note = Label.new()
	_note.visible = false
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_note.position = Vector2(-220, 80)
	_note.size = Vector2(440, 48)
	layer.add_child(_note)
	_hop = TextureButton.new()
	_hop.texture_normal = _HOP_UP
	_hop.texture_pressed = _HOP_DN
	_hop.texture_hover = _HOP_OVER
	_hop.ignore_texture_size = true
	_hop.stretch_mode = TextureButton.STRETCH_SCALE
	_hop.visible = false
	_hop.pressed.connect(_board)
	layer.add_child(_hop)
	var caption := Label.new()
	caption.text = "Board"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hop.add_child(caption)
	ToonGui.style_label(caption, Color.WHITE, 16, Color(0, 0, 0, 0), 0)
	ToonGui.style_label(_note, Color(1, 0.95, 0.7), 18, Color(0.15, 0.05, 0.2), 4)


func _process(delta: float) -> void:
	if _door == null or _boss == "":
		return
	var body := _body()
	var close := body != null and body.global_position.distance_to(_door.global_position) <= _REACH
	if not close:
		_boarding = false
		_left = 0.0
		_hop.visible = false
		_note.visible = false
		return
	_hop.visible = not _boarding
	_note.visible = true
	if _boarding:
		_left -= delta
		_note.text = "The elevator leaves in %d..." % ceili(_left)
		if _left <= 0.0:
			_depart()
	else:
		_note.text = "Board the elevator"
	_place_hop()


func _board() -> void:
	if not DisguisePage.ready_for_promotion(_dept):
		_note.text = "You cannot board this elevator until you have earned a promotion."
		_note.visible = true
		return
	_boarding = true
	_left = _COUNTDOWN


func _depart() -> void:
	trip = "in"
	ToonLoading.change_to(_boss)


func _place_hop() -> void:
	if _hop == null:
		return
	var view := get_viewport()
	if view == null:
		return
	_hop.size = Vector2(72, 36)
	_hop.position = view.get_visible_rect().size * 0.5 + Vector2(-36, 40)


func _body() -> Node3D:
	var host := get_parent()
	if host == null:
		return null
	return host.get_node_or_null("Player") as Node3D


func _find_any(host: Node, names: Array) -> Node3D:
	for marker in names:
		var found := _find(host, String(marker))
		if found != null:
			return found
	return null


func _find(host: Node, marker: String) -> Node3D:
	if marker == "":
		return null
	var found := host.find_child(marker, true, false)
	return found as Node3D


func _heading(forward: Vector3) -> float:
	return rad_to_deg(atan2(-forward.x, -forward.z))
