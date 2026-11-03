extends Node

## DistributedButton and DistributedDoorEntity. Stepping on a button presses
## it and pulls that lock. The door slides open when a toon walks into it,
## once every lock on it is open. SellbotLegFactorySpec wires the two
## entrance buttons together, and the lobby button with the duct button.

const _MODEL := preload("res://assets/cog_hq/cog_door_handshake.glb")
const _PRESS := preload("res://assets/cog_hq/audio/CHQ_FACT_switch_pressed.ogg")
const _POPUP := preload("res://assets/cog_hq/audio/CHQ_FACT_switch_popup.ogg")
const _UNLOCK := preload("res://assets/cog_hq/audio/CHQ_FACT_door_unlock.ogg")
const _ARMS := preload("res://assets/cog_hq/audio/CHQ_FACT_arms_retracting.ogg")
const _SLIDE := preload("res://assets/cog_hq/audio/CHQ_FACT_door_open_sliding.ogg")
const _FINAL := preload("res://assets/cog_hq/audio/CHQ_FACT_door_open_final.ogg")
const _GREEN := Color(0.0, 1.0, 0.0, 1.0)
const _ROMAN: PackedStringArray = ["One", "Two", "Three"]
## Locks that start closed. The others are already unlocked.
const _START_LOCKED := {
	10052: [1],
	30000: [1],
	30002: [1],
	30009: [1],
	30018: [1],
	30021: [1],
	60094: [1, 2],
}

var _buttons: Dictionary = {}
var _doors: Dictionary = {}
var _down: Dictionary = {}


static func place(host: Node) -> void:
	if Engine.is_editor_hint() or host == null:
		return
	if host.get_node_or_null("FactoryDoors") != null:
		return
	var script := load("res://scenes/cog_hq/factory_doors.gd") as GDScript
	var node := script.new() as Node
	node.name = "FactoryDoors"
	host.add_child(node)


func apply_switch(kind: int, ent_id: int, on: bool) -> void:
	if kind == 0:
		_set_button(ent_id, on, false)
		return
	_snap_unlocked(ent_id)
	_try_open(ent_id, false)


func _ready() -> void:
	var host := get_parent()
	if host != null:
		_gather(host)


func _physics_process(delta: float) -> void:
	_poll_player()
	for ent_id in _buttons:
		var button: CogButton = _buttons[ent_id]
		if button.release < 0.0:
			continue
		button.release -= delta
		if button.release <= 0.0:
			_set_button(button.id, false, true)
	for ent_id in _doors:
		var door: Door = _doors[ent_id]
		_advance_locks(door, delta)
		if door.until < 0.0:
			continue
		door.until -= delta
		if door.until > 0.0:
			continue
		_advance(door)


func _gather(node: Node) -> void:
	var node_name := String(node.name)
	if node_name.begins_with("button-"):
		_setup_button(node as Node3D, _ent_id(node_name))
		return
	if node_name.begins_with("door-"):
		_setup_door(node as Node3D, _ent_id(node_name))
		return
	for child in node.get_children():
		_gather(child)


func _setup_button(root: Node3D, ent_id: int) -> void:
	if root == null:
		return
	var cap := _named(root, "button") as MeshInstance3D
	var button := CogButton.new()
	button.id = ent_id
	button.root = root
	button.cap = cap
	button.color = _button_color(ent_id)
	button.seconds = _button_seconds(ent_id)
	if cap != null:
		button.rest = cap.position
		_paint(cap, button.color)
		_solid(cap)
	var base := _named(root, "buttonBase")
	if base != null:
		_solid(base)
	_buttons[ent_id] = button


