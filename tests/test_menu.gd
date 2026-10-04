extends SimTest
## Menu a ukládání ve skutečné aplikaci: první spuštění, výhra mise, další
## mise, pauzovací menu, odchod s rozehraným pokusem, uvolnění hry při
## přechodech, „další den“ s obnovou, uplatnění nastavení a tlačítko Zpět.

const DIR := "user://test_menu"

var _app: App


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	await _test_first_day()
	await _test_next_day()
	await _test_leaks()
	await _test_settings_in_game()
	await _test_back_and_background()
	_clean()
	GameSettings.new().apply_audio()
	finish()


func _clean() -> void:
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(name))


func _open_app() -> void:
	_app = (load("res://main/app.tscn") as PackedScene).instantiate() as App
	_app.settings_path = DIR.path_join("settings.json")
	_app.progress_path = DIR.path_join("progress.json")
	root.add_child(_app)
	await _frames(3)


func _close_app() -> void:
	_app.free()
	_app = null
	await _frames(2)


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


## Rozehraná hra běží ručně (pevné kroky), ne podle času testu.
func _game() -> Node:
	var game := _app.game
	if game != null and game.is_processing():
		game.set_process(false)
		(game.get_node("PaperWorld") as PaperWorld).camera.input_enabled = false
	return game


func _step(game: Node, frames: int) -> void:
	for _i in frames:
		game.call("_process", 1.0 / SimConst.TICKS_PER_SECOND)


func _test_first_day() -> void:
	await _open_app()
	var menu := _app.menu
	var target := menu.continue_target()
	check(menu.current_screen() == "main" and target["index"] == 0 and not target["resume"]
		and target["label"] == "Začít hrát", "první spuštění: hlavní menu nabízí začít misí 1")
	menu.show_levels()
	check(menu.current_screen() == "levels" and not menu.cards[0].disabled
		and menu.cards[1].disabled and menu.cards[5].disabled,
		"výběr misí: otevřená jen první, ostatní zamčené")
	menu.cards[0].pressed.emit()
	await _frames(2)
	var game := _game()
	check(game != null and not menu.visible and not _app.backdrop.visible
		and _app.progress.entry("dira-v-louce")["plays"] == 1,
		"karta spustí misi 1, menu a pozadí zmizí, pokus se započítá")
	var sim: LevelSim = game.get("_sim")
	var hud: Hud = game.get_node("Hud")
	var title: Label = hud.get("_title")
	_step(game, 30)
	check(hud.briefing.visible and game.get("_paused") and sim.tick_count == 0
		and title.text == "1 · Díra v louce", "úvodní karta mise: hra stojí, název má číslo")
	game.call("_try_assign_touch", Vector2(640, 300))
	check(sim.replay_log.is_empty(), "klepnutí přes úvodní kartu nic nepřidělí")
	hud.briefing.close()
	check(not hud.briefing.visible and game.get("_flyover") and game.get("_paused"),
		"„Hrát“ kartu zavře a ukáže přelet mapy (čas zatím stojí)")
	game.call("_end_flyover")
	check(not game.get("_paused"), "po přeletu se spustí čas")
	_solve(game, sim, "dira-v-louce")
	check(sim.finished and sim.is_won() and hud.result_open() and sim.saved == 10,
		"mise 1 vyhraná referenčním řešením 10/10, ukáže se výsledek")
	var stars: CenterContainer = hud.get("_result_stars")
	var next: Button = hud.get("_next_button")
	var on_disk := Progress.load_from(_app.progress_path)
	check(next.visible and next.text.contains("Schody") and on_disk.is_completed("dira-v-louce")
		and on_disk.is_unlocked(1) and on_disk.stars(0) == 3 and stars.visible,
		"výsledek ukáže 3 hvězdy a další misi; výhra je hned uložená na disku")
	hud.menu_action.emit("next")
	sim = game.get("_sim")
	check(_app.game == game and title.text == "2 · Schody na terasu" and not hud.result_open()
		and hud.briefing.visible, "Další spustí misi 2 ve stejné instanci hry s úvodní kartou")
	hud.briefing.close()
	game.call("_end_flyover")
	_step(game, 60)
	var pressed := InputEventKey.new()
	pressed.physical_keycode = KEY_ESCAPE
	pressed.pressed = true
	game.call("_unhandled_input", pressed)
	check(hud.pause_menu_open() and game.get("_paused"), "Esc otevře pauzovací menu a zastaví čas")
	var tick := sim.tick_count
	_step(game, 20)
	var nuke := InputEventKey.new()
	nuke.physical_keycode = KEY_N
	nuke.pressed = true
	game.call("_unhandled_input", nuke)
	check(sim.tick_count == tick and not sim.nuking and not hud.confirmation_open(),
		"v pauzovacím menu čas stojí a herní klávesy nic nedělají")
	hud.menu_action.emit("resume")
	check(not hud.pause_menu_open() and not game.get("_paused"),
		"Pokračovat zavře menu a vrátí běh")
	hud.pause_pressed.emit()
	hud.menu_pressed.emit()
	hud.menu_action.emit("resume")
	check(game.get("_paused"), "ruční pauza zůstane i po zavření menu")
	hud.pause_pressed.emit()
	_step(game, 30)
	hud.menu_pressed.emit()
	hud.menu_action.emit("main_menu")
	await _frames(2)
	var saved := Progress.load_from(_app.progress_path)
	check(_app.game == null and menu.visible and menu.current_screen() == "main"
		and saved.has_suspended() and saved.suspended["mission"] == "schody-na-terasu",
		"Hlavní menu uvolní hru a rozehraný pokus mise 2 je uložený")
	target = menu.continue_target()
	check(target["resume"] and target["index"] == 1 and target["label"] == "Pokračovat",
		"Pokračovat nabízí rozehranou misi 2")


