extends Node3D

## The estate's garden plots from GardenGlobals.estatePlots. Flowers, gag
## trees, and a statue each use the plot type the original hard point allows.

const _GARDEN := preload("res://scenes/estate/garden.gd")
const _GUI := preload("res://scenes/toons/toon_gui.gd")
const _GARDEN_DIR := "res://assets/estate/garden/"
const _GAGS: PackedStringArray = ["Toon-Up", "Trap", "Lure", "Sound", "Throw", "Squirt", "Drop"]
const _BEAN_LETTERS := "RGOVBPYCS"
const _BEAN_COLORS: Array[Color] = [
	Color(1, 0, 0), Color(0, 1, 0), Color(1, 0.647, 0), Color(0.58, 0, 0.827),
	Color(0, 0, 1), Color(1, 0.753, 0.796), Color(1, 1, 0), Color(0, 1, 1), Color(0.753, 0.753, 0.753),
]
const _FLOWER_TINT := {
	"red": Color(0.804, 0.2, 0.2),
	"orange": Color(0.922, 0.463, 0.0),
	"violet": Color(0.5, 0.2, 1.0),
	"blue": Color(0.4, 0.4, 1.0),
	"pink": Color(0.953, 0.545, 0.757),
	"yellow": Color(0.992, 0.843, 0.392),
	"white": Color(1, 1, 1),
	"green": Color(0.5, 0.8, 0.5),
}
const _FLOWER_MODEL := {
	49: "daisy.glb", 50: "tulip.glb", 51: "carnation.glb", 52: "lily.glb",
	53: "narcissi.glb", 54: "pansy.glb", 55: "petunia.glb", 56: "rose.glb",
}

var estate_index := 0
var _estate := 0
var _busy := false
var _near := false
var _recipe := ""
var _layer: CanvasLayer
var _text: Label
var _buttons: VBoxContainer
var _packed: Dictionary = {}
var _seen: PackedStringArray = []


static func place(host: Node, estate: int) -> void:
	if host.get_node_or_null("GardenPlots") != null:
		return
	var yard: Node = load("res://scenes/estate/garden_plots.gd").new()
	yard.name = "GardenPlots"
	yard.set("estate_index", estate)
	host.add_child(yard)


func _ready() -> void:
	_estate = clampi(estate_index, 0, 5)
	var layout: Array = _GARDEN.layout(_estate)
	for index in layout.size():
		var spot: Dictionary = layout[index]
		var marker := Node3D.new()
		marker.name = "Plot%d" % index
		var at := _ground(Vector3(float(spot.get("x", 0.0)), 4.0, -float(spot.get("y", 0.0))))
		marker.position = at
		marker.rotation.y = deg_to_rad(-float(spot.get("h", 0.0)))
		marker.set_meta("kind", int(spot.get("kind", 1)))
		add_child(marker)
		_seen.append("")
	_dress_all()
	_layer = CanvasLayer.new()
	_layer.layer = 24
	_layer.visible = false
	add_child(_layer)
	var panel := ColorRect.new()
	panel.color = Color(0.15, 0.35, 0.15, 0.94)
	panel.position = Vector2(280, 80)
	panel.size = Vector2(760, 520)
	_layer.add_child(panel)
	_text = Label.new()
	_text.position = Vector2(16, 12)
	_text.size = Vector2(728, 120)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_GUI.style_label(_text, Color.WHITE, 20, Color.BLACK, 3)
	panel.add_child(_text)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(16, 140)
	scroll.size = Vector2(728, 360)
	panel.add_child(scroll)
	_buttons = VBoxContainer.new()
	_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_buttons)


func _process(_delta: float) -> void:
	_refresh()
	if _busy:
		return
	var body := _body()
	if body == null:
		return
	var plot := _closest(body.global_position)
	if plot < 0:
		_near = false
		return
	if _near:
		return
	_near = true
	_open(plot)


func _open(plot: int) -> void:
	_busy = true
	_hold(true)
	_show(plot)


