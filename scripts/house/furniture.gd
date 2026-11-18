class_name Furniture
extends InteractZone
## A placed piece of furniture. Sits centered on its footprint (cells of 1 m) inside the
## house room, solid unless it is a rug. Seats can be sat on: E to sit, E or move to stand.

const SIT_HEIGHT := 0.25

var data: FurnitureData
var cell := Vector2i.ZERO
var rot := 0 ## quarter turns


func setup(furniture: FurnitureData, at_cell: Vector2i, rotation_steps: int) -> Furniture:
	data = furniture
	cell = at_cell
	rot = rotation_steps % 4
	return self


func size() -> Vector2i:
	return data.size_for(rot)


func _ready() -> void:
	prompt_text = "[E] Ngồi"
	prompt_height = 2.0
	super()
	var holder := Node3D.new()
	holder.rotation.y = -rot * PI * 0.5
	add_child(holder)
	var model: Node3D = data.model.instantiate()
	model.scale = Vector3.ONE * data.model_scale
	holder.add_child(model)
	# Kenney furniture has its origin on a corner: re-center it on the footprint.
	var box := _local_bounds(model, holder)
	model.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var s := size()
	if not data.floor_layer:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = Vector3(s.x * 0.9, 1.0, s.y * 0.9)
		shape.position.y = 0.5
		body.add_child(shape)
		add_child(body)
	if data.seat:
		var near := CollisionShape3D.new()
		near.shape = SphereShape3D.new()
		near.shape.radius = maxf(s.x, s.y) * 0.5 + 0.6
		near.position.y = 0.6
		add_child(near)


func interact(player: Player) -> void:
	player.sit_on(self)


## Yaw the sitter faces: the furniture's front (+Z of the unrotated model).
func facing_yaw() -> float:
	return PI - rot * PI * 0.5


func seat_point() -> Vector3:
	return global_position + Vector3.UP * SIT_HEIGHT


func stand_point() -> Vector3:
	var front := Vector3(0, 0, 1).rotated(Vector3.UP, -rot * PI * 0.5)
	return global_position + front * (maxi(size().x, size().y) * 0.5 + 0.6)


static func _local_bounds(model: Node3D, space: Node3D) -> AABB:
	var inv := space.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var b := inv * mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
