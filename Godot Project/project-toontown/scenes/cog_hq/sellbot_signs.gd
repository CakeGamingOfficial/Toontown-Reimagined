extends RefCounted

## SellbotCogHQLoader copies sign_sellBotHeadHQ onto each shaft and parents
## OnscreenText to it. The plaque is already in the exported tunnel. These
## lines sit on that plate: Daisy Gardens on the way out, Sellbot Factory on
## the way in, and Sellbot Headquarters on the factory side of that shaft.

const _XY := 23.0
const _ASPECT := 0.7227
const _Z := _XY * _ASPECT


static func place(host: Node) -> void:
	_walk(host)


static func _walk(node: Node) -> void:
	var tunnel_name := String(node.name)
	if node is Node3D and (
		tunnel_name.begins_with("linktunnel_dg_5316")
		or tunnel_name.begins_with("linktunnel_sellhq_11200")
		or tunnel_name.begins_with("linktunnel_sellhq_11000")
	):
		_letter(node as Node3D)
		return
	for child in node.get_children():
		_walk(child)


static func _letter(tunnel: Node3D) -> void:
	var tunnel_name := String(tunnel.name)
	if tunnel_name.begins_with("linktunnel_dg_5316"):
		_write(tunnel, Vector3(0.0, -291.5, 29.0), [
			{"text": "Daisy Gardens", "scale": 0.1, "z": -0.3},
		])
	elif tunnel_name.begins_with("linktunnel_sellhq_11200"):
		_write(tunnel, Vector3(148.625, -155.0, 27.0), [
			{"text": "Sellbot", "scale": 0.075, "z": -0.25},
			{"text": "Factory", "scale": 0.12, "z": -0.34},
		])
	elif tunnel_name.begins_with("linktunnel_sellhq_11000"):
		_write(tunnel, Vector3(0.0, -353.0, 27.5), [
			{"text": "Sellbot", "scale": 0.075, "z": -0.25},
			{"text": "Headquarters", "scale": 0.1, "z": -0.34},
		])


