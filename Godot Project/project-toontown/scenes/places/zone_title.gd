extends Control

## Hood.spawnTitleText. The sign font draws both cases as the same capitals.
## A playground branch's second line is "Playground". Streets and Cog HQ areas
## use TTLocalizer.GlobalStreetNames. Shop doors never load a new outdoor scene,
## so they do not get a title. Cog HQ lobbies and side areas do.

const _LINKS := preload("res://scenes/places/tunnel_links.gd")
const _PLACES := preload("res://scenes/places/hood_places.gd")
const _GUI := preload("res://scenes/toons/toon_gui.gd")

const _HOLD := 6.1
const _FADE := 0.5
const _SCALE := 0.16

const _ZONE: Dictionary = {
	"res://scenes/playgrounds/donalds_dock.tscn": 1000,
	"res://scenes/streets/barnacle_boulevard.tscn": 1100,
	"res://scenes/streets/seaweed_street.tscn": 1200,
	"res://scenes/streets/lighthouse_lane.tscn": 1300,
	"res://scenes/playgrounds/toontown_central.tscn": 2000,
	"res://scenes/streets/silly_street.tscn": 2100,
	"res://scenes/streets/loopy_lane.tscn": 2200,
	"res://scenes/streets/punchline_place.tscn": 2300,
	"res://scenes/playgrounds/the_burrrgh.tscn": 3000,
	"res://scenes/streets/walrus_way.tscn": 3100,
	"res://scenes/streets/sleet_street.tscn": 3200,
	"res://scenes/streets/polar_place.tscn": 3300,
	"res://scenes/playgrounds/minnies_melodyland.tscn": 4000,
	"res://scenes/streets/alto_avenue.tscn": 4100,
	"res://scenes/streets/baritone_boulevard.tscn": 4200,
	"res://scenes/streets/tenor_terrace.tscn": 4300,
	"res://scenes/playgrounds/daisy_gardens.tscn": 5000,
	"res://scenes/streets/elm_street.tscn": 5100,
	"res://scenes/streets/maple_street.tscn": 5200,
	"res://scenes/streets/oak_street.tscn": 5300,
	"res://scenes/playgrounds/acorn_acres.tscn": 6000,
	"res://scenes/playgrounds/goofy_speedway.tscn": 8000,
	"res://scenes/playgrounds/donalds_dreamland.tscn": 9000,
	"res://scenes/streets/lullaby_lane.tscn": 9100,
	"res://scenes/streets/pajama_place.tscn": 9200,
	"res://scenes/cog_hq/bossbot_country_club.tscn": 10000,
	"res://scenes/cog_hq/bossbot_lobby.tscn": 10100,
	"res://scenes/cog_hq/sellbot_courtyard.tscn": 11000,
	"res://scenes/cog_hq/sellbot_lobby.tscn": 11100,
	"res://scenes/cog_hq/sellbot_factory_exterior.tscn": 11200,
	"res://scenes/cog_hq/sellbot_front_factory.tscn": 11200,
	"res://scenes/cog_hq/sellbot_side_factory.tscn": 11500,
	"res://scenes/cog_hq/cashbot_trainyard.tscn": 12000,
	"res://scenes/cog_hq/cashbot_lobby.tscn": 12100,
	"res://scenes/cog_hq/lawbot_courtyard.tscn": 13000,
	"res://scenes/cog_hq/lawbot_lobby.tscn": 13100,
	"res://scenes/cog_hq/lawbot_da_lobby.tscn": 13200,
	"res://scenes/playgrounds/toon_estate.tscn": 16000,
	"res://scenes/playgrounds/chip_n_dales_minigolf.tscn": 17000,
}

const _HOOD: Dictionary = {
	1000: "Donald's Dock",
	2000: "Toontown Central",
	3000: "The Brrrgh",
	4000: "Minnie's Melodyland",
	5000: "Daisy Gardens",
	6000: "Chip 'n Dale's Acorn Acres",
	8000: "Goofy Speedway",
	9000: "Donald's Dreamland",
	10000: "Bossbot HQ",
	11000: "Sellbot HQ",
	12000: "Cashbot HQ",
	13000: "Lawbot HQ",
	16000: "your house",
	17000: "Chip 'n Dale's MiniGolf",
}

