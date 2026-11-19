class_name ItemData
extends Resource
## Anything that can sit in the inventory. One .tres per item in res://resources/items/.

enum Category { SEED, PRODUCE, FISH, TOOL, OUTFIT, MISC, ANIMAL, GOODS, FURNITURE, PET } ## append only: values are stored in .tres

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var category := Category.MISC
@export var icon: Texture2D
@export var color := Color.WHITE ## placeholder icon color when no icon is set
@export var buy_price := 0 ## 0 = not sold in shops
@export var sell_price := 0 ## 0 = cannot be sold
@export var crop: CropData ## seeds only: what this seed grows into
@export var model: PackedScene ## optional 3D model (shown e.g. when a fish is caught)
@export var size_range := Vector2.ZERO ## fish: size in cm when caught (min, max)

static var _swatches := {}


func get_icon() -> Texture2D:
	if icon:
		return icon
	if not _swatches.has(color):
		var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
		img.fill(color)
		_swatches[color] = ImageTexture.create_from_image(img)
	return _swatches[color]