static func _write(tunnel: Node3D, sign_panda: Vector3, lines: Array) -> void:
	var plate := _plate(tunnel)
	if plate == null:
		return
	var center := plate.global_transform * plate.get_aabb().get_center()
	var normal := _plate_normal(plate, tunnel.to_global(sign_panda) - center)
	if normal.length_squared() < 0.01:
		return
	var look := -normal
	var right := look.cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		return
	right = right.normalized()
	# The label's local Z is its face. That axis is the placard's normal, so the
	# words lie on the plate instead of standing out in the tunnel mouth.
	var axes := Basis(right, Vector3.UP, normal).orthonormalized()
	var room := _visible_width(tunnel, plate, center, normal, right)
	var font := ToonGui.suit_font()
	var fit := 1.0
	for item in lines:
		var row: Dictionary = item
		var text_scale := float(row.get("scale", 0.1))
		var px := font.get_string_size(String(row.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x * 0.01
		var world_w := px * text_scale * _XY
		if world_w > room and world_w > 0.01:
			fit = minf(fit, room / world_w)
	for item in lines:
		var row: Dictionary = item
		var text_scale := float(row.get("scale", 0.1)) * fit
		var height := text_scale * _Z
		var label := Label3D.new()
		label.text = String(row.get("text", ""))
		label.font = font
		label.font_size = 100
		label.pixel_size = 0.01
		label.modulate = Color(0.08, 0.08, 0.08, 1.0)
		label.outline_size = 0
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.width = 0.0
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tunnel.add_child(label)
		# OnscreenText pos (0, z) is setPos(0, 0, z) on the sign. The sign's Z
		# scale stretches that offset. Project it onto the placard plane.
		var panda := sign_panda + Vector3(0.0, 0.0, float(row.get("z", -0.3)) * _Z)
		var wanted := tunnel.to_global(panda)
		var on_plane := wanted - normal * (wanted - center).dot(normal)
		var at := on_plane + normal * 0.04
		# Scale the basis columns. Basis.scaled() scales world axes, which
		# extrudes the glyphs off a plate that does not face world X.
		var width := text_scale * _XY
		var flat := Basis(axes.x * width, axes.y * height, axes.z)
		label.global_transform = Transform3D(flat, at)


static func _plate(tunnel: Node) -> MeshInstance3D:
	if tunnel == null:
		return null
	return _find_plate(tunnel)


static func _find_plate(node: Node) -> MeshInstance3D:
	var found: Array = []
	_score_plates(node, found)
	if found.is_empty():
		return null
	return found[0]


## The exported nameplate is the thin face about 27 wide and 7 tall. Factory
## shafts name it polySurface152; the other two shafts name it polySurface15.
static func _score_plates(node: Node, found: Array) -> void:
	if node is MeshInstance3D:
		var size := (node as MeshInstance3D).get_aabb().size
		var dims: Array[float] = [size.x, size.y, size.z]
		dims.sort()
		if dims[0] < 0.05:
			var score := absf(dims[1] - 7.28) + absf(dims[2] - 27.45)
			if found.is_empty() or score < float(found[1]):
				found.clear()
				found.append(node)
				found.append(score)
	for child in node.get_children():
		_score_plates(child, found)


static func _plate_normal(plate: MeshInstance3D, toward_viewer: Vector3) -> Vector3:
	var size := plate.get_aabb().size
	var axis := Vector3(1.0, 0.0, 0.0)
	if size.y <= size.x and size.y <= size.z:
		axis = Vector3(0.0, 1.0, 0.0)
	elif size.z <= size.x and size.z <= size.y:
		axis = Vector3(0.0, 0.0, 1.0)
	var normal := (plate.global_transform.basis * axis).normalized()
	if normal.dot(toward_viewer) < 0.0:
		normal = -normal
	return normal


## How much of the plate can be read from the courtyard. The mouth cheeks cover
## the ends of a full-width "Daisy Gardens", so the line is fitted to the open span.
static func _visible_width(tunnel: Node, plate: MeshInstance3D, center: Vector3, normal: Vector3, right: Vector3) -> float:
	var half := _half_along(plate, right)
	var boxes: Array = []
	_collect_front(tunnel, plate, normal, center, boxes)
	var eye := center + normal * 40.0
	var lo := 0.4
	var hi := half
	for _step in 14:
		var mid := (lo + hi) * 0.5
		var point := center + right * mid + normal * 0.05
		if _segment_clear(eye, point, boxes):
			lo = mid
		else:
			hi = mid
	return maxf(lo * 2.0 * 0.9, 1.0)


static func _half_along(plate: MeshInstance3D, right: Vector3) -> float:
	var box := plate.get_aabb()
	var xf := plate.global_transform
	var center := xf * box.get_center()
	var half := 0.0
	for x in [box.position.x, box.end.x]:
		for y in [box.position.y, box.end.y]:
			for z in [box.position.z, box.end.z]:
				half = maxf(half, absf(((xf * Vector3(x, y, z)) - center).dot(right)))
	return half


static func _collect_front(node: Node, plate: MeshInstance3D, normal: Vector3, center: Vector3, boxes: Array) -> void:
	if node is MeshInstance3D and node != plate:
		var bounds := _world_box(node as MeshInstance3D)
		var min_p: Vector3 = bounds[0]
		var max_p: Vector3 = bounds[1]
		var front := -INF
		for x in [min_p.x, max_p.x]:
			for y in [min_p.y, max_p.y]:
				for z in [min_p.z, max_p.z]:
					front = maxf(front, (Vector3(x, y, z) - center).dot(normal))
		var eye := center + normal * 40.0
		if front > 0.3 and not _point_in_box(eye, min_p, max_p):
			boxes.append(bounds)
	for child in node.get_children():
		_collect_front(child, plate, normal, center, boxes)


static func _world_box(mesh: MeshInstance3D) -> Array:
	var box := mesh.get_aabb()
	var xf := mesh.global_transform
	var min_p := Vector3(INF, INF, INF)
	var max_p := Vector3(-INF, -INF, -INF)
	for x in [box.position.x, box.end.x]:
		for y in [box.position.y, box.end.y]:
			for z in [box.position.z, box.end.z]:
				var world: Vector3 = xf * Vector3(x, y, z)
				min_p = min_p.min(world)
				max_p = max_p.max(world)
	return [min_p, max_p]


static func _segment_clear(from: Vector3, to: Vector3, boxes: Array) -> bool:
	for bounds in boxes:
		if _segment_hits(from, to, bounds[0], bounds[1]):
			return false
	return true


static func _segment_hits(from: Vector3, to: Vector3, box_min: Vector3, box_max: Vector3) -> bool:
	var dir := to - from
	var tmin := 0.0
	var tmax := 1.0
	for axis in 3:
		var origin := from[axis]
		var delta := dir[axis]
		if absf(delta) < 0.00001:
			if origin < box_min[axis] or origin > box_max[axis]:
				return false
			continue
		var t0 := (box_min[axis] - origin) / delta
		var t1 := (box_max[axis] - origin) / delta
		if t0 > t1:
			var swap := t0
			t0 = t1
			t1 = swap
		tmin = maxf(tmin, t0)
		tmax = minf(tmax, t1)
		if tmin > tmax:
			return false
	return tmin <= 1.0 and tmax >= 0.0


static func _point_in_box(point: Vector3, box_min: Vector3, box_max: Vector3) -> bool:
	return point.x >= box_min.x and point.x <= box_max.x and point.y >= box_min.y and point.y <= box_max.y and point.z >= box_min.z and point.z <= box_max.z
