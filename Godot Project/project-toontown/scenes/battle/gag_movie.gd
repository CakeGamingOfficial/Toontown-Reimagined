class_name GagMovie
extends Node

## MovieThrow, MovieSquirt, MovieDrop, MovieTrap, MovieLure, MovieSound, and
## MovieHeal for a street battle. Props follow the original intervals. The
## camera cuts are MovieCamera's open shot, then the close shot.

const _PROPS := "res://assets/battle/props/"
const _SFX := "res://assets/audio/battle/"
const _HEIGHT := 4.88
# Panda Z-up into Godot Y-up. Storm-cloud bolts are cards in local X/Z, so this stands them up.
const _Z_UP := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
# MovieUtil.SPRAY_LEN. The spray mesh runs along local +Y, and Panda's lookAt aims that axis.
const _SPRAY_LEN := 1.5
const _SPRAY_SCALE: Array[float] = [0.2, 0.3, 0.1, 0.6, 0.8, 1.0, 2.0]
# MovieUtil.SUIT_LOSE_DURATION. The lose-mod plays after the hit react.
const LOSE_SECONDS := 6.0
const _GAGS: Array = [
	["feather", "megaphone", "lipstick", "cane", "", "cubes", "ladder"],
	["banana", "rake", "marbles", "quicksand", "trapdoor", "tnt", "traintrack"],
	["fishing-pole", "magnet", "fishing-pole", "magnet", "fishing-pole", "hypno-goggles", "slideshow"],
	["bikehorn", "whistle", "bugle", "aoogah", "elephant", "fog_horn", "singing"],
	["tart", "fruitpie-slice", "creampie-slice", "fruitpie", "creampie", "birthday-cake", "wedding-cake"],
	["squirting-flower", "glass", "water-gun", "bottle", "firehose", "stormcloud", "geyser"],
	["flowerpot", "sandbag", "anvil", "weight", "safe", "piano", "ship"],
]
const _HEAL_SFX: PackedStringArray = [
	"AA_heal_tickle.ogg", "AA_heal_telljoke.ogg", "AA_heal_smooch.ogg", "AA_heal_happydance.ogg",
	"AA_heal_pixiedust.ogg", "AA_heal_juggle.ogg", "AA_heal_High_Dive.ogg",
]
const _TRAP_SFX: PackedStringArray = [
	"TL_banana.ogg", "TL_rake_throw_only.ogg", "TL_marbles.ogg", "TL_quicksand.ogg",
	"TL_trap_door.ogg", "TL_dynamite.ogg", "TL_train_track_appear.ogg",
]
const _SOUND_SFX: PackedStringArray = [
	"AA_sound_bikehorn.ogg", "AA_sound_whistle.ogg", "AA_sound_bugle.ogg", "AA_sound_aoogah.ogg",
	"AA_sound_elephant.ogg", "SZ_DD_foghorn.ogg", "AA_sound_Opera_Singer.ogg",
]
# MovieSound.appearSoundFiles. The bugle grows without a separate appear effect.
const _SOUND_APPEAR: PackedStringArray = [
	"MG_tag_1.ogg", "LB_receive_evidence.ogg", "", "TL_step_on_rake.ogg",
	"toonbldg_grow.ogg", "mailbox_full_wobble.ogg", "mailbox_full_wobble.ogg",
]
# INSTRUMENT_SCALE_MODIFIER is 0.5, applied to each instrument's resting size.
const _SOUND_SIZE: PackedFloat32Array = [0.325, 0.1, 0.2, 0.25, 0.15, 0.15, 1.1]
const _HEAL_DELAY: PackedFloat32Array = [1.0, 2.0, 2.0, 0.2, 2.0, 0.7, 0.6]
const _SQUIRT_HIT: PackedStringArray = [
	"AA_squirt_flowersquirt.ogg", "AA_squirt_glasswater.ogg", "AA_squirt_neonwatergun.ogg", "AA_squirt_seltzer.ogg",
	"firehose_spray.ogg", "AA_throw_stormcloud.ogg", "AA_squirt_Geyser.ogg",
]
const _SQUIRT_MISS: PackedStringArray = [
	"AA_squirt_flowersquirt_miss.ogg", "AA_squirt_glasswater_miss.ogg", "AA_squirt_neonwatergun_miss.ogg", "AA_squirt_seltzer_miss.ogg",
	"firehose_spray.ogg", "AA_throw_stormcloud_miss.ogg", "AA_squirt_Geyser.ogg",
]
const _DROP_HIT: PackedStringArray = [
	"AA_drop_flowerpot.ogg", "AA_drop_sandbag.ogg", "AA_drop_anvil.ogg", "AA_drop_bigweight.ogg",
	"AA_drop_safe.ogg", "AA_drop_piano.ogg", "AA_drop_boat.ogg",
]
const _DROP_MISS: PackedStringArray = [
	"AA_drop_flowerpot_miss.ogg", "AA_drop_sandbag_miss.ogg", "AA_drop_anvil_miss.ogg", "AA_drop_bigweight_miss.ogg",
	"AA_drop_safe_miss.ogg", "AA_drop_piano_miss.ogg", "AA_drop_boat_miss.ogg",
]
const _SQUIRT_CLIP: PackedStringArray = ["pushbutton", "spit", "water-gun", "hold-bottle", "firehose", "pushbutton", "pushbutton"]
const _HEAL_CLIP: PackedStringArray = ["tickle", "sound", "smooch", "happy-dance", "sprinkle-dust", "juggle", "climb"]
const _LURE_DOLLAR: PackedStringArray = ["1dollar", "", "5dollar", "", "10dollar", "", ""]

const _DROP_FALL: Array[float] = [0.5, 0.1667, 0.0417, 0.4583, 0.4583, 0.4583, 0.0833]
# MovieTrap distances, in front of the cog. Panda +Y is the cog's forward.
const _TRAP_REACH: Array[float] = [2.6, 4.5, 3.7, 2.6, 2.6, 5.1, 2.6]
const _ATTACK_HELD := {
	"Pound Key!": ["phone", "receiver"],
	"Hang Up!": ["phone", "receiver"],
	"Audit!": ["calculator"],
	"Calculate!": ["calculator"],
	"Tabulate!": ["calculator"],
	"Shred!": ["shredder", "shredder-paper"],
	"Fountain Pen!": ["pen"],
	"Rub Out!": ["pad", "pencil"],
	"Write Off!": ["pad", "pencil"],
	"Fill With Lead!": ["pencil", "sharpener"],
	"Rubber Stamp!": ["rubber-stamp", "pad"],
	"Razzle Dazzle!": ["smile"],
	"Tee Off!": ["golf-club"],
	"Rolodex!": ["rollodex"],
	"Evil Eye!": ["evil-eye"],
	"Watercooler!": ["watercooler"],
	"Cigar Smoke!": ["cigar"],
	"Glower Power!": ["dagger", "dagger"],
}
const _ATTACK_THROWN := {
	"Clip On Tie!": "clip-on-tie",
	"Canned!": "can",
	"Pink Slip!": "pink-slip",
	"Sacked!": "sandbag",
	"Half Windsor!": "half-windsor",
	"Play Hardball!": "baseball",
	"Power Tie!": "power-tie",
	"Pick Pocket!": "1dollar",
	"Red Tape!": "redtape",
	"Bounce Check!": "bounced-check",
	"Crunch!": "calculator",
	"Market Crash!": "newspaper",
	"Bite!": "teeth",
	"Chomp!": "teeth",
	"Eviction Notice!": "shredder-paper",
	"Restraining Order!": "shredder-paper",
	"Pecking Order!": "bird",
	"Throw Book!": "lawbook",
	"Tee Off!": "golf-ball",
}
const _HEAL_TIME: Array[float] = [3.2, 3.6, 3.4, 6.4, 4.6, 7.7, 9.0]
const _SHOTS: Dictionary = {
	"throw_close": {"rel": true, "x": 3.0, "y": 8.0, "z": 0.66, "chest": true},
	"three_right": {"rel": true, "x": 5.2, "y": 5.45, "z": 0.66, "chest": true},
	"three_left": {"rel": true, "x": -5.2, "y": 5.45, "z": 0.66, "chest": true},
	"three_wide": {"rel": true, "x": 7.2, "y": 8.45, "z": 0.66, "chest": true},
	"behind": {"rel": true, "x": 5.0, "y": -7.0, "z": 1.0, "chest": true},
	"behind_high_right": {"rel": true, "x": 4.0, "y": -7.0, "z": 5.0, "plus_height": true},
	"group_low": {"rel": false, "x": 15.0, "y": 0.0, "z": 3.0},
	"suit_behind": {"rel": false, "x": 12.37, "y": 11.5, "z": 8.16, "flip": true},
	"toon_group": {"rel": false, "x": 10.0, "y": 0.0, "z": 10.0},
}

var _spawned: Array[Node] = []
var _prop_sources: Dictionary = {}
var _traps: Dictionary = {}
var _sprung: Array = []
var _fired: Dictionary = {}
var _attach: Dictionary = {}
var _party: Array = []
var _make_owner := 0
var _chording := false
var _aiming := false
var _aim_time := 0.0
var _aim_open := 3.0
var _aim_open_name := "group_low"
var _aim_close_name := "group_low"
var _aim_open_on := "battle"
var _aim_close_on := "battle"
var _aim_flip := 1.0
var _aim_actor: ToonActor
var _aim_cog: Node3D


func _ready() -> void:
	var path := _PROPS + "attachments.json"
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		_attach = parsed


## The server holds the movie for this long. Playback uses the same numbers,
## so a client cannot finish after the round has already moved on.
static func seconds(kind: String, track: int, level: int, died: bool, attack := "") -> float:
	if kind == "run" or kind == "lured":
		return 1.3
	if kind == "cog":
		var length := maxf(_cog_length(attack, "a"), maxf(_cog_length(attack, "b"), _cog_length(attack, "c")))
		return length + (5.6 if died else 0.0)
	if kind != "gag":
		return 2.2
	if track == 4:
		return 4.8
	if track == 5:
		if level <= 0:
			return 4.6
		if level == 1:
			return 5.4
		if level == 2:
			return 4.2
		if level == 3:
			return 4.4
		if level == 4:
			return 6.2
		if level == 5:
			return 7.2
		return 5.2
	if track == 6:
		return 6.6
	if track == 1:
		return 5.2 if level <= 2 or level == 5 else 4.6
	if track == 2:
		if level == 1 or level == 3:
			return 7.2
		if level == 5:
			return 6.0
		if level == 6:
			return 4.8
		return 5.6
	if track == 3:
		return 8.0 if level >= 6 else 5.0
	if track == 0:
		return _HEAL_TIME[clampi(level, 0, _HEAL_TIME.size() - 1)]
	return 2.2


## Movie groups one track into a single interval. Heal stays a sequence. Trap and
## lure start together. Sound staggers a second per level. Throw and squirt
## stagger half a second on one cog and a second between cogs. Drop uses 0.8s.
static func joins_chorus(beat: Dictionary) -> bool:
	if String(beat.get("kind", "")) != "gag":
		return false
	var track := int(beat.get("track", -1))
	return track >= 1 and track <= 6


static func same_chorus(lead: Dictionary, nxt: Dictionary) -> bool:
	return joins_chorus(lead) and joins_chorus(nxt) and int(lead.get("track", -1)) == int(nxt.get("track", -2))


## One party is one toon's gag, including every cog a group gag hits.
static func split_parties(beats: Array) -> Array:
	var parties: Array = []
	var current: Array = []
	var toon := -999999
	for item in beats:
		if not (item is Dictionary):
			continue
		var beat: Dictionary = item
		var who := int(beat.get("toon", 0))
		if current.is_empty() or who == toon:
			current.append(beat)
			toon = who
		else:
			parties.append(current)
			current = [beat]
			toon = who
	if not current.is_empty():
		parties.append(current)
	return parties


## How long the overlapping track movie runs, before the lose track.
static func chorus_seconds(beats: Array) -> float:
	var parties := split_parties(beats)
	var delays := chorus_delays(parties)
	var span := 0.0
	for index in parties.size():
		var party: Array = parties[index]
		if party.is_empty():
			continue
		var row: Dictionary = party[0]
		span = maxf(span, float(delays[index]) + seconds("gag", int(row.get("track", 0)), int(row.get("level", 0)), false))
	return span


static func chorus_delays(parties: Array) -> PackedFloat32Array:
	var delays := PackedFloat32Array()
	delays.resize(parties.size())
	if parties.is_empty():
		return delays
	var first: Array = parties[0]
	if first.is_empty():
		return delays
	var lead: Dictionary = first[0]
	var track := int(lead.get("track", -1))
	# MovieTrap and MovieLure put every toon in one Parallel.
	if track == 1 or track == 2:
		return delays
	# MovieSound steps a second later for each higher level. The same level starts together.
	if track == 3:
		return _level_delays(parties, 1.0)
	if track == 4 or track == 5 or track == 6:
		return _aimed_delays(parties, track)
	return delays


static func _level_delays(parties: Array, gap: float) -> PackedFloat32Array:
	var delays := PackedFloat32Array()
	delays.resize(parties.size())
	var levels: Array[int] = []
	var rows: Array = []
	for party in parties:
		rows = party
		if rows.is_empty():
			continue
		var gag_level := int((rows[0] as Dictionary).get("level", 0))
		if not levels.has(gag_level):
			levels.append(gag_level)
	levels.sort()
	var at := {}
	var cursor := 0.0
	for level in levels:
		at[level] = cursor
		cursor += gap
	for index in parties.size():
		rows = parties[index]
		if rows.is_empty():
			continue
		delays[index] = float(at.get(int((rows[0] as Dictionary).get("level", 0)), 0.0))
	return delays


static func _aimed_delays(parties: Array, track: int) -> PackedFloat32Array:
	var delays := PackedFloat32Array()
	delays.resize(parties.size())
	# BattleBase.TOON_THROW_DELAY / TOON_SQUIRT_DELAY are 0.5. TOON_DROP_DELAY is 0.8.
	var per := 0.8 if track == 6 else 0.5
	var gap := 1.0
	# Wedding cakes and Toon-up ships play after the single-target gags. Geysers stay in the suit list.
	var defer_group := track == 4 or track == 6
	var buckets := {}
	var order: Array[int] = []
	var groups: Array[int] = []
	for index in parties.size():
		var rows: Array = parties[index]
		if rows.is_empty():
			continue
		var row: Dictionary = rows[0]
		var level := int(row.get("level", 0))
		if defer_group and ToonLoadout.affects_group(track, level):
			groups.append(index)
			continue
		var cog := int(row.get("cog", 0))
		if not buckets.has(cog):
			buckets[cog] = []
			order.append(cog)
		(buckets[cog] as Array).append(index)
	var ranked: Array = []
	for index in order.size():
		var cog := order[index]
		ranked.append({"cog": cog, "n": (buckets[cog] as Array).size(), "i": index})
	# Fewer toons on a cog go first, matching MovieThrow's suit sort.
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["n"]) == int(b["n"]):
			return int(a["i"]) < int(b["i"])
		return int(a["n"]) < int(b["n"])
	)
	var suit_at := 0.0
	var singles_end := 0.0
	for item in ranked:
		var rank: Dictionary = item
		var members: Array = (buckets[int(rank["cog"])] as Array).duplicate()
		members.sort_custom(func(a: int, b: int) -> bool:
			var left: Dictionary = (parties[a] as Array)[0]
			var right: Dictionary = (parties[b] as Array)[0]
			var left_level := int(left.get("level", 0))
			var right_level := int(right.get("level", 0))
			if left_level == right_level:
				return a < b
			return left_level < right_level
		)
		var inner := 0.0
		for party_index in members:
			delays[party_index] = suit_at + inner
			var beat: Dictionary = (parties[party_index] as Array)[0]
			var length := seconds("gag", track, int(beat.get("level", 0)), false)
			singles_end = maxf(singles_end, delays[party_index] + length)
			inner += per
		suit_at += gap
	if track == 6:
		var extra := 0.0
		for group_index in groups:
			delays[group_index] = singles_end + extra
			extra += gap
	else:
		for group_index in groups:
			delays[group_index] = singles_end
	return delays


