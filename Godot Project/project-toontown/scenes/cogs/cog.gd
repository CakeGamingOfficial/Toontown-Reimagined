class_name Cog
extends Node3D

## The level printed on the cog. SuitBase.getActualLevel is this number:
## a Flunky's lowest suit is 1, a Yesman's is 3, the Big Cheese's is 8.
## Every cog uses the same pool: (level + 1) * (level + 2).
var cog_level := 1


func max_hp() -> int:
	return Cog.hp_for_level(cog_level)


static func hp_for_level(level: int) -> int:
	return (level + 1) * (level + 2)
