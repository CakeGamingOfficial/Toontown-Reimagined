extends Node
class_name JokeDoors

## Knock-knock doors for every street. The original sphere sits on a side door
## (door_single_* / door_garage_*), not the shop's front door. Those spheres
## were not in the street export, so the side-door panel stands in for one.
## A cog takeover removes the door, same as DistributedBuildingAI.exitBecomingSuit.
## Stepping up tells the joke every time. The heal matches that playground's
## treasure, and only the heal waits before the same door will give it again.

const _SHOP := preload("res://scenes/interiors/shop_door.gd")
const _TREASURES := preload("res://scenes/playgrounds/playground_treasures.gd")
const _KNOCK := "res://assets/audio/sfx/GUI_knock_3.ogg"
const _RIM := "res://assets/audio/battle/AA_heal_telljoke.ogg"
## How close you have to be to the spot in front of the side door. The shop
## entrance is farther than this, so walking into the main door does not start
## the joke. The panel mesh does not sit on the door node's origin, so the
## spot is the center of that panel.
const _REACH := 4.0
const _FRONT := 1.6
## RegenTreasurePlannerAI.spawnInterval is 20 seconds in most playgrounds.
## One door will not heal faster than picking up treasures.
const _COOLDOWN_MS := 20000
const _TALL := 10.0
## Nametags lifts an empty marker by about 3.6. Sitting the marker on the
## panel puts the Door card, and its balloon, at the top of the door.
const _DOOR_RAISE := 0.5
const _DOOR_INK := Color(0.25, 0.28, 0.75)

