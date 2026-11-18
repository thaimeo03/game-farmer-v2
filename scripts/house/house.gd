class_name House
extends Node3D
## The player's house interior: a room_size grid of 1 m cells from this node's origin (+X, +Z).
## Decorate mode (B): pick owned furniture in the HUD list, a ghost follows the mouse on the
## grid (green = fits, red = blocked), R rotates, click places; clicking a placed piece puts
## it back in the bag. Floor and wall colors can be changed. Saved under "house".

const FLOORS: Array[Color] = [Color(0.72, 0.52, 0.34), Color(0.85, 0.7, 0.5), Color(0.55, 0.38, 0.26), Color(0.9, 0.86, 0.8), Color(0.62, 0.7, 0.78)]
const WALLS: Array[Color] = [Color(0.98, 0.93, 0.82), Color(0.8, 0.9, 0.98), Color(0.98, 0.82, 0.85), Color(0.82, 0.95, 0.82), Color(0.95, 0.9, 0.65), Color(0.85, 0.8, 0.95)]
const WALL_HEIGHT := 3.0
const LOW_WALL := 0.5

@export var room_size := Vector2i(8, 6)

var floor_style := 0
var wall_style := 0
var decorating := false
var selected: FurnitureData
var _rot := 0
var _cell := Vector2i(-99, -99)
var _occupied := {} ## Vector2i -> Furniture (solid layer)
var _floor_occupied := {} ## Vector2i -> Furniture (rugs)
var _floor_mat := StandardMaterial3D.new()
var _wall_mat := StandardMaterial3D.new()
var _ghost: Node3D
var _cursor: MeshInstance3D
var _items: Node3D


func _ready() -> void:
	add_to_group(&"house")
	_items = Node3D.new()
	_items.name = "Furniture"
	add_child(_items)
	_build_room()
	var saved = SaveManager.register(&"house", self)
	if saved:
		load_save(saved)
	else: # starter furniture for a new game
		for spec in [[&"bed_single", Vector2i(0, 0), 0], [&"side_table", Vector2i(1, 0), 0], [&"rug_round", Vector2i(3, 2), 0],
				[&"coffee_table", Vector2i(3, 2), 0], [&"chair", Vector2i(5, 2), 1], [&"potted_plant", Vector2i(7, 0), 0]]:
			place(Database.furniture[spec[0]], spec[1], spec[2], false)
	_apply_styles()


func _enter_tree() -> void:
	_update_info.call_deferred()


func _exit_tree() -> void:
	if decorating:
		set_decorating(false)
	var hud := _hud()
	if hud:
		hud.show_info("")


# ---------------------------------------------------------------- placement

func can_place(data: FurnitureData, cell: Vector2i, rot: int) -> bool:
	var layer := _floor_occupied if data.floor_layer else _occupied
	var s := data.size_for(rot)
	for x in s.x:
		for y in s.y:
			var c := cell + Vector2i(x, y)
			if c.x < 0 or c.y < 0 or c.x >= room_size.x or c.y >= room_size.y or layer.has(c):
				return false
	return true


func place(data: FurnitureData, cell: Vector2i, rot: int, from_bag := true) -> Furniture:
	if not can_place(data, cell, rot) or (from_bag and not GameState.inventory.remove(data.item)):
		return null
	var f := Furniture.new().setup(data, cell, rot)
	var s := f.size()
	f.position = Vector3(cell.x + s.x * 0.5, 0.0, cell.y + s.y * 0.5)
	_items.add_child(f)
	_mark(f, f)
	_update_info()
	return f


func pick_up(f: Furniture) -> void:
	_mark(f, null)
	GameState.inventory.add(f.data.item)
	f.queue_free()
	_update_info()


func furniture_at(cell: Vector2i) -> Furniture:
	return _occupied.get(cell, _floor_occupied.get(cell))


func beauty() -> int:
	var total := 0
	for f: Furniture in _items.get_children():
		if not f.is_queued_for_deletion():
			total += f.data.beauty
	return total


func next_floor() -> void:
	floor_style = (floor_style + 1) % FLOORS.size()
	_apply_styles()


func next_wall() -> void:
	wall_style = (wall_style + 1) % WALLS.size()
	_apply_styles()


# ---------------------------------------------------------------- decorate mode

func set_decorating(on: bool) -> void:
	decorating = on
	GameState.ui_busy = on
	_cursor.visible = on
	select(null)
	var hud := _hud()
	if hud:
		if on:
			hud.show_decorate(self)
		else:
			hud.hide_decorate()


func select(data: FurnitureData) -> void:
	selected = data
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	if data:
		_ghost = Furniture.new().setup(data, Vector2i.ZERO, _rot)
		_ghost.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(_ghost)
		_ghost.collision_layer = 0
		_ghost.monitoring = false
		for body in _ghost.find_children("*", "StaticBody3D", true, false):
			body.queue_free()
		for mi: GeometryInstance3D in _ghost.find_children("*", "GeometryInstance3D", true, false):
			mi.transparency = 0.45
	_update_cursor()


