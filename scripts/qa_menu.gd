extends SceneTree
## Grafický průchod menu a ukládáním: první spuštění, výběr misí, výhra mise 1
## skutečnými kliknutími, výsledek, další mise, pauzovací menu, nastavení,
## odchod s rozehraným pokusem a „další den“ (nová instance aplikace).
## Ukládá snímky obrazovek; postup a nastavení jdou do vlastní složky user://.
##
## Spuštění (s grafikou, např. pod Xvfb):
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 \
##     --script res://scripts/qa_menu.gd -- --capture-dir=build/menu [--mobile]

const DATA_DIR := "user://qa_menu"

var _dir := "res://build/menu"
var _app: App
var _failed := false
var _report := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_dir = arg.trim_prefix("--capture-dir=")
		elif arg == "--mobile":
			root.content_scale_size = Vector2i(1280, 720)
			root.size = Vector2i(1600, 720)
	DirAccess.make_dir_recursive_absolute(_dir)
	DirAccess.make_dir_recursive_absolute(DATA_DIR)
	for file in ["settings.json", "progress.json"]:
		SaveFile.erase(DATA_DIR.path_join(file))
	await _first_day()
	await _next_day()
	_report["renderer"] = RenderingServer.get_video_adapter_name()
	var file := FileAccess.open(_dir.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_report, "\t"))
	print("MENU_QA ", "FAIL" if _failed else "OK", " ", JSON.stringify(_report))
	quit(1 if _failed else 0)


func _first_day() -> void:
	await _open_app()
	await _capture("01-hlavni-menu")
	await _click(_find_button(_app.menu, "Mise"))
	await _capture("02-vyber-misi")
	_expect(_app.menu.cards[1].disabled and not _app.menu.cards[0].disabled,
		"na začátku je otevřená jen první mise")
	await _click(_app.menu.cards[0])
	var game := _app.game
	_expect(game != null, "karta mise spustí hru")
	await _frames(10)
	await _capture("03-uvodni-karta")
	var hud: Hud = game.get_node("Hud")
	_expect(hud.briefing.visible, "mise začíná úvodní kartou")
	await _click(_find_button(hud, "Hrát"))
	await _frames(30)
	await _capture("03-mise-1")
	await _win_mission_one(game)
	await _capture("04-vysledek")
	var next: Button = game.get_node("Hud").get("_next_button")
	_expect(next.visible, "po výhře nabízí další misi")
	await _click(next)
	await _frames(40)
	var sim: LevelSim = game.get("_sim")
	_expect(sim.spec.title == "Schody na terasu", "tlačítko Další spustí misi 2")
	await _capture("04-uvodni-karta-2")
	await _click(_find_button(hud, "Hrát"))
	# Kousek mise 2, pak pauzovací menu, nápověda a nastavení.
	await _play(game, 120)
	Input.parse_input_event(_key(KEY_ESCAPE))
	await _frames(4)
	await _click(_find_button(hud, "Nápověda"))
	await _frames(3)
	await _capture("05-pauza")
	_expect(hud.pause_menu_open(), "Esc otevře pauzovací menu")
	await _click(_find_button(hud, "Nastavení"))
	await _frames(4)
	await _capture("06-nastaveni-zvuk")
	var panel: SettingsPanel = hud.get("_settings_panel")
	panel.show_tab(1)
	await _frames(3)
	await _click((panel.controls["ui_scale"] as Array)[3])
	await _frames(4)
	await _capture("07-nastaveni-zobrazeni")
	await _click(_find_button(panel, "Hotovo"))
	await _frames(4)
	await _click(_find_button(hud, "Pokračovat"))
	await _frames(10)
	await _capture("08-velke-rozhrani")
	_report["mission2_tick"] = sim.tick_count
	Input.parse_input_event(_key(KEY_ESCAPE))
	await _frames(4)
	await _click(_find_button(hud, "Hlavní menu"))
	await _frames(10)
	await _capture("09-menu-rozehrano")
	_expect(_app.game == null and _app.menu.continue_target()["resume"],
		"odchod do menu uloží rozehraný pokus")
	_app.queue_free()
	await _frames(4)


