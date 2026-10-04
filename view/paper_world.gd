class_name PaperWorld
extends Node2D
## 2D origami prezentace společné simulace. Herní pravidla sem nepatří.
##
## Pořadí kreslení: nebe → čtyři paralaxní vrstvy → herní rovina (terén, tráva,
## líheň, východ a pasti, postavy, přední pruhy vody a lávy, ústřižky) →
## popředí → ukazatele (štítek a šipka k východu). HUD je samostatná CanvasLayer.
## Herní rovina má jedinou transformaci z PaperCamera; vrstvy ji jen čtou.

const LAYER_DIR := "res://assets/origami/layers/"
const SKY_DATA := "res://assets/origami/layers/sky.json"
## [textura, posun, svislý posun, exponent zoomu, kotevní řádek, výška na obrazovce,
##  protažení dolů, opar]
const LAYERS := [
	["sky_decor", 0.03, 0.02, 0.04, 560.0, 0.42, false, 0.0],
	["mountains", 0.1, 0.06, 0.12, 640.0, 0.6, true, 0.2],
	["midground", 0.27, 0.16, 0.3, 720.0, 0.82, true, 0.11],
	["near", 0.5, 0.3, 0.5, 620.0, 1.0, true, 0.05],
]
const SKY := [Color("8fc3d6"), Color("b4d3d8"), Color("e6e4d2")]
## Kvalita efektů 0–2 (nízká, střední, vysoká): [zrnitost, světlo a paprsky, opar,
##  popředí, mraky a ptáci, lístky, strop ústřižků]. Herní rovina je vždy stejná.
const QUALITY := [
	[false, false, false, false, false, false, 80],
	[true, false, true, true, true, false, 160],
	[true, true, true, true, true, true, 260],
]

var camera: PaperCamera
var terrain: PaperTerrain
var grass: PaperGrass
var props: PaperProps
var actors: PaperActors
var fx: PaperFx
var foreground: PaperForeground
var plane: Node2D
var layers: Array[PaperParallax] = []
## Ukazatele k východu (štítek při přeletu, šipka u okraje).
var guide: PaperGuide
## Běžící přelet mapy (null = žádný).
var flyover: PaperFlyover
var quality := 2
## Vzhled kapitoly (PaperTheme): krajina, nebe, barvy terénu a trávy, světlo, počasí.
var theme := PaperTheme.BY_CHAPTER[0]
var _sim: LevelSim
var _sky: Node2D
var _sky_texture: GradientTexture2D
var _grain: Node2D
var _light: Node2D
var _light_material: ShaderMaterial
var _lightning := false


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
		layer.haze = spec[7]
		add_child(layer)
		layers.append(layer)
	add_sky_life(layers[0])
	plane = Node2D.new()
	plane.name = "GamePlane"
	add_child(plane)
	terrain = PaperTerrain.new()
	terrain.name = "Terrain"
	plane.add_child(terrain)
	grass = PaperGrass.new()
	grass.name = "Grass"
	plane.add_child(grass)
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
	# Teplé světlo slunce a paprsky přes celou scénu (pod HUDem).
	_light = Node2D.new()
	_light.name = "Light"
	_light_material = ShaderMaterial.new()
	_light_material.shader = preload("res://view/paper_light.gdshader")
	_light.material = _light_material
	_light.draw.connect(func() -> void:
		_light.draw_rect(Rect2(Vector2.ZERO, camera.viewport_size()), Color.WHITE))
	add_child(_light)
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
	guide = PaperGuide.new()
	guide.name = "Guide"
	guide.camera = camera
	add_child(guide)


## Mraky plují pomalu, každý jinou rychlostí; hejnko tří ptáčků mává křídly.
## Sdílí ji i pozadí menu (MenuBackdrop). `data_path` = sky.json tématu (ptáci nepovinní).
static func add_sky_life(sky: PaperParallax, data_path := SKY_DATA) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	for cloud: Dictionary in data["clouds"]:
		sky.drifters.append({"frames": [load("res://assets/origami/" + cloud["texture"])],
			"pos": Vector2(cloud["pos"][0], cloud["pos"][1]),
			"anchor": Vector2(cloud["anchor"][0], cloud["anchor"][1]),
			"speed": float(cloud["speed"]), "bob": 2.0, "phase": cloud["pos"][0] / 997.0})
	if not data.has("birds"):
		return
	var birds: Dictionary = data["birds"]
	var frames: Array = []
	for path: String in birds["frames"]:
		frames.append(load("res://assets/origami/" + path))
	var start := Vector2(birds["start"][0], birds["start"][1])
	for i in (birds["flock"] as Array).size():
		var member: Array = birds["flock"][i]
		sky.drifters.append({"frames": frames, "pos": start + Vector2(member[0], member[1]),
			"anchor": Vector2(birds["anchor"][0], birds["anchor"][1]), "scale": float(member[2]),
			"speed": float(birds["speed"]), "flap": 2, "bob": 6.0, "phase": i * 0.37})


