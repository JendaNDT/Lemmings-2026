class_name ClaySpace
extends RefCounted
## Jediný převod mezi logickými pixely a herní rovinou v metrech.

const UNIT := 0.1
const ACTOR_Z := 0.12
const DEPTH := 2.4


static func to_world(point: Vector2, depth: float = ACTOR_Z) -> Vector3:
	return Vector3(point.x * UNIT, -point.y * UNIT, depth)


static func to_logic(point: Vector3) -> Vector2:
	return Vector2(point.x, -point.y) / UNIT
