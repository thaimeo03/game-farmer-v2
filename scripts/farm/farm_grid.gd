class_name FarmGrid
extends Node3D
## Grid of FarmPlots starting at this node's origin (+X, +Z), fenced, with a sign that sells
## extra columns of land. Maps world positions to plots. Registers itself in group
## "farm_grid" and with SaveManager under "farm_grid".

signal crop_harvested(plot: FarmPlot, crop: CropData)

const SIGN := preload("res://assets/models/kenney/nature/sign.glb")

@export var plot_scene: PackedScene = preload("res://scenes/farm/farm_plot.tscn")
@export var size := Vector2i(6, 4)
@export var cell_size := 1.2
@export var fence_scene: PackedScene ## optional fence ring with a gate on the +Z side
@export var max_columns := 10
@export var land_cost := 150 ## price of the 7th column; each further column costs this much more

var _plots := {} # Vector2i -> FarmPlot
var _fence: Node3D
var _sign: InteractZone


func _ready() -> void:
	add_to_group(&"farm_grid")
	for x in size.x:
		for y in size.y:
			_add_plot(Vector2i(x, y))
	_rebuild_fence()
	_build_sign()
	var saved = SaveManager.register(&"farm_grid", self)
	if saved:
		load_save(saved)


func world_to_cell(world_pos: Vector3) -> Vector2i:
	var p := to_local(world_pos) / cell_size
	return Vector2i(floori(p.x), floori(p.z))


func get_plot(cell: Vector2i) -> FarmPlot:
	return _plots.get(cell)


func get_plot_at(world_pos: Vector3) -> FarmPlot:
	return get_plot(world_to_cell(world_pos))


## Admin/debug: every planted plot becomes harvestable.
func ripen_all() -> void:
	for plot: FarmPlot in _plots.values():
		if plot.crop and plot.state == FarmPlot.State.PLANTED:
			plot.stage = plot.crop.stage_durations.size()
			plot.state = FarmPlot.State.HARVESTABLE
			plot.problem = FarmPlot.Problem.NONE
			plot._refresh()


## Waters up to `limit` plots that need it (rain, visiting neighbors). Returns how many.
func water_dry(limit := 1 << 30) -> int:
	var n := 0
	for plot: FarmPlot in _plots.values():
		if n < limit and plot.can(&"water"):
			plot.perform(&"water")
			n += 1
	return n


func _process(_delta: float) -> void:
	# rain waters the whole farm (checked twice a second)
	if Engine.get_process_frames() % 30 == 0 and GameState.is_raining():
		water_dry()


func expand_cost() -> int:
	return land_cost * (size.x - 5)


func expand_level() -> int:
	return size.x - 4


## Adds one column of plots on the +X side.
func expand() -> void:
	if size.x >= max_columns:
		return
	for y in size.y:
		_add_plot(Vector2i(size.x, y))
	size.x += 1
	_rebuild_fence()
	_place_sign()


func to_save() -> Dictionary:
	var plots := []
	for plot: FarmPlot in _plots.values():
		if plot.state != FarmPlot.State.NORMAL:
			plots.append(plot.to_save())
	return {"columns": size.x, "plots": plots}


func load_save(data: Dictionary) -> void:
	while size.x < mini(int(data.get("columns", size.x)), max_columns):
		expand()
	for d: Dictionary in data.get("plots", []):
		var plot := get_plot(Vector2i(int(d.cell[0]), int(d.cell[1])))
		if plot:
			plot.from_save(d)


func _add_plot(cell: Vector2i) -> void:
	var plot: FarmPlot = plot_scene.instantiate()
	plot.cell = cell
	plot.position = Vector3((cell.x + 0.5) * cell_size, 0.0, (cell.y + 0.5) * cell_size)
	add_child(plot)
	plot.harvested.connect(func(crop: CropData) -> void: crop_harvested.emit(plot, crop))
	_plots[cell] = plot


func _rebuild_fence() -> void:
	if _fence:
		_fence.queue_free()
		_fence = null
	if fence_scene:
		var m := cell_size * 0.5
		_fence = Fence.build(self, Vector3(-m, 0, -m), size.x * cell_size + 2.0 * m,
			size.y * cell_size + 2.0 * m, cell_size, fence_scene)


func _build_sign() -> void:
	_sign = InteractZone.new()
	_sign.prompt_text = "[E] Mở rộng đất"
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	shape.shape.radius = 1.3
	shape.position.y = 0.8
	_sign.add_child(shape)
	var model: Node3D = SIGN.instantiate()
	model.scale = Vector3.ONE * 2.5
	model.rotation.y = -PI * 0.5
	_sign.add_child(model)
	add_child(_sign)
	_sign.interacted.connect(_on_sign)
	_place_sign()


func _place_sign() -> void:
	_sign.position = Vector3(size.x * cell_size + 1.6, 0.0, size.y * cell_size * 0.5)
	_sign.visible = size.x < max_columns
	_sign.set_prompt("[E] Mở rộng đất" if size.x < max_columns else "Đã mở rộng tối đa")


func _on_sign(_player: Player) -> void:
	if size.x >= max_columns:
		GameState.toast("Ruộng đã rộng tối đa")
		return
	var cost := expand_cost()
	var lvl := expand_level()
	var ok := Progression.level >= lvl and GameState.coins >= cost
	var buy := func() -> void:
		if Progression.level >= lvl and GameState.spend(cost):
			expand()
			GameState.toast("Ruộng đã rộng thêm!")
	_sign.hud().open_menu("Mở rộng đất", [{
		"text": "Thêm 1 cột (%d ô)\nGiá %d xu — cần cấp %d" % [size.y, cost, lvl],
		"buttons": [["Mua", buy, ok]],
	}])
