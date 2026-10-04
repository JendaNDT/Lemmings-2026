extends SimTest
## Přelet mapy ve skutečné aplikaci: po úvodní kartě kamera ukáže východ
## se štítkem, přeletí na startovní záběr u líhně a teprve pak se spustí čas.
## Klepnutí, klávesa i Zpět ho přeskočí, přechod na pozadí ho ukončí v pauze;
## restart ani ukázka ho neopakují a jde vypnout v nastavení. Šipka u okraje
## ukazuje k východu mimo záběr. Simulace se během přeletu nemění.

const DIR := "user://test_flyover"
const MISSION := "origami-finale"

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
	_app.start_mission(Campaign.index_of(MISSION))
	await _frames(3)
	var game := _app.game
	game.set_process(false)
	(game.get_node("PaperWorld") as PaperWorld).camera.input_enabled = false
	_test_flight(game)
	_test_skip(game)
	_test_no_repeat(game)
	_test_edge_arrow(game)
	_test_setting(game)
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


## Znovu stejná mise s úvodní kartou (jako tlačítko Další nebo výběr mise).
func _replay_mission(game: Node) -> void:
	game.call("_choose_mission", Campaign.index_of(MISSION))


func _exit_on_screen(world: PaperWorld) -> bool:
	var exit := Vector2(world.guide.exits[0]) - Vector2(0, 20)
	return world.guide.play_rect().has_point(world.camera.logic_to_screen(exit))


func _test_flight(game: Node) -> void:
	var hud: Hud = game.get_node("Hud")
	var world: PaperWorld = game.get_node("PaperWorld")
	var sim: LevelSim = game.get("_sim")
	var start_focus := world.camera.focus
	var start_zoom := world.camera.zoom_factor
	check(hud.briefing.visible and not _exit_on_screen(world),
		"finále začíná úvodní kartou a východ není ze startu vidět")
	hud.briefing.close()
	check(game.get("_flyover") and game.get("_paused") and hud.flyover.visible
		and game.call("_overlay_open") and _exit_on_screen(world)
		and world.camera.zoom_factor < start_zoom,
		"„Hrát“ spustí přelet: čas stojí, kamera ukáže východ v širším záběru")
	_step(game, 6)
	var label: Label = hud.flyover.get_child(0).get_child(0)
	check(world.guide.exit_tag > 0.9 and world.guide.arrow_position() == Vector2.INF
		and label.text.begins_with("Přelet mapy"),
		"nad východem je štítek Východ, šipka u okraje se při přeletu neukazuje")
	var duration := world.flyover.duration
	var min_zoom := INF
	var frames := 6
	var ticks_ok := true
	while game.get("_flyover") and frames < 200:
		_step(game, 1)
		frames += 1
		if game.get("_flyover"):
			ticks_ok = ticks_ok and sim.tick_count == 0 and sim.replay_log.is_empty() \
				and world.guide.arrow_position() == Vector2.INF
		min_zoom = minf(min_zoom, world.camera.zoom_factor)
	check(ticks_ok and absf(frames / float(SimConst.TICKS_PER_SECOND) - duration) < 0.15
		and duration <= 5.0,
		"během přeletu (%.1f s) simulace stojí na tiku 0, šipka u okraje se neukáže" % duration)
	check(min_zoom < start_zoom * PaperFlyover.EXIT_ZOOM - 0.1,
		"dlouhý let se uprostřed oddálí a ukáže kus mapy")
	check(not game.get("_paused") and not hud.flyover.visible and world.flyover == null
		and world.guide.exit_tag == 0.0 and world.camera.focus.is_equal_approx(start_focus)
		and is_equal_approx(world.camera.zoom_factor, start_zoom),
		"přelet skončí na startovním záběru u líhně a čas se rozběhne")
	_step(game, 17)
	check(sim.tick_count >= 16, "po přeletu hra běží")


func _test_skip(game: Node) -> void:
	var hud: Hud = game.get_node("Hud")
	var world: PaperWorld = game.get_node("PaperWorld")
	_replay_mission(game)
	var start_focus := world.camera.focus
	hud.briefing.close()
	_step(game, 5)
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	game.call("_unhandled_input", space)
	check(not game.get("_flyover") and not game.get("_paused")
		and world.camera.focus.is_equal_approx(start_focus),
		"klávesa přelet přeskočí (mezerník při tom hru nepozastaví)")
	_replay_mission(game)
	hud.briefing.close()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(640, 300)
	hud.flyover.call("_gui_input", click)
	var sim: LevelSim = game.get("_sim")
	check(not game.get("_flyover") and not game.get("_paused") and sim.replay_log.is_empty()
		and world.camera.focus.is_equal_approx(start_focus),
		"klepnutí kamkoli přelet přeskočí a nic nepřidělí")
	_replay_mission(game)
	hud.briefing.close()
	game.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not game.get("_flyover") and not game.get("_paused") and not hud.pause_menu_open(),
		"Zpět na Androidu přelet přeskočí (pauzovací menu až dalším Zpět)")
	_replay_mission(game)
	hud.briefing.close()
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not game.get("_flyover") and game.get("_paused") and not hud.flyover.visible
		and world.camera.focus.is_equal_approx(start_focus),
		"přechod na pozadí přelet ukončí, hra zůstane v pauze")
	hud.pause_pressed.emit()


func _test_no_repeat(game: Node) -> void:
	var hud: Hud = game.get_node("Hud")
	hud.restart_pressed.emit()
	check(not game.get("_flyover") and not game.get("_paused") and not hud.briefing.visible,
		"Znovu spustí misi hned, bez karty a přeletu")
	game.call("_on_menu_action", "demo")
	check(game.get("_demo") and not game.get("_flyover") and not game.get("_paused"),
		"ukázka řešení začne bez přeletu")
	hud.restart_pressed.emit()


func _test_edge_arrow(game: Node) -> void:
	var world: PaperWorld = game.get_node("PaperWorld")
	_step(game, 1)
	var rect := world.guide.play_rect()
	var arrow := world.guide.arrow_position()
	check(world.guide.edge_arrow and arrow != Vector2.INF and rect.has_point(arrow)
		and arrow.x > rect.get_center().x + rect.size.x * 0.35,
		"východ mimo záběr: šipka u pravého okraje ukazuje k němu")
	world.camera.focus = Vector2(world.guide.exits[0])
	world.camera.refresh()
	_step(game, 1)
	check(world.guide.arrow_position() == Vector2.INF, "když je východ vidět, šipka zmizí")
	_app.settings.set_value("ui_scale", 1.3)
	check(is_equal_approx(world.guide.ui_scale, 1.3), "ukazatele rostou s velikostí rozhraní")
	_app.settings.set_value("ui_scale", 1.0)


func _test_setting(game: Node) -> void:
	var hud: Hud = game.get_node("Hud")
	hud.menu_pressed.emit()
	hud.open_settings()
	var panel: SettingsPanel = hud.get("_settings_panel")
	(panel.controls["flyover"] as Button).button_pressed = false
	panel.close()
	hud.menu_action.emit("resume")
	var on_disk := GameSettings.load_from(_app.settings_path)
	_replay_mission(game)
	hud.briefing.close()
	check(not _app.settings.flyover and not on_disk.flyover and not game.get("_flyover")
		and not game.get("_paused"), "přelet jde vypnout v nastavení (Hra); mise pak začne hned")
	_app.settings.set_value("flyover", true)
	_app.settings.save()
