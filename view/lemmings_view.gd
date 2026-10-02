class_name LemmingsView
extends Node2D
## Kreslí všechny lumíky. Zatím jednoduchými tvary (placeholder) – později
## je nahradí HD animace. Pozice se plynule dopočítávají mezi tiky simulace,
## takže pohyb je hladký i na 144 Hz monitoru, přestože logika běží 17× za sekundu.

const SKIN := Color(1.0, 0.82, 0.68)
const HAIR := Color(0.32, 0.92, 0.38)
const ROBE := Color(0.27, 0.45, 1.0)
const ROBE_DARK := Color(0.15, 0.27, 0.72)
const TOOL := Color(0.72, 0.6, 0.45)
const BRICK := Color(0.9, 0.58, 0.3)
const HIGHLIGHT := Color(1.0, 1.0, 1.0, 0.85)

var sim: LevelSim
## 0..1 – jak daleko jsme mezi minulým a příštím tikem.
var alpha := 1.0
var hovered: Lemming = null


func setup(level_sim: LevelSim) -> void:
	sim = level_sim
	hovered = null


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var t := float(sim.tick_count) + alpha
	for lem in sim.lemmings:
		if lem.removed:
			continue
		_draw_lemming(lem, screen_pos(lem), t)
	if hovered != null and not hovered.removed:
		var hp := screen_pos(hovered)
		draw_rect(Rect2(hp + Vector2(-4.5, -12.5), Vector2(9, 13.5)), HIGHLIGHT, false, 0.4)


## Plynulá pozice lumíka (nohy) mezi minulým a aktuálním tikem.
func screen_pos(lem: Lemming) -> Vector2:
	return Vector2(lerpf(lem.prev_x, lem.x, alpha) + 0.5, lerpf(lem.prev_y, lem.y, alpha))


func _draw_lemming(lem: Lemming, p: Vector2, t: float) -> void:
	var d := float(lem.dir)
	match lem.state:
		Lemming.State.SPLATTING:
			var k := clampf(lem.state_ticks / float(SimConst.SPLAT_TICKS), 0.0, 1.0)
			draw_rect(Rect2(p + Vector2(-3.0 - k, -1.2), Vector2(6.0 + 2.0 * k, 1.2)), ROBE)
			draw_circle(p + Vector2(2.5 * d, -1.4), 1.2, SKIN)
			draw_circle(p + Vector2(3.3 * d, -1.8), 1.0, HAIR)
			return
		Lemming.State.EXITING:
			var s := 1.0 - clampf(lem.state_ticks / float(SimConst.EXIT_TICKS), 0.0, 1.0)
			draw_set_transform(p, 0.0, Vector2(s, s))
			_draw_body(Vector2.ZERO, d, 0.0, t)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return

	var stride := 0.0
	if lem.state in [Lemming.State.WALKER, Lemming.State.CLIMBER]:
		stride = sin(t * TAU / 8.0) * 1.1
	_draw_body(p, d, stride, t)
	if lem.bomb_ticks > 0:
		draw_string(ThemeDB.fallback_font, p + Vector2(-2, -15),
			str(ceili(lem.bomb_ticks / float(SimConst.TICKS_PER_SECOND))),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("ffe297"))

	# Ruce a nářadí podle toho, co lumík dělá.
	var shoulder := p + Vector2(0.0, -6.5)
	match lem.state:
		Lemming.State.FALLER, Lemming.State.CLIMBER, Lemming.State.FLOATER:
			draw_line(shoulder, shoulder + Vector2(-1.8, -3.0), SKIN, 0.8)
			draw_line(shoulder, shoulder + Vector2(1.8, -3.0), SKIN, 0.8)
			if lem.state == Lemming.State.FLOATER:
				draw_arc(p + Vector2(0, -17), 6, PI, TAU, 12, BRICK, 1.4)
				for side in [-1, 1]:
					draw_line(p + Vector2(side * 6, -17), shoulder, TOOL, 0.4)
		Lemming.State.BLOCKER:
			draw_line(shoulder + Vector2(-4.0, 0.0), shoulder + Vector2(4.0, 0.0), SKIN, 0.9)
		Lemming.State.DIGGER:
			var bob := sin(t * TAU / 4.0)
			draw_line(shoulder, p + Vector2(1.5 * d, -1.0 + bob), TOOL, 0.8)
			draw_rect(Rect2(p + Vector2(1.0 * d - 1.0, -0.5 + bob), Vector2(2.0, 1.2)), TOOL)
		Lemming.State.BUILDER:
			draw_line(shoulder, shoulder + Vector2(2.5 * d, 1.5), SKIN, 0.8)
			draw_rect(Rect2(shoulder + Vector2(2.5 * d - 1.5, 1.0), Vector2(3.0, 1.2)), BRICK)
		Lemming.State.BASHER:
			var punch := absf(sin(t * TAU / 4.0)) * 2.5
			draw_line(shoulder, shoulder + Vector2((2.0 + punch) * d, 0.5), SKIN, 0.9)
		Lemming.State.MINER:
			var swing := sin(lem.state_ticks * TAU / SimConst.MINER_TICKS_PER_STEP)
			draw_line(shoulder, p + Vector2(4 * d, -2 + swing * 2), TOOL, 0.8)
		Lemming.State.SHRUGGING:
			draw_line(shoulder, shoulder + Vector2(-2.2, -1.2), SKIN, 0.8)
			draw_line(shoulder, shoulder + Vector2(2.2, -1.2), SKIN, 0.8)
		_:
			var swing := sin(t * TAU / 8.0) * 1.2
			draw_line(shoulder, shoulder + Vector2(swing * d, 3.0), SKIN, 0.8)


func _draw_body(p: Vector2, d: float, stride: float, _t: float) -> void:
	# nohy
	draw_line(p + Vector2(-0.8, -3.2), p + Vector2(-0.8 + stride, 0.0), ROBE_DARK, 1.1)
	draw_line(p + Vector2(0.8, -3.2), p + Vector2(0.8 - stride, 0.0), ROBE_DARK, 1.1)
	# tělo
	draw_rect(Rect2(p + Vector2(-1.7, -7.6), Vector2(3.4, 4.8)), ROBE)
	# hlava, vlasy, oko
	var head := p + Vector2(0.4 * d, -8.9)
	draw_circle(head, 1.6, SKIN)
	draw_circle(head + Vector2(-0.6 * d, -1.0), 1.45, HAIR)
	draw_circle(head + Vector2(0.9 * d, 0.0), 0.3, Color(0.1, 0.1, 0.15))
