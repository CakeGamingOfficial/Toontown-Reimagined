extends Node3D
class_name StreetCog

## A street suit flies in, walks the right-hand lane, then flies out.
## A building suit walks out of a cog door and later walks back into one.
## The lane is one loop: right sidewalk to the end, cross, then the other sidewalk back.
## Battles are not started from here.

const WALK_SPEED := 4.8
const MIN_PATH_POINTS := 40
const MAX_PATH_POINTS := 300
const FROM_SKY := 6.5
## SuitTimings.fromSuitBuilding and DistributedSuit.STAND_OUTSIDE_DOOR.
const FROM_BUILDING := 2.0
const STAND_OUTSIDE := 2.5
const SKY_HEIGHT := FROM_SKY * WALK_SPEED
const GROUND_FRAME := 28
const DEFAULT_FPS := 24.0
const _DEPT_NAMES := {
	"c": "Bossbot",
	"l": "Lawbot",
	"m": "Cashbot",
	"s": "Sellbot",
}
## Parsed clip files are shared. Each cog only keeps its own mesh instance.
## Frames are baked one at a time. Building every pose in setup() was the street hitch.
static var _clip_files: Dictionary = {}
static var _index_cursor := 0
static var _bake_done := false
static var _pose_seq := 0
const _INDEX_PATHS: PackedStringArray = [
	"res://assets/cogs/anims/a/walk.walk",
	"res://assets/cogs/anims/a/neutral.walk",
	"res://assets/cogs/anims/a/landing.walk",
	"res://assets/cogs/anims/b/walk.walk",
	"res://assets/cogs/anims/b/neutral.walk",
	"res://assets/cogs/anims/b/landing.walk",
	"res://assets/cogs/anims/c/walk.walk",
	"res://assets/cogs/anims/c/neutral.walk",
	"res://assets/cogs/anims/c/landing.walk",
	"res://assets/cogs/props/propeller.walk",
	"res://assets/cogs/anims/robot_a/walk.walk",
	"res://assets/cogs/anims/robot_a/neutral.walk",
	"res://assets/cogs/anims/robot_a/landing.walk",
	"res://assets/cogs/anims/robot_b/walk.walk",
	"res://assets/cogs/anims/robot_b/neutral.walk",
	"res://assets/cogs/anims/robot_b/landing.walk",
	"res://assets/cogs/anims/robot_c/walk.walk",
	"res://assets/cogs/anims/robot_c/neutral.walk",
	"res://assets/cogs/anims/robot_c/landing.walk",
]
const _SHADE := preload("res://scenes/cogs/cog_shade.gdshader")
## DistributedFactorySuit.setVirtual. Additive red, no depth write.
const _LASER := preload("res://scenes/cogs/cog_laser.gdshader")
const _WAITER_BLAZER := "res://assets/cogs/suits/waiter_m_blazer.png"
const _WAITER_SLEEVE := "res://assets/cogs/suits/waiter_m_sleeve.png"
const _WAITER_LEG := "res://assets/cogs/suits/waiter_m_leg.png"
const _CORP_ICON := preload("res://assets/gui/cogs/CorpIcon.png")
const _LEGAL_ICON := preload("res://assets/gui/cogs/LegalIcon.png")
const _MONEY_ICON := preload("res://assets/gui/cogs/MoneyIcon.png")
const _SALES_ICON := preload("res://assets/gui/cogs/SalesIcon.png")
const _MEDALLION := {
	"c": _CORP_ICON,
	"l": _LEGAL_ICON,
	"m": _MONEY_ICON,
	"s": _SALES_ICON,
}
const _TRAFFIC := preload("res://scenes/streets/street_traffic.gd")
## Suit.generateSuit handColor. The glove geom is untextured; setSuitClothes only tints it.
const _CORP_HAND := Color(0.95, 0.75, 0.75)
const _LEGAL_HAND := Color(0.75, 0.75, 0.95)
const _MONEY_HAND := Color(0.65, 0.95, 0.85)
const _SALES_HAND := Color(0.95, 0.75, 0.95)
const _HAND_COLOR := {
	"f": _CORP_HAND, "p": _CORP_HAND, "ym": _CORP_HAND, "mm": _CORP_HAND,
	"ds": _CORP_HAND, "hh": _CORP_HAND,
	"cr": Color(0.85, 0.55, 0.55), "tbc": Color(0.75, 0.95, 0.75),
	"bf": _LEGAL_HAND, "dt": _LEGAL_HAND, "ac": _LEGAL_HAND, "bs": _LEGAL_HAND, "bw": _LEGAL_HAND,
	"b": Color(0.95, 0.95, 1.0), "sd": Color(0.5, 0.8, 0.75), "le": Color(0.25, 0.25, 0.5),
	"sc": _MONEY_HAND, "tw": _MONEY_HAND, "bc": _MONEY_HAND, "nc": _MONEY_HAND,
	"mb": _MONEY_HAND, "rb": _MONEY_HAND,
	"pp": Color(1.0, 0.5, 0.6), "ls": Color(0.5, 0.85, 0.75),
	"cc": Color(0.55, 0.65, 1.0),
	"tm": _SALES_HAND, "nd": _SALES_HAND, "gh": _SALES_HAND, "ms": _SALES_HAND,
	"tf": _SALES_HAND, "m": _SALES_HAND, "mh": _SALES_HAND,
}

signal departed

var cog_code := ""
var _model_path := ""
var cog_name := ""
var cog_level := 1
var dept := "c"
var body := "c"
var height := 4.0

var _points: Array[Vector3] = []
var _route: PackedInt32Array = PackedInt32Array()
var _slot := 0
var _goal := Vector3.ZERO
var _edges_left := 40
var _detail := 2
var _phase := 0
var _fly := 0.0
var _till_land := FROM_SKY
var _impact := 0.0
var _wait := 0.0
var _landing_frames := 1
var _landing_fps := DEFAULT_FPS
var _walk_fps := DEFAULT_FPS
var _neutral_fps := DEFAULT_FPS
var _walk_time := 0.0
var _idle_time := 0.0
var _tray_time := 0.0
var _tray_banks: Dictionary = {}
var _prop_time := 0.0
var _prop_frames := 0
var _prop_fps := DEFAULT_FPS
var _ground := Vector3.ZERO
var _path_ready := false
var _materials: Array[ShaderMaterial] = []
var _source: Dictionary = {}
var _walk: Dictionary = {}
var _neutral: Dictionary = {}
var _landing: Dictionary = {}
var _attacks: Dictionary = {}
var _body_timing: Dictionary = {}
var _propeller: Node3D
var _prop_bank: Dictionary = {}
var _sound: AudioStreamPlayer3D
var _fight_key := ""
## Suit.healthColors and healthGlowColors. The chest light replaces the badge in a battle.
const _HEALTH_COLORS: Array[Color] = [
	Color(0, 1, 0, 1),
	Color(1, 1, 0, 1),
	Color(1, 0.5, 0, 1),
	Color(1, 0, 0, 1),
	Color(0.3, 0.3, 0.3, 1),
]
const _HEALTH_GLOW: Array[Color] = [
	Color(0.25, 1, 0.25, 0.5),
	Color(1, 1, 0.25, 0.5),
	Color(1, 0.5, 0.25, 0.5),
	Color(1, 0.25, 0.25, 0.5),
	Color(0.3, 0.3, 0.3, 0.0),
]
var _health: Node3D
var _health_disc: MeshInstance3D
var _health_glow: MeshInstance3D
var _health_mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D
var _badge: MeshInstance3D
var _health_scale := Vector3.ONE
var _hp := -1
var _max_hp := 1
var _health_condition := -1
var _blink := 0.0
var _blink_red := true
static var _health_mesh: ArrayMesh
# MovieUtil.SUIT_LOSE_DURATION. Suit.getLoseActor plays the lose-mod across it.
const LOSE_SECONDS := 6.0
var _lose_on := false
var _lose_tried := false
var _lose_age := 0.0
## The server drops a defeated cog when its movie timer ends. A client is
## still playing the lose-mod, so the body stays until that clip finishes.
var _dismissed := false
var _revives := 0
var _laser := false
var _waiter := false
var _lose_bank: Dictionary = {}
var _fight_time := 0.0
var _take: Dictionary = {}
var _take_stage := ""
var _door_goal := Vector3.ZERO
var _building_suit := false
var _from_building := false
var _return_door := Vector3.ZERO
var _return_exit := Vector3.ZERO
var _return_block := -1
var _enter_from := Vector3.ZERO
var _door := Vector3.ZERO
var _exit := Vector3.ZERO


## The dressed suit already carries generateSuit's scale. Applying that
## number again shrinks the smallest bodies, Penny Pincher and Double Talker
## most of all. A skelecog mesh only has the 1.0173 factor, so its own scale
## is still applied here.
func _apply_suit_scale(cog: Dictionary) -> void:
	if bool(cog.get("skeleton", false)) and cog.has("scale"):
		scale = Vector3.ONE * float(cog["scale"])
	else:
		scale = Vector3.ONE


