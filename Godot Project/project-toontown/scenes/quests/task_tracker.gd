extends Control

## Held ToonTasks as one line along the bottom of the screen. The line and the
## arrow follow the task picked on the ToonTasks page. Until one is picked,
## that is the first task in the book.

const _UI := preload("res://scenes/shticker/ui_settings.gd")
const _LINKS := preload("res://scenes/places/tunnel_links.gd")
const _TITLES := preload("res://scenes/places/zone_title.gd")
const _PLACES := preload("res://scenes/places/hood_places.gd")
const _HQ := preload("res://scenes/interiors/toon_hq_door.gd")
const _DOOR := preload("res://scenes/interiors/shop_door.gd")
const _ARROW_TEX := preload("res://assets/gui/questmap/tt_t_gui_qst_arrow.png")

const _ARROW_SIZE := 40.0
const _ARROW_GAP := 4.0
const _ARRIVED := 10.0
# Stay aimed at a toon until you are standing with them. A shop floor is
# shorter than the distance that counts as arriving at a door.
const _BESIDE := 4.0
const _MISS := Vector3(INF, INF, INF)

var _tasks: ToonTasks
var _panel: PanelContainer
var _label: RichTextLabel
var _arrow: TextureRect
var _shown := ""
var _wait := 0.0
var _view := Vector2.ZERO
var _goal := Vector3.ZERO
var _have := false
var _at_npc := false
var _tunnel_scene: Node
var _tunnels: Array[Node3D] = []
var _npc_scene: Node
var _npc_id := -1
var _npc: Node3D
var _hq_scene: Node
var _hq: Node3D


