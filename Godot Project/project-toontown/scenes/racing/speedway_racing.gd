extends Node

## Race pads, kart stands, and the three central leaderboards on Goofy Speedway.
## A pad's sign changes track every 15 seconds until a toon is waiting.
## The district owns the pad. Toon Battle and Grand Prix still need two racers.

const _RULES := preload("res://scenes/racing/kart_rules.gd")
const _GARAGE := preload("res://scenes/racing/kart_garage.gd")
const _MODEL := preload("res://scenes/racing/kart_model.gd")
const _RACE := preload("res://scenes/racing/kart_race.gd")
const _RACES := preload("res://scenes/racing/race_matches.gd")
const _GUI := preload("res://scenes/toons/toon_gui.gd")
const _LAYOUT := "res://assets/racing/speedway.json"
const _CLOCK := preload("res://assets/gui/purchase/alarm_clock.png")
const _APPEAR := "res://assets/racing/audio/KART_Appear.ogg"
const _DIALOG := preload("res://assets/gui/tutorial/dialog/dialog_box.png")
const _YES_UP := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_UP.png")
const _YES_DOWN := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_DN.png")
const _YES_HOVER := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_Rllvr.png")
const _NO_UP := preload("res://assets/toons/gui/CloseBtn_UP.png")
const _NO_DOWN := preload("res://assets/toons/gui/CloseBtn_DN.png")
const _NO_HOVER := preload("res://assets/toons/gui/CloseBtn_Rllvr.png")
const _CREAM := Color(1, 1, 0.75, 1)

const _LISTS := {
	"stadium": [0, 1, 60, 61],
	"country": [20, 21, 62, 63],
	"city": [40, 41, 64, 65],
}

static var _drop: Dictionary = {}

var _pads: Array[Dictionary] = []
var _boards: Array[Dictionary] = []
var _board_left := 0.0
var _board_step := 0
var _layer: CanvasLayer
var _prompt_root: Control
var _prompt: Label
var _yes: TextureButton
var _no: TextureButton
var _yes_caption: Label
var _no_caption: Label
var _busy := false
var _near := false
var _cancel := false
var _shown: Node3D
var _hidden: Node3D
var _boarding := false
var _depart := -1.0
var _race_left := 0.0
var _board_pad := -1
var _told_seat := false
var _launched := false
var _field: Dictionary = {}
var _board_time := 0.0
var _board_hit: Dictionary = {}
var _board_kart: Node3D
var _board_anchor: Node3D
var _board_seat: Node3D
var _cam_from := Vector3.ZERO
var _cam_to := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _stand_at := Vector3.ZERO
var _run_from := Vector3.ZERO
var _block_heading := 0.0
var _toss_from := Vector3.ZERO
var _toss_yaw := 0.0
var _toss_to := Vector3.ZERO
var _posed := ""
var _clock_face: TextureRect
var _clock: Label
var _appear: AudioStreamPlayer


static func place(host: Node) -> void:
	if host.get_node_or_null("SpeedwayRacing") != null:
		return
	var here: Node = load("res://scenes/racing/speedway_racing.gd").new()
	here.name = "SpeedwayRacing"
	host.add_child(here)


static func park_return(point: Vector3, heading: float) -> void:
	_drop = {"point": point, "heading": heading}


static func take_drop() -> Dictionary:
	var found := _drop
	_drop = {}
	return found


func _ready() -> void:
	_read_layout()
	_build_prompt()


func _process(delta: float) -> void:
	var shared := _pull_pads()
	_sync_field()
	for pad in _pads:
		if not shared and int(pad.get("waiting", -1)) < 0:
			pad["left"] = float(pad.get("left", _RULES.SIGN_TIME)) - delta
			if float(pad["left"]) <= 0.0:
				pad["left"] = _RULES.SIGN_TIME
				var picked: Dictionary = _RULES.next_track(int(pad.get("track", -1)), String(pad.get("genre", "")), int(pad.get("index", 0)))
				pad["track"] = int(picked.get("track", 0))
				pad["type"] = int(picked.get("type", 0))
		var sign := pad.get("sign") as Label3D
		if sign != null:
			sign.text = "%s\n%s" % [_RULES.track_name(int(pad.get("track", 0))), _RULES.RACE_NAMES[int(pad.get("type", 0))]]
	_board_left -= delta
	if _board_left <= 0.0:
		_board_left = 10.0
		_board_step += 1
		_paint_boards()
	if _boarding:
		_tick_boarding(delta)
		return
	if _busy:
		return
	var body := _body()
	if body == null:
		return
	var hit := _closest(body.global_position)
	if hit.is_empty():
		_near = false
		return
	if _near:
		return
	_near = true
	_offer(hit)


