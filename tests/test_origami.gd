extends SimTest
## 2D origami: převod souřadnic, zoom kolem bodu, hranice, paralaxa, dotyky,
## animace podle tiků a celé řešení mise přes skutečnou scénu.

const HAZARD_LEVEL := preload("res://levels/level_hazards.tscn")
const ASPECTS := [Vector2(1920, 1080), Vector2(1280, 720), Vector2(2400, 1080), Vector2(1024, 768),
	Vector2(1080, 1080)]

var _taps := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_camera_math()
	_test_parallax()
	_test_static_terrain()
	_test_animation_rig()
	var scene := load("res://main/game_origami.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	game.set_process(false)
	var world: PaperWorld = game.get_node("PaperWorld")
	world.camera.input_enabled = false
	_test_gestures(world.camera)
	await _test_scene_input(game, world)
	_test_animation_in_scene(game, world)
	game.free()
	_test_hazard_effects()
	_test_grass()
	await _test_living_scene(scene)
	await process_frame
	_test_solution(scene)
	_test_other_missions(scene)
	_test_hazard_mission(scene)
	_test_chapter_themes(scene)
	finish()


func _camera(size: Vector2, level := Vector2(640, 200)) -> PaperCamera:
	var cam := PaperCamera.new()
	cam.viewport_override = size
	cam.setup(level, level * 0.5, 1.0)
	return cam


func _test_camera_math() -> void:
	var exact := true
	var clamped := true
	var anchored := true
	for size: Vector2 in ASPECTS:
		for level: Vector2 in [Vector2(640, 200), Vector2(400, 160), Vector2(120, 200)]:
			var cam := _camera(size, level)
			for zoom in [1.0, 1.5, 2.2, 3.2]:
				cam.zoom_factor = zoom
				cam.focus = Vector2(level.x * 0.31, level.y * 0.7)
				cam.refresh()
				for point in [Vector2(3, 7), Vector2(level.x * 0.5, 33.5), level - Vector2(1, 1)]:
					var screen := cam.logic_to_screen(point)
					exact = exact and cam.screen_to_logic(screen).distance_to(point) < 0.001 \
						and (cam.game_transform() * point).distance_to(screen) < 0.001
				# Viditelná herní plocha nikdy nepřesáhne level (užší level je vycentrovaný).
				var top_left := cam.screen_to_logic(Vector2(0, cam.top_padding))
				var bottom_right := cam.screen_to_logic(Vector2(size.x, size.y - cam.bottom_padding))
				for axis in 2:
					var span := bottom_right[axis] - top_left[axis]
					if span <= level[axis] + 0.001:
						clamped = clamped and top_left[axis] >= -0.001 \
							and bottom_right[axis] <= level[axis] + 0.001
					else:
						clamped = clamped and absf(top_left[axis] + bottom_right[axis] - level[axis]) < 0.01
			# Zoom kolem kurzoru: bod pod kurzorem zůstane, dokud to dovolí hranice.
			cam.zoom_factor = 1.6
			cam.focus = level * 0.5
			cam.refresh()
			var cursor := cam.logic_to_screen(level * Vector2(0.45, 0.55))
			var before := cam.screen_to_logic(cursor)
			cam.zoom_at(cursor, 1.3)
			# Užší level je vycentrovaný; tam kurzor kotvou být nemůže.
			if size.x / cam.pixel_scale() < level.x:
				anchored = anchored and cam.screen_to_logic(cursor).distance_to(before) < 0.01 \
					and absf(cam.zoom_factor - 2.08) < 0.001
			cam.free()
	check(exact, "převod logika ↔ obrazovka je přesně vratný a shodný s herní transformací")
	check(clamped, "kamera při žádném zoomu ani poměru stran neukáže prázdno mimo level")
	check(anchored, "zoom drží bod pod kurzorem na místě")
	var cam := _camera(Vector2(1280, 720))
	cam.zoom_at(Vector2(640, 300), 50.0)
	var max_ok := is_equal_approx(cam.zoom_factor, PaperCamera.MAX_ZOOM)
	cam.zoom_at(Vector2(640, 300), 0.001)
	check(max_ok and is_equal_approx(cam.zoom_factor, PaperCamera.MIN_ZOOM),
		"zoom respektuje meze 1× až 3,2×")
	cam.zoom_factor = 2.0
	cam.focus = Vector2(320, 100)
	cam.refresh()
	var anchor := cam.screen_to_logic(Vector2(500, 400))
	cam.pan_screen(Vector2(500, 400), Vector2(560, 380))
	check(cam.logic_to_screen(anchor).distance_to(Vector2(560, 380)) < 0.01,
		"tažení posune scénu přesně za prstem")
	cam.zoom_factor = 1.0
	cam.focus = Vector2(320, 100)
	cam.refresh()
	var corner := cam.screen_to_logic(Vector2(4, 360))
	cam.zoom_at(Vector2(4, 360), 1.5)
	check(cam.screen_to_logic(Vector2(0, cam.top_padding)).x >= -0.001 and corner.x >= 0,
		"zoom u okraje mapy zůstane v hranicích levelu")
	cam.free()


func _layers(cam: PaperCamera) -> Array[PaperParallax]:
	var out: Array[PaperParallax] = []
	for spec: Array in PaperWorld.LAYERS:
		var layer := PaperParallax.new()
		var tex: Texture2D = load(PaperWorld.LAYER_DIR + spec[0] + ".png")
		layer.setup(cam, tex, spec[1], spec[2], spec[3], spec[4], spec[5], spec[6])
		out.append(layer)
	return out


func _test_parallax() -> void:
	var covered := true
	var ordered_pan := true
	var ordered_zoom := true
	var smooth := true
	for size: Vector2 in ASPECTS:
		var cam := _camera(size)
		var layers := _layers(cam)
		for zoom in [1.0, 1.7, 3.2]:
			cam.zoom_factor = zoom
			for fx in [0.0, 0.5, 1.0]:
				cam.focus = Vector2(640 * fx, 200 * fx)
				cam.refresh()
				for layer in layers:
					if layer.extend_bottom:
						covered = covered and layer.covered_rect().end.y >= size.y
		# Posun: vzdálené vrstvy se pohnou méně než bližší a herní rovina nejvíc.
		cam.zoom_factor = 1.5
		cam.focus = Vector2(250, 100)
		cam.refresh()
		var before: Array[float] = []
		for layer in layers:
			before.append(layer.texture_to_screen(Vector2(100, 100)).x)
		var game_before := cam.logic_to_screen(Vector2(300, 100)).x
		cam.focus.x += 40
		cam.refresh()
		var moved: Array[float] = []
		for i in layers.size():
			moved.append(absf(layers[i].texture_to_screen(Vector2(100, 100)).x - before[i]))
		moved.append(absf(cam.logic_to_screen(Vector2(300, 100)).x - game_before))
		for i in moved.size() - 1:
			ordered_pan = ordered_pan and moved[i] < moved[i + 1]
		# Zoom: vzdálené vrstvy se zvětší méně, řízeně a plynule (bez skoků).
		var scale_before: Array[float] = []
		for layer in layers:
			scale_before.append(layer.layer_scale())
		var game_scale := cam.pixel_scale()
		var last: Array[Vector2] = []
		for layer in layers:
			last.append(layer.texture_to_screen(Vector2(700, 300)))
		for step in 40:
			cam.zoom_at(size * 0.5, 1.02)
			for i in layers.size():
				var now := layers[i].texture_to_screen(Vector2(700, 300))
				smooth = smooth and now.distance_to(last[i]) < size.y * 0.05
				last[i] = now
		var growth: Array[float] = []
		for i in layers.size():
			growth.append(layers[i].layer_scale() / scale_before[i])
		growth.append(cam.pixel_scale() / game_scale)
		for i in growth.size() - 1:
			ordered_zoom = ordered_zoom and growth[i] <= growth[i + 1] + 0.0001
		ordered_zoom = ordered_zoom and growth[0] < 1.06
		for layer in layers:
			layer.free()
		cam.free()
	check(covered, "vrstvy při všech poměrech stran, posunech a zoomech kryjí obrazovku bez mezer")
	check(ordered_pan, "paralaxa: vzdálenější vrstvy se posouvají méně než bližší a herní rovina")
	check(ordered_zoom, "rozdílný zoom vrstev je řízený: vzdálené se zvětšují nejméně")
	check(smooth, "plynulý zoom nezpůsobí skok žádné vrstvy")


func _test_static_terrain() -> void:
	var mask := TerrainMask.new(80, 60)
	paint_rect(mask, Rect2i(0, 20, 80, 40))
	paint_rect(mask, Rect2i(20, 30, 40, 12), TerrainMask.Kind.ERASE)
	var image := PaperTerrain.build_static(mask)
	check(image.get_pixel(10, 20).a8 == 0 and image.get_pixel(10, 22).a8 == 32,
		"drn leží od původního povrchu dolů")
	check(image.get_pixel(30, 42).a8 == 255 and image.get_pixel(30, 35).g8 == 255,
		"dno jeskyně nemá drn a vnitřek jeskyně má zadní stěnu")
	check(image.get_pixel(10, 10).g8 == 0, "nebe nad terénem není jeskyně")
	var terrain := PaperTerrain.new()
	root.add_child(terrain)
	terrain.setup(mask)
	var regions := mask.region_versions.duplicate()
	terrain.sync()
	check(terrain.updates == 0, "beze změny masky se textura neobnovuje")
	mask.erase_rect(5, 21, 4, 4)
	var changed := mask.region_versions.duplicate()
	terrain.sync()
	terrain.sync()
	check(terrain.updates == 1 and mask.region_versions == changed and regions != changed,
		"změna masky obnoví texturu jednou a revize oblastí se jen čtou")
	terrain.free()


func _test_animation_rig() -> void:
	var actors := PaperActors.new()
	var rig := actors.rig
	var complete := true
	for name: String in rig["state_animations"]:
		complete = complete and (rig["animations"] as Dictionary).has(name)
	complete = complete and (rig["state_animations"] as Array).size() == Lemming.State.size()
	check(complete, "každý stav postavy má vlastní origami animaci")
	var parts: Dictionary = rig["parts"]
	var tools_ok := true
	for name: String in rig["animations"]:
		var anim: Dictionary = rig["animations"][name]
		if anim["tool"] != "":
			tools_ok = tools_ok and parts.has(anim["tool"])
	check(tools_ok and parts.has("umbrella_open") and parts.has("pick") and parts.has("shovel"),
		"nářadí animací existuje v atlasu dílů")
	var build: Dictionary = rig["animations"]["build"]
	var phase := float(SimConst.BUILDER_BRICK_PHASE) / float(build["cycle"])
	var contact: Array = PaperActors.sample(build, phase)
	check(int(build["cycle"]) == SimConst.BUILDER_TICKS_PER_BRICK
		and is_equal_approx(float(contact[0]["torso"]), 38.0) and contact[2] == "",
		"stavitel pokládá cihlu v tiku, kdy ji simulace přidá do masky")
	var bash: Dictionary = rig["animations"]["bash"]
	check(int(bash["cycle"]) % SimConst.BASHER_TICKS_PER_STEP == 0
		and int(rig["animations"]["mine"]["cycle"]) % SimConst.MINER_TICKS_PER_STEP == 0
		and int(rig["animations"]["dig"]["cycle"]) % SimConst.DIGGER_TICKS_PER_ROW == 0,
		"úder raziče, horníka a kopáče padá na tik změny masky")
	actors.free()


func _test_gestures(cam: PaperCamera) -> void:
	_taps = 0
	cam.zoom_factor = 2.0
	cam.focus = Vector2(300, 100)
	cam.refresh()
	var gestures := TouchControls.new()
	gestures.camera = cam
	gestures.tapped = func(_point: Vector2) -> void: _taps += 1
	var vp := cam.viewport_size()
	var center := cam.screen_center()
	gestures.handle(_touch(0, center, true), vp)
	check(_taps == 0, "2D: stisk prstu ještě nepřidělí dovednost")
	gestures.handle(_touch(0, center + Vector2(3, 0), false), vp)
	check(_taps == 1, "2D: krátké klepnutí se vyhodnotí právě jednou po uvolnění")
	var anchor := cam.screen_to_logic(center)
	gestures.handle(_touch(0, center, true), vp)
	gestures.handle(_drag(0, center + Vector2(90, 10)), vp)
	gestures.handle(_touch(0, center + Vector2(90, 10), false), vp)
	check(_taps == 1 and cam.logic_to_screen(anchor).distance_to(center + Vector2(90, 10)) < 0.5,
		"2D: posun jedním prstem drží bod pod prstem a nepřidělí dovednost")
	cam.focus = Vector2(300, 100)
	cam.zoom_factor = 1.5
	cam.refresh()
	var a := center - Vector2(80, 0)
	var b := center + Vector2(80, 0)
	var mid_anchor := cam.screen_to_logic(center)
	var zoom := cam.zoom_factor
	gestures.handle(_touch(0, a, true), vp)
	gestures.handle(_touch(1, b, true), vp)
	gestures.handle(_drag(1, b + Vector2(60, 0)), vp)
	var new_center := (a + b + Vector2(60, 0)) * 0.5
	var held := cam.logic_to_screen(mid_anchor).distance_to(new_center) < 1.0
	gestures.handle(_touch(1, b + Vector2(60, 0), false), vp)
	gestures.handle(_touch(0, a, false), vp)
	check(cam.zoom_factor > zoom and held and _taps == 1,
		"2D: dva prsty přiblíží kolem svého středu a nevytvoří klepnutí")
	gestures.handle(_touch(0, Vector2(200, vp.y - 12), true), vp)
	gestures.handle(_touch(0, center, false), vp)
	gestures.handle(_touch(0, Vector2(200, 12), true), vp)
	gestures.handle(_touch(0, center, false), vp)
	check(_taps == 1, "2D: dotyk začatý na HUDu nepatří herní ploše")


func _test_scene_input(game: Node, world: PaperWorld) -> void:
	var sim: LevelSim = game.get("_sim")
	var lem := add_lemming(sim, 120, 70)
	game.set("_paused", true)
	game.call("_select_skill", Lemming.Skill.BLOCKER)
	world.camera.zoom_factor = 1.5
	world.camera.focus = Vector2(150, 80)
	world.camera.refresh()
	game.call("_process", 0.0)
	var point := world.camera.logic_to_screen(Vector2(lem.x + 0.5, lem.y - 5))
	root.push_input(_touch(0, point, true), true)
	root.push_input(_touch(0, point, false), true)
	await process_frame
	check(lem.state == Lemming.State.BLOCKER and sim.replay_log.size() == 1,
		"2D: skutečný dotyk ve scéně přidělí jediný společný příkaz")
	game.call("_select_skill", Lemming.Skill.DIGGER)
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	emulated.position = point
	game.call("_unhandled_input", emulated)
	check(sim.replay_log.size() == 1, "2D: emulovaná myš nezdvojí dotykový příkaz")
	var walker := add_lemming(sim, 200, 70)
	game.call("_select_skill", Lemming.Skill.BUILDER)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = world.camera.logic_to_screen(Vector2(walker.x + 0.5, walker.y - 4))
	game.call("_unhandled_input", click)
	check(walker.state == Lemming.State.BUILDER and sim.replay_log.size() == 2,
		"2D: klik myší na postavu přidělí dovednost přes stejný převod souřadnic")
	world.camera.input_enabled = true
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = world.camera.logic_to_screen(Vector2(200, 60))
	var zoom := world.camera.zoom_factor
	world.camera._unhandled_input(wheel)
	check(world.camera.zoom_factor > zoom
		and world.camera.logic_to_screen(Vector2(200, 60)).distance_to(wheel.position) < 0.01
		and sim.replay_log.size() == 2, "2D: kolečko přiblíží kolem kurzoru bez herního příkazu")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	world.camera._unhandled_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(700, 400)
	motion.relative = Vector2(-50, 0)
	var focus := world.camera.focus
	world.camera._unhandled_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	world.camera._input(release)
	check(world.camera.focus.x > focus.x and not world.camera.get("_dragging"),
		"2D: tažení pravým tlačítkem posune pohled a uvolnění nad HUDem tažení ukončí")
	world.camera.input_enabled = false
	game.set("_paused", false)
	game.notification(NOTIFICATION_APPLICATION_PAUSED)
	check(game.get("_paused"), "2D: odchod aplikace na pozadí zapne pauzu")


func _test_animation_in_scene(game: Node, world: PaperWorld) -> void:
	game.set("_paused", false)
	game.call("_load_level")
	var sim: LevelSim = game.get("_sim")
	# Razič hned před sloupem, aby zůstal v práci několik tiků.
	var lem := add_lemming(sim, 168, 70)
	sim.set_state(lem, Lemming.State.BASHER)
	game.call("_process", 0.0)
	var actors := world.actors
	var views: Dictionary = actors.get("_views")
	var pose: Dictionary = views[lem.id].pose.duplicate()
	game.set("_paused", true)
	for _i in 5:
		game.call("_process", 0.2)
	check(views[lem.id].pose == pose and sim.tick_count == 0,
		"pauza zastaví pracovní animaci i simulaci")
	game.set("_paused", false)
	game.call("_process", 2.0 / SimConst.TICKS_PER_SECOND)
	check(views[lem.id].pose != pose and actors.anim_for(lem) == "bash",
		"animace raziče běží podle simulačních tiků")
	# Stop-motion: póza drží krok a poloha je přesně simulační, nezávisle na alpha.
	check(actors.stop_motion, "stop-motion je výchozí vzhled pohybu")
	var stepped: Dictionary = views[lem.id].pose.duplicate()
	game.call("_process", 0.4 / SimConst.TICKS_PER_SECOND)
	check(views[lem.id].pose == stepped
		and actors.actor_position(lem) == Vector2(lem.x + 0.5, lem.y),
		"stop-motion: mezi tiky se póza ani poloha nehýbou")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_M
	key.pressed = true
	game.call("_unhandled_input", key)
	check(not actors.stop_motion and not world.props.stepped and sim.replay_log.is_empty(),
		"klávesa M přepne na plynulý pohyb bez herního příkazu")
	game.call("_process", 0.0)
	var smooth: Dictionary = views[lem.id].pose.duplicate()
	game.call("_process", 0.3 / SimConst.TICKS_PER_SECOND)
	check(views[lem.id].pose != smooth, "plynulý režim: póza se mění i mezi tiky")
	game.call("_unhandled_input", key)
	check(actors.stop_motion, "druhé stisknutí M vrátí stop-motion")
	lem.has_floater = true
	sim.set_state(lem, Lemming.State.FALLER)
	check(actors.anim_for(lem) == "fall_umbrella", "padající s padákem drží složený deštník")
	lem.dir = -lem.dir
	game.call("_process", 0.0)
	game.call("_process", 0.5 / SimConst.TICKS_PER_SECOND)
	var view = actors.get("_views")[lem.id]
	check(absf(view.facing) < 1.0, "otočka postavy proběhne jako plynulé otočení papírku")
	for _i in 4:
		game.call("_process", 1.0 / SimConst.TICKS_PER_SECOND)
	check(is_equal_approx(view.facing, float(lem.dir)), "otočka skončí ve směru simulace")
	var fg := world.foreground
	var rects := fg.clump_rects()
	if not rects.is_empty():
		var rect: Rect2 = rects[0][1]
		var behind := world.camera.screen_to_logic(rect.get_center())
		var hidden := add_lemming(sim, int(behind.x), int(behind.y + 5))
		for _i in 30:
			fg.update(0.05)
		var faded := float(fg.get("_fade").get(rects[0][0], 1.0)) < 0.5
		sim.remove_lemming(hidden, false)
		check(faded, "rostlina v popředí zprůhlední, když je za ní postava")
	else:
		check(true, "rostlina v popředí zprůhlední, když je za ní postava (žádná na obrazovce)")


## Celá první mise přes skutečnou origami scénu a dotykové přidělení:
## výsledek i stav se musí shodovat s čistou simulací se stejným záznamem.
func _test_solution(scene: PackedScene) -> void:
	var game := scene.instantiate()
	root.add_child(game)
	game.set_process(false)
	var world: PaperWorld = game.get_node("PaperWorld")
	world.camera.input_enabled = false
	var sim: LevelSim = game.get("_sim")
	var acts := [false, false, false]
	var hud: Hud = game.get_node("Hud")
	for _frame in 7000:
		game.call("_process", 1.0 / 30.0)
		for lem in sim.lemmings:
			if lem.removed or lem.state != Lemming.State.WALKER:
				continue
			var skill := -1
			if not acts[0] and lem.dir == 1 and lem.x >= 170 and lem.x <= 175:
				skill = Lemming.Skill.BASHER
			elif acts[0] and not acts[1] and lem.dir == 1 and lem.x >= 280 and lem.x <= 284:
				skill = Lemming.Skill.BUILDER
			elif acts[1] and not acts[2] and lem.y <= 58 and lem.x >= 330 and lem.x <= 360:
				skill = Lemming.Skill.DIGGER
			if skill < 0:
				continue
			hud.skill_selected.emit(skill)
			world.camera.focus = Vector2(lem.x, lem.y)
			world.camera.refresh()
			game.call("_try_assign_touch", world.camera.logic_to_screen(Vector2(lem.x + 0.5, lem.y - 5)))
			var index := [Lemming.Skill.BASHER, Lemming.Skill.BUILDER, Lemming.Skill.DIGGER].find(skill)
			acts[index] = lem.state != Lemming.State.WALKER
			break
		if sim.finished:
			break
	check(sim.finished and sim.saved == 20 and acts == [true, true, true],
		"první mise přes origami scénu a dotyk: zachráněno %d z 20" % sim.saved)
	var fresh := level_one()
	var replay := SimReplay.new(fresh, sim.replay_log)
	while replay.step():
		pass
	check(replay.error.is_empty() and snapshot(fresh) == snapshot(sim),
		"zobrazení nezměnilo výsledek: replay čisté simulace je totožný")
	game.free()


## Další zkušební mise v origami scéně: přidělení klepnutím, výsledek a shoda s replayem.
func _test_other_missions(scene: PackedScene) -> void:
	var game := scene.instantiate()
	root.add_child(game)
	game.set_process(false)
	var world: PaperWorld = game.get_node("PaperWorld")
	world.camera.input_enabled = false
	var hud: Hud = game.get_node("Hud")
	var levels := ["climb_float", "miner", "bomber"]
	var ids := ["lezec-a-padak", "sikmy-tunel", "cesta-skrz-zed"]
	for index in [1, 2, 3]:
		game.call("_choose_mission", Campaign.index_of(ids[index - 1]))
		var sim: LevelSim = game.get("_sim")
		var assigned := false
		var frames := 0
		while not sim.finished and frames < 12000:
			game.call("_process", 1.0 / 30.0)
			frames += 1
			for lem in sim.lemmings:
				if lem.removed:
					continue
				var wanted: Array[int] = []
				if index == 1 and not lem.can_climb:
					wanted = [Lemming.Skill.CLIMBER, Lemming.Skill.FLOATER]
				elif index == 2 and not assigned and lem.state == Lemming.State.WALKER and lem.x == 80:
					wanted = [Lemming.Skill.MINER]
				elif index == 3 and not assigned and lem.state == Lemming.State.WALKER and lem.x == 168:
					wanted = [Lemming.Skill.BLOCKER, Lemming.Skill.BOMBER]
				for skill in wanted:
					hud.skill_selected.emit(skill)
					world.camera.focus = Vector2(lem.x, lem.y)
					world.camera.refresh()
					var at := world.camera.logic_to_screen(Vector2(lem.x + 0.5, lem.y - 5))
					game.call("_try_assign_touch", at)
				if index > 1 and not wanted.is_empty():
					assigned = lem.state != Lemming.State.WALKER
		var path := "res://levels/level_%s.tscn" % levels[index - 1]
		var level := load(path).instantiate() as LevelDefinition
		var fresh := LevelSim.new(LevelLoader.build_spec(level), LevelLoader.build_mask(level))
		level.free()
		var replay := SimReplay.new(fresh, sim.replay_log)
		while replay.step():
			pass
		var same := replay.error.is_empty() and snapshot(fresh) == snapshot(sim)
		check(sim.finished and sim.is_won() and same,
			"mise %d v origami scéně přes dotyk: %d/%d, shoda s replayem" % [
				index + 1, sim.saved, sim.spec.lemming_count])
	game.free()


## Vzhled kapitol: každá kapitola má svou krajinu, barvy terénu a počasí;
## Hřiště je louka. Mění se jen dekorace, simulace zůstává stejná.
func _test_chapter_themes(scene: PackedScene) -> void:
	var game := scene.instantiate()
	root.add_child(game)
	game.set_process(false)
	var world: PaperWorld = game.get_node("PaperWorld")
	world.camera.input_enabled = false
	world.set_quality(2)
	var ok := true
	var weather := {}
	for c in Campaign.CHAPTERS.size():
		game.call("_choose_mission", Campaign.chapter_indices(c)[0])
		var theme: String = PaperTheme.BY_CHAPTER[c]
		var data := PaperTheme.data(theme)
		var terra: Color = data["terrain"]["TERRA"]
		var material: ShaderMaterial = world.terrain.get("_material")
		# Louka na začátku nic nepřepisuje: shader má její barvy jako výchozí.
		var param: Variant = material.get_shader_parameter("TERRA")
		if param == null and theme == "louka":
			param = Vector3(terra.r, terra.g, terra.b)
		var sky: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			PaperTheme.layer_dir(theme) + "sky.json"))
		var clouds: int = (sky["clouds"] as Array).size()
		ok = ok and world.theme == theme \
			and world.layers[1].texture.resource_path.begins_with(PaperTheme.layer_dir(theme)) \
			and (param as Vector3).is_equal_approx(Vector3(terra.r, terra.g, terra.b)) \
			and world.grass.colors == data["grass"] and world.fx.weather == data["weather"] \
			and world.layers[0].drifters.size() >= clouds
		for _frame in 120:
			game.call("_process", 1.0 / SimConst.TICKS_PER_SECOND)
		var kinds := {}
		for puff in world.fx.get("_puffs"):
			kinds[puff.kind] = true
		weather[theme] = kinds
	game.call("_choose_mission", -1)
	game.set("level_scene", Campaign.PLAYGROUND)
	game.call("_load_level")
	check(ok and world.theme == "louka" and world.layers[1].texture.resource_path
		== PaperWorld.LAYER_DIR + "mountains.png",
		"každá kapitola má vlastní krajinu, barvy terénu a trávy i počasí; Hřiště je louka")
	check(weather["sopka"].has(PaperFx.Puff.Kind.SPARK)
		and weather["bourka"].has(PaperFx.Puff.Kind.RAIN)
		and not weather["louka"].has(PaperFx.Puff.Kind.RAIN),
		"sopka žhne jiskrami, na Bouřkové hoře prší, louka je bez deště")
	check(PaperTheme.lightning(193.0) > 0.9 and PaperTheme.lightning(200.0) > 0.5
		and PaperTheme.lightning(205.0) == 0.0 and PaperTheme.lightning(483.0) > 0.9,
		"blesk na Bouřkové hoře: dvojitý záblesk pravidelně podle herního času")
	game.free()


