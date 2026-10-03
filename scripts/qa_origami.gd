extends SceneTree
## Grafický průchod 2D origami přes skutečné vstupy (klávesy, myš, kolečko,
## dotyk). Ukládá snímky, volitelně snímky pro video a kontroluje, že bílý
## terén v kontrolním režimu shaderu odpovídá masce simulace ve středech buněk.
##
## Spuštění (s grafikou, např. pod Xvfb):
##   godot --path . --rendering-driver opengl3 --script res://scripts/qa_origami.gd \
##     -- --capture-dir=build/origami [--mobile] [--record=build/origami/frames] [--gallery]

const FPS := 30.0

var _game: Node
var _world: PaperWorld
var _sim: LevelSim
var _hud: Hud
var _dir := "res://build/origami/captures"
var _record_dir := ""
var _recording := false
var _frame := 0
var _failed := false
var _mobile := false
var _report := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var gallery := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_dir = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--record="):
			_record_dir = arg.trim_prefix("--record=")
		elif arg == "--mobile":
			_mobile = true
		elif arg == "--gallery":
			gallery = true
	if _mobile:
		# Telefon na šířku s poměrem 20:9 a mobilním základním rozlišením.
		root.content_scale_size = Vector2i(1280, 720)
		root.size = Vector2i(1600, 720)
	DirAccess.make_dir_recursive_absolute(_dir)
	if not _record_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(_record_dir)
	_game = load("res://main/game_origami.tscn").instantiate()
	root.add_child(_game)
	_game.set_process(false)
	_world = _game.get_node("PaperWorld")
	_hud = _game.get_node("Hud")
	_sim = _game.get("_sim")
	await process_frame
	if gallery:
		await _gallery()
	else:
		await _play_level()
		await _mask_check()
	_report["renderer"] = RenderingServer.get_video_adapter_name()
	_report["viewport"] = [root.get_visible_rect().size.x, root.get_visible_rect().size.y]
	_report["mode"] = "touch" if _mobile else "keyboard_mouse"
	var file := FileAccess.open(_dir.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_report, "\t"))
	print("ORIGAMI_QA ", "FAIL" if _failed else "OK", " ", JSON.stringify(_report))
	quit(1 if _failed else 0)


# --- Průběh mise ---------------------------------------------------------------

func _play_level() -> void:
	var record := not _record_dir.is_empty()
	_recording = record
	await _advance(75, true)
	await _capture("01-start")
	_recording = false
	var acts := [false, false, false]
	var steps := 0
	while not _sim.finished and steps < 6000:
		steps += 1
		await _advance(1, _recording)
		for lem in _sim.lemmings:
			if lem.removed or lem.state != Lemming.State.WALKER:
				continue
			var acted := true
			if not acts[0] and lem.dir == 1 and lem.x >= 128 and lem.x <= 132:
				_recording = record
				await _zoom_to(lem, 2.4)
				await _wait_until(func() -> bool: return lem.x >= 170 or lem.dir != 1, 120)
				acts[0] = await _assign(lem, 3, Lemming.State.BASHER)
				await _advance(45, true)
				await _capture("02-bash")
				_recording = false
			elif acts[0] and not acts[1] and lem.dir == 1 and lem.x >= 250 and lem.x <= 254:
				_recording = record
				await _pan_to(lem)
				await _wait_until(func() -> bool: return lem.x >= 281 or lem.dir != 1, 120)
				acts[1] = await _assign(lem, 2, Lemming.State.BUILDER)
				await _advance(80, true)
				await _capture("03-stairs")
				_recording = false
			elif acts[1] and not acts[2] and lem.y <= 58 and lem.dir == 1 and lem.x >= 312 \
					and lem.x <= 318:
				_recording = record
				await _pan_to(lem)
				await _wait_until(func() -> bool: return lem.x >= 336 or lem.dir != 1, 80)
				acts[2] = await _assign(lem, 4, Lemming.State.DIGGER)
				await _advance(40, true)
				await _capture("04-dig")
				await _zoom_out_overview()
				await _capture("05-overview")
				await _pinch_demo()
				_recording = false
				_press_key(KEY_F)
			else:
				acted = false
			if acted:
				break
		if acts[2] and _sim.saved >= 3 and not _report.has("exit_capture"):
			_report["exit_capture"] = true
			_press_key(KEY_F)
			_recording = record
			await _focus(Vector2(380, 100), 2.2)
			await _advance(50, true)
			await _capture("06-exit")
			_recording = false
			_press_key(KEY_F)
	await _advance(3)
	await _capture("07-result")
	_report["saved"] = _sim.saved
	_report["lost"] = _sim.lost
	_report["ticks"] = _sim.tick_count
	_report["input_assignments"] = acts
	_report["won"] = _sim.is_won()
	_failed = _failed or _sim.saved != 20 or not acts.all(func(a: bool) -> bool: return a)


