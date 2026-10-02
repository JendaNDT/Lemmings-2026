@tool
class_name LemmingExit
extends Marker2D
## Východ – sem mají lumíci dojít. Postav bod uzlu přesně na povrch země.

const FRAME := Color(0.85, 0.72, 0.45)
const INSIDE := Color(0.05, 0.04, 0.06)
const LIGHT := Color(1.0, 0.85, 0.4, 0.5)


func _draw() -> void:
	draw_rect(Rect2(-8, -17, 16, 17), FRAME)
	draw_rect(Rect2(-5, -14, 10, 14), INSIDE)
	draw_rect(Rect2(-5, -3, 10, 3), LIGHT)
	draw_circle(Vector2(0, -20), 2.0, LIGHT)
