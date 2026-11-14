extends Node3D

## Party cannons. Aim with the arrows, fire with Control. Clouds pay
## CannonJellyBeanReward (2) each. The party caps that at CannonMaxTotalReward.

signal finished(base_beans: int, message: String)

const _SPEED := 80.0
const _GRAVITY := 32.0
const _YAW_MIN := -55.0
const _YAW_MAX := 50.0
const _PITCH_MIN := 15.0
const _PITCH_MAX := 85.0
const _TURN := 15.0

var _player: ToonActor
var _party: Dictionary = {}
var _origin := Vector3.ZERO
var _yaw := 0.0
var _pitch := 45.0
var _flying := false
var _vel := Vector3.ZERO
var _air := 0.0
var _hits := 0
var _clouds: Array[Node3D] = []
var _used: Dictionary = {}
var _note: Label
var _done := false


func setup(player: ToonActor, origin: Vector3, party: Dictionary) -> void:
	_player = player
	_origin = origin
	_party = party
	global_position = origin
	_player.global_position = origin + Vector3(0.0, 1.4, 0.0)
	_player.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	_banner()
	for index in 8:
		var cloud := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 6.0
		mesh.height = 12.0
		cloud.mesh = mesh
		var shade := StandardMaterial3D.new()
		shade.albedo_color = Color(0.85, 0.9, 0.95)
		shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cloud.material_override = shade
		var angle := deg_to_rad(-50.0 + float(index) * 14.0)
		var reach := 40.0 + float(index % 3) * 22.0
		var height := 22.0 + float(index % 4) * 14.0
		cloud.position = Vector3(sin(angle) * reach, height, -cos(angle) * reach)
		add_child(cloud)
		_clouds.append(cloud)


func holds_camera() -> bool:
	return not _done


func aim(camera: Camera3D) -> void:
	if _player == null:
		return
	if _flying:
		camera.global_position = _player.global_position + Vector3(0.0, 8.0, 22.0)
		camera.look_at(_player.global_position + Vector3(0.0, 2.0, 0.0), Vector3.UP)
		return
	var back := Vector3(sin(deg_to_rad(_yaw)), 0.0, cos(deg_to_rad(_yaw)))
	camera.global_position = _origin + Vector3(0.0, 6.0, 0.0) + back * 18.0
	camera.look_at(_origin + Vector3(0.0, 4.0, 0.0), Vector3.UP)


func _process(delta: float) -> void:
	if _done or _player == null:
		return
	if not _flying:
		_aim_barrel(delta)
		_note.text = "Party Cannons\nArrows aim. Control fires.\nHit the clouds. Each one is worth 2 jellybeans."
		if Keybinds.held("jump") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_launch()
		return
	_air += delta
	_glide(delta)
	_vel.y -= _GRAVITY * delta
	_player.global_position += _vel * delta
	_player.set_swimming(true)
	_player.set_meta("party_fly", true)
	_touch_clouds()
	_note.text = "Clouds hit: %d" % _hits
	if _air > 0.45 and _player.global_position.y <= _origin.y + 1.2 and _vel.y < 0.0:
		_land()


func _aim_barrel(delta: float) -> void:
	var yaw_dir := 0.0
	if Keybinds.held("left") or Input.is_physical_key_pressed(KEY_LEFT):
		yaw_dir += 1.0
	if Keybinds.held("right") or Input.is_physical_key_pressed(KEY_RIGHT):
		yaw_dir -= 1.0
	var pitch_dir := 0.0
	if Keybinds.held("forward") or Input.is_physical_key_pressed(KEY_UP):
		pitch_dir += 1.0
	if Keybinds.held("back") or Input.is_physical_key_pressed(KEY_DOWN):
		pitch_dir -= 1.0
	_yaw = clampf(_yaw + yaw_dir * _TURN * delta, _YAW_MIN, _YAW_MAX)
	_pitch = clampf(_pitch + pitch_dir * _TURN * delta, _PITCH_MIN, _PITCH_MAX)
	_player.rotation_degrees.y = _yaw
	_player.global_position = _origin + Vector3(0.0, 1.4, 0.0)


func _launch() -> void:
	_flying = true
	var rotation := deg_to_rad(_yaw)
	var angle := deg_to_rad(_pitch)
	var horiz := _SPEED * cos(angle)
	var panda := Vector3(horiz * -sin(rotation), horiz * cos(rotation), _SPEED * sin(angle))
	_vel = Vector3(panda.x, panda.z, -panda.y)
	_player.set_meta("party_fly", true)
	_player.set_swimming(true)


func _glide(delta: float) -> void:
	var steer := Vector3.ZERO
	if Keybinds.held("left") or Input.is_physical_key_pressed(KEY_LEFT):
		steer.x -= 1.0
	if Keybinds.held("right") or Input.is_physical_key_pressed(KEY_RIGHT):
		steer.x += 1.0
	if Keybinds.held("forward") or Input.is_physical_key_pressed(KEY_UP):
		steer.z -= 1.0
	if Keybinds.held("back") or Input.is_physical_key_pressed(KEY_DOWN):
		steer.z += 1.0
	_vel += steer * 18.0 * delta


func _touch_clouds() -> void:
	for index in _clouds.size():
		if bool(_used.get(index, false)):
			continue
		var cloud := _clouds[index]
		if _player.global_position.distance_to(cloud.global_position) > 8.0:
			continue
		_used[index] = true
		_hits += 1
		var shade := cloud.material_override as StandardMaterial3D
		if shade != null:
			shade.albedo_color = Color(0.95, 0.55, 0.75)
		var normal := (_player.global_position - cloud.global_position).normalized()
		if normal.length_squared() < 0.01:
			normal = Vector3.UP
		_vel = _vel.bounce(normal) * 0.35
		if _vel.y < 10.0:
			_vel.y = 18.0


func _land() -> void:
	var room := maxi(200 - int(_party.get("cannon", 0)), 0)
	var beans := mini(_hits * 2, room)
	_party["cannon"] = int(_party.get("cannon", 0)) + beans
	_player.remove_meta("party_fly")
	_player.set_swimming(false)
	_player.global_position = _origin + Vector3(0.0, 0.2, 3.0)
	_player.set("velocity", Vector3.ZERO)
	_done = true
	finished.emit(beans, "You collected %d jellybeans!\n\nNumber of Clouds Hit: " + str(_hits))
	queue_free()


func _banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_note = Label.new()
	_note.position = Vector2(40, 40)
	_note.size = Vector2(640, 120)
	ToonGui.style_label(_note, Color.WHITE, 28, Color(0.1, 0.05, 0.2), 4)
	layer.add_child(_note)
