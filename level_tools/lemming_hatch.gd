@tool
class_name LemmingHatch
extends Marker2D
## Líheň – odsud vypadávají lumíci. Bod uzlu = místo, kde se lumík objeví.

const FRAME := Color(0.55, 0.38, 0.22)
const INSIDE := Color(0.08, 0.06, 0.05)
const GLOW := Color(1.0, 0.75, 0.35, 0.35)


func _draw() -> void:
	draw_rect(Rect2(-11, -14, 22, 9), FRAME)
	draw_rect(Rect2(-8, -11, 16, 6), INSIDE)
	draw_rect(Rect2(-8, -5, 16, 2), GLOW)
