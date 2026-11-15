extends CanvasLayer

## GroupPanel, GroupInvitee, and the Go countdown from DistributedBoardingParty.

const _DIALOG := preload("res://assets/gui/tutorial/dialog/dialog_box.png")

var _panel: Control
var _title: Label
var _names: VBoxContainer
var _dest: Label
var _go: Button
var _leave: Button
var _hide: Button
var _show: Button
var _prev: Button
var _next: Button
var _hidden := false
var _dialog: Control
var _dialog_text: Label
var _dialog_buttons: Array[Button] = []
var _clock: Label
var _confirm := -1.0
var _seen_note := 0
var _invite_leader := -1
var _asking := -1
var _quit_open := false
var _laid := Vector2.ZERO
var _listed := ""


func _ready() -> void:
	layer = 36
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	add_child(_panel)
	var plate := TextureRect.new()
	plate.texture = _DIALOG
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.modulate = Color(0.55, 0.85, 0.55, 1.0)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(plate)
	_title = _label(_panel)
	_names = VBoxContainer.new()
	_names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_names)
	_dest = _label(_panel)
	_prev = _text_button("<", _step_dest.bind(-1))
	_next = _text_button(">", _step_dest.bind(1))
	_go = _text_button("GO", _press_go)
	_leave = _text_button("Leave", _ask_leave)
	_panel.add_child(_prev)
	_panel.add_child(_next)
	_panel.add_child(_go)
	_panel.add_child(_leave)
	_hide = _text_button("Hide", _fold)
	_show = _text_button("Show Boarding Group", _unfold)
	add_child(_hide)
	add_child(_show)
	_show.visible = false
	_dialog = Control.new()
	_dialog.visible = false
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dialog)
	var card := TextureRect.new()
	card.texture = _DIALOG
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.modulate = Color(1.0, 0.89, 0.77, 1.0)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog.add_child(card)
	_dialog_text = _label(_dialog)
	_dialog_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_clock = _label(self)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.visible = false


func _process(delta: float) -> void:
	_read_notes()
	var group := BoardingParty.my_group()
	var me := ToonNet.peer_id()
	var member := BoardingParty.has_active_group() or (_members(group).size() > 1 and _members(group).has(me))
	_panel.visible = member and not _hidden
	_hide.visible = member and not _hidden
	_show.visible = member and _hidden
	if member:
		_fill(group, me)
	_invites(group, me)
	_tick_go(delta, group)
	var view := get_viewport().get_visible_rect().size
	if view != _laid:
		_laid = view
		_layout(view)


func _fill(group: Dictionary, me: int) -> void:
	var leader := int(group.get("leader", -1))
	_title.text = "Boarding Group"
	_leave.text = "Disband" if leader == me else "Leave"
	var listed := ""
	for id in _members(group):
		var called := _toon_name(int(id))
		listed += "%d:%s|" % [int(id), called]
	if listed != _listed:
		_listed = listed
		for child in _names.get_children():
			child.queue_free()
		for id in _members(group):
			var row := _label(_names)
			var called := _toon_name(int(id))
			row.text = "%s  (Leader)" % called if int(id) == leader else called
		_laid = Vector2.ZERO
	var dest := BoardingParty.dest_name(group)
	var mine := leader == me
	_prev.visible = mine and _confirm < 0.0 and _pull(group).is_empty()
	_next.visible = _prev.visible
	_go.visible = mine
	_go.disabled = not _pull(group).is_empty()
	if _confirm >= 0.0:
		_go.text = "Click Again to\nCancel Go"
	else:
		_go.text = "GO"
	if mine:
		_dest.text = dest
	else:
		_dest.text = "Going To:\n%s" % dest


