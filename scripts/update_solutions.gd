extends SceneTree
## Zapíše do každé mise kampaně záznam jejího referenčního řešení
## (tests/reference_plans.gd) jako vlastnost `solution` – z něj hra přehrává
## „Ukázku řešení“. Spustit po každé změně misí nebo referenčních plánů;
## test_difficulty hlídá, že záznamy odpovídají plánům.
##
## Spuštění:
##   godot --headless --path . --script res://scripts/update_solutions.gd


func _initialize() -> void:
	var failed := false
	for info in Campaign.missions():
		var plan := ReferencePlans.plan_for(info["id"])
		var scene: PackedScene = info["scene"]
		if not plan.is_valid():
			print("CHYBA %s: chybí referenční plán" % info["id"])
			failed = true
			continue
		var level := scene.instantiate() as LevelDefinition
		var sim := LevelDifficulty.play(LevelLoader.build_spec(level), LevelLoader.build_mask(level),
			plan)
		level.free()
		var numbers := PackedStringArray()
		for command in sim.replay_log:
			for key in ["tick", "kind", "target", "value"]:
				numbers.append(str(int(command[key])))
		var line := "solution = PackedInt32Array(%s)" % ", ".join(numbers)
		if not _write(scene.resource_path, line):
			print("CHYBA %s: nepodařilo se zapsat %s" % [info["id"], scene.resource_path])
			failed = true
			continue
		print("%s: %d příkazů, zachráněno %d" % [info["id"], sim.replay_log.size(), sim.saved])
	print("SOLUTIONS ", "CHYBA" if failed else "OK")
	quit(1 if failed else 0)


## Nahradí (nebo doplní) řádek `solution = …` ve vlastnostech kořenového uzlu.
func _write(path: String, line: String) -> bool:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return false
	var lines := text.split("\n")
	var root := -1
	for i in lines.size():
		if lines[i].begins_with("[node ") and not lines[i].contains("parent="):
			root = i
			break
	if root < 0:
		return false
	var end := root + 1
	while end < lines.size() and not lines[end].is_empty():
		end += 1
	var out := PackedStringArray()
	for i in lines.size():
		if i > root and i < end and lines[i].begins_with("solution = "):
			continue
		if i == end:
			out.append(line)
		out.append(lines[i])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string("\n".join(out))
	return true
