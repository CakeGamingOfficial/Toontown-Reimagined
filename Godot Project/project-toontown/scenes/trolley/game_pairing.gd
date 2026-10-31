extends "res://scenes/trolley/trolley_minigame.gd"

## Toon Memory Game. The cards are phase_3.5 playingCard: front, back, and logo.
## Match two cards of the same rank. The bonus card pays an extra point.

const _ICONS := [
	"res://assets/gui/tutorial/gags/inventory_feather.png",
	"res://assets/gui/tutorial/gags/inventory_bannana_peel.png",
	"res://assets/gui/tutorial/gags/inventory_anvil.png",
	"res://assets/gui/tutorial/gags/inventory_tart.png",
	"res://assets/gui/tutorial/gags/inventory_bikehorn.png",
	"res://assets/gui/tutorial/gags/inventory_squirt_flower.png",
	"res://assets/gui/tutorial/gags/inventory_1dollarbill.png",
	"res://assets/gui/tutorial/gags/inventory_safe_box.png",
]
const _COLORS := [
	Color(0.93, 0.27, 0.28), Color(0.55, 0.82, 0.32), Color(0.35, 0.82, 0.95),
	Color(0.46, 0.38, 0.82), Color(0.71, 0.23, 0.44), Color(0.29, 0.33, 0.73),
	Color(0.24, 0.74, 0.52), Color(0.97, 0.69, 0.70),
]
## playingCard is 4.55 by 3.32. This scale fits the original 4-unit grid.
const _CARD_SCALE := 0.7
var _cards: Array[Node3D] = []
var _ranks: Array[int] = []
var _faces: Array[Node3D] = []
var _open: Array[int] = []
var _matched: Array[int] = []
var _flips := 0
var _lock := false
var _bonus := 0
var _px := 0.0
var _py := 0.0


func _init() -> void:
	title = "Toon Memory Game"
	instructions = "Press Delete to open a card. Match 2 cards to score a point.  Make a match with the bonus glow and earn an extra point.  Earn more points by keeping the flips low."
	duration = 120.0


func _build() -> void:
	_show("res://assets/minigames/memory_room.glb")
	var deck: Array[int] = []
	for rank in 8:
		for _suit in 4:
			deck.append(rank)
	deck.shuffle()
	_bonus = randi() % deck.size()
	for index in deck.size():
		var col := index % 8
		var row := int(index / 8)
		var card := _lay_card(float(col) * 4.0, float(row) * 4.0, deck[index], index == _bonus)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3.2, 2.3, 0.35)
		shape.shape = box
		body.add_child(shape)
		body.set_meta("card", index)
		card.add_child(body)
		_cards.append(card)
		_ranks.append(deck[index])
	_make_toon(_panda(0.0, 0.0, 0.0))
	_toon.rotation_degrees.y = 45.0
	_aim(14.0, -8.93, 33.45, 14.0, 6.0, 0.0)
	show_board("points")


func _play(delta: float) -> void:
	var move := _stick()
	_px = clampf(_px + move.x * 10.0 * delta, -1.0, 29.0)
	_py = clampf(_py + move.y * 10.0 * delta, -1.0, 14.0)
	_toon.position = _panda(_px, _py, 0.0)
	_toon.set_locomotion(move.length() * 8.0, false, false, delta)


func _unhandled_input(event: InputEvent) -> void:
	if not playing or _lock:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_DELETE:
			var nearest := _nearest()
			if nearest >= 0:
				_flip(nearest)
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
			return
		var origin := _camera.project_ray_origin(click.position)
		var end := origin + _camera.project_ray_normal(click.position) * 80.0
		var query := PhysicsRayQueryParameters3D.create(origin, end)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return
		var collider := hit["collider"] as Node
		if collider != null and collider.has_meta("card"):
			_flip(int(collider.get_meta("card")))


func _nearest() -> int:
	var best := -1
	var gap := 3.6
	for index in _cards.size():
		if _matched.has(index):
			continue
		var dist := _cards[index].position.distance_to(_toon.position)
		if dist < gap:
			gap = dist
			best = index
	return best


