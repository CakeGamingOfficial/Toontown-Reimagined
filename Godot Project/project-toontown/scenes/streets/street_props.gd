extends Node

## InteractiveAnimatedProp for the hydrants, mailboxes, and trash cans on a
## street. Walking onto a block starts their idle reels. The prop tied to that
## block's battle cell buffs one gag track the way the original does: a hydrant
## is squirt, a mailbox is throw, and a trash can is toon-up.

const _GUI := preload("res://scenes/toons/toon_gui.gd")
const _CATALOG := "res://assets/streets/props/catalog.json"
const _BONUSES := "res://assets/streets/props/bonuses.json"

static var _catalog: Dictionary = {}
static var _catalog_loaded := false
static var _bonuses: Dictionary = {}
static var _bonuses_loaded := false
static var _clips: Dictionary = {}

var _props: Array[Prop] = []
var _sad_clock := 0.0


class Prop extends RefCounted:
	var root: Node3D
	var key := ""
	var zone := ""
	var zone_node: Node
	var track := -1
	var meshes: Array[MeshInstance3D] = []
	var mode := ""
	var phase := ""
	var clip: Dictionary = {}
	var frame := 0.0
	var loops_left := 0
	var pause := 0.0
	var idle_index := -1
	var fight_index := 0
	var cheer_time := 0.0
	var shown := false
	var sad_on := false
	var label: Label3D
	var sound: AudioStreamPlayer3D


static func attach(host: Node3D) -> void:
	if Engine.is_editor_hint() or host.get_node_or_null("StreetProps") != null:
		return
	var node := (load("res://scenes/streets/street_props.gd") as GDScript).new() as Node
	node.name = "StreetProps"
	host.add_child(node)


static func bonus_for(slug: String, zone: String) -> int:
	if not _bonuses_loaded:
		_bonuses_loaded = true
		if FileAccess.file_exists(_BONUSES):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_BONUSES))
			if parsed is Dictionary:
				_bonuses = parsed
	var street: Variant = _bonuses.get(slug, {})
	if not (street is Dictionary) or not (street as Dictionary).has(zone):
		return -1
	return int((street as Dictionary)[zone])


func _ready() -> void:
	_load_catalog()
	_collect(get_parent())


func _process(delta: float) -> void:
	if _props.is_empty():
		return
	_sad_clock -= delta
	var refresh := _sad_clock <= 0.0
	if refresh:
		_sad_clock = 1.0
	for prop in _props:
		if prop.root == null or not is_instance_valid(prop.root):
			continue
		var visible := prop.root.is_visible_in_tree()
		if not visible:
			prop.shown = false
			if prop.sound != null and prop.sound.playing:
				prop.sound.stop()
			continue
		if not prop.shown:
			prop.shown = true
			prop.mode = ""
		_choose_mode(prop, refresh)
		_advance(prop, delta)


func _load_catalog() -> void:
	if _catalog_loaded:
		return
	_catalog_loaded = true
	if not FileAccess.file_exists(_CATALOG):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_CATALOG))
	if parsed is Dictionary:
		_catalog = parsed


func _collect(host: Node) -> void:
	if host == null:
		return
	var found: Array[Node] = []
	_find_props(host, found)
	for node in found:
		if not (node is Node3D):
			continue
		var key := _key_of(str(node.name))
		var row: Dictionary = _catalog.get(key, {})
		if row.is_empty():
			continue
		var prop := Prop.new()
		prop.root = node as Node3D
		prop.key = key
		prop.track = _track_of(key)
		prop.zone_node = _zone_node(node)
		if prop.zone_node != null:
			prop.zone = str(prop.zone_node.name)
		var verts: Array = row.get("verts", [])
		_take_meshes(node, prop.meshes, verts)
		if prop.meshes.is_empty():
			continue
		prop.label = _cheer_label(prop)
		prop.sound = AudioStreamPlayer3D.new()
		prop.sound.max_distance = 45.0
		prop.sound.unit_size = 45.0
		prop.root.add_child(prop.sound)
		_props.append(prop)


