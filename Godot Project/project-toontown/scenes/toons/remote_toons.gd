extends Node
class_name RemoteToons

## Other players are DistributedToon copies. The owner walks a local toon.
## Everyone else is built with show_style from that toon's DNA and plays the
## anim state the owner published. The owner's doodle rides along on that
## same pose. Poses arrive about five times a second, the old smooth-node
## broadcast, and this fills in the frames between them.

const _PERIOD := 0.2
# Farther than ~run travels in a few broadcasts. A door or ~tp is much farther.
const _SNAP := 96.0
const _KENNEL := preload("res://scenes/pets/doodle_kennel.gd")
const _DOODLE := preload("res://scenes/pets/doodle.gd")
const _CLOSET := preload("res://scenes/catalog/catalog_closet.gd")
const _PORTAL := preload("res://scenes/playgrounds/teleport_portal.gd")
const _DOOR := preload("res://scenes/interiors/door_motion.gd")
const _SHOP_DOOR := preload("res://scenes/interiors/shop_door.gd")
const _HOUSE_DOOR := preload("res://scenes/interiors/house_door.gd")
const _GAG_DOOR := preload("res://scenes/interiors/gag_shop_door.gd")
const _PET_DOOR := preload("res://scenes/interiors/pet_shop_door.gd")
const _KART_DOOR := preload("res://scenes/interiors/kart_shop_door.gd")
const _HALL_DOOR := preload("res://scenes/interiors/toon_hall_door.gd")
const _LIB_DOOR := preload("res://scenes/interiors/library_door.gd")
const _BANK_DOOR := preload("res://scenes/interiors/bank_door.gd")
const _HQ_DOOR := preload("res://scenes/interiors/toon_hq_door.gd")
const _TELEPORT_SFX := "res://assets/audio/sfx/AV_teleport.ogg"
# Toon.getTeleportOutTrack. The hole leaves the hand at 1.708 and the clip ends at 3.4.
const _OUT_TIME := 3.4
const _SOUND_AT := 0.5
const _DROP_AT := 1.708
const _IN_OPEN := 0.3
const _IN_HOLD := 0.6
const _JUMP_FROM := 0.45

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
var _arrival := false
var _clip_pose := -1.0
var _sent_pose_anim := ""
var _door_path := ""
var _door_kind := ""
var _door_stamp := 0
var _door_pos := Vector3.ZERO
var _door_tokens: Dictionary = {}
var _fishing := false
var _fish_pose := -1.0
var _fish_rod := 0
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
	var changed := anim != _anim or hidden != _hidden or _fishing or _arrival
	_heading = heading
	_speed = speed
	_turning = turning
	_jumping = jumping
	_hidden = hidden
	_anim = anim
	_arrival = false
	_fishing = false
	_fish_pose = -1.0
	if changed:
		_wait = 0.0


## The trolley publishes sit instead of a walk speed. A change goes out immediately.
func note_anim(heading: float, anim: String) -> void:
	# The teleport movie owns the channel until the hole finishes.
	if _arrival:
		return
	var changed := anim != _anim or _fishing
	_heading = heading
	_speed = 0.0
	_turning = false
	_jumping = false
	_anim = anim
	_fishing = false
	_fish_pose = -1.0
	if changed:
		_wait = 0.0


## Teleport out and teleport in. pose is seconds into that movie.
func note_clip(heading: float, anim: String, pose: float) -> void:
	var changed := anim != _anim or not _arrival
	_heading = heading
	_speed = 0.0
	_turning = false
	_jumping = false
	_hidden = false
	_fishing = false
	_fish_pose = -1.0
	_arrival = true
	_anim = anim
	_clip_pose = pose
	if changed:
		_wait = 0.0


func published_anim() -> String:
	return _anim


## DistributedDoor.setState. The owner names the door they just opened.
func note_door(door: Node3D, kind: String) -> void:
	if door == null or not is_instance_valid(door):
		return
	var scene := get_tree().current_scene if get_tree() != null else null
	if scene == null:
		return
	_door_path = str(scene.get_path_to(door))
	_door_kind = kind
	_door_pos = door.global_position
	_door_stamp = Time.get_ticks_msec()
	_wait = 0.0


