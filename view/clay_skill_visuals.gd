class_name ClaySkillVisuals
extends Node3D
## Provizorní padák a odpočet. Čas i viditelnost určuje pouze simulace.

var parachute: Node3D
var countdown: Label3D


func _init() -> void:
	parachute = Node3D.new()
	add_child(parachute)
	var fabric := StandardMaterial3D.new()
	fabric.albedo_color = Color("f2c65e")
	fabric.roughness = 1
	fabric.cull_mode = BaseMaterial3D.CULL_DISABLED
	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.65
	sphere.height = 0.65
	sphere.is_hemisphere = true
	sphere.radial_segments = 24
	sphere.rings = 8
	dome.mesh = sphere
	dome.material_override = fabric
	dome.position.y = 1.8
	parachute.add_child(dome)
	var rope := StandardMaterial3D.new()
	rope.albedo_color = Color("eee1c2")
	rope.roughness = 1
	for index in 4:
		var angle := index * TAU / 4 + PI / 4
		var a := Vector3(cos(angle) * 0.56, 1.8, sin(angle) * 0.56)
		var b := Vector3(cos(angle) * 0.18, 0.75, sin(angle) * 0.18)
		var line := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.012
		cylinder.bottom_radius = 0.012
		cylinder.height = a.distance_to(b)
		cylinder.radial_segments = 6
		line.mesh = cylinder
		line.material_override = rope
		line.position = (a + b) * 0.5
		line.quaternion = Quaternion(Vector3.UP, (a - b).normalized())
		parachute.add_child(line)
	parachute.hide()
	countdown = Label3D.new()
	countdown.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	countdown.font_size = 80
	countdown.pixel_size = 0.008
	countdown.modulate = Color("ffe297")
	countdown.outline_modulate = Color("472c25")
	countdown.outline_size = 16
	countdown.no_depth_test = true
	add_child(countdown)
	countdown.hide()


func sync(lem: Lemming, alpha: float) -> void:
	parachute.visible = lem.state == Lemming.State.FLOATER
	var phase := (lem.state_ticks + alpha) / SimConst.TICKS_PER_SECOND
	parachute.rotation.z = sin(phase * 4) * 0.06
	countdown.visible = lem.bomb_ticks > 0
	countdown.position.y = 2.8 if parachute.visible else 1.65
	countdown.text = str(ceili(lem.bomb_ticks / float(SimConst.TICKS_PER_SECOND)))
