extends Node

## DistributedFactoryElevatorExt. The front and side cars sit on the factory
## exterior. Boarding runs the normal elevator countdown, then the doors close
## and the toon teleports in at that entrance. The same car at the entrance rides
## back to the exterior.

const _MODEL := preload("res://assets/buildings/cog/elevator.glb")
const _INTERIOR := "res://scenes/cog_hq/sellbot_factory.tscn"
const _EXTERIOR := "res://scenes/cog_hq/sellbot_factory_exterior.tscn"
const _MUSIC := "res://assets/buildings/cog/audio/tt_elevator.ogg"
const _OPEN_SFX := "res://assets/buildings/cog/audio/elevator_door_open.ogg"
const _CLOSE_SFX := "res://assets/buildings/cog/audio/elevator_door_close.ogg"
const _HOP_UP := preload("res://assets/gui/rules/InventoryButtonUp.png")
const _HOP_DN := preload("res://assets/gui/rules/InventoryButtonDown.png")
const _HOP_OVER := preload("res://assets/gui/rules/InventoryButtonRollover.png")

## ElevatorData for a normal elevator.
const _REACH := 5.0
const _COUNTDOWN := 15.0
const _CLOSE_TIME := 2.0
const _BOARD := 1.0
const _BOARD_RUN := 0.75
## Elevator.enterBoarding. Factory elevators leave reverseBoardingCamera off.
const _BOARD_CAM := 1.5
const _EXIT := 1.0
const _SLIDE := 3.5
const _SCALE := 1.05
const _HOP_W := 0.1804 * 20.0 * 0.15
const _HOP_H := 0.1137 * 11.0 * 0.15
## ElevatorPoints[0] and JumpOutOffsets[0]. Local Y points into the car.
const _SEAT := Vector3(-1.5, 5.0, 0.1)
const _JUMP := Vector3(-1.5, -5.0, 0.1)
## setEntranceId. Panda (x, y, z, heading).
const _FRONT := Vector3(62.74, -85.31, 0.0)
const _FRONT_H := 2.0
const _SIDE := Vector3(-162.25, 26.43, 0.0)
const _SIDE_H := 269.0

static var trip := ""
static var entrance := 0

var _cars: Array[Node3D] = []
var _car: Node3D
var _phase := ""
var _age := 0.0
var _left := 0.0
var _from := Vector3.ZERO
var _hop: TextureButton
var _clock: Label3D
var _music: AudioStreamPlayer
var _cue := ""
var _cam_from := Vector3.ZERO
var _look_from := Vector3.FORWARD
var _cam_blend := -1.0


static func riding() -> bool:
	return trip != ""


static func place(host: Node) -> void:
	if Engine.is_editor_hint() or host == null:
		return
	var file := host.scene_file_path.get_file()
	if file != "sellbot_factory_exterior.tscn" and file != "sellbot_factory.tscn":
		return
	if host.get_node_or_null("FactoryElevators") != null:
		return
	var script := load("res://scenes/cog_hq/factory_elevator.gd") as GDScript
	var node := script.new() as Node
	node.name = "FactoryElevators"
	host.add_child(node)


## setFactoryInteriorZone uses how = teleportIn. The landing is the floor in
## front of the entrance car. The seat is inside the elevator.
static func arrival(host: Node, which: int, into_factory: bool) -> Dictionary:
	if into_factory:
		var car := _find(host, "FactoryExitFront" if which == 0 else "FactoryExitSide")
		if car == null:
			return {}
		var out := -car.global_transform.basis.y
		out.y = 0.0
		return {
			"point": car.global_transform * _JUMP,
			"heading": _heading(out),
		}
	var car := _find(host, "FactoryFront" if which == 0 else "FactorySide")
	if car == null:
		return {}
	var out := -car.global_transform.basis.y
	out.y = 0.0
	return {
		"point": car.global_transform * _JUMP,
		"heading": _heading(out),
	}


func _ready() -> void:
	var host := get_parent()
	if host == null:
		return
	if host.scene_file_path.get_file() == "sellbot_factory.tscn":
		_interior(host)
	else:
		_exterior(host)
	_build_hop()
	_build_clock()


