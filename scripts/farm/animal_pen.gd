class_name AnimalPen
extends InteractZone
## Fenced pen. Interacting at the gate releases every young animal in the bag (Gà con,
## Bê con...) into the pen, up to `capacity`. Animals are saved under "animal_pen".

@export var pen_size := Vector2(8, 6) ## fenced area, centered on this node
@export var capacity := 8
@export var fence_scene: PackedScene

var _animals: Node3D


func _ready() -> void:
	if prompt_text == "[E] Nói chuyện":
		prompt_text = "[E] Thả vật nuôi"
	super()
	if fence_scene:
		Fence.build(self, Vector3(-pen_size.x * 0.5, 0, -pen_size.y * 0.5), pen_size.x, pen_size.y, 1.2, fence_scene)
	_animals = Node3D.new()
	add_child(_animals)
	var saved = SaveManager.register(&"animal_pen", self)
	if saved:
		for d: Dictionary in saved.get("animals", []):
			var kind: AnimalData = Database.animals.get(StringName(d.get("id", "")))
			if kind:
				var a := _spawn(kind)
				a.fed_at = float(d.get("fed_at", -1.0))
				a.has_product = bool(d.get("has_product", false))


func count() -> int:
	return _animals.get_child_count()


func interact(_player: Player) -> void:
	var released := 0
	for kind: AnimalData in Database.animals.values():
		while count() < capacity and GameState.inventory.remove(kind.item):
			_spawn(kind)
			released += 1
	if released > 0:
		GameState.toast("Đã thả %d vật nuôi vào chuồng (%d/%d)" % [released, count(), capacity])
	elif count() >= capacity:
		GameState.toast("Chuồng đã đầy (%d/%d)" % [count(), capacity])
	else:
		GameState.toast("Chuồng %d/%d — mua vật nuôi ở Phố Chợ" % [count(), capacity])


func to_save() -> Dictionary:
	return {"animals": _animals.get_children().map(func(a: Animal) -> Dictionary: return a.to_save())}


func _spawn(kind: AnimalData) -> Animal:
	var half := pen_size * 0.5 - Vector2(0.7, 0.7)
	var a := Animal.new().setup(kind, Rect2(-half, half * 2.0))
	a.position = Vector3(randf_range(-half.x, half.x), 0, randf_range(-half.y, half.y))
	_animals.add_child(a)
	return a
