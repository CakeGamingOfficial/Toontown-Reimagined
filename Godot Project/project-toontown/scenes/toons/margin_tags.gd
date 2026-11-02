extends Node

## Nametag2d plus the MarginManager cells from ToonBase.initNametagGlobals.
## A name sits in a screen cell, with the phase_3 arrow spun toward the
## avatar, when that avatar's card is off the screen. Toon buildings use
## CCToonBuilding, cog buildings use CCSuitBuilding, and both drop off past
## 40 units the way Nametag2d.considerVisible measures them.

const _DOORS := preload("res://scenes/interiors/shop_door.gd")
## Hood id from the playground scene file. Kept here so this board does not
## pull the place table back into the toon that owns it.
const _HOODS: Dictionary = {
	"donalds_dock.tscn": 1000,
	"toontown_central.tscn": 2000,
	"the_burrrgh.tscn": 3000,
	"minnies_melodyland.tscn": 4000,
	"daisy_gardens.tscn": 5000,
	"donalds_dreamland.tscn": 9000,
}
## NametagGroup wordwrap. Buildings are wider than a toon or a suit.
const _TOON_WRAP := 7.5
const _BUILDING_WRAP := 8.5
## considerVisible keeps a building nametag only while distance squared is under this.
const _BUILDING_REACH := 1600.0
const _TEXT_PX := 18
## getArrowColor / the inactive or ready name color for each code we draw.
const _TOON_INK := Color(0.0, 0.6, 0.2, 1.0)
const _TOON_ARROW := Color(0.3, 0.7, 0.3, 1.0)
const _NPC_INK := Color(0.8, 0.4, 0.0, 1.0)
const _NPC_ARROW := Color(1.0, 0.4, 0.2, 1.0)
const _SUIT_INK := Color(0.0, 0.0, 0.0, 1.0)
const _SUIT_ARROW := Color(1.0, 0.4, 0.2, 1.0)
const _TOON_BUILDING := Color(0.3, 0.6, 1.0, 1.0)
const _SUIT_BUILDING := Color(0.55, 0.55, 0.55, 1.0)
## addGridCell columns and rows. Left 0/1-3, bottom 0.5-4.5/0, right 5/2 and 5/1.
const _CELLS: Array[Vector2] = [
	Vector2(0.0, 1.0), Vector2(0.0, 2.0), Vector2(0.0, 3.0),
	Vector2(0.5, 0.0), Vector2(1.5, 0.0), Vector2(2.5, 0.0), Vector2(3.5, 0.0), Vector2(4.5, 0.0),
	Vector2(5.0, 2.0), Vector2(5.0, 1.0),
]
## zone2TitleDict for the playground landmarks (hood + 500 + the sz number).
const _PLAYGROUND_TITLES: Dictionary = {
	1506: "Gag Shop",
	1507: "Toon Headquarters",
	1508: "Clothing Shop",
	2513: "Toon Hall",
	2514: "Toontown Bank",
	2516: "Toontown School House",
	2518: "Toontown Library",
	2519: "Gag Shop",
	2520: "Toon HQ",
	2521: "Clothing Shop",
	2522: "Pet Shop",
	3507: "Gag Shop",
	3508: "Toon HQ",
	3509: "Clothing Shop",
	4503: "Gag Shop",
	4504: "Toon Headquarters",
	4506: "Clothing Shop",
	5501: "Gag Shop",
	5502: "Toon HQ",
	5503: "Clothing Shop",
	9501: "Lullaby Library",
	9503: "The Snooze Bar",
	9504: "Gag Shop",
	9505: "Toon HQ",
	9506: "Clothing Shop",
}

var _layer: CanvasLayer
var _arrow_tex: Texture2D
var _widgets: Array[Dictionary] = []
var _playground: Array[Dictionary] = []
var _playground_host: Node
var _sticky: Dictionary = {}
var _sticky_at: Dictionary = {}


func setup(layer: CanvasLayer) -> void:
	_layer = layer
	_arrow_tex = _make_arrow()
	for _index in _CELLS.size():
		_widgets.append(_make_widget())


func place(camera: Camera3D, host: Node, people: Array) -> void:
	if camera == null or _layer == null:
		_hide_all()
		return
	var view := camera.get_viewport().get_visible_rect()
	if view.size.x < 2.0 or view.size.y < 2.0:
		_hide_all()
		return
	var wish: Array[Dictionary] = []
	for item in people:
		if item is Dictionary:
			_offer_card(item, camera, view, wish)
	_gather_buildings(host, camera, view, wish)
	wish.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"])
	)
	if wish.size() > _CELLS.size():
		wish.resize(_CELLS.size())
	var centers := _cell_centers(view.size)
	var used := {}
	var shown := {}
	for item in wish:
		var key := String(item["key"])
		var cell := _claim_cell(key, item["screen"], centers, used)
		if cell < 0:
			continue
		used[cell] = true
		shown[cell] = true
		_show_widget(cell, item, centers[cell])
	for index in _widgets.size():
		if shown.has(index):
			continue
		var widget: Dictionary = _widgets[index]
		(widget["root"] as Control).visible = false