## The fishing spot plays castlong by pose time. pose is -1 when the clip runs on its own.
func note_fishing(heading: float, anim: String, pose: float, rod: int) -> void:
	if _arrival:
		return
	var changed := anim != _anim or rod != _fish_rod or absf(pose - _fish_pose) > 0.12 or not _fishing
	_heading = heading
	_speed = 0.0
	_turning = false
	_jumping = false
	_hidden = false
	_anim = anim
	_fishing = true
	_fish_pose = pose
	_fish_rod = rod
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
	# A teleport, the shticker book, or an emote replaces the walk the moment it starts.
	var posed := ""
	if _actor != null and is_instance_valid(_actor) and not _arrival:
		posed = _actor.remote_anim()
	if posed != _sent_pose_anim:
		_sent_pose_anim = posed
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
	# A quest close-up hides the local mesh because the camera sits on that
	# spot. Other toons still see you standing where the movie left you.
	var anim := _anim
	var clip_pose := -1.0
	if _arrival:
		clip_pose = _clip_pose
	else:
		var posed := _actor.remote_anim()
		if posed != "":
			anim = posed
			clip_pose = _actor.remote_pose_time()
	var concealed := _hidden or not _actor.visible
	if _world != null and _world.has_method("in_cutscene") and bool(_world.call("in_cutscene")):
		concealed = false
	# The arrival hole hides the local mesh until the leap. Other toons still play it.
	if not MagicWords.ghosting() and (_arrival or anim == "teleport" or anim == "book" or _battle_clip(anim)):
		concealed = false
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
		"speed": _speed,
		"anim": anim,
		"clip_pose": clip_pose,
		"door_path": _door_path if _door_stamp > 0 and Time.get_ticks_msec() - _door_stamp < 3000 else "",
		"door_kind": _door_kind if _door_stamp > 0 and Time.get_ticks_msec() - _door_stamp < 3000 else "",
		"door_stamp": _door_stamp if _door_stamp > 0 and Time.get_ticks_msec() - _door_stamp < 3000 else 0,
		"door_x": _door_pos.x,
		"door_y": _door_pos.y,
		"door_z": _door_pos.z,
		"fishing": _fishing,
		"pose": _fish_pose,
		"rod": _fish_rod,
		"gm": gm,
		"hp": laff.x,
		"max_hp": laff.y,
		"held": _held(),
		"promo": [
			DisguisePage.ready_for_promotion(0),
			DisguisePage.ready_for_promotion(1),
			DisguisePage.ready_for_promotion(2),
			DisguisePage.ready_for_promotion(3),
		],
		"ghost": MagicWords.ghosting(),
		"asleep": MagicWords.asleep(),
		"instant_kill": MagicWords.instant_kill(),
		"hidden": concealed,
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
		"suit_type": _sellbot_type(),
		"suit_level": int(DisguisePage.suit_progress(3).get("level", 0)),
		"suit_ready": DisguisePage.suit_complete(3),
		"vp_ready": bool(_actor.get_meta("vp_ready", false)) if _actor != null else false,
		"exp": _experience(),
	})


func _experience() -> Array:
	var loadout := ToonLoadout.for_selected()
	var points: Array = []
	if loadout == null:
		return points
	for track in ToonLoadout.TRACK_COUNT:
		points.append(loadout.experience_of(track))
	return points


func _sellbot_type() -> int:
	# A finished suit is the one they are climbing. Otherwise the elevator uses a Cold Caller.
	if not DisguisePage.suit_complete(3):
		return 0
	return clampi(int(DisguisePage.suit_progress(3).get("type", 0)), 0, 7)


