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
## - Pořadí v jednom tiku pro každého lumíka: odpočet bomby → činnost stavu →
##   pád pod level → láva → voda → past → východ. Lumíci se zpracují v pořadí
##   vypuštění; past sežere jen prvního, ostatní projdou, než se znovu nabije.

enum Command { ASSIGN_SKILL, RELEASE_RATE, NUKE }
## Stavy, ze kterých už nevede cesta zpět: nepřidělují se dovednosti,
## nezapaluje se bomba, nekontroluje se východ ani nebezpečí.
const DYING_STATES := [
	Lemming.State.SPLATTING, Lemming.State.EXITING,
	Lemming.State.DROWNING, Lemming.State.BURNING,
]

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
var nuking := false
## Pasti: tik, od kterého je past znovu připravená, a tik posledního sežrání.
var trap_ready := PackedInt32Array()
var trap_fired := PackedInt32Array()
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
var _next_nuke_tick := 0


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
		Lemming.State.CLIMBER: ClimberState.new(),
		Lemming.State.FLOATER: FloaterState.new(),
		Lemming.State.MINER: MinerState.new(),
		Lemming.State.DROWNING: DrowningState.new(),
		Lemming.State.BURNING: BurningState.new(),
	}
	trap_ready.resize(spec.traps.size())
	trap_ready.fill(0)
	trap_fired.resize(spec.traps.size())
	trap_fired.fill(-1)


## Nezávislá kopie celého stavu – záložka pro přetáčení času. Zadání mise
## (spec) se nemění a sdílí se; stavy lumíků nemají vlastní data.
func snapshot() -> LevelSim:
	var terrain := TerrainMask.new(mask.width, mask.height)
	terrain.data = mask.data.duplicate()
	var copy := LevelSim.new(spec, terrain)
	for lem in lemmings:
		copy.lemmings.append(lem.duplicate_lemming())
	copy.tick_count = tick_count
	copy.release_rate = release_rate
	copy.skills = skills.duplicate()
	copy.spawned = spawned
	copy.saved = saved
	copy.lost = lost
	copy.finished = finished
	copy.nuking = nuking
	copy.trap_ready = trap_ready.duplicate()
	copy.trap_fired = trap_fired.duplicate()
	copy._replay_log = _replay_log.duplicate(true)
	copy._minimum_release_rate = _minimum_release_rate
	copy._next_spawn_tick = _next_spawn_tick
	copy._next_hatch = _next_hatch
	copy._next_nuke_tick = _next_nuke_tick
	return copy


## Jeden krok logiky.
func tick() -> void:
	if finished:
		return
	tick_count += 1
	_spawn_if_due()
	_arm_next_nuke()
	for lem in lemmings:
		if lem.removed:
			continue
		lem.prev_x = lem.x
		lem.prev_y = lem.y
		if lem.bomb_ticks > 0:
			lem.bomb_ticks -= 1
			if lem.bomb_ticks == 0:
				_explode(lem)
				continue
		lem.state_ticks += 1
		_states[lem.state].tick(lem, self)
		if lem.removed:
			continue
		if lem.y >= mask.height:
			emit_event("fell_out", lem)
			remove_lemming(lem, false)
		elif not _check_hazards(lem):
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
	lem.bomb_ticks = -1
	lem.saved = was_saved
	if was_saved:
		saved += 1
	else:
		lost += 1


# --- Přidělování dovedností ----------------------------------------------------

func can_assign(lem: Lemming, skill: int) -> bool:
	if lem == null or lem.removed or finished:
		return false
	if (lem.id < 0 or lem.id >= lemmings.size() or lemmings[lem.id] != lem
			or int(skills.get(skill, 0)) <= 0
			or lem.state in DYING_STATES):
		return false
	match skill:
		Lemming.Skill.CLIMBER:
			return not lem.can_climb
		Lemming.Skill.FLOATER:
			return not lem.has_floater
		Lemming.Skill.BOMBER:
			return lem.bomb_ticks < 0
	var target := _state_for_skill(skill)
	return target >= 0 and lem.state in Lemming.WORKING_STATES and lem.state != target


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
			value = clampi(value, _minimum_release_rate, SimConst.MAX_RELEASE_RATE)
			if target != -1 or value == release_rate:
				return false
			release_rate = value
		Command.NUKE:
			if target != -1 or value != 0 or nuking:
				return false
			nuking = true
			_next_nuke_tick = tick_count + 1
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
	match skill:
		Lemming.Skill.CLIMBER:
			lem.can_climb = true
		Lemming.Skill.FLOATER:
			lem.has_floater = true
		Lemming.Skill.BOMBER:
			lem.bomb_ticks = SimConst.BOMB_TICKS
		_:
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
		Lemming.Skill.MINER:
			return Lemming.State.MINER
	return -1


