extends Node
class_name RemoteToons

## Other players are DistributedToon copies. The owner walks a local toon.
## Everyone else is built with show_style from that toon's DNA and plays the
## anim state the owner published. Poses arrive about five times a second,
## the old smooth-node broadcast, and this fills in the frames between them.

const _PERIOD := 0.2

var _world: Node
var _body: Node3D
var _actor: ToonActor
var _tags: Nametags
var _own_tags := false
var _place := ""
var _wait := 0.0
var _heading := 0.0
var _speed := 0.0
var _turning := false
var _jumping := false
var _hidden := false
var _anim := ""
var _sent_gm := -1
var _meter: LaffMeter
var _puppets: Dictionary = {}


func bind(world: Node, body: Node3D, actor: ToonActor, tags: Nametags) -> void:
	_world = world
	_body = body
	_actor = actor
	_tags = tags
	_place = _place_of(world)
	if _tags == null:
		_own_tags = true
		_tags = Nametags.new()
		_tags.name = "RemoteNametags"
		var layer := CanvasLayer.new()
		layer.layer = 6
		add_child(layer)
		add_child(_tags)
		_tags.layer = layer
	var net := ToonNet.live()
	if net != null and not net.state_changed.is_connected(_on_state):
		net.state_changed.connect(_on_state)
	for channel in ToonNet.channels("toon:"):
		_apply(channel)


func note(heading: float, speed: float, turning: bool, jumping: bool, hidden: bool) -> void:
	var anim := _anim_name(speed, turning, jumping)
	var changed := anim != _anim or hidden != _hidden
	_heading = heading
	_speed = speed
	_turning = turning
	_jumping = jumping
	_hidden = hidden
	_anim = anim
	if changed:
		_wait = 0.0


func _process(delta: float) -> void:
	if _own_tags and _tags != null:
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			_tags.camera = camera
		_tags.place()
	# setGM is broadcast with the toon. Send the new icon on this frame.
	if MagicWords.gm_type() != _sent_gm:
		_wait = 0.0
	_wait -= delta
	if _wait <= 0.0:
		_wait = _PERIOD
		_send()
	_move_puppets(delta)


func _send() -> void:
	if _body == null or _actor == null or not is_instance_valid(_body):
		return
	var style := ToonRoster.selected_style()
	if style == null:
		return
	var where := _body.global_position
	var av := ToonRoster.avatar_id()
	var gm := MagicWords.gm_type()
	var laff := _laff()
	_sent_gm = gm
	_actor.set_meta("av", av)
	_actor.set_meta("gm", gm)
	ToonNet.submit("toon:%d" % ToonNet.peer_id(), {
		"district": ToonNet.district_id(),
		"district_name": ToonNet.district_name(),
		"place": _place,
		"spot": _place.get_file().get_basename().replace("_", " "),
		"av": av,
		"name": style.display_name(),
		"x": where.x,
		"y": where.y,
		"z": where.z,
		"heading": _heading,
		"anim": _anim,
		"gm": gm,
		"hp": laff.x,
		"max_hp": laff.y,
		"ghost": MagicWords.ghosting(),
		"hidden": _hidden or not _actor.visible,
		"style": style.to_dict(),
	})


func _laff() -> Vector2i:
	if _meter != null and is_instance_valid(_meter) and _meter.loadout() != null:
		var followed := _meter.loadout()
		return Vector2i(followed.hp, followed.max_hp)
	_meter = null
	if _world == null:
		return Vector2i(15, 15)
	for node in _world.find_children("", "LaffMeter", true, false):
		var meter := node as LaffMeter
		if meter != null and meter.loadout() != null:
			_meter = meter
			var followed := meter.loadout()
			return Vector2i(followed.hp, followed.max_hp)
	return Vector2i(15, 15)


func _on_state(channel: String) -> void:
	if channel.begins_with("toon:"):
		_apply(channel)


func _apply(channel: String) -> void:
	var peer := channel.trim_prefix("toon:").to_int()
	if peer == ToonNet.peer_id():
		return
	var state := ToonNet.latest(channel)
	if state.is_empty() or int(state.get("district", -1)) != ToonNet.district_id() or String(state.get("place", "")) != _place:
		_drop(peer)
		return
	if bool(state.get("ghost", false)) or bool(state.get("hidden", false)):
		_hide(peer)
		return
	var puppet: Dictionary = _puppets.get(peer, {})
	var actor: ToonActor = puppet.get("actor")
	var style_key := _style_key(state.get("style", {}))
	if actor == null or not is_instance_valid(actor):
		actor = _create(state)
		if actor == null:
			return
		var tag: Control = null
		if _tags != null:
			tag = _tags.add(actor, String(state.get("name", actor.name)), "toon")
		puppet = {"actor": actor, "tag": tag, "style": style_key}
	elif String(puppet.get("style", "")) != style_key:
		var dressed := ToonStyle.from_dict(state.get("style", {}))
		actor.show_style(dressed)
		puppet["style"] = style_key
	var target := Vector3(float(state.get("x", 0.0)), float(state.get("y", 0.0)), float(state.get("z", 0.0)))
	if actor.global_position.distance_squared_to(target) > 144.0:
		actor.global_position = target
	puppet["pos"] = target
	puppet["heading"] = float(state.get("heading", 0.0))
	puppet["anim"] = String(state.get("anim", "neutral"))
	puppet["seen"] = true
	_puppets[peer] = puppet
	actor.set_meta("av", int(state.get("av", 0)))
	actor.set_meta("gm", int(state.get("gm", 0)))
	actor.set_meta("hp", int(state.get("hp", 15)))
	actor.set_meta("max_hp", int(state.get("max_hp", 15)))
	var dressed: Variant = state.get("style", {})
	if dressed is Dictionary:
		actor.set_meta("style", dressed)
	actor.visible = true
	var tag: Control = puppet.get("tag")
	if tag != null:
		tag.visible = true


