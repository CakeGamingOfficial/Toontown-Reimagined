extends Node

## DistributedCogKart on the country club, and DistributedClubElevator on the
## GOLFCART already built into a kart room or the Club President's room.
## The exterior ride needs the laff from FactoryLaffMinimums. The interior
## cart waits until the floor's cogs are gone, then it takes the next floor.
## The President's cart returns to the country club.

const _RUN := preload("res://scenes/cog_hq/course_run.gd")
const _COURSE := "res://scenes/cog_hq/bossbot_course.tscn"
const _CLUB := "res://scenes/cog_hq/bossbot_country_club.tscn"
const _NAMES: PackedStringArray = ["FrontThree", "MiddleSix", "BackNine"]

const _REACH := 6.0
const _COUNTDOWN := 15.0
const _BOARD := 1.0
const _EXIT := 1.0

var _karts: Array[Node3D] = []
var _kart: Node3D
var _phase := ""
var _age := 0.0
var _left := 0.0
var _from := Vector3.ZERO
var _warned := false
var _clock: Label3D


static func place(host: Node) -> void:
	if Engine.is_editor_hint() or host == null:
		return
	var file := host.scene_file_path.get_file()
	if file != "bossbot_country_club.tscn" and file != "bossbot_course.tscn":
		return
	if host.get_node_or_null("CourseKarts") != null:
		return
	var script := load("res://scenes/cog_hq/course_kart.gd") as GDScript
	var node := script.new() as Node
	node.name = "CourseKarts"
	host.add_child(node)


static func arrival(host: Node, into_course: bool) -> Dictionary:
	if into_course:
		var spawn := _find(host, "CourseSpawn")
		if spawn == null:
			return {}
		var forward := spawn.global_transform.basis.y
		forward.y = 0.0
		if forward.length_squared() < 0.0001:
			forward = Vector3(0.0, 0.0, -1.0)
		return {"point": spawn.global_position, "heading": _heading(forward)}
	var kart := _find(host, _NAMES[_RUN.course])
	if kart == null:
		return {}
	var out := _nose(kart)
	return {"point": kart.global_position + out * 6.0, "heading": _heading(out)}


func _ready() -> void:
	var host := get_parent()
	if host == null:
		return
	if host.scene_file_path.get_file() == "bossbot_course.tscn":
		_interior(host)
	else:
		_exterior(host)
	_clock = Label3D.new()
	_clock.name = "KartClock"
	_clock.font = ToonGui.sign_font()
	_clock.font_size = 96
	_clock.pixel_size = 0.02
	_clock.modulate = Color(0.15, 0.45, 0.15, 1.0)
	_clock.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_clock.visible = false
	add_child(_clock)


func _process(delta: float) -> void:
	if _phase == "":
		_offer()
		return
	_age += delta
	if _phase == "board":
		_step_board()
	elif _phase == "wait":
		_left = maxf(_left - delta, 0.0)
		_stand()
		_show_clock(true)
		if _left <= 0.0:
			_depart()
	elif _phase == "hop":
		_show_clock(false)
		_step_hop()


func _exterior(host: Node) -> void:
	for index in _NAMES.size():
		var kart := _find(host, _NAMES[index])
		if kart == null:
			continue
		kart.set_meta("outside", true)
		kart.set_meta("course", index)
		kart.set_meta("exit", false)
		_karts.append(kart)


func _interior(host: Node) -> void:
	for child in host.get_children():
		if not str(child.name).begins_with("Piece"):
			continue
		var cart := _find(child, "GOLFCART")
		if cart == null:
			continue
		cart.set_meta("outside", false)
		cart.set_meta("course", _RUN.course)
		cart.set_meta("exit", not _RUN.has_next())
		_karts.append(cart)


