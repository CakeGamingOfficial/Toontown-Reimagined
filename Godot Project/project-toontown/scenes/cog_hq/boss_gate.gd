extends Node

## DistributedBossElevator. The lobby elevator boards only when the department
## promotion meter is full. The countdown is ElevatorData for the V.P., C.F.O.,
## C.J., and C.E.O. cars: 30 seconds.

const _VP_ELEVATOR := "res://assets/cog_hq/cog_hq_elevator.glb"
const _SLIDE := "res://assets/cog_hq/audio/CHQ_FACT_door_open_sliding.ogg"
const _FINAL := "res://assets/cog_hq/audio/CHQ_FACT_door_open_final.ogg"
const _REACH := 7.5
const _COUNTDOWN := 30.0
const _CLOSE_TIME := 4.0
const _BOARD := 1.0
const _BOARD_RUN := 0.75
const _BOARD_CAM := 1.5
const _EXIT := 1.0
## ElevatorData width for the V.P. car. Open is the exported rest pose.
const _WIDTH := 11.5
## CollisionSphere(0, 5, 0, collRadius) and BigElevatorPoints[0] / JumpOutOffsets[0].
const _SPHERE := Vector3(0.0, 5.0, 0.0)
const _SEAT := Vector3(-2.5, 9.0, 0.1)
const _JUMP := Vector3(-1.5, -5.0, 0.0)
const _HOP_W := 0.1804 * 20.0 * 0.15
const _HOP_H := 0.1137 * 11.0 * 0.15
const _HOP_UP := preload("res://assets/gui/rules/InventoryButtonUp.png")
const _HOP_DN := preload("res://assets/gui/rules/InventoryButtonDown.png")
const _HOP_OVER := preload("res://assets/gui/rules/InventoryButtonRollover.png")
const _REJECT := "You cannot board this elevator until you have earned a promotion."

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
var _car: Node3D
var _left := 0.0
var _boarding := false
var _phase := ""
var _age := 0.0
var _from := Vector3.ZERO
var _away := false
var _refused := false
var _cue := ""
var _cam_from := Vector3.ZERO
var _look_from := Vector3.FORWARD
var _cam_blend := 0.0
var _hop: TextureButton
var _note: Label
var _clock: Label3D


## DistributedVPElevator.setupElevator. The car is parented to elevator_locator
## and turned 180. The locator is still in the lobby's panda axes.
static func place_car(host: Node) -> void:
	if Engine.is_editor_hint() or host == null:
		return
	if host.scene_file_path.get_file() != "sellbot_lobby.tscn":
		return
	if host.find_child("VpElevator", true, false) != null:
		return
	var locator := host.find_child("elevator_locator", true, false) as Node3D
	if locator == null:
		return
	var packed := load(_VP_ELEVATOR) as PackedScene
	if packed == null:
		return
	var car := packed.instantiate() as Node3D
	if car == null:
		return
	car.name = "VpElevator"
	locator.add_child(car)
	car.basis = Basis(Vector3(-1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, 1))
	car.position = Vector3.ZERO
	_hide_frame(car)


static func _hide_frame(node: Node) -> void:
	var called := str(node.name)
	if called == "big_frame" or called.begins_with("big_frame@"):
		if node is Node3D:
			(node as Node3D).visible = false
	for child in node.get_children():
		_hide_frame(child)


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
	_car = host.find_child("VpElevator", true, false) as Node3D
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
	caption.text = "Hop off" if _car != null else "Board"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hop.add_child(caption)
	if _car != null:
		_hop.self_modulate = Color(0.5, 0.5, 0.5, 1.0)
		_hop.focus_mode = Control.FOCUS_NONE
		_hop.pressed.disconnect(_board)
		_hop.pressed.connect(_hop_off)
		ToonGui.button_sounds(_hop)
		caption.modulate = Color(2.0, 2.0, 2.0, 1.0)
		_build_clock()
	ToonGui.style_label(caption, Color.WHITE, 16, Color(0, 0, 0, 0), 0)
	ToonGui.style_label(_note, Color(1, 0.95, 0.7), 18, Color(0.15, 0.05, 0.2), 4)


