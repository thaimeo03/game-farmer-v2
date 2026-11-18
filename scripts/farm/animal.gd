class_name Animal
extends InteractZone
## One farm animal wandering inside its pen. Hungry -> fed (uses 1 feed) -> after
## produce_time it has a product to collect -> hungry again.

var data: AnimalData
var bounds := Rect2(-3, -2, 6, 4) ## wander area in the pen's local XZ
var fed_at := -1.0 ## GameState.clock when fed; -1 = hungry
var has_product := false

var _model: Node3D
var _anim: AnimationPlayer
var _status: Label3D
var _target := Vector3.ZERO
var _wait := 0.0


func setup(animal: AnimalData, area: Rect2) -> Animal:
	data = animal
	bounds = area
	return self


func _ready() -> void:
	prompt_height = 1.9
	super()
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	shape.shape.radius = 1.1
	shape.position.y = 0.5
	add_child(shape)
	_model = data.model.instantiate()
	_model.scale = Vector3.ONE * data.model_scale
	add_child(_model)
	_anim = _model.find_children("*", "AnimationPlayer", true, false).pop_front()
	for clip in [&"idle", &"walk"]:
		if _anim and _anim.has_animation(clip):
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_status = Label3D.new()
	_status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status.position.y = 1.45
	_status.font_size = 44
	_status.outline_size = 12
	add_child(_status)
	_pick_target()
	_refresh()


func _process(delta: float) -> void:
	if fed_at >= 0.0 and GameState.clock - fed_at >= data.produce_time:
		fed_at = -1.0
		has_product = true
		_refresh()
	elif fed_at >= 0.0:
		_status.text = "%ds" % ceili(data.produce_time - (GameState.clock - fed_at))
	_wander(delta)


func interact(_player: Player) -> void:
	if has_product:
		has_product = false
		GameState.inventory.add(data.product)
		Progression.reward(&"collect")
		GameState.toast("+1 %s" % data.product.display_name)
	elif fed_at < 0.0:
		if GameState.inventory.remove(data.feed):
			fed_at = GameState.clock
			GameState.toast("Đã cho %s ăn" % data.display_name)
		else:
			GameState.toast("Hết %s - mua ở Phố Chợ" % data.feed.display_name)
	else:
		GameState.toast("%s đang no, chờ thêm chút nhé" % data.display_name)
	_refresh()


func to_save() -> Dictionary:
	return {"id": String(data.id), "fed_at": fed_at, "has_product": has_product}


func _refresh() -> void:
	if has_product:
		_status.text = "Xong! %s" % data.product.display_name
		_status.modulate = Color(0.6, 1, 0.5)
		set_prompt("[E] %s" % data.collect_verb)
	elif fed_at < 0.0:
		_status.text = "Đói"
		_status.modulate = Color(1, 0.75, 0.4)
		set_prompt("[E] Cho ăn")
	else:
		_status.modulate = Color.WHITE
		set_prompt("[E] Xem")


func _wander(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		return
	var to := _target - position
	to.y = 0.0
	if to.length() < 0.1:
		_wait = randf_range(1.5, 4.0)
		_pick_target()
		_play(&"idle")
		return
	position += to.normalized() * minf(0.7 * delta, to.length())
	_model.rotation.y = atan2(to.x, to.z) # Kenney animals face +Z
	_play(&"walk")


func _pick_target() -> void:
	_target = Vector3(randf_range(bounds.position.x, bounds.end.x), 0.0, randf_range(bounds.position.y, bounds.end.y))


func _play(clip: StringName) -> void:
	if _anim and _anim.has_animation(clip) and _anim.current_animation != clip:
		_anim.play(clip, 0.2)