## MovieSuitAttacks.getToonTrack. The extra 1.4s is the reaction after the hit.
static func _cog_length(title: String, body: String) -> float:
	var react := _attack_react(title, body)
	return maxf(3.8, maxf(float(react["hit_t"]), float(react["dodge_t"])) + 1.4)


static func _react(hit: String, hit_t: float, dodge: String, dodge_t: float) -> Dictionary:
	return {"hit": hit, "hit_t": hit_t, "dodge": dodge, "dodge_t": dodge_t}


static func _attack_react(title: String, body: String) -> Dictionary:
	var heavy := body == "a" or body == "b"
	if title == "Clip On Tie!" or title == "Power Tie!":
		return _react("conked", (3.3 if heavy else 2.61), "sidestep-left", (3.1 if heavy else 2.34))
	if title == "Finger Wag!":
		var wag := 2.0
		if body == "a":
			wag = 1.7
		elif body == "b":
			wag = 1.8
		return _react("slip-backward", 2.7, "sidestep-left", wag)
	if title == "Rolodex!":
		var cards := 3.5
		if body == "a":
			cards = 3.8
		elif body == "b":
			cards = 4.0
		return _react("conked", cards, "sidestep-left", 2.5)
	if title == "Bounce Check!":
		if body == "a":
			return _react("conked", 5.1, "sidestep-left", 4.3)
		return _react("conked", 4.4, "sidestep-left", 3.6)
	if title == "Play Hardball!":
		if body == "b":
			return _react("conked", 3.46, "sidestep-left", 2.56)
		return _react("conked", 2.76, "sidestep-left", 1.86)
	if title == "Canned!":
		if body == "c":
			return _react("struggle", 3.93, "sidestep-left", 3.1)
		return _react("struggle", 4.63, "sidestep-left", 3.6)
	if title == "Half Windsor!":
		return _react("conked", 3.4, "sidestep-left", 2.4)
	if title == "Head Shrink!":
		return _react("cringe", 2.1, "sidestep-left", 1.4)
	if title == "Sacked!":
		return _react("struggle", 3.88, "sidestep-left", 3.0)
	var known := {
		"Pound Key!": _react("cringe", 2.7, "sidestep-left", 1.9),
		"Write Off!": _react("slip-forward", 3.4, "sidestep-left", 2.4),
		"Rubber Stamp!": _react("conked", 3.4, "sidestep-left", 1.9),
		"Razzle Dazzle!": _react("cringe", 2.6, "sidestep-left", 1.9),
		"Fountain Pen!": _react("conked", 1.81, "duck", 0.11),
		"Rub Out!": _react("conked", 2.2, "jump", 2.0),
		"Pick Pocket!": _react("cringe", 0.6, "sidestep-left", 0.01),
		"Hang Up!": _react("slip-backward", 5.5, "jump", 4.7),
		"Red Tape!": _react("struggle", 3.4, "jump", 2.8),
		"Audit!": _react("conked", 3.2, "duck", 0.9),
		"Calculate!": _react("conked", 3.2, "sidestep-left", 1.8),
		"Tabulate!": _react("conked", 3.2, "sidestep-left", 1.8),
		"Eviction Notice!": _react("conked", 3.4, "jump", 2.8),
		"Withdrawal!": _react("cringe", 1.2, "duck", 0.2),
		"Mumbo Jumbo!": _react("cringe", 3.2, "sidestep-left", 2.2),
		"Quake!": _react("slip-forward", 1.8, "jump", 1.1),
		"Shake!": _react("slip-forward", 1.1, "jump", 0.7),
		"Tremor!": _react("slip-forward", 1.1, "jump", 0.7),
		"Synergy!": _react("slip-forward", 1.7, "jump", 0.91),
		"Power Trip!": _react("slip-forward", 1.8, "jump", 1.29),
		"Guilt Trip!": _react("slip-forward", 1.5, "jump", 0.86),
		"Paradigm Shift!": _react("slip-backward", 1.95, "jump", 0.95),
		"Pink Slip!": _react("cringe", 2.81, "jump", 2.8),
		"Crunch!": _react("cringe", 4.7, "sidestep-left", 3.6),
		"Market Crash!": _react("cringe", 3.8, "sidestep-left", 2.4),
		"Glower Power!": _react("cringe", 1.6, "sidestep-left", 0.7),
		"Fired!": _react("cringe", 1.5, "sidestep-left", 0.3),
		"Restraining Order!": _react("cringe", 3.4, "sidestep-left", 2.8),
		"Pecking Order!": _react("cringe", 4.2, "sidestep-left", 2.8),
		"Bite!": _react("cringe", 3.2, "sidestep-left", 2.9),
		"Chomp!": _react("cringe", 3.2, "sidestep-left", 2.75),
	}
	if known.has(title):
		return known[title]
	return _react("cringe", 2.4, "sidestep-left", 2.4)


## MovieSuitAttacks throw release and flight time. The release includes the prop's appear.
func _throw_flight(title: String, body: String, missed: bool) -> Vector2:
	var heavy := body != "c"
	match title:
		"Clip On Tie!", "Power Tie!":
			var delay := 2.17 if heavy else 1.45
			return Vector2(1.0 + delay, 0.8 if missed else 0.4)
		"Half Windsor!":
			return Vector2(3.17, 0.8 if missed else 0.4)
		"Pink Slip!", "Red Tape!", "Eviction Notice!", "Restraining Order!":
			return Vector2(3.03, 0.5)
		"Canned!":
			return Vector2(3.13 if heavy else 2.43, 1.5)
		"Sacked!":
			return Vector2(2.98, 0.9)
		"Market Crash!":
			return Vector2(2.42, 1.5)
		"Bite!", "Chomp!":
			return Vector2(3.03, 0.4)
		"Play Hardball!":
			return Vector2(3.09 if body == "b" else 2.39, 0.5)
		"Bounce Check!":
			return Vector2(2.5 if body == "a" else 1.8, 0.5)
		"Pecking Order!":
			return Vector2(3.2, 1.1)
		"Tee Off!":
			return Vector2(4.35, 0.5)
		_:
			return Vector2(1.4, 0.75 if missed else 0.5)


## One row is [delay, file]. Hit-only cues are left out of a miss.
func _attack_cues(title: String, body: String, hit: bool) -> Array:
	var tie := (2.17 if body != "c" else 1.45) + 1.0
	var check := 2.5 if body == "a" else 1.8
	match title:
		"Pound Key!", "Hang Up!":
			return [[1.3, "SA_hangup.ogg"]]
		"Shred!":
			return [[3.4, "SA_shred.ogg"]]
		"Clip On Tie!":
			return [[tie, "SA_powertie_throw.ogg"]]
		"Power Tie!":
			if hit:
				return [[2.3, "SA_powertie_throw.ogg"], [2.9, "SA_powertie_impact.ogg"]]
			return [[2.3, "SA_powertie_throw.ogg"]]
		"Fountain Pen!":
			return [[1.6, "SA_fountain_pen.ogg"]]
		"Rub Out!":
			return [[1.7, "SA_rubout.ogg"]]
		"Finger Wag!":
			return [[1.3, "SA_finger_wag.ogg"]]
		"Write Off!":
			return [[2.3, "SA_writeoff_pen_only.ogg"], [3.2, "SA_writeoff_ding_only.ogg"]]
		"Rubber Stamp!":
			return [[1.3, "SA_rubber_stamp.ogg"]]
		"Razzle Dazzle!":
			return [[1.6, "SA_razzle_dazzle.ogg"]]
		"Synergy!":
			if hit:
				return [[0.9, "SA_synergy.ogg"], [2.2, "Toon_bodyfall_synergy.ogg"]]
			return [[0.9, "SA_synergy.ogg"]]
		"Tee Off!":
			return [[4.1, "SA_tee_off.ogg"]]
		"Brain Storm!":
			return [[2.6, "SA_brainstorm.ogg"]]
		"Buzz Word!":
			return [[3.9, "SA_buzz_word.ogg"]]
		"Demotion!":
			return [[1.2, "SA_demotion.ogg"]]
		"Canned!":
			if hit:
				return [[2.6, "SA_canned_tossup_only.ogg"], [3.93 if body == "c" else 4.63, "SA_canned_impact_only.ogg"]]
			return [[2.6, "SA_canned_tossup_only.ogg"]]
		"Pink Slip!":
			return [[2.9, "SA_pink_slip.ogg"]]
		"Glower Power!":
			return [[1.1, "SA_glower_power.ogg"]]
		"Head Shrink!":
			if hit:
				return [[2.1, "SA_head_shrink_only.ogg"], [5.8, "SA_head_grow_back_only.ogg"]]
			return []
		"Rolodex!":
			return [[2.8, "SA_rolodex.ogg"]]
		"Evil Eye!":
			return [[1.3, "SA_evil_eye.ogg"]]
		"Play Hardball!":
			if hit:
				return [[2.8, "SA_hardball_impact_only.ogg"]]
			return [[3.1, "SA_hardball.ogg"]]
		"Double Talk!":
			return [[2.5, "SA_filibuster.ogg"]]
		"Hot Air!":
			return [[1.6, "SA_hot_air.ogg"]]
		"Pick Pocket!":
			if hit:
				return [[0.2, "SA_pick_pocket.ogg"]]
			return []
		"Filibuster!":
			return [[1.1, "SA_filibuster.ogg"]]
		"Tremor!":
			return [[0.9, "SA_tremor.ogg"]]
		"Red Tape!":
			return [[2.9, "SA_red_tape.ogg"]]
		"Paradigm Shift!":
			if hit:
				return [[2.1, "SA_paradigm_shift.ogg"]]
			return []
		"Bounce Check!":
			return [[check + 0.5, "SA_pink_slip.ogg"], [check + 1.5, "SA_pink_slip.ogg"]]
		"Watercooler!":
			return [[1.1, "SA_watercooler_appear_only.ogg"], [2.97, "SA_watercooler_spray_only.ogg"]]
		"Fired!":
			return [[1.0, "SA_hot_air.ogg"]]
		"Audit!":
			return [[1.9, "SA_audit.ogg"]]
		"Liquidate!":
			return [[2.0, "SA_liquidate.ogg"]]
		"Withdrawal!":
			return [[1.4, "SA_withdrawl.ogg"]]
		"Jargon!":
			return [[2.1, "SA_jargon.ogg"]]
		"Mumbo Jumbo!":
			return [[2.5, "SA_mumbo_jumbo.ogg"]]
		"Guilt Trip!":
			return [[1.1, "SA_guilt_trip.ogg"]]
		_:
			return []


func has_aim() -> bool:
	return _aiming


func end_aim() -> void:
	_aiming = false
	_aim_actor = null
	_aim_cog = null


func aim_camera(camera: Camera3D, basis: Dictionary) -> void:
	if not _aiming or camera == null:
		return
	var name := _aim_close_name if _aim_time >= _aim_open else _aim_open_name
	var on := _aim_close_on if _aim_time >= _aim_open else _aim_open_on
	var shot: Dictionary = _SHOTS.get(name, _SHOTS["group_low"])
	var origin: Vector3 = basis.get("origin", Vector3.ZERO)
	var forward: Vector3 = basis.get("forward", Vector3(0, 0, 1))
	var right: Vector3 = basis.get("right", Vector3.RIGHT)
	var anchor := origin
	var height := 3.5
	if on == "toon" and _live(_aim_actor):
		anchor = _aim_actor.global_position
		height = 3.5
	elif on == "cog" and _live(_aim_cog):
		anchor = _aim_cog.global_position
		height = maxf(float(_aim_cog.get("height")), _HEIGHT)
	elif on == "cog":
		anchor = origin + forward * 5.0
		height = _HEIGHT
	var rise := float(shot.get("z", 3.0))
	if bool(shot.get("chest", false)):
		rise *= height
	elif bool(shot.get("plus_height", false)):
		rise += height
	var side := float(shot.get("x", 0.0))
	if bool(shot.get("flip", false)):
		side *= _aim_flip
	var ahead := float(shot.get("y", 0.0))
	var pos := anchor + right * side + forward * ahead + Vector3.UP * rise
	var look := origin + Vector3.UP * 2.0
	if bool(shot.get("rel", false)):
		look = anchor + Vector3.UP * (height * 0.66)
	if pos.distance_squared_to(look) < 0.36:
		pos = look - forward * 6.0 + Vector3.UP * 2.0
	camera.fov = 80.0
	camera.global_position = pos
	if camera.global_position.distance_squared_to(look) > 0.25:
		camera.look_at(look, Vector3.UP)


func clear_traps() -> void:
	for key in _traps.keys():
		var record: Dictionary = _traps[key]
		var node: Node = record.get("node")
		if node != null and is_instance_valid(node):
			node.queue_free()
	_traps.clear()
	_clear_spawned()


func party() -> Array:
	return _party


func play(beats: Array, actor_of: Callable, cog_of: Callable, still: Callable, contact: Callable) -> void:
	_fired.clear()
	_party = beats
	if beats.is_empty():
		return
	var lead: Dictionary = beats[0]
	var kind := String(lead.get("kind", ""))
	var parties := split_parties(beats)
	if kind == "gag" and parties.size() > 1 and joins_chorus(lead):
		await _play_chorus(beats, parties, actor_of, cog_of, still, contact)
		return
	var actor: ToonActor = actor_of.call(int(lead.get("toon", 0)))
	var marks := _marks(beats, cog_of)
	_begin_camera(lead, actor, marks)
	await _attack_one(lead, beats, actor, marks, actor_of, still, contact)
	_clear_spawned()
	if kind == "gag":
		await _cog_death(marks, still)
		_finish_revives(marks)
	_rest(actor, marks)


func _attack_one(lead: Dictionary, beats: Array, actor: ToonActor, marks: Array, actor_of: Callable, still: Callable, contact: Callable) -> void:
	var kind := String(lead.get("kind", ""))
	var track := int(lead.get("track", -1))
	var level := int(lead.get("level", 0))
	if kind == "cog":
		await _suit(beats, actor_of, marks, still, contact)
	elif kind == "gag" and actor != null and track == 4:
		await _throw(actor, _prop_name(track, level), level, marks, still, contact)
	elif kind == "gag" and actor != null and track == 5 and level == 0:
		await _flower(actor, marks, still, contact)
	elif kind == "gag" and actor != null and track == 5 and level >= 5:
		await _sky_squirt(actor, _prop_name(track, level), level, marks, still, contact)
	elif kind == "gag" and actor != null and track == 5:
		await _squirt(actor, _prop_name(track, level), level, marks, still, contact)
	elif kind == "gag" and actor != null and track == 6:
		await _drop(actor, _prop_name(track, level), level, marks, still, contact)
	elif kind == "gag" and actor != null and track == 1:
		await _trap(actor, _prop_name(track, level), level, marks, still, contact)
	elif kind == "gag" and actor != null and track == 2:
		await _lure(actor, _prop_name(track, level), level, marks, still, contact)
	elif kind == "gag" and actor != null and track == 3:
		await _sound(actor, _prop_name(track, level), level, marks, still, contact)
	elif kind == "gag" and actor != null and track == 0:
		await _heal(actor, _prop_name(track, level), level, beats, actor_of, still, contact)
	else:
		await _wait(1.2, still)
		if still.call():
			contact.call()


