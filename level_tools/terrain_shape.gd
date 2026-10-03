@tool
class_name TerrainShape
extends Polygon2D
## Kus terénu nakreslený v editoru. Při startu levelu se „vypálí“ do logické mapy
## (TerrainMask) a sám se skryje – terén pak kreslí shader.
## Tvary se vypalují v pořadí stromu scény: co je níž ve stromu, kreslí se navrch.
## Water/Lava vyplní tvar vodou/lávou (vymaže zem). One Way Left/Right je zem,
## kterou razič a horník prorazí jen ve směru šipek (doleva/doprava).

@export var kind: TerrainMask.Kind = TerrainMask.Kind.DIRT:
	set(value):
		kind = value
		_update_editor_color()


func _ready() -> void:
	_update_editor_color()


func _update_editor_color() -> void:
	match kind:
		TerrainMask.Kind.DIRT:
			color = Color(0.62, 0.42, 0.26)
		TerrainMask.Kind.STEEL:
			color = Color(0.62, 0.68, 0.78)
		TerrainMask.Kind.ERASE:
			color = Color(1.0, 0.25, 0.3, 0.45)
		TerrainMask.Kind.WATER:
			color = Color(0.35, 0.6, 0.85, 0.75)
		TerrainMask.Kind.LAVA:
			color = Color(0.95, 0.4, 0.1, 0.8)
		TerrainMask.Kind.ONE_WAY_LEFT, TerrainMask.Kind.ONE_WAY_RIGHT:
			color = Color(0.45, 0.62, 0.5)
