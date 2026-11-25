extends "res://scenes/trolley/trolley_minigame.gd"

## Toon Slingshot. Pound left and right to build power, pause to launch, then
## hold down for the umbrella and steer onto a colored target. The best landing
## is kept across the three rounds.

const _RED := Color(1.0, 0.0, 0.0, 0.5)
const _GREEN := Color(0.0, 1.0, 0.0, 0.5)
const _BLUE := Color(0.0, 0.0, 1.0, 0.5)
const _YELLOW := Color(1.0, 1.0, 0.0, 0.5)
const _PURPLE := Color(0.75, 0.0, 1.0, 0.5)
const _ORANGE := Color(1.0, 0.6, 0.0, 0.5)
const _FIELD_W := 450.0
const _FIELD_L := 1110.0
const _MAX_X := 135.0
const _MAX_Y := 900.0
const _GRAVITY := 12.5
const _FALL_GRAVITY := 4.0
const _STALL := 30.0
const _AIR := 0.1
const _CHUTE := 0.11
const _STEER := 15.0
const _TRAMP_Z := 3.6

var _counts: Array[int] = [8, 4, 2, 0]
var _values: Array[int] = [10, 16, 21, 28]
var _sizes: Array[float] = [31.0, 15.0, 7.0, 3.5]
var _colors: Array[Color] = [_RED, _GREEN, _BLUE, _YELLOW]
var _parts: Array[int] = [2, 2, 2, 1]
var _jump_size := 10.0
var _jump_num := 2
var _rings: Array[Dictionary] = []
var _tramps: Array[Dictionary] = []
var _phase := "pound"
var _x := 10.0
var _y := 0.0
var _z := 1.0
var _home_x := 10.0
var _power := 10.0
var _stretch := 10.0
var _aim_x := 0.0
var _speed := 0.0
var _side := 0.0
var _vz := 0.0
var _drift_x := 0.0
var _drift_y := 0.0
var _can_left := true
var _can_right := true
var _pressed_at := -1.0
var _ticker := 0.0
var _clock := 10
var _clock_left := 1.0
var _force := false
var _on_tramp := false
var _bounces := 0
var _butt := false
var _round := 1
var _score_left := 0.0
var _rubber: AudioStreamPlayer
var _flutter: AudioStreamPlayer
var _open: Node3D
var _closed: Node3D
var _chute: Node3D
var _sling: Node3D
var _band: MeshInstance3D
var _help: Label
var _count: Label
var _bar: ColorRect
var _bar_back: ColorRect
var _seated := false
var _chute_basis := Basis.IDENTITY
var _chute_ready := false


func _init() -> void:
	title = "Toon Slingshot"
	instructions = "Land on targets to score points"
	duration = 180.0


func _build() -> void:
	_pattern()
	_desert()
	_lay_targets()
	_home_x = _line()
	_x = _home_x
	_make_toon(_panda(_x, 0.0, 1.0))
	_toon.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	_sling = _spawn("res://assets/minigames/slingshot_sling.glb", _home_x, 10.0, 0.0)
	_band = MeshInstance3D.new()
	_band.name = "RubberBand"
	var band_mat := StandardMaterial3D.new()
	band_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	band_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	band_mat.vertex_color_use_as_albedo = true
	_band.material_override = band_mat
	add_child(_band)
	_chute = _spawn("res://assets/minigames/umbrella.glb", _x, 0.0, 1.0)
	if _chute != null:
		_open = _chute.find_child("open_umbrella", true, false) as Node3D
		_closed = _chute.find_child("closed_umbrella", true, false) as Node3D
		_show_chute(false)
	_camera.fov = 80.0
	_camera.far = 700.0
	_sky()
	_rubber = _loop_sfx("target_stretching_aim_loop", 0.05)
	_loop_sfx("target_wind_fly_loop", 0.12)
	_make_hud()
	_enter_pound()
	show_board("slingshot")


