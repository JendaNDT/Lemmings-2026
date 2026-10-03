extends SimTest
## Ukládání: bezpečný zápis (přerušení, poškození, záloha, změna formátu),
## nastavení s ochranou rozsahů, postup kampaně, rozehraný pokus přes replay
## a stabilní identifikátory misí.

const DIR := "user://test_save"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	_test_save_file()
	_test_damage()
	_test_settings()
	_test_campaign()
	_test_progress()
	_test_suspend()
	_clean()
	finish()


func _path(name: String) -> String:
	return DIR.path_join(name)


func _clean() -> void:
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(_path(name))


func _write_raw(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _test_save_file() -> void:
	var path := _path("data.json")
	var missing := SaveFile.read(path)
	check(missing["status"] == SaveFile.Status.MISSING and missing["data"].is_empty(),
		"chybějící soubor se hlásí jako chybějící, s prázdnými daty")
	var data := {"jmeno": "Lumík", "cisla": [1, 2, 3], "vnorene": {"a": true}}
	check(SaveFile.write(path, data, 3) == OK, "zápis proběhne")
	var back := SaveFile.read(path)
	check(back["status"] == SaveFile.Status.OK and back["format"] == 3
		and back["data"]["jmeno"] == "Lumík" and back["data"]["vnorene"]["a"] == true
		and (back["data"]["cisla"] as Array).size() == 3, "data a verze formátu se načtou zpět")
	check(not FileAccess.file_exists(path + ".tmp"), "dočasný soubor po zápisu nezůstane")
	SaveFile.write(path, {"verze": 2}, 3)
	check(FileAccess.file_exists(path + ".bak")
		and SaveFile.read(path + ".bak")["data"].get("jmeno") == "Lumík",
		"předchozí platná verze zůstane jako záloha .bak")


func _test_damage() -> void:
	var path := _path("damaged.json")
	SaveFile.write(path, {"krok": 1}, 1)
	SaveFile.write(path, {"krok": 2}, 1)
	# Přerušený zápis: nedokončený .tmp vedle platného souboru.
	_write_raw(path + ".tmp", "{\"game\":\"lemmings-2026\",\"for")
	check(SaveFile.read(path)["data"].get("krok") == 2.0,
		"přerušený zápis (useknutý .tmp) neovlivní platná data")
	check(SaveFile.write(path, {"krok": 3}, 1) == OK
		and SaveFile.read(path)["data"].get("krok") == 3.0, "další zápis po přerušeném proběhne normálně")
	# Poškozený obsah: změněná číslice v datech neodpovídá kontrolnímu součtu.
	var text := FileAccess.get_file_as_string(path).replace("\"krok\":3", "\"krok\":9")
	_write_raw(path, text)
	var restored := SaveFile.read(path)
	check(restored["status"] == SaveFile.Status.BACKUP and restored["data"].get("krok") == 2.0,
		"změněná data odhalí kontrolní součet a načte se záloha")
	check(FileAccess.file_exists(path + ".corrupt"), "poškozený soubor se odloží jako .corrupt")
	_write_raw(path, "")
	check(SaveFile.read(path)["status"] == SaveFile.Status.BACKUP, "prázdný soubor (useknutý zápis)")
	_write_raw(path, "{\"game\": 7, \"format\": \"x\", \"sha256\": false}\n[]")
	check(SaveFile.read(path)["status"] == SaveFile.Status.BACKUP,
		"hlavička se špatnými typy se pozná jako poškozená")
	_write_raw(path, "nesmysl\núplný")
	_write_raw(path + ".bak", "{}\n{}")
	var broken := SaveFile.read(path)
	check(broken["status"] == SaveFile.Status.CORRUPT and broken["data"].is_empty(),
		"poškozený soubor i záloha: hra začne s výchozími hodnotami a nespadne")
	SaveFile.erase(path)
	check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"),
		"smazání odstraní soubor i zálohu")


func _test_settings() -> void:
	var path := _path("settings.json")
	var settings := GameSettings.load_from(path)
	check(settings.load_status == SaveFile.Status.MISSING and not settings.muted
		and settings.ui_scale == 1.0 and settings.quality == GameSettings.Quality.HIGH,
		"první spuštění: výchozí nastavení (vysoká kvalita na počítači)")
	settings.set_value("volume_sfx", 0.4)
	settings.set_value("volume_master", 7.0)
	settings.set_value("ui_scale", 1.17)
	settings.set_value("quality", 9)
	settings.set_value("muted", true)
	settings.set_value("tap_reach", 58.0)
	check(is_equal_approx(settings.volumes["sfx"], 0.4) and settings.volumes["master"] == 1.0
		and settings.ui_scale == 1.15 and settings.quality == GameSettings.Quality.HIGH
		and settings.tap_reach == 60.0, "hodnoty se drží v povoleném rozsahu a krocích")
	settings.save()
	var again := GameSettings.load_from(path)
	check(again.load_status == SaveFile.Status.OK and again.to_dict() == settings.to_dict(),
		"nastavení se uloží a po novém spuštění načte beze změny")
	var odd := GameSettings.new()
	odd.from_dict({"audio": {"muted": "ano", "volumes": {"sfx": "hlasitě", "ui": -3,
		"ambient": NAN}}, "display": [], "controls": {"scroll_speed": 1.5},
		"budouci": {"neco": 1}})
	check(not odd.muted and odd.volumes["sfx"] == 1.0 and odd.volumes["ui"] == 0.0
		and odd.volumes["ambient"] == 1.0 and odd.scroll_speed == 1.6 and odd.stop_motion,
		"nesmyslné nebo neznámé položky se nahradí výchozími")
	# Novější verze formátu: načte se, co známe, a původní soubor zůstane vedle.
	SaveFile.write(path, {"audio": {"muted": true}, "novinka": {"x": 1}}, GameSettings.FORMAT + 1)
	var newer := GameSettings.load_from(path)
	check(newer.muted and FileAccess.file_exists(path + ".v%d" % (GameSettings.FORMAT + 1)),
		"soubor z novější verze se načte a jeho kopie se odloží")
	SaveFile.erase(path)
	# Starší soubor settings.cfg (jen ztlumení) se převezme.
	var legacy := ConfigFile.new()
	legacy.set_value("audio", "muted", true)
	legacy.save(_path("settings.cfg"))
	var migrated := GameSettings.load_from(path)
	check(migrated.muted, "ztlumení ze staršího settings.cfg se převezme")
	var memory := GameSettings.new()
	check(memory.save() == OK and not FileAccess.file_exists(""),
		"nastavení bez cesty (samostatná scéna, testy) se neukládá")


