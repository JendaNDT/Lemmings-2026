class_name PaperForeground
extends Node2D
## Rostliny v popředí: nízký rám u spodní lišty, posun rychlejší než herní
## rovina. Trs se zprůhlední, když je za ním postavička, a nikdy nepřijímá vstup.

const CLUMPS := [
	preload("res://assets/origami/layers/fg_leaves_teal.png"),
	preload("res://assets/origami/layers/fg_leaves_rust.png"),
	preload("res://assets/origami/layers/fg_fern_sage.png"),
]
## [trs, poloha v periodě, měřítko, zrcadlení]
const LAYOUT := [[0, 0.0, 0.52, false], [2, 900.0, 0.42, true], [1, 1900.0, 0.46, false],
	[2, 2700.0, 0.4, false], [0, 3500.0, 0.48, true]]
const PERIOD := 4300.0
const SCROLL_RATIO := 1.22
const ZOOM_EXPONENT := 0.18
const HIDDEN_ALPHA := 0.28

var camera: PaperCamera
var sim: LevelSim
var alpha := 1.0
## Průhlednost trsů podle jejich stálé identity (perioda × 100 + položka).
var _fade := {}


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## Obdélníky trsů na obrazovce: [index rozložení, Rect2, zrcadlit].
func clump_rects() -> Array:
	var out := []
	var vp := camera.viewport_size()
	var base := vp.y / PaperParallax.DESIGN_HEIGHT
	var s := base * pow(camera.zoom_factor, ZOOM_EXPONENT)
	var shift := camera.focus.x * camera.fit_scale() * SCROLL_RATIO
	var bottom := vp.y - camera.bottom_padding * 0.35
	var period := PERIOD * s
	var first := floori((shift - vp.x) / period) - 1
	for k in range(first, first + 4):
		for i in LAYOUT.size():
			var item: Array = LAYOUT[i]
			var tex: Texture2D = CLUMPS[item[0]]
			var size := Vector2(tex.get_width(), tex.get_height()) * s * float(item[2])
			var x := k * period + float(item[1]) * s - shift + vp.x * 0.5 - size.x * 0.5
			if x > vp.x or x + size.x < 0:
				continue
			out.append([k * 100 + i, Rect2(Vector2(x, bottom - size.y), size), item[3], item[0]])
	return out


func update(delta: float) -> void:
	if camera == null:
		return
	var rects := clump_rects()
	for entry in rects:
		var rect: Rect2 = entry[1]
		var busy := false
		if sim != null:
			var inset := rect.size * Vector2(-0.08, -0.1)
			var grown := rect.grow_individual(inset.x, inset.y, inset.x, 0)
			for lem in sim.lemmings:
				if lem.removed:
					continue
				var p := camera.logic_to_screen(Vector2(lem.x + 0.5, lem.y - 5.0))
				if grown.has_point(p):
					busy = true
					break
		var key: int = entry[0]
		_fade[key] = move_toward(float(_fade.get(key, 1.0)), HIDDEN_ALPHA if busy else 1.0, delta * 3.0)
	queue_redraw()


func _draw() -> void:
	if camera == null:
		return
	for entry in clump_rects():
		var rect: Rect2 = entry[1]
		var tex: Texture2D = CLUMPS[entry[3]]
		if entry[2]:
			rect = Rect2(rect.position + Vector2(rect.size.x, 0), Vector2(-rect.size.x, rect.size.y))
		draw_texture_rect(tex, rect, false, Color(1, 1, 1, float(_fade.get(entry[0], 1.0))))
