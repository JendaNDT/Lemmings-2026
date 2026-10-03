class_name PaperActors
extends Node2D
## Origami postavičky složené z dílů atlasu. Póza se počítá ze simulačního
## času (state_ticks + alpha), takže pauza a zrychlení platí i pro animace.
## Výpočet kloubů odpovídá náhledu v assets/origami/source/build_character.py.
##
## Stop-motion (výchozí): póza se mění jen každé STEP_TICKS tiky, poloha po
## celých ticích a díly se při každém kroku nepatrně „chvějí“ jako ručně
## posouvané papírové loutky. Kontakty nářadí zůstávají na tiku změny masky.

const RIG_PATH := "res://assets/origami/actor/worker_rig.json"
const ATLAS := preload("res://assets/origami/actor/worker_atlas.png")
const FLIP_TICKS := 2.0
const SELECT := Color("ffe39a")
const STEP_TICKS := 2
## Chvění dílů ve stupních (±) a kořene v logických pixelech (±).
const BOIL_DEGREES := 2.5
const BOIL_OFFSET := 0.05

var sim: LevelSim
var alpha := 1.0
var hovered: Lemming
var stop_motion := true
var rig: Dictionary
var _views := {}
var _scale := 32.0
var _font: Font


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


func _init() -> void:
	rig = JSON.parse_string(FileAccess.get_file_as_string(RIG_PATH))
	_scale = float(rig["atlas_scale"])
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_font = preload("res://assets/art_v2/ui/Nunito.ttf")


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
	var step := (sim.tick_count + lem.id) / STEP_TICKS
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


func _draw() -> void:
	if sim == null:
		return
	for lem in sim.lemmings:
		if lem.removed or not _views.has(lem.id):
			continue
		_draw_actor(lem, _views[lem.id])
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if hovered != null and not hovered.removed:
		var p := actor_position(hovered)
		draw_set_transform(p, 0.0, Vector2(1.0, 0.32))
		draw_arc(Vector2.ZERO, 4.2, 0.0, TAU, 32, SELECT, 0.9, true)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var tip := p + Vector2(0, -11.4)
		var marker := PackedVector2Array([tip, tip + Vector2(-1.3, -1.6), tip + Vector2(1.3, -1.6)])
		draw_colored_polygon(marker, SELECT)


func _draw_actor(lem: Lemming, view: ActorView) -> void:
	var p := actor_position(lem)
	var fade := 1.0
	if lem.state == Lemming.State.EXITING:
		fade = 1.0 - clampf((pose_ticks(lem) - 4.0) / float(SimConst.EXIT_TICKS - 4), 0.0, 1.0)
	var grounded := lem.state not in [
		Lemming.State.FALLER, Lemming.State.FLOATER, Lemming.State.CLIMBER]
	if grounded and lem.state != Lemming.State.SPLATTING:
		draw_set_transform(p + Vector2(0, 0.1), 0.0, Vector2(2.5, 0.5))
		draw_circle(Vector2.ZERO, 1.0, Color(0.1, 0.06, 0.03, 0.22 * fade))
	var base := Transform2D(0.0, Vector2(view.facing, 1.0), 0.0, p)
	var xforms := part_transforms(view.pose, view.root)
	var anim: Dictionary = rig["animations"][view.anim]
	var tool: String = view.pose.get("_tool", "")
	var parts: Dictionary = rig["parts"]
	var skeleton: Dictionary = rig["skeleton"]
	for name in rig["draw_order"]:
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
		draw_set_transform_matrix(xf)
		var shade := float(skeleton[name].get("shade", 1.0))
		draw_texture_rect_region(ATLAS, Rect2(-pivot / _scale, region.size / _scale), region,
			Color(shade, shade, shade, fade))
	if lem.bomb_ticks > 0:
		var seconds := ceili(lem.bomb_ticks / float(SimConst.TICKS_PER_SECOND))
		draw_set_transform(p + Vector2(0, -13.2), 0.0, Vector2(0.125, 0.125))
		draw_rect(Rect2(-14, -22, 28, 28), Color("f4e6cc"))
		draw_rect(Rect2(-14, -22, 28, 28), Color("8a4a2c"), false, 2.0)
		draw_string(_font, Vector2(-14, 0), str(seconds), HORIZONTAL_ALIGNMENT_CENTER, 28, 26,
			Color("8a2f1c"))
