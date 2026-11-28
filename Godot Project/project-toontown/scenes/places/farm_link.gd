extends RefCounted

## Funny Farm is zone 7000. Sleep Street (9300) leaves the pillow in Donald's
## Dreamland, and Barnyard Boulevard (7100) meets it on the way to the farm.
## Dreamland shafts are the pillow and the two streets. The farm mouth that
## opens onto Barnyard Boulevard uses the Toontown Central playground tunnel.
## A shaft's name is the zone it comes out in.

const _GLB := "res://assets/neighborhoods/donalds_dreamland/donalds_dreamland.glb"
const _SOURCE := "linktunnel_dl_9101_DNARoot"
const _TT_GLB := "res://assets/neighborhoods/toontown_central/toontown_central.glb"
const _TT_SOURCE := "linktunnel_tt_2226_DNARoot"

const _GRASS := Color(0.36, 0.72, 0.32)
const _WALK := Color(0.78, 0.74, 0.64)
const _ROAD := Color(0.42, 0.44, 0.46)

static var _template: Node3D
static var _tt_template: Node3D


static func place(host: Node3D) -> void:
	var file := host.scene_file_path.get_file()
	if file == "donalds_dreamland.tscn":
		_pillow(host)
	elif file == "funny_farm.tscn":
		_farm(host)
	elif file == "sleep_street.tscn":
		_street(host, "9300_street", "linktunnel_dl_9000_DNARoot", "linktunnel_ff_7100_DNARoot")
	elif file == "barnyard_boulevard.tscn":
		_street(host, "7100_street", "linktunnel_dl_9300_DNARoot", "linktunnel_ff_7000_DNARoot")


static func _farm(host: Node3D) -> void:
	var zone := host.get_node_or_null("7000_safe_zone") as Node3D
	if zone == null:
		return
	preload("res://scenes/places/farm_yard.gd").build(zone)
	# South gate, on the main-entrance path. Walking out runs north into the playground.
	_barn_gate(zone, "linktunnel_ff_7100_DNARoot", Vector3(0.0, 0.0, 154.0), Vector3(0.0, 0.0, -1.0), "FUNNY FARMS", "PLAYGROUND")
	# Barn Street is the west end of the ring. Orchard Street is the east end.
	# Neither is an exit yet.
	_barn_gate(zone, "farm_barn_west", Vector3(-136.0, 0.0, -2.0), Vector3(1.0, 0.0, 0.0), "BARN STREET", "")
	_barn_gate(zone, "farm_barn_east", Vector3(136.0, 0.0, -4.0), Vector3(-1.0, 0.0, 0.0), "ORCHARD STREET", "")
	_solidify(zone)


static func _street(host: Node3D, zone_name: String, near_name: String, far_name: String) -> void:
	var zone := host.get_node_or_null(zone_name) as Node3D
	if zone == null:
		return
	zone.add_child(_slab(Vector3(190.0, 0.4, 44.0), Vector3(0.0, -0.2, 0.0), _GRASS))
	zone.add_child(_slab(Vector3(190.0, 0.4, 8.0), Vector3(0.0, -0.12, -10.0), _WALK))
	zone.add_child(_slab(Vector3(190.0, 0.4, 8.0), Vector3(0.0, -0.12, 10.0), _WALK))
	zone.add_child(_slab(Vector3(190.0, 0.4, 14.0), Vector3(0.0, -0.05, 0.0), _ROAD))
	# Near mouth faces +X, into the street, back toward its playground.
	_shaft(zone, near_name, Vector3(-80.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0))
	# Far mouth faces -X, into the street, on toward the next zone.
	_shaft(zone, far_name, Vector3(80.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0))


static func _pillow(host: Node3D) -> void:
	if host.find_child("linktunnel_dl_9300_DNARoot", true, false) != null:
		return
	var pillow := host.find_child("pillow_main", true, false) as Node3D
	if pillow == null:
		return
	# Middle of the headboard, on the bed, shoved back against the near wall.
	# The Toon HQ is off the pillow's right side, so the mouth opens +X.
	var mouth := Vector3(-12.0, 1.6, -64.0)
	_shaft(pillow, "linktunnel_dl_9300_DNARoot", mouth, Vector3(1.0, 0.0, 0.0))
	var placed := pillow.find_child("linktunnel_dl_9300_DNARoot", true, false)
	if placed != null:
		_solidify(placed)


static func _shaft(parent: Node, link_name: String, mouth_at: Vector3, out_dir: Vector3, source: Node3D = null) -> void:
	if parent.get_node_or_null(link_name) != null or parent.find_child(link_name, true, false) != null:
		return
	var template: Node3D = source
	if template == null:
		template = _tunnel()
	if template == null:
		return
	var tunnel := template.duplicate() as Node3D
	tunnel.name = link_name
	parent.add_child(tunnel)
	# The copied shaft still wears its original street name.
	_lettering(tunnel, link_name)
	_seat_mouth(tunnel, mouth_at, out_dir)