func _setup_door(root: Node3D, ent_id: int) -> void:
	if root == null:
		return
	for child in root.get_children():
		child.free()
	var model := _MODEL.instantiate()
	root.add_child(model)
	var locked: Array = _START_LOCKED.get(ent_id, [])
	for index in 3:
		var roman: String = _ROMAN[index]
		if locked.has(index):
			_set_shown(_named(model, "Slide_%s_Left_Open" % roman), false)
			_set_shown(_named(model, "Slide_%s_Right_Open" % roman), false)
		else:
			_free_named(model, "Slide_%s_Closed" % roman)
			_free_named(model, "Slide_%s_Left_Open" % roman)
			_free_named(model, "Slide_%s_Right_Open" % roman)
	_free_named(model, "locator1")
	_free_named(model, "locator2")
	var door := Door.new()
	door.id = ent_id
	door.root = root
	door.top = _named(model, "doortop")
	door.bottom = _named(model, "doorbottom")
	door.left = _named(model, "doorLeft")
	door.right = _named(model, "doorRight")
	_solid(door.left)
	_solid(door.right)
	_solid(door.top)
	_solid(door.bottom)
	for index in 3:
		var roman: String = _ROMAN[index]
		var lock := Lock.new()
		lock.state = 4
		if locked.has(index):
			lock.state = 0
			lock.closed = _named(model, "Slide_%s_Closed" % roman)
			lock.left = _named(model, "Slide_%s_Left_Open" % roman)
			lock.right = _named(model, "Slide_%s_Right_Open" % roman)
		door.locks.append(lock)
	_doors[ent_id] = door


func _poll_player() -> void:
	var host := get_parent()
	if host == null:
		return
	var feet := host.get_node_or_null("Player") as Node3D
	if feet == null:
		return
	var where := feet.global_position
	for ent_id in _buttons:
		var button: CogButton = _buttons[ent_id]
		if button.root == null or not button.root.is_inside_tree():
			continue
		var local: Vector3 = button.root.to_local(where)
		var standing := Vector2(local.x, local.y).length() < 0.75 and absf(local.z) < 2.0
		if standing and not button.held:
			button.held = true
			button.release = -1.0
			_set_button(button.id, true, true)
		elif not standing and button.held:
			button.held = false
			if button.down and button.seconds >= 0.0:
				button.release = button.seconds
	for ent_id in _doors:
		var door: Door = _doors[ent_id]
		if door.root == null or not door.root.is_inside_tree():
			continue
		var local: Vector3 = door.root.to_local(where)
		var against := absf(local.x) < 4.5 and absf(local.y) < 1.2 and local.z > -0.5 and local.z < 5.0
		if against and not door.touching:
			door.touching = true
			_try_open(door.id, true)
		elif not against:
			door.touching = false


func _set_button(ent_id: int, on: bool, tell: bool) -> void:
	var button: CogButton = _buttons.get(ent_id) as CogButton
	if button == null or button.down == on:
		return
	button.down = on
	button.release = -1.0
	_down[ent_id] = on
	_pose_button(button, on)
	var stream: AudioStream = _POPUP
	if on:
		stream = _PRESS
	_sfx(button.root, stream)
	_drive_locks()
	if tell:
		ToonNet.ask_factory_switch(0, ent_id, on)


func _pose_button(button: CogButton, down: bool) -> void:
	if button.cap == null:
		return
	if button.tween != null and button.tween.is_valid():
		button.tween.kill()
	var dest: Vector3 = button.rest
	var color: Color = button.color
	if down:
		dest = button.rest + Vector3(0.0, 0.0, -0.2)
		color = _GREEN
	var duration := 0.8 if down else 1.0
	var tween := create_tween()
	button.tween = tween
	tween.set_parallel(true)
	tween.tween_property(button.cap, "position", dest, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_paint.bind(button.cap, color)).set_delay(duration * 0.5)


func _drive_locks() -> void:
	var entrance := bool(_down.get(30040, false)) or bool(_down.get(60102, false))
	_drive_lock(30000, 1, entrance)
	_drive_lock(30002, 1, entrance)
	var lobby := bool(_down.get(30076, false)) or bool(_down.get(60118, false))
	_drive_lock(30009, 1, lobby)
	_drive_lock(30021, 1, lobby)
	_drive_lock(10052, 1, bool(_down.get(10039, false)))
	_drive_lock(30018, 1, bool(_down.get(60103, false)))
	_drive_lock(60094, 1, bool(_down.get(60104, false)))
	_drive_lock(60094, 2, bool(_down.get(60105, false)))


