class_name TreasureChest
extends InteractZone
## Opens once per in-game day: xu, Lượng and sometimes spin tickets.

var _label: Label3D


func _ready() -> void:
	if prompt_text == "[E] Nói chuyện":
		prompt_text = "[E] Mở rương kho báu"
	super()
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 1.6
	_label.font_size = 44
	_label.outline_size = 12
	add_child(_label)


func _process(_delta: float) -> void:
	_label.text = "Đã mở hôm nay" if GameState.daily_count("treasure") > 0 else "Rương kho báu!"


func interact(_player: Player) -> void:
	if not GameState.daily_use("treasure", 1):
		return
	var coins := randi_range(100, 300)
	var gems := randi_range(3, 8)
	GameState.earn(coins)
	GameState.gems += gems
	GameState.money_changed.emit()
	var extra := ""
	if randf() < 0.3:
		GameState.inventory.add(Database.item(&"spin_ticket"), 2)
		extra = " +2 Vé quay"
	GameState.toast("Kho báu! +%d xu +%d Lượng%s" % [coins, gems, extra])
	var tw := create_tween()
	tw.tween_property($Model, "scale", Vector3.ONE * 1.25, 0.15)
	tw.tween_property($Model, "scale", Vector3.ONE, 0.2)