## Mise 6 v origami scéně: klepnutím lezec, stavitel, kopáč a razič; vykreslení
## vody, lávy, šipek a pasti jen čte simulaci (shoda s replayem čisté simulace).
func _test_hazard_mission(scene: PackedScene) -> void:
	var game := scene.instantiate()
	root.add_child(game)
	game.set_process(false)
	var world: PaperWorld = game.get_node("PaperWorld")
	world.camera.input_enabled = false
	var hud: Hud = game.get_node("Hud")
	game.call("_choose_mission", Campaign.index_of("voda-lava-past"))
	var sim: LevelSim = game.get("_sim")
	check(sim.spec.title == "Voda, láva a past" and sim.spec.traps.size() == 1
		and world.terrain.hazard_rect.has_point(Vector2i(240, 110))
		and world.terrain.hazard_rect.has_point(Vector2i(390, 110)),
		"mise 6 se načte s pastí a oblastí vody i lávy pro přední vrstvu")
	var hazards := PaperTerrain.build_hazards(sim.mask)
	var surface := hazards.get_pixel(240, 104)
	var above := hazards.get_pixel(240, 103)
	var arrow := hazards.get_pixel(150, 80)
	check(is_equal_approx(surface.r * 255.0, PaperTerrain.SURFACE_ZERO + PaperTerrain.SURFACE_STEP)
		and is_equal_approx(above.r * 255.0, PaperTerrain.SURFACE_ZERO - PaperTerrain.SURFACE_STEP)
		and hazards.get_pixel(390, 110).g > 0.5 and arrow.a > 0.99 and arrow.b < 0.01,
		"textura nebezpečí: hladina na horní hraně vody, láva a šipky doprava")
	var done := {}
	var opened := false
	var frames := 0
	while not sim.finished and frames < 12000:
		game.call("_process", 1.0 / 30.0)
		frames += 1
		if not opened and sim.trap_fired[0] >= 0:
			opened = world.props.trap_opening(0, float(sim.trap_fired[0]) + 1.0) < 0.1 \
				and world.props.trap_opening(0, float(sim.trap_ready[0])) > 0.6
		if sim.lemmings.is_empty():
			continue
		var hero := sim.lemmings[0]
		var ready := hero.state == Lemming.State.WALKER and hero.dir == 1 and not hero.removed
		var target: Lemming = null
		var skill := -1
		if not done.has(Lemming.Skill.CLIMBER) and not hero.removed:
			target = hero
			skill = Lemming.Skill.CLIMBER
		elif not done.has(Lemming.Skill.BUILDER) and ready and hero.x >= 224 and hero.y == 100:
			target = hero
			skill = Lemming.Skill.BUILDER
		elif done.has(Lemming.Skill.BUILDER) and not done.has(Lemming.Skill.DIGGER) and ready \
				and hero.x >= 350 and hero.y == 100:
			target = hero
			skill = Lemming.Skill.DIGGER
		elif not done.has(Lemming.Skill.BASHER) and sim.tick_count >= 400:
			for lem in sim.lemmings:
				if lem.id != 0 and not lem.removed and lem.state == Lemming.State.WALKER \
						and lem.dir == 1 and lem.x >= 134 and lem.x < 140:
					target = lem
					skill = Lemming.Skill.BASHER
					break
		if target == null:
			continue
		var before := sim.skills[skill] as int
		hud.skill_selected.emit(skill)
		world.camera.focus = Vector2(target.x, target.y)
		world.camera.refresh()
		var at := world.camera.logic_to_screen(Vector2(target.x + 0.5, target.y - 5))
		game.call("_try_assign_touch", at)
		if sim.skills[skill] < before:
			done[skill] = sim.tick_count
	var fresh_level := HAZARD_LEVEL.instantiate()
	var fresh := LevelSim.new(LevelLoader.build_spec(fresh_level), LevelLoader.build_mask(fresh_level))
	fresh_level.free()
	var replay := SimReplay.new(fresh, sim.replay_log)
	while replay.step():
		pass
	var same := replay.error.is_empty() and snapshot(fresh) == snapshot(sim)
	check(sim.finished and sim.is_won() and done.size() == 4 and same,
		"mise 6 v origami scéně přes dotyk: %d/%d, shoda s replayem" % [
			sim.saved, sim.spec.lemming_count])
	check(opened, "past se po sežrání zavře a před dobitím zase otevře")
	game.free()


