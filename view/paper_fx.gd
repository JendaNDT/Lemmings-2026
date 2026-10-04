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
const ASH := [Color("4a3a33"), Color("6b5a50"), Color("2f2622"), Color("8a7a6d")]
const BUBBLE := Color("f0f6f4")
const SMOKE := Color("5d5550")
const RIPPLE := Color("f4f8f4")
const RIG_PATH := "res://assets/origami/actor/worker_rig.json"
const ATLAS := preload("res://assets/origami/actor/worker_atlas.png")


## Bubliny, kouř, kruhy na hladině a plovoucí klobouk (jen vzhled).
class Puff:
	enum Kind { BUBBLE, SMOKE, RIPPLE, HAT, PETAL, SPARK, RAIN }
	var kind := Kind.BUBBLE
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 1.0
	var max_life := 1.0
	var size := 1.0
	var phase := 0.0
	## Hladina, na které bublina praskne (y v logických pixelech).
	var surface := 0.0
	var dir := 1.0
	var color := Color.WHITE
	var angle := 0.0


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
## Viditelná část levelu (logické px): sem občas přiletí lístek nebo okvětní plátek.
var view_rect := Rect2()
## Strop počtu ústřižků a obláčků (nižší kvalita efektů ho snižuje).
var max_scraps := MAX_SCRAPS
## Poletující okvětní lístky v krajině (při nízké kvalitě vypnuté).
var petals := true
## Počasí tématu: "petals" (lístky), "embers" (jiskry), "rain" (déšť), "motes" (prach v podzemí).
var weather := "petals"
var weather_colors: Array = [Color("b5b45e"), Color("e4903f"), Color("f1e9da"), Color("9aa456")]
## Hustota počasí podle kvality efektů: 0 vypnuto, 1 méně, 2 plně.
var weather_level := 2
## Barvy ústřižků hlíny (téma kapitoly; výchozí = louka).
var terra_colors: Array = TERRA
var _scraps: Array[Scrap] = []
var _puffs: Array[Puff] = []
var _rng := RandomNumberGenerator.new()
var _last_tick := -1
var _cap_region := Rect2()
var _cap_pivot := Vector2.ZERO
var _cap_scale := 32.0


func _init() -> void:
	var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RIG_PATH))
	var cap: Dictionary = rig["parts"]["cap"]
	_cap_region = Rect2(cap["region"][0], cap["region"][1], cap["region"][2], cap["region"][3])
	_cap_pivot = Vector2(cap["pivot"][0], cap["pivot"][1])
	_cap_scale = float(rig["atlas_scale"])
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func clear() -> void:
	_scraps.clear()
	_puffs.clear()
	_last_tick = -1
	unfolding.clear()
	_rng.seed = 2026
	queue_redraw()


func handle_events(events: Array[Dictionary]) -> void:
	for e in events:
		var p := Vector2(float(e["x"]) + 0.5, float(e["y"]))
		var d := float(e["dir"])
		match String(e["type"]):
			"dig":
				_burst(p + Vector2(0, 0.5), 3, terra_colors, Vector2(0, -26), 22.0, 0.7, 0.9)
			"bash":
				_burst(p + Vector2(4.0 * d, -5.0), 2, terra_colors, Vector2(-18.0 * d, -14.0), 16.0, 0.7,
					0.9)
			"mine":
				_burst(p + Vector2(4.0 * d, -2.0), 4, terra_colors, Vector2(-14.0 * d, -20.0), 18.0, 0.7,
					1.0)
			"explode":
				_burst(p + Vector2(0, -5), 30, terra_colors + WORKER, Vector2(0, -34), 60.0, 1.1, 1.5)
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
				# Šplouchnutí: kapky z modrého papíru odletí nahoru a spadnou zpět,
				# po hladině se rozběhnou dva kruhy.
				_burst(p + Vector2(0, -0.5), 14, WATER, Vector2(0, -34), 22.0, 0.7, 0.8, 0.8)
				_ripple(p, 0.0)
				_ripple(p, 0.25)
			"drowned":
				# Nad hladinou zbude jen plovoucí klobouk.
				_ripple(p, 0.0)
				var hat := Puff.new()
				hat.kind = Puff.Kind.HAT
				hat.pos = p + Vector2(0, -0.2)
				hat.vel = Vector2(1.2 * d, 0.0)
				hat.dir = d
				hat.max_life = 3.0
				hat.life = hat.max_life
				hat.surface = p.y
				_add_puff(hat)
			"burn":
				# Jiskry a popel stoupají vzhůru (záporná tíže).
				_burst(p + Vector2(0, -4), 14, EMBER, Vector2(0, -16), 14.0, 1.2, 0.7, -0.25)
			"burned":
				# Z papírku zbude hromádka popela a obláček kouře.
				_burst(p + Vector2(0, -2), 14, ASH, Vector2(0, -10), 10.0, 1.6, 0.8, 0.35)
				for k in 3:
					_smoke(p + Vector2(_rng.randf_range(-1.5, 1.5), -2.0 - k), 1.4)
			"trap":
				# Past cvakla: lístky a kousky kabátku.
				_burst(p + Vector2(0, -5), 12, LEAF + WORKER, Vector2(0, -20), 22.0, 0.8, 0.8)


