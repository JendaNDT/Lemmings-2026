class_name TerrainMask
extends RefCounted
## Logická mapa terénu: pro každý pixel víme, jestli je pevný, ocelový nebo postavený.
##
## Tohle je „pravda“, podle které se lumíci pohybují. Grafika ji jen obkresluje
## shaderem v mnohem vyšším rozlišení (viz view/terrain.gdshader).
##
## Data jsou uložená rovnou ve formátu GPU textury RGBA8 (4 bajty na pixel),
## takže se dají poslat na grafickou kartu bez přepočítávání:
##   R = pevný terén (0 / 255)
##   G = ocel – nejde prokopat (0 / 255)
##   B = postavené cihly od stavitele (0 / 255) – jen kvůli vzhledu
##   A = zatím nevyužito

enum Kind { DIRT, STEEL, ERASE }

const BYTES_PER_PIXEL := 4
const ON := 255

var width: int
var height: int
var data := PackedByteArray()
## Zvýší se při každé změně – grafika podle toho pozná, že má texturu obnovit.
var version := 0


func _init(w: int, h: int) -> void:
	width = maxi(w, 1)
	height = maxi(h, 1)
	data.resize(width * height * BYTES_PER_PIXEL)
	data.fill(0)


## Je na daném místě pevný terén? Boky levelu se chovají jako zeď,
## nad levelem i pod ním je volno (pod levelem je propast).
func is_solid(x: int, y: int) -> bool:
	if x < 0 or x >= width:
		return true
	if y < 0 or y >= height:
		return false
	return data[(y * width + x) * BYTES_PER_PIXEL] != 0


## Je na daném místě ocel? Boky levelu jsou taky „ocel“.
func is_steel(x: int, y: int) -> bool:
	if x < 0 or x >= width:
		return true
	if y < 0 or y >= height:
		return false
	return data[(y * width + x) * BYTES_PER_PIXEL + 1] != 0


func has_solid_in_rect(x0: int, y0: int, w: int, h: int) -> bool:
	for y in range(maxi(y0, 0), mini(y0 + h, height)):
		for x in range(maxi(x0, 0), mini(x0 + w, width)):
			if data[(y * width + x) * BYTES_PER_PIXEL] != 0:
				return true
	return false


func has_steel_in_rect(x0: int, y0: int, w: int, h: int) -> bool:
	for y in range(maxi(y0, 0), mini(y0 + h, height)):
		for x in range(maxi(x0, 0), mini(x0 + w, width)):
			if data[(y * width + x) * BYTES_PER_PIXEL + 1] != 0:
				return true
	return false


## Vykope obdélník (ocel zůstane). Vrací true, pokud se něco opravdu ubralo.
func erase_rect(x0: int, y0: int, w: int, h: int) -> bool:
	var changed := false
	for y in range(maxi(y0, 0), mini(y0 + h, height)):
		for x in range(maxi(x0, 0), mini(x0 + w, width)):
			changed = _erase(x, y) or changed
	if changed:
		version += 1
	return changed


## Vykope kruh (ocel zůstane) – pro výbuchy.
func erase_circle(cx: int, cy: int, radius: int) -> bool:
	var changed := false
	var r2 := radius * radius
	for y in range(maxi(cy - radius, 0), mini(cy + radius + 1, height)):
		for x in range(maxi(cx - radius, 0), mini(cx + radius + 1, width)):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= r2:
				changed = _erase(x, y) or changed
	if changed:
		version += 1
	return changed


## Přidá vodorovnou řadu postavených pixelů (cihla stavitele).
## Nepřepisuje existující terén ani ocel.
func add_brick_row(x_from: int, x_to: int, y: int) -> void:
	if y < 0 or y >= height:
		return
	var changed := false
	for x in range(maxi(mini(x_from, x_to), 0), mini(maxi(x_from, x_to), width - 1) + 1):
		var i := (y * width + x) * BYTES_PER_PIXEL
		if data[i] == 0:
			data[i] = ON
			data[i + 2] = ON
			changed = true
	if changed:
		version += 1


## Vyplní mnohoúhelník daným druhem terénu (používá se při načítání levelu).
## Pozdější tvary přemalují ty dřívější – stejně jako vrstvy v editoru.
func paint_polygon(points: PackedVector2Array, kind: Kind) -> void:
	var n := points.size()
	if n < 3:
		return
	var min_y := INF
	var max_y := -INF
	for p in points:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	var crossings := PackedFloat32Array()
	for y in range(maxi(floori(min_y), 0), mini(ceili(max_y), height - 1) + 1):
		# Řádkový algoritmus: najdi, kde střed řádku protíná hrany, a vyplň mezi nimi.
		var sy := y + 0.5
		crossings.clear()
		for i in n:
			var a := points[i]
			var b := points[(i + 1) % n]
			if (a.y <= sy and b.y > sy) or (b.y <= sy and a.y > sy):
				crossings.append(a.x + (sy - a.y) * (b.x - a.x) / (b.y - a.y))
		crossings.sort()
		var k := 0
		while k + 1 < crossings.size():
			var xa := maxi(ceili(crossings[k] - 0.5), 0)
			var xb := mini(floori(crossings[k + 1] - 0.5), width - 1)
			for x in range(xa, xb + 1):
				_paint(x, y, kind)
			k += 2
	version += 1


func _erase(x: int, y: int) -> bool:
	var i := (y * width + x) * BYTES_PER_PIXEL
	if data[i] == 0 or data[i + 1] != 0:
		return false
	data[i] = 0
	data[i + 2] = 0
	return true


func _paint(x: int, y: int, kind: Kind) -> void:
	var i := (y * width + x) * BYTES_PER_PIXEL
	match kind:
		Kind.DIRT:
			data[i] = ON
			data[i + 1] = 0
		Kind.STEEL:
			data[i] = ON
			data[i + 1] = ON
		Kind.ERASE:
			data[i] = 0
			data[i + 1] = 0
	data[i + 2] = 0
