extends Control

## ClerkPurchase. Each gag costs one jellybean from the pouch, not the bank.
## The inventory is the same card as the shticker book: a track the toon has
## not earned stays hidden, and a gag shows only after its skill point.

signal finished(reason: String)

const _BEANS := preload("res://scenes/toons/jellybeans.gd")
const _ROW := preload("res://assets/gui/tutorial/InventoryRow.png")
const _JAR := preload("res://assets/gui/tutorial/book/jar.png")
const _SECONDS := 120.0
const _GAG_ICON: Array[Texture2D] = [
	preload("res://assets/gui/tutorial/gags/inventory_feather.png"),
	preload("res://assets/gui/tutorial/gags/inventory_megaphone.png"),
	preload("res://assets/gui/tutorial/gags/inventory_lipstick.png"),
	preload("res://assets/gui/tutorial/gags/inventory_bamboo_cane.png"),
	preload("res://assets/gui/tutorial/gags/inventory_pixiedust.png"),
	preload("res://assets/gui/tutorial/gags/inventory_juggling_cubes.png"),
	preload("res://assets/gui/tutorial/gags/inventory_ladder.png"),
	preload("res://assets/gui/tutorial/gags/inventory_bannana_peel.png"),
	preload("res://assets/gui/tutorial/gags/inventory_rake.png"),
	preload("res://assets/gui/tutorial/gags/inventory_marbles.png"),
	preload("res://assets/gui/tutorial/gags/inventory_quicksand_icon.png"),
	preload("res://assets/gui/tutorial/gags/inventory_trapdoor.png"),
	preload("res://assets/gui/tutorial/gags/inventory_tnt.png"),
	preload("res://assets/gui/tutorial/gags/inventory_traintracks.png"),
	preload("res://assets/gui/tutorial/gags/inventory_1dollarbill.png"),
	preload("res://assets/gui/tutorial/gags/inventory_small_magnet.png"),
	preload("res://assets/gui/tutorial/gags/inventory_5dollarbill.png"),
	preload("res://assets/gui/tutorial/gags/inventory_big_magnet.png"),
	preload("res://assets/gui/tutorial/gags/inventory_10dollarbill.png"),
	preload("res://assets/gui/tutorial/gags/inventory_hypno_goggles.png"),
	preload("res://assets/gui/tutorial/gags/inventory_screen.png"),
	preload("res://assets/gui/tutorial/gags/inventory_bikehorn.png"),
	preload("res://assets/gui/tutorial/gags/inventory_whistle.png"),
	preload("res://assets/gui/tutorial/gags/inventory_bugle.png"),
	preload("res://assets/gui/tutorial/gags/inventory_aoogah.png"),
	preload("res://assets/gui/tutorial/gags/inventory_elephant.png"),
	preload("res://assets/gui/tutorial/gags/inventory_fog_horn.png"),
	preload("res://assets/gui/tutorial/gags/inventory_opera_singer.png"),
	preload("res://assets/gui/tutorial/gags/inventory_tart.png"),
	preload("res://assets/gui/tutorial/gags/inventory_fruit_pie_slice.png"),
	preload("res://assets/gui/tutorial/gags/inventory_cream_pie_slice.png"),
	preload("res://assets/gui/tutorial/gags/inventory_fruitpie.png"),
	preload("res://assets/gui/tutorial/gags/inventory_creampie.png"),
	preload("res://assets/gui/tutorial/gags/inventory_cake.png"),
	preload("res://assets/gui/tutorial/gags/inventory_wedding.png"),
	preload("res://assets/gui/tutorial/gags/inventory_squirt_flower.png"),
	preload("res://assets/gui/tutorial/gags/inventory_glass_of_water.png"),
	preload("res://assets/gui/tutorial/gags/inventory_water_gun.png"),
	preload("res://assets/gui/tutorial/gags/inventory_seltzer_bottle.png"),
	preload("res://assets/gui/tutorial/gags/inventory_firehose.png"),
	preload("res://assets/gui/tutorial/gags/inventory_storm_cloud.png"),
	preload("res://assets/gui/tutorial/gags/inventory_geyser.png"),
	preload("res://assets/gui/tutorial/gags/inventory_flower_pot.png"),
	preload("res://assets/gui/tutorial/gags/inventory_sandbag.png"),
	preload("res://assets/gui/tutorial/gags/inventory_anvil.png"),
	preload("res://assets/gui/tutorial/gags/inventory_weight.png"),
	preload("res://assets/gui/tutorial/gags/inventory_safe_box.png"),
	preload("res://assets/gui/tutorial/gags/inventory_piano.png"),
	preload("res://assets/gui/tutorial/gags/inventory_ship.png"),
]
const _SLOT_CENTER: PackedFloat32Array = [0.2679, 0.3770, 0.4861, 0.5933, 0.7044, 0.8115, 0.9226]

