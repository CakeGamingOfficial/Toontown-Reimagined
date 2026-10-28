class_name ToonStyle
extends RefCounted

## The slice of ToonDNA a Make a Toon shop edits. Head codes match the
## original species + muzzle + ear letters. Torso codes are size then
## shorts (s) or skirt (d).

const SPECIES: PackedStringArray = ["d", "c", "h", "m", "r", "f", "p", "b", "s"]
const SPECIES_NAME := {
	"d": "Dog",
	"c": "Cat",
	"h": "Horse",
	"m": "Mouse",
	"r": "Rabbit",
	"f": "Duck",
	"p": "Monkey",
	"b": "Bear",
	"s": "Pig",
}
const HEADS := {
	"d": ["dls", "dss", "dsl", "dll"],
	"c": ["cls", "css", "csl", "cll"],
	"h": ["hls", "hss", "hsl", "hll"],
	"m": ["mls", "mss"],
	"r": ["rls", "rss", "rsl", "rll"],
	"f": ["fls", "fss", "fsl", "fll"],
	"p": ["pls", "pss", "psl", "pll"],
	"b": ["bls", "bss", "bsl", "bll"],
	"s": ["sls", "sss", "ssl", "sll"],
}
const SIZES: PackedStringArray = ["s", "m", "l"]
const SIZE_NAME: PackedStringArray = ["Short", "Medium", "Tall"]
const SHIRTS: PackedStringArray = ["Solid", "Stripes", "Collared", "Pocket", "Bowtie", "Vest", "Jersey", "Flower"]
const SHORTS: PackedStringArray = ["Plain", "Cuffed", "Belted", "Side stripe"]
const SKIRTS: PackedStringArray = ["Plain", "Pleated", "Belted", "Flared"]

## allColorsList from ToonDNA. Index 0 is white, used for gloves.
const FUR: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(0.96875, 0.691406, 0.699219),
	Color(0.933594, 0.265625, 0.28125),
	Color(0.863281, 0.40625, 0.417969),
	Color(0.710938, 0.234375, 0.4375),
	Color(0.570312, 0.449219, 0.164062),
	Color(0.640625, 0.355469, 0.269531),
	Color(0.996094, 0.695312, 0.511719),
	Color(0.832031, 0.5, 0.296875),
	Color(0.992188, 0.480469, 0.167969),
	Color(0.996094, 0.898438, 0.320312),
	Color(0.996094, 0.957031, 0.597656),
	Color(0.855469, 0.933594, 0.492188),
	Color(0.550781, 0.824219, 0.324219),
	Color(0.242188, 0.742188, 0.515625),
	Color(0.304688, 0.96875, 0.402344),
	Color(0.433594, 0.90625, 0.835938),
	Color(0.347656, 0.820312, 0.953125),
	Color(0.191406, 0.5625, 0.773438),
	Color(0.558594, 0.589844, 0.875),
	Color(0.285156, 0.328125, 0.726562),
	Color(0.460938, 0.378906, 0.824219),
	Color(0.546875, 0.28125, 0.75),
	Color(0.726562, 0.472656, 0.859375),
	Color(0.898438, 0.617188, 0.90625),
	Color(0.7, 0.7, 0.8),
	Color(0.3, 0.3, 0.35),
]

## ClothesColors indices used by the Make a Toon wardrobe, through index 27.
const CLOTHES: Array[Color] = [
	Color(0.933594, 0.265625, 0.28125),
	Color(0.863281, 0.40625, 0.417969),
	Color(0.710938, 0.234375, 0.4375),
	Color(0.992188, 0.480469, 0.167969),
	Color(0.996094, 0.898438, 0.320312),
	Color(0.550781, 0.824219, 0.324219),
	Color(0.242188, 0.742188, 0.515625),
	Color(0.433594, 0.90625, 0.835938),
	Color(0.347656, 0.820312, 0.953125),
	Color(0.191406, 0.5625, 0.773438),
	Color(0.285156, 0.328125, 0.726562),
	Color(0.460938, 0.378906, 0.824219),
	Color(0.546875, 0.28125, 0.75),
	Color(0.570312, 0.449219, 0.164062),
	Color(0.640625, 0.355469, 0.269531),
	Color(0.996094, 0.695312, 0.511719),
	Color(0.832031, 0.5, 0.296875),
	Color(0.992188, 0.480469, 0.167969),
	Color(0.550781, 0.824219, 0.324219),
	Color(0.433594, 0.90625, 0.835938),
	Color(0.347656, 0.820312, 0.953125),
	Color(0.96875, 0.691406, 0.699219),
	Color(0.996094, 0.957031, 0.597656),
	Color(0.855469, 0.933594, 0.492188),
	Color(0.558594, 0.589844, 0.875),
	Color(0.726562, 0.472656, 0.859375),
	Color(0.898438, 0.617188, 0.90625),
	Color(1.0, 1.0, 1.0),
]

