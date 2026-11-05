extends Node

## The local toon boards a cog building. fillSlot runs them into a seat and
## turns them toward the doors. The countdown sits on the elevator and Hop off
## uses the inventory button. The doors then close and the ride plays each floor.

const _ELEVATOR := preload("res://assets/buildings/cog/elevator.glb")
const _LOBBY := preload("res://assets/buildings/cog/suit_interior.glb")
const _HALL := preload("res://assets/buildings/cog/cubicle_room.glb")
const _OFFICE := preload("res://assets/buildings/cog/boss_suit_office.glb")
const _RUNS := preload("res://scenes/buildings/building_runs.gd")
const _ELEVATOR_MUSIC := "res://assets/buildings/cog/audio/tt_elevator.ogg"
## DistributedBattleBldg.setBossBattle. A normal floor and the top floor
## each have their own indoor battle theme.
const _FLOOR_MUSIC := "res://assets/buildings/cog/audio/encntr_general_bg_indoor.ogg"
const _BOSS_MUSIC := "res://assets/buildings/cog/audio/encntr_suit_winning_indoor.ogg"
## DistributedSuitInterior enterResting, after a floor that is not the top.
const _WAIT_MUSIC := "res://assets/buildings/cog/audio/encntr_toon_winning_indoor.ogg"
const _ELEVATOR_VOL := 0.8
const _BATTLE_VOL := 0.9
const _WAIT_VOL := 0.7
const _OPEN_SFX := "res://assets/buildings/cog/audio/elevator_door_open.ogg"
const _CLOSE_SFX := "res://assets/buildings/cog/audio/elevator_door_close.ogg"
const _HOP_UP := preload("res://assets/gui/rules/InventoryButtonUp.png")
const _HOP_DN := preload("res://assets/gui/rules/InventoryButtonDown.png")
const _HOP_OVER := preload("res://assets/gui/rules/InventoryButtonRollover.png")
## ElevatorData collRadius. The sphere is centered inside the car.
const REACH := 5.0
## fillSlot runs for 75 percent of TOON_BOARD_ELEVATOR_TIME, then turns.
const _BOARD_RUN := 0.75
const _BOARD_TURN := 0.25
const _BOARD_CAM := 1.5
const _EXIT_RUN := 1.0
## Elevator.enableExitButton. image_scale (20, 1, 11) on a 0.15 node.
const _HOP_W := 0.1804 * 20.0 * 0.15
const _HOP_H := 0.1137 * 11.0 * 0.15
## Interior car keeps the glTF root spin, so panda (x, y, z) is (x, z, -y).
const _SEATS: Array[Vector3] = [
	Vector3(-1.5, 0.1, -5.0), Vector3(1.5, 0.1, -5.0),
	Vector3(-2.5, 0.1, -3.0), Vector3(2.5, 0.1, -3.0),
]
## Street elevator local space is still the panda elevator: X across, Y in, Z up.
const _STAND: Array[Vector3] = [
	Vector3(-1.5, 5.0, 0.1), Vector3(1.5, 5.0, 0.1),
	Vector3(-2.5, 3.0, 0.1), Vector3(2.5, 3.0, 0.1),
]
const _OFF: Array[Vector3] = [
	Vector3(-1.5, -5.0, 0.1), Vector3(1.5, -5.0, 0.1),
	Vector3(-2.5, -7.0, 0.1), Vector3(2.5, -7.0, 0.1),
]

var _room: Node3D
var _car: Node3D
var _out: Node3D
var _suits: Node3D
var _layer: CanvasLayer
var _banner: Label
var _music: AudioStreamPlayer
var _tune := ""
var _cue := ""
var _ask := 0.0
var _inside := false
var _return := Vector3.ZERO
var _hidden: Dictionary = {}
var _hop: TextureButton
var _clock: Label3D
var _cam_from := Vector3.ZERO
var _look_from := Vector3.ZERO
var _cam_blend := -1.0
var _avoid := 0
var _declined := 0
var _exiting := false
var _exit_age := 0.0
var _exit_from := Vector3.ZERO
var _exit_to := Vector3.ZERO
var _exit_heading := 0.0
var _riders: Dictionary = {}
var _remote_exits: Dictionary = {}
var _timing: Dictionary = {}
## Street boarding uses the panda elevator points. The far car uses the interior seats.
var _spots: Array = _STAND
var _floor_out := false
var _board_key := ""
var _ride_token := ""
var _ride_freed: Dictionary = {}


func _ready() -> void:
	_suits = Node3D.new()
	_suits.name = "FloorSuits"
	add_child(_suits)
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 28)
	_banner.add_theme_color_override("font_color", Color(1, 1, 1))
	_banner.visible = false
	_layer.add_child(_banner)
	_build_hop()
	_build_clock()
	set_process(true)


func _process(delta: float) -> void:
	_ask = maxf(_ask - delta, 0.0)
	_place_banner()
	_place_hop()
	_tick_remote_exits(delta)
	if _exiting:
		var raw := _raw_mine()
		if not raw.is_empty():
			var elevator := _street_elevator(int(raw.get("block", 0)))
			var open := String(raw.get("state", "")) == "boarding" and not bool(raw.get("depart", false))
			if elevator != null and open:
				_step_party(raw, elevator, delta)
		_step_exit(delta)
		_mask_remotes({})
		return
	var run := _mine()
	if run.is_empty():
		_leave()
		_release_riders()
		_offer(delta)
		_mask_remotes({})
		return
	_enter(run)
	_show(run, delta)
	_sync_cogs(run)
	_mask_remotes(run)


