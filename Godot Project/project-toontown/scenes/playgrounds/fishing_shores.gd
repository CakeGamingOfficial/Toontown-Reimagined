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
	var index := 0
	for entry in spots:
		index += 1
		var row: Array = entry
		var spot := Node3D.new()
		# A repeated name is discarded, so the later docks never matched a search.
		spot.name = "FishingShore%d" % index
		holder.add_child(spot)
		var heading := float(row[3])
		if anchored:
			spot.global_position = origin.global_position + Vector3(float(row[0]), float(row[1]), float(row[2]))
		else:
			spot.global_position = Vector3(float(row[0]), float(row[1]), float(row[2]))
		var pier := _take_pier(host, spot.global_position)
		if pier != null:
			# The cast stands on the exported pier, facing along its planks.
			spot.global_transform = pier.global_transform
			heading = _heading_of(pier)
		else:
			spot.global_basis = _basis(heading)
		spot.set_meta("heading", heading)
		spot.set_meta("zone", zone)
		spot.set_meta("water", water)


static func _take_pier(host: Node, near: Vector3) -> Node3D:
	var best: Node3D = null
	var best_gap := 12.0
	for node in host.find_children("fishing_spot*", "Node3D", true, false):
		var pier := node as Node3D
		if pier == null or pier.has_meta("shore_taken"):
			continue
		var gap := pier.global_position.distance_to(near)
		if gap < best_gap:
			best_gap = gap
			best = pier
	if best != null:
		best.set_meta("shore_taken", true)
	return best


static func _heading_of(pier: Node3D) -> float:
	var forward := pier.global_basis * Vector3(0.0, 1.0, 0.0)
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(atan2(-forward.x, -forward.z))


static func _basis(heading: float) -> Basis:
	var upright := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	return upright.rotated(Vector3.UP, deg_to_rad(heading))