func _drive_lock(door_id: int, index: int, unlocked: bool) -> void:
	var door: Door = _doors.get(door_id) as Door
	if door == null or index < 0 or index >= door.locks.size():
		return
	var lock: Lock = door.locks[index]
	if unlocked:
		if lock.state == 3 or lock.state == 4:
			return
		_begin_unlock(door, lock)
		return
	if lock.state == 0 or lock.state == 1:
		return
	_begin_lock(door, lock)
	if door.state == 1 or door.state == 2:
		_begin_close(door)


func _begin_unlock(door: Door, lock: Lock) -> void:
	# FourState unlocking lasts 4 seconds. The arms slide apart over 3.2.
	lock.state = 3
	lock.until = 4.0
	_sfx(door.root, _UNLOCK)
	_sfx(door.root, _ARMS)
	_kill_lock(lock)
	var tween := create_tween()
	lock.tweens.append(tween)
	tween.tween_interval(0.4)
	tween.tween_callback(_show_opening_arms.bind(lock))
	tween.tween_callback(_slide_arms.bind(door, lock, -7.5, 7.5, 3.2, Tween.EASE_OUT))
	tween.tween_interval(3.2)
	tween.tween_callback(_hide_arms.bind(lock))


func _begin_lock(door: Door, lock: Lock) -> void:
	lock.state = 1
	lock.until = 3.5
	_sfx(door.root, _ARMS)
	_kill_lock(lock)
	var tween := create_tween()
	lock.tweens.append(tween)
	tween.tween_interval(0.35)
	tween.tween_callback(_show_closing_arms.bind(lock))
	tween.tween_callback(_slide_arms.bind(door, lock, 0.0, 0.0, 2.8, Tween.EASE_IN))
	tween.tween_interval(2.8)
	tween.tween_callback(_show_closed.bind(lock))


func _show_opening_arms(lock: Lock) -> void:
	_set_shown(lock.closed, false)
	_set_shown(lock.left, true)
	_set_shown(lock.right, true)
	if lock.left != null:
		lock.left.position = Vector3.ZERO
	if lock.right != null:
		lock.right.position = Vector3.ZERO


func _show_closing_arms(lock: Lock) -> void:
	_set_shown(lock.closed, false)
	_set_shown(lock.left, true)
	_set_shown(lock.right, true)
	if lock.left != null:
		lock.left.position = Vector3(-7.5, 0.0, 0.0)
	if lock.right != null:
		lock.right.position = Vector3(7.5, 0.0, 0.0)


func _slide_arms(door: Door, lock: Lock, left_x: float, right_x: float, seconds: float, ease: Tween.EaseType) -> void:
	var tween := create_tween()
	lock.tweens.append(tween)
	tween.set_parallel(true)
	if lock.left != null:
		tween.tween_property(lock.left, "position", Vector3(left_x, 0.0, 0.0), seconds).set_trans(Tween.TRANS_QUAD).set_ease(ease)
	if lock.right != null:
		tween.tween_property(lock.right, "position", Vector3(right_x, 0.0, 0.0), seconds).set_trans(Tween.TRANS_QUAD).set_ease(ease)


func _hide_arms(lock: Lock) -> void:
	_set_shown(lock.left, false)
	_set_shown(lock.right, false)


func _show_closed(lock: Lock) -> void:
	_set_shown(lock.left, false)
	_set_shown(lock.right, false)
	_set_shown(lock.closed, true)


func _advance_locks(door: Door, delta: float) -> void:
	for item in door.locks:
		var lock: Lock = item
		if lock.until < 0.0:
			continue
		lock.until -= delta
		if lock.until > 0.0:
			continue
		lock.until = -1.0
		if lock.state == 3:
			lock.state = 4
			_hide_arms(lock)
			if door.touching:
				_try_open(door.id, true)
		elif lock.state == 1:
			lock.state = 0
			_show_closed(lock)


