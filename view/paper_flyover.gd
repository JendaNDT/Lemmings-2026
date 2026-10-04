class_name PaperFlyover
extends RefCounted
## Přelet mapy na začátku mise: kamera ukáže východ, chvíli na něm zůstane
## a pak přeletí ke startovnímu záběru u líhně. Jen vzhled – simulace mezitím
## stojí a PaperCamera zůstává jediným převodem logika ↔ obrazovka.

## Jak dlouho kamera ukazuje východ, než se rozletí (s).
const HOLD_EXIT := 1.6
## Krátké zastavení u líhně, než se spustí čas (s).
const HOLD_END := 0.35
## Rychlost letu v logických pixelech za sekundu a meze délky letu (s).
const FLIGHT_SPEED := 340.0
const FLIGHT_MIN := 0.7
const FLIGHT_MAX := 2.4
## U východu je záběr o kousek širší než herní (ukáže okolí cíle).
const EXIT_ZOOM := 0.8
## Dlouhý let se uprostřed oddálí až o tento podíl zoomu (ukáže kus mapy).
const ZOOM_DIP := 0.3
## Délka letu (logické px), od které se kamera oddálí naplno.
const DIP_DISTANCE := 500.0
## Střed záběru nad patou východu (logické px; domeček je vysoký asi 44 px).
const EXIT_LIFT := 18.0
## Nejdelší krok přeletu za jeden snímek (s).
const MAX_STEP := 0.1

var camera: PaperCamera
var elapsed := 0.0
var duration := 0.0
var done := false
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _from_zoom := 1.0
var _to_zoom := 1.0
var _flight := 0.0
var _dip := 0.0


## `exit_point` = pata východu. Cílem letu je záběr, který kamera právě má
## (startovní pohled připravený prezentací).
func _init(game_camera: PaperCamera, exit_point: Vector2) -> void:
	camera = game_camera
	_to = camera.focus
	_to_zoom = camera.zoom_factor
	_from_zoom = maxf(_to_zoom * EXIT_ZOOM, PaperCamera.MIN_ZOOM)
	camera.zoom_factor = _from_zoom
	camera.focus = exit_point - Vector2(0.0, EXIT_LIFT)
	camera.refresh()
	_from = camera.focus
	var distance := _from.distance_to(_to)
	_flight = clampf(distance / FLIGHT_SPEED, FLIGHT_MIN, FLIGHT_MAX)
	_dip = ZOOM_DIP * clampf(distance / DIP_DISTANCE, 0.0, 1.0)
	duration = HOLD_EXIT + _flight + HOLD_END
	advance(0.0)


## Posune přelet o `delta` sekund skutečného času a nastaví kameru.
func advance(delta: float) -> void:
	elapsed = minf(elapsed + delta, duration)
	var t := clampf((elapsed - HOLD_EXIT) / _flight, 0.0, 1.0)
	var eased := smoothstep(0.0, 1.0, t)
	camera.zoom_factor = lerpf(_from_zoom, _to_zoom, eased) * (1.0 - _dip * sin(PI * t))
	camera.focus = _from.lerp(_to, eased)
	camera.refresh()
	done = elapsed >= duration


## Přeskočení: kamera hned skočí na startovní záběr.
func finish() -> void:
	advance(duration)


## Viditelnost štítku „Východ“ (0–1): objeví se hned, zmizí na začátku letu.
func exit_tag() -> float:
	if done:
		return 0.0
	var fade_in := clampf(elapsed / 0.25, 0.0, 1.0)
	var fade_out := 1.0 - clampf((elapsed - HOLD_EXIT) / (_flight * 0.4), 0.0, 1.0)
	return fade_in * fade_out