func _offer(hit: Dictionary) -> void:
	_busy = true
	_hold(true)
	_clear_buttons()
	var viewing := bool(hit.get("viewing", false))
	var text := "Would you like to park your car here?"
	if not viewing:
		var race_type := int(hit.get("type", 0))
		if race_type == _RULES.PRACTICE:
			text = "Would you like to enter a practice race?"
		else:
			text = "Would you like to enter a %s race for %s tickets?" % [
				_RULES.RACE_NAMES[race_type], _RULES.entry_fee(int(hit.get("track", 0)), race_type),
			]
	_prompt.text = text
	_yes_caption.text = "Yes"
	_no_caption.text = "No"
	_set_yes(true)
	_layer.visible = true
	_yes.pressed.connect(_accept.bind(hit), CONNECT_ONE_SHOT)
	_no.pressed.connect(_decline, CONNECT_ONE_SHOT)


func _accept(hit: Dictionary) -> void:
	_layer.visible = false
	if bool(hit.get("viewing", false)):
		_park(hit)
		return
	if not _GARAGE.has_kart():
		_say("You need a kart first! Try asking one of the clerks in the Kart Shop.")
		return
	var fee := _RULES.entry_fee(int(hit.get("track", 0)), int(hit.get("type", 0)))
	if _GARAGE.tickets() < fee:
		_say("You don't have enough tickets! Try a practice race instead.")
		return
	var pad: Dictionary = hit.get("pad", {})
	pad["waiting"] = 1
	_wait_out(hit)


func _decline() -> void:
	_release_pad()
	_layer.visible = false
	_hold(false)
	_busy = false


func _release_pad() -> void:
	for pad in _pads:
		pad["waiting"] = -1


func _clear_buttons() -> void:
	for link in _yes.pressed.get_connections():
		_yes.pressed.disconnect(link["callable"])
	for link in _no.pressed.get_connections():
		_no.pressed.disconnect(link["callable"])


func _say(text: String) -> void:
	_clear_buttons()
	_prompt.text = text
	_set_yes(false)
	_layer.visible = true
	_no_caption.text = "OK"
	_layout_prompt()
	_no.pressed.connect(func() -> void:
		_no_caption.text = "No"
		_set_yes(true)
		_decline()
	, CONNECT_ONE_SHOT)


func _wait_out(hit: Dictionary) -> void:
	_board_begin(hit)


func holds_camera() -> bool:
	return _boarding


func aim(camera: Camera3D) -> void:
	if camera == null or not _boarding:
		return
	var weight := clampf(_board_time / 1.5, 0.0, 1.0)
	camera.global_position = _cam_from.lerp(_cam_to, weight)
	if camera.global_position.distance_squared_to(_cam_look) > 0.04:
		camera.look_at(_cam_look, Vector3.UP)


