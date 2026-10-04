class_name PaperActors
extends Node2D
## Origami postavičky složené z dílů atlasu. Póza se počítá ze simulačního
## času (state_ticks + alpha), takže pauza a zrychlení platí i pro animace.
## Výpočet kloubů odpovídá náhledu v assets/origami/source/build_character.py.
##
## Stop-motion (výchozí): póza se mění po celých ticích (STEP_TICKS), poloha
## také a díly se každé BOIL_TICKS tiky nepatrně „chvějí“ jako ručně
## posouvané papírové loutky. Kontakty nářadí zůstávají na tiku změny masky.

const RIG_PATH := "res://assets/origami/actor/worker_rig.json"
const ATLAS := preload("res://assets/origami/actor/worker_atlas.png")
const FLIP_TICKS := 2.0
const SELECT := Color("ffe39a")
const STEP_TICKS := 1
## Po kolika ticích se mění ruční chvění dílů (a vlny či plameny ve scéně).
const BOIL_TICKS := 2
## Dopad z pádu: krátké zplácnutí postavy (tiky).
const LAND_TICKS := 3.0
const FALLING_ANIMS := ["fall", "fall_umbrella", "float"]
## Postavička je „nálepka“: světlý papírový okraj kolem siluety a vržený
## stín na pozadí (zvednutý list jako terén). Tloušťka okraje v logických px.
const OUTLINE_WIDTH := 0.2
const OUTLINE_COLOR := Color("fbf3e2")
const SHADOW_OFFSET := Vector2(0.55, 0.7)
const SHADOW_COLOR := Color(0.12, 0.07, 0.04, 0.26)
const SILHOUETTE_SHADER := preload("res://view/paper_silhouette.gdshader")
const FLAME_OUTER := Color("f3923a")
const FLAME_MID := Color("fab84a")
const FLAME_CORE := Color("fff0b0")
## Chvění dílů ve stupních (±) a kořene v logických pixelech (±).
const BOIL_DEGREES := 2.5
const BOIL_OFFSET := 0.05
## Ohořelý papír: postavička v lávě postupně ztmavne.
const CHAR := Color(0.3, 0.2, 0.16)

var sim: LevelSim
var alpha := 1.0
var hovered: Lemming
var stop_motion := true
var rig: Dictionary
var _views := {}
var _scale := 32.0
var _font: Font
## Pod postavami: vržený stín a světlý okraj (stejné díly, jednobarevně).
var _silhouette: Node2D


class ActorView:
	var anim := ""
	var pose := {}
	var root := [0.0, 0.0, 0.0, 1.0, 1.0]
	var from_pose := {}
	var from_root := [0.0, 0.0, 0.0, 1.0, 1.0]
	var blending := false
	var facing := 1.0
	var dir := 1
	var flip_from := 1.0
	var flip_start := -100.0
	var landed := -100.0


func _init() -> void:
	rig = JSON.parse_string(FileAccess.get_file_as_string(RIG_PATH))
	_scale = float(rig["atlas_scale"])
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_font = preload("res://assets/fonts/Nunito.ttf")
	_silhouette = Node2D.new()
	_silhouette.name = "Silhouette"
	_silhouette.show_behind_parent = true
	_silhouette.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var material := ShaderMaterial.new()
	material.shader = SILHOUETTE_SHADER
	_silhouette.material = material
	_silhouette.draw.connect(_draw_silhouettes)
	add_child(_silhouette)


func setup(level_sim: LevelSim) -> void:
	sim = level_sim
	hovered = null
	_views.clear()
	queue_redraw()


## Název animace pro aktuální stav postavy.
func anim_for(lem: Lemming) -> String:
	var name: String = rig["state_animations"][lem.state]
	if name == "fall" and lem.has_floater:
		return "fall_umbrella"
	return name


## Čas ve stavu pro pózu: plynule (tiky + alpha), nebo po krocích stop-motion.
func pose_ticks(lem: Lemming) -> float:
	if stop_motion:
		return float(lem.state_ticks - posmod(lem.state_ticks, STEP_TICKS))
	return maxf(lem.state_ticks + alpha, 0.0)


## Fáze animace 0..1 ze simulačního času; kontakty nářadí odpovídají tikům masky.
func phase_for(lem: Lemming, anim: Dictionary) -> float:
	return pose_ticks(lem) / float(anim["cycle"])


