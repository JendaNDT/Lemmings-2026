extends Node3D
## Samostatný výtvarný výřez. Výchozí hra a její simulace zůstávají oddělené.

const WORKER := preload("res://assets/reference_v3/models/clay_worker.glb")
const STAGE := preload("res://assets/reference_v3/models/clay_reference.glb")
const FONT := preload("res://assets/art_v2/ui/Nunito.ttf")

var camera: Camera3D
var clock := 0.0
var paused := false
var _actors: Array[Dictionary] = []
var _crumbs: Array[Dictionary] = []
var _detail := false
var _plug: Node3D
var _plug_home := Vector3.ZERO


func _ready() -> void:
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		get_viewport().use_taa = true
		get_viewport().msaa_3d = Viewport.MSAA_4X
		RenderingServer.directional_soft_shadow_filter_set_quality(
			RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	var stage := STAGE.instantiate()
	add_child(stage)
	_surface_materials(stage)
	_plug = stage.find_child("DigPlug", true, false) as Node3D
	assert(_plug != null, "Chybí oddělovaná hmota")
	_plug_home = _plug.position
	for node in stage.find_children("Crumb_*", "Node3D", true, false):
		_crumbs.append({"node": node, "home": node.position, "index": _crumbs.size()})
	_lighting()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.1
	camera.position = Vector3(0, 3.3, 22)
	add_child(camera)
	camera.look_at(Vector3(0, 1.15, 0))
	camera.current = true
	var lens := CameraAttributesPractical.new()
	lens.dof_blur_far_enabled = true
	lens.dof_blur_far_distance = 27.0
	lens.dof_blur_far_transition = 12.0
	lens.dof_blur_amount = 0.07
	camera.attributes = lens
	_actor(Vector3(-4.6, 0.19, 0.35), "walk", .5)
	_actor(Vector3(-3.30, 0.19, 0.35), "walk", .13)
	_actor(Vector3(-1.32, 0.12, 0.4), "bash", .4)
	_actor(Vector3(1.10, .69, .64), "build", .0)
	_ui()
	set_study_time(0.0)


func _lighting() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = -1
	var background := CanvasLayer.new()
	background.layer = -10
	add_child(background)
	var sky_rect := ColorRect.new()
	sky_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := ShaderMaterial.new()
	gradient.shader = preload("res://studies/reference_sky.gdshader")
	sky_rect.material = gradient
	background.add_child(sky_rect)
	var sky := Sky.new()
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = Color("237ecb")
	material.sky_horizon_color = Color("6aafec")
	material.ground_horizon_color = Color("7abae4")
	material.ground_bottom_color = Color("8ab58b")
	material.sky_curve = .35
	sky.sky_material = material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b6d7eb")
	env.ambient_light_energy = .12
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssao_enabled = RenderingServer.get_current_rendering_method() == "forward_plus"
	env.ssao_radius = .75
	env.ssao_intensity = 2.2
	env.ssao_power = 1.35
	env.ssao_detail = 1.6
	env.fog_enabled = true
	env.fog_light_color = Color("9bc4df")
	env.fog_density = .001
	env.fog_sky_affect = 0.0
	var environment := WorldEnvironment.new()
	environment.environment = env
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -36, 0)
	key.light_color = Color("ffdda0")
	key.light_energy = 1.20
	key.light_angular_distance = 1.0
	key.shadow_enabled = true
	key.shadow_bias = .08
	key.shadow_normal_bias = 1.0
	key.directional_shadow_max_distance = 44
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 120, 0)
	fill.light_color = Color("9fcce6")
	fill.light_energy = .15
	add_child(fill)