func _mine() -> Dictionary:
	var run := _raw_mine()
	if _declined != 0 and int(run.get("id", -1)) == _declined:
		return {}
	return run


func _raw_mine() -> Dictionary:
	var peer := ToonNet.peer_id()
	for item in _rows():
		if not (item is Dictionary):
			continue
		var run: Dictionary = item
		for rider in run.get("toons", []):
			if rider is Dictionary and int((rider as Dictionary).get("id", 0)) == peer:
				return run
	return {}


func _rows() -> Array:
	var snap := ToonNet.latest("runs:%d:%s" % [_district(), _slug()])
	var rows: Variant = snap.get("rows", [])
	if rows is Array:
		return rows
	return []


func _offer(_delta: float) -> void:
	if _ask > 0.0:
		return
	var toon := _toon()
	if toon == null or bool(toon.call("battle_busy")):
		_banner.visible = false
		return
	var buildings := _buildings()
	if buildings == null:
		return
	var here: Vector3 = toon.call("battle_point")
	if _avoid != 0:
		var left := _street_elevator(_avoid)
		if left == null or _away_from(left, here):
			_avoid = 0
			_declined = 0
	var best := 0
	var best_dist := REACH
	for item in _building_rows():
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		if String(row.get("state", "")) == "clearing":
			continue
		var block := int(row.get("block", 0))
		if block == _avoid:
			continue
		var elevator := _street_elevator(block)
		if elevator == null:
			continue
		var dist := _car_gap(elevator, here)
		if dist > REACH:
			continue
		if dist < best_dist:
			best = block
			best_dist = dist
	if best == 0:
		return
	_ask = 1.2
	_return = buildings.call("elevator_spot", best)
	var hp: Vector2i = toon.call("battle_hp")
	ToonNet.ask_board(_district(), _slug(), best, str(toon.call("battle_name")), hp.x, hp.y)


func _enter(run: Dictionary) -> void:
	if _inside:
		return
	_inside = true
	var toon := _toon()
	if toon != null:
		toon.call("hold_for_battle", true)
	_ensure_room(run)


func _leave() -> void:
	if not _inside:
		_banner.visible = false
		return
	_inside = false
	_banner.visible = false
	_hide_board_gui()
	_release_riders()
	_cam_blend = -1.0
	_quiet()
	_release_street()
	_clear_cogs()
	if _room != null:
		_room.queue_free()
		_room = null
		_car = null
	var toon := _toon()
	if toon == null:
		return
	var back := _return
	back.y += 0.2
	toon.call("visit_friend", back, 0.0)
	toon.call("hold_for_battle", false)


func _show(run: Dictionary, delta: float) -> void:
	_ensure_room(run)
	var state := String(run.get("state", ""))
	var block := int(run.get("block", 0))
	var buildings := _buildings()
	var fight := _fight_of(run)
	var fight_state := String(fight.get("state", ""))
	var closed := 0.0
	if state == "closing":
		closed = 1.0 - clampf(float(run.get("left", 0.0)) / 2.0, 0.0, 1.0)
		_once("close", _CLOSE_SFX)
	elif state == "riding":
		var elapsed := 6.0 - float(run.get("left", 0.0))
		closed = 1.0 if elapsed < 4.0 else 1.0 - clampf((elapsed - 4.0) / 2.0, 0.0, 1.0)
		if elapsed >= 4.0:
			_once("open", _OPEN_SFX)
	var out_closed := 1.0
	if state == "resting" or state == "floorboard":
		out_closed = 0.0
	elif fight_state == "reserves":
		var elapsed := 3.0 - float(fight.get("left", 0.0))
		out_closed = 1.0 - clampf(elapsed / 2.0, 0.0, 1.0)
		_once("reserves", _OPEN_SFX)
	_slide(_car, closed)
	_slide(_out, out_closed)
	if buildings != null:
		var outside := 0.0
		if state == "closing":
			outside = closed
		elif state != "boarding":
			outside = 1.0
		buildings.call("set_doors", block, outside)
		var story := -1
		if state == "riding" or state == "battle" or state == "victory" or state == "failed" or state == "resting" or state == "floorboard":
			story = int(run.get("floor", 0))
		buildings.call("set_story", block, story)
		var floors := int(run.get("floors", 1))
		if _car != null:
			buildings.call("paint_elevator", _car, floors, story)
		if _out != null:
			buildings.call("paint_elevator", _out, floors, story)
	# The countdown stays on the street, so the street song keeps playing
	# until the ride. From there the building owns the music.
	if state == "riding":
		_hold_street()
		_play_music(_ELEVATOR_MUSIC, _ELEVATOR_VOL)
	elif state == "battle":
		_hold_street()
		if fight_state == "reward" and not _boss_floor(run):
			_play_music(_WAIT_MUSIC, _WAIT_VOL)
		elif _boss_floor(run):
			_play_music(_BOSS_MUSIC, _BATTLE_VOL)
		else:
			_play_music(_FLOOR_MUSIC, _BATTLE_VOL)
	elif state == "resting" or state == "floorboard":
		_hold_street()
		_play_music(_WAIT_MUSIC, _WAIT_VOL)
	elif state == "victory" or state == "failed":
		_hold_street()
		_quiet()
	else:
		_quiet()
	_banner.visible = true
	if state == "boarding" or state == "closing":
		_banner.visible = false
		_present_board(run, delta)
		return
	if state == "resting":
		_banner.visible = false
		_offer_next(run)
		return
	if state == "floorboard":
		_banner.visible = false
		_present_out(run, delta)
		return
	_hide_board_gui()
	_release_riders()
	if state == "riding":
		_banner.visible = false
		_aim_ride(6.0 - float(run.get("left", 0.0)))
		_pose_ride(run, delta)
		return
	elif state == "victory":
		_banner.text = "You took the building back!"
	elif state == "failed":
		_banner.text = "The Cogs kept the building."
	elif fight_state == "reserves":
		_banner.text = "More Cogs are coming!"
	elif state == "battle":
		_banner.visible = false
	else:
		_banner.text = "The elevator is closing"
	if state == "battle":
		return
	var toon := _toon()
	if toon == null or _car == null:
		return
	var seat := _seat(run)
	toon.call("visit_friend", seat, 180.0)


