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
## Stabilní identifikátor pro ukládání postupu (malá písmena, číslice, pomlčky).
## Po vydání mise ho neměnit, jinak hráči ztratí její výsledky.
@export var level_id := ""
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

@export_group("Kampaň")
## Mistrovský výsledek (★★★): kolik lumíků zachrání referenční řešení
## (tests/reference_plans.gd). Musí být víc než cíl mise.
@export_range(0, 200) var master_saved := 0
## Změřený index obtížnosti 0–100 (scripts/difficulty_report.gd); určuje pásmo.
@export_range(0, 100) var difficulty_index := 0
## Co mise nově učí – štítek na úvodní kartě (např. „Kopáč“).
@export var introduces := ""
## Krátký úvod na úvodní kartě mise.
@export_multiline var briefing := ""
## Nápovědy od obecné po konkrétní (pauzovací menu, po opakovaném neúspěchu).
@export var hints: PackedStringArray = []
## Záznam referenčního řešení pro „Ukázku řešení“: čtveřice tik, druh, cíl,
## hodnota (jako LevelSim.replay_log). Generuje scripts/update_solutions.gd
## z tests/reference_plans.gd; ručně neupravovat.
@export var solution := PackedInt32Array()
## Vlastní prostředí mise (PaperTheme): prázdné = podle kapitoly, „podzemi“ =
## jeskyně a důl pro patrové mise. Jen vzhled.
@export var scenery := ""


## Uložené řešení jako příkazy pro SimReplay ([] = mise ho nemá).
func solution_commands() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(0, solution.size() - 3, 4):
		out.append({"tick": solution[i], "kind": solution[i + 1], "target": solution[i + 2],
			"value": solution[i + 3]})
	return out


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
