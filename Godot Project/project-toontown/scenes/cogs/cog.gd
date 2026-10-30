class_name Cog
extends Node3D

## The level printed on the cog. SuitBase.getActualLevel is this number:
## a Flunky's lowest suit is 1, a Yesman's is 3, the Big Cheese's is 8.
## Every cog uses the same pool: (level + 1) * (level + 2).
var cog_level := 1

# SuitDNA.suitDeptFullnames and Suit.medallionColors.
const DEPT_NAME := {
	"c": "Bossbot",
	"l": "Lawbot",
	"m": "Cashbot",
	"s": "Sellbot",
}
const MEDALLION := {
	"c": Color(0.863, 0.776, 0.769),
	"s": Color(0.843, 0.745, 0.745),
	"l": Color(0.749, 0.776, 0.824),
	"m": Color(0.749, 0.769, 0.749),
}


static func dept_name(dept: String) -> String:
	return String(DEPT_NAME.get(dept, "Bossbot"))


static func medallion_color(dept: String) -> Color:
	if MEDALLION.has(dept):
		return MEDALLION[dept]
	return Color(0.863, 0.776, 0.769)


func max_hp() -> int:
	return Cog.hp_for_level(cog_level)


static func hp_for_level(level: int) -> int:
	return (level + 1) * (level + 2)
