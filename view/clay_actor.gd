class_name ClayActor
extends Node3D
## Póza se hledá podle simulačního času; AnimationPlayer nikdy neposouvá logiku.

const MODEL := preload("res://assets/clay/models/clay_worker.glb")
const CLIPS := {
	Lemming.State.FALLER: "fall", Lemming.State.WALKER: "walk",
	Lemming.State.BLOCKER: "block", Lemming.State.BUILDER: "build",
	Lemming.State.BASHER: "bash", Lemming.State.DIGGER: "dig",
	Lemming.State.SHRUGGING: "shrug", Lemming.State.SPLATTING: "splat",
	Lemming.State.EXITING: "exit",
}
const TOOLS := {
	Lemming.State.BUILDER: preload("res://assets/clay/models/clay_brick.glb"),
	Lemming.State.BASHER: preload("res://assets/clay/models/clay_pickaxe.glb"),
	Lemming.State.DIGGER: preload("res://assets/clay/models/clay_shovel.glb"),
}

var model: Node3D
var player: AnimationPlayer
var clip := ""
var pose_time := 0.0
var _state := -1
var _attachment: BoneAttachment3D
var _tool: Node3D


func _init() -> void:
	model = MODEL.instantiate() as Node3D
	model.scale = Vector3.ONE * (SimConst.LEMMING_HEIGHT * ClaySpace.UNIT / 1.205)
	add_child(model)
	player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	_attachment = BoneAttachment3D.new()
	_attachment.bone_name = "Hand.R"
	skeleton.add_child(_attachment)


func sync(lem: Lemming, alpha: float) -> void:
	position = ClaySpace.to_world(Vector2(
		lerpf(lem.prev_x, lem.x, alpha) + 0.5, lerpf(lem.prev_y, lem.y, alpha)))
	rotation.y = PI * 0.5 * lem.dir
	if _state != lem.state:
		_state = lem.state
		clip = CLIPS[lem.state]
		player.play(clip)
		_update_tool()
	var length := player.get_animation(clip).length
	var ticks := maxf(0, lem.state_ticks + alpha)
	var cycle := 17.0
	var offset := 0.0
	match lem.state:
		Lemming.State.BUILDER:
			cycle = SimConst.BUILDER_TICKS_PER_BRICK
		Lemming.State.BASHER:
			cycle = SimConst.BASHER_TICKS_PER_STEP
			offset = 0.5
		Lemming.State.DIGGER:
			cycle = SimConst.DIGGER_TICKS_PER_ROW
			offset = 0.5
		Lemming.State.SHRUGGING:
			cycle = SimConst.SHRUG_TICKS
		Lemming.State.SPLATTING:
			cycle = SimConst.SPLAT_TICKS
		Lemming.State.EXITING:
			cycle = SimConst.EXIT_TICKS
	var fraction := ticks / cycle + offset
	if lem.state in [Lemming.State.SHRUGGING, Lemming.State.SPLATTING, Lemming.State.EXITING]:
		fraction = minf(fraction, 0.999)
	else:
		fraction = fposmod(fraction, 1.0)
	pose_time = fraction * length
	player.seek(pose_time, true)
	player.advance(0)


func _update_tool() -> void:
	if is_instance_valid(_tool):
		_tool.free()
	_tool = null
	if not TOOLS.has(_state):
		return
	_tool = TOOLS[_state].instantiate() as Node3D
	_attachment.add_child(_tool)
	_tool.scale = Vector3.ONE * (0.4 if _state == Lemming.State.BUILDER else 0.65)
	var grip := Vector3(0, 0.1, 0)
	if _state == Lemming.State.DIGGER:
		_tool.rotation.z = PI
		grip.y = 0.45
	_tool.position = -(_tool.basis * grip)
