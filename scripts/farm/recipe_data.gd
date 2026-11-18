class_name RecipeData
extends Resource
## A processing recipe made on one machine: inputs -> output after `duration` seconds.

@export var id: StringName
@export var machine: StringName ## Machine.machine_id that can make it
@export var input_items: Array[ItemData] = []
@export var input_counts := PackedInt32Array()
@export var output: ItemData
@export var output_count := 1
@export var duration := 30.0
@export var unlock_level := 1


func can_make() -> bool:
	if Progression.level < unlock_level:
		return false
	for i in input_items.size():
		if GameState.inventory.count(input_items[i]) < input_counts[i]:
			return false
	return true


func consume_inputs() -> bool:
	if not can_make():
		return false
	for i in input_items.size():
		GameState.inventory.remove(input_items[i], input_counts[i])
	return true


func inputs_text() -> String:
	var parts := []
	for i in input_items.size():
		parts.append("%d %s" % [input_counts[i], input_items[i].display_name])
	return ", ".join(parts)