func setup(cog: Dictionary, points: Array[Vector3], route: PackedInt32Array, start: int, timing: Dictionary, propeller: Dictionary, resume: Dictionary = {}) -> void:
	_clear_lose()
	var paths := _suit_paths(cog)
	var want_laser := bool(cog.get("laser", false))
	var want_waiter := bool(cog.get("waiter", false))
	var same := get_node_or_null("Suit") != null and cog_code == str(cog["code"]) and _model_path == String(paths["model"]) and _laser == want_laser and _waiter == want_waiter
	cog_code = str(cog["code"])
	cog_name = str(cog["name"])
	dept = str(cog["dept"])
	body = str(cog["body"])
	height = float(cog["height"])
	cog_level = int(cog.get("level", 1))
	_revives = int(cog.get("revives", 0))
	_laser = want_laser
	_waiter = want_waiter
	name = cog_name
	_model_path = String(paths["model"])
	_apply_suit_scale(cog)
	_source = cog
	_points = points
	_route = route
	_slot = 0
	if route.size() > 0:
		_slot = posmod(start, route.size())
	# The walk is chosen when the suit reaches the sidewalk, not while it
	# is still dropping out of the sky.
	_path_ready = false
	_edges_left = 0
	visible = true
	set_process(true)
	var body_timing: Dictionary = timing.get(body, {})
	_body_timing = body_timing
	var walk_info: Dictionary = body_timing.get("walk", {})
	var neutral_info: Dictionary = body_timing.get("neutral", {})
	var landing_info: Dictionary = body_timing.get("landing", {})
	if float(walk_info.get("fps", 0.0)) > 1.0:
		_walk_fps = float(walk_info["fps"])
	if float(neutral_info.get("fps", 0.0)) > 1.0:
		_neutral_fps = float(neutral_info["fps"])
	if int(landing_info.get("frames", 0)) > 1:
		_landing_frames = int(landing_info["frames"])
		_landing_fps = float(landing_info.get("fps", DEFAULT_FPS))
	_prop_frames = int(propeller.get("frames", 0))
	_prop_fps = float(propeller.get("fps", DEFAULT_FPS))
	if _prop_fps < 1.0:
		_prop_fps = DEFAULT_FPS
	if not same:
		var previous := get_node_or_null("Suit")
		if previous != null:
			_drop_health()
			# The attack clips still point at this suit. Posing them after it is
			# freed is the "previously freed instance" crash on a drop react.
			_attacks.clear()
			previous.free()
		var packed := load(String(paths["model"])) as PackedScene
		if packed == null:
			_give_up()
			return
		var actor := packed.instantiate()
		actor.name = "Suit"
		add_child(actor)
		if not bool(cog.get("skeleton", false)):
			_hide_sleeve_pop(actor)
		_materials.clear()
		_own_materials(actor)
		_paint_hands(actor)
		_quiet_shadows(actor)
		if bool(cog.get("skeleton", false)):
			_paint_medallion(actor)
		_dress_look(actor)
	_release_nametag()
	_add_nametag()
	if not same or _walk.is_empty():
		_walk = _read_bank(String(paths["walk"]))
		_neutral = _read_bank(String(paths["neutral"]))
		_landing = _read_bank(String(paths["landing"]))
	if int(_landing.get("frames", 0)) > 1:
		_landing_frames = int(_landing["frames"])
	if _route.size() < 2:
		_give_up()
		return
	_prepare_landing()
	_read_take(resume)
	_building_suit = bool(resume.get("building_suit", false))
	set_meta("building_suit", _building_suit)
	_return_door = _vec(resume, "return_door", Vector3.ZERO)
	_return_exit = _vec(resume, "return_exit", Vector3.ZERO)
	_return_block = int(resume.get("return_block", -1))
	if int(resume.get("phase", -1)) == 3:
		_phase = 3
		_fly = float(resume.get("fly", 0.0))
		_enter_from = _vec(resume, "enter_from", _vec(resume, "position", global_position))
		global_position = _vec(resume, "position", _enter_from)
		rotation.y = float(resume.get("yaw", 0.0))
		_set_alpha(1.0)
		return
	if bool(resume.get("from_building", false)):
		_begin_exit(resume)
		return
	if resume.is_empty() or int(resume.get("phase", 0)) == 0:
		_phase = 0
		_fly = float(resume.get("fly", 0.0)) if not resume.is_empty() else 0.0
		_ground = _points[_route[_slot]]
		_goal = _ground
		if resume.is_empty():
			global_position = _ground + Vector3(0.0, SKY_HEIGHT, 0.0)
		else:
			global_position = _vec(resume, "position", _ground + Vector3(0.0, SKY_HEIGHT, 0.0))
			rotation.y = float(resume.get("yaw", 0.0))
		_set_alpha(clampf(_fly, 0.0, 1.0) if not resume.is_empty() else 0.0)
		_attach_propeller()
		_play_propeller(true)
		_pose_clip(_landing, 0, 0, 0.0)
		return
	_resume(resume)


## One catalog suit, built before it is asked to appear. setup() then reuses the actor.
func preload_suit(cog: Dictionary, timing: Dictionary, propeller: Dictionary) -> void:
	cog_code = str(cog.get("code", ""))
	body = str(cog.get("body", "c"))
	visible = false
	set_process(false)
	var body_timing: Dictionary = timing.get(body, {})
	_body_timing = body_timing
	var walk_info: Dictionary = body_timing.get("walk", {})
	var neutral_info: Dictionary = body_timing.get("neutral", {})
	var landing_info: Dictionary = body_timing.get("landing", {})
	if float(walk_info.get("fps", 0.0)) > 1.0:
		_walk_fps = float(walk_info["fps"])
	if float(neutral_info.get("fps", 0.0)) > 1.0:
		_neutral_fps = float(neutral_info["fps"])
	if int(landing_info.get("frames", 0)) > 1:
		_landing_frames = int(landing_info["frames"])
		_landing_fps = float(landing_info.get("fps", DEFAULT_FPS))
	_prop_frames = int(propeller.get("frames", 0))
	_prop_fps = float(propeller.get("fps", DEFAULT_FPS))
	if _prop_fps < 1.0:
		_prop_fps = DEFAULT_FPS
	var packed := load("res://assets/cogs/suits/%s.glb" % cog_code) as PackedScene
	if packed == null:
		return
	var actor := packed.instantiate()
	actor.name = "Suit"
	add_child(actor)
	_hide_sleeve_pop(actor)
	_materials.clear()
	_own_materials(actor)
	_paint_hands(actor)
	_quiet_shadows(actor)
	_walk = _read_bank("res://assets/cogs/anims/%s/walk.walk" % body)
	_neutral = _read_bank("res://assets/cogs/anims/%s/neutral.walk" % body)
	_landing = _read_bank("res://assets/cogs/anims/%s/landing.walk" % body)


func capture() -> Dictionary:
	var pos := Vector3.ZERO
	var yaw := 0.0
	if is_inside_tree():
		pos = global_position
		yaw = rotation.y
	return {
		"cog": _source,
		"slot": _slot,
		"edges": _edges_left,
		"phase": _phase,
		"fly": _fly,
		"walk": _walk_time,
		"idle": _idle_time,
		"goal": _goal,
		"ground": _ground,
		"position": pos,
		"yaw": yaw,
		"till": _till_land,
		"impact": _impact,
		"pathed": _path_ready,
		"from_building": _from_building and _phase == 0,
		"building_suit": _building_suit,
		"door": [_door.x, _door.y, _door.z],
		"exit": [_exit.x, _exit.y, _exit.z],
		"return_door": [_return_door.x, _return_door.y, _return_door.z],
		"return_exit": [_return_exit.x, _return_exit.y, _return_exit.z],
		"return_block": _return_block,
		"enter_from": [_enter_from.x, _enter_from.y, _enter_from.z],
		"do_id": int(get_meta("do_id", 0)),
		"takeover": _take,
		"take_stage": _take_stage,
		"door_goal": _door_goal,
	}


func _resume(state: Dictionary) -> void:
	_slot = posmod(int(state.get("slot", _slot)), maxi(_route.size(), 1))
	_edges_left = maxi(int(state.get("edges", _edges_left)), 1)
	_phase = int(state.get("phase", 1))
	_fly = float(state.get("fly", 0.0))
	_walk_time = float(state.get("walk", 0.0))
	_idle_time = float(state.get("idle", 0.0))
	_goal = _vec(state, "goal", _points[_route[_slot]])
	_ground = _vec(state, "ground", _goal)
	global_position = _vec(state, "position", _ground)
	rotation.y = float(state.get("yaw", 0.0))
	if _phase == 0:
		_set_alpha(clampf(_fly, 0.0, 1.0))
		_attach_propeller()
		_play_propeller(true)
		_pose_elapsed(_landing, maxf(_fly - _wait, 0.0), _landing_fps, false)
		return
	if _phase == 2:
		_set_alpha(_fly_out_alpha())
		_attach_propeller()
		_play_propeller(false)
		var dur := float(maxi(_landing_frames, 1)) / _landing_fps
		_pose_elapsed(_landing, dur - _fly, _landing_fps, false)
		return
	if _phase == 3:
		_set_alpha(1.0)
		_enter_from = _vec(state, "enter_from", global_position)
		_return_door = _vec(state, "return_door", _return_door)
		return
	if _take_stage == "door":
		_phase = 1
		_path_ready = true
		_door_goal = _vec(state, "door_goal", _goal)
		_goal = _door_goal
		_set_alpha(1.0)
		return
	_phase = 1
	_path_ready = true
	_set_alpha(1.0)
	_step_lane()
	var frames := maxi(int(_walk.get("frames", 1)), 1)
	_walk_time = fposmod(_walk_time, float(frames))
	var frame := int(_walk_time) % frames
	_pose_clip(_walk, frame, (frame + 1) % frames, _walk_time - float(frame))


func hold_fight(held: bool, point: Vector3, yaw: float) -> void:
	set_meta("in_fight", held)
	if not held:
		_fight_key = ""
		_hide_health()
		return
	global_position = point
	rotation.y = yaw


## Suit.generateHealthBar. The department badge hides and this light shows the
## cog's health: green, yellow, orange, red, then a blink when it is nearly gone.
func set_battle_hp(current: int, maximum: int) -> void:
	var cap := maxi(maximum, 1)
	var next := clampi(current, 0, cap)
	var changed := next != _hp or cap != _max_hp or _health == null or not is_instance_valid(_health)
	_hp = next
	_max_hp = cap
	_ensure_health()
	if changed:
		_health_condition = -1
		_paint_health()


func _ensure_health() -> void:
	if _health != null and is_instance_valid(_health):
		_health.visible = true
		if _badge != null and is_instance_valid(_badge):
			_badge.visible = false
		return
	var suit := get_node_or_null("Suit")
	if suit == null:
		return
	var icon := _find_named(suit, "Icon")
	var chest := icon.get_parent() as Node3D if icon != null else _find(suit, "joint_attachMeter") as Node3D
	if chest == null:
		return
	_badge = icon
	var light := Node3D.new()
	light.name = "HealthLight"
	chest.add_child(light)
	if icon != null:
		light.transform = icon.transform
		icon.visible = false
	_health = light
	_health_scale = light.scale
	var disc := MeshInstance3D.new()
	disc.name = "Disc"
	disc.mesh = _disc_mesh()
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_health_mat = _light_mat(Color(0, 1, 0), false)
	disc.material_override = _health_mat
	light.add_child(disc)
	_health_disc = disc
	var glow := MeshInstance3D.new()
	glow.name = "Glow"
	glow.mesh = _disc_mesh()
	glow.scale = Vector3(1.55, 1.55, 1.55)
	glow.position = Vector3(0.0, 0.04, 0.0)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow_mat = _light_mat(Color(0.25, 1, 0.25, 0.5), true)
	glow.material_override = _glow_mat
	light.add_child(glow)
	_health_glow = glow
	light.visible = true


func _hide_health() -> void:
	_hp = -1
	_health_condition = -1
	if _health != null and is_instance_valid(_health):
		_health.visible = false
		_health.scale = _health_scale
	if _badge != null and is_instance_valid(_badge):
		_badge.visible = true


func _drop_health() -> void:
	_health = null
	_health_disc = null
	_health_glow = null
	_health_mat = null
	_glow_mat = null
	_badge = null
	_hp = -1
	_health_condition = -1


