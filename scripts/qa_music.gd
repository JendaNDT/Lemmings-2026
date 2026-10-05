extends SceneTree
## Skutečný mix čtyř skladeb: grafický Godot v režimu Movie Maker (60 FPS).
## --script res://scripts/qa_music.gd -- --capture-dir=/tmp/music-qa
## Výstup: stereo WAV sběrnice Master a report časových úseků ve snímcích.
## Headless nemixuje zvuk; tento scénář jej záměrně odmítne.

var _music: GameMusic
var _record: AudioEffectRecord
var _dir := "res://build/music-qa"
var _frame := 0
var _starts := 0
var _failed := false
var _segments: Array[Dictionary] = []


func _initialize() -> void:
	root.size = Vector2i(320, 180)
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty():
		push_error("Hudební QA vyžaduje grafický Godot s --write-movie a 60 FPS.")
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_dir = arg.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(_dir)
	GameSettings.new().apply_audio()
	_music = GameMusic.new()
	root.add_child(_music)
	_music.track_started.connect(func(_slot: int) -> void: _starts += 1)
	_record = AudioEffectRecord.new()
	_record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, _record)
	_record.set_recording_active(true)
	for i in 4:
		_music.play_mission(Campaign.mission(i)["id"])
		await _segment("fade_%d" % (i + 1), 60)
		_active().seek(8.0)
		await _segment("track_%d" % (i + 1), 120)
		var expected := _starts + 1
		_active().seek(_active().stream.get_length() - 1.8)
		await _segment("loop_%d" % (i + 1), 210)
		_expect(_starts == expected and _music.current_slot == i,
			"skladba %d skutečně přešla přes konec do vlastní smyčky" % (i + 1))
	var bus := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_mute(bus, true)
	await _segment("muted", 60)
	AudioServer.set_bus_mute(bus, false)
	AudioServer.set_bus_volume_db(bus, linear_to_db(0.25))
	await _segment("quiet", 120)
	_music.stop_music()
	await _segment("stop_fade", 60)
	await _segment("stopped", 60)
	_record.set_recording_active(false)
	var recording := _record.get_recording()
	_expect(recording != null and recording.get_length() > 30.0,
		"záznam skutečného mixu má více než třicet sekund")
	if recording != null:
		_expect(recording.save_to_wav(_dir.path_join("music-mix.wav")) == OK,
			"záznam mixu uložen")
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	_music.queue_free()
	await process_frame
	var report := {"ok": not _failed, "fps": 60, "frames": _frame,
		"starts": _starts, "segments": _segments}
	var file := FileAccess.open(_dir.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("MUSIC_QA ", "FAIL" if _failed else "OK")
	quit(1 if _failed else 0)


func _active() -> AudioStreamPlayer:
	for child in _music.get_children():
		if child is AudioStreamPlayer and child.playing:
			return child
	return null


func _segment(label: String, frames: int) -> void:
	_segments.append({"label": label, "start": _frame, "end": _frame + frames})
	for _i in frames:
		await process_frame
		_frame += 1


func _expect(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
	print("[", "OK" if ok else "CHYBA", "] ", message)
