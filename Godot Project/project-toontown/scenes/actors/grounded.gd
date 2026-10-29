class_name Grounded
extends RefCounted

## The same gravity the player uses on the HQ stairs. A cog or toon keeps the
## horizontal step it already took, then falls until a floor stops it, and
## rides a slope that rises under its feet.

const GRAVITY := 64.348
const SNAP := 0.12
const CLIMB := 0.75
const REACH_UP := 1.5
const REACH_DOWN := 6.0

var velocity_y := 0.0


func step(actor: Node3D, delta: float) -> void:
	var world := actor.get_world_3d()
	if world == null:
		return
	var feet := actor.global_position
	var query := PhysicsRayQueryParameters3D.create(
		feet + Vector3(0.0, REACH_UP, 0.0),
		feet + Vector3(0.0, -REACH_DOWN, 0.0)
	)
	query.collide_with_areas = false
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var point: Vector3 = hit["position"]
	var floor_y := point.y
	# A ceiling or the landing above a pit is not a floor we can step onto.
	if floor_y > feet.y + CLIMB:
		return
	if floor_y >= feet.y - SNAP:
		feet.y = floor_y
		actor.global_position = feet
		velocity_y = -2.0
		return
	velocity_y -= GRAVITY * delta
	var next := feet.y + velocity_y * delta
	if next <= floor_y:
		next = floor_y
		velocity_y = -2.0
	feet.y = next
	actor.global_position = feet
