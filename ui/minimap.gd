class_name Minimap
extends Control
## Minimapa: zmenšený přehled celé mise v rohu herní plochy – terén, ocel,
## voda, láva, líheň, východ, pasti, lumíci a rámeček záběru kamery.
## Klepnutí nebo tažení pošle signál focus_requested (hra přesune kameru).
## Simulaci jen čte; obraz terénu obnovuje po změně masky nejvýš 4× za sekundu.

## Kam se má kamera podívat (logické souřadnice levelu).
signal focus_requested(point: Vector2)

## Největší rozměr mapy uvnitř rámečku (px při rozhraní 100 %) a okraj rámečku.
## Se zvětšeným rozhraním mapa na obrazovce neroste, ať nebere hrací plochu.
const MAX_SIZE := Vector2(240.0, 100.0)
const MARGIN := 6.0
const REFRESH_SECONDS := 0.25
const DIRT := Color(0.78, 0.6, 0.44)
const STEEL := Color(0.7, 0.74, 0.78)
const WATER := Color(0.36, 0.6, 0.86)
const LAVA := Color(0.93, 0.42, 0.18)
const LEMMING := Color(0.97, 0.93, 0.84)
const HATCH := Color(0.4, 0.82, 0.45)
const EXIT := Color(1.0, 0.84, 0.32)
const TRAP := Color(0.78, 0.36, 0.84)
const BACK := Color(0.06, 0.14, 0.17, 0.82)

var sim: LevelSim
## Záběr kamery v logických souřadnicích (nastavuje hra každý snímek).
var view_rect := Rect2()
## Zapnuto v nastavení (skutečná viditelnost navíc závisí na misi).
var enabled := true
## Velikost rozhraní (HUD): mapa se jí zmenší, aby na obrazovce zůstala stejná.
var ui_scale := 1.0
var _image: Image
var _texture: ImageTexture
## Logických pixelů na jeden pixel mapy a měřítko kreslení mapy.
var _step := 1
var _scale := 1.0
var _version := -1
var _since_refresh := 0.0
var _dragging := false


func _init() -> void:
	name = "Minimap"
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


func setup(level_sim: LevelSim) -> void:
	sim = level_sim
	_dragging = false
	var w := sim.spec.width
	var h := sim.spec.height
	_step = maxi(ceili(maxf(w / MAX_SIZE.x, h / MAX_SIZE.y)), 1)
	var pixels := Vector2i(ceili(w / float(_step)), ceili(h / float(_step)))
	var limit := MAX_SIZE / maxf(ui_scale, 0.5)
	_scale = minf(limit.x / pixels.x, limit.y / pixels.y)
	_image = Image.create(pixels.x, pixels.y, false, Image.FORMAT_RGBA8)
	_texture = null
	_version = -1
	var outer := map_size() + Vector2(MARGIN, MARGIN) * 2.0
	PaperUi.place(self, 1.0, 0.0, 1.0, 0.0, -outer.x - 14.0, Hud.TOP_BAR_HEIGHT + 2.0, -14.0,
		Hud.TOP_BAR_HEIGHT + 2.0 + outer.y)
	_rebuild()
	visible = enabled
	queue_redraw()


## Velikost samotné mapy uvnitř rámečku (px rozhraní).
func map_size() -> Vector2:
	if _image == null:
		return Vector2.ZERO
	return Vector2(_image.get_width(), _image.get_height()) * _scale


## Bod minimapy (vlastní souřadnice) → logický bod levelu.
func to_logic(local: Vector2) -> Vector2:
	var p := (local - Vector2(MARGIN, MARGIN)) / _scale * _step
	return Vector2(clampf(p.x, 0.0, sim.spec.width), clampf(p.y, 0.0, sim.spec.height))


func _process(delta: float) -> void:
	if sim == null or not visible:
		return
	_since_refresh += delta
	if sim.mask.version != _version and _since_refresh >= REFRESH_SECONDS:
		_rebuild()
	queue_redraw()


## Obraz terénu: každý pixel mapy vzorkuje střed svého čtverce masky.
func _rebuild() -> void:
	_since_refresh = 0.0
	_version = sim.mask.version
	var mask := sim.mask
	var data := mask.data
	var bpp := TerrainMask.BYTES_PER_PIXEL
	var half := floori(_step / 2.0)
	for py in _image.get_height():
		var y := mini(py * _step + half, mask.height - 1)
		for px in _image.get_width():
			var x := mini(px * _step + half, mask.width - 1)
			var i := (y * mask.width + x) * bpp
			var color := Color.TRANSPARENT
			if data[i] != 0:
				color = STEEL if data[i + 1] != 0 else DIRT
			elif data[i + 3] == TerrainMask.Special.WATER:
				color = WATER
			elif data[i + 3] == TerrainMask.Special.LAVA:
				color = LAVA
			_image.set_pixel(px, py, color)
	if _texture == null:
		_texture = ImageTexture.create_from_image(_image)
	else:
		_texture.update(_image)


func _draw() -> void:
	if sim == null or _texture == null:
		return
	var origin := Vector2(MARGIN, MARGIN)
	var k := _scale / _step
	draw_rect(Rect2(Vector2.ZERO, size), BACK)
	draw_rect(Rect2(Vector2.ZERO, size), Color(PaperUi.TEXT, 0.5), false, 1.5)
	draw_texture_rect(_texture, Rect2(origin, map_size()), false)
	for trap: Dictionary in sim.spec.traps:
		var at: Vector2i = trap["at"]
		draw_rect(Rect2(origin + Vector2(at) * k - Vector2(2, 3), Vector2(4, 3)), TRAP)
	for hatch in sim.spec.hatches:
		draw_rect(Rect2(origin + Vector2(hatch) * k - Vector2(3, 3), Vector2(6, 5)), HATCH)
	for exit in sim.spec.exits:
		draw_rect(Rect2(origin + Vector2(exit) * k - Vector2(3, 6), Vector2(6, 6)), EXIT)
	for lem in sim.lemmings:
		if not lem.removed:
			draw_rect(Rect2(origin + Vector2(lem.x, lem.y - 4) * k - Vector2(1, 1.5), Vector2(2, 3)),
				LEMMING)
	if view_rect.size != Vector2.ZERO:
		var top_left := origin + view_rect.position * k
		var frame := Rect2(top_left, view_rect.size * k).intersection(Rect2(origin, map_size()))
		draw_rect(frame, PaperUi.ACCENT, false, 1.5)


func _gui_input(event: InputEvent) -> void:
	if sim == null:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index \
			== MOUSE_BUTTON_LEFT:
		_dragging = event.is_pressed()
		if _dragging:
			focus_requested.emit(to_logic((event as InputEventMouseButton).position))
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		focus_requested.emit(to_logic((event as InputEventMouseMotion).position))
		accept_event()
