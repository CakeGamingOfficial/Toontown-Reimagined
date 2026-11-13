extends "res://scenes/trolley/trolley_minigame.gd"

## Ice Slide. Three matches of two launches. Closer to the center scores more.
## Barrels are worth 1. TNT is worth -1. Ctrl launches the tire.

const _MATCHES := 3
const _ROUNDS := 2
const _MIN := Vector2(-17.5, -12.5)
const _MAX := Vector2(17.5, 12.5)
const _FARTHEST := 22.9

var _hood := 2000
var _match := 0
var _round := 0
var _phase := "aim"
var _aim_left := 15.0
var _heading := 0.0
var _force := 0.01
var _head_momentum := 0.0
var _force_momentum := 0.0
var _at := Vector2(-17.5, -12.5)
var _vel := Vector2.ZERO
var _warned := false
var _treasures: Array[Dictionary] = []
var _penalties: Array[Dictionary] = []
var _props: Array[Node3D] = []
var _obstacles: Array[Vector2] = []
var _round_obs := true
var _tire: Node3D
var _arrow: MeshInstance3D
var _banner: Label


func _init() -> void:
	title = "Ice Slide"
	duration = 400.0
	_hood = int(_RIDE.hood)
	var penalties := _penalty_count()
	if penalties > 0:
		instructions = "Get as close to the center by the end of the second round. Use arrow keys to change direction and force. Press Ctrl to launch your toon.  Hit barrels for extra points and avoid the TNT!"
	else:
		instructions = "Get as close to the center by the end of the second round. Use arrow keys to change direction and force. Press Ctrl to launch your toon.  Hit barrels for extra points."


func begin() -> void:
	super.begin()
	if _clock_face != null:
		_clock_face.visible = false
		_clock_num.visible = false


func _build() -> void:
	_show("res://assets/minigames/ice_rink.glb")
	_at.x = clampf(_at.x + lineup_x(5.0), _MIN.x, _MAX.x)
	_tire = _spawn("res://assets/minigames/ice_tire.glb", _at.x, _at.y, 0.0)
	if _tire == null:
		_tire = _box(Vector3(3.0, 0.6, 3.0), Color(0.2, 0.2, 0.25))
		add_child(_tire)
	_make_toon(_panda(_at.x, _at.y, 1.6))
	_arrow = _box(Vector3(0.25, 0.2, 1.0), Color(1.0, 0.25, 0.2))
	_tire.add_child(_arrow)
	_arrow.position = Vector3(0, 0.4, -1.2)
	_place_round_props(true)
	var layer := CanvasLayer.new()
	layer.layer = 21
	add_child(layer)
	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 64
	_banner.offset_bottom = 150
	_banner.offset_left = -460
	_banner.offset_right = 460
	_banner.add_theme_font_size_override("font_size", 28)
	_banner.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	layer.add_child(_banner)
	_paint_banner()
	show_board("points")
	_aim_camera()


func _play(delta: float) -> void:
	if _phase == "aim":
		_aim_step(delta)
	elif _phase == "slide":
		_slide(delta)
	elif _phase == "pause":
		_aim_left -= delta
		if _aim_left <= 0.0:
			_next_launch()
	_toon.position = _panda(_at.x, _at.y, 1.6)
	_toon.rotation = _tire.rotation
	_toon.set_locomotion(0.0, false, false, delta)
	if _tire != null:
		_tire.position = _panda(_at.x, _at.y, 0.0)
	_aim_camera()