const _LOOPY := {
	28: ["Biscuit", "Biscuit out of here the Cogs are coming!"],
	41: ["Dewey", "Dewey want to go defeat some more Cogs?"],
	40: ["Minnie", "Minnie people have asked that, and it's driving me crazy!"],
	27: ["Disguise", "Disguise where the Cogs fly!"],
}
const _POLAR := {
	10: ["Aladdin", "Aladdin HQ wants a word with you."],
	6: ["Weirdo", "Weirdo all these Cogs come from?"],
	30: ["Bacon", "Bacon a cake to throw at the Cogs."],
	28: ["Isaiah", "Isaiah we go ride the trolley."],
	12: ["Juliet", "Juliet me in that Cog building with you and I'll give you a Toon-Up."],
}
## TTLocalizer.KnockKnockJokes. The block number picks one, wrapping at the end.
const _JOKES: Array = [
	["Who", "Bad echo in here, isn't there?"],
	["Dozen", "Dozen anybody want to let me in?"],
	["Freddie", "Freddie or not, here I come."],
	["Dishes", "Dishes your friend, let me in."],
	["Wooden shoe", "Wooden shoe like to know."],
	["Betty", "Betty doesn't know who I am."],
	["Kent", "Kent you tell?"],
	["Noah", "Noah don't know who either."],
	["I don't know", "Neither do I, I keep telling you that."],
	["Howard", "Howard I know?"],
	["Emma", "Emma so glad you asked me that."],
	["Auto", "Auto know, but I've forgotten."],
	["Jess", "Jess me and my shadow."],
	["One", "One-der why you keep asking that?"],
	["Alma", "Alma not going to tell you!"],
	["Zoom", "Zoom do you expect?"],
	["Amy", "Amy fraid I've forgotten."],
	["Arfur", "Arfur got."],
	["Ewan", "No, just me"],
	["Cozy", "Cozy who's knocking will you?"],
	["Sam", "Sam person who knocked on the door last time."],
	["Fozzie", "Fozzie hundredth time, my name is Flippy."],
	["Deduct", "Donald Deduct."],
	["Max", "Max no difference, just open the door."],
	["N.E.", "N.E. body you like, let me in."],
	["Amos", "Amos-quito bit me."],
	["Alma", "Alma candy's gone."],
	["Bruce", "I Bruce very easily, don't hit me."],
	["Colleen", "Colleen up your room, it's filthy."],
	["Elsie", "Elsie you later."],
	["Hugh", "Hugh is going to let me in?"],
	["Hugo", "Hugo first - I'm scared."],
	["Ida", "Ida know.  Sorry!"],
	["Isabel", "Isabel on a bike really necessary?"],
	["Joan", "Joan call us, we'll call you."],
	["Kay", "Kay, L, M, N, O, P."],
	["Justin", "Justin time for dinner."],
	["Liza", "Liza wrong to tell."],
	["Luke", "Luke and see who it is."],
	["Mandy", "Mandy the lifeboats, we're sinking."],
	["Max", "Max no difference - just open the door!"],
	["Nettie", "Nettie as a fruitcake."],
	["Olivia", "Olivia me alone!"],
	["Oscar", "Oscar stupid question, you get a stupid answer."],
	["Patsy", "Patsy dog on the head, he likes it."],
	["Paul", "Paul hard, the door's stuck again."],
	["Thea", "Thea later, alligator."],
	["Tyrone", "Tyrone shoelaces, you're old enough."],
	["Stella", "Stella no answer at the door."],
	["Uriah", "Keep Uriah on the ball."],
	["Dwayne", "Dwayne the bathtub.  I'm drowning."],
	["Dismay", "Dismay be a joke, but it didn't make me laugh."],
	["Ocelot", "Ocelot of questions, don't you?"],
	["Thermos", "Thermos be a better knock knock joke than this."],
	["Sultan", "Sultan Pepper."],
	["Vaughan", "Vaughan day my prince will come."],
	["Donald", "Donald come baby, cradle and all."],
	["Lettuce", "Lettuce in, won't you?"],
	["Ivor", "Ivor sore hand from knocking on your door!"],
	["Isabel", "Isabel broken, because I had to knock."],
	["Heywood, Hugh, Harry", "Heywood Hugh Harry up and open this door."],
	["Juan", "Juan of this days you'll find out."],
	["Earl", "Earl be glad to tell you if you open this door."],
	["Abbot", "Abbot time you opened this door!"],
	["Ferdie", "Ferdie last time, open the door!"],
	["Don", "Don mess around, just open the door."],
	["Sis", "Sis any way to treat a friend?"],
	["Isadore", "Isadore open or locked?"],
	["Harry", "Harry up and let me in!"],
	["Theodore", "Theodore wasn't open so I knocked-knocked."],
	["Ken", "Ken I come in?"],
	["Boo", "There's no need to cry about it."],
	["You", "You who!  Is there anybody there?"],
	["Ice cream", "Ice cream if you don't let me in."],
	["Sarah", "Sarah 'nother way into this building?"],
	["Mikey", "Mikey dropped down the drain."],
	["Doris", "Doris jammed again."],
	["Yelp", "Yelp me, the door is stuck."],
	["Scold", "Scold outside."],
	["Diana", "Diana third, can I have a drink please?"],
	["Doris", "Doris slammed on my finger, open it quick!"],
	["Lettuce", "Lettuce tell you some knock knock jokes."],
	["Izzy", "Izzy come, izzy go."],
	["Omar", "Omar goodness gracious - wrong door!"],
	["Says", "Says me, that's who!"],
	["Duck", "Just duck, they're throwing things at us."],
	["Tank", "You're welcome."],
	["Eyes", "Eyes got loads more knock knock jokes for you."],
	["Pizza", "Pizza cake would be great right now."],
	["Closure", "Closure mouth when you eat."],
	["Harriet", "Harriet all my lunch, I'm starving."],
	["Wooden", "Wooden you like to know?"],
	["Punch", "Not me, please."],
	["Gorilla", "Gorilla me a hamburger."],
	["Jupiter", "Jupiter hurry, or you'll miss the trolley."],
	["Bertha", "Happy Bertha to you!"],
	["Cows", "Cows go \"moo\" not \"who.\""],
	["Tuna fish", "You can tune a piano, but you can't tuna fish."],
	["Consumption", "Consumption be done about all these knock knock jokes?"],
	["Banana", "Banana spilt so ice creamed."],
	["X", "X-tremely pleased to meet you."],
	["Haydn", "Haydn seek is fun to play."],
	["Rhoda", "Rhoda boat as fast as you can."],
	["Quacker", "Quacker 'nother bad joke and I'm off!"],
	["Nana", "Nana your business."],
	["Ether", "Ether bunny."],
	["Little old lady", "My, you're good at yodelling!"],
	["Beets", "Beets me, I forgot the joke."],
	["Hal", "Halloo to you too!"],
	["Sarah", "Sarah doctor in the house?"],
	["Aileen", "Aileen Dover and fell down."],
	["Atomic", "Atomic ache"],
	["Agatha", "Agatha headache.  Got an aspirin?"],
	["Stan", "Stan back, I'm going to sneeze."],
	["Hatch", "Bless you."],
	["Ida", "It's not Ida who, it's Idaho."],
	["Zippy", "Mrs. Zippy."],
	["Yukon", "Yukon go away and come back another time."],
]

