extends Node

## DistributedFishingSpot for the local toon. Walk onto a shore spot, hold Cast,
## and drag down. The bob flies until it reaches the pond, then a moving target
## within 2.5 pulls the line. The saved rod picks the pole, the bait, and the catch.

signal finished

const _TANK := preload("res://scenes/fishing/fish_tank.gd")
const _BEANS := preload("res://scenes/toons/jellybeans.gd")
const _HOLIDAYS := preload("res://scenes/shticker/calendar_holidays.gd")
const _ROLL := preload("res://scenes/fishing/fish_roll.gd")
const _BINGO := preload("res://scenes/fishing/fish_bingo.gd")
const _FISH_PHOTO := preload("res://scenes/fishing/fish_photo.gd")
const _DIALOG := preload("res://assets/gui/tutorial/dialog/dialog_box.png")
const _BOARDS := preload("res://assets/gui/fishing/boards.png")
const _JAR_ART := preload("res://assets/gui/fishing/jar.png")
const _BUCKET_ART := preload("res://assets/gui/fishing/bucket.png")
const _PLAQUE := preload("res://assets/gui/fishing/display_jar.png")
const _CAST_ART := preload("res://assets/gui/fishing/castButton.png")
const _TIP_ART := preload("res://assets/gui/fishing/arrowTip.png")
const _TAIL_ART := preload("res://assets/gui/fishing/arrowTail.png")
const _EXIT_UP := preload("res://assets/gui/fishing/exit_buttonUp.png")
const _EXIT_DOWN := preload("res://assets/gui/fishing/exit_buttonDown.png")
const _EXIT_HOVER := preload("res://assets/gui/fishing/exit_buttonRollover.png")
const _RIPPLE_ART := preload("res://assets/props/fishing_ripples.png")
const _RIPPLE_COLS := 6
const _RIPPLE_ROWS := 4
const _RIPPLE_FRAMES := 24
const _CLOSE_UP := preload("res://assets/toons/gui/CloseBtn_UP.png")
const _CLOSE_DOWN := preload("res://assets/toons/gui/CloseBtn_DN.png")
const _CLOSE_HOVER := preload("res://assets/toons/gui/CloseBtn_Rllvr.png")
## ToontownTimer.getImage is phase_3.5 clock_gui alarm_clock, scaled to 0.45.
const _CLOCK_ART := preload("res://assets/gui/purchase/alarm_clock.png")
const _CLOCK_X := 1.16
const _CLOCK_Z := 0.83
const _CLOCK_W := 0.7417 * 0.45
const _CLOCK_H := 0.7292 * 0.45
# dialog_box_gui tight bounds, then FishPanel image_scale (0.65, 1, 0.85).
# The panel itself sits at (0, 0, 0.5).
const _DLG_W := 1.1122
const _DLG_H := 1.1861
const _DLG_CX := -0.02113
const _DLG_CZ := -0.03873
const _FISH_SX := 0.65
const _FISH_SZ := 0.85
const _FISH_Z := 0.5
const _HIT := 2.5
const _POLES: PackedStringArray = [
	"res://assets/props/fishing_pole.glb",
	"res://assets/props/fishing_pole_bamboo.glb",
	"res://assets/props/fishing_pole_wood.glb",
	"res://assets/props/fishing_pole_steel.glb",
	"res://assets/props/fishing_pole_gold.glb",
]
const _HOW_FIRST := "Click and drag down from the Cast button. The farther down you drag, the stronger your cast will be. Adjust your angle to hit the fish targets.\n\nTry it now!"
const _HOW_FAILED := "Click and drag down from the Cast button. The farther down you drag, the stronger your cast will be. Adjust your angle to hit the fish targets.\n\nTry it again now!"
const _BROKE := "You do not have any more jellybeans for bait! Ride the trolley or sell fish to the Pet Shop Clerks to earn more jellybeans."
const _FULL := "Your fish bucket is full. Go sell your fish to the Pet Shop Clerk and come back."
const _MISSED := "You didn't catch anything!"
const _BOOT := "An old boot"
const _BOOT_ART := preload("res://assets/gui/fishing/boot.png")
# fishing_boot.bam is a card from (-0.858333, 0.729167) to (0.858333, -0.729167),
# drawn at scale 0.2 in the middle of the item frame.
const _BOOT_W := 1.716666 * 0.2
const _BOOT_H := 1.458334 * 0.2
# Item frame: dialog geom_scale (1, 1, 0.6) at z 0.587.
const _ITEM_SX := 1.0
const _ITEM_SZ := 0.6
const _ITEM_Z := 0.587

var _rod := 0
var _actor: ToonActor
var _camera: Camera3D
var _spot: Node3D
var _from := Vector3.ZERO
var _from_heading := 0.0
var _stand := Vector3.ZERO
var _base_heading := 0.0
var _aim_heading := 0.0
var _water := 0.0
var _surface := 0.0
var _zone := 0
var _started := false
var _done := false
var _state := ""
var _time := 0.0
var _poled := false
var _pole_time := 0.0
var _power := 0.0
var _angle := 0.0
var _press := Vector2.ZERO
var _flight := 0.0
var _bite := 0.0
var _check := 1.0
var _bob_at := Vector3.ZERO
var _timer_left := 45.0
var _gui_up := false
var _modal_leave := false
var _posing := false
var _long_dur := 0.0
var _cast_from := 0.0
var _cast_clock := 0.0
var _queue: PackedStringArray = PackedStringArray()
var _queue_at := 0
var _cam_from := Vector3.ZERO
var _cam_at := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _pole: Node3D
var _bob: Node3D
var _ripples: MeshInstance3D
var _ripple_time := -1.0
var _line: MeshInstance3D
var _line_mesh: CylinderMesh
var _layer: CanvasLayer
var _bingo: Node
var _cast_button: TextureButton
var _cast_caption: Label
var _exit_button: TextureButton
var _exit_caption: Label
var _jar: Label
var _bucket: Label
var _clock_face: TextureRect
var _clock: Label
var _clock_shown := -1
var _arrow: Control
var _arrow_tip: TextureRect
var _arrow_tail: TextureRect
var _modal: Control
var _modal_label: Label
var _modal_button: Button
var _reward: Control
var _reward_label: Label
var _fish_photo: Control
var _fish_weight: Label
var _fish_value: Label
var _fish_extra: Label
var _boot_art: TextureRect
var _boot_name: Label