func _process(delta: float) -> void:
	_place_hop()
	if _phase == "":
		_offer()
		return
	_age += delta
	if _phase == "board":
		_step_board()
	elif _phase == "wait":
		_left = maxf(_left - delta, 0.0)
		_show_clock(true)
		_stand()
		if _left <= 0.0:
			_begin_close()
	elif _phase == "close":
		_slide(clampf(_age / _CLOSE_TIME, 0.0, 1.0))
		_stand()
		if _age >= _CLOSE_TIME:
			_depart()
	elif _phase == "hop":
		_show_clock(false)
		_step_hop()


func _exterior(host: Node) -> void:
	var geom := host.get_node_or_null("Geometry") as Node3D
	if geom == null:
		return
	_cars.append(_car_on(geom, "FactoryFront", _to_godot(_FRONT), _world_basis(_FRONT_H), true))
	_cars.append(_car_on(geom, "FactorySide", _to_godot(_SIDE), _world_basis(_SIDE_H), true))
	_cars[0].set_meta("entrance", 0)
	_cars[1].set_meta("entrance", 1)


func _interior(host: Node) -> void:
	var front := _car_on(_find(host, "ZONE03"), "FactoryExitFront", Vector3.ZERO, _panda_basis(180.0), false)
	var side := _car_on(_find(host, "ZONE16"), "FactoryExitSide", Vector3.ZERO, _panda_basis(180.0), false)
	if front != null:
		front.set_meta("entrance", 0)
		_cars.append(front)
	if side != null:
		side.set_meta("entrance", 1)
		_cars.append(side)


func _car_on(parent: Node3D, car_name: String, pos: Vector3, basis: Basis, outside: bool) -> Node3D:
	if parent == null:
		return null
	var car := _MODEL.instantiate() as Node3D
	car.name = car_name
	parent.add_child(car)
	_drop_spin(car)
	car.position = pos
	car.basis = Basis(basis.x * _SCALE, basis.y * _SCALE, basis.z * _SCALE)
	_hide_named(car, "light_panel")
	_hide_named(car, "light_panel_frame")
	_remember_doors(car)
	car.set_meta("outside", outside)
	car.set_meta("ready", outside)
	return car


func _offer() -> void:
	var toon := _toon()
	if toon == null or bool(toon.call("battle_busy")):
		return
	var here: Vector3 = toon.call("battle_point")
	for car in _cars:
		if car == null:
			continue
		_arm(car, here)
		if not bool(car.get_meta("ready")):
			continue
		if not _in_door(car, here):
			continue
		_begin_board(car)
		return


## The arrival seat is inside the car. Ready flips once the toon has walked out.
func _arm(car: Node3D, here: Vector3) -> void:
	if bool(car.get_meta("outside")) or bool(car.get_meta("ready")):
		return
	var local := car.global_transform.affine_inverse() * here
	if local.y < -6.0:
		car.set_meta("ready", true)


func _in_door(car: Node3D, here: Vector3) -> bool:
	if absf(here.y - car.global_position.y) > 6.0:
		return false
	var local := car.global_transform.affine_inverse() * here
	if bool(car.get_meta("outside")):
		return Vector2(local.x, local.y).length() < _REACH
	return absf(local.x) < 3.2 and local.y > -2.0 and local.y < 2.0


func _begin_board(car: Node3D) -> void:
	var toon := _toon()
	if toon == null:
		return
	_car = car
	_phase = "board"
	_age = 0.0
	_cue = ""
	_from = toon.call("battle_point")
	toon.call("hold_for_battle", true)
	_remember_cam()
	_slide(0.0)


func _step_board() -> void:
	var toon := _toon()
	if toon == null or _car == null:
		_release()
		return
	var seat: Vector3 = _car.global_transform * _SEAT
	var toward := _heading(seat - _from)
	var face := toward
	if _age >= _BOARD * _BOARD_RUN:
		face = _heading(-_car.global_transform.basis.y)
	var blend := clampf(_age / _BOARD, 0.0, 1.0)
	toon.call("visit_friend", _from.lerp(seat, blend), face if _age >= _BOARD * _BOARD_RUN else toward)
	_animate(16.0 if _age < _BOARD * _BOARD_RUN else 0.0)
	_aim()
	if _age >= _BOARD:
		_phase = "wait"
		_age = 0.0
		_left = _COUNTDOWN
		_animate(0.0)
		if _hop != null:
			_hop.visible = true


