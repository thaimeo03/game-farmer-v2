class_name PetData
extends Resource
## A companion pet kind. Owned as `item` (category PET); the active one follows the player
## and can run in the pet race. Affection (petting, treats) raises its level and race speed.

@export var id: StringName
@export var display_name := ""
@export var item: ItemData
@export var model: PackedScene
@export var model_scale := 0.4
@export var base_speed := 4.3 ## race speed at level 1


func level_for(affection: int) -> int:
	return 1 + mini(affection / 20, 9)


func race_speed(affection: int) -> float:
	return base_speed + 0.08 * (level_for(affection) - 1)
