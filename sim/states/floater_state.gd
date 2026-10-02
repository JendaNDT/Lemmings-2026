class_name FloaterState
extends LemmingState
## Rozvinutý padák: pomalý pád a bezpečné přistání z libovolné výšky.


func tick(lem: Lemming, sim: LevelSim) -> void:
	for _step in SimConst.FLOATER_SPEED:
		if sim.mask.is_solid(lem.x, lem.y):
			sim.set_state(lem, Lemming.State.WALKER)
			return
		lem.y += 1
		lem.fall_distance += 1
