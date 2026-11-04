extends Node3D

## CashbotHQExterior.TrainTracks and safezone.Train. Four trains share one
## clock. Each track leaves every 15 seconds, staggered, with a random string
## of cars. One run in four stops at the station and starts again.

const _LOCO := "res://assets/cog_hq/trains/locomotive.glb"
const _CARS: Array[String] = [
	"res://assets/cog_hq/trains/box_car.glb",
	"res://assets/cog_hq/trains/tank_car.glb",
	"res://assets/cog_hq/trains/flat_car.glb",
]
const _PASS := "res://assets/cog_hq/audio/CBHQ_TRAIN_pass.ogg"
const _STOP := "res://assets/cog_hq/audio/CBHQ_TRAIN_stopstart.ogg"
# The yard export parks panda (177.3, -103.4) on the origin.
const _SHIFT_X := -177.3
const _SHIFT_Z := -103.4
const _TRACK_Z := -67.0
const _CAR_LENGTH := 88.0
const _MARK := 15.0
# Locomotive tight bounds, plus the longest car past the last hitch.
const _NOSE := -116.94
const _LOCO_TAIL := 90.11
const _CAR_TAIL := 90.0
const _HEIGHT := 62.0
const _WIDTH := 36.0
# Tunnel5 through Tunnel8 open toward the station at panda x = -136.
const _TUNNEL_X := -136.0 + _SHIFT_X
const _CLIP := preload("res://scenes/cog_hq/train_clip.gdshader")

const _TRACKS: Array[Vector2] = [
	Vector2(-1000.0, -54.45),
	Vector2(1800.0, -133.45),
	Vector2(-1000.0, -212.45),
	Vector2(1800.0, -291.45),
]
const _ENDS: Array[Vector2] = [
	Vector2(2200.0, -54.45),
	Vector2(-1200.0, -133.45),
	Vector2(2200.0, -212.45),
	Vector2(-1200.0, -291.45),
]

var _runs: Array[Dictionary] = []


static func place(host: Node) -> void:
	if host.get_node_or_null("CashbotTrains") != null:
		return
	var yard := Node3D.new()
	yard.name = "CashbotTrains"
	yard.set_script(load("res://scenes/cog_hq/cashbot_trains.gd"))
	host.add_child(yard)


func _ready() -> void:
	var pass_sfx := AudioStreamOggVorbis.load_from_file(_PASS)
	var stop_sfx := AudioStreamOggVorbis.load_from_file(_STOP)
	var loco_scene := load(_LOCO) as PackedScene
	var car_scenes: Array[PackedScene] = []
	for path in _CARS:
		car_scenes.append(load(path) as PackedScene)
	for index in _TRACKS.size():
		var mover := Node3D.new()
		mover.name = "Train%d" % index
		add_child(mover)
		if loco_scene != null:
			var loco := loco_scene.instantiate()
			loco.name = "Locomotive"
			mover.add_child(loco)
			_clip_tree(loco)
		var hit := Area3D.new()
		hit.name = "Hit"
		hit.monitoring = true
		hit.monitorable = false
		hit.collision_layer = 0
		hit.collision_mask = 1
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		hit.add_child(shape)
		mover.add_child(hit)
		hit.body_entered.connect(_squish)
		var speaker := ToonAudio.effect_player()
		speaker.name = "TrainSound"
		speaker.volume_db = linear_to_db(0.5)
		mover.add_child(speaker)
		var flipped := _TRACKS[index].x < _ENDS[index].x
		if flipped:
			mover.rotation.y = PI
		_runs.append({
			"index": index,
			"mover": mover,
			"cars": car_scenes,
			"hit": shape,
			"speaker": speaker,
			"pass": pass_sfx,
			"stop": stop_sfx,
			"flipped": flipped,
			"run": -1,
			"sounded": true,
			"count": 0,
			"stop_run": false,
			"span": 6.0,
			"sfx": 0.0,
			"which": _PASS,
		})
	_sync(Time.get_unix_time_from_system())


func _process(_delta: float) -> void:
	_sync(Time.get_unix_time_from_system())


func _sync(now: float) -> void:
	var slot := _MARK / float(_TRACKS.size())
	for row in _runs:
		var index := int(row["index"])
		var first := slot * float(index)
		var run := int(floor((now - first) / _MARK))
		var mark := float(run) * _MARK + first
		var elapsed := now - mark
		if int(row["run"]) != run:
			_roll(row, run)
		_move(row, elapsed)
		_sound(row, elapsed)


