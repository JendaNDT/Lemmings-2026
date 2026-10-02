class_name TouchControls
extends RefCounted
## Gesta vlastní jen dotyky začaté v herní ploše. HUD obslouží Godot.

const DRAG_THRESHOLD := 14.0
var camera: ClayCamera
var tapped := Callable()
var _points: Dictionary = {}
var _start := Vector2.ZERO
var _moved := false


func clear() -> void:
	_points.clear()
	_moved = false


func handle(event: InputEvent, viewport_size: Vector2) -> void:
	if event is InputEventScreenTouch:
		_touch(event as InputEventScreenTouch, viewport_size)
	elif event is InputEventScreenDrag:
		_drag(event as InputEventScreenDrag)


func _touch(event: InputEventScreenTouch, viewport_size: Vector2) -> void:
	if event.pressed:
		if event.position.y <= camera.top_padding \
				or event.position.y >= viewport_size.y - camera.bottom_padding:
			return
		_points[event.index] = event.position
		if _points.size() == 1:
			_start = event.position
			_moved = false
		else:
			_moved = true
	elif _points.has(event.index):
		var is_tap := _points.size() == 1 and not _moved and not event.canceled \
			and event.position.distance_to(_start) < DRAG_THRESHOLD
		_points.erase(event.index)
		if is_tap and tapped.is_valid():
			tapped.call(event.position)


func _drag(event: InputEventScreenDrag) -> void:
	if not _points.has(event.index):
		return
	var previous: Vector2 = _points[event.index]
	if _points.size() == 1:
		_points[event.index] = event.position
		if not _moved and event.position.distance_to(_start) < DRAG_THRESHOLD:
			return
		_moved = true
		camera.focus += camera.screen_to_logic(previous) - camera.screen_to_logic(event.position)
		camera.refresh()
		return
	# Dva prsty současně posouvají i přibližují kolem svého středu.
	var keys := _points.keys()
	var a: Vector2 = _points[keys[0]]
	var b: Vector2 = _points[keys[1]]
	var old_center := (a + b) * 0.5
	var old_distance := maxf(a.distance_to(b), 1)
	var anchor := camera.screen_to_logic(old_center)
	_points[event.index] = event.position
	a = _points[keys[0]]
	b = _points[keys[1]]
	camera.zoom_factor = clampf(camera.zoom_factor * a.distance_to(b) / old_distance, 1, 3.2)
	camera.refresh()
	camera.focus += anchor - camera.screen_to_logic((a + b) * 0.5)
	camera.refresh()