## Efekty nebezpečí: bubliny jednou za tik (pauza je zastaví), kruhy, plovoucí
## klobouk, kouř; dopad z pádu krátce zplácne postavu. Jen vzhled.
func _test_hazard_effects() -> void:
	var sim := fixture(5)
	sim.mask.erase_rect(70, 80, 20, 20)
	paint_rect(sim.mask, Rect2i(70, 84, 20, 16), TerrainMask.Kind.WATER)
	var lem := add_lemming(sim, 72, 84)
	sim.set_state(lem, Lemming.State.DROWNING)
	var fx := PaperFx.new()
	fx.clear()
	fx.sim = sim
	fx.handle_events(sim.take_events())
	var ripples := fx._puffs.filter(func(p: PaperFx.Puff) -> bool:
		return p.kind == PaperFx.Puff.Kind.RIPPLE)
	check(ripples.size() == 2, "šplouchnutí rozběhne po hladině dva kruhy")
	var bubbles := 0
	for _frame in 6:
		fx.advance(0.0)
	bubbles = fx._puffs.filter(func(p: PaperFx.Puff) -> bool:
		return p.kind == PaperFx.Puff.Kind.BUBBLE).size()
	check(bubbles <= 1, "v pauze (stejný tik) bubliny nepřibývají")
	for _tick in 8:
		sim.tick()
		fx.advance(1.0 / 17.0)
	bubbles = fx._puffs.filter(func(p: PaperFx.Puff) -> bool:
		return p.kind == PaperFx.Puff.Kind.BUBBLE).size()
	check(bubbles >= 3, "topící se postava pouští bubliny (%d)" % bubbles)
	fx.handle_events([{"type": "drowned", "x": 75, "y": 84, "dir": 1, "id": 0, "value": 0}])
	var hats := fx._puffs.filter(func(p: PaperFx.Puff) -> bool:
		return p.kind == PaperFx.Puff.Kind.HAT)
	check(hats.size() == 1 and absf((hats[0] as PaperFx.Puff).surface - 84.0) < 0.01,
		"po utonutí zbude na hladině plovoucí klobouk")
	fx.handle_events([{"type": "burned", "x": 75, "y": 80, "dir": 1, "id": 1, "value": 0}])
	check(fx._puffs.any(func(p: PaperFx.Puff) -> bool: return p.kind == PaperFx.Puff.Kind.SMOKE),
		"z uhořelé postavy stoupá kouř")
	fx.free()
	var actors := PaperActors.new()
	var falls := fixture(5)
	var faller := add_lemming(falls, 60, 70)
	falls.set_state(faller, Lemming.State.FALLER)
	actors.setup(falls)
	actors.update_views()
	while faller.state == Lemming.State.FALLER and falls.tick_count < 40:
		falls.tick()
		actors.update_views()
	var view: PaperActors.ActorView = actors._views[faller.id]
	var squashed := float(view.root[4]) < 0.9
	falls.tick()
	falls.tick()
	falls.tick()
	actors.update_views()
	view = actors._views[faller.id]
	check(squashed and float(view.root[4]) > 0.94, "dopad z pádu postavu krátce zplácne a narovná")
	actors.free()


