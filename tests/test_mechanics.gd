extends SimTest
## Mezní situace fyziky a pravidel, které nesmí změnit nový renderer.


func _initialize() -> void:
	_test_falls()
	_test_steps()
	_test_blocker()
	_test_builder()
	_test_digging()
	_test_assignments()
	_test_exits_and_end()
	_test_exit_boundaries()
	_test_spawning()
	_test_terrain()
	finish()


func _test_falls() -> void:
	for distance in [SimConst.SAFE_FALL_DISTANCE, SimConst.SAFE_FALL_DISTANCE + 1]:
		var sim := fixture()
		var lem := add_lemming(sim, 60, 80 - distance)
		sim.set_state(lem, Lemming.State.FALLER)
		while lem.state == Lemming.State.FALLER and sim.tick_count < 100:
			sim.tick()
		var safe: bool = distance <= SimConst.SAFE_FALL_DISTANCE
		var expected: int = Lemming.State.WALKER if safe else Lemming.State.SPLATTING
		check(lem.state == expected and lem.y == 80, "hranice pádu: %d pixelů" % distance)
		if not safe:
			advance(sim, SimConst.SPLAT_TICKS - 1)
			check(sim.lost == 0, "nebezpečný pád počká na konec animace")
			sim.tick()
			sim.remove_lemming(lem, false)
			check(sim.lost == 1 and lem.removed, "smrt se započítá právě jednou")
	var empty := fixture()
	empty.mask.erase_rect(0, 0, empty.mask.width, empty.mask.height)
	var falling := add_lemming(empty, 60, empty.mask.height - 2)
	empty.set_state(falling, Lemming.State.FALLER)
	empty.tick()
	check(empty.lost == 1 and falling.removed, "pád pod spodní okraj levelu")


func _test_steps() -> void:
	for direction in [-1, 1]:
		for height in [SimConst.MAX_STEP_UP, SimConst.MAX_STEP_UP + 1]:
			var sim := fixture()
			var lem := add_lemming(sim)
			lem.dir = direction
			paint_rect(sim.mask, Rect2i(60 + direction, 80 - height, 1, height))
			sim.tick()
			var climbed: bool = height <= SimConst.MAX_STEP_UP
			check(
				(lem.x == 60 + direction and lem.y == 80 - height) if climbed
				else (lem.x == 60 and lem.dir == -direction),
				"schod %d pixelů, směr %d" % [height, direction]
			)
	for depth in [SimConst.MAX_STEP_DOWN, SimConst.MAX_STEP_DOWN + 1]:
		var sim := fixture()
		var lem := add_lemming(sim)
		sim.mask.erase_rect(61, 80, 20, depth)
		sim.tick()
		check(
			lem.state == (Lemming.State.WALKER if depth == SimConst.MAX_STEP_DOWN
			else Lemming.State.FALLER), "sestup %d pixelů" % depth
		)


func _test_blocker() -> void:
	var sim := fixture()
	var blocker := add_lemming(sim, 80)
	sim.assign_skill(blocker, Lemming.Skill.BLOCKER)
	var left := add_lemming(sim, 74)
	var right := add_lemming(sim, 86)
	right.dir = -1
	sim.tick()
	check(left.dir == -1 and right.dir == 1, "blokař otáčí příchozí z obou stran")
	left.x = 74
	left.dir = 1
	left.y = blocker.y - SimConst.BLOCKER_FIELD_HEIGHT - 1
	check(not sim.is_blocked(left), "blokař neovlivňuje jiné patro")
	sim.mask.erase_rect(80, 80, 1, 10)
	sim.tick()
	check(blocker.state == Lemming.State.FALLER, "blokař bez podpory začne padat")
	left.y = blocker.y
	check(not sim.is_blocked(left), "padající bývalý blokař už nezastaví chodce")


func _test_builder() -> void:
	for direction in [-1, 1]:
		var sim := fixture()
		var lem := add_lemming(sim)
		lem.dir = direction
		sim.assign_skill(lem, Lemming.Skill.BUILDER)
		advance(sim, SimConst.BUILDER_TICKS_PER_BRICK * (SimConst.BUILDER_BRICKS - 1)
			+ SimConst.BUILDER_BRICK_PHASE)
		check(
			lem.bricks_left == 0 and lem.state == Lemming.State.SHRUGGING
			and lem.y == 80 - SimConst.BUILDER_BRICKS
			and lem.x == 60 + 2 * SimConst.BUILDER_BRICKS * direction,
			"stavitel dokončí všech 12 schodů, směr %d" % direction
		)
		check(sim.mask.is_solid(lem.x, lem.y), "poslední schod nese stavitele")
		advance(sim, SimConst.SHRUG_TICKS)
		check(lem.state == Lemming.State.WALKER, "stavitel po upozornění pokračuje chůzí")
	var ceiling := fixture()
	var builder := add_lemming(ceiling)
	paint_rect(ceiling.mask, Rect2i(61, 70, 8, 1))
	ceiling.assign_skill(builder, Lemming.Skill.BUILDER)
	advance(ceiling, SimConst.BUILDER_BRICK_PHASE)
	check(builder.state == Lemming.State.WALKER and builder.dir == -1,
		"stavitel se pod nízkým stropem otočí")


