extends SimTest
## Skutečné ukázkové levely, lišta telefonu a potvrzování hromadného ukončení.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for mission in ["climb_float", "miner", "bomber"]:
		_solve(mission)
	await _test_interface()
	finish()


func _solve(mission: String) -> void:
	var level := load("res://levels/level_%s.tscn" % mission).instantiate() as LevelDefinition
	var sim := LevelSim.new(LevelLoader.build_spec(level), LevelLoader.build_mask(level))
	level.free()
	var assigned := false
	while not sim.finished and sim.tick_count < 3000:
		sim.tick()
		for lem in sim.lemmings:
			if lem.removed:
				continue
			match mission:
				"climb_float":
					if not lem.can_climb:
						sim.assign_skill(lem, Lemming.Skill.CLIMBER)
						sim.assign_skill(lem, Lemming.Skill.FLOATER)
				"miner":
					if not assigned and lem.state == Lemming.State.WALKER and lem.x == 80:
						assigned = sim.assign_skill(lem, Lemming.Skill.MINER)
				"bomber":
					if not assigned and lem.state == Lemming.State.WALKER and lem.x == 168:
						sim.assign_skill(lem, Lemming.Skill.BLOCKER)
						assigned = sim.assign_skill(lem, Lemming.Skill.BOMBER)
	check(sim.finished and sim.is_won() and sim.saved == sim.spec.save_required,
		"ukázka %s je řešitelná: %d/%d za %d tiků" % [
			mission, sim.saved, sim.spec.lemming_count, sim.tick_count])


func _test_interface() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var game := load("res://main/game_origami.tscn").instantiate() as Node
	root.add_child(game)
	game.set_process(false)
	var hud: Hud = game.get_node("Hud")
	game.call("_choose_mission", 4)
	for _frame in 3:
		await process_frame
	var sim: LevelSim = game.get("_sim")
	check(hud.visible_skills().size() == 8, "hřiště zpřístupní všech osm dovedností")
	var title: Label = hud.get("_title")
	check(title.text == Campaign.mission(4)["title"], "lišta ukazuje název právě načtené mise")
	var widgets: Dictionary = hud.get("_skill_widgets")
	var fits := true
	var right := 0.0
	for skill in hud.visible_skills():
		var button: Button = widgets[skill].button
		var rect := button.get_global_rect()
		fits = fits and rect.position.x >= right and rect.end.x <= 1280 \
			and rect.position.y >= 720 - Hud.BOTTOM_BAR_HEIGHT and rect.end.y <= 720
		right = rect.end.x
	check(fits, "osm tlačítek se vejde bez překrytí do mobilní lišty 1280 × 720")
	var lem := add_lemming(sim, 90, 70)
	game.call("_select_skill", Lemming.Skill.BOMBER)
	var world: PaperWorld = game.get_node("PaperWorld")
	world.camera.input_enabled = false
	var point := world.camera.logic_to_screen(Vector2(90.5, 65))
	hud.nuke_requested.emit()
	game.call("_process", 1.0)
	game.call("_try_assign_touch", point)
	check(game.get("_paused") and hud.confirmation_open() and sim.tick_count == 0
		and sim.replay_log.is_empty(), "potvrzovací okno zastaví čas a zabrání přidělení dotykem")
	hud.nuke_decided.emit(false)
	check(not game.get("_paused") and not sim.nuking and sim.replay_log.is_empty(),
		"zrušení dialogu obnoví běh bez příkazu")
	game.set("_paused", true)
	hud.nuke_requested.emit()
	hud.nuke_decided.emit(true)
	check(game.get("_paused") and sim.nuking and sim.replay_log.size() == 1,
		"potvrzení zachová původní pauzu a zapíše jediný společný příkaz")
	game.set("_paused", false)
	game.call("_process", 1.0 / SimConst.TICKS_PER_SECOND)
	check(lem.bomb_ticks > 0 and lem.bomb_ticks < SimConst.BOMB_TICKS,
		"odpočet bomby běží ve skutečné origami scéně")
	game.set("_paused", true)
	var remaining := lem.bomb_ticks
	game.call("_process", 1.0)
	check(remaining == lem.bomb_ticks, "pauza zastaví odpočet bomby")
	sim.set_state(lem, Lemming.State.FLOATER)
	game.call("_process", 0.0)
	check(lem.state == Lemming.State.FLOATER and lem.bomb_ticks == remaining,
		"změna stavu na padák zachová odpočet")
	hud.restart_pressed.emit()
	var restarted: LevelSim = game.get("_sim")
	check(restarted != sim and not restarted.nuking and restarted.replay_log.is_empty()
		and hud.visible_skills().size() == 8,
		"restart obnoví právě vybranou misi včetně vlastností, odpočtů a aktérů")
	game.call("_choose_mission", 1)
	check(hud.visible_skills() == [Lemming.Skill.CLIMBER, Lemming.Skill.FLOATER],
		"přechod do další mise odstraní staré dovednosti a zásoby")
	game.free()
	await process_frame
