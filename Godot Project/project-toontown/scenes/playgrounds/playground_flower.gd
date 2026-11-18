extends Node3D

## DistributedDGFlower. phase_8/models/props/DG_flower-mod.bam sits at
## panda (1.39, 92.91, 2), scale 2.5. The spin task adds 1.25 degrees each
## frame. The radius 6 sphere is the trigger. Each toon who steps in raises
## the flower 0.5, up to 10, and stepping out lowers it back toward 2.
## The move takes half a second. The radius 4.5 sphere is the wall.

const _MODEL := "res://assets/neighborhoods/daisy_gardens/props/DG_flower.glb"
const _SPIN := 1.25
const _RAISE := 0.5
const _STEP := 0.5
const _MIN := 2.0
const _MAX := 10.0
const _TRIGGER := 6.0
const _WALL := 4.5

var _flower: Node3D
var _height := _MIN
var _from := _MIN
var _to := _MIN
var _blend := 1.0
var _inside := false


static func place(host: Node) -> void:
	if host.get_node_or_null("DaisyFlower") != null:
		return
	var stem: Node = load("res://scenes/playgrounds/playground_flower.gd").new()
	stem.name = "DaisyFlower"
	host.add_child(stem)


func _ready() -> void:
	var packed := load(_MODEL) as PackedScene
	if packed == null:
		return
	_flower = packed.instantiate() as Node3D
	_flower.name = "BigFlower"
	_flower.position = Vector3(1.39, _MIN, -92.91)
	_flower.scale = Vector3.ONE * 2.5
	add_child(_flower)
	var wall := StaticBody3D.new()
	wall.name = "BigFlowerCollide"
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = _WALL
	shape.shape = sphere
	wall.add_child(shape)
	_flower.add_child(wall)


func _process(delta: float) -> void:
	if _flower == null:
		return
	_flower.rotate_y(deg_to_rad(_SPIN))
	if _blend < 1.0:
		_blend = minf(_blend + delta / _RAISE, 1.0)
		_flower.position.y = lerpf(_from, _to, _blend)
	_watch()


func _watch() -> void:
	var toon := get_parent().get_node_or_null("PlaygroundToon")
	if toon == null or not toon.has_method("battle_point") or bool(toon.call("is_held")):
		return
	var feet: Vector3 = toon.call("battle_point")
	var reach := _TRIGGER * _flower.scale.x
	var inside := feet.distance_to(_flower.global_position) <= reach
	if inside and not _inside:
		_change(_STEP)
	elif not inside and _inside:
		_change(-_STEP)
	_inside = inside


func _change(step: float) -> void:
	var next := _height + step
	if next > _MAX or next < _MIN:
		return
	_height = next
	_from = _flower.position.y
	_to = _height
	_blend = 0.0
