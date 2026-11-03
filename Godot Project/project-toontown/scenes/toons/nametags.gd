class_name Nametags
extends Node

## One board can follow every toon and cog in an area. Cog names sit on
## phase_3/models/props/panel, tinted with the CCSuit nametag colors.

const _TAG_BODY := ["legs", "hands", "torso", "arms", "node", "drop_shadow", "CorpIcon"]
## phase_3/models/props/panel, the card NametagGlobals.setNametagCard installs.
const _NAME_PANEL := preload("res://assets/gui/nametag/name_panel.png")
# NametagGlobals CCSuit card and name colors. Ready, rollover, depressed.
const _SUIT_CARD := Color(0.8, 0.8, 0.8, 0.5)
const _SUIT_CARD_OVER := Color(1.0, 1.0, 1.0, 1.0)
const _SUIT_CARD_DOWN := Color(0.2, 0.2, 0.2, 0.6)
const _SUIT_INK := Color(0.0, 0.0, 0.0, 1.0)
const _SUIT_INK_OVER := Color(0.5, 0.5, 0.5, 1.0)
const _SUIT_INK_DOWN := Color(1.0, 1.0, 1.0, 1.0)
const _GM_WHISTLE := preload("res://assets/gui/nametag/gm_whistle.png")
const _GM_FIST := preload("res://assets/gui/nametag/gm_fist.png")
const _GM_CONNECTED := preload("res://assets/gui/nametag/gm_connected.png")

var camera: Camera3D
var layer: CanvasLayer
## Return true to hide this card for one frame. The toontorial uses it for
## Tom's shop and for a wall between the camera and an NPC.
var occlude: Callable = Callable()

signal cog_clicked(actor: Node3D, tag: Control)
signal friend_clicked(actor: Node3D)
signal toon_clicked(actor: Node3D)

static var picking_friends := false

var _tags: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("nametag_boards")


func add(actor: Node3D, text: String, kind: String = "player", text_tint: Color = Color(0, 0, 0, 0)) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text_color := Color(0.25, 0.28, 0.75)
	var face := ToonGui.font()
	if kind == "npc":
		text_color = text_tint if text_tint.a > 0.0 else Color(0.93, 0.45, 0.14)
	elif kind == "cog":
		text_color = _SUIT_INK
		face = ToonGui.suit_font()
	if kind == "cog":
		panel.add_theme_stylebox_override("panel", _suit_card())
	else:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1.0, 1.0, 1.0, 0.55)
		box.set_corner_radius_all(4)
		box.content_margin_left = 4
		box.content_margin_right = 4
		box.content_margin_top = 1
		box.content_margin_bottom = 1
		panel.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ToonGui.style_label(label, text_color, 16, Color(0, 0, 0, 0), 0)
	if face:
		label.add_theme_font_override("font", face)
	panel.add_child(label)
	panel.visible = false
	if kind == "cog":
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.z_index = 35
		panel.set_meta("cog_name", text.get_slice("\n", 0))
		panel.gui_input.connect(_on_cog_tag.bind(panel, actor))
		panel.mouse_entered.connect(_suit_look.bind(panel, label, true))
		panel.mouse_exited.connect(_suit_look.bind(panel, label, false))
	if layer != null:
		layer.add_child(panel)
	# Measured once, from the resting head. A live head would bob the card.
	# The scale is remembered so a teleport hole shrinks the card with the toon.
	var born := actor.global_transform.basis.get_scale().y
	_tags.append({
		"label": panel,
		"actor": actor,
		"lift": _lift(actor),
		"scale": born,
		"kind": kind,
		"plain": text,
		"gm": -1,
	})
	return panel


## The margin board reads these. The 3D card stays up while the head is on screen.
func cards() -> Array:
	var rows: Array = []
	for item in _tags:
		rows.append({
			"actor": item.get("actor"),
			"kind": String(item.get("kind", "")),
			"plain": String(item.get("plain", "")),
			"lift": float(item.get("lift", 3.2)),
		})
	return rows


