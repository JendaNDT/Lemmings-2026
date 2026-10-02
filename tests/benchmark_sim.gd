extends SimTest
## Opakovatelná zátěž čisté simulace. Neměří renderer ani FPS hry.


func _initialize() -> void:
	var sim := fixture(200)
	sim.spec.hatches.append(Vector2i(60, 70))
	sim.change_release_rate(99)
	var durations: Array[int] = []
	var started := Time.get_ticks_usec()
	for _tick in 1700:
		var before := Time.get_ticks_usec()
		sim.tick()
		durations.append(Time.get_ticks_usec() - before)
		sim.take_events()
	var elapsed := Time.get_ticks_usec() - started
	durations.sort()
	print(JSON.stringify({
		"scenario": "200-walkers-1700-ticks-v1", "godot": Engine.get_version_info().string,
		"os": OS.get_name(), "cpu": OS.get_processor_name(), "total_ms": elapsed / 1000.0,
		"tick_p95_ms": durations[1614] / 1000.0, "tick_max_ms": durations[-1] / 1000.0,
		"spawned": sim.spawned, "lost": sim.lost, "ticks": sim.tick_count,
	}))
	check(sim.spawned == 200 and sim.lost == 0 and sim.tick_count == 1700 and not sim.finished,
		"zátěžový scénář: 200 živých lumíků, 1700 tiků")
	finish()