func _paint_health() -> void:
	if _health == null or not is_instance_valid(_health) or _health_mat == null or _glow_mat == null:
		return
	var ratio := clampf(float(_hp) / float(maxi(_max_hp, 1)), 0.0, 1.0)
	var condition := 5
	if ratio > 0.95:
		condition = 0
	elif ratio > 0.7:
		condition = 1
	elif ratio > 0.3:
		condition = 2
	elif ratio > 0.05:
		condition = 3
	elif ratio > 0.0:
		condition = 4
	if condition == _health_condition:
		return
	_health_condition = condition
	_blink = 0.0
	_blink_red = true
	_health.scale = _health_scale
	if condition >= 4:
		_apply_blink()
		return
	_health_mat.albedo_color = _HEALTH_COLORS[condition]
	_glow_mat.albedo_color = _HEALTH_GLOW[condition]


func _tick_health(delta: float) -> void:
	if _health_condition < 4 or _health == null or not is_instance_valid(_health) or not _health.visible:
		return
	_blink += delta
	var hold := 0.25 if _health_condition == 5 else 0.75
	var span := hold if _blink_red else 0.1
	if _blink < span:
		return
	_blink = 0.0
	_blink_red = not _blink_red
	_apply_blink()


func _apply_blink() -> void:
	if _health_mat == null or _glow_mat == null or _health == null or not is_instance_valid(_health):
		return
	var red := _blink_red
	_health_mat.albedo_color = _HEALTH_COLORS[3] if red else _HEALTH_COLORS[4]
	_glow_mat.albedo_color = _HEALTH_GLOW[3] if red else _HEALTH_GLOW[4]
	var pulse := 1.17 if _health_condition == 5 and red else 1.0
	_health.scale = _health_scale * pulse


