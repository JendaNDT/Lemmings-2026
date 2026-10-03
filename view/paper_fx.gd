class_name PaperFx
extends Node2D
## Papírové ústřižky a drobné efekty podle událostí simulace. Jen vzhled:
## náhoda je místní a výsledek hry neovlivní. Čas efektů běží s herním
## časem (pauza je zastaví, zrychlení urychlí).

const MAX_SCRAPS := 260
const GRAVITY := 120.0
const TERRA := [Color("be5131"), Color("cb7936"), Color("e4903f"), Color("e0aa60"), Color("dcae73")]
const PAPER := [Color("f2e2c8"), Color("e5ccaf")]
const WORKER := [Color("2a7b7c"), Color("f0a640"), Color("f6dcb8")]
const GOLD := [Color("fbe2a0"), Color("f8bf62"), Color("fff4d6")]
const WATER := [Color("cfe5ea"), Color("7fb6c9"), Color("f0f4f0")]
const EMBER := [Color("f8c063"), Color("e4903f"), Color("be5131"), Color("4a3a33")]
const LEAF := [Color("9a9a4e"), Color("b5b45e"), Color("d0614b"), Color("2a7b7c")]


class Scrap:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var angle := 0.0
	var spin := 0.0
	var life := 1.0
	var max_life := 1.0
	var size := 1.0
	var color := Color.WHITE
	var gravity := 1.0
	var shape := 0
	## Ústřižek dopadl na zem a chvíli leží (jen vzhled, maska se nemění).
	var resting := false


## Rozkládání harmonikové cihly: [x, y, dir, tik vzniku].
var unfolding: Array[Array] = []
var sim: LevelSim
var alpha := 1.0
var _scraps: Array[Scrap] = []
var _rng := RandomNumberGenerator.new()


func clear() -> void:
	_scraps.clear()
	unfolding.clear()
	_rng.seed = 2026
	queue_redraw()


func handle_events(events: Array[Dictionary]) -> void:
	for e in events:
		var p := Vector2(float(e["x"]) + 0.5, float(e["y"]))
		var d := float(e["dir"])
		match String(e["type"]):
			"dig":
				_burst(p + Vector2(0, 0.5), 3, TERRA, Vector2(0, -26), 22.0, 0.7, 0.9)
			"bash":
				_burst(p + Vector2(4.0 * d, -5.0), 2, TERRA, Vector2(-18.0 * d, -14.0), 16.0, 0.7, 0.9)
			"mine":
				_burst(p + Vector2(4.0 * d, -2.0), 4, TERRA, Vector2(-14.0 * d, -20.0), 18.0, 0.7, 1.0)
			"explode":
				_burst(p + Vector2(0, -5), 30, TERRA + WORKER, Vector2(0, -34), 60.0, 1.1, 1.5)
			"brick", "brick_warning":
				if sim != null:
					unfolding.append([p.x - 0.5, p.y, d, sim.tick_count])
				_burst(p + Vector2(2.0 * d, -0.5), 2, PAPER, Vector2(0, -8), 8.0, 0.5, 0.6, 0.4)
			"steel":
				_burst(p + Vector2(4.0 * d, -5.0), 5, [Color("c9d6dc"), Color("fff4d6")],
					Vector2(-16.0 * d, -16.0), 22.0, 0.45, 0.6)
			"splat":
				_burst(p + Vector2(0, -1), 10, WORKER, Vector2(0, -22), 26.0, 0.9, 0.9)
			"exit":
				_burst(p + Vector2(0, -6), 10, GOLD, Vector2(0, -14), 14.0, 1.0, 0.8, -0.15)
			"assign":
				_burst(p + Vector2(0, -11), 6, GOLD, Vector2(0, -8), 10.0, 0.5, 0.6, 0.2)
			"drown":
				# Šplouchnutí: kapky z modrého papíru odletí nahoru a spadnou zpět.
				_burst(p + Vector2(0, -0.5), 12, WATER, Vector2(0, -30), 20.0, 0.7, 0.8, 0.8)
			"burn":
				# Jiskry a popel stoupají vzhůru (záporná tíže).
				_burst(p + Vector2(0, -4), 14, EMBER, Vector2(0, -16), 14.0, 1.2, 0.7, -0.25)
			"trap":
				# Past cvakla: lístky a kousky kabátku.
				_burst(p + Vector2(0, -5), 12, LEAF + WORKER, Vector2(0, -20), 22.0, 0.8, 0.8)