func _assign(lem: Lemming, hotkey: int, expected: Lemming.State) -> bool:
	if _mobile:
		var skill: int = _hud.visible_skills()[hotkey - 1]
		var widgets: Dictionary = _hud.get("_skill_widgets")
		var button: Button = widgets[skill]["button"]
		await _tap(button.get_global_rect().get_center())
		await _tap(_world.camera.logic_to_screen(Vector2(lem.x + 0.5, lem.y - 5)))
	else:
		_press_key(KEY_1 + hotkey - 1)
		var point := _world.camera.logic_to_screen(Vector2(lem.x + 0.5, lem.y - 5))
		var motion := InputEventMouseMotion.new()
		motion.position = point
		_send(motion)
		await _advance(1, _recording)
		var click := InputEventMouseButton.new()
		click.position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		_send(click)
		click = click.duplicate()
		click.pressed = false
		_send(click)
	await _advance(1, _recording)
	var ok := lem.state == expected
	print("ASSIGN ", Lemming.SKILL_NAMES[int(_game.get("_selected_skill"))], " ", ok,
		" x=", lem.x, " dir=", lem.dir)
	_report["assign_attempts"] = int(_report.get("assign_attempts", 0)) + 1
	if not ok:
		_report["assign_misses"] = int(_report.get("assign_misses", 0)) + 1
	return ok


## Události z Input.parse_input_event jsou v souřadnicích okna; hra počítá ve viewportu.
func _window(point: Vector2) -> Vector2:
	return root.get_final_transform() * point


func _send(original: InputEvent) -> void:
	var event := original.duplicate() as InputEvent
	if event is InputEventMouse:
		var mouse := event as InputEventMouse
		mouse.position = _window(mouse.position)
		mouse.global_position = mouse.position
		if event is InputEventMouseMotion:
			var motion := event as InputEventMouseMotion
			motion.relative = root.get_final_transform().basis_xform(motion.relative)
	elif event is InputEventScreenTouch:
		(event as InputEventScreenTouch).position = _window((event as InputEventScreenTouch).position)
	elif event is InputEventScreenDrag:
		(event as InputEventScreenDrag).position = _window((event as InputEventScreenDrag).position)
	Input.parse_input_event(event)


func _press_key(code: Key) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = true
	Input.parse_input_event(key)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)


## Přiblížení kolečkem myši (desktop) nebo dvěma prsty (telefon) nad postavou.
func _zoom_to(lem: Lemming, target: float) -> void:
	await _pan_to(lem)
	var guard := 0
	while _world.camera.zoom_factor < target - 0.01 and guard < 20:
		guard += 1
		var at := _world.camera.logic_to_screen(Vector2(lem.x, lem.y - 4))
		if _mobile:
			await _pinch(at, 1.18)
		else:
			var wheel := InputEventMouseButton.new()
			wheel.position = at
			wheel.button_index = MOUSE_BUTTON_WHEEL_UP
			wheel.pressed = true
			_send(wheel)
			await _advance(2, _recording)


