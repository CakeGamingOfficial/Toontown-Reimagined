extends Control

## ClerkPurchase over InventoryNew's store purchase frame. The panel, sign,
## jar, and Done button come from phase_4 gag_shop_purchase_gui. The clock,
## trash can, and inventory rows are the same cards the original hangs on it.
## One pouch bean buys one gag. A track the toon has not earned stays hidden
## in its own slot, and a gag shows only after its skill point.

signal finished(reason: String)

const _BEANS := preload("res://scenes/toons/jellybeans.gd")
const _PANEL := preload("res://assets/gui/purchase/gagShopPanel.png")
const _SIGN := preload("res://assets/gui/purchase/Goofys_Sign.png")
const _JAR := preload("res://assets/gui/purchase/Jar.png")
const _UP := preload("res://assets/gui/purchase/PurchScrn_BTN_UP.png")
const _DN := preload("res://assets/gui/purchase/PurchScrn_BTN_DN.png")
const _OVER := preload("res://assets/gui/purchase/PurchScrn_BTN_RLVR.png")
const _CLOCK := preload("res://assets/gui/purchase/alarm_clock.png")
const _ROW := preload("res://assets/gui/tutorial/InventoryRow.png")
const _SLOT_UP := preload("res://assets/gui/rules/InventoryButtonUp.png")
const _SLOT_DN := preload("res://assets/gui/rules/InventoryButtonDown.png")
const _SLOT_OVER := preload("res://assets/gui/rules/InventoryButtonRollover.png")
const _SLOT_FLAT := preload("res://assets/gui/tutorial/InventoryButtonFlat.png")
const _TRASH_CLOSED := preload("res://assets/toons/gui/TrashCan_CLSD.png")
const _TRASH_OPEN := preload("res://assets/toons/gui/TrashCan_OPEN.png")
const _TRASH_HOVER := preload("res://assets/toons/gui/TrashCan_RLVR.png")
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
const _PRESSABLE := Color(0, 0.6, 1, 1)
const _DELETE_TINT := Color(0.7, 0.1, 0.1, 1)
const _UNPRESSABLE := Color(0.3, 0.3, 0.3, 0.8)

var loadout: ToonLoadout
var _remain := _SECONDS
var _deleting := false
var _broke := false
var _status_left := 0.0
var _closed := false
var _panel: TextureRect
var _sign: TextureRect
var _title: Label
var _jar: TextureRect
var _beans: Label
var _status: Label
var _clock: TextureRect
var _time: Label
var _done: TextureButton
var _trash: TextureButton
var _pouch: Label
var _rows: Array[TextureRect] = []
var _names: Array[Label] = []
var _bars: Array[ColorRect] = []
var _fills: Array[ColorRect] = []
var _skills: Array[Label] = []
var _slots: Array[TextureButton] = []
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
	# Inventory sits at (0.2, -0.04). gagShopPanel is image_pos (-0.21, 0.18) on that frame.
	_panel = _image(_PANEL)
	for track in ToonLoadout.TRACK_COUNT:
		var row := _image(_ROW)
		row.modulate = ToonLoadout.TRACK_COLORS[track]
		_rows.append(row)
		var name := _label()
		name.text = ToonLoadout.TRACK_NAMES[track].to_upper()
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(name)
		_names.append(name)
		var bar := ColorRect.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.color = ToonLoadout.TRACK_COLORS[track] * Color(0.6, 0.6, 0.6, 1)
		add_child(bar)
		_bars.append(bar)
		var fill := ColorRect.new()
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.color = ToonLoadout.TRACK_COLORS[track] * Color(0.9, 0.9, 0.9, 1)
		add_child(fill)
		_fills.append(fill)
		var skill := _label()
		skill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(skill)
		_skills.append(skill)
		for level in ToonLoadout.LEVEL_COUNT:
			var slot := TextureButton.new()
			slot.texture_normal = _SLOT_UP
			slot.texture_hover = _SLOT_OVER
			slot.texture_pressed = _SLOT_DN
			slot.texture_disabled = _SLOT_FLAT
			slot.ignore_texture_size = true
			slot.stretch_mode = TextureButton.STRETCH_SCALE
			slot.focus_mode = Control.FOCUS_NONE
			slot.pressed.connect(_press.bind(track, level))
			ToonGui.button_sounds(slot)
			add_child(slot)
			_slots.append(slot)
			var icon := TextureRect.new()
			icon.texture = _GAG_ICON[track * ToonLoadout.LEVEL_COUNT + level]
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(icon)
			_icons.append(icon)
			var count := _label()
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			add_child(count)
			_counts.append(count)
	_jar = _image(_JAR)
	_beans = _label()
	_beans.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_beans.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_beans)
	_pouch = _label()
	_pouch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pouch.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_pouch)
	_status = _label()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_status)
	_trash = TextureButton.new()
	_trash.texture_normal = _TRASH_CLOSED
	_trash.texture_hover = _TRASH_HOVER
	_trash.texture_pressed = _TRASH_OPEN
	_trash.ignore_texture_size = true
	_trash.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_trash.focus_mode = Control.FOCUS_NONE
	_trash.pressed.connect(_toggle_delete)
	ToonGui.button_sounds(_trash)
	add_child(_trash)
	_done = TextureButton.new()
	_done.texture_normal = _UP
	_done.texture_pressed = _DN
	_done.texture_hover = _OVER
	_done.ignore_texture_size = true
	_done.stretch_mode = TextureButton.STRETCH_SCALE
	_done.focus_mode = Control.FOCUS_NONE
	_done.pressed.connect(_close.bind("done"))
	ToonGui.button_sounds(_done)
	var caption := _label()
	caption.text = "DONE\nSHOPPING"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	_done.add_child(caption)
	add_child(_done)
	_sign = _image(_SIGN)
	_title = _label()
	_title.text = "Goofy's Gag Shop"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_title)
	_clock = _image(_CLOCK)
	_time = _label()
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_time)


