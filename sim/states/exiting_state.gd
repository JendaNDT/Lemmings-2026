class_name ExitingState
extends LemmingState
## Lumík vchází do východu. Po krátké animaci je zachráněný.


func enter(lem: Lemming, sim: LevelSim) -> void:
	sim.emit_event("exit", lem)


func tick(lem: Lemming, sim: LevelSim) -> void:
	if lem.state_ticks >= SimConst.EXIT_TICKS:
		sim.remove_lemming(lem, true)
