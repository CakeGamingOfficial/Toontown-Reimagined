extends RefCounted

## The round Funny Farm from the layout sheet. East is +X, north is -Z,
## and the plaza is the origin. One foot on the sheet is one unit here.
## Shop barns keep the Toontown Central landmark doors so the rooms still open.

const _TT := "res://assets/neighborhoods/toontown_central/toontown_central.glb"
const _PICNIC := "res://assets/neighborhoods/acorn_acres/picnic_tables.glb"
const _CHECKER := "res://assets/neighborhoods/acorn_acres/checker_game.glb"

const _GRASS := Color(0.42, 0.74, 0.28)
const _PATH := Color(0.78, 0.64, 0.38)
const _TRACK := Color(0.55, 0.36, 0.18)
const _FENCE := Color(0.62, 0.42, 0.22)
const _RED := Color(0.86, 0.22, 0.16)
const _ROOF := Color(0.62, 0.14, 0.12)
const _WHITE := Color(0.96, 0.95, 0.9)
const _WATER := Color(0.28, 0.62, 0.86)
const _HAY := Color(0.86, 0.72, 0.28)

# Panda Z-up on the Central export becomes Godot Y-up.
const _UPRIGHT := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))

static var _central: Node


const _GATE := "res://assets/neighborhoods/funny_farm/FF_Tunnel.glb"
const _GATE_SCALE := 18.0
const _SLIDE := "res://assets/neighborhoods/funny_farm/CowSlide.glb"
const _SLIDE_SCALE := 10.0
const _GROUND := "res://assets/neighborhoods/funny_farm/FF_playground.glb"
const _GAG_SHOP := "res://assets/neighborhoods/funny_farm/FF_GagShop.glb"
const _PET_SHOP := "res://assets/neighborhoods/funny_farm/FF_PetShop.glb"
const _CLOTHES := "res://assets/neighborhoods/funny_farm/FF_ClothingShop.glb"
const _HQ_MODEL := "res://assets/neighborhoods/funny_farm/FF_ToonHQ.glb"
const _GAZEBO := "res://assets/neighborhoods/funny_farm/FF_Gazebo.glb"
const _FLOWERS := "res://assets/neighborhoods/funny_farm/FF_Flowers.glb"
const _WINDMILL := "res://assets/neighborhoods/funny_farm/FF_Windmill.glb"
const _MILL_SCALE := 14.0
const _SHOP_SCALE := 16.0
const _FENCE_END := "res://assets/neighborhoods/funny_farm/funny-farms-fence-end-post.glb"
const _FENCE_JOIN := "res://assets/neighborhoods/funny_farm/funny-farms-fence-join-post.glb"
const _FENCE_PANEL := "res://assets/neighborhoods/funny_farm/funny-farms-fence-panel-2m.glb"
# The pieces are modeled in meters. The playground is in feet.
const _FENCE_SCALE := 3.28084
const _PAINT := preload("res://assets/neighborhoods/toontown_central/ttc_paint.gd")


## The modeled barn. Local +Y points out of the mouth, local +Z is up,
## and tunnel_origin sits on the mouth floor so the existing tunnel trip fits.
## The glb is Y-up with its detailed face on +Z. It is turned to face +Y.
static func barn_gate(line_top: String, line_bottom: String) -> Node3D:
	var barn := Node3D.new()
	barn.name = "BarnGate"
	var origin := Node3D.new()
	origin.name = "tunnel_origin"
	barn.add_child(origin)
	var packed := load(_GATE) as PackedScene
	if packed != null:
		var model := packed.instantiate() as Node3D
		if model != null:
			model.name = "FFTunnel"
			model.set_meta("no_solid", true)
			# Right-handed: model up (Y) becomes Z, model front (+Z) becomes +Y.
			model.basis = Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, 1.0, 0.0))
			model.scale = Vector3(_GATE_SCALE, _GATE_SCALE, _GATE_SCALE)
			model.position = Vector3(0.0, -0.58 * _GATE_SCALE, 0.83 * _GATE_SCALE)
			barn.add_child(model)
			_mesh_solid(model)
	# The wood board is just above the arch, under the loft window.
	if line_bottom == "":
		_tunnel_line(barn, line_top, 14.4, 1.5, 13.0)
	else:
		_tunnel_line(barn, line_top, 15.2, 1.15, 13.0)
		_tunnel_line(barn, line_bottom, 13.6, 1.15, 12.0)
	return barn


static func _tunnel_line(barn: Node3D, text: String, high: float, tall: float, wide: float) -> void:
	if text == "":
		return
	var label := Label3D.new()
	label.name = "StreetName"
	label.text = text
	label.font = ToonGui.sign_font()
	label.font_size = 110
	label.pixel_size = 0.01
	label.modulate = Color(0.22, 0.13, 0.06, 1.0)
	label.outline_size = 0
	label.shaded = false
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.double_sided = true
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ascent: float = label.font.get_ascent(110)
	var measured: Vector2 = label.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 110)
	var by_height := tall / maxf(ascent * label.pixel_size, 0.001)
	var by_width := wide / maxf(measured.x * label.pixel_size, 0.001)
	var fit := minf(by_height, by_width)
	# Outside the mouth is local +Y. The negative width keeps the line left to right.
	label.basis = Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, -1.0, 0.0))
	label.scale = Vector3(-fit, fit, 1.0)
	# The board face is recessed just inside the trim. Sit the letters on it.
	label.position = Vector3(0.0, -0.85, high)
	barn.add_child(label)


static func _gate_collision(barn: Node3D) -> void:
	var s := _GATE_SCALE
	var half_w := 0.95 * s
	var hole := 7.5
	var depth := 1.15 * s
	var height := 1.66 * s
	var thick := half_w - hole
	barn.add_child(_solid(Vector3(thick, depth, height), Vector3(-(hole + thick * 0.5), -depth * 0.5, height * 0.5)))
	barn.add_child(_solid(Vector3(thick, depth, height), Vector3(hole + thick * 0.5, -depth * 0.5, height * 0.5)))
	var header_h := height * 0.42
	barn.add_child(_solid(Vector3(hole * 2.0, depth, header_h), Vector3(0.0, -depth * 0.5, height - header_h * 0.5)))


