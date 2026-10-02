class_name SplattingState
extends LemmingState
## Lumík spadl z moc velké výšky. Chvíli trvá animace, pak zmizí.


func enter(lem: Lemming, sim: LevelSim) -> void:
	sim.emit_event("splat", lem)


func tick(lem: Lemming, sim: LevelSim) -> void:
	if lem.state_ticks >= SimConst.SPLAT_TICKS:
		sim.remove_lemming(lem, false)
