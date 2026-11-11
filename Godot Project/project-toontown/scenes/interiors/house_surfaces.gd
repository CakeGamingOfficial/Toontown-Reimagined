extends RefCounted

## DistributedHouseInterior.__colorWalls. The newest wallpaper, moulding,
## flooring, and wainscoting this toon has accepted are painted on the
## matching wall pieces. The ceiling takes the wallpaper color, darkened.

const _CLOSET := preload("res://scenes/catalog/catalog_closet.gd")
const _FILE := "res://assets/catalog/surfaces.json"

static var _loaded := false
static var _book: Dictionary = {}
static var _textures: Dictionary = {}


static func apply(host: Node) -> void:
	if host == null:
		return
	_load()
	var tokens := _CLOSET.catalog_tokens()
	var paper := _row("wallpaper", _last(tokens, "wallpaper"))
	var mould := _row("moulding", _last(tokens, "moulding"))
	var floor := _row("flooring", _last(tokens, "flooring"))
	var wain := _row("wainscoting", _last(tokens, "wainscoting"))
	if paper.is_empty() and mould.is_empty() and floor.is_empty() and wain.is_empty():
		return
	var shared: Dictionary = {}
	for node in host.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var kind := _kind(String(mesh.name))
		var row := {}
		if kind == "wallpaper" or kind == "ceiling" or kind == "border":
			row = paper
		elif kind == "moulding":
			row = mould
		elif kind == "floor":
			row = floor
		elif kind == "wainscoting":
			row = wain
		if row.is_empty():
			continue
		var stamp := String(row.get("texture", ""))
		if kind == "border":
			stamp = String(row.get("border", stamp))
		elif kind == "ceiling":
			stamp = "ceiling"
		var key := kind + ":" + stamp
		if not shared.has(key):
			shared[key] = _material(mesh, row, kind)
		var mat := shared[key] as Material
		var count := 1
		if mesh.mesh != null:
			count = maxi(mesh.mesh.get_surface_count(), 1)
		for index in count:
			mesh.set_surface_override_material(index, mat)


static func _kind(node_name: String) -> String:
	var called := node_name.to_lower()
	if "border" in called:
		return "border"
	if called.begins_with("ceiling"):
		return "ceiling"
	if called.begins_with("floor"):
		return "floor"
	if called.begins_with("wall_") and "_top" in called:
		return "moulding"
	if called.begins_with("wall_") and "_bottom" in called:
		return "wainscoting"
	if called.begins_with("wall_") or called.begins_with("windowcut"):
		return "wallpaper"
	return ""


static func _material(mesh: MeshInstance3D, row: Dictionary, kind: String) -> StandardMaterial3D:
	var current := mesh.get_active_material(0)
	var mat := StandardMaterial3D.new()
	if current is StandardMaterial3D:
		mat = (current as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var color := _color(row.get("color", []))
	var path := String(row.get("texture", ""))
	if kind == "border":
		path = String(row.get("border", path))
		color = _color(row.get("border_color", row.get("color", [])))
	if kind == "ceiling":
		color = Color(color.r * 0.66, color.g * 0.66, color.b * 0.66, color.a)
		mat.albedo_color = color
		return mat
	var tex := _texture(path)
	if tex != null:
		mat.albedo_texture = tex
	mat.albedo_color = color
	return mat


static func _color(value: Variant) -> Color:
	if value is Array and (value as Array).size() >= 3:
		var rgba: Array = value
		var alpha := 1.0
		if rgba.size() > 3:
			alpha = float(rgba[3])
		return Color(float(rgba[0]), float(rgba[1]), float(rgba[2]), alpha)
	return Color.WHITE


static func _texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _textures.has(path):
		return _textures[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_textures[path] = tex
	return tex


static func _row(kind: String, item_id: int) -> Dictionary:
	if item_id < 0:
		return {}
	var table: Variant = _book.get(kind, {})
	if table is Dictionary:
		var row: Variant = (table as Dictionary).get(str(item_id), {})
		if row is Dictionary:
			return row
	return {}


static func _last(tokens: PackedStringArray, kind: String) -> int:
	var found := -1
	for token in tokens:
		var bits := token.split(":")
		if bits.size() < 2 or bits[0] != kind:
			continue
		found = int(bits[1])
	return found


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(_FILE):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_FILE))
	if parsed is Dictionary:
		_book = parsed
