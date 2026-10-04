extends SimTest
## Pomocníci ve skutečné aplikaci: rychlost 1× → 3× → ½×, krok o jeden tik
## v pauze a ukázka řešení (přehraje uložený záznam mise, nezapisuje postup,
## u pozdější výhry se jen označí).

const DIR := "user://test_helpers"

var _app: App


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	_app = (load("res://main/app.tscn") as PackedScene).instantiate() as App
	_app.settings_path = DIR.path_join("settings.json")
	_app.progress_path = DIR.path_join("progress.json")
	root.add_child(_app)
	await _frames(3)
	_app.start_mission(Campaign.index_of("dira-v-louce"))
	await _frames(3)
	var game := _app.game
	game.set_process(false)
	(game.get_node("PaperWorld") as PaperWorld).camera.input_enabled = false
	var hud: Hud = game.get_node("Hud")
	hud.briefing.close()
	_test_speed(game, hud)
	_test_step(game, hud)
	_test_demo(game, hud)
	_app.free()
	await _frames(2)
	_clean()
	GameSettings.new().apply_audio()
	finish()


func _clean() -> void:
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(name))


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


## Hra běží ručně: jeden snímek = 1/17 s skutečného času.
func _step(game: Node, frames: int) -> void:
	for _i in frames:
		game.call("_process", 1.0 / SimConst.TICKS_PER_SECOND)


func _test_speed(game: Node, hud: Hud) -> void:
	var speeds: Array[float] = []
	for _i in 3:
		hud.speed_pressed.emit()
		speeds.append(float(game.get("_speed")))
	check(speeds == [3.0, 0.5, 1.0], "rychlost se přepíná 1× → 3× → ½× → 1×")
	hud.speed_pressed.emit()
	hud.speed_pressed.emit()
	var sim: LevelSim = game.get("_sim")
	var start := sim.tick_count
	_step(game, 40)
	check(absi(sim.tick_count - start - 20) <= 1 and hud.get("_speed_button").text == "½×",
		"zpomalení ½× provede za stejný čas polovinu tiků a tlačítko ukazuje ½×")
	hud.speed_pressed.emit()


func _test_step(game: Node, hud: Hud) -> void:
	var sim: LevelSim = game.get("_sim")
	var running := sim.tick_count
	hud.step_pressed.emit()
	_step(game, 1)
	check(sim.tick_count - running <= 2 and not (hud.get("_step_button") as Button).visible,
		"krok o tik mimo pauzu nic nedělá a tlačítko Krok je skryté")
	hud.pause_pressed.emit()
	_step(game, 1)
	var paused := sim.tick_count
	hud.step_pressed.emit()
	hud.step_pressed.emit()
	_step(game, 20)
	check(sim.tick_count == paused + 2 and (hud.get("_step_button") as Button).visible,
		"v pauze posune každé stisknutí Krok hru přesně o jeden tik, jinak čas stojí")
	hud.pause_pressed.emit()


func _test_demo(game: Node, hud: Hud) -> void:
	var progress: Progress = game.get("progress")
	var plays_before := int(progress.entry("dira-v-louce").get("plays", 0))
	check((hud.get("_demo_button") as Button).visible,
		"pauzovací menu nabízí Ukázku řešení (mise má uložený záznam)")
	game.call("_on_menu_action", "demo")
	var sim: LevelSim = game.get("_sim")
	var title: Label = hud.get("_title")
	check(game.get("_demo") and sim.tick_count == 0 and title.text.begins_with("Ukázka")
		and not (hud.get("_demo_button") as Button).visible,
		"ukázka spustí misi od začátku s označeným názvem")
	game.call("_change_release_rate", 5)
	check(sim.release_rate == sim.spec.release_rate, "během ukázky hráč nemění vypouštění")
	var focus := -1
	for _t in 200 * SimConst.TICKS_PER_SECOND:
		_step(game, 1)
		if not sim.replay_log.is_empty() and focus < 0:
			focus = int(game.get("_demo_focus"))
		if sim.finished:
			_step(game, 1)
			break
	var result_title: Label = hud.get("_result_title")
	check(sim.finished and sim.saved == 10 and focus == sim.replay_log[0]["target"]
		and hud.result_open() and result_title.text == "Konec ukázky",
		"ukázka sama zachrání mistrovských 10/10, zvýrazní lumíka a skončí oknem Konec ukázky")
	check(not progress.is_completed("dira-v-louce") and not progress.has_suspended()
		and int(progress.entry("dira-v-louce").get("plays", 0)) == plays_before,
		"ukázka se nezapíše do postupu (ani pokus, ani výhra, ani rozehraná hra)")
	hud.restart_pressed.emit()
	sim = game.get("_sim")
	check(not game.get("_demo") and not title.text.begins_with("Ukázka"),
		"Hrát sám spustí misi znovu normálně")
	var plan := ReferencePlans.plan_for("dira-v-louce")
	var state := {}
	for _t in 200 * SimConst.TICKS_PER_SECOND:
		var before := sim.tick_count
		_step(game, 1)
		if sim.tick_count != before:
			plan.call(sim, state)
		if sim.finished:
			_step(game, 1)
			break
	var note: Label = hud.get("_result_note")
	check(progress.is_completed("dira-v-louce") and progress.stars(0) == 3
		and note.text.contains("Po ukázce řešení"),
		"výhra po ukázce platí (3 hvězdy) a výsledek jen připomene, že hráč viděl ukázku")