func _play_chorus(beats: Array, parties: Array, actor_of: Callable, cog_of: Callable, still: Callable, contact: Callable) -> void:
	var lead: Dictionary = beats[0]
	var actor: ToonActor = actor_of.call(int(lead.get("toon", 0)))
	var marks := _marks(beats, cog_of)
	_begin_camera(lead, actor, marks)
	var delays := chorus_delays(parties)
	var pending := {"n": parties.size()}
	_chording = true
	var clock := 0.0
	for index in parties.size():
		var party: Array = parties[index]
		var delay := float(delays[index]) if index < delays.size() else 0.0
		var who: ToonActor = null
		if not party.is_empty():
			who = actor_of.call(int((party[0] as Dictionary).get("toon", 0)))
		var party_marks := _marks(party, cog_of)
		var batch := party
		var touch := func() -> void:
			_party = batch
			if contact.is_valid():
				contact.call()
		_play_party(party, who, party_marks, delay, actor_of, still, touch, pending)
	while int(pending["n"]) > 0 and still.call():
		_aim_time = clock
		await get_tree().process_frame
		if not is_inside_tree():
			_chording = false
			return
		clock += get_process_delta_time()
	_chording = false
	_aim_time = clock
	_clear_spawned()
	await _cog_death(marks, still)
	_finish_revives(marks)
	for party in parties:
		var rows: Array = party
		if rows.is_empty():
			continue
		var who: ToonActor = actor_of.call(int((rows[0] as Dictionary).get("toon", 0)))
		if who != null:
			_rest(who, _marks(rows, cog_of))


func _play_party(party: Array, actor: ToonActor, marks: Array, delay: float, actor_of: Callable, still: Callable, contact: Callable, pending: Dictionary) -> void:
	if delay > 0.0:
		await _wait(delay, still)
	if still.call():
		if actor == null or party.is_empty():
			contact.call()
		else:
			var lead: Dictionary = party[0]
			_make_owner = actor.get_instance_id()
			await _attack_one(lead, party, actor, marks, actor_of, still, contact)
			_clear_owner(actor.get_instance_id())
	pending["n"] = int(pending["n"]) - 1


func _marks(beats: Array, cog_of: Callable) -> Array:
	var marks: Array = []
	for item in beats:
		if not (item is Dictionary):
			continue
		var beat: Dictionary = item
		var cog_id := int(beat.get("cog", 0))
		var cog: Node = cog_of.call(cog_id)
		marks.append({
			"cog": cog,
			"id": cog_id,
			"hit": bool(beat.get("hit", false)),
			"hp": int(beat.get("cog_hp", 1)),
			"revived": bool(beat.get("revived", false)),
		})
	return marks


func _throw(actor: ToonActor, pie_name: String, level: int, marks: Array, still: Callable, contact: Callable) -> void:
	var stamp := actor.get_instance_id()
	_make_owner = stamp
	var pie := _make(pie_name)
	_hand(pie, actor, "def_joint_right_hold")
	var aim := _first_cog(marks)
	var hit := _any_hit(marks)
	var gate := {}
	await _run(seconds("gag", 4, level, false), still, func(elapsed: float) -> void:
		_make_owner = stamp
		actor.pose_action("throw", elapsed)
		# tPieLeavesHand 2.7, tPieHitsSuit 3.0, tSuitDodges 2.45.
		if pie_name == "birthday-cake":
			_pose_prop(pie, pie_name, elapsed)
		if elapsed < 2.7:
			pie.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf(elapsed, 0.0, 1.0))
		elif level == 6 and marks.size() > 1:
			_fly_cake(pie, marks, elapsed)
		else:
			_fly(pie, aim, _HEIGHT if hit else _HEIGHT * 1.3, elapsed, 2.7, 0.3 if hit else 0.45, not hit, not hit)
		if hit and elapsed >= 3.0 and not pie.has_meta("splats"):
			pie.visible = false
			# MovieThrow removes the cake tiers at impact, then shows the splat.
			_hide_cake_hits(pie, marks)
			var splats: Array[Node3D] = []
			for mark in marks:
				var row: Dictionary = mark
				if not bool(row.get("hit", false)):
					continue
				var cog := _node3d(row.get("cog"))
				var splat := _make("splat")
				_tint(splat, _splat_color(pie_name), true)
				splat.scale = Vector3.ONE * _splat_scale(pie_name)
				if cog != null:
					splat.global_position = cog.global_position + Vector3(0.0, _HEIGHT, 0.0)
				splats.append(splat)
			pie.set_meta("splats", splats)
		if pie.has_meta("splats"):
			for shown in pie.get_meta("splats"):
				if _live(shown) and shown is Node3D:
					var card := shown as Node3D
					var age := elapsed - 3.0
					_pose_prop(card, "splat", age)
					# ActorInterval plays the clip, then removeProp. 24 fps, last frame included.
					var frames := 10
					if card.has_meta("prop_bank"):
						frames = int((card.get_meta("prop_bank") as Dictionary).get("frames", frames))
					card.visible = age <= float(maxi(frames - 1, 1)) / 24.0
					if card.visible:
						_face_camera(card)
		_react_marks(marks, elapsed, 3.0, "pie-small", 2.45)
		if level == 6:
			if hit:
				_once("throw", elapsed, 1.0, "AA_throw_wedding_cake.ogg", stamp)
				_once("pie", elapsed, 3.0, "AA_throw_wedding_cake_cog.ogg", stamp)
			else:
				_once("throw", elapsed, 2.45, "AA_throw_wedding_cake_miss.ogg", stamp)
		else:
			_once("throw", elapsed, 2.6, "AA_pie_throw_only.ogg", stamp)
			if hit:
				_once("pie", elapsed, 2.7, _pie_hit(level), stamp)
		if elapsed >= 3.0 and _latch(gate, "hit"):
			contact.call()
	)
	actor.end_action("throw")


func _flower(actor: ToonActor, marks: Array, still: Callable, contact: Callable) -> void:
	var stamp := actor.get_instance_id()
	_make_owner = stamp
	var button := _make("button")
	_hand(button, actor, "def_joint_left_hold")
	button.scale = Vector3.ONE
	var flower := _make("squirting-flower")
	var joint := _joint(actor, "def_joint_attachFlower")
	if joint != null:
		flower.reparent(joint, false)
	flower.visible = false
	var spray := _make("spray")
	spray.visible = false
	_tint(spray, Color(0.75, 0.75, 1.0, 0.8))
	var aim := _first_cog(marks)
	var hit := _any_hit(marks)
	var gate := {}
	# Flower grows at 1.0s over 0.5s. Spray starts at 2.5 and lasts 0.3s.
	await _run(seconds("gag", 5, 0, false), still, func(elapsed: float) -> void:
		_make_owner = stamp
		actor.pose_action("pushbutton", elapsed)
		if elapsed >= 1.0:
			flower.visible = true
			var grown := clampf((elapsed - 1.0) / 0.5, 0.0, 1.0)
			var size := lerpf(0.01, 1.5, grown)
			if elapsed >= 2.5 and elapsed <= 2.8:
				size = 1.5
			elif elapsed > 2.8:
				size = lerpf(1.5, 0.01, clampf((elapsed - 2.8) / 0.5, 0.0, 1.0))
			flower.scale = Vector3.ONE * size
		if elapsed >= 2.5 and elapsed < 2.8 and aim != null:
			spray.visible = true
			_spray(spray, flower.global_position, aim.global_position + Vector3(0.0, _HEIGHT * 0.66, 0.0), 0)
		else:
			spray.visible = false
		_react_marks(marks, elapsed, 2.7, "squirt-small", 2.5)
		_once("squirt", elapsed, 2.1, "AA_squirt_flowersquirt.ogg" if hit else "AA_squirt_flowersquirt_miss.ogg", stamp)
		if elapsed >= 2.7 and _latch(gate, "hit"):
			contact.call()
	)
	actor.end_action("pushbutton")


func _squirt(actor: ToonActor, prop_name: String, level: int, marks: Array, still: Callable, contact: Callable) -> void:
	var stamp := actor.get_instance_id()
	_make_owner = stamp
	var prop := _make(prop_name)
	if level == 2:
		# MovieSquirt water-gun: right hand, not the joint origin.
		_seat(prop, actor, "def_joint_right_hold", Vector3(0.28, 0.1, 0.08), Vector3(85.6, -4.44, 94.43), Vector3.ONE)
	else:
		_hand(prop, actor, "def_joint_right_hold")
	var spray := _make("spray")
	spray.visible = false
	_tint(spray, Color(0.75, 0.75, 1.0, 0.8))
	var aim := _first_cog(marks)
	var hit := _any_hit(marks)
	var when := _squirt_when(level)
	var clip := String(when.get("clip", "pushbutton"))
	var spray_at := float(when.get("spray", 2.0))
	var hold := float(when.get("hold", 0.2))
	var contact_at := spray_at + 0.1
	var dodge_at := float(when.get("dodge", contact_at))
	var hydrant: Node3D = null
	if level == 4:
		hydrant = _make("hydrant")
		# The hose is parented to the hydrant, and the hydrant sits on the toon.
		hydrant.reparent(actor)
		hydrant.position = Vector3.ZERO
		hydrant.basis = Basis.IDENTITY
		prop.reparent(hydrant)
		prop.position = Vector3.ZERO
		prop.basis = Basis.IDENTITY
	var gate := {}
	await _run(seconds("gag", 5, level, false), still, func(elapsed: float) -> void:
		_make_owner = stamp
		actor.pose_action(clip, elapsed)
		if prop_name == "glass" or prop_name == "firehose":
			var started := 0.7 if level == 4 else 0.0
			_pose_prop(prop, prop_name, maxf(elapsed - started, 0.0))
		if level != 4:
			prop.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf(elapsed / 0.5, 0.0, 1.0))
		if elapsed >= spray_at and elapsed < spray_at + hold and aim != null:
			spray.visible = true
			_spray(spray, prop.global_position, aim.global_position + Vector3(0.0, _HEIGHT * 0.66, 0.0), level)
		else:
			spray.visible = false
		_react_marks(marks, elapsed, contact_at, "squirt-small", dodge_at)
		_once("squirt", elapsed, float(when.get("sound", spray_at)), _SQUIRT_HIT[level] if hit else _SQUIRT_MISS[level], stamp)
		if elapsed >= contact_at and _latch(gate, "hit"):
			contact.call()
	)
	actor.end_action(clip)


func _sky_squirt(actor: ToonActor, prop_name: String, level: int, marks: Array, still: Callable, contact: Callable) -> void:
	var stamp := actor.get_instance_id()
	_make_owner = stamp
	var aim := _first_cog(marks)
	var prop := _make(prop_name)
	prop.visible = false
	if aim != null:
		prop.global_position = aim.global_position + Vector3(0.0, _HEIGHT + 6.0, 0.0)
	var hit := _any_hit(marks)
	var gate := {}
	var cloud := level == 5
	if cloud:
		var button := _make("button")
		_hand(button, actor, "def_joint_left_hold")
		button.scale = Vector3.ONE
		prop.global_basis = _Z_UP
		_cloud_rain(prop)
	await _run(seconds("gag", 5, level, false), still, func(elapsed: float) -> void:
		_make_owner = stamp
		actor.pose_action("pushbutton", elapsed)
		if cloud:
			# pose(0) through the grow, then the bolt clip starts one second in.
			_pose_prop(prop, "stormcloud", 0.0 if elapsed < 2.5 else 1.0 + (elapsed - 2.5))
			# A hit holds the rain. A miss shrinks after the short 1.7s hold.
			var hold_until := 6.2 if hit else 4.2
			if aim != null:
				prop.global_position = aim.global_position + Vector3(0.0, _HEIGHT + 3.0, 0.0)
			prop.global_basis = _Z_UP
			if elapsed < 1.5:
				prop.visible = true
				prop.scale = Vector3.ONE * lerpf(0.05, 3.0, elapsed / 1.5)
			elif elapsed < hold_until:
				prop.visible = true
				prop.scale = Vector3.ONE * 3.0
			else:
				prop.scale = Vector3.ONE * lerpf(3.0, 0.05, clampf((elapsed - hold_until) / 0.5, 0.0, 1.0))
			_cloud_rain_step(prop, elapsed, hit, hold_until)
		elif elapsed >= 1.0:
			prop.visible = true
			var column := clampf((elapsed - 1.0) / 0.5, 0.0, 1.0)
			prop.scale = Vector3(column, column * 2.2, column)
			if aim != null:
				prop.global_position = aim.global_position + Vector3(0.0, 0.2, 0.0)
		_react_marks(marks, elapsed, 2.9, "soak" if level >= 6 else "squirt-small", 1.8)
		_once("sky", elapsed, 2.3 if cloud else 1.8, _SQUIRT_HIT[level] if hit else _SQUIRT_MISS[level], stamp)
		if cloud:
			_once("sky2", elapsed, 4.6, _SQUIRT_HIT[level] if hit else _SQUIRT_MISS[level], stamp)
		if elapsed >= 2.9 and _latch(gate, "hit"):
			contact.call()
	)
	actor.end_action("pushbutton")


# MovieSquirt storm cloud. liquidate.ptf is parented to the cloud, so the
# sphere and the speed scale with it, while the raindrop card does not.
func _cloud_rain(cloud: Node3D) -> void:
	cloud.add_child(_rain_system("trickle", 15))
	cloud.add_child(_rain_system("rain", 30))
	cloud.add_child(_rain_system("rain2", 30))
	cloud.add_child(_rain_system("rain3", 30))


func _rain_system(node_name: String, amount: int) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = node_name
	# liquidate setPos (0, 0, -0.2), just under the cloud.
	particles.position = Vector3(0.0, 0.0, -0.2)
	particles.amount = amount
	particles.lifetime = 0.4
	particles.explosiveness = 0.0
	particles.local_coords = true
	particles.emitting = false
	particles.visibility_aabb = AABB(Vector3(-4.0, -4.0, -24.0), Vector3(8.0, 8.0, 26.0))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	# Radius 0.45 and speed 16, times the cloud's scale of 3. The node scale below undoes that for the card.
	process.emission_sphere_radius = 1.35
	process.direction = Vector3(0.0, 0.0, -1.0)
	process.spread = 8.0
	process.initial_velocity_min = 48.0
	process.initial_velocity_max = 48.0
	process.gravity = Vector3.ZERO
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.225)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.albedo_texture = load("res://assets/battle/props/raindrop.png")
	quad.material = mat
	particles.draw_pass_1 = quad
	return particles