func _surface_materials(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		for index in node.mesh.get_surface_count():
			var material: Material = node.mesh.surface_get_material(index)
			if not material is StandardMaterial3D:
				continue
			var name_lower := material.resource_name.to_lower()
			if not (name_lower.begins_with("earth") or name_lower.begins_with("grass")
					or name_lower.begins_with("brick")):
				continue
			var clay := ShaderMaterial.new()
			clay.shader = preload("res://studies/clay_surface.gdshader")
			clay.set_shader_parameter("clay_color", material.albedo_color)
			clay.set_shader_parameter("relief", .012 if name_lower.begins_with("earth") else .006)
			node.set_surface_override_material(index, clay)


func _actor(at: Vector3, clip: String, phase: float) -> void:
	var model := WORKER.instantiate() as Node3D
	model.position = at
	model.rotation.y = .80
	add_child(model)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	var player := players[0] as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var selected := ""
	for candidate in player.get_animation_list():
		if candidate.begins_with(clip):
			selected = candidate
			break
	assert(not selected.is_empty(), "Chybí animační klip výtvarné studie")
	player.play(selected)
	_actors.append({"model": model, "player": player, "clip": selected, "phase": phase,
		"home": at, "kind": clip})
	if clip in ["bash", "build"]:
		var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var attachment := BoneAttachment3D.new()
		skeleton.add_child(attachment)
		attachment.bone_name = "Hand.R"
		var path := "res://assets/clay/models/clay_pickaxe.glb" if clip == "bash" \
			else "res://assets/clay/models/clay_brick.glb"
		var tool := load(path).instantiate() as Node3D
		attachment.add_child(tool)
		tool.scale = Vector3.ONE * (.85 if clip == "bash" else .6)
		tool.position = Vector3(0, -.10, 0)


func _process(delta: float) -> void:
	if not paused:
		set_study_time(clock + delta)


func set_study_time(value: float) -> void:
	clock = value
	for actor in _actors:
		var player: AnimationPlayer = actor.player
		var length := player.get_animation(actor.clip).length
		var speed := .50 if actor.kind == "bash" else .70
		player.seek(fposmod(clock * speed + actor.phase, length), true)
		player.advance(0)
		if actor.kind == "walk":
			actor.model.position.x = actor.home.x + sin(clock * .45) * .20
	var dig_phase := fposmod(clock * .5 + .4, 1.0)
	var pull := smoothstep(.40, .65, dig_phase)
	var gone := smoothstep(.60, .78, dig_phase)
	_plug.visible = dig_phase < .78
	_plug.scale = Vector3(1 - pull * .18, 1 - pull * .12, 1 + pull * .24) * (1 - gone * .97)
	_plug.position = _plug_home + Vector3(-pull * .1, -gone * .34, pull * .16)
	for crumb in _crumbs:
		var t := fposmod(clock + crumb.index * .071, 1.45) / 1.45
		crumb.node.position = crumb.home + Vector3(t * .20, sin(t * PI) * .16, t * .28)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_SPACE:
		paused = not paused
	elif event.physical_keycode == KEY_R:
		set_study_time(0)
	elif event.physical_keycode == KEY_TAB:
		_detail = not _detail
		camera.size = 4.3 if _detail else 8.1
		camera.position.x = -1.0 if _detail else 0.0


func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title_panel := Panel.new()
	title_panel.position = Vector2(16, 12)
	title_panel.size = Vector2(520, 43)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("203340")
	style.set_corner_radius_all(13)
	title_panel.add_theme_stylebox_override("panel", style)
	layer.add_child(title_panel)
	var label := Label.new()
	label.text = "MODELÍNOVÝ SVĚT  /  výtvarný výřez"
	label.position = Vector2(28, 20)
	var font := FontVariation.new()
	font.base_font = FONT
	font.variation_opentype = {0x77676874: 700.0}
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color("fff0d0"))
	label.add_theme_color_override("font_shadow_color", Color("23353b"))
	label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(label)
	var help := Label.new()
	help.text = "Mezerník · pauza     Tab · detail     R · znovu"
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(28, -42)
	help.add_theme_font_override("font", FONT)
	help.add_theme_font_size_override("font_size", 18)
	help.add_theme_color_override("font_color", Color("fff0d0"))
	layer.add_child(help)
