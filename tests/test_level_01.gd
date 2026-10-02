extends SceneTree
## Automatický test simulace – běží bez grafiky, za pár sekund.
## Díky oddělení logiky od grafiky jde celý level „odehrát“ v kódu.
##
## Spuštění (projekt musí být aspoň jednou otevřený v editoru):
##   godot --headless --path . --script res://tests/test_level_01.gd


func _initialize() -> void:
	var ok := true
	ok = _test_nobody_dies_without_action() and ok
	ok = _test_solution() and ok
	print("VÝSLEDEK: ", "OK" if ok else "CHYBA")
	quit(0 if ok else 1)


func _make_sim() -> LevelSim:
	var scene := load("res://levels/level_01.tscn") as PackedScene
	var level := scene.instantiate() as LevelDefinition
	var sim := LevelSim.new(LevelLoader.build_spec(level), LevelLoader.build_mask(level))
	level.free()
	return sim


## Bez zásahu hráče lumíci jen chodí sem a tam mezi zdmi a nikdo neumře.
func _test_nobody_dies_without_action() -> bool:
	var sim := _make_sim()
	for _t in 90 * SimConst.TICKS_PER_SECOND:
		sim.tick()
	var ok := sim.spawned == sim.spec.lemming_count and sim.lost == 0 and sim.saved == 0
	var detail := "venku %d, ztraceno %d" % [sim.lemmings_out(), sim.lost]
	return _check("bez zásahu nikdo neumře", ok, detail)


## Razič prorazí sloup, stavitel postaví schody na útes, kopáč prokope do jeskyně.
func _test_solution() -> bool:
	var sim := _make_sim()
	var bashed := false
	var built := false
	var dug := false
	for _t in 300 * SimConst.TICKS_PER_SECOND:
		sim.tick()
		for lem in sim.lemmings:
			if lem.removed or lem.state != Lemming.State.WALKER:
				continue
			if not bashed and lem.dir == 1 and lem.x >= 170 and lem.x <= 175:
				bashed = sim.assign_skill(lem, Lemming.Skill.BASHER)
			elif bashed and not built and lem.dir == 1 and lem.x >= 280 and lem.x <= 284:
				built = sim.assign_skill(lem, Lemming.Skill.BUILDER)
			elif built and not dug and lem.y <= 58 and lem.x >= 330 and lem.x <= 360:
				dug = sim.assign_skill(lem, Lemming.Skill.DIGGER)
		if sim.finished:
			break
	var ok := sim.finished and sim.is_won()
	var detail := "zachráněno %d z %d" % [sim.saved, sim.spec.lemming_count]
	return _check("level 1 jde vyřešit", ok, detail)


func _check(test_name: String, ok: bool, detail: String) -> bool:
	print("[%s] %s (%s)" % ["OK" if ok else "CHYBA", test_name, detail])
	return ok