func release(actor: Node3D) -> void:
	var kept: Array[Dictionary] = []
	for item in _tags:
		var raw: Variant = item.get("actor")
		var label := item["label"] as Control
		if raw == actor:
			if is_instance_valid(label):
				label.queue_free()
			var icon: TextureRect = item.get("icon")
			if icon != null and is_instance_valid(icon):
				icon.queue_free()
			_free_chat(item)
			continue
		kept.append(item)
	_tags = kept


func place() -> void:
	if camera == null:
		return
	var kept: Array[Dictionary] = []
	for item in _tags:
		var label := item["label"] as Control
		var raw: Variant = item.get("actor")
		if not is_instance_valid(raw):
			if is_instance_valid(label):
				label.queue_free()
			var gone: TextureRect = item.get("icon")
			if gone != null and is_instance_valid(gone):
				gone.queue_free()
			_free_chat(item)
			continue
		var actor := raw as Node3D
		if actor == null or not actor.visible or not actor.is_visible_in_tree():
			if is_instance_valid(label):
				label.visible = false
			_hide_icon(item)
			_hide_chat(item)
			kept.append(item)
			continue
		kept.append(item)
		_sync_gm(item)
		var lift := float(item.get("lift", 3.6))
		var born := float(item.get("scale", 1.0))
		var now := actor.global_transform.basis.get_scale().y
		if born > 0.05 and now > 0.001:
			lift *= now / born
		var point := actor.global_position + Vector3(0.0, lift, 0.0)
		if occlude.is_valid() and bool(occlude.call(actor, point)):
			label.visible = false
			_hide_icon(item)
			_hide_chat(item)
			continue
		if camera.is_position_behind(point):
			label.visible = false
			_hide_icon(item)
			_hide_chat(item)
			continue
		# Suit nametags are world cards on the cog. An off-screen suit does not
		# leave its name pinned to the edge of the view.
		if String(item.get("kind", "")) == "cog" and not _in_view(point):
			label.visible = false
			_hide_icon(item)
			_hide_chat(item)
			continue
		_fit(label, point)
		_place(label, point)
		_place_icon(item, label)
		_place_chat(item, label, actor)
		_arm_friend(item, label)
	_tags = kept


func _on_cog_tag(event: InputEvent, tag: Control, actor: Node3D) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	var label := tag.get_child(0) as Label
	if mouse.pressed:
		tag.set_meta("suit_down", true)
		if label != null:
			_suit_colors(tag, label, _SUIT_CARD_DOWN, _SUIT_INK_DOWN)
	else:
		tag.set_meta("suit_down", false)
		if label != null:
			_suit_look(tag, label, true)
	if not mouse.pressed:
		return
	var host := get_parent()
	if host != null and host.has_method("in_cutscene") and bool(host.call("in_cutscene")):
		return
	tag.accept_event()
	cog_clicked.emit(actor, tag)


func _on_friend_tag(event: InputEvent, actor: Node) -> void:
	if not picking_friends:
		return
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if not (actor is Node3D) or not is_instance_valid(actor):
		return
	get_viewport().set_input_as_handled()
	friend_clicked.emit(actor as Node3D)


func _on_toon_tag(event: InputEvent, actor: Node) -> void:
	if picking_friends:
		return
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if not (actor is Node3D) or not is_instance_valid(actor):
		return
	get_viewport().set_input_as_handled()
	toon_clicked.emit(actor as Node3D)


func _arm_friend(item: Dictionary, panel: Control) -> void:
	var kind := String(item.get("kind", ""))
	if kind != "player" and kind != "toon":
		return
	# Another toon's nametag opens ToonAvatarPanel. Pick-a-friend still wins.
	if kind == "toon" and not picking_friends:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.z_index = 36
		if not panel.has_meta("toon_hook"):
			panel.set_meta("toon_hook", true)
			var other: Variant = item.get("actor")
			panel.gui_input.connect(_on_toon_tag.bind(other))
		return
	if picking_friends:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.z_index = 36
		if not panel.has_meta("friend_hook"):
			panel.set_meta("friend_hook", true)
			var actor: Variant = item.get("actor")
			panel.gui_input.connect(_on_friend_tag.bind(actor))
		return
	if panel.has_meta("friend_hook") and not panel.has_meta("toon_hook"):
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.mouse_default_cursor_shape = Control.CURSOR_ARROW


