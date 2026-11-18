class_name FarmGrid
extends Node3D
## Spawns a size.x * size.y grid of FarmPlots starting at this node's origin (+X, +Z)
## and maps world positions to plots. Registers itself in group "farm_grid".

signal crop_harvested(plot: FarmPlot, crop: CropData)

@export var plot_scene: PackedScene = preload("res://scenes/farm/farm_plot.tscn")
@export var size := Vector2i(6, 4)
@export var cell_size := 1.2
## Optional fence piece (Kenney nature fence: 1 unit long, sits on the tile's -Z edge).
## A fence ring is built around the field with a gate gap in the middle of the +Z side.
@export var fence_scene: PackedScene

var _plots := {} # Vector2i -> FarmPlot


func _ready() -> void:
	add_to_group(&"farm_grid")
	if fence_scene:
		_build_fence()
	for x in size.x:
		for y in size.y:
			var plot: FarmPlot = plot_scene.instantiate()
			plot.cell = Vector2i(x, y)
			plot.position = Vector3((x + 0.5) * cell_size, 0.0, (y + 0.5) * cell_size)
			add_child(plot)
			plot.harvested.connect(func(crop: CropData) -> void: crop_harvested.emit(plot, crop))
			_plots[plot.cell] = plot
	SaveManager.farm = self
	if not SaveManager.pending_farm.is_empty():
		load_save(SaveManager.pending_farm)
		SaveManager.pending_farm = []


func _build_fence() -> void:
	var m := cell_size * 0.5 # margin between field and fence
	var w := size.x * cell_size + 2.0 * m
	var d := size.y * cell_size + 2.0 * m
	var nx := roundi(w / cell_size)
	var nz := roundi(d / cell_size)
	# [start corner, direction, segment count, segment length, skip index] per side, clockwise
	var sides := [
		[Vector3(-m, 0, -m), Vector3.RIGHT, nx, w / nx, -1],
		[Vector3(w - m, 0, -m), Vector3.BACK, nz, d / nz, -1],
		[Vector3(w - m, 0, d - m), Vector3.LEFT, nx, w / nx, floori(nx / 2.0)], # gate gap facing the spawn
		[Vector3(-m, 0, d - m), Vector3.FORWARD, nz, d / nz, -1],
	]
	for side in sides:
		var dir: Vector3 = side[1]
		var seg_len: float = side[3]
		for i in side[2]:
			if i == side[4]:
				continue
			var holder := StaticBody3D.new()
			holder.position = side[0] + dir * seg_len * (i + 0.5)
			holder.rotation.y = atan2(-dir.z, dir.x) # local +X along the side
			var piece: Node3D = fence_scene.instantiate()
			piece.scale = Vector3.ONE * seg_len
			piece.position.z = 0.5 * seg_len # model's fence sits on its -Z edge
			holder.add_child(piece)
			var shape := CollisionShape3D.new()
			shape.shape = BoxShape3D.new()
			shape.shape.size = Vector3(seg_len, 0.8, 0.15)
			shape.position.y = 0.4
			holder.add_child(shape)
			add_child(holder)


## Only plots that differ from fresh grass are stored.
func to_save() -> Array:
	var out := []
	for plot: FarmPlot in _plots.values():
		if plot.state != FarmPlot.State.NORMAL:
			out.append(plot.to_save())
	return out


func load_save(data: Array) -> void:
	for d: Dictionary in data:
		var plot := get_plot(Vector2i(int(d.cell[0]), int(d.cell[1])))
		if plot:
			plot.from_save(d)


func world_to_cell(world_pos: Vector3) -> Vector2i:
	var p := to_local(world_pos) / cell_size
	return Vector2i(floori(p.x), floori(p.z))


func get_plot(cell: Vector2i) -> FarmPlot:
	return _plots.get(cell)


func get_plot_at(world_pos: Vector3) -> FarmPlot:
	return get_plot(world_to_cell(world_pos))