func _offer_card(item: Dictionary, camera: Camera3D, view: Rect2, wish: Array[Dictionary]) -> void:
	var kind := String(item.get("kind", ""))
	if kind == "player" or kind == "":
		return
	var raw: Variant = item.get("actor")
	if not (raw is Node3D) or not is_instance_valid(raw):
		return
	var actor := raw as Node3D
	if not actor.visible or not actor.is_visible_in_tree():
		return
	var lift := float(item.get("lift", 3.2))
	var point := actor.global_position + Vector3.UP * lift
	if not _needs_margin(camera, point, view):
		return
	var plain := String(item.get("plain", "")).get_slice("\n", 0)
	if plain.is_empty():
		return
	var ink := _TOON_INK
	var arrow := _TOON_ARROW
	var face := ToonGui.font()
	var wrap := _TOON_WRAP
	if kind == "npc":
		ink = _NPC_INK
		arrow = _NPC_ARROW
	elif kind == "cog":
		ink = _SUIT_INK
		arrow = _SUIT_ARROW
		face = ToonGui.suit_font()
	var dist2 := camera.global_position.distance_squared_to(point)
	wish.append({
		"key": "who:%d" % actor.get_instance_id(),
		"text": plain,
		"ink": ink,
		"arrow": arrow,
		"font": face,
		"wrap": wrap,
		"screen": _aim_point(camera, point, view),
		"score": 1000.0 - dist2,
	})


func _gather_buildings(host: Node, camera: Camera3D, view: Rect2, wish: Array[Dictionary]) -> void:
	if host == null:
		return
	var taken := {}
	var buildings := host.get_node_or_null("StreetBuildings")
	if buildings != null:
		var district := int(buildings.get("district_id"))
		var slug := String(buildings.get("street_slug"))
		var net := get_node_or_null("/root/ToonNetwork")
		var rows: Variant = []
		if net != null and net.has_method("latest"):
			var snap: Variant = net.call("latest", "buildings:%d:%s" % [district, slug])
			if snap is Dictionary:
				rows = (snap as Dictionary).get("rows", [])
		if rows is Array:
			for item in rows:
				if not (item is Dictionary):
					continue
				var row: Dictionary = item
				if String(row.get("state", "suit")) == "clearing":
					continue
				var block := int(row.get("block", 0))
				taken[block] = true
				var title := String(row.get("title", "")).strip_edges()
				if title.is_empty():
					title = "COGS"
				title += ", Inc."
				var marked: Variant = buildings.call("marker", block)
				var point := Vector3.ZERO
				if marked is Vector3:
					point = marked
				_offer_building(wish, camera, view, "cogb:%d" % block, title, point, true)
	for entry in _DOORS.named_doors():
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry
		var building: Node3D = row.get("building")
		if building == null or not is_instance_valid(building):
			continue
		if building.has_meta("cog_building") or building.has_meta("suit_approaching"):
			continue
		var block := _DOORS.block_of(str(building.name))
		if taken.has(block):
			continue
		var title := String(_DOORS.record(_DOORS.interior_zone(building)).get("title", "")).strip_edges()
		if title.is_empty():
			continue
		var door: Node3D = row.get("door")
		var point := building.global_position
		if door != null and is_instance_valid(door):
			point = door.global_position
		_offer_building(wish, camera, view, "shop:%d" % building.get_instance_id(), title, point, false)
	_cache_playground(host)
	for spot in _playground:
		var node: Node3D = spot.get("node")
		if node == null or not is_instance_valid(node):
			continue
		_offer_building(wish, camera, view, String(spot["key"]), String(spot["title"]), node.global_position + Vector3.UP * 4.0, false)


func _offer_building(wish: Array[Dictionary], camera: Camera3D, view: Rect2, key: String, title: String, point: Vector3, suit: bool) -> void:
	if title.is_empty() or point == Vector3.ZERO:
		return
	var dist2 := camera.global_position.distance_squared_to(point)
	if dist2 >= _BUILDING_REACH:
		return
	if not _needs_margin(camera, point, view):
		return
	var ink := _SUIT_BUILDING if suit else _TOON_BUILDING
	wish.append({
		"key": key,
		"text": title,
		"ink": ink,
		"arrow": ink,
		"font": ToonGui.sign_font(),
		"wrap": _BUILDING_WRAP,
		"screen": _aim_point(camera, point, view),
		"score": 1000.0 - dist2,
	})


func _cache_playground(host: Node) -> void:
	if _playground_host == host:
		return
	_playground_host = host
	_playground.clear()
	var hood := int(_HOODS.get(host.scene_file_path.get_file(), 0))
	if hood == 0:
		return
	_collect_landmarks(host, hood)


func _collect_landmarks(node: Node, hood: int) -> void:
	var node_name := str(node.name)
	if node_name.begins_with("sz") and node_name.contains("_toon_landmark") and node_name.ends_with("_DNARoot"):
		var zone := _playground_zone(node_name, hood)
		var title := String(_PLAYGROUND_TITLES.get(zone, ""))
		if not title.is_empty() and node is Node3D:
			_playground.append({
				"node": node,
				"title": title,
				"key": "pg:%d" % zone,
			})
	for child in node.get_children():
		_collect_landmarks(child, hood)


