class_name TouchControls
extends RefCounted
## Gesta vlastní jen dotyky začaté v herní ploše. HUD obslouží Godot.
## Kamera (PaperCamera) musí mít metody pan_screen(), zoom_at()
## a vlastnosti top_padding / bottom_padding.

const DRAG_THRESHOLD := 14.0
const MAX_ZOOM_STEP := 1.5
var camera
var tapped := Callable()
## Náhled cíle: volá se s bodem dotyku, dokud jde o klepnutí (prst drží bez
## posunu), a s Vector2.INF, když se z dotyku stane posun, gesto nebo konec.
var preview := Callable()
var _points: Dictionary = {}
var _start := Vector2.ZERO
var _moved := false


func clear() -> void:
	_points.clear()
	_moved = false
	_preview(Vector2.INF)


func _preview(point: Vector2) -> void:
	if preview.is_valid():
		preview.call(point)


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
			_preview(event.position)
		else:
			_moved = true
			_preview(Vector2.INF)
	elif _points.has(event.index):
		var is_tap := _points.size() == 1 and not _moved and not event.canceled \
			and event.position.distance_to(_start) < DRAG_THRESHOLD
		_points.erase(event.index)
		_preview(Vector2.INF)
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
		_preview(Vector2.INF)
		camera.pan_screen(previous, event.position)
		return
	# Dva prsty současně posouvají i přibližují kolem svého středu.
	var keys := _points.keys()
	var a: Vector2 = _points[keys[0]]
	var b: Vector2 = _points[keys[1]]
	var old_center := (a + b) * 0.5
	var old_distance := maxf(a.distance_to(b), 1)
	_points[event.index] = event.position
	a = _points[keys[0]]
	b = _points[keys[1]]
	var ratio := clampf(a.distance_to(b) / old_distance, 1.0 / MAX_ZOOM_STEP, MAX_ZOOM_STEP)
	# Bod pod středem prstů zůstane pod nimi i při současném posunu.
	camera.zoom_at(old_center, ratio)
	camera.pan_screen(old_center, (a + b) * 0.5)
