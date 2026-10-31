extends Node

## Quest script tutorial_mickey. Mickey runs in with the new toon, asks if
## they have gags, and leaves Tutorial Tom to explain the Cogs. The camera
## is the script camera at panda (11, 7, 3) heading 52 until the toon is
## freed on the rug.

const _HOME := Vector3(0.0, 0.2, 0.0)
const _TOON_END := Vector3(-1.8, 0.2, -14.4)
const _MICKEY_END := Vector3(0.0, 0.2, -17.0)
const _CAM_POS := Vector3(11.0, 3.0, -7.0)
# Panda heading 52 looks along (-sin 52, cos 52). That is Godot (-sin 52, 0, -cos 52).
const _CAM_LOOK := Vector3(-0.7880, 0.0, -0.6157)
const _ASK := "Toontown has a new citizen! Do you have some extra gags?"
const _SURE := "Sure, Mickey!"
const _COGS := "Tutorial Tom will tell you all about the Cogs."
const _GO := "Gotta go!"
const _STEPS := "res://assets/audio/sfx/AV_footstep_runloop.mp3"

var _host: Node
var _body: CharacterBody3D
var _toon: ToonActor
var _mickey: Mickey
var _camera: Camera3D
var _tom: Node3D
var _bubble: PanelContainer
var _speaker: Node3D
var _steps: AudioStreamPlayer
var _step := 0
var _time := 0.0
var _anim_time := 0.0
var _waiting := false
var _active := false


func play(host: Node) -> void:
	_host = host
	_body = host.get_node_or_null("Player") as CharacterBody3D
	_camera = host.get_node_or_null("Camera") as Camera3D
	_tom = host.get_node_or_null("Tutorial Tom") as Node3D
	if _body == null or _camera == null:
		return
	for child in _body.get_children():
		if child is ToonActor:
			_toon = child as ToonActor
			break
	if _toon == null:
		return
	_mickey = Mickey.new()
	_mickey.name = "Mickey"
	host.add_child(_mickey)
	if not _mickey.loaded():
		_mickey.queue_free()
		_mickey = null
		return
	host.call("add_nametag", _mickey, "Mickey", Color(0.6, 0.4, 0.2))
	host.call("adopt_billboards", _mickey)
	# tutorial_mickey poses localToon in the shot. A quest close-up hides
	# the player; this run-in does not.
	host.call("set_cutscene", true, false)
	host.call("hold_camera", true)
	_toon.visible = true
	host.call("place_player", _HOME, 0.0)
	_stand_mickey(_HOME, 0.0)
	_aim_camera()
	_build_bubble()
	_active = true


func _process(delta: float) -> void:
	if not _active:
		return
	_aim_camera()
	_anim_time += delta
	if not _waiting:
		var limit := _limit()
		_time += delta
		if limit > 0.0 and _time >= limit:
			_time = 0.0
			_step += 1
			_enter_step()
	if not _active:
		return
	# Signs face the camera first. Mickey's pose has to be the last write
	# this frame, or a billboard yaw lands on the ears after the clip.
	_host.call("face_billboards")
	_move()
	_animate(delta)
	_place_bubble()


func _input(event: InputEvent) -> void:
	if not _waiting:
		return
	var click := false
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		click = button.pressed and button.button_index == MOUSE_BUTTON_LEFT
	if not click and not event.is_action_pressed("ui_accept"):
		return
	_waiting = false
	_time = 0.0
	_step += 1
	_enter_step()
	get_viewport().set_input_as_handled()


func _enter_step() -> void:
	if _step == 4:
		_show_line(_ASK, _mickey)
	elif _step == 6:
		var speaker: Node3D = _tom if _tom != null else _mickey
		_show_line(_SURE, speaker)
	elif _step == 8:
		_show_line(_COGS, _mickey)
	elif _step == 9:
		_show_line(_GO, _mickey)
	elif _step >= 12:
		_finish()


func _limit() -> float:
	if _step == 0:
		return 2.0
	if _step == 1 or _step == 11:
		return 2.0
	if _step == 2 or _step == 10:
		return 0.5
	if _step == 3:
		return 1.63
	if _step == 5 or _step == 7:
		return 1.0867
	return 0.0


func _running() -> bool:
	return _step == 1 or _step == 2 or _step == 10 or _step == 11


