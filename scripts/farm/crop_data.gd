class_name CropData
extends Resource
## Static definition of a crop. One .tres per crop in res://resources/crops/.

@export var id: StringName
@export var display_name := ""
@export var color := Color.ORANGE
## Seconds spent in each stage before advancing. Stage index == size() means mature.
@export var stage_durations := PackedFloat32Array([5.0, 5.0, 5.0])
## Optional model per stage (seed, sprout, young, mature). Empty entries use the placeholder.
@export var stage_scenes: Array[PackedScene] = []
## Item added to the inventory on harvest (prices live on the ItemData).
@export var produce: ItemData


func is_mature(stage: int) -> bool:
	return stage >= stage_durations.size()


func stage_at(elapsed: float) -> int:
	var s := 0
	while s < stage_durations.size() and elapsed >= stage_durations[s]:
		elapsed -= stage_durations[s]
		s += 1
	return s


func make_stage_visual(stage: int) -> Node3D:
	if stage < stage_scenes.size() and stage_scenes[stage]:
		return stage_scenes[stage].instantiate()
	# shortcut: low-poly sphere grows from green bud to crop color; drop real models into stage_scenes later
	var t := float(stage) / stage_durations.size()
	var r := lerpf(0.08, 0.3, t)
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Toon.material(Color(0.4, 0.8, 0.3).lerp(color, t))
	mi.position.y = r
	return mi
