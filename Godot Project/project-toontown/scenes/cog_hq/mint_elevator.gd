extends Node

## DistributedMintElevatorExt. The three cars sit on the Cashbot trainyard.
## Boarding counts down, the doors close, and a baked floor of that mint is
## chosen. Beating the supervisor sends the toon back to the car they boarded.
## Walking out of the mint does not.

const _MODEL := "res://assets/cog_hq/mint/mint_elevator.glb"
const _MINT := "res://scenes/cog_hq/cashbot_mint.tscn"
const _YARD := "res://scenes/cog_hq/cashbot_trainyard.tscn"
const _MUSIC := "res://assets/buildings/cog/audio/tt_elevator.ogg"
const _OPEN_SFX := "res://assets/buildings/cog/audio/elevator_door_open.ogg"
const _CLOSE_SFX := "res://assets/buildings/cog/audio/elevator_door_close.ogg"
const _HOP_UP := preload("res://assets/gui/rules/InventoryButtonUp.png")
const _HOP_DN := preload("res://assets/gui/rules/InventoryButtonDown.png")
const _HOP_OVER := preload("res://assets/gui/rules/InventoryButtonRollover.png")

## ElevatorData[ELEVATOR_MINT].
const _REACH := 5.0
const _COUNTDOWN := 15.0
const _CLOSE_TIME := 2.0
const _BOARD := 1.0
const _BOARD_RUN := 0.75
const _BOARD_CAM := 1.5
const _EXIT := 1.0
## Door travel. The mint car's width in ElevatorData.
const _SLIDE := 5.875
const _HOP_W := 0.1804 * 20.0 * 0.15
const _HOP_H := 0.1137 * 11.0 * 0.15
## The wrapper's +Z is outside the doors. -Z is the car.
const _SEAT := Vector3(0.0, 0.15, -3.5)
const _JUMP := Vector3(0.0, 0.15, 4.5)

static var trip := ""
static var mint_id := 12500
static var floor_num := 0
static var ride := 0

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


static func place(host: Node) -> void:
	if Engine.is_editor_hint() or host == null:
		return
	var file := host.scene_file_path.get_file()
	if file != "cashbot_trainyard.tscn" and file != "cashbot_mint.tscn":
		return
	if host.get_node_or_null("MintElevators") != null:
		return
	var script := load("res://scenes/cog_hq/mint_elevator.gd") as GDScript
	var node := script.new() as Node
	node.name = "MintElevators"
	host.add_child(node)


static func arrival(host: Node, into_mint: bool) -> Dictionary:
	if host == null:
		return {}
	if into_mint:
		var floor := host.get_node_or_null("MintFloor") as Node3D
		if floor == null or not floor.has_meta("spawn"):
			return {}
		return {
			"point": floor.get_meta("spawn"),
			"heading": float(floor.get_meta("spawn_h")),
		}
	var car := _find(host, "MintCar%d" % mint_id)
	if car == null:
		return {}
	return {
		"point": car.global_transform * _JUMP,
		"heading": _heading(car.global_transform.basis.z),
	}


func _ready() -> void:
	var host := get_parent()
	if host == null:
		return
	if host.scene_file_path.get_file() == "cashbot_trainyard.tscn":
		_yard(host)
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


func _yard(host: Node) -> void:
	var geom := host.get_node_or_null("Geometry") as Node3D
	if geom == null:
		return
	var packed := load(_MODEL) as PackedScene
	if packed == null:
		return
	var floors := load("res://scenes/cog_hq/mint_floor.gd") as GDScript
	var book: Dictionary = floors.data() if floors != null else {}
	for item in book.get("elevators", []):
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item
		var car := packed.instantiate() as Node3D
		if car == null:
			continue
		var which := int(spec.get("mint", 0))
		car.name = "MintCar%d" % which
		geom.add_child(car)
		var x := _vec(spec.get("x", [1.0, 0.0, 0.0]))
		var y := _vec(spec.get("y", [0.0, 1.0, 0.0]))
		var z := _vec(spec.get("z", [0.0, 0.0, 1.0]))
		car.transform = Transform3D(Basis(x, y, z), _vec(spec.get("o", [0.0, 0.0, 0.0])))
		car.set_meta("mint", which)
		car.set_meta("origin", int(spec.get("origin", 0)))
		car.set_meta("title", String(spec.get("name", "Mint")))
		_remember_doors(car)
		_solid(car)
		_sign(geom, car)
		_cars.append(car)


