extends Node

## TutorialStreet.handleEnterTunnel, then the local toon's tunnelOut run.
## The path is the same one tutorial_blocker uses when Flippy runs into the shaft.

const _ARRIVAL := preload("res://scenes/playgrounds/playground_toon.gd")
const _PLAYGROUND := "res://scenes/playgrounds/toontown_central.tscn"
const SHIFT_X := -86.09453
const SHIFT_Y := -19.84808
const FEET_Y := 0.2

var _host: Node
var _body: CharacterBody3D
var _player: ToonActor
var _running := false


func play(host: Node) -> void:
	_host = host
	_body = host.get_node_or_null("Player") as CharacterBody3D
	_player = _toon()
	if _body == null or _player == null:
		queue_free()
		return
	if host.has_method("set_cutscene"):
		host.call("set_cutscene", true)
	_body.velocity = Vector3.ZERO
	_running = true
	await _run_off()
	_running = false
	await _fade_out()
	_ARRIVAL.from_toontorial = true
	get_tree().change_scene_to_file(_PLAYGROUND)


func _process(delta: float) -> void:
	if not _running or not is_instance_valid(_player):
		return
	_player.set_locomotion(8.0, false, false, delta)
	if _host != null and _host.has_method("settle_camera"):
		_host.call("settle_camera")


func _run_off() -> void:
	_face(270.0)
	await get_tree().create_timer(0.5).timeout
	await _slide(_street(Vector3(217.4, 18.81, -0.475)), 240.0, 0.75)
	await _slide(_street(Vector3(222.4, 15.0, -0.475)), 180.0, 0.35)
	await _slide(_street(Vector3(222.4, 5.0, -0.475)), 180.0, 0.75)


func _slide(target: Vector3, heading: float, seconds: float) -> void:
	if not is_instance_valid(_body):
		return
	_face(heading)
	var start := _body.global_position
	var tween := create_tween()
	tween.tween_method(_along.bind(start, target), 0.0, 1.0, seconds)
	await tween.finished


func _along(t: float, start: Vector3, target: Vector3) -> void:
	if not is_instance_valid(_body):
		return
	var next := start.lerp(target, t)
	next.y = FEET_Y
	_body.global_position = next


func _face(heading: float) -> void:
	if _host != null and _host.has_method("face_actor") and is_instance_valid(_player):
		_host.call("face_actor", _player, heading)


func _fade_out() -> void:
	if _host == null or not _host.has_method("hud"):
		return
	var hud := _host.call("hud") as CanvasLayer
	if hud == null:
		return
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.4)
	await tween.finished


func _toon() -> ToonActor:
	if _body == null:
		return null
	for child in _body.get_children():
		if child is ToonActor:
			return child as ToonActor
	return null


func _street(panda: Vector3) -> Vector3:
	return Vector3(panda.x + SHIFT_X, FEET_Y, -(panda.y + SHIFT_Y))
