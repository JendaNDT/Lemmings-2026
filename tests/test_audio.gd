extends SimTest
## Zvuky: každá událost simulace má zvuk, podklady se načtou, omezení opakování,
## ztlumení a hlasitosti s uložením a napojení na skutečnou origami scénu.
## Zvuk nikdy nemění simulaci.

const SETTINGS := "user://test_audio/settings.json"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_event_coverage()
	_test_assets()
	await _test_limits_and_mute()
	await _test_scene()
	SaveFile.erase(SETTINGS)
	GameSettings.new().apply_audio()
	finish()


## Typy událostí, které simulace hlásí (přímo ze zdrojového kódu sim/).
func _sim_event_types() -> Array[String]:
	var found: Array[String] = []
	var regex := RegEx.create_from_string("emit_event\\(\\s*\\\"([a-z_]+)\\\"")
	var dirs := ["res://sim", "res://sim/states"]
	for dir_path: String in dirs:
		for file in DirAccess.get_files_at(dir_path):
			if not file.ends_with(".gd"):
				continue
			var text := FileAccess.get_file_as_string(dir_path + "/" + file)
			for m in regex.search_all(text):
				if not found.has(m.get_string(1)):
					found.append(m.get_string(1))
	return found


func _test_event_coverage() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameAudio.DATA_PATH))
	var types := _sim_event_types()
	var missing: Array[String] = []
	for type in types:
		var sound: String = GameAudio.EVENT_SOUNDS.get(type, "")
		if sound == "" or not (data["sounds"] as Dictionary).has(sound):
			missing.append(type)
	check(types.size() >= 15 and missing.is_empty(),
		"každá událost simulace (%d) má svůj zvuk; chybí: %s" % [types.size(), str(missing)])
	for ui in ["select", "click", "deny", "tick", "pause", "resume", "hatch", "nuke", "win", "lose"]:
		if not (data["sounds"] as Dictionary).has(ui):
			missing.append(ui)
	check(missing.is_empty(), "zvuky rozhraní, dvířek, odpočtu a výsledku existují")


func _test_assets() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameAudio.DATA_PATH))
	var ok := true
	var count := 0
	for name: String in data["sounds"]:
		for path: String in data["sounds"][name]["files"]:
			var stream := load(GameAudio.AUDIO_DIR + path) as AudioStreamWAV
			ok = ok and stream != null and not stream.stereo and stream.mix_rate == 44100 \
				and stream.get_length() > 0.04 and stream.get_length() < 2.0
			count += 1
	check(ok and count >= 28, "%d efektů se načte jako mono WAV 44,1 kHz kratší než 2 s" % count)
	var loops_ok := true
	for name: String in data["loops"]:
		var stream := load(GameAudio.AUDIO_DIR + data["loops"][name]["file"]) as AudioStreamWAV
		loops_ok = loops_ok and stream != null and stream.mix_rate == 22050 \
			and stream.get_length() >= 5.0
	check(loops_ok and (data["loops"] as Dictionary).size() == 3,
		"tři okolní smyčky (vítr, láva, voda)")