var _doors: Array[Dictionary] = []
var _cleanup := 8.0


static func attach(host: Node) -> void:
	if host == null or Engine.is_editor_hint():
		return
	if host.get_node_or_null("JokeDoors") != null:
		return
	var node := new()
	node.name = "JokeDoors"
	host.add_child(node)


static func joke_count() -> int:
	return _JOKES.size()


static func joke_for(zone_id: int, block: int) -> PackedStringArray:
	if zone_id == 2100 and block == 44:
		return PackedStringArray(["Wally", "Wally's not looking, hit him with a pie!"])
	if zone_id == 2300 and block == 1:
		return PackedStringArray(["Justin", "Justin other couple of Cog parts and off we go!"])
	if zone_id == 2200 and _LOOPY.has(block):
		var loopy: Array = _LOOPY[block]
		return PackedStringArray([String(loopy[0]), String(loopy[1])])
	if zone_id == 3300 and _POLAR.has(block):
		var polar: Array = _POLAR[block]
		return PackedStringArray([String(polar[0]), String(polar[1])])
	var pair: Array = _JOKES[posmod(block, _JOKES.size())]
	return PackedStringArray([String(pair[0]), String(pair[1])])


func _ready() -> void:
	_cleanup = minf(9.0, 4.0 + maxf(4.0, _rim_remain()))
	var host := get_parent()
	if host == null:
		return
	var landmarks: Dictionary = {}
	_index_landmarks(host, landmarks)
	var zone_id := _SHOP.street_zone(host.scene_file_path)
	_collect_sides(host, landmarks, zone_id)


func _index_landmarks(node: Node, found: Dictionary) -> void:
	var node_name := String(node.name)
	if node is Node3D and node_name.begins_with("tb") and (node_name.contains("toon_landmark") or node_name.contains("animated_building")):
		var block := _block_in(node_name)
		if block >= 0 and not found.has(block):
			found[block] = node
	for child in node.get_children():
		_index_landmarks(child, found)


func _collect_sides(node: Node, landmarks: Dictionary, zone_id: int) -> void:
	if node is Node3D and _is_panel(node as Node3D):
		_try_side(node as Node3D, node as Node3D, landmarks, zone_id)
	elif node is Node3D and _is_bare_frame(node as Node3D) and not _has_panel_sibling(node as Node3D):
		# Cold streets leave an empty locator. The painted door is the cornice
		# slab beside it, and batching frees that slab, so the locator keeps
		# the spot.
		var slab := _slab_sibling(node as Node3D)
		if slab != null:
			_try_side(node as Node3D, slab, landmarks, zone_id)
	for child in node.get_children():
		_collect_sides(child, landmarks, zone_id)


func _try_side(anchor: Node3D, slab: Node3D, landmarks: Dictionary, zone_id: int) -> void:
	var block := _block_above(anchor)
	var landmark: Node3D = landmarks.get(block) as Node3D
	if block < 0 or landmark == null:
		return
	_add_side(anchor, slab, landmark, block, zone_id)