## Posun pohledu tažením (pravé tlačítko myši / jeden prst) tak, aby byl cíl uprostřed.
func _pan_to(lem: Lemming) -> void:
	var start := _world.camera.logic_to_screen(Vector2(lem.x, lem.y))
	var target := _world.camera.screen_center() + Vector2(-60, 40)
	var steps := 8
	if _mobile:
		var down := InputEventScreenTouch.new()
		down.index = 0
		down.position = start
		down.pressed = true
		_send(down)
		for i in steps:
			var drag := InputEventScreenDrag.new()
			drag.index = 0
			drag.position = start.lerp(target, (i + 1.0) / steps)
			_send(drag)
			await _advance(1, _recording)
		var up := down.duplicate()
		up.pressed = false
		up.position = target
		_send(up)
	else:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_RIGHT
		press.position = start
		press.pressed = true
		_send(press)
		var last := start
		for i in steps:
			var motion := InputEventMouseMotion.new()
			motion.position = start.lerp(target, (i + 1.0) / steps)
			motion.relative = motion.position - last
			motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
			last = motion.position
			_send(motion)
			await _advance(1, _recording)
		var release := press.duplicate()
		release.pressed = false
		_send(release)
	await _advance(1, _recording)


func _pinch(center: Vector2, ratio: float) -> void:
	var a := center - Vector2(70, 0)
	var b := center + Vector2(70, 0)
	for index in 2:
		var touch := InputEventScreenTouch.new()
		touch.index = index
		touch.position = a if index == 0 else b
		touch.pressed = true
		_send(touch)
	var steps := 4
	for i in steps:
		var spread := lerpf(70.0, 70.0 * ratio, (i + 1.0) / steps)
		var drag := InputEventScreenDrag.new()
		drag.index = 1
		drag.position = center + Vector2(spread, 0)
		_send(drag)
		var drag0 := InputEventScreenDrag.new()
		drag0.index = 0
		drag0.position = center - Vector2(spread, 0)
		_send(drag0)
		await _advance(1, _recording)
	for index in 2:
		var touch := InputEventScreenTouch.new()
		touch.index = index
		touch.position = center + Vector2(70.0 * ratio * (1 if index else -1), 0)
		_send(touch)
	await _advance(1, _recording)


func _pinch_demo() -> void:
	# Dva prsty uprostřed: zoom ano, žádný herní příkaz.
	var log_size := _sim.replay_log.size()
	var zoom := _world.camera.zoom_factor
	for _i in 4:
		await _pinch(_world.camera.screen_center(), 1.15)
	var ok := _world.camera.zoom_factor > zoom and _sim.replay_log.size() == log_size
	_report["pinch_zoom_without_command"] = ok
	_failed = _failed or not ok
	await _capture("05b-pinch")


func _zoom_out_overview() -> void:
	for _i in 10:
		var wheel := InputEventMouseButton.new()
		wheel.position = _world.camera.screen_center()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		if _mobile:
			await _pinch(_world.camera.screen_center(), 1.0 / 1.2)
		else:
			_send(wheel)
			await _advance(2, _recording)


func _focus(point: Vector2, zoom: float) -> void:
	_world.camera.zoom_factor = zoom
	_world.camera.focus = point
	_world.camera.refresh()
	await _advance(1)


func _wait_until(condition: Callable, limit: int) -> void:
	var count := 0
	while not condition.call() and count < limit:
		count += 1
		await _advance(1, _recording)


func _tap(point: Vector2) -> void:
	var touch := InputEventScreenTouch.new()
	touch.position = point
	touch.index = 0
	touch.pressed = true
	_send(touch)
	await _advance(1, _recording)
	touch = touch.duplicate()
	touch.pressed = false
	_send(touch)
	await _advance(1, _recording)


## Posune hru o `frames` snímků po 1/30 s. Vykresluje jen snímky pro video;
## jinak běží herní smyčka bez kreslení (softwarové GPU v cloudu je pomalé).
func _advance(frames: int, record := false) -> void:
	if not (record and _recording):
		for _i in frames:
			_game.call("_process", 1.0 / FPS)
		await process_frame
		return
	for _i in frames:
		_game.call("_process", 1.0 / FPS)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_jpg(_record_dir.path_join("frame_%05d.jpg" % _frame), 0.92)
		_frame += 1


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_png(_dir.path_join(label + ".png")) != OK:
		_failed = true
	print("CAPTURE ", label)


# --- Přesnost terénu proti masce -------------------------------------------------

