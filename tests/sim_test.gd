class_name SimTest
extends SceneTree
## Sdílené testovací přípravky, bez závislosti na grafice či lokální cestě.

var checks := 0
var failures := 0


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("[%s] %s" % ["OK" if condition else "CHYBA", description])


func finish() -> void:
	print("VÝSLEDEK: %s (%d kontrol, %d chyb)" % [
		"OK" if failures == 0 and checks > 0 else "CHYBA", checks, failures
	])
	quit(0 if failures == 0 and checks > 0 else 1)


func fixture(count: int = 100) -> LevelSim:
	var spec := LevelSpec.new()
	spec.width = 160
	spec.height = 128
	spec.lemming_count = count
	spec.save_required = 1
	for skill in Lemming.SKILL_ORDER:
		spec.skills[skill] = 20
	var mask := TerrainMask.new(spec.width, spec.height)
	paint_rect(mask, Rect2i(0, 80, 160, 48))
	return LevelSim.new(spec, mask)


func paint_rect(
	mask: TerrainMask, rect: Rect2i, kind: TerrainMask.Kind = TerrainMask.Kind.DIRT
) -> void:
	mask.paint_polygon(PackedVector2Array([
		Vector2(rect.position), Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end), Vector2(rect.position.x, rect.end.y),
	]), kind)


func add_lemming(sim: LevelSim, x: int = 60, y: int = 80) -> Lemming:
	var lem := Lemming.new()
	lem.id = sim.lemmings.size()
	lem.x = x
	lem.y = y
	lem.prev_x = x
	lem.prev_y = y
	sim.lemmings.append(lem)
	sim.spawned += 1
	sim.set_state(lem, Lemming.State.WALKER)
	return lem


func advance(sim: LevelSim, ticks: int) -> void:
	for _tick in ticks:
		sim.tick()


func level_one() -> LevelSim:
	var scene := load("res://levels/level_01.tscn") as PackedScene
	var level := scene.instantiate() as LevelDefinition
	var sim := LevelSim.new(LevelLoader.build_spec(level), LevelLoader.build_mask(level))
	level.free()
	return sim


## Celý pozorovatelný stav, včetně pixelů terénu a všech polí lumíků.
func snapshot(sim: LevelSim) -> Array:
	var actors: Array = []
	for lem in sim.lemmings:
		actors.append([
			lem.id, lem.x, lem.y, lem.prev_x, lem.prev_y, lem.dir, lem.state,
			lem.state_ticks, lem.fall_distance, lem.bricks_left, lem.removed, lem.saved,
			lem.can_climb, lem.has_floater, lem.bomb_ticks,
		])
	return [
		sim.tick_count, sim.spawned, sim.saved, sim.lost, sim.finished, sim.release_rate,
		sim.skills.duplicate(), actors, sim.mask.data.duplicate(), sim.mask.version,
		sim.replay_log, sim.time_left_ticks(), sim.is_won(), sim.nuking,
	]
