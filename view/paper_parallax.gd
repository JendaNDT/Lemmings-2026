class_name PaperParallax
extends Node2D
## Jedna dekorativní vrstva krajiny s paralaxním posunem i zoomem.
##
## Vrstva je vodorovně navazující dlaždice, takže při žádném poměru stran ani
## posunu nevznikne prázdný okraj vlevo či vpravo. Neprůhledný spodní řádek se
## protáhne až ke spodku obrazovky. Kolize ani výběr postav vrstvy neovlivňují:
## jen čtou stav PaperCamera.

## Výška obrazovky (v pixelech textury), na kterou je vrstva navržená.
const DESIGN_HEIGHT := 1200.0
const LAYER_SHADER := preload("res://view/paper_layer.gdshader")

var texture: Texture2D
## Podíl posunu herní roviny při zoomu 1× (0 = nehybné nebe, 1 = herní rovina).
var scroll_ratio := 0.3
var vertical_ratio := 0.15
## Exponent zoomu: měřítko vrstvy = základ × zoom^exponent (0 = nemění se).
var zoom_exponent := 0.3
## Řádek textury, který při zoomu 1× a středu levelu leží na `anchor_screen` výšky obrazovky.
var anchor_row := 600.0
var anchor_screen := 0.6
var extend_bottom := true
var camera: PaperCamera
## Opar podle vzdálenosti od herní roviny (rozostření je už v podkladech).
var haze := 0.0:
	set(value):
		haze = value
		_material.set_shader_parameter("haze", value)
## Herní čas v ticích (ve stop-motion po krocích) pro pohyblivé výřezy.
var time := 0.0
## Pohyblivé výřezy vrstvy v pixelech textury (mraky, ptáci):
## {frames, pos, anchor, speed (px za tik), scale, flap (tiky na pózu, 0 = bez), bob, phase}.
var drifters: Array[Dictionary] = []
## Nízká kvalita efektů pohyblivé výřezy nekreslí.
var show_drifters := true
var _material := ShaderMaterial.new()
var _origin := Vector2.ZERO
var _scale := 1.0


func setup(cam: PaperCamera, tex: Texture2D, ratio: float, vratio: float, zoom_exp: float,
		row: float, screen_fraction: float, extend := true) -> void:
	camera = cam
	texture = tex
	scroll_ratio = ratio
	vertical_ratio = vratio
	zoom_exponent = zoom_exp
	anchor_row = row
	anchor_screen = screen_fraction
	extend_bottom = extend
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Dlaždice se kreslí ručně; opakování by u horní hrany prosvítalo spodním řádkem.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_material.shader = LAYER_SHADER
	material = _material


## Měřítko vrstvy (obrazovkových px na px textury) pro aktuální kameru.
func layer_scale() -> float:
	var vp := camera.viewport_size()
	return vp.y / DESIGN_HEIGHT * pow(camera.zoom_factor, zoom_exponent)


## Kde na obrazovce leží bod textury (x, y) – sdílené výpočty s testy.
func texture_to_screen(point: Vector2) -> Vector2:
	_update()
	return _origin + point * _scale


func _update() -> void:
	var vp := camera.viewport_size()
	var base := vp.y / DESIGN_HEIGHT
	_scale = layer_scale()
	var center := camera.screen_center()
	var fit := camera.fit_scale()
	# Ohnisko vrstvy v pixelech textury: posun herního ohniska zmenšený poměrem.
	var focus_x := camera.focus.x * fit * scroll_ratio / base
	var level_mid := camera.level_size.y * 0.5
	var focus_y := anchor_row - (anchor_screen * vp.y - center.y) / base \
		+ (camera.focus.y - level_mid) * fit * vertical_ratio / base
	_origin = center - Vector2(focus_x, focus_y) * _scale


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if texture == null or camera == null:
		return
	_update()
	var vp := camera.viewport_size()
	var size := Vector2(texture.get_width(), texture.get_height()) * _scale
	var first := floori(-_origin.x / size.x)
	var x := _origin.x + first * size.x
	var bottom := _origin.y + size.y
	while x < vp.x:
		draw_texture_rect(texture, Rect2(Vector2(x, _origin.y), size), false)
		x += size.x
	if show_drifters:
		_draw_drifters(vp)
	if extend_bottom and bottom < vp.y + 2.0:
		# Poslední řádek textury protažený dolů – žádná prázdná mezera při zoomu.
		var src := Rect2(0, texture.get_height() - 2, texture.get_width(), 1)
		x = _origin.x + first * size.x
		while x < vp.x:
			draw_texture_rect_region(texture, Rect2(Vector2(x, bottom - 1.0),
				Vector2(size.x, vp.y - bottom + 4.0)), src)
			x += size.x


## Nejnižší bod obrazovky, kam vrstva sahá (bez prodloužení); pro testy pokrytí.
func covered_rect() -> Rect2:
	_update()
	var vp := camera.viewport_size()
	var size := Vector2(texture.get_width(), texture.get_height()) * _scale
	var bottom := vp.y + 4.0 if extend_bottom else _origin.y + size.y
	return Rect2(Vector2(-INF, _origin.y), Vector2(INF, bottom - _origin.y))


## Poloha výřezu (pixely textury, x v rámci dlaždice) v aktuálním čase.
func drifter_position(item: Dictionary) -> Vector2:
	var pos: Vector2 = item["pos"]
	var phase := float(item.get("phase", 0.0))
	return Vector2(fposmod(pos.x + float(item["speed"]) * time, float(texture.get_width())),
		pos.y + sin(time * 0.11 + phase * TAU) * float(item.get("bob", 0.0)))


## Póza výřezu: ptáci mávají křídly (nahoře, uprostřed, dole, uprostřed).
func drifter_frame(item: Dictionary) -> int:
	var flap := int(item.get("flap", 0))
	if flap <= 0:
		return 0
	var step := floori(time / flap + float(item.get("phase", 0.0)) * 4.0)
	return [0, 1, 2, 1][posmod(step, 4)]


## Mraky plují a ptáci letí napříč dlaždicí; po jejím konci se objeví znovu.
func _draw_drifters(vp: Vector2) -> void:
	var tile := float(texture.get_width())
	for item in drifters:
		var tex: Texture2D = (item["frames"] as Array)[drifter_frame(item)]
		var k := float(item.get("scale", 1.0))
		var anchor: Vector2 = item["anchor"]
		var at_tile := drifter_position(item)
		var size := Vector2(tex.get_width(), tex.get_height()) * k * _scale
		var first := floori((-_origin.x / _scale - at_tile.x) / tile) - 1
		for rep in range(first, first + int(vp.x / (tile * _scale)) + 3):
			var at := _origin + (at_tile + Vector2(rep * tile, 0.0) - anchor * k) * _scale
			if at.x > vp.x or at.x + size.x < 0.0:
				continue
			draw_texture_rect(tex, Rect2(at, size), false)
