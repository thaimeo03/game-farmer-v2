class_name ShopNpc
extends InteractZone
## Shop stall + keeper. Interacting asks the HUD to open the shop panel.

enum Mode { BUY, SELL } ## BUY: player buys `stock`. SELL: player sells anything with a sell price.

@export var title := "Cửa hàng"
@export var mode := Mode.BUY
@export var stock: Array[ItemData] = []
@export var color := Color(0.9, 0.35, 0.3)
@export var keeper: PackedScene ## character model standing behind the counter (plays its "idle" clip)


func _ready() -> void:
	super()
	$Sign.text = title
	if keeper:
		spawn_character(keeper, $KeeperSpot)
	_tint_accent($Stall)


func interact(_player: Player) -> void:
	GameState.shop_requested.emit(self)


## Instances a Kenney character (scale 2.2, looping idle) under `parent`. Shared by other NPC setups.
static func spawn_character(scene: PackedScene, parent: Node3D) -> Node3D:
	var k: Node3D = scene.instantiate()
	k.scale = Vector3.ONE * 2.2
	parent.add_child(k)
	var ap := k.find_children("*", "AnimationPlayer", true, false).pop_front() as AnimationPlayer
	if ap and ap.has_animation(&"idle"):
		ap.get_animation(&"idle").loop_mode = Animation.LOOP_LINEAR
		ap.play(&"idle")
	return k


## Recolors every surface using the Blender material "FP_Accent" (awning stripes) to this shop's color.
func _tint_accent(root: Node) -> void:
	var tinted: StandardMaterial3D
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if src and src.resource_name == "FP_Accent":
				if not tinted:
					tinted = src.duplicate()
					tinted.albedo_color = color
				mi.set_surface_override_material(i, tinted)
