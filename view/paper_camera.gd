class_name PaperCamera
extends Node
## Kamera 2D origami: jediná herní transformace logika → obrazovka.
##
## Terén, postavy, líheň, východ i schody používají `game_transform()`.
## Dekorativní vrstvy z ní jen odvozují vlastní posun a zoom (PaperParallax).
## Zoom drží bod pod kurzorem / středem gesta, pokud to dovolí hranice mapy.

const SCROLL_SPEED := 1400.0
const EDGE_SIZE := 18.0
const MIN_ZOOM := 1.0
const MAX_ZOOM := 3.2
const WHEEL_STEP := 1.15

var focus := Vector2.ZERO
var zoom_factor := 1.0
var top_padding := Hud.TOP_BAR_HEIGHT
var bottom_padding := Hud.BOTTOM_BAR_HEIGHT
var input_enabled := true
## Velikost obrazovky; null = aktuální viewport (testy mohou zadat vlastní).
var viewport_override := Vector2.ZERO
var level_size := Vector2(640, 200)
var _dragging := false


func setup(size: Vector2, initial_focus: Vector2, initial_zoom := 1.25) -> void:
	level_size = Vector2(maxf(size.x, 1), maxf(size.y, 1))
	focus = initial_focus
	zoom_factor = clampf(initial_zoom, MIN_ZOOM, MAX_ZOOM)
	_dragging = false
	refresh()


func viewport_size() -> Vector2:
	if viewport_override != Vector2.ZERO:
		return viewport_override
	if is_inside_tree():
		return get_viewport().get_visible_rect().size
	return Vector2(1920, 1080)


## Výška herní plochy mezi horní a spodní lištou HUDu.
func usable_height() -> float:
	return maxf(viewport_size().y - top_padding - bottom_padding, 100.0)


## Měřítko, při kterém se celá výška levelu vejde mezi lišty (zoom 1×).
func fit_scale() -> float:
	return usable_height() / level_size.y


## Obrazovkových pixelů na jeden logický pixel.
func pixel_scale() -> float:
	return fit_scale() * zoom_factor


## Střed herní plochy na obrazovce (mezi lištami HUDu).
func screen_center() -> Vector2:
	var vp := viewport_size()
	return Vector2(vp.x * 0.5, top_padding + usable_height() * 0.5)


func game_transform() -> Transform2D:
	var s := pixel_scale()
	return Transform2D(0.0, Vector2(s, s), 0.0, screen_center() - focus * s)


func logic_to_screen(point: Vector2) -> Vector2:
	return (point - focus) * pixel_scale() + screen_center()


func screen_to_logic(point: Vector2) -> Vector2:
	return (point - screen_center()) / pixel_scale() + focus


## Udrží střed v hranicích levelu; užší level se vycentruje.
func refresh() -> void:
	zoom_factor = clampf(zoom_factor, MIN_ZOOM, MAX_ZOOM)
	var s := pixel_scale()
	var half := Vector2(viewport_size().x, usable_height()) / s * 0.5
	for axis in 2:
		if half[axis] * 2.0 >= level_size[axis]:
			focus[axis] = level_size[axis] * 0.5
		else:
			focus[axis] = clampf(focus[axis], half[axis], level_size[axis] - half[axis])


## Přiblížení o poměr `ratio` kolem bodu obrazovky (kurzor, střed dvou prstů).
func zoom_at(screen_point: Vector2, ratio: float) -> void:
	var anchor := screen_to_logic(screen_point)
	zoom_factor = clampf(zoom_factor * ratio, MIN_ZOOM, MAX_ZOOM)
	focus = anchor - (screen_point - screen_center()) / pixel_scale()
	refresh()


## Posun tak, aby bod z `from` putoval pod `to` (tažení prstem či myší).
func pan_screen(from: Vector2, to: Vector2) -> void:
	focus += (from - to) / pixel_scale()
	refresh()


func _process(delta: float) -> void:
	if input_enabled:
		var move := Vector2(
			float(Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D))
			- float(Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S))
			- float(Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W)))
		var vp := viewport_size()
		var mouse := get_viewport().get_mouse_position()
		if not DeviceProfile.touch_mode() and get_window().has_focus() and not _dragging \
				and mouse.y > top_padding and mouse.y < vp.y - bottom_padding \
				and mouse.x >= 0 and mouse.x < vp.x:
			if mouse.x < EDGE_SIZE:
				move.x -= 1
			elif mouse.x > vp.x - EDGE_SIZE:
				move.x += 1
		if move != Vector2.ZERO:
			focus += move * SCROLL_SPEED * delta / pixel_scale()
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(button.position, WHEEL_STEP)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(button.position, 1.0 / WHEEL_STEP)
	elif event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		zoom_at(magnify.position, magnify.factor)
	elif event is InputEventPanGesture:
		var pan := event as InputEventPanGesture
		pan_screen(pan.position, pan.position - pan.delta * 8.0)
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		pan_screen(motion.position - motion.relative, motion.position)


func _input(event: InputEvent) -> void:
	# Uvolnění tlačítka nad HUDem se k _unhandled_input nedostane.
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not button.pressed and button.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_dragging = false