func _find_props(node: Node, found: Array[Node]) -> void:
	if str(node.name).to_lower().begins_with("interactive_prop_"):
		found.append(node)
		return
	for child in node.get_children():
		_find_props(child, found)


func _key_of(node_name: String) -> String:
	var low := node_name.to_lower()
	var mark := low.find("__")
	if mark < 0:
		return ""
	var tail := low.substr(mark + 2)
	if tail.ends_with("_dnaroot"):
		tail = tail.substr(0, tail.length() - 8)
	return tail


func _track_of(key: String) -> int:
	if key.ends_with("hydrant"):
		return 5
	if key.ends_with("mailbox"):
		return 4
	if key.ends_with("trashcan"):
		return 0
	return -1


func _zone_node(node: Node) -> Node:
	var current := node.get_parent()
	while current != null:
		var name := str(current.name)
		if name.length() == 4 and name.is_valid_int():
			return current
		current = current.get_parent()
	return null


func _take_meshes(node: Node, into: Array[MeshInstance3D], verts: Array) -> void:
	var name := str(node.name).to_lower()
	if name.contains("_med") or name.contains("_low"):
		if node is Node3D:
			(node as Node3D).visible = false
		return
	if node is MeshInstance3D and _mesh_matches(node as MeshInstance3D, verts):
		into.append(node as MeshInstance3D)
	for child in node.get_children():
		_take_meshes(child, into, verts)


func _mesh_matches(mesh: MeshInstance3D, verts: Array) -> bool:
	if mesh.mesh == null or verts.is_empty() or mesh.mesh.get_surface_count() < verts.size():
		return false
	for index in verts.size():
		var arrays: Array = mesh.mesh.surface_get_arrays(index)
		var positions: Variant = arrays[Mesh.ARRAY_VERTEX]
		if not (positions is PackedVector3Array) or (positions as PackedVector3Array).size() != int(verts[index]):
			return false
	return true


