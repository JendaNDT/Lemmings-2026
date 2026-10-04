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
		"hladova-kytka":
			return _hungry_plant
		"sipky-v-utesu":
			return _arrow_cliff
		"brod":
			return _ford
		"pod-sopkou":
			return _volcano
		"dve-lihne":
			return _two_hatches
		"lavova-lavka":
			return _lava_bridges
		"velky-sestup":
			return _descent
		"origami-finale":
			return _finale
		"dulni-patra":
			return _mine_floors
		"mraveniste":
			return _anthill
		"podzemni-vodopad":
			return _cave_falls
		"hluboka-sachta":
			return _deep_shaft
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



## Stavitel před kamenným stupněm, za stupněm blokař před kytkou drží dav
## (zpátky na stupeň se nevyleze); když jsou všichni u něj, bomba ho uvolní
## a hustý dav proběhne, než se kytka dobije.
static func _hungry_plant(sim: LevelSim, s: Dictionary) -> void:
	for lem in sim.lemmings:
		if lem.removed or lem.state != Lemming.State.WALKER or lem.dir != 1:
			continue
		if not s.get("built", false) and lem.x == 138:
			s["built"] = sim.assign_skill(lem, Lemming.Skill.BUILDER)
		elif not s.has("block") and lem.x == 240 and lem.y >= 109:
			if sim.assign_skill(lem, Lemming.Skill.BLOCKER):
				s["block"] = lem.id
	if not s.has("block") or s.has("bomb") or sim.spawned < sim.spec.lemming_count:
		return
	for lem in sim.lemmings:
		if not lem.removed and lem.id != int(s["block"]) and lem.x < 210:
			return
	if sim.assign_skill(sim.lemmings[int(s["block"])], Lemming.Skill.BOMBER):
		s["bomb"] = sim.tick_count


## Razič prorazí zeď se šipkou doprava, mezi zdmi kopáč do střední jeskyně,
## tam horník šikmo skrz útes.
static func _arrow_cliff(sim: LevelSim, s: Dictionary) -> void:
	for lem in sim.lemmings:
		if lem.removed or lem.state != Lemming.State.WALKER or lem.dir != 1:
			continue
		if not s.get("bashed", false) and lem.x == 112:
			s["bashed"] = sim.assign_skill(lem, Lemming.Skill.BASHER)
		elif s.get("bashed", false) and not s.get("dug", false) and lem.y <= 62 and lem.x == 200:
			s["dug"] = sim.assign_skill(lem, Lemming.Skill.DIGGER)
		elif s.get("dug", false) and not s.get("mined", false) and lem.y == 100 and lem.x == 324:
			s["mined"] = sim.assign_skill(lem, Lemming.Skill.MINER)


## První lumík staví most (druhého stavitele při pokrčení ramen), druhý
## jako blokař drží dav; po přechodu mostu bomba na blokaře.
static func _ford(sim: LevelSim, s: Dictionary) -> void:
	if sim.lemmings.is_empty():
		return
	var hero := sim.lemmings[0]
	if not s.has("b1") and hero.state == Lemming.State.WALKER and hero.dir == 1 and hero.x == 232:
		if sim.assign_skill(hero, Lemming.Skill.BUILDER):
			s["b1"] = sim.tick_count
	elif s.has("b1") and not s.has("b2") and hero.state == Lemming.State.SHRUGGING:
		if sim.assign_skill(hero, Lemming.Skill.BUILDER):
			s["b2"] = sim.tick_count
	elif s.has("b2") and not s.has("bomb") and (hero.removed or hero.x >= 280):
		for lem in sim.lemmings:
			if lem.state == Lemming.State.BLOCKER and not lem.removed:
				if sim.assign_skill(lem, Lemming.Skill.BOMBER):
					s["bomb"] = sim.tick_count
	if not s.has("block") and sim.lemmings.size() > 1:
		var second := sim.lemmings[1]
		if second.state == Lemming.State.WALKER and second.dir == 1 and second.x == 196:
			if sim.assign_skill(second, Lemming.Skill.BLOCKER):
				s["block"] = sim.tick_count


