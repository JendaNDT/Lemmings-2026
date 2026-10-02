extends SceneTree
## Grafický průchod nových misí přes dotykový výběr dovedností a postav.

var _game: Node
var _world: ClayWorld
var _directory := "res://build/phase4/captures"
var _failed := false
var _report: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
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
	for mission in [1, 2, 3]:
		await _mission(mission)
	_game.call("_choose_mission", 4)
	_game.set("_paused", true)
	await _capture("08-eight-skills")
	var hud: Hud = _game.get_node("Hud")
	var button: Button = hud.get("_nuke_button")
	await _tap(button.get_global_rect().get_center())
	_failed = _failed or not hud.confirmation_open()
	await _capture("09-confirmation")
	hud.nuke_decided.emit(false)
	_report.append({"eight_skills": hud.visible_skills().size(),
		"confirmation_closed": not hud.confirmation_open()})
	var file := FileAccess.open(_directory.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_report, "\t"))
	print("STAGE4_GPU ", "FAIL" if _failed else "OK", " ", JSON.stringify(_report))
	quit(1 if _failed else 0)


func _mission(index: int) -> void:
	_game.call("_choose_mission", index)
	var sim: LevelSim = _game.get("_sim")
	var assigned := false
	var captured: Array[String] = []
	for _frame in 3000:
		_game.call("_process", 1.0 / SimConst.TICKS_PER_SECOND)
		for lem in sim.lemmings:
			if lem.removed:
				continue
			if index == 1 and not lem.can_climb:
				await _assign(lem, Lemming.Skill.CLIMBER)
				await _assign(lem, Lemming.Skill.FLOATER)
			elif index == 2 and not assigned and lem.state == Lemming.State.WALKER and lem.x == 80:
				await _assign(lem, Lemming.Skill.MINER)
				assigned = true
			elif index == 3 and not assigned and lem.state == Lemming.State.WALKER and lem.x == 168:
				await _assign(lem, Lemming.Skill.BLOCKER)
				await _assign(lem, Lemming.Skill.BOMBER)
				assigned = true
			var label := ""
			if lem.state == Lemming.State.CLIMBER and lem.state_ticks == 15:
				label = "01-climbing"
			elif lem.state == Lemming.State.FLOATER and lem.state_ticks == 20:
				label = "02-parachute"
			elif lem.state == Lemming.State.MINER and lem.state_ticks == 80:
				label = "04-mining"
			elif lem.bomb_ticks == 34:
				label = "06-countdown"
			if not label.is_empty() and label not in captured:
				captured.append(label)
				_world.camera.focus = Vector2(lem.x, lem.y + 20)
				_world.camera.refresh()
				await _capture(label)
		if index == 3 and sim.lost == 1 and "07-explosion" not in captured:
			captured.append("07-explosion")
			await _capture("07-explosion")
		if sim.finished or _failed:
			break
	var ok := sim.finished and sim.is_won() and sim.saved == sim.spec.save_required
	_failed = _failed or not ok
	_report.append({"mission": index, "saved": sim.saved, "lost": sim.lost,
		"won": sim.is_won(), "ticks": sim.tick_count, "commands": sim.replay_log.size()})
	await _capture("result-%d" % index)


func _assign(lem: Lemming, skill: int) -> void:
	var sim: LevelSim = _game.get("_sim")
	var before := sim.replay_log.size()
	var hud: Hud = _game.get_node("Hud")
	var widgets: Dictionary = hud.get("_skill_widgets")
	var button: Button = widgets[skill].button
	await _tap(button.get_global_rect().get_center())
	_world.camera.focus = Vector2(lem.x, lem.y + 25)
	_world.camera.refresh()
	await _tap(_world.camera.logic_to_screen(Vector2(lem.x + 0.5, lem.y - 5)))
	var ok := sim.replay_log.size() == before + 1 \
		and int(sim.replay_log.back().value) == skill and int(sim.replay_log.back().target) == lem.id
	print("STAGE4_TOUCH ", Lemming.SKILL_NAMES[skill], " ", ok)
	_failed = _failed or not ok


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
	_failed = _failed or image.save_png(_directory.path_join(label + ".png")) != OK
	print("CAPTURE ", label)