func _play(delta: float) -> void:
	var phase := _phase
	if phase == "pound":
		_pound(delta)
	elif phase == "score":
		_score_left -= delta
		_watch()
		_place_help()
		if _score_left <= 0.0:
			if _round >= 3:
				_end()
			else:
				_round += 1
				_enter_pound()
		return
	else:
		_fly(delta, phase)
	_put_toon()
	_watch()
	_place_help()


func _pattern() -> void:
	match int(_RIDE.hood):
		1000:
			_counts = [7, 4, 2, 0]
			_values = [11, 17, 23, 32]
			_sizes = [29.0, 13.0, 6.5, 3.2]
			_colors = [_RED, _GREEN, _BLUE, _YELLOW]
			_jump_size = 9.0
		5000:
			_counts = [6, 4, 2, 0]
			_values = [11, 18, 25, 34]
			_sizes = [29.0, 13.0, 6.5, 3.1]
			_colors = [_RED, _GREEN, _BLUE, _YELLOW]
			_jump_size = 8.0
		4000:
			_counts = [6, 4, 2, 0]
			_values = [12, 19, 27, 37]
			_sizes = [28.0, 12.0, 6.0, 3.0]
			_colors = [_GREEN, _BLUE, _YELLOW, _PURPLE]
			_jump_size = 8.0
		3000:
			_counts = [5, 4, 2, 0]
			_values = [12, 20, 29, 40]
			_sizes = [25.0, 12.0, 5.5, 2.5]
			_colors = [_GREEN, _BLUE, _YELLOW, _PURPLE]
			_jump_size = 7.0
		9000:
			_counts = [4, 3, 1, 0]
			_values = [12, 21, 31, 42]
			_sizes = [20.0, 10.0, 4.5, 2.0]
			_colors = [_BLUE, _YELLOW, _PURPLE, _ORANGE]
			_jump_size = 7.0
		_:
			_counts = [8, 4, 2, 0]
			_values = [10, 16, 21, 28]
			_sizes = [31.0, 15.0, 7.0, 3.5]
			_colors = [_RED, _GREEN, _BLUE, _YELLOW]
			_jump_size = 10.0


func _desert() -> void:
	_hide_floor()
	var path := "res://assets/minigames/slingshot_desert.glb"
	for row in range(-1, 5):
		var along := 300.0 * float(row)
		_place_tile(path, 0.0, along, row, 0)
		for side in [-1, 1]:
			for band in range(1, 4):
				_place_tile(path, float(side * band) * 150.0, along, row, side * band)


func _place_tile(path: String, x: float, y: float, row: int, column: int) -> void:
	var tile := _spawn(path, x, y, 0.0)
	if tile == null:
		return
	_hide_named(tile, "cloud_layer1")
	_hide_named(tile, "backdrop_layer1")
	_hide_named(tile, "mountain_set_b")
	_hide_named(tile, "mountain_c")
	var sky := _named(tile, "blue_sky_layer1")
	if sky != null:
		sky.position = Vector3(0.0, 0.0, 76.0)
		_both_sides(sky)
	var cloud := _named(tile, "cloud_layer_alpha")
	if cloud != null:
		cloud.position = Vector3(0.0, 0.0, 63.0)
		cloud.basis = _sling_hpr(0.0, 0.0, 180.0)
		_both_sides(cloud)
		var low := cloud.duplicate() as Node3D
		cloud.get_parent().add_child(low)
		low.position = Vector3(0.0, 0.0, 50.0)
		low.basis = _sling_hpr(0.0, 0.0, 180.0)
	var slot := absi(column)
	if slot == 3:
		_hide_named(tile, "sand_layer1")
	if slot != 2:
		return
	var which := "mountain_set_b" if column < 0 else "mountain_c"
	var mount := _named(tile, which)
	if mount == null:
		return
	mount.visible = true
	_hide_named(mount, "sand_b")
	_hide_named(mount, "sand_c")
	var height := 6.0 + float(absi(row * 3 + column) % 5)
	mount.position.x += 8.5 if column < 0 else -8.5
	var heading := 0.0
	var wide := Vector3(1.0, 1.1, height)
	if row >= 3:
		wide = Vector3(1.0, 1.5, height * 1.2)
		mount.position.x += -2.0 if column < 0 else 2.0
		heading = 310.0 if column < 0 else 50.0
		if row == 4:
			mount.visible = false
	elif row == -1:
		wide = Vector3(1.0, 1.5, height * 1.2)
		mount.position.x += 5.0 if column < 0 else -5.0
		mount.position.y += 3.0
		heading = 50.0 if column < 0 else 310.0
	if heading != 0.0:
		mount.basis = _sling_hpr(heading, 0.0, 0.0)
	mount.scale = wide


