extends Node

## RegenTreasurePlannerAI places maxTreasures at empty points, then every
## spawnInterval seconds fills one empty point. A treasure stays where it is
## until someone grabs it. DistributedSZTreasureAI heals when laff is missing
## and DistributedTreasure.setReject flashes the picture when it is not.

const SHADOW_TEXTURE := "res://assets/neighborhoods/toontown_central/props/drop_shadow.png"
const GRAB_SOUND := "res://assets/audio/sfx/SZ_DD_treasure.ogg"
const REJECT_SOUND := "res://assets/audio/sfx/ring_miss.ogg"
const SCALE := 0.9
const GRAB_REACH := 2.15
const FLY_TIME := 1.0

var kind := ""

var _scene := ""
var _heal := 0
var _interval := 20.0
var _max := 0
var _points: Array[Vector3] = []
var _slots: Array[Dictionary] = []
var _wait := 20.0
var _grab: AudioStream
var _reject: AudioStream


static func attach(host: Node, playground: String) -> void:
	if host == null or host.get_node_or_null("PlaygroundTreasures") != null:
		return
	var treasures: Node = (load("res://scenes/playgrounds/playground_treasures.gd") as GDScript).new()
	treasures.name = "PlaygroundTreasures"
	treasures.set("kind", playground)
	host.add_child(treasures)


## DistributedSZTreasureAI.healAmount. Streets use the hood id (2000 is
## Toontown Central) so a joke door can heal the same amount.
static func heal_amount(playground: String) -> int:
	match playground:
		"dd", "dg", "mm":
			return 10
		"br", "dl":
			return 12
		_:
			return 3


static func heal_for_hood(hood: int) -> int:
	match hood:
		1000:
			return heal_amount("dd")
		3000:
			return heal_amount("br")
		4000:
			return heal_amount("mm")
		5000:
			return heal_amount("dg")
		9000:
			return heal_amount("dl")
		_:
			return heal_amount("tt")


func _ready() -> void:
	_configure()
	if _scene == "" or _points.is_empty():
		return
	if not ResourceLoader.exists(_scene):
		return
	var packed := load(_scene) as PackedScene
	if packed == null:
		return
	_grab = AudioStreamOggVorbis.load_from_file(GRAB_SOUND)
	_reject = AudioStreamOggVorbis.load_from_file(REJECT_SOUND)
	_build(packed)
	for _n in _max:
		_place_one()
	_wait = _interval


func _process(delta: float) -> void:
	if _slots.is_empty():
		return
	var player := _player()
	var toon := _toon()
	var camera := get_viewport().get_camera_3d()
	for slot in _slots:
		_tick(slot, delta, player, toon, camera)
	_wait -= delta
	if _wait <= 0.0:
		_wait = _interval
		_place_one()


