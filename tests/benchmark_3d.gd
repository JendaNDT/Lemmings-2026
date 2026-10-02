extends SimTest
## Opakovatelná CPU zátěž prezentace. Nenahrazuje měření FPS na cílové grafice.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var sim := fixture(200)
	# Rozšířená mapa se souběžným kopáním přes několik hranic oblastí.
	sim.mask = TerrainMask.new(640, 200)
	sim.spec.width = 640
	sim.spec.height = 200
	paint_rect(sim.mask, Rect2i(0, 80, 640, 120))
	for index in 200:
		var lem := add_lemming(sim, 10 + (index * 3) % 615, 80)
		if index % 20 == 0:
			sim.assign_skill(lem, Lemming.Skill.DIGGER)
		elif index % 20 == 10:
			sim.assign_skill(lem, Lemming.Skill.BUILDER)
	var world := ClayWorld.new()
	root.add_child(world)
	world.setup(sim)
	world.camera.input_enabled = false
	world.update_frame(0, sim.take_events(), 0)
	var frames: Array[int] = []
	var rebuilds: Array[int] = []
	var max_regions := 0
	for index in 240:
		var start := Time.get_ticks_usec()
		sim.tick()
		world.update_frame(0.5, sim.take_events(), 1.0 / SimConst.TICKS_PER_SECOND)
		frames.append(Time.get_ticks_usec() - start)
		max_regions = maxi(max_regions, world.terrain.last_rebuilt.size())
		if world.terrain.last_update_usec > 0:
			rebuilds.append(world.terrain.last_update_usec)
	frames.sort()
	rebuilds.sort()
	var report := {
		"initial_actors": 200, "ticks": sim.tick_count,
		"cpu_frame_p50_usec": frames[frames.size() / 2],
		"cpu_frame_p95_usec": frames[int(frames.size() * 0.95)],
		"cpu_frame_max_usec": frames.back(),
		"terrain_p95_usec": rebuilds[int(rebuilds.size() * 0.95)],
		"terrain_max_usec": rebuilds.back(),
		"max_regions_per_update": max_regions,
		"total_regions": world.terrain.chunks.size(),
		"note": "CPU simulation + geometry + posing; GPU and target-device FPS excluded",
	}
	print("BENCHMARK_3D ", JSON.stringify(report))
	check(sim.tick_count == 240 and not rebuilds.is_empty(),
		"zátěž provedla 240 tiků se změnami terénu")
	check(max_regions < world.terrain.chunks.size(), "souběžná práce neobnovuje celý level")
	world.free()
	await process_frame
	finish()
