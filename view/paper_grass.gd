class_name PaperGrass
extends Node2D
## Papírová tráva rostoucí vzhůru z původního povrchu (z pruhu zeleného drnu).
## Stébla se kývají ve větru: kořen stojí, špička se hýbe nejvíc. Trs zmizí,
## když pod ním zmizí zem nebo když na něj někdo položí cihlu. Jen vzhled:
## kreslí se za postavami, kolize dál řídí maska.

const COLORS := [Color("9a9a4e"), Color("b5b45e"), Color("7c8240"), Color("9aa456")]
const LIGHT := Color("d8cf7e")
## Podíl sloupců povrchu, ve kterých roste trs (deterministický výběr).
const DENSITY := 340

var mask: TerrainMask
## Herní čas v ticích (ve stop-motion po krocích).
var time := 0.0
## Trsy: x, y povrchu, semínko.
var tufts: Array[Vector3i] = []


func setup(terrain_mask: TerrainMask, surface: Array[Vector2i]) -> void:
	mask = terrain_mask
	tufts.clear()
	for point in surface:
		var seed := posmod(point.x * 7919 + point.y * 104729, 1000)
		if seed < DENSITY:
			tufts.append(Vector3i(point.x, point.y, seed))
	queue_redraw()


## Roste trs ještě? Pod ním musí být zem a nad ním volno (ne cihla).
func tuft_visible(tuft: Vector3i) -> bool:
	return mask.is_solid(tuft.x, tuft.y) and not mask.is_solid(tuft.x, tuft.y - 1)


## Vrchol stébla `blade` v trsu (logické px) v aktuálním čase.
func blade_tip(tuft: Vector3i, blade: int) -> Vector2:
	var r := float(posmod(tuft.z * 31 + blade * 17, 100)) / 100.0
	var height := 1.3 + 1.9 * float(posmod(tuft.z * 13 + blade * 29, 100)) / 100.0
	var sway := (sin(time * 0.23 + tuft.x * 0.045 + blade * 0.9) * 0.3
		+ sin(time * 0.61 + tuft.x * 0.13) * 0.08) * height
	return Vector2(tuft.x + 0.5 + (r - 0.5) * 1.6 + (r - 0.5) * 0.9 + sway, tuft.y - height)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if mask == null:
		return
	for tuft in tufts:
		if not tuft_visible(tuft):
			continue
		var blades := 2 + tuft.z % 3
		for blade in blades:
			var r := float(posmod(tuft.z * 31 + blade * 17, 100)) / 100.0
			var root := Vector2(tuft.x + 0.5 + (r - 0.5) * 1.6, tuft.y + 0.4)
			var tip := blade_tip(tuft, blade)
			var w := 0.3 + 0.18 * r
			# Stéblo se ohýbá: střed se posune jen o část výchylky špičky.
			var mid := root.lerp(tip, 0.55) + Vector2((tip.x - root.x) * -0.15, 0.0)
			var color: Color = COLORS[posmod(tuft.z + blade, COLORS.size())]
			draw_colored_polygon(PackedVector2Array([
				root + Vector2(-w, 0.0), mid + Vector2(-w * 0.55, 0.0), tip,
				mid + Vector2(w * 0.55, 0.0), root + Vector2(w, 0.0)]), color)
			# Světlá polovina stébla (přehyb papíru, světlo zleva).
			draw_colored_polygon(PackedVector2Array([
				root + Vector2(-w, 0.0), mid + Vector2(-w * 0.55, 0.0), tip, mid, root]),
				color.lerp(LIGHT, 0.35))
