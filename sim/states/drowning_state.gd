class_name DrowningState
extends LemmingState
## Lumík spadl nebo vešel do vody. Chvíli se topí, pak zmizí (ztracen).


func enter(lem: Lemming, sim: LevelSim) -> void:
	lem.bomb_ticks = -1
	sim.emit_event("drown", lem)


func tick(lem: Lemming, sim: LevelSim) -> void:
	if lem.state_ticks >= SimConst.DROWN_TICKS:
		sim.remove_lemming(lem, false)
