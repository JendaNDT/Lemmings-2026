extends SimTest
## Rozlišení klepnutí, posunu, přiblížení a interakce s HUDem.

var _taps := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := load("res://main/game_3d.tscn").instantiate() as Node
	root.add_child(game)
	game.set_process(false)
	var world: ClayWorld = game.get_node("ClayWorld")
	world.camera.input_enabled = false
	world.camera.zoom_factor = 2
	world.camera.focus = Vector2(300, 100)
	world.camera.refresh()
	var gestures := TouchControls.new()
	gestures.camera = world.camera
	gestures.tapped = func(_point: Vector2) -> void: _taps += 1
	var vp := root.get_visible_rect().size
	var center := vp * 0.5
	gestures.handle(_touch(0, center, true), vp)
	check(_taps == 0, "stisk prstu ještě nepřidělí dovednost")
	gestures.handle(_touch(0, center + Vector2(2, 0), false), vp)
	check(_taps == 1, "krátké klepnutí se vyhodnotí právě jednou po uvolnění")
	var before := world.camera.focus
	gestures.handle(_touch(0, center, true), vp)
	gestures.handle(_drag(0, center + Vector2(100, 0)), vp)
	gestures.handle(_touch(0, center + Vector2(100, 0), false), vp)
	check(_taps == 1 and world.camera.focus.x < before.x, "posun kamery nepřidělí dovednost")
	var zoom := world.camera.zoom_factor
	gestures.handle(_touch(0, center - Vector2(60, 0), true), vp)
	gestures.handle(_touch(1, center + Vector2(60, 0), true), vp)
	gestures.handle(_drag(1, center + Vector2(140, 0)), vp)
	gestures.handle(_touch(1, center + Vector2(140, 0), false), vp)
	gestures.handle(_touch(0, center - Vector2(60, 0), false), vp)
	check(world.camera.zoom_factor > zoom and _taps == 1, "dva prsty přiblíží a nevytvoří klepnutí")
	gestures.handle(_touch(0, Vector2(100, vp.y - 10), true), vp)
	gestures.handle(_touch(0, center, false), vp)
	check(_taps == 1, "dotyk začatý na HUDu nepatří herní ploše")
	gestures.handle(_touch(0, center, true), vp)
	var canceled := _touch(0, center, false)
	canceled.canceled = true
	gestures.handle(canceled, vp)
	check(_taps == 1, "zrušený dotyk nepřidělí dovednost")
	gestures.handle(_touch(0, center, true), vp)
	gestures.clear()
	gestures.handle(_touch(0, center, false), vp)
	check(_taps == 1, "přerušení aplikace nebo restart vymaže rozpracované gesto")
	var sim: LevelSim = game.get("_sim")
	var lem := add_lemming(sim, 300, 70)
	game.set("_paused", true)
	game.call("_select_skill", Lemming.Skill.BLOCKER)
	world.camera.focus = Vector2(300, 90)
	world.camera.refresh()
	var point := world.camera.logic_to_screen(Vector2(lem.x + 0.5, lem.y - 5))
	root.push_input(_touch(0, point, true), true)
	root.push_input(_touch(0, point, false), true)
	await process_frame
	check(lem.state == Lemming.State.BLOCKER and sim.replay_log.size() == 1,
		"skutečný dotyk ve scéně přidělí jediný společný příkaz")
	game.call("_select_skill", Lemming.Skill.DIGGER)
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	emulated.position = point
	game.call("_unhandled_input", emulated)
	check(sim.replay_log.size() == 1, "emulovaná myš nezdvojí dotykový příkaz")
	game.set("_paused", false)
	game.notification(NOTIFICATION_APPLICATION_PAUSED)
	check(game.get("_paused"), "odchod aplikace na pozadí zapne pauzu")
	game.free()
	await process_frame
	finish()


func _touch(index: int, point: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	return event


func _drag(index: int, point: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	return event
