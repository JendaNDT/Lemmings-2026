class_name ReferencePlans
extends RefCounted
## Referenční řešení misí jako plány pro čistou simulaci (stejná jako v testech
## a ověřeních etap). Plán se volá po každém tiku: plan.call(sim, stav).
## Používá je měření obtížnosti (LevelDifficulty, scripts/difficulty_report.gd).
## Nová mise kampaně má mít svůj plán zde.


## id mise → plán (Callable), nebo prázdný Callable, když plán chybí.
static func plan_for(id: String) -> Callable:
	match id:
		"dira-v-louce":
			return _first_hole
		"schody-na-terasu":
			return _terrace
		"hlidka-u-srazu":
			return _cliff_guard
		"prvni-kroky", "vsech-osm-dovednosti":
			return _first_steps
		"lezec-a-padak":
			return _climb_float
		"sikmy-tunel":
			return _miner
		"cesta-skrz-zed":
			return _bomber
		"ocelove-koreny":
			return _steel_roots
		"propadlo":
			return _trapdoor
		"dlouha-lavka":
			return _long_bridge
		"mlynsky-spech":
			return _mill_rush
		"voda-lava-past":
			return _hazards
	return Callable()


## První chodec na louce (x ≥ 100) prokope díru do jeskyně.
static func _first_hole(sim: LevelSim, s: Dictionary) -> void:
	for lem in sim.lemmings:
		if not s.get("done", false) and not lem.removed and lem.state == Lemming.State.WALKER \
				and lem.x >= 100:
			s["done"] = sim.assign_skill(lem, Lemming.Skill.DIGGER)


## Stavitel 16 px před stupněm terasy (x = 214, směr doprava).
static func _terrace(sim: LevelSim, s: Dictionary) -> void:
	for lem in sim.lemmings:
		if not s.get("done", false) and not lem.removed and lem.state == Lemming.State.WALKER \
				and lem.dir == 1 and lem.x == 214:
			s["done"] = sim.assign_skill(lem, Lemming.Skill.BUILDER)


## Blokař před srázem (x ≥ 290), kopáč u prvního lumíka, který se od něj vrací.
static func _cliff_guard(sim: LevelSim, s: Dictionary) -> void:
	for lem in sim.lemmings:
		if lem.removed or lem.state != Lemming.State.WALKER:
			continue
		if not s.get("blocked", false) and lem.dir == 1 and lem.x >= 290:
			s["blocked"] = sim.assign_skill(lem, Lemming.Skill.BLOCKER)
		elif s.get("blocked", false) and not s.get("dug", false) and lem.dir == -1 \
				and lem.x <= 200:
			s["dug"] = sim.assign_skill(lem, Lemming.Skill.DIGGER)


## Razič prorazí sloup, stavitel postaví schody na útes, kopáč prokope do jeskyně.
static func _first_steps(sim: LevelSim, s: Dictionary) -> void:
	for lem in sim.lemmings:
		if lem.removed or lem.state != Lemming.State.WALKER:
			continue
		if not s.get("bashed", false) and lem.dir == 1 and lem.x >= 170 and lem.x <= 175:
			s["bashed"] = sim.assign_skill(lem, Lemming.Skill.BASHER)
		elif s.get("bashed", false) and not s.get("built", false) and lem.dir == 1 \
				and lem.x >= 280 and lem.x <= 284:
			s["built"] = sim.assign_skill(lem, Lemming.Skill.BUILDER)
		elif s.get("built", false) and not s.get("dug", false) and lem.y <= 58 \
				and lem.x >= 330 and lem.x <= 360:
			s["dug"] = sim.assign_skill(lem, Lemming.Skill.DIGGER)


## Každá postava dostane hned po vypadnutí lezce i padák.
static func _climb_float(sim: LevelSim, _s: Dictionary) -> void:
	for lem in sim.lemmings:
		if not lem.removed and not lem.can_climb:
			sim.assign_skill(lem, Lemming.Skill.CLIMBER)
			sim.assign_skill(lem, Lemming.Skill.FLOATER)


## První chodec na x = 80 začne kopat šikmý tunel.
static func _miner(sim: LevelSim, s: Dictionary) -> void:
	for lem in sim.lemmings:
		if not s.get("done", false) and not lem.removed and lem.state == Lemming.State.WALKER \
				and lem.x == 80:
			s["done"] = sim.assign_skill(lem, Lemming.Skill.MINER)


## První chodec u zdi (x = 168) se zastaví jako blokař a dostane bombu.
static func _bomber(sim: LevelSim, s: Dictionary) -> void:
	for lem in sim.lemmings:
		if not s.get("done", false) and not lem.removed and lem.state == Lemming.State.WALKER \
				and lem.x == 168:
			sim.assign_skill(lem, Lemming.Skill.BLOCKER)
			s["done"] = sim.assign_skill(lem, Lemming.Skill.BOMBER)


