extends Node
class_name RemoteToons

## Other players are DistributedToon copies. The owner walks a local toon.
## Everyone else is built with show_style from that toon's DNA and plays the
## anim state the owner published. The owner's doodle rides along on that
## same pose. Poses arrive about five times a second, the old smooth-node
## broadcast, and this fills in the frames between them.

const _PERIOD := 0.2
const _KENNEL := preload("res://scenes/pets/doodle_kennel.gd")
const _DOODLE := preload("res://scenes/pets/doodle.gd")
const _CLOSET := preload("res://scenes/catalog/catalog_closet.gd")

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
var _pins: Dictionary = {}


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
	var pet_dna: Array = []
	var pet_name := ""
	var pet_x := where.x
	var pet_y := where.y
	var pet_z := where.z
	var pet_yaw := 0.0
	var pet_anim := "neutral"
	var record := _KENNEL.current()
	var mine = _world.get_node_or_null("Doodle") if _world != null else null
	if not record.is_empty() and mine is Node3D and is_instance_valid(mine):
		var body := mine as Node3D
		for number in record.get("dna", []):
			pet_dna.append(int(number))
		pet_name = String(record.get("name", ""))
		pet_x = body.global_position.x
		pet_y = body.global_position.y
		pet_z = body.global_position.z
		pet_yaw = body.rotation.y
		pet_anim = String(body.call("clip_name"))
	var worn := _CLOSET.accessory_ids()
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
		"accessories": worn,
		"pet_name": pet_name,
		"pet_dna": pet_dna,
		"pet_x": pet_x,
		"pet_y": pet_y,
		"pet_z": pet_z,
		"pet_yaw": pet_yaw,
		"pet_anim": pet_anim,
		"parcel": _actor.carrying_parcel(),
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
	var style_key := _style_key(state.get("style", {})) + "|" + _worn_key(state.get("accessories", {}))
	if actor == null or not is_instance_valid(actor):
		actor = _create(state)
		if actor == null:
			return
		var tag: Control = null
		if _tags != null:
			tag = _tags.add(actor, String(state.get("name", actor.name)), "toon")
		var kept_pet = puppet.get("pet")
		var kept_key := String(puppet.get("pet_key", ""))
		puppet = {"actor": actor, "tag": tag, "style": style_key, "pet": kept_pet, "pet_key": kept_key}
	elif String(puppet.get("style", "")) != style_key:
		var dressed := ToonStyle.from_dict(state.get("style", {}))
		actor.show_style(dressed)
		_wear(actor, state)
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
	if bool(actor.get_meta("gone_sad", false)):
		actor.visible = false
		var hidden_tag: Control = puppet.get("tag")
		if hidden_tag != null:
			hidden_tag.visible = false
		var sad_pet = puppet.get("pet")
		if sad_pet is Node3D and is_instance_valid(sad_pet):
			(sad_pet as Node3D).visible = false
		return
	var dressed: Variant = state.get("style", {})
	if dressed is Dictionary:
		actor.set_meta("style", dressed)
	actor.visible = true
	actor.hold_parcel(bool(state.get("parcel", false)))
	var shown: Control = puppet.get("tag")
	if shown != null:
		shown.visible = true
	_sync_pet(peer, puppet, state)


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
	_wear(actor, state)
	actor.hold_parcel(bool(state.get("parcel", false)))
	actor.footsteps = true
	actor.global_position = Vector3(float(state.get("x", 0.0)), float(state.get("y", 0.0)), float(state.get("z", 0.0)))
	_face(actor, float(state.get("heading", 0.0)))
	return actor


func pin(peer: int, point: Vector3, heading: float) -> void:
	_pins[peer] = {"pos": point, "heading": heading}
	var actor := actor_for(peer)
	if actor == null:
		return
	actor.global_position = point
	_face(actor, heading)


func unpin(peer: int) -> void:
	_pins.erase(peer)


func unpin_all() -> void:
	_pins.clear()


func actor_for(peer: int) -> ToonActor:
	var puppet: Dictionary = _puppets.get(peer, {})
	var actor: ToonActor = puppet.get("actor")
	if actor != null and is_instance_valid(actor):
		return actor
	return null


func _move_puppets(delta: float) -> void:
	for peer in _puppets.keys():
		var puppet: Dictionary = _puppets[peer]
		_move_pet(puppet, delta)
		var actor: ToonActor = puppet.get("actor")
		if actor == null or not is_instance_valid(actor) or not actor.visible:
			continue
		if _pins.has(peer):
			var pinned: Dictionary = _pins[peer]
			actor.global_position = pinned.get("pos", actor.global_position)
			_face(actor, float(pinned.get("heading", 0.0)))
			actor.set_swimming(false)
			continue
		var target: Vector3 = puppet.get("pos", actor.global_position)
		var blend := clampf(delta / _PERIOD, 0.0, 1.0)
		actor.global_position = actor.global_position.lerp(target, blend)
		var heading := float(puppet.get("heading", 0.0))
		var turn := angle_difference(deg_to_rad(facing(actor)), deg_to_rad(heading))
		_face(actor, facing(actor) + rad_to_deg(turn) * blend)
		var anim := String(puppet.get("anim", "neutral"))
		actor.set_sad(anim == "sad-walk" or anim == "sad-neutral")
		actor.set_swimming(actor.under_water())
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
		elif anim == "sad-walk":
			actor.set_locomotion(4.0, false, false, delta)
		elif anim == "sad-neutral":
			actor.set_locomotion(0.0, false, false, delta)
		else:
			actor.set_locomotion(0.0, false, false, delta)


