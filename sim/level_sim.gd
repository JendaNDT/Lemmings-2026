class_name LevelSim
extends RefCounted
## Srdce hry: celá logika jednoho rozehraného levelu.
##
## Pravidla:
## - Žádné uzly, žádná grafika, žádný Input, žádná náhoda, žádný reálný čas.
## - Čas se posouvá jen voláním tick() – vždy o jeden pevný krok.
## - Příkazy se provedou mezi tiky, okamžitě i během pauzy, v pořadí přijetí.
## - Stejný level + stejné příkazy ve stejných ticích = vždy stejný výsledek
##   (díky tomu půjde udělat replay, přetáčení času a ověřování řešení).

enum Command { ASSIGN_SKILL, RELEASE_RATE }

var spec: LevelSpec
var mask: TerrainMask
var lemmings: Array[Lemming] = []
var tick_count := 0
var release_rate := 50
## Zbývající dovednosti: Lemming.Skill → počet.
var skills := {}
var spawned := 0
var saved := 0
var lost := 0
var finished := false
## Kopie přijatých příkazů; pořadí v poli rozhoduje i uvnitř stejného tiku.
var replay_log: Array[Dictionary]:
	get:
		return _replay_log.duplicate(true)

var _replay_log: Array[Dictionary] = []
var _minimum_release_rate := SimConst.MIN_RELEASE_RATE
var _states := {}
var _events: Array[Dictionary] = []
var _next_spawn_tick := 0
var _next_hatch := 0


func _init(level_spec: LevelSpec, terrain: TerrainMask) -> void:
	spec = level_spec
	mask = terrain
	release_rate = clampi(spec.release_rate, SimConst.MIN_RELEASE_RATE, SimConst.MAX_RELEASE_RATE)
	_minimum_release_rate = release_rate
	skills = spec.skills.duplicate()
	_next_spawn_tick = SimConst.HATCH_OPEN_TICKS
	_states = {
		Lemming.State.FALLER: FallerState.new(),
		Lemming.State.WALKER: WalkerState.new(),
		Lemming.State.SPLATTING: SplattingState.new(),
		Lemming.State.EXITING: ExitingState.new(),
		Lemming.State.BLOCKER: BlockerState.new(),
		Lemming.State.BUILDER: BuilderState.new(),
		Lemming.State.SHRUGGING: ShruggingState.new(),
		Lemming.State.BASHER: BasherState.new(),
		Lemming.State.DIGGER: DiggerState.new(),
	}


## Jeden krok logiky.
func tick() -> void:
	if finished:
		return
	tick_count += 1
	_spawn_if_due()
	for lem in lemmings:
		if lem.removed:
			continue
		lem.prev_x = lem.x
		lem.prev_y = lem.y
		lem.state_ticks += 1
		_states[lem.state].tick(lem, self)
		if lem.removed:
			continue
		if lem.y >= mask.height:
			emit_event("fell_out", lem)
			remove_lemming(lem, false)
		else:
			_check_exit(lem)
	_update_finished()


func set_state(lem: Lemming, state: Lemming.State) -> void:
	lem.state = state
	lem.state_ticks = 0
	_states[state].enter(lem, self)


func remove_lemming(lem: Lemming, was_saved: bool) -> void:
	if lem.removed:
		return
	lem.removed = true
	lem.saved = was_saved
	if was_saved:
		saved += 1
	else:
		lost += 1


# --- Přidělování dovedností ----------------------------------------------------

func can_assign(lem: Lemming, skill: int) -> bool:
	if lem == null or lem.removed or finished:
		return false
	if lem.id < 0 or lem.id >= lemmings.size() or lemmings[lem.id] != lem:
		return false
	if int(skills.get(skill, 0)) <= 0:
		return false
	var target := _state_for_skill(skill)
	if target < 0:
		return false  # dovednost zatím není naprogramovaná
	return lem.state in Lemming.WORKING_STATES and lem.state != target


func assign_skill(lem: Lemming, skill: int) -> bool:
	if not can_assign(lem, skill):
		return false
	return apply_command(Command.ASSIGN_SKILL, lem.id, skill)


## Jediný vstup hráčových příkazů. Neplatný příkaz ani změna bez účinku se nezapíše.
## Tik N znamená „po dokončení tiku N, před tikem N+1“; nula je před startem.
func apply_command(kind: int, target: int, value: int) -> bool:
	if finished:
		return false
	match kind:
		Command.ASSIGN_SKILL:
			if not _assign_skill_command(target, value):
				return false
		Command.RELEASE_RATE:
			if target != -1:
				return false
			value = clampi(value, _minimum_release_rate, SimConst.MAX_RELEASE_RATE)
			if value == release_rate:
				return false
			release_rate = value
		_:
			return false
	_replay_log.append({"tick": tick_count, "kind": kind, "target": target, "value": value})
	return true