## Přepne vzhled na téma kapitoly. Mění jen dekoraci; herní rovina a kamera zůstanou.
## Volá se před setup(): vykreslení dutin v terénu závisí na tématu.
func set_theme(name: String) -> void:
	if name == theme or not PaperTheme.THEMES.has(name):
		return
	theme = name
	var data := PaperTheme.data(name)
	var dir := PaperTheme.layer_dir(name)
	for i in layers.size():
		layers[i].texture = load(dir + LAYERS[i][0] + ".png")
	layers[0].drifters.clear()
	add_sky_life(layers[0], dir + "sky.json")
	_sky_texture.gradient.colors = PackedColorArray(data["sky"])
	terrain.set_palette(data["terrain"])
	terrain.fill_cavities = data.get("caves", true)
	grass.colors = data["grass"]
	grass.light = data["grass_light"]
	grass.queue_redraw()
	_lightning = data["lightning"]
	_light_material.set_shader_parameter("flash", 0.0)
	_apply_light()
	fx.weather = data["weather"]
	fx.weather_colors = data["weather_colors"]
	fx.terra_colors = data["scraps"]


func setup(sim: LevelSim) -> void:
	_sim = sim
	terrain.setup(sim.mask)
	grass.setup(sim.mask, terrain.surface_points)
	props.setup(sim)
	actors.setup(sim)
	fx.clear()
	fx.sim = sim
	foreground.sim = sim
	guide.setup(sim.spec.exits)
	flyover = null
	var focus := Vector2(sim.spec.width * 0.5, sim.spec.height * 0.45)
	if not sim.spec.hatches.is_empty():
		focus = Vector2(sim.spec.hatches[0]) + Vector2(60, 26)
	# Postavy mají být čitelné bez přibližování; telefon je fyzicky menší, začne ještě blíž.
	camera.setup(Vector2(sim.spec.width, sim.spec.height), focus,
		2.6 if DeviceProfile.touch_mode() else 2.0)
	_apply_camera()


func update_frame(alpha: float, events: Array[Dictionary], delta: float) -> void:
	terrain.sync()
	# Vlny a plameny: ve stop-motion se mění po dvou ticích jako postavy.
	if _sim != null:
		var ticks := _sim.tick_count
		var now := float(ticks - posmod(ticks, PaperActors.BOIL_TICKS)) if actors.stop_motion \
			else ticks + alpha
		terrain.set_time(now)
		_light_material.set_shader_parameter("time", now)
		if _lightning:
			_light_material.set_shader_parameter("flash", PaperTheme.lightning(ticks + alpha))
		for layer in layers:
			layer.time = now
		foreground.time = now
		grass.time = now
		var vp := camera.viewport_size()
		var top_left := camera.screen_to_logic(Vector2.ZERO)
		fx.view_rect = Rect2(top_left, camera.screen_to_logic(vp) - top_left)
	actors.alpha = alpha
	actors.update_views()
	props.alpha = alpha
	fx.alpha = alpha
	fx.handle_events(events)
	fx.advance(delta)
	foreground.update(get_process_delta_time())
	# Šipka k východu jen za hry; při přeletu východ ukazuje štítek.
	guide.edge_arrow = _sim != null and not _sim.finished and flyover == null
	guide.exit_tag = flyover.exit_tag() if flyover != null else 0.0
	guide.update(get_process_delta_time())
	_apply_camera()


## Přelet mapy: kamera začne u východu a přeletí na startovní záběr.
## Vrací false, když mise východ nemá (není co ukázat).
func start_flyover() -> bool:
	if _sim == null or _sim.spec.exits.is_empty():
		return false
	flyover = PaperFlyover.new(camera, Vector2(_sim.spec.exits[0]))
	_apply_camera()
	return true


## Posune přelet o skutečný čas; vrací true, dokud ještě běží. Dlouhý snímek
## (načítání, zásek telefonu) posune přelet nejvýš o MAX_STEP, takže pohled
## na východ nikdy nepřeskočí.
func advance_flyover(delta: float) -> bool:
	if flyover == null:
		return false
	flyover.advance(minf(delta, PaperFlyover.MAX_STEP))
	return not flyover.done


## Ukončí přelet (i předčasně): kamera skočí na startovní záběr.
func finish_flyover() -> void:
	if flyover == null:
		return
	flyover.finish()
	flyover = null
	guide.exit_tag = 0.0
	_apply_camera()


## Kvalita efektů (0 nízká, 1 střední, 2 vysoká). Mění jen ozdoby, ne hru.
func set_quality(level: int) -> void:
	quality = clampi(level, 0, QUALITY.size() - 1)
	var q: Array = QUALITY[quality]
	_grain.visible = q[0]
	_apply_light()
	for i in layers.size():
		layers[i].haze = float(LAYERS[i][7]) if q[2] else 0.0
		layers[i].show_drifters = q[4]
	foreground.visible = q[3]
	fx.petals = q[5]
	fx.weather_level = quality
	fx.max_scraps = q[6]


## Velikost rozhraní z nastavení: ukazatele k východu rostou s HUDem.
func set_ui_scale(value: float) -> void:
	guide.ui_scale = value


## Světlo a paprsky jen při vysoké kvalitě; blesk tématu (bouřka) vždy.
func _apply_light() -> void:
	var full: bool = QUALITY[quality][1]
	var light: Array = PaperTheme.data(theme)["light"]
	var warm: Color = light[0]
	_light.visible = full or _lightning
	_light_material.set_shader_parameter("warm", Vector3(warm.r, warm.g, warm.b))
	_light_material.set_shader_parameter("glow", light[1] if full else 0.0)
	_light_material.set_shader_parameter("rays", light[2] if full else 0.0)


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
	_light.queue_redraw()
	_grain.queue_redraw()


func _draw_sky() -> void:
	_sky.draw_texture_rect(_sky_texture, Rect2(Vector2.ZERO, camera.viewport_size()), false)