func _add_side(anchor: Node3D, slab: Node3D, landmark: Node3D, block: int, zone_id: int) -> void:
	var marker := Marker3D.new()
	marker.name = "DoorTag%d_%d" % [block, _doors.size()]
	add_child(marker)
	var spot := _center(slab)
	var out := _normal(slab, spot, landmark)
	var into_anchor := anchor.global_transform.affine_inverse()
	var local_spot: Vector3 = into_anchor * spot
	var local_out: Vector3 = into_anchor.basis * out
	var point := spot + out * _FRONT
	_doors.append({
		"building": landmark,
		"door": anchor,
		"zone": zone_id,
		"block": block,
		"point": point,
		"out": out,
		"local_spot": local_spot,
		"local_out": local_out,
		"near": false,
		"playing": false,
		"clock": 0.0,
		"step": 0,
		"marker": marker,
		"tagged": false,
		"line": "",
		"sound": null,
		"events": [],
		"setup": "",
		"punch": "",
		"raise": 0.0,
		"cool_until": 0,
	})


func _bare(node_name: String) -> String:
	var bare := node_name
	var at := bare.find("@")
	if at > 0:
		bare = bare.substr(0, at)
	while bare.length() > 0 and bare.substr(bare.length() - 1, 1).is_valid_int():
		bare = bare.substr(0, bare.length() - 1)
	return bare


func _is_side_name(node_name: String) -> bool:
	return node_name.begins_with("door_single_") or node_name.begins_with("door_garage_")


func _is_panel(door: Node3D) -> bool:
	var bare := _bare(String(door.name))
	if not _is_side_name(bare) or not bare.ends_with("_door"):
		return false
	return door is MeshInstance3D and (door as MeshInstance3D).mesh != null


func _is_bare_frame(door: Node3D) -> bool:
	var bare := _bare(String(door.name))
	if not _is_side_name(bare):
		return false
	return not bare.ends_with("_door") and not bare.ends_with("_flat")


func _has_panel_sibling(frame: Node3D) -> bool:
	var parent := frame.get_parent()
	if parent == null:
		return false
	var stem := _bare(String(frame.name))
	for child in parent.get_children():
		var bare := _bare(String(child.name))
		if bare == stem + "_door":
			return true
	return false


## A door panel is a flat slab about five to eight feet across. Windows on the
## same wall are smaller, and the no-door cornice is named *_nd.
func _door_sized(size: Vector3) -> bool:
	var thin := minf(size.x, minf(size.y, size.z))
	var across := maxf(size.x, maxf(size.y, size.z))
	var mid := size.x + size.y + size.z - thin - across
	return thin < 0.4 and mid >= 5.0 and across >= 5.0 and across < 12.0


func _slab_sibling(frame: Node3D) -> MeshInstance3D:
	var parent := frame.get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null or mesh.mesh == null or mesh == frame:
			continue
		var bare := _bare(String(mesh.name))
		if bare.begins_with("window") or bare.ends_with("_nd"):
			continue
		if not bare.ends_with("_d"):
			continue
		if _local_door_center(mesh) == null:
			continue
		return mesh
	return null


func _center(node: Node3D) -> Vector3:
	var mesh := node as MeshInstance3D
	if mesh != null and mesh.mesh != null:
		var local: Variant = _local_door_center(mesh)
		if local is Vector3:
			return mesh.global_transform * (local as Vector3)
	return node.global_position


## The swinging panel is its own mesh. On the other walls the same slab is the
## bottom surface of the cornice card, with the trim on the surface above it.
func _local_door_center(mesh_instance: MeshInstance3D) -> Variant:
	var points := _vertices(mesh_instance.mesh)
	if points.is_empty():
		return null
	var full := _bounds(points)
	if _door_sized(full.size):
		return full.get_center()
	var up := _up_axis(full.size)
	var floor := full.position[up]
	var low := PackedVector3Array()
	for point in points:
		if point[up] <= floor + 8.5:
			low.append(point)
	if low.size() < 3:
		return null
	var door_box := _bounds(low)
	if not _door_sized(door_box.size):
		return null
	return door_box.get_center()


