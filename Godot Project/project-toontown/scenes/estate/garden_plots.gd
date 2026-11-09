extends Node3D

## The estate's garden plots from GardenGlobals.estatePlots. Flowers, gag
## trees, and a statue each use the plot type the original hard point allows.

const _GARDEN := preload("res://scenes/estate/garden.gd")
const _GUI := preload("res://scenes/toons/toon_gui.gd")
const _GAGS: PackedStringArray = ["Toon-Up", "Trap", "Lure", "Sound", "Throw", "Squirt", "Drop"]

var estate_index := 0
var _estate := 0
var _busy := false
var _near := false
var _layer: CanvasLayer
var _text: Label
var _buttons: VBoxContainer


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
		var marker := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.4, 0.25, 1.4)
		marker.mesh = mesh
		marker.name = "Plot%d" % index
		var at := _ground(Vector3(float(spot.get("x", 0.0)), 4.0, -float(spot.get("y", 0.0))))
		marker.position = at + Vector3(0.0, 0.15, 0.0)
		var material := StandardMaterial3D.new()
		var kind := int(spot.get("kind", 1))
		material.albedo_color = Color(0.45, 0.28, 0.12) if kind == 0 else Color(0.25, 0.55, 0.2) if kind == 1 else Color(0.6, 0.6, 0.65)
		marker.material_override = material
		add_child(marker)
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
		for choice in _GARDEN.flower_choices():
			if not (choice is Dictionary):
				continue
			var card: Dictionary = choice
			_add("%s (%s) %d beans" % [String(card.get("name", "Flower")), String(card.get("beans", "")), String(card.get("beans", "")).length()], _plant_flower.bind(plot, int(card.get("species", 0)), int(card.get("variety", 0)), String(card.get("beans", ""))))
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
	_add("Close", _close)


func _plant_flower(plot: int, species: int, variety: int, beans: String) -> void:
	_text.text = _GARDEN.plant_flower(_estate, plot, species, variety, beans)
	_close_soon()


func _plant_tree(plot: int, track: int, level: int) -> void:
	_text.text = _GARDEN.plant_tree(_estate, plot, track, level)
	_close_soon()


func _statue(plot: int) -> void:
	_text.text = _GARDEN.place_statue(_estate, plot)
	_close_soon()


func _water(plot: int) -> void:
	_text.text = _GARDEN.water(_estate, plot)
	_close_soon()


func _pick(plot: int) -> void:
	_text.text = _GARDEN.harvest(_estate, plot)
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


func _closest(at: Vector3) -> int:
	var best := -1
	var best_d := 2.6
	for child in get_children():
		if not (child is MeshInstance3D):
			continue
		var marker := child as Node3D
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
