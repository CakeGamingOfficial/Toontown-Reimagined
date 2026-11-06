extends RefCounted

## PetTraits plus the mood drift from PetMood. Values are rolled per playground
## the way getRandValue does, then snapped to TraitDivisor.

const _INC := {
	"2000": [0.2, 0.65], "1000": [0.3, 0.7], "5000": [0.4, 0.75],
	"4000": [0.5, 0.8], "3000": [0.6, 0.85], "9000": [0.7, 0.9],
}
const _DEC := {
	"2000": [0.35, 0.8], "1000": [0.3, 0.7], "5000": [0.25, 0.6],
	"4000": [0.2, 0.5], "3000": [0.15, 0.4], "9000": [0.1, 0.3],
}
const _FORGET := {
	"2000": [0.0, 1.0], "1000": [0.0, 0.9], "5000": [0.0, 0.8],
	"4000": [0.0, 0.7], "3000": [0.0, 0.6], "9000": [0.0, 0.5],
}
const _SPAN := {
	"inc": [0.2, 0.9],
	"dec": [0.1, 0.8],
	"forget": [0.0, 1.0],
}
const _FIELDS := [
	["forgetfulness", "forget", true],
	["boredomThreshold", "inc", true],
	["restlessnessThreshold", "inc", true],
	["playfulnessThreshold", "dec", true],
	["lonelinessThreshold", "inc", true],
	["sadnessThreshold", "inc", true],
	["fatigueThreshold", "inc", true],
	["hungerThreshold", "inc", true],
	["confusionThreshold", "inc", true],
	["excitementThreshold", "dec", true],
	["angerThreshold", "inc", true],
	["surpriseThreshold", "inc", false],
	["affectionThreshold", "dec", true],
]
const _LINES := {
	"hungerThreshold": ["Always Hungry", "Often Hungry", "Sometimes Hungry", "Rarely Hungry"],
	"boredomThreshold": ["Always Bored", "Often Bored", "Sometimes Bored", "Rarely Bored"],
	"angerThreshold": ["Always Grumpy", "Often Grumpy", "Sometimes Grumpy", "Rarely Grumpy"],
	"forgetfulness": ["Always Forgets", "Often Forgets", "Sometimes Forgets", "Rarely Forgets"],
	"excitementThreshold": ["Very Calm", "Pretty Calm", "Pretty Excitable", "Very Excitable"],
	"sadnessThreshold": ["Always Sad", "Often Sad", "Sometimes Sad", "Rarely Sad"],
	"restlessnessThreshold": ["Always Restless", "Often Restless", "Sometimes Restless", "Rarely Restless"],
	"playfulnessThreshold": ["Rarely Playful", "Sometimes Playful", "Often Playful", "Always Playful"],
	"lonelinessThreshold": ["Always Lonely", "Often Lonely", "Sometimes Lonely", "Rarely Lonely"],
	"fatigueThreshold": ["Always Tired", "Often Tired", "Sometimes Tired", "Rarely Tired"],
	"confusionThreshold": ["Always Confused", "Often Confused", "Sometimes Confused", "Rarely Confused"],
	"surpriseThreshold": ["Always Surprised", "Often Surprised", "Sometimes Surprised", "Rarely Surprised"],
	"affectionThreshold": ["Rarely Affectionate", "Sometimes Affectionate", "Often Affectionate", "Always Affectionate"],
}
const _HOUR := 1.0
const _MINUTE := _HOUR / 60.0
const _BASE := {
	"boredom": 12.0 * _HOUR,
	"restlessness": 18.0 * _HOUR,
	"playfulness": -1.0 * _HOUR,
	"loneliness": 24.0 * _HOUR,
	"sadness": -1.0 * _HOUR,
	"fatigue": -15.0 * _MINUTE,
	"hunger": 24.0 * _HOUR,
	"confusion": -5.0 * _MINUTE,
	"excitement": -5.0 * _MINUTE,
	"surprise": -5.0 * _MINUTE,
	"affection": -10.0 * _MINUTE,
}
const _FASTER := ["sadness", "fatigue", "confusion", "surprise", "affection"]
const _UNHAPPY := ["boredom", "restlessness", "loneliness", "sadness", "fatigue", "hunger", "anger"]
const _CONTENTED := ["neutral", "excitement", "playfulness", "affection"]


