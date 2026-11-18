class_name Scatter
extends Node3D
## Deterministically scatters random props (trees, flowers, rocks...) over a rectangle
## centered on this node, skipping keep-out rectangles (fields, paths, plazas).

@export var scenes: Array[PackedScene] = []
@export var count := 40
@export var area := Vector2(40, 40) ## XZ size, centered on this node
@export var keep_out: Array[Rect2] = [] ## local XZ rects (x, z, width, depth) left empty
@export var scale_range := Vector2(1.8, 2.6)
@export var collision_radius := 0.0 ## > 0 adds a solid cylinder (trees, big rocks)
@export var random_seed := 1


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var placed := 0
	var terrain := get_parent().get_node_or_null(^"Terrain") as Terrain # props follow the hills
	for _try in count * 20:
		if placed >= count or scenes.is_empty():
			break
		var p := Vector2(rng.randf_range(-area.x, area.x), rng.randf_range(-area.y, area.y)) * 0.5
		if keep_out.any(func(r: Rect2) -> bool: return r.has_point(p)):
			continue
		var g := to_global(Vector3(p.x, 0.0, p.y))
		var h := terrain.height_at(g.x, g.z) if terrain else 0.0
		if terrain and h < terrain.water_level + 0.3:
			continue # no props in ponds
		var prop: Node3D = scenes[rng.randi() % scenes.size()].instantiate()
		prop.position = Vector3(p.x, h, p.y)
		prop.rotation.y = rng.randf() * TAU
		prop.scale = Vector3.ONE * rng.randf_range(scale_range.x, scale_range.y)
		add_child(prop)
		if collision_radius > 0.0:
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			shape.shape = CylinderShape3D.new()
			shape.shape.radius = collision_radius
			shape.position.y = 1.0
			body.add_child(shape)
			body.position = prop.position
			add_child(body)
		placed += 1