func _image(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _label() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _layout() -> void:
	# storePurchaseActivateButtons parks the inventory at (0.2, -0.04).
	var shop_x := 0.2
	var shop_z := -0.04
	_place(_panel, shop_x - 0.21, shop_z + 0.18, 2.425, 1.2)
	_place(_sign, 0.0, 0.83, 1.2917 * 1.2, 0.275 * 1.2)
	_title.position = _sign.position
	_title.size = _sign.size
	ToonGui.style_title(_title, Color(0.6, 0.2, 0.0), _px_of(0.09 * 1.2))
	_place(_jar, shop_x - 1.15, shop_z + 0.16, 0.4333, 0.5292)
	_beans.position = _point(shop_x - 1.15, shop_z + 0.16 - 0.1) - _jar.size * 0.5
	_beans.size = _jar.size
	_paint_jar()
	var status_size := _size(1.2, 0.1)
	_status.position = _point(shop_x - 0.25, shop_z + 0.625) - status_size * 0.5
	_status.size = status_size
	ToonGui.style_label(_status, Color(0.05, 0.14, 0.4), _px_of(0.08), Color(0, 0, 0, 0), 0)
	_place(_done, shop_x + 0.71, shop_z - 0.045, 0.4125 * 1.04, 0.175 * 1.04)
	var caption := _done.get_child(0) as Label
	ToonGui.style_label(caption, Color(0.0, 0.1, 0.7), _px_of(0.05 * 1.04), Color(0, 0, 0, 0), 0)
	_place(_clock, 1.16, 0.83, 0.7417 * 0.45, 0.7292 * 0.45)
	_time.position = _clock.position
	_time.size = _clock.size
	_paint_timer()
	# The trash can is (-0.55, -0.91) on the inventory frame, which is scaled by 0.81.
	var frame_x := shop_x - 0.23
	var frame_z := shop_z + 0.505
	var frame_scale := 0.81
	_place(
		_trash,
		frame_x + -0.55 * frame_scale,
		frame_z + -0.91 * frame_scale,
		0.3375 * 0.75 * frame_scale,
		0.4292 * 0.75 * frame_scale
	)
	# totalLabel sits in the blue square on the right of the panel.
	var pouch_size := _size(0.34, 0.14)
	_pouch.position = _point(frame_x + 1.175 * frame_scale, frame_z + -0.095 * 1.25 * frame_scale) - pouch_size * 0.5
	_pouch.size = pouch_size
	ToonGui.style_label(_pouch, Color(0.05, 0.14, 0.4), _px_of(0.05 * 1.25 * frame_scale), Color(0, 0, 0, 0), 0)
	_paint_pouch()
	var row_w := 1.6667 * frame_scale
	var row_h := 0.1137 * 1.1 * frame_scale
	for track in ToonLoadout.TRACK_COUNT:
		var open := loadout != null and loadout.track_open(track)
		var row_z := frame_z + float(track) * -0.12 * frame_scale
		var row := _rows[track]
		row.visible = open
		_names[track].visible = open
		_bars[track].visible = open
		_fills[track].visible = open
		_skills[track].visible = open
		if open:
			_place(row, frame_x, row_z, row_w, row_h)
			var name := _names[track]
			var name_size := _size(0.55, row_h)
			name.position = _point(frame_x + -0.785 * frame_scale, row_z + 0.01 * 1.1 * frame_scale) - Vector2(0.0, name_size.y * 0.5)
			name.size = name_size
			ToonGui.style_label(name, Color(0.2, 0.2, 0.2), _px_of(0.05 * frame_scale), Color(0, 0, 0, 0), 0)
			var bar_size := _size(0.3 * frame_scale, 0.05 * 1.1 * frame_scale)
			var bar_center := _point(frame_x + -0.645 * frame_scale, row_z + -0.025 * 1.1 * frame_scale)
			_bars[track].position = bar_center - bar_size * 0.5
			_bars[track].size = bar_size
			_skills[track].position = _bars[track].position
			_skills[track].size = bar_size
			ToonGui.style_label(_skills[track], Color(0, 0, 0, 0.8), _px_of(0.04 * frame_scale), Color(0, 0, 0, 0), 0)
			_paint_bar(track)
		for level in ToonLoadout.LEVEL_COUNT:
			var index := track * ToonLoadout.LEVEL_COUNT + level
			var shown := open and loadout != null and loadout.gag_usable(track, level)
			_slots[index].visible = shown
			_icons[index].visible = shown
			_counts[index].visible = shown
			if not shown:
				continue
			var local_x := -0.375 + float(level) * 0.18
			var center := _point(frame_x + local_x * frame_scale, row_z)
			var well := _size(0.1804 * frame_scale, 0.1137 * 1.1 * frame_scale)
			_slots[index].position = center - well * 0.5
			_slots[index].size = well
			var icon := well * 0.7
			_icons[index].position = center + Vector2(-0.01 * frame_scale, 0.0) - icon * 0.5
			_icons[index].size = icon
			_counts[index].position = _slots[index].position
			_counts[index].size = well
			ToonGui.style_label(_counts[index], Color.WHITE, _px_of(0.04 * frame_scale), Color(0.05, 0.12, 0.28), 2)
			_paint_slot(track, level)


func _refresh() -> void:
	if loadout == null:
		return
	_paint_jar()
	_paint_pouch()
	_broke = _BEANS.pouch() <= 0
	for track in ToonLoadout.TRACK_COUNT:
		if _bars[track].visible:
			_paint_bar(track)
		for level in ToonLoadout.LEVEL_COUNT:
			_paint_slot(track, level)
	if _status_left <= 0.0:
		_show_beans()


func _paint_bar(track: int) -> void:
	if loadout == null:
		return
	var current := loadout.experience_of(track)
	var nxt := loadout.next_skill(track)
	var span := maxi(nxt, 1)
	var ratio := clampf(float(current) / float(span), 0.0, 1.0)
	_skills[track].text = "%d / %d" % [current, nxt]
	var back := _bars[track]
	_fills[track].position = back.position
	_fills[track].size = Vector2(back.size.x * ratio, back.size.y)


func _paint_slot(track: int, level: int) -> void:
	if loadout == null:
		return
	var index := track * ToonLoadout.LEVEL_COUNT + level
	if index >= _counts.size() or not _counts[index].visible:
		return
	var owned := loadout.count_of(track, level)
	_counts[index].text = str(owned)
	var full := owned >= loadout.carry_limit(track, level) or loadout.pouch_full()
	var blocked := (not _deleting and (_broke or full or level > ToonLoadout.LAST_REGULAR)) or (_deleting and owned <= 0)
	var slot := _slots[index]
	slot.disabled = blocked
	if _deleting and not blocked:
		slot.modulate = _DELETE_TINT
	elif blocked:
		slot.modulate = _UNPRESSABLE
	else:
		slot.modulate = _PRESSABLE
	_icons[index].modulate = Color(0.55, 0.55, 0.55) if blocked else Color.WHITE


func _paint_pouch() -> void:
	var carried := 0
	var limit := ToonLoadout.CARRY
	if loadout != null:
		carried = loadout.gag_count()
		limit = loadout.max_carry
	_pouch.text = "Total gags\n%d / %d" % [carried, limit]


func _paint_jar() -> void:
	_beans.text = str(_BEANS.pouch())
	ToonGui.style_title(_beans, Color(0.95, 0.95, 0.0), _px_of(0.2))


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
	_trash.texture_normal = _TRASH_OPEN if _deleting else _TRASH_CLOSED
	_status_left = 0.0
	_refresh()


func _paint_timer() -> void:
	var whole := int(ceil(_remain))
	_time.text = str(whole)
	var digits := _time.text.length()
	var scale := 0.2
	if digits == 1:
		scale = 0.34
	elif digits == 2:
		scale = 0.27
	var late := whole <= 5
	ToonGui.style_label(_time, Color(1, 0, 0) if late else Color(0, 0, 0), _px_of(scale * 0.45), Color(0, 0, 0, 0), 0)


func _close(reason: String) -> void:
	if _closed:
		return
	_closed = true
	finished.emit(reason)
	queue_free()


func _point(ax: float, az: float) -> Vector2:
	var view := get_viewport().get_visible_rect().size
	var aspect := view.x / maxf(view.y, 1.0)
	return Vector2((ax / aspect + 1.0) * 0.5 * view.x, (1.0 - az) * 0.5 * view.y)


func _size(aw: float, ah: float) -> Vector2:
	var unit := get_viewport().get_visible_rect().size.y * 0.5
	return Vector2(aw * unit, ah * unit)


func _place(control: Control, ax: float, az: float, aw: float, ah: float) -> void:
	var rect := _size(aw, ah)
	control.position = _point(ax, az) - rect * 0.5
	control.size = rect


func _px_of(aspect_height: float) -> int:
	return maxi(int(round(aspect_height * get_viewport().get_visible_rect().size.y * 0.5)), 8)


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