func open(actor: ToonActor, camera: Camera3D, spot: Node3D, feet: Vector3, heading: float) -> void:
	_actor = actor
	_camera = camera
	_spot = spot
	_from = feet
	_from_heading = heading
	_stand = spot.global_position
	_base_heading = float(spot.get_meta("heading"))
	_aim_heading = _base_heading
	_water = float(spot.get_meta("water"))
	_zone = int(spot.get_meta("zone"))
	if is_inside_tree():
		_begin()


func _ready() -> void:
	_build()
	if _actor != null:
		_begin()


func _begin() -> void:
	if _started or _actor == null or _spot == null:
		return
	_started = true
	_rod = _TANK.rod()
	if _bingo != null:
		_bingo.call("open", _zone)
	_surface = _surface_y()
	_long_dur = _actor.action_length("castlong") / 4.0
	_state = "approach"
	_time = 0.0
	if _camera != null:
		_cam_from = _camera.global_position
		var forward := _forward(_base_heading)
		_cam_at = _stand - forward * 12.0 + Vector3(0.0, 15.0, 0.0)
		_cam_look = _cam_at + forward * 10.0 + Vector3(0.0, -7.81, 0.0)
	_play("run", true)


func _process(delta: float) -> void:
	if _done or _actor == null or not is_instance_valid(_actor):
		return
	_time += delta
	if _gui_up:
		_timer_left = maxf(_timer_left - delta, 0.0)
		_paint_clock(false)
	_tick_ripples(delta)
	if _state == "approach":
		_approach(delta)
	elif _state == "aim":
		_drag()
	elif _state == "cast":
		_cast_wind(delta)
	elif _state == "flight":
		_fly(delta)
	elif _state == "bite":
		_bobbing(delta)
	elif _state == "reward":
		_reel()
	elif _state == "leave":
		_leaving(delta)
	if _posing:
		_share()
		return
	_actor.set_locomotion(0.0, false, false, delta)
	_share()


func _approach(delta: float) -> void:
	var walk := clampf(_time / 1.0, 0.0, 1.0)
	_stand_at(_from.lerp(_stand, walk))
	var heading := rad_to_deg(lerp_angle(deg_to_rad(_from_heading), deg_to_rad(_base_heading), walk))
	_aim(heading)
	var glide := clampf(_time / 1.5, 0.0, 1.0)
	_glide_camera(glide * glide * (3.0 - 2.0 * glide))
	if _time >= 1.0 and not _poled:
		_poled = true
		_pole_time = 0.0
		_attach_pole()
		_play("pole", false)
	if not _poled:
		return
	_pole_time += delta
	if _pole != null:
		_pole.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf(_pole_time / 0.5, 0.0, 1.0))
	if _actor.action_length("pole") <= 0.0 or _actor.gesture_finished():
		_state = "wait"
		_play("pole-neutral", true)
		_show_gui()


func _drag() -> void:
	var mouse := _mouse()
	var delta_x := mouse.x - _press.x
	var delta_y := mouse.y - _press.y
	if delta_y >= 0.0:
		if _power <= 0.0:
			_angle = 0.0
			_arrow.visible = false
		return
	var dist := sqrt(delta_x * delta_x + delta_y * delta_y)
	var pulled := dist / 0.5
	_power = clampf(absf(pulled), 0.0, 1.0)
	_angle = rad_to_deg(atan(delta_x / delta_y))
	if _power < 0.25:
		_angle = _angle * pow(_power * 4.0, 3.0)
	var clamped := absf(_angle) > 50.0
	_angle = clampf(_angle, -50.0, 50.0)
	# angleNP.setH(-angle). Dragging right is a negative angle and a turn to the right.
	_aim_heading = _base_heading - _angle
	_aim(_aim_heading)
	_arrow.visible = true
	_layout_arrow()
	if clamped:
		_arrow.modulate = Color(1, 0, 0, 1)
	else:
		_arrow.modulate = Color(1.0, 1.0 - pow(_power, 3.0), 0.1, 0.7)
	if _long_dur > 0.0:
		_posing = true
		_actor.pose_action("castlong", (0.2 + _power * 0.7) * 4.0)


func _cast_wind(delta: float) -> void:
	_cast_clock += delta
	var wait := 1.2 - _cast_from
	if _long_dur > 0.0:
		_posing = true
		_actor.pose_action("castlong", minf(_cast_from + _cast_clock, _long_dur) * 4.0)
	if _cast_clock < wait:
		return
	_posing = false
	_actor.end_action("castlong")
	_actor.end_action("cast")
	_play("cast", false)
	_flight = 0.0
	_state = "flight"
	_show_bob()


func _fly(delta: float) -> void:
	_flight += delta
	var speed := _power * 25.0
	var pitch := deg_to_rad(_power * 30.0)
	var along := speed * cos(pitch) * _flight
	var rise := speed * sin(pitch) * _flight - 16.1 * _flight * _flight
	var pos := _stand + _forward(_aim_heading) * (3.0 + along) + Vector3(0.0, 8.5 + rise, 0.0)
	_bob.global_position = pos
	_draw_line()
	if pos.y <= _surface:
		_bob_at = Vector3(pos.x, _surface, pos.z)
		_bob.global_position = _bob_at
		_bite = 0.0
		_check = 1.0
		_state = "bite"
		_splash(_bob_at)
		_play_ripples(_bob_at)
		_play("fish-neutral", true)