func _begin_close() -> void:
	_phase = "close"
	_age = 0.0
	if _hop != null:
		_hop.visible = false
	_show_clock(false)
	_once("close", _CLOSE_SFX)
	_play_music()


## DistributedFactory.enterForemanReward sends the toon out after the win.
func win_leave() -> void:
	if _phase != "" and _phase != "offer":
		return
	var fallback: Node3D = null
	for car in _cars:
		if car == null or bool(car.get_meta("outside")):
			continue
		if fallback == null:
			fallback = car
		if int(car.get_meta("entrance")) != entrance:
			continue
		_car = car
		_depart()
		return
	if fallback == null:
		return
	_car = fallback
	_depart()


func _depart() -> void:
	if _car == null:
		_release()
		return
	var outside := bool(_car.get_meta("outside"))
	# Walking out does not finish the factory. The foreman battle does.
	trip = "in" if outside else "out"
	entrance = int(_car.get_meta("entrance"))
	ToonLoading.change_to(_INTERIOR if outside else _EXTERIOR)


func _hop_off() -> void:
	if _phase != "wait":
		return
	_phase = "hop"
	_age = 0.0
	_from = _toon().call("battle_point") if _toon() != null else Vector3.ZERO
	if _hop != null:
		_hop.visible = false
	_show_clock(false)
	_once("open", _OPEN_SFX)


func _step_hop() -> void:
	var toon := _toon()
	if toon == null or _car == null:
		_release()
		return
	var dest: Vector3 = _car.global_transform * _JUMP
	var face := _heading(-_car.global_transform.basis.y)
	var blend := clampf(_age / _EXIT, 0.0, 1.0)
	toon.call("visit_friend", _from.lerp(dest, blend), face)
	_animate(16.0 if blend < 1.0 else 0.0)
	_aim()
	if _age >= _EXIT:
		_car.set_meta("ready", true)
		_release()


func _stand() -> void:
	if _car == null:
		return
	var toon := _toon()
	if toon == null:
		return
	var face := _heading(-_car.global_transform.basis.y)
	toon.call("visit_friend", _car.global_transform * _SEAT, face)
	_animate(0.0)
	_aim()


func _release() -> void:
	_phase = ""
	_car = null
	_show_clock(false)
	if _hop != null:
		_hop.visible = false
	_quiet()
	var toon := _toon()
	if toon != null:
		toon.call("hold_for_battle", false)


func _slide(closed: float) -> void:
	if _car == null:
		return
	var amount := _SLIDE * clampf(closed, 0.0, 1.0)
	for door_name in ["left-door", "left_door", "right-door", "right_door"]:
		var door := _find(_car, door_name)
		if door == null or not door.has_meta("open_x"):
			continue
		var sign := -1.0 if door_name.begins_with("right") else 1.0
		door.position.x = float(door.get_meta("open_x")) + sign * amount


func _remember_doors(car: Node) -> void:
	for door_name in ["left-door", "left_door", "right-door", "right_door"]:
		var door := _find(car, door_name)
		if door != null:
			door.set_meta("open_x", door.position.x)


func _animate(speed: float) -> void:
	var toon := _toon()
	if toon == null:
		return
	var actor: Variant = toon.call("battle_actor")
	if actor != null and actor.has_method("set_locomotion"):
		actor.call("set_locomotion", speed, false, false, get_process_delta_time())


## Elevator.enterBoarding. Parent the shot to the car and ease to (0, -16, 5.5)
## over 1.5 seconds. Heading 0 looks along local +Y, into the open doors.
func _aim() -> void:
	if _car == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var dest: Vector3 = _car.global_transform * Vector3(0.0, -16.0, 5.5)
	var look: Vector3 = _car.global_transform * Vector3(0.0, 0.0, 5.5)
	_cam_blend = minf(_cam_blend + get_process_delta_time() / _BOARD_CAM, 1.0)
	var blend := clampf(_cam_blend, 0.0, 1.0)
	camera.global_position = _cam_from.lerp(dest, blend)
	var focus := _look_from.lerp(look, blend)
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


func _toon() -> Node:
	var host := get_parent()
	if host == null:
		return null
	return host.get_node_or_null("PlaygroundToon")


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
	var right := Vector3.UP.cross(face).normalized()
	var at: Vector3 = _car.global_transform * Vector3(0.0, 2.0, 7.5)
	_clock.global_transform = Transform3D(Basis(right, Vector3.UP, face).orthonormalized(), at)
	var text := str(ceili(_left) if _left > 0.0 else 0)
	if _clock.text != text:
		_clock.text = text
	_clock.visible = true


