extends Node

## DistributedGolfKart. The three rows on Chip 'n Dale's MiniGolf are already
## in the playground model: 3 holes, 6 holes, and 9 holes. Walking up takes a
## seat. The district starts the round when the clock finishes.

const ROUND := "res://scenes/golf/minigolf_round.tscn"
const PLAYGROUND := "res://scenes/playgrounds/chip_n_dales_minigolf.tscn"
const _CART := "res://assets/minigolf/golf_cart3.glb"
const _HOP_UP := preload("res://assets/gui/rules/InventoryButtonUp.png")
const _HOP_DN := preload("res://assets/gui/rules/InventoryButtonDown.png")
const _HOP_OVER := preload("res://assets/gui/rules/InventoryButtonRollover.png")
## GolfKart exit button. image_scale (20, 1, 11) on a 0.15 node.
const _HOP_W := 0.1804 * 20.0 * 0.15
const _HOP_H := 0.1137 * 11.0 * 0.15
const _REACH := 5.5
## generateToonJumpTrack waits 0.43s, then a 0.9s hop. sit-start begins at 1s.
const _JUMP_HOLD := 0.43
const _JUMP_FLY := 0.9
const _SIT_AT := 1.0
## generateToonReverseJumpTrack waits 0.1s, then the same 0.9s hop.
const _OUT_HOLD := 0.1
const _OUT_FLY := 0.9
const _ARC := 3.0
## GolfKart.enterBoarding. The camera settles over 1.5s at (0, 18, 8).
const _BOARD_CAM := 1.5
## JumpOutOffsets, kart-local. Z is up on the playground pad.
const _OUT: Array[Vector3] = [
	Vector3(3.0, 5.0, 0.0),
	Vector3(1.5, 4.0, 0.0),
	Vector3(-1.5, 4.0, 0.0),
	Vector3(-3.0, 4.0, 0.0),
]

static var _drop := Vector3.ZERO
static var _drop_heading := 0.0
static var _drop_on := false

var _host: Node
var _karts: Array[Node3D] = []
var _exit: TextureButton
var _clock: Label3D
var _held := false
var _asked := -1
var _switching := false
var _phase := ""
var _age := 0.0
var _kart_i := -1
var _seat_i := 0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _ground := 0.0
var _head_from := 0.0
var _head_to := 0.0
var _jump_len := 0.0
var _sit_len := 0.0
var _cam_blend := 0.0
var _cam_from := Vector3.ZERO
var _look_from := Vector3.ZERO


static func take_drop() -> Dictionary:
	if not _drop_on:
		return {}
	_drop_on = false
	return {"point": _drop, "heading": _drop_heading}


static func queue_drop(point: Vector3, heading: float) -> void:
	_drop = point
	_drop_heading = heading
	_drop_on = true


func setup(host: Node) -> bool:
	_host = host
	var root := host.get_parent()
	if root == null or not String(host.call("_scene_path")).contains("minigolf"):
		queue_free()
		return false
	var packed := load(_CART) as PackedScene
	for course in 3:
		for slot in 3:
			var spot := _parking_spot(root, course, slot)
			if spot == null:
				continue
			var kart := spot
			if packed != null:
				kart = packed.instantiate() as Node3D
				kart.name = "Cart"
				spot.add_child(kart)
				# The pad sits 0.05 under the kart. Local Z is up inside the playground model.
				kart.position = Vector3(0.0, 0.0, 0.05)
			_karts.append(kart)
			_sign(kart, MiniGolfRules.course_title(course))
	if _karts.is_empty():
		queue_free()
		return false
	_build_hud()
	return true


func tick(delta: float) -> void:
	if _host == null or _switching:
		return
	var game := MiniGolf.mine()
	if not game.is_empty():
		_go(game)
		return
	if _phase == "out":
		_fly_out(delta)
		return
	var seat := MiniGolf.seated_kart()
	if seat >= 0:
		_ride(seat, delta)
		return
	_let_go()
	_try_join()


func _try_join() -> void:
	if bool(_host.get("_locked")) or bool(_host.get("_filming")):
		return
	var body := _host.get("_body") as Node3D
	if body == null:
		return
	var best := -1
	var gap := _REACH
	for index in _karts.size():
		var offset := body.global_position - _karts[index].global_position
		offset.y = 0.0
		if offset.length() < gap:
			gap = offset.length()
			best = index
	if best < 0:
		_asked = -1
		return
	if best == _asked:
		return
	_asked = best
	ToonNet.minigolf_act("join", best, 0.0, 0.0)


