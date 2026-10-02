class_name MinerState
extends LemmingState
## Šikmý tunel se svažuje o jeden pixel na dva kroky; ocel se nenaruší.


func tick(lem: Lemming, sim: LevelSim) -> void:
	var mask := sim.mask
	if not mask.is_solid(lem.x, lem.y):
		sim.set_state(lem, Lemming.State.FALLER)
		return
	if lem.state_ticks % SimConst.MINER_TICKS_PER_STEP != 0:
		return
	var front := lem.x + lem.dir * SimConst.MINER_REACH
	var back := lem.x - lem.dir * 2
	var x0 := mini(front, back)
	var width := absi(front - back) + 1
	var top := lem.y - SimConst.LEMMING_HEIGHT
	if front < 0 or front >= mask.width or mask.has_steel_in_rect(
			x0, top, width, SimConst.LEMMING_HEIGHT + 1):
		sim.emit_event("steel", lem)
		lem.dir = -lem.dir
		sim.set_state(lem, Lemming.State.WALKER)
		return
	if mask.erase_rect(x0, top, width, SimConst.LEMMING_HEIGHT + 1):
		sim.emit_event("mine", lem)
	lem.x += lem.dir * SimConst.MINER_STEP_X
	lem.y += 1
	if not mask.is_solid(lem.x, lem.y):
		sim.set_state(lem, Lemming.State.FALLER)
