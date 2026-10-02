class_name LevelLoader
extends RefCounted
## Převádí scénu levelu (uzly z editoru) na čistá data pro simulaci.


static func build_spec(level: LevelDefinition) -> LevelSpec:
	var spec := LevelSpec.new()
	spec.title = level.title
	spec.width = level.size.x
	spec.height = level.size.y
	spec.lemming_count = level.lemming_count
	spec.save_required = level.save_required
	spec.release_rate = level.release_rate
	spec.time_limit_seconds = level.time_limit_seconds
	spec.skills = level.skill_counts()
	for node in _all_descendants(level):
		if node is LemmingHatch:
			spec.hatches.append(_cell_of(node, level))
		elif node is LemmingExit:
			spec.exits.append(_cell_of(node, level))
	return spec


static func build_mask(level: LevelDefinition) -> TerrainMask:
	var mask := TerrainMask.new(level.size.x, level.size.y)
	for node in _all_descendants(level):
		if node is TerrainShape:
			var shape := node as TerrainShape
			var xf := _transform_in_level(shape, level)
			var points := PackedVector2Array()
			for p in shape.polygon:
				points.append(xf * (p + shape.offset))
			mask.paint_polygon(points, shape.kind)
	return mask


## Schová nakreslené tvary terénu – ve hře terén kreslí TerrainView.
static func hide_terrain_shapes(level: LevelDefinition) -> void:
	for node in _all_descendants(level):
		if node is TerrainShape:
			(node as TerrainShape).visible = false


static func _all_descendants(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	_collect(root, out)
	return out


static func _collect(node: Node, out: Array[Node]) -> void:
	for child in node.get_children():
		out.append(child)
		_collect(child, out)


## Poskládá transformace od uzlu až ke kořeni levelu (funguje i mimo strom scény).
static func _transform_in_level(node: Node, level: Node) -> Transform2D:
	var xf := Transform2D.IDENTITY
	var current := node
	while current != null and current != level:
		if current is Node2D:
			xf = (current as Node2D).transform * xf
		current = current.get_parent()
	return xf


static func _cell_of(node: Node, level: Node) -> Vector2i:
	var p := _transform_in_level(node, level).origin
	return Vector2i(roundi(p.x), roundi(p.y))