func _ensure_room(run: Dictionary) -> void:
	var block := int(run.get("block", 0))
	var kind := String(run.get("room", "lobby"))
	if kind == "":
		kind = "lobby"
	if _room != null and int(_room.get_meta("block", -1)) == block and String(_room.get_meta("kind", "")) == kind:
		return
	if _room != null:
		_room.queue_free()
		_clear_cogs()
	var packed := _LOBBY
	if kind == "hall":
		packed = _HALL
	elif kind == "office":
		packed = _OFFICE
	_room = packed.instantiate() as Node3D
	if _room == null:
		return
	_room.name = "SuitFloor"
	_room.set_meta("block", block)
	_room.set_meta("kind", kind)
	_room.position = _RUNS.room_origin(block)
	add_child(_room)
	_solid_room(_room)
	var depth := 30.0
	if kind == "hall":
		depth = 40.0
	elif kind == "office":
		depth = 37.5
	_car = _park_car("In", Vector3(0.0, 0.0, depth), 180.0)
	_out = _park_car("Out", Vector3(0.0, 0.0, -depth), 0.0)
	_slide(_car, 1.0)
	_slide(_out, 1.0)


func _park_car(car_name: String, spot: Vector3, yaw: float) -> Node3D:
	var car := _ELEVATOR.instantiate() as Node3D
	if car == null or _room == null:
		return null
	car.name = car_name
	_room.add_child(car)
	car.position = spot
	car.rotation.y = deg_to_rad(yaw)
	preload("res://scenes/streets/street_buildings.gd").frame_solid(car)
	return car


func _sync_cogs(run: Dictionary) -> void:
	var wanted := {}
	for item in run.get("cogs", []):
		if item is Dictionary:
			wanted[int((item as Dictionary).get("id", 0))] = item
	for item in _fight_of(run).get("cogs", []):
		if item is Dictionary and not wanted.has(int((item as Dictionary).get("id", 0))):
			wanted[int((item as Dictionary).get("id", 0))] = item
	var have := {}
	for child in _suits.get_children():
		have[int(child.get_meta("do_id", 0))] = child
	for id in have.keys():
		if not wanted.has(int(id)):
			(have[id] as Node).queue_free()
	for id in wanted.keys():
		if have.has(int(id)):
			continue
		var cog: Dictionary = wanted[id]
		var actor := StreetCog.new()
		actor.name = "FloorCog%d" % int(id)
		_suits.add_child(actor)
		var spot := _vec(cog.get("pos", cog.get("from", [])))
		# setup() is the street drop. A floor has no path, so that call removes
		# the suit. present() leaves it standing where the floor placed it.
		actor.present(cog, _suit_timing())
		actor.set_meta("do_id", int(id))
		actor.hold_fight(true, spot, 0.0)


func _suit_timing() -> Dictionary:
	if not _timing.is_empty():
		return _timing
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cogs/catalog.json"))
	if parsed is Dictionary:
		var timing: Variant = (parsed as Dictionary).get("timing", {})
		if timing is Dictionary:
			_timing = timing
	return _timing


func _clear_cogs() -> void:
	for child in _suits.get_children():
		child.queue_free()


func _seat(run: Dictionary) -> Vector3:
	if _car == null:
		return _RUNS.room_origin(int(run.get("block", 0)))
	return _car.global_transform * _SEATS[_seat_index(run) % _SEATS.size()]


## __playElevator parents each toon to the in car, setHpr(180) facing out the
## doors, and loop('neutral') for the whole ride.
func _pose_ride(run: Dictionary, delta: float) -> void:
	var heading := _ride_heading()
	var toon := _toon()
	if toon == null or _car == null:
		return
	var index := 0
	for item in run.get("toons", []):
		if not (item is Dictionary):
			continue
		var rider: Dictionary = item
		var peer := int(rider.get("id", 0))
		var seat := index
		if rider.has("seat"):
			seat = int(rider.get("seat", index))
		var spot: Vector3 = _car.global_transform * _SEATS[seat % _SEATS.size()]
		var actor: ToonActor = null
		if peer == ToonNet.peer_id():
			toon.call("visit_friend", spot, heading)
			actor = toon.call("battle_actor")
		else:
			toon.call("pin_remote", peer, spot, heading)
			actor = toon.call("remote_actor", peer)
		if actor != null:
			var token := "%s:%s" % [int(run.get("id", 0)), int(run.get("floor", 0))]
			if _ride_token != token:
				_ride_token = token
				_ride_freed.clear()
			if not _ride_freed.has(peer):
				_ride_freed[peer] = true
				actor.clear_gesture()
				actor.end_action("victory")
			actor.set_locomotion(0.0, false, false, delta)
		index += 1