static func _gate_shell(barn: Node3D) -> void:
	var red := Color(0.84, 0.18, 0.16)
	var shade := Color(0.72, 0.12, 0.12)
	var trim := Color(0.97, 0.96, 0.92)
	# Side barns. The opening between x -7 and 7 is the walkway.
	barn.add_child(_pad(Vector3(11.0, 18.0, 14.0), Vector3(-12.5, -9.0, 7.0), red, "GateWall"))
	barn.add_child(_pad(Vector3(11.0, 18.0, 14.0), Vector3(12.5, -9.0, 7.0), red, "GateWall"))
	barn.add_child(_pad(Vector3(14.0, 18.0, 4.0), Vector3(0.0, -9.0, 12.0), red, "GateLintel"))
	# Vertical boards on the front face, so the wall is siding instead of one slab.
	_siding(barn, -12.5, shade)
	_siding(barn, 12.5, shade)
	# Gable faces the path. The slopes fall to the left and right, so the
	# sign sits on the flat wall instead of under the eave.
	_gable(barn, red, trim)
	# Trim sits on the front face only. It does not stick into the path.
	barn.add_child(_pad(Vector3(0.7, 0.45, 10.2), Vector3(-7.3, 0.35, 5.1), trim, "GateJamb"))
	barn.add_child(_pad(Vector3(0.7, 0.45, 10.2), Vector3(7.3, 0.35, 5.1), trim, "GateJamb"))
	barn.add_child(_pad(Vector3(15.4, 0.45, 0.7), Vector3(0.0, 0.35, 10.5), trim, "GateHead"))
	barn.add_child(_pad(Vector3(0.8, 0.4, 14.0), Vector3(-18.2, 0.3, 7.0), trim, "GateCorner"))
	barn.add_child(_pad(Vector3(0.8, 0.4, 14.0), Vector3(18.2, 0.3, 7.0), trim, "GateCorner"))
	barn.add_child(_pad(Vector3(13.4, 16.0, 0.45), Vector3(0.0, -8.0, 10.3), Color(0.62, 0.1, 0.1), "GateCeiling"))


static func _gable(barn: Node3D, red: Color, trim: Color) -> void:
	var face := PrismMesh.new()
	face.size = Vector3(36.0, 8.0, 0.5)
	var gable := _painted(face, red)
	gable.name = "GateGable"
	gable.rotation.x = -PI * 0.5
	gable.position = Vector3(0.0, 0.2, 18.0)
	barn.add_child(gable)
	var left := _pad(Vector3(22.0, 0.55, 20.0), Vector3(-9.5, -9.0, 18.0), red, "GateRoof")
	left.rotation.y = -0.4
	barn.add_child(left)
	var right := _pad(Vector3(22.0, 0.55, 20.0), Vector3(9.5, -9.0, 18.0), red, "GateRoof")
	right.rotation.y = 0.4
	barn.add_child(right)
	barn.add_child(_pad(Vector3(1.0, 18.0, 0.7), Vector3(0.0, -9.0, 22.4), trim, "GateRidge"))


static func _slope(size: Vector3, at: Vector3, tilt: float, color: Color) -> MeshInstance3D:
	var board := _pad(size, at, color, "GateRoof")
	board.rotation.x = tilt
	return board


static func _siding(barn: Node3D, side: float, color: Color) -> void:
	var board := 0
	while board < 4:
		var x := side + (float(board) - 1.5) * 2.4
		barn.add_child(_pad(Vector3(0.35, 0.25, 13.4), Vector3(x, 0.2, 6.7), color, "Siding"))
		board += 1


static func _gate_sign(barn: Node3D, line_top: String, line_bottom: String) -> void:
	var wood := Color(0.78, 0.58, 0.32)
	# One board, sitting in the gap between the doorway and the loft.
	barn.add_child(_pad(Vector3(16.2, 0.4, 5.4), Vector3(0.0, 0.5, 12.2), Color(0.4, 0.22, 0.1), "SignRim"))
	barn.add_child(_pad(Vector3(15.0, 0.45, 4.4), Vector3(0.0, 0.78, 12.2), wood, "SignFace"))
	# The sign font sits high on its line, so both rows are biased down onto the wood.
	_gate_line(barn, line_top, 12.35)
	_gate_line(barn, line_bottom, 11.05)


static func _gate_line(barn: Node3D, text: String, high: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = ToonGui.sign_font()
	label.font_size = 64
	label.pixel_size = 0.012
	label.modulate = Color(0.22, 0.13, 0.06, 1.0)
	label.outline_size = 0
	label.shaded = false
	label.double_sided = true
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Outside is local +Y. Negative width keeps the letters left to right.
	label.basis = Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, -1.0, 0.0))
	label.scale = Vector3(-1.0, 1.0, 1.0)
	label.position = Vector3(0.0, 1.2, high)
	barn.add_child(label)


static func _gate_loft(barn: Node3D) -> void:
	# High in the gable, clear of the sign.
	barn.add_child(_pad(Vector3(4.6, 0.3, 3.4), Vector3(0.0, 0.55, 17.6), _WHITE, "LoftFrame"))
	barn.add_child(_pad(Vector3(3.3, 0.35, 2.3), Vector3(0.0, 0.75, 17.6), Color(0.98, 0.88, 0.45), "LoftGlass"))
	barn.add_child(_pad(Vector3(0.16, 0.4, 2.3), Vector3(0.0, 0.9, 17.6), _WHITE, "LoftBar"))
	barn.add_child(_pad(Vector3(3.3, 0.4, 0.16), Vector3(0.0, 0.9, 17.6), _WHITE, "LoftBar"))
	barn.add_child(_slope(Vector3(6.0, 2.0, 0.3), Vector3(0.0, 1.1, 19.5), -0.45, _ROOF))


static func _gate_vane(barn: Node3D) -> void:
	var iron := Color(0.12, 0.12, 0.14)
	barn.add_child(_pad(Vector3(0.28, 0.28, 3.2), Vector3(0.0, -1.0, 23.0), iron, "VanePole"))
	barn.add_child(_pad(Vector3(2.4, 0.4, 1.05), Vector3(0.3, -1.0, 24.8), iron, "VaneBody"))
	barn.add_child(_pad(Vector3(1.0, 0.4, 0.85), Vector3(1.6, -1.0, 25.3), iron, "VaneHead"))
	barn.add_child(_pad(Vector3(0.25, 0.4, 0.8), Vector3(-0.4, -1.0, 24.2), iron, "VaneLeg"))
	barn.add_child(_pad(Vector3(0.25, 0.4, 0.8), Vector3(0.4, -1.0, 24.2), iron, "VaneLeg"))


