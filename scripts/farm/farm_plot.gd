class_name FarmPlot
extends Node3D
## One soil tile. NORMAL -> (till) TILLED -> (plant) PLANTED -> (water) grows -> HARVESTABLE -> (harvest) NORMAL.
## Growth counts from the moment of watering against GameState.clock, so crops keep
## growing while this level is unloaded (e.g. player is in the city).

signal harvested(crop: CropData)

enum State { NORMAL, TILLED, PLANTED, HARVESTABLE }

const SOIL_RAW := Color(0.6, 0.47, 0.32)
const SOIL_TILLED := Color(0.45, 0.31, 0.2)
const SOIL_WET := Color(0.3, 0.2, 0.13)

var cell: Vector2i
var state := State.NORMAL
var is_watered := false
var crop: CropData
var stage := 0
var _watered_at := 0.0

@onready var _soil_raw: Node3D = $SoilRaw
@onready var _soil_tilled: Node3D = $SoilTilled
@onready var _crop_root: Node3D = $Crop
@onready var _highlight: Node3D = $Highlight


func _ready() -> void:
	_refresh()


func _process(_delta: float) -> void:
	if state != State.PLANTED or not is_watered:
		return
	var s := crop.stage_at(GameState.clock - _watered_at)
	if s == stage:
		return
	stage = s
	if crop.is_mature(stage):
		state = State.HARVESTABLE
	_refresh()


func can(action: StringName) -> bool:
	match action:
		&"till": return state == State.NORMAL
		&"plant": return state == State.TILLED
		&"water": return state == State.PLANTED and not is_watered
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
		&"harvest":
			var done := crop
			crop = null
			is_watered = false
			state = State.NORMAL
			harvested.emit(done)
	_refresh()


func to_save() -> Dictionary:
	return {
		"cell": [cell.x, cell.y], "state": state, "watered": is_watered,
		"crop": String(crop.id) if crop else "", "stage": stage, "watered_at": _watered_at,
	}


func from_save(d: Dictionary) -> void:
	crop = Database.crop(StringName(d.get("crop", "")))
	state = int(d.get("state", State.NORMAL)) as State
	if crop == null and state in [State.PLANTED, State.HARVESTABLE]:
		state = State.TILLED # crop removed from the game: keep the soil, drop the plant
	is_watered = bool(d.get("watered", false))
	stage = int(d.get("stage", 0))
	_watered_at = float(d.get("watered_at", 0.0))
	_refresh()
	_process(0.0) # catch up on growth that happened while away


func set_highlighted(on: bool) -> void:
	_highlight.visible = on


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
	set_process(state == State.PLANTED and is_watered)
