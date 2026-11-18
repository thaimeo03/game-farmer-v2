class_name FishPond
extends InteractZone
## Home pond: release a fingerling, wait `grow_time`, then net several fish.
## Saved under "home_pond".

@export var grow_time := 120.0
@export var catch_count := 3
@export var fingerling: ItemData = preload("res://resources/items/fingerling.tres")
@export var catches: Array[ItemData] = [
	preload("res://resources/items/fish_perch.tres"),
	preload("res://resources/items/fish_carp.tres"),
]
@export var rare_catch: ItemData = preload("res://resources/items/fish_gold.tres")
@export var rare_chance := 0.1

var stocked_at := -1.0 ## GameState.clock when stocked; -1 = empty

var _status: Label3D


func _ready() -> void:
	if prompt_text == "[E] Nói chuyện":
		prompt_text = "[E] Ao cá nhà"
	super()
	_status = Label3D.new()
	_status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status.position.y = 1.8
	_status.font_size = 48
	_status.outline_size = 12
	add_child(_status)
	var saved = SaveManager.register(&"home_pond", self)
	if saved:
		stocked_at = float(saved.get("stocked_at", -1.0))


func is_grown() -> bool:
	return stocked_at >= 0.0 and GameState.clock - stocked_at >= grow_time


func _process(_delta: float) -> void:
	if stocked_at < 0.0:
		_status.text = "Ao trống"
	elif is_grown():
		_status.text = "Cá đã lớn!"
	else:
		_status.text = "Cá đang lớn %ds" % ceili(grow_time - (GameState.clock - stocked_at))


func interact(_player: Player) -> void:
	if stocked_at < 0.0:
		if GameState.inventory.remove(fingerling):
			stocked_at = GameState.clock
			GameState.toast("Đã thả cá giống xuống ao")
		else:
			GameState.toast("Cần %s - mua ở Phố Chợ" % fingerling.display_name)
	elif is_grown():
		for i in catch_count:
			GameState.inventory.add(rare_catch if randf() < rare_chance else catches.pick_random())
		stocked_at = -1.0
		Progression.reward(&"pond")
		GameState.toast("Vớt được %d con cá!" % catch_count)
	else:
		GameState.toast("Cá chưa lớn, chờ thêm nhé")


func to_save() -> Dictionary:
	return {"stocked_at": stocked_at}