func _bobbing(delta: float) -> void:
	_bite += delta
	_bob_at.y = _surface + sin(_bite * 1.8) * 0.08
	_bob.global_position = _bob_at
	_draw_line()
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	if _over_target():
		_catch()


func _reel() -> void:
	_draw_line()
	if _queue_at >= _queue.size():
		return
	if not _actor.gesture_finished():
		return
	_queue_at += 1
	if _queue_at == 1:
		_hide_bob()
	if _queue_at >= _queue.size():
		_play("pole-neutral", true)
		return
	_play(_queue[_queue_at], false)


func _leaving(delta: float) -> void:
	if _pole != null:
		var shrink := clampf(_time / 0.5, 0.0, 1.0)
		_pole.scale = Vector3.ONE * lerpf(1.0, 0.01, shrink)
	if _actor.action_length("fish-end") <= 0.0 or _actor.gesture_finished():
		_finish()


func _input(event: InputEvent) -> void:
	if _done or _cast_button == null:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT and mouse.button_index != MOUSE_BUTTON_RIGHT:
		return
	if mouse.pressed:
		# waiting, the throw, the bob in the water, and the catch dialog can all start another cast.
		var casting := _state == "wait" or _state == "cast" or _state == "flight" or _state == "bite" or _state == "reward"
		if casting and _cast_button.get_global_rect().has_point(mouse.position):
			_hide_fish()
			_reward.visible = false
			_press_cast()
			get_viewport().set_input_as_handled()
	elif _state == "aim":
		_release_cast()
		get_viewport().set_input_as_handled()


func _press_cast() -> void:
	if _modal.visible or _reward.visible:
		_hide_fish()
		_reward.visible = false
	# A second press pulls the line in and starts the aim over.
	_hide_bob()
	if _TANK.count() >= _TANK.max_count():
		_show_modal(_FULL, true)
		return
	if _BEANS.pouch() < _ROLL.cast_cost(_rod):
		_show_modal(_BROKE, true)
		return
	_state = "aim"
	_power = 0.0
	_angle = 0.0
	_press = _mouse()
	_cast_caption.text = ""
	_cast_button.modulate = Color(0, 1, 0)
	_play("pole-neutral", true)


func _release_cast() -> void:
	_posing = false
	_actor.end_action("castlong")
	_cast_caption.text = "Cast"
	var over := _cast_button.get_global_rect().has_point(get_viewport().get_mouse_position())
	_cast_button.modulate = Color(1, 1, 0) if over else Color(1, 0, 0)
	_arrow.visible = false
	if _power <= 0.0 and _TANK.collected() == 0:
		_state = "wait"
		_show_modal(_HOW_FAILED, false)
		_play("pole-neutral", true)
		return
	if not _BEANS.take_beans(_ROLL.cast_cost(_rod), false):
		_state = "wait"
		_show_modal(_BROKE, true)
		_play("pole-neutral", true)
		return
	_jar.text = str(_BEANS.pouch())
	_refresh_jar()
	_timer_left = 45.0
	_cast_from = 0.7 + (1.0 - _power) * 0.3
	_cast_clock = 0.0
	_aim_heading = _base_heading - _angle
	_aim(_aim_heading)
	_state = "cast"


func _catch() -> void:
	_hide_fish()
	var caught: Dictionary = _ROLL.roll(_zone, _rod)
	var code := int(caught["code"])
	var text := _MISSED
	var kept_fish := false
	var genus := -1
	var species := 99
	if code == 2:
		var tasks := ToonTasks.live()
		if tasks != null:
			tasks.note_fish(_zone)
		genus = int(caught["genus"])
		species = int(caught["species"])
		var weight := int(caught["weight"])
		var kind := _TANK.catch_code(genus, species, weight)
		if _TANK.add_fish(genus, species, weight):
			kept_fish = true
			_reward_label.text = _TANK.species_name(genus, species)
			_fish_weight.text = _TANK.weight_line(weight)
			_fish_value.text = _TANK.value_line(_TANK.bean_value(genus, species, weight))
			_fish_weight.visible = true
			_fish_value.visible = true
			_fish_extra.visible = kind == 9 or kind == 10
			if kind == 9:
				_fish_extra.text = "New Species!"
			elif kind == 10:
				_fish_extra.text = "New Record!"
			if _fish_photo != null:
				_fish_photo.call("show_genus", genus)
		else:
			text = _FULL
	elif code == 3:
		var beans := int(caught["beans"]) * int(_HOLIDAYS.bean_scale("fish"))
		_BEANS.add_beans(beans)
		_jar.text = str(_BEANS.pouch())
		_refresh_jar()
		text = "You caught:\n%d jellybeans" % beans
	elif code == 4:
		text = "You caught:"
		_boot_name.text = _BOOT
		_boot_name.visible = true
		_boot_art.visible = true
	_bucket.text = "%d/%d" % [_TANK.count(), _TANK.max_count()]
	if _bingo != null and (code == 2 or code == 4):
		_bingo.call("note_catch", genus, species)
	if not kept_fish:
		_reward_label.text = text
	_reward.visible = true
	_seat_fish()
	_seat_boot()
	_state = "reward"
	_queue = PackedStringArray(["reel", "reel-neutral", "fish-again"])
	_queue_at = 0
	_play("reel", false)


func _show_gui() -> void:
	_gui_up = true
	_timer_left = 45.0
	_layer.visible = true
	_jar.text = str(_BEANS.pouch())
	_bucket.text = "%d/%d" % [_TANK.count(), _TANK.max_count()]
	_layout()
	if _TANK.collected() == 0 and _TANK.count() == 0:
		_show_modal(_HOW_FIRST, false)


func _show_modal(message: String, leave: bool) -> void:
	_modal_leave = leave
	_modal_label.text = message
	_modal_button.text = "Exit" if leave else "OK"
	_modal.visible = true
	_state = "modal"


