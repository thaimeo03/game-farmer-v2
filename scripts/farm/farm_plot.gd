class_name FarmPlot
extends Node3D
## One soil tile. NORMAL -> (till) TILLED -> (plant) PLANTED -> (water) grows -> HARVESTABLE -> (harvest) NORMAL.
## Each growth stage needs its own watering: when a stage completes the soil dries and growth
## pauses until watered again. Stages may also bring weeds or pests, which pause growth
## until removed. Fertilizer halves stage durations. Growth is measured against
## GameState.clock, so it continues while the farm is unloaded or the game is closed.

signal harvested(crop: CropData)

enum State { NORMAL, TILLED, PLANTED, HARVESTABLE }
enum Problem { NONE, WEEDS, PESTS }

const SOIL_RAW := Color(0.6, 0.47, 0.32)
const SOIL_TILLED := Color(0.45, 0.31, 0.2)
const SOIL_WET := Color(0.3, 0.2, 0.13)
const WEED := preload("res://assets/models/kenney/nature/grass_large.glb")

var cell: Vector2i
var state := State.NORMAL
var is_watered := false
var crop: CropData
var stage := 0
var problem := Problem.NONE
var fertilized := false
var problem_chance := 0.25 ## chance of weeds/pests after each completed stage
var _watered_at := 0.0

@onready var _soil_raw: Node3D = $SoilRaw
@onready var _soil_tilled: Node3D = $SoilTilled
@onready var _crop_root: Node3D = $Crop
@onready var _highlight: Node3D = $Highlight


func _ready() -> void:
	_refresh()


func _process(_delta: float) -> void:
	if not _growing():
		return
	var needed := crop.stage_durations[stage] * (0.5 if fertilized else 1.0)
	if GameState.clock - _watered_at < needed:
		return
	stage += 1
	is_watered = false # dry again: the next stage needs another watering
	if crop.is_mature(stage):
		state = State.HARVESTABLE
	elif randf() < problem_chance:
		problem = Problem.WEEDS if randf() < 0.5 else Problem.PESTS
	_refresh()


func can(action: StringName) -> bool:
	match action:
		&"till": return state == State.NORMAL
		&"plant": return state == State.TILLED
		&"water": return state == State.PLANTED and not is_watered
		&"fertilize": return state == State.PLANTED and not fertilized
		&"weed": return problem == Problem.WEEDS
		&"spray": return problem == Problem.PESTS
		&"harvest": return state == State.HARVESTABLE
	return false


func perform(action: StringName, seed_crop: CropData = null) -> void:
	if not can(action):
		return
	match action:
		&"till":
			state = State.TILLED
		&"plant":
			crop = seed_crop
			stage = 0
			state = State.PLANTED
		&"water":
			is_watered = true
			_watered_at = GameState.clock
		&"fertilize":
			fertilized = true
		&"weed", &"spray":
			problem = Problem.NONE
			_watered_at = GameState.clock # the paused stage restarts its timer
		&"harvest":
			var done := crop
			crop = null
			is_watered = false
			fertilized = false
			problem = Problem.NONE
			state = State.NORMAL
			harvested.emit(done)
	_refresh()


## Short status for the HUD / prompts.
func status_text() -> String:
	if problem == Problem.WEEDS:
		return "Có cỏ dại!"
	if problem == Problem.PESTS:
		return "Bị sâu!"
	if state == State.PLANTED and not is_watered:
		return "Cần tưới"
	return ""


func to_save() -> Dictionary:
	return {
		"cell": [cell.x, cell.y], "state": state, "watered": is_watered,
		"crop": String(crop.id) if crop else "", "stage": stage, "watered_at": _watered_at,
		"problem": problem, "fertilized": fertilized,
	}


func from_save(d: Dictionary) -> void:
	crop = Database.crop(StringName(d.get("crop", "")))
	state = int(d.get("state", State.NORMAL)) as State
	if crop == null and state in [State.PLANTED, State.HARVESTABLE]:
		state = State.TILLED # crop removed from the game: keep the soil, drop the plant
	is_watered = bool(d.get("watered", false))
	stage = int(d.get("stage", 0))
	_watered_at = float(d.get("watered_at", 0.0))
	problem = int(d.get("problem", Problem.NONE)) as Problem
	fertilized = bool(d.get("fertilized", false))
	_refresh()
	_process(0.0) # catch up on growth that happened while away


func set_highlighted(on: bool) -> void:
	_highlight.visible = on


func _growing() -> bool:
	return state == State.PLANTED and is_watered and problem == Problem.NONE


func _refresh() -> void:
	var color := SOIL_WET if is_watered else (SOIL_RAW if state == State.NORMAL else SOIL_TILLED)
	_soil_raw.visible = state == State.NORMAL
	_soil_tilled.visible = state != State.NORMAL
	for mi: MeshInstance3D in _soil_raw.find_children("*", "MeshInstance3D", true, false) + _soil_tilled.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = Toon.material(color)
	for child in _crop_root.get_children():
		child.queue_free()
	if crop:
		_crop_root.add_child(crop.make_stage_visual(stage))
	if problem == Problem.WEEDS:
		for p in [Vector3(-0.32, 0, 0.3), Vector3(0.3, 0, -0.28), Vector3(0.28, 0, 0.32)]:
			var w: Node3D = WEED.instantiate()
			w.position = p
			w.scale = Vector3.ONE * 1.6
			_crop_root.add_child(w)
	elif problem == Problem.PESTS:
		for p in [Vector3(-0.15, 0.35, 0.1), Vector3(0.12, 0.25, -0.12), Vector3(0.05, 0.45, 0.15)]:
			var bug := MeshInstance3D.new()
			var m := SphereMesh.new()
			m.radius = 0.06
			m.height = 0.08
			bug.mesh = m
			bug.material_override = Toon.material(Color(0.85, 0.12, 0.1))
			bug.position = p
			_crop_root.add_child(bug)
	set_process(_growing())
