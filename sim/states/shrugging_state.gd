class_name ShruggingState
extends LemmingState
## Stavitel došel cihly: chvilku krčí rameny, pak pokračuje v chůzi.


func tick(lem: Lemming, sim: LevelSim) -> void:
	if not sim.mask.is_solid(lem.x, lem.y):
		sim.set_state(lem, Lemming.State.FALLER)
	elif lem.state_ticks >= SimConst.SHRUG_TICKS:
		sim.set_state(lem, Lemming.State.WALKER)