func _close_modal() -> void:
	_modal.visible = false
	if _modal_leave:
		_begin_leave()
		return
	_state = "wait"
	_play("pole-neutral", true)


func _bingo_paid(amount: int) -> void:
	_BEANS.add_beans(amount)
	if _jar != null:
		_jar.text = str(_BEANS.pouch())
		_refresh_jar()


func _close_reward() -> void:
	_hide_fish()
	_reward.visible = false
	if _state == "reward":
		_state = "wait"
		_play("pole-neutral", true)


func _begin_leave() -> void:
	_hide_fish()
	_reward.visible = false
	_modal.visible = false
	_layer.visible = false
	_gui_up = false
	_hide_bob()
	_posing = false
	_time = 0.0
	_state = "leave"
	_play("fish-end", false)


func _finish() -> void:
	if _done:
		return
	_done = true
	if _actor != null and is_instance_valid(_actor):
		if _actor.has_meta("fish_anim"):
			_actor.remove_meta("fish_anim")
		_actor.end_action("cast")
		_actor.end_action("castlong")
		_actor.clear_gesture()
	if _pole != null and is_instance_valid(_pole):
		_pole.queue_free()
	if _bob != null and is_instance_valid(_bob):
		_bob.queue_free()
	if _line != null and is_instance_valid(_line):
		_line.queue_free()
	if _ripples != null and is_instance_valid(_ripples):
		_ripples.queue_free()
	finished.emit()
	queue_free()


func _exit_pressed() -> void:
	_begin_leave()


func _attach_pole() -> void:
	_pole = Node3D.new()
	_pole.name = "FishingPole"
	var packed := load(_POLES[_rod]) as PackedScene
	if packed == null:
		packed = load(_POLES[0]) as PackedScene
	if packed != null:
		_pole.add_child(packed.instantiate())
	else:
		var stick := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.03
		mesh.bottom_radius = 0.05
		mesh.height = 3.2
		stick.mesh = mesh
		stick.position = Vector3(0.0, 1.6, 0.0)
		_pole.add_child(stick)
	var hand := _actor.find_child("def_joint_right_hold", true, false) as Node3D
	if hand == null:
		_actor.add_child(_pole)
	else:
		hand.add_child(_pole)
	_pole.scale = Vector3.ONE * 0.01


func _show_bob() -> void:
	if _bob == null:
		_bob = Node3D.new()
		_bob.name = "FishingBob"
		var packed := load("res://assets/props/fishing_bob.glb") as PackedScene
		if packed != null:
			var model := packed.instantiate()
			_bob.add_child(model)
			_bob.scale = Vector3.ONE * 1.5
		else:
			var mesh_node := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.16
			sphere.height = 0.32
			mesh_node.mesh = sphere
			_bob.add_child(mesh_node)
		_world().add_child(_bob)
		_line = MeshInstance3D.new()
		_line_mesh = CylinderMesh.new()
		_line_mesh.top_radius = 0.015
		_line_mesh.bottom_radius = 0.015
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1, 1, 1, 0.4)
		_line.material_override = material
		_line.mesh = _line_mesh
		_world().add_child(_line)
		_ripples = MeshInstance3D.new()
		var card := QuadMesh.new()
		# The shore lives in the pond's Z-up space. A Y-facing card stands
		# up behind the bob, so the ring lies flat the way the model does.
		card.orientation = PlaneMesh.FACE_Z
		card.size = Vector2(4.0, 4.0)
		_ripples.mesh = card
		var ring := StandardMaterial3D.new()
		ring.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.albedo_texture = _RIPPLE_ART
		ring.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		ring.cull_mode = BaseMaterial3D.CULL_DISABLED
		ring.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		ring.render_priority = 1
		ring.uv1_scale = Vector3(1.0 / _RIPPLE_COLS, 1.0 / _RIPPLE_ROWS, 1.0)
		_ripples.material_override = ring
		_ripples.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ripples.visible = false
		_world().add_child(_ripples)
	_bob.visible = true
	_line.visible = true


func _hide_bob() -> void:
	if _bob != null:
		_bob.visible = false
	if _line != null:
		_line.visible = false
	_show_ripples(false)


func _show_ripples(show: bool) -> void:
	if not show:
		_ripple_time = -1.0
	if _ripples != null:
		_ripples.visible = show


func _play_ripples(at: Vector3) -> void:
	if _ripples == null:
		return
	_ripples.global_position = Vector3(at.x, _surface + 0.025, at.z)
	_ripples.scale = Vector3.ONE
	_ripple_time = 0.0
	_ripples.visible = true
	var material := _ripples.material_override as StandardMaterial3D
	if material != null:
		material.uv1_offset = Vector3.ZERO


func _tick_ripples(delta: float) -> void:
	if _ripples == null or _ripple_time < 0.0:
		return
	_ripple_time += delta
	var frame := int(_ripple_time * 24.0)
	if frame >= _RIPPLE_FRAMES:
		_show_ripples(false)
		return
	var material := _ripples.material_override as StandardMaterial3D
	if material == null:
		return
	material.uv1_offset = Vector3(
		float(frame % _RIPPLE_COLS) / float(_RIPPLE_COLS),
		float(frame / _RIPPLE_COLS) / float(_RIPPLE_ROWS),
		0.0
	)


func _draw_line() -> void:
	if _line == null or _bob == null or not _bob.visible:
		return
	var start := _line_from()
	var stop := _bob.global_position
	var delta := stop - start
	var length := delta.length()
	if length < 0.05:
		_line.visible = false
		return
	_line.visible = true
	_line_mesh.height = length
	var axis := delta / length
	var side := axis.cross(Vector3.UP)
	if side.length() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()
	var normal := side.cross(axis).normalized()
	_line.global_transform = Transform3D(Basis(side, axis, normal), (start + stop) * 0.5)


