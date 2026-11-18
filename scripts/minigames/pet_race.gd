class_name PetRace
extends Node3D
## Pet racing: bet at the desk, five pets run down lanes along local -Z with random
## boosts / trips / naps, the camera cuts to the overview, and a correct pick pays
## bet * payout. Track visuals (dirt + lane lines) are generated; gates/bleachers are in the scene.

const RACERS := [
	{"name": "Thỏ Bông", "model": "res://assets/models/kenney/pets/animal-bunny.glb", "speed": 5.0, "payout": 2},
	{"name": "Cún Vàng", "model": "res://assets/models/kenney/pets/animal-dog.glb", "speed": 4.75, "payout": 3},
	{"name": "Cáo Lửa", "model": "res://assets/models/kenney/pets/animal-fox.glb", "speed": 4.55, "payout": 3},
	{"name": "Mèo Mướp", "model": "res://assets/models/kenney/pets/animal-cat.glb", "speed": 4.3, "payout": 4},
	{"name": "Heo Ủn", "model": "res://assets/models/kenney/pets/animal-pig.glb", "speed": 4.0, "payout": 5},
]
## [chance, seconds, speed multiplier, label] rolled every 0.7-1.4 s per racer
const EVENTS := [
	[0.22, 1.0, 1.8, "Tăng tốc!"],
	[0.12, 0.8, 0.0, "Vấp ngã!"],
	[0.08, 2.0, 0.0, "Ngủ gật... Zzz"],
]

@export var track_length := 30.0
@export var lane_width := 1.6
@export var pet_scale := 0.6
@export var keeper: PackedScene = preload("res://assets/models/kenney/characters/character-male-e.glb")

var racers: Array[Dictionary] = []
var racing := false

var _pick := -1
var _bet := 0
var _winner := -1
var _prev_cam: Camera3D

@onready var _cam: Camera3D = $OverviewCam


func _ready() -> void:
	$Desk.interacted.connect(func(_p: Player) -> void:
		if racing:
			GameState.toast("Cuộc đua đang diễn ra!")
		else:
			GameState.race_requested.emit(self))
	ShopNpc.spawn_character(keeper, $Desk/KeeperSpot)
	_build_track()
	for i in RACERS.size():
		var r: Dictionary = RACERS[i].duplicate()
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 80
		label.outline_size = 18
		add_child(label)
		r.merge({"label": label, "x": (i - (RACERS.size() - 1) * 0.5) * lane_width})
		_set_racer_model(r, r.model)
		racers.append(r)
	_reset()
	_cam.look_at(to_global(Vector3(0, 0, -track_length * 0.55)))


## Puts the player's pet in the last lane (or restores the house racer when pet is null).
func set_guest(pet: PetData, affection := 0) -> void:
	var r := racers[racers.size() - 1]
	var base: Dictionary = RACERS[RACERS.size() - 1]
	r.name = "%s (của bạn)" % pet.display_name if pet else base.name
	r.speed = pet.race_speed(affection) if pet else base.speed
	r.payout = 3 if pet else base.payout
	_set_racer_model(r, pet.model.resource_path if pet else base.model)
	_reset()


func _set_racer_model(r: Dictionary, path: String) -> void:
	if r.get("model_path") == path:
		return
	if r.has("node"):
		r.node.queue_free()
	var node: Node3D = load(path).instantiate()
	node.scale = Vector3.ONE * pet_scale
	node.rotation.y = PI # Kenney pets face +Z, the race runs to -Z
	add_child(node)
	var anim := node.find_children("*", "AnimationPlayer", true, false).pop_front() as AnimationPlayer
	for clip in [&"idle", &"run"]:
		if anim and anim.has_animation(clip):
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	r.merge({"node": node, "anim": anim, "model_path": path}, true)


func start_race(pick: int, bet: int) -> void:
	_pick = pick
	_bet = bet
	Progression.reward(&"race")
	_winner = -1
	_reset()
	GameState.ui_busy = true
	_prev_cam = get_viewport().get_camera_3d()
	_cam.make_current()
	for text in ["3", "2", "1", "Chạy!"]:
		GameState.toast(text)
		await get_tree().create_timer(0.7).timeout
	for r in racers:
		_play(r, &"run")
	racing = true


func _process(delta: float) -> void:
	if not racing:
		return
	for i in racers.size():
		var r := racers[i]
		r.event_t -= delta
		r.effect_t -= delta
		if r.event_t <= 0.0:
			_roll_event(r)
		var mult: float = r.effect_mult if r.effect_t > 0.0 else 1.0
		if r.effect_t <= 0.0 and r.label.text != r.name:
			r.label.text = r.name
			_play(r, &"run")
		var pet: Node3D = r.node
		pet.position.z -= r.speed * r.jitter * mult * delta
		r.label.position = pet.position + Vector3.UP * 1.6
		if _winner < 0 and pet.position.z <= -track_length:
			_winner = i
	if _winner >= 0:
		racing = false
		_finish()


func _roll_event(r: Dictionary) -> void:
	r.event_t = randf_range(0.7, 1.4)
	r.jitter = randf_range(0.9, 1.1)
	var roll := randf()
	for e in EVENTS:
		roll -= e[0]
		if roll < 0.0:
			r.effect_t = e[1]
			r.effect_mult = e[2]
			r.label.text = e[3]
			_play(r, &"idle" if e[2] == 0.0 else &"run")
			return


func _finish() -> void:
	var w := racers[_winner]
	for r in racers:
		_play(r, &"idle")
	if _winner == _pick:
		var prize := _bet * int(w.payout)
		GameState.earn(prize)
		GameState.toast("%s về nhất! Bạn thắng %d xu" % [w.name, prize])
	else:
		GameState.toast("%s về nhất. Bạn mất %d xu" % [w.name, _bet])
	await get_tree().create_timer(2.5).timeout
	if is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	_reset()
	GameState.ui_busy = false


func _reset() -> void:
	for r in racers:
		r.node.position = Vector3(r.x, 0.0, 0.0)
		r.label.position = r.node.position + Vector3.UP * 1.6
		r.label.text = r.name
		r.merge({"event_t": randf_range(0.5, 1.0), "effect_t": 0.0, "effect_mult": 1.0, "jitter": 1.0}, true)
		_play(r, &"idle")


func _play(r: Dictionary, clip: StringName) -> void:
	if r.anim and r.anim.has_animation(clip) and r.anim.current_animation != clip:
		r.anim.play(clip, 0.15)


func _build_track() -> void:
	var w := lane_width * RACERS.size()
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(0.8, 0.62, 0.42)
	var line := StandardMaterial3D.new()
	line.albedo_color = Color(1, 1, 1)
	_box(Vector3(w + 0.6, 0.04, track_length + 6.0), Vector3(0, 0.02, -track_length * 0.5), dirt)
	for i in RACERS.size() + 1:
		_box(Vector3(0.06, 0.05, track_length + 6.0), Vector3(-w * 0.5 + i * lane_width, 0.03, -track_length * 0.5), line)
	_box(Vector3(w, 0.05, 0.15), Vector3(0, 0.035, 0), line)
	_box(Vector3(w, 0.05, 0.15), Vector3(0, 0.035, -track_length), line)


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)