static func _seat_mouth(tunnel: Node3D, mouth_at: Vector3, out_dir: Vector3) -> void:
	var origin := _mouth(tunnel)
	if origin == null:
		return
	var out := out_dir
	out.y = 0.0
	if out.length_squared() < 0.01:
		out = Vector3(1.0, 0.0, 0.0)
	out = out.normalized()
	var side := out.cross(Vector3.UP)
	var wanted := Transform3D(Basis(side, out, Vector3.UP), mouth_at)
	# Place from the mouth's transform inside the shaft, not the shaft's
	# baked playground position.
	var seated := wanted * _under(tunnel, origin).affine_inverse()
	var parent_node := tunnel.get_parent() as Node3D
	if parent_node == null:
		tunnel.global_transform = seated
	else:
		tunnel.transform = parent_node.global_transform.affine_inverse() * seated


static func _under(root: Node3D, node: Node3D) -> Transform3D:
	var rel := Transform3D.IDENTITY
	var current := node
	while current != root:
		rel = current.transform * rel
		var up := current.get_parent()
		if up is Node3D:
			current = up as Node3D
		else:
			break
	return rel


static func _barn_gate(parent: Node, gate_name: String, mouth_at: Vector3, out_dir: Vector3, line_top: String, line_bottom: String) -> void:
	if parent.get_node_or_null(gate_name) != null or parent.find_child(gate_name, true, false) != null:
		return
	var barn := preload("res://scenes/places/farm_yard.gd").barn_gate(line_top, line_bottom)
	barn.name = gate_name
	parent.add_child(barn)
	_seat_mouth(barn, mouth_at, out_dir)


static func _tunnel() -> Node3D:
	return _cached(_GLB, _SOURCE, _template, false)


static func _tt_tunnel() -> Node3D:
	return _cached(_TT_GLB, _TT_SOURCE, _tt_template, true)


static func _cached(path: String, source_name: String, cached: Node3D, central: bool) -> Node3D:
	if cached != null and is_instance_valid(cached):
		return cached
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var temp := packed.instantiate()
	var found := temp.find_child(source_name, true, false) as Node3D
	if found == null:
		temp.free()
		return null
	var copy := found.duplicate() as Node3D
	temp.free()
	if central:
		_tt_template = copy
	else:
		_template = copy
	return copy


static func _mouth(node: Node) -> Node3D:
	if node is Node3D and String(node.name).begins_with("tunnel_origin"):
		return node as Node3D
	for child in node.get_children():
		var found := _mouth(child)
		if found != null:
			return found
	return null


## The baked sign is two Mickey lines: the place you come out, then its hood.
## Both sit on the mouth plane, local Y 95, centered on local X 60.
static func _lettering(tunnel: Node3D, link_name: String) -> void:
	var zone := 0
	for part in link_name.split("_"):
		if part.is_valid_int():
			zone = part.to_int()
			break
	var street := ""
	var hood := ""
	if zone == 9300:
		street = "Sleep Street"
		hood = "Donald's Dreamland"
	elif zone == 7100:
		street = "Barnyard Boulevard"
		hood = "Funny Farm"
	elif zone == 7000:
		street = "Playground"
		hood = "Funny Farm"
	elif zone == 9000:
		street = "Playground"
		hood = "Donald's Dreamland"
	if street == "":
		return
	# The imported shaft names the letter mesh baseline2, not baseline.
	_clear_letters(tunnel, hood != "Donald's Dreamland")
	# The plaque is the XZ card at local Y 95. The cream inside the red
	# border is about 14 wide, so a long name has to shrink to stay on it.
	_line(tunnel, street, Vector3(60.0, 95.4, 23.3), 1.6, 14.0)
	_line(tunnel, hood, Vector3(60.0, 95.4, 21.5), 1.05, 13.0)


static func _clear_letters(node: Node, hide_logo: bool) -> void:
	var low := String(node.name).to_lower()
	if low.begins_with("baseline") and node is MeshInstance3D:
		(node as MeshInstance3D).mesh = null
	elif hide_logo and low.begins_with("donald") and node is Node3D:
		(node as Node3D).visible = false
	for child in node.get_children():
		_clear_letters(child, hide_logo)


static func _line(tunnel: Node3D, text: String, at: Vector3, tall: float, wide: float) -> void:
	var label := Label3D.new()
	label.name = "StreetName"
	label.text = text
	label.font = ToonGui.sign_font()
	label.font_size = 110
	label.pixel_size = 0.01
	label.modulate = Color(1.0, 1.0, 0.501961, 1.0)
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
	# Label3D faces its -Z. Outside the mouth is local +Y, and up is local +Z.
	# The negative width turns the line around so it reads left to right.
	label.basis = Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, -1.0, 0.0))
	label.scale = Vector3(-fit, fit, 1.0)
	label.position = at
	tunnel.add_child(label)


static func _slab(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = at
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


static func _solidify(node: Node) -> void:
	if node.has_meta("no_solid"):
		return
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null and mesh.visible:
			mesh.create_trimesh_collision()
	for child in node.get_children():
		_solidify(child)
