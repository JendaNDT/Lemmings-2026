extends SimTest
## Systém obtížnosti: vzorec, pásma a referenční řešení všech misí kampaně.
## Změní-li se změřená obtížnost mise, je třeba aktualizovat docs/HERNI_DESIGN.md.


func _initialize() -> void:
	_test_formula()
	_test_reference_plans()
	_test_measured_mission()
	finish()


func _metrics(overrides: Dictionary) -> Dictionary:
	var m := {"lemmings": 10, "required": 5, "saved": 10, "ticks": 100,
		"time_limit_ticks": 1000, "windows": [200], "skills_used": 1, "skill_types": 1,
		"skills_available": 10, "hazard_kinds": 0}
	m.merge(overrides, true)
	return m


func _test_formula() -> void:
	var easy := _metrics({"skills_available": 100})
	var hard := _metrics({"saved": 5, "ticks": 950, "windows": [3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
		3, 3], "skills_used": 10, "skill_types": 5, "hazard_kinds": 3})
	check(LevelDifficulty.index(easy) == 0 and LevelDifficulty.index(hard) == 100,
		"index: velká rezerva a jeden pohodlný zásah = 0, nic navíc a těsné zásahy = 100")
	var total := 0
	for key: String in LevelDifficulty.WEIGHTS:
		total += int(LevelDifficulty.WEIGHTS[key])
	check(total == 100, "váhy složek dávají dohromady 100")
	var parts := LevelDifficulty.components(_metrics({"windows": [34, 68]}))
	check(parts["precision"] == 0.0 and is_equal_approx(parts["actions"], 0.5 / 11.0),
		"okno 2 s je pohodlné; zásah s oknem 4 s se počítá jako poloviční")
	check(LevelDifficulty.tier(0) == 1 and LevelDifficulty.tier(19) == 1
		and LevelDifficulty.tier(20) == 2 and LevelDifficulty.tier(59) == 3
		and LevelDifficulty.tier(80) == 5 and LevelDifficulty.tier_name(4) == "Těžká",
		"pásma: 0–19 Seznámení, 20–39 Lehká, 40–59 Střední, 60–79 Těžká, 80+ Mistrovská")


func _test_reference_plans() -> void:
	var missing: Array[String] = []
	var failed: Array[String] = []
	for info in Campaign.missions():
		var plan := ReferencePlans.plan_for(info["id"])
		if not plan.is_valid():
			missing.append(info["id"])
			continue
		var level := (info["scene"] as PackedScene).instantiate() as LevelDefinition
		var sim := LevelDifficulty.play(LevelLoader.build_spec(level),
			LevelLoader.build_mask(level), plan)
		level.free()
		if not (sim.finished and sim.is_won()):
			failed.append(info["id"])
	check(missing.is_empty() and failed.is_empty(),
		"každá mise kampaně má referenční řešení a vyhraje (chybí %s, selhalo %s)" % [
			str(missing), str(failed)])


func _test_measured_mission() -> void:
	var level := Campaign.SCENES[Campaign.index_of("cesta-skrz-zed")].instantiate() \
		as LevelDefinition
	var m := LevelDifficulty.measure(LevelLoader.build_spec(level), LevelLoader.build_mask(level),
		ReferencePlans.plan_for("cesta-skrz-zed"))
	level.free()
	check(m["won"] and m["saved"] == 3 and m["idle_saved"] == 0 and m["windows"] == [14, 137],
		"mise 4 změřena: 3/4, bez zásahu nikdo, okna zásahů 14 a 137 tiků")
	check(m["index"] == 54 and LevelDifficulty.tier_name(m["tier"]) == "Střední",
		"mise 4: index 54, pásmo Střední (jako v herním design dokumentu)")
