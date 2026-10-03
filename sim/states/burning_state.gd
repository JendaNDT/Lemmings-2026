class_name BurningState
extends LemmingState
## Lumík se dotkl lávy. Krátce hoří, pak zmizí (ztracen).


func enter(lem: Lemming, sim: LevelSim) -> void:
	lem.bomb_ticks = -1
	sim.emit_event("burn", lem)


func tick(lem: Lemming, sim: LevelSim) -> void:
	if lem.state_ticks >= SimConst.BURN_TICKS:
		sim.remove_lemming(lem, false)