## Tráva roste vzhůru z původního povrchu, kývá se jen špičkou a je vázaná na masku.
func _test_grass() -> void:
	var sim := fixture(5)
	var surface := PaperTerrain.exposed_surface(PaperTerrain.build_static(sim.mask))
	var on_top := surface.all(func(p: Vector2i) -> bool: return p.y == 80)
	check(surface.size() == 160 and on_top, "tráva má místo jen na původním povrchu nad nebem")
	var grass := PaperGrass.new()
	grass.setup(sim.mask, surface)
	check(grass.tufts.size() > 30 and grass.tufts.size() < 90, "trsy trávy rostou v části sloupců")
	var tuft: Vector3i = grass.tufts[3]
	grass.time = 0.0
	var tip_a := grass.blade_tip(tuft, 0)
	grass.time = 20.0
	var tip_b := grass.blade_tip(tuft, 0)
	check(tip_a.y < tuft.y and tip_b.y < tuft.y and absf(tip_a.x - tip_b.x) > 0.05,
		"stéblo míří vzhůru a ve větru se hýbe jeho špička")
	check(grass.tuft_visible(tuft), "trs na neporušené zemi je vidět")
	sim.mask.add_brick_row(tuft.x - 1, tuft.x + 1, tuft.y - 1)
	check(not grass.tuft_visible(tuft), "trs pod položenou cihlou zmizí")
	var other: Vector3i = grass.tufts[10]
	sim.mask.erase_rect(other.x - 1, other.y - 2, 3, 6)
	check(not grass.tuft_visible(other), "trs zmizí s vykopanou zemí")
	grass.free()
	var level := HAZARD_LEVEL.instantiate()
	var mask := LevelLoader.build_mask(level)
	level.free()
	var points := PaperTerrain.exposed_surface(PaperTerrain.build_static(mask))
	var wet := points.filter(_under_liquid.bind(mask))
	check(wet.is_empty(), "pod vodou ani lávou tráva neroste")


