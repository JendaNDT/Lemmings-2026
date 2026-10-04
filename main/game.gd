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
## Rychlosti tlačítka rychlosti v pořadí přepínání (1×, zrychlení, zpomalení).
const SPEEDS := [1.0, SimConst.FAST_FORWARD_MULTIPLIER, SimConst.SLOW_MOTION_MULTIPLIER]
## O kolik tiků vrací pomocník Přetočit (5 s); stejně často se ukládá záložka stavu.
const REWIND_TICKS := 5 * SimConst.TICKS_PER_SECOND
## Kolik záložek stavu se drží (minuta hry); starší přetočení přehraje misi od začátku.
const MAX_SNAPSHOTS := 12

## Který level se hraje. Dá se přepnout v Inspectoru.
@export var level_scene: PackedScene = preload("res://levels/level_01.tscn")
## Uzel vlastní prezentace (2D origami PaperWorld).
## Prázdná cesta = původní jednoduché 2D zobrazení pro porovnání.
@export var presentation_path := NodePath()

## Nastavení a postup hráče (předá App před přidáním do stromu).
var settings: GameSettings
var progress: Progress
## Obnovit rozehraný pokus z `progress.suspended` (jen při prvním načtení).
var resume_suspended := false
## Na začátku mise ukázat úvodní kartu (spouští-li misi menu; testy a editor ne).
var show_briefing := false
var _sim: LevelSim
var _level: LevelDefinition
var _selected_skill := -1
var _paused := false
var _speed := 1.0
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
## Ukázka řešení: hra přehrává uložený záznam mise, hráč jen sleduje.
var _demo := false
var _demo_commands: Array[Dictionary] = []
var _demo_cursor := 0
## Lumík, kterému ukázka právě přidělila dovednost (zvýraznění), a do kdy.
var _demo_focus := -1
var _demo_focus_until := 0
## Hráč v této misi viděl ukázku (u výsledku se to jen označí, hvězdy platí).
var _demo_seen := false
## Záložky stavu pro přetáčení (vzestupně podle tiku, bez příkazů svého tiku).
var _snapshots: Array[LevelSim] = []
## Běží přelet mapy (po úvodní kartě): čas stojí, klepnutí ho přeskočí.
var _flyover := false
## Prst drží na herní ploše bez posunu: kde (náhled cíle), jinak INF.
var _touch_preview := Vector2.INF

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
	_hud.briefing.closed.connect(_on_briefing_closed)
	_hud.flyover.skipped.connect(func() -> void: _end_flyover())
	_hud.minimap.focus_requested.connect(func(point: Vector2) -> void:
		if _view != null and not _flyover:
			_view.camera.focus = point
			_view.camera.refresh())
	_hud.skill_unavailable.connect(func(skill: int) -> void:
		if not _sim.finished and not _demo:
			_audio.play_ui("deny")
			_hud.info.show_notice(PlayInfo.refusal_text(SkillRules.Refusal.NO_SKILL, skill, null)))
	_hud.skill_selected.connect(_select_skill)
	_hud.release_rate_step.connect(_change_release_rate)
	_hud.pause_pressed.connect(_toggle_pause)
	_hud.speed_pressed.connect(_toggle_speed)
	_hud.step_pressed.connect(_step_tick)
	_hud.rewind_pressed.connect(_rewind)
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
		_touch.preview = func(point: Vector2) -> void: _touch_preview = point
	_apply_settings()
	_load_level()