static func _gate_barrels(barn: Node3D) -> void:
	_barrel(barn, Vector3(-9.6, 2.6, 1.35))
	_barrel(barn, Vector3(-11.6, 3.6, 1.15))
	_barrel(barn, Vector3(9.6, 2.6, 1.35))
	_barrel(barn, Vector3(11.6, 3.6, 1.15))
	_lantern(barn, -8.6)
	_lantern(barn, 8.6)
	_gate_fence(barn, -12.0)
	_gate_fence(barn, 12.0)


static func _barrel(barn: Node3D, at: Vector3) -> void:
	var drum := CylinderMesh.new()
	drum.top_radius = 1.35
	drum.bottom_radius = 1.45
	drum.height = 2.5
	var barrel := _painted(drum, Color(0.62, 0.38, 0.18))
	barrel.name = "Barrel"
	barrel.position = at
	barrel.rotation.x = PI * 0.5
	barn.add_child(barrel)


static func _lantern(barn: Node3D, side: float) -> void:
	barn.add_child(_pad(Vector3(0.35, 0.35, 2.4), Vector3(side, 0.45, 7.6), Color(0.4, 0.26, 0.14), "LanternPost"))
	barn.add_child(_pad(Vector3(0.9, 0.55, 1.15), Vector3(side, 0.7, 9.0), Color(0.98, 0.78, 0.22), "Lantern"))


static func _gate_fence(barn: Node3D, side: float) -> void:
	var post := 0
	while post < 3:
		var along := 5.5 + float(post) * 3.2
		barn.add_child(_pad(Vector3(0.35, 0.35, 2.3), Vector3(side, along, 1.15), _WHITE, "GateFence"))
		post += 1
	barn.add_child(_pad(Vector3(0.2, 6.4, 0.22), Vector3(side, 8.7, 1.7), _WHITE, "GateRail"))
	barn.add_child(_pad(Vector3(0.2, 6.4, 0.22), Vector3(side, 8.7, 0.9), _WHITE, "GateRail"))


static func build(zone: Node3D) -> void:
	_terrain(zone)
	_fence(zone)
	_trees(zone)
	_flowers(zone)
	_shops(zone)
	_trolley(zone)
	_games(zone)
	_windmill(zone)
	_slide(zone)
	_gazebo(zone)
	_hay(zone)


static func _terrain(zone: Node3D) -> void:
	var packed := load(_GROUND) as PackedScene
	if packed == null:
		return
	var ground := packed.instantiate() as Node3D
	if ground == null:
		return
	ground.name = "FarmGround"
	var water := ground.find_child("Fishing_Pond_Water", true, false)
	if water != null:
		water.name = "fishing_pond"
	# Materials are white. The pasture, dirt, and pond colors live on the vertices.
	_PAINT.paint(ground)
	zone.add_child(ground)


static func _ground(zone: Node3D) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 200.0
	cyl.bottom_radius = 200.0
	cyl.height = 0.6
	cyl.radial_segments = 48
	var disc := _painted(cyl, _GRASS)
	disc.position = Vector3(0.0, -0.3, 0.0)
	disc.name = "FarmLawn"
	zone.add_child(disc)
	var plaza := CylinderMesh.new()
	plaza.top_radius = 8.0
	plaza.bottom_radius = 8.0
	plaza.height = 0.1
	plaza.radial_segments = 20
	var bed := _painted(plaza, Color(0.45, 0.75, 0.32))
	bed.position = Vector3(0.0, 0.08, 0.0)
	bed.name = "PlazaLawn"
	zone.add_child(bed)


static func _paths(zone: Node3D) -> void:
	zone.add_child(_pad(Vector3(24.0, 0.12, 340.0), Vector3(0.0, 0.06, 0.0), _PATH, "PathNorth"))
	zone.add_child(_pad(Vector3(340.0, 0.12, 24.0), Vector3(0.0, 0.06, 0.0), _PATH, "PathEast"))
	zone.add_child(_pad(Vector3(16.0, 0.12, 80.0), Vector3(40.0, 0.07, -90.0), _PATH, "PathGag"))
	zone.add_child(_pad(Vector3(70.0, 0.12, 16.0), Vector3(80.0, 0.07, -40.0), _PATH, "PathCloth"))
	zone.add_child(_pad(Vector3(16.0, 0.12, 70.0), Vector3(70.0, 0.07, 50.0), _PATH, "PathPet"))
	zone.add_child(_pad(Vector3(16.0, 0.12, 70.0), Vector3(-70.0, 0.07, 50.0), _PATH, "PathPond"))
	zone.add_child(_pad(Vector3(70.0, 0.12, 16.0), Vector3(-80.0, 0.07, -40.0), _PATH, "PathSlide"))


static func _track(zone: Node3D) -> void:
	var steps := 36
	var index := 0
	while index < steps:
		var ang := float(index) * TAU / float(steps)
		var mid := Vector3(cos(ang) * 178.0, 0.08, sin(ang) * 178.0)
		var board := _pad(Vector3(18.0, 0.1, 8.0), mid, _TRACK, "TrolleyRing")
		board.rotation.y = -ang
		zone.add_child(board)
		index += 1