func update_views() -> void:
	if sim == null:
		return
	var now := float(sim.tick_count) if stop_motion else sim.tick_count + alpha
	var alive := {}
	for lem in sim.lemmings:
		if lem.removed:
			continue
		alive[lem.id] = true
		var view: ActorView = _views.get(lem.id)
		if view == null:
			view = ActorView.new()
			view.facing = lem.dir
			view.dir = lem.dir
			_views[lem.id] = view
		if view.dir != lem.dir:
			view.flip_from = view.facing
			view.flip_start = now
			view.dir = lem.dir
		var flip := clampf((now - view.flip_start) / FLIP_TICKS, 0.0, 1.0)
		if flip >= 1.0:
			view.facing = float(lem.dir)
		elif stop_motion:
			# Papírek se otočí ve dvou krocích, nikdy není vidět úplně z hrany.
			view.facing = (signf(view.flip_from) if flip < 0.5 else float(lem.dir)) * 0.45
		else:
			view.facing = lerpf(view.flip_from, lem.dir, smoothstep(0.0, 1.0, flip))
		var name := anim_for(lem)
		if name != view.anim:
			if view.anim in FALLING_ANIMS and name not in FALLING_ANIMS and name != "splat":
				view.landed = now
			if view.anim != "":
				view.from_pose = view.pose.duplicate()
				view.from_root = view.root.duplicate()
				view.blending = true
			view.anim = name
		var anim: Dictionary = rig["animations"][name]
		var sampled := sample(anim, phase_for(lem, anim))
		var pose: Dictionary = sampled[0]
		var root: Array = sampled[1]
		var blend_ticks := float(rig["blend_ticks"])
		var b := clampf(pose_ticks(lem) / blend_ticks, 0.0, 1.0)
		if view.blending and b < 1.0:
			var k := smoothstep(0.0, 1.0, b)
			for key in pose:
				pose[key] = lerpf(float(view.from_pose.get(key, pose[key])), float(pose[key]), k)
			for i in root.size():
				root[i] = lerpf(float(view.from_root[i]), float(root[i]), k)
		else:
			view.blending = false
		# Dopad: postavička se na okamžik zplácne a zase narovná.
		var land := 1.0 - clampf((now - view.landed) / LAND_TICKS, 0.0, 1.0)
		if land > 0.0:
			root[3] = float(root[3]) * (1.0 + 0.14 * land)
			root[4] = float(root[4]) * (1.0 - 0.22 * land)
		if stop_motion:
			_boil(lem, pose, root)
		view.pose = pose
		view.root = root
		view.pose["_tool"] = sampled[2]
	for id in _views.keys():
		if not alive.has(id):
			_views.erase(id)


## Ruční chvění: v každém kroku jiné, ale deterministické (stejný krok = stejná póza).
func _boil(lem: Lemming, pose: Dictionary, root: Array) -> void:
	var step := (sim.tick_count + lem.id) / BOIL_TICKS
	var index := 0
	for key in pose:
		pose[key] = float(pose[key]) + (_noise(lem.id, step, index) - 0.5) * 2.0 * BOIL_DEGREES
		index += 1
	root[0] = float(root[0]) + (_noise(lem.id, step, 90) - 0.5) * 2.0 * BOIL_OFFSET
	root[1] = float(root[1]) + (_noise(lem.id, step, 91) - 0.5) * 2.0 * BOIL_OFFSET


static func _noise(id: int, step: int, index: int) -> float:
	return float(posmod(hash([id, step, index]), 1000)) / 999.0


## Interpolace klíčů (kosinová), stejná jako sample() v generátoru.
static func sample(anim: Dictionary, t: float) -> Array:
	var keys: Array = anim["keys"]
	var loop: bool = anim["loop"]
	t = fposmod(t, 1.0) if loop else clampf(t, 0.0, 1.0)
	var tool: String = anim["tool"]
	for i in keys.size():
		var key: Dictionary = keys[i]
		var next: Dictionary
		var next_t: float
		if i + 1 < keys.size():
			next = keys[i + 1]
			next_t = next["t"]
		elif loop:
			next = keys[0]
			next_t = 1.0 + float(next["t"])
		else:
			return [(key["pose"] as Dictionary).duplicate(), (key["root"] as Array).duplicate(),
				key.get("tool", tool)]
		if t >= float(key["t"]) and t < next_t:
			var f := (t - float(key["t"])) / (next_t - float(key["t"]))
			f = 0.5 - 0.5 * cos(PI * f)
			var pose := {}
			var a: Dictionary = key["pose"]
			var bpose: Dictionary = next["pose"]
			for name in a:
				pose[name] = lerpf(float(a[name]), float(bpose.get(name, a[name])), f)
			var root := []
			for j in (key["root"] as Array).size():
				root.append(lerpf(float(key["root"][j]), float(next["root"][j]), f))
			return [pose, root, key.get("tool", tool)]
	var first: Dictionary = keys[0]
	return [(first["pose"] as Dictionary).duplicate(), (first["root"] as Array).duplicate(),
		first.get("tool", tool)]


