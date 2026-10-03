extends SceneTree
## Přímé záběry výtvarného výřezu, bez obrazových úprav po vykreslení.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var directory := "res://build/reference-v3/capture"
	var quick := "--quick" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			directory = arg.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(directory)
	root.content_scale_size = Vector2i(1600, 900)
	root.size = Vector2i(800, 450) if quick else Vector2i(1600, 900)
	root.msaa_3d = Viewport.MSAA_4X
	root.use_taa = RenderingServer.get_current_rendering_method() == "forward_plus"
	var scene := load("res://studies/clay_reference.tscn").instantiate() as Node3D
	root.add_child(scene)
	if "--no-shadows" in OS.get_cmdline_user_args():
		for light in scene.find_children("*", "Light3D", true, false):
			light.shadow_enabled = false
	if "--no-ssao" in OS.get_cmdline_user_args():
		for world in scene.find_children("*", "WorldEnvironment", true, false):
			world.environment.ssao_enabled = false
	scene.set("paused", true)
	if "--check-controls" in OS.get_cmdline_user_args():
		await _key(KEY_SPACE)
		assert(not scene.get("paused"))
		await _key(KEY_SPACE)
		assert(scene.get("paused"))
		var lens: Camera3D = scene.get("camera")
		var size_before := lens.size
		await _key(KEY_TAB)
		assert(lens.size < size_before)
		await _key(KEY_TAB)
		assert(is_equal_approx(lens.size, size_before))
		scene.call("set_study_time", 9.0)
		await _key(KEY_R)
		assert(is_zero_approx(float(scene.get("clock"))))
		print("REFERENCE_CONTROLS_OK space pause, tab detail, R restart")
	scene.call("set_study_time", .55)
	await _capture(directory.path_join("overview.png"))
	if quick:
		print("REFERENCE_CAPTURE_OK")
		quit()
		return
	var camera: Camera3D = scene.get("camera")
	camera.size = 4.3
	camera.position.x = -1.0
	await _capture(directory.path_join("detail.png"))
	scene.call("set_study_time", 1.15)
	await _capture(directory.path_join("work-pose.png"))
	if "--record" in OS.get_cmdline_user_args():
		camera.size = 8.1
		camera.position.x = 0
		DirAccess.make_dir_recursive_absolute(directory.path_join("frames"))
		for frame in 48:
			scene.call("set_study_time", frame / 24.0)
			await RenderingServer.frame_post_draw
			var path := directory.path_join("frames/%03d.png" % frame)
			assert(root.get_texture().get_image().save_png(path) == OK)
		print("RECORDED 48 rendered frames at 24 fps")
	print("REFERENCE_CAPTURE_OK")
	quit()


func _capture(path: String) -> void:
	for _frame in 12:
		await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("CAPTURE ", path)


func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
