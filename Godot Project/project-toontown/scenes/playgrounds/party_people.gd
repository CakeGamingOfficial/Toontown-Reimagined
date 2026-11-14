extends StaticBody3D

## DistributedNPCPartyPerson stands on party_person_left and party_person_right
## in the playground gate. createNpcsInZone gives the first party person the
## odd slot, which is the right locator, and the second person the left.
## Walking up asks the original question and opens the party planner.

const _GUI := preload("res://scenes/toons/toon_gui.gd")
const _BEANS := preload("res://scenes/toons/jellybeans.gd")
const _PARTY := preload("res://scenes/parties/toon_party.gd")
const _DIALOG := preload("res://assets/gui/tutorial/dialog/dialog_box.png")
const _OK_UP := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_UP.png")
const _OK_DOWN := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_DN.png")
const _OK_HOVER := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_Rllvr.png")
const _NO_UP := preload("res://assets/toons/gui/CloseBtn_UP.png")
const _NO_DOWN := preload("res://assets/toons/gui/CloseBtn_DN.png")
const _NO_HOVER := preload("res://assets/toons/gui/CloseBtn_Rllvr.png")
const _RATE := 1.05
const _REACH := 2.4
const _WAIT := 30.0
const _ASK := "Would you like to plan a new party right now?"
const _ON_YOUR_WAY := "Have fun planning your party!"
const _NEXT_TIME := "Maybe next time.  Have a good day!"
const _TOO_MANY := "You can only host one party at a time, sorry."
const _MIN_COST := "It costs a minimum of 100 jellybeans to plan a party."
const _TOO_LONG := "Need more time to think?"

# name, head, torso, legs, gender, arm, glove, leg, head, shirt, shirt color,
# shorts, shorts color. Sleeve indices are unused, the same as the clerks.
const _CREW := {
	"toontown_central.tscn": {
		"right": ["Party Planner Pumpkin", "sls", "ls", "m", "m", 10, 0, 9, 9, 0, 3, 0, 18],
		"left": ["Party Planner Polly", "sss", "ld", "m", "f", 10, 0, 9, 9, 0, 23, 0, 5],
	},
	"donalds_dock.tscn": {
		"right": ["Party Planner Pickles", "fls", "ms", "l", "m", 14, 0, 3, 3, 0, 1, 0, 13],
		"left": ["Party Planner Patty", "fss", "ms", "m", "f", 2, 0, 3, 3, 1, 6, 5, 6],
	},
	"the_burrrgh.tscn": {
		"right": ["Party Planner Pete", "cls", "ss", "m", "m", 18, 0, 17, 17, 1, 7, 1, 9],
		"left": ["Party Planner Penny", "css", "sd", "m", "f", 17, 0, 16, 16, 0, 24, 0, 9],
	},
	"minnies_melodyland.tscn": {
		"right": ["Party Planner Preston", "bll", "ls", "s", "m", 3, 0, 19, 19, 0, 8, 1, 12],
		"left": ["Party Planner Penelope", "bss", "md", "m", "f", 24, 0, 19, 19, 0, 24, 0, 12],
	},
	"daisy_gardens.tscn": {
		"right": ["Party Planner Pierce", "dls", "ms", "m", "m", 13, 0, 12, 12, 0, 1, 0, 6],
		"left": ["Party Planner Peggy", "dss", "md", "m", "f", 1, 0, 3, 3, 1, 5, 0, 5],
	},
	"donalds_dreamland.tscn": {
		"right": ["Party Planner Pebbles", "rss", "ls", "l", "m", 21, 0, 20, 20, 0, 12, 0, 11],
		"left": ["Party Planner Pearl", "rls", "md", "l", "f", 6, 0, 21, 21, 1, 11, 0, 11],
	},
}

var _group: Node
var _actor: ToonActor
var _origin: Node3D
var _busy := false
var _away := true
var _slow := false
var _line: PanelContainer
var _words: Label
var _line_left := 0.0
var _layer: CanvasLayer


static func place(host: Node) -> void:
	if host == null or Engine.is_editor_hint():
		return
	if host.find_child("PartyPeople", true, false) != null:
		return
	var crew: Dictionary = _CREW.get(host.scene_file_path.get_file(), {})
	if crew.is_empty():
		return
	var left := host.find_child("party_person_left", true, false) as Node3D
	var right := host.find_child("party_person_right", true, false) as Node3D
	if left == null and right == null:
		return
	var group := Node3D.new()
	group.name = "PartyPeople"
	host.add_child(group)
	_stand(left, crew["left"], "PartyPersonLeft", group)
	_stand(right, crew["right"], "PartyPersonRight", group)