## Načte misi `level_scene`. `intro` = ukázat úvodní kartu (ne při restartu),
## `demo` = přehrát uložené řešení mise (postup se nezapisuje).
func _load_level(intro := true, demo := false) -> void:
	_hud.close_nuke_confirmation()
	_hud.close_pause_menu()
	_flyover = false
	_hud.flyover.hide()
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
	if _level.level_id != _mission_id:
		_demo_seen = false
	_mission_id = _level.level_id
	_demo = demo and not _level.solution.is_empty()
	_demo_commands.clear()
	if _demo:
		_demo_commands = _level.solution_commands()
	_demo_cursor = 0
	_demo_focus = -1
	_demo_seen = _demo_seen or _demo
	_resumed = false
	if resume_suspended and not _demo and not _mission_id.is_empty() \
			and progress.suspended.get("mission", "") == _mission_id:
		# Rozehraný pokus: přehrát uložené příkazy až do uloženého tiku.
		_resumed = progress.restore_suspended(_sim)
		if not _resumed:
			_sim = LevelSim.new(LevelLoader.build_spec(_level), LevelLoader.build_mask(_level))
		_sim.take_events()
	resume_suspended = false
	LevelLoader.hide_terrain_shapes(_level)
	if not _resumed and not _demo and not _mission_id.is_empty():
		progress.record_start(_mission_id)
	progress.save()

	var focus := Vector2(spec.width / 2.0, spec.height / 2.0)
	if not spec.hatches.is_empty():
		focus = Vector2(spec.hatches[0])
	if _view != null:
		if _view.has_method("set_theme"):
			# Vzhled kapitoly (krajina, barvy, počasí); Hřiště a mise mimo kampaň = louka.
			# Patrové mise mají vlastní prostředí (podzemí) v kterékoli kapitole.
			# Téma před setup(): terén podle něj kreslí (ne)uzavřené dutiny.
			_view.set_theme(PaperTheme.for_mission(_level.scenery,
				Campaign.chapter_of(Campaign.index_of(_mission_id))))
		_view.setup(_sim)
	else:
		_terrain_view.setup(mask)
		_lemmings_view.setup(_sim)
		_fx_view.clear()
		_camera.setup(Vector2(spec.width, spec.height), focus)
	var title := Campaign.display_title(_mission_id) if not _mission_id.is_empty() else ""
	_hud.setup(_sim, ("Ukázka · " + title) if _demo else title, _level.hints,
		not _level.solution.is_empty(), _demo)
	_audio.setup(_sim, _logic_to_audio)

	# Obnovený pokus začne v pauze, ať se hráč nejdřív rozkouká.
	_paused = _resumed
	if show_briefing and intro and not _resumed:
		_paused = true
		_hud.briefing.open(_briefing_data())
	_speed = 1.0
	_accumulator = 0.0
	_result_shown = false
	var skills := _hud.visible_skills()
	_select_skill(skills[0] if not skills.is_empty() else -1, false)
	_snapshots = [_sim.snapshot()]
	if _demo:
		_apply_demo_commands()


func _process(delta: float) -> void:
	if _sim == null:
		return
	if _flyover and not _view.advance_flyover(delta):
		_end_flyover()
	var tick_time := 1.0 / SimConst.TICKS_PER_SECOND
	if not _paused and not _sim.finished:
		_accumulator += delta * _speed
		var steps := 0
		while _accumulator >= tick_time and steps < 8:
			_advance()
			_accumulator -= tick_time
			steps += 1
		_accumulator = minf(_accumulator, tick_time)

	var events := _sim.take_events()
	_audio.update(events, delta)
	var alpha := clampf(_accumulator / tick_time, 0.0, 1.0)
	if _view != null:
		var visual_delta := 0.0 if _paused or _sim.finished else delta * _speed
		_view.update_frame(alpha, events, visual_delta)
	else:
		_fx_view.handle_events(events)
		_lemmings_view.alpha = alpha

	var pointer := get_viewport().get_mouse_position()
	var hovered := _sim.find_lemming_at(mouse_logic_position(), _selected_skill)
	if _view != null and _touch_preview != Vector2.INF:
		# Prst drží na ploše: zvýraznit lumíka, kterého klepnutí zasáhne.
		pointer = _touch_preview
		hovered = _touch_target(_touch_preview)
	if _demo and _demo_focus >= 0 and _sim.tick_count < _demo_focus_until \
			and not _sim.lemmings[_demo_focus].removed:
		hovered = _sim.lemmings[_demo_focus]
	if _view != null:
		_view.highlight(hovered)
	else:
		_lemmings_view.hovered = hovered
	var cursor := Input.CURSOR_CROSS if hovered != null else Input.CURSOR_ARROW
	if Input.get_current_cursor_shape() != cursor:
		Input.set_default_cursor_shape(cursor)
	_show_target_info(hovered, pointer)

	_update_minimap()
	# Při přeletu vypadá lišta jako za běhu (čas se rozběhne hned po něm).
	_hud.refresh(_paused and not _flyover, _speed)
	if _sim.finished and not _result_shown:
		_result_shown = true
		_hud.show_result(_sim, _record_result())
		_audio.play_ui("win" if _sim.is_won() else "lose")


