extends SimTest
## Etapa 5: voda, láva, pasti a jednosměrné zdi v čisté simulaci,
## pevné pořadí událostí a kontrola levelů.


func _initialize() -> void:
	_test_water()
	_test_lava()
	_test_bridges()
	_test_traps()
	_test_one_way()
	_test_dying_rules()
	_test_loader_and_validator()
	_test_mission_six()
	finish()


## Jáma 70–89 v zemi (y 80–99) vyplněná od řádku `surface` daným druhem.
func _pool(sim: LevelSim, kind: TerrainMask.Kind, surface := 84) -> void:
	sim.mask.erase_rect(70, 80, 20, 20)
	paint_rect(sim.mask, Rect2i(70, surface, 20, 100 - surface), kind)


func _events_of(sim: LevelSim, type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in sim.take_events():
		if e["type"] == type:
			out.append(e)
	return out


func _test_water() -> void:
	var sim := fixture()
	_pool(sim, TerrainMask.Kind.WATER)
	check(sim.mask.hazard_at(75, 84) == TerrainMask.Special.WATER and not sim.mask.is_solid(75, 84)
		and sim.mask.hazard_at(75, 83) == TerrainMask.Special.NONE,
		"voda je prázdná buňka se značkou vody")
	var lem := add_lemming(sim, 66, 80)
	sim.take_events()
	var ticks := 0
	while lem.state != Lemming.State.DROWNING and ticks < 60:
		sim.tick()
		ticks += 1
	var drowned := _events_of(sim, "drown")
	check(lem.state == Lemming.State.DROWNING and drowned.size() == 1 and lem.y >= 84
		and sim.lost == 0, "lumík, který spadne do vody, se začne topit (zatím nezapočten)")
	var entry_x := lem.x
	advance(sim, SimConst.DROWN_TICKS - 1)
	check(not lem.removed, "topení trvá DROWN_TICKS tiků")
	check(lem.x > entry_x and lem.x <= 89 and lem.x - entry_x <= SimConst.DROWN_TICKS / 2,
		"topící se lumík se plácá dál od břehu: %d → %d" % [entry_x, lem.x])
	sim.take_events()
	sim.tick()
	check(lem.removed and not lem.saved and sim.lost == 1, "utonulý lumík je ztracený právě jednou")
	check(_events_of(sim, "drowned").size() == 1, "konec topení ohlásí událost pro grafiku")
	advance(sim, 20)
	check(sim.lost == 1, "ztráta se nezapočítá znovu")
	# V úzké jámě se plácání zastaví u protějšího břehu.
	var narrow := fixture()
	narrow.mask.erase_rect(70, 80, 4, 20)
	paint_rect(narrow.mask, Rect2i(70, 84, 4, 16), TerrainMask.Kind.WATER)
	var paddler := add_lemming(narrow, 66, 80)
	while paddler.state != Lemming.State.DROWNING and narrow.tick_count < 60:
		narrow.tick()
	advance(narrow, SimConst.DROWN_TICKS - 1)
	check(paddler.x == 73 and not paddler.removed, "plácání nevleze do protějšího břehu")
	# Tenká hladina: pád až 3 px za tik ji nepřeskočí.
	var thin := fixture()
	thin.mask.erase_rect(70, 80, 20, 20)
	paint_rect(thin.mask, Rect2i(70, 92, 20, 1), TerrainMask.Kind.WATER)
	var faller := add_lemming(thin, 75, 40)
	thin.set_state(faller, Lemming.State.FALLER)
	while faller.state == Lemming.State.FALLER and thin.tick_count < 100:
		thin.tick()
	check(faller.state == Lemming.State.DROWNING, "padající lumík nepřeskočí jednořádkovou vodu")
	# Padák vodu nezachrání.
	var floaty := fixture()
	_pool(floaty, TerrainMask.Kind.WATER)
	var floater := add_lemming(floaty, 75, 20)
	floater.has_floater = true
	floaty.set_state(floater, Lemming.State.FALLER)
	advance(floaty, 200)
	check(floater.removed and floaty.lost == 1, "ani lumík s padákem ve vodě nepřežije")


func _test_lava() -> void:
	var sim := fixture()
	_pool(sim, TerrainMask.Kind.LAVA)
	var lem := add_lemming(sim, 66, 80)
	sim.take_events()
	while lem.state != Lemming.State.BURNING and sim.tick_count < 60:
		sim.tick()
	check(lem.state == Lemming.State.BURNING and _events_of(sim, "burn").size() == 1,
		"láva lumíka zapálí")
	advance(sim, SimConst.BURN_TICKS)
	check(lem.removed and sim.lost == 1, "uhořelý lumík je ztracený")
	# Láva má přednost před vodou ve stejném tiku.
	var both := fixture()
	both.mask.erase_rect(70, 80, 20, 20)
	paint_rect(both.mask, Rect2i(70, 90, 20, 1), TerrainMask.Kind.WATER)
	paint_rect(both.mask, Rect2i(70, 91, 20, 9), TerrainMask.Kind.LAVA)
	var faller := add_lemming(both, 75, 89)
	both.set_state(faller, Lemming.State.FALLER)
	both.tick()
	check(faller.y >= 91 and faller.state == Lemming.State.BURNING,
		"voda i láva v jednom tiku: rozhodne láva")


func _test_bridges() -> void:
	# Hladina až po okraj; stavitel ji přemostí cihlami a ostatní přejdou suchou nohou.
	var sim := fixture()
	_pool(sim, TerrainMask.Kind.WATER, 80)
	sim.mask.add_brick_row(69, 90, 80)
	check(sim.mask.is_solid(75, 80) and sim.mask.special_at(75, 80) == TerrainMask.Special.WATER
		and sim.mask.hazard_at(75, 80) == TerrainMask.Special.NONE,
		"cihla ve vodě je suchá stavba (značka vody zůstane pod ní)")
	var lem := add_lemming(sim, 64, 80)
	advance(sim, 60)
	check(not lem.removed and lem.x > 90 and lem.state == Lemming.State.WALKER,
		"lumík přejde po cihlách nad vodou")
	sim.mask.erase_rect(70, 80, 20, 1)
	check(sim.mask.hazard_at(75, 80) == TerrainMask.Special.WATER, "vykopaná cihla vodu zase odkryje")
	var lava := fixture()
	_pool(lava, TerrainMask.Kind.LAVA, 80)
	lava.mask.add_brick_row(69, 90, 80)
	var walker := add_lemming(lava, 64, 80)
	advance(lava, 60)
	check(not walker.removed and walker.x > 90, "most z cihel vede i přes lávu")


func _trap_sim(rearm: int) -> LevelSim:
	var sim := fixture()
	sim.spec.traps.append({"at": Vector2i(80, 80), "rect": Rect2i(75, 70, 10, 10), "rearm": rearm})
	return LevelSim.new(sim.spec, sim.mask)


func _test_traps() -> void:
	var sim := _trap_sim(40)
	check(sim.trap_ready.size() == 1 and sim.trap_ready[0] == 0 and sim.trap_fired[0] == -1,
		"past je na začátku připravená")
	var first := add_lemming(sim, 70, 80)
	var second := add_lemming(sim, 66, 80)
	var third := add_lemming(sim, 30, 80)
	sim.take_events()
	while not first.removed and sim.tick_count < 40:
		sim.tick()
	var events := _events_of(sim, "trap")
	check(first.removed and not first.saved and sim.lost == 1 and first.x == 75
		and events.size() == 1 and events[0]["value"] == 0 and events[0]["id"] == first.id,
		"past sežere prvního lumíka hned na okraji spouště")
	var fired := sim.trap_fired[0]
	check(fired == sim.tick_count and sim.trap_ready[0] == fired + 40, "past si pamatuje čas a dobití")
	while second.x < 90 and sim.tick_count < 80:
		sim.tick()
	check(not second.removed and second.x >= 90 and sim.tick_count < fired + 40,
		"během dobíjení projde další lumík bez úhony")
	while not third.removed and sim.tick_count < 200:
		sim.tick()
	check(third.removed and sim.trap_fired[0] >= fired + 40 and sim.lost == 2,
		"po dobití past sežere dalšího")
	# Dva lumíci ve spoušti ve stejném tiku: rozhoduje pořadí vypuštění.
	var pair := _trap_sim(40)
	var a := add_lemming(pair, 74, 80)
	var b := add_lemming(pair, 74, 80)
	pair.tick()
	check(a.removed and not b.removed and pair.lost == 1,
		"ze dvou lumíků naráz sežere past toho, kdo vyšel dřív")
	# Spoušť hlídá nohy: padající lumík nad spouští ještě není chycen.
	var above := _trap_sim(40)
	var high := add_lemming(above, 80, 40)
	above.set_state(high, Lemming.State.FALLER)
	above.tick()
	check(not high.removed, "lumík nad spouští zatím není chycen")
	while not high.removed and above.tick_count < 40:
		above.tick()
	check(high.removed, "po dopadu do spouště ho past sežere")


func _test_one_way() -> void:
	for wall_kind in [TerrainMask.Kind.ONE_WAY_RIGHT, TerrainMask.Kind.ONE_WAY_LEFT]:
		for direction in [1, -1]:
			var sim := fixture()
			paint_rect(sim.mask, Rect2i(70, 60, 20, 20), wall_kind)
			var start := 64 if direction > 0 else 95
			var lem := add_lemming(sim, start, 80)
			lem.dir = direction
			advance(sim, 2)
			sim.take_events()
			sim.assign_skill(lem, Lemming.Skill.BASHER)
			advance(sim, 160)
			var with_arrows: bool = (wall_kind == TerrainMask.Kind.ONE_WAY_RIGHT) == (direction > 0)
			var through: bool = (lem.x > 90) if direction > 0 else (lem.x < 70)
			check(through == with_arrows,
				"razič a jednosměrná zeď %s, směr %d: %s" % [
					"→" if wall_kind == TerrainMask.Kind.ONE_WAY_RIGHT else "←", direction,
					"prorazí" if with_arrows else "otočí se"])
	var mine := fixture()
	paint_rect(mine.mask, Rect2i(70, 40, 30, 40), TerrainMask.Kind.ONE_WAY_LEFT)
	var miner := add_lemming(mine, 64, 80)
	advance(mine, 2)
	mine.assign_skill(miner, Lemming.Skill.MINER)
	advance(mine, 30)
	check(miner.dir == -1 and miner.state == Lemming.State.WALKER and miner.x <= 70,
		"horník se o zeď se šipkami proti sobě otočí")
	var dig := fixture()
	paint_rect(dig.mask, Rect2i(50, 80, 30, 20), TerrainMask.Kind.ONE_WAY_LEFT)
	var digger := add_lemming(dig, 60, 80)
	dig.assign_skill(digger, Lemming.Skill.DIGGER)
	advance(dig, 60)
	check(digger.y > 90, "kopáč jde jednosměrnou zdí dolů bez omezení")
	var mask := TerrainMask.new(20, 20)
	paint_rect(mask, Rect2i(0, 0, 20, 20), TerrainMask.Kind.ONE_WAY_RIGHT)
	check(mask.has_one_way_against(5, 5, 2, 2, -1) and not mask.has_one_way_against(5, 5, 2, 2, 1),
		"zeď se šipkami doprava brání jen ražení doleva")
	mask.erase_rect(5, 5, 2, 2)
	check(not mask.has_one_way_against(5, 5, 2, 2, -1), "vykopané místo už nebrání")
	mask.add_brick_row(5, 6, 5)
	check(mask.is_solid(5, 5) and not mask.has_one_way_against(5, 5, 2, 1, -1),
		"cihla ve vykopané jednosměrné zdi je obyčejná stavba")
	paint_rect(mask, Rect2i(0, 0, 20, 20), TerrainMask.Kind.DIRT)
	check(mask.special_at(3, 3) == TerrainMask.Special.NONE, "přemalování hlínou značku smaže")


func _test_dying_rules() -> void:
	var sim := fixture()
	for state in [Lemming.State.DROWNING, Lemming.State.BURNING]:
		var lem := add_lemming(sim)
		sim.set_state(lem, state)
		var accepted := false
		for skill in Lemming.SKILL_ORDER:
			accepted = sim.can_assign(lem, skill) or accepted
		check(not accepted, "topící se ani hořící lumík nepřijme dovednost: %d" % state)
	var bomb := fixture()
	_pool(bomb, TerrainMask.Kind.WATER)
	var lem := add_lemming(bomb, 66, 80)
	bomb.assign_skill(lem, Lemming.Skill.BOMBER)
	while lem.state != Lemming.State.DROWNING and bomb.tick_count < 60:
		bomb.tick()
	var data := bomb.mask.data.duplicate()
	advance(bomb, 120)
	check(lem.bomb_ticks == -1 and bomb.mask.data == data,
		"voda zhasne odpočet bomby; utonulý lumík nevybuchne")
	# Nebezpečí přednostně před východem ve stejném tiku.
	var exit := fixture()
	exit.spec.exits.append(Vector2i(75, 84))
	_pool(exit, TerrainMask.Kind.WATER)
	var walker := add_lemming(exit, 72, 84)
	exit.tick()
	check(walker.state == Lemming.State.DROWNING and exit.saved == 0,
		"voda a východ v jednom tiku: nejdřív se kontroluje voda")
	var nuke := fixture()
	_pool(nuke, TerrainMask.Kind.WATER)
	var swimmer := add_lemming(nuke, 66, 80)
	while swimmer.state != Lemming.State.DROWNING and nuke.tick_count < 60:
		nuke.tick()
	nuke.start_nuke()
	nuke.tick()
	check(swimmer.bomb_ticks == -1, "hromadné odpálení topícího se lumíka přeskočí")


func _test_loader_and_validator() -> void:
	var level := LevelDefinition.new()
	level.size = Vector2i(200, 100)
	level.lemming_count = 5
	level.save_required = 6
	var ground := TerrainShape.new()
	ground.polygon = PackedVector2Array([Vector2(0, 60), Vector2(200, 60), Vector2(200, 100),
		Vector2(0, 100)])
	level.add_child(ground)
	var water := TerrainShape.new()
	water.kind = TerrainMask.Kind.WATER
	water.polygon = PackedVector2Array([Vector2(150, 60), Vector2(190, 60), Vector2(190, 80),
		Vector2(150, 80)])
	level.add_child(water)
	var trap := LemmingTrap.new()
	trap.position = Vector2(100, 60)
	trap.rearm_ticks = 25
	level.add_child(trap)
	var floating := LemmingTrap.new()
	floating.position = Vector2(60, 30)
	level.add_child(floating)
	var exit := LemmingExit.new()
	exit.position = Vector2(170, 60)
	level.add_child(exit)
	var spec := LevelLoader.build_spec(level)
	var mask := LevelLoader.build_mask(level)
	check(spec.traps.size() == 2 and spec.traps[0]["rect"] == Rect2i(95, 50, 10, 10)
		and spec.traps[0]["rearm"] == 25 and spec.traps[0]["at"] == Vector2i(100, 60),
		"načítání levelu převezme past se spouští nad bodem")
	check(mask.hazard_at(160, 70) == TerrainMask.Special.WATER and not mask.is_solid(160, 70),
		"tvar Water vyřízne zem a vyplní vodu")
	var problems := LevelValidator.problems(spec, mask)
	var text := "\n".join(problems)
	check(text.contains("Chybí líheň") and text.contains("vyšší než počet")
		and text.contains("Past na (60, 30) visí") and text.contains("ve vodě nebo v lávě")
		and not text.contains("Past na (100, 60)"),
		"kontrola levelu najde chybějící líheň, požadavek, past ve vzduchu a východ ve vodě")
	check(level._get_configuration_warnings() == problems,
		"editor ukáže stejná varování u kořene levelu")
	level.free()
	var dir := DirAccess.open("res://levels")
	var names := Array(dir.get_files()).filter(func(n: String) -> bool: return n.ends_with(".tscn"))
	names.sort()
	var clean := true
	for name: String in names:
		var scene := (load("res://levels/" + name) as PackedScene).instantiate() as LevelDefinition
		var found := LevelValidator.problems_for(scene)
		if not found.is_empty():
			clean = false
			print("  %s: %s" % [name, "; ".join(found)])
		scene.free()
	check(clean and names.size() >= 5,
		"všechny levely (%d) projdou kontrolou bez nálezu" % names.size())


## Mise 6: lezec přeleze jednosměrnou zeď a postaví most přes vodu, kopáč
## obejde lávu chodbou dolů, razič pustí ostatní ve směru šipek; past sežere
## několik lumíků. Výsledek se musí shodovat s replayem.
func _test_mission_six() -> void:
	var sim := _mission_six()
	var done := {}
	var deaths := {}
	while not sim.finished and sim.tick_count < 6000:
		sim.tick()
		for e in sim.take_events():
			if e["type"] in ["drown", "burn", "trap", "splat", "fell_out"]:
				deaths[e["type"]] = int(deaths.get(e["type"], 0)) + 1
		if sim.lemmings.is_empty():
			continue
		var hero := sim.lemmings[0]
		var ready := hero.state == Lemming.State.WALKER and hero.dir == 1 and not hero.removed
		if not done.has("climb"):
			_order(sim, hero, Lemming.Skill.CLIMBER, "climb", done)
		elif not done.has("build") and ready and hero.x >= 224 and hero.y == 100:
			_order(sim, hero, Lemming.Skill.BUILDER, "build", done)
		elif done.has("build") and not done.has("dig") and ready and hero.x >= 350 and hero.y == 100:
			_order(sim, hero, Lemming.Skill.DIGGER, "dig", done)
		if not done.has("bash") and sim.tick_count >= 400:
			for lem in sim.lemmings:
				if lem.id != 0 and not lem.removed and lem.state == Lemming.State.WALKER \
						and lem.dir == 1 and lem.x >= 134 and lem.x < 140:
					_order(sim, lem, Lemming.Skill.BASHER, "bash", done)
					break
	check(sim.finished and sim.is_won() and done.size() == 4 and deaths.keys() == ["trap"],
		"mise 6 čistou simulací: zachráněno %d z %d, ztráty %s" % [
			sim.saved, sim.spec.lemming_count, str(deaths)])
	var fresh := _mission_six()
	var replay := SimReplay.new(fresh, sim.replay_log)
	while replay.step():
		pass
	check(replay.error.is_empty() and snapshot(fresh) == snapshot(sim),
		"mise 6: replay je totožný včetně pastí, vody a masky")
	# Bez mostu se první lumík utopí, bez kopání shoří v lávě.
	var lazy := _mission_six()
	var hero_fate := ""
	while lazy.tick_count < 1500 and hero_fate.is_empty():
		lazy.tick()
		if not lazy.lemmings.is_empty() and not lazy.lemmings[0].can_climb:
			lazy.assign_skill(lazy.lemmings[0], Lemming.Skill.CLIMBER)
		for e in lazy.take_events():
			if e["id"] == 0 and e["type"] in ["drown", "burn"]:
				hero_fate = e["type"]
	check(hero_fate == "drown", "mise 6 bez mostu: lezec se utopí v jezírku")


func _mission_six() -> LevelSim:
	var level := (load("res://levels/level_hazards.tscn") as PackedScene).instantiate()
	var sim := LevelSim.new(LevelLoader.build_spec(level), LevelLoader.build_mask(level))
	level.free()
	return sim


func _order(sim: LevelSim, lem: Lemming, skill: int, name: String, done: Dictionary) -> void:
	if sim.apply_command(LevelSim.Command.ASSIGN_SKILL, lem.id, skill):
		done[name] = sim.tick_count
