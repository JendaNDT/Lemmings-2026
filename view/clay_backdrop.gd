class_name ClayBackdrop
extends Node3D
## Modelovaná krajina za herní rovinou. Sdílené meshe drží počet kreslení nízko.

var _batches := {}
var _meshes := {}


func setup(width: int, height: int) -> void:
	for child in get_children():
		child.free()
	_batches.clear()
	var sphere := SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	sphere.radial_segments = 20
	sphere.rings = 12
	_meshes["round"] = sphere
	var hill_mesh := SphereMesh.new()
	hill_mesh.radius = 1
	hill_mesh.height = 2
	hill_mesh.radial_segments = 64
	hill_mesh.rings = 32
	_meshes["hill"] = hill_mesh
	var tube := CylinderMesh.new()
	tube.top_radius = 0.85
	tube.bottom_radius = 1
	tube.height = 1
	tube.radial_segments = 20
	_meshes["tube"] = tube
	var cone := CylinderMesh.new()
	cone.top_radius = 0.035
	cone.bottom_radius = 1
	cone.height = 1
	cone.radial_segments = 24
	_meshes["roof"] = cone
	var base := float(height)
	for index in range(-2, ceili(width / 70.0) + 3):
		var x := index * 70.0
		var rise := sin(index * 2.3) * 12
		_add("hill", _at(x, base * 0.73 + rise, -38), Vector3(10, 8.5, 4), Color("82a9b6"))
		_add("hill", _at(x + 20, base * 0.83 - rise, -30), Vector3(8, 7.2, 3.5), Color("83a78c"))
		_add("hill", _at(x - 10, base * 0.98 + rise * 0.5, -21),
			Vector3(8.5, 5.3, 4), Color("709674"))
	for index in 6:
		_cloud(45 + index * width / 5.0, 18 + fposmod(index * 17.0, 35), -42, index)
	for index in range(-1, ceili(width / 42.0) + 2):
		var x := index * 42.0 + sin(index * 4.1) * 10
		var y := base * 0.90 + sin(index * 1.9) * 10
		_tree(x, y, -24, 1.2 + fposmod(index * 0.37, 0.65), index)
	for index in 9:
		_tree(index * width / 8.0 + 11, base * 0.57, -36, 0.85, index)
	_castle(width * 0.39, base * 0.48, -33)
	# Nízké oblé břehy a světlý pruh vody jsou vidět mezerami pod plošinami.
	_add("hill", _at(width * 0.55, base * 1.07, -17),
		Vector3(width * 0.085, 0.7, 4), Color("79b6c2"))
	for index in 12:
		_add("hill", _at(index * width / 11.0, base * 1.25, -10),
			Vector3(5.5, 3.5 + sin(index) * 0.5, 2), Color("71916a"))
	_flush()


func _at(x: float, y: float, depth: float) -> Vector3:
	return ClaySpace.to_world(Vector2(x, y), depth) \
		+ Vector3(0, (depth - ClaySpace.ACTOR_Z) * tan(ClayCamera.TILT), 0)


func _cloud(x: float, y: float, depth: float, seed_value: int) -> void:
	var anchor := _at(x, y, depth)
	for index in 7:
		var p := Vector3((index - 3) * 1.0, sin(index * 2.1 + seed_value) * 0.35, 0)
		var radius := 0.65 + sin(index * 1.7) * 0.2
		_add("round", anchor + p, Vector3(1.3, radius, 0.9), Color("e6ece2"))
	_add("round", anchor + Vector3(-0.5, 0.8, 0), Vector3(1.4, 1.2, 1), Color("f0eee1"))


func _tree(x: float, y: float, depth: float, scale_value: float, seed_value: int) -> void:
	var at := _at(x, y, depth)
	_add("tube", at + Vector3(0, 1.1, 0) * scale_value,
		Vector3(0.23, 2.2, 0.23) * scale_value, Color("8b7860"))
	for index in 6:
		var angle := index * TAU / 5
		var p := Vector3(cos(angle) * 0.65, 2.4 + sin(angle) * 0.7, sin(index) * 0.2)
		var color := Color("5a896b").lerp(Color("8aa572"), fposmod(index * 0.23 + seed_value * 0.13, 1))
		_add("round", at + p * scale_value,
			Vector3(0.9, 1.15, 0.8) * scale_value, color)


func _castle(x: float, y: float, depth: float) -> void:
	var base := _at(x, y, depth)
	for index in 3:
		var offset := Vector3((index - 1) * 1.65, 0, 0.5 if index == 1 else 0)
		var h := 4.6 if index == 1 else 2.8
		_add("tube", base + offset + Vector3(0, h * 0.5, 0),
			Vector3(0.72, h, 0.72), Color("c4bea0"))
		_add("roof", base + offset + Vector3(0, h + 0.75, 0),
			Vector3(1.05, 1.8, 1.05), Color("b67d76"))
		_add("round", base + offset + Vector3(0, h * 0.7, 0.69),
			Vector3(0.14, 0.26, 0.07), Color("67716e"))
		_add("round", base + offset + Vector3(0, 0.7, 0.70),
			Vector3(0.25, 0.53, 0.05), Color("787c6b"))


func _add(type: String, at: Vector3, scale_value: Vector3, color: Color) -> void:
	if not _batches.has(type):
		_batches[type] = []
	_batches[type].append([Transform3D(Basis.IDENTITY.scaled(scale_value), at), color])


func _flush() -> void:
	for type: String in _batches:
		var batch: Array = _batches[type]
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.use_colors = true
		instances.mesh = _meshes[type]
		instances.instance_count = batch.size()
		for index in batch.size():
			instances.set_instance_transform(index, batch[index][0])
			instances.set_instance_color(index, batch[index][1])
		var node := MultiMeshInstance3D.new()
		node.multimesh = instances
		var material := ShaderMaterial.new()
		material.shader = preload("res://view/clay_backdrop.gdshader")
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
