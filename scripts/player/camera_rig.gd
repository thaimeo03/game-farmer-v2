class_name CameraRig
extends Node3D
## Orbit camera that follows its parent. Right-drag rotates, mouse wheel zooms.
## Node tree: CameraRig (top_level) > SpringArm3D > Camera3D. Only yaw lives on the rig,
## so the player can use this node's basis to move relative to the camera.

@export var follow_speed := 8.0
@export var smooth_speed := 10.0
@export var rotate_sensitivity := 0.3 ## degrees per pixel
@export var zoom_step := 1.5
@export var zoom_range := Vector2(4.0, 22.0)
@export var pitch_range := Vector2(-75.0, -15.0)
@export var yaw := 45.0
@export var pitch := -45.0
@export var zoom := 12.0

## Smoothed values we own. Never read them back from rotation_degrees: Godot returns that
## wrapped to (-180, 180], so lerping from it toward an unbounded yaw spun the camera a full
## turn whenever a fast drag crossed 180 degrees.
var _cur_yaw := 0.0
var _cur_pitch := 0.0
var _cur_zoom := 0.0

@onready var _arm: SpringArm3D = $SpringArm3D
@onready var _target: Node3D = get_parent()


func _ready() -> void:
	snap()


## Jump to the current yaw/pitch/zoom and target position without smoothing.
func snap() -> void:
	global_position = _target.global_position
	_cur_yaw = yaw
	_cur_pitch = pitch
	_cur_zoom = zoom
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * rotate_sensitivity
		pitch = clampf(pitch - event.relative.y * rotate_sensitivity, pitch_range.x, pitch_range.y)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clampf(zoom - zoom_step, zoom_range.x, zoom_range.y)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clampf(zoom + zoom_step, zoom_range.x, zoom_range.y)


func _process(delta: float) -> void:
	global_position = global_position.lerp(_target.global_position, 1.0 - exp(-follow_speed * delta))
	var w := 1.0 - exp(-smooth_speed * delta)
	_cur_yaw = lerpf(_cur_yaw, yaw, w)
	_cur_pitch = lerpf(_cur_pitch, pitch, w)
	_cur_zoom = lerpf(_cur_zoom, zoom, w)
	# keep the numbers small without changing the difference between them
	var turns := floorf(_cur_yaw / 360.0) * 360.0
	_cur_yaw -= turns
	yaw -= turns
	_apply()


func _apply() -> void:
	rotation_degrees.y = _cur_yaw
	_arm.rotation_degrees.x = _cur_pitch
	_arm.spring_length = _cur_zoom