func _held() -> bool:
	var host := get_parent()
	if host == null:
		return false
	var toon := host.get_node_or_null("PlaygroundToon")
	if toon == null or not ("_battle_hold" in toon):
		return false
	return bool(toon.get("_battle_hold"))


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
		# Leaving the zone used to delete the toon on the spot. Finish the hole first.
		if _keep_teleport(peer):
			return
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
	# ~run covers more than a normal step between broadcasts. Snapping that
	# gap plants the toon on each packet, so the walk never reads. Only a
	# real teleport should jump.
	var jumped := actor.global_position.distance_squared_to(target) > _SNAP * _SNAP
	if jumped:
		actor.global_position = target
	puppet["pos"] = target
	puppet["heading"] = float(state.get("heading", 0.0))
	puppet["speed"] = float(state.get("speed", 0.0))
	puppet["anim"] = String(state.get("anim", "neutral"))
	puppet["clip_pose"] = float(state.get("clip_pose", -1.0))
	puppet["pose_msec"] = Time.get_ticks_msec()
	puppet["departing"] = false
	puppet["fishing"] = bool(state.get("fishing", false))
	puppet["pose"] = float(state.get("pose", -1.0))
	puppet["rod"] = int(state.get("rod", 0))
	puppet["seen"] = true
	var swung := int(state.get("door_stamp", 0))
	if swung > 0 and swung != int(puppet.get("door_stamp", 0)):
		puppet["door_stamp"] = swung
		_play_remote_door(String(state.get("door_path", "")), String(state.get("door_kind", "")), Vector3(float(state.get("door_x", 0.0)), float(state.get("door_y", 0.0)), float(state.get("door_z", 0.0))))
	_puppets[peer] = puppet
	actor.set_meta("peer", peer)
	actor.set_meta("av", int(state.get("av", 0)))
	actor.set_meta("gm", int(state.get("gm", 0)))
	actor.set_meta("hp", int(state.get("hp", 15)))
	actor.set_meta("max_hp", int(state.get("max_hp", 15)))
	if bool(actor.get_meta("ran_home", false)) and jumped:
		actor.set_meta("ran_home", false)
	elif bool(actor.get_meta("gone_sad", false)) or bool(actor.get_meta("ran_home", false)):
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
		if actor == null or not is_instance_valid(actor):
			continue
		if bool(puppet.get("departing", false)):
			actor.visible = true
			_play_portal(actor, puppet, "teleport")
			if _elapsed_pose(puppet) >= _OUT_TIME:
				_drop(int(peer))
			continue
		if not actor.visible and String(puppet.get("anim", "")) != "arrival":
			continue
		if _pins.has(peer):
			var pinned: Dictionary = _pins[peer]
			actor.global_position = pinned.get("pos", actor.global_position)
			_face(actor, float(pinned.get("heading", 0.0)))
			actor.set_swimming(false)
			# The battle slot used to freeze the body. Duck, lose, and the
			# victory dance are published on the same channel as a teleport.
			var pinned_anim := String(puppet.get("anim", ""))
			var has_pose := float(puppet.get("clip_pose", -1.0)) >= 0.0
			var frame_now := Engine.get_process_frames()
			var posed_frame := int(actor.get_meta("pose_frame", -1))
			var posed_this_frame := posed_frame == frame_now
			var owned := String(actor.get_meta("net_clip", ""))
			var showing := actor.remote_anim()
			if _battle_clip(pinned_anim) and has_pose and not posed_this_frame:
				_clear_portal(actor, puppet)
				actor.hide_remote_book()
				actor.pose_action(pinned_anim, _elapsed_pose(puppet))
				actor.set_meta("net_clip", pinned_anim)
			elif not posed_this_frame and owned != "" and owned == showing:
				actor.release_pose()
				actor.set_locomotion(0.0, false, false, 0.0)
				actor.remove_meta("net_clip")
			continue
		var target: Vector3 = puppet.get("pos", actor.global_position)
		var blend := clampf(delta / _PERIOD, 0.0, 1.0)
		actor.global_position = actor.global_position.lerp(target, blend)
		var heading := float(puppet.get("heading", 0.0))
		var turn := angle_difference(deg_to_rad(facing(actor)), deg_to_rad(heading))
		_face(actor, facing(actor) + rad_to_deg(turn) * blend)
		var anim := String(puppet.get("anim", "neutral"))
		actor.set_sad(anim == "sad-walk" or anim == "sad-neutral")
		if bool(puppet.get("fishing", false)):
			_clear_portal(actor, puppet)
			_play_fishing(actor, puppet, anim, delta)
			continue
		_drop_pole(puppet)
		if anim == "teleport" or anim == "arrival":
			_play_portal(actor, puppet, anim)
			continue
		if anim == "book":
			_clear_portal(actor, puppet)
			actor.set_swimming(false)
			actor.pose_remote_book(float(puppet.get("clip_pose", 0.0)))
			continue
		if _held_clip(anim) and float(puppet.get("clip_pose", -1.0)) >= 0.0:
			_clear_portal(actor, puppet)
			actor.hide_remote_book()
			actor.set_swimming(false)
			# The lineup pins a toon while the victory dance plays. After the
			# fight, the last "victory" update must not lock the body again.
			# The SpeedChat dance is the same clip, played as a gesture.
			if anim == "victory":
				if String(puppet.get("emote", "")) != "victory":
					puppet["emote"] = "victory"
					actor.play_gesture("victory", 1.0, false)
				continue
			puppet["emote"] = ""
			actor.pose_action(anim, _elapsed_pose(puppet))
			continue
		_clear_portal(actor, puppet)
		actor.hide_remote_book()
		actor.set_swimming(actor.under_water())
		if String(puppet.get("emote", "")) == "victory":
			puppet["emote"] = ""
			actor.clear_gesture()
		if anim == "sit":
			actor.pose_synced_loop("sit")
			continue
		if anim == "sit-start":
			actor.release_pose()
			actor.play_gesture("sit-start", 1.0, false)
			actor.set_locomotion(0.0, false, false, delta)
			continue
		actor.release_pose()
		var speed := float(puppet.get("speed", 0.0))
		if anim == "run":
			actor.set_locomotion(speed if speed >= 8.0 else 9.0, false, false, delta)
		elif anim == "walk":
			var paced := speed
			if paced <= 0.5 or paced >= 8.0:
				paced = 4.0
			actor.set_locomotion(paced, false, false, delta)
		elif anim == "reverse":
			actor.set_locomotion(speed if speed < -0.5 else -4.0, false, false, delta)
		elif anim == "turn":
			actor.set_locomotion(0.0, true, false, delta)
		elif anim == "jump":
			var hopping := speed if absf(speed) > 0.5 else 4.0
			actor.set_locomotion(hopping, false, true, delta)
		elif anim == "sad-walk":
			actor.set_locomotion(speed if absf(speed) > 0.5 else 4.0, false, false, delta)
		elif anim == "sad-neutral":
			actor.set_locomotion(0.0, false, false, delta)
		else:
			actor.set_locomotion(0.0, false, false, delta)


