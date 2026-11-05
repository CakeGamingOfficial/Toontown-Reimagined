extends "res://scenes/trolley/trolley_minigame.gd"

## Toon Memory Game. The cards are phase_3.5 playingCard: front, back, and logo.
## The back logo is the Reimagined mark. Match two cards of the same rank.
## The bonus card pays an extra point.

const _LOGO := preload("res://assets/gui/loading/toontown_logo.png")

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
## OrthoDrive on the pairing game. Speed 11 is a run. One frame never moves more than 1.
const _TOON_SPEED := 11.0
const _MAX_FRAME_MOVE := 1.0
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
var _heading_goal := 0.0
var _rest_heading := 0.0
var _rest_pending := 0.0
var _rest_wait := 0.0
var _last_x := 0
var _last_y := 0
var _glow: Node3D
var _bonus_order: Array[int] = []
var _bonus_index := -1
var _played := 0.0
var _logo_mat: StandardMaterial3D


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
	for index in deck.size():
		var col := index % 8
		var row := int(index / 8)
		var card := _lay_card(float(col) * 4.0, float(row) * 4.0, deck[index])
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
	_bonus_order = _bonus_path()
	_glow = _make_glow()
	_seat_glow(0, false)
	_make_toon(_panda(0.0, 0.0, 0.0))
	# A single player starts at the corner, facing the board.
	_toon.rotation_degrees.y = 0.0
	_toon.set_locomotion(0.0, false, false, 0.0)
	# Closer than the old 33-unit pullback, with a margin past a tight crop of the grid.
	_aim(14.0, -5.5, 20.7, 14.0, 6.0, 0.0)
	show_board("points")


func _play(delta: float) -> void:
	var move := _stick()
	var x_vel := int(move.x)
	var y_vel := int(move.y)
	_steer(x_vel, y_vel, delta)
	var speed := 0.0
	if x_vel != 0 or y_vel != 0:
		var step := Vector2(float(x_vel), float(y_vel)).normalized() * _TOON_SPEED * delta
		if step.length() > _MAX_FRAME_MOVE:
			step = step.normalized() * _MAX_FRAME_MOVE
		_px += step.x
		_py += step.y
		speed = _TOON_SPEED
	# The board is 8 by 5 card slots. The toon stays inside that rectangle.
	_px = clampf(_px, 0.0, 28.0)
	_py = clampf(_py, 0.0, 16.0)
	_toon.position = _panda(_px, _py, 0.0)
	var lift: float = 0.15 if _nearest() >= 0 else 0.0
	_toon.position = _panda(_px, _py, lift)
	_toon.set_locomotion(speed, false, false, delta)
	_played += delta
	_tick_glow()


## OrthoDrive turns toward the keys, then back to the last held heading when they are released.
func _steer(x_vel: int, y_vel: int, delta: float) -> void:
	if _rest_wait > 0.0:
		_rest_wait = maxf(_rest_wait - delta, 0.0)
		if _rest_wait == 0.0:
			_rest_heading = _rest_pending
	if x_vel != _last_x or y_vel != _last_y:
		_rest_wait = 0.0
		if x_vel == 0 and y_vel == 0:
			_heading_goal = _rest_heading
		else:
			var heading := _move_heading(x_vel, y_vel)
			var was_diagonal := _last_x != 0 and _last_y != 0
			var now_diagonal := x_vel != 0 and y_vel != 0
			if was_diagonal and not now_diagonal:
				_rest_pending = heading
				_rest_wait = 0.05
			else:
				_rest_heading = heading
			_heading_goal = heading
		_last_x = x_vel
		_last_y = y_vel
	var current := deg_to_rad(_toon.rotation_degrees.y)
	var goal := deg_to_rad(_heading_goal)
	_toon.rotation_degrees.y = rad_to_deg(rotate_toward(current, goal, deg_to_rad(900.0) * delta))


## OrthoDrive's heading table. Panda heading 0 faces +Y, which is this toon's yaw 0.
func _move_heading(x_vel: int, y_vel: int) -> float:
	if x_vel == 0 and y_vel > 0:
		return 0.0
	if x_vel == 0 and y_vel < 0:
		return 180.0
	if x_vel > 0 and y_vel == 0:
		return -90.0
	if x_vel < 0 and y_vel == 0:
		return 90.0
	if x_vel > 0 and y_vel > 0:
		return -45.0
	if x_vel < 0 and y_vel > 0:
		return 45.0
	if x_vel > 0 and y_vel < 0:
		return -135.0
	return 135.0


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
		# The matched cards fade out over a second, then hide.
		_fade_card(_cards[_open[0]])
		_fade_card(_cards[_open[1]])
		_open.clear()
		_lock = false
		_note_flips()
		if _matched.size() >= _ranks.size():
			_lock = true
			_sfx("MG_pairing_all_matched")
			_bonus_score()
			await get_tree().create_timer(1.0).timeout
			if is_inside_tree():
				_end()
	else:
		_note_flips()
		_turn_down()


func _turn_down() -> void:
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return
	var shown: Array[int] = []
	shown.append_array(_open)
	for index in shown:
		_turn(_cards[index], false)
		_sfx("MG_pairing_card_flip_face_down", 0.6)
	_open.clear()
	_lock = false
	await get_tree().create_timer(0.25).timeout
	if not is_inside_tree():
		return
	for index in shown:
		_faces[index].visible = false


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


