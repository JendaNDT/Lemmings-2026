class_name ClayTerrain
extends Node3D
## Každý čtenář sleduje revize samostatně; změny se nespotřebovávají.

const NAMES := ["clay_earth", "clay_grass", "brushed_steel", "clay_brick"]
const DRESSING_HALO := 8

var mask: TerrainMask
var grass := PackedByteArray()
var chunks: Array[MeshInstance3D] = []
var dressing: Array[Node3D] = []
var materials: Array[ShaderMaterial] = []
var last_rebuilt: Array[int] = []
var last_update_usec := 0
var total_rebuilds := 0
var _versions := PackedInt32Array()
var _texture: ImageTexture
var _version := -1
var _previous_data := PackedByteArray()


func setup(terrain: TerrainMask) -> void:
	for child in get_children():
		child.free()
	chunks.clear()
	dressing.clear()
	materials.clear()
	mask = terrain
	_version = -1
	_previous_data = PackedByteArray()
	total_rebuilds = 0
	_versions.resize(mask.region_versions.size())
	_versions.fill(-1)
	grass.resize(mask.width * mask.height)
	grass.fill(0)
	# Zeleň zůstává pouze na původním povrchu, v čerstvých tunelech neroste.
	for x in mask.width:
		for y in mask.height:
			if mask.data[(y * mask.width + x) * 4] != 0:
				for dy in range(y, mini(y + 4, mask.height)):
					grass[dy * mask.width + x] = 1
				break
	_texture = ImageTexture.create_from_image(Image.create_from_data(
		mask.width, mask.height, false, Image.FORMAT_RGBA8, mask.data))
	for index in NAMES.size():
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://view/clay_terrain.gdshader")
		for channel in {"color_map": "albedo", "normal_map": "normal", "orm_map": "orm"}:
			var suffix: String = {"color_map": "albedo", "normal_map": "normal", "orm_map": "orm"}[channel]
			mat.set_shader_parameter(channel, load("res://assets/clay/textures/%s/%s_%s.png" %
				[NAMES[index], NAMES[index], suffix]))
		mat.set_shader_parameter("terrain_mask", _texture)
		mat.set_shader_parameter("mask_size", Vector2(mask.width, mask.height))
		mat.set_shader_parameter("material_kind", index)
		mat.set_shader_parameter("base_color", [Color("b37447"), Color("548b37"),
			Color("72818b"), Color("c9b78f")][index])
		materials.append(mat)
	for index in _versions.size():
		var chunk := MeshInstance3D.new()
		chunk.name = "Region%d" % index
		add_child(chunk)
		chunks.append(chunk)
		dressing.append(null)
	sync()


func sync() -> void:
	last_rebuilt.clear()
	last_update_usec = 0
	if mask == null or mask.version == _version:
		return
	var started := Time.get_ticks_usec()
	_texture.update(Image.create_from_data(mask.width, mask.height,
		false, Image.FORMAT_RGBA8, mask.data))
	var dirty := _dirty_regions()
	for index in dirty:
		var mesh := ClayMesher.build(mask, grass, index, materials)
		chunks[index].mesh = mesh if mesh.get_surface_count() > 0 else null
		if is_instance_valid(dressing[index]):
			dressing[index].free()
		dressing[index] = ClayDressing.build(mask, grass, index)
		add_child(dressing[index])
		_versions[index] = mask.region_versions[index]
		last_rebuilt.append(index)
		total_rebuilds += 1
	_version = mask.version
	_previous_data = mask.data.duplicate()
	last_update_usec = Time.get_ticks_usec() - started


func _dirty_regions() -> Array[int]:
	var result: Array[int] = []
	if _previous_data.is_empty():
		for index in _versions.size():
			result.append(index)
		return result
	var affected := {}
	for index in _versions.size():
		if _versions[index] == mask.region_versions[index]:
			continue
		_versions[index] = mask.region_versions[index]
		var x0 := index % mask.region_columns * TerrainMask.REGION_SIZE
		var y0 := index / mask.region_columns * TerrainMask.REGION_SIZE
		for y in range(y0, mini(y0 + TerrainMask.REGION_SIZE, mask.height)):
			for x in range(x0, mini(x0 + TerrainMask.REGION_SIZE, mask.width)):
				var offset := (y * mask.width + x) * 4
				if mask.data[offset] == _previous_data[offset] \
						and mask.data[offset + 1] == _previous_data[offset + 1] \
						and mask.data[offset + 2] == _previous_data[offset + 2]:
					continue
				for ny in range(maxi(0, y - DRESSING_HALO) / TerrainMask.REGION_SIZE,
						mini(mask.height - 1, y + DRESSING_HALO) / TerrainMask.REGION_SIZE + 1):
					for nx in range(maxi(0, x - DRESSING_HALO) / TerrainMask.REGION_SIZE,
							mini(mask.width - 1, x + DRESSING_HALO) / TerrainMask.REGION_SIZE + 1):
						affected[ny * mask.region_columns + nx] = true
	for index: int in affected:
		result.append(index)
	result.sort()
	return result


func set_impacts(values: PackedVector4Array) -> void:
	for mat in materials:
		mat.set_shader_parameter("impacts", values)
