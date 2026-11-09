extends RefCounted

## Kart.generateKart. Body color tints chasse, accessory color tints the
## vertex cards, and hood, trunk, and wheel pieces hang on their attach nodes.

const _GARAGE := preload("res://scenes/racing/kart_garage.gd")
const _CATALOG := "res://assets/racing/catalog.json"
const _MAPS := "res://assets/racing/maps/"

static var _book: Dictionary = {}


static func build(row: Array = []) -> Node3D:
	var dna := row if not row.is_empty() else _GARAGE.dna()
	var root := Node3D.new()
	root.name = "Kart"
	var body := int(dna[0]) if dna.size() > 0 else 0
	if body < 0:
		body = 0
	var packed := load("res://assets/racing/karts/kart_%d.glb" % clampi(body, 0, 2)) as PackedScene
	if packed == null:
		return root
	var model := packed.instantiate()
	root.add_child(model)
	_tint_named(model, "chasse", _color(int(dna[1]) if dna.size() > 1 else -1))
	_hide_decals(model)
	if dna.size() > 8:
		_attach(model, int(dna[3]), int(dna[2]))
		_attach(model, int(dna[4]), int(dna[2]))
		_attach_pair(model, int(dna[5]), int(dna[2]))
		_attach_pair(model, int(dna[6]), int(dna[2]))
		_apply_rims(model, int(dna[7]), body)
		_apply_decal(model, int(dna[8]), body)
	return root


static func item(accessory: int) -> Dictionary:
	_load()
	for entry in _book.get("accessories", []):
		if entry is Dictionary and int((entry as Dictionary).get("id", -2)) == accessory:
			return entry
	return {}


static func karts() -> Array:
	_load()
	var rows: Array = _book.get("karts", [])
	return rows


static func of_kind(kind: String) -> Array:
	# AccessoryTypeDict. Colors are shared by the body and the accessories.
	_load()
	var rows: Array = []
	for entry in _book.get("accessories", []):
		if not (entry is Dictionary):
			continue
		var card: Dictionary = entry
		var acc_id := int(card.get("id", -1))
		var matches := false
		if kind == "color":
			matches = String(card.get("kind", "")) == "color"
		elif kind == "hood":
			matches = acc_id >= 0 and acc_id <= 10
		elif kind == "trunk":
			matches = acc_id >= 11 and acc_id <= 18
		elif kind == "front":
			matches = acc_id >= 19 and acc_id <= 26
		elif kind == "back":
			matches = acc_id >= 27 and acc_id <= 39
		elif kind == "rim":
			matches = String(card.get("kind", "")) == "rim"
		elif kind == "decal":
			matches = String(card.get("kind", "")) == "decal"
		if matches:
			rows.append(card)
	return rows


static func field_for(kind: String) -> int:
	match kind:
		"color":
			return 1
		"hood":
			return 3
		"trunk":
			return 4
		"front":
			return 5
		"back":
			return 6
		"rim":
			return 7
		"decal":
			return 8
		_:
			return 2


static func _attach(model: Node, accessory: int, color_id: int) -> void:
	var card := item(accessory)
	if card.is_empty() or not card.has("file"):
		return
	var packed := load(String(card.get("file", ""))) as PackedScene
	if packed == null:
		return
	var piece := packed.instantiate()
	var anchor := _find(model, String(card.get("attach", "")))
	(anchor if anchor != null else model).add_child(piece)
	_tint_named(piece, "vertex", _color(color_id))


static func _attach_pair(model: Node, accessory: int, color_id: int) -> void:
	var card := item(accessory)
	if card.is_empty() or not card.has("file"):
		return
	var pattern := String(card.get("attach", ""))
	if not pattern.contains("%s"):
		_attach(model, accessory, color_id)
		return
	var packed := load(String(card.get("file", ""))) as PackedScene
	if packed == null:
		return
	for side in ["left", "right"]:
		var piece := packed.instantiate()
		var anchor := _find(model, pattern % side)
		(anchor if anchor != null else model).add_child(piece)
		_tint_named(piece, "vertex", _color(color_id))


static func _apply_rims(model: Node, accessory: int, _body: int) -> void:
	var which := accessory
	if which < 0:
		which = 40
	var card := item(which)
	var tex_name := String(card.get("tex", ""))
	if tex_name.is_empty():
		return
	var texture := load(_MAPS + tex_name + ".png") as Texture2D
	if texture == null:
		return
	_paint_named(model, "WheelRim", texture)


static func _apply_decal(model: Node, accessory: int, body: int) -> void:
	var card := item(accessory)
	if card.is_empty():
		return
	var number := int(card.get("decal", 0))
	if number <= 0:
		return
	var slug := "kart%d" % (clampi(body, 0, 2) + 1)
	var hood := load("%s%s_HoodDecal_%d.png" % [_MAPS, slug, number]) as Texture2D
	var side := load("%s%s_SideDecal_%d.png" % [_MAPS, slug, number]) as Texture2D
	_paint_named(model, "hoodDecal", hood)
	_paint_named(model, "SideDecal", side)
	_show_named(model, "Decal")


static func _color(accessory: int) -> Color:
	var card := item(accessory)
	var parts: Variant = card.get("color", [])
	if parts is Array and (parts as Array).size() >= 3:
		var row: Array = parts
		return Color(float(row[0]), float(row[1]), float(row[2]), 1.0)
	return Color.WHITE


static func _hide_decals(node: Node) -> void:
	if String(node.name).contains("Decal"):
		node.visible = false if node is Node3D else node.visible
	for child in node.get_children():
		_hide_decals(child)


static func _show_named(node: Node, needle: String) -> void:
	if String(node.name).contains(needle):
		node.visible = true
	for child in node.get_children():
		_show_named(child, needle)


static func _tint_named(node: Node, needle: String, color: Color) -> void:
	if color == Color.WHITE:
		return
	if String(node.name).contains(needle) and node is MeshInstance3D:
		_tint_mesh(node as MeshInstance3D, color)
	for child in node.get_children():
		_tint_named(child, needle, color)


static func _tint_mesh(mesh: MeshInstance3D, color: Color) -> void:
	if mesh.mesh == null:
		return
	for surface in mesh.mesh.get_surface_count():
		var material := mesh.get_active_material(surface)
		if material == null:
			continue
		var copy := material.duplicate() as StandardMaterial3D
		if copy == null:
			continue
		copy.albedo_color = color
		mesh.set_surface_override_material(surface, copy)


static func _paint_named(node: Node, needle: String, texture: Texture2D) -> void:
	if texture == null:
		return
	if String(node.name).contains(needle) and node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		mesh.visible = true
		if mesh.mesh == null:
			return
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			if material == null:
				continue
			var copy := material.duplicate() as StandardMaterial3D
			if copy == null:
				continue
			copy.albedo_texture = texture
			mesh.set_surface_override_material(surface, copy)
	for child in node.get_children():
		_paint_named(child, needle, texture)


static func _find(node: Node, name: String) -> Node:
	if name.is_empty():
		return null
	if String(node.name) == name or String(node.name).ends_with(name):
		return node
	for child in node.get_children():
		var found := _find(child, name)
		if found != null:
			return found
	return null


static func _load() -> void:
	if not _book.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_CATALOG))
	if parsed is Dictionary:
		_book = parsed