func _test_campaign() -> void:
	var list := Campaign.missions()
	var ids := {}
	var ok := list.size() == Campaign.count() and list.size() >= 6
	for i in list.size():
		var info: Dictionary = list[i]
		var level := (info["scene"] as PackedScene).instantiate() as LevelDefinition
		ok = ok and LevelValidator.is_valid_id(info["id"]) and not ids.has(info["id"]) \
			and info["id"] == level.level_id and info["title"] == level.title \
			and info["lemmings"] == level.lemming_count and info["required"] == level.save_required
		ids[info["id"]] = true
		level.free()
	check(ok, "každá mise má platný a jedinečný identifikátor, kampaň čte údaje přímo ze scén")
	check(Campaign.index_of("voda-lava-past") == 5 and Campaign.index_of("neexistuje") == -1,
		"mise se dohledá podle identifikátoru")


func _test_progress() -> void:
	var path := _path("progress.json")
	var progress := Progress.load_from(path)
	check(progress.is_unlocked(0) and not progress.is_unlocked(1)
		and progress.next_mission_index() == 0, "na začátku je otevřená jen první mise")
	check(progress.is_unlocked(5, true), "vývojová volba otevře všechny mise")
	progress.record_start("prvni-kroky")
	var lost := progress.record_result("prvni-kroky", 5, false, 900)
	check(not lost["first_win"] and not progress.is_unlocked(1) and progress.entry("prvni-kroky")
		["plays"] == 1, "prohra nic neodemkne, ale započítá pokus")
	var won := progress.record_result("prvni-kroky", 15, true, 2000)
	check(won["first_win"] and won["unlocked_next"] and progress.is_unlocked(1)
		and progress.next_mission_index() == 1, "první výhra splní misi a odemkne další")
	var better := progress.record_result("prvni-kroky", 18, true, 2500)
	var faster := progress.record_result("prvni-kroky", 18, true, 1800)
	var worse := progress.record_result("prvni-kroky", 12, true, 900)
	var entry := progress.entry("prvni-kroky")
	check(better["new_best"] and faster["new_best"] and not worse["new_best"]
		and entry["best_saved"] == 18 and entry["best_ticks"] == 1800 and entry["wins"] == 4,
		"rekord: víc zachráněných, při shodě rychlejší čas")
	progress.save()
	var again := Progress.load_from(path)
	check(again.load_status == SaveFile.Status.OK and again.to_dict() == progress.to_dict()
		and again.last_mission == "prvni-kroky", "postup se uloží a po novém spuštění načte")
	var odd := Progress.new()
	odd.from_dict({"missions": {"prvni-kroky": {"completed": "ano", "best_saved": -4,
		"plays": "x"}, "7": 5}, "last_mission": 3, "suspended": {"mission": "x"}})
	check(not odd.is_completed("prvni-kroky") and odd.entry("prvni-kroky")["best_saved"] == 0
		and odd.missions.size() == 1 and odd.last_mission == "" and not odd.has_suspended(),
		"poškozené položky postupu se vyčistí")
	again.reset()
	check(again.missions.is_empty() and not FileAccess.file_exists(path),
		"smazání postupu vymaže výsledky i soubor")


func _test_suspend() -> void:
	var path := _path("suspend.json")
	var scene := Campaign.SCENES[3]
	var sim := _mission_sim(scene)
	for _t in 140:
		sim.tick()
	var walkers := sim.lemmings.filter(func(l: Lemming) -> bool:
		return l.state == Lemming.State.WALKER)
	check(not walkers.is_empty() and sim.assign_skill(walkers[0], Lemming.Skill.BOMBER),
		"rozehraná mise 4: přidělen bombič")
	sim.change_release_rate(10)
	for _t in 200:
		sim.tick()
	var progress := Progress.new()
	progress.path = path
	progress.suspend("cesta-skrz-zed", sim)
	progress.save()
	var loaded := Progress.load_from(path)
	check(loaded.has_suspended() and loaded.suspended["tick"] == 340.0,
		"rozehraný pokus se uloží jako příkazy a tik")
	var fresh := _mission_sim(scene)
	check(loaded.restore_suspended(fresh) and fresh.tick_count == 340
		and snapshot(fresh) == snapshot(sim) and not loaded.has_suspended(),
		"obnova přehraje příkazy a stav je totožný (postavy, terén, počty)")
	var tampered := Progress.load_from(path)
	(tampered.suspended["commands"] as Array).clear()
	check(not tampered.restore_suspended(_mission_sim(scene)),
		"nesedící záznam (jiná verze levelu, poškození) se pozná podle otisku a zahodí")
	SaveFile.erase(path)


func _mission_sim(scene: PackedScene) -> LevelSim:
	var level := scene.instantiate() as LevelDefinition
	var sim := LevelSim.new(LevelLoader.build_spec(level), LevelLoader.build_mask(level))
	level.free()
	return sim