const BODY_SCALE := {
	"m": 0.6,
	"c": 0.73,
	"f": 0.66,
	"r": 0.74,
	"h": 0.85,
	"d": 0.85,
	"p": 0.68,
	"b": 0.85,
	"s": 0.77,
}

## Make a Toon shirts are desat 1 and 2. Each entry is shirt texture, color.
const BOY_TOPS: Array = [
	[0, 0], [0, 1], [0, 2], [0, 3], [0, 4], [0, 5], [0, 6], [0, 7], [0, 8], [0, 9], [0, 10], [0, 11], [0, 12], [0, 27],
	[1, 0], [1, 1], [1, 2], [1, 3], [1, 4], [1, 5], [1, 6], [1, 7], [1, 8], [1, 9], [1, 10], [1, 11], [1, 12],
]
const GIRL_TOPS: Array = BOY_TOPS
## Bottom texture index, color, and whether it is a skirt.
const BOY_BOTTOMS: Array = [
	[0, 0, false], [0, 1, false], [0, 2, false], [0, 4, false], [0, 6, false], [0, 9, false], [0, 10, false],
	[0, 11, false], [0, 12, false], [0, 13, false], [0, 14, false], [0, 15, false], [0, 16, false], [0, 17, false],
	[0, 18, false], [0, 19, false], [0, 20, false],
	[1, 0, false], [1, 1, false], [1, 2, false], [1, 4, false], [1, 6, false], [1, 9, false], [1, 10, false],
	[1, 11, false], [1, 12, false],
]
const GIRL_BOTTOMS: Array = [
	[0, 0, true], [0, 1, true], [0, 2, true], [0, 3, true], [0, 4, true], [0, 5, true], [0, 6, true], [0, 7, true],
	[0, 8, true], [0, 9, true], [0, 11, true], [0, 12, true], [0, 21, true], [0, 22, true], [0, 23, true],
	[0, 24, true], [0, 25, true], [0, 26, true], [0, 27, true],
	[5, 0, false], [5, 1, false], [5, 2, false], [5, 3, false], [5, 4, false], [5, 5, false], [5, 6, false],
	[5, 7, false], [5, 8, false], [5, 9, false], [5, 11, false], [5, 12, false],
]

var first_name := ""
var last_name := ""
var gender := "m"
var head := "dss"
var torso := "ms"
var legs := "m"
var head_color := 17
var arm_color := 17
var leg_color := 17
var glove_color := 0
var top_tex := 0
var top_color := 4
var bot_tex := 0
var bot_color := 8


func display_name() -> String:
	var full := (first_name + " " + last_name).strip_edges()
	if full.is_empty():
		return "Unnamed Toon"
	return full


func species() -> String:
	if head.is_empty():
		return "d"
	return head.substr(0, 1)


func species_name() -> String:
	return String(SPECIES_NAME.get(species(), "Toon"))


func head_label() -> String:
	if head.length() < 3:
		return "Head"
	var feature := "snout"
	if species() == "f":
		feature = "bill"
	var length_name := "Long" if head[1] == "l" else "Short"
	var ear_name := "long ears" if head[2] == "l" else "short ears"
	return "%s %s, %s" % [length_name, feature, ear_name]


func torso_size() -> int:
	if torso.is_empty():
		return 1
	return maxi(SIZES.find(torso.substr(0, 1)), 0)


func leg_size() -> int:
	return maxi(SIZES.find(legs), 0)


func wears_skirt() -> bool:
	return torso.length() > 1 and torso[1] == "d"


func bottom_label() -> String:
	var list := SKIRTS if wears_skirt() else SHORTS
	return list[clampi(bot_tex, 0, list.size() - 1)]


func shirt_label() -> String:
	return SHIRTS[clampi(top_tex, 0, SHIRTS.size() - 1)]


static func heads_for(species_code: String) -> Array:
	return HEADS.get(species_code, HEADS["d"])


static func fur_color(index: int) -> Color:
	return FUR[clampi(index, 0, FUR.size() - 1)]