## Horník asi 65 px před lávovým jezerem (tunel vede pod lávou do jeskyně),
## hned potom vypouštění na 99, aby dav došel ke kytce pohromadě; v jámě
## za kytkou dvoje schody na římsu s východem.
static func _volcano(sim: LevelSim, s: Dictionary) -> void:
	if s.has("mined") and not s.get("fast", false):
		s["fast"] = sim.change_release_rate(SimConst.MAX_RELEASE_RATE - sim.release_rate)
	for lem in sim.lemmings:
		if lem.removed or lem.state != Lemming.State.WALKER or lem.dir != 1:
			continue
		if not s.has("mined") and lem.y == 100 and lem.x == 185:
			if sim.assign_skill(lem, Lemming.Skill.MINER):
				s["mined"] = lem.id
		elif not s.has("b1") and lem.y == 184 and lem.x == 436:
			if sim.assign_skill(lem, Lemming.Skill.BUILDER):
				s["b1"] = lem.id
	if s.has("b1") and not s.has("b2"):
		var builder := sim.lemmings[int(s["b1"])]
		if builder.state == Lemming.State.SHRUGGING and sim.assign_skill(builder, Lemming.Skill.BUILDER):
			s["b2"] = builder.id


## Vpravo lávka přes kanál od samého břehu a blokař za ní, vlevo dvoje
## schody ke stěně kopce; po přechodu lávky bomba na blokaře.
static func _two_hatches(sim: LevelSim, s: Dictionary) -> void:
	for lem in sim.lemmings:
		if lem.removed or lem.state != Lemming.State.WALKER:
			continue
		if not s.has("left") and lem.dir == 1 and lem.x == 220 and lem.y == 150:
			if sim.assign_skill(lem, Lemming.Skill.BUILDER):
				s["left"] = lem.id
		elif not s.has("bridge") and lem.dir == -1 and lem.x == 402:
			if sim.assign_skill(lem, Lemming.Skill.BUILDER):
				s["bridge"] = lem.id
		elif s.has("bridge") and not s.has("block") and lem.dir == -1 and lem.x == 440:
			if sim.assign_skill(lem, Lemming.Skill.BLOCKER):
				s["block"] = lem.id
	if s.has("left") and not s.has("left2"):
		var builder := sim.lemmings[int(s["left"])]
		if builder.state == Lemming.State.SHRUGGING and sim.assign_skill(builder, Lemming.Skill.BUILDER):
			s["left2"] = builder.id
	if s.has("block") and not s.has("bomb"):
		var bridger := sim.lemmings[int(s["bridge"])]
		if bridger.removed or bridger.x < 370:
			if sim.assign_skill(sim.lemmings[int(s["block"])], Lemming.Skill.BOMBER):
				s["bomb"] = sim.tick_count


## Blokař drží dav, první lumík staví u samého okraje všech tří lávových
## jam, po přechodu poslední bomba na blokaře.
static func _lava_bridges(sim: LevelSim, s: Dictionary) -> void:
	if sim.lemmings.is_empty():
		return
	var hero := sim.lemmings[0]
	var walking := hero.state == Lemming.State.WALKER and hero.dir == 1 and not hero.removed
	var built := int(s.get("built", 0))
	if built < 3 and walking and hero.x == [178, 288, 398][built]:
		if sim.assign_skill(hero, Lemming.Skill.BUILDER):
			s["built"] = built + 1
	elif built == 3 and not s.has("bomb") and walking and hero.x >= 440:
		for lem in sim.lemmings:
			if lem.state == Lemming.State.BLOCKER and not lem.removed \
					and sim.assign_skill(lem, Lemming.Skill.BOMBER):
				s["bomb"] = sim.tick_count
	if not s.has("block") and sim.lemmings.size() > 1:
		var second := sim.lemmings[1]
		if second.state == Lemming.State.WALKER and second.dir == 1 and second.x == 140:
			if sim.assign_skill(second, Lemming.Skill.BLOCKER):
				s["block"] = sim.tick_count