## Panda H 180 faces elevator -Y, out the doors. That direction is this car's +Z.
func _ride_heading() -> float:
	if _car == null:
		return 0.0
	return _heading_of(_car.global_transform.basis * Vector3(0.0, 0.0, 1.0))


func _seat_index(run: Dictionary) -> int:
	var index := 0
	var peer := ToonNet.peer_id()
	for rider in run.get("toons", []):
		if rider is Dictionary and int((rider as Dictionary).get("id", 0)) == peer:
			if (rider as Dictionary).has("seat"):
				return int((rider as Dictionary).get("seat", index))
			return index
		index += 1
	return 0


## fillSlot parents the toon to the street elevator, runs to ElevatorPoints, and
## turns to face out. The camera eases to the boarding shot over 1.5 seconds.
func _present_board(run: Dictionary, delta: float) -> void:
	_spots = _STAND
	var elevator := _street_elevator(int(run.get("block", 0)))
	var open := String(run.get("state", "")) == "boarding" and not bool(run.get("depart", false))
	_paint_clock(elevator, open, float(run.get("left", 0.0)))
	if _hop != null:
		_hop.visible = open
	if elevator == null:
		return
	if _cam_blend < 0.0:
		_remember_cam()
	_cam_blend = minf(_cam_blend + delta / _BOARD_CAM, 1.0)
	_aim_board(elevator)
	_step_party(run, elevator, delta)


## DistributedSuitInterior enterResting. Control is the toon's, and the far
## elevator is the one that goes up.
func _offer_next(run: Dictionary) -> void:
	_hide_board_gui()
	_spots = _STAND
	var toon := _toon()
	if toon != null and not _floor_out:
		toon.call("hold_for_battle", false)
	if _out == null or toon == null or _ask > 0.0:
		return
	var here: Vector3 = toon.call("battle_point")
	if _floor_out:
		if not _inside_out(here):
			_floor_out = false
		return
	if not _inside_out(here):
		return
	_ask = 1.2
	_board_key = ""
	_riders.clear()
	_cam_blend = -1.0
	ToonNet.ask_next(_district(), _slug(), int(run.get("block", 0)))


func _present_out(run: Dictionary, delta: float) -> void:
	if _floor_out or _out == null:
		_hide_board_gui()
		return
	var key := "floor:%s:%s" % [int(run.get("id", 0)), int(run.get("floor", 0))]
	if _board_key != key:
		_board_key = key
		_riders.clear()
		_cam_blend = -1.0
	var toon := _toon()
	if toon != null:
		toon.call("hold_for_battle", true)
	_spots = _SEATS
	var open := not bool(run.get("depart", false))
	_paint_clock(_out, open, float(run.get("left", 0.0)))
	if _hop != null:
		_hop.visible = open
	if _cam_blend < 0.0:
		_remember_cam()
	_cam_blend = minf(_cam_blend + delta / _BOARD_CAM, 1.0)
	_aim_interior(_out)
	_step_party(run, _out, delta)
	_spots = _STAND


## The interior car keeps the glTF spin, so its local -Z is into the car.
func _aim_interior(car: Node3D) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var dest: Vector3 = car.global_transform * Vector3(0.0, 4.0, 8.0)
	var look: Vector3 = car.global_transform * Vector3(0.0, 3.0, -2.0)
	var blend := clampf(_cam_blend, 0.0, 1.0)
	camera.global_position = _cam_from.lerp(dest, blend)
	var focus := _look_from.lerp(look, blend)
	if camera.global_position.distance_squared_to(focus) > 0.04:
		camera.look_at(focus, Vector3.UP)


func _hop_floor(run: Dictionary) -> void:
	_floor_out = true
	_board_key = ""
	_riders.erase(ToonNet.peer_id())
	_cam_blend = -1.0
	_hide_board_gui()
	var toon := _toon()
	if toon != null and _out != null:
		var here: Vector3 = toon.call("battle_point")
		var flat: Vector3 = _room.global_position - _out.global_position if _room != null else Vector3.ZERO
		flat.y = 0.0
		var heading := _out_heading(_out)
		var spot := here
		if flat.length_squared() > 0.04:
			heading = _heading_of(flat)
			spot = _out.global_position + flat.normalized() * 6.0
			spot.y = here.y
		toon.call("visit_friend", spot, heading)
		toon.call("hold_for_battle", false)
	ToonNet.ask_floor_hop(_district(), _slug(), int(run.get("block", 0)))


func _inside_out(here: Vector3) -> bool:
	if _out == null:
		return false
	var spot: Vector3 = _out.global_transform * Vector3(0.0, 1.0, -2.5)
	if absf(here.y - spot.y) > 3.0:
		return false
	return Vector2(here.x - spot.x, here.z - spot.z).length() <= 3.5


