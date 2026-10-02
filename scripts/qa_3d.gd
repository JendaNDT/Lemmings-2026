extends SceneTree
## Opakovatelný grafický průchod přes skutečné klávesy a myš; výstupy mimo export.

var _game: Node
var _world: ClayWorld
var _sim: LevelSim
var _directory := "res://build/phase3/captures"
var _times: Array[int] = []
var _rebuild_times: Array[int] = []
var _failed := false
var _touch_mode := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_touch_mode = "--touch" in OS.get_cmdline_user_args()
	if _touch_mode:
		root.content_scale_size = Vector2i(1280, 720)
		root.size = Vector2i(1280, 720)
		root.msaa_2d = Viewport.MSAA_DISABLED
		root.msaa_3d = Viewport.MSAA_DISABLED
		root.scaling_3d_scale = 0.75
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_directory = arg.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(_directory)
	_game = load("res://main/game_3d.tscn").instantiate()
	root.add_child(_game)
	_game.set_process(false)
	_world = _game.get_node("ClayWorld")
	_world.camera.input_enabled = false
	_sim = _game.get("_sim")
	await process_frame
	await _capture("01-start")
	var actions := [false, false, false]
	var after_bash := false
	var after_build := false
	var after_dig := false
	for frame in 5100:
		var started := Time.get_ticks_usec()
		_game.call("_process", 1.0 / SimConst.TICKS_PER_SECOND)
		_times.append(Time.get_ticks_usec() - started)
		if _world.terrain.last_update_usec > 0:
			_rebuild_times.append(_world.terrain.last_update_usec)
		for lem in _sim.lemmings:
			if lem.removed or lem.state != Lemming.State.WALKER:
				continue
			if not actions[0] and lem.dir == 1 and lem.x >= 170 and lem.x <= 175:
				actions[0] = await _assign(lem, KEY_3, Lemming.State.BASHER)
			elif actions[0] and not actions[1] and lem.dir == 1 and lem.x >= 280 and lem.x <= 284:
				actions[1] = await _assign(lem, KEY_2, Lemming.State.BUILDER)
			elif actions[1] and not actions[2] and lem.y <= 58 and lem.x >= 330 and lem.x <= 360:
				actions[2] = await _assign(lem, KEY_4, Lemming.State.DIGGER)
		if frame == 120:
			await _capture("02-walk")
		if actions[0] and not after_bash and _sim.mask.version > 18:
			after_bash = true
			await _capture("03-tunnel")
		if actions[1] and not after_build and _sim.mask.version > 30:
			after_build = true
			await _capture("04-stairs")
		if actions[2] and not after_dig and _sim.mask.version > 42:
			after_dig = true
			_world.camera.focus.x = 350
			_world.camera.refresh()
			await _capture("05-shaft")
		if _sim.finished or _failed:
			break
	await _capture("06-result")
	_times.sort()
	_rebuild_times.sort()
	var report := {
		"input_mode": "touch" if _touch_mode else "keyboard_and_mouse",
		"saved": _sim.saved, "lost": _sim.lost, "ticks": _sim.tick_count,
		"won": _sim.is_won(), "input_assignments": actions,
		"cpu_frame_p95_usec": _times[int(_times.size() * 0.95)],
		"cpu_frame_max_usec": _times.back(),
		"terrain_p95_usec": _rebuild_times[int(_rebuild_times.size() * 0.95)] \
			if not _rebuild_times.is_empty() else 0,
		"terrain_max_usec": _rebuild_times.back() if not _rebuild_times.is_empty() else 0,
		"renderer": RenderingServer.get_video_adapter_name(),
		"note": "CPU timings exclude drawing; software GPU is not target-device FPS",
	}
	var file := FileAccess.open(_directory.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	var ok := not _failed and _sim.saved == 20 and _sim.is_won() and actions.all(func(a): return a)
	print("GPU_QA ", "OK" if ok else "FAIL", " ", JSON.stringify(report))
	quit(0 if ok else 1)


func _assign(lem: Lemming, keycode: Key, expected: Lemming.State) -> bool:
	if _touch_mode:
		return await _assign_touch(lem, keycode, expected)
	var key := InputEventKey.new()
	key.physical_keycode = keycode
	key.pressed = true
	root.push_input(key, true)
	key = key.duplicate()
	key.pressed = false
	root.push_input(key, true)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = _world.camera.logic_to_screen(Vector2(lem.x + 0.5, lem.y - 5))
	root.push_input(motion, true)
	await process_frame
	var click := InputEventMouseButton.new()
	click.position = motion.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	await process_frame
	var ok := lem.state == expected
	print("INPUT ", Lemming.SKILL_NAMES[int(_game.get("_selected_skill"))], " ", ok)
	_failed = _failed or not ok
	return ok


func _assign_touch(lem: Lemming, keycode: Key, expected: Lemming.State) -> bool:
	var hud: Hud = _game.get_node("Hud")
	var skill: int = hud.visible_skills()[int(keycode - KEY_1)]
	var widgets: Dictionary = hud.get("_skill_widgets")
	var button: Button = widgets[skill]["button"]
	await _tap(button.get_global_rect().get_center())
	_world.camera.focus = Vector2(lem.x, lem.y + 25)
	_world.camera.refresh()
	var point := _world.camera.logic_to_screen(Vector2(lem.x + 0.5, lem.y - 5))
	await _tap(point)
	var ok := lem.state == expected
	print("TOUCH ", Lemming.SKILL_NAMES[skill], " ", ok)
	_failed = _failed or not ok
	return ok


func _tap(point: Vector2) -> void:
	var touch := InputEventScreenTouch.new()
	touch.position = point
	touch.index = 0
	touch.pressed = true
	Input.parse_input_event(touch)
	await process_frame
	touch = touch.duplicate()
	touch.pressed = false
	Input.parse_input_event(touch)
	await process_frame


func _capture(label: String) -> void:
	for _frame in 3:
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_png(_directory.path_join(label + ".png")) != OK:
		_failed = true
	print("CAPTURE ", label)
