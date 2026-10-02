class_name FxView
extends Node2D
## Drobné efekty (hlína, prach, jiskry) jako reakce na události ze simulace.
## Náhoda je tady v pořádku – jde jen o vzhled, logiku hry to neovlivní.

const MAX_PARTICLES := 800
const GRAVITY := 140.0

const DIRT := Color(0.62, 0.42, 0.26)
const DUST := Color(0.95, 0.85, 0.7, 0.8)
const SPARK := Color(1.0, 0.9, 0.55)
const MAGIC := Color(1.0, 0.85, 0.35)
const HAIR := Color(0.32, 0.92, 0.38)
const ROBE := Color(0.27, 0.45, 1.0)


class Particle:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 0.0
	var max_life := 1.0
	var color := Color.WHITE
	var size := 1.0
	var gravity := 1.0


var _particles: Array[Particle] = []


func clear() -> void:
	_particles.clear()
	queue_redraw()


func handle_events(events: Array[Dictionary]) -> void:
	for e in events:
		var p := Vector2(float(e["x"]) + 0.5, float(e["y"]))
		var d := float(e["dir"])
		match String(e["type"]):
			"dig":
				_burst(p, 3, DIRT, Vector2(0, -35), 30.0, 0.5, 0.9)
			"bash", "mine":
				_burst(p + Vector2(4.0 * d, -5.0), 3, DIRT, Vector2(25.0 * d, -15.0), 25.0, 0.5, 0.9)
			"explode":
				_burst(p + Vector2(0, -5), 24, DIRT, Vector2(0, -40), 70.0, 0.65, 1.5)
			"brick":
				_burst(p + Vector2(2.0 * d, -1.0), 2, DUST, Vector2(0, -8), 10.0, 0.4, 0.6, 0.2)
			"brick_warning":
				_burst(p + Vector2(2.0 * d, -1.0), 3, SPARK, Vector2(0, -12), 12.0, 0.4, 0.5, 0.2)
			"steel":
				_burst(p + Vector2(4.0 * d, -5.0), 6, SPARK, Vector2(-20.0 * d, -20.0), 35.0, 0.35, 0.5)
			"splat":
				_burst(p + Vector2(0, -1), 6, HAIR, Vector2(0, -30), 30.0, 0.6, 0.8)
				_burst(p + Vector2(0, -1), 6, ROBE, Vector2(0, -25), 30.0, 0.6, 0.8)
			"exit":
				_burst(p + Vector2(0, -6), 12, MAGIC, Vector2(0, -18), 18.0, 0.9, 0.6, -0.2)
			"assign":
				_burst(p + Vector2(0, -12), 5, DUST, Vector2(0, -10), 12.0, 0.35, 0.5, 0.0)


func _burst(at: Vector2, count: int, color: Color, base_vel: Vector2, spread: float,
		life: float, size: float, gravity := 1.0) -> void:
	for _i in count:
		if _particles.size() >= MAX_PARTICLES:
			return
		var part := Particle.new()
		part.pos = at
		part.vel = base_vel + Vector2(randf_range(-spread, spread), randf_range(-spread, spread) * 0.5)
		part.max_life = life * randf_range(0.7, 1.3)
		part.life = part.max_life
		part.color = color
		part.size = size * randf_range(0.6, 1.2)
		part.gravity = gravity
		_particles.append(part)


func _process(delta: float) -> void:
	if _particles.is_empty():
		return
	for i in range(_particles.size() - 1, -1, -1):
		var part := _particles[i]
		part.life -= delta
		if part.life <= 0.0:
			_particles.remove_at(i)
			continue
		part.vel.y += GRAVITY * part.gravity * delta
		part.pos += part.vel * delta
	queue_redraw()


func _draw() -> void:
	for part in _particles:
		var k := part.life / part.max_life
		var c := part.color
		c.a *= k
		var s := part.size * (0.5 + 0.5 * k)
		draw_rect(Rect2(part.pos - Vector2(s, s) * 0.5, Vector2(s, s)), c)