func _cloud_rain_step(cloud: Node3D, elapsed: float, hit: bool, hold_until: float) -> void:
	var cloud_hold := 4.7 if hit else 1.7
	var trickle_for := cloud_hold * 0.25
	var rain_at := 2.5 + trickle_for * 2.0
	var particle_scale := 1.0 / maxf(cloud.scale.x, 0.05)
	var names: PackedStringArray = ["trickle", "rain", "rain2", "rain3"]
	for node_name in names:
		var system := cloud.get_node(node_name) as GPUParticles3D
		if system == null:
			continue
		system.scale = Vector3.ONE * particle_scale
	var trickle := cloud.get_node("trickle") as GPUParticles3D
	if trickle != null:
		trickle.emitting = elapsed >= 2.5 and elapsed < 2.5 + trickle_for
	for i in 3:
		var system := cloud.get_node(names[i + 1]) as GPUParticles3D
		if system == null:
			continue
		system.emitting = elapsed >= rain_at + float(i) * 0.3 and elapsed < hold_until


func _drop(actor: ToonActor, prop_name: String, level: int, marks: Array, still: Callable, contact: Callable) -> void:
	var stamp := actor.get_instance_id()
	_make_owner = stamp
	var button := _make("button")
	_hand(button, actor, "def_joint_left_hold")
	button.scale = Vector3.ONE
	var props: Array[Node3D] = []
	for mark in marks:
		var falling := _make(prop_name)
		falling.visible = false
		props.append(falling)
	var hit := _any_hit(marks)
	var fall := _DROP_FALL[clampi(level, 0, _DROP_FALL.size() - 1)]
	var shadows: Array[Node3D] = []
	for _mark in marks:
		shadows.append(_shadow())
	var gate := {}
	var react := "flatten" if level >= 3 else "drop-react"
	await _run(seconds("gag", 6, level, false), still, func(elapsed: float) -> void:
		_make_owner = stamp
		actor.pose_action("pushbutton", elapsed)
		# The button lands at 2.44. The shadow grows until the object appears at 4.3.
		if elapsed >= 2.44 and _latch(gate, "box"):
			_sfx("AA_drop_trigger_box.ogg")
		for index in props.size():
			var falling := props[index]
			var shadow := shadows[index]
			var mark: Dictionary = marks[index]
			var cog := _node3d(mark.get("cog"))
			if cog == null:
				falling.visible = false
				shadow.visible = false
				continue
			var missed := not bool(mark.get("hit", false))
			var rest := cog.global_position + Vector3(0.0, 0.75 if level < 2 else 0.0, 0.0)
			# Big drops miss five units in front of the cog. Small ones still land on it.
			if missed and level >= 3:
				rest += _forward(cog) * 5.0
			shadow.global_position = Vector3(rest.x, cog.global_position.y + 0.05, rest.z)
			if elapsed >= 2.44 and elapsed < 4.6:
				shadow.visible = true
				var grown := clampf((elapsed - 2.44) / (4.3 - 2.44), 0.0, 1.0)
				shadow.scale = Vector3.ONE * lerpf(0.01, 1.6, grown)
			else:
				shadow.visible = false
			if elapsed < 4.3:
				falling.visible = false
				continue
			falling.visible = true
			if prop_name == "ship":
				var fallen := clampf((elapsed - 4.3) / fall, 0.0, 1.0)
				var above := rest + Vector3(0.0, 5.0, 0.0)
				falling.global_position = above.lerp(rest, fallen) + Vector3(0.0, _drop_hop(elapsed - (4.3 + fall)), 0.0)
				var shrink_at := 4.3 + fall + 0.4
				var shrink_for := 0.3 if (not missed or level == 1 or level == 2) else 0.1
				if elapsed < shrink_at:
					falling.scale = Vector3.ONE
				else:
					var faded := clampf((elapsed - shrink_at) / shrink_for, 0.0, 1.0)
					falling.scale = Vector3.ONE * maxf(1.0 - faded, 0.01)
				continue
			# The channel is the fall. The root stays on the cog the way posObject does.
			falling.global_position = _drop_root(cog, level, missed)
			falling.global_basis = cog.global_basis.orthonormalized()
			var full := not missed or level == 1 or level == 2
			var shown := elapsed - 4.3
			if not full:
				shown = minf(shown, fall)
			_pose_prop(falling, prop_name, shown)
			var clip_len := float(maxi(_prop_frames(prop_name) - 1, 1)) / 24.0
			var shrink_at := 4.3 + (clip_len - 0.3 if full else fall + 1.0)
			var shrink_for := 0.3 if full else 0.1
			var base := 1.0
			if prop_name == "weight":
				base = 0.75
			elif prop_name == "safe":
				base = 0.85
			if elapsed < shrink_at:
				falling.scale = Vector3.ONE * base
			else:
				var faded := clampf((elapsed - shrink_at) / shrink_for, 0.0, 1.0)
				falling.scale = Vector3.ONE * base * maxf(1.0 - faded, 0.01)
		_react_marks(marks, elapsed, 4.3, react, 4.3)
		if elapsed >= 4.3 + fall and _latch(gate, "land"):
			_sfx(_DROP_HIT[level] if hit else _DROP_MISS[level])
			if hit and level == 6:
				_sfx("AA_drop_boat_cog.ogg")
		if elapsed >= 4.3 and _latch(gate, "hit"):
			contact.call()
	)
	actor.end_action("pushbutton")


func _trap(actor: ToonActor, prop_name: String, level: int, marks: Array, still: Callable, contact: Callable) -> void:
	var stamp := actor.get_instance_id()
	_make_owner = stamp
	# MovieTrap.__trapTrain lays one railroad for the whole side, not one per cog.
	var railroad := prop_name == "traintrack"
	var props: Array[Node3D] = []
	var count := 1 if railroad else marks.size()
	for _index in count:
		var prop := _make(prop_name)
		if railroad:
			_hide_tunnels(prop)
		else:
			_hand(prop, actor, "def_joint_right_hold")
		props.append(prop)
	var clip := "toss" if level < 3 or level == 5 else "pushbutton"
	var button: Node3D = null
	if level == 3 or level == 4 or level == 6:
		button = _make("button")
		_hand(button, actor, "def_joint_left_hold")
	var gate := {}
	await _run(seconds("gag", 1, level, false), still, func(elapsed: float) -> void:
		_make_owner = stamp
		actor.pose_action(clip, elapsed)
		if railroad:
			var lead := _first_cog(marks)
			if lead != null and not props.is_empty():
				_throw_trap(props[0], actor, lead, level, elapsed)
		else:
			for index in props.size():
				var prop := props[index]
				var mark: Dictionary = marks[index]
				var cog := _node3d(mark.get("cog"))
				if cog == null:
					continue
				_throw_trap(prop, actor, cog, level, elapsed)
				if prop_name == "banana" or prop_name == "rake" or prop_name == "marbles" or prop_name == "tnt":
					_pose_prop(prop, prop_name, elapsed)
		if button != null:
			button.scale = Vector3.ONE
		var sound_at := 0.2
		if level == 0:
			sound_at = 0.25
		elif level == 5:
			sound_at = 1.0
		elif level >= 3:
			sound_at = 2.3
			_once("trapbox", elapsed, 2.3, "AA_drop_trigger_box.ogg", stamp)
		_once("trap", elapsed, sound_at, _TRAP_SFX[level] if level < _TRAP_SFX.size() else "TL_banana.ogg", stamp)
		if elapsed >= 3.5 and _latch(gate, "hit"):
			contact.call()
	)
	if railroad and not props.is_empty():
		var planted := props[0]
		for mark in marks:
			var row: Dictionary = mark
			var cog := _node3d(row.get("cog"))
			if cog != null:
				_plant(cog, planted, int(row.get("id", 0)), _TRAP_SFX[level] if level < _TRAP_SFX.size() else "TL_banana.ogg", level)
	else:
		for index in props.size():
			var mark: Dictionary = marks[index]
			var cog := _node3d(mark.get("cog"))
			if cog != null:
				var planted := props[index]
				if level == 1:
					# The rake left on the cog is rake-step-mod, not the thrown rake.
					var react := _make("rake-react")
					react.global_transform = planted.global_transform
					planted.visible = false
					planted = react
				_plant(cog, planted, int(mark.get("id", 0)), _TRAP_SFX[level] if level < _TRAP_SFX.size() else "TL_banana.ogg", level)
	if button != null:
		button.visible = false
	actor.end_action(clip)


func _lure(actor: ToonActor, prop_name: String, level: int, marks: Array, still: Callable, contact: Callable) -> void:
	var stamp := actor.get_instance_id()
	_make_owner = stamp
	var clip := "battlecast"
	if level == 1 or level == 3:
		clip = "hold-magnet"
	elif level == 5:
		clip = "hypnotize"
	elif level == 6:
		clip = "pushbutton"
	var screen_button: Node3D = null
	var prop := _make(prop_name)
	if level == 6:
		screen_button = _make("button")
		_hand(screen_button, actor, "def_joint_left_hold")
		prop.visible = false
	if level == 1:
		_seat(prop, actor, "def_joint_left_hold", Vector3(-0.27, 0.19, 0.29), Vector3(-90.0, 84.17, -180.0), Vector3(0.85, 0.85, 0.85))
	elif level == 3:
		_seat(prop, actor, "def_joint_left_hold", Vector3(-0.27, 0.08, 0.29), Vector3(-90.0, 84.17, -180.0), Vector3(1.32, 1.32, 1.32))
	elif level == 5:
		_seat(prop, actor, "def_joint_left_hold", Vector3(-1.03, 1.04, -0.3), Vector3(-96.55, 36.14, -170.59), Vector3(1.5, 1.5, 1.5))
	elif level != 6:
		_hand(prop, actor, "def_joint_right_hold")
	var bill: Node3D = null
	var bill_name := _LURE_DOLLAR[level] if level < _LURE_DOLLAR.size() else ""
	if bill_name != "":
		bill = _make(bill_name)
		var paid := _first_cog(marks)
		if paid != null:
			# The bill stands in front of the cog, 5.1 along the cog's forward.
			_seat(bill, paid, "Suit", Vector3(0.0, 5.1, 0.0), Vector3.ZERO, Vector3.ONE)
			bill.scale = Vector3.ONE
		else:
			_hand(bill, actor, "def_joint_right_hold")
	var gate := {}
	var lure_at := 3.5
	if level == 1 or level == 3:
		lure_at = 3.7
	elif level == 5:
		lure_at = 2.6
	elif level == 6:
		lure_at = 2.4
	await _run(seconds("gag", 2, level, false), still, func(elapsed: float) -> void:
		_make_owner = stamp
		actor.pose_action(clip, elapsed)
		if prop_name == "fishing-pole" or prop_name == "hypno-goggles":
			_pose_prop(prop, prop_name, elapsed)
		if bill != null:
			_pose_prop(bill, "1dollar", elapsed)
		if level == 1 or level == 3 or level == 5:
			var held: Vector3 = prop.get_meta("grow")
			prop.scale = held
		elif level == 6:
			# The screen stays down through the button, then grows in 4 ahead of the toon.
			if elapsed < 2.5:
				prop.visible = false
			else:
				prop.visible = true
				if prop.get_parent() != self:
					prop.reparent(self)
				prop.global_position = actor.global_transform * Vector3(0.0, 4.0, 0.0)
				prop.global_basis = actor.global_transform.basis
				if elapsed >= 6.7:
					prop.scale = Vector3(1.0, 1.0, lerpf(1.0, 0.1, clampf((elapsed - 6.7) / 0.4, 0.0, 1.0)))
				else:
					prop.scale = Vector3.ONE * lerpf(0.1, 1.0, clampf((elapsed - 2.5) / 1.2, 0.0, 1.0))
		else:
			prop.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf(elapsed / 0.6, 0.0, 1.0))
		_react_marks(marks, elapsed, lure_at, "hypnotized", lure_at)
		var lure_sound := "TL_fishing_pole.ogg"
		var lure_delay := 0.5
		if level == 1:
			lure_sound = "TL_small_magnet.ogg"
			lure_delay = 0.7
		elif level == 3:
			lure_sound = "TL_large_magnet.ogg"
			lure_delay = 0.7
		elif level == 5:
			lure_sound = "TL_hypnotize.ogg"
		elif level == 6:
			lure_sound = "TL_presentation.ogg"
			lure_delay = 2.3
			_once("lurebox", elapsed, 2.5, "AA_drop_trigger_box.ogg", stamp)
		_once("lure", elapsed, lure_delay, lure_sound, stamp)
		if elapsed >= lure_at and _latch(gate, "hit"):
			for mark in marks:
				var row: Dictionary = mark
				if not bool(row.get("hit", false)):
					continue
				if _spring(int(row.get("id", 0)), elapsed):
					_react_one(row.get("cog"), "rake-react", 0.0)
			contact.call()
		_pose_sprung(elapsed)
	)
	if screen_button != null:
		screen_button.visible = false
	actor.end_action(clip)


func _sound(actor: ToonActor, prop_name: String, level: int, marks: Array, still: Callable, contact: Callable) -> void:
	var stamp := actor.get_instance_id()
	_make_owner = stamp
	var horn := _make("megaphone")
	# Both the megaphone and the instrument sit on the right hand.
	_hand(horn, actor, "def_joint_right_hold")
	var prop := _make(prop_name)
	var seat: Dictionary = _instrument_seat(level)
	_seat(prop, actor, "def_joint_right_hold", seat["pos"], seat["hpr"], Vector3.ONE)
	var gate := {}
	var react_at := 2.8 + (3.0 if level >= 6 else 0.0)
	await _run(seconds("gag", 3, level, false), still, func(elapsed: float) -> void:
		_make_owner = stamp
		actor.pose_action("sound", elapsed)
		# Megaphone shows, the instrument grows after 1s, and the note hits at 2.45.
		horn.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf(elapsed / 0.2, 0.0, 1.0))
		var grown := 0.325
		if level >= 0 and level < _SOUND_SIZE.size():
			grown = _SOUND_SIZE[level]
		var grow_for := 0.2
		if level == 2:
			grow_for = 1.0
		elif level >= 6:
			grow_for = 2.1
		var size := 0.01
		if elapsed >= 1.0:
			size = lerpf(0.01, grown, clampf((elapsed - 1.0) / grow_for, 0.0, 1.0))
		if elapsed >= 2.45 and elapsed < 2.65:
			size = lerpf(grown, grown * 1.7, (elapsed - 2.45) / 0.2)
		elif elapsed >= 2.65 and elapsed < 2.85:
			size = lerpf(grown * 1.7, grown, (elapsed - 2.65) / 0.2)
		elif elapsed >= 4.2:
			size = lerpf(grown, 0.01, clampf((elapsed - 4.2) / 0.1, 0.0, 1.0))
		prop.scale = Vector3(size, size * (1.4 if elapsed >= 2.45 and elapsed < 2.65 else 1.0), size)
		if level >= 6 and elapsed >= 2.2:
			# The singer leaves the hand and stands in front of the toon.
			if prop.get_parent() != self:
				var at := prop.global_position
				prop.reparent(self)
				prop.global_position = at
				prop.set_meta("stage", at)
			var stage: Vector3 = prop.get_meta("stage")
			var walked := clampf((elapsed - 2.2) / 1.0, 0.0, 1.0)
			var ahead := -actor.global_transform.basis.z
			ahead.y = 0.0
			if ahead.length_squared() > 0.01:
				prop.global_position = stage + ahead.normalized() * 1.6 * walked
		_react_marks(marks, elapsed, react_at, "squirt-small")
		var note_at := 2.45
		var appear_at := 1.15
		if level == 1 or level == 3 or level == 4 or level == 5:
			appear_at = 1.05
		elif level == 2:
			appear_at = -1.0
			note_at = 1.7
		elif level >= 6:
			appear_at = 1.0
			note_at = 2.15
		if appear_at >= 0.0 and level < _SOUND_APPEAR.size() and _SOUND_APPEAR[level] != "":
			_once("appear", elapsed, appear_at, _SOUND_APPEAR[level], stamp)
		_once("sound", elapsed, note_at, _SOUND_SFX[level] if level < _SOUND_SFX.size() else "AA_sound_bikehorn.ogg", stamp)
		if level >= 6 and _any_hit(marks):
			_once("glass", elapsed, react_at, "AA_sound_Opera_Singer_Cog_Glass.ogg", stamp)
		if elapsed >= react_at and _latch(gate, "hit"):
			contact.call()
	)
	actor.end_action("sound")


