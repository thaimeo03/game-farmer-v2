class_name Inventory
extends RefCounted
## Item -> count bag. Insertion order is kept, so the UI lists items in pickup order.

signal changed

var _items: Dictionary[ItemData, int] = {}


func count(item: ItemData) -> int:
	return _items.get(item, 0)


func add(item: ItemData, amount := 1) -> void:
	assert(item and amount > 0)
	_items[item] = count(item) + amount
	changed.emit()


func remove(item: ItemData, amount := 1) -> bool:
	if amount <= 0 or count(item) < amount:
		return false
	_items[item] -= amount
	if _items[item] == 0:
		_items.erase(item)
	changed.emit()
	return true


func items(category := -1) -> Array[ItemData]:
	var out: Array[ItemData] = []
	for item: ItemData in _items:
		if category < 0 or item.category == category:
			out.append(item)
	return out


func to_save() -> Dictionary:
	var out := {}
	for item: ItemData in _items:
		out[String(item.id)] = _items[item]
	return out


func from_save(data: Dictionary) -> void:
	_items.clear()
	for id: String in data:
		var item := Database.item(StringName(id))
		if item:
			_items[item] = int(data[id])
		else:
			push_warning("Save has unknown item id '%s', skipped" % id)
	changed.emit()