func _invites(group: Dictionary, me: int) -> void:
	if group.is_empty():
		_close_dialog()
		return
	var invites: Array = group.get("invites", [])
	if invites.has(me) and not _quit_open:
		var leader := int(group.get("leader", -1))
		if _invite_leader != leader:
			_invite_leader = leader
			_asking = -1
			_ask("%s would like you to join their Boarding Group." % _toon_name(leader), ["OK", "No"], [_accept_invite, _reject_invite])
		return
	var asked: Dictionary = group.get("asked", {})
	var mine := -1
	for key in asked.keys():
		if int(asked[key]) == me:
			mine = int(key)
			break
	if mine >= 0 and not _quit_open:
		if _asking != mine:
			_asking = mine
			_invite_leader = -1
			_ask("Inviting %s to your Boarding Group." % _toon_name(mine), ["Cancel"], [_cancel_invite])
		return
	if not _quit_open and (_invite_leader >= 0 or _asking >= 0):
		_invite_leader = -1
		_asking = -1
		_close_dialog()


func _tick_go(delta: float, group: Dictionary) -> void:
	if _confirm >= 0.0:
		_confirm = maxf(_confirm - delta, 0.0)
		_clock.visible = true
		_clock.text = "Confirming...\n%d" % ceili(_confirm)
		if _confirm <= 0.0:
			_confirm = -1.0
			BoardingParty.request("go", {})
		return
	var pull := _pull(group)
	if pull.is_empty():
		_clock.visible = false
		return
	var left := float(pull.get("at", 0.0)) - ToonNet.now()
	if left <= 0.0:
		_clock.visible = false
		return
	_clock.visible = true
	_clock.text = "Going to\n%s in %d" % [BoardingParty.dest_name(group), ceili(left)]


func _read_notes() -> void:
	for item in BoardingParty.snapshot().get("notes", []):
		if not (item is Dictionary):
			continue
		var note: Dictionary = item
		var id := int(note.get("id", 0))
		if id <= _seen_note or int(note.get("to", -1)) != ToonNet.peer_id():
			continue
		_seen_note = maxi(_seen_note, id)
		var text := String(note.get("text", ""))
		if text == "":
			continue
		var tree := get_tree()
		if tree == null or tree.current_scene == null:
			continue
		var toon := tree.current_scene.get_node_or_null("PlaygroundToon")
		if toon != null and toon.has_method("show_notice"):
			toon.call("show_notice", text)


func _press_go() -> void:
	if _confirm >= 0.0:
		_confirm = -1.0
		_clock.visible = false
		return
	if not _pull(BoardingParty.my_group()).is_empty():
		return
	_confirm = 3.0


func _step_dest(step: int) -> void:
	var group := BoardingParty.my_group()
	var info := BoardingParty.zone_info(String(group.get("zone", "")))
	var count := (info.get("names", []) as Array).size()
	if count <= 0:
		return
	BoardingParty.request("dest", {"index": posmod(int(group.get("dest", 0)) + step, count)})


func _ask_leave() -> void:
	_quit_open = true
	_ask("Are you sure you want to quit this Boarding Group?", ["Yes", "No"], [_do_leave, _keep_group])


func _do_leave() -> void:
	_quit_open = false
	_close_dialog()
	BoardingParty.request("leave", {})


func _keep_group() -> void:
	_quit_open = false
	_close_dialog()


func _accept_invite() -> void:
	var leader := _invite_leader
	_close_dialog()
	BoardingParty.request("accept", {"leader": leader})


func _reject_invite() -> void:
	var leader := _invite_leader
	_close_dialog()
	BoardingParty.request("reject", {"leader": leader})


func _cancel_invite() -> void:
	var who := _asking
	_close_dialog()
	BoardingParty.request("cancel", {"who": who})


func _fold() -> void:
	_hidden = true


func _unfold() -> void:
	_hidden = false


func _ask(text: String, captions: Array, actions: Array) -> void:
	_close_dialog()
	_dialog.visible = true
	_dialog_text.text = text
	for index in captions.size():
		var button := _text_button(String(captions[index]), actions[index])
		_dialog.add_child(button)
		_dialog_buttons.append(button)
	_laid = Vector2.ZERO


func _close_dialog() -> void:
	_dialog.visible = false
	for button in _dialog_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_dialog_buttons.clear()


