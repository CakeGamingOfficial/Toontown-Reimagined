extends Node

## Sellbot VP scenes around the pie round. Lines, cage heights, the roll, and
## the doobers are DistributedSellbotBoss. The boss model stays in panda space
## under the room, which already turns that space upright.

const _ROLL_SPEED := 7.5
const _RIDE := 8.0
const _OPEN := 4.0
const _CAGE_Z: Array[float] = [100.0, 81.0, 63.0, 44.0, 25.0, 18.0]
const _DOOBERS: Array = [
	{"code": "cc", "name": "Cold Caller", "body": "c", "height": 4.63},
	{"code": "tm", "name": "Telemarketer", "body": "b", "height": 5.24},
	{"code": "nd", "name": "Name Dropper", "body": "a", "height": 5.98},
	{"code": "gh", "name": "Glad Hander", "body": "c", "height": 6.4},
	{"code": "ms", "name": "Mover & Shaker", "body": "b", "height": 6.7},
	{"code": "tf", "name": "Two-Face", "body": "a", "height": 6.95},
	{"code": "m", "name": "The Mingler", "body": "a", "height": 7.61},
	{"code": "mh", "name": "Mr. Hollywood", "body": "a", "height": 8.95},
]

var _boss: Node
var _geom: Node3D
var _marker: Node3D
var _vp: Node3D
var _cage: Node3D
var _toon: Node3D
var _toon_name := "The caged Toon"
var _movie := ""
var _t := 0.0
var _pages: PackedStringArray = []
var _page := 0
var _finished := false
var _finish_as := ""
var _doobers: Array[Node3D] = []
var _roll: Array[Vector3] = []
var _roll_at := 0
var _door_u := 1.0
var _door_goal := 1.0
var _ramp_home: Dictionary = {}
var _door_home: Dictionary = {}
var _barrels: Node3D
var _poser: StreetCog
var _banks: Dictionary = {}
var _rates: Dictionary = {}
var _pose := ""
var _pose_time := 0.0
var _pose_loop := true
var _pose_next := ""
var _left_tread := 0.0
var _right_tread := 0.0
var _left_mat: BaseMaterial3D
var _right_mat: BaseMaterial3D
var _music: AudioStreamPlayer
var _door_heard := 1.0
var _arrived := false
var _epilogue := false
var _cue := ""
var _cued := false
var _ramp_slide := false
var _sos_dna: Dictionary = {}
var _pie_advice := 30.0
var _throw_advice := -1.0
var _cage_chat := 15.0
var _advice_at := 100
var _got_pies := false
var _threw := false
var _dancing := false
var _rewarding := false
var _win: AudioStreamPlayer
var _suits: Array[Node3D] = []
var _said := ""
var _cage_i := 0
var _drop_next := ""
var _pending_pages: PackedStringArray = []
var _exp_before: Dictionary = {}
var _pose_hold := -1.0
var _suits_lost := false
var _iris: ColorRect
var _gears: Array[Dictionary] = []
var _gear_mesh: Mesh
var _gear_time := 0.0
var _gear_birth := 0.0
var _ramps_closed := false
var _waiting := false
var _wait_t := 0.0
var _wait_label: Label
var _music_key := ""
var _caged_line := ""
var _saved_fov := -1.0
var _mask_saved := -1
var _collide_back := -1.0
var _release_when_solid := false
var _leaving := false
var _reward_cam := false
var _reward_side := false
var _reward_focus: Node3D
var _peer_before: Dictionary = {}
var _exp_frozen := false
var _shadow: MeshInstance3D
var _flash_paint: StandardMaterial3D
var _flash_left := 0.0
const _DROP: PackedStringArray = [
	"Great job!  You're wearing him down!",
	"Keep after him!  He's on the run!",
	"You guys are doing great!",
	"Fantastic!  You've almost got him now!",
]


func bind(boss: Node) -> void:
	_boss = boss
	set_process(true)
	process_priority = 20


func play(which: String) -> void:
	_stop_movie()
	_ensure_cast()
	_movie = which
	_t = 0.0
	_finished = false
	_finish_as = which
	_roll_at = 0
	if which == "intro":
		_hold(true)
		_set_cage(0)
		_arrived = false
		_spawn_doobers()
		_door_u = 0.0
		_door_goal = 0.0
		_door_heard = 0.0
		music("elevator")
		_use_hq_fov()
		_open_iris()
		_place_vp(_elevator_spot(), Vector3(0, -20, 5))
		_seat_toons()
		_wear_suits()
		_remember_exp()
		_ramps_closed = false
		_waiting = false
		if _boss != null and _boss.has_method("reset_vp_teams"):
			_boss.call("reset_vp_teams")
		pose("speech")
	elif which == "roll":
		_hold(true)
		pose("neutral")
		music("between")
		_drop_into("roll")
	elif which == "victory":
		_hold(true)
		_set_cage(4)
		_epilogue = false
		pose("fall")
		_place_vp(Vector3(0, -175, -6.5), Vector3(0, 78, 18))


func pages(which: String, lines: PackedStringArray) -> void:
	_stop_movie()
	_ensure_cast()
	if which == "prepare3":
		_pending_pages = lines
		_finished = false
		_finish_as = which
		_drop_into("prepare3")
		return
	_movie = which
	_pages = lines
	_page = 0
	_finished = false
	_finish_as = which
	_say(lines[0] if lines.size() > 0 else "")
	if which == "prepare2":
		_hide_barrels()
		music("sting")
		_collide_back = 0.5
		_set_cage(3 if _solo() else 2)
		pose("neutral")
		_place_vp(Vector3(0, 60, 18), Vector3(0, 77, 18))
	elif which == "prepare3":
		_set_cage(4)
		pose("neutral")
		_place_vp(Vector3(0, 60, 18), Vector3(0, 77, 18))


func next_page() -> void:
	if _finished or _movie == "drop":
		return
	_page += 1
	if _movie == "thanks" and _page == 2:
		_emote(13)
	if _page >= _pages.size():
		if _movie == "thanks":
			_send_home()
			return
		if _movie == "prepare2" and _party().size() > 1:
			_begin_wait()
			return
		_complete()
		return
	_say(_pages[_page])


func _send_home() -> void:
	# __epilogueChatDone. He waves, then half a second later you teleport home.
	if _leaving:
		return
	_leaving = true
	_emote(0)
	if _pages.is_empty() or _pages[_pages.size() - 1] != "See ya!":
		_caged_say("See ya!")
	if _boss != null and _boss.has_method("clear_pages"):
		_boss.call("clear_pages")
	await get_tree().create_timer(0.5).timeout
	if is_inside_tree() and _boss != null and _boss.has_method("leave_for_playground"):
		_boss.call("leave_for_playground")


func skip() -> void:
	_complete()


func place_damage(along: float) -> void:
	if _movie != "" or _vp == null:
		return
	var path: Array[Vector3] = [Vector3(0, 60, 18), Vector3(0, -110, -6.5), Vector3(0, -175, -6.5)]
	var spot := _along(path, clampf(along, 0.0, 1.0))
	# Battle three keeps the door side toward the cage while he rolls backward.
	_place_vp(spot, Vector3(0, 78, 18), true)


func _process(delta: float) -> void:
	_slide_room(delta)
	_grab_barrels()
	_lift_iris(delta)
	_tick_gears(delta)
	_tick_flash(delta)
	_tick_collisions(delta)
	_capture_peer_exp()
	if _reward_cam:
		_aim_reward()
	if _movie == "intro" and _arrived and _speech_time() < 37.0:
		_speech_anim(_speech_time())
	_advance_pose(delta)
	_pie_lines(delta)
	if _movie == "intro":
		_t += delta
		if _t < _RIDE + _OPEN:
			_ride_elevator()
		elif not _arrived:
			_arrived = true
			_place_vp(Vector3(0, -35, 0), Vector3(0, 0, 5))
			music("promotion")
			_say("You are hereby promoted to full-fledged Sellbots.  Congratulations!", true)
		_intro_beat()
		if _finished:
			return
		if _arrived:
			_march_toons(delta)
			_move_doobers()
			_aim_camera()
	elif _waiting:
		_poll_wait(delta)
	elif _movie == "drop":
		_t += delta
		_lower_cage()
		if _t >= 4.0:
			_finish_drop()
	elif _movie == "roll":
		_t += delta
		if not _step_roll(delta):
			_set_cage(3 if _solo() else 2)
			_collide_back = -1.0
			_set_collisions(false)
			_complete()
	elif _movie == "uncage":
		_t += delta
		_play_uncage(delta)
	elif _movie == "victory":
		_t += delta
		if _t >= 8.0:
			_begin_epilogue()
	elif _movie == "dance":
		_t += delta
		if _t >= 5.0 and not _rewarding:
			_rewarding = true
			_show_gag_reward()


func _speech_time() -> float:
	return maxf(_t - (_RIDE + _OPEN), 0.0)


func _intro_beat() -> void:
	var speech := _speech_time()
	if speech <= 0.0:
		return
	if speech >= _party().size():
		_door_goal = 0.0
	if speech >= 40.0:
		_place_vp(Vector3(0, -35, 0), Vector3(0, 0, 5))
		_complete()
		return
	if speech >= 39.0:
		_say("Attack!!", true)
	elif speech >= 37.0:
		if not _ramps_closed:
			_ramps_closed = true
			pose("neutral")
			_clear_boss_line()
			_normal_eyes()
		_say("")
	elif speech >= 34.0:
		_clear_boss_line()
		if not _suits_lost:
			_suits_lost = true
			_blow_suits()
	elif speech >= 31.0:
		_caged_say("")
		_say("Huh?  Toons!  In disguise!", true)
	elif speech >= 27.0:
		_clear_boss_line()
		_caged_say("So, did you Toons come to rescue me?")
	elif speech >= 25.0:
		_clear_boss_line()
		_caged_say("")
	elif speech >= 22.2:
		_clear_boss_line()
		_caged_say("Hey! Hiya! Hey over there!")
	elif speech >= 22.0:
		_say("You are hereby promoted to full-fledged Sellbots.  Congratu--", true)
	elif speech >= 18.0:
		_say("Welcome, new Cogs!", true)
	elif speech >= 12.0:
		_say("Go!  And make that sale!", true)