func _vertices(mesh: Mesh) -> PackedVector3Array:
	var points := PackedVector3Array()
	if mesh == null:
		return points
	for surface in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var verts: Variant = arrays[Mesh.ARRAY_VERTEX]
		if verts is PackedVector3Array:
			points.append_array(verts)
	return points


func _bounds(points: PackedVector3Array) -> AABB:
	var box := AABB(points[0], Vector3.ZERO)
	for point in points:
		box = box.expand(point)
	return box


func _up_axis(size: Vector3) -> int:
	if size.y <= size.x and size.y <= size.z:
		return 2 if size.z >= size.x else 0
	if size.x <= size.y and size.x <= size.z:
		return 2 if size.z >= size.y else 1
	return 0 if size.x >= size.y else 1


func _normal(node: Node3D, spot: Vector3, landmark: Node3D) -> Vector3:
	var local := Vector3.UP
	var mesh := node as MeshInstance3D
	if mesh != null and mesh.mesh != null:
		var size := mesh.get_aabb().size
		if size.x <= size.y and size.x <= size.z:
			local = Vector3.RIGHT
		elif size.z <= size.x and size.z <= size.y:
			local = Vector3.BACK
	var axis: Vector3 = node.global_transform.basis * local
	axis.y = 0.0
	if axis.length_squared() < 0.0001:
		axis = Vector3(0.0, 0.0, 1.0)
	else:
		axis = axis.normalized()
	var away := spot - _behind(node, landmark)
	away.y = 0.0
	if away.length_squared() > 1.0 and axis.dot(away) < 0.0:
		axis = -axis
	return axis


func _behind(node: Node3D, landmark: Node3D) -> Vector3:
	var wall := node.get_parent() as Node3D
	if wall is MeshInstance3D and (wall as MeshInstance3D).mesh != null:
		var box: AABB = wall.global_transform * (wall as MeshInstance3D).get_aabb()
		return box.get_center()
	return landmark.global_position


func _block_in(node_name: String) -> int:
	if not node_name.begins_with("tb"):
		return -1
	var digits := ""
	var index := 2
	while index < node_name.length() and node_name.substr(index, 1).is_valid_int():
		digits += node_name.substr(index, 1)
		index += 1
	if digits.is_empty():
		return -1
	if index < node_name.length() and node_name.substr(index, 1) != "_":
		return -1
	return int(digits)


func _block_above(node: Node) -> int:
	var current := node
	while current != null:
		var block := _block_in(String(current.name))
		if block >= 0:
			return block
		current = current.get_parent()
	return -1


func _process(delta: float) -> void:
	if _doors.is_empty():
		return
	var toon := _toon()
	if toon == null:
		return
	var where: Vector3 = toon.call("battle_point")
	var busy: bool = bool(toon.call("battle_busy"))
	var talking := false
	for door in _doors:
		if _visit(door, toon, where, busy, talking, delta):
			talking = true


func _visit(door: Dictionary, toon: Node, where: Vector3, busy: bool, other: bool, delta: float) -> bool:
	if _asleep(door):
		if bool(door["playing"]) or bool(door["tagged"]):
			_stop(door, toon)
		door["near"] = false
		return false
	_refresh(door)
	var point: Vector3 = door["point"]
	var near := _close(where, point)
	if bool(door["playing"]):
		_follow(door)
		if not near:
			_stop(door, toon)
			door["near"] = false
			return false
		_advance(door, delta, toon)
		door["near"] = true
		return bool(door["playing"])
	# Leaving and coming back tells the joke again. The heal is the only
	# part that waits.
	if near and not bool(door["near"]) and not other and not busy:
		if _begin(door, toon):
			door["near"] = true
			return true
		return false
	door["near"] = near
	return false