func _place_chat(item: Dictionary, label: Control, actor: Node3D) -> void:
	var line := String(actor.get_meta("chat_line", ""))
	var until := int(actor.get_meta("chat_until", 0))
	if line == "" or Time.get_ticks_msec() >= until:
		_hide_chat(item)
		return
	var bubble := _chat_panel(item)
	var words := bubble.get_node_or_null("Words") as Label
	if words != null:
		var px := 18
		var face := ToonGui.font()
		var name_label := label.get_child(0) as Label
		if name_label != null:
			px = maxi(name_label.get_theme_font_size("font_size"), 12)
			var named := name_label.get_theme_font("font")
			if named != null:
				face = named
		words.add_theme_font_override("font", face)
		ToonGui.show_speech(words, line, px)
	bubble.visible = label.visible
	bubble.reset_size()
	bubble.position = label.position + Vector2((label.size.x - bubble.size.x) * 0.5, -bubble.size.y - 4.0)


func _chat_panel(item: Dictionary) -> PanelContainer:
	var existing: PanelContainer = item.get("chat")
	if existing != null and is_instance_valid(existing):
		return existing
	var bubble := PanelContainer.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.z_index = 16
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.98)
	box.border_color = Color(0.05, 0.05, 0.05)
	box.set_border_width_all(3)
	box.set_corner_radius_all(12)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	bubble.add_theme_stylebox_override("panel", box)
	var words := Label.new()
	words.name = "Words"
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ToonGui.style_label(words, Color(0.05, 0.05, 0.08), 18, Color(0, 0, 0, 0), 0)
	bubble.add_child(words)
	bubble.visible = false
	if layer != null:
		layer.add_child(bubble)
	item["chat"] = bubble
	return bubble


func _hide_chat(item: Dictionary) -> void:
	var bubble: PanelContainer = item.get("chat")
	if bubble != null and is_instance_valid(bubble):
		bubble.visible = false


func _free_chat(item: Dictionary) -> void:
	var bubble: PanelContainer = item.get("chat")
	if bubble != null and is_instance_valid(bubble):
		bubble.queue_free()


func _lift(actor: Node3D) -> float:
	var head := _find(actor, "def_head")
	if head:
		var scale := actor.global_transform.basis.get_scale().y
		if scale < 0.05:
			scale = 1.0
		return head.global_position.y - actor.global_position.y + 0.96 * scale
	var top := -1.0
	for node in actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null or _TAG_BODY.has(String(mesh.name)):
			continue
		var box := mesh.global_transform * mesh.get_aabb()
		top = maxf(top, box.position.y + box.size.y)
	if top >= 0.0:
		return top - actor.global_position.y + 0.04
	return 3.6


func _fit(panel: Control, point: Vector3) -> void:
	var here := camera.unproject_position(point)
	var above := camera.unproject_position(point + Vector3(0.0, 0.2, 0.0))
	var px := clampi(int(absf(here.y - above.y)), 12, 36)
	var label := panel.get_child(0) as Label
	if label:
		label.add_theme_font_size_override("font_size", px)
		label.add_theme_constant_override("line_spacing", -maxi(int(px * 0.12), 1))
	var side := maxi(int(px * 0.24), 3)
	var vert := maxi(int(px * 0.048), 1)
	var flat := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if flat != null:
		flat.set_corner_radius_all(maxi(int(px * 0.22), 3))
		flat.content_margin_left = side
		flat.content_margin_right = side
		flat.content_margin_top = vert
		flat.content_margin_bottom = vert
		return
	var card := panel.get_theme_stylebox("panel") as StyleBoxTexture
	if card == null:
		return
	card.content_margin_left = side
	card.content_margin_right = side
	card.content_margin_top = vert
	card.content_margin_bottom = vert


