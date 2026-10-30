extends RefCounted

## HoodMgr.addLinkTunnelHooks names each shaft linktunnel_{hood}_{zone}.
## The zone is where that tunnel comes out. ZoneUtil.getBranchZone picks the
## street or playground scene that contains it. A trip remembers the zone the
## toon left so the far side can find the matching shaft, the way
## Place.enterTunnelIn looks up makeLinkTunnelName.

const _FORWARD := 20.0

static var arrival_from_zone := -1
static var arrival_from_code := ""
static var arrival_lateral := 0.0

const _CODE: Dictionary = {
	1000: "dd",
	2000: "tt",
	3000: "br",
	4000: "mm",
	5000: "dg",
	6000: "oz",
	8000: "gs",
	9000: "dl",
	10000: "bosshq",
	11000: "sellhq",
	12000: "cashhq",
	13000: "lawhq",
	17000: "gz",
}

const _BRANCH: Dictionary = {
	1000: "res://scenes/playgrounds/donalds_dock.tscn",
	1100: "res://scenes/streets/barnacle_boulevard.tscn",
	1200: "res://scenes/streets/seaweed_street.tscn",
	1300: "res://scenes/streets/lighthouse_lane.tscn",
	2000: "res://scenes/playgrounds/toontown_central.tscn",
	2100: "res://scenes/streets/silly_street.tscn",
	2200: "res://scenes/streets/loopy_lane.tscn",
	2300: "res://scenes/streets/punchline_place.tscn",
	3000: "res://scenes/playgrounds/the_burrrgh.tscn",
	3100: "res://scenes/streets/walrus_way.tscn",
	3200: "res://scenes/streets/sleet_street.tscn",
	3300: "res://scenes/streets/polar_place.tscn",
	4000: "res://scenes/playgrounds/minnies_melodyland.tscn",
	4100: "res://scenes/streets/alto_avenue.tscn",
	4200: "res://scenes/streets/baritone_boulevard.tscn",
	4300: "res://scenes/streets/tenor_terrace.tscn",
	5000: "res://scenes/playgrounds/daisy_gardens.tscn",
	5100: "res://scenes/streets/elm_street.tscn",
	5200: "res://scenes/streets/maple_street.tscn",
	5300: "res://scenes/streets/oak_street.tscn",
	6000: "res://scenes/playgrounds/acorn_acres.tscn",
	8000: "res://scenes/playgrounds/goofy_speedway.tscn",
	9000: "res://scenes/playgrounds/donalds_dreamland.tscn",
	9100: "res://scenes/streets/lullaby_lane.tscn",
	9200: "res://scenes/streets/pajama_place.tscn",
	10000: "res://scenes/cog_hq/bossbot_lobby.tscn",
	11000: "res://scenes/cog_hq/sellbot_courtyard.tscn",
	12000: "res://scenes/cog_hq/cashbot_trainyard.tscn",
	13000: "res://scenes/cog_hq/lawbot_courtyard.tscn",
	17000: "res://scenes/playgrounds/chip_n_dales_minigolf.tscn",
}


static func arriving() -> bool:
	return arrival_from_zone >= 0


static func depart(from_zone: int, from_code: String, lateral: float) -> void:
	arrival_from_zone = from_zone
	arrival_from_code = from_code
	arrival_lateral = lateral


static func take() -> Dictionary:
	var trip := {
		"from_zone": arrival_from_zone,
		"from_code": arrival_from_code,
		"lateral": arrival_lateral,
	}
	arrival_from_zone = -1
	arrival_from_code = ""
	arrival_lateral = 0.0
	return trip


static func hood_of(zone_id: int) -> int:
	return zone_id - posmod(zone_id, 1000)


static func branch_of(zone_id: int) -> int:
	var branch := zone_id - posmod(zone_id, 100)
	var cog := zone_id >= 10000 and zone_id < 15000
	if not cog and posmod(zone_id, 1000) >= 500:
		branch -= 500
	return branch


static func scene_for_zone(zone_id: int) -> String:
	var branch := branch_of(zone_id)
	if _BRANCH.has(branch):
		return String(_BRANCH[branch])
	return ""


static func code_for_zone(zone_id: int) -> String:
	var hood := hood_of(zone_id)
	if _CODE.has(hood):
		return String(_CODE[hood])
	return ""


static func run_speed() -> float:
	return _FORWARD


const _PIVOT_X := -14.0
const _PIVOT_Y := -6.0
const _PIVOT_DUR := 2.0
const _PIVOT_ANGLE := 135.0
const _CENTER := 9.0
const _INFLUENCE := 0.6
const _OUT_Y := 5.0
const _FEET := 0.1