func _begin(door: Dictionary, toon: Node) -> bool:
	var board := _board(toon)
	if board == null:
		return false
	var joke := joke_for(int(door["zone"]), int(door["block"]))
	door["setup"] = String(joke[0])
	door["punch"] = String(joke[1])
	door["line"] = ""
	door["playing"] = true
	door["clock"] = 0.0
	door["step"] = 0
	door["raise"] = _DOOR_RAISE
	door["events"] = _beats()
	_follow(door)
	if not bool(door["tagged"]):
		board.add(door["marker"], "Door", "npc", _DOOR_INK)
		door["tagged"] = true
	if not _cooling(door):
		door["cool_until"] = Time.get_ticks_msec() + _COOLDOWN_MS
		_heal(toon, int(door["zone"]))
	_advance(door, 0.0, toon)
	return true


func _cooling(door: Dictionary) -> bool:
	return Time.get_ticks_msec() < int(door.get("cool_until", 0))


func _heal(toon: Node, zone_id: int) -> void:
	if toon == null or not toon.has_method("heal"):
		return
	var hood := zone_id - zone_id % 1000
	var amount := _TREASURES.heal_for_hood(hood)
	if amount <= 0:
		return
	toon.call("heal", amount)


func _beats() -> Array:
	var events: Array = [
		{"t": 0.0, "id": "knock_line"},
		{"t": 0.5, "id": "knock_sfx"},
		{"t": 1.0, "id": "who"},
		{"t": 2.0, "id": "setup"},
		{"t": 3.0, "id": "who2"},
		{"t": 4.0, "id": "punch"},
		{"t": _cleanup, "id": "clear"},
		{"t": 9.0, "id": "done"},
	]
	return events


func _advance(door: Dictionary, delta: float, toon: Node) -> void:
	var clock: float = float(door["clock"]) + delta
	door["clock"] = clock
	var events: Array = door["events"]
	var step: int = int(door["step"])
	while step < events.size():
		var event: Dictionary = events[step]
		if clock < float(event["t"]):
			break
		_play(door, String(event["id"]), toon)
		step += 1
		if not bool(door["playing"]):
			break
	door["step"] = step


func _play(door: Dictionary, id: String, toon: Node) -> void:
	match id:
		"knock_line":
			_show_door(door, "Knock, knock.", _gap(door, "knock_line", "setup"))
		"knock_sfx":
			_cue(door, _KNOCK, 0.0)
		"who":
			_show_toon(door, toon, "Who's there?", _gap(door, "who", "who2"))
		"setup":
			_show_door(door, String(door["setup"]), _gap(door, "setup", "punch"))
		"who2":
			_show_toon(door, toon, String(door["setup"]) + " who?", _gap(door, "who2", "clear"))
		"punch":
			_show_door(door, String(door["punch"]), _gap(door, "punch", "clear"))
			_cue(door, _RIM, 2.0)
		"clear":
			_clear_chatter(door, toon)
			_silence(door)
		"done":
			door["playing"] = false


func _gap(door: Dictionary, start_id: String, end_id: String) -> float:
	return maxf(_when(door, end_id) - _when(door, start_id), 0.5)


func _when(door: Dictionary, id: String) -> float:
	var events: Array = door["events"]
	for event in events:
		var row: Dictionary = event
		if String(row["id"]) == id:
			return float(row["t"])
	return float(door["clock"]) + 2.0


func _show_door(door: Dictionary, text: String, seconds: float) -> void:
	# Door lines land on the NPCs channel so SpeedChat++ keeps them.
	_log_chat("log_npc_line", text)
	var marker := _live(door, "marker")
	if marker == null:
		return
	marker.set_meta("chat_line", text)
	marker.set_meta("chat_until", Time.get_ticks_msec() + int(seconds * 1000.0))


func _show_toon(door: Dictionary, toon: Node, text: String, seconds: float) -> void:
	if toon == null:
		return
	door["line"] = text
	# The toon's replies ("Who's there?", "X who?") stay on the Players channel.
	_log_chat("log_player_line", text)
	toon.call("say_line", text, seconds)


func _speed_chat() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	# SpeedChat is created in code under the Hud canvas, so it is not a direct
	# child of the street and it has no owner. owned=false is what finds it.
	var scene := tree.current_scene
	if scene != null:
		var chat := scene.find_child("SpeedChat", true, false)
		if chat != null:
			return chat
	return tree.root.find_child("SpeedChat", true, false)