func _heal(actor: ToonActor, prop_name: String, level: int, beats: Array, actor_of: Callable, still: Callable, contact: Callable) -> void:
	var clip := _HEAL_CLIP[level] if level < _HEAL_CLIP.size() else "tickle"
	var dur := seconds("gag", 0, level, false)
	var prop: Node3D = null
	if prop_name != "":
		prop = _make(prop_name)
		if level == 2:
			_seat(prop, actor, "def_joint_right_hold", Vector3(-0.27, -0.24, -0.95), Vector3(-118.0, -10.6, -25.9), Vector3.ONE)
		elif level == 3:
			_seat(prop, actor, "def_joint_left_hold", Vector3(-0.28, 0.0, 0.14), Vector3(0.0, 0.0, -150.0), Vector3.ONE)
		elif level == 5:
			var hips := _hips(actor)
			if hips != null:
				_seat(prop, hips, "", Vector3.ZERO, Vector3.ZERO, Vector3.ONE)
			else:
				_hand(prop, actor, "def_joint_right_hold")
		else:
			_hand(prop, actor, "def_joint_right_hold")
	var hat: Node3D = null
	if level == 3:
		hat = _make("hat")
		_seat(hat, actor, "def_joint_right_hold", Vector3(0.23, 0.09, 0.69), Vector3(180.0, 0.0, 0.0), Vector3.ONE)
	var ladder: Node3D = null
	var glass: Node3D = null
	if level == 6:
		ladder = _make("ladder")
		glass = _make("glass")
		# MovieHeal: ladder is 4 ahead of the toon, the glass is just in front, pitched flat.
		ladder.global_position = actor.global_transform * Vector3(0.0, 4.0, 0.0)
		ladder.global_basis = actor.global_transform.basis
		glass.global_position = actor.global_transform * Vector3(0.0, 1.1, 0.2)
		glass.global_basis = actor.global_transform.basis * _panda_hpr(0.0, 90.0, 0.0)
		ladder.scale = Vector3(0.01, 0.01, 0.01)
		glass.scale = Vector3.ONE * 4.0
	var gate := {}
	await _run(dur, still, func(elapsed: float) -> void:
		actor.pose_action(clip, elapsed)
		if prop != null and (prop_name == "feather" or prop_name == "cubes"):
			_pose_prop(prop, prop_name, elapsed)
		if prop != null and level != 5:
			prop.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf(elapsed / 0.4, 0.0, 1.0))
		if hat != null:
			hat.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf(elapsed / 0.4, 0.0, 1.0))
		if level == 5 and prop != null:
			prop.scale = Vector3.ONE * lerpf(0.01, 1.0, clampf(elapsed / 0.4, 0.0, 1.0))
		if level == 4:
			_pixie(actor, beats, actor_of, elapsed)
		if ladder != null:
			var grown := clampf(elapsed / 1.5, 0.0, 1.0)
			if elapsed > dur - 1.5:
				grown = clampf((dur - elapsed) / 1.5, 0.0, 1.0)
			ladder.scale = Vector3(0.5, 0.5, 0.45) * maxf(grown, 0.01)
			if not actor.has_meta("battle_home"):
				actor.set_meta("battle_home", actor.global_position)
			var home: Vector3 = actor.get_meta("battle_home")
			var climb_to := ladder.global_position
			if elapsed < 1.5:
				actor.global_position = home.lerp(climb_to, elapsed / 1.5)
			elif elapsed < dur - 1.5:
				var risen := clampf((elapsed - 1.5) / 4.5, 0.0, 1.0)
				actor.global_position = climb_to + Vector3(0.0, risen * 3.2, 0.0)
			else:
				actor.global_position = climb_to.lerp(home, clampf((elapsed - (dur - 1.5)) / 1.5, 0.0, 1.0))
		if level < 4 and elapsed >= 1.4 and _latch(gate, "spark"):
			for item in beats:
				if not (item is Dictionary) or not bool((item as Dictionary).get("hit", false)):
					continue
				var patient: ToonActor = actor_of.call(int((item as Dictionary).get("toon_id", (item as Dictionary).get("toon", 0))))
				if patient == null:
					continue
				var spark := _make("splat")
				_tint(spark, Color(0.55, 1.0, 0.45, 0.9))
				spark.scale = Vector3.ONE * 0.35
				spark.global_position = patient.global_position + Vector3(0.0, 3.2, 0.0)
				if level == 2:
					var lips := _make("lips")
					var head := _joint(patient, "def_head")
					if head == null:
						head = _joint(patient, "joint_head")
					if head != null:
						_seat(lips, head, "", Vector3(0.0, 0.0, -3.04), Vector3.ZERO, Vector3.ONE)
					else:
						lips.global_position = patient.global_position + Vector3(0.0, 3.5, 0.35)
					lips.scale = Vector3.ONE
		_once("heal", elapsed, _HEAL_DELAY[level] if level < _HEAL_DELAY.size() else 0.4, _HEAL_SFX[level] if level < _HEAL_SFX.size() else "AA_heal_tickle.ogg")
		if elapsed >= 1.4 and _latch(gate, "hit"):
			contact.call()
	)
	actor.end_action(clip)
	if actor.has_meta("battle_home"):
		actor.global_position = actor.get_meta("battle_home")
		actor.remove_meta("battle_home")


func _suit(beats: Array, actor_of: Callable, marks: Array, still: Callable, contact: Callable) -> void:
	var lead: Dictionary = beats[0]
	var cog := _first_cog(marks)
	var key := String(lead.get("anim", "glower"))
	var title := String(lead.get("attack", ""))
	var thrown_name := ""
	var body := "c"
	var code := ""
	if cog != null and "body" in cog:
		body = String(cog.body)
	if cog != null and "cog_code" in cog:
		code = String(cog.cog_code)
	var reaction := _attack_react(title, body)
	var hit_anim := String(reaction["hit"])
	var dodge_anim := String(reaction["dodge"])
	var hit_t := float(reaction["hit_t"])
	var dodge_t := float(reaction["dodge_t"])
	var length := _cog_length(title, body)
	var props: Array[Node3D] = []
	if cog != null:
		for item in _attack_rows(title, body, code):
			var row: Dictionary = item
			var shown := _make(String(row["prop"]))
			_seat(shown, cog, String(row["joint"]), row["pos"], row["hpr"], row["grow"])
			if bool(row.get("thrown", false)):
				thrown_name = shown.name
			props.append(shown)
	var victims: Array = lead.get("victims", [])
	var gate := {}
	if _live(cog) and title != "":
		cog.set_meta("chat_line", title)
		cog.set_meta("chat_until", Time.get_ticks_msec() + int(length * 1000.0))
		ToonSpeech.cog(title)
	# A fatal hit keeps the round open for the shrink. This clip is only the attack.
	await _run(length, still, func(elapsed: float) -> void:
		if _live(cog):
			_react_one(cog, key, elapsed)
		if (title == "Pound Key!" or title == "Hang Up!") and elapsed >= 1.54:
			for shown in props:
				if shown.name == "receiver" and not shown.has_meta("ear"):
					var ear := Vector3(-0.45, 0.48, -0.62)
					var turn := Vector3(-87.47, -18.21, 7.82)
					if title == "Hang Up!":
						ear = Vector3(-0.53, 0.21, -0.54)
						turn = Vector3(-99.49, -35.27, 1.84)
					_seat(shown, cog, "joint_Rhold", ear, turn, Vector3.ONE)
					shown.set_meta("ear", true)
		var missed := true
		for item in victims:
			if item is Dictionary and bool((item as Dictionary).get("hit", false)):
				missed = false
		var flight := _throw_flight(title, body, missed)
		for shown in props:
			if title == "Pick Pocket!":
				shown.visible = not missed and elapsed >= 0.6 and elapsed < 1.65
			elif title == "Tee Off!" and shown.name == "golf-ball":
				shown.visible = elapsed >= 1.7
			var flying := thrown_name != "" and shown.name == thrown_name and elapsed >= flight.x
			if not flying:
				var grow := Vector3.ONE
				if shown.has_meta("grow"):
					grow = shown.get_meta("grow")
				var amount := 1.0 if elapsed >= 0.4 else lerpf(0.01, 1.0, elapsed / 0.4)
				shown.scale = grow * amount
			if flying:
				var victim := _first_victim(victims, actor_of)
				if victim != null:
					_arc(shown, victim.global_position + Vector3(0.0, 2.4, 0.0), elapsed, flight.x, flight.y, missed)
		for item in victims:
			if not (item is Dictionary):
				continue
			var victim: Dictionary = item
			if bool(victim.get("died", false)):
				continue
			var landed := bool(victim.get("hit", false))
			var react_at := hit_t if landed else dodge_t
			if elapsed < react_at:
				continue
			var actor: ToonActor = actor_of.call(int(victim.get("id", 0)))
			if actor == null:
				continue
			var clip := hit_anim if landed else dodge_anim
			actor.pose_action(clip, elapsed - react_at)
		var cues := _attack_cues(title, body, not missed)
		for index in cues.size():
			var cue: Array = cues[index]
			_once("atk%d" % index, elapsed, float(cue[0]), String(cue[1]))
		if missed and dodge_anim.begins_with("sidestep"):
			_once("step", elapsed, dodge_t + 0.5, "AV_side_step.ogg")
		var strike := hit_t if not missed else dodge_t
		if elapsed >= strike and _latch(gate, "hit"):
			contact.call()
	)
	for item in victims:
		if not (item is Dictionary) or bool((item as Dictionary).get("died", false)):
			continue
		var actor: ToonActor = actor_of.call(int((item as Dictionary).get("id", 0)))
		if actor == null:
			continue
		var clip := hit_anim if bool((item as Dictionary).get("hit", false)) else dodge_anim
		actor.end_action(clip)
	if _live(cog):
		cog.set_meta("chat_line", "")
		cog.set_meta("chat_until", 0)


func _plant(cog: Node3D, prop: Node3D, cog_id: int, sound_name: String, level: int) -> void:
	if _traps.has(cog_id):
		var previous: Dictionary = _traps[cog_id]
		var old: Node = previous.get("node")
		if old != null and old != prop and is_instance_valid(old):
			old.queue_free()
	if level == 6:
		_seat_track(prop, cog)
		prop.scale = Vector3.ONE
		_spawned.erase(prop)
		_traps[cog_id] = {"node": prop, "sound": sound_name, "level": level, "cog": cog}
		return
	var reach := _TRAP_REACH[clampi(level, 0, _TRAP_REACH.size() - 1)]
	var spot := cog.global_position + _forward(cog) * reach
	spot.y = cog.global_position.y
	if level == 0:
		spot.y -= 0.35
	elif level == 5:
		spot.y += 0.4
	else:
		spot.y += 0.05
	prop.reparent(self)
	prop.global_position = spot
	prop.scale = Vector3.ONE * (0.7 if level == 1 else 1.0)
	if level == 1:
		prop.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	elif level == 5:
		prop.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_spawned.erase(prop)
	_traps[cog_id] = {"node": prop, "sound": sound_name, "level": level, "cog": cog}


func _spring(cog_id: int, elapsed: float) -> bool:
	if not _traps.has(cog_id):
		return false
	var record: Dictionary = _traps[cog_id]
	_traps.erase(cog_id)
	record["born"] = elapsed
	_sprung.append(record)
	var level := int(record.get("level", 0))
	if level == 5:
		_sfx("TL_dynamite.ogg")
		record["later"] = "ENC_cogfall_apart.ogg"
		record["later_at"] = 2.0
	elif level == 6:
		_sfx("TL_train.ogg")
		record["later"] = "TL_train_cog.ogg"
		record["later_at"] = 0.4
		var cog := _node3d(record.get("cog"))
		var node := _node3d(record.get("node"))
		if node != null and not node.has_meta("rail_train"):
			# MovieLure drives one train along the rails, from x=-7.131 through 45 feet.
			_show_tunnels(node)
			var train := _make("train")
			var along := node.global_basis.x
			if along.length_squared() < 0.01:
				along = _forward(cog) if cog != null else Vector3.RIGHT
			along = along.normalized()
			node.set_meta("rail_train", train)
			node.set_meta("rail_from", node.global_position + along * -7.131)
			node.set_meta("rail_to", node.global_position + along * (-7.131 + 45.0))
			train.global_position = node.get_meta("rail_from")
			train.global_basis = _train_basis(node)
		if node != null:
			record["train"] = node.get_meta("rail_train")
			record["from"] = node.get_meta("rail_from")
			record["to"] = node.get_meta("rail_to")
	elif level == 1:
		record["later"] = "TL_step_on_rake.ogg"
		record["later_at"] = 0.6
	elif level == 0 or level == 2:
		_sfx("AA_pie_throw_only.ogg")
		record["later"] = "Toon_bodyfall_synergy.ogg"
		record["later_at"] = 0.55
	elif level == 3:
		_sfx("TL_quicksand.ogg")
		record["later"] = "Toon_bodyfall_synergy.ogg"
		record["later_at"] = 0.8
	elif level == 4:
		_sfx("TL_trap_door.ogg")
		record["later"] = "Toon_bodyfall_synergy.ogg"
		record["later_at"] = 1.6
	else:
		_sfx(String(record.get("sound", "TL_step_on_rake.ogg")))
	return true


func _pose_sprung(elapsed: float) -> void:
	for item in _sprung:
		var record: Dictionary = item
		var node := _node3d(record.get("node"))
		if node == null:
			continue
		var age := elapsed - float(record.get("born", elapsed))
		var level := int(record.get("level", 0))
		var later := String(record.get("later", ""))
		if later != "" and age >= float(record.get("later_at", 0.0)) and not bool(record.get("later_played", false)):
			record["later_played"] = true
			_sfx(later)
		if level == 0:
			_pose_prop(node, "banana", 3.1 + age)
		elif level == 2:
			_pose_prop(node, "marbles", 3.1 + age)
		elif level == 5:
			_pose_prop(node, "tnt", age)
		if level == 1:
			if age >= 0.5 and age < 0.6:
				node.rotation_degrees.x = lerpf(-90.0, 0.0, (age - 0.5) / 0.1)
			elif age >= 0.6 and age < 1.3:
				node.rotation_degrees.x = 0.0
			elif age >= 1.3:
				node.rotation_degrees.x = lerpf(0.0, -90.0, clampf((age - 1.3) / 0.4, 0.0, 1.0))
				node.scale = Vector3.ONE * 0.7 * maxf(1.0 - clampf((age - 1.9) / 0.2, 0.0, 1.0), 0.01)
		elif level == 5 and age >= 2.3 and not bool(record.get("boom", false)):
			record["boom"] = true
			node.visible = false
			var boom := _make("explosion")
			boom.global_position = node.global_position + Vector3(0.0, 1.2, 0.0)
			boom.scale = Vector3.ONE * 1.6
		elif level == 6:
			var train := _node3d(record.get("train"))
			if train != null:
				var rolled := clampf(age / 2.0, 0.0, 1.0)
				var start: Vector3 = record.get("from", train.global_position)
				var finish: Vector3 = record.get("to", train.global_position)
				train.global_position = start.lerp(finish, rolled)
				train.global_basis = _train_basis(node)
		elif level <= 2 and age > 1.1:
			node.scale = Vector3.ONE * maxf(1.0 - clampf((age - 1.1) / 1.0, 0.0, 1.0), 0.01)
		elif age > 2.4:
			node.scale = Vector3.ONE * maxf(1.0 - clampf((age - 2.4) / 0.8, 0.0, 1.0), 0.01)