## Transformace dílů v souřadnicích postavy (počátek mezi chodidly).
func part_transforms(pose: Dictionary, root: Array) -> Dictionary:
	var scale := Vector2(float(root[3]), float(root[4]))
	var out := {"root": Transform2D(deg_to_rad(float(root[2])), scale, 0.0,
		Vector2(float(root[0]), float(root[1])))}
	var skeleton: Dictionary = rig["skeleton"]
	for name in rig["draw_order"]:
		_resolve(name, pose, skeleton, out)
	return out


func _resolve(name: String, pose: Dictionary, skeleton: Dictionary, out: Dictionary) -> Transform2D:
	if out.has(name):
		return out[name]
	var node: Dictionary = skeleton[name]
	var parent := _resolve(node["parent"], pose, skeleton, out)
	var joint := Vector2(float(node["joint"][0]), float(node["joint"][1]))
	var xf := parent * Transform2D(deg_to_rad(float(pose.get(name, 0.0))), joint)
	out[name] = xf
	return xf


func actor_position(lem: Lemming) -> Vector2:
	if stop_motion:
		return Vector2(lem.x + 0.5, lem.y)
	return Vector2(lerpf(lem.prev_x, lem.x, alpha) + 0.5, lerpf(lem.prev_y, lem.y, alpha))


func _process(_delta: float) -> void:
	queue_redraw()
	_silhouette.queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	for lem in sim.lemmings:
		if lem.removed or not _views.has(lem.id):
			continue
		_draw_actor(lem, _views[lem.id])
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# Umírající nebo odcházející postavě nejde nic přidělit: bez zvýraznění.
	if hovered != null and not hovered.removed and hovered.state not in LevelSim.DYING_STATES:
		var p := actor_position(hovered)
		draw_set_transform(p, 0.0, Vector2(1.0, 0.32))
		draw_arc(Vector2.ZERO, 4.2, 0.0, TAU, 32, SELECT, 0.9, true)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var tip := p + Vector2(0, -11.4)
		var marker := PackedVector2Array([tip, tip + Vector2(-1.3, -1.6), tip + Vector2(1.3, -1.6)])
		draw_colored_polygon(marker, SELECT)


func _draw_actor(lem: Lemming, view: ActorView) -> void:
	var p := actor_position(lem)
	var fade := actor_fade(lem)
	var tint := Color.WHITE
	if lem.state == Lemming.State.BURNING:
		var k := pose_ticks(lem) / float(SimConst.BURN_TICKS)
		tint = Color.WHITE.lerp(CHAR, clampf(k / 0.55, 0.0, 1.0))
	var grounded := lem.state not in [
		Lemming.State.FALLER, Lemming.State.FLOATER, Lemming.State.CLIMBER,
		Lemming.State.DROWNING, Lemming.State.BURNING]
	if grounded and lem.state != Lemming.State.SPLATTING:
		draw_set_transform(p + Vector2(0, 0.1), 0.0, Vector2(2.5, 0.5))
		draw_circle(Vector2.ZERO, 1.0, Color(0.1, 0.06, 0.03, 0.22 * fade))
	var skeleton: Dictionary = rig["skeleton"]
	for item: Array in _part_draws(lem, view, p):
		draw_set_transform_matrix(item[0])
		var shade := float(skeleton[item[3]].get("shade", 1.0))
		draw_texture_rect_region(ATLAS, item[1], item[2],
			Color(shade * tint.r, shade * tint.g, shade * tint.b, fade))
	if lem.state == Lemming.State.BURNING:
		_draw_flames(lem, p)
	if lem.bomb_ticks > 0:
		var seconds := ceili(lem.bomb_ticks / float(SimConst.TICKS_PER_SECOND))
		draw_set_transform(p + Vector2(0, -13.2), 0.0, Vector2(0.125, 0.125))
		draw_rect(Rect2(-14, -22, 28, 28), Color("f4e6cc"))
		draw_rect(Rect2(-14, -22, 28, 28), Color("8a4a2c"), false, 2.0)
		draw_string(_font, Vector2(-14, 0), str(seconds), HORIZONTAL_ALIGNMENT_CENTER, 28, 26,
			Color("8a2f1c"))


## Průhlednost postavy při odchodu, topení a hoření.
func actor_fade(lem: Lemming) -> float:
	var fade := 1.0
	match lem.state:
		Lemming.State.EXITING:
			fade = 1.0 - clampf((pose_ticks(lem) - 4.0) / float(SimConst.EXIT_TICKS - 4), 0.0, 1.0)
		Lemming.State.DROWNING:
			# Potopí se za průsvitné přední pruhy vody a na konci zmizí.
			fade = 1.0 - clampf((pose_ticks(lem) / float(SimConst.DROWN_TICKS) - 0.75) * 4.0, 0.0, 1.0)
		Lemming.State.BURNING:
			var k := pose_ticks(lem) / float(SimConst.BURN_TICKS)
			fade = 1.0 - clampf((k - 0.8) / 0.2, 0.0, 1.0)
	return fade