func _show(plot: int) -> void:
	_clear_buttons()
	var layout: Array = _GARDEN.layout(_estate)
	var kind := int((layout[plot] as Dictionary).get("kind", 1))
	var plant: Dictionary = _GARDEN.plots(_estate)[plot]
	_text.text = "%s\n%s\n%s, skill %d/%d. %s, skill %d/%d." % [
		_kind_name(kind), _GARDEN.describe(plant),
		_GARDEN.shovel_name(), _GARDEN.shovel_skill(), _need_shovel(),
		_GARDEN.can_name(), _GARDEN.can_skill(), _need_can(),
	]
	_layer.visible = true
	if plant.is_empty() and kind == 1:
		_recipe = ""
		_text.text = "Choose the jellybeans you want to plant.\n%s, skill %d/%d." % [
			_GARDEN.shovel_name(), _GARDEN.shovel_skill(), _need_shovel(),
		]
		_bean_buttons(plot)
		return
	elif plant.is_empty() and kind == 0:
		for track in _GAGS.size():
			if _GARDEN.shovel_power() < 1:
				break
			_add("Plant %s level 1" % _GAGS[track], _plant_tree.bind(plot, track, 0))
			if _GARDEN.shovel_power() >= 3:
				_add("Plant %s level 3" % _GAGS[track], _plant_tree.bind(plot, track, 2))
	elif plant.is_empty():
		_add("Place a garden statue (125 jellybeans)", _statue.bind(plot))
	else:
		if not bool(plant.get("wilted", false)):
			_add("Water", _water.bind(plot))
		if int(plant.get("stage", 0)) >= 3 or bool(plant.get("wilted", false)):
			_add("Pick", _pick.bind(plot))
		_add("Bean game", _bean_game.bind(plot))
	_add("Close", _close)


func _bean_buttons(plot: int) -> void:
	_clear_buttons()
	var slots := mini(_GARDEN.shovel_power(), 8)
	var line := Label.new()
	line.text = "Recipe: %s  (%d boxes)" % [_recipe if not _recipe.is_empty() else "...", slots]
	line.custom_minimum_size = Vector2(700, 32)
	_GUI.style_label(line, Color.WHITE, 20, Color.BLACK, 3)
	_buttons.add_child(line)
	for index in _BEAN_LETTERS.length():
		_add(_bean_word(index), _append_bean.bind(plot, _BEAN_LETTERS.substr(index, 1)))
	_add("Plant", _commit_beans.bind(plot))
	_add("Reset", _reset_beans.bind(plot))
	_add("Bean game", _bean_game.bind(plot))
	_add("Close", _close)


func _append_bean(plot: int, letter: String) -> void:
	if _recipe.length() >= mini(_GARDEN.shovel_power(), 8):
		return
	_recipe += letter
	_bean_buttons(plot)


func _reset_beans(plot: int) -> void:
	_recipe = ""
	_bean_buttons(plot)


func _commit_beans(plot: int) -> void:
	var result := _GARDEN.plant_recipe(_estate, plot, _recipe)
	_recipe = ""
	_dress(plot)
	if result.begins_with("You planted"):
		_text.text = result
		_close_soon()
		return
	_text.text = result + "\nChoose the jellybeans you want to plant."
	_bean_buttons(plot)


func _bean_game(plot: int) -> void:
	_layer.visible = false
	var game: Node = load("res://scenes/estate/garden_drop.gd").new()
	add_child(game)
	game.connect("finished", _bean_game_done.bind(plot))


func _bean_game_done(won: bool, plot: int) -> void:
	if won:
		var spots: Array = _GARDEN.plots(_estate)
		if plot >= 0 and plot < spots.size() and spots[plot] is Dictionary and not (spots[plot] as Dictionary).is_empty():
			_GARDEN.water(_estate, plot)
		_dress(plot)
	_layer.visible = true
	_show(plot)


func _bean_word(index: int) -> String:
	var words := ["Red", "Green", "Orange", "Violet", "Blue", "Pink", "Yellow", "Cyan", "Silver"]
	return words[index]


func _plant_flower(plot: int, species: int, variety: int, beans: String) -> void:
	_text.text = _GARDEN.plant_flower(_estate, plot, species, variety, beans)
	_dress(plot)
	_close_soon()


