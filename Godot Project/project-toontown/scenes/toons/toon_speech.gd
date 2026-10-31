class_name ToonSpeech
extends RefCounted

## DistributedToon.playDialogueForString. A speech bubble pops
## GUI_balloon_popup, then the species clip for that line: howl when the
## text says "ooo", exclaim on "!", question on "?", otherwise short, med,
## or long from the character count. Mickey uses one clip for every length.

const _POP := "res://assets/audio/sfx/GUI_balloon_popup.mp3"
const _DIAL := "res://assets/audio/dial/"
const _ANIMAL := {
	"d": "dog",
	"c": "cat",
	"h": "horse",
	"m": "mouse",
	"r": "rabbit",
	"f": "duck",
	"p": "monkey",
	"b": "bear",
	"s": "pig",
	"mk": "mickey",
}

static var _voice: AudioStreamPlayer
static var _cog: AudioStreamPlayer


static func speak(actor: Node, text: String) -> void:
	if text.is_empty():
		return
	var species := ""
	if actor is Mickey:
		species = "mk"
	elif actor is ToonActor:
		species = (actor as ToonActor).species()
	play(species, text)


static func play(species: String, text: String) -> void:
	if text.is_empty():
		return
	ToonGui.play_sfx(null, _POP)
	var path := _clip(species, text)
	if path.is_empty():
		return
	_play(_voice, "ToonSpeech", path)


## Suit.playDialogueForString. Cogs do not pop the toon balloon. Short lines
## grunt, medium lines murmur, and long lines, shouts, and "ooo" use the
## statement. A question uses the question clip.
static func cog(text: String) -> void:
	if text.is_empty():
		return
	_play(_cog, "CogSpeech", _cog_clip(text))


static func _clip(species: String, text: String) -> String:
	var animal := String(_ANIMAL.get(species, ""))
	if animal.is_empty():
		return ""
	if animal == "mickey":
		return _DIAL + "mickey.mp3"
	var kind := "long"
	var folded := text.to_lower()
	if folded.contains("ooo"):
		kind = "howl"
	elif folded.contains("!"):
		kind = "exclaim"
	elif folded.contains("?"):
		kind = "question"
	else:
		var count := text.length()
		if count <= 6:
			kind = "short"
		elif count <= 12:
			kind = "med"
	return "%sAV_%s_%s.mp3" % [_DIAL, animal, kind]


static func _cog_clip(text: String) -> String:
	var folded := text.to_lower()
	var kind := "statement"
	if folded.contains("?") and not folded.contains("ooo") and not folded.contains("!"):
		kind = "question"
	elif not folded.contains("ooo") and not folded.contains("!"):
		var count := text.length()
		if count <= 6:
			kind = "grunt"
		elif count <= 12:
			kind = "murmur"
	return _DIAL + "COG_VO_" + kind + ".mp3"


static func _play(player: AudioStreamPlayer, player_name: String, path: String) -> void:
	if path.is_empty():
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	if player == null or not is_instance_valid(player):
		player = ToonAudio.effect_player()
		player.name = player_name
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null:
			return
		var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
		if parent == null:
			return
		parent.add_child(player)
		if player_name == "CogSpeech":
			_cog = player
		else:
			_voice = player
	else:
		player.stop()
	player.stream = stream
	player.play()