func _board_begin(hit: Dictionary) -> void:
	_boarding = true
	_depart = -1.0
	_posed = ""
	_told_seat = false
	_launched = false
	_board_time = 0.0
	_board_pad = int(hit.get("pad_index", -1))
	_race_left = _RULES.COUNTDOWN
	var waiting := _RACES.wait_left(_board_pad)
	if waiting >= 0.0:
		_race_left = waiting
	_board_hit = hit
	var style := ToonRoster.selected_style()
	var dressed: Dictionary = {}
	var toon_name := "Toon"
	if style != null:
		dressed = style.to_dict()
		toon_name = style.display_name()
	ToonNet.race_act("join", {
		"pad": _board_pad,
		"block": int(hit.get("block_index", -1)),
		"av": ToonRoster.avatar_id(),
		"name": toon_name,
		"dna": _GARAGE.dna().duplicate(),
		"style": dressed,
	})
	_cancel = false
	var panda_heading := float(hit.get("heading", 0.0))
	_block_heading = -panda_heading
	var at: Vector3 = hit.get("pos", Vector3.ZERO)
	var host := get_parent()
	_board_anchor = Node3D.new()
	_board_anchor.position = at
	_board_anchor.rotation.y = deg_to_rad(_block_heading)
	host.add_child(_board_anchor)
	var body := _body()
	var origin := body.global_position if body != null else at
	var ahead := _board_anchor.to_global(Vector3(0.0, 0.0, -6.5))
	var behind := _board_anchor.to_global(Vector3(0.0, 0.0, 6.5))
	ahead.y = origin.y
	behind.y = origin.y
	_stand_at = ahead if origin.distance_squared_to(ahead) <= origin.distance_squared_to(behind) else behind
	_run_from = origin
	_toss_to = at
	_cam_to = _board_anchor.to_global(Vector3(0.0, 10.0, 23.0))
	_cam_look = _board_anchor.to_global(Vector3(0.0, 1.2, 0.0))
	var view_cam := get_viewport().get_camera_3d()
	_cam_from = view_cam.global_position if view_cam != null else _cam_to
	_board_kart = _MODEL.build()
	_board_kart.scale = Vector3.ONE * 0.1
	_board_kart.visible = false
	host.add_child(_board_kart)
	_board_seat = Node3D.new()
	_board_seat.name = "Seat"
	_board_seat.position = Vector3(0.0, 0.1555, -0.1238)
	_board_kart.add_child(_board_seat)
	var toon := _toon()
	if toon != null:
		toon.ensure_clip("feedPet")
		toon.release_pose()
		toon.clear_gesture()
	_clear_buttons()
	_no.pressed.connect(_board_exit, CONNECT_ONE_SHOT)
	_show_clock(true)
	_paint_clock()


func _tick_boarding(delta: float) -> void:
	if _launched:
		return
	var race := _RACES.mine()
	if not race.is_empty() and String(race.get("phase", "")) == "run":
		_launched = true
		_launch_board()
		return
	if _depart >= 0.0:
		_use_pose("sit", delta)
		_sit_toon()
		if not _RACES.live():
			_depart -= delta
			if _depart <= 0.0:
				_launched = true
				_launch_board()
		return
	_board_time += delta
	if _RACES.live():
		var remote := _RACES.wait_left(_board_pad)
		if remote >= 0.0:
			_race_left = remote
		var note := _RACES.notice(_board_pad)
		if note == "racers" and not _RACES.on_pad(_board_pad) and race.is_empty():
			_board_stop()
			_say("Toon Battle and Grand Prix races require two or more racers.")
			return
		if not race.is_empty() and String(race.get("phase", "")) == "enter" and _board_time >= 7.13:
			_show_going()
			return
		if _board_time > 2.0 and not _RACES.on_pad(_board_pad) and race.is_empty():
			_board_stop()
			if _RACES.pad_closed(_board_pad):
				_say("That race is already leaving.")
			else:
				_say("That starting block is already taken.")
			return
	else:
		_race_left = maxf(_race_left - delta, 0.0)
	_paint_clock()
	_step_movie(delta)
	if _RACES.live():
		if _posed == "sit" and not _told_seat:
			_told_seat = true
			ToonNet.race_act("seated", {})
	elif _race_left <= 0.0:
		_begin_depart()


func _show_going() -> void:
	if _depart >= 0.0:
		return
	_depart = 0.0
	_use_pose("sit", 0.0)
	_sit_toon()
	_prompt.text = "Going to the Race!"
	_show_clock(false)
	_no_caption.text = "Exit"
	_clear_buttons()
	_no.pressed.connect(_board_exit, CONNECT_ONE_SHOT)


func _step_movie(delta: float) -> void:
	var t := _board_time
	var body := _body()
	if t < 0.5:
		_use_pose("", delta)
		return
	if t < 1.5:
		var walk := clampf((t - 0.5) / 1.0, 0.0, 1.0)
		var place := _run_from.lerp(_stand_at, walk)
		var face := _heading_of(_run_from, _stand_at)
		_move_toon(place, face)
		_use_pose("run", delta)
		return
	if t < 3.6:
		_move_toon(_stand_at, _block_heading)
		if _posed != "feedPet":
			_put_in_hand()
			_play_appear()
		_use_pose("feedPet", delta)
		return
	if t < 4.25:
		_use_pose("feedPet", delta)
	elif t < 5.8:
		_use_pose("", delta)
	elif t < 6.8:
		_use_pose("jump", delta)
	elif t < 7.13:
		_use_pose("sit-start", delta)
	else:
		_use_pose("sit", delta)
	if t < 4.8:
		if _board_kart != null and _board_kart.get_parent() != get_parent():
			_toss_from = _board_kart.global_position
			_toss_yaw = _board_kart.global_rotation.y
			var kept := _board_kart.global_transform
			get_parent().add_child(_board_kart)
			_board_kart.global_transform = kept
		var flight := clampf((t - 3.6) / 1.2, 0.0, 1.0)
		_fly_kart(flight)
		return
	if t < 5.0:
		_settle_kart(0.0)
		return
	if t < 5.8:
		_settle_kart(clampf((t - 5.0) / 0.8, 0.0, 1.0))
		return
	_settle_kart(1.0)
	var hop := t - 5.8
	if hop < 0.43:
		_move_toon(_stand_at, _block_heading)
		return
	var rise := clampf((hop - 0.43) / 0.9, 0.0, 1.0)
	var seat := _board_seat.global_position if _board_seat != null else _toss_to
	var spot := _stand_at.lerp(seat, rise)
	spot.y += sin(rise * PI) * 2.2
	_move_toon(spot, _block_heading)


