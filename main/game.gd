extends Node
## Hlavní scéna – „lepidlo“ mezi simulací, grafikou a ovládáním.
##
## Každý snímek: přičte uplynulý čas, provede tolik pevných kroků simulace,
## kolik se jich do něj vejde, a pak předá grafice, jak daleko jsme mezi tiky.

## Který level se hraje. Dá se přepnout v Inspectoru.
@export var level_scene: PackedScene = preload("res://levels/level_01.tscn")
@export var use_3d := false

var _sim: LevelSim
var _level: LevelDefinition
var _selected_skill := -1
var _paused := false
var _fast := false
var _accumulator := 0.0
var _result_shown := false
var _touch: TouchControls

@onready var _world: Node2D = $World
@onready var _terrain_view: TerrainView = $World/TerrainView
@onready var _lemmings_view: LemmingsView = $World/LemmingsView
@onready var _fx_view: FxView = $World/FxView
@onready var _camera: GameCamera = $World/GameCamera
@onready var _hud: Hud = $Hud
@onready var _clay: ClayWorld = get_node_or_null("ClayWorld")


func _ready() -> void:
	_hud.skill_selected.connect(_select_skill)
	_hud.release_rate_step.connect(_change_release_rate)
	_hud.pause_pressed.connect(_toggle_pause)
	_hud.speed_pressed.connect(_toggle_speed)
	_hud.restart_pressed.connect(_load_level)
	_camera.top_padding = Hud.TOP_BAR_HEIGHT
	_camera.bottom_padding = Hud.BOTTOM_BAR_HEIGHT
	if use_3d:
		_world.visible = false
		$Background.visible = false
		_camera.enabled = false
		for node in [_camera, _terrain_view, _lemmings_view, _fx_view]:
			node.set_process(false)
			node.set_process_unhandled_input(false)
		_touch = TouchControls.new()
		_touch.camera = _clay.camera
		_touch.tapped = _try_assign_touch
	_load_level()


func _load_level() -> void:
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
	LevelLoader.hide_terrain_shapes(_level)
	_sim = LevelSim.new(spec, mask)

	var focus := Vector2(spec.width / 2.0, spec.height / 2.0)
	if not spec.hatches.is_empty():
		focus = Vector2(spec.hatches[0])
	if use_3d:
		_clay.setup(_sim)
	else:
		_terrain_view.setup(mask)
		_lemmings_view.setup(_sim)
		_fx_view.clear()
		_camera.setup(Vector2(spec.width, spec.height), focus)
	_hud.setup(_sim)

	_paused = false
	_accumulator = 0.0
	_result_shown = false
	var skills := _hud.visible_skills()
	_select_skill(skills[0] if not skills.is_empty() else -1)


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
	var alpha := clampf(_accumulator / tick_time, 0.0, 1.0)
	if use_3d:
		var visual_delta := 0.0 if _paused or _sim.finished else delta * \
			(SimConst.FAST_FORWARD_MULTIPLIER if _fast else 1.0)
		_clay.update_frame(alpha, events, visual_delta)
	else:
		_fx_view.handle_events(events)
		_lemmings_view.alpha = alpha

	var hovered := _sim.find_lemming_at(mouse_logic_position(), _selected_skill)
	if use_3d:
		_clay.highlight(hovered)
	else:
		_lemmings_view.hovered = hovered
	var cursor := Input.CURSOR_CROSS if hovered != null else Input.CURSOR_ARROW
	if Input.get_current_cursor_shape() != cursor:
		Input.set_default_cursor_shape(cursor)

	_hud.refresh(_paused, SimConst.FAST_FORWARD_MULTIPLIER if _fast else 1.0)
	if _sim.finished and not _result_shown:
		_result_shown = true
		_hud.show_result(_sim)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if use_3d and mb.device == InputEvent.DEVICE_ID_EMULATION:
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
				_load_level()
			KEY_MINUS, KEY_KP_SUBTRACT:
				_change_release_rate(-1)
			KEY_EQUAL, KEY_KP_ADD:
				_change_release_rate(1)


func _input(event: InputEvent) -> void:
	if _touch != null and not _result_shown:
		_touch.handle(event, get_viewport().get_visible_rect().size)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_paused = true
		if _touch != null:
			_touch.clear()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_toggle_pause()


func _try_assign_touch(screen_point: Vector2) -> void:
	if _selected_skill < 0 or _sim.finished:
		return
	var best: Lemming = null
	var best_distance := 42.0
	# Větší dotykový dosah, ale stále jen mezi cíli, jimž lze dovednost přidělit.
	for lem in _sim.lemmings:
		if not _sim.can_assign(lem, _selected_skill):
			continue
		var position := _clay.camera.logic_to_screen(Vector2(lem.x + 0.5, lem.y - 5))
		var distance := screen_point.distance_to(position)
		if distance < best_distance:
			best = lem
			best_distance = distance
	if best != null:
		_sim.assign_skill(best, _selected_skill)


func _try_assign(screen_point: Vector2) -> void:
	if _selected_skill < 0 or _sim.finished:
		return
	var lem := _sim.find_lemming_at(logic_position(screen_point), _selected_skill)
	if lem != null:
		_sim.assign_skill(lem, _selected_skill)


func mouse_logic_position() -> Vector2:
	return logic_position(get_viewport().get_mouse_position())


func logic_position(screen_point: Vector2) -> Vector2:
	if use_3d:
		return _clay.camera.screen_to_logic(screen_point)
	return _lemmings_view.get_global_transform_with_canvas().affine_inverse() * screen_point


func _select_skill(skill: int) -> void:
	_selected_skill = skill
	_hud.select_skill(skill)


func _change_release_rate(delta: int) -> void:
	_sim.change_release_rate(delta)


func _toggle_pause() -> void:
	_paused = not _paused


func _toggle_speed() -> void:
	_fast = not _fast
