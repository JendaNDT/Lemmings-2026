extends SimTest


func _initialize() -> void:
	_test_boundaries()
	_test_bad_records()
	_test_solution_replay()
	_test_snapshot()
	finish()


## Záložka stavu (přetáčení): kopie pokračuje přesně jako originál a nesdílí s ním data.
func _test_snapshot() -> void:
	var level := Campaign.SCENES[Campaign.index_of("origami-finale")].instantiate() \
		as LevelDefinition
	var commands := level.solution_commands()
	var original := LevelSim.new(LevelLoader.build_spec(level), LevelLoader.build_mask(level))
	level.free()
	var replay := SimReplay.new(original, commands)
	while original.tick_count < 1200:
		replay.step()
	var copy := original.snapshot()
	var same := Progress.digest(copy) == Progress.digest(original)
	# Kopie dostane zbylé příkazy ručně, originál je dál přehrává SimReplay.
	var cursor := copy.replay_log.size()
	while not original.finished:
		replay.step()
		copy.tick()
		while cursor < commands.size() and int(commands[cursor]["tick"]) == copy.tick_count:
			copy.apply_command(commands[cursor]["kind"], commands[cursor]["target"],
				commands[cursor]["value"])
			cursor += 1
	check(same and copy.finished and Progress.digest(copy) == Progress.digest(original)
		and copy.saved == 36 and copy.lemmings[0] != original.lemmings[0]
		and copy.mask.data == original.mask.data,
		"záložka stavu uprostřed finále pokračuje stejně jako originál (36/40), vlastní data")


func _test_boundaries() -> void:
	var sim := fixture()
	sim.spec.hatches.append(Vector2i(60, 80))
	check(sim.change_release_rate(10) and sim.change_release_rate(-5), "dva příkazy před prvním tikem")
	advance(sim, SimConst.HATCH_OPEN_TICKS)
	var lem := sim.lemmings[0]
	var before_tick := sim.tick_count
	check(sim.assign_skill(lem, Lemming.Skill.BUILDER)
		and sim.assign_skill(lem, Lemming.Skill.DIGGER), "dva příkazy stejnému lumíkovi během pauzy")
	check(sim.tick_count == before_tick and lem.y == 80 and lem.state == Lemming.State.DIGGER,
		"příkazy se provedou okamžitě v pořadí, ale neposunou čas ani polohu")
	var copied := sim.replay_log
	copied[0].value = 99
	copied.clear()
	check(sim.replay_log.size() == 4 and sim.replay_log[0].value == 60,
		"čtenář záznamu nemůže změnit původní příkazy")
	var fresh := fixture()
	fresh.spec.hatches.append(Vector2i(60, 80))
	var replay := SimReplay.new(fresh, sim.replay_log)
	check(fresh.tick_count == 0 and fresh.release_rate == 55, "replay provede příkazy tiku nula")
	for _tick in before_tick:
		replay.step()
	check(replay.error.is_empty() and snapshot(sim) == snapshot(fresh),
		"replay zachová pořadí více příkazů stejného tiku")
	check(not sim.apply_command(999, -1, 60)
		and not sim.apply_command(LevelSim.Command.ASSIGN_SKILL, -1, 3)
		and not sim.apply_command(LevelSim.Command.RELEASE_RATE, 0, 60)
		and not sim.change_release_rate(0) and sim.replay_log.size() == 4,
		"neplatné a prázdné příkazy se nezapisují")