func _move_doobers() -> void:
	# The walk interval starts nine seconds in, then skips ahead at sixteen.
	var clock := _doober_clock(_speech_time())
	var delays: Array[int] = [0, 4, 8, 12, 14, 10, 6, 2]
	for index in _doobers.size():
		var cog := _doobers[index]
		if not is_instance_valid(cog):
			continue
		var side := 0 if index < 4 else 1
		var slot := index if index < 4 else index - 4
		var home := _battle_point(side, slot, 4, true)
		var turn := Vector3(-20, -50, 0) if side == 0 else Vector3(20, -50, 0)
		var path: Array[Vector3] = [home, turn, Vector3(0, -50, 0), Vector3(0, -135, -6.5)]
		var delay := delays[index] if index < delays.size() else 0
		var walked := -1.0 if clock < 0.0 else clock - float(delay)
		var spot := home
		var aim := turn
		var moving := false
		if walked > 0.0:
			var remain := walked
			moving = true
			for step in path.size() - 1:
				var span := path[step].distance_to(path[step + 1]) / 8.64
				aim = path[step + 1]
				if remain < span:
					spot = path[step].lerp(path[step + 1], remain / maxf(span, 0.001))
					remain = -1.0
					break
				remain -= span
				spot = path[step + 1]
			if remain >= 0.0:
				# beginSupaFlyMove. The propeller climb belongs to the suit.
				if not bool(cog.get_meta("flew", false)):
					cog.position = spot
					cog.set_meta("flew", true)
					if cog.has_method("fly_away"):
						cog.call("fly_away")
				continue
		cog.position = spot
		if cog.has_method("set_walking"):
			cog.call("set_walking", moving and spot.z <= 0.1)
		_face_panda(cog, spot, aim)


func _step_roll(delta: float) -> bool:
	if _roll_at >= _roll.size() - 1:
		return false
	var here := _roll[_roll_at]
	var there := _roll[_roll_at + 1]
	var step := _ROLL_SPEED * delta
	var next := _move_toward(here, there, step)
	_roll[_roll_at] = next
	var look := Vector3(0, 78, 18) if _movie == "victory" else there
	_place_vp(next, look, true)
	if next.distance_to(there) <= 0.05:
		_roll_at += 1
	return true


func _doober_clock(speech: float) -> float:
	if speech < 9.0:
		return -1.0
	if speech < 16.0:
		return speech - 9.0
	return 14.0 + (speech - 16.0)


func _toon_track_time(speech: float) -> float:
	# The first slice plays to sixteen. The movie then jumps to track time thirty.
	if speech < 16.0:
		return speech
	return 30.0 + (speech - 16.0)


func _march_toons(delta: float) -> void:
	var speech := _speech_time()
	var track := _toon_track_time(speech)
	var assignments := _toon_assignments()
	var seats: Array[Vector3] = [
		Vector3(-2.5, 9, 0.1), Vector3(2.5, 9, 0.1),
		Vector3(-8.0, 9, 0.1), Vector3(8.0, 9, 0.1),
		Vector3(-2.5, 4, 0.1), Vector3(2.5, 4, 0.1),
		Vector3(-8.0, 4, 0.1), Vector3(8.0, 4, 0.1),
	]
	var origin := _elevator_spot()
	for index in assignments.size():
		var item: Dictionary = assignments[index]
		var person := item["node"] as Node3D
		if person == null or not is_instance_valid(person):
			continue
		var side := int(item["side"])
		var slot := int(item["slot"])
		var count := int(item["count"])
		var delay := float(item["delay"])
		var seat := origin + seats[mini(index, seats.size() - 1)]
		var promo := _battle_point(side, slot, count, true)
		var battle := _battle_point(side, slot, count, false)
		var heading := _battle_heading(side, _point_heading(slot, count))
		var local := track - delay
		var spot := seat
		var walking := false
		var backward := false
		if speech >= 37.0:
			var u := clampf((speech - 37.0) / 3.0, 0.0, 1.0)
			spot = promo.lerp(battle, u)
			walking = u < 1.0
			backward = true
		elif local > 0.0 and local <= 1.0:
			spot = seat.lerp(Vector3(0, 90, 20), local)
			walking = true
		elif local > 1.0:
			var along := (local - 1.0) / 35.0
			if along >= 1.0:
				spot = promo
			else:
				spot = _enter_point(side, along)
				walking = true
		_stand_person(person, spot, heading)
		_pose_person(person, delta, walking, backward)


func _toon_assignments() -> Array[Dictionary]:
	var teams: Array = [[], []]
	if _boss != null and _boss.has_method("vp_teams"):
		var found: Variant = _boss.call("vp_teams")
		if found is Array and (found as Array).size() >= 2:
			teams = found
	var by_peer := {}
	for person in _party():
		by_peer[_peer_of(person)] = person
	var rows: Array[Dictionary] = []
	var delay := 0
	for side in [0, 1]:
		var team: Array = teams[side]
		for slot in team.size():
			var peer := int(team[slot])
			if not by_peer.has(peer):
				continue
			rows.append({
				"node": by_peer[peer],
				"side": side,
				"slot": slot,
				"count": team.size(),
				"delay": delay,
			})
			delay += 1
	if rows.is_empty():
		var people := _party()
		for index in people.size():
			rows.append({
				"node": people[index],
				"side": 0,
				"slot": index,
				"count": people.size(),
				"delay": index,
			})
	return rows


func _peer_of(person: Node) -> int:
	if person.has_meta("peer"):
		return int(person.get_meta("peer"))
	var actor := _actor_of(person as Node3D)
	if actor != null and actor.has_meta("peer"):
		return int(actor.get_meta("peer"))
	return ToonNet.peer_id()


func _stand_person(person: Node3D, panda: Vector3, heading: float) -> void:
	person.global_position = _world(panda)
	var ahead := _world(panda + _heading_forward(heading))
	if person.global_position.distance_squared_to(ahead) > 0.04:
		person.look_at(ahead, Vector3.UP)
	_snap_suit(person, ahead)


func _pose_person(person: Node3D, delta: float, walking: bool, backward: bool) -> void:
	var suit := _suit_for(person)
	if suit != null and is_instance_valid(suit) and suit.visible:
		if suit.has_method("set_walking"):
			suit.call("set_walking", walking)
		return
	var actor := _actor_of(person)
	if actor == null or not actor.has_method("set_locomotion"):
		return
	var speed := 0.0
	if walking:
		speed = -4.0 if backward else 4.0
	actor.call("set_locomotion", speed, false, false, delta)


func _enter_point(side: int, along: float) -> Vector3:
	var samples: Array[Vector3] = [
		Vector3(0, 88.147, 20), Vector3(-14.813, 67.855, 20), Vector3(-44.402, 56.936, 20),
		Vector3(-69.814, 42.021, 20), Vector3(-85.394, 19.556, 20), Vector3(-88.668, -8.956, 20),
		Vector3(-76.582, -31.586, 20), Vector3(-49.371, -38.409, 20), Vector3(-21, -37.929, 20),
	]
	if side == 1:
		for index in samples.size():
			var point: Vector3 = samples[index]
			point.x = -point.x
			samples[index] = point
	var scaled := clampf(along, 0.0, 1.0) * float(samples.size() - 1)
	var frame := mini(int(scaled), samples.size() - 2)
	return samples[frame].lerp(samples[frame + 1], scaled - float(frame))


func _battle_origin(side: int) -> Vector3:
	return Vector3(-25, -35, 0) if side == 0 else Vector3(25, -35, 0)


func _battle_offset(side: int, local: Vector3) -> Vector3:
	# Boss heading -90. Side B's battle node is turned 180 from side A.
	if side == 0:
		return Vector3(local.y, -local.x, local.z)
	return Vector3(-local.y, local.x, local.z)


func _battle_point(side: int, slot: int, count: int, promo: bool) -> Vector3:
	var local := _point_local(slot, count)
	if promo:
		local.y += 10.0
	return _battle_origin(side) + _battle_offset(side, local)


func _point_local(slot: int, count: int) -> Vector3:
	var rows: Array = [
		[Vector3(0, -6, 0)],
		[Vector3(1.5, -6.5, 0), Vector3(-1.5, -6.5, 0)],
		[Vector3(3, -6.75, 0), Vector3(0, -7, 0), Vector3(-3, -6.75, 0)],
		[Vector3(4.5, -7, 0), Vector3(1.5, -7.5, 0), Vector3(-1.5, -7.5, 0), Vector3(-4.5, -7, 0)],
	]
	var row: Array = rows[clampi(count, 1, 4) - 1]
	var point: Vector3 = row[clampi(slot, 0, row.size() - 1)]
	return point


func _point_heading(slot: int, count: int) -> float:
	var rows: Array = [
		[0.0],
		[5.0, -5.0],
		[5.0, 0.0, -5.0],
		[10.0, 5.0, -5.0, -10.0],
	]
	var row: Array = rows[clampi(count, 1, 4) - 1]
	return float(row[clampi(slot, 0, row.size() - 1)])


func _battle_heading(side: int, local_heading: float) -> float:
	return (-90.0 if side == 0 else 90.0) + local_heading


func _heading_forward(heading: float) -> Vector3:
	var radians := deg_to_rad(heading)
	return Vector3(sin(-radians), cos(-radians), 0)


func _place_camera(at: Vector3, hpr: Vector3) -> void:
	var camera := _camera()
	if camera == null:
		return
	camera.global_position = _world(at)
	var forward := _heading_forward(hpr.x)
	var pitch := deg_to_rad(hpr.y)
	forward = Vector3(forward.x * cos(pitch), forward.y * cos(pitch), sin(pitch))
	var focus := _world(at + forward)
	if camera.global_position.distance_squared_to(focus) > 0.04:
		camera.look_at(focus, Vector3.UP)


func _face_panda(node: Node3D, spot: Vector3, aim: Vector3) -> void:
	if _geom == null or spot.distance_squared_to(aim) < 0.04:
		return
	var focus := _world(aim)
	if node.global_position.distance_squared_to(focus) > 0.04:
		node.look_at(focus, Vector3.UP)


func _clear_boss_line() -> void:
	if _said == "":
		return
	_said = ""
	if _boss != null and _boss.has_method("set_line"):
		_boss.call("set_line", "")


