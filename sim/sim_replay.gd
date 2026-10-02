class_name SimReplay
extends RefCounted
## Technický přehrávač pro testy a budoucí ukládání řešení (bez ovládání ve hře).
## Dostane čerstvou simulaci stejného levelu a kopii záznamu. step() provede jeden
## tik a příkazy na jeho konci. Příkazy tiku 0 se provedou už při vytvoření.

var sim: LevelSim
var error := ""
var _commands: Array[Dictionary] = []
var _cursor := 0


func _init(fresh_sim: LevelSim, commands: Array) -> void:
	sim = fresh_sim
	if sim.tick_count != 0 or sim.spawned != 0 or not sim.replay_log.is_empty():
		error = "Replay vyžaduje čerstvou simulaci."
		return
	var previous_tick := 0
	for item in commands:
		var command := _read_command(item)
		if command.is_empty():
			return
		if command.tick < previous_tick:
			error = "Příkazy nejsou seřazené podle tiku."
			return
		previous_tick = command.tick
		_commands.append(command)
	_apply_due()


## false = konec levelu nebo chyba. Chybu musí volající zkontrolovat i na konci.
func step() -> bool:
	if not error.is_empty() or sim.finished:
		return false
	sim.tick()
	_apply_due()
	if sim.finished and _cursor < _commands.size() and error.is_empty():
		error = "Level skončil před posledním příkazem."
	return error.is_empty()


func commands_remaining() -> int:
	return _commands.size() - _cursor


func _read_command(item: Variant) -> Dictionary:
	if not item is Dictionary or item.size() != 4:
		error = "Neplatný formát příkazu."
		return {}
	var command := {}
	for key in ["tick", "kind", "target", "value"]:
		var number: Variant = item.get(key)
		# JSON načítá čísla jako float. Přijmeme jen přesná, konečná celá čísla.
		if not (number is int or number is float):
			error = "Příkaz musí obsahovat celá čísla."
			return {}
		if not is_finite(float(number)) or absf(float(number)) > 2147483647.0:
			error = "Číslo příkazu je mimo rozsah."
			return {}
		if float(number) != float(int(number)):
			error = "Příkaz obsahuje neceločíselnou hodnotu."
			return {}
		command[key] = int(number)
	if not _valid_payload(command):
		error = "Neznámý druh příkazu nebo neplatné argumenty."
		return {}
	return command


func _valid_payload(command: Dictionary) -> bool:
	match command.kind:
		LevelSim.Command.ASSIGN_SKILL:
			return command.target >= 0 and command.value in Lemming.SKILL_ORDER
		LevelSim.Command.RELEASE_RATE:
			return command.target == -1 and command.value >= sim.release_rate \
				and command.value <= SimConst.MAX_RELEASE_RATE
	return false


func _apply_due() -> void:
	while _cursor < _commands.size() and _commands[_cursor].tick == sim.tick_count:
		var command := _commands[_cursor]
		if not sim.apply_command(command.kind, command.target, command.value):
			error = "Příkaz %d v tiku %d nelze provést." % [_cursor, sim.tick_count]
			return
		_cursor += 1
