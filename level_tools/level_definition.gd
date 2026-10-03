@tool
class_name LevelDefinition
extends Node2D
## Kořen scény levelu. Pravidla levelu se nastavují v Inspectoru vpravo.
##
## Jak postavit level v editoru Godotu:
## 1. Terén = uzly TerrainShape (mnohoúhelníky). Kreslí se nástrojem pro polygony.
##    Druh „Dirt“ = hlína, „Steel“ = ocel, „Erase“ = vyřízne díru do předchozích tvarů.
##    „Water“ a „Lava“ = voda a láva, „One Way Left/Right“ = jednosměrná zeď.
## 2. Líheň = uzel LemmingHatch, východ = uzel LemmingExit (postav ho přesně na zem).
##    Past = uzel LemmingTrap (také na zem).
## 3. Jednotky jsou „logické pixely“ – lumík je vysoký 10 px.
## 4. Varování u kořene levelu (žlutý trojúhelník) hlásí chybějící líheň,
##    východ ve vzduchu, past mimo zem a podobná opomenutí.

@export var title := "Nový level"
## Velikost levelu v logických pixelech (bílý rámeček v editoru).
@export var size := Vector2i(640, 200):
	set(value):
		size = value
		if is_inside_tree():
			queue_redraw()
@export_range(1, 200) var lemming_count := 20
@export_range(0, 200) var save_required := 10
@export_range(1, 99) var release_rate := 50
@export_range(10, 3600) var time_limit_seconds := 300

@export_group("Dovednosti")
@export_range(0, 99) var climbers := 0
@export_range(0, 99) var floaters := 0
@export_range(0, 99) var bombers := 0
@export_range(0, 99) var blockers := 0
@export_range(0, 99) var builders := 0
@export_range(0, 99) var bashers := 0
@export_range(0, 99) var miners := 0
@export_range(0, 99) var diggers := 0


func skill_counts() -> Dictionary:
	return {
		Lemming.Skill.CLIMBER: climbers,
		Lemming.Skill.FLOATER: floaters,
		Lemming.Skill.BOMBER: bombers,
		Lemming.Skill.BLOCKER: blockers,
		Lemming.Skill.BUILDER: builders,
		Lemming.Skill.BASHER: bashers,
		Lemming.Skill.MINER: miners,
		Lemming.Skill.DIGGER: diggers,
	}


func _get_configuration_warnings() -> PackedStringArray:
	return LevelValidator.problems_for(self)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, Vector2(size)), Color(1, 1, 1, 0.7), false, 1.0)