## Opakované přechody menu ↔ hra a restarty nehromadí uzly ani objekty.
func _test_leaks() -> void:
	await _frames(3)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var counts: Array[float] = []
	for round in 3:
		_app.start_mission(round % 2)
		await _frames(2)
		var game := _game()
		_step(game, 40)
		game.call("_restart")
		game.call("_restart")
		_step(game, 10)
		(game.get_node("Hud") as Hud).menu_action.emit("levels")
		await _frames(3)
		counts.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	check(counts.all(func(c: float) -> bool: return c == nodes) and orphans == 0.0,
		"tři přechody menu → hra → menu s restarty: uzlů stále %d (%s), osiřelých %d" % [
			nodes, str(counts), orphans])
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	_app.start_mission(0)
	await _frames(2)
	(_game().get_node("Hud") as Hud).menu_action.emit("levels")
	await _frames(3)
	var after := Performance.get_monitor(Performance.OBJECT_COUNT)
	check(absf(after - objects) <= 2.0, "objekty se po odchodu z mise uvolní (%d → %d)" % [
		objects, after])
	check(_app.menu.current_screen() == "levels", "Výběr misí vrátí na kartu misí")


func _test_next_day() -> void:
	var stored := Progress.load_from(_app.progress_path).suspended
	await _close_app()
	await _open_app()
	var progress := _app.progress
	check(progress.load_status == SaveFile.Status.OK and progress.is_completed("dira-v-louce")
		and progress.is_unlocked(1) and not progress.is_unlocked(2),
		"další den: nová instance aplikace načte splněnou misi 1 a odemčenou misi 2")
	_app.menu.show_levels()
	var status := _app.menu.cards[0].get_node("Text/Status") as Label
	check(status.text.begins_with("Nejlépe 10 z 10"),
		"karta mise 1 ukazuje rekord: %s" % status.text)
	_app.menu.show_main()
	var target := _app.menu.continue_target()
	_app.menu.play_requested.emit(target["index"], target["resume"])
	await _frames(2)
	var game := _game()
	var sim: LevelSim = game.get("_sim")
	check(game.get("_resumed") and sim.tick_count == int(stored["tick"]) and sim.tick_count > 0
		and Progress.digest(sim) == stored["digest"] and game.get("_paused")
		and not _app.progress.has_suspended() and not (game.get_node("Hud") as Hud).briefing.visible,
		"Pokračovat obnoví misi 2 na stejném tiku (%d) se stejným stavem, v pauze" % sim.tick_count)
	check(_app.progress.entry("schody-na-terasu")["plays"] == 1,
		"obnovení rozehraného pokusu se nepočítá jako nový pokus")
	(game.get_node("Hud") as Hud).menu_action.emit("main_menu")
	await _frames(2)