static func clothes_color(index: int) -> Color:
	return CLOTHES[clampi(index, 0, CLOTHES.size() - 1)]


static func random_named(gender_code: String) -> ToonStyle:
	var style := random_body(gender_code)
	style.first_name = _FIRST[randi() % _FIRST.size()]
	style.last_name = _LAST[randi() % _LAST.size()]
	return style


func body_scale() -> float:
	return float(BODY_SCALE.get(species(), 0.8))


static func tops_for(gender_code: String) -> Array:
	return GIRL_TOPS if gender_code == "f" else BOY_TOPS


static func bottoms_for(gender_code: String) -> Array:
	return GIRL_BOTTOMS if gender_code == "f" else BOY_BOTTOMS


func cycle_top(step: int) -> void:
	var tops := tops_for(gender)
	var index := 0
	for item_index in tops.size():
		var item: Array = tops[item_index]
		if int(item[0]) == top_tex and int(item[1]) == top_color:
			index = item_index
			break
	index = posmod(index + step, tops.size())
	var chosen: Array = tops[index]
	top_tex = int(chosen[0])
	top_color = int(chosen[1])


func cycle_bottom(step: int) -> void:
	var bottoms := bottoms_for(gender)
	var index := 0
	for item_index in bottoms.size():
		var item: Array = bottoms[item_index]
		if int(item[0]) == bot_tex and int(item[1]) == bot_color:
			index = item_index
			break
	index = posmod(index + step, bottoms.size())
	var chosen: Array = bottoms[index]
	bot_tex = int(chosen[0])
	bot_color = int(chosen[1])
	var size := SIZES[torso_size()]
	torso = size + ("d" if bool(chosen[2]) else "s")


static func random_body(gender_code: String) -> ToonStyle:
	var style := ToonStyle.new()
	style.gender = gender_code
	var species_code: String = SPECIES[randi() % SPECIES.size()]
	var heads := heads_for(species_code)
	style.head = String(heads[randi() % heads.size()])
	var size := randi() % 3
	style.legs = SIZES[randi() % SIZES.size()]
	var color := 1 + randi() % 24
	style.head_color = color
	style.arm_color = color
	style.leg_color = color
	style.glove_color = 0
	var tops := tops_for(gender_code)
	var top: Array = tops[randi() % tops.size()]
	style.top_tex = int(top[0])
	style.top_color = int(top[1])
	var bottoms := bottoms_for(gender_code)
	var bottom: Array = bottoms[randi() % bottoms.size()]
	style.bot_tex = int(bottom[0])
	style.bot_color = int(bottom[1])
	style.torso = SIZES[size] + ("d" if bool(bottom[2]) else "s")
	return style


func to_dict() -> Dictionary:
	return {
		"first_name": first_name,
		"last_name": last_name,
		"gender": gender,
		"head": head,
		"torso": torso,
		"legs": legs,
		"head_color": head_color,
		"arm_color": arm_color,
		"leg_color": leg_color,
		"glove_color": glove_color,
		"top_tex": top_tex,
		"top_color": top_color,
		"bot_tex": bot_tex,
		"bot_color": bot_color,
	}


static func from_dict(data: Dictionary) -> ToonStyle:
	var style := ToonStyle.new()
	style.first_name = String(data.get("first_name", ""))
	style.last_name = String(data.get("last_name", ""))
	style.gender = String(data.get("gender", "m"))
	style.head = String(data.get("head", "dss"))
	style.torso = String(data.get("torso", "ms"))
	style.legs = String(data.get("legs", "m"))
	style.head_color = int(data.get("head_color", 17))
	style.arm_color = int(data.get("arm_color", 17))
	style.leg_color = int(data.get("leg_color", 17))
	style.glove_color = int(data.get("glove_color", 0))
	style.top_tex = int(data.get("top_tex", 0))
	style.top_color = int(data.get("top_color", 4))
	style.bot_tex = int(data.get("bot_tex", 0))
	style.bot_color = int(data.get("bot_color", 8))
	return style


const _FIRST: PackedStringArray = ["Loopy", "Bumpy", "Zany", "Wiggly", "Dizzy", "Peppy", "Snappy", "Bonnie", "Flip", "Scooter"]
const _LAST: PackedStringArray = ["McBounce", "Fizzle", "Wobble", "Snorkel", "Biscuit", "Jellyroll", "Giggles", "Toonington", "Puddlejump", "Feather"]