## Walking cannot leave a seat. Hop off plays the reverse jump and lands
## outside the join radius, so the cart does not pull the toon back on.
func _ride(seat: int, delta: float) -> void:
	_held = true
	_host.set("_locked", true)
	if _phase == "" or _kart_i != seat:
		_begin_in(seat)
	if _phase == "in":
		_age += delta
		_place_in()
	if _phase == "sit":
		_place_sit()
	if _exit != null:
		_exit.visible = true
		_place_hop()
	_cam_blend = minf(_cam_blend + delta / _BOARD_CAM, 1.0)
	_show_clock(_kart_node(seat), _wait(seat))


func _begin_in(seat: int) -> void:
	var body := _host.get("_body") as CharacterBody3D
	var actor := _host.get("_player") as Node3D
	var kart := _kart_node(seat)
	_kart_i = seat
	_seat_i = _my_seat(seat)
	_phase = "in"
	_age = 0.0
	_from = body.global_position if body != null else Vector3.ZERO
	_ground = _from.y
	_head_from = float(_host.get("_heading"))
	_head_to = _sit_heading(kart, _seat_i)
	_to = _from
	if kart != null:
		_to = _cushion(kart, _seat_i)
		_to.y -= _hip_drop(actor)
	_jump_len = _clip_length(actor, "jump")
	_sit_len = _clip_length(actor, "sit-start")
	_remember_camera()
	if body != null:
		body.velocity = Vector3.ZERO


func _place_in() -> void:
	var body := _host.get("_body") as CharacterBody3D
	var actor := _host.get("_player") as Node3D
	if body == null:
		return
	var landed := _JUMP_HOLD + _JUMP_FLY
	var along := 0.0
	if _age > _JUMP_HOLD:
		along = clampf((_age - _JUMP_HOLD) / _JUMP_FLY, 0.0, 1.0)
	if _age < landed:
		body.global_position = _arc(_from, _to, along)
		_aim(rad_to_deg(lerp_angle(deg_to_rad(_head_from), deg_to_rad(_head_to), along)))
	else:
		body.global_position = _to
		_aim(_head_to)
	body.velocity = Vector3.ZERO
	if actor == null:
		return
	if _age < _SIT_AT:
		_pose(actor, "jump", minf(_age, _jump_len))
		_share("jump")
		return
	if _sit_len > 0.0 and _age < _SIT_AT + _sit_len:
		_pose(actor, "sit-start", _age - _SIT_AT)
		_share("sit-start")
		return
	_phase = "sit"


func _place_sit() -> void:
	var body := _host.get("_body") as CharacterBody3D
	var actor := _host.get("_player") as Node3D
	if body != null:
		body.global_position = _to
		body.velocity = Vector3.ZERO
	_aim(_head_to)
	if actor != null and actor.has_method("pose_synced_loop"):
		actor.call("pose_synced_loop", "sit")
	_share("sit")


func _fly_out(delta: float) -> void:
	_age += delta
	var body := _host.get("_body") as CharacterBody3D
	var actor := _host.get("_player") as Node3D
	var landed := _OUT_HOLD + _OUT_FLY
	var along := 0.0
	if _age > _OUT_HOLD:
		along = clampf((_age - _OUT_HOLD) / _OUT_FLY, 0.0, 1.0)
	if body != null and _age < landed:
		body.global_position = _arc(_from, _to, along)
		body.velocity = Vector3.ZERO
		_aim(rad_to_deg(lerp_angle(deg_to_rad(_head_from), deg_to_rad(_head_to), along)))
		_pose(actor, "jump", minf(_age, _jump_len))
		_share("jump")
		return
	if body != null:
		body.global_position = _to
		body.velocity = Vector3.ZERO
	_aim(_head_to)
	if actor != null:
		if actor.has_method("end_action"):
			actor.call("end_action", "jump")
		if actor.has_method("release_pose"):
			actor.call("release_pose")
		if actor.has_method("clear_gesture"):
			actor.call("clear_gesture")
	_share("neutral")
	_asked = _kart_i
	_phase = ""
	_let_go()


func _let_go() -> void:
	if _exit != null:
		_exit.visible = false
	if _clock != null:
		_clock.visible = false
	if not _held:
		return
	_held = false
	_host.set("_locked", false)


