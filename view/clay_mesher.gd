class_name ClayMesher
extends RefCounted
## Zaoblený řez masky: středy buněk zůstávají věrné kolizím, okraje mají oblý profil.

const BEVEL_CELLS := 3
const HALO := BEVEL_CELLS + 2

class Surface:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()


	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3,
			corner_normals: Array[Vector3] = []) -> void:
		var start := vertices.size()
		var points := [a, b, c, d]
		for i in 4:
			var point: Vector3 = points[i]
			vertices.append(point)
			normals.append(normal if corner_normals.is_empty() else corner_normals[i])
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
	var field := _field(mask, Rect2i(x0, y0, width, height))
	var stride := width + 1 + 2 * HALO
	var surfaces: Array[Surface] = [Surface.new(), Surface.new(), Surface.new(), Surface.new()]
	var used := PackedByteArray()
	used.resize(width * height)
	for y in height:
		for x in width:
			var cell := kind(mask, grass, x0 + x, y0 + y)
			if cell < 0 or used[y * width + x] != 0:
				continue
			var rw := 1
			var rh := 1
			# Plochý vnitřek zůstává sloučený; detail potřebuje pouze obvod.
			if _flat(field, x, y, stride):
				while x + rw < width and used[y * width + x + rw] == 0 \
						and kind(mask, grass, x0 + x + rw, y0 + y) == cell \
						and _flat(field, x + rw, y, stride):
					rw += 1
				while y + rh < height:
					var matches := true
					for dx in rw:
						if used[(y + rh) * width + x + dx] != 0 \
								or kind(mask, grass, x0 + x + dx, y0 + y + rh) != cell \
								or not _flat(field, x + dx, y + rh, stride):
							matches = false
							break
					if not matches:
						break
					rh += 1
			for dy in rh:
				for dx in rw:
					used[(y + dy) * width + x + dx] = 1
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for p in [Vector2i(x, y), Vector2i(x + rw, y),
					Vector2i(x + rw, y + rh), Vector2i(x, y + rh)]:
				var at: int = (p.y + HALO) * stride + p.x + HALO
				var offset := _corner_offset(mask, x0 + p.x, y0 + p.y)
				points.append(ClaySpace.to_world(Vector2(x0 + p.x, y0 + p.y) + offset,
					_profile(field[at])))
				var dx := (_profile(field[at + 1]) - _profile(field[at - 1])) / (2 * ClaySpace.UNIT)
				var dy := (_profile(field[at + stride]) - _profile(field[at - stride])) \
					/ (2 * ClaySpace.UNIT)
				normals.append(Vector3(-dx, dy, 1).normalized())
			var surface := surfaces[cell]
			surface.quad(points[0], points[1], points[2], points[3], Vector3.BACK, normals)
			var back: Array[Vector3] = []
			for point in points:
				back.append(Vector3(point.x, point.y, -ClaySpace.DEPTH))
			surface.quad(back[3], back[2], back[1], back[0], Vector3.FORWARD)
			if rw == 1 and rh == 1:
				var neighbors := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
				for edge in 4:
					var n: Vector2i = neighbors[edge]
					if _solid(mask, x0 + x + n.x, y0 + y + n.y):
						continue
					var next := (edge + 1) % 4
					var normal := (points[next] - points[edge]).cross(Vector3.FORWARD).normalized()
					surface.quad(back[edge], back[next], points[next], points[edge], normal)
	var mesh := ArrayMesh.new()
	for index in surfaces.size():
		if surfaces[index].vertices.is_empty():
			continue
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surfaces[index].arrays())
		mesh.surface_set_material(mesh.get_surface_count() - 1, materials[index])
	return mesh


static func _flat(field: PackedFloat32Array, x: int, y: int, stride: int) -> bool:
	var at := (y + HALO) * stride + x + HALO
	return minf(minf(field[at], field[at + 1]),
		minf(field[at + stride], field[at + stride + 1])) >= BEVEL_CELLS


static func _solid(mask: TerrainMask, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < mask.width and y < mask.height \
		and mask.data[(y * mask.width + x) * 4] > 0


static func _profile(distance: float) -> float:
	var t := clampf(distance / BEVEL_CELLS, 0, 1)
	return -0.16 * (1.0 - sqrt(1.0 - (1.0 - t) * (1.0 - t)))


static func _corner_offset(mask: TerrainMask, x: int, y: int) -> Vector2:
	var direction := Vector2.ZERO
	var count := 0
	for dy in [-1, 0]:
		for dx in [-1, 0]:
			if _solid(mask, x + dx, y + dy):
				count += 1
				direction += Vector2(dx + 0.5, dy + 0.5)
	# Posun je menší než čtvrtina buňky a nikdy nepřejde přes její střed.
	return direction * (0.44 if count == 1 else -0.44) if count in [1, 3] else Vector2.ZERO


static func _field(mask: TerrainMask, rect: Rect2i) -> PackedFloat32Array:
	var width := rect.size.x + 1 + 2 * HALO
	var height := rect.size.y + 1 + 2 * HALO
	var field := PackedFloat32Array()
	field.resize(width * height)
	for y in height:
		for x in width:
			var gx := rect.position.x + x - HALO
			var gy := rect.position.y + y - HALO
			var inside := _solid(mask, gx - 1, gy - 1) and _solid(mask, gx, gy - 1) \
				and _solid(mask, gx - 1, gy) and _solid(mask, gx, gy)
			field[y * width + x] = float(BEVEL_CELLS) if inside else 0.0
	for y in range(1, height):
		for x in range(1, width):
			var at := y * width + x
			field[at] = minf(field[at], minf(field[at - 1], field[at - width]) + 1)
	for y in range(height - 2, -1, -1):
		for x in range(width - 2, -1, -1):
			var at := y * width + x
			field[at] = minf(field[at], minf(field[at + 1], field[at + width]) + 1)
	return field