func _test_digging() -> void:
	for direction in [-1, 1]:
		for steel in [false, true]:
			var sim := fixture()
			var lem := add_lemming(sim)
			lem.dir = direction
			var edge := 61 if direction > 0 else 52
			paint_rect(sim.mask, Rect2i(edge, 60, 8, 20),
				TerrainMask.Kind.STEEL if steel else TerrainMask.Kind.DIRT)
			sim.assign_skill(lem, Lemming.Skill.BASHER)
			advance(sim, SimConst.BASHER_TICKS_PER_STEP)
			if steel:
				check(lem.state == Lemming.State.WALKER and lem.dir == -direction
					and sim.mask.is_steel(60 + direction, 75),
					"razič zachová ocel a otočí se, směr %d" % direction)
			else:
				check(lem.state == Lemming.State.BASHER and lem.x == 60 + direction
					and not sim.mask.is_solid(60 + direction, 75),
					"razič prokope hlínu, směr %d" % direction)
	for steel in [false, true]:
		var sim := fixture()
		var lem := add_lemming(sim)
		if steel:
			paint_rect(sim.mask, Rect2i(64, 80, 1, 1), TerrainMask.Kind.STEEL)
		sim.assign_skill(lem, Lemming.Skill.DIGGER)
		advance(sim, SimConst.DIGGER_TICKS_PER_ROW)
		check(
			(lem.y == 80 and lem.state == Lemming.State.WALKER
			and sim.mask.is_solid(60, 80)) if steel else
			(lem.y == 81 and not sim.mask.has_solid_in_rect(56, 80, 9, 1)),
			"kopáč kontroluje celou šířku oceli" if steel else "kopáč vykope celou řadu hlíny"
		)


func _test_assignments() -> void:
	var sim := fixture()
	var lem := add_lemming(sim)
	var foreign := add_lemming(fixture())
	var count: int = sim.skills[Lemming.Skill.BUILDER]
	check(not sim.assign_skill(foreign, Lemming.Skill.BUILDER)
		and not sim.assign_skill(null, Lemming.Skill.BUILDER), "cizí a chybějící lumík se odmítne")
	check(not sim.assign_skill(lem, 999), "neexistující dovednost se odmítne")
	sim.skills[Lemming.Skill.DIGGER] = 0
	check(not sim.assign_skill(lem, Lemming.Skill.DIGGER), "vyčerpaná dovednost se odmítne")
	check(sim.assign_skill(lem, Lemming.Skill.BUILDER)
		and not sim.assign_skill(lem, Lemming.Skill.BUILDER)
		and sim.skills[Lemming.Skill.BUILDER] == count - 1 and sim.replay_log.size() == 1,
		"opakované přidělení nespotřebuje další dovednost ani záznam")
	sim.remove_lemming(lem, false)
	check(not sim.assign_skill(lem, Lemming.Skill.BASHER), "odstraněný lumík příkaz nepřijme")


func _test_exits_and_end() -> void:
	var sim := fixture(1)
	sim.spec.exits.append(Vector2i(62, 80))
	var lem := add_lemming(sim)
	sim.tick()
	check(lem.state == Lemming.State.EXITING and sim.saved == 0 and not sim.finished,
		"východ spustí animaci, výsledek ještě neuzavře")
	advance(sim, SimConst.EXIT_TICKS)
	sim.remove_lemming(lem, true)
	check(sim.saved == 1 and sim.lost == 0 and sim.finished and sim.is_won(),
		"poslední zachráněný ukončí vítězný level a započítá se jednou")
	var frozen := snapshot(sim)
	advance(sim, 10)
	check(not sim.change_release_rate(1) and not sim.assign_skill(lem, Lemming.Skill.BUILDER)
		and snapshot(sim) == frozen, "dokončený level odmítá tiky i příkazy")
	var blocked := fixture(1)
	blocked.skills[Lemming.Skill.BOMBER] = 0
	blocked.spec.exits.append(Vector2i(60, 80))
	var blocker := add_lemming(blocked)
	blocked.assign_skill(blocker, Lemming.Skill.BLOCKER)
	blocked.tick()
	check(blocked.finished and not blocked.is_won() and blocked.saved == 0,
		"samotný blokař ukončí level, východ ho nezachrání")
	var timeout := fixture()
	timeout.spec.time_limit_seconds = 1
	advance(timeout, SimConst.TICKS_PER_SECOND - 1)
	check(not timeout.finished and timeout.time_left_seconds() == 1, "čas zbývá do posledního tiku")
	timeout.tick()
	check(timeout.finished and timeout.time_left_ticks() == 0 and not timeout.is_won(),
		"časový limit skončí přesně v určeném tiku")
	var ongoing := fixture(2)
	var saved := add_lemming(ongoing)
	add_lemming(ongoing)
	ongoing.remove_lemming(saved, true)
	ongoing.tick()
	check(ongoing.is_won() and not ongoing.finished, "splněný cíl nechá dohrát zbývající lumíky")