## Mise 6: první lumík jako lezec postaví most přes jezírko a prokope se
## do chodby; později druhý razič otevře jednosměrnou zeď pro ostatní.
static func _hazards(sim: LevelSim, s: Dictionary) -> void:
	if sim.lemmings.is_empty():
		return
	var hero := sim.lemmings[0]
	var ready := hero.state == Lemming.State.WALKER and hero.dir == 1 and not hero.removed
	if not s.has("climb") and not hero.removed:
		if sim.assign_skill(hero, Lemming.Skill.CLIMBER):
			s["climb"] = sim.tick_count
	elif not s.has("build") and ready and hero.x >= 224 and hero.y == 100:
		if sim.assign_skill(hero, Lemming.Skill.BUILDER):
			s["build"] = sim.tick_count
	elif s.has("build") and not s.has("dig") and ready and hero.x >= 350 and hero.y == 100:
		if sim.assign_skill(hero, Lemming.Skill.DIGGER):
			s["dig"] = sim.tick_count
	elif not s.has("bash") and sim.tick_count >= 400:
		for lem in sim.lemmings:
			if lem.id != 0 and not lem.removed and lem.state == Lemming.State.WALKER \
					and lem.dir == 1 and lem.x >= 134 and lem.x < 140:
				if sim.assign_skill(lem, Lemming.Skill.BASHER):
					s["bash"] = sim.tick_count
				break


## Razič u hliněného kmene (x = 145), za ním kopáč do jeskyně (x = 240).
static func _steel_roots(sim: LevelSim, s: Dictionary) -> void:
	for lem in sim.lemmings:
		if lem.removed or lem.state != Lemming.State.WALKER or lem.dir != 1:
			continue
		if not s.get("bashed", false) and lem.x == 145:
			s["bashed"] = sim.assign_skill(lem, Lemming.Skill.BASHER)
		elif s.get("bashed", false) and not s.get("dug", false) and lem.x == 240:
			s["dug"] = sim.assign_skill(lem, Lemming.Skill.DIGGER)


## Bomba prvnímu lumíkovi hned po dopadu; v jeskyni stavitel před stupněm.
static func _trapdoor(sim: LevelSim, s: Dictionary) -> void:
	if sim.lemmings.is_empty():
		return
	var first := sim.lemmings[0]
	if not s.get("bomb", false) and first.state == Lemming.State.WALKER:
		s["bomb"] = sim.assign_skill(first, Lemming.Skill.BOMBER)
	for lem in sim.lemmings:
		if not s.get("built", false) and not lem.removed and lem.state == Lemming.State.WALKER \
				and lem.dir == 1 and lem.y == 130 and lem.x == 236:
			s["built"] = sim.assign_skill(lem, Lemming.Skill.BUILDER)


## Lezec přeleze ohrádku, postaví dvoje schody přes propast (druhé při
## pokrčení ramen) a po dokončení razič otevře ohrádku zevnitř.
static func _long_bridge(sim: LevelSim, s: Dictionary) -> void:
	if sim.lemmings.is_empty():
		return
	var hero := sim.lemmings[0]
	if not s.has("climb") and not hero.removed:
		if sim.assign_skill(hero, Lemming.Skill.CLIMBER):
			s["climb"] = sim.tick_count
	elif not s.has("b1") and hero.state == Lemming.State.WALKER and hero.dir == 1 \
			and hero.x == 214 and hero.y == 120:
		if sim.assign_skill(hero, Lemming.Skill.BUILDER):
			s["b1"] = sim.tick_count
	elif s.has("b1") and not s.has("b2") and hero.state == Lemming.State.SHRUGGING:
		if sim.assign_skill(hero, Lemming.Skill.BUILDER):
			s["b2"] = sim.tick_count
	elif s.has("b2") and not s.has("bash") and hero.state != Lemming.State.BUILDER:
		for lem in sim.lemmings:
			if lem.id != 0 and not lem.removed and lem.state == Lemming.State.WALKER \
					and lem.dir == 1 and lem.x >= 142 and lem.x <= 146:
				if sim.assign_skill(lem, Lemming.Skill.BASHER):
					s["bash"] = sim.tick_count
				break


## Razič prorazí hráz, hned potom vypouštění na 99, stavitel před stupněm k mlýnu.
static func _mill_rush(sim: LevelSim, s: Dictionary) -> void:
	if s.get("bashed", false) and not s.get("fast", false):
		s["fast"] = sim.change_release_rate(SimConst.MAX_RELEASE_RATE - sim.release_rate)
	for lem in sim.lemmings:
		if lem.removed or lem.state != Lemming.State.WALKER or lem.dir != 1:
			continue
		if not s.get("bashed", false) and lem.x == 195:
			s["bashed"] = sim.assign_skill(lem, Lemming.Skill.BASHER)
		elif not s.get("built", false) and lem.x == 370 and lem.y == 120:
			s["built"] = sim.assign_skill(lem, Lemming.Skill.BUILDER)

