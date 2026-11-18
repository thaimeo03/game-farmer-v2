class_name AnimalData
extends Resource
## A farm animal kind. Buying `item` at the shop and releasing it at the pen spawns one.
## Fed with `feed`, it produces `product` after `produce_time` seconds.

@export var id: StringName
@export var display_name := ""
@export var model: PackedScene
@export var model_scale := 0.45
@export var item: ItemData ## what the shop sells (e.g. "Gà con")
@export var feed: ItemData
@export var product: ItemData
@export var produce_time := 60.0
@export var collect_verb := "Thu" ## prompt word: "Thu trứng", "Vắt sữa"...
