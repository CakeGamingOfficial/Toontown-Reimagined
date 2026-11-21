extends RefCounted

## Factories, mints, offices, golf courses, and the four bosses are tuned
## for four toons. Each missing toon lowers every cog by one level. Four or
## more stay on the original numbers. Hit points are Cog.hp_for_level.

static var _by_peer: Dictionary = {}


static func note_group(members: Array) -> void:
	var count := 0
	for id in members:
		if int(id) > 0:
			count += 1
	if count < 1:
		count = 1
	for id in members:
		var peer := int(id)
		if peer > 0:
			_by_peer[peer] = count


static func for_peer(peer: int) -> int:
	return maxi(int(_by_peer.get(peer, 1)), 1)


static func level(base: int, toons: int) -> int:
	var party := clampi(toons, 1, 4)
	return maxi(base - (4 - party), 1)