func _plant_tree(plot: int, track: int, level: int) -> void:
	_text.text = _GARDEN.plant_tree(_estate, plot, track, level)
	_dress(plot)
	_close_soon()


func _statue(plot: int) -> void:
	_text.text = _GARDEN.place_statue(_estate, plot)
	_dress(plot)
	_close_soon()


func _water(plot: int) -> void:
	_text.text = _GARDEN.water(_estate, plot)
	_dress(plot)
	_close_soon()


func _pick(plot: int) -> void:
	_text.text = _GARDEN.harvest(_estate, plot)
	_dress(plot)
	_close_soon()


func _close_soon() -> void:
	_clear_buttons()
	_add("Close", _close)


func _close() -> void:
	_layer.visible = false
	_hold(false)
	_busy = false


func _kind_name(kind: int) -> String:
	if kind == 0:
		return "Gag tree plot"
	if kind == 2:
		return "Statuary plot"
	return "Flower plot"


func _need_shovel() -> int:
	return [80, 160, 320, 640][mini(_GARDEN.shovel(), 3)]


func _need_can() -> int:
	return [100, 200, 400, 1000][mini(_GARDEN.can(), 3)]


func _add(caption: String, call: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(700, 36)
	button.pressed.connect(call)
	_buttons.add_child(button)


func _clear_buttons() -> void:
	for child in _buttons.get_children():
		child.queue_free()


func _refresh() -> void:
	var spots: Array = _GARDEN.plots(_estate)
	for index in mini(spots.size(), _seen.size()):
		var plant: Dictionary = spots[index] if spots[index] is Dictionary else {}
		if _signature(plant) != _seen[index]:
			_dress(index)


func _dress_all() -> void:
	var spots: Array = _GARDEN.plots(_estate)
	for index in mini(spots.size(), _seen.size()):
		_dress(index)


func _dress(index: int) -> void:
	var marker := get_node_or_null("Plot%d" % index) as Node3D
	if marker == null or index >= _seen.size():
		return
	for child in marker.get_children():
		child.free()
	var spots: Array = _GARDEN.plots(_estate)
	var plant: Dictionary = {}
	if index < spots.size() and spots[index] is Dictionary:
		plant = spots[index]
	var kind := int(marker.get_meta("kind", 1))
	if plant.is_empty():
		if kind == 2:
			_place(marker, "garden_slab.glb", 0.075)
		elif kind == 0:
			_place(marker, "dirt_mound.glb", 1.5)
		else:
			_place(marker, "dirt_mound.glb", 0.7)
		_seen[index] = _signature(plant)
		return
	var planted_kind := int(plant.get("kind", kind))
	var stage := int(plant.get("stage", 0))
	var wilted := bool(plant.get("wilted", false))
	var water := int(plant.get("water", 0))
	if planted_kind == 0:
		var which := "gag_tree_small"
		if stage >= 2:
			which = "gag_tree_large"
		elif stage == 1:
			which = "gag_tree_med"
		if wilted:
			which += "_wilt"
		var tree := _place(marker, "gag_tree_stages.glb", 1.0)
		_keep_named(tree, which)
		if wilted and tree != null:
			_tint_meshes(tree, Color(0.55, 0.4, 0.25), false)
		var mound_scale := 3.0
		if stage == 0:
			mound_scale = 1.5
		_place_mound(marker, water, mound_scale)
	elif planted_kind == 2:
		_place(marker, "garden_mickey_shovel.glb", 0.05)
	else:
		var file_name := "seedling.glb"
		if stage >= 1:
			file_name = String(_FLOWER_MODEL.get(int(plant.get("species", 49)), "daisy.glb"))
		var flower := _place(marker, file_name, 2.0)
		if flower != null:
			flower.rotation.y = PI
			_show_bloom(flower, not wilted)
			if stage >= 1:
				var tint: Color = _FLOWER_TINT.get(_GARDEN.flower_color(int(plant.get("species", 49)), int(plant.get("variety", 0))), Color(0.8, 0.2, 0.2))
				_tint_meshes(flower, tint, true)
		_place_mound(marker, water, 0.73)
	_seen[index] = _signature(plant)


func _signature(plant: Dictionary) -> String:
	if plant.is_empty():
		return "empty"
	return "%s|%s|%s|%s|%s|%s" % [
		plant.get("kind", 0), plant.get("species", 0), plant.get("stage", 0),
		plant.get("wilted", false), plant.get("water", 0), plant.get("variety", 0),
	]


func _place(parent: Node3D, file_name: String, model_scale: float) -> Node3D:
	var path := _GARDEN_DIR + file_name
	if not _packed.has(path):
		_packed[path] = load(path)
	var packed := _packed[path] as PackedScene
	if packed == null:
		return null
	var node := packed.instantiate()
	if not (node is Node3D):
		node.free()
		return null
	var body := node as Node3D
	body.scale = Vector3.ONE * model_scale
	parent.add_child(body)
	_hide_named(body, "collision")
	return body


func _place_mound(parent: Node3D, water: int, model_scale: float) -> void:
	var file_name := "sand_mound.glb" if water <= 0 else "dirt_mound.glb"
	var mound := _place(parent, file_name, model_scale)
	if mound != null and water > 0:
		var dark := clampf(1.0 - float(mini(water, 8)) * 0.07, 0.4, 1.0)
		_tint_meshes(mound, Color(dark, dark, dark), false)


func _keep_named(root: Node, wanted: String) -> void:
	if root == null:
		return
	var matches: Array[Node] = []
	_find_exact(root, wanted, matches)
	if matches.is_empty() and wanted.ends_with("_wilt"):
		_find_exact(root, wanted.trim_suffix("_wilt"), matches)
	if matches.is_empty():
		return
	_hide_other_trees(root, matches)


func _find_exact(node: Node, wanted: String, matches: Array[Node]) -> void:
	if String(node.name) == wanted:
		matches.append(node)
	for child in node.get_children():
		_find_exact(child, wanted, matches)


func _hide_other_trees(node: Node, keep: Array[Node]) -> void:
	for child in node.get_children():
		var title := String(child.name)
		if title.begins_with("gag_tree") and child not in keep:
			child.visible = false
		else:
			_hide_other_trees(child, keep)


func _show_bloom(node: Node, bloom: bool) -> void:
	var title := String(node.name)
	if "wilt" in title and "bloom" not in title:
		node.visible = not bloom
	elif "bloom" in title:
		node.visible = bloom
	for child in node.get_children():
		_show_bloom(child, bloom)


func _tint_meshes(node: Node, color: Color, desat_only: bool) -> void:
	var title := String(node.name)
	if node is MeshInstance3D and (not desat_only or "desat" in title):
		var mesh := node as MeshInstance3D
		var mat := StandardMaterial3D.new()
		var active := mesh.get_active_material(0)
		if active is StandardMaterial3D:
			mat.albedo_texture = (active as StandardMaterial3D).albedo_texture
		mat.albedo_color = color
		mesh.material_override = mat
	for child in node.get_children():
		_tint_meshes(child, color, desat_only)


func _hide_named(node: Node, piece: String) -> void:
	if piece in String(node.name):
		node.visible = false
	for child in node.get_children():
		_hide_named(child, piece)


func _closest(at: Vector3) -> int:
	var best := -1
	var best_d := 2.6
	for child in get_children():
		if not String(child.name).begins_with("Plot"):
			continue
		var marker := child as Node3D
		if marker == null:
			continue
		var flat := Vector2(at.x, at.z).distance_to(Vector2(marker.global_position.x, marker.global_position.z))
		if flat < best_d:
			best_d = flat
			best = int(String(marker.name).trim_prefix("Plot"))
	return best


func _ground(at: Vector3) -> Vector3:
	var space := get_world_3d()
	if space == null:
		return at
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 20.0, at + Vector3.DOWN * 40.0)
	var hit := space.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3(at.x, 0.2, at.z)
	return hit.position


func _body() -> Node3D:
	var host := get_parent()
	if host == null:
		return null
	return host.get_node_or_null("Player") as Node3D


func _hold(holding: bool) -> void:
	var host := get_parent()
	if host == null:
		return
	var toon := host.get_node_or_null("PlaygroundToon")
	if toon != null and toon.has_method("hold_for_race"):
		toon.call("hold_for_race", holding)
