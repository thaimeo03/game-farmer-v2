class_name CaroTable
extends InteractZone
## Stone table in the park: sit down for a game of caro against the AI.


func _ready() -> void:
	if prompt_text == "[E] Nói chuyện":
		prompt_text = "[E] Chơi cờ caro"
	super()


func interact(_player: Player) -> void:
	hud().open_caro()
