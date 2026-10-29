class_name GagPanel
extends Control

## The gag inventory from InventoryNew: seven tracks, seven levels. Empty
## slots stay colored. A gag Tutorial Tom has handed over shows its icon
## and how many the toon is carrying.

const _BUTTON := preload("res://assets/gui/tutorial/InventoryButtonUp.png")
const _CUPCAKE := preload("res://assets/gui/tutorial/gags/inventory_tart.png")
const _FLOWER := preload("res://assets/gui/tutorial/gags/inventory_squirt_flower.png")

var _loadout: ToonLoadout
var _icons: Array = []
var _counts: Array = []
var _roots: Array = []


func setup(loadout: ToonLoadout) -> void:
	_loadout = loadout
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(640, 332)
	size = custom_minimum_size
	for track in ToonLoadout.TRACK_COUNT:
		var row := Control.new()
		row.mouse_filter = MOUSE_FILTER_IGNORE
		row.position = Vector2(0, track * 46)
		row.size = Vector2(640, 44)
		add_child(row)
		var title := Label.new()
		title.text = ToonLoadout.TRACK_NAMES[track].to_upper()
		title.position = Vector2(8, 8)
		title.size = Vector2(150, 28)
		title.mouse_filter = MOUSE_FILTER_IGNORE
		ToonGui.style_label(title, Color(0.15, 0.15, 0.15), 18, Color(1, 1, 1, 0.35), 1)
		row.add_child(title)
		var icons: Array = []
		var counts: Array = []
		var roots: Array = []
		for level in ToonLoadout.LEVEL_COUNT:
			var slot := Control.new()
			slot.mouse_filter = MOUSE_FILTER_IGNORE
			slot.position = Vector2(168 + level * 66, 2)
			slot.size = Vector2(60, 40)
			row.add_child(slot)
			var button := TextureRect.new()
			button.texture = _BUTTON
			button.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			button.stretch_mode = TextureRect.STRETCH_SCALE
			button.mouse_filter = MOUSE_FILTER_IGNORE
			button.position = Vector2.ZERO
			button.size = slot.size
			button.modulate = ToonLoadout.TRACK_COLORS[track]
			slot.add_child(button)
			var icon := TextureRect.new()
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = MOUSE_FILTER_IGNORE
			icon.position = Vector2(10, 2)
			icon.size = Vector2(36, 28)
			icon.visible = false
			slot.add_child(icon)
			var badge := Panel.new()
			badge.mouse_filter = MOUSE_FILTER_IGNORE
			badge.position = Vector2(34, 22)
			badge.size = Vector2(22, 16)
			badge.visible = false
			var box := StyleBoxFlat.new()
			box.bg_color = Color(0.16, 0.45, 0.86)
			box.set_corner_radius_all(4)
			badge.add_theme_stylebox_override("panel", box)
			slot.add_child(badge)
			var number := Label.new()
			number.mouse_filter = MOUSE_FILTER_IGNORE
			number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			number.position = Vector2.ZERO
			number.size = badge.size
			number.text = "0"
			ToonGui.style_label(number, Color.WHITE, 12, Color(0, 0, 0), 1)
			badge.add_child(number)
			icons.append(icon)
			counts.append(badge)
			roots.append(slot)
		_icons.append(icons)
		_counts.append(counts)
		_roots.append(roots)
	refresh()


func refresh() -> void:
	if _loadout == null:
		return
	for track in ToonLoadout.TRACK_COUNT:
		for level in ToonLoadout.LEVEL_COUNT:
			var owned := _loadout.unlocked(track, level)
			var icon := _icons[track][level] as TextureRect
			var badge := _counts[track][level] as Panel
			icon.visible = owned
			badge.visible = owned
			if owned:
				icon.texture = _icon_for(track, level)
				var number := badge.get_child(0) as Label
				number.text = str(_loadout.count_of(track, level))


func slot_center(track: int, level: int) -> Vector2:
	var slot := _roots[track][level] as Control
	return slot.get_global_rect().get_center()


func _icon_for(track: int, level: int) -> Texture2D:
	if track == ToonLoadout.THROW and level == 0:
		return _CUPCAKE
	if track == ToonLoadout.SQUIRT and level == 0:
		return _FLOWER
	return null
