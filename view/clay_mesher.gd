class_name ClayMesher
extends RefCounted
## Přesné vytažení buněk masky. Obdélníky slučujeme jen uvnitř stejného materiálu.
## Boky vznikají výhradně proti prázdné buňce, nikdy na švu dvou oblastí.


class Surface:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()


	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
		var start := vertices.size()
		for point in [a, b, c, d]:
			vertices.append(point)
			normals.append(normal)
			if absf(normal.z) > 0.5:
				uvs.append(Vector2(point.x, -point.y))
			elif absf(normal.y) > 0.5:
				uvs.append(Vector2(point.x, -point.z))
			else:
				uvs.append(Vector2(-point.z, -point.y))
		for index in [0, 1, 2, 0, 2, 3]:
			indices.append(start + index)


	func arrays() -> Array:
		var result := []
		result.resize(Mesh.ARRAY_MAX)
		result[Mesh.ARRAY_VERTEX] = vertices
		result[Mesh.ARRAY_NORMAL] = normals
		result[Mesh.ARRAY_TEX_UV] = uvs
		result[Mesh.ARRAY_INDEX] = indices
		return result


static func kind(mask: TerrainMask, grass: PackedByteArray, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= mask.width or y >= mask.height:
		return -1
	var offset := (y * mask.width + x) * 4
	if mask.data[offset] == 0:
		return -1
	if mask.data[offset + 1] != 0:
		return 2
	if mask.data[offset + 2] != 0:
		return 3
	return 1 if grass[y * mask.width + x] != 0 else 0


static func build(mask: TerrainMask, grass: PackedByteArray, region: int,
		materials: Array[ShaderMaterial]) -> ArrayMesh:
	var x0 := (region % mask.region_columns) * TerrainMask.REGION_SIZE
	var y0 := (region / mask.region_columns) * TerrainMask.REGION_SIZE
	var width := mini(TerrainMask.REGION_SIZE, mask.width - x0)
	var height := mini(TerrainMask.REGION_SIZE, mask.height - y0)
	var cells := PackedInt32Array()
	cells.resize(width * height)
	var stride := width + 2
	var halo := PackedInt32Array()
	halo.resize(stride * (height + 2))
	for y in range(-1, height + 1):
		for x in range(-1, width + 1):
			halo[(y + 1) * stride + x + 1] = kind(mask, grass, x0 + x, y0 + y)
	var surfaces: Array[Surface] = [Surface.new(), Surface.new(), Surface.new(), Surface.new()]
	for y in height:
		for x in width:
			cells[y * width + x] = halo[(y + 1) * stride + x + 1]
	var used := PackedByteArray()
	used.resize(cells.size())
	for y in height:
		for x in width:
			var cell := cells[y * width + x]
			if cell < 0:
				continue
			var surface := surfaces[cell]
			var neighbor := (y + 1) * stride + x + 1
			var edges := int(halo[neighbor - stride] < 0) + int(halo[neighbor + stride] < 0) * 2 \
				+ int(halo[neighbor - 1] < 0) * 4 + int(halo[neighbor + 1] < 0) * 8
			if edges != 0:
				_sides(surface, x0 + x, y0 + y, edges)
			if used[y * width + x] != 0:
				continue
			var rw := 1
			while x + rw < width and cells[y * width + x + rw] == cell \
					and used[y * width + x + rw] == 0:
				rw += 1
			var rh := 1
			while y + rh < height:
				var matches := true
				for dx in rw:
					if cells[(y + rh) * width + x + dx] != cell \
							or used[(y + rh) * width + x + dx] != 0:
						matches = false
						break
				if not matches:
					break
				rh += 1
			for dy in rh:
				for dx in rw:
					used[(y + dy) * width + x + dx] = 1
			var a := ClaySpace.to_world(Vector2(x0 + x, y0 + y), 0)
			var b := a + Vector3(rw * ClaySpace.UNIT, 0, 0)
			var c := b - Vector3(0, rh * ClaySpace.UNIT, 0)
			var d := a - Vector3(0, rh * ClaySpace.UNIT, 0)
			surface.quad(a, b, c, d, Vector3.BACK)
			var depth := Vector3(0, 0, -ClaySpace.DEPTH)
			surface.quad(d + depth, c + depth, b + depth, a + depth, Vector3.FORWARD)
	var mesh := ArrayMesh.new()
	for index in surfaces.size():
		if surfaces[index].vertices.is_empty():
			continue
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surfaces[index].arrays())
		mesh.surface_set_material(mesh.get_surface_count() - 1, materials[index])
	return mesh


static func _sides(surface: Surface, x: int, y: int, edges: int) -> void:
	var a := ClaySpace.to_world(Vector2(x, y), 0)
	var b := a + Vector3(ClaySpace.UNIT, 0, 0)
	var c := b - Vector3(0, ClaySpace.UNIT, 0)
	var d := a - Vector3(0, ClaySpace.UNIT, 0)
	var back := Vector3(0, 0, -ClaySpace.DEPTH)
	if edges & 1:
		surface.quad(a + back, b + back, b, a, Vector3.UP)
	if edges & 2:
		surface.quad(d, c, c + back, d + back, Vector3.DOWN)
	if edges & 4:
		surface.quad(a, d, d + back, a + back, Vector3.LEFT)
	if edges & 8:
		surface.quad(b + back, c + back, c, b, Vector3.RIGHT)
