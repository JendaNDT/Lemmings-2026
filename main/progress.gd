class_name Progress
extends RefCounted
## Postup hráče: splněné mise, nejlepší výsledky, poslední hraná mise
## a rozehraný pokus. Ukládá se přes SaveFile do `user://progress.json`.
##
## Rozehraný pokus se neukládá jako stav světa, ale jako seznam příkazů
## (`replay_log`) a tik. Simulace je deterministická, takže stejné příkazy
## na stejném levelu dají přesně stejný stav; kontrolní otisk to ověří.

const PATH := "user://progress.json"
const FORMAT := 1

var path := ""
## id mise → {"completed", "best_saved", "best_ticks", "plays", "wins"}
var missions := {}
var last_mission := ""
## {"mission", "tick", "commands", "digest", "saved_at"}; prázdné = nic rozehraného.
var suspended := {}
var load_status := SaveFile.Status.MISSING


static func load_from(file_path: String) -> Progress:
	var progress := Progress.new()
	progress.path = file_path
	var result := SaveFile.read(file_path)
	progress.load_status = result["status"]
	if int(result["format"]) > FORMAT:
		# Soubor z novější verze hry: před přepsáním ho odložit vedle.
		SaveFile.keep_copy(file_path, ".v%d" % int(result["format"]))
	if result["status"] in [SaveFile.Status.OK, SaveFile.Status.BACKUP]:
		progress.from_dict(_migrate(result["data"], result["format"]))
	return progress


func save() -> Error:
	if path.is_empty():
		return OK
	return SaveFile.write(path, to_dict(), FORMAT)


## Smaže veškerý postup (soubor i zálohu).
func reset() -> void:
	missions.clear()
	last_mission = ""
	suspended.clear()
	if not path.is_empty():
		SaveFile.erase(path)


func to_dict() -> Dictionary:
	return {"missions": missions.duplicate(true), "last_mission": last_mission,
		"suspended": suspended.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	missions.clear()
	var stored: Variant = data.get("missions")
	if stored is Dictionary:
		for id: Variant in stored:
			var entry: Variant = stored[id]
			if id is String and entry is Dictionary:
				missions[id] = _clean_entry(entry)
	var last: Variant = data.get("last_mission")
	last_mission = last if last is String else ""
	var pending: Variant = data.get("suspended")
	suspended = pending if pending is Dictionary and _valid_suspended(pending) else {}


func entry(id: String) -> Dictionary:
	return missions.get(id, _clean_entry({}))


func is_completed(id: String) -> bool:
	return bool(entry(id)["completed"])


## První mise je vždy otevřená, další po splnění předchozí.
func is_unlocked(index: int, unlock_all := false) -> bool:
	if unlock_all or index <= 0:
		return true
	if index >= Campaign.count():
		return false
	var list := Campaign.missions()
	return is_completed(list[index - 1]["id"]) or is_completed(list[index]["id"])


func completed_count() -> int:
	var total := 0
	for info in Campaign.missions():
		total += int(is_completed(info["id"]))
	return total


## Kam vede „Pokračovat“ bez rozehraného pokusu: první otevřená nesplněná
## mise, a když je vše splněné, naposledy hraná.
func next_mission_index(unlock_all := false) -> int:
	var list := Campaign.missions()
	for i in list.size():
		if is_unlocked(i, unlock_all) and not is_completed(list[i]["id"]):
			return i
	return maxi(0, Campaign.index_of(last_mission))


func record_start(id: String) -> void:
	var item := entry(id)
	item["plays"] = int(item["plays"]) + 1
	missions[id] = item
	last_mission = id
	suspended.clear()


## Zapíše výsledek dohrané mise. Vrací {"first_win", "new_best", "unlocked_next"}.
func record_result(id: String, saved: int, won: bool, ticks: int) -> Dictionary:
	var item := entry(id)
	var index := Campaign.index_of(id)
	var was_completed := bool(item["completed"])
	var next_was_open := is_unlocked(index + 1)
	var best_saved := int(item["best_saved"])
	var info := {"first_win": won and not was_completed,
		"new_best": won and was_completed and (saved > best_saved
			or (saved == best_saved and ticks < int(item["best_ticks"]))),
		"unlocked_next": false}
	if won:
		item["wins"] = int(item["wins"]) + 1
		item["completed"] = true
		if saved > best_saved or (saved == best_saved and ticks < int(item["best_ticks"])):
			item["best_saved"] = saved
			item["best_ticks"] = ticks
	missions[id] = item
	last_mission = id
	suspended.clear()
	info["unlocked_next"] = won and not next_was_open and index + 1 < Campaign.count()
	return info


## Uloží rozehraný pokus (příkazy a tik) pro „Pokračovat“.
func suspend(id: String, sim: LevelSim) -> void:
	suspended = {"mission": id, "tick": sim.tick_count, "commands": sim.replay_log.duplicate(true),
		"digest": digest(sim), "saved_at": int(Time.get_unix_time_from_system())}
	last_mission = id


func has_suspended() -> bool:
	return not suspended.is_empty()


## Obnoví rozehraný pokus na čerstvé simulaci. Vrací false, když nesedí
## (jiná verze levelu, poškozená data) – pak se pokus zahodí.
func restore_suspended(sim: LevelSim) -> bool:
	if suspended.is_empty():
		return false
	var replay := SimReplay.new(sim, suspended["commands"])
	var target := int(suspended["tick"])
	while replay.error.is_empty() and sim.tick_count < target and not sim.finished:
		replay.step()
	var ok: bool = replay.error.is_empty() and sim.tick_count == target \
		and replay.commands_remaining() == 0 and digest(sim) == suspended["digest"]
	suspended.clear()
	return ok


## Otisk stavu simulace (počty, postavy, terén) pro ověření obnovy.
static func digest(sim: LevelSim) -> String:
	var parts := PackedStringArray([str(sim.tick_count), str(sim.spawned), str(sim.saved),
		str(sim.lost), str(sim.release_rate), str(sim.nuking), str(sim.skills)])
	for lem in sim.lemmings:
		parts.append("%d,%d,%d,%d,%d,%d,%d" % [lem.id, lem.x, lem.y, lem.dir, lem.state,
			lem.state_ticks, lem.bomb_ticks])
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(";".join(parts).to_utf8_buffer())
	context.update(sim.mask.data)
	return context.finish().hex_encode()


static func _clean_entry(data: Dictionary) -> Dictionary:
	return {
		"completed": data.get("completed") == true,
		"best_saved": maxi(0, _int(data, "best_saved")),
		"best_ticks": maxi(0, _int(data, "best_ticks")),
		"plays": maxi(0, _int(data, "plays")),
		"wins": maxi(0, _int(data, "wins")),
	}


static func _valid_suspended(data: Dictionary) -> bool:
	return data.get("mission") is String and (data.get("tick") is float or data.get("tick") is int) \
		and data.get("commands") is Array and data.get("digest") is String


static func _int(data: Dictionary, key: String) -> int:
	var value: Variant = data.get(key)
	if (value is float or value is int) and is_finite(float(value)):
		return int(value)
	return 0


## Úpravy dat ze starších verzí formátu (zatím jen verze 1).
static func _migrate(data: Dictionary, _format: int) -> Dictionary:
	return data
