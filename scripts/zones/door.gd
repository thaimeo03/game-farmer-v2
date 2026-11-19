class_name Door
extends InteractZone
## Walk-through door between two zones (house <-> farm): no bus, just a fade.
## The player appears at the Marker3D named `target_spawn` in the target zone.

@export var target_zone: StringName
@export var target_spawn: StringName = &"PlayerSpawn"
@export var fare := 0 ## xu to pay (boat ticket)
@export var min_level := 1


func _ready() -> void:
	if prompt_text == "[E] Nói chuyện":
		prompt_text = "[E] Vào nhà"
	super()


func interact(_player: Player) -> void:
	if Progression.level < min_level:
		GameState.toast("Cần cấp %d" % min_level)
		return
	if fare > 0 and not GameState.spend(fare):
		return
	GameState.travel(target_zone, target_spawn)