func _offer() -> void:
	var toon := _toon()
	if toon == null or bool(toon.call("battle_busy")):
		return
	var here: Vector3 = toon.call("battle_point")
	for car in _cars:
		if car == null:
			continue
		if not _in_door(car, here):
			continue
		_begin_board(car)
		return


func _in_door(car: Node3D, here: Vector3) -> bool:
	if absf(here.y - car.global_position.y) > 8.0:
		return false
	var local := car.global_transform.affine_inverse() * here
	return Vector2(local.x, local.z - 1.42).length() < _REACH


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
		face = _heading(_car.global_transform.basis.z)
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


## The supervisor battle is what finishes the mint.
func win_leave() -> void:
	trip = "out"
	ToonLoading.change_to(_YARD)


func _depart() -> void:
	if _car == null:
		_release()
		return
	trip = "in"
	ride += 1
	mint_id = int(_car.get_meta("mint"))
	floor_num = randi() % 20
	ToonNet.publish("mint-trip", {"mint": mint_id, "floor": floor_num, "ride": ride})
	ToonLoading.change_to(_MINT)


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
	var face := _heading(_car.global_transform.basis.z)
	var blend := clampf(_age / _EXIT, 0.0, 1.0)
	toon.call("visit_friend", _from.lerp(dest, blend), face)
	_animate(16.0 if blend < 1.0 else 0.0)
	_aim()
	if _age >= _EXIT:
		_release()


func _stand() -> void:
	if _car == null:
		return
	var toon := _toon()
	if toon == null:
		return
	var face := _heading(_car.global_transform.basis.z)
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
	for door_name in ["left_door", "right_door"]:
		var door := _find(_car, door_name)
		if door == null or not door.has_meta("open_x"):
			continue
		var sign := -1.0 if door_name.begins_with("right") else 1.0
		door.position.x = float(door.get_meta("open_x")) + sign * amount


func _remember_doors(car: Node) -> void:
	for door_name in ["left_door", "right_door"]:
		var door := _find(car, door_name)
		if door != null:
			door.set_meta("open_x", door.position.x)


func _solid(node: Node) -> void:
	var node_name := String(node.name)
	if node_name == "left_door" or node_name == "right_door":
		return
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null:
			mesh.create_trimesh_collision()
	for child in node.get_children():
		_solid(child)


func _sign(geom: Node3D, car: Node3D) -> void:
	var origin := _find(geom, "elevator_signorigin_%d" % int(car.get_meta("origin")))
	if origin == null:
		return
	var face := car.global_transform.basis.z
	face.y = 0.0
	if face.length_squared() < 0.0001:
		face = Vector3.FORWARD
	face = face.normalized()
	var right := Vector3.UP.cross(face).normalized()
	var label := Label3D.new()
	label.text = String(car.get_meta("title")).to_upper()
	label.font = ToonGui.suit_font()
	label.font_size = 100
	label.pixel_size = 0.018
	label.modulate = Color(0.87, 0.87, 0.87, 1.0)
	label.outline_size = 0
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geom.add_child(label)
	label.global_transform = Transform3D(Basis(right, Vector3.UP, face), origin.global_position + face * 0.2)


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
	var dest: Vector3 = _car.global_transform * Vector3(0.0, 5.5, 16.0)
	var look: Vector3 = _car.global_transform * Vector3(0.0, 5.5, 0.0)
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
	var face := _car.global_transform.basis.z
	face.y = 0.0
	if face.length_squared() < 0.0001:
		face = Vector3.FORWARD
	face = face.normalized()
	var right := Vector3.UP.cross(face).normalized()
	var at: Vector3 = _car.global_transform * Vector3(0.0, 7.5, -1.5)
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


func _vec(value: Variant) -> Vector3:
	if value is Array:
		var row: Array = value
		if row.size() >= 3:
			return Vector3(float(row[0]), float(row[1]), float(row[2]))
	return Vector3.ZERO
