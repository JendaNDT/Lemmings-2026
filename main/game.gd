extends Node
## Hlavní scéna – „lepidlo“ mezi simulací, grafikou a ovládáním.
##
## Každý snímek: přičte uplynulý čas, provede tolik pevných kroků simulace,
## kolik se jich do něj vejde, a pak předá grafice, jak daleko jsme mezi tiky.
## Výsledky zapisuje do postupu (Progress), nastavení čte z GameSettings.
## Spouští ji App z menu; samostatně (editor, testy) hraje s výchozím
## nastavením a postupem jen v paměti.

## Hráč chce opustit misi: "main_menu" nebo "levels" (rozehraný pokus je uložený).
signal leave_requested(target: String)

const MISSIONS := Campaign.SCENES

## Který level se hraje. Dá se přepnout v Inspectoru.
@export var level_scene: PackedScene = Campaign.SCENES[0]
## Uzel vlastní prezentace (2D origami PaperWorld).
## Prázdná cesta = původní jednoduché 2D zobrazení pro porovnání.
@export var presentation_path := NodePath()

## Nastavení a postup hráče (předá App před přidáním do stromu).
var settings: GameSettings
var progress: Progress
## Obnovit rozehraný pokus z `progress.suspended` (jen při prvním načtení).
var resume_suspended := false
var _sim: LevelSim
var _level: LevelDefinition
var _selected_skill := -1
var _paused := false
var _fast := false
var _accumulator := 0.0
var _result_shown := false
var _touch: TouchControls
var _pause_before_confirmation := false
var _pause_before_menu := false
var _mission_id := ""
## Poslední načtení obnovilo rozehraný pokus (pro testy a ladění).
var _resumed := false
## Zvuky (efekty podle událostí simulace, okolí, rozhraní). Hudba přijde později.
var _audio: GameAudio

@onready var _world: Node2D = $World
@onready var _terrain_view: TerrainView = $World/TerrainView
@onready var _lemmings_view: LemmingsView = $World/LemmingsView
@onready var _fx_view: FxView = $World/FxView
@onready var _camera: GameCamera = $World/GameCamera
@onready var _hud: Hud = $Hud
## Prezentace s metodami setup(), update_frame(), highlight() a kamerou
## (screen_to_logic, logic_to_screen, pan_screen, zoom_at). Typ záměrně volný.
@onready var _view = null if presentation_path.is_empty() else get_node_or_null(presentation_path)


func _ready() -> void:
	if settings == null:
		settings = GameSettings.new()
	if progress == null:
		progress = Progress.new()
	settings.changed.connect(_on_setting_changed)
	_hud.settings = settings
	_hud.menu_pressed.connect(_open_pause_menu)
	_hud.menu_action.connect(_on_menu_action)
	_hud.skill_selected.connect(_select_skill)
	_hud.release_rate_step.connect(_change_release_rate)
	_hud.pause_pressed.connect(_toggle_pause)
	_hud.speed_pressed.connect(_toggle_speed)
	_hud.restart_pressed.connect(_restart)
	_hud.nuke_requested.connect(_request_nuke)
	_hud.nuke_decided.connect(_decide_nuke)
	_hud.sound_pressed.connect(_toggle_sound)
	_audio = GameAudio.new()
	_audio.name = "Audio"
	add_child(_audio)
	_camera.top_padding = Hud.TOP_BAR_HEIGHT
	_camera.bottom_padding = Hud.BOTTOM_BAR_HEIGHT
	if _view != null:
		_world.visible = false
		$Background.visible = false
		_camera.enabled = false
		for node in [_camera, _terrain_view, _lemmings_view, _fx_view]:
			node.set_process(false)
			node.set_process_unhandled_input(false)
		_touch = TouchControls.new()
		_touch.camera = _view.camera
		_touch.tapped = _try_assign_touch
	_apply_settings()
	_load_level()


