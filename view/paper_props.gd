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
var data: Dictionary
## Délka kůlů a žebříku pod každou líhní (podle původního terénu).
var _supports: Array[float] = []


func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func setup(level_sim: LevelSim) -> void:
	sim = level_sim
	_supports.clear()
	for hatch in sim.spec.hatches:
		var ground := hatch.y + 2
		while ground < sim.mask.height and not sim.mask.is_solid(hatch.x - 10, ground):
			ground += 1
		_supports.append(float(mini(ground - hatch.y, 80)))
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var now := sim.tick_count + alpha
	for i in sim.spec.hatches.size():
		_draw_hatch(Vector2(sim.spec.hatches[i]), _supports[i], now)
	for point in sim.spec.exits:
		_draw_exit(Vector2(point), now)


func _draw_hatch(at: Vector2, support: float, now: float) -> void:
	var info: Dictionary = data["hatch"]
	var s := float(info["scale"])
	var anchor := Vector2(info["anchor"][0], info["anchor"][1])
	# Kůly a žebřík až k původní zemi.
	var post_w := HATCH_POST.get_width() / s
	for post: Array in info["posts"]:
		var top := at + Vector2(float(post[0]), float(post[1]))
		var length := support - float(post[1])
		draw_texture_rect_region(HATCH_POST, Rect2(top, Vector2(post_w, length)),
			Rect2(0, 0, HATCH_POST.get_width(), length * s))
	var ladder_size := Vector2(HATCH_LADDER.get_width(), HATCH_LADDER.get_height()) / s
	var ladder_top := at + Vector2(float(info["ladder_x"]), 0.4)
	draw_set_transform(ladder_top, -0.12, Vector2.ONE)
	draw_texture_rect_region(HATCH_LADDER, Rect2(Vector2.ZERO, Vector2(ladder_size.x, support)),
		Rect2(0, 0, HATCH_LADDER.get_width(), support * s))
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


func _draw_exit(at: Vector2, now: float) -> void:
	var info: Dictionary = data["exit"]
	var s := float(info["scale"])
	var anchor := Vector2(info["anchor"][0], info["anchor"][1])
	var glow := 0.18 + 0.06 * sin(now * 0.35)
	draw_set_transform(at + Vector2(0.5, -6.0), 0.0, Vector2(1.0, 1.35))
	draw_circle(Vector2.ZERO, 9.0, Color(GLOW, glow * 0.5))
	draw_circle(Vector2.ZERO, 6.0, Color(GLOW, glow))
	draw_set_transform_matrix(Transform2D.IDENTITY)
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
