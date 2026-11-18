class_name FurnitureData
extends Resource
## A placeable furniture kind. Bought as `item` (category FURNITURE), placed on the house grid.

@export var id: StringName
@export var item: ItemData
@export var model: PackedScene
@export var model_scale := 2.0
@export var footprint := Vector2i.ONE ## grid cells (x, z) at rotation 0
@export var beauty := 1 ## adds to the house's "Điểm đẹp nhà"
@export var seat := false ## the player can sit on it
@export var floor_layer := false ## rugs: lie on the floor, other furniture can stand on them


func size_for(rot: int) -> Vector2i:
	return footprint if rot % 2 == 0 else Vector2i(footprint.y, footprint.x)
