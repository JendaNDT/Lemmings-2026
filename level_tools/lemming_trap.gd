@tool
class_name LemmingTrap
extends Marker2D
## Past – masožravá rostlina. Bod uzlu postav přesně na povrch země.
## Sežere prvního lumíka, jehož nohy vstoupí do spouště (obdélník nad bodem),
## pak se `rearm_ticks` tiků „dobíjí“ a ostatní lumíci projdou.

const SPOUSTA := Color(0.85, 0.3, 0.25, 0.35)
const ROSTLINA := Color(0.5, 0.58, 0.3)

## Šířka a výška spouště v logických pixelech (střed dole = bod uzlu).
@export var trigger_size := Vector2i(10, 10):
	set(value):
		trigger_size = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
		queue_redraw()
## Kolik tiků trvá, než je past znovu připravená (17 tiků = 1 s).
@export_range(1, 1000) var rearm_ticks := SimConst.TRAP_REARM_TICKS


## Obdélník spouště v buňkách levelu pro bod `cell`.
func trigger_rect(cell: Vector2i) -> Rect2i:
	return Rect2i(cell.x - trigger_size.x / 2, cell.y - trigger_size.y, trigger_size.x, trigger_size.y)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var rect := trigger_rect(Vector2i.ZERO)
	draw_rect(Rect2(rect), SPOUSTA)
	draw_line(Vector2(0, 0), Vector2(0, -3), ROSTLINA, 1.0)
	draw_circle(Vector2(-2.5, -6), 3.0, ROSTLINA)
	draw_circle(Vector2(2.5, -6), 3.0, ROSTLINA)