func _put_in_hand() -> void:
	var toon := _toon()
	if toon == null or _board_kart == null:
		return
	var hand := toon.find_child("def_joint_right_hold", true, false) as Node3D
	if hand == null:
		return
	hand.add_child(_board_kart)
	_board_kart.position = Vector3.ZERO
	_board_kart.rotation = Vector3.ZERO
	_board_kart.scale = Vector3.ONE * 0.1
	_board_kart.visible = true


func _fly_kart(weight: float) -> void:
	if _board_kart == null:
		return
	var flight := 1.2
	var gravity := -32.0 * 0.45
	var tau := weight * flight
	var vel_y := (_toss_to.y - _toss_from.y) / flight - 0.5 * gravity * flight
	var spot := _toss_from.lerp(_toss_to, weight)
	spot.y = _toss_from.y + vel_y * tau + 0.5 * gravity * tau * tau
	_board_kart.global_position = spot
	_board_kart.scale = Vector3.ONE * 0.1
	_board_kart.global_rotation.y = lerp_angle(_toss_yaw, deg_to_rad(_block_heading), weight)


func _settle_kart(weight: float) -> void:
	if _board_kart == null:
		return
	_board_kart.global_position = _toss_to
	_board_kart.global_rotation.y = deg_to_rad(_block_heading)
	_board_kart.scale = _pop_scale(weight)


func _pop_scale(weight: float) -> Vector3:
	# generateKartAppearTrack springs the kart from a flat card up to full size.
	var marks: PackedFloat32Array = PackedFloat32Array([0.0, 0.2, 0.3, 0.4, 0.6, 0.7, 0.8])
	var wide: PackedFloat32Array = PackedFloat32Array([0.1, 1.1, 0.9, 1.0, 1.0, 1.0, 1.0])
	var tall: PackedFloat32Array = PackedFloat32Array([0.1, 0.1, 0.1, 0.1, 1.1, 0.9, 1.0])
	var along := clampf(weight, 0.0, 1.0) * 0.8
	var index := 0
	while index < marks.size() - 2 and along > marks[index + 1]:
		index += 1
	var span := marks[index + 1] - marks[index]
	var blend := 0.0 if span <= 0.0 else clampf((along - marks[index]) / span, 0.0, 1.0)
	var width := lerpf(wide[index], wide[index + 1], blend) * 1.6
	var height := lerpf(tall[index], tall[index + 1], blend) * 1.6
	return Vector3(width, height, width)


func _use_pose(name: String, delta: float) -> void:
	var toon := _toon()
	if toon == null:
		return
	if name == "run":
		if _posed != "run":
			_posed = "run"
			toon.release_pose()
			toon.clear_gesture()
		toon.play_run(delta)
		return
	if name == "sit":
		if _posed != "sit":
			_posed = "sit"
			toon.release_pose()
			toon.clear_gesture()
		toon.pose_synced_loop("sit")
		return
	if _posed == name:
		return
	_posed = name
	toon.release_pose()
	toon.clear_gesture()
	if name == "":
		return
	toon.play_gesture(name, 1.0, name == "jump")


func _move_toon(at: Vector3, heading: float) -> void:
	var body := _body()
	if body != null:
		body.global_position = at
		body.velocity = Vector3.ZERO
	var toon := _toon()
	if toon != null:
		_face_toon(toon, heading)


func _sit_toon() -> void:
	if _board_seat == null:
		return
	_move_toon(_board_seat.global_position, _block_heading)


