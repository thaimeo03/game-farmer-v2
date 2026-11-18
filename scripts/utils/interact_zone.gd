class_name InteractZone
extends Area3D
## Area the player can stand in to interact (E / Space / click). While inside, it becomes
## the player's `interactable` and shows a floating prompt. Subclasses override interact(),
## or listeners connect to `interacted`.

signal interacted(player: Player)

@export var prompt_text := "[E] Nói chuyện"
@export var prompt_height := 2.6

var _prompt: Label3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	_prompt = get_node_or_null(^"Prompt")
	if not _prompt:
		_prompt = Label3D.new()
		_prompt.position.y = prompt_height
		_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_prompt.modulate = Color(1, 0.95, 0.4)
		_prompt.outline_modulate = Color.BLACK
		_prompt.font_size = 40
		_prompt.outline_size = 12
		add_child(_prompt)
	_prompt.text = prompt_text
	_prompt.visible = false
	body_entered.connect(_on_body.bind(true))
	body_exited.connect(_on_body.bind(false))


func interact(player: Player) -> void:
	interacted.emit(player)


func _on_body(body: Node3D, entered: bool) -> void:
	if body is Player:
		_prompt.visible = entered
		if entered:
			body.interactable = self
		elif body.interactable == self:
			body.interactable = null