func _build_hop() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ElevatorHop"
	layer.layer = 30
	add_child(layer)
	_hop = TextureButton.new()
	_hop.name = "HopOff"
	_hop.texture_normal = _HOP_UP
	_hop.texture_pressed = _HOP_DN
	_hop.texture_hover = _HOP_OVER
	_hop.ignore_texture_size = true
	_hop.stretch_mode = TextureButton.STRETCH_SCALE
	_hop.focus_mode = Control.FOCUS_NONE
	_hop.visible = false
	_hop.self_modulate = Color(0.5, 0.5, 0.5, 1.0)
	_hop.pressed.connect(_hop_off)
	ToonGui.button_sounds(_hop)
	var caption := Label.new()
	caption.text = "Hop off"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.modulate = Color(2.0, 2.0, 2.0, 1.0)
	caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hop.add_child(caption)
	layer.add_child(_hop)


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
	# TextNode keeps the baseline on (0, 2, 7.5). Bottom alignment parks the
	# descent there instead, so the digits rise into the top of the frame.
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_clock.offset = Vector2(0.0, -_clock.font.get_descent(_clock.font_size))
	_clock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_clock.visible = false
	add_child(_clock)


func _place_hop() -> void:
	if _hop == null or not _hop.visible:
		return
	var view := get_viewport().get_visible_rect().size
	ToonGui.place(_hop, view, 0.0, 0.8, _HOP_W, _HOP_H)
	var caption := _hop.get_child(0) as Label
	if caption != null:
		ToonGui.style_label(caption, Color(0.9, 0.9, 0.9), maxi(int(round(0.12 * view.y * 0.5)), 8), Color(0, 0, 0, 0), 0)


func _play_music() -> void:
	var stream := AudioStreamOggVorbis.load_from_file(_MUSIC)
	if stream == null:
		return
	if _music == null:
		_music = ToonAudio.music_player()
		_music.name = "ElevatorMusic"
		add_child(_music)
	_music.stream = stream
	_music.volume_db = linear_to_db(0.8)
	_music.play()


func _quiet() -> void:
	if _music != null:
		_music.stop()


func _once(token: String, path: String) -> void:
	if _cue == token:
		return
	_cue = token
	var stream := AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		return
	var player := ToonAudio.effect_player()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _drop_spin(root: Node3D) -> void:
	for child in root.get_children():
		if not (child is Node3D):
			continue
		var body := child as Node3D
		var basis := body.basis
		var z_up := basis.x.distance_to(Vector3(1, 0, 0)) < 0.02
		z_up = z_up and basis.y.distance_to(Vector3(0, 0, -1)) < 0.02
		z_up = z_up and basis.z.distance_to(Vector3(0, 1, 0)) < 0.02
		if z_up:
			body.basis = Basis.IDENTITY
		return


func _hide_named(node: Node, piece: String) -> void:
	if str(node.name) == piece or str(node.name).begins_with(piece + "@"):
		if node is Node3D:
			(node as Node3D).visible = false
	for child in node.get_children():
		_hide_named(child, piece)


static func _panda_basis(heading: float) -> Basis:
	var yaw := deg_to_rad(heading)
	return Basis(
		Vector3(cos(yaw), -sin(yaw), 0.0),
		Vector3(-sin(yaw), cos(yaw), 0.0),
		Vector3(0.0, 0.0, 1.0)
	)


static func _world_basis(heading: float) -> Basis:
	var panda := _panda_basis(heading)
	return Basis(_to_godot(panda.x), _to_godot(panda.y), _to_godot(panda.z))


static func _to_godot(panda: Vector3) -> Vector3:
	return Vector3(panda.x, panda.z, -panda.y)


static func _heading(dir: Vector3) -> float:
	return rad_to_deg(atan2(-dir.x, -dir.z))


static func _find(node: Node, node_name: String) -> Node3D:
	if node == null:
		return null
	if node is Node3D and str(node.name) == node_name:
		return node as Node3D
	for child in node.get_children():
		var found := _find(child, node_name)
		if found != null:
			return found
	return null
