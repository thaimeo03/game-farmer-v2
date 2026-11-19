class_name StreetLamp
extends Node3D
## Lamp post that lights up at night (DayNight calls set_lit on group "street_lamp").

const MODEL := preload("res://assets/models/props/street_lamp.glb")

static var lit_now := false ## current state, so lamps created later start right

var _light: OmniLight3D
var _bulbs: Array = [] ## [MeshInstance3D, surface index] using FP_Bulb
var _glow: StandardMaterial3D


func _ready() -> void:
	add_to_group(&"street_lamp")
	add_child(MODEL.instantiate())
	_light = OmniLight3D.new()
	_light.position = Vector3(0.7, 2.8, 0)
	_light.omni_range = 10.0
	_light.light_energy = 1.8
	_light.light_color = Color(1, 0.82, 0.55)
	add_child(_light)
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if mat and mat.resource_name == "FP_Bulb":
				if not _glow:
					_glow = mat.duplicate()
					_glow.emission_enabled = true
					_glow.emission = Color(1, 0.85, 0.5)
					_glow.emission_energy_multiplier = 4.0
				_bulbs.append([mi, i])
	set_lit(lit_now)


func set_lit(on: bool) -> void:
	_light.visible = on
	for b: Array in _bulbs:
		(b[0] as MeshInstance3D).set_surface_override_material(b[1], _glow if on else null)