func _face_toon(actor: Node3D, heading: float) -> void:
	var body_scale := actor.transform.basis.get_scale().x
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	upright = upright.rotated(Vector3.UP, deg_to_rad(heading))
	actor.transform.basis = upright.scaled(Vector3.ONE * body_scale)


func _heading_of(from: Vector3, to: Vector3) -> float:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	if flat.length_squared() < 0.0001:
		return _block_heading
	return rad_to_deg(atan2(-flat.x, -flat.z))


func _begin_depart() -> void:
	if int(_board_hit.get("type", 0)) != _RULES.PRACTICE:
		_board_stop()
		_say("Toon Battle and Grand Prix races require two or more racers.")
		return
	_depart = _RULES.ENTER_RACE
	_prompt.text = "Going to the Race!"
	_show_clock(false)
	_no_caption.text = "Exit"
	_clear_buttons()
	_no.pressed.connect(_board_exit, CONNECT_ONE_SHOT)


func _launch_board() -> void:
	var hit := _board_hit
	var spot: Vector3 = hit.get("pos", Vector3.ZERO)
	var heading := float(hit.get("heading", 0.0))
	var back := Vector3(sin(deg_to_rad(heading)), 0.0, cos(deg_to_rad(heading))) * 4.0
	var race := _RACES.mine()
	var track := int(hit.get("track", 0))
	var kind := int(hit.get("type", 0))
	var laps := _RULES.LAPS
	if not race.is_empty():
		track = int(race.get("track", track))
		kind = int(race.get("type", kind))
		laps = int(race.get("laps", laps))
	_RACE.launch(track, kind, laps, spot + back, heading)


func _board_exit() -> void:
	_board_stop()
	_decline()


func _board_stop() -> void:
	if _boarding:
		ToonNet.race_act("exit", {})
		ToonNet.race_act("leave", {})
	_boarding = false
	_depart = -1.0
	_posed = ""
	_told_seat = false
	_launched = false
	var toon := _toon()
	if toon != null:
		toon.release_pose()
		toon.clear_gesture()
	if _board_kart != null and is_instance_valid(_board_kart):
		_board_kart.queue_free()
	_board_kart = null
	_board_seat = null
	if _board_anchor != null and is_instance_valid(_board_anchor):
		_board_anchor.queue_free()
	_board_anchor = null
	if _appear != null:
		_appear.stop()
	_show_clock(false)
	_layer.visible = false


func _show_clock(clock: bool) -> void:
	_layer.visible = true
	var dim := _prompt_root.get_child(0) as CanvasItem
	var frame := _prompt_root.get_child(1) as CanvasItem
	dim.visible = not clock
	frame.visible = not clock
	_prompt.visible = not clock
	_clock_face.visible = clock
	_clock.visible = clock
	_set_yes(false)
	_no.visible = true
	_no_caption.visible = true
	if clock:
		_no_caption.text = "Exit"
		_prompt_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		_prompt_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layout_prompt()


func _paint_clock() -> void:
	if _clock == null:
		return
	_clock.text = str(int(ceil(_race_left)))


func _play_appear() -> void:
	var stream := load(_APPEAR) as AudioStream
	if stream == null:
		return
	if _appear == null:
		_appear = AudioStreamPlayer.new()
		add_child(_appear)
	_appear.stream = stream
	_appear.play()


func _toon() -> ToonActor:
	var body := _body()
	if body == null:
		return null
	for child in body.get_children():
		if child is ToonActor:
			return child as ToonActor
	return null


func _pull_pads() -> bool:
	var rows := _RACES.pads()
	if rows.is_empty():
		return false
	var count := mini(_pads.size(), rows.size())
	for index in count:
		var pad: Dictionary = _pads[index]
		if bool(pad.get("viewing", false)) or not (rows[index] is Dictionary):
			continue
		var row: Dictionary = rows[index]
		pad["track"] = int(row.get("track", pad.get("track", 0)))
		pad["type"] = int(row.get("type", pad.get("type", 0)))
		pad["left"] = float(row.get("left", pad.get("left", _RULES.SIGN_TIME)))
		var peers: Variant = row.get("peers", [])
		pad["waiting"] = 0 if peers is Array and not (peers as Array).is_empty() else -1
	return true


