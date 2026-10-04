class_name ReferencePlans
extends RefCounted
## Referenční řešení misí jako plány pro čistou simulaci (stejná jako v testech
## a ověřeních etap). Plán se volá po každém tiku: plan.call(sim, stav).
## Používá je měření obtížnosti (LevelDifficulty, scripts/difficulty_report.gd).
## Nová mise kampaně má mít svůj plán zde.


## id mise → plán (Callable), nebo prázdný Callable, když plán chybí.
static func plan_for(id: String) -> Callable:
	match id:
		"prvni-kroky", "vsech-osm-dovednosti":
			return _first_steps
		"lezec-a-padak":
			return _climb_float
		"sikmy-tunel":
			return _miner
		"cesta-skrz-zed":
			return _bomber
		"voda-lava-past":
			return _hazards
	return Callable()


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
