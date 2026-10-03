class_name PaperTerrain
extends Node2D
## Papírový terén kreslený shaderem přímo z masky simulace.
##
## Maska je jediný zdroj kolizí; zde se jen čte. Statická textura si pamatuje
## původní povrch (mech nepřirůstá v tunelech) a vnitřky jeskyní (zadní stěna).

const SHADER := preload("res://view/paper_terrain.gdshader")
const PAPER := preload("res://assets/origami/paper/paper_fiber.png")
const NOISE := preload("res://assets/origami/paper/noise_smooth.png")
## Vnitřek jeskyně: pevná zem nad, pod i po stranách v těchto vzdálenostech.
const CAVE_REACH_Y := 60
const CAVE_REACH_X := 120
## Mech roste jen na runech, nad kterými je aspoň tolik volného místa.
const SKY_GAP := 24

var mask: TerrainMask
var updates := 0
var _mask_image: Image
var _mask_texture: ImageTexture
var _static_texture: ImageTexture
var _version := -1
var _material: ShaderMaterial


func _init() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("paper_tex", PAPER)
	_material.set_shader_parameter("noise_tex", NOISE)
	material = _material
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func setup(terrain: TerrainMask) -> void:
	mask = terrain
	_mask_image = Image.create_from_data(mask.width, mask.height, false, Image.FORMAT_RGBA8, mask.data)
	# Mipmapy masky = levné rozmazání pro měkké stíny a šířku vláknitých okrajů.
	_mask_image.generate_mipmaps()
	_mask_texture = ImageTexture.create_from_image(_mask_image)
	_static_texture = ImageTexture.create_from_image(build_static(mask))
	_version = mask.version
	_material.set_shader_parameter("mask_tex", _mask_texture)
	_material.set_shader_parameter("mask_soft", _mask_texture)
	_material.set_shader_parameter("static_tex", _static_texture)
	_material.set_shader_parameter("mask_size", Vector2(mask.width, mask.height))
	_material.set_shader_parameter("band_offset", float(mask.width % 6))
	queue_redraw()


## Kontrolní režim: jen bílý pevný terén (pro porovnání s maskou na snímku).
func set_debug_mask(enabled: bool) -> void:
	_material.set_shader_parameter("debug_mode", 1 if enabled else 0)


## Obnoví texturu, pokud se maska změnila. Revize se jen čtou, nespotřebují.
func sync() -> void:
	if mask == null or mask.version == _version:
		return
	_version = mask.version
	_mask_image.set_data(mask.width, mask.height, false, Image.FORMAT_RGBA8, mask.data)
	_mask_image.generate_mipmaps()
	_mask_texture.update(_mask_image)
	updates += 1


func _draw() -> void:
	if _mask_texture != null:
		draw_texture_rect(_mask_texture, Rect2(Vector2.ZERO, Vector2(mask.width, mask.height)), false)


## R = původní zem, G = vnitřek jeskyně, A = hloubka pod povrchem vystaveným nebi (×16).
static func build_static(source: TerrainMask) -> Image:
	var w := source.width
	var h := source.height
	var bpp := TerrainMask.BYTES_PER_PIXEL
	var solid := PackedByteArray()
	solid.resize(w * h)
	for i in w * h:
		solid[i] = 1 if source.data[i * bpp] != 0 else 0
	var out := PackedByteArray()
	out.resize(w * h * 4)
	out.fill(0)
	# Vzdálenost k nejbližší zemi nad a pod (po sloupcích).
	var above := PackedInt32Array()
	above.resize(w * h)
	var below := PackedInt32Array()
	below.resize(w * h)
	for x in w:
		var last := -100000
		for y in h:
			var i := y * w + x
			if solid[i]:
				last = y
			above[i] = y - last
		last = 100000
		for y in range(h - 1, -1, -1):
			var i := y * w + x
			if solid[i]:
				last = y
			below[i] = last - y
	# Vzdálenost k zemi vlevo a vpravo (po řádcích) → vnitřek jeskyně.
	var left_dist := PackedInt32Array()
	left_dist.resize(w)
	for y in h:
		var left := -100000
		var row := y * w
		for x in w:
			if solid[row + x]:
				left = x
			left_dist[x] = x - left
		var right := 100000
		for x in range(w - 1, -1, -1):
			var i := row + x
			if solid[i]:
				right = x
				out[i * 4] = 255
				continue
			if left_dist[x] <= CAVE_REACH_X and right - x <= CAVE_REACH_X \
					and above[i] <= CAVE_REACH_Y and below[i] <= CAVE_REACH_Y:
				out[i * 4 + 1] = 255
	# Hloubka pod povrchem: mech jen tam, kde je nad runem dost volného nebe
	# a nejde o dno jeskyně.
	for x in w:
		var run_start := -1
		var exposed := false
		var gap := 100000
		for y in h:
			var i := y * w + x
			if solid[i]:
				if run_start < 0:
					run_start = y
					exposed = gap >= SKY_GAP and (y == 0 or out[(i - w) * 4 + 1] == 0)
				var depth := (y - run_start) * 16 if exposed else 255
				out[i * 4 + 3] = mini(depth, 255)
				gap = 0
			else:
				run_start = -1
				gap = mini(gap + 1, 100000)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)
