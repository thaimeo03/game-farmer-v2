class_name Player
extends CharacterBody3D
## Third-person farmer: camera-relative movement, tool quickbar, timed farm actions,
## and talking to whatever interactable (NPC, fishing spot...) is in range.
## Animations: if the AnimationPlayer has a clip named after the state/action
## (idle, walk, run, till, water, plant, harvest, fish) it is played; otherwise a
## procedural placeholder (bob / bow) is used so primitives still read well.

signal tool_changed
signal emoted(kind: StringName)

enum Tool { HOE, WATER, SEED, ROD, FERTILIZER }
enum State { IDLE, WALK, RUN, ACTION }

const TOOL_NAMES: Array[String] = ["Cuốc", "Bình tưới", "Hạt giống", "Cần câu", "Phân bón"]
const TOOL_ACTIONS: Array[StringName] = [&"till", &"water", &"plant", &"fish", &"fertilize"]
## Plot problems are handled first, whatever tool is held.
const PRIORITY_ACTIONS: Array[StringName] = [&"harvest", &"weed", &"spray"]
## Actions that use up an item (by Database id).
const CONSUMES := {&"spray": &"pesticide", &"fertilize": &"fertilizer"}
const STATE_ANIMS: Array[StringName] = [&"idle", &"walk", &"run", &""]
## Our state/action names -> clip names in the Kenney Mini Characters rig.
const ANIM_ALIASES := {
	&"run": &"sprint", &"till": &"attack-melee-right", &"water": &"interact-right",
	&"plant": &"pick-up", &"harvest": &"pick-up", &"fish": &"holding-right",
	&"fertilize": &"pick-up", &"weed": &"pick-up", &"spray": &"interact-right",
}
## Emote wheel (G): kind -> [clip, bubble, name]
const EMOTES := {
	&"wave": [&"interact-left", "👋", "Vẫy tay"], &"laugh": [&"emote-yes", "😄", "Cười"],
	&"sad": [&"emote-no", "😢", "Buồn"], &"jump": [&"jump", "🎉", "Nhảy"],
	&"heart": [&"emote-yes", "❤", "Thả tim"], &"sit": [&"sit", "😌", "Ngồi"],
}
const LOOPING: Array[StringName] = [&"idle", &"walk", &"sprint"]
const TOOL_MODELS: Array[PackedScene] = [
	preload("res://assets/models/props/tool_hoe.glb"),
	preload("res://assets/models/props/tool_watering_can.glb"),
	preload("res://assets/models/props/tool_seed_bag.glb"),
	preload("res://assets/models/props/tool_fishing_rod.glb"),
	preload("res://assets/models/props/tool_seed_bag.glb"),
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

## Appearance (saved under "appearance"): base character, worn accessories, pets.
var base_id := "character-female-b"
var owned_bases: Array[String] = ["character-female-b"]
var equipped := {} ## OutfitData.Slot -> OutfitData
var pet_affection := {} ## pet id (String) -> int
var active_pet: PetData

var _target: FarmPlot
var _sitting: Furniture
var _riding: Node3D ## ferris cabin etc.: we follow it until end_ride()
var _ride_offset := Vector3.ZERO
var _pet: PetCompanion
var _hand: BoneAttachment3D
var _held: Node3D
var _bob_t := 0.0
var _bubble: Label3D
var _bubble_t := 0.0
var _emote_sit := false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var visual: Node3D = $Visual
var anim: AnimationPlayer
@onready var cam: CameraRig = $CameraRig


func _ready() -> void:
	_pet = PetCompanion.new()
	_pet.owner_player = self
	add_child(_pet)
	var saved = SaveManager.register(&"appearance", self)
	if saved:
		load_save(saved)
	else:
		_setup_model()


# ---------------------------------------------------------------- appearance

func set_base(id: String) -> void:
	base_id = id
	_setup_model()


func equip_outfit(outfit: OutfitData) -> void:
	equipped[outfit.slot] = outfit
	Avatar.dress(visual.get_node(^"Model"), equipped)


func unequip(slot: int) -> void:
	equipped.erase(slot)
	Avatar.dress(visual.get_node(^"Model"), equipped)


func set_active_pet(pet: PetData) -> void:
	active_pet = pet
	_pet.set_pet(pet)


func pet_companion() -> PetCompanion:
	return _pet


func pet_level() -> int:
	return active_pet.level_for(pet_affection.get(String(active_pet.id), 0)) if active_pet else 0


func add_affection(amount: int) -> void:
	if active_pet:
		var key := String(active_pet.id)
		pet_affection[key] = pet_affection.get(key, 0) + amount


func to_save() -> Dictionary:
	var worn := {}
	for slot: int in equipped:
		worn[str(slot)] = String(equipped[slot].id)
	return {"base": base_id, "owned_bases": owned_bases, "equipped": worn, "pet_affection": pet_affection,
		"active_pet": String(active_pet.id) if active_pet else ""}


func load_save(d: Dictionary) -> void:
	base_id = String(d.get("base", base_id))
	owned_bases.assign(d.get("owned_bases", owned_bases))
	equipped.clear()
	var worn: Dictionary = d.get("equipped", {})
	for slot: String in worn:
		var o: OutfitData = Database.outfits.get(StringName(worn[slot]))
		if o:
			equipped[o.slot] = o
	pet_affection = d.get("pet_affection", {})
	_setup_model()
	var pet: PetData = Database.pets.get(StringName(d.get("active_pet", "")))
	if pet and GameState.inventory.count(pet.item) > 0:
		set_active_pet(pet)


## Rebuilds $Visual/Model from base_id, re-wires animations, the held tool and accessories.
func _setup_model() -> void:
	var old := visual.get_node_or_null(^"Model")
	if old:
		visual.remove_child(old)
		old.queue_free()
	var model := Avatar.make_model(base_id)
	visual.add_child(model)
	anim = model.find_children("*", "AnimationPlayer", true, false).pop_front()
	if anim:
		for clip in LOOPING:
			if anim.has_animation(clip):
				anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_hand = null
	_held = null
	var skel := model.find_children("*", "Skeleton3D", true, false).pop_front() as Skeleton3D
	if skel and skel.find_bone(hand_bone) >= 0:
		_hand = BoneAttachment3D.new()
		_hand.bone_name = hand_bone
		skel.add_child(_hand)
	Avatar.dress(model, equipped)
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
	if _riding:
		global_position = _riding.global_position + _ride_offset
		return
	if _sitting:
		if not GameState.ui_busy and Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back").length() > 0.1:
			stand_up()
		return
	if _emote_sit and not GameState.ui_busy and Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back").length() > 0.1:
		_emote_sit = false
		_set_state(State.IDLE)
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
	if _bubble_t > 0.0:
		_bubble_t -= delta
		_bubble.visible = _bubble_t > 0.0
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
	if t == Tool.FERTILIZER:
		return "%s x%d" % [TOOL_NAMES[t], GameState.inventory.count(Database.item(&"fertilizer"))]
	if t != Tool.SEED:
		return TOOL_NAMES[t]
	var s := current_seed()
	return "%s x%d" % [s.crop.display_name, GameState.inventory.count(s)] if s else "Hết hạt"


func teleport(pos: Vector3) -> void:
	if _sitting:
		_sitting = null
		$CollisionShape3D.set_deferred(&"disabled", false)
		_set_state(State.IDLE)
	global_position = pos
	velocity = Vector3.ZERO
	cam.snap()
	if _pet:
		_pet.snap_to_owner()
	interactable = null


func try_interact() -> void:
	if _sitting:
		stand_up()
		return
	if state == State.ACTION or GameState.ui_busy:
		return
	if is_instance_valid(interactable):
		interactable.interact(self)
		return
	if not is_instance_valid(_target):
		return
	var action: StringName = TOOL_ACTIONS[tool]
	for a in PRIORITY_ACTIONS:
		if _target.can(a):
			action = a
			break
	if not _target.can(action):
		var hint := _target.status_text()
		if hint:
			GameState.toast(hint)
		return
	var seed_item := current_seed()
	if action == &"plant" and seed_item == null:
		GameState.toast("Hết hạt giống - mua ở Phố Chợ")
		return
	if CONSUMES.has(action) and GameState.inventory.count(Database.item(CONSUMES[action])) == 0:
		GameState.toast("Hết %s - mua ở Phố Chợ" % Database.item(CONSUMES[action]).display_name)
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


## Speech/emote bubble above the head.
func say(text: String, seconds := 2.5) -> void:
	if not _bubble:
		_bubble = Label3D.new()
		_bubble.position.y = 2.6
		_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bubble.font_size = 64
		_bubble.outline_size = 14
		add_child(_bubble)
	_bubble.text = text
	_bubble.visible = true
	_bubble_t = seconds


func face(point: Vector3) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length() > 0.05:
		visual.rotation.y = atan2(-to.x, -to.z)


## Plays an emote (see EMOTES); nearby neighbors answer via the `emoted` signal.
func emote(kind: StringName) -> void:
	if state == State.ACTION or _sitting or _riding or not EMOTES.has(kind):
		return
	var e: Array = EMOTES[kind]
	say(e[1])
	emoted.emit(kind)
	Quests.notify(&"emote", kind)
	state = State.ACTION
	velocity = Vector3.ZERO
	if not anim or not anim.has_animation(e[0]):
		_set_state(State.IDLE)
		return
	anim.play(e[0], 0.15)
	if kind == &"sit":
		_emote_sit = true # stays seated until you move
		return
	var tw := create_tween()
	tw.tween_interval(anim.get_animation(e[0]).length)
	tw.tween_callback(func() -> void:
		if state == State.ACTION and not _emote_sit:
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


## Rides along with `node` (e.g. a ferris wheel cabin) until end_ride().
func ride(node: Node3D, offset := Vector3.ZERO) -> void:
	_riding = node
	_ride_offset = offset
	state = State.ACTION
	velocity = Vector3.ZERO
	$CollisionShape3D.set_deferred(&"disabled", true)
	if anim and anim.has_animation(&"idle"):
		anim.play(&"idle")


func end_ride(at: Vector3) -> void:
	_riding = null
	$CollisionShape3D.set_deferred(&"disabled", false)
	teleport(at)
	_set_state(State.IDLE)


func is_sitting() -> bool:
	return _sitting != null


func sit_on(seat: Furniture) -> void:
	_sitting = seat
	state = State.ACTION
	velocity = Vector3.ZERO
	$CollisionShape3D.set_deferred(&"disabled", true) # we are inside the seat's collider
	global_position = seat.seat_point()
	visual.rotation.y = seat.facing_yaw()
	if anim and anim.has_animation(&"sit"):
		anim.play(&"sit", 0.2)


func stand_up() -> void:
	if not _sitting:
		return
	global_position = _sitting.stand_point()
	_sitting = null
	$CollisionShape3D.set_deferred(&"disabled", false)
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
	if CONSUMES.has(action) and not GameState.inventory.remove(Database.item(CONSUMES[action])):
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