func _test_bad_records() -> void:
	var valid := {"tick": 0, "kind": LevelSim.Command.RELEASE_RATE, "target": -1, "value": 60}
	var malformed: Array = [
		["text"], [{}], [{"tick": 0}],
		[{"tick": -1, "kind": 1, "target": -1, "value": 60}],
		[{"tick": 0.5, "kind": 1, "target": -1, "value": 60}],
		[{"tick": "0", "kind": 1, "target": -1, "value": 60}],
		[{"tick": INF, "kind": 1, "target": -1, "value": 60}],
		[{"tick": 0, "kind": 999, "target": -1, "value": 60}],
		[valid, {"tick": 1, "kind": 1, "target": -1, "value": 100}],
		[valid, {"tick": 1, "kind": 1, "target": -1, "value": 40}],
		[{"tick": 0, "kind": 1, "target": -1, "value": true}],
		[{"tick": 2, "kind": 1, "target": -1, "value": 65}, valid],
	]
	var rejected := true
	for record in malformed:
		var sim := fixture()
		var replay := SimReplay.new(sim, record)
		rejected = rejected and not replay.error.is_empty() and sim.replay_log.is_empty()
	check(rejected, "poškozený formát se odmítne před změnou simulace")
	var unavailable := SimReplay.new(fixture(), [
		{"tick": 0, "kind": LevelSim.Command.ASSIGN_SKILL, "target": 0, "value": 4}
	])
	check(not unavailable.error.is_empty(), "replay hlásí příkaz pro neexistujícího lumíka")
	var used := fixture()
	used.tick()
	check(not SimReplay.new(used, []).error.is_empty(), "replay odmítne rozehranou simulaci")
	var short_level := fixture()
	short_level.spec.time_limit_seconds = 1
	var beyond_end := SimReplay.new(short_level, [
		{"tick": 50, "kind": LevelSim.Command.RELEASE_RATE, "target": -1, "value": 60}
	])
	for _tick in SimConst.TICKS_PER_SECOND:
		beyond_end.step()
	check(not beyond_end.error.is_empty(), "replay neskryje příkaz za koncem levelu")


func _test_solution_replay() -> void:
	var original := level_one()
	original.change_release_rate(20)
	original.change_release_rate(-10)
	var bashed := false
	var built := false
	var dug := false
	var trace := {}
	var events: Array = []
	while not original.finished and original.tick_count < 6000:
		original.tick()
		if original.tick_count == 100:
			original.change_release_rate(5)
		for lem in original.lemmings:
			if lem.removed or lem.state != Lemming.State.WALKER:
				continue
			if not bashed and lem.dir == 1 and lem.x >= 170 and lem.x <= 175:
				bashed = original.assign_skill(lem, Lemming.Skill.BASHER)
			elif bashed and not built and lem.dir == 1 and lem.x >= 280 and lem.x <= 284:
				built = original.assign_skill(lem, Lemming.Skill.BUILDER)
			elif built and not dug and lem.y <= 58 and lem.x >= 330 and lem.x <= 360:
				dug = original.assign_skill(lem, Lemming.Skill.DIGGER)
		if original.tick_count % 17 == 0:
			trace[original.tick_count] = _digest(original)
		events.append_array(original.take_events())
	check(original.finished and original.saved == 20 and bashed and built and dug,
		"řešení s měněným vypouštěním zachrání 20 z 20")
	# Skutečný průchod JSONem: čísla z parseru jsou float, pořadí pole se zachová.
	var serialized: Array = JSON.parse_string(JSON.stringify(original.replay_log))
	for cadence in [[1.0 / 30], [1.0 / 144], [0.0, 0.008, 0.041, 0.3, 0.016, 1.0]]:
		var fresh := level_one()
		var replay := SimReplay.new(fresh, serialized)
		var replay_events: Array = []
		var accumulator := 0.0
		var frame := 0
		var identical := true
		while not fresh.finished and replay.error.is_empty() and frame < 100000:
			accumulator += cadence[frame % cadence.size()]
			var steps := 0
			while accumulator >= 1.0 / SimConst.TICKS_PER_SECOND and steps < 8:
				if not replay.step():
					break
				accumulator -= 1.0 / SimConst.TICKS_PER_SECOND
				steps += 1
				if trace.has(fresh.tick_count):
					identical = identical and trace[fresh.tick_count] == _digest(fresh)
				replay_events.append_array(fresh.take_events())
			accumulator = minf(accumulator, 1.0 / SimConst.TICKS_PER_SECOND)
			frame += 1
		check(identical and replay.error.is_empty() and replay.commands_remaining() == 0
			and snapshot(fresh) == snapshot(original) and events == replay_events,
			"JSON replay: shodný průběh, terén, lumíci i události při tempu %s" % str(cadence))


func _digest(sim: LevelSim) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(snapshot(sim)))
	return context.finish().hex_encode()