func _try_open(ent_id: int, tell: bool) -> void:
	var door: Door = _doors.get(ent_id) as Door
	if door == null or door.state != 0 or not _locks_open(door):
		return
	_begin_open(door)
	if tell:
		ToonNet.ask_factory_switch(1, ent_id, true)


func _locks_open(door: Door) -> bool:
	for item in door.locks:
		if (item as Lock).state != 4:
			return false
	return true


func _snap_unlocked(ent_id: int) -> void:
	var door: Door = _doors.get(ent_id) as Door
	if door == null:
		return
	for item in door.locks:
		var lock: Lock = item
		lock.state = 4
		lock.until = -1.0
		_hide_arms(lock)
		_set_shown(lock.closed, false)


func _begin_open(door: Door) -> void:
	# Opening lasts 5 seconds: the top and bottom slide, then the side doors.
	door.state = 1
	door.until = 5.0
	_kill(door)
	_sfx(door.root, _SLIDE)
	var tween := create_tween()
	door.tweens.append(tween)
	tween.tween_interval(0.5)
	tween.tween_callback(_slide_outer.bind(door, 8.0, 2.0, Tween.EASE_OUT))
	tween.tween_interval(1.875)
	tween.tween_callback(_sfx.bind(door.root, _FINAL))
	tween.tween_interval(0.125)
	tween.tween_callback(_stash_outer.bind(door))
	tween.tween_callback(_sfx.bind(door.root, _SLIDE))
	tween.tween_callback(_slide_inner.bind(door, 8.0, 2.0, Tween.EASE_OUT))
	tween.tween_interval(1.875)
	tween.tween_callback(_sfx.bind(door.root, _FINAL))
	tween.tween_interval(0.125)
	tween.tween_callback(_stash_inner.bind(door))


func _begin_close(door: Door) -> void:
	door.state = 3
	door.until = 6.0
	_kill(door)
	var tween := create_tween()
	door.tweens.append(tween)
	tween.tween_interval(0.6)
	tween.tween_callback(_unstash_inner.bind(door))
	tween.tween_callback(_sfx.bind(door.root, _SLIDE))
	tween.tween_callback(_slide_inner.bind(door, 0.0, 2.4, Tween.EASE_IN))
	tween.tween_interval(2.25)
	tween.tween_callback(_sfx.bind(door.root, _FINAL))
	tween.tween_interval(0.15)
	tween.tween_callback(_unstash_outer.bind(door))
	tween.tween_callback(_sfx.bind(door.root, _SLIDE))
	tween.tween_callback(_slide_outer.bind(door, 0.0, 2.4, Tween.EASE_IN))
	tween.tween_interval(2.25)
	tween.tween_callback(_sfx.bind(door.root, _FINAL))


func _advance(door: Door) -> void:
	door.until = -1.0
	if door.state == 1:
		door.state = 2
		door.until = 1.0
		return
	if door.state == 2:
		_begin_close(door)
		return
	if door.state == 3:
		_kill(door)
		_rest(door)
		door.state = 0


func _slide_outer(door: Door, distance: float, seconds: float, ease: Tween.EaseType) -> void:
	var tween := create_tween()
	door.tweens.append(tween)
	tween.set_parallel(true)
	if door.top != null:
		tween.tween_property(door.top, "position", Vector3(0.0, 0.0, distance), seconds).set_trans(Tween.TRANS_QUAD).set_ease(ease)
	if door.bottom != null:
		tween.tween_property(door.bottom, "position", Vector3(0.0, 0.0, -distance), seconds).set_trans(Tween.TRANS_QUAD).set_ease(ease)


func _slide_inner(door: Door, distance: float, seconds: float, ease: Tween.EaseType) -> void:
	var tween := create_tween()
	door.tweens.append(tween)
	tween.set_parallel(true)
	if door.left != null:
		tween.tween_property(door.left, "position", Vector3(-distance, 0.0, 0.0), seconds).set_trans(Tween.TRANS_QUAD).set_ease(ease)
	if door.right != null:
		tween.tween_property(door.right, "position", Vector3(distance, 0.0, 0.0), seconds).set_trans(Tween.TRANS_QUAD).set_ease(ease)