## Kontrolní režim shaderu kreslí jen bílý pevný terén. Ve středu každé viditelné
## buňky musí barva odpovídat masce simulace (po kopání, stavění i výbuchu).
func _mask_check() -> void:
	_sim.mask.erase_circle(250, 85, 12)
	_sim.mask.add_brick_row(120, 140, 60)
	_world.terrain.sync()
	var hidden: Array[CanvasItem] = []
	for node: CanvasItem in [_world.props, _world.actors, _world.fx, _world.foreground]:
		hidden.append(node)
	for layer in _world.layers:
		hidden.append(layer)
	for node in hidden:
		node.visible = false
	_hud.visible = false
	_world.terrain.set_debug_mask(true)
	var mismatches := 0
	var checked := 0
	for spot in [Vector2(250, 85), Vector2(130, 62), Vector2(185, 66), Vector2(350, 85)]:
		await _focus(spot, PaperCamera.MAX_ZOOM)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var vp := root.get_visible_rect().size
		var scale := Vector2(image.get_width(), image.get_height()) / vp
		var top_left := _world.camera.screen_to_logic(Vector2(0, _world.camera.top_padding)).ceil()
		var bottom_right := _world.camera.screen_to_logic(
			Vector2(vp.x, vp.y - _world.camera.bottom_padding)).floor()
		for y in range(int(top_left.y), int(bottom_right.y)):
			for x in range(int(top_left.x), int(bottom_right.x)):
				var screen := _world.camera.logic_to_screen(Vector2(x + 0.5, y + 0.5)) * scale
				var pixel := image.get_pixelv(Vector2i(screen.floor()))
				var white := pixel.r > 0.5
				checked += 1
				if white != _sim.mask.is_solid(x, y):
					mismatches += 1
	_world.terrain.set_debug_mask(false)
	for node in hidden:
		node.visible = true
	_hud.visible = true
	_report["mask_cells_checked"] = checked
	_report["mask_mismatches"] = mismatches
	_failed = _failed or checked < 1000 or mismatches > 0
	print("MASK ", checked, " buněk, neshod ", mismatches)


# --- Galerie dovedností -----------------------------------------------------------

## Hřiště se všemi dovednostmi: zblízka zachytí každou pózu ve skutečném enginu.
func _gallery() -> void:
	_game.call("_choose_mission", 4)
	_sim = _game.get("_sim")
	await _advance(2)
	var spots := {
		"g-walk": [Lemming.State.WALKER, Vector2i(60, 70)],
		"g-block": [Lemming.State.BLOCKER, Vector2i(110, 70)],
		"g-build": [Lemming.State.BUILDER, Vector2i(140, 70)],
		"g-bash": [Lemming.State.BASHER, Vector2i(166, 70)],
		"g-mine": [Lemming.State.MINER, Vector2i(230, 70)],
		"g-dig": [Lemming.State.DIGGER, Vector2i(262, 70)],
	}
	var lems := {}
	for key: String in spots:
		var lem := _add(spots[key][1])
		lems[key] = lem
		if spots[key][0] != Lemming.State.WALKER:
			_sim.set_state(lem, spots[key][0])
	var floater := _add(Vector2i(80, 20))
	floater.has_floater = true
	_sim.set_state(floater, Lemming.State.FALLER)
	var bomber := _add(Vector2i(205, 70))
	bomber.bomb_ticks = SimConst.BOMB_TICKS
	var climber := _add(Vector2i(37, 70))
	climber.can_climb = true
	climber.dir = -1
	_sim.set_state(climber, Lemming.State.CLIMBER)
	await _focus(Vector2(110, 62), 3.2)
	await _advance(14)
	await _capture("g-01-walk-block-build")
	await _focus(Vector2(190, 62), 3.2)
	await _capture("g-02-bash-bomb")
	await _focus(Vector2(45, 55), 3.2)
	await _capture("g-02b-climb")
	await _advance(20)
	await _focus(Vector2(250, 70), 3.2)
	await _capture("g-03-mine-dig")
	await _focus(Vector2(85, 50), 3.2)
	await _capture("g-04-float")
	await _focus(Vector2(150, 60), 2.0)
	await _advance(40)
	await _capture("g-05-progress")
	_report["gallery"] = true


func _add(at: Vector2i) -> Lemming:
	var lem := Lemming.new()
	lem.id = _sim.lemmings.size()
	lem.x = at.x
	lem.y = at.y
	lem.prev_x = at.x
	lem.prev_y = at.y
	_sim.lemmings.append(lem)
	_sim.spawned += 1
	_sim.set_state(lem, Lemming.State.WALKER)
	return lem
