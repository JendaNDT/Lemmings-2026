class_name PaperWorld
extends Node2D
## 2D origami prezentace společné simulace. Herní pravidla sem nepatří.
##
## Pořadí kreslení: nebe → čtyři paralaxní vrstvy → herní rovina (terén,
## líheň, východ a pasti, postavy, přední pruhy vody a lávy, ústřižky) →
## popředí. HUD je samostatná CanvasLayer.
## Herní rovina má jedinou transformaci z PaperCamera; vrstvy ji jen čtou.

const LAYER_DIR := "res://assets/origami/layers/"
## [textura, posun, svislý posun, exponent zoomu, kotevní řádek, výška na obrazovce]
const LAYERS := [
	["sky_decor", 0.03, 0.02, 0.04, 560.0, 0.42, false],
	["mountains", 0.1, 0.06, 0.12, 640.0, 0.6, true],
	["midground", 0.27, 0.16, 0.3, 720.0, 0.82, true],
	["near", 0.5, 0.3, 0.5, 620.0, 1.0, true],
]
const SKY := [Color("8fc3d6"), Color("b4d3d8"), Color("e6e4d2")]

var camera: PaperCamera
var terrain: PaperTerrain
var props: PaperProps
var actors: PaperActors
var fx: PaperFx
var foreground: PaperForeground
var plane: Node2D
var layers: Array[PaperParallax] = []
var _sim: LevelSim
var _sky: Node2D
var _sky_texture: GradientTexture2D
var _grain: Node2D


func _ready() -> void:
	camera = PaperCamera.new()
	camera.name = "Camera"
	# Kamera zpracuje vstup dřív než hra, takže transformace nezaostává o snímek.
	camera.process_priority = -10
	add_child(camera)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.38, 0.7])
	gradient.colors = PackedColorArray(SKY)
	_sky_texture = GradientTexture2D.new()
	_sky_texture.gradient = gradient
	_sky_texture.fill_from = Vector2(0, 0)
	_sky_texture.fill_to = Vector2(0, 1)
	_sky_texture.width = 4
	_sky_texture.height = 256
	_sky = Node2D.new()
	_sky.name = "Sky"
	_sky.draw.connect(_draw_sky)
	add_child(_sky)
	for spec: Array in LAYERS:
		var layer := PaperParallax.new()
		layer.name = String(spec[0]).capitalize().replace(" ", "")
		layer.setup(camera, load(LAYER_DIR + spec[0] + ".png"), spec[1], spec[2], spec[3], spec[4],
			spec[5], spec[6])
		add_child(layer)
		layers.append(layer)
	plane = Node2D.new()
	plane.name = "GamePlane"
	add_child(plane)
	terrain = PaperTerrain.new()
	terrain.name = "Terrain"
	plane.add_child(terrain)
	props = PaperProps.new()
	props.name = "Props"
	plane.add_child(props)
	actors = PaperActors.new()
	actors.name = "Actors"
	plane.add_child(actors)
	# Přední pruhy vody: ponořená část postavy je „pod hladinou“.
	plane.add_child(terrain.surface)
	fx = PaperFx.new()
	fx.name = "Fx"
	plane.add_child(fx)
	foreground = PaperForeground.new()
	foreground.name = "Foreground"
	foreground.camera = camera
	add_child(foreground)
	# Zrnitost papíru a vinětace sjednotí všechny vrstvy; HUD zůstane čistý.
	_grain = Node2D.new()
	_grain.name = "Grain"
	var grain_material := ShaderMaterial.new()
	grain_material.shader = preload("res://view/paper_grain.gdshader")
	grain_material.set_shader_parameter("paper_tex", PaperTerrain.PAPER)
	_grain.material = grain_material
	_grain.draw.connect(func() -> void:
		_grain.draw_rect(Rect2(Vector2.ZERO, camera.viewport_size()), Color.WHITE))
	add_child(_grain)


func setup(sim: LevelSim) -> void:
	_sim = sim
	terrain.setup(sim.mask)
	props.setup(sim)
	actors.setup(sim)
	fx.clear()
	fx.sim = sim
	foreground.sim = sim
	var focus := Vector2(sim.spec.width * 0.5, sim.spec.height * 0.45)
	if not sim.spec.hatches.is_empty():
		focus = Vector2(sim.spec.hatches[0]) + Vector2(60, 40)
	# Na telefonu je obrazovka fyzicky malá: začneme blíž, aby byly postavy čitelné.
	camera.setup(Vector2(sim.spec.width, sim.spec.height), focus,
		2.0 if DeviceProfile.touch_mode() else 1.5)
	_apply_camera()


func update_frame(alpha: float, events: Array[Dictionary], delta: float) -> void:
	terrain.sync()
	# Vlny a plameny: ve stop-motion se mění po dvou ticích jako postavy.
	if _sim != null:
		var ticks := _sim.tick_count
		terrain.set_time(float(ticks - posmod(ticks, PaperActors.STEP_TICKS)) if actors.stop_motion
			else ticks + alpha)
	actors.alpha = alpha
	actors.update_views()
	props.alpha = alpha
	fx.alpha = alpha
	fx.handle_events(events)
	fx.advance(delta)
	foreground.update(get_process_delta_time())
	_apply_camera()


func highlight(lem: Lemming) -> void:
	actors.hovered = lem


## Stop-motion pohyb postav a objektů (výchozí) ↔ plynulý pohyb mezi tiky.
func set_stop_motion(enabled: bool) -> void:
	actors.stop_motion = enabled
	props.stepped = enabled


func toggle_stop_motion() -> bool:
	set_stop_motion(not actors.stop_motion)
	return actors.stop_motion


func _apply_camera() -> void:
	camera.refresh()
	plane.transform = camera.game_transform()
	_sky.queue_redraw()
	_grain.queue_redraw()


func _draw_sky() -> void:
	_sky.draw_texture_rect(_sky_texture, Rect2(Vector2.ZERO, camera.viewport_size()), false)