func _sync_field() -> void:
	var rows := _RACES.pads()
	var want: Dictionary = {}
	for pad_index in rows.size():
		if pad_index >= _pads.size() or not (rows[pad_index] is Dictionary):
			continue
		var row: Dictionary = rows[pad_index]
		var peers: Variant = row.get("peers", [])
		var blocks: Variant = row.get("blocks", [])
		var names: Variant = row.get("names", [])
		var dna: Variant = row.get("dna", [])
		var styles: Variant = row.get("styles", [])
		if not (peers is Array) or not (blocks is Array):
			continue
		var pad: Dictionary = _pads[pad_index]
		var local_blocks: Array = pad.get("blocks", [])
		for seat in (peers as Array).size():
			var peer := int((peers as Array)[seat])
			if peer == ToonNet.peer_id():
				continue
			if seat >= (blocks as Array).size():
				continue
			var block_index := int((blocks as Array)[seat])
			if block_index < 0 or block_index >= local_blocks.size() or not (local_blocks[block_index] is Dictionary):
				continue
			want[peer] = true
			if not _field.has(peer):
				var toon_name := "Toon"
				if names is Array and seat < (names as Array).size():
					toon_name = String((names as Array)[seat])
				var kart_dna: Array = []
				if dna is Array and seat < (dna as Array).size() and (dna as Array)[seat] is Array:
					kart_dna = (dna as Array)[seat]
				var dressed: Dictionary = {}
				if styles is Array and seat < (styles as Array).size() and (styles as Array)[seat] is Dictionary:
					dressed = (styles as Array)[seat]
				_field[peer] = _make_waiter(local_blocks[block_index], toon_name, kart_dna, dressed)
	var gone: Array = []
	for key in _field.keys():
		if not want.has(key):
			gone.append(key)
	for key in gone:
		var node := _field[key] as Node
		if node != null and is_instance_valid(node):
			node.queue_free()
		_field.erase(key)
	for key in _field.keys():
		var show := _field[key] as Node3D
		if show == null:
			continue
		var driver := show.get_node_or_null("Seat/Driver") as ToonActor
		if driver != null:
			driver.pose_synced_loop("sit")


func _make_waiter(block: Dictionary, toon_name: String, dna: Array, dressed: Dictionary) -> Node3D:
	var kart := _MODEL.build(dna)
	var at: Vector3 = block.get("pos", Vector3.ZERO)
	kart.position = at + Vector3.UP * 0.2
	kart.rotation.y = deg_to_rad(-float(block.get("heading", 0.0)))
	kart.scale = Vector3.ONE * 1.6
	add_child(kart)
	var seat := Node3D.new()
	seat.name = "Seat"
	seat.position = Vector3(0.0, 0.1555, -0.1238)
	seat.scale = Vector3.ONE * (1.0 / 1.6)
	kart.add_child(seat)
	if not dressed.is_empty():
		var actor := ToonActor.new()
		actor.name = "Driver"
		actor.footsteps = false
		seat.add_child(actor)
		actor.show_style(ToonStyle.from_dict(dressed))
		var body_scale := actor.transform.basis.get_scale().x
		var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
		actor.transform.basis = upright.scaled(Vector3.ONE * body_scale)
		actor.pose_synced_loop("sit")
	var label := Label3D.new()
	label.text = toon_name
	label.font = _GUI.sign_font()
	label.font_size = 42
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.1, 0.35, 0.85)
	label.outline_modulate = Color.WHITE
	label.position = Vector3(0.0, 3.2, 0.0)
	kart.add_child(label)
	return kart


func _park(hit: Dictionary) -> void:
	if not _GARAGE.has_kart():
		_say("You need a kart first! Try asking one of the clerks in the Kart Shop.")
		return
	_clear_buttons()
	_clear_show()
	_shown = _MODEL.build()
	add_child(_shown)
	var at: Vector3 = hit.get("pos", Vector3.ZERO)
	_shown.global_position = at + Vector3.UP * 0.2
	_shown.rotation.y = deg_to_rad(-float(hit.get("heading", 0.0)))
	var body := _body()
	if body != null:
		for child in body.get_children():
			if child is ToonActor:
				_hidden = child
				_hidden.visible = false
	_prompt.text = "Parked."
	_set_yes(false)
	_no_caption.text = "Exit"
	_layer.visible = true
	_layout_prompt()
	_no.pressed.connect(func() -> void:
		_clear_show()
		_no_caption.text = "No"
		_set_yes(true)
		_decline()
	, CONNECT_ONE_SHOT)


func _clear_show() -> void:
	if _shown != null and is_instance_valid(_shown):
		_shown.queue_free()
	_shown = null
	if _hidden != null and is_instance_valid(_hidden):
		_hidden.visible = true
	_hidden = null