func _solid_room(room: Node) -> void:
	if room is MeshInstance3D:
		var mesh := room as MeshInstance3D
		var low := str(mesh.name).to_lower()
		if mesh.mesh != null and not low.contains("shadow") and not low.contains("shad"):
			mesh.create_trimesh_collision()
			var body := mesh.get_node_or_null(str(mesh.name) + "_col") as StaticBody3D
			if body != null:
				body.collision_layer = 1
				body.collision_mask = 0
	for child in room.get_children():
		_solid_room(child)


func _step_party(run: Dictionary, elevator: Node3D, delta: float) -> void:
	var block := int(run.get("block", 0))
	var index := 0
	for item in run.get("toons", []):
		if not (item is Dictionary):
			continue
		var rider: Dictionary = item
		var peer := int(rider.get("id", 0))
		var seat := index
		if rider.has("seat"):
			seat = int(rider.get("seat", index))
		_step_rider(peer, seat, block, elevator, delta)
		index += 1
	_drop_boarded_riders()


func _step_rider(peer: int, seat: int, block: int, elevator: Node3D, delta: float) -> void:
	if peer == ToonNet.peer_id() and (_exiting or _floor_out):
		return
	var spots: Array = _spots if not _spots.is_empty() else _STAND
	var point: Vector3 = spots[seat % spots.size()]
	var goal := elevator.global_transform * point
	var face_out := _out_heading(elevator)
	if not _riders.has(peer):
		var start := _rider_point(peer, goal)
		var travel := goal - start
		travel.y = 0.0
		var face := face_out
		if travel.length_squared() > 0.04:
			face = _heading_of(travel)
		_riders[peer] = {
			"age": 0.0,
			"from": start,
			"face": face,
			"pose": "",
			"block": block,
			"seat": seat,
			"at": start,
		}
	var info: Dictionary = _riders[peer]
	info["age"] = float(info.get("age", 0.0)) + delta
	info["block"] = block
	info["seat"] = seat
	var age := float(info["age"])
	var from: Vector3 = info["from"]
	var approach := float(info["face"])
	var pos := goal
	var heading := face_out
	var running := false
	if age < _BOARD_RUN:
		pos = from.lerp(goal, clampf(age / _BOARD_RUN, 0.0, 1.0))
		heading = approach
		running = true
	elif age < _BOARD_RUN + _BOARD_TURN:
		var turn := clampf((age - _BOARD_RUN) / _BOARD_TURN, 0.0, 1.0)
		heading = rad_to_deg(lerp_angle(deg_to_rad(approach), deg_to_rad(face_out), turn))
		running = true
	info["at"] = pos
	_put_rider(peer, pos, heading, running, delta, info)


func _put_rider(peer: int, pos: Vector3, heading: float, running: bool, delta: float, info: Dictionary) -> void:
	var toon := _toon()
	if toon == null:
		return
	var local := peer == ToonNet.peer_id()
	var actor: ToonActor = null
	if local:
		toon.call("visit_friend", pos, heading)
		actor = toon.call("battle_actor")
	else:
		toon.call("pin_remote", peer, pos, heading)
		actor = toon.call("remote_actor", peer)
	if actor == null:
		return
	var pose := String(info.get("pose", ""))
	if running:
		if pose != "run":
			info["pose"] = "run"
			actor.clear_gesture()
		actor.set_locomotion(9.0, false, false, delta)
		return
	if pose != "stand":
		info["pose"] = "stand"
		actor.clear_gesture()
	actor.set_locomotion(0.0, false, false, delta)


func _rider_point(peer: int, fallback: Vector3) -> Vector3:
	var toon := _toon()
	if toon == null:
		return fallback
	if peer == ToonNet.peer_id():
		return toon.call("battle_point")
	var actor: ToonActor = toon.call("remote_actor", peer)
	if actor == null:
		return fallback
	return actor.global_position


func _drop_boarded_riders() -> void:
	var mine := ToonNet.peer_id()
	var gone: Array[int] = []
	for peer in _riders.keys():
		if _still_aboard(int(peer)):
			continue
		gone.append(int(peer))
	for peer in gone:
		var info: Dictionary = _riders[peer]
		_riders.erase(peer)
		if peer == mine:
			continue
		_start_remote_exit(peer, info)


func _still_aboard(peer: int) -> bool:
	for item in _rows():
		if not (item is Dictionary):
			continue
		for rider in (item as Dictionary).get("toons", []):
			if rider is Dictionary and int((rider as Dictionary).get("id", 0)) == peer:
				return true
	return false


func _start_remote_exit(peer: int, info: Dictionary) -> void:
	var elevator := _street_elevator(int(info.get("block", 0)))
	var seat := int(info.get("seat", 0))
	var from: Vector3 = info.get("at", Vector3.ZERO)
	var dest := from
	if elevator != null:
		dest = elevator.global_transform * _OFF[seat % _OFF.size()]
	var travel := dest - from
	travel.y = 0.0
	var heading := _out_heading(elevator) if elevator != null else 0.0
	if travel.length_squared() > 0.04:
		heading = _heading_of(travel)
	_remote_exits[peer] = {
		"age": 0.0,
		"from": from,
		"to": dest,
		"heading": heading,
	}


func _tick_remote_exits(delta: float) -> void:
	var done: Array[int] = []
	for peer in _remote_exits.keys():
		var info: Dictionary = _remote_exits[peer]
		info["age"] = float(info.get("age", 0.0)) + delta
		var age := float(info["age"])
		var from: Vector3 = info["from"]
		var dest: Vector3 = info["to"]
		var heading := float(info["heading"])
		var running := age < _EXIT_RUN
		var pos := from.lerp(dest, clampf(age / _EXIT_RUN, 0.0, 1.0))
		_put_remote(int(peer), pos, heading, running, delta)
		if not running:
			done.append(int(peer))
	for peer in done:
		_remote_exits.erase(peer)
		var toon := _toon()
		if toon != null:
			toon.call("unpin_remote", peer)


