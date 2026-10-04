class_name LevelDifficulty
extends RefCounted
## Systém obtížnosti: měřitelný index 0–100 a pět pásem.
##
## Index se počítá z odehraného referenčního řešení mise (deterministická
## simulace, žádný odhad): jak malá je rezerva záchrany, jak přesně musí hráč
## klepnout (časové okno nejtěsnějšího zásahu), kolik zásahů a druhů dovedností
## řešení potřebuje, kolik dovedností zbývá, jak těsný je čas a kolik druhů
## nebezpečí v misi je. Popis a zdůvodnění vah: docs/HERNI_DESIGN.md.

## Váhy složek (součet 100). Vyšší složka = těžší mise.
const WEIGHTS := {
	"margin": 25, "precision": 25, "actions": 15, "variety": 10,
	"supply": 10, "time": 10, "hazards": 5,
}
## Pásma: [spodní hranice indexu, název]. Pásmo 1 = nejlehčí.
const TIERS := [
	[0, "Seznámení"], [20, "Lehká"], [40, "Střední"], [60, "Těžká"], [80, "Mistrovská"],
]
## Okno zásahu (tiky), od kterého je přesnost pohodlná (2 s), a nejtěsnější okno.
const EASY_WINDOW := 34
const TIGHT_WINDOW := 3
## Nejdelší zkoumaný posun zásahu (tiky) při hledání okna.
const MAX_SHIFT := 68


## Složky obtížnosti 0–1 z naměřených údajů (viz measure()).
static func components(m: Dictionary) -> Dictionary:
	var lemmings := maxf(float(m["lemmings"]), 1.0)
	var margin := (float(m["saved"]) - float(m["required"])) / lemmings
	# Zásah s pohodlným oknem váží méně než těsný (okno 4 s = poloviční zásah).
	var effective := 0.0
	for window: int in m["windows"]:
		effective += minf(1.0, float(EASY_WINDOW) / maxf(float(window), 1.0))
	var available := maxf(float(m["skills_available"]), 1.0)
	var usage := float(m["ticks"]) / maxf(float(m["time_limit_ticks"]), 1.0)
	# Přesnost určuje nejtěsnější zásah řešení.
	var windows: Array = m["windows"]
	var window := float(windows.min()) if not windows.is_empty() else float(MAX_SHIFT * 2 + 1)
	return {
		# Rezerva 50 % a víc = bez tlaku; žádná rezerva = plný tlak.
		"margin": clampf(1.0 - margin / 0.5, 0.0, 1.0),
		"precision": clampf((EASY_WINDOW - window) / float(EASY_WINDOW - TIGHT_WINDOW), 0.0, 1.0),
		# Jeden zásah = 0, dvanáct těsných a víc = plný počet.
		"actions": clampf((effective - 1.0) / 11.0, 0.0, 1.0),
		# Jeden druh dovednosti = 0, pět a víc druhů = plná pestrost.
		"variety": clampf((float(m["skill_types"]) - 1.0) / 4.0, 0.0, 1.0),
		# Kolik z nabídnutých kusů řešení spotřebuje (všechny = žádná rezerva).
		"supply": clampf(float(m["skills_used"]) / available, 0.0, 1.0),
		# Do 30 % času bez tlaku, 90 % a víc = těsný čas.
		"time": clampf((usage - 0.3) / 0.6, 0.0, 1.0),
		"hazards": clampf(float(m["hazard_kinds"]) / 3.0, 0.0, 1.0),
	}


static func index(m: Dictionary) -> int:
	var parts := components(m)
	var total := 0.0
	for key: String in WEIGHTS:
		total += float(WEIGHTS[key]) * float(parts[key])
	return clampi(roundi(total), 0, 100)


## Pásmo 1–5 pro index.
static func tier(value: int) -> int:
	var result := 1
	for i in TIERS.size():
		if value >= int(TIERS[i][0]):
			result = i + 1
	return result


static func tier_name(level: int) -> String:
	return TIERS[clampi(level, 1, TIERS.size()) - 1][1]