func _caged_say(text: String) -> void:
	var big := _speech_time() >= 22.2 and _speech_time() < 31.0
	var scale := 2.0 if big else 1.0
	if text == _caged_line and (_toon == null or is_equal_approx(float(_toon.get_meta("nametag_scale", 1.0)), scale)):
		return
	_caged_line = text
	if _toon == null:
		return
	_toon.set_meta("nametag_scale", scale)
	_toon.set_meta("chat_line", text)
	_toon.set_meta("chat_until", 0 if text == "" else Time.get_ticks_msec() + 8000)
	if text != "":
		_emote(0)
		ToonSpeech.speak(_toon, text)


func _normal_eyes() -> void:
	for person in _party():
		var actor := _actor_of(person)
		if actor != null and actor.has_method("set_expression"):
			actor.call("set_expression", "normal")


func _begin_wait() -> void:
	# Shown only while somebody else is still reading. A solo group never waits.
	_waiting = true
	_wait_t = 0.0
	_mark_ready(true)


func _poll_wait(delta: float) -> void:
	_wait_t += delta
	if _all_ready():
		_hide_wait_label()
		_mark_ready(false)
		_waiting = false
		_complete()
		return
	if _wait_t >= 1.0:
		_show_wait_label()


func _all_ready() -> bool:
	if not ToonNet.networked():
		return true
	for person in _party():
		var peer := _peer_of(person)
		if peer == ToonNet.peer_id():
			continue
		if not bool(ToonNet.latest("toon:%d" % peer).get("vp_ready", false)):
			return false
	return true


func _mark_ready(ready: bool) -> void:
	for person in _party():
		if _peer_of(person) != ToonNet.peer_id():
			continue
		var actor := _actor_of(person)
		if actor != null:
			actor.set_meta("vp_ready", ready)


func _show_wait_label() -> void:
	if _wait_label != null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.name = "VpWaiting"
	add_child(layer)
	_wait_label = Label.new()
	_wait_label.text = "Waiting for other players..."
	_wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wait_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_wait_label.offset_top = 120
	_wait_label.offset_left = -220
	_wait_label.offset_right = 220
	_wait_label.add_theme_font_size_override("font_size", 28)
	_wait_label.add_theme_color_override("font_color", Color.WHITE)
	layer.add_child(_wait_label)


func _hide_wait_label() -> void:
	if _wait_label == null:
		return
	var layer := _wait_label.get_parent()
	_wait_label = null
	if layer != null:
		layer.queue_free()


func _hide_barrels() -> void:
	if _barrels != null and is_instance_valid(_barrels):
		_barrels.queue_free()
	_barrels = null


func _roll_path() -> Array[Vector3]:
	# SellbotBossTopRampPosA / PosB. The client rolls up the ramp on their side.
	if _boss != null and _boss.has_method("arena_side") and int(_boss.call("arena_side")) == 1:
		return [Vector3(0, -35, 0), Vector3(80, -35, 18), Vector3(80, 10, 18), Vector3(50, 60, 18), Vector3(0, 60, 18)]
	return [Vector3(0, -35, 0), Vector3(-80, -35, 18), Vector3(-80, 10, 18), Vector3(-50, 40, 18), Vector3(0, 60, 18)]


func _slide_room(delta: float) -> void:
	_ensure_cast()
	if _geom == null:
		return
	var step := 9.0 * delta
	var sliding := false
	for spec in [["A", "west_ramp2"], ["B", "west_ramp"], ["C", "west_ramp1"]]:
		var ramp := _geom.find_child(String(spec[1]), true, false) as Node3D
		if ramp == null:
			continue
		if not _ramp_home.has(spec[0]):
			_ramp_home[spec[0]] = ramp.position.x
		var home := float(_ramp_home[spec[0]])
		var target := home if _ramp_out(String(spec[0])) else home + 18.0
		var gap := target - ramp.position.x
		if absf(gap) > 0.05:
			sliding = true
		if absf(gap) <= step:
			ramp.position.x = target
		else:
			ramp.position.x += signf(gap) * step
	if sliding and not _ramp_slide:
		_ramp_slide = true
		sfx("CHQ_VP_ramp_slide.ogg")
	elif not sliding:
		_ramp_slide = false
	if _door_goal != _door_heard:
		_door_heard = _door_goal
		sfx("CHQ_VP_door_open.ogg" if _door_goal > 0.5 else "CHQ_VP_door_close.ogg")
	_door_u = move_toward(_door_u, _door_goal, delta / 4.0)
	var entrance := _geom.find_child("elevatorEntrance", true, false) as Node3D
	if entrance == null:
		return
	for door_name in ["left-door", "right-door"]:
		var door := entrance.find_child(door_name, true, false) as Node3D
		if door == null:
			continue
		if not _door_home.has(door_name):
			_door_home[door_name] = door.position
		var open: Vector3 = _door_home[door_name]
		var closed := open + Vector3(11.5 if door_name == "left-door" else -11.5, 0.0, 0.0)
		door.position = open.lerp(closed, 1.0 - _door_u)


func _ramp_out(which: String) -> bool:
	var phase := ""
	var side := 0
	if _boss != null:
		if _boss.has_method("phase"):
			phase = String(_boss.call("phase"))
		if _boss.has_method("arena_side"):
			side = int(_boss.call("arena_side"))
	if _ramps_closed:
		return false
	if phase == "intro":
		return which != "C"
	if phase == "roll" or phase == "prepare2" or phase == "skele":
		if which == "C":
			return false
		if which == "A":
			return side == 0
		return side == 1
	if phase == "prepare3" or phase == "pies" or phase == "reward":
		return which == "C"
	return false


func _spawn_barrels() -> void:
	# SellbotBossGlobals.BarrelDefs. Only Operation: Storm Sellbot brings them up.
	if _geom == null or _barrels != null:
		return
	if _boss == null or not _boss.has_method("nerfed") or not bool(_boss.call("nerfed")):
		return
	if not ResourceLoader.exists("res://assets/cogs/bosses/gag_tank.glb"):
		return
	var packed := load("res://assets/cogs/bosses/gag_tank.glb") as PackedScene
	if packed == null:
		return
	_barrels = Node3D.new()
	_barrels.name = "VpBarrels"
	_geom.add_child(_barrels)
	_barrels.position = Vector3(0, -36, -8)
	if _boss.has_method("arena_side") and int(_boss.call("arena_side")) == 0:
		_barrels.rotation.z = PI
	var specs: Array = [
		{"kind": "healBarrel", "at": Vector3(15, 23, 0), "grab": 50, "track": 0, "level": 0},
		{"kind": "gagBarrel", "at": Vector3(15, -23, 0), "grab": 10, "track": 3, "level": 3},
		{"kind": "gagBarrel", "at": Vector3(21, 20, 0), "grab": 10, "track": 4, "level": 3},
		{"kind": "gagBarrel", "at": Vector3(21, -20, 0), "grab": 10, "track": 5, "level": 3},
	]
	var label := load("res://scenes/cog_hq/barrel_label.gd") as GDScript
	for spec in specs:
		var tank := packed.instantiate() as Node3D
		if tank == null:
			continue
		tank.name = "VpBarrel"
		_barrels.add_child(tank)
		tank.position = spec["at"]
		tank.scale = Vector3(0.5, 0.5, 0.5)
		tank.set_meta("kind", spec["kind"])
		tank.set_meta("grab", spec["grab"])
		tank.set_meta("track", spec["track"])
		tank.set_meta("level", spec["level"])
		tank.set_meta("taken", false)
		if label != null:
			label.call("dress", tank, spec["kind"], spec["track"], spec["level"])
	var rise := create_tween()
	rise.tween_property(_barrels, "position:z", 0.0, 0.5)


func _grab_barrels() -> void:
	if _barrels == null or _boss == null:
		return
	var host := _boss.get_parent()
	var body := host.get_node_or_null("Player") as Node3D if host != null else null
	if body == null:
		return
	for tank in _barrels.get_children():
		if not tank is Node3D or bool(tank.get_meta("taken", false)):
			continue
		var barrel := tank as Node3D
		if body.global_position.distance_to(barrel.global_position) > 2.2:
			continue
		var kind := String(barrel.get_meta("kind", ""))
		var grab := int(barrel.get_meta("grab", 0))
		if kind == "healBarrel":
			var loadout := ToonLoadout.for_selected()
			loadout.set_hp(mini(loadout.hp + grab, loadout.max_hp), loadout.max_hp)
			loadout.save()
		elif kind == "gagBarrel":
			var loadout := ToonLoadout.for_selected()
			var got := 0
			for _n in grab:
				if loadout.purchase(int(barrel.get_meta("track", 0)), int(barrel.get_meta("level", 0))) <= 0:
					break
				got += 1
			if got <= 0:
				continue
		else:
			continue
		barrel.set_meta("taken", true)
		barrel.visible = false


func _stand_by_cage() -> void:
	if _cage == null or _boss == null:
		return
	var host := _boss.get_parent()
	var body := host.get_node_or_null("Player") as Node3D if host != null else null
	if body == null:
		return
	var stand := _cage.global_position + Vector3(8.0, 0.0, 6.0)
	stand.y = body.global_position.y
	body.global_position = stand
	if body.global_position.distance_squared_to(_cage.global_position) > 0.25:
		body.look_at(_cage.global_position, Vector3.UP)


func _emote(index: int) -> void:
	if _toon != null and _toon.has_method("play_emote"):
		_toon.call("play_emote", index)


func _move_toward(here: Vector3, there: Vector3, step: float) -> Vector3:
	var offset := there - here
	var length := offset.length()
	if length <= step or length < 0.001:
		return there
	return here + offset * (step / length)


func _along(path: Array[Vector3], along: float) -> Vector3:
	var lengths: Array[float] = []
	var total := 0.0
	for index in path.size() - 1:
		var span := path[index].distance_to(path[index + 1])
		lengths.append(span)
		total += span
	var remain := along * total
	for index in lengths.size():
		if remain > lengths[index] and index < lengths.size() - 1:
			remain -= lengths[index]
			continue
		var span := maxf(lengths[index], 0.001)
		return path[index].lerp(path[index + 1], clampf(remain / span, 0.0, 1.0))
	return path[path.size() - 1]


