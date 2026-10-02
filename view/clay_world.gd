class_name ClayWorld
extends Node3D
## Prostorová prezentace společné simulace. Herní pravidla sem nepatří.

var terrain: ClayTerrain
var camera: ClayCamera
var fx: ClayFx
var actors: Dictionary = {}
var _sim: LevelSim
var _props: Node3D
var _selection: MeshInstance3D


func _ready() -> void:
	terrain = ClayTerrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	camera = ClayCamera.new()
	camera.name = "Camera"
	add_child(camera)
	fx = ClayFx.new()
	add_child(fx)
	_props = Node3D.new()
	add_child(_props)
	_lighting()
	_selection = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.29
	ring.outer_radius = 0.35
	ring.rings = 24
	ring.ring_segments = 8
	_selection.mesh = ring
	_selection.rotation.x = PI * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ffe99b")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	_selection.material_override = mat
	_selection.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_selection.visible = false
	add_child(_selection)


func setup(sim: LevelSim) -> void:
	_sim = sim
	for actor: ClayActor in actors.values():
		actor.free()
	actors.clear()
	for prop in _props.get_children():
		prop.free()
	fx.clear()
	terrain.setup(sim.mask)
	var focus := Vector2(sim.spec.width * 0.5, sim.spec.height * 0.5)
	if not sim.spec.hatches.is_empty():
		focus.x = sim.spec.hatches[0].x
	camera.setup(Vector2(sim.spec.width, sim.spec.height), focus)
	for point in sim.spec.hatches:
		_add_prop("clay_hatch", point, 1.3)
	for point in sim.spec.exits:
		_add_prop("clay_exit", point, 1.2)
	_selection.visible = false


func update_frame(alpha: float, events: Array[Dictionary], delta: float) -> void:
	terrain.sync()
	for lem in _sim.lemmings:
		if lem.removed:
			if actors.has(lem.id):
				(actors[lem.id] as ClayActor).free()
				actors.erase(lem.id)
			continue
		if not actors.has(lem.id):
			var actor := ClayActor.new()
			actor.name = "Lumik%d" % lem.id
			add_child(actor)
			actors[lem.id] = actor
		(actors[lem.id] as ClayActor).sync(lem, alpha)
	fx.update(delta, events)
	terrain.set_impacts(fx.impacts)


func highlight(lem: Lemming) -> void:
	_selection.visible = lem != null and actors.has(lem.id)
	if _selection.visible:
		_selection.position = (actors[lem.id] as ClayActor).position + Vector3(0, 0.5, 0.7)


func _add_prop(model_name: String, point: Vector2i, factor: float) -> void:
	var prop := load("res://assets/clay/models/%s.glb" % model_name).instantiate() as Node3D
	prop.position = ClaySpace.to_world(Vector2(point), -0.18)
	prop.scale = Vector3.ONE * factor
	_props.add_child(prop)


func _lighting() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("c8dfe6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dceaff")
	env.ambient_light_energy = 0.25 if DeviceProfile.touch_mode() else 0.48
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssao_enabled = not DeviceProfile.touch_mode() \
		and RenderingServer.get_current_rendering_method() == "forward_plus"
	env.ssao_radius = 0.4
	env.ssao_intensity = 1.3
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -25, 0)
	sun.light_color = Color("fff0d8")
	sun.light_energy = 0.6 if DeviceProfile.touch_mode() else 1.1
	sun.light_angular_distance = 2.5
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 0.4
	sun.directional_shadow_max_distance = 110
	add_child(sun)
	# Vzdálené kulisy jsou za celým terénem a nezasahují do herní roviny.
	for index in 7:
		var hill := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 1
		mesh.height = 2
		hill.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("9fbfc5") if index % 2 == 0 else Color("aecbd0")
		material.roughness = 1
		hill.material_override = material
		hill.position = Vector3(index * 14 - 10, -26, -16 - index % 2 * 4)
		hill.scale = Vector3(12, 6 + index % 3, 3)
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(hill)