func _held_clip(anim: String) -> bool:
	return anim != "neutral" and anim != "walk" and anim != "run" and anim != "reverse" and anim != "turn" and anim != "jump" and anim != "sad-walk" and anim != "sad-neutral" and anim != "sit" and anim != "sit-start"


## Duck, lose, and victory. The teleport hole and the shticker book have their own movies.
func _battle_clip(anim: String) -> bool:
	return _held_clip(anim) and anim != "teleport" and anim != "arrival" and anim != "book"


func _elapsed_pose(puppet: Dictionary) -> float:
	var base := float(puppet.get("clip_pose", 0.0))
	var stamp := int(puppet.get("pose_msec", 0))
	if stamp <= 0:
		return base
	return base + float(Time.get_ticks_msec() - stamp) / 1000.0


func _keep_teleport(peer: int) -> bool:
	var puppet: Dictionary = _puppets.get(peer, {})
	if puppet.is_empty():
		return false
	if String(puppet.get("anim", "")) != "teleport":
		return false
	if bool(puppet.get("departing", false)):
		return true
	if _elapsed_pose(puppet) >= _OUT_TIME:
		return false
	puppet["departing"] = true
	_puppets[peer] = puppet
	return true


func _play_portal(actor: ToonActor, puppet: Dictionary, anim: String) -> void:
	actor.hide_remote_book()
	actor.set_swimming(false)
	var shadow := actor.find_child("drop_shadow", true, false) as Node3D
	if shadow != null:
		shadow.visible = false
	var tag: Control = puppet.get("tag")
	var pose := _elapsed_pose(puppet)
	if anim == "teleport":
		if pose >= _OUT_TIME:
			_clear_portal(actor, puppet)
			actor.visible = false
			if tag != null:
				tag.visible = false
			return
		actor.visible = true
		actor.set_hole_clip(true, actor.global_position.y)
		actor.pose_action("teleport", pose)
		var hole := _ensure_hole(actor, puppet, pose < _DROP_AT)
		if hole != null:
			hole.call("pose_at", pose)
		if pose >= _SOUND_AT and not bool(puppet.get("sounded", false)):
			puppet["sounded"] = true
			_play_teleport_sound(actor)
		return
	var leap := actor.action_length("leap")
	var total := _IN_OPEN + _IN_HOLD + _IN_OPEN
	if leap > _JUMP_FROM:
		total = maxf(total, _IN_OPEN + (leap - _JUMP_FROM))
	if pose >= total:
		_clear_portal(actor, puppet)
		actor.visible = true
		if tag != null:
			tag.visible = true
		actor.release_pose()
		actor.set_locomotion(0.0, false, false, 0.016)
		return
	var landing := _ensure_hole(actor, puppet, false)
	if landing != null:
		if not bool(puppet.get("hole_set", false)):
			puppet["hole_set"] = true
			landing.global_transform = actor.global_transform
			landing.global_position = actor.to_global(Vector3(0.0, -2.4, 0.0))
		landing.call("pose_at", _arrival_hole(pose))
	if pose < _IN_OPEN:
		actor.visible = false
		if tag != null:
			tag.visible = false
		return
	actor.visible = true
	if tag != null:
		tag.visible = true
	actor.set_hole_clip(false, 0.0)
	actor.pose_action("leap", _JUMP_FROM + (pose - _IN_OPEN))