func _burst(at: Vector2, count: int, colors: Array, base: Vector2, spread: float,
		life: float, size: float, gravity := 1.0) -> void:
	for _i in count:
		while _scraps.size() >= max_scraps:
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


func _add_puff(puff: Puff) -> void:
	while _puffs.size() >= max_scraps:
		_puffs.remove_at(0)
	_puffs.append(puff)


func _ripple(at: Vector2, delay: float) -> void:
	var ring := Puff.new()
	ring.kind = Puff.Kind.RIPPLE
	ring.pos = at
	ring.max_life = 0.9 + delay
	ring.life = ring.max_life
	ring.phase = delay
	_add_puff(ring)


func _smoke(at: Vector2, life: float) -> void:
	var puff := Puff.new()
	puff.kind = Puff.Kind.SMOKE
	puff.pos = at
	puff.vel = Vector2(_rng.randf_range(-2.0, 2.0), _rng.randf_range(-11.0, -7.0))
	puff.max_life = life * _rng.randf_range(0.8, 1.2)
	puff.life = puff.max_life
	puff.size = _rng.randf_range(0.8, 1.3)
	puff.phase = _rng.randf() * TAU
	_add_puff(puff)


## Průběžné efekty podle stavu postav: bubliny topících se, kouř a jiskry
## hořících. Spouští se jednou za simulační tik, takže je zastaví pauza.
func _hazard_tick() -> void:
	if sim == null or sim.tick_count == _last_tick:
		return
	_last_tick = sim.tick_count
	_spawn_weather()
	for lem in sim.lemmings:
		if lem.removed:
			continue
		var p := Vector2(lem.x + 0.5, lem.y)
		var k := float(lem.state_ticks)
		if lem.state == Lemming.State.DROWNING:
			# Bubliny vycházejí z ponořené části postavy (ta klesá až ~9 px).
			var depth := maxf(k / float(SimConst.DROWN_TICKS) * 9.5 - 6.0, 0.6)
			if (sim.tick_count + lem.id) % 2 == 0:
				var bubble := Puff.new()
				bubble.kind = Puff.Kind.BUBBLE
				bubble.pos = p + Vector2(_rng.randf_range(-2.0, 2.0), depth + _rng.randf_range(0.0, 2.5))
				bubble.vel = Vector2(0.0, _rng.randf_range(-9.0, -6.0))
				bubble.size = _rng.randf_range(0.35, 0.8)
				bubble.max_life = 1.5
				bubble.life = bubble.max_life
				bubble.surface = p.y - 0.2
				bubble.phase = _rng.randf() * TAU
				_add_puff(bubble)
			if lem.state_ticks % 6 == 3:
				_ripple(p, 0.0)
		elif lem.state == Lemming.State.BURNING:
			if (sim.tick_count + lem.id) % 2 == 0:
				_smoke(p + Vector2(_rng.randf_range(-1.5, 1.5), -7.0 + k * 0.2), 1.3)
			_burst(p + Vector2(_rng.randf_range(-2.0, 2.0), -4.0), 1, EMBER, Vector2(0, -14), 8.0,
				0.9, 0.5, -0.3)


