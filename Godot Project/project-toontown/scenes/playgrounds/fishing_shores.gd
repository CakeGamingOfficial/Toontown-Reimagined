extends RefCounted

## DNA fishing_spot. Walking into the 1.5 sphere starts a cast. The spot's
## heading is the direction the toon faces, out over the pond.

const _DATA := preload("res://scenes/playgrounds/fishing_shore_data.gd")


static func place(host: Node) -> void:
	if host == null or Engine.is_editor_hint():
		return
	if host.find_child("FishingShores", true, false) != null:
		return
	var file := host.scene_file_path.get_file()
	if file.begins_with("toon_estate"):
		file = "toon_estate.tscn"
	var info: Dictionary = _DATA.SHORES.get(file, {})
	if info.is_empty():
		return
	var anchored := bool(info["anchored"])
	var origin: Node3D = null
	if anchored:
		origin = host.find_child("npc_fisherman_origin_0", true, false) as Node3D
		if origin == null:
			return
	var pond := host.find_child("fishing_pond*", true, false) as Node3D
	if pond == null:
		pond = host as Node3D
	if pond == null:
		return
	var holder := Node3D.new()
	holder.name = "FishingShores"
	pond.add_child(holder)
	var zone := int(info["zone"])
	var water := float(info["water"])
	var spots: Array = info["spots"]
	for entry in spots:
		var row: Array = entry
		var spot := Node3D.new()
		spot.name = "FishingShore"
		holder.add_child(spot)
		var heading := float(row[3])
		if anchored:
			spot.global_position = origin.global_position + Vector3(float(row[0]), float(row[1]), float(row[2]))
		else:
			spot.global_position = Vector3(float(row[0]), float(row[1]), float(row[2]))
		spot.global_basis = _basis(heading)
		spot.set_meta("heading", heading)
		spot.set_meta("zone", zone)
		spot.set_meta("water", water)


static func _basis(heading: float) -> Basis:
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	return upright.rotated(Vector3.UP, deg_to_rad(heading))