func _put_remote(peer: int, pos: Vector3, heading: float, running: bool, delta: float) -> void:
	var toon := _toon()
	if toon == null:
		return
	toon.call("pin_remote", peer, pos, heading)
	var actor: ToonActor = toon.call("remote_actor", peer)
	if actor == null:
		return
	if running:
		actor.set_locomotion(9.0, false, false, delta)
		return
	actor.clear_gesture()
	actor.set_locomotion(0.0, false, false, delta)


func _hop_off() -> void:
	if _exiting:
		return
	var run := _raw_mine()
	if run.is_empty():
		return
	if String(run.get("state", "")) == "floorboard":
		_hop_floor(run)
		return
	if String(run.get("state", "")) != "boarding" or bool(run.get("depart", false)):
		return
	var block := int(run.get("block", 0))
	var elevator := _street_elevator(block)
	var toon := _toon()
	_exit_from = toon.call("battle_point") if toon != null else Vector3.ZERO
	_exit_to = _exit_from
	if elevator != null:
		_exit_to = elevator.global_transform * _OFF[_seat_index(run) % _OFF.size()]
	var travel := _exit_to - _exit_from
	travel.y = 0.0
	if travel.length_squared() > 0.04:
		_exit_heading = _heading_of(travel)
	else:
		_exit_heading = _out_heading(elevator)
	_exit_age = 0.0
	_exiting = true
	_declined = int(run.get("id", 0))
	_avoid = block
	_riders.erase(ToonNet.peer_id())
	if _hop != null:
		_hop.visible = false
	if _clock != null:
		_clock.visible = false
	ToonNet.ask_hop(_district(), _slug(), block)


func _step_exit(delta: float) -> void:
	var run := _raw_mine()
	if not run.is_empty():
		var state := String(run.get("state", ""))
		if state != "boarding" or bool(run.get("depart", false)):
			_exiting = false
			_declined = 0
			_avoid = 0
			_hide_board_gui()
			return
	_exit_age += delta
	var along := clampf(_exit_age / _EXIT_RUN, 0.0, 1.0)
	_move_local(_exit_from.lerp(_exit_to, along), _exit_heading, true, delta)
	var elevator := _street_elevator(_avoid)
	if elevator != null:
		if _cam_blend < 0.0:
			_remember_cam()
		_cam_blend = minf(_cam_blend + delta / _BOARD_CAM, 1.0)
		_aim_board(elevator)
	if along < 1.0:
		return
	_exiting = false
	_inside = false
	_cam_blend = -1.0
	_hide_board_gui()
	_move_local(_exit_to, _exit_heading, false, delta)
	var toon := _toon()
	if toon != null:
		toon.call("hold_for_battle", false)
	_quiet()
	_release_street()
	_clear_cogs()
	if _room != null:
		_room.queue_free()
		_room = null
		_car = null
		_out = null


func _move_local(pos: Vector3, heading: float, running: bool, delta: float) -> void:
	var toon := _toon()
	if toon == null:
		return
	toon.call("visit_friend", pos, heading)
	var actor: ToonActor = toon.call("battle_actor")
	if actor == null:
		return
	if running:
		actor.set_locomotion(9.0, false, false, delta)
		return
	actor.clear_gesture()
	actor.set_locomotion(0.0, false, false, delta)


## Elevator.enterBoarding. The shot sits in front of the open doors.
func _aim_board(elevator: Node3D) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var dest: Vector3 = elevator.global_transform * Vector3(0.0, -16.0, 5.5)
	var look: Vector3 = elevator.global_transform * Vector3(0.0, 0.0, 5.5)
	var blend := clampf(_cam_blend, 0.0, 1.0)
	camera.global_position = _cam_from.lerp(dest, blend)
	var focus := _look_from.lerp(look, blend)
	if camera.global_position.distance_squared_to(focus) > 0.04:
		camera.look_at(focus, Vector3.UP)


func _remember_cam() -> void:
	_cam_blend = 0.0
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_cam_from = Vector3.ZERO
		_look_from = Vector3.FORWARD
		return
	_cam_from = camera.global_position
	_look_from = _cam_from - camera.global_basis.z * 12.0


## startCountdownClock. Sign-font digits on the car, just inside the frame.
func _paint_clock(elevator: Node3D, show: bool, left: float) -> void:
	if _clock == null:
		return
	if not show or elevator == null:
		_clock.visible = false
		return
	var face := elevator.global_transform.basis * Vector3(0.0, -1.0, 0.0)
	face.y = 0.0
	if face.length_squared() < 0.0001:
		face = Vector3.FORWARD
	face = face.normalized()
	var right := Vector3.UP.cross(face)
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	right = right.normalized()
	var at: Vector3 = elevator.global_transform * Vector3(0.0, 2.0, 7.5)
	_clock.global_transform = Transform3D(Basis(right, Vector3.UP, face).orthonormalized(), at)
	var whole := ceili(left) if left > 0.0 else 0
	var text := str(whole)
	if _clock.text != text:
		_clock.text = text
	_clock.visible = true