static func _stand(origin: Node3D, row: Array, body_name: String, group: Node) -> void:
	if origin == null or row.is_empty():
		return
	var body := (load("res://scenes/playgrounds/party_people.gd") as GDScript).new() as StaticBody3D
	body.name = body_name
	origin.add_child(body)
	body.global_position = origin.global_position + Vector3(0.0, 0.02, 0.0)
	body.global_basis = Basis.IDENTITY
	var actor := ToonActor.new()
	actor.name = String(row[0])
	body.add_child(actor)
	actor.show_style(_style(row))
	_face(actor, origin)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.6
	shape.height = 3.0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, shape.height * 0.5, 0.0)
	body.add_child(collision)
	body.call("watch", actor, origin, group)


func watch(actor: ToonActor, origin: Node3D, group: Node) -> void:
	_actor = actor
	_origin = origin
	_group = group


func _process(delta: float) -> void:
	if _actor != null:
		_actor.set_locomotion(0.0, false, false, delta * _RATE)
	_line_left = maxf(_line_left - delta, 0.0)
	_place_line()
	if _busy:
		return
	var player := _player()
	if player == null:
		return
	var near := global_position.distance_to(player.global_position) <= _REACH
	if not near:
		_away = true
		return
	if not _away:
		return
	if _group != null and bool(_group.get_meta("talking", false)):
		return
	_away = false
	_busy = true
	_greet()


func _greet() -> void:
	if _group != null:
		_group.set_meta("talking", true)
	_hold(true)
	_face_player()
	ToonSpeech.speak(_actor, _ASK)
	var yes := await _ask(_ASK)
	if not is_inside_tree():
		_finish_talk()
		return
	if _slow:
		await _reply(_TOO_LONG)
	elif not yes:
		await _reply(_NEXT_TIME)
	elif _PARTY.hosting():
		await _reply(_TOO_MANY)
	elif _BEANS.pouch() + _BEANS.bank() < 100:
		await _reply(_MIN_COST)
	else:
		_say(_ON_YOUR_WAY, 1.2)
		var playground := _playground()
		var gate: Node = null
		if playground != null:
			gate = playground.get_node_or_null("PartyGate")
		if gate != null and gate.has_method("open_planner"):
			gate.call("open_planner")
		while is_inside_tree() and gate != null and is_instance_valid(gate) and gate.get_node_or_null("PartyPlanner") != null:
			await get_tree().process_frame
		_say("", 0.0)
	_finish_talk()


func _reply(text: String) -> void:
	_say(text, 2.2)
	var left := 2.2
	while left > 0.0:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		left -= get_process_delta_time()
	_say("", 0.0)


func _finish_talk() -> void:
	_slow = false
	if _origin != null and _actor != null:
		_face(_actor, _origin)
	_hold(false)
	if _group != null:
		_group.set_meta("talking", false)
	_busy = false


func _ask(line: String) -> bool:
	var host := Control.new()
	host.name = "PartyChoice"
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.z_index = 60
	host.set_meta("choice", 0)
	_layer_host().add_child(host)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(dim)
	var frame := TextureRect.new()
	frame.texture = _DIALOG
	frame.modulate = Color(1, 1, 0.75, 1)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(frame)
	var words := Label.new()
	words.text = line
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(words)
	var yes := _choice_button(host, "Yes", Vector2(0.24, -0.18), true)
	var no := _choice_button(host, "No", Vector2(-0.24, -0.18), false)
	yes.pressed.connect(func() -> void: host.set_meta("choice", 1))
	no.pressed.connect(func() -> void: host.set_meta("choice", 2))
	var view := host.get_viewport().get_visible_rect().size
	_GUI.place(frame, view, 0.0, 0.0, 1.55, 0.7)
	var px := maxi(int(round(0.035 * view.y * 0.5)), 1)
	_GUI.style_label(words, Color(0.05, 0.05, 0.05), px, Color(0, 0, 0, 0), 0)
	_GUI.place(words, view, 0.0, 0.12, 1.3, 0.22)
	var waited := 0.0
	while int(host.get_meta("choice")) == 0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if waited >= _WAIT:
			_slow = true
			host.set_meta("choice", 2)
		if not is_inside_tree() or not is_instance_valid(host):
			if is_instance_valid(host):
				host.queue_free()
			return false
		if Input.is_key_pressed(KEY_ESCAPE):
			host.set_meta("choice", 2)
	var agreed := int(host.get_meta("choice")) == 1
	host.queue_free()
	return agreed


