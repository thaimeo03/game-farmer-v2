class_name BusStop
extends InteractZone
## Every zone's bus stop: interacting opens the route board (HUD). Like a real bus, it is
## only here while picking up / dropping off: depart() = pull in, board, pull out;
## arrive() = pull in, player steps off at $Exit, bus leaves. Main awaits these around
## the zone switch. The bus drives along its own +X (front).

@export var drive_distance := 16.0
@export var drive_time := 1.2

@onready var _bus: Node3D = $Bus
@onready var _parked: Vector3 = _bus.position
@onready var exit_point: Marker3D = $Exit


func _ready() -> void:
	if prompt_text == "[E] Nói chuyện":
		prompt_text = "[E] Đi xe buýt"
	super()
	_set_bus_visible(false)
	_bus.position = _parked - _bus.basis.x * drive_distance


func interact(_player: Player) -> void:
	GameState.bus_requested.emit(self)


func depart(player: Player) -> void:
	await _pull_in()
	player.visible = false
	await get_tree().create_timer(0.3).timeout
	await _pull_out()


func arrive(player: Player) -> void:
	player.visible = false
	await _pull_in()
	player.teleport(exit_point.global_position)
	player.visual.rotation.y = global_rotation.y # face away from the road, into the zone
	player.cam.yaw = rad_to_deg(global_rotation.y)
	player.cam.snap()
	player.visible = true
	_pull_out() # not awaited: the player can walk off while the bus leaves


func _pull_in() -> void:
	_bus.position = _parked - _bus.basis.x * drive_distance
	_set_bus_visible(true)
	var tw := create_tween()
	tw.tween_property(_bus, "position", _parked, drive_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await tw.finished


func _pull_out() -> void:
	var tw := create_tween()
	tw.tween_property(_bus, "position", _parked + _bus.basis.x * drive_distance, drive_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	_set_bus_visible(false)


func _set_bus_visible(on: bool) -> void:
	_bus.visible = on
	$Bus/Body/CollisionShape3D.set_deferred(&"disabled", not on) # no invisible bus blocking the road
