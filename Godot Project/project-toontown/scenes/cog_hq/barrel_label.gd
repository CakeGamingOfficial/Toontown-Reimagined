extends RefCounted

## DistributedBarrelBase.loadModel puts the label on gagNode, then each barrel
## kind attaches its own picture. The imported tank is still Panda's axes:
## Z is up, and the label faces -Y.

const _ICE := preload("res://assets/neighborhoods/toontown_central/props/icecream.glb")
const _JAR := preload("res://assets/gui/purchase/Jar.png")
## gagNode.setColorScale(0.7, 0.7, 0.6, 1)
const _TINT := Color(0.7, 0.7, 0.6, 1.0)
## gagLabelDCS.setColor(0.15, 0.15, 0.1)
const _PLATE := Color(0.15, 0.15, 0.1, 1.0)
## gagNode (0, -2.62, 4) plus the icon's (0, -0.1, 0).
const _FACE := Vector3(0.0, -2.72, 4.0)
## Inventory cards are 0.133 across. Gag barrels scale them by 13.
const _GAG_CARD := 0.133
const _GAG_SCALE := 13.0
## BarrelBase.getGagTrack. Throw and squirt are listed twice.
const _RANDOM: Array[int] = [0, 1, 2, 3, 4, 4, 5, 5, 6]


static func track_for(ent_id: int, raw: Variant) -> int:
	if raw is String:
		var text := String(raw)
		if text.is_valid_int():
			return clampi(int(text), 0, 6)
	elif raw is int or raw is float:
		var track := int(raw)
		if track >= 0 and track <= 6:
			return track
	var rng := RandomNumberGenerator.new()
	rng.seed = ent_id
	return _RANDOM[rng.randi() % _RANDOM.size()]


static func dress(root: Node3D, kind: String, track: int, level: int) -> void:
	if root == null or _find(root, "BarrelIcon") != null:
		return
	var host := _find(root, "gagTankAll") as Node3D
	if host == null:
		host = root
	_darken(root)
	if kind == "healBarrel":
		_ice_cream(host)
		return
	var texture: Texture2D = _JAR if kind == "beanBarrel" else BattleMenu.icon_for(track, clampi(level, 0, 6))
	if texture == null:
		return
	var size := Vector2(_GAG_CARD, _GAG_CARD) * _GAG_SCALE
	var at := _FACE
	if kind == "beanBarrel":
		# Jar is 0.433 by 0.529 and is scaled by 3. It is centered on gagNode.
		size = Vector2(0.433, 0.529) * 3.0
	var quad := QuadMesh.new()
	quad.size = size
	var icon := MeshInstance3D.new()
	icon.name = "BarrelIcon"
	icon.mesh = quad
	icon.material_override = _card(texture)
	icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The card faces -Y and its top points up the tank.
	icon.transform = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)), at)
	host.add_child(icon)


static func _ice_cream(host: Node3D) -> void:
	var cream := _ICE.instantiate() as Node3D
	if cream == null:
		return
	cream.name = "BarrelIcon"
	# The baked card is Y-up. Scale 0.6, and its bottom sits 0.7 below gagNode.
	var basis := Basis(Vector3(0.6, 0, 0), Vector3(0, 0, 0.6), Vector3(0, -0.6, 0))
	cream.transform = Transform3D(basis, Vector3(0.0, -2.72, 3.3))
	host.add_child(cream)
	_tint(cream)


static func _card(texture: Texture2D) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.albedo_color = _TINT
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat


static func _darken(root: Node) -> void:
	var plate := _find(root, "gagLabelDCS")
	if plate == null:
		return
	_paint(plate)


static func _paint(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var source := mesh.get_active_material(0)
		var mat := StandardMaterial3D.new()
		if source is StandardMaterial3D:
			mat = (source as StandardMaterial3D).duplicate() as StandardMaterial3D
		mat.albedo_color = _PLATE
		mesh.material_override = mat
	for child in node.get_children():
		_paint(child)


static func _tint(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var source := mesh.get_active_material(0)
		if source is StandardMaterial3D:
			var mat := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
			mat.albedo_color = _TINT
			mesh.material_override = mat
	for child in node.get_children():
		_tint(child)


static func _find(node: Node, wanted: String) -> Node:
	if node == null:
		return null
	if String(node.name) == wanted:
		return node
	for child in node.get_children():
		var found := _find(child, wanted)
		if found != null:
			return found
	return null
