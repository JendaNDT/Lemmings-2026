class_name WalkerState
extends LemmingState
## Chodec: jde rovně, vyleze na malé schody, u zdi se otočí, z okraje spadne.


func tick(lem: Lemming, sim: LevelSim) -> void:
	if sim.is_blocked(lem):
		lem.dir = -lem.dir
	var mask := sim.mask
	var nx := lem.x + lem.dir

	if mask.is_solid(nx, lem.y):
		# Před námi je terén. Jak vysoko? Malý schod vylezeme, vysoká zeď = otočka.
		var up := 0
		while up <= SimConst.MAX_STEP_UP and mask.is_solid(nx, lem.y - up - 1):
			up += 1
		if up > SimConst.MAX_STEP_UP:
			if lem.can_climb and nx >= 0 and nx < mask.width:
				sim.set_state(lem, Lemming.State.CLIMBER)
			else:
				lem.dir = -lem.dir
			return
		lem.x = nx
		lem.y -= up
		return

	# Před námi je díra. Malý schod dolů sejdeme, jinak začneme padat.
	var down := 1
	while down <= SimConst.MAX_STEP_DOWN and not mask.is_solid(nx, lem.y + down):
		down += 1
	lem.x = nx
	if down <= SimConst.MAX_STEP_DOWN:
		lem.y += down
	else:
		lem.y += SimConst.MAX_STEP_DOWN
		sim.set_state(lem, Lemming.State.FALLER)
		lem.fall_distance = SimConst.MAX_STEP_DOWN