func _aim_camera() -> void:
	# makeIntroductionMovie. The opening eases. Every later cut is immediate.
	var clock := _speech_time()
	var at := Vector3(0, 25, 30)
	var hpr := Vector3(0, 0, 0)
	if clock < 8.0:
		var u := clock / 8.0
		u = u * u * (3.0 - 2.0 * u)
		at = Vector3(0, 25, 30).lerp(Vector3(-22, -100, 35), u)
		hpr = Vector3(0, 0, 0).lerp(Vector3(-10, -13, 0), u)
	elif clock < 10.0:
		at = Vector3(-22, -100, 35)
		hpr = Vector3(-10, -13, 0)
	elif clock < 16.0:
		at = Vector3(-23.1, 15.7, 17.2)
		hpr = Vector3(-160, -2.4, 0)
	elif clock < 25.0:
		at = Vector3(-25, -99, 10)
		hpr = Vector3(-14, 10, 0)
	elif clock < 27.0:
		at = Vector3(-12, -15, 27)
		hpr = Vector3(-151, -15, 0)
	elif clock < 31.0:
		at = Vector3(-12, 48, 94)
		hpr = Vector3(-26, 20, 0)
	elif clock < 34.0:
		at = Vector3(-20, -35, 10)
		hpr = Vector3(-88, 25, 0)
	elif clock < 37.0:
		var side := 0
		if _boss != null and _boss.has_method("arena_side"):
			side = int(_boss.call("arena_side"))
		at = _battle_origin(side) + _battle_offset(side, Vector3(0, 18, 5))
		hpr = Vector3(_battle_heading(side, -180.0), 0, 0)
	else:
		at = Vector3(-23.4, -145.6, 44.0)
		hpr = Vector3(-10, -12.5, 0)
	_place_camera(at, hpr)


func _complete() -> void:
	if _finished:
		return
	_finished = true
	_waiting = false
	_hide_wait_label()
	_mark_ready(false)
	var which := _finish_as if _finish_as != "" else _movie
	var wait_solid := false
	if which == "roll":
		_collide_back = -1.0
		_set_collisions(false)
		wait_solid = true
	elif which != "prepare2":
		_collide_back = -1.0
		_set_collisions(true)
	elif _mask_saved >= 0:
		wait_solid = true
	if which == "intro":
		_door_goal = 0.0
		_remove_suits()
		music("battle")
	_stop_movie()
	if which == "victory":
		_show_frolic()
	if wait_solid:
		_release_when_solid = true
	else:
		_release_when_solid = false
		_hold(false)
	if _boss != null and _boss.has_method("show_finished"):
		_boss.call("show_finished", which)


func _stop_movie() -> void:
	_movie = ""
	for cog in _doobers:
		if is_instance_valid(cog):
			cog.queue_free()
	_doobers.clear()


func _ensure_cast() -> void:
	if _geom == null:
		var host := _boss.get_parent() if _boss != null else null
		_geom = host.get_node_or_null("Geometry") as Node3D if host != null else null
	if _geom == null:
		return
	if _marker == null:
		_marker = Node3D.new()
		_marker.name = "VpMarker"
		_geom.add_child(_marker)
	if _vp == null:
		var packed := load("res://assets/cogs/bosses/sellbot_vp.glb") as PackedScene
		if packed != null:
			_vp = packed.instantiate() as Node3D
			_vp.name = "VP"
			_geom.add_child(_vp)
	_cage = _geom.find_child("cage", true, false) as Node3D
	if _toon == null and _cage != null:
		_summon_toon()


func _summon_toon() -> void:
	var card: Dictionary = _boss.call("hold_caged_toon") if _boss != null and _boss.has_method("hold_caged_toon") else {}
	_toon_name = String(card.get("name", "The caged Toon"))
	var style := _sos_style(int(card.get("id", 0)))
	if style == null:
		style = ToonStyle.random_body("m" if randi() % 2 == 0 else "f")
	_toon = ToonActor.new()
	_toon.name = "CagedToon"
	_cage.add_child(_toon)
	_toon.position = Vector3(0, -1.5, -6)
	_toon.set("follows_ground", false)
	if _toon.has_method("show_style"):
		_toon.call("show_style", style)
	var tags := _tags()
	if tags != null and tags.has_method("add"):
		tags.call("add", _toon, _toon_name, "npc")


func _spawn_doobers() -> void:
	for index in _DOOBERS.size():
		var spec: Dictionary = _DOOBERS[index]
		var cog := (load("res://scenes/cogs/street_cog.gd") as GDScript).new() as Node3D
		cog.name = "Doober%d" % index
		_geom.add_child(cog)
		if cog.has_method("present"):
			cog.call("present", {
				"code": spec["code"],
				"name": spec["name"],
				"dept": "s",
				"body": spec["body"],
				"height": spec["height"],
				"level": index + 1,
				"hp": 1,
				"max": 1,
			}, {})
		_doobers.append(cog)


func _place_vp(at: Vector3, look: Vector3, rolling := false) -> void:
	if _vp == null:
		return
	var before := _vp.global_position
	var before_yaw := _vp.global_rotation.y
	_vp.position = at
	var focus := _world(look)
	if _vp.global_position.distance_squared_to(focus) > 0.25:
		_vp.look_at(focus, Vector3.UP)
	if rolling:
		_stick_floor()
		var yaw := wrapf(_vp.global_rotation.y - before_yaw, -PI, PI)
		_scroll_treads(_vp.global_position - before, yaw)


func pose(which: String) -> void:
	# BossCog.getAnim. Speech loops through the introduction. The hit plays
	# once, then he stays down until the next attack. The fall holds.
	var clip := "Fb_neutral"
	var loop := true
	var nxt := ""
	match which:
		"speech":
			clip = "Ff_speech"
		"turn":
			clip = "ltTurn2Wave"
			loop = false
		"wave":
			clip = "wave"
		"look":
			clip = "Ff_lookRt"
			loop = false
		"face":
			clip = "turn2Fb"
			loop = false
		"hit":
			flash()
			clip = "Fb_firstHit"
			loop = false
			nxt = "down"
			sfx("CHQ_VP_reeling_backwards.ogg")
			sfx("AA_sound_aoogah.ogg")
		"downhit":
			flash()
			clip = "Fb_downHit"
			loop = false
			nxt = "down"
			sfx("CHQ_VP_reeling_backwards.ogg")
		"down":
			clip = "Fb_downNeutral"
		"jump":
			clip = "Fb_jump"
			loop = false
			nxt = "neutral"
			sfx("General_throw_miss.ogg")
			_cue = "boom"
			_cued = false
		"throw":
			clip = "Fb_UpThrow"
			loop = false
			nxt = "neutral"
			sfx("CHQ_VP_frisbee_gears.ogg")
		"spin":
			clip = "Bb2Ff_spin"
			loop = false
			nxt = "neutral"
			sfx("CHQ_VP_spin.ogg")
			_cue = "rain"
			_cued = false
		"fall":
			clip = "Fb_fall"
			loop = false
			sfx("CHQ_VP_reeling_backwards.ogg")
			_cue = "death"
			_cued = false
		_:
			clip = "Fb_neutral"
	if clip == _pose:
		_pose_loop = loop
		return
	_cue = ""
	_cued = false
	_pose = clip
	_pose_time = 0.0
	_pose_loop = loop
	_pose_next = nxt
	_ensure_bank(clip)


func _advance_pose(delta: float) -> void:
	if _pose == "" or _vp == null or _poser == null:
		return
	var bank: Dictionary = _banks.get(_pose, {})
	var frames := int(bank.get("frames", 0))
	var fps := float(bank.get("fps", 24.0))
	if frames < 1 or fps <= 0.0:
		return
	if _pose_hold >= 0.0:
		_pose_time = _pose_hold
		_pose_hold = -1.0
	else:
		_pose_time += delta
	_play_cue()
	if _movie == "victory" and _pose == "Fb_fall" and _pose_time >= float(frames) / fps:
		_begin_epilogue()
	if frames == 1:
		_poser._pose_clip(bank, 0, 0, 0.0)
		_keep_treads()
		if not _pose_loop and _pose_next != "" and _pose_time >= 0.4:
			pose(_pose_next)
		return
	if not _pose_loop and _pose_next != "" and _pose_time >= float(frames) / fps:
		pose(_pose_next)
		return
	_poser._pose_elapsed(bank, _pose_time, fps, _pose_loop)
	_keep_treads()


func _ensure_bank(clip: String) -> void:
	if _vp == null or _banks.has(clip):
		return
	var path := "res://assets/cogs/bosses/anims/%s.walk" % clip
	if not FileAccess.file_exists(path):
		return
	if _rates.is_empty():
		_load_rates()
	if _poser == null:
		_poser = StreetCog.new()
	var bank := _poser._read_bank(path, _vp)
	bank["fps"] = float(_rates.get(clip, 24.0))
	_shade_bank(bank)
	_banks[clip] = bank


func _load_rates() -> void:
	var path := "res://assets/cogs/bosses/anims/clips.json"
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		for key in parsed:
			var row: Variant = parsed[key]
			if row is Dictionary:
				_rates[str(key)] = float(row.get("fps", 24.0))


func _scroll_treads(moved: Vector3, yaw: float) -> void:
	if _vp == null:
		return
	# rollBossToPoint. Both treads share the roll rate. A turn runs them apart.
	var along := moved.dot(-_vp.global_transform.basis.z)
	var roll := along * (3.5 / 7.5)
	# A snapped look is not the original timed turn. Keep one frame from spinning the tread.
	var turn := rad_to_deg(clampf(yaw, deg_to_rad(-15.0), deg_to_rad(15.0))) * (3.5 / 20.0)
	_left_tread += roll + turn
	_right_tread += roll - turn
	_keep_treads()


func _keep_treads() -> void:
	_tread_material("left_tread", true)
	_tread_material("right_tread", false)
	if _left_mat != null:
		_left_mat.uv1_offset.x = _left_tread
	if _right_mat != null:
		_right_mat.uv1_offset.x = _right_tread