func _load_level() -> void:
	_hud.close_nuke_confirmation()
	_hud.close_pause_menu()
	if _touch != null:
		_touch.clear()
	if _level != null:
		_world.remove_child(_level)
		_level.queue_free()
	_level = level_scene.instantiate() as LevelDefinition
	_world.add_child(_level)
	_world.move_child(_level, 0)  # dekorace levelu vzadu, terén a lumíci před ní

	var spec := LevelLoader.build_spec(_level)
	var mask := LevelLoader.build_mask(_level)
	_sim = LevelSim.new(spec, mask)
	_mission_id = _level.level_id
	_resumed = false
	if resume_suspended and not _mission_id.is_empty() \
			and progress.suspended.get("mission", "") == _mission_id:
		# Rozehraný pokus: přehrát uložené příkazy až do uloženého tiku.
		_resumed = progress.restore_suspended(_sim)
		if not _resumed:
			_sim = LevelSim.new(LevelLoader.build_spec(_level), LevelLoader.build_mask(_level))
		_sim.take_events()
	resume_suspended = false
	LevelLoader.hide_terrain_shapes(_level)
	if not _resumed and not _mission_id.is_empty():
		progress.record_start(_mission_id)
	progress.save()

	var focus := Vector2(spec.width / 2.0, spec.height / 2.0)
	if not spec.hatches.is_empty():
		focus = Vector2(spec.hatches[0])
	if _view != null:
		_view.setup(_sim)
	else:
		_terrain_view.setup(mask)
		_lemmings_view.setup(_sim)
		_fx_view.clear()
		_camera.setup(Vector2(spec.width, spec.height), focus)
	_hud.setup(_sim)
	_audio.setup(_sim, _logic_to_audio)

	# Obnovený pokus začne v pauze, ať se hráč nejdřív rozkouká.
	_paused = _resumed
	_fast = false
	_accumulator = 0.0
	_result_shown = false
	var skills := _hud.visible_skills()
	_select_skill(skills[0] if not skills.is_empty() else -1, false)


func _process(delta: float) -> void:
	if _sim == null:
		return
	var tick_time := 1.0 / SimConst.TICKS_PER_SECOND
	if not _paused and not _sim.finished:
		var speed := SimConst.FAST_FORWARD_MULTIPLIER if _fast else 1.0
		_accumulator += delta * speed
		var steps := 0
		while _accumulator >= tick_time and steps < 8:
			_sim.tick()
			_accumulator -= tick_time
			steps += 1
		_accumulator = minf(_accumulator, tick_time)

	var events := _sim.take_events()
	_audio.update(events, delta)
	var alpha := clampf(_accumulator / tick_time, 0.0, 1.0)
	if _view != null:
		var visual_delta := 0.0 if _paused or _sim.finished else delta * \
			(SimConst.FAST_FORWARD_MULTIPLIER if _fast else 1.0)
		_view.update_frame(alpha, events, visual_delta)
	else:
		_fx_view.handle_events(events)
		_lemmings_view.alpha = alpha

	var hovered := _sim.find_lemming_at(mouse_logic_position(), _selected_skill)
	if _view != null:
		_view.highlight(hovered)
	else:
		_lemmings_view.hovered = hovered
	var cursor := Input.CURSOR_CROSS if hovered != null else Input.CURSOR_ARROW
	if Input.get_current_cursor_shape() != cursor:
		Input.set_default_cursor_shape(cursor)

	_hud.refresh(_paused, SimConst.FAST_FORWARD_MULTIPLIER if _fast else 1.0)
	if _sim.finished and not _result_shown:
		_result_shown = true
		_hud.show_result(_sim, _record_result())
		_audio.play_ui("win" if _sim.is_won() else "lose")


func _unhandled_input(event: InputEvent) -> void:
	var escape: bool = event is InputEventKey and event.pressed and not event.echo \
		and event.physical_keycode == KEY_ESCAPE
	if _hud.confirmation_open():
		if escape:
			_decide_nuke(false)
		return
	if _hud.pause_menu_open() or _hud.result_open():
		if escape and _hud.pause_menu_open():
			_on_menu_action("resume")
		return
	if escape:
		_open_pause_menu()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if _touch != null and mb.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_try_assign(mb.position)
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		var code := key.physical_keycode
		if code >= KEY_1 and code <= KEY_9:
			var skills := _hud.visible_skills()
			var index := int(code - KEY_1)
			if index < skills.size():
				_select_skill(skills[index])
		match code:
			KEY_SPACE, KEY_P:
				_toggle_pause()
			KEY_F:
				_toggle_speed()
			KEY_R:
				_restart()
			KEY_T:
				_toggle_sound()
			KEY_N:
				_request_nuke()
			KEY_M:
				# Jen vzhled: stop-motion ↔ plynulý pohyb (prezentace, která ho umí).
				if _view != null and _view.has_method("toggle_stop_motion"):
					_view.toggle_stop_motion()
			KEY_MINUS, KEY_KP_SUBTRACT:
				_change_release_rate(-1)
			KEY_EQUAL, KEY_KP_ADD:
				_change_release_rate(1)