func _read_layout() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_LAYOUT))
	if not (parsed is Array):
		return
	var current: Dictionary = {}
	for item in parsed as Array:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		var name := String(row.get("name", ""))
		var pos_row: Array = row.get("pos", [0, 0, 0])
		var pos := Vector3(float(pos_row[0]), float(pos_row[1]), float(pos_row[2]))
		var heading := float(row.get("heading", 0.0))
		if name.begins_with("racing_pad") or name.begins_with("viewing_pad"):
			var parts := name.split("_")
			var index := int(parts[2]) if parts.size() > 2 and name.begins_with("racing") else 0
			var genre_name := parts[3] if parts.size() > 3 else ""
			var picked: Dictionary = _RULES.next_track(-1, genre_name, index)
			current = {
				"name": name,
				"index": index,
				"genre": genre_name,
				"viewing": name.begins_with("viewing"),
				"track": int(picked.get("track", 0)),
				"type": int(picked.get("type", 0)),
				"left": _RULES.SIGN_TIME,
				"blocks": [],
			}
			_pads.append(current)
			if not bool(current["viewing"]):
				var sign := Label3D.new()
				sign.font = _GUI.sign_font()
				sign.font_size = 48
				sign.pixel_size = 0.025
				sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				sign.modulate = Color(0.05, 0.2, 0.55)
				sign.outline_modulate = Color.WHITE
				sign.text = _RULES.track_name(int(current["track"]))
				add_child(sign)
				current["sign"] = sign
		elif name.begins_with("starting_block") and not current.is_empty():
			var blocks: Array = current.get("blocks", [])
			blocks.append({
				"pos": pos,
				"heading": heading,
				"viewing": bool(current.get("viewing", false)),
				"track": current.get("track", 0),
				"type": current.get("type", 0),
				"pad": current,
				"pad_index": _pads.size() - 1,
				"block_index": blocks.size(),
			})
			current["blocks"] = blocks
			var sign := current.get("sign") as Label3D
			if sign != null and blocks.size() == 1:
				sign.global_position = pos + Vector3.UP * 7.0
		elif name == "leaderBoard_stadium" or name == "leaderBoard_city" or name == "leaderBoard_country":
			var kind := "stadium"
			if name.ends_with("city"):
				kind = "city"
			elif name.ends_with("country"):
				kind = "country"
			var label := Label3D.new()
			label.font = _GUI.sign_font()
			label.font_size = 32
			label.pixel_size = 0.012
			label.modulate = Color(0.15, 0.45, 0.4)
			label.outline_size = 8
			label.outline_modulate = Color.WHITE
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			label.global_position = pos + Vector3.UP * 4.5
			label.rotation.y = deg_to_rad(-heading)
			add_child(label)
			_boards.append({"label": label, "kind": kind})
	_paint_boards()


func _paint_boards() -> void:
	for board in _boards:
		var label := board.get("label") as Label3D
		var tracks: Array = _LISTS.get(String(board.get("kind", "stadium")), [])
		if label == null or tracks.is_empty():
			continue
		var slot := posmod(_board_step, tracks.size() * 3)
		var track_id := int(tracks[slot / 3])
		var period := slot % 3
		var lines := "%s\n%s" % [_RULES.track_name(track_id), _RULES.PERIOD_NAMES[period]]
		var place := 1
		for row in _GARAGE.board(track_id, period):
			if row is Array and (row as Array).size() >= 4:
				var record: Array = row
				lines += "\n%d. %s  %s" % [place, String(record[3]), _RULES.clock(float(record[0]))]
				place += 1
		label.text = lines


