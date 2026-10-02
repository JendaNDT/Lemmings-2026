extends SimTest
## Trvalé vlastnosti, šikmé tunely, souběžné odpočty a hromadné ukončení.


func _initialize() -> void:
	_test_traits()
	_test_climbing()
	_test_parachutes()
	_test_mining()
	_test_bombs()
	_test_nuke()
	_test_replay()
	finish()


func _test_traits() -> void:
	var sim := fixture()
	var lem := add_lemming(sim)
	sim.assign_skill(lem, Lemming.Skill.BUILDER)
	advance(sim, 3)
	check(sim.assign_skill(lem, Lemming.Skill.CLIMBER)
		and sim.assign_skill(lem, Lemming.Skill.FLOATER), "trvalé vlastnosti se kombinují")
	check(lem.state == Lemming.State.BUILDER and lem.state_ticks == 3,
		"přidělení vlastností nezruší ani neposune pracovní činnost")
	var counts := sim.skills.duplicate()
	var commands := sim.replay_log.size()
	check(not sim.assign_skill(lem, Lemming.Skill.CLIMBER)
		and not sim.assign_skill(lem, Lemming.Skill.FLOATER)
		and counts == sim.skills and sim.replay_log.size() == commands,
		"opakování vlastností nespotřebuje zásobu ani nezapíše příkaz")
	sim.set_state(lem, Lemming.State.FALLER)
	sim.set_state(lem, Lemming.State.WALKER)
	check(lem.can_climb and lem.has_floater, "vlastnosti přežijí změny stavů")
	for state in [Lemming.State.SPLATTING, Lemming.State.EXITING]:
		var dying := add_lemming(sim)
		sim.set_state(dying, state)
		var accepted := false
		for skill in Lemming.SKILL_ORDER:
			accepted = sim.can_assign(dying, skill) or accepted
		check(not accepted, "umírající ani odcházející lumík nepřijme dovednost: %d" % state)


func _test_climbing() -> void:
	for direction in [-1, 1]:
		var sim := fixture()
		var lem := add_lemming(sim)
		lem.dir = direction
		paint_rect(sim.mask, Rect2i(61 if direction > 0 else 45, 40, 15, 40))
		sim.assign_skill(lem, Lemming.Skill.CLIMBER)
		sim.tick()
		check(lem.state == Lemming.State.CLIMBER and lem.dir == direction,
			"lezec se na vysoké zdi neotočí, směr %d" % direction)
		advance(sim, 41)
		check(lem.state == Lemming.State.WALKER and lem.x == 60 + direction
			and lem.y == 40, "lezec vystoupí na hranu zdi, směr %d" % direction)
		var ceiling := fixture()
		var stuck := add_lemming(ceiling)
		stuck.dir = direction
		paint_rect(ceiling.mask, Rect2i(61 if direction > 0 else 45, 30, 15, 50))
		paint_rect(ceiling.mask, Rect2i(60, 55, 1, 1))
		ceiling.assign_skill(stuck, Lemming.Skill.CLIMBER)
		advance(ceiling, 17)
		check(stuck.state == Lemming.State.FALLER and stuck.dir == -direction,
			"strop odrazí lezce do pádu, směr %d" % direction)
	var boundary := fixture()
	var edge := add_lemming(boundary, 0)
	edge.dir = -1
	boundary.assign_skill(edge, Lemming.Skill.CLIMBER)
	boundary.tick()
	check(edge.dir == 1 and edge.state == Lemming.State.WALKER,
		"lezec neleze po neviditelném okraji mapy")


func _test_parachutes() -> void:
	for late in [false, true]:
		var sim := fixture()
		var lem := add_lemming(sim, 60, 0)
		sim.set_state(lem, Lemming.State.FALLER)
		if late:
			advance(sim, 22)
		check(sim.assign_skill(lem, Lemming.Skill.FLOATER), "padák lze přidělit během pádu")
		var opened := false
		while lem.state in [Lemming.State.FALLER, Lemming.State.FLOATER] and sim.tick_count < 150:
			sim.tick()
			opened = opened or lem.state == Lemming.State.FLOATER
		check(opened and lem.state == Lemming.State.WALKER and lem.y == 80
			and sim.lost == 0, "padák zachrání dlouhý pád i při pozdním přidělení: %s" % late)
	var short_fall := fixture()
	var short_lem := add_lemming(short_fall, 60, 74)
	short_fall.set_state(short_lem, Lemming.State.FALLER)
	short_fall.assign_skill(short_lem, Lemming.Skill.FLOATER)
	advance(short_fall, 3)
	check(short_lem.state == Lemming.State.WALKER and short_lem.has_floater,
		"krátký pád nepotřebuje rozvinutí padáku")
	var abyss := fixture()
	abyss.mask.erase_rect(0, 0, 160, 128)
	var lost := add_lemming(abyss, 60, 126)
	abyss.assign_skill(lost, Lemming.Skill.FLOATER)
	abyss.set_state(lost, Lemming.State.FLOATER)
	advance(abyss, 3)
	check(lost.removed and abyss.lost == 1, "padák nezachrání pád mimo mapu")


