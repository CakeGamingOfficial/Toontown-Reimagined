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
# MovieUtil.SUIT_LOSE_DURATION. Suit.getLoseActor plays the lose-mod across it.
const LOSE_SECONDS := 6.0
var _lose_on := false
var _lose_tried := false
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
	var same := get_node_or_null("Suit") != null and cog_code == str(cog["code"]) and _model_path == String(paths["model"])
	cog_code = str(cog["code"])
	cog_name = str(cog["name"])
	dept = str(cog["dept"])
	body = str(cog["body"])
	height = float(cog["height"])
	cog_level = int(cog.get("level", 1))
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
		_set_alpha(1.0 - clampf(_fly, 0.0, 1.0))
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
		return
	global_position = point
	rotation.y = yaw


func march(walking: bool) -> void:
	_fight_key = "walk" if walking else ""


func begin_react(key: String, elapsed: float) -> void:
	if _lose_on:
		return
	_fight_key = key
	_fight_time = elapsed
	# The movie asks for this pose on its own clock. Posing here keeps the
	# attack up even when this cog already idled earlier in the frame.
	if key != "" and bool(get_meta("in_fight", false)):
		play_attack(key, elapsed)


## Suit.getLoseActor. The live suit hides and suit-lose-mod plays for 6 seconds.
func play_lose(elapsed: float) -> void:
	_detail = 2
	if not _lose_on and not _lose_tried:
		_start_lose()
	if not _lose_on:
		return
	var frames := int(_lose_bank.get("frames", 0))
	if frames <= 1:
		return
	var frame := mini(int(clampf(elapsed / LOSE_SECONDS, 0.0, 1.0) * float(frames - 1)), frames - 1)
	_pose_clip(_lose_bank, frame, frame, 0.0)


func _start_lose() -> void:
	_lose_tried = true
	var packed := load("res://assets/cogs/lose/%s.glb" % body) as PackedScene
	if packed == null:
		return
	var suit := get_node_or_null("Suit")
	var lose := packed.instantiate()
	lose.name = "LoseActor"
	add_child(lose)
	_match_lose_scale(lose, suit)
	if suit != null:
		_dress_lose(lose, suit)
		_copy_head(lose, suit)
		suit.visible = false
	_release_nametag()
	_lose_bank = _read_bank("res://assets/cogs/lose/%s.lose" % body, lose)
	if int(_lose_bank.get("frames", 0)) <= 1:
		lose.free()
		if suit != null:
			suit.visible = true
		return
	_lose_on = true


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
	var worn := 1.0
	for child in suit.get_children():
		if child is Node3D and (child as Node3D).scale.x > 0.05:
			worn = (child as Node3D).scale.x
			break
	for child in lose.get_children():
		if child is Node3D:
			(child as Node3D).scale = Vector3.ONE * worn


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
	for child in src.get_children():
		if not (child is Node3D) or String(child.name).begins_with("joint"):
			continue
		dst.add_child(child.duplicate())


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


func play_attack(key: String, elapsed: float) -> void:
	# Attack clips are loaded on demand. Street roaming does not call this.
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
	var walk_file := str(cog.get("walk", "res://assets/cogs/anims/%s/walk.walk" % body))
	var neutral_file := str(cog.get("neutral", "res://assets/cogs/anims/%s/neutral.walk" % body))
	_walk = _read_bank(walk_file)
	_neutral = _read_bank(neutral_file)
	_release_nametag()
	_add_nametag()
	_idle(0.0)


func set_walking(moving: bool) -> void:
	set_meta("walking", moving)


func _process(delta: float) -> void:
	# The death actor is posed by the battle movie. Idle would put the suit back.
	if _lose_on:
		return
	if bool(get_meta("in_fight", false)):
		if _fight_key == "walk":
			_march(delta)
		elif _fight_key != "":
			play_attack(_fight_key, _fight_time)
		else:
			_idle(delta)
		return
	if bool(get_meta("factory", false)):
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
	_set_alpha(1.0 - clampf(_fly, 0.0, 1.0))
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
	if bool(get_meta("factory", false)):
		return not bool(get_meta("in_fight", false))
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
	if _lane_blocked():
		_idle(delta)
		return
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


## The suit ahead keeps the lane. A pile stops and lets that one walk off.
func _lane_blocked() -> bool:
	var parent := get_parent()
	if parent == null:
		return false
	var toward := Vector2(_goal.x - global_position.x, _goal.z - global_position.z)
	var reach := toward.length()
	var mine := get_instance_id()
	for child in parent.get_children():
		if child == self or not (child is StreetCog):
			continue
		var other := child as StreetCog
		if not other.on_lane():
			continue
		var flat := Vector2(other.global_position.x - global_position.x, other.global_position.z - global_position.z)
		var dist := flat.length()
		if dist < 2.0 and other.get_instance_id() < mine:
			return true
		if dist > 6.0 or dist < 0.001 or reach < 0.001:
			continue
		# Only the suit walking the same way, and ahead, holds this one back.
		# The suit on the opposite sidewalk is close at a corner and must pass.
		var yaw := other.rotation.y
		var same_way := Vector2(-sin(yaw), -cos(yaw))
		if same_way.dot(toward) <= 0.0:
			continue
		if flat.dot(toward) / (dist * reach) >= 0.65:
			return true
	return false


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