func _stash_outer(door: Door) -> void:
	_set_shown(door.top, false)
	_set_shown(door.bottom, false)


func _stash_inner(door: Door) -> void:
	_set_shown(door.left, false)
	_set_shown(door.right, false)


func _unstash_inner(door: Door) -> void:
	_set_shown(door.left, true)
	_set_shown(door.right, true)


func _unstash_outer(door: Door) -> void:
	_set_shown(door.top, true)
	_set_shown(door.bottom, true)


func _rest(door: Door) -> void:
	_place(door.top, Vector3.ZERO)
	_place(door.bottom, Vector3.ZERO)
	_place(door.left, Vector3.ZERO)
	_place(door.right, Vector3.ZERO)


func _place(node: Node3D, where: Vector3) -> void:
	if node == null:
		return
	node.position = where
	node.visible = true


func _kill(door: Door) -> void:
	_stop(door.tweens)


func _kill_lock(lock: Lock) -> void:
	_stop(lock.tweens)


func _stop(tweens: Array) -> void:
	for item in tweens:
		var tween := item as Tween
		if tween != null and tween.is_valid():
			tween.kill()
	tweens.clear()


func _solid(node: Node) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null and mesh.get_node_or_null(String(mesh.name) + "_col") == null:
			mesh.create_trimesh_collision()
			var body := mesh.get_node_or_null(String(mesh.name) + "_col") as StaticBody3D
			if body != null:
				body.collision_layer = 1
				body.collision_mask = 0
	for child in node.get_children():
		var child_name := String(child.name)
		if child_name.contains("collision") or child_name.contains("collsion"):
			continue
		_solid(child)


func _sfx(at: Node, stream: AudioStream) -> void:
	if at == null or stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.unit_size = 12.0
	player.max_distance = 80.0
	at.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _paint(mesh: MeshInstance3D, color: Color) -> void:
	if mesh == null:
		return
	var mat := StandardMaterial3D.new()
	var source := mesh.get_active_material(0)
	if source is StandardMaterial3D:
		mat = (source as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.albedo_color = color
	mat.vertex_color_use_as_albedo = false
	mesh.material_override = mat


func _set_shown(node: Node3D, shown: bool) -> void:
	if node != null:
		node.visible = shown


func _named(root: Node, node_name: String) -> Node3D:
	if root == null:
		return null
	return root.find_child(node_name, true, false) as Node3D


func _free_named(root: Node, node_name: String) -> void:
	var node := _named(root, node_name)
	if node != null:
		node.free()


static func _ent_id(node_name: String) -> int:
	var dash := node_name.find("-")
	if dash < 0:
		return -1
	return node_name.substr(dash + 1).to_int()


static func _button_color(ent_id: int) -> Color:
	if ent_id >= 20033 and ent_id <= 20036:
		return Color(0.862745, 0.517647, 0.0941177, 1.0)
	return Color(1.0, 0.0, 0.0, 1.0)


static func _button_seconds(ent_id: int) -> float:
	if ent_id >= 20033 and ent_id <= 20036:
		return 1.0
	return -1.0


class Lock:
	var state := 0
	var until := -1.0
	var closed: Node3D
	var left: Node3D
	var right: Node3D
	var tweens: Array = []

	func _init() -> void:
		tweens = []


class Door:
	var id := 0
	var root: Node3D
	var top: Node3D
	var bottom: Node3D
	var left: Node3D
	var right: Node3D
	var locks: Array = []
	var state := 0
	var until := -1.0
	var touching := false
	var tweens: Array = []

	func _init() -> void:
		locks = []
		tweens = []


class CogButton:
	var id := 0
	var root: Node3D
	var cap: MeshInstance3D
	var rest := Vector3.ZERO
	var color := Color.WHITE
	var seconds := -1.0
	var down := false
	var held := false
	var release := -1.0
	var tween: Tween
