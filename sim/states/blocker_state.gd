class_name BlockerState
extends LemmingState
## Blokař: stojí s rozpaženýma rukama a ostatní se od něj otáčejí.
## Samotné otáčení řeší LevelSim.is_blocked(), tady jen hlídáme zem pod nohama.


func tick(lem: Lemming, sim: LevelSim) -> void:
	if not sim.mask.is_solid(lem.x, lem.y):
		sim.set_state(lem, Lemming.State.FALLER)