## panel.bam is a rounded quad. CCSuit tints it gray until the pointer is over it.
func _suit_card() -> StyleBoxTexture:
	var card := StyleBoxTexture.new()
	card.texture = _NAME_PANEL
	var corner := 8
	card.texture_margin_left = corner
	card.texture_margin_right = corner
	card.texture_margin_top = corner
	card.texture_margin_bottom = corner
	card.modulate_color = _SUIT_CARD
	return card


func _suit_look(panel: Control, label: Label, over: bool) -> void:
	if over and bool(panel.get_meta("suit_down", false)):
		return
	if not over:
		panel.set_meta("suit_down", false)
	_suit_colors(panel, label, _SUIT_CARD_OVER if over else _SUIT_CARD, _SUIT_INK_OVER if over else _SUIT_INK)


func _suit_colors(panel: Control, label: Label, card: Color, ink: Color) -> void:
	var box := panel.get_theme_stylebox("panel") as StyleBoxTexture
	if box != null:
		box.modulate_color = card
	label.add_theme_color_override("font_color", ink)


func _in_view(point: Vector3) -> bool:
	if not camera.is_position_in_frustum(point):
		return false
	var view := camera.get_viewport().get_visible_rect()
	return view.has_point(camera.unproject_position(point))


func _place(control: Control, world: Vector3) -> void:
	var view := camera.get_viewport().get_visible_rect().size
	if view.x < 2.0 or view.y < 2.0:
		control.visible = false
		return
	control.reset_size()
	var screen := camera.unproject_position(world)
	control.position = screen - control.size * Vector2(0.5, 1.0)
	control.visible = true


func _sync_gm(item: Dictionary) -> void:
	var wanted := 0
	var actor := item.get("actor") as Node
	if String(item.get("kind", "")) == "player":
		wanted = MagicWords.gm_type()
	elif actor != null and actor.has_meta("gm"):
		wanted = int(actor.get_meta("gm"))
	if int(item.get("gm", -1)) == wanted:
		return
	item["gm"] = wanted
	var panel := item["label"] as Control
	var written := panel.get_child(0) as Label if panel != null else null
	var plain := String(item.get("plain", ""))
	var title := MagicWords.gm_title(wanted)
	if written != null:
		written.text = plain if title == "" else "%s %s" % [title, plain]
	if wanted <= 0:
		var old: TextureRect = item.get("icon")
		if old != null and is_instance_valid(old):
			old.queue_free()
		item.erase("icon")
		return
	var icon: TextureRect = item.get("icon")
	if icon == null or not is_instance_valid(icon):
		icon = TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if layer != null:
			layer.add_child(icon)
		item["icon"] = icon
	icon.texture = _gm_texture(wanted)


func _gm_texture(kind: int) -> Texture2D:
	if kind == 3:
		return _GM_FIST
	if kind == 4:
		return _GM_CONNECTED
	return _GM_WHISTLE


func _hide_icon(item: Dictionary) -> void:
	var icon: TextureRect = item.get("icon")
	if icon != null and is_instance_valid(icon):
		icon.visible = false


func _place_icon(item: Dictionary, panel: Control) -> void:
	var icon: TextureRect = item.get("icon")
	if icon == null or not is_instance_valid(icon):
		return
	if not panel.visible:
		icon.visible = false
		return
	var written := panel.get_child(0) as Label
	var side := 16.0
	if written != null:
		side = float(written.get_theme_font_size("font_size"))
	icon.custom_minimum_size = Vector2(side, side)
	icon.size = Vector2(side, side)
	icon.pivot_offset = icon.size * 0.5
	icon.rotation = fmod(float(Time.get_ticks_msec()) / 3000.0, 1.0) * TAU
	icon.position = panel.position + Vector2(-side - 4.0, (panel.size.y - side) * 0.5)
	icon.visible = true


func _find(root: Node, node_name: String) -> Node3D:
	if root.name == node_name and root is Node3D:
		return root as Node3D
	var found := root.find_child(node_name, true, false)
	return found as Node3D
