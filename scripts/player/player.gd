class_name Player
extends CharacterBody3D
## Third-person farmer: camera-relative movement, tool quickbar, timed farm actions,
## and talking to whatever interactable (NPC, fishing spot...) is in range.
## Animations: if the AnimationPlayer has a clip named after the state/action
## (idle, walk, run, till, water, plant, harvest, fish) it is played; otherwise a
## procedural placeholder (bob / bow) is used so primitives still read well.

signal tool_changed

enum Tool { HOE, WATER, SEED, ROD }
enum State { IDLE, WALK, RUN, ACTION }

const TOOL_NAMES: Array[String] = ["Cuốc", "Bình tưới", "Hạt giống", "Cần câu"]
const TOOL_ACTIONS: Array[StringName] = [&"till", &"water", &"plant", &"fish"]
const STATE_ANIMS: Array[StringName] = [&"idle", &"walk", &"run", &""]
## Our state/action names -> clip names in the Kenney Mini Characters rig.
const ANIM_ALIASES := {
	&"run": &"sprint", &"till": &"attack-melee-right", &"water": &"interact-right",
	&"plant": &"pick-up", &"harvest": &"pick-up", &"fish": &"holding-right",
}
const LOOPING: Array[StringName] = [&"idle", &"walk", &"sprint"]
const TOOL_MODELS: Array[PackedScene] = [
	preload("res://assets/models/props/tool_hoe.glb"),
	preload("res://assets/models/props/tool_watering_can.glb"),
	preload("res://assets/models/props/tool_seed_bag.glb"),
	preload("res://assets/models/props/tool_fishing_rod.glb"),
]

@export var walk_speed := 3.5
@export var run_speed := 6.5
@export var acceleration := 12.0
@export var turn_speed := 12.0
@export var reach := 1.0 ## distance in front of the player used to pick the target plot
@export var action_time := 0.6
@export var hand_bone := &"arm-right" ## skeleton bone the held tool is attached to
## Tool pose relative to the hand bone (in model space, which is scaled 2.2 -> tool scale 1/2.2).
@export var hold_offset := Transform3D(Basis().scaled(Vector3.ONE / 2.2), Vector3(0, -0.22, 0.04))

var state := State.IDLE
var tool := Tool.HOE
var seed_index := 0
## Set by NPCs / spots while the player stands in their area; must have interact(player).
var interactable: Node

var _target: FarmPlot
var _hand: BoneAttachment3D
var _held: Node3D
var _bob_t := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var visual: Node3D = $Visual
@onready var anim: AnimationPlayer = visual.find_children("*", "AnimationPlayer", true, false).pop_front()
@onready var cam: CameraRig = $CameraRig


func _ready() -> void:
	if anim:
		for clip in LOOPING:
			if anim.has_animation(clip):
				anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	var skel := visual.find_children("*", "Skeleton3D", true, false).pop_front() as Skeleton3D
	if skel and skel.find_bone(hand_bone) >= 0:
		_hand = BoneAttachment3D.new()
		_hand.bone_name = hand_bone
		skel.add_child(_hand)
	_play(&"idle")
	_show_tool()


func _show_tool() -> void:
	if _held:
		_held.queue_free()
		_held = null
	if _hand:
		_held = TOOL_MODELS[tool].instantiate()
		_held.transform = hold_offset
		_hand.add_child(_held)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var dir := Vector3.ZERO
	if state != State.ACTION and not GameState.ui_busy:
		var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		dir = cam.global_transform.basis * Vector3(input.x, 0.0, input.y)
	var running := Input.is_action_pressed(&"run")
	var target_v := dir * (run_speed if running else walk_speed)
	var w := 1.0 - exp(-acceleration * delta)
	velocity.x = lerpf(velocity.x, target_v.x, w)
	velocity.z = lerpf(velocity.z, target_v.z, w)
	move_and_slide()

	if dir.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-turn_speed * delta))
	if state != State.ACTION:
		_set_state(State.IDLE if dir.length() < 0.1 else (State.RUN if running else State.WALK))
	_update_target()


func _process(delta: float) -> void:
	if anim and anim.has_animation(&"walk"):
		return
	var moving := state == State.WALK or state == State.RUN
	_bob_t = _bob_t + delta * (14.0 if state == State.RUN else 9.0) if moving else 0.0
	visual.position.y = absf(sin(_bob_t)) * 0.08