var loadout: ToonLoadout
var _remain := _SECONDS
var _deleting := false
var _broke := false
var _status_left := 0.0
var _closed := false
var _card: Panel
var _title: Label
var _status: Label
var _timer: Label
var _beans: Label
var _delete: Button
var _done: Button
var _rows: Array[TextureRect] = []
var _names: Array[Label] = []
var _buttons: Array[Button] = []
var _icons: Array[TextureRect] = []
var _counts: Array[Label] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	var view := get_viewport()
	if not view.size_changed.is_connected(_layout):
		view.size_changed.connect(_layout)
	_layout()
	_refresh()


func _process(delta: float) -> void:
	if _closed:
		return
	_remain = maxf(_remain - delta, 0.0)
	_paint_timer()
	if _status_left > 0.0:
		_status_left = maxf(_status_left - delta, 0.0)
		if _status_left == 0.0:
			_show_beans()
	if _remain <= 0.0:
		_close("timeout")


func _input(event: InputEvent) -> void:
	if _closed or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode != KEY_ESCAPE and key.physical_keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	_close("done")


func _build() -> void:
	var wash := ColorRect.new()
	wash.color = Color(0, 0, 0, 0.25)
	wash.mouse_filter = Control.MOUSE_FILTER_STOP
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(wash)
	# A PanelContainer stretches every child to the card, so the last button
	# covers the inventory. Panel keeps the positions _layout assigns.
	_card = Panel.new()
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var cream := StyleBoxFlat.new()
	cream.bg_color = Color(1.0, 0.96, 0.78)
	cream.border_color = Color(0.45, 0.28, 0.08)
	cream.set_border_width_all(6)
	cream.set_corner_radius_all(18)
	cream.content_margin_left = 16
	cream.content_margin_right = 16
	cream.content_margin_top = 12
	cream.content_margin_bottom = 12
	_card.add_theme_stylebox_override("panel", cream)
	add_child(_card)
	_title = Label.new()
	_title.text = "Goofy's Gag Shop"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_title)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_status)
	_timer = Label.new()
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_timer)
	for track in ToonLoadout.TRACK_COUNT:
		var row := TextureRect.new()
		row.texture = _ROW
		row.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.stretch_mode = TextureRect.STRETCH_SCALE
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.modulate = ToonLoadout.TRACK_COLORS[track]
		_card.add_child(row)
		_rows.append(row)
		var name := Label.new()
		name.text = ToonLoadout.TRACK_NAMES[track].to_upper()
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_card.add_child(name)
		_names.append(name)
		for level in ToonLoadout.LEVEL_COUNT:
			var button := Button.new()
			button.focus_mode = Control.FOCUS_NONE
			button.flat = true
			var empty := StyleBoxEmpty.new()
			button.add_theme_stylebox_override("normal", empty)
			button.add_theme_stylebox_override("hover", empty)
			button.add_theme_stylebox_override("pressed", empty)
			button.add_theme_stylebox_override("disabled", empty)
			button.add_theme_stylebox_override("focus", empty)
			button.pressed.connect(_press.bind(track, level))
			ToonGui.button_sounds(button)
			_card.add_child(button)
			_buttons.append(button)
			var icon := TextureRect.new()
			icon.texture = _GAG_ICON[track * ToonLoadout.LEVEL_COUNT + level]
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_card.add_child(icon)
			_icons.append(icon)
			var count := Label.new()
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			count.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_card.add_child(count)
			_counts.append(count)
	var jar := TextureRect.new()
	jar.name = "Jar"
	jar.texture = _JAR
	jar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	jar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	jar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(jar)
	_beans = Label.new()
	_beans.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_beans.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_beans.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_beans)
	_delete = _pill("DELETE")
	_delete.pressed.connect(_toggle_delete)
	_done = _pill("DONE\nSHOPPING")
	_done.pressed.connect(_close.bind("done"))