func _named(root: Node, node_name: String) -> Node3D:
	return root.find_child(node_name, true, false) as Node3D


func _hide_named(root: Node, node_name: String) -> void:
	var node := _named(root, node_name)
	if node != null:
		node.visible = false


func _both_sides(node: Node3D) -> void:
	if not node is MeshInstance3D:
		return
	var mesh_node := node as MeshInstance3D
	var source := mesh_node.get_active_material(0) as StandardMaterial3D
	if source == null:
		return
	var paint := source.duplicate() as StandardMaterial3D
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_node.material_override = paint


func _sling_hpr(heading: float, pitch: float, roll: float) -> Basis:
	var turn := Quaternion(Vector3(0, 0, 1), deg_to_rad(heading))
	var tilt := Quaternion(Vector3(1, 0, 0), deg_to_rad(pitch))
	var twist := Quaternion(Vector3(0, 1, 0), deg_to_rad(roll))
	return Basis(turn * tilt * twist)


func _lay_targets() -> void:
	var placed: Array[Dictionary] = []
	var highest := 0
	for value in _values:
		if value > highest:
			highest = value
	var bias := 0.5
	if highest > 0:
		bias = float(highest) * 0.5 / float(highest)
	for type_index in _counts.size():
		for _copy in _counts[type_index]:
			var fill := _sizes[type_index]
			var spot := _find_spot(fill, placed, bias)
			if spot == Vector2.INF:
				continue
			placed.append({"x": spot.x, "y": spot.y, "fill": fill})
			var drawn: Array[int] = []
			var sub := _parts[type_index]
			while sub > 0:
				drawn.append(type_index + sub - 1)
				sub -= 1
			drawn.sort()
			for combined in drawn:
				_disc(spot.x, spot.y, _sizes[combined], _colors[combined], 0.04 + float(combined) * 0.02)
				_rings.append({
					"x": spot.x,
					"y": spot.y,
					"radius": _sizes[combined],
					"value": _values[combined],
				})
	for _jump in _jump_num:
		var spot := _find_spot(_jump_size, placed, bias)
		if spot == Vector2.INF:
			continue
		placed.append({"x": spot.x, "y": spot.y, "fill": _jump_size})
		var lat := _jump_size / 6.8
		var pad := _spawn("res://assets/minigames/trampoline.glb", spot.x, spot.y, 0.05)
		if pad != null:
			pad.scale = Vector3(lat, 1.0, lat)
			var shadow := pad.find_child("tramp_shadow", true, false) as Node3D
			if shadow != null:
				shadow.visible = false
		_disc(spot.x, spot.y, _jump_size + 0.5, Color(0.0, 0.0, 0.0, 0.25), 0.03)
		_tramps.append({"x": spot.x, "y": spot.y, "radius": _jump_size})
	var plants: PackedStringArray = ["res://assets/minigames/cactus.glb"]
	if ResourceLoader.exists("res://assets/minigames/cactus_b.glb"):
		plants.append("res://assets/minigames/cactus_b.glb")
	for _plant in 30:
		var cactus_x := shared_float(-_FIELD_W * 0.375, _FIELD_W * 0.375)
		var cactus_y := 5.0 + shared_float(0.0, 1.0) * (_FIELD_L - 5.0)
		var which := plants[shared_int(plants.size())] if plants.size() > 1 else plants[0]
		var cactus := _spawn(which, cactus_x, cactus_y, 0.0, shared_float(0.5, 1.5))
		if cactus != null:
			cactus.rotation_degrees.y = shared_float(0.0, 360.0)


