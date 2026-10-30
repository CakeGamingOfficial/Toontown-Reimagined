extends Node

## TutorialStreet.handleEnterTunnel runs the same tunnelOut movie as every
## other shaft: LocalToon.tunnelOut on linktunnel_tt_0's tunnel_origin.
## The far side is still the Toontown Central hole, the first time out.

const _ARRIVAL := preload("res://scenes/playgrounds/playground_toon.gd")
const _LINKS := preload("res://scenes/places/tunnel_links.gd")
const _PLAYGROUND := "res://scenes/playgrounds/toontown_central.tscn"

var _host: Node
var _body: CharacterBody3D
var _player: ToonActor
var _camera: Camera3D


func play(host: Node) -> void:
	_host = host
	_body = host.get_node_or_null("Player") as CharacterBody3D
	_player = _toon()
	_camera = host.get_node_or_null("Camera") as Camera3D
	if _body == null or _player == null:
		queue_free()
		return
	var root: Node = host
	var street := host.get_node_or_null("TutorialStreet") as Node
	if street != null:
		root = street
	var link := _LINKS.find_link(root, "tt", 0)
	var origin: Node3D = null
	if link != null:
		origin = _LINKS.origin_under(link)
	if origin == null:
		queue_free()
		return
	if host.has_method("set_cutscene"):
		host.call("set_cutscene", true)
	_body.velocity = Vector3.ZERO
	await _tunnel_out(origin)
	_ARRIVAL.from_toontorial = true
	get_tree().change_scene_to_file(_PLAYGROUND)


func _tunnel_out(origin: Node3D) -> void:
	var start := _LINKS.local_on(origin, _body.global_position)
	var start_x := clampf(start.x * 0.95, -10.0, 10.0)
	var straight := maxf(absf(start.y - (-6.0)) / _LINKS.run_speed(), 0.15)
	var total := straight + 2.0
	var fade := _blackout()
	fade.color.a = 0.0
	var cam_from := Vector3.ZERO
	if _camera != null:
		cam_from = _camera.global_position
	var elapsed := 0.0
	var previous := Time.get_ticks_msec()
	while elapsed < total:
		await get_tree().process_frame
		if not is_instance_valid(origin) or not is_instance_valid(_body):
			return
		var now := Time.get_ticks_msec()
		var delta := clampf(float(now - previous) / 1000.0, 0.0, 0.05)
		previous = now
		elapsed += delta
		var local := _LINKS.out_local(start, start_x, straight, elapsed)
		_body.global_position = _LINKS.world_on(origin, local)
		var ahead := _LINKS.out_local(start, start_x, straight, elapsed + 0.05)
		var step := _LINKS.world_on(origin, ahead) - _body.global_position
		step.y = 0.0
		var facing := -origin.global_basis.y
		if step.length_squared() > 0.0001:
			facing = step.normalized()
		_face(_LINKS.heading_of(facing))
		if is_instance_valid(_player):
			_player.set_locomotion(_LINKS.run_speed(), false, false, delta)
		_aim_camera(origin, cam_from, clampf(elapsed / 1.0, 0.0, 1.0))
		if elapsed >= total - 0.5:
			fade.color.a = clampf((elapsed - (total - 0.5)) / 0.4, 0.0, 1.0)


func _aim_camera(origin: Node3D, cam_from: Vector3, blend: float) -> void:
	if _camera == null:
		return
	var settle := _LINKS.world_on(origin, Vector3(0.0, 20.0, 12.0))
	var focus := _LINKS.world_on(origin, Vector3(0.0, 0.0, 3.0))
	var eased := blend * blend * (3.0 - 2.0 * blend)
	_camera.global_position = cam_from.lerp(settle, eased)
	if _camera.global_position.distance_squared_to(focus) > 0.01:
		_camera.look_at(focus, Vector3.UP)


func _face(heading: float) -> void:
	if _host != null and _host.has_method("face_actor") and is_instance_valid(_player):
		_host.call("face_actor", _player, heading)


func _blackout() -> ColorRect:
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer: CanvasLayer = null
	if _host != null and _host.has_method("hud"):
		layer = _host.call("hud") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		add_child(layer)
	layer.add_child(fade)
	return fade


func _toon() -> ToonActor:
	if _body == null:
		return null
	for child in _body.get_children():
		if child is ToonActor:
			return child as ToonActor
	return null
