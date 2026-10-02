class_name FallerState
extends LemmingState
## Padající lumík. Po dopadu buď jde dál, nebo se (z velké výšky) splácne.


func enter(lem: Lemming, _sim: LevelSim) -> void:
	lem.fall_distance = 0


func tick(lem: Lemming, sim: LevelSim) -> void:
	for _i in SimConst.FALL_SPEED:
		if sim.mask.is_solid(lem.x, lem.y):
			if lem.fall_distance > SimConst.SAFE_FALL_DISTANCE:
				sim.set_state(lem, Lemming.State.SPLATTING)
			else:
				sim.set_state(lem, Lemming.State.WALKER)
			return
		lem.y += 1
		lem.fall_distance += 1