func _go(game: Dictionary) -> void:
	_switching = true
	var body := _host.get("_body") as Node3D
	var point := body.global_position if body != null else Vector3.ZERO
	var heading := float(_host.get("_heading"))
	queue_drop(point, heading)
	var arrival := load("res://scenes/playgrounds/playground_toon.gd")
	arrival.teleport_in = true
	ToonLoading.change_to(ROUND)


func _parking_spot(root: Node, course: int, slot: int) -> Node3D:
	var kart := root.find_child("golf_kart_%d_%d" % [course, slot], true, false) as Node3D
	if kart == null:
		return null
	# The playground import keeps one pad named starting_block_0 and
	# renames the other eight. The pad is the kart marker's child.
	for child in kart.get_children():
		if child is Node3D and String(child.name).begins_with("starting_block"):
			return child
	return kart


func _kart_node(published_index: int) -> Node3D:
	if published_index < 0 or published_index >= _karts.size():
		return null
	return _karts[published_index]


func _wait(published_index: int) -> float:
	var state := ToonNet.latest("minigolf")
	var karts: Array = state.get("karts", [])
	if published_index < 0 or published_index >= karts.size():
		return -1.0
	return float(karts[published_index].get("wait", -1.0))


func _sign(kart: Node3D, title: String) -> void:
	var label := Label3D.new()
	label.text = title
	label.font = ToonGui.sign_font()
	label.font_size = 48
	label.pixel_size = 0.04
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.15, 0.35, 0.15)
	label.outline_modulate = Color(0.95, 0.95, 0.8)
	label.outline_size = 8
	label.position = Vector3(0.0, 0.0, 6.4)
	kart.add_child(label)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_exit = TextureButton.new()
	_exit.texture_normal = _HOP_UP
	_exit.texture_pressed = _HOP_DN
	_exit.texture_hover = _HOP_OVER
	_exit.ignore_texture_size = true
	_exit.stretch_mode = TextureButton.STRETCH_SCALE
	_exit.focus_mode = Control.FOCUS_NONE
	_exit.visible = false
	_exit.self_modulate = Color(1.0, 0.0, 0.0, 1.0)
	_exit.pressed.connect(_get_off)
	ToonGui.button_sounds(_exit)
	var caption := Label.new()
	caption.text = "Hop off"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	_exit.add_child(caption)
	layer.add_child(_exit)
	_clock = Label3D.new()
	_clock.font = ToonGui.sign_font()
	_clock.font_size = 64
	_clock.pixel_size = 2.0 / 64.0
	_clock.modulate = Color(0.9, 0.1, 0.1, 1.0)
	_clock.outline_size = 0
	_clock.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock.position = Vector3(0.0, -1.0, 7.0)
	_clock.visible = false


func _place_hop() -> void:
	if _exit == null:
		return
	var view := get_viewport().get_visible_rect().size
	ToonGui.place(_exit, view, 0.0, 0.8, _HOP_W, _HOP_H)
	var caption := _exit.get_child(0) as Label
	if caption == null:
		return
	ToonGui.style_label(caption, Color(1.0, 1.0, 0.65, 1.0), maxi(int(round(0.12 * view.y * 0.5)), 8), Color(0, 0, 0, 0), 0)


func _show_clock(kart: Node3D, wait: float) -> void:
	if _clock == null or kart == null:
		return
	if _clock.get_parent() != kart:
		kart.add_child(_clock)
	_clock.visible = wait >= 0.0
	_clock.text = str(int(ceil(maxf(wait, 0.0))))


func _get_off() -> void:
	if _phase == "out" or _kart_i < 0:
		return
	var body := _host.get("_body") as CharacterBody3D
	var kart := _kart_node(_kart_i)
	_from = body.global_position if body != null else _to
	_to = _exit_point(kart, _seat_i)
	_head_from = float(_host.get("_heading"))
	var away := _to - _from
	away.y = 0.0
	_head_to = _heading_of(away) if away.length_squared() > 0.04 else _head_from
	_age = 0.0
	_phase = "out"
	if _exit != null:
		_exit.visible = false
	ToonNet.minigolf_act("leave", 0, 0.0, 0.0)


