extends Node
## Autoload "Database": every ItemData / CropData / ZoneData by id, so save files and
## menus can refer to content by id. Scans the resource folders once at startup.

var items := {} ## StringName -> ItemData
var crops := {} ## StringName -> CropData
var zones: Array[ZoneData] = [] ## sorted by ZoneData.order
var animals := {} ## StringName -> AnimalData
var recipes := {} ## StringName -> RecipeData


func _init() -> void:
	_scan("res://resources/items", items)
	_scan("res://resources/crops", crops)
	_scan("res://resources/animals", animals)
	_scan("res://resources/recipes", recipes)
	var found := {}
	_scan("res://resources/zones", found)
	for z: ZoneData in found.values():
		zones.append(z)
	zones.sort_custom(func(a: ZoneData, b: ZoneData) -> bool: return a.order < b.order)


func item(id: StringName) -> ItemData:
	return items.get(id)


func crop(id: StringName) -> CropData:
	return crops.get(id)


func recipes_for(machine: StringName) -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	for r: RecipeData in recipes.values():
		if r.machine == machine:
			out.append(r)
	out.sort_custom(func(a: RecipeData, b: RecipeData) -> bool: return a.unlock_level < b.unlock_level)
	return out


func zone(id: StringName) -> ZoneData:
	for z in zones:
		if z.id == id:
			return z
	return null


func _scan(dir: String, out: Dictionary) -> void:
	for file in ResourceLoader.list_directory(dir):
		if file.ends_with(".tres"):
			var res := load(dir.path_join(file))
			if res and "id" in res:
				assert(not out.has(res.id), "duplicate id %s in %s" % [res.id, dir])
				out[res.id] = res