## Průzkumník s padákem jde napřed, dav nahoře drží blokař. Průzkumník kope
## jámu v hliněném okně u druhého srázu a dole staví lávku přes jezírko;
## pak dav vedou dva horníci úzkými okny v ocelových lemech.
static func _descent(sim: LevelSim, s: Dictionary) -> void:
	if sim.lemmings.is_empty():
		return
	var scout := sim.lemmings[0]
	if not s.has("float"):
		if sim.assign_skill(scout, Lemming.Skill.FLOATER):
			s["float"] = sim.tick_count
	var scouting := scout.state == Lemming.State.WALKER and scout.dir == 1 and not scout.removed
	if not s.has("dig") and scouting and scout.y == 120 and scout.x == 226:
		if sim.assign_skill(scout, Lemming.Skill.DIGGER):
			s["dig"] = sim.tick_count
	elif not s.has("build") and scouting and scout.y == 308 and scout.x == 406:
		if sim.assign_skill(scout, Lemming.Skill.BUILDER):
			s["build"] = sim.tick_count
	for lem in sim.lemmings:
		if lem.id == 0 or lem.removed or lem.state != Lemming.State.WALKER or lem.dir != 1:
			continue
		if not s.has("block") and lem.y == 50 and lem.x == 110:
			if sim.assign_skill(lem, Lemming.Skill.BLOCKER):
				s["block"] = lem.id
		elif s.has("build") and not s.has("mine1") and lem.y == 50 and lem.x == 58:
			if sim.assign_skill(lem, Lemming.Skill.MINER):
				s["mine1"] = lem.id
		elif not s.has("mine2") and lem.y == 242 and lem.x == 331:
			if sim.assign_skill(lem, Lemming.Skill.MINER):
				s["mine2"] = lem.id


## Průzkumník (lezec s padákem) připraví celou cestu, dav zatím čeká v ohradě:
## dvoje schody přes řeku, razič skrz šipky, kopáč před skálou se šipkami
## proti směru, po střeše chodby, lávka přes lávu a dvoje schody na útes.
## Vypouštění hned na 99; razič otevře ohradu po mostě a chodbu s kytkami
## po lávce, takže dav proběhne kolem kytek pohromadě.
static func _finale(sim: LevelSim, s: Dictionary) -> void:
	if not s.has("fast"):
		if sim.change_release_rate(SimConst.MAX_RELEASE_RATE - sim.release_rate):
			s["fast"] = sim.tick_count
	if sim.lemmings.is_empty():
		return
	var hero := sim.lemmings[0]
	if not s.has("climb") and sim.assign_skill(hero, Lemming.Skill.CLIMBER):
		s["climb"] = sim.tick_count
	elif not s.has("float") and sim.assign_skill(hero, Lemming.Skill.FLOATER):
		s["float"] = sim.tick_count
	var ready := hero.state == Lemming.State.WALKER and hero.dir == 1 and not hero.removed
	var steps := [["river", 146, 160, Lemming.Skill.BUILDER], ["rock", 234, 160, Lemming.Skill.BASHER],
		["dig", 306, 160, Lemming.Skill.DIGGER], ["lava", 678, 180, Lemming.Skill.BUILDER],
		["cliff", 800, 180, Lemming.Skill.BUILDER]]
	for step in steps:
		if not s.has(step[0]) and ready and hero.x == step[1] and hero.y == step[2]:
			if sim.assign_skill(hero, step[3]):
				s[step[0]] = sim.tick_count
	if hero.state == Lemming.State.SHRUGGING:
		for key in ["river", "cliff"]:
			if s.has(key) and not s.has(key + "2") and sim.assign_skill(hero, Lemming.Skill.BUILDER):
				s[key + "2"] = sim.tick_count
	for lem in sim.lemmings:
		if lem.id == 0 or lem.removed or lem.state != Lemming.State.WALKER or lem.dir != 1:
			continue
		if s.has("river2") and hero.x >= 210 and not s.has("pen") and lem.x == 104 and lem.y == 160:
			if sim.assign_skill(lem, Lemming.Skill.BASHER):
				s["pen"] = sim.tick_count
		elif s.has("cliff2") and hero.y < 160 and not s.has("gate") and lem.x == 434 and lem.y == 180:
			if sim.assign_skill(lem, Lemming.Skill.BASHER):
				s["gate"] = sim.tick_count