func start_nuke() -> bool:
	return apply_command(Command.NUKE, -1, 0)


func _arm_next_nuke() -> void:
	if not nuking or tick_count < _next_nuke_tick:
		return
	for lem in lemmings:
		if lem.removed or lem.bomb_ticks >= 0 or lem.state in DYING_STATES:
			continue
		lem.bomb_ticks = SimConst.BOMB_TICKS
		emit_event("assign", lem)
		_next_nuke_tick = tick_count + SimConst.NUKE_INTERVAL
		return


func _explode(lem: Lemming) -> void:
	mask.erase_circle(lem.x, lem.y - SimConst.LEMMING_HEIGHT / 2, SimConst.BOMB_RADIUS)
	emit_event("explode", lem)
	remove_lemming(lem, false)


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
## `value` nese doplňující číslo (např. index pasti).
func emit_event(type: String, lem: Lemming, value: int = 0) -> void:
	_events.append({"type": type, "x": lem.x, "y": lem.y, "dir": lem.dir, "id": lem.id,
		"value": value})


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
	return 0 if nuking else spec.lemming_count - spawned


func time_left_ticks() -> int:
	return maxi(spec.time_limit_seconds * SimConst.TICKS_PER_SECOND - tick_count, 0)


func time_left_seconds() -> int:
	return ceili(time_left_ticks() / float(SimConst.TICKS_PER_SECOND))


func is_won() -> bool:
	return saved >= spec.save_required


func _spawn_if_due() -> void:
	if nuking or spawned >= spec.lemming_count or spec.hatches.is_empty():
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


## Láva, voda a pasti. Kontroluje se svislý úsek, kterým lumík v tomto tiku
## prošel (pád až 3 px za tik nepřeskočí tenkou hladinu). Vrací true, když
## lumíka zasáhly – pak se už nekontroluje východ.
func _check_hazards(lem: Lemming) -> bool:
	if lem.state in DYING_STATES:
		return false
	var top := mini(lem.prev_y, lem.y) - 1
	var bottom := maxi(lem.prev_y, lem.y)
	var water := false
	for y in range(top, bottom + 1):
		var special := mask.hazard_at(lem.x, y)
		if special == TerrainMask.Special.LAVA:
			set_state(lem, Lemming.State.BURNING)
			return true
		water = water or special == TerrainMask.Special.WATER
	if water:
		set_state(lem, Lemming.State.DROWNING)
		return true
	var feet := Vector2i(lem.x, lem.y - 1)
	for index in spec.traps.size():
		var rect: Rect2i = spec.traps[index]["rect"]
		if tick_count < trap_ready[index] or not rect.has_point(feet):
			continue
		trap_ready[index] = tick_count + int(spec.traps[index]["rearm"])
		trap_fired[index] = tick_count
		emit_event("trap", lem, index)
		remove_lemming(lem, false)
		return true
	return false


func _check_exit(lem: Lemming) -> void:
	if lem.state == Lemming.State.BLOCKER or lem.state in DYING_STATES:
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
	if not nuking and spawned < spec.lemming_count:
		return
	# Blokař s bombou nebo dostupným bombičem může ještě ovlivnit výsledek.
	for lem in lemmings:
		if lem.removed:
			continue
		if lem.state != Lemming.State.BLOCKER or lem.bomb_ticks > 0 or nuking:
			return
		if int(skills.get(Lemming.Skill.BOMBER, 0)) > 0:
			return
	finished = true
