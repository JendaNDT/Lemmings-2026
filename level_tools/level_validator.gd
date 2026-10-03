@tool
class_name LevelValidator
extends RefCounted
## Kontrola levelu: najde častá opomenutí dřív, než se level hraje.
## Vrací srozumitelné české věty; prázdný seznam = bez nálezu.
## Používá ji editor (varování u kořene levelu) i testy všech misí.


static func problems_for(level: LevelDefinition) -> PackedStringArray:
	return problems(LevelLoader.build_spec(level), LevelLoader.build_mask(level))


static func problems(spec: LevelSpec, mask: TerrainMask) -> PackedStringArray:
	var out := PackedStringArray()
	var bounds := Rect2i(0, 0, spec.width, spec.height)
	if spec.hatches.is_empty():
		out.append("Chybí líheň (uzel LemmingHatch).")
	if spec.exits.is_empty():
		out.append("Chybí východ (uzel LemmingExit).")
	if spec.save_required > spec.lemming_count:
		out.append("Požadavek na záchranu (%d) je vyšší než počet lumíků (%d)."
			% [spec.save_required, spec.lemming_count])
	for hatch in spec.hatches:
		var name := "Líheň na %s" % str(hatch)
		if not bounds.has_point(hatch):
			out.append(name + " je mimo level.")
			continue
		if mask.is_solid(hatch.x, hatch.y):
			out.append(name + " je zarostlá v terénu.")
		if not mask.has_solid_in_rect(hatch.x, hatch.y, 1, spec.height - hatch.y):
			out.append(name + ": pod ní není žádná zem, lumíci vypadnou z mapy.")
		if _hazard_below(mask, hatch):
			out.append(name + ": lumíci padají rovnou do vody nebo lávy.")
	for exit in spec.exits:
		var name := "Východ na %s" % str(exit)
		if not bounds.has_point(exit):
			out.append(name + " je mimo level.")
			continue
		var reach := Rect2i(exit.x - SimConst.EXIT_REACH_X, exit.y - SimConst.EXIT_REACH_Y,
			SimConst.EXIT_REACH_X * 2 + 1, SimConst.EXIT_REACH_Y + 2)
		if not mask.has_solid_in_rect(reach.position.x, reach.position.y, reach.size.x, reach.size.y):
			out.append(name + " visí ve vzduchu – postav ho na zem.")
		elif mask.is_solid(exit.x, exit.y - 1) and mask.is_solid(exit.x, exit.y - SimConst.EXIT_REACH_Y):
			out.append(name + " je zasypaný terénem.")
		if _hazard_in_rect(mask, reach):
			out.append(name + " leží ve vodě nebo v lávě.")
	for i in spec.traps.size():
		var trap: Dictionary = spec.traps[i]
		var at: Vector2i = trap["at"]
		var name := "Past na %s" % str(at)
		if not bounds.has_point(at):
			out.append(name + " je mimo level.")
			continue
		if not mask.is_solid(at.x, at.y):
			out.append(name + " visí ve vzduchu – postav ji na zem.")
		for exit in spec.exits:
			if (trap["rect"] as Rect2i).grow(SimConst.EXIT_REACH_X + 2).has_point(exit):
				out.append(name + " zakrývá východ.")
	return out


static func _hazard_below(mask: TerrainMask, from: Vector2i) -> bool:
	for y in range(from.y, mask.height):
		if mask.is_solid(from.x, y):
			return false
		if mask.hazard_at(from.x, y) != TerrainMask.Special.NONE:
			return true
	return false


static func _hazard_in_rect(mask: TerrainMask, rect: Rect2i) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if mask.hazard_at(x, y) != TerrainMask.Special.NONE:
				return true
	return false