func _input(event: InputEvent) -> void:
	if _touch != null and not _result_shown and not _hud.confirmation_open() \
			and not _hud.pause_menu_open():
		_touch.handle(event, get_viewport().get_visible_rect().size)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_paused = true
		_pause_before_confirmation = true
		_pause_before_menu = true
		if _touch != null:
			_touch.clear()
		# Telefon může aplikaci na pozadí ukončit: pokus i nastavení uložit hned.
		_suspend_if_running()
		settings.save()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_suspend_if_running()
		settings.save()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _hud.confirmation_open():
			_decide_nuke(false)
		elif _hud.settings_open():
			_hud.close_settings()
		elif _hud.pause_menu_open():
			_on_menu_action("resume")
		elif _hud.result_open():
			_on_menu_action("levels")
		else:
			_open_pause_menu()


func _try_assign_touch(screen_point: Vector2) -> void:
	if _selected_skill < 0 or _sim.finished or _hud.confirmation_open() \
			or _hud.pause_menu_open():
		return
	var best: Lemming = null
	var best_distance := settings.tap_reach
	# Větší dotykový dosah, ale stále jen mezi cíli, jimž lze dovednost přidělit.
	for lem in _sim.lemmings:
		if not _sim.can_assign(lem, _selected_skill):
			continue
		var position: Vector2 = _view.camera.logic_to_screen(Vector2(lem.x + 0.5, lem.y - 5))
		var distance := screen_point.distance_to(position)
		if distance < best_distance:
			best = lem
			best_distance = distance
	if best != null:
		_sim.assign_skill(best, _selected_skill)
	elif _nearest_lemming_distance(screen_point) < settings.tap_reach:
		# Klepnutí na postavu, které dovednost přidělit nejde (už ji má, došly kusy…).
		_audio.play_ui("deny")


func _try_assign(screen_point: Vector2) -> void:
	if _selected_skill < 0 or _sim.finished or _hud.confirmation_open() \
			or _hud.pause_menu_open():
		return
	var lem := _sim.find_lemming_at(logic_position(screen_point), _selected_skill)
	if lem != null and not _sim.assign_skill(lem, _selected_skill):
		_audio.play_ui("deny")


func _nearest_lemming_distance(screen_point: Vector2) -> float:
	var best := INF
	for lem in _sim.lemmings:
		if not lem.removed:
			var position: Vector2 = _view.camera.logic_to_screen(Vector2(lem.x + 0.5, lem.y - 5))
			best = minf(best, screen_point.distance_to(position))
	return best


## Kde zvuk zní: místo v prostoru, ve kterém poslouchá obrazovka.
func _logic_to_audio(point: Vector2) -> Vector2:
	if _view != null:
		return _view.camera.logic_to_screen(point)
	return _lemmings_view.get_global_transform() * point


func mouse_logic_position() -> Vector2:
	return logic_position(get_viewport().get_mouse_position())


func logic_position(screen_point: Vector2) -> Vector2:
	if _view != null:
		return _view.camera.screen_to_logic(screen_point)
	return _lemmings_view.get_global_transform_with_canvas().affine_inverse() * screen_point


func _select_skill(skill: int, by_player := true) -> void:
	if by_player and skill != _selected_skill:
		_audio.play_ui("select")
	_selected_skill = skill
	_hud.select_skill(skill)


func _change_release_rate(delta: int) -> void:
	if _sim.change_release_rate(delta):
		_audio.play_ui("tick")


func _toggle_pause() -> void:
	_paused = not _paused
	_audio.play_ui("pause" if _paused else "resume")