func _process(delta: float) -> void:
	if _boss == "":
		return
	if _car != null:
		_ride(delta)
		return
	if _door == null:
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


## Walking into the open car starts the countdown. The digits sit on the frame.
func _ride(delta: float) -> void:
	_place_hop()
	if _phase == "":
		_offer()
		return
	_age += delta
	if _phase == "board" or _phase == "wait":
		_left = maxf(_left - delta, 0.0)
		_show_clock(true)
		if _hop != null:
			_hop.visible = true
		if _phase == "board":
			_step_board()
		else:
			_stand()
		if _left <= 0.0:
			_begin_close()
	elif _phase == "close":
		_show_clock(false)
		if _hop != null:
			_hop.visible = false
		_slide(clampf(_age / _CLOSE_TIME, 0.0, 1.0))
		_stand()
		_once("close", _SLIDE)
		if _age >= _CLOSE_TIME:
			_once("shut", _FINAL)
			_depart()
	elif _phase == "hop":
		_show_clock(false)
		_step_hop()


func _offer() -> void:
	var toon := _toon()
	if toon == null or bool(toon.call("battle_busy")):
		return
	var here: Vector3 = toon.call("battle_point")
	if not _in_sphere(here):
		_away = false
		_refused = false
		return
	if _away or _refused:
		return
	if not DisguisePage.ready_for_promotion(_dept):
		_refused = true
		toon.call("show_popup", _REJECT)
		return
	_phase = "board"
	_age = 0.0
	_left = _COUNTDOWN
	_cue = ""
	_from = here
	toon.call("hold_for_battle", true)
	_remember_cam()


func _in_sphere(here: Vector3) -> bool:
	if _car == null:
		return false
	var local: Vector3 = _car.global_transform.affine_inverse() * here
	if local.distance_to(_SPHERE) <= _REACH:
		return true
	# The cab is solid, so the toon stops on the lobby side of the sphere.
	return absf(local.x) < 8.0 and local.y < 1.0 and local.y > -_REACH and absf(local.z) < 6.0


func _step_board() -> void:
	var toon := _toon()
	if toon == null or _car == null:
		_release()
		return
	var seat: Vector3 = _car.global_transform * _SEAT
	var toward := _heading(seat - _from)
	var face := toward
	if _age >= _BOARD * _BOARD_RUN:
		face = _out_heading()
	var blend := clampf(_age / _BOARD, 0.0, 1.0)
	toon.call("visit_friend", _from.lerp(seat, blend), face)
	_animate(16.0 if _age < _BOARD * _BOARD_RUN else 0.0)
	_aim()
	if _age >= _BOARD:
		_phase = "wait"
		_age = 0.0
		_animate(0.0)


func _stand() -> void:
	var toon := _toon()
	if toon == null or _car == null:
		return
	toon.call("visit_friend", _car.global_transform * _SEAT, _out_heading())
	_animate(0.0)
	_aim()


func _begin_close() -> void:
	_phase = "close"
	_age = 0.0
	if _hop != null:
		_hop.visible = false
	_show_clock(false)


func _hop_off() -> void:
	if _phase != "board" and _phase != "wait":
		return
	_phase = "hop"
	_age = 0.0
	var toon := _toon()
	_from = toon.call("battle_point") if toon != null else Vector3.ZERO
	if _hop != null:
		_hop.visible = false
	_show_clock(false)


func _step_hop() -> void:
	var toon := _toon()
	if toon == null or _car == null:
		_release()
		return
	var dest: Vector3 = _car.global_transform * _JUMP
	var blend := clampf(_age / _EXIT, 0.0, 1.0)
	toon.call("visit_friend", _from.lerp(dest, blend), _out_heading())
	_animate(16.0 if blend < 1.0 else 0.0)
	_aim()
	if _age >= _EXIT:
		_release()


