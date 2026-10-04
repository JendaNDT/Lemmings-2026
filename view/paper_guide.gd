class_name PaperGuide
extends Node2D
## Ukazatele nad krajinou (pod HUDem) v obrazovkových souřadnicích:
## štítek „Východ“ při přeletu mapy a šipka u okraje herní plochy, když je
## východ mimo záběr. Polohy počítá jen přes PaperCamera; kolize ani výběr
## postav neovlivní (nic nepřijímá vstup).

const EXIT := preload("res://assets/origami/props/exit.png")
## Výška domečku východu nad jeho patou (logické px, viz props.json).
const EXIT_HEIGHT := 42.0
## Kam míří hrot štítku: levá část střechy (vlajka vpravo zůstane volná).
const TAG_POINT := Vector2(-6.0, -22.5)
const TAG_TEXT := "Východ"
const TAG_FONT_SIZE := 32
## Poloměr odznaku šipky a jeho odstup od okraje herní plochy (px při velikosti
## rozhraní 100 %).
const BADGE_RADIUS := 32.0
const EDGE_MARGIN := 52.0
const PAPER := Color("f4e8d2")

var camera: PaperCamera
var exits: Array[Vector2i] = []
## Viditelnost štítku „Východ“ (0–1); řídí ho přelet mapy.
var exit_tag := 0.0
## Šipka k východu mimo záběr (hra ji vypne po konci mise).
var edge_arrow := true
## Velikost rozhraní z nastavení (ukazatele rostou s HUDem).
var ui_scale := 1.0
## Skutečný čas pro pohupování ukazatelů (jen vzhled).
var time := 0.0
var _tag_box: StyleBox
var _font: Font


func _ready() -> void:
	_tag_box = PaperUi.paper("label", 12.0)
	# Stejné (tučné) písmo jako HUD.
	_font = PaperUi.theme().default_font


func setup(level_exits: Array[Vector2i]) -> void:
	exits = level_exits.duplicate()
	exit_tag = 0.0
	edge_arrow = true
	queue_redraw()


func update(delta: float) -> void:
	time += delta
	# Štítek se při přeletu prolíná; šipka je vždy plná.
	modulate = Color(1, 1, 1, exit_tag if exit_tag > 0.0 else 1.0)
	queue_redraw()


## Herní plocha mezi lištami HUDu (obrazovkové px).
func play_rect() -> Rect2:
	var vp := camera.viewport_size()
	return Rect2(0.0, camera.top_padding, vp.x, camera.usable_height())


## Kde má být šipka k nejbližšímu východu; INF, když je některý východ vidět
## nebo se šipka nemá ukazovat.
func arrow_position() -> Vector2:
	if not edge_arrow or exit_tag > 0.0 or exits.is_empty() or camera == null:
		return Vector2.INF
	var rect := play_rect()
	var center := rect.get_center()
	var best := Vector2.INF
	for exit in exits:
		var point := camera.logic_to_screen(Vector2(exit) - Vector2(0.0, EXIT_HEIGHT * 0.5))
		if rect.has_point(point):
			return Vector2.INF
		if best == Vector2.INF or center.distance_squared_to(point) < center.distance_squared_to(best):
			best = point
	# Průsečík paprsku od středu plochy k východu s okrajem (zmenšeným o odstup).
	var inner := rect.grow(-EDGE_MARGIN * ui_scale)
	var dir := best - center
	var t := INF
	if absf(dir.x) > 0.001:
		t = minf(t, (inner.size.x * 0.5) / absf(dir.x))
	if absf(dir.y) > 0.001:
		t = minf(t, (inner.size.y * 0.5) / absf(dir.y))
	return center + dir * minf(t, 1.0)


func _draw() -> void:
	if camera == null:
		return
	if exit_tag > 0.0:
		for exit in exits:
			_draw_tag(Vector2(exit))
	var at := arrow_position()
	if at != Vector2.INF:
		_draw_arrow(at)


## Papírový štítek „Východ“ se šipkou dolů, pohupuje se nad domečkem.
func _draw_tag(exit: Vector2) -> void:
	var k := ui_scale
	var roof := camera.logic_to_screen(exit + TAG_POINT)
	var bob := sin(time * 4.0) * 6.0 * k
	var font_size := roundi(TAG_FONT_SIZE * k)
	var text_size := _font.get_string_size(TAG_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pad := Vector2(22.0, 10.0) * k
	var box_size := text_size + pad * 2.0
	var tip := roof + Vector2(0.0, -4.0 * k + bob)
	var arrow_size := Vector2(20.0, 34.0) * k
	# U východu pod stropem nebo u horní lišty štítek nevyjede z herní plochy.
	var lowest_top := play_rect().position.y + 10.0 * k
	tip.y = maxf(tip.y, lowest_top + box_size.y + arrow_size.y - 4.0 * k)
	var box := Rect2(tip - Vector2(box_size.x * 0.5, box_size.y + arrow_size.y - 4.0 * k), box_size)
	var arrow := PackedVector2Array([tip, tip + Vector2(-arrow_size.x, -arrow_size.y),
		tip + Vector2(arrow_size.x, -arrow_size.y)])
	draw_colored_polygon(arrow, PaperUi.ACCENT)
	draw_polyline(arrow + PackedVector2Array([tip]), PaperUi.INK, 3.0 * k, true)
	_tag_box.draw(get_canvas_item(), box)
	var baseline := box.position + Vector2(pad.x, pad.y + _font.get_ascent(font_size))
	draw_string(_font, baseline, TAG_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		PaperUi.INK)


## Kulatý papírový odznak s domečkem východu a hrotem směrem k němu.
func _draw_arrow(at: Vector2) -> void:
	var center := play_rect().get_center()
	var dir := (at - center).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var radius := BADGE_RADIUS * ui_scale
	at += dir * sin(time * 4.0) * 4.0 * ui_scale
	var side := dir.orthogonal()
	var tip := PackedVector2Array([at + dir * radius * 1.6,
		at + dir * radius * 0.3 + side * radius * 0.62, at + dir * radius * 0.3 - side * radius * 0.62])
	# Měkký stín pod odznakem, ať je vidět i na světlém nebi.
	draw_circle(at + Vector2(0.0, 3.0) * ui_scale, radius + 2.0, Color(0, 0, 0, 0.18))
	draw_colored_polygon(tip, PaperUi.ACCENT)
	draw_polyline(tip + PackedVector2Array([tip[0]]), PaperUi.INK, 3.0 * ui_scale, true)
	draw_circle(at, radius, PAPER)
	draw_arc(at, radius, 0.0, TAU, 48, PaperUi.INK, 3.0 * ui_scale, true)
	var icon_height := radius * 1.35
	var icon_size := Vector2(EXIT.get_width(), EXIT.get_height()) * icon_height / EXIT.get_height()
	draw_texture_rect(EXIT, Rect2(at - icon_size * 0.5 + Vector2(0.0, 1.0), icon_size), false)
