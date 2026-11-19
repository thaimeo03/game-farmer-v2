class_name Terrain
extends StaticBody3D
## Low-poly ground generated at load: exactly flat inside `flat_zones` (fields, plazas,
## tracks), rolling hills elsewhere, a steep rise at the map edge, ponds with water,
## dirt paths painted in. Flat-shaded and vertex-colored, with trimesh collision.
## Other nodes (Scatter) sample height_at() so props sit on the hills.

@export var size := 130.0
@export var resolution := 100 ## quads per side
@export var hill_height := 3.5
@export var edge_height := 10.0
@export var noise_frequency := 0.035
@export var flat_zones: Array[Rect2] = [] ## (x, z, width, depth), height forced to 0
@export var flat_falloff := 7.0
@export var ponds: Array[Vector3] = [] ## (x, z, radius)
@export var pond_depth := 1.6
@export var water_level := -0.35
@export var sand_height := 0.25 ## sand up to this far above the water (wider = beach)
@export var paths: Array[Rect2] = [] ## dirt-colored strips
@export var island_radius := 0.0 ## > 0: land is an island of this radius, sea all around
@export var random_seed := 1
@export var grass := Color(0.46, 0.76, 0.32)
@export var grass_dark := Color(0.3, 0.58, 0.25)
@export var dirt := Color(0.74, 0.57, 0.38)
@export var sand := Color(0.93, 0.85, 0.62)

var _noise: FastNoiseLite


func _ready() -> void:
	collision_layer = 1 | 4 # world + camera_blocker: the camera only collides with the ground
	_build()


func height_at(x: float, z: float) -> float:
	if not _noise:
		_noise = FastNoiseLite.new()
		_noise.seed = random_seed
		_noise.frequency = noise_frequency
	var flat := 1.0
	for r in flat_zones:
		flat = minf(flat, smoothstep(0.0, flat_falloff, _rect_distance(r, x, z)))
	var h := (_noise.get_noise_2d(x, z) * 0.5 + 0.5) * hill_height * flat
	h += smoothstep(0.72, 1.0, maxf(absf(x), absf(z)) / (size * 0.5)) * edge_height
	for p in ponds:
		var d := Vector2(x, z).distance_to(Vector2(p.x, p.y))
		h -= pond_depth * (1.0 - smoothstep(p.z * 0.55, p.z, d))
	if island_radius > 0.0:
		h -= pond_depth * 1.5 * smoothstep(island_radius * 0.7, island_radius, Vector2(x, z).length())
	return h


func _build() -> void:
	var n := resolution + 1
	var step := size / resolution
	var half := size * 0.5
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for j in n:
		for i in n:
			hs[j * n + i] = height_at(-half + i * step, -half + j * step)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in resolution:
		for i in resolution:
			var a := Vector3(-half + i * step, hs[j * n + i], -half + j * step)
			var b := Vector3(a.x + step, hs[j * n + i + 1], a.z)
			var c := Vector3(a.x + step, hs[(j + 1) * n + i + 1], a.z + step)
			var d := Vector3(a.x, hs[(j + 1) * n + i], a.z + step)
			if (i + j) % 2 == 0: # alternate diagonals for a less regular low-poly look
				_tri(st, a, b, c)
				_tri(st, a, c, d)
			else:
				_tri(st, a, b, d)
				_tri(st, b, c, d)
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mesh.surface_set_material(0, mat)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	add_child(shape)

	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.35, 0.72, 0.95, 0.78)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.15
	var seas := ponds.duplicate()
	if island_radius > 0.0:
		seas.append(Vector3(0, 0, size * 0.55))
	for p in seas:
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE * p.z * 2.2
		plane.material = water
		var w := MeshInstance3D.new()
		w.mesh = plane
		w.position = Vector3(p.x, water_level, p.y)
		add_child(w)


## One flat-shaded triangle; winding fixed so the face points up (Godot front faces are clockwise).
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var nrm := (b - a).cross(c - a)
	if nrm.y < 0.0:
		var t := b
		b = c
		c = t
		nrm = -nrm
	var center := (a + b + c) / 3.0
	st.set_normal(nrm.normalized())
	st.set_color(_color_at(center))
	for v in [a, c, b]:
		st.add_vertex(v)


func _color_at(p: Vector3) -> Color:
	for r in paths:
		if r.has_point(Vector2(p.x, p.z)):
			return dirt
	if p.y < water_level + sand_height:
		return sand
	var t := _noise.get_noise_2d(p.x * 3.0 + 97.0, p.z * 3.0) * 0.5 + 0.5
	return grass.lerp(grass_dark, clampf(t * 0.55 + p.y / (hill_height + edge_height) * 0.5, 0.0, 1.0))


static func _rect_distance(r: Rect2, x: float, z: float) -> float:
	var dx := maxf(maxf(r.position.x - x, 0.0), x - r.end.x)
	var dz := maxf(maxf(r.position.y - z, 0.0), z - r.end.y)
	return sqrt(dx * dx + dz * dz)