func _lay_card(x: float, y: float, rank: int) -> Node3D:
	var holder := Node3D.new()
	add_child(holder)
	holder.position = _panda(x, y, 0.08)
	# Pitch +90 puts card_back and the logo toward the camera. Pitch -90 shows card_front.
	holder.rotation_degrees.x = 90.0
	var model := _prop("res://assets/minigames/playing_card.glb")
	if model == null:
		model = _box(Vector3(3.2, 2.3, 0.12), _COLORS[rank])
		holder.add_child(model)
	else:
		holder.add_child(model)
		model.scale = Vector3(_CARD_SCALE, _CARD_SCALE, _CARD_SCALE)
		# Spins the card in its plane so the back and the gag are right side up.
		model.rotate_object_local(Vector3.UP, PI)
		var front := model.find_child("card_front", true, false)
		if front != null:
			_tint(front, _COLORS[rank])
		var logo := model.find_child("logo", true, false) as MeshInstance3D
		if logo != null:
			logo.rotation_degrees.y = 180.0
			logo.material_override = _logo_skin()
			# The old wordmark quad is wider than it is tall. Square it for this mark.
			var span := logo.mesh.get_aabb().size if logo.mesh != null else Vector3.ONE
			if span.x > 0.01:
				logo.scale.x *= span.z / span.x
	var icon := _icon(_ICONS[rank])
	model.add_child(icon)
	# card_front is centered just left of the origin. Local -Z is the front side
	# once the card is pitched, and a yaw of 180 lays the quad flat on that side.
	icon.position = Vector3(-0.175, 0.0, -0.04)
	icon.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	icon.visible = false
	_faces.append(icon)
	return holder


func _turn(holder: Node3D, face_up: bool) -> void:
	# get_meta errors when the key is missing, even if a default is passed.
	if holder.has_meta("flip"):
		var prior: Variant = holder.get_meta("flip")
		if prior is Tween and (prior as Tween).is_valid():
			(prior as Tween).kill()
	var tween := create_tween()
	holder.set_meta("flip", tween)
	tween.tween_property(holder, "rotation_degrees:x", -90.0 if face_up else 90.0, 0.25)


## The glow is the garden-sign glow, scaled like the original bonus marker.
func _make_glow() -> Node3D:
	var sign := _prop("res://assets/minigames/garden_sign.glb")
	if sign == null:
		return null
	add_child(sign)
	sign.scale = Vector3(2.5, 2.5, 2.5)
	_keep_named(sign, "glow")
	return sign


## calcBonusTraversal walks every card, two columns at a time.
func _bonus_path() -> Array[int]:
	var order: Array[int] = []
	var half := 4
	for i in half:
		for side in 2:
			var col := i + side * half
			for row in 5:
				var card := row * 8 + col
				if card >= 0 and card < _cards.size():
					order.append(card)
	return order


func _tick_glow() -> void:
	if _bonus_order.is_empty():
		return
	var index := int(_played / 0.5) % _bonus_order.size()
	if index == _bonus_index:
		return
	_seat_glow(index, true)


func _seat_glow(index: int, chime: bool) -> void:
	_bonus_index = index
	_bonus = _bonus_order[index]
	if _glow != null:
		_glow.position = _cards[_bonus].position + Vector3(0.0, 0.05, 0.0)
	if chime:
		_sfx("MG_pairing_bonus_moves", 0.25)


func _fade_card(card: Node3D) -> void:
	var mats: Array[StandardMaterial3D] = []
	_collect_fade(card, mats)
	var tween := create_tween()
	tween.tween_method(_paint_fade.bind(mats), 1.0, 0.0, 1.0)
	tween.tween_callback(card.hide)


func _collect_fade(node: Node, mats: Array[StandardMaterial3D]) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var mat: StandardMaterial3D = mesh.material_override as StandardMaterial3D
		if mat == null:
			var current := mesh.get_active_material(0)
			if current is StandardMaterial3D:
				mat = (current as StandardMaterial3D).duplicate() as StandardMaterial3D
			else:
				mat = StandardMaterial3D.new()
		else:
			mat = mat.duplicate() as StandardMaterial3D
		mesh.material_override = mat
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mats.append(mat)
	for child in node.get_children():
		_collect_fade(child, mats)


func _paint_fade(alpha: float, mats: Array[StandardMaterial3D]) -> void:
	for mat in mats:
		var color := mat.albedo_color
		color.a = alpha
		mat.albedo_color = color


func _keep_named(root: Node, keep: String) -> void:
	if root is MeshInstance3D and root.name != keep:
		(root as MeshInstance3D).visible = false
	for child in root.get_children():
		_keep_named(child, keep)


func _logo_skin() -> StandardMaterial3D:
	if _logo_mat != null:
		return _logo_mat
	_logo_mat = StandardMaterial3D.new()
	_logo_mat.albedo_texture = _LOGO
	_logo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_logo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_logo_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _logo_mat


func _icon(path: String) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.2, 2.2)
	mesh_node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if ResourceLoader.exists(path):
		mat.albedo_texture = load(path)
	mesh_node.material_override = mat
	return mesh_node