## Papírové plameny kolem hořící postavy: jazyky mění tvar po celých ticích,
## nejdřív rostou, s mačkajícím se papírem slábnou.
func _draw_flames(lem: Lemming, p: Vector2) -> void:
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var k := clampf(pose_ticks(lem) / float(SimConst.BURN_TICKS), 0.0, 1.0)
	var strength := smoothstep(0.0, 0.15, k) * (1.0 - smoothstep(0.75, 1.0, k))
	if strength <= 0.0:
		return
	var step := sim.tick_count
	var tongues := [[-2.4, 0.8], [-0.8, 1.2], [0.9, 1.1], [2.5, 0.75], [0.0, 0.9]]
	for i in tongues.size():
		var spec: Array = tongues[i]
		var jitter := _noise(lem.id, step, 200 + i)
		var height := (4.0 + 5.5 * jitter) * float(spec[1]) * strength * (1.0 - 0.45 * k)
		var lean := (_noise(lem.id, step, 300 + i) - 0.5) * 2.2
		var base := p + Vector2(float(spec[0]), 0.4 - k * 1.5 * float(i % 2))
		for layer in 3:
			var scale := [1.0, 0.68, 0.36][layer] as float
			var color: Color = [FLAME_OUTER, FLAME_MID, FLAME_CORE][layer]
			var w := 1.5 * scale * float(spec[1])
			var h := height * scale
			var tongue := PackedVector2Array([
				base + Vector2(-w, 0.0),
				base + Vector2(-w * 0.8 + lean * 0.3, -h * 0.45),
				base + Vector2(lean, -h),
				base + Vector2(w * 0.7 + lean * 0.4, -h * 0.5),
				base + Vector2(w, 0.0),
			])
			draw_colored_polygon(tongue, Color(color, 0.92))


## Díly k vykreslení: [transformace, cílový obdélník, oblast atlasu, jméno kloubu].
func _part_draws(lem: Lemming, view: ActorView, p: Vector2) -> Array:
	var out := []
	var base := Transform2D(0.0, Vector2(view.facing, 1.0), 0.0, p)
	var xforms := part_transforms(view.pose, view.root)
	var anim: Dictionary = rig["animations"][view.anim]
	var tool: String = view.pose.get("_tool", "")
	var parts: Dictionary = rig["parts"]
	var skeleton: Dictionary = rig["skeleton"]
	for name: String in rig["draw_order"]:
		var part: String = skeleton[name].get("part", "")
		if name == "tool":
			part = tool
		if part == "":
			continue
		var info: Dictionary = parts[part]
		var region := Rect2(info["region"][0], info["region"][1], info["region"][2], info["region"][3])
		var pivot := Vector2(info["pivot"][0], info["pivot"][1])
		var xf := base * (xforms[name] as Transform2D)
		if name == "tool" and int(anim.get("unfold_ticks", 0)) > 0:
			var open := clampf(pose_ticks(lem) / float(anim["unfold_ticks"]), 0.15, 1.0)
			xf = xf * Transform2D(0.0, Vector2(open, 0.6 + 0.4 * open), 0.0, Vector2.ZERO)
		out.append([xf, Rect2(-pivot / _scale, region.size / _scale), region, name])
	return out


## Stín a světlý okraj všech postav jednou vrstvou pod nimi (okraje sousedních
## postav splývají jako nálepky). Okraj = silueta posunutá do 8 směrů.
func _draw_silhouettes() -> void:
	if sim == null:
		return
	var offsets: Array[Vector2] = []
	for k in 8:
		offsets.append(Vector2.from_angle(k * TAU / 8.0) * OUTLINE_WIDTH)
	for pass_index in 2:
		for lem in sim.lemmings:
			if lem.removed or not _views.has(lem.id):
				continue
			var fade := actor_fade(lem)
			if lem.state == Lemming.State.DROWNING:
				fade *= 0.6
			var p := actor_position(lem)
			var items := _part_draws(lem, _views[lem.id], p)
			var shifts: Array[Vector2] = offsets
			if pass_index == 0:
				shifts = [SHADOW_OFFSET]
			var color := Color(SHADOW_COLOR, SHADOW_COLOR.a * fade) if pass_index == 0 \
				else Color(OUTLINE_COLOR, fade)
			for shift in shifts:
				for item: Array in items:
					var xf: Transform2D = item[0]
					_silhouette.draw_set_transform_matrix(Transform2D(xf.x, xf.y, xf.origin + shift))
					_silhouette.draw_texture_rect_region(ATLAS, item[1], item[2], color)
	_silhouette.draw_set_transform_matrix(Transform2D.IDENTITY)