## „Další den“: nová instance aplikace načte postup a nastavení ze souborů.
func _next_day() -> void:
	await _open_app()
	await _capture("10-druhy-den")
	_expect(_app.progress.is_completed("dira-v-louce") and _app.settings.ui_scale > 1.2,
		"postup i nastavení vydržely nové spuštění")
	await _click(_find_button(_app.menu, "Pokračovat"))
	await _frames(20)
	var game := _app.game
	var sim: LevelSim = game.get("_sim")
	_expect(game.get("_resumed") and sim.tick_count == int(_report["mission2_tick"]),
		"Pokračovat obnoví rozehranou misi 2 na stejném tiku")
	await _capture("11-obnoveno")
	_app.settings.set_value("ui_scale", 1.0)
	_app.settings.save()
	Input.parse_input_event(_key(KEY_ESCAPE))
	await _frames(4)
	await _click(_find_button(game.get_node("Hud"), "Výběr misí"))
	await _frames(10)
	await _capture("12-mise-po-navratu")
	_app.settings.set_value("unlock_all", true)
	_report["missions"] = Campaign.count()
	_app.menu.show_chapter(1)
	await _frames(4)
	await _capture("13-kapitola-2")
	_app.menu.show_chapter(2)
	await _frames(4)
	await _capture("14-kapitola-3")
	_app.menu.show_chapter(3)
	await _frames(4)
	await _capture("15-kapitola-4")
	_app.queue_free()
	await _frames(4)


func _open_app() -> void:
	_app = (load("res://main/app.tscn") as PackedScene).instantiate() as App
	_app.settings_path = DATA_DIR.path_join("settings.json")
	_app.progress_path = DATA_DIR.path_join("progress.json")
	root.add_child(_app)
	await _frames(20)


## Mise 1 skutečně: kopáč přes lištu a kliknutí na postavu (zrychleně).
func _win_mission_one(game: Node) -> void:
	var sim: LevelSim = game.get("_sim")
	var hud: Hud = game.get_node("Hud")
	var world: PaperWorld = game.get_node("PaperWorld")
	world.camera.input_enabled = false
	var dug := false
	game.set("_speed", 3.0)
	for _frame in 4000:
		await process_frame
		if sim.finished:
			break
		if dug:
			continue
		for lem in sim.lemmings:
			if lem.removed or lem.state != Lemming.State.WALKER or lem.x < 100:
				continue
			hud.skill_selected.emit(Lemming.Skill.DIGGER)
			world.camera.focus = Vector2(lem.x, lem.y)
			world.camera.refresh()
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = world.camera.logic_to_screen(Vector2(lem.x + 0.5, lem.y - 5))
			game.call("_unhandled_input", click)
			dug = not sim.replay_log.is_empty()
			break
	await _frames(10)
	_report["mission1"] = [sim.saved, sim.spec.lemming_count, sim.tick_count]
	_expect(sim.finished and sim.is_won(), "mise 1 vyhraná přes lištu a kliknutí")


func _play(game: Node, frames: int) -> void:
	game.set("_speed", 3.0)
	await _frames(frames)
	game.set("_speed", 1.0)


func _find_button(node: Node, text: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		var button := child as Button
		if button.is_visible_in_tree() and (button.text == text
				or (button.has_node("Text/Title")
					and (button.get_node("Text/Title") as Label).text == text)):
			return button
	_expect(false, "tlačítko „%s“ nenalezeno" % text)
	return null


## Skutečné kliknutí myší doprostřed tlačítka (přes vstup okna).
func _click(button: Control) -> void:
	if button == null:
		return
	var at := button.get_global_rect().get_center()
	at = root.get_final_transform() * at
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
		await process_frame
	await _frames(2)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(_dir.path_join(name + ".png"))


func _expect(ok: bool, text: String) -> void:
	print("[%s] %s" % ["OK" if ok else "CHYBA", text])
	if not ok:
		_failed = true