func _tread_material(node_name: String, left: bool) -> void:
	var mesh := _vp.find_child(node_name, true, false) as MeshInstance3D
	if mesh == null:
		return
	var kept := _left_mat if left else _right_mat
	if kept == null:
		var source := mesh.get_surface_override_material(0) as BaseMaterial3D
		if source == null and mesh.mesh != null:
			source = mesh.mesh.surface_get_material(0) as BaseMaterial3D
		if source == null:
			return
		kept = source.duplicate() as BaseMaterial3D
		if left:
			_left_mat = kept
		else:
			_right_mat = kept
	mesh.set_surface_override_material(0, kept)


func widen() -> void:
	# BossBattleCameraFov. The pie round is wider than the Cog HQ view.
	_set_fov(72.0)


func _use_hq_fov() -> void:
	# CogHQCameraFov. The elevator, the speech, and the cog battles use this.
	_set_fov(60.0)


func _set_fov(fov: float) -> void:
	var camera := _camera()
	if camera == null:
		return
	if _saved_fov < 0.0:
		_saved_fov = camera.fov
	camera.fov = fov


func _restore_fov() -> void:
	var camera := _camera()
	if camera == null or not is_instance_valid(camera) or _saved_fov < 0.0:
		return
	camera.fov = _saved_fov
	_saved_fov = -1.0


func _set_collisions(enabled: bool) -> void:
	# collisionsOff. He can roll through the group, and the floor still holds them.
	var body := _player_body()
	if body == null:
		return
	if enabled:
		if _mask_saved >= 0:
			body.collision_mask = _mask_saved
			_mask_saved = -1
		return
	if _mask_saved < 0:
		_mask_saved = body.collision_mask
	body.collision_mask = 0


func _tick_collisions(delta: float) -> void:
	if _collide_back < 0.0:
		return
	_collide_back = maxf(_collide_back - delta, 0.0)
	if _collide_back <= 0.0:
		_collide_back = -1.0
		_set_collisions(true)
		if _release_when_solid:
			_release_when_solid = false
			_hold(false)


func _capture_peer_exp() -> void:
	# The first gag points we see are the ones from before the cog fights.
	if _exp_frozen:
		return
	for person in _party():
		if _local_person(person):
			continue
		var peer := _peer_of(person)
		if _peer_before.has(peer):
			continue
		var exp: Variant = ToonNet.latest("toon:%d" % peer).get("exp", [])
		if exp is Array and (exp as Array).size() > 0:
			_peer_before[peer] = (exp as Array).duplicate()


func _reward_for(person: Node3D) -> Dictionary:
	var before: Dictionary = {}
	var earned: Dictionary = {}
	var after: Array = []
	var prior: Array = []
	if _local_person(person):
		var loadout := ToonLoadout.for_selected()
		for track in ToonLoadout.TRACK_COUNT:
			prior.append(int(_exp_before.get(track, 0)))
			after.append(loadout.experience_of(track) if loadout != null else prior[track])
	else:
		var peer := _peer_of(person)
		if not _peer_before.has(peer):
			return {"any": false, "before": before, "earned": earned}
		prior = _peer_before[peer]
		var exp: Variant = ToonNet.latest("toon:%d" % peer).get("exp", [])
		if exp is Array:
			after = exp
	var any := false
	for track in ToonLoadout.TRACK_COUNT:
		var was := int(prior[track]) if track < prior.size() else 0
		var now := int(after[track]) if track < after.size() else was
		before[track] = was
		var gain := maxi(now - was, 0)
		earned[track] = gain
		if gain > 0:
			any = true
	return {"any": any, "before": before, "earned": earned}


func _local_person(person: Node) -> bool:
	return person == _player_body() or _peer_of(person) == ToonNet.peer_id()


func _person_name(person: Node3D) -> String:
	var actor := _actor_of(person)
	if actor != null and actor.name != "":
		return actor.name
	return String(ToonNet.latest("toon:%d" % _peer_of(person)).get("name", "Toon"))


func _player_body() -> CharacterBody3D:
	if _boss == null:
		return null
	var host := _boss.get_parent()
	if host == null:
		return null
	return host.get_node_or_null("Player") as CharacterBody3D


func _aim_reward() -> void:
	# chooseRewardShot with the group shot turned off. The camera sits on the Toon whose tracks are filling.
	var body := _reward_focus if _reward_focus != null and is_instance_valid(_reward_focus) else _player_body()
	var camera := _camera()
	if body == null or camera == null:
		return
	var actor := _actor_of(body)
	var height := 3.5
	if actor != null:
		var head := actor.find_child("def_head", true, false) as Node3D
		if head != null:
			height = maxf(head.global_position.y - body.global_position.y, 2.0)
	var panda := Vector3(5.2, 5.45, height * 0.66) if _reward_side else Vector3(0.0, 8.0, height * 0.66)
	var local := Vector3(panda.x, panda.z, -panda.y)
	camera.global_position = body.global_transform * local
	var look := body.global_position + Vector3(0.0, height * 0.5, 0.0)
	if camera.global_position.distance_squared_to(look) > 0.04:
		camera.look_at(look, Vector3.UP)


func flash() -> void:
	# flashRed. A tenth of a second of red, then it fades back.
	if _vp == null:
		return
	if _flash_paint == null:
		_flash_paint = StandardMaterial3D.new()
		_flash_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_paint.albedo_color = Color(1, 0, 0, 0.65)
	_flash_left = 0.4
	for node in _vp.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = _flash_paint


func _tick_flash(delta: float) -> void:
	if _flash_left <= 0.0 or _flash_paint == null:
		return
	_flash_left = maxf(_flash_left - delta, 0.0)
	var color := _flash_paint.albedo_color
	color.a = 0.65 if _flash_left > 0.3 else _flash_left / 0.3 * 0.65
	_flash_paint.albedo_color = color
	if _flash_left > 0.0 or _vp == null:
		return
	for node in _vp.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = null


func _show_shadow() -> void:
	# The shadow sits on the floor under the cage once it has dropped that far.
	if _shadow != null:
		_shadow.visible = true
		return
	var host := _boss.get_parent() if _boss != null else self
	_shadow = MeshInstance3D.new()
	_shadow.name = "CageShadow"
	var plane := PlaneMesh.new()
	plane.size = Vector2(7, 7)
	_shadow.mesh = plane
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.albedo_color = Color(1, 1, 1, 0.6)
	var tex := load("res://assets/neighborhoods/toontown_central/props/drop_shadow.png") as Texture2D
	if tex != null:
		paint.albedo_texture = tex
	_shadow.material_override = paint
	host.add_child(_shadow)
	_shadow.global_position = _world(Vector3(0, 77.9, 18)) + Vector3(0, 0.08, 0)


func _hide_shadow() -> void:
	if _shadow != null:
		_shadow.visible = false


func _play_uncage(delta: float) -> void:
	# The cage lowers, the door swings, he walks out, cheers, and jumps.
	var drop := clampf(_t / 0.5, 0.0, 1.0)
	drop = 1.0 - pow(1.0 - drop, 2.0)
	if _cage != null:
		_cage.position.z = lerpf(25.0, 18.0, drop)
	var door := _geom.find_child("cage_door", true, false) as Node3D if _geom != null else null
	if door != null:
		var swing := clampf(_t / 0.5, 0.0, 1.0)
		swing = 1.0 - pow(1.0 - swing, 2.0)
		door.rotation_degrees = Vector3(90.0 * swing, 0, 0)
		if _t >= 0.5 and not bool(door.get_meta("opened", false)):
			door.set_meta("opened", true)
			sfx("CHQ_SOS_cage_door.ogg")
	if _toon == null:
		if _t >= 2.6:
			_finish_uncage()
		return
	if _t < 0.7:
		_toon.position = Vector3(0, -2, -6)
	elif _t < 1.5:
		var walk := (_t - 0.7) / 0.8
		_toon.position = Vector3(0, lerpf(-2.0, -6.0, walk), -6)
		if _toon.has_method("set_locomotion"):
			_toon.call("set_locomotion", 4.0, false, false, delta)
	elif _t < 2.6:
		_cheer()
		if _toon.has_method("set_locomotion"):
			_toon.call("set_locomotion", 0.0, false, false, delta)
	else:
		_finish_uncage()


func _cheer() -> void:
	if _caged_line == "Yippee!":
		return
	_caged_line = "Yippee!"
	_toon.set_meta("chat_line", "Yippee!")
	_toon.set_meta("chat_until", Time.get_ticks_msec() + 2500)
	ToonSpeech.speak(_toon, "Yippee!")
	if _toon.has_method("play_gesture"):
		_toon.call("play_gesture", "jump", 1.0, false)


func _finish_uncage() -> void:
	if _toon != null and _toon.has_method("clear_gesture"):
		_toon.call("clear_gesture")
	var host := _boss.get_parent() if _boss != null else null
	var body := host.get_node_or_null("Player") as Node3D if host != null else null
	if _toon != null and body != null and _toon.global_position.distance_squared_to(body.global_position) > 0.25:
		_toon.look_at(body.global_position, Vector3.UP)
	_movie = "thanks"
	_pages = _thanks()
	_page = 0
	_say(_pages[0] if _pages.size() > 0 else "")
	if _boss != null and _boss.has_method("show_pages"):
		_boss.call("show_pages")


func _exit_tree() -> void:
	_set_collisions(true)
	_restore_fov()


func _set_cage(index: int) -> void:
	if _cage == null:
		return
	var clamped := clampi(index, 0, _CAGE_Z.size() - 1)
	_cage.position.z = _CAGE_Z[clamped]
	if clamped >= 4:
		_show_shadow()
	else:
		_hide_shadow()


func _open_cage() -> void:
	_movie = "uncage"
	_t = 0.0
	_set_cage(4)
	if _toon != null:
		_toon.position = Vector3(0, -2, -6)
	var door := _geom.find_child("cage_door", true, false) as Node3D if _geom != null else null
	if door != null:
		door.rotation_degrees = Vector3.ZERO
	sfx("CHQ_SOS_cage_lower.ogg")


func _thanks() -> PackedStringArray:
	var lines: PackedStringArray = [
		"It's great to be free!\nThanks for all your help!\nI am in your debt.\nHere's my card. If you ever need a hand in battle, give a shout!\nJust click on your SOS button.",
	]
	if _boss != null and _boss.has_method("promotion_note"):
		var extra := String(_boss.call("promotion_note"))
		if extra != "":
			lines.append(extra)
	lines.append("See ya!")
	return lines