func _hide_board_gui() -> void:
	if _hop != null:
		_hop.visible = false
	if _clock != null:
		_clock.visible = false


func _release_riders() -> void:
	if _riders.is_empty():
		return
	var toon := _toon()
	var mine := ToonNet.peer_id()
	for peer in _riders.keys():
		if toon == null:
			continue
		if int(peer) == mine:
			var actor: ToonActor = toon.call("battle_actor")
			if actor != null:
				actor.clear_gesture()
				actor.set_locomotion(0.0, false, false, 0.0)
			continue
		toon.call("unpin_remote", int(peer))
	_riders.clear()


func _build_hop() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ElevatorHop"
	layer.layer = 30
	add_child(layer)
	_hop = TextureButton.new()
	_hop.name = "HopOff"
	_hop.texture_normal = _HOP_UP
	_hop.texture_pressed = _HOP_DN
	_hop.texture_hover = _HOP_OVER
	_hop.ignore_texture_size = true
	_hop.stretch_mode = TextureButton.STRETCH_SCALE
	_hop.focus_mode = Control.FOCUS_NONE
	_hop.visible = false
	_hop.self_modulate = Color(0.5, 0.5, 0.5, 1.0)
	_hop.pressed.connect(_hop_off)
	ToonGui.button_sounds(_hop)
	var caption := Label.new()
	caption.text = "Hop off"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The button tint is the gray image. The caption stays the light text color.
	caption.modulate = Color(2.0, 2.0, 2.0, 1.0)
	caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hop.add_child(caption)
	layer.add_child(_hop)


func _build_clock() -> void:
	var root := Node3D.new()
	root.name = "ElevatorClock"
	add_child(root)
	_clock = Label3D.new()
	_clock.name = "Clock"
	_clock.font = ToonGui.sign_font()
	_clock.font_size = 110
	_clock.pixel_size = 2.0 / 110.0
	_clock.modulate = Color(0.5, 0.5, 0.5, 1.0)
	_clock.outline_size = 0
	_clock.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# TextNode keeps the baseline on (0, 2, 7.5). Bottom alignment parks the
	# descent there instead, so the digits rise into the top of the frame.
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_clock.offset = Vector2(0.0, -_clock.font.get_descent(_clock.font_size))
	_clock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_clock.visible = false
	root.add_child(_clock)


func _place_hop() -> void:
	if _hop == null:
		return
	var view := get_viewport().get_visible_rect().size
	ToonGui.place(_hop, view, 0.0, 0.8, _HOP_W, _HOP_H)
	var caption := _hop.get_child(0) as Label
	if caption == null:
		return
	ToonGui.style_label(caption, Color(0.9, 0.9, 0.9), maxi(int(round(0.12 * view.y * 0.5)), 8), Color(0, 0, 0, 0), 0)


func _street_elevator(block: int) -> Node3D:
	var buildings := _buildings()
	if buildings == null or not buildings.has_method("elevator_node"):
		return null
	var elevator: Variant = buildings.call("elevator_node", block)
	if elevator is Node3D and is_instance_valid(elevator):
		return elevator
	return null


## CollisionSphere(0, 5, 0, collRadius) on the elevator model. The sphere fills
## the car and meets the doorway. A disk of that radius around the door would
## board you from the sidewalk.
func _car_gap(elevator: Node3D, here: Vector3) -> float:
	var local: Vector3 = elevator.global_transform.affine_inverse() * here
	return local.distance_to(Vector3(0.0, 5.0, 0.0))


func _away_from(elevator: Node3D, here: Vector3) -> bool:
	return _car_gap(elevator, here) > REACH


func _out_heading(elevator: Node3D) -> float:
	if elevator == null:
		return 0.0
	var out := elevator.global_transform.basis * Vector3(0.0, -1.0, 0.0)
	out.y = 0.0
	if out.length_squared() < 0.0001:
		return 0.0
	return _heading_of(out)


func _heading_of(dir: Vector3) -> float:
	return rad_to_deg(atan2(-dir.x, -dir.z))