func _layout(view: Vector2) -> void:
	var unit := view.y * 0.5
	ToonGui.place(_panel, view, -1.05, 0.15, 0.72, 0.95)
	_place_in(_title, 8.0, 8.0, _panel.size.x - 16.0, unit * 0.08)
	ToonGui.style_label(_title, Color(0.05, 0.2, 0.05), int(unit * 0.04), Color(0, 0, 0, 0), 0)
	_names.position = Vector2(16.0, unit * 0.1)
	_names.size = Vector2(_panel.size.x - 32.0, unit * 0.42)
	_names.add_theme_constant_override("separation", 2)
	for child in _names.get_children():
		if child is Label:
			ToonGui.style_label(child as Label, Color.BLACK, int(unit * 0.034), Color(0, 0, 0, 0), 0)
	_place_in(_dest, 36.0, _panel.size.y - unit * 0.38, _panel.size.x - 72.0, unit * 0.1)
	ToonGui.style_label(_dest, Color(0.05, 0.15, 0.35), int(unit * 0.032), Color(0, 0, 0, 0), 0)
	_place_in(_prev, 8.0, _panel.size.y - unit * 0.38, 28.0, unit * 0.08)
	_place_in(_next, _panel.size.x - 36.0, _panel.size.y - unit * 0.38, 28.0, unit * 0.08)
	_place_in(_go, 16.0, _panel.size.y - unit * 0.26, _panel.size.x - 32.0, unit * 0.1)
	_place_in(_leave, 16.0, _panel.size.y - unit * 0.14, _panel.size.x - 32.0, unit * 0.09)
	_style_button(_go, unit)
	_style_button(_leave, unit)
	_style_button(_prev, unit)
	_style_button(_next, unit)
	ToonGui.place(_hide, view, -1.48, 0.15, 0.16, 0.28)
	ToonGui.place(_show, view, -1.55, 0.15, 0.42, 0.16)
	_style_button(_hide, unit)
	_style_button(_show, unit)
	ToonGui.place(_dialog, view, 0.15, 0.35, 1.15, 0.7)
	_place_in(_dialog_text, _dialog.size.x * 0.1, _dialog.size.y * 0.12, _dialog.size.x * 0.8, _dialog.size.y * 0.42)
	ToonGui.style_label(_dialog_text, Color.BLACK, int(unit * 0.036), Color(0, 0, 0, 0), 0)
	var count := _dialog_buttons.size()
	for index in count:
		var button := _dialog_buttons[index]
		var span := _dialog.size.x * 0.34
		var x := _dialog.size.x * 0.5 + (float(index) - float(count - 1) * 0.5) * (span + 12.0) - span * 0.5
		_place_in(button, x, _dialog.size.y * 0.64, span, _dialog.size.y * 0.18)
		_style_button(button, unit)
	ToonGui.place(_clock, view, 0.0, -0.55, 0.9, 0.22)
	ToonGui.style_sign(_clock, Color(0.45, 0.45, 0.45), int(unit * 0.07), Color(0, 0, 0, 0), 0)


func _label(parent: Node) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _text_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button


func _style_button(button: Button, unit: float) -> void:
	if button == null:
		return
	button.add_theme_font_override("font", ToonGui.font())
	button.add_theme_font_size_override("font_size", int(unit * 0.03))


func _place_in(control: Control, x: float, y: float, width: float, height: float) -> void:
	if control == null:
		return
	control.position = Vector2(x, y)
	control.size = Vector2(width, height)


func _pull(group: Dictionary) -> Dictionary:
	var found: Variant = group.get("pull", {})
	if found is Dictionary:
		return found
	return {}


func _members(group: Dictionary) -> Array:
	var found: Variant = group.get("members", [])
	if found is Array:
		return found
	return []


func _toon_name(peer: int) -> String:
	var called := String(ToonNet.latest("toon:%d" % peer).get("name", "")).strip_edges()
	if called == "":
		return "A Toon"
	return called
