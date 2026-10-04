class_name Campaign
extends RefCounted
## Kampaň: mise v pořadí, rozdělené do kapitol, a Hřiště mimo kampaň.
## Postup se ukládá podle stabilního identifikátoru mise
## (`LevelDefinition.level_id`), ne podle pořadí, takže přidání nebo
## přeřazení mise uložený postup nerozbije. Číslo mise se dopočítá z pořadí.
## Návrh celé kampaně: docs/HERNI_DESIGN.md.

const SCENES: Array[PackedScene] = [
	# I. Papírová louka
	preload("res://levels/level_dira_v_louce.tscn"),
	preload("res://levels/level_schody_na_terasu.tscn"),
	preload("res://levels/level_miner.tscn"),
	preload("res://levels/level_hlidka_u_srazu.tscn"),
	preload("res://levels/level_climb_float.tscn"),
	preload("res://levels/level_01.tscn"),
	# II. Skalní les
	preload("res://levels/level_bomber.tscn"),
	# III. Voda a oheň
	preload("res://levels/level_hazards.tscn"),
]
## Kapitoly: [římské číslo, název, index první mise, počet misí].
const CHAPTERS := [
	["I", "Papírová louka", 0, 6],
	["II", "Skalní les", 6, 1],
	["III", "Voda a oheň", 7, 1],
]
## Pískoviště se všemi dovednostmi; otevře se po splnění kapitoly I.
const PLAYGROUND := preload("res://levels/level_playground.tscn")

static var _missions: Array[Dictionary] = []
static var _playground := {}


## [{id, title, scene, lemmings, required, master, difficulty, introduces}]
## – čteno ze scén bez jejich vytvoření.
static func missions() -> Array[Dictionary]:
	if _missions.is_empty():
		for scene in SCENES:
			_missions.append(_read(scene))
	return _missions


static func playground() -> Dictionary:
	if _playground.is_empty():
		_playground = _read(PLAYGROUND)
	return _playground


static func count() -> int:
	return SCENES.size()


static func index_of(id: String) -> int:
	var list := missions()
	for i in list.size():
		if list[i]["id"] == id:
			return i
	return -1


static func index_of_scene(scene: PackedScene) -> int:
	return SCENES.find(scene)


static func mission(index: int) -> Dictionary:
	return missions()[index]


## Název s číslem z pořadí kampaně („3 · Šikmý tunel“); Hřiště bez čísla.
static func display_title(id: String) -> String:
	var index := index_of(id)
	if index < 0:
		return playground()["title"] if id == playground()["id"] else id
	return "%d · %s" % [index + 1, mission(index)["title"]]


## Index kapitoly (0…) pro misi kampaně, −1 pro misi mimo kampaň.
static func chapter_of(index: int) -> int:
	for c in CHAPTERS.size():
		var first: int = CHAPTERS[c][2]
		if index >= first and index < first + int(CHAPTERS[c][3]):
			return c
	return -1


static func chapter_title(chapter: int) -> String:
	return "%s. %s" % [CHAPTERS[chapter][0], CHAPTERS[chapter][1]]


static func chapter_indices(chapter: int) -> Array[int]:
	var out: Array[int] = []
	for i in range(int(CHAPTERS[chapter][2]), int(CHAPTERS[chapter][2]) + int(CHAPTERS[chapter][3])):
		out.append(i)
	return out


## Prahy hvězd [★, ★★, ★★★]: cíl mise, polovina cesty k mistrovskému
## výsledku a mistrovský výsledek (výsledek referenčního řešení).
static func star_thresholds(info: Dictionary) -> Array[int]:
	var required := int(info["required"])
	var master := maxi(int(info["master"]), required)
	return [required, required + ceili((master - required) / 2.0), master]


## Kolik hvězd (0–3) dává daný počet zachráněných.
static func stars_for(info: Dictionary, saved: int) -> int:
	var thresholds := star_thresholds(info)
	var stars := 0
	for limit in thresholds:
		if saved >= limit:
			stars += 1
	return stars


static func _read(scene: PackedScene) -> Dictionary:
	var info := {"id": "", "title": "", "scene": scene, "lemmings": 20, "required": 10,
		"master": 0, "difficulty": 0, "introduces": ""}
	var keys := {"level_id": "id", "title": "title", "lemming_count": "lemmings",
		"save_required": "required", "master_saved": "master",
		"difficulty_index": "difficulty", "introduces": "introduces"}
	var state := scene.get_state()
	for i in state.get_node_property_count(0):
		var key: String = state.get_node_property_name(0, i)
		if keys.has(key):
			info[keys[key]] = state.get_node_property_value(0, i)
	return info