func _aim_step(delta: float) -> void:
	_aim_left -= delta
	var move := _stick()
	var up := move.y > 0.2 and move.y >= absf(move.x)
	var down := move.y < -0.2 and absf(move.y) >= absf(move.x)
	var left := move.x < -0.2 and absf(move.x) > absf(move.y)
	var right := move.x > 0.2 and absf(move.x) > absf(move.y)
	if up:
		_force_momentum = minf(_force_momentum + delta * 160.0, 50.0)
		_force += _force_momentum * delta
		_sfx_once("MG_sfx_ice_force_increase_3sec")
	elif down:
		_force_momentum = minf(_force_momentum + delta * 160.0, 50.0)
		_force -= _force_momentum * delta
		_sfx_once("MG_sfx_ice_force_decrease_3sec")
	else:
		_force_momentum = 0.0
		if not left and not right:
			_sfx_name = ""
	if left:
		_head_momentum = minf(_head_momentum + delta * 60.0, 50.0)
		_heading += _head_momentum * delta
		_sfx_once("MG_sfx_ice_force_rotate")
	elif right:
		_head_momentum = minf(_head_momentum + delta * 60.0, 50.0)
		_heading -= _head_momentum * delta
		_sfx_once("MG_sfx_ice_force_rotate")
	else:
		_head_momentum = 0.0
	_force = clampf(_force, 0.01, 100.0)
	_face_tire()
	if _arrow != null:
		var reach := 0.6 + _force / 100.0 * 3.4
		_arrow.scale = Vector3(1.0, 1.0, reach)
		_arrow.position = Vector3(0, 0.45, -0.6 - reach * 0.5)
	if not _warned and _aim_left < 12.0:
		_warned = true
		_banner.text = "Match %d/%d, Round %d/%d\nRemember to press the Ctrl key!" % [_match + 1, _MATCHES, _round + 1, _ROUNDS]
	if Keybinds.held("jump"):
		_launch()
	elif _aim_left <= 0.0:
		_force = 0.01
		_launch()


func _launch() -> void:
	var rad := deg_to_rad(_heading + 90.0)
	var dir := Vector2(cos(rad), sin(rad))
	_vel = dir * (_force / 100.0) * 28.0
	_phase = "slide"
	_banner.text = "Match %d/%d, Round %d/%d" % [_match + 1, _MATCHES, _round + 1, _ROUNDS]


func _slide(delta: float) -> void:
	var speed := _vel.length()
	if speed < 0.35:
		_vel = Vector2.ZERO
		_phase = "pause"
		_aim_left = 1.2
		return
	var drop := 12.0 * delta
	_vel = _vel.normalized() * maxf(speed - drop, 0.0)
	_at += _vel * delta
	if _at.x < _MIN.x or _at.x > _MAX.x:
		_at.x = clampf(_at.x, _MIN.x, _MAX.x)
		_vel.x = -_vel.x * 0.45
	if _at.y < _MIN.y or _at.y > _MAX.y:
		_at.y = clampf(_at.y, _MIN.y, _MAX.y)
		_vel.y = -_vel.y * 0.45
	_bounce_obstacles()
	_collect()
	_face_tire()


func _bounce_obstacles() -> void:
	for spot in _obstacles:
		var away := _at - spot
		var reach := 3.0 if _round_obs else 2.2
		if away.length() > reach or away.length() < 0.001:
			continue
		var normal := away.normalized()
		_at = spot + normal * reach
		if _vel.dot(normal) < 0.0:
			_vel = _vel.bounce(normal) * 0.5


func _collect() -> void:
	for item in _treasures:
		if bool(item["gone"]):
			continue
		var spot: Vector2 = item["at"]
		if _at.distance_to(spot) > 2.2:
			continue
		item["gone"] = true
		(item["node"] as Node3D).visible = false
		score += 1
		_sfx("SZ_DD_treasure")
	for item in _penalties:
		if bool(item["gone"]):
			continue
		var spot: Vector2 = item["at"]
		if _at.distance_to(spot) > 2.2:
			continue
		item["gone"] = true
		(item["node"] as Node3D).visible = false
		score -= 1
		_sfx("MG_neg_buzzer")


func _next_launch() -> void:
	if _round + 1 < _ROUNDS:
		_round += 1
		_begin_aim()
		return
	var length := _at.length()
	var points := length / _FARTHEST * (1.0 - 5.0) + 5.0
	score += int(points + 0.5)
	_match += 1
	if _match >= _MATCHES:
		_phase = "done"
		_banner.text = "Finish!"
		_aim_left = 1.4
		return
	_round = 0
	_at = Vector2(-17.5, -12.5)
	_heading = 45.0
	_place_round_props(true)
	_begin_aim()


func _process(delta: float) -> void:
	_place_tags()
	if _phase == "done":
		_aim_left -= delta
		if _aim_left <= 0.0:
			_phase = "over"
			_end()
		return
	super._process(delta)


