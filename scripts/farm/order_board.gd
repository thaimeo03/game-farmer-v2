class_name OrderBoard
extends InteractZone
## Delivery orders: `slots` random requests ("4 Cà rốt + 2 Trứng gà") paying more than the
## market. Delivering sends the truck off and the slot refills after `cooldown`.
## Saved under "order_board".

## Items orders may ask for, and the level from which each appears.
const POOL := {
	&"carrot": 1, &"tomato": 1, &"pumpkin": 1, &"egg": 1, &"fish_perch": 1, &"carrot_juice": 1,
	&"veggie_salad": 1, &"tomato_juice": 2, &"milk": 2, &"wool": 2, &"truffle": 3,
	&"pumpkin_pie": 2, &"wool_scarf": 2, &"mushroom_soup": 3,
}

@export var slots := 3
@export var cooldown := 45.0
@export var bonus := 1.4 ## reward = market value * bonus + 10
@export var truck: Node3D

var orders: Array = [] ## [{"items": {id: count}, "coins": int, "xp": int, "ready_at": float}]

var _truck_home: Vector3


func _ready() -> void:
	if prompt_text == "[E] Nói chuyện":
		prompt_text = "[E] Bảng đơn hàng"
	super()
	if truck:
		_truck_home = truck.position
	var saved = SaveManager.register(&"order_board", self)
	if saved:
		orders = saved.get("orders", [])
	while orders.size() < slots:
		orders.append(make_order(0.0))


func make_order(ready_at: float) -> Dictionary:
	var choices := POOL.keys().filter(func(id: StringName) -> bool: return POOL[id] <= Progression.level)
	choices.shuffle()
	var items := {}
	var value := 0
	var total := 0
	for id: StringName in choices.slice(0, randi_range(1, 2)):
		var item := Database.item(id)
		var n := randi_range(2, 5) if item.category != ItemData.Category.GOODS else randi_range(1, 2)
		items[String(id)] = n
		value += item.sell_price * n
		total += n
	return {"items": items, "coins": int(value * bonus) + 10, "xp": 5 + total * 2, "ready_at": ready_at}


func can_fill(order: Dictionary) -> bool:
	for id: String in order.items:
		if GameState.inventory.count(Database.item(StringName(id))) < int(order.items[id]):
			return false
	return true


func deliver(index: int) -> bool:
	var order: Dictionary = orders[index]
	if GameState.clock < float(order.ready_at) or not can_fill(order):
		return false
	for id: String in order.items:
		GameState.inventory.remove(Database.item(StringName(id)), int(order.items[id]))
	GameState.earn(int(order.coins))
	Progression.add_xp(int(order.xp))
	GameState.toast("Đã giao đơn! +%d xu, +%d EXP" % [int(order.coins), int(order.xp)])
	orders[index] = make_order(GameState.clock + cooldown)
	_send_truck()
	return true


func interact(_player: Player) -> void:
	var rows := []
	for i in orders.size():
		var o: Dictionary = orders[i]
		var wait := float(o.ready_at) - GameState.clock
		if wait > 0.0:
			rows.append({"text": "Đơn mới sau %ds..." % ceili(wait)})
			continue
		var parts := []
		for id: String in o.items:
			var item := Database.item(StringName(id))
			parts.append("%s %d/%d" % [item.display_name, GameState.inventory.count(item), int(o.items[id])])
		rows.append({
			"text": "%s\n→ %d xu, %d EXP" % [", ".join(parts), int(o.coins), int(o.xp)],
			"buttons": [["Giao", deliver.bind(i), can_fill(o)]],
		})
	hud().open_menu("Đơn Hàng Giao Xe Tải", rows)


func to_save() -> Dictionary:
	return {"orders": orders}


func _send_truck() -> void:
	if not truck:
		return
	var tw := create_tween()
	tw.tween_property(truck, "position", _truck_home + truck.basis.x * 30.0, 2.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void: truck.position = _truck_home - truck.basis.x * 30.0)
	tw.tween_interval(2.0)
	tw.tween_property(truck, "position", _truck_home, 2.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