func _configure() -> void:
	_heal = heal_amount(kind)
	match kind:
		"tt":
			_scene = "res://assets/neighborhoods/toontown_central/props/icecream.glb"
			_heal = 3
			_interval = 20.0
			_max = 5
			_points = _convert([[-59.9, -6.9, 0.84], [-90.6, -3.0, -0.75], [27.1, -93.5, 2.5], [94.2, 33.5, 4.0], [35.4, 43.1, 4.0], [67.1, 105.5, 2.5], [-99.15, -87.3407, 0.52499], [1.60586, -119.492, 3.025], [43.2026, -76.287, 3.025], [129.137, -61.9039, 2.525], [92.99, -158.399, 3.025], [111.749, -8.59927, 4.57466], [41.999, -30.2923, 4.025], [31.0649, -43.9149, 4.025], [10.0156, 105.218, 2.525], [46.9667, 169.143, 3.025], [100.68, 93.9896, 2.525], [129.285, 58.6107, 2.525], [-28.6272, 85.9833, 0.525], [-114.613, 86.1727, 0.525], [-132.528, 31.255, 0.025]])
		"dd":
			_heal = 10
			_interval = 20.0
			_max = 2
			_points = _convert([[52.9072, -23.4768, -12.308], [35.3827, -51.9196, -12.308], [17.4252, -57.3107, -12.308], [-0.716054, -68.5, -12.308], [-29.0169, -66.8887, -12.308], [-63.492, -64.2191, -12.308], [-72.2423, -58.3686, -12.308], [-97.9602, -42.8905, -12.308], [-102.215, -34.1519, -12.308], [-102.978, -4.09065, -12.308], [-101.305, 30.6454, -12.308], [-45.0621, -21.0088, -12.308], [-11.4043, -29.0816, -12.308], [2.33548, -7.71722, -12.308], [-8.643, 33.9891, -12.308], [-53.224, 18.1293, -12.308], [-99.7225, -8.1298, -12.308], [-100.457, 28.351, -12.308], [-76.7946, 4.21199, -12.308], [-64.9137, 37.5765, -12.308], [-17.6075, 102.135, -12.308], [-23.4112, 127.777, -12.308], [-11.3513, 128.991, -12.308], [-14.1068, 83.2043, -12.308], [53.2685, 24.3585, -12.308], [41.4197, 4.35384, -12.308]])
		"dg":
			_heal = 10
			_interval = 15.0
			_max = 2
			_points = _convert([[-49.0, 156.0, 0.0], [-59.0, 50.0, 0.0], [19.0, 16.0, 0.0], [76.0, 38.0, 1.1], [102.0, 121.0, 0.0], [69.0, 123.0, 0.0], [49.0, 105.0, 0.0], [24.0, 156.0, 0.0], [-27.0, 127.0, 0.0], [-56.0, 105.0, 0.0], [-40.0, 113.0, 0.0], [25.0, 114.0, 0.0], [-6.0, 84.0, 0.0], [19.0, 96.0, 0.0], [0.0, 114.0, 0.0], [-78.0, 157.0, 10.0], [-33.4, 218.2, 10.0], [57.0, 205.0, 10.0], [32.0, 77.0, 0.0], [-102.0, 101.0, 0.0]])
		"mm":
			_heal = 10
			_interval = 20.0
			_max = 2
			_points = _convert([[118.0, -39.0, 3.3], [118.0, 1.0, 3.3], [112.0, -22.0, 0.8], [108.0, -74.0, -4.5], [110.0, -65.0, -4.5], [102.0, 23.5, -4.5], [60.0, -115.0, 6.5], [-5.0, -115.0, 6.5], [-64.0, -77.0, 6.5], [-77.0, -44.0, 6.5], [-76.0, 3.0, 6.5], [44.0, 76.0, 6.5], [136.0, -96.0, -13.5], [85.0, -6.7, -13.5], [60.0, -95.0, -14.5], [72.0, 60.0, -13.5], [-55.0, -23.0, -14.5], [-21.0, 47.0, -14.5], [-24.0, -75.0, -14.5]])
		"br":
			_heal = 12
			_interval = 20.0
			_max = 2
			_points = _convert([[-108.0, 46.0, 6.2], [-111.0, 74.0, 6.2], [-126.0, 81.0, 6.2], [-74.0, -75.0, 3.0], [-136.0, -51.0, 3.0], [-20.0, 35.0, 6.2], [-55.0, 109.0, 6.2], [58.0, -57.0, 6.2], [-42.0, -134.0, 6.2], [-68.0, -148.0, 6.2], [-1.0, -62.0, 6.2], [25.0, 2.0, 6.2], [-133.0, 53.0, 6.2], [-99.0, 86.0, 6.2], [30.0, 63.0, 6.2], [-147.0, 3.0, 6.2], [-135.0, -102.0, 6.2], [35.0, -98.0, 6.2]])
		"dl":
			_heal = 12
			_interval = 20.0
			_max = 2
			_points = _convert([[86.0, 69.0, -17.4], [34.0, -48.0, -16.4], [87.0, -70.0, -17.5], [-98.0, 99.0, 0.0], [51.0, 100.0, 0.0], [-45.0, -12.0, -15.0], [9.0, 8.0, -15.0], [-24.0, 64.0, -17.2], [-100.0, -99.0, 0.0], [21.0, -101.0, 0.0], [88.0, -17.0, -15.0], [32.0, 70.0, -17.4], [53.0, 35.0, -15.8], [2.0, -30.0, -15.5], [-40.0, -56.0, -16.8], [-28.0, 18.0, -15.0], [-34.0, -88.0, 0.0]])
		"oz":
			_heal = 3
			_interval = 20.0
			_max = 5
			_points = _convert([[-156.9, -118.9, 0.025], [-35.6, 86.0, 1.25], [116.8, 10.8, 0.104], [-35.0, 145.7, 0.025], [-198.8, -45.1, 0.025], [-47.1, -25.5, 0.809], [59.15, 34.8, 1.767], [-81.02, -72.2, 0.026], [-167.9, 124.5, 0.025], [-226.7, -27.6, 0.025], [-16.0, -108.9, 0.025], [18.0, 58.5, 5.919], [91.4, 127.8, 0.025], [-86.5, -75.9, 0.025], [-48.751, -32.3, 1.143]])


