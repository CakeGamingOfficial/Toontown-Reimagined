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


func tick(_delta: float) -> void:
	if _host == null or _switching:
		return
	var game := MiniGolf.mine()
	if not game.is_empty():
		_go(game)
		return
	var seat := MiniGolf.seated_kart()
	if seat >= 0:
		_hold(seat)
		return
	_asked = -1
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
	if best < 0 or best == _asked:
		return
	_asked = best
	ToonNet.minigolf_act("join", best, 0.0, 0.0)


func _hold(seat: int) -> void:
	_held = true
	_host.set("_locked", true)
	var body := _host.get("_body") as CharacterBody3D
	var kart := _kart_node(seat)
	if body != null and kart != null:
		var stand := kart.global_position
		stand.y = body.global_position.y
		body.global_position = stand
		body.velocity = Vector3.ZERO
		var actor := _host.get("_player") as Node3D
		if actor != null and actor.has_method("set_locomotion"):
			actor.call("set_locomotion", 0.0, false, false, 0.016)
	if _exit != null:
		_exit.visible = true
		_place_hop()
	var wait := _wait(seat)
	_show_clock(kart, wait)


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
	ToonNet.minigolf_act("leave", 0, 0.0, 0.0)
