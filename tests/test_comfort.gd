extends SimTest
## Etapa 10 – pohodlí: proč dovednost nejde dát (SkillRules a hláška),
## štítek nad lumíkem s davem, náhled cíle, dokud prst drží na ploše,
## a minimapa (přehled, rámeček záběru, přesun pohledu, vypnutí).

const GAME_SCENE := preload("res://main/game_origami.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_reasons()
	_test_same_rules()
	_test_texts()
	await _test_game()
	await _test_minimap()
	finish()


func _test_reasons() -> void:
	var sim := fixture(10)
	var walker := add_lemming(sim, 60, 80)
	var digger := add_lemming(sim, 70, 80)
	sim.assign_skill(digger, Lemming.Skill.DIGGER)
	var climber := add_lemming(sim, 80, 80)
	sim.assign_skill(climber, Lemming.Skill.CLIMBER)
	var blocker := add_lemming(sim, 30, 80)
	sim.assign_skill(blocker, Lemming.Skill.BLOCKER)
	var faller := add_lemming(sim, 100, 40)
	sim.set_state(faller, Lemming.State.FALLER)
	var home := add_lemming(sim, 110, 80)
	sim.set_state(home, Lemming.State.EXITING)
	var r := SkillRules.Refusal
	check(SkillRules.refusal(sim, walker, Lemming.Skill.DIGGER) == r.NONE
		and SkillRules.refusal(sim, digger, Lemming.Skill.DIGGER) == r.SAME_WORK
		and SkillRules.refusal(sim, digger, Lemming.Skill.BUILDER) == r.NONE
		and SkillRules.refusal(sim, climber, Lemming.Skill.CLIMBER) == r.ALREADY
		and SkillRules.refusal(sim, blocker, Lemming.Skill.BUILDER) == r.NOT_WORKING
		and SkillRules.refusal(sim, blocker, Lemming.Skill.BOMBER) == r.NONE
		and SkillRules.refusal(sim, faller, Lemming.Skill.DIGGER) == r.NOT_WORKING
		and SkillRules.refusal(sim, faller, Lemming.Skill.FLOATER) == r.NONE
		and SkillRules.refusal(sim, home, Lemming.Skill.FLOATER) == r.DYING,
		"důvody: už to dělá, už to umí, blokař a padající jen trvalé, doma nic")
	sim.assign_skill(walker, Lemming.Skill.BOMBER)
	sim.skills[Lemming.Skill.MINER] = 0
	var gone := Lemming.new()
	gone.id = 99
	check(SkillRules.refusal(sim, walker, Lemming.Skill.BOMBER) == r.ALREADY
		and SkillRules.refusal(sim, digger, Lemming.Skill.MINER) == r.NO_SKILL
		and SkillRules.refusal(sim, gone, Lemming.Skill.DIGGER) == r.GONE,
		"důvody: bombu už má, došly kusy, neznámý lumík")
	sim.finished = true
	check(SkillRules.refusal(sim, digger, Lemming.Skill.BUILDER) == r.FINISHED
		and not sim.can_assign(digger, Lemming.Skill.BUILDER), "po konci mise nejde nic")
	var crowd := fixture(10)
	for _i in 3:
		add_lemming(crowd, 50, 80)
	add_lemming(crowd, 90, 80)
	check(SkillRules.crowd_at(crowd, Vector2(50.5, 75)) == 3
		and SkillRules.crowd_at(crowd, Vector2(90.5, 75)) == 1
		and SkillRules.crowd_at(crowd, Vector2(70.5, 75)) == 0, "dav v bodě: počet lumíků pod kurzorem")


## Původní pravidlo přidělování (před SkillRules) pro porovnání.
func _old_can_assign(sim: LevelSim, lem: Lemming, skill: int) -> bool:
	if lem == null or lem.removed or sim.finished:
		return false
	if (lem.id < 0 or lem.id >= sim.lemmings.size() or sim.lemmings[lem.id] != lem
			or int(sim.skills.get(skill, 0)) <= 0
			or lem.state in LevelSim.DYING_STATES):
		return false
	match skill:
		Lemming.Skill.CLIMBER:
			return not lem.can_climb
		Lemming.Skill.FLOATER:
			return not lem.has_floater
		Lemming.Skill.BOMBER:
			return lem.bomb_ticks < 0
	var target := SkillRules.state_for_skill(skill)
	return target >= 0 and lem.state in Lemming.WORKING_STATES and lem.state != target


## Stejný výsledek jako dřív ve všech stavech celé hry (finále podle plánu).
func _test_same_rules() -> void:
	var level := Campaign.SCENES[Campaign.index_of("origami-finale")].instantiate() as LevelDefinition
	var sim := LevelSim.new(LevelLoader.build_spec(level), LevelLoader.build_mask(level))
	level.free()
	var plan := ReferencePlans.plan_for("origami-finale")
	var state := {}
	var compared := 0
	var mismatches := 0
	var states := {}
	while not sim.finished and sim.tick_count < 4000:
		sim.tick()
		plan.call(sim, state)
		if sim.tick_count % 25 != 0:
			continue
		for lem in sim.lemmings:
			states[lem.state] = true
			for skill: int in Lemming.SKILL_ORDER:
				compared += 1
				if sim.can_assign(lem, skill) != _old_can_assign(sim, lem, skill):
					mismatches += 1
	check(mismatches == 0 and compared > 20000 and states.size() >= 8,
		"pravidla přidělování se nezměnila (%d porovnání v %d stavech)" % [compared, states.size()])


func _test_texts() -> void:
	var sim := fixture(5)
	var blocker := add_lemming(sim, 30, 80)
	sim.assign_skill(blocker, Lemming.Skill.BLOCKER)
	var digger := add_lemming(sim, 60, 80)
	sim.assign_skill(digger, Lemming.Skill.DIGGER)
	var r := SkillRules.Refusal
	check(PlayInfo.refusal_text(r.NOT_WORKING, Lemming.Skill.DIGGER, blocker).begins_with("Blokař")
		and PlayInfo.refusal_text(r.SAME_WORK, Lemming.Skill.DIGGER, digger) == "Tenhle lumík už kope."
		and PlayInfo.refusal_text(r.NO_SKILL, Lemming.Skill.DIGGER, null) == "Kopáč: už nezbývá žádný."
		and PlayInfo.refusal_text(r.ALREADY, Lemming.Skill.FLOATER, digger).contains("padák")
		and PlayInfo.refusal_text(r.NONE, Lemming.Skill.DIGGER, digger).is_empty(),
		"hlášky česky a konkrétně (blokař, už kope, došly kusy, padák)")


func _test_game() -> void:
	var game := GAME_SCENE.instantiate() as Node
	root.add_child(game)
	game.set_process(false)
	var world: PaperWorld = game.get_node("PaperWorld")
	var hud: Hud = game.get_node("Hud")
	world.camera.input_enabled = false
	var sim: LevelSim = game.get("_sim")
	var lem := add_lemming(sim, 300, 70)
	game.set("_paused", true)
	game.call("_select_skill", Lemming.Skill.DIGGER)
	world.camera.zoom_factor = 2
	world.camera.focus = Vector2(300, 90)
	world.camera.refresh()
	var point := world.camera.logic_to_screen(Vector2(lem.x + 0.5, lem.y - 5))
	var title: Label = hud.info.get("_tag_title")
	root.push_input(_touch(0, point, true), true)
	game.call("_process", 0.0)
	check(game.get("_touch_preview") == point and world.actors.hovered == lem
		and hud.info.target_visible() and title.text.begins_with("Chodec")
		and sim.replay_log.is_empty(),
		"držený prst zvýrazní lumíka a štítek ukáže, co dělá – zatím nic nepřidělí")
	root.push_input(_touch(0, point, false), true)
	game.call("_process", 0.0)
	check(lem.state == Lemming.State.DIGGER and sim.replay_log.size() == 1
		and game.get("_touch_preview") == Vector2.INF, "uvolnění přidělí dovednost a náhled skončí")
	root.push_input(_touch(0, point, true), true)
	root.push_input(_touch(0, point, false), true)
	check(sim.replay_log.size() == 1 and hud.info.notice_text() == "Tenhle lumík už kope.",
		"klepnutí na kopáče s kopáčem nic nepřidělí a hláška řekne proč")
	for _i in 2:
		add_lemming(sim, 300, 70)
	root.push_input(_touch(0, point, true), true)
	game.call("_process", 0.0)
	check(title.text.contains("3 v davu"), "štítek spočítá lumíky v davu pod prstem")
	root.push_input(_drag(0, point + Vector2(60, 0)), true)
	root.push_input(_touch(0, point + Vector2(60, 0), false), true)
	game.call("_process", 0.0)
	check(game.get("_touch_preview") == Vector2.INF and sim.replay_log.size() == 1,
		"posun prstem náhled zruší a nic nepřidělí")
	sim.skills[Lemming.Skill.MINER] = 0
	hud.skill_unavailable.emit(Lemming.Skill.MINER)
	check(hud.info.notice_text() == "Horník: už nezbývá žádný.",
		"klepnutí na prázdnou dovednost řekne, že došla")
	hud.info.call("_process", 3.0)
	check(hud.info.notice_text().is_empty(), "hláška po chvíli zmizí")
	game.free()
	await process_frame


func _test_minimap() -> void:
	var game := GAME_SCENE.instantiate() as Node
	root.add_child(game)
	game.set_process(false)
	var world: PaperWorld = game.get_node("PaperWorld")
	var hud: Hud = game.get_node("Hud")
	world.camera.input_enabled = false
	game.call("_choose_mission", Campaign.index_of("origami-finale"))
	game.call("_process", 0.0)
	var minimap := hud.minimap
	var sim: LevelSim = game.get("_sim")
	var map := minimap.map_size()
	check(minimap.visible and minimap.sim == sim and map.x <= Minimap.MAX_SIZE.x + 0.5
		and map.y <= Minimap.MAX_SIZE.y + 0.5 and minimap.view_rect.size.x > 0.0
		and minimap.view_rect.size.x < sim.spec.width,
		"minimapa ukáže celou misi zmenšeně a rámeček záběru kamery")
	var target := Vector2(800, 150)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(Minimap.MARGIN, Minimap.MARGIN) + target / sim.spec.width * map.x
	minimap.call("_gui_input", click)
	check(absf(world.camera.focus.x - target.x) < 12.0, "klepnutí na minimapu přesune pohled")
	var version := sim.mask.version
	sim.mask.erase_rect(400, 176, 30, 20)
	minimap.call("_process", 0.3)
	check(sim.mask.version != version and minimap.get("_version") == sim.mask.version,
		"po změně terénu se obraz minimapy obnoví")
	var center := minimap.get_global_rect().get_center()
	root.push_input(_touch(0, center, true), true)
	check(game.get("_touch_preview") == Vector2.INF,
		"dotyk začatý na minimapě nepatří herní ploše (žádný náhled ani přidělení)")
	root.push_input(_touch(0, center, false), true)
	var settings: GameSettings = game.get("settings")
	settings.set_value("minimap", false)
	game.call("_process", 0.0)
	check(not minimap.visible, "minimapa jde vypnout v nastavení")
	settings.set_value("minimap", true)
	game.free()
	await process_frame


func _touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event


func _drag(index: int, position: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	return event