func _playground_zone(node_name: String, hood: int) -> int:
	var digits := ""
	var index := 2
	while index < node_name.length() and node_name.substr(index, 1).is_valid_int():
		digits += node_name.substr(index, 1)
		index += 1
	if digits.is_empty():
		return 0
	return hood + 500 + int(digits)


func _needs_margin(camera: Camera3D, point: Vector3, view: Rect2) -> bool:
	if camera.is_position_behind(point):
		return true
	if not camera.is_position_in_frustum(point):
		return true
	var screen := camera.unproject_position(point)
	var pad := view.size * 0.06
	var inset := Rect2(view.position + pad, view.size - pad * 2.0)
	return not inset.has_point(screen)


func _aim_point(camera: Camera3D, point: Vector3, view: Rect2) -> Vector2:
	var rel := point - camera.global_position
	var forward := -camera.global_basis.z
	if rel.dot(forward) <= 0.5:
		var side := camera.global_basis.x.dot(rel)
		var x := view.position.x + 12.0 if side < 0.0 else view.end.x - 12.0
		return Vector2(x, view.position.y + view.size.y * 0.5)
	return camera.unproject_position(point)


func _cell_centers(view: Vector2) -> Array[Vector2]:
	var aspect := view.x / view.y
	var left := -aspect
	var bottom := -1.0
	var cell_w := (aspect * 2.0) / 6.0
	var cell_h := 2.0 / 6.0
	var unit := view.y * 0.5
	var centers: Array[Vector2] = []
	for spot in _CELLS:
		var ax := left + cell_w * (spot.x + 0.5)
		var az := bottom + cell_h * (spot.y + 0.5)
		centers.append(Vector2(view.x * 0.5 + ax * unit, view.y * 0.5 - az * unit))
	return centers


func _claim_cell(key: String, screen: Vector2, centers: Array[Vector2], used: Dictionary) -> int:
	var now := Time.get_ticks_msec()
	var held := int(_sticky.get(key, -1))
	if held >= 0 and held < centers.size() and not used.has(held):
		if now - int(_sticky_at.get(key, 0)) < 30000:
			_sticky_at[key] = now
			return held
	var best := -1
	var best_dist := INF
	for index in centers.size():
		if used.has(index):
			continue
		var dist := centers[index].distance_squared_to(screen)
		if dist < best_dist:
			best_dist = dist
			best = index
	if best >= 0:
		_sticky[key] = best
		_sticky_at[key] = now
	return best


func _show_widget(index: int, item: Dictionary, center: Vector2) -> void:
	var widget: Dictionary = _widgets[index]
	var root := widget["root"] as Control
	var label := widget["label"] as Label
	var arrow := widget["arrow"] as TextureRect
	var text := String(item["text"])
	var font: Font = item["font"]
	var wrap := float(item["wrap"])
	var ink: Color = item["ink"]
	if String(widget.get("text", "")) != text or widget.get("font") != font:
		var wrapped := _wrap(font, text, _TEXT_PX, _TEXT_PX * wrap)
		ToonGui.style_label(label, ink, _TEXT_PX, Color(0, 0, 0, 0), 0)
		label.add_theme_font_override("font", font)
		label.text = wrapped
		label.reset_size()
		widget["text"] = text
		widget["font"] = font
	else:
		label.add_theme_color_override("font_color", ink)
	arrow.modulate = item["arrow"]
	var text_size := label.size
	root.size = text_size + Vector2(0.0, 16.0)
	root.position = center - Vector2(text_size.x * 0.5, text_size.y * 0.5)
	arrow.position = Vector2(text_size.x * 0.5, text_size.y + 1.0) - arrow.size * 0.5
	var aim: Vector2 = item["screen"] - (root.position + arrow.position + arrow.size * 0.5)
	if aim.length_squared() > 1.0:
		arrow.rotation = atan2(aim.y, aim.x)
	root.visible = true


func _wrap(font: Font, text: String, px: int, budget: float) -> String:
	if font == null:
		return text
	var lines: PackedStringArray = []
	var line := ""
	for word in text.split(" ", false):
		var trial := word if line.is_empty() else "%s %s" % [line, word]
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > budget and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = trial
	if not line.is_empty():
		lines.append(line)
	return "\n".join(lines)


func _hide_all() -> void:
	for widget in _widgets:
		(widget["root"] as Control).visible = false


func _make_widget() -> Dictionary:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	root.z_index = 30
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(label)
	var arrow := TextureRect.new()
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.texture = _arrow_tex
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_SCALE
	arrow.size = Vector2(16.0, 16.0)
	arrow.pivot_offset = arrow.size * 0.5
	root.add_child(arrow)
	if _layer != null:
		_layer.add_child(root)
	return {"root": root, "label": label, "arrow": arrow, "text": "", "font": null}


func _make_arrow() -> Texture2D:
	var image := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in 18:
		var reach := int(round((1.0 - absf(float(y) - 8.5) / 8.5) * 16.0))
		for x in reach:
			image.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(image)
