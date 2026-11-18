class_name PetCompanion
extends Node3D
## The active pet, trotting after its owner (top-level child of the Player, so it travels
## with them between zones). Not an interact zone (it is always next to the player and would
## steal E); pet it / give treats from the wardrobe menu (O).

const PET_COOLDOWN := 30.0
const TREAT := &"pet_treat"

var owner_player: Player
var data: PetData

var _model: Node3D
var _anim: AnimationPlayer
var _label: Label3D
var _last_pet := -999.0


func _ready() -> void:
	top_level = true
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 1.05
	_label.font_size = 26
	_label.outline_size = 8
	add_child(_label)
	set_pet(data)


func set_pet(pet: PetData) -> void:
	data = pet
	if not is_inside_tree():
		return
	if _model:
		_model.queue_free()
		_model = null
	visible = pet != null
	if not pet:
		return
	_model = pet.model.instantiate()
	_model.scale = Vector3.ONE * pet.model_scale
	add_child(_model)
	_anim = _model.find_children("*", "AnimationPlayer", true, false).pop_front()
	for clip in [&"idle", &"walk", &"run"]:
		if _anim and _anim.has_animation(clip):
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_update_label()
	snap_to_owner()


func snap_to_owner() -> void:
	if owner_player and is_inside_tree():
		global_position = _follow_point()


func _physics_process(delta: float) -> void:
	if not data or not owner_player:
		return
	var target := _follow_point()
	var to := target - global_position
	to.y = 0.0
	var dist := to.length()
	if dist > 12.0: # left far behind (teleport, bus): catch up instantly
		snap_to_owner()
		return
	if dist > 0.3:
		var speed := clampf(dist * 2.5, 1.0, 8.0)
		global_position += to.normalized() * minf(speed * delta, dist)
		_model.rotation.y = atan2(to.x, to.z) # Kenney animals face +Z
		_play(&"run" if speed > 4.0 else &"walk")
	else:
		_play(&"idle")
	global_position.y = lerpf(global_position.y, owner_player.global_position.y, 1.0 - exp(-10.0 * delta))


## Menu rows for the wardrobe: pet it / feed it.
func menu_rows(player: Player) -> Array:
	var rows := [{
		"text": "%s — cấp %d (thân thiết %d)" % [data.display_name, player.pet_level(), player.pet_affection.get(String(data.id), 0)],
	}, {
		"text": "Vuốt ve (+1 thân thiết)",
		"buttons": [["Vuốt ve", _pet_it.bind(player), GameState.clock - _last_pet >= PET_COOLDOWN]],
	}, {
		"text": "Cho ăn Bánh thưởng (+5 thân thiết) — có %d" % GameState.inventory.count(Database.item(TREAT)),
		"buttons": [["Cho ăn", _feed.bind(player), GameState.inventory.count(Database.item(TREAT)) > 0]],
	}]
	return rows


func _pet_it(player: Player) -> void:
	_last_pet = GameState.clock
	player.add_affection(1)
	_cheer()


func _feed(player: Player) -> void:
	if GameState.inventory.remove(Database.item(TREAT)):
		player.add_affection(5)
		_cheer()


func _cheer() -> void:
	_update_label()
	GameState.toast("%s vui lắm! ♥" % data.display_name)
	var tw := create_tween()
	tw.tween_property(_model, "position:y", 0.4, 0.15)
	tw.tween_property(_model, "position:y", 0.0, 0.2)


func _update_label() -> void:
	if data and owner_player:
		_label.text = "%s Lv%d" % [data.display_name, owner_player.pet_level()]


func _follow_point() -> Vector3:
	var back := owner_player.visual.global_transform.basis.z # player faces -Z: +Z is behind
	return owner_player.global_position + back * 1.3 + back.cross(Vector3.UP) * 0.5


func _play(clip: StringName) -> void:
	if _anim and _anim.has_animation(clip) and _anim.current_animation != clip:
		_anim.play(clip, 0.2)
