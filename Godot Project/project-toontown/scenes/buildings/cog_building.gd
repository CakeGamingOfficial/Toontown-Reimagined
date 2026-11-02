extends Node

## The local toon boards a cog building. DistributedElevatorExt counts down,
## the doors close, and DistributedSuitInterior plays each floor. The server
## run decides the floor. This only shows it.

const _ELEVATOR := preload("res://assets/buildings/cog/elevator.glb")
const _LOBBY := preload("res://assets/buildings/cog/suit_interior.glb")
const _HALL := preload("res://assets/buildings/cog/cubicle_room.glb")
const _OFFICE := preload("res://assets/buildings/cog/boss_suit_office.glb")
const _RUNS := preload("res://scenes/buildings/building_runs.gd")
const _ELEVATOR_MUSIC := "res://assets/buildings/cog/audio/tt_elevator.ogg"
const _INDOOR_MUSIC := "res://assets/buildings/cog/audio/encntr_toon_winning_indoor.ogg"
const _OPEN_SFX := "res://assets/buildings/cog/audio/elevator_door_open.ogg"
const _CLOSE_SFX := "res://assets/buildings/cog/audio/elevator_door_close.ogg"
const REACH := 5.5
const _SEATS: Array[Vector3] = [
	Vector3(-1.5, 0.1, -5.0), Vector3(1.5, 0.1, -5.0),
	Vector3(-2.5, 0.1, -3.0), Vector3(2.5, 0.1, -3.0),
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
	set_process(true)


func _process(delta: float) -> void:
	_ask = maxf(_ask - delta, 0.0)
	_place_banner()
	var run := _mine()
	if run.is_empty():
		_leave()
		_offer(delta)
		_mask_remotes({})
		return
	_enter(run)
	_show(run)
	_sync_cogs(run)
	_mask_remotes(run)


func _mine() -> Dictionary:
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
	var best := 0
	var best_dist := REACH
	for item in _building_rows():
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		if String(row.get("state", "")) == "clearing":
			continue
		var spot: Vector3 = buildings.call("elevator_spot", int(row.get("block", 0)))
		if spot == Vector3.ZERO:
			continue
		var dist := Vector2(spot.x - here.x, spot.z - here.z).length()
		if dist < best_dist:
			best = int(row.get("block", 0))
			best_dist = dist
	if best == 0:
		_banner.visible = false
		return
	_banner.visible = true
	_banner.text = "Boarding the elevator"
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
	_quiet()
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


func _show(run: Dictionary) -> void:
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
	if fight_state == "reserves":
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
		if state == "riding" or state == "battle":
			story = int(run.get("floor", 0))
		buildings.call("set_story", block, story)
	if state == "riding":
		_play_music(_ELEVATOR_MUSIC)
	elif fight_state == "reward":
		_play_music(_INDOOR_MUSIC)
	else:
		_quiet()
	_banner.visible = true
	if state == "boarding":
		_banner.text = "Elevator leaving in %d" % ceili(float(run.get("left", 0.0)))
	elif state == "riding":
		_banner.text = "Floor %d of %d" % [int(run.get("floor", 0)) + 1, int(run.get("floors", 1))]
		_aim_ride(6.0 - float(run.get("left", 0.0)))
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
	if state == "boarding" or state == "closing" or state == "battle":
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
		var points: Array[Vector3] = [spot]
		actor.setup(cog, points, PackedInt32Array([0]), 0, {}, {})
		actor.set_meta("do_id", int(id))
		actor.hold_fight(true, spot, 0.0)


func _clear_cogs() -> void:
	for child in _suits.get_children():
		child.queue_free()


func _seat(run: Dictionary) -> Vector3:
	if _car == null:
		return _RUNS.room_origin(int(run.get("block", 0)))
	var index := 0
	var peer := ToonNet.peer_id()
	for rider in run.get("toons", []):
		if rider is Dictionary and int((rider as Dictionary).get("id", 0)) == peer:
			break
		index += 1
	return _car.global_transform * _SEATS[index % _SEATS.size()]


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


func _play_music(path: String) -> void:
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
	_music.volume_db = linear_to_db(0.8)
	_music.play()


func _quiet() -> void:
	_tune = ""
	if _music != null:
		_music.stop()


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
		var gone := state == "riding" or state == "battle" or state == "victory" or state == "failed"
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