func _log_chat(method: String, text: String) -> void:
	var chat := _speed_chat()
	if chat != null and chat.has_method(method):
		if method == "log_npc_line":
			chat.call(method, "Door", text, _DOOR_INK)
		else:
			chat.call(method, text)


func _stop(door: Dictionary, toon: Node) -> void:
	door["playing"] = false
	_clear_chatter(door, toon)
	_silence(door)


func _clear_chatter(door: Dictionary, toon: Node) -> void:
	var spoken := String(door.get("line", ""))
	door["line"] = ""
	if toon != null and spoken != "":
		toon.call("quiet_line", spoken)
	var marker := _live(door, "marker")
	if marker != null:
		marker.set_meta("chat_line", "")
		marker.set_meta("chat_until", 0)
	_drop_tag(door, toon)


func _drop_tag(door: Dictionary, toon: Node) -> void:
	if not bool(door.get("tagged", false)):
		return
	door["tagged"] = false
	if toon == null:
		return
	var board := _board(toon)
	var marker := _live(door, "marker")
	if board != null and marker != null:
		board.release(marker)


func _follow(door: Dictionary) -> void:
	var marker := _live(door, "marker")
	var side := _live(door, "door")
	if marker == null or side == null:
		return
	_refresh(door)
	var point: Vector3 = door["point"]
	marker.global_position = point - (door["out"] as Vector3) * _FRONT + Vector3.UP * float(door["raise"])


func _refresh(door: Dictionary) -> void:
	var side := _live(door, "door")
	if side == null:
		return
	var local_spot: Vector3 = door["local_spot"]
	var local_out: Vector3 = door["local_out"]
	var spot: Vector3 = side.global_transform * local_spot
	var out: Vector3 = side.global_transform.basis * local_out
	out.y = 0.0
	if out.length_squared() < 0.0001:
		out = Vector3(0.0, 0.0, 1.0)
	else:
		out = out.normalized()
	door["point"] = spot + out * _FRONT
	door["out"] = out


func _live(door: Dictionary, key: String) -> Node3D:
	var raw: Variant = door.get(key)
	if typeof(raw) != TYPE_OBJECT or not is_instance_valid(raw):
		return null
	return raw as Node3D


func _asleep(door: Dictionary) -> bool:
	var side := _live(door, "door")
	if side == null or not side.is_visible_in_tree():
		return true
	var landmark := _live(door, "building")
	if landmark == null:
		return true
	return landmark.has_meta("cog_building") or landmark.has_meta("suit_approaching")


func _cue(door: Dictionary, path: String, from: float) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	_silence(door)
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var start := from
	var length := stream.get_length()
	if length > 0.0 and start >= length:
		start = 0.0
	var player := ToonAudio.effect_player()
	player.stream = stream
	player.finished.connect(player.queue_free)
	add_child(player)
	door["sound"] = player
	player.play(start)


func _silence(door: Dictionary) -> void:
	var raw: Variant = door.get("sound")
	door["sound"] = null
	# The clip frees its player when it ends. `is` on that freed player is the stack trace.
	if typeof(raw) != TYPE_OBJECT or not is_instance_valid(raw):
		return
	var player := raw as AudioStreamPlayer
	if player == null:
		return
	player.stop()
	player.queue_free()


func _rim_remain() -> float:
	if not ResourceLoader.exists(_RIM):
		return 0.0
	var stream := load(_RIM) as AudioStream
	if stream == null:
		return 0.0
	return maxf(stream.get_length() - 2.0, 0.0)


func _toon() -> Node:
	var host := get_parent()
	if host == null:
		return null
	for child in host.get_children():
		if child.has_method("say_line") and child.has_method("battle_point"):
			return child
	return null


func _board(toon: Node) -> Nametags:
	return toon.get_node_or_null("Nametags") as Nametags


func _close(where: Vector3, point: Vector3) -> bool:
	if absf(where.y - point.y) > _TALL:
		return false
	return Vector2(where.x, where.z).distance_to(Vector2(point.x, point.z)) <= _REACH
