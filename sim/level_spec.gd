class_name LevelSpec
extends RefCounted
## Pravidla jednoho levelu v čisté podobě (bez Godot uzlů).
## Vyrábí ho LevelLoader ze scény levelu.

var title := ""
var width := 640
var height := 200
var lemming_count := 20
var save_required := 10
## Rychlost vypouštění lumíků (1–99). Hráč ji může jen zvýšit.
var release_rate := 50
var time_limit_seconds := 300
## Lemming.Skill → počet kusů.
var skills := {}
## Místa, kde lumíci vypadávají (líhně) a kam mají dojít (východy).
var hatches: Array[Vector2i] = []
var exits: Array[Vector2i] = []