static func _fence(zone: Node3D) -> void:
	var end_packed := load(_FENCE_END) as PackedScene
	var join_packed := load(_FENCE_JOIN) as PackedScene
	var panel_packed := load(_FENCE_PANEL) as PackedScene
	if end_packed == null or join_packed == null or panel_packed == null:
		return
	var ring := _fence_ring(zone)
	var length := 0.0
	var step := 0
	while step < ring.size() - 1:
		length += ring[step].distance_to(ring[step + 1])
		step += 1
	var span := 2.0 * _FENCE_SCALE
	var bays := maxi(int(round(length / span)), 1)
	var spacing := length / float(bays)
	var points: Array[Vector3] = []
	var walked := 0.0
	var next_at := 0.0
	var cursor := 0
	while cursor < ring.size() - 1 and points.size() < bays:
		var from: Vector3 = ring[cursor]
		var to: Vector3 = ring[cursor + 1]
		var seg := from.distance_to(to)
		while walked + seg >= next_at and points.size() < bays:
			var along := 0.0
			if seg > 0.001:
				along = (next_at - walked) / seg
			points.append(from.lerp(to, along))
			next_at += spacing
		walked += seg
		cursor += 1
	var open: Array[bool] = []
	var mark := 0
	while mark < points.size():
		open.append(_fence_gap(points[mark]))
		mark += 1
	var fence := Node3D.new()
	fence.name = "FarmFence"
	fence.set_meta("no_solid", true)
	var index := 0
	while index < points.size():
		if not open[index]:
			var prev_i := (index - 1 + points.size()) % points.size()
			var next_i := (index + 1) % points.size()
			var packed := join_packed
			if open[prev_i] or open[next_i]:
				packed = end_packed
			_fence_piece(fence, packed, points[index], 0.0, false)
			if not open[next_i]:
				var dir := points[next_i] - points[index]
				var yaw := atan2(-dir.z, dir.x)
				_fence_piece(fence, panel_packed, points[index], yaw, true)
		index += 1
	zone.add_child(fence)


static func _fence_ring(zone: Node3D) -> Array[Vector3]:
	var center := Vector3(0.4, 0.0, -3.8)
	var mesh_node := zone.find_child("Grass_Terrain", true, false) as MeshInstance3D
	if mesh_node == null or mesh_node.mesh == null:
		return _fence_oval(center, 150.0, 170.0)
	var arrays: Array = mesh_node.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var xf := mesh_node.transform
	var parent := mesh_node.get_parent() as Node3D
	while parent != null and parent != zone:
		xf = parent.transform * xf
		parent = parent.get_parent() as Node3D
	var bins: PackedFloat32Array = PackedFloat32Array()
	var best: Array[Vector3] = []
	var bin := 0
	while bin < 180:
		bins.append(0.0)
		best.append(center)
		bin += 1
	var index := 0
	while index < verts.size():
		var point := xf * verts[index]
		var dx := point.x - center.x
		var dz := point.z - center.z
		var ang := atan2(dz, dx)
		if ang < 0.0:
			ang += TAU
		var slot := int(ang / TAU * 180.0)
		if slot < 0:
			slot = 0
		if slot > 179:
			slot = 179
		var reach := sqrt(dx * dx + dz * dz)
		if reach > bins[slot]:
			bins[slot] = reach
			best[slot] = Vector3(point.x, 0.0, point.z)
		index += 1
	var ring: Array[Vector3] = []
	bin = 0
	while bin < best.size():
		var edge := best[bin]
		var outward := edge - center
		# Keep the post on the grass, with its outer face on the lawn edge.
		if outward.length() > 1.0:
			edge = center + outward.normalized() * (outward.length() - 0.4)
		ring.append(edge)
		bin += 1
	ring.append(ring[0])
	return ring


static func _fence_oval(center: Vector3, radius_x: float, radius_z: float) -> Array[Vector3]:
	var ring: Array[Vector3] = []
	var steps := 180
	var index := 0
	while index <= steps:
		var ang := TAU * float(index) / float(steps)
		ring.append(Vector3(center.x + cos(ang) * radius_x, 0.0, center.z + sin(ang) * radius_z))
		index += 1
	return ring


static func _fence_gap(at: Vector3) -> bool:
	var mouths: Array[Vector3] = [Vector3(0.0, 0.0, 154.0), Vector3(-136.0, 0.0, -2.0), Vector3(136.0, 0.0, -4.0)]
	var index := 0
	while index < mouths.size():
		if at.distance_to(mouths[index]) < 20.0:
			return true
		index += 1
	return false


static func _fence_piece(parent: Node3D, packed: PackedScene, at: Vector3, yaw: float, panel: bool) -> void:
	var piece := packed.instantiate() as Node3D
	if piece == null:
		return
	piece.name = "FencePanel" if panel else "FencePost"
	piece.position = at
	piece.rotation.y = yaw
	piece.scale = Vector3(_FENCE_SCALE, _FENCE_SCALE, _FENCE_SCALE)
	_PAINT.paint(piece)
	var body := StaticBody3D.new()
	body.name = "FenceSolid"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	if panel:
		box.size = Vector3(2.0, 1.0, 0.16)
		shape.position = Vector3(1.0, 0.5, 0.0)
	else:
		box.size = Vector3(0.24, 1.04, 0.24)
		shape.position = Vector3(0.0, 0.52, 0.0)
	shape.shape = box
	body.add_child(shape)
	piece.add_child(body)
	parent.add_child(piece)


static func _gate(ang: float) -> bool:
	# Openings at the entrance, the two streets, and the building spurs.
	var gaps: Array[float] = [PI * 0.5, PI, 0.0, -PI * 0.5, -2.54, -0.73, 0.62]
	var index := 0
	while index < gaps.size():
		if absf(angle_difference(ang, gaps[index])) < 0.34:
			return true
		index += 1
	return false


static func _trees(zone: Node3D) -> void:
	var source := _pull("prop_tree_large_ur_DNARoot")
	if source == null:
		return
	var steps := 16
	var index := 0
	while index < steps:
		var ang := float(index) * TAU / float(steps)
		if _gate(ang):
			index += 1
			continue
		var tree := source.duplicate() as Node3D
		tree.name = "FarmTree"
		_seat(tree, Vector3(cos(ang) * 128.0, 0.0, -4.0 + sin(ang) * 140.0), 0.0)
		zone.add_child(tree)
		index += 1


static func _flowers(zone: Node3D) -> void:
	# Small beds around the plaza and along the paths.
	var spots: Array[Vector3] = [
		Vector3(14.0, 0.0, 14.0), Vector3(-14.0, 0.0, 14.0),
		Vector3(14.0, 0.0, -14.0), Vector3(-14.0, 0.0, -14.0),
		Vector3(22.0, 0.0, 55.0), Vector3(-22.0, 0.0, 55.0),
		Vector3(22.0, 0.0, -55.0), Vector3(-22.0, 0.0, -55.0),
		Vector3(55.0, 0.0, 22.0), Vector3(-55.0, 0.0, 22.0),
	]
	var index := 0
	while index < spots.size():
		_flower_bed(zone, spots[index], index)
		index += 1


