class_name ClayFx
extends Node3D
## Omezený počet hrudek. Žádná kolize ani náhoda ve společné simulaci.

const LIMIT := 96
var impacts := PackedVector4Array()
var _particles: Array[Dictionary] = []
var _pulse := 0
var _mesh: SphereMesh
var _clay: Material = preload("res://assets/clay/materials/clay_earth.tres")
var _brick: Material = preload("res://assets/clay/materials/clay_brick.tres")


func _init() -> void:
	impacts.resize(8)
	_mesh = SphereMesh.new()
	_mesh.radius = 0.075
	_mesh.height = 0.15
	_mesh.radial_segments = 8
	_mesh.rings = 4


func clear() -> void:
	for item in _particles:
		(item["node"] as MeshInstance3D).free()
	_particles.clear()
	impacts.fill(Vector4.ZERO)
	_pulse = 0


func update(delta: float, events: Array[Dictionary]) -> void:
	for index in impacts.size():
		impacts[index].z = maxf(0, impacts[index].z - delta * 3.0)
	for i in range(_particles.size() - 1, -1, -1):
		var item := _particles[i]
		item["age"] += delta
		var node: MeshInstance3D = item["node"]
		var age: float = item["age"]
		if age >= 0.65:
			node.free()
			_particles.remove_at(i)
			continue
		var velocity: Vector3 = item["velocity"]
		node.position = item["origin"] + velocity * age + Vector3(0, -4.0 * age * age, age * 0.3)
		node.scale = Vector3(1.0 + sin(age * 12) * 0.45, 1.0 - sin(age * 12) * 0.2, 1.0) \
			* minf(1, (0.65 - age) * 6)
		node.rotation.z = age * 4 * signf(velocity.x)
	for event in events:
		var type: String = event["type"]
		if type not in ["dig", "bash", "brick", "brick_warning", "steel"]:
			continue
		var point := Vector2(float(event["x"]) + 0.5, float(event["y"]))
		var direction := float(event["dir"])
		if type in ["bash", "steel"]:
			point += Vector2(3 * direction, -5)
		var at := ClaySpace.to_world(point, 0.3)
		if type in ["bash", "dig"]:
			impacts[_pulse % 8] = Vector4(at.x, at.y, 1, 0)
			_pulse += 1
		for index in 3:
			if _particles.size() >= LIMIT:
				break
			var node := MeshInstance3D.new()
			node.mesh = _mesh
			node.material_override = _clay if type in ["dig", "bash"] else _brick
			node.position = at
			add_child(node)
			_particles.append({"node": node, "origin": at, "age": 0.0,
				"velocity": Vector3((index - 1) * 0.9 + direction * 0.3, 1.0 + index * 0.2, 0.5)})