func _convert(raw: Array) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for item in raw:
		var row: Array = item
		points.append(Vector3(float(row[0]), float(row[2]), -float(row[1])))
	return points


func _build(packed: PackedScene) -> void:
	for point in _points:
		var root := Node3D.new()
		root.name = "treasure_%d" % _slots.size()
		root.scale = Vector3(SCALE, SCALE, SCALE)
		add_child(root)
		root.global_position = point
		var model := packed.instantiate() as Node3D
		model.name = "model"
		root.add_child(model)
		var shadow := _shadow()
		root.add_child(shadow)
		var mats: Array[StandardMaterial3D] = []
		var colors: Array[Color] = []
		var modes: Array[int] = []
		_own(model, mats, colors, modes)
		var card := _billboard(model)
		var rest := Basis.IDENTITY
		if card != null:
			rest = card.global_transform.basis
		root.visible = false
		_slots.append({
			"root": root,
			"model": model,
			"shadow": shadow,
			"state": "empty",
			"home": point,
			"from": point,
			"elapsed": 0.0,
			"flash": 0.0,
			"inside": false,
			"mats": mats,
			"colors": colors,
			"modes": modes,
			"card": card,
			"rest": rest,
		})


func _tick(slot: Dictionary, delta: float, player: Node3D, toon: Node, camera: Camera3D) -> void:
	var state := String(slot["state"])
	if state == "empty":
		return
	_face(slot, camera)
	if state == "fly":
		_advance_fly(slot, delta, player)
		return
	if state == "flash":
		_advance_flash(slot, delta)
		return
	if player == null:
		return
	var root := slot["root"] as Node3D
	var near := _near(root, player)
	if near and not bool(slot["inside"]):
		slot["inside"] = true
		_try(slot, toon)
	elif not near:
		slot["inside"] = false


func _try(slot: Dictionary, toon: Node) -> void:
	if toon == null or not toon.has_method("laff_missing") or not toon.has_method("heal"):
		return
	if int(toon.call("laff_missing")) <= 0:
		_start_flash(slot)
		return
	toon.call("heal", _heal)
	_start_fly(slot)


func _start_flash(slot: Dictionary) -> void:
	slot["state"] = "flash"
	slot["flash"] = 0.0
	_play(_reject, slot["root"] as Node3D)


func _advance_flash(slot: Dictionary, delta: float) -> void:
	var t := float(slot["flash"]) + delta
	slot["flash"] = t
	_paint(slot, _darkness(t))
	if t >= 1.0:
		slot["state"] = "out"
		slot["flash"] = 0.0
		_paint(slot, 0.0)


func _darkness(t: float) -> float:
	# setReject fades to black over 0.8s, then back over 0.2s.
	if t <= 0.0 or t >= 1.0:
		return 0.0
	if t < 0.8:
		var into := t / 0.8
		return into * into
	var back := (t - 0.8) / 0.2
	var eased := 1.0 - (1.0 - back) * (1.0 - back)
	return 1.0 - eased


func _start_fly(slot: Dictionary) -> void:
	var root := slot["root"] as Node3D
	slot["state"] = "fly"
	slot["elapsed"] = 0.0
	slot["from"] = root.global_position
	var shadow := slot["shadow"] as Node3D
	if shadow != null:
		shadow.visible = false
	_play(_grab, root)