func _assign_skill_command(target: int, skill: int) -> bool:
	if target < 0 or target >= lemmings.size():
		return false
	var lem := lemmings[target]
	if not can_assign(lem, skill):
		return false
	skills[skill] = int(skills[skill]) - 1
	set_state(lem, _state_for_skill(skill) as Lemming.State)
	emit_event("assign", lem)
	return true


func _state_for_skill(skill: int) -> int:
	match skill:
		Lemming.Skill.BLOCKER:
			return Lemming.State.BLOCKER
		Lemming.Skill.BUILDER:
			return Lemming.State.BUILDER
		Lemming.Skill.BASHER:
			return Lemming.State.BASHER
		Lemming.Skill.DIGGER:
			return Lemming.State.DIGGER
	return -1


## Najde lumíka pod kurzorem. Přednost mají ti, kterým jde vybraná dovednost dát.
func find_lemming_at(point: Vector2, skill: int) -> Lemming:
	var best: Lemming = null
	var best_score := INF
	for lem in lemmings:
		if lem.removed:
			continue
		var dx := absf(point.x - (lem.x + 0.5))
		if dx > 4.0:
			continue
		if point.y < lem.y - SimConst.LEMMING_HEIGHT - 1.5 or point.y > lem.y + 1.5:
			continue
		var score := dx + absf(point.y - (lem.y - 5.0)) * 0.5
		if skill >= 0 and not can_assign(lem, skill):
			score += 100.0
		if score < best_score:
			best_score = score
			best = lem
	return best


# --- Pomocné dotazy pro stavy ---------------------------------------------------

## Narazil lumík na pole blokaře? (Jen při chůzi směrem k blokaři.)
func is_blocked(lem: Lemming) -> bool:
	for other in lemmings:
		if other == lem or other.removed or other.state != Lemming.State.BLOCKER:
			continue
		if absi(lem.y - other.y) > SimConst.BLOCKER_FIELD_HEIGHT:
			continue
		var dx := other.x - lem.x
		if lem.dir > 0 and dx > 0 and dx <= SimConst.BLOCKER_FIELD:
			return true
		if lem.dir < 0 and dx < 0 and -dx <= SimConst.BLOCKER_FIELD:
			return true
	return false


# --- Události pro grafiku a zvuk -----------------------------------------------

## Simulace jen „hlásí“, co se stalo. Grafika a zvuk si to vyzvednou a zareagují.
func emit_event(type: String, lem: Lemming) -> void:
	_events.append({"type": type, "x": lem.x, "y": lem.y, "dir": lem.dir, "id": lem.id})


func take_events() -> Array[Dictionary]:
	var out := _events
	_events = []
	return out


# --- Stav levelu ----------------------------------------------------------------

func change_release_rate(delta: int) -> bool:
	return apply_command(Command.RELEASE_RATE, -1, release_rate + delta)


func spawn_interval_ticks() -> int:
	return 4 + floori((SimConst.MAX_RELEASE_RATE - release_rate) / 2.0)


func lemmings_out() -> int:
	return spawned - saved - lost


func lemmings_waiting() -> int:
	return spec.lemming_count - spawned


func time_left_ticks() -> int:
	return maxi(spec.time_limit_seconds * SimConst.TICKS_PER_SECOND - tick_count, 0)


func time_left_seconds() -> int:
	return ceili(time_left_ticks() / float(SimConst.TICKS_PER_SECOND))


func is_won() -> bool:
	return saved >= spec.save_required


func _spawn_if_due() -> void:
	if spawned >= spec.lemming_count or spec.hatches.is_empty():
		return
	if tick_count < _next_spawn_tick:
		return
	var hatch: Vector2i = spec.hatches[_next_hatch % spec.hatches.size()]
	_next_hatch += 1
	var lem := Lemming.new()
	lem.id = spawned
	lem.x = hatch.x
	lem.y = hatch.y
	lem.prev_x = hatch.x
	lem.prev_y = hatch.y
	lem.dir = 1
	lemmings.append(lem)
	spawned += 1
	set_state(lem, Lemming.State.FALLER)
	emit_event("spawn", lem)
	_next_spawn_tick = tick_count + spawn_interval_ticks()


func _check_exit(lem: Lemming) -> void:
	if lem.state in [Lemming.State.BLOCKER, Lemming.State.SPLATTING, Lemming.State.EXITING]:
		return
	for e in spec.exits:
		var near_x := absi(lem.x - e.x) <= SimConst.EXIT_REACH_X
		var near_y := lem.y <= e.y + 1 and lem.y >= e.y - SimConst.EXIT_REACH_Y
		if near_x and near_y:
			lem.x = e.x
			set_state(lem, Lemming.State.EXITING)
			return


func _update_finished() -> void:
	if time_left_ticks() <= 0:
		finished = true
		return
	if spawned < spec.lemming_count:
		return
	# Konec, když už nezbývá nikdo, kdo by se mohl hýbat (blokaři se nepočítají).
	for lem in lemmings:
		if not lem.removed and lem.state != Lemming.State.BLOCKER:
			return
	finished = true