func _release() -> void:
	_phase = ""
	_away = true
	_show_clock(false)
	_slide(0.0)
	if _hop != null:
		_hop.visible = false
	var toon := _toon()
	if toon != null:
		toon.call("hold_for_battle", false)


func _slide(closed: float) -> void:
	if _car == null:
		return
	var left := _find(_car, "left-door")
	var right := _find(_car, "right-door")
	if left != null:
		left.position.x = _WIDTH * closed
	if right != null:
		right.position.x = -_WIDTH * closed


func _out_heading() -> float:
	if _car == null:
		return 0.0
	var out := -_car.global_transform.basis.y
	out.y = 0.0
	return _heading(out)


func _animate(speed: float) -> void:
	var toon := _toon()
	if toon == null:
		return
	var actor: Variant = toon.call("battle_actor")
	if actor != null and actor.has_method("set_locomotion"):
		actor.call("set_locomotion", speed, false, false, get_process_delta_time())


func _aim() -> void:
	if _car == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var dest: Vector3 = _car.global_transform * Vector3(0.0, -16.0, 5.5)
	var look: Vector3 = _car.global_transform * Vector3(0.0, 0.0, 5.5)
	_cam_blend = minf(_cam_blend + get_process_delta_time() / _BOARD_CAM, 1.0)
	camera.global_position = _cam_from.lerp(dest, clampf(_cam_blend, 0.0, 1.0))
	var focus: Vector3 = _look_from.lerp(look, clampf(_cam_blend, 0.0, 1.0))
	if camera.global_position.distance_squared_to(focus) > 0.04:
		camera.look_at(focus, Vector3.UP)


func _remember_cam() -> void:
	_cam_blend = 0.0
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_cam_from = Vector3.ZERO
		_look_from = Vector3.FORWARD
		return
	_cam_from = camera.global_position
	_look_from = _cam_from - camera.global_basis.z * 12.0


func _show_clock(show: bool) -> void:
	if _clock == null or _car == null:
		return
	if not show:
		_clock.visible = false
		return
	var face := -_car.global_transform.basis.y
	face.y = 0.0
	if face.length_squared() < 0.0001:
		face = Vector3.FORWARD
	face = face.normalized()
	var right := Vector3.UP.cross(face)
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	right = right.normalized()
	var at: Vector3 = _car.global_transform * Vector3(0.0, 2.0, 7.5)
	_clock.global_transform = Transform3D(Basis(right, Vector3.UP, face).orthonormalized(), at)
	var text := str(ceili(_left) if _left > 0.0 else 0)
	if _clock.text != text:
		_clock.text = text
	_clock.visible = true


func _build_clock() -> void:
	_clock = Label3D.new()
	_clock.name = "Clock"
	_clock.font = ToonGui.sign_font()
	_clock.font_size = 110
	_clock.pixel_size = 2.0 / 110.0
	_clock.modulate = Color(0.5, 0.5, 0.5, 1.0)
	_clock.outline_size = 0
	_clock.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_clock.offset = Vector2(0.0, -_clock.font.get_descent(_clock.font_size))
	_clock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_clock.visible = false
	add_child(_clock)


func _once(token: String, path: String) -> void:
	if _cue == token:
		return
	_cue = token
	var stream := AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		return
	var player := ToonAudio.effect_player()
	player.stream = stream
	player.volume_db = linear_to_db(0.7)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _toon() -> Node:
	var host := get_parent()
	if host == null:
		return null
	return host.get_node_or_null("PlaygroundToon")


func _board() -> void:
	if not DisguisePage.ready_for_promotion(_dept):
		_note.text = _REJECT
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
	if _car != null:
		if not _hop.visible:
			return
		var size := view.get_visible_rect().size
		ToonGui.place(_hop, size, 0.0, 0.8, _HOP_W, _HOP_H)
		var caption := _hop.get_child(0) as Label
		if caption != null:
			ToonGui.style_label(caption, Color(0.9, 0.9, 0.9), maxi(int(round(0.12 * size.y * 0.5)), 8), Color(0, 0, 0, 0), 0)
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
