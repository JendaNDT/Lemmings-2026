class_name MenuBackdrop
extends Node2D
## Pozadí menu: stejná papírová krajina jako ve hře (nebe, paralaxní vrstvy,
## mraky a ptáci, světlo a zrnitost), pomalu proplouvá do stran. Bez simulace.

## Jak daleko a jak rychle kamera krajinou proplouvá (logické px, s).
const LEVEL_SIZE := Vector2(1400, 260)
const DRIFT := 420.0
const PERIOD := 90.0

var camera: PaperCamera
var layers: Array[PaperParallax] = []
var _time := 0.0
var _sky: Node2D
var _sky_texture: GradientTexture2D
var _light: Node2D
var _light_material: ShaderMaterial
var _grain: Node2D


func _ready() -> void:
	camera = PaperCamera.new()
	camera.name = "Camera"
	camera.input_enabled = false
	camera.top_padding = 0.0
	camera.bottom_padding = 0.0
	add_child(camera)
	camera.setup(LEVEL_SIZE, LEVEL_SIZE * 0.5, 1.0)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.38, 0.7])
	gradient.colors = PackedColorArray(PaperWorld.SKY)
	_sky_texture = GradientTexture2D.new()
	_sky_texture.gradient = gradient
	_sky_texture.fill_to = Vector2(0, 1)
	_sky_texture.width = 4
	_sky_texture.height = 256
	_sky = Node2D.new()
	_sky.name = "Sky"
	_sky.draw.connect(func() -> void:
		_sky.draw_texture_rect(_sky_texture, Rect2(Vector2.ZERO, camera.viewport_size()), false))
	add_child(_sky)
	for spec: Array in PaperWorld.LAYERS:
		var layer := PaperParallax.new()
		layer.name = String(spec[0]).capitalize().replace(" ", "")
		layer.setup(camera, load(PaperWorld.LAYER_DIR + spec[0] + ".png"), spec[1], spec[2],
			spec[3], spec[4], spec[5], spec[6])
		layer.haze = spec[7]
		add_child(layer)
		layers.append(layer)
	PaperWorld.add_sky_life(layers[0])
	_light = Node2D.new()
	_light.name = "Light"
	_light_material = ShaderMaterial.new()
	_light_material.shader = preload("res://view/paper_light.gdshader")
	_light.material = _light_material
	_light.draw.connect(func() -> void:
		_light.draw_rect(Rect2(Vector2.ZERO, camera.viewport_size()), Color.WHITE))
	add_child(_light)
	_grain = Node2D.new()
	_grain.name = "Grain"
	var grain_material := ShaderMaterial.new()
	grain_material.shader = preload("res://view/paper_grain.gdshader")
	grain_material.set_shader_parameter("paper_tex", PaperTerrain.PAPER)
	_grain.material = grain_material
	_grain.draw.connect(func() -> void:
		_grain.draw_rect(Rect2(Vector2.ZERO, camera.viewport_size()), Color.WHITE))
	add_child(_grain)


## Stejné kvalitativní stupně jako ve hře (PaperWorld.QUALITY).
func set_quality(level: int) -> void:
	var q: Array = PaperWorld.QUALITY[clampi(level, 0, PaperWorld.QUALITY.size() - 1)]
	_grain.visible = q[0]
	_light.visible = q[1]
	for i in layers.size():
		layers[i].haze = float(PaperWorld.LAYERS[i][7]) if q[2] else 0.0
		layers[i].show_drifters = q[4]


func _process(delta: float) -> void:
	_time += delta
	camera.focus = Vector2(LEVEL_SIZE.x * 0.5 + sin(_time * TAU / PERIOD) * DRIFT,
		LEVEL_SIZE.y * 0.5)
	camera.refresh()
	# Mraky a ptáci počítají v herních ticích.
	var ticks := _time * SimConst.TICKS_PER_SECOND
	for layer in layers:
		layer.time = ticks
	_light_material.set_shader_parameter("time", ticks)
	_sky.queue_redraw()
	_light.queue_redraw()
	_grain.queue_redraw()