func _say(text: String, voice := false) -> void:
	if text == _said:
		return
	_said = text
	if _boss != null and _boss.has_method("set_line"):
		_boss.call("set_line", text)
	if voice:
		_voice(text)
	elif text != "" and _toon != null:
		ToonSpeech.speak(_toon, text)


func _speech_anim(speech: float) -> void:
	# Ff_speech, turn to wave, wave, turn back, then speech again.
	if speech < 10.0:
		_cue_pose("speech", speech + 2.0, true)
	elif speech < 12.0:
		_cue_pose("turn", speech - 10.0, false)
	elif speech < 16.0:
		_cue_pose("wave", speech - 12.0, true)
	elif speech < 18.0:
		_cue_pose("turn", 2.0 - (speech - 16.0), false)
	elif speech < 25.0:
		_cue_pose("speech", speech - 18.0, true)
	elif speech < 31.0:
		_cue_pose("look", speech - 25.0, false)
	else:
		_cue_pose("face", speech - 31.0, false)


func _cue_pose(which: String, at: float, loop: bool) -> void:
	pose(which)
	_pose_loop = loop
	_pose_hold = maxf(at, 0.0)


func _open_iris() -> void:
	# enterWaitForToons fades the screen. It lifts as the elevator movie starts.
	var layer := CanvasLayer.new()
	layer.layer = 80
	layer.name = "VpIris"
	add_child(layer)
	_iris = ColorRect.new()
	_iris.color = Color(0, 0, 0, 1)
	_iris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_iris.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_iris)


func _lift_iris(delta: float) -> void:
	if _iris == null:
		return
	var color := _iris.color
	color.a = maxf(color.a - delta / 0.8, 0.0)
	_iris.color = color
	if color.a <= 0.0:
		var layer := _iris.get_parent()
		_iris = null
		if layer != null:
			layer.queue_free()


func _blow_suits() -> void:
	# loseCogSuits. Dust, then the suit comes off into the slip backward.
	for suit in _suits:
		if not is_instance_valid(suit):
			continue
		var anchor := suit.get_meta("toon_anchor") as Node3D
		_puff(anchor.global_position if anchor != null else suit.global_position)
	await get_tree().create_timer(0.3).timeout
	if not is_inside_tree():
		return
	var actors: Array[Node] = []
	for suit in _suits:
		if is_instance_valid(suit):
			var actor := suit.get_meta("toon_actor") as Node
			if actor != null:
				actors.append(actor)
	_remove_suits()
	for actor in actors:
		if not is_instance_valid(actor):
			continue
		if actor.has_method("set_expression"):
			actor.call("set_expression", "sad")
		if actor.has_method("play_emote"):
			actor.call("play_emote", 14)


func _puff(at: Vector3) -> void:
	var bits := CPUParticles3D.new()
	bits.name = "SuitDust"
	bits.position = at
	bits.amount = 28
	bits.lifetime = 0.7
	bits.one_shot = true
	bits.explosiveness = 0.85
	bits.emitting = true
	bits.direction = Vector3(0, 1, 0)
	bits.spread = 60.0
	bits.initial_velocity_min = 1.0
	bits.initial_velocity_max = 3.0
	bits.gravity = Vector3(0, -2.0, 0)
	bits.scale_amount_min = 0.35
	bits.scale_amount_max = 0.8
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	bits.mesh = mesh
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.85, 0.85, 0.82, 0.7)
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bits.material_override = paint
	var host := _boss.get_parent() if _boss != null else self
	host.add_child(bits)
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(bits.queue_free)


func _tick_gears(delta: float) -> void:
	if _gear_time > 0.0 and _gear_mesh != null and _vp != null:
		_gear_birth += delta
		while _gear_birth >= 0.005 and _gears.size() < 200:
			_gear_birth -= 0.005
			_birth_gear()
		_gear_time = maxf(_gear_time - delta, 0.0)
	if _gears.is_empty():
		return
	var kept: Array[Dictionary] = []
	var sink := Vector3(0, -79, 0)
	for item in _gears:
		var gear := item
		var body := gear["body"] as Node3D
		if body == null or not is_instance_valid(body):
			continue
		var age := float(gear["age"]) + delta
		if age >= 1.0:
			body.queue_free()
			continue
		var pos: Vector3 = gear["pos"]
		var vel: Vector3 = gear["vel"]
		var toward := sink - pos
		var dist := toward.length()
		if dist < 50.0 and dist > 0.05:
			vel += toward / dist * (15.9701 / (dist * dist)) * delta
		vel += Vector3(0, 0, 10.0) * delta
		pos += vel * delta
		gear["age"] = age
		gear["pos"] = pos
		gear["vel"] = vel
		body.position = pos
		body.scale = Vector3.ONE * lerpf(0.15, 0.3, age)
		kept.append(gear)
	_gears = kept


func _birth_gear() -> void:
	var root := _vp.get_node_or_null("GearShower") as Node3D
	if root == null:
		root = Node3D.new()
		root.name = "GearShower"
		root.position = Vector3(0, 4.6, 0)
		_vp.add_child(root)
	var body := MeshInstance3D.new()
	body.mesh = _gear_mesh
	root.add_child(body)
	var dir := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	if dir.length() < 0.001:
		dir = Vector3(0, 1, 0)
	dir = dir.normalized()
	body.position = dir
	body.scale = Vector3.ONE * 0.15
	_gears.append({"body": body, "pos": dir, "vel": dir * 5.0, "age": 0.0})


func _voice(text: String) -> void:
	# Avatar.playDialogueForString. "!" is an exclamation, "?" a question.
	# Length picks grunt, murmur, or the long statement. Exclamation uses the statement clip.
	var file := "Boss_COG_VO_statement.ogg"
	var lower := text.to_lower()
	if lower.contains("!"):
		file = "Boss_COG_VO_statement.ogg"
	elif lower.contains("?"):
		file = "Boss_COG_VO_question.ogg"
	elif text.length() <= 6:
		file = "Boss_COG_VO_grunt.ogg"
	elif text.length() <= 12:
		file = "Boss_COG_VO_murmur.ogg"
	sfx(file)


func _drop_into(next: String) -> void:
	# makeEndOfBattleMovie. One missing side starts a step lower.
	_drop_next = next
	_cage_i = (1 if _solo() else 0) if next == "roll" else (3 if _solo() else 2)
	_movie = "drop"
	_t = 0.0
	_said = ""
	if _vp != null:
		_vp.visible = false
	_set_cage(_cage_i)
	sfx("CHQ_SOS_cage_lower.ogg")
	if _cage_i >= 0 and _cage_i < _DROP.size():
		_say(_DROP[_cage_i])
	_aim_cage()


