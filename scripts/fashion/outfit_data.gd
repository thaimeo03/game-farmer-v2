class_name OutfitData
extends Resource
## A wearable accessory attached to a bone of the character. Owned as `item` (category OUTFIT).

enum Slot { HAT, GLASSES, NECK, BACK, AURA }
const SLOT_NAMES: Array[String] = ["Mũ", "Kính", "Cổ", "Lưng", "Hào quang"]

@export var id: StringName
@export var item: ItemData
@export var model: PackedScene
@export var slot := Slot.HAT
@export var gem_price := 0 ## > 0: bought with Lượng instead of xu
@export var unlock_level := 1