func _flip(index: int) -> void:
	if not playing or _lock or _matched.has(index) or _open.has(index):
		return
	_open.append(index)
	_faces[index].visible = true
	_turn(_cards[index], true)
	_flips += 1
	_sfx("MG_pairing_card_flip_face_up")
	if index == _bonus:
		_sfx("MG_pairing_bonus_moves", 0.7)
	if _open.size() < 2:
		_note_flips()
		return
	_lock = true
	if _ranks[_open[0]] == _ranks[_open[1]]:
		var bonus := _open.has(_bonus)
		_matched.append(_open[0])
		_matched.append(_open[1])
		score += 2 if bonus else 1
		_sfx("MG_pairing_match_bonus_both" if bonus else "MG_pairing_match")
		_cards[_open[0]].visible = false
		_cards[_open[1]].visible = false
		_open.clear()
		_lock = false
		_note_flips()
		if _matched.size() >= _ranks.size():
			_sfx("MG_pairing_all_matched")
			_bonus_score()
			_end()
	else:
		_note_flips()
		_turn_down()


func _turn_down() -> void:
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return
	for shown in _open:
		_turn(_cards[shown], false)
		_faces[shown].visible = false
		_sfx("MG_pairing_card_flip_face_down", 0.6)
	_open.clear()
	_lock = false


func _note_flips() -> void:
	if _board != null:
		_board.note_flip(_flips, int(_matched.size() / 2))


func _bonus_score() -> void:
	var matches := _matched.size() / 2
	var ideal := maxi(int(round(float(matches) * 2.0 * 1.6)), 2)
	var extra := 0
	if _flips < ideal:
		extra = matches
	elif _flips < ideal * 2:
		extra = int(round(float(matches) * float(ideal * 2 - _flips) / float(ideal)))
	score += extra


func _lay_card(x: float, y: float, rank: int, bonus: bool) -> Node3D:
	var holder := Node3D.new()
	add_child(holder)
	holder.position = _panda(x, y, 0.08)
	# The exported card stands up. This pitch lays it flat with the back on top.
	holder.rotation_degrees.x = -90.0
	var model := _prop("res://assets/minigames/playing_card.glb")
	if model == null:
		model = _box(Vector3(3.2, 2.3, 0.12), _COLORS[rank])
		holder.add_child(model)
	else:
		holder.add_child(model)
		model.scale = Vector3(_CARD_SCALE, _CARD_SCALE, _CARD_SCALE)
		var front := model.find_child("card_front", true, false)
		if front != null:
			_tint(front, _COLORS[rank])
		var logo := model.find_child("logo", true, false) as Node3D
		if logo != null:
			logo.rotation_degrees.y = 180.0
	var icon := _icon(_ICONS[rank])
	model.add_child(icon)
	icon.position = Vector3(0.0, 0.0, -0.08)
	icon.rotation_degrees.y = 180.0
	icon.visible = false
	var skin := icon.material_override as StandardMaterial3D
	if skin != null:
		skin.cull_mode = BaseMaterial3D.CULL_BACK
	_faces.append(icon)
	if bonus:
		_place_glow(holder.position)
	return holder


func _turn(holder: Node3D, face_up: bool) -> void:
	var prior: Variant = holder.get_meta("flip", null)
	if prior is Tween and (prior as Tween).is_valid():
		(prior as Tween).kill()
	var tween := create_tween()
	holder.set_meta("flip", tween)
	tween.tween_property(holder, "rotation_degrees:x", 90.0 if face_up else -90.0, 0.25)


func _place_glow(at: Vector3) -> void:
	var sign := _prop("res://assets/minigames/garden_sign.glb")
	if sign == null:
		return
	add_child(sign)
	sign.position = at + Vector3(0.0, 0.15, 0.0)
	sign.scale = Vector3(1.9, 1.9, 1.9)
	_keep_named(sign, "glow")


func _keep_named(root: Node, keep: String) -> void:
	if root is MeshInstance3D and root.name != keep:
		(root as MeshInstance3D).visible = false
	for child in root.get_children():
		_keep_named(child, keep)


func _icon(path: String) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.2, 2.2)
	mesh_node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if ResourceLoader.exists(path):
		mat.albedo_texture = load(path)
	mesh_node.material_override = mat
	return mesh_node