func _choice_button(host: Control, text: String, at: Vector2, yes: bool) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _OK_UP if yes else _NO_UP
	button.texture_pressed = _OK_DOWN if yes else _NO_DOWN
	button.texture_hover = _OK_HOVER if yes else _NO_HOVER
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_GUI.button_sounds(button)
	host.add_child(button)
	var caption := Label.new()
	caption.text = text
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_STOP
	caption.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	caption.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			button.pressed.emit()
	)
	host.add_child(caption)
	var view := host.get_viewport().get_visible_rect().size
	_GUI.style_label(caption, Color(0, 0, 0), maxi(int(round(0.04 * view.y * 0.5)), 1), Color(0, 0, 0, 0), 0)
	_GUI.place(button, view, at.x, at.y, 0.12, 0.12)
	_GUI.place(caption, view, at.x, at.y - 0.11, 0.28, 0.06)
	return button


func _say(text: String, seconds: float) -> void:
	_line_left = seconds
	if text.is_empty():
		if _line != null:
			_line.visible = false
		return
	if _layer == null:
		_layer = CanvasLayer.new()
		_layer.layer = 24
		add_child(_layer)
	if _line == null:
		_line = PanelContainer.new()
		_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1, 1, 1, 0.98)
		box.border_color = Color(0.05, 0.05, 0.05)
		box.set_border_width_all(3)
		box.set_corner_radius_all(16)
		box.content_margin_left = 12
		box.content_margin_right = 16
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		_line.add_theme_stylebox_override("panel", box)
		_words = Label.new()
		_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_GUI.style_label(_words, Color(0.05, 0.05, 0.08), 22, Color(0, 0, 0, 0), 0)
		_line.add_child(_words)
		_layer.add_child(_line)
	_GUI.show_speech(_words, text, 22)
	_line.visible = true
	ToonSpeech.speak(_actor, text)


func _place_line() -> void:
	if _line == null or _actor == null:
		return
	if _line_left <= 0.0:
		_line.visible = false
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_line.visible = false
		return
	var point := _actor.global_position + Vector3(0.0, 3.6, 0.0)
	var head := _actor.find_child("def_head", true, false) as Node3D
	if head != null:
		point = head.global_position + Vector3(0.0, 0.7, 0.0)
	if camera.is_position_behind(point):
		_line.visible = false
		return
	_line.visible = true
	_line.reset_size()
	var screen := camera.unproject_position(point)
	_line.position = screen - Vector2(_line.size.x * 0.5, _line.size.y + 8.0)


func _face_player() -> void:
	var player := _player()
	if player == null or _actor == null:
		return
	var ahead := player.global_position - _actor.global_position
	ahead.y = 0.0
	if ahead.length_squared() < 0.0001:
		return
	var heading := rad_to_deg(atan2(-ahead.x, -ahead.z))
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	upright = upright.rotated(Vector3.UP, deg_to_rad(heading))
	_actor.transform.basis = upright


func _hold(holding: bool) -> void:
	var playground := _playground()
	if playground == null:
		return
	var toon := playground.get_node_or_null("PlaygroundToon")
	if toon != null and toon.has_method("hold_for_race"):
		toon.call("hold_for_race", holding)


func _player() -> Node3D:
	var playground := _playground()
	if playground == null:
		return null
	return playground.get_node_or_null("Player") as Node3D


func _playground() -> Node:
	var node := get_parent()
	while node != null:
		if node.get_node_or_null("PlaygroundToon") != null or node.get_node_or_null("PartyGate") != null:
			return node
		node = node.get_parent()
	return null


func _layer_host() -> Node:
	var playground := _playground()
	if playground != null:
		return playground
	return self


static func _style(row: Array) -> ToonStyle:
	var style := ToonStyle.new()
	style.first_name = String(row[0])
	style.head = String(row[1])
	style.torso = String(row[2])
	style.legs = String(row[3])
	style.gender = String(row[4])
	style.arm_color = int(row[5])
	style.glove_color = int(row[6])
	style.leg_color = int(row[7])
	style.head_color = int(row[8])
	style.top_tex = int(row[9])
	style.top_color = int(row[10])
	style.bot_tex = int(row[11])
	style.bot_color = int(row[12])
	return style


static func _face(actor: Node3D, origin: Node3D) -> void:
	var ahead := origin.to_global(Vector3(0.0, 1.0, 0.0)) - origin.global_position
	ahead.y = 0.0
	var heading := 0.0
	if ahead.length_squared() > 0.0001:
		heading = rad_to_deg(atan2(-ahead.x, -ahead.z))
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	upright = upright.rotated(Vector3.UP, deg_to_rad(heading))
	actor.transform.basis = upright
