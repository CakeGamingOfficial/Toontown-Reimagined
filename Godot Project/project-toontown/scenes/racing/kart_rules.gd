extends RefCounted

## RaceGlobals, KartShopGlobals, and the kart-page strings the races share.
## A track id's low bit is the reverse curve of the same model.

const PRACTICE := 0
const BATTLE := 1
const CIRCUIT := 2
const MAX_RACERS := 4
const MAX_TICKETS := 99999
const MAX_ACCESSORIES := 16
const COUNTDOWN := 30.0
const ENTER_RACE := 6.0
const RACE_COUNTDOWN := 3
const SIGN_TIME := 15.0
const LAPS := 3
const BANANA := 1
const TURBO := 2
const ANVIL := 3
const PIE := 4

const _WINNINGS: Array[float] = [3.0, 1.0, 0.5, 0.15]
const PRACTICE_TICKETS := 20
const PERIOD_BONUS: Array[int] = [10, 100, 1000]
const QUAL_NEED: Array[int] = [1, 10, 100]
const WIN_NEED: Array[int] = [1, 10, 100]
const CIRCUIT_NEED: Array[int] = [1, 5, 25]

const TRACK_IDS: Array[int] = [0, 1, 20, 21, 40, 41, 60, 61, 62, 63, 64, 65]

const _GAG: Array = [
	[4, 1, 1, 1, 2, 4],
	[4, 1, 1, 2, 3, 4],
	[4, 1, 2, 2, 3, 4],
	[1, 2, 2, 2, 3, 4],
]

const _INFO := {
	0: "Welcome to Screwball Stadium!\nPut the pedal to the metal and hang on tight!\nUse Control to throw gags you pick up on the track, and the arrow keys to control your kart.",
	60: "Welcome to Corkscrew Coliseum!\nUse the banked turns to keep your speed up!\nUse Control to throw gags you pick up on the track, and the arrow keys to control your kart.",
	20: "Welcome to Rustic Raceway!\nPlease be kind to the fauna and stay on the track!\nUse Control to throw gags you pick up on the track, and the arrow keys to control your kart.",
	62: "Welcome to Airborne Acres!\nHold onto your hats! It looks bumpy up ahead...\nUse Control to throw gags you pick up on the track, and the arrow keys to control your kart.",
	40: "Welcome to City Circuit!\nWatch out for pedestrians as you speed through downtown!\nUse Control to throw gags you pick up on the track, and the arrow keys to control your kart.",
	64: "Welcome to Blizzard Boulevard!\nWatch your speed. There might be ice out there.\nUse Control to throw gags you pick up on the track, and the arrow keys to control your kart.",
}

# SuitBuilding-style rows: qualifying seconds, record seconds, battle fee, circuit fee, genre.
# Genre is 0 stadium, 1 country, 2 city. Panda points become Godot with (x, z, -y).
const _ROW := {
	0: [240.0, 115.0, 50, 500, 0, "GS_Race_SS.ogg", "speedway_a"],
	1: [240.0, 115.0, 50, 500, 0, "GS_Race_SS.ogg", "speedway_a"],
	60: [335.0, 210.0, 75, 1000, 0, "GS_Race_SS.ogg", "speedway_b"],
	61: [335.0, 210.0, 75, 1000, 0, "GS_Race_SS.ogg", "speedway_b"],
	20: [360.0, 230.0, 100, 500, 1, "GS_Race_RR.ogg", "rural_b"],
	21: [360.0, 230.0, 100, 500, 1, "GS_Race_RR.ogg", "rural_b"],
	62: [480.0, 360.0, 150, 1000, 1, "GS_Race_RR.ogg", "rural_b2"],
	63: [480.0, 360.0, 150, 1000, 1, "GS_Race_RR.ogg", "rural_b2"],
	40: [480.0, 305.0, 300, 500, 2, "GS_Race_CC.ogg", "urban_a"],
	41: [480.0, 305.0, 300, 500, 2, "GS_Race_CC.ogg", "urban_a"],
	64: [480.0, 280.0, 400, 1000, 2, "GS_Race_CC.ogg", "urban_b"],
	65: [480.0, 280.0, 400, 1000, 2, "GS_Race_CC.ogg", "urban_b"],
}

const _NAME := {
	0: "Screwball Stadium",
	1: "Screwball Stadium Rev",
	20: "Rustic Raceway",
	21: "Rustic Raceway Rev",
	40: "City Circuit",
	41: "City Circuit Rev",
	60: "Corkscrew Coliseum",
	61: "Corkscrew Coliseum Rev",
	62: "Airborne Acres",
	63: "Airborne Acres Rev",
	64: "Blizzard Boulevard",
	65: "Blizzard Boulevard Rev",
}

const RACE_NAMES: PackedStringArray = ["Practice", "Toon Battle", "Grand Prix"]
const PERIOD_NAMES: PackedStringArray = ["daily", "weekly", "all time"]
const GENRE_KEY: PackedStringArray = ["stadium", "country", "city"]

const _FORWARD := {
	0: [0, 60],
	1: [20, 62],
	2: [40, 64],
}
const _REVERSE := {
	0: [1, 61],
	1: [21, 63],
	2: [41, 65],
}


static func world(panda: Vector3) -> Vector3:
	return Vector3(panda.x, panda.z, -panda.y)