func rotate_selection() -> void:
	_rot = (_rot + 1) % 4
	select(selected)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"decorate"):
		if decorating or not GameState.ui_busy:
			set_decorating(not decorating)
			get_viewport().set_input_as_handled()
		return
	if not decorating:
		return
	if event is InputEventMouseMotion:
		_cell = _mouse_cell(event.position)
		_update_cursor()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_cell = _mouse_cell(event.position)
		click_cell(_cell)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		rotate_selection()
	elif event.is_action_pressed(&"ui_cancel"):
		set_decorating(false)
		get_viewport().set_input_as_handled()


## Decorate-mode click: place the selection, or pick up what is on that cell.
func click_cell(cell: Vector2i) -> void:
	if selected:
		if place(selected, cell, _rot):
			if GameState.inventory.count(selected.item) == 0:
				select(null)
		else:
			GameState.toast("Không đặt được ở đây")
	else:
		var f := furniture_at(cell)
		if f:
			pick_up(f)
	_update_cursor()


func _mouse_cell(mouse: Vector2) -> Vector2i:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return _cell
	var hit = Plane(Vector3.UP, global_position.y).intersects_ray(cam.project_ray_origin(mouse), cam.project_ray_normal(mouse))
	if hit == null:
		return _cell
	var p := to_local(hit)
	return Vector2i(floori(p.x), floori(p.z))


func _update_cursor() -> void:
	if not _cursor:
		return
	var s := selected.size_for(_rot) if selected else Vector2i.ONE
	var center := Vector3(_cell.x + s.x * 0.5, 0.03, _cell.y + s.y * 0.5)
	_cursor.position = center
	_cursor.scale = Vector3(s.x, 1, s.y)
	var ok := can_place(selected, _cell, _rot) if selected else furniture_at(_cell) != null
	(_cursor.material_override as StandardMaterial3D).albedo_color = Color(0.3, 1, 0.4, 0.45) if ok else Color(1, 0.3, 0.3, 0.45)
	if _ghost:
		_ghost.position = Vector3(center.x, 0, center.z)


# ---------------------------------------------------------------- save / room

func to_save() -> Dictionary:
	var items := []
	for f: Furniture in _items.get_children():
		if not f.is_queued_for_deletion():
			items.append({"id": String(f.data.id), "x": f.cell.x, "y": f.cell.y, "rot": f.rot})
	return {"floor": floor_style, "wall": wall_style, "items": items}


func load_save(d: Dictionary) -> void:
	floor_style = int(d.get("floor", 0)) % FLOORS.size()
	wall_style = int(d.get("wall", 0)) % WALLS.size()
	for it: Dictionary in d.get("items", []):
		var data: FurnitureData = Database.furniture.get(StringName(it.get("id", "")))
		if data and not place(data, Vector2i(int(it.x), int(it.y)), int(it.rot), false):
			GameState.inventory.add(data.item) # spot taken (layout changed): give it back
	_apply_styles()


func _mark(f: Furniture, value: Variant) -> void:
	var layer := _floor_occupied if f.data.floor_layer else _occupied
	var s := f.size()
	for x in s.x:
		for y in s.y:
			if value:
				layer[f.cell + Vector2i(x, y)] = value
			else:
				layer.erase(f.cell + Vector2i(x, y))


func _apply_styles() -> void:
	_floor_mat.albedo_color = FLOORS[floor_style]
	_wall_mat.albedo_color = WALLS[wall_style]


func _update_info() -> void:
	var hud := _hud()
	if hud and is_inside_tree():
		hud.show_info("Điểm đẹp nhà: %d   (B: trang trí)" % beauty())


func _hud() -> Hud:
	return get_tree().get_first_node_in_group(&"hud") as Hud if is_inside_tree() else null


func _build_room() -> void:
	var w := float(room_size.x)
	var d := float(room_size.y)
	_box(Vector3(w, 0.1, d), Vector3(w * 0.5, -0.05, d * 0.5), _floor_mat, 1 | 4)
	_box(Vector3(w, WALL_HEIGHT, 0.2), Vector3(w * 0.5, WALL_HEIGHT * 0.5, -0.1), _wall_mat, 1)
	_box(Vector3(0.2, WALL_HEIGHT, d), Vector3(-0.1, WALL_HEIGHT * 0.5, d * 0.5), _wall_mat, 1)
	_box(Vector3(0.2, LOW_WALL, d), Vector3(w + 0.1, LOW_WALL * 0.5, d * 0.5), _wall_mat, 1)
	var gap := 2.0 # front door opening, centered
	var side := (w - gap) * 0.5
	_box(Vector3(side, LOW_WALL, 0.2), Vector3(side * 0.5, LOW_WALL * 0.5, d + 0.1), _wall_mat, 1)
	_box(Vector3(side, LOW_WALL, 0.2), Vector3(w - side * 0.5, LOW_WALL * 0.5, d + 0.1), _wall_mat, 1)
	var cursor_mesh := PlaneMesh.new()
	cursor_mesh.size = Vector2.ONE
	_cursor = MeshInstance3D.new()
	_cursor.mesh = cursor_mesh
	var cm := StandardMaterial3D.new()
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cursor.material_override = cm
	_cursor.visible = false
	add_child(_cursor)


func _box(size: Vector3, pos: Vector3, mat: Material, layer: int) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.position = pos
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	add_child(body)
