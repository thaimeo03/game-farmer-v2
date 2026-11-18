extends Node3D
## Root scene: persistent Player + HUD. Loads the save, then moves between zones by bus:
## bus departs -> fade + "Đang đến ..." banner -> zone swap -> bus arrives -> player steps off.
## Visited zones are cached out of the tree so their state (farm plots...) survives.

var _zones := {} # zone id -> zone root
var _zone: Node
var _busy := false

@onready var _player: Player = $Player
@onready var _hud: Hud = $HUD


func _ready() -> void:
	_hud.bind(_player)
	GameState.travel_requested.connect(travel)
	var loaded := SaveManager.load_game()
	await _enter_zone(GameState.current_zone if loaded else &"my_farm", loaded)
	SaveManager.active = true


func _exit_tree() -> void:
	for zone: Node in _zones.values():
		if zone != _zone:
			zone.free()


func travel(zone_id: StringName) -> void:
	var dest := Database.zone(zone_id)
	if _busy or dest == null or zone_id == GameState.current_zone:
		return
	_busy = true
	GameState.ui_busy = true
	var stop := _bus_stop()
	if stop:
		await stop.depart(_player)
	await _hud.fade(1.0, 0.5)
	_hud.show_banner("Đang đến %s..." % dest.display_name)
	await _enter_zone(zone_id, true)
	await get_tree().create_timer(0.8).timeout
	_hud.show_banner("")
	await _hud.fade(0.0, 0.5)
	stop = _bus_stop()
	if stop:
		await stop.arrive(_player)
	SaveManager.save_game()
	GameState.ui_busy = false
	_busy = false


func _enter_zone(zone_id: StringName, at_bus_stop: bool) -> void:
	var data := Database.zone(zone_id)
	if data == null:
		push_warning("Unknown zone '%s', going home" % zone_id)
		data = Database.zone(&"my_farm")
	if _zone:
		remove_child.call_deferred(_zone) # deferred: we may be inside a physics callback
	if not _zones.has(data.id):
		_zones[data.id] = load(data.scene_path).instantiate()
	_zone = _zones[data.id]
	GameState.current_zone = data.id
	add_child.call_deferred(_zone)
	await get_tree().process_frame
	var stop := _bus_stop()
	var spawn := _zone.get_node_or_null(^"PlayerSpawn") as Node3D
	var target: Node3D = stop.exit_point if stop and (at_bus_stop or not spawn) else spawn
	_player.teleport(target.global_position if target else Vector3.UP)


func _bus_stop() -> BusStop:
	return _zone.find_child("BusStop", true, false) as BusStop if _zone else null
