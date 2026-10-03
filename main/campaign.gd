class_name Campaign
extends RefCounted
## Seznam misí v pořadí kampaně. Postup se ukládá podle stabilního
## identifikátoru mise (`LevelDefinition.level_id`), ne podle pořadí,
## takže přidání nebo přeřazení mise uložený postup nerozbije.

const SCENES: Array[PackedScene] = [
	preload("res://levels/level_01.tscn"),
	preload("res://levels/level_climb_float.tscn"),
	preload("res://levels/level_miner.tscn"),
	preload("res://levels/level_bomber.tscn"),
	preload("res://levels/level_playground.tscn"),
	preload("res://levels/level_hazards.tscn"),
]

static var _missions: Array[Dictionary] = []


## [{id, title, scene, lemmings, required}] – čteno ze scén bez jejich vytvoření.
static func missions() -> Array[Dictionary]:
	if _missions.is_empty():
		for scene in SCENES:
			var info := {"id": "", "title": "", "scene": scene, "lemmings": 20, "required": 10}
			var state := scene.get_state()
			for i in state.get_node_property_count(0):
				match state.get_node_property_name(0, i):
					"level_id": info["id"] = state.get_node_property_value(0, i)
					"title": info["title"] = state.get_node_property_value(0, i)
					"lemming_count": info["lemmings"] = state.get_node_property_value(0, i)
					"save_required": info["required"] = state.get_node_property_value(0, i)
			_missions.append(info)
	return _missions


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