func _lower_cage() -> void:
	if _cage == null or _cage_i < 0 or _cage_i + 1 >= _CAGE_Z.size():
		return
	var u := clampf(_t / 1.0, 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	_cage.position.z = lerpf(_CAGE_Z[_cage_i], _CAGE_Z[_cage_i + 1], u)
	_aim_cage()


func _finish_drop() -> void:
	_cage_i += 1
	_set_cage(_cage_i)
	if _vp != null:
		_vp.visible = true
	if _drop_next == "roll":
		_begin_roll()
	else:
		_begin_prepare3()


func _begin_roll() -> void:
	_movie = "roll"
	_t = 0.0
	_finish_as = "roll"
	_roll = _roll_path()
	_place_vp(_roll[0], _roll[1])
	_spawn_barrels()
	_set_collisions(false)
	_collide_back = 0.5


func _begin_prepare3() -> void:
	_movie = "prepare3"
	_pages = _pending_pages
	_page = 0
	_t = 0.0
	_finish_as = "prepare3"
	_set_cage(4)
	pose("neutral")
	_place_vp(Vector3(0, 60, 18), Vector3(0, 77, 18))
	_say(_pages[0] if _pages.size() > 0 else "")
	if _boss != null and _boss.has_method("show_pages"):
		_boss.call("show_pages")


func _aim_cage() -> void:
	var camera := _camera()
	if camera == null or _cage == null or _marker == null:
		return
	_marker.global_position = _cage.global_position
	var panda: Vector3 = _marker.position
	camera.global_position = _world(panda + Vector3(0, -50, 0))
	if camera.global_position.distance_squared_to(_cage.global_position) > 0.04:
		camera.look_at(_cage.global_position, Vector3.UP)


func seat_cage(index: int) -> void:
	_cage_i = index
	_ensure_cast()
	_set_cage(index)


func _solo() -> bool:
	return _party().size() < 2


func _remember_exp() -> void:
	var loadout := ToonLoadout.for_selected()
	if loadout == null:
		return
	_exp_before.clear()
	for track in ToonLoadout.TRACK_COUNT:
		_exp_before[track] = loadout.experience_of(track)


func _show_gag_reward() -> void:
	# doToonVictory. Each Toon who earned points gets the camera, then the next one.
	if _win != null:
		_win.stop()
	_exp_frozen = true
	var loadout := ToonLoadout.for_selected()
	if loadout == null or _boss == null or not _boss.has_method("play_gag_reward"):
		_open_thanks()
		return
	for person in _party():
		var pack := _reward_for(person)
		if not bool(pack.get("any", false)):
			continue
		var earned: Dictionary = pack["earned"]
		_reward_focus = person
		_reward_side = randf() < 0.5
		_reward_cam = true
		var actor := _actor_of(person)
		if actor != null and actor.has_method("play_emote"):
			actor.call("play_emote", 6)
		if _local_person(person):
			await _boss.play_gag_reward(loadout, _exp_before, earned)
		else:
			await _boss.play_gag_reward(loadout, pack["before"], earned, _person_name(person), false)
		if not is_inside_tree():
			return
	_reward_cam = false
	_reward_focus = null
	_open_thanks()


func _shade_bank(bank: Dictionary) -> void:
	# Street suits blend on the pose shader. The VP mesh arrives as a plain material.
	if _poser == null:
		return
	for item in bank.get("clips", []):
		if not (item is Dictionary):
			continue
		var record: Dictionary = item
		var instance := record.get("instance") as MeshInstance3D
		if instance == null:
			continue
		if instance.name == "left_tread" or instance.name == "right_tread":
			continue
		var overrides: Array = record.get("overrides", [])
		for index in overrides.size():
			var source: Variant = overrides[index]
			if source is BaseMaterial3D:
				var shaded: Material = _poser._shade_material(source)
				overrides[index] = shaded
				instance.set_surface_override_material(index, shaded)
		record["overrides"] = overrides


func _hold(holding: bool) -> void:
	if _boss == null:
		return
	var host := _boss.get_parent()
	for node_name in ["PlaygroundToon", "Player"]:
		var toon := host.get_node_or_null(node_name) if host != null else null
		if toon != null and toon.has_method("hold_for_race"):
			toon.call("hold_for_race", holding)


func _world(panda: Vector3) -> Vector3:
	if _marker == null:
		return panda
	_marker.position = panda
	return _marker.global_position


func _camera() -> Camera3D:
	if _boss == null:
		return null
	var host := _boss.get_parent()
	if host == null:
		return null
	var toon := host.get_node_or_null("ToonCamera") as Camera3D
	if toon != null:
		return toon
	return host.find_child("Camera", true, false) as Camera3D


func _begin_epilogue() -> void:
	if _dancing or _epilogue:
		return
	_dancing = true
	if _vp != null:
		_vp.visible = false
	_ring_toons()
	_victory_dance()
	_t = 0.0
	_movie = "dance"
	_finish_as = "victory"


func _open_thanks() -> void:
	if _epilogue:
		return
	_epilogue = true
	if _win != null:
		_win.stop()
	_open_cage()
	music("epilogue")
	_use_hq_fov()
	_finish_as = "victory"
	var camera := _camera()
	if camera != null:
		# enterEpilogue. Panda (-24, 52, 27.5), looking at the cage.
		camera.global_position = _world(Vector3(-24.0, 52.0, 27.5))
		var focus := _world(Vector3(0.0, 78.0, 22.0))
		if camera.global_position.distance_squared_to(focus) > 0.04:
			camera.look_at(focus, Vector3.UP)


func _victory_dance() -> void:
	# MovieToonVictory. The gag points already came from the cog fights.
	var path := "res://assets/audio/sfx/ENC_Win.mp3"
	if FileAccess.file_exists(path):
		var stream := load(path) as AudioStream
		if stream != null:
			if _win == null:
				_win = AudioStreamPlayer.new()
				_win.name = "VpWin"
				add_child(_win)
			_win.stream = stream
			_win.play()
	for person in _party():
		if person.has_method("play_emote"):
			person.call("play_emote", 6)


func _show_frolic() -> void:
	# After the goodbye he is back at the battle spot and the Toons can walk.
	if _vp == null:
		return
	_vp.visible = true
	pose("neutral")
	_hide_shadow()
	_use_hq_fov()
	_place_vp(Vector3(0, -35, 0), Vector3(0, 0, 5))


func _ride_elevator() -> void:
	_place_vp(_elevator_spot(), Vector3(0, -20, 5))
	_seat_toons()
	if _t >= _RIDE and _door_goal < 0.5:
		_door_goal = 1.0
	var height := 8.0 if _t >= _RIDE else _ride_bob(_t)
	var camera := _camera()
	if camera == null:
		return
	var spot := _elevator_spot()
	camera.global_position = _world(spot + Vector3(0, 30, height))
	var focus := _world(spot + Vector3(0, 0, 6))
	if camera.global_position.distance_squared_to(focus) > 0.04:
		camera.look_at(focus, Vector3.UP)


func _ride_bob(time: float) -> float:
	# getRideElevatorInterval, played twice. The camera dips, then rises.
	var u := fposmod(time, 4.0)
	if u < 0.5:
		return 8.0
	if u < 1.0:
		return lerpf(8.0, 7.8, (u - 0.5) / 0.5)
	if u < 1.5:
		return lerpf(7.8, 8.0, (u - 1.0) / 0.5)
	if u < 2.5:
		return 8.0
	if u < 3.0:
		return lerpf(8.0, 8.2, (u - 2.5) / 0.5)
	return lerpf(8.2, 8.0, (u - 3.0) / 1.0)


func _seat_toons() -> void:
	var seats: Array[Vector3] = [
		Vector3(-2.5, 9, 0.1), Vector3(2.5, 9, 0.1),
		Vector3(-8.0, 9, 0.1), Vector3(8.0, 9, 0.1),
		Vector3(-2.5, 4, 0.1), Vector3(2.5, 4, 0.1),
		Vector3(-8.0, 4, 0.1), Vector3(8.0, 4, 0.1),
	]
	_place_party(seats)


func _step_out() -> void:
	var spots: Array[Vector3] = [
		Vector3(-4.6, -5.2, 0.1), Vector3(4.6, -5.2, 0.1),
		Vector3(-1.6, -6.2, 0.1), Vector3(1.6, -6.2, 0.1),
	]
	_place_party(spots)


func _place_party(spots: Array[Vector3]) -> void:
	var origin := _elevator_spot()
	var people := _party()
	for index in people.size():
		var person := people[index]
		var spot: Vector3 = spots[mini(index, spots.size() - 1)]
		var panda := origin + spot
		person.global_position = _world(panda)
		var ahead := _world(panda + Vector3(0, -1, 0))
		if person.global_position.distance_squared_to(ahead) > 0.04:
			person.look_at(ahead, Vector3.UP)
		_snap_suit(person, ahead)


func _snap_suit(anchor: Node3D, ahead: Vector3) -> void:
	var suit := _suit_for(anchor)
	if suit == null:
		return
	suit.global_position = anchor.global_position
	if suit.global_position.distance_squared_to(ahead) > 0.04:
		suit.look_at(ahead, Vector3.UP)


func _suit_for(anchor: Node3D) -> Node3D:
	for suit in _suits:
		if is_instance_valid(suit) and suit.get_meta("toon_anchor") == anchor:
			return suit
	return null


func _wear_suits() -> void:
	# putToonInCogSuit. A finished Sellbot suit is the one they are climbing.
	# Anything short of that is a rental Cold Caller. The level is still theirs.
	for person in _party():
		_wear_one(person, _suit_spec(person))


func _suit_spec(anchor: Node3D) -> Dictionary:
	var cog_type := 0
	var level := 1
	if _is_local(anchor):
		var progress := DisguisePage.suit_progress(3)
		level = int(progress.get("level", 0)) + 1
		if DisguisePage.suit_complete(3):
			cog_type = int(progress.get("type", 0))
	else:
		var actor := _actor_of(anchor)
		var peer := int(actor.get_meta("peer")) if actor != null and actor.has_meta("peer") else 0
		var state := ToonNet.latest("toon:%d" % peer)
		if state.has("suit_level"):
			level = int(state.get("suit_level", 0)) + 1
			if bool(state.get("suit_ready", false)):
				cog_type = int(state.get("suit_type", 0))
	var spec: Dictionary = (_DOOBERS[clampi(cog_type, 0, _DOOBERS.size() - 1)] as Dictionary).duplicate()
	spec["level"] = maxi(level, 1)
	return spec


func _is_local(anchor: Node3D) -> bool:
	if anchor.name == "Player":
		return true
	return anchor.get_parent() != null and anchor.get_parent().name == "Player"


func _wear_one(anchor: Node3D, spec: Dictionary) -> void:
	if _suit_for(anchor) != null:
		return
	var actor := _actor_of(anchor)
	if actor == null:
		return
	var parent := anchor.get_parent()
	if parent == null:
		return
	var suit := StreetCog.new()
	suit.name = "CogSuit"
	parent.add_child(suit)
	suit.present({
		"code": spec["code"],
		"name": spec["name"],
		"dept": "s",
		"body": spec["body"],
		"height": spec["height"],
		"level": int(spec["level"]),
		"hp": 1,
		"max": 1,
	}, {})
	var joint := suit.find_child("joint_head", true, false) as Node3D
	var head := actor.find_child("head_look", true, false) as Node3D
	var neck := head.get_parent() as Node3D if head != null else null
	if joint == null or head == null or neck == null:
		suit.queue_free()
		return
	for piece in joint.get_children():
		if piece is Node3D:
			(piece as Node3D).visible = false
	head.reparent(joint)
	# The head mesh is panda-space. This is the same basis _face uses at heading 0,
	# so the face points the way the suit is looking.
	var scale := actor.transform.basis.get_scale().x
	if scale < 0.01:
		scale = 1.0
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	head.transform = Transform3D(upright.scaled(Vector3.ONE * scale), Vector3(0, 0.2, 0))
	for child in actor.get_children():
		if child.name == "1000" or child.name == "500" or child.name == "250" or child.name == "0":
			child.visible = false
	suit.set_meta("toon_anchor", anchor)
	suit.set_meta("toon_actor", actor)
	suit.set_meta("toon_head", head)
	suit.set_meta("toon_neck", neck)
	_suits.append(suit)
	var board := _tags()
	if board != null and board.has_method("dress_suit"):
		var toon_name := actor.name if actor.name != "Toon" else "Toon"
		var card := "%s\n%s\nLevel %d" % [toon_name, String(spec["name"]), int(spec["level"])]
		board.call("dress_suit", actor, card, float(spec["height"]) + 1.3)


func _remove_suits() -> void:
	for suit in _suits:
		if not is_instance_valid(suit):
			continue
		var head := suit.get_meta("toon_head") as Node3D
		var neck := suit.get_meta("toon_neck") as Node3D
		var actor := suit.get_meta("toon_actor") as Node3D
		if head != null and is_instance_valid(head) and neck != null and is_instance_valid(neck):
			head.reparent(neck)
			head.transform = Transform3D.IDENTITY
		if actor != null and is_instance_valid(actor):
			for child in actor.get_children():
				if child.name == "1000" or child.name == "500" or child.name == "250" or child.name == "0":
					child.visible = true
			var board := _tags()
			if board != null and board.has_method("undress_suit"):
				board.call("undress_suit", actor)
		suit.queue_free()
	_suits.clear()


func _actor_of(anchor: Node3D) -> Node3D:
	if anchor.find_child("head_look", true, false) != null and anchor.get_node_or_null("1000") != null:
		return anchor
	for child in anchor.get_children():
		if child is Node3D and (child as Node3D).find_child("head_look", true, false) != null:
			return child
	return null


func _tags() -> Node:
	if _boss == null:
		return null
	var host := _boss.get_parent()
	if host == null:
		return null
	return host.find_child("Nametags", true, false)


func _party() -> Array[Node3D]:
	var people: Array[Node3D] = []
	if _boss == null:
		return people
	var host := _boss.get_parent()
	if host == null:
		return people
	for node_name in ["Player", "PlaygroundToon"]:
		var body := host.get_node_or_null(node_name) as Node3D
		if body != null and not people.has(body):
			people.append(body)
	for node in host.find_children("", "ToonActor", true, false):
		if node == _toon or people.has(node):
			continue
		if not node.has_meta("peer"):
			continue
		if node is Node3D:
			people.append(node)
	return people


func _stick_floor() -> void:
	# stickBossToFloor. Rays ten units ahead, under him, and ten units behind.
	if _vp == null:
		return
	var forward := -_vp.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.001:
		forward = Vector3(0, 0, -1)
	forward = forward.normalized()
	var front_hit: Variant = _floor_at(_vp.global_position + forward * 10.0)
	var middle_hit: Variant = _floor_at(_vp.global_position)
	var back_hit: Variant = _floor_at(_vp.global_position - forward * 10.0)
	if middle_hit == null:
		return
	var middle := middle_hit as Vector3
	var center := middle
	var tilt := 0.0
	if front_hit != null and back_hit != null:
		var front := front_hit as Vector3
		var back := back_hit as Vector3
		var average := (front + back) * 0.5
		if average.y > middle.y:
			center = average
		if front.y > middle.y + 0.01 or back.y > middle.y + 0.01:
			var span := Vector2(front.x - back.x, front.z - back.z).length()
			tilt = atan2(front.y - back.y, maxf(span, 0.01))
	_set_world_y(center.y)
	var yaw := _vp.global_rotation.y
	_vp.global_rotation = Vector3(-tilt, yaw, 0.0)


func _floor_at(at: Vector3) -> Variant:
	if _vp == null:
		return null
	var world := _vp.get_world_3d()
	if world == null:
		return null
	var query := PhysicsRayQueryParameters3D.create(at + Vector3(0, 8, 0), at + Vector3(0, -20, 0))
	query.collision_mask = 1
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit["position"] as Vector3


func _set_world_y(height: float) -> void:
	if _vp == null:
		return
	var before := _vp.global_position.y
	_vp.position.z += 1.0
	var rise := _vp.global_position.y - before
	_vp.position.z -= 1.0
	if absf(rise) < 0.001:
		return
	_vp.position.z += (height - _vp.global_position.y) / rise


func touched_cage() -> void:
	_got_pies = true
	_throw_advice = 30.0
	var line := _cage_line(randi_range(10, 12))
	_boss_say(line, 6.0)
	_cage_chat = 15.0


func threw_pie() -> void:
	_threw = true


func out_of_pies() -> void:
	_boss_say("You need to get more pies!", 6.0)
	_pie_advice = 20.0


func _pie_lines(delta: float) -> void:
	if _boss == null or not _boss.has_method("phase") or String(_boss.call("phase")) != "pies":
		return
	if not _got_pies:
		_pie_advice -= delta
		if _pie_advice <= 0.0:
			_pie_advice = 30.0
			_boss_say("Jump up to touch the cage to get pies.", 6.0)
	elif not _threw and _throw_advice >= 0.0:
		_throw_advice -= delta
		if _throw_advice <= 0.0:
			_throw_advice = -1.0
			_boss_say("Click to throw pies!", 6.0)
	_cage_chat -= delta
	if _cage_chat > 0.0:
		return
	_cage_chat = 15.0
	var index := randi_range(20, 21)
	if _got_pies:
		if _advice_at <= 106:
			index = _advice_at
			_advice_at += 1
		elif randf() < 0.2:
			index = randi_range(100, 106)
		else:
			return
	_boss_say(_cage_line(index), 6.0)


func _cage_line(index: int) -> String:
	var lines := {
		10: "Nice jump, %(toon)s.  Here are some pies!",
		11: "Hi, %(toon)s!  Have some pies!",
		12: "Hey there, %(toon)s!  You've got some pies now!",
		20: "Hey, %(toon)s!  Jump up to my cage and get some pies to throw!",
		21: "Hi, %(toon)s!  Use the Ctrl key to jump up and touch my cage!",
		100: "Click to throw a pie.",
		101: "Click to throw. The pie flies the way you are looking.",
		102: "First try to lob a pie inside his undercarriage to gum up his works.",
		103: "Wait for the door to open, and throw a pie straight inside.",
		104: "When he's dizzy, hit him in the face or chest to knock him back!",
		105: "You'll know you've got a good hit when you see the splat in color.",
		106: "If you hit a Toon with a pie, it gives that Toon a Laff point!",
	}
	var text := String(lines.get(index, ""))
	return text.replace("%(toon)s", _toon_name_here())


func _toon_name_here() -> String:
	var people := _party()
	if people.is_empty() or _boss == null:
		return "Toon"
	var host := _boss.get_parent()
	var body := host.get_node_or_null("Player") if host != null else null
	if body != null and body.has_method("battle_name"):
		return String(body.call("battle_name"))
	return "Toon"


func _boss_say(text: String, seconds: float) -> void:
	if text == "" or _boss == null:
		return
	if _boss.has_method("say_for"):
		_boss.call("say_for", text, seconds)
	if _toon != null:
		ToonSpeech.speak(_toon, text)


func _ring_toons() -> void:
	# DistributedSellbotBoss.__arrangeToonsAroundCage. Radius 15, facing the cage.
	if _cage == null or _boss == null:
		return
	var host := _boss.get_parent()
	if host == null:
		return
	var people: Array[Node3D] = []
	for node_name in ["Player", "PlaygroundToon"]:
		var body := host.get_node_or_null(node_name) as Node3D
		if body != null and not people.has(body):
			people.append(body)
	for node in host.find_children("", "ToonActor", true, false):
		if node == _toon or people.has(node):
			continue
		if not node.has_meta("peer"):
			continue
		if node is Node3D:
			people.append(node)
	var count := people.size()
	if count == 0:
		return
	var center := float(count - 1) / 2.0
	var around := _cage.global_position
	for index in count:
		var person := people[index]
		var angle := deg_to_rad(270.0 - 15.0 * (float(index) - center))
		var stand := around + Vector3(cos(angle) * 15.0, 0.0, sin(angle) * 15.0)
		stand.y = _world(Vector3(0.0, 0.0, 18.0)).y
		person.global_position = stand
		if person.global_position.distance_squared_to(around) > 0.25:
			person.look_at(Vector3(around.x, person.global_position.y, around.z), Vector3.UP)


func _elevator_spot() -> Vector3:
	if _geom == null:
		return Vector3(0, -35, 0)
	var entrance := _geom.find_child("elevatorEntrance", true, false) as Node3D
	if entrance == null:
		return Vector3(0, -35, 0)
	return _geom.to_local(entrance.global_position)


func _sos_style(npc_id: int) -> ToonStyle:
	if npc_id == 0:
		return null
	if _sos_dna.is_empty():
		var path := "res://scenes/shticker/sos_dna.json"
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				_sos_dna = parsed
	var dna: Variant = _sos_dna.get(str(npc_id), [])
	if typeof(dna) != TYPE_ARRAY or (dna as Array).size() < 14:
		return null
	var row: Array = dna
	var style := ToonStyle.new()
	style.head = String(row[0])
	style.torso = String(row[1])
	style.legs = String(row[2])
	style.gender = String(row[3])
	style.arm_color = int(row[4])
	style.glove_color = int(row[5])
	style.leg_color = int(row[6])
	style.head_color = int(row[7])
	style.top_tex = int(row[8])
	style.top_color = int(row[9])
	style.bot_tex = int(row[12])
	style.bot_color = int(row[13])
	return style


func music(which: String) -> void:
	var file := ""
	match which:
		"elevator":
			file = "tt_elevator.ogg"
		"battle", "battle1":
			file = "encntr_general_bg.ogg"
		"promotion", "sting":
			file = "encntr_suit_winning_indoor.ogg"
		"between":
			file = "encntr_toon_winning.ogg"
		"battle2", "battle3":
			file = "encntr_suit_winning_indoor.ogg"
		"epilogue":
			file = "encntr_hall_of_fame.ogg"
	if file == "":
		return
	var path := "res://assets/cogs/bosses/audio/" + file
	if not FileAccess.file_exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	if _music == null:
		_music = AudioStreamPlayer.new()
		_music.name = "VpMusic"
		add_child(_music)
	if _music_key == which and _music.playing:
		return
	var copy := stream.duplicate() as AudioStream
	if copy != null:
		stream = copy
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = which != "sting"
	_music_key = which
	_music.stream = stream
	_music.volume_db = 0.0 if which == "sting" else -4.0
	_music.play()


func sfx(file: String) -> void:
	var path := "res://assets/cogs/bosses/audio/" + file
	if not FileAccess.file_exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _play_cue() -> void:
	if _cued or _cue == "":
		return
	var at := 0.9
	if _cue == "boom":
		at = 1.1
	elif _cue == "death":
		at = 1.2
	if _pose_time < at:
		return
	_cued = true
	if _cue == "rain":
		sfx("CHQ_VP_raining_gears.ogg")
		_gear_shower()
	elif _cue == "boom":
		sfx("ENC_cogfall_apart.ogg")
	elif _cue == "death":
		sfx("CHQ_VP_big_death.ogg")


func _gear_shower() -> void:
	# bossCogFrontAttack.ptf. Gears radiate from a sphere, drift back, and sink downward.
	if _vp == null:
		return
	_gear_time = 1.5
	_gear_birth = 0.0
	if _gear_mesh == null:
		var packed := load("res://assets/cogs/bosses/gear.glb") as PackedScene
		if packed == null:
			return
		var gear := packed.instantiate()
		var found := _first_mesh(gear)
		if found != null:
			_gear_mesh = found
		gear.free()


func _first_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return (node as MeshInstance3D).mesh
	for child in node.get_children():
		var found := _first_mesh(child)
		if found != null:
			return found
	return null