func _arrival_hole(elapsed: float) -> float:
	if elapsed < _IN_OPEN:
		return lerpf(_OUT_TIME, 3.1, elapsed / _IN_OPEN)
	if elapsed < _IN_OPEN + _IN_HOLD:
		return 3.1
	var shut := clampf((elapsed - _IN_OPEN - _IN_HOLD) / _IN_OPEN, 0.0, 1.0)
	return lerpf(3.1, _OUT_TIME, shut)


func _ensure_hole(actor: ToonActor, puppet: Dictionary, on_hand: bool) -> Node3D:
	var portal := puppet.get("portal") as Node3D
	if portal == null or not is_instance_valid(portal):
		portal = _PORTAL.new() as Node3D
		portal.name = "TeleportPortal"
		actor.add_child(portal)
		portal.call("setup")
		puppet["portal"] = portal
		puppet["hole_down"] = false
		puppet["hole_set"] = false
	if on_hand and not bool(puppet.get("hole_down", false)):
		var hand := actor.find_child("def_joint_right_hold", true, false) as Node3D
		var parent := actor as Node
		if hand != null:
			parent = hand
		if portal.get_parent() != parent:
			parent.add_child(portal)
			portal.transform = Transform3D.IDENTITY
		return portal
	if not bool(puppet.get("hole_down", false)):
		portal.reparent(actor, false)
		portal.transform = Transform3D.IDENTITY
		puppet["hole_down"] = true
	return portal


func _clear_portal(actor: ToonActor, puppet: Dictionary) -> void:
	var portal: Variant = puppet.get("portal")
	if not (portal is Node):
		return
	if is_instance_valid(portal):
		(portal as Node).queue_free()
	puppet.erase("portal")
	puppet.erase("hole_down")
	puppet.erase("hole_set")
	puppet.erase("sounded")
	actor.set_hole_clip(false, 0.0)
	var shadow := actor.find_child("drop_shadow", true, false) as Node3D
	if shadow != null:
		shadow.visible = true


func _play_teleport_sound(actor: ToonActor) -> void:
	var stream := ToonAudio.stream(_TELEPORT_SFX)
	if stream == null:
		return
	var player := ToonAudio.effect_3d()
	player.stream = stream
	actor.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _play_remote_door(path: String, kind: String, at: Vector3) -> void:
	var door := _find_shared_door(path, at)
	if door == null:
		return
	_swing_shared(door, kind)
	var token := Time.get_ticks_msec()
	_door_tokens[path] = token
	await get_tree().create_timer(2.0).timeout
	if int(_door_tokens.get(path, 0)) != token:
		return
	_door_tokens.erase(path)
	if is_instance_valid(door):
		_close_shared(door, kind)


func _find_shared_door(path: String, at: Vector3) -> Node3D:
	var scene := get_tree().current_scene if get_tree() != null else null
	if scene == null:
		return null
	if path != "":
		var named := scene.get_node_or_null(path) as Node3D
		if named != null:
			return named
	var state := {"door": null, "dist": 12.0}
	_scan_shared_door(scene, at, state)
	return state["door"] as Node3D