## delta je herní čas (0 při pauze, ×3 při zrychlení).
func advance(delta: float) -> void:
	_hazard_tick()
	for i in range(_puffs.size() - 1, -1, -1):
		var puff := _puffs[i]
		puff.life -= delta
		if puff.life <= 0.0:
			_puffs.remove_at(i)
			continue
		puff.phase += delta * 6.0
		match puff.kind:
			Puff.Kind.BUBBLE:
				puff.pos += Vector2(sin(puff.phase) * 1.2, puff.vel.y) * delta
				if puff.pos.y <= puff.surface:
					# Bublina na hladině praskne malým kroužkem.
					_puffs.remove_at(i)
					var pop := Puff.new()
					pop.kind = Puff.Kind.RIPPLE
					pop.pos = Vector2(puff.pos.x, puff.surface + 0.2)
					pop.size = 0.35
					pop.max_life = 0.35
					pop.life = pop.max_life
					_add_puff(pop)
			Puff.Kind.SMOKE:
				puff.pos += puff.vel * delta
				puff.vel *= 1.0 - minf(delta * 0.8, 0.5)
				puff.size += delta * 2.2
			Puff.Kind.HAT:
				puff.pos.x += puff.vel.x * delta
				puff.vel.x *= 1.0 - minf(delta * 0.7, 0.5)
			Puff.Kind.SPARK:
				puff.pos += Vector2(puff.vel.x + sin(puff.phase * 0.4) * 2.0, puff.vel.y) * delta
			Puff.Kind.RAIN:
				puff.pos += puff.vel * delta
				if sim != null and sim.mask.is_solid(floori(puff.pos.x), floori(puff.pos.y)):
					_puffs.remove_at(i)
			Puff.Kind.PETAL:
				if puff.surface > 0.0:
					continue
				# Lístek se snáší, houpe se do stran a přetáčí; na zemi chvíli zůstane.
				puff.pos += Vector2(puff.vel.x + sin(puff.phase * 0.35) * 3.5, puff.vel.y) * delta
				puff.angle += delta * 1.6 * puff.dir
				if sim != null and sim.mask.is_solid(floori(puff.pos.x), floori(puff.pos.y + 0.4)):
					puff.surface = 1.0
					puff.life = minf(puff.life, 2.5)
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
	_draw_puffs()
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


## Počasí tématu: lístky shora, jiskry zdola, nebo déšť (jen vzhled, místní náhoda).
func _spawn_weather() -> void:
	if view_rect.size.x <= 0.0 or weather_level <= 0:
		return
	match weather:
		"petals":
			if petals:
				_spawn_petal()
		"embers":
			if posmod(sim.tick_count, 3 - weather_level) == 0:
				_spawn_spark()
		"motes":
			# Podzemí: řídký svítící prach se pomalu vznáší (méně než jiskry).
			if posmod(sim.tick_count, 6 - weather_level * 2) == 0:
				var mote := _spawn_spark()
				mote.vel = Vector2(_rng.randf_range(-2.5, 2.5), _rng.randf_range(-3.0, 1.5))
				mote.max_life = _rng.randf_range(4.0, 6.5)
				mote.life = mote.max_life
				mote.size *= 0.8
		"rain":
			for _i in weather_level * 3:
				_spawn_drop()


## Jiskra se rozžhne kdekoli v pohledu, pomalu stoupá, mihotá se a zhasne.
func _spawn_spark() -> Puff:
	var spark := Puff.new()
	spark.kind = Puff.Kind.SPARK
	spark.pos = view_rect.position + Vector2(_rng.randf(), _rng.randf()) * view_rect.size
	spark.vel = Vector2(_rng.randf_range(-3.0, 4.0), _rng.randf_range(-12.0, -6.0))
	spark.max_life = _rng.randf_range(3.0, 5.0)
	spark.life = spark.max_life
	spark.size = _rng.randf_range(0.55, 0.95)
	spark.phase = _rng.randf() * TAU
	spark.color = weather_colors[_rng.randi() % weather_colors.size()]
	_add_puff(spark)
	return spark


## Kapka deště padá šikmo shora; na terénu zmizí.
func _spawn_drop() -> void:
	var drop := Puff.new()
	drop.kind = Puff.Kind.RAIN
	# Kapky vznikají i kousek za okraji pohledu, ať při posunu kamery nejsou suché pruhy.
	drop.pos = Vector2(view_rect.position.x + _rng.randf_range(-0.2, 1.3) * view_rect.size.x,
		view_rect.position.y - _rng.randf() * 6.0)
	drop.vel = Vector2(-9.0, _rng.randf_range(58.0, 72.0))
	drop.max_life = 3.0
	drop.life = drop.max_life
	drop.size = _rng.randf_range(3.5, 5.5)
	drop.color = weather_colors[_rng.randi() % weather_colors.size()]
	_add_puff(drop)


