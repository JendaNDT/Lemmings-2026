extends SceneTree
## Reprodukovatelný render první mise na profilu tabletu, bez měnění simulace.
## Dva běhy: 30 zahřívacích + 100 měřených snímků, střední kvalita, tik 130.
## godot --path . --rendering-method gl_compatibility --script \
##   res://scripts/benchmark_mobile.gd -- --mobile-preview [--native]
## Měří aktuální stroj/ovladač; výsledek z cloudu není FPS fyzického Androidu.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Benchmark potřebuje skutečné grafické vykreslování.")
		quit(1)
		return
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var native := "--native" in OS.get_cmdline_user_args()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if native \
		else Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(2560, 1600)
	root.msaa_2d = Viewport.MSAA_DISABLED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# Izolujeme grafiku. Hudba i zvuky mají vlastní ověření skutečného mixu.
	node_added.connect(func(node: Node) -> void:
		if node is GameAudio or node is GameMusic:
			node.set("silent", true))
	var game := (load("res://main/game_origami.tscn") as PackedScene).instantiate()
	game.level_scene = Campaign.SCENES[0]
	game.settings = GameSettings.new()
	game.settings.quality = GameSettings.Quality.MEDIUM
	game.settings.flyover = false
	root.add_child(game)
	game.set_process(false)
	for _i in 130:
		game.call("_advance")
	game.set("_paused", true)
	game.set_process(true)
	for run in 2:
		for _i in 30:
			await process_frame
		var times: Array[float] = []
		var before := Time.get_ticks_usec()
		for _i in 100:
			await process_frame
			var now := Time.get_ticks_usec()
			times.append((now - before) / 1000.0)
			before = now
		times.sort()
		print("TABLET_RENDER ", JSON.stringify({
			"scenario": "first-mission-tick130-medium-tablet-v1", "run": run + 1,
			"native": native, "samples": times.size(), "window": str(root.size),
			"logical": str(root.get_visible_rect().size),
			"render_pixels": str(root.get_texture().get_size()),
			"median_ms": times[50], "p95_ms": times[95],
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"renderer": RenderingServer.get_video_adapter_name(),
		}))
	game.free()
	await process_frame
	quit()
