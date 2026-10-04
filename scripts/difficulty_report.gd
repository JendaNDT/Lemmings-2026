extends SceneTree
## Změří obtížnost všech misí kampaně z jejich referenčních řešení
## (ReferencePlans) a vypíše tabulku pro herní design dokument.
##
## Spuštění:
##   godot --headless --path . --script res://scripts/difficulty_report.gd \
##     -- [--out=build/difficulty.json]


func _initialize() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	var report := []
	print("| # | Mise | Lumíci | Cíl | Ref. | Bez zásahu | Zásahy | Druhy | Kusy | Čas | "
		+ "Okno (tiky) | Nebezpečí | Index | Pásmo |")
	print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	var ok := true
	for i in Campaign.count():
		var info := Campaign.mission(i)
		var plan := ReferencePlans.plan_for(info["id"])
		if not plan.is_valid():
			print("| %d | %s | – | – | bez referenčního řešení |" % [i + 1, info["title"]])
			ok = false
			continue
		var level := (info["scene"] as PackedScene).instantiate() as LevelDefinition
		var spec := LevelLoader.build_spec(level)
		var mask := LevelLoader.build_mask(level)
		level.free()
		var m := LevelDifficulty.measure(spec, mask, plan)
		ok = ok and m["won"]
		print("| %d | %s | %d | %d | %d | %d | %d | %d | %d / %d | %d %% | %d (%s) | %d | %d | %s |" % [
			i + 1, info["title"], m["lemmings"], m["required"], m["saved"], m["idle_saved"],
			m["actions"], m["skill_types"], m["skills_used"], m["skills_available"],
			roundi(100.0 * m["ticks"] / m["time_limit_ticks"]), m["window_ticks"],
			", ".join(m["windows"].map(func(w: int) -> String: return str(w))),
			m["hazard_kinds"], m["index"], LevelDifficulty.tier_name(m["tier"])])
		m.erase("log")
		m["id"] = info["id"]
		m["components"] = LevelDifficulty.components(m)
		report.append(m)
	if not out.is_empty():
		var file := FileAccess.open(out, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	print("DIFFICULTY ", "OK" if ok else "CHYBA")
	quit(0 if ok else 1)
