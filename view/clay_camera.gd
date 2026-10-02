class_name ClayCamera
extends Camera3D
## Pevný ortografický směr, posun a zoom. Výběr se promítá do roviny postav.

const TILT := 0.2094395102  # 12 stupňů, žádná volná rotace kamery.
const SCROLL_SPEED := 1400.0

var focus := Vector2.ZERO
var zoom_factor := 1.0
var top_padding := Hud.TOP_BAR_HEIGHT
var bottom_padding := Hud.BOTTOM_BAR_HEIGHT
var input_enabled := true
var _level_size := Vector2(640, 200)
var _dragging := false


func setup(level_size: Vector2, initial_focus: Vector2) -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	keep_aspect = Camera3D.KEEP_HEIGHT
	near = 0.1
	far = 200
	current = true
	_level_size = level_size
	focus = initial_focus
	zoom_factor = 1.4 if DeviceProfile.touch_mode() else 1.0
	_dragging = false
	refresh()


func screen_to_logic(point: Vector2) -> Vector2:
	var plane := Plane(Vector3.BACK, ClaySpace.ACTOR_Z)
	var hit: Variant = plane.intersects_ray(project_ray_origin(point), project_ray_normal(point))
	if hit == null:
		return Vector2(-INF, -INF)
	return ClaySpace.to_logic(hit as Vector3)


func logic_to_screen(point: Vector2) -> Vector2:
	return unproject_position(ClaySpace.to_world(point))


func refresh() -> void:
	var vp := get_viewport().get_visible_rect().size
	var usable := maxf(vp.y - top_padding - bottom_padding, 100)
	size = _level_size.y * ClaySpace.UNIT * cos(TILT) * vp.y / usable / zoom_factor
	var scale_y := usable * zoom_factor / _level_size.y
	var scale_x := scale_y / cos(TILT)
	var half_width := vp.x / scale_x * 0.5
	focus.x = clampf(focus.x, half_width, _level_size.x - half_width) \
		if half_width * 2 < _level_size.x else _level_size.x * 0.5
	var half_height := usable / scale_y * 0.5
	focus.y = clampf(focus.y, half_height, _level_size.y - half_height)
	var target := ClaySpace.to_world(focus + Vector2(0,
		(bottom_padding - top_padding) / (2.0 * scale_y)))
	position = target + Vector3(0, sin(TILT), cos(TILT)) * 70.0
	look_at(target)


func _process(delta: float) -> void:
	if input_enabled:
		var move := Vector2(
			float(Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D))
			- float(Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S))
			- float(Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W)))
		var mouse := get_viewport().get_mouse_position()
		var vp := get_viewport().get_visible_rect().size
		if not DeviceProfile.touch_mode() and get_window().has_focus() \
				and not _dragging and mouse.y > top_padding \
				and mouse.y < vp.y - bottom_padding and mouse.x >= 0 and mouse.x < vp.x:
			if mouse.x < 18:
				move.x -= 1
			elif mouse.x > vp.x - 18:
				move.x += 1
		focus += move * SCROLL_SPEED * delta * size / vp.y / ClaySpace.UNIT
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = button.pressed
		elif button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var before := screen_to_logic(button.position)
			zoom_factor = clampf(zoom_factor *
				(1.15 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 1, 3.2)
			refresh()
			focus += before - screen_to_logic(button.position)
			refresh()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		focus += screen_to_logic(motion.position - motion.relative) - screen_to_logic(motion.position)
		refresh()


func _input(event: InputEvent) -> void:
	# Uvolnění nad HUDem se k _unhandled_input nedostane.
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not button.pressed and button.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_dragging = false