static func roll(rng: RandomNumberGenerator, zone: int) -> Dictionary:
	var key := str(zone)
	if not _INC.has(key):
		key = "2000"
	var rows: Array = []
	var extreme: Array = []
	var total := 0.0
	for field in _FIELDS:
		var spec: Array = field
		var name := String(spec[0])
		var kind := String(spec[1])
		var worth := bool(spec[2])
		var span: Array = _range(kind, key)
		var value := _snap(_gauss(rng, float(span[0]), float(span[1])))
		var percent := _percent(kind, value)
		var higher := kind == "inc"
		var quality := _quality(kind, percent)
		var how := _extreme_amount(percent)
		var row := {
			"name": name,
			"value": value,
			"kind": kind,
			"worth": worth,
			"higher": higher,
			"percentile": percent if higher else 1.0 - percent,
			"quality": quality,
			"extreme": how,
		}
		rows.append(row)
		if worth:
			total += value if higher else 1.0 - value
		if worth and quality != 2:
			extreme.append(row)
	extreme.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["extreme"]) > float(b["extreme"]))
	var lines: PackedStringArray = []
	for row in extreme:
		var words: Array = _LINES.get(String(row["name"]), [])
		var slot := _word_slot(int(row["quality"]))
		if slot >= 0 and slot < words.size():
			lines.append(String(words[slot]))
	return {"rows": rows, "overall": total / float(_FIELDS.size()), "lines": lines}


static func blank_mood() -> Dictionary:
	return {
		"boredom": 0.0, "restlessness": 0.0, "playfulness": 0.0, "loneliness": 0.0,
		"sadness": 0.0, "affection": 0.0, "hunger": 0.0, "confusion": 0.0,
		"excitement": 0.0, "fatigue": 0.0, "anger": 0.0, "surprise": 0.0,
	}


static func drift(mood: Dictionary, rows: Array, seconds: float) -> Dictionary:
	var next := mood.duplicate()
	if seconds <= 0.0:
		return next
	for comp in _BASE.keys():
		var pace := _pace(String(comp), rows)
		if absf(pace) < 0.01:
			pace = 0.01 if pace >= 0.0 else -0.01
		var value := float(next.get(comp, 0.0)) + seconds / (pace * 7200.0)
		next[comp] = clampf(value, 0.0, 1.0)
	var abuse := (float(next["hunger"]) * 3.0 + float(next["boredom"]) + float(next["loneliness"])) / 5.0
	var anger_pace := _anger_pace(abuse, rows)
	var anger := float(next.get("anger", 0.0)) + seconds / (anger_pace * 7200.0)
	next["anger"] = clampf(anger, 0.0, 1.0)
	return next


static func nudge(mood: Dictionary, deltas: Dictionary) -> Dictionary:
	var next := mood.duplicate()
	for comp in deltas.keys():
		next[comp] = clampf(float(next.get(comp, 0.0)) + float(deltas[comp]), 0.0, 1.0)
	return next


static func dominant(mood: Dictionary, rows: Array) -> String:
	var winner := "neutral"
	var priority := 1.0
	for comp in mood.keys():
		if comp == "restlessness" or comp == "playfulness":
			continue
		var value := float(mood[comp])
		var gate := maxf(_threshold(String(comp), rows), 0.01)
		var rank := value / gate
		if rank >= priority:
			winner = String(comp)
			priority = rank
		elif comp == "fatigue" and rank >= 1.0:
			winner = "fatigue"
	return winner


static func contented(mood: Dictionary, rows: Array) -> bool:
	return _CONTENTED.has(dominant(mood, rows))


static func unhappy(mood: Dictionary, rows: Array) -> bool:
	return _UNHAPPY.has(dominant(mood, rows))