func _line_from() -> Vector3:
	if _pole != null:
		var tip := _pole.find_child("*attach*", true, false) as Node3D
		if tip != null:
			return tip.global_position
	var hand := _actor.find_child("def_joint_right_hold", true, false) as Node3D
	if hand != null:
		return hand.global_position
	return _stand + Vector3(0.0, 2.5, 0.0)


func _splash(at: Vector3) -> void:
	var paths: PackedStringArray = PackedStringArray([
		"res://assets/audio/sfx/TT_splash1.ogg",
		"res://assets/audio/sfx/TT_splash2.ogg",
	])
	var stream := load(paths[randi() % paths.size()]) as AudioStream
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = linear_to_db(0.8)
	player.position = at
	_world().add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _over_target() -> bool:
	var here: Node = _spot
	while here != null:
		var spots := here.find_child("FishingSpots", true, false) as Node
		if spots != null:
			for child in spots.get_children():
				var target := child as Node3D
				if target != null and target.global_position.distance_to(_bob_at) < _HIT:
					return true
			return false
		here = here.get_parent()
	return false


func _surface_y() -> float:
	var here: Node = _spot
	while here != null:
		var spots := here.find_child("FishingSpots", true, false) as Node
		if spots != null:
			for child in spots.get_children():
				var target := child as Node3D
				if target != null:
					return target.global_position.y
		here = here.get_parent()
	return _water


func _world() -> Node:
	return _spot.get_parent()


func _share() -> void:
	if _actor == null or not is_instance_valid(_actor):
		return
	var anim := "pole-neutral"
	var pose := -1.0
	if _state == "approach":
		anim = "pole" if _poled else "run"
	elif _state == "aim" or _state == "cast":
		anim = "castlong"
		var along := (0.2 + _power * 0.7) * 4.0
		if _state == "cast":
			along = minf(_cast_from + _cast_clock, _long_dur) * 4.0
		pose = along
	elif _state == "flight" or _state == "bite":
		anim = "fish-neutral"
	elif _state == "reward":
		anim = "pole-neutral"
		if _queue_at >= 0 and _queue_at < _queue.size():
			anim = _queue[_queue_at]
	elif _state == "leave":
		anim = "fish-end"
	_actor.set_meta("fish_anim", anim)
	_actor.set_meta("fish_pose", pose)
	_actor.set_meta("fish_rod", _rod)


func _play(suffix: String, loop: bool) -> void:
	_posing = false
	if _actor.action_length(suffix) <= 0.0 and suffix != "run":
		_actor.clear_gesture()
		return
	_actor.play_gesture(suffix, 1.0, loop)


func _aim(heading: float) -> void:
	var host := get_parent()
	if host != null and host.has_method("aim_fishing"):
		host.call("aim_fishing", heading)


func _stand_at(at: Vector3) -> void:
	var host := get_parent()
	if host != null and host.has_method("stand_fishing"):
		host.call("stand_fishing", at)


func _refresh_jar() -> void:
	var host := get_parent()
	if host != null and host.has_method("refresh_fishing_jar"):
		host.call("refresh_fishing_jar")


func _glide_camera(weight: float) -> void:
	if _camera == null:
		return
	_camera.global_position = _cam_from.lerp(_cam_at, weight)
	_camera.look_at(_cam_look, Vector3.UP)


func _forward(heading: float) -> Vector3:
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	upright = upright.rotated(Vector3.UP, deg_to_rad(heading))
	return upright * Vector3(0, 1, 0)