func _find_spot(fill: float, placed: Array[Dictionary], bias: float) -> Vector2:
	for _try in 40:
		var x := shared_float(0.0, 1.0) * (_FIELD_W * 0.6) - _FIELD_W * 0.3
		var y := (shared_float(0.0, 1.0) * 0.6 + 0.4 * bias) * _FIELD_L
		if _clear(x, y, fill, placed):
			return Vector2(x, y)
	return Vector2.INF


func _clear(x: float, y: float, fill: float, placed: Array[Dictionary]) -> bool:
	for spot in placed:
		var dx := float(spot["x"]) - x
		var dy := float(spot["y"]) - y
		if sqrt(dx * dx + dy * dy) - (fill + float(spot["fill"])) <= 0.0:
			return false
	return true


func _disc(x: float, y: float, radius: float, color: Color, height: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.06
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = mat
	add_child(ring)
	ring.position = _panda(x, y, height)


func _pound(delta: float) -> void:
	var left := Keybinds.held("left") or Input.is_physical_key_pressed(KEY_LEFT)
	var right := Keybinds.held("right") or Input.is_physical_key_pressed(KEY_RIGHT)
	if not right:
		_can_right = true
	elif _can_right:
		_can_right = false
		_boost()
	if not left:
		_can_left = true
	elif _can_left:
		_can_left = false
		_boost()
	var slide := 0.0
	if left:
		slide -= _STEER
	if right:
		slide += _STEER
	_aim_x = clampf(_aim_x + slide * delta, -5.0, 5.0)
	_clock_left -= delta
	if _clock_left <= 0.0:
		_clock -= 1
		_clock_left = 1.0
		if _clock < 0:
			_force = true
	var since := 1000.0
	if _pressed_at >= 0.0:
		since = _age() - _pressed_at
		_ticker += delta
		if _ticker >= 0.1:
			_ticker = 0.0
			var scaled := _power * 0.05
			_power -= 1.0 + 0.2 * scaled * scaled
	if _force:
		since = 1000.0
	if _force or (_pressed_at >= 0.0 and since > 0.5):
		_launch()
		return
	_stretch = lerpf(_stretch, _power, 0.1)
	_x = _home_x - _aim_x
	_y = -_stretch * 0.12
	_paint_power()
	if _rubber != null:
		_rubber.volume_db = linear_to_db(maxf(clampf(_power / 140.0, 0.02, 0.7), 0.001))
	if not _seated and _toon != null and _toon.gesture_finished():
		_toon.play_gesture("sit", 1.0, true)
		_seated = true
	_help.text = "Pound left and right arrows for power, stop to launch"
	_count.text = "Forced launch in %d seconds" % maxi(_clock, 0)


func _boost() -> void:
	var now := _age()
	if _pressed_at < 0.0:
		_pressed_at = now
		_ticker = 0.0
		return
	var gap := maxf(absf(now - _pressed_at), 0.01)
	_power += 0.6 / gap + 5.0
	_pressed_at = now
	_sfx("target_stretching_aim_loop", 0.35)


func _launch() -> void:
	if _power > 120.0:
		_power = 120.0
	if _power < 40.0:
		_power = 40.0
	_phase = "fly"
	_speed = _power
	_side = -_aim_x * 7.0
	_vz = _speed * 0.5
	_y = 0.0
	_z = 1.0
	_x = _home_x
	_drift_x = 0.0
	_drift_y = 0.0
	_bounces = 0
	_butt = false
	_show_chute(false)
	if _bar_back != null:
		_bar_back.visible = false
		_bar.visible = false
		_count.visible = false
	if _rubber != null:
		_rubber.stop()
	_toon.set_swimming(true)
	_sfx("target_launch")
	_help.text = "Press down to open umbrella"


func _fly(delta: float, phase: String) -> void:
	var drag := _CHUTE if phase == "fall" else _AIR
	_speed -= _speed * drag * delta
	_side -= _side * drag * delta
	if phase == "fall" and _z > 350.0:
		_speed += -(_z - 350.0) * delta * 0.05
	_y += _speed * delta
	if _y > _MAX_Y:
		_y = _MAX_Y
	if phase == "fall" or phase == "bounce":
		if _y < 15.0:
			_y = 15.0
	_on_tramp = _tramp_here()
	var lift_mult := 0.0
	if phase == "fly":
		_x += _side * delta
		if _stick().y < -0.5:
			_enter_fall()
	elif phase == "fall":
		_drift_x = clampf(_drift_x, -_STEER, _STEER)
		_drift_y = clampf(_drift_y, -_STEER, _STEER)
		var move := _stick()
		_drift_x += move.x * _STEER * delta
		_drift_y += move.y * _STEER * delta
		_x += _drift_x * delta
		_y += _drift_y * delta
		lift_mult = 1.0
	elif phase == "bounce":
		_x += _drift_x * delta
		_y += _drift_y * delta
	_x = clampf(_x, -_MAX_X, _MAX_X)
	var lift := (_speed - _STALL) / _STALL * lift_mult
	if lift < 0.0:
		lift = 0.0
	var gravity := _FALL_GRAVITY if phase == "fall" else _GRAVITY
	_vz += (lift - gravity) * delta
	_z += _vz * delta
	if _z < _TRAMP_Z and _on_tramp:
		_bounce_tramp()
	elif _z < 0.1:
		_bounce_ground(phase)


func _bounce_tramp() -> void:
	if _bounces == 0:
		_sfx("target_trampoline_2")
	var rebound := 0.75
	if _bounces >= 1:
		rebound = 0.5
		if _phase != "bounce":
			_enter_bounce()
	_z = _TRAMP_Z
	var sign_z := 1.0 if _vz >= 0.0 else -1.0
	_vz = -(_vz * rebound - sign_z)
	_bounces += 1
	if absf(_vz) < 1.0:
		_vz = 0.0
		_enter_score()


func _bounce_ground(phase: String) -> void:
	if phase == "fly" or phase == "fall":
		if _phase != "bounce":
			_enter_bounce()
	if phase == "fly":
		_butt = true
		_toon.set_swimming(false)
		_toon.play_gesture("slip-forward", 1.0, false)
		_sfx("target_impact_grunt1")
		_sfx("target_impact_only")
	elif phase == "fall" or phase == "bounce":
		if absf(_vz) > 6.0:
			_toon.play_gesture("land", 1.0, false)
			_sfx("target_impact_only")
	_z = 0.1
	var sign_z := 1.0 if _vz >= 0.0 else -1.0
	_vz = -(_vz * 0.5 - sign_z)
	_speed *= 0.5
	_drift_x *= 0.5
	_drift_y *= 0.5
	if absf(_vz) < 1.0 and (phase == "fly" or phase == "bounce"):
		_vz = 0.0
		_enter_score()


func _tramp_here() -> bool:
	for pad in _tramps:
		var dx := float(pad["x"]) - _x
		var dy := float(pad["y"]) - _y
		var radius := float(pad["radius"])
		if dx * dx + dy * dy < radius * radius:
			return true
	return false


func _enter_pound() -> void:
	_phase = "pound"
	_power = 10.0
	_stretch = 10.0
	_aim_x = 0.0
	_speed = 0.0
	_side = 0.0
	_vz = 0.0
	_drift_x = 0.0
	_drift_y = 0.0
	_y = 0.0
	_z = 1.0
	_x = _home_x
	_can_left = true
	_can_right = true
	_pressed_at = -1.0
	_ticker = 0.0
	_clock = 10
	_clock_left = 1.0
	_force = false
	_bounces = 0
	_butt = false
	_seated = false
	_show_chute(false)
	if _toon != null:
		_toon.set_swimming(false)
		_toon.play_gesture("sit-start", 1.0, false)
	if _rubber != null and not _rubber.playing:
		_rubber.play()
	if _bar_back != null:
		_bar_back.visible = true
		_bar.visible = true
		_count.visible = true
	if _board != null:
		_board.visible = false
	_paint_power()


func _enter_fall() -> void:
	if _phase == "fall":
		return
	_phase = "fall"
	_speed *= 0.5
	_show_chute(true)
	_toon.set_swimming(false)
	_toon.play_gesture("jump", 1.0, true)
	_flutter = _loop_sfx("target_wind_float_clothloop", 0.45)
	_sfx("target_chute")
	_help.text = "Use the arrow keys to land on target"


func _enter_bounce() -> void:
	_phase = "bounce"
	_show_chute(false)
	if _flutter != null:
		_flutter.stop()
	_help.text = " Bouncing can knock you off target"


func _enter_score() -> void:
	if _phase == "score":
		return
	_phase = "score"
	_vz = 0.0
	_show_chute(false)
	if _flutter != null:
		_flutter.stop()
	_toon.set_swimming(false)
	var landed := _best_landing()
	if landed > score:
		score = landed
	if _board != null:
		_board.show_round(_round, score, true)
	if landed <= 1:
		_toon.play_gesture("sad-neutral", 1.0, true)
		_sfx("target_Lose", 0.8)
	else:
		_toon.play_gesture("victory", 1.0, true)
		_sfx("target_happydance", 0.8)
	_mark(landed)
	_score_left = 4.0
	_help.text = ""


func _best_landing() -> int:
	var best := 0
	for ring in _rings:
		var dx := float(ring["x"]) - _x
		var dy := float(ring["y"]) - _y
		var radius := float(ring["radius"])
		if dx * dx + dy * dy < radius * radius and int(ring["value"]) > best:
			best = int(ring["value"])
	return best


func _mark(landed: int) -> void:
	if landed <= 1:
		return
	for ring in _rings:
		if int(ring["value"]) != landed:
			continue
		var dx := float(ring["x"]) - _x
		var dy := float(ring["y"]) - _y
		if dx * dx + dy * dy < float(ring["radius"]) * float(ring["radius"]):
			_disc(float(ring["x"]), float(ring["y"]), float(ring["radius"]) + 0.6, Color(1, 1, 1, 0.85), 0.2)
			return


func _show_chute(open: bool) -> void:
	if _chute == null or _toon == null:
		return
	_chute.visible = true
	if not _chute_ready:
		_chute_basis = _chute.basis
		_chute_ready = true
		if _open != null:
			_open.position = Vector3(0.1, 0.2, -0.1)
			_open.basis = _sling_hpr(-90.0, 0.0, 15.0)
		if _closed != null:
			_closed.basis = _sling_hpr(0.0, 100.0, 35.0)
	if _open != null:
		_open.visible = open
	if _closed != null:
		_closed.visible = not open
	var hand := _toon.find_child("def_joint_right_hold", true, false) as Node3D
	if hand != null and _chute.get_parent() != hand:
		_chute.reparent(hand)
	_chute.position = Vector3.ZERO
	if open:
		_chute.basis = _chute_basis * _sling_hpr(0.0, 180.0, -25.0)
		_chute.scale = Vector3.ONE * 1.5
	else:
		_chute.basis = _chute_basis
		_chute.scale = Vector3.ONE


func _put_toon() -> void:
	_toon.position = _panda(_x, _y, _z)
	_toon.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	_draw_band()


func _watch() -> void:
	if _phase == "pound":
		_aim_cam(_home_x, 0.0, 1.0, 25.0, 7.0, -15.0, 0.0)
	elif _phase == "fly":
		_aim_cam(_x, _y, _z, 13.0, 5.0, -15.0, 0.0)
	elif _phase == "score":
		_aim_cam(_x, _y, _z, -13.0, 1.0, 10.0, 180.0)
	else:
		_aim_cam(_x, _y, _z, 10.0, 15.0, -68.0, 0.0)


func _aim_cam(anchor_x: float, anchor_y: float, anchor_z: float, back: float, up: float, pitch: float, heading: float) -> void:
	var cam_y := anchor_y - back
	var cam_z := anchor_z + up
	_camera.position = _panda(anchor_x, cam_y, cam_z)
	var heading_rad := deg_to_rad(heading)
	var pitch_rad := deg_to_rad(pitch)
	var level := cos(pitch_rad)
	var look := _panda(
		anchor_x + -sin(heading_rad) * level * 40.0,
		cam_y + cos(heading_rad) * level * 40.0,
		cam_z + sin(pitch_rad) * 40.0
	)
	if _camera.global_position.distance_squared_to(look) > 0.01:
		_camera.look_at(look, Vector3.UP)


func _draw_band() -> void:
	if _band == null:
		return
	_band.visible = _phase == "pound"
	if _phase != "pound":
		return
	var local_y := _y - 10.0 - 1.75
	var held := Vector3(_x, _y - 1.75, _z + 1.5)
	if local_y > 0.0:
		held = Vector3(_home_x, 10.0, 14.0)
		local_y = 0.0
	var thick := clampf(1.0 + local_y / 25.0, 0.2, 1.2)
	var tint := Color(1.0, 0.3, 0.2).lerp(Color(1.0, 0.6, 0.35), clampf(thick, 0.0, 1.0))
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_ribbon(mesh, Vector3(_home_x - 5.5, 10.0, 14.0), held, thick, tint)
	_ribbon(mesh, Vector3(_home_x + 5.5, 10.0, 14.0), held, thick, tint)
	mesh.surface_end()
	_band.mesh = mesh


func _ribbon(mesh: ImmediateMesh, post: Vector3, held: Vector3, thick: float, tint: Color) -> void:
	var post_top := _panda(post.x, post.y, post.z + thick * 0.5)
	var post_bottom := _panda(post.x, post.y, post.z - thick * 0.5)
	var held_top := _panda(held.x, held.y, held.z + thick * 0.5)
	var held_bottom := _panda(held.x, held.y, held.z - thick * 0.5)
	mesh.surface_set_color(tint)
	mesh.surface_add_vertex(post_bottom)
	mesh.surface_add_vertex(post_top)
	mesh.surface_add_vertex(held_bottom)
	mesh.surface_add_vertex(post_top)
	mesh.surface_add_vertex(held_top)
	mesh.surface_add_vertex(held_bottom)


func _paint_power() -> void:
	if _bar == null or _bar_back == null:
		return
	var view := get_viewport().get_visible_rect().size
	var width := view.x * 0.46
	var height := view.y * 0.07
	var origin := Vector2((view.x - width) * 0.5, view.y * 0.78)
	_bar_back.position = origin
	_bar_back.size = Vector2(width, height)
	var fill := clampf(_power / 100.0, 0.0, 1.0) * (width - 10.0)
	_bar.position = origin + Vector2(5.0, 5.0)
	_bar.size = Vector2(fill, height - 10.0)
	_count.position = origin
	_count.size = Vector2(width, height)


func _make_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 25
	add_child(layer)
	_bar_back = ColorRect.new()
	_bar_back.color = Color(0.5, 0.5, 0.5, 0.55)
	layer.add_child(_bar_back)
	_bar = ColorRect.new()
	_bar.color = Color(1.0, 0.0, 0.0, 1.0)
	layer.add_child(_bar)
	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.add_theme_font_size_override("font_size", 22)
	_count.add_theme_color_override("font_color", Color(1, 1, 1))
	layer.add_child(_count)
	_help = Label.new()
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help.add_theme_font_size_override("font_size", 26)
	_help.add_theme_color_override("font_color", Color(1, 1, 1))
	layer.add_child(_help)
	_help.position = Vector2(0.0, 0.0)
	_help.size = Vector2(1600.0, 40.0)


func _place_help() -> void:
	var view := get_viewport().get_visible_rect().size
	_help.position = Vector2(0.0, view.y * 0.70)
	_help.size = Vector2(view.x, 36.0)


func _sky() -> void:
	for child in get_children():
		var world := child as WorldEnvironment
		if world == null or world.environment == null:
			continue
		world.environment.background_color = Color(0.75, 0.8, 1.0)


func _line() -> float:
	var count := float(party_size())
	return float(party_index()) * 14.0 - 14.0 * (count - 1.0) / 2.0 + 10.0


func _age() -> float:
	return Time.get_ticks_msec() / 1000.0