func _react_marks(marks: Array, elapsed: float, at: float, hit_key: String, miss_at: float = -1.0) -> void:
	var dodge := at if miss_at < 0.0 else miss_at
	for mark in marks:
		var row: Dictionary = mark
		var when := at if bool(row.get("hit", false)) else dodge
		if elapsed < when:
			continue
		var key := hit_key
		if not bool(row.get("hit", false)):
			key = "sidestep-left"
		# A killing hit still plays the react. The lose-mod follows the gag.
		_react_one(row.get("cog"), key, elapsed - when)


func _cog_death(marks: Array, still: Callable) -> void:
	var dying := false
	for mark in marks:
		var row: Dictionary = mark
		if int(row.get("hp", 1)) <= 0 and row.get("cog") != null:
			dying = true
	if not dying:
		return
	var gate := {}
	await _run(LOSE_SECONDS, still, func(elapsed: float) -> void:
		for mark in marks:
			var row: Dictionary = mark
			if int(row.get("hp", 1)) > 0:
				continue
			var cog: Variant = row.get("cog")
			if _live(cog) and cog is Node and (cog as Node).has_method("play_lose"):
				(cog as Node).call("play_lose", elapsed)
		# MovieUtil deathSoundTrack. Cog_Death is the spin, then the crash.
		if elapsed >= 0.8 and _latch(gate, "spin"):
			_sfx("Cog_Death.ogg")
		if elapsed >= 5.0 and _latch(gate, "crash"):
			_sfx("ENC_cogfall_apart.ogg")
	)


## removeReviveSuit. The lose actor comes off and the same cog stands up as a Skelecog.
func _finish_revives(marks: Array) -> void:
	for mark in marks:
		var row: Dictionary = mark
		if not bool(row.get("revived", false)):
			continue
		var cog: Variant = row.get("cog")
		if _live(cog) and cog is Node and (cog as Node).has_method("finish_revive"):
			(cog as Node).call("finish_revive")


func _react_one(cog: Variant, key: String, elapsed: float) -> void:
	if _live(cog) and cog is Node and (cog as Node).has_method("begin_react"):
		(cog as Node).call("begin_react", key, elapsed)


func _rest(actor: ToonActor, marks: Array) -> void:
	for mark in marks:
		var row: Dictionary = mark
		var cog: Variant = row.get("cog")
		if _live(cog) and cog is Node and (cog as Node).has_method("begin_react") and int(row.get("hp", 1)) > 0:
			(cog as Node).call("begin_react", "", 0.0)
	if actor != null:
		actor.set_locomotion(0.0, false, false, 0.0)


## MovieTrap trapPoint (0, 5 - SUIT_TRAP_DISTANCE, 0.025) and heading 0.
## The exported track is still Panda: X runs along the rails, Z is up.
func _seat_track(prop: Node3D, cog: Node3D) -> void:
	var axes := _rail_axes(cog)
	var origin: Vector3 = axes["origin"]
	var forward: Vector3 = axes["forward"]
	var right: Vector3 = axes["right"]
	prop.reparent(self)
	prop.global_position = origin + forward * (5.0 - 2.6) + Vector3.UP * 0.025
	# Local Y is the track's width. Negating forward keeps the basis right-handed
	# so the rails face up instead of being culled.
	prop.global_basis = Basis(right, -forward, Vector3.UP)


func _rail_axes(cog: Node3D) -> Dictionary:
	var host := get_parent()
	if host != null and host.has_method("_battle_basis"):
		var fight: Variant = host.get("_fight")
		if fight is Dictionary and not (fight as Dictionary).is_empty():
			return host.call("_battle_basis", fight)
	var ahead := -_forward(cog)
	var right := Vector3.UP.cross(ahead)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var origin := cog.global_position - ahead * 5.0
	origin.y = cog.global_position.y
	return {"origin": origin, "forward": ahead, "right": right}


func _train_basis(track: Node3D) -> Basis:
	# MovieLure setH(90). The grill is the nose at -Y, so it points along +X.
	return track.global_basis * Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))


func _hide_tunnels(node: Node) -> void:
	_tunnel(node, false)


func _show_tunnels(node: Node) -> void:
	_tunnel(node, true)


func _tunnel(node: Node, shown: bool) -> void:
	var node_name := String(node.name)
	if node_name == "tunnel2" or node_name == "tunnel3":
		if node is Node3D:
			(node as Node3D).visible = shown
	for child in node.get_children():
		_tunnel(child, shown)


func _throw_trap(prop: Node3D, actor: ToonActor, cog: Node3D, level: int, elapsed: float) -> void:
	if level == 6:
		# The track stays hidden through the button press, then grows in at the battle point.
		if elapsed < 2.5:
			prop.visible = false
			return
		prop.visible = true
		_seat_track(prop, cog)
		prop.scale = Vector3.ONE * lerpf(0.1, 1.0, clampf((elapsed - 2.5) / 1.2, 0.0, 1.0))
		return
	var reach := _TRAP_REACH[clampi(level, 0, _TRAP_REACH.size() - 1)]
	var spot := cog.global_position + _forward(cog) * reach
	spot.y = cog.global_position.y + (0.4 if level == 5 else 0.05)
	if level >= 3 and level != 5:
		if elapsed < 2.5:
			prop.visible = false
			return
		prop.visible = true
		prop.reparent(self)
		prop.global_position = spot
		prop.scale = Vector3.ONE * lerpf(0.1, 1.0, clampf((elapsed - 2.5) / 1.2, 0.0, 1.0))
		return
	if elapsed < 2.3:
		var full := 0.7 if level == 1 else 1.0
		prop.scale = Vector3.ONE * lerpf(0.01, full, clampf(elapsed, 0.0, 1.0))
		return
	var duration := 0.9
	if level == 1:
		duration = 1.1
	elif level == 2:
		duration = 1.2
	if level == 0 and elapsed > 2.3 + duration:
		var slide := clampf((elapsed - 2.3 - duration) / 0.8, 0.0, 1.0)
		var land := cog.global_position + _forward(cog) * (reach + 2.0)
		land.y = spot.y
		prop.global_position = land.lerp(spot, slide)
		prop.rotation_degrees = Vector3.ZERO
		return
	_arc(prop, spot, elapsed, 2.3, duration, false)
	if level == 1:
		prop.rotation_degrees = Vector3(-90.0, 63.43, 63.43)
	elif level == 5:
		prop.rotation_degrees = Vector3(90.0, 0.0, 0.0)


func _fly_cake(pie: Node3D, marks: Array, elapsed: float) -> void:
	# The tiers leave the cake on the first frame. Remember that split, or the
	# next frame treats the empty cake as a model with no parts and the tiers
	# are never freed.
	if not pie.has_meta("cake_flight"):
		pie.set_meta("cake_flight", _cake_flight(pie, marks.size()))
	var flight: Array = pie.get_meta("cake_flight")
	for index in mini(marks.size(), flight.size()):
		var mark: Dictionary = marks[index]
		var cog := _node3d(mark.get("cog"))
		var missed := not bool(mark.get("hit", false))
		var group: Array = flight[index]
		for item in group:
			var piece := _node3d(item)
			if piece != null:
				_fly(piece, cog, _HEIGHT if not missed else _HEIGHT * 1.3, elapsed, 2.7, 0.3 if not missed else 0.45, missed, missed)


func _cake_flight(pie: Node3D, count: int) -> Array:
	var flight: Array = []
	var parts := _cake_parts(pie)
	if parts.is_empty():
		var copies: Array[Node3D] = [pie]
		for index in range(1, count):
			copies.append(_make("wedding-cake"))
		for copy in copies:
			flight.append([copy])
		return flight
	var groups := _cake_groups(parts, count)
	for group in groups:
		var flying: Array = []
		for item in group:
			var piece := _node3d(item)
			if piece == null:
				continue
			# reparentCakePart moves a tier onto the battle. removeProps deletes
			# it with the other spawned props, so it has to be tracked there.
			if not _spawned.has(piece):
				_spawned.append(piece)
			flying.append(piece)
		flight.append(flying)
	return flight


func _hide_cake_hits(pie: Node3D, marks: Array) -> void:
	if not pie.has_meta("cake_flight"):
		return
	var flight: Array = pie.get_meta("cake_flight")
	for index in mini(marks.size(), flight.size()):
		if not bool((marks[index] as Dictionary).get("hit", false)):
			continue
		var group: Array = flight[index]
		for item in group:
			var piece := _node3d(item)
			if piece != null:
				piece.visible = false


func _cake_parts(pie: Node3D) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for part_name in ["cake1", "cake2", "cake3", "caketop"]:
		var part := pie.find_child(part_name, true, false)
		if part is Node3D:
			found.append(part as Node3D)
	return found


func _cake_groups(parts: Array[Node3D], count: int) -> Array:
	if count <= 1 or parts.size() < 4:
		return [parts]
	if count == 2:
		return [[parts[0], parts[1]], [parts[2], parts[3]]]
	if count == 3:
		return [[parts[0], parts[1]], [parts[2]], [parts[3]]]
	return [[parts[0]], [parts[1]], [parts[2]], [parts[3]]]


func _arc(prop: Node3D, target: Vector3, elapsed: float, leave: float, duration: float, miss: bool) -> void:
	if not prop.has_meta("from"):
		var at := prop.global_position
		var grown := prop.scale
		prop.reparent(self)
		prop.global_position = at
		prop.scale = grown
		prop.set_meta("from", at)
		prop.set_meta("grown", grown)
	var start: Vector3 = prop.get_meta("from")
	var finish := target
	if miss:
		finish = start + (target - start) * 1.5
	var flight := maxf(duration, 0.05)
	var flown := clampf((elapsed - leave) / flight, 0.0, 1.0)
	var time := flown * flight
	var velocity := (finish.y - start.y - 0.5 * -32.144 * flight * flight) / flight
	var pos := start.lerp(finish, flown)
	pos.y = start.y + velocity * time + 0.5 * -32.144 * time * time
	prop.global_position = pos
	if miss and flown > 0.7:
		var grown: Vector3 = prop.get_meta("grown") if prop.has_meta("grown") else Vector3.ONE
		prop.scale = grown * maxf(1.0 - (flown - 0.7) / 0.3, 0.01)


func _pixie(actor: ToonActor, beats: Array, actor_of: Callable, elapsed: float) -> void:
	if elapsed < 1.5:
		return
	var dust: Node3D = actor.get_meta("pixie") if actor.has_meta("pixie") else null
	if dust == null:
		dust = _make("splat")
		_tint(dust, Color(0.65, 1.0, 0.75, 0.85))
		actor.set_meta("pixie", dust)
	var patient: Node3D = actor
	for item in beats:
		if item is Dictionary and bool((item as Dictionary).get("hit", false)):
			var found: ToonActor = actor_of.call(int((item as Dictionary).get("toon_id", (item as Dictionary).get("toon", 0))))
			if found != null:
				patient = found
				break
	var flown := clampf((elapsed - 1.5) / 1.9, 0.0, 1.0)
	var end := patient.global_position + Vector3(0.0, 2.2, 0.0)
	dust.global_position = actor.global_position.lerp(end, flown) + Vector3(0.0, sin(flown * PI) * 1.2, 0.0)
	dust.scale = Vector3.ONE * lerpf(0.12, 0.5, flown)
	_face_camera(dust)


func _drop_hop(age: float) -> float:
	if age <= 0.0:
		return 0.0
	if age < 0.15:
		return sin(age / 0.15 * PI) * 0.5
	if age < 0.3:
		return sin((age - 0.15) / 0.15 * PI) * 0.2
	return 0.0


func _forward(cog: Node3D) -> Vector3:
	var forward := -cog.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		return Vector3(0.0, 0.0, -1.0)
	return forward.normalized()


func _first_victim(victims: Array, actor_of: Callable) -> ToonActor:
	for item in victims:
		if item is Dictionary:
			var actor: ToonActor = actor_of.call(int((item as Dictionary).get("id", 0)))
			if actor != null:
				return actor
	return null


func _fly(prop: Node3D, aim: Node3D, height: float, elapsed: float, leave: float, flight: float, miss: bool, shrink: bool = false) -> void:
	if not prop.has_meta("from"):
		var at := prop.global_position
		prop.reparent(self)
		prop.global_position = at
		prop.scale = Vector3.ONE
		prop.set_meta("from", at)
	if aim == null:
		return
	var start: Vector3 = prop.get_meta("from")
	var target := aim.global_position + Vector3(0.0, height, 0.0)
	if miss:
		target = start + (target - start) * 1.5
	var flown := clampf((elapsed - leave) / maxf(flight, 0.05), 0.0, 1.0)
	prop.global_position = start.lerp(target, flown)
	if shrink:
		var faded := 0.0 if flown < 0.7 else (flown - 0.7) / 0.3
		prop.scale = Vector3.ONE * maxf(1.0 - faded, 0.01)


func _run(length: float, still: Callable, step: Callable) -> void:
	var elapsed := 0.0
	while elapsed < length:
		if not still.call():
			return
		# A chorus clock owns the camera. Each toon's clip would otherwise snap it back.
		if not _chording:
			_aim_time = elapsed
		step.call(elapsed)
		await get_tree().process_frame
		if not is_inside_tree():
			return
		elapsed += get_process_delta_time()
	if still.call():
		step.call(length)


func _wait(length: float, still: Callable) -> void:
	await _run(length, still, func(_elapsed: float) -> void:
		pass)


func _begin_camera(lead: Dictionary, actor: ToonActor, marks: Array) -> void:
	var kind := String(lead.get("kind", ""))
	var track := int(lead.get("track", -1))
	var level := int(lead.get("level", 0))
	var many := marks.size() > 1
	var seed := absi(int(lead.get("toon", 1)) * 13 + int(lead.get("cog", 1)) * 17 + track * 19 + level * 23 + int(lead.get("hp", 0)))
	_aiming = true
	_aim_time = 0.0
	_aim_actor = actor
	_aim_cog = _first_cog(marks)
	_aim_flip = 1.0 if seed % 2 == 0 else -1.0
	_aim_open = 3.0
	_aim_open_name = "group_low"
	_aim_close_name = "group_low"
	_aim_open_on = "battle"
	_aim_close_on = "battle"
	if kind == "cog":
		_aim_open = 2.8
		_aim_open_name = "throw_close"
		_aim_open_on = "cog"
		_aim_close_name = "three_left"
		_aim_close_on = "toon"
		return
	if track == 0:
		if level >= 6:
			_aim_open = 9.0
			return
		_aim_open = 2.8
		_aim_open_name = "toon_group"
		_aim_close_name = "toon_group"
		return
	if track == 1 or track == 2:
		if track == 2 and _train_trap():
			_aim_close_name = "behind_high_right"
			_aim_close_on = "toon"
		return
	if track == 3:
		_aim_open = 5.0 if level >= 6 else 3.1
		if many:
			_aim_open_name = "group_low" if seed % 2 == 0 else "suit_behind"
			_aim_close_name = "suit_behind" if seed % 2 == 0 else "group_low"
			return
		var sound_open: Array[String] = []
		sound_open.assign(["three_wide", "group_low", "suit_behind"] if level >= 6 else ["three_right", "group_low", "suit_behind"])
		_assign_shot(true, sound_open[seed % sound_open.size()], "toon")
		var sound_close: Array[String] = ["throw_close", "three_left", "group_low", "suit_behind"]
		_assign_shot(false, sound_close[(seed / 5) % sound_close.size()], "cog")
		return
	if many:
		_aim_open_name = "group_low" if seed % 2 == 0 else "suit_behind"
		_aim_close_name = "suit_behind" if seed % 2 == 0 else "group_low"
		return
	var opens: Array[String] = ["throw_close", "three_right", "behind", "group_low", "suit_behind"]
	_assign_shot(true, opens[seed % opens.size()], "toon")
	var closes: Array[String] = ["throw_close", "three_left", "group_low", "suit_behind"]
	_assign_shot(false, closes[(seed / 5) % closes.size()], "cog")