## Důlní patra: kopáč na 2. patře nad hromadou hlušiny (x = 130, cestou doleva),
## na 3. patře druhý kopáč nad hromadou na dně (x = 82), dole dav dojde k východu.
static func _mine_floors(sim: LevelSim, s: Dictionary) -> void:
	for lem in sim.lemmings:
		if lem.removed or lem.state != Lemming.State.WALKER:
			continue
		if not s.has("dig2") and absi(lem.y - 115) <= 2 and lem.dir == -1 and lem.x == 130:
			if sim.assign_skill(lem, Lemming.Skill.DIGGER):
				s["dig2"] = sim.tick_count
		elif s.has("dig2") and not s.has("dig3") and absi(lem.y - 182) <= 2 and lem.x == 82:
			if sim.assign_skill(lem, Lemming.Skill.DIGGER):
				s["dig3"] = sim.tick_count


## Mraveniště: kopáč v hliněném okně horní komory (x = 260), ve druhé komoře
## bomba chodci cestou doleva (x = 215), vybuchne nad oknem v oceli (x ≈ 130);
## dole stavitel postaví schody na stupeň ke dveřím (x = 360).
static func _anthill(sim: LevelSim, s: Dictionary) -> void:
	for lem in sim.lemmings:
		if lem.removed or lem.state != Lemming.State.WALKER:
			continue
		if not s.has("dig") and absi(lem.y - 70) <= 2 and lem.x == 260:
			if sim.assign_skill(lem, Lemming.Skill.DIGGER):
				s["dig"] = sim.tick_count
		elif not s.has("bomb") and absi(lem.y - 125) <= 2 and lem.dir == -1 and lem.x == 215:
			if sim.assign_skill(lem, Lemming.Skill.BOMBER):
				s["bomb"] = sim.tick_count
		elif not s.has("build") and lem.y == 180 and lem.dir == 1 and lem.x == 360:
			if sim.assign_skill(lem, Lemming.Skill.BUILDER):
				s["build"] = sim.tick_count


## Podzemní vodopád: vypouštění hned na 99 (hustý dav projde kolem kytky),
## na třetí terase blokař před okrajem nad lávou (x = 270, cestou doleva)
## a razič skrz skálu se šipkami doprava (x = 346).
static func _cave_falls(sim: LevelSim, s: Dictionary) -> void:
	if not s.has("fast"):
		if sim.change_release_rate(SimConst.MAX_RELEASE_RATE - sim.release_rate):
			s["fast"] = sim.tick_count
	for lem in sim.lemmings:
		if lem.removed or lem.state != Lemming.State.WALKER or absi(lem.y - 150) > 2:
			continue
		if not s.has("block") and lem.dir == -1 and lem.x == 270:
			if sim.assign_skill(lem, Lemming.Skill.BLOCKER):
				s["block"] = sim.tick_count
		elif not s.has("bash") and lem.dir == 1 and lem.x == 346:
			if sim.assign_skill(lem, Lemming.Skill.BASHER):
				s["bash"] = sim.tick_count


## Hluboká šachta: vypouštění hned na 99 (dav proběhne kolem kytky), horník
## na skalním pilíři druhé římsy (x = 256), kopáč v hliněném okně ocelové
## podlahy třetí římsy (x = 280, cestou doleva) a hned po dopadu blokař
## na čtvrté římse těsně před lávou (x = 276).
static func _deep_shaft(sim: LevelSim, s: Dictionary) -> void:
	if not s.has("fast"):
		if sim.change_release_rate(SimConst.MAX_RELEASE_RATE - sim.release_rate):
			s["fast"] = sim.tick_count
	for lem in sim.lemmings:
		if lem.removed or lem.state != Lemming.State.WALKER:
			continue
		if not s.has("mine") and absi(lem.y - 95) <= 2 and lem.dir == 1 and lem.x == 256:
			if sim.assign_skill(lem, Lemming.Skill.MINER):
				s["mine"] = sim.tick_count
		elif not s.has("dig") and absi(lem.y - 165) <= 2 and lem.dir == -1 and lem.x == 280:
			if sim.assign_skill(lem, Lemming.Skill.DIGGER):
				s["dig"] = sim.tick_count
		elif not s.has("block") and absi(lem.y - 222) <= 2 and lem.dir == -1 and lem.x == 276:
			if sim.assign_skill(lem, Lemming.Skill.BLOCKER):
				s["block"] = sim.tick_count
