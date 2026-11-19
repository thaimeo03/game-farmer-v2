class_name ShellSpawner
extends Node3D
## Scatters pick-up seashells over `area` (local XZ rect) once per in-game day. Picked shells
## stay gone until the next day (re-checked each time the zone is entered).

const KINDS := [
	[&"shell_scallop", preload("res://assets/models/props/shell_scallop.glb")],
	[&"shell_conch", preload("res://assets/models/props/shell_conch.glb")],
	[&"starfish", preload("res://assets/models/props/starfish.glb")],
]

@export var area := Rect2(-10, -6, 20, 10)
@export var count := 8

var _day := -1


func _enter_tree() -> void:
	_respawn_if_new_day.call_deferred()


func _respawn_if_new_day() -> void:
	if GameState.day() == _day:
		return
	_day = GameState.day()
	for c in get_children():
		c.queue_free()
	var terrain := get_parent().get_node_or_null(^"Terrain") as Terrain
	for i in count:
		var kind: Array = KINDS.pick_random()
		var shell := InteractZone.new()
		shell.prompt_text = "[E] Nhặt %s" % Database.item(kind[0]).display_name
		shell.prompt_height = 0.8
		shell.position = Vector3(randf_range(area.position.x, area.end.x), 0.0, randf_range(area.position.y, area.end.y))
		var g := to_global(shell.position)
		shell.position.y = terrain.height_at(g.x, g.z) if terrain else 0.0
		var shape := CollisionShape3D.new()
		shape.shape = SphereShape3D.new()
		shape.shape.radius = 0.8
		shell.add_child(shape)
		var model: Node3D = kind[1].instantiate()
		model.scale = Vector3.ONE * 1.6
		model.rotation.y = randf() * TAU
		shell.add_child(model)
		shell.interacted.connect(_pick.bind(shell, kind[0]))
		add_child(shell)


func _pick(_player: Player, shell: InteractZone, id: StringName) -> void:
	GameState.inventory.add(Database.item(id))
	GameState.toast("+1 %s" % Database.item(id).display_name)
	shell.queue_free()