func _toggle_speed() -> void:
	_fast = not _fast
	_audio.play_ui("click")


func _toggle_sound() -> void:
	settings.set_value("muted", not settings.muted)
	settings.save()


func _restart() -> void:
	_audio.play_ui("click")
	_load_level()


func _choose_mission(index: int) -> void:
	if index < 0 or index >= Campaign.count():
		return
	level_scene = Campaign.SCENES[index]
	_audio.play_ui("click")
	_load_level()


func _request_nuke() -> void:
	if _sim.finished or _sim.nuking or _hud.confirmation_open() or _hud.pause_menu_open():
		return
	if not settings.confirm_nuke:
		_sim.start_nuke()
		return
	_pause_before_confirmation = _paused
	_paused = true
	if _touch != null:
		_touch.clear()
	_audio.play_ui("click")
	_hud.show_nuke_confirmation()


func _decide_nuke(confirmed: bool) -> void:
	if not _hud.confirmation_open():
		return
	_hud.close_nuke_confirmation()
	if confirmed:
		_sim.start_nuke()
	else:
		_audio.play_ui("click")
	_paused = _pause_before_confirmation


## Pauzovací menu (tlačítko Menu, Esc, Zpět na Androidu). Čas stojí.
func _open_pause_menu() -> void:
	if _result_shown or _hud.confirmation_open() or _hud.pause_menu_open():
		return
	_pause_before_menu = _paused
	_paused = true
	if _touch != null:
		_touch.clear()
	_audio.play_ui("pause")
	_hud.show_pause_menu()


func _on_menu_action(action: String) -> void:
	match action:
		"resume":
			_hud.close_pause_menu()
			_paused = _pause_before_menu
			_audio.play_ui("resume")
		"restart":
			_restart()
		"next":
			var index := Campaign.index_of(_mission_id)
			if index >= 0 and index + 1 < Campaign.count():
				_choose_mission(index + 1)
		"levels", "main_menu":
			_audio.play_ui("click")
			_suspend_if_running()
			progress.save()
			settings.save()
			if leave_requested.get_connections().is_empty():
				# Samostatně spuštěná scéna hry (editor): přejít do aplikace s menu.
				get_tree().change_scene_to_file.call_deferred("res://main/app.tscn")
			else:
				leave_requested.emit(action)


## Rozehraný pokus uloží pro „Pokračovat“ (jen když už běží a neskončil).
func _suspend_if_running() -> void:
	if _sim != null and not _sim.finished and _sim.tick_count > 0 and not _mission_id.is_empty():
		progress.suspend(_mission_id, _sim)
		progress.save()


## Zapíše výsledek do postupu a připraví údaje pro okno výsledku.
func _record_result() -> Dictionary:
	if _mission_id.is_empty():
		return {}
	var info := progress.record_result(_mission_id, _sim.saved, _sim.is_won(), _sim.tick_count)
	progress.save()
	var entry := progress.entry(_mission_id)
	info["best_saved"] = entry["best_saved"]
	info["best_ticks"] = entry["best_ticks"]
	var index := Campaign.index_of(_mission_id)
	if index >= 0 and index + 1 < Campaign.count():
		info["next_title"] = Campaign.mission(index + 1)["title"]
	return info


func _on_setting_changed(_key: String) -> void:
	_apply_settings()


## Uplatní nastavení: zvuk, okno, velikost rozhraní, kvalita a ovládání.
func _apply_settings() -> void:
	settings.apply_audio()
	settings.apply_window()
	_hud.set_sound(not settings.muted)
	_hud.show_fps(settings.show_fps)
	_hud.set_ui_scale(settings.ui_scale)
	var top := _hud.top_bar_height()
	var bottom := _hud.bottom_bar_height()
	_camera.top_padding = top
	_camera.bottom_padding = bottom
	if _view == null:
		return
	_view.camera.top_padding = top
	_view.camera.bottom_padding = bottom
	_view.camera.set("edge_scroll", settings.edge_scroll)
	_view.camera.set("speed_scale", settings.scroll_speed)
	if _view.has_method("set_quality"):
		_view.set_quality(settings.quality)
	if _view.has_method("set_stop_motion"):
		_view.set_stop_motion(settings.stop_motion)