func _my_seat(kart_index: int) -> int:
	var av := ToonRoster.avatar_id()
	var karts: Array = ToonNet.latest("minigolf").get("karts", [])
	if kart_index < 0 or kart_index >= karts.size():
		return 0
	var riders: Array = karts[kart_index].get("avs", [])
	var found := riders.find(av)
	return found if found >= 0 else 0


func _cushion(kart: Node3D, index: int) -> Vector3:
	var seat := kart.find_child("seat%d" % (index + 1), true, false) as Node3D
	if seat != null:
		return seat.global_position
	return kart.global_position + Vector3(0.0, 1.6, 0.0)


func _exit_point(kart: Node3D, index: int) -> Vector3:
	if kart == null:
		return _from
	var spot := kart.global_transform * _OUT[clampi(index, 0, 3)]
	spot.y = _ground
	var flat := spot - kart.global_position
	flat.y = 0.0
	if flat.length() < _REACH + 0.75:
		if flat.length_squared() < 0.01:
			flat = Vector3(_REACH + 0.75, 0.0, 0.0)
		else:
			flat = flat.normalized() * (_REACH + 0.75)
		spot = kart.global_position + flat
		spot.y = _ground
	return spot


## The kart's heading is its local +Y. Front seats add 180 and face the hood.
func _sit_heading(kart: Node3D, index: int) -> float:
	if kart == null:
		return float(_host.get("_heading"))
	var forward := kart.global_transform.basis.y
	forward.y = 0.0
	var heading := _heading_of(forward)
	if index < 2:
		heading += 180.0
	return heading


## The follow camera sits behind the toon, so the number at the front of the
## cart stays out of frame. This is the boarding shot that looks back at it.
func holds_camera() -> bool:
	return _held and _phase != "out" and _kart_node(_kart_i) != null


func aim(camera: Camera3D) -> void:
	var kart := _kart_node(_kart_i)
	if camera == null or kart == null:
		return
	var dest := kart.global_transform * Vector3(0.0, 18.0, 8.0)
	var look := kart.global_transform * Vector3(0.0, 0.0, 4.0)
	var t := clampf(_cam_blend, 0.0, 1.0)
	camera.global_position = _cam_from.lerp(dest, t)
	var focus := _look_from.lerp(look, t)
	if camera.global_position.distance_squared_to(focus) > 0.04:
		var up := kart.global_transform.basis.z
		if up.dot(Vector3.UP) < 0.0:
			up = -up
		camera.look_at(focus, up if up.length_squared() > 0.01 else Vector3.UP)


func _remember_camera() -> void:
	_cam_blend = 0.0
	var camera := _host.get("_camera") as Camera3D
	if camera == null:
		_cam_from = Vector3.ZERO
		_look_from = Vector3.FORWARD
		return
	_cam_from = camera.global_position
	_look_from = _cam_from - camera.global_basis.z * 12.0


func _heading_of(forward: Vector3) -> float:
	return rad_to_deg(atan2(-forward.x, -forward.z))


func _aim(heading: float) -> void:
	_host.set("_heading", heading)
	var actor := _host.get("_player") as Node3D
	if actor != null and _host.has_method("_face"):
		_host.call("_face", actor, heading)


func _arc(start: Vector3, finish: Vector3, along: float) -> Vector3:
	var mid := start.lerp(finish, along)
	mid.y += sin(along * PI) * _ARC
	return mid


func _hip_drop(actor: Node3D) -> float:
	if actor == null:
		return 1.2
	if actor.has_method("pose_action"):
		actor.call("pose_action", "sit", 47.0 / 24.0)
	var joint := actor.find_child("joint_hips", true, false) as Node3D
	var drop := 1.2
	if joint != null:
		drop = joint.global_position.y - actor.global_position.y
	if actor.has_method("end_action"):
		actor.call("end_action", "sit")
	if actor.has_method("release_pose"):
		actor.call("release_pose")
	return maxf(drop, 0.4)


func _clip_length(actor: Node3D, suffix: String) -> float:
	if actor != null and actor.has_method("action_length"):
		return float(actor.call("action_length", suffix))
	return 0.0


func _pose(actor: Node3D, suffix: String, elapsed: float) -> void:
	if actor != null and actor.has_method("pose_action"):
		actor.call("pose_action", suffix, elapsed)


func _share(anim: String) -> void:
	var remotes := _host.get("_remotes") as Node
	if remotes != null and remotes.has_method("note_anim"):
		remotes.call("note_anim", float(_host.get("_heading")), anim)