func _test_mining() -> void:
	for direction in [-1, 1]:
		var sim := fixture()
		var lem := add_lemming(sim)
		lem.dir = direction
		check(sim.assign_skill(lem, Lemming.Skill.MINER), "horníka lze přidělit")
		advance(sim, SimConst.MINER_TICKS_PER_STEP * 3)
		check(lem.x == 60 + direction * 6 and lem.y == 83
			and lem.state == Lemming.State.MINER and sim.mask.is_solid(lem.x, lem.y)
			and not sim.mask.has_solid_in_rect(lem.x, lem.y - 10, 1, 10),
			"horník vytvoří sestupný průchozí tunel, směr %d" % direction)
		var steel := fixture()
		var stopped := add_lemming(steel)
		stopped.dir = direction
		paint_rect(steel.mask, Rect2i(60 + direction * 4, 79, 1, 1), TerrainMask.Kind.STEEL)
		var before := steel.mask.data.duplicate()
		steel.assign_skill(stopped, Lemming.Skill.MINER)
		advance(steel, SimConst.MINER_TICKS_PER_STEP)
		check(stopped.state == Lemming.State.WALKER and stopped.dir == -direction
			and steel.mask.data == before, "ocel zastaví celý úder horníka, směr %d" % direction)
	var open := fixture()
	var falling := add_lemming(open)
	open.mask.erase_rect(56, 81, 12, 47)
	open.assign_skill(falling, Lemming.Skill.MINER)
	advance(open, SimConst.MINER_TICKS_PER_STEP)
	check(falling.state == Lemming.State.FALLER, "horník po proražení podlahy začne padat")


func _test_bombs() -> void:
	var sim := fixture()
	var worker := add_lemming(sim)
	sim.assign_skill(worker, Lemming.Skill.BUILDER)
	check(sim.assign_skill(worker, Lemming.Skill.BOMBER), "bomba se přidělí během práce")
	advance(sim, 8)
	check(worker.state == Lemming.State.BUILDER and worker.bricks_left == 11
		and worker.bomb_ticks == SimConst.BOMB_TICKS - 8,
		"odpočet běží souběžně se stavbou")
	var remaining := worker.bomb_ticks
	check(not sim.assign_skill(worker, Lemming.Skill.BOMBER) and worker.bomb_ticks == remaining,
		"další bomba neobnoví odpočet")
	var single := fixture(1)
	var blocker := add_lemming(single)
	single.assign_skill(blocker, Lemming.Skill.BLOCKER)
	single.tick()
	check(not single.finished, "dostupná bomba nechá možnost odblokovat konec levelu")
	paint_rect(single.mask, Rect2i(65, 80, 2, 2), TerrainMask.Kind.STEEL)
	single.assign_skill(blocker, Lemming.Skill.BOMBER)
	single.skills[Lemming.Skill.BOMBER] = 0
	advance(single, SimConst.BOMB_TICKS - 1)
	check(not single.finished and not blocker.removed and blocker.bomb_ticks == 1,
		"čekající bomba zabrání předčasnému konci samotného blokaře")
	single.take_events()
	single.tick()
	var events := single.take_events()
	check(single.finished and single.lost == 1 and blocker.removed
		and events.size() == 1 and events[0].type == "explode"
		and not single.mask.is_solid(60, 80) and single.mask.is_steel(65, 80),
		"výbuch nastane přesně po pěti sekundách a zachová ocel")
	var escaping := fixture(1)
	escaping.spec.exits.append(Vector2i(62, 80))
	var safe := add_lemming(escaping)
	escaping.assign_skill(safe, Lemming.Skill.BOMBER)
	advance(escaping, SimConst.EXIT_TICKS + 1)
	check(escaping.saved == 1 and escaping.lost == 0 and safe.bomb_ticks < 0,
		"vstup do východu před výbuchem zruší odpočet")


func _test_nuke() -> void:
	var sim := fixture(4)
	for x in [20, 60, 100]:
		var lem := add_lemming(sim, x)
		sim.assign_skill(lem, Lemming.Skill.BLOCKER)
	var stock := sim.skills.duplicate()
	check(sim.start_nuke() and not sim.start_nuke(), "hromadné ukončení lze spustit pouze jednou")
	sim.tick()
	check(sim.lemmings[0].bomb_ticks > 0 and sim.lemmings[1].bomb_ticks < 0
		and sim.lemmings_waiting() == 0, "hromadné ukončení zapaluje postupně a zavře líheň")
	advance(sim, SimConst.BOMB_TICKS + 2 * SimConst.NUKE_INTERVAL)
	check(sim.finished and sim.lost == 3 and sim.spawned == 3 and sim.skills == stock,
		"hromadné ukončení dohraje odpočty bez spotřeby zásoby bombičů")
	var early := fixture(2)
	early.spec.hatches.append(Vector2i(40, 50))
	early.start_nuke()
	advance(early, SimConst.HATCH_OPEN_TICKS + 2)
	check(early.finished and early.spawned == 0, "ukončení před otevřením líhně nikoho nevypustí")


func _test_replay() -> void:
	var original := fixture()
	original.spec.hatches.append(Vector2i(60, 80))
	advance(original, SimConst.HATCH_OPEN_TICKS)
	for skill in [Lemming.Skill.CLIMBER, Lemming.Skill.FLOATER,
			Lemming.Skill.BOMBER, Lemming.Skill.MINER]:
		original.assign_skill(original.lemmings[0], skill)
	advance(original, 10)
	original.start_nuke()
	while not original.finished and original.tick_count < 300:
		original.tick()
	var fresh := fixture()
	fresh.spec.hatches.append(Vector2i(60, 80))
	var serialized: Array = JSON.parse_string(JSON.stringify(original.replay_log))
	var replay := SimReplay.new(fresh, serialized)
	while not fresh.finished and replay.error.is_empty() and fresh.tick_count < 300:
		replay.step()
	check(original.finished and replay.error.is_empty() and snapshot(original) == snapshot(fresh)
		and original.take_events() == fresh.take_events(),
		"JSON replay zachová vlastnosti, horníka, odpočty i hromadné ukončení")