static func _shops(zone: Node3D) -> void:
	# Doors face back down the dirt spur. The landmark stays for its door.
	# The front is local +Z. The doorway sits on the north path end, facing the playground.
	_modeled_shop(zone, "sz20_toon_landmark_hqTT_DNARoot", Vector3(0.0, 0.0, -119.0), _HQ_MODEL, 0.49, 1.21, 1.90, -0.49, 0.50, false)
	# The doorway sits on the path end. wide, tall, back, front, and opening are model units.
	_modeled_shop(zone, "sz19_toon_landmark_TT_gag_shop_DNARoot", Vector3(-107.0, 0.0, -74.0), _GAG_SHOP, 0.30, 1.41, 1.90, -0.87, 0.58)
	# Doorway is offset toward the left of the shell. It sits on the northeast spur.
	_modeled_shop(zone, "sz21_toon_landmark_TT_clothes_shop_DNARoot", Vector3(96.0, 0.0, -86.0), _CLOTHES, 0.467, 1.684, 1.90, -0.816, 0.36, false, -0.215, -0.215)
	_modeled_shop(zone, "sz22_toon_landmark_TT_pet_shop_DNARoot", Vector3(129.0, 0.0, 75.0), _PET_SHOP, 0.42, 1.42, 1.90, -0.46, 0.45)


static func _shop(zone: Node3D, source_name: String, at: Vector3, wide: float, deep: float, tall: float, kind: String, title: String) -> void:
	var barn := _storefront(at, wide, deep, tall, kind, title)
	zone.add_child(barn)
	var landmark := _pull(source_name)
	if landmark == null:
		return
	landmark.basis = _toward(at)
	landmark.position = at
	zone.add_child(landmark)
	var front := barn.global_transform * Vector3(0.0, 6.0, deep * 0.5)
	var door := _door(landmark)
	if door != null:
		var shift := front - door.global_position
		shift.y = 0.0
		landmark.global_position += shift
	_quiet(landmark)


## The modeled barn faces the plaza. Its doorway is local +Z at door_z, and the
## landmark door is parked there so the shop still opens. The landmark itself stays hidden.
static func _modeled_shop(zone: Node3D, source_name: String, tip: Vector3, path: String, door_z: float, _wide: float, _tall: float, _back: float, _opening: float, flip_front: bool = false, door_x: float = 0.0, _opening_x: float = 0.0) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var model := packed.instantiate() as Node3D
	if model == null:
		return
	var facing := _face(tip)
	var aim := facing.z
	model.name = "FarmShop"
	model.set_meta("no_solid", true)
	if flip_front:
		model.basis = Basis(-facing.x, facing.y, -facing.z)
	else:
		model.basis = facing
	# Scale after this. Reading basis once scale is set would apply the doorway offset twice.
	var door_local := Vector3(door_x, 0.0, door_z)
	model.position = tip - model.basis * (door_local * _SHOP_SCALE)
	model.scale = Vector3(_SHOP_SCALE, _SHOP_SCALE, _SHOP_SCALE)
	_PAINT.paint(model)
	_mesh_solid(model)
	zone.add_child(model)
	var landmark := _pull(source_name)
	if landmark == null:
		return
	landmark.basis = facing * _UPRIGHT
	if source_name.contains("clothes_shop"):
		# shop_door hangs the clothing door on this local point. Park that point on the new doorway.
		var pivot := Vector3(-4.672, -0.77, 3.827)
		landmark.position = tip - landmark.basis * pivot
		landmark.set_meta("farm_mouth", tip)
		landmark.set_meta("farm_forward", aim)
	else:
		landmark.position = tip
	zone.add_child(landmark)
	var door := _landmark_door(landmark)
	if door != null and not source_name.contains("clothes_shop"):
		var shift := tip - door.global_position
		shift.y = 0.0
		landmark.global_position += shift
		# The pet shop interior looks this door up. Point it out of the new doorway.
		if source_name.contains("pet_shop"):
			door.set_meta("shop_mouth", tip)
			door.set_meta("shop_forward", aim)
			door.set_meta("shop_shell", 0.0)
		door.visible = false
	if source_name.contains("toon_landmark_hq"):
		_seat_hq_doors(landmark, tip)
	_hide_meshes(landmark)


static func _landmark_door(node: Node) -> Node3D:
	if node is Node3D:
		var node_name := str(node.name)
		if node_name.begins_with("door_double_") and not node_name.contains("flat") and not node_name.contains("hole") and not node_name.ends_with("_left") and not node_name.ends_with("_right"):
			return node as Node3D
	for child in node.get_children():
		var found := _landmark_door(child)
		if found != null:
			return found
	return null


static func _seat_hq_doors(landmark: Node3D, tip: Vector3) -> void:
	var index := 0
	while index < 2:
		var door := _named(landmark, "door_%d" % index)
		if door != null:
			var left := _named(door, "leftDoor")
			var right := _named(door, "rightDoor")
			if left != null and right != null:
				var mid := (left.global_position + right.global_position) * 0.5
				door.global_position += tip - mid
			else:
				door.global_position = tip
		var origin := _named(landmark, "door_origin_%d" % index)
		if origin != null:
			origin.global_position = tip
		index += 1


static func _named(node: Node, wanted: String) -> Node3D:
	if node is Node3D and str(node.name) == wanted:
		return node as Node3D
	for child in node.get_children():
		var found := _named(child, wanted)
		if found != null:
			return found
	return null


static func _gazebo(zone: Node3D) -> void:
	var packed := load(_GAZEBO) as PackedScene
	if packed == null:
		return
	var model := packed.instantiate() as Node3D
	if model == null:
		return
	model.name = "Gazebo"
	model.set_meta("no_solid", true)
	model.scale = Vector3(12.0, 12.0, 12.0)
	_PAINT.paint(model)
	_mesh_solid(model)
	zone.add_child(model)