func _begin_aim() -> void:
	_phase = "aim"
	_aim_left = 15.0
	_warned = false
	_force = 0.01
	_force_momentum = 0.0
	_head_momentum = 0.0
	_vel = Vector2.ZERO
	_paint_banner()


func _place_round_props(fresh: bool) -> void:
	for node in _props:
		if is_instance_valid(node):
			node.queue_free()
	_props.clear()
	_treasures.clear()
	_penalties.clear()
	_obstacles.clear()
	if not fresh:
		return
	_round_obs = _hood != 3000 and _hood != 9000
	for spot in _obstacle_spots():
		_obstacles.append(spot)
		var crate := _spawn("res://assets/minigames/ice_crate.glb", spot.x, spot.y, 0.0)
		if crate == null:
			crate = _box(Vector3(2.0, 2.0, 2.0), Color(0.55, 0.32, 0.16))
			add_child(crate)
			crate.position = _panda(spot.x, spot.y, 1.0)
		_props.append(crate)
	for _i in range(_treasure_count()):
		var spot := _open_spot()
		var node := _spawn("res://assets/minigames/ice_barrel.glb", spot.x, spot.y, 0.0)
		if node == null:
			node = _box(Vector3(1.4, 1.6, 1.4), Color(0.45, 0.28, 0.12))
			add_child(node)
			node.position = _panda(spot.x, spot.y, 0.8)
		_props.append(node)
		_treasures.append({"node": node, "at": spot, "gone": false})
	for _i in range(_penalty_count()):
		var spot := _open_spot()
		var node := _spawn("res://assets/minigames/ice_tnt.glb", spot.x, spot.y, 0.0)
		if node == null:
			node = _box(Vector3(1.1, 1.1, 1.1), Color(0.15, 0.15, 0.15))
			add_child(node)
			node.position = _panda(spot.x, spot.y, 0.6)
		_props.append(node)
		_penalties.append({"node": node, "at": spot, "gone": false})


func _open_spot() -> Vector2:
	for _try in range(12):
		var spot := Vector2(shared_float(-12.0, 12.0), shared_float(-8.0, 8.0))
		if spot.length() < 3.0:
			continue
		var clear := true
		for other in _obstacles:
			if other.distance_to(spot) < 4.0:
				clear = false
		if clear:
			return spot
	return Vector2(shared_float(-8.0, 8.0), shared_float(-6.0, 6.0))


func _treasure_count() -> int:
	if _hood == 3000 or _hood == 9000:
		return 1
	return 2


func _penalty_count() -> int:
	if _hood == 3000 or _hood == 9000:
		return 2
	if _hood == 2000:
		return 0
	return 1


func _obstacle_spots() -> Array[Vector2]:
	if _hood == 1000:
		return [Vector2(0, 0)]
	if _hood == 5000:
		return [Vector2(-10, 0), Vector2(10, 0)]
	if _hood == 4000:
		return [Vector2(0, -7.5), Vector2(0, 7.5)]
	if _hood == 3000:
		return [Vector2(-10, 0), Vector2(10, 0), Vector2(0, -7.5), Vector2(0, 7.5)]
	if _hood == 9000:
		return [Vector2(-10, -7.5), Vector2(-10, 7.5), Vector2(10, -7.5), Vector2(10, 7.5)]
	return []


func _face_tire() -> void:
	var rad := deg_to_rad(_heading + 90.0)
	var dir := Vector2(cos(rad), sin(rad))
	var ahead := _tire.position + Vector3(dir.x, 0.0, -dir.y)
	if ahead.distance_squared_to(_tire.position) < 0.0001:
		return
	_tire.look_at(ahead, Vector3.UP)


func _aim_camera() -> void:
	_camera.position = _panda(0.0, -22.0, 28.0)
	_camera.look_at(_panda(_at.x * 0.4, _at.y * 0.4, 0.0), Vector3.UP)


func _paint_banner() -> void:
	_banner.text = "Match %d/%d, Round %d/%d" % [_match + 1, _MATCHES, _round + 1, _ROUNDS]


var _sfx_name := ""


func _sfx_once(file_name: String) -> void:
	if _sfx_name == file_name:
		return
	_sfx_name = file_name
	_sfx(file_name, 0.7)
