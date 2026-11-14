extends Node3D

## Jellybean trampoline. Control jumps. The boost is strongest at the bottom
## of the bounce. Twelve beans sit from 20 to 90. The top one adds 10 more.
## The round lasts TrampolineDuration, 60 seconds.

signal finished(base_beans: int, message: String)

const _SURFACE := 3.6
const _SPRING := 400.0
const _DAMP := 2.5
const _GRAVITY := -32.0
const _JUMP := 330.0
const _FIRST := 500.0
const _BEANS := 12
const _BONUS := 10
const _LENGTH := 60.0

var _player: ToonActor
var _origin := Vector3.ZERO
var _height := 3.6
var _vel := 0.0
var _jumped := false
var _peak := 0.0
var _top := 0.0
var _left := 60.0
var _got: Array[bool] = []
var _beans: Array[Node3D] = []
var _heights: Array[float] = []
var _count := 0
var _big := false
var _note: Label
var _done := false
var _heading := 0.0


func setup(player: ToonActor, origin: Vector3, _party: Dictionary) -> void:
	_player = player
	_origin = origin
	_got.resize(_BEANS)
	_got.fill(false)
	var step := (90.0 - 20.0) / float(_BEANS - 1)
	for index in _BEANS:
		var height := 20.0 + step * float(index)
		_heights.append(height)
		var bean := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 1.6 if index < _BEANS - 1 else 3.2
		mesh.height = mesh.radius * 2.0
		bean.mesh = mesh
		var shade := StandardMaterial3D.new()
		shade.albedo_color = Color(0.95, 0.35, 0.45) if index < _BEANS - 1 else Color(0.2, 0.85, 0.35)
		shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bean.material_override = shade
		bean.position = Vector3(0.0, height, 0.0)
		add_child(bean)
		_beans.append(bean)
	global_position = origin
	_player.global_position = origin + Vector3(0.0, _SURFACE, 0.0)
	_banner()


func holds_camera() -> bool:
	return not _done


func aim(camera: Camera3D) -> void:
	if _player == null:
		return
	camera.global_position = _player.global_position + Vector3(0.0, 8.0, 28.0)
	camera.look_at(_player.global_position + Vector3(0.0, 2.0, 0.0), Vector3.UP)


func _process(delta: float) -> void:
	if _done or _player == null:
		return
	_left -= delta
	if Keybinds.held("jump") and _height <= _SURFACE + 0.4:
		_jumped = true
	var turn := 0.0
	if Keybinds.held("left") or Input.is_physical_key_pressed(KEY_LEFT):
		turn += 1.0
	if Keybinds.held("right") or Input.is_physical_key_pressed(KEY_RIGHT):
		turn -= 1.0
	_heading += turn * 120.0 * delta
	_player.rotation_degrees.y = _heading
	var remain := delta
	while remain > 0.0:
		var step := minf(remain, 0.002)
		_step(step)
		remain -= step
	_player.global_position = _origin + Vector3(0.0, _height, 0.0)
	_player.set("velocity", Vector3.ZERO)
	_collect()
	_note.text = "Jelly Beans Trampoline\nControl jumps. Back hops off.\n%d ft    Beans %d    %d:%02d" % [int(_top), _count, int(_left) / 60, int(_left) % 60]
	if _left <= 0.0 or (_left < 59.2 and Keybinds.held("back")):
		_finish()


func _step(step: float) -> void:
	var accel := _GRAVITY
	if _height < _SURFACE:
		accel = _GRAVITY + _SPRING * (_SURFACE - _height) - _DAMP * _vel
		if _jumped and (_peak > 75.0 or _vel >= -300000.0):
			accel += _JUMP
			if _peak < _SURFACE + 1.5:
				accel += _FIRST
	else:
		_jumped = false
	var before := _vel
	_vel += accel * step
	if before > 0.0 and _vel <= 0.0:
		_peak = _height
	_height += _vel * step
	if _height > _top:
		_top = _height
	if _height < 0.2:
		_height = 0.2
		_vel = absf(_vel) * 0.2


func _collect() -> void:
	for index in _BEANS:
		if _got[index]:
			continue
		if _height < _heights[index]:
			continue
		_got[index] = true
		_count += 1
		if index == _BEANS - 1:
			_big = true
		_beans[index].visible = false


func _finish() -> void:
	var beans := _count
	if _big:
		beans += _BONUS
	_player.global_position = _origin + Vector3(4.0, 0.2, 0.0)
	_player.set("velocity", Vector3.ZERO)
	_done = true
	var line := "You collected %d jellybeans."
	if _big:
		line = "You collected %d jellybeans, including 10 more for the Big Bean."
	finished.emit(beans, line)
	queue_free()


func _banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_note = Label.new()
	_note.position = Vector2(40, 40)
	_note.size = Vector2(760, 140)
	ToonGui.style_label(_note, Color.WHITE, 28, Color(0.1, 0.05, 0.2), 4)
	layer.add_child(_note)
