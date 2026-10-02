class_name BuilderState
extends LemmingState
## Stavitel: pokládá cihly do schodů (každá o 1 px výš a 2 px dál).
## Když narazí na zeď, otočí se. Po poslední cihle pokrčí rameny a jde dál.


func enter(lem: Lemming, _sim: LevelSim) -> void:
	lem.bricks_left = SimConst.BUILDER_BRICKS


func tick(lem: Lemming, sim: LevelSim) -> void:
	var mask := sim.mask
	if not mask.is_solid(lem.x, lem.y):
		sim.set_state(lem, Lemming.State.FALLER)
		return
	if lem.state_ticks % SimConst.BUILDER_TICKS_PER_BRICK != SimConst.BUILDER_BRICK_PHASE:
		return

	# Polož cihlu o řádek výš, než lumík stojí, a vylez na ni.
	var row := lem.y - 1
	mask.add_brick_row(lem.x, lem.x + lem.dir * (SimConst.BRICK_WIDTH - 1), row)
	lem.y = row
	lem.bricks_left -= 1
	if lem.bricks_left < SimConst.BUILDER_WARNING_BRICKS:
		sim.emit_event("brick_warning", lem)
	else:
		sim.emit_event("brick", lem)

	# Posuň se o dva kroky dopředu, pokud tomu nebrání zeď nebo strop.
	for _i in 2:
		var nx := lem.x + lem.dir
		if (
			mask.is_solid(nx, row - 1)
			or mask.is_solid(nx, row - 2)
			or mask.is_solid(nx, row - SimConst.LEMMING_HEIGHT + 1)
		):
			lem.dir = -lem.dir
			sim.set_state(lem, Lemming.State.WALKER)
			return
		lem.x = nx

	if lem.bricks_left <= 0:
		sim.set_state(lem, Lemming.State.SHRUGGING)
