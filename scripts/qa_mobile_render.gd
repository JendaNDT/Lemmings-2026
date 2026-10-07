extends SimTest
## Skutečný 2D render mobilního profilu: počet vykreslených pixelů, zachování
## poměru stran a vstupy v pixelech displeje (HUD i přidělení dovednosti).
## Spouštět s grafikou a --mobile-preview; headless tuto kontrolu nenahrazuje.
## godot --path . --rendering-method gl_compatibility --script \
##   res://scripts/qa_mobile_render.gd -- --mobile-preview

const SIZES := [Vector2i(2560, 1600), Vector2i(1920, 1200), Vector2i(2400, 1080)]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless" or not DeviceProfile.touch_mode():
		check(false, "je potřeba grafický Godot a --mobile-preview")
		finish()
		return
	# Tento průchod měří obraz a vstupy. Dummy audio nemíchá streamy;
	# skutečný zvuk má vlastní qa_music.gd, zde jej nespouštíme.
	node_added.connect(_silence_audio)
	check(ProjectSettings.get_setting("display/window/stretch/mode.android") == "viewport",
		"Android vykresluje do návrhového viewportu")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width.android"),
		ProjectSettings.get_setting("display/window/size/viewport_height.android"))
	root.msaa_2d = Viewport.MSAA_DISABLED
	for size: Vector2i in SIZES:
		await _profile(size)
	finish()


func _profile(size: Vector2i) -> void:
	root.size = size
	await _frames(2)
	var game := load("res://main/game_origami.tscn").instantiate() as Node
	root.add_child(game)
	game.set_process(false)
	game.set("_paused", true)
	var world: PaperWorld = game.get_node("PaperWorld")
	world.camera.input_enabled = false
	world.camera.zoom_factor = 2.0
	world.camera.focus = Vector2(300, 90)
	world.camera.refresh()
	var sim: LevelSim = game.get("_sim")
	var lem := add_lemming(sim, 300, 70)
	game.call("_process", 0.0)
	await _frames(3)
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image().get_size()
	var logical := root.get_visible_rect().size
	check(pixels.x * pixels.y <= 1600 * 800 and pixels.x * pixels.y < size.x * size.y,
		"%s: omezené interní rozlišení %s" % [size, pixels])
	check(Vector2(pixels).distance_to(logical) < 2.0
		and absf(float(pixels.x) / pixels.y - float(size.x) / size.y) < 0.003,
		"%s: viewport a obraz mají stejný poměr stran" % size)
	var hud: Hud = game.get_node("Hud")
	var pause: Button = hud.get("_pause_button")
	_mouse_click(pause.get_global_rect().get_center())
	await _frames(1)
	check(not game.get("_paused"), "%s: tlačítko HUD reaguje v pixelech displeje" % size)
	game.set("_paused", true)
	game.call("_select_skill", Lemming.Skill.BLOCKER)
	var point := world.camera.logic_to_screen(Vector2(lem.x + 0.5, lem.y - 5))
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = _screen_point(point)
		touch.pressed = pressed
		root.push_input(touch, false)
	await _frames(1)
	check(lem.state == Lemming.State.BLOCKER and sim.replay_log.size() == 1,
		"%s: fyzický dotyk přidělí právě jednu dovednost" % size)
	var camera_before := world.camera.focus
	var center := logical * 0.5
	var start := InputEventScreenTouch.new()
	start.index = 0
	start.position = _screen_point(center)
	start.pressed = true
	root.push_input(start, false)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = _screen_point(center + Vector2(90, 0))
	root.push_input(drag, false)
	start = start.duplicate()
	start.position = drag.position
	start.pressed = false
	root.push_input(start, false)
	check(world.camera.focus.x < camera_before.x and sim.replay_log.size() == 1,
		"%s: tažení přesune kameru, nevytvoří herní příkaz" % size)
	game.free()
	await _frames(2)


func _screen_point(point: Vector2) -> Vector2:
	return point * Vector2(root.size) / root.get_visible_rect().size


func _mouse_click(point: Vector2) -> void:
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.pressed = pressed
		click.position = _screen_point(point)
		root.push_input(click, false)


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _silence_audio(node: Node) -> void:
	if node is GameAudio or node is GameMusic:
		node.set("silent", true)
