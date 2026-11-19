class_name FerrisWheel
extends InteractZone
## Giant wheel: the ring turns around its local Z, cabins hang level from the rim. Riding
## (fee) puts the player in the cabin nearest the bottom for one full turn while the camera
## pulls back for a panorama, then drops them at $Exit.

const CABIN := preload("res://assets/models/props/ferris_cabin.glb")

@export var radius := 6.0
@export var cabins := 6
@export var speed := 0.25 ## rad/s -> one turn in ~25 s
@export var fee := 10

var riding := false
var _angle := 0.0
var _cabins: Array[Node3D] = []

@onready var _ring: Node3D = $Ring
@onready var _exit: Marker3D = $Exit


func _ready() -> void:
	if prompt_text == "[E] Nói chuyện":
		prompt_text = "[E] Đi đu quay (%d xu)" % fee
	super()
	for i in cabins:
		var c: Node3D = CABIN.instantiate()
		add_child(c)
		_cabins.append(c)
	_place_cabins()


func _process(delta: float) -> void:
	_angle = fmod(_angle + speed * delta, TAU)
	_place_cabins()


func cabin_position(i: int) -> Vector3:
	var a := _angle + TAU * i / cabins
	return _ring.position + Vector3(cos(a), sin(a), 0.0) * radius


func interact(player: Player) -> void:
	if riding or not GameState.spend(fee):
		return
	riding = true
	GameState.ui_busy = true
	var lowest := 0
	for i in cabins:
		if cabin_position(i).y < cabin_position(lowest).y:
			lowest = i
	var cam := player.cam
	var view := [cam.zoom, cam.pitch]
	cam.zoom = cam.zoom_range.y + 8.0
	cam.pitch = -18.0
	player.ride(_cabins[lowest], Vector3(0, -1.15, 0))
	await get_tree().create_timer(TAU / speed).timeout
	player.end_ride(_exit.global_position)
	cam.zoom = view[0]
	cam.pitch = view[1]
	Progression.reward(&"race")
	GameState.ui_busy = false
	riding = false


func _place_cabins() -> void:
	_ring.rotation.z = _angle
	for i in _cabins.size():
		_cabins[i].position = cabin_position(i)