func _offer() -> void:
	var toon := _toon()
	if toon == null or bool(toon.call("battle_busy")):
		return
	var here: Vector3 = toon.call("battle_point")
	for kart in _karts:
		if kart == null:
			continue
		if here.distance_to(kart.global_position) > _REACH:
			continue
		if absf(here.y - kart.global_position.y) > 6.0:
			continue
		if bool(kart.get_meta("outside")):
			var hp: Vector2i = toon.call("battle_hp")
			var need := _laff(int(kart.get_meta("course", 0)))
			if hp.x < need:
				if not _warned:
					_warned = true
					toon.call("show_notice", "You need %d laff points to ride this kart" % need)
				return
		elif not _floor_open():
			return
		_warned = false
		_begin(kart)
		return


func _laff(index: int) -> int:
	var mins: PackedInt32Array = [0, 101, 106]
	return mins[clampi(index, 0, 2)]


func _floor_open() -> bool:
	var cogs := get_parent().get_node_or_null("StreetSuits")
	if cogs != null and cogs.has_method("floor_clear"):
		return bool(cogs.call("floor_clear"))
	return true


func _begin(kart: Node3D) -> void:
	var toon := _toon()
	if toon == null:
		return
	_kart = kart
	_phase = "board"
	_age = 0.0
	_from = toon.call("battle_point")
	toon.call("hold_for_battle", true)


func _seat() -> Vector3:
	if _kart == null:
		return Vector3.ZERO
	return _kart.global_position + Vector3(0.0, 1.4, 0.0)


func _step_board() -> void:
	var toon := _toon()
	if toon == null or _kart == null:
		_release()
		return
	var blend := clampf(_age / _BOARD, 0.0, 1.0)
	toon.call("visit_friend", _from.lerp(_seat(), blend), _heading(_nose(_kart)))
	if _age >= _BOARD:
		_phase = "wait"
		_age = 0.0
		_left = _COUNTDOWN


func _stand() -> void:
	var toon := _toon()
	if toon == null or _kart == null:
		return
	toon.call("visit_friend", _seat(), _heading(_nose(_kart)))


func _depart() -> void:
	if _kart == null:
		_release()
		return
	_show_clock(false)
	if bool(_kart.get_meta("outside")):
		_RUN.begin(int(_kart.get_meta("course", 0)))
		ToonLoading.change_to(_COURSE)
		return
	if bool(_kart.get_meta("exit")):
		_RUN.trip = "out"
		ToonLoading.change_to(_CLUB)
		return
	_RUN.advance()
	ToonLoading.change_to(_COURSE)


func _step_hop() -> void:
	_release()


func _release() -> void:
	_phase = ""
	_kart = null
	_show_clock(false)
	var toon := _toon()
	if toon != null:
		toon.call("hold_for_battle", false)


func _show_clock(show: bool) -> void:
	if _clock == null or _kart == null:
		return
	_clock.visible = show
	if not show:
		return
	_clock.global_position = _kart.global_position + Vector3(0.0, 4.2, 0.0)
	var text := str(ceili(_left) if _left > 0.0 else 0)
	if _clock.text != text:
		_clock.text = text


func _toon() -> Node:
	var host := get_parent()
	if host == null:
		return null
	return host.get_node_or_null("PlaygroundToon")


static func _nose(kart: Node3D) -> Vector3:
	var flat := -kart.global_transform.basis.z
	flat.y = 0.0
	if flat.length_squared() < 0.04:
		flat = kart.global_transform.basis.y
		flat.y = 0.0
	if flat.length_squared() < 0.04:
		return Vector3(0.0, 0.0, -1.0)
	return flat.normalized()


static func _heading(dir: Vector3) -> float:
	return rad_to_deg(atan2(-dir.x, -dir.z))


static func _find(node: Node, node_name: String) -> Node3D:
	if node == null:
		return null
	if node is Node3D and str(node.name) == node_name:
		return node as Node3D
	for child in node.get_children():
		var found := _find(child, node_name)
		if found != null:
			return found
	return null
