extends RefCounted
class_name RunSummary

## A short card at the end of a facility or a boss. The numbers are the gags
## that landed during the run: damage, laff restored, how many gags were used,
## and how long the run took.

const _DIALOG := preload("res://assets/gui/tutorial/dialog/dialog_box.png")
const _OK_UP := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_UP.png")
const _OK_DOWN := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_DN.png")
const _OK_HOVER := preload("res://assets/gui/tutorial/dialog/ChtBx_OKBtn_Rllvr.png")

static var _on := false
static var _kind := ""
static var _started := 0
static var _rows: Dictionary = {}


static func start(kind: String) -> void:
	_on = true
	_kind = kind
	_started = Time.get_ticks_msec()
	_rows.clear()


static func note(peer: int, who: String, damage: int, healed: int, gags: int) -> void:
	if not _on or peer <= 0 or not _inside():
		return
	var row: Dictionary = _rows.get(peer, {"name": who, "damage": 0, "toonup": 0, "gags": 0})
	if who != "":
		row["name"] = who
	row["damage"] = int(row["damage"]) + maxi(damage, 0)
	row["toonup"] = int(row["toonup"]) + maxi(healed, 0)
	row["gags"] = int(row["gags"]) + maxi(gags, 0)
	_rows[peer] = row


static func present() -> void:
	if not _on:
		return
	_on = false
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.name = "RunSummary"
	tree.current_scene.add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var view := root.get_viewport().get_visible_rect().size
	var card := TextureRect.new()
	card.texture = _DIALOG
	card.modulate = Color(1, 1, 0.75)
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size = Vector2(view.y * 0.95, view.y * 0.62)
	card.position = (view - card.size) * 0.5
	root.add_child(card)
	var title := _line(root)
	title.text = _kind
	title.position = card.position + Vector2(card.size.x * 0.12, card.size.y * 0.16)
	title.size = Vector2(card.size.x * 0.76, card.size.y * 0.12)
	var body := _line(root)
	body.text = _body()
	body.position = card.position + Vector2(card.size.x * 0.16, card.size.y * 0.30)
	body.size = Vector2(card.size.x * 0.68, card.size.y * 0.40)
	var button := TextureButton.new()
	button.texture_normal = _OK_UP
	button.texture_pressed = _OK_DOWN
	button.texture_hover = _OK_HOVER
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.size = Vector2(view.y * 0.08, view.y * 0.08)
	button.position = card.position + Vector2(card.size.x * 0.5 - button.size.x * 0.5, card.size.y * 0.74)
	ToonGui.button_sounds(button)
	root.add_child(button)
	var done := false
	button.pressed.connect(func() -> void: done = true)
	while not done and is_instance_valid(layer):
		await tree.process_frame
	if is_instance_valid(layer):
		layer.queue_free()


static func _inside() -> bool:
	var path := _scene_path()
	return path.contains("sellbot_factory") or path.contains("cashbot_mint") or path.contains("lawbot_office") or path.contains("bossbot_course") or path.ends_with("sellbot_vp.tscn") or path.ends_with("cashbot_cfo.tscn") or path.ends_with("lawbot_cj.tscn") or path.ends_with("bossbot_ceo.tscn")


static func _scene_path() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return ""
	return tree.current_scene.scene_file_path


static func _body() -> String:
	var elapsed := maxi(Time.get_ticks_msec() - _started, 0) / 1000
	var clock := "%d:%02d" % [elapsed / 60, elapsed % 60]
	var gags := 0
	var people := 0
	for peer in _rows.keys():
		var row: Dictionary = _rows[peer]
		gags += int(row.get("gags", 0))
		people += 1
	if people <= 1:
		var solo: Dictionary = {}
		for peer in _rows.keys():
			solo = _rows[peer]
		return "Time  %s\nDamage dealt  %d\nToon-Up  %d\nGags used  %d" % [clock, int(solo.get("damage", 0)), int(solo.get("toonup", 0)), gags]
	return "Time  %s\nDamage  %s\nToon-Up  %s\nGags used  %d" % [clock, _leader("damage"), _leader("toonup"), gags]


static func _leader(field: String) -> String:
	var best := 0
	var names: PackedStringArray = []
	for peer in _rows.keys():
		var row: Dictionary = _rows[peer]
		var amount := int(row.get(field, 0))
		if amount <= 0 or amount < best:
			continue
		if amount > best:
			best = amount
			names = PackedStringArray()
		var who := String(row.get("name", "A toon"))
		if who == "":
			who = "A toon"
		names.append(who)
	if best <= 0:
		return "0"
	return "%s  %d" % [" and ".join(names), best]


static func _line(parent: Node) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ToonGui.style_label(label, Color(0.08, 0.08, 0.08), 22, Color(0, 0, 0, 0), 0)
	parent.add_child(label)
	return label