static func _shop_shell(model: Node3D, wide: float, tall: float, back: float, front: float, opening: float, opening_x: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.name = "ShopSolid"
	var left_edge := -wide * 0.5
	var right_edge := wide * 0.5
	var open_left := opening_x - opening * 0.5
	var open_right := opening_x + opening * 0.5
	var left_w := maxf(open_left - left_edge, 0.05)
	var right_w := maxf(right_edge - open_right, 0.05)
	var depth := absf(front - back)
	var mid_z := (front + back) * 0.5
	var into := signf(back - front)
	body.add_child(_shape(Vector3(left_w, tall, depth), Vector3(left_edge + left_w * 0.5, tall * 0.5, mid_z)))
	body.add_child(_shape(Vector3(right_w, tall, depth), Vector3(right_edge - right_w * 0.5, tall * 0.5, mid_z)))
	body.add_child(_shape(Vector3(wide, tall, 0.2), Vector3(0.0, tall * 0.5, back - into * 0.1)))
	var door_top := 0.55
	var lintel := tall - door_top
	body.add_child(_shape(Vector3(opening, lintel, 0.3), Vector3(opening_x, door_top + lintel * 0.5, front + into * 0.15)))
	model.add_child(body)


static func _shape(size: Vector3, at: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	return shape


static func _hide_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).visible = false
	if node is StaticBody3D:
		var body := node as StaticBody3D
		body.collision_layer = 0
		body.collision_mask = 0
	for child in node.get_children():
		_hide_meshes(child)


static func _storefront(at: Vector3, wide: float, deep: float, tall: float, kind: String, title: String) -> Node3D:
	var barn := Node3D.new()
	barn.name = "FarmBarn"
	barn.basis = _face(at)
	barn.position = at
	var wall := _RED
	var trim := _WHITE
	var roof_color := _ROOF
	var door_color := Color(0.22, 0.42, 0.78)
	if kind == "gag":
		wall = Color(0.86, 0.62, 0.36)
		trim = _WHITE
		roof_color = Color(0.55, 0.28, 0.16)
		door_color = Color(0.45, 0.24, 0.12)
	elif kind == "clothes":
		wall = Color(0.45, 0.58, 0.9)
		trim = Color(0.98, 0.82, 0.28)
		roof_color = Color(0.32, 0.38, 0.72)
		door_color = Color(0.98, 0.78, 0.28)
	elif kind == "pet":
		wall = Color(0.96, 0.88, 0.62)
		trim = Color(0.28, 0.48, 0.86)
		roof_color = Color(0.42, 0.55, 0.82)
		door_color = Color(0.28, 0.45, 0.78)
	var wall_top := tall
	barn.add_child(_pad(Vector3(wide + 4.0, 1.6, deep + 4.0), Vector3(0.0, 0.8, 0.0), Color(0.78, 0.74, 0.66), "Step"))
	barn.add_child(_pad(Vector3(wide, wall_top, deep), Vector3(0.0, 1.6 + wall_top * 0.5, 0.0), wall, "BarnWall"))
	barn.add_child(_roof_colored(wide, deep, tall * 0.55, 1.6 + wall_top, roof_color))
	barn.add_child(_pad(Vector3(wide + 1.2, 1.4, deep + 1.2), Vector3(0.0, 1.6 + wall_top, 0.0), trim, "BarnTrim"))
	_posts(barn, wide, deep, wall_top, trim)
	_window(barn, Vector3(-wide * 0.28, 1.6 + wall_top * 0.62, deep * 0.5 + 0.3), Color(0.55, 0.82, 0.95))
	_window(barn, Vector3(wide * 0.28, 1.6 + wall_top * 0.62, deep * 0.5 + 0.3), Color(0.55, 0.82, 0.95))
	_double_door(barn, Vector3(0.0, 7.2, deep * 0.5 + 0.35), door_color)
	_plaque(barn, title, wide, 1.6 + wall_top * 0.78, deep * 0.5 + 1.1, Color(0.15, 0.22, 0.55))
	if kind == "hq":
		_cupola(barn, 1.6 + wall_top + tall * 0.55)
	elif kind == "gag":
		_awning(barn, wide, deep, 1.6 + wall_top * 0.55, _RED, _WHITE)
		_megaphone(barn, 1.6 + wall_top + tall * 0.35)
	elif kind == "pet":
		_awning(barn, wide, deep, 1.6 + wall_top * 0.55, Color(0.25, 0.48, 0.9), _WHITE)
		_bones(barn, wide, 1.6 + wall_top * 0.92, deep)
	return barn


static func _pond(zone: Node3D) -> void:
	var water := CylinderMesh.new()
	water.top_radius = 16.0
	water.bottom_radius = 16.0
	water.height = 0.2
	water.radial_segments = 24
	var pond := _painted(water, _WATER)
	pond.name = "fishing_pond"
	pond.position = Vector3(-120.0, 0.12, 80.0)
	zone.add_child(pond)
	var rim := _pad(Vector3(6.0, 1.2, 6.0), Vector3(-104.0, 0.6, 80.0), _FENCE, "PondDock")
	zone.add_child(rim)


static func _trolley(zone: Node3D) -> void:
	var station := _pull("prop_trolley_station_DNARoot")
	if station == null:
		return
	station.name = "FarmTrolley"
	# Southeast spur. After the upright, yaw 0 faces north, so this turn faces the plaza.
	_seat(station, Vector3(98.0, 0.0, 90.0), 0.84)
	zone.add_child(station)


static func _games(zone: Node3D) -> void:
	var spots: Array[Vector3] = [Vector3(-48.0, 0.0, 36.0), Vector3(48.0, 0.0, 24.0), Vector3(24.0, 0.0, -36.0)]
	var index := 0
	while index < spots.size():
		_prop(zone, _PICNIC, "FarmPicnic", spots[index], 1.0)
		_prop(zone, _CHECKER, "FarmChecker", spots[index] + Vector3(0.0, 1.2, 0.0), 0.6)
		index += 1


static func _windmill(zone: Node3D) -> void:
	var packed := load(_WINDMILL) as PackedScene
	if packed == null:
		return
	var mill := packed.instantiate() as Node3D
	if mill == null:
		return
	var at := Vector3(-112.0, 0.0, -50.0)
	mill.name = "Windmill"
	mill.set_meta("no_solid", true)
	# The door and the rotor are on the model's +Z, so that face looks toward the plaza.
	mill.basis = _face(at)
	mill.scale = Vector3(_MILL_SCALE, _MILL_SCALE, _MILL_SCALE)
	mill.position = at
	_PAINT.paint(mill)
	var tower := mill.find_child("Tower", true, false)
	if tower != null:
		_mesh_solid(tower)
	var rotor := mill.find_child("Rotor", true, false) as Node3D
	if rotor != null:
		rotor.set_script(load("res://scenes/places/farm_spin.gd") as Script)
	zone.add_child(mill)


static func _slide(zone: Node3D) -> void:
	var rig := Node3D.new()
	rig.name = "CowSlide"
	rig.position = Vector3(-132.0, 0.0, -50.0)
	rig.basis = _face(rig.position)
	var packed := load(_SLIDE) as PackedScene
	if packed != null:
		var model := packed.instantiate() as Node3D
		if model != null:
			model.name = "CowSlideModel"
			model.set_meta("no_solid", true)
			# The imported node already sits the mesh on y=0. The cow itself is on local -Z.
			model.rotation.y = PI
			model.scale = Vector3(_SLIDE_SCALE, _SLIDE_SCALE, _SLIDE_SCALE)
			rig.add_child(model)
			_mesh_solid(model)
	zone.add_child(rig)


static func _mesh_solid(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null:
			var before := mesh.get_child_count()
			mesh.create_trimesh_collision()
			var index := before
			while index < mesh.get_child_count():
				var body := mesh.get_child(index) as StaticBody3D
				if body != null:
					body.collision_layer = 1
					body.collision_mask = 0
					var shape_index := 0
					while shape_index < body.get_child_count():
						var shape_node := body.get_child(shape_index) as CollisionShape3D
						if shape_node != null:
							var poly := shape_node.shape as ConcavePolygonShape3D
							if poly != null:
								poly.backface_collision = true
						shape_index += 1
				index += 1
	var next := 0
	while next < node.get_child_count():
		_mesh_solid(node.get_child(next))
		next += 1


static func _signpost(zone: Node3D) -> void:
	var post := Node3D.new()
	post.name = "FarmSign"
	post.position = Vector3(0.0, 0.0, 0.0)
	post.add_child(_pad(Vector3(0.8, 8.0, 0.8), Vector3(0.0, 4.0, 0.0), _FENCE, "SignPole"))
	post.add_child(_pad(Vector3(14.0, 3.4, 0.4), Vector3(0.0, 7.2, 0.0), _WHITE, "SignBoard"))
	var label := Label3D.new()
	label.text = "Funny Farm"
	label.font = ToonGui.sign_font()
	label.font_size = 64
	label.pixel_size = 0.012
	label.modulate = Color(0.15, 0.35, 0.8, 1.0)
	label.outline_size = 6
	label.outline_modulate = Color(1, 1, 1, 1)
	label.position = Vector3(0.0, 7.2, 0.28)
	label.double_sided = true
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	post.add_child(label)
	zone.add_child(post)


static func _hay(zone: Node3D) -> void:
	var spots: Array[Vector3] = [Vector3(64.0, 0.8, 28.0), Vector3(-36.0, 0.8, 48.0), Vector3(36.0, 0.8, -28.0)]
	var index := 0
	while index < spots.size():
		zone.add_child(_pad(Vector3(6.0, 1.6, 3.0), spots[index], _HAY, "HayBale"))
		index += 1


static func _prop(zone: Node3D, path: String, node_name: String, at: Vector3, size: float) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var prop := packed.instantiate() as Node3D
	if prop == null:
		return
	prop.name = node_name
	# These prop files already carry the playground's upright root.
	prop.position = at
	prop.scale = Vector3(size, size, size)
	zone.add_child(prop)


static func _seat(node: Node3D, at: Vector3, yaw: float) -> void:
	node.basis = Basis(Vector3.UP, yaw) * _UPRIGHT
	node.position = at


static func _pull(node_name: String) -> Node3D:
	if _central == null or not is_instance_valid(_central):
		var packed := load(_TT) as PackedScene
		if packed == null:
			return null
		_central = packed.instantiate()
	var found := _central.find_child(node_name, true, false) as Node3D
	if found == null:
		return null
	return found.duplicate() as Node3D


static func _toward(at: Vector3) -> Basis:
	return _face(at) * _UPRIGHT


static func _face(at: Vector3) -> Basis:
	var aim := Vector3(-at.x, 0.0, -at.z)
	if aim.length_squared() < 1.0:
		aim = Vector3(0.0, 0.0, 1.0)
	aim = aim.normalized()
	var side := Vector3.UP.cross(aim)
	return Basis(side, Vector3.UP, aim)


static func _quiet(node: Node) -> void:
	if node is StaticBody3D:
		var body := node as StaticBody3D
		body.collision_layer = 0
		body.collision_mask = 0
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var low := String(mesh.name).to_lower()
		if not low.contains("door") and mesh.mesh != null and mesh.get_aabb().size.length() > 8.0:
			mesh.visible = false
	for child in node.get_children():
		_quiet(child)


static func _door(node: Node) -> Node3D:
	var low := String(node.name).to_lower()
	if node is Node3D and low.contains("door") and not low.contains("flat") and not low.contains("hole"):
		return node as Node3D
	for child in node.get_children():
		var found := _door(child)
		if found != null:
			return found
	return null


static func _flower_bed(zone: Node3D, at: Vector3, which: int) -> void:
	var packed := load(_FLOWERS) as PackedScene
	if packed == null:
		return
	var bed := packed.instantiate() as Node3D
	if bed == null:
		return
	bed.name = "FlowerBed"
	bed.set_meta("no_solid", true)
	bed.rotation.y = float(which) * 0.9
	# The mesh floor is at local y=-0.239. The scale is meters to feet.
	bed.scale = Vector3(_FENCE_SCALE, _FENCE_SCALE, _FENCE_SCALE)
	bed.position = at + Vector3(0.0, 0.239 * _FENCE_SCALE, 0.0)
	_PAINT.paint(bed)
	_mesh_solid(bed)
	zone.add_child(bed)


static func _roof_colored(wide: float, deep: float, roof_h: float, wall_top: float, color: Color) -> MeshInstance3D:
	var prism := PrismMesh.new()
	# Ridge runs along local X after the yaw, so the slopes face the front.
	prism.size = Vector3(deep + 2.4, roof_h, wide + 2.4)
	var roof := _painted(prism, color)
	roof.name = "BarnRoof"
	roof.rotation.y = PI * 0.5
	roof.position = Vector3(0.0, wall_top + roof_h * 0.45, 0.0)
	return roof


static func _posts(barn: Node3D, wide: float, deep: float, wall_top: float, trim: Color) -> void:
	barn.add_child(_pad(Vector3(1.6, wall_top, 1.6), Vector3(-wide * 0.5, 1.6 + wall_top * 0.5, deep * 0.5), trim, "BarnPost"))
	barn.add_child(_pad(Vector3(1.6, wall_top, 1.6), Vector3(wide * 0.5, 1.6 + wall_top * 0.5, deep * 0.5), trim, "BarnPost"))
	barn.add_child(_pad(Vector3(1.6, wall_top, 1.6), Vector3(-wide * 0.5, 1.6 + wall_top * 0.5, -deep * 0.5), trim, "BarnPost"))
	barn.add_child(_pad(Vector3(1.6, wall_top, 1.6), Vector3(wide * 0.5, 1.6 + wall_top * 0.5, -deep * 0.5), trim, "BarnPost"))


static func _window(barn: Node3D, at: Vector3, glass: Color) -> void:
	barn.add_child(_pad(Vector3(5.2, 5.2, 0.4), at, _WHITE, "WindowFrame"))
	barn.add_child(_pad(Vector3(3.4, 3.4, 0.5), at + Vector3(0.0, 0.0, 0.12), glass, "WindowGlass"))
	barn.add_child(_pad(Vector3(0.28, 3.4, 0.55), at + Vector3(0.0, 0.0, 0.2), _WHITE, "WindowBar"))
	barn.add_child(_pad(Vector3(3.4, 0.28, 0.55), at + Vector3(0.0, 0.0, 0.2), _WHITE, "WindowBar"))


static func _double_door(barn: Node3D, at: Vector3, color: Color) -> void:
	barn.add_child(_pad(Vector3(9.2, 12.2, 0.45), at, _WHITE, "DoorFrame"))
	barn.add_child(_pad(Vector3(3.6, 10.4, 0.55), at + Vector3(-2.0, -0.4, 0.15), color, "DoorLeaf"))
	barn.add_child(_pad(Vector3(3.6, 10.4, 0.55), at + Vector3(2.0, -0.4, 0.15), color, "DoorLeaf"))
	barn.add_child(_pad(Vector3(0.35, 10.4, 0.65), at + Vector3(0.0, -0.4, 0.25), _WHITE, "DoorSplit"))


static func _plaque(barn: Node3D, title: String, wide: float, high: float, forward: float, ink: Color) -> void:
	var board := wide * 0.62
	barn.add_child(_pad(Vector3(board + 1.4, 4.8, 0.45), Vector3(0.0, high, forward), Color(0.55, 0.18, 0.14), "SignRim"))
	barn.add_child(_pad(Vector3(board, 3.6, 0.55), Vector3(0.0, high, forward + 0.12), Color(0.98, 0.94, 0.78), "SignFace"))
	var label := Label3D.new()
	label.text = title
	label.font = ToonGui.sign_font()
	label.font_size = 64
	label.pixel_size = 0.011
	label.modulate = ink
	label.outline_size = 0
	label.shaded = false
	label.double_sided = true
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# The front of the barn is local +Z. Flip the width so the letters read correctly.
	label.basis = Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, -1.0))
	label.scale = Vector3(-1.0, 1.0, 1.0)
	label.position = Vector3(0.0, high, forward + 0.45)
	barn.add_child(label)