func _aim_ride(elapsed: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _car == null:
		return
	var bob := 4.0
	if elapsed < 0.5:
		bob = 4.0
	elif elapsed < 1.0:
		bob = lerpf(4.0, 3.8, (elapsed - 0.5) / 0.5)
	elif elapsed < 1.5:
		bob = lerpf(3.8, 4.0, (elapsed - 1.0) / 0.5)
	elif elapsed < 2.5:
		bob = 4.0
	elif elapsed < 3.0:
		bob = lerpf(4.0, 4.2, (elapsed - 2.5) / 0.5)
	elif elapsed < 4.0:
		bob = lerpf(4.2, 4.0, (elapsed - 3.0) / 1.0)
	camera.global_position = _car.global_transform * Vector3(0.0, bob, -14.0)
	var look: Vector3 = _car.global_transform * Vector3(0.0, 3.0, -4.0)
	if camera.global_position.distance_squared_to(look) > 0.04:
		camera.look_at(look, Vector3.UP)


func _fight_of(run: Dictionary) -> Dictionary:
	var want := int(run.get("fight", 0))
	if want == 0:
		return {}
	var snap := ToonNet.latest("fights:%d:%s" % [_district(), _slug()])
	var rows: Variant = snap.get("rows", [])
	if not (rows is Array):
		return {}
	for item in rows:
		if item is Dictionary and int((item as Dictionary).get("id", 0)) == want:
			return item
	return {}


func _boss_floor(run: Dictionary) -> bool:
	return int(run.get("floor", 0)) + 1 >= maxi(int(run.get("floors", 1)), 1)


func _play_music(path: String, volume: float) -> void:
	if _tune == path and _music != null and _music.playing:
		return
	_tune = path
	var stream := AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		return
	stream.loop = true
	if _music == null:
		_music = ToonAudio.music_player()
		_music.name = "BuildingMusic"
		add_child(_music)
	_music.stream = stream
	_music.volume_db = linear_to_db(volume)
	_music.play()


func _quiet() -> void:
	_tune = ""
	if _music != null:
		_music.stop()


var _street: AudioStreamPlayer
var _street_on := false


func _hold_street() -> void:
	if _street != null and is_instance_valid(_street):
		return
	_street = _street_player()
	if _street == null:
		return
	_street_on = _street.playing
	_street.stop()


func _release_street() -> void:
	var player := _street
	var resume := _street_on
	_street = null
	_street_on = false
	if resume and player != null and is_instance_valid(player):
		player.play()


func _street_player() -> AudioStreamPlayer:
	var current: Node = self
	while current != null:
		for child in current.get_children():
			if child == _music:
				continue
			var player := child as AudioStreamPlayer
			if player != null and str(player.name) == "StreetMusic":
				return player
		current = current.get_parent()
	return null


func _once(token: String, path: String) -> void:
	if _cue == token:
		return
	_cue = token
	var stream := AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		return
	var player := ToonAudio.effect_player()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _slide(car: Node3D, closed: float) -> void:
	if car == null:
		return
	var left := _find(car, "left-door")
	if left == null:
		left = _find(car, "left_door")
	var right := _find(car, "right-door")
	if right == null:
		right = _find(car, "right_door")
	var slide := 3.5 * clampf(closed, 0.0, 1.0)
	if left != null:
		left.position.x = slide
	if right != null:
		right.position.x = -slide


func _drop_spin(root: Node3D) -> void:
	for child in root.get_children():
		if not (child is Node3D):
			continue
		var body := child as Node3D
		var basis := body.basis
		var z_up := basis.x.distance_to(Vector3(1, 0, 0)) < 0.02
		z_up = z_up and basis.y.distance_to(Vector3(0, 0, -1)) < 0.02
		z_up = z_up and basis.z.distance_to(Vector3(0, 1, 0)) < 0.02
		if z_up:
			body.basis = Basis.IDENTITY
		return


func _dept_color(track: String) -> Color:
	if track == "l":
		return Color(0.45, 0.48, 0.62)
	if track == "m":
		return Color(0.4, 0.55, 0.45)
	if track == "s":
		return Color(0.55, 0.42, 0.55)
	return Color(0.55, 0.48, 0.45)


func _place_banner() -> void:
	var view := get_viewport().get_visible_rect().size
	if _banner == null or view.y < 1.0:
		return
	_banner.position = Vector2(view.x * 0.5 - 220.0, view.y * 0.18)
	_banner.size = Vector2(440.0, 48.0)


func _buildings() -> Node:
	return get_parent().get_node_or_null("StreetBuildings")


func _toon() -> Node:
	var host := get_parent()
	if host == null:
		return null
	return host.get_node_or_null("PlaygroundToon")


func _mask_remotes(run: Dictionary) -> void:
	var toon := _toon()
	if toon == null or not toon.has_method("remote_actor"):
		return
	var mine := int(run.get("id", -1))
	var away := {}
	for item in _rows():
		if not (item is Dictionary):
			continue
		var other: Dictionary = item
		var together := mine > 0 and int(other.get("id", 0)) == mine
		var state := String(other.get("state", ""))
		var gone := state == "riding" or state == "battle" or state == "victory" or state == "failed" or state == "resting" or state == "floorboard"
		if together or not gone:
			continue
		for rider in other.get("toons", []):
			if rider is Dictionary:
				away[int((rider as Dictionary).get("id", 0))] = true
	for peer in _hidden.keys():
		if away.has(int(peer)):
			continue
		var actor: ToonActor = toon.call("remote_actor", int(peer))
		if actor != null:
			actor.visible = true
	_hidden = away
	for peer in away.keys():
		var actor: ToonActor = toon.call("remote_actor", int(peer))
		if actor != null:
			actor.visible = false


func _building_rows() -> Array:
	var snap := ToonNet.latest("buildings:%d:%s" % [_district(), _slug()])
	var rows: Variant = snap.get("rows", [])
	if rows is Array:
		return rows
	return []


func _district() -> int:
	var buildings := _buildings()
	if buildings != null:
		return int(buildings.get("district_id"))
	return ToonNet.district_id()


func _slug() -> String:
	var buildings := _buildings()
	if buildings != null:
		return str(buildings.get("street_slug"))
	return ""


func _find(root: Node, needle: String) -> Node3D:
	if root == null:
		return null
	var wanted := needle.to_lower()
	if str(root.name).to_lower().contains(wanted) and root is Node3D:
		return root
	for child in root.get_children():
		var found := _find(child, needle)
		if found != null:
			return found
	return null


func _vec(value: Variant) -> Vector3:
	if value is Array:
		var row: Array = value
		if row.size() >= 3:
			return Vector3(float(row[0]), float(row[1]), float(row[2]))
	return Vector3.ZERO