## DistributedToon.getTunnelOutToonTrack. The straight run ends at the pivot,
## then the pivot heading goes from 0 to -135 while the toon eases toward the
## shaft center over the first 90/135 of that turn.
static func out_local(start: Vector3, start_x: float, straight: float, elapsed: float) -> Vector3:
	if elapsed <= straight:
		var along := clampf(elapsed / straight, 0.0, 1.0)
		return Vector3(lerpf(start.x, start_x, along), lerpf(start.y, _PIVOT_Y, along), _FEET)
	var swung := _swing(start_x, elapsed - straight)
	return Vector3(_PIVOT_X + swung.x, _PIVOT_Y + swung.y, _FEET)


## getTunnelInToonTrack. Wait already swung, unwind the pivot from -135 to 0,
## release the lateral pull over the last 90/135, then run straight out to Y 5.
static func in_local(end_x: float, elapsed: float) -> Vector3:
	var straight := absf(_OUT_Y - _PIVOT_Y) / _FORWARD
	if elapsed <= 0.8 + _PIVOT_DUR:
		var turn_t := clampf(maxf(elapsed - 0.8, 0.0), 0.0, _PIVOT_DUR)
		var swung := _unwind(end_x, turn_t)
		return Vector3(_PIVOT_X + swung.x, _PIVOT_Y + swung.y, _FEET)
	var along := clampf((elapsed - 0.8 - _PIVOT_DUR) / straight, 0.0, 1.0)
	return Vector3(end_x, lerpf(_PIVOT_Y, _OUT_Y, along), _FEET)


static func in_length() -> float:
	return 0.8 + _PIVOT_DUR + absf(_OUT_Y - _PIVOT_Y) / _FORWARD


static func world_on(origin: Node3D, local: Vector3) -> Vector3:
	var basis := origin.global_basis
	return origin.global_position + basis.x * local.x + basis.y * local.y + basis.z * local.z


static func local_on(origin: Node3D, world: Vector3) -> Vector3:
	return origin.global_transform.affine_inverse() * world


static func heading_of(dir: Vector3) -> float:
	return rad_to_deg(atan2(-dir.x, -dir.z))


## Godot numbers a second empty tunnel_origin as tunnel_origin2. The DNA name
## is still the shaft the movie is parented to.
static func origin_under(node: Node) -> Node3D:
	for child in node.get_children():
		if child is Node3D and _origin_name(String(child.name)):
			return child as Node3D
		var deeper := origin_under(child)
		if deeper != null:
			return deeper
	return null


static func find_link(node: Node, code: String, zone: int) -> Node3D:
	var prefix := "linktunnel_%s_%d" % [code, zone]
	var node_name := String(node.name)
	if node is Node3D and node_name.begins_with(prefix):
		var rest := node_name.substr(prefix.length())
		if rest.is_empty() or rest.begins_with("_") or rest.begins_with("@"):
			return node as Node3D
	for child in node.get_children():
		var found := find_link(child, code, zone)
		if found != null:
			return found
	return null


static func _origin_name(node_name: String) -> bool:
	if not node_name.begins_with("tunnel_origin"):
		return false
	var rest := node_name.substr("tunnel_origin".length())
	return rest.is_empty() or rest.begins_with("@") or rest.is_valid_int()


static func _swing(start_x: float, pivot_t: float) -> Vector2:
	var pivot_lerp := _PIVOT_DUR * (90.0 / _PIVOT_ANGLE)
	var ox := start_x - _PIVOT_X
	var target := _CENTER + (ox - _CENTER) * (1.0 - _INFLUENCE)
	var pulled := target
	if pivot_t < pivot_lerp:
		pulled = lerpf(ox, target, clampf(pivot_t / pivot_lerp, 0.0, 1.0))
	var angle := deg_to_rad(-_PIVOT_ANGLE * clampf(pivot_t / _PIVOT_DUR, 0.0, 1.0))
	return Vector2(pulled * cos(angle), pulled * sin(angle))


static func _unwind(end_x: float, turn_t: float) -> Vector2:
	var pivot_lerp := _PIVOT_DUR * (90.0 / _PIVOT_ANGLE)
	var ox := end_x - _PIVOT_X
	var pulled := _CENTER + (ox - _CENTER) * (1.0 - _INFLUENCE)
	var pivot_x := pulled
	var blend_at := _PIVOT_DUR - pivot_lerp
	if turn_t > blend_at:
		var along := clampf((turn_t - blend_at) / pivot_lerp, 0.0, 1.0)
		pivot_x = lerpf(pulled, ox, along)
	var angle := deg_to_rad(lerpf(-_PIVOT_ANGLE, 0.0, clampf(turn_t / _PIVOT_DUR, 0.0, 1.0)))
	return Vector2(pivot_x * cos(angle), pivot_x * sin(angle))