## Odehraje plán na čisté simulaci a změří údaje pro index.
## `plan` se volá po každém tiku: plan.call(sim, stav) a přiděluje dovednosti.
static func measure(spec: LevelSpec, mask: TerrainMask, plan: Callable) -> Dictionary:
	var sim := play(spec, mask, plan)
	var log := sim.replay_log.duplicate(true)
	# Rozhodnutím je každý příkaz: dovednost, změna vypouštění i hromadné ukončení.
	var types := {}
	var used := 0
	for command in log:
		if command["kind"] == LevelSim.Command.ASSIGN_SKILL:
			used += 1
			types[command["value"]] = true
	var available := 0
	for skill: int in spec.skills:
		available += int(spec.skills[skill])
	var windows: Array[int] = []
	for i in log.size():
		windows.append(_window(spec, mask, log, i))
	var idle := LevelSim.new(spec, _copy(mask))
	while not idle.finished:
		idle.tick()
	var result := {
		"lemmings": spec.lemming_count, "required": spec.save_required, "saved": sim.saved,
		"won": sim.finished and sim.is_won(), "ticks": sim.tick_count,
		"time_limit_ticks": spec.time_limit_seconds * SimConst.TICKS_PER_SECOND,
		"actions": log.size(), "skills_used": used, "skill_types": types.size(),
		"skills_available": available,
		"window_ticks": windows.min() if not windows.is_empty() else MAX_SHIFT * 2 + 1,
		"windows": windows, "hazard_kinds": hazard_kinds(spec, mask),
		"idle_saved": idle.saved, "log": log,
	}
	result["index"] = index(result)
	result["tier"] = tier(result["index"])
	return result


## Odehraje plán do konce mise na kopii masky a vrátí simulaci.
static func play(spec: LevelSpec, mask: TerrainMask, plan: Callable) -> LevelSim:
	var sim := LevelSim.new(spec, _copy(mask))
	var state := {}
	var limit := spec.time_limit_seconds * SimConst.TICKS_PER_SECOND + 60
	while not sim.finished and sim.tick_count < limit:
		sim.tick()
		plan.call(sim, state)
	return sim


## Kolik druhů nebezpečí mise obsahuje (voda, láva, jednosměrné zdi, pasti).
static func hazard_kinds(spec: LevelSpec, mask: TerrainMask) -> int:
	var found := {}
	var bpp := TerrainMask.BYTES_PER_PIXEL
	for i in mask.width * mask.height:
		var kind := mask.data[i * bpp + 3]
		if kind == TerrainMask.Special.WATER or kind == TerrainMask.Special.LAVA:
			found[kind] = true
		elif kind != TerrainMask.Special.NONE:
			found["one_way"] = true
	return found.size() + (1 if not spec.traps.is_empty() else 0)


## Časové okno zásahu: o kolik tiků dřív i později smí přijít, aby řešení
## (se stejnými ostatními zásahy) pořád vyšlo. Vrací šířku okna v tikách.
static func _window(spec: LevelSpec, mask: TerrainMask, log: Array, index_in_log: int) -> int:
	var width := 1
	for direction in [-1, 1]:
		for shift in range(1, MAX_SHIFT + 1):
			if not _wins_with_shift(spec, mask, log, index_in_log, shift * direction):
				break
			width += 1
	return width


static func _wins_with_shift(spec: LevelSpec, mask: TerrainMask, log: Array, at: int,
		shift: int) -> bool:
	var moved: Array = []
	for i in log.size():
		var command: Dictionary = log[i].duplicate()
		if i == at:
			command["tick"] = int(command["tick"]) + shift
			if command["tick"] < 0:
				return false
		moved.append(command)
	# Stabilní řazení podle tiku: ostatní zásahy zůstanou ve stejném pořadí.
	var order := range(moved.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var ta := int(moved[a]["tick"])
		var tb := int(moved[b]["tick"])
		return ta < tb or (ta == tb and a < b))
	var sorted: Array = []
	for i in order:
		sorted.append(moved[i])
	var sim := LevelSim.new(spec, _copy(mask))
	var replay := SimReplay.new(sim, sorted)
	while replay.step():
		pass
	return replay.error.is_empty() and sim.finished and sim.saved >= spec.save_required


static func _copy(mask: TerrainMask) -> TerrainMask:
	var copy := TerrainMask.new(mask.width, mask.height)
	copy.data = mask.data.duplicate()
	return copy
