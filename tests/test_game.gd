extends SimTest
## Integrace skutečné scény a HUD. Běží i bez grafického serveru.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://main/game.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	var sim: LevelSim = game.get("_sim")
	var hud: Hud = game.get_node("Hud")
	check(sim != null and not hud.visible_skills().is_empty(), "hlavní scéna načte level a HUD")
	for _frame in 360:
		await process_frame
	check(sim.tick_count >= 90 and sim.spawned > 0, "skutečná herní smyčka vypouští lumíky")
	hud.pause_pressed.emit()
	var paused_tick := sim.tick_count
	hud.release_rate_step.emit(1)
	var lem := sim.lemmings[0]
	check(sim.assign_skill(lem, Lemming.Skill.BUILDER), "přidělení dovednosti během pauzy")
	for _frame in 60:
		await process_frame
	check(sim.tick_count == paused_tick and sim.release_rate == sim.spec.release_rate + 1
		and lem.state_ticks == 0 and sim.replay_log.size() == 2,
		"pauza zastaví čas, HUD i dovednost se zaznamenají ve stejném tiku")
	hud.pause_pressed.emit()
	for _frame in 60:
		await process_frame
	var normal_ticks := sim.tick_count - paused_tick
	hud.speed_pressed.emit()
	var fast_start := sim.tick_count
	for _frame in 60:
		await process_frame
	check(absi(sim.tick_count - fast_start - 3 * normal_ticks) <= 3,
		"zrychlení HUD přibližně ztrojnásobí počet pevných tiků")
	hud.restart_pressed.emit()
	var restarted: LevelSim = game.get("_sim")
	check(restarted != sim and restarted.tick_count == 0 and restarted.replay_log.is_empty()
		and restarted.release_rate == restarted.spec.release_rate, "restart obnoví level a vymaže záznam")
	game.queue_free()
	await process_frame
	_test_render_cadences(scene)
	finish()


func _test_render_cadences(scene: PackedScene) -> void:
	var reference: Array = []
	for cadence in [[1.0 / 30], [1.0 / 144], [0.008, 0.041, 0.3, 0.016]]:
		var game := scene.instantiate()
		root.add_child(game)
		game.set_process(false)
		var sim: LevelSim = game.get("_sim")
		sim.spec.time_limit_seconds = 10
		var frame := 0
		while not sim.finished and frame < 5000:
			game.call("_process", cadence[frame % cadence.size()])
			frame += 1
		if reference.is_empty():
			reference = snapshot(sim)
		check(sim.finished and sim.tick_count == 170 and snapshot(sim) == reference,
			"skutečný _process zachová výsledek při tempu %s" % str(cadence))
		game.free()
