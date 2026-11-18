class_name Door
extends InteractZone
## Walk-through door between two zones (house <-> farm): no bus, just a fade.
## The player appears at the Marker3D named `target_spawn` in the target zone.

@export var target_zone: StringName
@export var target_spawn: StringName = &"PlayerSpawn"


func _ready() -> void:
	if prompt_text == "[E] Nói chuyện":
		prompt_text = "[E] Vào nhà"
	super()


func interact(_player: Player) -> void:
	GameState.travel(target_zone, target_spawn)
