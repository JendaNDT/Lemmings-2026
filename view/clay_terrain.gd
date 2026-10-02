class_name ClayTerrain
extends Node3D
## Každý čtenář sleduje revize samostatně; změny se nespotřebovávají.

const NAMES := ["clay_earth", "clay_grass", "brushed_steel", "clay_brick"]

var mask: TerrainMask
var grass := PackedByteArray()
var chunks: Array[MeshInstance3D] = []
var materials: Array[ShaderMaterial] = []
var last_rebuilt: Array[int] = []
var last_update_usec := 0
var total_rebuilds := 0
var _versions := PackedInt32Array()
var _texture: ImageTexture
var _version := -1


func setup(terrain: TerrainMask) -> void:
	for child in get_children():
		child.free()
	chunks.clear()
	materials.clear()
	mask = terrain
	_version = -1
	total_rebuilds = 0
	_versions.resize(mask.region_versions.size())
	_versions.fill(-1)
	grass.resize(mask.width * mask.height)
	grass.fill(0)
	# Zeleň zůstává pouze na původním povrchu, v čerstvých tunelech neroste.
	for x in mask.width:
		for y in mask.height:
			if mask.data[(y * mask.width + x) * 4] != 0:
				for dy in range(y, mini(y + 2, mask.height)):
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
		mat.set_shader_parameter("base_color", [Color("9e4a21"), Color("579634"),
			Color("8a9299"), Color("bab08c")][index])
		materials.append(mat)
	for index in _versions.size():
		var chunk := MeshInstance3D.new()
		chunk.name = "Region%d" % index
		add_child(chunk)
		chunks.append(chunk)
	sync()


func sync() -> void:
	last_rebuilt.clear()
	last_update_usec = 0
	if mask == null or mask.version == _version:
		return
	var started := Time.get_ticks_usec()
	_texture.update(Image.create_from_data(mask.width, mask.height,
		false, Image.FORMAT_RGBA8, mask.data))
	for index in _versions.size():
		if _versions[index] == mask.region_versions[index]:
			continue
		var mesh := ClayMesher.build(mask, grass, index, materials)
		chunks[index].mesh = mesh if mesh.get_surface_count() > 0 else null
		_versions[index] = mask.region_versions[index]
		last_rebuilt.append(index)
		total_rebuilds += 1
	_version = mask.version
	last_update_usec = Time.get_ticks_usec() - started


func set_impacts(values: PackedVector4Array) -> void:
	for mat in materials:
		mat.set_shader_parameter("impacts", values)