func _burst(at: Vector2, count: int, colors: Array, base: Vector2, spread: float,
		life: float, size: float, gravity := 1.0) -> void:
	for _i in count:
		if _scraps.size() >= MAX_SCRAPS:
			_scraps.remove_at(0)
		var s := Scrap.new()
		s.pos = at + Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
		s.vel = base + Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-spread, spread) * 0.6)
		s.angle = _rng.randf() * TAU
		s.spin = _rng.randf_range(-9, 9)
		s.max_life = life * _rng.randf_range(0.7, 1.3)
		s.life = s.max_life
		s.size = size * _rng.randf_range(0.6, 1.3)
		s.color = colors[_rng.randi() % colors.size()]
		s.gravity = gravity
		s.shape = _rng.randi() % 3
		_scraps.append(s)


## delta je herní čas (0 při pauze, ×3 při zrychlení).
func advance(delta: float) -> void:
	for i in range(_scraps.size() - 1, -1, -1):
		var s := _scraps[i]
		s.life -= delta
		if s.life <= 0.0:
			_scraps.remove_at(i)
			continue
		if s.resting:
			continue
		s.vel.y += GRAVITY * s.gravity * delta
		s.vel *= 1.0 - minf(delta * 1.5, 0.5)
		var next := s.pos + s.vel * delta
		# Těžší ústřižky dopadnou na terén a zůstanou ležet jako hromádka.
		if sim != null and s.gravity >= 1.0 and s.vel.y > 0.0 \
				and sim.mask.is_solid(floori(next.x), floori(next.y + s.size * 0.3)):
			s.resting = true
			s.life = maxf(s.life, 3.5)
			s.max_life = maxf(s.max_life, s.life)
			s.angle = snappedf(s.angle, PI / 3.0)
			continue
		s.pos = next
		s.angle += s.spin * delta
	if sim != null:
		var now := sim.tick_count + alpha
		while not unfolding.is_empty() and now - float(unfolding[0][3]) > 5.0:
			unfolding.remove_at(0)
	queue_redraw()


func _draw() -> void:
	if sim != null:
		var now := sim.tick_count + alpha
		for item in unfolding:
			# Cihla se rozloží jako harmonika do skutečné délky z masky.
			var k := clampf((now - float(item[3])) / 4.0, 0.0, 1.0)
			if k >= 1.0:
				continue
			var d := float(item[2])
			var x := float(item[0]) + (0.0 if d > 0.0 else 1.0)
			var y := float(item[1])
			var width := lerpf(1.2, float(SimConst.BRICK_WIDTH), smoothstep(0.0, 1.0, k))
			var lift := (1.0 - k) * 1.6
			var folds := 3
			var step := width / folds
			for f in folds:
				var x0 := x + d * f * step
				var x1 := x0 + d * step
				var mid := (x0 + x1) * 0.5
				var color: Color = PAPER[f % 2]
				draw_colored_polygon(PackedVector2Array([
					Vector2(x0, y + 1.0), Vector2(mid, y - lift), Vector2(x1, y + 1.0)]),
					Color(color, 1.0 - k * 0.6))
	for s in _scraps:
		var fade := clampf(s.life / s.max_life * 1.6, 0.0, 1.0)
		if s.resting:
			fade = clampf(s.life / 1.2, 0.0, 1.0)
			# Ležící ústřižek zmizí, když pod ním zmizí zem.
			if sim != null and not sim.mask.is_solid(floori(s.pos.x), floori(s.pos.y + s.size * 0.3)):
				fade = 0.0
		var c := Color(s.color, fade)
		var r := s.size * 0.5
		var pts := PackedVector2Array()
		var corners := 3 if s.shape < 2 else 4
		for k in corners:
			var a := s.angle + k * TAU / corners + (0.4 if k == 1 and s.shape == 1 else 0.0)
			pts.append(s.pos + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, c)