func _mouse() -> Vector2:
	var view := get_viewport().get_visible_rect().size
	var point := get_viewport().get_mouse_position()
	return Vector2(point.x / view.x * 2.0 - 1.0, 1.0 - point.y / view.y * 2.0)


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "FishingGui"
	_layer.visible = false
	add_child(_layer)
	var root := Control.new()
	root.name = "CastGui"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	# phase_4 fishingGui, drawn in the same order as the model: the plank,
	# the jar and bucket, their number frames, then the cast and exit buttons.
	_card(root, "Boards", _BOARDS)
	_card(root, "JarArt", _JAR_ART)
	_card(root, "BucketArt", _BUCKET_ART)
	_card(root, "JarFrame", _PLAQUE)
	_card(root, "BucketFrame", _PLAQUE)
	_jar = Label.new()
	_jar.name = "Jar"
	_jar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_jar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_jar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_sign(_jar, Color(0.95, 0.95, 0), 36, Color(0, 0, 0), 0)
	root.add_child(_jar)
	_bucket = Label.new()
	_bucket.name = "Bucket"
	_bucket.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bucket.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bucket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(_bucket, Color(0.95, 0.95, 0), 22, Color(0, 0, 0), 4)
	root.add_child(_bucket)
	_cast_button = TextureButton.new()
	_cast_button.name = "Cast"
	_cast_button.texture_normal = _CAST_ART
	_cast_button.texture_hover = _CAST_ART
	_cast_button.texture_pressed = _CAST_ART
	_cast_button.ignore_texture_size = true
	_cast_button.stretch_mode = TextureButton.STRETCH_SCALE
	_cast_button.focus_mode = Control.FOCUS_NONE
	_cast_button.modulate = Color(1, 0, 0)
	_cast_button.mouse_entered.connect(_cast_hover.bind(true))
	_cast_button.mouse_exited.connect(_cast_hover.bind(false))
	root.add_child(_cast_button)
	_cast_caption = Label.new()
	_cast_caption.name = "CastText"
	_cast_caption.text = "Cast"
	_cast_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cast_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cast_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(_cast_caption, Color(1, 1, 1), 28, Color(0, 0, 0), 4)
	root.add_child(_cast_caption)
	_exit_button = TextureButton.new()
	_exit_button.name = "Exit"
	_exit_button.texture_normal = _EXIT_UP
	_exit_button.texture_hover = _EXIT_HOVER
	_exit_button.texture_pressed = _EXIT_DOWN
	_exit_button.ignore_texture_size = true
	_exit_button.stretch_mode = TextureButton.STRETCH_SCALE
	_exit_button.focus_mode = Control.FOCUS_NONE
	_exit_button.pressed.connect(_exit_pressed)
	_exit_button.mouse_entered.connect(func() -> void: _exit_caption.visible = true)
	_exit_button.mouse_exited.connect(func() -> void: _exit_caption.visible = false)
	root.add_child(_exit_button)
	_exit_caption = Label.new()
	_exit_caption.name = "ExitText"
	_exit_caption.text = "Exit"
	_exit_caption.visible = false
	_exit_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exit_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_exit_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(_exit_caption, Color(1, 1, 1), 22, Color(0, 0, 0), 4)
	root.add_child(_exit_caption)
	_clock_face = TextureRect.new()
	_clock_face.name = "Clock"
	_clock_face.texture = _CLOCK_ART
	_clock_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_clock_face.stretch_mode = TextureRect.STRETCH_SCALE
	_clock_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_clock_face)
	_clock = Label.new()
	_clock.name = "Timer"
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_clock)
	_arrow = Control.new()
	_arrow.name = "Arrow"
	_arrow.visible = false
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.modulate = Color(0.9, 0.9, 0.1, 0.7)
	root.add_child(_arrow)
	_arrow_tip = _card(_arrow, "Tip", _TIP_ART)
	_arrow_tail = _card(_arrow, "Tail", _TAIL_ART)
	_modal = _panel(root, "HowTo")
	_modal_label = _modal.get_node("Text") as Label
	_modal_button = Button.new()
	_modal_button.name = "OK"
	_modal_button.text = "OK"
	_modal_button.focus_mode = Control.FOCUS_NONE
	_modal_button.add_theme_stylebox_override("normal", _fill(Color(0.2, 0.55, 0.95)))
	_modal_button.add_theme_stylebox_override("hover", _fill(Color(1, 1, 0)))
	_modal_button.add_theme_stylebox_override("pressed", _fill(Color(0.1, 0.35, 0.7)))
	_style_button(_modal_button, 22)
	_modal_button.pressed.connect(_close_modal)
	_modal.add_child(_modal_button)
	_reward = _panel(root, "Catch")
	_reward_label = _reward.get_node("Text") as Label
	_fish_photo = _FISH_PHOTO.new()
	_fish_photo.name = "FishPhoto"
	_reward.add_child(_fish_photo)
	_fish_weight = _fish_label("Weight")
	_fish_value = _fish_label("Value")
	_fish_extra = _fish_label("Extra")
	_boot_art = _card(_reward, "Boot", _BOOT_ART)
	_boot_art.visible = false
	_reward.move_child(_boot_art, 1)
	_boot_name = _fish_label("BootName")
	var close := _image_button(_reward, "Close", _CLOSE_UP, _CLOSE_DOWN, _CLOSE_HOVER)
	close.pressed.connect(_close_reward)
	_bingo = _BINGO.new()
	_bingo.name = "FishBingo"
	_layer.add_child(_bingo)
	_bingo.connect("marked", _close_reward)
	_bingo.connect("paid", _bingo_paid)
	_bingo.call("open", _zone)
	var view := get_viewport()
	if not view.size_changed.is_connected(_layout):
		view.size_changed.connect(_layout)


func _panel(parent: Control, panel_name: String) -> Control:
	var panel := Control.new()
	panel.name = panel_name
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(panel)
	var frame := TextureRect.new()
	frame.name = "Dialog"
	frame.texture = _DIALOG
	frame.modulate = Color(1, 1, 0.75, 1)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)
	var text := Label.new()
	text.name = "Text"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ToonGui.style_label(text, Color(0, 0, 0), 22, Color(0, 0, 0, 0), 0)
	panel.add_child(text)
	return panel


func _image_button(parent: Control, button_name: String, up: Texture2D, down: Texture2D, hover: Texture2D) -> TextureButton:
	var button := TextureButton.new()
	button.name = button_name
	button.texture_normal = up
	button.texture_pressed = down
	button.texture_hover = hover
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(button)
	return button


