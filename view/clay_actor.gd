class_name ClayActor
extends Node3D
## Póza se hledá podle simulačního času; AnimationPlayer nikdy neposouvá logiku.

const MODEL := preload("res://assets/art_v2/models/clay_worker.glb")
const PICKAXE := preload("res://assets/clay/models/clay_pickaxe.glb")
const CLIPS := {
	Lemming.State.FALLER: "fall", Lemming.State.WALKER: "walk",
	Lemming.State.BLOCKER: "block", Lemming.State.BUILDER: "build",
	Lemming.State.BASHER: "bash", Lemming.State.DIGGER: "dig",
	Lemming.State.SHRUGGING: "shrug", Lemming.State.SPLATTING: "splat",
	Lemming.State.EXITING: "exit",
	Lemming.State.CLIMBER: "walk", Lemming.State.FLOATER: "fall",
	Lemming.State.MINER: "mine",
	# Ve 2.5D porovnávací scéně nemají voda a láva vlastní klip.
	Lemming.State.DROWNING: "splat", Lemming.State.BURNING: "splat",
}
const TOOLS := {
	Lemming.State.BUILDER: preload("res://assets/clay/models/clay_brick.glb"),
	Lemming.State.BASHER: PICKAXE,
	Lemming.State.DIGGER: preload("res://assets/clay/models/clay_shovel.glb"),
	Lemming.State.MINER: PICKAXE,
}

var model: Node3D
var player: AnimationPlayer
var clip := ""
var pose_time := 0.0
var _state := -1
var _attachment: BoneAttachment3D
var _tool: Node3D
var _skeleton: Skeleton3D
var _skill_visuals: ClaySkillVisuals


func _init() -> void:
	model = MODEL.instantiate() as Node3D
	model.scale = Vector3.ONE * (SimConst.LEMMING_HEIGHT * ClaySpace.UNIT / 1.27)
	add_child(model)
	player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	_skeleton = skeleton
	_attachment = BoneAttachment3D.new()
	_attachment.bone_name = "Hand.R"
	skeleton.add_child(_attachment)
	_skill_visuals = ClaySkillVisuals.new()
	add_child(_skill_visuals)


func sync(lem: Lemming, alpha: float) -> void:
	position = ClaySpace.to_world(Vector2(
		lerpf(lem.prev_x, lem.x, alpha) + 0.5, lerpf(lem.prev_y, lem.y, alpha)))
	rotation.y = 0.85 * lem.dir
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
		Lemming.State.MINER:
			cycle = SimConst.MINER_TICKS_PER_STEP
			offset = 0.5
		Lemming.State.SHRUGGING:
			cycle = SimConst.SHRUG_TICKS
		Lemming.State.SPLATTING:
			cycle = SimConst.SPLAT_TICKS
		Lemming.State.EXITING:
			cycle = SimConst.EXIT_TICKS
		Lemming.State.DROWNING:
			cycle = SimConst.DROWN_TICKS
		Lemming.State.BURNING:
			cycle = SimConst.BURN_TICKS
	var fraction := ticks / cycle + offset
	if lem.state in [Lemming.State.SHRUGGING, Lemming.State.SPLATTING, Lemming.State.EXITING,
			Lemming.State.DROWNING, Lemming.State.BURNING]:
		fraction = minf(fraction, 0.999)
	else:
		fraction = fposmod(fraction, 1.0)
	pose_time = fraction * length
	player.seek(pose_time, true)
	player.advance(0)
	if lem.state == Lemming.State.CLIMBER:
		_climbing_pose(ticks)
	_skill_visuals.sync(lem, alpha)


func _climbing_pose(ticks: float) -> void:
	# Zvednutí paží doplní střídavý krok; neovlivňuje přesné místo kolize.
	for side in ["L", "R"]:
		var bone := _skeleton.find_bone("Arm." + side)
		var phase := ticks * TAU / 12 + (PI if side == "L" else 0.0)
		var pose := _skeleton.get_bone_pose_rotation(bone)
		_skeleton.set_bone_pose_rotation(bone,
			pose * Quaternion(Vector3.RIGHT, -1.5 + sin(phase) * 0.45))


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
