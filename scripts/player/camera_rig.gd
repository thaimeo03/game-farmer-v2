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

@onready var _arm: SpringArm3D = $SpringArm3D
@onready var _target: Node3D = get_parent()


func _ready() -> void:
	snap()


## Jump to the current yaw/pitch/zoom and target position without smoothing.
func snap() -> void:
	global_position = _target.global_position
	rotation_degrees.y = yaw
	_arm.rotation_degrees.x = pitch
	_arm.spring_length = zoom


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
	rotation_degrees.y = lerpf(rotation_degrees.y, yaw, w)
	_arm.rotation_degrees.x = lerpf(_arm.rotation_degrees.x, pitch, w)
	_arm.spring_length = lerpf(_arm.spring_length, zoom, w)
