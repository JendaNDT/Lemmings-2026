class_name DiggerState
extends LemmingState
## Kopáč: kope svislou díru dolů. Skončí, když prokope na volný prostor
## (začne padat), nebo narazí na ocel (jde dál pěšky).


func tick(lem: Lemming, sim: LevelSim) -> void:
	var mask := sim.mask
	if lem.state_ticks % SimConst.DIGGER_TICKS_PER_ROW != 0:
		return

	var x0 := lem.x - SimConst.DIGGER_HALF_WIDTH
	var w := SimConst.DIGGER_HALF_WIDTH * 2 + 1
	if mask.has_steel_in_rect(x0, lem.y, w, 1):
		sim.emit_event("steel", lem)
		sim.set_state(lem, Lemming.State.WALKER)
		return

	if mask.erase_rect(x0, lem.y, w, 1):
		sim.emit_event("dig", lem)
	lem.y += 1
	if not mask.is_solid(lem.x, lem.y):
		sim.set_state(lem, Lemming.State.FALLER)
