class_name DrowningState
extends LemmingState
## Lumík spadl nebo vešel do vody. Chvíli se topí a plácá se dál od břehu
## (jen dokud je před ním voda), pak zmizí (ztracen).


func enter(lem: Lemming, sim: LevelSim) -> void:
	lem.bomb_ticks = -1
	sim.emit_event("drown", lem)


func tick(lem: Lemming, sim: LevelSim) -> void:
	if lem.state_ticks >= SimConst.DROWN_TICKS:
		sim.emit_event("drowned", lem)
		sim.remove_lemming(lem, false)
		return
	if lem.state_ticks % SimConst.DROWN_DRIFT_TICKS == 0 \
			and sim.mask.hazard_at(lem.x + lem.dir, lem.y) == TerrainMask.Special.WATER:
		lem.x += lem.dir
