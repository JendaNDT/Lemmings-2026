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