func _assign_shot(opening: bool, name: String, actor_on: String) -> void:
	var shot: Dictionary = _SHOTS.get(name, {})
	var on := actor_on if bool(shot.get("rel", false)) else "battle"
	if opening:
		_aim_open_name = name
		_aim_open_on = on
	else:
		_aim_close_name = name
		_aim_close_on = on


func _train_trap() -> bool:
	for key in _traps.keys():
		var record: Dictionary = _traps[key]
		if int(record.get("level", -1)) >= 6:
			return true
	return false


func _squirt_when(level: int) -> Dictionary:
	# MovieSquirt starts the spray on a frame of the toon clip. Clips are 24fps.
	if level == 1:
		return {"clip": "spit", "spray": 82.0 / 24.0, "hold": 0.2, "dodge": 82.0 / 24.0 - 0.5, "sound": 1.7}
	if level == 2:
		return {"clip": "water-gun", "spray": 48.0 / 24.0, "hold": 0.4, "dodge": 1.1, "sound": 1.8}
	if level == 3:
		var spray := 53.0 / 24.0 + 0.05
		return {"clip": "hold-bottle", "spray": spray, "hold": 0.2, "dodge": maxf(spray + 0.1 - 0.7, 0.0), "sound": spray - 0.1}
	return {"clip": "firehose", "spray": 2.8, "hold": 2.0, "dodge": 2.1, "sound": 2.8}


func _shadow() -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 1.0)
	mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.0, 0.0, 0.0, 0.45)
	mesh.material_override = mat
	mesh.visible = false
	mesh.set_meta("gag_owner", _make_owner)
	add_child(mesh)
	_spawned.append(mesh)
	return mesh


## MovieDrop.posObject. Small drops sit at shoulder height. The clip itself falls.
func _drop_root(cog: Node3D, level: int, missed: bool) -> Vector3:
	var rest := cog.global_position
	if missed and level >= 3:
		rest += _forward(cog) * 5.0
	var lift := 0.0
	if level <= 1:
		lift += 0.75
	if level < 3 and not missed:
		var body := "c"
		if "body" in cog:
			body = String(cog.body)
		var shoulder := 2.505
		if body == "a":
			shoulder = 3.32
		elif body == "b":
			shoulder = 3.435
		lift += shoulder * cog.scale.y
	rest.y += lift
	return rest


func _prop_frames(clip_name: String) -> int:
	return int(_prop_source(clip_name).get("frames", 0))


## Play a BattleProps actor channel. Joints carry the drop and the splat.
## A few props, the peel and the hose, move their vertices instead.
func _pose_prop(prop: Node3D, clip_name: String, elapsed: float) -> void:
	if prop == null or clip_name == "":
		return
	var bank: Dictionary = prop.get_meta("prop_bank", {}) if prop.has_meta("prop_bank") else {}
	if String(bank.get("clip", "")) != clip_name:
		bank = _bind_prop(prop, clip_name)
		prop.set_meta("prop_bank", bank)
	var frames := int(bank.get("frames", 0))
	if frames <= 1:
		return
	var time := clampf(elapsed * 24.0, 0.0, float(frames - 1))
	var frame := mini(int(time), frames - 1)
	var following := mini(frame + 1, frames - 1)
	var blend := 0.0 if following == frame else time - float(frame)
	for item in bank.get("joints", []):
		var record: Dictionary = item
		var node := record.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		node.transform = _prop_matrix(_blended_cells(record["frames"] as Array, frame, following, blend))
	for item in bank.get("meshes", []):
		var record: Dictionary = item
		var instance := record.get("instance") as MeshInstance3D
		if instance == null or not is_instance_valid(instance):
			continue
		var posed := _prop_surface(record, frame, following, blend)
		if posed != null and instance.mesh != posed:
			instance.mesh = posed


func _bind_prop(prop: Node3D, clip_name: String) -> Dictionary:
	var source := _prop_source(clip_name)
	var bank := {"clip": clip_name, "frames": int(source.get("frames", 0)), "joints": [], "meshes": []}
	for item in source.get("joints", []):
		var record: Dictionary = item
		var node := prop.find_child(String(record.get("name", "")), true, false) as Node3D
		if node == null:
			continue
		bank["joints"].append({"node": node, "frames": record["frames"]})
	for item in source.get("meshes", []):
		var record: Dictionary = item
		var mesh := _mesh_under(prop, String(record.get("parent", "")))
		if mesh == null:
			continue
		var poses: Array = []
		poses.resize(int(source.get("frames", 0)))
		bank["meshes"].append({
			"instance": mesh,
			"original": mesh.mesh,
			"surfaces": record["surfaces"],
			"bytes": record["bytes"],
			"poses": poses,
		})
	return bank


func _mesh_under(prop: Node, parent_name: String) -> MeshInstance3D:
	var parent := prop.find_child(parent_name, true, false)
	if parent == null:
		return null
	for child in parent.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			return child as MeshInstance3D
	if parent is MeshInstance3D and (parent as MeshInstance3D).mesh != null:
		return parent as MeshInstance3D
	return null


func _prop_source(clip_name: String) -> Dictionary:
	if _prop_sources.has(clip_name):
		return _prop_sources[clip_name]
	var parsed := _parse_prop(_PROPS + clip_name + ".walk")
	_prop_sources[clip_name] = parsed
	return parsed


func _parse_prop(path: String) -> Dictionary:
	var empty := {"frames": 0, "joints": [], "meshes": []}
	if not FileAccess.file_exists(path):
		return empty
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 16 or bytes.slice(0, 6).get_string_from_ascii() != "TWALK3":
		return empty
	var at := 8
	var frame_count := bytes.decode_u32(at)
	at += 4
	var node_count := bytes.decode_u32(at)
	at += 4
	var meshes: Array = []
	for _node_index in node_count:
		var name_len := bytes.decode_u16(at)
		at += 2
		var parent_name := bytes.slice(at, at + name_len).get_string_from_utf8()
		at += name_len
		var surface_count := bytes.decode_u32(at)
		at += 4
		var surfaces: Array = []
		for _surface_index in surface_count:
			var vertex_count := bytes.decode_u32(at)
			at += 4
			var has_uv := bytes.decode_u8(at)
			at += 1
			var uvs := PackedVector2Array()
			if has_uv != 0:
				uvs.resize(vertex_count)
				for index in vertex_count:
					var u := bytes.decode_float(at)
					at += 4
					var v := bytes.decode_float(at)
					at += 4
					uvs[index] = Vector2(u, v)
			var base := at
			at += frame_count * vertex_count * 12
			surfaces.append({"uv": uvs, "verts": vertex_count, "base": base})
		meshes.append({"parent": parent_name, "surfaces": surfaces, "bytes": bytes})
	var joints: Array = []
	if at + 4 <= bytes.size():
		var joint_count := bytes.decode_u32(at)
		at += 4
		for _joint_index in joint_count:
			if at + 2 > bytes.size():
				break
			var name_len := bytes.decode_u16(at)
			at += 2
			var joint_name := bytes.slice(at, at + name_len).get_string_from_utf8()
			at += name_len
			at += 64
			var frames: Array = []
			frames.resize(frame_count)
			for frame in frame_count:
				var cells := PackedFloat32Array()
				cells.resize(16)
				for cell in 16:
					cells[cell] = bytes.decode_float(at)
					at += 4
				frames[frame] = cells
			joints.append({"name": joint_name, "frames": frames})
	return {"frames": frame_count, "joints": joints, "meshes": meshes}


func _blended_cells(frames: Array, frame: int, following: int, blend: float) -> PackedFloat32Array:
	var current: PackedFloat32Array = frames[frame]
	if blend <= 0.001 or following == frame:
		return current
	var nxt: PackedFloat32Array = frames[following]
	var mixed := PackedFloat32Array()
	mixed.resize(16)
	for index in 16:
		mixed[index] = lerpf(current[index], nxt[index], blend)
	return mixed


## Keep the scale in the basis. Orthonormalizing would flatten the anvil and the splat.
func _prop_matrix(cells: PackedFloat32Array) -> Transform3D:
	return Transform3D(Basis(
		Vector3(cells[0], cells[1], cells[2]),
		Vector3(cells[4], cells[5], cells[6]),
		Vector3(cells[8], cells[9], cells[10])
	), Vector3(cells[12], cells[13], cells[14]))


func _prop_surface(record: Dictionary, frame: int, following: int, blend: float) -> ArrayMesh:
	var poses: Array = record["poses"]
	var posed: ArrayMesh = null
	if frame < poses.size():
		posed = poses[frame] as ArrayMesh
	if posed == null:
		posed = _build_prop_mesh(record, frame)
		if frame < poses.size():
			poses[frame] = posed
	if blend <= 0.001 or following == frame or posed == null:
		return posed
	var nxt := poses[following] as ArrayMesh
	if nxt == null:
		nxt = _build_prop_mesh(record, following)
		if following < poses.size():
			poses[following] = nxt
	if nxt == null:
		return posed
	return _blend_prop_mesh(posed, nxt, blend)


func _build_prop_mesh(record: Dictionary, frame: int) -> ArrayMesh:
	var bytes: PackedByteArray = record["bytes"]
	var original: Mesh = record.get("original") as Mesh
	var mesh := ArrayMesh.new()
	var surfaces: Array = record["surfaces"]
	for surface_index in surfaces.size():
		var surface: Dictionary = surfaces[surface_index]
		var count := int(surface["verts"])
		var base := int(surface["base"]) + frame * count * 12
		var positions := PackedVector3Array()
		positions.resize(count)
		var at := base
		for index in count:
			positions[index] = Vector3(bytes.decode_float(at), bytes.decode_float(at + 4), bytes.decode_float(at + 8))
			at += 12
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = positions
		arrays[Mesh.ARRAY_NORMAL] = _face_normals(positions)
		var uvs: PackedVector2Array = surface["uv"]
		if uvs.size() == count:
			arrays[Mesh.ARRAY_TEX_UV] = uvs
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if original != null and surface_index < original.get_surface_count():
			mesh.surface_set_material(surface_index, original.surface_get_material(surface_index))
	return mesh


func _blend_prop_mesh(current: ArrayMesh, nxt: ArrayMesh, blend: float) -> ArrayMesh:
	var mixed := ArrayMesh.new()
	for index in current.get_surface_count():
		var left: Array = current.surface_get_arrays(index)
		var right: Array = nxt.surface_get_arrays(index)
		var positions: PackedVector3Array = left[Mesh.ARRAY_VERTEX]
		var next_positions: PackedVector3Array = right[Mesh.ARRAY_VERTEX]
		var blended := PackedVector3Array()
		blended.resize(positions.size())
		for vertex in positions.size():
			blended[vertex] = positions[vertex].lerp(next_positions[vertex], blend)
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = blended
		arrays[Mesh.ARRAY_NORMAL] = _face_normals(blended)
		arrays[Mesh.ARRAY_TEX_UV] = left[Mesh.ARRAY_TEX_UV]
		mixed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mixed.surface_set_material(index, current.surface_get_material(index))
	return mixed


