class_name PaperProps
extends Node2D
## Papírová líheň a východ v herní rovině (stejná transformace jako terén).
## Dvířka a vlajka se hýbou podle simulačního času; pauza je zastaví.

const DATA_PATH := "res://assets/origami/props/props.json"
const HATCH := preload("res://assets/origami/props/hatch.png")
const HATCH_DOOR := preload("res://assets/origami/props/hatch_door.png")
const HATCH_POST := preload("res://assets/origami/props/hatch_post.png")
const HATCH_LADDER := preload("res://assets/origami/props/hatch_ladder.png")
const EXIT := preload("res://assets/origami/props/exit.png")
const EXIT_FLAG := preload("res://assets/origami/props/exit_flag.png")
const GLOW := Color(1.0, 0.86, 0.5)

var sim: LevelSim
var alpha := 1.0
## Stop-motion: dvířka, vlajka a záře se mění po celých ticích.
var stepped := true
var data: Dictionary
## Rostlinky na povrchu: [x, y, druh]. Zmizí, když pod nimi zmizí zem.
var plants: Array[Vector3i] = []
## Délka kůlů a žebříku pod každou líhní (podle původního terénu).
var _supports: Array[float] = []
var _plant_textures: Array[Texture2D] = []


func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	for item: Dictionary in data["plants"]:
		_plant_textures.append(load("res://assets/origami/" + item["texture"]))
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Opakování by u horních hran prosvítalo spodním řádkem; dlaždice skládáme ručně.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED


func setup(level_sim: LevelSim) -> void:
	sim = level_sim
	_supports.clear()
	for hatch in sim.spec.hatches:
		var ground := hatch.y + 2
		while ground < sim.mask.height and not sim.mask.is_solid(hatch.x - 10, ground):
			ground += 1
		_supports.append(float(mini(ground - hatch.y, 80)))
	_place_plants()
	queue_redraw()


## Rovná místa původního povrchu, dál od líhně a východu; výběr je deterministický.
func _place_plants() -> void:
	plants.clear()
	var mask := sim.mask
	var keep_clear: Array[Vector2i] = []
	keep_clear.append_array(sim.spec.hatches)
	keep_clear.append_array(sim.spec.exits)
	var last_x := -100
	for x in range(6, mask.width - 6):
		if x - last_x < 24 or posmod(x * 7919 + 13, 97) > 9:
			continue
		var y := _surface(x)
		if y < 0 or absi(_surface(x - 3) - y) > 1 or absi(_surface(x + 3) - y) > 1:
			continue
		var near := false
		for point in keep_clear:
			near = near or (absi(point.x - x) < 18 and absi(point.y - y) < 30)
		if near:
			continue
		plants.append(Vector3i(x, y, posmod(x * 31 + y, _plant_textures.size())))
		last_x = x


func _surface(x: int) -> int:
	for y in range(1, sim.mask.height):
		if sim.mask.is_solid(x, y):
			return y if y >= 12 and not sim.mask.has_solid_in_rect(x, y - 12, 1, 11) else -1
	return -1


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var now := float(sim.tick_count) if stepped else sim.tick_count + alpha
	for plant in plants:
		if not sim.mask.is_solid(plant.x - 1, plant.y) or not sim.mask.is_solid(plant.x + 1, plant.y) \
				or sim.mask.is_solid(plant.x, plant.y - 2):
			continue
		var info: Dictionary = data["plants"][plant.z]
		var tex := _plant_textures[plant.z]
		var anchor := Vector2(info["anchor"][0], info["anchor"][1])
		var size := tex.get_size() / float(data["hatch"]["scale"])
		draw_texture_rect(tex, Rect2(Vector2(plant.x + 0.5, plant.y) - anchor, size), false)
	for i in sim.spec.hatches.size():
		_draw_hatch(Vector2(sim.spec.hatches[i]), _supports[i], now)
	for point in sim.spec.exits:
		_draw_exit(Vector2(point), now)


func _draw_hatch(at: Vector2, support: float, now: float) -> void:
	var info: Dictionary = data["hatch"]
	var s := float(info["scale"])
	var anchor := Vector2(info["anchor"][0], info["anchor"][1])
	# Kůly a žebřík až k původní zemi.
	for post: Array in info["posts"]:
		var top := at + Vector2(float(post[0]), float(post[1]))
		_tile_down(HATCH_POST, top, support - float(post[1]), s)
	draw_set_transform(at + Vector2(float(info["ladder_x"]), 0.4), -0.12, Vector2.ONE)
	_tile_down(HATCH_LADDER, Vector2.ZERO, support, s)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_texture_rect(HATCH, Rect2(at - anchor, HATCH.get_size() / s), false)
	# Padací dvířka se otevřou těsně před prvním vypuštěním.
	var open := clampf((now - (SimConst.HATCH_OPEN_TICKS - 14)) / 10.0, 0.0, 1.0)
	var half := Vector2(5.5, HATCH_DOOR.get_height() / s)
	var angle := smoothstep(0.0, 1.0, open) * 1.35
	draw_set_transform(at + Vector2(-5.5, 0.0), angle, Vector2.ONE)
	draw_texture_rect(HATCH_DOOR, Rect2(Vector2.ZERO, half), false)
	draw_set_transform(at + Vector2(5.5, 0.0), -angle, Vector2.ONE)
	draw_texture_rect(HATCH_DOOR, Rect2(Vector2(-half.x, 0.0), half), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Svislé skládání dlaždice (kůl, žebřík) do dané délky; poslední kus se ořízne.
func _tile_down(tex: Texture2D, top: Vector2, length: float, s: float) -> void:
	var size := tex.get_size() / s
	var y := 0.0
	while y < length - 0.01:
		var piece := minf(size.y, length - y)
		draw_texture_rect_region(tex, Rect2(top + Vector2(0, y), Vector2(size.x, piece)),
			Rect2(0, 0, tex.get_width(), piece * s))
		y += piece


func _draw_exit(at: Vector2, now: float) -> void:
	var info: Dictionary = data["exit"]
	var s := float(info["scale"])
	var anchor := Vector2(info["anchor"][0], info["anchor"][1])
	# Teplá záře ze dveří jen nad prahem (pulzuje podle herního času).
	var glow := 0.18 + 0.06 * sin(now * 0.35)
	for layer in [[10.0, 0.5], [6.5, 1.0]]:
		var radius: float = layer[0]
		var arc := PackedVector2Array()
		for k in 17:
			var angle := PI + k * PI / 16.0
			arc.append(at + Vector2(0.5 + cos(angle) * radius, sin(angle) * radius * 1.5))
		draw_colored_polygon(arc, Color(GLOW, glow * float(layer[1])))
	draw_texture_rect(EXIT, Rect2(at - anchor, EXIT.get_size() / s), false)
	var flag: Dictionary = info["flag"]
	var pole := at + Vector2(flag["pole_top"][0], flag["pole_top"][1])
	var size := Vector2(EXIT_FLAG.get_width(), EXIT_FLAG.get_height()) / s
	# Vlajka vlaje: střídavé zúžení a zkosení podle herního času.
	var wave := sin(now * 0.45)
	var xf := Transform2D(Vector2(0.92 + 0.08 * wave, 0.05 * wave),
		Vector2(0.0, 1.0), pole)
	draw_set_transform_matrix(xf)
	draw_texture_rect(EXIT_FLAG, Rect2(Vector2.ZERO, size), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)