func _move() -> void:
	var toon_pos := _TOON_END
	var mickey_pos := _MICKEY_END
	var toon_h := -70.0
	var mickey_h := -120.0
	if _step == 0:
		toon_pos = _HOME
		mickey_pos = _HOME
		toon_h = 0.0
		mickey_h = 0.0
	elif _step == 1:
		var weight := _ease(_time / 2.0)
		toon_pos = _HOME.lerp(_TOON_END, weight)
		mickey_pos = _HOME.lerp(_MICKEY_END, weight)
		toon_h = 0.0
		mickey_h = 0.0
	elif _step == 2:
		var weight := _ease(_time / 0.5)
		toon_h = lerpf(0.0, -70.0, weight)
		mickey_h = lerpf(0.0, -120.0, weight)
	elif _step == 10:
		mickey_h = lerpf(-120.0, -180.0, _ease(_time / 0.5))
	elif _step == 11:
		mickey_pos = _MICKEY_END.lerp(_HOME, _ease(_time / 2.0))
		mickey_h = -180.0
	_toon.visible = true
	_host.call("place_player", toon_pos, toon_h)
	_stand_mickey(mickey_pos, mickey_h)


func _animate(delta: float) -> void:
	if _running():
		_toon.play_run(delta)
		_start_steps()
	else:
		_toon.set_locomotion(0.0, false, false, delta)
		_stop_steps()
	if _step == 0 or _step == 6:
		_mickey.pose("wait", _anim_time, 1.0, true)
	elif _step == 1 or _step == 2 or _step == 10 or _step == 11:
		_mickey.pose("run", _anim_time, 1.0, true)
	elif _step == 3:
		_mickey.pose("left-start", _time, 1.0, false)
	elif _step == 4:
		_mickey.pose("left", _anim_time, 1.0, true)
	elif _step == 5:
		_mickey.pose("left-start", _time, -1.5, false)
	elif _step == 7:
		_mickey.pose("right-start", _time, 1.0, false)
	elif _step == 8 or _step == 9:
		_mickey.pose("right", _anim_time, 1.0, true)


func _stand_mickey(where: Vector3, heading: float) -> void:
	_mickey.position = where
	_mickey.rotation.y = deg_to_rad(heading)


func _ease(amount: float) -> float:
	var clamped := clampf(amount, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)


func _aim_camera() -> void:
	if _camera == null:
		return
	_camera.global_position = _CAM_POS
	_camera.look_at(_CAM_POS + _CAM_LOOK, Vector3.UP)


func _start_steps() -> void:
	if _steps != null and _steps.playing:
		return
	var stream := load(_STEPS) as AudioStreamMP3
	if stream == null:
		return
	stream = stream.duplicate() as AudioStreamMP3
	stream.loop = true
	if _steps == null:
		_steps = ToonAudio.effect_player()
		_steps.name = "RunSteps"
		add_child(_steps)
	_steps.stream = stream
	_steps.play()


func _stop_steps() -> void:
	if _steps != null and _steps.playing:
		_steps.stop()


func _build_bubble() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	panel.z_index = 16
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.96)
	box.border_color = Color(0, 0, 0)
	box.set_border_width_all(3)
	box.set_corner_radius_all(16)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(340, 0)
	ToonGui.style_label(label, Color(0.05, 0.05, 0.05), 22, Color(0, 0, 0, 0), 0)
	column.add_child(label)
	var hint := Label.new()
	hint.text = "Click to continue"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ToonGui.style_label(hint, Color(0.35, 0.35, 0.35), 16, Color(0, 0, 0, 0), 0)
	column.add_child(hint)
	var layer := _host.call("hud") as CanvasLayer
	layer.add_child(panel)
	_bubble = panel


func _show_line(text: String, speaker: Node3D) -> void:
	_speaker = speaker
	var label := _bubble.get_child(0).get_child(0) as Label
	label.text = text
	_bubble.visible = true
	_waiting = true
	ToonSpeech.speak(speaker, text)
	_place_bubble()


func _place_bubble() -> void:
	if _bubble == null or not _bubble.visible or _speaker == null or _camera == null:
		return
	var point := _speaker.global_position + Vector3(0.0, 4.6, 0.0)
	if _camera.is_position_behind(point):
		return
	_bubble.reset_size()
	var screen := _camera.unproject_position(point)
	_bubble.position = screen - _bubble.size * Vector2(0.5, 1.0) + Vector2(0.0, -16.0)


func _finish() -> void:
	_active = false
	_waiting = false
	_stop_steps()
	if _bubble:
		_bubble.queue_free()
		_bubble = null
	if _mickey:
		_mickey.queue_free()
		_mickey = null
	_toon.set_locomotion(0.0, false, false, 0.0)
	# FREE_LOCALTOON puts the toon on the rug. Panda (1.6, 9.8, 0) heading 14.
	_host.call("place_player", Vector3(1.6, 0.2, -9.8), 14.0)
	_host.call("hold_camera", false)
	_host.call("set_cutscene", false)
	_host.call("settle_camera")
	queue_free()
