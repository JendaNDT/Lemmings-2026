class_name GameCamera
extends Camera2D
## Kamera: posun šipkami / WASD / myší u okraje obrazovky / tažením pravým
## tlačítkem, přiblížení kolečkem. Zoom se sám přizpůsobí výšce levelu.

const SCROLL_SPEED := 1400.0  # obrazovkových pixelů za sekundu
const EDGE_SIZE := 18.0
const MAX_ZOOM_FACTOR := 2.5

## Kolik místa nahoře a dole zabírá HUD (v obrazovkových pixelech).
var top_padding := 56.0
var bottom_padding := 120.0

var _level_size := Vector2(640, 200)
var _zoom_factor := 1.0
var _dragging := false


func setup(level_size: Vector2, focus: Vector2) -> void:
	_level_size = level_size
	_zoom_factor = 1.0
	_dragging = false
	_apply_zoom()
	position = focus
	_clamp_position()


func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		move.x -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		move.x += 1.0
	if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
		move.y -= 1.0
	if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
		move.y += 1.0

	var vp := get_viewport_rect().size
	var mouse := get_viewport().get_mouse_position()
	if get_window().has_focus() and Rect2(Vector2.ZERO, vp).has_point(mouse) and not _dragging:
		if mouse.x < EDGE_SIZE:
			move.x -= 1.0
		elif mouse.x > vp.x - EDGE_SIZE:
			move.x += 1.0

	if move != Vector2.ZERO:
		position += move * SCROLL_SPEED * delta / zoom.x
	_apply_zoom()
	_clamp_position()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_zoom_factor = minf(_zoom_factor * 1.1, MAX_ZOOM_FACTOR)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_zoom_factor = maxf(_zoom_factor / 1.1, 1.0)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		position -= (event as InputEventMouseMotion).relative / zoom.x


## Zoom tak, aby se celá výška levelu vešla mezi horní a spodní lištu HUDu.
func _apply_zoom() -> void:
	var vp := get_viewport_rect().size
	var fit := maxf((vp.y - top_padding - bottom_padding) / maxf(_level_size.y, 1.0), 0.5)
	var z := fit * _zoom_factor
	zoom = Vector2(z, z)


func _clamp_position() -> void:
	var vp := get_viewport_rect().size
	var half := vp / zoom / 2.0
	var top := -top_padding / zoom.y
	var bottom := _level_size.y + bottom_padding / zoom.y
	if half.x * 2.0 >= _level_size.x:
		position.x = _level_size.x / 2.0
	else:
		position.x = clampf(position.x, half.x, _level_size.x - half.x)
	if half.y * 2.0 >= bottom - top:
		position.y = (top + bottom) / 2.0
	else:
		position.y = clampf(position.y, top + half.y, bottom - half.y)
