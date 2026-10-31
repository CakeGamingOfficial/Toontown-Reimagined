extends "res://scenes/trolley/trolley_minigame.gd"

## Ring Game. Swim through the color named on the sign. Rings are swimming_game_ring.

const _COLORS := [
	Color(1.0, 0.4, 0.2), Color(0.0, 0.9, 0.2), Color(1.0, 0.5, 0.25),
	Color(1.0, 0.0, 1.0), Color(1, 1, 1), Color(0.15, 0.15, 0.15), Color(1, 1, 0.2),
]
const _NAMES := ["red", "green", "orange", "purple", "white", "black", "yellow"]
var _rings: Array[Dictionary] = []
var _want := 0
var _sent := 0
var _gap := 0.0
var _hold := -1.0
var _px := 0.0
var _pz := 2.0
var _sign: Label
static var _shared_color := -1


func _init() -> void:
	if _shared_color < 0:
		_shared_color = randi() % _NAMES.size()
	_want = _shared_color
	title = "Ring Game"
	instructions = "Try to swim through as many of the %s rings as you can.  Use the arrow keys to swim." % _NAMES[_want]
	duration = 55.0


func _build() -> void:
	_show("res://assets/minigames/swimming_game.glb")
	_shared_color = -1
	_make_toon(_panda(_px, 0.0, _pz))
	# Face the rings. Yaw 180 faces the camera, so 0 swims away from it.
	_toon.rotation_degrees.y = 0.0
	_toon.pose_swimming(false)
	_aim(_px, -15.0, _pz, _px, 20.0, _pz)
	_loop_sfx("AV_ambient_water", 0.35)
	var layer := CanvasLayer.new()
	add_child(layer)
	_sign = Label.new()
	_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sign.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_sign.offset_top = 70
	_sign.offset_bottom = 130
	_sign.offset_left = -240
	_sign.offset_right = 240
	_sign.add_theme_font_size_override("font_size", 40)
	layer.add_child(_sign)
	_paint_sign()
	show_board("ring")


func _play(delta: float) -> void:
	var move := _stick()
	_px = clampf(_px + move.x * 10.0 * delta, -10.0, 10.0)
	_pz = clampf(_pz + move.y * 10.0 * delta, -2.0, 10.0)
	_toon.position = _panda(_px, 0.0, _pz)
	_toon.play_gesture("swim", 1.0, true)
	_toon.set_locomotion(0.0, false, false, delta)
	_camera.position = _panda(_px, -15.0, _pz + 1.0)
	_camera.look_at(_panda(_px, 12.0, _pz), Vector3.UP)
	_gap -= delta
	if _gap <= 0.0 and _sent < 16:
		_gap = 3.0
		_sent += 1
		var ring := _spawn("res://assets/minigames/swimming_ring.glb", randf_range(-7.0, 7.0), 90.0, randf_range(0.5, 8.0))
		if ring == null:
			ring = _ball(1.4, _COLORS[_want])
			add_child(ring)
			ring.position = _panda(randf_range(-7.0, 7.0), 90.0, randf_range(0.5, 8.0))
		else:
			_tint(ring, _COLORS[_want])
		_rings.append({"node": ring, "taken": false, "index": _sent - 1})
	var kept: Array[Dictionary] = []
	for item in _rings:
		var node := item["node"] as Node3D
		node.position.z += 22.5 * delta
		var passed := node.position.z > _toon.position.z + 1.2
		var through := node.position.z > _toon.position.z - 1.0 and node.position.z < _toon.position.z + 1.2
		var aimed := Vector2(node.position.x - _toon.position.x, node.position.y - _toon.position.y).length() < 3.2
		if through and aimed and not bool(item["taken"]):
			item["taken"] = true
			score += 1
			_sfx("ring_get")
			node.visible = false
		if passed:
			if _board != null:
				_board.mark_ring(int(item["index"]), bool(item["taken"]))
			if not bool(item["taken"]):
				_sfx("ring_miss", 0.7)
			node.queue_free()
		else:
			kept.append(item)
	_rings = kept
	if _sent >= 16 and _rings.is_empty():
		if score < 16:
			_end()
			return
		if _hold < 0.0:
			_hold = 2.0
			_sfx("ring_perfect")
			if _board != null:
				_board.perfect()
		_hold -= delta
		if _hold <= 0.0:
			_end()


func _paint_sign() -> void:
	_sign.text = "Swim through the %s rings" % _NAMES[_want]
	_sign.add_theme_color_override("font_color", _COLORS[_want])