func _scan_shared_door(node: Node, at: Vector3, state: Dictionary) -> void:
	if node is Node3D:
		var called := str(node.name)
		if called.begins_with("door_double_") or called == "door_0" or called.begins_with("door_origin") or called.ends_with("_Door"):
			var here := (node as Node3D).global_position
			if here.distance_to(at) < float(state["dist"]):
				state["dist"] = here.distance_to(at)
				state["door"] = node
	for child in node.get_children():
		_scan_shared_door(child, at, state)


func _swing_shared(door: Node3D, kind: String) -> void:
	match kind:
		"shop":
			_SHOP_DOOR.open(self, door, false)
		"house":
			_HOUSE_DOOR.open(self, door, false)
		"gag":
			_GAG_DOOR.open(self, door, false)
		"pet":
			_PET_DOOR.open(self, door, false)
		"kart":
			_KART_DOOR.open(self, door, false)
		"hall":
			_HALL_DOOR.open(self, door, false)
		"hall-out":
			_HALL_DOOR.open_out(self, door, false)
		"library":
			_LIB_DOOR.open(self, door, false)
		"bank":
			_BANK_DOOR.open(self, door, false)
		"hq":
			_HQ_DOOR.open(self, door, false)


func _close_shared(door: Node3D, kind: String) -> void:
	if kind == "hall-out":
		_HALL_DOOR.close_out(self, door)
		return
	if kind == "kart":
		_DOOR.close_in(self, door)
		_DOOR.close_left(self, door)
		return
	if kind == "shop":
		_SHOP_DOOR.close(self, door)
		return
	_DOOR.close_in(self, door)


func _play_fishing(actor: ToonActor, puppet: Dictionary, anim: String, delta: float) -> void:
	actor.set_swimming(false)
	if anim == "run":
		_drop_pole(puppet)
		actor.release_pose()
		actor.set_locomotion(9.0, false, false, delta)
		return
	_hold_pole(actor, puppet, int(puppet.get("rod", 0)))
	var pose := float(puppet.get("pose", -1.0))
	if pose >= 0.0:
		actor.pose_action(anim, pose)
		return
	actor.release_pose()
	var looping := anim == "pole-neutral" or anim == "fish-neutral"
	actor.play_gesture(anim, 1.0, looping)
	actor.set_locomotion(0.0, false, false, delta)


func _hold_pole(actor: ToonActor, puppet: Dictionary, rod: int) -> void:
	var pole: Node3D = puppet.get("pole")
	if pole == null or not is_instance_valid(pole) or int(puppet.get("pole_rod", -1)) != rod:
		if pole != null and is_instance_valid(pole):
			pole.queue_free()
		pole = Node3D.new()
		pole.name = "FishingPole"
		var paths: PackedStringArray = [
			"res://assets/props/fishing_pole.glb",
			"res://assets/props/fishing_pole_bamboo.glb",
			"res://assets/props/fishing_pole_wood.glb",
			"res://assets/props/fishing_pole_steel.glb",
			"res://assets/props/fishing_pole_gold.glb",
		]
		var which := clampi(rod, 0, paths.size() - 1)
		var packed := load(paths[which]) as PackedScene
		if packed != null:
			pole.add_child(packed.instantiate())
		puppet["pole"] = pole
		puppet["pole_rod"] = rod
	var hand := actor.find_child("def_joint_right_hold", true, false) as Node3D
	if hand == null:
		if pole.get_parent() != actor:
			actor.add_child(pole)
	elif pole.get_parent() != hand:
		hand.add_child(pole)
	pole.scale = Vector3.ONE


func _drop_pole(puppet: Dictionary) -> void:
	var pole: Node3D = puppet.get("pole")
	if pole != null and is_instance_valid(pole):
		pole.queue_free()
	puppet.erase("pole")
	puppet.erase("pole_rod")


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
	_drop_pole(puppet)
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
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		data.get("head", ""), data.get("torso", ""), data.get("legs", ""),
		data.get("gender", ""), data.get("head_color", 0), data.get("arm_color", 0),
		data.get("leg_color", 0), data.get("head_hex", ""), data.get("arm_hex", ""),
		data.get("leg_hex", ""), data.get("top_tex", 0), data.get("top_color", 0),
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
