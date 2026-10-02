class_name BasherState
extends LemmingState
## Razič: prokopává vodorovný tunel. Skončí, když už před ním nic není.
## Když narazí na ocel, otočí se a jde pryč.


func tick(lem: Lemming, sim: LevelSim) -> void:
	var mask := sim.mask
	if not mask.is_solid(lem.x, lem.y):
		sim.set_state(lem, Lemming.State.FALLER)
		return
	if lem.state_ticks % SimConst.BASHER_TICKS_PER_STEP != 0:
		return

	var top := lem.y - SimConst.LEMMING_HEIGHT
	var height := SimConst.LEMMING_HEIGHT

	# Ocel (nebo okraj levelu) v cestě → konec, otočka.
	var reach_x := lem.x + lem.dir * SimConst.BASHER_REACH
	var hit_x := mini(lem.x + lem.dir, reach_x)
	var hit_w := SimConst.BASHER_REACH
	if reach_x < 0 or reach_x >= mask.width or mask.has_steel_in_rect(hit_x, top, hit_w, height):
		sim.emit_event("steel", lem)
		lem.dir = -lem.dir
		sim.set_state(lem, Lemming.State.WALKER)
		return

	# Je před námi ještě co kopat? Pokud ne, razič se vrací k chůzi.
	var look_x := lem.x + lem.dir * SimConst.BASHER_LOOKAHEAD
	var look_from := mini(lem.x + lem.dir, look_x)
	if not mask.has_solid_in_rect(look_from, top, SimConst.BASHER_LOOKAHEAD, height):
		sim.set_state(lem, Lemming.State.WALKER)
		return

	if mask.erase_rect(hit_x, top, hit_w, height):
		sim.emit_event("bash", lem)
	lem.x += lem.dir