func _unhandled_input(event: InputEvent) -> void:
	if _overlay_input(event):
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
			KEY_PERIOD:
				_step_tick()
			KEY_BACKSPACE:
				_rewind()
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


## Vstup, když je otevřené okno HUDu nebo běží přelet (true = vstup patří jim).
## Esc mimo okna otevře pauzovací menu.
func _overlay_input(event: InputEvent) -> bool:
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	var escape: bool = key and event.physical_keycode == KEY_ESCAPE
	if _hud.confirmation_open():
		if escape:
			_decide_nuke(false)
	elif _hud.briefing.visible:
		if key and event.physical_keycode in [KEY_ESCAPE, KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
			_hud.briefing.close()
	elif _flyover:
		# Myš a dotyk zachytí vrstva přeletu v HUDu; klávesa přelet přeskočí.
		if key:
			_end_flyover()
	elif _hud.pause_menu_open() or _hud.result_open():
		if escape and _hud.pause_menu_open():
			_on_menu_action("resume")
	elif escape:
		_open_pause_menu()
	else:
		return false
	return true


func _input(event: InputEvent) -> void:
	if _touch != null and not _result_shown and not _overlay_open():
		# Dotyk začatý na minimapě patří jí (posouvá pohled), ne herní ploše.
		if event is InputEventScreenTouch and event.pressed and _hud.minimap.visible \
				and _hud.minimap.get_global_rect().has_point(event.position):
			return
		_touch.handle(event, get_viewport().get_visible_rect().size)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		# Přelet skončí, ale hra zůstane stát (obnovení pohybu je na hráči).
		_end_flyover(false)
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
		elif _hud.briefing.visible:
			_hud.briefing.close()
		elif _flyover:
			_end_flyover()
		elif _hud.settings_open():
			_hud.close_settings()
		elif _hud.pause_menu_open():
			_on_menu_action("resume")
		elif _hud.result_open():
			_on_menu_action("levels")
		else:
			_open_pause_menu()


func _try_assign_touch(screen_point: Vector2) -> void:
	if _selected_skill < 0 or _sim.finished or _overlay_open() or _demo:
		return
	var target := _touch_target(screen_point)
	if target != null and not _sim.assign_skill(target, _selected_skill):
		# Klepnutí na postavu, které dovednost přidělit nejde: zvuk a důvod.
		_refuse(target)


## Koho zasáhne klepnutí: nejbližší lumík v dotykovém dosahu, kterému jde
## vybraná dovednost dát; když žádný, nejbližší živý (kvůli vysvětlení proč ne).
func _touch_target(screen_point: Vector2) -> Lemming:
	var best: Lemming = null
	var best_distance := settings.tap_reach
	var nearest: Lemming = null
	var nearest_distance := settings.tap_reach
	for lem in _sim.lemmings:
		if lem.removed:
			continue
		var position: Vector2 = _view.camera.logic_to_screen(Vector2(lem.x + 0.5, lem.y - 5))
		var distance := screen_point.distance_to(position)
		if distance < best_distance and _sim.can_assign(lem, _selected_skill):
			best = lem
			best_distance = distance
		if distance < nearest_distance and lem.state not in LevelSim.DYING_STATES:
			nearest = lem
			nearest_distance = distance
	return best if best != null else nearest


func _try_assign(screen_point: Vector2) -> void:
	if _selected_skill < 0 or _sim.finished or _overlay_open() or _demo:
		return
	var lem := _sim.find_lemming_at(logic_position(screen_point), _selected_skill)
	if lem != null and not _sim.assign_skill(lem, _selected_skill):
		_refuse(lem)


## Minimapa sleduje aktuální simulaci (i po přetočení a v ukázce) a záběr kamery.
func _update_minimap() -> void:
	var minimap := _hud.minimap
	if _view == null:
		minimap.hide()
		return
	if minimap.sim != _sim:
		minimap.setup(_sim)
	minimap.visible = minimap.enabled
	var vp := get_viewport().get_visible_rect().size
	var top_left: Vector2 = _view.camera.screen_to_logic(Vector2(0.0, _hud.top_bar_height()))
	var bottom_right: Vector2 = _view.camera.screen_to_logic(
		Vector2(vp.x, vp.y - _hud.bottom_bar_height()))
	minimap.view_rect = Rect2(top_left, bottom_right - top_left)


## Dovednost nešla přidělit: zvuk odmítnutí a krátká hláška proč.
func _refuse(lem: Lemming) -> void:
	_audio.play_ui("deny")
	_hud.info.show_notice(PlayInfo.refusal_text(SkillRules.refusal(_sim, lem, _selected_skill),
		_selected_skill, lem))


## Štítek nad lumíkem pod kurzorem nebo prstem: co dělá, dav a proč nejde
## vybraná dovednost. Mimo herní plochu, v oknech a po konci mise zmizí.
func _show_target_info(lem: Lemming, pointer: Vector2) -> void:
	var visible := get_viewport().get_visible_rect()
	var in_play := pointer.y > _hud.top_bar_height() \
		and pointer.y < visible.size.y - _hud.bottom_bar_height()
	if lem == null or _view == null or _sim.finished or _overlay_open() or not in_play \
			or (DeviceProfile.touch_mode() and _touch_preview == Vector2.INF and not _demo):
		_hud.info.show_target(null, Vector2.ZERO, 0, "")
		return
	var refusal := SkillRules.refusal(_sim, lem, _selected_skill) if _selected_skill >= 0 \
		else SkillRules.Refusal.NONE
	var reason := "" if _demo or refusal in [SkillRules.Refusal.NONE, SkillRules.Refusal.GONE,
		SkillRules.Refusal.FINISHED] else PlayInfo.refusal_text(refusal, _selected_skill, lem)
	var head: Vector2 = _view.camera.logic_to_screen(Vector2(lem.x + 0.5, lem.y - 13))
	_hud.info.show_target(lem, head, SkillRules.crowd_at(_sim, logic_position(pointer)), reason)


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
	if not _demo and _sim.change_release_rate(delta):
		_audio.play_ui("tick")


func _toggle_pause() -> void:
	_paused = not _paused
	_audio.play_ui("pause" if _paused else "resume")


## Rychlost: 1× → zrychlení → zpomalení (pomocník hlavně pro dotyk) → 1×.
func _toggle_speed() -> void:
	_speed = SPEEDS[(SPEEDS.find(_speed) + 1) % SPEEDS.size()]
	_audio.play_ui("click")


## Pomocník: v pauze posune hru o jeden tik (těsná okna zásahu).
func _step_tick() -> void:
	if not _paused or _sim.finished or _result_shown or _overlay_open():
		return
	_advance()
	# Ukázat stav po kroku (mezistav mezi tiky by byl o krok pozadu).
	_accumulator = 0.999 / SimConst.TICKS_PER_SECOND
	_audio.play_ui("click")


## Pomocník: vrátí hru o 5 s. Simulace je deterministická, takže stačí misi
## postavit znovu a přehrát zaznamenané příkazy až do dřívějšího tiku.
## Pozdější příkazy se zahodí; kamera, pauza i rychlost zůstanou.
func _rewind() -> void:
	if _demo or _sim.tick_count == 0 or _result_shown or _overlay_open():
		return
	var target := maxi(_sim.tick_count - REWIND_TICKS, 0)
	var log := _sim.replay_log
	# Nejbližší záložka před cílem; bez ní se mise přehraje od začátku.
	var sim: LevelSim = null
	for snapshot in _snapshots:
		if snapshot.tick_count <= target:
			sim = snapshot.snapshot()
	if sim == null:
		sim = LevelSim.new(LevelLoader.build_spec(_level), LevelLoader.build_mask(_level))
	var cursor := sim.replay_log.size()
	while true:
		while cursor < log.size() and int(log[cursor]["tick"]) == sim.tick_count \
				and sim.tick_count <= target:
			if not sim.apply_command(log[cursor]["kind"], log[cursor]["target"],
					log[cursor]["value"]):
				push_warning("Přetočení se nepodařilo: příkaz %d nelze provést." % cursor)
				return
			cursor += 1
		if sim.tick_count >= target or sim.finished:
			break
		sim.tick()
	if sim.tick_count != target:
		push_warning("Přetočení se nepodařilo: mise skončila dřív.")
		return
	sim.take_events()
	_snapshots = _snapshots.filter(func(s: LevelSim) -> bool: return s.tick_count <= target)
	_sim = sim
	if _touch != null:
		_touch.clear()
	if _view != null:
		var focus: Vector2 = _view.camera.focus
		var zoom: float = _view.camera.zoom_factor
		_view.setup(_sim)
		_view.camera.focus = focus
		_view.camera.zoom_factor = zoom
		_view.camera.refresh()
	else:
		_terrain_view.setup(_sim.mask)
		_lemmings_view.setup(_sim)
		_fx_view.clear()
	var title := Campaign.display_title(_mission_id) if not _mission_id.is_empty() else ""
	_hud.setup(_sim, title, _level.hints, not _level.solution.is_empty())
	_audio.setup(_sim, _logic_to_audio)
	_select_skill(_selected_skill, false)
	_accumulator = 0.0
	_audio.play_ui("click")


## Jeden tik simulace; při ukázce řešení po něm provede příkazy záznamu.
func _advance() -> void:
	_sim.tick()
	if _sim.tick_count % REWIND_TICKS == 0 and not _demo:
		_snapshots.append(_sim.snapshot())
		if _snapshots.size() > MAX_SNAPSHOTS:
			_snapshots.pop_front()
	if _demo:
		_apply_demo_commands()


## Příkazy ukázky, které patří do aktuálního tiku (jako SimReplay).
func _apply_demo_commands() -> void:
	while _demo_cursor < _demo_commands.size() \
			and int(_demo_commands[_demo_cursor]["tick"]) <= _sim.tick_count:
		var command := _demo_commands[_demo_cursor]
		_demo_cursor += 1
		if _sim.apply_command(command["kind"], command["target"], command["value"]) \
				and command["kind"] == LevelSim.Command.ASSIGN_SKILL:
			_show_demo_command(command["target"], command["value"])


## Ukázka zvýrazní dovednost i lumíka a natočí na něj kameru, je-li mimo záběr.
func _show_demo_command(target: int, skill: int) -> void:
	_hud.select_skill(skill)
	_demo_focus = target
	_demo_focus_until = _sim.tick_count + SimConst.TICKS_PER_SECOND
	if _view == null:
		return
	var lem := _sim.lemmings[target]
	var point := Vector2(lem.x, lem.y - 5)
	var screen: Vector2 = _view.camera.logic_to_screen(point)
	var visible := get_viewport().get_visible_rect()
	if not visible.grow(-visible.size.x * 0.15).has_point(screen):
		_view.camera.focus = point
		_view.camera.refresh()


func _toggle_sound() -> void:
	settings.set_value("muted", not settings.muted)
	settings.save()


func _restart() -> void:
	_audio.play_ui("click")
	_load_level(false)


func _choose_mission(index: int) -> void:
	if index < 0 or index >= Campaign.count():
		return
	level_scene = Campaign.SCENES[index]
	_audio.play_ui("click")
	_load_level()


func _request_nuke() -> void:
	if _sim.finished or _sim.nuking or _overlay_open() or _demo:
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
	if _result_shown or _overlay_open():
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
		"demo":
			_hud.close_pause_menu()
			_audio.play_ui("click")
			_load_level(false, true)
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
	if _sim != null and not _demo and not _sim.finished and _sim.tick_count > 0 \
			and not _mission_id.is_empty():
		progress.suspend(_mission_id, _sim)
		progress.save()


## Zapíše výsledek do postupu a připraví údaje pro okno výsledku.
func _record_result() -> Dictionary:
	if _demo:
		return {"demo": true}
	if _mission_id.is_empty():
		return {}
	var info := progress.record_result(_mission_id, _sim.saved, _sim.is_won(), _sim.tick_count)
	progress.save()
	var entry := progress.entry(_mission_id)
	info["best_saved"] = entry["best_saved"]
	info["best_ticks"] = entry["best_ticks"]
	if Campaign.index_of(_mission_id) >= 0:
		info["thresholds"] = Campaign.star_thresholds(Campaign.mission(
			Campaign.index_of(_mission_id)))
	var index := Campaign.index_of(_mission_id)
	if index >= 0 and index + 1 < Campaign.count():
		info["next_title"] = Campaign.mission(index + 1)["title"]
	info["demo_seen"] = _demo_seen
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
	_hud.minimap.enabled = settings.minimap
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
	if _view.has_method("set_ui_scale"):
		_view.set_ui_scale(settings.ui_scale)


## Je otevřené okno, které patří HUDu (potvrzení, pauza, úvodní karta, přelet)?
func _overlay_open() -> bool:
	return _hud.confirmation_open() or _hud.pause_menu_open() or _hud.briefing.visible \
		or _flyover


## Po úvodní kartě přelet mapy (lze vypnout v nastavení), pak se spustí čas.
func _on_briefing_closed() -> void:
	if settings.flyover and _view != null and _view.start_flyover():
		_flyover = true
		if _touch != null:
			_touch.clear()
		_hud.flyover.show()
		return
	_paused = false
	_audio.play_ui("resume")


## Konec přeletu mapy (doletěl nebo ho hráč přeskočil). `start` = spustit čas.
func _end_flyover(start := true) -> void:
	if not _flyover:
		return
	_flyover = false
	_view.finish_flyover()
	_hud.flyover.hide()
	if start:
		_paused = false
		_audio.play_ui("resume")


## Údaje pro úvodní kartu mise.
func _briefing_data() -> Dictionary:
	var spec := _sim.spec
	var skills: Array = []
	for skill: int in Lemming.SKILL_ORDER:
		if int(spec.skills.get(skill, 0)) > 0:
			skills.append([skill, int(spec.skills[skill])])
	var data := {
		"title": Campaign.display_title(_mission_id) if not _mission_id.is_empty() else spec.title,
		"goal": "Cíl: zachraň %d z %d lumíků · čas %d:%02d" % [spec.save_required,
			spec.lemming_count, floori(spec.time_limit_seconds / 60.0), spec.time_limit_seconds % 60],
		"introduces": _level.introduces, "briefing": _level.briefing, "skills": skills,
	}
	var index := Campaign.index_of(_mission_id)
	if index >= 0:
		var info := Campaign.mission(index)
		data["chapter"] = "Kapitola " + Campaign.chapter_title(Campaign.chapter_of(index))
		if _level.scenery == "podzemi":
			data["chapter"] += " · výprava do podzemí"
		data["tier"] = LevelDifficulty.tier(int(info["difficulty"]))
		data["thresholds"] = Campaign.star_thresholds(info)
		data["stars"] = progress.stars(index)
	return data