func _test_limits_and_mute() -> void:
	DirAccess.make_dir_recursive_absolute(SETTINGS.get_base_dir())
	SaveFile.erase(SETTINGS)
	var audio := GameAudio.new()
	root.add_child(audio)
	var sim := fixture(5)
	audio.setup(sim, func(p: Vector2) -> Vector2: return p * 4.0)
	var loop := audio.get_node("loop_wind") as AudioStreamPlayer
	check((loop.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD,
		"okolní smyčka se opakuje dokola")
	var events: Array[Dictionary] = []
	for i in 20:
		events.append({"type": "dig", "x": 10 + i, "y": 80, "dir": 1, "id": i, "value": 0})
	for i in 10:
		events.append({"type": "exit", "x": 50, "y": 80, "dir": 1, "id": i, "value": 0})
	audio.played.clear()
	audio.update(events)
	var digs := audio.played.count("dig")
	check(digs == 1 and audio.played.size() <= GameAudio.MAX_PER_FRAME,
		"hromada stejných událostí v jednom snímku nezahltí zvuk (kopání %d×, celkem %d)" % [
			digs, audio.played.size()])
	var player := audio.get_node("dig_0") as AudioStreamPlayer2D
	check(player.position == Vector2(10.5, 76.0) * 4.0, "zvuk zní v místě události na obrazovce")
	audio.update(events.slice(0, 1), 0.12)
	check(audio.played.count("dig") == 2, "po krátkém odstupu se zvuk smí ozvat znovu")
	var master := AudioServer.get_bus_index("Master")
	var settings := GameSettings.load_from(SETTINGS)
	settings.set_value("muted", true)
	settings.apply_audio()
	settings.save()
	check(AudioServer.is_bus_mute(master), "ztlumení ztiší vše")
	var again := GameSettings.load_from(SETTINGS)
	check(again.muted and again.load_status == SaveFile.Status.OK,
		"ztlumení se uloží a vydrží i po novém spuštění")
	again.set_value("muted", false)
	again.set_value("volume_sfx", 0.5)
	again.set_value("volume_music", 0.0)
	again.apply_audio()
	var sfx := AudioServer.get_bus_index("SFX")
	var music := AudioServer.get_bus_index("Music")
	check(not AudioServer.is_bus_mute(master) and absf(AudioServer.get_bus_volume_db(sfx)
		- linear_to_db(0.5)) < 0.01 and AudioServer.is_bus_mute(music),
		"zvuk jde zase zapnout; hlasitost efektů 50 %, hudba na nule je ztlumená")
	for bus: String in GameAudio.BUSES:
		check(AudioServer.get_bus_index(bus) >= 0, "sběrnice %s existuje (hudba přijde později)" % bus)
	GameSettings.new().apply_audio()
	audio.free()
	await process_frame


func _test_scene() -> void:
	var game := (load("res://main/game_origami.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.set_process(false)
	var audio: GameAudio = game.get_node("Audio")
	var world: PaperWorld = game.get_node("PaperWorld")
	world.camera.input_enabled = false
	var hud: Hud = game.get_node("Hud")
	var sim: LevelSim = game.get("_sim")
	check(audio.played.is_empty(), "výběr výchozí dovednosti při načtení levelu nezní")
	for _frame in 120:
		game.call("_process", 1.0 / 30.0)
	check(audio.played.has("hatch") and audio.played.has("spawn"),
		"otevření líhně a vypadnutí lumíka mají zvuk")
	hud.skill_selected.emit(Lemming.Skill.BUILDER)
	var lem := sim.lemmings[0]
	world.camera.focus = Vector2(lem.x, lem.y)
	world.camera.refresh()
	var at := world.camera.logic_to_screen(Vector2(lem.x + 0.5, lem.y - 5))
	game.call("_try_assign_touch", at)
	game.call("_process", 1.0 / 30.0)
	check(audio.played.has("select") and audio.played.has("assign"),
		"výběr dovednosti a přidělení postavě zní")
	game.call("_try_assign_touch", at)
	check(audio.played.has("deny"), "druhé klepnutí na stejného stavitele ohlásí, že to nejde")
	hud.release_rate_step.emit(1)
	hud.pause_pressed.emit()
	hud.pause_pressed.emit()
	check(audio.played.has("tick") and audio.played.has("pause") and audio.played.has("resume"),
		"vypouštění a pauza mají zvuky rozhraní")
	var log_size := sim.replay_log.size()
	var settings: GameSettings = game.get("settings")
	hud.sound_pressed.emit()
	check(settings.muted and AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
		and sim.replay_log.size() == log_size, "tlačítko zvuku ztlumí hru bez herního příkazu")
	hud.sound_pressed.emit()
	game.call("_choose_mission", 5)
	sim = game.get("_sim")
	var water := audio.get_node("loop_water") as AudioStreamPlayer2D
	var lava := audio.get_node("loop_lava") as AudioStreamPlayer2D
	game.call("_process", 1.0 / 30.0)
	var expected := world.camera.logic_to_screen(Vector2(240.5, 115))
	check(water.position.distance_to(expected) < 120.0 and lava.position.x > water.position.x,
		"smyčky vody a lávy zní z jejich místa v misi 6")
	sim.spec.time_limit_seconds = 1
	for _frame in 120:
		game.call("_process", 1.0 / 30.0)
		if sim.finished:
			game.call("_process", 1.0 / 30.0)
			break
	check(sim.finished and audio.played.has("lose"), "konec mise zahraje krátkou znělku")
	game.free()
	await process_frame