func _roll(row: Dictionary, run: int) -> void:
	row["run"] = run
	row["sounded"] = false
	var rng := RandomNumberGenerator.new()
	rng.seed = int(row["index"]) + run + 1
	var count := rng.randi_range(1, 9)
	var types: Array[int] = []
	for _car in count:
		types.append(rng.randi_range(0, _CARS.size() - 1))
	var stop_run := rng.randi_range(0, 3) == 0
	var span := 6.0
	var sfx := 0.0
	var which := _PASS
	if stop_run:
		span = float(rng.randi_range(4, 5))
		sfx = maxf(span - 4.3, 0.0)
		which = _STOP
	else:
		span = float(rng.randi_range(6, int(_MARK) - 2))
		sfx = span * 0.5 - 3.5
		if bool(row["flipped"]):
			sfx -= 1.0
		else:
			sfx += 1.0
	row["count"] = count
	row["stop_run"] = stop_run
	row["span"] = span
	row["sfx"] = sfx
	row["which"] = which
	_build_cars(row, types)
	if elapsed_past_sound(row, sfx):
		row["sounded"] = true


func elapsed_past_sound(row: Dictionary, sfx: float) -> bool:
	var now := Time.get_unix_time_from_system()
	var index := int(row["index"])
	var first := _MARK / float(_TRACKS.size()) * float(index)
	var mark := float(int(row["run"])) * _MARK + first
	return now - mark > sfx + 1.0


func _build_cars(row: Dictionary, types: Array[int]) -> void:
	var mover := row["mover"] as Node3D
	var old := mover.get_node_or_null("Cars")
	if old != null:
		old.free()
	var holder := Node3D.new()
	holder.name = "Cars"
	mover.add_child(holder)
	var scenes: Array = row["cars"]
	for index in types.size():
		var packed: PackedScene = scenes[types[index]]
		if packed == null:
			continue
		var car := packed.instantiate()
		holder.add_child(car)
		car.position = Vector3(_CAR_LENGTH * float(index + 1), 0.0, 0.0)
		_clip_tree(car)
	var tail := _LOCO_TAIL
	if not types.is_empty():
		tail = _CAR_LENGTH * float(types.size()) + _CAR_TAIL
	var length := tail - _NOSE
	var box := row["hit"] as CollisionShape3D
	var shape := box.shape as BoxShape3D
	shape.size = Vector3(length, _HEIGHT, _WIDTH)
	box.position = Vector3(_NOSE + length * 0.5, _HEIGHT * 0.5, 0.0)


func _move(row: Dictionary, elapsed: float) -> void:
	var index := int(row["index"])
	var start := _point(_TRACKS[index])
	var finish := _point(_ENDS[index])
	var span := float(row["span"])
	var where := finish
	if bool(row["stop_run"]):
		var halfway := _point(Vector2(150.0, _TRACKS[index].y))
		if elapsed < span:
			where = start.lerp(halfway, _ease_in_out(elapsed / span))
		elif elapsed < span + 3.0:
			where = halfway
		elif elapsed < span * 2.0 + 3.0:
			where = halfway.lerp(finish, _ease_in((elapsed - span - 3.0) / span))
	elif elapsed < span:
		where = start.lerp(finish, clampf(elapsed / span, 0.0, 1.0))
	var mover := row["mover"] as Node3D
	var yaw := mover.rotation.y
	mover.position = where
	mover.rotation.y = yaw


func _sound(row: Dictionary, elapsed: float) -> void:
	if bool(row["sounded"]) or elapsed < float(row["sfx"]):
		return
	row["sounded"] = true
	if elapsed > float(row["sfx"]) + 1.0:
		return
	var speaker := row["speaker"] as AudioStreamPlayer
	var source: AudioStream = row["pass"] if String(row["which"]) == _PASS else row["stop"]
	if source == null or speaker == null:
		return
	speaker.stream = source
	speaker.play()


func _clip_tree(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null:
			for surface in mesh_node.mesh.get_surface_count():
				var source := mesh_node.get_active_material(surface) as StandardMaterial3D
				var painted := ShaderMaterial.new()
				painted.shader = _CLIP
				painted.set_shader_parameter("clip_x", _TUNNEL_X)
				var tint := Color(1, 1, 1, 1)
				var texture: Texture2D = null
				if source != null:
					tint = source.albedo_color
					texture = source.albedo_texture
				painted.set_shader_parameter("albedo_color", tint)
				painted.set_shader_parameter("use_tex", texture != null)
				if texture != null:
					painted.set_shader_parameter("albedo_tex", texture)
				mesh_node.set_surface_override_material(surface, painted)
	for child in node.get_children():
		_clip_tree(child)


func _point(panda: Vector2) -> Vector3:
	return Vector3(panda.x + _SHIFT_X, _TRACK_Z, -panda.y + _SHIFT_Z)


func _ease_in_out(amount: float) -> float:
	var t := clampf(amount, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _ease_in(amount: float) -> float:
	var t := clampf(amount, 0.0, 1.0)
	return t * t


func _squish(body: Node) -> void:
	if body == null or body.name != "Player":
		return
	var place := get_parent().get_node_or_null("PlaygroundToon")
	if place != null and place.has_method("squish"):
		place.call("squish", 10)