func _hide(peer: int) -> void:
	var puppet: Dictionary = _puppets.get(peer, {})
	var actor: ToonActor = puppet.get("actor")
	if actor != null and is_instance_valid(actor):
		actor.visible = false
		actor.set_swimming(false)
		actor.set_locomotion(0.0, false, false, 0.0)
	var pet = puppet.get("pet")
	if pet is Node3D and is_instance_valid(pet):
		(pet as Node3D).visible = false


func _drop(peer: int) -> void:
	var puppet: Dictionary = _puppets.get(peer, {})
	if puppet.is_empty():
		return
	var actor: ToonActor = puppet.get("actor")
	if _tags != null and actor != null and is_instance_valid(actor):
		_tags.release(actor)
	if actor != null and is_instance_valid(actor):
		actor.queue_free()
	_free_pet(puppet)
	_puppets.erase(peer)
	_pins.erase(peer)


func _exit_tree() -> void:
	for peer in _puppets.keys():
		_drop(int(peer))


func _sync_pet(peer: int, puppet: Dictionary, state: Dictionary) -> void:
	var raw: Variant = state.get("pet_dna", [])
	var pet = puppet.get("pet")
	if not (raw is Array) or (raw as Array).size() < 9:
		_free_pet(puppet)
		return
	var dna: Array = raw
	var pet_name := String(state.get("pet_name", ""))
	var key := _pet_key(dna, pet_name)
	if pet == null or not is_instance_valid(pet):
		pet = _DOODLE.new()
		pet.name = "RemoteDoodle%d" % peer
		pet.remote = true
		if _world != null:
			_world.add_child(pet)
		else:
			add_child(pet)
		pet.show_pet(dna, pet_name)
		puppet["pet"] = pet
		puppet["pet_key"] = key
	elif String(puppet.get("pet_key", "")) != key:
		pet.show_pet(dna, pet_name)
		puppet["pet_key"] = key
	var node := pet as Node3D
	if node == null:
		return
	node.visible = true
	var point := Vector3(float(state.get("pet_x", 0.0)), float(state.get("pet_y", 0.0)), float(state.get("pet_z", 0.0)))
	var anim := String(state.get("pet_anim", "neutral"))
	var previous := String(puppet.get("shown_trick", ""))
	puppet["pet_pos"] = point
	puppet["pet_yaw"] = float(state.get("pet_yaw", 0.0))
	puppet["pet_anim"] = anim
	if anim != previous:
		puppet["shown_trick"] = anim
		_heal_from_trick(node, anim)
	if node.global_position.distance_squared_to(point) > 144.0:
		node.global_position = point
		node.rotation.y = float(puppet["pet_yaw"])


func _heal_from_trick(node: Node3D, anim: String) -> void:
	var amount := 0
	if anim == "jump":
		amount = 5
	elif anim == "toBeg":
		amount = 6
	elif anim == "playDead":
		amount = 7
	elif anim == "rollover":
		amount = 8
	elif anim == "backflip":
		amount = 9
	elif anim == "dance":
		amount = 10
	elif anim == "speak":
		amount = 11
	if amount <= 0 or _body == null or not is_instance_valid(_body):
		return
	if node.global_position.distance_to(_body.global_position) > 15.0:
		return
	var host := get_parent()
	if host != null and host.has_method("heal"):
		host.heal(amount)


func _move_pet(puppet: Dictionary, delta: float) -> void:
	var pet = puppet.get("pet")
	if not (pet is Node3D) or not is_instance_valid(pet):
		return
	var node := pet as Node3D
	if not node.visible:
		return
	var target: Vector3 = puppet.get("pet_pos", node.global_position)
	var blend := clampf(delta / _PERIOD, 0.0, 1.0)
	node.global_position = node.global_position.lerp(target, blend)
	node.rotation.y = lerp_angle(node.rotation.y, float(puppet.get("pet_yaw", node.rotation.y)), blend)
	node.call("use_remote", String(puppet.get("pet_anim", "neutral")))


func _free_pet(puppet: Dictionary) -> void:
	var pet = puppet.get("pet")
	if pet != null and is_instance_valid(pet):
		pet.queue_free()
	puppet.erase("pet")
	puppet.erase("pet_key")


func _pet_key(dna: Array, pet_name: String) -> String:
	var parts: PackedStringArray = []
	for number in dna:
		parts.append(str(int(number)))
	parts.append(pet_name)
	return "|".join(parts)


func _anim_name(speed: float, turning: bool, jumping: bool) -> String:
	if _actor != null and _actor.is_sad():
		if absf(speed) > 0.5 or turning:
			return "sad-walk"
		return "sad-neutral"
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


func _wear(actor: ToonActor, state: Dictionary) -> void:
	var worn: Variant = state.get("accessories", {})
	if worn is Dictionary:
		actor.wear_accessories(worn)
	else:
		actor.wear_accessories({})


func _worn_key(value: Variant) -> String:
	if not (value is Dictionary):
		return ""
	var worn: Dictionary = value
	var slots: Array = worn.keys()
	slots.sort()
	var bits := ""
	for slot in slots:
		bits += "%s=%s," % [slot, worn[slot]]
	return bits


func _style_key(value: Variant) -> String:
	if not (value is Dictionary):
		return ""
	var data: Dictionary = value
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		data.get("head", ""), data.get("torso", ""), data.get("legs", ""),
		data.get("gender", ""), data.get("head_color", 0), data.get("arm_color", 0),
		data.get("leg_color", 0), data.get("top_tex", 0), data.get("top_color", 0),
		data.get("bot_tex", 0), data.get("bot_color", 0), data.get("top_map", ""),
		data.get("sleeve_map", ""), data.get("bottom_map", ""), data.get("first_name", ""),
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