func _pill(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.12, 0.45, 0.95)
	box.set_corner_radius_all(10)
	button.add_theme_stylebox_override("normal", box)
	var down := box.duplicate() as StyleBoxFlat
	down.bg_color = Color(0.08, 0.3, 0.7)
	button.add_theme_stylebox_override("pressed", down)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	ToonGui.button_sounds(button)
	_card.add_child(button)
	return button


func _style_button(button: Button, px: int) -> void:
	button.add_theme_font_override("font", ToonGui.font())
	button.add_theme_font_size_override("font_size", maxi(px, 1))


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.y < 2.0:
		return
	var card := Vector2(minf(view.x * 0.9, view.y * 1.35), view.y * 0.9)
	_card.position = (view - card) * 0.5
	_card.size = card
	var title_px := maxi(int(card.y * 0.045), 18)
	var body_px := maxi(int(card.y * 0.028), 13)
	ToonGui.style_title(_title, Color(0.55, 0.22, 0.05), title_px)
	_title.position = Vector2(card.x * 0.16, card.y * 0.02)
	_title.size = Vector2(card.x * 0.68, card.y * 0.08)
	ToonGui.style_label(_status, Color(0.05, 0.14, 0.4), body_px, Color(0, 0, 0, 0), 0)
	_status.position = Vector2(card.x * 0.08, card.y * 0.1)
	_status.size = Vector2(card.x * 0.84, card.y * 0.06)
	ToonGui.style_label(_timer, Color(0.75, 0.08, 0.08), body_px, Color(0, 0, 0, 0), 0)
	_timer.position = Vector2(card.x * 0.72, card.y * 0.02)
	_timer.size = Vector2(card.x * 0.24, card.y * 0.07)
	var shown: Array[int] = []
	for track in ToonLoadout.TRACK_COUNT:
		if loadout != null and loadout.track_open(track):
			shown.append(track)
	if shown.is_empty():
		shown.append(ToonLoadout.THROW)
		shown.append(ToonLoadout.SQUIRT)
	var top := card.y * 0.18
	var band := card.y * 0.62
	var gap := maxf(band * 0.02, 3.0)
	var row_h := (band - gap * float(shown.size() - 1)) / float(shown.size())
	var row_w := minf(row_h * (252.0 / 28.0), card.x * 0.92)
	row_h = row_w * (28.0 / 252.0)
	var row_x := (card.x - row_w) * 0.5
	var name_px := maxi(int(row_h * 0.38), 9)
	var count_px := maxi(int(row_h * 0.28), 8)
	var placed := 0
	for track in ToonLoadout.TRACK_COUNT:
		var open := shown.has(track)
		var row := _rows[track]
		row.visible = open
		_names[track].visible = open
		if not open:
			for level in ToonLoadout.LEVEL_COUNT:
				var index := track * ToonLoadout.LEVEL_COUNT + level
				_buttons[index].visible = false
				_icons[index].visible = false
				_counts[index].visible = false
			continue
		var row_y := top + float(placed) * (row_h + gap)
		placed += 1
		row.position = Vector2(row_x, row_y)
		row.size = Vector2(row_w, row_h)
		var name := _names[track]
		name.position = Vector2(row_x + row_w * 0.02, row_y)
		name.size = Vector2(row_w * 0.2, row_h)
		ToonGui.style_label(name, Color.WHITE, name_px, Color(0.08, 0.08, 0.12), 2)
		for level in ToonLoadout.LEVEL_COUNT:
			var index := track * ToonLoadout.LEVEL_COUNT + level
			var center := Vector2(row_x + _SLOT_CENTER[level] * row_w, row_y + row_h * 0.5)
			var well := row_w * 0.1
			var button := _buttons[index]
			button.position = center - Vector2(well, row_h * 0.9) * 0.5
			button.size = Vector2(well, row_h * 0.9)
			var icon_size := well * 0.78
			var icon := _icons[index]
			icon.position = center - Vector2(icon_size, icon_size) * 0.5
			icon.size = Vector2(icon_size, icon_size)
			var count := _counts[index]
			count.position = button.position
			count.size = button.size - Vector2(well * 0.04, row_h * 0.02)
			ToonGui.style_label(count, Color.WHITE, count_px, Color(0.05, 0.12, 0.28), 2)
	var footer_y := card.y * 0.84
	var jar := _card.get_node("Jar") as Control
	jar.position = Vector2(card.x * 0.04, footer_y)
	jar.size = Vector2(card.y * 0.12, card.y * 0.12)
	_beans.position = jar.position
	_beans.size = jar.size
	ToonGui.style_title(_beans, Color(0.95, 0.88, 0.1), maxi(int(jar.size.y * 0.28), 14))
	_delete.position = Vector2(card.x * 0.22, footer_y + card.y * 0.02)
	_delete.size = Vector2(card.x * 0.22, card.y * 0.09)
	_done.position = Vector2(card.x * 0.58, footer_y + card.y * 0.01)
	_done.size = Vector2(card.x * 0.34, card.y * 0.11)
	_style_button(_delete, body_px)
	_style_button(_done, body_px)