func _advance_fly(slot: Dictionary, delta: float, player: Node3D) -> void:
	var root := slot["root"] as Node3D
	var elapsed := float(slot["elapsed"]) + delta
	slot["elapsed"] = elapsed
	var u := clampf(elapsed / FLY_TIME, 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	var start: Vector3 = slot["from"]
	var target := start + Vector3(0.0, 3.0, 0.0)
	if player != null:
		target = player.global_position + Vector3(0.0, 3.0, 0.0)
	root.global_position = start.lerp(target, u)
	if elapsed < FLY_TIME:
		return
	root.visible = false
	root.global_position = slot["home"]
	slot["state"] = "empty"
	var shadow := slot["shadow"] as Node3D
	if shadow != null:
		shadow.visible = true


func _place_one() -> void:
	var sitting := 0
	var empty: Array[int] = []
	for i in _slots.size():
		var state := String(_slots[i]["state"])
		if state == "out" or state == "flash":
			sitting += 1
		elif state == "empty":
			empty.append(i)
	if sitting >= _max or empty.is_empty():
		return
	_show(empty[randi() % empty.size()])


func _show(index: int) -> void:
	var slot: Dictionary = _slots[index]
	var root := slot["root"] as Node3D
	var home: Vector3 = slot["home"]
	root.global_position = home
	root.visible = true
	var shadow := slot["shadow"] as Node3D
	if shadow != null:
		shadow.visible = true
	slot["state"] = "out"
	slot["inside"] = false
	slot["flash"] = 0.0
	slot["elapsed"] = 0.0
	_paint(slot, 0.0)


func _near(root: Node3D, player: Node3D) -> bool:
	if root == null or player == null:
		return false
	var offset := player.global_position - root.global_position
	if absf(offset.y) > 4.0:
		return false
	offset.y = 0.0
	return offset.length() <= GRAB_REACH


func _face(slot: Dictionary, camera: Camera3D) -> void:
	if camera == null:
		return
	var card := slot["card"] as Node3D
	if card != null:
		var rest: Basis = slot["rest"]
		_yaw(card, rest, camera.global_position)
		return
	var model := slot["model"] as Node3D
	if model == null:
		return
	var flat := camera.global_position - model.global_position
	flat.y = 0.0
	if flat.length() < 0.001:
		return
	# The ice-cream cone's visible side is +Z. look_at aims -Z at the point.
	model.look_at(model.global_position - flat, Vector3.UP)


func _yaw(node: Node3D, rest: Basis, target: Vector3) -> void:
	# Same yaw as the playground cards: the picture faces -Y.
	var face := Vector3(-rest.y.x, 0.0, -rest.y.z)
	var to_target := target - node.global_position
	to_target.y = 0.0
	if face.length() < 0.0001 or to_target.length() < 0.0001:
		return
	var turned := node.global_transform
	turned.basis = rest.rotated(Vector3.UP, face.signed_angle_to(to_target, Vector3.UP))
	node.global_transform = turned


func _paint(slot: Dictionary, darkness: float) -> void:
	var mats: Array = slot["mats"]
	var colors: Array = slot["colors"]
	var modes: Array = slot["modes"]
	for i in mats.size():
		var mat := mats[i] as StandardMaterial3D
		if mat == null:
			continue
		var base: Color = colors[i]
		if darkness <= 0.001:
			mat.albedo_color = base
			mat.transparency = int(modes[i])
		else:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(base.r, base.g, base.b, base.a) * (1.0 - darkness)


func _own(node: Node, mats: Array[StandardMaterial3D], colors: Array[Color], modes: Array[int]) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var source := mesh.get_active_material(0) as StandardMaterial3D
		if source == null and mesh.mesh != null:
			source = mesh.mesh.surface_get_material(0) as StandardMaterial3D
		if source != null:
			var copy := source.duplicate() as StandardMaterial3D
			copy.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			copy.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.material_override = copy
			mats.append(copy)
			colors.append(copy.albedo_color)
			modes.append(int(copy.transparency))
	for child in node.get_children():
		_own(child, mats, colors, modes)


func _billboard(node: Node) -> Node3D:
	if node is Node3D and String(node.name).contains("__billboard"):
		return node as Node3D
	for child in node.get_children():
		var found := _billboard(child)
		if found != null:
			return found
	return null


func _shadow() -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.orientation = PlaneMesh.FACE_Y
	mesh.size = Vector2(8.0, 8.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.0, 0.0, 0.0, 0.5)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var texture := load(SHADOW_TEXTURE) as Texture2D
	if texture:
		material.albedo_texture = texture
	var shadow := MeshInstance3D.new()
	shadow.name = "shadow"
	shadow.mesh = mesh
	shadow.material_override = material
	shadow.position = Vector3(0.0, 0.025, 0.0)
	shadow.scale = Vector3(0.4, 0.4, 0.4)
	return shadow


func _play(stream: AudioStream, root: Node3D) -> void:
	if stream == null or root == null:
		return
	var player := ToonAudio.effect_3d()
	player.stream = stream
	player.max_distance = 80.0
	player.unit_size = 12.0
	root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _player() -> Node3D:
	var host := get_parent()
	if host == null:
		return null
	return host.get_node_or_null("Player") as Node3D


func _toon() -> Node:
	var host := get_parent()
	if host == null:
		return null
	return host.get_node_or_null("PlaygroundToon")