## Leží bod povrchu na dně jezírka nebo lávové jámy mise 6 (nebo přímo pod hladinou)?
func _under_liquid(p: Vector2i, mask: TerrainMask) -> bool:
	var pool := p.x > 228 and p.x < 253 and p.y > 104
	var pit := p.x > 370 and p.x < 406 and p.y > 103
	return pool or pit or mask.special_at(p.x, p.y - 1) != TerrainMask.Special.NONE


## Čitelnost, hloubka a živá krajina: jen vzhled, řízený herním časem.
func _test_living_scene(scene: PackedScene) -> void:
	var game := scene.instantiate()
	root.add_child(game)
	game.set_process(false)
	var world: PaperWorld = game.get_node("PaperWorld")
	world.camera.input_enabled = false
	game.call("_choose_mission", Campaign.index_of("prvni-kroky"))
	var sim: LevelSim = game.get("_sim")
	check(is_equal_approx(world.camera.zoom_factor, 2.0),
		"výchozí pohled je bližší, postavy jsou čitelné bez přibližování")
	var silhouette := world.actors.get_node("Silhouette") as Node2D
	check(silhouette != null and silhouette.show_behind_parent and silhouette.material != null,
		"postavy mají pod sebou světlý okraj a vržený stín")
	var sky := world.layers[0]
	var clouds := sky.drifters.filter(func(d: Dictionary) -> bool: return d.get("flap", 0) == 0)
	var birds := sky.drifters.filter(func(d: Dictionary) -> bool: return d.get("flap", 0) > 0)
	check(clouds.size() == 5 and birds.size() == 3, "na obloze je 5 mraků a hejnko 3 ptáčků")
	for _frame in 40:
		game.call("_process", 1.0 / 17.0)
	var t0 := sky.time
	var cloud_x := sky.drifter_position(clouds[0]).x
	var poses := {}
	for _frame in 30:
		game.call("_process", 1.0 / 17.0)
		poses[sky.drifter_frame(birds[0])] = true
	var moved := fposmod(sky.drifter_position(clouds[0]).x - cloud_x, 2800.0)
	check(sky.time > t0 and moved > 0.5 and moved < 20.0, "mraky pomalu plují s herním časem")
	check(poses.size() == 3, "ptáček mává křídly (tři pózy)")
	check(world.layers[1].haze > world.layers[3].haze and world.layers[3].haze > 0.0,
		"vzdálenější vrstvy jsou víc v oparu")
	game.call("_toggle_pause")
	var paused_time := sky.time
	var petals := world.fx._puffs.size()
	for _frame in 20:
		game.call("_process", 1.0 / 17.0)
	check(sky.time == paused_time and world.fx._puffs.size() == petals and sim.replay_log.is_empty(),
		"pauza zastaví mraky, ptáky i lístky; dekorace nevytváří herní příkazy")
	game.free()
	await process_frame


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
