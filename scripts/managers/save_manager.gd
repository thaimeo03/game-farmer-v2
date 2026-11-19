extends Node
## Autoload "SaveManager": one JSON save in user://saves/. Autosaves every minute, on every
## bus trip and when the window closes. Time spent offline is added to GameState.clock on
## load, so crops keep growing while the game is closed.

const VERSION := 2
const AUTOSAVE_SECONDS := 60.0

var path := "user://saves/slot_1.json"
var active := false ## Main turns this on once the game is loaded (tests leave it off)
var _savables := {} ## key -> Node with to_save()/load_save(); registered while it exists (in tree or cached)
var _pending := {} ## key -> loaded data whose node has not been instanced yet

var _timer := 0.0


func _process(delta: float) -> void:
	if not active:
		return
	_timer += delta
	if _timer >= AUTOSAVE_SECONDS:
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and active:
		save_game()


func has_save() -> bool:
	return FileAccess.file_exists(path)


func save_game() -> bool:
	_timer = 0.0
	var data := {
		"version": VERSION,
		"unix": Time.get_unix_time_from_system(),
		"clock": GameState.clock,
		"coins": GameState.coins,
		"gems": GameState.gems,
		"inventory": GameState.inventory.to_save(),
		"level": Progression.level,
		"xp": Progression.xp,
		"zone": String(GameState.current_zone),
		"fish_journal": GameState.fish_journal,
		"daily": GameState.daily,
		"world": _world_data(),
	}
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	# write to a temp file first so a crash mid-write never destroys the previous save
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if not f:
		push_error("Cannot write save: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return DirAccess.rename_absolute(tmp, path) == OK


## Returns false when there is no usable save (new game).
func load_game() -> bool:
	if not has_save():
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) not in [1, VERSION]:
		push_warning("Save unreadable, kept as %s.bad and starting a new game" % path)
		DirAccess.rename_absolute(path, path + ".bad")
		return false
	var offline := maxf(0.0, Time.get_unix_time_from_system() - float(data.get("unix", 0)))
	GameState.clock = float(data.get("clock", 0.0)) + offline
	GameState.coins = int(data.get("coins", 0))
	GameState.gems = int(data.get("gems", 0))
	GameState.inventory.from_save(data.get("inventory", {}))
	Progression.level = int(data.get("level", 1))
	Progression.xp = int(data.get("xp", 0))
	GameState.current_zone = StringName(data.get("zone", "my_farm"))
	GameState.fish_journal = data.get("fish_journal", {})
	GameState.daily = data.get("daily", {})
	_pending = data.get("world", {})
	if int(data.version) == 1: # v1 stored only the farm plots
		_pending = {"farm_grid": {"plots": data.get("farm", [])}}
	# objects that registered before the save was loaded (the persistent Player) get their data now
	for key: StringName in _savables:
		if is_instance_valid(_savables[key]) and _savables[key].has_method(&"load_save") and _pending.has(String(key)):
			_savables[key].load_save(_pending[String(key)])
			_pending.erase(String(key))
	GameState.money_changed.emit()
	Progression.xp_changed.emit()
	return true


## Called by persistent world objects in _ready. Returns their saved data (or null) once.
func register(key: StringName, node: Node) -> Variant:
	_savables[key] = node
	var data = _pending.get(String(key))
	_pending.erase(String(key))
	return data


func _world_data() -> Dictionary:
	var out := _pending.duplicate(true) # data of zones not visited this session is kept as-is
	for key: StringName in _savables:
		if is_instance_valid(_savables[key]):
			out[String(key)] = _savables[key].to_save()
	return out