func setup(tasks: ToonTasks) -> void:
	_tasks = tasks
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.mouse_filter = MOUSE_FILTER_IGNORE
	_panel.visible = false
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1.0, 1.0, 1.0, 0.55)
	box.set_corner_radius_all(4)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	_panel.add_theme_stylebox_override("panel", box)
	_label = RichTextLabel.new()
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("normal_font", ToonGui.font())
	_label.add_theme_font_size_override("normal_font_size", 22)
	_label.add_theme_color_override("default_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 4)
	_panel.add_child(_label)
	add_child(_panel)
	_arrow = TextureRect.new()
	_arrow.texture = _ARROW_TEX
	_arrow.mouse_filter = MOUSE_FILTER_IGNORE
	_arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_arrow.size = Vector2(_ARROW_SIZE, _ARROW_SIZE)
	_arrow.pivot_offset = _arrow.size * 0.5
	_arrow.visible = false
	add_child(_arrow)


func _process(delta: float) -> void:
	var view := get_viewport_rect().size
	if view != _view:
		_place()
	_wait -= delta
	if _wait <= 0.0:
		_wait = 0.25
		_refresh()
	_aim()


func _refresh() -> void:
	var book := get_parent().get_node_or_null("ShtickerBook") if get_parent() != null else null
	var open := book != null and book.has_method("is_open") and bool(book.call("is_open"))
	if open or _tasks == null or not _UI.tracker_on():
		_panel.visible = false
		_have = false
		return
	var text := _lines()
	_panel.visible = not text.is_empty()
	_have = false
	if text.is_empty():
		return
	var scene := get_tree().current_scene
	if scene != null:
		var here := _TITLES.zone_of(scene.scene_file_path)
		var card := _tasks.tracked_card()
		if not card.is_empty():
			var point := _goal_for(card, scene, here)
			if not is_inf(point.x):
				_goal = point
				_have = true
	if text == _shown and _view == get_viewport_rect().size:
		return
	_shown = text
	_label.text = text
	_place()


func _place() -> void:
	_view = get_viewport_rect().size
	var card := _panel.get_combined_minimum_size()
	_panel.size = card
	# Bottom center, clear of the screen edge. The card hugs the words.
	_panel.position = Vector2((_view.x - card.x) * 0.5, _view.y - card.y - 28.0)
	if _arrow == null:
		return
	var center_x := _panel.position.x + card.x * 0.5
	_arrow.position = Vector2(center_x - _ARROW_SIZE * 0.5, _panel.position.y - _ARROW_SIZE - _ARROW_GAP)


func _aim() -> void:
	if _arrow == null:
		return
	if not _have or not _panel.visible:
		_arrow.visible = false
		return
	var scene := get_tree().current_scene
	var body: Node3D = null
	if scene != null:
		body = scene.get_node_or_null("Player") as Node3D
	var cam := get_viewport().get_camera_3d()
	if body == null or cam == null:
		_arrow.visible = false
		return
	var flat := Vector2(_goal.x - body.global_position.x, _goal.z - body.global_position.z)
	var arrived: float = _BESIDE if _at_npc else _ARRIVED
	if flat.length() < arrived:
		_arrow.visible = false
		return
	var forward := -cam.global_basis.z
	var right := cam.global_basis.x
	var ahead := flat.dot(Vector2(forward.x, forward.z))
	var side := flat.dot(Vector2(right.x, right.z))
	if absf(ahead) + absf(side) < 0.001:
		_arrow.visible = false
		return
	# The picture points right. Zero rotation is ahead, which is up the screen.
	_arrow.rotation = atan2(side, ahead) - PI * 0.5
	_arrow.visible = true


## Where the tracked task wants the toon to walk. A task that can be done
## right here, or a friend or phone task, leaves the arrow hidden.
func _goal_for(card: Dictionary, scene: Node, here: int) -> Vector3:
	_at_npc = false
	var kind := String(card.get("kind", ""))
	var ready := bool(card.get("ready", false))
	if ready or kind == "visit" or kind == "deliver" or kind == "track":
		return _turn_in_point(card, scene, here)
	if kind == "friend" or kind == "phone":
		return _MISS
	if kind == "trolley":
		var car := scene.find_child("trolley_car", true, false) as Node3D
		return car.global_position if car != null else _MISS
	var need_zone := int(card.get("zone", 0))
	var need_hood := int(card.get("hood", 0))
	if kind == "fish" and _fish_here(here, need_zone, need_hood):
		return _MISS
	if kind != "fish" and _task_here(here, need_zone, need_hood):
		return _MISS
	var dest := need_zone if need_zone != 0 else need_hood
	if dest == 0:
		return _nearest_street(scene, here)
	return _tunnel_toward(scene, here, dest)


func _turn_in_point(card: Dictionary, scene: Node, here: int) -> Vector3:
	var npc_id := int(card.get("npc", 0))
	var npc := _npc_at(scene, npc_id)
	if npc != null:
		_at_npc = true
		return npc.global_position
	var turn := String(card.get("turn_in", ""))
	if turn == "hq" or npc_id == 0 or npc_id == 1000:
		if _PLACES.is_toon_hq(scene.scene_file_path):
			var officer := _nearest_officer(scene)
			if officer == null:
				return _MISS
			_at_npc = true
			return officer.global_position
		# The landmark root sits at the playground origin. The doors are on the
		# building, and a toon in another zone has to be walked there tunnel by tunnel.
		var step := _LINKS.hq_step(here)
		if step == 0:
			return _MISS
		if _LINKS.branch_of(here) == step:
			return _hq_door_point(scene)
		return _tunnel_toward(scene, here, step)
	if turn.is_valid_int():
		var zone := int(turn)
		var building := _DOOR.find_for_zone(zone)
		if building != null and is_instance_valid(building):
			var door := _DOOR.find_exterior_door(building)
			if door != null:
				return door.global_position
			return building.global_position
		return _tunnel_toward(scene, here, _LINKS.branch_of(zone))
	return _MISS


func _task_here(here: int, need_zone: int, need_hood: int) -> bool:
	if not _on_street(here):
		return false
	if need_zone == 0 and need_hood == 0:
		return true
	if need_zone != 0:
		return here == need_zone or _LINKS.branch_of(here) == need_zone
	return _LINKS.hood_of(here) == need_hood


func _fish_here(here: int, need_zone: int, need_hood: int) -> bool:
	if here == 0:
		return false
	if need_zone == 0 and need_hood == 0:
		return true
	if need_zone != 0:
		return here == need_zone or _LINKS.branch_of(here) == need_zone
	return _LINKS.hood_of(here) == need_hood


func _on_street(here: int) -> bool:
	if here == 0:
		return false
	return _LINKS.branch_of(here) != _LINKS.hood_of(here)


func _npc_at(scene: Node, npc_id: int) -> Node3D:
	if npc_id == 0:
		return null
	if is_instance_valid(_npc_scene) and _npc_scene == scene and _npc_id == npc_id:
		if _npc != null and is_instance_valid(_npc):
			return _npc
	_npc_scene = scene
	_npc_id = npc_id
	_npc = null
	for node in scene.find_children("*", "StaticBody3D", true, false):
		if int(node.get_meta("npc_id", 0)) != npc_id:
			continue
		_npc = node as Node3D
		return _npc
	return null


## Any HQ officer can take the hand-in. The closest one is the one to walk to.
func _nearest_officer(scene: Node) -> Node3D:
	var player := scene.get_node_or_null("Player") as Node3D
	var best: Node3D = null
	var best_gap := INF
	for node in scene.find_children("Officer*", "StaticBody3D", true, false):
		var body := node as Node3D
		if player == null:
			return body
		var flat := Vector2(body.global_position.x - player.global_position.x, body.global_position.z - player.global_position.z)
		var gap := flat.length_squared()
		if gap < best_gap:
			best_gap = gap
			best = body
	return best


## The closer of the two outdoor doors. The DNA root is not that doorway.
func _hq_door_point(scene: Node) -> Vector3:
	var building := _hq_at(scene)
	if building == null:
		return _MISS
	var player := _player_flat(scene)
	var best := _MISS
	var best_gap := INF
	for index in 2:
		var door := _HQ.find_exterior_door(building, index)
		if door == null:
			continue
		var gap := _flat_gap(door.global_position, player)
		if gap < best_gap:
			best = door.global_position
			best_gap = gap
	return best


func _hq_at(scene: Node) -> Node3D:
	if is_instance_valid(_hq_scene) and _hq_scene == scene:
		if _hq != null and is_instance_valid(_hq):
			return _hq
		return null
	_hq_scene = scene
	_hq = _HQ.find_building(scene)
	return _hq


func _tunnel_toward(scene: Node, here: int, dest: int) -> Vector3:
	var dest_branch := _LINKS.branch_of(dest)
	var dest_hood := _LINKS.hood_of(dest)
	if here != 0 and _LINKS.branch_of(here) == dest_branch:
		return _MISS
	var player := _player_flat(scene)
	var exact: Node3D = null
	var hood_hit: Node3D = null
	var exact_gap := INF
	var hood_gap := INF
	for link in _tunnels_of(scene):
		if not is_instance_valid(link):
			continue
		var zone := _tunnel_zone(String(link.name))
		if zone == 0:
			continue
		var gap := _flat_gap(link.global_position, player)
		if _LINKS.branch_of(zone) == dest_branch and gap < exact_gap:
			exact = link
			exact_gap = gap
		elif _LINKS.hood_of(zone) == dest_hood and gap < hood_gap:
			hood_hit = link
			hood_gap = gap
	var chosen := exact if exact != null else hood_hit
	if chosen == null:
		chosen = _raw_shaft(scene, dest_branch)
	if chosen == null:
		return _MISS
	return chosen.global_position


## Cashbot and Lawbot keep the model's shaft name. Sellbot and Bossbot are
## renamed to linktunnel_ before this runs.
func _raw_shaft(scene: Node, dest_branch: int) -> Node3D:
	var file := scene.scene_file_path.get_file()
	var wanted := ""
	if file == "cashbot_trainyard.tscn" and dest_branch == 9200:
		wanted = "LinkTunnel1"
	elif file == "lawbot_courtyard.tscn" and dest_branch == 3300:
		wanted = "LinkTunnel1"
	if wanted.is_empty():
		return null
	return scene.find_child(wanted, true, false) as Node3D


func _nearest_street(scene: Node, here: int) -> Vector3:
	var hood := _LINKS.hood_of(here) if here != 0 else 0
	var player := _player_flat(scene)
	var best: Node3D = null
	var best_gap := INF
	for link in _tunnels_of(scene):
		if not is_instance_valid(link):
			continue
		var zone := _tunnel_zone(String(link.name))
		if zone == 0 or _LINKS.branch_of(zone) == _LINKS.hood_of(zone):
			continue
		if hood != 0 and _LINKS.hood_of(zone) != hood:
			continue
		var gap := _flat_gap(link.global_position, player)
		if gap < best_gap:
			best = link
			best_gap = gap
	if best == null:
		return _MISS
	return best.global_position


func _tunnels_of(scene: Node) -> Array[Node3D]:
	if is_instance_valid(_tunnel_scene) and _tunnel_scene == scene:
		return _tunnels
	_tunnel_scene = scene
	_tunnels.clear()
	_gather_tunnels(scene)
	return _tunnels


func _gather_tunnels(node: Node) -> void:
	var node_name := String(node.name)
	if node is Node3D and node_name.begins_with("linktunnel_"):
		_tunnels.append(node as Node3D)
	for child in node.get_children():
		_gather_tunnels(child)


func _tunnel_zone(node_name: String) -> int:
	var body := node_name.trim_prefix("linktunnel_")
	for part in body.split("_"):
		if part.is_valid_int():
			return int(part)
	return 0


func _player_flat(scene: Node) -> Vector2:
	var body := scene.get_node_or_null("Player") as Node3D
	if body == null:
		return Vector2.ZERO
	return Vector2(body.global_position.x, body.global_position.z)


func _flat_gap(point: Vector3, player: Vector2) -> float:
	return Vector2(point.x, point.z).distance_squared_to(player)


func _lines() -> String:
	var card := _tasks.tracked_card()
	if card.is_empty():
		return ""
	var caption := String(card.get("caption", ""))
	if caption.is_empty():
		return ""
	var parts: PackedStringArray = [caption]
	var building := String(card.get("building", ""))
	var location := String(card.get("location", ""))
	if bool(card.get("ready", false)):
		var who := String(card.get("return_name", ""))
		if who.is_empty():
			who = "an HQ Officer"
		parts.append("Return to " + who)
	else:
		var goal := int(card.get("goal", 1))
		if goal > 1 or bool(card.get("show_count", false)):
			parts.append("%d of %d" % [int(card.get("progress", 0)), goal])
		var kind := String(card.get("kind", ""))
		var where := String(card.get("where", ""))
		if kind != "visit" and kind != "track" and not where.is_empty() and where != building:
			parts.append(where)
	var street := _street_name(location)
	if not street.is_empty():
		parts.append(street)
	var playground := _playground_name(location)
	if not building.is_empty() and not playground.is_empty():
		parts.append(building + "/" + playground)
	elif not building.is_empty():
		parts.append(building)
	var ink := _UI.done_color() if bool(card.get("ready", false)) else _UI.progress_color()
	return "[color=#%s]%s[/color]" % [ink.to_html(false), " · ".join(parts)]


## Loopy Lane counts. "Playground" and "Any Street" do not.
func _street_name(location: String) -> String:
	var bits := location.split("\n", false)
	if bits.is_empty():
		return ""
	var street := String(bits[0])
	if street == "Playground" or street == "Any Street" or street == _playground_name(location):
		return ""
	return street


## The neighborhood, not the extra "Playground" street line.
func _playground_name(location: String) -> String:
	var bits := location.split("\n", false)
	for i in range(bits.size() - 1, -1, -1):
		var line := String(bits[i])
		if line != "Playground" and line != "Any Street":
			return line
	return ""