static func _disc_mesh() -> ArrayMesh:
	if _health_mesh != null:
		return _health_mesh
	var segments := 20
	var radius := 0.533
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	verts.append(Vector3.ZERO)
	normals.append(Vector3.UP)
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		verts.append(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
		normals.append(Vector3.UP)
	var indices := PackedInt32Array()
	for index in segments:
		indices.append(0)
		indices.append(1 + index)
		indices.append(1 + (index + 1) % segments)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_health_mesh = mesh
	return mesh


static func _light_mat(color: Color, glow: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return mat


func march(walking: bool) -> void:
	_fight_key = "walk" if walking else ""
	# The battle moves the suit after this cog has already processed, and a
	# culled suit leaves _detail at 0, which skips the pose. The face-off
	# walk is loop('walk') for the whole adjust, so pose it on this call.
	if not walking or not bool(get_meta("in_fight", false)):
		return
	if is_visible_in_tree():
		_detail = 2
	_march(0.0)


func begin_react(key: String, elapsed: float) -> void:
	if _lose_on:
		return
	var changed := key != _fight_key
	_fight_key = key
	_fight_time = elapsed
	# The movie asks for this pose on its own clock. Posing here keeps the
	# attack up even when this cog already idled earlier in the frame.
	if key != "" and bool(get_meta("in_fight", false)):
		play_attack(key, elapsed)
	elif changed and bool(get_meta("in_fight", false)):
		# A hit pose can leave the head joint wide. Idle again on the same
		# neutral frame, or that joint stays at the react.
		_idle(0.0)


## Suit.getLoseActor. The live suit hides and suit-lose-mod plays for 6 seconds.
## A Skelecog swaps in cog*_robot-lose-mod instead of the suited body.
func play_lose(elapsed: float) -> void:
	_detail = 2
	if not _lose_on and not _lose_tried:
		_start_lose()
	if not _lose_on:
		return
	var frames := int(_lose_bank.get("frames", 0))
	if frames <= 1:
		return
	var cursor := clampf(elapsed / LOSE_SECONDS, 0.0, 1.0) * float(frames - 1)
	var frame := mini(int(cursor), frames - 1)
	var following := mini(frame + 1, frames - 1)
	var fraction := cursor - float(frame)
	if following == frame:
		fraction = 0.0
	_pose_clip(_lose_bank, frame, following, fraction)
	_keep_lose_face()


func _start_lose() -> void:
	_lose_tried = true
	_lose_age = 0.0
	var skeleton := bool(_source.get("skeleton", false))
	var stem := body
	if skeleton:
		stem = "robot_%s" % body
	var packed := load("res://assets/cogs/lose/%s.glb" % stem) as PackedScene
	if packed == null:
		return
	var suit := get_node_or_null("Suit")
	var lose := packed.instantiate()
	lose.name = "LoseActor"
	add_child(lose)
	_match_lose_scale(lose, suit)
	if suit != null:
		if not skeleton:
			_dress_lose(lose, suit)
			_copy_head(lose, suit)
		suit.visible = false
	_dress_look(lose)
	_release_nametag()
	_lose_bank = _read_bank("res://assets/cogs/lose/%s.lose" % stem, lose)
	if int(_lose_bank.get("frames", 0)) <= 1:
		lose.free()
		if suit != null:
			suit.visible = true
		return
	_lose_on = true


## Suit.makeSkeleton after the lose. The v2.0 card comes off with the old suit.
func finish_revive() -> void:
	if _source.is_empty():
		return
	StreetSuits.dress_skeleton(_source)
	_source["revives"] = 0
	_revives = 0
	_laser = false
	_waiter = false
	cog_name = str(_source.get("name", "Skelecog"))
	name = cog_name
	_clear_lose()
	_attacks.clear()
	_fight_key = ""
	var previous := get_node_or_null("Suit")
	if previous != null:
		_drop_health()
		previous.free()
	var paths := _suit_paths(_source)
	_model_path = String(paths["model"])
	_apply_suit_scale(_source)
	var packed := load(_model_path) as PackedScene
	if packed == null:
		return
	var actor := packed.instantiate()
	actor.name = "Suit"
	add_child(actor)
	_materials.clear()
	_own_materials(actor)
	_paint_hands(actor)
	_quiet_shadows(actor)
	_paint_medallion(actor)
	_release_nametag()
	_add_nametag()
	_walk = _read_bank(String(paths["walk"]))
	_neutral = _read_bank(String(paths["neutral"]))
	_landing = _read_bank(String(paths["landing"]))
	if bool(get_meta("in_fight", false)):
		var maximum := maxi(_max_hp, 1)
		set_battle_hp(maximum, maximum)
	var frames := maxi(int(_neutral.get("frames", 1)), 1)
	_pose_clip(_neutral, 0, 1 % frames, 0.0)


func _clear_lose() -> void:
	_lose_on = false
	_lose_tried = false
	_lose_bank = {}
	var suit := get_node_or_null("Suit")
	if suit != null:
		suit.visible = true
	var lose := get_node_or_null("LoseActor")
	if lose != null:
		lose.free()


func _match_lose_scale(lose: Node, suit: Node) -> void:
	if suit == null:
		return
	# Suit.getLoseActor sets the lose actor to the live suit's scale. That
	# number sits on the egg under the up-axis wrapper. The wrapper itself
	# is 1, and copying it left the death model at the full body size.
	var worn := _egg_scale(suit)
	if worn < 0.05:
		return
	for child in lose.get_children():
		var part := _node3d(child)
		if part != null:
			part.scale = Vector3.ONE * worn


func _egg_scale(node: Node) -> float:
	var part := _node3d(node)
	if part != null and part.scale.x > 0.05 and absf(part.scale.x - 1.0) > 0.001:
		return part.scale.x
	for child in node.get_children():
		var nested := _egg_scale(child)
		if absf(nested - 1.0) > 0.001:
			return nested
	return 1.0


func _dress_lose(lose: Node, suit: Node) -> void:
	for part in ["torso", "arms", "legs", "hands"]:
		var src := _find(suit, part) as MeshInstance3D
		var dst := _find(lose, part) as MeshInstance3D
		if src == null or dst == null or src.mesh == null or dst.mesh == null:
			continue
		var count := mini(src.mesh.get_surface_count(), dst.mesh.get_surface_count())
		for index in count:
			var material := src.get_surface_override_material(index)
			if material == null:
				material = src.mesh.surface_get_material(index)
			if material != null:
				dst.set_surface_override_material(index, material)


func _copy_head(lose: Node, suit: Node) -> void:
	var src := _find(suit, "joint_head")
	var dst := _find(lose, "joint_head")
	if src == null or dst == null:
		return
	# Suit.getLoseActor.instanceTo(joint_head). The lose body has an empty
	# neck. The standing head, glasses included, is what blows up.
	# The fly-in propeller stays parented here after it hides. It is not a head part.
	for child in src.get_children():
		var part := _node3d(child)
		if part == null or String(part.name).begins_with("joint") or part.name == "Propeller":
			continue
		var copy := part.duplicate()
		dst.add_child(copy)
		_show_lose_face(copy)


## The head card is one-sided. A duplicate keeps the street suit's material,
## so the lose copy gets its own and draws the face from either side.
func _show_lose_face(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null:
			for index in mesh_node.mesh.get_surface_count():
				var source := mesh_node.get_surface_override_material(index)
				if source == null:
					source = mesh_node.mesh.surface_get_material(index)
				if source is BaseMaterial3D:
					var mat := (source as BaseMaterial3D).duplicate() as BaseMaterial3D
					mat.cull_mode = BaseMaterial3D.CULL_DISABLED
					mesh_node.set_surface_override_material(index, mat)
	for child in node.get_children():
		_show_lose_face(child)


## The lose joint flattens, then drops to a zero scale. That smears the face
## and then leaves a degenerate mesh. Keep the full head until it pops off.
func _keep_lose_face() -> void:
	var lose := get_node_or_null("LoseActor")
	if lose == null:
		return
	var head := _find(lose, "joint_head") as Node3D
	if head == null:
		return
	var posed := head.transform
	var amount := posed.basis.get_scale()
	var popped := amount.x < 0.05 or amount.y < 0.05 or amount.z < 0.05
	if not popped:
		posed.basis = posed.basis.orthonormalized()
		head.transform = posed
	for child in head.get_children():
		var part := _node3d(child)
		if part != null and part.name != "Propeller":
			part.visible = not popped


func defeat() -> void:
	if bool(get_meta("playback", false)):
		return
	_clear_lose()
	set_meta("in_fight", false)
	_fight_key = ""
	departed.emit()


func follow_net(state: Dictionary) -> void:
	set_meta("playback", true)
	if bool(get_meta("in_fight", false)):
		return
	if _path_ready or not bool(state.get("pathed", false)):
		return
	set_meta("net_edges", int(state.get("edges", 40)))
	_slot = posmod(int(state.get("slot", _slot)), maxi(_route.size(), 1))
	_goal = _vec(state, "goal", _goal)
	_ground = _vec(state, "ground", _ground)
	global_position = _vec(state, "position", global_position)
	_assign_path()


func _vec(state: Dictionary, key: String, fallback: Vector3) -> Vector3:
	var value: Variant = state.get(key, fallback)
	if value is Vector3:
		return value
	if value is Array:
		var row: Array = value
		if row.size() >= 3:
			return Vector3(float(row[0]), float(row[1]), float(row[2]))
	return fallback


func _node3d(value: Variant) -> Node3D:
	if value != null and is_instance_valid(value) and value is Node3D:
		return value
	return null


func _mesh3d(value: Variant) -> MeshInstance3D:
	if value != null and is_instance_valid(value) and value is MeshInstance3D:
		return value
	return null


func _bank_live(bank: Dictionary) -> bool:
	var clips: Array = bank.get("clips", [])
	if clips.is_empty():
		return true
	var record: Dictionary = clips[0]
	return _mesh3d(record.get("instance")) != null


func play_attack(key: String, elapsed: float) -> void:
	# Attack clips are loaded on demand. Street roaming does not call this.
	if _attacks.has(key) and not _bank_live(_attacks[key]):
		_attacks.erase(key)
	if not _attacks.has(key):
		var folder := body
		if bool(_source.get("skeleton", false)):
			folder = "robot_%s" % body
		_attacks[key] = _read_bank("res://assets/cogs/anims/%s/%s.walk" % [folder, key])
	var bank: Dictionary = _attacks[key]
	var frames := int(bank.get("frames", 0))
	if frames <= 1:
		return
	if is_visible_in_tree():
		_detail = 2
	var fps := _attack_fps(key)
	var time := clampf(elapsed * fps, 0.0, float(frames - 1))
	var frame := mini(int(time), frames - 1)
	var following := mini(frame + 1, frames - 1)
	var blend := 0.0 if following == frame else time - float(frame)
	_pose_clip(bank, frame, following, blend)


func _prepare_landing() -> void:
	var frames := float(maxi(_landing_frames, 1))
	var dur := frames / _landing_fps
	var air := float(GROUND_FRAME) / _landing_fps
	if air > dur:
		air = dur * 0.5
	_impact = maxf(dur - air, 0.0)
	_till_land = maxf(FROM_SKY - _impact, 0.2)
	_wait = maxf(_till_land - air, 0.0)


## DistributedSuitPlannerAI keeps a suit out for a path of 40 to 300 points.
## A short forward gap is rejected, and the suit takes the long way instead.
func _street_stay(count: int) -> int:
	if count < 2:
		return 1
	var ahead := randi_range(1, count - 1)
	var points := ahead + 1
	if points < MIN_PATH_POINTS:
		points = (count - ahead) + 1
	if points > MAX_PATH_POINTS:
		points = MAX_PATH_POINTS
	if points < 2:
		points = 2
	return points - 1


func present(cog: Dictionary, timing: Dictionary) -> void:
	_clear_lose()
	# Factory suits stand and walk in place. The street route, and the drop
	# out of the sky, belong to the street planner.
	cog_code = str(cog["code"])
	cog_name = str(cog["name"])
	dept = str(cog["dept"])
	body = str(cog["body"])
	height = float(cog["height"])
	cog_level = int(cog.get("level", 1))
	_revives = int(cog.get("revives", 0))
	_laser = bool(cog.get("laser", false))
	_waiter = bool(cog.get("waiter", false))
	name = cog_name
	_source = cog
	set_meta("factory", true)
	set_process(true)
	visible = true
	var body_timing: Dictionary = timing.get(body, {})
	_body_timing = body_timing
	var walk_info: Dictionary = body_timing.get("walk", {})
	var neutral_info: Dictionary = body_timing.get("neutral", {})
	if float(walk_info.get("fps", 0.0)) > 1.0:
		_walk_fps = float(walk_info["fps"])
	if float(neutral_info.get("fps", 0.0)) > 1.0:
		_neutral_fps = float(neutral_info["fps"])
	var mesh_path := str(cog.get("model", "res://assets/cogs/suits/%s.glb" % cog_code))
	var packed := load(mesh_path) as PackedScene
	if packed == null:
		packed = load("res://assets/cogs/suits/%s.glb" % cog_code) as PackedScene
	if packed == null:
		return
	var actor := packed.instantiate()
	actor.name = "Suit"
	add_child(actor)
	_apply_suit_scale(cog)
	if not bool(cog.get("skeleton", false)):
		_hide_sleeve_pop(actor)
	_materials.clear()
	_own_materials(actor)
	_paint_hands(actor)
	_quiet_shadows(actor)
	if bool(cog.get("skeleton", false)):
		_paint_medallion(actor)
	_dress_look(actor)
	var walk_file := str(cog.get("walk", "res://assets/cogs/anims/%s/walk.walk" % body))
	var neutral_file := str(cog.get("neutral", "res://assets/cogs/anims/%s/neutral.walk" % body))
	_walk = _read_bank(walk_file)
	_neutral = _read_bank(neutral_file)
	_release_nametag()
	_add_nametag()
	_idle(0.0)


func set_walking(moving: bool) -> void:
	set_meta("walking", moving)


## Toon.setSpeed while disguised. The suit loops walk or neutral. A street cull
## must not freeze the one the local toon is wearing.
func play_step(moving: bool, delta: float) -> void:
	set_meta("disguise", true)
	var neck := find_child("joint_head", true, false) as Node3D
	if neck != null and not has_meta("neck_rest"):
		set_meta("neck_rest", neck.transform)
	_detail = 2
	if bool(get_meta("tray", false)) and _pose_tray(moving, delta):
		pass
	elif moving:
		_march(delta)
	else:
		_idle(delta)
	# The walk clip swings joint_head. The toon head is parented there, so put
	# the neck back on the rest pose and let the body mesh do the stepping.
	if neck != null and has_meta("neck_rest"):
		neck.transform = get_meta("neck_rest")


func _process(delta: float) -> void:
	if bool(get_meta("disguise", false)):
		return
	# The death actor is posed by the battle movie. Idle would put the suit back.
	if _lose_on:
		_lose_age += delta
	if _dismissed and _can_depart():
		_drop_defeated()
		return
	if _lose_on:
		return
	if bool(get_meta("in_fight", false)):
		_tick_health(delta)
		if _fight_key == "walk":
			if is_visible_in_tree():
				_detail = 2
			_march(delta)
		elif _fight_key != "":
			play_attack(_fight_key, _fight_time)
		else:
			_idle(delta)
		return
	if bool(get_meta("factory", false)):
		if _phase == 2:
			_fly_out(delta)
			return
		# Same pose budget as a street suit. A cog in a stashed room, or one
		# you are not looking at, keeps its place without a new mesh.
		_detail = _camera_detail()
		if _detail == 0:
			if bool(get_meta("walking", false)):
				_walk_time = fposmod(_walk_time + delta * _walk_fps, float(maxi(int(_walk.get("frames", 1)), 1)))
			else:
				_idle_time = fposmod(_idle_time + delta * _neutral_fps, float(maxi(int(_neutral.get("frames", 1)), 1)))
			return
		if bool(get_meta("walking", false)):
			_march(delta)
		else:
			_idle(delta)
		return
	if _points.is_empty():
		return
	_detail = _camera_detail()
	if _phase == 3:
		_enter_building(delta)
		return
	if _phase == 0:
		if _from_building:
			_leave_building(delta)
		else:
			_fly_in(delta)
	elif _phase == 1:
		_roam(delta)
	else:
		_fly_out(delta)


static func exit_span(door: Vector3, street: Vector3) -> Dictionary:
	var delta := street - door
	delta.y = 0.0
	var length := delta.length()
	if length < 0.05:
		return {"start": door, "end": door, "yaw": 0.0}
	var flat := delta / length
	var outside := door + flat * STAND_OUTSIDE
	var start := outside - flat * (WALK_SPEED * FROM_BUILDING)
	start.y = door.y
	outside.y = door.y
	return {"start": start, "end": outside, "yaw": atan2(-flat.x, -flat.z)}


func _begin_exit(resume: Dictionary) -> void:
	_from_building = true
	_building_suit = true
	set_meta("building_suit", true)
	_phase = 0
	_fly = float(resume.get("fly", 0.0))
	_door = _vec(resume, "door", Vector3.ZERO)
	_exit = _vec(resume, "exit", _door)
	var span := exit_span(_door, _exit)
	var start: Vector3 = span["start"]
	_ground = span["end"]
	_goal = _ground
	global_position = _vec(resume, "position", start)
	rotation.y = float(resume.get("yaw", span["yaw"]))
	_set_alpha(1.0)
	_detach_propeller()
	_pose_elapsed(_walk, 0.0, _walk_fps, true)


func _leave_building(delta: float) -> void:
	_fly += delta
	var span := exit_span(_door, _exit)
	var start: Vector3 = span["start"]
	var outside: Vector3 = span["end"]
	global_position = start.lerp(outside, clampf(_fly / FROM_BUILDING, 0.0, 1.0))
	rotation.y = float(span["yaw"])
	_march(delta)
	if _fly < FROM_BUILDING:
		return
	_from_building = false
	_phase = 1
	_ground = outside
	global_position = outside
	_assign_path()


func _fly_in(delta: float) -> void:
	_fly += delta
	var fade := clampf(_fly, 0.0, 1.0)
	_set_alpha(fade)
	if _fly < _till_land:
		var along := _fly / _till_land
		global_position = _ground + Vector3(0.0, SKY_HEIGHT * (1.0 - along), 0.0)
	else:
		global_position = _ground
	if _fly < _wait:
		_pose_clip(_landing, 0, 0, 0.0)
	else:
		_pose_elapsed(_landing, _fly - _wait, _landing_fps, false)
	_spin_propeller(delta, true)
	if _fly >= FROM_SKY:
		_detach_propeller()
		_assign_path()
		_phase = 1
		_pose_elapsed(_walk, 0.0, _walk_fps, true)


func _fly_out(delta: float) -> void:
	_fly += delta
	# The fade is the last second of the climb. Fading on the first second
	# hid the suit before it left the sidewalk.
	_set_alpha(_fly_out_alpha())
	var dur := float(maxi(_landing_frames, 1)) / _landing_fps
	_pose_elapsed(_landing, dur - _fly, _landing_fps, false)
	if _fly < _impact:
		global_position = _ground
	else:
		var along := clampf((_fly - _impact) / _till_land, 0.0, 1.0)
		global_position = _ground + Vector3(0.0, SKY_HEIGHT * along, 0.0)
	_spin_propeller(delta, false)
	if _fly >= FROM_SKY:
		_detach_propeller()
		departed.emit()
		if bool(get_meta("pooled", false)):
			set_meta("pooled", false)
			return
		queue_free()


func lane_slot() -> int:
	return _slot


func on_lane() -> bool:
	# A suit in a battle has left the sidewalk. Counting it as still walking
	# makes every cog behind it idle until the fight ends.
	if bool(get_meta("in_fight", false)):
		return false
	if bool(get_meta("factory", false)):
		return true
	return _phase == 1


func _roam(delta: float) -> void:
	if bool(get_meta("playback", false)) and not _path_ready:
		_idle(delta)
		return
	if _take_stage == "door":
		_walk_door(delta)
		return
	if _take_stage == "inside":
		_idle(delta)
		return
	if _route.size() < 2:
		_begin_fly_out()
		return
	# The goal is always the next point on the right-hand loop. A saved goal
	# from another visit must not pull the suit across the street.
	_goal = _points[_route[(_slot + 1) % _route.size()]]
	_snap_to_lane()
	var flat := Vector2(global_position.x, global_position.z)
	var target := Vector2(_goal.x, _goal.z)
	var remaining := flat.distance_to(target)
	# Suits walk through each other. Waiting on the suit ahead closed the
	# lane into a circle, so a finished suit never reached its takeoff.
	if remaining < 0.08:
		global_position = _goal
		_slot = (_slot + 1) % _route.size()
		_edges_left -= 1
		if _edges_left <= 0:
			if not _take.is_empty():
				_begin_door()
			elif _building_suit and _return_door.length_squared() > 1.0 and _door_still_cog():
				_begin_enter()
			else:
				_begin_fly_out()
			return
		_step_lane()
		return
	var step := minf(WALK_SPEED * delta, remaining)
	var toward := (target - flat) / remaining
	global_position.x += toward.x * step
	global_position.z += toward.y * step
	var origin := _points[_route[_slot]]
	var span := Vector2(origin.x, origin.z).distance_to(target)
	if span > 0.001:
		global_position.y = lerpf(origin.y, _goal.y, 1.0 - remaining / span)
	_face(toward)
	_walk_time = fposmod(_walk_time + delta * _walk_fps, float(maxi(int(_walk.get("frames", 1)), 1)))
	var frames := int(_walk.get("frames", 1))
	if frames > 1:
		var frame := int(_walk_time)
		if frame >= frames:
			frame = 0
		var blend := _walk_time - float(frame)
		_pose_clip(_walk, frame, (frame + 1) % frames, blend)
	else:
		_idle(delta)


## Drop the suit back onto the segment it is supposed to be walking.
func _snap_to_lane() -> void:
	var origin := _points[_route[_slot]]
	var start := Vector2(origin.x, origin.z)
	var end := Vector2(_goal.x, _goal.z)
	var here := Vector2(global_position.x, global_position.z)
	var edge := end - start
	var length := edge.length_squared()
	var along := 0.0
	if length > 0.0001:
		along = clampf((here - start).dot(edge) / length, 0.0, 1.0)
	var on_path := start.lerp(end, along)
	if here.distance_squared_to(on_path) > 0.12:
		global_position.x = on_path.x
		global_position.z = on_path.y
	global_position.y = lerpf(origin.y, _goal.y, along)


func _door_still_cog() -> bool:
	if _return_block < 0:
		return true
	var suits := get_parent()
	if suits == null:
		return true
	var street := suits.get_parent()
	if street == null:
		return true
	var buildings := street.get_node_or_null("StreetBuildings")
	if buildings == null or not buildings.has_method("block_taken"):
		return true
	return bool(buildings.call("block_taken", _return_block))


func _begin_enter() -> void:
	_phase = 3
	_fly = 0.0
	_enter_from = global_position
	_path_ready = true


func _enter_building(delta: float) -> void:
	_fly += delta
	var start := _enter_from
	var door := _return_door
	var flat := Vector2(start.x, start.z)
	var target := Vector2(door.x, door.z)
	var dist := flat.distance_to(target)
	var dur := maxf(dist / WALK_SPEED, 0.35)
	var along := clampf(_fly / dur, 0.0, 1.0)
	global_position = start.lerp(door, along)
	var toward := target - flat
	if toward.length_squared() > 0.0001:
		_face(toward.normalized())
	_walk_time = fposmod(_walk_time + delta * _walk_fps, float(maxi(int(_walk.get("frames", 1)), 1)))
	var frames := int(_walk.get("frames", 1))
	if frames > 1:
		var frame := int(_walk_time)
		if frame >= frames:
			frame = 0
		var blend := _walk_time - float(frame)
		_pose_clip(_walk, frame, (frame + 1) % frames, blend)
	if _fly < dur:
		return
	departed.emit()
	if bool(get_meta("pooled", false)):
		set_meta("pooled", false)
		return
	queue_free()


## The suit is leaving the street. Rise on the propeller instead of popping out.
func fly_away() -> bool:
	if bool(get_meta("in_fight", false)) or _lose_on:
		_dismissed = true
		return true
	if _phase == 2 or _phase == 3:
		return true
	set_meta("flying", true)
	_begin_fly_out()
	return true


func _can_depart() -> bool:
	if _lose_on:
		return _lose_age >= LOSE_SECONDS
	return not bool(get_meta("in_fight", false))


func _drop_defeated() -> void:
	_dismissed = false
	set_meta("in_fight", false)
	departed.emit()
	if bool(get_meta("pooled", false)):
		set_meta("pooled", false)
		visible = false
		set_process(false)
		return
	queue_free()


func _fly_out_alpha() -> float:
	var fade_start := maxf(FROM_SKY - 1.0, 0.0)
	if _fly <= fade_start:
		return 1.0
	return 1.0 - clampf(_fly - fade_start, 0.0, 1.0)


func _begin_fly_out() -> void:
	# A second call was restarting the takeoff, so the suit played the
	# landing backwards from the top over and over.
	if _phase == 2:
		return
	if int(_landing.get("frames", 0)) <= 1:
		var paths := _suit_paths(_source)
		_landing = _read_bank(String(paths["landing"]))
		if int(_landing.get("frames", 0)) > 1:
			_landing_frames = int(_landing["frames"])
		_prepare_landing()
	_phase = 2
	_fly = 0.0
	_ground = global_position
	_set_alpha(1.0)
	_attach_propeller()
	_play_propeller(false)


func _read_take(resume: Dictionary) -> void:
	var found: Variant = resume.get("takeover", {})
	if not (found is Dictionary) or (found as Dictionary).is_empty():
		found = get_meta("takeover", {})
	_take = found if found is Dictionary else {}
	if _take.is_empty():
		_take_stage = ""
		return
	_take_stage = String(resume.get("take_stage", "lane"))


func _begin_door() -> void:
	_take_stage = "door"
	_door_goal = _TRAFFIC.stand_outside(global_position, _TRAFFIC.read_pos(_take.get("pos", [])))
	_goal = _door_goal


func _walk_door(delta: float) -> void:
	var flat := Vector2(global_position.x, global_position.z)
	var target := Vector2(_door_goal.x, _door_goal.z)
	var remaining := flat.distance_to(target)
	if remaining < 0.08:
		global_position = _door_goal
		_arrive_door()
		return
	var step := minf(WALK_SPEED * delta, remaining)
	var toward := (target - flat) / remaining
	global_position.x += toward.x * step
	global_position.z += toward.y * step
	global_position.y = lerpf(global_position.y, _door_goal.y, step / remaining)
	_face(toward)
	_walk_time = fposmod(_walk_time + delta * _walk_fps, float(maxi(int(_walk.get("frames", 1)), 1)))
	var frames := int(_walk.get("frames", 1))
	if frames > 1:
		var frame := int(_walk_time)
		if frame >= frames:
			frame = 0
		_pose_clip(_walk, frame, (frame + 1) % frames, _walk_time - float(frame))
	else:
		_idle(delta)


func _arrive_door() -> void:
	if _take_stage == "inside":
		return
	_take_stage = "inside"
	if bool(get_meta("playback", false)):
		return
	var host := get_parent()
	if host != null and host.has_method("finish_takeover"):
		host.call("finish_takeover", _take)
	departed.emit()


func retire() -> void:
	visible = false
	set_process(false)
	if _sound != null:
		_sound.stop()
	_detach_propeller()
	_release_nametag()


func _give_up() -> void:
	set_meta("discard", true)
	departed.emit()
	queue_free()


## The route is already the right-hand loop. The next point is always forward.
## DistributedSuitPlannerAI chooses that path before the suit is generated.
## Here it waits until the landing, so a suit still in the sky does not
## search the street graph.
func _assign_path() -> void:
	if _path_ready:
		_step_lane()
		return
	if bool(get_meta("playback", false)):
		var given := int(get_meta("net_edges", -1))
		if given < 0:
			return
		_path_ready = true
		_edges_left = given
		_step_lane()
		return
	_path_ready = true
	_edges_left = _street_stay(_route.size())
	if not _take.is_empty():
		var door_slot := _TRAFFIC.nearest_route(_points, _route, _TRAFFIC.read_pos(_take.get("pos", [])))
		_edges_left = _TRAFFIC.door_steps(_slot, door_slot, _route.size())
		_take_stage = "lane"
	elif _building_suit and _return_exit.length_squared() > 1.0:
		var back_slot := _TRAFFIC.nearest_route(_points, _route, _return_exit)
		_edges_left = _TRAFFIC.door_steps(_slot, back_slot, _route.size())
	_step_lane()


func _step_lane() -> void:
	if _route.size() < 2:
		_begin_fly_out()
		return
	var nxt := (_slot + 1) % _route.size()
	_goal = _points[_route[nxt]]
	var toward := Vector2(_goal.x - global_position.x, _goal.z - global_position.z)
	if toward.length_squared() > 0.0001:
		_face(toward.normalized())


func _face(toward: Vector2) -> void:
	# Heading 0 faces -Z, matching the tutorial suit.
	rotation.y = atan2(-toward.x, -toward.y)


func _pose_tray(moving: bool, delta: float) -> bool:
	var clip := "tray_walk" if moving else "tray_neutral"
	var path := "res://assets/cogs/anims/%s/%s.walk" % [body, clip]
	if not FileAccess.file_exists(path):
		return false
	if not _tray_banks.has(path):
		var loaded: Variant = _read_bank(path)
		if loaded is Dictionary:
			_tray_banks[path] = loaded
	var bank: Dictionary = _tray_banks.get(path, {})
	if int(bank.get("frames", 0)) <= 1:
		return false
	_tray_time += delta
	_pose_elapsed(bank, _tray_time, 24.0, true)
	return true


func _march(delta: float) -> void:
	var frames := int(_walk.get("frames", 1))
	if frames <= 1:
		_idle(delta)
		return
	_walk_time = fposmod(_walk_time + delta * _walk_fps, float(frames))
	var frame := int(_walk_time)
	if frame >= frames:
		frame = 0
	_pose_clip(_walk, frame, (frame + 1) % frames, _walk_time - float(frame))


func _idle(delta: float) -> void:
	var frames := int(_neutral.get("frames", 1))
	if frames <= 1:
		return
	_idle_time = fposmod(_idle_time + delta * _neutral_fps, float(frames))
	var frame := int(_idle_time)
	if frame >= frames:
		frame = 0
	var blend := _idle_time - float(frame)
	_pose_clip(_neutral, frame, (frame + 1) % frames, blend)


func _pose_elapsed(bank: Dictionary, elapsed: float, fps: float, looping: bool) -> void:
	var frames := int(bank.get("frames", 0))
	if frames <= 1:
		_idle(0.0)
		return
	var span := float(frames) / fps
	var time := elapsed
	if looping:
		time = fposmod(elapsed, span)
	else:
		time = clampf(elapsed, 0.0, span)
	var cursor := time * fps
	var frame := mini(int(cursor), frames - 1)
	var following := frame
	if looping:
		following = (frame + 1) % frames
	else:
		following = mini(frame + 1, frames - 1)
	var blend := 0.0 if following == frame else cursor - float(frame)
	_pose_clip(bank, frame, following, blend)


func _release_nametag() -> void:
	var board := get_parent().get_node_or_null("Nametags") if get_parent() != null else null
	if board != null and board.has_method("release"):
		board.call("release", self)


func _add_nametag() -> void:
	var board := get_parent().get_node_or_null("Nametags")
	if board == null or not board.has_method("add"):
		return
	var dept_name := str(_DEPT_NAMES.get(dept, "Bossbot"))
	var level_text := "Level %d" % cog_level
	if _revives > 0:
		level_text += " v2.0"
	# SuitBaseNameWithLevel: name, department, level, on the translucent suit card.
	board.call("add", self, "%s\n%s\n%s" % [cog_name, dept_name, level_text], "cog")


func _attach_propeller() -> void:
	if _propeller != null:
		_propeller.visible = true
		return
	var packed := load("res://assets/cogs/props/propeller.glb") as PackedScene
	if packed == null:
		return
	var head := _find(self, "joint_head") as Node3D
	if head == null:
		return
	_propeller = packed.instantiate() as Node3D
	_propeller.name = "Propeller"
	head.add_child(_propeller)
	_own_materials(_propeller)
	_prop_bank = _read_bank("res://assets/cogs/props/propeller.walk", _propeller)


func _detach_propeller() -> void:
	if _sound != null:
		_sound.stop()
	if _propeller != null:
		_propeller.visible = false


func _play_propeller(inbound: bool) -> void:
	var file := "ENC_propeller_in.ogg" if inbound else "ENC_propeller_out.ogg"
	var path := "res://assets/cogs/audio/" + file
	if not FileAccess.file_exists(path):
		return
	if _sound == null:
		_sound = ToonAudio.effect_3d()
		_sound.name = "PropellerSound"
		_sound.unit_size = 25.0
		add_child(_sound)
	_sound.stream = load(path)
	_sound.play()


func _spin_propeller(delta: float, inbound: bool) -> void:
	if _propeller == null:
		return
	var frames := int(_prop_bank.get("frames", 0))
	if frames <= 1:
		_propeller.rotate_object_local(Vector3(0, 0, 1), delta * 28.0)
		return
	_prop_time += delta
	var spin_end := 8
	if inbound:
		var loop_span := float(mini(spin_end, frames - 1) + 1)
		var spin := fposmod(_prop_time * _prop_fps, loop_span)
		if _fly > _wait:
			spin = clampf(_wait * _prop_fps + (_fly - _wait) * _prop_fps, 0.0, float(frames - 1))
		var frame := mini(int(spin), frames - 1)
		var following := (frame + 1) % frames
		if _fly <= _wait:
			following = (frame + 1) % int(loop_span)
		var blend := spin - float(frame)
		_pose_clip(_prop_bank, frame, following, blend)
	else:
		var cursor := float(frames - 1) - _prop_time * _prop_fps
		cursor = clampf(cursor, 0.0, float(frames - 1))
		var frame := mini(int(cursor), frames - 1)
		var following := mini(frame + 1, frames - 1)
		var blend := cursor - float(frame)
		_pose_clip(_prop_bank, frame, following, blend)


func _set_alpha(alpha: float) -> void:
	_fade_node(self, clampf(alpha, 0.0, 1.0))


func _fade_node(node: Node, shown: float) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var mesh := mesh_node.mesh
		if mesh != null:
			for index in mesh.get_surface_count():
				_fade_material(mesh.surface_get_material(index), shown)
				_fade_material(mesh_node.get_surface_override_material(index), shown)
	for child in node.get_children():
		_fade_node(child, shown)


func _fade_material(material: Material, shown: float) -> void:
	if not (material is ShaderMaterial):
		return
	var shader := material as ShaderMaterial
	var tint: Variant = shader.get_shader_parameter("albedo_color")
	var color := Color.WHITE
	if tint is Color:
		color = tint
	color.a = shown
	shader.set_shader_parameter("albedo_color", color)


func _own_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh_node.mesh != null:
			for index in mesh_node.mesh.get_surface_count():
				var source := mesh_node.get_surface_override_material(index)
				if source == null:
					source = mesh_node.mesh.surface_get_material(index)
				if source is BaseMaterial3D:
					var copy := _shade_material(source as BaseMaterial3D)
					mesh_node.set_surface_override_material(index, copy)
					_materials.append(copy)
				elif source is ShaderMaterial:
					mesh_node.set_surface_override_material(index, source)
					_materials.append(source)
	for child in node.get_children():
		_own_materials(child)


func _shade_material(source: BaseMaterial3D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _SHADE
	material.set_shader_parameter("albedo_color", source.albedo_color)
	var textured := source.albedo_texture != null
	material.set_shader_parameter("use_albedo_texture", 1.0 if textured else 0.0)
	if textured:
		material.set_shader_parameter("albedo_texture", source.albedo_texture)
	var cut := 0.0
	if source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR or source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_HASH:
		cut = source.alpha_scissor_threshold if source.alpha_scissor_threshold > 0.01 else 0.5
	material.set_shader_parameter("cutout", cut)
	material.set_shader_parameter("use_vertex_color", 1.0 if source.vertex_color_use_as_albedo else 0.0)
	return material


## The exported glove still carries hand.png. That picture is what draws the white
## chips across the fingers. The original geom turns the texture off and tints the mesh.
func _paint_hands(actor: Node) -> void:
	var tint := _CORP_HAND
	if _HAND_COLOR.has(cog_code):
		tint = _HAND_COLOR[cog_code] as Color
	_paint_hand_node(actor, tint)


func _paint_hand_node(node: Node, tint: Color) -> void:
	if node is MeshInstance3D and str(node.name) == "hands":
		var mesh_node := node as MeshInstance3D
		var count := 0
		if mesh_node.mesh != null:
			count = mesh_node.mesh.get_surface_count()
		for index in count:
			var material := mesh_node.get_surface_override_material(index) as ShaderMaterial
			if material == null:
				continue
			material.set_shader_parameter("use_albedo_texture", 0.0)
			material.set_shader_parameter("use_vertex_color", 0.0)
			material.set_shader_parameter("albedo_color", tint)
	for child in node.get_children():
		_paint_hand_node(child, tint)


## Laser is a skelecog drawn as red light. A waiter keeps the cog and wears
## the white suit from phase_3.5/maps/waiter_m_*.png.
func _dress_look(actor: Node) -> void:
	if _laser:
		_paint_laser(actor)
	elif _waiter:
		_paint_waiter(actor)


func _paint_laser(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if not str(mesh_node.name).to_lower().contains("shadow") and mesh_node.mesh != null:
			for index in mesh_node.mesh.get_surface_count():
				var material := mesh_node.get_surface_override_material(index) as ShaderMaterial
				if material == null:
					var source := mesh_node.mesh.surface_get_material(index)
					if source is BaseMaterial3D:
						material = _shade_material(source as BaseMaterial3D)
						mesh_node.set_surface_override_material(index, material)
				if material == null:
					continue
				var tint: Variant = material.get_shader_parameter("albedo_color")
				var color := Color(1, 0, 0, 1)
				if tint is Color:
					color = tint
					color.r = 1.0
					color.g = 0.0
					color.b = 0.0
				material.shader = _LASER
				material.set_shader_parameter("albedo_color", color)
	for child in node.get_children():
		_paint_laser(child)


func _paint_waiter(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var cloth := _waiter_texture(str(mesh_node.name))
		if cloth != null and mesh_node.mesh != null:
			for index in mesh_node.mesh.get_surface_count():
				var material := mesh_node.get_surface_override_material(index) as ShaderMaterial
				if material == null:
					var source := mesh_node.mesh.surface_get_material(index)
					if source is BaseMaterial3D:
						material = _shade_material(source as BaseMaterial3D)
						mesh_node.set_surface_override_material(index, material)
				if material == null:
					continue
				material.set_shader_parameter("albedo_texture", cloth)
				material.set_shader_parameter("use_albedo_texture", 1.0)
	for child in node.get_children():
		_paint_waiter(child)


func _waiter_texture(part: String) -> Texture2D:
	var path := ""
	match part:
		"torso":
			path = _WAITER_BLAZER
		"arms":
			path = _WAITER_SLEEVE
		"legs":
			path = _WAITER_LEG
	if path == "":
		return null
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _quiet_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_quiet_shadows(child)


func _suit_paths(cog: Dictionary) -> Dictionary:
	var code := str(cog.get("code", ""))
	var suit_body := str(cog.get("body", "c"))
	return {
		"model": str(cog.get("model", "res://assets/cogs/suits/%s.glb" % code)),
		"walk": str(cog.get("walk", "res://assets/cogs/anims/%s/walk.walk" % suit_body)),
		"neutral": str(cog.get("neutral", "res://assets/cogs/anims/%s/neutral.walk" % suit_body)),
		"landing": str(cog.get("landing", "res://assets/cogs/anims/%s/landing.walk" % suit_body)),
	}


## Suit.generateCorporateMedallion. The robot export wears a Sellbot badge.
func _paint_medallion(actor: Node) -> void:
	var icon := _find_named(actor, "Icon")
	if icon == null or icon.mesh == null:
		return
	var texture: Texture2D = _MEDALLION.get(dept, _CORP_ICON)
	var color := Cog.medallion_color(dept)
	for index in icon.mesh.get_surface_count():
		var material := icon.get_surface_override_material(index) as ShaderMaterial
		if material == null:
			continue
		material.set_shader_parameter("albedo_texture", texture)
		material.set_shader_parameter("use_albedo_texture", 1.0)
		material.set_shader_parameter("albedo_color", color)


func _find_named(node: Node, tail: String) -> MeshInstance3D:
	if node is MeshInstance3D and str(node.name).ends_with(tail):
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_named(child, tail)
		if found != null:
			return found
	return null

## Both wrists carry a white shirt cuff into the sleeve, and a flat gray
## lining that sits on the pinstripe. The cuffs stay. The linings go. The
## black ring at the neck stays. Clips for these bodies drop the same
## surfaces, so the pose swap still lines materials up with the standing mesh.
func _hide_sleeve_pop(actor: Node) -> void:
	var suit := _find(actor, "node") as MeshInstance3D
	if suit == null or suit.mesh == null:
		return
	var drop: Array[int] = []
	for index in suit.mesh.get_surface_count():
		var arrays := suit.mesh.surface_get_arrays(index)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var material := suit.mesh.surface_get_material(index) as BaseMaterial3D
		var textured := material != null and material.albedo_texture != null
		if not textured and verts.size() > 9:
			drop.append(index)
	if drop.is_empty():
		return
	var kept := ArrayMesh.new()
	for index in suit.mesh.get_surface_count():
		if drop.has(index):
			continue
		var kept_arrays := suit.mesh.surface_get_arrays(index)
		kept.add_surface_from_arrays(suit.mesh.surface_get_primitive_type(index), kept_arrays)
		kept.surface_set_material(kept.get_surface_count() - 1, suit.mesh.surface_get_material(index))
	suit.mesh = kept


static func _drops_sleeve_pop(path: String) -> bool:
	return path.contains("/anims/a/") or path.contains("/anims/b/") or path.contains("/anims/c/")


func _pose_clip(bank: Dictionary, frame: int, following: int, blend: float) -> void:
	if _detail == 0:
		bank["shown"] = -1
		return
	# A visible suit blends. The in-between pose is a shader mix, so the
	# street does not rewrite a vertex buffer on every display frame.
	var fraction := clampf(blend, 0.0, 1.0)
	var show := int(bank.get("shown", -1)) != frame
	if show:
		bank["shown"] = frame
	var clips: Array = bank.get("clips", [])
	for item in clips:
		var record: Dictionary = item
		var instance := _mesh3d(record.get("instance"))
		if instance == null:
			continue
		var posed := _frame_mesh(record, frame)
		if posed == null:
			continue
		var shown := posed
		var amount := 0.0
		if fraction > 0.001 and following != frame:
			var mixed := _blend_mesh(record, frame, following)
			if mixed != null:
				shown = mixed
				amount = fraction
		if instance.mesh != shown:
			instance.mesh = shown
			show = true
		_set_pose_blend(record.get("overrides", []), amount)
		if not show:
			continue
		_apply_overrides(instance, shown, record.get("overrides", []))
	var joints: Array = bank.get("joints", [])
	for item in joints:
		var record: Dictionary = item
		var joint := _node3d(record.get("node"))
		if joint == null:
			continue
		var frames: Array = record["frames"]
		if frames.is_empty():
			continue
		var posed_frame := _joint_at(record, frame)
		if fraction > 0.001:
			var nxt := _joint_at(record, following)
			posed_frame.origin = posed_frame.origin.lerp(nxt.origin, fraction)
			posed_frame.basis = _blend_basis(posed_frame.basis, nxt.basis, fraction)
		var stamp := frame * 1000 + int(fraction * 20.0)
		# The stamp only means this clip already wrote this pose. A hit clip
		# writes the same joint in between, and skipping here left that pose on.
		if int(record.get("pose_id", 0)) == 0:
			_pose_seq += 1
			record["pose_id"] = _pose_seq
		var pose_id := int(record["pose_id"])
		if int(record.get("stamp", -1)) == stamp and int(joint.get_meta("pose_owner", 0)) == pose_id:
			continue
		record["stamp"] = stamp
		joint.set_meta("pose_owner", pose_id)
		# The clip stores the joint in the same space as the posed body.
		# The head stays on the neck when that matrix is used as the pose.
		joint.transform = posed_frame


func _frame_mesh(record: Dictionary, frame: int) -> ArrayMesh:
	var poses: Array = record.get("poses", [])
	if frame < 0 or frame >= poses.size():
		return null
	var slot: Variant = poses[frame]
	if slot is ArrayMesh:
		return slot as ArrayMesh
	var source: Dictionary = record.get("source", {})
	return _ensure_pose(source, frame)


func _blend_mesh(record: Dictionary, frame: int, following: int) -> ArrayMesh:
	var source: Dictionary = record.get("source", {})
	var cache: Dictionary = source.get("blend_meshes", {})
	var pair := frame * 10000 + following
	var cached: ArrayMesh = cache.get(pair) as ArrayMesh
	if cached != null and cached.get_surface_count() > 0:
		return cached
	var first := _frame_mesh(record, frame)
	var second := _frame_mesh(record, following)
	if first == null or second == null or first.get_surface_count() != second.get_surface_count():
		return null
	var blended := ArrayMesh.new()
	for index in first.get_surface_count():
		var left: Array = first.surface_get_arrays(index)
		var right: Array = second.surface_get_arrays(index)
		var vertex_slot: Variant = left[Mesh.ARRAY_VERTEX]
		var next_slot: Variant = right[Mesh.ARRAY_VERTEX]
		if not (vertex_slot is PackedVector3Array) or not (next_slot is PackedVector3Array):
			return null
		var positions: PackedVector3Array = vertex_slot
		var next_positions: PackedVector3Array = next_slot
		if positions.size() != next_positions.size() or positions.is_empty():
			return null
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = positions
		var normal_slot: Variant = left[Mesh.ARRAY_NORMAL]
		if normal_slot is PackedVector3Array:
			var normals: PackedVector3Array = normal_slot
			if normals.size() == positions.size():
				arrays[Mesh.ARRAY_NORMAL] = normals
		var uv_slot: Variant = left[Mesh.ARRAY_TEX_UV]
		if uv_slot is PackedVector2Array:
			var uvs: PackedVector2Array = uv_slot
			if uvs.size() == positions.size():
				arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_CUSTOM0] = _custom_rgba(next_positions)
		var next_normal_slot: Variant = right[Mesh.ARRAY_NORMAL]
		if next_normal_slot is PackedVector3Array:
			var next_normals: PackedVector3Array = next_normal_slot
			if next_normals.size() == positions.size():
				arrays[Mesh.ARRAY_TANGENT] = _tangents_from_vec3(next_normals)
		var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		blended.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	cache[pair] = blended
	source["blend_meshes"] = cache
	return blended


func _apply_overrides(instance: MeshInstance3D, posed: ArrayMesh, overrides: Array) -> void:
	for index in overrides.size():
		var material := overrides[index] as Material
		if material != null and index < posed.get_surface_count():
			instance.set_surface_override_material(index, material)


func _set_pose_blend(overrides: Array, amount: float) -> void:
	for item in overrides:
		var material := item as ShaderMaterial
		if material != null:
			material.set_shader_parameter("pose_blend", amount)


static func _custom_rgba(points: PackedVector3Array) -> PackedFloat32Array:
	var packed := PackedFloat32Array()
	packed.resize(points.size() * 4)
	var at := 0
	for point in points:
		packed[at] = point.x
		packed[at + 1] = point.y
		packed[at + 2] = point.z
		packed[at + 3] = 0.0
		at += 4
	return packed


static func _tangents_from_vec3(normals: PackedVector3Array) -> PackedFloat32Array:
	var packed := PackedFloat32Array()
	packed.resize(normals.size() * 4)
	var at := 0
	for normal in normals:
		packed[at] = normal.x
		packed[at + 1] = normal.y
		packed[at + 2] = normal.z
		packed[at + 3] = 1.0
		at += 4
	return packed


func _camera_detail() -> int:
	if _block_hidden():
		return 0
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 2
	var chest := global_position + Vector3(0.0, height * 0.45, 0.0)
	var dist2 := chest.distance_squared_to(cam.global_position)
	# Off-screen suits hold their last pose. Every suit you can see blends.
	if dist2 > 16.0 * 16.0 and cam.is_position_behind(chest) and not cam.is_position_in_frustum(chest):
		return 0
	return 2


## A suit on a stashed block stays on its path, but it does not draw or animate.
func _block_hidden() -> bool:
	var suits := get_parent()
	if suits == null:
		return false
	var street := suits.get_parent()
	if street == null or not street.has_method("zone_visible_at"):
		visible = true
		return false
	var tick := Engine.get_process_frames()
	if tick % 8 != int(get_instance_id()) % 8 and has_meta("zone_hide"):
		var cached := bool(get_meta("zone_hide"))
		visible = not cached
		return cached
	var hidden := not bool(street.call("zone_visible_at", global_position))
	set_meta("zone_hide", hidden)
	visible = not hidden
	return hidden


func _attack_fps(key: String) -> float:
	var info: Dictionary = _body_timing.get(key, {})
	var fps := float(info.get("fps", 0.0))
	if fps > 1.0:
		return fps
	return _walk_fps


static func _face_normals(positions: PackedVector3Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(positions.size())
	var index := 0
	while index + 2 < positions.size():
		var edge_a := positions[index + 1] - positions[index]
		var edge_b := positions[index + 2] - positions[index]
		var normal := edge_a.cross(edge_b)
		if normal.length_squared() < 0.000001:
			normal = Vector3.UP
		else:
			normal = normal.normalized()
		normals[index] = normal
		normals[index + 1] = normal
		normals[index + 2] = normal
		index += 3
	return normals


static func _smooth_normals(positions: PackedVector3Array) -> PackedVector3Array:
	var flat := _face_normals(positions)
	var normals := PackedVector3Array()
	normals.resize(positions.size())
	var groups: Dictionary = {}
	for index in positions.size():
		var point := positions[index]
		var key := Vector3i(int(round(point.x * 1000.0)), int(round(point.y * 1000.0)), int(round(point.z * 1000.0)))
		var ids := PackedInt32Array()
		if groups.has(key):
			ids = groups[key]
		ids.append(index)
		groups[key] = ids
	for key in groups:
		var ids := groups[key] as PackedInt32Array
		var sum := Vector3.ZERO
		for index in ids:
			sum += flat[index]
		if sum.length_squared() < 0.000001:
			sum = Vector3.UP
		else:
			sum = sum.normalized()
		for index in ids:
			normals[index] = sum
	return normals


static func index_next() -> bool:
	if _index_cursor >= _INDEX_PATHS.size():
		return false
	var path := _INDEX_PATHS[_index_cursor]
	_index_cursor += 1
	if not _clip_files.has(path):
		_clip_files[path] = _parse_clip(path)
	return true


## One missing pose across every clip already opened. The street calls this
## between spawns so a landing never builds its whole clip on the frame it appears.
static func bake_one() -> bool:
	if _bake_done:
		return false
	for path in _clip_files.keys():
		var parsed: Dictionary = _clip_files[path]
		var nodes: Array = parsed.get("nodes", [])
		for item in nodes:
			if not (item is Dictionary):
				continue
			var node: Dictionary = item
			var poses: Array = node.get("poses", [])
			for frame in poses.size():
				if poses[frame] is ArrayMesh:
					continue
				_ensure_pose(node, frame)
				return true
	_bake_done = true
	return false


func _read_bank(path: String, root: Node = null) -> Dictionary:
	if not _clip_files.has(path):
		_clip_files[path] = _parse_clip(path)
	var search: Node = self if root == null else root
	return _bind_clip(_clip_files[path], search)


static func _parse_clip(path: String) -> Dictionary:
	_bake_done = false
	var nodes: Array = []
	var joints: Array = []
	var empty := {"nodes": nodes, "joints": joints, "frames": 0}
	if not FileAccess.file_exists(path):
		return empty
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 16 or bytes.slice(0, 6).get_string_from_ascii() != "TWALK3":
		return empty
	var at := 8
	var frame_count := bytes.decode_u32(at)
	at += 4
	var node_count := bytes.decode_u32(at)
	at += 4
	for _node_index in node_count:
		var name_len := bytes.decode_u16(at)
		at += 2
		var node_name := bytes.slice(at, at + name_len).get_string_from_utf8()
		at += name_len
		var surface_count := bytes.decode_u32(at)
		at += 4
		var drop_pop := _drops_sleeve_pop(path) and node_name == "node"
		var surfaces: Array = []
		for _surface_index in surface_count:
			var vertex_count := bytes.decode_u32(at)
			at += 4
			var has_uv := bytes.decode_u8(at)
			at += 1
			var uvs := PackedVector2Array()
			if has_uv != 0:
				uvs.resize(vertex_count)
				for index in vertex_count:
					var u := bytes.decode_float(at)
					at += 4
					var v := bytes.decode_float(at)
					at += 4
					uvs[index] = Vector2(u, v)
			var base := at
			at += frame_count * vertex_count * 12
			var drop := drop_pop and has_uv == 0 and vertex_count > 9
			if drop:
				continue
			if vertex_count >= 1 and base + frame_count * vertex_count * 12 <= bytes.size():
				surfaces.append({"uv": uvs, "verts": vertex_count, "base": base})
		if surfaces.is_empty():
			continue
		var poses: Array = []
		poses.resize(frame_count)
		nodes.append({
			"name": node_name,
			"surfaces": surfaces,
			"poses": poses,
			"bytes": bytes,
		})
	if at + 4 > bytes.size():
		return {"nodes": nodes, "joints": joints, "frames": frame_count}
	var joint_count := bytes.decode_u32(at)
	at += 4
	for _joint_index in joint_count:
		if at + 2 > bytes.size():
			break
		var name_len := bytes.decode_u16(at)
		at += 2
		if at + name_len + 64 > bytes.size():
			break
		var joint_name := bytes.slice(at, at + name_len).get_string_from_utf8()
		at += name_len
		var bind_cells := PackedFloat32Array()
		bind_cells.resize(16)
		for cell in 16:
			bind_cells[cell] = bytes.decode_float(at)
			at += 4
		var base := at
		at += frame_count * 64
		var frames: Array = []
		frames.resize(frame_count)
		joints.append({
			"name": joint_name,
			"bind": _transform_from_panda(bind_cells),
			"base": base,
			"bytes": bytes,
			"frames": frames,
		})
	return {"nodes": nodes, "joints": joints, "frames": frame_count}


static func _ensure_pose(node: Dictionary, frame: int) -> ArrayMesh:
	var poses: Array = node.get("poses", [])
	if frame < 0 or frame >= poses.size():
		return null
	var existing: Variant = poses[frame]
	if existing is ArrayMesh:
		return existing as ArrayMesh
	var bytes: PackedByteArray = node.get("bytes", PackedByteArray())
	var posed := ArrayMesh.new()
	var surfaces: Array = node.get("surfaces", [])
	for surface_item in surfaces:
		if not (surface_item is Dictionary):
			continue
		var surface: Dictionary = surface_item
		var verts := int(surface.get("verts", 0))
		var base := int(surface.get("base", 0))
		var positions := _read_positions(bytes, base, frame, verts)
		if positions.is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = positions
		arrays[Mesh.ARRAY_NORMAL] = _smooth_normals(positions)
		var surface_uvs: PackedVector2Array = surface.get("uv", PackedVector2Array())
		if surface_uvs.size() == positions.size():
			arrays[Mesh.ARRAY_TEX_UV] = surface_uvs
		posed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if posed.get_surface_count() == 0:
		return null
	poses[frame] = posed
	return posed


static func _read_positions(bytes: PackedByteArray, base: int, frame: int, verts: int) -> PackedVector3Array:
	var positions := PackedVector3Array()
	if verts < 1:
		return positions
	var at := base + frame * verts * 12
	if at < 0 or at + verts * 12 > bytes.size():
		return positions
	positions.resize(verts)
	for index in verts:
		var x := bytes.decode_float(at)
		at += 4
		var y := bytes.decode_float(at)
		at += 4
		var z := bytes.decode_float(at)
		at += 4
		positions[index] = Vector3(x, y, z)
	return positions


static func _joint_at(record: Dictionary, frame: int) -> Transform3D:
	var frames: Array = record.get("frames", [])
	if frames.is_empty():
		return Transform3D.IDENTITY
	var index := posmod(frame, frames.size())
	var have: Variant = frames[index]
	if have is Transform3D:
		return have
	var bytes: PackedByteArray = record.get("bytes", PackedByteArray())
	var at := int(record.get("base", 0)) + index * 64
	if at < 0 or at + 64 > bytes.size():
		return Transform3D.IDENTITY
	var cells := PackedFloat32Array()
	cells.resize(16)
	for cell in 16:
		cells[cell] = bytes.decode_float(at)
		at += 4
	var posed := _transform_from_panda(cells)
	frames[index] = posed
	return posed


func _bind_clip(parsed: Dictionary, root: Node) -> Dictionary:
	var clips: Array = []
	var joints: Array = []
	# The robot egg names every bone card "node". Each clip entry is the next
	# mesh of that name, in the same order the baker walked the model.
	var taken: Array = []
	var nodes: Array = parsed.get("nodes", [])
	for item in nodes:
		var node: Dictionary = item
		var instance := _find_mesh(root, str(node["name"]), taken)
		if instance == null or instance.mesh == null:
			continue
		taken.append(instance)
		var poses: Array = node.get("poses", [])
		if poses.is_empty():
			continue
		var first := _ensure_pose(node, 0)
		if first == null:
			continue
		var overrides: Array = []
		for surface_index in first.get_surface_count():
			var source: Material = null
			if surface_index < instance.mesh.get_surface_count():
				source = instance.get_surface_override_material(surface_index)
				if source == null:
					source = instance.mesh.surface_get_material(surface_index)
			overrides.append(source)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.mesh = first
		for surface_index in overrides.size():
			var material := overrides[surface_index] as Material
			if material != null and surface_index < first.get_surface_count():
				instance.set_surface_override_material(surface_index, material)
		clips.append({
			"instance": instance,
			"poses": poses,
			"source": node,
			"overrides": overrides,
		})
	var shared_joints: Array = parsed.get("joints", [])
	for item in shared_joints:
		var node: Dictionary = item
		var joint := _find(root, str(node["name"])) as Node3D
		if joint == null:
			continue
		var joint_frames: Array = node.get("frames", [])
		joints.append({
			"node": joint,
			"rest": joint.transform,
			"bind": node["bind"],
			"frames": joint_frames,
			"base": int(node.get("base", 0)),
			"bytes": node.get("bytes", PackedByteArray()),
		})
	return {"clips": clips, "joints": joints, "frames": int(parsed.get("frames", 0)), "shown": -1}


static func _blend_basis(from: Basis, to: Basis, fraction: float) -> Basis:
	var from_scale := from.get_scale()
	var to_scale := to.get_scale()
	if from_scale.x < 0.05 or from_scale.y < 0.05 or from_scale.z < 0.05:
		return _lerp_basis(from, to, fraction)
	if to_scale.x < 0.05 or to_scale.y < 0.05 or to_scale.z < 0.05:
		return _lerp_basis(from, to, fraction)
	var rotation := from.orthonormalized().slerp(to.orthonormalized(), fraction)
	return rotation.scaled(from_scale.lerp(to_scale, fraction))


static func _lerp_basis(from: Basis, to: Basis, fraction: float) -> Basis:
	return Basis(from.x.lerp(to.x, fraction), from.y.lerp(to.y, fraction), from.z.lerp(to.z, fraction))


static func _transform_from_panda(cells: PackedFloat32Array) -> Transform3D:
	var x := Vector3(cells[0], cells[1], cells[2])
	var y := Vector3(cells[4], cells[5], cells[6])
	var z := Vector3(cells[8], cells[9], cells[10])
	var origin := Vector3(cells[12], cells[13], cells[14])
	var sx := x.length()
	var sy := y.length()
	var sz := z.length()
	# A scale joint flattens a bone by shrinking one axis. Orthonormalizing
	# that away leaves the card at its bind size, disconnected from the pose.
	if sx < 0.05 or sy < 0.05 or sz < 0.05:
		return Transform3D(Basis(x, y, z), origin)
	var basis := Basis(x / sx, y / sy, z / sz)
	basis = basis.orthonormalized().scaled(Vector3(sx, sy, sz))
	return Transform3D(basis, origin)


func _find(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find(child, wanted)
		if found != null:
			return found
	return null


func _find_mesh(node: Node, wanted: String, taken: Array) -> MeshInstance3D:
	if node is MeshInstance3D and not taken.has(node) and _same_mesh(node.name, wanted):
		return node
	for child in node.get_children():
		var found := _find_mesh(child, wanted, taken)
		if found != null:
			return found
	return null


## Godot renames a second "node" to "node2" on import. The clip still says "node".
func _same_mesh(actual: String, wanted: String) -> bool:
	if actual == wanted:
		return true
	if not actual.begins_with(wanted):
		return false
	var rest := actual.substr(wanted.length())
	return rest.is_valid_int()