static func known(track_id: int) -> bool:
	return _ROW.has(track_id)


static func track_name(track_id: int) -> String:
	return String(_NAME.get(track_id, "Race"))


static func model_slug(track_id: int) -> String:
	var row: Array = _ROW.get(track_id, _ROW[0])
	return String(row[6])


static func reversed(track_id: int) -> bool:
	return track_id % 2 == 1


static func qualifying(track_id: int) -> float:
	return float((_ROW.get(track_id, _ROW[0]) as Array)[0])


static func record_time(track_id: int) -> float:
	return float((_ROW.get(track_id, _ROW[0]) as Array)[1])


static func genre(track_id: int) -> int:
	return int((_ROW.get(track_id, _ROW[0]) as Array)[4])


static func music_file(track_id: int) -> String:
	return String((_ROW.get(track_id, _ROW[0]) as Array)[5])


static func entry_fee(track_id: int, race_type: int) -> int:
	var row: Array = _ROW.get(track_id, _ROW[0])
	if race_type == BATTLE:
		return int(row[2])
	if race_type == CIRCUIT:
		return int(row[3])
	return 0


static func info_text(track_id: int) -> String:
	var base_id := track_id - (track_id % 2)
	if track_id == 61:
		base_id = 60
	elif track_id == 63:
		base_id = 62
	elif track_id == 65:
		base_id = 64
	elif track_id == 21:
		base_id = 20
	elif track_id == 41:
		base_id = 40
	elif track_id == 1:
		base_id = 0
	return String(_INFO.get(base_id, _INFO[0]))


static func drag(track_id: int) -> float:
	# DistributedVehicle.surfaceModifiers. Stadium is asphalt, country is dirt.
	var which := genre(track_id)
	if which == 1:
		return 0.3
	return 0.2


static func winnings_for(place: int, racers: int, fee: int, race_type: int, qualified: bool) -> int:
	if not qualified:
		return 0
	if race_type == PRACTICE:
		return PRACTICE_TICKETS
	var index := place - 1 + (MAX_RACERS - racers)
	index = clampi(index, 0, _WINNINGS.size() - 1)
	return int(float(fee) * _WINNINGS[index])


static func gag_type(place: int, roll: int) -> int:
	var row: Array = _GAG[clampi(place - 1, 0, _GAG.size() - 1)]
	return int(row[clampi(roll, 0, row.size() - 1)])


static func next_track(previous: int, genre_name: String, pad_index: int) -> Dictionary:
	# getNextRaceInfo. An unknown previous id starts on the second layout.
	var genre_id := 1
	if genre_name == "town":
		genre_id = 2
	elif genre_name == "stadium":
		genre_id = 0
	var canonical := posmod(pad_index, 4)
	var reverse := canonical == 1 or canonical == 3
	var race_type := BATTLE if canonical >= 2 else PRACTICE
	var pair: Array = (_REVERSE if reverse else _FORWARD)[genre_id]
	var track_id := int(pair[1])
	if pair.has(previous):
		var index := pair.find(previous) + 1
		track_id = int(pair[index % pair.size()])
	return {"track": track_id, "type": race_type, "laps": LAPS}


static func track_index(track_id: int) -> int:
	return TRACK_IDS.find(track_id)


static func bonus_for(period: int) -> int:
	return PERIOD_BONUS[clampi(period, 0, PERIOD_BONUS.size() - 1)]


static func qual_need(step: int) -> int:
	return QUAL_NEED[clampi(step, 0, 2)]


static func win_need(step: int) -> int:
	return WIN_NEED[clampi(step, 0, 2)]


static func circuit_need(step: int) -> int:
	return CIRCUIT_NEED[clampi(step, 0, 2)]


static func trophy_text(index: int) -> String:
	var hoods: PackedStringArray = ["Speedway", "Rural", "Urban"]
	if index < 9:
		var count := qual_need(index % 3)
		var word := "Race" if count == 1 else "Races"
		return "%d %s %s Qualified" % [count, hoods[index / 3], word]
	if index == 9:
		return "100 Total Races Qualified"
	if index < 19:
		var which := index - 10
		var count := win_need(which % 3)
		var word := "Race" if count == 1 else "Races"
		return "%d %s %s Won" % [count, hoods[which / 3], word]
	if index == 19:
		return "100 Total Races Won"
	if index < 23:
		var count := circuit_need(index - 20)
		var word := "Race" if count == 1 else "Races"
		return "%d Circuit %s Qualified" % [count, word]
	if index < 26:
		var count := circuit_need(index - 23)
		var word := "Race" if count == 1 else "Races"
		return "%d Circuit %s Won" % [count, word]
	if index < 29:
		var count := circuit_need(index - 26)
		var word := "Race" if count == 1 else "Races"
		return "%d Circuit %s Swept" % [count, word]
	if index == 29:
		return "Grand Touring"
	var cups := [10, 20, 30]
	return "%d Kart Racing trophies won! Laff point boost!" % cups[clampi(index - 30, 0, 2)]


static func clock(seconds: float) -> String:
	var whole := maxi(int(seconds), 0)
	var hundredths := int(round((seconds - float(whole)) * 100.0))
	if hundredths >= 100:
		hundredths = 0
		whole += 1
	var mins := whole / 60
	var secs := whole % 60
	return "%02d:%02d:%02d" % [mins, secs, hundredths]