func _begin_fly_out() -> void:
	_phase = 2
	_fly = 0.0
	_ground = global_position
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
	# SuitBaseNameWithLevel: name, department, level, on the translucent suit card.
	var tag: Variant = board.call("add", self, "%s\n%s\nLevel %d" % [cog_name, dept_name, cog_level], "cog")
	var panel := tag as Control
	if panel != null:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


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

## The loose suit mesh keeps a shirt card on the right wrist. Posed, that card
## sticks out of the sleeve. Both wrists also carry a flat gray lining that
## sits on the pinstripe. The left shirt cuff stays in the sleeve opening, and
## the black ring at the neck stays. Clips for these bodies drop the same
## surfaces, so the pose swap still lines materials up with the standing mesh.
func _hide_sleeve_pop(actor: Node) -> void:
	var suit := _find(actor, "node") as MeshInstance3D
	if suit == null or suit.mesh == null:
		return
	var drop: Array[int] = []
	var shirt_cards := 0
	for index in suit.mesh.get_surface_count():
		var arrays := suit.mesh.surface_get_arrays(index)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var material := suit.mesh.surface_get_material(index) as BaseMaterial3D
		var textured := material != null and material.albedo_texture != null
		if textured and verts.size() == 24:
			shirt_cards += 1
			if shirt_cards == 2:
				drop.append(index)
		elif not textured and verts.size() > 9:
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
	# Suits at the far end of a block snap to the clip frame. Blending every
	# joint, every frame, is what kept a crowded street under the refresh rate.
	var fraction := 0.0 if _detail < 2 else clampf(blend, 0.0, 1.0)
	# Each frame is a finished mesh shared by every suit on that body. Swapping
	# it does not rewrite vertex buffers, which was both corrupting the pose
	# and stalling the street.
	var show := int(bank.get("shown", -1)) != frame
	if show:
		bank["shown"] = frame
	var clips: Array = bank.get("clips", [])
	for item in clips:
		var record: Dictionary = item
		var instance := record["instance"] as MeshInstance3D
		if not is_instance_valid(instance):
			continue
		var poses: Array = record.get("poses", [])
		if frame < 0 or frame >= poses.size():
			continue
		var posed: ArrayMesh = null
		var slot: Variant = poses[frame]
		if slot is ArrayMesh:
			posed = slot as ArrayMesh
		if posed == null:
			var source: Dictionary = record.get("source", {})
			posed = _ensure_pose(source, frame)
		if posed == null:
			continue
		if instance.mesh != posed:
			instance.mesh = posed
			show = true
		if not show:
			continue
		var overrides: Array = record.get("overrides", [])
		for index in overrides.size():
			var material := overrides[index] as Material
			if material != null and index < posed.get_surface_count():
				instance.set_surface_override_material(index, material)
	var joints: Array = bank.get("joints", [])
	for item in joints:
		var record: Dictionary = item
		var joint := record["node"] as Node3D
		if not is_instance_valid(joint):
			continue
		var frames: Array = record["frames"]
		if frames.is_empty():
			continue
		var posed_frame := _joint_at(record, frame)
		if fraction > 0.001:
			var nxt := _joint_at(record, following)
			posed_frame.origin = posed_frame.origin.lerp(nxt.origin, fraction)
			posed_frame.basis = posed_frame.basis.slerp(nxt.basis, fraction)
		var stamp := frame * 1000 + int(fraction * 20.0)
		if int(record.get("stamp", -1)) == stamp:
			continue
		record["stamp"] = stamp
		var bind_inv := Transform3D.IDENTITY
		if record.has("bind_inv"):
			bind_inv = record["bind_inv"] as Transform3D
		else:
			var bind: Transform3D = record["bind"]
			bind_inv = bind.affine_inverse()
			record["bind_inv"] = bind_inv
		var rest: Transform3D = record["rest"]
		joint.transform = rest * bind_inv * posed_frame


func _camera_detail() -> int:
	if _block_hidden():
		return 0
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 2
	var chest := global_position + Vector3(0.0, height * 0.45, 0.0)
	var dist2 := chest.distance_squared_to(cam.global_position)
	# Off-screen suits hold their last pose. Every suit you can see blends
	# the clip every frame, including one at the far end of the street.
	if dist2 > 16.0 * 16.0 and cam.is_position_behind(chest) and not cam.is_position_in_frustum(chest):
		return 0
	# Close suits blend. The rest of the block holds the current clip frame.
	if dist2 < 20.0 * 20.0 and cam.is_position_in_frustum(chest):
		return 2
	return 1


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
		var shirt_cards := 0
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
			var drop := false
			if drop_pop and has_uv != 0 and vertex_count == 24:
				shirt_cards += 1
				drop = shirt_cards == 2
			elif drop_pop and has_uv == 0 and vertex_count > 9:
				drop = true
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


static func _transform_from_panda(cells: PackedFloat32Array) -> Transform3D:
	var x := Vector3(cells[0], cells[1], cells[2])
	var y := Vector3(cells[4], cells[5], cells[6])
	var z := Vector3(cells[8], cells[9], cells[10])
	var origin := Vector3(cells[12], cells[13], cells[14])
	if x.length_squared() < 0.0025 or y.length_squared() < 0.0025 or z.length_squared() < 0.0025:
		return Transform3D(Basis.from_scale(Vector3.ZERO), origin)
	var basis := Basis(x, y, z)
	basis = basis.orthonormalized()
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