const _PLACE: Dictionary = {
	1000: "Playground",
	1100: "Barnacle Boulevard",
	1200: "Seaweed Street",
	1300: "Lighthouse Lane",
	2000: "Playground",
	2100: "Silly Street",
	2200: "Loopy Lane",
	2300: "Punchline Place",
	3000: "Playground",
	3100: "Walrus Way",
	3200: "Sleet Street",
	3300: "Polar Place",
	4000: "Playground",
	4100: "Alto Avenue",
	4200: "Baritone Boulevard",
	4300: "Tenor Terrace",
	5000: "Playground",
	5100: "Elm Street",
	5200: "Maple Street",
	5300: "Oak Street",
	9000: "Playground",
	9100: "Lullaby Lane",
	9200: "Pajama Place",
	10000: "Bossbot HQ Country Club",
	10100: "Bossbot HQ Lobby",
	11000: "Sellbot HQ Courtyard",
	11100: "Sellbot HQ Lobby",
	11200: "Sellbot Factory",
	11500: "Sellbot Factory",
	12000: "Cashbot Train Yard",
	12100: "Cashbot HQ Lobby",
	13000: "Lawbot HQ Courtyard",
	13100: "Courthouse Lobby",
	13200: "DA's Office Lobby",
}

const _PLACE_BY_SCENE: Dictionary = {
	"res://scenes/cog_hq/sellbot_front_factory.tscn": "Front Entrance",
	"res://scenes/cog_hq/sellbot_side_factory.tscn": "Side Entrance",
	"res://scenes/interiors/gag_shop.tscn": "Gag Shop",
	"res://scenes/interiors/toon_hall.tscn": "Toon Hall",
}

var _label: Label
var _tint := Color(1.0, 0.5, 0.4)


static func caption(scene_path: String) -> Dictionary:
	var zone := _zone(scene_path)
	if zone == 0:
		return {}
	var hood := _LINKS.hood_of(zone)
	if not _HOOD.has(hood):
		return {}
	var text := String(_HOOD[hood])
	var place := ""
	if _PLACE_BY_SCENE.has(scene_path):
		place = String(_PLACE_BY_SCENE[scene_path])
	elif _PLACE.has(zone):
		place = String(_PLACE[zone])
	if not place.is_empty():
		text += "\n" + place
	return {"text": text, "color": _tint_for(hood)}


static func _zone(scene_path: String) -> int:
	if _ZONE.has(scene_path):
		return int(_ZONE[scene_path])
	var linked := _LINKS.zone_for_scene(scene_path)
	if linked != 0:
		return linked
	return _PLACES.hood_for_scene(scene_path)


static func _tint_for(hood: int) -> Color:
	match hood:
		1000:
			return Color(0.8, 0.6, 0.5)
		3000:
			return Color(0.3, 0.6, 1.0)
		4000:
			return Color(1.0, 0.5, 0.5)
		5000:
			return Color(0.8, 0.6, 1.0)
		9000:
			return Color(1.0, 0.9, 0.5)
		10000, 11000, 12000, 13000:
			return Color(0.5, 0.5, 0.5)
		_:
			return Color(1.0, 0.5, 0.4)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = -1


func open(text: String, tint: Color) -> void:
	_tint = tint
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.text = text
	add_child(_label)
	_layout()
	if not get_viewport().size_changed.is_connected(_layout):
		get_viewport().size_changed.connect(_layout)
	var tween := create_tween()
	tween.tween_interval(_HOLD)
	tween.tween_property(self, "modulate:a", 0.0, _FADE)
	tween.finished.connect(queue_free)


func _layout() -> void:
	if _label == null:
		return
	var view := get_viewport().get_visible_rect().size
	var unit := view.y * 0.5
	var px := maxi(int(round(_SCALE * unit)), 8)
	_GUI.style_title(_label, _tint, px)
	_label.add_theme_constant_override("line_spacing", int(round(float(px) * -0.12)))
	var box := Vector2(view.x, float(px) * 2.6)
	var center := Vector2(view.x * 0.5, view.y * 0.5 - (-0.5) * unit)
	_label.position = center - box * 0.5
	_label.size = box