func _test_settings_in_game() -> void:
	var settings := _app.settings
	settings.set_value("unlock_all", true)
	_app.start_playground()
	await _frames(2)
	var game := _game()
	var hud: Hud = game.get_node("Hud")
	check(game != null and (hud.get("_title") as Label).text == "Hřiště",
		"Hřiště se spustí mimo kampaň (vývojové odemčení)")
	hud.briefing.close()
	game.call("_end_flyover")
	var world: PaperWorld = game.get_node("PaperWorld")
	settings.set_value("ui_scale", 1.3)
	await _frames(2)
	var widgets: Dictionary = hud.get("_skill_widgets")
	var fits := true
	var right := 0.0
	for skill in hud.visible_skills():
		var rect := (widgets[skill]["button"] as Button).get_global_rect()
		fits = fits and rect.position.x >= right - 0.5 and rect.end.x <= 1280.5 \
			and rect.end.y <= 720.5 and rect.position.y >= 720 - hud.bottom_bar_height()
		right = rect.end.x
	check(fits and hud.visible_skills().size() == 8 and world.camera.bottom_padding
		== Hud.BOTTOM_BAR_HEIGHT * 1.3, "rozhraní 130 %: osm dovedností se vejde do 1280 × 720 "
		+ "a herní plocha začíná nad zvětšenou lištou")
	settings.set_value("quality", GameSettings.Quality.LOW)
	var grain: Node2D = world.get("_grain")
	var light: Node2D = world.get("_light")
	check(not grain.visible and not light.visible and not world.foreground.visible
		and world.fx.max_scraps == 80 and not world.layers[0].show_drifters,
		"nízká kvalita vypne zrnitost, světlo, popředí, mraky a omezí ústřižky")
	settings.set_value("quality", GameSettings.Quality.HIGH)
	check(grain.visible and light.visible and world.foreground.visible and world.fx.petals,
		"vysoká kvalita vše vrátí")
	settings.set_value("stop_motion", false)
	settings.set_value("show_fps", true)
	settings.set_value("edge_scroll", false)
	settings.set_value("scroll_speed", 1.6)
	var fps: Control = hud.get("_fps_tab")
	check(not world.actors.stop_motion and fps.visible and not world.camera.edge_scroll
		and world.camera.speed_scale == 1.6, "pohyb postav, FPS a posun kamery se uplatní hned")
	settings.set_value("volume_ambient", 0.25)
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(
		AudioServer.get_bus_index("Ambient"))), 0.25), "hlasitost okolí se nastaví na sběrnici")
	hud.menu_pressed.emit()
	hud.open_settings()
	check(hud.settings_open(), "z pauzy jde otevřít nastavení")
	var panel: SettingsPanel = hud.get("_settings_panel")
	(panel.controls["confirm_nuke"] as Button).button_pressed = false
	panel.close()
	await _frames(1)
	var on_disk := GameSettings.load_from(_app.settings_path)
	check(not hud.settings_open() and not on_disk.confirm_nuke and on_disk.ui_scale == 1.3
		and on_disk.quality == GameSettings.Quality.HIGH,
		"přepínač v nastavení změní volbu a zavření ji uloží na disk")
	hud.menu_action.emit("resume")
	var sim: LevelSim = game.get("_sim")
	hud.nuke_requested.emit()
	check(sim.nuking and not hud.confirmation_open(), "bez potvrzování spustí Ukončit odpočet hned")
	settings.set_value("ui_scale", 1.0)
	settings.set_value("confirm_nuke", true)
	settings.save()
	hud.menu_action.emit("levels")
	await _frames(2)


func _test_back_and_background() -> void:
	_app.start_mission(0)
	await _frames(2)
	var game := _game()
	var hud: Hud = game.get_node("Hud")
	game.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not hud.briefing.visible and not hud.pause_menu_open() and game.get("_flyover"),
		"Zpět na úvodní kartě ji zavře a začne přelet mapy")
	game.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not game.get("_flyover") and not game.get("_paused") and not hud.pause_menu_open(),
		"další Zpět přelet přeskočí a spustí misi")
	_step(game, 40)
	game.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(hud.pause_menu_open(), "Zpět na Androidu otevře pauzovací menu")
	game.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not hud.pause_menu_open(), "druhé Zpět menu zavře")
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var saved := Progress.load_from(_app.progress_path)
	check(game.get("_paused") and saved.has_suspended()
		and saved.suspended["mission"] == "dira-v-louce",
		"přechod na pozadí hru zastaví a rozehraný pokus hned uloží")
	hud.menu_action.emit("levels")
	await _frames(2)
	_app.menu.show_settings()
	await _frames(1)
	_app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(_app.menu.current_screen() == "main" or _app.menu.current_screen() == "levels",
		"Zpět v menu zavře nastavení")
	_app.menu.show_settings()
	await _frames(1)
	var panel: SettingsPanel = _app.menu.get("_settings_panel")
	panel.reset_progress_confirmed.emit()
	check(_app.progress.missions.is_empty() and not _app.progress.has_suspended()
		and _app.menu.continue_target()["label"] == "Začít hrát",
		"Smazat postup vrátí hru na začátek")
	await _close_app()


## Referenční řešení mise přes stejné příkazy jako hráč (krok po kroku ve hře).
func _solve(game: Node, sim: LevelSim, id: String) -> void:
	var plan := ReferencePlans.plan_for(id)
	var state := {}
	for _t in 300 * SimConst.TICKS_PER_SECOND:
		var before := sim.tick_count
		_step(game, 1)
		if sim.tick_count != before:
			plan.call(sim, state)
		if sim.finished:
			_step(game, 1)
			return
