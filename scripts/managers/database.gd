extends Node
## Autoload "Database": every ItemData / CropData / ZoneData by id, so save files and
## menus can refer to content by id. Scans the resource folders once at startup.

var items := {} ## StringName -> ItemData
var crops := {} ## StringName -> CropData
var zones: Array[ZoneData] = [] ## sorted by ZoneData.order


func _init() -> void:
	_scan("res://resources/items", items)
	_scan("res://resources/crops", crops)
	var found := {}
	_scan("res://resources/zones", found)
	for z: ZoneData in found.values():
		zones.append(z)
	zones.sort_custom(func(a: ZoneData, b: ZoneData) -> bool: return a.order < b.order)


func item(id: StringName) -> ItemData:
	return items.get(id)


func crop(id: StringName) -> CropData:
	return crops.get(id)


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