func _test_exit_boundaries() -> void:
	for entry in [
		[Vector2i(63, 80), true], [Vector2i(64, 80), false],
		[Vector2i(61, 88), true], [Vector2i(61, 89), false],
		[Vector2i(61, 79), true], [Vector2i(61, 78), false],
	]:
		var sim := fixture()
		var lem := add_lemming(sim)
		sim.spec.exits.append(entry[0])
		sim.tick()
		check((lem.state == Lemming.State.EXITING) == entry[1],
			"hranice vstupu do východu %s" % str(entry[0]))
	var deadly := fixture()
	deadly.spec.exits.append(Vector2i(60, 80))
	var falling := add_lemming(deadly, 60, 80)
	deadly.set_state(falling, Lemming.State.FALLER)
	falling.fall_distance = SimConst.SAFE_FALL_DISTANCE + 1
	deadly.tick()
	check(falling.state == Lemming.State.SPLATTING and deadly.saved == 0,
		"východ nezachrání lumíka po smrtelném pádu")


func _test_spawning() -> void:
	var sim := fixture(3)
	sim.spec.hatches.assign([Vector2i(30, 20), Vector2i(110, 20)])
	advance(sim, SimConst.HATCH_OPEN_TICKS - 1)
	check(sim.spawned == 0, "líheň se neotevře předčasně")
	sim.tick()
	check(sim.spawned == 1 and sim.lemmings[0].x == 30, "první líheň se otevře v tiku 34")
	var interval := sim.spawn_interval_ticks()
	sim.change_release_rate(1000)
	advance(sim, interval - 1)
	check(sim.spawned == 1, "změna rychlosti neposouvá již naplánovaný výstup")
	sim.tick()
	check(sim.spawned == 2 and sim.lemmings[1].x == 110, "líhně se pravidelně střídají")
	advance(sim, 4)
	check(sim.spawned == 3 and sim.lemmings_waiting() == 0 and sim.release_rate == 99,
		"další interval používá novou rychlost a nepřekročí počet lumíků")
	sim.change_release_rate(-1000)
	check(sim.release_rate == 50, "vypouštění neklesne pod počáteční rychlost")
	for rate in [-10, 150]:
		var spec := LevelSpec.new()
		spec.release_rate = rate
		var bounded := LevelSim.new(spec, TerrainMask.new(10, 10))
		bounded.change_release_rate(-1000)
		check(bounded.release_rate == (1 if rate < 1 else 99), "neplatný výchozí limit se omezí")


func _test_terrain() -> void:
	var mask := TerrainMask.new(16, 16)
	paint_rect(mask, Rect2i(0, 0, 16, 16))
	paint_rect(mask, Rect2i(6, 6, 4, 4), TerrainMask.Kind.STEEL)
	mask.erase_circle(5, 5, 3)
	check(not mask.is_solid(5, 5) and mask.is_solid(2, 2) and mask.is_steel(6, 6),
		"kruhové kopání zachová ocel a buňky mimo kruh")
	mask.erase_rect(-10, -10, 50, 50)
	check(mask.is_steel(6, 6) and not mask.is_solid(0, 0), "kopání mimo mapu se ořízne, ocel zůstane")
	var version := mask.version
	mask.erase_rect(6, 6, 4, 4)
	mask.add_brick_row(6, 9, 6)
	check(mask.version == version and mask.is_steel(6, 6), "kopání a stavba nepřepíše ocel")
	mask.add_brick_row(20, -20, 2)
	check(mask.is_solid(0, 2) and mask.is_solid(15, 2),
		"stavba v obou směrech se ořízne na mapu")
	mask.erase_rect(0, 2, 16, 1)
	check(mask.data[(2 * 16) * 4 + 2] == 0, "kopání odstraní také značku cihly")
	check(mask.is_solid(-1, 8) and mask.is_steel(16, 8)
		and not mask.is_solid(8, -1) and not mask.is_solid(8, 16),
		"boky jsou zeď, horní a dolní okraj volno")
