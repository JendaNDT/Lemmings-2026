class_name ClayDressing
extends RefCounted
## Oblá zeleň a kamínky jsou přivázané k živé masce, takže po zásahu nezůstanou viset.

static var _sphere: SphereMesh
static var _material: StandardMaterial3D


static func build(mask: TerrainMask, grass: PackedByteArray, region: int) -> Node3D:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 1
		_sphere.height = 2
		_sphere.radial_segments = 12
		_sphere.rings = 8
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 0.95
	var root := Node3D.new()
	var placements: Array[Transform3D] = []
	var colors: Array[Color] = []
	var x0 := region % mask.region_columns * TerrainMask.REGION_SIZE
	var y0 := region / mask.region_columns * TerrainMask.REGION_SIZE
	for y in range(y0, mini(y0 + TerrainMask.REGION_SIZE, mask.height)):
		for x in range(x0, mini(x0 + TerrainMask.REGION_SIZE, mask.width)):
			if mask.is_steel(x, y) and x % 12 == 5 and y % 10 == 7 \
					and _supported(mask, x, y, 2):
				_add(placements, colors, Vector2(x + 0.5, y + 0.5), 0.045,
					Vector3(0.085, 0.085, 0.04), Color("465961"))
			if not _dirt(mask, x, y):
				continue
			var seed_value := _hash(x, y)
			if x % 3 == 0 and grass[y * mask.width + x] > 0 \
					and not ClayMesher._solid(mask, x, y - 1) and _supported(mask, x, y + 2, 1):
				var scale_value := Vector3(0.27 + seed_value * 0.07, 0.18, 0.18)
				_add(placements, colors, Vector2(x + 0.5 + (seed_value - 0.5),
					y + 1.9 + seed_value * 0.35), -0.04, scale_value,
					Color("4b7d2e").lerp(Color("648b35"), seed_value), (seed_value - 0.5) * 0.35)
				if x % 24 == 0:
					_plant(placements, colors, Vector2(x + 0.5, y), seed_value)
			elif x % 15 == 4 and y % 13 == 5 and seed_value > 0.45:
				var px := x + int(_hash(x + 3, y) * 7) - 3
				var py := y + int(_hash(x, y + 3) * 7) - 3
				if grass[y * mask.width + x] > 0 or not _supported(mask, px, py, 3):
					continue
				var size := 0.08 + seed_value * 0.10
				_add(placements, colors, Vector2(px + 0.5, py + 0.5), -size * 0.35,
					Vector3(size * 1.4, size, size * 0.65),
					Color("726e6a").lerp(Color("938672"), seed_value), seed_value * 2)
	if not placements.is_empty():
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = _sphere
		multi.instance_count = placements.size()
		for index in placements.size():
			multi.set_instance_transform(index, placements[index])
			multi.set_instance_color(index, colors[index])
		var node := MultiMeshInstance3D.new()
		node.multimesh = multi
		node.material_override = _material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
	return root


static func _hash(x: int, y: int) -> float:
	return fposmod(sin(x * 127.1 + y * 311.7) * 43758.5453, 1.0)


static func _dirt(mask: TerrainMask, x: int, y: int) -> bool:
	var at := (y * mask.width + x) * 4
	return mask.data[at] > 0 and mask.data[at + 1] == 0 and mask.data[at + 2] == 0


static func _supported(mask: TerrainMask, x: int, y: int, radius: int) -> bool:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if not ClayMesher._solid(mask, x + dx, y + dy):
				return false
	return true


static func _add(placements: Array[Transform3D], colors: Array[Color], point: Vector2,
		depth: float, scale_value: Vector3, color: Color, angle: float = 0) -> void:
	placements.append(Transform3D(Basis(Vector3.BACK, angle).scaled(scale_value),
		ClaySpace.to_world(point, depth)))
	colors.append(color)


static func _plant(placements: Array[Transform3D], colors: Array[Color],
		point: Vector2, seed_value: float) -> void:
	for index in 3:
		var sign_value := index - 1
		_add(placements, colors, point + Vector2(sign_value * 1.3, -1.1 - seed_value),
			-0.65, Vector3(0.09, 0.24 + seed_value * 0.07, 0.08),
			Color("3c7560").lerp(Color("80a145"), index / 3.0), -sign_value * 0.55)
	if seed_value > 0.65:
		_add(placements, colors, point + Vector2(2.2, -2.3), -0.65,
			Vector3.ONE * 0.08, Color("efd884"))
