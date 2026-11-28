extends Node3D

## The windmill sails turn in place. The shaft is this node's local Z.


func _process(delta: float) -> void:
	rotate_z(delta * 0.7)