static func active(mood: Dictionary, rows: Array, comp: String) -> bool:
	return float(mood.get(comp, 0.0)) >= _threshold(comp, rows)


static func _threshold(comp: String, rows: Array) -> float:
	var wanted := comp + "Threshold"
	for row in rows:
		if String((row as Dictionary).get("name", "")) == wanted:
			return float((row as Dictionary).get("value", 0.5))
	return 0.5


static func _pace(comp: String, rows: Array) -> float:
	var base := float(_BASE.get(comp, 1.0))
	var wanted := comp + "Threshold"
	var row := {}
	for item in rows:
		if String((item as Dictionary).get("name", "")) == wanted:
			row = item
			break
	if row.is_empty():
		return base if absf(base) > 0.01 else 0.01
	return base * _drift_factor(float(row.get("percentile", 0.5)), comp in _FASTER)


static func _anger_pace(abuse: float, rows: Array) -> float:
	var row := {}
	for item in rows:
		if String((item as Dictionary).get("name", "")) == "angerThreshold":
			row = item
			break
	var faster := _drift_factor(float(row.get("percentile", 0.5)), true) if not row.is_empty() else 1.0
	var slower := _drift_factor(float(row.get("percentile", 0.5)), false) if not row.is_empty() else 1.0
	var tip := 0.6
	if abuse < tip:
		return lerpf(-20.0 * _MINUTE * faster, -5000.0 * 7.0 * 24.0, abuse / tip)
	return lerpf(5000.0 * 7.0 * 24.0, 2.0 * 7.0 * 24.0 * slower, (abuse - tip) / (1.0 - tip))


static func _drift_factor(percentile: float, faster_is_better: bool) -> float:
	var value := clampf(percentile, 0.0, 1.0)
	if faster_is_better:
		if value < 0.5:
			return lerpf(2.0, 1.0, value * 2.0)
		var rebased := (value - 0.5) * 2.0
		return lerpf(1.0, 0.1, rebased * rebased)
	if value < 0.5:
		return lerpf(0.75, 1.0, value * 2.0)
	var rebased := (value - 0.5) * 2.0
	return lerpf(1.0, 28.0, rebased * rebased)


static func _range(kind: String, zone: String) -> Array:
	if kind == "dec":
		return _DEC[zone]
	if kind == "forget":
		return _FORGET[zone]
	return _INC[zone]


static func _gauss(rng: RandomNumberGenerator, low: float, high: float) -> float:
	var mid := (low + high) * 0.5
	var sample := rng.randfn(mid, maxf((high - low) / 6.0, 0.01))
	return clampf(sample, low, high)


static func _snap(value: float) -> float:
	return floorf(value * 10000.0) / 10000.0


static func _percent(kind: String, value: float) -> float:
	var span: Array = _SPAN[kind]
	var low := float(span[0])
	var high := float(span[1])
	if value < low:
		low = value
	elif value > high:
		high = value
	if absf(high - low) < 0.0001:
		return 0.0
	return clampf((value - low) / (high - low), 0.0, 1.0)


static func _quality(kind: String, percent: float) -> int:
	var increasing := kind == "inc"
	if increasing:
		if percent <= 0.1:
			return 0
		if percent <= 0.25:
			return 1
		if percent >= 0.9:
			return 4
		if percent >= 0.75:
			return 3
		return 2
	if percent <= 0.1:
		return 4
	if percent <= 0.25:
		return 3
	if percent >= 0.9:
		return 0
	if percent >= 0.75:
		return 1
	return 2


static func _extreme_amount(percent: float) -> float:
	if percent < 0.5:
		return clampf((0.5 - percent) * 2.0, 0.0, 1.0)
	return clampf((percent - 0.5) * 2.0, 0.0, 1.0)


static func _word_slot(quality: int) -> int:
	if quality == 0:
		return 0
	if quality == 1:
		return 1
	if quality == 3:
		return 2
	if quality == 4:
		return 3
	return -1