func _closest(at: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_d := 2.4
	for pad in _pads:
		var blocks: Array = pad.get("blocks", [])
		for block in blocks:
			if not (block is Dictionary):
				continue
			var row: Dictionary = block
			var pos: Vector3 = row.get("pos", Vector3.ZERO)
			var flat := Vector2(at.x, at.z).distance_to(Vector2(pos.x, pos.z))
			if flat < best_d and absf(at.y - pos.y) < 4.0:
				best_d = flat
				best = row.duplicate()
				best["track"] = pad.get("track", 0)
				best["type"] = pad.get("type", 0)
				best["viewing"] = pad.get("viewing", false)
	return best


func _body() -> Node3D:
	var host := get_parent()
	if host == null:
		return null
	return host.get_node_or_null("Player") as Node3D


func _hold(holding: bool) -> void:
	var host := get_parent()
	if host == null:
		return
	var toon := host.get_node_or_null("PlaygroundToon")
	if toon != null and toon.has_method("hold_for_race"):
		toon.call("hold_for_race", holding)


func _build_prompt() -> void:
	# TTGlobalDialog, style YesNo. The cream card is dialog_box_gui, and the
	# choices are the check and the X from dialog_box_buttons_gui.
	_layer = CanvasLayer.new()
	_layer.layer = 30
	_layer.visible = false
	add_child(_layer)
	_prompt_root = Control.new()
	_prompt_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_prompt_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_prompt_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prompt_root.add_child(dim)
	var frame := TextureRect.new()
	frame.texture = _DIALOG
	frame.modulate = _CREAM
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_root.add_child(frame)
	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_root.add_child(_prompt)
	_yes = _choice(_YES_UP, _YES_DOWN, _YES_HOVER)
	_yes_caption = _choice_caption("Yes")
	_no = _choice(_NO_UP, _NO_DOWN, _NO_HOVER)
	_no_caption = _choice_caption("No")
	# ToontownTimer on a starting block: alarm clock at (1.16, 0, -0.73), scale 0.3.
	_clock_face = TextureRect.new()
	_clock_face.texture = _CLOCK
	_clock_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_clock_face.stretch_mode = TextureRect.STRETCH_SCALE
	_clock_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_face.visible = false
	_prompt_root.add_child(_clock_face)
	_clock = Label.new()
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock.visible = false
	_prompt_root.add_child(_clock)
	var view := get_viewport()
	if view != null and not view.size_changed.is_connected(_layout_prompt):
		view.size_changed.connect(_layout_prompt)
	_layout_prompt()


func _choice(up: Texture2D, down: Texture2D, hover: Texture2D) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = up
	button.texture_pressed = down
	button.texture_hover = hover
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_GUI.button_sounds(button)
	_prompt_root.add_child(button)
	return button


func _choice_caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_root.add_child(label)
	return label


func _set_yes(shown: bool) -> void:
	_yes.visible = shown
	_yes_caption.visible = shown
	_layout_prompt()


func _layout_prompt() -> void:
	if _prompt_root == null:
		return
	var view := get_viewport().get_visible_rect().size
	if view.y < 2.0:
		return
	_prompt_root.position = Vector2.ZERO
	_prompt_root.size = view
	var dim := _prompt_root.get_child(0) as Control
	dim.position = Vector2.ZERO
	dim.size = view
	if _clock_face != null and _clock_face.visible:
		_GUI.place(_clock_face, view, 1.16, -0.73, 0.7417 * 0.3, 0.7292 * 0.3)
		_GUI.place(_clock, view, 1.16, -0.73, 0.22, 0.16)
		var digits := maxi(int(round(0.12 * view.y * 0.5)), 1)
		_GUI.style_label(_clock, Color(0, 0, 0), digits, Color(0, 0, 0, 0), 0)
		_place_choice(_no, _no_caption, view, 1.16)
		_GUI.place(_no, view, 1.16, -0.9, 0.1, 0.1)
		_GUI.place(_no_caption, view, 1.16, -1.02, 0.36, 0.1)
		return
	# dialog_box_gui tight bounds. OTPDialog text is scale 0.07, wrap 12.
	_GUI.place(_prompt_root.get_child(1), view, 0.0, 0.0, 1.1122, 1.1861)
	var px := maxi(int(round(0.07 * view.y * 0.5)), 1)
	_GUI.style_label(_prompt, Color(0, 0, 0), px, Color(0, 0, 0, 0), 0)
	_GUI.place(_prompt, view, 0.0, 0.16, 0.84, 0.5)
	var yes_x := -0.2
	var no_x := 0.2
	if not _yes.visible:
		no_x = 0.0
	_place_choice(_yes, _yes_caption, view, yes_x)
	_place_choice(_no, _no_caption, view, no_x)


func _place_choice(button: TextureButton, caption: Label, view: Vector2, x: float) -> void:
	_GUI.place(button, view, x, -0.32, 0.1, 0.1)
	var px := maxi(int(round(0.05 * view.y * 0.5)), 1)
	_GUI.style_label(caption, Color(0, 0, 0), px, Color(0, 0, 0, 0), 0)
	_GUI.place(caption, view, x, -0.44, 0.36, 0.1)
