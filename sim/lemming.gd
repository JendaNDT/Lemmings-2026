class_name Lemming
extends RefCounted
## Data jednoho lumíka. Žádná logika – tu mají stavy ve složce sim/states.
##
## Pozice (x, y) je pixel, na kterém lumík STOJÍ (první pevný pixel pod nohama).
## Při pádu je to pixel, kde právě jsou nohy.

## Co lumík právě dělá. Každý stav má svůj soubor v sim/states.
enum State {
	FALLER,
	WALKER,
	SPLATTING,
	EXITING,
	BLOCKER,
	BUILDER,
	SHRUGGING,
	BASHER,
	DIGGER,
	CLIMBER,
	FLOATER,
	MINER,
	DROWNING,
	BURNING,
}

## Dovednosti, které hráč přiděluje (pořadí jako v originále).
enum Skill {
	CLIMBER,
	FLOATER,
	BOMBER,
	BLOCKER,
	BUILDER,
	BASHER,
	MINER,
	DIGGER,
}

const SKILL_ORDER := [
	Skill.CLIMBER,
	Skill.FLOATER,
	Skill.BOMBER,
	Skill.BLOCKER,
	Skill.BUILDER,
	Skill.BASHER,
	Skill.MINER,
	Skill.DIGGER,
]

const SKILL_NAMES := {
	Skill.CLIMBER: "Lezec",
	Skill.FLOATER: "Padák",
	Skill.BOMBER: "Bombič",
	Skill.BLOCKER: "Blokař",
	Skill.BUILDER: "Stavitel",
	Skill.BASHER: "Razič",
	Skill.MINER: "Horník",
	Skill.DIGGER: "Kopáč",
}

## Stavy „na zemi při práci“ – jen z nich jde přidělit pracovní dovednost.
const WORKING_STATES := [
	State.WALKER,
	State.SHRUGGING,
	State.BUILDER,
	State.BASHER,
	State.DIGGER,
	State.MINER,
]

var id := 0
var x := 0
var y := 0
## Pozice z minulého tiku – grafika mezi nimi plynule dopočítává pohyb.
var prev_x := 0
var prev_y := 0
## Směr chůze: 1 = doprava, -1 = doleva.
var dir := 1
var state: State = State.FALLER
## Kolik tiků už lumík v aktuálním stavu je.
var state_ticks := 0
var fall_distance := 0
var bricks_left := 0
## Trvalé vlastnosti přežijí změnu pracovní činnosti i pád.
var can_climb := false
var has_floater := false
## -1 = bez bomby; zbývající čas se mění výhradně v pevných ticích.
var bomb_ticks := -1
## Lumík už ze hry zmizel (zachráněn nebo mrtvý).
var removed := false
var saved := false


func is_active() -> bool:
	return not removed
