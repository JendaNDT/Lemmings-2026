extends SimTest
## Skutečné nahrávky, střídání v kampani, mix, životní cyklus a izolace simulace.

const DIR := "user://test_music"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	_test_tracks()
	await _test_player()
	await _test_application()
	_clean()
	GameSettings.new().apply_audio()
	finish()


func _clean() -> void:
	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file))


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _test_tracks() -> void:
	var durations := [95.2, 107.2, 155.2, 162.4]
	for i in 4:
		var stream := load(GameMusic.TRACKS[i]) as AudioStreamOggVorbis
		check(stream != null and absf(stream.get_length() - durations[i]) < 0.1,
			"dodaná skladba %d se načte jako Vorbis se zachovanou délkou" % (i + 1))
	var assigned: Array[int] = []
	for info: Dictionary in Campaign.missions():
		assigned.append(GameMusic.slot_for_mission(info["id"]))
	check(assigned == [0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3,
		0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3],
		"všech 24 misí střídá čtyři skladby v pořadí nahrání, i přes hranice kapitol")
	check(GameMusic.slot_for_mission(Campaign.playground()["id"]) == 0,
		"Hřiště mimo kampaň dostává první skladbu")


func _test_player() -> void:
	var music := GameMusic.new()
	root.add_child(music)
	music.set_process(false)
	var first: AudioStreamPlayer = music.get_node("Voice0")
	var second: AudioStreamPlayer = music.get_node("Voice1")
	var starts: Array[int] = []
	music.track_started.connect(func(slot: int) -> void: starts.append(slot))
	check(not first.playing and not second.playing, "v menu se hudba sama nespustí")
	music.play_mission(Campaign.mission(0)["id"])
	if music.silent:
		check(music.current_slot == 0 and first.stream == null and second.stream == null,
			"headless běh eviduje hudbu bez hlasů v neaktivním mixéru")
		music.free()
		return
	music.call("_process", GameMusic.CHANGE_FADE)
	check(second.playing and not first.playing and second.bus == "Music"
		and absf(second.volume_db - GameMusic.GAIN_DB) < 0.01,
		"první mise spustí první skladbu přes samostatnou hudební sběrnici")
	music.play_mission(Campaign.mission(0)["id"])
	check(starts == [0], "opětovné spuštění stejné mise hudbu nerestartuje")
	music.play_mission(Campaign.mission(1)["id"])
	music.call("_process", GameMusic.CHANGE_FADE * 0.5)
	check(first.playing and second.playing and first.volume_db < GameMusic.GAIN_DB
		and second.volume_db < GameMusic.GAIN_DB,
		"změna mise prolíná dvě skladby se zeslabenými hlasy")
	music.call("_process", GameMusic.CHANGE_FADE)
	check(first.playing and not second.playing and second.stream == null,
		"po přechodu dohraje jen nová skladba; starý stream se uvolní")
	# Skutečná pozice nahrávky v dekodéru přiblíží konec bez čekání dvě minuty.
	first.seek(first.stream.get_length() - 0.2)
	await _frames(3)
	music.call("_process", 0.02)
	check(starts == [0, 1, 1] and second.playing,
		"u konce nahrávky se rozjede její vlastní začátek, nikoli další skladba")
	music.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(first.stream_paused and second.stream_paused,
		"uspání aplikace během prolínání pozastaví oba hudební hlasy")
	music.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(not first.stream_paused and not second.stream_paused,
		"návrat do aplikace obnoví hudbu")
	music.call("_process", GameMusic.LOOP_FADE)
	music.stop_music()
	music.call("_process", GameMusic.CHANGE_FADE)
	check(music.current_slot == -1 and not first.playing and not second.playing
		and first.stream == null and second.stream == null,
		"odchod do menu postupně ztiší a uvolní oba přehrávače")
	music.play_mission(Campaign.mission(2)["id"])
	music.stop_music()
	music.play_mission(Campaign.mission(3)["id"])
	music.call("_process", GameMusic.CHANGE_FADE)
	check(music.current_slot == 3 and (int(first.playing) + int(second.playing)) == 1,
		"rychlý odchod a nová mise nezanechají starou skladbu nebo třetí hlas")
	music.free()
	await _frames(2)


func _test_application() -> void:
	var app := (load("res://main/app.tscn") as PackedScene).instantiate() as App
	app.settings_path = DIR.path_join("settings.json")
	app.progress_path = DIR.path_join("progress.json")
	root.add_child(app)
	await _frames(2)
	var music := app.music
	music.set_process(false)
	var starts: Array[int] = []
	music.track_started.connect(func(slot: int) -> void: starts.append(slot))
	app.start_mission(0)
	await _frames(2)
	var game := app.game
	game.set_process(false)
	var hud: Hud = game.get_node("Hud")
	hud.briefing.close()
	game.call("_end_flyover")
	music.call("_process", GameMusic.CHANGE_FADE)
	check(game.get("music") == music and music.current_slot == 0,
		"skutečná herní scéna používá hudbu vlastněnou aplikací")
	var sim: LevelSim = game.get("_sim")
	var before := snapshot(sim)
	app.settings.set_value("volume_music", 0.25)
	app.settings.apply_audio()
	app.settings.save()
	var again := GameSettings.load_from(app.settings_path)
	var bus := AudioServer.get_bus_index("Music")
	check(is_equal_approx(again.volumes["music"], 0.25)
		and absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.25)) < 0.01,
		"hudební hlasitost se promítá do mixu a zůstane uložená")
	app.settings.set_value("volume_music", 0.0)
	app.settings.apply_audio()
	check(AudioServer.is_bus_mute(bus)
		and not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),
		"nula vypne jen hudbu, efekty zůstávají zapnuté")
	check(snapshot(sim) == before, "přehrávání a změny hlasitosti nemění simulaci ani replay")
	hud.pause_pressed.emit()
	hud.speed_pressed.emit()
	hud.speed_pressed.emit()
	var normal_pitch := true
	for child in music.get_children():
		normal_pitch = normal_pitch and is_equal_approx(child.pitch_scale, 1.0)
	check(normal_pitch and starts == [0], "pauza, zrychlení i zpomalení nemění tempo hudby")
	hud.restart_pressed.emit()
	check(starts == [0], "restart přes herní HUD zachová právě hrající skladbu")
	# Získat několik sekund historie a provést skutečné přetočení.
	hud.briefing.close()
	game.call("_end_flyover")
	for _i in 100:
		game.call("_process", 1.0 / SimConst.TICKS_PER_SECOND)
	sim = game.get("_sim")
	var tick_before := sim.tick_count
	hud.rewind_pressed.emit()
	sim = game.get("_sim")
	check(tick_before >= 85 and sim.tick_count < tick_before and starts == [0],
		"skutečný návrat o pět sekund nepřetáčí ani nerestartuje hudbu")
	game.call("_choose_mission", 4)
	check(music.current_slot == 0 and starts == [0],
		"pátá mise používá stejnou skladbu jako první a při přímém skoku nepřeruší zvuk")
	game.call("_choose_mission", 5)
	check(music.current_slot == 1 and starts == [0, 1],
		"přechod na šestou misi zvolí druhou skladbu")
	game.call("_on_menu_action", "main_menu")
	await _frames(2)
	music.call("_process", GameMusic.CHANGE_FADE)
	check(app.game == null and app.music == music and music.current_slot == -1,
		"návrat do menu zruší misi, ale ponechá přehrávač pro plynulé ztišení")
	app.free()
	await _frames(2)