func _cheer_label(prop: Prop) -> Label3D:
	var label := Label3D.new()
	label.name = "PropCheer"
	label.text = _word(prop.track)
	label.font = _GUI.sign_font()
	label.font_size = 64
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(0.0, 0.0, 1.0, 1.0)
	label.outline_size = 8
	label.outline_modulate = Color(0.0, 0.0, 0.2, 1.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The street root stands Panda up, so this node's local Z is world up.
	label.position = Vector3(0.0, 0.0, 3.0)
	label.visible = false
	prop.root.add_child(label)
	return label


func _word(track: int) -> String:
	if track == 0:
		return "Super Toon-Up!"
	if track == 4:
		return "Super Throw!"
	if track == 5:
		return "Super Squirt!"
	return ""


func _choose_mode(prop: Prop, refresh_sad: bool) -> void:
	var battle := _battle(prop.zone)
	if battle == "victory":
		if prop.mode != "victory":
			_enter(prop, "victory")
		return
	if battle == "fight":
		if prop.mode != "into" and prop.mode != "cheer":
			_enter(prop, "into")
		return
	if refresh_sad:
		prop.sad_on = _building_sad(prop.zone_node)
	if prop.sad_on:
		if prop.mode != "sad":
			_enter(prop, "sad")
		return
	if prop.mode != "idle":
		_enter(prop, "idle")


func _battle(zone: String) -> String:
	if zone == "":
		return ""
	var suits := get_parent().get_node_or_null("StreetSuits")
	if suits == null:
		return ""
	var district := int(suits.get("district_id"))
	var slug := str(suits.get("street_slug"))
	var state := ToonNet.latest("fights:%d:%s" % [district, slug])
	var rows: Array = state.get("rows", [])
	for item in rows:
		if not (item is Dictionary):
			continue
		var fight: Dictionary = item
		if str(fight.get("zone", "")) != zone:
			continue
		var name := str(fight.get("state", ""))
		if name == "reward":
			return "victory"
		if name == "faceoff" or name == "input" or name == "movie" or name == "reserves":
			return "fight"
	return ""


func _building_sad(zone: Node) -> bool:
	if zone == null:
		return false
	return _has_cog_building(zone)


func _has_cog_building(node: Node) -> bool:
	if node.has_meta("cog_building"):
		return true
	for child in node.get_children():
		if str(child.name).to_lower().begins_with("interactive_prop_"):
			continue
		if _has_cog_building(child):
			return true
	return false


func _enter(prop: Prop, mode: String) -> void:
	prop.mode = mode
	prop.phase = "clip"
	prop.frame = 0.0
	prop.loops_left = 0
	prop.pause = 0.0
	prop.cheer_time = 0.0
	if prop.label != null:
		prop.label.visible = false
	var row: Dictionary = _catalog.get(prop.key, {})
	if mode == "idle":
		_start_idle(prop, row)
	elif mode == "into":
		var into: Variant = row.get("into", {})
		if into is Dictionary and not (into as Dictionary).is_empty():
			_play(prop, into)
		else:
			_enter(prop, "cheer")
	elif mode == "cheer":
		prop.fight_index = 0
		_start_fight(prop, row)
	elif mode == "victory":
		var victory: Variant = row.get("victory", {})
		if victory is Dictionary and not (victory as Dictionary).is_empty():
			_play(prop, victory)
			prop.loops_left = 100000
	elif mode == "sad":
		var sad: Variant = row.get("sad", {})
		if sad is Dictionary and not (sad as Dictionary).is_empty():
			_play(prop, sad)
			prop.loops_left = 100000


func _start_idle(prop: Prop, row: Dictionary) -> void:
	var idles: Array = row.get("idles", [])
	if idles.is_empty():
		return
	var which := _pick_idle(idles.size())
	prop.idle_index = which
	var info: Dictionary = idles[which]
	var min_loop := int(info.get("min_loop", 1))
	var max_loop := int(info.get("max_loop", min_loop))
	prop.loops_left = randi_range(mini(min_loop, max_loop), maxi(min_loop, max_loop))
	prop.phase = "clip"
	_play(prop, info)


func _start_fight(prop: Prop, row: Dictionary) -> void:
	var fights: Array = row.get("fights", [])
	if fights.is_empty():
		return
	if prop.fight_index >= fights.size():
		prop.fight_index = 0
		prop.cheer_time = 0.0
	_play(prop, fights[prop.fight_index])


func _pick_idle(count: int) -> int:
	# chooseIdleAnimToRun. Earlier idles are twice as likely as the next one.
	if count <= 1:
		return 0
	var span := (1 << count) - 1
	var roll := randi_range(1, span)
	var cursor := 0
	for index in count:
		cursor += 1 << (count - 1 - index)
		if roll <= cursor:
			return index
	return count - 1


func _play(prop: Prop, info: Dictionary) -> void:
	var file_name := str(info.get("file", ""))
	var path := "res://assets/streets/props/%s/%s.iprop" % [prop.key, file_name]
	prop.clip = _read_clip(path)
	prop.frame = 0.0
	_pose(prop, 0)
	if prop.sound != null:
		prop.sound.stop()
	if bool(info.get("sound", false)):
		var heard := "res://assets/streets/props/%s/%s.ogg" % [prop.key, file_name]
		if FileAccess.file_exists(heard):
			var stream := AudioStreamOggVorbis.load_from_file(heard)
			if stream != null:
				prop.sound.stream = stream
				prop.sound.play()


func _advance(prop: Prop, delta: float) -> void:
	if prop.mode == "cheer" and prop.label != null:
		prop.cheer_time += delta
		prop.label.visible = prop.cheer_time < 4.0
		prop.label.position.z = lerpf(3.0, 7.0, clampf(prop.cheer_time / 4.0, 0.0, 1.0))
	if prop.phase == "pause":
		prop.pause -= delta
		if prop.pause <= 0.0:
			var row: Dictionary = _catalog.get(prop.key, {})
			_start_idle(prop, row)
		return
	var frames: Array = prop.clip.get("frames", [])
	if frames.is_empty():
		return
	var fps := float(prop.clip.get("fps", 24.0))
	prop.frame += delta * fps
	if prop.frame < float(frames.size()):
		_pose(prop, int(prop.frame))
		return
	if prop.loops_left > 1:
		prop.loops_left -= 1
		prop.frame = fmod(prop.frame, float(frames.size()))
		_pose(prop, int(prop.frame))
		return
	_finish_clip(prop)


func _finish_clip(prop: Prop) -> void:
	var row: Dictionary = _catalog.get(prop.key, {})
	if prop.mode == "into":
		_enter(prop, "cheer")
		return
	if prop.mode == "cheer":
		prop.fight_index += 1
		_start_fight(prop, row)
		return
	if prop.mode == "victory" or prop.mode == "sad":
		prop.frame = 0.0
		_pose(prop, 0)
		prop.loops_left = 100000
		return
	if prop.mode != "idle":
		return
	var idles: Array = row.get("idles", [])
	if prop.phase == "clip" and prop.idle_index >= 0 and prop.idle_index < idles.size():
		var info: Dictionary = idles[prop.idle_index]
		var settle := str(info.get("settle", ""))
		if settle != "":
			prop.phase = "settle"
			prop.loops_left = 1
			_play(prop, {"file": settle, "sound": true})
			return
		_begin_pause(prop, info)
		return
	if prop.phase == "settle" and prop.idle_index >= 0 and prop.idle_index < idles.size():
		_begin_pause(prop, idles[prop.idle_index])
		return
	_start_idle(prop, row)


func _begin_pause(prop: Prop, info: Dictionary) -> void:
	var low := int(info.get("min_pause", 0))
	var high := int(info.get("max_pause", low))
	prop.phase = "pause"
	prop.pause = float(randi_range(mini(low, high), maxi(low, high)))
	if prop.sound != null:
		prop.sound.stop()


func _pose(prop: Prop, frame: int) -> void:
	var frames: Array = prop.clip.get("frames", [])
	if frames.is_empty():
		return
	var index := clampi(frame, 0, frames.size() - 1)
	var surfaces: Array = frames[index]
	for mesh in prop.meshes:
		if not is_instance_valid(mesh) or mesh.mesh == null:
			continue
		var posed := ArrayMesh.new()
		for surface in surfaces.size():
			if surface >= mesh.mesh.get_surface_count():
				break
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			arrays[Mesh.ARRAY_VERTEX] = surfaces[surface]
			posed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var material := mesh.mesh.surface_get_material(surface)
			if material != null:
				posed.surface_set_material(surface, material)
		mesh.mesh = posed


static func _read_clip(path: String) -> Dictionary:
	if _clips.has(path):
		return _clips[path]
	var empty := {"fps": 24.0, "frames": []}
	if not FileAccess.file_exists(path):
		_clips[path] = empty
		return empty
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_clips[path] = empty
		return empty
	var magic := file.get_buffer(8)
	if magic.slice(0, 6).get_string_from_ascii() != "IPROP2":
		file.close()
		_clips[path] = empty
		return empty
	var frame_count := file.get_32()
	var fps := file.get_float()
	var surface_count := file.get_32()
	var counts: Array[int] = []
	counts.resize(surface_count)
	for surface in surface_count:
		counts[surface] = file.get_32()
	var frames: Array = []
	for _frame_index in frame_count:
		var surfaces: Array = []
		for surface in surface_count:
			var positions := PackedVector3Array()
			positions.resize(counts[surface])
			for index in counts[surface]:
				positions[index] = Vector3(file.get_float(), file.get_float(), file.get_float())
			surfaces.append(positions)
		frames.append(surfaces)
	file.close()
	var clip := {"fps": fps, "frames": frames}
	_clips[path] = clip
	return clip