static func _awning(barn: Node3D, wide: float, deep: float, high: float, first: Color, second: Color) -> void:
	var count := 8
	var index := 0
	var stripe_w := (wide - 2.0) / float(count)
	while index < count:
		var tint := second
		if index % 2 == 0:
			tint = first
		var board := _pad(Vector3(stripe_w - 0.12, 0.45, 7.5), Vector3(-wide * 0.5 + 1.0 + stripe_w * (float(index) + 0.5), high, deep * 0.5 + 2.6), tint, "Awning")
		board.rotation.x = 0.45
		barn.add_child(board)
		index += 1


static func _megaphone(barn: Node3D, high: float) -> void:
	var horn := CylinderMesh.new()
	horn.top_radius = 0.4
	horn.bottom_radius = 2.4
	horn.height = 6.0
	var bell := _painted(horn, Color(0.95, 0.55, 0.15))
	bell.name = "Megaphone"
	bell.position = Vector3(0.0, high, 0.0)
	bell.rotation.x = -0.6
	barn.add_child(bell)


static func _bones(barn: Node3D, wide: float, high: float, deep: float) -> void:
	var left := _pad(Vector3(4.5, 0.7, 0.7), Vector3(-wide * 0.22, high, deep * 0.5 + 0.8), _WHITE, "Bone")
	left.rotation.z = 0.6
	barn.add_child(left)
	var right := _pad(Vector3(4.5, 0.7, 0.7), Vector3(wide * 0.22, high, deep * 0.5 + 0.8), _WHITE, "Bone")
	right.rotation.z = -0.6
	barn.add_child(right)


static func _cupola(barn: Node3D, peak: float) -> void:
	barn.add_child(_pad(Vector3(7.0, 5.0, 7.0), Vector3(0.0, peak + 2.2, 0.0), _WHITE, "Cupola"))
	barn.add_child(_roof_colored(6.0, 6.0, 3.2, peak + 4.6, _ROOF))
	barn.add_child(_pad(Vector3(0.35, 4.5, 0.35), Vector3(0.0, peak + 8.0, 0.0), Color(0.2, 0.2, 0.22), "VanePole"))
	barn.add_child(_pad(Vector3(3.2, 1.3, 0.8), Vector3(1.2, peak + 10.2, 0.0), Color(0.15, 0.15, 0.16), "Vane"))


static func _solid(size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.name = "GateSolid"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return body


static func _pad(size: Vector3, at: Vector3, color: Color, node_name: String) -> MeshInstance3D:
	var box := _painted(BoxMesh.new(), color)
	(box.mesh as BoxMesh).size = size
	box.position = at
	box.name = node_name
	return box


static func _painted(shape: Mesh, color: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh
