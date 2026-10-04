extends SceneTree
## Maraton (etapa 10): jedna instance aplikace odehraje celou kampaň za sebou
## podle referenčních řešení – s restartem v každé misi, tlačítkem „Další“
## a návratem do menu po každé kapitole – a hlídá uzly, objekty, paměť,
## výsledky i zápis postupu. Výstup: řádek na misi a SOAK OK / SOAK CHYBA.
##
##   godot --headless --path . --script res://scripts/soak.gd
##   (s vykreslováním přes xvfb-run hlásí i paměť textur)

const DIR := "user://soak"

var _failed := false
var _app: App


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(DIR)
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(name))
	_app = (load("res://main/app.tscn") as PackedScene).instantiate() as App
	_app.settings_path = DIR.path_join("settings.json")
	_app.progress_path = DIR.path_join("progress.json")
	root.add_child(_app)
	await _frames(5)
	var base_static := 0.0
	var start := Time.get_ticks_msec()
	print("| # | Mise | Zachráněno | Mistr | Tiky | Uzlů ve hře | Statická paměť MB"
		+ " | Textury MB | s |")
	print("|---|---|---|---|---|---|---|---|---|")
	for chapter in Campaign.CHAPTERS.size():
		var indices := Campaign.chapter_indices(chapter)
		_app.start_mission(indices[0])
		await _frames(3)
		for index in indices:
			await _play(index)
			var hud: Hud = _app.game.get_node("Hud")
			if index != indices[-1]:
				hud.menu_action.emit("next")
				await _frames(2)
		(_app.game.get_node("Hud") as Hud).menu_action.emit("levels")
		await _frames(4)
		# Nově odemčené karty misí mají hvězdy a tečky (víc uzlů je v pořádku).
		# Únik pozná až druhý návrat do menu bez dalšího odemčení.
		var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		_app.start_mission(indices[0])
		await _frames(3)
		_app.game.set_process(false)
		(_app.game.get_node("Hud") as Hud).menu_action.emit("levels")
		await _frames(4)
		var again := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
		var memory := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
		var label: String = Campaign.CHAPTERS[chapter][0]
		if chapter == 0:
			base_static = memory
		print("MENU po kapitole %s: uzlů %d, po dalším návratu %d, osiřelých %d, paměť %.1f MB" % [
			label, nodes, again, orphans, memory])
		_expect(again == nodes and orphans == 0,
			"po kapitole %s další návrat do menu nepřidá uzly" % label)
		_expect(memory - base_static < 24.0, "paměť po kapitole %s neroste (%.1f MB navíc)" % [
			label, memory - base_static])
	var progress := Progress.load_from(_app.progress_path)
	var stars := 0
	for index in Campaign.count():
		stars += progress.stars(index)
	_expect(stars == Campaign.count() * 3, "na disku je celá kampaň se všemi hvězdami (%d)" % stars)
	print("SOAK %s – %d misí za %.0f s" % ["CHYBA" if _failed else "OK", Campaign.count(),
		(Time.get_ticks_msec() - start) / 1000.0])
	_app.queue_free()
	await _frames(3)
	quit(1 if _failed else 0)


## Jedna mise: úvodní karta, přelet, kousek hry, restart a pak celé řešení.
func _play(index: int) -> void:
	var game := _app.game
	game.set_process(false)
	var hud: Hud = game.get_node("Hud")
	var id: String = Campaign.mission(index)["id"]
	var mission_start := Time.get_ticks_msec()
	hud.briefing.close()
	game.call("_end_flyover")
	for _i in 60:
		game.call("_process", 1.0 / SimConst.TICKS_PER_SECOND)
	game.call("_restart")
	var sim: LevelSim = game.get("_sim")
	var plan := ReferencePlans.plan_for(id)
	var state := {}
	var nodes := 0.0
	var limit := sim.spec.time_limit_seconds * SimConst.TICKS_PER_SECOND + 200
	while not sim.finished and sim.tick_count < limit:
		var before := sim.tick_count
		game.call("_process", 1.0 / SimConst.TICKS_PER_SECOND)
		if sim.tick_count != before:
			plan.call(sim, state)
		if sim.tick_count == 600:
			nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		if sim.tick_count % 120 == 0:
			await process_frame
	game.call("_process", 0.0)
	await _frames(2)
	var master := int(Campaign.mission(index)["master"])
	var textures := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	print("| %d | %s | %d | %d | %d | %d | %.1f | %.0f | %.1f |" % [index + 1,
		Campaign.mission(index)["title"], sim.saved, master, sim.tick_count, nodes,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, textures,
		(Time.get_ticks_msec() - mission_start) / 1000.0])
	_expect(sim.finished and sim.saved == master and hud.result_open(),
		"%s: řešení zachrání mistrovských %d a ukáže výsledek" % [id, master])


func _expect(condition: bool, text: String) -> void:
	if not condition:
		_failed = true
		print("[CHYBA] " + text)


func _frames(count: int) -> void:
	for _i in count:
		await process_frame