func _create(state: Dictionary) -> ToonActor:
	var raw: Variant = state.get("style", {})
	if not (raw is Dictionary):
		return null
	var style := ToonStyle.from_dict(raw)
	var actor := ToonActor.new()
	actor.name = style.display_name()
	if _world != null:
		_world.add_child(actor)
	else:
		add_child(actor)
	actor.show_style(style)
	actor.footsteps = true
	actor.global_position = Vector3(float(state.get("x", 0.0)), float(state.get("y", 0.0)), float(state.get("z", 0.0)))
	_face(actor, float(state.get("heading", 0.0)))
	return actor


func _move_puppets(delta: float) -> void:
	for peer in _puppets.keys():
		var puppet: Dictionary = _puppets[peer]
		var actor: ToonActor = puppet.get("actor")
		if actor == null or not is_instance_valid(actor) or not actor.visible:
			continue
		var target: Vector3 = puppet.get("pos", actor.global_position)
		var blend := clampf(delta / _PERIOD, 0.0, 1.0)
		actor.global_position = actor.global_position.lerp(target, blend)
		var heading := float(puppet.get("heading", 0.0))
		var turn := angle_difference(deg_to_rad(facing(actor)), deg_to_rad(heading))
		_face(actor, facing(actor) + rad_to_deg(turn) * blend)
		var anim := String(puppet.get("anim", "neutral"))
		if anim == "run":
			actor.set_locomotion(9.0, false, false, delta)
		elif anim == "walk":
			actor.set_locomotion(4.0, false, false, delta)
		elif anim == "reverse":
			actor.set_locomotion(-4.0, false, false, delta)
		elif anim == "turn":
			actor.set_locomotion(0.0, true, false, delta)
		elif anim == "jump":
			actor.set_locomotion(4.0, false, true, delta)
		else:
			actor.set_locomotion(0.0, false, false, delta)


func _hide(peer: int) -> void:
	var puppet: Dictionary = _puppets.get(peer, {})
	var actor: ToonActor = puppet.get("actor")
	if actor != null and is_instance_valid(actor):
		actor.visible = false
		actor.set_locomotion(0.0, false, false, 0.0)


func _drop(peer: int) -> void:
	var puppet: Dictionary = _puppets.get(peer, {})
	if puppet.is_empty():
		return
	var actor: ToonActor = puppet.get("actor")
	if _tags != null and actor != null and is_instance_valid(actor):
		_tags.release(actor)
	if actor != null and is_instance_valid(actor):
		actor.queue_free()
	_puppets.erase(peer)


func _exit_tree() -> void:
	for peer in _puppets.keys():
		_drop(int(peer))


func _anim_name(speed: float, turning: bool, jumping: bool) -> String:
	if jumping:
		return "jump"
	if speed >= 8.0:
		return "run"
	if speed > 0.5:
		return "walk"
	if speed < -0.5:
		return "reverse"
	if turning:
		return "turn"
	return "neutral"


func _place_of(world: Node) -> String:
	if world != null and world.is_inside_tree():
		var current := world.get_tree().current_scene
		if current != null and current.scene_file_path != "":
			return current.scene_file_path
	if world == null:
		return ""
	if world.scene_file_path != "":
		return world.scene_file_path
	return String(world.name)


func _style_key(value: Variant) -> String:
	if not (value is Dictionary):
		return ""
	var data: Dictionary = value
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		data.get("head", ""), data.get("torso", ""), data.get("legs", ""),
		data.get("gender", ""), data.get("head_color", 0), data.get("arm_color", 0),
		data.get("leg_color", 0), data.get("top_tex", 0), data.get("top_color", 0),
		data.get("bot_tex", 0), data.get("bot_color", 0), data.get("first_name", ""),
		data.get("last_name", ""),
	]


static func facing(actor: Node3D) -> float:
	var forward := actor.global_transform.basis * Vector3(0, 1, 0)
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return 0.0
	forward = forward.normalized()
	return rad_to_deg(atan2(-forward.x, -forward.z))


func _face(actor: Node3D, heading: float) -> void:
	var body_scale := actor.transform.basis.get_scale().x
	if body_scale < 0.01:
		body_scale = 1.0
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	upright = upright.rotated(Vector3.UP, deg_to_rad(heading))
	actor.transform.basis = upright.scaled(Vector3.ONE * body_scale)