func _face_normals(positions: PackedVector3Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(positions.size())
	var index := 0
	while index + 2 < positions.size():
		var edge := (positions[index + 1] - positions[index]).cross(positions[index + 2] - positions[index])
		var normal := edge.normalized() if edge.length_squared() > 0.000001 else Vector3.UP
		normals[index] = normal
		normals[index + 1] = normal
		normals[index + 2] = normal
		index += 3
	return normals


func _prop_name(track: int, level: int) -> String:
	if track < 0 or track >= _GAGS.size():
		return "tart"
	var row: Array = _GAGS[track]
	if level < 0 or level >= row.size():
		return "tart"
	return String(row[level])


func _make(prop_name: String) -> Node3D:
	var wrap := Node3D.new()
	wrap.name = prop_name
	wrap.set_meta("gag_owner", _make_owner)
	add_child(wrap)
	_spawned.append(wrap)
	var path := _PROPS + prop_name + ".glb"
	if not ResourceLoader.exists(path):
		return wrap
	var packed := load(path) as PackedScene
	if packed == null:
		return wrap
	var model := packed.instantiate()
	wrap.add_child(model)
	return wrap


func _instrument_seat(level: int) -> Dictionary:
	# MovieSound setInstrumentStats. The instrument shares the megaphone's right hand.
	match level:
		0:
			return {"pos": Vector3(-1.1, -1.4, 0.1), "hpr": Vector3(145.0, 0.0, 0.0)}
		1:
			return {"pos": Vector3(-1.2, -1.3, 0.1), "hpr": Vector3(145.0, 0.0, 85.0)}
		2:
			return {"pos": Vector3(-1.3, -1.4, 0.1), "hpr": Vector3(145.0, 0.0, 85.0)}
		3:
			return {"pos": Vector3(-1.0, -1.5, 0.2), "hpr": Vector3(145.0, 0.0, 85.0)}
		4:
			return {"pos": Vector3(-0.6, -0.9, 0.15), "hpr": Vector3(145.0, 0.0, 85.0)}
		5:
			return {"pos": Vector3(-0.8, -0.9, 0.2), "hpr": Vector3(145.0, 0.0, 0.0)}
		_:
			return {"pos": Vector3(-1.04, -1.17, 0.26), "hpr": Vector3(145.0, 0.0, 90.0)}


func _attack_rows(title: String, body: String, code: String) -> Array:
	var right := "joint_Rhold"
	var left := "joint_Lhold"
	var one := Vector3.ONE
	match title:
		"Pound Key!", "Hang Up!":
			return [
				_prop_row("phone", left, Vector3(0.23, 0.17, -0.11), Vector3(5.939, 2.763, -177.591), one, false),
				_prop_row("receiver", left, Vector3(0.23, 0.17, -0.11), Vector3(5.939, 2.763, -177.591), one, false),
			]
		"Shred!":
			return [
				_prop_row("shredder", left, Vector3(0.0, -0.12, -0.34), Vector3(-90.0, -53.77, 0.0), Vector3(4.81, 4.81, 4.81), false),
				_prop_row("shredder-paper", right, Vector3(0.59, -0.31, 0.81), Vector3(79.224, 32.576, -179.449), one, false),
			]
		"Fountain Pen!":
			return [_prop_row("pen", right, Vector3.ZERO, Vector3.ZERO, Vector3(1.5, 1.5, 1.5), false)]
		"Fill With Lead!":
			return [
				_prop_row("pencil", right, Vector3(-0.29, -0.33, -0.13), Vector3(160.565, -11.653, -169.244), one, false),
				_prop_row("sharpener", left, Vector3(0.0, 0.0, -0.03), Vector3.ZERO, one, false),
			]
		"Write Off!", "Rub Out!":
			return [
				_prop_row("pad", left, Vector3(-0.66, 0.81, -0.06), Vector3(14.93, -2.29, 180.0), one, false),
				_prop_row("pencil", right, Vector3(0.04, -0.38, -0.1), Vector3(-170.223, -3.762, -62.929), one, false),
			]
		"Rubber Stamp!":
			if body == "c":
				return [
					_prop_row("pad", left, Vector3(0.19, -0.55, -0.21), Vector3(-166.76, -4.001, -1.658), one, false),
					_prop_row("rubber-stamp", right, Vector3(-0.64, -0.08, 0.11), Vector3.ZERO, one, false),
				]
			return [
				_prop_row("pad", left, Vector3(-0.65, 0.83, -0.04), Vector3(5.625, 4.456, -165.125), one, false),
				_prop_row("rubber-stamp", right, Vector3(-0.64, -0.17, -0.03), Vector3.ZERO, one, false),
			]
		"Razzle Dazzle!":
			return [_prop_row("smile", right, Vector3(0.0, -0.42, -0.04), Vector3(105.715, 73.977, 65.932), Vector3(1.39, 1.39, 1.39), false)]
		"Tee Off!":
			var ball_x := 2.1
			if code == "tbc":
				ball_x = 4.1
			elif code == "m":
				ball_x = 3.2
			elif code == "rb":
				ball_x = 4.2
			return [
				_prop_row("golf-club", left, Vector3.ZERO, Vector3(63.097, 43.988, -18.435), Vector3(1.1, 1.1, 1.1), false),
				_prop_row("golf-ball", "Suit", Vector3(ball_x, 0.0, 0.1), Vector3.ZERO, Vector3(1.5, 1.5, 1.5), true),
			]
		"Rolodex!":
			if body == "b":
				return [_prop_row("rollodex", left, Vector3(0.12, 0.24, 0.01), Vector3(99.032, 5.973, -179.839), Vector3(0.91, 0.91, 0.91), false)]
			return [_prop_row("rollodex", left, Vector3(-0.51, -0.03, -0.1), Vector3(89.673, 2.166, 177.786), Vector3(1.2, 1.2, 1.2), false)]
		"Evil Eye!":
			return [_prop_row("evil-eye", "Suit", Vector3(-0.4, 3.65, 5.01), Vector3(-155.0, -20.0, 0.0), Vector3(11.0, 11.0, 11.0), false)]
		"Watercooler!":
			return [_prop_row("watercooler", left, Vector3(0.48, 0.11, -0.92), Vector3(20.403, 33.158, 69.511), Vector3(1.15, 1.15, 1.15), false)]
		"Glower Power!":
			return [
				_prop_row("dagger", "Suit", Vector3(0.4, 3.8, 3.7), Vector3.ZERO, Vector3(0.4, 0.4, 0.4), false),
				_prop_row("dagger", "Suit", Vector3(-0.4, 3.8, 3.7), Vector3.ZERO, Vector3(0.4, 0.4, 0.4), false),
			]
		"Audit!", "Calculate!", "Tabulate!", "Crunch!":
			return [_prop_row("calculator", left, Vector3(0.35, 0.52, 0.03), Vector3(1.352, -6.518, -6.045), Vector3(1.0, 1.37, 1.31), false)]
		"Clip On Tie!":
			return [_prop_row("clip-on-tie", right, Vector3(0.66, 0.51, 0.28), Vector3(-69.652, -17.199, 67.96), one, true)]
		"Canned!":
			return [_prop_row("can", right, Vector3(-0.14, 0.15, 0.08), Vector3(-10.584, 11.945, -161.684), Vector3(6.0, 6.0, 6.0), true)]
		"Pink Slip!":
			return [_prop_row("pink-slip", right, Vector3(0.07, -0.06, -0.18), Vector3(-172.075, -26.715, -89.131), Vector3(8.0, 8.0, 8.0), true)]
		"Sacked!":
			return [_prop_row("sandbag", right, Vector3(0.51, -2.03, -0.73), Vector3(90.0, -24.98, 77.73), Vector3(0.65, 1.47, 1.28), true)]
		"Half Windsor!":
			return [_prop_row("half-windsor", right, Vector3(0.02, 0.88, 0.48), Vector3(99.0, -3.0, -108.2), Vector3(7.0, 7.0, 7.0), true)]
		"Play Hardball!":
			return [_prop_row("baseball", right, Vector3(0.04, 0.03, -0.31), Vector3(-1.152, 86.581, -76.784), Vector3(5.0, 5.0, 5.0), true)]
		"Power Tie!":
			return [_prop_row("power-tie", right, Vector3(1.16, 0.24, 0.63), Vector3(171.561, 1.745, -163.443), Vector3(3.5, 3.5, 3.5), true)]
		"Pick Pocket!":
			return [_prop_row("1dollar", right, Vector3(-0.01, 0.45, -0.25), Vector3(136.424, -46.434, -129.712), Vector3(1.41, 1.41, 1.41), false)]
		"Red Tape!":
			var tape_x := -0.24 if code == "tf" or code == "nc" else 0.24
			return [_prop_row("redtape", right, Vector3(tape_x, 0.09, -0.38), Vector3(-1.152, 86.581, -76.784), Vector3(0.9, 0.9, 0.24), true)]
		"Bounce Check!":
			return [_prop_row("bounced-check", right, Vector3.ZERO, Vector3(95.247, 79.025, 88.849), Vector3(8.5, 8.5, 8.5), true)]
		"Market Crash!":
			return [_prop_row("newspaper", right, Vector3(-0.07, 0.17, -0.13), Vector3(161.867, -33.149, -48.086), Vector3(3.0, 3.0, 3.0), true)]
		"Bite!", "Chomp!":
			return [_prop_row("teeth", right, Vector3(-0.05, 0.41, -0.54), Vector3(4.465, -3.563, 51.479), Vector3(3.0, 3.0, 3.0), true)]
		"Eviction Notice!", "Restraining Order!":
			return [_prop_row("shredder-paper", right, Vector3(-0.04, 0.15, -1.38), Vector3(10.584, -11.945, 18.316), one, true)]
		"Pecking Order!":
			return [_prop_row("bird", right, Vector3.ZERO, Vector3.ZERO, Vector3(9.0, 9.0, 9.0), true)]
		"Cigar Smoke!":
			return [_prop_row("cigar", right, Vector3.ZERO, Vector3.ZERO, one, false)]
		"Throw Book!":
			return [_prop_row("lawbook", right, Vector3.ZERO, Vector3.ZERO, one, true)]
		_:
			return []


func _prop_row(prop_name: String, joint_name: String, pos: Vector3, hpr: Vector3, grow: Vector3, thrown: bool) -> Dictionary:
	return {"prop": prop_name, "joint": joint_name, "pos": pos, "hpr": hpr, "grow": grow, "thrown": thrown}


func _hips(actor: Node) -> Node3D:
	var hips := _joint(actor, "def_joint_hips")
	if hips == null:
		hips = _joint(actor, "joint_hips")
	return hips


func _seat(prop: Node3D, host: Node, joint_name: String, pos: Vector3, hpr: Vector3, grow: Vector3) -> void:
	var joint: Node3D = null
	if joint_name == "Suit":
		joint = host.get_node_or_null("Suit") as Node3D
		if joint == null:
			joint = host as Node3D
	elif joint_name == "":
		joint = host as Node3D
	else:
		joint = _joint(host, joint_name)
	if joint == null:
		prop.reparent(host)
		return
	prop.reparent(joint, false)
	prop.position = pos
	prop.basis = _panda_hpr(hpr.x, hpr.y, hpr.z)
	prop.scale = Vector3(0.01, 0.01, 0.01)
	prop.set_meta("grow", grow)


## Panda setHpr in the joint's Z-up space: heading about Z, pitch about X, roll about Y.
func _panda_hpr(heading: float, pitch: float, roll: float) -> Basis:
	var turn := Quaternion(Vector3(0, 0, 1), deg_to_rad(heading))
	var tilt := Quaternion(Vector3(1, 0, 0), deg_to_rad(pitch))
	var twist := Quaternion(Vector3(0, 1, 0), deg_to_rad(roll))
	return Basis(twist * tilt * turn)


func _hand(prop: Node3D, actor: Node3D, joint_name: String) -> void:
	var joint := _joint(actor, joint_name)
	if joint == null:
		prop.reparent(actor)
		prop.position = Vector3(0.2, 1.4, 0.4)
	else:
		prop.reparent(joint, false)
		prop.transform = Transform3D.IDENTITY
	prop.scale = Vector3(0.01, 0.01, 0.01)


func _on_joint(prop: Node3D, host: Node, joint_name: String, pose_name: String) -> void:
	var joint := _joint(host, joint_name)
	if joint == null:
		prop.reparent(host)
		return
	prop.reparent(joint, false)
	prop.transform = _pose(pose_name)
	prop.scale = Vector3.ONE


func _pose(pose_name: String) -> Transform3D:
	var data: Variant = _attach.get(pose_name, {})
	if not data is Dictionary:
		return Transform3D.IDENTITY
	var record: Dictionary = data
	var origin: Array = record.get("origin", [0, 0, 0])
	var x: Array = record.get("x", [1, 0, 0])
	var y: Array = record.get("y", [0, 1, 0])
	var z: Array = record.get("z", [0, 0, 1])
	if origin.size() < 3 or x.size() < 3 or y.size() < 3 or z.size() < 3:
		return Transform3D.IDENTITY
	return Transform3D(Basis(
		Vector3(float(x[0]), float(x[1]), float(x[2])),
		Vector3(float(y[0]), float(y[1]), float(y[2])),
		Vector3(float(z[0]), float(z[1]), float(z[2]))
	), Vector3(float(origin[0]), float(origin[1]), float(origin[2])))


func _joint(host: Node, joint_name: String) -> Node3D:
	if host == null:
		return null
	return host.find_child(joint_name, true, false) as Node3D


func _spray(spray: Node3D, from_world: Vector3, to_world: Vector3, level: int) -> void:
	var dir := to_world - from_world
	var distance := dir.length()
	if distance < 0.05:
		spray.visible = false
		return
	spray.reparent(self)
	# look_at aims local -Z. This mesh's stream is local +Y, so aim that at the cog.
	var forward := dir / distance
	var up := Vector3.UP
	if absf(forward.dot(up)) > 0.98:
		up = Vector3.FORWARD
	var side := up.cross(forward).normalized()
	up = forward.cross(side).normalized()
	spray.global_basis = Basis(side, forward, up)
	spray.global_position = from_world
	var reach := distance / _SPRAY_LEN
	var thick := _SPRAY_SCALE[clampi(level, 0, _SPRAY_SCALE.size() - 1)]
	spray.scale = Vector3(reach * thick, reach, reach * thick)


func _face_camera(node: Node3D) -> void:
	if node == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	# setBillboardPointWorld. The splat card lies in local XZ, front toward local -Y, up local +Z.
	var to_cam := camera.global_position - node.global_position
	if to_cam.length_squared() < 0.0001:
		return
	to_cam = to_cam.normalized()
	var up := Vector3.UP
	if absf(to_cam.dot(up)) > 0.98:
		up = Vector3.FORWARD
	var right := up.cross(to_cam).normalized()
	var kept := node.scale
	node.global_basis = Basis(right, -to_cam, right.cross(-to_cam).normalized())
	node.scale = kept


func _tint(node: Node, color: Color, textured := false) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var tint := StandardMaterial3D.new()
		tint.albedo_color = color
		tint.cull_mode = BaseMaterial3D.CULL_DISABLED
		if textured:
			var source := mesh_node.get_active_material(0)
			if source is StandardMaterial3D:
				tint.albedo_texture = (source as StandardMaterial3D).albedo_texture
			# splat-mod is an alpha-mask card. setColor tints it; it does not replace the graphic.
			tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			tint.alpha_scissor_threshold = 0.5
			tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		else:
			tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh_node.material_override = tint


func _live(node: Variant) -> bool:
	return node != null and is_instance_valid(node)


## A freed cog is not null. Assigning it to a Node3D runs `is` and crashes.
func _node3d(value: Variant) -> Node3D:
	if _live(value) and value is Node3D:
		return value
	return null


func _first_cog(marks: Array) -> Node3D:
	for mark in marks:
		var cog: Variant = (mark as Dictionary).get("cog")
		if _live(cog) and cog is Node3D:
			return cog
	return null


func _any_hit(marks: Array) -> bool:
	for mark in marks:
		if bool((mark as Dictionary).get("hit", false)):
			return true
	return false


func _aside(actor: Node3D, cog: Node3D) -> Vector3:
	return _aside_from(actor.global_position, cog)


func _aside_from(origin: Vector3, cog: Node3D) -> Vector3:
	var away := cog.global_position - origin
	away.y = 0.0
	if away.length_squared() < 0.01:
		return Vector3.RIGHT
	return away.normalized().cross(Vector3.UP)


func _splat_color(pie_name: String) -> Color:
	if pie_name.begins_with("cream"):
		return Color(250.0 / 255.0, 241.0 / 255.0, 24.0 / 255.0)
	if pie_name == "birthday-cake" or pie_name == "wedding-cake":
		return Color(253.0 / 255.0, 119.0 / 255.0, 220.0 / 255.0)
	return Color(55.0 / 255.0, 40.0 / 255.0, 148.0 / 255.0)


func _splat_scale(pie_name: String) -> float:
	if pie_name == "tart":
		return 0.3
	if pie_name.ends_with("slice"):
		return 0.5
	if pie_name == "birthday-cake" or pie_name == "wedding-cake":
		return 0.9
	return 0.7


func _pie_hit(level: int) -> String:
	if level <= 0:
		return "AA_tart_only.ogg"
	if level >= 5:
		return "AA_wholepie_only.ogg"
	return "AA_slice_only.ogg"


func _once(id: String, elapsed: float, at: float, file_name: String, owner: int = 0) -> void:
	var key := "%d:%s" % [owner, id]
	if elapsed < at or bool(_fired.get(key, false)):
		return
	_fired[key] = true
	_sfx(file_name)


func _latch(gate: Dictionary, id: String) -> bool:
	if bool(gate.get(id, false)):
		return false
	gate[id] = true
	return true


func _sfx(file_name: String) -> void:
	var path := _SFX + file_name
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null:
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			stream = AudioStreamOggVorbis.load_from_buffer(file.get_buffer(file.get_length()))
	if stream == null:
		return
	var player := ToonAudio.effect_player()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _clear_owner(owner: int) -> void:
	if owner == 0:
		return
	var left: Array[Node] = []
	for node in _spawned:
		if is_instance_valid(node) and int(node.get_meta("gag_owner", 0)) == owner:
			node.queue_free()
		elif is_instance_valid(node):
			left.append(node)
	_spawned = left


func _clear_spawned() -> void:
	for item in _sprung:
		var record: Dictionary = item
		var node: Node = record.get("node")
		if node != null and is_instance_valid(node):
			node.queue_free()
	_sprung.clear()
	for node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()
