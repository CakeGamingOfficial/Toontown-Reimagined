extends Camera3D

## Free-fly camera for walking the playground before a toon controller exists.
## Hold the right mouse button to look. WASD moves, E/Q go up and down, Shift sprints.

@export var move_speed := 70.0
@export var sprint_multiplier := 2.5
@export var look_sensitivity := 0.003

var _yaw := 0.0
var _pitch := 0.0


func _ready() -> void:
	current = true
	look_at(Vector3(0, 4, 0), Vector3.UP)
	_pitch = rotation.x
	_yaw = rotation.y


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * look_sensitivity
		_pitch = clampf(_pitch - event.relative.y * look_sensitivity, deg_to_rad(-85.0), deg_to_rad(85.0))
		rotation = Vector3(_pitch, _yaw, 0.0)


func _process(delta: float) -> void:
	var direction := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		direction.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		direction.z += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_SPACE):
		direction.y += 1.0
	if Input.is_physical_key_pressed(KEY_Q):
		direction.y -= 1.0
	if direction == Vector3.ZERO:
		return
	var speed := move_speed * (sprint_multiplier if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	translate(direction.normalized() * speed * delta)
