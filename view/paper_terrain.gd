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
## Vzdálenost od hladiny vody a lávy v texturě nebezpečí: 128 + 12 × px
## (kladně pod hladinou, záporně nad ní; plameny a záře sahají 10 px nad lávu).
const SURFACE_ZERO := 128
const SURFACE_STEP := 12
const SURFACE_REACH := 10

var mask: TerrainMask
var updates := 0
## Přední vrstva hladiny (kreslí se nad postavami): obdélník s vodou a lávou.
var surface: Node2D
var hazard_rect := Rect2i()
## Buňky původního povrchu vystaveného nebi (kde roste mech); z nich roste tráva.
var surface_points: Array[Vector2i] = []
var _mask_image: Image
var _mask_texture: ImageTexture
var _static_texture: ImageTexture
var _hazard_texture: ImageTexture
var _version := -1
var _material: ShaderMaterial
var _surface_material: ShaderMaterial


func _init() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("paper_tex", PAPER)
	_material.set_shader_parameter("noise_tex", NOISE)
	material = _material
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_surface_material = ShaderMaterial.new()
	_surface_material.shader = SHADER
	_surface_material.set_shader_parameter("paper_tex", PAPER)
	_surface_material.set_shader_parameter("noise_tex", NOISE)
	_surface_material.set_shader_parameter("debug_mode", 2)
	surface = Node2D.new()
	surface.name = "HazardSurface"
	surface.material = _surface_material
	surface.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	surface.draw.connect(_draw_surface)


func _notification(what: int) -> void:
	# Bez PaperWorld (např. v testu) přední vrstva nikdy nevstoupí do stromu.
	if what == NOTIFICATION_PREDELETE and is_instance_valid(surface) and surface.get_parent() == null:
		surface.free()


func setup(terrain: TerrainMask) -> void:
	mask = terrain
	_mask_image = Image.create_from_data(mask.width, mask.height, false, Image.FORMAT_RGBA8, mask.data)
	# Mipmapy masky = levné rozmazání pro měkké stíny a šířku vláknitých okrajů.
	_mask_image.generate_mipmaps()
	_mask_texture = ImageTexture.create_from_image(_mask_image)
	var static_image := build_static(mask)
	_static_texture = ImageTexture.create_from_image(static_image)
	surface_points = exposed_surface(static_image)
	var hazards := build_hazards(mask)
	hazard_rect = _hazard_bounds(hazards)
	# Mipmapy = rozmazaná láva pro teplou záři na okolním terénu.
	hazards.generate_mipmaps()
	_hazard_texture = ImageTexture.create_from_image(hazards)
	_version = mask.version
	for target: ShaderMaterial in [_material, _surface_material]:
		target.set_shader_parameter("mask_tex", _mask_texture)
		target.set_shader_parameter("mask_soft", _mask_texture)
		target.set_shader_parameter("static_tex", _static_texture)
		target.set_shader_parameter("hazard_tex", _hazard_texture)
		target.set_shader_parameter("hazard_soft", _hazard_texture)
		target.set_shader_parameter("mask_size", Vector2(mask.width, mask.height))
		target.set_shader_parameter("band_offset", float(mask.width % 6))
	queue_redraw()
	surface.queue_redraw()


## Herní čas pro vlny a plameny (ve stop-motion po celých ticích).
func set_time(ticks: float) -> void:
	_material.set_shader_parameter("sim_time", ticks)
	_surface_material.set_shader_parameter("sim_time", ticks)


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


## Přední průsvitná vrstva vody a hřebeny lávy jen v oblasti nebezpečí.
func _draw_surface() -> void:
	if _mask_texture == null or hazard_rect.size == Vector2i.ZERO:
		return
	# Výřez textury masky: UV zůstane v souřadnicích celé masky, shader počítá stejně.
	var rect := Rect2(hazard_rect)
	surface.draw_texture_rect_region(_mask_texture, rect, rect)


## R = voda, G = láva: vzdálenost od hladiny (SURFACE_ZERO ± SURFACE_STEP × px),
## 0 = nic. B = jednosměrná zeď doleva, A = doprava (255). Hladina leží
## na horní hraně nejvyšší buňky sloupce, takže kresba sedí na pravidla.
static func build_hazards(source: TerrainMask) -> Image:
	var w := source.width
	var h := source.height
	var bpp := TerrainMask.BYTES_PER_PIXEL
	var out := PackedByteArray()
	out.resize(w * h * 4)
	out.fill(0)
	for x in w:
		for channel in 2:
			var kind := TerrainMask.Special.WATER if channel == 0 else TerrainMask.Special.LAVA
			var top := -1
			for y in h:
				var i := y * w + x
				if source.data[i * bpp + 3] != kind:
					top = -1
					continue
				if top < 0:
					top = y
					for k in range(1, SURFACE_REACH + 1):
						var above := ((y - k) * w + x) * 4 + channel
						if y - k >= 0 and out[above] == 0:
							out[above] = SURFACE_ZERO - SURFACE_STEP * k
				out[i * 4 + channel] = mini(SURFACE_ZERO + SURFACE_STEP * (y - top + 1), 255)
		for y in h:
			var i := y * w + x
			var special := source.data[i * bpp + 3]
			if special == TerrainMask.Special.ONE_WAY_LEFT:
				out[i * 4 + 2] = 255
			elif special == TerrainMask.Special.ONE_WAY_RIGHT:
				out[i * 4 + 3] = 255
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)


## Obdélník s vodou a lávou (včetně prostoru pro plameny nad hladinou).
static func _hazard_bounds(image: Image) -> Rect2i:
	var rect := Rect2i()
	var found := false
	var data := image.get_data()
	var w := image.get_width()
	for i in data.size() / 4:
		if data[i * 4] == 0 and data[i * 4 + 1] == 0:
			continue
		var cell := Rect2i(i % w, i / w, 1, 1)
		rect = cell if not found else rect.merge(cell)
		found = true
	return rect.grow(2).intersection(Rect2i(0, 0, w, image.get_height())) if found else Rect2i()


## Horní buňky povrchu vystaveného nebi (R pevné, hloubka 0) ze statické textury.
static func exposed_surface(static_image: Image) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var data := static_image.get_data()
	var w := static_image.get_width()
	for i in data.size() / 4:
		if data[i * 4] == 255 and data[i * 4 + 3] == 0:
			out.append(Vector2i(i % w, i / w))
	return out


## R = původní zem, G = vnitřek jeskyně, A = hloubka pod povrchem vystaveným nebi (×16).
## Jeskyně je prázdné místo sevřené zemí (viz CAVE_REACH_*) nebo uzavřená dutina,
## kam se od horního ani bočních okrajů levelu nedá dostat. Pod vodou a lávou mech neroste.
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
	# Uzavřené dutiny: prázdná místa nedosažitelná od horního a bočních okrajů.
	var open := PackedByteArray()
	open.resize(w * h)
	var queue := PackedInt32Array()
	for x in w:
		if not solid[x]:
			open[x] = 1
			queue.append(x)
	for y in range(1, h):
		for x in [0, w - 1]:
			var i: int = y * w + x
			if not solid[i] and not open[i]:
				open[i] = 1
				queue.append(i)
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var x := i % w
		for next in [i - w, i + w, i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1]:
			if next >= 0 and next < w * h and not solid[next] and not open[next]:
				open[next] = 1
				queue.append(next)
	for i in w * h:
		if not solid[i] and not open[i]:
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
				var special := source.data[i * bpp + 3]
				var liquid := special == TerrainMask.Special.WATER or special == TerrainMask.Special.LAVA
				gap = 0 if liquid else mini(gap + 1, 100000)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)