func _refresh() -> void:
	if loadout == null:
		return
	_beans.text = str(_BEANS.pouch())
	_broke = _BEANS.pouch() <= 0
	for track in ToonLoadout.TRACK_COUNT:
		var open := loadout.track_open(track)
		_rows[track].visible = open
		_names[track].visible = open
		for level in ToonLoadout.LEVEL_COUNT:
			var index := track * ToonLoadout.LEVEL_COUNT + level
			var shown := open and loadout.gag_usable(track, level)
			_buttons[index].visible = shown
			_icons[index].visible = shown
			_counts[index].visible = shown
			if not shown:
				continue
			var owned := loadout.count_of(track, level)
			_counts[index].text = str(owned)
			var full := owned >= loadout.carry_limit(track, level) or loadout.pouch_full()
			var blocked := (not _deleting and (_broke or full or level > ToonLoadout.LAST_REGULAR)) or (_deleting and owned <= 0)
			_buttons[index].disabled = blocked
			_icons[index].modulate = Color(0.55, 0.55, 0.55) if blocked else Color.WHITE
	if _status_left <= 0.0:
		_show_beans()


func _show_beans() -> void:
	if _deleting:
		_status.text = "Click on a gag to DELETE it."
		return
	var money := _BEANS.pouch()
	if money <= 0:
		_status.text = "Sorry, you are all out of jellybeans!"
	elif money == 1:
		_status.text = "You have 1 jellybean to spend"
	else:
		_status.text = "You have %d jellybeans to spend" % money


func _note(text: String) -> void:
	_status.text = text
	_status_left = 2.0


func _press(track: int, level: int) -> void:
	if _closed or loadout == null:
		return
	if _deleting:
		if loadout.toss_gag(track, level):
			_refresh()
		return
	if _BEANS.pouch() <= 0:
		_broke = true
		_note("Sorry, you are all out of jellybeans!")
		_refresh()
		return
	var result := loadout.purchase(track, level)
	if result > 0:
		if _BEANS.take_beans(1, false):
			_note("You purchased %s" % loadout.gag_name(track, level))
		else:
			loadout.toss_gag(track, level)
			_note("Sorry, you are all out of jellybeans!")
	elif result == -2:
		_note("Sorry, you have too many props")
	elif result == -1:
		_note("Sorry, you have enough %s already" % _plural(loadout.gag_name(track, level)))
	else:
		_note("You do not have enough skill for that yet")
	_refresh()


func _toggle_delete() -> void:
	_deleting = not _deleting
	_delete.text = "DONE" if _deleting else "DELETE"
	_status_left = 0.0
	_refresh()


func _paint_timer() -> void:
	var whole := int(ceil(_remain))
	_timer.text = "%d:%02d" % [whole / 60, whole % 60]


func _close(reason: String) -> void:
	if _closed:
		return
	_closed = true
	finished.emit(reason)
	queue_free()


func _plural(name: String) -> String:
	match name:
		"Glass of Water":
			return "Glasses of Water"
		"TNT":
			return "TNT"
		_:
			if name.ends_with("s"):
				return name
			return name + "s"
