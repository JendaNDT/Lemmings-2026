extends SimTest
## Geometrie skutečných meshů, projekce kamery a celé řešení přes novou scénu.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_geometry()
	var scene := load("res://main/game_3d.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	game.set_process(false)
	var world: ClayWorld = game.get_node("ClayWorld")
	world.camera.input_enabled = false
	_test_camera(world.camera)
	await _test_input(game, world)
	_test_solution(game, world)
	game.free()
	await process_frame
	finish()


func _test_geometry() -> void:
	var mask := TerrainMask.new(70, 48)
	paint_rect(mask, Rect2i(2, 8, 66, 35))
	paint_rect(mask, Rect2i(35, 15, 7, 8), TerrainMask.Kind.STEEL)
	mask.erase_rect(14, 17, 32, 10)
	var terrain := ClayTerrain.new()
	root.add_child(terrain)
	terrain.setup(mask)
	check(_mesh_matches(terrain), "mesh přesně pokrývá masku včetně jeskyně a oceli")
	var before := terrain.total_rebuilds
	terrain.sync()
	check(terrain.total_rebuilds == before, "beze změny se nepřestaví žádná oblast")
	mask.erase_rect(8, 11, 2, 2)
	terrain.sync()
	check(terrain.last_rebuilt == [0], "malý zásah mění jedinou oblast")
	mask.erase_rect(32, 10, 1, 2)
	terrain.sync()
	check(terrain.last_rebuilt == [0, 1], "zásah na švu obnoví oba sousední boky")
	check(_mesh_matches(terrain), "po řezu na švu nejsou mezery ani vnitřní stěny")
	mask.add_brick_row(24, 38, 5)
	terrain.sync()
	check(_mesh_matches(terrain), "oddělené cihly mají úplný povrch a správný materiál")
	mask.erase_circle(30, 34, 8)
	terrain.sync()
	check(_mesh_matches(terrain), "kruhový řez zachová přesnou masku a uzavřené boky")
	var second := ClayTerrain.new()
	root.add_child(second)
	second.setup(mask)
	mask.erase_rect(10, 30, 1, 1)
	terrain.sync()
	second.sync()
	check(_mesh_matches(terrain) and _mesh_matches(second), "dva čtenáři nespotřebují změny terénu")
	terrain.free()
	second.free()


func _mesh_matches(terrain: ClayTerrain) -> bool:
	var mask := terrain.mask
	var coverage := PackedInt32Array()
	coverage.resize(mask.width * mask.height)
	var edge_area := 0.0
	for chunk in terrain.chunks:
		if chunk.mesh == null:
			continue
		for surface in chunk.mesh.get_surface_count():
			var arrays := chunk.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for tri in range(0, indices.size(), 3):
				var a := vertices[indices[tri]]
				var b := vertices[indices[tri + 1]]
				var c := vertices[indices[tri + 2]]
				var cross := (b - a).cross(c - a)
				if cross.dot(normals[indices[tri]]) >= 0:
					return false
				if absf(normals[indices[tri]].z) < 0.5:
					edge_area += cross.length() * 0.5
			for index in range(0, vertices.size(), 4):
				if normals[index].z < 0.9:
					continue
				var a := ClaySpace.to_logic(vertices[index]).round()
				var c := ClaySpace.to_logic(vertices[index + 2]).round()
				var material := chunk.mesh.surface_get_material(surface) as ShaderMaterial
				var kind: int = material.get_shader_parameter("material_kind")
				for y in range(int(a.y), int(c.y)):
					for x in range(int(a.x), int(c.x)):
						var cell := y * mask.width + x
						coverage[cell] += 1
						if mask.data[cell * 4 + 1] != 0 and kind != 2:
							return false
						if mask.data[cell * 4 + 2] != 0 and kind != 3:
							return false
	var edges := 0
	for y in mask.height:
		for x in mask.width:
			var solid := mask.data[(y * mask.width + x) * 4] != 0
			if coverage[y * mask.width + x] != int(solid):
				return false
			if not solid:
				continue
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var p: Vector2i = Vector2i(x, y) + offset
				if not Rect2i(0, 0, mask.width, mask.height).has_point(p) \
						or mask.data[(p.y * mask.width + p.x) * 4] == 0:
					edges += 1
	return absf(edge_area - edges * ClaySpace.UNIT * ClaySpace.DEPTH) < 0.01


func _test_camera(camera: ClayCamera) -> void:
	for zoom in [1.0, 1.7, 3.2]:
		camera.zoom_factor = zoom
		camera.focus = Vector2(320, 100)
		camera.refresh()
		var matches := true
		for point in [Vector2(10, 10), Vector2(90, 70), Vector2(380, 110), Vector2(630, 190)]:
			var projected := camera.screen_to_logic(camera.logic_to_screen(point))
			matches = matches and projected.distance_to(point) < 0.01
		check(matches, "projekce a zpětný výběr sedí při zoomu %.1f" % zoom)
		var before := camera.focus
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(500, 300)
		motion.relative = Vector2(20, -10)
		camera.set("_dragging", true)
		camera.call("_unhandled_input", motion)
		camera.set("_dragging", false)
		# Pro vstupní test je kamera dočasně povolena níže.
		check(camera.focus == before, "vypnutý kamerový vstup nemění stav")
		camera.input_enabled = true
		camera.set("_dragging", true)
		camera.call("_unhandled_input", motion)
		check(camera.focus.x < before.x, "tažení myši posune kameru správným směrem")
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_RIGHT
		camera.call("_input", release)
		check(not camera.get("_dragging"), "uvolnění nad HUDem ukončí tažení")
		camera.input_enabled = false
	camera.zoom_factor = 1
	camera.refresh()


func _test_input(game: Node, world: ClayWorld) -> void:
	var sim: LevelSim = game.get("_sim")
	world.camera.focus = Vector2(100, 100)
	world.camera.refresh()
	var lem := add_lemming(sim, 100, 70)
	game.set("_paused", true)
	game.call("_select_skill", Lemming.Skill.BLOCKER)
	game.call("_process", 0.0)
	var point := world.camera.logic_to_screen(Vector2(lem.x + 0.5, lem.y - 5))
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await process_frame
	check(game.call("logic_position", point).distance_to(Vector2(100.5, 65)) < 0.1,
		"poloha vstupní události se převede do herní roviny")
	var click := InputEventMouseButton.new()
	click.position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click, true)
	await process_frame
	check(lem.state == Lemming.State.BLOCKER and sim.replay_log.size() == 1,
		"kliknutí ve 3D přidělí dovednost přes společný příkaz")
	game.call("_process", 0.0)
	var actor: ClayActor = world.actors[lem.id]
	var frozen := actor.pose_time
	game.call("_process", 0.5)
	check(actor.pose_time == frozen and sim.tick_count == 0, "pauza zastaví simulaci i 3D pózu")
	for state in [Lemming.State.BUILDER, Lemming.State.BASHER, Lemming.State.DIGGER]:
		lem.state = state
		lem.state_ticks = SimConst.BUILDER_BRICK_PHASE if state == Lemming.State.BUILDER else 2
		actor.sync(lem, 0)
		check(is_equal_approx(actor.pose_time / actor.player.get_animation(actor.clip).length, 0.5),
			"pracovní kontakt nastane v tiku změny terénu: %s" % actor.clip)
	game.call("_load_level")
	check(world.actors.is_empty() and world.fx.get_child_count() == 0,
		"restart odstraní postavy, nástroje a efekty")


func _test_solution(game: Node, world: ClayWorld) -> void:
	var sim: LevelSim = game.get("_sim")
	var reference := level_one()
	var actions := [false, false, false]
	var largest_rebuild := 0
	for _frame in 5100:
		game.call("_process", 1.0 / SimConst.TICKS_PER_SECOND)
		reference.tick()
		largest_rebuild = maxi(largest_rebuild, world.terrain.last_rebuilt.size())
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
				var applied := sim.assign_skill(lem, skill)
				applied = reference.assign_skill(reference.lemmings[lem.id], skill) and applied
				check(applied,
					"řešení přidělí %s v obou prezentacích" % Lemming.SKILL_NAMES[skill])
		if sim.finished:
			break
	check(sim.finished and sim.saved == 20 and sim.is_won(), "celý 2.5D level zachrání 20 z 20")
	check(snapshot(sim) == snapshot(reference), "3D herní smyčka přesně zachová stav čisté simulace")
	check(_mesh_matches(world.terrain), "výsledná geometrie odpovídá tunelu, schodům a svislé šachtě")
	check(largest_rebuild <= 4, "během řešení se mění nejvýše čtyři oblasti najednou")
