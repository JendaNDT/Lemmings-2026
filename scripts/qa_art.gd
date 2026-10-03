extends SceneTree
## Stejná hratelná scéna pro výtvarnou kontrolu před a po kopání.

var _directory := "res://build/art-pass/captures"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_directory = arg.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(_directory)
	root.content_scale_size = Vector2i(1600, 900)
	root.size = Vector2i(1600, 900)
	root.msaa_2d = Viewport.MSAA_DISABLED
	var game := load("res://main/game_3d.tscn").instantiate() as Node
	root.add_child(game)
	game.set_process(false)
	var world: ClayWorld = game.get_node("ClayWorld")
	world.camera.input_enabled = false
	world.camera.zoom_factor = 1.4
	world.camera.focus = Vector2(240, 86)
	world.camera.refresh()
	var sim: LevelSim = game.get("_sim")
	var actions := [false, false, false]
	for tick in 1015:
		game.call("_process", 1.0 / SimConst.TICKS_PER_SECOND)
		for lem in sim.lemmings:
			if lem.removed or lem.state != Lemming.State.WALKER:
				continue
			var skill := -1
			if not actions[0] and lem.dir == 1 and lem.x >= 170 and lem.x <= 175:
				skill = Lemming.Skill.BASHER
				actions[0] = true
			elif actions[0] and not actions[1] and lem.dir == 1 and lem.x >= 280 and lem.x <= 284:
				skill = Lemming.Skill.BUILDER
				actions[1] = true
			elif actions[1] and not actions[2] and lem.y <= 58 and lem.x >= 330 and lem.x <= 360:
				skill = Lemming.Skill.DIGGER
				actions[2] = true
			if skill >= 0:
				sim.assign_skill(lem, skill)
		if tick in [120, 260, 490, 720]:
			await _capture("scene-%d" % tick)
		if tick == 260:
			world.camera.zoom_factor = 2.5
			world.camera.focus = Vector2(185, 75)
			world.camera.refresh()
			await _capture("closeup")
			world.camera.zoom_factor = 1.4
			world.camera.focus = Vector2(240, 86)
			world.camera.refresh()
		if sim.finished:
			break
	print("ART_QA saved=", sim.saved, " ticks=", sim.tick_count)
	quit(0 if sim.saved == 20 else 1)


func _capture(label: String) -> void:
	for _frame in 3:
		await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(_directory.path_join(label + ".png"))
	print("CAPTURE ", label, " ", result)