func _fill(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(10)
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


func _style_button(button: Button, size: int) -> void:
	button.add_theme_font_override("font", ToonGui.font())
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", Color(1, 1, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	button.add_theme_constant_override("outline_size", 4)


func _layout() -> void:
	if _cast_button == null:
		return
	var view := get_viewport().get_visible_rect().size
	var root := _cast_button.get_parent()
	# fishingGui.bam bounds, multiplied by the castGui scale of 0.67.
	ToonGui.place(root.get_node("Boards"), view, 0.0, -0.8693, 2.68, 0.3209)
	ToonGui.place(root.get_node("JarArt"), view, -0.7457, -0.8090, 0.3444, 0.3759)
	ToonGui.place(root.get_node("BucketArt"), view, 0.7688, -0.7876, 0.4161, 0.4670)
	ToonGui.place(root.get_node("JarFrame"), view, -0.7450, -0.8254, 0.2935, 0.1769)
	ToonGui.place(root.get_node("BucketFrame"), view, 0.7688, -0.8790, 0.2459, 0.1715)
	ToonGui.place(_jar, view, -0.7450, -0.8254, 0.2935, 0.1769)
	ToonGui.place(_bucket, view, 0.7688, -0.8790, 0.2459, 0.1715)
	# DirectButton scale (0.036, 1, 0.048) on the 4x3 cast card, then the
	# gui scale of 0.67. "Cast" sits under the circle, text_pos (0, -4).
	ToonGui.place(_cast_button, view, 0.0, -0.4688, 0.0965, 0.0965)
	ToonGui.place(_cast_caption, view, 0.0, -0.558, 0.22, 0.1)
	ToonGui.place(_exit_button, view, 1.1725, -0.8911, 0.1662, 0.1508)
	ToonGui.place(_exit_caption, view, 1.1725, -0.9515, 0.24, 0.09)
	ToonGui.place(_clock_face, view, _CLOCK_X, _CLOCK_Z, _CLOCK_W, _CLOCK_H)
	_paint_clock(true)
	var unit := view.y * 0.5
	_jar.add_theme_font_size_override("font_size", maxi(int(round(0.1072 * unit)), 1))
	_bucket.add_theme_font_size_override("font_size", maxi(int(round(0.0603 * unit)), 1))
	_cast_caption.add_theme_font_size_override("font_size", maxi(int(round(0.0724 * unit)), 1))
	_exit_caption.add_theme_font_size_override("font_size", maxi(int(round(0.067 * unit)), 1))
	_layout_panel(_modal, view, 1.7, 1.15)
	_layout_panel(_reward, view, 1.35, 0.85)
	_seat_fish()
	_seat_boot()
	_layout_arrow()


## FishPanel. The species name sits above the swim window, the weight and
## value sit under it, and New Species / New Record sit between them. All of
## those lines are inside the cream, not on the green frame.
func _seat_fish() -> void:
	if _reward == null or _fish_weight == null or not _fish_weight.visible:
		return
	var view := get_viewport().get_visible_rect().size
	var card_w := _DLG_W * _FISH_SX
	var card_h := _DLG_H * _FISH_SZ
	ToonGui.place(_reward, view, _DLG_CX * _FISH_SX, _FISH_Z + _DLG_CZ * _FISH_SZ, card_w, card_h)
	var frame := _reward.get_node("Dialog") as Control
	frame.position = Vector2.ZERO
	frame.size = _reward.size
	var unit := view.y * 0.5
	_seat_baseline(_reward_label, 0.0, 0.35, 0.06, card_w * 0.84)
	ToonGui.style_label(_reward_label, Color(0, 0, 0), maxi(int(round(0.06 * unit)), 1), Color(0, 0, 0, 0), 0)
	_seat_baseline(_fish_weight, 0.0, -0.28, 0.05, card_w * 0.84)
	ToonGui.style_label(_fish_weight, Color(0, 0, 0), maxi(int(round(0.05 * unit)), 1), Color(0, 0, 0, 0), 0)
	_seat_baseline(_fish_value, 0.0, -0.35, 0.05, card_w * 0.84)
	ToonGui.style_label(_fish_value, Color(0, 0, 0), maxi(int(round(0.05 * unit)), 1), Color(0, 0, 0, 0), 0)
	_seat_baseline(_fish_extra, 0.0, 0.26, 0.08, card_w * 0.84)
	ToonGui.style_sign(_fish_extra, Color(0.2, 0.8, 0.4), maxi(int(round(0.08 * unit)), 1), Color(0, 0, 0, 0), 0)
	if _fish_photo != null and _fish_photo.visible:
		var top_left := _fish_local(-0.3, 0.25)
		var bottom_right := _fish_local(0.3, -0.235)
		_fish_photo.position = Vector2(minf(top_left.x, bottom_right.x), minf(top_left.y, bottom_right.y))
		_fish_photo.size = Vector2(absf(bottom_right.x - top_left.x), absf(bottom_right.y - top_left.y))
	var close := _reward.get_child(_reward.get_child_count() - 1) as Control
	_seat_center(close, 0.275, -0.375, 0.12, 0.12)


func _hide_fish() -> void:
	if _fish_photo != null:
		_fish_photo.call("clear")
	if _fish_weight != null:
		_fish_weight.visible = false
	if _fish_value != null:
		_fish_value.visible = false
	if _fish_extra != null:
		_fish_extra.visible = false
	if _boot_art != null:
		_boot_art.visible = false
	if _boot_name != null:
		_boot_name.visible = false
	if _reward == null or _reward_label == null:
		return
	_reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reward_label.clip_text = false
	ToonGui.style_label(_reward_label, Color(0, 0, 0), 22, Color(0, 0, 0, 0), 0)
	var view := get_viewport().get_visible_rect().size
	_layout_panel(_reward, view, 1.35, 0.85)


func _fish_label(label_name: String) -> Label:
	var label := Label.new()
	label.name = label_name
	label.visible = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward.add_child(label)
	return label


## A dialog-local point, in pixels on the catch card. Z is up.
func _fish_local(lx: float, lz: float) -> Vector2:
	return _card_local(lx, lz, _FISH_SX, _FISH_SZ, _FISH_Z)


func _card_local(lx: float, lz: float, sx: float, sz: float, origin_z: float) -> Vector2:
	var card_w := _DLG_W * sx
	var card_h := _DLG_H * sz
	var left := _DLG_CX * sx - card_w * 0.5
	var top := origin_z + _DLG_CZ * sz + card_h * 0.5
	var fx := (lx - left) / card_w
	var fy := (top - (origin_z + lz)) / card_h
	return Vector2(fx, fy) * _reward.size


## The boot catch uses the item frame: "You caught:" above the boot picture,
## and "An old boot" under it.
func _seat_boot() -> void:
	if _reward == null or _boot_art == null or not _boot_art.visible:
		return
	var view := get_viewport().get_visible_rect().size
	var card_w := _DLG_W * _ITEM_SX
	var card_h := _DLG_H * _ITEM_SZ
	ToonGui.place(_reward, view, _DLG_CX * _ITEM_SX, _ITEM_Z + _DLG_CZ * _ITEM_SZ, card_w, card_h)
	var frame := _reward.get_node("Dialog") as Control
	frame.position = Vector2.ZERO
	frame.size = _reward.size
	var unit := view.y * 0.5
	_seat_on(_reward_label, 0.0, 0.2, 0.08, card_w * 0.8, _ITEM_SX, _ITEM_SZ, _ITEM_Z)
	ToonGui.style_label(_reward_label, Color(0, 0, 0), maxi(int(round(0.08 * unit)), 1), Color(0, 0, 0, 0), 0)
	_seat_on(_boot_name, 0.0, -0.25, 0.06, card_w * 0.8, _ITEM_SX, _ITEM_SZ, _ITEM_Z)
	ToonGui.style_label(_boot_name, Color(0, 0, 0), maxi(int(round(0.06 * unit)), 1), Color(0, 0, 0, 0), 0)
	_place_on(_boot_art, 0.0, 0.0, _BOOT_W, _BOOT_H, _ITEM_SX, _ITEM_SZ, _ITEM_Z)
	var close := _reward.get_child(_reward.get_child_count() - 1) as Control
	_place_on(close, 0.44, -0.24, 0.14, 0.14, _ITEM_SX, _ITEM_SZ, _ITEM_Z)


func _seat_baseline(label: Label, lx: float, lz: float, text_scale: float, width_units: float) -> void:
	_seat_on(label, lx, lz, text_scale, width_units, _FISH_SX, _FISH_SZ, _FISH_Z)


func _seat_on(label: Label, lx: float, lz: float, text_scale: float, width_units: float, sx: float, sz: float, origin_z: float) -> void:
	var at := _card_local(lx, lz, sx, sz, origin_z)
	var px_per_unit := _reward.size.y / (_DLG_H * sz)
	var height := text_scale * px_per_unit
	var width := width_units * _reward.size.x / (_DLG_W * sx)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.size = Vector2(width, height)
	label.position = Vector2(at.x - width * 0.5, at.y - height)


func _seat_center(control: Control, lx: float, lz: float, width_units: float, height_units: float) -> void:
	_place_on(control, lx, lz, width_units, height_units, _FISH_SX, _FISH_SZ, _FISH_Z)


func _place_on(control: Control, lx: float, lz: float, width_units: float, height_units: float, sx: float, sz: float, origin_z: float) -> void:
	var at := _card_local(lx, lz, sx, sz, origin_z)
	var size := Vector2(
		width_units * _reward.size.x / (_DLG_W * sx),
		height_units * _reward.size.y / (_DLG_H * sz)
	)
	control.size = size
	control.position = at - size * 0.5


## OTPTimer draws the count on the white face of alarm_clock. Two digits use
## text scale 0.27, one digit 0.34, and the last five seconds turn red.
func _paint_clock(force: bool) -> void:
	if _clock == null or _clock_face == null:
		return
	var whole := int(ceili(_timer_left))
	if not force and whole == _clock_shown:
		return
	_clock_shown = whole
	var digits := str(whole).length()
	var text_scale := 0.27
	if digits <= 1:
		text_scale = 0.34
	elif digits >= 3:
		text_scale = 0.2
	var view := get_viewport().get_visible_rect().size
	var px := maxi(int(round(text_scale * 0.45 * view.y * 0.5)), 10)
	var late := whole <= 5
	ToonGui.style_label(_clock, Color(1, 0, 0) if late else Color(0, 0, 0), px, Color(0, 0, 0, 0), 0)
	_clock.text = str(whole)
	# alarm_clock.png is 61x61. The face is centered at pixel (28.5, 33.5).
	var face_x := _CLOCK_X + (28.5 / 61.0 - 0.5) * _CLOCK_W
	var face_z := _CLOCK_Z - (33.5 / 61.0 - 0.5) * _CLOCK_H
	ToonGui.place(_clock, view, face_x, face_z, (29.0 / 61.0) * _CLOCK_W, (27.0 / 61.0) * _CLOCK_H)


func _layout_panel(panel: Control, view: Vector2, width: float, height: float) -> void:
	ToonGui.place(panel, view, 0.0, 0.15, width, height)
	var frame := panel.get_node("Dialog") as Control
	frame.position = Vector2.ZERO
	frame.size = panel.size
	var text := panel.get_node("Text") as Control
	text.position = Vector2(panel.size.x * 0.08, panel.size.y * 0.08)
	text.size = Vector2(panel.size.x * 0.84, panel.size.y * 0.62)
	var button := panel.get_child(panel.get_child_count() - 1) as Control
	var side := panel.size.y * 0.22
	button.size = Vector2(side, side)
	button.position = Vector2(panel.size.x * 0.5 + side * 0.2, panel.size.y - side * 1.15)


func _layout_arrow() -> void:
	if _arrow == null or _arrow_tip == null:
		return
	var view := get_viewport().get_visible_rect().size
	var unit := view.y * 0.5
	# The arrow node sits at z=-0.695 in the gui, then the gui scale of 0.67.
	# Roll is around that point, so the control's origin is the pivot.
	var origin := Vector2(view.x * 0.5, view.y * 0.5 + 0.46565 * unit)
	_arrow.position = origin
	_arrow.pivot_offset = Vector2.ZERO
	# The cast heading uses -angle, the same as angleNP.setH. Roll the arrow
	# with that aim so the graphic points where the line goes.
	_arrow.rotation = deg_to_rad(_angle)
	_place_card(_arrow_tip, unit, 0.0, -0.0389, 0.2278, 0.0764)
	var reach := maxf(_power, 0.0)
	_arrow_tail.visible = reach > 0.0
	if reach <= 0.0:
		return
	# arrowTail scale (0.075, 0.075, power * 0.2) on a card about 4 by 3.
	var tail_z := (-0.111 - 0.2974 * reach) * 0.67
	_place_card(_arrow_tail, unit, 0.0054, tail_z, 0.201, 0.402 * reach)


func _place_card(card: Control, unit: float, x: float, z: float, width: float, height: float) -> void:
	var box := Vector2(width, height) * unit
	card.size = box
	card.position = Vector2(x * unit, -z * unit) - box * 0.5


func _card(parent: Node, card_name: String, texture: Texture2D) -> TextureRect:
	var card := TextureRect.new()
	card.name = card_name
	card.texture = texture
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(card)
	return card


func _cast_hover(inside: bool) -> void:
	if _state == "aim":
		_cast_button.modulate = Color(0, 1, 0)
		return
	_cast_button.modulate = Color(1, 1, 0) if inside else Color(1, 0, 0)