## Občasný lístek nebo okvětní plátek v horní části pohledu (jen vzhled).
func _spawn_petal() -> void:
	if posmod(sim.tick_count, 19) != 0 or _rng.randf() > 0.7:
		return
	var petal := Puff.new()
	petal.kind = Puff.Kind.PETAL
	petal.pos = Vector2(view_rect.position.x + _rng.randf() * view_rect.size.x * 0.9,
		view_rect.position.y - 4.0)
	petal.vel = Vector2(_rng.randf_range(1.5, 4.5), _rng.randf_range(3.5, 6.0))
	petal.max_life = 14.0
	petal.life = petal.max_life
	petal.size = _rng.randf_range(0.9, 1.4)
	petal.phase = _rng.randf() * TAU
	petal.angle = _rng.randf() * TAU
	petal.dir = 1.0 if _rng.randf() < 0.5 else -1.0
	petal.color = weather_colors[_rng.randi() % weather_colors.size()]
	_add_puff(petal)


func _draw_puffs() -> void:
	for puff in _puffs:
		var t := 1.0 - puff.life / puff.max_life
		match puff.kind:
			Puff.Kind.BUBBLE:
				var a := clampf(puff.life / 0.3, 0.0, 1.0) * 0.85
				draw_arc(puff.pos, puff.size, 0.0, TAU, 12, Color(BUBBLE, a), 0.22, true)
				draw_circle(puff.pos + Vector2(-0.3, -0.3) * puff.size, puff.size * 0.25, Color(BUBBLE, a))
			Puff.Kind.SMOKE:
				# Obláček z šedého papíru: nepravidelný mnohoúhelník, roste a bledne.
				var pts := PackedVector2Array()
				for k in 7:
					var ang := k * TAU / 7.0
					var r := puff.size * (0.85 + 0.25 * sin(ang * 3.0 + puff.phase * 0.2))
					pts.append(puff.pos + Vector2(cos(ang), sin(ang)) * r)
				draw_colored_polygon(pts, Color(SMOKE, 0.42 * (1.0 - t)))
			Puff.Kind.RIPPLE:
				var age := puff.max_life - puff.life - puff.phase
				if age < 0.0:
					continue
				var local := clampf(age / (puff.max_life - puff.phase), 0.0, 1.0)
				var radius := lerpf(0.6, 6.0 if puff.size >= 1.0 else 1.6, sqrt(local))
				draw_set_transform(puff.pos, 0.0, Vector2(1.0, 0.24))
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(RIPPLE, 0.75 * (1.0 - local)), 0.9, true)
				draw_set_transform_matrix(Transform2D.IDENTITY)
			Puff.Kind.SPARK:
				var glow := clampf(puff.life / 1.2, 0.0, 1.0) * clampf((puff.max_life - puff.life) / 0.6,
					0.0, 1.0) * (0.65 + 0.35 * sin(puff.phase * 1.7))
				draw_circle(puff.pos, puff.size * 2.4, Color(puff.color, glow * 0.22))
				draw_circle(puff.pos, puff.size, Color(puff.color, glow))
			Puff.Kind.RAIN:
				var tail := puff.vel.normalized() * puff.size
				draw_line(puff.pos - tail, puff.pos, Color(puff.color, 0.7), 0.3, true)
			Puff.Kind.PETAL:
				var fade := clampf(puff.life / 1.5, 0.0, 1.0)
				# Přetáčení: lístek se zužuje, jak se otáčí kolem své osy.
				var flip := 0.35 + 0.65 * absf(cos(puff.phase * 0.5))
				draw_set_transform(puff.pos, puff.angle, Vector2(flip, 1.0) * puff.size)
				var leaf := PackedVector2Array([Vector2(0, -1.1), Vector2(0.55, -0.2), Vector2(0.3, 0.7),
					Vector2(0, 1.0), Vector2(-0.3, 0.7), Vector2(-0.55, -0.2)])
				draw_colored_polygon(leaf, Color(puff.color, fade))
				draw_line(Vector2(0, -0.9), Vector2(0, 0.85), Color(puff.color.darkened(0.25), fade), 0.12)
				draw_set_transform_matrix(Transform2D.IDENTITY)
			Puff.Kind.HAT:
				# Klobouk se houpe na vlnách a nakonec se rozmočí.
				var bob := sin(puff.phase * 0.5) * 0.35
				var tilt := sin(puff.phase * 0.35) * 0.18
				var fade := clampf(puff.life / 0.8, 0.0, 1.0)
				draw_set_transform(puff.pos + Vector2(0.0, -1.4 + bob), tilt, Vector2(puff.dir, 1.0))
				draw_texture_rect_region(ATLAS, Rect2(-_cap_pivot / _cap_scale - Vector2(0.0, -1.0),
					_cap_region.size / _cap_scale), _cap_region, Color(1, 1, 1, fade))
				draw_set_transform_matrix(Transform2D.IDENTITY)
