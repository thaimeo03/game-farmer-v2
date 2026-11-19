class_name EmoteWheel
extends Control
## Emote wheel (G): six round buttons around the screen center.

var player: Player


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var kinds := Player.EMOTES.keys()
	for i in kinds.size():
		var e: Array = Player.EMOTES[kinds[i]]
		var b := Button.new()
		b.text = "%s\n%s" % [e[1], e[2]]
		b.custom_minimum_size = Vector2(96, 74)
		b.focus_mode = Control.FOCUS_NONE
		var a := TAU * i / kinds.size() - PI * 0.5
		b.position = Vector2(cos(a), sin(a)) * 130.0 - b.custom_minimum_size * 0.5
		b.pressed.connect(_pick.bind(kinds[i]))
		add_child(b)
	var hint := Label.new()
	hint.text = "Biểu cảm"
	hint.position = Vector2(-36, -12)
	add_child(hint)


func _pick(kind: StringName) -> void:
	(get_tree().get_first_node_in_group(&"hud") as Hud).close_panels()
	player.emote(kind)
