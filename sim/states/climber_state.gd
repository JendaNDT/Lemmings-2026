class_name ClimberState
extends LemmingState
## Lezec stoupá podél stěny. Strop ho odrazí; na okraji přejde do chůze.


func tick(lem: Lemming, sim: LevelSim) -> void:
	var nx := lem.x + lem.dir
	var mask := sim.mask
	if nx < 0 or nx >= mask.width or mask.is_solid(lem.x, lem.y - SimConst.LEMMING_HEIGHT):
		_detach(lem, sim)
		return
	if mask.is_solid(nx, lem.y - 1):
		lem.y -= 1
		return
	if mask.is_solid(nx, lem.y) and not mask.has_solid_in_rect(
			nx, lem.y - SimConst.LEMMING_HEIGHT, 1, SimConst.LEMMING_HEIGHT):
		lem.x = nx
		sim.set_state(lem, Lemming.State.WALKER)
	else:
		_detach(lem, sim)


func _detach(lem: Lemming, sim: LevelSim) -> void:
	lem.dir = -lem.dir
	sim.set_state(lem, Lemming.State.FALLER)