func _unhandled_input(event: InputEvent) -> void:
	if GameState.ui_busy:
		return
	for i in Tool.size():
		if event.is_action_pressed("tool_%d" % (i + 1)):
			select_tool(i)
	if event.is_action_pressed(&"interact"):
		try_interact()


func select_tool(t: int) -> void:
	# Pressing Seeds again cycles through the seed types in the bag.
	if t == Tool.SEED and tool == Tool.SEED:
		seed_index += 1
	tool = t as Tool
	_show_tool()
	tool_changed.emit()


## Selected seed item from the inventory, or null when the bag has no seeds.
func current_seed() -> ItemData:
	var seeds := GameState.inventory.items(ItemData.Category.SEED)
	return seeds[seed_index % seeds.size()] if not seeds.is_empty() else null


func tool_label(t: int = tool) -> String:
	if t != Tool.SEED:
		return TOOL_NAMES[t]
	var s := current_seed()
	return "%s x%d" % [s.crop.display_name, GameState.inventory.count(s)] if s else "Hết hạt"


func teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	cam.snap()
	interactable = null


func try_interact() -> void:
	if state == State.ACTION or GameState.ui_busy:
		return
	if is_instance_valid(interactable):
		interactable.interact(self)
		return
	if not is_instance_valid(_target):
		return
	var action := &"harvest" if _target.can(&"harvest") else TOOL_ACTIONS[tool]
	var seed_item := current_seed()
	if action == &"plant" and seed_item == null and _target.can(action):
		GameState.toast("Hết hạt giống - mua thêm ở Thành Phố")
		return
	if not _target.can(action):
		return
	var plot := _target
	_set_state(State.ACTION)
	var to := plot.global_position - global_position
	visual.rotation.y = atan2(-to.x, -to.z)
	_play(action)
	var tw := create_tween()
	tw.tween_interval(action_time)
	tw.tween_callback(func() -> void:
		_finish_action(plot, action, seed_item)
		_set_state(State.IDLE))


## Long activities driven by someone else (fishing...): lock into ACTION, face a point, loop a clip.
func begin_activity(anim_name: StringName, face_point: Vector3) -> void:
	state = State.ACTION
	velocity = Vector3.ZERO
	var to := face_point - global_position
	visual.rotation.y = atan2(-to.x, -to.z)
	var clip: StringName = ANIM_ALIASES.get(anim_name, anim_name)
	if anim and anim.has_animation(clip):
		anim.play(clip, 0.15)


func end_activity() -> void:
	_set_state(State.IDLE)


## Swap a customization slot (Hair, Hat, Top, Bottom...) under $Visual. Used by the fashion shop later.
func equip(slot: StringName, mesh: Mesh, material: Material = null) -> void:
	var node := visual.get_node_or_null(NodePath(slot)) as MeshInstance3D
	if node:
		node.mesh = mesh
		node.material_override = material


func _finish_action(plot: FarmPlot, action: StringName, seed_item: ItemData) -> void:
	if not is_instance_valid(plot) or not plot.can(action):
		return
	if action != &"plant" or GameState.inventory.count(seed_item) > 0:
		Progression.reward(action)
	match action:
		&"plant":
			if GameState.inventory.remove(seed_item):
				plot.perform(action, seed_item.crop)
		&"harvest":
			var produce := plot.crop.produce
			plot.perform(action)
			GameState.inventory.add(produce)
			GameState.toast("+1 %s" % produce.display_name)
		_:
			plot.perform(action)


func _update_target() -> void:
	var farm := get_tree().get_first_node_in_group(&"farm_grid") as FarmGrid
	var plot: FarmPlot = farm.get_plot_at(global_position - visual.global_transform.basis.z * reach) if farm else null
	if plot == _target:
		return
	if is_instance_valid(_target):
		_target.set_highlighted(false)
	_target = plot
	if _target:
		_target.set_highlighted(true)


func _set_state(s: State) -> void:
	if s == state:
		return
	state = s
	if s != State.ACTION:
		_play(STATE_ANIMS[s])


func _play(anim_name: StringName) -> void:
	var clip: StringName = ANIM_ALIASES.get(anim_name, anim_name)
	if anim and anim.has_animation(clip):
		# action clips are stretched to fit action_time
		var speed := anim.get_animation(clip).length / action_time if state == State.ACTION else 1.0
		anim.play(clip, 0.15, speed)
	elif state == State.ACTION:
		var tw := create_tween()
		tw.tween_property(visual, "rotation:x", -0.5, action_time * 0.4)
		tw.tween_property(visual, "rotation:x", 0.0, action_time * 0.6)
