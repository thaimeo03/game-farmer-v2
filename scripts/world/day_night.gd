class_name DayNight
extends Node
## Sky, sun and ambient light follow GameState.clock; rain (GameState.is_raining) greys the
## sky and drops rain around the player; a rainbow shows the hour after a rain; street lamps
## switch on at dusk. The world Environment is shared by every zone, so it is changed in place.

const ENV: Environment = preload("res://resources/world_environment.tres")
const RAINBOW := preload("res://assets/models/props/rainbow.glb")
const DAY_TOP := Color(0.3, 0.56, 0.95)
const DAY_HORIZON := Color(0.78, 0.89, 1)
const DUSK_TOP := Color(0.36, 0.35, 0.68)
const DUSK_HORIZON := Color(1.0, 0.6, 0.38)
const NIGHT_TOP := Color(0.03, 0.05, 0.15)
const NIGHT_HORIZON := Color(0.1, 0.14, 0.28)
const RAIN_TOP := Color(0.42, 0.47, 0.55)
const RAIN_HORIZON := Color(0.62, 0.65, 0.7)

var player: Node3D
var _env: Environment = ENV
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _indoor := false
var _rain_amount := 0.0
var _rain: GPUParticles3D
var _rainbow: Node3D
var _rainbow_mats: Array[StandardMaterial3D] = []
var _rainbow_alpha := 0.0
var _lamps := -1 ## last state sent to the lamps (-1 = unknown)


func _ready() -> void:
	_sky = ENV.sky.sky_material
	_build_rain()
	_build_rainbow()


## 0 at night .. 1 in full day; dawn 4:30-7:00, dusk 17:00-19:30.
static func daylight(minute: float) -> float:
	return smoothstep(270.0, 420.0, minute) * (1.0 - smoothstep(1020.0, 1170.0, minute))


func set_zone(zone: Node, indoor: bool) -> void:
	_indoor = indoor
	_sun = zone.get_node_or_null(^"Sun") as DirectionalLight3D
	if _sun and not _sun.has_meta(&"base_energy"):
		_sun.set_meta(&"base_energy", _sun.light_energy)
		_sun.set_meta(&"base_rotation", _sun.rotation_degrees)
	_lamps = -1
	_process(0.0)


func _process(delta: float) -> void:
	var m := GameState.minute_of_day()
	var d := daylight(m)
	if _indoor:
		d = maxf(d, 0.7)
	var raining := GameState.is_raining() and not _indoor
	_rain_amount = move_toward(_rain_amount, 1.0 if raining else 0.0, delta * 0.4) if delta > 0.0 else (1.0 if raining else 0.0)
	var r := _rain_amount
	var dusk := clampf(1.0 - absf(d - 0.5) * 2.0, 0.0, 1.0) * (1.0 - r)
	var grey := 0.35 + 0.65 * d
	var top := NIGHT_TOP.lerp(DAY_TOP, d).lerp(DUSK_TOP, dusk * 0.5).lerp(RAIN_TOP * grey, r * 0.8)
	var horizon := NIGHT_HORIZON.lerp(DAY_HORIZON, d).lerp(DUSK_HORIZON, dusk * 0.8).lerp(RAIN_HORIZON * grey, r * 0.8)
	_sky.sky_top_color = top
	_sky.sky_horizon_color = horizon
	_sky.ground_horizon_color = horizon
	_env.ambient_light_energy = lerpf(0.55, 1.1, d) * (1.0 - 0.2 * r)
	_env.fog_light_color = horizon
	_env.fog_density = 0.0055 + 0.008 * r
	if _sun and is_instance_valid(_sun) and not _indoor:
		var base_rot: Vector3 = _sun.get_meta(&"base_rotation")
		_sun.light_energy = lerpf(0.18, _sun.get_meta(&"base_energy"), d) * (1.0 - 0.6 * r)
		_sun.light_color = Color(0.55, 0.65, 1.0).lerp(Color(1, 0.97, 0.92), d).lerp(Color(1, 0.62, 0.38), dusk * 0.7)
		var p := clampf((m - 360.0) / 720.0, 0.0, 1.0) # sun path 6:00 -> 18:00
		var elevation := lerpf(14.0, -base_rot.x, sin(p * PI)) if d > 0.08 else 40.0 # moon at night
		_sun.rotation_degrees = Vector3(-elevation, base_rot.y + lerpf(-50.0, 50.0, p), 0.0)
	var lit := 1 if (d < 0.45 or r > 0.6 and d < 0.8) and not _indoor else 0
	if lit != _lamps:
		_lamps = lit
		StreetLamp.lit_now = lit == 1
		get_tree().call_group(&"street_lamp", &"set_lit", lit == 1)
	if player and is_instance_valid(player):
		_rain.global_position = player.global_position + Vector3(0, 9, 0)
		_rainbow.global_position = Vector3(player.global_position.x, -12.0, player.global_position.z - 150.0)
	_rain.emitting = r > 0.25
	_rain.amount_ratio = r
	var want := 1.0 if GameState.has_rainbow() and not raining and not _indoor and d > 0.5 else 0.0
	_rainbow_alpha = move_toward(_rainbow_alpha, want, delta * 0.25) if delta > 0.0 else want
	_rainbow.visible = _rainbow_alpha > 0.01
	for mat in _rainbow_mats:
		mat.albedo_color.a = 0.5 * _rainbow_alpha


func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.amount = 1400
	_rain.lifetime = 1.2
	_rain.local_coords = false
	_rain.emitting = false
	_rain.visibility_aabb = AABB(Vector3(-20, -30, -20), Vector3(40, 40, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16, 1, 16)
	pm.direction = Vector3(0.05, -1, 0)
	pm.spread = 2.0
	pm.initial_velocity_min = 15.0
	pm.initial_velocity_max = 19.0
	pm.gravity = Vector3(0, -9.8, 0)
	_rain.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.025, 0.6)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.82, 0.88, 1.0, 0.5)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	quad.material = mat
	_rain.draw_pass_1 = quad
	add_child(_rain)


func _build_rainbow() -> void:
	_rainbow = RAINBOW.instantiate()
	_rainbow.scale = Vector3.ONE * 80.0
	_rainbow.visible = false
	add_child(_rainbow)
	for mi: MeshInstance3D in _rainbow.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i) as StandardMaterial3D
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.disable_fog = true
			mat.albedo_color = src.albedo_color if src else Color.WHITE
			mi.set_surface_override_material(i, mat)
			_rainbow_mats.append(mat)
